# Labspace for Docker Sandboxes (sbx)

An interactive lab for learning Docker Sandboxes — the microVM-based agent environment built by Docker.

<img width="1850" height="979" alt="image" src="https://github.com/user-attachments/assets/86bab658-04de-43d4-8f68-478a1a3f0da8" />

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Compose v2.36+ for provider services)
- [ttyd](https://github.com/tsl0922/ttyd): `brew install ttyd` (macOS) · `sudo apt install ttyd` (Linux)
- [sbx](https://github.com/docker/sbx-releases): `brew install docker/tap/sbx` (macOS) · see [docs](https://docs.docker.com/go/sbx/) for Linux

## Quick Start

```bash
git clone https://github.com/shelajev/labspace-sbx
cd labspace-sbx
CONTENT_PATH=$PWD docker compose up
```

Open http://localhost:3030

- **Left panel** → lab instructions
- **Right panel** → your host terminal with `sbx` ready to use

To stop: `docker compose down` (cleans up the host ttyd automatically).

## How the terminal is wired

The "Term 1 / Term 2" tabs iframe a **host** ttyd on port 8085. ttyd is a regular host process — we can't run it from a container because the whole point is to invoke `sbx` commands *against your host's sbx daemon and microVMs*.

To keep everything launchable with a single `docker compose up`, we use a [Compose provider service](https://docs.docker.com/compose/how-tos/provider-services/) — see `providers/sbx-ttyd`. On `compose up` the provider script checks prerequisites, starts ttyd as a daemonized host process, and emits the URL via the provider protocol. On `compose down` it stops the ttyd.

## What you'll learn

- **Why microVM isolation matters** for AI agents and how sbx's boundary differs from a container
- **The four layers of agent governance:** structural isolation, credential proxy injection, network policy enforcement, and audit logging
- **Running your first sandbox** and proving an agent cannot escape the VM — with real commands against real file paths
- **Reviewing agent changes** with Git worktrees before any code touches your working tree
- **Injecting secrets** into agents without ever exposing them to the VM
- **Enforcing network policy** at the proxy layer — and watching allowed and blocked connections in a live audit log
- **Branch mode and parallel agents** — running multiple autonomous agents on the same repo simultaneously, each governed by the same policy
- **Air-gapped agent workflows** — running open-source models locally with Docker Model Runner, zero cloud dependency
- **The enterprise architecture:** what it takes to govern 30,000 concurrent agent sessions across a workforce
