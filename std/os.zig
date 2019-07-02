// This file contains thin wrappers around OS-specific APIs, with these
// specific goals in mind:
// * Convert "errno"-style error codes into Zig errors.
// * When null-terminated byte buffers are required, provide APIs which accept
//   slices as well as APIs which accept null-terminated byte buffers. Same goes
//   for UTF-16LE encoding.
// * Where operating systems share APIs, e.g. POSIX, these thin wrappers provide
//   cross platform abstracting.
// * When there exists a corresponding libc function and linking libc, the libc
//   implementation is used. Exceptions are made for known buggy areas of libc.
//   On Linux libc can be side-stepped by using `std.os.linux` directly.
// * For Windows, this file represents the API that libc would provide for
//   Windows. For thin wrappers around Windows-specific APIs, see `std.os.windows`.
// Note: The Zig standard library does not support POSIX thread cancellation, and
// in general EINTR is handled by trying again.

const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const elf = std.elf;
const dl = @import("dynamic_library.zig");
const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

comptime {
    assert(@import("std") == std); // std lib tests require --override-std-dir
}

pub const darwin = @import("os/darwin.zig");
pub const freebsd = @import("os/freebsd.zig");
pub const linux = @import("os/linux.zig");
pub const netbsd = @import("os/netbsd.zig");
pub const uefi = @import("os/uefi.zig");
pub const wasi = @import("os/wasi.zig");
pub const windows = @import("os/windows.zig");
pub const zen = @import("os/zen.zig");

/// When linking libc, this is the C API. Otherwise, it is the OS-specific system interface.
pub const system = if (builtin.link_libc) std.c else switch (builtin.os) {
    .macosx, .ios, .watchos, .tvos => darwin,
    .freebsd => freebsd,
    .linux => linux,
    .netbsd => netbsd,
    .wasi => wasi,
    .windows => windows,
    .zen => zen,
    else => struct {},
};

pub usingnamespace @import("os/bits.zig");

/// See also `getenv`. Populated by startup code before main().
pub var environ: [][*]u8 = undefined;

/// Populated by startup code before main().
/// Not available on Windows. See `std.process.args`
/// for obtaining the process arguments.
pub var argv: [][*]u8 = undefined;

/// To obtain errno, call this function with the return value of the
/// system function call. For some systems this will obtain the value directly
/// from the return code; for others it will use a thread-local errno variable.
/// Therefore, this function only returns a well-defined value when it is called
/// directly after the system function call which one wants to learn the errno
/// value of.
pub const errno = system.getErrno;

