# Scenario 3 — NanoClaw on Telegram

**Workspace:** `project/nanoclaw-telegram/`
**Sandbox type:** `shell`
**Time:** ~15 minutes

The hardest of the three — and the one that shows Docker Sandboxes working
at full stretch.

**NanoClaw** is a WhatsApp/Telegram-to-Claude bridge: messages come in over
Telegram, NanoClaw spawns a **Claude agent in its own container** to handle
each one, the container replies, NanoClaw forwards the reply back to
Telegram. You get a personal AI assistant on your phone.

What makes this interesting for the sandbox story:

1. NanoClaw isn't a coding agent. It's a Node.js app. Same sandbox, same
   isolation.
2. NanoClaw uses **Docker-in-Docker** — it starts its own containers
   inside the sandbox. The proxy's secret injection has to cascade through
   those nested containers.
3. The `ANTHROPIC_API_KEY` the Claude agent container needs is literally the
   string `proxy-managed`. The real key is injected at the HTTP layer by the
   host proxy — through two container boundaries — before it hits
   Anthropic.

---

## Step 1 — Create a Telegram bot

On your phone or in [web.telegram.org](https://web.telegram.org):

1. Search for **@BotFather** and start a chat.
2. Send `/newbot`.
3. Give it a display name (e.g. `My Demo Bot`).
4. Give it a username ending in `bot` (e.g. `mydemo_<your-handle>_bot`).
5. Copy the **bot token** BotFather replies with. Looks like `1234567890:AAH…`.

Then get your own user ID:

1. Search for **@userinfobot** and start a chat.
2. Send `/start`.
3. Copy the **Id** number (e.g. `123456789`).

Keep both values handy — you'll paste them into a `.env` file in a moment.

---

## Step 2 — Clone NanoClaw into the workspace

From the **Host** tab:

```bash
cd ./project/nanoclaw-telegram
git clone git@github.com:qwibitai/nanoclaw.git nanoclaw
cd nanoclaw
git checkout 47ad2e6     # pinned to the commit this lab was tested against
cd ../..
```

If you don't have SSH set up for GitHub, use HTTPS:

```bash
git clone https://github.com/qwibitai/nanoclaw.git project/nanoclaw-telegram/nanoclaw
(cd project/nanoclaw-telegram/nanoclaw && git checkout 47ad2e6)
```

---

## Step 3 — Write the `.env` file

```bash
cat > project/nanoclaw-telegram/nanoclaw/.env <<EOF
TELEGRAM_BOT_TOKEN=<paste-bot-token>
TELEGRAM_USER_ID=<paste-user-id>
ANTHROPIC_API_KEY=proxy-managed
EOF
```

Replace the two placeholders. Leave `ANTHROPIC_API_KEY=proxy-managed` as the
literal string — that's the cue to NanoClaw that the real key is injected
upstream.

---

## Step 4 — Create the sandbox

```bash
sbx create shell --name nanoclaw-demo ./project/nanoclaw-telegram
```

`shell` is the generic sandbox type — no specific agent pre-baked. You get a
Debian-based microVM with Docker, Node, and git available.

---

## Step 5 — Open the network policy

This scenario needs three categories of outbound access. Add them all now
before the bot tries to start:

```bash
# Telegram bot API
sbx policy allow network api.telegram.org

# Debian package repos (the agent container image is built inside the VM)
sbx policy allow network "deb.debian.org:80,security.debian.org:80"
sbx policy allow network "*.debian.org"
```

`api.anthropic.com` is already on the default allow list — the Claude agent
containers NanoClaw spawns will reach it through there.

---

## Step 6 — Install, patch, build (inside the sandbox)

Open an interactive shell in the sandbox:

```bash
sbx run nanoclaw-demo
```

Once you're in the VM, `cd` to the workspace and install:

```bash
cd /workspace/nanoclaw-telegram/nanoclaw
npm install
```

Then apply the Docker-Sandbox-specific patches (trust the proxy CA, forward
proxy env to nested containers, teach grammy about the proxy agent):

```bash
bash ../sandbox-patch.sh
```

Expected output: a few `[sandbox-patch]` lines, each patch applied or
"already patched, skipping".

Build NanoClaw:

```bash
npm run build
```

Then build the agent container image — this is the image each incoming
Telegram message spawns for its Claude session:

```bash
./container/build.sh
```

Takes 1–2 minutes; at the end you should see
`Successfully tagged nanoclaw-agent:latest`.

Leave the sandbox shell open for the next step.

---

## Step 7 — Start NanoClaw

Still inside the sandbox:

```bash
cd /workspace/nanoclaw-telegram
./start-nanoclaw.sh
```

Expected output:

```
Starting Docker daemon…
Docker is ready.
Building agent container…
Registering main group for Telegram user <your-id>…
Starting NanoClaw…
[nanoclaw] Telegram adapter initialized
[nanoclaw] Listening for messages from @<your-bot>
[nanoclaw] ANTHROPIC_API_KEY: proxy-managed ← will be injected by proxy
```

---

## Step 8 — Talk to your bot

On your phone, open Telegram and send your bot a message:

```
Hello! Can you help me write a Python sorting function?
```

Within a few seconds you should see Claude's reply appear in the Telegram
chat. What just happened under the hood:

```
Your phone
    → Telegram servers
    → api.telegram.org
    → Sandbox proxy (allowed — we added api.telegram.org)
    → NanoClaw (inside the sandbox)
    → docker run nanoclaw-agent (inside the sandbox)
    → Claude inside that nested container
    → HTTPS → api.anthropic.com (no Authorization header!)
    → Sandbox proxy injects the Authorization from your host keychain
    → Anthropic → reply flows back the reverse way
```

Two container boundaries, one proxy, zero secrets leaked.

---

## Step 9 — Prove the key cascade

From a **new Host tab session** (leave NanoClaw running):

```bash
# Host: no key visible here? (depends on your shell — the point is it's not coming *from* here)
env | grep ANTHROPIC_API_KEY

# Sandbox env: completely empty
sbx exec nanoclaw-demo env | grep ANTHROPIC_API_KEY

# Inside the *nested* agent container: .env shows the placeholder string
sbx exec nanoclaw-demo -- bash -c \
  "cat /workspace/nanoclaw-telegram/nanoclaw/.env | grep ANTHROPIC_API_KEY"
```

That last line should literally print `ANTHROPIC_API_KEY=proxy-managed`.
Claude's agent container reads that file, sends the string upstream, and the
proxy swaps it for the real key *on the way out*. At every layer a curious
attacker could look, the real key is absent.

---

## Step 10 — Audit

```bash
sbx network log nanoclaw-demo
```

You'll see `api.telegram.org`, `api.anthropic.com`, and Debian repo
connections. If the agent container tried to phone home anywhere else, it
would appear here — blocked.

---

## Cleanup

```bash
# From the host — stop NanoClaw in the sandbox
sbx exec nanoclaw-demo -- pkill -f nanoclaw || true

# Or kill the whole sandbox
sbx stop nanoclaw-demo
sbx rm nanoclaw-demo      # only if you want to release the disk
```

---

## What you just proved

| Point | Evidence |
|---|---|
| Docker Sandboxes aren't just for coding agents | NanoClaw is a Telegram bot in Node.js — same isolation, same tooling |
| Nested containers inherit the proxy | The agent containers spawned inside the sandbox still route through the host proxy |
| Key injection works across two boundaries | `ANTHROPIC_API_KEY=proxy-managed` was the literal value in every container's env; the real key was injected at the HTTP layer |
| Audit is the whole sandbox, not just the top process | `sbx network log` shows nested container connections too |

Next: **Wrap-up** — what all three scenarios mean together.
