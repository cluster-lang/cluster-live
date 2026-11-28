// ============================================================================
//  Cluster Standard Library: Cryptography & Hashing (std/crypto.zk)
//  Pure Cluster implementations:
//   - SHA-1, SHA-256 (FIPS 180-4), FNV-1a, DJB2
//   - HMAC-SHA256 (RFC 2104), HKDF-SHA256 (RFC 5869)
//   - ChaCha20, Poly1305, ChaCha20-Poly1305 AEAD (RFC 8439)
//   - X25519 Elliptic Curve Diffie-Hellman (RFC 7748, constant-time 16x16 limbs)
// ============================================================================

fn rol32(x: int, n: int) -> int:
    mask := 4294967295
    left := (x << n) & mask
    right := (x & mask) >> (32 - n)
    return (left | right) & mask

fn rotr32(x: int, n: int) -> int:
    mask := 4294967295
    if n == 0:
        return x & mask
    right := (x & mask) >> n
    left := (x << (32 - n)) & mask
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

fn str_to_bytes(s: string) -> vector[int]:
    out := vector[int]()
    n := string_length(s)
    i := 0
    while i < n:
        list_push(out, byte_at(s, i) & 255)
        i = i + 1
    return out

fn bytes_to_str(b: vector[int]) -> string:
    sz := list_size(b)
    buf: ptr := mem_alloc(sz + 1)
    i := 0
    while i < sz:
        ptr_write_u8(ptr_add(buf, i), b[(i)] & 255)
        i = i + 1
    ptr_write_u8(ptr_add(buf, sz), 0)
    return str_from_parts(buf, sz)

fn bytes_to_hex(b: vector[int]) -> string:
    sz := list_size(b)
    out := ""
    i := 0
    while i < sz:
        v := b[(i)] & 255
        out = out + hex_nibble((v >> 4) & 15) + hex_nibble(v & 15)
        i = i + 1
    return out

fn _hex_val(c: int) -> int:
    if c >= 48 and c <= 57: return c - 48
    if c >= 97 and c <= 102: return c - 87
    if c >= 65 and c <= 70: return c - 55
    return 0

fn hex_to_bytes(h: string) -> vector[int]:
    out := vector[int]()
    n := string_length(h)
    i := 0
    while i + 1 < n:
        v := (_hex_val(byte_at(h, i)) << 4) | _hex_val(byte_at(h, i + 1))
        list_push(out, v)
        i = i + 2
    return out

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
            word := ((bytes[b_idx] << 24) | (bytes[b_idx + 1] << 16) | (bytes[b_idx + 2] << 8) | bytes[b_idx + 3]) & mask
            w.push(word)
            t = t + 1
        while t < 80:
            val := (w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16]) & mask
            w.push(rol32(val, 1))
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