/// Closes the file descriptor.
/// This function is not capable of returning any indication of failure. An
/// application which wants to ensure writes have succeeded before closing
/// must call `fsync` before `close`.
/// Note: The Zig standard library does not support POSIX thread cancellation.
pub fn close(fd: fd_t) void {
    if (windows.is_the_target) {
        return windows.CloseHandle(fd);
    }
    if (wasi.is_the_target) {
        _ = wasi.fd_close(fd);
    }
    if (darwin.is_the_target) {
        // This avoids the EINTR problem.
        switch (darwin.getErrno(darwin.@"close$NOCANCEL"(fd))) {
            EBADF => unreachable, // Always a race condition.
            else => return,
        }
    }
    switch (errno(system.close(fd))) {
        EBADF => unreachable, // Always a race condition.
        EINTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}

pub const GetRandomError = OpenError;

/// Obtain a series of random bytes. These bytes can be used to seed user-space
/// random number generators or for cryptographic purposes.
/// When linking against libc, this calls the
/// appropriate OS-specific library call. Otherwise it uses the zig standard
/// library implementation.
pub fn getrandom(buf: []u8) GetRandomError!void {
    if (windows.is_the_target) {
        return windows.RtlGenRandom(buf);
    }
    if (linux.is_the_target) {
        while (true) {
            // Bypass libc because it's missing on even relatively new versions.
            switch (linux.getErrno(linux.getrandom(buf.ptr, buf.len, 0))) {
                0 => return,
                EINVAL => unreachable,
                EFAULT => unreachable,
                EINTR => continue,
                ENOSYS => return getRandomBytesDevURandom(buf),
                else => |err| return unexpectedErrno(err),
            }
        }
    }
    if (wasi.is_the_target) {
        switch (wasi.random_get(buf.ptr, buf.len)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }
    return getRandomBytesDevURandom(buf);
}

fn getRandomBytesDevURandom(buf: []u8) !void {
    const fd = try openC(c"/dev/urandom", O_RDONLY | O_CLOEXEC, 0);
    defer close(fd);

    const stream = &std.fs.File.openHandle(fd).inStream().stream;
    stream.readNoEof(buf) catch return error.Unexpected;
}

/// Causes abnormal process termination.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it raises SIGABRT followed by SIGKILL and finally lo
pub fn abort() noreturn {
    @setCold(true);
    if (builtin.link_libc) {
        system.abort();
    }
    if (windows.is_the_target) {
        if (builtin.mode == .Debug) {
            @breakpoint();
        }
        windows.kernel32.ExitProcess(3);
    }
    if (builtin.os == .uefi) {
        // TODO there must be a better thing to do here than loop forever
        while (true) {}
    }

    raise(SIGABRT) catch {};

    // TODO the rest of the implementation of abort() from musl libc here

    raise(SIGKILL) catch {};
    exit(127);
}

pub const RaiseError = error{Unexpected};

pub fn raise(sig: u8) RaiseError!void {
    if (builtin.link_libc) {
        switch (errno(system.raise(sig))) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    if (wasi.is_the_target) {
        switch (wasi.proc_raise(SIGABRT)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    if (linux.is_the_target) {
        var set: linux.sigset_t = undefined;
        linux.blockAppSignals(&set);
        const tid = linux.syscall0(linux.SYS_gettid);
        const rc = linux.syscall2(linux.SYS_tkill, tid, sig);
        linux.restoreSignals(&set);
        switch (errno(rc)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    @compileError("std.os.raise unimplemented for this target");
}

pub const KillError = error{
    PermissionDenied,
    Unexpected,
};

pub fn kill(pid: pid_t, sig: u8) KillError!void {
    switch (errno(system.kill(pid, sig))) {
        0 => return,
        EINVAL => unreachable, // invalid signal
        EPERM => return error.PermissionDenied,
        ESRCH => unreachable, // always a race condition
        else => |err| return unexpectedErrno(err),
    }
}

/// Exits the program cleanly with the specified status code.
pub fn exit(status: u8) noreturn {
    if (builtin.link_libc) {
        system.exit(status);
    }
    if (windows.is_the_target) {
        windows.kernel32.ExitProcess(status);
    }
    if (wasi.is_the_target) {
        wasi.proc_exit(status);
    }
    if (linux.is_the_target and !builtin.single_threaded) {
        linux.exit_group(status);
    }
    system.exit(status);
}

pub const ReadError = error{
    InputOutput,
    SystemResources,
    IsDir,
    OperationAborted,
    BrokenPipe,
    Unexpected,
};

/// Returns the number of bytes that were read, which can be less than
/// buf.len. If 0 bytes were read, that means EOF.
/// This function is for blocking file descriptors only. For non-blocking, see
/// `readAsync`.
pub fn read(fd: fd_t, buf: []u8) ReadError!usize {
    if (windows.is_the_target) {
        return windows.ReadFile(fd, buf);
    }

    if (wasi.is_the_target and !builtin.link_libc) {
        const iovs = [1]iovec{iovec{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        }};

        var nread: usize = undefined;
        switch (wasi.fd_read(fd, &iovs, iovs.len, &nread)) {
            0 => return nread,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Linux can return EINVAL when read amount is > 0x7ffff000
    // See https://github.com/ziglang/zig/pull/743#issuecomment-363158274
    // TODO audit this. Shawn Landden says that this is not actually true.
    // if this logic should stay, move it to std.os.linux
    const max_buf_len = 0x7ffff000;

    var index: usize = 0;
    while (index < buf.len) {
        const want_to_read = math.min(buf.len - index, usize(max_buf_len));
        const rc = system.read(fd, buf.ptr + index, want_to_read);
        switch (errno(rc)) {
            0 => {
                const amt_read = @intCast(usize, rc);
                index += amt_read;
                if (amt_read == want_to_read) continue;
                // Read returned less than buf.len.
                return index;
            },
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => unreachable, // This function is for blocking reads.
            EBADF => unreachable, // Always a race condition.
            EIO => return error.InputOutput,
            EISDIR => return error.IsDir,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
    return index;
}

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
/// This function is for blocking file descriptors only. For non-blocking, see
/// `preadvAsync`.
pub fn preadv(fd: fd_t, iov: []const iovec, offset: u64) ReadError!usize {
    if (darwin.is_the_target) {
        // Darwin does not have preadv but it does have pread.
        var off: usize = 0;
        var iov_i: usize = 0;
        var inner_off: usize = 0;
        while (true) {
            const v = iov[iov_i];
            const rc = darwin.pread(fd, v.iov_base + inner_off, v.iov_len - inner_off, offset + off);
            const err = darwin.getErrno(rc);
            switch (err) {
                0 => {
                    const amt_read = @bitCast(usize, rc);
                    off += amt_read;
                    inner_off += amt_read;
                    if (inner_off == v.iov_len) {
                        iov_i += 1;
                        inner_off = 0;
                        if (iov_i == iov.len) {
                            return off;
                        }
                    }
                    if (rc == 0) return off; // EOF
                    continue;
                },
                EINTR => continue,
                EINVAL => unreachable,
                EFAULT => unreachable,
                ESPIPE => unreachable, // fd is not seekable
                EAGAIN => unreachable, // This function is for blocking reads.
                EBADF => unreachable, // always a race condition
                EIO => return error.InputOutput,
                EISDIR => return error.IsDir,
                ENOBUFS => return error.SystemResources,
                ENOMEM => return error.SystemResources,
                else => return unexpectedErrno(err),
            }
        }
    }
    while (true) {
        // TODO handle the case when iov_len is too large and get rid of this @intCast
        const rc = system.preadv(fd, iov.ptr, @intCast(u32, iov.len), offset);
        switch (errno(rc)) {
            0 => return @bitCast(usize, rc),
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => unreachable, // This function is for blocking reads.
            EBADF => unreachable, // always a race condition
            EIO => return error.InputOutput,
            EISDIR => return error.IsDir,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const WriteError = error{
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    Unexpected,
};

/// Write to a file descriptor. Keeps trying if it gets interrupted.
/// This function is for blocking file descriptors only. For non-blocking, see
/// `writeAsync`.
pub fn write(fd: fd_t, bytes: []const u8) WriteError!void {
    if (windows.is_the_target) {
        return windows.WriteFile(fd, bytes);
    }

    if (wasi.is_the_target and !builtin.link_libc) {
        const ciovs = [1]iovec_const{iovec_const{
            .iov_base = bytes.ptr,
            .iov_len = bytes.len,
        }};
        var nwritten: usize = undefined;
        switch (wasi.fd_write(fd, &ciovs, ciovs.len, &nwritten)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Linux can return EINVAL when write amount is > 0x7ffff000
    // See https://github.com/ziglang/zig/pull/743#issuecomment-363165856
    // TODO audit this. Shawn Landden says that this is not actually true.
    // if this logic should stay, move it to std.os.linux
    const max_bytes_len = 0x7ffff000;

    var index: usize = 0;
    while (index < bytes.len) {
        const amt_to_write = math.min(bytes.len - index, usize(max_bytes_len));
        const rc = system.write(fd, bytes.ptr + index, amt_to_write);
        switch (errno(rc)) {
            0 => {
                index += @intCast(usize, rc);
                continue;
            },
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => unreachable, // This function is for blocking writes.
            EBADF => unreachable, // Always a race condition.
            EDESTADDRREQ => unreachable, // `connect` was never called.
            EDQUOT => return error.DiskQuota,
            EFBIG => return error.FileTooBig,
            EIO => return error.InputOutput,
            ENOSPC => return error.NoSpaceLeft,
            EPERM => return error.AccessDenied,
            EPIPE => return error.BrokenPipe,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Write multiple buffers to a file descriptor. Keeps trying if it gets interrupted.
/// This function is for blocking file descriptors only. For non-blocking, see
/// `pwritevAsync`.
pub fn pwritev(fd: fd_t, iov: []const iovec_const, offset: u64) WriteError!void {
    if (darwin.is_the_target) {
        // Darwin does not have pwritev but it does have pwrite.
        var off: usize = 0;
        var iov_i: usize = 0;
        var inner_off: usize = 0;
        while (true) {
            const v = iov[iov_i];
            const rc = darwin.pwrite(fd, v.iov_base + inner_off, v.iov_len - inner_off, offset + off);
            const err = darwin.getErrno(rc);
            switch (err) {
                0 => {
                    const amt_written = @bitCast(usize, rc);
                    off += amt_written;
                    inner_off += amt_written;
                    if (inner_off == v.iov_len) {
                        iov_i += 1;
                        inner_off = 0;
                        if (iov_i == iov.len) {
                            return;
                        }
                    }
                    continue;
                },
                EINTR => continue,
                ESPIPE => unreachable, // `fd` is not seekable.
                EINVAL => unreachable,
                EFAULT => unreachable,
                EAGAIN => unreachable, // This function is for blocking writes.
                EBADF => unreachable, // Always a race condition.
                EDESTADDRREQ => unreachable, // `connect` was never called.
                EDQUOT => return error.DiskQuota,
                EFBIG => return error.FileTooBig,
                EIO => return error.InputOutput,
                ENOSPC => return error.NoSpaceLeft,
                EPERM => return error.AccessDenied,
                EPIPE => return error.BrokenPipe,
                else => return unexpectedErrno(err),
            }
        }
    }

    while (true) {
        // TODO handle the case when iov_len is too large and get rid of this @intCast
        const rc = system.pwritev(fd, iov.ptr, @intCast(u32, iov.len), offset);
        switch (errno(rc)) {
            0 => return,
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => unreachable, // This function is for blocking writes.
            EBADF => unreachable, // Always a race condition.
            EDESTADDRREQ => unreachable, // `connect` was never called.
            EDQUOT => return error.DiskQuota,
            EFBIG => return error.FileTooBig,
            EIO => return error.InputOutput,
            ENOSPC => return error.NoSpaceLeft,
            EPERM => return error.AccessDenied,
            EPIPE => return error.BrokenPipe,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const OpenError = error{
    AccessDenied,
    FileTooBig,
    IsDir,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    NameTooLong,
    SystemFdQuotaExceeded,
    NoDevice,
    FileNotFound,
    SystemResources,
    NoSpaceLeft,
    NotDir,
    PathAlreadyExists,
    DeviceBusy,
    Unexpected,
};

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// `file_path` needs to be copied in memory to add a null terminating byte.
/// See also `openC`.
pub fn open(file_path: []const u8, flags: u32, perm: usize) OpenError!fd_t {
    const file_path_c = try toPosixPath(file_path);
    return openC(&file_path_c, flags, perm);
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// See also `open`.
/// TODO https://github.com/ziglang/zig/issues/265
pub fn openC(file_path: [*]const u8, flags: u32, perm: usize) OpenError!fd_t {
    while (true) {
        const rc = system.open(file_path, flags, perm);
        switch (errno(rc)) {
            0 => return @intCast(fd_t, rc),
            EINTR => continue,

            EFAULT => unreachable,
            EINVAL => unreachable,
            EACCES => return error.AccessDenied,
            EFBIG => return error.FileTooBig,
            EOVERFLOW => return error.FileTooBig,
            EISDIR => return error.IsDir,
            ELOOP => return error.SymLinkLoop,
            EMFILE => return error.ProcessFdQuotaExceeded,
            ENAMETOOLONG => return error.NameTooLong,
            ENFILE => return error.SystemFdQuotaExceeded,
            ENODEV => return error.NoDevice,
            ENOENT => return error.FileNotFound,
            ENOMEM => return error.SystemResources,
            ENOSPC => return error.NoSpaceLeft,
            ENOTDIR => return error.NotDir,
            EPERM => return error.AccessDenied,
            EEXIST => return error.PathAlreadyExists,
            EBUSY => return error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn dup2(old_fd: fd_t, new_fd: fd_t) !void {
    while (true) {
        switch (errno(system.dup2(old_fd, new_fd))) {
            0 => return,
            EBUSY, EINTR => continue,
            EMFILE => return error.ProcessFdQuotaExceeded,
            EINVAL => unreachable,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// TODO provide execveC which does not take an allocator
pub fn execve(allocator: *mem.Allocator, argv_slice: []const []const u8, env_map: *const std.BufMap) !void {
    const argv_buf = try allocator.alloc(?[*]u8, argv_slice.len + 1);
    mem.set(?[*]u8, argv_buf, null);
    defer {
        for (argv_buf) |arg| {
            const arg_buf = if (arg) |ptr| mem.toSlice(u8, ptr) else break;
            allocator.free(arg_buf);
        }
        allocator.free(argv_buf);
    }
    for (argv_slice) |arg, i| {
        const arg_buf = try allocator.alloc(u8, arg.len + 1);
        @memcpy(arg_buf.ptr, arg.ptr, arg.len);
        arg_buf[arg.len] = 0;

        argv_buf[i] = arg_buf.ptr;
    }
    argv_buf[argv_slice.len] = null;

    const envp_buf = try createNullDelimitedEnvMap(allocator, env_map);
    defer freeNullDelimitedEnvMap(allocator, envp_buf);

    const exe_path = argv_slice[0];
    if (mem.indexOfScalar(u8, exe_path, '/') != null) {
        return execveErrnoToErr(errno(system.execve(argv_buf[0].?, argv_buf.ptr, envp_buf.ptr)));
    }

    const PATH = getenv("PATH") orelse "/usr/local/bin:/bin/:/usr/bin";
    // PATH.len because it is >= the largest search_path
    // +1 for the / to join the search path and exe_path
    // +1 for the null terminating byte
    const path_buf = try allocator.alloc(u8, PATH.len + exe_path.len + 2);
    defer allocator.free(path_buf);
    var it = mem.tokenize(PATH, ":");
    var seen_eacces = false;
    var err: usize = undefined;
    while (it.next()) |search_path| {
        mem.copy(u8, path_buf, search_path);
        path_buf[search_path.len] = '/';
        mem.copy(u8, path_buf[search_path.len + 1 ..], exe_path);
        path_buf[search_path.len + exe_path.len + 1] = 0;
        err = errno(system.execve(path_buf.ptr, argv_buf.ptr, envp_buf.ptr));
        assert(err > 0);
        if (err == EACCES) {
            seen_eacces = true;
        } else if (err != ENOENT) {
            return execveErrnoToErr(err);
        }
    }
    if (seen_eacces) {
        err = EACCES;
    }
    return execveErrnoToErr(err);
}

pub fn createNullDelimitedEnvMap(allocator: *mem.Allocator, env_map: *const std.BufMap) ![]?[*]u8 {
    const envp_count = env_map.count();
    const envp_buf = try allocator.alloc(?[*]u8, envp_count + 1);
    mem.set(?[*]u8, envp_buf, null);
    errdefer freeNullDelimitedEnvMap(allocator, envp_buf);
    {
        var it = env_map.iterator();
        var i: usize = 0;
        while (it.next()) |pair| : (i += 1) {
            const env_buf = try allocator.alloc(u8, pair.key.len + pair.value.len + 2);
            @memcpy(env_buf.ptr, pair.key.ptr, pair.key.len);
            env_buf[pair.key.len] = '=';
            @memcpy(env_buf.ptr + pair.key.len + 1, pair.value.ptr, pair.value.len);
            env_buf[env_buf.len - 1] = 0;

            envp_buf[i] = env_buf.ptr;
        }
        assert(i == envp_count);
    }
    assert(envp_buf[envp_count] == null);
    return envp_buf;
}

pub fn freeNullDelimitedEnvMap(allocator: *mem.Allocator, envp_buf: []?[*]u8) void {
    for (envp_buf) |env| {
        const env_buf = if (env) |ptr| ptr[0 .. mem.len(u8, ptr) + 1] else break;
        allocator.free(env_buf);
    }
    allocator.free(envp_buf);
}

pub const ExecveError = error{
    SystemResources,
    AccessDenied,
    InvalidExe,
    FileSystem,
    IsDir,
    FileNotFound,
    NotDir,
    FileBusy,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NameTooLong,

    Unexpected,
};

fn execveErrnoToErr(err: usize) ExecveError {
    assert(err > 0);
    switch (err) {
        EFAULT => unreachable,
        E2BIG => return error.SystemResources,
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENAMETOOLONG => return error.NameTooLong,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENOMEM => return error.SystemResources,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EINVAL => return error.InvalidExe,
        ENOEXEC => return error.InvalidExe,
        EIO => return error.FileSystem,
        ELOOP => return error.FileSystem,
        EISDIR => return error.IsDir,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ETXTBSY => return error.FileBusy,
        else => return unexpectedErrno(err),
    }
}

/// Get an environment variable.
/// See also `getenvC`.
/// TODO make this go through libc when we have it
pub fn getenv(key: []const u8) ?[]const u8 {
    for (environ) |ptr| {
        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '=') : (line_i += 1) {}
        const this_key = ptr[0..line_i];
        if (!mem.eql(u8, key, this_key)) continue;

        var end_i: usize = line_i;
        while (ptr[end_i] != 0) : (end_i += 1) {}
        const this_value = ptr[line_i + 1 .. end_i];

        return this_value;
    }
    return null;
}

/// Get an environment variable with a null-terminated name.
/// See also `getenv`.
/// TODO https://github.com/ziglang/zig/issues/265
pub fn getenvC(key: [*]const u8) ?[]const u8 {
    if (builtin.link_libc) {
        const value = system.getenv(key) orelse return null;
        return mem.toSliceConst(u8, value);
    }
    return getenv(mem.toSliceConst(u8, key));
}

pub const GetCwdError = error{
    NameTooLong,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
};

/// The result is a slice of out_buffer, indexed from 0.
pub fn getcwd(out_buffer: []u8) GetCwdError![]u8 {
    if (windows.is_the_target) {
        return windows.GetCurrentDirectory(out_buffer);
    }

    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.getcwd(out_buffer.ptr, out_buffer.len)) |_| 0 else std.c._errno().*;
    } else blk: {
        break :blk errno(system.getcwd(out_buffer.ptr, out_buffer.len));
    };
    switch (err) {
        0 => return mem.toSlice(u8, out_buffer.ptr),
        EFAULT => unreachable,
        EINVAL => unreachable,
        ENOENT => return error.CurrentWorkingDirectoryUnlinked,
        ERANGE => return error.NameTooLong,
        else => return unexpectedErrno(@intCast(usize, err)),
    }
}

pub const SymLinkError = error{
    AccessDenied,
    DiskQuota,
    PathAlreadyExists,
    FileSystem,
    SymLinkLoop,
    FileNotFound,
    SystemResources,
    NoSpaceLeft,
    ReadOnlyFileSystem,
    NotDir,
    NameTooLong,
    InvalidUtf8,
    BadPathName,
    Unexpected,
};

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `sym_link_path` exists, it will not be overwritten.
/// See also `symlinkC` and `symlinkW`.
pub fn symlink(target_path: []const u8, sym_link_path: []const u8) SymLinkError!void {
    if (windows.is_the_target) {
        const target_path_w = try windows.sliceToPrefixedFileW(target_path);
        const sym_link_path_w = try windows.sliceToPrefixedFileW(sym_link_path);
        return windows.CreateSymbolicLinkW(&sym_link_path_w, &target_path_w, 0);
    } else {
        const target_path_c = try toPosixPath(target_path);
        const sym_link_path_c = try toPosixPath(sym_link_path);
        return symlinkC(&target_path_c, &sym_link_path_c);
    }
}

/// This is the same as `symlink` except the parameters are null-terminated pointers.
/// See also `symlink`.
pub fn symlinkC(target_path: [*]const u8, sym_link_path: [*]const u8) SymLinkError!void {
    if (windows.is_the_target) {
        const target_path_w = try windows.cStrToPrefixedFileW(target_path);
        const sym_link_path_w = try windows.cStrToPrefixedFileW(sym_link_path);
        return windows.CreateSymbolicLinkW(&sym_link_path_w, &target_path_w, 0);
    }
    switch (errno(system.symlink(target_path, sym_link_path))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => unreachable,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EDQUOT => return error.DiskQuota,
        EEXIST => return error.PathAlreadyExists,
        EIO => return error.FileSystem,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.NoSpaceLeft,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn symlinkat(target_path: []const u8, newdirfd: fd_t, sym_link_path: []const u8) SymLinkError!void {
    const target_path_c = try toPosixPath(target_path);
    const sym_link_path_c = try toPosixPath(sym_link_path);
    return symlinkatC(target_path_c, newdirfd, sym_link_path_c);
}

pub fn symlinkatC(target_path: [*]const u8, newdirfd: fd_t, sym_link_path: [*]const u8) SymLinkError!void {
    switch (errno(system.symlinkat(target_path, newdirfd, sym_link_path))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => unreachable,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EDQUOT => return error.DiskQuota,
        EEXIST => return error.PathAlreadyExists,
        EIO => return error.FileSystem,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.NoSpaceLeft,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub const UnlinkError = error{
    FileNotFound,
    AccessDenied,
    FileBusy,
    FileSystem,
    IsDir,
    SymLinkLoop,
    NameTooLong,
    NotDir,
    SystemResources,
    ReadOnlyFileSystem,
    Unexpected,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,
};

/// Delete a name and possibly the file it refers to.
/// See also `unlinkC`.
pub fn unlink(file_path: []const u8) UnlinkError!void {
    if (windows.is_the_target) {
        const file_path_w = try windows.sliceToPrefixedFileW(file_path);
        return windows.DeleteFileW(&file_path_w);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return unlinkC(&file_path_c);
    }
}

/// Same as `unlink` except the parameter is a null terminated UTF8-encoded string.
pub fn unlinkC(file_path: [*]const u8) UnlinkError!void {
    if (windows.is_the_target) {
        const file_path_w = try windows.cStrToPrefixedFileW(file_path);
        return windows.DeleteFileW(&file_path_w);
    }
    switch (errno(system.unlink(file_path))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EBUSY => return error.FileBusy,
        EFAULT => unreachable,
        EINVAL => unreachable,
        EIO => return error.FileSystem,
        EISDIR => return error.IsDir,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ENOMEM => return error.SystemResources,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

const RenameError = error{
    AccessDenied,
    FileBusy,
    DiskQuota,
    IsDir,
    SymLinkLoop,
    LinkQuotaExceeded,
    NameTooLong,
    FileNotFound,
    NotDir,
    SystemResources,
    NoSpaceLeft,
    PathAlreadyExists,
    ReadOnlyFileSystem,
    RenameAcrossMountPoints,
    InvalidUtf8,
    BadPathName,
    Unexpected,
};

/// Change the name or location of a file.
pub fn rename(old_path: []const u8, new_path: []const u8) RenameError!void {
    if (windows.is_the_target) {
        const old_path_w = try windows.sliceToPrefixedFileW(old_path);
        const new_path_w = try windows.sliceToPrefixedFileW(new_path);
        return renameW(&old_path_w, &new_path_w);
    } else {
        const old_path_c = try toPosixPath(old_path);
        const new_path_c = try toPosixPath(new_path);
        return renameC(&old_path_c, &new_path_c);
    }
}

/// Same as `rename` except the parameters are null-terminated byte arrays.
pub fn renameC(old_path: [*]const u8, new_path: [*]const u8) RenameError!void {
    if (windows.is_the_target) {
        const old_path_w = try windows.cStrToPrefixedFileW(old_path);
        const new_path_w = try windows.cStrToPrefixedFileW(new_path);
        return renameW(&old_path_w, &new_path_w);
    }
    switch (errno(system.rename(old_path, new_path))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EBUSY => return error.FileBusy,
        EDQUOT => return error.DiskQuota,
        EFAULT => unreachable,
        EINVAL => unreachable,
        EISDIR => return error.IsDir,
        ELOOP => return error.SymLinkLoop,
        EMLINK => return error.LinkQuotaExceeded,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.NoSpaceLeft,
        EEXIST => return error.PathAlreadyExists,
        ENOTEMPTY => return error.PathAlreadyExists,
        EROFS => return error.ReadOnlyFileSystem,
        EXDEV => return error.RenameAcrossMountPoints,
        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `rename` except the parameters are null-terminated UTF16LE encoded byte arrays.
/// Assumes target is Windows.
pub fn renameW(old_path: [*]const u16, new_path: [*]const u16) RenameError!void {
    const flags = windows.MOVEFILE_REPLACE_EXISTING | windows.MOVEFILE_WRITE_THROUGH;
    return windows.MoveFileExW(old_path, new_path, flags);
}

pub const MakeDirError = error{
    AccessDenied,
    DiskQuota,
    PathAlreadyExists,
    SymLinkLoop,
    LinkQuotaExceeded,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NoSpaceLeft,
    NotDir,
    ReadOnlyFileSystem,
    InvalidUtf8,
    BadPathName,
    Unexpected,
};

/// Create a directory.
/// `mode` is ignored on Windows.
pub fn mkdir(dir_path: []const u8, mode: u32) MakeDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        return windows.CreateDirectoryW(&dir_path_w, null);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return mkdirC(&dir_path_c, mode);
    }
}

/// Same as `mkdir` but the parameter is a null-terminated UTF8-encoded string.
pub fn mkdirC(dir_path: [*]const u8, mode: u32) MakeDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.cStrToPrefixedFileW(dir_path);
        return windows.CreateDirectoryW(&dir_path_w, null);
    }
    switch (errno(system.mkdir(dir_path, mode))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EDQUOT => return error.DiskQuota,
        EEXIST => return error.PathAlreadyExists,
        EFAULT => unreachable,
        ELOOP => return error.SymLinkLoop,
        EMLINK => return error.LinkQuotaExceeded,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.NoSpaceLeft,
        ENOTDIR => return error.NotDir,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub const DeleteDirError = error{
    AccessDenied,
    FileBusy,
    SymLinkLoop,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NotDir,
    DirNotEmpty,
    ReadOnlyFileSystem,
    InvalidUtf8,
    BadPathName,
    Unexpected,
};

/// Deletes an empty directory.
pub fn rmdir(dir_path: []const u8) DeleteDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        return windows.RemoveDirectoryW(&dir_path_w);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return rmdirC(&dir_path_c);
    }
}

/// Same as `rmdir` except the parameter is null-terminated.
pub fn rmdirC(dir_path: [*]const u8) DeleteDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.cStrToPrefixedFileW(dir_path);
        return windows.RemoveDirectoryW(&dir_path_w);
    }
    switch (errno(system.rmdir(dir_path))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EBUSY => return error.FileBusy,
        EFAULT => unreachable,
        EINVAL => unreachable,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOTDIR => return error.NotDir,
        EEXIST => return error.DirNotEmpty,
        ENOTEMPTY => return error.DirNotEmpty,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub const ChangeCurDirError = error{
    AccessDenied,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NotDir,
    Unexpected,
};

/// Changes the current working directory of the calling process.
/// `dir_path` is recommended to be a UTF-8 encoded string.
pub fn chdir(dir_path: []const u8) ChangeCurDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        @compileError("TODO implement chdir for Windows");
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return chdirC(&dir_path_c);
    }
}

/// Same as `chdir` except the parameter is null-terminated.
pub fn chdirC(dir_path: [*]const u8) ChangeCurDirError!void {
    if (windows.is_the_target) {
        const dir_path_w = try windows.cStrToPrefixedFileW(dir_path);
        @compileError("TODO implement chdir for Windows");
    }
    switch (errno(system.chdir(dir_path))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EFAULT => unreachable,
        EIO => return error.FileSystem,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOTDIR => return error.NotDir,
        else => |err| return unexpectedErrno(err),
    }
}

pub const ReadLinkError = error{
    AccessDenied,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NotDir,
    Unexpected,
};

/// Read value of a symbolic link.
/// The return value is a slice of `out_buffer` from index 0.
pub fn readlink(file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (windows.is_the_target) {
        const file_path_w = try windows.sliceToPrefixedFileW(file_path);
        @compileError("TODO implement readlink for Windows");
    } else {
        const file_path_c = try toPosixPath(file_path);
        return readlinkC(&file_path_c, out_buffer);
    }
}

/// Same as `readlink` except `file_path` is null-terminated.
pub fn readlinkC(file_path: [*]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (windows.is_the_target) {
        const file_path_w = try windows.cStrToPrefixedFileW(file_path);
        @compileError("TODO implement readlink for Windows");
    }
    const rc = system.readlink(file_path, out_buffer.ptr, out_buffer.len);
    switch (errno(rc)) {
        0 => return out_buffer[0..@bitCast(usize, rc)],
        EACCES => return error.AccessDenied,
        EFAULT => unreachable,
        EINVAL => unreachable,
        EIO => return error.FileSystem,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOTDIR => return error.NotDir,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SetIdError = error{
    ResourceLimitReached,
    InvalidUserId,
    PermissionDenied,
    Unexpected,
};

pub fn setuid(uid: u32) SetIdError!void {
    switch (errno(system.setuid(uid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setreuid(ruid: u32, euid: u32) SetIdError!void {
    switch (errno(system.setreuid(ruid, euid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setgid(gid: u32) SetIdError!void {
    switch (errno(system.setgid(gid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setregid(rgid: u32, egid: u32) SetIdError!void {
    switch (errno(system.setregid(rgid, egid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

/// Test whether a file descriptor refers to a terminal.
pub fn isatty(handle: fd_t) bool {
    if (windows.is_the_target) {
        if (isCygwinPty(handle))
            return true;

        var out: windows.DWORD = undefined;
        return windows.kernel32.GetConsoleMode(handle, &out) != 0;
    }
    if (builtin.link_libc) {
        return system.isatty(handle) != 0;
    }
    if (wasi.is_the_target) {
        @compileError("TODO implement std.os.isatty for WASI");
    }
    if (linux.is_the_target) {
        var wsz: linux.winsize = undefined;
        return linux.syscall3(linux.SYS_ioctl, @bitCast(usize, isize(handle)), linux.TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
    }
    unreachable;
}

pub fn isCygwinPty(handle: fd_t) bool {
    if (!windows.is_the_target) return false;

    const size = @sizeOf(windows.FILE_NAME_INFO);
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = [_]u8{0} ** (size + windows.MAX_PATH);

    if (windows.kernel32.GetFileInformationByHandleEx(
        handle,
        windows.FileNameInfo,
        @ptrCast(*c_void, &name_info_bytes),
        name_info_bytes.len,
    ) == 0) {
        return false;
    }

    const name_info = @ptrCast(*const windows.FILE_NAME_INFO, &name_info_bytes[0]);
    const name_bytes = name_info_bytes[size .. size + usize(name_info.FileNameLength)];
    const name_wide = @bytesToSlice(u16, name_bytes);
    return mem.indexOf(u16, name_wide, [_]u16{ 'm', 's', 'y', 's', '-' }) != null or
        mem.indexOf(u16, name_wide, [_]u16{ '-', 'p', 't', 'y' }) != null;
}

pub const SocketError = error{
    /// Permission to create a socket of the specified type and/or
    /// pro‐tocol is denied.
    PermissionDenied,

    /// The implementation does not support the specified address family.
    AddressFamilyNotSupported,

    /// Unknown protocol, or protocol family not available.
    ProtocolFamilyNotAvailable,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Insufficient memory is available. The socket cannot be created until sufficient
    /// resources are freed.
    SystemResources,

    /// The protocol type or the specified protocol is not supported within this domain.
    ProtocolNotSupported,

    Unexpected,
};

pub fn socket(domain: u32, socket_type: u32, protocol: u32) SocketError!i32 {
    const rc = system.socket(domain, socket_type, protocol);
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        EACCES => return error.PermissionDenied,
        EAFNOSUPPORT => return error.AddressFamilyNotSupported,
        EINVAL => return error.ProtocolFamilyNotAvailable,
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENOBUFS, ENOMEM => return error.SystemResources,
        EPROTONOSUPPORT => return error.ProtocolNotSupported,
        else => |err| return unexpectedErrno(err),
    }
}

pub const BindError = error{
    /// The address is protected, and the user is not the superuser.
    /// For UNIX domain sockets: Search permission is denied on  a  component
    /// of  the  path  prefix.
    AccessDenied,

    /// The given address is already in use, or in the case of Internet domain sockets,
    /// The  port number was specified as zero in the socket
    /// address structure, but, upon attempting to bind to  an  ephemeral  port,  it  was
    /// determined  that  all  port  numbers in the ephemeral port range are currently in
    /// use.  See the discussion of /proc/sys/net/ipv4/ip_local_port_range ip(7).
    AddressInUse,

    /// A nonexistent interface was requested or the requested address was not local.
    AddressNotAvailable,

    /// Too many symbolic links were encountered in resolving addr.
    SymLinkLoop,

    /// addr is too long.
    NameTooLong,

    /// A component in the directory prefix of the socket pathname does not exist.
    FileNotFound,

    /// Insufficient kernel memory was available.
    SystemResources,

    /// A component of the path prefix is not a directory.
    NotDir,

    /// The socket inode would reside on a read-only filesystem.
    ReadOnlyFileSystem,

    Unexpected,
};

/// addr is `*const T` where T is one of the sockaddr
pub fn bind(fd: i32, addr: *const sockaddr) BindError!void {
    const rc = system.bind(fd, addr, @sizeOf(sockaddr));
    switch (errno(rc)) {
        0 => return,
        EACCES => return error.AccessDenied,
        EADDRINUSE => return error.AddressInUse,
        EBADF => unreachable, // always a race condition if this error is returned
        EINVAL => unreachable,
        ENOTSOCK => unreachable,
        EADDRNOTAVAIL => return error.AddressNotAvailable,
        EFAULT => unreachable,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOTDIR => return error.NotDir,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

const ListenError = error{
    /// Another socket is already listening on the same port.
    /// For Internet domain sockets, the  socket referred to by sockfd had not previously
    /// been bound to an address and, upon attempting to bind it to an ephemeral port, it
    /// was determined that all port numbers in the ephemeral port range are currently in
    /// use.  See the discussion of /proc/sys/net/ipv4/ip_local_port_range in ip(7).
    AddressInUse,

    /// The file descriptor sockfd does not refer to a socket.
    FileDescriptorNotASocket,

    /// The socket is not of a type that supports the listen() operation.
    OperationNotSupported,

    Unexpected,
};

pub fn listen(sockfd: i32, backlog: u32) ListenError!void {
    const rc = system.listen(sockfd, backlog);
    switch (errno(rc)) {
        0 => return,
        EADDRINUSE => return error.AddressInUse,
        EBADF => unreachable,
        ENOTSOCK => return error.FileDescriptorNotASocket,
        EOPNOTSUPP => return error.OperationNotSupported,
        else => |err| return unexpectedErrno(err),
    }
}

pub const AcceptError = error{
    ConnectionAborted,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Not enough free memory.  This often means that the memory allocation  is  limited
    /// by the socket buffer limits, not by the system memory.
    SystemResources,

    /// The file descriptor sockfd does not refer to a socket.
    FileDescriptorNotASocket,

    /// The referenced socket is not of type SOCK_STREAM.
    OperationNotSupported,

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    Unexpected,
};

/// Accept a connection on a socket. `fd` must be opened in blocking mode.
/// See also `accept4_async`.
pub fn accept4(fd: i32, addr: *sockaddr, flags: u32) AcceptError!i32 {
    while (true) {
        var sockaddr_size = u32(@sizeOf(sockaddr));
        const rc = system.accept4(fd, addr, &sockaddr_size, flags);
        switch (errno(rc)) {
            0 => return @intCast(i32, rc),
            EINTR => continue,
            else => |err| return unexpectedErrno(err),

            EAGAIN => unreachable, // This function is for blocking only.
            EBADF => unreachable, // always a race condition
            ECONNABORTED => return error.ConnectionAborted,
            EFAULT => unreachable,
            EINVAL => unreachable,
            EMFILE => return error.ProcessFdQuotaExceeded,
            ENFILE => return error.SystemFdQuotaExceeded,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            ENOTSOCK => return error.FileDescriptorNotASocket,
            EOPNOTSUPP => return error.OperationNotSupported,
            EPROTO => return error.ProtocolFailure,
            EPERM => return error.BlockedByFirewall,
        }
    }
}

/// This is the same as `accept4` except `fd` is expected to be non-blocking.
/// Returns -1 if would block.
pub fn accept4_async(fd: i32, addr: *sockaddr, flags: u32) AcceptError!i32 {
    while (true) {
        var sockaddr_size = u32(@sizeOf(sockaddr));
        const rc = system.accept4(fd, addr, &sockaddr_size, flags);
        switch (errno(rc)) {
            0 => return @intCast(i32, rc),
            EINTR => continue,
            else => |err| return unexpectedErrno(err),

            EAGAIN => return -1,
            EBADF => unreachable, // always a race condition
            ECONNABORTED => return error.ConnectionAborted,
            EFAULT => unreachable,
            EINVAL => unreachable,
            EMFILE => return error.ProcessFdQuotaExceeded,
            ENFILE => return error.SystemFdQuotaExceeded,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            ENOTSOCK => return error.FileDescriptorNotASocket,
            EOPNOTSUPP => return error.OperationNotSupported,
            EPROTO => return error.ProtocolFailure,
            EPERM => return error.BlockedByFirewall,
        }
    }
}

pub const EpollCreateError = error{
    /// The  per-user   limit   on   the   number   of   epoll   instances   imposed   by
    /// /proc/sys/fs/epoll/max_user_instances  was encountered.  See epoll(7) for further
    /// details.
    /// Or, The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// There was insufficient memory to create the kernel object.
    SystemResources,

    Unexpected,
};

pub fn epoll_create1(flags: u32) EpollCreateError!i32 {
    const rc = system.epoll_create1(flags);
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        else => |err| return unexpectedErrno(err),

        EINVAL => unreachable,
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENOMEM => return error.SystemResources,
    }
}

pub const EpollCtlError = error{
    /// op was EPOLL_CTL_ADD, and the supplied file descriptor fd is  already  registered
    /// with this epoll instance.
    FileDescriptorAlreadyPresentInSet,

    /// fd refers to an epoll instance and this EPOLL_CTL_ADD operation would result in a
    /// circular loop of epoll instances monitoring one another.
    OperationCausesCircularLoop,

    /// op was EPOLL_CTL_MOD or EPOLL_CTL_DEL, and fd is not registered with  this  epoll
    /// instance.
    FileDescriptorNotRegistered,

    /// There was insufficient memory to handle the requested op control operation.
    SystemResources,

    /// The  limit  imposed  by /proc/sys/fs/epoll/max_user_watches was encountered while
    /// trying to register (EPOLL_CTL_ADD) a new file descriptor on  an  epoll  instance.
    /// See epoll(7) for further details.
    UserResourceLimitReached,

    /// The target file fd does not support epoll.  This error can occur if fd refers to,
    /// for example, a regular file or a directory.
    FileDescriptorIncompatibleWithEpoll,

    Unexpected,
};

pub fn epoll_ctl(epfd: i32, op: u32, fd: i32, event: ?*epoll_event) EpollCtlError!void {
    const rc = system.epoll_ctl(epfd, op, fd, event);
    switch (errno(rc)) {
        0 => return,
        else => |err| return unexpectedErrno(err),

        EBADF => unreachable, // always a race condition if this happens
        EEXIST => return error.FileDescriptorAlreadyPresentInSet,
        EINVAL => unreachable,
        ELOOP => return error.OperationCausesCircularLoop,
        ENOENT => return error.FileDescriptorNotRegistered,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.UserResourceLimitReached,
        EPERM => return error.FileDescriptorIncompatibleWithEpoll,
    }
}

/// Waits for an I/O event on an epoll file descriptor.
/// Returns the number of file descriptors ready for the requested I/O,
/// or zero if no file descriptor became ready during the requested timeout milliseconds.
pub fn epoll_wait(epfd: i32, events: []epoll_event, timeout: i32) usize {
    while (true) {
        // TODO get rid of the @intCast
        const rc = system.epoll_wait(epfd, events.ptr, @intCast(u32, events.len), timeout);
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),
            EINTR => continue,
            EBADF => unreachable,
            EFAULT => unreachable,
            EINVAL => unreachable,
            else => unreachable,
        }
    }
}

pub const EventFdError = error{
    SystemResources,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    Unexpected,
};

pub fn eventfd(initval: u32, flags: u32) EventFdError!i32 {
    const rc = system.eventfd(initval, flags);
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        else => |err| return unexpectedErrno(err),

        EINVAL => unreachable, // invalid parameters
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENODEV => return error.SystemResources,
        ENOMEM => return error.SystemResources,
    }
}

pub const GetSockNameError = error{
    /// Insufficient resources were available in the system to perform the operation.
    SystemResources,

    Unexpected,
};

pub fn getsockname(sockfd: i32) GetSockNameError!sockaddr {
    var addr: sockaddr = undefined;
    var addrlen: socklen_t = @sizeOf(sockaddr);
    switch (errno(system.getsockname(sockfd, &addr, &addrlen))) {
        0 => return addr,
        else => |err| return unexpectedErrno(err),

        EBADF => unreachable, // always a race condition
        EFAULT => unreachable,
        EINVAL => unreachable, // invalid parameters
        ENOTSOCK => unreachable,
        ENOBUFS => return error.SystemResources,
    }
}

pub const ConnectError = error{
    /// For UNIX domain sockets, which are identified by pathname: Write permission is denied on  the  socket
    /// file,  or  search  permission  is  denied  for  one of the directories in the path prefix.
    /// or
    /// The user tried to connect to a broadcast address without having the socket broadcast flag enabled  or
    /// the connection request failed because of a local firewall rule.
    PermissionDenied,

    /// Local address is already in use.
    AddressInUse,

    /// (Internet  domain  sockets)  The  socket  referred  to  by sockfd had not previously been bound to an
    /// address and, upon attempting to bind it to an ephemeral port, it was determined that all port numbers
    /// in    the    ephemeral    port    range    are   currently   in   use.    See   the   discussion   of
    /// /proc/sys/net/ipv4/ip_local_port_range in ip(7).
    AddressNotAvailable,

    /// The passed address didn't have the correct address family in its sa_family field.
    AddressFamilyNotSupported,

    /// Insufficient entries in the routing cache.
    SystemResources,

    /// A connect() on a stream socket found no one listening on the remote address.
    ConnectionRefused,

    /// Network is unreachable.
    NetworkUnreachable,

    /// Timeout  while  attempting  connection.   The server may be too busy to accept new connections.  Note
    /// that for IP sockets the timeout may be very long when syncookies are enabled on the server.
    ConnectionTimedOut,

    Unexpected,
};

/// Initiate a connection on a socket.
/// This is for blocking file descriptors only.
/// For non-blocking, see `connect_async`.
pub fn connect(sockfd: i32, sock_addr: *sockaddr, len: socklen_t) ConnectError!void {
    while (true) {
        switch (errno(system.connect(sockfd, sock_addr, @sizeOf(sockaddr)))) {
            0 => return,
            EACCES => return error.PermissionDenied,
            EPERM => return error.PermissionDenied,
            EADDRINUSE => return error.AddressInUse,
            EADDRNOTAVAIL => return error.AddressNotAvailable,
            EAFNOSUPPORT => return error.AddressFamilyNotSupported,
            EAGAIN => return error.SystemResources,
            EALREADY => unreachable, // The socket is nonblocking and a previous connection attempt has not yet been completed.
            EBADF => unreachable, // sockfd is not a valid open file descriptor.
            ECONNREFUSED => return error.ConnectionRefused,
            EFAULT => unreachable, // The socket structure address is outside the user's address space.
            EINPROGRESS => unreachable, // The socket is nonblocking and the connection cannot be completed immediately.
            EINTR => continue,
            EISCONN => unreachable, // The socket is already connected.
            ENETUNREACH => return error.NetworkUnreachable,
            ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            EPROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            ETIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Same as `connect` except it is for blocking socket file descriptors.
/// It expects to receive EINPROGRESS`.
pub fn connect_async(sockfd: i32, sock_addr: *sockaddr, len: socklen_t) ConnectError!void {
    while (true) {
        switch (errno(system.connect(sockfd, sock_addr, @sizeOf(sockaddr)))) {
            EINTR => continue,
            0, EINPROGRESS => return,
            EACCES => return error.PermissionDenied,
            EPERM => return error.PermissionDenied,
            EADDRINUSE => return error.AddressInUse,
            EADDRNOTAVAIL => return error.AddressNotAvailable,
            EAFNOSUPPORT => return error.AddressFamilyNotSupported,
            EAGAIN => return error.SystemResources,
            EALREADY => unreachable, // The socket is nonblocking and a previous connection attempt has not yet been completed.
            EBADF => unreachable, // sockfd is not a valid open file descriptor.
            ECONNREFUSED => return error.ConnectionRefused,
            EFAULT => unreachable, // The socket structure address is outside the user's address space.
            EISCONN => unreachable, // The socket is already connected.
            ENETUNREACH => return error.NetworkUnreachable,
            ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            EPROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            ETIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn getsockoptError(sockfd: i32) ConnectError!void {
    var err_code: u32 = undefined;
    var size: u32 = @sizeOf(u32);
    const rc = system.getsockopt(sockfd, SOL_SOCKET, SO_ERROR, @ptrCast([*]u8, &err_code), &size);
    assert(size == 4);
    switch (errno(rc)) {
        0 => switch (err_code) {
            0 => return,
            EACCES => return error.PermissionDenied,
            EPERM => return error.PermissionDenied,
            EADDRINUSE => return error.AddressInUse,
            EADDRNOTAVAIL => return error.AddressNotAvailable,
            EAFNOSUPPORT => return error.AddressFamilyNotSupported,
            EAGAIN => return error.SystemResources,
            EALREADY => unreachable, // The socket is nonblocking and a previous connection attempt has not yet been completed.
            EBADF => unreachable, // sockfd is not a valid open file descriptor.
            ECONNREFUSED => return error.ConnectionRefused,
            EFAULT => unreachable, // The socket structure address is outside the user's address space.
            EISCONN => unreachable, // The socket is already connected.
            ENETUNREACH => return error.NetworkUnreachable,
            ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            EPROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            ETIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return unexpectedErrno(err),
        },
        EBADF => unreachable, // The argument sockfd is not a valid file descriptor.
        EFAULT => unreachable, // The address pointed to by optval or optlen is not in a valid part of the process address space.
        EINVAL => unreachable,
        ENOPROTOOPT => unreachable, // The option is unknown at the level indicated.
        ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
        else => |err| return unexpectedErrno(err),
    }
}

pub fn waitpid(pid: i32, flags: u32) u32 {
    // TODO allow implicit pointer cast from *u32 to *c_uint ?
    const Status = if (builtin.link_libc) c_uint else u32;
    var status: Status = undefined;
    while (true) {
        switch (errno(system.waitpid(pid, &status, flags))) {
            0 => return @bitCast(u32, status),
            EINTR => continue,
            ECHILD => unreachable, // The process specified does not exist. It would be a race condition to handle this error.
            EINVAL => unreachable, // The options argument was invalid
            else => unreachable,
        }
    }
}

pub const FStatError = error{
    SystemResources,
    Unexpected,
};

pub fn fstat(fd: fd_t) FStatError!Stat {
    var stat: Stat = undefined;
    if (darwin.is_the_target) {
        switch (darwin.getErrno(darwin.@"fstat$INODE64"(fd, &stat))) {
            0 => return stat,
            EBADF => unreachable, // Always a race condition.
            ENOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }

    switch (errno(system.fstat(fd, &stat))) {
        0 => return stat,
        EBADF => unreachable, // Always a race condition.
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const KQueueError = error{
    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    Unexpected,
};

pub fn kqueue() KQueueError!i32 {
    const rc = system.kqueue();
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        else => |err| return unexpectedErrno(err),
    }
}

pub const KEventError = error{
    /// The process does not have permission to register a filter.
    AccessDenied,

    /// The event could not be found to be modified or deleted.
    EventNotFound,

    /// No memory was available to register the event.
    SystemResources,

    /// The specified process to attach to does not exist.
    ProcessNotFound,

    /// changelist or eventlist had too many items on it.
    /// TODO remove this possibility
    Overflow,
};

pub fn kevent(
    kq: i32,
    changelist: []const Kevent,
    eventlist: []Kevent,
    timeout: ?*const timespec,
) KEventError!usize {
    while (true) {
        const rc = system.kevent(
            kq,
            changelist.ptr,
            try math.cast(c_int, changelist.len),
            eventlist.ptr,
            try math.cast(c_int, eventlist.len),
            timeout,
        );
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),
            EACCES => return error.AccessDenied,
            EFAULT => unreachable,
            EBADF => unreachable, // Always a race condition.
            EINTR => continue,
            EINVAL => unreachable,
            ENOENT => return error.EventNotFound,
            ENOMEM => return error.SystemResources,
            ESRCH => return error.ProcessNotFound,
            else => unreachable,
        }
    }
}

pub const INotifyInitError = error{
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    SystemResources,
    Unexpected,
};

/// initialize an inotify instance
pub fn inotify_init1(flags: u32) INotifyInitError!i32 {
    const rc = system.inotify_init1(flags);
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        EINVAL => unreachable,
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const INotifyAddWatchError = error{
    AccessDenied,
    NameTooLong,
    FileNotFound,
    SystemResources,
    UserResourceLimitReached,
    Unexpected,
};

/// add a watch to an initialized inotify instance
pub fn inotify_add_watch(inotify_fd: i32, pathname: []const u8, mask: u32) INotifyAddWatchError!i32 {
    const pathname_c = try toPosixPath(pathname);
    return inotify_add_watchC(inotify_fd, &pathname_c, mask);
}

/// Same as `inotify_add_watch` except pathname is null-terminated.
pub fn inotify_add_watchC(inotify_fd: i32, pathname: [*]const u8, mask: u32) INotifyAddWatchError!i32 {
    const rc = system.inotify_add_watch(inotify_fd, pathname, mask);
    switch (errno(rc)) {
        0 => return @intCast(i32, rc),
        EACCES => return error.AccessDenied,
        EBADF => unreachable,
        EFAULT => unreachable,
        EINVAL => unreachable,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOSPC => return error.UserResourceLimitReached,
        else => |err| return unexpectedErrno(err),
    }
}

/// remove an existing watch from an inotify instance
pub fn inotify_rm_watch(inotify_fd: i32, wd: i32) void {
    switch (errno(system.inotify_rm_watch(inotify_fd, wd))) {
        0 => return,
        EBADF => unreachable,
        EINVAL => unreachable,
        else => unreachable,
    }
}

pub const MProtectError = error{
    /// The memory cannot be given the specified access.  This can happen, for example, if you
    /// mmap(2)  a  file  to  which  you have read-only access, then ask mprotect() to mark it
    /// PROT_WRITE.
    AccessDenied,

    /// Changing  the  protection  of a memory region would result in the total number of map‐
    /// pings with distinct attributes (e.g., read versus read/write protection) exceeding the
    /// allowed maximum.  (For example, making the protection of a range PROT_READ in the mid‐
    /// dle of a region currently protected as PROT_READ|PROT_WRITE would result in three map‐
    /// pings: two read/write mappings at each end and a read-only mapping in the middle.)
    OutOfMemory,
    Unexpected,
};

/// `memory.len` must be page-aligned.
pub fn mprotect(memory: []align(mem.page_size) u8, protection: u32) MProtectError!void {
    assert(mem.isAligned(memory.len, mem.page_size));
    switch (errno(system.mprotect(memory.ptr, memory.len, protection))) {
        0 => return,
        EINVAL => unreachable,
        EACCES => return error.AccessDenied,
        ENOMEM => return error.OutOfMemory,
        else => |err| return unexpectedErrno(err),
    }
}

pub const ForkError = error{
    SystemResources,
    Unexpected,
};

pub fn fork() ForkError!pid_t {
    const rc = system.fork();
    switch (errno(rc)) {
        0 => return @intCast(pid_t, rc),
        EAGAIN => return error.SystemResources,
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const MMapError = error{
    /// The underlying filesystem of the specified file does not support memory mapping.
    MemoryMappingNotSupported,

    /// A file descriptor refers to a non-regular file. Or a file mapping was requested,
    /// but the file descriptor is not open for reading. Or `MAP_SHARED` was requested
    /// and `PROT_WRITE` is set, but the file descriptor is not open in `O_RDWR` mode.
    /// Or `PROT_WRITE` is set, but the file is append-only.
    AccessDenied,

    /// The `prot` argument asks for `PROT_EXEC` but the mapped area belongs to a file on
    /// a filesystem that was mounted no-exec.
    PermissionDenied,
    LockedMemoryLimitExceeded,
    OutOfMemory,
    Unexpected,
};

/// Map files or devices into memory.
/// Use of a mapped region can result in these signals:
/// * SIGSEGV - Attempted write into a region mapped as read-only.
/// * SIGBUS - Attempted  access to a portion of the buffer that does not correspond to the file
pub fn mmap(
    ptr: ?[*]align(mem.page_size) u8,
    length: usize,
    prot: u32,
    flags: u32,
    fd: fd_t,
    offset: isize,
) MMapError![]align(mem.page_size) u8 {
    const err = if (builtin.link_libc) blk: {
        const rc = std.c.mmap(ptr, length, prot, flags, fd, offset);
        if (rc != MAP_FAILED) return @ptrCast([*]align(mem.page_size) u8, @alignCast(mem.page_size, rc))[0..length];
        break :blk @intCast(usize, system._errno().*);
    } else blk: {
        const rc = system.mmap(ptr, length, prot, flags, fd, offset);
        const err = errno(rc);
        if (err == 0) return @intToPtr([*]align(mem.page_size) u8, rc)[0..length];
        break :blk err;
    };
    switch (err) {
        ETXTBSY => return error.AccessDenied,
        EACCES => return error.AccessDenied,
        EPERM => return error.PermissionDenied,
        EAGAIN => return error.LockedMemoryLimitExceeded,
        EBADF => unreachable, // Always a race condition.
        EOVERFLOW => unreachable, // The number of pages used for length + offset would overflow.
        ENODEV => return error.MemoryMappingNotSupported,
        EINVAL => unreachable, // Invalid parameters to mmap()
        ENOMEM => return error.OutOfMemory,
        else => return unexpectedErrno(err),
    }
}

/// Deletes the mappings for the specified address range, causing
/// further references to addresses within the range to generate invalid memory references.
/// Note that while POSIX allows unmapping a region in the middle of an existing mapping,
/// Zig's munmap function does not, for two reasons:
/// * It violates the Zig principle that resource deallocation must succeed.
/// * The Windows function, VirtualFree, has this restriction.
pub fn munmap(memory: []align(mem.page_size) u8) void {
    switch (errno(system.munmap(memory.ptr, memory.len))) {
        0 => return,
        EINVAL => unreachable, // Invalid parameters.
        ENOMEM => unreachable, // Attempted to unmap a region in the middle of an existing mapping.
        else => unreachable,
    }
}

pub const AccessError = error{
    PermissionDenied,
    FileNotFound,
    NameTooLong,
    InputOutput,
    SystemResources,
    BadPathName,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    Unexpected,
};

/// check user's permissions for a file
/// TODO currently this assumes `mode` is `F_OK` on Windows.
pub fn access(path: []const u8, mode: u32) AccessError!void {
    if (windows.is_the_target) {
        const path_w = try windows.sliceToPrefixedFileW(path);
        _ = try windows.GetFileAttributesW(&path_w);
        return;
    }
    const path_c = try toPosixPath(path);
    return accessC(&path_c, mode);
}

/// Same as `access` except `path` is null-terminated.
pub fn accessC(path: [*]const u8, mode: u32) AccessError!void {
    if (windows.is_the_target) {
        const path_w = try windows.cStrToPrefixedFileW(path);
        _ = try windows.GetFileAttributesW(&path_w);
        return;
    }
    switch (errno(system.access(path, mode))) {
        0 => return,
        EACCES => return error.PermissionDenied,
        EROFS => return error.PermissionDenied,
        ELOOP => return error.PermissionDenied,
        ETXTBSY => return error.PermissionDenied,
        ENOTDIR => return error.FileNotFound,
        ENOENT => return error.FileNotFound,

        ENAMETOOLONG => return error.NameTooLong,
        EINVAL => unreachable,
        EFAULT => unreachable,
        EIO => return error.InputOutput,
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const PipeError = error{
    SystemFdQuotaExceeded,
    ProcessFdQuotaExceeded,
    Unexpected,
};

/// Creates a unidirectional data channel that can be used for interprocess communication.
pub fn pipe() PipeError![2]fd_t {
    var fds: [2]fd_t = undefined;
    switch (errno(system.pipe(&fds))) {
        0 => return fds,
        EINVAL => unreachable, // Invalid parameters to pipe()
        EFAULT => unreachable, // Invalid fds pointer
        ENFILE => return error.SystemFdQuotaExceeded,
        EMFILE => return error.ProcessFdQuotaExceeded,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn pipe2(flags: u32) PipeError![2]fd_t {
    var fds: [2]fd_t = undefined;
    switch (errno(system.pipe2(&fds, flags))) {
        0 => return fds,
        EINVAL => unreachable, // Invalid flags
        EFAULT => unreachable, // Invalid fds pointer
        ENFILE => return error.SystemFdQuotaExceeded,
        EMFILE => return error.ProcessFdQuotaExceeded,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SysCtlError = error{
    PermissionDenied,
    SystemResources,
    NameTooLong,
    Unexpected,
};

pub fn sysctl(
    name: []const c_int,
    oldp: ?*c_void,
    oldlenp: ?*usize,
    newp: ?*c_void,
    newlen: usize,
) SysCtlError!void {
    const name_len = math.cast(c_uint, name.len) catch return error.NameTooLong;
    switch (errno(system.sysctl(name.ptr, name_len, oldp, oldlenp, newp, newlen))) {
        0 => return,
        EFAULT => unreachable,
        EPERM => return error.PermissionDenied,
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn sysctlbynameC(
    name: [*]const u8,
    oldp: ?*c_void,
    oldlenp: ?*usize,
    newp: ?*c_void,
    newlen: usize,
) SysCtlError!void {
    switch (errno(system.sysctlbyname(name, oldp, oldlenp, newp, newlen))) {
        0 => return,
        EFAULT => unreachable,
        EPERM => return error.PermissionDenied,
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn gettimeofday(tv: ?*timeval, tz: ?*timezone) void {
    switch (errno(system.gettimeofday(tv, tz))) {
        0 => return,
        EINVAL => unreachable,
        else => unreachable,
    }
}

pub const SeekError = error{
    Unseekable,
    Unexpected,
};

/// Repositions read/write file offset relative to the beginning.
pub fn lseek_SET(fd: fd_t, offset: u64) SeekError!void {
    if (linux.is_the_target and !builtin.link_libc and @sizeOf(usize) == 4) {
        switch (errno(system.llseek(fd, offset, null, SEEK_SET))) {
            0 => return,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (windows.is_the_target) {
        return windows.SetFilePointerEx_BEGIN(fd, offset);
    }
    const ipos = @bitCast(i64, offset); // the OS treats this as unsigned
    switch (errno(system.lseek(fd, ipos, SEEK_SET))) {
        0 => return,
        EBADF => unreachable, // always a race condition
        EINVAL => return error.Unseekable,
        EOVERFLOW => return error.Unseekable,
        ESPIPE => return error.Unseekable,
        ENXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Repositions read/write file offset relative to the current offset.
pub fn lseek_CUR(fd: fd_t, offset: i64) SeekError!void {
    if (linux.is_the_target and !builtin.link_libc and @sizeOf(usize) == 4) {
        switch (errno(system.llseek(fd, @bitCast(u64, offset), null, SEEK_CUR))) {
            0 => return,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (windows.is_the_target) {
        return windows.SetFilePointerEx_CURRENT(fd, offset);
    }
    switch (errno(system.lseek(fd, offset, SEEK_CUR))) {
        0 => return,
        EBADF => unreachable, // always a race condition
        EINVAL => return error.Unseekable,
        EOVERFLOW => return error.Unseekable,
        ESPIPE => return error.Unseekable,
        ENXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Repositions read/write file offset relative to the end.
pub fn lseek_END(fd: fd_t, offset: i64) SeekError!void {
    if (linux.is_the_target and !builtin.link_libc and @sizeOf(usize) == 4) {
        switch (errno(system.llseek(fd, @bitCast(u64, offset), null, SEEK_END))) {
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (windows.is_the_target) {
        return windows.SetFilePointerEx_END(fd, offset);
    }
    switch (errno(system.lseek(fd, offset, SEEK_END))) {
        0 => return,
        EBADF => unreachable, // always a race condition
        EINVAL => return error.Unseekable,
        EOVERFLOW => return error.Unseekable,
        ESPIPE => return error.Unseekable,
        ENXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Returns the read/write file offset relative to the beginning.
pub fn lseek_CUR_get(fd: fd_t) SeekError!u64 {
    if (linux.is_the_target and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, 0, &result, SEEK_CUR))) {
            0 => return result,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (windows.is_the_target) {
        return windows.SetFilePointerEx_CURRENT_get(fd);
    }
    const rc = system.lseek(fd, 0, SEEK_CUR);
    switch (errno(rc)) {
        0 => return @bitCast(u64, rc),
        EBADF => unreachable, // always a race condition
        EINVAL => return error.Unseekable,
        EOVERFLOW => return error.Unseekable,
        ESPIPE => return error.Unseekable,
        ENXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

pub const RealPathError = error{
    FileNotFound,
    AccessDenied,
    NameTooLong,
    NotSupported,
    NotDir,
    SymLinkLoop,
    InputOutput,
    FileTooBig,
    IsDir,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
    NoSpaceLeft,
    FileSystem,
    BadPathName,
    DeviceBusy,

    SharingViolation,
    PipeBusy,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    PathAlreadyExists,

    Unexpected,
};

/// Return the canonicalized absolute pathname.
/// Expands all symbolic links and resolves references to `.`, `..`, and
/// extra `/` characters in `pathname`.
/// The return value is a slice of `out_buffer`, but not necessarily from the beginning.
/// See also `realpathC` and `realpathW`.
pub fn realpath(pathname: []const u8, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
    if (windows.is_the_target) {
        const pathname_w = try windows.sliceToPrefixedFileW(pathname);
        return realpathW(&pathname_w, out_buffer);
    }
    const pathname_c = try toPosixPath(pathname);
    return realpathC(&pathname_c, out_buffer);
}

/// Same as `realpath` except `pathname` is null-terminated.
pub fn realpathC(pathname: [*]const u8, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
    if (windows.is_the_target) {
        const pathname_w = try windows.cStrToPrefixedFileW(pathname);
        return realpathW(&pathname_w, out_buffer);
    }
    if (linux.is_the_target and !builtin.link_libc) {
        const fd = try openC(pathname, linux.O_PATH | linux.O_NONBLOCK | linux.O_CLOEXEC, 0);
        defer close(fd);

        var procfs_buf: ["/proc/self/fd/-2147483648\x00".len]u8 = undefined;
        const proc_path = std.fmt.bufPrint(procfs_buf[0..], "/proc/self/fd/{}\x00", fd) catch unreachable;

        return readlinkC(proc_path.ptr, out_buffer);
    }
    const result_path = std.c.realpath(pathname, out_buffer) orelse switch (std.c._errno().*) {
        EINVAL => unreachable,
        EBADF => unreachable,
        EFAULT => unreachable,
        EACCES => return error.AccessDenied,
        ENOENT => return error.FileNotFound,
        ENOTSUP => return error.NotSupported,
        ENOTDIR => return error.NotDir,
        ENAMETOOLONG => return error.NameTooLong,
        ELOOP => return error.SymLinkLoop,
        EIO => return error.InputOutput,
        else => |err| return unexpectedErrno(@intCast(usize, err)),
    };
    return mem.toSlice(u8, result_path);
}

/// Same as `realpath` except `pathname` is null-terminated and UTF16LE-encoded.
pub fn realpathW(pathname: [*]const u16, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
    const h_file = try windows.CreateFileW(
        pathname,
        windows.GENERIC_READ,
        windows.FILE_SHARE_READ,
        null,
        windows.OPEN_EXISTING,
        windows.FILE_ATTRIBUTE_NORMAL,
        null,
    );
    defer windows.CloseHandle(h_file);

    var wide_buf: [windows.PATH_MAX_WIDE]u16 = undefined;
    const wide_len = try windows.GetFinalPathNameByHandleW(h_file, &wide_buf, wide_buf.len, windows.VOLUME_NAME_DOS);
    assert(wide_len <= wide_buf.len);
    const wide_slice = wide_buf[0..wide_len];

    // Windows returns \\?\ prepended to the path.
    // We strip it to make this function consistent across platforms.
    const prefix = [_]u16{ '\\', '\\', '?', '\\' };
    const start_index = if (mem.startsWith(u16, wide_slice, prefix)) prefix.len else 0;

    // Trust that Windows gives us valid UTF-16LE.
    const end_index = std.unicode.utf16leToUtf8(out_buffer, wide_slice[start_index..]) catch unreachable;
    return out_buffer[0..end_index];
}

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn nanosleep(seconds: u64, nanoseconds: u64) void {
    var req = timespec{
        .tv_sec = math.cast(isize, seconds) catch math.maxInt(isize),
        .tv_nsec = math.cast(isize, nanoseconds) catch math.maxInt(isize),
    };
    var rem: timespec = undefined;
    while (true) {
        switch (errno(system.nanosleep(&req, &rem))) {
            EFAULT => unreachable,
            EINVAL => {
                // Sometimes Darwin returns EINVAL for no reason.
                // We treat it as a spurious wakeup.
                return;
            },
            EINTR => {
                req = rem;
                continue;
            },
            // This prong handles success as well as unexpected errors.
            else => return,
        }
    }
}

pub fn dl_iterate_phdr(comptime T: type, callback: extern fn (info: *dl_phdr_info, size: usize, data: ?*T) i32, data: ?*T) isize {
    // This is implemented only for systems using ELF executables
    if (windows.is_the_target or builtin.os == .uefi or wasi.is_the_target or darwin.is_the_target)
        @compileError("dl_iterate_phdr is not available for this target");

    if (builtin.link_libc) {
        return system.dl_iterate_phdr(
            @ptrCast(std.c.dl_iterate_phdr_callback, callback),
            @ptrCast(?*c_void, data),
        );
    }

    const elf_base = std.process.getBaseAddress();
    const ehdr = @intToPtr(*elf.Ehdr, elf_base);
    // Make sure the base address points to an ELF image
    assert(mem.eql(u8, ehdr.e_ident[0..4], "\x7fELF"));
    const n_phdr = ehdr.e_phnum;
    const phdrs = (@intToPtr([*]elf.Phdr, elf_base + ehdr.e_phoff))[0..n_phdr];

    var it = dl.linkmap_iterator(phdrs) catch unreachable;

    // The executable has no dynamic link segment, create a single entry for
    // the whole ELF image
    if (it.end()) {
        var info = dl_phdr_info{
            .dlpi_addr = elf_base,
            .dlpi_name = c"/proc/self/exe",
            .dlpi_phdr = phdrs.ptr,
            .dlpi_phnum = ehdr.e_phnum,
        };

        return callback(&info, @sizeOf(dl_phdr_info), data);
    }

    // Last return value from the callback function
    var last_r: isize = 0;
    while (it.next()) |entry| {
        var dlpi_phdr: [*]elf.Phdr = undefined;
        var dlpi_phnum: u16 = undefined;

        if (entry.l_addr != 0) {
            const elf_header = @intToPtr(*elf.Ehdr, entry.l_addr);
            dlpi_phdr = @intToPtr([*]elf.Phdr, entry.l_addr + elf_header.e_phoff);
            dlpi_phnum = elf_header.e_phnum;
        } else {
            // This is the running ELF image
            dlpi_phdr = @intToPtr([*]elf.Phdr, elf_base + ehdr.e_phoff);
            dlpi_phnum = ehdr.e_phnum;
        }

        var info = dl_phdr_info{
            .dlpi_addr = entry.l_addr,
            .dlpi_name = entry.l_name,
            .dlpi_phdr = dlpi_phdr,
            .dlpi_phnum = dlpi_phnum,
        };

        last_r = callback(&info, @sizeOf(dl_phdr_info), data);
        if (last_r != 0) break;
    }

    return last_r;
}

pub const ClockGetTimeError = error{
    UnsupportedClock,
    Unexpected,
};

pub fn clock_gettime(clk_id: i32, tp: *timespec) ClockGetTimeError!void {
    switch (errno(system.clock_gettime(clk_id, tp))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn clock_getres(clk_id: i32, res: *timespec) ClockGetTimeError!void {
    switch (errno(system.clock_getres(clk_id, res))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SchedGetAffinityError = error{
    PermissionDenied,
    Unexpected,
};

pub fn sched_getaffinity(pid: pid_t) SchedGetAffinityError!cpu_set_t {
    var set: cpu_set_t = undefined;
    switch (errno(system.sched_getaffinity(pid, @sizeOf(cpu_set_t), &set))) {
        0 => return set,
        EFAULT => unreachable,
        EINVAL => unreachable,
        ESRCH => unreachable,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

/// Used to convert a slice to a null terminated slice on the stack.
/// TODO https://github.com/ziglang/zig/issues/287
pub fn toPosixPath(file_path: []const u8) ![PATH_MAX]u8 {
    var path_with_null: [PATH_MAX]u8 = undefined;
    // >= rather than > to make room for the null byte
    if (file_path.len >= PATH_MAX) return error.NameTooLong;
    mem.copy(u8, &path_with_null, file_path);
    path_with_null[file_path.len] = 0;
    return path_with_null;
}

/// Whether or not error.Unexpected will print its value and a stack trace.
/// if this happens the fix is to add the error code to the corresponding
/// switch expression, possibly introduce a new error in the error set, and
/// send a patch to Zig.
pub const unexpected_error_tracing = builtin.mode == .Debug;

pub const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    /// This error is in theory not possible, but it would be better
    /// to handle this error than to invoke undefined behavior.
    Unexpected,
};

/// Call this when you made a syscall or something that sets errno
/// and you get an unexpected error.
pub fn unexpectedErrno(err: usize) UnexpectedError {
    if (unexpected_error_tracing) {
        std.debug.warn("unexpected errno: {}\n", err);
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

pub const SigaltstackError = error{
    /// The supplied stack size was less than MINSIGSTKSZ.
    SizeTooSmall,

    /// Attempted to change the signal stack while it was active.
    PermissionDenied,
    Unexpected,
};

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) SigaltstackError!void {
    if (windows.is_the_target or uefi.is_the_target or wasi.is_the_target)
        @compileError("std.os.sigaltstack not available for this target");

    switch (errno(system.sigaltstack(ss, old_ss))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => unreachable,
        ENOMEM => return error.SizeTooSmall,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

/// Examine and change a signal action.
pub fn sigaction(sig: u6, act: *const Sigaction, oact: ?*Sigaction) void {
    switch (errno(system.sigaction(sig, act, oact))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => unreachable,
        else => unreachable,
    }
}

test "" {
    _ = @import("os/darwin.zig");
    _ = @import("os/freebsd.zig");
    _ = @import("os/linux.zig");
    _ = @import("os/netbsd.zig");
    _ = @import("os/uefi.zig");
    _ = @import("os/wasi.zig");
    _ = @import("os/windows.zig");
    _ = @import("os/zen.zig");

    _ = @import("os/test.zig");
}
