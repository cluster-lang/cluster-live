// Cluster Standard Library: x86-64 Disassembler & Safe-Patch Validator (std/x86_disasm)
// Replaces external capstone dependency with pure-Cluster x86-64 machine-code decoding.

import "std/binpack.cl"

model X86Insn:
    mnemonic: string
    op_str: string
    size: int
    has_mem: int
    valid: int

model X86PatchCheck:
    ok: int
    reason: string
    disasm: string

fn _x86_reg_name(reg: int, is64: int, is8: int) -> string:
    r := reg & 15
    if is8 == 1:
        if r == 0: return "al"
        if r == 1: return "cl"
        if r == 2: return "dl"
        if r == 3: return "bl"
        if r == 4: return "spl"
        if r == 5: return "bpl"
        if r == 6: return "sil"
        if r == 7: return "dil"
        return "r" + to_text(r) + "b"
    if is64 == 1:
        if r == 0: return "rax"
        if r == 1: return "rcx"
        if r == 2: return "rdx"
        if r == 3: return "rbx"
        if r == 4: return "rsp"
        if r == 5: return "rbp"
        if r == 6: return "rsi"
        if r == 7: return "rdi"
        return "r" + to_text(r)
    if r == 0: return "eax"
    if r == 1: return "ecx"
    if r == 2: return "edx"
    if r == 3: return "ebx"
    if r == 4: return "esp"
    if r == 5: return "ebp"
    if r == 6: return "esi"
    if r == 7: return "edi"
    return "r" + to_text(r) + "d"

fn _x86_decode_modrm_len(bs: vector[int], pos: int, n: int, has_sib_mem: int) -> int:
    if pos >= n:
        return -1
    modrm := bs[(pos)] & 255
    md := (modrm >> 6) & 3
    rm := modrm & 7
    extra := 1
    if md != 3 and rm == 4:
        if pos + extra >= n:
            return -1
        sib := bs[(pos + extra)] & 255
        extra = extra + 1
        base := sib & 7
        if md == 0 and base == 5:
            extra = extra + 4
    elif md == 0 and rm == 5:
        extra = extra + 4
    if md == 1:
        extra = extra + 1
    elif md == 2:
        extra = extra + 4
    if pos + extra > n:
        return -1
    return extra

fn _x86_fmt_mem(modrm: int, bs: vector[int], modrm_pos: int, rex_b: int) -> string:
    md := (modrm >> 6) & 3
    rm := modrm & 7
    if md == 3:
        return ""
    if rm == 4:
        sib := bs[(modrm_pos + 1)] & 255
        base := (sib & 7) | (rex_b * 8)
        idx := (sib >> 3) & 7
        if md == 0 and (sib & 7) == 5 and idx == 4:
            disp := (bs[(modrm_pos + 2)] | (bs[(modrm_pos + 3)] << 8) | (bs[(modrm_pos + 4)] << 16) | (bs[(modrm_pos + 5)] << 24))
            return "[0x" + sys_int_to_hex(disp, 1) + "]"
        return "[" + _x86_reg_name(base, 1, 0) + "+...]"
    if md == 0 and rm == 5:
        return "[rip+disp32]"
    reg := rm | (rex_b * 8)
    if md == 0:
        return "[" + _x86_reg_name(reg, 1, 0) + "]"
    if md == 1:
        d8 := bs[(modrm_pos + 1)] & 255
        return "[" + _x86_reg_name(reg, 1, 0) + " + 0x" + sys_int_to_hex(d8, 1) + "]"
    return "[" + _x86_reg_name(reg, 1, 0) + " + disp32]"

