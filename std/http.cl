// Cluster Standard Library: HTTP (std::http)
// HTTP request representation, status codes, and response builder

fn http_status_text(code: int) -> string:
    if code == 200: return "OK"
    elif code == 201: return "Created"
    elif code == 204: return "No Content"
    elif code == 400: return "Bad Request"
    elif code == 401: return "Unauthorized"
    elif code == 403: return "Forbidden"
    elif code == 404: return "Not Found"
    elif code == 405: return "Method Not Allowed"
    elif code == 500: return "Internal Server Error"
    elif code == 502: return "Bad Gateway"
    elif code == 503: return "Service Unavailable"
    return "Unknown"

model HttpRequest:
    method: string
    path: string
    body: string

    fn is_get(& self) -> int:
        if self.method == "GET":
            return 1
        return 0

    fn is_post(& self) -> int:
        if self.method == "POST":
            return 1
        return 0

model HttpResponse:
    status_code: int := 200
    content_type: string := "application/json"
    body: string := ""

    fn set_status(& self, code: int):
        self.status_code = code

    fn set_content_type(& self, ctype: string):
        self.content_type = ctype

    fn set_body(& self, b: string):
        self.body = b

    fn format_http(& self) -> string:
        stext := http_status_text(self.status_code)
        resp := "HTTP/1.1 " + to_text(self.status_code) + " " + stext + "\r\n"
        resp = resp + "Content-Type: " + self.content_type + "\r\n"
        resp = resp + "Content-Length: " + to_text(string_length(self.body)) + "\r\n"
        resp = resp + "Connection: close\r\n\r\n"
        resp = resp + self.body
        return resp

// ============================================================================
//  Pure Cluster HTTP/1.1 Parser, Router, Client & Multi-Worker Reactor
// ============================================================================

fn _http_ascii_lower(s: string) -> string:
    n := string_length(s)
    if n == 0:
        return ""
    buf := mem_alloc(n + 1)
    i := 0
    while i < n:
        c := byte_at(s, i)
        if c >= 65 and c <= 90:
            c = c + 32
        ptr_write_u8(ptr_add(buf, i), c & 255)
        i = i + 1
    ptr_write_u8(ptr_add(buf, n), 0)
    return str_from_parts(buf, n)

fn _http_trim(s: string) -> string:
    n := string_length(s)
    lo := 0
    while lo < n:
        c := byte_at(s, lo)
        if c == 32 or c == 9 or c == 13 or c == 10:
            lo = lo + 1
        else:
            break
    hi := n
    while hi > lo:
        c2 := byte_at(s, hi - 1)
        if c2 == 32 or c2 == 9 or c2 == 13 or c2 == 10:
            hi = hi - 1
        else:
            break
    if hi <= lo:
        return ""
    return substring(s, lo, hi - lo)

fn _http_find_sub_from(hay: string, pat: string, start: int) -> int:
    hn := string_length(hay)
    pn := string_length(pat)
    if pn == 0:
        return start
    if start < 0 or hn < pn:
        return -1
    i := start
    limit := hn - pn
    while i <= limit:
        j := 0
        ok := 1
        while j < pn:
            if byte_at(hay, i + j) != byte_at(pat, j):
                ok = 0
                j = pn
            else:
                j = j + 1
        if ok == 1:
            return i
        i = i + 1
    return -1

fn _http_parse_int(s: string, dflt: int) -> int:
    ts := _http_trim(s)
    n := string_length(ts)
    if n == 0:
        return dflt
    val := 0
    i := 0
    seen := 0
    while i < n:
        c := byte_at(ts, i)
        if c >= 48 and c <= 57:
            val = (val * 10) + (c - 48)
            seen = 1
        else:
            break
        i = i + 1
    if seen == 0:
        return dflt
    return val

// Parsed HTTP/1.1 request with header and query-string helpers.
model HttpParsedRequest:
    method: string
    path: string
    query: string
    version: string
    headers_raw: string
    body: string

    fn hdr_get(& self, name: string) -> string:
        target := _http_ascii_lower(_http_trim(name))
        if string_length(target) == 0:
            return ""
        raw := self.headers_raw
        n := string_length(raw)
        pos := 0
        while pos < n:
            eol := _http_find_sub_from(raw, "\n", pos)
            line := ""
            if eol < 0:
                line = substring(raw, pos, n - pos)
                pos = n
            else:
                line = substring(raw, pos, eol - pos)
                pos = eol + 1
            col := _http_find_sub_from(line, ":", 0)
            if col > 0:
                k := _http_ascii_lower(_http_trim(substring(line, 0, col)))
                if k == target:
                    return _http_trim(substring(line, col + 1, string_length(line) - col - 1))
        return ""

    fn query_get(& self, key: string) -> string:
        q := self.query
        qn := string_length(q)
        pos := 0
        while pos < qn:
            amp := _http_find_sub_from(q, "&", pos)
            part := ""
            if amp < 0:
                part = substring(q, pos, qn - pos)
                pos = qn
            else:
                part = substring(q, pos, amp - pos)
                pos = amp + 1
            eq := _http_find_sub_from(part, "=", 0)
            if eq >= 0:
                k := substring(part, 0, eq)
                if k == key:
                    return substring(part, eq + 1, string_length(part) - eq - 1)
            elif part == key:
                return ""
        return ""

