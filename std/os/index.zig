const std = @import("../index.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const is_windows = builtin.os == Os.windows;
const os = this;

pub const windows = @import("windows/index.zig");
pub const darwin = @import("darwin.zig");
pub const linux = @import("linux.zig");
pub const posix = switch(builtin.os) {
    Os.linux => linux,
    Os.darwin, Os.macosx, Os.ios => darwin,
    else => @compileError("Unsupported OS"),
};

pub const max_noalloc_path_len = 1024;
pub const ChildProcess = @import("child_process.zig").ChildProcess;
pub const path = @import("path.zig");

pub const line_sep = switch (builtin.os) {
    Os.windows => "\r\n",
    else => "\n",
};

pub const page_size = 4 * 1024;

pub const UserInfo = @import("get_user_id.zig").UserInfo;
pub const getUserInfo = @import("get_user_id.zig").getUserInfo;

const windows_util = @import("windows/util.zig");
pub const windowsWaitSingle = windows_util.windowsWaitSingle;
pub const windowsWrite = windows_util.windowsWrite;
pub const windowsIsCygwinPty = windows_util.windowsIsCygwinPty;
pub const windowsOpen = windows_util.windowsOpen;
pub const windowsLoadDll = windows_util.windowsLoadDll;
pub const windowsUnloadDll = windows_util.windowsUnloadDll; 
pub const createWindowsEnvBlock = windows_util.createWindowsEnvBlock;

pub const FileHandle = if (is_windows) windows.HANDLE else i32;

const debug = std.debug;
const assert = debug.assert;

const c = std.c;

const mem = std.mem;
const Allocator = mem.Allocator;

const BufMap = std.BufMap;
const cstr = std.cstr;

const io = std.io;
const base64 = std.base64;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const math = std.math;

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
error DirNotEmpty;
error WouldBlock;

/// Fills `buf` with random bytes. If linking against libc, this calls the
/// appropriate OS-specific library call. Otherwise it uses the zig standard
/// library implementation.
pub fn getRandomBytes(buf: []u8) -> %void {
    switch (builtin.os) {
        Os.linux => while (true) {
            // TODO check libc version and potentially call c.getrandom.
            // See #397
            const err = posix.getErrno(posix.getrandom(buf.ptr, buf.len, 0));
            if (err > 0) {
                return switch (err) {
                    posix.EINVAL => unreachable,
                    posix.EFAULT => unreachable,
                    posix.EINTR  => continue,
                    else         => unexpectedErrorPosix(err),
                };
            }
            return;
        },
        Os.darwin, Os.macosx, Os.ios => {
            const fd = %return posixOpen("/dev/urandom", posix.O_RDONLY|posix.O_CLOEXEC,
                0, null);
            defer close(fd);

            %return posixRead(fd, buf);
        },
        Os.windows => {
            var hCryptProv: windows.HCRYPTPROV = undefined;
            if (windows.CryptAcquireContextA(&hCryptProv, null, null, windows.PROV_RSA_FULL, 0) == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    else => unexpectedErrorWindows(err),
                };
            }
            defer _ = windows.CryptReleaseContext(hCryptProv, 0);

            if (windows.CryptGenRandom(hCryptProv, windows.DWORD(buf.len), buf.ptr) == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    else => unexpectedErrorWindows(err),
                };
            }
        },
        else => @compileError("Unsupported OS"),
    }
}

test "os.getRandomBytes" {
    var buf: [50]u8 = undefined;
    %%getRandomBytes(buf[0..]);
}

