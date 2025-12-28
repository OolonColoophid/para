#!/usr/bin/env python3
"""
Para MCP Server - Model Context Protocol server for Para CLI tool

Exposes all 13 para commands as MCP tools for use with Poke, Claude Code,
and other MCP clients.
"""

import asyncio
import json
import logging
import os
import subprocess
from typing import Any, Dict, List, Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.server.sse import SseServerTransport
from mcp.types import Tool, TextContent
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route, Mount
import contextlib
from typing import AsyncIterator

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("para-mcp")

# Para CLI executable path
PARA_CLI = os.environ.get("PARA_CLI_PATH", "para")


class ParaError(Exception):
    """Exception raised when para command fails"""
    pass


def run_para_command(args: List[str], check: bool = True) -> Dict[str, Any]:
    """
    Execute a para command and return the JSON output.

    Args:
        args: Command arguments (without 'para' prefix)
        check: Whether to raise exception on non-zero exit code

    Returns:
        Parsed JSON response from para

    Raises:
        ParaError: If command fails
    """
    cmd = [PARA_CLI] + args + ["--json"]
    logger.info(f"Executing: {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check,
            env=os.environ.copy()
        )

        # Try to parse JSON output
        if result.stdout.strip():
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                # If JSON parsing fails, return raw output
                return {"output": result.stdout, "raw": True}

        # If no stdout, return success status
        return {"success": True, "returncode": result.returncode}

    except subprocess.CalledProcessError as e:
        error_msg = e.stderr.strip() if e.stderr else str(e)
        logger.error(f"Para command failed: {error_msg}")
        raise ParaError(f"Para command failed: {error_msg}")
    except Exception as e:
        logger.error(f"Unexpected error running para: {e}")
        raise ParaError(f"Unexpected error: {str(e)}")


# Initialize FastMCP server
app = Server("para-mcp-server")


@app.list_tools()
async def list_tools() -> List[Tool]:
    """List all available para tools"""
    return [
        # Read-only tools
        Tool(
            name="para_list",
            description="List all projects and/or areas in your PARA system. Optionally filter by type.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area", "all"],
                        "description": "Filter by type: 'project', 'area', or 'all' (default: all)",
                        "default": "all"
                    }
                }
            }
        ),
        Tool(
            name="para_read",
            description="Read the entire journal.org file content for a specific project or area.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_headings",
            description="Extract org-mode headings (* ...) from the journal file of a project or area.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_search",
            description="Search for text in Para files with context. Fast full-text search using ripgrep.",
            inputSchema={
                "type": "object",
                "properties": {
                    "scope": {
                        "type": "string",
                        "enum": ["project", "area", "projects", "areas", "resources", "archive", "all"],
                        "description": "Search scope: 'project' (specific), 'area' (specific), 'projects' (all), 'areas' (all), 'resources', 'archive', or 'all'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area (required when scope is 'project' or 'area')"
                    },
                    "query": {
                        "type": "string",
                        "description": "Search query text"
                    },
                    "context": {
                        "type": "integer",
                        "description": "Number of context lines before/after each match (default: 2)",
                        "default": 2
                    },
                    "caseSensitive": {
                        "type": "boolean",
                        "description": "Whether to perform case-sensitive search (default: false)",
                        "default": false
                    }
                },
                "required": ["scope", "query"]
            }
        ),
        Tool(
            name="para_agenda",
            description="Export org-mode agenda from Para projects and areas. Shows TODOs, deadlines, and scheduled items.",
            inputSchema={
                "type": "object",
                "properties": {
                    "days": {
                        "type": "integer",
                        "description": "Number of days in agenda view (default: 7 for weekly view)",
                        "default": 7
                    },
                    "project": {
                        "type": "string",
                        "description": "Limit agenda to specific project name"
                    },
                    "area": {
                        "type": "string",
                        "description": "Limit agenda to specific area name"
                    },
                    "scope": {
                        "type": "string",
                        "enum": ["projects", "areas", "all"],
                        "description": "Scope: 'projects', 'areas', or 'all' (default: all)",
                        "default": "all"
                    }
                }
            }
        ),
        Tool(
            name="para_environment",
            description="Display environment configuration and validate Para setup (PARA_HOME, PARA_ARCHIVE, etc.).",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="para_version",
            description="Get Para version information.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="para_ai_overview",
            description="Get comprehensive documentation about Para for AI understanding, including all commands and usage.",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="para_directory",
            description="Get the absolute directory path for a specific project or area.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_path",
            description="Get PARA system paths (home, resources, archive, or path to a specific project/area).",
            inputSchema={
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "enum": ["home", "resources", "archive", "project", "area"],
                        "description": "Location type to get path for"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of project or area (required if location is 'project' or 'area')"
                    }
                },
                "required": ["location"]
            }
        ),
        # Write tools
        Tool(
            name="para_create",
            description="Create a new project or area in your PARA system. This will create the directory and journal.org file.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item to create: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area to create"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_archive",
            description="Archive a completed project or area by moving it to the PARA_ARCHIVE location.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item to archive: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area to archive"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_delete",
            description="Permanently delete a project or area. This action cannot be undone.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item to delete: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area to delete"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        # Metadata tools
        Tool(
            name="para_open",
            description="Get the path to the journal.org file for a project or area. In server context, returns the path.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area"
                    }
                },
                "required": ["type", "name"]
            }
        ),
        Tool(
            name="para_reveal",
            description="Get the directory path for a project or area. In server context, returns the path.",
            inputSchema={
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["project", "area"],
                        "description": "Type of item: 'project' or 'area'"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the project or area"
                    }
                },
                "required": ["type", "name"]
            }
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> List[TextContent]:
    """Handle tool calls by routing to appropriate para command"""

    try:
        # Route to appropriate handler based on tool name
        if name == "para_list":
            return await handle_list(arguments)
        elif name == "para_read":
            return await handle_read(arguments)
        elif name == "para_headings":
            return await handle_headings(arguments)
        elif name == "para_search":
            return await handle_search(arguments)
        elif name == "para_agenda":
            return await handle_agenda(arguments)
        elif name == "para_environment":
            return await handle_environment(arguments)
        elif name == "para_version":
            return await handle_version(arguments)
        elif name == "para_ai_overview":
            return await handle_ai_overview(arguments)
        elif name == "para_directory":
            return await handle_directory(arguments)
        elif name == "para_path":
            return await handle_path(arguments)
        elif name == "para_create":
            return await handle_create(arguments)
        elif name == "para_archive":
            return await handle_archive(arguments)
        elif name == "para_delete":
            return await handle_delete(arguments)
        elif name == "para_open":
            return await handle_open(arguments)
        elif name == "para_reveal":
            return await handle_reveal(arguments)
        else:
            raise ValueError(f"Unknown tool: {name}")

    except ParaError as e:
        return [TextContent(type="text", text=json.dumps({"error": str(e)}, indent=2))]
    except Exception as e:
        logger.error(f"Error handling tool {name}: {e}")
        return [TextContent(type="text", text=json.dumps({"error": f"Internal error: {str(e)}"}, indent=2))]


