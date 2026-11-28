// ============================================================================
//  Cluster Standard Library: Embedded SQL Engine & PostgreSQL v3 Wire Codec (std/sql.zk)
//  Pure Cluster database engine:
//   - Embedded file-persisted table engine (CREATE TABLE, INSERT, SELECT, UPDATE, DELETE)
//   - PostgreSQL v3 binary wire protocol packet builders and message decoders
// ============================================================================

fn _sql_trim(s: string) -> string:
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

fn _sql_upper(s: string) -> string:
    n := string_length(s)
    if n == 0:
        return ""
    buf := mem_alloc(n + 1)
    i := 0
    while i < n:
        c := byte_at(s, i)
        if c >= 97 and c <= 122:
            c = c - 32
        ptr_write_u8(ptr_add(buf, i), c & 255)
        i = i + 1
    ptr_write_u8(ptr_add(buf, n), 0)
    return str_from_parts(buf, n)

fn _sql_find_sub(hay: string, pat: string, start: int) -> int:
    hn := string_length(hay)
    pn := string_length(pat)
    if pn == 0:
        return start
    if start < 0 or hn < pn:
        return -1
    i := start
    lim := hn - pn
    while i <= lim:
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

fn _sql_split_char(s: string, sep: int) -> vector[string]:
    out := vector[string]()
    n := string_length(s)
    if n == 0:
        return out
    start := 0
    i := 0
    while i < n:
        if byte_at(s, i) == sep:
            out.push(substring(s, start, i - start))
            start = i + 1
        i = i + 1
    out.push(substring(s, start, n - start))
    return out

fn _sql_join_char(parts: vector[string], sep: string) -> string:
    out := ""
    i := 0
    while i < parts.len():
        if i > 0:
            out = out + sep
        out = out + parts[i]
        i = i + 1
    return out

fn _sql_unquote(s: string) -> string:
    t := _sql_trim(s)
    n := string_length(t)
    if n >= 2:
        if (byte_at(t, 0) == 39 and byte_at(t, n - 1) == 39) or (byte_at(t, 0) == 34 and byte_at(t, n - 1) == 34):
            return substring(t, 1, n - 2)
    return t

fn _sql_esc_field(s: string) -> string:
    n := string_length(s)
    out := ""
    i := 0
    while i < n:
        c := byte_at(s, i)
        if c == 9:
            out = out + "\\t"
        elif c == 10:
            out = out + "\\n"
        elif c == 92:
            out = out + "\\\\"
        else:
            out = out + substring(s, i, 1)
        i = i + 1
    return out

fn _sql_unesc_field(s: string) -> string:
    n := string_length(s)
    out := ""
    i := 0
    while i < n:
        c := byte_at(s, i)
        if c == 92 and (i + 1) < n:
            nx := byte_at(s, i + 1)
            if nx == 116:
                out = out + "\t"
                i = i + 2
            elif nx == 110:
                out = out + "\n"
                i = i + 2
            elif nx == 92:
                out = out + "\\"
                i = i + 2
            else:
                out = out + substring(s, i, 1)
                i = i + 1
        else:
            out = out + substring(s, i, 1)
            i = i + 1
    return out

// Query execution result from SqlDb.
model SqlResult:
    ok: int
    err: string
    cols: vector[string]
    rows_flat: vector[string]
    ncols: int
    nrows: int
    affected: int

    fn sql_cell(& self, row: int, col: int) -> string:
        if row < 0 or row >= self.nrows or col < 0 or col >= self.ncols:
            return ""
        idx := (row * self.ncols) + col
        if idx < 0 or idx >= self.rows_flat.len():
            return ""
        return self.rows_flat[idx]

fn _sql_err_res(msg: string) -> SqlResult:
    return SqlResult(0, msg, vector[string](), vector[string](), 0, 0, 0)

fn _sql_ok_res(aff: int) -> SqlResult:
    return SqlResult(1, "", vector[string](), vector[string](), 0, 0, aff)

