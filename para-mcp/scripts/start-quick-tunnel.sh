#!/bin/bash
# Quick Cloudflare Tunnel - No setup required!
# The URL will change each time you restart, but this requires zero configuration

echo "=== Starting Quick Cloudflare Tunnel ==="
echo ""
echo "This will create a temporary tunnel with a random trycloudflare.com URL."
echo "No setup or authentication required!"
echo ""
echo "Note: The URL will change each time you restart the tunnel."
echo "For a permanent URL, use ./setup-tunnel.sh instead (requires Cloudflare account)."
echo ""
echo "Starting tunnel to http://localhost:8000..."
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start quick tunnel
cloudflared tunnel --url http://localhost:8000
