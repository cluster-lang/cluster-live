// Cluster Standard Library: JSON (std::json)
// Pure Cluster JSON streaming parser, AST accessor, and serializer

JSON_NULL: int := 0
JSON_BOOL: int := 1
JSON_INT: int := 2
JSON_FLOAT: int := 3
JSON_STRING: int := 4
JSON_ARRAY: int := 5
JSON_OBJECT: int := 6

fn _json_hex_byte(n: int) -> string:
    v := n & 15
    if v < 10:
        return chr(48 + v)
    return chr(87 + v)

fn json_quote(s: string) -> string:
    out := vector[int]()
    list_push(out, 34)
    i := 0
    slen := string_length(s)
    while i < slen:
        b := byte_at(s, i)
        if b == 34:
            list_push(out, 92); list_push(out, 34)
        elif b == 92:
            list_push(out, 92); list_push(out, 92)
        elif b == 10:
            list_push(out, 92); list_push(out, 110)
        elif b == 13:
            list_push(out, 92); list_push(out, 114)
        elif b == 9:
            list_push(out, 92); list_push(out, 116)
        elif b < 32:
            list_push(out, 92); list_push(out, 117); list_push(out, 48); list_push(out, 48)
            h1 := (b >> 4) & 15
            h2 := b & 15
            if h1 < 10: list_push(out, 48 + h1)
            else: list_push(out, 87 + h1)
            if h2 < 10: list_push(out, 48 + h2)
            else: list_push(out, 87 + h2)
        else:
            list_push(out, b)
        i = i + 1
    list_push(out, 34)
    sz := list_size(out)
    buf: ptr := mem_alloc(sz + 1)
    k := 0
    while k < sz:
        ptr_write_u8(ptr_add(buf, k), out[(k)])
        k = k + 1
    ptr_write_u8(ptr_add(buf, sz), 0)
    return str_from_parts(buf, sz)

fn json_encode_int(val: int) -> string:
    return to_text(val)

fn json_encode_bool(val: int) -> string:
    if val != 0:
        return "true"
    return "false"

model JsonObject:
    keys: vector[string]
    vals: vector[string]

    fn put_str(& self, k: string, v: string):
        list_push(self.keys, k)
        list_push(self.vals, json_quote(v))

    fn put_int(& self, k: string, v: int):
        list_push(self.keys, k)
        list_push(self.vals, to_text(v))

    fn put_bool(& self, k: string, v: int):
        list_push(self.keys, k)
        if v != 0:
            list_push(self.vals, "true")
        else:
            list_push(self.vals, "false")

    fn put_raw(& self, k: string, raw_json: string):
        list_push(self.keys, k)
        list_push(self.vals, raw_json)

    fn get(& self, k: string) -> string:
        i := 0
        sz := list_size(self.keys)
        while i < sz:
            if self.keys[(i)] == k:
                return self.vals[(i)]
            i = i + 1
        return ""

    fn stringify(& self) -> string:
        sz := list_size(self.keys)
        if sz == 0:
            return "{}"
        out := "{"
        i := 0
        while i < sz:
            if i > 0:
                out = out + ", "
            out = out + json_quote(self.keys[(i)]) + ": " + self.vals[(i)]
            i = i + 1
        out = out + "}"
        return out

