// ==============================================================================
// Cluster Document (.cld) - Standard Pure Cluster Module
// Ultra-Fast Document Parser, AST & Binary Bundle Serializer
// Combines Jekyll Conventions, Hugo Speed, and Astro Islands Architecture
// 100% Pure Cluster Language · Zero External Dependencies
// ==============================================================================

model CldMeta:
    title: string
    author: string
    date: string
    layout: string
    tags: string
    slug: string
    description: string

model CldBlock:
    kind: string     // h1, h2, h3, h4, p, code, quote, list, table, island, hr, raw_html
    content: string
    extra: string    // language for code, level for heading, props for island

model CldIsland:
    name: string
    directive: string // load, idle, visible, zero-js
    props: string
    fallback: string

model CldDoc:
    meta: CldMeta
    blocks: vector[CldBlock]
    islands: vector[CldIsland]
    raw_body: string

// ------------------------------------------------------------------------------
// String & Utility Helpers
// ------------------------------------------------------------------------------

fn cld_split(text: string, delim: string) -> vector[string]:
    let mut parts: vector[string] = []
    let mut buf: string = ""
    let mut i: int = 0
    let text_len: int = len(text)
    while i < text_len:
        c := char_at(text, i)
        if c == delim:
            parts.push(buf)
            buf = ""
        else:
            buf = buf + c
        i = i + 1
    parts.push(buf)
    return parts

fn cld_trim(text: string) -> string:
    let text_len: int = len(text)
    if text_len == 0:
        return ""
    let mut start: int = 0
    while start < text_len:
        c := char_at(text, start)
        if c != " " and c != "\t" and c != "\r" and c != "\n":
            break
        start = start + 1
    if start >= text_len:
        return ""
    let mut end: int = text_len - 1
    while end >= start:
        c := char_at(text, end)
        if c != " " and c != "\t" and c != "\r" and c != "\n":
            break
        end = end - 1
    let result_len: int = end - start + 1
    if result_len <= 0:
        return ""
    return substring(text, start, result_len)

fn cld_starts_with(text: string, prefix: string) -> int:
    let tlen: int = len(text)
    let plen: int = len(prefix)
    if plen > tlen:
        return 0
    sub := substring(text, 0, plen)
    if sub == prefix:
        return 1
    return 0

fn cld_to_lower_char(c: string) -> string:
    if c == "A": return "a"
    elif c == "B": return "b"
    elif c == "C": return "c"
    elif c == "D": return "d"
    elif c == "E": return "e"
    elif c == "F": return "f"
    elif c == "G": return "g"
    elif c == "H": return "h"
    elif c == "I": return "i"
    elif c == "J": return "j"
    elif c == "K": return "k"
    elif c == "L": return "l"
    elif c == "M": return "m"
    elif c == "N": return "n"
    elif c == "O": return "o"
    elif c == "P": return "p"
    elif c == "Q": return "q"
    elif c == "R": return "r"
    elif c == "S": return "s"
    elif c == "T": return "t"
    elif c == "U": return "u"
    elif c == "V": return "v"
    elif c == "W": return "w"
    elif c == "X": return "x"
    elif c == "Y": return "y"
    elif c == "Z": return "z"
    return c

fn cld_slugify(text: string) -> string:
    let mut out: string = ""
    let tlen: int = len(text)
    let valid_chars: string = "abcdefghijklmnopqrstuvwxyz0123456789-"
    let mut i: int = 0
    while i < tlen:
        c := char_at(text, i)
        if c == " " or c == "_" or c == "/" or c == ".":
            out = out + "-"
        else:
            lc := cld_to_lower_char(c)
            let mut vi: int = 0
            let mut found: int = 0
            while vi < len(valid_chars):
                if char_at(valid_chars, vi) == lc:
                    found = 1
                    break
                vi = vi + 1
            if found == 1:
                out = out + lc
        i = i + 1
    return out

