// ============================================================================
//  Cluster Standard Library: HTTP/2 (RFC 9113) & HPACK (RFC 7541) (std/http2.zk)
//  Pure Cluster binary frame codec, header compression & stream state table.
// ============================================================================

fn h2_preface() -> string:
    return "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

fn _h2_str_to_bytes(s: string) -> vector[int]:
    n := string_length(s)
    out := vector[int]()
    i := 0
    while i < n:
        out.push(byte_at(s, i) & 255)
        i = i + 1
    return out

fn _h2_bytes_to_str(b: vector[int], start: int, length: int) -> string:
    if length <= 0:
        return ""
    buf := mem_alloc(length + 1)
    i := 0
    while i < length:
        ptr_write_u8(ptr_add(buf, i), b[start + i] & 255)
        i = i + 1
    ptr_write_u8(ptr_add(buf, length), 0)
    return str_from_parts(buf, length)

fn _h2_push_u16(&out: vector[int], v: int):
    out.push((v >> 8) & 255)
    out.push(v & 255)

fn _h2_push_u24(&out: vector[int], v: int):
    out.push((v >> 16) & 255)
    out.push((v >> 8) & 255)
    out.push(v & 255)

fn _h2_push_u32(&out: vector[int], v: int):
    out.push((v >> 24) & 255)
    out.push((v >> 16) & 255)
    out.push((v >> 8) & 255)
    out.push(v & 255)

fn _h2_read_u32(b: vector[int], off: int) -> int:
    b0 := b[off] & 255
    b1 := b[off + 1] & 255
    b2 := b[off + 2] & 255
    b3 := b[off + 3] & 255
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3

// RFC 9113 HTTP/2 binary frame.
model H2Frame:
    ok: int
    ftype: int
    flags: int
    stream_id: int
    payload: vector[int]

// Encode an HTTP/2 frame with its 9-byte RFC 9113 header.
fn h2_encode_frame(ftype: int, flags: int, stream_id: int, payload: vector[int]) -> vector[int]:
    out := vector[int]()
    _h2_push_u24(out, payload.len())
    out.push(ftype & 255)
    out.push(flags & 255)
    _h2_push_u32(out, stream_id & 2147483647)
    i := 0
    while i < payload.len():
        out.push(payload[i] & 255)
        i = i + 1
    return out

// Decode a single HTTP/2 frame starting at offset, returning payload and updating next_off.
fn h2_decode_frame(buf: vector[int], offset: int, &next_off: int) -> H2Frame:
    if offset < 0 or (offset + 9) > buf.len():
        next_off = offset
        return H2Frame(0, 0, 0, 0, vector[int]())
    flen := ((buf[offset] & 255) << 16) | ((buf[offset + 1] & 255) << 8) | (buf[offset + 2] & 255)
    ftype := buf[offset + 3] & 255
    flags := buf[offset + 4] & 255
    sid := _h2_read_u32(buf, offset + 5) & 2147483647
    if (offset + 9 + flen) > buf.len():
        next_off = offset
        return H2Frame(0, ftype, flags, sid, vector[int]())
    payload := vector[int]()
    i := 0
    while i < flen:
        payload.push(buf[offset + 9 + i] & 255)
        i = i + 1
    next_off = offset + 9 + flen
    return H2Frame(1, ftype, flags, sid, payload)

// Build HTTP/2 SETTINGS frame (type 4).
fn h2_build_settings(max_concurrent: int, init_window: int, ack: int) -> vector[int]:
    payload := vector[int]()
    flags := 0
    if ack != 0:
        flags = 1
    else:
        if max_concurrent > 0:
            _h2_push_u16(payload, 3)
            _h2_push_u32(payload, max_concurrent)
        if init_window > 0:
            _h2_push_u16(payload, 4)
            _h2_push_u32(payload, init_window)
    return h2_encode_frame(4, flags, 0, payload)

// Build HTTP/2 PING frame (type 6, 8 opaque bytes).
fn h2_build_ping(opaque8: vector[int], ack: int) -> vector[int]:
    payload := vector[int]()
    i := 0
    while i < 8:
        if i < opaque8.len():
            payload.push(opaque8[i] & 255)
        else:
            payload.push(0)
        i = i + 1
    flags := 0
    if ack != 0:
        flags = 1
    return h2_encode_frame(6, flags, 0, payload)