// Parse a raw HTTP/1.1 wire request into HttpParsedRequest.
fn http_parse_request(raw: string) -> HttpParsedRequest:
    hdr_end := _http_find_sub_from(raw, "\r\n\r\n", 0)
    sep_len := 4
    if hdr_end < 0:
        hdr_end = _http_find_sub_from(raw, "\n\n", 0)
        sep_len = 2
    head := raw
    body := ""
    if hdr_end >= 0:
        head = substring(raw, 0, hdr_end)
        body_start := hdr_end + sep_len
        if body_start < string_length(raw):
            body = substring(raw, body_start, string_length(raw) - body_start)
    eol := _http_find_sub_from(head, "\n", 0)
    req_line := head
    headers := ""
    if eol >= 0:
        req_line = _http_trim(substring(head, 0, eol))
        if eol + 1 < string_length(head):
            headers = substring(head, eol + 1, string_length(head) - eol - 1)
    else:
        req_line = _http_trim(head)
    sp1 := _http_find_sub_from(req_line, " ", 0)
    method := "GET"
    target := "/"
    version := "HTTP/1.1"
    if sp1 > 0:
        method = substring(req_line, 0, sp1)
        rest := _http_trim(substring(req_line, sp1 + 1, string_length(req_line) - sp1 - 1))
        sp2 := _http_find_sub_from(rest, " ", 0)
        if sp2 >= 0:
            target = substring(rest, 0, sp2)
            version = _http_trim(substring(rest, sp2 + 1, string_length(rest) - sp2 - 1))
        elif string_length(rest) > 0:
            target = rest
    path := target
    query := ""
    qidx := _http_find_sub_from(target, "?", 0)
    if qidx >= 0:
        path = substring(target, 0, qidx)
        if qidx + 1 < string_length(target):
            query = substring(target, qidx + 1, string_length(target) - qidx - 1)
    return HttpParsedRequest(method, path, query, version, headers, body)

// Parse a raw HTTP/1.x response into HttpResponse.
fn http_parse_response(raw: string) -> HttpResponse:
    hdr_end := _http_find_sub_from(raw, "\r\n\r\n", 0)
    sep_len := 4
    if hdr_end < 0:
        hdr_end = _http_find_sub_from(raw, "\n\n", 0)
        sep_len = 2
    head := raw
    body := ""
    if hdr_end >= 0:
        head = substring(raw, 0, hdr_end)
        bstart := hdr_end + sep_len
        if bstart < string_length(raw):
            body = substring(raw, bstart, string_length(raw) - bstart)
    eol := _http_find_sub_from(head, "\n", 0)
    status_line := head
    headers := ""
    if eol >= 0:
        status_line = _http_trim(substring(head, 0, eol))
        if eol + 1 < string_length(head):
            headers = substring(head, eol + 1, string_length(head) - eol - 1)
    sp1 := _http_find_sub_from(status_line, " ", 0)
    code := 0
    if sp1 >= 0:
        code = _http_parse_int(substring(status_line, sp1 + 1, string_length(status_line) - sp1 - 1), 0)
    parsed := HttpParsedRequest("", "", "", "", headers, body)
    ct := parsed.hdr_get("content-type")
    if string_length(ct) == 0:
        ct = "text/plain"
    return HttpResponse(code, ct, body)

// Build a serialized HTTP/1.1 request wire payload.
fn http_build_request(method: string, host: string, path: string, extra_hdrs: string, body: string) -> string:
    p := path
    if string_length(p) == 0:
        p = "/"
    req := method + " " + p + " HTTP/1.1\r\n"
    req = req + "Host: " + host + "\r\n"
    if string_length(extra_hdrs) > 0:
        req = req + extra_hdrs
        if _http_find_sub_from(extra_hdrs, "\n", string_length(extra_hdrs) - 1) < 0:
            req = req + "\r\n"
    blen := string_length(body)
    if blen > 0:
        req = req + "Content-Length: " + to_text(blen) + "\r\n"
    req = req + "Connection: close\r\n\r\n"
    if blen > 0:
        req = req + body
    return req

// Format an HTTP/1.1 response with optional keep-alive framing.
fn http_build_response(status_code: int, ctype: string, body: string, keep_alive: int) -> string:
    stext := http_status_text(status_code)
    conn := "close"
    if keep_alive != 0:
        conn = "keep-alive"
    resp := "HTTP/1.1 " + to_text(status_code) + " " + stext + "\r\n"
    resp = resp + "Content-Type: " + ctype + "\r\n"
    resp = resp + "Content-Length: " + to_text(string_length(body)) + "\r\n"
    resp = resp + "Connection: " + conn + "\r\n\r\n"
    resp = resp + body
    return resp