fn cld_contains(text: string, sub: string) -> int:
    let tlen: int = len(text)
    let slen: int = len(sub)
    if slen > tlen:
        return 0
    let mut i: int = 0
    while i <= tlen - slen:
        if substring(text, i, slen) == sub:
            return 1
        i = i + 1
    return 0

fn cld_replace_token(text: string, marker: string, tag_open: string, tag_close: string) -> string:
    if cld_contains(text, marker) == 0:
        return text
    let mut out: string = ""
    let mlen: int = len(marker)
    let tlen: int = len(text)
    let mut i: int = 0
    let mut chunk_start: int = 0
    let mut in_tag: int = 0
    while i < tlen:
        if i + mlen <= tlen:
            sub := substring(text, i, mlen)
            if sub == marker:
                if i > chunk_start:
                    out = out + substring(text, chunk_start, i - chunk_start)
                if in_tag == 0:
                    out = out + tag_open
                    in_tag = 1
                else:
                    out = out + tag_close
                    in_tag = 0
                i = i + mlen
                chunk_start = i
                continue
        i = i + 1
    if chunk_start < tlen:
        out = out + substring(text, chunk_start, tlen - chunk_start)
    return out

// Inline Markdown transformer: **bold**, *italic*, `code`
fn cld_inline_html(text: string) -> string:
    let s1 := cld_replace_token(text, "**", "<strong>", "</strong>")
    let s2 := cld_replace_token(s1, "`", "<code>", "</code>")
    let s3 := cld_replace_token(s2, "*", "<em>", "</em>")
    return s3

// ------------------------------------------------------------------------------
// Document Creation & Constructors
// ------------------------------------------------------------------------------

fn cld_meta_new(title: string, layout: string) -> CldMeta:
    slug := cld_slugify(title)
    return CldMeta(title, "Anonymous", "", layout, "", slug, "")

fn cld_new() -> CldDoc:
    meta := cld_meta_new("Untitled Document", "default")
    let blks: vector[CldBlock] = []
    let isls: vector[CldIsland] = []
    return CldDoc(meta, blks, isls, "")

// ------------------------------------------------------------------------------
// Parser: Parse .cld Text into CldDoc AST
// ------------------------------------------------------------------------------

