// ============================================================================
//  cl-ai-layernorm: Layer Normalization & RMSNorm Module
// ----------------------------------------------------------------------------
//  Activation normalization layers in pure Cluster:
//    * LayerNorm: y = (x - mean) / sqrt(var + eps) * gamma + beta
//    * RMSNorm:   y = x / sqrt(mean(x^2) + eps) * weight (LLaMA style)
//    * Numerically stable forward pass with analytical backward gradients
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct LayerNorm:
    dim: int
    eps: float
    gamma: Tensor
    beta: Tensor
    ggamma: Tensor
    gbeta: Tensor
    cached_x: Tensor
    cached_x_hat: Tensor
    cached_var_inv: Tensor

fn layernorm_new(dim: int, eps: float) -> LayerNorm:
    g := tensor_ones(1, dim)
    b := tensor_zeros(1, dim)
    gg := tensor_zeros(1, dim)
    gb := tensor_zeros(1, dim)
    cx := tensor_zeros(1, 1)
    cxhat := tensor_zeros(1, 1)
    cvi := tensor_zeros(1, 1)
    return LayerNorm(dim, eps, g, b, gg, gb, cx, cxhat, cvi)

fn layernorm_forward(ln: LayerNorm, x: Tensor) -> Tensor:
    ln.cached_x = x.clone()
    seq_len := x.rows()
    x_hat := tensor_zeros(seq_len, ln.dim)
    var_inv := tensor_zeros(seq_len, 1)
    out := tensor_zeros(seq_len, ln.dim)
    
    let mut r: int = 0
    let mut c: int = 0
    
    r = 0
    while r < seq_len:
        // Compute mean
        let mut sum_x: float = 0.0
        c = 0
        while c < ln.dim:
            sum_x = sum_x + x.get(r, c)
            c = c + 1
        mean := sum_x / to_float(ln.dim)
        
        // Compute variance
        let mut sum_sq: float = 0.0
        c = 0
        while c < ln.dim:
            d := x.get(r, c) - mean
            sum_sq = sum_sq + d * d
            c = c + 1
        variance := sum_sq / to_float(ln.dim)
        inv_std := 1.0 / sqrt(variance + ln.eps)
        tensor_set(var_inv, r, 0, inv_std)
        
        // Normalize & Scale
        c = 0
        while c < ln.dim:
            norm_val := (x.get(r, c) - mean) * inv_std
            tensor_set(x_hat, r, c, norm_val)
            scaled := norm_val * ln.gamma.get(0, c) + ln.beta.get(0, c)
            tensor_set(out, r, c, scaled)
            c = c + 1
        r = r + 1
        
    ln.cached_x_hat = x_hat
    ln.cached_var_inv = var_inv
    return out

fn layernorm_backward(ln: LayerNorm, grad_out: Tensor) -> Tensor:
    seq_len := grad_out.rows()
    gx := tensor_zeros(seq_len, ln.dim)
    
    let mut r: int = 0
    let mut c: int = 0
    
    // 1. Gradients for gamma and beta
    c = 0
    while c < ln.dim:
        let mut d_g: float = 0.0
        let mut d_b: float = 0.0
        r = 0
        while r < seq_len:
            d_g = d_g + grad_out.get(r, c) * ln.cached_x_hat.get(r, c)
            d_b = d_b + grad_out.get(r, c)
            r = r + 1
        tensor_set(ln.ggamma, 0, c, ln.ggamma.get(0, c) + d_g)
        tensor_set(ln.gbeta, 0, c, ln.gbeta.get(0, c) + d_b)
        c = c + 1
        
    // 2. Gradient for input X
    // dL/dx = (gamma / sqrt(var + eps)) * [grad_out - mean(grad_out) - x_hat * mean(grad_out * x_hat)]
    r = 0
    while r < seq_len:
        let mut sum_gy: float = 0.0
        let mut sum_gy_xhat: float = 0.0
        c = 0
        while c < ln.dim:
            gy := grad_out.get(r, c) * ln.gamma.get(0, c)
            sum_gy = sum_gy + gy
            sum_gy_xhat = sum_gy_xhat + gy * ln.cached_x_hat.get(r, c)
            c = c + 1
            
        inv_std := ln.cached_var_inv.get(r, 0)
        inv_d := 1.0 / to_float(ln.dim)
        
        c = 0
        while c < ln.dim:
            gy := grad_out.get(r, c) * ln.gamma.get(0, c)
            val := inv_std * (gy - inv_d * sum_gy - ln.cached_x_hat.get(r, c) * inv_d * sum_gy_xhat)
            tensor_set(gx, r, c, val)
            c = c + 1
        r = r + 1
        
    return gx

