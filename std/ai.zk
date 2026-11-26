// Cluster Standard Library: AI Model Layer (std::ai)
// Zero-Training Weight Surgery & AI Parameter Analysis

const MODEL_FORMAT_UNKNOWN: int = 0
const MODEL_FORMAT_SAFETENSORS: int = 1
const MODEL_FORMAT_GGUF: int = 2
const MODEL_FORMAT_CLM: int = 3

const DTYPE_F32: int = 0
const DTYPE_F16: int = 1
const DTYPE_BF16: int = 2
const DTYPE_Q4_0: int = 3
const DTYPE_Q8_0: int = 4

const CLM_QUANT_F32: int = 0
const CLM_QUANT_F16: int = 1
const CLM_QUANT_INT8: int = 2
const CLM_QUANT_INT4: int = 3
const CLM_QUANT_INT2: int = 4

fn model_format_name(fmt: int) -> string:
    if fmt == MODEL_FORMAT_SAFETENSORS:
        return "SafeTensors (HuggingFace)"
    elif fmt == MODEL_FORMAT_GGUF:
        return "GGUF (llama.cpp)"
    elif fmt == MODEL_FORMAT_CLM:
        return "CLM (Cluster Packed Binary)"
    return "Unknown"

fn model_dtype_name(dt: int) -> string:
    if dt == DTYPE_F32:
        return "F32"
    elif dt == DTYPE_F16:
        return "F16"
    elif dt == DTYPE_BF16:
        return "BF16"
    elif dt == DTYPE_Q4_0:
        return "Q4_0"
    elif dt == DTYPE_Q8_0:
        return "Q8_0"
    return "Unknown"

// Native AI Model Lifecycle (Zero-RAM mmap)
fn model_open(path: string) -> ptr:
    return ai_open(path)

fn model_close(m: ptr):
    ai_close(m)

fn model_format(m: ptr) -> int:
    return ai_format(m)

fn model_tensor_count(m: ptr) -> int:
    return ai_tensor_count(m)

fn model_total_params(m: ptr) -> int:
    return ai_total_params(m)

fn model_tensor_name(m: ptr, idx: int) -> string:
    return ai_tensor_name(m, idx)

fn model_tensor_rows(m: ptr, idx: int) -> int:
    return ai_tensor_rows(m, idx)

fn model_tensor_cols(m: ptr, idx: int) -> int:
    return ai_tensor_cols(m, idx)

fn model_tensor_elements(m: ptr, idx: int) -> int:
    return ai_tensor_elements(m, idx)

fn model_tensor_dtype(m: ptr, idx: int) -> int:
    return ai_tensor_dtype(m, idx)

// Native Tensor Extraction & Model Surgery
fn model_get_tensor(m: ptr, name: string) -> tensor:
    return ai_get_tensor(m, name)

fn model_cosine_similarity(a: tensor, b: tensor) -> float:
    return ai_cosine_similarity(a, b)

fn model_blend(student: tensor, teacher: tensor, alpha: float) -> tensor:
    return ai_blend(student, teacher, alpha)

fn model_merge(student_path: string, teacher_path: string, out_path: string, alpha: float) -> int:
    return ai_merge(student_path, teacher_path, out_path, alpha)

// CLM Compressed Packed Binary API
fn clm_model_open(path: string) -> ptr:
    return clm_open(path)

fn clm_model_embedded() -> ptr:
    return clm_open_embedded()

fn clm_model_close(m: ptr):
    clm_close(m)

fn clm_model_total_params(m: ptr) -> int:
    return clm_total_params(m)

fn clm_model_layers(m: ptr) -> int:
    return clm_num_layers(m)

fn clm_model_hidden_dim(m: ptr) -> int:
    return clm_hidden_dim(m)

fn clm_model_vocab_size(m: ptr) -> int:
    return clm_vocab_size(m)

fn clm_model_file_size(m: ptr) -> int:
    return clm_file_size(m)

fn clm_model_tensor_count(m: ptr) -> int:
    return clm_tensor_count(m)

fn clm_model_tensor_name(m: ptr, idx: int) -> string:
    return clm_tensor_name(m, idx)

fn clm_model_get_tensor(m: ptr, name: string) -> tensor:
    return clm_get_tensor(m, name)

fn clm_model_pack(in_path: string, out_path: string, quant_mode: int) -> int:
    return clm_pack(in_path, out_path, quant_mode)

fn clm_model_chat(m: ptr, prompt: string) -> string:
    return clm_chat(m, prompt)

fn clm_model_generate(m: ptr, prompt: string, max_tokens: int) -> string:
    return clm_generate(m, prompt, max_tokens)

// Milestone 18: Cluster AI Low-Rank Adapter (.clad) & Depth Mode
fn clm_model_attach_adaptor(m: ptr, path: string) -> int:
    return clm_attach_adaptor(m, path)

fn clm_model_detach_adaptor(m: ptr):
    clm_detach_adaptor(m)

fn clm_model_has_adaptor(m: ptr) -> bool:
    return clm_has_adaptor(m) != 0

fn clm_model_adaptor_rank(m: ptr) -> int:
    return clm_adaptor_rank(m)

fn clm_model_set_depth_mode(m: ptr, enabled: bool):
    if enabled:
        clm_set_depth_mode(m, 1)
    else:
        clm_set_depth_mode(m, 0)

fn clm_model_is_depth_mode(m: ptr) -> bool:
    return clm_is_depth_mode(m) != 0

fn clm_model_adapt(base_clm: string, orig_path: string, out_clad: string, rank: int) -> int:
    return clm_adapt(base_clm, orig_path, out_clad, rank)