fn cld_parse_text(content: string) -> CldDoc:
    doc := cld_new()
    lines := cld_split(content, "\n")
    let total_lines: int = len(lines)
    
    let mut in_header: int = 1
    let mut in_code_block: int = 0
    let mut code_buf: string = ""
    let mut code_lang: string = "text"
    let mut line_idx: int = 0

    while line_idx < total_lines:
        raw_line := lines[line_idx]
        trimmed := cld_trim(raw_line)

        // Header section parsing
        if in_header == 1:
            if trimmed == "===" or trimmed == "---":
                in_header = 0
                line_idx = line_idx + 1
                continue
            
            // Key|Value or Key: Value
            if len(trimmed) > 0:
                sep_idx := -1
                let mut ci: int = 0
                let trim_len: int = len(trimmed)
                while ci < trim_len:
                    ch := char_at(trimmed, ci)
                    if ch == "|" or ch == ":":
                        sep_idx = ci
                        break
                    ci = ci + 1
                
                if sep_idx > 0:
                    key := cld_trim(substring(trimmed, 0, sep_idx))
                    val := cld_trim(substring(trimmed, sep_idx + 1, trim_len - sep_idx - 1))
                    if key == "title":
                        doc.meta.title = val
                        doc.meta.slug = cld_slugify(val)
                    elif key == "author":
                        doc.meta.author = val
                    elif key == "date":
                        doc.meta.date = val
                    elif key == "layout":
                        doc.meta.layout = val
                    elif key == "tags":
                        doc.meta.tags = val
                    elif key == "slug":
                        doc.meta.slug = val
                    elif key == "description":
                        doc.meta.description = val

            line_idx = line_idx + 1
            continue

        // Body section parsing
        if in_code_block == 1:
            if cld_starts_with(trimmed, "```") == 1:
                in_code_block = 0
                b := CldBlock("code", code_buf, code_lang)
                doc.blocks.push(b)
                code_buf = ""
                code_lang = "text"
            else:
                if len(code_buf) > 0:
                    code_buf = code_buf + "\n" + raw_line
                else:
                    code_buf = raw_line
            line_idx = line_idx + 1
            continue

        if cld_starts_with(trimmed, "```") == 1:
            in_code_block = 1
            if len(trimmed) > 3:
                code_lang = cld_trim(substring(trimmed, 3, len(trimmed) - 3))
            else:
                code_lang = "text"
            code_buf = ""
            line_idx = line_idx + 1
            continue

        if len(trimmed) == 0:
            line_idx = line_idx + 1
            continue

        // Heading checks: #, ##, ###, ####
        if cld_starts_with(trimmed, "#### ") == 1:
            h_text := cld_trim(substring(trimmed, 5, len(trimmed) - 5))
            b := CldBlock("h4", h_text, "4")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "### ") == 1:
            h_text := cld_trim(substring(trimmed, 4, len(trimmed) - 4))
            b := CldBlock("h3", h_text, "3")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "## ") == 1:
            h_text := cld_trim(substring(trimmed, 3, len(trimmed) - 3))
            b := CldBlock("h2", h_text, "2")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "# ") == 1:
            h_text := cld_trim(substring(trimmed, 2, len(trimmed) - 2))
            b := CldBlock("h1", h_text, "1")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "> ") == 1:
            q_text := cld_trim(substring(trimmed, 2, len(trimmed) - 2))
            b := CldBlock("quote", q_text, "")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "- ") == 1 or cld_starts_with(trimmed, "* ") == 1:
            li_text := cld_trim(substring(trimmed, 2, len(trimmed) - 2))
            b := CldBlock("list", li_text, "")
            doc.blocks.push(b)
        elif trimmed == "---" or trimmed == "***":
            b := CldBlock("hr", "", "")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "<island ") == 1:
            // Parse island component: <island name="Counter" client:load count="0" />
            let mut isl_name: string = "Widget"
            let mut isl_dir: string = "load"
            let mut isl_props: string = ""
            
            // Extract attributes from tag
            attrs := cld_split(trimmed, " ")
            let mut ai: int = 1
            while ai < len(attrs):
                attr := attrs[ai]
                if cld_starts_with(attr, "name=\"") == 1:
                    isl_name = substring(attr, 6, len(attr) - 7)
                elif cld_starts_with(attr, "client:load") == 1:
                    isl_dir = "load"
                elif cld_starts_with(attr, "client:idle") == 1:
                    isl_dir = "idle"
                elif cld_starts_with(attr, "client:visible") == 1:
                    isl_dir = "visible"
                elif cld_starts_with(attr, "client:zero-js") == 1:
                    isl_dir = "zero-js"
                else:
                    if attr != "/>" and attr != ">":
                        if len(isl_props) > 0:
                            isl_props = isl_props + " " + attr
                        else:
                            isl_props = attr
                ai = ai + 1

            isl := CldIsland(isl_name, isl_dir, isl_props, "")
            doc.islands.push(isl)
            b := CldBlock("island", isl_name, isl_dir + "|" + isl_props)
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "::: callout") == 1:
            let mut c_type: string = "note"
            let mut c_title: string = "Note"
            let clen: int = len(trimmed)
            if cld_contains(trimmed, "type=\"") == 1:
                let mut si: int = 0
                while si < clen - 6:
                    if substring(trimmed, si, 6) == "type=\"":
                        let mut se: int = si + 6
                        while se < clen:
                            if char_at(trimmed, se) == "\"":
                                c_type = substring(trimmed, si + 6, se - (si + 6))
                                break
                            se = se + 1
                        break
                    si = si + 1
            if cld_contains(trimmed, "title=\"") == 1:
                let mut ti: int = 0
                while ti < clen - 7:
                    if substring(trimmed, ti, 7) == "title=\"":
                        let mut te: int = ti + 7
                        while te < clen:
                            if char_at(trimmed, te) == "\"":
                                c_title = substring(trimmed, ti + 7, te - (ti + 7))
                                break
                            te = te + 1
                        break
                    ti = ti + 1
            elif c_type == "warning": c_title = "Warning"
            elif c_type == "tip": c_title = "Pro Tip"
            elif c_type == "danger": c_title = "Danger"
            elif c_type == "important": c_title = "Important"

            let mut callout_data: string = ""
            let mut next_idx: int = line_idx + 1
            while next_idx < total_lines:
                c_raw := lines[next_idx]
                c_trim := cld_trim(c_raw)
                if c_trim == ":::" or c_trim == "::":
                    next_idx = next_idx + 1
                    break
                if len(c_trim) > 0:
                    if len(callout_data) > 0:
                        callout_data = callout_data + "\n" + c_trim
                    else:
                        callout_data = c_trim
                next_idx = next_idx + 1
            line_idx = next_idx - 1
            b := CldBlock("callout", callout_data, c_type + "|" + c_title)
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "::: tabs") == 1:
            let mut tabs_data: string = ""
            let mut next_idx: int = line_idx + 1
            while next_idx < total_lines:
                tb_raw := lines[next_idx]
                tb_trim := cld_trim(tb_raw)
                if tb_trim == ":::" or tb_trim == "::":
                    next_idx = next_idx + 1
                    break
                if len(tabs_data) > 0:
                    tabs_data = tabs_data + "\n" + tb_raw
                else:
                    tabs_data = tb_raw
                next_idx = next_idx + 1
            line_idx = next_idx - 1
            b := CldBlock("tabs", tabs_data, "")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "::: sheet") == 1:
            let mut sheet_title: string = "Data Sheet"
            if cld_contains(trimmed, "title=\"") == 1:
                let mut si: int = 0
                let slen: int = len(trimmed)
                while si < slen - 7:
                    if substring(trimmed, si, 7) == "title=\"":
                        let mut se: int = si + 7
                        while se < slen:
                            if char_at(trimmed, se) == "\"":
                                sheet_title = substring(trimmed, si + 7, se - (si + 7))
                                break
                            se = se + 1
                        break
                    si = si + 1

            let mut sheet_data: string = ""
            let mut next_idx: int = line_idx + 1
            while next_idx < total_lines:
                s_raw := lines[next_idx]
                s_trim := cld_trim(s_raw)
                if s_trim == ":::" or s_trim == "::":
                    next_idx = next_idx + 1
                    break
                if len(s_trim) > 0:
                    if len(sheet_data) > 0:
                        sheet_data = sheet_data + "\n" + s_trim
                    else:
                        sheet_data = s_trim
                next_idx = next_idx + 1
            line_idx = next_idx - 1
            b := CldBlock("sheet", sheet_data, sheet_title)
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "|") == 1:
            let mut table_raw: string = raw_line
            let mut next_idx: int = line_idx + 1
            while next_idx < total_lines:
                next_raw := lines[next_idx]
                next_trimmed := cld_trim(next_raw)
                if cld_starts_with(next_trimmed, "|") == 1:
                    table_raw = table_raw + "\n" + next_trimmed
                    next_idx = next_idx + 1
                else:
                    break
            line_idx = next_idx - 1
            b := CldBlock("table", table_raw, "")
            doc.blocks.push(b)
        elif cld_starts_with(trimmed, "<") == 1:
            b := CldBlock("raw_html", raw_line, "")
            doc.blocks.push(b)
        else:
            // Standard paragraph
            b := CldBlock("p", trimmed, "")
            doc.blocks.push(b)

        line_idx = line_idx + 1

    return doc

