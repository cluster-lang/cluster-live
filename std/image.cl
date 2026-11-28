// Cluster Standard Library: PPM (P6) to PNG Encoder (std/image)
// Replaces Pillow Image.open(ppm).save(png) with zero external library dependency.

import "std/binpack.cl"

model RgbImage:
    width: int
    height: int
    pixels: ptr
    n_bytes: int

fn _img_crc32(p: ptr, length: int) -> int:
    crc := 4294967295
    i := 0
    while i < length:
        b := ptr_read_u8(ptr_add(p, i))
        crc = (crc ^ b) & 4294967295
        bit := 0
        while bit < 8:
            if (crc & 1) == 1:
                // IEEE 802.3 reflected poly 0xEDB88320 = 3988292384
                crc = ((crc >> 1) & 2147483647) ^ 3988292384
            else:
                crc = (crc >> 1) & 2147483647
            bit = bit + 1
        i = i + 1
    return (crc ^ 4294967295) & 4294967295

fn _img_adler32(p: ptr, length: int) -> int:
    s1 := 1
    s2 := 0
    i := 0
    while i < length:
        s1 = (s1 + ptr_read_u8(ptr_add(p, i))) % 65521
        s2 = (s2 + s1) % 65521
        i = i + 1
    return ((s2 << 16) | s1) & 4294967295

fn _png_push_chunk(&out: BinBuf, ctype: string, data_ptr: ptr, data_len: int):
    binbuf_push_u32_be(out, data_len)
    cbuf := binbuf_new(data_len + 8)
    binbuf_push_str(cbuf, ctype)
    if data_len > 0 and data_ptr != null:
        binbuf_push_raw(cbuf, data_ptr, data_len)
    crc := _img_crc32(cbuf.buf, cbuf.len)
    binbuf_push_raw(out, cbuf.buf, cbuf.len)
    binbuf_push_u32_be(out, crc)
    binbuf_free(cbuf)

fn image_read_ppm(path: string) -> RgbImage:
    b := binbuf_from_file(path)
    if b.buf == null or b.len < 12:
        binbuf_free(b)
        return RgbImage(0, 0, null, 0)
    p := b.buf
    // Parse "P6\nW H\n255\n" skipping # comments
    if bin_read_u8(p, 0) != 80 or bin_read_u8(p, 1) != 54:
        binbuf_free(b)
        return RgbImage(0, 0, null, 0)
    pos := 2
    tokens := vector[int]()
    while pos < b.len and list_size(tokens) < 3:
        ch := bin_read_u8(p, pos)
        if ch == 35:
            while pos < b.len and bin_read_u8(p, pos) != 10:
                pos = pos + 1
            pos = pos + 1
        elif ch == 32 or ch == 10 or ch == 13 or ch == 9:
            pos = pos + 1
        else:
            val := 0
            while pos < b.len:
                d := bin_read_u8(p, pos)
                if d < 48 or d > 57:
                    break
                val = val * 10 + (d - 48)
                pos = pos + 1
            list_push(tokens, val)
    if pos < b.len:
        pos = pos + 1
    if list_size(tokens) < 3:
        binbuf_free(b)
        return RgbImage(0, 0, null, 0)
    w := tokens[(0)]
    h := tokens[(1)]
    need := w * h * 3
    if pos + need > b.len:
        need = b.len - pos
    px := mem_alloc(need + 4)
    mem_copy(px, ptr_add(p, pos), need)
    binbuf_free(b)
    return RgbImage(w, h, px, need)

fn image_free(&img: RgbImage):
    if img.pixels != null:
        mem_free(img.pixels)
        img.pixels = null
    img.width = 0
    img.height = 0
    img.n_bytes = 0

fn image_write_png_rgb(path: string, w: int, h: int, pixels: ptr) -> int:
    if w <= 0 or h <= 0 or pixels == null:
        return -1
    row_bytes := w * 3
    raw_len := h * (1 + row_bytes)
    raw := mem_alloc(raw_len + 8)
    y := 0
    while y < h:
        dst_row := ptr_add(raw, y * (1 + row_bytes))
        ptr_write_u8(dst_row, 0)
        mem_copy(ptr_add(dst_row, 1), ptr_add(pixels, y * row_bytes), row_bytes)
        y = y + 1

    zbuf := binbuf_new(raw_len + 256)
    // zlib header (CMF=0x78, FLG=0x01)
    binbuf_push_u8(zbuf, 120)
    binbuf_push_u8(zbuf, 1)
    off := 0
    while off < raw_len:
        blk := raw_len - off
        if blk > 65535:
            blk = 65535
        is_final := 0
        if off + blk == raw_len:
            is_final = 1
        binbuf_push_u8(zbuf, is_final)
        binbuf_push_u16_le(zbuf, blk)
        binbuf_push_u16_le(zbuf, blk ^ 65535)
        binbuf_push_raw(zbuf, ptr_add(raw, off), blk)
        off = off + blk
    adler := _img_adler32(raw, raw_len)
    binbuf_push_u32_be(zbuf, adler)
    mem_free(raw)

    png := binbuf_new(zbuf.len + 128)
    // PNG 8-byte signature
    binbuf_push_u8(png, 137)
    binbuf_push_u8(png, 80)
    binbuf_push_u8(png, 78)
    binbuf_push_u8(png, 71)
    binbuf_push_u8(png, 13)
    binbuf_push_u8(png, 10)
    binbuf_push_u8(png, 26)
    binbuf_push_u8(png, 10)

    ihdr := binbuf_new(16)
    binbuf_push_u32_be(ihdr, w)
    binbuf_push_u32_be(ihdr, h)
    binbuf_push_u8(ihdr, 8)
    binbuf_push_u8(ihdr, 2)
    binbuf_push_u8(ihdr, 0)
    binbuf_push_u8(ihdr, 0)
    binbuf_push_u8(ihdr, 0)
    _png_push_chunk(png, "IHDR", ihdr.buf, ihdr.len)
    binbuf_free(ihdr)

    _png_push_chunk(png, "IDAT", zbuf.buf, zbuf.len)
    binbuf_free(zbuf)
    _png_push_chunk(png, "IEND", null, 0)

    rc := binbuf_write_file(png, path)
    binbuf_free(png)
    return rc

fn image_ppm_to_png(ppm_path: string, png_path: string) -> int:
    img := image_read_ppm(ppm_path)
    if img.width <= 0 or img.height <= 0:
        image_free(img)
        return -1
    rc := image_write_png_rgb(png_path, img.width, img.height, img.pixels)
    image_free(img)
    return rc