model JsonDoc:
    ok: int := 0
    root: int := -1
    err: string := ""
    kinds: vector[int]
    str_vals: vector[string]
    int_vals: vector[int]
    edge_parent: vector[int]
    edge_key: vector[string]
    edge_child: vector[int]

    fn new_node(& self, k: int, sv: string, iv: int) -> int:
        id := list_size(self.kinds)
        list_push(self.kinds, k)
        list_push(self.str_vals, sv)
        list_push(self.int_vals, iv)
        return id

    fn add_edge(& self, p: int, k: string, ch: int):
        list_push(self.edge_parent, p)
        list_push(self.edge_key, k)
        list_push(self.edge_child, ch)

    fn kind(& self, node: int) -> int:
        if node < 0 or node >= list_size(self.kinds):
            return -1
        return self.kinds[(node)]

    fn as_str(& self, node: int) -> string:
        if node < 0 or node >= list_size(self.str_vals):
            return ""
        return self.str_vals[(node)]

    fn as_int(& self, node: int) -> int:
        if node < 0 or node >= list_size(self.int_vals):
            return 0
        return self.int_vals[(node)]

    fn jget(& self, obj_node: int, key: string) -> int:
        if obj_node < 0:
            return -1
        i := 0
        n := list_size(self.edge_parent)
        while i < n:
            if self.edge_parent[(i)] == obj_node:
                if self.edge_key[(i)] == key:
                    return self.edge_child[(i)]
            i = i + 1
        return -1

    fn get_str(& self, obj_node: int, key: string, dflt: string) -> string:
        cid := self.jget(obj_node, key)
        if cid < 0:
            return dflt
        return self.as_str(cid)

    fn get_int(& self, obj_node: int, key: string, dflt: int) -> int:
        cid := self.jget(obj_node, key)
        if cid < 0:
            return dflt
        return self.as_int(cid)

    fn get_bool(& self, obj_node: int, key: string, dflt: int) -> int:
        cid := self.jget(obj_node, key)
        if cid < 0:
            return dflt
        if self.kinds[(cid)] == JSON_BOOL:
            return self.int_vals[(cid)]
        return dflt

    fn arr_len(& self, arr_node: int) -> int:
        if arr_node < 0:
            return 0
        cnt := 0
        i := 0
        n := list_size(self.edge_parent)
        while i < n:
            if self.edge_parent[(i)] == arr_node:
                cnt = cnt + 1
            i = i + 1
        return cnt

    fn at(& self, arr_node: int, idx: int) -> int:
        if arr_node < 0 or idx < 0:
            return -1
        cnt := 0
        i := 0
        n := list_size(self.edge_parent)
        while i < n:
            if self.edge_parent[(i)] == arr_node:
                if cnt == idx:
                    return self.edge_child[(i)]
                cnt = cnt + 1
            i = i + 1
        return -1

    fn to_json(& self, node: int) -> string:
        if node < 0 or node >= list_size(self.kinds):
            return "null"
        k := self.kinds[(node)]
        if k == JSON_NULL: return "null"
        if k == JSON_BOOL:
            if self.int_vals[(node)] != 0: return "true"
            return "false"
        if k == JSON_INT: return to_text(self.int_vals[(node)])
        if k == JSON_FLOAT: return self.str_vals[(node)]
        if k == JSON_STRING: return json_quote(self.str_vals[(node)])
        if k == JSON_ARRAY:
            out := "["
            first := 1
            i := 0
            n := list_size(self.edge_parent)
            while i < n:
                if self.edge_parent[(i)] == node:
                    if first == 0: out = out + ", "
                    first = 0
                    out = out + self.to_json(self.edge_child[(i)])
                i = i + 1
            return out + "]"
        if k == JSON_OBJECT:
            out := "{"
            first := 1
            i := 0
            n := list_size(self.edge_parent)
            while i < n:
                if self.edge_parent[(i)] == node:
                    if first == 0: out = out + ", "
                    first = 0
                    out = out + json_quote(self.edge_key[(i)]) + ": " + self.to_json(self.edge_child[(i)])
                i = i + 1
            return out + "}"
        return "null"

fn _jp_skip_ws(src: string, n: int, pos: int) -> int:
    p := pos
    while p < n:
        c := byte_at(src, p)
        if c == 32 or c == 10 or c == 13 or c == 9:
            p = p + 1
        else:
            break
    return p

fn _jp_parse_str(src: string, n: int, &pos_vec: vector[int]) -> string:
    p := pos_vec[(0)]
    if p >= n:
        return ""
    if byte_at(src, p) != 34:
        return ""
    p = p + 1
    bytes := vector[int]()
    while p < n:
        c := byte_at(src, p)
        if c == 34:
            p = p + 1
            break
        if c == 92 and p + 1 < n:
            nx := byte_at(src, p + 1)
            if nx == 34: list_push(bytes, 34)
            elif nx == 92: list_push(bytes, 92)
            elif nx == 47: list_push(bytes, 47)
            elif nx == 110: list_push(bytes, 10)
            elif nx == 114: list_push(bytes, 13)
            elif nx == 116: list_push(bytes, 9)
            elif nx == 98: list_push(bytes, 8)
            elif nx == 102: list_push(bytes, 12)
            else: list_push(bytes, nx)
            p = p + 2
        else:
            list_push(bytes, c)
            p = p + 1
    pos_vec[(0)] = p
    sz := list_size(bytes)
    buf: ptr := mem_alloc(sz + 1)
    k := 0
    while k < sz:
        ptr_write_u8(ptr_add(buf, k), bytes[(k)])
        k = k + 1
    ptr_write_u8(ptr_add(buf, sz), 0)
    return str_from_parts(buf, sz)

