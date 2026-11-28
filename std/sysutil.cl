// Cluster Standard Library: POSIX System, Process, Time & Argparse Utilities (std/sysutil)
// Pure Cluster wrappers over libc POSIX syscalls and compiler runtime builtins.

extern fn getenv(name: ptr) -> ptr
extern fn getcwd(buf: ptr, sz: int) -> ptr
extern fn clock_gettime(clk_id: int, ts: ptr) -> int
extern fn usleep(usec: int) -> int
extern fn popen(cmd: ptr, mode: ptr) -> ptr
extern fn pclose(fp: ptr) -> int
extern fn fread(buf: ptr, sz: int, cnt: int, fp: ptr) -> int
extern fn open(pathname: ptr, flags: i32, mode: i32) -> i32
extern fn close(fd: i32) -> i32
extern fn lseek(fd: i32, offset: int, whence: i32) -> int
extern fn read(fd: i32, buf: ptr, count: int) -> int
extern fn write(fd: i32, buf: ptr, count: int) -> int
extern fn mkdir(pathname: ptr, mode: i32) -> i32
extern fn unlink(pathname: ptr) -> i32

fn sys_env_get(name: string) -> string:
    p := getenv(str_cstr(name))
    if p == null:
        return ""
    return cstr_to_str(p)

fn sys_cwd() -> string:
    buf := mem_alloc(4096)
    p := getcwd(buf, 4096)
    out := ""
    if p != null:
        out = cstr_to_str(p)
    mem_free(buf)
    return out

fn sys_time_ns() -> int:
    ts := mem_alloc(16)
    clock_gettime(0, ts)
    sec := ptr_read(ts)
    nsec := ptr_read(ptr_add(ts, 8))
    mem_free(ts)
    return sec * 1000000000 + nsec

fn sys_time_ms() -> int:
    return sys_time_ns() / 1000000

fn sys_time_s() -> float:
    ns := sys_time_ns()
    return float(ns) / 1000000000.0

fn sys_mono_ms() -> int:
    ts := mem_alloc(16)
    clock_gettime(1, ts)
    sec := ptr_read(ts)
    nsec := ptr_read(ptr_add(ts, 8))
    mem_free(ts)
    return sec * 1000 + nsec / 1000000

fn sys_sleep_ms(ms: int):
    if ms > 0:
        usleep(ms * 1000)

fn sys_exec_capture(cmd: string) -> string:
    fp := popen(str_cstr(cmd), str_cstr("r"))
    if fp == null:
        return ""
    cap := 65536
    buf := mem_alloc(cap)
    total := 0
    while 1 == 1:
        if total + 4096 + 1 > cap:
            ncap := cap * 2
            nbuf := mem_realloc(buf, ncap)
            if nbuf == null:
                break
            buf = nbuf
            cap = ncap
        got := fread(ptr_add(buf, total), 1, 4096, fp)
        if got <= 0:
            break
        total = total + got
    pclose(fp)
    ptr_write_u8(ptr_add(buf, total), 0)
    out := ""
    if total > 0:
        out = str_from_parts(buf, total)
    mem_free(buf)
    return out

fn sys_posix_open_ro(path: string) -> i32:
    return open(str_cstr(path), 0, 0)

fn sys_posix_open_wo_trunc(path: string) -> i32:
    // O_WRONLY|O_CREAT|O_TRUNC = 1 | 64 | 512 = 577, mode 0644 = 420
    return open(str_cstr(path), 577, 420)

fn sys_posix_lseek(fd: i32, off: int, whence: int) -> int:
    return lseek(fd, off, whence)

fn sys_posix_read(fd: i32, buf: ptr, n: int) -> int:
    return read(fd, buf, n)

fn sys_posix_write(fd: i32, buf: ptr, n: int) -> int:
    return write(fd, buf, n)

fn sys_posix_close(fd: i32) -> i32:
    return close(fd)

fn sys_unlink(path: string) -> int:
    if path == "":
        return 0
    return unlink(str_cstr(path))

fn sys_mkdir_p(path: string) -> int:
    if path == "" or fs_is_dir(path) == 1:
        return 0
    n := string_length(path)
    cur := ""
    i := 0
    while i < n:
        c := byte_at(path, i)
        cur = cur + char_at(path, i)
        if c == 47 and cur != "/":
            if fs_is_dir(cur) == 0:
                mkdir(str_cstr(cur), 493)
        i = i + 1
    if fs_is_dir(path) == 0:
        return mkdir(str_cstr(path), 493)
    return 0

fn sys_arg_has(flag: string) -> int:
    n := sys_argc()
    i := 0
    while i < n:
        if sys_arg(i) == flag:
            return 1
        i = i + 1
    return 0

fn sys_arg_get(key: string, dflt: string) -> string:
    n := sys_argc()
    pref := key + "="
    plen := string_length(pref)
    i := 0
    while i < n:
        a := sys_arg(i)
        if a == key and i + 1 < n:
            return sys_arg(i + 1)
        if string_length(a) > plen and substring(a, 0, plen) == pref:
            return substring(a, plen, string_length(a) - plen)
        i = i + 1
    return dflt

fn sys_arg_get_int(key: string, dflt: int) -> int:
    v := sys_arg_get(key, "")
    if v == "":
        return dflt
    return to_int(v)

fn sys_arg_get_float(key: string, dflt: float) -> float:
    v := sys_arg_get(key, "")
    if v == "":
        return dflt
    return to_float(v)

