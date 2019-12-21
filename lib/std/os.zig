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

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const elf = std.elf;
const dl = @import("dynamic_library.zig");
const MAX_PATH_BYTES = std.fs.MAX_PATH_BYTES;

pub const darwin = @import("os/darwin.zig");
pub const dragonfly = @import("os/dragonfly.zig");
pub const freebsd = @import("os/freebsd.zig");
pub const netbsd = @import("os/netbsd.zig");
pub const linux = @import("os/linux.zig");
pub const uefi = @import("os/uefi.zig");
pub const wasi = @import("os/wasi.zig");
pub const windows = @import("os/windows.zig");

comptime {
    assert(@import("std") == std); // std lib tests require --override-lib-dir
}

test "" {
    _ = darwin;
    _ = freebsd;
    _ = linux;
    _ = netbsd;
    _ = uefi;
    _ = wasi;
    _ = windows;

    _ = @import("os/test.zig");
}

/// Applications can override the `system` API layer in their root source file.
/// Otherwise, when linking libc, this is the C API.
/// When not linking libc, it is the OS-specific system interface.
pub const system = if (@hasDecl(root, "os") and root.os != @This())
    root.os.system
else if (builtin.link_libc)
    std.c
else switch (builtin.os) {
    .macosx, .ios, .watchos, .tvos => darwin,
    .freebsd => freebsd,
    .linux => linux,
    .netbsd => netbsd,
    .dragonfly => dragonfly,
    .wasi => wasi,
    .windows => windows,
    else => struct {},
};

pub usingnamespace @import("os/bits.zig");

/// See also `getenv`. Populated by startup code before main().
pub var environ: [][*:0]u8 = undefined;