/// Raises a signal in the current kernel thread, ending its execution.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it uses the zig standard library implementation.
pub coldcc fn abort() -> noreturn {
    if (builtin.link_libc) {
        c.abort();
    }
    switch (builtin.os) {
        Os.linux, Os.darwin, Os.macosx, Os.ios => {
            _ = posix.raise(posix.SIGABRT);
            _ = posix.raise(posix.SIGKILL);
            while (true) {}
        },
        Os.windows => {
            if (builtin.mode == builtin.Mode.Debug) {
                @breakpoint();
            }
            windows.ExitProcess(3);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Exits the program cleanly with the specified status code.
pub coldcc fn exit(status: i32) -> noreturn {
    if (builtin.link_libc) {
        c.exit(status);
    }
    switch (builtin.os) {
        Os.linux, Os.darwin, Os.macosx, Os.ios => {
            posix.exit(status);
        },
        Os.windows => {
            // Map a possibly negative status code to a non-negative status for the systems default
            // integer width.
            const p_status = if (@sizeOf(c_uint) < @sizeOf(u32))
                @truncate(c_uint, @bitCast(u32, status))
            else
                c_uint(@bitCast(u32, status));

            windows.ExitProcess(p_status);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Closes the file handle. Keeps trying if it gets interrupted by a signal.
pub fn close(handle: FileHandle) {
    if (is_windows) {
        windows_util.windowsClose(handle);
    } else {
        while (true) {
            const err = posix.getErrno(posix.close(handle));
            if (err == posix.EINTR) {
                continue;
            } else {
                return;
            }
        }
    }
}

/// Calls POSIX read, and keeps trying if it gets interrupted.
pub fn posixRead(fd: i32, buf: []u8) -> %void {
    var index: usize = 0;
    while (index < buf.len) {
        const amt_written = posix.read(fd, &buf[index], buf.len - index);
        const err = posix.getErrno(amt_written);
        if (err > 0) {
            return switch (err) {
                posix.EINTR => continue,
                posix.EINVAL, posix.EFAULT => unreachable,
                posix.EAGAIN => error.WouldBlock,
                posix.EBADF => error.FileClosed,
                posix.EIO => error.InputOutput,
                posix.EISDIR => error.IsDir,
                posix.ENOBUFS, posix.ENOMEM => error.SystemResources,
                else => unexpectedErrorPosix(err),
            };
        }
        index += amt_written;
    }
}

error WouldBlock;
error FileClosed;
error DestinationAddressRequired;
error DiskQuota;
error FileTooBig;
error InputOutput;
error NoSpaceLeft;
error BrokenPipe;

/// Calls POSIX write, and keeps trying if it gets interrupted.
pub fn posixWrite(fd: i32, bytes: []const u8) -> %void {
    while (true) {
        const write_ret = posix.write(fd, bytes.ptr, bytes.len);
        const write_err = posix.getErrno(write_ret);
        if (write_err > 0) {
            return switch (write_err) {
                posix.EINTR  => continue,
                posix.EINVAL, posix.EFAULT => unreachable,
                posix.EAGAIN => error.WouldBlock,
                posix.EBADF => error.FileClosed,
                posix.EDESTADDRREQ => error.DestinationAddressRequired,
                posix.EDQUOT => error.DiskQuota,
                posix.EFBIG  => error.FileTooBig,
                posix.EIO    => error.InputOutput,
                posix.ENOSPC => error.NoSpaceLeft,
                posix.EPERM  => error.AccessDenied,
                posix.EPIPE  => error.BrokenPipe,
                else         => unexpectedErrorPosix(write_err),
            };
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
pub fn posixOpen(file_path: []const u8, flags: u32, perm: usize, allocator: ?&Allocator) -> %i32 {
    var stack_buf: [max_noalloc_path_len]u8 = undefined;
    var path0: []u8 = undefined;
    var need_free = false;

    if (file_path.len < stack_buf.len) {
        path0 = stack_buf[0..file_path.len + 1];
    } else if (allocator) |a| {
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
                posix.EINTR => continue,

                posix.EFAULT => unreachable,
                posix.EINVAL => unreachable,
                posix.EACCES => error.AccessDenied,
                posix.EFBIG, posix.EOVERFLOW => error.FileTooBig,
                posix.EISDIR => error.IsDir,
                posix.ELOOP => error.SymLinkLoop,
                posix.EMFILE => error.ProcessFdQuotaExceeded,
                posix.ENAMETOOLONG => error.NameTooLong,
                posix.ENFILE => error.SystemFdQuotaExceeded,
                posix.ENODEV => error.NoDevice,
                posix.ENOENT => error.PathNotFound,
                posix.ENOMEM => error.SystemResources,
                posix.ENOSPC => error.NoSpaceLeft,
                posix.ENOTDIR => error.NotDir,
                posix.EPERM => error.AccessDenied,
                posix.EEXIST => error.PathAlreadyExists,
                else => unexpectedErrorPosix(err),
            };
        }
        return i32(result);
    }
}

pub fn posixDup2(old_fd: i32, new_fd: i32) -> %void {
    while (true) {
        const err = posix.getErrno(posix.dup2(old_fd, new_fd));
        if (err > 0) {
            return switch (err) {
                posix.EBUSY, posix.EINTR => continue,
                posix.EMFILE => error.ProcessFdQuotaExceeded,
                posix.EINVAL => unreachable,
                else => unexpectedErrorPosix(err),
            };
        }
        return;
    }
}

pub fn createNullDelimitedEnvMap(allocator: &Allocator, env_map: &const BufMap) -> %[]?&u8 {
    const envp_count = env_map.count();
    const envp_buf = %return allocator.alloc(?&u8, envp_count + 1);
    mem.set(?&u8, envp_buf, null);
    %defer freeNullDelimitedEnvMap(allocator, envp_buf);
    {
        var it = env_map.iterator();
        var i: usize = 0;
        while (it.next()) |pair| : (i += 1) {
            const env_buf = %return allocator.alloc(u8, pair.key.len + pair.value.len + 2);
            @memcpy(&env_buf[0], pair.key.ptr, pair.key.len);
            env_buf[pair.key.len] = '=';
            @memcpy(&env_buf[pair.key.len + 1], pair.value.ptr, pair.value.len);
            env_buf[env_buf.len - 1] = 0;

            envp_buf[i] = env_buf.ptr;
        }
        assert(i == envp_count);
    }
    assert(envp_buf[envp_count] == null);
    return envp_buf;
}

pub fn freeNullDelimitedEnvMap(allocator: &Allocator, envp_buf: []?&u8) {
    for (envp_buf) |env| {
        const env_buf = if (env) |ptr| ptr[0 .. cstr.len(ptr) + 1] else break;
        allocator.free(env_buf);
    }
    allocator.free(envp_buf);
}

/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
pub fn posixExecve(argv: []const []const u8, env_map: &const BufMap,
    allocator: &Allocator) -> %void
{
    const argv_buf = %return allocator.alloc(?&u8, argv.len + 1);
    mem.set(?&u8, argv_buf, null);
    defer {
        for (argv_buf) |arg| {
            const arg_buf = if (arg) |ptr| cstr.toSlice(ptr) else break;
            allocator.free(arg_buf);
        }
        allocator.free(argv_buf);
    }
    for (argv) |arg, i| {
        const arg_buf = %return allocator.alloc(u8, arg.len + 1);
        @memcpy(&arg_buf[0], arg.ptr, arg.len);
        arg_buf[arg.len] = 0;

        argv_buf[i] = arg_buf.ptr;
    }
    argv_buf[argv.len] = null;

    const envp_buf = %return createNullDelimitedEnvMap(allocator, env_map);
    defer freeNullDelimitedEnvMap(allocator, envp_buf);

    const exe_path = argv[0];
    if (mem.indexOfScalar(u8, exe_path, '/') != null) {
        return posixExecveErrnoToErr(posix.getErrno(posix.execve(??argv_buf[0], argv_buf.ptr, envp_buf.ptr)));
    }

    const PATH = getEnvPosix("PATH") ?? "/usr/local/bin:/bin/:/usr/bin";
    // PATH.len because it is >= the largest search_path
    // +1 for the / to join the search path and exe_path
    // +1 for the null terminating byte
    const path_buf = %return allocator.alloc(u8, PATH.len + exe_path.len + 2);
    defer allocator.free(path_buf);
    var it = mem.split(PATH, ":");
    var seen_eacces = false;
    var err: usize = undefined;
    while (it.next()) |search_path| {
        mem.copy(u8, path_buf, search_path);
        path_buf[search_path.len] = '/';
        mem.copy(u8, path_buf[search_path.len + 1 ..], exe_path);
        path_buf[search_path.len + exe_path.len + 1] = 0;
        err = posix.getErrno(posix.execve(path_buf.ptr, argv_buf.ptr, envp_buf.ptr));
        assert(err > 0);
        if (err == posix.EACCES) {
            seen_eacces = true;
        } else if (err != posix.ENOENT) {
            return posixExecveErrnoToErr(err);
        }
    }
    if (seen_eacces) {
        err = posix.EACCES;
    }
    return posixExecveErrnoToErr(err);
}

fn posixExecveErrnoToErr(err: usize) -> error {
    assert(err > 0);
    return switch (err) {
        posix.EFAULT => unreachable,
        posix.E2BIG, posix.EMFILE, posix.ENAMETOOLONG, posix.ENFILE, posix.ENOMEM => error.SystemResources,
        posix.EACCES, posix.EPERM => error.AccessDenied,
        posix.EINVAL, posix.ENOEXEC => error.InvalidExe,
        posix.EIO, posix.ELOOP => error.FileSystem,
        posix.EISDIR => error.IsDir,
        posix.ENOENT => error.FileNotFound,
        posix.ENOTDIR => error.NotDir,
        posix.ETXTBSY => error.FileBusy,
        else => unexpectedErrorPosix(err),
    };
}

pub var posix_environ_raw: []&u8 = undefined;

/// Caller must free result when done.
pub fn getEnvMap(allocator: &Allocator) -> %BufMap {
    var result = BufMap.init(allocator);
    %defer result.deinit();

    if (is_windows) {
        const ptr = windows.GetEnvironmentStringsA() ?? return error.OutOfMemory;
        defer assert(windows.FreeEnvironmentStringsA(ptr) != 0);

        var i: usize = 0;
        while (true) {
            if (ptr[i] == 0)
                return result;

            const key_start = i;

            while (ptr[i] != 0 and ptr[i] != '=') : (i += 1) {}
            const key = ptr[key_start..i];

            if (ptr[i] == '=') i += 1;

            const value_start = i;
            while (ptr[i] != 0) : (i += 1) {}
            const value = ptr[value_start..i];

            i += 1; // skip over null byte

            %return result.set(key, value);
        }
    } else {
        for (posix_environ_raw) |ptr| {
            var line_i: usize = 0;
            while (ptr[line_i] != 0 and ptr[line_i] != '=') : (line_i += 1) {}
            const key = ptr[0..line_i];

            var end_i: usize = line_i;
            while (ptr[end_i] != 0) : (end_i += 1) {}
            const value = ptr[line_i + 1..end_i];

            %return result.set(key, value);
        }
        return result;
    }
}

pub fn getEnvPosix(key: []const u8) -> ?[]const u8 {
    for (posix_environ_raw) |ptr| {
        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '=') : (line_i += 1) {}
        const this_key = ptr[0..line_i];
        if (!mem.eql(u8, key, this_key))
            continue;

        var end_i: usize = line_i;
        while (ptr[end_i] != 0) : (end_i += 1) {}
        const this_value = ptr[line_i + 1..end_i];

        return this_value;
    }
    return null;
}

error EnvironmentVariableNotFound;

/// Caller must free returned memory.
pub fn getEnvVarOwned(allocator: &mem.Allocator, key: []const u8) -> %[]u8 {
    if (is_windows) {
        const key_with_null = %return cstr.addNullByte(allocator, key);
        defer allocator.free(key_with_null);

        var buf = %return allocator.alloc(u8, 256);
        %defer allocator.free(buf);

        while (true) {
            const windows_buf_len = %return math.cast(windows.DWORD, buf.len);
            const result = windows.GetEnvironmentVariableA(key_with_null.ptr, buf.ptr, windows_buf_len);

            if (result == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    windows.ERROR.ENVVAR_NOT_FOUND => error.EnvironmentVariableNotFound,
                    else => unexpectedErrorWindows(err),
                };
            }

            if (result > buf.len) {
                buf = %return allocator.realloc(u8, buf, result);
                continue;
            }

            return allocator.shrink(u8, buf, result);
        }
    } else {
        const result = getEnvPosix(key) ?? return error.EnvironmentVariableNotFound;
        return mem.dupe(allocator, u8, result);
    }
}

/// Caller must free the returned memory.
pub fn getCwd(allocator: &Allocator) -> %[]u8 {
    switch (builtin.os) {
        Os.windows => {
            var buf = %return allocator.alloc(u8, 256);
            %defer allocator.free(buf);

            while (true) {
                const result = windows.GetCurrentDirectoryA(windows.WORD(buf.len), buf.ptr);

                if (result == 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        else => unexpectedErrorWindows(err),
                    };
                }

                if (result > buf.len) {
                    buf = %return allocator.realloc(u8, buf, result);
                    continue;
                }

                return allocator.shrink(u8, buf, result);
            }
        },
        else => {
            var buf = %return allocator.alloc(u8, 1024);
            %defer allocator.free(buf);
            while (true) {
                const err = posix.getErrno(posix.getcwd(buf.ptr, buf.len));
                if (err == posix.ERANGE) {
                    buf = %return allocator.realloc(u8, buf, buf.len * 2);
                    continue;
                } else if (err > 0) {
                    return unexpectedErrorPosix(err);
                }

                return allocator.shrink(u8, buf, cstr.len(buf.ptr));
            }
        },
    }
}

test "os.getCwd" {
    // at least call it so it gets compiled
    _ = getCwd(debug.global_allocator);
}

pub fn symLink(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    if (is_windows) {
        return symLinkWindows(allocator, existing_path, new_path);
    } else {
        return symLinkPosix(allocator, existing_path, new_path);
    }
}

pub fn symLinkWindows(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    const existing_with_null = %return cstr.addNullByte(allocator, existing_path);
    defer allocator.free(existing_with_null);
    const new_with_null = %return cstr.addNullByte(allocator, new_path);
    defer allocator.free(new_with_null);

    if (windows.CreateSymbolicLinkA(existing_with_null.ptr, new_with_null.ptr, 0) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            else => unexpectedErrorWindows(err),
        };
    }
}

pub fn symLinkPosix(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    const full_buf = %return allocator.alloc(u8, existing_path.len + new_path.len + 2);
    defer allocator.free(full_buf);

    const existing_buf = full_buf;
    mem.copy(u8, existing_buf, existing_path);
    existing_buf[existing_path.len] = 0;

    const new_buf = full_buf[existing_path.len + 1..];
    mem.copy(u8, new_buf, new_path);
    new_buf[new_path.len] = 0;

    const err = posix.getErrno(posix.symlink(existing_buf.ptr, new_buf.ptr));
    if (err > 0) {
        return switch (err) {
            posix.EFAULT, posix.EINVAL => unreachable,
            posix.EACCES, posix.EPERM => error.AccessDenied,
            posix.EDQUOT => error.DiskQuota,
            posix.EEXIST => error.PathAlreadyExists,
            posix.EIO => error.FileSystem,
            posix.ELOOP => error.SymLinkLoop,
            posix.ENAMETOOLONG => error.NameTooLong,
            posix.ENOENT => error.FileNotFound,
            posix.ENOTDIR => error.NotDir,
            posix.ENOMEM => error.SystemResources,
            posix.ENOSPC => error.NoSpaceLeft,
            posix.EROFS => error.ReadOnlyFileSystem,
            else => unexpectedErrorPosix(err),
        };
    }
}

// here we replace the standard +/ with -_ so that it can be used in a file name
const b64_fs_encoder = base64.Base64Encoder.init(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
    base64.standard_pad_char);

pub fn atomicSymLink(allocator: &Allocator, existing_path: []const u8, new_path: []const u8) -> %void {
    if (symLink(allocator, existing_path, new_path)) {
        return;
    } else |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    }

    var rand_buf: [12]u8 = undefined;
    const tmp_path = %return allocator.alloc(u8, new_path.len + base64.Base64Encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0..], new_path);
    while (true) {
        %return getRandomBytes(rand_buf[0..]);
        b64_fs_encoder.encode(tmp_path[new_path.len..], rand_buf);
        if (symLink(allocator, existing_path, tmp_path)) {
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
    if (builtin.os == Os.windows) {
        return deleteFileWindows(allocator, file_path);
    } else {
        return deleteFilePosix(allocator, file_path);
    }
}

error FileNotFound;
error AccessDenied;

pub fn deleteFileWindows(allocator: &Allocator, file_path: []const u8) -> %void {
    const buf = %return allocator.alloc(u8, file_path.len + 1);
    defer allocator.free(buf);

    mem.copy(u8, buf, file_path);
    buf[file_path.len] = 0;

    if (windows.DeleteFileA(buf.ptr) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.FILE_NOT_FOUND => error.FileNotFound,
            windows.ERROR.ACCESS_DENIED => error.AccessDenied,
            windows.ERROR.FILENAME_EXCED_RANGE, windows.ERROR.INVALID_PARAMETER => error.NameTooLong,
            else => unexpectedErrorWindows(err),
        };
    }
}

pub fn deleteFilePosix(allocator: &Allocator, file_path: []const u8) -> %void {
    const buf = %return allocator.alloc(u8, file_path.len + 1);
    defer allocator.free(buf);

    mem.copy(u8, buf, file_path);
    buf[file_path.len] = 0;

    const err = posix.getErrno(posix.unlink(buf.ptr));
    if (err > 0) {
        return switch (err) {
            posix.EACCES, posix.EPERM => error.AccessDenied,
            posix.EBUSY => error.FileBusy,
            posix.EFAULT, posix.EINVAL => unreachable,
            posix.EIO => error.FileSystem,
            posix.EISDIR => error.IsDir,
            posix.ELOOP => error.SymLinkLoop,
            posix.ENAMETOOLONG => error.NameTooLong,
            posix.ENOENT => error.FileNotFound,
            posix.ENOTDIR => error.NotDir,
            posix.ENOMEM => error.SystemResources,
            posix.EROFS => error.ReadOnlyFileSystem,
            else => unexpectedErrorPosix(err),
        };
    }
}

/// Calls ::copyFileMode with 0o666 for the mode.
pub fn copyFile(allocator: &Allocator, source_path: []const u8, dest_path: []const u8) -> %void {
    return copyFileMode(allocator, source_path, dest_path, 0o666);
}

// TODO instead of accepting a mode argument, use the mode from fstat'ing the source path once open
/// Guaranteed to be atomic.
pub fn copyFileMode(allocator: &Allocator, source_path: []const u8, dest_path: []const u8, mode: usize) -> %void {
    var rand_buf: [12]u8 = undefined;
    const tmp_path = %return allocator.alloc(u8, dest_path.len + base64.Base64Encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0..], dest_path);
    %return getRandomBytes(rand_buf[0..]);
    b64_fs_encoder.encode(tmp_path[dest_path.len..], rand_buf);

    var out_file = %return io.File.openWriteMode(tmp_path, mode, allocator);
    defer out_file.close();
    %defer _ = deleteFile(allocator, tmp_path);

    var in_file = %return io.File.openRead(source_path, allocator);
    defer in_file.close();

    var buf: [page_size]u8 = undefined;
    while (true) {
        const amt = %return in_file.read(buf[0..]);
        %return out_file.write(buf[0..amt]);
        if (amt != buf.len)
            return rename(allocator, tmp_path, dest_path);
    }
}

pub fn rename(allocator: &Allocator, old_path: []const u8, new_path: []const u8) -> %void {
    const full_buf = %return allocator.alloc(u8, old_path.len + new_path.len + 2);
    defer allocator.free(full_buf);

    const old_buf = full_buf;
    mem.copy(u8, old_buf, old_path);
    old_buf[old_path.len] = 0;

    const new_buf = full_buf[old_path.len + 1..];
    mem.copy(u8, new_buf, new_path);
    new_buf[new_path.len] = 0;

    if (is_windows) {
        const flags = windows.MOVEFILE_REPLACE_EXISTING|windows.MOVEFILE_WRITE_THROUGH;
        if (windows.MoveFileExA(old_buf.ptr, new_buf.ptr, flags) == 0) {
            const err = windows.GetLastError();
            return switch (err) {
                else => unexpectedErrorWindows(err),
            };
        }
    } else {
        const err = posix.getErrno(posix.rename(old_buf.ptr, new_buf.ptr));
        if (err > 0) {
            return switch (err) {
                posix.EACCES, posix.EPERM => error.AccessDenied,
                posix.EBUSY => error.FileBusy,
                posix.EDQUOT => error.DiskQuota,
                posix.EFAULT, posix.EINVAL => unreachable,
                posix.EISDIR => error.IsDir,
                posix.ELOOP => error.SymLinkLoop,
                posix.EMLINK => error.LinkQuotaExceeded,
                posix.ENAMETOOLONG => error.NameTooLong,
                posix.ENOENT => error.FileNotFound,
                posix.ENOTDIR => error.NotDir,
                posix.ENOMEM => error.SystemResources,
                posix.ENOSPC => error.NoSpaceLeft,
                posix.EEXIST, posix.ENOTEMPTY => error.PathAlreadyExists,
                posix.EROFS => error.ReadOnlyFileSystem,
                posix.EXDEV => error.RenameAcrossMountPoints,
                else => unexpectedErrorPosix(err),
            };
        }
    }
}

pub fn makeDir(allocator: &Allocator, dir_path: []const u8) -> %void {
    if (is_windows) {
        return makeDirWindows(allocator, dir_path);
    } else {
        return makeDirPosix(allocator, dir_path);
    }
}

pub fn makeDirWindows(allocator: &Allocator, dir_path: []const u8) -> %void {
    const path_buf = %return cstr.addNullByte(allocator, dir_path);
    defer allocator.free(path_buf);

    if (windows.CreateDirectoryA(path_buf.ptr, null) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.ALREADY_EXISTS => error.PathAlreadyExists,
            windows.ERROR.PATH_NOT_FOUND => error.FileNotFound,
            else => unexpectedErrorWindows(err),
        };
    }
}

