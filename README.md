# Tiko Editor

Tiko is a FreeBASIC source editor. The native application is being rebuilt
with the FreeBASIC runtime and gfxlib, using the bundled omaGUI toolkit for
its interface.

The native entry point is [src/tiko.bas](src/tiko.bas). The earlier Windows
implementation is retained in `src/tiko_windows_legacy.bas` while its editor
features are ported.

## Native editor features

- Tiko's File, Edit, Search, View, Project, Compile, Debug, and Help menus
- The editor's left tool strip, grouped source explorer, document tabs, and
  segmented status bar
- Open and save FreeBASIC source files with a file dialog
- Keep up to 12 source documents open, with dirty markers and discard prompts
- Edit source with line numbers, FreeBASIC syntax colors, four-space Tab, and
  automatic indentation after Return
- Undo, redo, selection, copy, cut, paste, and Find Next
- Build and run the active source file, with compiler and program output shown
  in Tiko's output pane
- Use Ctrl+N, Ctrl+O, Ctrl+S, Ctrl+Shift+S, Ctrl+B, Ctrl+R, Ctrl+W, Ctrl+F,
  and F3 for common commands

The editor buffer is limited to 2 MiB. The native loader accepts source files
up to 4 MiB before line-ending normalization and retains the file's UTF-8 BOM
and detected line-ending style when saving. Compiler build and run commands
execute synchronously, so Tiko pauses while they run. Set `TIKO_FBC` to the
compiler executable path to select a compiler; otherwise Tiko runs `fbc` from
`PATH`.

This is the first native port of Tiko's editing shell. Project and session
management, localization, code completion, debugger integration, function
parsing, and several commands shown in the original menus still need native
implementations.

## Build

Install a recent FreeBASIC compiler with gfxlib support, then run the script
for your platform from the repository root:

```sh
chmod +x _compile.sh
./_compile.sh
./bin/tiko
```

On Windows, run `_compile.bat`. Both scripts build `src/tiko.bas` and include
the bundled `src/omaGUI-main` toolkit.

omaGUI owns platform-specific behavior such as clipboard access. Its Win32
and xclip implementations remain gated by the target OS, with an in-process
fallback where a system clipboard is unavailable.

## License

Tiko Editor is licensed under the GNU GPLv3 or later. See [LICENSE](LICENSE).

Copyright (C) 2016-2026 Paul Squires, PlanetSquires Software.
