// Cluster Standard Library: Binary Packing, File Byte Buffers & IEEE-754 Codecs (std/binpack)
// Replaces Python struct / mmap / IEEE-754 fp16 & bf16 conversions in pure Cluster.

import "std/sysutil.cl"

model BinBuf:
    buf: ptr
    len: int
    cap: int

fn binbuf_new(init_cap: int) -> BinBuf:
    c := init_cap
    if c < 256:
        c = 256
    return BinBuf(mem_alloc(c), 0, c)

fn binbuf_free(&b: BinBuf):
    if b.buf != null:
        mem_free(b.buf)
        b.buf = null
    b.len = 0
    b.cap = 0

fn binbuf_ensure(&b: BinBuf, need: int):
    req := b.len + need
    if req <= b.cap:
        return
    ncap := b.cap
    if ncap < 256:
        ncap = 256
    while ncap < req:
        ncap = ncap * 2
    nbuf := mem_realloc(b.buf, ncap)
    if nbuf != null:
        b.buf = nbuf
        b.cap = ncap

fn binbuf_from_file(path: string) -> BinBuf:
    fd := sys_posix_open_ro(path)
    if fd < 0:
        return BinBuf(null, 0, 0)
    sz := sys_posix_lseek(fd, 0, 2)
    sys_posix_lseek(fd, 0, 0)
    if sz <= 0:
        sys_posix_close(fd)
        return BinBuf(mem_alloc(16), 0, 16)
    p := mem_alloc(sz + 8)
    off := 0
    while off < sz:
        n := sys_posix_read(fd, ptr_add(p, off), sz - off)
        if n <= 0:
            break
        off = off + n
    sys_posix_close(fd)
    return BinBuf(p, off, sz + 8)

fn binbuf_write_file(&b: BinBuf, path: string) -> int:
    if b.buf == null:
        return -1
    fd := sys_posix_open_wo_trunc(path)
    if fd < 0:
        return -1
    written := 0
    while written < b.len:
        n := sys_posix_write(fd, ptr_add(b.buf, written), b.len - written)
        if n <= 0:
            sys_posix_close(fd)
            return -1
        written = written + n
    sys_posix_close(fd)
    return 0

fn binbuf_push_u8(&b: BinBuf, v: int):
    binbuf_ensure(b, 1)
    ptr_write_u8(ptr_add(b.buf, b.len), v & 255)
    b.len = b.len + 1

fn binbuf_push_i8(&b: BinBuf, v: int):
    binbuf_push_u8(b, v & 255)

fn binbuf_push_u16_le(&b: BinBuf, v: int):
    binbuf_ensure(b, 2)
    ptr_write_u8(ptr_add(b.buf, b.len), v & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 1), (v >> 8) & 255)
    b.len = b.len + 2

fn binbuf_push_u32_le(&b: BinBuf, v: int):
    binbuf_ensure(b, 4)
    ptr_write_u8(ptr_add(b.buf, b.len), v & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 1), (v >> 8) & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 2), (v >> 16) & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 3), (v >> 24) & 255)
    b.len = b.len + 4

fn binbuf_push_u32_be(&b: BinBuf, v: int):
    binbuf_ensure(b, 4)
    ptr_write_u8(ptr_add(b.buf, b.len), (v >> 24) & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 1), (v >> 16) & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 2), (v >> 8) & 255)
    ptr_write_u8(ptr_add(b.buf, b.len + 3), v & 255)
    b.len = b.len + 4

fn binbuf_push_u64_le(&b: BinBuf, v: int):
    binbuf_push_u32_le(b, v & 4294967295)
    binbuf_push_u32_le(b, (v >> 32) & 4294967295)

fn binbuf_push_str(&b: BinBuf, s: string):
    n := string_length(s)
    if n <= 0:
        return
    binbuf_ensure(b, n)
    mem_copy(ptr_add(b.buf, b.len), str_cstr(s), n)
    b.len = b.len + n

fn binbuf_push_raw(&b: BinBuf, src: ptr, n: int):
    if n <= 0 or src == null:
        return
    binbuf_ensure(b, n)
    mem_copy(ptr_add(b.buf, b.len), src, n)
    b.len = b.len + n

fn binbuf_push_zeros(&b: BinBuf, n: int):
    if n <= 0:
        return
    binbuf_ensure(b, n)
    mem_set(ptr_add(b.buf, b.len), 0, n)
    b.len = b.len + n

fn binbuf_align(&b: BinBuf, align: int):
    rem := b.len % align
    if rem != 0:
        binbuf_push_zeros(b, align - rem)

fn bin_f32_to_bits(x: float) -> int:
    scratch := mem_alloc(8)
    ptr_write_f32(scratch, x)
    b0 := ptr_read_u8(scratch)
    b1 := ptr_read_u8(ptr_add(scratch, 1))
    b2 := ptr_read_u8(ptr_add(scratch, 2))
    b3 := ptr_read_u8(ptr_add(scratch, 3))
    mem_free(scratch)
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

fn bin_bits_to_f32(bits: int) -> float:
    scratch := mem_alloc(8)
    ptr_write_u8(scratch, bits & 255)
    ptr_write_u8(ptr_add(scratch, 1), (bits >> 8) & 255)
    ptr_write_u8(ptr_add(scratch, 2), (bits >> 16) & 255)
    ptr_write_u8(ptr_add(scratch, 3), (bits >> 24) & 255)
    v := ptr_read_f32(scratch)
    mem_free(scratch)
    return v

