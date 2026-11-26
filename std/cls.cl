// ==============================================================================
// Cluster Schema & Contract (.cls) - Standard Pure Cluster Module
// Declarative type safety, runtime contract validation, and API schema engine
// ==============================================================================

import "std/clb.cl"

model ClsFieldRule:
    name: string
    ftype: string
    required: int
    min_val: int
    max_val: int
    min_len: int
    max_len: int
    must_contain: string
    enums: vector[string]

model ClsSchema:
    name: string
    fields: vector[ClsFieldRule]
    errors: vector[string]

fn cls_new(name: string) -> ClsSchema:
    let f_list: vector[ClsFieldRule] = []
    let err_list: vector[string] = []
    return ClsSchema(name, f_list, err_list)

fn cls_add_int(s: ClsSchema, name: string, req: int, min_v: int, max_v: int) -> void:
    let empty_enums: vector[string] = []
    rule := ClsFieldRule(name, "int", req, min_v, max_v, 0, 0, "", empty_enums)
    s.fields.push(rule)

fn cls_add_string(s: ClsSchema, name: string, req: int, min_l: int, max_l: int, must_have: string) -> void:
    let empty_enums: vector[string] = []
    rule := ClsFieldRule(name, "string", req, 0, 0, min_l, max_l, must_have, empty_enums)
    s.fields.push(rule)

fn cls_add_float(s: ClsSchema, name: string, req: int) -> void:
    let empty_enums: vector[string] = []
    rule := ClsFieldRule(name, "float", req, 0, 0, 0, 0, "", empty_enums)
    s.fields.push(rule)

fn cls_add_bool(s: ClsSchema, name: string, req: int) -> void:
    let empty_enums: vector[string] = []
    rule := ClsFieldRule(name, "bool", req, 0, 0, 0, 0, "", empty_enums)
    s.fields.push(rule)

fn cls_add_enum(s: ClsSchema, name: string, req: int, options: vector[string]) -> void:
    rule := ClsFieldRule(name, "enum", req, 0, 0, 0, 0, "", options)
    s.fields.push(rule)

fn cls_clear_errors(s: ClsSchema) -> void:
    let fresh: vector[string] = []
    s.errors = fresh

fn cls_validate(s: ClsSchema, doc: ClbDoc) -> int:
    cls_clear_errors(s)
    let mut is_valid: int = 1
    let mut i: int = 0
    while i < len(s.fields):
        let f: ClsFieldRule = s.fields[i]
        has_field := clb_has(doc, f.name)
        
        // 1. Required check
        if f.required == 1 and has_field == 0:
            s.errors.push("validation error: missing required field '" + f.name + "'")
            is_valid = 0
        elif has_field == 1:
            // 2. Type and bounds checks
            if f.ftype == "int":
                v_int := clb_get_int(doc, f.name, 0)
                if f.min_val != f.max_val:
                    if v_int < f.min_val:
                        s.errors.push("field '" + f.name + "' value " + str(v_int) + " is less than min " + str(f.min_val))
                        is_valid = 0
                    if v_int > f.max_val:
                        s.errors.push("field '" + f.name + "' value " + str(v_int) + " exceeds max " + str(f.max_val))
                        is_valid = 0
            elif f.ftype == "string":
                v_str := clb_get_string(doc, f.name, "")
                str_l := len(v_str)
                if f.min_len > 0 and str_l < f.min_len:
                    s.errors.push("field '" + f.name + "' length " + str(str_l) + " is shorter than min_len " + str(f.min_len))
                    is_valid = 0
                if f.max_len > 0 and str_l > f.max_len:
                    s.errors.push("field '" + f.name + "' length " + str(str_l) + " exceeds max_len " + str(f.max_len))
                    is_valid = 0
                if len(f.must_contain) > 0:
                    if string_contains(v_str, f.must_contain) == 0:
                        s.errors.push("field '" + f.name + "' missing required substring '" + f.must_contain + "'")
                        is_valid = 0
            elif f.ftype == "enum":
                v_str := clb_get_string(doc, f.name, "")
                let mut is_matched: int = 0
                let mut opt_idx: int = 0
                while opt_idx < len(f.enums):
                    if f.enums[opt_idx] == v_str:
                        is_matched = 1
                        break
                    opt_idx = opt_idx + 1
                if is_matched == 0:
                    s.errors.push("field '" + f.name + "' has invalid enum value '" + v_str + "'")
                    is_valid = 0
        i = i + 1
        
    return is_valid