fn sys_arg_pos(idx: int, dflt: string) -> string:
    n := sys_argc()
    pos := 0
    i := 0
    while i < n:
        a := sys_arg(i)
        if string_length(a) > 0 and byte_at(a, 0) == 45:
            if string_contains(a, "=") == 0 and i + 1 < n:
                nx := sys_arg(i + 1)
                if string_length(nx) > 0 and byte_at(nx, 0) != 45:
                    i = i + 1
        else:
            if pos == idx:
                return a
            pos = pos + 1
        i = i + 1
    return dflt

fn sys_str_trim(s: string) -> string:
    n := string_length(s)
    if n == 0:
        return ""
    a := 0
    while a < n:
        b := byte_at(s, a)
        if b != 32 and b != 9 and b != 10 and b != 13:
            break
        a = a + 1
    e := n
    while e > a:
        b := byte_at(s, e - 1)
        if b != 32 and b != 9 and b != 10 and b != 13:
            break
        e = e - 1
    return substring(s, a, e - a)

fn sys_str_starts(s: string, pref: string) -> int:
    ls := string_length(s)
    lp := string_length(pref)
    if lp > ls:
        return 0
    if lp == 0:
        return 1
    if substring(s, 0, lp) == pref:
        return 1
    return 0

fn sys_str_ends(s: string, suf: string) -> int:
    ls := string_length(s)
    lf := string_length(suf)
    if lf > ls:
        return 0
    if lf == 0:
        return 1
    if substring(s, ls - lf, lf) == suf:
        return 1
    return 0

fn sys_str_find_from(hay: string, pat: string, start: int) -> int:
    nh := string_length(hay)
    np := string_length(pat)
    if np == 0:
        return start
    if start < 0:
        start = 0
    limit := nh - np
    i := start
    while i <= limit:
        if substring(hay, i, np) == pat:
            return i
        i = i + 1
    return -1

fn sys_str_replace(s: string, old: string, rep: string) -> string:
    lo := string_length(old)
    if lo == 0:
        return s
    ls := string_length(s)
    out := ""
    i := 0
    while i < ls:
        if i + lo <= ls and substring(s, i, lo) == old:
            out = out + rep
            i = i + lo
        else:
            out = out + char_at(s, i)
            i = i + 1
    return out

fn sys_str_split(s: string, sep: string) -> vector[string]:
    res := vector[string]()
    ls := string_length(s)
    lsep := string_length(sep)
    if lsep == 0:
        list_push(res, s)
        return res
    start := 0
    while start <= ls:
        idx := sys_str_find_from(s, sep, start)
        if idx < 0:
            list_push(res, substring(s, start, ls - start))
            break
        list_push(res, substring(s, start, idx - start))
        start = idx + lsep
    return res

fn sys_str_split_lines(s: string) -> vector[string]:
    return sys_str_split(sys_str_replace(s, "\r\n", "\n"), "\n")

fn sys_str_lower(s: string) -> string:
    n := string_length(s)
    out := ""
    i := 0
    while i < n:
        b := byte_at(s, i)
        if b >= 65 and b <= 90:
            out = out + chr(b + 32)
        else:
            out = out + char_at(s, i)
        i = i + 1
    return out

fn sys_path_join(a: string, b: string) -> string:
    if a == "" or a == ".":
        return b
    if b == "":
        return a
    if byte_at(b, 0) == 47:
        return b
    la := string_length(a)
    if byte_at(a, la - 1) == 47:
        return a + b
    return a + "/" + b

fn sys_path_basename(p: string) -> string:
    n := string_length(p)
    if n == 0:
        return ""
    i := n - 1
    while i >= 0:
        if byte_at(p, i) == 47:
            return substring(p, i + 1, n - i - 1)
        i = i - 1
    return p

fn sys_path_dirname(p: string) -> string:
    n := string_length(p)
    i := n - 1
    while i >= 0:
        if byte_at(p, i) == 47:
            if i == 0:
                return "/"
            return substring(p, 0, i)
        i = i - 1
    return "."

fn sys_int_to_hex(val: int, width: int) -> string:
    hex_chars := "0123456789abcdef"
    if val == 0:
        out := "0"
        while string_length(out) < width:
            out = "0" + out
        return out
    v := val
    neg := 0
    if v < 0:
        neg = 1
        v = 0 - v
    out := ""
    while v > 0:
        nib := v & 15
        out = char_at(hex_chars, nib) + out
        v = v >> 4
    while string_length(out) < width:
        out = "0" + out
    if neg == 1:
        out = "-" + out
    return out

fn sys_hex_to_int(s: string) -> int:
    t := sys_str_lower(sys_str_trim(s))
    if sys_str_starts(t, "0x") == 1:
        t = substring(t, 2, string_length(t) - 2)
    res := 0
    n := string_length(t)
    i := 0
    while i < n:
        c := byte_at(t, i)
        d := 0
        if c >= 48 and c <= 57:
            d = c - 48
        elif c >= 97 and c <= 102:
            d = c - 87
        else:
            i = i + 1
            continue
        res = (res << 4) | d
        i = i + 1
    return res

fn sys_glob_suffix(dir: string, suf: string) -> vector[string]:
    out := vector[string]()
    if fs_is_dir(dir) == 0:
        return out
    entries := fs_list_dir(dir)
    i := 0
    while i < list_size(entries):
        name := entries[(i)]
        if suf == "" or sys_str_ends(name, suf) == 1:
            list_push(out, sys_path_join(dir, name))
        i = i + 1
    return out
