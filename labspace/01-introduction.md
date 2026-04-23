# Docker Sandboxes — Three Agent Demos

Three hands-on scenarios, each proving a different part of the Docker Sandboxes
(`sbx`) security story. You'll do them yourself — no pre-baked sandboxes, no
hidden scripts. By the end you'll have created, configured, and torn down three
sandboxes running three different real agents.

---

## What's in this lab

| Scenario | Agent | Sandbox type | What it proves |
|---|---|---|---|
| 1 | Claude Code | `claude` | Default-deny network · zero-secret containers · proxy-injected auth |
| 2 | OpenCode + NVIDIA NIM (Kimi K2.5) | `opencode` | Provider-agnostic isolation · editor integration via ACP · explicit allow-lists |
| 3 | NanoClaw (Telegram bot → Claude) | `shell` | Docker-in-Docker inside a sandbox · proxy key injection through nested containers · non-coding agents |

The three scenarios are independent. You can do them in any order after the
pre-flight, though the difficulty ramps: scenario 1 is ~5 minutes, 2 needs one
API key, 3 needs a Telegram bot and a few more minutes.

---

## The three tabs you'll use

Look at the tabs above this instructions panel:

- **Host** — a terminal on *your real machine*. This is where `sbx` runs. You'll
  use this tab for almost every command in the lab.
- **Claude** — a second host terminal pre-wired to drop you into
  `sbx run claude .` so you can quickly jump into a Claude session.
- **VS Code** — a browser-based VS Code with the `project/` directory of this
  lab mounted. Only needed for Scenario 2 (OpenCode over ACP).

All three are on your host — `sbx` is a host-level tool that manages microVMs
on your hardware, so there's nothing useful about running it from inside a
container.

---

## What `sbx` actually is

Docker Sandboxes is a CLI + daemon that creates **Linux microVMs** (not
containers) for running AI agents. Each sandbox has:

- Its own kernel, filesystem, and network namespace
- A proxy on the host that mediates every outbound connection
- Network policy: deny-by-default, explicit allow-lists per domain
- Secret injection: API keys live in the OS keychain, never inside the VM

An agent inside a sandbox runs as if it had root on its own machine — it
really does, within that microVM. What it *can't* do is reach your host
filesystem, read your real environment variables, or make network calls you
haven't approved.

---

## Ready?

Move to the next page for the pre-flight.
