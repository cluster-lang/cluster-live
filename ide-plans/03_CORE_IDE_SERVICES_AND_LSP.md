# Cluster-IDE: Core Engine Services & LSP Architecture
**Document ID:** `IDE-PLN-003`  
**Core Technologies:** `std/io.cl`, `cl` Driver, Cluster LSP Server  

---

## 1. Overview of Core Backend Services

Cluster-IDE decouples UI presentation from background language services through 4 primary service modules:

```
┌────────────────────────────────────────────────────────┐
│                   Cluster-IDE UI Layer                 │
└───────────────────────────┬────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  File System  │   │   Compiler    │   │ Language (LSP)│
│    Service    │   │   Pipeline    │   │    Service    │
│  (std/io.cl)  │   │ (cl run/build)│   │   (cl lsp)    │
└───────────────┘   └───────────────┘   └───────────────┘
```

---

## 2. File System Service (`std/io.cl`)

The IDE relies directly on Cluster's native file management library:
* **Opening Files:** `io_read(path)` loads text content into editor state without locking file descriptors.
* **Saving Files:** `io_write(path, content)` flushes buffer atomically to disk.
* **Auto-Save & Temp Snapshots:** Writes to `.cl_cache/autosave/` before invoking compilers.
* **Directory Trees:** Scans project directories and populates the tree view with icons determined by `io_path_extension(path)`.
* **File Operations:**
  * New File: `io_write(new_path, "")`
  * New Folder: `io_mkdir(dir_path)`
  * Delete: `io_delete(path)` or `io_rmdir(dir_path)`
  * Duplicate: `io_copy(src, dst)`

---

## 3. Compiler Pipeline Service (`cl`)

Cluster-IDE invokes the native `cl` driver via sub-process or direct library calls:
* **Syntax & Typecheck (`cl check <file>`):**
  * Emits streaming Pratt parser diagnostics in **< 30 ms**.
  * Underlines syntax and type errors with line and column accuracy.
* **Execute (`cl run <file> [-- args]`):**
  * Compiles with `-O3` and runs native binary in **~180 ms**.
  * Captures stdout/stderr into the bottom Terminal console.
* **LLVM IR Inspection (`cl emit-llvm <file>`):**
  * Emits pure SSA LLVM IR for compiler debugging.
* **Formatter (`cl fmt <file> -w`):**
  * Auto-formats code on save (`Ctrl+S` / `Cmd+S`) with 100% idempotent formatting.

---

## 4. Language Server Protocol (LSP) Service

Cluster already provides an integrated LSP implementation (`cl lsp`). Cluster-IDE binds directly to this service:
* **Semantic Highlighting:** Distinguishes keywords (`fn`, `model`, `let`, `mut`), types (`int`, `string`, `bool`, `vector`), and builtins (`file_read`, `pln`).
* **Live Autocomplete:** Suggests widget names (`Button`, `Card`, `Column`), standard library methods (`io_path_join`), and model properties.
* **Hover Documentation:** Displays docstrings and parameter signatures when hovering over any function.
* **Go to Definition:** Jumps directly to model or function declarations across the workspace.