pub fn makeDirPosix(allocator: &Allocator, dir_path: []const u8) -> %void {
    const path_buf = %return cstr.addNullByte(allocator, dir_path);
    defer allocator.free(path_buf);

    const err = posix.getErrno(posix.mkdir(path_buf.ptr, 0o755));
    if (err > 0) {
        return switch (err) {
            posix.EACCES, posix.EPERM => error.AccessDenied,
            posix.EDQUOT => error.DiskQuota,
            posix.EEXIST => error.PathAlreadyExists,
            posix.EFAULT => unreachable,
            posix.ELOOP => error.SymLinkLoop,
            posix.EMLINK => error.LinkQuotaExceeded,
            posix.ENAMETOOLONG => error.NameTooLong,
            posix.ENOENT => error.FileNotFound,
            posix.ENOMEM => error.SystemResources,
            posix.ENOSPC => error.NoSpaceLeft,
            posix.ENOTDIR => error.NotDir,
            posix.EROFS => error.ReadOnlyFileSystem,
            else => unexpectedErrorPosix(err),
        };
    }
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
pub fn makePath(allocator: &Allocator, full_path: []const u8) -> %void {
    const resolved_path = %return path.resolve(allocator, full_path);
    defer allocator.free(resolved_path);

    var end_index: usize = resolved_path.len;
    while (true) {
        makeDir(allocator, resolved_path[0..end_index]) %% |err| {
            if (err == error.PathAlreadyExists) {
                // TODO stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                if (end_index == resolved_path.len)
                    return;
            } else if (err == error.FileNotFound) {
                // march end_index backward until next path component
                while (true) {
                    end_index -= 1;
                    if (os.path.isSep(resolved_path[end_index]))
                        break;
                }
                continue;
            } else {
                return err;
            }
        };
        if (end_index == resolved_path.len)
            return;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == resolved_path.len or os.path.isSep(resolved_path[end_index]))
                break;
        }
    }
}

