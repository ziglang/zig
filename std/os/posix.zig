// This is the "Zig-flavored POSIX" API layer.
// The purpose is not to match POSIX as closely as possible. Instead,
// the goal is to provide a very specific layer of abstraction:
// * Implement the POSIX functions, types, and definitions where possible,
//   using lower-level target-specific API. For example, on Linux `rename` might call
//   SYS_renameat or SYS_rename depending on the architecture.
// * When null-terminated byte buffers are required, provide APIs which accept
//   slices as well as APIs which accept null-terminated byte buffers. Same goes
//   for UTF-16LE encoding.
// * Convert "errno"-style error codes into Zig errors.
// * Work around kernel bugs and limitations. For example, if a function accepts
//   a `usize` number of bytes to write, but the kernel can only handle maxInt(u32)
//   number of bytes, this API layer should introduce a loop to make multiple
//   syscalls so that the full `usize` number of bytes are written.
// * Implement the OS-specific functions, types, and definitions that the Zig
//   standard library needs, at the same API abstraction layer as outlined above.
//   this includes, for example Windows functions.
// * When there exists a corresponding libc function and linking libc, call the
//   libc function.
// Note: The Zig standard library does not support POSIX thread cancellation, and
// in general EINTR is handled by trying again.

const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const os = @import("../os.zig");
const system = os.system;
const mem = std.mem;
const BufMap = std.BufMap;
const Allocator = mem.Allocator;
const windows = os.windows;
const wasi = os.wasi;
const linux = os.linux;
const testing = std.testing;

pub const FileHandle = if (windows.is_the_target) windows.HANDLE else if (wasi.is_the_target) wasi.fd_t else i32;
pub use system.errno_codes;

pub const PATH_MAX = system.PATH_MAX;

/// > The maximum path of 32,767 characters is approximate, because the "\\?\"
/// > prefix may be expanded to a longer string by the system at run time, and
/// > this expansion applies to the total length.
/// from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
pub const PATH_MAX_WIDE = 32767;

pub const iovec = system.iovec;
pub const iovec_const = system.iovec_const;

/// See also `getenv`.
pub var environ: [][*]u8 = undefined;

/// To obtain errno, call this function with the return value of the
/// system function call. For some systems this will obtain the value directly
/// from the return code; for others it will use a thread-local errno variable.
/// Therefore, this function only returns a well-defined value when it is called
/// directly after the system function call which one wants to learn the errno
/// value of.
pub const errno = system.getErrno;

