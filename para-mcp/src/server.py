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
    description="List all projects, areas, and/or resources in your PARA system. Optionally filter by type.",
    schema={
        "type": "object",
        "properties": {
            "type": {
                "type": "string",
                "enum": ["project", "area", "resource", "all"],
                "description": "Filter by type: 'project', 'area', 'resource', or 'all' (default: all)",
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
    description="Read the main org file content for a project, area, or resource. Projects/areas use journal.org, resources use readme.org.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type of item: 'project', 'area', or 'resource'"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_read(args: Dict[str, Any]) -> str:
    result = await para.run(["read", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_headings",
    description="Extract org-mode headings (* ...) from the main file of a project, area, or resource.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type of item: 'project', 'area', or 'resource'"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
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
                "enum": ["project", "area", "resource", "projects", "areas", "resources", "archive", "all"],
                "description": "Search scope"
            },
            "name": {"type": "string", "description": "Name of project/area/resource (required when scope is 'project', 'area', or 'resource')"},
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

    if scope in ["project", "area", "resource"]:
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
    description="Get the absolute directory path for a specific project, area, or resource.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_directory(args: Dict[str, Any]) -> str:
    result = await para.run(["directory", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_path",
    description="Get PARA system paths (home, resources, archive, or path to a specific project/area/resource).",
    schema={
        "type": "object",
        "properties": {
            "location": {"type": "string", "enum": ["home", "resources", "archive", "project", "area", "resource"], "description": "Location type"},
            "name": {"type": "string", "description": "Name (required if location is 'project', 'area', or 'resource')"}
        },
        "required": ["location"]
    }
)
async def para_path(args: Dict[str, Any]) -> str:
    location = args["location"]
    if location in ["project", "area", "resource"]:
        if "name" not in args:
            return json.dumps({"error": f"'name' is required when location is '{location}'"}, indent=2)
        result = await para.run(["path", location, args["name"]])
    else:
        result = await para.run(["path", location])
    return json.dumps(result, indent=2)


# Write tools

@server.tool(
    name="para_create",
    description="Create a new project, area, or resource in your PARA system.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type to create"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_create(args: Dict[str, Any]) -> str:
    result = await para.run(["create", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_archive",
    description="Archive a completed project, area, or resource by moving it to PARA_ARCHIVE.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type to archive"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_archive(args: Dict[str, Any]) -> str:
    result = await para.run(["archive", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_delete",
    description="Permanently delete a project, area, or resource. This action cannot be undone.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type to delete"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_delete(args: Dict[str, Any]) -> str:
    result = await para.run(["delete", args["type"], args["name"]])
    return json.dumps(result, indent=2)


@server.tool(
    name="para_migrate",
    description="Migrate an item from one type to another (e.g., project to area, area to resource).",
    schema={
        "type": "object",
        "properties": {
            "from_type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Current type of the item"},
            "name": {"type": "string", "description": "Name of the item to migrate"},
            "to_type": {"type": "string", "enum": ["project", "area", "resource"], "description": "New type for the item"}
        },
        "required": ["from_type", "name", "to_type"]
    }
)
async def para_migrate(args: Dict[str, Any]) -> str:
    result = await para.run(["migrate", args["from_type"], args["name"], args["to_type"]])
    return json.dumps(result, indent=2)


# Metadata tools

@server.tool(
    name="para_open",
    description="Get the path to the main org file for a project, area, or resource.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
        },
        "required": ["type", "name"]
    }
)
async def para_open(args: Dict[str, Any]) -> str:
    item_type = args["type"]
    result = await para.run(["directory", item_type, args["name"]])
    if isinstance(result, dict) and "path" in result:
        # Resources use readme.org, projects/areas use journal.org
        main_file = "readme.org" if item_type == "resource" else "journal.org"
        result["mainFilePath"] = f"{result['path']}/{main_file}"
        result["note"] = "In server context, this returns the path. Use a client to actually open the file."
    return json.dumps(result, indent=2)


@server.tool(
    name="para_reveal",
    description="Get the directory path for a project, area, or resource.",
    schema={
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["project", "area", "resource"], "description": "Type of item"},
            "name": {"type": "string", "description": "Name of the project, area, or resource"}
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
