// Cluster Standard Library: SafeTensors Module (std::ai::safetensors)
// Pure SafeTensors Header & Weight Offset Specification

const SAFETENSORS_MAGIC_LEN: int = 8

struct SafeTensorEntry:
    name: string
    dtype: string
    shape_dim0: int
    shape_dim1: int
    data_start: int
    data_end: int

fn is_safetensors_file(path: string) -> bool:
    flen := string_length(".safetensors")
    slen := string_length(path)
    if flen > slen:
        return false
    sub := substring(path, slen - flen, flen)
    return sub == ".safetensors"

fn safetensors_header_aligned(len: int) -> int:
    rem := (8 - ((8 + len) % 8)) % 8
    return len + rem

fn safetensors_dtype_size(dtype: string) -> int:
    if dtype == "F32" or dtype == "float32":
        return 4
    elif dtype == "F16" or dtype == "float16" or dtype == "BF16" or dtype == "bfloat16":
        return 2
    elif dtype == "I8" or dtype == "int8" or dtype == "U8" or dtype == "uint8":
        return 1
    return 4

fn safetensors_element_count(dim0: int, dim1: int) -> int:
    let mut d0: int = dim0
    if d0 <= 0:
        d0 = 1
    let mut d1: int = dim1
    if d1 <= 0:
        d1 = 1
    return d0 * d1

fn safetensors_byte_size(dim0: int, dim1: int, dtype: string) -> int:
    return safetensors_element_count(dim0, dim1) * safetensors_dtype_size(dtype)
