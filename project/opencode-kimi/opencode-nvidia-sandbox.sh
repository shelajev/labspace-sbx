#!/bin/bash
# opencode-nvidia-sandbox.sh
# Zed ACP wrapper: runs OpenCode with Kimi K2.5 via NVIDIA NIM in a Docker Sandbox
#
# This script uses the pre-configured sandbox 'opencode-opencode-kimi'
# which has opencode.json configured for NVIDIA NIM (moonshotai/kimi-k2.5).
#
# Install by symlinking into Zed's agents directory:
#   mkdir -p ~/.config/zed/agents
#   ln -s ~/sbx-demo/opencode-kimi/opencode-nvidia-sandbox.sh \
#         ~/.config/zed/agents/opencode-nvidia-sandbox.sh

SANDBOX="opencode-opencode-kimi"
WORKSPACE="$HOME/sbx-demo/opencode-kimi"
LOG="/tmp/opencode-nvidia-sandbox.log"

# Redirect ALL stderr to log — nothing should reach Zed except ACP JSON on stdout
exec 2>>"$LOG"

echo "$(date): starting opencode-nvidia (Kimi K2.5) in sandbox $SANDBOX" >>"$LOG"

# Verify sandbox exec works; recreate if stale
if ! sbx exec "$SANDBOX" true >>"$LOG" 2>&1; then
    echo "$(date): Sandbox stale or missing, recreating..." >>"$LOG"
    sbx rm "$SANDBOX" >>"$LOG" 2>&1 || true
    sbx create --name "$SANDBOX" opencode "$WORKSPACE" >>"$LOG" 2>&1
fi

# Copy opencode.json to global config so it survives sandbox restarts
sbx exec "$SANDBOX" bash -c "mkdir -p /home/agent/.config/opencode && cp $WORKSPACE/opencode.json /home/agent/.config/opencode/opencode.json" >>"$LOG" 2>&1

# Run OpenCode in ACP mode — reads opencode.json from workspace for NVIDIA NIM config
echo "$(date): launching opencode acp" >>"$LOG"
exec sbx exec -i -w "$WORKSPACE" "$SANDBOX" opencode acp