fn cls_get_errors(s: ClsSchema) -> string:
    let mut out: string = ""
    let mut i: int = 0
    while i < len(s.errors):
        out = out + "- " + s.errors[i] + "\n"
        i = i + 1
    return out

fn cls_save(filepath: string, s: ClsSchema) -> int:
    let mut out: string = "CLS/1.0\nSCHEMA|" + s.name + "\n===\n"
    let mut i: int = 0
    while i < len(s.fields):
        let f: ClsFieldRule = s.fields[i]
        let mut enum_str: string = ""
        let mut e_i: int = 0
        while e_i < len(f.enums):
            enum_str = enum_str + f.enums[e_i]
            if e_i < len(f.enums) - 1:
                enum_str = enum_str + ","
            e_i = e_i + 1
            
        line := "FIELD|" + f.name + "|" + f.ftype + "|" + str(f.required) + "|" + str(f.min_val) + "|" + str(f.max_val) + "|" + str(f.min_len) + "|" + str(f.max_len) + "|" + f.must_contain + "|" + enum_str
        out = out + line + "\n"
        i = i + 1
    return file_write(filepath, out)

fn cls_load(filepath: string) -> ClsSchema:
    s := cls_new("unnamed")
    if file_exists(filepath) == 0:
        return s
    raw := file_read(filepath)
    if len(raw) == 0:
        return s
        
    let mut in_data: int = 0
    let mut line: string = ""
    let mut i: int = 0
    while i < len(raw):
        ch := char_at(raw, i)
        if ch == "\n":
            if line == "===" or line == "---":
                in_data = 1
            elif in_data == 0:
                if len(line) >= 7 and substring(line, 0, 7) == "SCHEMA|":
                    s.name = substring(line, 7, len(line) - 7)
            else:
                if len(line) >= 6 and substring(line, 0, 6) == "FIELD|":
                    sub := substring(line, 6, len(line) - 6)
                    let mut parts: vector[string] = []
                    let mut p_buf: string = ""
                    let mut j: int = 0
                    while j < len(sub):
                        c := char_at(sub, j)
                        if c == "|":
                            parts.push(p_buf)
                            p_buf = ""
                        else:
                            p_buf = p_buf + c
                        j = j + 1
                    parts.push(p_buf)
                    
                    if len(parts) >= 9:
                        f_name := parts[0]
                        f_type := parts[1]
                        f_req := to_int(parts[2])
                        min_v := to_int(parts[3])
                        max_v := to_int(parts[4])
                        min_l := to_int(parts[5])
                        max_l := to_int(parts[6])
                        must_c := parts[7]
                        
                        let mut enums: vector[string] = []
                        enum_raw := parts[8]
                        if len(enum_raw) > 0:
                            let mut e_buf: string = ""
                            let mut k: int = 0
                            while k < len(enum_raw):
                                ec := char_at(enum_raw, k)
                                if ec == ",":
                                    enums.push(e_buf)
                                    e_buf = ""
                                else:
                                    e_buf = e_buf + ec
                                k = k + 1
                            if len(e_buf) > 0:
                                enums.push(e_buf)
                                
                        rule := ClsFieldRule(f_name, f_type, f_req, min_v, max_v, min_l, max_l, must_c, enums)
                        s.fields.push(rule)
            line = ""
        else:
            line = line + ch
        i = i + 1
    return s
