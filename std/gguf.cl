// Cluster Standard Library: GGUF v2/v3 Binary Reader (std/gguf)
// Pure Cluster parser replacing Python gguf.GGUFReader for bare-metal model packing.

import "std/binpack.cl"

model GgufTensor:
    name: string
    n_dims: int
    d0: int
    d1: int
    d2: int
    d3: int
    dtype_id: int
    dtype_name: string
    rel_offset: int
    file_offset: int
    n_elements: int
    n_bytes: int

model GgufFile:
    buf: BinBuf
    version: int
    tensor_count: int
    kv_count: int
    data_offset: int
    kv_int: dict[string, int]
    kv_float: dict[string, float]
    kv_str: dict[string, string]
    tensors: vector[GgufTensor]
    tensor_idx: dict[string, int]

fn gguf_dtype_name(dt: int) -> string:
    if dt == 0: return "F32"
    if dt == 1: return "F16"
    if dt == 2: return "Q4_0"
    if dt == 3: return "Q4_1"
    if dt == 6: return "Q5_0"
    if dt == 7: return "Q5_1"
    if dt == 8: return "Q8_0"
    if dt == 12: return "Q4_K"
    if dt == 13: return "Q5_K"
    if dt == 14: return "Q6_K"
    return "UNKNOWN_" + to_text(dt)

fn gguf_calc_nbytes(dt: int, nelems: int) -> int:
    if dt == 0: return nelems * 4
    if dt == 1: return nelems * 2
    if dt == 2: return (nelems / 32) * 18
    if dt == 8: return (nelems / 32) * 34
    if dt == 12: return (nelems / 256) * 144
    if dt == 14: return (nelems / 256) * 210
    return nelems

fn _gguf_skip_val(p: ptr, off: int, vtype: int) -> int:
    if vtype == 0 or vtype == 1 or vtype == 7:
        return off + 1
    if vtype == 2 or vtype == 3:
        return off + 2
    if vtype == 4 or vtype == 5 or vtype == 6:
        return off + 4
    if vtype == 10 or vtype == 11 or vtype == 12:
        return off + 8
    if vtype == 8:
        slen := bin_read_u64_le(p, off)
        return off + 8 + slen
    if vtype == 9:
        et := bin_read_u32_le(p, off)
        cnt := bin_read_u64_le(p, off + 4)
        cur := off + 12
        i := 0
        while i < cnt:
            cur = _gguf_skip_val(p, cur, et)
            i = i + 1
        return cur
    return off

fn gguf_open(path: string) -> GgufFile:
    b := binbuf_from_file(path)
    kvi := dict[string, int]()
    kvf := dict[string, float]()
    kvs := dict[string, string]()
    ts := vector[GgufTensor]()
    tidx := dict[string, int]()
    if b.buf == null or b.len < 24:
        return GgufFile(b, 0, 0, 0, 0, kvi, kvf, kvs, ts, tidx)
    p := b.buf
    magic := bin_read_u32_le(p, 0)
    // "GGUF" LE = 0x46554747 = 1179993927
    if magic != 1179993927:
        return GgufFile(b, 0, 0, 0, 0, kvi, kvf, kvs, ts, tidx)
    ver := bin_read_u32_le(p, 4)
    tc := bin_read_u64_le(p, 8)
    kvc := bin_read_u64_le(p, 16)
    cur := 24
    i := 0
    while i < kvc and cur + 12 < b.len:
        klen := bin_read_u64_le(p, cur)
        key := bin_read_str(p, cur + 8, klen)
        cur = cur + 8 + klen
        vt := bin_read_u32_le(p, cur)
        cur = cur + 4
        if vt == 4 or vt == 5:
            kvi[key] = bin_read_u32_le(p, cur)
        elif vt == 10 or vt == 11:
            kvi[key] = bin_read_u64_le(p, cur)
        elif vt == 6:
            kvf[key] = bin_read_f32_le(p, cur)
        elif vt == 12:
            kvf[key] = bin_read_f64_le(p, cur)
        elif vt == 8:
            slen := bin_read_u64_le(p, cur)
            kvs[key] = bin_read_str(p, cur + 8, slen)
        elif vt == 7:
            kvi[key] = bin_read_u8(p, cur)
        cur = _gguf_skip_val(p, cur, vt)
        i = i + 1

    ti := 0
    while ti < tc and cur + 16 < b.len:
        nlen := bin_read_u64_le(p, cur)
        tname := bin_read_str(p, cur + 8, nlen)
        cur = cur + 8 + nlen
        nd := bin_read_u32_le(p, cur)
        cur = cur + 4
        d0 := 1
        d1 := 1
        d2 := 1
        d3 := 1
        ne := 1
        di := 0
        while di < nd:
            dv := bin_read_u64_le(p, cur)
            cur = cur + 8
            ne = ne * dv
            if di == 0: d0 = dv
            elif di == 1: d1 = dv
            elif di == 2: d2 = dv
            elif di == 3: d3 = dv
            di = di + 1
        dt := bin_read_u32_le(p, cur)
        ro := bin_read_u64_le(p, cur + 4)
        cur = cur + 12
        nb := gguf_calc_nbytes(dt, ne)
        gt := GgufTensor(tname, nd, d0, d1, d2, d3, dt, gguf_dtype_name(dt), ro, 0, ne, nb)
        tidx[tname] = list_size(ts)
        list_push(ts, gt)
        ti = ti + 1

    align := 32
    if kvi.has("general.alignment"):
        av := kvi["general.alignment"]
        if av > 0:
            align = av
    rem := cur % align
    if rem != 0:
        cur = cur + (align - rem)
    data_off := cur
    tj := 0
    while tj < list_size(ts):
        ts[(tj)].file_offset = data_off + ts[(tj)].rel_offset
        tj = tj + 1

    return GgufFile(b, ver, tc, kvc, data_off, kvi, kvf, kvs, ts, tidx)

fn gguf_close(&g: GgufFile):
    binbuf_free(g.buf)

fn gguf_get_int(g: GgufFile, key: string, dflt: int) -> int:
    if g.kv_int.has(key):
        return g.kv_int[key]
    return dflt

fn gguf_get_float(g: GgufFile, key: string, dflt: float) -> float:
    if g.kv_float.has(key):
        return g.kv_float[key]
    return dflt

fn gguf_get_str(g: GgufFile, key: string, dflt: string) -> string:
    if g.kv_str.has(key):
        return g.kv_str[key]
    return dflt

fn gguf_has_tensor(g: GgufFile, name: string) -> int:
    if g.tensor_idx.has(name):
        return 1
    return 0

fn gguf_get_tensor(g: GgufFile, name: string) -> GgufTensor:
    idx := g.tensor_idx[name]
    return g.tensors[(idx)]
