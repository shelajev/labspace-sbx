#!/bin/bash
# sandbox-patch.sh — Apply Docker Sandbox proxy patches to NanoClaw
#
# Run this from the nanoclaw project root after `git clone` and `npm install`.
# It patches the source code so NanoClaw works inside a Docker Sandbox
# where all traffic goes through a MITM proxy.
#
# Usage: bash sandbox-patch.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[sandbox-patch]${NC} $*"; }
warn() { echo -e "${YELLOW}[sandbox-patch]${NC} $*"; }
err()  { echo -e "${RED}[sandbox-patch]${NC} $*" >&2; }

# Verify we're in the nanoclaw directory
if [[ ! -f package.json ]] || ! grep -q '"nanoclaw"' package.json 2>/dev/null; then
  err "Run this script from the nanoclaw project root."
  exit 1
fi

# Verify we're inside a Docker Sandbox (proxy env vars present)
if [[ -z "${HTTPS_PROXY:-}" && -z "${https_proxy:-}" ]]; then
  warn "No HTTPS_PROXY detected. Are you inside a Docker Sandbox?"
  warn "Continuing anyway — patches are safe to apply outside sandboxes too."
fi

# ─── Patch 1: Dockerfile — npm strict-ssl + proxy build args ───

log "Patching container/Dockerfile for proxy compatibility..."

if [[ -f container/Dockerfile ]]; then
  if ! grep -q 'strict-ssl' container/Dockerfile; then
    # Add npm strict-ssl and proxy-ca cert handling before the first npm install
    sed -i '/# Install agent-browser and claude-code globally/i\
# Docker Sandbox: accept proxy MITM certificate for npm\
ARG http_proxy\
ARG https_proxy\
ARG NODE_EXTRA_CA_CERTS\
RUN npm config set strict-ssl false\
' container/Dockerfile
    log "  Dockerfile patched."
  else
    log "  Dockerfile already patched, skipping."
  fi
else
  warn "  container/Dockerfile not found, skipping."
fi

# ─── Patch 2: container/build.sh — pass proxy build args ───

log "Patching container/build.sh for proxy build args..."

if [[ -f container/build.sh ]]; then
  if ! grep -q 'http_proxy' container/build.sh; then
    sed -i 's|\${CONTAINER_RUNTIME} build -t|\${CONTAINER_RUNTIME} build --build-arg http_proxy=${http_proxy:-} --build-arg https_proxy=${https_proxy:-} -t|' container/build.sh
    log "  build.sh patched."
  else
    log "  build.sh already patched, skipping."
  fi
else
  warn "  container/build.sh not found, skipping."
fi

# ─── Patch 3: Forward proxy env vars to agent containers ───

log "Patching src/container-runner.ts to forward proxy env vars..."

if [[ -f src/container-runner.ts ]]; then
  if ! grep -q 'HTTP_PROXY.*HTTPS_PROXY.*http_proxy' src/container-runner.ts; then
    # Insert proxy env var forwarding + --network host after the TZ line in buildContainerArgs
    cat > /tmp/proxy-env-patch.py << 'PYEOF'
import re, sys

content = open(sys.argv[1]).read()

# Add --network host to docker run args (sub-containers need to reach the sandbox proxy)
content = content.replace(
    "const args: string[] = ['run', '-i', '--rm', '--name', containerName];",
    "const args: string[] = ['run', '-i', '--rm', '--network', 'host', '--name', containerName];"
)

