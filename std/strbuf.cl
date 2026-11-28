// Cluster Standard Library: Zero-Copy Arena StringBuilder (std/strbuf)
// Doubling byte buffer backed by C heap / arena allocation, avoiding O(N^2) concatenation.

model StrBuf:
    buf: ptr
    len: int
    cap: int

fn strbuf_new(init_cap: int) -> StrBuf:
    c := init_cap
    if c < 256:
        c = 256
    b := StrBuf()
    b.buf = mem_alloc(c)
    b.len = 0
    b.cap = c
    ptr_write_u8(b.buf, 0)
    return b

fn strbuf_ensure(&b: StrBuf, need: int):
    req := b.len + need + 1
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

fn strbuf_push(&b: StrBuf, s: string):
    slen := len(s)
    if slen <= 0:
        return
    strbuf_ensure(b, slen)
    src := str_cstr(s)
    mem_copy(ptr_add(b.buf, b.len), src, slen)
    b.len = b.len + slen
    ptr_write_u8(ptr_add(b.buf, b.len), 0)

fn strbuf_push_char(&b: StrBuf, ch: int):
    strbuf_ensure(b, 1)
    ptr_write_u8(ptr_add(b.buf, b.len), ch)
    b.len = b.len + 1
    ptr_write_u8(ptr_add(b.buf, b.len), 0)

fn strbuf_push_bytes(&b: StrBuf, src: ptr, n: int):
    if n <= 0 or src == null:
        return
    strbuf_ensure(b, n)
    mem_copy(ptr_add(b.buf, b.len), src, n)
    b.len = b.len + n
    ptr_write_u8(ptr_add(b.buf, b.len), 0)

fn strbuf_push_int(&b: StrBuf, v: int):
    strbuf_push(b, to_text(v))

fn strbuf_clear(&b: StrBuf):
    b.len = 0
    if b.buf != null:
        ptr_write_u8(b.buf, 0)

fn strbuf_finish(&b: StrBuf) -> string:
    if b.buf == null or b.len <= 0:
        return ""
    return str_from_parts(b.buf, b.len)

fn strbuf_write_file(&b: StrBuf, path: string) -> int:
    if b.buf == null:
        return file_write(path, "")
    s := str_from_parts(b.buf, b.len)
    return file_write(path, s)

fn strbuf_free(&b: StrBuf):
    if b.buf != null:
        mem_free(b.buf)
        b.buf = null
    b.len = 0
    b.cap = 0
