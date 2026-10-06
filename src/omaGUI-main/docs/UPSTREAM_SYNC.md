<!--
    Project: Optical FreeBASIC / omaGUI
    File: UPSTREAM_SYNC.md
    Purpose: Record the reference copy and decisions behind local integration.
    Responsibilities: Identify imported fixes, retained extensions, and checks.
    This file intentionally does NOT contain a release-wide compatibility claim.
-->

# Reference integration, 2026-09-13

Reference: `C:\Nextcloud\games\newjrpg\omaGui`

Destination: `C:\Nextcloud\games\FreeBASIC_packages\Optical-Freebasic\omaGui`

The reference was read-only. Of its 158 non-ignored files, 122 matched locally
and 36 differed. Every reference file already had a local counterpart.
The source, header, test, documentation, and master-include differences were
reviewed individually; differing files were not copied wholesale.

## Imported fix

`src/widgets/button.bas` now uses the reference's `button_Update` implementation:

- Null widgets and released private data return before dereferencing them.
- Pointer release stores the final hover state before calling application code.
- Pointer and keyboard activation return immediately after the callback, which
  may have destroyed the button or its entire parent tree.

Reference `button.bas` SHA-256:
`4F9C92F72BB8FE89EB19480F4C89E641C10FD61A4E2F117DC2DB6553DF561588`

The remaining button differences are the local semantic palette and mnemonic
underline rendering. No public signature or data layout changed in this merge.

## Retained local work

The other differences were local additions or replacements supporting those
additions, not missing reference improvements. These remain intact:

- Splitters, block indentation, line-number gutters, and KeyUp callbacks.
- Independent classic widget colors and access-key underlines.
- Resizable child windows, title controls, and minimize/maximize state.
- List item data, replacement, scrolling, and observable ComboBox opening.
- Multi-pattern file lists, root-directory handling, and label layout/clipping.
- Extended message dialogs and their checked allocation/layout handling.
- Local tests, documentation, and master includes for these features.

Unchanged reference assets, examples, and tools needed no copying. Compiler
outputs and local executables were not imported from the reference directory.
The fix uses only FreeBASIC and the existing input layer, with no SDK or new
platform dependency.

## Regression coverage

`tests/button_lifetime_smoke.bas` first detaches live button data in a callback.
This detects incorrect post-callback writes without relying on freed-memory
contents. That check failed against the old implementation and passed after
the fix. Further cases cover immediate destruction, registry-owned tree removal,
Enter/Space, simultaneous pointer/key input, null arguments, and polled results.

Both the full project gate and `tools/verify_omagui_workspace.ps1` include the
new test. The focused verifier also builds the linked IDE, checks its layout and
editor commands, emits Linux C, and runs strict fblint. Linux C generation is
not a Linux link or runtime test.

The focused verifier passed all nine widget tests, both linked IDE checks, all
four Linux C-generation checks, and strict Windows lint with zero errors and
zero warnings. Additional parent-modal, extended-message-dialog (429 checks),
and semantic title-color/rendering tests passed using the null display driver.
The full sample-translation gate was not rerun for this focused merge.
The normal root `vbdos_studio.exe` was rebuilt with the installed
`C:\FreeBASIC\fbc.exe` (1.20.2-14); its layout and editor smoke checks also
passed. Those checks left the sample project and source hashes unchanged.

Verification logs:
`build/omagui_workspace_3f9fa091360445a9b59969d2ca192a4f` and
`build/omagui_sync_95c2a380ea9a4fe39e81f1b01e851ba9`, relative to the project root.

<!-- end of UPSTREAM_SYNC.md -->
