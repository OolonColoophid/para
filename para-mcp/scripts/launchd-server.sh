#!/bin/bash
# Wrapper script for launchd to inherit shell environment

# Source environment variables
[ -f ~/.zshenv ] && source ~/.zshenv
[ -f ~/.zaliases ] && source ~/.zaliases
[ -f ~/.zapi_keys ] && source ~/.zapi_keys

# Change to MCP directory and run server
cd /Users/ianuser/repos/other/para/para-mcp
export USE_HTTP=true
export PORT=8000

exec ./venv/bin/python -m src.server