// File-backed relational SQL table store.
model SqlDb:
    path: string
    tables: vector[string]
    t_cols: vector[string]
    t_rows: vector[string]

    fn sql_find_table(& self, tname: string) -> int:
        i := 0
        while i < self.tables.len():
            if self.tables[i] == tname:
                return i
            i = i + 1
        return -1

    fn sql_save(& self) -> int:
        if string_length(self.path) == 0:
            return 1
        out := "CLDB1\n"
        ti := 0
        while ti < self.tables.len():
            out = out + "T:" + self.tables[ti] + "\t" + self.t_cols[ti] + "\n"
            rblock := self.t_rows[ti]
            if string_length(rblock) > 0:
                lines := _sql_split_char(rblock, 10)
                li := 0
                while li < lines.len():
                    if string_length(lines[li]) > 0:
                        out = out + "R:" + lines[li] + "\n"
                    li = li + 1
            ti = ti + 1
        return file_write(self.path, out)

    fn sql_exec(& self, raw_sql: string) -> SqlResult:
        q := _sql_trim(raw_sql)
        qn := string_length(q)
        if qn > 0 and byte_at(q, qn - 1) == 59:
            q = _sql_trim(substring(q, 0, qn - 1))
        uq := _sql_upper(q)
        if _sql_find_sub(uq, "CREATE TABLE ", 0) == 0:
            rest := _sql_trim(substring(q, 13, string_length(q) - 13))
            lp := _sql_find_sub(rest, "(", 0)
            rp := _sql_find_sub(rest, ")", 0)
            if lp <= 0 or rp <= lp:
                return _sql_err_res("Invalid CREATE TABLE syntax")
            tname := _sql_trim(substring(rest, 0, lp))
            if self.sql_find_table(tname) >= 0:
                return _sql_ok_res(0)
            cdefs := _sql_split_char(substring(rest, lp + 1, rp - lp - 1), 44)
            cnames := vector[string]()
            ci := 0
            while ci < cdefs.len():
                cd := _sql_trim(cdefs[ci])
                if string_length(cd) > 0:
                    sp := _sql_find_sub(cd, " ", 0)
                    if sp > 0:
                        cnames.push(_sql_trim(substring(cd, 0, sp)))
                    else:
                        cnames.push(cd)
                ci = ci + 1
            self.tables.push(tname)
            self.t_cols.push(_sql_join_char(cnames, "\t"))
            self.t_rows.push("")
            self.sql_save()
            return _sql_ok_res(0)

        if _sql_find_sub(uq, "DROP TABLE ", 0) == 0:
            tname := _sql_trim(substring(q, 11, string_length(q) - 11))
            tidx := self.sql_find_table(tname)
            if tidx < 0:
                return _sql_err_res("Unknown table: " + tname)
            nt := vector[string]()
            nc := vector[string]()
            nr := vector[string]()
            k := 0
            while k < self.tables.len():
                if k != tidx:
                    nt.push(self.tables[k])
                    nc.push(self.t_cols[k])
                    nr.push(self.t_rows[k])
                k = k + 1
            self.tables = nt
            self.t_cols = nc
            self.t_rows = nr
            self.sql_save()
            return _sql_ok_res(1)

        if _sql_find_sub(uq, "INSERT INTO ", 0) == 0:
            vpos := _sql_find_sub(uq, " VALUES", 12)
            if vpos < 0:
                return _sql_err_res("Missing VALUES in INSERT")
            tpart := _sql_trim(substring(q, 12, vpos - 12))
            lp_t := _sql_find_sub(tpart, "(", 0)
            tname := tpart
            if lp_t > 0:
                tname = _sql_trim(substring(tpart, 0, lp_t))
            tidx := self.sql_find_table(tname)
            if tidx < 0:
                return _sql_err_res("Unknown table: " + tname)
            vpart := _sql_trim(substring(q, vpos + 7, string_length(q) - vpos - 7))
            lp := _sql_find_sub(vpart, "(", 0)
            rp := _sql_find_sub(vpart, ")", 0)
            if lp < 0 or rp <= lp:
                return _sql_err_res("Invalid VALUES clause")
            raw_vals := _sql_split_char(substring(vpart, lp + 1, rp - lp - 1), 44)
            esc_vals := vector[string]()
            vi := 0
            while vi < raw_vals.len():
                esc_vals.push(_sql_esc_field(_sql_unquote(raw_vals[vi])))
                vi = vi + 1
            tcols := _sql_split_char(self.t_cols[tidx], 9)
            while esc_vals.len() < tcols.len():
                esc_vals.push("")
            line := _sql_join_char(esc_vals, "\t")
            cur := self.t_rows[tidx]
            if string_length(cur) > 0:
                self.t_rows[(tidx)] = cur + "\n" + line
            else:
                self.t_rows[(tidx)] = line
            self.sql_save()
            return _sql_ok_res(1)

        if _sql_find_sub(uq, "SELECT ", 0) == 0:
            fpos := _sql_find_sub(uq, " FROM ", 7)
            if fpos < 0:
                return _sql_err_res("Missing FROM in SELECT")
            sel_s := _sql_trim(substring(q, 7, fpos - 7))
            after_from := _sql_trim(substring(q, fpos + 6, string_length(q) - fpos - 6))
            uaf := _sql_upper(after_from)
            wpos := _sql_find_sub(uaf, " WHERE ", 0)
            tname := after_from
            wcol := ""
            wval := ""
            has_w := 0
            if wpos >= 0:
                tname = _sql_trim(substring(after_from, 0, wpos))
                wexpr := _sql_trim(substring(after_from, wpos + 7, string_length(after_from) - wpos - 7))
                eq := _sql_find_sub(wexpr, "=", 0)
                if eq > 0:
                    has_w = 1
                    wcol = _sql_trim(substring(wexpr, 0, eq))
                    wval = _sql_unquote(substring(wexpr, eq + 1, string_length(wexpr) - eq - 1))
            tidx := self.sql_find_table(tname)
            if tidx < 0:
                return _sql_err_res("Unknown table: " + tname)
            tcols := _sql_split_char(self.t_cols[tidx], 9)
            sel_idxs := vector[int]()
            out_cols := vector[string]()
            if sel_s == "*":
                ci := 0
                while ci < tcols.len():
                    sel_idxs.push(ci)
                    out_cols.push(tcols[ci])
                    ci = ci + 1
            else:
                req_cols := _sql_split_char(sel_s, 44)
                ri := 0
                while ri < req_cols.len():
                    rc := _sql_trim(req_cols[ri])
                    ci := 0
                    found := -1
                    while ci < tcols.len():
                        if tcols[ci] == rc:
                            found = ci
                            ci = tcols.len()
                        ci = ci + 1
                    if found >= 0:
                        sel_idxs.push(found)
                        out_cols.push(rc)
                    ri = ri + 1
            wcol_idx := -1
            if has_w == 1:
                ci := 0
                while ci < tcols.len():
                    if tcols[ci] == wcol:
                        wcol_idx = ci
                    ci = ci + 1
            flat := vector[string]()
            nrows := 0
            rblock := self.t_rows[tidx]
            if string_length(rblock) > 0:
                rlines := _sql_split_char(rblock, 10)
                li := 0
                while li < rlines.len():
                    if string_length(rlines[li]) > 0:
                        fields := _sql_split_char(rlines[li], 9)
                        keep := 1
                        if has_w == 1:
                            if wcol_idx < 0 or wcol_idx >= fields.len():
                                keep = 0
                            elif _sql_unesc_field(fields[wcol_idx]) != wval:
                                keep = 0
                        if keep == 1:
                            si := 0
                            while si < sel_idxs.len():
                                cidx := sel_idxs[si]
                                if cidx < fields.len():
                                    flat.push(_sql_unesc_field(fields[cidx]))
                                else:
                                    flat.push("")
                                si = si + 1
                            nrows = nrows + 1
                    li = li + 1
            return SqlResult(1, "", out_cols, flat, out_cols.len(), nrows, nrows)

        if _sql_find_sub(uq, "UPDATE ", 0) == 0:
            spos := _sql_find_sub(uq, " SET ", 7)
            if spos < 0:
                return _sql_err_res("Missing SET in UPDATE")
            tname := _sql_trim(substring(q, 7, spos - 7))
            tidx := self.sql_find_table(tname)
            if tidx < 0:
                return _sql_err_res("Unknown table: " + tname)
            rest := _sql_trim(substring(q, spos + 5, string_length(q) - spos - 5))
            urest := _sql_upper(rest)
            wpos := _sql_find_sub(urest, " WHERE ", 0)
            sexpr := rest
            has_w := 0
            wcol := ""
            wval := ""
            if wpos >= 0:
                sexpr = _sql_trim(substring(rest, 0, wpos))
                wexpr := _sql_trim(substring(rest, wpos + 7, string_length(rest) - wpos - 7))
                eqw := _sql_find_sub(wexpr, "=", 0)
                if eqw > 0:
                    has_w = 1
                    wcol = _sql_trim(substring(wexpr, 0, eqw))
                    wval = _sql_unquote(substring(wexpr, eqw + 1, string_length(wexpr) - eqw - 1))
            eqs := _sql_find_sub(sexpr, "=", 0)
            if eqs <= 0:
                return _sql_err_res("Invalid SET clause")
            scol := _sql_trim(substring(sexpr, 0, eqs))
            sval := _sql_unquote(substring(sexpr, eqs + 1, string_length(sexpr) - eqs - 1))
            tcols := _sql_split_char(self.t_cols[tidx], 9)
            scol_idx := -1
            wcol_idx := -1
            ci := 0
            while ci < tcols.len():
                if tcols[ci] == scol: scol_idx = ci
                if tcols[ci] == wcol: wcol_idx = ci
                ci = ci + 1
            if scol_idx < 0:
                return _sql_err_res("Unknown column: " + scol)
            aff := 0
            new_lines := vector[string]()
            rblock := self.t_rows[tidx]
            if string_length(rblock) > 0:
                rlines := _sql_split_char(rblock, 10)
                li := 0
                while li < rlines.len():
                    if string_length(rlines[li]) > 0:
                        fields := _sql_split_char(rlines[li], 9)
                        match_r := 1
                        if has_w == 1:
                            if wcol_idx < 0 or wcol_idx >= fields.len():
                                match_r = 0
                            elif _sql_unesc_field(fields[wcol_idx]) != wval:
                                match_r = 0
                        if match_r == 1 and scol_idx < fields.len():
                            fields[(scol_idx)] = _sql_esc_field(sval)
                            aff = aff + 1
                        new_lines.push(_sql_join_char(fields, "\t"))
                    li = li + 1
            self.t_rows[(tidx)] = _sql_join_char(new_lines, "\n")
            self.sql_save()
            return _sql_ok_res(aff)

        if _sql_find_sub(uq, "DELETE FROM ", 0) == 0:
            rest := _sql_trim(substring(q, 12, string_length(q) - 12))
            urest := _sql_upper(rest)
            wpos := _sql_find_sub(urest, " WHERE ", 0)
            tname := rest
            has_w := 0
            wcol := ""
            wval := ""
            if wpos >= 0:
                tname = _sql_trim(substring(rest, 0, wpos))
                wexpr := _sql_trim(substring(rest, wpos + 7, string_length(rest) - wpos - 7))
                eqw := _sql_find_sub(wexpr, "=", 0)
                if eqw > 0:
                    has_w = 1
                    wcol = _sql_trim(substring(wexpr, 0, eqw))
                    wval = _sql_unquote(substring(wexpr, eqw + 1, string_length(wexpr) - eqw - 1))
            tidx := self.sql_find_table(tname)
            if tidx < 0:
                return _sql_err_res("Unknown table: " + tname)
            tcols := _sql_split_char(self.t_cols[tidx], 9)
            wcol_idx := -1
            ci := 0
            while ci < tcols.len():
                if tcols[ci] == wcol: wcol_idx = ci
                ci = ci + 1
            aff := 0
            kept := vector[string]()
            rblock := self.t_rows[tidx]
            if string_length(rblock) > 0:
                rlines := _sql_split_char(rblock, 10)
                li := 0
                while li < rlines.len():
                    if string_length(rlines[li]) > 0:
                        fields := _sql_split_char(rlines[li], 9)
                        del := 1
                        if has_w == 1:
                            if wcol_idx < 0 or wcol_idx >= fields.len():
                                del = 0
                            elif _sql_unesc_field(fields[wcol_idx]) != wval:
                                del = 0
                        if del == 1:
                            aff = aff + 1
                        else:
                            kept.push(rlines[li])
                    li = li + 1
            self.t_rows[(tidx)] = _sql_join_char(kept, "\n")
            self.sql_save()
            return _sql_ok_res(aff)

        return _sql_err_res("Unsupported SQL statement")