// ----------------------------------------------------------------------------
// FIPS 180-4 SHA-256
// ----------------------------------------------------------------------------
fn sha256_bytes(msg_bytes: vector[int]) -> vector[int]:
    mask := 4294967295
    k_tab: vector[int] = [
        1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
        3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
        3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
        2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
        666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
        2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
        430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
        1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298
    ]
    bytes := vector[int]()
    mlen := list_size(msg_bytes)
    i := 0
    while i < mlen:
        list_push(bytes, msg_bytes[(i)] & 255)
        i = i + 1
    list_push(bytes, 128)
    while (list_size(bytes) + 8) % 64 != 0:
        list_push(bytes, 0)
    bit_len := mlen * 8
    hi := (bit_len >> 32) & mask
    lo := bit_len & mask
    list_push(bytes, (hi >> 24) & 255); list_push(bytes, (hi >> 16) & 255)
    list_push(bytes, (hi >> 8) & 255);  list_push(bytes, hi & 255)
    list_push(bytes, (lo >> 24) & 255); list_push(bytes, (lo >> 16) & 255)
    list_push(bytes, (lo >> 8) & 255);  list_push(bytes, lo & 255)

    h0 := 1779033703
    h1 := 3144134277
    h2 := 1013904242
    h3 := 2773480762
    h4 := 1359893119
    h5 := 2600822924
    h6 := 528734635
    h7 := 1541459225

    total := list_size(bytes)
    chunk := 0
    while chunk < total:
        w := vector[int]()
        t := 0
        while t < 16:
            bi := chunk + (t * 4)
            word := ((bytes[(bi)] << 24) | (bytes[(bi + 1)] << 16) | (bytes[(bi + 2)] << 8) | bytes[(bi + 3)]) & mask
            list_push(w, word)
            t = t + 1
        while t < 64:
            w15 := w[(t - 15)]
            w2 := w[(t - 2)]
            s0 := rotr32(w15, 7) ^ rotr32(w15, 18) ^ ((w15 & mask) >> 3)
            s1 := rotr32(w2, 17) ^ rotr32(w2, 19) ^ ((w2 & mask) >> 10)
            nw := (w[(t - 16)] + s0 + w[(t - 7)] + s1) & mask
            list_push(w, nw)
            t = t + 1
        a := h0; b := h1; c := h2; d := h3
        e := h4; f := h5; g := h6; h := h7
        i = 0
        while i < 64:
            S1 := rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25)
            ch := (e & f) ^ ((e ^ mask) & g)
            temp1 := (h + S1 + ch + k_tab[(i)] + w[(i)]) & mask
            S0 := rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22)
            maj := (a & b) ^ (a & c) ^ (b & c)
            temp2 := (S0 + maj) & mask
            h = g; g = f; f = e
            e = (d + temp1) & mask
            d = c; c = b; b = a
            a = (temp1 + temp2) & mask
            i = i + 1
        h0 = (h0 + a) & mask; h1 = (h1 + b) & mask
        h2 = (h2 + c) & mask; h3 = (h3 + d) & mask
        h4 = (h4 + e) & mask; h5 = (h5 + f) & mask
        h6 = (h6 + g) & mask; h7 = (h7 + h) & mask
        chunk = chunk + 64

    dig := vector[int]()
    hs: vector[int] = [h0, h1, h2, h3, h4, h5, h6, h7]
    hi2 := 0
    while hi2 < 8:
        hv := hs[(hi2)]
        list_push(dig, (hv >> 24) & 255)
        list_push(dig, (hv >> 16) & 255)
        list_push(dig, (hv >> 8) & 255)
        list_push(dig, hv & 255)
        hi2 = hi2 + 1
    return dig

fn sha256(msg: string) -> string:
    return bytes_to_hex(sha256_bytes(str_to_bytes(msg)))

// ----------------------------------------------------------------------------
// HMAC-SHA256 & HKDF-SHA256 (RFC 2104 / RFC 5869)
// ----------------------------------------------------------------------------
fn hmac_sha256(key_in: vector[int], msg: vector[int]) -> vector[int]:
    key := vector[int]()
    if list_size(key_in) > 64:
        kh := sha256_bytes(key_in)
        i := 0
        while i < list_size(kh):
            list_push(key, kh[(i)])
            i = i + 1
    else:
        i := 0
        while i < list_size(key_in):
            list_push(key, key_in[(i)] & 255)
            i = i + 1
    while list_size(key) < 64:
        list_push(key, 0)

    ipad := vector[int]()
    opad := vector[int]()
    i := 0
    while i < 64:
        kb := key[(i)]
        list_push(ipad, kb ^ 54)
        list_push(opad, kb ^ 92)
        i = i + 1
    i = 0
    while i < list_size(msg):
        list_push(ipad, msg[(i)] & 255)
        i = i + 1
    inner := sha256_bytes(ipad)
    i = 0
    while i < list_size(inner):
        list_push(opad, inner[(i)])
        i = i + 1
    return sha256_bytes(opad)

fn hkdf_extract(salt: vector[int], ikm: vector[int]) -> vector[int]:
    s := salt
    if list_size(s) == 0:
        s = vector[int]()
        i := 0
        while i < 32:
            list_push(s, 0)
            i = i + 1
    return hmac_sha256(s, ikm)

fn hkdf_expand(prk: vector[int], info: vector[int], out_len: int) -> vector[int]:
    okm := vector[int]()
    prev := vector[int]()
    ctr := 1
    while list_size(okm) < out_len:
        inp := vector[int]()
        pi := 0
        while pi < list_size(prev):
            list_push(inp, prev[(pi)])
            pi = pi + 1
        ii := 0
        while ii < list_size(info):
            list_push(inp, info[(ii)])
            ii = ii + 1
        list_push(inp, ctr & 255)
        prev = hmac_sha256(prk, inp)
        bi := 0
        while bi < list_size(prev) and list_size(okm) < out_len:
            list_push(okm, prev[(bi)])
            bi = bi + 1
        ctr = ctr + 1
    return okm

