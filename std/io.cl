// ==============================================================================
// Cluster Standard Library: I/O & File System Management (std/io.cl)
// Safe file operations, directory control, and path manipulation
// 100% Pure Cluster Language
// ==============================================================================

// Read entire file content into string
fn io_read(path: string) -> string:
    return file_read(path)

// Write string content to file (creates or overwrites)
fn io_write(path: string, content: string):
    file_write(path, content)

// Check if file or directory exists (1: true, 0: false)
fn io_exists(path: string) -> int:
    return file_exists(path)

// Append string content to existing file or create if absent
fn io_append(path: string, content: string):
    if file_exists(path) == 1:
        let existing: string = file_read(path)
        file_write(path, existing + content)
    else:
        file_write(path, content)

// Delete a file from disk
fn io_delete(path: string) -> int:
    return sys_run("rm -f \"" + path + "\"")

// Copy file from source to destination
fn io_copy(src: string, dst: string) -> int:
    return sys_run("cp \"" + src + "\" \"" + dst + "\"")

// Move or rename file
fn io_move(src: string, dst: string) -> int:
    return sys_run("mv \"" + src + "\" \"" + dst + "\"")

// Create directory and any missing parent directories
fn io_mkdir(path: string) -> int:
    return sys_run("mkdir -p \"" + path + "\"")

// Remove directory recursively
fn io_rmdir(path: string) -> int:
    return sys_run("rm -rf \"" + path + "\"")

// Join parent directory and filename with forward slash
fn io_path_join(dir: string, file: string) -> string:
    let dlen: int = len(dir)
    if dlen == 0:
        return file
    let last_ch: string = char_at(dir, dlen - 1)
    if last_ch == "/":
        return dir + file
    return dir + "/" + file

// Extract filename from path
fn io_path_basename(path: string) -> string:
    let plen: int = len(path)
    if plen == 0:
        return ""
    let mut i: int = plen - 1
    while i >= 0:
        let ch: string = char_at(path, i)
        if ch == "/":
            return substring(path, i + 1, plen - 1 - i)
        i = i - 1
    return path

// Extract directory from path
fn io_path_dirname(path: string) -> string:
    let plen: int = len(path)
    if plen == 0:
        return "."
    let mut i: int = plen - 1
    while i >= 0:
        let ch: string = char_at(path, i)
        if ch == "/":
            if i == 0:
                return "/"
            return substring(path, 0, i)
        i = i - 1
    return "."

// Extract file extension including dot (e.g. ".txt", ".cl")
fn io_path_extension(path: string) -> string:
    let base: string = io_path_basename(path)
    let blen: int = len(base)
    let mut i: int = blen - 1
    while i >= 0:
        let ch: string = char_at(base, i)
        if ch == ".":
            return substring(base, i, blen - i)
        i = i - 1
    return ""