fn x86_decode_insn(bs: vector[int], start: int) -> X86Insn:
    n := list_size(bs)
    if start >= n:
        return X86Insn("", "", 0, 0, 0)
    pos := start
    rep := 0
    seg_pfx := ""
    opsz := 0
    while pos < n:
        b := bs[(pos)] & 255
        if b == 243 or b == 242:
            rep = b
            pos = pos + 1
        elif b == 102:
            opsz = 1
            pos = pos + 1
        elif b == 103 or b == 240:
            pos = pos + 1
        elif b == 62 or b == 46 or b == 38 or b == 54:
            pos = pos + 1
        elif b == 100:
            seg_pfx = "fs:"
            pos = pos + 1
        elif b == 101:
            seg_pfx = "gs:"
            pos = pos + 1
        else:
            break
    rex := 0
    if pos < n:
        rb := bs[(pos)] & 255
        if rb >= 64 and rb <= 79:
            rex = rb
            pos = pos + 1
    if pos >= n:
        return X86Insn("", "", 0, 0, 0)
    rex_w := (rex >> 3) & 1
    rex_r := (rex >> 2) & 1
    rex_b := rex & 1

    op := bs[(pos)] & 255
    pos = pos + 1

    // 1-byte NOP
    if op == 144:
        return X86Insn("nop", "", pos - start, 0, 1)
    // ret, hlt, cli, sti, int3
    if op == 195:
        return X86Insn("ret", "", pos - start, 0, 1)
    if op == 203:
        return X86Insn("retf", "", pos - start, 0, 1)
    if op == 207:
        return X86Insn("iretq", "", pos - start, 0, 1)
    if op == 244:
        return X86Insn("hlt", "", pos - start, 0, 1)
    if op == 250:
        return X86Insn("cli", "", pos - start, 0, 1)
    if op == 251:
        return X86Insn("sti", "", pos - start, 0, 1)
    if op == 204:
        return X86Insn("int3", "", pos - start, 0, 1)
    if op == 205:
        if pos >= n:
            return X86Insn("", "", 0, 0, 0)
        return X86Insn("int", "0x" + sys_int_to_hex(bs[(pos)] & 255, 1), pos + 1 - start, 0, 1)
    // rep movsb (f3 a4)
    if op == 164:
        mnem := "movsb"
        if rep == 243:
            mnem = "rep movsb"
        return X86Insn(mnem, "", pos - start, 1, 1)
    // push/pop r64 (50..5f)
    if op >= 80 and op <= 87:
        return X86Insn("push", _x86_reg_name((op - 80) | (rex_b * 8), 1, 0), pos - start, 0, 1)
    if op >= 88 and op <= 95:
        return X86Insn("pop", _x86_reg_name((op - 88) | (rex_b * 8), 1, 0), pos - start, 0, 1)
    // mov reg, imm32/64 (b8..bf)
    if op >= 184 and op <= 191:
        isz := 4
        if rex_w == 1:
            isz = 8
        elif opsz == 1:
            isz = 2
        if pos + isz > n:
            return X86Insn("", "", 0, 0, 0)
        imm := 0
        k := isz - 1
        while k >= 0:
            imm = (imm << 8) | (bs[(pos + k)] & 255)
            k = k - 1
        reg := _x86_reg_name((op - 184) | (rex_b * 8), rex_w, 0)
        return X86Insn("mov", reg + ", 0x" + sys_int_to_hex(imm, 1), pos + isz - start, 0, 1)
    // jcc rel8 (70..7f)
    if op >= 112 and op <= 127:
        if pos >= n:
            return X86Insn("", "", 0, 0, 0)
        return X86Insn("jne", "rel8", pos + 1 - start, 0, 1)
    if op == 235:
        if pos >= n:
            return X86Insn("", "", 0, 0, 0)
        return X86Insn("jmp", "rel8", pos + 1 - start, 0, 1)
    if op == 232 or op == 233:
        if pos + 4 > n:
            return X86Insn("", "", 0, 0, 0)
        mn := "call"
        if op == 233:
            mn = "jmp"
        return X86Insn(mn, "rel32", pos + 4 - start, 0, 1)

    // Two-byte 0f ...
    if op == 15:
        if pos >= n:
            return X86Insn("", "", 0, 0, 0)
        op2 := bs[(pos)] & 255
        pos = pos + 1
        if op2 == 11:
            return X86Insn("ud2", "", pos - start, 0, 1)
        if op2 == 5:
            return X86Insn("syscall", "", pos - start, 0, 1)
        if op2 == 185 or op2 == 255:
            ml := _x86_decode_modrm_len(bs, pos, n, 0)
            if ml < 0:
                return X86Insn("", "", 0, 0, 0)
            mrm := bs[(pos)] & 255
            mn := "ud1"
            if op2 == 255:
                mn = "ud0"
            r1 := _x86_reg_name(((mrm >> 3) & 7) | (rex_r * 8), rex_w, 0)
            r2 := _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 0)
            return X86Insn(mn, r1 + ", " + r2, pos + ml - start, 0, 1)
        if op2 == 177:
            ml := _x86_decode_modrm_len(bs, pos, n, 0)
            if ml < 0:
                return X86Insn("", "", 0, 0, 0)
            mrm := bs[(pos)] & 255
            md := (mrm >> 6) & 3
            r1 := _x86_reg_name(((mrm >> 3) & 7) | (rex_r * 8), rex_w, 0)
            if md == 3:
                return X86Insn("cmpxchg", _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 0) + ", " + r1, pos + ml - start, 0, 1)
            mem := seg_pfx + _x86_fmt_mem(mrm, bs, pos, rex_b)
            return X86Insn("cmpxchg", mem + ", " + r1, pos + ml - start, 1, 1)
        if op2 == 31:
            ml := _x86_decode_modrm_len(bs, pos, n, 0)
            if ml < 0:
                return X86Insn("", "", 0, 0, 0)
            return X86Insn("nop", "", pos + ml - start, 0, 1)
        if op2 >= 32 and op2 <= 35:
            ml := _x86_decode_modrm_len(bs, pos, n, 0)
            if ml < 0:
                return X86Insn("", "", 0, 0, 0)
            return X86Insn("mov", "cr0, rax", pos + ml - start, 0, 1)
        if op2 == 1:
            if pos < n:
                sub := bs[(pos)] & 255
                if sub == 216:
                    return X86Insn("vmrun", "", pos + 1 - start, 0, 1)
                if sub == 217:
                    return X86Insn("vmmcall", "", pos + 1 - start, 0, 1)
        if op2 >= 128 and op2 <= 143:
            if pos + 4 > n:
                return X86Insn("", "", 0, 0, 0)
            return X86Insn("jne", "rel32", pos + 4 - start, 0, 1)
        return X86Insn("", "", 0, 0, 0)

    // Standard ModRM ALU/MOV: xor (31, 33), mov (89, 8b), add/sub (01, 29)
    if op == 49 or op == 51 or op == 137 or op == 139 or op == 1 or op == 41:
        ml := _x86_decode_modrm_len(bs, pos, n, 0)
        if ml < 0:
            return X86Insn("", "", 0, 0, 0)
        mrm := bs[(pos)] & 255
        md := (mrm >> 6) & 3
        r_reg := _x86_reg_name(((mrm >> 3) & 7) | (rex_r * 8), rex_w, 0)
        mn := "mov"
        if op == 49 or op == 51:
            mn = "xor"
        elif op == 1:
            mn = "add"
        elif op == 41:
            mn = "sub"
        if md == 3:
            rm_reg := _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 0)
            if op == 51 or op == 139:
                return X86Insn(mn, r_reg + ", " + rm_reg, pos + ml - start, 0, 1)
            return X86Insn(mn, rm_reg + ", " + r_reg, pos + ml - start, 0, 1)
        mem := seg_pfx + _x86_fmt_mem(mrm, bs, pos, rex_b)
        if op == 51 or op == 139:
            return X86Insn(mn, r_reg + ", " + mem, pos + ml - start, 1, 1)
        return X86Insn(mn, mem + ", " + r_reg, pos + ml - start, 1, 1)

    // Group 1 imm8 (83)
    if op == 131:
        ml := _x86_decode_modrm_len(bs, pos, n, 0)
        if ml < 0 or pos + ml + 1 > n:
            return X86Insn("", "", 0, 0, 0)
        mrm := bs[(pos)] & 255
        md := (mrm >> 6) & 3
        subop := (mrm >> 3) & 7
        mn := "add"
        if subop == 4:
            mn = "and"
        elif subop == 5:
            mn = "sub"
        elif subop == 7:
            mn = "cmp"
        imm8 := bs[(pos + ml)] & 255
        if md == 3:
            dst := _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 0)
            return X86Insn(mn, dst + ", 0x" + sys_int_to_hex(imm8, 1), pos + ml + 1 - start, 0, 1)
        return X86Insn(mn, _x86_fmt_mem(mrm, bs, pos, rex_b) + ", 0x" + sys_int_to_hex(imm8, 1), pos + ml + 1 - start, 1, 1)

    // c6 /0 mov byte imm8, c7 /0 mov dword imm32
    if op == 198 or op == 199:
        isz := 1
        if op == 199:
            isz = 4
        ml := _x86_decode_modrm_len(bs, pos, n, 0)
        if ml < 0 or pos + ml + isz > n:
            return X86Insn("", "", 0, 0, 0)
        mrm := bs[(pos)] & 255
        md := (mrm >> 6) & 3
        imm := 0
        k := isz - 1
        while k >= 0:
            imm = (imm << 8) | (bs[(pos + ml + k)] & 255)
            k = k - 1
        if md == 3:
            dst := _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 1 - (isz / 4))
            return X86Insn("mov", dst + ", 0x" + sys_int_to_hex(imm, 1), pos + ml + isz - start, 0, 1)
        return X86Insn("mov", _x86_fmt_mem(mrm, bs, pos, rex_b) + ", 0x" + sys_int_to_hex(imm, 1), pos + ml + isz - start, 1, 1)

    // f7 div / idiv / neg / not
    if op == 247:
        ml := _x86_decode_modrm_len(bs, pos, n, 0)
        if ml < 0:
            return X86Insn("", "", 0, 0, 0)
        mrm := bs[(pos)] & 255
        md := (mrm >> 6) & 3
        subop := (mrm >> 3) & 7
        mn := "div"
        if subop == 7:
            mn = "idiv"
        elif subop == 3:
            mn = "neg"
        elif subop == 2:
            mn = "not"
        if md == 3:
            return X86Insn(mn, _x86_reg_name((mrm & 7) | (rex_b * 8), rex_w, 0), pos + ml - start, 0, 1)
        return X86Insn(mn, _x86_fmt_mem(mrm, bs, pos, rex_b), pos + ml - start, 1, 1)

    return X86Insn("", "", 0, 0, 0)

