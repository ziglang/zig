pub const windows = @import("windows.zig");
pub const darwin = @import("darwin.zig");
pub const linux = @import("linux.zig");
pub const posix = switch(@compileVar("os")) {
    Os.linux => linux,
    Os.darwin, Os.macosx, Os.ios => darwin,
    Os.windows => windows,
    else => @compileError("Unsupported OS"),
};

pub const max_noalloc_path_len = 1024;
pub const ChildProcess = @import("child_process.zig").ChildProcess;
pub const path = @import("path.zig");

pub const line_sep = switch (@compileVar("os")) {
    Os.windows => "\r\n",
    else => "\n",
};

const debug = @import("../debug.zig");
const assert = debug.assert;

const errno = @import("errno.zig");
const linking_libc = @import("../target.zig").linking_libc;
const c = @import("../c/index.zig");

const mem = @import("../mem.zig");
const Allocator = mem.Allocator;

const BufMap = @import("../buf_map.zig").BufMap;
const cstr = @import("../cstr.zig");

const io = @import("../io.zig");
const base64 = @import("../base64.zig");

error Unexpected;
error SystemResources;
error AccessDenied;
error InvalidExe;
error FileSystem;
error IsDir;
error FileNotFound;
error FileBusy;
error PathAlreadyExists;
error SymLinkLoop;
error ReadOnlyFileSystem;
error LinkQuotaExceeded;
error RenameAcrossMountPoints;

/// Fills `buf` with random bytes. If linking against libc, this calls the
/// appropriate OS-specific library call. Otherwise it uses the zig standard
/// library implementation.
pub fn getRandomBytes(buf: []u8) -> %void {
    while (true) {
        const err = switch (@compileVar("os")) {
            Os.linux => {
                if (linking_libc) {
                    if (c.getrandom(buf.ptr, buf.len, 0) == -1) *c._errno() else 0
                } else {
                    posix.getErrno(posix.getrandom(buf.ptr, buf.len, 0))
                }
            },
            Os.darwin, Os.macosx, Os.ios => {
                if (linking_libc) {
                    if (posix.getrandom(buf.ptr, buf.len) == -1) *c._errno() else 0
                } else {
                    posix.getErrno(posix.getrandom(buf.ptr, buf.len))
                }
            },
            Os.windows => {
                var hCryptProv: windows.HCRYPTPROV = undefined;
                if (!windows.CryptAcquireContext(&hCryptProv, null, null, windows.PROV_RSA_FULL, 0)) {
                    return error.Unexpected;
                }
                defer _ = windows.CryptReleaseContext(hCryptProv, 0);

                if (!windows.CryptGenRandom(hCryptProv, windows.DWORD(buf.len), buf.ptr)) {
                    return error.Unexpected;
                }
                return;
            },
            else => @compileError("Unsupported OS"),
        };
        if (err > 0) {
            return switch (err) {
                errno.EINVAL => unreachable,
                errno.EFAULT => unreachable,
                errno.EINTR  => continue,
                else         => error.Unexpected,
            }
        }
        return;
    }
}

