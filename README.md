# Para - A Command Line Tool for Managing Your PARA Productivity System

[![Swift](https://img.shields.io/badge/Swift-5.6-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Para is a command line tool designed to help you manage your personal productivity system based on the PARA (Projects, Areas, Resources, Archives) method. It works in an Emacs context, in that new files are created in [Org mode](https://orgmode.org) format. The PARA method is a framework for organizing your digital life and enhancing your productivity.

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
