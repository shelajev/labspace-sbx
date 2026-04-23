# Labspace — Docker Sandboxes Agent Demos

An interactive lab that walks you through three real AI-agent workloads
running inside Docker Sandboxes (`sbx`) microVMs. You'll see default-deny
networking, proxy-injected secrets, and editor integrations in action against
three different agents, three different providers, and one sandbox substrate.

<img width="1850" height="979" alt="image" src="https://github.com/user-attachments/assets/86bab658-04de-43d4-8f68-478a1a3f0da8" />

## What you'll run

| Scenario | Agent | Provider | Entry point |
|---|---|---|---|
| 1 | Claude Code | Anthropic | `sbx run` |
| 2 | OpenCode | NVIDIA NIM / Kimi K2.5 | VS Code over ACP |
| 3 | NanoClaw (Telegram bot) | Anthropic | Telegram message → Docker-in-Docker |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Compose v2.36+ for provider services)
- [ttyd](https://github.com/tsl0922/ttyd): `brew install ttyd` (macOS) · `sudo apt install ttyd` (Linux)
- [sbx](https://github.com/docker/sbx-releases): `brew install docker/tap/sbx` (macOS) · see [docs](https://docs.docker.com/go/sbx/) for Linux
- An **Anthropic API key** on your host (`$ANTHROPIC_API_KEY`) for Scenarios 1 and 3
- *(Scenario 2)* A free [NVIDIA Build API key](https://build.nvidia.com/settings/api-keys)
- *(Scenario 3)* A Telegram account (to create a bot via @BotFather)

## Quick Start

```bash
git clone https://github.com/shelajev/labspace-sbx
cd labspace-sbx
echo "$ANTHROPIC_API_KEY" | sbx secret set -g anthropic
CONTENT_PATH=$PWD docker compose up
```

Open http://localhost:3030.

- **Left panel** → lab instructions
- **Right panel** → three tabs:
  - **Host** — a shell on your host, `sbx` on PATH, starting in the labspace dir
  - **Claude** — a second host shell pre-wired to `sbx run claude .`
  - **VS Code** — a browser VS Code with `project/` open (used in Scenario 2)

To stop: `docker compose down` (cleans up the host ttyd automatically).

## How the terminals are wired

The **Host** and **Claude** tabs iframe two **host-side ttyd** processes
(ports 8085 and 8086). They run on the host because `sbx` is a host tool —
putting them in a container would mean `sbx` commands acting against a
different `sbx` daemon than the one managing your real microVMs.

To keep everything launchable with a single `docker compose up`, we use a
[Compose provider service](https://docs.docker.com/compose/how-tos/provider-services/)
(`providers/sbx-ttyd`). The provider starts ttyd as a daemonized host
process on `compose up` and stops it on `compose down`.

The **VS Code** tab runs a containerized code-server
(`dockersamples/labspace-workspace-base`) on port 8080. It mounts the
labspace `project/` directory at `/home/coder/project`.

## Repo layout

```
labspace-sbx/
├── compose.yaml                  # includes oci://dockersamples/labspace-content-dev
├── compose.override.yaml         # tabs, workspace services, configurator config
├── providers/sbx-ttyd            # Compose provider that runs host-side ttyd
├── labspace/                     # lab instructions — rendered in the left panel
│   ├── labspace.yaml             # tabs + chapter manifest
│   └── 01..06-*.md               # six chapters: intro, pre-flight, 3 scenarios, wrap-up
└── project/                      # workspace files — mounted into VS Code and referenced by sbx
    ├── claude-demo/              # Scenario 1 workspace
    ├── opencode-kimi/            # Scenario 2 workspace (+ ACP wrapper)
    └── nanoclaw-telegram/        # Scenario 3 start / patch scripts
```

## Development

```bash
# Mac / Linux
CONTENT_PATH=$PWD docker compose up --watch

# Windows (PowerShell)
$Env:CONTENT_PATH = (Get-Location).Path; docker compose up --watch
```

`--watch` syncs local edits into the running containers, so chapter or
project changes show up immediately in the interface.