fn x86_disasm_hex(hex_str: string) -> string:
    bs := bin_hex_to_bytes(hex_str)
    n := list_size(bs)
    if n == 0:
        return "<invalid>"
    off := 0
    out := ""
    cnt := 0
    while off < n:
        ins := x86_decode_insn(bs, off)
        if ins.valid == 0 or ins.size <= 0:
            break
        part := ins.mnemonic
        if ins.op_str != "":
            part = part + " " + ins.op_str
        if cnt > 0:
            out = out + "; "
        out = out + part
        off = off + ins.size
        cnt = cnt + 1
    if out == "":
        return "<invalid>"
    return out

fn _x86_is_forbidden_mnem(m: string) -> int:
    if m == "jmp" or m == "call" or m == "ret" or m == "retf" or m == "iretq":
        return 1
    if m == "int" or m == "int3" or m == "syscall" or m == "hlt" or m == "cli" or m == "sti":
        return 1
    if m == "vmrun" or m == "vmmcall" or m == "ud2" or m == "ud1" or m == "ud0":
        return 1
    if m == "jne" or m == "je" or m == "div" or m == "idiv":
        return 1
    return 0

fn x86_validate_safe_patch(patch_hex: string, expected_len: int) -> X86PatchCheck:
    raw := bin_hex_to_bytes(patch_hex)
    rlen := list_size(raw)
    if rlen != expected_len:
        return X86PatchCheck(0, "patch_len=" + to_text(rlen) + " != fault_len=" + to_text(expected_len), "")
    if rlen == 0 or rlen > 15:
        return X86PatchCheck(0, "patch_len out of range: " + to_text(rlen), "")
    off := 0
    dis_parts := ""
    cnt := 0
    while off < rlen:
        ins := x86_decode_insn(raw, off)
        if ins.valid == 0 or ins.size <= 0:
            break
        if _x86_is_forbidden_mnem(ins.mnemonic) == 1:
            return X86PatchCheck(0, "forbidden mnemonic in patch: " + ins.mnemonic, "")
        if string_contains(ins.op_str, "cr0") == 1 or string_contains(ins.op_str, "fs:") == 1 or string_contains(ins.op_str, "gs:") == 1:
            return X86PatchCheck(0, "forbidden privileged operand: " + ins.mnemonic + " " + ins.op_str, "")
        if ins.has_mem == 1 or string_contains(ins.op_str, "[") == 1:
            return X86PatchCheck(0, "memory operand disallowed in safe patch: " + ins.mnemonic + " " + ins.op_str, "")
        part := ins.mnemonic
        if ins.op_str != "":
            part = part + " " + ins.op_str
        if cnt > 0:
            dis_parts = dis_parts + "; "
        dis_parts = dis_parts + part
        off = off + ins.size
        cnt = cnt + 1
    if off != rlen:
        return X86PatchCheck(0, "invalid x86-64 instruction encoding (decoded " + to_text(off) + "/" + to_text(rlen) + " bytes)", "")
    return X86PatchCheck(1, "ok", dis_parts)
