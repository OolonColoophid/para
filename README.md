# Para - A Command Line Tool for Managing Your PARA Productivity System

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Para is a command line tool designed to help you manage your personal productivity system based on the **PARA method**. It works with [Org mode](https://orgmode.org) files and is ideal for Emacs users who want a fast way to organize their work.

## What is PARA?

PARA is a simple organizational system created by Tiago Forte with four categories:

- **Projects**: Short-term efforts with a defined end goal (e.g., "Launch website", "Plan vacation")
- **Areas**: Ongoing responsibilities without an end date (e.g., "Health", "Finances", "Guitar practice")
- **Resources**: Reference materials and topics of interest (e.g., "Recipes", "Code snippets")
- **Archives**: Inactive items from the other categories

Para helps you manage the Projects and Areas portions of this system from the command line.

## Quick Start

```bash
# Install para
git clone https://github.com/OolonColoophid/para.git
cd para
./install.sh

# Set up your PARA folders (add to ~/.zshrc or ~/.bashrc)
export PARA_HOME=~/Documents/PARA
export PARA_ARCHIVE=~/Documents/Archive

# Create the directories
mkdir -p $PARA_HOME/projects $PARA_HOME/areas $PARA_ARCHIVE

# Start using para
para create project my-first-project
para list
para open project my-first-project
```

## Features

- Create new projects and areas
- Archive completed projects and areas
- Delete unwanted projects and areas
- List existing projects and areas
- Open projects and areas in the associated application (usually Emacs)

## Installation

### Automatic Installation (Recommended)

1. Clone the repository:

```bash
git clone https://github.com/OolonColoophid/para.git
cd para
```

2. Run the install script:

```bash
./install.sh
```

The script will build Para in release mode and install it to `/usr/local/bin/para`. You may be prompted for administrator privileges.

### Manual Installation

If you prefer to install manually:

```bash
# Build for release
xcodebuild -scheme para -configuration Release build

# Find and copy the binary (path may vary)
sudo cp [path-to-built-binary] /usr/local/bin/para
sudo chmod +x /usr/local/bin/para
```

## Configuration

Para relies on environment variables to determine the location of your PARA folders. Set these in your shell configuration file (e.g., `.bashrc`, `.zshrc`):

- `PARA_HOME`: Base directory for your PARA system (defaults to `~/Documents/PARA` if not set)
- `PARA_ARCHIVE`: Directory for archived projects/areas (defaults to `~/Documents/archive` if not set)

Example:
```bash
export PARA_HOME=~/Dropbox/PARA
export PARA_ARCHIVE=~/Dropbox/Archive
```

## Usage

```
USAGE: para <subcommand>

OPTIONS:
  -h, --help              Show help information.
  --version               Show the version.

SUBCOMMANDS:
  create                  Create a new project or area. Org category in-file
                          metadata will be set based on the name
  archive                 Archive an existing project or area.
  delete                  Delete a project or area
  list                    List existing Projects or Areas.
  open                    Open a project or area

  See 'para help <subcommand>' for detailed help.
```

### Examples

- Create a new project:
  ```
  para create project roofBuild
  ```

- Archive an area:
  ```
  para archive area guitar
  ```

- Delete a project:
  ```
  para delete project roofBuild
  ```

- List all areas:
  ```
  para list area
  ```

- Open a project:
  ```
  para open project roofBuild
  ```

## MCP Server Integration

Para includes a built-in [Model Context Protocol (MCP)](https://modelcontextprotocol.io) server that allows AI assistants like Claude to interact with your PARA system. The MCP server exposes all para commands through a simple HTTP interface, enabling AI assistants to create projects, list areas, read journals, and more.

### Setup

The MCP server is optional and requires Python 3.10 or later.

#### During Installation

When running `./install.sh`, you'll be prompted to set up the MCP server:

```bash
🐍 MCP Server Setup
   The Para MCP server enables AI assistants to interact with your Para system.
   Set up MCP server now? [y/N]:
```

Choose `y` to automatically create the Python virtual environment and install dependencies.

#### Manual Setup

If you skipped the setup during installation, you can set it up later:

```bash
para server-setup
```

To configure a permanent Cloudflare tunnel for remote access:

```bash
para server-setup --tunnel
```

### Server Commands

Para provides several commands for managing the MCP server:

#### Start Server

```bash
# Start server on default port (8000)
para server-start

# Start with custom port
para server-start --port 3000

# Start as background daemon
para server-start --background

# Start with quick temporary tunnel (trycloudflare.com)
para server-start --quick-tunnel

# Start with permanent configured tunnel
para server-start --tunnel
```

When started with `--quick-tunnel`, the server will output a public URL that you can use to connect from anywhere:

```
🚀 Starting Para MCP Server...
🌐 Server: http://localhost:8000
🔗 Tunnel: https://abc-def.trycloudflare.com
📋 Add to Poke: https://abc-def.trycloudflare.com/sse
```

#### Check Status

```bash
# View server status
para server-status

# Output status as JSON
para server-status --json
```

#### Stop Server

```bash
para server-stop
```

#### View Logs

```bash
# View recent logs
para server-logs

# Follow logs in real-time
para server-logs --follow

# Show last 50 lines
para server-logs --lines 50
```

### Using with AI Assistants

Once the server is running, you can connect it to AI assistants that support MCP:

1. **With Poke (Browser Extension)**:
   - Install the [Poke extension](https://poke.new)
   - Add the MCP endpoint: `http://localhost:8000/sse` (or the tunnel URL + `/sse` if using `--quick-tunnel`)
   - The assistant can now interact with your PARA system

2. **With Claude Desktop**:
   - Configure the MCP server in Claude Desktop settings
   - Point to `http://localhost:8000/sse`

3. **Remote Access**:
   - Use `para server-start --quick-tunnel` for temporary public URL
   - Use `para server-setup --tunnel` + `para server-start --tunnel` for permanent tunnel

### Available MCP Tools

The MCP server exposes these tools to AI assistants:

- `para_create` - Create new projects or areas
- `para_archive` - Archive existing items
- `para_delete` - Delete items permanently
- `para_list` - List projects, areas, or all items
- `para_open` - Open journal files
- `para_reveal` - Reveal items in Finder
- `para_terminal` - Open items in Terminal
- `para_read` - Read journal contents
- `para_headings` - Extract headings from journals
- `para_path` - Get paths to PARA directories

### Menu Bar App Integration

The Para menu bar app shows the MCP server status at the top of the menu:

- **When Stopped**: `○ MCP Server Stopped` (gray circle)
- **When Running**: `● MCP Server Running` (green circle)
  - Shows local server URL (clickable to copy)
  - Shows tunnel URL if active (clickable to copy)

The menu automatically updates every 2-3 seconds to reflect the current server state.

### Architecture

The MCP server is a Python application located in `para-mcp/` that uses:
- Python MCP SDK for protocol implementation
- Uvicorn for HTTP transport
- Server-Sent Events (SSE) transport (`/sse` endpoint)

The Para CLI manages the server lifecycle through Swift's `Foundation.Process` API, handling:
- Virtual environment creation
- Dependency installation
- Process spawning and PID tracking
- Graceful shutdown
- Tunnel management via Cloudflare

Version information:
- Para CLI version: Shown in `para version`
- MCP Server version: Defined in `para-mcp/pyproject.toml`

Both components version independently, allowing the MCP server to evolve separately from the CLI.

## Example Org Mode File

When a new project or area is created using the `para create` command, an Org mode file named `journal.org` is created inside the project or area folder.

Here's an example of the file name and its contents:

File name: `journal.org`

File contents:

```orgmode
#+TITLE: RoofBuild Project Journal
#+CATEGORY: RoofBuild
```

In this example, if you run the command `para create project roofBuild`, it will create a new folder named `roofBuild` inside the `projects` directory specified by `PARA_HOME`. Inside the `roofBuild` folder, a file named `journal.org` will be created with the contents shown above.

The `#+TITLE:` keyword in the Org mode file sets the title of the document, which includes the name of the project or area and the word "Journal". The `#+CATEGORY:` keyword sets the category of the document, which is the capitalized name of the project or area.

## Contributing

Contributions are welcome! Please:

1. Open an issue first for significant changes
2. Follow Swift coding conventions
3. Add tests when appropriate
4. Keep documentation up-to-date

See our [Code of Conduct](CODE_OF_CONDUCT.md) for more information about participating in this project.

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Para is released under the MIT License. See [LICENSE](LICENSE) for details.

## Documentation

For more detailed documentation about commands and configuration, see our [wiki](#) (coming soon).