// Open or create an embedded SQLite-style table database at path (pass "" for in-memory).
fn sql_open(path: string) -> SqlDb:
    db := SqlDb(path, vector[string](), vector[string](), vector[string]())
    if string_length(path) > 0 and file_exists(path) == 1:
        raw := file_read(path)
        lines := _sql_split_char(raw, 10)
        cur_t := -1
        li := 0
        while li < lines.len():
            ln := lines[li]
            if string_length(ln) >= 2:
                if substring(ln, 0, 2) == "T:":
                    rest := substring(ln, 2, string_length(ln) - 2)
                    tab := _sql_find_sub(rest, "\t", 0)
                    if tab > 0:
                        tname := substring(rest, 0, tab)
                        cols := substring(rest, tab + 1, string_length(rest) - tab - 1)
                        db.tables.push(tname)
                        db.t_cols.push(cols)
                        db.t_rows.push("")
                        cur_t = db.tables.len() - 1
                elif substring(ln, 0, 2) == "R:" and cur_t >= 0:
                    row_s := substring(ln, 2, string_length(ln) - 2)
                    if string_length(db.t_rows[cur_t]) > 0:
                        db.t_rows[(cur_t)] = db.t_rows[cur_t] + "\n" + row_s
                    else:
                        db.t_rows[(cur_t)] = row_s
            li = li + 1
    return db

