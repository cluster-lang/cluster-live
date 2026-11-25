// ==============================================================================
// Cluster Live Studio — HTTP Server
// 100% Pure Cluster Language Web Server & Live Compiler Engine
// Multi-Backend Support: LLVM 24.0.0 (Primary) & CL-IL v1.0.0 (Secondary IL)
// Contributor: Mohammad Zaid <zkalamgir@proton.me>
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
    resp = resp + "Access-Control-Allow-Headers: Content-Type, X-Backend\r\n"
    resp = resp + "Connection: close\r\n\r\n"
    resp = resp + body
    return resp

fn has_substr(haystack: string, needle: string) -> bool:
    let hlen: int = len(haystack)
    let nlen: int = len(needle)
    if hlen < nlen:
        return false
    let mut i: int = 0
    while i <= hlen - nlen:
        if substring(haystack, i, nlen) == needle:
            return true
        i = i + 1
    return false

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

fn is_blank(s: string) -> bool:
    let slen: int = len(s)
    let mut i: int = 0
    while i < slen:
        let ch: string = char_at(s, i)
        if ch != " " and ch != "\t" and ch != "\r" and ch != "\n":
            return false
        i = i + 1
    return true

fn extract_code_part(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    if sep_idx >= 0:
        return substring(payload, 0, sep_idx)
    return payload

fn extract_stdin_part(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    if sep_idx >= 0:
        let raw_stdin: string = substring(payload, sep_idx + 21, len(payload) - (sep_idx + 21))
        return trim_leading_newline(raw_stdin)
    return ""

fn execute_cluster_with_flag(payload: string, backend_flag: string) -> string:
    let code: string = extract_code_part(payload)
    let stdin_data: string = extract_stdin_part(payload)

    if is_blank(code):
        return "Ready. (No code to execute)\n"

    file_write("/tmp/cluster_live_code.cl", code)
    file_write("/tmp/cluster_live_stdin.txt", stdin_data)
    let mut flag_arg: string = ""
    if len(backend_flag) > 0:
        flag_arg = backend_flag + " "
    let cmd: string = "timeout 15s /home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl run " + flag_arg + "/tmp/cluster_live_code.cl < /tmp/cluster_live_stdin.txt > /tmp/cluster_live_out.txt 2>&1"
    sys_run(cmd)
    if file_exists("/tmp/cluster_live_out.txt") == 1:
        let out_text: string = file_read("/tmp/cluster_live_out.txt")
        if len(out_text) > 0:
            return out_text
    return "Error: Execution did not produce output."

fn execute_cluster_run(payload: string) -> string:
    return execute_cluster_with_flag(payload, "--llvm")

fn execute_cluster_run_clil(payload: string) -> string:
    return execute_cluster_with_flag(payload, "--cl-il")

fn execute_cluster_run_native(payload: string) -> string:
    return execute_cluster_with_flag(payload, "")

fn execute_cluster_check(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
    if is_blank(code):
        return "Ready. (No code to check)\n"
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
    if is_blank(code):
        return "; Ready. (No code provided)\n"
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

fn execute_cluster_clil(payload: string) -> string:
    let sep_idx: int = find_stdin_separator(payload)
    let mut code: string = payload
    if sep_idx >= 0:
        code = substring(payload, 0, sep_idx)
    if is_blank(code):
        return "; Ready. (No code provided)\n"
    file_write("/tmp/cluster_live_code.cl", code)
    sys_run("rm -f /tmp/cluster_live.clil /tmp/cluster_live.opt.clil /tmp/cluster_live_clil_err.txt /tmp/cluster_live_clil_opt.txt")
    
    // Step 1: Emit intermediate representation
    let cmd1: string = "/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl emit-llvm /tmp/cluster_live_code.cl -o /tmp/cluster_live.clil > /tmp/cluster_live_clil_err.txt 2>&1"
    sys_run(cmd1)

    // Step 2: Run CL-IL parser and optimizer
    if file_exists("/tmp/cluster_live.clil") == 1:
        let cmd2: string = "/home/alamgir-zk/Cluster-Family/cluster-lang/bin/cl-il opt /tmp/cluster_live.clil -O3 -o /tmp/cluster_live.opt.clil > /tmp/cluster_live_clil_opt.txt 2>&1"
        sys_run(cmd2)
        if file_exists("/tmp/cluster_live.opt.clil") == 1:
            let opt_text: string = file_read("/tmp/cluster_live.opt.clil")
            let mut stats_text: string = ""
            if file_exists("/tmp/cluster_live_clil_opt.txt") == 1:
                stats_text = file_read("/tmp/cluster_live_clil_opt.txt")
            if len(opt_text) > 0:
                let mut header: string = "; ==========================================================================\n"
                header = header + "; Cluster Intermediate Language (CL-IL) v1.0.0 — SSA Optimized IR\n"
                if len(stats_text) > 0:
                    header = header + "; " + stats_text + "\n"
                header = header + "; ==========================================================================\n\n"
                return header + opt_text

    if file_exists("/tmp/cluster_live_clil_err.txt") == 1:
        return file_read("/tmp/cluster_live_clil_err.txt")
    return "Error: Could not emit CL-IL IR."

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
    print("  Compiler: cl v1.0.0 (LLVM 24.0 Backend)")
    print("  CL-IL:    CL-IL v1.0.0 (Cluster Intermediate Language)")
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
        elif is_get_or_head and path == "/ide_controller.js":
            let js_ide: string = file_read("web/ide_controller.js")
            resp = make_http_response("200 OK", "application/javascript; charset=utf-8", js_ide)
        elif is_get_or_head and path == "/examples_list.json":
            let ex_json: string = file_read("web/examples_list.json")
            resp = make_http_response("200 OK", "application/json; charset=utf-8", ex_json)
        elif is_get_or_head and has_substr(path, "/examples/"):
            let plen: int = len(path)
            let ex_sub: string = substring(path, 10, plen - 10)
            let full_p: string = "examples/" + ex_sub
            if file_exists(full_p) == 1:
                let content: string = file_read(full_p)
                resp = make_http_response("200 OK", "text/plain; charset=utf-8", content)
            else:
                resp = make_http_response("404 Not Found", "text/plain", "Example not found.")
        elif is_get_or_head and path == "/api/health":
            let h_json: string = "{\"status\": \"online\", \"server\": \"pure-cluster-http\", \"compiler\": \"cl v1.0.0\", \"backends\": [\"llvm\", \"cl-il\", \"native-zk\"], \"cl_il_version\": \"1.0.0\"}"
            resp = make_http_response("200 OK", "application/json", h_json)
        elif method == "POST" and (path == "/api/clil" or path == "/api/cl-il"):
            let code_to_clil: string = find_http_body(raw_req)
            let out_clil: string = execute_cluster_clil(code_to_clil)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_clil)
        elif method == "POST" and (path == "/api/clil-run" or path == "/api/cl-il-run"):
            let code_to_clil_run: string = find_http_body(raw_req)
            let out_clil_run: string = execute_cluster_run_clil(code_to_clil_run)
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_clil_run)
        elif method == "POST" and path == "/api/run":
            let code_to_run: string = find_http_body(raw_req)
            if has_substr(raw_req, "X-Backend: cl-il") or has_substr(raw_req, "backend=cl-il"):
                let out_clil_run: string = execute_cluster_run_clil(code_to_run)
                resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_clil_run)
            elif has_substr(raw_req, "X-Backend: native-zk") or has_substr(raw_req, "backend=native-zk"):
                let out_nat: string = execute_cluster_run_native(code_to_run)
                resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_nat)
            else:
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
        elif is_get_or_head and path == "/api/git-status":
            let out_git: string = execute_git_status()
            resp = make_http_response("200 OK", "text/plain; charset=utf-8", out_git)
        else:
            let not_found: string = "404 Not Found"
            resp = make_http_response("404 Not Found", "text/plain", not_found)

        tcp_write(client_fd, resp)
        tcp_close(client_fd)

    tcp_close(server_fd)
    return 0
