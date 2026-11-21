// ==============================================================================
// Cluster-IDE: Pure Cluster Language Self-Hosting Cross-Platform IDE (Phase 3)
// 100% Pure Cluster Language & Cluster UI — Zero External Frameworks
// Targets: Android, Apple (iOS/macOS), Windows, Linux, and Modern Web
// Phase 3: Compiler Execution, Diagnostics Engine, Code Formatter, Jump-to-Line
// ==============================================================================

import src/core/widget.cl
import src/core/state.cl
import src/core/animation.cl
import src/render/html.cl

fn generate_ide_javascript() -> string:
    let js_body: string = file_read("web/ide_controller.js")
    return "<script>\n" + js_body + "\n</script>\n"

fn inject_before_body(html: string, extra: string) -> string:
    let hlen: int = len(html)
    let needle: string = "</body>"
    let nlen: int = len(needle)
    let mut i: int = hlen - nlen
    while i >= 0:
        if substring(html, i, nlen) == needle:
            return substring(html, 0, i) + extra + "\n" + substring(html, i, hlen - i)
        i = i - 1
    return html + extra

fn build_cluster_ide() -> Widget:
    // 1. Top Bar with Logo, Diagnostics & Action Controls
    let title_badge = Badge("Studio v1.0", "#238636", "#ffffff", 10)
    let title_block = Row([
        Icon("terminal", 20, "#58a6ff"),
        Text("Cluster IDE", 16, "#e6edf3", true),
        title_badge
    ], 8, 0)

    let actions_block = Row([
        Button("🎨 Format (F7)", "ClusterIDE.formatCode()", "#21262d", "#3fb950", 12),
        Button("✔ Check (F6)", "ClusterIDE.checkCode(false)", "#21262d", "#58a6ff", 12),
        Button("⚡ Run (F5)", "ClusterIDE.runCode()", "#238636", "#ffffff", 12),
        Button("💾 Save (Ctrl+S)", "ClusterIDE.saveFile()", "#21262d", "#e6edf3", 12),
        Button("⚙ Settings", "ClusterIDE.switchPanel('settings')", "#21262d", "#8b949e", 12)
    ], 8, 0)

    let top_bar = AppBar("", title_block, actions_block, "#161b22")

    // 2. Left Activity Bar (46px icon rail)
    let activity_bar_html: string = "<div style=\"width:46px; background:#0d1117; border-right:1px solid #30363d; display:flex; flex-direction:column; align-items:center; padding:12px 0; gap:16px; flex-shrink:0;\"><div class=\"cl-activity-icon\" data-panel=\"explorer\" onclick=\"ClusterIDE.switchPanel('explorer')\" style=\"color:#58a6ff; cursor:pointer; padding:8px 6px; border-left:2px solid #58a6ff; background:#161b22; width:100%; text-align:center; box-sizing:border-box;\" title=\"Explorer (Files)\">📁</div><div class=\"cl-activity-icon\" data-panel=\"search\" onclick=\"ClusterIDE.switchPanel('search')\" style=\"color:#8b949e; cursor:pointer; padding:8px 6px; border-left:2px solid transparent; width:100%; text-align:center; box-sizing:border-box;\" title=\"Search Across Project\">🔍</div><div class=\"cl-activity-icon\" data-panel=\"git\" onclick=\"ClusterIDE.switchPanel('git')\" style=\"color:#8b949e; cursor:pointer; padding:8px 6px; border-left:2px solid transparent; width:100%; text-align:center; box-sizing:border-box;\" title=\"Source Control (Git)\">🌿</div><div class=\"cl-activity-icon\" data-panel=\"packages\" onclick=\"ClusterIDE.switchPanel('packages')\" style=\"color:#8b949e; cursor:pointer; padding:8px 6px; border-left:2px solid transparent; width:100%; text-align:center; box-sizing:border-box;\" title=\"Standard Library & Packages\">📦</div><div style=\"flex:1;\"></div><div class=\"cl-activity-icon\" data-panel=\"settings\" onclick=\"ClusterIDE.switchPanel('settings')\" style=\"color:#8b949e; cursor:pointer; padding:8px 6px; border-left:2px solid transparent; width:100%; text-align:center; box-sizing:border-box;\" title=\"Compiler Settings\">⚙️</div></div>"
    let activity_bar = RawHtml(activity_bar_html)

    // 3. Multi-View Left Sidebar (Explorer, Search, Git, Packages, Settings)
    let p_explorer: string = "<div id=\"panel-explorer\" class=\"cl-sidebar-view\" style=\"display:flex; flex-direction:column; height:100%;\"><div style=\"display:flex; align-items:center; justify-content:space-between; padding:10px 14px; border-bottom:1px solid #21262d;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase; letter-spacing:0.5px;\">Explorer</span><div style=\"display:flex; gap:8px;\"><span onclick=\"var n=prompt('New file:'); if(n) ClusterIDE.switchFile(n);\" style=\"cursor:pointer; font-size:14px; color:#8b949e;\" title=\"New File\">+</span><span onclick=\"ClusterIDE.init();\" style=\"cursor:pointer; font-size:13px; color:#8b949e;\" title=\"Refresh\">⟳</span></div></div><div style=\"flex:1; overflow-y:auto; padding:8px 0; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size:13px;\"><div style=\"padding:4px 12px; color:#8b949e; font-size:11px; font-weight:600;\">▾ CLUSTER-PROJECT</div><div class=\"cl-tree-item\" data-file=\"main.cl\" onclick=\"ClusterIDE.switchFile('main.cl')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#58a6ff; background:rgba(88,166,255,0.12); cursor:pointer; transition:background 0.15s;\"><span>📄</span><span>main.cl</span></div><div class=\"cl-tree-item\" data-file=\"models.cl\" onclick=\"ClusterIDE.switchFile('models.cl')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#e6edf3; cursor:pointer; transition:background 0.15s;\"><span>📄</span><span>models.cl</span></div><div class=\"cl-tree-item\" data-file=\"cl.toml\" onclick=\"ClusterIDE.switchFile('cl.toml')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#e6edf3; cursor:pointer; transition:background 0.15s;\"><span>⚙️</span><span>cl.toml</span></div><div style=\"padding:12px 12px 4px 12px; color:#8b949e; font-size:11px; font-weight:600;\">▾ STANDARD LIBRARY</div><div class=\"cl-tree-item\" data-file=\"std/io.cl\" onclick=\"ClusterIDE.switchFile('std/io.cl')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#8b949e; cursor:pointer;\"><span>📚</span><span>std/io.cl</span></div><div class=\"cl-tree-item\" data-file=\"std/net.cl\" onclick=\"ClusterIDE.switchFile('std/net.cl')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#8b949e; cursor:pointer;\"><span>🌐</span><span>std/net.cl</span></div><div class=\"cl-tree-item\" data-file=\"src/ui.cl\" onclick=\"ClusterIDE.switchFile('src/ui.cl')\" style=\"display:flex; align-items:center; gap:8px; padding:6px 20px; color:#8b949e; cursor:pointer;\"><span>🎨</span><span>src/ui.cl</span></div></div></div>"
    let p_search: string = "<div id=\"panel-search\" class=\"cl-sidebar-view\" style=\"display:none; flex-direction:column; height:100%; padding:12px;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase;\">Search Project</span><input type=\"text\" placeholder=\"Search symbols or text...\" oninput=\"var q=this.value.toLowerCase(); var res=''; for(var f in ClusterIDE.files){ if(ClusterIDE.files[f].toLowerCase().includes(q)) res += '<div><b style=\\'color:#58a6ff\\'>' + f + '</b></div>'; } document.getElementById('search-results').innerHTML = res;\" style=\"margin-top:8px; width:100%; background:#0d1117; border:1px solid #30363d; border-radius:4px; padding:6px 10px; color:#e6edf3; font-size:12px; outline:none; box-sizing:border-box;\" /><div id=\"search-results\" style=\"margin-top:12px; font-size:12px; color:#8b949e; display:flex; flex-direction:column; gap:6px; overflow-y:auto;\">Type to search across open files...</div></div>"
    let p_git: string = "<div id=\"panel-git\" class=\"cl-sidebar-view\" style=\"display:none; flex-direction:column; height:100%; padding:12px;\"><div style=\"display:flex; justify-content:space-between; align-items:center;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase;\">Source Control</span><span onclick=\"ClusterIDE.refreshGitStatus()\" style=\"cursor:pointer; font-size:13px; color:#58a6ff;\">⟳</span></div><pre id=\"git-status-content\" style=\"margin-top:10px; background:#0d1117; border:1px solid #30363d; border-radius:4px; padding:10px; font-family:monospace; font-size:11px; color:#3fb950; overflow:auto; max-height:220px;\">Checking repository status...</pre><input type=\"text\" placeholder=\"Commit message...\" style=\"margin-top:10px; width:100%; background:#0d1117; border:1px solid #30363d; border-radius:4px; padding:6px 10px; color:#e6edf3; font-size:12px; outline:none; box-sizing:border-box;\" /><button onclick=\"alert('Git commit staged!')\" style=\"margin-top:8px; background:#238636; color:#fff; border:none; border-radius:4px; padding:8px; font-size:12px; font-weight:600; cursor:pointer;\">Commit Changes</button></div>"
    let p_packages: string = "<div id=\"panel-packages\" class=\"cl-sidebar-view\" style=\"display:none; flex-direction:column; height:100%; padding:12px; overflow-y:auto;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase;\">Installed Packages</span><div style=\"margin-top:10px; display:flex; flex-direction:column; gap:8px;\"><div style=\"background:#0d1117; border:1px solid #30363d; border-radius:6px; padding:8px 10px;\"><b style=\"color:#58a6ff; font-size:13px;\">cluster-ui</b><div style=\"font-size:11px; color:#8b949e;\">v1.0.0 · Declarative UI Framework</div></div><div style=\"background:#0d1117; border:1px solid #30363d; border-radius:6px; padding:8px 10px;\"><b style=\"color:#3fb950; font-size:13px;\">std/io</b><div style=\"font-size:11px; color:#8b949e;\">Built-in · File & Directory Manager</div></div><div style=\"background:#0d1117; border:1px solid #30363d; border-radius:6px; padding:8px 10px;\"><b style=\"color:#d29922; font-size:13px;\">std/net</b><div style=\"font-size:11px; color:#8b949e;\">Built-in · High-Speed Socket & HTTP</div></div></div></div>"
    let p_settings: string = "<div id=\"panel-settings\" class=\"cl-sidebar-view\" style=\"display:none; flex-direction:column; height:100%; padding:12px; overflow-y:auto;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase;\">Compiler Settings</span><div style=\"margin-top:10px; display:flex; flex-direction:column; gap:10px; font-size:12px;\"><label style=\"color:#e6edf3;\">Optimization Level:<select style=\"margin-top:4px; width:100%; background:#0d1117; color:#fff; border:1px solid #30363d; padding:6px; border-radius:4px;\"><option selected>-O3 (Aggressive LLVM)</option><option>-O2 (Standard)</option><option>-O0 (Fast Debug)</option></select></label><label style=\"color:#e6edf3; display:flex; align-items:center; gap:8px;\"><input type=\"checkbox\" checked style=\"accent-color:#238636;\" /> Enable Link-Time Optimization (--lto)</label><label style=\"color:#e6edf3; display:flex; align-items:center; gap:8px;\"><input type=\"checkbox\" style=\"accent-color:#238636;\" /> Thread Sanitizer (--tsan)</label></div></div>"

    let sidebar_wrapper_start: string = "<div style=\"width:240px; background:#161b22; border-right:1px solid #30363d; display:flex; flex-direction:column; flex-shrink:0; overflow:hidden;\">"
    let sidebar_wrapper_end: string = "</div>"
    let sidebar_html: string = sidebar_wrapper_start + p_explorer + p_search + p_git + p_packages + p_settings + sidebar_wrapper_end
    let sidebar_panel = RawHtml(sidebar_html)

    // 4. Center Multi-Tab Code Editor Area
    let tab_bar_html: string = "<div id=\"ide-tab-bar\" style=\"height:36px; background:#161b22; border-bottom:1px solid #30363d; display:flex; align-items:center; padding:0 8px; box-sizing:border-box;\"></div>"
    let tab_bar = RawHtml(tab_bar_html)

    // Editor Gutter and Multi-Layer Syntax Highlighted Textarea (Fixed Full Viewport Height: calc(100vh - 275px) with synchronized scrolling)
    let editor_style: string = "<style>#cluster-code-editor::selection { background:rgba(56, 139, 253, 0.4); color:transparent; } #cluster-code-editor::-moz-selection { background:rgba(56, 139, 253, 0.4); color:transparent; } .cl-editor-container pre, .cl-editor-container textarea, .cl-editor-container code { font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace !important; font-size:13.5px !important; line-height:1.55 !important; letter-spacing:0px !important; tab-size:4 !important; -moz-tab-size:4 !important; }</style>"
    let gutter_html: string = "<pre id=\"ide-line-gutter\" style=\"height:calc(100vh - 275px); overflow:hidden; padding:14px 10px; margin:0; color:#484f58; background:#0d1117; border-right:1px solid #21262d; text-align:right; user-select:none; min-width:40px; box-sizing:border-box;\">1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n20\n21\n22\n23\n24\n25\n26\n27\n28\n29\n30</pre>"
    let hl_layer_html: string = "<pre id=\"ide-highlight-layer\" aria-hidden=\"true\" style=\"position:absolute; top:0; left:0; width:100%; height:100%; margin:0; padding:14px; box-sizing:border-box; overflow:hidden; pointer-events:none; background:transparent; border:none; white-space:pre; word-wrap:normal;\"><code id=\"ide-highlight-code\" style=\"white-space:pre; word-wrap:normal;\"></code></pre>"
    let textarea_html: string = "<textarea id=\"cluster-code-editor\" spellcheck=\"false\" style=\"position:absolute; top:0; left:0; width:100%; height:100%; margin:0; padding:14px; box-sizing:border-box; background:transparent; color:transparent; caret-color:#58a6ff; border:none; outline:none; resize:none; white-space:pre; overflow:auto; z-index:2; word-wrap:normal;\"></textarea>"
    let stage_html: string = "<div style=\"position:relative; flex:1; height:calc(100vh - 275px); min-height:calc(100vh - 275px); overflow:hidden;\">" + hl_layer_html + textarea_html + "</div>"
    let editor_core_html: string = editor_style + "<div class=\"cl-editor-container\" style=\"display:flex; flex:1; width:100%; height:calc(100vh - 275px); min-height:calc(100vh - 275px); background:#0d1117; overflow:hidden;\">" + gutter_html + stage_html + "</div>"
    let editor_core = RawHtml(editor_core_html)

    let editor_column = Column([
        tab_bar,
        editor_core
    ], 0, 0)

    // 5. Right Live Multi-Target Preview Panel
    let preview_header_html: string = "<div style=\"height:36px; background:#161b22; border-bottom:1px solid #30363d; display:flex; align-items:center; justify-content:space-between; padding:0 12px; box-sizing:border-box;\"><span style=\"font-size:11px; font-weight:700; color:#8b949e; text-transform:uppercase;\">Live Preview</span><div style=\"display:flex; gap:4px;\"><button class=\"preview-target-btn\" data-target=\"web\" onclick=\"ClusterIDE.setPreviewTarget('web')\" style=\"background:#1f6feb; color:#fff; border:none; padding:4px 10px; border-radius:4px; font-size:11px; cursor:pointer; font-weight:500;\">Web</button><button class=\"preview-target-btn\" data-target=\"android\" onclick=\"ClusterIDE.setPreviewTarget('android')\" style=\"background:#21262d; color:#8b949e; border:none; padding:4px 10px; border-radius:4px; font-size:11px; cursor:pointer; font-weight:500;\">Android</button><button class=\"preview-target-btn\" data-target=\"apple\" onclick=\"ClusterIDE.setPreviewTarget('apple')\" style=\"background:#21262d; color:#8b949e; border:none; padding:4px 10px; border-radius:4px; font-size:11px; cursor:pointer; font-weight:500;\">Apple</button></div></div>"
    let preview_iframe_html: string = "<iframe id=\"ide-preview-frame\" style=\"width:100%; height:calc(100vh - 275px); border:none; background:#0d1117;\"></iframe>"

    let preview_pane_html: string = "<div style=\"width:420px; background:#161b22; border-left:1px solid #30363d; display:flex; flex-direction:column; flex-shrink:0;\">" + preview_header_html + preview_iframe_html + "</div>"
    let preview_pane = RawHtml(preview_pane_html)

    // 6. Assemble Main Workspace (Activity Bar + Sidebar + Center Editor + Right Preview)
    let workspace_body = Row([
        activity_bar,
        sidebar_panel,
        Expanded(editor_column),
        preview_pane
    ], 0, 0)

    // 7. Bottom Console / Diagnostics Panel with multi-tab switcher
    let console_header_html: string = "<div style=\"height:32px; background:#161b22; border-top:1px solid #30363d; border-bottom:1px solid #21262d; display:flex; align-items:center; justify-content:space-between; padding:0 14px; box-sizing:border-box;\"><div style=\"display:flex; align-items:center; gap:20px;\"><span class=\"cl-console-tab\" data-tab=\"terminal\" onclick=\"ClusterIDE.switchConsoleTab('terminal')\" style=\"font-size:11px; font-weight:700; color:#58a6ff; text-transform:uppercase; cursor:pointer; padding:6px 0; border-bottom:2px solid #58a6ff;\">Terminal Output</span><span id=\"ide-problems-badge\" class=\"cl-console-tab\" data-tab=\"problems\" onclick=\"ClusterIDE.switchConsoleTab('problems')\" style=\"font-size:11px; font-weight:600; color:#8b949e; text-transform:uppercase; cursor:pointer; padding:6px 0; border-bottom:2px solid transparent;\">Problems (0)</span><span onclick=\"ClusterIDE.fetchLlvmIr()\" style=\"font-size:11px; font-weight:600; color:#8b949e; text-transform:uppercase; cursor:pointer; padding:6px 0;\" title=\"Inspect SSA LLVM IR\">LLVM IR</span><span onclick=\"document.getElementById('ide-terminal-output').innerText = '';\" style=\"font-size:11px; color:#8b949e; cursor:pointer;\" title=\"Clear Console Output\">Clear</span></div><span id=\"ide-status-pill\" style=\"font-size:11px; color:#3fb950; font-weight:500;\">● Ready</span></div>"
    let console_body_html: string = "<pre id=\"ide-terminal-output\" style=\"height:130px; margin:0; padding:10px 14px; background:#0d1117; color:#3fb950; font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, monospace; font-size:13px; line-height:1.45; overflow-y:auto; white-space:pre-wrap; box-sizing:border-box;\">⚡ Cluster IDE Ready. Press F5 or click '⚡ Run' to compile & run at native speed.</pre>"
    let console_problems_html: string = "<div id=\"ide-problems-content\" style=\"display:none; height:130px; background:#0d1117; overflow-y:auto; box-sizing:border-box; flex-direction:column;\"><div style=\"padding:16px; color:#3fb950; font-size:12px; display:flex; align-items:center; gap:8px;\"><span>✔</span><span>No diagnostics problems detected across open files. Typecheck clean.</span></div></div>"

    let bottom_console = RawHtml(console_header_html + console_body_html + console_problems_html)

    // 8. Bottom Status Bar (with dynamic cursor position and file status)
    let status_bar_html: string = "<div style=\"height:24px; background:#161b22; border-top:1px solid #30363d; display:flex; align-items:center; justify-content:space-between; padding:0 12px; font-size:11px; color:#8b949e; box-sizing:border-box;\"><div style=\"display:flex; align-items:center; gap:8px;\"><span style=\"color:#3fb950;\">● Ready</span><span>|</span><span>Cluster Compiler v1.0.0 (LLVM 23.0)</span><span>|</span><span id=\"ide-status-file\">File: main.cl</span></div><div style=\"display:flex; align-items:center; gap:14px;\"><span id=\"ide-cursor-pos\">Ln 1, Col 1</span><span>Spaces: 4</span><span>Encoding: UTF-8</span></div></div>"
    let status_bar = RawHtml(status_bar_html)

    // 9. Full Viewport Scaffold
    let ide_scaffold = Scaffold(
        app_bar = top_bar,
        body = Column([
            Expanded(workspace_body),
            bottom_console
        ], 0, 0),
        bottom_bar = status_bar,
        fab = Spacer()
    )

    return ide_scaffold

fn main() -> int:
    pln("Compiling Phase 3 Cluster-IDE Engine...")
    let ide_root = build_cluster_ide()

    let full_html: string = render_page_html("Cluster IDE — Universal Cross-Platform Studio", ide_root)

    // Inject Cluster-IDE Interactive Controller script cleanly before body tag
    let js_controller: string = generate_ide_javascript()
    let final_html: string = inject_before_body(full_html, js_controller)

    // Write generated IDE directly to web/ide.html
    let dest_path: string = "web/ide.html"
    file_write(dest_path, final_html)
    pln("✔ Phase 3 Cluster-IDE successfully generated at " + dest_path)
    pln("✔ Shell size: " + str(len(final_html)) + " bytes")

    return 0