// ============================================================================
//  PostgreSQL v3 Wire Protocol Codec (RFC / PG 3.0)
// ============================================================================

fn _pg_push_u16(&out: vector[int], v: int):
    out.push((v >> 8) & 255)
    out.push(v & 255)

fn _pg_push_u32(&out: vector[int], v: int):
    out.push((v >> 24) & 255)
    out.push((v >> 16) & 255)
    out.push((v >> 8) & 255)
    out.push(v & 255)

fn _pg_read_i32(b: vector[int], off: int) -> int:
    u := ((b[off] & 255) << 24) | ((b[off + 1] & 255) << 16) | ((b[off + 2] & 255) << 8) | (b[off + 3] & 255)
    if (u & 2147483648) != 0:
        return u - 4294967296
    return u

fn _pg_read_i16(b: vector[int], off: int) -> int:
    return ((b[off] & 255) << 8) | (b[off + 1] & 255)

fn _pg_push_cstr(&out: vector[int], s: string):
    n := string_length(s)
    i := 0
    while i < n:
        out.push(byte_at(s, i) & 255)
        i = i + 1
    out.push(0)

// Decoded PostgreSQL v3 backend/frontend wire message.
model PgMessage:
    mtype: int
    payload: vector[int]

// Build a PostgreSQL v3 StartupMessage packet.
fn pg_build_startup(user: string, database: string) -> vector[int]:
    body := vector[int]()
    _pg_push_u32(body, 196608)
    _pg_push_cstr(body, "user")
    _pg_push_cstr(body, user)
    _pg_push_cstr(body, "database")
    _pg_push_cstr(body, database)
    body.push(0)
    pkt := vector[int]()
    _pg_push_u32(pkt, body.len() + 4)
    i := 0
    while i < body.len():
        pkt.push(body[i])
        i = i + 1
    return pkt

