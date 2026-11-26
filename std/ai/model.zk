// Cluster Standard Library: AI Model Layer (std::ai)
// Zero-Training Weight Surgery & AI Parameter Analysis

const MODEL_FORMAT_UNKNOWN: int = 0
const MODEL_FORMAT_SAFETENSORS: int = 1
const MODEL_FORMAT_GGUF: int = 2

const DTYPE_F32: int = 0
const DTYPE_F16: int = 1
const DTYPE_BF16: int = 2
const DTYPE_Q4_0: int = 3
const DTYPE_Q8_0: int = 4

fn model_format_name(fmt: int) -> string:
    if fmt == MODEL_FORMAT_SAFETENSORS:
        return "SafeTensors (HuggingFace)"
    elif fmt == MODEL_FORMAT_GGUF:
        return "GGUF (llama.cpp)"
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
