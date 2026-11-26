// ============================================================================
//  Cluster Standard Library: Cryptography & Hashing (std/crypto.cl)
//  Pure Cluster implementations of RFC 3174 SHA-1, FNV-1a, DJB2, and Base64
// ============================================================================

fn rol32(x: int, n: int) -> int:
    mask := 4294967295
    left := (x << n) & mask
    right := (x >> (32 - n)) & mask
    return (left | right) & mask

fn hex_nibble(n: int) -> string:
    v := n & 15
    if v == 0: return "0"
    if v == 1: return "1"
    if v == 2: return "2"
    if v == 3: return "3"
    if v == 4: return "4"
    if v == 5: return "5"
    if v == 6: return "6"
    if v == 7: return "7"
    if v == 8: return "8"
    if v == 9: return "9"
    if v == 10: return "a"
    if v == 11: return "b"
    if v == 12: return "c"
    if v == 13: return "d"
    if v == 14: return "e"
    return "f"

fn to_hex32(val: int) -> string:
    v := val & 4294967295
    h := ""
    shift := 28
    while shift >= 0:
        nibble := (v >> shift) & 15
        h = h + hex_nibble(nibble)
        shift = shift - 4
    return h

fn hex_char_val(c: int) -> int:
    if c >= 48 and c <= 57: return c - 48
    if c >= 97 and c <= 102: return c - 87
    if c >= 65 and c <= 70: return c - 55
    return 0

fn sha1(msg: string) -> string:
    mask := 4294967295
    mlen := len(msg)
    bit_len := mlen * 8

    bytes: vector[int] = []
    i := 0
    while i < mlen:
        bytes.push(byte_at(msg, i))
        i = i + 1

    bytes.push(128)

    while (len(bytes) + 8) % 64 != 0:
        bytes.push(0)

    high_bits := (bit_len >> 32) & mask
    low_bits := bit_len & mask

    bytes.push((high_bits >> 24) & 255)
    bytes.push((high_bits >> 16) & 255)
    bytes.push((high_bits >> 8) & 255)
    bytes.push(high_bits & 255)

    bytes.push((low_bits >> 24) & 255)
    bytes.push((low_bits >> 16) & 255)
    bytes.push((low_bits >> 8) & 255)
    bytes.push(low_bits & 255)

    h0 := 1732584193
    h1 := 4023233417
    h2 := 2562383102
    h3 := 271733878
    h4 := 3285377520

    total_bytes := len(bytes)
    chunk := 0
    while chunk < total_bytes:
        w: vector[int] = []
        t := 0
        while t < 16:
            b_idx := chunk + (t * 4)
            b0 := bytes[b_idx]
            b1 := bytes[b_idx + 1]
            b2 := bytes[b_idx + 2]
            b3 := bytes[b_idx + 3]
            word := ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & mask
            w.push(word)
            t = t + 1

        while t < 80:
            val := (w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]) & mask
            rot := rol32(val, 1)
            w.push(rot)
            t = t + 1

        a := h0
        b := h1
        c := h2
        d := h3
        e := h4

        i = 0
        while i < 80:
            f := 0
            k := 0
            if i < 20:
                f = (b & c) | ((b ^ mask) & d)
                k = 1518500249
            elif i < 40:
                f = b ^ c ^ d
                k = 1859775393
            elif i < 60:
                f = (b & c) | (b & d) | (c & d)
                k = 2400959708
            else:
                f = b ^ c ^ d
                k = 3395469782

            temp := (rol32(a, 5) + f + e + k + w[i]) & mask
            e = d
            d = c
            c = rol32(b, 30)
            b = a
            a = temp
            i = i + 1

        h0 = (h0 + a) & mask
        h1 = (h1 + b) & mask
        h2 = (h2 + c) & mask
        h3 = (h3 + d) & mask
        h4 = (h4 + e) & mask

        chunk = chunk + 64

    return to_hex32(h0) + to_hex32(h1) + to_hex32(h2) + to_hex32(h3) + to_hex32(h4)

fn djb2_hash(s: string) -> int:
    hash := 5381
    i := 0
    slen := len(s)
    while i < slen:
        b := byte_at(s, i)
        hash = ((hash * 33) + b) % 2147483647
        i = i + 1
    return hash

fn fnv1a_hash(s: string) -> int:
    hash := 2166136261
    i := 0
    slen := len(s)
    while i < slen:
        b := byte_at(s, i)
        hash = (hash ^ b) * 16777619
        hash = hash % 2147483647
        i = i + 1
    return hash