fn _http_split_path(p: string) -> vector[string]:
    segs := vector[string]()
    n := string_length(p)
    i := 0
    while i < n:
        if byte_at(p, i) == 47:
            i = i + 1
        else:
            j := i
            while j < n:
                if byte_at(p, j) == 47:
                    break
                j = j + 1
            segs.push(substring(p, i, j - i))
            i = j + 1
    return segs

// Lightweight URL router supporting exact routes and :param segments.
model HttpRouter:
    methods: vector[string]
    patterns: vector[string]
    handler_ids: vector[int]

    fn route_add(& self, method: string, pattern: string, handler_id: int):
        self.methods.push(method)
        self.patterns.push(pattern)
        self.handler_ids.push(handler_id)

    fn route_match(& self, method: string, path: string, &param_names: vector[string], &param_vals: vector[string]) -> int:
        while param_names.len() > 0:
            param_names.pop()
        while param_vals.len() > 0:
            param_vals.pop()
        p_segs := _http_split_path(path)
        i := 0
        while i < self.methods.len():
            if self.methods[i] == method or self.methods[i] == "*":
                r_segs := _http_split_path(self.patterns[i])
                if r_segs.len() == p_segs.len():
                    matched := 1
                    tmp_n := vector[string]()
                    tmp_v := vector[string]()
                    k := 0
                    while k < r_segs.len():
                        rs := r_segs[k]
                        ps := p_segs[k]
                        if string_length(rs) > 0 and byte_at(rs, 0) == 58:
                            tmp_n.push(substring(rs, 1, string_length(rs) - 1))
                            tmp_v.push(ps)
                        elif rs != ps:
                            matched = 0
                            break
                        k = k + 1
                    if matched == 1:
                        ti := 0
                        while ti < tmp_n.len():
                            param_names.push(tmp_n[ti])
                            param_vals.push(tmp_v[ti])
                            ti = ti + 1
                        return self.handler_ids[i]
            i = i + 1
        return -1

fn http_router_new() -> HttpRouter:
    return HttpRouter(vector[string](), vector[string](), vector[int]())

// Execute an HTTP/1.1 request over a fresh TCP connection and parse the response.
fn http_request_raw(host: string, port: int, wire_req: string) -> HttpResponse:
    fd := net_connect(host, port)
    if fd < 0:
        return HttpResponse(0, "text/plain", "")
    net_write(fd, wire_req)
    full := ""
    rounds := 0
    while rounds < 256:
        chunk := net_read(fd, 65536)
        if string_length(chunk) == 0:
            break
        full = full + chunk
        rounds = rounds + 1
    net_close(fd)
    return http_parse_response(full)

// Send an HTTP/1.1 GET request to host:port/path.
fn http_client_get(host: string, port: int, path: string) -> HttpResponse:
    req := http_build_request("GET", host, path, "", "")
    return http_request_raw(host, port, req)

// Send an HTTP/1.1 POST request to host:port/path.
fn http_client_post(host: string, port: int, path: string, ctype: string, body: string) -> HttpResponse:
    hdr := "Content-Type: " + ctype + "\r\n"
    req := http_build_request("POST", host, path, hdr, body)
    return http_request_raw(host, port, req)

// Start the multi-worker io_uring/epoll HTTP reactor on port serving static body.
fn http_serve_fast(port: int, body: string):
    server_start(port, body)

// Build HTTP/1.1 Keep-Alive response payload with persistent Connection header.
fn http_format_keepalive(status_code: int, ctype: string, body: string) -> string:
    stext := http_status_text(status_code)
    resp := "HTTP/1.1 " + to_text(status_code) + " " + stext + "\r\n"
    resp = resp + "Content-Type: " + ctype + "\r\n"
    resp = resp + "Content-Length: " + to_text(string_length(body)) + "\r\n"
    resp = resp + "Connection: keep-alive\r\n\r\n"
    return resp + body

fn _http_hex_val(b: int) -> int:
    if b >= 48 and b <= 57:
        return b - 48
    if b >= 97 and b <= 102:
        return b - 87
    if b >= 65 and b <= 70:
        return b - 55
    return -1

// Decode an HTTP/1.1 Transfer-Encoding: chunked body payload cleanly.
fn http_decode_chunked(raw_body: string) -> string:
    n := string_length(raw_body)
    pos := 0
    out := ""
    while pos < n:
        line_end := pos
        while line_end < n and byte_at(raw_body, line_end) != 10:
            line_end = line_end + 1
        sz := 0
        i := pos
        while i < line_end:
            c := byte_at(raw_body, i)
            if c == 13 or c == 59:
                break
            d := _http_hex_val(c)
            if d >= 0:
                sz = (sz * 16) + d
            i = i + 1
        pos = line_end + 1
        if sz == 0:
            break
        if pos + sz > n:
            sz = n - pos
        out = out + substring(raw_body, pos, sz)
        pos = pos + sz
        if pos < n and byte_at(raw_body, pos) == 13:
            pos = pos + 1
        if pos < n and byte_at(raw_body, pos) == 10:
            pos = pos + 1
    return out