/// Returns ::error.DirNotEmpty if the directory is not empty.
/// To delete a directory recursively, see ::deleteTree
pub fn deleteDir(allocator: &Allocator, dir_path: []const u8) -> %void {
    const path_buf = %return allocator.alloc(u8, dir_path.len + 1);
    defer allocator.free(path_buf);

    mem.copy(u8, path_buf, dir_path);
    path_buf[dir_path.len] = 0;

    const err = posix.getErrno(posix.rmdir(path_buf.ptr));
    if (err > 0) {
        return switch (err) {
            posix.EACCES, posix.EPERM => error.AccessDenied,
            posix.EBUSY => error.FileBusy,
            posix.EFAULT, posix.EINVAL => unreachable,
            posix.ELOOP => error.SymLinkLoop,
            posix.ENAMETOOLONG => error.NameTooLong,
            posix.ENOENT => error.FileNotFound,
            posix.ENOMEM => error.SystemResources,
            posix.ENOTDIR => error.NotDir,
            posix.EEXIST, posix.ENOTEMPTY => error.DirNotEmpty,
            posix.EROFS => error.ReadOnlyFileSystem,
            else => unexpectedErrorPosix(err),
        };
    }
}

/// Whether ::full_path describes a symlink, file, or directory, this function
/// removes it. If it cannot be removed because it is a non-empty directory,
/// this function recursively removes its entries and then tries again.
// TODO non-recursive implementation
pub fn deleteTree(allocator: &Allocator, full_path: []const u8) -> %void {
    start_over: while (true) {
        // First, try deleting the item as a file. This way we don't follow sym links.
        if (deleteFile(allocator, full_path)) {
            return;
        } else |err| {
            if (err == error.FileNotFound)
                return;
            if (err != error.IsDir)
                return err;
        }
        {
            var dir = Dir.open(allocator, full_path) %% |err| {
                if (err == error.FileNotFound)
                    return;
                if (err == error.NotDir)
                    continue :start_over;
                return err;
            };
            defer dir.close();

            var full_entry_buf = ArrayList(u8).init(allocator);
            defer full_entry_buf.deinit();

            while (%return dir.next()) |entry| {
                %return full_entry_buf.resize(full_path.len + entry.name.len + 1);
                const full_entry_path = full_entry_buf.toSlice();
                mem.copy(u8, full_entry_path, full_path);
                full_entry_path[full_path.len] = '/';
                mem.copy(u8, full_entry_path[full_path.len + 1..], entry.name);

                %return deleteTree(allocator, full_entry_path);
            }
        }
        return deleteDir(allocator, full_path);
    }
}

