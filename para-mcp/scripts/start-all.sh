#!/bin/bash
# Start both MCP server and Cloudflare tunnel using tmux

cd "$(dirname "$0")"

echo "=== Starting Para MCP Server + Cloudflare Tunnel ==="
echo ""

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "Error: tmux not found. Install with: brew install tmux"
    echo ""
    echo "Or run in separate terminals:"
    echo "  Terminal 1: ./start-server.sh"
    echo "  Terminal 2: ./start-tunnel.sh"
    exit 1
fi

# Check if tunnel is configured
if [ ! -f ~/.cloudflared/config.yml ]; then
    echo "Error: Tunnel not configured. Run ./setup-tunnel.sh first"
    exit 1
fi

# Create or attach to tmux session
SESSION="para-mcp"

if tmux has-session -t $SESSION 2>/dev/null; then
    echo "Session already running. Attaching..."
    tmux attach -t $SESSION
else
    echo "Creating new tmux session..."
    echo ""

    # Create session with first window for MCP server
    tmux new-session -d -s $SESSION -n "mcp-server" "cd $(pwd) && ./start-server-http.sh"

    # Create second window for tunnel
    tmux new-window -t $SESSION -n "tunnel" "cd $(pwd) && ./start-tunnel.sh"

    # Select first window
    tmux select-window -t $SESSION:0

    echo "✓ Started in tmux session '$SESSION'"
    echo ""
    echo "Commands:"
    echo "  tmux attach -t $SESSION     # Attach to session"
    echo "  Ctrl+B then D               # Detach from session"
    echo "  Ctrl+B then N               # Next window"
    echo "  Ctrl+B then P               # Previous window"
    echo "  tmux kill-session -t $SESSION  # Stop everything"
    echo ""
    echo "Attaching to session..."
    sleep 2

    tmux attach -t $SESSION
fi
