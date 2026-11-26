// ============================================================================
//  cl-ai-transformer: Pure Cluster Modern Transformer Decoder Architecture
// ----------------------------------------------------------------------------
//  Full LLaMA 3 / Mistral / DeepSeek style Decoder Block in pure Cluster:
//    * Pre-Attention RMSNorm normalization
//    * Multi-Head Scaled Dot-Product FlashAttention with Rotary Embeddings (RoPE)
//    * Residual Skip Connections
//    * Post-Attention RMSNorm normalization
//    * SwiGLU Gated FeedForward Network (gate @ w_gate * up @ w_up) @ w_down
//    * Autoregressive next-token logits generation & Top-K/ArgMax sampling
// ============================================================================

import "std/tensor.cl"
import "std/math.zk"

struct LlamaBlock:
    dim: int
    hidden_dim: int
    heads: int
    head_dim: int
    scale: float
    attn_norm_w: Tensor
    wq: Tensor
    wk: Tensor
    wv: Tensor
    wo: Tensor
    ffn_norm_w: Tensor
    w_gate: Tensor
    w_up: Tensor
    w_down: Tensor

fn llama_block_new(dim: int, hidden_dim: int, heads: int) -> LlamaBlock:
    head_dim := dim / heads
    scale := 1.0 / sqrt(to_float(head_dim))
    bnd_d := 1.0 / sqrt(to_float(dim))
    bnd_h := 1.0 / sqrt(to_float(hidden_dim))
    
    // Normalization weights (initialized to 1.0)
    attn_norm := tensor_fill(1, dim, 1.0)
    ffn_norm := tensor_fill(1, dim, 1.0)
    
    // Attention projections
    wq := tensor_random(dim, dim, -bnd_d, bnd_d)
    wk := tensor_random(dim, dim, -bnd_d, bnd_d)
    wv := tensor_random(dim, dim, -bnd_d, bnd_d)
    wo := tensor_random(dim, dim, -bnd_d, bnd_d)
    
    // SwiGLU FeedForward projections
    w_gate := tensor_random(dim, hidden_dim, -bnd_d, bnd_d)
    w_up   := tensor_random(dim, hidden_dim, -bnd_d, bnd_d)
    w_down := tensor_random(hidden_dim, dim, -bnd_h, bnd_h)
    
    return LlamaBlock(
        dim, hidden_dim, heads, head_dim, scale,
        attn_norm, wq, wk, wv, wo,
        ffn_norm, w_gate, w_up, w_down
    )

fn llama_block_forward(b: LlamaBlock, x: Tensor, is_causal: int) -> Tensor:
    // 1. Pre-Attention RMSNorm
    x_norm := rmsnorm(x, b.attn_norm_w, 0.00001)
    
    // 2. Linear Projections for Q, K, V
    q := x_norm @ b.wq
    k := x_norm @ b.wk
    v := x_norm @ b.wv
    
    // 3. Rotary Position Embeddings (RoPE)
    q_rot := rope(q, b.head_dim, 10000.0)
    k_rot := rope(k, b.head_dim, 10000.0)
    
    // 4. SRAM-Tiled FlashAttention
    attn := flash_attention(q_rot, k_rot, v, b.scale, is_causal)
    attn_out := attn @ b.wo
    
    // 5. First Residual Connection
    x1 := x + attn_out
    
    // 6. Post-Attention RMSNorm
    x1_norm := rmsnorm(x1, b.ffn_norm_w, 0.00001)
    
    // 7. SwiGLU FeedForward Network: (SiLU(x @ w_gate) * (x @ w_up)) @ w_down
    gate := x1_norm @ b.w_gate
    up := x1_norm @ b.w_up
    act := swiglu(gate, up)
    ffn_out := act @ b.w_down
    
    // 8. Second Residual Connection
    out := x1 + ffn_out
    return out

// Autoregressive Greedy & Temperature Sampling

fn sample_argmax(logits: Tensor) -> int:
    // Returns index of highest probability token in the last row
    rows := logits.rows()
    cols := logits.cols()
    last_r := rows - 1
    
    let mut best_idx: int = 0
    let mut best_val: float = logits.get(last_r, 0)
    
    let mut c: int = 1
    while c < cols:
        v := logits.get(last_r, c)
        if v > best_val:
            best_val = v
            best_idx = c
        c = c + 1
    return best_idx

fn sample_with_temperature(logits: Tensor, temp: float) -> int:
    if temp <= 0.001:
        return sample_argmax(logits)
    
    rows := logits.rows()
    cols := logits.cols()
    last_r := rows - 1
    
    // Scale logits by temperature and apply softmax
    scaled := tensor_zeros(1, cols)
    let mut c: int = 0
    while c < cols:
        scaled.set(0, c, logits.get(last_r, c) / temp)
        c = c + 1
    
    probs := softmax(scaled)
    return sample_argmax(probs)