// Build HTTP/2 GOAWAY frame (type 7).
fn h2_build_goaway(last_stream_id: int, error_code: int) -> vector[int]:
    payload := vector[int]()
    _h2_push_u32(payload, last_stream_id & 2147483647)
    _h2_push_u32(payload, error_code)
    return h2_encode_frame(7, 0, 0, payload)

// Build HTTP/2 WINDOW_UPDATE frame (type 8).
fn h2_build_window_update(stream_id: int, increment: int) -> vector[int]:
    payload := vector[int]()
    _h2_push_u32(payload, increment & 2147483647)
    return h2_encode_frame(8, 0, stream_id, payload)

// Build HTTP/2 RST_STREAM frame (type 3).
fn h2_build_rst_stream(stream_id: int, error_code: int) -> vector[int]:
    payload := vector[int]()
    _h2_push_u32(payload, error_code)
    return h2_encode_frame(3, 0, stream_id, payload)

// Build HTTP/2 DATA frame (type 0).
fn h2_build_data(stream_id: int, data_s: string, end_stream: int) -> vector[int]:
    flags := 0
    if end_stream != 0:
        flags = 1
    return h2_encode_frame(0, flags, stream_id, _h2_str_to_bytes(data_s))

// --- HPACK (RFC 7541) integer & header codec ---

fn hpack_encode_int(&out: vector[int], value: int, prefix_bits: int, prefix_flags: int):
    max_p := (1 << prefix_bits) - 1
    if value < max_p:
        out.push((prefix_flags | value) & 255)
        return
    out.push((prefix_flags | max_p) & 255)
    rem := value - max_p
    while rem >= 128:
        out.push(((rem & 127) | 128) & 255)
        rem = rem >> 7
    out.push(rem & 127)

fn hpack_decode_int(buf: vector[int], &pos: int, prefix_bits: int) -> int:
    if pos >= buf.len():
        return -1
    max_p := (1 << prefix_bits) - 1
    val := buf[pos] & max_p
    pos = pos + 1
    if val < max_p:
        return val
    m := 0
    while pos < buf.len():
        b := buf[pos] & 255
        pos = pos + 1
        val = val + ((b & 127) << m)
        m = m + 7
        if (b & 128) == 0:
            return val
    return val

fn _hpack_push_str(&out: vector[int], s: string):
    bs := _h2_str_to_bytes(s)
    hpack_encode_int(out, bs.len(), 7, 0)
    i := 0
    while i < bs.len():
        out.push(bs[i])
        i = i + 1

fn _hpack_read_str(buf: vector[int], &pos: int) -> string:
    if pos >= buf.len():
        return ""
    slen := hpack_decode_int(buf, pos, 7)
    if slen <= 0 or (pos + slen) > buf.len():
        return ""
    s := _h2_bytes_to_str(buf, pos, slen)
    pos = pos + slen
    return s

fn _hpack_static_lookup(idx: int, &name_out: string, &val_out: string) -> int:
    name_out = ""
    val_out = ""
    s_idx := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 24, 28, 31, 38, 54, 58]
    s_nm := [":authority", ":method", ":method", ":path", ":path", ":scheme", ":scheme", ":status", ":status", ":status", ":status", ":status", ":status", ":status", "accept-encoding", "cache-control", "content-length", "content-type", "host", "server", "user-agent"]
    s_vl := ["", "GET", "POST", "/", "/index.html", "http", "https", "200", "204", "206", "304", "400", "404", "500", "gzip, deflate", "", "", "", "", "", ""]
    i := 0
    while i < s_idx.len():
        if s_idx[i] == idx:
            name_out = s_nm[i]
            val_out = s_vl[i]
            return 1
        i = i + 1
    return 0

fn _hpack_find_static_pair(k: string, v: string) -> int:
    if k == ":method" and v == "GET": return 2
    if k == ":method" and v == "POST": return 3
    if k == ":path" and v == "/": return 4
    if k == ":path" and v == "/index.html": return 5
    if k == ":scheme" and v == "http": return 6
    if k == ":scheme" and v == "https": return 7
    if k == ":status" and v == "200": return 8
    if k == ":status" and v == "204": return 9
    if k == ":status" and v == "400": return 12
    if k == ":status" and v == "404": return 13
    if k == ":status" and v == "500": return 14
    return 0