fn bin_f16_bits_to_f32(h: int) -> float:
    sign := (h >> 15) & 1
    exp := (h >> 10) & 31
    mant := h & 1023
    fbits := 0
    if exp == 0:
        if mant == 0:
            fbits = sign << 31
        else:
            e := 113
            m := mant
            while (m & 1024) == 0:
                m = m << 1
                e = e - 1
            m = m & 1023
            fbits = (sign << 31) | (e << 23) | (m << 13)
    elif exp == 31:
        fbits = (sign << 31) | (255 << 23) | (mant << 13)
    else:
        e32 := exp + 112
        fbits = (sign << 31) | (e32 << 23) | (mant << 13)
    return bin_bits_to_f32(fbits)

fn bin_f32_to_f16_bits(x: float) -> int:
    b := bin_f32_to_bits(x)
    sign := (b >> 16) & 32768
    exp := (b >> 23) & 255
    mant := b & 8388607
    if exp == 255:
        if mant != 0:
            return sign | 31744 | 512
        return sign | 31744
    new_exp := exp - 112
    if new_exp <= 0:
        if new_exp < -10:
            return sign
        m := (mant | 8388608) >> (1 - new_exp)
        round_bit := (m >> 12) & 1
        return sign | ((m >> 13) + round_bit)
    if new_exp >= 31:
        return sign | 31744
    m16 := (mant + 4096) >> 13
    if m16 == 1024:
        m16 = 0
        new_exp = new_exp + 1
    if new_exp >= 31:
        return sign | 31744
    return sign | (new_exp << 10) | m16

fn bin_bf16_bits_to_f32(h: int) -> float:
    return bin_bits_to_f32((h & 65535) << 16)

fn binbuf_push_f32_le(&b: BinBuf, x: float):
    binbuf_push_u32_le(b, bin_f32_to_bits(x))

fn binbuf_push_f16_le(&b: BinBuf, x: float):
    binbuf_push_u16_le(b, bin_f32_to_f16_bits(x))

fn bin_read_u8(p: ptr, off: int) -> int:
    return ptr_read_u8(ptr_add(p, off))

fn bin_read_i8(p: ptr, off: int) -> int:
    v := ptr_read_u8(ptr_add(p, off))
    if v >= 128:
        return v - 256
    return v

fn bin_read_u16_le(p: ptr, off: int) -> int:
    b0 := ptr_read_u8(ptr_add(p, off))
    b1 := ptr_read_u8(ptr_add(p, off + 1))
    return b0 | (b1 << 8)

fn bin_read_u32_le(p: ptr, off: int) -> int:
    b0 := ptr_read_u8(ptr_add(p, off))
    b1 := ptr_read_u8(ptr_add(p, off + 1))
    b2 := ptr_read_u8(ptr_add(p, off + 2))
    b3 := ptr_read_u8(ptr_add(p, off + 3))
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

fn bin_read_i32_le(p: ptr, off: int) -> int:
    v := bin_read_u32_le(p, off)
    if v >= 2147483648:
        return v - 4294967296
    return v

fn bin_read_u64_le(p: ptr, off: int) -> int:
    lo := bin_read_u32_le(p, off)
    hi := bin_read_u32_le(p, off + 4)
    return lo | (hi << 32)

fn bin_read_f32_le(p: ptr, off: int) -> float:
    return bin_bits_to_f32(bin_read_u32_le(p, off))

fn bin_read_f16_le(p: ptr, off: int) -> float:
    return bin_f16_bits_to_f32(bin_read_u16_le(p, off))

fn bin_read_bf16_le(p: ptr, off: int) -> float:
    return bin_bf16_bits_to_f32(bin_read_u16_le(p, off))

fn bin_read_f64_le(p: ptr, off: int) -> float:
    return ptr_read_f64(ptr_add(p, off))

fn bin_read_str(p: ptr, off: int, slen: int) -> string:
    if slen <= 0:
        return ""
    return str_from_parts(ptr_add(p, off), slen)

fn bin_hex_to_bytes(hex_s: string) -> vector[int]:
    out := vector[int]()
    n := string_length(hex_s)
    hi := -1
    i := 0
    while i < n:
        c := byte_at(hex_s, i)
        nib := -1
        if c >= 48 and c <= 57:
            nib = c - 48
        elif c >= 97 and c <= 102:
            nib = c - 87
        elif c >= 65 and c <= 70:
            nib = c - 55
        if nib >= 0:
            if hi < 0:
                hi = nib
            else:
                list_push(out, (hi << 4) | nib)
                hi = -1
        i = i + 1
    return out

fn bin_bytes_to_hex(bs: vector[int], spaced: int) -> string:
    hex_chars := "0123456789abcdef"
    out := ""
    n := list_size(bs)
    i := 0
    while i < n:
        b := bs[(i)] & 255
        if spaced == 1 and i > 0:
            out = out + " "
        out = out + char_at(hex_chars, (b >> 4) & 15) + char_at(hex_chars, b & 15)
        i = i + 1
    return out

fn bin_fmt_spaced_hex(hex_s: string) -> string:
    return bin_bytes_to_hex(bin_hex_to_bytes(hex_s), 1)
