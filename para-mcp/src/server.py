#!/usr/bin/env python3
"""
Para MCP Server - Model Context Protocol server for Para CLI tool

Exposes all 13 para commands as MCP tools for use with Poke, Claude Code,
and other MCP clients.
"""

import json
import logging
import os
from typing import Any, Dict

from mcp_cloudflare_kit import MCPServer, CLIWrapper, ServerConfig

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("para-mcp")

# Server configuration
config = ServerConfig(
    name="para-mcp",
    port=int(os.environ.get("PORT", "8000")),
    api_key_env="PARA_API_KEY"
)

# Initialize MCP server and CLI wrapper
server = MCPServer("para-mcp-server", config)
para = CLIWrapper(
    cli_path="para",
    json_flag="--json",
    env_var="PARA_CLI_PATH",
    default_timeout=30
)


# Read-only tools

@server.tool(
    name="para_list",
    description="List all projects and/or areas in your PARA system. Optionally filter by type.",
    schema={
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
)
async def para_list(args: Dict[str, Any]) -> str:
    type_filter = args.get("type", "all")
    cmd_args = ["list"] if type_filter == "all" else ["list", type_filter]
    result = await para.run(cmd_args)
    return json.dumps(result, indent=2)


@server.tool(
    name="para_read",
    description="Read the entire journal.org file content for a specific project or area.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type of item: 'project' or 'area'"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_read(args: Dict[str, Any]) -> str:
    result = await para.run(["read", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_headings",
    description="Extract org-mode headings (* ...) from the journal file of a project or area.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type of item: 'project' or 'area'"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_headings(args: Dict[str, Any]) -> str:
    result = await para.run(["headings", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_search",
    description="Search for text in Para files with context. Fast full-text search using ripgrep.",
    schema={
        "type": "object",
        "properties": {
            "scope": {
                "type": "string",
                "enum": ["project", "area", "projects", "areas", "resources", "archive", "all"],
                "description": "Search scope"
            },
            "name": {"type": "string", "description": "Name of project/area (required when scope is 'project' or 'area')"},
            "query": {"type": "string", "description": "Search query text"},
            "context": {"type": "integer", "description": "Context lines before/after (default: 2)", "default": 2},
            "caseSensitive": {"type": "boolean", "description": "Case-sensitive search (default: false)", "default": False}
        },
        "required": ["scope", "query"]
    }
)
async def para_search(args: Dict[str, Any]) -> str:
    scope = args["scope"]
    cmd_args = ["search", scope]

    if scope in ["project", "area"]:
        if "name" not in args:
            return json.dumps({"error": f"'name' is required when scope is '{scope}'"}, indent=2)
        cmd_args.append(args["name"])

    cmd_args.append(args["query"])

    if args.get("context", 2) != 2:
        cmd_args.extend(["-C", str(args["context"])])
    if args.get("caseSensitive"):
        cmd_args.append("--case-sensitive")

    result = await para.run(cmd_args)
    return json.dumps(result, indent=2)


@server.tool(
    name="para_agenda",
    description="Export org-mode agenda from Para projects and areas. Shows TODOs, deadlines, and scheduled items.",
    schema={
        "type": "object",
        "properties": {
            "days": {"type": "integer", "description": "Days in agenda view (default: 7)", "default": 7},
            "project": {"type": "string", "description": "Limit to specific project"},
            "area": {"type": "string", "description": "Limit to specific area"},
            "scope": {"type": "string", "enum": ["projects", "areas", "all"], "description": "Scope (default: all)", "default": "all"}
        }
    }
)
async def para_agenda(args: Dict[str, Any]) -> str:
    cmd_args = ["agenda", "--days", str(args.get("days", 7))]

    if args.get("project"):
        cmd_args.extend(["--project", args["project"]])
    elif args.get("area"):
        cmd_args.extend(["--area", args["area"]])
    else:
        cmd_args.extend(["--scope", args.get("scope", "all")])

    result = await para.run(cmd_args)
    return json.dumps(result, indent=2)


@server.tool(
    name="para_environment",
    description="Display environment configuration and validate Para setup.",
    schema={"type": "object", "properties": {}}
)
async def para_environment(args: Dict[str, Any]) -> str:
    result = await para.run(["environment"])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_version",
    description="Get Para version information.",
    schema={"type": "object", "properties": {}}
)
async def para_version(args: Dict[str, Any]) -> str:
    result = await para.run(["version"])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_ai_overview",
    description="Get comprehensive documentation about Para for AI understanding.",
    schema={"type": "object", "properties": {}}
)
async def para_ai_overview(args: Dict[str, Any]) -> str:
    result = await para.run(["ai-overview"])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_directory",
    description="Get the absolute directory path for a specific project or area.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_directory(args: Dict[str, Any]) -> str:
    result = await para.run(["directory", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_path",
    description="Get PARA system paths (home, resources, archive, or path to a specific project/area).",
    schema={
        "type": "object",
        "properties": {
            "location": {"type": "string", "enum": ["home", "resources", "archive", "project", "area"], "description": "Location type"},
            "name": {"type": "string", "description": "Name (required if location is 'project' or 'area')"}
        },
        "required": ["location"]
    }
)
async def para_path(args: Dict[str, Any]) -> str:
    location = args["location"]
    if location in ["project", "area"]:
        if "name" not in args:
            return json.dumps({"error": f"'name' is required when location is '{location}'"}, indent=2)
        result = await para.run(["path", location, args["name"]])
    else:
        result = await para.run(["path", location])
    return json.dumps(result, indent=2)


# Write tools

@server.tool(
    name="para_create",
    description="Create a new project or area in your PARA system.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type to create"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_create(args: Dict[str, Any]) -> str:
    result = await para.run(["create", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_archive",
    description="Archive a completed project or area by moving it to PARA_ARCHIVE.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type to archive"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_archive(args: Dict[str, Any]) -> str:
    result = await para.run(["archive", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_delete",
    description="Permanently delete a project or area. This action cannot be undone.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type to delete"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_delete(args: Dict[str, Any]) -> str:
    result = await para.run(["delete", args["type"], args["name"]])
    return json.dumps(result, indent=2)


# Metadata tools

@server.tool(
    name="para_open",
    description="Get the path to the journal.org file for a project or area.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_open(args: Dict[str, Any]) -> str:
    result = await para.run(["directory", args["type"], args["name"]])
    if isinstance(result, dict) and "path" in result:
        result["journalPath"] = f"{result['path']}/journal.org"
        result["note"] = "In server context, this returns the path. Use a client to actually open the file."
    return json.dumps(result, indent=2)


@server.tool(
    name="para_reveal",
    description="Get the directory path for a project or area.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project or area"}
        },
        "required": ["type", "name"]
    }
)
async def para_reveal(args: Dict[str, Any]) -> str:
    result = await para.run(["directory", args["type"], args["name"]])
    if isinstance(result, dict):
        result["note"] = "In server context, this returns the path. Use a client to actually reveal the folder."
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    logger.info("Starting Para MCP Server...")
    logger.info(f"Para CLI path: {para.cli_path}")
    logger.info(f"PARA_HOME: {os.environ.get('PARA_HOME', 'not set')}")
    logger.info(f"PARA_ARCHIVE: {os.environ.get('PARA_ARCHIVE', 'not set')}")
    server.run()
