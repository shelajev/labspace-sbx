# Pre-flight

Before starting any scenario, confirm your environment is ready. This takes
about 2 minutes.

---

## Step 1 — Verify `sbx` is installed

Switch to the **Host** tab and run:

```bash
sbx version
```

You should see a version string like `sbx 0.21.0` or similar. If you see
`command not found`:

```bash
# macOS
brew install docker/tap/sbx

# Linux
# See https://docs.docker.com/go/sbx/
```

---

## Step 2 — Log in to Docker

```bash
sbx login
```

The CLI prints a one-time code and a URL. Open the URL in a browser, confirm
the code, and you're in. You'll also be asked to pick a default network
policy — choose **Balanced** (default-deny, common dev sites pre-allowed).

---

## Step 3 — Store your Anthropic API key

Scenarios 1 and 3 use Claude. The key is stored in your **OS keychain** via
`sbx secret set` — it never lives in an env var the sandbox can read, and it
never gets written to a file.

```bash
echo "$ANTHROPIC_API_KEY" | sbx secret set -g anthropic
```

If `$ANTHROPIC_API_KEY` isn't set in your host shell yet, set it first from
the same tab:

```bash
read -s -p "ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY
echo "$ANTHROPIC_API_KEY" | sbx secret set -g anthropic
```

(Hit Enter after pasting the key; `-s` keeps it off the screen.)

Verify:

```bash
sbx secret ls
```

You should see `anthropic` in the list.

> Scenario 2 uses a NVIDIA Build API key. You'll collect that inside the
> scenario, not here — it lives in `opencode.json` instead of the keychain,
> scoped to a single sandbox.

---

## Step 4 — Confirm the labspace project directory

The three demo workspaces are already on disk, bundled with this labspace.
From the Host tab:

```bash
ls project/
# → claude-demo  nanoclaw-telegram  opencode-kimi
```

If you see those three directories, you're set. Every scenario will reference
paths under `project/`.

> Your Host tab starts in the labspace repo root. If `ls project/` fails, run
> `pwd` — if you're not in the labspace directory, `cd` there and try again.

---

## Step 5 — Optional: preview the tabs

- **Claude** tab — should show a shell ready to run `sbx run claude .`. If
  you open it now, it'll try to drop you into Claude using the default
  sandbox. Come back to it in Scenario 1.
- **VS Code** tab — should show a browser VS Code with `/home/coder/project`
  open. Only used in Scenario 2.

You're ready. Next: Scenario 1 — Claude in an Isolated Sandbox.