fn layernorm_zero_grad(ln: LayerNorm) -> void:
    tensor_free(ln.ggamma)
    tensor_free(ln.gbeta)
    ln.ggamma = tensor_zeros(1, ln.dim)
    ln.gbeta = tensor_zeros(1, ln.dim)

// ----------------------------------------------------------------------------
//  RMSNorm (Root Mean Square Normalization)
// ----------------------------------------------------------------------------

struct RMSNorm:
    dim: int
    eps: float
    weight: Tensor
    gweight: Tensor
    cached_x: Tensor
    cached_rms_inv: Tensor

fn rmsnorm_new(dim: int, eps: float) -> RMSNorm:
    w := tensor_ones(1, dim)
    gw := tensor_zeros(1, dim)
    cx := tensor_zeros(1, 1)
    crms := tensor_zeros(1, 1)
    return RMSNorm(dim, eps, w, gw, cx, crms)

fn rmsnorm_forward(rms: RMSNorm, x: Tensor) -> Tensor:
    rms.cached_x = x.clone()
    seq_len := x.rows()
    out := tensor_zeros(seq_len, rms.dim)
    rms_inv := tensor_zeros(seq_len, 1)
    
    let mut r: int = 0
    let mut c: int = 0
    
    r = 0
    while r < seq_len:
        let mut sum_sq: float = 0.0
        c = 0
        while c < rms.dim:
            v := x.get(r, c)
            sum_sq = sum_sq + v * v
            c = c + 1
        inv_rms := 1.0 / sqrt(sum_sq / to_float(rms.dim) + rms.eps)
        tensor_set(rms_inv, r, 0, inv_rms)
        c = 0
        while c < rms.dim:
            scaled := x.get(r, c) * inv_rms * rms.weight.get(0, c)
            tensor_set(out, r, c, scaled)
            c = c + 1
        r = r + 1
        
    rms.cached_rms_inv = rms_inv
    return out

fn rmsnorm_backward(rms: RMSNorm, grad_out: Tensor) -> Tensor:
    seq_len := grad_out.rows()
    gx := tensor_zeros(seq_len, rms.dim)
    
    let mut r: int = 0
    let mut c: int = 0
    
    c = 0
    while c < rms.dim:
        let mut d_w: float = 0.0
        r = 0
        while r < seq_len:
            norm_val := rms.cached_x.get(r, c) * rms.cached_rms_inv.get(r, 0)
            d_w = d_w + grad_out.get(r, c) * norm_val
            r = r + 1
        tensor_set(rms.gweight, 0, c, rms.gweight.get(0, c) + d_w)
        c = c + 1
        
    r = 0
    while r < seq_len:
        let mut sum_g_x: float = 0.0
        c = 0
        while c < rms.dim:
            sum_g_x = sum_g_x + grad_out.get(r, c) * rms.weight.get(0, c) * rms.cached_x.get(r, c)
            c = c + 1
            
        inv_rms := rms.cached_rms_inv.get(r, 0)
        c = 0
        while c < rms.dim:
            x_val := rms.cached_x.get(r, c)
            g_scaled := grad_out.get(r, c) * rms.weight.get(0, c)
            v := inv_rms * (g_scaled - x_val * inv_rms * inv_rms * sum_g_x / to_float(rms.dim))
            tensor_set(gx, r, c, v)
            c = c + 1
        r = r + 1
        
    return gx

fn rmsnorm_zero_grad(rms: RMSNorm) -> void:
    tensor_free(rms.gweight)
    rms.gweight = tensor_zeros(1, rms.dim)