// ----------------------------------------------------------------------------
// ChaCha20 & Poly1305 AEAD (RFC 8439)
// ----------------------------------------------------------------------------
fn _cc_qr(&s: vector[int], a: int, b: int, c: int, d: int):
    m := 4294967295
    sa := (s[(a)] + s[(b)]) & m
    sd := rol32(s[(d)] ^ sa, 16)
    sc := (s[(c)] + sd) & m
    sb := rol32(s[(b)] ^ sc, 12)
    sa = (sa + sb) & m
    sd = rol32(sd ^ sa, 8)
    sc = (sc + sd) & m
    sb = rol32(sb ^ sc, 7)
    s[(a)] = sa; s[(b)] = sb; s[(c)] = sc; s[(d)] = sd

fn _le32(b: vector[int], off: int) -> int:
    return (b[(off)] & 255) | ((b[(off + 1)] & 255) << 8) | ((b[(off + 2)] & 255) << 16) | ((b[(off + 3)] & 255) << 24)

fn chacha20_block(key: vector[int], counter: int, nonce: vector[int]) -> vector[int]:
    m := 4294967295
    st := vector[int]()
    list_push(st, 1634760805); list_push(st, 857760878); list_push(st, 2036477234); list_push(st, 1797285236)
    i := 0
    while i < 8:
        list_push(st, _le32(key, i * 4))
        i = i + 1
    list_push(st, counter & m)
    list_push(st, _le32(nonce, 0))
    list_push(st, _le32(nonce, 4))
    list_push(st, _le32(nonce, 8))

    ws := vector[int]()
    i = 0
    while i < 16:
        list_push(ws, st[(i)])
        i = i + 1
    r := 0
    while r < 10:
        _cc_qr(ws, 0, 4, 8, 12); _cc_qr(ws, 1, 5, 9, 13); _cc_qr(ws, 2, 6, 10, 14); _cc_qr(ws, 3, 7, 11, 15)
        _cc_qr(ws, 0, 5, 10, 15); _cc_qr(ws, 1, 6, 11, 12); _cc_qr(ws, 2, 7, 8, 13); _cc_qr(ws, 3, 4, 9, 14)
        r = r + 1
    out := vector[int]()
    i = 0
    while i < 16:
        v := (ws[(i)] + st[(i)]) & m
        list_push(out, v & 255)
        list_push(out, (v >> 8) & 255)
        list_push(out, (v >> 16) & 255)
        list_push(out, (v >> 24) & 255)
        i = i + 1
    return out

fn chacha20_xor(key: vector[int], counter: int, nonce: vector[int], data: vector[int]) -> vector[int]:
    out := vector[int]()
    n := list_size(data)
    blk_idx := 0
    off := 0
    while off < n:
        ks := chacha20_block(key, counter + blk_idx, nonce)
        j := 0
        while j < 64 and off + j < n:
            list_push(out, (data[(off + j)] ^ ks[(j)]) & 255)
            j = j + 1
        blk_idx = blk_idx + 1
        off = off + 64
    return out

