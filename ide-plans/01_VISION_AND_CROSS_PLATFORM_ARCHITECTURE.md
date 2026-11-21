# Cluster-IDE: Vision & Cross-Platform Architecture
**Document ID:** `IDE-PLN-001`  
**Author:** Deepmind Antigravity  
**Goal:** Self-Hosting Universal IDE Written 100% in Cluster Language & Cluster UI  
**Target Matrix:** Android, Apple (iOS/macOS), Windows, Mac, Linux, and Modern Web  

---

## 1. Vision: The Self-Hosting Cross-Device Developer Studio

Most modern IDEs suffer from massive bloat:
* **VS Code:** Consumes 1.2 GB+ of RAM, running on heavy Electron/Chromium with thousands of node modules.
* **Android Studio:** Consumes 3 GB–6 GB of RAM, runs on JVM, and cannot run on phones or tablets.
* **Xcode:** Restricted solely to macOS; cannot run on Linux, Windows, or Android.

### The Cluster-IDE Vision:
A high-performance, lightweight (under 25 MB footprint, under 40 MB RAM), full-featured IDE **written entirely in Cluster Language** using **Cluster UI**.
Because Cluster UI compiles directly to:
* **Web:** Semantic HTML5/CSS3 + Micro-Runtime (< 0.4 KB)
* **Android:** Native Android Jetpack Layouts & Views
* **Apple:** Native SwiftUI Views for macOS & iOS
* **Desktop (Windows/Linux/Mac):** Pure native binary via Cluster Compiler + lightweight native web/compositor window

Developers can run the **exact same IDE**:
* On a high-end Linux/Windows workstation.
* On a MacBook or iPad.
* On an Android tablet or phone while traveling.
* In any modern web browser with zero installation.

---

## 2. High-Level System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Cluster-IDE User Interface                       │
│       (Written 100% in Cluster Language using Cluster UI Widgets)       │
├────────────────────────────────┬───────────────────────────────────────┤
│ Dockable Left Rail             │ Central Multi-Tab Editor Workspace    │
│ • File Explorer (std/io.cl)    │ • Syntax Highlighting & Line Numbers   │
│ • Project Tree & New Files     │ • Live Code Autocomplete & Tooltips   │
│ • Git Status & Commit View     │ • Multi-Cursor & Find / Replace        │
├────────────────────────────────┴───────────────────────────────────────┤
│ Right Preview & Inspector      │ Bottom Interactive Console & Terminal │
│ • Live HTML5 / UI Preview      │ • Compiler Output (cl build/run)      │
│ • Android XML Layout Preview   │ • Error Diagnostics with Line Jumping │
│ • SwiftUI View Preview         │ • REPL & stdin input buffer           │
└────────────────────────────────┴───────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       Cluster IDE Core Engine                          │
│                                                                        │
│   ┌───────────────────────────┐     ┌──────────────────────────────┐   │
│   │   Project & File System   │     │   Cluster Language Server    │   │
│   │    Module (std/io.cl)     │     │      (cl lsp / parser)       │   │
│   └───────────────────────────┘     └──────────────────────────────┘   │
│   ┌───────────────────────────┐     ┌──────────────────────────────┐   │
│   │   Live Compiler Bridge    │     │   Multi-Target Lowering      │   │
│   │ (cl build, run, emit-llvm)│     │  (Web, Android, Apple Swift) │   │
│   └───────────────────────────┘     └──────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Universal Target Adapters                       │
│                                                                        │
│   [ Linux / Windows / Mac ]      [ Android Target ]    [ Apple Target ] │
│   Native ELF/EXE binary via     Native APK with        macOS/iOS App    │
│   Cluster compiler + Window     Jetpack + WebView      with SwiftUI     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Dual Execution Architecture

Cluster-IDE supports two seamless operational modes:

### Mode A: Embedded Local Mode (Native Desktop & Mobile)
* The IDE binary directly invokes the local `cl` driver via native process calls or embedded LLVM library.
* Reads and writes local files directly via `std/io.cl`.
* Operates 100% offline with zero network latency.

### Mode B: Cloud / Remote Studio Mode (`cluster-live` Protocol)
* The IDE runs in a browser or thin mobile client.
* Communicates over high-speed HTTP/WebSocket with `server.cl` running on a developer server or cloud workstation.
* Can compile and run 10,000-line projects on an ordinary smartphone without draining mobile battery.

---

## 4. Key Architectural Goals & Performance Budget

| Metric | Target Budget | Compared to VS Code | Compared to Android Studio |
| :--- | :---: | :---: | :---: |
| **Cold Startup Time** | **< 150 ms** | 2.5s – 5.0s | 12s – 35s |
| **Idle Memory (RAM)** | **< 45 MB** | 800 MB – 1.4 GB | 2.5 GB – 5.0 GB |
| **Binary Footprint** | **< 20 MB** | 350 MB | 1.8 GB |
| **Code Completion** | **< 8 ms** | 30 ms – 120 ms | 50 ms – 200 ms |
| **Compile & Run Feedback** | **< 250 ms** | Dependent on plugins | 15s – 60s (Gradle) |