/// Raises a signal in the current kernel thread, ending its execution.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it uses the zig standard library implementation.
pub coldcc fn abort() -> noreturn {
    if (linking_libc) {
        c.abort();
    }
    switch (@compileVar("os")) {
        Os.linux, Os.darwin, Os.macosx, Os.ios => {
            _ = posix.raise(posix.SIGABRT);
            _ = posix.raise(posix.SIGKILL);
            while (true) {}
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Calls POSIX close, and keeps trying if it gets interrupted.
pub fn posixClose(fd: i32) {
    while (true) {
        const err = posix.getErrno(posix.close(fd));
        if (err == errno.EINTR) {
            continue;
        } else {
            return;
        }
    }
}

/// Calls POSIX write, and keeps trying if it gets interrupted.
pub fn posixWrite(fd: i32, bytes: []const u8) -> %void {
    while (true) {
        const write_ret = posix.write(fd, bytes.ptr, bytes.len);
        const write_err = posix.getErrno(write_ret);
        if (write_err > 0) {
            return switch (write_err) {
                errno.EINTR  => continue,
                errno.EINVAL => unreachable,
                errno.EDQUOT => error.DiskQuota,
                errno.EFBIG  => error.FileTooBig,
                errno.EIO    => error.Io,
                errno.ENOSPC => error.NoSpaceLeft,
                errno.EPERM  => error.BadPerm,
                errno.EPIPE  => error.PipeFail,
                else         => error.Unexpected,
            }
        }
        return;
    }
}


/// ::file_path may need to be copied in memory to add a null terminating byte. In this case
/// a fixed size buffer of size ::max_noalloc_path_len is an attempted solution. If the fixed
/// size buffer is too small, and the provided allocator is null, ::error.NameTooLong is returned.
/// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
/// Calls POSIX open, keeps trying if it gets interrupted, and translates
/// the return value into zig errors.
pub fn posixOpen(file_path: []const u8, flags: usize, perm: usize, allocator: ?&Allocator) -> %i32 {
    var stack_buf: [max_noalloc_path_len]u8 = undefined;
    var path0: []u8 = undefined;
    var need_free = false;

    if (file_path.len < stack_buf.len) {
        path0 = stack_buf[0...file_path.len + 1];
    } else if (const a ?= allocator) {
        path0 = %return a.alloc(u8, file_path.len + 1);
        need_free = true;
    } else {
        return error.NameTooLong;
    }
    defer if (need_free) {
        (??allocator).free(path0);
    };
    mem.copy(u8, path0, file_path);
    path0[file_path.len] = 0;

    while (true) {
        const result = posix.open(path0.ptr, flags, perm);
        const err = posix.getErrno(result);
        if (err > 0) {
            return switch (err) {
                errno.EINTR => continue,

                errno.EFAULT => unreachable,
                errno.EINVAL => unreachable,
                errno.EACCES => error.BadPerm,
                errno.EFBIG, errno.EOVERFLOW => error.FileTooBig,
                errno.EISDIR => error.IsDir,
                errno.ELOOP => error.SymLinkLoop,
                errno.EMFILE => error.ProcessFdQuotaExceeded,
                errno.ENAMETOOLONG => error.NameTooLong,
                errno.ENFILE => error.SystemFdQuotaExceeded,
                errno.ENODEV => error.NoDevice,
                errno.ENOENT => error.PathNotFound,
                errno.ENOMEM => error.SystemResources,
                errno.ENOSPC => error.NoSpaceLeft,
                errno.ENOTDIR => error.NotDir,
                errno.EPERM => error.BadPerm,
                else => error.Unexpected,
            }
        }
        return i32(result);
    }
}

pub fn posixDup2(old_fd: i32, new_fd: i32) -> %void {
    while (true) {
        const err = posix.getErrno(posix.dup2(old_fd, new_fd));
        if (err > 0) {
            return switch (err) {
                errno.EBUSY, errno.EINTR => continue,
                errno.EMFILE => error.ProcessFdQuotaExceeded,
                errno.EINVAL => unreachable,
                else => error.Unexpected,
            };
        }
        return;
    }
}

/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// Also make the first arg equal to exe_path.
/// This function also uses the PATH environment variable to get the full path to the executable.
pub fn posixExecve(exe_path: []const u8, argv: []const []const u8, env_map: &const BufMap,
    allocator: &Allocator) -> %void
{
    const argv_buf = %return allocator.alloc(?&const u8, argv.len + 2);
    mem.set(?&const u8, argv_buf, null);
    defer {
        for (argv_buf) |arg| {
            const arg_buf = if (const ptr ?= arg) ptr[0...cstr.len(ptr)] else break;
            allocator.free(arg_buf);
        }
        allocator.free(argv_buf);
    }
    {
        // Add exe_path to the first argument.
        const arg_buf = %return allocator.alloc(u8, exe_path.len + 1);
        @memcpy(&arg_buf[0], exe_path.ptr, exe_path.len);
        arg_buf[exe_path.len] = 0;

        argv_buf[0] = arg_buf.ptr;
    }
    for (argv) |arg, i| {
        const arg_buf = %return allocator.alloc(u8, arg.len + 1);
        @memcpy(&arg_buf[0], arg.ptr, arg.len);
        arg_buf[arg.len] = 0;

        argv_buf[i + 1] = arg_buf.ptr;
    }
    argv_buf[argv.len + 1] = null;

    const envp_count = env_map.count();
    const envp_buf = %return allocator.alloc(?&const u8, envp_count + 1);
    mem.set(?&const u8, envp_buf, null);
    defer {
        for (envp_buf) |env| {
            const env_buf = if (const ptr ?= env) ptr[0...cstr.len(ptr)] else break;
            allocator.free(env_buf);
        }
        allocator.free(envp_buf);
    }
    {
        var it = env_map.iterator();
        var i: usize = 0;
        while (true; i += 1) {
            const pair = it.next() ?? break;

            const env_buf = %return allocator.alloc(u8, pair.key.len + pair.value.len + 2);
            @memcpy(&env_buf[0], pair.key.ptr, pair.key.len);
            env_buf[pair.key.len] = '=';
            @memcpy(&env_buf[pair.key.len + 1], pair.value.ptr, pair.value.len);
            env_buf[env_buf.len - 1] = 0;

            envp_buf[i] = env_buf.ptr;
        }
        assert(i == envp_count);
    }
    envp_buf[envp_count] = null;


    if (mem.indexOfScalar(u8, exe_path, '/') != null) {
        // +1 for the null terminating byte
        const path_buf = %return allocator.alloc(u8, exe_path.len + 1);
        defer allocator.free(path_buf);
        @memcpy(&path_buf[0], &exe_path[0], exe_path.len);
        path_buf[exe_path.len] = 0;
        return posixExecveErrnoToErr(posix.getErrno(posix.execve(path_buf.ptr, argv_buf.ptr, envp_buf.ptr)));
    }

    const PATH = getEnv("PATH") ?? "/usr/local/bin:/bin/:/usr/bin";
    // PATH.len because it is >= the largest search_path
    // +1 for the / to join the search path and exe_path
    // +1 for the null terminating byte
    const path_buf = %return allocator.alloc(u8, PATH.len + exe_path.len + 2);
    defer allocator.free(path_buf);
    var it = mem.split(PATH, ':');
    var seen_eacces = false;
    var err: usize = undefined;
    while (true) {
        const search_path = it.next() ?? break;
        mem.copy(u8, path_buf, search_path);
        path_buf[search_path.len] = '/';
        mem.copy(u8, path_buf[search_path.len + 1 ...], exe_path);
        path_buf[search_path.len + exe_path.len + 2] = 0;
        err = posix.getErrno(posix.execve(path_buf.ptr, argv_buf.ptr, envp_buf.ptr));
        assert(err > 0);
        if (err == errno.EACCES) {
            seen_eacces = true;
        } else if (err != errno.ENOENT) {
            return posixExecveErrnoToErr(err);
        }
    }
    if (seen_eacces) {
        err = errno.EACCES;
    }
    return posixExecveErrnoToErr(err);
}

fn posixExecveErrnoToErr(err: usize) -> error {
    assert(err > 0);
    return switch (err) {
        errno.EFAULT => unreachable,
        errno.E2BIG, errno.EMFILE, errno.ENAMETOOLONG, errno.ENFILE, errno.ENOMEM => error.SystemResources,
        errno.EACCES, errno.EPERM => error.AccessDenied,
        errno.EINVAL, errno.ENOEXEC => error.InvalidExe,
        errno.EIO, errno.ELOOP => error.FileSystem,
        errno.EISDIR => error.IsDir,
        errno.ENOENT => error.FileNotFound,
        errno.ENOTDIR => error.NotDir,
        errno.ETXTBSY => error.FileBusy,
        else => error.Unexpected,
    };
}

pub var environ_raw: []&u8 = undefined;

pub fn getEnvMap(allocator: &Allocator) -> %BufMap {
    var result = BufMap.init(allocator);
    %defer result.deinit();

    for (environ_raw) |ptr| {
        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '='; line_i += 1) {}
        const key = ptr[0...line_i];

        var end_i: usize = line_i;
        while (ptr[end_i] != 0; end_i += 1) {}
        const value = ptr[line_i + 1...end_i];

        %return result.set(key, value);
    }
    return result;
}

pub fn getEnv(key: []const u8) -> ?[]const u8 {
    for (environ_raw) |ptr| {
        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '='; line_i += 1) {}
        const this_key = ptr[0...line_i];
        if (!mem.eql(u8, key, this_key))
            continue;

        var end_i: usize = line_i;
        while (ptr[end_i] != 0; end_i += 1) {}
        const this_value = ptr[line_i + 1...end_i];

        return this_value;
    }
    return null;
}

pub const args = struct {
    pub var raw: []&u8 = undefined;

    pub fn count() -> usize {
        return raw.len;
    }
    pub fn at(i: usize) -> []const u8 {
        const s = raw[i];
        return s[0...cstr.len(s)];
    }
};

/// Caller must free the returned memory.
pub fn getCwd(allocator: &Allocator) -> %[]u8 {
    var buf = %return allocator.alloc(u8, 1024);
    %defer allocator.free(buf);
    while (true) {
        const err = posix.getErrno(posix.getcwd(buf.ptr, buf.len));
        if (err == errno.ERANGE) {
            buf = %return allocator.realloc(u8, buf, buf.len * 2);
            continue;
        } else if (err > 0) {
            return error.Unexpected;
        }

        return buf;
    }
}

pub fn symLink(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    const full_buf = %return allocator.alloc(u8, existing_path.len + new_path.len + 2);
    defer allocator.free(full_buf);

    const existing_buf = full_buf;
    mem.copy(u8, existing_buf, existing_path);
    existing_buf[existing_path.len] = 0;

    const new_buf = full_buf[existing_path.len + 1...];
    mem.copy(u8, new_buf, new_path);
    new_buf[new_path.len] = 0;

    const err = posix.getErrno(posix.symlink(existing_buf.ptr, new_buf.ptr));
    if (err > 0) {
        return switch (err) {
            errno.EFAULT, errno.EINVAL => unreachable,
            errno.EACCES, errno.EPERM => error.AccessDenied,
            errno.EDQUOT => error.DiskQuota,
            errno.EEXIST => error.PathAlreadyExists,
            errno.EIO => error.FileSystem,
            errno.ELOOP => error.SymLinkLoop,
            errno.ENAMETOOLONG => error.NameTooLong,
            errno.ENOENT => error.FileNotFound,
            errno.ENOTDIR => error.NotDir,
            errno.ENOMEM => error.SystemResources,
            errno.ENOSPC => error.NoSpaceLeft,
            errno.EROFS => error.ReadOnlyFileSystem,
            else => error.Unexpected,
        };
    }
}

// here we replace the standard +/ with -_ so that it can be used in a file name
const b64_fs_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=";

pub fn atomicSymLink(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    try (symLink(allocator, existing_path, new_path)) {
        return;
    } else |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    }

    var rand_buf: [12]u8 = undefined;
    const tmp_path = %return allocator.alloc(u8, new_path.len + base64.calcEncodedSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0...], new_path);
    while (true) {
        %return getRandomBytes(rand_buf[0...]);
        _ = base64.encodeWithAlphabet(tmp_path[new_path.len...], rand_buf, b64_fs_alphabet);
        try (symLink(allocator, existing_path, tmp_path)) {
            return rename(allocator, tmp_path, new_path);
        } else |err| {
            if (err == error.PathAlreadyExists) {
                continue;
            } else {
                return err;
            }
        }
    }

}