fn cld_parse_file(filepath: string) -> CldDoc:
    if file_exists(filepath) == 0:
        return cld_new()
    content := file_read(filepath)
    return cld_parse_text(content)

// ------------------------------------------------------------------------------
// Binary Packing (.clb bundle format)
// ------------------------------------------------------------------------------

fn cld_pack(doc: CldDoc) -> string:
    let mut out: string = "CLD/1.0\n"
    out = out + "META|" + doc.meta.title + "|" + doc.meta.author + "|" + doc.meta.date + "|" + doc.meta.layout + "|" + doc.meta.tags + "|" + doc.meta.slug + "|" + doc.meta.description + "\n"
    out = out + "BLOCKS_COUNT|" + str(len(doc.blocks)) + "\n"
    
    let mut bi: int = 0
    while bi < len(doc.blocks):
        b := doc.blocks[bi]
        out = out + "BLOCK|" + b.kind + "|" + b.extra + "|" + b.content + "\n"
        bi = bi + 1
    
    out = out + "ISLANDS_COUNT|" + str(len(doc.islands)) + "\n"
    let mut ii: int = 0
    while ii < len(doc.islands):
        isl := doc.islands[ii]
        out = out + "ISLAND|" + isl.name + "|" + isl.directive + "|" + isl.props + "|" + isl.fallback + "\n"
        ii = ii + 1
    
    out = out + "END_CLD\n"
    return out

