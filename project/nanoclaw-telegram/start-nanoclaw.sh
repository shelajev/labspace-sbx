#!/bin/bash
# Start NanoClaw Telegram bot inside the Docker Sandbox
# Usage: ./start-nanoclaw.sh
#
# Reads TELEGRAM_USER_ID from nanoclaw/.env (or pass as $1)
# to auto-register the main group on first run.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NANOCLAW_DIR="$SCRIPT_DIR/nanoclaw"

# --- Docker daemon ---
echo "Starting Docker daemon..."
sudo dockerd &>/tmp/dockerd.log &

echo "Waiting for Docker to be ready..."
for i in $(seq 1 30); do
    if docker info &>/dev/null; then
        echo "Docker is ready."
        break
    fi
    if [ "$i" = "30" ]; then
        echo "ERROR: Docker failed to start. Check /tmp/dockerd.log"
        exit 1
    fi
    sleep 1
done

# --- Build agent container ---
echo "Building agent container..."
cd "$NANOCLAW_DIR"
./container/build.sh

# --- Register main group if TELEGRAM_USER_ID is set ---
TELEGRAM_USER_ID="${1:-${TELEGRAM_USER_ID:-}}"

# Try to read from .env if not provided
if [ -z "$TELEGRAM_USER_ID" ] && [ -f "$NANOCLAW_DIR/.env" ]; then
    TELEGRAM_USER_ID=$(grep '^TELEGRAM_USER_ID=' "$NANOCLAW_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]"' || true)
fi

if [ -n "$TELEGRAM_USER_ID" ]; then
    echo "Registering main group for Telegram user $TELEGRAM_USER_ID..."
    node "$NANOCLAW_DIR/scripts/register-main-group.cjs" "$TELEGRAM_USER_ID"
else
    echo "Warning: No TELEGRAM_USER_ID set. Skipping main group registration."
    echo "  Set it in .env or pass as: ./start-nanoclaw.sh <user-id>"
fi

# --- Start NanoClaw ---
echo "Starting NanoClaw..."
npm start
