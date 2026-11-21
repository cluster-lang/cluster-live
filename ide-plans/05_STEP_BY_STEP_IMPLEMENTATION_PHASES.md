# Cluster-IDE: Step-by-Step Implementation Roadmap
**Document ID:** `IDE-PLN-005`  
**Goal:** Deliver Working Self-Hosting Cluster-IDE Milestone by Milestone  

---

## 1. Roadmap Overview & Timeline

```
[ Phase 1: Pure Cluster UI Shell ] ──► [ Phase 2: File System & Workspace ] ──► [ Phase 3: Live Compiler & LSP ] ──► [ Phase 4: Multi-Target Preview ] ──► [ Phase 5: Cross-Device Packaging ]
```

---

## 2. Detailed Implementation Phases

### Phase 1: Cluster-IDE Shell Prototype (Current Milestone)
* **Objective:** Build the complete IDE visual interface 100% in pure Cluster Language using Cluster UI widgets.
* **Deliverable:** `cluster-live/ide.cl`
* **Features:**
  * Top Navigation Bar with Run/Check/Settings action triggers.
  * Left Activity Rail (`NavigationRail`) with File Explorer, Search, and Git tabs.
  * File Explorer Tree (`ListTile` + `Badge`) showing project files.
  * Center Multi-Tab Editor Area with line numbering and syntax-highlighted code block.
  * Right Live Preview Pane with Web/Android/Apple target selector.
  * Bottom Integrated Terminal / Output Console.
* **Verification:** Compile and serve directly via `server.cl` on port 8080.

---

### Phase 2: File System & Workspace Management
* **Objective:** Enable true file editing, saving, and directory browsing using `std/io.cl`.
* **Features:**
  * Recursive workspace directory listing via `io_path_join` and `io_path_dirname`.
  * Open file on click: loads file content via `io_read(path)` into the active editor tab.
  * Save file: flushes editor buffer via `io_write(path, content)` atomically.
  * Create new file / folder modals using `Dialog` and `TextInput` widgets.
  * Auto-save debounce (500 ms) before compiler triggers.

---

### Phase 3: Compiler Execution & Real-Time Diagnostics
* **Objective:** Wire the IDE to the native `cl` driver for instant compile-and-run feedback.
* **Features:**
  * ⚡ **Run Button (`F5`):** Executes `cl run <file>` with `-O3` and captures output in the terminal console.
  * ✔ **Check Button:** Runs Pratt streaming parser & typecheck (`cl check <file>`) in < 30 ms.
  * **Click-to-Line Error Jumping:** Parses compiler error strings (e.g. `main.cl:14:5: error[E3001]`) and highlights the exact line in the editor.
  * **Formatting on Save:** Invokes `cl fmt -w` to format code automatically.

---

### Phase 4: Real-Time Multi-Target Live Preview
* **Objective:** Hot-reload UI previews as code is typed.
* **Features:**
  * **Web Preview:** Renders live Cluster UI widgets into an interactive sandbox iframe.
  * **Android Jetpack Preview:** Displays lowered Android XML layout with component hierarchy inspector.
  * **Apple SwiftUI Preview:** Displays generated SwiftUI code and simulated iOS canvas.
  * **Target Toggle:** Instant switching between Web, Android, and Apple previews.

---

### Phase 5: Cross-Platform Native Packaging
* **Objective:** Distribute native standalone packages for all major operating systems.
* **Targets:**
  1. **Linux:** Single self-contained ELF executable (`cluster-ide`) with WebKitGTK wrapper.
  2. **Windows:** Portable Win32 executable (`cluster-ide.exe`) using Microsoft WebView2.
  3. **Android:** Native Android APK (`ClusterIDE.apk`) with ARM64 compiler bundle.
  4. **Apple:** Universal macOS App (`Cluster IDE.app`) and iPadOS bundle.
  5. **Web PWA:** Zero-install web app with offline Service Worker support.