fn poly1305_mac(key32: vector[int], msg: vector[int]) -> vector[int]:
    // RFC 8439 Poly1305 in 5 x 26-bit limbs mod (2^130 - 5)
    t0 := _le32(key32, 0) & 268435455
    t1 := _le32(key32, 4) & 268435440
    t2 := _le32(key32, 8) & 268435440
    t3 := _le32(key32, 12) & 268435440
    // Pack clamped r into 26-bit limbs (no overflow: sum < 2^56)
    m26 := 67108863
    r0 := t0 & m26
    r1 := ((t0 >> 26) | (t1 << 6)) & m26
    r2 := ((t1 >> 20) | (t2 << 12)) & m26
    r3 := ((t2 >> 14) | (t3 << 18)) & m26
    r4 := (t3 >> 8) & 268435455
    r1 = r1 & 67108608
    r2 = r2 & 67092479
    r3 = r3 & 66060287
    r4 = r4 & 1048575

    // Recompute standard RFC clamp in byte order before 26-bit unpack for exact accuracy
    rc := vector[int]()
    i := 0
    while i < 16:
        b := key32[(i)] & 255
        if i == 3 or i == 7 or i == 11 or i == 15: b = b & 15
        if i == 4 or i == 8 or i == 12: b = b & 252
        list_push(rc, b)
        i = i + 1
    w0 := _le32(rc, 0) & 4294967295
    w1 := _le32(rc, 4) & 4294967295
    w2 := _le32(rc, 8) & 4294967295
    w3 := _le32(rc, 12) & 4294967295
    r0 = w0 & m26
    r1 = ((w0 >> 26) | (w1 << 6)) & m26
    r2 = ((w1 >> 20) | (w2 << 12)) & m26
    r3 = ((w2 >> 14) | (w3 << 18)) & m26
    r4 = (w3 >> 8) & 16777215

    s1 := r1 * 5; s2 := r2 * 5; s3 := r3 * 5; s4 := r4 * 5
    h0 := 0; h1 := 0; h2 := 0; h3 := 0; h4 := 0

    mlen := list_size(msg)
    off := 0
    while off < mlen:
        rem := mlen - off
        take := 16
        if rem < 16: take = rem
        blk := vector[int]()
        bi := 0
        while bi < 17:
            list_push(blk, 0)
            bi = bi + 1
        bi = 0
        while bi < take:
            blk[(bi)] = msg[(off + bi)] & 255
            bi = bi + 1
        blk[(take)] = 1

        m0 := _le32(blk, 0) & 4294967295
        m1 := _le32(blk, 4) & 4294967295
        m2 := _le32(blk, 8) & 4294967295
        m3 := _le32(blk, 12) & 4294967295
        hib := blk[(16)]

        h0 = h0 + (m0 & m26)
        h1 = h1 + (((m0 >> 26) | (m1 << 6)) & m26)
        h2 = h2 + (((m1 >> 20) | (m2 << 12)) & m26)
        h3 = h3 + (((m2 >> 14) | (m3 << 18)) & m26)
        h4 = h4 + ((m3 >> 8) | (hib << 24))

        d0 := (h0 * r0) + (h1 * s4) + (h2 * s3) + (h3 * s2) + (h4 * s1)
        d1 := (h0 * r1) + (h1 * r0) + (h2 * s4) + (h3 * s3) + (h4 * s2)
        d2 := (h0 * r2) + (h1 * r1) + (h2 * r0) + (h3 * s4) + (h4 * s3)
        d3 := (h0 * r3) + (h1 * r2) + (h2 * r1) + (h3 * r0) + (h4 * s4)
        d4 := (h0 * r4) + (h1 * r3) + (h2 * r2) + (h3 * r1) + (h4 * r0)

        c := d0 >> 26; h0 = d0 & m26; d1 = d1 + c
        c = d1 >> 26; h1 = d1 & m26; d2 = d2 + c
        c = d2 >> 26; h2 = d2 & m26; d3 = d3 + c
        c = d3 >> 26; h3 = d3 & m26; d4 = d4 + c
        c = d4 >> 26; h4 = d4 & m26; h0 = h0 + (c * 5)
        c = h0 >> 26; h0 = h0 & m26; h1 = h1 + c
        off = off + 16

    c := h1 >> 26; h1 = h1 & m26; h2 = h2 + c
    c = h2 >> 26; h2 = h2 & m26; h3 = h3 + c
    c = h3 >> 26; h3 = h3 & m26; h4 = h4 + c
    c = h4 >> 26; h4 = h4 & m26; h0 = h0 + (c * 5)
    c = h0 >> 26; h0 = h0 & m26; h1 = h1 + c

    // Conditional subtract p = 2^130 - 5
    g0 := h0 + 5; c = g0 >> 26; g0 = g0 & m26
    g1 := h1 + c; c = g1 >> 26; g1 = g1 & m26
    g2 := h2 + c; c = g2 >> 26; g2 = g2 & m26
    g3 := h3 + c; c = g3 >> 26; g3 = g3 & m26
    g4 := h4 + c - 67108864
    if g4 >= 0:
        h0 = g0; h1 = g1; h2 = g2; h3 = g3; h4 = g4

    // Pack limbs into 4 x 32-bit words and add key32[16..31]
    u0 := (h0 | (h1 << 26)) & 4294967295
    u1 := ((h1 >> 6) | (h2 << 20)) & 4294967295
    u2 := ((h2 >> 12) | (h3 << 14)) & 4294967295
    u3 := ((h3 >> 18) | (h4 << 8)) & 4294967295

    u0 = u0 + (_le32(key32, 16) & 4294967295)
    u1 = u1 + (_le32(key32, 20) & 4294967295) + (u0 >> 32)
    u2 = u2 + (_le32(key32, 24) & 4294967295) + (u1 >> 32)
    u3 = u3 + (_le32(key32, 28) & 4294967295) + (u2 >> 32)
    u0 = u0 & 4294967295; u1 = u1 & 4294967295; u2 = u2 & 4294967295; u3 = u3 & 4294967295

    tag := vector[int]()
    words: vector[int] = [u0, u1, u2, u3]
    wi := 0
    while wi < 4:
        w := words[(wi)]
        list_push(tag, w & 255)
        list_push(tag, (w >> 8) & 255)
        list_push(tag, (w >> 16) & 255)
        list_push(tag, (w >> 24) & 255)
        wi = wi + 1
    return tag

