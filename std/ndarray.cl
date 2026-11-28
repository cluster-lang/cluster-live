// Cluster Standard Library: Numerical Arrays, PRNG & Quantization Utilities (std/ndarray)
// Pure Cluster replacement for NumPy numerical arrays, Q8_0 packing, and LR/similarity checks.

import "std/binpack.cl"

model NdArray:
    data: vector[float]
    rows: int
    cols: int

model RngState:
    s: int

fn rng_seed(seed: int) -> RngState:
    st := seed
    if st == 0:
        st = 123456789
    return RngState(st)

fn rng_u64(&r: RngState) -> int:
    x := r.s
    x = x ^ (x << 13)
    x = x ^ ((x >> 7) & 144115188075855871)
    x = x ^ (x << 17)
    r.s = x
    if x < 0:
        return 0 - x
    return x

fn rng_uniform(&r: RngState, lo: float, hi: float) -> float:
    u := float(rng_u64(r) & 16777215) / 16777216.0
    return lo + u * (hi - lo)

fn rng_normal(&r: RngState, mean: float, std: float) -> float:
    u1 := rng_uniform(r, 0.000001, 0.999999)
    u2 := rng_uniform(r, 0.0, 1.0)
    z := sqrt(-2.0 * log(u1)) * cos(6.283185307179586 * u2)
    return mean + std * z

fn nd_zeros(rows: int, cols: int) -> NdArray:
    n := rows * cols
    v := vector[float]()
    i := 0
    while i < n:
        list_push(v, 0.0)
        i = i + 1
    return NdArray(v, rows, cols)

fn nd_dot(a: vector[float], b: vector[float]) -> float:
    n := list_size(a)
    nb := list_size(b)
    if nb < n:
        n = nb
    s := 0.0
    i := 0
    while i < n:
        s = s + a[(i)] * b[(i)]
        i = i + 1
    return s

fn nd_norm(a: vector[float]) -> float:
    return sqrt(nd_dot(a, a))

fn nd_cosine(a: vector[float], b: vector[float]) -> float:
    na := nd_norm(a)
    nb := nd_norm(b)
    if na == 0.0 and nb == 0.0:
        return 1.0
    if na == 0.0 or nb == 0.0:
        return 0.0
    return nd_dot(a, b) / (na * nb)

fn nd_max_abs_diff(a: vector[float], b: vector[float]) -> float:
    n := list_size(a)
    m := 0.0
    i := 0
    while i < n:
        d := fabs(a[(i)] - b[(i)])
        if d > m:
            m = d
        i = i + 1
    return m

fn nd_mean_abs_diff(a: vector[float], b: vector[float]) -> float:
    n := list_size(a)
    if n == 0:
        return 0.0
    s := 0.0
    i := 0
    while i < n:
        s = s + fabs(a[(i)] - b[(i)])
        i = i + 1
    return s / float(n)

fn nd_argmax(a: vector[float]) -> int:
    n := list_size(a)
    if n == 0:
        return -1
    best := 0
    bv := a[(0)]
    i := 1
    while i < n:
        if a[(i)] > bv:
            bv = a[(i)]
            best = i
        i = i + 1
    return best

fn nd_rmsnorm(x: vector[float], w: vector[float], eps: float) -> vector[float]:
    n := list_size(x)
    ss := 0.0
    i := 0
    while i < n:
        ss = ss + x[(i)] * x[(i)]
        i = i + 1
    inv := 1.0 / sqrt(ss / float(n) + eps)
    out := vector[float]()
    i = 0
    while i < n:
        list_push(out, x[(i)] * inv * w[(i)])
        i = i + 1
    return out

fn nd_silu_mul(gate: vector[float], up: vector[float]) -> vector[float]:
    n := list_size(gate)
    out := vector[float]()
    i := 0
    while i < n:
        g := gate[(i)]
        ax := fabs(g)
        e := exp(0.0 - ax)
        num := 1.0
        if g < 0.0:
            num = e
        silu := (g * num) / (1.0 + e)
        list_push(out, silu * up[(i)])
        i = i + 1
    return out

fn nd_softmax(scores: vector[float]) -> vector[float]:
    n := list_size(scores)
    out := vector[float]()
    if n == 0:
        return out
    mx := scores[(0)]
    i := 1
    while i < n:
        if scores[(i)] > mx:
            mx = scores[(i)]
        i = i + 1
    sum_e := 0.0
    i = 0
    while i < n:
        ev := exp(scores[(i)] - mx)
        list_push(out, ev)
        sum_e = sum_e + ev
        i = i + 1
    i = 0
    while i < n:
        out[(i)] = out[(i)] / sum_e
        i = i + 1
    return out

fn nd_quantize_q8_0_row_split(&out: BinBuf, mat_ptr: ptr, rows: int, cols: int, use_fp16: int):
    nb := cols / 32
    r := 0
    while r < rows:
        row_base := ptr_add(mat_ptr, r * cols * 4)
        scales := vector[float]()
        b := 0
        while b < nb:
            amax := 0.0
            k := 0
            while k < 32:
                v := fabs(ptr_read_f32(ptr_add(row_base, (b * 32 + k) * 4)))
                if v > amax:
                    amax = v
                k = k + 1
            sc := 0.0
            if amax > 0.0:
                sc = amax / 127.0
            if use_fp16 == 1 and sc > 0.0:
                sc = bin_f16_bits_to_f32(bin_f32_to_f16_bits(sc))
            list_push(scales, sc)
            inv := 0.0
            if sc > 0.0:
                inv = 1.0 / sc
            k = 0
            while k < 32:
                fv := ptr_read_f32(ptr_add(row_base, (b * 32 + k) * 4)) * inv
                qi := to_int(round(fv))
                if qi > 127: qi = 127
                if qi < -127: qi = -127
                binbuf_push_i8(out, qi)
                k = k + 1
            b = b + 1
        b = 0
        while b < nb:
            if use_fp16 == 1:
                binbuf_push_f16_le(out, scales[(b)])
            else:
                binbuf_push_f32_le(out, scales[(b)])
            b = b + 1
        r = r + 1

fn nd_lr_warmup_cosine(step: int, total_steps: int, warmup_steps: int, max_lr: float) -> float:
    if warmup_steps > 0 and step < warmup_steps:
        return max_lr * float(step + 1) / float(warmup_steps)
    if total_steps <= warmup_steps or total_steps <= 1:
        return max_lr
    prog := float(step - warmup_steps) / float(total_steps - warmup_steps)
    if prog > 1.0:
        prog = 1.0
    coeff := 0.5 * (1.0 + cos(3.141592653589793 * prog))
    return max_lr * (0.1 + 0.9 * coeff)
