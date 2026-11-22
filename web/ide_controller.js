window.ClusterIDE = {
    currentFile: 'main.cl',
    currentPanel: 'explorer',
    currentConsoleTab: 'terminal',
    previewTarget: 'web',
    openTabs: ['main.cl', 'models.cl', 'cl.toml'],
    problems: [],
    checkDebounceTimer: null,
    files: {
        'main.cl': 'import std/io.cl\nimport src/ui.cl\n\nfn main() -> int:\n    let card = Card(\n        child = Column([\n            Text("⚡ Welcome to Cluster IDE", 20, "#58a6ff", true),\n            Text("Self-Hosting IDE in Pure Cluster Language & UI", 13, "#8b949e"),\n            Row([\n                Button("Run Tests", "alert(1)"),\n                Button("Docs", "alert(2)", "#21262d", "#58a6ff")\n            ], 8)\n        ], 14),\n        bg_color = "#161b22"\n    )\n    pln(render_page_html("Cluster IDE App", card))\n    return 0',
        'models.cl': '// Cluster Data Models\nmodel ProjectState:\n    name: string\n    version: string\n    active_files: int\n    is_git_synced: bool\n\nfn default_project() -> ProjectState:\n    return ProjectState(\n        name = "cluster_app",\n        version = "1.0.0",\n        active_files = 3,\n        is_git_synced = true\n    )',
        'cl.toml': '[package]\nname = "cluster-app"\nversion = "1.0.0"\nedition = "2026"\nauthors = ["Developer <dev@cluster-lang.org>"]\n\n[dependencies]\ncluster-ui = { version = "1.0.0", path = "../cluster-ui" }\n\n[build]\nopt-level = 3\nlto = true',
        'std/io.cl': '// Cluster Standard Library: I/O (std/io.cl)\nfn io_read(path: string) -> string: return file_read(path)\nfn io_write(path: string, content: string): file_write(path, content)\nfn io_exists(path: string) -> int: return file_exists(path)',
        'std/net.cl': '// Cluster Standard Library: Networking (std/net.cl)\nfn net_listen(port: int) -> int: return tcp_listen(port)\nfn net_accept(fd: int) -> int: return tcp_accept(fd)',
        'src/ui.cl': '// Cluster UI Framework Re-Export (src/ui.cl)\nimport src/core/widget.cl\nimport src/core/theme.cl\nimport src/core/state.cl\nimport src/core/animation.cl\nimport src/render/html.cl'
    },
    highlightCluster: function(code) {
        if (!code) return '';
        var safe = code
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');

        // Single-pass deterministic tokenizer matching VS Code Dark+ color palette
        var tokenRegex = /(\/\/[^\n]*)|(&quot;[\s\S]*?&quot;|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(\b(?:import|let|mut|model|struct|true|false)\b)|(\b(?:fn|return|if|else|while|for|in|break|continue|and|or|not)\b)|(\b(?:int|string|bool|float|char|void)\b)|(\b(?:Card|Column|Row|Text|Button|Box|Badge|AppBar|Scaffold|Icon|Spacer|Expanded|Container|Divider|Image|TextInput|Widget|ProjectState)\b)|(\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\())|(\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*=(?!=)))|(-&gt;|=&gt;)|(\b\d+(?:\.\d+)?\b)/g;

        var result = safe.replace(tokenRegex, function(m, comment, str, declKw, ctrlKw, type, constructor, fnCall, prop, arrow, num) {
            if (comment) return '<span style="color:#6a9955; font-style:italic;">' + comment + '</span>';
            if (str) return '<span style="color:#ce9178;">' + str + '</span>';
            if (declKw) return '<span style="color:#569cd6; font-weight:600;">' + declKw + '</span>';
            if (ctrlKw) return '<span style="color:#c586c0; font-weight:600;">' + ctrlKw + '</span>';
            if (type) return '<span style="color:#4ec9b0;">' + type + '</span>';
            if (constructor) return '<span style="color:#4ec9b0; font-weight:600;">' + constructor + '</span>';
            if (fnCall) return '<span style="color:#dcdcaa;">' + fnCall + '</span>';
            if (prop) return '<span style="color:#9cdcfe;">' + prop + '</span>';
            if (arrow) return '<span style="color:#d4d4d4;">' + arrow + '</span>';
            if (num) return '<span style="color:#b5cea8;">' + num + '</span>';
            return m;
        });

        // Preserve trailing newline for exact textarea height sync
        if (code.endsWith('\n')) result += '\n ';

        return result;
    },
    updateHighlight: function() {
        var editor = document.getElementById('cluster-code-editor');
        var hlCode = document.getElementById('ide-highlight-code');
        if (editor && hlCode) {
            hlCode.innerHTML = this.highlightCluster(editor.value);
        }
    },
    syncScroll: function() {
        var editor = document.getElementById('cluster-code-editor');
        var gutter = document.getElementById('ide-line-gutter');
        var hlLayer = document.getElementById('ide-highlight-layer');
        if (editor) {
            if (gutter) gutter.scrollTop = editor.scrollTop;
            if (hlLayer) {
                hlLayer.scrollTop = editor.scrollTop;
                hlLayer.scrollLeft = editor.scrollLeft;
            }
        }
    },
    init: function() {
        var editor = document.getElementById('cluster-code-editor');
        if (editor) {
            editor.value = this.files[this.currentFile] || '';
            this.updateLineNumbers();
            this.renderTabs();
            this.updateCursorPos();
            this.updateHighlight();
            this.syncScroll();

            editor.addEventListener('scroll', function() {
                ClusterIDE.syncScroll();
            });

            editor.addEventListener('input', function() {
                ClusterIDE.files[ClusterIDE.currentFile] = editor.value;
                ClusterIDE.updateLineNumbers();
                ClusterIDE.updateCursorPos();
                ClusterIDE.updateHighlight();
                ClusterIDE.syncScroll();
                clearTimeout(ClusterIDE.checkDebounceTimer);
                ClusterIDE.checkDebounceTimer = setTimeout(function() {
                    ClusterIDE.checkCode(true);
                }, 600);
            });

            editor.addEventListener('keyup', function() { ClusterIDE.updateCursorPos(); });
            editor.addEventListener('click', function() { ClusterIDE.updateCursorPos(); });

            editor.addEventListener('keydown', function(e) {
                // 1. Smart Auto-Indentation on Enter Key
                if (e.key === 'Enter') {
                    e.preventDefault();
                    var start = this.selectionStart;
                    var end = this.selectionEnd;
                    var val = this.value;

                    // Extract text of current line before cursor
                    var lastNewline = val.lastIndexOf('\n', start - 1);
                    var lineStart = (lastNewline === -1) ? 0 : lastNewline + 1;
                    var currentLine = val.substring(lineStart, start);

                    // Preserve existing leading whitespace
                    var indentMatch = currentLine.match(/^[ \t]*/);
                    var indent = indentMatch ? indentMatch[0] : '';

                    // If line ends with ':' (Cluster/Python block start) or '{' or '[', add 4 spaces
                    var trimmed = currentLine.trimEnd();
                    if (trimmed.endsWith(':') || trimmed.endsWith('{') || trimmed.endsWith('[')) {
                        indent += '    ';
                    }

                    var insertText = '\n' + indent;
                    this.value = val.substring(0, start) + insertText + val.substring(end);
                    this.selectionStart = this.selectionEnd = start + insertText.length;

                    ClusterIDE.files[ClusterIDE.currentFile] = this.value;
                    ClusterIDE.updateLineNumbers();
                    ClusterIDE.updateCursorPos();
                    ClusterIDE.updateHighlight();
                    ClusterIDE.syncScroll();
                    return;
                }

                // 2. Smart Backspace: Unindent 4 spaces if preceded by 4 indentation spaces
                if (e.key === 'Backspace' && this.selectionStart === this.selectionEnd) {
                    var start = this.selectionStart;
                    var lastNewline = this.value.lastIndexOf('\n', start - 1);
                    var lineStart = (lastNewline === -1) ? 0 : lastNewline + 1;
                    var lineBeforeCursor = this.value.substring(lineStart, start);
                    if (lineBeforeCursor.length >= 4 && /^[ ]+$/.test(lineBeforeCursor) && (lineBeforeCursor.length % 4 === 0)) {
                        e.preventDefault();
                        this.value = this.value.substring(0, start - 4) + this.value.substring(start);
                        this.selectionStart = this.selectionEnd = start - 4;
                        ClusterIDE.files[ClusterIDE.currentFile] = this.value;
                        ClusterIDE.updateLineNumbers();
                        ClusterIDE.updateCursorPos();
                        ClusterIDE.updateHighlight();
                        ClusterIDE.syncScroll();
                        return;
                    }
                }

                // 3. Tab Key (Insert 4 spaces)
                if (e.key === 'Tab') {
                    e.preventDefault();
                    var start = this.selectionStart;
                    var end = this.selectionEnd;
                    if (!e.shiftKey) {
                        this.value = this.value.substring(0, start) + '    ' + this.value.substring(end);
                        this.selectionStart = this.selectionEnd = start + 4;
                    } else {
                        // Shift+Tab: Unindent
                        var lastNewline = this.value.lastIndexOf('\n', start - 1);
                        var lineStart = (lastNewline === -1) ? 0 : lastNewline + 1;
                        if (this.value.substring(lineStart, lineStart + 4) === '    ') {
                            this.value = this.value.substring(0, lineStart) + this.value.substring(lineStart + 4);
                            this.selectionStart = this.selectionEnd = Math.max(lineStart, start - 4);
                        }
                    }
                    ClusterIDE.updateLineNumbers();
                    ClusterIDE.updateHighlight();
                    ClusterIDE.syncScroll();
                    return;
                }

                // 4. Save File Shortcut (Ctrl+S / Cmd+S)
                if ((e.ctrlKey || e.metaKey) && e.key === 's') {
                    e.preventDefault();
                    ClusterIDE.saveFile();
                }
            });
        }
    },
    switchPanel: function(panelName) {
        this.currentPanel = panelName;
        document.querySelectorAll('.cl-activity-icon').forEach(function(el) {
            if (el.getAttribute('data-panel') === panelName) {
                el.style.color = '#58a6ff';
                el.style.borderLeft = '2px solid #58a6ff';
                el.style.backgroundColor = '#161b22';
            } else {
                el.style.color = '#8b949e';
                el.style.borderLeft = '2px solid transparent';
                el.style.backgroundColor = 'transparent';
            }
        });
        document.querySelectorAll('.cl-sidebar-view').forEach(function(el) {
            if (el.getAttribute('id') === 'panel-' + panelName) {
                el.style.display = 'flex';
            } else {
                el.style.display = 'none';
            }
        });
        if (panelName === 'git') this.refreshGitStatus();
    },
    switchConsoleTab: function(tabName) {
        this.currentConsoleTab = tabName;
        document.querySelectorAll('.cl-console-tab').forEach(function(el) {
            if (el.getAttribute('data-tab') === tabName) {
                el.style.color = '#58a6ff';
                el.style.borderBottom = '2px solid #58a6ff';
            } else {
                el.style.color = '#8b949e';
                el.style.borderBottom = '2px solid transparent';
            }
        });
        var termView = document.getElementById('ide-terminal-output');
        var probView = document.getElementById('ide-problems-content');
        if (termView && probView) {
            if (tabName === 'problems') {
                termView.style.display = 'none';
                probView.style.display = 'flex';
            } else {
                termView.style.display = 'block';
                probView.style.display = 'none';
            }
        }
    },
    switchFile: function(filename) {
        var editor = document.getElementById('cluster-code-editor');
        var gutter = document.getElementById('ide-line-gutter');
        if (!editor) return;
        this.files[this.currentFile] = editor.value;
        this.currentFile = filename;
        if (this.openTabs.indexOf(filename) === -1) {
            this.openTabs.push(filename);
        }
        editor.value = this.files[filename] || '';
        this.updateLineNumbers();
        this.renderTabs();
        this.updateCursorPos();
        this.updateHighlight();
        if (gutter) gutter.scrollTop = 0;
        editor.scrollTop = 0;
        editor.scrollLeft = 0;
        this.syncScroll();
        var statusFile = document.getElementById('ide-status-file');
        if (statusFile) statusFile.innerText = 'File: ' + filename;
        document.querySelectorAll('.cl-tree-item').forEach(function(el) {
            if (el.getAttribute('data-file') === filename) {
                el.style.backgroundColor = 'rgba(88, 166, 255, 0.15)';
                el.style.color = '#58a6ff';
            } else {
                el.style.backgroundColor = 'transparent';
                el.style.color = '#e6edf3';
            }
        });
    },
    closeTab: function(e, filename) {
        e.stopPropagation();
        var idx = this.openTabs.indexOf(filename);
        if (idx !== -1 && this.openTabs.length > 1) {
            this.openTabs.splice(idx, 1);
            if (this.currentFile === filename) {
                this.switchFile(this.openTabs[Math.max(0, idx - 1)]);
            } else {
                this.renderTabs();
            }
        }
    },
    renderTabs: function() {
        var container = document.getElementById('ide-tab-bar');
        if (!container) return;
        var html = '';
        for (var i = 0; i < this.openTabs.length; i++) {
            var f = this.openTabs[i];
            var isActive = (f === this.currentFile);
            var bg = isActive ? '#0d1117' : '#161b22';
            var border = isActive ? '2px solid #58a6ff' : '2px solid transparent';
            var color = isActive ? '#ffffff' : '#8b949e';
            html += '<div onclick="ClusterIDE.switchFile(\'' + f + '\')" style="padding:7px 14px; font-size:12px; font-weight:500; color:' + color + '; background:' + bg + '; border-top:' + border + '; cursor:pointer; display:flex; align-items:center; gap:8px; border-right:1px solid #21262d;"><span>' + f + '</span><span onclick="ClusterIDE.closeTab(event, \'' + f + '\')" style="opacity:0.6; font-size:11px;">✕</span></div>';
        }
        html += '<div style="flex:1;"></div><span style="font-size:11px; color:#8b949e; padding-right:12px;">Cluster Language v1.0.0</span>';
        container.innerHTML = html;
    },
    saveFile: function() {
        var editor = document.getElementById('cluster-code-editor');
        var statusPill = document.getElementById('ide-status-pill');
        if (!editor) return;
        this.files[this.currentFile] = editor.value;
        var payload = this.currentFile + '\n' + editor.value;
        fetch('/api/save', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: payload
        }).then(function(res) { return res.text(); })
        .then(function(msg) {
            if (statusPill) {
                var now = new Date();
                var timeStr = now.getHours() + ':' + String(now.getMinutes()).padStart(2, '0') + ':' + String(now.getSeconds()).padStart(2, '0');
                statusPill.innerText = '✔ Saved (' + timeStr + ')';
                statusPill.style.color = '#3fb950';
            }
        });
    },
    formatCode: function() {
        var editor = document.getElementById('cluster-code-editor');
        var statusBadge = document.getElementById('ide-status-pill');
        if (!editor) return;
        if (statusBadge) { statusBadge.innerText = '🎨 Formatting...'; statusBadge.style.color = '#d29922'; }
        fetch('/api/format', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: editor.value
        }).then(function(res) { return res.text(); })
        .then(function(formattedCode) {
            editor.value = formattedCode;
            ClusterIDE.files[ClusterIDE.currentFile] = formattedCode;
            ClusterIDE.updateLineNumbers();
            ClusterIDE.updateHighlight();
            ClusterIDE.syncScroll();
            if (statusBadge) {
                statusBadge.innerText = '✔ Formatted';
                statusBadge.style.color = '#3fb950';
            }
        }).catch(function(err) {
            if (statusBadge) { statusBadge.innerText = '✖ Format Error'; statusBadge.style.color = '#f85149'; }
        });
    },
    jumpToLine: function(targetLine, targetCol) {
        var editor = document.getElementById('cluster-code-editor');
        if (!editor) return;
        var lines = editor.value.split('\n');
        var lineIdx = Math.max(1, Math.min(targetLine, lines.length)) - 1;
        var colIdx = Math.max(1, targetCol || 1) - 1;
        var offset = 0;
        for (var i = 0; i < lineIdx; i++) offset += lines[i].length + 1;
        offset += Math.min(colIdx, lines[lineIdx].length);
        editor.focus();
        editor.setSelectionRange(offset, offset);
        editor.scrollTop = Math.max(0, (lineIdx - 4) * 21);
        this.syncScroll();
        this.updateCursorPos();
    },
    parseDiagnostics: function(rawText) {
        var list = [];
        var lines = rawText.split('\n');
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            var m = l.match(/:(\d+):(\d+):\s*(error|warning)(?:\[(.*?)\])?:\s*(.*)/i);
            if (m) {
                list.push({
                    line: parseInt(m[1], 10),
                    col: parseInt(m[2], 10),
                    type: (m[3] || 'error').toLowerCase(),
                    code: m[4] || '',
                    msg: m[5] || l
                });
            }
        }
        this.problems = list;
        this.renderProblems();
    },
    renderProblems: function() {
        var container = document.getElementById('ide-problems-content');
        var badge = document.getElementById('ide-problems-badge');
        if (badge) {
            badge.innerText = 'Problems (' + this.problems.length + ')';
            badge.style.color = (this.problems.length > 0) ? '#f85149' : '#8b949e';
        }
        if (!container) return;
        if (this.problems.length === 0) {
            container.innerHTML = '<div style="padding:16px; color:#3fb950; font-size:12px; display:flex; align-items:center; gap:8px;"><span>✔</span><span>No diagnostics problems detected across open files. Typecheck clean.</span></div>';
            return;
        }
        var html = '<div style="display:flex; flex-direction:column; gap:4px; padding:8px;">';
        for (var i = 0; i < this.problems.length; i++) {
            var p = this.problems[i];
            var icon = (p.type === 'error') ? '✖' : '⚠';
            var color = (p.type === 'error') ? '#f85149' : '#d29922';
            html += '<div onclick="ClusterIDE.jumpToLine(' + p.line + ', ' + p.col + ')" style="display:flex; align-items:center; gap:10px; padding:6px 10px; background:#161b22; border-left:3px solid ' + color + '; border-radius:4px; font-size:12px; cursor:pointer; color:#e6edf3;" onmouseover="this.style.background=\'#21262d\'" onmouseout="this.style.background=\'#161b22\'">';
            html += '<span style="color:' + color + '; font-weight:700;">' + icon + '</span>';
            html += '<span style="background:#21262d; color:#8b949e; padding:2px 6px; border-radius:3px; font-family:monospace; font-size:11px;">Ln ' + p.line + ', Col ' + p.col + '</span>';
            if (p.code) html += '<span style="color:' + color + '; font-family:monospace; font-size:11px;">[' + p.code + ']</span>';
            html += '<span style="flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + p.msg + '</span>';
            html += '<span style="color:#58a6ff; font-size:11px;">Jump ➔</span>';
            html += '</div>';
        }
        html += '</div>';
        container.innerHTML = html;
    },
    refreshGitStatus: function() {
        var gitList = document.getElementById('git-status-content');
        if (!gitList) return;
        gitList.innerText = 'Checking repository status...';
        fetch('/api/git-status')
        .then(function(res) { return res.text(); })
        .then(function(text) {
            gitList.innerText = text;
        });
    },
    updateCursorPos: function() {
        var editor = document.getElementById('cluster-code-editor');
        var posLabel = document.getElementById('ide-cursor-pos');
        if (!editor || !posLabel) return;
        var textBefore = editor.value.substring(0, editor.selectionStart);
        var lines = textBefore.split('\n');
        var row = lines.length;
        var col = lines[lines.length - 1].length + 1;
        posLabel.innerText = 'Ln ' + row + ', Col ' + col;
    },
    updateLineNumbers: function() {
        var editor = document.getElementById('cluster-code-editor');
        var gutter = document.getElementById('ide-line-gutter');
        if (editor && gutter) {
            var lines = editor.value.split('\n').length;
            var nums = '';
            for (var i = 1; i <= Math.max(lines, 30); i++) nums += i + '\n';
            gutter.innerText = nums;
        }
    },
    renderAnsi: function(text) {
        if (!text) return '';
        var escaped = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        var formatted = escaped
            .replace(/\u001b\[92m|\u001b\[32m/g, '<span style="color:#3fb950; font-weight:600;">')
            .replace(/\u001b\[91m|\u001b\[31m/g, '<span style="color:#f85149; font-weight:600;">')
            .replace(/\u001b\[93m|\u001b\[33m/g, '<span style="color:#d29922; font-weight:600;">')
            .replace(/\u001b\[94m|\u001b\[34m/g, '<span style="color:#58a6ff; font-weight:600;">')
            .replace(/\u001b\[0m/g, '</span>')
            .replace(/\u001b\[[0-9;]*m/g, '');
        return formatted;
    },
    runCode: function() {
        var editor = document.getElementById('cluster-code-editor');
        var consoleOut = document.getElementById('ide-terminal-output');
        var statusBadge = document.getElementById('ide-status-pill');
        if (!editor || !consoleOut) return;
        this.switchConsoleTab('terminal');
        if (statusBadge) { statusBadge.innerText = '⚡ Compiling...'; statusBadge.style.color = '#d29922'; }
        consoleOut.innerHTML = '<span style="color:#8b949e;">Compiling target (-O3) via Cluster LLVM pipeline...</span>\n';
        var startTime = performance.now();
        fetch('/api/run', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: editor.value
        }).then(function(res) { return res.text(); })
        .then(function(output) {
            var duration = ((performance.now() - startTime) / 1000).toFixed(2);
            consoleOut.innerHTML = ClusterIDE.renderAnsi(output);
            ClusterIDE.parseDiagnostics(output);
            var clean = output.replace(/\u001b\[[0-9;]*m/g, '');
            if (statusBadge) {
                if (clean.includes('Finished') && (clean.includes('target(s)') || clean.includes('build'))) {
                    statusBadge.innerText = '✔ Success (' + duration + 's)';
                    statusBadge.style.color = '#3fb950';
                } else if (clean.includes('error') || clean.includes('Error')) {
                    statusBadge.innerText = '✖ Build Error';
                    statusBadge.style.color = '#f85149';
                    if (ClusterIDE.problems.length > 0) ClusterIDE.switchConsoleTab('problems');
                } else {
                    statusBadge.innerText = '✔ Complete (' + duration + 's)';
                    statusBadge.style.color = '#3fb950';
                }
            }
            ClusterIDE.updatePreview(output);
        }).catch(function(err) {
            consoleOut.innerText = 'Network error: ' + err.message;
            if (statusBadge) { statusBadge.innerText = '✖ Network Error'; statusBadge.style.color = '#f85149'; }
        });
    },
    checkCode: function(isSilent) {
        var editor = document.getElementById('cluster-code-editor');
        var consoleOut = document.getElementById('ide-terminal-output');
        var statusBadge = document.getElementById('ide-status-pill');
        if (!editor || !consoleOut) return;
        if (!isSilent) {
            this.switchConsoleTab('terminal');
            consoleOut.innerHTML = '<span style="color:#8b949e;">Running Pratt parser & typecheck...</span>\n';
        }
        fetch('/api/check', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: editor.value
        }).then(function(res) { return res.text(); })
        .then(function(output) {
            if (!isSilent) consoleOut.innerHTML = ClusterIDE.renderAnsi(output);
            ClusterIDE.parseDiagnostics(output);
            var clean = output.replace(/\u001b\[[0-9;]*m/g, '');
            if (statusBadge) {
                if (clean.includes('ok') || clean.includes('PASSED') || clean.includes('clean')) {
                    statusBadge.innerText = '✔ Typecheck OK';
                    statusBadge.style.color = '#3fb950';
                } else {
                    statusBadge.innerText = '✖ Type Error';
                    statusBadge.style.color = '#f85149';
                    if (!isSilent && ClusterIDE.problems.length > 0) ClusterIDE.switchConsoleTab('problems');
                }
            }
        });
    },
    fetchLlvmIr: function() {
        var editor = document.getElementById('cluster-code-editor');
        var consoleOut = document.getElementById('ide-terminal-output');
        if (!editor || !consoleOut) return;
        this.switchConsoleTab('terminal');
        consoleOut.innerText = 'Emitting SSA LLVM IR...\n';
        fetch('/api/llvm', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: editor.value
        }).then(function(res) { return res.text(); })
        .then(function(output) {
            consoleOut.innerText = output;
        });
    },
    fetchClilIr: function() {
        var editor = document.getElementById('cluster-code-editor');
        var consoleOut = document.getElementById('ide-terminal-output');
        if (!editor || !consoleOut) return;
        this.switchConsoleTab('terminal');
        consoleOut.innerText = 'Emitting SSA CL-IL IR...\n';
        fetch('/api/clil', {
            method: 'POST',
            headers: { 'Content-Type': 'text/plain' },
            body: editor.value
        }).then(function(res) { return res.text(); })
        .then(function(output) {
            consoleOut.innerText = output;
        });
    },
    updatePreview: function(rawOutput) {
        var previewFrame = document.getElementById('ide-preview-frame');
        if (!previewFrame) return;
        var htmlContent = '';
        if (rawOutput.includes('<!DOCTYPE html>')) {
            var start = rawOutput.indexOf('<!DOCTYPE html>');
            htmlContent = rawOutput.substring(start);
        } else {
            htmlContent = '<div style="padding:24px; color:#e6edf3; font-family:sans-serif; background:#0d1117;"><h3 style="color:#58a6ff;">Program Stdout</h3><pre style="color:#3fb950; font-family:monospace; line-height:1.5;">' + rawOutput + '</pre></div>';
        }
        previewFrame.srcdoc = htmlContent;
    },
    setPreviewTarget: function(target) {
        this.previewTarget = target;
        document.querySelectorAll('.preview-target-btn').forEach(function(b) {
            if (b.getAttribute('data-target') === target) {
                b.style.backgroundColor = '#1f6feb';
                b.style.color = '#ffffff';
            } else {
                b.style.backgroundColor = '#21262d';
                b.style.color = '#8b949e';
            }
        });
        var previewFrame = document.getElementById('ide-preview-frame');
        if (target === 'android' && previewFrame) {
            previewFrame.srcdoc = '<div style="padding:20px; color:#e6edf3; font-family:monospace; background:#0d1117;"><h4 style="color:#3fb950;">&lt;Android Jetpack XML Layout View&gt;</h4><pre style="color:#8b949e;">&lt;androidx.constraintlayout.widget.ConstraintLayout\n    xmlns:android="http://schemas.android.com/apk/res/android"\n    android:layout_width="match_parent"\n    android:layout_height="match_parent"&gt;\n    &lt;!-- Generated by Cluster UI Android Target --&gt;\n&lt;/androidx.constraintlayout.widget.ConstraintLayout&gt;</pre></div>';
        } else if (target === 'apple' && previewFrame) {
            previewFrame.srcdoc = '<div style="padding:20px; color:#e6edf3; font-family:monospace; background:#0d1117;"><h4 style="color:#58a6ff;">// Apple SwiftUI View Representation</h4><pre style="color:#8b949e;">import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        VStack(spacing: 12) {\n            Text("Cluster UI on Apple Metal")\n        }\n    }\n}</pre></div>';
        } else {
            this.runCode();
        }
    }
};

window.addEventListener('DOMContentLoaded', function() {
    ClusterIDE.init();
    window.addEventListener('keydown', function(e) {
        if (e.key === 'F5') { e.preventDefault(); ClusterIDE.runCode(); }
        if (e.key === 'F6') { e.preventDefault(); ClusterIDE.checkCode(false); }
        if (e.key === 'F7') { e.preventDefault(); ClusterIDE.formatCode(); }
    });
});
