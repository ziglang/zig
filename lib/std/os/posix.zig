//! This file contains posix abstractions and wrappers around
//! OS-specific APIs for conforming platforms, whether libc is or is not linked.
//! The purpose of this file is to have error handling for APIs which
//! don't support comparable semantics on non-posix systems like Windows.
//! Reasons are:
//!  - Fundamental flaws (signaling, process management)
//!  - More extensive execution semantics (permission system, memory management, ipc)
//! With above restrictions, the same goals as for os.zig apply.

const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const math = std.math;
const mem = std.mem;
const os = std.os;

const wasi = os.wasi;

const UnexpectedError = os.UnexpectedError;
const errno = os.errno;
const fd_t = os.fd_t;
const gid_t = os.gid_t;
const mode_t = os.mode_t;
const pid_t = os.pid_t;
const rlimit = os.rlimit;
const rlimit_resource = os.rlimit_resource;
const rusage = os.rusage;
const sigset_t = os.sigset_t;
const stack_t = os.stack_t;
const system = os.system;
const termios = os.termios;
const timespec = os.timespec;
const uid_t = os.uid_t;
const utsname = os.utsname;
const Sigaction = os.Sigaction;
const E = os.E;
const F = os.F;
const FD_CLOEXEC = os.FD_CLOEXEC;
const O = os.O;
const TCSA = os.TCSA;
const unexpectedErrno = os.unexpectedErrno;

pub const FChmodError = error{
    AccessDenied,
    InputOutput,
    SymLinkLoop,
    FileNotFound,
    SystemResources,
    ReadOnlyFileSystem,
} || UnexpectedError;