fn _jp_parse_value(src: string, n: int, &pos_vec: vector[int], &doc: JsonDoc) -> int:
    p := _jp_skip_ws(src, n, pos_vec[(0)])
    pos_vec[(0)] = p
    if p >= n:
        doc.err = "unexpected EOF"
        return -1
    c := byte_at(src, p)
    if c == 34:
        sv := _jp_parse_str(src, n, pos_vec)
        return doc.new_node(JSON_STRING, sv, 0)
    if c == 123: // '{'
        obj_id := doc.new_node(JSON_OBJECT, "", 0)
        p = _jp_skip_ws(src, n, p + 1)
        pos_vec[(0)] = p
        if p < n:
            if byte_at(src, p) == 125:
                pos_vec[(0)] = p + 1
                return obj_id
        while pos_vec[(0)] < n:
            kp := _jp_skip_ws(src, n, pos_vec[(0)])
            pos_vec[(0)] = kp
            if kp >= n:
                doc.err = "expected object key"
                return -1
            if byte_at(src, kp) != 34:
                doc.err = "expected object key"
                return -1
            key := _jp_parse_str(src, n, pos_vec)
            cp := _jp_skip_ws(src, n, pos_vec[(0)])
            if cp >= n:
                doc.err = "expected ':'"
                return -1
            if byte_at(src, cp) != 58:
                doc.err = "expected ':'"
                return -1
            pos_vec[(0)] = cp + 1
            vid := _jp_parse_value(src, n, pos_vec, doc)
            if vid < 0:
                return -1
            doc.add_edge(obj_id, key, vid)
            np := _jp_skip_ws(src, n, pos_vec[(0)])
            pos_vec[(0)] = np
            if np < n:
                ch2 := byte_at(src, np)
                if ch2 == 44:
                    pos_vec[(0)] = np + 1
                elif ch2 == 125:
                    pos_vec[(0)] = np + 1
                    return obj_id
                else:
                    doc.err = "expected ',' or '}'"
                    return -1
        return obj_id
    if c == 91: // '['
        arr_id := doc.new_node(JSON_ARRAY, "", 0)
        p = _jp_skip_ws(src, n, p + 1)
        pos_vec[(0)] = p
        if p < n:
            if byte_at(src, p) == 93:
                pos_vec[(0)] = p + 1
                return arr_id
        idx := 0
        while pos_vec[(0)] < n:
            vid := _jp_parse_value(src, n, pos_vec, doc)
            if vid < 0:
                return -1
            doc.add_edge(arr_id, to_text(idx), vid)
            idx = idx + 1
            np := _jp_skip_ws(src, n, pos_vec[(0)])
            pos_vec[(0)] = np
            if np < n:
                ch2 := byte_at(src, np)
                if ch2 == 44:
                    pos_vec[(0)] = np + 1
                elif ch2 == 93:
                    pos_vec[(0)] = np + 1
                    return arr_id
                else:
                    doc.err = "expected ',' or ']'"
                    return -1
        return arr_id
    if c == 116: // true
        pos_vec[(0)] = p + 4
        return doc.new_node(JSON_BOOL, "true", 1)
    if c == 102: // false
        pos_vec[(0)] = p + 5
        return doc.new_node(JSON_BOOL, "false", 0)
    if c == 110: // null
        pos_vec[(0)] = p + 4
        return doc.new_node(JSON_NULL, "null", 0)
    if c == 45 or (c >= 48 and c <= 57):
        start := p
        is_flt := 0
        if c == 45:
            p = p + 1
        while p < n:
            d := byte_at(src, p)
            if (d >= 48 and d <= 57):
                p = p + 1
            elif d == 46 or d == 101 or d == 69 or d == 43 or d == 45:
                is_flt = 1
                p = p + 1
            else:
                break
        pos_vec[(0)] = p
        num_s := substring(src, start, p - start)
        if is_flt != 0:
            return doc.new_node(JSON_FLOAT, num_s, to_int(num_s))
        return doc.new_node(JSON_INT, num_s, to_int(num_s))
    doc.err = "unexpected token at " + to_text(p)
    return -1

fn json_parse(src: string) -> JsonDoc:
    doc := JsonDoc(0, -1, "", vector[int](), vector[string](), vector[int](), vector[int](), vector[string](), vector[int]())
    pv := vector[int]()
    list_push(pv, 0)
    rid := _jp_parse_value(src, string_length(src), pv, doc)
    if rid >= 0:
        doc.ok = 1
        doc.root = rid
    return doc

fn _json_find_sub(hay: string, pat: string) -> int:
    hn := string_length(hay)
    pn := string_length(pat)
    if pn == 0:
        return 0
    if pn > hn:
        return -1
    p0 := byte_at(pat, 0)
    i := 0
    lim := hn - pn + 1
    while i < lim:
        if byte_at(hay, i) == p0:
            j := 1
            ok := 1
            while j < pn:
                if byte_at(hay, i + j) != byte_at(pat, j):
                    ok = 0
                    break
                j = j + 1
            if ok == 1:
                return i
        i = i + 1
    return -1

fn json_find_str(raw: string, key: string) -> string:
    pat := "\"" + key + "\""
    idx := _json_find_sub(raw, pat)
    if idx < 0:
        return ""
    n := string_length(raw)
    p := idx + string_length(pat)
    p = _jp_skip_ws(raw, n, p)
    if p >= n:
        return ""
    if byte_at(raw, p) != 58:
        return ""
    p = _jp_skip_ws(raw, n, p + 1)
    pv := vector[int]()
    list_push(pv, p)
    return _jp_parse_str(raw, n, pv)

fn json_find_int(raw: string, key: string) -> int:
    pat := "\"" + key + "\""
    idx := _json_find_sub(raw, pat)
    if idx < 0:
        return 0
    n := string_length(raw)
    p := idx + string_length(pat)
    p = _jp_skip_ws(raw, n, p)
    if p >= n:
        return 0
    if byte_at(raw, p) != 58:
        return 0
    p = _jp_skip_ws(raw, n, p + 1)
    start := p
    if p < n and byte_at(raw, p) == 45:
        p = p + 1
    while p < n:
        d := byte_at(raw, p)
        if d >= 48 and d <= 57:
            p = p + 1
        else:
            break
    if p <= start:
        return 0
    return to_int(substring(raw, start, p - start))
