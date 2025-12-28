#!/bin/bash
# Start the Para MCP Server in HTTP mode (for web access)

cd "$(dirname "$0")"

echo "=== Starting Para MCP Server (HTTP Mode) ==="
echo ""

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
else
    echo "Error: Virtual environment not found. Run:"
    echo "  python3.10 -m venv venv"
    echo "  source venv/bin/activate"
    echo "  pip install -r requirements.txt"
    exit 1
fi

# Check environment variables
if [ -z "$PARA_HOME" ]; then
    export PARA_HOME=~/Documents/PARA
    echo "Using default PARA_HOME: $PARA_HOME"
fi

if [ -z "$PARA_ARCHIVE" ]; then
    export PARA_ARCHIVE=~/Documents/archive
    echo "Using default PARA_ARCHIVE: $PARA_ARCHIVE"
fi

# Enable HTTP mode
export USE_HTTP=true
export PORT=8000

echo ""
echo "Environment:"
echo "  PARA_HOME: $PARA_HOME"
echo "  PARA_ARCHIVE: $PARA_ARCHIVE"
echo "  USE_HTTP: $USE_HTTP"
echo "  PORT: $PORT"
echo ""
echo "Server starting in HTTP mode on http://0.0.0.0:8000"
echo "Access locally: http://localhost:8000"
echo "Access via tunnel: Your Cloudflare URL"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start the server in HTTP mode
python -m src.server
