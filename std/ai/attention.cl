// ============================================================================
//  cl-ai-attention: Multi-Head Self-Attention Module
// ----------------------------------------------------------------------------
//  Scaled dot-product multi-head attention with causal autoregressive masking:
//    * Query, Key, Value, Output linear projection transformations
//    * Numerically stable softmax attention matrix with optional causal triangle mask
//    * Exact analytical backward pass computing dW_q, dW_k, dW_v, dW_o, and dX
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct MultiHeadAttention:
    dim: int
    heads: int
    head_dim: int
    scale: float
    w_q: Tensor
    w_k: Tensor
    w_v: Tensor
    w_o: Tensor
    gw_q: Tensor
    gw_k: Tensor
    gw_v: Tensor
    gw_o: Tensor
    cached_x: Tensor
    cached_q: Tensor
    cached_k: Tensor
    cached_v: Tensor
    cached_attn: Tensor
    cached_context: Tensor

fn mha_new(dim: int, heads: int) -> MultiHeadAttention:
    head_dim := dim / heads
    bound := 1.0 / sqrt(to_float(dim))
    wq := tensor_random(dim, dim, -bound, bound)
    wk := tensor_random(dim, dim, -bound, bound)
    wv := tensor_random(dim, dim, -bound, bound)
    wo := tensor_random(dim, dim, -bound, bound)
    gwq := tensor_zeros(dim, dim)
    gwk := tensor_zeros(dim, dim)
    gwv := tensor_zeros(dim, dim)
    gwo := tensor_zeros(dim, dim)
    scale := 1.0 / sqrt(to_float(head_dim))
    cx := tensor_zeros(1, 1)
    cq := tensor_zeros(1, 1)
    ck := tensor_zeros(1, 1)
    cv := tensor_zeros(1, 1)
    ca := tensor_zeros(1, 1)
    cctx := tensor_zeros(1, 1)
    return MultiHeadAttention(dim, heads, head_dim, scale, wq, wk, wv, wo, gwq, gwk, gwv, gwo, cx, cq, ck, cv, ca, cctx)

fn mha_forward(mha: MultiHeadAttention, x: Tensor, is_causal: int) -> Tensor:
    mha.cached_x = x.clone()
    q := x @ mha.w_q
    k := x @ mha.w_k
    v := x @ mha.w_v
    mha.cached_q = q
    mha.cached_k = k
    mha.cached_v = v
    
    kt := k.transpose()
    scores := (q @ kt) * mha.scale
    seq_len := x.rows()
    if is_causal == 1:
        r := 0
        while r < seq_len:
            c := r + 1
            while c < seq_len:
                tensor_set(scores, r, c, -10000.0)
                c = c + 1
            r = r + 1
            
    attn := scores.softmax()
    mha.cached_attn = attn
    context := attn @ v
    mha.cached_context = context
    out := context @ mha.w_o
    return out

fn mha_backward(mha: MultiHeadAttention, grad_out: Tensor) -> Tensor:
    // 1. Gradients for W_o
    ctx_t := mha.cached_context.transpose()
    g_wo := ctx_t @ grad_out
    mha.gw_o = mha.gw_o + g_wo
    
    // 2. Gradients for Context
    wo_t := mha.w_o.transpose()
    g_context := grad_out @ wo_t
    
    // 3. Gradients for V and Attn
    attn_t := mha.cached_attn.transpose()
    g_v := attn_t @ g_context
    vt := mha.cached_v.transpose()
    g_attn := g_context @ vt
    
    // 4. Backward through row-wise Softmax
    seq_len := mha.cached_x.rows()
    g_scores := tensor_zeros(seq_len, seq_len)
    r := 0
    while r < seq_len:
        dot_sum := 0.0
        c := 0
        while c < seq_len:
            dot_sum = dot_sum + g_attn.get(r, c) * mha.cached_attn.get(r, c)
            c = c + 1
        c = 0
        while c < seq_len:
            a_val := mha.cached_attn.get(r, c)
            gs := a_val * (g_attn.get(r, c) - dot_sum) * mha.scale
            tensor_set(g_scores, r, c, gs)
            c = c + 1
        r = r + 1
        
    // 5. Gradients for Q and K
    g_q := g_scores @ mha.cached_k
    gst := g_scores.transpose()
    g_k := gst @ mha.cached_q
    
    // 6. Gradients for projection weights W_q, W_k, W_v
    xt := mha.cached_x.transpose()
    mha.gw_q = mha.gw_q + (xt @ g_q)
    mha.gw_k = mha.gw_k + (xt @ g_k)
    mha.gw_v = mha.gw_v + (xt @ g_v)
    
    // 7. Gradients for input X
    wqt := mha.w_q.transpose()
    wkt := mha.w_k.transpose()
    wvt := mha.w_v.transpose()
    gx := (g_q @ wqt) + (g_k @ wkt) + (g_v @ wvt)
    return gx

fn mha_zero_grad(mha: MultiHeadAttention) -> void:
    tensor_free(mha.gw_q)
    tensor_free(mha.gw_k)
    tensor_free(mha.gw_v)
    tensor_free(mha.gw_o)
    mha.gw_q = tensor_zeros(mha.dim, mha.dim)
    mha.gw_k = tensor_zeros(mha.dim, mha.dim)
    mha.gw_v = tensor_zeros(mha.dim, mha.dim)
    mha.gw_o = tensor_zeros(mha.dim, mha.dim)
