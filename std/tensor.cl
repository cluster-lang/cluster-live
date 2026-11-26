// Cluster Standard Library: High-Performance Multi-Dimensional Tensors (std::tensor)
// SIMD Cache-Optimized Linear Algebra, GEMM, & AI Attention Primitives

fn zeros(rows: int, cols: int) -> tensor:
    return tensor_zeros(rows, cols)

fn ones(rows: int, cols: int) -> tensor:
    return tensor_ones(rows, cols)

fn fill(rows: int, cols: int, val: float) -> tensor:
    return tensor_fill(rows, cols, val)

fn eye(n: int) -> tensor:
    t := tensor_zeros(n, n)
    let mut i: int = 0
    while i < n:
        t.set(i, i, 1.0)
        i = i + 1
    return t

fn from_vector(rows: int, cols: int, &v: vector[float]) -> tensor:
    t := tensor_zeros(rows, cols)
    let mut r: int = 0
    let mut idx: int = 0
    while r < rows:
        let mut c: int = 0
        while c < cols:
            if idx < list_size(v):
                t.set(r, c, v[idx])
                idx = idx + 1
            c = c + 1
        r = r + 1
    return t

fn to_vector(t: tensor) -> vector[float]:
    v: vector[float] = []
    let mut r: int = 0
    rows := t.rows()
    cols := t.cols()
    while r < rows:
        let mut c: int = 0
        while c < cols:
            list_push(v, t.get(r, c))
            c = c + 1
        r = r + 1
    return v

fn matmul(a: tensor, b: tensor) -> tensor:
    return a @ b

fn transpose(t: tensor) -> tensor:
    return t.transpose()

fn sum(t: tensor) -> float:
    return t.sum()

fn dot(a: tensor, b: tensor) -> float:
    return a.dot(b)

fn relu(t: tensor) -> tensor:
    return tensor_relu(t)

fn gelu(t: tensor) -> tensor:
    return tensor_gelu(t)

fn softmax(t: tensor) -> tensor:
    return tensor_softmax(t)

// Modern Transformer & LLM AI Primitives

fn silu(t: tensor) -> tensor:
    rows := t.rows()
    cols := t.cols()
    out := tensor_zeros(rows, cols)
    let mut r: int = 0
    let mut c: int = 0
    while r < rows:
        c = 0
        while c < cols:
            val := t.get(r, c)
            out.set(r, c, val / (1.0 + exp(-val)))
            c = c + 1
        r = r + 1
    return out

fn swiglu(gate: tensor, up: tensor) -> tensor:
    rows := gate.rows()
    cols := gate.cols()
    out := tensor_zeros(rows, cols)
    let mut r: int = 0
    let mut c: int = 0
    while r < rows:
        c = 0
        while c < cols:
            g := gate.get(r, c)
            silu_g := g / (1.0 + exp(-g))
            out.set(r, c, silu_g * up.get(r, c))
            c = c + 1
        r = r + 1
    return out

fn rmsnorm(x: tensor, weight: tensor, eps: float) -> tensor:
    rows := x.rows()
    cols := x.cols()
    out := tensor_zeros(rows, cols)
    let mut r: int = 0
    let mut c: int = 0
    while r < rows:
        let mut sum_sq: float = 0.0
        c = 0
        while c < cols:
            v := x.get(r, c)
            sum_sq = sum_sq + (v * v)
            c = c + 1
        rms := sqrt((sum_sq / to_float(cols)) + eps)
        inv_rms := 1.0 / rms
        c = 0
        while c < cols:
            w := weight.get(0, c)
            out.set(r, c, x.get(r, c) * inv_rms * w)
            c = c + 1
        r = r + 1
    return out

fn rope(t: tensor, head_dim: int, base_freq: float) -> tensor:
    rows := t.rows()
    cols := t.cols()
    out := t.clone()
    half_dim := head_dim / 2
    let mut pos: int = 0
    while pos < rows:
        let mut i: int = 0
        while i < half_dim:
            if (2 * i + 1) < cols:
                theta := 1.0 / pow(base_freq, to_float(2 * i) / to_float(head_dim))
                angle := to_float(pos) * theta
                cos_a := cos(angle)
                sin_a := sin(angle)
                x0 := t.get(pos, 2 * i)
                x1 := t.get(pos, 2 * i + 1)
                out.set(pos, 2 * i, (x0 * cos_a) - (x1 * sin_a))
                out.set(pos, 2 * i + 1, (x0 * sin_a) + (x1 * cos_a))
            i = i + 1
        pos = pos + 1
    return out