# Find the TZ push line and insert proxy forwarding after it
tz_pattern = r"(args\.push\('-e', `TZ=\$\{TIMEZONE\}`\);)"
proxy_code = r"""\1

  // Docker Sandbox: forward proxy env vars to agent containers
  const proxyVars = [
    'HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy',
    'NO_PROXY', 'no_proxy', 'SSL_CERT_FILE', 'REQUESTS_CA_BUNDLE',
  ];
  for (const v of proxyVars) {
    if (process.env[v]) args.push('-e', `${v}=${process.env[v]}`);
  }

  // Docker Sandbox: mount proxy CA cert and trust it for Claude Code
  // Claude Code ignores NODE_EXTRA_CA_CERTS, so we also disable TLS verification.
  // This is safe because the sub-container runs inside a sandbox with proxy-controlled networking.
  const proxyCertPath = path.join(process.cwd(), 'proxy-ca.crt');
  if (fs.existsSync(proxyCertPath)) {
    args.push('-v', `${proxyCertPath}:/workspace/proxy-ca.crt:ro`);
    args.push('-e', 'NODE_EXTRA_CA_CERTS=/workspace/proxy-ca.crt');
    args.push('-e', 'NODE_TLS_REJECT_UNAUTHORIZED=0');
  }"""

result = re.sub(tz_pattern, proxy_code, content, count=1)

if result == content:
    print("WARNING: TZ pattern not found, patch may have failed", file=sys.stderr)
    sys.exit(1)

open(sys.argv[1], 'w').write(result)
PYEOF
    python3 /tmp/proxy-env-patch.py src/container-runner.ts
    rm /tmp/proxy-env-patch.py
    log "  container-runner.ts patched."
  else
    log "  container-runner.ts already patched, skipping."
  fi
else
  err "  src/container-runner.ts not found!"
  exit 1
fi

# ─── Patch 4: Copy proxy CA cert to project dir ───

log "Copying proxy CA certificate to project directory..."

CERT_SRC="/usr/local/share/ca-certificates/proxy-ca.crt"
if [[ -f "$CERT_SRC" ]]; then
  cp "$CERT_SRC" proxy-ca.crt
  # Add to .gitignore if not already there
  if ! grep -q 'proxy-ca.crt' .gitignore 2>/dev/null; then
    echo 'proxy-ca.crt' >> .gitignore
  fi
  log "  CA cert copied to proxy-ca.crt"
else
  warn "  Proxy CA cert not found at $CERT_SRC (not in a sandbox?)"
fi

# ─── Patch 5: Install https-proxy-agent for WhatsApp ───

log "Installing https-proxy-agent dependency..."

# Always check from the project's node_modules (not global)
if [[ ! -d node_modules/https-proxy-agent ]]; then
  npm install https-proxy-agent 2>&1 | tail -1
  log "  https-proxy-agent installed."
else
  log "  https-proxy-agent already installed, skipping."
fi

# ─── Patch 6: Telegram adapter — proxy agent for grammy ───

log "Patching Telegram adapter for proxy compatibility..."

if [[ -f src/channels/telegram.ts ]]; then
  if ! grep -q 'HttpsProxyAgent' src/channels/telegram.ts; then
    cat > /tmp/telegram-proxy-patch.py << 'PYEOF'
import sys

content = open(sys.argv[1]).read()

# Add import for HttpsProxyAgent at the top (after the first import line)
import_line = "import { HttpsProxyAgent } from 'https-proxy-agent';\n"
# Insert after the grammy import
content = content.replace(
    "import { Bot } from 'grammy';",
    "import { Bot } from 'grammy';\n" + import_line,
    1
)

# Patch the Bot constructor to include proxy agent in baseFetchConfig
# Find: this.bot = new Bot(this.botToken);
# Replace with version that includes proxy agent
old_bot_init = "this.bot = new Bot(this.botToken);"
proxy_bot_init = """// Docker Sandbox: route grammy requests through the MITM proxy
    const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
    const clientOpts = proxyUrl
      ? { client: { baseFetchConfig: { agent: new HttpsProxyAgent(proxyUrl), compress: true } } }
      : {};
    this.bot = new Bot(this.botToken, clientOpts);"""

if old_bot_init in content:
    content = content.replace(old_bot_init, proxy_bot_init, 1)
    open(sys.argv[1], 'w').write(content)
    print("  telegram.ts patched.")
else:
    print("  WARNING: Bot constructor pattern not found in telegram.ts")
