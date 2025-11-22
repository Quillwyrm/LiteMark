# LiteNotes Phase Plan

## Phase 0: Hello World Plugin

-   Minimal custom View.
-   One command.
-   Confirm drawing text works.

## Phase 1: Convert to Plugin Directory

-   Create `plugins/litenotes/`.
-   Move code into `init.lua`.
-   Rename command to `litenotes:open-panel`.

## Phase 2: Create User Notes Directory

-   Ensure `USERDIR/litenotes/` exists.
-   Prepare for storing per-project notes.

## Phase 3: Load and Display global.md

-   Create/load `global.md`.
-   Render document as plain text in view.

## Phase 4: Per‑Project Notes

-   Detect project root.
-   Map absolute path → notes file.
-   Load/create project-specific notes.

## Phase 5: Edit Mode Using DocView

-   Switch from custom draw to real editing.
-   Side panel shows DocView for the notes file.

## Phase 6: Add View Mode (Custom Renderer)

-   Reintroduce `LiteNotesView`.
-   Switch between View and Edit modes.
-   View Mode reads doc lines and draws them manually.

## Phase 7: Shallow Markdown Styling

-   Headings, bullets, bold, italic.
-   Line-based rules.
-   No full markdown parser.

## Phase 8: View Current Markdown Command

-   Render any open `.md` doc in View Mode.
-   No storage mapping.

## Phase 9: Later Enhancements

-   Inline/fenced code backgrounds.
-   Optional auto-return-to-view.
-   Plugin settings.
