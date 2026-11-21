// ==============================================================================
// Cluster Live Studio — HTTP Server
// 100% Pure Cluster Language Web Server & Live Compiler Engine
// ==============================================================================

import std/net.cl

fn get_request_method(raw: string) -> string:
    let rlen: int = len(raw)
    let mut i: int = 0
    while i < rlen:
        if char_at(raw, i) == " ":
            return substring(raw, 0, i)
        i = i + 1
    return "GET"

fn get_request_path(raw: string) -> string:
    let rlen: int = len(raw)
    if rlen < 4:
        return "/"
    let mut sp1: int = -1
    let mut i: int = 0
    while i < rlen:
        if char_at(raw, i) == " ":
            sp1 = i
            break
        i = i + 1
    if sp1 < 0:
        return "/"
    let mut sp2: int = -1
    let mut j: int = sp1 + 1
    while j < rlen:
        if char_at(raw, j) == " ":
            sp2 = j
            break
        j = j + 1
    if sp2 < 0:
        sp2 = rlen
    let mut path: string = substring(raw, sp1 + 1, sp2 - sp1 - 1)
    let mut qp: int = 0
    while qp < len(path):
        if char_at(path, qp) == "?":
            return substring(path, 0, qp)
        qp = qp + 1
    return path

fn find_http_body(raw: string) -> string:
    let rlen: int = len(raw)
    let mut i: int = 0
    while i < rlen - 3:
        if char_at(raw, i) == "\r" and char_at(raw, i + 1) == "\n" and char_at(raw, i + 2) == "\r" and char_at(raw, i + 3) == "\n":
            return substring(raw, i + 4, rlen - (i + 4))
        i = i + 1
    let mut j: int = 0
    while j < rlen - 1:
        if char_at(raw, j) == "\n" and char_at(raw, j + 1) == "\n":
            return substring(raw, j + 2, rlen - (j + 2))
        j = j + 1
    return ""

fn make_http_response(status_line: string, content_type: string, body: string) -> string:
    let mut resp: string = "HTTP/1.1 " + status_line + "\r\n"
    resp = resp + "Content-Type: " + content_type + "\r\n"
    resp = resp + "Content-Length: " + str(len(body)) + "\r\n"
    resp = resp + "Access-Control-Allow-Origin: *\r\n"
    resp = resp + "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
    resp = resp + "Access-Control-Allow-Headers: Content-Type\r\n"
    resp = resp + "Connection: close\r\n\r\n"
    resp = resp + body
    return resp

fn find_stdin_separator(body: string) -> int:
    let blen: int = len(body)
    let sep: string = "---STDIN_SEPARATOR---"
    let slen: int = len(sep)
    if blen < slen:
        return -1
    let mut i: int = 0
    while i <= blen - slen:
        if substring(body, i, slen) == sep:
            return i
        i = i + 1
    return -1

fn trim_leading_newline(s: string) -> string:
    let slen: int = len(s)
    if slen > 1 and char_at(s, 0) == "\r" and char_at(s, 1) == "\n":
        return substring(s, 2, slen - 2)
    if slen > 0 and char_at(s, 0) == "\n":
        return substring(s, 1, slen - 1)
    return s