pub const Dir = struct {
    // See man getdents
    fd: i32,
    allocator: &Allocator,
    buf: []u8,
    index: usize,
    end_index: usize,

    const LinuxEntry = extern struct {
        d_ino: usize,
        d_off: usize,
        d_reclen: u16,
        d_name: u8, // field address is the address of first byte of name
    };

    pub const Entry = struct {
        name: []const u8,
        kind: Kind,

        pub const Kind = enum {
            BlockDevice,
            CharacterDevice,
            Directory,
            NamedPipe,
            SymLink,
            File,
            UnixDomainSocket,
            Unknown,
        };
    };

    pub fn open(allocator: &Allocator, dir_path: []const u8) -> %Dir {
        const fd = %return posixOpen(dir_path, posix.O_RDONLY|posix.O_DIRECTORY|posix.O_CLOEXEC, 0, allocator);
        return Dir {
            .allocator = allocator,
            .fd = fd,
            .index = 0,
            .end_index = 0,
            .buf = []u8{},
        };
    }

    pub fn close(self: &Dir) {
        self.allocator.free(self.buf);
        os.close(self.fd);
    }

    /// Memory such as file names referenced in this returned entry becomes invalid
    /// with subsequent calls to next, as well as when this ::Dir is deinitialized.
    pub fn next(self: &Dir) -> %?Entry {
        start_over: while (true) {
            if (self.index >= self.end_index) {
                if (self.buf.len == 0) {
                    self.buf = %return self.allocator.alloc(u8, page_size);
                }

                while (true) {
                    const result = posix.getdents(self.fd, self.buf.ptr, self.buf.len);
                    const err = linux.getErrno(result);
                    if (err > 0) {
                        switch (err) {
                            posix.EBADF, posix.EFAULT, posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.buf = %return self.allocator.realloc(u8, self.buf, self.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    if (result == 0)
                        return null;
                    self.index = 0;
                    self.end_index = result;
                    break;
                }
            }
            const linux_entry = @ptrCast(& align(1) LinuxEntry, &self.buf[self.index]);
            const next_index = self.index + linux_entry.d_reclen;
            self.index = next_index;

            const name = cstr.toSlice(&linux_entry.d_name);

            // skip . and .. entries
            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const type_char = self.buf[next_index - 1];
            const entry_kind = switch (type_char) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                else => Entry.Kind.Unknown,
            };
            return Entry {
                .name = name,
                .kind = entry_kind,
            };
        }
    }
};

pub fn changeCurDir(allocator: &Allocator, dir_path: []const u8) -> %void {
    const path_buf = %return allocator.alloc(u8, dir_path.len + 1);
    defer allocator.free(path_buf);

    mem.copy(u8, path_buf, dir_path);
    path_buf[dir_path.len] = 0;

    const err = posix.getErrno(posix.chdir(path_buf.ptr));
    if (err > 0) {
        return switch (err) {
            posix.EACCES => error.AccessDenied,
            posix.EFAULT => unreachable,
            posix.EIO => error.FileSystem,
            posix.ELOOP => error.SymLinkLoop,
            posix.ENAMETOOLONG => error.NameTooLong,
            posix.ENOENT => error.FileNotFound,
            posix.ENOMEM => error.SystemResources,
            posix.ENOTDIR => error.NotDir,
            else => unexpectedErrorPosix(err),
        };
    }
}

/// Read value of a symbolic link.
pub fn readLink(allocator: &Allocator, pathname: []const u8) -> %[]u8 {
    const path_buf = %return allocator.alloc(u8, pathname.len + 1);
    defer allocator.free(path_buf);

    mem.copy(u8, path_buf, pathname);
    path_buf[pathname.len] = 0;

    var result_buf = %return allocator.alloc(u8, 1024);
    %defer allocator.free(result_buf);
    while (true) {
        const ret_val = posix.readlink(path_buf.ptr, result_buf.ptr, result_buf.len);
        const err = posix.getErrno(ret_val);
        if (err > 0) {
            return switch (err) {
                posix.EACCES => error.AccessDenied,
                posix.EFAULT, posix.EINVAL => unreachable,
                posix.EIO => error.FileSystem,
                posix.ELOOP => error.SymLinkLoop,
                posix.ENAMETOOLONG => error.NameTooLong,
                posix.ENOENT => error.FileNotFound,
                posix.ENOMEM => error.SystemResources,
                posix.ENOTDIR => error.NotDir,
                else => unexpectedErrorPosix(err),
            };
        }
        if (ret_val == result_buf.len) {
            result_buf = %return allocator.realloc(u8, result_buf, result_buf.len * 2);
            continue;
        }
        return allocator.shrink(u8, result_buf, ret_val);
    }
}

pub fn sleep(seconds: usize, nanoseconds: usize) {
    switch(builtin.os) {
        Os.linux, Os.darwin, Os.macosx, Os.ios => {
            posixSleep(u63(seconds), u63(nanoseconds));
        },
        Os.windows => {
            const milliseconds = seconds * 1000 + nanoseconds / 1000000;
            windows.Sleep(windows.DWORD(milliseconds));
        },
        else => @compileError("Unsupported OS"),
    }
}

const u63 = @IntType(false, 63);
pub fn posixSleep(seconds: u63, nanoseconds: u63) {
    var req = posix.timespec {
        .tv_sec = seconds,
        .tv_nsec = nanoseconds,
    };
    var rem: posix.timespec = undefined;
    while (true) {
        const ret_val = posix.nanosleep(&req, &rem);
        const err = posix.getErrno(ret_val);
        if (err == 0) return;
        switch (err) {
            posix.EFAULT => unreachable,
            posix.EINVAL => {
                // Sometimes Darwin returns EINVAL for no reason.
                // We treat it as a spurious wakeup.
                return;
            },
            posix.EINTR => {
                req = rem;
                continue;
            },
            else => return,
        }
    }
}

test "os.sleep" {
    sleep(0, 1);
}

error ResourceLimitReached;
error InvalidUserId;
error PermissionDenied;

pub fn posix_setuid(uid: u32) -> %void {
    const err = posix.getErrno(posix.setuid(uid));
    if (err == 0) return;
    return switch (err) {
        posix.EAGAIN => error.ResourceLimitReached,
        posix.EINVAL => error.InvalidUserId,
        posix.EPERM => error.PermissionDenied,
        else => unexpectedErrorPosix(err),
    };
}

pub fn posix_setreuid(ruid: u32, euid: u32) -> %void {
    const err = posix.getErrno(posix.setreuid(ruid, euid));
    if (err == 0) return;
    return switch (err) {
        posix.EAGAIN => error.ResourceLimitReached,
        posix.EINVAL => error.InvalidUserId,
        posix.EPERM => error.PermissionDenied,
        else => unexpectedErrorPosix(err),
    };
}

pub fn posix_setgid(gid: u32) -> %void {
    const err = posix.getErrno(posix.setgid(gid));
    if (err == 0) return;
    return switch (err) {
        posix.EAGAIN => error.ResourceLimitReached,
        posix.EINVAL => error.InvalidUserId,
        posix.EPERM => error.PermissionDenied,
        else => unexpectedErrorPosix(err),
    };
}

pub fn posix_setregid(rgid: u32, egid: u32) -> %void {
    const err = posix.getErrno(posix.setregid(rgid, egid));
    if (err == 0) return;
    return switch (err) {
        posix.EAGAIN => error.ResourceLimitReached,
        posix.EINVAL => error.InvalidUserId,
        posix.EPERM => error.PermissionDenied,
        else => unexpectedErrorPosix(err),
    };
}

error NoStdHandles;
pub fn windowsGetStdHandle(handle_id: windows.DWORD) -> %windows.HANDLE {
    if (windows.GetStdHandle(handle_id)) |handle| {
        if (handle == windows.INVALID_HANDLE_VALUE) {
            const err = windows.GetLastError();
            return switch (err) {
                else => os.unexpectedErrorWindows(err),
            };
        }
        return handle;
    } else {
        return error.NoStdHandles;
    }
}

pub const ArgIteratorPosix = struct {
    index: usize,
    count: usize,

    pub fn init() -> ArgIteratorPosix {
        return ArgIteratorPosix {
            .index = 0,
            .count = raw.len,
        };
    }

    pub fn next(self: &ArgIteratorPosix) -> ?[]const u8 {
        if (self.index == self.count)
            return null;

        const s = raw[self.index];
        self.index += 1;
        return cstr.toSlice(s);
    }

    pub fn skip(self: &ArgIteratorPosix) -> bool {
        if (self.index == self.count)
            return false;

        self.index += 1;
        return true;
    }

    /// This is marked as public but actually it's only meant to be used
    /// internally by zig's startup code.
    pub var raw: []&u8 = undefined;
};

pub const ArgIteratorWindows = struct {
    index: usize,
    cmd_line: &const u8,
    in_quote: bool,
    quote_count: usize,
    seen_quote_count: usize,

    pub fn init() -> ArgIteratorWindows {
        return initWithCmdLine(windows.GetCommandLineA());
    }

    pub fn initWithCmdLine(cmd_line: &const u8) -> ArgIteratorWindows {
        return ArgIteratorWindows {
            .index = 0,
            .cmd_line = cmd_line,
            .in_quote = false,
            .quote_count = countQuotes(cmd_line),
            .seen_quote_count = 0,
        };
    }

    /// You must free the returned memory when done.
    pub fn next(self: &ArgIteratorWindows, allocator: &Allocator) -> ?%[]u8 {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return null,
                ' ', '\t' => continue,
                else => break,
            }
        }

        return self.internalNext(allocator);
    }

    pub fn skip(self: &ArgIteratorWindows) -> bool {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return false,
                ' ', '\t' => continue,
                else => break,
            }
        }

        var backslash_count: usize = 0;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return true,
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    if (quote_is_real) {
                        self.seen_quote_count += 1;
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    if (self.seen_quote_count % 2 == 0 or self.seen_quote_count == self.quote_count) {
                        return true;
                    }
                    backslash_count = 0;
                },
                else => {
                    backslash_count = 0;
                    continue;
                },
            }
        }
    }

    fn internalNext(self: &ArgIteratorWindows, allocator: &Allocator) -> %[]u8 {
        var buf = %return Buffer.initSize(allocator, 0);
        defer buf.deinit();

        var backslash_count: usize = 0;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return buf.toOwnedSlice(),
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    %return self.emitBackslashes(&buf, backslash_count / 2);
                    backslash_count = 0;

                    if (quote_is_real) {
                        self.seen_quote_count += 1;
                        if (self.seen_quote_count == self.quote_count and self.seen_quote_count % 2 == 1) {
                            %return buf.appendByte('"');
                        }
                    } else {
                        %return buf.appendByte('"');
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    %return self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    if (self.seen_quote_count % 2 == 1 and self.seen_quote_count != self.quote_count) {
                        %return buf.appendByte(byte);
                    } else {
                        return buf.toOwnedSlice();
                    }
                },
                else => {
                    %return self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    %return buf.appendByte(byte);
                },
            }
        }
    }

    fn emitBackslashes(self: &ArgIteratorWindows, buf: &Buffer, emit_count: usize) -> %void {
        var i: usize = 0;
        while (i < emit_count) : (i += 1) {
            %return buf.appendByte('\\');
        }
    }

    fn countQuotes(cmd_line: &const u8) -> usize {
        var result: usize = 0;
        var backslash_count: usize = 0;
        var index: usize = 0;
        while (true) : (index += 1) {
            const byte = cmd_line[index];
            switch (byte) {
                0 => return result,
                '\\' => backslash_count += 1,
                '"' => {
                    result += 1 - (backslash_count % 2);
                    backslash_count = 0;
                },
                else => {
                    backslash_count = 0;
                },
            }
        }
    }

};