# Tool handler implementations

async def handle_list(args: Dict[str, Any]) -> List[TextContent]:
    """List projects and/or areas"""
    type_filter = args.get("type", "all")

    if type_filter == "all":
        result = run_para_command(["list"])
    else:
        result = run_para_command(["list", type_filter])

    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_read(args: Dict[str, Any]) -> List[TextContent]:
    """Read journal.org file"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["read", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_headings(args: Dict[str, Any]) -> List[TextContent]:
    """Get org-mode headings"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["headings", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_search(args: Dict[str, Any]) -> List[TextContent]:
    """Search for text in Para files"""
    scope = args["scope"]
    query = args["query"]
    context = args.get("context", 2)
    case_sensitive = args.get("caseSensitive", False)

    # Build command arguments
    cmd_args = ["search", scope]

    # Add name if searching specific project/area
    if scope in ["project", "area"]:
        name = args.get("name")
        if not name:
            return [TextContent(type="text", text=json.dumps({
                "error": f"'name' is required when scope is '{scope}'"
            }, indent=2))]
        cmd_args.append(name)

    # Add query
    cmd_args.append(query)

    # Add optional flags
    if context != 2:
        cmd_args.extend(["-C", str(context)])

    if case_sensitive:
        cmd_args.append("--case-sensitive")

    result = run_para_command(cmd_args)
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_agenda(args: Dict[str, Any]) -> List[TextContent]:
    """Export org-mode agenda"""
    days = args.get("days", 7)
    project = args.get("project")
    area = args.get("area")
    scope = args.get("scope", "all")

    # Build command arguments
    cmd_args = ["agenda", "--days", str(days)]

    # Handle project/area specific vs scope
    if project:
        cmd_args.extend(["--project", project])
    elif area:
        cmd_args.extend(["--area", area])
    else:
        cmd_args.extend(["--scope", scope])

    result = run_para_command(cmd_args)
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_environment(args: Dict[str, Any]) -> List[TextContent]:
    """Get environment configuration"""
    result = run_para_command(["environment"])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_version(args: Dict[str, Any]) -> List[TextContent]:
    """Get version information"""
    result = run_para_command(["version"])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_ai_overview(args: Dict[str, Any]) -> List[TextContent]:
    """Get AI overview documentation"""
    result = run_para_command(["ai-overview"])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_directory(args: Dict[str, Any]) -> List[TextContent]:
    """Get directory path"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["directory", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_path(args: Dict[str, Any]) -> List[TextContent]:
    """Get PARA paths"""
    location = args["location"]

    if location in ["project", "area"]:
        if "name" not in args:
            raise ParaError(f"Parameter 'name' is required when location is '{location}'")
        name = args["name"]
        result = run_para_command(["path", location, name])
    else:
        result = run_para_command(["path", location])

    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_create(args: Dict[str, Any]) -> List[TextContent]:
    """Create new project or area"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["create", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_archive(args: Dict[str, Any]) -> List[TextContent]:
    """Archive project or area"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["archive", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_delete(args: Dict[str, Any]) -> List[TextContent]:
    """Delete project or area"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["delete", item_type, name])
    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_open(args: Dict[str, Any]) -> List[TextContent]:
    """Get journal file path"""
    item_type = args["type"]
    name = args["name"]

    # Use directory command to get path, then append journal.org
    result = run_para_command(["directory", item_type, name])
    if isinstance(result, dict) and "path" in result:
        result["journalPath"] = f"{result['path']}/journal.org"
        result["note"] = "In server context, this returns the path. Use a client to actually open the file."

    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def handle_reveal(args: Dict[str, Any]) -> List[TextContent]:
    """Get directory path (same as directory command)"""
    item_type = args["type"]
    name = args["name"]

    result = run_para_command(["directory", item_type, name])
    if isinstance(result, dict):
        result["note"] = "In server context, this returns the path. Use a client to actually reveal the folder."

    return [TextContent(type="text", text=json.dumps(result, indent=2))]


