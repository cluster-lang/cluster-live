// ==============================================================================
// Cluster Binary Bundle (.clb) - Standard Pure Cluster Module
// Ultra-fast, zero-dependency structured data object format (replaces JSON/Protobuf)
// ==============================================================================

model ClbItem:
    key: string
    vtype: string
    v_str: string
    v_int: int
    v_float: float
    v_bool: int

model ClbDoc:
    items: vector[ClbItem]

fn clb_new() -> ClbDoc:
    let list: vector[ClbItem] = []
    return ClbDoc(list)

fn clb_has(doc: ClbDoc, key: string) -> int:
    let items: vector[ClbItem] = doc.items
    let mut i: int = 0
    while i < len(items):
        let it: ClbItem = items[i]
        if it.key == key:
            return 1
        i = i + 1
    return 0

fn clb_set_int(doc: ClbDoc, key: string, v: int) -> void:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            it.vtype = "int"
            it.v_int = v
            it.v_str = str(v)
            return
        i = i + 1
    item := ClbItem(key, "int", str(v), v, 0.0, 0)
    doc.items.push(item)

fn clb_get_int(doc: ClbDoc, key: string, default_v: int) -> int:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            if it.vtype == "int":
                return it.v_int
            return to_int(it.v_str)
        i = i + 1
    return default_v

fn clb_set_float(doc: ClbDoc, key: string, v: float) -> void:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            it.vtype = "float"
            it.v_float = v
            it.v_str = str(v)
            return
        i = i + 1
    item := ClbItem(key, "float", str(v), 0, v, 0)
    doc.items.push(item)

fn clb_get_float(doc: ClbDoc, key: string, default_v: float) -> float:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            if it.vtype == "float":
                return it.v_float
            return to_float(it.v_str)
        i = i + 1
    return default_v

fn clb_set_string(doc: ClbDoc, key: string, v: string) -> void:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            it.vtype = "string"
            it.v_str = v
            return
        i = i + 1
    item := ClbItem(key, "string", v, 0, 0.0, 0)
    doc.items.push(item)

fn clb_get_string(doc: ClbDoc, key: string, default_v: string) -> string:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            return it.v_str
        i = i + 1
    return default_v

fn clb_set_bool(doc: ClbDoc, key: string, v: int) -> void:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            it.vtype = "bool"
            it.v_bool = v
            it.v_str = str(v)
            return
        i = i + 1
    item := ClbItem(key, "bool", str(v), v, 0.0, v)
    doc.items.push(item)

fn clb_get_bool(doc: ClbDoc, key: string, default_v: int) -> int:
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        if it.key == key:
            if it.vtype == "bool":
                return it.v_bool
            if it.v_str == "1" or it.v_str == "true":
                return 1
            return 0
        i = i + 1
    return default_v

fn clb_count(doc: ClbDoc) -> int:
    return len(doc.items)

fn clb_save(filepath: string, doc: ClbDoc) -> int:
    let mut out: string = "CLB/1.0\nCOUNT|" + str(len(doc.items)) + "\n===\n"
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        out = out + it.vtype + "|" + it.key + "|" + it.v_str + "\n"
        i = i + 1
    return file_write(filepath, out)

fn clb_load(filepath: string) -> ClbDoc:
    doc := clb_new()
    if file_exists(filepath) == 0:
        return doc
    raw := file_read(filepath)
    if len(raw) == 0:
        return doc
        
    let mut in_data: int = 0
    let mut line: string = ""
    let mut i: int = 0
    while i < len(raw):
        ch := char_at(raw, i)
        if ch == "\n":
            if line == "===" or line == "---":
                in_data = 1
            elif in_data == 1 and len(line) > 0:
                p1 := -1
                p2 := -1
                let mut j: int = 0
                while j < len(line):
                    if char_at(line, j) == "|":
                        if p1 < 0:
                            p1 = j
                        elif p2 < 0:
                            p2 = j
                            break
                    j = j + 1
                if p1 > 0 and p2 > p1:
                    vtype := substring(line, 0, p1)
                    k := substring(line, p1 + 1, p2 - (p1 + 1))
                    v := substring(line, p2 + 1, len(line) - (p2 + 1))
                    if vtype == "int":
                        clb_set_int(doc, k, to_int(v))
                    elif vtype == "float":
                        clb_set_float(doc, k, to_float(v))
                    elif vtype == "bool":
                        clb_set_bool(doc, k, to_int(v))
                    else:
                        clb_set_string(doc, k, v)
            line = ""
        else:
            line = line + ch
        i = i + 1
    return doc

fn clb_to_json(doc: ClbDoc) -> string:
    let mut res: string = "{\n"
    let mut i: int = 0
    while i < len(doc.items):
        let it: ClbItem = doc.items[i]
        res = res + "  \"" + it.key + "\": "
        if it.vtype == "string":
            res = res + "\"" + it.v_str + "\""
        elif it.vtype == "bool":
            if it.v_bool == 1:
                res = res + "true"
            else:
                res = res + "false"
        else:
            res = res + it.v_str
        if i < len(doc.items) - 1:
            res = res + ","
        res = res + "\n"
        i = i + 1
    res = res + "}\n"
    return res