// Build a PostgreSQL v3 Simple Query ('Q') packet.
fn pg_build_query(sql: string) -> vector[int]:
    pkt := vector[int]()
    pkt.push(81)
    _pg_push_u32(pkt, 4 + string_length(sql) + 1)
    _pg_push_cstr(pkt, sql)
    return pkt

// Build a PostgreSQL v3 Parse ('P') extended query packet.
fn pg_build_parse(stmt_name: string, sql: string) -> vector[int]:
    total := 4 + string_length(stmt_name) + 1 + string_length(sql) + 1 + 2
    pkt := vector[int]()
    pkt.push(80)
    _pg_push_u32(pkt, total)
    _pg_push_cstr(pkt, stmt_name)
    _pg_push_cstr(pkt, sql)
    _pg_push_u16(pkt, 0)
    return pkt

// Build a PostgreSQL v3 Terminate ('X') packet.
fn pg_build_terminate() -> vector[int]:
    pkt := vector[int]()
    pkt.push(88)
    _pg_push_u32(pkt, 4)
    return pkt

// Decode concatenated PostgreSQL v3 tagged wire messages.
fn pg_decode_messages(buf: vector[int]) -> vector[PgMessage]:
    msgs := vector[PgMessage]()
    pos := 0
    while (pos + 5) <= buf.len():
        mtype := buf[pos] & 255
        mlen := _pg_read_i32(buf, pos + 1)
        if mlen < 4 or (pos + 1 + mlen) > buf.len():
            break
        pl := vector[int]()
        i := 5
        while i < (1 + mlen):
            pl.push(buf[pos + i] & 255)
            i = i + 1
        msgs.push(PgMessage(mtype, pl))
        pos = pos + 1 + mlen
    return msgs

// Decode fields from a PostgreSQL v3 DataRow ('D') message payload.
fn pg_parse_data_row(payload: vector[int]) -> vector[string]:
    vals := vector[string]()
    if payload.len() < 2:
        return vals
    ncols := _pg_read_i16(payload, 0)
    pos := 2
    ci := 0
    while ci < ncols and (pos + 4) <= payload.len():
        flen := _pg_read_i32(payload, pos)
        pos = pos + 4
        if flen < 0:
            vals.push("NULL")
        else:
            if (pos + flen) > payload.len():
                break
            if flen == 0:
                vals.push("")
            else:
                mem := mem_alloc(flen + 1)
                bi := 0
                while bi < flen:
                    ptr_write_u8(ptr_add(mem, bi), payload[pos + bi] & 255)
                    bi = bi + 1
                ptr_write_u8(ptr_add(mem, flen), 0)
                vals.push(str_from_parts(mem, flen))
            pos = pos + flen
        ci = ci + 1
    return vals