PYEOF
    python3 /tmp/telegram-proxy-patch.py src/channels/telegram.ts
    rm /tmp/telegram-proxy-patch.py
  else
    log "  telegram.ts already patched, skipping."
  fi
else
  log "  telegram.ts not found (Telegram skill not applied yet), skipping."
fi

# ─── Patch 7: WhatsApp adapter — proxy agent for Baileys WebSocket + version fetch ───

log "Patching WhatsApp adapter for proxy compatibility..."

if [[ -f src/channels/whatsapp.ts ]]; then
  if ! grep -q 'HttpsProxyAgent' src/channels/whatsapp.ts; then
    cat > /tmp/whatsapp-proxy-patch.py << 'PYEOF'
import sys

content = open(sys.argv[1]).read()

# 1. Add imports for HttpsProxyAgent and https at the top
import_block = """import { HttpsProxyAgent } from 'https-proxy-agent';
import https from 'https';
"""
content = content.replace(
    "import makeWASocket,",
    import_block + "\nimport makeWASocket,",
    1
)

# 2. Add proxy-aware version fetch function before the class definition
version_fetch_fn = '''
/**
 * Docker Sandbox: fetch WhatsApp Web version through the proxy.
 * Uses the same sw.js approach as Baileys but routes through HttpsProxyAgent
 * since Node's fetch doesn't respect HTTP_PROXY env vars.
 */
async function fetchWaVersionViaProxy(): Promise<[number, number, number] | undefined> {
  const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
  if (!proxyUrl) return undefined;

  const agent = new HttpsProxyAgent(proxyUrl);
  return new Promise((resolve) => {
    const req = https.get('https://web.whatsapp.com/sw.js', {
      agent,
      headers: {
        'sec-fetch-site': 'none',
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
    }, (res) => {
      let data = '';
      res.on('data', (c: Buffer) => data += c);
      res.on('end', () => {
        const regex = /\\\\?"client_revision\\\\?":\\s*(\\d+)/;
        const match = data.match(regex);
        if (match?.[1]) {
          resolve([2, 3000, parseInt(match[1])] as [number, number, number]);
        } else {
          resolve(undefined);
        }
      });
    });
    req.on('error', () => resolve(undefined));
    req.setTimeout(10000, () => { req.destroy(); resolve(undefined); });
  });
}

'''
content = content.replace(
    "export class WhatsAppChannel",
    version_fetch_fn + "export class WhatsAppChannel",
    1
)

# 3. Patch the version fetch to use proxy-aware function first
old_version = """const { version } = await fetchLatestWaWebVersion({}).catch((err) => {
      logger.warn(
        { err },
        'Failed to fetch latest WA Web version, using default',
      );
      return { version: undefined };
    });"""
new_version = """// Docker Sandbox: try proxy-aware version fetch first
    const proxyVersion = await fetchWaVersionViaProxy();
    const { version } = proxyVersion
      ? { version: proxyVersion }
      : await fetchLatestWaWebVersion({}).catch((err) => {
          logger.warn(
            { err },
            'Failed to fetch latest WA Web version, using default',
          );
          return { version: undefined };
        });"""
content = content.replace(old_version, new_version, 1)

# 4. Add proxy agent to makeWASocket call
old_socket = """this.sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, logger),
      },
      printQRInTerminal: false,
      logger,
      browser: Browsers.macOS('Chrome'),
    });"""
new_socket = """// Docker Sandbox: route Baileys WebSocket through the MITM proxy
    const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
    const proxyAgent = proxyUrl ? new HttpsProxyAgent(proxyUrl) : undefined;

    this.sock = makeWASocket({
      version,
      auth: {
        creds: state.creds,
        keys: makeCacheableSignalKeyStore(state.keys, logger),
      },
      printQRInTerminal: false,
      logger,
      browser: Browsers.macOS('Chrome'),
      agent: proxyAgent,
      fetchAgent: proxyAgent,
    });"""
