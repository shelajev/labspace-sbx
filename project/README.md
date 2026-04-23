# Labspace: Running AI Agents Safely with Docker Sandboxes

This project contains three hands-on scenarios that demonstrate what
Docker Sandboxes (`sbx`) bring to real AI-agent workflows:

- **`claude-demo/`** — Claude Code in an isolated microVM. Proves default-deny
  networking, zero-secret containers, and proxy-injected auth.
- **`opencode-kimi/`** — OpenCode powered by NVIDIA NIM / Kimi K2.5, driven from
  VS Code over the Agent Client Protocol (ACP). Same sandbox, different
  provider, same security story.
- **`nanoclaw-telegram/`** — a Telegram-to-Claude bridge running Docker-in-Docker
  inside a shell sandbox. Proof that non-coding agents and nested containers
  inherit the same isolation and proxy key injection.

Follow the lab instructions in the left panel. Each scenario is self-contained;
you can do them in any order once the pre-flight is complete.