pub fn deleteFile(allocator: &Allocator, file_path: []const u8) -> %void {
    const buf = %return allocator.alloc(u8, file_path.len + 1);
    defer allocator.free(buf);

    mem.copy(u8, buf, file_path);
    buf[file_path.len] = 0;

    const err = posix.getErrno(posix.unlink(buf.ptr));
    if (err > 0) {
        return switch (err) {
            errno.EACCES, errno.EPERM => error.AccessDenied,
            errno.EBUSY => error.FileBusy,
            errno.EFAULT, errno.EINVAL => unreachable,
            errno.EIO => error.FileSystem,
            errno.EISDIR => error.IsDir,
            errno.ELOOP => error.SymLinkLoop,
            errno.ENAMETOOLONG => error.NameTooLong,
            errno.ENOENT => error.FileNotFound,
            errno.ENOTDIR => error.NotDir,
            errno.ENOMEM => error.SystemResources,
            errno.EROFS => error.ReadOnlyFileSystem,
            else => error.Unexpected,
        };
    }
}

pub fn copyFile(allocator: &Allocator, source_path: []const u8, dest_path: []const u8) -> %void {
    var in_stream = %return io.InStream.open(source_path, allocator);
    defer in_stream.close();
    var out_stream = %return io.OutStream.open(dest_path, allocator);
    defer out_stream.close();

    const buf = out_stream.buffer[0...];
    while (true) {
        const amt = %return in_stream.read(buf);
        out_stream.index = amt;
        %return out_stream.flush();
        if (amt != out_stream.buffer.len)
            return;
    }
}