fn _hpack_find_static_name(k: string) -> int:
    if k == ":authority": return 1
    if k == ":method": return 2
    if k == ":path": return 4
    if k == ":scheme": return 6
    if k == ":status": return 8
    if k == "cache-control": return 24
    if k == "content-length": return 28
    if k == "content-type": return 31
    if k == "host": return 38
    if k == "server": return 54
    if k == "user-agent": return 58
    return 0

// Encode name/value header lists using RFC 7541 HPACK indexed + literal representations.
fn hpack_encode_headers(names: vector[string], values: vector[string]) -> vector[int]:
    out := vector[int]()
    n := names.len()
    if values.len() < n:
        n = values.len()
    i := 0
    while i < n:
        k := names[i]
        v := values[i]
        pidx := _hpack_find_static_pair(k, v)
        if pidx > 0:
            hpack_encode_int(out, pidx, 7, 128)
        else:
            nidx := _hpack_find_static_name(k)
            if nidx > 0:
                hpack_encode_int(out, nidx, 4, 0)
                _hpack_push_str(out, v)
            else:
                out.push(0)
                _hpack_push_str(out, k)
                _hpack_push_str(out, v)
        i = i + 1
    return out

// Decode an HPACK header block into parallel name/value string vectors.
fn hpack_decode_headers(buf: vector[int], &out_names: vector[string], &out_values: vector[string]) -> int:
    while out_names.len() > 0:
        out_names.pop()
    while out_values.len() > 0:
        out_values.pop()
    pos := 0
    count := 0
    while pos < buf.len():
        first := buf[pos] & 255
        if (first & 128) != 0:
            idx := hpack_decode_int(buf, pos, 7)
            nm := ""
            vl := ""
            if _hpack_static_lookup(idx, nm, vl) == 1:
                out_names.push(nm)
                out_values.push(vl)
                count = count + 1
        elif (first & 64) != 0:
            idx := hpack_decode_int(buf, pos, 6)
            nm := ""
            vl_dummy := ""
            if idx > 0:
                _hpack_static_lookup(idx, nm, vl_dummy)
            else:
                nm = _hpack_read_str(buf, pos)
            vl := _hpack_read_str(buf, pos)
            out_names.push(nm)
            out_values.push(vl)
            count = count + 1
        elif (first & 224) == 32:
            hpack_decode_int(buf, pos, 5)
        else:
            idx := hpack_decode_int(buf, pos, 4)
            nm := ""
            vl_dummy := ""
            if idx > 0:
                _hpack_static_lookup(idx, nm, vl_dummy)
            else:
                nm = _hpack_read_str(buf, pos)
            vl := _hpack_read_str(buf, pos)
            out_names.push(nm)
            out_values.push(vl)
            count = count + 1
    return count

// Build an HTTP/2 HEADERS frame (type 1) from header name/value vectors.
fn h2_build_headers_frame(stream_id: int, names: vector[string], values: vector[string], end_stream: int, end_headers: int) -> vector[int]:
    hpack := hpack_encode_headers(names, values)
    flags := 0
    if end_stream != 0:
        flags = flags | 1
    if end_headers != 0:
        flags = flags | 4
    return h2_encode_frame(1, flags, stream_id, hpack)

// HTTP/2 multiplexed stream state tracker (0=idle, 1=open, 2=half-closed, 3=closed).
model H2Conn:
    next_stream_id: int
    stream_ids: vector[int]
    stream_states: vector[int]

    fn h2_open_stream(& self) -> int:
        sid := self.next_stream_id
        self.next_stream_id = sid + 2
        self.stream_ids.push(sid)
        self.stream_states.push(1)
        return sid

    fn h2_set_state(& self, sid: int, st: int):
        i := 0
        while i < self.stream_ids.len():
            if self.stream_ids[i] == sid:
                self.stream_states[(i)] = st
                return
            i = i + 1
        self.stream_ids.push(sid)
        self.stream_states.push(st)

    fn h2_get_state(& self, sid: int) -> int:
        i := 0
        while i < self.stream_ids.len():
            if self.stream_ids[i] == sid:
                return self.stream_states[i]
            i = i + 1
        return 0

fn h2_conn_client() -> H2Conn:
    return H2Conn(1, vector[int](), vector[int]())
