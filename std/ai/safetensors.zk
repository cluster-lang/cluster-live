// Cluster Standard Library: SafeTensors Module (std::ai::safetensors)
// SafeTensors format parsing utilities and tensor offsets

const SAFETENSORS_MAGIC_LEN: int = 8

fn is_safetensors_file(path: string) -> bool:
    return string_ends_with(path, ".safetensors")

fn safetensors_header_aligned(len: int) -> int:
    rem := (8 - ((8 + len) % 8)) % 8
    return len + rem