pub fn rename(allocator: &Allocator, old_path: []const u8, new_path: []const u8) -> %void {
    const full_buf = %return allocator.alloc(u8, old_path.len + new_path.len + 2);
    defer allocator.free(full_buf);

    const old_buf = full_buf;
    mem.copy(u8, old_buf, old_path);
    old_buf[old_path.len] = 0;

    const new_buf = full_buf[old_path.len + 1...];
    mem.copy(u8, new_buf, new_path);
    new_buf[new_path.len] = 0;

    const err = posix.getErrno(posix.rename(old_buf.ptr, new_buf.ptr));
    if (err > 0) {
        return switch (err) {
            errno.EACCES, errno.EPERM => error.AccessDenied,
            errno.EBUSY => error.FileBusy,
            errno.EDQUOT => error.DiskQuota,
            errno.EFAULT, errno.EINVAL => unreachable,
            errno.EISDIR => error.IsDir,
            errno.ELOOP => error.SymLinkLoop,
            errno.EMLINK => error.LinkQuotaExceeded,
            errno.ENAMETOOLONG => error.NameTooLong,
            errno.ENOENT => error.FileNotFound,
            errno.ENOTDIR => error.NotDir,
            errno.ENOMEM => error.SystemResources,
            errno.ENOSPC => error.NoSpaceLeft,
            errno.EEXIST, errno.ENOTEMPTY => error.PathAlreadyExists,
            errno.EROFS => error.ReadOnlyFileSystem,
            errno.EXDEV => error.RenameAcrossMountPoints,
            else => error.Unexpected,
        };
    }
}

