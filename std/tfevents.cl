// Cluster Standard Library: TensorBoard TFRecord Event Writer (std/tfevents)
// Pure Cluster writer emitting native TFEvent protobuf records with Castagnoli CRC32C.

import "std/binpack.cl"

model TfEventWriter:
    fd: i32
    path: string

fn _tf_crc32c(p: ptr, length: int) -> int:
    crc := 4294967295
    i := 0
    while i < length:
        b := ptr_read_u8(ptr_add(p, i))
        crc = (crc ^ b) & 4294967295
        bit := 0
        while bit < 8:
            if (crc & 1) == 1:
                // Castagnoli reflected poly = 0x82F63B78 = 2197175160
                crc = ((crc >> 1) & 2147483647) ^ 2197175160
            else:
                crc = (crc >> 1) & 2147483647
            bit = bit + 1
        i = i + 1
    return (crc ^ 4294967295) & 4294967295

fn _tf_mask_crc(crc: int) -> int:
    rot := (((crc >> 15) & 131071) | ((crc << 17) & 4294967295)) & 4294967295
    // 0xa282ead8 = 2726488792
    return (rot + 2726488792) & 4294967295

fn _pb_push_varint(&b: BinBuf, val: int):
    v := val
    if v == 0:
        binbuf_push_u8(b, 0)
        return
    while v > 0:
        byte := v & 127
        v = (v >> 7) & 144115188075855871
        if v > 0:
            byte = byte | 128
        binbuf_push_u8(b, byte)

fn _pb_push_f64_le(&b: BinBuf, v: float):
    scratch := mem_alloc(8)
    ptr_write_f64(scratch, v)
    binbuf_push_raw(b, scratch, 8)
    mem_free(scratch)

fn _tf_write_record(fd: i32, &payload: BinBuf):
    hdr := binbuf_new(16)
    binbuf_push_u64_le(hdr, payload.len)
    lcrc := _tf_mask_crc(_tf_crc32c(hdr.buf, 8))
    binbuf_push_u32_le(hdr, lcrc)
    if fd >= 0:
        sys_posix_write(fd, hdr.buf, 12)
        sys_posix_write(fd, payload.buf, payload.len)
        pcrc := _tf_mask_crc(_tf_crc32c(payload.buf, payload.len))
        ftr := binbuf_new(8)
        binbuf_push_u32_le(ftr, pcrc)
        sys_posix_write(fd, ftr.buf, 4)
        binbuf_free(ftr)
    binbuf_free(hdr)

fn tfevents_open(log_dir: string) -> TfEventWriter:
    sys_mkdir_p(log_dir)
    ts := sys_time_ns() / 1000000000
    fname := "events.out.tfevents." + to_text(ts) + ".clsandbox.1"
    full := sys_path_join(log_dir, fname)
    fd := sys_posix_open_wo_trunc(full)
    // Emit header Event(wall_time=ts, file_version="brain.Event:2")
    ev := binbuf_new(64)
    binbuf_push_u8(ev, 9)
    _pb_push_f64_le(ev, float(ts))
    ver := "brain.Event:2"
    binbuf_push_u8(ev, 26)
    _pb_push_varint(ev, string_length(ver))
    binbuf_push_str(ev, ver)
    _tf_write_record(fd, ev)
    binbuf_free(ev)
    return TfEventWriter(fd, full)

fn tfevents_add_scalar(w: TfEventWriter, tag: string, val: float, step: int, wall_time: float):
    if w.fd < 0:
        return
    // Summary.Value: field 1 tag (wire 2 => 0x0a), field 2 simple_value float (wire 5 => 0x15)
    vbuf := binbuf_new(128)
    binbuf_push_u8(vbuf, 10)
    _pb_push_varint(vbuf, string_length(tag))
    binbuf_push_str(vbuf, tag)
    binbuf_push_u8(vbuf, 21)
    binbuf_push_f32_le(vbuf, val)

    // Summary: field 1 repeated Value (wire 2 => 0x0a)
    sbuf := binbuf_new(144)
    binbuf_push_u8(sbuf, 10)
    _pb_push_varint(sbuf, vbuf.len)
    binbuf_push_raw(sbuf, vbuf.buf, vbuf.len)

    // Event: field 1 wall_time (double => 0x09), field 2 step (int64 => 0x10), field 5 summary (wire 2 => 0x2a)
    ev := binbuf_new(192)
    binbuf_push_u8(ev, 9)
    _pb_push_f64_le(ev, wall_time)
    binbuf_push_u8(ev, 16)
    _pb_push_varint(ev, step)
    binbuf_push_u8(ev, 42)
    _pb_push_varint(ev, sbuf.len)
    binbuf_push_raw(ev, sbuf.buf, sbuf.len)

    _tf_write_record(w.fd, ev)
    binbuf_free(vbuf)
    binbuf_free(sbuf)
    binbuf_free(ev)

fn tfevents_close(&w: TfEventWriter):
    if w.fd >= 0:
        sys_posix_close(w.fd)
        w.fd = -1