/// Changes the mode of the file referred to by the file descriptor.
/// The process must have the correct privileges in order to do this
/// successfully, or must have the effective user ID matching the owner
/// of the file.
pub fn fchmod(fd: fd_t, mode: mode_t) FChmodError!void {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        @compileError("Unsupported OS");

    while (true) {
        const res = system.fchmod(fd, mode);

        switch (system.getErrno(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable, // Can be reached if the fd refers to a non-iterable directory.

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

const FChmodAtError = FChmodError || error{
    NameTooLong,
};

pub fn fchmodat(dirfd: fd_t, path: []const u8, mode: mode_t, flags: u32) FChmodAtError!void {
    if (!std.fs.has_executable_bit) @compileError("fchmodat unsupported by target OS");

    const path_c = try os.toPosixPath(path);

    while (true) {
        const res = system.fchmodat(dirfd, &path_c, mode, flags);

        switch (system.getErrno(res)) {
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
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        @compileError("Unsupported OS");

    while (true) {
        const res = system.fchown(fd, owner orelse @as(u32, 0) -% 1, group orelse @as(u32, 0) -% 1);

        switch (system.getErrno(res)) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => unreachable, // Can be reached if the fd refers to a non-iterable directory.

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

pub const KillError = error{PermissionDenied} || UnexpectedError;

pub fn kill(pid: pid_t, sig: u8) KillError!void {
    switch (errno(system.kill(pid, sig))) {
        .SUCCESS => return,
        .INVAL => unreachable, // invalid signal
        .PERM => return error.PermissionDenied,
        .SRCH => unreachable, // always a race condition
        else => |err| return unexpectedErrno(err),
    }
}

/// Duplicate file descriptor.
pub fn dup(old_fd: fd_t) !fd_t {
    const rc = system.dup(old_fd);
    return switch (errno(rc)) {
        .SUCCESS => return @intCast(fd_t, rc),
        .MFILE => error.ProcessFdQuotaExceeded,
        .BADF => unreachable, // invalid file descriptor
        else => |err| return unexpectedErrno(err),
    };
}

/// Assign file descriptor.
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
        else => |err| switch (builtin.os.tag) {
            .macos, .ios, .tvos, .watchos => switch (err) {
                .BADEXEC => return error.InvalidExe,
                .BADARCH => return error.InvalidExe,
                else => return unexpectedErrno(err),
            },
            .linux, .solaris => switch (err) {
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

    const PATH = os.getenvZ("PATH") orelse "/usr/local/bin:/bin/:/usr/bin";
    // Use of MAX_PATH_BYTES here is valid as the path_buf will be passed
    // directly to the operating system in execveZ.
    var path_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    var it = mem.tokenize(u8, PATH, ":");
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
        mem.copy(u8, &path_buf, search_path);
        path_buf[search_path.len] = '/';
        mem.copy(u8, path_buf[search_path.len + 1 ..], file_slice);
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

pub const WaitPidResult = struct {
    pid: pid_t,
    status: u32,
};

/// Use this version of the `waitpid` wrapper if you spawned your child process using explicit
/// `fork` and `execve` method.
pub fn waitpid(pid: pid_t, flags: u32) WaitPidResult {
    const Status = if (builtin.link_libc) c_int else u32;
    var status: Status = undefined;
    while (true) {
        const rc = system.waitpid(pid, &status, if (builtin.link_libc) @intCast(c_int, flags) else flags);
        switch (errno(rc)) {
            .SUCCESS => return .{
                .pid = @intCast(pid_t, rc),
                .status = @bitCast(u32, status),
            },
            .INTR => continue,
            .CHILD => unreachable, // The process specified does not exist. It would be a race condition to handle this error.
            .INVAL => unreachable, // Invalid flags.
            else => unreachable,
        }
    }
}

pub const ForkError = error{SystemResources} || UnexpectedError;

pub fn fork() ForkError!pid_t {
    const rc = system.fork();
    switch (errno(rc)) {
        .SUCCESS => return @intCast(pid_t, rc),
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
    /// and `PROT_WRITE` is set, but the file descriptor is not open in `O.RDWR` mode.
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
    flags: u32,
    fd: fd_t,
    offset: u64,
) MMapError![]align(mem.page_size) u8 {
    const mmap_sym = if (builtin.os.tag == .linux and builtin.link_libc)
        system.mmap64
    else
        system.mmap;

    const ioffset = @bitCast(i64, offset); // the OS treats this as unsigned
    const rc = mmap_sym(ptr, length, prot, flags, fd, ioffset);
    const err = if (builtin.link_libc) blk: {
        if (rc != std.c.MAP.FAILED) return @ptrCast([*]align(mem.page_size) u8, @alignCast(mem.page_size, rc))[0..length];
        break :blk @intToEnum(E, system._errno().*);
    } else blk: {
        const err = errno(rc);
        if (err == .SUCCESS) return @intToPtr([*]align(mem.page_size) u8, rc)[0..length];
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
        .NOMEM => return error.OutOfMemory,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NFILE => return error.SystemFdQuotaExceeded,
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
} || UnexpectedError;

pub fn msync(memory: []align(mem.page_size) u8, flags: i32) MSyncError!void {
    switch (errno(system.msync(memory.ptr, memory.len, flags))) {
        .SUCCESS => return,
        .NOMEM => return error.UnmappedMemory, // Unsuccessful, provided pointer does not point mapped memory
        .INVAL => unreachable, // Invalid parameters.
        else => unreachable,
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

pub fn pipe2(flags: u32) PipeError![2]fd_t {
    if (@hasDecl(system, "pipe2")) {
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

    var fds: [2]fd_t = try pipe();
    errdefer {
        os.close(fds[0]);
        os.close(fds[1]);
    }

    if (flags == 0)
        return fds;

    // O.CLOEXEC is special, it's a file descriptor flag and must be set using
    // F.SETFD.
    if (flags & O.CLOEXEC != 0) {
        for (fds) |fd| {
            switch (errno(system.fcntl(fd, F.SETFD, @as(u32, FD_CLOEXEC)))) {
                .SUCCESS => {},
                .INVAL => unreachable, // Invalid flags
                .BADF => unreachable, // Always a race condition
                else => |err| return unexpectedErrno(err),
            }
        }
    }

    const new_flags = flags & ~@as(u32, O.CLOEXEC);
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
            .SUCCESS => return @intCast(usize, rc),
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
pub fn sigaction(sig: u6, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) error{OperationNotSupported}!void {
    switch (errno(system.sigaction(sig, act, oact))) {
        .SUCCESS => return,
        .INVAL, .NOSYS => return error.OperationNotSupported,
        else => unreachable,
    }
}

/// Sets the thread signal mask.
pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) void {
    switch (errno(system.sigprocmask(flags, set, oldset))) {
        .SUCCESS => return,
        .FAULT => unreachable,
        .INVAL => unreachable,
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
    if (builtin.os.tag == .wasi and !builtin.link_libc) {
        // TODO WASI encodes `wasi.fstflags` to signify magic values
        // similar to UTIME_NOW and UTIME_OMIT. Currently, we ignore
        // this here, but we should really handle it somehow.
        const atim = times[0].toTimestamp();
        const mtim = times[1].toTimestamp();
        switch (wasi.fd_filestat_set_times(fd, atim, mtim, wasi.FILESTAT_SET_ATIM | wasi.FILESTAT_SET_MTIM)) {
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

pub fn uname() utsname {
    var uts: utsname = undefined;
    switch (errno(system.uname(&uts))) {
        .SUCCESS => return uts,
        .FAULT => unreachable,
        else => unreachable,
    }
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

pub const TermiosGetError = error{NotATerminal} || UnexpectedError;

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

pub const GetrlimitError = UnexpectedError;

pub fn getrlimit(resource: rlimit_resource) GetrlimitError!rlimit {
    const getrlimit_sym = if (builtin.os.tag == .linux and builtin.link_libc)
        system.getrlimit64
    else
        system.getrlimit;

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
    const setrlimit_sym = if (builtin.os.tag == .linux and builtin.link_libc)
        system.setrlimit64
    else
        system.setrlimit;

    switch (errno(setrlimit_sym(resource, &limits))) {
        .SUCCESS => return,
        .FAULT => unreachable, // bogus pointer
        .INVAL => return error.LimitTooBig, // this could also mean "invalid resource", but that would be unreachable
        .PERM => return error.PermissionDenied,
        else => |err| return unexpectedErrno(err),
    }
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
