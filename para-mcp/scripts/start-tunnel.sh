#!/bin/bash
# Start the Cloudflare Tunnel in background mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$(dirname "$SCRIPT_DIR")"
TUNNEL_LOG="$MCP_DIR/.tunnel.log"
TUNNEL_PID_FILE="$MCP_DIR/.tunnel.pid"

# Check if tunnel is configured
if [ ! -f ~/.cloudflared/config.yml ]; then
    echo "Error: Tunnel not configured. Run setup-tunnel.sh first" >&2
    exit 1
fi

# Check if tunnel is already running
if [ -f "$TUNNEL_PID_FILE" ]; then
    OLD_PID=$(cat "$TUNNEL_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Error: Tunnel already running (PID: $OLD_PID)" >&2
        exit 1
    fi
    rm -f "$TUNNEL_PID_FILE"
fi

# Get tunnel URL from config file
CONFIG_FILE="$HOME/.cloudflared/config.yml"
HOSTNAME=$(grep -E "^\s*-?\s*hostname:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*hostname:\s*//' | tr -d ' ')
if [ -z "$HOSTNAME" ]; then
    echo "Error: Could not determine tunnel hostname from $CONFIG_FILE" >&2
    exit 1
fi
TUNNEL_URL="https://$HOSTNAME"

# Clear old log
> "$TUNNEL_LOG"

# Start tunnel in background
cloudflared tunnel run para-mcp >> "$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

# Save PID
echo "$TUNNEL_PID" > "$TUNNEL_PID_FILE"

# Wait for tunnel to establish connection (up to 10 seconds)
echo "Waiting for tunnel connection..." >&2
CONNECTED=false
for i in {1..20}; do
    sleep 0.5

    # Check if process died
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
        echo "Error: Tunnel process exited unexpectedly" >&2
        echo "--- Tunnel log ---" >&2
        tail -20 "$TUNNEL_LOG" >&2
        rm -f "$TUNNEL_PID_FILE"
        exit 1
    fi

    # Check for successful connection in logs
    if grep -q "Registered tunnel connection" "$TUNNEL_LOG" 2>/dev/null; then
        CONNECTED=true
        break
    fi

    # Also check for connection errors
    if grep -q "failed to connect" "$TUNNEL_LOG" 2>/dev/null; then
        echo "Error: Tunnel failed to connect" >&2
        echo "--- Tunnel log ---" >&2
        tail -20 "$TUNNEL_LOG" >&2
        kill "$TUNNEL_PID" 2>/dev/null
        rm -f "$TUNNEL_PID_FILE"
        exit 1
    fi
done

if [ "$CONNECTED" != "true" ]; then
    echo "Warning: Could not verify tunnel connection (may still be connecting)" >&2
    echo "Check logs: $TUNNEL_LOG" >&2
fi

# Verify local server is reachable (if running)
if curl -s --max-time 2 http://localhost:8000/ > /dev/null 2>&1; then
    echo "Local server verified at localhost:8000" >&2
else
    echo "Warning: Local server not responding at localhost:8000" >&2
fi

# Test tunnel connectivity (quick check)
echo "Testing tunnel connectivity..." >&2
TUNNEL_RESPONSE=$(curl -s --max-time 5 "$TUNNEL_URL/" 2>&1)
if echo "$TUNNEL_RESPONSE" | grep -q '"status":"ok"' 2>/dev/null; then
    echo "Tunnel verified: $TUNNEL_URL" >&2
else
    echo "Warning: Tunnel health check failed or timed out" >&2
    echo "Response: $TUNNEL_RESPONSE" >&2
    echo "The tunnel may still be initializing. Check: $TUNNEL_URL" >&2
fi

# Output the URL (this is captured by Swift)
echo "$TUNNEL_URL"
