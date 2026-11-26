#!/usr/bin/env bash
# ==============================================================================
# Cluster Live Studio — Service Manager
# Starts, stops, and monitors the Pure Cluster Language Web Studio Server
# Usage: ./start.sh {start|stop|restart|status}
# Contributor: zk-mohammad <ZaidKhan-alamgir@proton.me>
# License: CCFL-2.0
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PID_FILE="$DIR/.server.pid"
LOG_FILE="$DIR/server.log"
PORT=8080
CLUSTER_BIN="$DIR/bin/cl"

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    # Fallback: check if port 8080 is listening
    if lsof -i :$PORT -sTCP:LISTEN >/dev/null 2>&1 || ss -ltn "( sport = :$PORT )" | grep -q ":$PORT"; then
        return 0
    fi
    return 1
}

get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE" 2>/dev/null
    else
        lsof -ti :$PORT 2>/dev/null | head -n 1
    fi
}

start_server() {
    if is_running; then
        local pid=$(get_pid)
        echo "⚡ Cluster Live Studio is already running on http://localhost:$PORT (PID: $pid)"
        return 0
    fi

    # Compile server_bin if missing or source/compiler updated
    if [ ! -f "$DIR/server_bin" ] || [ "$DIR/server.cl" -nt "$DIR/server_bin" ] || [ "$CLUSTER_BIN" -nt "$DIR/server_bin" ]; then
        echo "⚡ Compiling Cluster Live HTTP Server with LLVM primary backend..."
        "$CLUSTER_BIN" build server.cl -O3 -o server_bin
        echo "✔ Build complete: server_bin"
    fi

    echo "🚀 Starting Cluster Live Studio on http://localhost:$PORT..."
    nohup ./server_bin > "$LOG_FILE" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"
    sleep 0.5

    if kill -0 "$new_pid" 2>/dev/null; then
        echo "✔ Cluster Live Studio started successfully (PID: $new_pid)"
        echo "🌐 URL: http://localhost:$PORT"
    else
        echo "❌ Failed to start server. Check $LOG_FILE for details:"
        tail -n 10 "$LOG_FILE" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 1
    fi
}

stop_server() {
    local stopped=0
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "🛑 Stopping Cluster Live Studio (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 0.5
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            stopped=1
        fi
        rm -f "$PID_FILE"
    fi

    # Ensure any lingering process on port 8080 is stopped
    local port_pids=$(lsof -ti :$PORT 2>/dev/null || true)
    if [ -n "$port_pids" ]; then
        echo "🛑 Freeing port $PORT (PIDs: $port_pids)..."
        kill $port_pids 2>/dev/null || true
        sleep 0.5
        kill -9 $port_pids 2>/dev/null || true
        stopped=1
    fi

    if [ "$stopped" -eq 1 ]; then
        echo "✔ Cluster Live Studio stopped."
    else
        echo "⚡ Cluster Live Studio is not currently running."
    fi
}

status_server() {
    if is_running; then
        local pid=$(get_pid)
        local mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}' || echo "N/A")
        echo "● Cluster Live Studio is RUNNING"
        echo "  PID:     $pid"
        echo "  Memory:  $mem"
        echo "  URL:     http://localhost:$PORT"
    else
        echo "○ Cluster Live Studio is STOPPED"
    fi
}

case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 0.5
        start_server
        ;;
    status)
        status_server
        ;;
    *)
        echo "Cluster Live Studio Management Script"
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start    Launch server in background on port $PORT"
        echo "  stop     Terminate running server and free port $PORT"
        echo "  restart  Restart the server"
        echo "  status   Show current runtime status and memory"
        exit 1
        ;;
esac