/// Populated by startup code before main().
/// Not available on Windows. See `std.process.args`
/// for obtaining the process arguments.
pub var argv: [][*:0]u8 = undefined;

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
    if (builtin.os == .windows) {
        return windows.CloseHandle(fd);
    }
    if (builtin.os == .wasi) {
        _ = wasi.fd_close(fd);
    }
    if (comptime std.Target.current.isDarwin()) {
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
pub fn getrandom(buffer: []u8) GetRandomError!void {
    if (builtin.os == .windows) {
        return windows.RtlGenRandom(buffer);
    }
    if (builtin.os == .linux or builtin.os == .freebsd) {
        var buf = buffer;
        const use_c = builtin.os != .linux or
            std.c.versionCheck(builtin.Version{ .major = 2, .minor = 25, .patch = 0 }).ok;

        while (buf.len != 0) {
            var err: u16 = undefined;

            const num_read = if (use_c) blk: {
                const rc = std.c.getrandom(buf.ptr, buf.len, 0);
                err = std.c.getErrno(rc);
                break :blk @bitCast(usize, rc);
            } else blk: {
                const rc = linux.getrandom(buf.ptr, buf.len, 0);
                err = linux.getErrno(rc);
                break :blk rc;
            };

            switch (err) {
                0 => buf = buf[num_read..],
                EINVAL => unreachable,
                EFAULT => unreachable,
                EINTR => continue,
                ENOSYS => return getRandomBytesDevURandom(buf),
                else => return unexpectedErrno(err),
            }
        }
        return;
    }
    if (builtin.os == .wasi) {
        switch (wasi.random_get(buffer.ptr, buffer.len)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }
    return getRandomBytesDevURandom(buffer);
}

fn getRandomBytesDevURandom(buf: []u8) !void {
    const fd = try openC("/dev/urandom", O_RDONLY | O_CLOEXEC, 0);
    defer close(fd);

    const st = try fstat(fd);
    if (!S_ISCHR(st.mode)) {
        return error.NoDevice;
    }

    const stream = &std.fs.File.openHandle(fd).inStream().stream;
    stream.readNoEof(buf) catch return error.Unexpected;
}

/// Causes abnormal process termination.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it raises SIGABRT followed by SIGKILL and finally lo
pub fn abort() noreturn {
    @setCold(true);
    // MSVCRT abort() sometimes opens a popup window which is undesirable, so
    // even when linking libc on Windows we use our own abort implementation.
    // See https://github.com/ziglang/zig/issues/2071 for more details.
    if (builtin.os == .windows) {
        if (builtin.mode == .Debug) {
            @breakpoint();
        }
        windows.kernel32.ExitProcess(3);
    }
    if (!builtin.link_libc and builtin.os == .linux) {
        raise(SIGABRT) catch {};

        // TODO the rest of the implementation of abort() from musl libc here

        raise(SIGKILL) catch {};
        exit(127);
    }
    if (builtin.os == .uefi) {
        exit(0); // TODO choose appropriate exit code
    }
    if (builtin.os == .wasi) {
        @breakpoint();
        exit(1);
    }

    system.abort();
}

pub const RaiseError = UnexpectedError;

pub fn raise(sig: u8) RaiseError!void {
    if (builtin.link_libc) {
        switch (errno(system.raise(sig))) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    if (builtin.os == .wasi) {
        switch (wasi.proc_raise(SIGABRT)) {
            0 => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    if (builtin.os == .linux) {
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

pub const KillError = error{PermissionDenied} || UnexpectedError;

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
    if (builtin.os == .windows) {
        windows.kernel32.ExitProcess(status);
    }
    if (builtin.os == .wasi) {
        wasi.proc_exit(status);
    }
    if (builtin.os == .linux and !builtin.single_threaded) {
        linux.exit_group(status);
    }
    if (builtin.os == .uefi) {
        // exit() is only avaliable if exitBootServices() has not been called yet.
        // This call to exit should not fail, so we don't care about its return value.
        if (uefi.system_table.boot_services) |bs| {
            _ = bs.exit(uefi.handle, status, 0, null);
        }
        // If we can't exit, reboot the system instead.
        uefi.system_table.runtime_services.resetSystem(uefi.tables.ResetType.ResetCold, status, 0, null);
    }
    system.exit(status);
}

pub const ReadError = error{
    InputOutput,
    SystemResources,
    IsDir,
    OperationAborted,
    BrokenPipe,
    ConnectionResetByPeer,

    /// This error occurs when no global event loop is configured,
    /// and reading from the file descriptor would block.
    WouldBlock,
} || UnexpectedError;

/// Returns the number of bytes that were read, which can be less than
/// buf.len. If 0 bytes were read, that means EOF.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
pub fn read(fd: fd_t, buf: []u8) ReadError!usize {
    if (builtin.os == .windows) {
        return windows.ReadFile(fd, buf);
    }

    if (builtin.os == .wasi and !builtin.link_libc) {
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

    while (true) {
        const rc = system.read(fd, buf.ptr, buf.len);
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
            EBADF => unreachable, // Always a race condition.
            EIO => return error.InputOutput,
            EISDIR => return error.IsDir,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            ECONNRESET => return error.ConnectionResetByPeer,
            else => |err| return unexpectedErrno(err),
        }
    }
    return index;
}

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
pub fn readv(fd: fd_t, iov: []const iovec) ReadError!usize {
    while (true) {
        // TODO handle the case when iov_len is too large and get rid of this @intCast
        const rc = system.readv(fd, iov.ptr, @intCast(u32, iov.len));
        switch (errno(rc)) {
            0 => return @bitCast(usize, rc),
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
            EBADF => unreachable, // always a race condition
            EIO => return error.InputOutput,
            EISDIR => return error.IsDir,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
pub fn preadv(fd: fd_t, iov: []const iovec, offset: u64) ReadError!usize {
    if (comptime std.Target.current.isDarwin()) {
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
                EAGAIN => if (std.event.Loop.instance) |loop| {
                    loop.waitUntilFdReadable(fd);
                    continue;
                } else {
                    return error.WouldBlock;
                },
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
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
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

    /// This error occurs when no global event loop is configured,
    /// and reading from the file descriptor would block.
    WouldBlock,
} || UnexpectedError;

/// Write to a file descriptor. Keeps trying if it gets interrupted.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
/// TODO evented I/O integration is disabled until
/// https://github.com/ziglang/zig/issues/3557 is solved.
pub fn write(fd: fd_t, bytes: []const u8) WriteError!void {
    if (builtin.os == .windows) {
        return windows.WriteFile(fd, bytes);
    }

    if (builtin.os == .wasi and !builtin.link_libc) {
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
        const amt_to_write = math.min(bytes.len - index, @as(usize, max_bytes_len));
        const rc = system.write(fd, bytes.ptr + index, amt_to_write);
        switch (errno(rc)) {
            0 => {
                index += @intCast(usize, rc);
                continue;
            },
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            // TODO https://github.com/ziglang/zig/issues/3557
            EAGAIN => return error.WouldBlock,
            //EAGAIN => if (std.event.Loop.instance) |loop| {
            //    loop.waitUntilFdWritable(fd);
            //    continue;
            //} else {
            //    return error.WouldBlock;
            //},
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

/// Write multiple buffers to a file descriptor.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
pub fn writev(fd: fd_t, iov: []const iovec_const) WriteError!void {
    while (true) {
        // TODO handle the case when iov_len is too large and get rid of this @intCast
        const rc = system.writev(fd, iov.ptr, @intCast(u32, iov.len));
        switch (errno(rc)) {
            0 => return,
            EINTR => continue,
            EINVAL => unreachable,
            EFAULT => unreachable,
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdWritable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
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

/// Write multiple buffers to a file descriptor, with a position offset.
/// Keeps trying if it gets interrupted.
pub fn pwritev(fd: fd_t, iov: []const iovec_const, offset: u64) WriteError!void {
    if (comptime std.Target.current.isDarwin()) {
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
                EAGAIN => if (std.event.Loop.instance) |loop| {
                    loop.waitUntilFdWritable(fd);
                    continue;
                } else {
                    return error.WouldBlock;
                },
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
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdWritable(fd);
                continue;
            } else {
                return error.WouldBlock;
            },
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
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    FileNotFound,

    /// The path exceeded `MAX_PATH_BYTES` bytes.
    NameTooLong,

    /// Insufficient kernel memory was available, or
    /// the named file is a FIFO and per-user hard limit on
    /// memory allocation for pipes has been reached.
    SystemResources,

    /// The file is too large to be opened. This error is unreachable
    /// for 64-bit targets, as well as when opening directories.
    FileTooBig,

    /// The path refers to directory but the `O_DIRECTORY` flag was not provided.
    IsDir,

    /// A new path cannot be created because the device has no room for the new file.
    /// This error is only reachable when the `O_CREAT` flag is provided.
    NoSpaceLeft,

    /// A component used as a directory in the path was not, in fact, a directory, or
    /// `O_DIRECTORY` was specified and the path was not a directory.
    NotDir,

    /// The path already exists and the `O_CREAT` and `O_EXCL` flags were provided.
    PathAlreadyExists,
    DeviceBusy,
} || UnexpectedError;

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// See also `openC`.
pub fn open(file_path: []const u8, flags: u32, perm: usize) OpenError!fd_t {
    const file_path_c = try toPosixPath(file_path);
    return openC(&file_path_c, flags, perm);
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// See also `open`.
pub fn openC(file_path: [*:0]const u8, flags: u32, perm: usize) OpenError!fd_t {
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

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// `file_path` is relative to the open directory handle `dir_fd`.
/// See also `openatC`.
pub fn openat(dir_fd: fd_t, file_path: []const u8, flags: u32, mode: usize) OpenError!fd_t {
    const file_path_c = try toPosixPath(file_path);
    return openatC(dir_fd, &file_path_c, flags, mode);
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// `file_path` is relative to the open directory handle `dir_fd`.
/// See also `openat`.
pub fn openatC(dir_fd: fd_t, file_path: [*:0]const u8, flags: u32, mode: usize) OpenError!fd_t {
    while (true) {
        const rc = system.openat(dir_fd, file_path, flags, mode);
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
            EINVAL => unreachable, // invalid parameters passed to dup2
            EBADF => unreachable, // always a race condition
            else => |err| return unexpectedErrno(err),
        }
    }
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
} || UnexpectedError;

/// Like `execve` except the parameters are null-terminated,
/// matching the syscall API on all targets. This removes the need for an allocator.
/// This function ignores PATH environment variable. See `execvpeC` for that.
pub fn execveC(path: [*:0]const u8, child_argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) ExecveError {
    switch (errno(system.execve(path, child_argv, envp))) {
        0 => unreachable,
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
        else => |err| return unexpectedErrno(err),
    }
}

/// Like `execvpe` except the parameters are null-terminated,
/// matching the syscall API on all targets. This removes the need for an allocator.
/// This function also uses the PATH environment variable to get the full path to the executable.
/// If `file` is an absolute path, this is the same as `execveC`.
pub fn execvpeC(file: [*:0]const u8, child_argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) ExecveError {
    const file_slice = mem.toSliceConst(u8, file);
    if (mem.indexOfScalar(u8, file_slice, '/') != null) return execveC(file, child_argv, envp);

    const PATH = getenv("PATH") orelse "/usr/local/bin:/bin/:/usr/bin";
    var path_buf: [MAX_PATH_BYTES]u8 = undefined;
    var it = mem.tokenize(PATH, ":");
    var seen_eacces = false;
    var err: ExecveError = undefined;
    while (it.next()) |search_path| {
        if (path_buf.len < search_path.len + file_slice.len + 1) return error.NameTooLong;
        mem.copy(u8, &path_buf, search_path);
        path_buf[search_path.len] = '/';
        mem.copy(u8, path_buf[search_path.len + 1 ..], file_slice);
        const path_len = search_path.len + file_slice.len + 1;
        path_buf[path_len] = 0;
        err = execveC(path_buf[0..path_len :0].ptr, child_argv, envp);
        switch (err) {
            error.AccessDenied => seen_eacces = true,
            error.FileNotFound, error.NotDir => {},
            else => |e| return e,
        }
    }
    if (seen_eacces) return error.AccessDenied;
    return err;
}

/// This function must allocate memory to add a null terminating bytes on path and each arg.
/// It must also convert to KEY=VALUE\0 format for environment variables, and include null
/// pointers after the args and after the environment variables.
/// `argv_slice[0]` is the executable path.
/// This function also uses the PATH environment variable to get the full path to the executable.
pub fn execvpe(
    allocator: *mem.Allocator,
    argv_slice: []const []const u8,
    env_map: *const std.BufMap,
) (ExecveError || error{OutOfMemory}) {
    const argv_buf = try allocator.alloc(?[*:0]u8, argv_slice.len + 1);
    mem.set(?[*:0]u8, argv_buf, null);
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
        argv_buf[i] = arg_buf[0..arg.len :0].ptr;
    }
    argv_buf[argv_slice.len] = null;
    const argv_ptr = argv_buf[0..argv_slice.len :null].ptr;

    const envp_buf = try createNullDelimitedEnvMap(allocator, env_map);
    defer freeNullDelimitedEnvMap(allocator, envp_buf);

    return execvpeC(argv_buf.ptr[0].?, argv_ptr, envp_buf.ptr);
}

pub fn createNullDelimitedEnvMap(allocator: *mem.Allocator, env_map: *const std.BufMap) ![:null]?[*:0]u8 {
    const envp_count = env_map.count();
    const envp_buf = try allocator.alloc(?[*:0]u8, envp_count + 1);
    mem.set(?[*:0]u8, envp_buf, null);
    errdefer freeNullDelimitedEnvMap(allocator, envp_buf);
    {
        var it = env_map.iterator();
        var i: usize = 0;
        while (it.next()) |pair| : (i += 1) {
            const env_buf = try allocator.alloc(u8, pair.key.len + pair.value.len + 2);
            @memcpy(env_buf.ptr, pair.key.ptr, pair.key.len);
            env_buf[pair.key.len] = '=';
            @memcpy(env_buf.ptr + pair.key.len + 1, pair.value.ptr, pair.value.len);
            const len = env_buf.len - 1;
            env_buf[len] = 0;
            envp_buf[i] = env_buf[0..len :0].ptr;
        }
        assert(i == envp_count);
    }
    return envp_buf[0..envp_count :null];
}

pub fn freeNullDelimitedEnvMap(allocator: *mem.Allocator, envp_buf: []?[*:0]u8) void {
    for (envp_buf) |env| {
        const env_buf = if (env) |ptr| ptr[0 .. mem.len(u8, ptr) + 1] else break;
        allocator.free(env_buf);
    }
    allocator.free(envp_buf);
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
pub fn getenvC(key: [*:0]const u8) ?[]const u8 {
    if (builtin.link_libc) {
        const value = system.getenv(key) orelse return null;
        return mem.toSliceConst(u8, value);
    }
    return getenv(mem.toSliceConst(u8, key));
}

pub const GetCwdError = error{
    NameTooLong,
    CurrentWorkingDirectoryUnlinked,
} || UnexpectedError;

/// The result is a slice of out_buffer, indexed from 0.
pub fn getcwd(out_buffer: []u8) GetCwdError![]u8 {
    if (builtin.os == .windows) {
        return windows.GetCurrentDirectory(out_buffer);
    }

    const err = if (builtin.link_libc) blk: {
        break :blk if (std.c.getcwd(out_buffer.ptr, out_buffer.len)) |_| 0 else std.c._errno().*;
    } else blk: {
        break :blk errno(system.getcwd(out_buffer.ptr, out_buffer.len));
    };
    switch (err) {
        0 => return mem.toSlice(u8, @ptrCast([*:0]u8, out_buffer.ptr)),
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
} || UnexpectedError;

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `sym_link_path` exists, it will not be overwritten.
/// See also `symlinkC` and `symlinkW`.
pub fn symlink(target_path: []const u8, sym_link_path: []const u8) SymLinkError!void {
    if (builtin.os == .windows) {
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
pub fn symlinkC(target_path: [*:0]const u8, sym_link_path: [*:0]const u8) SymLinkError!void {
    if (builtin.os == .windows) {
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

pub fn symlinkatC(target_path: [*:0]const u8, newdirfd: fd_t, sym_link_path: [*:0]const u8) SymLinkError!void {
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

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,
} || UnexpectedError;

/// Delete a name and possibly the file it refers to.
/// See also `unlinkC`.
pub fn unlink(file_path: []const u8) UnlinkError!void {
    if (builtin.os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(file_path);
        return windows.DeleteFileW(&file_path_w);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return unlinkC(&file_path_c);
    }
}

/// Same as `unlink` except the parameter is a null terminated UTF8-encoded string.
pub fn unlinkC(file_path: [*:0]const u8) UnlinkError!void {
    if (builtin.os == .windows) {
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

pub const UnlinkatError = UnlinkError || error{
    /// When passing `AT_REMOVEDIR`, this error occurs when the named directory is not empty.
    DirNotEmpty,
};

/// Delete a file name and possibly the file it refers to, based on an open directory handle.
/// Asserts that the path parameter has no null bytes.
pub fn unlinkat(dirfd: fd_t, file_path: []const u8, flags: u32) UnlinkatError!void {
    if (std.debug.runtime_safety) for (file_path) |byte| assert(byte != 0);
    if (builtin.os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(file_path);
        return unlinkatW(dirfd, &file_path_w, flags);
    }
    const file_path_c = try toPosixPath(file_path);
    return unlinkatC(dirfd, &file_path_c, flags);
}

/// Same as `unlinkat` but `file_path` is a null-terminated string.
pub fn unlinkatC(dirfd: fd_t, file_path_c: [*:0]const u8, flags: u32) UnlinkatError!void {
    if (builtin.os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(file_path_c);
        return unlinkatW(dirfd, &file_path_w, flags);
    }
    switch (errno(system.unlinkat(dirfd, file_path_c, flags))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.AccessDenied,
        EBUSY => return error.FileBusy,
        EFAULT => unreachable,
        EIO => return error.FileSystem,
        EISDIR => return error.IsDir,
        ELOOP => return error.SymLinkLoop,
        ENAMETOOLONG => return error.NameTooLong,
        ENOENT => return error.FileNotFound,
        ENOTDIR => return error.NotDir,
        ENOMEM => return error.SystemResources,
        EROFS => return error.ReadOnlyFileSystem,
        ENOTEMPTY => return error.DirNotEmpty,

        EINVAL => unreachable, // invalid flags, or pathname has . as last component
        EBADF => unreachable, // always a race condition

        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `unlinkat` but `sub_path_w` is UTF16LE, NT prefixed. Windows only.
pub fn unlinkatW(dirfd: fd_t, sub_path_w: [*:0]const u16, flags: u32) UnlinkatError!void {
    const w = windows;

    const want_rmdir_behavior = (flags & AT_REMOVEDIR) != 0;
    const create_options_flags = if (want_rmdir_behavior)
        @as(w.ULONG, w.FILE_DELETE_ON_CLOSE)
    else
        @as(w.ULONG, w.FILE_DELETE_ON_CLOSE | w.FILE_NON_DIRECTORY_FILE);

    const path_len_bytes = @intCast(u16, mem.toSliceConst(u16, sub_path_w).len * 2);
    var nt_name = w.UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        // The Windows API makes this mutable, but it will not mutate here.
        .Buffer = @intToPtr([*]u16, @ptrToInt(sub_path_w)),
    };

    if (sub_path_w[0] == '.' and sub_path_w[1] == 0) {
        // Windows does not recognize this, but it does work with empty string.
        nt_name.Length = 0;
    }
    if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) {
        // Can't remove the parent directory with an open handle.
        return error.FileBusy;
    }

    var attr = w.OBJECT_ATTRIBUTES{
        .Length = @sizeOf(w.OBJECT_ATTRIBUTES),
        .RootDirectory = dirfd,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var io: w.IO_STATUS_BLOCK = undefined;
    var tmp_handle: w.HANDLE = undefined;
    var rc = w.ntdll.NtCreateFile(
        &tmp_handle,
        w.SYNCHRONIZE | w.DELETE,
        &attr,
        &io,
        null,
        0,
        w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE,
        w.FILE_OPEN,
        create_options_flags,
        null,
        0,
    );
    if (rc == w.STATUS.SUCCESS) {
        rc = w.ntdll.NtClose(tmp_handle);
    }
    switch (rc) {
        w.STATUS.SUCCESS => return,
        w.STATUS.OBJECT_NAME_INVALID => unreachable,
        w.STATUS.OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        w.STATUS.INVALID_PARAMETER => unreachable,
        w.STATUS.FILE_IS_A_DIRECTORY => return error.IsDir,
        else => return w.unexpectedStatus(rc),
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
} || UnexpectedError;

/// Change the name or location of a file.
pub fn rename(old_path: []const u8, new_path: []const u8) RenameError!void {
    if (builtin.os == .windows) {
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
pub fn renameC(old_path: [*:0]const u8, new_path: [*:0]const u8) RenameError!void {
    if (builtin.os == .windows) {
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
pub fn renameW(old_path: [*:0]const u16, new_path: [*:0]const u16) RenameError!void {
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
} || UnexpectedError;

/// Create a directory.
/// `mode` is ignored on Windows.
pub fn mkdir(dir_path: []const u8, mode: u32) MakeDirError!void {
    if (builtin.os == .windows) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        return windows.CreateDirectoryW(&dir_path_w, null);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return mkdirC(&dir_path_c, mode);
    }
}

/// Same as `mkdir` but the parameter is a null-terminated UTF8-encoded string.
pub fn mkdirC(dir_path: [*:0]const u8, mode: u32) MakeDirError!void {
    if (builtin.os == .windows) {
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
} || UnexpectedError;

/// Deletes an empty directory.
pub fn rmdir(dir_path: []const u8) DeleteDirError!void {
    if (builtin.os == .windows) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        return windows.RemoveDirectoryW(&dir_path_w);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return rmdirC(&dir_path_c);
    }
}

/// Same as `rmdir` except the parameter is null-terminated.
pub fn rmdirC(dir_path: [*:0]const u8) DeleteDirError!void {
    if (builtin.os == .windows) {
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
} || UnexpectedError;

/// Changes the current working directory of the calling process.
/// `dir_path` is recommended to be a UTF-8 encoded string.
pub fn chdir(dir_path: []const u8) ChangeCurDirError!void {
    if (builtin.os == .windows) {
        const dir_path_w = try windows.sliceToPrefixedFileW(dir_path);
        @compileError("TODO implement chdir for Windows");
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return chdirC(&dir_path_c);
    }
}

/// Same as `chdir` except the parameter is null-terminated.
pub fn chdirC(dir_path: [*:0]const u8) ChangeCurDirError!void {
    if (builtin.os == .windows) {
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
} || UnexpectedError;

/// Read value of a symbolic link.
/// The return value is a slice of `out_buffer` from index 0.
pub fn readlink(file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (builtin.os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(file_path);
        @compileError("TODO implement readlink for Windows");
    } else {
        const file_path_c = try toPosixPath(file_path);
        return readlinkC(&file_path_c, out_buffer);
    }
}

/// Same as `readlink` except `file_path` is null-terminated.
pub fn readlinkC(file_path: [*:0]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (builtin.os == .windows) {
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

pub fn readlinkatC(dirfd: fd_t, file_path: [*:0]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (builtin.os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(file_path);
        @compileError("TODO implement readlink for Windows");
    }
    const rc = system.readlinkat(dirfd, file_path, out_buffer.ptr, out_buffer.len);
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
} || UnexpectedError;

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
    if (builtin.os == .windows) {
        if (isCygwinPty(handle))
            return true;

        var out: windows.DWORD = undefined;
        return windows.kernel32.GetConsoleMode(handle, &out) != 0;
    }
    if (builtin.link_libc) {
        return system.isatty(handle) != 0;
    }
    if (builtin.os == .wasi) {
        var statbuf: fdstat_t = undefined;
        const err = system.fd_fdstat_get(handle, &statbuf);
        if (err != 0) {
            // errno = err;
            return false;
        }

        // A tty is a character device that we can't seek or tell on.
        if (statbuf.fs_filetype != FILETYPE_CHARACTER_DEVICE or
            (statbuf.fs_rights_base & (RIGHT_FD_SEEK | RIGHT_FD_TELL)) != 0)
        {
            // errno = ENOTTY;
            return false;
        }

        return true;
    }
    if (builtin.os == .linux) {
        var wsz: linux.winsize = undefined;
        return linux.syscall3(linux.SYS_ioctl, @bitCast(usize, @as(isize, handle)), linux.TIOCGWINSZ, @ptrToInt(&wsz)) == 0;
    }
    unreachable;
}

pub fn isCygwinPty(handle: fd_t) bool {
    if (builtin.os != .windows) return false;

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
    const name_bytes = name_info_bytes[size .. size + @as(usize, name_info.FileNameLength)];
    const name_wide = @bytesToSlice(u16, name_bytes);
    return mem.indexOf(u16, name_wide, &[_]u16{ 'm', 's', 'y', 's', '-' }) != null or
        mem.indexOf(u16, name_wide, &[_]u16{ '-', 'p', 't', 'y' }) != null;
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
} || UnexpectedError;

pub fn socket(domain: u32, socket_type: u32, protocol: u32) SocketError!fd_t {
    const rc = system.socket(domain, socket_type, protocol);
    switch (errno(rc)) {
        0 => return @intCast(fd_t, rc),
        EACCES => return error.PermissionDenied,
        EAFNOSUPPORT => return error.AddressFamilyNotSupported,
        EINVAL => return error.ProtocolFamilyNotAvailable,
        EMFILE => return error.ProcessFdQuotaExceeded,
        ENFILE => return error.SystemFdQuotaExceeded,
        ENOBUFS => return error.SystemResources,
        ENOMEM => return error.SystemResources,
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
} || UnexpectedError;

/// addr is `*const T` where T is one of the sockaddr
pub fn bind(sockfd: fd_t, addr: *const sockaddr, len: socklen_t) BindError!void {
    const rc = system.bind(sockfd, addr, len);
    switch (errno(rc)) {
        0 => return,
        EACCES => return error.AccessDenied,
        EADDRINUSE => return error.AddressInUse,
        EBADF => unreachable, // always a race condition if this error is returned
        EINVAL => unreachable, // invalid parameters
        ENOTSOCK => unreachable, // invalid `sockfd`
        EADDRNOTAVAIL => return error.AddressNotAvailable,
        EFAULT => unreachable, // invalid `addr` pointer
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
} || UnexpectedError;

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

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    /// This error occurs when no global event loop is configured,
    /// and accepting from the socket would block.
    WouldBlock,
} || UnexpectedError;

/// Accept a connection on a socket.
/// If the application has a global event loop enabled, EAGAIN is handled
/// via the event loop. Otherwise EAGAIN results in error.WouldBlock.
pub fn accept4(
    /// This argument is a socket that has been created with `socket`, bound to a local address
    /// with `bind`, and is listening for connections after a `listen`.
    sockfd: fd_t,
    /// This argument is a pointer to a sockaddr structure.  This structure is filled in with  the
    /// address  of  the  peer  socket, as known to the communications layer.  The exact format of the
    /// address returned addr is determined by the socket's address  family  (see  `socket`  and  the
    /// respective  protocol  man  pages).
    addr: *sockaddr,
    /// This argument is a value-result argument: the caller must initialize it to contain  the
    /// size (in bytes) of the structure pointed to by addr; on return it will contain the actual size
    /// of the peer address.
    ///
    /// The returned address is truncated if the buffer provided is too small; in this  case,  `addr_size`
    /// will return a value greater than was supplied to the call.
    addr_size: *socklen_t,
    /// If  flags  is  0, then `accept4` is the same as `accept`.  The following values can be bitwise
    /// ORed in flags to obtain different behavior:
    /// * `SOCK_NONBLOCK` - Set the `O_NONBLOCK` file status flag on the open file description (see `open`)
    ///   referred  to by the new file descriptor.  Using this flag saves extra calls to `fcntl` to achieve
    ///   the same result.
    /// * `SOCK_CLOEXEC`  - Set the close-on-exec (`FD_CLOEXEC`) flag on the new file descriptor.   See  the
    ///   description  of the `O_CLOEXEC` flag in `open` for reasons why this may be useful.
    flags: u32,
) AcceptError!fd_t {
    while (true) {
        const rc = system.accept4(sockfd, addr, addr_size, flags);
        switch (errno(rc)) {
            0 => return @intCast(fd_t, rc),
            EINTR => continue,

            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(sockfd);
                continue;
            } else {
                return error.WouldBlock;
            },
            EBADF => unreachable, // always a race condition
            ECONNABORTED => return error.ConnectionAborted,
            EFAULT => unreachable,
            EINVAL => unreachable,
            ENOTSOCK => unreachable,
            EMFILE => return error.ProcessFdQuotaExceeded,
            ENFILE => return error.SystemFdQuotaExceeded,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            EOPNOTSUPP => unreachable,
            EPROTO => return error.ProtocolFailure,
            EPERM => return error.BlockedByFirewall,

            else => |err| return unexpectedErrno(err),
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
} || UnexpectedError;

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
} || UnexpectedError;

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
} || UnexpectedError;

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
} || UnexpectedError;

pub fn getsockname(sockfd: fd_t, addr: *sockaddr, addrlen: *socklen_t) GetSockNameError!void {
    switch (errno(system.getsockname(sockfd, addr, addrlen))) {
        0 => return,
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

    /// This error occurs when no global event loop is configured,
    /// and connecting to the socket would block.
    WouldBlock,

    /// The given path for the unix socket does not exist.
    FileNotFound,
} || UnexpectedError;

/// Initiate a connection on a socket.
pub fn connect(sockfd: fd_t, sock_addr: *const sockaddr, len: socklen_t) ConnectError!void {
    while (true) {
        switch (errno(system.connect(sockfd, sock_addr, len))) {
            0 => return,
            EACCES => return error.PermissionDenied,
            EPERM => return error.PermissionDenied,
            EADDRINUSE => return error.AddressInUse,
            EADDRNOTAVAIL => return error.AddressNotAvailable,
            EAFNOSUPPORT => return error.AddressFamilyNotSupported,
            EAGAIN, EINPROGRESS => {
                const loop = std.event.Loop.instance orelse return error.WouldBlock;
                loop.waitUntilFdWritableOrReadable(sockfd);
                return getsockoptError(sockfd);
            },
            EALREADY => unreachable, // The socket is nonblocking and a previous connection attempt has not yet been completed.
            EBADF => unreachable, // sockfd is not a valid open file descriptor.
            ECONNREFUSED => return error.ConnectionRefused,
            EFAULT => unreachable, // The socket structure address is outside the user's address space.
            EINTR => continue,
            EISCONN => unreachable, // The socket is already connected.
            ENETUNREACH => return error.NetworkUnreachable,
            ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            EPROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            ETIMEDOUT => return error.ConnectionTimedOut,
            ENOENT => return error.FileNotFound, // Returned when socket is AF_UNIX and the given path does not exist.
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
    AccessDenied,
} || UnexpectedError;

pub fn fstat(fd: fd_t) FStatError!Stat {
    var stat: Stat = undefined;
    if (comptime std.Target.current.isDarwin()) {
        switch (darwin.getErrno(darwin.@"fstat$INODE64"(fd, &stat))) {
            0 => return stat,
            EINVAL => unreachable,
            EBADF => unreachable, // Always a race condition.
            ENOMEM => return error.SystemResources,
            EACCES => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    switch (errno(system.fstat(fd, &stat))) {
        0 => return stat,
        EINVAL => unreachable,
        EBADF => unreachable, // Always a race condition.
        ENOMEM => return error.SystemResources,
        EACCES => return error.AccessDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const KQueueError = error{
    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,
} || UnexpectedError;

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
} || UnexpectedError;

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
} || UnexpectedError;

/// add a watch to an initialized inotify instance
pub fn inotify_add_watch(inotify_fd: i32, pathname: []const u8, mask: u32) INotifyAddWatchError!i32 {
    const pathname_c = try toPosixPath(pathname);
    return inotify_add_watchC(inotify_fd, &pathname_c, mask);
}

/// Same as `inotify_add_watch` except pathname is null-terminated.
pub fn inotify_add_watchC(inotify_fd: i32, pathname: [*:0]const u8, mask: u32) INotifyAddWatchError!i32 {
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
} || UnexpectedError;

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

pub const ForkError = error{SystemResources} || UnexpectedError;

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
} || UnexpectedError;

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
    offset: u64,
) MMapError![]align(mem.page_size) u8 {
    const err = if (builtin.link_libc) blk: {
        const rc = std.c.mmap(ptr, length, prot, flags, fd, offset);
        if (rc != std.c.MAP_FAILED) return @ptrCast([*]align(mem.page_size) u8, @alignCast(mem.page_size, rc))[0..length];
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
} || UnexpectedError;

/// check user's permissions for a file
/// TODO currently this assumes `mode` is `F_OK` on Windows.
pub fn access(path: []const u8, mode: u32) AccessError!void {
    if (builtin.os == .windows) {
        const path_w = try windows.sliceToPrefixedFileW(path);
        _ = try windows.GetFileAttributesW(&path_w);
        return;
    }
    const path_c = try toPosixPath(path);
    return accessC(&path_c, mode);
}

/// Same as `access` except `path` is null-terminated.
pub fn accessC(path: [*:0]const u8, mode: u32) AccessError!void {
    if (builtin.os == .windows) {
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

/// Call from Windows-specific code if you already have a UTF-16LE encoded, null terminated string.
/// Otherwise use `access` or `accessC`.
/// TODO currently this ignores `mode`.
pub fn accessW(path: [*:0]const u16, mode: u32) windows.GetFileAttributesError!void {
    const ret = try windows.GetFileAttributesW(path);
    if (ret != windows.INVALID_FILE_ATTRIBUTES) {
        return;
    }
    switch (windows.kernel32.GetLastError()) {
        windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
        windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
        windows.ERROR.ACCESS_DENIED => return error.PermissionDenied,
        else => |err| return windows.unexpectedError(err),
    }
}

pub const PipeError = error{
    SystemFdQuotaExceeded,
    ProcessFdQuotaExceeded,
} || UnexpectedError;

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
} || UnexpectedError;

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
    name: [*:0]const u8,
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

pub const SeekError = error{Unseekable} || UnexpectedError;

/// Repositions read/write file offset relative to the beginning.
pub fn lseek_SET(fd: fd_t, offset: u64) SeekError!void {
    if (builtin.os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, offset, &result, SEEK_SET))) {
            0 => return,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (builtin.os == .windows) {
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
    if (builtin.os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, @bitCast(u64, offset), &result, SEEK_CUR))) {
            0 => return,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (builtin.os == .windows) {
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
    if (builtin.os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, @bitCast(u64, offset), &result, SEEK_END))) {
            0 => return,
            EBADF => unreachable, // always a race condition
            EINVAL => return error.Unseekable,
            EOVERFLOW => return error.Unseekable,
            ESPIPE => return error.Unseekable,
            ENXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (builtin.os == .windows) {
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
    if (builtin.os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
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
    if (builtin.os == .windows) {
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
} || UnexpectedError;

/// Return the canonicalized absolute pathname.
/// Expands all symbolic links and resolves references to `.`, `..`, and
/// extra `/` characters in `pathname`.
/// The return value is a slice of `out_buffer`, but not necessarily from the beginning.
/// See also `realpathC` and `realpathW`.
pub fn realpath(pathname: []const u8, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
    if (builtin.os == .windows) {
        const pathname_w = try windows.sliceToPrefixedFileW(pathname);
        return realpathW(&pathname_w, out_buffer);
    }
    const pathname_c = try toPosixPath(pathname);
    return realpathC(&pathname_c, out_buffer);
}

/// Same as `realpath` except `pathname` is null-terminated.
pub fn realpathC(pathname: [*:0]const u8, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
    if (builtin.os == .windows) {
        const pathname_w = try windows.cStrToPrefixedFileW(pathname);
        return realpathW(&pathname_w, out_buffer);
    }
    if (builtin.os == .linux and !builtin.link_libc) {
        const fd = try openC(pathname, linux.O_PATH | linux.O_NONBLOCK | linux.O_CLOEXEC, 0);
        defer close(fd);

        var procfs_buf: ["/proc/self/fd/-2147483648".len:0]u8 = undefined;
        const proc_path = std.fmt.bufPrint(procfs_buf[0..], "/proc/self/fd/{}\x00", .{fd}) catch unreachable;

        return readlinkC(@ptrCast([*:0]const u8, proc_path.ptr), out_buffer);
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
pub fn realpathW(pathname: [*:0]const u16, out_buffer: *[MAX_PATH_BYTES]u8) RealPathError![]u8 {
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
    const start_index = if (mem.startsWith(u16, wide_slice, &prefix)) prefix.len else 0;

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

pub fn dl_iterate_phdr(
    comptime T: type,
    callback: extern fn (info: *dl_phdr_info, size: usize, data: ?*T) i32,
    data: ?*T,
) isize {
    if (builtin.object_format != .elf)
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
            .dlpi_name = "/proc/self/exe",
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

pub const ClockGetTimeError = error{UnsupportedClock} || UnexpectedError;

pub fn clock_gettime(clk_id: i32, tp: *timespec) ClockGetTimeError!void {
    if (comptime std.Target.current.getOs() == .wasi) {
        var ts: timestamp_t = undefined;
        switch (system.clock_time_get(@bitCast(u32, clk_id), 1, &ts)) {
            0 => {
                tp.* = .{
                    .tv_sec = @intCast(i64, ts / std.time.ns_per_s),
                    .tv_nsec = @intCast(isize, ts % std.time.ns_per_s),
                };
            },
            EINVAL => return error.UnsupportedClock,
            else => |err| return unexpectedErrno(err),
        }
        return;
    }
    switch (errno(system.clock_gettime(clk_id, tp))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn clock_getres(clk_id: i32, res: *timespec) ClockGetTimeError!void {
    if (comptime std.Target.current.getOs() == .wasi) {
        var ts: timestamp_t = undefined;
        switch (system.clock_res_get(@bitCast(u32, clk_id), &ts)) {
            0 => res.* = .{
                .tv_sec = @intCast(i64, ts / std.time.ns_per_s),
                .tv_nsec = @intCast(isize, ts % std.time.ns_per_s),
            },
            EINVAL => return error.UnsupportedClock,
            else => |err| return unexpectedErrno(err),
        }
        return;
    }

    switch (errno(system.clock_getres(clk_id, res))) {
        0 => return,
        EFAULT => unreachable,
        EINVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SchedGetAffinityError = error{PermissionDenied} || UnexpectedError;

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
pub fn toPosixPath(file_path: []const u8) ![PATH_MAX - 1:0]u8 {
    var path_with_null: [PATH_MAX - 1:0]u8 = undefined;
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
        std.debug.warn("unexpected errno: {}\n", .{err});
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

pub const SigaltstackError = error{
    /// The supplied stack size was less than MINSIGSTKSZ.
    SizeTooSmall,

    /// Attempted to change the signal stack while it was active.
    PermissionDenied,
} || UnexpectedError;

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) SigaltstackError!void {
    if (builtin.os == .windows or builtin.os == .uefi or builtin.os == .wasi)
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

pub const FutimensError = error{
    /// times is NULL, or both tv_nsec values are UTIME_NOW, and either:
    /// *  the effective user ID of the caller does not match the  owner
    ///    of  the  file,  the  caller does not have write access to the
    ///    file, and the caller is not privileged (Linux: does not  have
    ///    either  the  CAP_FOWNER  or the CAP_DAC_OVERRIDE capability);
    ///    or,
    /// *  the file is marked immutable (see chattr(1)).
    AccessDenied,

    /// The caller attempted to change one or both timestamps to a value
    /// other than the current time, or to change one of the  timestamps
    /// to the current time while leaving the other timestamp unchanged,
    /// (i.e., times is not NULL, neither tv_nsec  field  is  UTIME_NOW,
    /// and neither tv_nsec field is UTIME_OMIT) and either:
    /// *  the  caller's  effective  user ID does not match the owner of
    ///    file, and the caller is not privileged (Linux: does not  have
    ///    the CAP_FOWNER capability); or,
    /// *  the file is marked append-only or immutable (see chattr(1)).
    PermissionDenied,

    ReadOnlyFileSystem,
} || UnexpectedError;

pub fn futimens(fd: fd_t, times: *const [2]timespec) FutimensError!void {
    switch (errno(system.futimens(fd, times))) {
        0 => return,
        EACCES => return error.AccessDenied,
        EPERM => return error.PermissionDenied,
        EBADF => unreachable, // always a race condition
        EFAULT => unreachable,
        EINVAL => unreachable,
        EROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub const GetHostNameError = error{PermissionDenied} || UnexpectedError;

pub fn gethostname(name_buffer: *[HOST_NAME_MAX]u8) GetHostNameError![]u8 {
    if (builtin.link_libc) {
        switch (errno(system.gethostname(name_buffer, name_buffer.len))) {
            0 => return mem.toSlice(u8, @ptrCast([*:0]u8, name_buffer)),
            EFAULT => unreachable,
            ENAMETOOLONG => unreachable, // HOST_NAME_MAX prevents this
            EPERM => return error.PermissionDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (builtin.os == .linux) {
        var uts: utsname = undefined;
        switch (errno(system.uname(&uts))) {
            0 => {
                const hostname = mem.toSlice(u8, @ptrCast([*:0]u8, &uts.nodename));
                mem.copy(u8, name_buffer, hostname);
                return name_buffer[0..hostname.len];
            },
            EFAULT => unreachable,
            EPERM => return error.PermissionDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    @compileError("TODO implement gethostname for this OS");
}

pub fn res_mkquery(
    op: u4,
    dname: []const u8,
    class: u8,
    ty: u8,
    data: []const u8,
    newrr: ?[*]const u8,
    buf: []u8,
) usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var name = dname;
    if (mem.endsWith(u8, name, ".")) name.len -= 1;
    assert(name.len <= 253);
    const n = 17 + name.len + @boolToInt(name.len != 0);

    // Construct query template - ID will be filled later
    var q: [280]u8 = undefined;
    @memset(&q, 0, n);
    q[2] = @as(u8, op) * 8 + 1;
    q[5] = 1;
    mem.copy(u8, q[13..], name);
    var i: usize = 13;
    var j: usize = undefined;
    while (q[i] != 0) : (i = j + 1) {
        j = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        // TODO determine the circumstances for this and whether or
        // not this should be an error.
        if (j - i - 1 > 62) unreachable;
        q[i - 1] = @intCast(u8, j - i);
    }
    q[i + 1] = ty;
    q[i + 3] = class;

    // Make a reasonably unpredictable id
    var ts: timespec = undefined;
    clock_gettime(CLOCK_REALTIME, &ts) catch {};
    const UInt = @IntType(false, @TypeOf(ts.tv_nsec).bit_count);
    const unsec = @bitCast(UInt, ts.tv_nsec);
    const id = @truncate(u32, unsec + unsec / 65536);
    q[0] = @truncate(u8, id / 256);
    q[1] = @truncate(u8, id);

    mem.copy(u8, buf, q[0..n]);
    return n;
}

pub const SendError = error{
    /// (For UNIX domain sockets, which are identified by pathname) Write permission is  denied
    /// on  the destination socket file, or search permission is denied for one of the
    /// directories the path prefix.  (See path_resolution(7).)
    /// (For UDP sockets) An attempt was made to send to a network/broadcast address as  though
    /// it was a unicast address.
    AccessDenied,

    /// The socket is marked nonblocking and the requested operation would block, and
    /// there is no global event loop configured.
    /// It's also possible to get this error under the following condition:
    /// (Internet  domain datagram sockets) The socket referred to by sockfd had not previously
    /// been bound to an address and, upon attempting to bind it to an ephemeral port,  it  was
    /// determined that all port numbers in the ephemeral port range are currently in use.  See
    /// the discussion of /proc/sys/net/ipv4/ip_local_port_range in ip(7).
    WouldBlock,

    /// Another Fast Open is already in progress.
    FastOpenAlreadyInProgress,

    /// Connection reset by peer.
    ConnectionResetByPeer,

    /// The  socket  type requires that message be sent atomically, and the size of the message
    /// to be sent made this impossible. The message is not transmitted.
    ///
    MessageTooBig,

    /// The output queue for a network interface was full.  This generally indicates  that  the
    /// interface  has  stopped sending, but may be caused by transient congestion.  (Normally,
    /// this does not occur in Linux.  Packets are just silently dropped when  a  device  queue
    /// overflows.)
    /// This is also caused when there is not enough kernel memory available.
    SystemResources,

    /// The  local  end  has been shut down on a connection oriented socket.  In this case, the
    /// process will also receive a SIGPIPE unless MSG_NOSIGNAL is set.
    BrokenPipe,
} || UnexpectedError;

/// Transmit a message to another socket.
///
/// The `sendto` call may be used only when the socket is in a connected state (so that the intended
/// recipient  is  known). The  following call
///
///     send(sockfd, buf, len, flags);
///
/// is equivalent to
///
///     sendto(sockfd, buf, len, flags, NULL, 0);
///
/// If  sendto()  is used on a connection-mode (`SOCK_STREAM`, `SOCK_SEQPACKET`) socket, the arguments
/// `dest_addr` and `addrlen` are asserted to be `null` and `0` respectively, and asserted
/// that the socket was actually connected.
/// Otherwise, the address of the target is given by `dest_addr` with `addrlen` specifying  its  size.
///
/// If the message is too long to pass atomically through the underlying protocol,
/// `SendError.MessageTooBig` is returned, and the message is not transmitted.
///
/// There is no  indication  of  failure  to  deliver.
///
/// When the message does not fit into the send buffer of  the  socket,  `sendto`  normally  blocks,
/// unless  the socket has been placed in nonblocking I/O mode.  In nonblocking mode it would fail
/// with `SendError.WouldBlock`.  The `select` call may be used  to  determine when it is
/// possible to send more data.
pub fn sendto(
    /// The file descriptor of the sending socket.
    sockfd: fd_t,
    /// Message to send.
    buf: []const u8,
    flags: u32,
    dest_addr: ?*const sockaddr,
    addrlen: socklen_t,
) SendError!usize {
    while (true) {
        const rc = system.sendto(sockfd, buf.ptr, buf.len, flags, dest_addr, addrlen);
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),

            EACCES => return error.AccessDenied,
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdWritable(sockfd);
                continue;
            } else {
                return error.WouldBlock;
            },
            EALREADY => return error.FastOpenAlreadyInProgress,
            EBADF => unreachable, // always a race condition
            ECONNRESET => return error.ConnectionResetByPeer,
            EDESTADDRREQ => unreachable, // The socket is not connection-mode, and no peer address is set.
            EFAULT => unreachable, // An invalid user space address was specified for an argument.
            EINTR => continue,
            EINVAL => unreachable, // Invalid argument passed.
            EISCONN => unreachable, // connection-mode socket was connected already but a recipient was specified
            EMSGSIZE => return error.MessageTooBig,
            ENOBUFS => return error.SystemResources,
            ENOMEM => return error.SystemResources,
            ENOTCONN => unreachable, // The socket is not connected, and no target has been given.
            ENOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            EOPNOTSUPP => unreachable, // Some bit in the flags argument is inappropriate for the socket type.
            EPIPE => return error.BrokenPipe,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Transmit a message to another socket.
///
/// The `send` call may be used only when the socket is in a connected state (so that the intended
/// recipient  is  known).   The  only  difference  between `send` and `write` is the presence of
/// flags.  With a zero flags argument, `send` is equivalent to  `write`.   Also,  the  following
/// call
///
///     send(sockfd, buf, len, flags);
///
/// is equivalent to
///
///     sendto(sockfd, buf, len, flags, NULL, 0);
///
/// There is no  indication  of  failure  to  deliver.
///
/// When the message does not fit into the send buffer of  the  socket,  `send`  normally  blocks,
/// unless  the socket has been placed in nonblocking I/O mode.  In nonblocking mode it would fail
/// with `SendError.WouldBlock`.  The `select` call may be used  to  determine when it is
/// possible to send more data.
pub fn send(
    /// The file descriptor of the sending socket.
    sockfd: fd_t,
    buf: []const u8,
    flags: u32,
) SendError!usize {
    return sendto(sockfd, buf, flags, null, 0);
}

pub const PollError = error{
    /// The kernel had no space to allocate file descriptor tables.
    SystemResources,
} || UnexpectedError;

pub fn poll(fds: []pollfd, timeout: i32) PollError!usize {
    while (true) {
        const rc = system.poll(fds.ptr, fds.len, timeout);
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),
            EFAULT => unreachable,
            EINTR => continue,
            EINVAL => unreachable,
            ENOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const RecvFromError = error{
    /// The socket is marked nonblocking and the requested operation would block, and
    /// there is no global event loop configured.
    WouldBlock,

    /// A remote host refused to allow the network connection, typically because it is not
    /// running the requested service.
    ConnectionRefused,

    /// Could not allocate kernel memory.
    SystemResources,
} || UnexpectedError;

pub fn recvfrom(
    sockfd: fd_t,
    buf: []u8,
    flags: u32,
    src_addr: ?*sockaddr,
    addrlen: ?*socklen_t,
) RecvFromError!usize {
    while (true) {
        const rc = system.recvfrom(sockfd, buf.ptr, buf.len, flags, src_addr, addrlen);
        switch (errno(rc)) {
            0 => return @intCast(usize, rc),
            EBADF => unreachable, // always a race condition
            EFAULT => unreachable,
            EINVAL => unreachable,
            ENOTCONN => unreachable,
            ENOTSOCK => unreachable,
            EINTR => continue,
            EAGAIN => if (std.event.Loop.instance) |loop| {
                loop.waitUntilFdReadable(sockfd);
                continue;
            } else {
                return error.WouldBlock;
            },
            ENOMEM => return error.SystemResources,
            ECONNREFUSED => return error.ConnectionRefused,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const DnExpandError = error{InvalidDnsPacket};

pub fn dn_expand(
    msg: []const u8,
    comp_dn: []const u8,
    exp_dn: []u8,
) DnExpandError!usize {
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var p = comp_dn.ptr;
    var len: usize = std.math.maxInt(usize);
    const end = msg.ptr + msg.len;
    if (p == end or exp_dn.len == 0) return error.InvalidDnsPacket;
    var dest = exp_dn.ptr;
    const dend = dest + std.math.min(exp_dn.len, 254);
    // detect reference loop using an iteration counter
    var i: usize = 0;
    while (i < msg.len) : (i += 2) {
        // loop invariants: p<end, dest<dend
        if ((p[0] & 0xc0) != 0) {
            if (p + 1 == end) return error.InvalidDnsPacket;
            var j = ((p[0] & @as(usize, 0x3f)) << 8) | p[1];
            if (len == std.math.maxInt(usize)) len = @ptrToInt(p) + 2 - @ptrToInt(comp_dn.ptr);
            if (j >= msg.len) return error.InvalidDnsPacket;
            p = msg.ptr + j;
        } else if (p[0] != 0) {
            if (dest != exp_dn.ptr) {
                dest.* = '.';
                dest += 1;
            }
            var j = p[0];
            p += 1;
            if (j >= @ptrToInt(end) - @ptrToInt(p) or j >= @ptrToInt(dend) - @ptrToInt(dest)) {
                return error.InvalidDnsPacket;
            }
            while (j != 0) {
                j -= 1;
                dest.* = p[0];
                dest += 1;
                p += 1;
            }
        } else {
            dest.* = 0;
            if (len == std.math.maxInt(usize)) len = @ptrToInt(p) + 1 - @ptrToInt(comp_dn.ptr);
            return len;
        }
    }
    return error.InvalidDnsPacket;
}

pub const SchedYieldError = error{
    /// The system is not configured to allow yielding
    SystemCannotYield,
};

pub fn sched_yield() SchedYieldError!void {
    if (builtin.os == .windows) {
        // The return value has to do with how many other threads there are; it is not
        // an error condition on Windows.
        _ = windows.kernel32.SwitchToThread();
        return;
    }
    switch (errno(system.sched_yield())) {
        0 => return,
        ENOSYS => return error.SystemCannotYield,
        else => return error.SystemCannotYield,
    }
}