pub const ArgIterator = struct {
    inner: if (builtin.os == Os.windows) ArgIteratorWindows else ArgIteratorPosix,

    pub fn init() -> ArgIterator {
        return ArgIterator {
            .inner = if (builtin.os == Os.windows) ArgIteratorWindows.init() else ArgIteratorPosix.init(),
        };
    }
    
    /// You must free the returned memory when done.
    pub fn next(self: &ArgIterator, allocator: &Allocator) -> ?%[]u8 {
        if (builtin.os == Os.windows) {
            return self.inner.next(allocator);
        } else {
            return mem.dupe(allocator, u8, self.inner.next() ?? return null);
        }
    }

    /// If you only are targeting posix you can call this and not need an allocator.
    pub fn nextPosix(self: &ArgIterator) -> ?[]const u8 {
        return self.inner.next();
    }

    /// Parse past 1 argument without capturing it.
    /// Returns `true` if skipped an arg, `false` if we are at the end.
    pub fn skip(self: &ArgIterator) -> bool {
        return self.inner.skip();
    }
};

pub fn args() -> ArgIterator {
    return ArgIterator.init();
}

/// Caller must call freeArgs on result.
pub fn argsAlloc(allocator: &mem.Allocator) -> %[]const []u8 {
    // TODO refactor to only make 1 allocation.
    var it = args();
    var contents = %return Buffer.initSize(allocator, 0);
    defer contents.deinit();

    var slice_list = ArrayList(usize).init(allocator);
    defer slice_list.deinit();

    while (it.next(allocator)) |arg_or_err| {
        const arg = %return arg_or_err;
        defer allocator.free(arg);
        %return contents.append(arg);
        %return slice_list.append(arg.len);
    }

    const contents_slice = contents.toSliceConst();
    const slice_sizes = slice_list.toSliceConst();
    const slice_list_bytes = %return math.mul(usize, @sizeOf([]u8), slice_sizes.len);
    const total_bytes = %return math.add(usize, slice_list_bytes, contents_slice.len);
    const buf = %return allocator.alignedAlloc(u8, @alignOf([]u8), total_bytes);
    %defer allocator.free(buf);

    const result_slice_list = ([][]u8)(buf[0..slice_list_bytes]);
    const result_contents = buf[slice_list_bytes..];
    mem.copy(u8, result_contents, contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index];
        contents_index = new_index;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: &mem.Allocator, args_alloc: []const []u8) {
    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len;
    }
    const unaligned_allocated_buf = @ptrCast(&u8, args_alloc.ptr)[0..total_bytes];
    const aligned_allocated_buf = @alignCast(@alignOf([]u8), unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
}

