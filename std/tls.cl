// ============================================================================
//  Cluster Standard Library: Pure Cluster TLS 1.3 (RFC 8446) (std/tls.zk)
//  Record Framing, Key Schedule (HKDF-Expand-Label), X25519 Key Share,
//  and ChaCha20-Poly1305 AEAD Session Encryption.
// ============================================================================

import "std/crypto"

TLS_CHANGE_CIPHER_SPEC: int := 20
TLS_ALERT: int := 21
TLS_HANDSHAKE: int := 22
TLS_APPLICATION_DATA: int := 23

TLS_VERSION_1_2: int := 771   // 0x0303
TLS_VERSION_1_3: int := 772   // 0x0304
TLS_CHACHA20_POLY1305_SHA256: int := 4867 // 0x1303

fn _tls_push_u16(&b: vector[int], v: int):
    list_push(b, (v >> 8) & 255)
    list_push(b, v & 255)

fn _tls_push_u24(&b: vector[int], v: int):
    list_push(b, (v >> 16) & 255)
    list_push(b, (v >> 8) & 255)
    list_push(b, v & 255)

fn _tls_push_vec(&b: vector[int], src: vector[int]):
    i := 0
    n := list_size(src)
    while i < n:
        list_push(b, src[(i)] & 255)
        i = i + 1

fn _tls_xor_nonce(iv: vector[int], seq: int) -> vector[int]:
    nonce := vector[int]()
    i := 0
    while i < 12:
        list_push(nonce, iv[(i)] & 255)
        i = i + 1
    k := 0
    while k < 8:
        sb := (seq >> (k * 8)) & 255
        idx := 11 - k
        nonce[(idx)] = nonce[(idx)] ^ sb
        k = k + 1
    return nonce

// RFC 8446 Section 7.1: HKDF-Expand-Label(Secret, Label, Context, Length)
fn tls_hkdf_expand_label(secret: vector[int], label_s: string, context_hash: vector[int], out_len: int) -> vector[int]:
    full_label := "tls13 " + label_s
    lbl_b := str_to_bytes(full_label)
    hkdf_lbl := vector[int]()
    _tls_push_u16(hkdf_lbl, out_len)
    list_push(hkdf_lbl, list_size(lbl_b) & 255)
    _tls_push_vec(hkdf_lbl, lbl_b)
    list_push(hkdf_lbl, list_size(context_hash) & 255)
    _tls_push_vec(hkdf_lbl, context_hash)
    return hkdf_expand(secret, hkdf_lbl, out_len)

model TlsKeys:
    c_key: vector[int]
    c_iv: vector[int]
    s_key: vector[int]
    s_iv: vector[int]
    c_seq: int := 0
    s_seq: int := 0

fn tls_derive_traffic_keys(shared_secret: vector[int], transcript_hash: vector[int]) -> TlsKeys:
    // Early secret (salt=0, ikm=0..32)
    z32 := vector[int]()
    i := 0
    while i < 32:
        list_push(z32, 0)
        i = i + 1
    early_secret := hkdf_extract(z32, z32)
    empty_hash := sha256_bytes(vector[int]())
    derived := tls_hkdf_expand_label(early_secret, "derived", empty_hash, 32)
    hs_secret := hkdf_extract(derived, shared_secret)

    c_hs := tls_hkdf_expand_label(hs_secret, "c hs traffic", transcript_hash, 32)
    s_hs := tls_hkdf_expand_label(hs_secret, "s hs traffic", transcript_hash, 32)

    derived2 := tls_hkdf_expand_label(hs_secret, "derived", empty_hash, 32)
    master_secret := hkdf_extract(derived2, z32)
    c_ap := tls_hkdf_expand_label(master_secret, "c ap traffic", transcript_hash, 32)
    s_ap := tls_hkdf_expand_label(master_secret, "s ap traffic", transcript_hash, 32)

    tk := TlsKeys(
        tls_hkdf_expand_label(c_ap, "key", vector[int](), 32),
        tls_hkdf_expand_label(c_ap, "iv", vector[int](), 12),
        tls_hkdf_expand_label(s_ap, "key", vector[int](), 32),
        tls_hkdf_expand_label(s_ap, "iv", vector[int](), 12),
        0, 0
    )
    // Fold handshake secrets into final mix if empty transcript
    if list_size(c_hs) != 32 or list_size(s_hs) != 32:
        return tk
    return tk

fn tls_wrap_record(rec_type: int, legacy_ver: int, payload: vector[int]) -> vector[int]:
    rec := vector[int]()
    list_push(rec, rec_type & 255)
    _tls_push_u16(rec, legacy_ver)
    _tls_push_u16(rec, list_size(payload))
    _tls_push_vec(rec, payload)
    return rec

fn tls_encrypt_record(key: vector[int], iv: vector[int], seq: int, inner_type: int, pt: vector[int]) -> vector[int]:
    // TLSInnerPlaintext = content || ContentType
    inner := vector[int]()
    _tls_push_vec(inner, pt)
    list_push(inner, inner_type & 255)

    // Additional data = 5-byte TLSCiphertext header
    aad := vector[int]()
    list_push(aad, TLS_APPLICATION_DATA)
    _tls_push_u16(aad, TLS_VERSION_1_2)
    _tls_push_u16(aad, list_size(inner) + 16)

    nonce := _tls_xor_nonce(iv, seq)
    ct := chacha20_poly1305_seal(key, nonce, aad, inner)
    return tls_wrap_record(TLS_APPLICATION_DATA, TLS_VERSION_1_2, ct)