fn execute_cluster_run(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    let mut stdin_data: string = ""
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
        let raw_stdin: string = substring(payload, sep_idx + 21, len(payload) - (sep_idx + 21))
        stdin_data = trim_leading_newline(raw_stdin)

    file_write("/tmp/cluster_live_code.cl", code)
    file_write("/tmp/cluster_live_stdin.txt", stdin_data)
    let cmd: string = "timeout 60s /home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl run /tmp/cluster_live_code.cl < /tmp/cluster_live_stdin.txt > /tmp/cluster_live_out.txt 2>&1"
    let status: int = sys_run(cmd)
    if file_exists("/tmp/cluster_live_out.txt") == 1:
        let out_text: string = file_read("/tmp/cluster_live_out.txt")
        if len(out_text) > 0:
            return out_text
    return "Error: Execution did not produce output."

fn execute_cluster_check(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
    file_write("/tmp/cluster_live_code.cl", code)
    let cmd: string = "/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl check /tmp/cluster_live_code.cl > /tmp/cluster_live_out.txt 2>&1"
    sys_run(cmd)
    if file_exists("/tmp/cluster_live_out.txt") == 1:
        let out: string = file_read("/tmp/cluster_live_out.txt")
        if len(out) == 0:
            return "✔ Pratt Lexer & Typecheck: PASSED (Zero syntax or type errors)"
        return out
    return "Check complete."

fn execute_cluster_llvm(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
    file_write("/tmp/cluster_live_code.cl", code)
    sys_run("rm -f /tmp/cluster_live.ll")
    let cmd: string = "/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl emit-llvm /tmp/cluster_live_code.cl -o /tmp/cluster_live.ll > /tmp/cluster_live_out.txt 2>&1"
    let ret: int = sys_run(cmd)
    if file_exists("/tmp/cluster_live.ll") == 1:
        let ll_code: string = file_read("/tmp/cluster_live.ll")
        if len(ll_code) > 0:
            return ll_code
    if file_exists("/tmp/cluster_live_out.txt") == 1:
        return file_read("/tmp/cluster_live_out.txt")
    return "Error: Could not emit LLVM IR."

fn execute_file_save(payload: string) -> string:
    let plen: int = len(payload)
    let mut nl_idx: int = -1
    let mut i: int = 0
    while i < plen:
        if char_at(payload, i) == "\n":
            nl_idx = i
            break
        i = i + 1
    if nl_idx <= 0:
        return "Error: Invalid save payload format (missing path)."
    let file_path: string = substring(payload, 0, nl_idx)
    let content: string = substring(payload, nl_idx + 1, plen - (nl_idx + 1))
    file_write(file_path, content)
    return "OK: File saved successfully."

fn execute_cluster_format(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
    file_write("/tmp/cluster_live_code.cl", code)
    let cmd: string = "/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl fmt -w /tmp/cluster_live_code.cl > /dev/null 2>&1"
    sys_run(cmd)
    if file_exists("/tmp/cluster_live_code.cl") == 1:
        return file_read("/tmp/cluster_live_code.cl")
    return code

fn execute_git_status() -> string:
    sys_run("git -C /home/alamgir-zk/Cluster-Family/cluster-lang status -s > /tmp/cluster_git_status.txt 2>&1")
    if file_exists("/tmp/cluster_git_status.txt") == 1:
        let out: string = file_read("/tmp/cluster_git_status.txt")
        if len(out) > 0:
            return out
    return "✔ Clean working tree (No uncommitted changes)"

fn main() -> int:
    let port: int = 8080
    let server_fd: int = tcp_listen(port)
    if server_fd < 0:
        print("❌ Failed to bind server socket on port " + str(port))
        return 1

    print("==========================================================")
    print("        ⚡ CLUSTER LIVE STUDIO (WEB IDE SERVER)          ")
    print("==========================================================")
    print("  Engine:   100% Pure Cluster Language HTTP Runtime")
    print("  Compiler: cl v1.0.0 (LLVM 23.0 Backend)")
    print("  URL:      http://localhost:" + str(port))
    print("==========================================================")
    print("Server ready. Listening for live compilation requests...\n")

    let mut running: int = 1
    while running == 1:
        let client_fd: int = tcp_accept(server_fd)
        if client_fd < 0:
            continue

        let raw_req: string = tcp_read(client_fd, 65536)
        if len(raw_req) == 0:
            tcp_close(client_fd)
            continue

        let method: string = get_request_method(raw_req)
        let path: string = get_request_path(raw_req)

        let mut resp: string = ""

        let is_get_or_head: bool = (method == "GET" or method == "HEAD")

        if method == "OPTIONS":
            resp = make_http_response("200 OK", "text/plain", "OK")
        elif is_get_or_head and (path == "/" or path == "/index.html"):
            let html: string = file_read("web/index.html")
            resp = make_http_response("200 OK", "text/html; charset=utf-8", html)
        elif is_get_or_head and (path == "/ide" or path == "/ide.html"):
            let ide_html: string = file_read("web/ide.html")
            resp = make_http_response("200 OK", "text/html; charset=utf-8", ide_html)
        elif is_get_or_head and path == "/style.css":
            let css: string = file_read("web/style.css")
            resp = make_http_response("200 OK", "text/css; charset=utf-8", css)
        elif is_get_or_head and path == "/app.js":
            let js: string = file_read("web/app.js")
            resp = make_http_response("200 OK", "application/javascript; charset=utf-8", js)
        elif is_get_or_head and path == "/api/health":
            let h_json: string = "{\"status\": \"online\", \"server\": \"pure-cluster-http\", \"compiler\": \"cl v1.0.0\"}"
            resp = make_http_response("200 OK", "application/json", h_json)
        elif method == "POST" and path == "/api/run":
            let code_to_run: string = find_http_body(raw_req)
            let out_run: string = execute_cluster_run(code_to_run)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_run)
        elif method == "POST" and path == "/api/check":
            let code_to_check: string = find_http_body(raw_req)
            let out_check: string = execute_cluster_check(code_to_check)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_check)
        elif method == "POST" and path == "/api/llvm":
            let code_to_llvm: string = find_http_body(raw_req)
            let out_llvm: string = execute_cluster_llvm(code_to_llvm)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_llvm)
        elif method == "POST" and path == "/api/save":
            let save_payload: string = find_http_body(raw_req)
            let out_save: string = execute_file_save(save_payload)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_save)
        elif method == "POST" and path == "/api/format":
            let code_to_fmt: string = find_http_body(raw_req)
            let out_fmt: string = execute_cluster_format(code_to_fmt)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_fmt)
        elif method == "GET" and path == "/api/git-status":
            let out_git: string = execute_git_status()
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_git)
        else:
            let not_found: string = "404 Not Found"
            resp = make_http_response("404 Not Found", "text/plain", not_found)

        tcp_write(client_fd, resp)
        tcp_close(client_fd)

    tcp_close(server_fd)
    return 0
