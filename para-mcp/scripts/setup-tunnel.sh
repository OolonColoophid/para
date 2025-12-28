#!/bin/bash
# Setup script for Cloudflare Tunnel with PERMANENT URL
# This requires a Cloudflare account (free)
# For a simpler option with no setup, use ./start-quick-tunnel.sh instead

set -e

echo "=== Para MCP Server - Permanent Cloudflare Tunnel Setup ==="
echo ""
echo "This will create a PERMANENT Cloudflare Tunnel with a fixed URL."
echo "You'll get a permanent *.cfargotunnel.com URL that won't change."
echo ""
echo "REQUIREMENT: You need a Cloudflare account (free to create)."
echo "If you don't have one or want something simpler, use ./start-quick-tunnel.sh instead."
echo ""

# Check if already authenticated
if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo "Step 1: Authenticate with Cloudflare..."
    echo ""
    echo "This will open your browser. You need to:"
    echo "  1. Log in to Cloudflare (or create a free account)"
    echo "  2. Select ANY zone (if you don't have one, you can add a free domain)"
    echo "     Note: You don't need to actually use this domain for the tunnel"
    echo ""
    echo "Press Enter to continue..."
    read

    cloudflared tunnel login

    echo ""
    echo "✓ Authentication complete!"
    echo ""
fi

# Check if tunnel already exists
if cloudflared tunnel list 2>/dev/null | grep -q para-mcp; then
    echo "Tunnel 'para-mcp' already exists!"
    echo ""
    TUNNEL_ID=$(cloudflared tunnel list | grep para-mcp | awk '{print $1}')
    echo "Tunnel ID: $TUNNEL_ID"
else
    # Create tunnel
    echo "Creating tunnel 'para-mcp'..."
    cloudflared tunnel create para-mcp

    echo ""
    echo "✓ Tunnel created!"
    echo ""

    TUNNEL_ID=$(cloudflared tunnel list | grep para-mcp | awk '{print $1}')
    echo "Tunnel ID: $TUNNEL_ID"
fi

# Create config file
echo ""
echo "Creating tunnel configuration..."
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: ~/.cloudflared/$TUNNEL_ID.json

ingress:
  - service: http://localhost:8000
EOF

echo "✓ Configuration created at ~/.cloudflared/config.yml"
echo ""

# Step 4: Get the public URL
echo "=== Setup Complete! ==="
echo ""
echo "Your tunnel URL will be: https://$TUNNEL_ID.cfargotunnel.com"
echo ""
echo "Next steps:"
echo "1. Start everything: ./start-all.sh"
echo "   (or start separately with ./start-server-http.sh and ./start-tunnel.sh)"
echo ""
echo "2. Use this URL in Poke: https://$TUNNEL_ID.cfargotunnel.com"
echo ""
echo "The tunnel is now ready to use!"
