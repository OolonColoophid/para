#!/bin/bash
# Start the Para MCP Server

cd "$(dirname "$0")"

echo "=== Starting Para MCP Server ==="
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

echo ""
echo "Environment:"
echo "  PARA_HOME: $PARA_HOME"
echo "  PARA_ARCHIVE: $PARA_ARCHIVE"
echo ""

# Check if we should use HTTP mode (for web access)
if [ "$USE_HTTP" = "true" ]; then
    echo "Server starting in HTTP mode on http://0.0.0.0:8000"
    echo "Access via: http://localhost:8000"
else
    echo "Server starting in stdio mode (for MCP Inspector/Claude Code)"
fi

echo "Press Ctrl+C to stop"
echo ""

# Start the server
python -m src.server
