// ============================================================================
//  cl-ai-embedding: Token ID to Dense Vector Embedding Module
// ----------------------------------------------------------------------------
//  High-performance embedding table in pure Cluster:
//    * Fast vectorized lookup from token IDs to dense representation vectors
//    * O(D) row-copy forward pass using SIMD memory transfer
//    * Analytical backward pass with gradient accumulation per vocabulary token
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct Embedding:
    vocab_size: int
    dim: int
    weights: Tensor
    grad_weights: Tensor
    cached_tokens: vector[int]

fn embedding_new(vocab_size: int, dim: int) -> Embedding:
    // Xavier / Glorot uniform weight initialization
    bound := 1.0 / sqrt(to_float(dim))
    w := tensor_random(vocab_size, dim, -bound, bound)
    gw := tensor_zeros(vocab_size, dim)
    let mut cached: vector[int] = []
    return Embedding(vocab_size, dim, w, gw, cached)

fn embedding_forward(emb: Embedding, tokens: vector[int]) -> Tensor:
    n := len(tokens)
    emb.cached_tokens = []
    i := 0
    while i < n:
        emb.cached_tokens.push(tokens[i])
        i = i + 1
        
    out := tensor_zeros(n, emb.dim)
    i = 0
    while i < n:
        tok_id := tokens[i]
        if tok_id >= 0 and tok_id < emb.vocab_size:
            tensor_copy_row(out, i, emb.weights, tok_id)
        i = i + 1
    return out

fn embedding_backward(emb: Embedding, grad_output: Tensor) -> void:
    n := len(emb.cached_tokens)
    i := 0
    while i < n:
        tok_id := emb.cached_tokens[i]
        if tok_id >= 0 and tok_id < emb.vocab_size:
            tensor_add_to_row(emb.grad_weights, tok_id, grad_output, i, 1.0)
        i = i + 1

fn embedding_zero_grad(emb: Embedding) -> void:
    tensor_free(emb.grad_weights)
    emb.grad_weights = tensor_zeros(emb.vocab_size, emb.dim)

fn embedding_get_vector(emb: Embedding, token_id: int) -> Tensor:
    vec := tensor_zeros(1, emb.dim)
    if token_id >= 0 and token_id < emb.vocab_size:
        tensor_copy_row(vec, 0, emb.weights, token_id)
    return vec
