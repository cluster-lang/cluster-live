#!/usr/bin/env bash
# ==============================================================================
# Cluster Live Studio — Launcher Script
# Starts the Pure Cluster Language Web IDE Server
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

CLUSTER_BIN="/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl"

if [ ! -f "$DIR/server_bin" ] || [ "$DIR/server.cl" -nt "$DIR/server_bin" ]; then
    echo "⚡ Compiling Cluster Live HTTP Server with native LLVM backend..."
    "$CLUSTER_BIN" build server.cl -o server_bin
    echo "✔ Build complete: server_bin"
fi

echo "🚀 Starting Cluster Live Studio..."
exec ./server_bin
