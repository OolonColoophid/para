# Known Bugs

None currently.

## Fixed Bugs

### Fixed in commit 043a586 (2025-12-23)

- **URL Construction**: `Create`, `Open`, and `Reveal` constructed URLs with `URL(string: "file://" + path)` in `para/ParaCore.swift`, so folders/files containing spaces or special characters failed to open.
  - **Fix**: Changed to `URL(fileURLWithPath:)` which properly handles spaces and special characters. Removed unnecessary optional binding since this initializer is non-failable.
  - **Tests**: Added `testCreateProjectWithSpaces`, `testURLConstructionWithSpecialCharacters`, `testProjectNameWithUnicodeCharacters`, `testProjectNameWithMultipleConsecutiveSpaces`

- **JSON Mode Support**: Several subcommands (`Reveal`, `Directory`, `Read`, `Headings`) were missing the `@OptionGroup var globalOptions: Para` wiring, so `--json` did not toggle `ParaGlobals.jsonMode` for them; JSON responses were unavailable.
  - **Fix**: Added `@OptionGroup var globalOptions: Para` to all four commands. Added `ParaGlobals.jsonMode = globalOptions.json` to `Reveal` and `Directory` commands (others already had the check).
  - **Tests**: Can now use `--json` flag with all commands for machine-readable output

- **Archive Fallback Path**: Archive fallback path in `para/ParaCore.swift` defaulted to `~/Dropbox/para/archive`, which conflicted with the documented `~/Documents/archive` default used elsewhere (Environment command, README).
  - **Fix**: Changed fallback to `~/Documents/archive` to align with documentation and other commands.
  - **Tests**: Added `testArchiveUsesCorrectFallbackPath` to verify correct default is used when `PARA_ARCHIVE` is unset
