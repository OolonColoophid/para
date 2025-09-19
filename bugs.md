# Known Bugs

- `Create`, `Open`, and `Reveal` still construct URLs with `URL(string: "file://" + path)` in `para/ParaCore.swift`, so folders/files containing spaces or special characters fail to open. These calls need `URL(fileURLWithPath:)`.
- Several subcommands (e.g., `Reveal`, `Directory`, `Read`, `Headings`) are missing the `@OptionGroup var globalOptions: Para` wiring, so `--json` does not toggle `ParaGlobals.jsonMode` for them; JSON responses remain unavailable.
- Archive fallback path in `para/ParaCore.swift` defaults to `~/Dropbox/para/archive`, which conflicts with the documented `~/Documents/archive` default used elsewhere (Environment command, README). Aligning the default prevents unexpected archive failures when `PARA_ARCHIVE` is unset.