test "windows arg parsing" {
    testWindowsCmdLine(c"a   b\tc d", [][]const u8{"a", "b", "c", "d"});
    testWindowsCmdLine(c"\"abc\" d e", [][]const u8{"abc", "d", "e"});
    testWindowsCmdLine(c"a\\\\\\b d\"e f\"g h", [][]const u8{"a\\\\\\b", "de fg", "h"});
    testWindowsCmdLine(c"a\\\\\\\"b c d", [][]const u8{"a\\\"b", "c", "d"});
    testWindowsCmdLine(c"a\\\\\\\\\"b c\" d e", [][]const u8{"a\\\\b c", "d", "e"});
    testWindowsCmdLine(c"a   b\tc \"d f", [][]const u8{"a", "b", "c", "\"d", "f"});

    testWindowsCmdLine(c"\".\\..\\zig-cache\\build\" \"bin\\zig.exe\" \".\\..\" \".\\..\\zig-cache\" \"--help\"",
        [][]const u8{".\\..\\zig-cache\\build", "bin\\zig.exe", ".\\..", ".\\..\\zig-cache", "--help"});
}

fn testWindowsCmdLine(input_cmd_line: &const u8, expected_args: []const []const u8) {
    var it = ArgIteratorWindows.initWithCmdLine(input_cmd_line);
    for (expected_args) |expected_arg| {
        const arg = %%??it.next(debug.global_allocator);
        assert(mem.eql(u8, arg, expected_arg));
    }
    assert(it.next(debug.global_allocator) == null);
}

