#!/bin/bash
# Start the Cloudflare Tunnel

echo "=== Starting Cloudflare Tunnel ==="
echo ""

# Check if tunnel is configured
if [ ! -f ~/.cloudflared/config.yml ]; then
    echo "Error: Tunnel not configured. Run ./setup-tunnel.sh first"
    exit 1
fi

# Get tunnel URL
echo "Tunnel URL:"
cloudflared tunnel info para-mcp 2>/dev/null | grep -E "https://" || echo "Unable to retrieve URL. Check with: cloudflared tunnel info para-mcp"
echo ""

echo "Starting tunnel..."
echo "Press Ctrl+C to stop"
echo ""

# Run the tunnel
cloudflared tunnel run para-mcp
