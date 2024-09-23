//! POSIX API layer.
//!
//! This is more cross platform than using OS-specific APIs, however, it is
//! lower-level and less portable than other namespaces such as `std.fs` and
//! `std.process`.
//!
//! These APIs are generally lowered to libc function calls if and only if libc
//! is linked. Most operating systems other than Windows, Linux, and WASI
//! require always linking libc because they use it as the stable syscall ABI.
//!
//! Operating systems that are not POSIX-compliant are sometimes supported by
//! this API layer; sometimes not. Generally, an implementation will be
//! provided only if such implementation is straightforward on that operating
//! system. Otherwise, programmers are expected to use OS-specific logic to
//! deal with the exception.

const builtin = @import("builtin");
const root = @import("root");
const std = @import("std.zig");
const mem = std.mem;
const fs = std.fs;
const max_path_bytes = fs.max_path_bytes;
const maxInt = std.math.maxInt;
const cast = std.math.cast;
const assert = std.debug.assert;
const native_os = builtin.os.tag;

test {
    _ = @import("posix/test.zig");
}

/// Whether to use libc for the POSIX API layer.
const use_libc = builtin.link_libc or switch (native_os) {
    .windows, .wasi => true,
    else => false,
};

const linux = std.os.linux;
const windows = std.os.windows;
const wasi = std.os.wasi;

/// A libc-compatible API layer.
pub const system = if (use_libc)
    std.c
else switch (native_os) {
    .linux => linux,
    .plan9 => std.os.plan9,
    else => struct {
        pub const ucontext_t = void;
        pub const pid_t = void;
        pub const pollfd = void;
        pub const fd_t = void;
        pub const uid_t = void;
        pub const gid_t = void;
    },
};

pub const AF = system.AF;
pub const AF_SUN = system.AF_SUN;
pub const AI = system.AI;
pub const ARCH = system.ARCH;
pub const AT = system.AT;
pub const AT_SUN = system.AT_SUN;
pub const CLOCK = system.CLOCK;
pub const CPU_COUNT = system.CPU_COUNT;
pub const CTL = system.CTL;
pub const DT = system.DT;
pub const E = system.E;
pub const Elf_Symndx = system.Elf_Symndx;
pub const F = system.F;
pub const FD_CLOEXEC = system.FD_CLOEXEC;
pub const Flock = system.Flock;
pub const HOST_NAME_MAX = system.HOST_NAME_MAX;
pub const HW = system.HW;
pub const IFNAMESIZE = system.IFNAMESIZE;
pub const IOV_MAX = system.IOV_MAX;
pub const IPPROTO = system.IPPROTO;
pub const KERN = system.KERN;
pub const Kevent = system.Kevent;
pub const MADV = system.MADV;
pub const MAP = system.MAP;
pub const MAX_ADDR_LEN = system.MAX_ADDR_LEN;
pub const MFD = system.MFD;
pub const MMAP2_UNIT = system.MMAP2_UNIT;
pub const MSF = system.MSF;
pub const MSG = system.MSG;
pub const NAME_MAX = system.NAME_MAX;
pub const O = system.O;
pub const PATH_MAX = system.PATH_MAX;
pub const POLL = system.POLL;
pub const POSIX_FADV = system.POSIX_FADV;
pub const PR = system.PR;
pub const PROT = system.PROT;
pub const REG = system.REG;
pub const RLIM = system.RLIM;
pub const RR = system.RR;
pub const S = system.S;
pub const SA = system.SA;
pub const SC = system.SC;
pub const SEEK = system.SEEK;
pub const SHUT = system.SHUT;
pub const SIG = system.SIG;
pub const SIOCGIFINDEX = system.SIOCGIFINDEX;
pub const SO = system.SO;
pub const SOCK = system.SOCK;
pub const SOL = system.SOL;
pub const STDERR_FILENO = system.STDERR_FILENO;
pub const STDIN_FILENO = system.STDIN_FILENO;
pub const STDOUT_FILENO = system.STDOUT_FILENO;
pub const SYS = system.SYS;
pub const Sigaction = system.Sigaction;
pub const Stat = system.Stat;
pub const T = system.T;
pub const TCP = system.TCP;
pub const VDSO = system.VDSO;
pub const W = system.W;
pub const _SC = system._SC;
pub const addrinfo = system.addrinfo;
pub const blkcnt_t = system.blkcnt_t;
pub const blksize_t = system.blksize_t;
pub const clock_t = system.clock_t;
pub const clockid_t = system.clockid_t;
pub const cpu_set_t = system.cpu_set_t;
pub const dev_t = system.dev_t;
pub const dl_phdr_info = system.dl_phdr_info;
pub const empty_sigset = system.empty_sigset;
pub const fd_t = system.fd_t;
pub const file_obj = system.file_obj;
pub const filled_sigset = system.filled_sigset;
pub const gid_t = system.gid_t;
pub const ifreq = system.ifreq;
pub const ino_t = system.ino_t;
pub const mcontext_t = system.mcontext_t;
pub const mode_t = system.mode_t;
pub const msghdr = system.msghdr;
pub const msghdr_const = system.msghdr_const;
pub const nfds_t = system.nfds_t;
pub const nlink_t = system.nlink_t;
pub const off_t = system.off_t;
pub const pid_t = system.pid_t;
pub const pollfd = system.pollfd;
pub const port_event = system.port_event;
pub const port_notify = system.port_notify;
pub const port_t = system.port_t;
pub const rlim_t = system.rlim_t;
pub const rlimit = system.rlimit;
pub const rlimit_resource = system.rlimit_resource;
pub const rusage = system.rusage;
pub const sa_family_t = system.sa_family_t;
pub const siginfo_t = system.siginfo_t;
pub const sigset_t = system.sigset_t;
pub const sockaddr = system.sockaddr;
pub const socklen_t = system.socklen_t;
pub const stack_t = system.stack_t;
pub const time_t = system.time_t;
pub const timespec = system.timespec;
pub const timestamp_t = system.timestamp_t;
pub const timeval = system.timeval;
pub const timezone = system.timezone;
pub const ucontext_t = system.ucontext_t;
pub const uid_t = system.uid_t;
pub const user_desc = system.user_desc;
pub const utsname = system.utsname;

pub const termios = system.termios;
pub const CSIZE = system.CSIZE;
pub const NCCS = system.NCCS;
pub const cc_t = system.cc_t;
pub const V = system.V;
pub const speed_t = system.speed_t;
pub const tc_iflag_t = system.tc_iflag_t;
pub const tc_oflag_t = system.tc_oflag_t;
pub const tc_cflag_t = system.tc_cflag_t;
pub const tc_lflag_t = system.tc_lflag_t;

pub const F_OK = system.F_OK;
pub const R_OK = system.R_OK;
pub const W_OK = system.W_OK;
pub const X_OK = system.X_OK;

pub const iovec = extern struct {
    base: [*]u8,
    len: usize,
};

pub const iovec_const = extern struct {
    base: [*]const u8,
    len: usize,
};

pub const ACCMODE = enum(u2) {
    RDONLY = 0,
    WRONLY = 1,
    RDWR = 2,
};

pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const winsize = extern struct {
    row: u16,
    col: u16,
    xpixel: u16,
    ypixel: u16,
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const LOG = struct {
    /// system is unusable
    pub const EMERG = 0;
    /// action must be taken immediately
    pub const ALERT = 1;
    /// critical conditions
    pub const CRIT = 2;
    /// error conditions
    pub const ERR = 3;
    /// warning conditions
    pub const WARNING = 4;
    /// normal but significant condition
    pub const NOTICE = 5;
    /// informational
    pub const INFO = 6;
    /// debug-level messages
    pub const DEBUG = 7;
};

pub const socket_t = if (native_os == .windows) windows.ws2_32.SOCKET else fd_t;

/// Obtains errno from the return value of a system function call.
///
/// For some systems this will obtain the value directly from the syscall return value;
/// for others it will use a thread-local errno variable. Therefore, this
/// function only returns a well-defined value when it is called directly after
/// the system function call whose errno value is intended to be observed.
pub fn errno(rc: anytype) E {
    if (use_libc) {
        return if (rc == -1) @enumFromInt(std.c._errno().*) else .SUCCESS;
    }
    const signed: isize = @bitCast(rc);
    const int = if (signed > -4096 and signed < 0) -signed else 0;
    return @enumFromInt(int);
}

/// Closes the file descriptor.
///
/// Asserts the file descriptor is open.
///
/// This function is not capable of returning any indication of failure. An
/// application which wants to ensure writes have succeeded before closing must
/// call `fsync` before `close`.
///
/// The Zig standard library does not support POSIX thread cancellation.
pub fn close(fd: fd_t) void {
    if (native_os == .windows) {
        return windows.CloseHandle(fd);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        _ = std.os.wasi.fd_close(fd);
        return;
    }
    switch (errno(system.close(fd))) {
        .BADF => unreachable, // Always a race condition.
        .INTR => return, // This is still a success. See https://github.com/ziglang/zig/issues/2425
        else => return,
    }
}

pub const FChmodError = error{
    AccessDenied,
    InputOutput,
    SymLinkLoop,
    FileNotFound,
    SystemResources,
    ReadOnlyFileSystem,
} || UnexpectedError;

/// Changes the mode of the file referred to by the file descriptor.
///
/// The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner
/// of the file.
pub fn fchmod(fd: fd_t, mode: mode_t) FChmodError!void {
    if (!fs.has_executable_bit) @compileError("fchmod unsupported by target OS");

    while (true) {
        const res = system.fchmod(fd, mode);
        switch (errno(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.FileNotFound,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const FChmodAtError = FChmodError || error{
    /// A component of `path` exceeded `NAME_MAX`, or the entire path exceeded
    /// `PATH_MAX`.
    NameTooLong,
    /// `path` resolves to a symbolic link, and `AT.SYMLINK_NOFOLLOW` was set
    /// in `flags`. This error only occurs on Linux, where changing the mode of
    /// a symbolic link has no meaning and can cause undefined behaviour on
    /// certain filesystems.
    ///
    /// The procfs fallback was used but procfs was not mounted.
    OperationNotSupported,
    /// The procfs fallback was used but the process exceeded its open file
    /// limit.
    ProcessFdQuotaExceeded,
    /// The procfs fallback was used but the system exceeded it open file limit.
    SystemFdQuotaExceeded,
};

/// Changes the `mode` of `path` relative to the directory referred to by
/// `dirfd`. The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner of the
/// file.
///
/// On Linux the `fchmodat2` syscall will be used if available, otherwise a
/// workaround using procfs will be employed. Changing the mode of a symbolic
/// link with `AT.SYMLINK_NOFOLLOW` set will also return
/// `OperationNotSupported`, as:
///
///  1. Permissions on the link are ignored when resolving its target.
///  2. This operation has been known to invoke undefined behaviour across
///     different filesystems[1].
///
/// [1]: https://sourceware.org/legacy-ml/libc-alpha/2020-02/msg00467.html.
pub inline fn fchmodat(dirfd: fd_t, path: []const u8, mode: mode_t, flags: u32) FChmodAtError!void {
    if (!fs.has_executable_bit) @compileError("fchmodat unsupported by target OS");

    // No special handling for linux is needed if we can use the libc fallback
    // or `flags` is empty. Glibc only added the fallback in 2.32.
    const skip_fchmodat_fallback = native_os != .linux or
        std.c.versionCheck(.{ .major = 2, .minor = 32, .patch = 0 }) or
        flags == 0;

    // This function is marked inline so that when flags is comptime-known,
    // skip_fchmodat_fallback will be comptime-known true.
    if (skip_fchmodat_fallback)
        return fchmodat1(dirfd, path, mode, flags);

    return fchmodat2(dirfd, path, mode, flags);
}

fn fchmodat1(dirfd: fd_t, path: []const u8, mode: mode_t, flags: u32) FChmodAtError!void {
    const path_c = try toPosixPath(path);
    while (true) {
        const res = system.fchmodat(dirfd, &path_c, mode, flags);
        switch (errno(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .OPNOTSUPP => return error.OperationNotSupported,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
}

fn fchmodat2(dirfd: fd_t, path: []const u8, mode: mode_t, flags: u32) FChmodAtError!void {
    const global = struct {
        var has_fchmodat2: bool = true;
    };
    const path_c = try toPosixPath(path);
    const use_fchmodat2 = (builtin.os.isAtLeast(.linux, .{ .major = 6, .minor = 6, .patch = 0 }) orelse false) and
        @atomicLoad(bool, &global.has_fchmodat2, .monotonic);
    while (use_fchmodat2) {
        // Later on this should be changed to `system.fchmodat2`
        // when the musl/glibc add a wrapper.
        const res = linux.fchmodat2(dirfd, &path_c, mode, flags);
        switch (E.init(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.FileNotFound,
            .OPNOTSUPP => return error.OperationNotSupported,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,

            .NOSYS => {
                @atomicStore(bool, &global.has_fchmodat2, false, .monotonic);
                break;
            },
            else => |err| return unexpectedErrno(err),
        }
    }

    // Fallback to changing permissions using procfs:
    //
    // 1. Open `path` as a `PATH` descriptor.
    // 2. Stat the fd and check if it isn't a symbolic link.
    // 3. Generate the procfs reference to the fd via `/proc/self/fd/{fd}`.
    // 4. Pass the procfs path to `chmod` with the `mode`.
    var pathfd: fd_t = undefined;
    while (true) {
        const rc = system.openat(dirfd, &path_c, .{ .PATH = true, .NOFOLLOW = true, .CLOEXEC = true }, @as(mode_t, 0));
        switch (errno(rc)) {
            .SUCCESS => {
                pathfd = @intCast(rc);
                break;
            },
            .INTR => continue,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .PERM => return error.AccessDenied,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
    defer close(pathfd);

    const stat = fstatatZ(pathfd, "", AT.EMPTY_PATH) catch |err| switch (err) {
        error.NameTooLong => unreachable,
        error.FileNotFound => unreachable,
        error.InvalidUtf8 => unreachable,
        else => |e| return e,
    };
    if ((stat.mode & S.IFMT) == S.IFLNK)
        return error.OperationNotSupported;

    var procfs_buf: ["/proc/self/fd/-2147483648\x00".len]u8 = undefined;
    const proc_path = std.fmt.bufPrintZ(procfs_buf[0..], "/proc/self/fd/{d}", .{pathfd}) catch unreachable;
    while (true) {
        const res = system.chmod(proc_path, mode);
        switch (errno(res)) {
            // Getting NOENT here means that procfs isn't mounted.
            .NOENT => return error.OperationNotSupported,

            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.SymLinkLoop,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.FileNotFound,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const FChownError = error{
    AccessDenied,
    InputOutput,
    SymLinkLoop,
    FileNotFound,
    SystemResources,
    ReadOnlyFileSystem,
} || UnexpectedError;

/// Changes the owner and group of the file referred to by the file descriptor.
/// The process must have the correct privileges in order to do this
/// successfully. The group may be changed by the owner of the directory to
/// any group of which the owner is a member. If the owner or group is
/// specified as `null`, the ID is not changed.
pub fn fchown(fd: fd_t, owner: ?uid_t, group: ?gid_t) FChownError!void {
    switch (native_os) {
        .windows, .wasi => @compileError("Unsupported OS"),
        else => {},
    }

    while (true) {
        const res = system.fchown(fd, owner orelse ~@as(uid_t, 0), group orelse ~@as(gid_t, 0));

        switch (errno(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable, // Can be reached if the fd refers to a directory opened without `Dir.OpenOptions{ .iterate = true }`

            .FAULT => unreachable,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .IO => return error.InputOutput,
            .LOOP => return error.SymLinkLoop,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.FileNotFound,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const RebootError = error{
    PermissionDenied,
} || UnexpectedError;

pub const RebootCommand = switch (native_os) {
    .linux => union(linux.LINUX_REBOOT.CMD) {
        RESTART: void,
        HALT: void,
        CAD_ON: void,
        CAD_OFF: void,
        POWER_OFF: void,
        RESTART2: [*:0]const u8,
        SW_SUSPEND: void,
        KEXEC: void,
    },
    else => @compileError("Unsupported OS"),
};

pub fn reboot(cmd: RebootCommand) RebootError!void {
    switch (native_os) {
        .linux => {
            switch (linux.E.init(linux.reboot(
                .MAGIC1,
                .MAGIC2,
                cmd,
                switch (cmd) {
                    .RESTART2 => |s| s,
                    else => null,
                },
            ))) {
                .SUCCESS => {},
                .PERM => return error.PermissionDenied,
                else => |err| return std.posix.unexpectedErrno(err),
            }
            switch (cmd) {
                .CAD_OFF => {},
                .CAD_ON => {},
                .SW_SUSPEND => {},

                .HALT => unreachable,
                .KEXEC => unreachable,
                .POWER_OFF => unreachable,
                .RESTART => unreachable,
                .RESTART2 => unreachable,
            }
        },
        else => @compileError("Unsupported OS"),
    }
}

pub const GetRandomError = OpenError;

/// Obtain a series of random bytes. These bytes can be used to seed user-space
/// random number generators or for cryptographic purposes.
/// When linking against libc, this calls the
/// appropriate OS-specific library call. Otherwise it uses the zig standard
/// library implementation.
pub fn getrandom(buffer: []u8) GetRandomError!void {
    if (native_os == .windows) {
        return windows.RtlGenRandom(buffer);
    }
    if (builtin.link_libc and @TypeOf(system.arc4random_buf) != void) {
        system.arc4random_buf(buffer.ptr, buffer.len);
        return;
    }
    if (native_os == .wasi) switch (wasi.random_get(buffer.ptr, buffer.len)) {
        .SUCCESS => return,
        else => |err| return unexpectedErrno(err),
    };
    if (@TypeOf(system.getrandom) != void) {
        var buf = buffer;
        const use_c = native_os != .linux or
            std.c.versionCheck(std.SemanticVersion{ .major = 2, .minor = 25, .patch = 0 });

        while (buf.len != 0) {
            const num_read: usize, const err = if (use_c) res: {
                const rc = std.c.getrandom(buf.ptr, buf.len, 0);
                break :res .{ @bitCast(rc), errno(rc) };
            } else res: {
                const rc = linux.getrandom(buf.ptr, buf.len, 0);
                break :res .{ rc, linux.E.init(rc) };
            };

            switch (err) {
                .SUCCESS => buf = buf[num_read..],
                .INVAL => unreachable,
                .FAULT => unreachable,
                .INTR => continue,
                else => return unexpectedErrno(err),
            }
        }
        return;
    }
    if (native_os == .emscripten) {
        const err = errno(std.c.getentropy(buffer.ptr, buffer.len));
        switch (err) {
            .SUCCESS => return,
            else => return unexpectedErrno(err),
        }
    }
    return getRandomBytesDevURandom(buffer);
}

fn getRandomBytesDevURandom(buf: []u8) !void {
    const fd = try openZ("/dev/urandom", .{ .ACCMODE = .RDONLY, .CLOEXEC = true }, 0);
    defer close(fd);

    const st = try fstat(fd);
    if (!S.ISCHR(st.mode)) {
        return error.NoDevice;
    }

    const file: fs.File = .{ .handle = fd };
    const stream = file.reader();
    stream.readNoEof(buf) catch return error.Unexpected;
}

/// Causes abnormal process termination.
/// If linking against libc, this calls the abort() libc function. Otherwise
/// it raises SIGABRT followed by SIGKILL and finally lo
/// Invokes the current signal handler for SIGABRT, if any.
pub fn abort() noreturn {
    @branchHint(.cold);
    // MSVCRT abort() sometimes opens a popup window which is undesirable, so
    // even when linking libc on Windows we use our own abort implementation.
    // See https://github.com/ziglang/zig/issues/2071 for more details.
    if (native_os == .windows) {
        if (builtin.mode == .Debug) {
            @breakpoint();
        }
        windows.kernel32.ExitProcess(3);
    }
    if (!builtin.link_libc and native_os == .linux) {
        // The Linux man page says that the libc abort() function
        // "first unblocks the SIGABRT signal", but this is a footgun
        // for user-defined signal handlers that want to restore some state in
        // some program sections and crash in others.
        // So, the user-installed SIGABRT handler is run, if present.
        raise(SIG.ABRT) catch {};

        // Disable all signal handlers.
        sigprocmask(SIG.BLOCK, &linux.all_mask, null);

        // Only one thread may proceed to the rest of abort().
        if (!builtin.single_threaded) {
            const global = struct {
                var abort_entered: bool = false;
            };
            while (@cmpxchgWeak(bool, &global.abort_entered, false, true, .seq_cst, .seq_cst)) |_| {}
        }

        // Install default handler so that the tkill below will terminate.
        const sigact = Sigaction{
            .handler = .{ .handler = SIG.DFL },
            .mask = empty_sigset,
            .flags = 0,
        };
        sigaction(SIG.ABRT, &sigact, null);

        _ = linux.tkill(linux.gettid(), SIG.ABRT);

        const sigabrtmask: linux.sigset_t = [_]u32{0} ** 31 ++ [_]u32{1 << (SIG.ABRT - 1)};
        sigprocmask(SIG.UNBLOCK, &sigabrtmask, null);

        // Beyond this point should be unreachable.
        @as(*allowzero volatile u8, @ptrFromInt(0)).* = 0;
        raise(SIG.KILL) catch {};
        exit(127); // Pid 1 might not be signalled in some containers.
    }
    switch (native_os) {
        .uefi, .wasi, .emscripten, .cuda, .amdhsa => @trap(),
        else => system.abort(),
    }
}

pub const RaiseError = UnexpectedError;

pub fn raise(sig: u8) RaiseError!void {
    if (builtin.link_libc) {
        switch (errno(system.raise(sig))) {
            .SUCCESS => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    if (native_os == .linux) {
        var set: sigset_t = undefined;
        // block application signals
        sigprocmask(SIG.BLOCK, &linux.app_mask, &set);

        const tid = linux.gettid();
        const rc = linux.tkill(tid, sig);

        // restore signal mask
        sigprocmask(SIG.SETMASK, &set, null);

        switch (errno(rc)) {
            .SUCCESS => return,
            else => |err| return unexpectedErrno(err),
        }
    }

    @compileError("std.posix.raise unimplemented for this target");
}

pub const KillError = error{ ProcessNotFound, PermissionDenied } || UnexpectedError;

pub fn kill(pid: pid_t, sig: u8) KillError!void {
    switch (errno(system.kill(pid, sig))) {
        .SUCCESS => return,
        .INVAL => unreachable, // invalid signal
        .PERM => return error.PermissionDenied,
        .SRCH => return error.ProcessNotFound,
        else => |err| return unexpectedErrno(err),
    }
}

/// Exits all threads of the program with the specified status code.
pub fn exit(status: u8) noreturn {
    if (builtin.link_libc) {
        std.c.exit(status);
    }
    if (native_os == .windows) {
        windows.kernel32.ExitProcess(status);
    }
    if (native_os == .wasi) {
        wasi.proc_exit(status);
    }
    if (native_os == .linux and !builtin.single_threaded) {
        linux.exit_group(status);
    }
    if (native_os == .uefi) {
        const uefi = std.os.uefi;
        // exit() is only available if exitBootServices() has not been called yet.
        // This call to exit should not fail, so we don't care about its return value.
        if (uefi.system_table.boot_services) |bs| {
            _ = bs.exit(uefi.handle, @enumFromInt(status), 0, null);
        }
        // If we can't exit, reboot the system instead.
        uefi.system_table.runtime_services.resetSystem(.ResetCold, @enumFromInt(status), 0, null);
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
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,

    /// This error occurs when no global event loop is configured,
    /// and reading from the file descriptor would block.
    WouldBlock,

    /// reading a timerfd with CANCEL_ON_SET will lead to this error
    /// when the clock goes through a discontinuous change
    Canceled,

    /// In WASI, this error occurs when the file descriptor does
    /// not hold the required rights to read from it.
    AccessDenied,

    /// This error occurs in Linux if the process to be read from
    /// no longer exists.
    ProcessNotFound,

    /// Unable to read file due to lock.
    LockViolation,
} || UnexpectedError;

/// Returns the number of bytes that were read, which can be less than
/// buf.len. If 0 bytes were read, that means EOF.
/// If `fd` is opened in non blocking mode, the function will return error.WouldBlock
/// when EAGAIN is received.
///
/// Linux has a limit on how many bytes may be transferred in one `read` call, which is `0x7ffff000`
/// on both 64-bit and 32-bit systems. This is due to using a signed C int as the return value, as
/// well as stuffing the errno codes into the last `4096` values. This is noted on the `read` man page.
/// The limit on Darwin is `0x7fffffff`, trying to read more than that returns EINVAL.
/// The corresponding POSIX limit is `maxInt(isize)`.
pub fn read(fd: fd_t, buf: []u8) ReadError!usize {
    if (buf.len == 0) return 0;
    if (native_os == .windows) {
        return windows.ReadFile(fd, buf, null);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        const iovs = [1]iovec{iovec{
            .base = buf.ptr,
            .len = buf.len,
        }};

        var nread: usize = undefined;
        switch (wasi.fd_read(fd, &iovs, iovs.len, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForReading, // Can be a race condition.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Prevents EINVAL.
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),
        else => maxInt(isize),
    };
    while (true) {
        const rc = system.read(fd, buf.ptr, @min(buf.len, max_count));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .CANCELED => return error.Canceled,
            .BADF => return error.NotOpenForReading, // Can be a race condition.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// This operation is non-atomic on the following systems:
/// * Windows
/// On these systems, the read races with concurrent writes to the same file descriptor.
///
/// This function assumes that all vectors, including zero-length vectors, have
/// a pointer within the address space of the application.
pub fn readv(fd: fd_t, iov: []const iovec) ReadError!usize {
    if (native_os == .windows) {
        // TODO improve this to use ReadFileScatter
        if (iov.len == 0) return 0;
        const first = iov[0];
        return read(fd, first.base[0..first.len]);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var nread: usize = undefined;
        switch (wasi.fd_read(fd, iov.ptr, iov.len, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable, // currently not support in WASI
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    while (true) {
        const rc = system.readv(fd, iov.ptr, @min(iov.len, IOV_MAX));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const PReadError = ReadError || error{Unseekable};

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
///
/// Retries when interrupted by a signal.
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// Linux has a limit on how many bytes may be transferred in one `pread` call, which is `0x7ffff000`
/// on both 64-bit and 32-bit systems. This is due to using a signed C int as the return value, as
/// well as stuffing the errno codes into the last `4096` values. This is noted on the `read` man page.
/// The limit on Darwin is `0x7fffffff`, trying to read more than that returns EINVAL.
/// The corresponding POSIX limit is `maxInt(isize)`.
pub fn pread(fd: fd_t, buf: []u8, offset: u64) PReadError!usize {
    if (buf.len == 0) return 0;
    if (native_os == .windows) {
        return windows.ReadFile(fd, buf, offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        const iovs = [1]iovec{iovec{
            .base = buf.ptr,
            .len = buf.len,
        }};

        var nread: usize = undefined;
        switch (wasi.fd_pread(fd, &iovs, iovs.len, offset, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForReading, // Can be a race condition.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Prevent EINVAL.
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),
        else => maxInt(isize),
    };

    const pread_sym = if (lfs64_abi) system.pread64 else system.pread;
    while (true) {
        const rc = pread_sym(fd, buf.ptr, @min(buf.len, max_count), @bitCast(offset));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // Can be a race condition.
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const TruncateError = error{
    FileTooBig,
    InputOutput,
    FileBusy,

    /// In WASI, this error occurs when the file descriptor does
    /// not hold the required rights to call `ftruncate` on it.
    AccessDenied,
} || UnexpectedError;

pub fn ftruncate(fd: fd_t, length: u64) TruncateError!void {
    if (native_os == .windows) {
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;
        var eof_info = windows.FILE_END_OF_FILE_INFORMATION{
            .EndOfFile = @bitCast(length),
        };

        const rc = windows.ntdll.NtSetInformationFile(
            fd,
            &io_status_block,
            &eof_info,
            @sizeOf(windows.FILE_END_OF_FILE_INFORMATION),
            .FileEndOfFileInformation,
        );

        switch (rc) {
            .SUCCESS => return,
            .INVALID_HANDLE => unreachable, // Handle not open for writing
            .ACCESS_DENIED => return error.AccessDenied,
            else => return windows.unexpectedStatus(rc),
        }
    }
    if (native_os == .wasi and !builtin.link_libc) {
        switch (wasi.fd_filestat_set_size(fd, length)) {
            .SUCCESS => return,
            .INTR => unreachable,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .PERM => return error.AccessDenied,
            .TXTBSY => return error.FileBusy,
            .BADF => unreachable, // Handle not open for writing
            .INVAL => unreachable, // Handle not open for writing
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    const ftruncate_sym = if (lfs64_abi) system.ftruncate64 else system.ftruncate;
    while (true) {
        switch (errno(ftruncate_sym(fd, @bitCast(length)))) {
            .SUCCESS => return,
            .INTR => continue,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .PERM => return error.AccessDenied,
            .TXTBSY => return error.FileBusy,
            .BADF => unreachable, // Handle not open for writing
            .INVAL => unreachable, // Handle not open for writing
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Number of bytes read is returned. Upon reading end-of-file, zero is returned.
///
/// Retries when interrupted by a signal.
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// This operation is non-atomic on the following systems:
/// * Darwin
/// * Windows
/// On these systems, the read races with concurrent writes to the same file descriptor.
pub fn preadv(fd: fd_t, iov: []const iovec, offset: u64) PReadError!usize {
    const have_pread_but_not_preadv = switch (native_os) {
        .windows, .macos, .ios, .watchos, .tvos, .visionos, .haiku => true,
        else => false,
    };
    if (have_pread_but_not_preadv) {
        // We could loop here; but proper usage of `preadv` must handle partial reads anyway.
        // So we simply read into the first vector only.
        if (iov.len == 0) return 0;
        const first = iov[0];
        return pread(fd, first.base[0..first.len], offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var nread: usize = undefined;
        switch (wasi.fd_pread(fd, iov.ptr, iov.len, offset, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    const preadv_sym = if (lfs64_abi) system.preadv64 else system.preadv;
    while (true) {
        const rc = preadv_sym(fd, iov.ptr, @min(iov.len, IOV_MAX), @bitCast(offset));
        switch (errno(rc)) {
            .SUCCESS => return @bitCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const WriteError = error{
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    DeviceBusy,
    InvalidArgument,

    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to write to it.
    AccessDenied,
    BrokenPipe,
    SystemResources,
    OperationAborted,
    NotOpenForWriting,

    /// The process cannot access the file because another process has locked
    /// a portion of the file. Windows-only.
    LockViolation,

    /// This error occurs when no global event loop is configured,
    /// and reading from the file descriptor would block.
    WouldBlock,

    /// Connection reset by peer.
    ConnectionResetByPeer,

    /// This error occurs in Linux if the process being written to
    /// no longer exists.
    ProcessNotFound,
} || UnexpectedError;

/// Write to a file descriptor.
/// Retries when interrupted by a signal.
/// Returns the number of bytes written. If nonzero bytes were supplied, this will be nonzero.
///
/// Note that a successful write() may transfer fewer than count bytes.  Such partial  writes  can
/// occur  for  various reasons; for example, because there was insufficient space on the disk
/// device to write all of the requested bytes, or because a blocked write() to a socket,  pipe,  or
/// similar  was  interrupted by a signal handler after it had transferred some, but before it had
/// transferred all of the requested bytes.  In the event of a partial write, the caller can  make
/// another  write() call to transfer the remaining bytes.  The subsequent call will either
/// transfer further bytes or may result in an error (e.g., if the disk is now full).
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// Linux has a limit on how many bytes may be transferred in one `write` call, which is `0x7ffff000`
/// on both 64-bit and 32-bit systems. This is due to using a signed C int as the return value, as
/// well as stuffing the errno codes into the last `4096` values. This is noted on the `write` man page.
/// The limit on Darwin is `0x7fffffff`, trying to read more than that returns EINVAL.
/// The corresponding POSIX limit is `maxInt(isize)`.
pub fn write(fd: fd_t, bytes: []const u8) WriteError!usize {
    if (bytes.len == 0) return 0;
    if (native_os == .windows) {
        return windows.WriteFile(fd, bytes, null);
    }

    if (native_os == .wasi and !builtin.link_libc) {
        const ciovs = [_]iovec_const{iovec_const{
            .base = bytes.ptr,
            .len = bytes.len,
        }};
        var nwritten: usize = undefined;
        switch (wasi.fd_write(fd, &ciovs, ciovs.len, &nwritten)) {
            .SUCCESS => return nwritten,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),
        else => maxInt(isize),
    };
    while (true) {
        const rc = system.write(fd, bytes.ptr, @min(bytes.len, max_count));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .CONNRESET => return error.ConnectionResetByPeer,
            .BUSY => return error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Write multiple buffers to a file descriptor.
/// Retries when interrupted by a signal.
/// Returns the number of bytes written. If nonzero bytes were supplied, this will be nonzero.
///
/// Note that a successful write() may transfer fewer bytes than supplied.  Such partial  writes  can
/// occur  for  various reasons; for example, because there was insufficient space on the disk
/// device to write all of the requested bytes, or because a blocked write() to a socket,  pipe,  or
/// similar  was  interrupted by a signal handler after it had transferred some, but before it had
/// transferred all of the requested bytes.  In the event of a partial write, the caller can  make
/// another  write() call to transfer the remaining bytes.  The subsequent call will either
/// transfer further bytes or may result in an error (e.g., if the disk is now full).
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// If `iov.len` is larger than `IOV_MAX`, a partial write will occur.
///
/// This function assumes that all vectors, including zero-length vectors, have
/// a pointer within the address space of the application.
pub fn writev(fd: fd_t, iov: []const iovec_const) WriteError!usize {
    if (native_os == .windows) {
        // TODO improve this to use WriteFileScatter
        if (iov.len == 0) return 0;
        const first = iov[0];
        return write(fd, first.base[0..first.len]);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var nwritten: usize = undefined;
        switch (wasi.fd_write(fd, iov.ptr, iov.len, &nwritten)) {
            .SUCCESS => return nwritten,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    while (true) {
        const rc = system.writev(fd, iov.ptr, @min(iov.len, IOV_MAX));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // Can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .CONNRESET => return error.ConnectionResetByPeer,
            .BUSY => return error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const PWriteError = WriteError || error{Unseekable};

/// Write to a file descriptor, with a position offset.
/// Retries when interrupted by a signal.
/// Returns the number of bytes written. If nonzero bytes were supplied, this will be nonzero.
///
/// Note that a successful write() may transfer fewer bytes than supplied.  Such partial  writes  can
/// occur  for  various reasons; for example, because there was insufficient space on the disk
/// device to write all of the requested bytes, or because a blocked write() to a socket,  pipe,  or
/// similar  was  interrupted by a signal handler after it had transferred some, but before it had
/// transferred all of the requested bytes.  In the event of a partial write, the caller can  make
/// another  write() call to transfer the remaining bytes.  The subsequent call will either
/// transfer further bytes or may result in an error (e.g., if the disk is now full).
///
/// For POSIX systems, if `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
/// On Windows, if the application has a global event loop enabled, I/O Completion Ports are
/// used to perform the I/O. `error.WouldBlock` is not possible on Windows.
///
/// Linux has a limit on how many bytes may be transferred in one `pwrite` call, which is `0x7ffff000`
/// on both 64-bit and 32-bit systems. This is due to using a signed C int as the return value, as
/// well as stuffing the errno codes into the last `4096` values. This is noted on the `write` man page.
/// The limit on Darwin is `0x7fffffff`, trying to write more than that returns EINVAL.
/// The corresponding POSIX limit is `maxInt(isize)`.
pub fn pwrite(fd: fd_t, bytes: []const u8, offset: u64) PWriteError!usize {
    if (bytes.len == 0) return 0;
    if (native_os == .windows) {
        return windows.WriteFile(fd, bytes, offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        const ciovs = [1]iovec_const{iovec_const{
            .base = bytes.ptr,
            .len = bytes.len,
        }};

        var nwritten: usize = undefined;
        switch (wasi.fd_pwrite(fd, &ciovs, ciovs.len, offset, &nwritten)) {
            .SUCCESS => return nwritten,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForWriting, // can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    // Prevent EINVAL.
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),
        else => maxInt(isize),
    };

    const pwrite_sym = if (lfs64_abi) system.pwrite64 else system.pwrite;
    while (true) {
        const rc = pwrite_sym(fd, bytes.ptr, @min(bytes.len, max_count), @bitCast(offset));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // Can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .BUSY => return error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Write multiple buffers to a file descriptor, with a position offset.
/// Retries when interrupted by a signal.
/// Returns the number of bytes written. If nonzero bytes were supplied, this will be nonzero.
///
/// Note that a successful write() may transfer fewer than count bytes.  Such partial  writes  can
/// occur  for  various reasons; for example, because there was insufficient space on the disk
/// device to write all of the requested bytes, or because a blocked write() to a socket,  pipe,  or
/// similar  was  interrupted by a signal handler after it had transferred some, but before it had
/// transferred all of the requested bytes.  In the event of a partial write, the caller can  make
/// another  write() call to transfer the remaining bytes.  The subsequent call will either
/// transfer further bytes or may result in an error (e.g., if the disk is now full).
///
/// If `fd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
///
/// The following systems do not have this syscall, and will return partial writes if more than one
/// vector is provided:
/// * Darwin
/// * Windows
///
/// If `iov.len` is larger than `IOV_MAX`, a partial write will occur.
pub fn pwritev(fd: fd_t, iov: []const iovec_const, offset: u64) PWriteError!usize {
    const have_pwrite_but_not_pwritev = switch (native_os) {
        .windows, .macos, .ios, .watchos, .tvos, .visionos, .haiku => true,
        else => false,
    };

    if (have_pwrite_but_not_pwritev) {
        // We could loop here; but proper usage of `pwritev` must handle partial writes anyway.
        // So we simply write the first vector only.
        if (iov.len == 0) return 0;
        const first = iov[0];
        return pwrite(fd, first.base[0..first.len], offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var nwritten: usize = undefined;
        switch (wasi.fd_pwrite(fd, iov.ptr, iov.len, offset, &nwritten)) {
            .SUCCESS => return nwritten,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => unreachable,
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForWriting, // Can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    const pwritev_sym = if (lfs64_abi) system.pwritev64 else system.pwritev;
    while (true) {
        const rc = pwritev_sym(fd, iov.ptr, @min(iov.len, IOV_MAX), @bitCast(offset));
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => return error.InvalidArgument,
            .FAULT => unreachable,
            .NOENT => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForWriting, // Can be a race condition.
            .DESTADDRREQ => unreachable, // `connect` was never called.
            .DQUOT => return error.DiskQuota,
            .FBIG => return error.FileTooBig,
            .IO => return error.InputOutput,
            .NOSPC => return error.NoSpaceLeft,
            .PERM => return error.AccessDenied,
            .PIPE => return error.BrokenPipe,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .BUSY => return error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const OpenError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to open a new resource relative to it.
    AccessDenied,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    FileNotFound,

    /// The path exceeded `max_path_bytes` bytes.
    NameTooLong,

    /// Insufficient kernel memory was available, or
    /// the named file is a FIFO and per-user hard limit on
    /// memory allocation for pipes has been reached.
    SystemResources,

    /// The file is too large to be opened. This error is unreachable
    /// for 64-bit targets, as well as when opening directories.
    FileTooBig,

    /// The path refers to directory but the `DIRECTORY` flag was not provided.
    IsDir,

    /// A new path cannot be created because the device has no room for the new file.
    /// This error is only reachable when the `CREAT` flag is provided.
    NoSpaceLeft,

    /// A component used as a directory in the path was not, in fact, a directory, or
    /// `DIRECTORY` was specified and the path was not a directory.
    NotDir,

    /// The path already exists and the `CREAT` and `EXCL` flags were provided.
    PathAlreadyExists,
    DeviceBusy,

    /// The underlying filesystem does not support file locks
    FileLocksNotSupported,

    /// Path contains characters that are disallowed by the underlying filesystem.
    BadPathName,

    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,

    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,

    /// One of these three things:
    /// * pathname  refers to an executable image which is currently being
    ///   executed and write access was requested.
    /// * pathname refers to a file that is currently in  use  as  a  swap
    ///   file, and the O_TRUNC flag was specified.
    /// * pathname  refers  to  a file that is currently being read by the
    ///   kernel (e.g., for module/firmware loading), and write access was
    ///   requested.
    FileBusy,

    WouldBlock,
} || UnexpectedError;

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// See also `openZ`.
pub fn open(file_path: []const u8, flags: O, perm: mode_t) OpenError!fd_t {
    if (native_os == .windows) {
        @compileError("Windows does not support POSIX; use Windows-specific API or cross-platform std.fs API");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return openat(AT.FDCWD, file_path, flags, perm);
    }
    const file_path_c = try toPosixPath(file_path);
    return openZ(&file_path_c, flags, perm);
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// See also `open`.
pub fn openZ(file_path: [*:0]const u8, flags: O, perm: mode_t) OpenError!fd_t {
    if (native_os == .windows) {
        @compileError("Windows does not support POSIX; use Windows-specific API or cross-platform std.fs API");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return open(mem.sliceTo(file_path, 0), flags, perm);
    }

    const open_sym = if (lfs64_abi) system.open64 else system.open;
    while (true) {
        const rc = open_sym(file_path, flags, perm);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,

            .FAULT => unreachable,
            .INVAL => return error.BadPathName,
            .ACCES => return error.AccessDenied,
            .FBIG => return error.FileTooBig,
            .OVERFLOW => return error.FileTooBig,
            .ISDIR => return error.IsDir,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .PERM => return error.AccessDenied,
            .EXIST => return error.PathAlreadyExists,
            .BUSY => return error.DeviceBusy,
            .ILSEQ => |err| if (native_os == .wasi)
                return error.InvalidUtf8
            else
                return unexpectedErrno(err),
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// `file_path` is relative to the open directory handle `dir_fd`.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// See also `openatZ`.
pub fn openat(dir_fd: fd_t, file_path: []const u8, flags: O, mode: mode_t) OpenError!fd_t {
    if (native_os == .windows) {
        @compileError("Windows does not support POSIX; use Windows-specific API or cross-platform std.fs API");
    } else if (native_os == .wasi and !builtin.link_libc) {
        // `mode` is ignored on WASI, which does not support unix-style file permissions
        const opts = try openOptionsFromFlagsWasi(flags);
        const fd = try openatWasi(
            dir_fd,
            file_path,
            opts.lookup_flags,
            opts.oflags,
            opts.fs_flags,
            opts.fs_rights_base,
            opts.fs_rights_inheriting,
        );
        errdefer close(fd);

        if (flags.write) {
            const info = try std.os.fstat_wasi(fd);
            if (info.filetype == .DIRECTORY)
                return error.IsDir;
        }

        return fd;
    }
    const file_path_c = try toPosixPath(file_path);
    return openatZ(dir_fd, &file_path_c, flags, mode);
}

/// Open and possibly create a file in WASI.
pub fn openatWasi(
    dir_fd: fd_t,
    file_path: []const u8,
    lookup_flags: wasi.lookupflags_t,
    oflags: wasi.oflags_t,
    fdflags: wasi.fdflags_t,
    base: wasi.rights_t,
    inheriting: wasi.rights_t,
) OpenError!fd_t {
    while (true) {
        var fd: fd_t = undefined;
        switch (wasi.path_open(dir_fd, lookup_flags, file_path.ptr, file_path.len, oflags, base, inheriting, fdflags, &fd)) {
            .SUCCESS => return fd,
            .INTR => continue,

            .FAULT => unreachable,
            // Provides INVAL with a linux host on a bad path name, but NOENT on Windows
            .INVAL => return error.BadPathName,
            .BADF => unreachable,
            .ACCES => return error.AccessDenied,
            .FBIG => return error.FileTooBig,
            .OVERFLOW => return error.FileTooBig,
            .ISDIR => return error.IsDir,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .PERM => return error.AccessDenied,
            .EXIST => return error.PathAlreadyExists,
            .BUSY => return error.DeviceBusy,
            .NOTCAPABLE => return error.AccessDenied,
            .ILSEQ => return error.InvalidUtf8,
            else => |err| return unexpectedErrno(err),
        }
    }
}

/// A struct to contain all lookup/rights flags accepted by `wasi.path_open`
const WasiOpenOptions = struct {
    oflags: wasi.oflags_t,
    lookup_flags: wasi.lookupflags_t,
    fs_rights_base: wasi.rights_t,
    fs_rights_inheriting: wasi.rights_t,
    fs_flags: wasi.fdflags_t,
};

/// Compute rights + flags corresponding to the provided POSIX access mode.
fn openOptionsFromFlagsWasi(oflag: O) OpenError!WasiOpenOptions {
    const w = std.os.wasi;

    // Next, calculate the read/write rights to request, depending on the
    // provided POSIX access mode
    var rights: w.rights_t = .{};
    if (oflag.read) {
        rights.FD_READ = true;
        rights.FD_READDIR = true;
    }
    if (oflag.write) {
        rights.FD_DATASYNC = true;
        rights.FD_WRITE = true;
        rights.FD_ALLOCATE = true;
        rights.FD_FILESTAT_SET_SIZE = true;
    }

    // https://github.com/ziglang/zig/issues/18882
    const flag_bits: u32 = @bitCast(oflag);
    const oflags_int: u16 = @as(u12, @truncate(flag_bits >> 12));
    const fs_flags_int: u16 = @as(u12, @truncate(flag_bits));

    return .{
        // https://github.com/ziglang/zig/issues/18882
        .oflags = @bitCast(oflags_int),
        .lookup_flags = .{
            .SYMLINK_FOLLOW = !oflag.NOFOLLOW,
        },
        .fs_rights_base = rights,
        .fs_rights_inheriting = rights,
        // https://github.com/ziglang/zig/issues/18882
        .fs_flags = @bitCast(fs_flags_int),
    };
}

/// Open and possibly create a file. Keeps trying if it gets interrupted.
/// `file_path` is relative to the open directory handle `dir_fd`.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// See also `openat`.
pub fn openatZ(dir_fd: fd_t, file_path: [*:0]const u8, flags: O, mode: mode_t) OpenError!fd_t {
    if (native_os == .windows) {
        @compileError("Windows does not support POSIX; use Windows-specific API or cross-platform std.fs API");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return openat(dir_fd, mem.sliceTo(file_path, 0), flags, mode);
    }

    const openat_sym = if (lfs64_abi) system.openat64 else system.openat;
    while (true) {
        const rc = openat_sym(dir_fd, file_path, flags, mode);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,

            .FAULT => unreachable,
            .INVAL => return error.BadPathName,
            .BADF => unreachable,
            .ACCES => return error.AccessDenied,
            .FBIG => return error.FileTooBig,
            .OVERFLOW => return error.FileTooBig,
            .ISDIR => return error.IsDir,
            .LOOP => return error.SymLinkLoop,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NODEV => return error.NoDevice,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .PERM => return error.AccessDenied,
            .EXIST => return error.PathAlreadyExists,
            .BUSY => return error.DeviceBusy,
            .OPNOTSUPP => return error.FileLocksNotSupported,
            .AGAIN => return error.WouldBlock,
            .TXTBSY => return error.FileBusy,
            .ILSEQ => |err| if (native_os == .wasi)
                return error.InvalidUtf8
            else
                return unexpectedErrno(err),
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn dup(old_fd: fd_t) !fd_t {
    const rc = system.dup(old_fd);
    return switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .MFILE => error.ProcessFdQuotaExceeded,
        .BADF => unreachable, // invalid file descriptor
        else => |err| return unexpectedErrno(err),
    };
}

pub fn dup2(old_fd: fd_t, new_fd: fd_t) !void {
    while (true) {
        switch (errno(system.dup2(old_fd, new_fd))) {
            .SUCCESS => return,
            .BUSY, .INTR => continue,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .INVAL => unreachable, // invalid parameters passed to dup2
            .BADF => unreachable, // invalid file descriptor
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

/// This function ignores PATH environment variable. See `execvpeZ` for that.
pub fn execveZ(
    path: [*:0]const u8,
    child_argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) ExecveError {
    switch (errno(system.execve(path, child_argv, envp))) {
        .SUCCESS => unreachable,
        .FAULT => unreachable,
        .@"2BIG" => return error.SystemResources,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .INVAL => return error.InvalidExe,
        .NOEXEC => return error.InvalidExe,
        .IO => return error.FileSystem,
        .LOOP => return error.FileSystem,
        .ISDIR => return error.IsDir,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .TXTBSY => return error.FileBusy,
        else => |err| switch (native_os) {
            .macos, .ios, .tvos, .watchos, .visionos => switch (err) {
                .BADEXEC => return error.InvalidExe,
                .BADARCH => return error.InvalidExe,
                else => return unexpectedErrno(err),
            },
            .linux => switch (err) {
                .LIBBAD => return error.InvalidExe,
                else => return unexpectedErrno(err),
            },
            else => return unexpectedErrno(err),
        },
    }
}

pub const Arg0Expand = enum {
    expand,
    no_expand,
};

/// Like `execvpeZ` except if `arg0_expand` is `.expand`, then `argv` is mutable,
/// and `argv[0]` is expanded to be the same absolute path that is passed to the execve syscall.
/// If this function returns with an error, `argv[0]` will be restored to the value it was when it was passed in.
pub fn execvpeZ_expandArg0(
    comptime arg0_expand: Arg0Expand,
    file: [*:0]const u8,
    child_argv: switch (arg0_expand) {
        .expand => [*:null]?[*:0]const u8,
        .no_expand => [*:null]const ?[*:0]const u8,
    },
    envp: [*:null]const ?[*:0]const u8,
) ExecveError {
    const file_slice = mem.sliceTo(file, 0);
    if (mem.indexOfScalar(u8, file_slice, '/') != null) return execveZ(file, child_argv, envp);

    const PATH = getenvZ("PATH") orelse "/usr/local/bin:/bin/:/usr/bin";
    // Use of PATH_MAX here is valid as the path_buf will be passed
    // directly to the operating system in execveZ.
    var path_buf: [PATH_MAX]u8 = undefined;
    var it = mem.tokenizeScalar(u8, PATH, ':');
    var seen_eacces = false;
    var err: ExecveError = error.FileNotFound;

    // In case of expanding arg0 we must put it back if we return with an error.
    const prev_arg0 = child_argv[0];
    defer switch (arg0_expand) {
        .expand => child_argv[0] = prev_arg0,
        .no_expand => {},
    };

    while (it.next()) |search_path| {
        const path_len = search_path.len + file_slice.len + 1;
        if (path_buf.len < path_len + 1) return error.NameTooLong;
        @memcpy(path_buf[0..search_path.len], search_path);
        path_buf[search_path.len] = '/';
        @memcpy(path_buf[search_path.len + 1 ..][0..file_slice.len], file_slice);
        path_buf[path_len] = 0;
        const full_path = path_buf[0..path_len :0].ptr;
        switch (arg0_expand) {
            .expand => child_argv[0] = full_path,
            .no_expand => {},
        }
        err = execveZ(full_path, child_argv, envp);
        switch (err) {
            error.AccessDenied => seen_eacces = true,
            error.FileNotFound, error.NotDir => {},
            else => |e| return e,
        }
    }
    if (seen_eacces) return error.AccessDenied;
    return err;
}

/// This function also uses the PATH environment variable to get the full path to the executable.
/// If `file` is an absolute path, this is the same as `execveZ`.
pub fn execvpeZ(
    file: [*:0]const u8,
    argv_ptr: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) ExecveError {
    return execvpeZ_expandArg0(.no_expand, file, argv_ptr, envp);
}

/// Get an environment variable.
/// See also `getenvZ`.
pub fn getenv(key: []const u8) ?[:0]const u8 {
    if (native_os == .windows) {
        @compileError("std.posix.getenv is unavailable for Windows because environment strings are in WTF-16 format. See std.process.getEnvVarOwned for a cross-platform API or std.process.getenvW for a Windows-specific API.");
    }
    if (builtin.link_libc) {
        var ptr = std.c.environ;
        while (ptr[0]) |line| : (ptr += 1) {
            var line_i: usize = 0;
            while (line[line_i] != 0 and line[line_i] != '=') : (line_i += 1) {}
            const this_key = line[0..line_i];

            if (!mem.eql(u8, this_key, key)) continue;

            return mem.sliceTo(line + line_i + 1, 0);
        }
        return null;
    }
    if (native_os == .wasi) {
        @compileError("std.posix.getenv is unavailable for WASI. See std.process.getEnvMap or std.process.getEnvVarOwned for a cross-platform API.");
    }
    // The simplified start logic doesn't populate environ.
    if (std.start.simplified_logic) return null;
    // TODO see https://github.com/ziglang/zig/issues/4524
    for (std.os.environ) |ptr| {
        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '=') : (line_i += 1) {}
        const this_key = ptr[0..line_i];
        if (!mem.eql(u8, key, this_key)) continue;

        return mem.sliceTo(ptr + line_i + 1, 0);
    }
    return null;
}

/// Get an environment variable with a null-terminated name.
/// See also `getenv`.
pub fn getenvZ(key: [*:0]const u8) ?[:0]const u8 {
    if (builtin.link_libc) {
        const value = system.getenv(key) orelse return null;
        return mem.sliceTo(value, 0);
    }
    if (native_os == .windows) {
        @compileError("std.posix.getenvZ is unavailable for Windows because environment string is in WTF-16 format. See std.process.getEnvVarOwned for cross-platform API or std.process.getenvW for Windows-specific API.");
    }
    return getenv(mem.sliceTo(key, 0));
}

pub const GetCwdError = error{
    NameTooLong,
    CurrentWorkingDirectoryUnlinked,
} || UnexpectedError;

/// The result is a slice of out_buffer, indexed from 0.
pub fn getcwd(out_buffer: []u8) GetCwdError![]u8 {
    if (native_os == .windows) {
        return windows.GetCurrentDirectory(out_buffer);
    } else if (native_os == .wasi and !builtin.link_libc) {
        const path = ".";
        if (out_buffer.len < path.len) return error.NameTooLong;
        const result = out_buffer[0..path.len];
        @memcpy(result, path);
        return result;
    }

    const err: E = if (builtin.link_libc) err: {
        const c_err = if (std.c.getcwd(out_buffer.ptr, out_buffer.len)) |_| 0 else std.c._errno().*;
        break :err @enumFromInt(c_err);
    } else err: {
        break :err errno(system.getcwd(out_buffer.ptr, out_buffer.len));
    };
    switch (err) {
        .SUCCESS => return mem.sliceTo(out_buffer, 0),
        .FAULT => unreachable,
        .INVAL => unreachable,
        .NOENT => return error.CurrentWorkingDirectoryUnlinked,
        .RANGE => return error.NameTooLong,
        else => return unexpectedErrno(err),
    }
}

pub const SymLinkError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to create a new symbolic link relative to it.
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

    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,

    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    BadPathName,
} || UnexpectedError;

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
/// If `sym_link_path` exists, it will not be overwritten.
/// See also `symlinkZ.
pub fn symlink(target_path: []const u8, sym_link_path: []const u8) SymLinkError!void {
    if (native_os == .windows) {
        @compileError("symlink is not supported on Windows; use std.os.windows.CreateSymbolicLink instead");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return symlinkat(target_path, wasi.AT.FDCWD, sym_link_path);
    }
    const target_path_c = try toPosixPath(target_path);
    const sym_link_path_c = try toPosixPath(sym_link_path);
    return symlinkZ(&target_path_c, &sym_link_path_c);
}

/// This is the same as `symlink` except the parameters are null-terminated pointers.
/// See also `symlink`.
pub fn symlinkZ(target_path: [*:0]const u8, sym_link_path: [*:0]const u8) SymLinkError!void {
    if (native_os == .windows) {
        @compileError("symlink is not supported on Windows; use std.os.windows.CreateSymbolicLink instead");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return symlinkatZ(target_path, fs.cwd().fd, sym_link_path);
    }
    switch (errno(system.symlink(target_path, sym_link_path))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .ROFS => return error.ReadOnlyFileSystem,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Similar to `symlink`, however, creates a symbolic link named `sym_link_path` which contains the string
/// `target_path` **relative** to `newdirfd` directory handle.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
/// If `sym_link_path` exists, it will not be overwritten.
/// See also `symlinkatWasi`, `symlinkatZ` and `symlinkatW`.
pub fn symlinkat(target_path: []const u8, newdirfd: fd_t, sym_link_path: []const u8) SymLinkError!void {
    if (native_os == .windows) {
        @compileError("symlinkat is not supported on Windows; use std.os.windows.CreateSymbolicLink instead");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return symlinkatWasi(target_path, newdirfd, sym_link_path);
    }
    const target_path_c = try toPosixPath(target_path);
    const sym_link_path_c = try toPosixPath(sym_link_path);
    return symlinkatZ(&target_path_c, newdirfd, &sym_link_path_c);
}

/// WASI-only. The same as `symlinkat` but targeting WASI.
/// See also `symlinkat`.
pub fn symlinkatWasi(target_path: []const u8, newdirfd: fd_t, sym_link_path: []const u8) SymLinkError!void {
    switch (wasi.path_symlink(target_path.ptr, target_path.len, newdirfd, sym_link_path.ptr, sym_link_path.len)) {
        .SUCCESS => {},
        .FAULT => unreachable,
        .INVAL => unreachable,
        .BADF => unreachable,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .ROFS => return error.ReadOnlyFileSystem,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,
        else => |err| return unexpectedErrno(err),
    }
}

/// The same as `symlinkat` except the parameters are null-terminated pointers.
/// See also `symlinkat`.
pub fn symlinkatZ(target_path: [*:0]const u8, newdirfd: fd_t, sym_link_path: [*:0]const u8) SymLinkError!void {
    if (native_os == .windows) {
        @compileError("symlinkat is not supported on Windows; use std.os.windows.CreateSymbolicLink instead");
    } else if (native_os == .wasi and !builtin.link_libc) {
        return symlinkat(mem.sliceTo(target_path, 0), newdirfd, mem.sliceTo(sym_link_path, 0));
    }
    switch (errno(system.symlinkat(target_path, newdirfd, sym_link_path))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .ROFS => return error.ReadOnlyFileSystem,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

pub const LinkError = UnexpectedError || error{
    AccessDenied,
    DiskQuota,
    PathAlreadyExists,
    FileSystem,
    SymLinkLoop,
    LinkQuotaExceeded,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NoSpaceLeft,
    ReadOnlyFileSystem,
    NotSameFileSystem,

    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
};

/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn linkZ(oldpath: [*:0]const u8, newpath: [*:0]const u8) LinkError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return link(mem.sliceTo(oldpath, 0), mem.sliceTo(newpath, 0));
    }
    switch (errno(system.link(oldpath, newpath))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .FAULT => unreachable,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .PERM => return error.AccessDenied,
        .ROFS => return error.ReadOnlyFileSystem,
        .XDEV => return error.NotSameFileSystem,
        .INVAL => unreachable,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn link(oldpath: []const u8, newpath: []const u8) LinkError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return linkat(wasi.AT.FDCWD, oldpath, wasi.AT.FDCWD, newpath, 0) catch |err| switch (err) {
            error.NotDir => unreachable, // link() does not support directories
            else => |e| return e,
        };
    }
    const old = try toPosixPath(oldpath);
    const new = try toPosixPath(newpath);
    return try linkZ(&old, &new);
}

pub const LinkatError = LinkError || error{NotDir};

/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn linkatZ(
    olddir: fd_t,
    oldpath: [*:0]const u8,
    newdir: fd_t,
    newpath: [*:0]const u8,
    flags: i32,
) LinkatError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return linkat(olddir, mem.sliceTo(oldpath, 0), newdir, mem.sliceTo(newpath, 0), flags);
    }
    switch (errno(system.linkat(olddir, oldpath, newdir, newpath, flags))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .FAULT => unreachable,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .PERM => return error.AccessDenied,
        .ROFS => return error.ReadOnlyFileSystem,
        .XDEV => return error.NotSameFileSystem,
        .INVAL => unreachable,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn linkat(
    olddir: fd_t,
    oldpath: []const u8,
    newdir: fd_t,
    newpath: []const u8,
    flags: i32,
) LinkatError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        const old: RelativePathWasi = .{ .dir_fd = olddir, .relative_path = oldpath };
        const new: RelativePathWasi = .{ .dir_fd = newdir, .relative_path = newpath };
        const old_flags: wasi.lookupflags_t = .{
            .SYMLINK_FOLLOW = (flags & AT.SYMLINK_FOLLOW) != 0,
        };
        switch (wasi.path_link(
            old.dir_fd,
            old_flags,
            old.relative_path.ptr,
            old.relative_path.len,
            new.dir_fd,
            new.relative_path.ptr,
            new.relative_path.len,
        )) {
            .SUCCESS => return,
            .ACCES => return error.AccessDenied,
            .DQUOT => return error.DiskQuota,
            .EXIST => return error.PathAlreadyExists,
            .FAULT => unreachable,
            .IO => return error.FileSystem,
            .LOOP => return error.SymLinkLoop,
            .MLINK => return error.LinkQuotaExceeded,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOSPC => return error.NoSpaceLeft,
            .NOTDIR => return error.NotDir,
            .PERM => return error.AccessDenied,
            .ROFS => return error.ReadOnlyFileSystem,
            .XDEV => return error.NotSameFileSystem,
            .INVAL => unreachable,
            .ILSEQ => return error.InvalidUtf8,
            else => |err| return unexpectedErrno(err),
        }
    }
    const old = try toPosixPath(oldpath);
    const new = try toPosixPath(newpath);
    return try linkatZ(olddir, &old, newdir, &new, flags);
}

pub const UnlinkError = error{
    FileNotFound,

    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to unlink a resource by path relative to it.
    AccessDenied,
    FileBusy,
    FileSystem,
    IsDir,
    SymLinkLoop,
    NameTooLong,
    NotDir,
    SystemResources,
    ReadOnlyFileSystem,

    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,

    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || UnexpectedError;

/// Delete a name and possibly the file it refers to.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// See also `unlinkZ`.
pub fn unlink(file_path: []const u8) UnlinkError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return unlinkat(wasi.AT.FDCWD, file_path, 0) catch |err| switch (err) {
            error.DirNotEmpty => unreachable, // only occurs when targeting directories
            else => |e| return e,
        };
    } else if (native_os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(null, file_path);
        return unlinkW(file_path_w.span());
    } else {
        const file_path_c = try toPosixPath(file_path);
        return unlinkZ(&file_path_c);
    }
}

/// Same as `unlink` except the parameter is null terminated.
pub fn unlinkZ(file_path: [*:0]const u8) UnlinkError!void {
    if (native_os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(null, file_path);
        return unlinkW(file_path_w.span());
    } else if (native_os == .wasi and !builtin.link_libc) {
        return unlink(mem.sliceTo(file_path, 0));
    }
    switch (errno(system.unlink(file_path))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .IO => return error.FileSystem,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .ROFS => return error.ReadOnlyFileSystem,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `unlink` except the parameter is null-terminated, WTF16 LE encoded.
pub fn unlinkW(file_path_w: []const u16) UnlinkError!void {
    windows.DeleteFile(file_path_w, .{ .dir = fs.cwd().fd }) catch |err| switch (err) {
        error.DirNotEmpty => unreachable, // we're not passing .remove_dir = true
        else => |e| return e,
    };
}

pub const UnlinkatError = UnlinkError || error{
    /// When passing `AT.REMOVEDIR`, this error occurs when the named directory is not empty.
    DirNotEmpty,
};

/// Delete a file name and possibly the file it refers to, based on an open directory handle.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// Asserts that the path parameter has no null bytes.
pub fn unlinkat(dirfd: fd_t, file_path: []const u8, flags: u32) UnlinkatError!void {
    if (native_os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(dirfd, file_path);
        return unlinkatW(dirfd, file_path_w.span(), flags);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return unlinkatWasi(dirfd, file_path, flags);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return unlinkatZ(dirfd, &file_path_c, flags);
    }
}

/// WASI-only. Same as `unlinkat` but targeting WASI.
/// See also `unlinkat`.
pub fn unlinkatWasi(dirfd: fd_t, file_path: []const u8, flags: u32) UnlinkatError!void {
    const remove_dir = (flags & AT.REMOVEDIR) != 0;
    const res = if (remove_dir)
        wasi.path_remove_directory(dirfd, file_path.ptr, file_path.len)
    else
        wasi.path_unlink_file(dirfd, file_path.ptr, file_path.len);
    switch (res) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .FAULT => unreachable,
        .IO => return error.FileSystem,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .ROFS => return error.ReadOnlyFileSystem,
        .NOTEMPTY => return error.DirNotEmpty,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,

        .INVAL => unreachable, // invalid flags, or pathname has . as last component
        .BADF => unreachable, // always a race condition

        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `unlinkat` but `file_path` is a null-terminated string.
pub fn unlinkatZ(dirfd: fd_t, file_path_c: [*:0]const u8, flags: u32) UnlinkatError!void {
    if (native_os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(dirfd, file_path_c);
        return unlinkatW(dirfd, file_path_w.span(), flags);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return unlinkat(dirfd, mem.sliceTo(file_path_c, 0), flags);
    }
    switch (errno(system.unlinkat(dirfd, file_path_c, flags))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .FAULT => unreachable,
        .IO => return error.FileSystem,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .ROFS => return error.ReadOnlyFileSystem,
        .EXIST => return error.DirNotEmpty,
        .NOTEMPTY => return error.DirNotEmpty,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),

        .INVAL => unreachable, // invalid flags, or pathname has . as last component
        .BADF => unreachable, // always a race condition

        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `unlinkat` but `sub_path_w` is WTF16LE, NT prefixed. Windows only.
pub fn unlinkatW(dirfd: fd_t, sub_path_w: []const u16, flags: u32) UnlinkatError!void {
    const remove_dir = (flags & AT.REMOVEDIR) != 0;
    return windows.DeleteFile(sub_path_w, .{ .dir = dirfd, .remove_dir = remove_dir });
}

pub const RenameError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to rename a resource by path relative to it.
    ///
    /// On Windows, this error may be returned instead of PathAlreadyExists when
    /// renaming a directory over an existing directory.
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
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    NoDevice,
    SharingViolation,
    PipeBusy,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
    /// On Windows, antivirus software is enabled by default. It can be
    /// disabled, but Windows Update sometimes ignores the user's preference
    /// and re-enables it. When enabled, antivirus software on Windows
    /// intercepts file system operations and makes them significantly slower
    /// in addition to possibly failing with this error code.
    AntivirusInterference,
} || UnexpectedError;

/// Change the name or location of a file.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn rename(old_path: []const u8, new_path: []const u8) RenameError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return renameat(wasi.AT.FDCWD, old_path, wasi.AT.FDCWD, new_path);
    } else if (native_os == .windows) {
        const old_path_w = try windows.sliceToPrefixedFileW(null, old_path);
        const new_path_w = try windows.sliceToPrefixedFileW(null, new_path);
        return renameW(old_path_w.span().ptr, new_path_w.span().ptr);
    } else {
        const old_path_c = try toPosixPath(old_path);
        const new_path_c = try toPosixPath(new_path);
        return renameZ(&old_path_c, &new_path_c);
    }
}

/// Same as `rename` except the parameters are null-terminated.
pub fn renameZ(old_path: [*:0]const u8, new_path: [*:0]const u8) RenameError!void {
    if (native_os == .windows) {
        const old_path_w = try windows.cStrToPrefixedFileW(null, old_path);
        const new_path_w = try windows.cStrToPrefixedFileW(null, new_path);
        return renameW(old_path_w.span().ptr, new_path_w.span().ptr);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return rename(mem.sliceTo(old_path, 0), mem.sliceTo(new_path, 0));
    }
    switch (errno(system.rename(old_path, new_path))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .DQUOT => return error.DiskQuota,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .EXIST => return error.PathAlreadyExists,
        .NOTEMPTY => return error.PathAlreadyExists,
        .ROFS => return error.ReadOnlyFileSystem,
        .XDEV => return error.RenameAcrossMountPoints,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `rename` except the parameters are null-terminated and WTF16LE encoded.
/// Assumes target is Windows.
pub fn renameW(old_path: [*:0]const u16, new_path: [*:0]const u16) RenameError!void {
    const flags = windows.MOVEFILE_REPLACE_EXISTING | windows.MOVEFILE_WRITE_THROUGH;
    return windows.MoveFileExW(old_path, new_path, flags);
}

/// Change the name or location of a file based on an open directory handle.
/// On Windows, both paths should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, both paths should be encoded as valid UTF-8.
/// On other platforms, both paths are an opaque sequence of bytes with no particular encoding.
pub fn renameat(
    old_dir_fd: fd_t,
    old_path: []const u8,
    new_dir_fd: fd_t,
    new_path: []const u8,
) RenameError!void {
    if (native_os == .windows) {
        const old_path_w = try windows.sliceToPrefixedFileW(old_dir_fd, old_path);
        const new_path_w = try windows.sliceToPrefixedFileW(new_dir_fd, new_path);
        return renameatW(old_dir_fd, old_path_w.span(), new_dir_fd, new_path_w.span(), windows.TRUE);
    } else if (native_os == .wasi and !builtin.link_libc) {
        const old: RelativePathWasi = .{ .dir_fd = old_dir_fd, .relative_path = old_path };
        const new: RelativePathWasi = .{ .dir_fd = new_dir_fd, .relative_path = new_path };
        return renameatWasi(old, new);
    } else {
        const old_path_c = try toPosixPath(old_path);
        const new_path_c = try toPosixPath(new_path);
        return renameatZ(old_dir_fd, &old_path_c, new_dir_fd, &new_path_c);
    }
}

/// WASI-only. Same as `renameat` expect targeting WASI.
/// See also `renameat`.
fn renameatWasi(old: RelativePathWasi, new: RelativePathWasi) RenameError!void {
    switch (wasi.path_rename(old.dir_fd, old.relative_path.ptr, old.relative_path.len, new.dir_fd, new.relative_path.ptr, new.relative_path.len)) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .DQUOT => return error.DiskQuota,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .EXIST => return error.PathAlreadyExists,
        .NOTEMPTY => return error.PathAlreadyExists,
        .ROFS => return error.ReadOnlyFileSystem,
        .XDEV => return error.RenameAcrossMountPoints,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,
        else => |err| return unexpectedErrno(err),
    }
}

/// An fd-relative file path
///
/// This is currently only used for WASI-specific functionality, but the concept
/// is the same as the dirfd/pathname pairs in the `*at(...)` POSIX functions.
const RelativePathWasi = struct {
    /// Handle to directory
    dir_fd: fd_t,
    /// Path to resource within `dir_fd`.
    relative_path: []const u8,
};

/// Same as `renameat` except the parameters are null-terminated.
pub fn renameatZ(
    old_dir_fd: fd_t,
    old_path: [*:0]const u8,
    new_dir_fd: fd_t,
    new_path: [*:0]const u8,
) RenameError!void {
    if (native_os == .windows) {
        const old_path_w = try windows.cStrToPrefixedFileW(old_dir_fd, old_path);
        const new_path_w = try windows.cStrToPrefixedFileW(new_dir_fd, new_path);
        return renameatW(old_dir_fd, old_path_w.span(), new_dir_fd, new_path_w.span(), windows.TRUE);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return renameat(old_dir_fd, mem.sliceTo(old_path, 0), new_dir_fd, mem.sliceTo(new_path, 0));
    }

    switch (errno(system.renameat(old_dir_fd, old_path, new_dir_fd, new_path))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .DQUOT => return error.DiskQuota,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ISDIR => return error.IsDir,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .EXIST => return error.PathAlreadyExists,
        .NOTEMPTY => return error.PathAlreadyExists,
        .ROFS => return error.ReadOnlyFileSystem,
        .XDEV => return error.RenameAcrossMountPoints,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `renameat` but Windows-only and the path parameters are
/// [WTF-16](https://simonsapin.github.io/wtf-8/#potentially-ill-formed-utf-16) encoded.
pub fn renameatW(
    old_dir_fd: fd_t,
    old_path_w: []const u16,
    new_dir_fd: fd_t,
    new_path_w: []const u16,
    ReplaceIfExists: windows.BOOLEAN,
) RenameError!void {
    const src_fd = windows.OpenFile(old_path_w, .{
        .dir = old_dir_fd,
        .access_mask = windows.SYNCHRONIZE | windows.GENERIC_WRITE | windows.DELETE,
        .creation = windows.FILE_OPEN,
        .filter = .any, // This function is supposed to rename both files and directories.
        .follow_symlinks = false,
    }) catch |err| switch (err) {
        error.WouldBlock => unreachable, // Not possible without `.share_access_nonblocking = true`.
        else => |e| return e,
    };
    defer windows.CloseHandle(src_fd);

    var need_fallback = true;
    var rc: windows.NTSTATUS = undefined;
    // FILE_RENAME_INFORMATION_EX and FILE_RENAME_POSIX_SEMANTICS require >= win10_rs1,
    // but FILE_RENAME_IGNORE_READONLY_ATTRIBUTE requires >= win10_rs5. We check >= rs5 here
    // so that we only use POSIX_SEMANTICS when we know IGNORE_READONLY_ATTRIBUTE will also be
    // supported in order to avoid either (1) using a redundant call that we can know in advance will return
    // STATUS_NOT_SUPPORTED or (2) only setting IGNORE_READONLY_ATTRIBUTE when >= rs5
    // and therefore having different behavior when the Windows version is >= rs1 but < rs5.
    if (builtin.target.os.isAtLeast(.windows, .win10_rs5) orelse false) {
        const struct_buf_len = @sizeOf(windows.FILE_RENAME_INFORMATION_EX) + (max_path_bytes - 1);
        var rename_info_buf: [struct_buf_len]u8 align(@alignOf(windows.FILE_RENAME_INFORMATION_EX)) = undefined;
        const struct_len = @sizeOf(windows.FILE_RENAME_INFORMATION_EX) - 1 + new_path_w.len * 2;
        if (struct_len > struct_buf_len) return error.NameTooLong;

        const rename_info: *windows.FILE_RENAME_INFORMATION_EX = @ptrCast(&rename_info_buf);
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;

        var flags: windows.ULONG = windows.FILE_RENAME_POSIX_SEMANTICS | windows.FILE_RENAME_IGNORE_READONLY_ATTRIBUTE;
        if (ReplaceIfExists == windows.TRUE) flags |= windows.FILE_RENAME_REPLACE_IF_EXISTS;
        rename_info.* = .{
            .Flags = flags,
            .RootDirectory = if (fs.path.isAbsoluteWindowsWTF16(new_path_w)) null else new_dir_fd,
            .FileNameLength = @intCast(new_path_w.len * 2), // already checked error.NameTooLong
            .FileName = undefined,
        };
        @memcpy((&rename_info.FileName).ptr, new_path_w);
        rc = windows.ntdll.NtSetInformationFile(
            src_fd,
            &io_status_block,
            rename_info,
            @intCast(struct_len), // already checked for error.NameTooLong
            .FileRenameInformationEx,
        );
        switch (rc) {
            .SUCCESS => return,
            // INVALID_PARAMETER here means that the filesystem does not support FileRenameInformationEx
            .INVALID_PARAMETER => {},
            // For all other statuses, fall down to the switch below to handle them.
            else => need_fallback = false,
        }
    }

    if (need_fallback) {
        const struct_buf_len = @sizeOf(windows.FILE_RENAME_INFORMATION) + (max_path_bytes - 1);
        var rename_info_buf: [struct_buf_len]u8 align(@alignOf(windows.FILE_RENAME_INFORMATION)) = undefined;
        const struct_len = @sizeOf(windows.FILE_RENAME_INFORMATION) - 1 + new_path_w.len * 2;
        if (struct_len > struct_buf_len) return error.NameTooLong;

        const rename_info: *windows.FILE_RENAME_INFORMATION = @ptrCast(&rename_info_buf);
        var io_status_block: windows.IO_STATUS_BLOCK = undefined;

        rename_info.* = .{
            .Flags = ReplaceIfExists,
            .RootDirectory = if (fs.path.isAbsoluteWindowsWTF16(new_path_w)) null else new_dir_fd,
            .FileNameLength = @intCast(new_path_w.len * 2), // already checked error.NameTooLong
            .FileName = undefined,
        };
        @memcpy((&rename_info.FileName).ptr, new_path_w);

        rc =
            windows.ntdll.NtSetInformationFile(
            src_fd,
            &io_status_block,
            rename_info,
            @intCast(struct_len), // already checked for error.NameTooLong
            .FileRenameInformation,
        );
    }

    switch (rc) {
        .SUCCESS => {},
        .INVALID_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        .OBJECT_PATH_SYNTAX_BAD => unreachable,
        .ACCESS_DENIED => return error.AccessDenied,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .NOT_SAME_DEVICE => return error.RenameAcrossMountPoints,
        .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
        .DIRECTORY_NOT_EMPTY => return error.PathAlreadyExists,
        .FILE_IS_A_DIRECTORY => return error.IsDir,
        .NOT_A_DIRECTORY => return error.NotDir,
        else => return windows.unexpectedStatus(rc),
    }
}

/// On Windows, `sub_dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `sub_dir_path` should be encoded as valid UTF-8.
/// On other platforms, `sub_dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn mkdirat(dir_fd: fd_t, sub_dir_path: []const u8, mode: u32) MakeDirError!void {
    if (native_os == .windows) {
        const sub_dir_path_w = try windows.sliceToPrefixedFileW(dir_fd, sub_dir_path);
        return mkdiratW(dir_fd, sub_dir_path_w.span(), mode);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return mkdiratWasi(dir_fd, sub_dir_path, mode);
    } else {
        const sub_dir_path_c = try toPosixPath(sub_dir_path);
        return mkdiratZ(dir_fd, &sub_dir_path_c, mode);
    }
}

pub fn mkdiratWasi(dir_fd: fd_t, sub_dir_path: []const u8, mode: u32) MakeDirError!void {
    _ = mode;
    switch (wasi.path_create_directory(dir_fd, sub_dir_path.ptr, sub_dir_path.len)) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .BADF => unreachable,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .FAULT => unreachable,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .ROFS => return error.ReadOnlyFileSystem,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,
        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `mkdirat` except the parameters are null-terminated.
pub fn mkdiratZ(dir_fd: fd_t, sub_dir_path: [*:0]const u8, mode: u32) MakeDirError!void {
    if (native_os == .windows) {
        const sub_dir_path_w = try windows.cStrToPrefixedFileW(dir_fd, sub_dir_path);
        return mkdiratW(dir_fd, sub_dir_path_w.span(), mode);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return mkdirat(dir_fd, mem.sliceTo(sub_dir_path, 0), mode);
    }
    switch (errno(system.mkdirat(dir_fd, sub_dir_path, mode))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .BADF => unreachable,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .FAULT => unreachable,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .ROFS => return error.ReadOnlyFileSystem,
        // dragonfly: when dir_fd is unlinked from filesystem
        .NOTCONN => return error.FileNotFound,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `mkdirat` except the parameter WTF16 LE encoded.
pub fn mkdiratW(dir_fd: fd_t, sub_path_w: []const u16, mode: u32) MakeDirError!void {
    _ = mode;
    const sub_dir_handle = windows.OpenFile(sub_path_w, .{
        .dir = dir_fd,
        .access_mask = windows.GENERIC_READ | windows.SYNCHRONIZE,
        .creation = windows.FILE_CREATE,
        .filter = .dir_only,
    }) catch |err| switch (err) {
        error.IsDir => return error.Unexpected,
        error.PipeBusy => return error.Unexpected,
        error.WouldBlock => return error.Unexpected,
        error.AntivirusInterference => return error.Unexpected,
        else => |e| return e,
    };
    windows.CloseHandle(sub_dir_handle);
}

pub const MakeDirError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to create a new directory relative to it.
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
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    NoDevice,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || UnexpectedError;

/// Create a directory.
/// `mode` is ignored on Windows and WASI.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn mkdir(dir_path: []const u8, mode: u32) MakeDirError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return mkdirat(wasi.AT.FDCWD, dir_path, mode);
    } else if (native_os == .windows) {
        const dir_path_w = try windows.sliceToPrefixedFileW(null, dir_path);
        return mkdirW(dir_path_w.span(), mode);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return mkdirZ(&dir_path_c, mode);
    }
}

/// Same as `mkdir` but the parameter is null-terminated.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn mkdirZ(dir_path: [*:0]const u8, mode: u32) MakeDirError!void {
    if (native_os == .windows) {
        const dir_path_w = try windows.cStrToPrefixedFileW(null, dir_path);
        return mkdirW(dir_path_w.span(), mode);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return mkdir(mem.sliceTo(dir_path, 0), mode);
    }
    switch (errno(system.mkdir(dir_path, mode))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .DQUOT => return error.DiskQuota,
        .EXIST => return error.PathAlreadyExists,
        .FAULT => unreachable,
        .LOOP => return error.SymLinkLoop,
        .MLINK => return error.LinkQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.NoSpaceLeft,
        .NOTDIR => return error.NotDir,
        .ROFS => return error.ReadOnlyFileSystem,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `mkdir` but the parameters is WTF16LE encoded.
pub fn mkdirW(dir_path_w: []const u16, mode: u32) MakeDirError!void {
    _ = mode;
    const sub_dir_handle = windows.OpenFile(dir_path_w, .{
        .dir = fs.cwd().fd,
        .access_mask = windows.GENERIC_READ | windows.SYNCHRONIZE,
        .creation = windows.FILE_CREATE,
        .filter = .dir_only,
    }) catch |err| switch (err) {
        error.IsDir => return error.Unexpected,
        error.PipeBusy => return error.Unexpected,
        error.WouldBlock => return error.Unexpected,
        error.AntivirusInterference => return error.Unexpected,
        else => |e| return e,
    };
    windows.CloseHandle(sub_dir_handle);
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
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || UnexpectedError;

/// Deletes an empty directory.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn rmdir(dir_path: []const u8) DeleteDirError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        return unlinkat(wasi.AT.FDCWD, dir_path, AT.REMOVEDIR) catch |err| switch (err) {
            error.FileSystem => unreachable, // only occurs when targeting files
            error.IsDir => unreachable, // only occurs when targeting files
            else => |e| return e,
        };
    } else if (native_os == .windows) {
        const dir_path_w = try windows.sliceToPrefixedFileW(null, dir_path);
        return rmdirW(dir_path_w.span());
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return rmdirZ(&dir_path_c);
    }
}

/// Same as `rmdir` except the parameter is null-terminated.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn rmdirZ(dir_path: [*:0]const u8) DeleteDirError!void {
    if (native_os == .windows) {
        const dir_path_w = try windows.cStrToPrefixedFileW(null, dir_path);
        return rmdirW(dir_path_w.span());
    } else if (native_os == .wasi and !builtin.link_libc) {
        return rmdir(mem.sliceTo(dir_path, 0));
    }
    switch (errno(system.rmdir(dir_path))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .BUSY => return error.FileBusy,
        .FAULT => unreachable,
        .INVAL => return error.BadPathName,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTDIR => return error.NotDir,
        .EXIST => return error.DirNotEmpty,
        .NOTEMPTY => return error.DirNotEmpty,
        .ROFS => return error.ReadOnlyFileSystem,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `rmdir` except the parameter is WTF-16 LE encoded.
pub fn rmdirW(dir_path_w: []const u16) DeleteDirError!void {
    return windows.DeleteFile(dir_path_w, .{ .dir = fs.cwd().fd, .remove_dir = true }) catch |err| switch (err) {
        error.IsDir => unreachable,
        else => |e| return e,
    };
}

pub const ChangeCurDirError = error{
    AccessDenied,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NotDir,
    BadPathName,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
} || UnexpectedError;

/// Changes the current working directory of the calling process.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn chdir(dir_path: []const u8) ChangeCurDirError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        @compileError("WASI does not support os.chdir");
    } else if (native_os == .windows) {
        var wtf16_dir_path: [windows.PATH_MAX_WIDE]u16 = undefined;
        if (try std.unicode.checkWtf8ToWtf16LeOverflow(dir_path, &wtf16_dir_path)) {
            return error.NameTooLong;
        }
        const len = try std.unicode.wtf8ToWtf16Le(&wtf16_dir_path, dir_path);
        return chdirW(wtf16_dir_path[0..len]);
    } else {
        const dir_path_c = try toPosixPath(dir_path);
        return chdirZ(&dir_path_c);
    }
}

/// Same as `chdir` except the parameter is null-terminated.
/// On Windows, `dir_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `dir_path` should be encoded as valid UTF-8.
/// On other platforms, `dir_path` is an opaque sequence of bytes with no particular encoding.
pub fn chdirZ(dir_path: [*:0]const u8) ChangeCurDirError!void {
    if (native_os == .windows) {
        const dir_path_span = mem.span(dir_path);
        var wtf16_dir_path: [windows.PATH_MAX_WIDE]u16 = undefined;
        if (try std.unicode.checkWtf8ToWtf16LeOverflow(dir_path_span, &wtf16_dir_path)) {
            return error.NameTooLong;
        }
        const len = try std.unicode.wtf8ToWtf16Le(&wtf16_dir_path, dir_path_span);
        return chdirW(wtf16_dir_path[0..len]);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return chdir(mem.span(dir_path));
    }
    switch (errno(system.chdir(dir_path))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .FAULT => unreachable,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTDIR => return error.NotDir,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `chdir` except the parameter is WTF16 LE encoded.
pub fn chdirW(dir_path: []const u16) ChangeCurDirError!void {
    windows.SetCurrentDirectory(dir_path) catch |err| switch (err) {
        error.NoDevice => return error.FileSystem,
        else => |e| return e,
    };
}

pub const FchdirError = error{
    AccessDenied,
    NotDir,
    FileSystem,
} || UnexpectedError;

pub fn fchdir(dirfd: fd_t) FchdirError!void {
    if (dirfd == AT.FDCWD) return;
    while (true) {
        switch (errno(system.fchdir(dirfd))) {
            .SUCCESS => return,
            .ACCES => return error.AccessDenied,
            .BADF => unreachable,
            .NOTDIR => return error.NotDir,
            .INTR => continue,
            .IO => return error.FileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const ReadLinkError = error{
    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to read value of a symbolic link relative to it.
    AccessDenied,
    FileSystem,
    SymLinkLoop,
    NameTooLong,
    FileNotFound,
    SystemResources,
    NotLink,
    NotDir,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
    BadPathName,
    /// Windows-only. This error may occur if the opened reparse point is
    /// of unsupported type.
    UnsupportedReparsePointType,
    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,
} || UnexpectedError;

/// Read value of a symbolic link.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// The return value is a slice of `out_buffer` from index 0.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, the result is encoded as UTF-8.
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
pub fn readlink(file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .wasi and !builtin.link_libc) {
        return readlinkat(wasi.AT.FDCWD, file_path, out_buffer);
    } else if (native_os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(null, file_path);
        return readlinkW(file_path_w.span(), out_buffer);
    } else {
        const file_path_c = try toPosixPath(file_path);
        return readlinkZ(&file_path_c, out_buffer);
    }
}

/// Windows-only. Same as `readlink` except `file_path` is WTF16 LE encoded.
/// The result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// See also `readlinkZ`.
pub fn readlinkW(file_path: []const u16, out_buffer: []u8) ReadLinkError![]u8 {
    return windows.ReadLink(fs.cwd().fd, file_path, out_buffer);
}

/// Same as `readlink` except `file_path` is null-terminated.
pub fn readlinkZ(file_path: [*:0]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(null, file_path);
        return readlinkW(file_path_w.span(), out_buffer);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return readlink(mem.sliceTo(file_path, 0), out_buffer);
    }
    const rc = system.readlink(file_path, out_buffer.ptr, out_buffer.len);
    switch (errno(rc)) {
        .SUCCESS => return out_buffer[0..@bitCast(rc)],
        .ACCES => return error.AccessDenied,
        .FAULT => unreachable,
        .INVAL => return error.NotLink,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTDIR => return error.NotDir,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Similar to `readlink` except reads value of a symbolink link **relative** to `dirfd` directory handle.
/// On Windows, `file_path` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, `file_path` should be encoded as valid UTF-8.
/// On other platforms, `file_path` is an opaque sequence of bytes with no particular encoding.
/// The return value is a slice of `out_buffer` from index 0.
/// On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// On WASI, the result is encoded as UTF-8.
/// On other platforms, the result is an opaque sequence of bytes with no particular encoding.
/// See also `readlinkatWasi`, `realinkatZ` and `realinkatW`.
pub fn readlinkat(dirfd: fd_t, file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .wasi and !builtin.link_libc) {
        return readlinkatWasi(dirfd, file_path, out_buffer);
    }
    if (native_os == .windows) {
        const file_path_w = try windows.sliceToPrefixedFileW(dirfd, file_path);
        return readlinkatW(dirfd, file_path_w.span(), out_buffer);
    }
    const file_path_c = try toPosixPath(file_path);
    return readlinkatZ(dirfd, &file_path_c, out_buffer);
}

/// WASI-only. Same as `readlinkat` but targets WASI.
/// See also `readlinkat`.
pub fn readlinkatWasi(dirfd: fd_t, file_path: []const u8, out_buffer: []u8) ReadLinkError![]u8 {
    var bufused: usize = undefined;
    switch (wasi.path_readlink(dirfd, file_path.ptr, file_path.len, out_buffer.ptr, out_buffer.len, &bufused)) {
        .SUCCESS => return out_buffer[0..bufused],
        .ACCES => return error.AccessDenied,
        .FAULT => unreachable,
        .INVAL => return error.NotLink,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTDIR => return error.NotDir,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,
        else => |err| return unexpectedErrno(err),
    }
}

/// Windows-only. Same as `readlinkat` except `file_path` is null-terminated, WTF16 LE encoded.
/// The result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// See also `readlinkat`.
pub fn readlinkatW(dirfd: fd_t, file_path: []const u16, out_buffer: []u8) ReadLinkError![]u8 {
    return windows.ReadLink(dirfd, file_path, out_buffer);
}

/// Same as `readlinkat` except `file_path` is null-terminated.
/// See also `readlinkat`.
pub fn readlinkatZ(dirfd: fd_t, file_path: [*:0]const u8, out_buffer: []u8) ReadLinkError![]u8 {
    if (native_os == .windows) {
        const file_path_w = try windows.cStrToPrefixedFileW(dirfd, file_path);
        return readlinkatW(dirfd, file_path_w.span(), out_buffer);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return readlinkat(dirfd, mem.sliceTo(file_path, 0), out_buffer);
    }
    const rc = system.readlinkat(dirfd, file_path, out_buffer.ptr, out_buffer.len);
    switch (errno(rc)) {
        .SUCCESS => return out_buffer[0..@bitCast(rc)],
        .ACCES => return error.AccessDenied,
        .FAULT => unreachable,
        .INVAL => return error.NotLink,
        .IO => return error.FileSystem,
        .LOOP => return error.SymLinkLoop,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTDIR => return error.NotDir,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

pub const SetEidError = error{
    InvalidUserId,
    PermissionDenied,
} || UnexpectedError;

pub const SetIdError = error{ResourceLimitReached} || SetEidError;

pub fn setuid(uid: uid_t) SetIdError!void {
    switch (errno(system.setuid(uid))) {
        .SUCCESS => return,
        .AGAIN => return error.ResourceLimitReached,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn seteuid(uid: uid_t) SetEidError!void {
    switch (errno(system.seteuid(uid))) {
        .SUCCESS => return,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setreuid(ruid: uid_t, euid: uid_t) SetIdError!void {
    switch (errno(system.setreuid(ruid, euid))) {
        .SUCCESS => return,
        .AGAIN => return error.ResourceLimitReached,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setgid(gid: gid_t) SetIdError!void {
    switch (errno(system.setgid(gid))) {
        .SUCCESS => return,
        .AGAIN => return error.ResourceLimitReached,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setegid(uid: uid_t) SetEidError!void {
    switch (errno(system.setegid(uid))) {
        .SUCCESS => return,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn setregid(rgid: gid_t, egid: gid_t) SetIdError!void {
    switch (errno(system.setregid(rgid, egid))) {
        .SUCCESS => return,
        .AGAIN => return error.ResourceLimitReached,
        .INVAL => return error.InvalidUserId,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SetPgidError = error{
    ProcessAlreadyExec,
    InvalidProcessGroupId,
    PermissionDenied,
    ProcessNotFound,
} || UnexpectedError;

pub fn setpgid(pid: pid_t, pgid: pid_t) SetPgidError!void {
    switch (errno(system.setpgid(pid, pgid))) {
        .SUCCESS => return,
        .ACCES => return error.ProcessAlreadyExec,
        .INVAL => return error.InvalidProcessGroupId,
        .PERM => return error.PermissionDenied,
        .SRCH => return error.ProcessNotFound,
        else => |err| return unexpectedErrno(err),
    }
}

/// Test whether a file descriptor refers to a terminal.
pub fn isatty(handle: fd_t) bool {
    if (native_os == .windows) {
        if (fs.File.isCygwinPty(.{ .handle = handle }))
            return true;

        var out: windows.DWORD = undefined;
        return windows.kernel32.GetConsoleMode(handle, &out) != 0;
    }
    if (builtin.link_libc) {
        return system.isatty(handle) != 0;
    }
    if (native_os == .wasi) {
        var statbuf: wasi.fdstat_t = undefined;
        const err = wasi.fd_fdstat_get(handle, &statbuf);
        if (err != .SUCCESS)
            return false;

        // A tty is a character device that we can't seek or tell on.
        if (statbuf.fs_filetype != .CHARACTER_DEVICE)
            return false;
        if (statbuf.fs_rights_base.FD_SEEK or statbuf.fs_rights_base.FD_TELL)
            return false;

        return true;
    }
    if (native_os == .linux) {
        while (true) {
            var wsz: winsize = undefined;
            const fd: usize = @bitCast(@as(isize, handle));
            const rc = linux.syscall3(.ioctl, fd, linux.T.IOCGWINSZ, @intFromPtr(&wsz));
            switch (linux.E.init(rc)) {
                .SUCCESS => return true,
                .INTR => continue,
                else => return false,
            }
        }
    }
    return system.isatty(handle) != 0;
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

    /// The socket type is not supported by the protocol.
    SocketTypeNotSupported,
} || UnexpectedError;

pub fn socket(domain: u32, socket_type: u32, protocol: u32) SocketError!socket_t {
    if (native_os == .windows) {
        // NOTE: windows translates the SOCK.NONBLOCK/SOCK.CLOEXEC flags into
        // windows-analogous operations
        const filtered_sock_type = socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC);
        const flags: u32 = if ((socket_type & SOCK.CLOEXEC) != 0)
            windows.ws2_32.WSA_FLAG_NO_HANDLE_INHERIT
        else
            0;
        const rc = try windows.WSASocketW(
            @bitCast(domain),
            @bitCast(filtered_sock_type),
            @bitCast(protocol),
            null,
            0,
            flags,
        );
        errdefer windows.closesocket(rc) catch unreachable;
        if ((socket_type & SOCK.NONBLOCK) != 0) {
            var mode: c_ulong = 1; // nonblocking
            if (windows.ws2_32.SOCKET_ERROR == windows.ws2_32.ioctlsocket(rc, windows.ws2_32.FIONBIO, &mode)) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    // have not identified any error codes that should be handled yet
                    else => unreachable,
                }
            }
        }
        return rc;
    }

    const have_sock_flags = !builtin.target.isDarwin() and native_os != .haiku;
    const filtered_sock_type = if (!have_sock_flags)
        socket_type & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC)
    else
        socket_type;
    const rc = system.socket(domain, filtered_sock_type, protocol);
    switch (errno(rc)) {
        .SUCCESS => {
            const fd: fd_t = @intCast(rc);
            errdefer close(fd);
            if (!have_sock_flags) {
                try setSockFlags(fd, socket_type);
            }
            return fd;
        },
        .ACCES => return error.PermissionDenied,
        .AFNOSUPPORT => return error.AddressFamilyNotSupported,
        .INVAL => return error.ProtocolFamilyNotAvailable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOBUFS => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        .PROTONOSUPPORT => return error.ProtocolNotSupported,
        .PROTOTYPE => return error.SocketTypeNotSupported,
        else => |err| return unexpectedErrno(err),
    }
}

pub const ShutdownError = error{
    ConnectionAborted,

    /// Connection was reset by peer, application should close socket as it is no longer usable.
    ConnectionResetByPeer,
    BlockingOperationInProgress,

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// The socket is not connected (connection-oriented sockets only).
    SocketNotConnected,
    SystemResources,
} || UnexpectedError;

pub const ShutdownHow = enum { recv, send, both };

/// Shutdown socket send/receive operations
pub fn shutdown(sock: socket_t, how: ShutdownHow) ShutdownError!void {
    if (native_os == .windows) {
        const result = windows.ws2_32.shutdown(sock, switch (how) {
            .recv => windows.ws2_32.SD_RECEIVE,
            .send => windows.ws2_32.SD_SEND,
            .both => windows.ws2_32.SD_BOTH,
        });
        if (0 != result) switch (windows.ws2_32.WSAGetLastError()) {
            .WSAECONNABORTED => return error.ConnectionAborted,
            .WSAECONNRESET => return error.ConnectionResetByPeer,
            .WSAEINPROGRESS => return error.BlockingOperationInProgress,
            .WSAEINVAL => unreachable,
            .WSAENETDOWN => return error.NetworkSubsystemFailed,
            .WSAENOTCONN => return error.SocketNotConnected,
            .WSAENOTSOCK => unreachable,
            .WSANOTINITIALISED => unreachable,
            else => |err| return windows.unexpectedWSAError(err),
        };
    } else {
        const rc = system.shutdown(sock, switch (how) {
            .recv => SHUT.RD,
            .send => SHUT.WR,
            .both => SHUT.RDWR,
        });
        switch (errno(rc)) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INVAL => unreachable,
            .NOTCONN => return error.SocketNotConnected,
            .NOTSOCK => unreachable,
            .NOBUFS => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
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

    /// The address is not valid for the address family of socket.
    AddressFamilyNotSupported,

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

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    FileDescriptorNotASocket,

    AlreadyBound,
} || UnexpectedError;

/// addr is `*const T` where T is one of the sockaddr
pub fn bind(sock: socket_t, addr: *const sockaddr, len: socklen_t) BindError!void {
    if (native_os == .windows) {
        const rc = windows.bind(sock, addr, len);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAEACCES => return error.AccessDenied,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEFAULT => unreachable, // invalid pointers
                .WSAEINVAL => return error.AlreadyBound,
                .WSAENOBUFS => return error.SystemResources,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                else => |err| return windows.unexpectedWSAError(err),
            }
            unreachable;
        }
        return;
    } else {
        const rc = system.bind(sock, addr, len);
        switch (errno(rc)) {
            .SUCCESS => return,
            .ACCES, .PERM => return error.AccessDenied,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable, // always a race condition if this error is returned
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => unreachable, // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .FAULT => unreachable, // invalid `addr` pointer
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOMEM => return error.SystemResources,
            .NOTDIR => return error.NotDir,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }
    unreachable;
}

pub const ListenError = error{
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

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// Ran out of system resources
    /// On Windows it can either run out of socket descriptors or buffer space
    SystemResources,

    /// Already connected
    AlreadyConnected,

    /// Socket has not been bound yet
    SocketNotBound,
} || UnexpectedError;

pub fn listen(sock: socket_t, backlog: u31) ListenError!void {
    if (native_os == .windows) {
        const rc = windows.listen(sock, backlog);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable, // not initialized WSA
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEADDRINUSE => return error.AddressInUse,
                .WSAEISCONN => return error.AlreadyConnected,
                .WSAEINVAL => return error.SocketNotBound,
                .WSAEMFILE, .WSAENOBUFS => return error.SystemResources,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEOPNOTSUPP => return error.OperationNotSupported,
                .WSAEINPROGRESS => unreachable,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = system.listen(sock, backlog);
        switch (errno(rc)) {
            .SUCCESS => return,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => unreachable,
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .OPNOTSUPP => return error.OperationNotSupported,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const AcceptError = error{
    ConnectionAborted,

    /// The file descriptor sockfd does not refer to a socket.
    FileDescriptorNotASocket,

    /// The per-process limit on the number of open file descriptors has been reached.
    ProcessFdQuotaExceeded,

    /// The system-wide limit on the total number of open files has been reached.
    SystemFdQuotaExceeded,

    /// Not enough free memory.  This often means that the memory allocation  is  limited
    /// by the socket buffer limits, not by the system memory.
    SystemResources,

    /// Socket is not listening for new connections.
    SocketNotListening,

    ProtocolFailure,

    /// Firewall rules forbid connection.
    BlockedByFirewall,

    /// This error occurs when no global event loop is configured,
    /// and accepting from the socket would block.
    WouldBlock,

    /// An incoming connection was indicated, but was subsequently terminated by the
    /// remote peer prior to accepting the call.
    ConnectionResetByPeer,

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// The referenced socket is not a type that supports connection-oriented service.
    OperationNotSupported,
} || UnexpectedError;

/// Accept a connection on a socket.
/// If `sockfd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
pub fn accept(
    /// This argument is a socket that has been created with `socket`, bound to a local address
    /// with `bind`, and is listening for connections after a `listen`.
    sock: socket_t,
    /// This argument is a pointer to a sockaddr structure.  This structure is filled in with  the
    /// address  of  the  peer  socket, as known to the communications layer.  The exact format of the
    /// address returned addr is determined by the socket's address  family  (see  `socket`  and  the
    /// respective  protocol  man  pages).
    addr: ?*sockaddr,
    /// This argument is a value-result argument: the caller must initialize it to contain  the
    /// size (in bytes) of the structure pointed to by addr; on return it will contain the actual size
    /// of the peer address.
    ///
    /// The returned address is truncated if the buffer provided is too small; in this  case,  `addr_size`
    /// will return a value greater than was supplied to the call.
    addr_size: ?*socklen_t,
    /// The following values can be bitwise ORed in flags to obtain different behavior:
    /// * `SOCK.NONBLOCK` - Set the `NONBLOCK` file status flag on the open file description (see `open`)
    ///   referred  to by the new file descriptor.  Using this flag saves extra calls to `fcntl` to achieve
    ///   the same result.
    /// * `SOCK.CLOEXEC`  - Set the close-on-exec (`FD_CLOEXEC`) flag on the new file descriptor.   See  the
    ///   description  of the `CLOEXEC` flag in `open` for reasons why this may be useful.
    flags: u32,
) AcceptError!socket_t {
    const have_accept4 = !(builtin.target.isDarwin() or native_os == .windows or native_os == .haiku);
    assert(0 == (flags & ~@as(u32, SOCK.NONBLOCK | SOCK.CLOEXEC))); // Unsupported flag(s)

    const accepted_sock: socket_t = while (true) {
        const rc = if (have_accept4)
            system.accept4(sock, addr, addr_size, flags)
        else if (native_os == .windows)
            windows.accept(sock, addr, addr_size)
        else
            system.accept(sock, addr, addr_size);

        if (native_os == .windows) {
            if (rc == windows.ws2_32.INVALID_SOCKET) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable, // not initialized WSA
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEFAULT => unreachable,
                    .WSAEINVAL => return error.SocketNotListening,
                    .WSAEMFILE => return error.ProcessFdQuotaExceeded,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOBUFS => return error.FileDescriptorNotASocket,
                    .WSAEOPNOTSUPP => return error.OperationNotSupported,
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                break rc;
            }
        } else {
            switch (errno(rc)) {
                .SUCCESS => break @intCast(rc),
                .INTR => continue,
                .AGAIN => return error.WouldBlock,
                .BADF => unreachable, // always a race condition
                .CONNABORTED => return error.ConnectionAborted,
                .FAULT => unreachable,
                .INVAL => return error.SocketNotListening,
                .NOTSOCK => unreachable,
                .MFILE => return error.ProcessFdQuotaExceeded,
                .NFILE => return error.SystemFdQuotaExceeded,
                .NOBUFS => return error.SystemResources,
                .NOMEM => return error.SystemResources,
                .OPNOTSUPP => unreachable,
                .PROTO => return error.ProtocolFailure,
                .PERM => return error.BlockedByFirewall,
                else => |err| return unexpectedErrno(err),
            }
        }
    };

    errdefer switch (native_os) {
        .windows => windows.closesocket(accepted_sock) catch unreachable,
        else => close(accepted_sock),
    };
    if (!have_accept4) {
        try setSockFlags(accepted_sock, flags);
    }
    return accepted_sock;
}

fn setSockFlags(sock: socket_t, flags: u32) !void {
    if ((flags & SOCK.CLOEXEC) != 0) {
        if (native_os == .windows) {
            // TODO: Find out if this is supported for sockets
        } else {
            var fd_flags = fcntl(sock, F.GETFD, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fd_flags |= FD_CLOEXEC;
            _ = fcntl(sock, F.SETFD, fd_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
        }
    }
    if ((flags & SOCK.NONBLOCK) != 0) {
        if (native_os == .windows) {
            var mode: c_ulong = 1;
            if (windows.ws2_32.ioctlsocket(sock, windows.ws2_32.FIONBIO, &mode) == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    // TODO: handle more errors
                    else => |err| return windows.unexpectedWSAError(err),
                }
            }
        } else {
            var fl_flags = fcntl(sock, F.GETFL, 0) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
            fl_flags |= 1 << @bitOffsetOf(O, "NONBLOCK");
            _ = fcntl(sock, F.SETFL, fl_flags) catch |err| switch (err) {
                error.FileBusy => unreachable,
                error.Locked => unreachable,
                error.PermissionDenied => unreachable,
                error.DeadLock => unreachable,
                error.LockedRegionLimitExceeded => unreachable,
                else => |e| return e,
            };
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
        .SUCCESS => return @intCast(rc),
        else => |err| return unexpectedErrno(err),

        .INVAL => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
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

pub fn epoll_ctl(epfd: i32, op: u32, fd: i32, event: ?*system.epoll_event) EpollCtlError!void {
    const rc = system.epoll_ctl(epfd, op, fd, event);
    switch (errno(rc)) {
        .SUCCESS => return,
        else => |err| return unexpectedErrno(err),

        .BADF => unreachable, // always a race condition if this happens
        .EXIST => return error.FileDescriptorAlreadyPresentInSet,
        .INVAL => unreachable,
        .LOOP => return error.OperationCausesCircularLoop,
        .NOENT => return error.FileDescriptorNotRegistered,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.UserResourceLimitReached,
        .PERM => return error.FileDescriptorIncompatibleWithEpoll,
    }
}

/// Waits for an I/O event on an epoll file descriptor.
/// Returns the number of file descriptors ready for the requested I/O,
/// or zero if no file descriptor became ready during the requested timeout milliseconds.
pub fn epoll_wait(epfd: i32, events: []system.epoll_event, timeout: i32) usize {
    while (true) {
        // TODO get rid of the @intCast
        const rc = system.epoll_wait(epfd, events.ptr, @intCast(events.len), timeout);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .BADF => unreachable,
            .FAULT => unreachable,
            .INVAL => unreachable,
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
        .SUCCESS => return @intCast(rc),
        else => |err| return unexpectedErrno(err),

        .INVAL => unreachable, // invalid parameters
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NODEV => return error.SystemResources,
        .NOMEM => return error.SystemResources,
    }
}

pub const GetSockNameError = error{
    /// Insufficient resources were available in the system to perform the operation.
    SystemResources,

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// Socket hasn't been bound yet
    SocketNotBound,

    FileDescriptorNotASocket,
} || UnexpectedError;

pub fn getsockname(sock: socket_t, addr: *sockaddr, addrlen: *socklen_t) GetSockNameError!void {
    if (native_os == .windows) {
        const rc = windows.getsockname(sock, addr, addrlen);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable, // addr or addrlen have invalid pointers or addrlen points to an incorrect value
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = system.getsockname(sock, addr, addrlen);
        switch (errno(rc)) {
            .SUCCESS => return,
            else => |err| return unexpectedErrno(err),

            .BADF => unreachable, // always a race condition
            .FAULT => unreachable,
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .NOBUFS => return error.SystemResources,
        }
    }
}

pub fn getpeername(sock: socket_t, addr: *sockaddr, addrlen: *socklen_t) GetSockNameError!void {
    if (native_os == .windows) {
        const rc = windows.getpeername(sock, addr, addrlen);
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable, // addr or addrlen have invalid pointers or addrlen points to an incorrect value
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        const rc = system.getpeername(sock, addr, addrlen);
        switch (errno(rc)) {
            .SUCCESS => return,
            else => |err| return unexpectedErrno(err),

            .BADF => unreachable, // always a race condition
            .FAULT => unreachable,
            .INVAL => unreachable, // invalid parameters
            .NOTSOCK => return error.FileDescriptorNotASocket,
            .NOBUFS => return error.SystemResources,
        }
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

    /// Connection was reset by peer before connect could complete.
    ConnectionResetByPeer,

    /// Socket is non-blocking and already has a pending connection in progress.
    ConnectionPending,
} || UnexpectedError;

/// Initiate a connection on a socket.
/// If `sockfd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN or EINPROGRESS is received.
pub fn connect(sock: socket_t, sock_addr: *const sockaddr, len: socklen_t) ConnectError!void {
    if (native_os == .windows) {
        const rc = windows.ws2_32.connect(sock, sock_addr, @intCast(len));
        if (rc == 0) return;
        switch (windows.ws2_32.WSAGetLastError()) {
            .WSAEADDRINUSE => return error.AddressInUse,
            .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
            .WSAECONNREFUSED => return error.ConnectionRefused,
            .WSAECONNRESET => return error.ConnectionResetByPeer,
            .WSAETIMEDOUT => return error.ConnectionTimedOut,
            .WSAEHOSTUNREACH, // TODO: should we return NetworkUnreachable in this case as well?
            .WSAENETUNREACH,
            => return error.NetworkUnreachable,
            .WSAEFAULT => unreachable,
            .WSAEINVAL => unreachable,
            .WSAEISCONN => unreachable,
            .WSAENOTSOCK => unreachable,
            .WSAEWOULDBLOCK => return error.WouldBlock,
            .WSAEACCES => unreachable,
            .WSAENOBUFS => return error.SystemResources,
            .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
            else => |err| return windows.unexpectedWSAError(err),
        }
        return;
    }

    while (true) {
        switch (errno(system.connect(sock, sock_addr, len))) {
            .SUCCESS => return,
            .ACCES => return error.PermissionDenied,
            .PERM => return error.PermissionDenied,
            .ADDRINUSE => return error.AddressInUse,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .AGAIN, .INPROGRESS => return error.WouldBlock,
            .ALREADY => return error.ConnectionPending,
            .BADF => unreachable, // sockfd is not a valid open file descriptor.
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .FAULT => unreachable, // The socket structure address is outside the user's address space.
            .INTR => continue,
            .ISCONN => unreachable, // The socket is already connected.
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            .PROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOENT => return error.FileNotFound, // Returned when socket is AF.UNIX and the given path does not exist.
            .CONNABORTED => unreachable, // Tried to reuse socket that previously received error.ConnectionRefused.
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn getsockoptError(sockfd: fd_t) ConnectError!void {
    var err_code: i32 = undefined;
    var size: u32 = @sizeOf(u32);
    const rc = system.getsockopt(sockfd, SOL.SOCKET, SO.ERROR, @ptrCast(&err_code), &size);
    assert(size == 4);
    switch (errno(rc)) {
        .SUCCESS => switch (@as(E, @enumFromInt(err_code))) {
            .SUCCESS => return,
            .ACCES => return error.PermissionDenied,
            .PERM => return error.PermissionDenied,
            .ADDRINUSE => return error.AddressInUse,
            .ADDRNOTAVAIL => return error.AddressNotAvailable,
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .AGAIN => return error.SystemResources,
            .ALREADY => return error.ConnectionPending,
            .BADF => unreachable, // sockfd is not a valid open file descriptor.
            .CONNREFUSED => return error.ConnectionRefused,
            .FAULT => unreachable, // The socket structure address is outside the user's address space.
            .ISCONN => unreachable, // The socket is already connected.
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            .PROTOTYPE => unreachable, // The socket type does not support the requested communications protocol.
            .TIMEDOUT => return error.ConnectionTimedOut,
            .CONNRESET => return error.ConnectionResetByPeer,
            else => |err| return unexpectedErrno(err),
        },
        .BADF => unreachable, // The argument sockfd is not a valid file descriptor.
        .FAULT => unreachable, // The address pointed to by optval or optlen is not in a valid part of the process address space.
        .INVAL => unreachable,
        .NOPROTOOPT => unreachable, // The option is unknown at the level indicated.
        .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
        else => |err| return unexpectedErrno(err),
    }
}

pub const WaitPidResult = struct {
    pid: pid_t,
    status: u32,
};

/// Use this version of the `waitpid` wrapper if you spawned your child process using explicit
/// `fork` and `execve` method.
pub fn waitpid(pid: pid_t, flags: u32) WaitPidResult {
    var status: if (builtin.link_libc) c_int else u32 = undefined;
    while (true) {
        const rc = system.waitpid(pid, &status, @intCast(flags));
        switch (errno(rc)) {
            .SUCCESS => return .{
                .pid = @intCast(rc),
                .status = @bitCast(status),
            },
            .INTR => continue,
            .CHILD => unreachable, // The process specified does not exist. It would be a race condition to handle this error.
            .INVAL => unreachable, // Invalid flags.
            else => unreachable,
        }
    }
}

pub fn wait4(pid: pid_t, flags: u32, ru: ?*rusage) WaitPidResult {
    var status: if (builtin.link_libc) c_int else u32 = undefined;
    while (true) {
        const rc = system.wait4(pid, &status, @intCast(flags), ru);
        switch (errno(rc)) {
            .SUCCESS => return .{
                .pid = @intCast(rc),
                .status = @bitCast(status),
            },
            .INTR => continue,
            .CHILD => unreachable, // The process specified does not exist. It would be a race condition to handle this error.
            .INVAL => unreachable, // Invalid flags.
            else => unreachable,
        }
    }
}

pub const FStatError = error{
    SystemResources,

    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to get its filestat information.
    AccessDenied,
} || UnexpectedError;

/// Return information about a file descriptor.
pub fn fstat(fd: fd_t) FStatError!Stat {
    if (native_os == .wasi and !builtin.link_libc) {
        return Stat.fromFilestat(try std.os.fstat_wasi(fd));
    }
    if (native_os == .windows) {
        @compileError("fstat is not yet implemented on Windows");
    }

    const fstat_sym = if (lfs64_abi) system.fstat64 else system.fstat;
    var stat = mem.zeroes(Stat);
    switch (errno(fstat_sym(fd, &stat))) {
        .SUCCESS => return stat,
        .INVAL => unreachable,
        .BADF => unreachable, // Always a race condition.
        .NOMEM => return error.SystemResources,
        .ACCES => return error.AccessDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const FStatAtError = FStatError || error{
    NameTooLong,
    FileNotFound,
    SymLinkLoop,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
};

/// Similar to `fstat`, but returns stat of a resource pointed to by `pathname`
/// which is relative to `dirfd` handle.
/// On WASI, `pathname` should be encoded as valid UTF-8.
/// On other platforms, `pathname` is an opaque sequence of bytes with no particular encoding.
/// See also `fstatatZ` and `std.os.fstatat_wasi`.
pub fn fstatat(dirfd: fd_t, pathname: []const u8, flags: u32) FStatAtError!Stat {
    if (native_os == .wasi and !builtin.link_libc) {
        const filestat = try std.os.fstatat_wasi(dirfd, pathname, .{
            .SYMLINK_FOLLOW = (flags & AT.SYMLINK_NOFOLLOW) == 0,
        });
        return Stat.fromFilestat(filestat);
    } else if (native_os == .windows) {
        @compileError("fstatat is not yet implemented on Windows");
    } else {
        const pathname_c = try toPosixPath(pathname);
        return fstatatZ(dirfd, &pathname_c, flags);
    }
}

/// Same as `fstatat` but `pathname` is null-terminated.
/// See also `fstatat`.
pub fn fstatatZ(dirfd: fd_t, pathname: [*:0]const u8, flags: u32) FStatAtError!Stat {
    if (native_os == .wasi and !builtin.link_libc) {
        const filestat = try std.os.fstatat_wasi(dirfd, mem.sliceTo(pathname, 0), .{
            .SYMLINK_FOLLOW = (flags & AT.SYMLINK_NOFOLLOW) == 0,
        });
        return Stat.fromFilestat(filestat);
    }

    const fstatat_sym = if (lfs64_abi) system.fstatat64 else system.fstatat;
    var stat = mem.zeroes(Stat);
    switch (errno(fstatat_sym(dirfd, pathname, &stat, flags))) {
        .SUCCESS => return stat,
        .INVAL => unreachable,
        .BADF => unreachable, // Always a race condition.
        .NOMEM => return error.SystemResources,
        .ACCES => return error.AccessDenied,
        .PERM => return error.AccessDenied,
        .FAULT => unreachable,
        .NAMETOOLONG => return error.NameTooLong,
        .LOOP => return error.SymLinkLoop,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.FileNotFound,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
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
        .SUCCESS => return @intCast(rc),
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
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
            cast(c_int, changelist.len) orelse return error.Overflow,
            eventlist.ptr,
            cast(c_int, eventlist.len) orelse return error.Overflow,
            timeout,
        );
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .ACCES => return error.AccessDenied,
            .FAULT => unreachable,
            .BADF => unreachable, // Always a race condition.
            .INTR => continue,
            .INVAL => unreachable,
            .NOENT => return error.EventNotFound,
            .NOMEM => return error.SystemResources,
            .SRCH => return error.ProcessNotFound,
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
        .SUCCESS => return @intCast(rc),
        .INVAL => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const INotifyAddWatchError = error{
    AccessDenied,
    NameTooLong,
    FileNotFound,
    SystemResources,
    UserResourceLimitReached,
    NotDir,
    WatchAlreadyExists,
} || UnexpectedError;

/// add a watch to an initialized inotify instance
pub fn inotify_add_watch(inotify_fd: i32, pathname: []const u8, mask: u32) INotifyAddWatchError!i32 {
    const pathname_c = try toPosixPath(pathname);
    return inotify_add_watchZ(inotify_fd, &pathname_c, mask);
}

/// Same as `inotify_add_watch` except pathname is null-terminated.
pub fn inotify_add_watchZ(inotify_fd: i32, pathname: [*:0]const u8, mask: u32) INotifyAddWatchError!i32 {
    const rc = system.inotify_add_watch(inotify_fd, pathname, mask);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .ACCES => return error.AccessDenied,
        .BADF => unreachable,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.UserResourceLimitReached,
        .NOTDIR => return error.NotDir,
        .EXIST => return error.WatchAlreadyExists,
        else => |err| return unexpectedErrno(err),
    }
}

/// remove an existing watch from an inotify instance
pub fn inotify_rm_watch(inotify_fd: i32, wd: i32) void {
    switch (errno(system.inotify_rm_watch(inotify_fd, wd))) {
        .SUCCESS => return,
        .BADF => unreachable,
        .INVAL => unreachable,
        else => unreachable,
    }
}

pub const FanotifyInitError = error{
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    SystemResources,
    PermissionDenied,
    /// The kernel does not recognize the flags passed, likely because it is an
    /// older version.
    UnsupportedFlags,
} || UnexpectedError;

pub fn fanotify_init(flags: std.os.linux.fanotify.InitFlags, event_f_flags: u32) FanotifyInitError!i32 {
    const rc = system.fanotify_init(flags, event_f_flags);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .INVAL => return error.UnsupportedFlags,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const FanotifyMarkError = error{
    MarkAlreadyExists,
    IsDir,
    NotAssociatedWithFileSystem,
    FileNotFound,
    SystemResources,
    UserMarkQuotaExceeded,
    NotDir,
    OperationNotSupported,
    PermissionDenied,
    NotSameFileSystem,
    NameTooLong,
} || UnexpectedError;

pub fn fanotify_mark(
    fanotify_fd: fd_t,
    flags: std.os.linux.fanotify.MarkFlags,
    mask: std.os.linux.fanotify.MarkMask,
    dirfd: fd_t,
    pathname: ?[]const u8,
) FanotifyMarkError!void {
    if (pathname) |path| {
        const path_c = try toPosixPath(path);
        return fanotify_markZ(fanotify_fd, flags, mask, dirfd, &path_c);
    } else {
        return fanotify_markZ(fanotify_fd, flags, mask, dirfd, null);
    }
}

pub fn fanotify_markZ(
    fanotify_fd: fd_t,
    flags: std.os.linux.fanotify.MarkFlags,
    mask: std.os.linux.fanotify.MarkMask,
    dirfd: fd_t,
    pathname: ?[*:0]const u8,
) FanotifyMarkError!void {
    const rc = system.fanotify_mark(fanotify_fd, flags, mask, dirfd, pathname);
    switch (errno(rc)) {
        .SUCCESS => return,
        .BADF => unreachable,
        .EXIST => return error.MarkAlreadyExists,
        .INVAL => unreachable,
        .ISDIR => return error.IsDir,
        .NODEV => return error.NotAssociatedWithFileSystem,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOSPC => return error.UserMarkQuotaExceeded,
        .NOTDIR => return error.NotDir,
        .OPNOTSUPP => return error.OperationNotSupported,
        .PERM => return error.PermissionDenied,
        .XDEV => return error.NotSameFileSystem,
        else => |err| return unexpectedErrno(err),
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

pub fn mprotect(memory: []align(mem.page_size) u8, protection: u32) MProtectError!void {
    if (native_os == .windows) {
        const win_prot: windows.DWORD = switch (@as(u3, @truncate(protection))) {
            0b000 => windows.PAGE_NOACCESS,
            0b001 => windows.PAGE_READONLY,
            0b010 => unreachable, // +w -r not allowed
            0b011 => windows.PAGE_READWRITE,
            0b100 => windows.PAGE_EXECUTE,
            0b101 => windows.PAGE_EXECUTE_READ,
            0b110 => unreachable, // +w -r not allowed
            0b111 => windows.PAGE_EXECUTE_READWRITE,
        };
        var old: windows.DWORD = undefined;
        windows.VirtualProtect(memory.ptr, memory.len, win_prot, &old) catch |err| switch (err) {
            error.InvalidAddress => return error.AccessDenied,
            error.Unexpected => return error.Unexpected,
        };
    } else {
        switch (errno(system.mprotect(memory.ptr, memory.len, protection))) {
            .SUCCESS => return,
            .INVAL => unreachable,
            .ACCES => return error.AccessDenied,
            .NOMEM => return error.OutOfMemory,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const ForkError = error{SystemResources} || UnexpectedError;

pub fn fork() ForkError!pid_t {
    const rc = system.fork();
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .AGAIN => return error.SystemResources,
        .NOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
    }
}

pub const MMapError = error{
    /// The underlying filesystem of the specified file does not support memory mapping.
    MemoryMappingNotSupported,

    /// A file descriptor refers to a non-regular file. Or a file mapping was requested,
    /// but the file descriptor is not open for reading. Or `MAP.SHARED` was requested
    /// and `PROT_WRITE` is set, but the file descriptor is not open in `RDWR` mode.
    /// Or `PROT_WRITE` is set, but the file is append-only.
    AccessDenied,

    /// The `prot` argument asks for `PROT_EXEC` but the mapped area belongs to a file on
    /// a filesystem that was mounted no-exec.
    PermissionDenied,
    LockedMemoryLimitExceeded,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    OutOfMemory,
} || UnexpectedError;

/// Map files or devices into memory.
/// `length` does not need to be aligned.
/// Use of a mapped region can result in these signals:
/// * SIGSEGV - Attempted write into a region mapped as read-only.
/// * SIGBUS - Attempted  access to a portion of the buffer that does not correspond to the file
pub fn mmap(
    ptr: ?[*]align(mem.page_size) u8,
    length: usize,
    prot: u32,
    flags: system.MAP,
    fd: fd_t,
    offset: u64,
) MMapError![]align(mem.page_size) u8 {
    const mmap_sym = if (lfs64_abi) system.mmap64 else system.mmap;
    const rc = mmap_sym(ptr, length, prot, @bitCast(flags), fd, @bitCast(offset));
    const err: E = if (builtin.link_libc) blk: {
        if (rc != std.c.MAP_FAILED) return @as([*]align(mem.page_size) u8, @ptrCast(@alignCast(rc)))[0..length];
        break :blk @enumFromInt(system._errno().*);
    } else blk: {
        const err = errno(rc);
        if (err == .SUCCESS) return @as([*]align(mem.page_size) u8, @ptrFromInt(rc))[0..length];
        break :blk err;
    };
    switch (err) {
        .SUCCESS => unreachable,
        .TXTBSY => return error.AccessDenied,
        .ACCES => return error.AccessDenied,
        .PERM => return error.PermissionDenied,
        .AGAIN => return error.LockedMemoryLimitExceeded,
        .BADF => unreachable, // Always a race condition.
        .OVERFLOW => unreachable, // The number of pages used for length + offset would overflow.
        .NODEV => return error.MemoryMappingNotSupported,
        .INVAL => unreachable, // Invalid parameters to mmap()
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.OutOfMemory,
        else => return unexpectedErrno(err),
    }
}

/// Deletes the mappings for the specified address range, causing
/// further references to addresses within the range to generate invalid memory references.
/// Note that while POSIX allows unmapping a region in the middle of an existing mapping,
/// Zig's munmap function does not, for two reasons:
/// * It violates the Zig principle that resource deallocation must succeed.
/// * The Windows function, VirtualFree, has this restriction.
pub fn munmap(memory: []align(mem.page_size) const u8) void {
    switch (errno(system.munmap(memory.ptr, memory.len))) {
        .SUCCESS => return,
        .INVAL => unreachable, // Invalid parameters.
        .NOMEM => unreachable, // Attempted to unmap a region in the middle of an existing mapping.
        else => unreachable,
    }
}

pub const MSyncError = error{
    UnmappedMemory,
    PermissionDenied,
} || UnexpectedError;

pub fn msync(memory: []align(mem.page_size) u8, flags: i32) MSyncError!void {
    switch (errno(system.msync(memory.ptr, memory.len, flags))) {
        .SUCCESS => return,
        .PERM => return error.PermissionDenied,
        .NOMEM => return error.UnmappedMemory, // Unsuccessful, provided pointer does not point mapped memory
        .INVAL => unreachable, // Invalid parameters.
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
    FileBusy,
    SymLinkLoop,
    ReadOnlyFileSystem,
    /// WASI-only; file paths must be valid UTF-8.
    InvalidUtf8,
    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,
} || UnexpectedError;

/// check user's permissions for a file
///
/// * On Windows, asserts `path` is valid [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, invalid UTF-8 passed to `path` causes `error.InvalidUtf8`.
/// * On other platforms, `path` is an opaque sequence of bytes with no particular encoding.
///
/// On Windows, `mode` is ignored. This is a POSIX API that is only partially supported by
/// Windows. See `fs` for the cross-platform file system API.
pub fn access(path: []const u8, mode: u32) AccessError!void {
    if (native_os == .windows) {
        const path_w = windows.sliceToPrefixedFileW(null, path) catch |err| switch (err) {
            error.AccessDenied => return error.PermissionDenied,
            else => |e| return e,
        };
        _ = try windows.GetFileAttributesW(path_w.span().ptr);
        return;
    } else if (native_os == .wasi and !builtin.link_libc) {
        return faccessat(wasi.AT.FDCWD, path, mode, 0);
    }
    const path_c = try toPosixPath(path);
    return accessZ(&path_c, mode);
}

/// Same as `access` except `path` is null-terminated.
pub fn accessZ(path: [*:0]const u8, mode: u32) AccessError!void {
    if (native_os == .windows) {
        const path_w = windows.cStrToPrefixedFileW(null, path) catch |err| switch (err) {
            error.AccessDenied => return error.PermissionDenied,
            else => |e| return e,
        };
        _ = try windows.GetFileAttributesW(path_w.span().ptr);
        return;
    } else if (native_os == .wasi and !builtin.link_libc) {
        return access(mem.sliceTo(path, 0), mode);
    }
    switch (errno(system.access(path, mode))) {
        .SUCCESS => return,
        .ACCES => return error.PermissionDenied,
        .ROFS => return error.ReadOnlyFileSystem,
        .LOOP => return error.SymLinkLoop,
        .TXTBSY => return error.FileBusy,
        .NOTDIR => return error.FileNotFound,
        .NOENT => return error.FileNotFound,
        .NAMETOOLONG => return error.NameTooLong,
        .INVAL => unreachable,
        .FAULT => unreachable,
        .IO => return error.InputOutput,
        .NOMEM => return error.SystemResources,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Check user's permissions for a file, based on an open directory handle.
///
/// * On Windows, asserts `path` is valid [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On WASI, invalid UTF-8 passed to `path` causes `error.InvalidUtf8`.
/// * On other platforms, `path` is an opaque sequence of bytes with no particular encoding.
///
/// On Windows, `mode` is ignored. This is a POSIX API that is only partially supported by
/// Windows. See `fs` for the cross-platform file system API.
pub fn faccessat(dirfd: fd_t, path: []const u8, mode: u32, flags: u32) AccessError!void {
    if (native_os == .windows) {
        const path_w = try windows.sliceToPrefixedFileW(dirfd, path);
        return faccessatW(dirfd, path_w.span().ptr);
    } else if (native_os == .wasi and !builtin.link_libc) {
        const resolved: RelativePathWasi = .{ .dir_fd = dirfd, .relative_path = path };

        const st = blk: {
            break :blk std.os.fstatat_wasi(dirfd, path, .{
                .SYMLINK_FOLLOW = (flags & AT.SYMLINK_NOFOLLOW) == 0,
            });
        } catch |err| switch (err) {
            error.AccessDenied => return error.PermissionDenied,
            else => |e| return e,
        };

        if (mode != F_OK) {
            var directory: wasi.fdstat_t = undefined;
            if (wasi.fd_fdstat_get(resolved.dir_fd, &directory) != .SUCCESS) {
                return error.PermissionDenied;
            }

            var rights: wasi.rights_t = .{};
            if (mode & R_OK != 0) {
                if (st.filetype == .DIRECTORY) {
                    rights.FD_READDIR = true;
                } else {
                    rights.FD_READ = true;
                }
            }
            if (mode & W_OK != 0) {
                rights.FD_WRITE = true;
            }
            // No validation for X_OK

            // https://github.com/ziglang/zig/issues/18882
            const rights_int: u64 = @bitCast(rights);
            const inheriting_int: u64 = @bitCast(directory.fs_rights_inheriting);
            if ((rights_int & inheriting_int) != rights_int) {
                return error.PermissionDenied;
            }
        }
        return;
    }
    const path_c = try toPosixPath(path);
    return faccessatZ(dirfd, &path_c, mode, flags);
}

/// Same as `faccessat` except the path parameter is null-terminated.
pub fn faccessatZ(dirfd: fd_t, path: [*:0]const u8, mode: u32, flags: u32) AccessError!void {
    if (native_os == .windows) {
        const path_w = try windows.cStrToPrefixedFileW(dirfd, path);
        return faccessatW(dirfd, path_w.span().ptr);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return faccessat(dirfd, mem.sliceTo(path, 0), mode, flags);
    }
    switch (errno(system.faccessat(dirfd, path, mode, flags))) {
        .SUCCESS => return,
        .ACCES => return error.PermissionDenied,
        .ROFS => return error.ReadOnlyFileSystem,
        .LOOP => return error.SymLinkLoop,
        .TXTBSY => return error.FileBusy,
        .NOTDIR => return error.FileNotFound,
        .NOENT => return error.FileNotFound,
        .NAMETOOLONG => return error.NameTooLong,
        .INVAL => unreachable,
        .FAULT => unreachable,
        .IO => return error.InputOutput,
        .NOMEM => return error.SystemResources,
        .ILSEQ => |err| if (native_os == .wasi)
            return error.InvalidUtf8
        else
            return unexpectedErrno(err),
        else => |err| return unexpectedErrno(err),
    }
}

/// Same as `faccessat` except asserts the target is Windows and the path parameter
/// is NtDll-prefixed, null-terminated, WTF-16 encoded.
pub fn faccessatW(dirfd: fd_t, sub_path_w: [*:0]const u16) AccessError!void {
    if (sub_path_w[0] == '.' and sub_path_w[1] == 0) {
        return;
    }
    if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) {
        return;
    }

    const path_len_bytes = cast(u16, mem.sliceTo(sub_path_w, 0).len * 2) orelse return error.NameTooLong;
    var nt_name = windows.UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w),
    };
    var attr = windows.OBJECT_ATTRIBUTES{
        .Length = @sizeOf(windows.OBJECT_ATTRIBUTES),
        .RootDirectory = if (fs.path.isAbsoluteWindowsW(sub_path_w)) null else dirfd,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var basic_info: windows.FILE_BASIC_INFORMATION = undefined;
    switch (windows.ntdll.NtQueryAttributesFile(&attr, &basic_info)) {
        .SUCCESS => return,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .OBJECT_NAME_INVALID => unreachable,
        .INVALID_PARAMETER => unreachable,
        .ACCESS_DENIED => return error.PermissionDenied,
        .OBJECT_PATH_SYNTAX_BAD => unreachable,
        else => |rc| return windows.unexpectedStatus(rc),
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
        .SUCCESS => return fds,
        .INVAL => unreachable, // Invalid parameters to pipe()
        .FAULT => unreachable, // Invalid fds pointer
        .NFILE => return error.SystemFdQuotaExceeded,
        .MFILE => return error.ProcessFdQuotaExceeded,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn pipe2(flags: O) PipeError![2]fd_t {
    if (@TypeOf(system.pipe2) != void) {
        var fds: [2]fd_t = undefined;
        switch (errno(system.pipe2(&fds, flags))) {
            .SUCCESS => return fds,
            .INVAL => unreachable, // Invalid flags
            .FAULT => unreachable, // Invalid fds pointer
            .NFILE => return error.SystemFdQuotaExceeded,
            .MFILE => return error.ProcessFdQuotaExceeded,
            else => |err| return unexpectedErrno(err),
        }
    }

    const fds: [2]fd_t = try pipe();
    errdefer {
        close(fds[0]);
        close(fds[1]);
    }

    // https://github.com/ziglang/zig/issues/18882
    if (@as(u32, @bitCast(flags)) == 0)
        return fds;

    // CLOEXEC is special, it's a file descriptor flag and must be set using
    // F.SETFD.
    if (flags.CLOEXEC) {
        for (fds) |fd| {
            switch (errno(system.fcntl(fd, F.SETFD, @as(u32, FD_CLOEXEC)))) {
                .SUCCESS => {},
                .INVAL => unreachable, // Invalid flags
                .BADF => unreachable, // Always a race condition
                else => |err| return unexpectedErrno(err),
            }
        }
    }

    const new_flags: u32 = f: {
        var new_flags = flags;
        new_flags.CLOEXEC = false;
        break :f @bitCast(new_flags);
    };
    // Set every other flag affecting the file status using F.SETFL.
    if (new_flags != 0) {
        for (fds) |fd| {
            switch (errno(system.fcntl(fd, F.SETFL, new_flags))) {
                .SUCCESS => {},
                .INVAL => unreachable, // Invalid flags
                .BADF => unreachable, // Always a race condition
                else => |err| return unexpectedErrno(err),
            }
        }
    }

    return fds;
}

pub const SysCtlError = error{
    PermissionDenied,
    SystemResources,
    NameTooLong,
    UnknownName,
} || UnexpectedError;

pub fn sysctl(
    name: []const c_int,
    oldp: ?*anyopaque,
    oldlenp: ?*usize,
    newp: ?*anyopaque,
    newlen: usize,
) SysCtlError!void {
    if (native_os == .wasi) {
        @panic("unsupported"); // TODO should be compile error, not panic
    }
    if (native_os == .haiku) {
        @panic("unsupported"); // TODO should be compile error, not panic
    }

    const name_len = cast(c_uint, name.len) orelse return error.NameTooLong;
    switch (errno(system.sysctl(name.ptr, name_len, oldp, oldlenp, newp, newlen))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .PERM => return error.PermissionDenied,
        .NOMEM => return error.SystemResources,
        .NOENT => return error.UnknownName,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn sysctlbynameZ(
    name: [*:0]const u8,
    oldp: ?*anyopaque,
    oldlenp: ?*usize,
    newp: ?*anyopaque,
    newlen: usize,
) SysCtlError!void {
    if (native_os == .wasi) {
        @panic("unsupported"); // TODO should be compile error, not panic
    }
    if (native_os == .haiku) {
        @panic("unsupported"); // TODO should be compile error, not panic
    }

    switch (errno(system.sysctlbyname(name, oldp, oldlenp, newp, newlen))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .PERM => return error.PermissionDenied,
        .NOMEM => return error.SystemResources,
        .NOENT => return error.UnknownName,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn gettimeofday(tv: ?*timeval, tz: ?*timezone) void {
    switch (errno(system.gettimeofday(tv, tz))) {
        .SUCCESS => return,
        .INVAL => unreachable,
        else => unreachable,
    }
}

pub const SeekError = error{
    Unseekable,

    /// In WASI, this error may occur when the file descriptor does
    /// not hold the required rights to seek on it.
    AccessDenied,
} || UnexpectedError;

/// Repositions read/write file offset relative to the beginning.
pub fn lseek_SET(fd: fd_t, offset: u64) SeekError!void {
    if (native_os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, offset, &result, SEEK.SET))) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (native_os == .windows) {
        return windows.SetFilePointerEx_BEGIN(fd, offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var new_offset: wasi.filesize_t = undefined;
        switch (wasi.fd_seek(fd, @bitCast(offset), .SET, &new_offset)) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }

    const lseek_sym = if (lfs64_abi) system.lseek64 else system.lseek;
    switch (errno(lseek_sym(fd, @bitCast(offset), SEEK.SET))) {
        .SUCCESS => return,
        .BADF => unreachable, // always a race condition
        .INVAL => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .NXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Repositions read/write file offset relative to the current offset.
pub fn lseek_CUR(fd: fd_t, offset: i64) SeekError!void {
    if (native_os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, @bitCast(offset), &result, SEEK.CUR))) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (native_os == .windows) {
        return windows.SetFilePointerEx_CURRENT(fd, offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var new_offset: wasi.filesize_t = undefined;
        switch (wasi.fd_seek(fd, offset, .CUR, &new_offset)) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
    const lseek_sym = if (lfs64_abi) system.lseek64 else system.lseek;
    switch (errno(lseek_sym(fd, @bitCast(offset), SEEK.CUR))) {
        .SUCCESS => return,
        .BADF => unreachable, // always a race condition
        .INVAL => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .NXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Repositions read/write file offset relative to the end.
pub fn lseek_END(fd: fd_t, offset: i64) SeekError!void {
    if (native_os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, @bitCast(offset), &result, SEEK.END))) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (native_os == .windows) {
        return windows.SetFilePointerEx_END(fd, offset);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var new_offset: wasi.filesize_t = undefined;
        switch (wasi.fd_seek(fd, offset, .END, &new_offset)) {
            .SUCCESS => return,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
    const lseek_sym = if (lfs64_abi) system.lseek64 else system.lseek;
    switch (errno(lseek_sym(fd, @bitCast(offset), SEEK.END))) {
        .SUCCESS => return,
        .BADF => unreachable, // always a race condition
        .INVAL => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .NXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

/// Returns the read/write file offset relative to the beginning.
pub fn lseek_CUR_get(fd: fd_t) SeekError!u64 {
    if (native_os == .linux and !builtin.link_libc and @sizeOf(usize) == 4) {
        var result: u64 = undefined;
        switch (errno(system.llseek(fd, 0, &result, SEEK.CUR))) {
            .SUCCESS => return result,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (native_os == .windows) {
        return windows.SetFilePointerEx_CURRENT_get(fd);
    }
    if (native_os == .wasi and !builtin.link_libc) {
        var new_offset: wasi.filesize_t = undefined;
        switch (wasi.fd_seek(fd, 0, .CUR, &new_offset)) {
            .SUCCESS => return new_offset,
            .BADF => unreachable, // always a race condition
            .INVAL => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .NXIO => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
    const lseek_sym = if (lfs64_abi) system.lseek64 else system.lseek;
    const rc = lseek_sym(fd, 0, SEEK.CUR);
    switch (errno(rc)) {
        .SUCCESS => return @bitCast(rc),
        .BADF => unreachable, // always a race condition
        .INVAL => return error.Unseekable,
        .OVERFLOW => return error.Unseekable,
        .SPIPE => return error.Unseekable,
        .NXIO => return error.Unseekable,
        else => |err| return unexpectedErrno(err),
    }
}

pub const FcntlError = error{
    PermissionDenied,
    FileBusy,
    ProcessFdQuotaExceeded,
    Locked,
    DeadLock,
    LockedRegionLimitExceeded,
} || UnexpectedError;

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) FcntlError!usize {
    while (true) {
        const rc = system.fcntl(fd, cmd, arg);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .AGAIN, .ACCES => return error.Locked,
            .BADF => unreachable,
            .BUSY => return error.FileBusy,
            .INVAL => unreachable, // invalid parameters
            .PERM => return error.PermissionDenied,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NOTDIR => unreachable, // invalid parameter
            .DEADLK => return error.DeadLock,
            .NOLCK => return error.LockedRegionLimitExceeded,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const FlockError = error{
    WouldBlock,

    /// The kernel ran out of memory for allocating file locks
    SystemResources,

    /// The underlying filesystem does not support file locks
    FileLocksNotSupported,
} || UnexpectedError;

/// Depending on the operating system `flock` may or may not interact with
/// `fcntl` locks made by other processes.
pub fn flock(fd: fd_t, operation: i32) FlockError!void {
    while (true) {
        const rc = system.flock(fd, operation);
        switch (errno(rc)) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INTR => continue,
            .INVAL => unreachable, // invalid parameters
            .NOLCK => return error.SystemResources,
            .AGAIN => return error.WouldBlock, // TODO: integrate with async instead of just returning an error
            .OPNOTSUPP => return error.FileLocksNotSupported,
            else => |err| return unexpectedErrno(err),
        }
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

    /// Windows-only; file paths provided by the user must be valid WTF-8.
    /// https://simonsapin.github.io/wtf-8/
    InvalidWtf8,

    /// On Windows, `\\server` or `\\server\share` was not found.
    NetworkNotFound,

    PathAlreadyExists,

    /// On Windows, antivirus software is enabled by default. It can be
    /// disabled, but Windows Update sometimes ignores the user's preference
    /// and re-enables it. When enabled, antivirus software on Windows
    /// intercepts file system operations and makes them significantly slower
    /// in addition to possibly failing with this error code.
    AntivirusInterference,

    /// On Windows, the volume does not contain a recognized file system. File
    /// system drivers might not be loaded, or the volume may be corrupt.
    UnrecognizedVolume,
} || UnexpectedError;

/// Return the canonicalized absolute pathname.
///
/// Expands all symbolic links and resolves references to `.`, `..`, and
/// extra `/` characters in `pathname`.
///
/// On Windows, `pathname` should be encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
///
/// On other platforms, `pathname` is an opaque sequence of bytes with no particular encoding.
///
/// The return value is a slice of `out_buffer`, but not necessarily from the beginning.
///
/// See also `realpathZ` and `realpathW`.
///
/// * On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On other platforms, the result is an opaque sequence of bytes with no particular encoding.
///
/// Calling this function is usually a bug.
pub fn realpath(pathname: []const u8, out_buffer: *[max_path_bytes]u8) RealPathError![]u8 {
    if (native_os == .windows) {
        const pathname_w = try windows.sliceToPrefixedFileW(null, pathname);
        return realpathW(pathname_w.span(), out_buffer);
    } else if (native_os == .wasi and !builtin.link_libc) {
        @compileError("WASI does not support os.realpath");
    }
    const pathname_c = try toPosixPath(pathname);
    return realpathZ(&pathname_c, out_buffer);
}

/// Same as `realpath` except `pathname` is null-terminated.
///
/// Calling this function is usually a bug.
pub fn realpathZ(pathname: [*:0]const u8, out_buffer: *[max_path_bytes]u8) RealPathError![]u8 {
    if (native_os == .windows) {
        const pathname_w = try windows.cStrToPrefixedFileW(null, pathname);
        return realpathW(pathname_w.span(), out_buffer);
    } else if (native_os == .wasi and !builtin.link_libc) {
        return realpath(mem.sliceTo(pathname, 0), out_buffer);
    }
    if (!builtin.link_libc) {
        const flags: O = switch (native_os) {
            .linux => .{
                .NONBLOCK = true,
                .CLOEXEC = true,
                .PATH = true,
            },
            else => .{
                .NONBLOCK = true,
                .CLOEXEC = true,
            },
        };
        const fd = openZ(pathname, flags, 0) catch |err| switch (err) {
            error.FileLocksNotSupported => unreachable,
            error.WouldBlock => unreachable,
            error.FileBusy => unreachable, // not asking for write permissions
            error.InvalidUtf8 => unreachable, // WASI-only
            else => |e| return e,
        };
        defer close(fd);

        return std.os.getFdPath(fd, out_buffer);
    }
    const result_path = std.c.realpath(pathname, out_buffer) orelse switch (@as(E, @enumFromInt(std.c._errno().*))) {
        .SUCCESS => unreachable,
        .INVAL => unreachable,
        .BADF => unreachable,
        .FAULT => unreachable,
        .ACCES => return error.AccessDenied,
        .NOENT => return error.FileNotFound,
        .OPNOTSUPP => return error.NotSupported,
        .NOTDIR => return error.NotDir,
        .NAMETOOLONG => return error.NameTooLong,
        .LOOP => return error.SymLinkLoop,
        .IO => return error.InputOutput,
        else => |err| return unexpectedErrno(err),
    };
    return mem.sliceTo(result_path, 0);
}

/// Same as `realpath` except `pathname` is WTF16LE-encoded.
///
/// The result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
///
/// Calling this function is usually a bug.
pub fn realpathW(pathname: []const u16, out_buffer: *[max_path_bytes]u8) RealPathError![]u8 {
    const w = windows;

    const dir = fs.cwd().fd;
    const access_mask = w.GENERIC_READ | w.SYNCHRONIZE;
    const share_access = w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE;
    const creation = w.FILE_OPEN;
    const h_file = blk: {
        const res = w.OpenFile(pathname, .{
            .dir = dir,
            .access_mask = access_mask,
            .share_access = share_access,
            .creation = creation,
            .filter = .any,
        }) catch |err| switch (err) {
            error.WouldBlock => unreachable,
            else => |e| return e,
        };
        break :blk res;
    };
    defer w.CloseHandle(h_file);

    return std.os.getFdPath(h_file, out_buffer);
}

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn nanosleep(seconds: u64, nanoseconds: u64) void {
    var req = timespec{
        .sec = cast(isize, seconds) orelse maxInt(isize),
        .nsec = cast(isize, nanoseconds) orelse maxInt(isize),
    };
    var rem: timespec = undefined;
    while (true) {
        switch (errno(system.nanosleep(&req, &rem))) {
            .FAULT => unreachable,
            .INVAL => {
                // Sometimes Darwin returns EINVAL for no reason.
                // We treat it as a spurious wakeup.
                return;
            },
            .INTR => {
                req = rem;
                continue;
            },
            // This prong handles success as well as unexpected errors.
            else => return,
        }
    }
}

pub fn dl_iterate_phdr(
    context: anytype,
    comptime Error: type,
    comptime callback: fn (info: *dl_phdr_info, size: usize, context: @TypeOf(context)) Error!void,
) Error!void {
    const Context = @TypeOf(context);
    const elf = std.elf;
    const dl = @import("dynamic_library.zig");

    switch (builtin.object_format) {
        .elf, .c => {},
        else => @compileError("dl_iterate_phdr is not available for this target"),
    }

    if (builtin.link_libc) {
        switch (system.dl_iterate_phdr(struct {
            fn callbackC(info: *dl_phdr_info, size: usize, data: ?*anyopaque) callconv(.C) c_int {
                const context_ptr: *const Context = @ptrCast(@alignCast(data));
                callback(info, size, context_ptr.*) catch |err| return @intFromError(err);
                return 0;
            }
        }.callbackC, @ptrCast(@constCast(&context)))) {
            0 => return,
            else => |err| return @as(Error, @errorCast(@errorFromInt(@as(std.meta.Int(.unsigned, @bitSizeOf(anyerror)), @intCast(err))))),
        }
    }

    const elf_base = std.process.getBaseAddress();
    const ehdr: *elf.Ehdr = @ptrFromInt(elf_base);
    // Make sure the base address points to an ELF image.
    assert(mem.eql(u8, ehdr.e_ident[0..4], elf.MAGIC));
    const n_phdr = ehdr.e_phnum;
    const phdrs = (@as([*]elf.Phdr, @ptrFromInt(elf_base + ehdr.e_phoff)))[0..n_phdr];

    var it = dl.linkmap_iterator(phdrs) catch unreachable;

    // The executable has no dynamic link segment, create a single entry for
    // the whole ELF image.
    if (it.end()) {
        // Find the base address for the ELF image, if this is a PIE the value
        // is non-zero.
        const base_address = for (phdrs) |*phdr| {
            if (phdr.p_type == elf.PT_PHDR) {
                break @intFromPtr(phdrs.ptr) - phdr.p_vaddr;
                // We could try computing the difference between _DYNAMIC and
                // the p_vaddr of the PT_DYNAMIC section, but using the phdr is
                // good enough (Is it?).
            }
        } else unreachable;

        var info = dl_phdr_info{
            .addr = base_address,
            .name = "/proc/self/exe",
            .phdr = phdrs.ptr,
            .phnum = ehdr.e_phnum,
        };

        return callback(&info, @sizeOf(dl_phdr_info), context);
    }

    // Last return value from the callback function.
    while (it.next()) |entry| {
        var phdr: [*]elf.Phdr = undefined;
        var phnum: u16 = undefined;

        if (entry.l_addr != 0) {
            const elf_header: *elf.Ehdr = @ptrFromInt(entry.l_addr);
            phdr = @ptrFromInt(entry.l_addr + elf_header.e_phoff);
            phnum = elf_header.e_phnum;
        } else {
            // This is the running ELF image
            phdr = @ptrFromInt(elf_base + ehdr.e_phoff);
            phnum = ehdr.e_phnum;
        }

        var info = dl_phdr_info{
            .addr = entry.l_addr,
            .name = entry.l_name,
            .phdr = phdr,
            .phnum = phnum,
        };

        try callback(&info, @sizeOf(dl_phdr_info), context);
    }
}

pub const ClockGetTimeError = error{UnsupportedClock} || UnexpectedError;

/// TODO: change this to return the timespec as a return value
pub fn clock_gettime(clock_id: clockid_t, tp: *timespec) ClockGetTimeError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        var ts: timestamp_t = undefined;
        switch (system.clock_time_get(clock_id, 1, &ts)) {
            .SUCCESS => {
                tp.* = .{
                    .sec = @intCast(ts / std.time.ns_per_s),
                    .nsec = @intCast(ts % std.time.ns_per_s),
                };
            },
            .INVAL => return error.UnsupportedClock,
            else => |err| return unexpectedErrno(err),
        }
        return;
    }
    if (native_os == .windows) {
        if (clock_id == .REALTIME) {
            var ft: windows.FILETIME = undefined;
            windows.kernel32.GetSystemTimeAsFileTime(&ft);
            // FileTime has a granularity of 100 nanoseconds and uses the NTFS/Windows epoch.
            const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
            const ft_per_s = std.time.ns_per_s / 100;
            tp.* = .{
                .sec = @as(i64, @intCast(ft64 / ft_per_s)) + std.time.epoch.windows,
                .nsec = @as(c_long, @intCast(ft64 % ft_per_s)) * 100,
            };
            return;
        } else {
            // TODO POSIX implementation of CLOCK.MONOTONIC on Windows.
            return error.UnsupportedClock;
        }
    }

    switch (errno(system.clock_gettime(clock_id, tp))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub fn clock_getres(clock_id: clockid_t, res: *timespec) ClockGetTimeError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        var ts: timestamp_t = undefined;
        switch (system.clock_res_get(@bitCast(clock_id), &ts)) {
            .SUCCESS => res.* = .{
                .sec = @intCast(ts / std.time.ns_per_s),
                .nsec = @intCast(ts % std.time.ns_per_s),
            },
            .INVAL => return error.UnsupportedClock,
            else => |err| return unexpectedErrno(err),
        }
        return;
    }

    switch (errno(system.clock_getres(clock_id, res))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => return error.UnsupportedClock,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SchedGetAffinityError = error{PermissionDenied} || UnexpectedError;

pub fn sched_getaffinity(pid: pid_t) SchedGetAffinityError!cpu_set_t {
    var set: cpu_set_t = undefined;
    switch (errno(system.sched_getaffinity(pid, @sizeOf(cpu_set_t), &set))) {
        .SUCCESS => return set,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .SRCH => unreachable,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SigaltstackError = error{
    /// The supplied stack size was less than MINSIGSTKSZ.
    SizeTooSmall,

    /// Attempted to change the signal stack while it was active.
    PermissionDenied,
} || UnexpectedError;

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) SigaltstackError!void {
    switch (errno(system.sigaltstack(ss, old_ss))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .NOMEM => return error.SizeTooSmall,
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

/// Examine and change a signal action.
pub fn sigaction(sig: u6, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) void {
    switch (errno(system.sigaction(sig, act, oact))) {
        .SUCCESS => return,
        // EINVAL means the signal is either invalid or some signal that cannot have its action
        // changed. For POSIX, this means SIGKILL/SIGSTOP. For e.g. Solaris, this also includes the
        // non-standard SIGWAITING, SIGCANCEL, and SIGLWP. Either way, programmer error.
        .INVAL => unreachable,
        else => unreachable,
    }
}

/// Sets the thread signal mask.
pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) void {
    switch (errno(system.sigprocmask(@bitCast(flags), set, oldset))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => unreachable,
        else => unreachable,
    }
}

pub const FutimensError = error{
    /// times is NULL, or both nsec values are UTIME_NOW, and either:
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
    /// (i.e., times is not NULL, neither nsec  field  is  UTIME_NOW,
    /// and neither nsec field is UTIME_OMIT) and either:
    /// *  the  caller's  effective  user ID does not match the owner of
    ///    file, and the caller is not privileged (Linux: does not  have
    ///    the CAP_FOWNER capability); or,
    /// *  the file is marked append-only or immutable (see chattr(1)).
    PermissionDenied,

    ReadOnlyFileSystem,
} || UnexpectedError;

pub fn futimens(fd: fd_t, times: *const [2]timespec) FutimensError!void {
    if (native_os == .wasi and !builtin.link_libc) {
        // TODO WASI encodes `wasi.fstflags` to signify magic values
        // similar to UTIME_NOW and UTIME_OMIT. Currently, we ignore
        // this here, but we should really handle it somehow.
        const atim = times[0].toTimestamp();
        const mtim = times[1].toTimestamp();
        switch (wasi.fd_filestat_set_times(fd, atim, mtim, .{
            .ATIM = true,
            .MTIM = true,
        })) {
            .SUCCESS => return,
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            .BADF => unreachable, // always a race condition
            .FAULT => unreachable,
            .INVAL => unreachable,
            .ROFS => return error.ReadOnlyFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }

    switch (errno(system.futimens(fd, times))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .PERM => return error.PermissionDenied,
        .BADF => unreachable, // always a race condition
        .FAULT => unreachable,
        .INVAL => unreachable,
        .ROFS => return error.ReadOnlyFileSystem,
        else => |err| return unexpectedErrno(err),
    }
}

pub const GetHostNameError = error{PermissionDenied} || UnexpectedError;

pub fn gethostname(name_buffer: *[HOST_NAME_MAX]u8) GetHostNameError![]u8 {
    if (builtin.link_libc) {
        switch (errno(system.gethostname(name_buffer, name_buffer.len))) {
            .SUCCESS => return mem.sliceTo(name_buffer, 0),
            .FAULT => unreachable,
            .NAMETOOLONG => unreachable, // HOST_NAME_MAX prevents this
            .PERM => return error.PermissionDenied,
            else => |err| return unexpectedErrno(err),
        }
    }
    if (native_os == .linux) {
        const uts = uname();
        const hostname = mem.sliceTo(&uts.nodename, 0);
        const result = name_buffer[0..hostname.len];
        @memcpy(result, hostname);
        return result;
    }

    @compileError("TODO implement gethostname for this OS");
}

pub fn uname() utsname {
    var uts: utsname = undefined;
    switch (errno(system.uname(&uts))) {
        .SUCCESS => return uts,
        .FAULT => unreachable,
        else => unreachable,
    }
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
    _ = data;
    _ = newrr;
    // This implementation is ported from musl libc.
    // A more idiomatic "ziggy" implementation would be welcome.
    var name = dname;
    if (mem.endsWith(u8, name, ".")) name.len -= 1;
    assert(name.len <= 253);
    const n = 17 + name.len + @intFromBool(name.len != 0);

    // Construct query template - ID will be filled later
    var q: [280]u8 = undefined;
    @memset(q[0..n], 0);
    q[2] = @as(u8, op) * 8 + 1;
    q[5] = 1;
    @memcpy(q[13..][0..name.len], name);
    var i: usize = 13;
    var j: usize = undefined;
    while (q[i] != 0) : (i = j + 1) {
        j = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        // TODO determine the circumstances for this and whether or
        // not this should be an error.
        if (j - i - 1 > 62) unreachable;
        q[i - 1] = @intCast(j - i);
    }
    q[i + 1] = ty;
    q[i + 3] = class;

    // Make a reasonably unpredictable id
    var ts: timespec = undefined;
    clock_gettime(.REALTIME, &ts) catch {};
    const UInt = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(ts.nsec)));
    const unsec: UInt = @bitCast(ts.nsec);
    const id: u32 = @truncate(unsec + unsec / 65536);
    q[0] = @truncate(id / 256);
    q[1] = @truncate(id);

    @memcpy(buf[0..n], q[0..n]);
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
    MessageTooBig,

    /// The output queue for a network interface was full.  This generally indicates  that  the
    /// interface  has  stopped sending, but may be caused by transient congestion.  (Normally,
    /// this does not occur in Linux.  Packets are just silently dropped when  a  device  queue
    /// overflows.)
    /// This is also caused when there is not enough kernel memory available.
    SystemResources,

    /// The  local  end  has been shut down on a connection oriented socket.  In this case, the
    /// process will also receive a SIGPIPE unless MSG.NOSIGNAL is set.
    BrokenPipe,

    FileDescriptorNotASocket,

    /// Network is unreachable.
    NetworkUnreachable,

    /// The local network interface used to reach the destination is down.
    NetworkSubsystemFailed,
} || UnexpectedError;

pub const SendMsgError = SendError || error{
    /// The passed address didn't have the correct address family in its sa_family field.
    AddressFamilyNotSupported,

    /// Returned when socket is AF.UNIX and the given path has a symlink loop.
    SymLinkLoop,

    /// Returned when socket is AF.UNIX and the given path length exceeds `max_path_bytes` bytes.
    NameTooLong,

    /// Returned when socket is AF.UNIX and the given path does not point to an existing file.
    FileNotFound,
    NotDir,

    /// The socket is not connected (connection-oriented sockets only).
    SocketNotConnected,
    AddressNotAvailable,
};

pub fn sendmsg(
    /// The file descriptor of the sending socket.
    sockfd: socket_t,
    /// Message header and iovecs
    msg: *const msghdr_const,
    flags: u32,
) SendMsgError!usize {
    while (true) {
        const rc = system.sendmsg(sockfd, msg, flags);
        if (native_os == .windows) {
            if (rc == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSAEACCES => return error.AccessDenied,
                    .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEMSGSIZE => return error.MessageTooBig,
                    .WSAENOBUFS => return error.SystemResources,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
                    .WSAEDESTADDRREQ => unreachable, // A destination address is required.
                    .WSAEFAULT => unreachable, // The lpBuffers, lpTo, lpOverlapped, lpNumberOfBytesSent, or lpCompletionRoutine parameters are not part of the user address space, or the lpTo parameter is too small.
                    .WSAEHOSTUNREACH => return error.NetworkUnreachable,
                    // TODO: WSAEINPROGRESS, WSAEINTR
                    .WSAEINVAL => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENETRESET => return error.ConnectionResetByPeer,
                    .WSAENETUNREACH => return error.NetworkUnreachable,
                    .WSAENOTCONN => return error.SocketNotConnected,
                    .WSAESHUTDOWN => unreachable, // The socket has been shut down; it is not possible to WSASendTo on a socket after shutdown has been invoked with how set to SD_SEND or SD_BOTH.
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    .WSANOTINITIALISED => unreachable, // A successful WSAStartup call must occur before using this function.
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                return @intCast(rc);
            }
        } else {
            switch (errno(rc)) {
                .SUCCESS => return @intCast(rc),

                .ACCES => return error.AccessDenied,
                .AGAIN => return error.WouldBlock,
                .ALREADY => return error.FastOpenAlreadyInProgress,
                .BADF => unreachable, // always a race condition
                .CONNRESET => return error.ConnectionResetByPeer,
                .DESTADDRREQ => unreachable, // The socket is not connection-mode, and no peer address is set.
                .FAULT => unreachable, // An invalid user space address was specified for an argument.
                .INTR => continue,
                .INVAL => unreachable, // Invalid argument passed.
                .ISCONN => unreachable, // connection-mode socket was connected already but a recipient was specified
                .MSGSIZE => return error.MessageTooBig,
                .NOBUFS => return error.SystemResources,
                .NOMEM => return error.SystemResources,
                .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
                .OPNOTSUPP => unreachable, // Some bit in the flags argument is inappropriate for the socket type.
                .PIPE => return error.BrokenPipe,
                .AFNOSUPPORT => return error.AddressFamilyNotSupported,
                .LOOP => return error.SymLinkLoop,
                .NAMETOOLONG => return error.NameTooLong,
                .NOENT => return error.FileNotFound,
                .NOTDIR => return error.NotDir,
                .HOSTUNREACH => return error.NetworkUnreachable,
                .NETUNREACH => return error.NetworkUnreachable,
                .NOTCONN => return error.SocketNotConnected,
                .NETDOWN => return error.NetworkSubsystemFailed,
                else => |err| return unexpectedErrno(err),
            }
        }
    }
}

pub const SendToError = SendMsgError || error{
    /// The destination address is not reachable by the bound address.
    UnreachableAddress,
    /// The destination address is not listening.
    ConnectionRefused,
};

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
/// If  sendto()  is used on a connection-mode (`SOCK.STREAM`, `SOCK.SEQPACKET`) socket, the arguments
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
    sockfd: socket_t,
    /// Message to send.
    buf: []const u8,
    flags: u32,
    dest_addr: ?*const sockaddr,
    addrlen: socklen_t,
) SendToError!usize {
    if (native_os == .windows) {
        switch (windows.sendto(sockfd, buf.ptr, buf.len, flags, dest_addr, addrlen)) {
            windows.ws2_32.SOCKET_ERROR => switch (windows.ws2_32.WSAGetLastError()) {
                .WSAEACCES => return error.AccessDenied,
                .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                .WSAECONNRESET => return error.ConnectionResetByPeer,
                .WSAEMSGSIZE => return error.MessageTooBig,
                .WSAENOBUFS => return error.SystemResources,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
                .WSAEDESTADDRREQ => unreachable, // A destination address is required.
                .WSAEFAULT => unreachable, // The lpBuffers, lpTo, lpOverlapped, lpNumberOfBytesSent, or lpCompletionRoutine parameters are not part of the user address space, or the lpTo parameter is too small.
                .WSAEHOSTUNREACH => return error.NetworkUnreachable,
                // TODO: WSAEINPROGRESS, WSAEINTR
                .WSAEINVAL => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAENETRESET => return error.ConnectionResetByPeer,
                .WSAENETUNREACH => return error.NetworkUnreachable,
                .WSAENOTCONN => return error.SocketNotConnected,
                .WSAESHUTDOWN => unreachable, // The socket has been shut down; it is not possible to WSASendTo on a socket after shutdown has been invoked with how set to SD_SEND or SD_BOTH.
                .WSAEWOULDBLOCK => return error.WouldBlock,
                .WSANOTINITIALISED => unreachable, // A successful WSAStartup call must occur before using this function.
                else => |err| return windows.unexpectedWSAError(err),
            },
            else => |rc| return @intCast(rc),
        }
    }
    while (true) {
        const rc = system.sendto(sockfd, buf.ptr, buf.len, flags, dest_addr, addrlen);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),

            .ACCES => return error.AccessDenied,
            .AGAIN => return error.WouldBlock,
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => unreachable, // always a race condition
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => unreachable, // The socket is not connection-mode, and no peer address is set.
            .FAULT => unreachable, // An invalid user space address was specified for an argument.
            .INTR => continue,
            .INVAL => return error.UnreachableAddress,
            .ISCONN => unreachable, // connection-mode socket was connected already but a recipient was specified
            .MSGSIZE => return error.MessageTooBig,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => unreachable, // The file descriptor sockfd does not refer to a socket.
            .OPNOTSUPP => unreachable, // Some bit in the flags argument is inappropriate for the socket type.
            .PIPE => return error.BrokenPipe,
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.NotDir,
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTCONN => return error.SocketNotConnected,
            .NETDOWN => return error.NetworkSubsystemFailed,
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
    sockfd: socket_t,
    buf: []const u8,
    flags: u32,
) SendError!usize {
    return sendto(sockfd, buf, flags, null, 0) catch |err| switch (err) {
        error.AddressFamilyNotSupported => unreachable,
        error.SymLinkLoop => unreachable,
        error.NameTooLong => unreachable,
        error.FileNotFound => unreachable,
        error.NotDir => unreachable,
        error.NetworkUnreachable => unreachable,
        error.AddressNotAvailable => unreachable,
        error.SocketNotConnected => unreachable,
        error.UnreachableAddress => unreachable,
        error.ConnectionRefused => unreachable,
        else => |e| return e,
    };
}

pub const SendFileError = PReadError || WriteError || SendError;

/// Transfer data between file descriptors, with optional headers and trailers.
///
/// Returns the number of bytes written, which can be zero.
///
/// The `sendfile` call copies `in_len` bytes from one file descriptor to another. When possible,
/// this is done within the operating system kernel, which can provide better performance
/// characteristics than transferring data from kernel to user space and back, such as with
/// `read` and `write` calls. When `in_len` is `0`, it means to copy until the end of the input file has been
/// reached. Note, however, that partial writes are still possible in this case.
///
/// `in_fd` must be a file descriptor opened for reading, and `out_fd` must be a file descriptor
/// opened for writing. They may be any kind of file descriptor; however, if `in_fd` is not a regular
/// file system file, it may cause this function to fall back to calling `read` and `write`, in which case
/// atomicity guarantees no longer apply.
///
/// Copying begins reading at `in_offset`. The input file descriptor seek position is ignored and not updated.
/// If the output file descriptor has a seek position, it is updated as bytes are written. When
/// `in_offset` is past the end of the input file, it successfully reads 0 bytes.
///
/// `flags` has different meanings per operating system; refer to the respective man pages.
///
/// These systems support atomically sending everything, including headers and trailers:
/// * macOS
/// * FreeBSD
///
/// These systems support in-kernel data copying, but headers and trailers are not sent atomically:
/// * Linux
///
/// Other systems fall back to calling `read` / `write`.
///
/// Linux has a limit on how many bytes may be transferred in one `sendfile` call, which is `0x7ffff000`
/// on both 64-bit and 32-bit systems. This is due to using a signed C int as the return value, as
/// well as stuffing the errno codes into the last `4096` values. This is noted on the `sendfile` man page.
/// The limit on Darwin is `0x7fffffff`, trying to write more than that returns EINVAL.
/// The corresponding POSIX limit on this is `maxInt(isize)`.
pub fn sendfile(
    out_fd: fd_t,
    in_fd: fd_t,
    in_offset: u64,
    in_len: u64,
    headers: []const iovec_const,
    trailers: []const iovec_const,
    flags: u32,
) SendFileError!usize {
    var header_done = false;
    var total_written: usize = 0;

    // Prevents EOVERFLOW.
    const size_t = std.meta.Int(.unsigned, @typeInfo(usize).int.bits - 1);
    const max_count = switch (native_os) {
        .linux => 0x7ffff000,
        .macos, .ios, .watchos, .tvos, .visionos => maxInt(i32),
        else => maxInt(size_t),
    };

    switch (native_os) {
        .linux => sf: {
            if (headers.len != 0) {
                const amt = try writev(out_fd, headers);
                total_written += amt;
                if (amt < count_iovec_bytes(headers)) return total_written;
                header_done = true;
            }

            // Here we match BSD behavior, making a zero count value send as many bytes as possible.
            const adjusted_count = if (in_len == 0) max_count else @min(in_len, max_count);

            const sendfile_sym = if (lfs64_abi) system.sendfile64 else system.sendfile;
            while (true) {
                var offset: off_t = @bitCast(in_offset);
                const rc = sendfile_sym(out_fd, in_fd, &offset, adjusted_count);
                switch (errno(rc)) {
                    .SUCCESS => {
                        const amt: usize = @bitCast(rc);
                        total_written += amt;
                        if (in_len == 0 and amt == 0) {
                            // We have detected EOF from `in_fd`.
                            break;
                        } else if (amt < in_len) {
                            return total_written;
                        } else {
                            break;
                        }
                    },

                    .BADF => unreachable, // Always a race condition.
                    .FAULT => unreachable, // Segmentation fault.
                    .OVERFLOW => unreachable, // We avoid passing too large of a `count`.
                    .NOTCONN => return error.BrokenPipe, // `out_fd` is an unconnected socket

                    .INVAL => {
                        // EINVAL could be any of the following situations:
                        // * Descriptor is not valid or locked
                        // * an mmap(2)-like operation is  not  available  for in_fd
                        // * count is negative
                        // * out_fd has the APPEND flag set
                        // Because of the "mmap(2)-like operation" possibility, we fall back to doing read/write
                        // manually.
                        break :sf;
                    },
                    .AGAIN => return error.WouldBlock,
                    .IO => return error.InputOutput,
                    .PIPE => return error.BrokenPipe,
                    .NOMEM => return error.SystemResources,
                    .NXIO => return error.Unseekable,
                    .SPIPE => return error.Unseekable,
                    else => |err| {
                        unexpectedErrno(err) catch {};
                        break :sf;
                    },
                }
            }

            if (trailers.len != 0) {
                total_written += try writev(out_fd, trailers);
            }

            return total_written;
        },
        .freebsd => sf: {
            var hdtr_data: std.c.sf_hdtr = undefined;
            var hdtr: ?*std.c.sf_hdtr = null;
            if (headers.len != 0 or trailers.len != 0) {
                // Here we carefully avoid `@intCast` by returning partial writes when
                // too many io vectors are provided.
                const hdr_cnt = cast(u31, headers.len) orelse maxInt(u31);
                if (headers.len > hdr_cnt) return writev(out_fd, headers);

                const trl_cnt = cast(u31, trailers.len) orelse maxInt(u31);

                hdtr_data = std.c.sf_hdtr{
                    .headers = headers.ptr,
                    .hdr_cnt = hdr_cnt,
                    .trailers = trailers.ptr,
                    .trl_cnt = trl_cnt,
                };
                hdtr = &hdtr_data;
            }

            while (true) {
                var sbytes: off_t = undefined;
                const err = errno(system.sendfile(in_fd, out_fd, @bitCast(in_offset), @min(in_len, max_count), hdtr, &sbytes, flags));
                const amt: usize = @bitCast(sbytes);
                switch (err) {
                    .SUCCESS => return amt,

                    .BADF => unreachable, // Always a race condition.
                    .FAULT => unreachable, // Segmentation fault.
                    .NOTCONN => return error.BrokenPipe, // `out_fd` is an unconnected socket

                    .INVAL, .OPNOTSUPP, .NOTSOCK, .NOSYS => {
                        // EINVAL could be any of the following situations:
                        // * The fd argument is not a regular file.
                        // * The s argument is not a SOCK.STREAM type socket.
                        // * The offset argument is negative.
                        // Because of some of these possibilities, we fall back to doing read/write
                        // manually, the same as ENOSYS.
                        break :sf;
                    },

                    .INTR => if (amt != 0) return amt else continue,

                    .AGAIN => if (amt != 0) {
                        return amt;
                    } else {
                        return error.WouldBlock;
                    },

                    .BUSY => if (amt != 0) {
                        return amt;
                    } else {
                        return error.WouldBlock;
                    },

                    .IO => return error.InputOutput,
                    .NOBUFS => return error.SystemResources,
                    .PIPE => return error.BrokenPipe,

                    else => {
                        unexpectedErrno(err) catch {};
                        if (amt != 0) {
                            return amt;
                        } else {
                            break :sf;
                        }
                    },
                }
            }
        },
        .macos, .ios, .tvos, .watchos, .visionos => sf: {
            var hdtr_data: std.c.sf_hdtr = undefined;
            var hdtr: ?*std.c.sf_hdtr = null;
            if (headers.len != 0 or trailers.len != 0) {
                // Here we carefully avoid `@intCast` by returning partial writes when
                // too many io vectors are provided.
                const hdr_cnt = cast(u31, headers.len) orelse maxInt(u31);
                if (headers.len > hdr_cnt) return writev(out_fd, headers);

                const trl_cnt = cast(u31, trailers.len) orelse maxInt(u31);

                hdtr_data = std.c.sf_hdtr{
                    .headers = headers.ptr,
                    .hdr_cnt = hdr_cnt,
                    .trailers = trailers.ptr,
                    .trl_cnt = trl_cnt,
                };
                hdtr = &hdtr_data;
            }

            while (true) {
                var sbytes: off_t = @min(in_len, max_count);
                const err = errno(system.sendfile(in_fd, out_fd, @bitCast(in_offset), &sbytes, hdtr, flags));
                const amt: usize = @bitCast(sbytes);
                switch (err) {
                    .SUCCESS => return amt,

                    .BADF => unreachable, // Always a race condition.
                    .FAULT => unreachable, // Segmentation fault.
                    .INVAL => unreachable,
                    .NOTCONN => return error.BrokenPipe, // `out_fd` is an unconnected socket

                    .OPNOTSUPP, .NOTSOCK, .NOSYS => break :sf,

                    .INTR => if (amt != 0) return amt else continue,

                    .AGAIN => if (amt != 0) {
                        return amt;
                    } else {
                        return error.WouldBlock;
                    },

                    .IO => return error.InputOutput,
                    .PIPE => return error.BrokenPipe,

                    else => {
                        unexpectedErrno(err) catch {};
                        if (amt != 0) {
                            return amt;
                        } else {
                            break :sf;
                        }
                    },
                }
            }
        },
        else => {}, // fall back to read/write
    }

    if (headers.len != 0 and !header_done) {
        const amt = try writev(out_fd, headers);
        total_written += amt;
        if (amt < count_iovec_bytes(headers)) return total_written;
    }

    rw: {
        var buf: [8 * 4096]u8 = undefined;
        // Here we match BSD behavior, making a zero count value send as many bytes as possible.
        const adjusted_count = if (in_len == 0) buf.len else @min(buf.len, in_len);
        const amt_read = try pread(in_fd, buf[0..adjusted_count], in_offset);
        if (amt_read == 0) {
            if (in_len == 0) {
                // We have detected EOF from `in_fd`.
                break :rw;
            } else {
                return total_written;
            }
        }
        const amt_written = try write(out_fd, buf[0..amt_read]);
        total_written += amt_written;
        if (amt_written < in_len or in_len == 0) return total_written;
    }

    if (trailers.len != 0) {
        total_written += try writev(out_fd, trailers);
    }

    return total_written;
}

fn count_iovec_bytes(iovs: []const iovec_const) usize {
    var count: usize = 0;
    for (iovs) |iov| {
        count += iov.len;
    }
    return count;
}

pub const CopyFileRangeError = error{
    FileTooBig,
    InputOutput,
    /// `fd_in` is not open for reading; or `fd_out` is not open  for  writing;
    /// or the  `APPEND`  flag  is  set  for `fd_out`.
    FilesOpenedWithWrongFlags,
    IsDir,
    OutOfMemory,
    NoSpaceLeft,
    Unseekable,
    PermissionDenied,
    SwapFile,
    CorruptedData,
} || PReadError || PWriteError || UnexpectedError;

/// Transfer data between file descriptors at specified offsets.
///
/// Returns the number of bytes written, which can less than requested.
///
/// The `copy_file_range` call copies `len` bytes from one file descriptor to another. When possible,
/// this is done within the operating system kernel, which can provide better performance
/// characteristics than transferring data from kernel to user space and back, such as with
/// `pread` and `pwrite` calls.
///
/// `fd_in` must be a file descriptor opened for reading, and `fd_out` must be a file descriptor
/// opened for writing. They may be any kind of file descriptor; however, if `fd_in` is not a regular
/// file system file, it may cause this function to fall back to calling `pread` and `pwrite`, in which case
/// atomicity guarantees no longer apply.
///
/// If `fd_in` and `fd_out` are the same, source and target ranges must not overlap.
/// The file descriptor seek positions are ignored and not updated.
/// When `off_in` is past the end of the input file, it successfully reads 0 bytes.
///
/// `flags` has different meanings per operating system; refer to the respective man pages.
///
/// These systems support in-kernel data copying:
/// * Linux (cross-filesystem from version 5.3)
/// * FreeBSD 13.0
///
/// Other systems fall back to calling `pread` / `pwrite`.
///
/// Maximum offsets on Linux and FreeBSD are `maxInt(i64)`.
pub fn copy_file_range(fd_in: fd_t, off_in: u64, fd_out: fd_t, off_out: u64, len: usize, flags: u32) CopyFileRangeError!usize {
    if ((comptime builtin.os.isAtLeast(.freebsd, .{ .major = 13, .minor = 0, .patch = 0 }) orelse false) or
        (comptime builtin.os.tag == .linux and std.c.versionCheck(.{ .major = 2, .minor = 27, .patch = 0 })))
    {
        var off_in_copy: i64 = @bitCast(off_in);
        var off_out_copy: i64 = @bitCast(off_out);

        while (true) {
            const rc = system.copy_file_range(fd_in, &off_in_copy, fd_out, &off_out_copy, len, flags);
            if (native_os == .freebsd) {
                switch (errno(rc)) {
                    .SUCCESS => return @intCast(rc),
                    .BADF => return error.FilesOpenedWithWrongFlags,
                    .FBIG => return error.FileTooBig,
                    .IO => return error.InputOutput,
                    .ISDIR => return error.IsDir,
                    .NOSPC => return error.NoSpaceLeft,
                    .INVAL => break, // these may not be regular files, try fallback
                    .INTEGRITY => return error.CorruptedData,
                    .INTR => continue,
                    else => |err| return unexpectedErrno(err),
                }
            } else { // assume linux
                switch (errno(rc)) {
                    .SUCCESS => return @intCast(rc),
                    .BADF => return error.FilesOpenedWithWrongFlags,
                    .FBIG => return error.FileTooBig,
                    .IO => return error.InputOutput,
                    .ISDIR => return error.IsDir,
                    .NOSPC => return error.NoSpaceLeft,
                    .INVAL => break, // these may not be regular files, try fallback
                    .NOMEM => return error.OutOfMemory,
                    .OVERFLOW => return error.Unseekable,
                    .PERM => return error.PermissionDenied,
                    .TXTBSY => return error.SwapFile,
                    .XDEV => break, // support for cross-filesystem copy added in Linux 5.3, use fallback
                    else => |err| return unexpectedErrno(err),
                }
            }
        }
    }

    var buf: [8 * 4096]u8 = undefined;
    const amt_read = try pread(fd_in, buf[0..@min(buf.len, len)], off_in);
    if (amt_read == 0) return 0;
    return pwrite(fd_out, buf[0..amt_read], off_out);
}

pub const PollError = error{
    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// The kernel had no space to allocate file descriptor tables.
    SystemResources,
} || UnexpectedError;

pub fn poll(fds: []pollfd, timeout: i32) PollError!usize {
    if (native_os == .windows) {
        switch (windows.poll(fds.ptr, @intCast(fds.len), timeout)) {
            windows.ws2_32.SOCKET_ERROR => switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAENOBUFS => return error.SystemResources,
                // TODO: handle more errors
                else => |err| return windows.unexpectedWSAError(err),
            },
            else => |rc| return @intCast(rc),
        }
    }
    while (true) {
        const fds_count = cast(nfds_t, fds.len) orelse return error.SystemResources;
        const rc = system.poll(fds.ptr, fds_count, timeout);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .FAULT => unreachable,
            .INTR => continue,
            .INVAL => unreachable,
            .NOMEM => return error.SystemResources,
            else => |err| return unexpectedErrno(err),
        }
    }
    unreachable;
}

pub const PPollError = error{
    /// The operation was interrupted by a delivery of a signal before it could complete.
    SignalInterrupt,

    /// The kernel had no space to allocate file descriptor tables.
    SystemResources,
} || UnexpectedError;

pub fn ppoll(fds: []pollfd, timeout: ?*const timespec, mask: ?*const sigset_t) PPollError!usize {
    var ts: timespec = undefined;
    var ts_ptr: ?*timespec = null;
    if (timeout) |timeout_ns| {
        ts_ptr = &ts;
        ts = timeout_ns.*;
    }
    const fds_count = cast(nfds_t, fds.len) orelse return error.SystemResources;
    const rc = system.ppoll(fds.ptr, fds_count, ts_ptr, mask);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .FAULT => unreachable,
        .INTR => return error.SignalInterrupt,
        .INVAL => unreachable,
        .NOMEM => return error.SystemResources,
        else => |err| return unexpectedErrno(err),
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

    ConnectionResetByPeer,
    ConnectionTimedOut,

    /// The socket has not been bound.
    SocketNotBound,

    /// The UDP message was too big for the buffer and part of it has been discarded
    MessageTooBig,

    /// The network subsystem has failed.
    NetworkSubsystemFailed,

    /// The socket is not connected (connection-oriented sockets only).
    SocketNotConnected,
} || UnexpectedError;

pub fn recv(sock: socket_t, buf: []u8, flags: u32) RecvFromError!usize {
    return recvfrom(sock, buf, flags, null, null);
}

/// If `sockfd` is opened in non blocking mode, the function will
/// return error.WouldBlock when EAGAIN is received.
pub fn recvfrom(
    sockfd: socket_t,
    buf: []u8,
    flags: u32,
    src_addr: ?*sockaddr,
    addrlen: ?*socklen_t,
) RecvFromError!usize {
    while (true) {
        const rc = system.recvfrom(sockfd, buf.ptr, buf.len, flags, src_addr, addrlen);
        if (native_os == .windows) {
            if (rc == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSANOTINITIALISED => unreachable,
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEINVAL => return error.SocketNotBound,
                    .WSAEMSGSIZE => return error.MessageTooBig,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENOTCONN => return error.SocketNotConnected,
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    .WSAETIMEDOUT => return error.ConnectionTimedOut,
                    // TODO: handle more errors
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                return @intCast(rc);
            }
        } else {
            switch (errno(rc)) {
                .SUCCESS => return @intCast(rc),
                .BADF => unreachable, // always a race condition
                .FAULT => unreachable,
                .INVAL => unreachable,
                .NOTCONN => return error.SocketNotConnected,
                .NOTSOCK => unreachable,
                .INTR => continue,
                .AGAIN => return error.WouldBlock,
                .NOMEM => return error.SystemResources,
                .CONNREFUSED => return error.ConnectionRefused,
                .CONNRESET => return error.ConnectionResetByPeer,
                .TIMEDOUT => return error.ConnectionTimedOut,
                else => |err| return unexpectedErrno(err),
            }
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
    var len: usize = maxInt(usize);
    const end = msg.ptr + msg.len;
    if (p == end or exp_dn.len == 0) return error.InvalidDnsPacket;
    var dest = exp_dn.ptr;
    const dend = dest + @min(exp_dn.len, 254);
    // detect reference loop using an iteration counter
    var i: usize = 0;
    while (i < msg.len) : (i += 2) {
        // loop invariants: p<end, dest<dend
        if ((p[0] & 0xc0) != 0) {
            if (p + 1 == end) return error.InvalidDnsPacket;
            const j = @as(usize, p[0] & 0x3f) << 8 | p[1];
            if (len == maxInt(usize)) len = @intFromPtr(p) + 2 - @intFromPtr(comp_dn.ptr);
            if (j >= msg.len) return error.InvalidDnsPacket;
            p = msg.ptr + j;
        } else if (p[0] != 0) {
            if (dest != exp_dn.ptr) {
                dest[0] = '.';
                dest += 1;
            }
            var j = p[0];
            p += 1;
            if (j >= @intFromPtr(end) - @intFromPtr(p) or j >= @intFromPtr(dend) - @intFromPtr(dest)) {
                return error.InvalidDnsPacket;
            }
            while (j != 0) {
                j -= 1;
                dest[0] = p[0];
                dest += 1;
                p += 1;
            }
        } else {
            dest[0] = 0;
            if (len == maxInt(usize)) len = @intFromPtr(p) + 1 - @intFromPtr(comp_dn.ptr);
            return len;
        }
    }
    return error.InvalidDnsPacket;
}

pub const SetSockOptError = error{
    /// The socket is already connected, and a specified option cannot be set while the socket is connected.
    AlreadyConnected,

    /// The option is not supported by the protocol.
    InvalidProtocolOption,

    /// The send and receive timeout values are too big to fit into the timeout fields in the socket structure.
    TimeoutTooBig,

    /// Insufficient resources are available in the system to complete the call.
    SystemResources,

    // Setting the socket option requires more elevated permissions.
    PermissionDenied,

    NetworkSubsystemFailed,
    FileDescriptorNotASocket,
    SocketNotBound,
    NoDevice,
} || UnexpectedError;

/// Set a socket's options.
pub fn setsockopt(fd: socket_t, level: i32, optname: u32, opt: []const u8) SetSockOptError!void {
    if (native_os == .windows) {
        const rc = windows.ws2_32.setsockopt(fd, level, @intCast(optname), opt.ptr, @intCast(opt.len));
        if (rc == windows.ws2_32.SOCKET_ERROR) {
            switch (windows.ws2_32.WSAGetLastError()) {
                .WSANOTINITIALISED => unreachable,
                .WSAENETDOWN => return error.NetworkSubsystemFailed,
                .WSAEFAULT => unreachable,
                .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                .WSAEINVAL => return error.SocketNotBound,
                else => |err| return windows.unexpectedWSAError(err),
            }
        }
        return;
    } else {
        switch (errno(system.setsockopt(fd, level, optname, opt.ptr, @intCast(opt.len)))) {
            .SUCCESS => {},
            .BADF => unreachable, // always a race condition
            .NOTSOCK => unreachable, // always a race condition
            .INVAL => unreachable,
            .FAULT => unreachable,
            .DOM => return error.TimeoutTooBig,
            .ISCONN => return error.AlreadyConnected,
            .NOPROTOOPT => return error.InvalidProtocolOption,
            .NOMEM => return error.SystemResources,
            .NOBUFS => return error.SystemResources,
            .PERM => return error.PermissionDenied,
            .NODEV => return error.NoDevice,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const MemFdCreateError = error{
    SystemFdQuotaExceeded,
    ProcessFdQuotaExceeded,
    OutOfMemory,
    /// Either the name provided exceeded `NAME_MAX`, or invalid flags were passed.
    NameTooLong,
} || UnexpectedError;

pub fn memfd_createZ(name: [*:0]const u8, flags: u32) MemFdCreateError!fd_t {
    switch (native_os) {
        .linux => {
            // memfd_create is available only in glibc versions starting with 2.27.
            const use_c = std.c.versionCheck(.{ .major = 2, .minor = 27, .patch = 0 });
            const sys = if (use_c) std.c else linux;
            const rc = sys.memfd_create(name, flags);
            switch (errno(rc)) {
                .SUCCESS => return @intCast(rc),
                .FAULT => unreachable, // name has invalid memory
                .INVAL => return error.NameTooLong, // or, program has a bug and flags are faulty
                .NFILE => return error.SystemFdQuotaExceeded,
                .MFILE => return error.ProcessFdQuotaExceeded,
                .NOMEM => return error.OutOfMemory,
                else => |err| return unexpectedErrno(err),
            }
        },
        .freebsd => {
            if (comptime builtin.os.version_range.semver.max.order(.{ .major = 13, .minor = 0, .patch = 0 }) == .lt)
                @compileError("memfd_create is unavailable on FreeBSD < 13.0");
            const rc = system.memfd_create(name, flags);
            switch (errno(rc)) {
                .SUCCESS => return rc,
                .BADF => unreachable, // name argument NULL
                .INVAL => unreachable, // name too long or invalid/unsupported flags.
                .MFILE => return error.ProcessFdQuotaExceeded,
                .NFILE => return error.SystemFdQuotaExceeded,
                .NOSYS => return error.SystemOutdated,
                else => |err| return unexpectedErrno(err),
            }
        },
        else => @compileError("target OS does not support memfd_create()"),
    }
}

pub fn memfd_create(name: []const u8, flags: u32) MemFdCreateError!fd_t {
    var buffer: [NAME_MAX - "memfd:".len - 1:0]u8 = undefined;
    if (name.len > buffer.len) return error.NameTooLong;
    @memcpy(buffer[0..name.len], name);
    buffer[name.len] = 0;
    return memfd_createZ(&buffer, flags);
}

pub fn getrusage(who: i32) rusage {
    var result: rusage = undefined;
    const rc = system.getrusage(who, &result);
    switch (errno(rc)) {
        .SUCCESS => return result,
        .INVAL => unreachable,
        .FAULT => unreachable,
        else => unreachable,
    }
}

pub const TIOCError = error{NotATerminal};

pub const TermiosGetError = TIOCError || UnexpectedError;

pub fn tcgetattr(handle: fd_t) TermiosGetError!termios {
    while (true) {
        var term: termios = undefined;
        switch (errno(system.tcgetattr(handle, &term))) {
            .SUCCESS => return term,
            .INTR => continue,
            .BADF => unreachable,
            .NOTTY => return error.NotATerminal,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const TermiosSetError = TermiosGetError || error{ProcessOrphaned};

pub fn tcsetattr(handle: fd_t, optional_action: TCSA, termios_p: termios) TermiosSetError!void {
    while (true) {
        switch (errno(system.tcsetattr(handle, optional_action, &termios_p))) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INTR => continue,
            .INVAL => unreachable,
            .NOTTY => return error.NotATerminal,
            .IO => return error.ProcessOrphaned,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const TermioGetPgrpError = TIOCError || UnexpectedError;

/// Returns the process group ID for the TTY associated with the given handle.
pub fn tcgetpgrp(handle: fd_t) TermioGetPgrpError!pid_t {
    while (true) {
        var pgrp: pid_t = undefined;
        switch (errno(system.tcgetpgrp(handle, &pgrp))) {
            .SUCCESS => return pgrp,
            .BADF => unreachable,
            .INVAL => unreachable,
            .INTR => continue,
            .NOTTY => return error.NotATerminal,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const TermioSetPgrpError = TermioGetPgrpError || error{NotAPgrpMember};

/// Sets the controlling process group ID for given TTY.
/// handle must be valid fd_t to a TTY associated with calling process.
/// pgrp must be a valid process group, and the calling process must be a member
/// of that group.
pub fn tcsetpgrp(handle: fd_t, pgrp: pid_t) TermioSetPgrpError!void {
    while (true) {
        switch (errno(system.tcsetpgrp(handle, &pgrp))) {
            .SUCCESS => return,
            .BADF => unreachable,
            .INVAL => unreachable,
            .INTR => continue,
            .NOTTY => return error.NotATerminal,
            .PERM => return TermioSetPgrpError.NotAPgrpMember,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub fn signalfd(fd: fd_t, mask: *const sigset_t, flags: u32) !fd_t {
    const rc = system.signalfd(fd, mask, flags);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .BADF, .INVAL => unreachable,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NOMEM => return error.SystemResources,
        .MFILE => return error.ProcessResources,
        .NODEV => return error.InodeMountFail,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SyncError = error{
    InputOutput,
    NoSpaceLeft,
    DiskQuota,
    AccessDenied,
} || UnexpectedError;

/// Write all pending file contents and metadata modifications to all filesystems.
pub fn sync() void {
    system.sync();
}

/// Write all pending file contents and metadata modifications to the filesystem which contains the specified file.
pub fn syncfs(fd: fd_t) SyncError!void {
    const rc = system.syncfs(fd);
    switch (errno(rc)) {
        .SUCCESS => return,
        .BADF, .INVAL, .ROFS => unreachable,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return unexpectedErrno(err),
    }
}

/// Write all pending file contents and metadata modifications for the specified file descriptor to the underlying filesystem.
pub fn fsync(fd: fd_t) SyncError!void {
    if (native_os == .windows) {
        if (windows.kernel32.FlushFileBuffers(fd) != 0)
            return;
        switch (windows.GetLastError()) {
            .SUCCESS => return,
            .INVALID_HANDLE => unreachable,
            .ACCESS_DENIED => return error.AccessDenied, // a sync was performed but the system couldn't update the access time
            .UNEXP_NET_ERR => return error.InputOutput,
            else => return error.InputOutput,
        }
    }
    const rc = system.fsync(fd);
    switch (errno(rc)) {
        .SUCCESS => return,
        .BADF, .INVAL, .ROFS => unreachable,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return unexpectedErrno(err),
    }
}

/// Write all pending file contents for the specified file descriptor to the underlying filesystem, but not necessarily the metadata.
pub fn fdatasync(fd: fd_t) SyncError!void {
    if (native_os == .windows) {
        return fsync(fd) catch |err| switch (err) {
            SyncError.AccessDenied => return, // fdatasync doesn't promise that the access time was synced
            else => return err,
        };
    }
    const rc = system.fdatasync(fd);
    switch (errno(rc)) {
        .SUCCESS => return,
        .BADF, .INVAL, .ROFS => unreachable,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .DQUOT => return error.DiskQuota,
        else => |err| return unexpectedErrno(err),
    }
}

pub const PrctlError = error{
    /// Can only occur with PR_SET_SECCOMP/SECCOMP_MODE_FILTER or
    /// PR_SET_MM/PR_SET_MM_EXE_FILE
    AccessDenied,
    /// Can only occur with PR_SET_MM/PR_SET_MM_EXE_FILE
    InvalidFileDescriptor,
    InvalidAddress,
    /// Can only occur with PR_SET_SPECULATION_CTRL, PR_MPX_ENABLE_MANAGEMENT,
    /// or PR_MPX_DISABLE_MANAGEMENT
    UnsupportedFeature,
    /// Can only occur with PR_SET_FP_MODE
    OperationNotSupported,
    PermissionDenied,
} || UnexpectedError;

pub fn prctl(option: PR, args: anytype) PrctlError!u31 {
    if (@typeInfo(@TypeOf(args)) != .@"struct")
        @compileError("Expected tuple or struct argument, found " ++ @typeName(@TypeOf(args)));
    if (args.len > 4)
        @compileError("prctl takes a maximum of 4 optional arguments");

    var buf: [4]usize = undefined;
    {
        comptime var i = 0;
        inline while (i < args.len) : (i += 1) buf[i] = args[i];
    }

    const rc = system.prctl(@intFromEnum(option), buf[0], buf[1], buf[2], buf[3]);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .ACCES => return error.AccessDenied,
        .BADF => return error.InvalidFileDescriptor,
        .FAULT => return error.InvalidAddress,
        .INVAL => unreachable,
        .NODEV, .NXIO => return error.UnsupportedFeature,
        .OPNOTSUPP => return error.OperationNotSupported,
        .PERM, .BUSY => return error.PermissionDenied,
        .RANGE => unreachable,
        else => |err| return unexpectedErrno(err),
    }
}

pub const GetrlimitError = UnexpectedError;

pub fn getrlimit(resource: rlimit_resource) GetrlimitError!rlimit {
    const getrlimit_sym = if (lfs64_abi) system.getrlimit64 else system.getrlimit;

    var limits: rlimit = undefined;
    switch (errno(getrlimit_sym(resource, &limits))) {
        .SUCCESS => return limits,
        .FAULT => unreachable, // bogus pointer
        .INVAL => unreachable,
        else => |err| return unexpectedErrno(err),
    }
}

pub const SetrlimitError = error{ PermissionDenied, LimitTooBig } || UnexpectedError;

pub fn setrlimit(resource: rlimit_resource, limits: rlimit) SetrlimitError!void {
    const setrlimit_sym = if (lfs64_abi) system.setrlimit64 else system.setrlimit;

    switch (errno(setrlimit_sym(resource, &limits))) {
        .SUCCESS => return,
        .FAULT => unreachable, // bogus pointer
        .INVAL => return error.LimitTooBig, // this could also mean "invalid resource", but that would be unreachable
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
}

pub const MincoreError = error{
    /// A kernel resource was temporarily unavailable.
    SystemResources,
    /// vec points to an invalid address.
    InvalidAddress,
    /// addr is not page-aligned.
    InvalidSyscall,
    /// One of the following:
    /// * length is greater than user space TASK_SIZE - addr
    /// * addr + length contains unmapped memory
    OutOfMemory,
    /// The mincore syscall is not available on this version and configuration
    /// of this UNIX-like kernel.
    MincoreUnavailable,
} || UnexpectedError;

/// Determine whether pages are resident in memory.
pub fn mincore(ptr: [*]align(mem.page_size) u8, length: usize, vec: [*]u8) MincoreError!void {
    return switch (errno(system.mincore(ptr, length, vec))) {
        .SUCCESS => {},
        .AGAIN => error.SystemResources,
        .FAULT => error.InvalidAddress,
        .INVAL => error.InvalidSyscall,
        .NOMEM => error.OutOfMemory,
        .NOSYS => error.MincoreUnavailable,
        else => |err| unexpectedErrno(err),
    };
}

pub const MadviseError = error{
    /// advice is MADV.REMOVE, but the specified address range is not a shared writable mapping.
    AccessDenied,
    /// advice is MADV.HWPOISON, but the caller does not have the CAP_SYS_ADMIN capability.
    PermissionDenied,
    /// A kernel resource was temporarily unavailable.
    SystemResources,
    /// One of the following:
    /// * addr is not page-aligned or length is negative
    /// * advice is not valid
    /// * advice is MADV.DONTNEED or MADV.REMOVE and the specified address range
    ///   includes locked, Huge TLB pages, or VM_PFNMAP pages.
    /// * advice is MADV.MERGEABLE or MADV.UNMERGEABLE, but the kernel was not
    ///   configured with CONFIG_KSM.
    /// * advice is MADV.FREE or MADV.WIPEONFORK but the specified address range
    ///   includes file, Huge TLB, MAP.SHARED, or VM_PFNMAP ranges.
    InvalidSyscall,
    /// (for MADV.WILLNEED) Paging in this area would exceed the process's
    /// maximum resident set size.
    WouldExceedMaximumResidentSetSize,
    /// One of the following:
    /// * (for MADV.WILLNEED) Not enough memory: paging in failed.
    /// * Addresses in the specified range are not currently mapped, or
    ///   are outside the address space of the process.
    OutOfMemory,
    /// The madvise syscall is not available on this version and configuration
    /// of the Linux kernel.
    MadviseUnavailable,
    /// The operating system returned an undocumented error code.
    Unexpected,
};

/// Give advice about use of memory.
/// This syscall is optional and is sometimes configured to be disabled.
pub fn madvise(ptr: [*]align(mem.page_size) u8, length: usize, advice: u32) MadviseError!void {
    switch (errno(system.madvise(ptr, length, advice))) {
        .SUCCESS => return,
        .PERM => return error.PermissionDenied,
        .ACCES => return error.AccessDenied,
        .AGAIN => return error.SystemResources,
        .BADF => unreachable, // The map exists, but the area maps something that isn't a file.
        .INVAL => return error.InvalidSyscall,
        .IO => return error.WouldExceedMaximumResidentSetSize,
        .NOMEM => return error.OutOfMemory,
        .NOSYS => return error.MadviseUnavailable,
        else => |err| return unexpectedErrno(err),
    }
}

pub const PerfEventOpenError = error{
    /// Returned if the perf_event_attr size value is too small (smaller
    /// than PERF_ATTR_SIZE_VER0), too big (larger than the page  size),
    /// or  larger  than the kernel supports and the extra bytes are not
    /// zero.  When E2BIG is returned, the perf_event_attr size field is
    /// overwritten by the kernel to be the size of the structure it was
    /// expecting.
    TooBig,
    /// Returned when the requested event requires CAP_SYS_ADMIN permis‐
    /// sions  (or a more permissive perf_event paranoid setting).  Some
    /// common cases where an unprivileged process  may  encounter  this
    /// error:  attaching  to a process owned by a different user; moni‐
    /// toring all processes on a given CPU (i.e.,  specifying  the  pid
    /// argument  as  -1); and not setting exclude_kernel when the para‐
    /// noid setting requires it.
    /// Also:
    /// Returned on many (but not all) architectures when an unsupported
    /// exclude_hv,  exclude_idle,  exclude_user, or exclude_kernel set‐
    /// ting is specified.
    /// It can also happen, as with EACCES, when the requested event re‐
    /// quires   CAP_SYS_ADMIN   permissions   (or   a  more  permissive
    /// perf_event paranoid setting).  This includes  setting  a  break‐
    /// point on a kernel address, and (since Linux 3.13) setting a ker‐
    /// nel function-trace tracepoint.
    PermissionDenied,
    /// Returned if another event already has exclusive  access  to  the
    /// PMU.
    DeviceBusy,
    /// Each  opened  event uses one file descriptor.  If a large number
    /// of events are opened, the per-process limit  on  the  number  of
    /// open file descriptors will be reached, and no more events can be
    /// created.
    ProcessResources,
    EventRequiresUnsupportedCpuFeature,
    /// Returned if  you  try  to  add  more  breakpoint
    /// events than supported by the hardware.
    TooManyBreakpoints,
    /// Returned  if PERF_SAMPLE_STACK_USER is set in sample_type and it
    /// is not supported by hardware.
    SampleStackNotSupported,
    /// Returned if an event requiring a specific  hardware  feature  is
    /// requested  but  there is no hardware support.  This includes re‐
    /// questing low-skid events if not supported, branch tracing if  it
    /// is not available, sampling if no PMU interrupt is available, and
    /// branch stacks for software events.
    EventNotSupported,
    /// Returned  if  PERF_SAMPLE_CALLCHAIN  is   requested   and   sam‐
    /// ple_max_stack   is   larger   than   the  maximum  specified  in
    /// /proc/sys/kernel/perf_event_max_stack.
    SampleMaxStackOverflow,
    /// Returned if attempting to attach to a process that does not  exist.
    ProcessNotFound,
} || UnexpectedError;

pub fn perf_event_open(
    attr: *system.perf_event_attr,
    pid: pid_t,
    cpu: i32,
    group_fd: fd_t,
    flags: usize,
) PerfEventOpenError!fd_t {
    if (native_os == .linux) {
        // There is no syscall wrapper for this function exposed by libcs
        const rc = linux.perf_event_open(attr, pid, cpu, group_fd, flags);
        switch (errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .@"2BIG" => return error.TooBig,
            .ACCES => return error.PermissionDenied,
            .BADF => unreachable, // group_fd file descriptor is not valid.
            .BUSY => return error.DeviceBusy,
            .FAULT => unreachable, // Segmentation fault.
            .INVAL => unreachable, // Bad attr settings.
            .INTR => unreachable, // Mixed perf and ftrace handling for a uprobe.
            .MFILE => return error.ProcessResources,
            .NODEV => return error.EventRequiresUnsupportedCpuFeature,
            .NOENT => unreachable, // Invalid type setting.
            .NOSPC => return error.TooManyBreakpoints,
            .NOSYS => return error.SampleStackNotSupported,
            .OPNOTSUPP => return error.EventNotSupported,
            .OVERFLOW => return error.SampleMaxStackOverflow,
            .PERM => return error.PermissionDenied,
            .SRCH => return error.ProcessNotFound,
            else => |err| return unexpectedErrno(err),
        }
    }
}

pub const TimerFdCreateError = error{
    AccessDenied,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
} || UnexpectedError;

pub const TimerFdGetError = error{InvalidHandle} || UnexpectedError;
pub const TimerFdSetError = TimerFdGetError || error{Canceled};

pub fn timerfd_create(clock_id: clockid_t, flags: system.TFD) TimerFdCreateError!fd_t {
    const rc = system.timerfd_create(clock_id, @bitCast(flags));
    return switch (errno(rc)) {
        .SUCCESS => @intCast(rc),
        .INVAL => unreachable,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
        .NODEV => return error.NoDevice,
        .NOMEM => return error.SystemResources,
        .PERM => return error.AccessDenied,
        else => |err| return unexpectedErrno(err),
    };
}

pub fn timerfd_settime(
    fd: i32,
    flags: system.TFD.TIMER,
    new_value: *const system.itimerspec,
    old_value: ?*system.itimerspec,
) TimerFdSetError!void {
    const rc = system.timerfd_settime(fd, @bitCast(flags), new_value, old_value);
    return switch (errno(rc)) {
        .SUCCESS => {},
        .BADF => error.InvalidHandle,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .CANCELED => error.Canceled,
        else => |err| return unexpectedErrno(err),
    };
}

pub fn timerfd_gettime(fd: i32) TimerFdGetError!system.itimerspec {
    var curr_value: system.itimerspec = undefined;
    const rc = system.timerfd_gettime(fd, &curr_value);
    return switch (errno(rc)) {
        .SUCCESS => return curr_value,
        .BADF => error.InvalidHandle,
        .FAULT => unreachable,
        .INVAL => unreachable,
        else => |err| return unexpectedErrno(err),
    };
}

pub const PtraceError = error{
    DeviceBusy,
    InputOutput,
    ProcessNotFound,
    PermissionDenied,
} || UnexpectedError;

pub fn ptrace(request: u32, pid: pid_t, addr: usize, signal: usize) PtraceError!void {
    if (native_os == .windows or native_os == .wasi)
        @compileError("Unsupported OS");

    return switch (native_os) {
        .linux => switch (errno(linux.ptrace(request, pid, addr, signal, 0))) {
            .SUCCESS => {},
            .SRCH => error.ProcessNotFound,
            .FAULT => unreachable,
            .INVAL => unreachable,
            .IO => return error.InputOutput,
            .PERM => error.PermissionDenied,
            .BUSY => error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        },

        .macos, .ios, .tvos, .watchos, .visionos => switch (errno(std.c.ptrace(
            @intCast(request),
            pid,
            @ptrFromInt(addr),
            @intCast(signal),
        ))) {
            .SUCCESS => {},
            .SRCH => error.ProcessNotFound,
            .INVAL => unreachable,
            .PERM => error.PermissionDenied,
            .BUSY => error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        },

        else => switch (errno(system.ptrace(request, pid, addr, signal))) {
            .SUCCESS => {},
            .SRCH => error.ProcessNotFound,
            .INVAL => unreachable,
            .PERM => error.PermissionDenied,
            .BUSY => error.DeviceBusy,
            else => |err| return unexpectedErrno(err),
        },
    };
}

pub const NameToFileHandleAtError = error{
    FileNotFound,
    NotDir,
    OperationNotSupported,
    NameTooLong,
    Unexpected,
};

pub fn name_to_handle_at(
    dirfd: fd_t,
    pathname: []const u8,
    handle: *std.os.linux.file_handle,
    mount_id: *i32,
    flags: u32,
) NameToFileHandleAtError!void {
    const pathname_c = try toPosixPath(pathname);
    return name_to_handle_atZ(dirfd, &pathname_c, handle, mount_id, flags);
}

pub fn name_to_handle_atZ(
    dirfd: fd_t,
    pathname_z: [*:0]const u8,
    handle: *std.os.linux.file_handle,
    mount_id: *i32,
    flags: u32,
) NameToFileHandleAtError!void {
    switch (errno(system.name_to_handle_at(dirfd, pathname_z, handle, mount_id, flags))) {
        .SUCCESS => {},
        .FAULT => unreachable, // pathname, mount_id, or handle outside accessible address space
        .INVAL => unreachable, // bad flags, or handle_bytes too big
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.NotDir,
        .OPNOTSUPP => return error.OperationNotSupported,
        .OVERFLOW => return error.NameTooLong,
        else => |err| return unexpectedErrno(err),
    }
}

pub const IoCtl_SIOCGIFINDEX_Error = error{
    FileSystem,
    InterfaceNotFound,
} || UnexpectedError;

pub fn ioctl_SIOCGIFINDEX(fd: fd_t, ifr: *ifreq) IoCtl_SIOCGIFINDEX_Error!void {
    while (true) {
        switch (errno(system.ioctl(fd, SIOCGIFINDEX, @intFromPtr(ifr)))) {
            .SUCCESS => return,
            .INVAL => unreachable, // Bad parameters.
            .NOTTY => unreachable,
            .NXIO => unreachable,
            .BADF => unreachable, // Always a race condition.
            .FAULT => unreachable, // Bad pointer parameter.
            .INTR => continue,
            .IO => return error.FileSystem,
            .NODEV => return error.InterfaceNotFound,
            else => |err| return unexpectedErrno(err),
        }
    }
}

const lfs64_abi = native_os == .linux and builtin.link_libc and builtin.abi.isGnu();

/// Whether or not `error.Unexpected` will print its value and a stack trace.
///
/// If this happens the fix is to add the error code to the corresponding
/// switch expression, possibly introduce a new error in the error set, and
/// send a patch to Zig.
pub const unexpected_error_tracing = builtin.zig_backend == .stage2_llvm and builtin.mode == .Debug;

pub const UnexpectedError = error{
    /// The Operating System returned an undocumented error code.
    ///
    /// This error is in theory not possible, but it would be better
    /// to handle this error than to invoke undefined behavior.
    ///
    /// When this error code is observed, it usually means the Zig Standard
    /// Library needs a small patch to add the error code to the error set for
    /// the respective function.
    Unexpected,
};

/// Call this when you made a syscall or something that sets errno
/// and you get an unexpected error.
pub fn unexpectedErrno(err: E) UnexpectedError {
    if (unexpected_error_tracing) {
        std.debug.print("unexpected errno: {d}\n", .{@intFromEnum(err)});
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}

/// Used to convert a slice to a null terminated slice on the stack.
pub fn toPosixPath(file_path: []const u8) error{NameTooLong}![PATH_MAX - 1:0]u8 {
    if (std.debug.runtime_safety) assert(mem.indexOfScalar(u8, file_path, 0) == null);
    var path_with_null: [PATH_MAX - 1:0]u8 = undefined;
    // >= rather than > to make room for the null byte
    if (file_path.len >= PATH_MAX) return error.NameTooLong;
    @memcpy(path_with_null[0..file_path.len], file_path);
    path_with_null[file_path.len] = 0;
    return path_with_null;
}
