// ============================================================================
//  cl-ai-loss: Loss Functions & Analytical Gradients Module
// ----------------------------------------------------------------------------
//  Production loss functions for transformer and neural network training:
//    * Cross-Entropy Loss with numerically stable Log-Softmax (Language Modeling)
//    * Mean Squared Error Loss (MSE) for regression
//    * Binary Cross-Entropy Loss (BCE) for binary classification
//    * Analytical closed-form gradient computation
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

fn cross_entropy_loss(logits: Tensor, targets: vector[int]) -> float:
    seq_len := logits.rows()
    vocab_size := logits.cols()
    let mut total_loss: float = 0.0
    
    let mut r: int = 0
    while r < seq_len:
        target_idx := targets[r]
        if target_idx >= 0 and target_idx < vocab_size:
            // Find max for numerical stability
            let mut max_val: float = logits.get(r, 0)
            let mut c: int = 1
            while c < vocab_size:
                v := logits.get(r, c)
                if v > max_val:
                    max_val = v
                c = c + 1
                
            // Compute sum of exp
            let mut sum_exp: float = 0.0
            c = 0
            while c < vocab_size:
                sum_exp = sum_exp + exp(logits.get(r, c) - max_val)
                c = c + 1
                
            // log(softmax(x_target)) = x_target - max - log(sum_exp)
            log_prob := (logits.get(r, target_idx) - max_val) - log(sum_exp)
            total_loss = total_loss - log_prob
        r = r + 1
        
    return total_loss / to_float(seq_len)

fn cross_entropy_backward(logits: Tensor, targets: vector[int]) -> Tensor:
    // Analytical gradient of Cross-Entropy + Softmax:
    // dL/dz_{i,j} = (p_{i,j} - y_{i,j}) / seq_len
    seq_len := logits.rows()
    vocab_size := logits.cols()
    probs := logits.softmax()
    inv_s := 1.0 / to_float(seq_len)
    
    let mut r: int = 0
    while r < seq_len:
        target_idx := targets[r]
        let mut c: int = 0
        while c < vocab_size:
            p := probs.get(r, c)
            let mut grad_val: float = p
            if c == target_idx:
                grad_val = grad_val - 1.0
            tensor_set(probs, r, c, grad_val * inv_s)
            c = c + 1
        r = r + 1
        
    return probs

fn mse_loss(preds: Tensor, targets: Tensor) -> float:
    diff := preds - targets
    n := preds.size()
    let mut sum_sq: float = 0.0
    let mut r: int = 0
    while r < preds.rows():
        let mut c: int = 0
        while c < preds.cols():
            d := diff.get(r, c)
            sum_sq = sum_sq + d * d
            c = c + 1
        r = r + 1
    tensor_free(diff)
    return sum_sq / to_float(n)

fn mse_backward(preds: Tensor, targets: Tensor) -> Tensor:
    diff := preds - targets
    scale := 2.0 / to_float(preds.size())
    grad := diff * scale
    tensor_free(diff)
    return grad

fn bce_loss(preds: Tensor, targets: Tensor) -> float:
    let mut total: float = 0.0
    n := preds.size()
    eps := 0.0000001
    let mut r: int = 0
    while r < preds.rows():
        let mut c: int = 0
        while c < preds.cols():
            p := preds.get(r, c)
            y := targets.get(r, c)
            // Clamp p for numerical stability
            let mut p_c: float = p
            if p_c < eps:
                p_c = eps
            if p_c > 1.0 - eps:
                p_c = 1.0 - eps
            total = total - (y * log(p_c) + (1.0 - y) * log(1.0 - p_c))
            c = c + 1
        r = r + 1
    return total / to_float(n)

fn bce_backward(preds: Tensor, targets: Tensor) -> Tensor:
    grad := tensor_zeros(preds.rows(), preds.cols())
    n := preds.size()
    inv_n := 1.0 / to_float(n)
    eps := 0.0000001
    let mut r: int = 0
    while r < preds.rows():
        let mut c: int = 0
        while c < preds.cols():
            p := preds.get(r, c)
            y := targets.get(r, c)
            let mut p_c: float = p
            if p_c < eps:
                p_c = eps
            if p_c > 1.0 - eps:
                p_c = 1.0 - eps
            // dL/dp = (p - y) / (p * (1 - p)) * (1/n)
            g := ((p_c - y) / (p_c * (1.0 - p_c))) * inv_n
            tensor_set(grad, r, c, g)
            c = c + 1
        r = r + 1
    return grad
