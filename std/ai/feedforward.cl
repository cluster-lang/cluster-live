// ============================================================================
//  cl-ai-feedforward: Position-wise Feed-Forward Network Module
// ----------------------------------------------------------------------------
//  Two-layer MLP transformer block in pure Cluster:
//    * Linear projection: H1 = X * W1 + b1
//    * Non-linear activation: Act = GELU(H1)
//    * Down projection: Out = Act * W2 + b2
//    * Exact analytical backpropagation computing dW1, db1, dW2, db2, and dX
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct FeedForward:
    dim: int
    hidden_dim: int
    w1: Tensor
    b1: Tensor
    w2: Tensor
    b2: Tensor
    gw1: Tensor
    gb1: Tensor
    gw2: Tensor
    gb2: Tensor
    cached_x: Tensor
    cached_h1: Tensor
    cached_act: Tensor

fn ffn_new(dim: int, hidden_dim: int) -> FeedForward:
    bnd1 := 1.0 / sqrt(to_float(dim))
    bnd2 := 1.0 / sqrt(to_float(hidden_dim))
    w1 := tensor_random(dim, hidden_dim, -bnd1, bnd1)
    b1 := tensor_zeros(1, hidden_dim)
    w2 := tensor_random(hidden_dim, dim, -bnd2, bnd2)
    b2 := tensor_zeros(1, dim)
    gw1 := tensor_zeros(dim, hidden_dim)
    gb1 := tensor_zeros(1, hidden_dim)
    gw2 := tensor_zeros(hidden_dim, dim)
    gb2 := tensor_zeros(1, dim)
    cx := tensor_zeros(1, 1)
    ch1 := tensor_zeros(1, 1)
    cact := tensor_zeros(1, 1)
    return FeedForward(dim, hidden_dim, w1, b1, w2, b2, gw1, gb1, gw2, gb2, cx, ch1, cact)

fn ffn_forward(ffn: FeedForward, x: Tensor) -> Tensor:
    ffn.cached_x = x.clone()
    seq_len := x.rows()
    let mut r: int = 0
    let mut c: int = 0
    
    // Linear 1: h1 = x @ w1 + b1
    h1 := x @ ffn.w1
    r = 0
    while r < seq_len:
        c = 0
        while c < ffn.hidden_dim:
            v := h1.get(r, c) + ffn.b1.get(0, c)
            tensor_set(h1, r, c, v)
            c = c + 1
        r = r + 1
    ffn.cached_h1 = h1
    
    // Activation: GELU
    act := h1.gelu()
    ffn.cached_act = act
    
    // Linear 2: out = act @ w2 + b2
    out := act @ ffn.w2
    r = 0
    while r < seq_len:
        c = 0
        while c < ffn.dim:
            v := out.get(r, c) + ffn.b2.get(0, c)
            tensor_set(out, r, c, v)
            c = c + 1
        r = r + 1
    return out

fn ffn_backward(ffn: FeedForward, grad_out: Tensor) -> Tensor:
    seq_len := grad_out.rows()
    let mut r: int = 0
    let mut c: int = 0
    
    // 1. Gradients for W2 and b2
    act_t := ffn.cached_act.transpose()
    g_w2 := act_t @ grad_out
    ffn.gw2 = ffn.gw2 + g_w2
    
    c = 0
    while c < ffn.dim:
        let mut sum_b: float = 0.0
        r = 0
        while r < seq_len:
            sum_b = sum_b + grad_out.get(r, c)
            r = r + 1
        tensor_set(ffn.gb2, 0, c, ffn.gb2.get(0, c) + sum_b)
        c = c + 1
        
    // 2. Backprop into activation: g_act = grad_out @ w2^T
    w2_t := ffn.w2.transpose()
    g_act := grad_out @ w2_t
    
    // 3. Backprop through GELU activation derivative
    g_h1 := tensor_zeros(seq_len, ffn.hidden_dim)
    r = 0
    while r < seq_len:
        c = 0
        while c < ffn.hidden_dim:
            x_val := ffn.cached_h1.get(r, c)
            u := 0.79788456 * (x_val + 0.044715 * x_val * x_val * x_val)
            th := tanh(u)
            sech2 := 1.0 - th * th
            du := 0.79788456 * (1.0 + 3.0 * 0.044715 * x_val * x_val)
            dgelu := 0.5 * (1.0 + th) + 0.5 * x_val * sech2 * du
            tensor_set(g_h1, r, c, g_act.get(r, c) * dgelu)
            c = c + 1
        r = r + 1
        
    // 4. Gradients for W1 and b1
    xt := ffn.cached_x.transpose()
    g_w1 := xt @ g_h1
    ffn.gw1 = ffn.gw1 + g_w1
    
    c = 0
    while c < ffn.hidden_dim:
        let mut sum_b1: float = 0.0
        r = 0
        while r < seq_len:
            sum_b1 = sum_b1 + g_h1.get(r, c)
            r = r + 1
        tensor_set(ffn.gb1, 0, c, ffn.gb1.get(0, c) + sum_b1)
        c = c + 1
        
    // 5. Gradient for input X: gx = g_h1 @ w1^T
    w1_t := ffn.w1.transpose()
    gx := g_h1 @ w1_t
    return gx

fn ffn_zero_grad(ffn: FeedForward) -> void:
    tensor_free(ffn.gw1)
    tensor_free(ffn.gb1)
    tensor_free(ffn.gw2)
    tensor_free(ffn.gb2)
    ffn.gw1 = tensor_zeros(ffn.dim, ffn.hidden_dim)
    ffn.gb1 = tensor_zeros(1, ffn.hidden_dim)
    ffn.gw2 = tensor_zeros(ffn.hidden_dim, ffn.dim)
    ffn.gb2 = tensor_zeros(1, ffn.dim)
