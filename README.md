# ⚡ Cluster Live Studio

A high-performance, real-time web IDE and live compilation playground for **Cluster Language v1.0.0**, featuring a backend web server written **100% in pure Cluster Language** with zero external dependencies.

---

## 🌟 Key Features

- **Instant Real-Time Compilation:**
  - Powered by Cluster's native LLVM 23 backend (`bin/cl`). Compiles and runs in **milliseconds**.
- **100% Pure Cluster Language HTTP Server (`server.cl`):**
  - Native socket engine built on `std/net.cl` (`tcp_listen`, `tcp_accept`, `tcp_read`, `tcp_write`).
  - Implements custom HTTP/1.1 request routing, query parsing, and response framing.
- **Turbo C++ Nostalgia Mode:**
  - One-click toggle switch to transform the IDE into the classic 2019 **Turbo C++ blue-window aesthetic** (bright yellow text, cyan headers, and blue panels).
- **Multiple Compilation Modes:**
  1. **⚡ Native Binary (-O3):** Compiles code directly into native machine instructions via LLVM and executes immediately.
  2. **🔍 Pratt Diagnostics:** Instant streaming lexer and Pratt parser syntax/type check.
  3. **⚙️ Direct LLVM IR:** Inspect generated LLVM 23 intermediate representation.
- **Auto-Run (Live Re-compilation):**
  - Instant live execution as you type (400ms debounce) for an interactive feedback loop.
- **Built-in Templates:**
  - `model Transaction` with automatic JSON serialization & compile-time reflection.
  - Native concurrency with `spawn`.
  - Unquoted & dotted module imports (`import std/ssg/document.cl`).
  - Pattern matching (`match / case`).
  - Native algorithms (Fibonacci, Math).

---

## 🚀 Quickstart

### Launch the Server
```bash
cd /media/alamgir-zk/debian13-hdd/alamgir-zk/zk-company/cluster-live
chmod +x start.sh
./start.sh
```

Or run directly with the Cluster native compiler:
```bash
/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl run server.cl
```

### Access the Web Playground
Open your browser at:
```
http://localhost:8080
```

---

## 📁 Project Structure

```
cluster-live/
├── server.cl          # 100% Pure Cluster Language HTTP Server & Compiler API
├── server_bin         # Precompiled native ELF executable (-O3)
├── start.sh           # One-click launcher script
├── README.md          # Project documentation
└── web/               # Frontend Assets
    ├── index.html     # Split-screen responsive IDE layout
    ├── app.js         # Client-side editor controller & live runner
    └── style.css      # Dark theme & Turbo C++ mode styling
```

---

## 📡 HTTP API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/` | Serves the main IDE interface (`web/index.html`) |
| `GET` | `/style.css` | Serves stylesheet with Turbo C++ mode rules |
| `GET` | `/app.js` | Serves client runtime controller |
| `GET` | `/api/health` | Returns server health status and compiler version |
| `POST` | `/api/run` | Compiles & executes Cluster source code; returns output |
| `POST` | `/api/check` | Runs Pratt syntax & type checker; returns diagnostics |
| `POST` | `/api/llvm` | Emits raw LLVM 23 IR |

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Ctrl + Enter` / `Cmd + Enter` | Compile and Run Code |
| `F9` | Classic Turbo C++ Run Shortcut |
| `Tab` | Indent 4 spaces |

---

## 🤝 Contribution Guidelines (Pure Cluster Mandate)

All contributions to `cluster-live` are welcome under the following conditions:
1. **100% Pure Cluster Code:** All server logic, routing, compiler interfaces, and core backend infrastructure must be written strictly in pure Cluster language (`.cl`).
2. **Zero External Runtime Dependencies:** No external third-party backends (Node.js, Python, Go, Rust) may be introduced.
3. **Architecture Integrity:** Frontend client code must remain lightweight, high-performance, and compatible with modern standards without external heavy frameworks.

---

## 📄 License

Cluster Community & Fair-Source License (CCFL v2.0 / Strict-Distribution).  
Copyright (c) 2026 Mohammad Zaid (zk-mohammad) / Cluster Organization. See [LICENSE](LICENSE) for details.