fn flash_attention(q: tensor, k: tensor, v: tensor, scale: float, is_causal: int) -> tensor:
    S := q.rows()
    D := q.cols()
    V_dim := v.cols()
    out := tensor_zeros(S, V_dim)
    
    let mut i: int = 0
    while i < S:
        let mut m_prev: float = -1000000.0
        let mut l_prev: float = 0.0
        
        let mut j: int = 0
        while j < S:
            if is_causal == 1 and j > i:
                j = S
            else:
                let mut score: float = 0.0
                let mut d: int = 0
                while d < D:
                    score = score + (q.get(i, d) * k.get(j, d))
                    d = d + 1
                score = score * scale
                
                let mut m_curr: float = m_prev
                if score > m_curr:
                    m_curr = score
                
                exp_prev := exp(m_prev - m_curr)
                exp_score := exp(score - m_curr)
                l_curr := (l_prev * exp_prev) + exp_score
                
                let mut vd: int = 0
                while vd < V_dim:
                    cur_val := out.get(i, vd)
                    new_val := (cur_val * exp_prev) + (exp_score * v.get(j, vd))
                    out.set(i, vd, new_val)
                    vd = vd + 1
                
                m_prev = m_curr
                l_prev = l_curr
                j = j + 1
        
        if l_prev > 0.000001:
            inv_l := 1.0 / l_prev
            let mut vd: int = 0
            while vd < V_dim:
                out.set(i, vd, out.get(i, vd) * inv_l)
                vd = vd + 1
        i = i + 1
    return out

// Fused Low-Bit Quantized Matrix Multiplication (Zero Memory Decompression)
fn gemm_q8_0(act: tensor, n_cols: int, &q_weights: vector[int], &scales: vector[float]) -> tensor:
    M := act.rows()
    K := act.cols()
    out := tensor_zeros(M, n_cols)
    blocks_per_col := (K + 31) / 32
    
    let mut r: int = 0
    while r < M:
        let mut c: int = 0
        while c < n_cols:
            let mut acc: float = 0.0
            let mut b: int = 0
            while b < blocks_per_col:
                blk_idx := (c * blocks_per_col) + b
                scale := scales[blk_idx]
                let mut bsum: float = 0.0
                let mut e: int = 0
                w_start := blk_idx * 32
                while e < 32:
                    k_idx := (b * 32) + e
                    if k_idx < K:
                        w := to_float(q_weights[w_start + e])
                        bsum = bsum + (act.get(r, k_idx) * w)
                    e = e + 1
                acc = acc + (bsum * scale)
                b = b + 1
            out.set(r, c, acc)
            c = c + 1
        r = r + 1
    return out

fn gemm_q4_0(act: tensor, n_cols: int, &qnibbles: vector[int], &scales: vector[float]) -> tensor:
    M := act.rows()
    K := act.cols()
    out := tensor_zeros(M, n_cols)
    blocks_per_col := (K + 31) / 32
    
    let mut r: int = 0
    while r < M:
        let mut c: int = 0
        while c < n_cols:
            let mut acc: float = 0.0
            let mut b: int = 0
            while b < blocks_per_col:
                blk_idx := (c * blocks_per_col) + b
                scale := scales[blk_idx]
                let mut bsum: float = 0.0
                let mut b_byte: int = 0
                byte_start := blk_idx * 16
                while b_byte < 16:
                    byte_val := qnibbles[byte_start + b_byte]
                    low := (byte_val % 16) - 8
                    high := (byte_val / 16) - 8
                    k0 := (b * 32) + (b_byte * 2)
                    k1 := k0 + 1
                    if k0 < K:
                        bsum = bsum + (act.get(r, k0) * to_float(low))
                    if k1 < K:
                        bsum = bsum + (act.get(r, k1) * to_float(high))
                    b_byte = b_byte + 1
                acc = acc + (bsum * scale)
                b = b + 1
            out.set(r, c, acc)
            c = c + 1
        r = r + 1
    return out