/// Closes the file handle.
/// This function is not capable of returning any indication of failure. An
/// application which wants to ensure writes have succeeded before closing
/// must call `fsync` before `close`.
/// Note: The Zig standard library does not support POSIX thread cancellation.
pub fn close(handle: FileHandle) void {
    if (windows.is_the_target and !builtin.link_libc) {
        assert(windows.CloseHandle(handle) != 0);
        return;
    }
    if (wasi.is_the_target) {
        switch (wasi.fd_close(handle)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }
    switch (system.getErrno(system.close(handle))) {
        EBADF => unreachable, // Always a race condition.
        EINTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}

pub const GetRandomError = error{};

/// Obtain a series of random bytes. These bytes can be used to seed user-space
/// random number generators or for cryptographic purposes.
/// When linking against libc, this calls the
/// appropriate OS-specific library call. Otherwise it uses the zig standard
/// library implementation.
pub fn getrandom(buf: []u8) GetRandomError!void {
    if (windows.is_the_target) {
        // Call RtlGenRandom() instead of CryptGetRandom() on Windows
        // https://github.com/rust-lang-nursery/rand/issues/111
        // https://bugzilla.mozilla.org/show_bug.cgi?id=504270
        if (windows.RtlGenRandom(buf.ptr, buf.len) == 0) {
            const err = windows.GetLastError();
            return switch (err) {
                else => unexpectedErrorWindows(err),
            };
        }
        return;
    }
    if (linux.is_the_target) {
        while (true) {
            switch (system.getErrno(system.getrandom(buf.ptr, buf.len, 0))) {
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
        switch (os.wasi.random_get(buf.ptr, buf.len)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }
    return getRandomBytesDevURandom(buf);
}

fn getRandomBytesDevURandom(buf: []u8) !void {
    const fd = try openC(c"/dev/urandom", O_RDONLY | O_CLOEXEC, 0);
    defer close(fd);

    const stream = &os.File.openHandle(fd).inStream().stream;
    stream.readNoEof(buf) catch return error.Unexpected;
}

test "os.getRandomBytes" {
    var buf_a: [50]u8 = undefined;
    var buf_b: [50]u8 = undefined;
    try getRandomBytes(&buf_a);
    try getRandomBytes(&buf_b);
    // If this test fails the chance is significantly higher that there is a bug than
    // that two sets of 50 bytes were equal.
    testing.expect(!mem.eql(u8, buf_a, buf_b));
}

/// Causes abnormal process termination.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it raises SIGABRT followed by SIGKILL and finally lo
pub fn abort() noreturn {
    @setCold(true);
    if (builtin.link_libc) {
        c.abort();
    }
    if (windows.is_the_target) {
        if (builtin.mode == .Debug) {
            @breakpoint();
        }
        windows.ExitProcess(3);
    }
    if (builtin.os == .uefi) {
        // TODO there must be a better thing to do here than loop forever
        while (true) {}
    }

    raise(SIGABRT);

    // TODO the rest of the implementation of abort() from musl libc here

    raise(SIGKILL);
    exit(127);
}

pub const RaiseError = error{};

pub fn raise(sig: u8) RaiseError!void {
    if (builtin.link_libc) {
        switch (system.getErrno(system.raise(sig))) {
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

    if (windows.is_the_target) {
        @compileError("TODO implement std.posix.raise for Windows");
    }

    var set: system.sigset_t = undefined;
    system.blockAppSignals(&set);
    const tid = system.syscall0(system.SYS_gettid);
    const rc = system.syscall2(system.SYS_tkill, tid, sig);
    system.restoreSignals(&set);
    switch (system.getErrno(rc)) {
        0 => return,
        else => |err| return unexpectedErrno(err),
    }
}

/// Exits the program cleanly with the specified status code.
pub fn exit(status: u8) noreturn {
    if (builtin.link_libc) {
        std.c.exit(status);
    }
    if (windows.is_the_target) {
        windows.ExitProcess(status);
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
pub fn read(fd: FileHandle, buf: []u8) ReadError!usize {
    if (windows.is_the_target and !builtin.link_libc) {
        var index: usize = 0;
        while (index < buffer.len) {
            const want_read_count = @intCast(windows.DWORD, math.min(windows.DWORD(math.maxInt(windows.DWORD)), buffer.len - index));
            var amt_read: windows.DWORD = undefined;
            if (windows.ReadFile(fd, buffer.ptr + index, want_read_count, &amt_read, null) == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    windows.ERROR.OPERATION_ABORTED => continue,
                    windows.ERROR.BROKEN_PIPE => return index,
                    else => unexpectedErrorWindows(err),
                };
            }
            if (amt_read == 0) return index;
            index += amt_read;
        }
        return index;
    }

    if (wasi.is_the_target and !builtin.link_libc) {
        const iovs = [1]was.iovec_t{wasi.iovec_t{
            .buf = buf.ptr,
            .buf_len = buf.len,
        }};

        var nread: usize = undefined;
        switch (fd_read(fd, &iovs, iovs.len, &nread)) {
            0 => return nread,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Linux can return EINVAL when read amount is > 0x7ffff000
    // See https://github.com/ziglang/zig/pull/743#issuecomment-363158274
    const max_buf_len = 0x7ffff000;

    var index: usize = 0;
    while (index < buf.len) {
        const want_to_read = math.min(buf.len - index, usize(max_buf_len));
        const rc = system.read(fd, buf.ptr + index, want_to_read);
        switch (system.getErrno(rc)) {
            0 => {
                index += rc;
                if (rc == want_to_read) continue;
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
pub fn preadv(fd: FileHandle, iov: [*]const iovec, count: usize, offset: u64) ReadError!usize {
    if (os.darwin.is_the_target) {
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
                    off += rc;
                    inner_off += rc;
                    if (inner_off == v.iov_len) {
                        iov_i += 1;
                        inner_off = 0;
                        if (iov_i == count) {
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
        const rc = system.preadv(fd, iov, count, offset);
        const err = system.getErrno(rc);
        switch (err) {
            0 => return rc,
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
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
pub fn write(fd: FileHandle, bytes: []const u8) WriteError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        var bytes_written: windows.DWORD = undefined;
        // TODO replace this @intCast with a loop that writes all the bytes
        if (windows.WriteFile(handle, bytes.ptr, @intCast(u32, bytes.len), &bytes_written, null) == 0) {
            switch (windows.GetLastError()) {
                windows.ERROR.INVALID_USER_BUFFER => return error.SystemResources,
                windows.ERROR.NOT_ENOUGH_MEMORY => return error.SystemResources,
                windows.ERROR.OPERATION_ABORTED => return error.OperationAborted,
                windows.ERROR.NOT_ENOUGH_QUOTA => return error.SystemResources,
                windows.ERROR.IO_PENDING => unreachable,
                windows.ERROR.BROKEN_PIPE => return error.BrokenPipe,
                else => |err| return unexpectedErrorWindows(err),
            }
        }
    }

    if (wasi.is_the_target and !builtin.link_libc) {
        const ciovs = [1]wasi.ciovec_t{wasi.ciovec_t{
            .buf = bytes.ptr,
            .buf_len = bytes.len,
        }};
        var nwritten: usize = undefined;
        switch (fd_write(fd, &ciovs, ciovs.len, &nwritten)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Linux can return EINVAL when write amount is > 0x7ffff000
    // See https://github.com/ziglang/zig/pull/743#issuecomment-363165856
    const max_bytes_len = 0x7ffff000;

    var index: usize = 0;
    while (index < bytes.len) {
        const amt_to_write = math.min(bytes.len - index, usize(max_bytes_len));
        const rc = system.write(fd, bytes.ptr + index, amt_to_write);
        const write_err = system.getErrno(rc);
        switch (write_err) {
            0 => {
                index += rc;
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
            else => return unexpectedErrno(write_err),
        }
    }
}

/// Write multiple buffers to a file descriptor. Keeps trying if it gets interrupted.
/// This function is for blocking file descriptors only. For non-blocking, see
/// `pwritevAsync`.
pub fn pwritev(fd: FileHandle, iov: [*]const iovec_const, count: usize, offset: u64) WriteError!void {
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
                    off += rc;
                    inner_off += rc;
                    if (inner_off == v.iov_len) {
                        iov_i += 1;
                        inner_off = 0;
                        if (iov_i == count) {
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
        const rc = system.pwritev(fd, iov, count, offset);
        const err = system.getErrno(rc);
        switch (err) {
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
            else => return unexpectedErrno(err),
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
pub fn open(file_path: []const u8, flags: u32, perm: usize) OpenError!FileHandle {
    const file_path_c = try toPosixPath(file_path);
    return openC(&file_path_c, flags, perm);
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// See also `open`.
/// TODO https://github.com/ziglang/zig/issues/265
pub fn openC(file_path: [*]const u8, flags: u32, perm: usize) OpenError!FileHandle {
    while (true) {
        const rc = system.open(file_path, flags, perm);
        switch (system.getErrno(rc)) {
            0 => return @intCast(FileHandle, rc),
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

pub const WindowsOpenError = error{
    SharingViolation,
    PathAlreadyExists,

    /// When any of the path components can not be found or the file component can not
    /// be found. Some operating systems distinguish between path components not found and
    /// file components not found, but they are collapsed into FileNotFound to gain
    /// consistency across operating systems.
    FileNotFound,

    AccessDenied,
    PipeBusy,
    NameTooLong,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    Unexpected,
};

pub fn openWindows(
    file_path: []const u8,
    desired_access: windows.DWORD,
    share_mode: windows.DWORD,
    creation_disposition: windows.DWORD,
    flags_and_attrs: windows.DWORD,
) WindowsOpenError!FileHandle {
    const file_path_w = try sliceToPrefixedFileW(file_path);
    return openW(&file_path_w, desired_access, share_mode, creation_disposition, flags_and_attrs);
}

pub fn openW(
    file_path_w: [*]const u16,
    desired_access: windows.DWORD,
    share_mode: windows.DWORD,
    creation_disposition: windows.DWORD,
    flags_and_attrs: windows.DWORD,
) WindowsOpenError!windows.HANDLE {
    const result = windows.CreateFileW(file_path_w, desired_access, share_mode, null, creation_disposition, flags_and_attrs, null);

    if (result == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.SHARING_VIOLATION => return error.SharingViolation,
            windows.ERROR.ALREADY_EXISTS => return error.PathAlreadyExists,
            windows.ERROR.FILE_EXISTS => return error.PathAlreadyExists,
            windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.ACCESS_DENIED => return error.AccessDenied,
            windows.ERROR.PIPE_BUSY => return error.PipeBusy,
            else => return unexpectedErrorWindows(err),
        }
    }

    return result;
}

pub fn dup2(old_fd: FileHandle, new_fd: FileHandle) !void {
    while (true) {
        switch (system.getErrno(system.dup2(old_fd, new_fd))) {
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
pub fn execve(allocator: *Allocator, argv: []const []const u8, env_map: *const BufMap) !void {
    const argv_buf = try allocator.alloc(?[*]u8, argv.len + 1);
    mem.set(?[*]u8, argv_buf, null);
    defer {
        for (argv_buf) |arg| {
            const arg_buf = if (arg) |ptr| cstr.toSlice(ptr) else break;
            allocator.free(arg_buf);
        }
        allocator.free(argv_buf);
    }
    for (argv) |arg, i| {
        const arg_buf = try allocator.alloc(u8, arg.len + 1);
        @memcpy(arg_buf.ptr, arg.ptr, arg.len);
        arg_buf[arg.len] = 0;

        argv_buf[i] = arg_buf.ptr;
    }
    argv_buf[argv.len] = null;

    const envp_buf = try createNullDelimitedEnvMap(allocator, env_map);
    defer freeNullDelimitedEnvMap(allocator, envp_buf);

    const exe_path = argv[0];
    if (mem.indexOfScalar(u8, exe_path, '/') != null) {
        return execveErrnoToErr(system.getErrno(system.execve(argv_buf[0].?, argv_buf.ptr, envp_buf.ptr)));
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
        err = system.getErrno(system.execve(path_buf.ptr, argv_buf.ptr, envp_buf.ptr));
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

pub fn createNullDelimitedEnvMap(allocator: *Allocator, env_map: *const BufMap) ![]?[*]u8 {
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

pub fn freeNullDelimitedEnvMap(allocator: *Allocator, envp_buf: []?[*]u8) void {
    for (envp_buf) |env| {
        const env_buf = if (env) |ptr| ptr[0 .. cstr.len(ptr) + 1] else break;
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
        const value = std.c.getenv(key) orelse return null;
        return mem.toSliceConst(u8, value);
    }
    return getenv(mem.toSliceConst(u8, key));
}

/// See std.elf for the constants.
pub fn getauxval(index: usize) usize {
    if (builtin.link_libc) {
        return usize(std.c.getauxval(index));
    } else if (linux.elf_aux_maybe) |auxv| {
        var i: usize = 0;
        while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
            if (auxv[i].a_type == index)
                return auxv[i].a_un.a_val;
        }
    }
    return 0;
}

pub const GetCwdError = error{
    NameTooLong,
    CurrentWorkingDirectoryUnlinked,
    Unexpected,
};

/// The result is a slice of out_buffer, indexed from 0.
pub fn getcwd(out_buffer: []u8) GetCwdError![]u8 {
    if (windows.is_the_target and !builtin.link_libc) {
        var utf16le_buf: [windows_util.PATH_MAX_WIDE]u16 = undefined;
        const casted_len = @intCast(windows.DWORD, utf16le_buf.len); // TODO shouldn't need this cast
        const casted_ptr = ([*]u16)(&utf16le_buf); // TODO shouldn't need this cast
        const result = windows.GetCurrentDirectoryW(casted_len, casted_ptr);
        if (result == 0) {
            const err = windows.GetLastError();
            switch (err) {
                else => return unexpectedErrorWindows(err),
            }
        }
        assert(result <= utf16le_buf.len);
        const utf16le_slice = utf16le_buf[0..result];
        // Trust that Windows gives us valid UTF-16LE.
        var end_index: usize = 0;
        var it = std.unicode.Utf16LeIterator.init(utf16le);
        while (it.nextCodepoint() catch unreachable) |codepoint| {
            if (end_index + std.unicode.utf8CodepointSequenceLength(codepoint) >= out_buffer.len)
                return error.NameTooLong;
            end_index += utf8Encode(codepoint, out_buffer[end_index..]) catch unreachable;
        }
        return out_buffer[0..end_index];
    }

    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.getcwd(out_buffer.ptr, out_buffer.len)) |_| 0 else std.c._errno().*;
    } else blk: {
        break :blk system.getErrno(system.getcwd(out_buffer, out_buffer.len));
    };
    switch (err) {
        0 => return mem.toSlice(u8, out_buffer),
        EFAULT => unreachable,
        EINVAL => unreachable,
        ENOENT => return error.CurrentWorkingDirectoryUnlinked,
        ERANGE => return error.NameTooLong,
        else => |err| return unexpectedErrno(err),
    }
}

test "getcwd" {
    // at least call it so it gets compiled
    var buf: [os.MAX_PATH_BYTES]u8 = undefined;
    _ = getcwd(&buf) catch {};
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

/// Creates a symbolic link named `new_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `new_path` exists, it will not be overwritten.
/// See also `symlinkC` and `symlinkW`.
pub fn symlink(target_path: []const u8, new_path: []const u8) SymLinkError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const target_path_w = try cStrToPrefixedFileW(target_path);
        const new_path_w = try cStrToPrefixedFileW(new_path);
        return symlinkW(&target_path_w, &new_path_w);
    } else {
        const target_path_c = try toPosixPath(target_path);
        const new_path_c = try toPosixPath(new_path);
        return symlinkC(&target_path_c, &new_path_c);
    }
}

pub fn symlinkat(target_path: []const u8, newdirfd: FileHandle, new_path: []const u8) SymLinkError!void {
    const target_path_c = try toPosixPath(target_path);
    const new_path_c = try toPosixPath(new_path);
    return symlinkatC(target_path_c, newdirfd, new_path_c);
}

pub fn symlinkatC(target_path: [*]const u8, newdirfd: FileHandle, new_path: [*]const u8) SymLinkError!void {
    const err = blk: {
        if (builtin.link_libc) {
            break :blk if (std.c.symlinkat(target_path, newdirfd, new_path) == -1) errno().* else 0;
        } else {
            break :blk system.getErrno(system.symlinkat(target_path, newdirfd, new_path));
        }
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

/// This is the same as `symlink` except the parameters are null-terminated pointers.
/// See also `symlink` and `symlinkW`.
pub fn symlinkC(target_path: [*]const u8, new_path: [*]const u8) SymLinkError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const target_path_w = try cStrToPrefixedFileW(target_path);
        const new_path_w = try cStrToPrefixedFileW(new_path);
        return symlinkW(&target_path_w, &new_path_w);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.symlink(target_path, new_path) == -1) errno().* else 0;
    } else if (@hasDecl(system, "symlink")) blk: {
        break :blk system.getErrno(system.symlink(target_path, new_path));
    } else blk: {
        break :blk system.getErrno(system.symlinkat(target_path, AT_FDCWD, new_path));
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

/// This is the same as `symlink` except the parameters are null-terminated pointers to
/// UTF-16LE encoded strings.
/// See also `symlink` and `symlinkC`.
/// TODO handle when linking libc
pub fn symlinkW(target_path_w: [*]const u16, new_path_w: [*]const u16) SymLinkError!void {
    if (windows.CreateSymbolicLinkW(target_path_w, new_path_w, 0) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return unexpectedErrorWindows(err),
        }
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
pub fn unlink(file_path: []const u8) UnlinkError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const file_path_w = try sliceToPrefixedFileW(file_path);
        return unlinkW(&file_path_w);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return unlinkC(&file_path_c);
    }
}

/// Same as `unlink` except the parameter is a UTF16LE-encoded string.
/// TODO handle when linking libc
pub fn unlinkW(file_path: [*]const u16) UnlinkError!void {
    if (windows.unlinkW(file_path) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.ACCESS_DENIED => return error.AccessDenied,
            windows.ERROR.FILENAME_EXCED_RANGE => return error.NameTooLong,
            windows.ERROR.INVALID_PARAMETER => return error.NameTooLong,
            else => return unexpectedErrorWindows(err),
        }
    }
}

/// Same as `unlink` except the parameter is a null terminated UTF8-encoded string.
pub fn unlinkC(file_path: [*]const u8) UnlinkError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const file_path_w = try cStrToPrefixedFileW(file_path);
        return unlinkW(&file_path_w);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.unlink(file_path) == -1) errno().* else 0;
    } else if (@hasDecl(system, "unlink")) blk: {
        break :blk system.getErrno(system.unlink(file_path));
    } else blk: {
        break :blk system.getErrno(system.unlinkat(AT_FDCWD, file_path, 0));
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

const RenameError = error{}; // TODO

/// Change the name or location of a file.
pub fn rename(old_path: []const u8, new_path: []const u8) RenameError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const old_path_w = try sliceToPrefixedFileW(old_path);
        const new_path_w = try sliceToPrefixedFileW(new_path);
        return renameW(&old_path_w, &new_path_w);
    } else {
        const old_path_c = try toPosixPath(old_path);
        const new_path_c = try toPosixPath(new_path);
        return renameC(&old_path_c, &new_path_c);
    }
}

/// Same as `rename` except the parameters are null-terminated byte arrays.
pub fn renameC(old_path: [*]const u8, new_path: [*]const u8) RenameError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const old_path_w = try cStrToPrefixedFileW(old_path);
        const new_path_w = try cStrToPrefixedFileW(new_path);
        return renameW(&old_path_w, &new_path_w);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.rename(old_path, new_path) == -1) errno().* else 0;
    } else if (@hasDecl(system, "rename")) blk: {
        break :blk system.getErrno(system.rename(old_path, new_path));
    } else if (@hasDecl(system, "renameat")) blk: {
        break :blk system.getErrno(system.renameat(AT_FDCWD, old_path, AT_FDCWD, new_path));
    } else blk: {
        break :blk system.getErrno(system.renameat2(AT_FDCWD, old_path, AT_FDCWD, new_path, 0));
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

/// Same as `rename` except the parameters are null-terminated UTF16LE-encoded strings.
/// TODO handle when linking libc
pub fn renameW(old_path: [*]const u16, new_path: [*]const u16) RenameError!void {
    const flags = windows.MOVEFILE_REPLACE_EXISTING | windows.MOVEFILE_WRITE_THROUGH;
    if (windows.MoveFileExW(old_path, new_path, flags) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return unexpectedErrorWindows(err),
        }
    }
}

pub const MakeDirError = error{};

/// Create a directory.
/// `mode` is ignored on Windows.
pub fn mkdir(dir_path: []const u8, mode: u32) MakeDirError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try sliceToPrefixedFileW(dir_path);
        return mkdirW(&dir_path_w, mode);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return mkdirC(&dir_path_c, mode);
    }
}

/// Same as `mkdir` but the parameter is a null-terminated UTF8-encoded string.
pub fn mkdirC(dir_path: [*]const u8, mode: u32) MakeDirError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try cStrToPrefixedFileW(dir_path);
        return mkdirW(&dir_path_w, mode);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.mkdir(dir_path, mode) == -1) errno().* else 0;
    } else if (@hasDecl(system, "mkdir")) blk: {
        break :blk system.getErrno(system.mkdir(dir_path, mode));
    } else blk: {
        break :blk system.getErrno(system.mkdirat(AT_FDCWD, dir_path, mode));
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

/// Same as `mkdir` but the parameter is a null-terminated UTF16LE-encoded string.
pub fn mkdirW(dir_path: []const u8, mode: u32) MakeDirError!void {
    const dir_path_w = try sliceToPrefixedFileW(dir_path);

    if (windows.CreateDirectoryW(&dir_path_w, null) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.ALREADY_EXISTS => return error.PathAlreadyExists,
            windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            else => return unexpectedErrorWindows(err),
        }
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
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try sliceToPrefixedFileW(dir_path);
        return rmdirW(&dir_path_w);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return rmdirC(&dir_path_c);
    }
}

/// Same as `rmdir` except the parameter is a null-terminated UTF8-encoded string.
pub fn rmdirC(dir_path: [*]const u8) DeleteDirError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try cStrToPrefixedFileW(dir_path);
        return rmdirW(&dir_path_w);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.rmdir(dir_path) == -1) errno().* else 0;
    } else if (@hasDecl(system, "rmdir")) blk: {
        break :blk system.getErrno(system.rmdir(dir_path));
    } else blk: {
        break :blk system.getErrno(system.unlinkat(AT_FDCWD, dir_path, AT_REMOVEDIR));
    };
    switch (err) {
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
        else => return unexpectedErrno(err),
    }
}

/// Same as `rmdir` except the parameter is a null-terminated UTF16LE-encoded string.
/// TODO handle linking libc
pub fn rmdirW(dir_path_w: [*]const u16) DeleteDirError!void {
    if (windows.RemoveDirectoryW(dir_path_w) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.DIR_NOT_EMPTY => return error.DirNotEmpty,
            else => return unexpectedErrorWindows(err),
        }
    }
}

pub const ChangeCurDirError = error{};

/// Changes the current working directory of the calling process.
/// `dir_path` is recommended to be a UTF-8 encoded string.
pub fn chdir(dir_path: []const u8) ChangeCurDirError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try sliceToPrefixedFileW(dir_path);
        return chdirW(&dir_path_w);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return chdirC(&dir_path_c);
    }
}

/// Same as `chdir` except the parameter is null-terminated.
pub fn chdirC(dir_path: [*]const u8) ChangeCurDirError!void {
    if (windows.is_the_target and !builtin.link_libc) {
        const dir_path_w = try cStrToPrefixedFileW(dir_path);
        return chdirW(&dir_path_w);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.chdir(dir_path) == -1) errno().* else 0;
    } else blk: {
        break :blk system.getErrno(system.chdir(dir_path));
    };
    switch (err) {
        0 => return,
        EACCES => return error.AccessDenied,
        EFAULT => unreachable,
        EIO => return error.FileSystem,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOMEM => return error.SystemResources,
        ENOTDIR => return error.NotDir,
        else => return unexpectedErrno(err),
    }
}

/// Same as `chdir` except the parameter is a null-terminated, UTF16LE-encoded string.
/// TODO handle linking libc
pub fn chdirW(dir_path: [*]const u16) ChangeCurDirError!void {
    @compileError("TODO implement chdir for Windows");
}

pub const ReadLinkError = error{};

/// Read value of a symbolic link.
/// The return value is a slice of `out_buffer` from index 0.
pub fn readlink(file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (windows.is_the_target and !builtin.link_libc) {
        const file_path_w = try sliceToPrefixedFileW(file_path);
        return readlinkW(&file_path_w, out_buffer);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return readlinkC(&file_path_c, out_buffer);
    }
}

/// Same as `readlink` except `file_path` is null-terminated.
pub fn readlinkC(file_path: [*]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (windows.is_the_target and !builtin.link_libc) {
        const file_path_w = try cStrToPrefixedFileW(file_path);
        return readlinkW(&file_path_w, out_buffer);
    }
    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.readlink(file_path, out_buffer.ptr, out_buffer.len) == -1) errno().* else 0;
    } else if (@hasDecl(system, "readlink")) blk: {
        break :blk system.getErrno(system.readlink(file_path, out_buffer.ptr, out_buffer.len));
    } else blk: {
        break :blk system.getErrno(system.readlinkat(AT_FDCWD, file_path, out_buffer.ptr, out_buffer.len));
    };
    const rc = system.readlink(file_path, out_buffer, out_buffer.len);
    switch (system.getErrno(rc)) {
        0 => return out_buffer[0..rc],
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
    switch (system.getErrno(system.setuid(uid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setreuid(ruid: u32, euid: u32) SetIdError!void {
    switch (system.getErrno(system.setreuid(ruid, euid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setgid(gid: u32) SetIdError!void {
    switch (system.getErrno(system.setgid(gid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setregid(rgid: u32, egid: u32) SetIdError!void {
    switch (system.getErrno(system.setregid(rgid, egid))) {
        0 => return,
        EAGAIN => return error.ResourceLimitReached,
        EINVAL => return error.InvalidUserId,
        EPERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const GetStdHandleError = error{
    NoStandardHandleAttached,
    Unexpected,
};

pub fn GetStdHandle(handle_id: windows.DWORD) GetStdHandleError!FileHandle {
    if (windows.is_the_target) {
        const handle = windows.GetStdHandle(handle_id) orelse return error.NoStandardHandleAttached;
        if (handle == windows.INVALID_HANDLE_VALUE) {
            switch (windows.GetLastError()) {
                else => |err| unexpectedErrorWindows(err),
            }
        }
        return handle;
    }

    switch (handle_id) {
        windows.STD_ERROR_HANDLE => return STDERR_FILENO,
        windows.STD_OUTPUT_HANDLE => return STDOUT_FILENO,
        windows.STD_INPUT_HANDLE => return STDIN_FILENO,
        else => unreachable,
    }
}

/// Test whether a file descriptor refers to a terminal.
pub fn isatty(handle: FileHandle) bool {
    if (builtin.link_libc) {
        return c.isatty(handle) != 0;
    }
    if (windows.is_the_target) {
        if (isCygwinPty(handle))
            return true;

        var out: windows.DWORD = undefined;
        return windows.GetConsoleMode(handle, &out) != 0;
    }
    if (wasi.is_the_target) {
        @compileError("TODO implement std.os.posix.isatty for WASI");
    }

    var wsz: system.winsize = undefined;
    return system.syscall3(system.SYS_ioctl, @bitCast(usize, isize(handle)), TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
}

pub fn isCygwinPty(handle: FileHandle) bool {
    if (!windows.is_the_target) return false;

    const size = @sizeOf(windows.FILE_NAME_INFO);
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = []u8{0} ** (size + windows.MAX_PATH);

    if (windows.GetFileInformationByHandleEx(
        handle,
        windows.FileNameInfo,
        @ptrCast(*c_void, &name_info_bytes[0]),
        @intCast(u32, name_info_bytes.len),
    ) == 0) {
        return false;
    }

    const name_info = @ptrCast(*const windows.FILE_NAME_INFO, &name_info_bytes[0]);
    const name_bytes = name_info_bytes[size .. size + usize(name_info.FileNameLength)];
    const name_wide = @bytesToSlice(u16, name_bytes);
    return mem.indexOf(u16, name_wide, []u16{ 'm', 's', 'y', 's', '-' }) != null or
        mem.indexOf(u16, name_wide, []u16{ '-', 'p', 't', 'y' }) != null;
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
    switch (system.getErrno(rc)) {
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
    const rc = system.bind(fd, system, @sizeOf(sockaddr));
    switch (system.getErrno(rc)) {
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
    switch (system.getErrno(rc)) {
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
        switch (system.getErrno(rc)) {
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
        switch (system.getErrno(rc)) {
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
    switch (system.getErrno(rc)) {
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

pub fn epoll_ctl(epfd: i32, op: u32, fd: i32, event: *epoll_event) EpollCtlError!void {
    const rc = system.epoll_ctl(epfd, op, fd, event);
    switch (system.getErrno(rc)) {
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
        switch (system.getErrno(rc)) {
            0 => return rc,
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
    switch (system.getErrno(rc)) {
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
    switch (system.getErrno(system.getsockname(sockfd, &addr, &addrlen))) {
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
pub fn connect(sockfd: i32, sockaddr: *const sockaddr) ConnectError!void {
    while (true) {
        switch (system.getErrno(system.connect(sockfd, sockaddr, @sizeOf(sockaddr)))) {
            0 => return,
            else => |err| return unexpectedErrno(err),

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
        }
    }
}

/// Same as `connect` except it is for blocking socket file descriptors.
/// It expects to receive EINPROGRESS`.
pub fn connect_async(sockfd: i32, sockaddr: *const c_void, len: u32) ConnectError!void {
    while (true) {
        switch (system.getErrno(system.connect(sockfd, sockaddr, len))) {
            0, EINPROGRESS => return,
            EINTR => continue,
            else => return unexpectedErrno(err),

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
        }
    }
}

pub fn getsockoptError(sockfd: i32) ConnectError!void {
    var err_code: i32 = undefined;
    var size: u32 = @sizeOf(i32);
    const rc = system.getsockopt(sockfd, SOL_SOCKET, SO_ERROR, @ptrCast([*]u8, &err_code), &size);
    assert(size == 4);
    switch (system.getErrno(rc)) {
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

pub fn wait(pid: i32) i32 {
    var status: i32 = undefined;
    while (true) {
        switch (system.getErrno(system.waitpid(pid, &status, 0))) {
            0 => return status,
            EINTR => continue,
            ECHILD => unreachable, // The process specified does not exist. It would be a race condition to handle this error.
            EINVAL => unreachable, // The options argument was invalid
            else => unreachable,
        }
    }
}

pub fn fstat(fd: FileHandle) !Stat {
    var stat: Stat = undefined;
    switch (system.getErrno(system.fstat(fd, &stat))) {
        0 => return stat,
        EBADF => unreachable, // Always a race condition.
        ENOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }

    return stat;
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
    switch (system.getErrno(rc)) {
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
};

pub fn kevent(
    kq: i32,
    changelist: []const Kevent,
    eventlist: []Kevent,
    timeout: ?*const timespec,
) KEventError!usize {
    while (true) {
        const rc = system.kevent(kq, changelist, eventlist, timeout);
        switch (system.getErrno(rc)) {
            0 => return rc,
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
    switch (system.getErrno(rc)) {
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
    switch (system.getErrno(rc)) {
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
    switch (system.getErrno(system.inotify_rm_watch(inotify_fd, wd))) {
        0 => return,
        EBADF => unreachable,
        EINVAL => unreachable,
        else => unreachable,
    }
}

pub const MProtectError = error{
    AccessDenied,
    OutOfMemory,
    Unexpected,
};

/// address and length must be page-aligned
pub fn mprotect(address: usize, length: usize, protection: u32) MProtectError!void {
    const negative_page_size = @bitCast(usize, -isize(page_size));
    const aligned_address = address & negative_page_size;
    const aligned_end = (address + length + page_size - 1) & negative_page_size;
    assert(address == aligned_address);
    assert(length == aligned_end - aligned_address);
    switch (system.getErrno(system.mprotect(address, length, protection))) {
        0 => return,
        EINVAL => unreachable,
        EACCES => return error.AccessDenied,
        ENOMEM => return error.OutOfMemory,
        else => return unexpectedErrno(err),
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

const unexpected_error_tracing = builtin.mode == .Debug;
const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    Unexpected,
};

/// Call this when you made a syscall or something that sets errno
/// and you get an unexpected error.
pub fn unexpectedErrno(errno: usize) UnexpectedError {
    if (unexpected_error_tracing) {
        std.debug.warn("unexpected errno: {}\n", errno);
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

/// Call this when you made a windows DLL call or something that does SetLastError
/// and you get an unexpected error.
pub fn unexpectedErrorWindows(err: windows.DWORD) UnexpectedError {
    if (unexpected_error_tracing) {
        std.debug.warn("unexpected GetLastError(): {}\n", err);
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

pub fn cStrToPrefixedFileW(s: [*]const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedFileW(mem.toSliceConst(u8, s));
}

pub fn sliceToPrefixedFileW(s: []const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedSuffixedFileW(s, []u16{0});
}

pub fn sliceToPrefixedSuffixedFileW(s: []const u8, comptime suffix: []const u16) ![PATH_MAX_WIDE + suffix.len]u16 {
    // TODO well defined copy elision
    var result: [PATH_MAX_WIDE + suffix.len]u16 = undefined;

    // > File I/O functions in the Windows API convert "/" to "\" as part of
    // > converting the name to an NT-style name, except when using the "\\?\"
    // > prefix as detailed in the following sections.
    // from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
    // Because we want the larger maximum path length for absolute paths, we
    // disallow forward slashes in zig std lib file functions on Windows.
    for (s) |byte| {
        switch (byte) {
            '/', '*', '?', '"', '<', '>', '|' => return error.BadPathName,
            else => {},
        }
    }
    const start_index = if (mem.startsWith(u8, s, "\\\\") or !os.path.isAbsolute(s)) 0 else blk: {
        const prefix = []u16{ '\\', '\\', '?', '\\' };
        mem.copy(u16, result[0..], prefix);
        break :blk prefix.len;
    };
    const end_index = start_index + try std.unicode.utf8ToUtf16Le(result[start_index..], s);
    assert(end_index <= result.len);
    if (end_index + suffix.len > result.len) return error.NameTooLong;
    mem.copy(u16, result[end_index..], suffix);
    return result;
}
