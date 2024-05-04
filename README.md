# Para - A Command Line Tool for Managing Your PARA Productivity System

[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Para is a command line tool designed to help you manage your personal productivity system based on the PARA (Projects, Areas, Resources, Archives) method. It works in an Emacs context, in that new files are created in [Org mode](https://orgmode.org) format. The PARA method, popularized by [Tiago Forte](https://fortelabs.com), is a framework for organizing your digital life and enhancing your productivity.

## Features

- Create new projects and areas
- Archive completed projects and areas
- Delete unwanted projects and areas
- List existing projects and areas
- Open projects and areas in the associated application (usually Emacs)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/para.git
```

2. Navigate to the project directory:

```bash
cd para
```

3. Build the project:

```bash
swift build -c release
```

4. Move the built binary to a directory in your `PATH`:

```bash
mv .build/release/para /usr/local/bin/
```

## Configuration

Para relies on environment variables to determine the location of your PARA folders. Set the following environment variables in your shell configuration file (e.g., `.bashrc`, `.zshrc`):

- `PARA_HOME`: The base directory for your PARA system (default: `~/Documents/PARA`)
- `PARA_ARCHIVE`: The directory for archived projects and areas (default: `~/Documents/archive`)

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

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

Para is released under the [MIT License](https://opensource.org/licenses/MIT).
