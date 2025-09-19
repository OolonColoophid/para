# Repository Guidelines

## Project Structure & Module Organization
- Core CLI logic lives in `para/main.swift`; each subcommand is defined in ArgumentParser extensions near related helpers.
- Tests reside in `paraTests/paraTests.swift` using XCTest. Run them from Xcode or the Swift toolchain.
- The Xcode project is tracked in `para.xcodeproj`; `install.sh` orchestrates release builds, signing, and installation.
- Generated artifacts land in `build/` (local) or the derived data folder during `xcodebuild`; keep this directory out of source control.

## Build, Test, and Development Commands
```bash
xcodebuild -scheme para -configuration Debug -derivedDataPath build build    # Fast local build
xcodebuild -scheme paraTests -configuration Debug -derivedDataPath build test # Run XCTest suite
./build/Build/Products/Debug/para --help                                      # Exercise the debug binary
./install.sh                                                                   # Release build + install to /usr/local/bin
```
- Use `PARA_HOME=/tmp/para PARA_ARCHIVE=/tmp/para/archive ./build/Build/Products/Debug/para list project` to spot-check behaviour against disposable data.

## Coding Style & Naming Conventions
- Adopt standard Swift formatting: 4-space indentation, trailing commas for multiline collections, and braces on the same line.
- Prefer `UpperCamelCase` for types, `lowerCamelCase` for functions, methods, and properties, matching existing declarations in `main.swift`.
- Guard clauses should exit early; leverage `Para.outputError` / `Para.outputSuccess` helpers for messaging consistency.

## Testing Guidelines
- XCTest covers file-system behaviours in `paraTests.swift`; mirror new features with focused tests that set up disposable folders under `~/tmp` like the existing suite.
- Name new tests `test<Scenario>` and keep assertions deterministic; clean up temp artifacts inside `tearDown()` helpers.
- Run `xcodebuild ... test` (or `swift test` once a Package manifest lands) before pushing.

## Commit & Pull Request Guidelines
- Follow the current log style (`Add …`, `Fix …`): concise, imperative subject (<65 chars) with optional explanatory body.
- Group related changes per commit; include test updates when behaviour shifts.
- Pull requests should describe intent, list manual/automated verification, and link issues. Add screenshots or terminal snippets when UI/CLI output changes.

## Environment & Configuration Tips
- The CLI infers paths from `PARA_HOME` and `PARA_ARCHIVE`; export them in your shell profile (`~/.zshrc`) before running tests.
- Use `para environment` to confirm directory health, and `para --json <command>` when scripting or integrating with other agents.