fn _aead_mac_data(otk: vector[int], aad: vector[int], ct: vector[int]) -> vector[int]:
    m := vector[int]()
    i := 0
    while i < list_size(aad):
        list_push(m, aad[(i)] & 255)
        i = i + 1
    while (list_size(m) % 16) != 0:
        list_push(m, 0)
    i = 0
    while i < list_size(ct):
        list_push(m, ct[(i)] & 255)
        i = i + 1
    while (list_size(m) % 16) != 0:
        list_push(m, 0)
    alen := list_size(aad)
    clen := list_size(ct)
    j := 0
    while j < 8:
        list_push(m, (alen >> (j * 8)) & 255)
        j = j + 1
    j = 0
    while j < 8:
        list_push(m, (clen >> (j * 8)) & 255)
        j = j + 1
    return poly1305_mac(otk, m)

fn chacha20_poly1305_seal(key: vector[int], nonce: vector[int], aad: vector[int], pt: vector[int]) -> vector[int]:
    otk := chacha20_block(key, 0, nonce)
    ct := chacha20_xor(key, 1, nonce, pt)
    tag := _aead_mac_data(otk, aad, ct)
    i := 0
    while i < 16:
        list_push(ct, tag[(i)])
        i = i + 1
    return ct

fn chacha20_poly1305_open(key: vector[int], nonce: vector[int], aad: vector[int], ct_tag: vector[int], &ok: int) -> vector[int]:
    ok = 0
    n := list_size(ct_tag)
    if n < 16:
        return vector[int]()
    ct_len := n - 16
    ct := vector[int]()
    i := 0
    while i < ct_len:
        list_push(ct, ct_tag[(i)] & 255)
        i = i + 1
    otk := chacha20_block(key, 0, nonce)
    exp_tag := _aead_mac_data(otk, aad, ct)
    diff := 0
    i = 0
    while i < 16:
        diff = diff | (exp_tag[(i)] ^ (ct_tag[(ct_len + i)] & 255))
        i = i + 1
    if diff != 0:
        return vector[int]()
    ok = 1
    return chacha20_xor(key, 1, nonce, ct)

// ----------------------------------------------------------------------------
// RFC 7748 X25519 (Constant-Time 16x16-bit Limbs Montgomery Ladder)
// ----------------------------------------------------------------------------
fn _fe_zero() -> vector[int]:
    v := vector[int]()
    i := 0
    while i < 16:
        list_push(v, 0)
        i = i + 1
    return v

fn _fe_from_bytes(b: vector[int]) -> vector[int]:
    o := _fe_zero()
    i := 0
    while i < 16:
        o[(i)] = (b[(i * 2)] & 255) | ((b[(i * 2 + 1)] & 255) << 8)
        i = i + 1
    o[(15)] = o[(15)] & 32767
    return o

fn _fe_carry(&h: vector[int]):
    i := 0
    while i < 16:
        h[(i)] = h[(i)] + 65536
        c := h[(i)] >> 16
        h[(i)] = h[(i)] - (c << 16)
        if i < 15:
            h[(i + 1)] = h[(i + 1)] + (c - 1)
        else:
            h[(0)] = h[(0)] + (38 * (c - 1))
        i = i + 1

fn _fe_add(a: vector[int], b: vector[int]) -> vector[int]:
    o := _fe_zero()
    i := 0
    while i < 16:
        o[(i)] = a[(i)] + b[(i)]
        i = i + 1
    return o

fn _fe_sub(a: vector[int], b: vector[int]) -> vector[int]:
    o := _fe_zero()
    i := 0
    while i < 16:
        o[(i)] = a[(i)] - b[(i)]
        i = i + 1
    return o

