# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Para is a command line tool for managing a PARA (Projects, Areas, Resources, Archives) productivity system. It works primarily with Org mode files and provides the following functionality:
- Create new projects and areas
- Archive completed projects and areas
- Delete unwanted projects and areas
- List existing projects and areas
- Open projects and areas in the associated application (usually Emacs)

## Building and Running

To build and install Para:

```bash
swift build -c release
mv .build/release/para /usr/local/bin/
```

## Running Tests

To run the tests:

```bash
swift test
```

To run a specific test:

```bash
swift test --filter ParaTests/testCreateFolder
```

## Environment Configuration

Para requires two environment variables:
- `PARA_HOME`: Base directory for your PARA system (defaults to `~/Documents/PARA` if not set)
- `PARA_ARCHIVE`: Directory for archived projects/areas (defaults to `~/Documents/archive` if not set)

Example configuration:
```bash
export PARA_HOME=~/Dropbox/PARA
export PARA_ARCHIVE=~/Dropbox/Archive
```

## Code Architecture

The application is structured as a Swift command-line tool using the ArgumentParser framework:

1. **Main Command Structure**: `Para` is the root command with subcommands for various operations.

2. **Subcommands**:
   - `Create`: Creates new project or area with associated files
   - `Archive`: Moves projects/areas to the archive location
   - `Delete`: Removes projects/areas
   - `List`: Shows existing projects/areas
   - `Open`: Opens the project/area in the default application

3. **Helper Functions**: The Para extension provides utility functions for file operations, path determination, and folder listing.

## PARA Folder Structure

The tool expects and manages the following structure:
- `$PARA_HOME/projects/`: Contains project folders
- `$PARA_HOME/areas/`: Contains area folders
- Each project/area has a `journal.org` file with metadata

## File Structure

- `main.swift` - Contains all command definitions and helper functions
- Tests are located in `paraTests/paraTests.swift`

## Common Usage Examples

- Create a new project: `para create project roofBuild`
- Archive an area: `para archive area guitar`
- Delete a project: `para delete project roofBuild`
- List all areas: `para list area`
- List all projects and areas: `para list`
- Open a project's journal.org file: `para open project roofBuild`
- Open a project folder in Finder: `para reveal project roofBuild`
- Show environment settings: `para environment`

## Features

### Project and Area Management
- Projects and areas can be identified by emoji in listings (📁 for projects, 🔄 for areas)
- If a project or area has a description specified in the journal.org file with `#+DESCRIPTION:`, it will be displayed in the list output
- Commands like `archive` and `delete` can automatically detect whether a name belongs to a project or area

### Environment Configuration
- Use the `para environment` command to see the current environment settings and check if required directories exist
- Helpful suggestions are provided if any required directories are missing

### Folder Operations
- Use the `--reveal` flag with the `open` command to open the folder in Finder instead of opening the journal.org file