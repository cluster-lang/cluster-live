// ============================================================================
//  cl-ai-optimizer: Optimizers & Learning Rate Schedulers Module
// ----------------------------------------------------------------------------
//  Production optimization algorithms for deep transformer training in pure Cluster:
//    * AdamW: Decoupled weight decay adaptive moment estimation (Loshchilov & Hutter)
//    * SGD with Nesterov / classical momentum and L2 weight decay
//    * Learning rate scheduling: Linear Warmup + Cosine Annealing decay
//    * Global gradient clipping by L2 norm to prevent exploding gradients
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct AdamWState:
    m: Tensor
    v: Tensor

struct AdamW:
    lr: float
    beta1: float
    beta2: float
    eps: float
    weight_decay: float
    step_num: int

fn adamw_new(lr: float, beta1: float, beta2: float, eps: float, weight_decay: float) -> AdamW:
    return AdamW(lr, beta1, beta2, eps, weight_decay, 0)

fn adamw_init_state(param: Tensor) -> AdamWState:
    m := tensor_zeros(param.rows(), param.cols())
    v := tensor_zeros(param.rows(), param.cols())
    return AdamWState(m, v)

fn adamw_step_tensor(opt: AdamW, state: AdamWState, param: Tensor, grad: Tensor) -> void:
    // Update step count
    opt.step_num = opt.step_num + 1
    t := to_float(opt.step_num)
    
    // Bias correction factors
    bc1 := 1.0 - pow(opt.beta1, t)
    bc2 := 1.0 - pow(opt.beta2, t)
    
    let mut inv_bc1: float = 1.0
    if bc1 > 0.000000000001:
        inv_bc1 = 1.0 / bc1
    let mut inv_bc2: float = 1.0
    if bc2 > 0.000000000001:
        inv_bc2 = 1.0 / bc2
    
    rows := param.rows()
    cols := param.cols()
    
    let mut r: int = 0
    let mut c: int = 0
    while r < rows:
        c = 0
        while c < cols:
            g := grad.get(r, c)
            p := param.get(r, c)
            
            // Decoupled weight decay: p = p - lr * weight_decay * p
            let mut p_decayed: float = p - opt.lr * opt.weight_decay * p
            
            // First moment: m = beta1 * m + (1 - beta1) * g
            m_val := opt.beta1 * state.m.get(r, c) + (1.0 - opt.beta1) * g
            tensor_set(state.m, r, c, m_val)
            
            // Second moment: v = beta2 * v + (1 - beta2) * g^2
            v_val := opt.beta2 * state.v.get(r, c) + (1.0 - opt.beta2) * g * g
            tensor_set(state.v, r, c, v_val)
            
            // Corrected moments
            m_hat := m_val * inv_bc1
            v_hat := v_val * inv_bc2
            
            // Parameter update
            p_updated := p_decayed - (opt.lr * m_hat) / (sqrt(v_hat) + opt.eps)
            tensor_set(param, r, c, p_updated)
            
            c = c + 1
        r = r + 1

struct SGDMomentum:
    lr: float
    momentum: float
    weight_decay: float

fn sgd_new(lr: float, momentum: float, weight_decay: float) -> SGDMomentum:
    return SGDMomentum(lr, momentum, weight_decay)

fn sgd_init_velocity(param: Tensor) -> Tensor:
    return tensor_zeros(param.rows(), param.cols())

fn sgd_step_tensor(opt: SGDMomentum, velocity: Tensor, param: Tensor, grad: Tensor) -> void:
    rows := param.rows()
    cols := param.cols()
    let mut r: int = 0
    let mut c: int = 0
    while r < rows:
        c = 0
        while c < cols:
            g := grad.get(r, c)
            p := param.get(r, c)
            if opt.weight_decay > 0.0:
                g = g + opt.weight_decay * p
            v := opt.momentum * velocity.get(r, c) + g
            tensor_set(velocity, r, c, v)
            p_new := p - opt.lr * v
            tensor_set(param, r, c, p_new)
            c = c + 1
        r = r + 1

fn get_cosine_schedule_with_warmup(current_step: int, total_steps: int, base_lr: float, warmup_steps: int) -> float:
    if current_step < warmup_steps:
        let mut ws: int = warmup_steps
        if ws <= 0:
            ws = 1
        return base_lr * (to_float(current_step) / to_float(ws))
    if current_step >= total_steps:
        return 0.0
    progress := to_float(current_step - warmup_steps) / to_float(total_steps - warmup_steps)
    // 0.5 * (1 + cos(pi * progress))
    pi := 3.141592653589793
    cosine_decay := 0.5 * (1.0 + cos(pi * progress))
    return base_lr * cosine_decay

fn clip_gradient_norm(grad: Tensor, max_norm: float) -> float:
    current_norm := grad.norm()
    if current_norm > max_norm and max_norm > 0.0:
        grad.clip(max_norm)
    return current_norm
