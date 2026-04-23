# Wrap-up

You just drove three very different AI workloads through the same sandbox
boundary. Here's what to take away.

---

## The three scenarios, side by side

| | Scenario 1 | Scenario 2 | Scenario 3 |
|---|---|---|---|
| **Agent** | Claude Code | OpenCode | NanoClaw (Node.js) |
| **Model** | Claude | Kimi K2.5 | Claude |
| **Provider** | Anthropic | NVIDIA NIM | Anthropic |
| **Entry point** | `sbx run claude-demo` | VS Code → ACP | Telegram → bot |
| **Key storage** | host keychain | `opencode.json` | proxy-managed placeholder |
| **Nesting** | none | none | Docker-in-Docker |

Different agent, different model, different protocol, different entry point,
different key-storage strategy — **same sandbox primitives underneath**.

---

## The three security pillars (recap)

1. **Structural isolation.** Each sandbox is a microVM with its own kernel
   and filesystem. Escape requires compromising the VM boundary, not just a
   process or a namespace.
2. **Explicit networking.** Default-deny. Every domain the agent can reach
   was approved by you via `sbx policy allow network`. Everything else is
   refused at the proxy — you see it in `sbx network log`.
3. **Zero-secret containers.** Secrets live on the host (keychain, workspace
   config file), never in the sandbox env. The proxy injects auth at the HTTP
   layer, on the way out.

---

## Where the sandbox boundary sits

```
┌─ Your host ────────────────────────────────────────────────┐
│                                                            │
│   ANTHROPIC_API_KEY, NVIDIA key, Telegram token            │
│               ↓                                            │
│   sbx daemon ──→ host proxy ──→ api.anthropic.com          │
│      │                       ─→ integrate.api.nvidia.com   │
│      │                       ─→ api.telegram.org           │
│      │                                                     │
│      └──────────┐                                          │
│                 ▼                                          │
│   ┌────────────────────────────────────────────┐           │
│   │  microVM (sandbox)                         │           │
│   │    ┌──────────────────────────────────┐    │           │
│   │    │  agent process (Claude/OpenCode/ │    │           │
│   │    │  NanoClaw)                       │    │           │
│   │    │                                  │    │           │
│   │    │  env: no secrets visible         │    │           │
│   │    └──────────────────────────────────┘    │           │
│   │    (optionally spawns nested containers,   │           │
│   │     which inherit proxy config)            │           │
│   └────────────────────────────────────────────┘           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

The boundary isn't "container" and isn't "app-level permission check" — it's
a microVM with a mediating proxy. Applications, nested containers, and sub-
processes inside the microVM all share the same egress controls. The agent
is governed by the *sandbox*, not by its own good behavior.

---

## Where to go next

- **Read the sandbox configuration docs:** [docs.docker.com/go/sbx/](https://docs.docker.com/go/sbx/)
- **Build your own agent integration** over ACP — the stdio protocol we used
  in Scenario 2 works for any editor or app that can spawn a child process.
- **Tighten policy.** `sbx policy` has more than `allow network`. Look at
  filesystem mount policy, secret scoping, and branch-mode patterns for
  running multiple agents against the same repo.
- **Audit discipline.** `sbx network log` is the start, not the end. Pipe it
  into your SIEM and treat it like any other audit feed.

---

## Troubleshooting cheatsheet

**`sbx run` hangs or errors**
```bash
sbx ls                       # state of all sandboxes
sbx daemon restart           # usually fixes transient issues
```

**Network request unexpectedly blocked**
```bash
sbx network log <sandbox>    # see exactly what policy rule matched
sbx policy ls                # review what's allowed
sbx policy allow network <domain>
```

**Nested container doesn't see the proxy (scenario 3-style)**
- Confirm `HTTPS_PROXY` / `HTTP_PROXY` env vars are forwarded into the inner
  container via your `docker run` args.
- Confirm the proxy CA cert is mounted into the inner container and either
  trusted via `NODE_EXTRA_CA_CERTS` (Node) or added to the OS trust store.

**OpenCode 404 in scenario 2**
- Double-check the model ID in `opencode.json` matches what NVIDIA NIM
  serves (`moonshotai/kimi-k2.5`).
- Confirm `integrate.api.nvidia.com` is allowed in `sbx policy ls`.

---

That's the lab. Thanks for running through it.
