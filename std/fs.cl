// Cluster Standard Library: POSIX Filesystem Utilities (std/fs)
// Zero-fork wrappers around native runtime POSIX calls in libcluster_rt.so.
// Note: Builtins fs_mkdir_p, fs_mtime_ns, fs_copy_file, fs_remove, fs_realpath,
// fs_list_dir, fs_is_dir are also directly available in any Cluster program.

fn ensure_dir(path: string) -> int:
    return fs_mkdir_p(path)

fn file_mtime_ns(path: string) -> int:
    return fs_mtime_ns(path)

fn copy_file(src: string, dst: string) -> int:
    return fs_copy_file(src, dst)

fn remove_file(path: string) -> int:
    return fs_remove(path)

fn real_path(path: string) -> string:
    return fs_realpath(path)

fn list_dir(path: string) -> vector[string]:
    return fs_list_dir(path)

fn dir_exists(path: string) -> int:
    return fs_is_dir(path)

fn path_exists(path: string) -> int:
    return file_exists(path)

fn read_text(path: string) -> string:
    return file_read(path)

fn write_text(path: string, content: string) -> int:
    return file_write(path, content)