fn cld_unpack(raw_bytes: string) -> CldDoc:
    doc := cld_new()
    lines := cld_split(raw_bytes, "\n")
    let total: int = len(lines)
    if total < 2:
        return doc
    
    let mut i: int = 0
    while i < total:
        line := lines[i]
        if cld_starts_with(line, "META|") == 1:
            parts := cld_split(line, "|")
            if len(parts) >= 8:
                doc.meta.title = parts[1]
                doc.meta.author = parts[2]
                doc.meta.date = parts[3]
                doc.meta.layout = parts[4]
                doc.meta.tags = parts[5]
                doc.meta.slug = parts[6]
                doc.meta.description = parts[7]
        elif cld_starts_with(line, "BLOCK|") == 1:
            parts := cld_split(line, "|")
            if len(parts) >= 4:
                b := CldBlock(parts[1], parts[3], parts[2])
                doc.blocks.push(b)
        elif cld_starts_with(line, "ISLAND|") == 1:
            parts := cld_split(line, "|")
            if len(parts) >= 5:
                isl := CldIsland(parts[1], parts[2], parts[3], parts[4])
                doc.islands.push(isl)
        i = i + 1

    return doc

fn cld_save_binary(filepath: string, doc: CldDoc) -> int:
    packed := cld_pack(doc)
    return file_write(filepath, packed)

fn cld_load_binary(filepath: string) -> CldDoc:
    if file_exists(filepath) == 0:
        return cld_new()
    packed := file_read(filepath)
    return cld_unpack(packed)

// ------------------------------------------------------------------------------
// HTML Rendering & Astro Islands Generation
// ------------------------------------------------------------------------------

