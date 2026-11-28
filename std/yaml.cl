// Cluster Standard Library: YAML Configuration Parser (std/yaml)
// Pure Cluster parser supporting nested mappings (key.subkey), inline lists, and block lists.

import "std/sysutil.cl"

model YamlDoc:
    kv: dict[string, string]
    lists: dict[string, vector[string]]

fn _yaml_strip_comment(line: string) -> string:
    in_sq := 0
    in_dq := 0
    n := string_length(line)
    i := 0
    while i < n:
        c := byte_at(line, i)
        if c == 34 and in_sq == 0:
            in_dq = 1 - in_dq
        elif c == 39 and in_dq == 0:
            in_sq = 1 - in_sq
        elif c == 35 and in_sq == 0 and in_dq == 0:
            if i == 0 or byte_at(line, i - 1) == 32 or byte_at(line, i - 1) == 9:
                return substring(line, 0, i)
        i = i + 1
    return line

fn _yaml_unquote(s: string) -> string:
    t := sys_str_trim(s)
    n := string_length(t)
    if n >= 2:
        first := byte_at(t, 0)
        last := byte_at(t, n - 1)
        if (first == 34 and last == 34) or (first == 39 and last == 39):
            return substring(t, 1, n - 2)
    return t

fn yaml_parse(src: string) -> YamlDoc:
    doc := YamlDoc(dict[string, string](), dict[string, vector[string]]())
    lines := sys_str_split_lines(src)
    ind_stack := vector[int]()
    key_stack := vector[string]()
    active_list_key := ""
    i := 0
    while i < list_size(lines):
        raw := _yaml_strip_comment(lines[(i)])
        trimmed := sys_str_trim(raw)
        if trimmed == "" or trimmed == "---":
            i = i + 1
            continue
        indent := 0
        while indent < string_length(raw) and byte_at(raw, indent) == 32:
            indent = indent + 1

        if sys_str_starts(trimmed, "- ") == 1 and active_list_key != "":
            item := _yaml_unquote(substring(trimmed, 2, string_length(trimmed) - 2))
            lst := doc.lists[active_list_key]
            list_push(lst, item)
            doc.lists[active_list_key] = lst
            i = i + 1
            continue

        while list_size(ind_stack) > 0:
            top_i := list_size(ind_stack) - 1
            if indent <= ind_stack[(top_i)]:
                list_pop(ind_stack)
                list_pop(key_stack)
            else:
                break

        col := sys_str_find_from(trimmed, ":", 0)
        if col < 0:
            i = i + 1
            continue
        k := sys_str_trim(substring(trimmed, 0, col))
        rest := sys_str_trim(substring(trimmed, col + 1, string_length(trimmed) - col - 1))

        full_key := k
        if list_size(key_stack) > 0:
            pref := ""
            j := 0
            while j < list_size(key_stack):
                if j > 0:
                    pref = pref + "."
                pref = pref + key_stack[(j)]
                j = j + 1
            full_key = pref + "." + k

        if rest == "":
            list_push(ind_stack, indent)
            list_push(key_stack, k)
            active_list_key = full_key
            if doc.lists.has(full_key) == 0:
                doc.lists[full_key] = vector[string]()
        elif sys_str_starts(rest, "[") == 1 and sys_str_ends(rest, "]") == 1:
            inner := substring(rest, 1, string_length(rest) - 2)
            parts := sys_str_split(inner, ",")
            arr := vector[string]()
            pi := 0
            while pi < list_size(parts):
                p := _yaml_unquote(parts[(pi)])
                if p != "":
                    list_push(arr, p)
                pi = pi + 1
            doc.lists[full_key] = arr
            doc.kv[full_key] = rest
            active_list_key = ""
        else:
            doc.kv[full_key] = _yaml_unquote(rest)
            active_list_key = ""
        i = i + 1
    return doc

fn yaml_load_file(path: string) -> YamlDoc:
    return yaml_parse(file_read(path))

fn yaml_has(doc: YamlDoc, key: string) -> int:
    if doc.kv.has(key):
        return 1
    return 0

fn yaml_get(doc: YamlDoc, key: string, dflt: string) -> string:
    if doc.kv.has(key):
        return doc.kv[key]
    return dflt

fn yaml_get_int(doc: YamlDoc, key: string, dflt: int) -> int:
    if doc.kv.has(key) == 0:
        return dflt
    return to_int(doc.kv[key])

fn yaml_get_float(doc: YamlDoc, key: string, dflt: float) -> float:
    if doc.kv.has(key) == 0:
        return dflt
    return to_float(doc.kv[key])

fn yaml_get_list(doc: YamlDoc, key: string) -> vector[string]:
    if doc.lists.has(key):
        return doc.lists[key]
    return vector[string]()