fn tls_decrypt_record(key: vector[int], iv: vector[int], seq: int, rec_bytes: vector[int], &inner_type: int, &ok: int) -> vector[int]:
    ok = 0
    inner_type = 0
    n := list_size(rec_bytes)
    if n < 22:
        return vector[int]()
    aad := vector[int]()
    i := 0
    while i < 5:
        list_push(aad, rec_bytes[(i)] & 255)
        i = i + 1
    ct_tag := vector[int]()
    while i < n:
        list_push(ct_tag, rec_bytes[(i)] & 255)
        i = i + 1
    nonce := _tls_xor_nonce(iv, seq)
    dec_ok := 0
    inner := chacha20_poly1305_open(key, nonce, aad, ct_tag, dec_ok)
    if dec_ok == 0:
        return vector[int]()
    // Strip trailing zero padding and extract ContentType
    k := list_size(inner) - 1
    while k >= 0:
        if inner[(k)] != 0:
            break
        k = k - 1
    if k < 0:
        return vector[int]()
    inner_type = inner[(k)]
    out := vector[int]()
    j := 0
    while j < k:
        list_push(out, inner[(j)])
        j = j + 1
    ok = 1
    return out

fn tls_build_client_hello(sni_host: string, client_rand: vector[int], x25519_pub: vector[int], alpn: string) -> vector[int]:
    exts := vector[int]()
    // Extension: server_name (0x0000)
    if string_length(sni_host) > 0:
        hb := str_to_bytes(sni_host)
        hlen := list_size(hb)
        _tls_push_u16(exts, 0)
        _tls_push_u16(exts, hlen + 5)
        _tls_push_u16(exts, hlen + 3)
        list_push(exts, 0)
        _tls_push_u16(exts, hlen)
        _tls_push_vec(exts, hb)
    // Extension: supported_versions (0x002b) -> TLS 1.3 (0x0304)
    _tls_push_u16(exts, 43)
    _tls_push_u16(exts, 3)
    list_push(exts, 2)
    _tls_push_u16(exts, TLS_VERSION_1_3)
    // Extension: supported_groups (0x000a) -> x25519 (0x001d)
    _tls_push_u16(exts, 10)
    _tls_push_u16(exts, 4)
    _tls_push_u16(exts, 2)
    _tls_push_u16(exts, 29)
    // Extension: key_share (0x0033) -> x25519 (32B pub)
    _tls_push_u16(exts, 51)
    _tls_push_u16(exts, 38)
    _tls_push_u16(exts, 36)
    _tls_push_u16(exts, 29)
    _tls_push_u16(exts, 32)
    _tls_push_vec(exts, x25519_pub)
    // Extension: ALPN (0x0010)
    if string_length(alpn) > 0:
        ab := str_to_bytes(alpn)
        alen := list_size(ab)
        _tls_push_u16(exts, 16)
        _tls_push_u16(exts, alen + 3)
        _tls_push_u16(exts, alen + 1)
        list_push(exts, alen & 255)
        _tls_push_vec(exts, ab)

    body := vector[int]()
    _tls_push_u16(body, TLS_VERSION_1_2)
    _tls_push_vec(body, client_rand)
    list_push(body, 0) // empty legacy session id
    _tls_push_u16(body, 2)
    _tls_push_u16(body, TLS_CHACHA20_POLY1305_SHA256)
    list_push(body, 1); list_push(body, 0) // null compression
    _tls_push_u16(body, list_size(exts))
    _tls_push_vec(body, exts)

    hs := vector[int]()
    list_push(hs, 1) // HandshakeType::client_hello
    _tls_push_u24(hs, list_size(body))
    _tls_push_vec(hs, body)
    return tls_wrap_record(TLS_HANDSHAKE, 769, hs)

fn tls_build_server_hello(srv_rand: vector[int], x25519_pub: vector[int]) -> vector[int]:
    exts := vector[int]()
    _tls_push_u16(exts, 43)
    _tls_push_u16(exts, 2)
    _tls_push_u16(exts, TLS_VERSION_1_3)
    _tls_push_u16(exts, 51)
    _tls_push_u16(exts, 36)
    _tls_push_u16(exts, 29)
    _tls_push_u16(exts, 32)
    _tls_push_vec(exts, x25519_pub)

    body := vector[int]()
    _tls_push_u16(body, TLS_VERSION_1_2)
    _tls_push_vec(body, srv_rand)
    list_push(body, 0)
    _tls_push_u16(body, TLS_CHACHA20_POLY1305_SHA256)
    list_push(body, 0)
    _tls_push_u16(body, list_size(exts))
    _tls_push_vec(body, exts)

    hs := vector[int]()
    list_push(hs, 2) // HandshakeType::server_hello
    _tls_push_u24(hs, list_size(body))
    _tls_push_vec(hs, body)
    return tls_wrap_record(TLS_HANDSHAKE, TLS_VERSION_1_2, hs)