content = content.replace(old_socket, new_socket, 1)

open(sys.argv[1], 'w').write(content)
print("  whatsapp.ts patched.")
PYEOF
    python3 /tmp/whatsapp-proxy-patch.py src/channels/whatsapp.ts
    rm /tmp/whatsapp-proxy-patch.py
  else
    log "  whatsapp.ts already patched, skipping."
  fi
else
  log "  whatsapp.ts not found (WhatsApp skill not applied yet), skipping."
fi

# ─── Patch 7b: WhatsApp auth script — proxy agent for Baileys ───

log "Patching WhatsApp auth script for proxy compatibility..."

if [[ -f src/whatsapp-auth.ts ]]; then
  if ! grep -q 'HttpsProxyAgent' src/whatsapp-auth.ts; then
    cat > /tmp/whatsapp-auth-proxy-patch.py << 'PYEOF'
import sys

content = open(sys.argv[1]).read()

# 1. Add imports for HttpsProxyAgent and https at the top
import_block = """import { HttpsProxyAgent } from 'https-proxy-agent';
import https from 'https';
"""
content = content.replace(
    "import makeWASocket,",
    import_block + "\nimport makeWASocket,",
    1
)

# 2. Add proxy-aware version fetch function before the connectSocket function
version_fetch_fn = '''
/**
 * Docker Sandbox: fetch WhatsApp Web version through the proxy.
 * Uses the same sw.js approach as Baileys but routes through HttpsProxyAgent.
 */
async function fetchWaVersionViaProxy(): Promise<[number, number, number] | undefined> {
  const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
  if (!proxyUrl) return undefined;

  const agent = new HttpsProxyAgent(proxyUrl);
  return new Promise((resolve) => {
    const req = https.get('https://web.whatsapp.com/sw.js', {
      agent,
      headers: {
        'sec-fetch-site': 'none',
        'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
    }, (res) => {
      let data = '';
      res.on('data', (c: Buffer) => data += c);
      res.on('end', () => {
        const regex = /\\\\?"client_revision\\\\?":\\s*(\\d+)/;
        const match = data.match(regex);
        if (match?.[1]) {
          resolve([2, 3000, parseInt(match[1])] as [number, number, number]);
        } else {
          resolve(undefined);
        }
      });
    });
    req.on('error', () => resolve(undefined));
    req.setTimeout(10000, () => { req.destroy(); resolve(undefined); });
  });
}

'''
content = content.replace(
    "async function connectSocket(",
    version_fetch_fn + "async function connectSocket(",
    1
)

# 3. Patch the version fetch to use proxy-aware function first
old_version = """const { version } = await fetchLatestWaWebVersion({}).catch((err) => {
    logger.warn(
      { err },
      'Failed to fetch latest WA Web version, using default',
    );
    return { version: undefined };
  });"""
new_version = """// Docker Sandbox: try proxy-aware version fetch first
  const proxyVersion = await fetchWaVersionViaProxy();
  const { version } = proxyVersion
    ? { version: proxyVersion }
    : await fetchLatestWaWebVersion({}).catch((err) => {
        logger.warn(
          { err },
          'Failed to fetch latest WA Web version, using default',
        );
        return { version: undefined };
      });"""
content = content.replace(old_version, new_version, 1)

# 4. Add proxy agent to makeWASocket call
old_socket = """const sock = makeWASocket({
    version,
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, logger),
    },
    printQRInTerminal: false,
    logger,
    browser: Browsers.macOS('Chrome'),
  });"""
new_socket = """// Docker Sandbox: route Baileys WebSocket through the MITM proxy
  const proxyUrl = process.env.HTTPS_PROXY || process.env.https_proxy;
  const proxyAgent = proxyUrl ? new HttpsProxyAgent(proxyUrl) : undefined;

  const sock = makeWASocket({
    version,
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, logger),
    },
    printQRInTerminal: false,
    logger,
    browser: Browsers.macOS('Chrome'),
    agent: proxyAgent,
    fetchAgent: proxyAgent,
  });"""
