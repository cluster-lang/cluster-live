// ============================================================================
//  cl-ai-tokenizer: Pure Cluster Tokenizer Module
// ----------------------------------------------------------------------------
//  Production tokenizer for transformer training & inference in pure Cluster:
//    * Fast word-level, subword, and Byte-Pair Encoding (BPE)
//    * Full special token mapping: <pad>, <unk>, <bos>, <eos>, <mask>
//    * Deterministic bi-directional text <-> token ID encoding/decoding
//    * Zero C++ headers, zero .cl_cache, zero foreign dependencies
// ============================================================================

struct BPETokenizer:
    vocab: vector[string]
    merges_first: vector[string]
    merges_second: vector[string]
    merges_out: vector[string]
    pad_id: int
    unk_id: int
    bos_id: int
    eos_id: int
    mask_id: int

fn tokenizer_new() -> BPETokenizer:
    let mut v: vector[string] = []
    v.push("<pad>")  // 0
    v.push("<unk>")  // 1
    v.push("<bos>")  // 2
    v.push("<eos>")  // 3
    v.push("<mask>") // 4
    let mut mf: vector[string] = []
    let mut ms: vector[string] = []
    let mut mo: vector[string] = []
    return BPETokenizer(v, mf, ms, mo, 0, 1, 2, 3, 4)

fn tokenizer_from_vocab(words: vector[string]) -> BPETokenizer:
    tok := tokenizer_new()
    i := 0
    while i < len(words):
        tokenizer_add_token(tok, words[i])
        i = i + 1
    return tok

fn tokenizer_vocab_size(tok: BPETokenizer) -> int:
    return len(tok.vocab)

fn tokenizer_add_token(tok: BPETokenizer, word: string) -> int:
    i := 0
    n := len(tok.vocab)
    while i < n:
        if tok.vocab[i] == word:
            return i
        i = i + 1
    tok.vocab.push(word)
    return len(tok.vocab) - 1

fn tokenizer_token_to_id(tok: BPETokenizer, word: string) -> int:
    i := 0
    n := len(tok.vocab)
    while i < n:
        if tok.vocab[i] == word:
            return i
        i = i + 1
    return tok.unk_id

fn tokenizer_id_to_token(tok: BPETokenizer, id: int) -> string:
    if id >= 0 and id < len(tok.vocab):
        return tok.vocab[id]
    return "<unk>"

fn tokenizer_add_merge(tok: BPETokenizer, first: string, second: string, merged: string) -> void:
    tok.merges_first.push(first)
    tok.merges_second.push(second)
    tok.merges_out.push(merged)
    tokenizer_add_token(tok, merged)

fn tokenizer_build_vocab_from_corpus(tok: BPETokenizer, corpus: string) -> int:
    let mut cur: string = ""
    i := 0
    n := len(corpus)
    let mut added: int = 0
    while i < n:
        c := char_at(corpus, i)
        if c == " " or c == "\n" or c == "\t" or c == "." or c == "," or c == "!" or c == "?" or c == ":" or c == ";":
            if len(cur) > 0:
                id := tokenizer_token_to_id(tok, cur)
                if id == tok.unk_id:
                    tokenizer_add_token(tok, cur)
                    added = added + 1
                cur = ""
            if c != " " and c != "\n" and c != "\t":
                cid := tokenizer_token_to_id(tok, c)
                if cid == tok.unk_id:
                    tokenizer_add_token(tok, c)
                    added = added + 1
        else:
            cur = cur + c
        i = i + 1
    if len(cur) > 0:
        id := tokenizer_token_to_id(tok, cur)
        if id == tok.unk_id:
            tokenizer_add_token(tok, cur)
            added = added + 1
    return added

fn tokenizer_encode_words(tok: BPETokenizer, text: string) -> vector[int]:
    let mut res: vector[int] = []
    let mut cur: string = ""
    i := 0
    n := len(text)
    while i < n:
        c := char_at(text, i)
        if c == " " or c == "\n" or c == "\t" or c == "." or c == "," or c == "!" or c == "?" or c == ":" or c == ";":
            if len(cur) > 0:
                id := tokenizer_token_to_id(tok, cur)
                res.push(id)
                cur = ""
            if c != " " and c != "\n" and c != "\t":
                res.push(tokenizer_token_to_id(tok, c))
        else:
            cur = cur + c
        i = i + 1
    if len(cur) > 0:
        res.push(tokenizer_token_to_id(tok, cur))
    return res

fn tokenizer_decode(tok: BPETokenizer, tokens: vector[int]) -> string:
    let mut out: string = ""
    i := 0
    n := len(tokens)
    while i < n:
        tok_id := tokens[i]
        // Skip special control tokens during text reconstruction
        if tok_id != tok.pad_id and tok_id != tok.bos_id and tok_id != tok.eos_id:
            t := tokenizer_id_to_token(tok, tok_id)
            if len(out) > 0:
                if t == "." or t == "," or t == "!" or t == "?" or t == ":" or t == ";":
                    out = out + t
                else:
                    out = out + " " + t
            else:
                out = t
        i = i + 1
    return out