pub fn makeDir(allocator: &Allocator, dir_path: []const u8) -> %void {
    const path_buf = %return allocator.alloc(u8, dir_path.len + 1);
    defer allocator.free(path_buf);

    mem.copy(u8, path_buf, dir_path);
    path_buf[dir_path.len] = 0;

    const err = posix.getErrno(posix.mkdir(path_buf.ptr, 0o755));
    if (err > 0) {
        return switch (err) {
            errno.EACCES, errno.EPERM => error.AccessDenied,
            errno.EDQUOT => error.DiskQuota,
            errno.EEXIST => error.PathAlreadyExists,
            errno.EFAULT => unreachable,
            errno.ELOOP => error.SymLinkLoop,
            errno.EMLINK => error.LinkQuotaExceeded,
            errno.ENAMETOOLONG => error.NameTooLong,
            errno.ENOENT => error.FileNotFound,
            errno.ENOMEM => error.SystemResources,
            errno.ENOSPC => error.NoSpaceLeft,
            errno.ENOTDIR => error.NotDir,
            errno.EROFS => error.ReadOnlyFileSystem,
            else => error.Unexpected,
        };
    }
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
pub fn makePath(allocator: &Allocator, full_path: []const u8) -> %void {
    const child_dir = %return path.dirname(allocator, full_path);
    defer allocator.free(child_dir);

    if (mem.eql(u8, child_dir, full_path))
        return;

    makePath(allocator, child_dir) %% |err| {
        if (err != error.PathAlreadyExists)
            return err;
    };

    makeDir(allocator, full_path) %% |err| {
        if (err != error.PathAlreadyExists)
            return err;
        // TODO stat the file and return an error if it's not a directory
    };
}
