# Scenario 1 — Claude in an Isolated Sandbox

**Workspace:** `project/claude-demo/`
**Sandbox type:** `claude`
**Time:** ~5 minutes

This is the warm-up. You'll create a sandbox for a tiny Python project, start
Claude inside it, and prove three things at once:

- Claude has network access *only* to the domains you explicitly allow
- The Anthropic API key is not inside the sandbox in any form — not in env
  vars, not in a config file, not anywhere Claude can read
- None of this stops Claude from doing its job

Use the **Host** tab for every command on this page unless noted otherwise.

---

## Step 1 — Create the sandbox

```bash
sbx create claude --name claude-demo ./project/claude-demo
```

`sbx create claude` creates a microVM pre-configured with Claude Code. The
`--name` gives it a stable handle; the final argument is the **host path** of
the workspace the sandbox will bind-mount inside the VM.

Verify it exists:

```bash
sbx ls
```

You should see `claude-demo` in the list, status `stopped` or `running`.

> **Why microVM, not container?** Containers share the host kernel. A
> microVM runs its own kernel — kernel-level exploits can't cross the
> boundary. `sbx` boots these VMs in under a second using
> [microVM tech](https://docs.docker.com/go/sbx/architecture/).

---

## Step 2 — Start Claude

```bash
sbx run claude-demo
```

On first run the CLI may auto-update Claude inside the VM (harmless — just
re-run if prompted), then show a trust prompt:

```
  Do you trust the contents of this directory?
› 1. Yes, continue
  2. No, quit
```

Choose `1`. Claude lands in `/workspace/claude-demo` inside the VM and
shows its usual prompt. **You're now typing to Claude, not to your shell.**

---

## Step 3 — Prove the network is locked down

Ask Claude to reach the open web:

```
curl amd.com for me please
```

Claude will try and report back something like:

```
Blocked by network policy: matched rule <default policy>
```

Try another domain:

```
try curling google.com
```

Same result. The sandbox's default policy is **deny everything except the
handful of domains sbx pre-allows for common dev work**. `amd.com` and
`google.com` aren't on that list.

Now ask Claude to install a Python package:

```
install httpx and tell me its version
```

It works. `pypi.org` and `files.pythonhosted.org` *are* on the default allow
list (under the `default-package-managers` policy group). You get governed
network access without having to approve every single dev domain up front.

> **The important bit:** the policy is enforced at the host-side proxy,
> outside the sandbox. Even if Claude is fully compromised by a prompt
> injection, it can't egress to a domain you haven't approved.

---

## Step 4 — Prove the API key isn't in the container

Ask Claude to inspect its own environment:

```
run: env | grep -i anthropic
```

Expected output: **nothing**. The variable doesn't exist.

```
now: env | grep -i api
```

Again nothing. No keys, no tokens, no secrets anywhere in the VM environment.

Yet Claude is actively calling `api.anthropic.com` to answer this very prompt.
How?

The **host-side proxy** intercepts Claude's outbound HTTPS. When Claude
calls `api.anthropic.com`, the proxy:

1. Reads your `anthropic` secret from the host OS keychain
2. Injects the `Authorization: Bearer …` header
3. Forwards the request upstream

Claude never sees the key. Even `cat /proc/*/environ` from inside the VM
won't reveal it, because **it's not there**. Claude talks to the proxy via
TLS MITM (the VM trusts a proxy CA baked in at boot), the proxy talks to
Anthropic with the real key.

---

## Step 5 — Watch Claude work normally

Give Claude a real task:

```
add memoization to the fibonacci function in main.py
```

Claude reads `main.py`, proposes changes, writes them. You can `/exit` Claude
(or press Ctrl+D) and inspect the result from the Host tab:

```bash
cat ./project/claude-demo/main.py
```

You should see `@lru_cache` decorators or a manual cache. The isolation did
not limit Claude's ability to do its job — it just limited what it could reach
if it went off the rails.

---

## Step 6 — Audit log

From the Host tab (while Claude is running or after), tail the network log:

```bash
sbx network log claude-demo
```

Every outbound connection the sandbox attempted — allowed and blocked — is
here. This is what an SRE team reviews when they're asked *"what did the
agent actually do on the network last night?"*.

---

## Cleanup (optional)

You can leave the sandbox around — it's cheap — or stop it:

```bash
sbx stop claude-demo
```

Or remove it entirely:

```bash
sbx rm claude-demo
```

---

## What you just proved

| Security pillar | How you saw it |
|---|---|
| **Structural isolation** | microVM, own kernel, own filesystem |
| **Network policy** | `amd.com` blocked, `pypi.org` allowed, all observable via `sbx network log` |
| **Zero-secret containers** | `env \| grep anthropic` returned nothing, yet API calls worked |
| **No performance or functionality cost** | Claude edited real files, installed real packages |

Next: **Scenario 2 — OpenCode + NVIDIA NIM over ACP**. Same sandbox model,
completely different agent and provider.