fn cld_render_blocks(doc: CldDoc) -> string:
    let mut out: string = ""
    let mut in_list: int = 0
    let mut bi: int = 0
    let total: int = len(doc.blocks)

    while bi < total:
        b := doc.blocks[bi]
        
        // Handle list wrapper
        if b.kind == "list":
            if in_list == 0:
                out = out + "<ul>\n"
                in_list = 1
            out = out + "  <li>" + cld_inline_html(b.content) + "</li>\n"
        else:
            if in_list == 1:
                out = out + "</ul>\n"
                in_list = 0

            if b.kind == "h1":
                slug := cld_slugify(b.content)
                out = out + "<h1 id=\"" + slug + "\">" + cld_inline_html(b.content) + "</h1>\n"
            elif b.kind == "h2":
                slug := cld_slugify(b.content)
                out = out + "<h2 id=\"" + slug + "\">" + cld_inline_html(b.content) + "</h2>\n"
            elif b.kind == "h3":
                slug := cld_slugify(b.content)
                out = out + "<h3 id=\"" + slug + "\">" + cld_inline_html(b.content) + "</h3>\n"
            elif b.kind == "h4":
                slug := cld_slugify(b.content)
                out = out + "<h4 id=\"" + slug + "\">" + cld_inline_html(b.content) + "</h4>\n"
            elif b.kind == "p":
                out = out + "<p>" + cld_inline_html(b.content) + "</p>\n"
            elif b.kind == "quote":
                out = out + "<blockquote>" + cld_inline_html(b.content) + "</blockquote>\n"
            elif b.kind == "table":
                t_lines := cld_split(b.content, "\n")
                if len(t_lines) >= 1:
                    out = out + "<table>\n<thead>\n<tr>\n"
                    h_cols := cld_split(t_lines[0], "|")
                    let mut hi: int = 0
                    while hi < len(h_cols):
                        cell := cld_trim(h_cols[hi])
                        if len(cell) > 0:
                            out = out + "  <th>" + cld_inline_html(cell) + "</th>\n"
                        hi = hi + 1
                    out = out + "</tr>\n</thead>\n<tbody>\n"
                    
                    let mut ri: int = 1
                    while ri < len(t_lines):
                        row_line := t_lines[ri]
                        if cld_contains(row_line, "---") == 0:
                            r_cols := cld_split(row_line, "|")
                            out = out + "<tr>\n"
                            let mut ci: int = 0
                            while ci < len(r_cols):
                                cell := cld_trim(r_cols[ci])
                                if len(cell) > 0:
                                    out = out + "  <td>" + cld_inline_html(cell) + "</td>\n"
                                ci = ci + 1
                            out = out + "</tr>\n"
                        ri = ri + 1
                    out = out + "</tbody>\n</table>\n"
            elif b.kind == "sheet":
                t_lines := cld_split(b.content, "\n")
                if len(t_lines) >= 1:
                    let mut sheet_html: string = "<div class=\"cluster-sheet-wrapper\">\n"
                    sheet_html = sheet_html + "  <div class=\"cluster-sheet-header\">\n"
                    sheet_html = sheet_html + "    <div class=\"cluster-sheet-title\">📊 " + b.extra + "</div>\n"
                    sheet_html = sheet_html + "    <div class=\"cluster-sheet-controls\">\n"
                    sheet_html = sheet_html + "      <input type=\"text\" class=\"cluster-sheet-search\" placeholder=\"🔍 Search table...\" oninput=\"clusterSheetFilter(this)\" />\n"
                    sheet_html = sheet_html + "      <button class=\"cluster-sheet-export-btn\" onclick=\"clusterSheetExportCSV(this)\">📥 Export CSV</button>\n"
                    sheet_html = sheet_html + "    </div>\n"
                    sheet_html = sheet_html + "  </div>\n"
                    sheet_html = sheet_html + "  <div class=\"cluster-sheet-container\">\n"
                    sheet_html = sheet_html + "    <table class=\"cluster-sheet-table\">\n"
                    sheet_html = sheet_html + "      <thead>\n        <tr>\n"
                    
                    h_cols := cld_split(t_lines[0], "|")
                    let mut hi: int = 0
                    let mut valid_col: int = 0
                    while hi < len(h_cols):
                        cell := cld_trim(h_cols[hi])
                        if len(cell) > 0:
                            sheet_html = sheet_html + "          <th onclick=\"clusterSheetSort(this, " + str(valid_col) + ")\">" + cld_inline_html(cell) + " <span class=\"sort-icon\">⇅</span></th>\n"
                            valid_col = valid_col + 1
                        hi = hi + 1
                    sheet_html = sheet_html + "        </tr>\n      </thead>\n      <tbody>\n"
                    
                    let mut ri: int = 1
                    let mut row_count: int = 0
                    while ri < len(t_lines):
                        row_line := t_lines[ri]
                        if cld_contains(row_line, "---") == 0:
                            r_cols := cld_split(row_line, "|")
                            sheet_html = sheet_html + "        <tr>\n"
                            let mut ci: int = 0
                            while ci < len(r_cols):
                                cell := cld_trim(r_cols[ci])
                                if len(cell) > 0 or (ci > 0 and ci < len(r_cols) - 1):
                                    if len(cell) > 0:
                                        sheet_html = sheet_html + "          <td>" + cld_inline_html(cell) + "</td>\n"
                                ci = ci + 1
                            sheet_html = sheet_html + "        </tr>\n"
                            row_count = row_count + 1
                        ri = ri + 1
                    
                    sheet_html = sheet_html + "      </tbody>\n    </table>\n  </div>\n"
                    sheet_html = sheet_html + "  <div class=\"cluster-sheet-footer\">\n"
                    sheet_html = sheet_html + "    <span class=\"cluster-sheet-count\">Total: " + str(row_count) + " entries</span>\n"
                    sheet_html = sheet_html + "  </div>\n</div>\n"
                    out = out + sheet_html
            elif b.kind == "callout":
                c_parts := cld_split(b.extra, "|")
                let mut cp_type: string = "note"
                let mut cp_title: string = "Note"
                let mut cp_icon: string = "ℹ️"
                if len(c_parts) >= 1: cp_type = c_parts[0]
                if len(c_parts) >= 2: cp_title = c_parts[1]
                if cp_type == "warning": cp_icon = "⚠️"
                elif cp_type == "tip": cp_icon = "💡"
                elif cp_type == "danger": cp_icon = "🚨"
                elif cp_type == "important": cp_icon = "❗"
                
                out = out + "<div class=\"cluster-callout callout-" + cp_type + "\">\n"
                out = out + "  <div class=\"callout-header\"><span class=\"callout-icon\">" + cp_icon + "</span> <strong>" + cp_title + "</strong></div>\n"
                out = out + "  <div class=\"callout-body\"><p>" + cld_inline_html(b.content) + "</p></div>\n"
                out = out + "</div>\n"
            elif b.kind == "tabs":
                tb_lines := cld_split(b.content, "\n")
                let mut tab_names: vector[string] = []
                let mut tab_bodies: vector[string] = []
                let mut cur_body: string = ""
                let mut ti: int = 0
                while ti < len(tb_lines):
                    tl := tb_lines[ti]
                    tl_trim := cld_trim(tl)
                    if cld_starts_with(tl_trim, "== ") == 1:
                        if len(tab_names) > 0:
                            tab_bodies.push(cur_body)
                            cur_body = ""
                        tab_name := cld_trim(substring(tl_trim, 3, len(tl_trim) - 3))
                        tab_names.push(tab_name)
                    else:
                        if len(cur_body) > 0:
                            cur_body = cur_body + "\n" + tl
                        else:
                            cur_body = tl
                    ti = ti + 1
                if len(tab_names) > 0:
                    tab_bodies.push(cur_body)
                
                out = out + "<div class=\"cluster-tabs-wrapper\">\n"
                out = out + "  <div class=\"cluster-tabs-header\">\n"
                let mut hti: int = 0
                while hti < len(tab_names):
                    let mut active_cls: string = ""
                    if hti == 0: active_cls = " active"
                    out = out + "    <button class=\"cluster-tab-btn" + active_cls + "\" onclick=\"clusterSwitchTab(this, " + str(hti) + ")\">" + tab_names[hti] + "</button>\n"
                    hti = hti + 1
                out = out + "  </div>\n"
                out = out + "  <div class=\"cluster-tabs-body\">\n"
                let mut bti: int = 0
                while bti < len(tab_bodies):
                    let mut b_active_cls: string = " style=\"display:none;\""
                    if bti == 0: b_active_cls = " style=\"display:block;\""
                    out = out + "    <div class=\"cluster-tab-pane\"" + b_active_cls + " data-tab-idx=\"" + str(bti) + "\">\n"
                    out = out + "      <div class=\"highlight\"><pre class=\"highlight\"><code>" + tab_bodies[bti] + "</code></pre></div>\n"
                    out = out + "    </div>\n"
                    bti = bti + 1
                out = out + "  </div>\n</div>\n"
            elif b.kind == "code":
                let mut lang: string = b.extra
                if len(lang) == 0:
                    lang = "cluster"
                out = out + "<div class=\"language-" + lang + " highlighter-rouge\"><div class=\"highlight\"><pre class=\"highlight\"><code class=\"language-" + lang + "\">" + b.content + "</code></pre></div></div>\n"
            elif b.kind == "hr":
                out = out + "<hr />\n"
            elif b.kind == "raw_html":
                out = out + b.content + "\n"
            elif b.kind == "island":
                // Render Island Container with partial hydration metadata
                parts := cld_split(b.extra, "|")
                let mut dir: string = "load"
                let mut props: string = ""
                if len(parts) >= 1:
                    dir = parts[0]
                if len(parts) >= 2:
                    props = parts[1]
                
                out = out + "<cluster-island data-island=\"" + b.content + "\" data-client=\"" + dir + "\" " + props + ">\n"
                out = out + "  <!-- Astro-style Island Component: " + b.content + " (" + dir + ") -->\n"
                out = out + "  <div class=\"cluster-island-placeholder\" id=\"island-" + cld_slugify(b.content) + "\">\n"
                out = out + "    <span>[Interactive Island: " + b.content + "]</span>\n"
                out = out + "  </div>\n"
                out = out + "</cluster-island>\n"

        bi = bi + 1

    if in_list == 1:
        out = out + "</ul>\n"

    return out