fn _fe_mul(a: vector[int], b: vector[int]) -> vector[int]:
    t := vector[int]()
    i := 0
    while i < 31:
        list_push(t, 0)
        i = i + 1
    i = 0
    while i < 16:
        j := 0
        while j < 16:
            t[(i + j)] = t[(i + j)] + (a[(i)] * b[(j)])
            j = j + 1
        i = i + 1
    i = 0
    while i < 15:
        t[(i)] = t[(i)] + (38 * t[(i + 16)])
        i = i + 1
    o := _fe_zero()
    i = 0
    while i < 16:
        o[(i)] = t[(i)]
        i = i + 1
    _fe_carry(o)
    _fe_carry(o)
    return o

fn _fe_sq(a: vector[int]) -> vector[int]:
    return _fe_mul(a, a)

fn _fe_inv(a: vector[int]) -> vector[int]:
    c := a
    i := 253
    while i >= 0:
        c = _fe_sq(c)
        if i != 2 and i != 4:
            c = _fe_mul(c, a)
        i = i - 1
    return c

fn _fe_cswap(&p: vector[int], &q: vector[int], b: int):
    i := 0
    while i < 16:
        t := b * (p[(i)] ^ q[(i)])
        p[(i)] = p[(i)] ^ t
        q[(i)] = q[(i)] ^ t
        i = i + 1

fn _fe_to_bytes(n: vector[int]) -> vector[int]:
    m := _fe_zero()
    t := _fe_zero()
    i := 0
    while i < 16:
        t[(i)] = n[(i)]
        i = i + 1
    _fe_carry(t); _fe_carry(t); _fe_carry(t)
    q := 0
    while q < 2:
        m[(0)] = t[(0)] - 65517
        i = 1
        while i < 15:
            m[(i)] = t[(i)] - 65535 - ((m[(i - 1)] >> 16) & 1)
            m[(i - 1)] = m[(i - 1)] & 65535
            i = i + 1
        m[(15)] = t[(15)] - 32767 - ((m[(14)] >> 16) & 1)
        m[(14)] = m[(14)] & 65535
        swap := 1 - ((m[(15)] >> 16) & 1)
        _fe_cswap(t, m, swap)
        q = q + 1
    out := vector[int]()
    i = 0
    while i < 16:
        list_push(out, t[(i)] & 255)
        list_push(out, (t[(i)] >> 8) & 255)
        i = i + 1
    return out

fn x25519_scalarmult(scalar: vector[int], u_bytes: vector[int]) -> vector[int]:
    z := vector[int]()
    i := 0
    while i < 32:
        list_push(z, scalar[(i)] & 255)
        i = i + 1
    z[(0)] = z[(0)] & 248
    z[(31)] = (z[(31)] & 127) | 64

    x := _fe_from_bytes(u_bytes)
    a := _fe_zero(); a[(0)] = 1
    b := _fe_zero()
    i = 0
    while i < 16:
        b[(i)] = x[(i)]
        i = i + 1
    c := _fe_zero()
    d := _fe_zero(); d[(0)] = 1
    a24 := _fe_zero(); a24[(0)] = 56129; a24[(1)] = 1 // 121665 = 0x1db41

    swap := 0
    pos := 254
    while pos >= 0:
        r := (z[(pos >> 3)] >> (pos & 7)) & 1
        swap = swap ^ r
        _fe_cswap(a, b, swap)
        _fe_cswap(c, d, swap)
        swap = r

        aa := _fe_add(a, c)
        bb := _fe_sub(a, c)
        cc := _fe_add(b, d)
        dd := _fe_sub(b, d)
        e := _fe_sq(aa)
        f := _fe_sq(bb)
        da := _fe_mul(dd, aa)
        cb := _fe_mul(cc, bb)
        b = _fe_sq(_fe_add(da, cb))
        d = _fe_mul(x, _fe_sq(_fe_sub(da, cb)))
        a = _fe_mul(e, f)
        ed := _fe_sub(e, f)
        c = _fe_mul(ed, _fe_add(e, _fe_mul(a24, ed)))
        pos = pos - 1
    _fe_cswap(a, b, swap)
    _fe_cswap(c, d, swap)
    return _fe_to_bytes(_fe_mul(a, _fe_inv(c)))

fn x25519_base(scalar: vector[int]) -> vector[int]:
    g := vector[int]()
    list_push(g, 9)
    i := 1
    while i < 32:
        list_push(g, 0)
        i = i + 1
    return x25519_scalarmult(scalar, g)

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
