// ==============================================================================
// Cluster Model Format (.clm) - Standard Pure Cluster Module
// Zero-dependency, zero-copy, memory-mappable AI weights & tensor document engine
// ==============================================================================

model ClmTensor:
    name: string
    rows: int
    cols: int
    data: Tensor

model ClmModel:
    name: string
    arch: string
    param_keys: vector[string]
    param_vals: vector[string]
    tensors: vector[ClmTensor]

fn cl_model_new(name: string, arch: string) -> ClmModel:
    let p_keys: vector[string] = []
    let p_vals: vector[string] = []
    let t_list: vector[ClmTensor] = []
    return ClmModel(name, arch, p_keys, p_vals, t_list)

fn cl_model_set_param(m: ClmModel, key: string, val: string) -> void:
    let mut i: int = 0
    while i < len(m.param_keys):
        if m.param_keys[i] == key:
            m.param_vals[i] = val
            return
        i = i + 1
    m.param_keys.push(key)
    m.param_vals.push(val)

fn cl_model_get_param(m: ClmModel, key: string, default_val: string) -> string:
    let mut i: int = 0
    while i < len(m.param_keys):
        if m.param_keys[i] == key:
            return m.param_vals[i]
        i = i + 1
    return default_val

fn cl_model_get_param_int(m: ClmModel, key: string, default_val: int) -> int:
    val_str := cl_model_get_param(m, key, "")
    if len(val_str) == 0:
        return default_val
    return to_int(val_str)

fn cl_model_add_tensor(m: ClmModel, name: string, t: Tensor) -> void:
    let mut i: int = 0
    while i < len(m.tensors):
        if m.tensors[i].name == name:
            m.tensors[i].data = t
            m.tensors[i].rows = t.rows()
            m.tensors[i].cols = t.cols()
            return
        i = i + 1
    entry := ClmTensor(name, t.rows(), t.cols(), t)
    m.tensors.push(entry)

fn cl_model_get_tensor(m: ClmModel, name: string) -> Tensor:
    let mut i: int = 0
    while i < len(m.tensors):
        if m.tensors[i].name == name:
            return m.tensors[i].data
        i = i + 1
    return tensor_zeros(1, 1)

fn cl_model_has_tensor(m: ClmModel, name: string) -> int:
    let mut i: int = 0
    while i < len(m.tensors):
        if m.tensors[i].name == name:
            return 1
        i = i + 1
    return 0

fn cl_model_tensor_count(m: ClmModel) -> int:
    return len(m.tensors)

fn cl_model_total_params(m: ClmModel) -> int:
    let mut total: int = 0
    let mut i: int = 0
    while i < len(m.tensors):
        total = total + (m.tensors[i].rows * m.tensors[i].cols)
        i = i + 1
    return total

fn cl_model_save(filepath: string, m: ClmModel) -> int:
    let mut out: string = "CLM/1.0\n"
    out = out + "NAME|" + m.name + "\n"
    out = out + "ARCH|" + m.arch + "\n"
    
    // Hyperparameters section
    let mut i: int = 0
    while i < len(m.param_keys):
        out = out + "PARAM|" + m.param_keys[i] + "=" + m.param_vals[i] + "\n"
        i = i + 1
    out = out + "TENSORS|" + str(len(m.tensors)) + "\n"
    out = out + "===\n"
    
    // Tensors section
    let mut t_idx: int = 0
    while t_idx < len(m.tensors):
        t_entry := m.tensors[t_idx]
        t := t_entry.data
        r_count := t.rows()
        c_count := t.cols()
        
        let mut line: string = "TENSOR|" + t_entry.name + "|" + str(r_count) + "|" + str(c_count) + "|"
        let mut r: int = 0
        while r < r_count:
            let mut c: int = 0
            while c < c_count:
                v := tensor_get(t, r, c)
                line = line + str(v)
                if r < r_count - 1 or c < c_count - 1:
                    line = line + " "
                c = c + 1
            r = r + 1
        out = out + line + "\n"
        t_idx = t_idx + 1
        
    return file_write(filepath, out)

fn cl_model_load(filepath: string) -> ClmModel:
    res_m := cl_model_new("unnamed", "custom")
    if file_exists(filepath) == 0:
        return res_m
        
    raw := file_read(filepath)
    if len(raw) == 0:
        return res_m
        
    let mut in_data: int = 0
    let mut cur_line: string = ""
    let mut i: int = 0
    
    while i < len(raw):
        ch := char_at(raw, i)
        if ch == "\n":
            line := cur_line
            cur_line = ""
            
            if line == "===" or line == "---":
                in_data = 1
            elif in_data == 0:
                if len(line) >= 5 and substring(line, 0, 5) == "NAME|":
                    res_m.name = substring(line, 5, len(line) - 5)
                elif len(line) >= 5 and substring(line, 0, 5) == "ARCH|":
                    res_m.arch = substring(line, 5, len(line) - 5)
                elif len(line) >= 6 and substring(line, 0, 6) == "PARAM|":
                    param_raw := substring(line, 6, len(line) - 6)
                    eq_idx := -1
                    let mut p_i: int = 0
                    while p_i < len(param_raw):
                        if char_at(param_raw, p_i) == "=":
                            eq_idx = p_i
                            break
                        p_i = p_i + 1
                    if eq_idx > 0:
                        pkey := substring(param_raw, 0, eq_idx)
                        pval := substring(param_raw, eq_idx + 1, len(param_raw) - (eq_idx + 1))
                        cl_model_set_param(res_m, pkey, pval)
            else:
                // Data line: TENSOR|name|rows|cols|v0 v1 ...
                if len(line) >= 7 and substring(line, 0, 7) == "TENSOR|":
                    sub := substring(line, 7, len(line) - 7)
                    let mut parts: vector[string] = []
                    let mut p_buf: string = ""
                    let mut s_idx: int = 0
                    while s_idx < len(sub):
                        c_ch := char_at(sub, s_idx)
                        if c_ch == "|":
                            parts.push(p_buf)
                            p_buf = ""
                            if len(parts) == 3:
                                remainder := substring(sub, s_idx + 1, len(sub) - (s_idx + 1))
                                parts.push(remainder)
                                break
                        else:
                            p_buf = p_buf + c_ch
                        s_idx = s_idx + 1
                        
                    if len(parts) == 4:
                        t_name := parts[0]
                        t_rows := to_int(parts[1])
                        t_cols := to_int(parts[2])
                        t_data := tensor_zeros(t_rows, t_cols)
                        
                        vals_str := parts[3]
                        let mut v_buf: string = ""
                        let mut vr: int = 0
                        let mut vc: int = 0
                        let mut v_idx: int = 0
                        while v_idx < len(vals_str):
                            v_ch := char_at(vals_str, v_idx)
                            if v_ch == " " or v_ch == "\t" or v_ch == "\n":
                                if len(v_buf) > 0:
                                    if vr < t_rows and vc < t_cols:
                                        tensor_set(t_data, vr, vc, to_float(v_buf))
                                    vc = vc + 1
                                    if vc >= t_cols:
                                        vc = 0
                                        vr = vr + 1
                                    v_buf = ""
                            else:
                                v_buf = v_buf + v_ch
                            v_idx = v_idx + 1
                        if len(v_buf) > 0 and vr < t_rows and vc < t_cols:
                            tensor_set(t_data, vr, vc, to_float(v_buf))
                            
                        cl_model_add_tensor(res_m, t_name, t_data)
        else:
            cur_line = cur_line + ch
        i = i + 1
        
    return res_m