test "std.os" {
    _ = @import("child_process.zig");
    _ = @import("darwin_errno.zig");
    _ = @import("darwin.zig");
    _ = @import("get_user_id.zig");
    _ = @import("linux_errno.zig");
    //_ = @import("linux_i386.zig");
    _ = @import("linux_x86_64.zig");
    _ = @import("linux.zig");
    _ = @import("path.zig");
    _ = @import("windows/index.zig");
}


error Unexpected;

// TODO make this a build variable that you can set
const unexpected_error_tracing = false;

/// Call this when you made a syscall or something that sets errno
/// and you get an unexpected error.
pub fn unexpectedErrorPosix(errno: usize) -> error {
    if (unexpected_error_tracing) {
        debug.warn("unexpected errno: {}\n", errno);
        debug.dumpStackTrace();
    }
    return error.Unexpected;
}

/// Call this when you made a windows DLL call or something that does SetLastError
/// and you get an unexpected error.
pub fn unexpectedErrorWindows(err: windows.DWORD) -> error {
    if (unexpected_error_tracing) {
        debug.warn("unexpected GetLastError(): {}\n", err);
        debug.dumpStackTrace();
    }
    return error.Unexpected;
}

pub fn openSelfExe() -> %io.File {
    switch (builtin.os) {
        Os.linux => {
            return io.File.openRead("/proc/self/exe", null);
        },
        Os.darwin => {
            @panic("TODO: openSelfExe on Darwin");
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Get the path to the current executable.
/// If you only need the directory, use selfExeDirPath.
/// If you only want an open file handle, use openSelfExe.
/// This function may return an error if the current executable
/// was deleted after spawning.
/// Caller owns returned memory.
pub fn selfExePath(allocator: &mem.Allocator) -> %[]u8 {
    switch (builtin.os) {
        Os.linux => {
            // If the currently executing binary has been deleted,
            // the file path looks something like `/a/b/c/exe (deleted)`
            return readLink(allocator, "/proc/self/exe");
        },
        Os.windows => {
            var out_path = %return Buffer.initSize(allocator, 0xff);
            %defer out_path.deinit();
            while (true) {
                const dword_len = %return math.cast(windows.DWORD, out_path.len());
                const copied_amt = windows.GetModuleFileNameA(null, out_path.ptr(), dword_len);
                if (copied_amt <= 0) {
                    const err = windows.GetLastError();
                    return switch (err) {
                        else => unexpectedErrorWindows(err),
                    };
                }
                if (copied_amt < out_path.len()) {
                    out_path.shrink(copied_amt);
                    return out_path.toOwnedSlice();
                }
                const new_len = (%return math.shlExact(out_path.len(), 1)) | 0b1;
                %return out_path.resize(new_len);
            }
        },
        Os.darwin, Os.macosx, Os.ios => {
            var u32_len: u32 = 0;
            const ret1 = c._NSGetExecutablePath(undefined, &u32_len);
            assert(ret1 != 0);
            const bytes = %return allocator.alloc(u8, u32_len);
            %defer allocator.free(bytes);
            const ret2 = c._NSGetExecutablePath(bytes.ptr, &u32_len);
            assert(ret2 == 0);
            return bytes;
        },
        else => @compileError("Unsupported OS"),
    }
}

/// Get the directory path that contains the current executable.
/// Caller owns returned memory.
pub fn selfExeDirPath(allocator: &mem.Allocator) -> %[]u8 {
    switch (builtin.os) {
        Os.linux => {
            // If the currently executing binary has been deleted,
            // the file path looks something like `/a/b/c/exe (deleted)`
            // This path cannot be opened, but it's valid for determining the directory
            // the executable was in when it was run.
            const full_exe_path = %return readLink(allocator, "/proc/self/exe");
            %defer allocator.free(full_exe_path);
            const dir = path.dirname(full_exe_path);
            return allocator.shrink(u8, full_exe_path, dir.len);
        },
        Os.windows, Os.darwin, Os.macosx, Os.ios => {
            const self_exe_path = %return selfExePath(allocator);
            %defer allocator.free(self_exe_path);
            const dirname = os.path.dirname(self_exe_path);
            return allocator.shrink(u8, self_exe_path, dirname.len);
        },
        else => @compileError("unimplemented: std.os.selfExeDirPath for " ++ @tagName(builtin.os)),
    }
}

pub fn isTty(handle: FileHandle) -> bool {
    if (is_windows) {
        return windows_util.windowsIsTty(handle);
    } else {
        if (builtin.link_libc) {
            return c.isatty(handle) != 0;
        } else {
            return posix.isatty(handle);
        }
    }
}
