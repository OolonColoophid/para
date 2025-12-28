#!/usr/bin/env python3
"""
Quick test script to verify para commands work
"""

import subprocess
import json
import os

# Set up environment
os.environ.setdefault("PARA_HOME", os.path.expanduser("~/Documents/PARA"))
os.environ.setdefault("PARA_ARCHIVE", os.path.expanduser("~/Documents/archive"))

def test_para_command():
    """Test that para CLI is accessible and returns JSON"""
    cmd = ["para", "version", "--json"]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        data = json.loads(result.stdout)
        print("✓ Para CLI is working")
        print(f"  Version: {data.get('version')}")
        print(f"  Build: {data.get('build')}")
        return True
    else:
        print("✗ Para CLI failed")
        print(f"  Error: {result.stderr}")
        return False

def test_server_import():
    """Test that the server can be imported"""
    try:
        from src.server import app, list_tools
        print("✓ Server module imports successfully")
        return True
    except Exception as e:
        print(f"✗ Server import failed: {e}")
        return False

def test_list_tools():
    """Test that tools are defined correctly"""
    try:
        from src.server import list_tools
        import asyncio

        tools = asyncio.run(list_tools())
        print(f"✓ Found {len(tools)} tools:")
        for tool in tools:
            print(f"  - {tool.name}: {tool.description[:60]}...")
        return True
    except Exception as e:
        print(f"✗ List tools failed: {e}")
        return False

if __name__ == "__main__":
    print("Testing Para MCP Server\n")

    all_pass = True
    all_pass &= test_para_command()
    all_pass &= test_server_import()
    all_pass &= test_list_tools()

    print("\n" + ("="*50))
    if all_pass:
        print("✓ All tests passed!")
        print("\nTo run the server:")
        print("  python -m src.server")
        print("\nTo test with MCP Inspector:")
        print("  npx @modelcontextprotocol/inspector python -m src.server")
    else:
        print("✗ Some tests failed")
        exit(1)
