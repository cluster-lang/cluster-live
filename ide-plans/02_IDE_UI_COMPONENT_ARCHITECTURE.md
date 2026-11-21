# Cluster-IDE: UI Component & Workspace Layout Architecture
**Document ID:** `IDE-PLN-002`  
**Implementation Technology:** 100% Pure Cluster UI (`src/widgets/*.cl`)  

---

## 1. Ergonomic Workspace Layout

The IDE layout is structured using Cluster UI's declarative layout primitives (`Column`, `Row`, `Box`, `NavigationRail`, `DataTable`, `CodeBlock`, `Card`):

```
+------------------------------------------------------------------------------------+
|  [Logo] Cluster IDE v1.0   [File] [Edit] [Project] [Terminal] [Help]  [⚡ Run] [✔ Check]|
+----+-----------------------+-----------------------------+-------------------------+
|    | PROJECT EXPLORER      | MAIN CODE EDITOR (TABS)     | LIVE PREVIEW / TARGET   |
| [F]| ▾ my_project/         | [main.cl x] [widget.cl] [+] | [ Web ] [Android] [iOS] |
| i  |   ▾ src/              | 1 | import std/io.cl        | ----------------------- |
| l  |     main.cl           | 2 | import src/ui.cl        |                         |
| e  |     models.cl         | 3 |                         |   [ Rendered UI Output  |
| s  |   ▾ assets/           | 4 | fn main() -> int:       |     with Live Hot       |
|    |     logo.png          | 5 |     let app = Column([  |     Reloading ]         |
| [G]|   cl.toml             | 6 |         Text("Hi")      |                         |
| i  |                       | 7 |     ])                  |                         |
| t  |                       | 8 |     return 0            |                         |
|    +-----------------------+-----------------------------+-------------------------+
| [S]| TERMINAL / COMPILER DIAGNOSTICS                                               |
| e  | Finished build [-O3] target(s) in 0.18s                                       |
| t  | ✔ Compilation Succeeded (12,410 tokens, 6,102 AST nodes)                      |
+----+-------------------------------------------------------------------------------+
| Status: Ready | Cluster v1.0.0 (x86_64-linux) | UTF-8 | 4 Spaces | Line: 5, Col: 12|
+------------------------------------------------------------------------------------+
```

---

## 2. Cluster UI Composition Code

The entire IDE frame is composed cleanly in pure Cluster code:

```cluster
import src/core/widget.cl
import src/core/state.cl
import src/core/animation.cl
import src/render/html.cl

fn build_cluster_ide_ui() -> Widget:
    // Top Application Bar with Navigation and Controls
    let top_bar = AppBar(
        title = "⚡ Cluster IDE — Next-Gen Multiplatform Studio",
        leading = Row([Icon("terminal", 22, "#58a6ff"), Text("Cluster IDE", 15, "#e6edf3", true)], 8),
        trailing = Row([
            Button("✔ Check", "Cluster.dispatch('CHECK_CODE')", "#21262d", "#58a6ff", 13),
            Button("⚡ Run (F5)", "Cluster.dispatch('RUN_CODE')", "#238636", "#ffffff", 13),
            Button("⚙ Settings", "Cluster.dispatch('TOGGLE_SETTINGS')", "#21262d", "#8b949e", 13)
        ], 10),
        bg_color = "#161b22"
    )

    // Left Activity Navigation Rail
    let activity_rail = NavigationRail(
        header = Icon("code", 24, "#58a6ff"),
        items = [
            Icon("folder", 20, "#e6edf3"),
            Icon("search", 20, "#8b949e"),
            Icon("git-branch", 20, "#8b949e"),
            Icon("settings", 20, "#8b949e")
        ],
        active_index = 0,
        width = 54,
        bg_color = "#0d1117"
    )

    // Left File Explorer Pane
    let file_tree = Column([
        Text("EXPLORER", 11, "#8b949e", true),
        ListTile("src/main.cl", "Cluster Source", "file-code", "open_file('src/main.cl')"),
        ListTile("src/models.cl", "Data Models", "file-code", "open_file('src/models.cl')"),
        ListTile("cl.toml", "Manifest", "file-text", "open_file('cl.toml')")
    ], 6, 12)
    let file_pane = Box(file_tree, width = 230, bg_color = "#161b22")

    // Center Multi-Tab Code Editor Pane
    let editor_pane = Column([
        // Tab bar
        Row([
            Badge("main.cl ✕", "#1f6feb", "#ffffff", 12),
            Badge("models.cl", "#21262d", "#8b949e", 12)
        ], 6, 8),
        // Code Block Editor
        CodeBlock(
            code = "import std/io.cl\nimport src/ui.cl\n\nfn main() -> int:\n    let app = Text(\"Hello Cluster IDE!\")\n    pln(app.text)\n    return 0",
            language = "cluster",
            bg_color = "#0d1117"
        )
    ], 0, 0)

    // Right Live Preview Pane
    let preview_header = Row([
        Text("PREVIEW", 11, "#8b949e", true),
        Spacer(),
        SegmentedButton(["Web", "Android", "Apple"], 0, "switch_preview_target")
    ], 8, 8)
    let preview_content = Box(
        Center(Text("⚡ Live Hot Reload Active", 16, "#3fb950", true)),
        bg_color = "#0d1117"
    )
    let preview_pane = Box(Column([preview_header, preview_content], 8, 8), width = 360, bg_color = "#161b22")

    // Bottom Output / Terminal Pane
    let terminal_pane = Column([
        Row([Text("OUTPUT CONSOLE", 11, "#8b949e", true), Spacer(), Icon("x", 14, "#8b949e")], 8, 8),
        Text("Finished build [-O3] target(s) in 0.12s\nHello Cluster IDE!", 13, "#3fb950")
    ], 6, 12)

    // Assemble Full Workspace Layout
    let center_workspace = Row([
        activity_rail,
        file_pane,
        Expanded(editor_pane),
        preview_pane
    ], 0)

    let full_ide_layout = Scaffold(
        app_bar = top_bar,
        body = Column([Expanded(center_workspace), Box(terminal_pane, height = 160, bg_color = "#0d1117")], 0),
        bottom_bar = Box(Text("Ready | Cluster v1.0.0 | UTF-8", 11, "#8b949e"), padding = 4, bg_color = "#161b22"),
        fab = Spacer()
    )

    return full_ide_layout
```