// Replace single variable in layout string
fn cld_template_replace(layout: string, key: string, val: string) -> string:
    ob := "{" + "{"
    cb := "}" + "}"
    target := ob + key + cb
    tlen := len(target)
    target_sp := ob + " " + key + " " + cb
    splen := len(target_sp)

    if cld_contains(layout, target) == 0 and cld_contains(layout, target_sp) == 0:
        return layout

    let mut out: string = ""
    let llen: int = len(layout)
    let mut i: int = 0
    let mut chunk_start: int = 0
    while i < llen:
        if i + splen <= llen:
            sub := substring(layout, i, splen)
            if sub == target_sp:
                if i > chunk_start:
                    out = out + substring(layout, chunk_start, i - chunk_start)
                out = out + val
                i = i + splen
                chunk_start = i
                continue
        if i + tlen <= llen:
            sub := substring(layout, i, tlen)
            if sub == target:
                if i > chunk_start:
                    out = out + substring(layout, chunk_start, i - chunk_start)
                out = out + val
                i = i + tlen
                chunk_start = i
                continue
        i = i + 1
    if chunk_start < llen:
        out = out + substring(layout, chunk_start, llen - chunk_start)
    return out

fn cld_render_page(doc: CldDoc, layout_html: string) -> string:
    body_html := cld_render_blocks(doc)
    let mut res: string = layout_html
    res = cld_template_replace(res, "content", body_html)
    res = cld_template_replace(res, "title", doc.meta.title)
    res = cld_template_replace(res, "author", doc.meta.author)
    res = cld_template_replace(res, "date", doc.meta.date)
    res = cld_template_replace(res, "description", doc.meta.description)
    res = cld_template_replace(res, "tags", doc.meta.tags)
    res = cld_template_replace(res, "slug", doc.meta.slug)
    return res
