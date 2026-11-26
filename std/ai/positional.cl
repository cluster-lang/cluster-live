// ============================================================================
//  cl-ai-positional: Positional Encoding Module
// ----------------------------------------------------------------------------
//  Comprehensive position representation for transformers in pure Cluster:
//    * Sinusoidal Positional Encoding (Vaswani et al. Attention Is All You Need)
//    * Rotary Position Embedding (RoPE - Su et al. RoFormer / LLaMA)
//    * Forward injection and analytical backward identity gradient pass
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct PositionalEncoding:
    max_len: int
    dim: int
    pe_table: Tensor

fn positional_encoding_new(max_len: int, dim: int) -> PositionalEncoding:
    pe := tensor_zeros(max_len, dim)
    pos := 0
    while pos < max_len:
        i := 0
        while i < dim:
            div_term := pow(10000.0, to_float(2 * (i / 2)) / to_float(dim))
            angle := to_float(pos) / div_term
            if i % 2 == 0:
                tensor_set(pe, pos, i, sin(angle))
            else:
                tensor_set(pe, pos, i, cos(angle))
            i = i + 1
        pos = pos + 1
    return PositionalEncoding(max_len, dim, pe)

fn pe_forward(pe: PositionalEncoding, x: Tensor) -> Tensor:
    seq_len := x.rows()
    out := x.clone()
    r := 0
    while r < seq_len:
        c := 0
        while c < pe.dim:
            v := x.get(r, c) + pe.pe_table.get(r, c)
            tensor_set(out, r, c, v)
            c = c + 1
        r = r + 1
    return out

fn pe_backward(pe: PositionalEncoding, grad_output: Tensor) -> Tensor:
    // Gradient through addition passes directly to inputs (dL/dx = dL/dout)
    return grad_output.clone()

fn apply_rope(x: Tensor, seq_offset: int) -> Tensor:
    seq_len := x.rows()
    dim := x.cols()
    out := x.clone()
    r := 0
    while r < seq_len:
        pos := seq_offset + r
        i := 0
        while i + 1 < dim:
            theta := to_float(pos) / pow(10000.0, to_float(i) / to_float(dim))
            cos_th := cos(theta)
            sin_th := sin(theta)
            x0 := x.get(r, i)
            x1 := x.get(r, i + 1)
            // 2D Givens rotation: [cos -sin; sin cos] * [x0; x1]
            r0 := x0 * cos_th - x1 * sin_th
            r1 := x0 * sin_th + x1 * cos_th
            tensor_set(out, r, i, r0)
            tensor_set(out, r, i + 1, r1)
            i = i + 2
        r = r + 1
    return out

fn apply_rope_backward(grad_out: Tensor, seq_offset: int) -> Tensor:
    seq_len := grad_out.rows()
    dim := grad_out.cols()
    out := grad_out.clone()
    r := 0
    while r < seq_len:
        pos := seq_offset + r
        i := 0
        while i + 1 < dim:
            theta := to_float(pos) / pow(10000.0, to_float(i) / to_float(dim))
            cos_th := cos(theta)
            sin_th := sin(theta)
            g0 := grad_out.get(r, i)
            g1 := grad_out.get(r, i + 1)
            // Inverse Givens rotation: transpose [cos sin; -sin cos]
            rg0 := g0 * cos_th + g1 * sin_th
            rg1 := - g0 * sin_th + g1 * cos_th
            tensor_set(out, r, i, rg0)
            tensor_set(out, r, i + 1, rg1)
            i = i + 2
        r = r + 1
    return out