async def main():
    """Main entry point for the MCP server"""
    logger.info("Starting Para MCP Server...")
    logger.info(f"Para CLI path: {PARA_CLI}")
    logger.info(f"PARA_HOME: {os.environ.get('PARA_HOME', 'not set')}")
    logger.info(f"PARA_ARCHIVE: {os.environ.get('PARA_ARCHIVE', 'not set')}")

    # Check if we should run in HTTP mode
    use_http = os.environ.get("USE_HTTP", "false").lower() == "true"

    if use_http:
        # HTTP mode - for web access via Cloudflare Tunnel
        logger.info("Running in HTTP mode (SSE transport)")
        port = int(os.environ.get("PORT", "8000"))

        # Create SSE transport for Poke compatibility
        sse = SseServerTransport("/messages/")

        async def health_check(request):
            """Health check endpoint for testing"""
            return JSONResponse({
                "status": "ok",
                "service": "para-mcp-server",
                "transport": "sse",
                "sse_endpoint": "/sse",
                "messages_endpoint": "/messages/"
            })

        async def handle_sse(request):
            """Handle SSE connection for MCP"""
            async with sse.connect_sse(
                request.scope,
                request.receive,
                request._send
            ) as streams:
                await app.run(
                    streams[0],
                    streams[1],
                    app.create_initialization_options()
                )

        # Create Starlette app with SSE routes
        starlette_app = Starlette(
            routes=[
                Route("/", endpoint=health_check, methods=["GET"]),
                Route("/sse", endpoint=handle_sse, methods=["GET"]),
                Mount("/messages/", app=sse.handle_post_message),
            ],
        )

        import uvicorn
        # Default to localhost for security; use BIND_ALL_INTERFACES=true to allow LAN access
        bind_host = "0.0.0.0" if os.environ.get("BIND_ALL_INTERFACES") else "127.0.0.1"
        logger.info(f"Server listening on http://{bind_host}:{port}")
        logger.info(f"SSE endpoint: http://{bind_host}:{port}/sse")
        config = uvicorn.Config(starlette_app, host=bind_host, port=port, log_level="info")
        server = uvicorn.Server(config)
        await server.serve()
    else:
        # Stdio mode - for local MCP Inspector / Claude Code
        logger.info("Running in stdio mode")
        async with stdio_server() as (read_stream, write_stream):
            await app.run(
                read_stream,
                write_stream,
                app.create_initialization_options()
            )


if __name__ == "__main__":
    asyncio.run(main())