content = content.replace(old_socket, new_socket, 1)

open(sys.argv[1], 'w').write(content)
print("  whatsapp-auth.ts patched.")
PYEOF
    python3 /tmp/whatsapp-auth-proxy-patch.py src/whatsapp-auth.ts
    rm /tmp/whatsapp-auth-proxy-patch.py
  else
    log "  whatsapp-auth.ts already patched, skipping."
  fi
else
  log "  whatsapp-auth.ts not found (WhatsApp skill not applied yet), skipping."
fi

# ─── Patch 8: Fix /dev/null shadow mount for DinD ───

log "Patching container-runner.ts to replace /dev/null shadow mount..."

if [[ -f src/container-runner.ts ]]; then
  if grep -q "'/dev/null'" src/container-runner.ts; then
    # Create an empty file to use instead of /dev/null (DinD can't mount /dev/null)
    touch .env.empty
    if ! grep -q '.env.empty' .gitignore 2>/dev/null; then
      echo '.env.empty' >> .gitignore
    fi

    # Replace /dev/null with the empty file path
    cat > /tmp/devnull-patch.py << 'PYEOF'
import sys

content = open(sys.argv[1]).read()

# Replace the /dev/null shadow mount with an empty file in the project directory
old = "hostPath: '/dev/null',"
new = "hostPath: path.join(process.cwd(), '.env.empty'),"
content = content.replace(old, new)

open(sys.argv[1], 'w').write(content)
PYEOF
    python3 /tmp/devnull-patch.py src/container-runner.ts
    rm /tmp/devnull-patch.py
    log "  /dev/null shadow mount replaced with .env.empty"
  else
    log "  /dev/null already replaced, skipping."
  fi
fi

# ─── Patch 9: container/agent-runner npm strict-ssl (handled by Dockerfile) ───

log "Patching container/agent-runner for proxy compatibility..."

if [[ -f container/agent-runner/package.json ]]; then
  # The agent-runner npm install happens during docker build,
  # which is already handled by Dockerfile patch. But also ensure
  # the entrypoint handles proxy for runtime tsc compilation.
  log "  Agent runner will use Dockerfile proxy patches."
fi

# ─── Patch 10: Setup step for container build — proxy build args ───

log "Checking setup/container.ts for proxy build arg support..."

if [[ -f setup/container.ts ]]; then
  if ! grep -q 'http_proxy' setup/container.ts; then
    # The setup script uses: execSync(`${buildCmd} -t ${image} .`, ...)
    # We need to inject proxy build args into the template literal
    # Use python3 for the replacement since the string contains complex escapes
    python3 -c "
import sys
content = open('setup/container.ts').read()
old = '\${buildCmd} -t \${image} .'
new = \"\${buildCmd} --build-arg http_proxy=\${process.env.http_proxy || ''} --build-arg https_proxy=\${process.env.https_proxy || ''} -t \${image} .\"
content = content.replace(old, new, 1)
open('setup/container.ts', 'w').write(content)
"
    if grep -q 'http_proxy' setup/container.ts; then
      log "  setup/container.ts patched."
    else
      warn "  setup/container.ts patch may not have applied correctly."
    fi
  else
    log "  setup/container.ts already patched, skipping."
  fi
fi

# ─── Summary ───

echo ""
log "All patches applied."
echo ""
echo "Next steps:"
echo "  1. Configure WhatsApp proxy bypass (run from HOST, not sandbox):"
echo "     docker sandbox network proxy <sandbox-name> \\"
echo "       --bypass-host web.whatsapp.com \\"
echo '       --bypass-host "*.whatsapp.com" \\'
echo '       --bypass-host "*.whatsapp.net"'
echo ""
echo "  2. Build and run NanoClaw:"
echo "     npm run build"
echo "     claude   # then type: /setup"
echo ""
echo "  3. Or run interactively for testing:"
echo "     npm run dev"
