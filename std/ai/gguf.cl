// Cluster Standard Library: GGUF Module (std::ai::gguf)
// llama.cpp / GGUF binary format constants, type layouts & dequantization

const GGUF_MAGIC: string = "GGUF"
const GGUF_VERSION_V2: int = 2
const GGUF_VERSION_V3: int = 3
const GGUF_DEFAULT_ALIGNMENT: int = 32

// GGUF Metadata Value Types
const GGUF_TYPE_UINT8: int = 0
const GGUF_TYPE_INT8: int = 1
const GGUF_TYPE_UINT16: int = 2
const GGUF_TYPE_INT16: int = 3
const GGUF_TYPE_UINT32: int = 4
const GGUF_TYPE_INT32: int = 5
const GGUF_TYPE_FLOAT32: int = 6
const GGUF_TYPE_BOOL: int = 7
const GGUF_TYPE_STRING: int = 8
const GGUF_TYPE_ARRAY: int = 9
const GGUF_TYPE_UINT64: int = 10
const GGUF_TYPE_INT64: int = 11
const GGUF_TYPE_FLOAT64: int = 12

// GGML Quantization Encodings
const GGML_TYPE_F32: int = 0
const GGML_TYPE_F16: int = 1
const GGML_TYPE_Q4_0: int = 2
const GGML_TYPE_Q4_1: int = 3
const GGML_TYPE_Q8_0: int = 8

// Block sizes in elements
const Q8_0_BLOCK_SIZE: int = 32
const Q4_0_BLOCK_SIZE: int = 32

struct GGUFTensorMeta:
    name: string
    n_dims: int
    dim0: int
    dim1: int
    quant_type: int
    offset: int

struct GGUFHeader:
    version: int
    tensor_count: int
    metadata_kv_count: int
    is_valid: bool

fn is_gguf_file(path: string) -> bool:
    flen := string_length(".gguf")
    slen := string_length(path)
    if flen > slen:
        return false
    sub := substring(path, slen - flen, flen)
    return sub == ".gguf"

fn gguf_align_offset(offset: int, alignment: int) -> int:
    rem := offset % alignment
    if rem == 0:
        return offset
    return offset + (alignment - rem)

fn gguf_type_name(t: int) -> string:
    if t == GGML_TYPE_F32:
        return "F32"
    elif t == GGML_TYPE_F16:
        return "F16"
    elif t == GGML_TYPE_Q4_0:
        return "Q4_0"
    elif t == GGML_TYPE_Q4_1:
        return "Q4_1"
    elif t == GGML_TYPE_Q8_0:
        return "Q8_0"
    return "UNKNOWN"

fn gguf_read_u32_le(raw: string, offset: int) -> int:
    b0 := byte_at(raw, offset)
    b1 := byte_at(raw, offset + 1)
    b2 := byte_at(raw, offset + 2)
    b3 := byte_at(raw, offset + 3)
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn gguf_read_u64_le(raw: string, offset: int) -> int:
    low := gguf_read_u32_le(raw, offset)
    high := gguf_read_u32_le(raw, offset + 4)
    return low + (high * 4294967296)

fn parse_gguf_header(raw_data: string) -> GGUFHeader:
    slen := string_length(raw_data)
    if slen < 24:
        return GGUFHeader(0, 0, 0, false)
    
    // Check magic: bytes 0..3 must match "GGUF" (0x47, 0x47, 0x55, 0x46)
    m0 := byte_at(raw_data, 0)
    m1 := byte_at(raw_data, 1)
    m2 := byte_at(raw_data, 2)
    m3 := byte_at(raw_data, 3)
    
    // 'G' = 71, 'U' = 85, 'F' = 70
    if m0 != 71 or m1 != 71 or m2 != 85 or m3 != 70:
        return GGUFHeader(0, 0, 0, false)
    
    version := gguf_read_u32_le(raw_data, 4)
    tensor_cnt := gguf_read_u64_le(raw_data, 8)
    meta_cnt := gguf_read_u64_le(raw_data, 16)
    
    return GGUFHeader(version, tensor_cnt, meta_cnt, true)

// Q8_0 Block Dequantization: 32 elements per block
// Each block has 1 fp16 scale factor 'd', and 32 int8 quantized weights
fn dequantize_q8_block(scale: float, &q_weights: vector[int]) -> vector[float]:
    out: vector[float] = []
    let mut i: int = 0
    sz := list_size(q_weights)
    while i < sz:
        val := to_float(q_weights[i]) * scale
        list_push(out, val)
        i = i + 1
    return out

// Q4_0 Block Dequantization: 32 elements packed into 16 bytes (nibbles)
// Each block has 1 fp16 scale factor 'd', and 16 bytes containing two 4-bit nibbles each (-8 to 7)
fn dequantize_q4_block(scale: float, &raw_nibbles: vector[int]) -> vector[float]:
    out: vector[float] = []
    let mut i: int = 0
    sz := list_size(raw_nibbles)
    while i < sz:
        byte_val := raw_nibbles[i]
        // Low 4 bits
        low := (byte_val % 16) - 8
        list_push(out, to_float(low) * scale)
        // High 4 bits
        high := (byte_val / 16) - 8
        list_push(out, to_float(high) * scale)
        i = i + 1
    return out
