# LiteNotes — High-Level Specification (Expanded Design)

LiteNotes is a lightweight developer-notes system for Lite XL.  
It provides a **single dedicated notes/view panel** capable of:

- Per-project notes (stored externally)
- Viewing any `.md` file in a readable, styled mode
- (Optional / future) Creating new Markdown notes inside a project

The panel always exists **as a single instance**:  
commands simply **retarget** it to a different underlying document.

---

## 1. Goals

- Provide project-scoped notes without cluttering the project directory.
- Allow viewing *any* Markdown file in a readable, editor-font-based view.
- Let all actions be **explicit** — no auto-opening, no automatic detection.
- Keep scope extremely small and predictable.
- Maintain a strict “one notes panel” rule to avoid UX confusion.
- (Maybe later) Add a helper to create new `.md` notes from within Lite XL.

---

## 2. Storage Model (Project Notes)

LiteNotes keeps all **project notes** under a plugin-owned global directory:

```text
<userdir>/notes-plugin/
```

Each project root receives a single notes file:

```text
<userdir>/notes-plugin/<root-id>.md
```

`<root-id>` is a sanitized or hashed representation of the project root path.

**Fallback:**  
If no project root is detected:

```text
<userdir>/notes-plugin/global.md
```

LiteNotes **never** writes notes inside the project directory when opening project notes.

---

## 3. Root Resolution

- Uses Lite XL's project-dir detection.
- If a project root exists → use `<root-id>.md`.
- If none → use `global.md`.

---

## 4. Commands (User Interaction)

LiteNotes exposes explicit commands that all retarget the single LiteNotes panel.

### 4.1 `LiteNotes: Open Project Notes` (core)

- Identify current root.
- Load/create the per-root notes file.
- Open the LiteNotes panel (or retarget existing panel).
- Start in **View Mode**.

### 4.2 `LiteNotes: View Current Markdown` (core)

- Only enabled when the focused file is a `.md`.
- Retarget the LiteNotes panel to render **that Doc** in View Mode.
- No storage outside the file itself; no copies, no special handling.

This gives lightweight `.md` readability inside the editor using the same panel.

### 4.3 `LiteNotes: New Note` (optional / future)

This command is **not required for the initial implementation**.

If implemented later:

- User selects a directory (via tree selection, picker, or a simple prompt).
- Plugin creates a new blank `.md` file in that directory.
- Opens it as the underlying document for the LiteNotes panel.
- Starts in View Mode.

LiteNotes does not create templates, metadata, or scaffolding — just a blank `.md`.

---

## 5. Panel Behavior (Global)

### Single Panel Rule

LiteNotes always uses **exactly one** panel instance.  
Invoking any LiteNotes command **retargets** this panel to another document.

### When panel opens

- Starts in **View Mode**.
- Displays whichever document the triggering command specifies:
  - Per-project notes file, or
  - The current `.md` Doc, or
  - (Future) A newly created note.

### When project root changes

- If panel is closed → do nothing.
- If panel is open and showing **project notes**:
  - Swap underlying document to the new project’s notes file (creating it if needed).
- If panel is open and showing **an arbitrary `.md`**:
  - Leave it unchanged. (It follows the file, not the project.)

---

## 6. Edit Mode

Edit mode uses a real `Doc` + `DocView`:

- Raw Markdown visible.
- Standard editing capabilities: cursor, selection, undo/redo.
- Uniform line height.
- Uses the user's Markdown syntax highlighting automatically.
- No custom styling added.

The underlying Doc is the same one used for View Mode.

---

## 7. View Mode

View mode is a custom **read-only renderer** applied to the underlying Doc.

### Rendering Rules

- Use the user's editor font family.
- Larger size for `#` and `##` headings.
- Bold for `**text**`.
- Italic for `*text*`.
- Simple bullets for lines starting with `-`.
- Shallow, per-line parsing only.
- No block-level or advanced Markdown.
- No syntax highlighting.
- Allows variable line heights.

View mode is scrollable and never editable.
LiteNotes does not open on program start, unless toggle is set by the user (default OFF).

Scrolling:

- Mouse-wheel scrolling over the panel is allowed in either mode.
- Scrolling alone does **not** change mode.

---

## 8. Mode Switching UX

### View Mode → Edit Mode

Triggered by:

- User **clicking inside the LiteNotes panel** (left-click anywhere in the content area), or
- A future explicit "Edit Notes" command.

Effect:

- Replace the custom View with a standard DocView for the same Doc.
- Show raw Markdown.
- The panel becomes the active view.

### Edit Mode → View Mode

Triggered when the panel **loses focus**:

- If the LiteNotes DocView was the active view and the user clicks into a different view/tab/split:
  - On next update, the LiteNotes panel reverts back to View Mode for its underlying Doc.
- The panel’s underlying document does **not** change; only the representation (DocView → View).

### On focus regain

- When the user later reopens/retargets the panel via a LiteNotes command:
  - It always re-enters via **View Mode**.
- To edit again, the user clicks in the panel.

This gives simple semantics:

- **Click notes panel → edit.**
- **Click away → view.**

---

## 9. No Implicit Behaviors

LiteNotes does not:

- auto-open on project change
- auto-detect `.md` and pop up
- auto-switch based on file type
- sync previews live as you type in a separate editor
- add UI controls for formatting
- create additional panels or window types

Every action that changes what the panel shows is driven by explicit user commands.

---

## 10. Out of Scope (Explicit)

LiteNotes will **never** support:

- Per-line notes or annotations.
- Multiple notes panels.
- Rich Markdown (tables, links, images, code blocks, embeds).
- Folding, headings outline, navigation tree.
- Synchronised scrolling between separate edit & view panes.
- Multi-document notebooks.
- Tagging, indexing, searching.
- Background sync or cloud sync.

The plugin remains intentionally minimal and predictable.

---

## 11. Summary

LiteNotes provides:

- A **single** notes/view panel.
- Per-project notes stored outside the project tree.
- A readable lightweight Markdown renderer using the editor font.
- The ability to view any `.md` inside the same renderer.
- (Optionally) A helper to create new `.md` notes later, without changing the core design.
- Strict, predictable behaviour with no hidden magic.
- Shallow Markdown for readability, not a full preview engine.
- Minimal, stable scope focused on  
  **“developer notes inside Lite XL.”**
