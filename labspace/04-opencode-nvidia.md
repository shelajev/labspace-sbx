# Scenario 2 — OpenCode + NVIDIA NIM via ACP

**Workspace:** `project/opencode-kimi/`
**Sandbox type:** `opencode`
**Time:** ~10 minutes

Same sandbox model, different agent, different model provider, different
entry point. This scenario shows that Docker Sandboxes are a **substrate**,
not a single-vendor lock-in:

- The agent is **OpenCode** (not Claude).
- The model is **Kimi K2.5** served over **NVIDIA NIM** (not Anthropic).
- The editor is **VS Code**, talking to the sandboxed agent over the
  **Agent Client Protocol (ACP)** — the same protocol Zed uses natively.

What Zed gets for free, any editor can get via an ACP client. OpenCode, Claude
Code, Copilot-style agents — anything that speaks ACP plugs into the same
sandbox boundary.

---

## Step 1 — Get a NVIDIA Build API key

In your host browser:

1. Go to [build.nvidia.com](https://build.nvidia.com) and sign in (or sign up).
2. Open [build.nvidia.com/settings/api-keys](https://build.nvidia.com/settings/api-keys).
3. Click **Generate API Key** and copy it (starts with `nvapi-…`).

---

## Step 2 — Put the key into `opencode.json`

Unlike Anthropic (keychain-backed, proxy-injected), OpenCode reads its
provider credentials from a JSON file in the workspace. That file lives
inside the sandboxed workspace directory, so the key still never touches
your host env.

From the **Host** tab:

```bash
# Replace YOUR_NVIDIA_API_KEY below
sed -i '' 's/"apiKey": ".*"/"apiKey": "YOUR_NVIDIA_API_KEY"/' \
  ./project/opencode-kimi/opencode.json
```

On Linux, drop the `''` after `-i`:

```bash
sed -i 's/"apiKey": ".*"/"apiKey": "YOUR_NVIDIA_API_KEY"/' \
  ./project/opencode-kimi/opencode.json
```

Verify:

```bash
cat ./project/opencode-kimi/opencode.json
```

You should see the real key where the placeholder was.

---

## Step 3 — Create the sandbox

```bash
sbx create opencode --name opencode-demo ./project/opencode-kimi
```

`sbx create opencode` is the OpenCode-flavored template — pre-configured with
the OpenCode CLI and related plumbing.

---

## Step 4 — Allow only what this agent needs

The default policy blocks `integrate.api.nvidia.com` (it's not a standard dev
service). Add it explicitly:

```bash
sbx policy allow network integrate.api.nvidia.com
```

Confirm:

```bash
sbx policy ls
```

---

## Step 5 — Give the workspace a git repo

OpenCode expects a git repo in its workspace. Initialize one inside the
sandbox (not on the host — we want this scoped to the sandboxed copy):

```bash
sbx exec opencode-demo -- bash -c \
  "cd /workspace/opencode-kimi && git init && git add -A && git commit -m 'init'"
```

---

## Step 6 — Install the ACP extension in VS Code

Switch to the **VS Code** tab above. You're looking at a code-server instance
with the labspace `project/` directory open.

1. Click the **Extensions** icon in the left sidebar (or Ctrl+Shift+X).
2. Search for **`formulahendry.acp-client`** ("ACP Client" by Jun Han).
3. Install it.

> **Heads-up — known rough edge:** This lab's VS Code runs inside a
> container, and the ACP extension spawns the agent as a child process
> *inside that container*. The `sbx` CLI is a host tool, so this only works
> out of the box if you're using VS Code **installed on your host**, with
> this lab's `project/` directory open there. If you want to do this
> scenario from your host VS Code instead, skip ahead to Step 7 with those
> tweaks in mind. We'll fix the container-side plumbing in a follow-up to
> this lab — track the issue in the repo if you hit it.

---

## Step 7 — Configure the ACP agent

Open VS Code settings (JSON form) — Ctrl+Shift+P → "Preferences: Open User
Settings (JSON)". Add:

```json
{
  "acpClient.agents": [
    {
      "id": "opencode-nvidia",
      "name": "OpenCode @ NVIDIA NIM (sandboxed)",
      "command": "/home/coder/project/opencode-kimi/opencode-nvidia-sandbox.sh"
    }
  ]
}
```

On your host VS Code, that path becomes
`<path-to-labspace>/project/opencode-kimi/opencode-nvidia-sandbox.sh`.

Open the wrapper script — it's short:

```bash
cat ./project/opencode-kimi/opencode-nvidia-sandbox.sh
```

It runs `sbx exec -i -w <workspace> opencode-demo opencode acp`. That's all
the ACP "integration" is: **spawn the sandboxed agent in ACP mode, let stdin
and stdout do the rest**. No special SDK, no vendor lock-in.

> If you copied the wrapper out of the lab's `project/` directory, it still
> expects sandbox name `opencode-opencode-kimi`. Edit the `SANDBOX=` line at
> the top to `opencode-demo` (matching what you created in step 3).

---

## Step 8 — Open an ACP session and ask Kimi

In VS Code, open the Command Palette → "ACP: New Thread" (or use the
extension's sidebar icon). Pick **OpenCode @ NVIDIA NIM (sandboxed)**.

In the thread, ask:

```
What model are you? Summarize what Kimi K2.5 is good at.
```

You should get an answer identifying Kimi K2.5 (200K context, multimodal,
agentic coding). Every token went over `integrate.api.nvidia.com` from
inside your sandbox.

---

## Step 9 — Prove the key is scoped to the sandbox

From the Host tab:

```bash
sbx exec opencode-demo env | grep -i NVIDIA
```

Nothing in the env. The key is in `opencode.json` inside the workspace,
readable by OpenCode but not exported to the environment. And it's scoped
to this one sandbox — other sandboxes (including your Claude one from
scenario 1) can't read it.

```bash
grep -i nvidia /proc/*/environ 2>/dev/null   # on your host — empty
```

Your host shell doesn't have it either.

---

## Step 10 — See the audit trail

```bash
sbx network log opencode-demo
```

You'll see only `integrate.api.nvidia.com` connections. Any other destination
is refused. If Kimi started trying to exfiltrate to `evil.com`, the policy
would block it *and* you'd see the attempt in this log.

---

## What you just proved

| Point | Evidence |
|---|---|
| sbx is model/provider-agnostic | Kimi K2.5 over NVIDIA NIM works with the same CLI, same policy surface |
| ACP is the editor bridge | VS Code talked to a sandboxed agent through a standard stdio protocol |
| Keys stay scoped | NVIDIA key lives in `opencode.json`, not in host env, not in sandbox env |
| Allow-list is explicit | `sbx policy allow network integrate.api.nvidia.com` was the only thing we added |

Next: **Scenario 3 — NanoClaw on Telegram**. Hardest one — Docker-in-Docker,
agent containers, and a real Telegram bot.
