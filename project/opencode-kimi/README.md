# OpenCode + NVIDIA NIM (Kimi K2.5) Demo

This workspace runs OpenCode powered by **Kimi K2.5** via NVIDIA Build API.

## Model
- Provider: NVIDIA NIM
- Model: `moonshotai/kimi-k2.5` (200K context, multimodal)
- API: `https://integrate.api.nvidia.com/v1`

## What This Shows
- OpenCode running in an isolated Docker Sandbox
- Third-party LLM provider (not Anthropic) via NVIDIA NIM
- Same sandbox isolation benefits regardless of AI provider
- Zed editor → ACP protocol → sandboxed agent

## Quick Start (from Zed)
Press `Cmd+Shift+O` to open a new agent thread with opencode-sandbox.
