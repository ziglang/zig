//! This file provides the system interface functions for Linux matching those
//! that are provided by libc, whether or not libc is linked. The following
//! abstractions are made:
//! * Work around kernel bugs and limitations. For example, see sendmmsg.
//! * Implement all the syscalls in the same way that libc functions will
//!   provide `rename` when only the `renameat` syscall exists.
//! * Does not support POSIX thread cancellation.
const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const elf = std.elf;
const vdso = @import("linux/vdso.zig");
const dl = @import("../dynamic_library.zig");
const native_arch = builtin.cpu.arch;
const native_endian = native_arch.endian();
const is_mips = native_arch.isMIPS();
const is_ppc = native_arch.isPPC();
const is_ppc64 = native_arch.isPPC64();
const is_sparc = native_arch.isSPARC();
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const ACCMODE = std.posix.ACCMODE;

test {
    if (builtin.os.tag == .linux) {
        _ = @import("linux/test.zig");
    }
}

const syscall_bits = switch (native_arch) {
    .thumb => @import("linux/thumb.zig"),
    else => arch_bits,
};

const arch_bits = switch (native_arch) {
    .x86 => @import("linux/x86.zig"),
    .x86_64 => @import("linux/x86_64.zig"),
    .aarch64, .aarch64_be => @import("linux/arm64.zig"),
    .arm, .thumb => @import("linux/arm-eabi.zig"),
    .riscv64 => @import("linux/riscv64.zig"),
    .sparc64 => @import("linux/sparc64.zig"),
    .mips, .mipsel => @import("linux/mips.zig"),
    .mips64, .mips64el => @import("linux/mips64.zig"),
    .powerpc, .powerpcle => @import("linux/powerpc.zig"),
    .powerpc64, .powerpc64le => @import("linux/powerpc64.zig"),
    else => struct {},
};
pub const syscall0 = syscall_bits.syscall0;
pub const syscall1 = syscall_bits.syscall1;
pub const syscall2 = syscall_bits.syscall2;
pub const syscall3 = syscall_bits.syscall3;
pub const syscall4 = syscall_bits.syscall4;
pub const syscall5 = syscall_bits.syscall5;
pub const syscall6 = syscall_bits.syscall6;
pub const syscall7 = syscall_bits.syscall7;
pub const restore = syscall_bits.restore;
pub const restore_rt = syscall_bits.restore_rt;
pub const socketcall = syscall_bits.socketcall;
pub const syscall_pipe = syscall_bits.syscall_pipe;
pub const syscall_fork = syscall_bits.syscall_fork;

pub const ARCH = arch_bits.ARCH;
pub const Elf_Symndx = arch_bits.Elf_Symndx;
pub const F = arch_bits.F;
pub const Flock = arch_bits.Flock;
pub const HWCAP = arch_bits.HWCAP;
pub const LOCK = arch_bits.LOCK;
pub const MMAP2_UNIT = arch_bits.MMAP2_UNIT;
pub const REG = arch_bits.REG;
pub const SC = arch_bits.SC;
pub const Stat = arch_bits.Stat;
pub const VDSO = arch_bits.VDSO;
pub const blkcnt_t = arch_bits.blkcnt_t;
pub const blksize_t = arch_bits.blksize_t;
pub const clone = arch_bits.clone;
pub const dev_t = arch_bits.dev_t;
pub const ino_t = arch_bits.ino_t;
pub const mcontext_t = arch_bits.mcontext_t;
pub const mode_t = arch_bits.mode_t;
pub const msghdr = arch_bits.msghdr;
pub const msghdr_const = arch_bits.msghdr_const;
pub const nlink_t = arch_bits.nlink_t;
pub const off_t = arch_bits.off_t;
pub const time_t = arch_bits.time_t;
pub const timeval = arch_bits.timeval;
pub const timezone = arch_bits.timezone;
pub const ucontext_t = arch_bits.ucontext_t;
pub const user_desc = arch_bits.user_desc;
pub const getcontext = arch_bits.getcontext;

pub const tls = @import("linux/tls.zig");
pub const pie = @import("linux/start_pie.zig");
pub const BPF = @import("linux/bpf.zig");
pub const IOCTL = @import("linux/ioctl.zig");
pub const SECCOMP = @import("linux/seccomp.zig");

pub const syscalls = @import("linux/syscalls.zig");
pub const SYS = switch (@import("builtin").cpu.arch) {
    .x86 => syscalls.X86,
    .x86_64 => syscalls.X64,
    .aarch64, .aarch64_be => syscalls.Arm64,
    .arm, .thumb => syscalls.Arm,
    .riscv64 => syscalls.RiscV64,
    .sparc64 => syscalls.Sparc64,
    .mips, .mipsel => syscalls.Mips,
    .mips64, .mips64el => syscalls.Mips64,
    .powerpc, .powerpcle => syscalls.PowerPC,
    .powerpc64, .powerpc64le => syscalls.PowerPC64,
    else => @compileError("The Zig Standard Library is missing syscall definitions for the target CPU architecture"),
};

pub const MAP_TYPE = enum(u4) {
    SHARED = 0x01,
    PRIVATE = 0x02,
    SHARED_VALIDATE = 0x03,
};

pub const MAP = switch (native_arch) {
    .x86_64, .x86 => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        @"32BIT": bool = false,
        _7: u1 = 0,
        GROWSDOWN: bool = false,
        _9: u2 = 0,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        LOCKED: bool = false,
        NORESERVE: bool = false,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    .aarch64, .aarch64_be, .arm, .thumb => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        _6: u2 = 0,
        GROWSDOWN: bool = false,
        _9: u2 = 0,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        LOCKED: bool = false,
        NORESERVE: bool = false,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    .riscv64 => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        _6: u9 = 0,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    .sparc64 => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        NORESERVE: bool = false,
        _7: u1 = 0,
        LOCKED: bool = false,
        GROWSDOWN: bool = false,
        _10: u1 = 0,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        _13: u2 = 0,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        _5: u1 = 0,
        @"32BIT": bool = false,
        _7: u3 = 0,
        NORESERVE: bool = false,
        ANONYMOUS: bool = false,
        GROWSDOWN: bool = false,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        LOCKED: bool = false,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        NORESERVE: bool = false,
        LOCKED: bool = false,
        GROWSDOWN: bool = false,
        _9: u2 = 0,
        DENYWRITE: bool = false,
        EXECUTABLE: bool = false,
        _13: u2 = 0,
        POPULATE: bool = false,
        NONBLOCK: bool = false,
        STACK: bool = false,
        HUGETLB: bool = false,
        SYNC: bool = false,
        FIXED_NOREPLACE: bool = false,
        _21: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    else => @compileError("missing std.os.linux.MAP constants for this architecture"),
};

pub const O = switch (native_arch) {
    .x86_64 => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u4 = 0,
        CREAT: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NONBLOCK: bool = false,
        DSYNC: bool = false,
        ASYNC: bool = false,
        DIRECT: bool = false,
        _15: u1 = 0,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    .x86, .riscv64 => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u4 = 0,
        CREAT: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NONBLOCK: bool = false,
        DSYNC: bool = false,
        ASYNC: bool = false,
        DIRECT: bool = false,
        LARGEFILE: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    .aarch64, .aarch64_be, .arm, .thumb => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u4 = 0,
        CREAT: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NONBLOCK: bool = false,
        DSYNC: bool = false,
        ASYNC: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        DIRECT: bool = false,
        LARGEFILE: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    .sparc64 => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u1 = 0,
        APPEND: bool = false,
        _4: u2 = 0,
        ASYNC: bool = false,
        _7: u2 = 0,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        _12: u1 = 0,
        DSYNC: bool = false,
        NONBLOCK: bool = false,
        NOCTTY: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        _18: u2 = 0,
        DIRECT: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u6 = 0,
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u1 = 0,
        APPEND: bool = false,
        DSYNC: bool = false,
        _5: u2 = 0,
        NONBLOCK: bool = false,
        CREAT: bool = false,
        TRUNC: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        ASYNC: bool = false,
        LARGEFILE: bool = false,
        SYNC: bool = false,
        DIRECT: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        _20: u1 = 0,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        ACCMODE: ACCMODE = .RDONLY,
        _2: u4 = 0,
        CREAT: bool = false,
        EXCL: bool = false,
        NOCTTY: bool = false,
        TRUNC: bool = false,
        APPEND: bool = false,
        NONBLOCK: bool = false,
        DSYNC: bool = false,
        ASYNC: bool = false,
        DIRECTORY: bool = false,
        NOFOLLOW: bool = false,
        LARGEFILE: bool = false,
        DIRECT: bool = false,
        NOATIME: bool = false,
        CLOEXEC: bool = false,
        SYNC: bool = false,
        PATH: bool = false,
        TMPFILE: bool = false,
        _: u9 = 0,
    },
    else => @compileError("missing std.os.linux.O constants for this architecture"),
};

/// Set by startup code, used by `getauxval`.
pub var elf_aux_maybe: ?[*]std.elf.Auxv = null;

const extern_getauxval = switch (builtin.zig_backend) {
    // Calling extern functions is not yet supported with these backends
    .stage2_aarch64, .stage2_arm, .stage2_riscv64, .stage2_sparc64 => false,
    else => !builtin.link_libc,
};

comptime {
    if (extern_getauxval) {
        @export(getauxvalImpl, .{ .name = "getauxval", .linkage = .weak });
    }
}

pub const getauxval = if (extern_getauxval) struct {
    extern fn getauxval(index: usize) usize;
}.getauxval else getauxvalImpl;

fn getauxvalImpl(index: usize) callconv(.C) usize {
    const auxv = elf_aux_maybe orelse return 0;
    var i: usize = 0;
    while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
        if (auxv[i].a_type == index)
            return auxv[i].a_un.a_val;
    }
    return 0;
}

// Some architectures (and some syscalls) require 64bit parameters to be passed
// in a even-aligned register pair.
const require_aligned_register_pair =
    builtin.cpu.arch.isPPC() or
    builtin.cpu.arch.isMIPS() or
    builtin.cpu.arch.isARM() or
    builtin.cpu.arch.isThumb();

// Split a 64bit value into a {LSB,MSB} pair.
// The LE/BE variants specify the endianness to assume.
fn splitValueLE64(val: i64) [2]u32 {
    const u: u64 = @bitCast(val);
    return [2]u32{
        @as(u32, @truncate(u)),
        @as(u32, @truncate(u >> 32)),
    };
}
fn splitValueBE64(val: i64) [2]u32 {
    const u: u64 = @bitCast(val);
    return [2]u32{
        @as(u32, @truncate(u >> 32)),
        @as(u32, @truncate(u)),
    };
}
fn splitValue64(val: i64) [2]u32 {
    const u: u64 = @bitCast(val);
    switch (native_endian) {
        .little => return [2]u32{
            @as(u32, @truncate(u)),
            @as(u32, @truncate(u >> 32)),
        },
        .big => return [2]u32{
            @as(u32, @truncate(u >> 32)),
            @as(u32, @truncate(u)),
        },
    }
}

/// Get the errno from a syscall return value, or 0 for no error.
/// The public API is exposed via the `E` namespace.
fn errnoFromSyscall(r: usize) E {
    const signed_r: isize = @bitCast(r);
    const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
    return @enumFromInt(int);
}

pub fn dup(old: i32) usize {
    return syscall1(.dup, @as(usize, @bitCast(@as(isize, old))));
}

pub fn dup2(old: i32, new: i32) usize {
    if (@hasField(SYS, "dup2")) {
        return syscall2(.dup2, @as(usize, @bitCast(@as(isize, old))), @as(usize, @bitCast(@as(isize, new))));
    } else {
        if (old == new) {
            if (std.debug.runtime_safety) {
                const rc = syscall2(.fcntl, @as(usize, @bitCast(@as(isize, old))), F.GETFD);
                if (@as(isize, @bitCast(rc)) < 0) return rc;
            }
            return @as(usize, @intCast(old));
        } else {
            return syscall3(.dup3, @as(usize, @bitCast(@as(isize, old))), @as(usize, @bitCast(@as(isize, new))), 0);
        }
    }
}

pub fn dup3(old: i32, new: i32, flags: u32) usize {
    return syscall3(.dup3, @as(usize, @bitCast(@as(isize, old))), @as(usize, @bitCast(@as(isize, new))), flags);
}

pub fn chdir(path: [*:0]const u8) usize {
    return syscall1(.chdir, @intFromPtr(path));
}

pub fn fchdir(fd: fd_t) usize {
    return syscall1(.fchdir, @as(usize, @bitCast(@as(isize, fd))));
}

pub fn chroot(path: [*:0]const u8) usize {
    return syscall1(.chroot, @intFromPtr(path));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) usize {
    return syscall3(.execve, @intFromPtr(path), @intFromPtr(argv), @intFromPtr(envp));
}

pub fn fork() usize {
    if (comptime native_arch.isSPARC()) {
        return syscall_fork();
    } else if (@hasField(SYS, "fork")) {
        return syscall0(.fork);
    } else {
        return syscall2(.clone, SIG.CHLD, 0);
    }
}

/// This must be inline, and inline call the syscall function, because if the
/// child does a return it will clobber the parent's stack.
/// It is advised to avoid this function and use clone instead, because
/// the compiler is not aware of how vfork affects control flow and you may
/// see different results in optimized builds.
pub inline fn vfork() usize {
    return @call(.always_inline, syscall0, .{.vfork});
}

pub fn futimens(fd: i32, times: *const [2]timespec) usize {
    return utimensat(fd, null, times, 0);
}

pub fn utimensat(dirfd: i32, path: ?[*:0]const u8, times: *const [2]timespec, flags: u32) usize {
    return syscall4(.utimensat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), @intFromPtr(times), flags);
}

pub fn fallocate(fd: i32, mode: i32, offset: i64, length: i64) usize {
    if (usize_bits < 64) {
        const offset_halves = splitValue64(offset);
        const length_halves = splitValue64(length);
        return syscall6(
            .fallocate,
            @as(usize, @bitCast(@as(isize, fd))),
            @as(usize, @bitCast(@as(isize, mode))),
            offset_halves[0],
            offset_halves[1],
            length_halves[0],
            length_halves[1],
        );
    } else {
        return syscall4(
            .fallocate,
            @as(usize, @bitCast(@as(isize, fd))),
            @as(usize, @bitCast(@as(isize, mode))),
            @as(u64, @bitCast(offset)),
            @as(u64, @bitCast(length)),
        );
    }
}

pub fn futex_wait(uaddr: *const i32, futex_op: u32, val: i32, timeout: ?*const timespec) usize {
    return syscall4(.futex, @intFromPtr(uaddr), futex_op, @as(u32, @bitCast(val)), @intFromPtr(timeout));
}

pub fn futex_wake(uaddr: *const i32, futex_op: u32, val: i32) usize {
    return syscall3(.futex, @intFromPtr(uaddr), futex_op, @as(u32, @bitCast(val)));
}

/// Given an array of `futex_waitv`, wait on each uaddr.
/// The thread wakes if a futex_wake() is performed at any uaddr.
/// The syscall returns immediately if any waiter has *uaddr != val.
/// timeout is an optional timeout value for the operation.
/// Each waiter has individual flags.
/// The `flags` argument for the syscall should be used solely for specifying
/// the timeout as realtime, if needed.
/// Flags for private futexes, sizes, etc. should be used on the
/// individual flags of each waiter.
///
/// Returns the array index of one of the woken futexes.
/// No further information is provided: any number of other futexes may also
/// have been woken by the same event, and if more than one futex was woken,
/// the retrned index may refer to any one of them.
/// (It is not necessaryily the futex with the smallest index, nor the one
/// most recently woken, nor...)
pub fn futex2_waitv(
    /// List of futexes to wait on.
    waiters: [*]futex_waitv,
    /// Length of `waiters`.
    nr_futexes: u32,
    /// Flag for timeout (monotonic/realtime).
    flags: u32,
    /// Optional absolute timeout.
    timeout: ?*const timespec,
    /// Clock to be used for the timeout, realtime or monotonic.
    clockid: i32,
) usize {
    return syscall6(
        .futex_waitv,
        @intFromPtr(waiters),
        nr_futexes,
        flags,
        @intFromPtr(timeout),
        @bitCast(@as(isize, clockid)),
    );
}

/// Wait on a futex.
/// Identical to `FUTEX.WAIT`, except it is part of the futex2 family of calls.
pub fn futex2_wait(
    /// Address of the futex to wait on.
    uaddr: *const anyopaque,
    /// Value of `uaddr`.
    val: usize,
    /// Bitmask.
    mask: usize,
    /// `FUTEX2` flags.
    flags: u32,
    /// Optional absolute timeout.
    timeout: *const timespec,
    /// Clock to be used for the timeout, realtime or monotonic.
    clockid: i32,
) usize {
    return syscall6(
        .futex_wait,
        @intFromPtr(uaddr),
        val,
        mask,
        flags,
        @intFromPtr(timeout),
        @bitCast(@as(isize, clockid)),
    );
}

/// Wake a number of futexes.
/// Identical to `FUTEX.WAKE`, except it is part of the futex2 family of calls.
pub fn futex2_wake(
    /// Address of the futex(es) to wake.
    uaddr: [*]const anyopaque,
    /// Bitmask
    mask: usize,
    /// Number of the futexes to wake.
    nr: i32,
    /// `FUTEX2` flags.
    flags: u32,
) usize {
    return syscall4(
        .futex_wake,
        @intFromPtr(uaddr),
        mask,
        @bitCast(@as(isize, nr)),
        flags,
    );
}

/// Requeue a waiter from one futex to another.
/// Identical to `FUTEX.CMP_REQUEUE`, except it is part of the futex2 family of calls.
pub fn futex2_requeue(
    /// Array describing the source and destination futex.
    waiters: [*]futex_waitv,
    /// Unsed.
    flags: u32,
    /// Number of futexes to wake.
    nr_wake: i32,
    /// Number of futexes to requeue.
    nr_requeue: i32,
) usize {
    return syscall4(
        .futex_requeue,
        @intFromPtr(waiters),
        flags,
        @bitCast(@as(isize, nr_wake)),
        @bitCast(@as(isize, nr_requeue)),
    );
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return syscall2(.getcwd, @intFromPtr(buf), size);
}

pub fn getdents(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        .getdents,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(dirp),
        @min(len, maxInt(c_int)),
    );
}

pub fn getdents64(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        .getdents64,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(dirp),
        @min(len, maxInt(c_int)),
    );
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(.inotify_init1, flags);
}

pub fn inotify_add_watch(fd: i32, pathname: [*:0]const u8, mask: u32) usize {
    return syscall3(.inotify_add_watch, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(pathname), mask);
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(.inotify_rm_watch, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, wd))));
}

pub fn fanotify_init(flags: u32, event_f_flags: u32) usize {
    return syscall2(.fanotify_init, flags, event_f_flags);
}

pub fn fanotify_mark(fd: i32, flags: u32, mask: u64, dirfd: i32, pathname: ?[*:0]const u8) usize {
    return syscall5(.fanotify_mark, @as(usize, @bitCast(@as(isize, fd))), flags, mask, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(pathname));
}

pub fn readlink(noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    if (@hasField(SYS, "readlink")) {
        return syscall3(.readlink, @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
    } else {
        return syscall4(.readlinkat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
    }
}

pub fn readlinkat(dirfd: i32, noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(.readlinkat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
}

pub fn mkdir(path: [*:0]const u8, mode: u32) usize {
    if (@hasField(SYS, "mkdir")) {
        return syscall2(.mkdir, @intFromPtr(path), mode);
    } else {
        return syscall3(.mkdirat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(path), mode);
    }
}

pub fn mkdirat(dirfd: i32, path: [*:0]const u8, mode: u32) usize {
    return syscall3(.mkdirat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode);
}

pub fn mknod(path: [*:0]const u8, mode: u32, dev: u32) usize {
    if (@hasField(SYS, "mknod")) {
        return syscall3(.mknod, @intFromPtr(path), mode, dev);
    } else {
        return mknodat(AT.FDCWD, path, mode, dev);
    }
}

pub fn mknodat(dirfd: i32, path: [*:0]const u8, mode: u32, dev: u32) usize {
    return syscall4(.mknodat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode, dev);
}

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: ?[*:0]const u8, flags: u32, data: usize) usize {
    return syscall5(.mount, @intFromPtr(special), @intFromPtr(dir), @intFromPtr(fstype), flags, data);
}

pub fn umount(special: [*:0]const u8) usize {
    return syscall2(.umount2, @intFromPtr(special), 0);
}

pub fn umount2(special: [*:0]const u8, flags: u32) usize {
    return syscall2(.umount2, @intFromPtr(special), flags);
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: MAP, fd: i32, offset: i64) usize {
    if (@hasField(SYS, "mmap2")) {
        // Make sure the offset is also specified in multiples of page size
        if ((offset & (MMAP2_UNIT - 1)) != 0)
            return @bitCast(-@as(isize, @intFromEnum(E.INVAL)));

        return syscall6(
            .mmap2,
            @intFromPtr(address),
            length,
            prot,
            @as(u32, @bitCast(flags)),
            @bitCast(@as(isize, fd)),
            @truncate(@as(u64, @bitCast(offset)) / MMAP2_UNIT),
        );
    } else {
        return syscall6(
            .mmap,
            @intFromPtr(address),
            length,
            prot,
            @as(u32, @bitCast(flags)),
            @bitCast(@as(isize, fd)),
            @as(u64, @bitCast(offset)),
        );
    }
}

pub fn mprotect(address: [*]const u8, length: usize, protection: usize) usize {
    return syscall3(.mprotect, @intFromPtr(address), length, protection);
}

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

pub fn msync(address: [*]const u8, length: usize, flags: i32) usize {
    return syscall3(.msync, @intFromPtr(address), length, @as(u32, @bitCast(flags)));
}

pub fn munmap(address: [*]const u8, length: usize) usize {
    return syscall2(.munmap, @intFromPtr(address), length);
}

pub fn poll(fds: [*]pollfd, n: nfds_t, timeout: i32) usize {
    if (@hasField(SYS, "poll")) {
        return syscall3(.poll, @intFromPtr(fds), n, @as(u32, @bitCast(timeout)));
    } else {
        return syscall5(
            .ppoll,
            @intFromPtr(fds),
            n,
            @intFromPtr(if (timeout >= 0)
                &timespec{
                    .tv_sec = @divTrunc(timeout, 1000),
                    .tv_nsec = @rem(timeout, 1000) * 1000000,
                }
            else
                null),
            0,
            NSIG / 8,
        );
    }
}

pub fn ppoll(fds: [*]pollfd, n: nfds_t, timeout: ?*timespec, sigmask: ?*const sigset_t) usize {
    return syscall5(.ppoll, @intFromPtr(fds), n, @intFromPtr(timeout), @intFromPtr(sigmask), NSIG / 8);
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return syscall3(.read, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(buf), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: i64) usize {
    const offset_u: u64 = @bitCast(offset);
    return syscall5(
        .preadv,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(iov),
        count,
        // Kernel expects the offset is split into largest natural word-size.
        // See following link for detail:
        // https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=601cc11d054ae4b5e9b5babec3d8e4667a2cb9b5
        @as(usize, @truncate(offset_u)),
        if (usize_bits < 64) @as(usize, @truncate(offset_u >> 32)) else 0,
    );
}

pub fn preadv2(fd: i32, iov: [*]const iovec, count: usize, offset: i64, flags: kernel_rwf) usize {
    const offset_u: u64 = @bitCast(offset);
    return syscall6(
        .preadv2,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(iov),
        count,
        // See comments in preadv
        @as(usize, @truncate(offset_u)),
        if (usize_bits < 64) @as(usize, @truncate(offset_u >> 32)) else 0,
        flags,
    );
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(.readv, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(.writev, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(iov), count);
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: i64) usize {
    const offset_u: u64 = @bitCast(offset);
    return syscall5(
        .pwritev,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(iov),
        count,
        // See comments in preadv
        @as(usize, @truncate(offset_u)),
        if (usize_bits < 64) @as(usize, @truncate(offset_u >> 32)) else 0,
    );
}

pub fn pwritev2(fd: i32, iov: [*]const iovec_const, count: usize, offset: i64, flags: kernel_rwf) usize {
    const offset_u: u64 = @bitCast(offset);
    return syscall6(
        .pwritev2,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(iov),
        count,
        // See comments in preadv
        @as(usize, @truncate(offset_u)),
        if (usize_bits < 64) @as(usize, @truncate(offset_u >> 32)) else 0,
        flags,
    );
}

pub fn rmdir(path: [*:0]const u8) usize {
    if (@hasField(SYS, "rmdir")) {
        return syscall1(.rmdir, @intFromPtr(path));
    } else {
        return syscall3(.unlinkat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(path), AT.REMOVEDIR);
    }
}

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasField(SYS, "symlink")) {
        return syscall2(.symlink, @intFromPtr(existing), @intFromPtr(new));
    } else {
        return syscall3(.symlinkat, @intFromPtr(existing), @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(new));
    }
}

pub fn symlinkat(existing: [*:0]const u8, newfd: i32, newpath: [*:0]const u8) usize {
    return syscall3(.symlinkat, @intFromPtr(existing), @as(usize, @bitCast(@as(isize, newfd))), @intFromPtr(newpath));
}

pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: i64) usize {
    if (@hasField(SYS, "pread64") and usize_bits < 64) {
        const offset_halves = splitValue64(offset);
        if (require_aligned_register_pair) {
            return syscall6(
                .pread64,
                @as(usize, @bitCast(@as(isize, fd))),
                @intFromPtr(buf),
                count,
                0,
                offset_halves[0],
                offset_halves[1],
            );
        } else {
            return syscall5(
                .pread64,
                @as(usize, @bitCast(@as(isize, fd))),
                @intFromPtr(buf),
                count,
                offset_halves[0],
                offset_halves[1],
            );
        }
    } else {
        // Some architectures (eg. 64bit SPARC) pread is called pread64.
        const syscall_number = if (!@hasField(SYS, "pread") and @hasField(SYS, "pread64"))
            .pread64
        else
            .pread;
        return syscall4(
            syscall_number,
            @as(usize, @bitCast(@as(isize, fd))),
            @intFromPtr(buf),
            count,
            @as(u64, @bitCast(offset)),
        );
    }
}

pub fn access(path: [*:0]const u8, mode: u32) usize {
    if (@hasField(SYS, "access")) {
        return syscall2(.access, @intFromPtr(path), mode);
    } else {
        return syscall4(.faccessat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(path), mode, 0);
    }
}

pub fn faccessat(dirfd: i32, path: [*:0]const u8, mode: u32, flags: u32) usize {
    return syscall4(.faccessat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode, flags);
}

pub fn pipe(fd: *[2]i32) usize {
    if (comptime (native_arch.isMIPS() or native_arch.isSPARC())) {
        return syscall_pipe(fd);
    } else if (@hasField(SYS, "pipe")) {
        return syscall1(.pipe, @intFromPtr(fd));
    } else {
        return syscall2(.pipe2, @intFromPtr(fd), 0);
    }
}

pub fn pipe2(fd: *[2]i32, flags: O) usize {
    return syscall2(.pipe2, @intFromPtr(fd), @as(u32, @bitCast(flags)));
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall3(.write, @bitCast(@as(isize, fd)), @intFromPtr(buf), count);
}

pub fn ftruncate(fd: i32, length: i64) usize {
    if (@hasField(SYS, "ftruncate64") and usize_bits < 64) {
        const length_halves = splitValue64(length);
        if (require_aligned_register_pair) {
            return syscall4(
                .ftruncate64,
                @as(usize, @bitCast(@as(isize, fd))),
                0,
                length_halves[0],
                length_halves[1],
            );
        } else {
            return syscall3(
                .ftruncate64,
                @as(usize, @bitCast(@as(isize, fd))),
                length_halves[0],
                length_halves[1],
            );
        }
    } else {
        return syscall2(
            .ftruncate,
            @as(usize, @bitCast(@as(isize, fd))),
            @as(usize, @bitCast(length)),
        );
    }
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: i64) usize {
    if (@hasField(SYS, "pwrite64") and usize_bits < 64) {
        const offset_halves = splitValue64(offset);

        if (require_aligned_register_pair) {
            return syscall6(
                .pwrite64,
                @as(usize, @bitCast(@as(isize, fd))),
                @intFromPtr(buf),
                count,
                0,
                offset_halves[0],
                offset_halves[1],
            );
        } else {
            return syscall5(
                .pwrite64,
                @as(usize, @bitCast(@as(isize, fd))),
                @intFromPtr(buf),
                count,
                offset_halves[0],
                offset_halves[1],
            );
        }
    } else {
        // Some architectures (eg. 64bit SPARC) pwrite is called pwrite64.
        const syscall_number = if (!@hasField(SYS, "pwrite") and @hasField(SYS, "pwrite64"))
            .pwrite64
        else
            .pwrite;
        return syscall4(
            syscall_number,
            @as(usize, @bitCast(@as(isize, fd))),
            @intFromPtr(buf),
            count,
            @as(u64, @bitCast(offset)),
        );
    }
}

pub fn rename(old: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasField(SYS, "rename")) {
        return syscall2(.rename, @intFromPtr(old), @intFromPtr(new));
    } else if (@hasField(SYS, "renameat")) {
        return syscall4(.renameat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(old), @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(new));
    } else {
        return syscall5(.renameat2, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(old), @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(new), 0);
    }
}

pub fn renameat(oldfd: i32, oldpath: [*:0]const u8, newfd: i32, newpath: [*:0]const u8) usize {
    if (@hasField(SYS, "renameat")) {
        return syscall4(
            .renameat,
            @as(usize, @bitCast(@as(isize, oldfd))),
            @intFromPtr(oldpath),
            @as(usize, @bitCast(@as(isize, newfd))),
            @intFromPtr(newpath),
        );
    } else {
        return syscall5(
            .renameat2,
            @as(usize, @bitCast(@as(isize, oldfd))),
            @intFromPtr(oldpath),
            @as(usize, @bitCast(@as(isize, newfd))),
            @intFromPtr(newpath),
            0,
        );
    }
}

pub fn renameat2(oldfd: i32, oldpath: [*:0]const u8, newfd: i32, newpath: [*:0]const u8, flags: u32) usize {
    return syscall5(
        .renameat2,
        @as(usize, @bitCast(@as(isize, oldfd))),
        @intFromPtr(oldpath),
        @as(usize, @bitCast(@as(isize, newfd))),
        @intFromPtr(newpath),
        flags,
    );
}

pub fn open(path: [*:0]const u8, flags: O, perm: mode_t) usize {
    if (@hasField(SYS, "open")) {
        return syscall3(.open, @intFromPtr(path), @as(u32, @bitCast(flags)), perm);
    } else {
        return syscall4(
            .openat,
            @bitCast(@as(isize, AT.FDCWD)),
            @intFromPtr(path),
            @as(u32, @bitCast(flags)),
            perm,
        );
    }
}

pub fn create(path: [*:0]const u8, perm: mode_t) usize {
    return syscall2(.creat, @intFromPtr(path), perm);
}

pub fn openat(dirfd: i32, path: [*:0]const u8, flags: O, mode: mode_t) usize {
    // dirfd could be negative, for example AT.FDCWD is -100
    return syscall4(.openat, @bitCast(@as(isize, dirfd)), @intFromPtr(path), @as(u32, @bitCast(flags)), mode);
}

/// See also `clone` (from the arch-specific include)
pub fn clone5(flags: usize, child_stack_ptr: usize, parent_tid: *i32, child_tid: *i32, newtls: usize) usize {
    return syscall5(.clone, flags, child_stack_ptr, @intFromPtr(parent_tid), @intFromPtr(child_tid), newtls);
}

/// See also `clone` (from the arch-specific include)
pub fn clone2(flags: u32, child_stack_ptr: usize) usize {
    return syscall2(.clone, flags, child_stack_ptr);
}

pub fn close(fd: i32) usize {
    return syscall1(.close, @as(usize, @bitCast(@as(isize, fd))));
}

pub fn fchmod(fd: i32, mode: mode_t) usize {
    return syscall2(.fchmod, @as(usize, @bitCast(@as(isize, fd))), mode);
}

pub fn chmod(path: [*:0]const u8, mode: mode_t) usize {
    if (@hasField(SYS, "chmod")) {
        return syscall2(.chmod, @intFromPtr(path), mode);
    } else {
        return fchmodat(AT.FDCWD, path, mode, 0);
    }
}

pub fn fchown(fd: i32, owner: uid_t, group: gid_t) usize {
    if (@hasField(SYS, "fchown32")) {
        return syscall3(.fchown32, @as(usize, @bitCast(@as(isize, fd))), owner, group);
    } else {
        return syscall3(.fchown, @as(usize, @bitCast(@as(isize, fd))), owner, group);
    }
}

pub fn fchmodat(fd: i32, path: [*:0]const u8, mode: mode_t, _: u32) usize {
    return syscall3(.fchmodat, @bitCast(@as(isize, fd)), @intFromPtr(path), mode);
}

pub fn fchmodat2(fd: i32, path: [*:0]const u8, mode: mode_t, flags: u32) usize {
    return syscall4(.fchmodat2, @bitCast(@as(isize, fd)), @intFromPtr(path), mode, flags);
}

/// Can only be called on 32 bit systems. For 64 bit see `lseek`.
pub fn llseek(fd: i32, offset: u64, result: ?*u64, whence: usize) usize {
    // NOTE: The offset parameter splitting is independent from the target
    // endianness.
    return syscall5(
        ._llseek,
        @as(usize, @bitCast(@as(isize, fd))),
        @as(usize, @truncate(offset >> 32)),
        @as(usize, @truncate(offset)),
        @intFromPtr(result),
        whence,
    );
}

/// Can only be called on 64 bit systems. For 32 bit see `llseek`.
pub fn lseek(fd: i32, offset: i64, whence: usize) usize {
    return syscall3(.lseek, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(offset)), whence);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(.exit, @as(usize, @bitCast(@as(isize, status))));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(.exit_group, @as(usize, @bitCast(@as(isize, status))));
    unreachable;
}

/// flags for the `reboot' system call.
pub const LINUX_REBOOT = struct {
    /// First magic value required to use _reboot() system call.
    pub const MAGIC1 = enum(u32) {
        MAGIC1 = 0xfee1dead,
        _,
    };

    /// Second magic value required to use _reboot() system call.
    pub const MAGIC2 = enum(u32) {
        MAGIC2 = 672274793,
        MAGIC2A = 85072278,
        MAGIC2B = 369367448,
        MAGIC2C = 537993216,
        _,
    };

    /// Commands accepted by the _reboot() system call.
    pub const CMD = enum(u32) {
        /// Restart system using default command and mode.
        RESTART = 0x01234567,

        /// Stop OS and give system control to ROM monitor, if any.
        HALT = 0xCDEF0123,

        /// Ctrl-Alt-Del sequence causes RESTART command.
        CAD_ON = 0x89ABCDEF,

        /// Ctrl-Alt-Del sequence sends SIGINT to init task.
        CAD_OFF = 0x00000000,

        /// Stop OS and remove all power from system, if possible.
        POWER_OFF = 0x4321FEDC,

        /// Restart system using given command string.
        RESTART2 = 0xA1B2C3D4,

        /// Suspend system using software suspend if compiled in.
        SW_SUSPEND = 0xD000FCE2,

        /// Restart system using a previously loaded Linux kernel
        KEXEC = 0x45584543,

        _,
    };
};

pub fn reboot(magic: LINUX_REBOOT.MAGIC1, magic2: LINUX_REBOOT.MAGIC2, cmd: LINUX_REBOOT.CMD, arg: ?*const anyopaque) usize {
    return std.os.linux.syscall4(
        .reboot,
        @intFromEnum(magic),
        @intFromEnum(magic2),
        @intFromEnum(cmd),
        @intFromPtr(arg),
    );
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(.getrandom, @intFromPtr(buf), count, flags);
}

pub fn kill(pid: pid_t, sig: i32) usize {
    return syscall2(.kill, @as(usize, @bitCast(@as(isize, pid))), @as(usize, @bitCast(@as(isize, sig))));
}

pub fn tkill(tid: pid_t, sig: i32) usize {
    return syscall2(.tkill, @as(usize, @bitCast(@as(isize, tid))), @as(usize, @bitCast(@as(isize, sig))));
}

pub fn tgkill(tgid: pid_t, tid: pid_t, sig: i32) usize {
    return syscall3(.tgkill, @as(usize, @bitCast(@as(isize, tgid))), @as(usize, @bitCast(@as(isize, tid))), @as(usize, @bitCast(@as(isize, sig))));
}

pub fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8, flags: i32) usize {
    if (@hasField(SYS, "link")) {
        return syscall3(
            .link,
            @intFromPtr(oldpath),
            @intFromPtr(newpath),
            @as(usize, @bitCast(@as(isize, flags))),
        );
    } else {
        return syscall5(
            .linkat,
            @as(usize, @bitCast(@as(isize, AT.FDCWD))),
            @intFromPtr(oldpath),
            @as(usize, @bitCast(@as(isize, AT.FDCWD))),
            @intFromPtr(newpath),
            @as(usize, @bitCast(@as(isize, flags))),
        );
    }
}

pub fn linkat(oldfd: fd_t, oldpath: [*:0]const u8, newfd: fd_t, newpath: [*:0]const u8, flags: i32) usize {
    return syscall5(
        .linkat,
        @as(usize, @bitCast(@as(isize, oldfd))),
        @intFromPtr(oldpath),
        @as(usize, @bitCast(@as(isize, newfd))),
        @intFromPtr(newpath),
        @as(usize, @bitCast(@as(isize, flags))),
    );
}

pub fn unlink(path: [*:0]const u8) usize {
    if (@hasField(SYS, "unlink")) {
        return syscall1(.unlink, @intFromPtr(path));
    } else {
        return syscall3(.unlinkat, @as(usize, @bitCast(@as(isize, AT.FDCWD))), @intFromPtr(path), 0);
    }
}

pub fn unlinkat(dirfd: i32, path: [*:0]const u8, flags: u32) usize {
    return syscall3(.unlinkat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), flags);
}

pub fn waitpid(pid: pid_t, status: *u32, flags: u32) usize {
    return syscall4(.wait4, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(status), flags, 0);
}

pub fn wait4(pid: pid_t, status: *u32, flags: u32, usage: ?*rusage) usize {
    return syscall4(
        .wait4,
        @as(usize, @bitCast(@as(isize, pid))),
        @intFromPtr(status),
        flags,
        @intFromPtr(usage),
    );
}

pub fn waitid(id_type: P, id: i32, infop: *siginfo_t, flags: u32) usize {
    return syscall5(.waitid, @intFromEnum(id_type), @as(usize, @bitCast(@as(isize, id))), @intFromPtr(infop), flags, 0);
}

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) usize {
    return syscall3(.fcntl, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, cmd))), arg);
}

pub fn flock(fd: fd_t, operation: i32) usize {
    return syscall2(.flock, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, operation))));
}

// We must follow the C calling convention when we call into the VDSO
const VdsoClockGettime = *align(1) const fn (i32, *timespec) callconv(.C) usize;
var vdso_clock_gettime: ?VdsoClockGettime = &init_vdso_clock_gettime;

pub fn clock_gettime(clk_id: i32, tp: *timespec) usize {
    if (@hasDecl(VDSO, "CGT_SYM")) {
        const ptr = @atomicLoad(?VdsoClockGettime, &vdso_clock_gettime, .unordered);
        if (ptr) |f| {
            const rc = f(clk_id, tp);
            switch (rc) {
                0, @as(usize, @bitCast(-@as(isize, @intFromEnum(E.INVAL)))) => return rc,
                else => {},
            }
        }
    }
    return syscall2(.clock_gettime, @as(usize, @bitCast(@as(isize, clk_id))), @intFromPtr(tp));
}

fn init_vdso_clock_gettime(clk: i32, ts: *timespec) callconv(.C) usize {
    const ptr: ?VdsoClockGettime = @ptrFromInt(vdso.lookup(VDSO.CGT_VER, VDSO.CGT_SYM));
    // Note that we may not have a VDSO at all, update the stub address anyway
    // so that clock_gettime will fall back on the good old (and slow) syscall
    @atomicStore(?VdsoClockGettime, &vdso_clock_gettime, ptr, .monotonic);
    // Call into the VDSO if available
    if (ptr) |f| return f(clk, ts);
    return @as(usize, @bitCast(-@as(isize, @intFromEnum(E.NOSYS))));
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return syscall2(.clock_getres, @as(usize, @bitCast(@as(isize, clk_id))), @intFromPtr(tp));
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(.clock_settime, @as(usize, @bitCast(@as(isize, clk_id))), @intFromPtr(tp));
}

pub fn gettimeofday(tv: ?*timeval, tz: ?*timezone) usize {
    return syscall2(.gettimeofday, @intFromPtr(tv), @intFromPtr(tz));
}

pub fn settimeofday(tv: *const timeval, tz: *const timezone) usize {
    return syscall2(.settimeofday, @intFromPtr(tv), @intFromPtr(tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return syscall2(.nanosleep, @intFromPtr(req), @intFromPtr(rem));
}

pub fn pause() usize {
    if (@hasField(SYS, "pause")) {
        return syscall0(.pause);
    } else {
        return syscall4(.ppoll, 0, 0, 0, 0);
    }
}

pub fn setuid(uid: uid_t) usize {
    if (@hasField(SYS, "setuid32")) {
        return syscall1(.setuid32, uid);
    } else {
        return syscall1(.setuid, uid);
    }
}

pub fn setgid(gid: gid_t) usize {
    if (@hasField(SYS, "setgid32")) {
        return syscall1(.setgid32, gid);
    } else {
        return syscall1(.setgid, gid);
    }
}

pub fn setreuid(ruid: uid_t, euid: uid_t) usize {
    if (@hasField(SYS, "setreuid32")) {
        return syscall2(.setreuid32, ruid, euid);
    } else {
        return syscall2(.setreuid, ruid, euid);
    }
}

pub fn setregid(rgid: gid_t, egid: gid_t) usize {
    if (@hasField(SYS, "setregid32")) {
        return syscall2(.setregid32, rgid, egid);
    } else {
        return syscall2(.setregid, rgid, egid);
    }
}

pub fn getuid() uid_t {
    if (@hasField(SYS, "getuid32")) {
        return @as(uid_t, @intCast(syscall0(.getuid32)));
    } else {
        return @as(uid_t, @intCast(syscall0(.getuid)));
    }
}

pub fn getgid() gid_t {
    if (@hasField(SYS, "getgid32")) {
        return @as(gid_t, @intCast(syscall0(.getgid32)));
    } else {
        return @as(gid_t, @intCast(syscall0(.getgid)));
    }
}

pub fn geteuid() uid_t {
    if (@hasField(SYS, "geteuid32")) {
        return @as(uid_t, @intCast(syscall0(.geteuid32)));
    } else {
        return @as(uid_t, @intCast(syscall0(.geteuid)));
    }
}

pub fn getegid() gid_t {
    if (@hasField(SYS, "getegid32")) {
        return @as(gid_t, @intCast(syscall0(.getegid32)));
    } else {
        return @as(gid_t, @intCast(syscall0(.getegid)));
    }
}

pub fn seteuid(euid: uid_t) usize {
    // We use setresuid here instead of setreuid to ensure that the saved uid
    // is not changed. This is what musl and recent glibc versions do as well.
    //
    // The setresuid(2) man page says that if -1 is passed the corresponding
    // id will not be changed. Since uid_t is unsigned, this wraps around to the
    // max value in C.
    comptime assert(@typeInfo(uid_t) == .Int and @typeInfo(uid_t).Int.signedness == .unsigned);
    return setresuid(std.math.maxInt(uid_t), euid, std.math.maxInt(uid_t));
}

pub fn setegid(egid: gid_t) usize {
    // We use setresgid here instead of setregid to ensure that the saved uid
    // is not changed. This is what musl and recent glibc versions do as well.
    //
    // The setresgid(2) man page says that if -1 is passed the corresponding
    // id will not be changed. Since gid_t is unsigned, this wraps around to the
    // max value in C.
    comptime assert(@typeInfo(uid_t) == .Int and @typeInfo(uid_t).Int.signedness == .unsigned);
    return setresgid(std.math.maxInt(gid_t), egid, std.math.maxInt(gid_t));
}

pub fn getresuid(ruid: *uid_t, euid: *uid_t, suid: *uid_t) usize {
    if (@hasField(SYS, "getresuid32")) {
        return syscall3(.getresuid32, @intFromPtr(ruid), @intFromPtr(euid), @intFromPtr(suid));
    } else {
        return syscall3(.getresuid, @intFromPtr(ruid), @intFromPtr(euid), @intFromPtr(suid));
    }
}

pub fn getresgid(rgid: *gid_t, egid: *gid_t, sgid: *gid_t) usize {
    if (@hasField(SYS, "getresgid32")) {
        return syscall3(.getresgid32, @intFromPtr(rgid), @intFromPtr(egid), @intFromPtr(sgid));
    } else {
        return syscall3(.getresgid, @intFromPtr(rgid), @intFromPtr(egid), @intFromPtr(sgid));
    }
}

pub fn setresuid(ruid: uid_t, euid: uid_t, suid: uid_t) usize {
    if (@hasField(SYS, "setresuid32")) {
        return syscall3(.setresuid32, ruid, euid, suid);
    } else {
        return syscall3(.setresuid, ruid, euid, suid);
    }
}

pub fn setresgid(rgid: gid_t, egid: gid_t, sgid: gid_t) usize {
    if (@hasField(SYS, "setresgid32")) {
        return syscall3(.setresgid32, rgid, egid, sgid);
    } else {
        return syscall3(.setresgid, rgid, egid, sgid);
    }
}

pub fn getgroups(size: usize, list: *gid_t) usize {
    if (@hasField(SYS, "getgroups32")) {
        return syscall2(.getgroups32, size, @intFromPtr(list));
    } else {
        return syscall2(.getgroups, size, @intFromPtr(list));
    }
}

pub fn setgroups(size: usize, list: [*]const gid_t) usize {
    if (@hasField(SYS, "setgroups32")) {
        return syscall2(.setgroups32, size, @intFromPtr(list));
    } else {
        return syscall2(.setgroups, size, @intFromPtr(list));
    }
}

pub fn setsid() pid_t {
    return @as(pid_t, @bitCast(@as(u32, @truncate(syscall0(.setsid)))));
}

pub fn getpid() pid_t {
    return @as(pid_t, @bitCast(@as(u32, @truncate(syscall0(.getpid)))));
}

pub fn gettid() pid_t {
    return @as(pid_t, @bitCast(@as(u32, @truncate(syscall0(.gettid)))));
}

pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) usize {
    return syscall4(.rt_sigprocmask, flags, @intFromPtr(set), @intFromPtr(oldset), NSIG / 8);
}

pub fn sigaction(sig: u6, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) usize {
    assert(sig >= 1);
    assert(sig != SIG.KILL);
    assert(sig != SIG.STOP);

    var ksa: k_sigaction = undefined;
    var oldksa: k_sigaction = undefined;
    const mask_size = @sizeOf(@TypeOf(ksa.mask));

    if (act) |new| {
        const restorer_fn = if ((new.flags & SA.SIGINFO) != 0) &restore_rt else &restore;
        ksa = k_sigaction{
            .handler = new.handler.handler,
            .flags = new.flags | SA.RESTORER,
            .mask = undefined,
            .restorer = @ptrCast(restorer_fn),
        };
        @memcpy(@as([*]u8, @ptrCast(&ksa.mask))[0..mask_size], @as([*]const u8, @ptrCast(&new.mask)));
    }

    const ksa_arg = if (act != null) @intFromPtr(&ksa) else 0;
    const oldksa_arg = if (oact != null) @intFromPtr(&oldksa) else 0;

    const result = switch (native_arch) {
        // The sparc version of rt_sigaction needs the restorer function to be passed as an argument too.
        .sparc, .sparc64 => syscall5(.rt_sigaction, sig, ksa_arg, oldksa_arg, @intFromPtr(ksa.restorer), mask_size),
        else => syscall4(.rt_sigaction, sig, ksa_arg, oldksa_arg, mask_size),
    };
    if (E.init(result) != .SUCCESS) return result;

    if (oact) |old| {
        old.handler.handler = oldksa.handler;
        old.flags = @as(c_uint, @truncate(oldksa.flags));
        @memcpy(@as([*]u8, @ptrCast(&old.mask))[0..mask_size], @as([*]const u8, @ptrCast(&oldksa.mask)));
    }

    return 0;
}

const usize_bits = @typeInfo(usize).Int.bits;

pub fn sigaddset(set: *sigset_t, sig: u6) void {
    const s = sig - 1;
    // shift in musl: s&8*sizeof *set->__bits-1
    const shift = @as(u5, @intCast(s & (usize_bits - 1)));
    const val = @as(u32, @intCast(1)) << shift;
    (set.*)[@as(usize, @intCast(s)) / usize_bits] |= val;
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((set.*)[@as(usize, @intCast(s)) / usize_bits] & (@as(usize, @intCast(1)) << (s & (usize_bits - 1)))) != 0;
}

pub fn getsockname(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.getsockname, &[3]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len) });
    }
    return syscall3(.getsockname, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len));
}

pub fn getpeername(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.getpeername, &[3]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len) });
    }
    return syscall3(.getpeername, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.socket, &[3]usize{ domain, socket_type, protocol });
    }
    return syscall3(.socket, domain, socket_type, protocol);
}

pub fn setsockopt(fd: i32, level: i32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.setsockopt, &[5]usize{ @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @as(usize, @intCast(optlen)) });
    }
    return syscall5(.setsockopt, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @as(usize, @intCast(optlen)));
}

pub fn getsockopt(fd: i32, level: i32, optname: u32, noalias optval: [*]u8, noalias optlen: *socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.getsockopt, &[5]usize{ @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @intFromPtr(optlen) });
    }
    return syscall5(.getsockopt, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, level))), optname, @intFromPtr(optval), @intFromPtr(optlen));
}

pub fn sendmsg(fd: i32, msg: *const msghdr_const, flags: u32) usize {
    const fd_usize = @as(usize, @bitCast(@as(isize, fd)));
    const msg_usize = @intFromPtr(msg);
    if (native_arch == .x86) {
        return socketcall(SC.sendmsg, &[3]usize{ fd_usize, msg_usize, flags });
    } else {
        return syscall3(.sendmsg, fd_usize, msg_usize, flags);
    }
}

pub fn sendmmsg(fd: i32, msgvec: [*]mmsghdr_const, vlen: u32, flags: u32) usize {
    if (@typeInfo(usize).Int.bits > @typeInfo(@typeInfo(mmsghdr).Struct.fields[1].type).Int.bits) {
        // workaround kernel brokenness:
        // if adding up all iov_len overflows a i32 then split into multiple calls
        // see https://www.openwall.com/lists/musl/2014/06/07/5
        const kvlen = if (vlen > IOV_MAX) IOV_MAX else vlen; // matches kernel
        var next_unsent: usize = 0;
        for (msgvec[0..kvlen], 0..) |*msg, i| {
            var size: i32 = 0;
            const msg_iovlen = @as(usize, @intCast(msg.msg_hdr.msg_iovlen)); // kernel side this is treated as unsigned
            for (msg.msg_hdr.msg_iov[0..msg_iovlen]) |iov| {
                if (iov.iov_len > std.math.maxInt(i32) or @addWithOverflow(size, @as(i32, @intCast(iov.iov_len)))[1] != 0) {
                    // batch-send all messages up to the current message
                    if (next_unsent < i) {
                        const batch_size = i - next_unsent;
                        const r = syscall4(.sendmmsg, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(&msgvec[next_unsent]), batch_size, flags);
                        if (E.init(r) != 0) return next_unsent;
                        if (r < batch_size) return next_unsent + r;
                    }
                    // send current message as own packet
                    const r = sendmsg(fd, &msg.msg_hdr, flags);
                    if (E.init(r) != 0) return r;
                    // Linux limits the total bytes sent by sendmsg to INT_MAX, so this cast is safe.
                    msg.msg_len = @as(u32, @intCast(r));
                    next_unsent = i + 1;
                    break;
                }
                size += iov.iov_len;
            }
        }
        if (next_unsent < kvlen or next_unsent == 0) { // want to make sure at least one syscall occurs (e.g. to trigger MSG.EOR)
            const batch_size = kvlen - next_unsent;
            const r = syscall4(.sendmmsg, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(&msgvec[next_unsent]), batch_size, flags);
            if (E.init(r) != 0) return r;
            return next_unsent + r;
        }
        return kvlen;
    }
    return syscall4(.sendmmsg, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(msgvec), vlen, flags);
}

pub fn connect(fd: i32, addr: *const anyopaque, len: socklen_t) usize {
    const fd_usize = @as(usize, @bitCast(@as(isize, fd)));
    const addr_usize = @intFromPtr(addr);
    if (native_arch == .x86) {
        return socketcall(SC.connect, &[3]usize{ fd_usize, addr_usize, len });
    } else {
        return syscall3(.connect, fd_usize, addr_usize, len);
    }
}

pub fn recvmsg(fd: i32, msg: *msghdr, flags: u32) usize {
    const fd_usize = @as(usize, @bitCast(@as(isize, fd)));
    const msg_usize = @intFromPtr(msg);
    if (native_arch == .x86) {
        return socketcall(SC.recvmsg, &[3]usize{ fd_usize, msg_usize, flags });
    } else {
        return syscall3(.recvmsg, fd_usize, msg_usize, flags);
    }
}

pub fn recvfrom(
    fd: i32,
    noalias buf: [*]u8,
    len: usize,
    flags: u32,
    noalias addr: ?*sockaddr,
    noalias alen: ?*socklen_t,
) usize {
    const fd_usize = @as(usize, @bitCast(@as(isize, fd)));
    const buf_usize = @intFromPtr(buf);
    const addr_usize = @intFromPtr(addr);
    const alen_usize = @intFromPtr(alen);
    if (native_arch == .x86) {
        return socketcall(SC.recvfrom, &[6]usize{ fd_usize, buf_usize, len, flags, addr_usize, alen_usize });
    } else {
        return syscall6(.recvfrom, fd_usize, buf_usize, len, flags, addr_usize, alen_usize);
    }
}

pub fn shutdown(fd: i32, how: i32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.shutdown, &[2]usize{ @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, how))) });
    }
    return syscall2(.shutdown, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, how))));
}

pub fn bind(fd: i32, addr: *const sockaddr, len: socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.bind, &[3]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @as(usize, @intCast(len)) });
    }
    return syscall3(.bind, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @as(usize, @intCast(len)));
}

pub fn listen(fd: i32, backlog: u32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.listen, &[2]usize{ @as(usize, @bitCast(@as(isize, fd))), backlog });
    }
    return syscall2(.listen, @as(usize, @bitCast(@as(isize, fd))), backlog);
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: u32, addr: ?*const sockaddr, alen: socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.sendto, &[6]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(buf), len, flags, @intFromPtr(addr), @as(usize, @intCast(alen)) });
    }
    return syscall6(.sendto, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(buf), len, flags, @intFromPtr(addr), @as(usize, @intCast(alen)));
}

pub fn sendfile(outfd: i32, infd: i32, offset: ?*i64, count: usize) usize {
    if (@hasField(SYS, "sendfile64")) {
        return syscall4(
            .sendfile64,
            @as(usize, @bitCast(@as(isize, outfd))),
            @as(usize, @bitCast(@as(isize, infd))),
            @intFromPtr(offset),
            count,
        );
    } else {
        return syscall4(
            .sendfile,
            @as(usize, @bitCast(@as(isize, outfd))),
            @as(usize, @bitCast(@as(isize, infd))),
            @intFromPtr(offset),
            count,
        );
    }
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: *[2]i32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.socketpair, &[4]usize{ @as(usize, @intCast(domain)), @as(usize, @intCast(socket_type)), @as(usize, @intCast(protocol)), @intFromPtr(fd) });
    }
    return syscall4(.socketpair, @as(usize, @intCast(domain)), @as(usize, @intCast(socket_type)), @as(usize, @intCast(protocol)), @intFromPtr(fd));
}

pub fn accept(fd: i32, noalias addr: ?*sockaddr, noalias len: ?*socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.accept, &[4]usize{ fd, addr, len, 0 });
    }
    return accept4(fd, addr, len, 0);
}

pub fn accept4(fd: i32, noalias addr: ?*sockaddr, noalias len: ?*socklen_t, flags: u32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.accept4, &[4]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len), flags });
    }
    return syscall4(.accept4, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len), flags);
}

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    if (@hasField(SYS, "fstat64")) {
        return syscall2(.fstat64, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(stat_buf));
    } else {
        return syscall2(.fstat, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(stat_buf));
    }
}

pub fn stat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasField(SYS, "stat64")) {
        return syscall2(.stat64, @intFromPtr(pathname), @intFromPtr(statbuf));
    } else {
        return syscall2(.stat, @intFromPtr(pathname), @intFromPtr(statbuf));
    }
}

pub fn lstat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasField(SYS, "lstat64")) {
        return syscall2(.lstat64, @intFromPtr(pathname), @intFromPtr(statbuf));
    } else {
        return syscall2(.lstat, @intFromPtr(pathname), @intFromPtr(statbuf));
    }
}

pub fn fstatat(dirfd: i32, path: [*:0]const u8, stat_buf: *Stat, flags: u32) usize {
    if (@hasField(SYS, "fstatat64")) {
        return syscall4(.fstatat64, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), @intFromPtr(stat_buf), flags);
    } else {
        return syscall4(.fstatat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), @intFromPtr(stat_buf), flags);
    }
}

pub fn statx(dirfd: i32, path: [*:0]const u8, flags: u32, mask: u32, statx_buf: *Statx) usize {
    if (@hasField(SYS, "statx")) {
        return syscall5(
            .statx,
            @as(usize, @bitCast(@as(isize, dirfd))),
            @intFromPtr(path),
            flags,
            mask,
            @intFromPtr(statx_buf),
        );
    }
    return @as(usize, @bitCast(-@as(isize, @intFromEnum(E.NOSYS))));
}

pub fn listxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(.listxattr, @intFromPtr(path), @intFromPtr(list), size);
}

pub fn llistxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(.llistxattr, @intFromPtr(path), @intFromPtr(list), size);
}

pub fn flistxattr(fd: usize, list: [*]u8, size: usize) usize {
    return syscall3(.flistxattr, fd, @intFromPtr(list), size);
}

pub fn getxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.getxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size);
}

pub fn lgetxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.lgetxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size);
}

pub fn fgetxattr(fd: usize, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.lgetxattr, fd, @intFromPtr(name), @intFromPtr(value), size);
}

pub fn setxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.setxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size, flags);
}

pub fn lsetxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.lsetxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size, flags);
}

pub fn fsetxattr(fd: usize, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.fsetxattr, fd, @intFromPtr(name), @intFromPtr(value), size, flags);
}

pub fn removexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(.removexattr, @intFromPtr(path), @intFromPtr(name));
}

pub fn lremovexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(.lremovexattr, @intFromPtr(path), @intFromPtr(name));
}

pub fn fremovexattr(fd: usize, name: [*:0]const u8) usize {
    return syscall2(.fremovexattr, fd, @intFromPtr(name));
}

pub fn sched_yield() usize {
    return syscall0(.sched_yield);
}

pub fn sched_getaffinity(pid: pid_t, size: usize, set: *cpu_set_t) usize {
    const rc = syscall3(.sched_getaffinity, @as(usize, @bitCast(@as(isize, pid))), size, @intFromPtr(set));
    if (@as(isize, @bitCast(rc)) < 0) return rc;
    if (rc < size) @memset(@as([*]u8, @ptrCast(set))[rc..size], 0);
    return 0;
}

pub fn sched_setaffinity(pid: pid_t, set: *const cpu_set_t) !void {
    const size = @sizeOf(cpu_set_t);
    const rc = syscall3(.sched_setaffinity, @as(usize, @bitCast(@as(isize, pid))), size, @intFromPtr(set));

    switch (std.os.errno(rc)) {
        .SUCCESS => return,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

pub fn epoll_create() usize {
    return epoll_create1(0);
}

pub fn epoll_create1(flags: usize) usize {
    return syscall1(.epoll_create1, flags);
}

pub fn epoll_ctl(epoll_fd: i32, op: u32, fd: i32, ev: ?*epoll_event) usize {
    return syscall4(.epoll_ctl, @as(usize, @bitCast(@as(isize, epoll_fd))), @as(usize, @intCast(op)), @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32) usize {
    return epoll_pwait(epoll_fd, events, maxevents, timeout, null);
}

pub fn epoll_pwait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32, sigmask: ?*const sigset_t) usize {
    return syscall6(
        .epoll_pwait,
        @as(usize, @bitCast(@as(isize, epoll_fd))),
        @intFromPtr(events),
        @as(usize, @intCast(maxevents)),
        @as(usize, @bitCast(@as(isize, timeout))),
        @intFromPtr(sigmask),
        @sizeOf(sigset_t),
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(.eventfd2, count, flags);
}

pub fn timerfd_create(clockid: i32, flags: TFD) usize {
    return syscall2(.timerfd_create, @bitCast(@as(isize, clockid)), @as(u32, @bitCast(flags)));
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(.timerfd_gettime, @bitCast(@as(isize, fd)), @intFromPtr(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: TFD.TIMER, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(.timerfd_settime, @bitCast(@as(isize, fd)), @as(u32, @bitCast(flags)), @intFromPtr(new_value), @intFromPtr(old_value));
}

// Flags for the 'setitimer' system call
pub const ITIMER = enum(i32) {
    REAL = 0,
    VIRTUAL = 1,
    PROF = 2,
};

pub fn getitimer(which: i32, curr_value: *itimerspec) usize {
    return syscall2(.getitimer, @as(usize, @bitCast(@as(isize, which))), @intFromPtr(curr_value));
}

pub fn setitimer(which: i32, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall3(.setitimer, @as(usize, @bitCast(@as(isize, which))), @intFromPtr(new_value), @intFromPtr(old_value));
}

pub fn unshare(flags: usize) usize {
    return syscall1(.unshare, flags);
}

pub fn capget(hdrp: *cap_user_header_t, datap: *cap_user_data_t) usize {
    return syscall2(.capget, @intFromPtr(hdrp), @intFromPtr(datap));
}

pub fn capset(hdrp: *cap_user_header_t, datap: *const cap_user_data_t) usize {
    return syscall2(.capset, @intFromPtr(hdrp), @intFromPtr(datap));
}

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) usize {
    return syscall2(.sigaltstack, @intFromPtr(ss), @intFromPtr(old_ss));
}

pub fn uname(uts: *utsname) usize {
    return syscall1(.uname, @intFromPtr(uts));
}

pub fn io_uring_setup(entries: u32, p: *io_uring_params) usize {
    return syscall2(.io_uring_setup, entries, @intFromPtr(p));
}

pub fn io_uring_enter(fd: i32, to_submit: u32, min_complete: u32, flags: u32, sig: ?*sigset_t) usize {
    return syscall6(.io_uring_enter, @as(usize, @bitCast(@as(isize, fd))), to_submit, min_complete, flags, @intFromPtr(sig), NSIG / 8);
}

pub fn io_uring_register(fd: i32, opcode: IORING_REGISTER, arg: ?*const anyopaque, nr_args: u32) usize {
    return syscall4(.io_uring_register, @as(usize, @bitCast(@as(isize, fd))), @intFromEnum(opcode), @intFromPtr(arg), nr_args);
}

pub fn memfd_create(name: [*:0]const u8, flags: u32) usize {
    return syscall2(.memfd_create, @intFromPtr(name), flags);
}

pub fn getrusage(who: i32, usage: *rusage) usize {
    return syscall2(.getrusage, @as(usize, @bitCast(@as(isize, who))), @intFromPtr(usage));
}

pub fn tcgetattr(fd: fd_t, termios_p: *termios) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), T.CGETS, @intFromPtr(termios_p));
}

pub fn tcsetattr(fd: fd_t, optional_action: TCSA, termios_p: *const termios) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), T.CSETS + @intFromEnum(optional_action), @intFromPtr(termios_p));
}

pub fn tcgetpgrp(fd: fd_t, pgrp: *pid_t) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), T.IOCGPGRP, @intFromPtr(pgrp));
}

pub fn tcsetpgrp(fd: fd_t, pgrp: *const pid_t) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), T.IOCSPGRP, @intFromPtr(pgrp));
}

pub fn tcdrain(fd: fd_t) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), T.CSBRK, 1);
}

pub fn ioctl(fd: fd_t, request: u32, arg: usize) usize {
    return syscall3(.ioctl, @as(usize, @bitCast(@as(isize, fd))), request, arg);
}

pub fn signalfd(fd: fd_t, mask: *const sigset_t, flags: u32) usize {
    return syscall4(.signalfd4, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(mask), NSIG / 8, flags);
}

pub fn copy_file_range(fd_in: fd_t, off_in: ?*i64, fd_out: fd_t, off_out: ?*i64, len: usize, flags: u32) usize {
    return syscall6(
        .copy_file_range,
        @as(usize, @bitCast(@as(isize, fd_in))),
        @intFromPtr(off_in),
        @as(usize, @bitCast(@as(isize, fd_out))),
        @intFromPtr(off_out),
        len,
        flags,
    );
}

pub fn bpf(cmd: BPF.Cmd, attr: *BPF.Attr, size: u32) usize {
    return syscall3(.bpf, @intFromEnum(cmd), @intFromPtr(attr), size);
}

pub fn sync() void {
    _ = syscall0(.sync);
}

pub fn syncfs(fd: fd_t) usize {
    return syscall1(.syncfs, @as(usize, @bitCast(@as(isize, fd))));
}

pub fn fsync(fd: fd_t) usize {
    return syscall1(.fsync, @as(usize, @bitCast(@as(isize, fd))));
}

pub fn fdatasync(fd: fd_t) usize {
    return syscall1(.fdatasync, @as(usize, @bitCast(@as(isize, fd))));
}

pub fn prctl(option: i32, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return syscall5(.prctl, @as(usize, @bitCast(@as(isize, option))), arg2, arg3, arg4, arg5);
}

pub fn getrlimit(resource: rlimit_resource, rlim: *rlimit) usize {
    // use prlimit64 to have 64 bit limits on 32 bit platforms
    return prlimit(0, resource, null, rlim);
}

pub fn setrlimit(resource: rlimit_resource, rlim: *const rlimit) usize {
    // use prlimit64 to have 64 bit limits on 32 bit platforms
    return prlimit(0, resource, rlim, null);
}

pub fn prlimit(pid: pid_t, resource: rlimit_resource, new_limit: ?*const rlimit, old_limit: ?*rlimit) usize {
    return syscall4(
        .prlimit64,
        @as(usize, @bitCast(@as(isize, pid))),
        @as(usize, @bitCast(@as(isize, @intFromEnum(resource)))),
        @intFromPtr(new_limit),
        @intFromPtr(old_limit),
    );
}

pub fn mincore(address: [*]u8, len: usize, vec: [*]u8) usize {
    return syscall3(.mincore, @intFromPtr(address), len, @intFromPtr(vec));
}

pub fn madvise(address: [*]u8, len: usize, advice: u32) usize {
    return syscall3(.madvise, @intFromPtr(address), len, advice);
}

pub fn pidfd_open(pid: pid_t, flags: u32) usize {
    return syscall2(.pidfd_open, @as(usize, @bitCast(@as(isize, pid))), flags);
}

pub fn pidfd_getfd(pidfd: fd_t, targetfd: fd_t, flags: u32) usize {
    return syscall3(
        .pidfd_getfd,
        @as(usize, @bitCast(@as(isize, pidfd))),
        @as(usize, @bitCast(@as(isize, targetfd))),
        flags,
    );
}

pub fn pidfd_send_signal(pidfd: fd_t, sig: i32, info: ?*siginfo_t, flags: u32) usize {
    return syscall4(
        .pidfd_send_signal,
        @as(usize, @bitCast(@as(isize, pidfd))),
        @as(usize, @bitCast(@as(isize, sig))),
        @intFromPtr(info),
        flags,
    );
}

pub fn process_vm_readv(pid: pid_t, local: []iovec, remote: []const iovec_const, flags: usize) usize {
    return syscall6(
        .process_vm_readv,
        @as(usize, @bitCast(@as(isize, pid))),
        @intFromPtr(local.ptr),
        local.len,
        @intFromPtr(remote.ptr),
        remote.len,
        flags,
    );
}

pub fn process_vm_writev(pid: pid_t, local: []const iovec_const, remote: []const iovec_const, flags: usize) usize {
    return syscall6(
        .process_vm_writev,
        @as(usize, @bitCast(@as(isize, pid))),
        @intFromPtr(local.ptr),
        local.len,
        @intFromPtr(remote.ptr),
        remote.len,
        flags,
    );
}

pub fn fadvise(fd: fd_t, offset: i64, len: i64, advice: usize) usize {
    if (comptime builtin.cpu.arch.isMIPS()) {
        // MIPS requires a 7 argument syscall

        const offset_halves = splitValue64(offset);
        const length_halves = splitValue64(len);

        return syscall7(
            .fadvise64,
            @as(usize, @bitCast(@as(isize, fd))),
            0,
            offset_halves[0],
            offset_halves[1],
            length_halves[0],
            length_halves[1],
            advice,
        );
    } else if (comptime builtin.cpu.arch.isARM()) {
        // ARM reorders the arguments

        const offset_halves = splitValue64(offset);
        const length_halves = splitValue64(len);

        return syscall6(
            .fadvise64_64,
            @as(usize, @bitCast(@as(isize, fd))),
            advice,
            offset_halves[0],
            offset_halves[1],
            length_halves[0],
            length_halves[1],
        );
    } else if (@hasField(SYS, "fadvise64_64") and usize_bits != 64) {
        // The extra usize check is needed to avoid SPARC64 because it provides both
        // fadvise64 and fadvise64_64 but the latter behaves differently than other platforms.

        const offset_halves = splitValue64(offset);
        const length_halves = splitValue64(len);

        return syscall6(
            .fadvise64_64,
            @as(usize, @bitCast(@as(isize, fd))),
            offset_halves[0],
            offset_halves[1],
            length_halves[0],
            length_halves[1],
            advice,
        );
    } else {
        return syscall4(
            .fadvise64,
            @as(usize, @bitCast(@as(isize, fd))),
            @as(usize, @bitCast(offset)),
            @as(usize, @bitCast(len)),
            advice,
        );
    }
}

pub fn perf_event_open(
    attr: *perf_event_attr,
    pid: pid_t,
    cpu: i32,
    group_fd: fd_t,
    flags: usize,
) usize {
    return syscall5(
        .perf_event_open,
        @intFromPtr(attr),
        @as(usize, @bitCast(@as(isize, pid))),
        @as(usize, @bitCast(@as(isize, cpu))),
        @as(usize, @bitCast(@as(isize, group_fd))),
        flags,
    );
}

pub fn seccomp(operation: u32, flags: u32, args: ?*const anyopaque) usize {
    return syscall3(.seccomp, operation, flags, @intFromPtr(args));
}

pub fn ptrace(
    req: u32,
    pid: pid_t,
    addr: usize,
    data: usize,
    addr2: usize,
) usize {
    return syscall5(
        .ptrace,
        req,
        @as(usize, @bitCast(@as(isize, pid))),
        addr,
        data,
        addr2,
    );
}

/// Query the page cache statistics of a file.
pub fn cachestat(
    /// The open file descriptor to retrieve statistics from.
    fd: fd_t,
    /// The byte range in `fd` to query.
    /// When `len > 0`, the range is `[off..off + len]`.
    /// When `len` == 0, the range is from `off` to the end of `fd`.
    cstat_range: *const cache_stat_range,
    /// The structure where page cache statistics are stored.
    cstat: *cache_stat,
    /// Currently unused, and must be set to `0`.
    flags: u32,
) usize {
    return syscall4(
        .cachestat,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(cstat_range),
        @intFromPtr(cstat),
        flags,
    );
}

pub fn map_shadow_stack(addr: u64, size: u64, flags: u32) usize {
    return syscall3(.map_shadow_stack, addr, size, flags);
}

pub const E = switch (native_arch) {
    .mips, .mipsel => enum(u16) {
        /// No error occurred.
        SUCCESS = 0,

        PERM = 1,
        NOENT = 2,
        SRCH = 3,
        INTR = 4,
        IO = 5,
        NXIO = 6,
        @"2BIG" = 7,
        NOEXEC = 8,
        BADF = 9,
        CHILD = 10,
        /// Also used for WOULDBLOCK.
        AGAIN = 11,
        NOMEM = 12,
        ACCES = 13,
        FAULT = 14,
        NOTBLK = 15,
        BUSY = 16,
        EXIST = 17,
        XDEV = 18,
        NODEV = 19,
        NOTDIR = 20,
        ISDIR = 21,
        INVAL = 22,
        NFILE = 23,
        MFILE = 24,
        NOTTY = 25,
        TXTBSY = 26,
        FBIG = 27,
        NOSPC = 28,
        SPIPE = 29,
        ROFS = 30,
        MLINK = 31,
        PIPE = 32,
        DOM = 33,
        RANGE = 34,

        NOMSG = 35,
        IDRM = 36,
        CHRNG = 37,
        L2NSYNC = 38,
        L3HLT = 39,
        L3RST = 40,
        LNRNG = 41,
        UNATCH = 42,
        NOCSI = 43,
        L2HLT = 44,
        DEADLK = 45,
        NOLCK = 46,
        BADE = 50,
        BADR = 51,
        XFULL = 52,
        NOANO = 53,
        BADRQC = 54,
        BADSLT = 55,
        DEADLOCK = 56,
        BFONT = 59,
        NOSTR = 60,
        NODATA = 61,
        TIME = 62,
        NOSR = 63,
        NONET = 64,
        NOPKG = 65,
        REMOTE = 66,
        NOLINK = 67,
        ADV = 68,
        SRMNT = 69,
        COMM = 70,
        PROTO = 71,
        DOTDOT = 73,
        MULTIHOP = 74,
        BADMSG = 77,
        NAMETOOLONG = 78,
        OVERFLOW = 79,
        NOTUNIQ = 80,
        BADFD = 81,
        REMCHG = 82,
        LIBACC = 83,
        LIBBAD = 84,
        LIBSCN = 85,
        LIBMAX = 86,
        LIBEXEC = 87,
        ILSEQ = 88,
        NOSYS = 89,
        LOOP = 90,
        RESTART = 91,
        STRPIPE = 92,
        NOTEMPTY = 93,
        USERS = 94,
        NOTSOCK = 95,
        DESTADDRREQ = 96,
        MSGSIZE = 97,
        PROTOTYPE = 98,
        NOPROTOOPT = 99,
        PROTONOSUPPORT = 120,
        SOCKTNOSUPPORT = 121,
        OPNOTSUPP = 122,
        PFNOSUPPORT = 123,
        AFNOSUPPORT = 124,
        ADDRINUSE = 125,
        ADDRNOTAVAIL = 126,
        NETDOWN = 127,
        NETUNREACH = 128,
        NETRESET = 129,
        CONNABORTED = 130,
        CONNRESET = 131,
        NOBUFS = 132,
        ISCONN = 133,
        NOTCONN = 134,
        UCLEAN = 135,
        NOTNAM = 137,
        NAVAIL = 138,
        ISNAM = 139,
        REMOTEIO = 140,
        SHUTDOWN = 143,
        TOOMANYREFS = 144,
        TIMEDOUT = 145,
        CONNREFUSED = 146,
        HOSTDOWN = 147,
        HOSTUNREACH = 148,
        ALREADY = 149,
        INPROGRESS = 150,
        STALE = 151,
        CANCELED = 158,
        NOMEDIUM = 159,
        MEDIUMTYPE = 160,
        NOKEY = 161,
        KEYEXPIRED = 162,
        KEYREVOKED = 163,
        KEYREJECTED = 164,
        OWNERDEAD = 165,
        NOTRECOVERABLE = 166,
        RFKILL = 167,
        HWPOISON = 168,
        DQUOT = 1133,
        _,

        pub const init = errnoFromSyscall;
    },
    .sparc, .sparcel, .sparc64 => enum(u16) {
        /// No error occurred.
        SUCCESS = 0,

        PERM = 1,
        NOENT = 2,
        SRCH = 3,
        INTR = 4,
        IO = 5,
        NXIO = 6,
        @"2BIG" = 7,
        NOEXEC = 8,
        BADF = 9,
        CHILD = 10,
        /// Also used for WOULDBLOCK
        AGAIN = 11,
        NOMEM = 12,
        ACCES = 13,
        FAULT = 14,
        NOTBLK = 15,
        BUSY = 16,
        EXIST = 17,
        XDEV = 18,
        NODEV = 19,
        NOTDIR = 20,
        ISDIR = 21,
        INVAL = 22,
        NFILE = 23,
        MFILE = 24,
        NOTTY = 25,
        TXTBSY = 26,
        FBIG = 27,
        NOSPC = 28,
        SPIPE = 29,
        ROFS = 30,
        MLINK = 31,
        PIPE = 32,
        DOM = 33,
        RANGE = 34,

        INPROGRESS = 36,
        ALREADY = 37,
        NOTSOCK = 38,
        DESTADDRREQ = 39,
        MSGSIZE = 40,
        PROTOTYPE = 41,
        NOPROTOOPT = 42,
        PROTONOSUPPORT = 43,
        SOCKTNOSUPPORT = 44,
        /// Also used for NOTSUP
        OPNOTSUPP = 45,
        PFNOSUPPORT = 46,
        AFNOSUPPORT = 47,
        ADDRINUSE = 48,
        ADDRNOTAVAIL = 49,
        NETDOWN = 50,
        NETUNREACH = 51,
        NETRESET = 52,
        CONNABORTED = 53,
        CONNRESET = 54,
        NOBUFS = 55,
        ISCONN = 56,
        NOTCONN = 57,
        SHUTDOWN = 58,
        TOOMANYREFS = 59,
        TIMEDOUT = 60,
        CONNREFUSED = 61,
        LOOP = 62,
        NAMETOOLONG = 63,
        HOSTDOWN = 64,
        HOSTUNREACH = 65,
        NOTEMPTY = 66,
        PROCLIM = 67,
        USERS = 68,
        DQUOT = 69,
        STALE = 70,
        REMOTE = 71,
        NOSTR = 72,
        TIME = 73,
        NOSR = 74,
        NOMSG = 75,
        BADMSG = 76,
        IDRM = 77,
        DEADLK = 78,
        NOLCK = 79,
        NONET = 80,
        RREMOTE = 81,
        NOLINK = 82,
        ADV = 83,
        SRMNT = 84,
        COMM = 85,
        PROTO = 86,
        MULTIHOP = 87,
        DOTDOT = 88,
        REMCHG = 89,
        NOSYS = 90,
        STRPIPE = 91,
        OVERFLOW = 92,
        BADFD = 93,
        CHRNG = 94,
        L2NSYNC = 95,
        L3HLT = 96,
        L3RST = 97,
        LNRNG = 98,
        UNATCH = 99,
        NOCSI = 100,
        L2HLT = 101,
        BADE = 102,
        BADR = 103,
        XFULL = 104,
        NOANO = 105,
        BADRQC = 106,
        BADSLT = 107,
        DEADLOCK = 108,
        BFONT = 109,
        LIBEXEC = 110,
        NODATA = 111,
        LIBBAD = 112,
        NOPKG = 113,
        LIBACC = 114,
        NOTUNIQ = 115,
        RESTART = 116,
        UCLEAN = 117,
        NOTNAM = 118,
        NAVAIL = 119,
        ISNAM = 120,
        REMOTEIO = 121,
        ILSEQ = 122,
        LIBMAX = 123,
        LIBSCN = 124,
        NOMEDIUM = 125,
        MEDIUMTYPE = 126,
        CANCELED = 127,
        NOKEY = 128,
        KEYEXPIRED = 129,
        KEYREVOKED = 130,
        KEYREJECTED = 131,
        OWNERDEAD = 132,
        NOTRECOVERABLE = 133,
        RFKILL = 134,
        HWPOISON = 135,
        _,

        pub const init = errnoFromSyscall;
    },
    else => enum(u16) {
        /// No error occurred.
        /// Same code used for `NSROK`.
        SUCCESS = 0,
        /// Operation not permitted
        PERM = 1,
        /// No such file or directory
        NOENT = 2,
        /// No such process
        SRCH = 3,
        /// Interrupted system call
        INTR = 4,
        /// I/O error
        IO = 5,
        /// No such device or address
        NXIO = 6,
        /// Arg list too long
        @"2BIG" = 7,
        /// Exec format error
        NOEXEC = 8,
        /// Bad file number
        BADF = 9,
        /// No child processes
        CHILD = 10,
        /// Try again
        /// Also means: WOULDBLOCK: operation would block
        AGAIN = 11,
        /// Out of memory
        NOMEM = 12,
        /// Permission denied
        ACCES = 13,
        /// Bad address
        FAULT = 14,
        /// Block device required
        NOTBLK = 15,
        /// Device or resource busy
        BUSY = 16,
        /// File exists
        EXIST = 17,
        /// Cross-device link
        XDEV = 18,
        /// No such device
        NODEV = 19,
        /// Not a directory
        NOTDIR = 20,
        /// Is a directory
        ISDIR = 21,
        /// Invalid argument
        INVAL = 22,
        /// File table overflow
        NFILE = 23,
        /// Too many open files
        MFILE = 24,
        /// Not a typewriter
        NOTTY = 25,
        /// Text file busy
        TXTBSY = 26,
        /// File too large
        FBIG = 27,
        /// No space left on device
        NOSPC = 28,
        /// Illegal seek
        SPIPE = 29,
        /// Read-only file system
        ROFS = 30,
        /// Too many links
        MLINK = 31,
        /// Broken pipe
        PIPE = 32,
        /// Math argument out of domain of func
        DOM = 33,
        /// Math result not representable
        RANGE = 34,
        /// Resource deadlock would occur
        DEADLK = 35,
        /// File name too long
        NAMETOOLONG = 36,
        /// No record locks available
        NOLCK = 37,
        /// Function not implemented
        NOSYS = 38,
        /// Directory not empty
        NOTEMPTY = 39,
        /// Too many symbolic links encountered
        LOOP = 40,
        /// No message of desired type
        NOMSG = 42,
        /// Identifier removed
        IDRM = 43,
        /// Channel number out of range
        CHRNG = 44,
        /// Level 2 not synchronized
        L2NSYNC = 45,
        /// Level 3 halted
        L3HLT = 46,
        /// Level 3 reset
        L3RST = 47,
        /// Link number out of range
        LNRNG = 48,
        /// Protocol driver not attached
        UNATCH = 49,
        /// No CSI structure available
        NOCSI = 50,
        /// Level 2 halted
        L2HLT = 51,
        /// Invalid exchange
        BADE = 52,
        /// Invalid request descriptor
        BADR = 53,
        /// Exchange full
        XFULL = 54,
        /// No anode
        NOANO = 55,
        /// Invalid request code
        BADRQC = 56,
        /// Invalid slot
        BADSLT = 57,
        /// Bad font file format
        BFONT = 59,
        /// Device not a stream
        NOSTR = 60,
        /// No data available
        NODATA = 61,
        /// Timer expired
        TIME = 62,
        /// Out of streams resources
        NOSR = 63,
        /// Machine is not on the network
        NONET = 64,
        /// Package not installed
        NOPKG = 65,
        /// Object is remote
        REMOTE = 66,
        /// Link has been severed
        NOLINK = 67,
        /// Advertise error
        ADV = 68,
        /// Srmount error
        SRMNT = 69,
        /// Communication error on send
        COMM = 70,
        /// Protocol error
        PROTO = 71,
        /// Multihop attempted
        MULTIHOP = 72,
        /// RFS specific error
        DOTDOT = 73,
        /// Not a data message
        BADMSG = 74,
        /// Value too large for defined data type
        OVERFLOW = 75,
        /// Name not unique on network
        NOTUNIQ = 76,
        /// File descriptor in bad state
        BADFD = 77,
        /// Remote address changed
        REMCHG = 78,
        /// Can not access a needed shared library
        LIBACC = 79,
        /// Accessing a corrupted shared library
        LIBBAD = 80,
        /// .lib section in a.out corrupted
        LIBSCN = 81,
        /// Attempting to link in too many shared libraries
        LIBMAX = 82,
        /// Cannot exec a shared library directly
        LIBEXEC = 83,
        /// Illegal byte sequence
        ILSEQ = 84,
        /// Interrupted system call should be restarted
        RESTART = 85,
        /// Streams pipe error
        STRPIPE = 86,
        /// Too many users
        USERS = 87,
        /// Socket operation on non-socket
        NOTSOCK = 88,
        /// Destination address required
        DESTADDRREQ = 89,
        /// Message too long
        MSGSIZE = 90,
        /// Protocol wrong type for socket
        PROTOTYPE = 91,
        /// Protocol not available
        NOPROTOOPT = 92,
        /// Protocol not supported
        PROTONOSUPPORT = 93,
        /// Socket type not supported
        SOCKTNOSUPPORT = 94,
        /// Operation not supported on transport endpoint
        /// This code also means `NOTSUP`.
        OPNOTSUPP = 95,
        /// Protocol family not supported
        PFNOSUPPORT = 96,
        /// Address family not supported by protocol
        AFNOSUPPORT = 97,
        /// Address already in use
        ADDRINUSE = 98,
        /// Cannot assign requested address
        ADDRNOTAVAIL = 99,
        /// Network is down
        NETDOWN = 100,
        /// Network is unreachable
        NETUNREACH = 101,
        /// Network dropped connection because of reset
        NETRESET = 102,
        /// Software caused connection abort
        CONNABORTED = 103,
        /// Connection reset by peer
        CONNRESET = 104,
        /// No buffer space available
        NOBUFS = 105,
        /// Transport endpoint is already connected
        ISCONN = 106,
        /// Transport endpoint is not connected
        NOTCONN = 107,
        /// Cannot send after transport endpoint shutdown
        SHUTDOWN = 108,
        /// Too many references: cannot splice
        TOOMANYREFS = 109,
        /// Connection timed out
        TIMEDOUT = 110,
        /// Connection refused
        CONNREFUSED = 111,
        /// Host is down
        HOSTDOWN = 112,
        /// No route to host
        HOSTUNREACH = 113,
        /// Operation already in progress
        ALREADY = 114,
        /// Operation now in progress
        INPROGRESS = 115,
        /// Stale NFS file handle
        STALE = 116,
        /// Structure needs cleaning
        UCLEAN = 117,
        /// Not a XENIX named type file
        NOTNAM = 118,
        /// No XENIX semaphores available
        NAVAIL = 119,
        /// Is a named type file
        ISNAM = 120,
        /// Remote I/O error
        REMOTEIO = 121,
        /// Quota exceeded
        DQUOT = 122,
        /// No medium found
        NOMEDIUM = 123,
        /// Wrong medium type
        MEDIUMTYPE = 124,
        /// Operation canceled
        CANCELED = 125,
        /// Required key not available
        NOKEY = 126,
        /// Key has expired
        KEYEXPIRED = 127,
        /// Key has been revoked
        KEYREVOKED = 128,
        /// Key was rejected by service
        KEYREJECTED = 129,
        // for robust mutexes
        /// Owner died
        OWNERDEAD = 130,
        /// State not recoverable
        NOTRECOVERABLE = 131,
        /// Operation not possible due to RF-kill
        RFKILL = 132,
        /// Memory page has hardware error
        HWPOISON = 133,
        // nameserver query return codes
        /// DNS server returned answer with no data
        NSRNODATA = 160,
        /// DNS server claims query was misformatted
        NSRFORMERR = 161,
        /// DNS server returned general failure
        NSRSERVFAIL = 162,
        /// Domain name not found
        NSRNOTFOUND = 163,
        /// DNS server does not implement requested operation
        NSRNOTIMP = 164,
        /// DNS server refused query
        NSRREFUSED = 165,
        /// Misformatted DNS query
        NSRBADQUERY = 166,
        /// Misformatted domain name
        NSRBADNAME = 167,
        /// Unsupported address family
        NSRBADFAMILY = 168,
        /// Misformatted DNS reply
        NSRBADRESP = 169,
        /// Could not contact DNS servers
        NSRCONNREFUSED = 170,
        /// Timeout while contacting DNS servers
        NSRTIMEOUT = 171,
        /// End of file
        NSROF = 172,
        /// Error reading file
        NSRFILE = 173,
        /// Out of memory
        NSRNOMEM = 174,
        /// Application terminated lookup
        NSRDESTRUCTION = 175,
        /// Domain name is too long
        NSRQUERYDOMAINTOOLONG = 176,
        /// Domain name is too long
        NSRCNAMELOOP = 177,

        _,

        pub const init = errnoFromSyscall;
    },
};

pub const pid_t = i32;
pub const fd_t = i32;
pub const socket_t = i32;
pub const uid_t = u32;
pub const gid_t = u32;
pub const clock_t = isize;

pub const NAME_MAX = 255;
pub const PATH_MAX = 4096;
pub const IOV_MAX = 1024;

/// Largest hardware address length
/// e.g. a mac address is a type of hardware address
pub const MAX_ADDR_LEN = 32;

pub const STDIN_FILENO = 0;
pub const STDOUT_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const AT = struct {
    /// Special value used to indicate openat should use the current working directory
    pub const FDCWD = -100;

    /// Do not follow symbolic links
    pub const SYMLINK_NOFOLLOW = 0x100;

    /// Remove directory instead of unlinking file
    pub const REMOVEDIR = 0x200;

    /// Follow symbolic links.
    pub const SYMLINK_FOLLOW = 0x400;

    /// Suppress terminal automount traversal
    pub const NO_AUTOMOUNT = 0x800;

    /// Allow empty relative pathname
    pub const EMPTY_PATH = 0x1000;

    /// Type of synchronisation required from statx()
    pub const STATX_SYNC_TYPE = 0x6000;

    /// - Do whatever stat() does
    pub const STATX_SYNC_AS_STAT = 0x0000;

    /// - Force the attributes to be sync'd with the server
    pub const STATX_FORCE_SYNC = 0x2000;

    /// - Don't sync attributes with the server
    pub const STATX_DONT_SYNC = 0x4000;

    /// Apply to the entire subtree
    pub const RECURSIVE = 0x8000;
};

pub const FALLOC = struct {
    /// Default is extend size
    pub const FL_KEEP_SIZE = 0x01;

    /// De-allocates range
    pub const FL_PUNCH_HOLE = 0x02;

    /// Reserved codepoint
    pub const FL_NO_HIDE_STALE = 0x04;

    /// Removes a range of a file without leaving a hole in the file
    pub const FL_COLLAPSE_RANGE = 0x08;

    /// Converts a range of file to zeros preferably without issuing data IO
    pub const FL_ZERO_RANGE = 0x10;

    /// Inserts space within the file size without overwriting any existing data
    pub const FL_INSERT_RANGE = 0x20;

    /// Unshares shared blocks within the file size without overwriting any existing data
    pub const FL_UNSHARE_RANGE = 0x40;
};

pub const FUTEX = struct {
    pub const WAIT = 0;
    pub const WAKE = 1;
    pub const FD = 2;
    pub const REQUEUE = 3;
    pub const CMP_REQUEUE = 4;
    pub const WAKE_OP = 5;
    pub const LOCK_PI = 6;
    pub const UNLOCK_PI = 7;
    pub const TRYLOCK_PI = 8;
    pub const WAIT_BITSET = 9;
    pub const WAKE_BITSET = 10;
    pub const WAIT_REQUEUE_PI = 11;
    pub const CMP_REQUEUE_PI = 12;

    pub const PRIVATE_FLAG = 128;

    pub const CLOCK_REALTIME = 256;

    /// Max numbers of elements in a `futex_waitv` array.
    pub const WAITV_MAX = 128;
};

pub const FUTEX2 = struct {
    pub const SIZE_U8 = 0x00;
    pub const SIZE_U16 = 0x01;
    pub const SIZE_U32 = 0x02;
    pub const SIZE_U64 = 0x03;
    pub const NUMA = 0x04;

    pub const PRIVATE = FUTEX.PRIVATE_FLAG;
};

pub const PROT = struct {
    /// page can not be accessed
    pub const NONE = 0x0;
    /// page can be read
    pub const READ = 0x1;
    /// page can be written
    pub const WRITE = 0x2;
    /// page can be executed
    pub const EXEC = 0x4;
    /// page may be used for atomic ops
    pub const SEM = switch (native_arch) {
        // TODO: also xtensa
        .mips, .mipsel, .mips64, .mips64el => 0x10,
        else => 0x8,
    };
    /// mprotect flag: extend change to start of growsdown vma
    pub const GROWSDOWN = 0x01000000;
    /// mprotect flag: extend change to end of growsup vma
    pub const GROWSUP = 0x02000000;
};

pub const FD_CLOEXEC = 1;

pub const F_OK = 0;
pub const X_OK = 1;
pub const W_OK = 2;
pub const R_OK = 4;

pub const W = struct {
    pub const NOHANG = 1;
    pub const UNTRACED = 2;
    pub const STOPPED = 2;
    pub const EXITED = 4;
    pub const CONTINUED = 8;
    pub const NOWAIT = 0x1000000;

    pub fn EXITSTATUS(s: u32) u8 {
        return @as(u8, @intCast((s & 0xff00) >> 8));
    }
    pub fn TERMSIG(s: u32) u32 {
        return s & 0x7f;
    }
    pub fn STOPSIG(s: u32) u32 {
        return EXITSTATUS(s);
    }
    pub fn IFEXITED(s: u32) bool {
        return TERMSIG(s) == 0;
    }
    pub fn IFSTOPPED(s: u32) bool {
        return @as(u16, @truncate(((s & 0xffff) *% 0x10001) >> 8)) > 0x7f00;
    }
    pub fn IFSIGNALED(s: u32) bool {
        return (s & 0xffff) -% 1 < 0xff;
    }
};

// waitid id types
pub const P = enum(c_uint) {
    ALL = 0,
    PID = 1,
    PGID = 2,
    PIDFD = 3,
    _,
};

pub const SA = if (is_mips) struct {
    pub const NOCLDSTOP = 1;
    pub const NOCLDWAIT = 0x10000;
    pub const SIGINFO = 8;
    pub const RESTART = 0x10000000;
    pub const RESETHAND = 0x80000000;
    pub const ONSTACK = 0x08000000;
    pub const NODEFER = 0x40000000;
    pub const RESTORER = 0x04000000;
} else if (is_sparc) struct {
    pub const NOCLDSTOP = 0x8;
    pub const NOCLDWAIT = 0x100;
    pub const SIGINFO = 0x200;
    pub const RESTART = 0x2;
    pub const RESETHAND = 0x4;
    pub const ONSTACK = 0x1;
    pub const NODEFER = 0x20;
    pub const RESTORER = 0x04000000;
} else struct {
    pub const NOCLDSTOP = 1;
    pub const NOCLDWAIT = 2;
    pub const SIGINFO = 4;
    pub const RESTART = 0x10000000;
    pub const RESETHAND = 0x80000000;
    pub const ONSTACK = 0x08000000;
    pub const NODEFER = 0x40000000;
    pub const RESTORER = 0x04000000;
};

pub const SIG = if (is_mips) struct {
    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const BUS = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const USR1 = 10;
    pub const SEGV = 11;
    pub const USR2 = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const STKFLT = 16;
    pub const CHLD = 17;
    pub const CONT = 18;
    pub const STOP = 19;
    pub const TSTP = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const URG = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const IO = 29;
    pub const POLL = 29;
    pub const PWR = 30;
    pub const SYS = 31;
    pub const UNUSED = SIG.SYS;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
} else if (is_sparc) struct {
    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 4;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const EMT = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const BUS = 10;
    pub const SEGV = 11;
    pub const SYS = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const URG = 16;
    pub const STOP = 17;
    pub const TSTP = 18;
    pub const CONT = 19;
    pub const CHLD = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const POLL = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const LOST = 29;
    pub const USR1 = 30;
    pub const USR2 = 31;
    pub const IOT = ABRT;
    pub const CLD = CHLD;
    pub const PWR = LOST;
    pub const IO = SIG.POLL;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
} else struct {
    pub const BLOCK = 0;
    pub const UNBLOCK = 1;
    pub const SETMASK = 2;

    pub const HUP = 1;
    pub const INT = 2;
    pub const QUIT = 3;
    pub const ILL = 4;
    pub const TRAP = 5;
    pub const ABRT = 6;
    pub const IOT = ABRT;
    pub const BUS = 7;
    pub const FPE = 8;
    pub const KILL = 9;
    pub const USR1 = 10;
    pub const SEGV = 11;
    pub const USR2 = 12;
    pub const PIPE = 13;
    pub const ALRM = 14;
    pub const TERM = 15;
    pub const STKFLT = 16;
    pub const CHLD = 17;
    pub const CONT = 18;
    pub const STOP = 19;
    pub const TSTP = 20;
    pub const TTIN = 21;
    pub const TTOU = 22;
    pub const URG = 23;
    pub const XCPU = 24;
    pub const XFSZ = 25;
    pub const VTALRM = 26;
    pub const PROF = 27;
    pub const WINCH = 28;
    pub const IO = 29;
    pub const POLL = 29;
    pub const PWR = 30;
    pub const SYS = 31;
    pub const UNUSED = SIG.SYS;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);
};

pub const kernel_rwf = u32;

pub const RWF = struct {
    pub const HIPRI: kernel_rwf = 0x00000001;
    pub const DSYNC: kernel_rwf = 0x00000002;
    pub const SYNC: kernel_rwf = 0x00000004;
    pub const NOWAIT: kernel_rwf = 0x00000008;
    pub const APPEND: kernel_rwf = 0x00000010;
};

pub const SEEK = struct {
    pub const SET = 0;
    pub const CUR = 1;
    pub const END = 2;
};

pub const SHUT = struct {
    pub const RD = 0;
    pub const WR = 1;
    pub const RDWR = 2;
};

pub const SOCK = struct {
    pub const STREAM = if (is_mips) 2 else 1;
    pub const DGRAM = if (is_mips) 1 else 2;
    pub const RAW = 3;
    pub const RDM = 4;
    pub const SEQPACKET = 5;
    pub const DCCP = 6;
    pub const PACKET = 10;
    pub const CLOEXEC = if (is_sparc) 0o20000000 else 0o2000000;
    pub const NONBLOCK = if (is_mips) 0o200 else if (is_sparc) 0o40000 else 0o4000;
};

pub const TCP = struct {
    /// Turn off Nagle's algorithm
    pub const NODELAY = 1;
    /// Limit MSS
    pub const MAXSEG = 2;
    /// Never send partially complete segments.
    pub const CORK = 3;
    /// Start keeplives after this period, in seconds
    pub const KEEPIDLE = 4;
    /// Interval between keepalives
    pub const KEEPINTVL = 5;
    /// Number of keepalives before death
    pub const KEEPCNT = 6;
    /// Number of SYN retransmits
    pub const SYNCNT = 7;
    /// Life time of orphaned FIN-WAIT-2 state
    pub const LINGER2 = 8;
    /// Wake up listener only when data arrive
    pub const DEFER_ACCEPT = 9;
    /// Bound advertised window
    pub const WINDOW_CLAMP = 10;
    /// Information about this connection.
    pub const INFO = 11;
    /// Block/reenable quick acks
    pub const QUICKACK = 12;
    /// Congestion control algorithm
    pub const CONGESTION = 13;
    /// TCP MD5 Signature (RFC2385)
    pub const MD5SIG = 14;
    /// Use linear timeouts for thin streams
    pub const THIN_LINEAR_TIMEOUTS = 16;
    /// Fast retrans. after 1 dupack
    pub const THIN_DUPACK = 17;
    /// How long for loss retry before timeout
    pub const USER_TIMEOUT = 18;
    /// TCP sock is under repair right now
    pub const REPAIR = 19;
    pub const REPAIR_QUEUE = 20;
    pub const QUEUE_SEQ = 21;
    pub const REPAIR_OPTIONS = 22;
    /// Enable FastOpen on listeners
    pub const FASTOPEN = 23;
    pub const TIMESTAMP = 24;
    /// limit number of unsent bytes in write queue
    pub const NOTSENT_LOWAT = 25;
    /// Get Congestion Control (optional) info
    pub const CC_INFO = 26;
    /// Record SYN headers for new connections
    pub const SAVE_SYN = 27;
    /// Get SYN headers recorded for connection
    pub const SAVED_SYN = 28;
    /// Get/set window parameters
    pub const REPAIR_WINDOW = 29;
    /// Attempt FastOpen with connect
    pub const FASTOPEN_CONNECT = 30;
    /// Attach a ULP to a TCP connection
    pub const ULP = 31;
    /// TCP MD5 Signature with extensions
    pub const MD5SIG_EXT = 32;
    /// Set the key for Fast Open (cookie)
    pub const FASTOPEN_KEY = 33;
    /// Enable TFO without a TFO cookie
    pub const FASTOPEN_NO_COOKIE = 34;
    pub const ZEROCOPY_RECEIVE = 35;
    /// Notify bytes available to read as a cmsg on read
    pub const INQ = 36;
    pub const CM_INQ = INQ;
    /// delay outgoing packets by XX usec
    pub const TX_DELAY = 37;

    pub const REPAIR_ON = 1;
    pub const REPAIR_OFF = 0;
    /// Turn off without window probes
    pub const REPAIR_OFF_NO_WP = -1;
};

pub const PF = struct {
    pub const UNSPEC = 0;
    pub const LOCAL = 1;
    pub const UNIX = LOCAL;
    pub const FILE = LOCAL;
    pub const INET = 2;
    pub const AX25 = 3;
    pub const IPX = 4;
    pub const APPLETALK = 5;
    pub const NETROM = 6;
    pub const BRIDGE = 7;
    pub const ATMPVC = 8;
    pub const X25 = 9;
    pub const INET6 = 10;
    pub const ROSE = 11;
    pub const DECnet = 12;
    pub const NETBEUI = 13;
    pub const SECURITY = 14;
    pub const KEY = 15;
    pub const NETLINK = 16;
    pub const ROUTE = PF.NETLINK;
    pub const PACKET = 17;
    pub const ASH = 18;
    pub const ECONET = 19;
    pub const ATMSVC = 20;
    pub const RDS = 21;
    pub const SNA = 22;
    pub const IRDA = 23;
    pub const PPPOX = 24;
    pub const WANPIPE = 25;
    pub const LLC = 26;
    pub const IB = 27;
    pub const MPLS = 28;
    pub const CAN = 29;
    pub const TIPC = 30;
    pub const BLUETOOTH = 31;
    pub const IUCV = 32;
    pub const RXRPC = 33;
    pub const ISDN = 34;
    pub const PHONET = 35;
    pub const IEEE802154 = 36;
    pub const CAIF = 37;
    pub const ALG = 38;
    pub const NFC = 39;
    pub const VSOCK = 40;
    pub const KCM = 41;
    pub const QIPCRTR = 42;
    pub const SMC = 43;
    pub const XDP = 44;
    pub const MAX = 45;
};

pub const AF = struct {
    pub const UNSPEC = PF.UNSPEC;
    pub const LOCAL = PF.LOCAL;
    pub const UNIX = AF.LOCAL;
    pub const FILE = AF.LOCAL;
    pub const INET = PF.INET;
    pub const AX25 = PF.AX25;
    pub const IPX = PF.IPX;
    pub const APPLETALK = PF.APPLETALK;
    pub const NETROM = PF.NETROM;
    pub const BRIDGE = PF.BRIDGE;
    pub const ATMPVC = PF.ATMPVC;
    pub const X25 = PF.X25;
    pub const INET6 = PF.INET6;
    pub const ROSE = PF.ROSE;
    pub const DECnet = PF.DECnet;
    pub const NETBEUI = PF.NETBEUI;
    pub const SECURITY = PF.SECURITY;
    pub const KEY = PF.KEY;
    pub const NETLINK = PF.NETLINK;
    pub const ROUTE = PF.ROUTE;
    pub const PACKET = PF.PACKET;
    pub const ASH = PF.ASH;
    pub const ECONET = PF.ECONET;
    pub const ATMSVC = PF.ATMSVC;
    pub const RDS = PF.RDS;
    pub const SNA = PF.SNA;
    pub const IRDA = PF.IRDA;
    pub const PPPOX = PF.PPPOX;
    pub const WANPIPE = PF.WANPIPE;
    pub const LLC = PF.LLC;
    pub const IB = PF.IB;
    pub const MPLS = PF.MPLS;
    pub const CAN = PF.CAN;
    pub const TIPC = PF.TIPC;
    pub const BLUETOOTH = PF.BLUETOOTH;
    pub const IUCV = PF.IUCV;
    pub const RXRPC = PF.RXRPC;
    pub const ISDN = PF.ISDN;
    pub const PHONET = PF.PHONET;
    pub const IEEE802154 = PF.IEEE802154;
    pub const CAIF = PF.CAIF;
    pub const ALG = PF.ALG;
    pub const NFC = PF.NFC;
    pub const VSOCK = PF.VSOCK;
    pub const KCM = PF.KCM;
    pub const QIPCRTR = PF.QIPCRTR;
    pub const SMC = PF.SMC;
    pub const XDP = PF.XDP;
    pub const MAX = PF.MAX;
};

pub const SO = if (is_mips) struct {
    pub const DEBUG = 1;
    pub const REUSEADDR = 0x0004;
    pub const KEEPALIVE = 0x0008;
    pub const DONTROUTE = 0x0010;
    pub const BROADCAST = 0x0020;
    pub const LINGER = 0x0080;
    pub const OOBINLINE = 0x0100;
    pub const REUSEPORT = 0x0200;
    pub const SNDBUF = 0x1001;
    pub const RCVBUF = 0x1002;
    pub const SNDLOWAT = 0x1003;
    pub const RCVLOWAT = 0x1004;
    pub const RCVTIMEO = 0x1006;
    pub const SNDTIMEO = 0x1005;
    pub const ERROR = 0x1007;
    pub const TYPE = 0x1008;
    pub const ACCEPTCONN = 0x1009;
    pub const PROTOCOL = 0x1028;
    pub const DOMAIN = 0x1029;
    pub const NO_CHECK = 11;
    pub const PRIORITY = 12;
    pub const BSDCOMPAT = 14;
    pub const PASSCRED = 17;
    pub const PEERCRED = 18;
    pub const PEERSEC = 30;
    pub const SNDBUFFORCE = 31;
    pub const RCVBUFFORCE = 33;
    pub const SECURITY_AUTHENTICATION = 22;
    pub const SECURITY_ENCRYPTION_TRANSPORT = 23;
    pub const SECURITY_ENCRYPTION_NETWORK = 24;
    pub const BINDTODEVICE = 25;
    pub const ATTACH_FILTER = 26;
    pub const DETACH_FILTER = 27;
    pub const GET_FILTER = ATTACH_FILTER;
    pub const PEERNAME = 28;
    pub const TIMESTAMP_OLD = 29;
    pub const PASSSEC = 34;
    pub const TIMESTAMPNS_OLD = 35;
    pub const MARK = 36;
    pub const TIMESTAMPING_OLD = 37;
    pub const RXQ_OVFL = 40;
    pub const WIFI_STATUS = 41;
    pub const PEEK_OFF = 42;
    pub const NOFCS = 43;
    pub const LOCK_FILTER = 44;
    pub const SELECT_ERR_QUEUE = 45;
    pub const BUSY_POLL = 46;
    pub const MAX_PACING_RATE = 47;
    pub const BPF_EXTENSIONS = 48;
    pub const INCOMING_CPU = 49;
    pub const ATTACH_BPF = 50;
    pub const DETACH_BPF = DETACH_FILTER;
    pub const ATTACH_REUSEPORT_CBPF = 51;
    pub const ATTACH_REUSEPORT_EBPF = 52;
    pub const CNX_ADVICE = 53;
    pub const MEMINFO = 55;
    pub const INCOMING_NAPI_ID = 56;
    pub const COOKIE = 57;
    pub const PEERGROUPS = 59;
    pub const ZEROCOPY = 60;
    pub const TXTIME = 61;
    pub const BINDTOIFINDEX = 62;
    pub const TIMESTAMP_NEW = 63;
    pub const TIMESTAMPNS_NEW = 64;
    pub const TIMESTAMPING_NEW = 65;
    pub const RCVTIMEO_NEW = 66;
    pub const SNDTIMEO_NEW = 67;
    pub const DETACH_REUSEPORT_BPF = 68;
} else if (is_ppc or is_ppc64) struct {
    pub const DEBUG = 1;
    pub const REUSEADDR = 2;
    pub const TYPE = 3;
    pub const ERROR = 4;
    pub const DONTROUTE = 5;
    pub const BROADCAST = 6;
    pub const SNDBUF = 7;
    pub const RCVBUF = 8;
    pub const KEEPALIVE = 9;
    pub const OOBINLINE = 10;
    pub const NO_CHECK = 11;
    pub const PRIORITY = 12;
    pub const LINGER = 13;
    pub const BSDCOMPAT = 14;
    pub const REUSEPORT = 15;
    pub const RCVLOWAT = 16;
    pub const SNDLOWAT = 17;
    pub const RCVTIMEO = 18;
    pub const SNDTIMEO = 19;
    pub const PASSCRED = 20;
    pub const PEERCRED = 21;
    pub const ACCEPTCONN = 30;
    pub const PEERSEC = 31;
    pub const SNDBUFFORCE = 32;
    pub const RCVBUFFORCE = 33;
    pub const PROTOCOL = 38;
    pub const DOMAIN = 39;
    pub const SECURITY_AUTHENTICATION = 22;
    pub const SECURITY_ENCRYPTION_TRANSPORT = 23;
    pub const SECURITY_ENCRYPTION_NETWORK = 24;
    pub const BINDTODEVICE = 25;
    pub const ATTACH_FILTER = 26;
    pub const DETACH_FILTER = 27;
    pub const GET_FILTER = ATTACH_FILTER;
    pub const PEERNAME = 28;
    pub const TIMESTAMP_OLD = 29;
    pub const PASSSEC = 34;
    pub const TIMESTAMPNS_OLD = 35;
    pub const MARK = 36;
    pub const TIMESTAMPING_OLD = 37;
    pub const RXQ_OVFL = 40;
    pub const WIFI_STATUS = 41;
    pub const PEEK_OFF = 42;
    pub const NOFCS = 43;
    pub const LOCK_FILTER = 44;
    pub const SELECT_ERR_QUEUE = 45;
    pub const BUSY_POLL = 46;
    pub const MAX_PACING_RATE = 47;
    pub const BPF_EXTENSIONS = 48;
    pub const INCOMING_CPU = 49;
    pub const ATTACH_BPF = 50;
    pub const DETACH_BPF = DETACH_FILTER;
    pub const ATTACH_REUSEPORT_CBPF = 51;
    pub const ATTACH_REUSEPORT_EBPF = 52;
    pub const CNX_ADVICE = 53;
    pub const MEMINFO = 55;
    pub const INCOMING_NAPI_ID = 56;
    pub const COOKIE = 57;
    pub const PEERGROUPS = 59;
    pub const ZEROCOPY = 60;
    pub const TXTIME = 61;
    pub const BINDTOIFINDEX = 62;
    pub const TIMESTAMP_NEW = 63;
    pub const TIMESTAMPNS_NEW = 64;
    pub const TIMESTAMPING_NEW = 65;
    pub const RCVTIMEO_NEW = 66;
    pub const SNDTIMEO_NEW = 67;
    pub const DETACH_REUSEPORT_BPF = 68;
} else if (is_sparc) struct {
    pub const DEBUG = 1;
    pub const REUSEADDR = 4;
    pub const TYPE = 4104;
    pub const ERROR = 4103;
    pub const DONTROUTE = 16;
    pub const BROADCAST = 32;
    pub const SNDBUF = 4097;
    pub const RCVBUF = 4098;
    pub const KEEPALIVE = 8;
    pub const OOBINLINE = 256;
    pub const NO_CHECK = 11;
    pub const PRIORITY = 12;
    pub const LINGER = 128;
    pub const BSDCOMPAT = 1024;
    pub const REUSEPORT = 512;
    pub const PASSCRED = 2;
    pub const PEERCRED = 64;
    pub const RCVLOWAT = 2048;
    pub const SNDLOWAT = 4096;
    pub const RCVTIMEO = 8192;
    pub const SNDTIMEO = 16384;
    pub const ACCEPTCONN = 32768;
    pub const PEERSEC = 30;
    pub const SNDBUFFORCE = 4106;
    pub const RCVBUFFORCE = 4107;
    pub const PROTOCOL = 4136;
    pub const DOMAIN = 4137;
    pub const SECURITY_AUTHENTICATION = 20481;
    pub const SECURITY_ENCRYPTION_TRANSPORT = 20482;
    pub const SECURITY_ENCRYPTION_NETWORK = 20484;
    pub const BINDTODEVICE = 13;
    pub const ATTACH_FILTER = 26;
    pub const DETACH_FILTER = 27;
    pub const GET_FILTER = 26;
    pub const PEERNAME = 28;
    pub const TIMESTAMP_OLD = 29;
    pub const PASSSEC = 31;
    pub const TIMESTAMPNS_OLD = 33;
    pub const MARK = 34;
    pub const TIMESTAMPING_OLD = 35;
    pub const RXQ_OVFL = 36;
    pub const WIFI_STATUS = 37;
    pub const PEEK_OFF = 38;
    pub const NOFCS = 39;
    pub const LOCK_FILTER = 40;
    pub const SELECT_ERR_QUEUE = 41;
    pub const BUSY_POLL = 48;
    pub const MAX_PACING_RATE = 49;
    pub const BPF_EXTENSIONS = 50;
    pub const INCOMING_CPU = 51;
    pub const ATTACH_BPF = 52;
    pub const DETACH_BPF = 27;
    pub const ATTACH_REUSEPORT_CBPF = 53;
    pub const ATTACH_REUSEPORT_EBPF = 54;
    pub const CNX_ADVICE = 55;
    pub const MEMINFO = 57;
    pub const INCOMING_NAPI_ID = 58;
    pub const COOKIE = 59;
    pub const PEERGROUPS = 61;
    pub const ZEROCOPY = 62;
    pub const TXTIME = 63;
    pub const BINDTOIFINDEX = 65;
    pub const TIMESTAMP_NEW = 70;
    pub const TIMESTAMPNS_NEW = 66;
    pub const TIMESTAMPING_NEW = 67;
    pub const RCVTIMEO_NEW = 68;
    pub const SNDTIMEO_NEW = 69;
    pub const DETACH_REUSEPORT_BPF = 71;
} else struct {
    pub const DEBUG = 1;
    pub const REUSEADDR = 2;
    pub const TYPE = 3;
    pub const ERROR = 4;
    pub const DONTROUTE = 5;
    pub const BROADCAST = 6;
    pub const SNDBUF = 7;
    pub const RCVBUF = 8;
    pub const KEEPALIVE = 9;
    pub const OOBINLINE = 10;
    pub const NO_CHECK = 11;
    pub const PRIORITY = 12;
    pub const LINGER = 13;
    pub const BSDCOMPAT = 14;
    pub const REUSEPORT = 15;
    pub const PASSCRED = 16;
    pub const PEERCRED = 17;
    pub const RCVLOWAT = 18;
    pub const SNDLOWAT = 19;
    pub const RCVTIMEO = 20;
    pub const SNDTIMEO = 21;
    pub const ACCEPTCONN = 30;
    pub const PEERSEC = 31;
    pub const SNDBUFFORCE = 32;
    pub const RCVBUFFORCE = 33;
    pub const PROTOCOL = 38;
    pub const DOMAIN = 39;
    pub const SECURITY_AUTHENTICATION = 22;
    pub const SECURITY_ENCRYPTION_TRANSPORT = 23;
    pub const SECURITY_ENCRYPTION_NETWORK = 24;
    pub const BINDTODEVICE = 25;
    pub const ATTACH_FILTER = 26;
    pub const DETACH_FILTER = 27;
    pub const GET_FILTER = ATTACH_FILTER;
    pub const PEERNAME = 28;
    pub const TIMESTAMP_OLD = 29;
    pub const PASSSEC = 34;
    pub const TIMESTAMPNS_OLD = 35;
    pub const MARK = 36;
    pub const TIMESTAMPING_OLD = 37;
    pub const RXQ_OVFL = 40;
    pub const WIFI_STATUS = 41;
    pub const PEEK_OFF = 42;
    pub const NOFCS = 43;
    pub const LOCK_FILTER = 44;
    pub const SELECT_ERR_QUEUE = 45;
    pub const BUSY_POLL = 46;
    pub const MAX_PACING_RATE = 47;
    pub const BPF_EXTENSIONS = 48;
    pub const INCOMING_CPU = 49;
    pub const ATTACH_BPF = 50;
    pub const DETACH_BPF = DETACH_FILTER;
    pub const ATTACH_REUSEPORT_CBPF = 51;
    pub const ATTACH_REUSEPORT_EBPF = 52;
    pub const CNX_ADVICE = 53;
    pub const MEMINFO = 55;
    pub const INCOMING_NAPI_ID = 56;
    pub const COOKIE = 57;
    pub const PEERGROUPS = 59;
    pub const ZEROCOPY = 60;
    pub const TXTIME = 61;
    pub const BINDTOIFINDEX = 62;
    pub const TIMESTAMP_NEW = 63;
    pub const TIMESTAMPNS_NEW = 64;
    pub const TIMESTAMPING_NEW = 65;
    pub const RCVTIMEO_NEW = 66;
    pub const SNDTIMEO_NEW = 67;
    pub const DETACH_REUSEPORT_BPF = 68;
};

pub const SCM = struct {
    pub const WIFI_STATUS = SO.WIFI_STATUS;
    pub const TIMESTAMPING_OPT_STATS = 54;
    pub const TIMESTAMPING_PKTINFO = 58;
    pub const TXTIME = SO.TXTIME;
};

pub const SOL = struct {
    pub const SOCKET = if (is_mips or is_sparc) 65535 else 1;

    pub const IP = 0;
    pub const IPV6 = 41;
    pub const ICMPV6 = 58;

    pub const RAW = 255;
    pub const DECNET = 261;
    pub const X25 = 262;
    pub const PACKET = 263;
    pub const ATM = 264;
    pub const AAL = 265;
    pub const IRDA = 266;
    pub const NETBEUI = 267;
    pub const LLC = 268;
    pub const DCCP = 269;
    pub const NETLINK = 270;
    pub const TIPC = 271;
    pub const RXRPC = 272;
    pub const PPPOL2TP = 273;
    pub const BLUETOOTH = 274;
    pub const PNPIPE = 275;
    pub const RDS = 276;
    pub const IUCV = 277;
    pub const CAIF = 278;
    pub const ALG = 279;
    pub const NFC = 280;
    pub const KCM = 281;
    pub const TLS = 282;
    pub const XDP = 283;
};

pub const SOMAXCONN = 128;

pub const IP = struct {
    pub const TOS = 1;
    pub const TTL = 2;
    pub const HDRINCL = 3;
    pub const OPTIONS = 4;
    pub const ROUTER_ALERT = 5;
    pub const RECVOPTS = 6;
    pub const RETOPTS = 7;
    pub const PKTINFO = 8;
    pub const PKTOPTIONS = 9;
    pub const PMTUDISC = 10;
    pub const MTU_DISCOVER = 10;
    pub const RECVERR = 11;
    pub const RECVTTL = 12;
    pub const RECVTOS = 13;
    pub const MTU = 14;
    pub const FREEBIND = 15;
    pub const IPSEC_POLICY = 16;
    pub const XFRM_POLICY = 17;
    pub const PASSSEC = 18;
    pub const TRANSPARENT = 19;
    pub const ORIGDSTADDR = 20;
    pub const RECVORIGDSTADDR = IP.ORIGDSTADDR;
    pub const MINTTL = 21;
    pub const NODEFRAG = 22;
    pub const CHECKSUM = 23;
    pub const BIND_ADDRESS_NO_PORT = 24;
    pub const RECVFRAGSIZE = 25;
    pub const MULTICAST_IF = 32;
    pub const MULTICAST_TTL = 33;
    pub const MULTICAST_LOOP = 34;
    pub const ADD_MEMBERSHIP = 35;
    pub const DROP_MEMBERSHIP = 36;
    pub const UNBLOCK_SOURCE = 37;
    pub const BLOCK_SOURCE = 38;
    pub const ADD_SOURCE_MEMBERSHIP = 39;
    pub const DROP_SOURCE_MEMBERSHIP = 40;
    pub const MSFILTER = 41;
    pub const MULTICAST_ALL = 49;
    pub const UNICAST_IF = 50;

    pub const RECVRETOPTS = IP.RETOPTS;

    pub const PMTUDISC_DONT = 0;
    pub const PMTUDISC_WANT = 1;
    pub const PMTUDISC_DO = 2;
    pub const PMTUDISC_PROBE = 3;
    pub const PMTUDISC_INTERFACE = 4;
    pub const PMTUDISC_OMIT = 5;

    pub const DEFAULT_MULTICAST_TTL = 1;
    pub const DEFAULT_MULTICAST_LOOP = 1;
    pub const MAX_MEMBERSHIPS = 20;
};

/// IPv6 socket options
pub const IPV6 = struct {
    pub const ADDRFORM = 1;
    pub const @"2292PKTINFO" = 2;
    pub const @"2292HOPOPTS" = 3;
    pub const @"2292DSTOPTS" = 4;
    pub const @"2292RTHDR" = 5;
    pub const @"2292PKTOPTIONS" = 6;
    pub const CHECKSUM = 7;
    pub const @"2292HOPLIMIT" = 8;
    pub const NEXTHOP = 9;
    pub const AUTHHDR = 10;
    pub const FLOWINFO = 11;

    pub const UNICAST_HOPS = 16;
    pub const MULTICAST_IF = 17;
    pub const MULTICAST_HOPS = 18;
    pub const MULTICAST_LOOP = 19;
    pub const ADD_MEMBERSHIP = 20;
    pub const DROP_MEMBERSHIP = 21;
    pub const ROUTER_ALERT = 22;
    pub const MTU_DISCOVER = 23;
    pub const MTU = 24;
    pub const RECVERR = 25;
    pub const V6ONLY = 26;
    pub const JOIN_ANYCAST = 27;
    pub const LEAVE_ANYCAST = 28;

    // IPV6.MTU_DISCOVER values
    pub const PMTUDISC_DONT = 0;
    pub const PMTUDISC_WANT = 1;
    pub const PMTUDISC_DO = 2;
    pub const PMTUDISC_PROBE = 3;
    pub const PMTUDISC_INTERFACE = 4;
    pub const PMTUDISC_OMIT = 5;

    // Flowlabel
    pub const FLOWLABEL_MGR = 32;
    pub const FLOWINFO_SEND = 33;
    pub const IPSEC_POLICY = 34;
    pub const XFRM_POLICY = 35;
    pub const HDRINCL = 36;

    // Advanced API (RFC3542) (1)
    pub const RECVPKTINFO = 49;
    pub const PKTINFO = 50;
    pub const RECVHOPLIMIT = 51;
    pub const HOPLIMIT = 52;
    pub const RECVHOPOPTS = 53;
    pub const HOPOPTS = 54;
    pub const RTHDRDSTOPTS = 55;
    pub const RECVRTHDR = 56;
    pub const RTHDR = 57;
    pub const RECVDSTOPTS = 58;
    pub const DSTOPTS = 59;
    pub const RECVPATHMTU = 60;
    pub const PATHMTU = 61;
    pub const DONTFRAG = 62;

    // Advanced API (RFC3542) (2)
    pub const RECVTCLASS = 66;
    pub const TCLASS = 67;

    pub const AUTOFLOWLABEL = 70;

    // RFC5014: Source address selection
    pub const ADDR_PREFERENCES = 72;

    pub const PREFER_SRC_TMP = 0x0001;
    pub const PREFER_SRC_PUBLIC = 0x0002;
    pub const PREFER_SRC_PUBTMP_DEFAULT = 0x0100;
    pub const PREFER_SRC_COA = 0x0004;
    pub const PREFER_SRC_HOME = 0x0400;
    pub const PREFER_SRC_CGA = 0x0008;
    pub const PREFER_SRC_NONCGA = 0x0800;

    // RFC5082: Generalized Ttl Security Mechanism
    pub const MINHOPCOUNT = 73;

    pub const ORIGDSTADDR = 74;
    pub const RECVORIGDSTADDR = IPV6.ORIGDSTADDR;
    pub const TRANSPARENT = 75;
    pub const UNICAST_IF = 76;
    pub const RECVFRAGSIZE = 77;
    pub const FREEBIND = 78;
};

pub const MSG = struct {
    pub const OOB = 0x0001;
    pub const PEEK = 0x0002;
    pub const DONTROUTE = 0x0004;
    pub const CTRUNC = 0x0008;
    pub const PROXY = 0x0010;
    pub const TRUNC = 0x0020;
    pub const DONTWAIT = 0x0040;
    pub const EOR = 0x0080;
    pub const WAITALL = 0x0100;
    pub const FIN = 0x0200;
    pub const SYN = 0x0400;
    pub const CONFIRM = 0x0800;
    pub const RST = 0x1000;
    pub const ERRQUEUE = 0x2000;
    pub const NOSIGNAL = 0x4000;
    pub const MORE = 0x8000;
    pub const WAITFORONE = 0x10000;
    pub const BATCH = 0x40000;
    pub const ZEROCOPY = 0x4000000;
    pub const FASTOPEN = 0x20000000;
    pub const CMSG_CLOEXEC = 0x40000000;
};

pub const DT = struct {
    pub const UNKNOWN = 0;
    pub const FIFO = 1;
    pub const CHR = 2;
    pub const DIR = 4;
    pub const BLK = 6;
    pub const REG = 8;
    pub const LNK = 10;
    pub const SOCK = 12;
    pub const WHT = 14;
};

pub const T = struct {
    pub const CGETS = if (is_mips) 0x540D else 0x5401;
    pub const CSETS = if (is_mips) 0x540e else 0x5402;
    pub const CSETSW = if (is_mips) 0x540f else 0x5403;
    pub const CSETSF = if (is_mips) 0x5410 else 0x5404;
    pub const CGETA = if (is_mips) 0x5401 else 0x5405;
    pub const CSETA = if (is_mips) 0x5402 else 0x5406;
    pub const CSETAW = if (is_mips) 0x5403 else 0x5407;
    pub const CSETAF = if (is_mips) 0x5404 else 0x5408;
    pub const CSBRK = if (is_mips) 0x5405 else 0x5409;
    pub const CXONC = if (is_mips) 0x5406 else 0x540A;
    pub const CFLSH = if (is_mips) 0x5407 else 0x540B;
    pub const IOCEXCL = if (is_mips) 0x740d else 0x540C;
    pub const IOCNXCL = if (is_mips) 0x740e else 0x540D;
    pub const IOCSCTTY = if (is_mips) 0x7472 else 0x540E;
    pub const IOCGPGRP = if (is_mips) 0x5472 else 0x540F;
    pub const IOCSPGRP = if (is_mips) 0x741d else 0x5410;
    pub const IOCOUTQ = if (is_mips) 0x7472 else 0x5411;
    pub const IOCSTI = if (is_mips) 0x5472 else 0x5412;
    pub const IOCGWINSZ = if (is_mips or is_ppc64) 0x40087468 else 0x5413;
    pub const IOCSWINSZ = if (is_mips or is_ppc64) 0x80087467 else 0x5414;
    pub const IOCMGET = if (is_mips) 0x741d else 0x5415;
    pub const IOCMBIS = if (is_mips) 0x741b else 0x5416;
    pub const IOCMBIC = if (is_mips) 0x741c else 0x5417;
    pub const IOCMSET = if (is_mips) 0x741a else 0x5418;
    pub const IOCGSOFTCAR = if (is_mips) 0x5481 else 0x5419;
    pub const IOCSSOFTCAR = if (is_mips) 0x5482 else 0x541A;
    pub const FIONREAD = if (is_mips) 0x467F else 0x541B;
    pub const IOCINQ = FIONREAD;
    pub const IOCLINUX = if (is_mips) 0x5483 else 0x541C;
    pub const IOCCONS = if (is_mips) IOCTL.IOW('t', 120, c_int) else 0x541D;
    pub const IOCGSERIAL = if (is_mips) 0x5484 else 0x541E;
    pub const IOCSSERIAL = if (is_mips) 0x5485 else 0x541F;
    pub const IOCPKT = if (is_mips) 0x5470 else 0x5420;
    pub const FIONBIO = if (is_mips) 0x667e else 0x5421;
    pub const IOCNOTTY = if (is_mips) 0x5471 else 0x5422;
    pub const IOCSETD = if (is_mips) 0x7401 else 0x5423;
    pub const IOCGETD = if (is_mips) 0x7400 else 0x5424;
    pub const CSBRKP = if (is_mips) 0x5486 else 0x5425;
    pub const IOCSBRK = 0x5427;
    pub const IOCCBRK = 0x5428;
    pub const IOCGSID = if (is_mips) 0x7416 else 0x5429;
    pub const IOCGRS485 = 0x542E;
    pub const IOCSRS485 = 0x542F;
    pub const IOCGPTN = IOCTL.IOR('T', 0x30, c_uint);
    pub const IOCSPTLCK = IOCTL.IOW('T', 0x31, c_int);
    pub const IOCGDEV = IOCTL.IOR('T', 0x32, c_uint);
    pub const CGETX = 0x5432;
    pub const CSETX = 0x5433;
    pub const CSETXF = 0x5434;
    pub const CSETXW = 0x5435;
    pub const IOCSIG = IOCTL.IOW('T', 0x36, c_int);
    pub const IOCVHANGUP = 0x5437;
    pub const IOCGPKT = IOCTL.IOR('T', 0x38, c_int);
    pub const IOCGPTLCK = IOCTL.IOR('T', 0x39, c_int);
    pub const IOCGEXCL = IOCTL.IOR('T', 0x40, c_int);
};

pub const EPOLL = struct {
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");

    pub const CTL_ADD = 1;
    pub const CTL_DEL = 2;
    pub const CTL_MOD = 3;

    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const RDNORM = 0x040;
    pub const RDBAND = 0x080;
    pub const WRNORM = if (is_mips) 0x004 else 0x100;
    pub const WRBAND = if (is_mips) 0x100 else 0x200;
    pub const MSG = 0x400;
    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const RDHUP = 0x2000;
    pub const EXCLUSIVE = (@as(u32, 1) << 28);
    pub const WAKEUP = (@as(u32, 1) << 29);
    pub const ONESHOT = (@as(u32, 1) << 30);
    pub const ET = (@as(u32, 1) << 31);
};

pub const CLOCK = struct {
    pub const REALTIME = 0;
    pub const MONOTONIC = 1;
    pub const PROCESS_CPUTIME_ID = 2;
    pub const THREAD_CPUTIME_ID = 3;
    pub const MONOTONIC_RAW = 4;
    pub const REALTIME_COARSE = 5;
    pub const MONOTONIC_COARSE = 6;
    pub const BOOTTIME = 7;
    pub const REALTIME_ALARM = 8;
    pub const BOOTTIME_ALARM = 9;
    pub const SGI_CYCLE = 10;
    pub const TAI = 11;
};

pub const CSIGNAL = 0x000000ff;

pub const CLONE = struct {
    pub const VM = 0x00000100;
    pub const FS = 0x00000200;
    pub const FILES = 0x00000400;
    pub const SIGHAND = 0x00000800;
    pub const PIDFD = 0x00001000;
    pub const PTRACE = 0x00002000;
    pub const VFORK = 0x00004000;
    pub const PARENT = 0x00008000;
    pub const THREAD = 0x00010000;
    pub const NEWNS = 0x00020000;
    pub const SYSVSEM = 0x00040000;
    pub const SETTLS = 0x00080000;
    pub const PARENT_SETTID = 0x00100000;
    pub const CHILD_CLEARTID = 0x00200000;
    pub const DETACHED = 0x00400000;
    pub const UNTRACED = 0x00800000;
    pub const CHILD_SETTID = 0x01000000;
    pub const NEWCGROUP = 0x02000000;
    pub const NEWUTS = 0x04000000;
    pub const NEWIPC = 0x08000000;
    pub const NEWUSER = 0x10000000;
    pub const NEWPID = 0x20000000;
    pub const NEWNET = 0x40000000;
    pub const IO = 0x80000000;

    // Flags for the clone3() syscall.

    /// Clear any signal handler and reset to SIG_DFL.
    pub const CLEAR_SIGHAND = 0x100000000;
    /// Clone into a specific cgroup given the right permissions.
    pub const INTO_CGROUP = 0x200000000;

    // cloning flags intersect with CSIGNAL so can be used with unshare and clone3 syscalls only.

    /// New time namespace
    pub const NEWTIME = 0x00000080;
};

pub const EFD = struct {
    pub const SEMAPHORE = 1;
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");
    pub const NONBLOCK = 1 << @bitOffsetOf(O, "NONBLOCK");
};

pub const MS = struct {
    pub const RDONLY = 1;
    pub const NOSUID = 2;
    pub const NODEV = 4;
    pub const NOEXEC = 8;
    pub const SYNCHRONOUS = 16;
    pub const REMOUNT = 32;
    pub const MANDLOCK = 64;
    pub const DIRSYNC = 128;
    pub const NOATIME = 1024;
    pub const NODIRATIME = 2048;
    pub const BIND = 4096;
    pub const MOVE = 8192;
    pub const REC = 16384;
    pub const SILENT = 32768;
    pub const POSIXACL = (1 << 16);
    pub const UNBINDABLE = (1 << 17);
    pub const PRIVATE = (1 << 18);
    pub const SLAVE = (1 << 19);
    pub const SHARED = (1 << 20);
    pub const RELATIME = (1 << 21);
    pub const KERNMOUNT = (1 << 22);
    pub const I_VERSION = (1 << 23);
    pub const STRICTATIME = (1 << 24);
    pub const LAZYTIME = (1 << 25);
    pub const NOREMOTELOCK = (1 << 27);
    pub const NOSEC = (1 << 28);
    pub const BORN = (1 << 29);
    pub const ACTIVE = (1 << 30);
    pub const NOUSER = (1 << 31);

    pub const RMT_MASK = (RDONLY | SYNCHRONOUS | MANDLOCK | I_VERSION | LAZYTIME);

    pub const MGC_VAL = 0xc0ed0000;
    pub const MGC_MSK = 0xffff0000;
};

pub const MNT = struct {
    pub const FORCE = 1;
    pub const DETACH = 2;
    pub const EXPIRE = 4;
};

pub const UMOUNT_NOFOLLOW = 8;

pub const IN = struct {
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");
    pub const NONBLOCK = 1 << @bitOffsetOf(O, "NONBLOCK");

    pub const ACCESS = 0x00000001;
    pub const MODIFY = 0x00000002;
    pub const ATTRIB = 0x00000004;
    pub const CLOSE_WRITE = 0x00000008;
    pub const CLOSE_NOWRITE = 0x00000010;
    pub const CLOSE = CLOSE_WRITE | CLOSE_NOWRITE;
    pub const OPEN = 0x00000020;
    pub const MOVED_FROM = 0x00000040;
    pub const MOVED_TO = 0x00000080;
    pub const MOVE = MOVED_FROM | MOVED_TO;
    pub const CREATE = 0x00000100;
    pub const DELETE = 0x00000200;
    pub const DELETE_SELF = 0x00000400;
    pub const MOVE_SELF = 0x00000800;
    pub const ALL_EVENTS = 0x00000fff;

    pub const UNMOUNT = 0x00002000;
    pub const Q_OVERFLOW = 0x00004000;
    pub const IGNORED = 0x00008000;

    pub const ONLYDIR = 0x01000000;
    pub const DONT_FOLLOW = 0x02000000;
    pub const EXCL_UNLINK = 0x04000000;
    pub const MASK_CREATE = 0x10000000;
    pub const MASK_ADD = 0x20000000;

    pub const ISDIR = 0x40000000;
    pub const ONESHOT = 0x80000000;
};

pub const FAN = struct {
    pub const ACCESS = 0x00000001;
    pub const MODIFY = 0x00000002;
    pub const CLOSE_WRITE = 0x00000008;
    pub const CLOSE_NOWRITE = 0x00000010;
    pub const OPEN = 0x00000020;
    pub const Q_OVERFLOW = 0x00004000;
    pub const OPEN_PERM = 0x00010000;
    pub const ACCESS_PERM = 0x00020000;
    pub const ONDIR = 0x40000000;
    pub const EVENT_ON_CHILD = 0x08000000;
    pub const CLOSE = CLOSE_WRITE | CLOSE_NOWRITE;
    pub const CLOEXEC = 0x00000001;
    pub const NONBLOCK = 0x00000002;
    pub const CLASS_NOTIF = 0x00000000;
    pub const CLASS_CONTENT = 0x00000004;
    pub const CLASS_PRE_CONTENT = 0x00000008;
    pub const ALL_CLASS_BITS = CLASS_NOTIF | CLASS_CONTENT | CLASS_PRE_CONTENT;
    pub const UNLIMITED_QUEUE = 0x00000010;
    pub const UNLIMITED_MARKS = 0x00000020;
    pub const ALL_INIT_FLAGS = CLOEXEC | NONBLOCK | ALL_CLASS_BITS | UNLIMITED_QUEUE | UNLIMITED_MARKS;
    pub const MARK_ADD = 0x00000001;
    pub const MARK_REMOVE = 0x00000002;
    pub const MARK_DONT_FOLLOW = 0x00000004;
    pub const MARK_ONLYDIR = 0x00000008;
    pub const MARK_MOUNT = 0x00000010;
    pub const MARK_IGNORED_MASK = 0x00000020;
    pub const MARK_IGNORED_SURV_MODIFY = 0x00000040;
    pub const MARK_FLUSH = 0x00000080;
    pub const ALL_MARK_FLAGS = MARK_ADD | MARK_REMOVE | MARK_DONT_FOLLOW | MARK_ONLYDIR | MARK_MOUNT | MARK_IGNORED_MASK | MARK_IGNORED_SURV_MODIFY | MARK_FLUSH;
    pub const ALL_EVENTS = ACCESS | MODIFY | CLOSE | OPEN;
    pub const ALL_PERM_EVENTS = OPEN_PERM | ACCESS_PERM;
    pub const ALL_OUTGOING_EVENTS = ALL_EVENTS | ALL_PERM_EVENTS | Q_OVERFLOW;
    pub const ALLOW = 0x01;
    pub const DENY = 0x02;
};

pub const fanotify_event_metadata = extern struct {
    event_len: u32,
    vers: u8,
    reserved: u8,
    metadata_len: u16,
    mask: u64 align(8),
    fd: i32,
    pid: i32,
};

pub const fanotify_response = extern struct {
    fd: i32,
    response: u32,
};

pub const S = struct {
    pub const IFMT = 0o170000;

    pub const IFDIR = 0o040000;
    pub const IFCHR = 0o020000;
    pub const IFBLK = 0o060000;
    pub const IFREG = 0o100000;
    pub const IFIFO = 0o010000;
    pub const IFLNK = 0o120000;
    pub const IFSOCK = 0o140000;

    pub const ISUID = 0o4000;
    pub const ISGID = 0o2000;
    pub const ISVTX = 0o1000;
    pub const IRUSR = 0o400;
    pub const IWUSR = 0o200;
    pub const IXUSR = 0o100;
    pub const IRWXU = 0o700;
    pub const IRGRP = 0o040;
    pub const IWGRP = 0o020;
    pub const IXGRP = 0o010;
    pub const IRWXG = 0o070;
    pub const IROTH = 0o004;
    pub const IWOTH = 0o002;
    pub const IXOTH = 0o001;
    pub const IRWXO = 0o007;

    pub fn ISREG(m: mode_t) bool {
        return m & IFMT == IFREG;
    }

    pub fn ISDIR(m: mode_t) bool {
        return m & IFMT == IFDIR;
    }

    pub fn ISCHR(m: mode_t) bool {
        return m & IFMT == IFCHR;
    }

    pub fn ISBLK(m: mode_t) bool {
        return m & IFMT == IFBLK;
    }

    pub fn ISFIFO(m: mode_t) bool {
        return m & IFMT == IFIFO;
    }

    pub fn ISLNK(m: mode_t) bool {
        return m & IFMT == IFLNK;
    }

    pub fn ISSOCK(m: mode_t) bool {
        return m & IFMT == IFSOCK;
    }
};

pub const UTIME = struct {
    pub const NOW = 0x3fffffff;
    pub const OMIT = 0x3ffffffe;
};

const TFD_TIMER = packed struct(u32) {
    ABSTIME: bool = false,
    CANCEL_ON_SET: bool = false,
    _: u30 = 0,
};

pub const TFD = switch (native_arch) {
    .sparc64 => packed struct(u32) {
        _0: u14 = 0,
        NONBLOCK: bool = false,
        _15: u7 = 0,
        CLOEXEC: bool = false,
        _: u9 = 0,

        pub const TIMER = TFD_TIMER;
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        _0: u7 = 0,
        NONBLOCK: bool = false,
        _8: u11 = 0,
        CLOEXEC: bool = false,
        _: u12 = 0,

        pub const TIMER = TFD_TIMER;
    },
    else => packed struct(u32) {
        _0: u11 = 0,
        NONBLOCK: bool = false,
        _12: u7 = 0,
        CLOEXEC: bool = false,
        _: u12 = 0,

        pub const TIMER = TFD_TIMER;
    },
};

pub const winsize = extern struct {
    ws_row: u16,
    ws_col: u16,
    ws_xpixel: u16,
    ws_ypixel: u16,
};

/// NSIG is the total number of signals defined.
/// As signal numbers are sequential, NSIG is one greater than the largest defined signal number.
pub const NSIG = if (is_mips) 128 else 65;

pub const sigset_t = [1024 / 32]u32;

pub const all_mask: sigset_t = [_]u32{0xffffffff} ** @typeInfo(sigset_t).Array.len;
pub const app_mask: sigset_t = [2]u32{ 0xfffffffc, 0x7fffffff } ++ [_]u32{0xffffffff} ** 30;

const k_sigaction_funcs = struct {
    const handler = ?*align(1) const fn (i32) callconv(.C) void;
    const restorer = *const fn () callconv(.C) void;
};

pub const k_sigaction = switch (native_arch) {
    .mips, .mipsel => extern struct {
        flags: c_uint,
        handler: k_sigaction_funcs.handler,
        mask: [4]c_ulong,
        restorer: k_sigaction_funcs.restorer,
    },
    .mips64, .mips64el => extern struct {
        flags: c_uint,
        handler: k_sigaction_funcs.handler,
        mask: [2]c_ulong,
        restorer: k_sigaction_funcs.restorer,
    },
    else => extern struct {
        handler: k_sigaction_funcs.handler,
        flags: c_ulong,
        restorer: k_sigaction_funcs.restorer,
        mask: [2]c_uint,
    },
};

/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = extern struct {
    pub const handler_fn = *align(1) const fn (i32) callconv(.C) void;
    pub const sigaction_fn = *const fn (i32, *const siginfo_t, ?*anyopaque) callconv(.C) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: c_uint,
    restorer: ?*const fn () callconv(.C) void = null,
};

const sigset_len = @typeInfo(sigset_t).Array.len;
pub const empty_sigset = [_]u32{0} ** sigset_len;
pub const filled_sigset = [_]u32{(1 << (31 & (usize_bits - 1))) - 1} ++ [_]u32{0} ** (sigset_len - 1);

pub const SFD = struct {
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");
    pub const NONBLOCK = 1 << @bitOffsetOf(O, "NONBLOCK");
};

pub const signalfd_siginfo = extern struct {
    signo: u32,
    errno: i32,
    code: i32,
    pid: u32,
    uid: uid_t,
    fd: i32,
    tid: u32,
    band: u32,
    overrun: u32,
    trapno: u32,
    status: i32,
    int: i32,
    ptr: u64,
    utime: u64,
    stime: u64,
    addr: u64,
    addr_lsb: u16,
    __pad2: u16,
    syscall: i32,
    call_addr: u64,
    native_arch: u32,
    __pad: [28]u8,
};

pub const in_port_t = u16;
pub const sa_family_t = u16;
pub const socklen_t = u32;

pub const sockaddr = extern struct {
    family: sa_family_t,
    data: [14]u8,

    pub const SS_MAXSIZE = 128;
    pub const storage = extern struct {
        family: sa_family_t align(8),
        padding: [SS_MAXSIZE - @sizeOf(sa_family_t)]u8 = undefined,

        comptime {
            assert(@sizeOf(storage) == SS_MAXSIZE);
            assert(@alignOf(storage) == 8);
        }
    };

    /// IPv4 socket address
    pub const in = extern struct {
        family: sa_family_t = AF.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    /// IPv6 socket address
    pub const in6 = extern struct {
        family: sa_family_t = AF.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// UNIX domain socket address
    pub const un = extern struct {
        family: sa_family_t = AF.UNIX,
        path: [108]u8,
    };

    /// Packet socket address
    pub const ll = extern struct {
        family: sa_family_t = AF.PACKET,
        protocol: u16,
        ifindex: i32,
        hatype: u16,
        pkttype: u8,
        halen: u8,
        addr: [8]u8,
    };

    /// Netlink socket address
    pub const nl = extern struct {
        family: sa_family_t = AF.NETLINK,
        __pad1: c_ushort = 0,

        /// port ID
        pid: u32,

        /// multicast groups mask
        groups: u32,
    };

    pub const xdp = extern struct {
        family: u16 = AF.XDP,
        flags: u16,
        ifindex: u32,
        queue_id: u32,
        shared_umem_fd: u32,
    };

    /// Address structure for vSockets
    pub const vm = extern struct {
        family: sa_family_t = AF.VSOCK,
        reserved1: u16 = 0,
        port: u32,
        cid: u32,
        flags: u8,

        /// The total size of this structure should be exactly the same as that of struct sockaddr.
        zero: [3]u8 = [_]u8{0} ** 3,
        comptime {
            std.debug.assert(@sizeOf(vm) == @sizeOf(sockaddr));
        }
    };
};

pub const mmsghdr = extern struct {
    msg_hdr: msghdr,
    msg_len: u32,
};

pub const mmsghdr_const = extern struct {
    msg_hdr: msghdr_const,
    msg_len: u32,
};

pub const epoll_data = extern union {
    ptr: usize,
    fd: i32,
    u32: u32,
    u64: u64,
};

pub const epoll_event = extern struct {
    events: u32,
    data: epoll_data align(switch (native_arch) {
        .x86_64 => 4,
        else => @alignOf(epoll_data),
    }),
};

pub const VFS_CAP_REVISION_MASK = 0xFF000000;
pub const VFS_CAP_REVISION_SHIFT = 24;
pub const VFS_CAP_FLAGS_MASK = ~VFS_CAP_REVISION_MASK;
pub const VFS_CAP_FLAGS_EFFECTIVE = 0x000001;

pub const VFS_CAP_REVISION_1 = 0x01000000;
pub const VFS_CAP_U32_1 = 1;
pub const XATTR_CAPS_SZ_1 = @sizeOf(u32) * (1 + 2 * VFS_CAP_U32_1);

pub const VFS_CAP_REVISION_2 = 0x02000000;
pub const VFS_CAP_U32_2 = 2;
pub const XATTR_CAPS_SZ_2 = @sizeOf(u32) * (1 + 2 * VFS_CAP_U32_2);

pub const XATTR_CAPS_SZ = XATTR_CAPS_SZ_2;
pub const VFS_CAP_U32 = VFS_CAP_U32_2;
pub const VFS_CAP_REVISION = VFS_CAP_REVISION_2;

pub const vfs_cap_data = extern struct {
    //all of these are mandated as little endian
    //when on disk.
    const Data = struct {
        permitted: u32,
        inheritable: u32,
    };

    magic_etc: u32,
    data: [VFS_CAP_U32]Data,
};

pub const CAP = struct {
    pub const CHOWN = 0;
    pub const DAC_OVERRIDE = 1;
    pub const DAC_READ_SEARCH = 2;
    pub const FOWNER = 3;
    pub const FSETID = 4;
    pub const KILL = 5;
    pub const SETGID = 6;
    pub const SETUID = 7;
    pub const SETPCAP = 8;
    pub const LINUX_IMMUTABLE = 9;
    pub const NET_BIND_SERVICE = 10;
    pub const NET_BROADCAST = 11;
    pub const NET_ADMIN = 12;
    pub const NET_RAW = 13;
    pub const IPC_LOCK = 14;
    pub const IPC_OWNER = 15;
    pub const SYS_MODULE = 16;
    pub const SYS_RAWIO = 17;
    pub const SYS_CHROOT = 18;
    pub const SYS_PTRACE = 19;
    pub const SYS_PACCT = 20;
    pub const SYS_ADMIN = 21;
    pub const SYS_BOOT = 22;
    pub const SYS_NICE = 23;
    pub const SYS_RESOURCE = 24;
    pub const SYS_TIME = 25;
    pub const SYS_TTY_CONFIG = 26;
    pub const MKNOD = 27;
    pub const LEASE = 28;
    pub const AUDIT_WRITE = 29;
    pub const AUDIT_CONTROL = 30;
    pub const SETFCAP = 31;
    pub const MAC_OVERRIDE = 32;
    pub const MAC_ADMIN = 33;
    pub const SYSLOG = 34;
    pub const WAKE_ALARM = 35;
    pub const BLOCK_SUSPEND = 36;
    pub const AUDIT_READ = 37;
    pub const PERFMON = 38;
    pub const BPF = 39;
    pub const CHECKPOINT_RESTORE = 40;
    pub const LAST_CAP = CHECKPOINT_RESTORE;

    pub fn valid(x: u8) bool {
        return x >= 0 and x <= LAST_CAP;
    }

    pub fn TO_MASK(cap: u8) u32 {
        return @as(u32, 1) << @as(u5, @intCast(cap & 31));
    }

    pub fn TO_INDEX(cap: u8) u8 {
        return cap >> 5;
    }
};

pub const cap_t = extern struct {
    hdrp: *cap_user_header_t,
    datap: *cap_user_data_t,
};

pub const cap_user_header_t = extern struct {
    version: u32,
    pid: usize,
};

pub const cap_user_data_t = extern struct {
    effective: u32,
    permitted: u32,
    inheritable: u32,
};

pub const inotify_event = extern struct {
    wd: i32,
    mask: u32,
    cookie: u32,
    len: u32,
    //name: [?]u8,

    // if an event is returned for a directory or file inside the directory being watched
    // returns the name of said directory/file
    // returns `null` if the directory/file is the one being watched
    pub fn getName(self: *const inotify_event) ?[:0]const u8 {
        if (self.len == 0) return null;
        return std.mem.span(@as([*:0]const u8, @ptrCast(self)) + @sizeOf(inotify_event));
    }
};

pub const dirent64 = extern struct {
    ino: u64,
    off: u64,
    reclen: u16,
    type: u8,
    name: u8, // field address is the address of first byte of name https://github.com/ziglang/zig/issues/173
};

pub const dl_phdr_info = extern struct {
    dlpi_addr: usize,
    dlpi_name: ?[*:0]const u8,
    dlpi_phdr: [*]std.elf.Phdr,
    dlpi_phnum: u16,
};

pub const CPU_SETSIZE = 128;
pub const cpu_set_t = [CPU_SETSIZE / @sizeOf(usize)]usize;
pub const cpu_count_t = std.meta.Int(.unsigned, std.math.log2(CPU_SETSIZE * 8));

pub fn CPU_COUNT(set: cpu_set_t) cpu_count_t {
    var sum: cpu_count_t = 0;
    for (set) |x| {
        sum += @popCount(x);
    }
    return sum;
}

pub const MINSIGSTKSZ = switch (native_arch) {
    .x86, .x86_64, .arm, .mipsel => 2048,
    .aarch64 => 5120,
    else => @compileError("MINSIGSTKSZ not defined for this architecture"),
};
pub const SIGSTKSZ = switch (native_arch) {
    .x86, .x86_64, .arm, .mipsel => 8192,
    .aarch64 => 16384,
    else => @compileError("SIGSTKSZ not defined for this architecture"),
};

pub const SS_ONSTACK = 1;
pub const SS_DISABLE = 2;
pub const SS_AUTODISARM = 1 << 31;

pub const stack_t = if (is_mips)
    // IRIX compatible stack_t
    extern struct {
        sp: [*]u8,
        size: usize,
        flags: i32,
    }
else
    extern struct {
        sp: [*]u8,
        flags: i32,
        size: usize,
    };

pub const sigval = extern union {
    int: i32,
    ptr: *anyopaque,
};

const siginfo_fields_union = extern union {
    pad: [128 - 2 * @sizeOf(c_int) - @sizeOf(c_long)]u8,
    common: extern struct {
        first: extern union {
            piduid: extern struct {
                pid: pid_t,
                uid: uid_t,
            },
            timer: extern struct {
                timerid: i32,
                overrun: i32,
            },
        },
        second: extern union {
            value: sigval,
            sigchld: extern struct {
                status: i32,
                utime: clock_t,
                stime: clock_t,
            },
        },
    },
    sigfault: extern struct {
        addr: *allowzero anyopaque,
        addr_lsb: i16,
        first: extern union {
            addr_bnd: extern struct {
                lower: *anyopaque,
                upper: *anyopaque,
            },
            pkey: u32,
        },
    },
    sigpoll: extern struct {
        band: isize,
        fd: i32,
    },
    sigsys: extern struct {
        call_addr: *anyopaque,
        syscall: i32,
        native_arch: u32,
    },
};

pub const siginfo_t = if (is_mips)
    extern struct {
        signo: i32,
        code: i32,
        errno: i32,
        fields: siginfo_fields_union,
    }
else
    extern struct {
        signo: i32,
        errno: i32,
        code: i32,
        fields: siginfo_fields_union,
    };

// io_uring_params.flags

/// io_context is polled
pub const IORING_SETUP_IOPOLL = 1 << 0;

/// SQ poll thread
pub const IORING_SETUP_SQPOLL = 1 << 1;

/// sq_thread_cpu is valid
pub const IORING_SETUP_SQ_AFF = 1 << 2;

/// app defines CQ size
pub const IORING_SETUP_CQSIZE = 1 << 3;

/// clamp SQ/CQ ring sizes
pub const IORING_SETUP_CLAMP = 1 << 4;

/// attach to existing wq
pub const IORING_SETUP_ATTACH_WQ = 1 << 5;

/// start with ring disabled
pub const IORING_SETUP_R_DISABLED = 1 << 6;

/// continue submit on error
pub const IORING_SETUP_SUBMIT_ALL = 1 << 7;

/// Cooperative task running. When requests complete, they often require
/// forcing the submitter to transition to the kernel to complete. If this
/// flag is set, work will be done when the task transitions anyway, rather
/// than force an inter-processor interrupt reschedule. This avoids interrupting
/// a task running in userspace, and saves an IPI.
pub const IORING_SETUP_COOP_TASKRUN = 1 << 8;

/// If COOP_TASKRUN is set, get notified if task work is available for
/// running and a kernel transition would be needed to run it. This sets
/// IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
pub const IORING_SETUP_TASKRUN_FLAG = 1 << 9;

/// SQEs are 128 byte
pub const IORING_SETUP_SQE128 = 1 << 10;
/// CQEs are 32 byte
pub const IORING_SETUP_CQE32 = 1 << 11;

/// Only one task is allowed to submit requests
pub const IORING_SETUP_SINGLE_ISSUER = 1 << 12;

/// Defer running task work to get events.
/// Rather than running bits of task work whenever the task transitions
/// try to do it just before it is needed.
pub const IORING_SETUP_DEFER_TASKRUN = 1 << 13;

/// IO submission data structure (Submission Queue Entry)
pub const io_uring_sqe = @import("linux/io_uring_sqe.zig").io_uring_sqe;

pub const IoUring = @import("linux/IoUring.zig");

/// If sqe->file_index is set to this for opcodes that instantiate a new
/// direct descriptor (like openat/openat2/accept), then io_uring will allocate
/// an available direct descriptor instead of having the application pass one
/// in. The picked direct descriptor will be returned in cqe->res, or -ENFILE
/// if the space is full.
/// Available since Linux 5.19
pub const IORING_FILE_INDEX_ALLOC = maxInt(u32);

pub const IOSQE_BIT = enum(u8) {
    FIXED_FILE,
    IO_DRAIN,
    IO_LINK,
    IO_HARDLINK,
    ASYNC,
    BUFFER_SELECT,
    CQE_SKIP_SUCCESS,

    _,
};

// io_uring_sqe.flags

/// use fixed fileset
pub const IOSQE_FIXED_FILE = 1 << @intFromEnum(IOSQE_BIT.FIXED_FILE);

/// issue after inflight IO
pub const IOSQE_IO_DRAIN = 1 << @intFromEnum(IOSQE_BIT.IO_DRAIN);

/// links next sqe
pub const IOSQE_IO_LINK = 1 << @intFromEnum(IOSQE_BIT.IO_LINK);

/// like LINK, but stronger
pub const IOSQE_IO_HARDLINK = 1 << @intFromEnum(IOSQE_BIT.IO_HARDLINK);

/// always go async
pub const IOSQE_ASYNC = 1 << @intFromEnum(IOSQE_BIT.ASYNC);

/// select buffer from buf_group
pub const IOSQE_BUFFER_SELECT = 1 << @intFromEnum(IOSQE_BIT.BUFFER_SELECT);

/// don't post CQE if request succeeded
/// Available since Linux 5.17
pub const IOSQE_CQE_SKIP_SUCCESS = 1 << @intFromEnum(IOSQE_BIT.CQE_SKIP_SUCCESS);

pub const IORING_OP = enum(u8) {
    NOP,
    READV,
    WRITEV,
    FSYNC,
    READ_FIXED,
    WRITE_FIXED,
    POLL_ADD,
    POLL_REMOVE,
    SYNC_FILE_RANGE,
    SENDMSG,
    RECVMSG,
    TIMEOUT,
    TIMEOUT_REMOVE,
    ACCEPT,
    ASYNC_CANCEL,
    LINK_TIMEOUT,
    CONNECT,
    FALLOCATE,
    OPENAT,
    CLOSE,
    FILES_UPDATE,
    STATX,
    READ,
    WRITE,
    FADVISE,
    MADVISE,
    SEND,
    RECV,
    OPENAT2,
    EPOLL_CTL,
    SPLICE,
    PROVIDE_BUFFERS,
    REMOVE_BUFFERS,
    TEE,
    SHUTDOWN,
    RENAMEAT,
    UNLINKAT,
    MKDIRAT,
    SYMLINKAT,
    LINKAT,
    MSG_RING,
    FSETXATTR,
    SETXATTR,
    FGETXATTR,
    GETXATTR,
    SOCKET,
    URING_CMD,
    SEND_ZC,
    SENDMSG_ZC,
    READ_MULTISHOT,
    WAITID,
    FUTEX_WAIT,
    FUTEX_WAKE,
    FUTEX_WAITV,
    FIXED_FD_INSTALL,
    FTRUNCATE,

    _,
};
// io_uring_sqe.uring_cmd_flags (rw_flags in the Zig struct)

/// use registered buffer; pass thig flag along with setting sqe->buf_index.
pub const IORING_URING_CMD_FIXED = 1 << 0;

// io_uring_sqe.fsync_flags (rw_flags in the Zig struct)
pub const IORING_FSYNC_DATASYNC = 1 << 0;

// io_uring_sqe.timeout_flags (rw_flags in the Zig struct)
pub const IORING_TIMEOUT_ABS = 1 << 0;
pub const IORING_TIMEOUT_UPDATE = 1 << 1; // Available since Linux 5.11
pub const IORING_TIMEOUT_BOOTTIME = 1 << 2; // Available since Linux 5.15
pub const IORING_TIMEOUT_REALTIME = 1 << 3; // Available since Linux 5.15
pub const IORING_LINK_TIMEOUT_UPDATE = 1 << 4; // Available since Linux 5.15
pub const IORING_TIMEOUT_ETIME_SUCCESS = 1 << 5; // Available since Linux 5.16
pub const IORING_TIMEOUT_CLOCK_MASK = IORING_TIMEOUT_BOOTTIME | IORING_TIMEOUT_REALTIME;
pub const IORING_TIMEOUT_UPDATE_MASK = IORING_TIMEOUT_UPDATE | IORING_LINK_TIMEOUT_UPDATE;

// io_uring_sqe.splice_flags (rw_flags in the Zig struct)
// extends splice(2) flags
pub const IORING_SPLICE_F_FD_IN_FIXED = 1 << 31;

// POLL_ADD flags.
// Note that since sqe->poll_events (rw_flags in the Zig struct) is the flag space, the command flags for POLL_ADD are stored in sqe->len.

/// Multishot poll. Sets IORING_CQE_F_MORE if the poll handler will continue to report CQEs on behalf of the same SQE.
pub const IORING_POLL_ADD_MULTI = 1 << 0;
/// Update existing poll request, matching sqe->addr as the old user_data field.
pub const IORING_POLL_UPDATE_EVENTS = 1 << 1;
pub const IORING_POLL_UPDATE_USER_DATA = 1 << 2;
pub const IORING_POLL_ADD_LEVEL = 1 << 3;

// ASYNC_CANCEL flags.

/// Cancel all requests that match the given key
pub const IORING_ASYNC_CANCEL_ALL = 1 << 0;
/// Key off 'fd' for cancelation rather than the request 'user_data'.
pub const IORING_ASYNC_CANCEL_FD = 1 << 1;
/// Match any request
pub const IORING_ASYNC_CANCEL_ANY = 1 << 2;
/// 'fd' passed in is a fixed descriptor. Available since Linux 6.0
pub const IORING_ASYNC_CANCEL_FD_FIXED = 1 << 3;

// send/sendmsg and recv/recvmsg flags (sqe->ioprio)

/// If set, instead of first attempting to send or receive and arm poll if that yields an -EAGAIN result,
/// arm poll upfront and skip the initial transfer attempt.
pub const IORING_RECVSEND_POLL_FIRST = 1 << 0;
/// Multishot recv. Sets IORING_CQE_F_MORE if the handler will continue to report CQEs on behalf of the same SQE.
pub const IORING_RECV_MULTISHOT = 1 << 1;
/// Use registered buffers, the index is stored in the buf_index field.
pub const IORING_RECVSEND_FIXED_BUF = 1 << 2;
/// If set, SEND[MSG]_ZC should report the zerocopy usage in cqe.res for the IORING_CQE_F_NOTIF cqe.
pub const IORING_SEND_ZC_REPORT_USAGE = 1 << 3;
/// CQE.RES FOR IORING_CQE_F_NOTIF if IORING_SEND_ZC_REPORT_USAGE was requested
pub const IORING_NOTIF_USAGE_ZC_COPIED = 1 << 31;

/// accept flags stored in sqe->iopri
pub const IORING_ACCEPT_MULTISHOT = 1 << 0;

/// IORING_OP_MSG_RING command types, stored in sqe->addr
pub const IORING_MSG_RING_COMMAND = enum(u8) {
    /// pass sqe->len as 'res' and off as user_data
    DATA,
    /// send a registered fd to another ring
    SEND_FD,
};

// io_uring_sqe.msg_ring_flags (rw_flags in the Zig struct)

/// Don't post a CQE to the target ring. Not applicable for IORING_MSG_DATA, obviously.
pub const IORING_MSG_RING_CQE_SKIP = 1 << 0;

/// Pass through the flags from sqe->file_index (splice_fd_in in the zig struct) to cqe->flags */
pub const IORING_MSG_RING_FLAGS_PASS = 1 << 1;

// IO completion data structure (Completion Queue Entry)
pub const io_uring_cqe = extern struct {
    /// io_uring_sqe.data submission passed back
    user_data: u64,

    /// result code for this event
    res: i32,
    flags: u32,

    // Followed by 16 bytes of padding if initialized with IORING_SETUP_CQE32, doubling cqe size

    pub fn err(self: io_uring_cqe) E {
        if (self.res > -4096 and self.res < 0) {
            return @as(E, @enumFromInt(-self.res));
        }
        return .SUCCESS;
    }

    // On successful completion of the provided buffers IO request, the CQE flags field
    // will have IORING_CQE_F_BUFFER set and the selected buffer ID will be indicated by
    // the upper 16-bits of the flags field.
    pub fn buffer_id(self: io_uring_cqe) !u16 {
        if (self.flags & IORING_CQE_F_BUFFER != IORING_CQE_F_BUFFER) {
            return error.NoBufferSelected;
        }
        return @as(u16, @intCast(self.flags >> IORING_CQE_BUFFER_SHIFT));
    }
};

// io_uring_cqe.flags

/// If set, the upper 16 bits are the buffer ID
pub const IORING_CQE_F_BUFFER = 1 << 0;
/// If set, parent SQE will generate more CQE entries.
/// Available since Linux 5.13.
pub const IORING_CQE_F_MORE = 1 << 1;
/// If set, more data to read after socket recv
pub const IORING_CQE_F_SOCK_NONEMPTY = 1 << 2;
/// Set for notification CQEs. Can be used to distinct them from sends.
pub const IORING_CQE_F_NOTIF = 1 << 3;

pub const IORING_CQE_BUFFER_SHIFT = 16;

/// Magic offsets for the application to mmap the data it needs
pub const IORING_OFF_SQ_RING = 0;
pub const IORING_OFF_CQ_RING = 0x8000000;
pub const IORING_OFF_SQES = 0x10000000;

/// Filled with the offset for mmap(2)
pub const io_sqring_offsets = extern struct {
    /// offset of ring head
    head: u32,

    /// offset of ring tail
    tail: u32,

    /// ring mask value
    ring_mask: u32,

    /// entries in ring
    ring_entries: u32,

    /// ring flags
    flags: u32,

    /// number of sqes not submitted
    dropped: u32,

    /// sqe index array
    array: u32,

    resv1: u32,
    user_addr: u64,
};

// io_sqring_offsets.flags

/// needs io_uring_enter wakeup
pub const IORING_SQ_NEED_WAKEUP = 1 << 0;
/// kernel has cqes waiting beyond the cq ring
pub const IORING_SQ_CQ_OVERFLOW = 1 << 1;
/// task should enter the kernel
pub const IORING_SQ_TASKRUN = 1 << 2;

pub const io_cqring_offsets = extern struct {
    head: u32,
    tail: u32,
    ring_mask: u32,
    ring_entries: u32,
    overflow: u32,
    cqes: u32,
    flags: u32,
    resv: u32,
    user_addr: u64,
};

// io_cqring_offsets.flags

/// disable eventfd notifications
pub const IORING_CQ_EVENTFD_DISABLED = 1 << 0;

// io_uring_enter flags
pub const IORING_ENTER_GETEVENTS = 1 << 0;
pub const IORING_ENTER_SQ_WAKEUP = 1 << 1;
pub const IORING_ENTER_SQ_WAIT = 1 << 2;
pub const IORING_ENTER_EXT_ARG = 1 << 3;
pub const IORING_ENTER_REGISTERED_RING = 1 << 4;

pub const io_uring_params = extern struct {
    sq_entries: u32,
    cq_entries: u32,
    flags: u32,
    sq_thread_cpu: u32,
    sq_thread_idle: u32,
    features: u32,
    wq_fd: u32,
    resv: [3]u32,
    sq_off: io_sqring_offsets,
    cq_off: io_cqring_offsets,
};

// io_uring_params.features flags

pub const IORING_FEAT_SINGLE_MMAP = 1 << 0;
pub const IORING_FEAT_NODROP = 1 << 1;
pub const IORING_FEAT_SUBMIT_STABLE = 1 << 2;
pub const IORING_FEAT_RW_CUR_POS = 1 << 3;
pub const IORING_FEAT_CUR_PERSONALITY = 1 << 4;
pub const IORING_FEAT_FAST_POLL = 1 << 5;
pub const IORING_FEAT_POLL_32BITS = 1 << 6;
pub const IORING_FEAT_SQPOLL_NONFIXED = 1 << 7;
pub const IORING_FEAT_EXT_ARG = 1 << 8;
pub const IORING_FEAT_NATIVE_WORKERS = 1 << 9;
pub const IORING_FEAT_RSRC_TAGS = 1 << 10;
pub const IORING_FEAT_CQE_SKIP = 1 << 11;
pub const IORING_FEAT_LINKED_FILE = 1 << 12;

// io_uring_register opcodes and arguments
pub const IORING_REGISTER = enum(u32) {
    REGISTER_BUFFERS,
    UNREGISTER_BUFFERS,
    REGISTER_FILES,
    UNREGISTER_FILES,
    REGISTER_EVENTFD,
    UNREGISTER_EVENTFD,
    REGISTER_FILES_UPDATE,
    REGISTER_EVENTFD_ASYNC,
    REGISTER_PROBE,
    REGISTER_PERSONALITY,
    UNREGISTER_PERSONALITY,
    REGISTER_RESTRICTIONS,
    REGISTER_ENABLE_RINGS,

    // extended with tagging
    REGISTER_FILES2,
    REGISTER_FILES_UPDATE2,
    REGISTER_BUFFERS2,
    REGISTER_BUFFERS_UPDATE,

    // set/clear io-wq thread affinities
    REGISTER_IOWQ_AFF,
    UNREGISTER_IOWQ_AFF,

    // set/get max number of io-wq workers
    REGISTER_IOWQ_MAX_WORKERS,

    // register/unregister io_uring fd with the ring
    REGISTER_RING_FDS,
    NREGISTER_RING_FDS,

    // register ring based provide buffer group
    REGISTER_PBUF_RING,
    UNREGISTER_PBUF_RING,

    // sync cancelation API
    REGISTER_SYNC_CANCEL,

    // register a range of fixed file slots for automatic slot allocation
    REGISTER_FILE_ALLOC_RANGE,

    // flag added to the opcode to use a registered ring fd
    IORING_REGISTER_USE_REGISTERED_RING = 1 << 31,

    _,
};

/// io_uring_restriction->opcode values
pub const IOWQ_CATEGORIES = enum(u8) {
    BOUND,
    UNBOUND,
};

/// deprecated, see struct io_uring_rsrc_update
pub const io_uring_files_update = extern struct {
    offset: u32,
    resv: u32,
    fds: u64,
};

/// Register a fully sparse file space, rather than pass in an array of all -1 file descriptors.
pub const IORING_RSRC_REGISTER_SPARSE = 1 << 0;

pub const io_uring_rsrc_register = extern struct {
    nr: u32,
    flags: u32,
    resv2: u64,
    data: u64,
    tags: u64,
};

pub const io_uring_rsrc_update = extern struct {
    offset: u32,
    resv: u32,
    data: u64,
};

pub const io_uring_rsrc_update2 = extern struct {
    offset: u32,
    resv: u32,
    data: u64,
    tags: u64,
    nr: u32,
    resv2: u32,
};

pub const io_uring_notification_slot = extern struct {
    tag: u64,
    resv: [3]u64,
};

pub const io_uring_notification_register = extern struct {
    nr_slots: u32,
    resv: u32,
    resv2: u64,
    data: u64,
    resv3: u64,
};

/// Skip updating fd indexes set to this value in the fd table */
pub const IORING_REGISTER_FILES_SKIP = -2;

pub const IO_URING_OP_SUPPORTED = 1 << 0;

pub const io_uring_probe_op = extern struct {
    op: IORING_OP,

    resv: u8,

    /// IO_URING_OP_* flags
    flags: u16,

    resv2: u32,
};

pub const io_uring_probe = extern struct {
    /// last opcode supported
    last_op: IORING_OP,

    /// Number of io_uring_probe_op following
    ops_len: u8,

    resv: u16,
    resv2: [3]u32,

    // Followed by up to `ops_len` io_uring_probe_op structures
};

pub const io_uring_restriction = extern struct {
    opcode: IORING_RESTRICTION,
    arg: extern union {
        /// IORING_RESTRICTION_REGISTER_OP
        register_op: IORING_REGISTER,

        /// IORING_RESTRICTION_SQE_OP
        sqe_op: IORING_OP,

        /// IORING_RESTRICTION_SQE_FLAGS_*
        sqe_flags: u8,
    },
    resv: u8,
    resv2: [3]u32,
};

/// io_uring_restriction->opcode values
pub const IORING_RESTRICTION = enum(u16) {
    /// Allow an io_uring_register(2) opcode
    REGISTER_OP = 0,

    /// Allow an sqe opcode
    SQE_OP = 1,

    /// Allow sqe flags
    SQE_FLAGS_ALLOWED = 2,

    /// Require sqe flags (these flags must be set on each submission)
    SQE_FLAGS_REQUIRED = 3,

    _,
};

pub const io_uring_buf = extern struct {
    addr: u64,
    len: u32,
    bid: u16,
    resv: u16,
};

pub const io_uring_buf_ring = extern struct {
    resv1: u64,
    resv2: u32,
    resv3: u16,
    tail: u16,
};

/// argument for IORING_(UN)REGISTER_PBUF_RING
pub const io_uring_buf_reg = extern struct {
    ring_addr: u64,
    ring_entries: u32,
    bgid: u16,
    pad: u16,
    resv: [3]u64,
};

pub const io_uring_getevents_arg = extern struct {
    sigmask: u64,
    sigmask_sz: u32,
    pad: u32,
    ts: u64,
};

/// Argument for IORING_REGISTER_SYNC_CANCEL
pub const io_uring_sync_cancel_reg = extern struct {
    addr: u64,
    fd: i32,
    flags: u32,
    timeout: kernel_timespec,
    pad: [4]u64,
};

/// Argument for IORING_REGISTER_FILE_ALLOC_RANGE
/// The range is specified as [off, off + len)
pub const io_uring_file_index_range = extern struct {
    off: u32,
    len: u32,
    resv: u64,
};

pub const io_uring_recvmsg_out = extern struct {
    namelen: u32,
    controllen: u32,
    payloadlen: u32,
    flags: u32,
};

pub const utsname = extern struct {
    sysname: [64:0]u8,
    nodename: [64:0]u8,
    release: [64:0]u8,
    version: [64:0]u8,
    machine: [64:0]u8,
    domainname: [64:0]u8,
};
pub const HOST_NAME_MAX = 64;

pub const STATX_TYPE = 0x0001;
pub const STATX_MODE = 0x0002;
pub const STATX_NLINK = 0x0004;
pub const STATX_UID = 0x0008;
pub const STATX_GID = 0x0010;
pub const STATX_ATIME = 0x0020;
pub const STATX_MTIME = 0x0040;
pub const STATX_CTIME = 0x0080;
pub const STATX_INO = 0x0100;
pub const STATX_SIZE = 0x0200;
pub const STATX_BLOCKS = 0x0400;
pub const STATX_BASIC_STATS = 0x07ff;

pub const STATX_BTIME = 0x0800;

pub const STATX_ATTR_COMPRESSED = 0x0004;
pub const STATX_ATTR_IMMUTABLE = 0x0010;
pub const STATX_ATTR_APPEND = 0x0020;
pub const STATX_ATTR_NODUMP = 0x0040;
pub const STATX_ATTR_ENCRYPTED = 0x0800;
pub const STATX_ATTR_AUTOMOUNT = 0x1000;

pub const statx_timestamp = extern struct {
    tv_sec: i64,
    tv_nsec: u32,
    __pad1: u32,
};

/// Renamed to `Statx` to not conflict with the `statx` function.
pub const Statx = extern struct {
    /// Mask of bits indicating filled fields
    mask: u32,

    /// Block size for filesystem I/O
    blksize: u32,

    /// Extra file attribute indicators
    attributes: u64,

    /// Number of hard links
    nlink: u32,

    /// User ID of owner
    uid: uid_t,

    /// Group ID of owner
    gid: gid_t,

    /// File type and mode
    mode: u16,
    __pad1: u16,

    /// Inode number
    ino: u64,

    /// Total size in bytes
    size: u64,

    /// Number of 512B blocks allocated
    blocks: u64,

    /// Mask to show what's supported in `attributes`.
    attributes_mask: u64,

    /// Last access file timestamp
    atime: statx_timestamp,

    /// Creation file timestamp
    btime: statx_timestamp,

    /// Last status change file timestamp
    ctime: statx_timestamp,

    /// Last modification file timestamp
    mtime: statx_timestamp,

    /// Major ID, if this file represents a device.
    rdev_major: u32,

    /// Minor ID, if this file represents a device.
    rdev_minor: u32,

    /// Major ID of the device containing the filesystem where this file resides.
    dev_major: u32,

    /// Minor ID of the device containing the filesystem where this file resides.
    dev_minor: u32,

    __pad2: [14]u64,
};

pub const addrinfo = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: socklen_t,
    addr: ?*sockaddr,
    canonname: ?[*:0]u8,
    next: ?*addrinfo,
};

pub const IPPORT_RESERVED = 1024;

pub const IPPROTO = struct {
    pub const IP = 0;
    pub const HOPOPTS = 0;
    pub const ICMP = 1;
    pub const IGMP = 2;
    pub const IPIP = 4;
    pub const TCP = 6;
    pub const EGP = 8;
    pub const PUP = 12;
    pub const UDP = 17;
    pub const IDP = 22;
    pub const TP = 29;
    pub const DCCP = 33;
    pub const IPV6 = 41;
    pub const ROUTING = 43;
    pub const FRAGMENT = 44;
    pub const RSVP = 46;
    pub const GRE = 47;
    pub const ESP = 50;
    pub const AH = 51;
    pub const ICMPV6 = 58;
    pub const NONE = 59;
    pub const DSTOPTS = 60;
    pub const MTP = 92;
    pub const BEETPH = 94;
    pub const ENCAP = 98;
    pub const PIM = 103;
    pub const COMP = 108;
    pub const SCTP = 132;
    pub const MH = 135;
    pub const UDPLITE = 136;
    pub const MPLS = 137;
    pub const RAW = 255;
    pub const MAX = 256;
};

pub const RR = struct {
    pub const A = 1;
    pub const CNAME = 5;
    pub const AAAA = 28;
};

pub const tcp_repair_opt = extern struct {
    opt_code: u32,
    opt_val: u32,
};

pub const tcp_repair_window = extern struct {
    snd_wl1: u32,
    snd_wnd: u32,
    max_window: u32,
    rcv_wnd: u32,
    rcv_wup: u32,
};

pub const TcpRepairOption = enum {
    TCP_NO_QUEUE,
    TCP_RECV_QUEUE,
    TCP_SEND_QUEUE,
    TCP_QUEUES_NR,
};

/// why fastopen failed from client perspective
pub const tcp_fastopen_client_fail = enum {
    /// catch-all
    TFO_STATUS_UNSPEC,
    /// if not in TFO_CLIENT_NO_COOKIE mode
    TFO_COOKIE_UNAVAILABLE,
    /// SYN-ACK did not ack SYN data
    TFO_DATA_NOT_ACKED,
    /// SYN-ACK did not ack SYN data after timeout
    TFO_SYN_RETRANSMITTED,
};

/// for TCP_INFO socket option
pub const TCPI_OPT_TIMESTAMPS = 1;
pub const TCPI_OPT_SACK = 2;
pub const TCPI_OPT_WSCALE = 4;
/// ECN was negotiated at TCP session init
pub const TCPI_OPT_ECN = 8;
/// we received at least one packet with ECT
pub const TCPI_OPT_ECN_SEEN = 16;
/// SYN-ACK acked data in SYN sent or rcvd
pub const TCPI_OPT_SYN_DATA = 32;

pub const nfds_t = usize;
pub const pollfd = extern struct {
    fd: fd_t,
    events: i16,
    revents: i16,
};

pub const POLL = struct {
    pub const IN = 0x001;
    pub const PRI = 0x002;
    pub const OUT = 0x004;
    pub const ERR = 0x008;
    pub const HUP = 0x010;
    pub const NVAL = 0x020;
    pub const RDNORM = 0x040;
    pub const RDBAND = 0x080;
};

pub const HUGETLB_FLAG_ENCODE_SHIFT = 26;
pub const HUGETLB_FLAG_ENCODE_MASK = 0x3f;
pub const HUGETLB_FLAG_ENCODE_64KB = 16 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_512KB = 19 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_1MB = 20 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_2MB = 21 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_8MB = 23 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_16MB = 24 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_32MB = 25 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_256MB = 28 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_512MB = 29 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_1GB = 30 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_2GB = 31 << HUGETLB_FLAG_ENCODE_SHIFT;
pub const HUGETLB_FLAG_ENCODE_16GB = 34 << HUGETLB_FLAG_ENCODE_SHIFT;

pub const MFD = struct {
    pub const CLOEXEC = 0x0001;
    pub const ALLOW_SEALING = 0x0002;
    pub const HUGETLB = 0x0004;
    pub const ALL_FLAGS = CLOEXEC | ALLOW_SEALING | HUGETLB;

    pub const HUGE_SHIFT = HUGETLB_FLAG_ENCODE_SHIFT;
    pub const HUGE_MASK = HUGETLB_FLAG_ENCODE_MASK;
    pub const HUGE_64KB = HUGETLB_FLAG_ENCODE_64KB;
    pub const HUGE_512KB = HUGETLB_FLAG_ENCODE_512KB;
    pub const HUGE_1MB = HUGETLB_FLAG_ENCODE_1MB;
    pub const HUGE_2MB = HUGETLB_FLAG_ENCODE_2MB;
    pub const HUGE_8MB = HUGETLB_FLAG_ENCODE_8MB;
    pub const HUGE_16MB = HUGETLB_FLAG_ENCODE_16MB;
    pub const HUGE_32MB = HUGETLB_FLAG_ENCODE_32MB;
    pub const HUGE_256MB = HUGETLB_FLAG_ENCODE_256MB;
    pub const HUGE_512MB = HUGETLB_FLAG_ENCODE_512MB;
    pub const HUGE_1GB = HUGETLB_FLAG_ENCODE_1GB;
    pub const HUGE_2GB = HUGETLB_FLAG_ENCODE_2GB;
    pub const HUGE_16GB = HUGETLB_FLAG_ENCODE_16GB;
};

pub const rusage = extern struct {
    utime: timeval,
    stime: timeval,
    maxrss: isize,
    ixrss: isize,
    idrss: isize,
    isrss: isize,
    minflt: isize,
    majflt: isize,
    nswap: isize,
    inblock: isize,
    oublock: isize,
    msgsnd: isize,
    msgrcv: isize,
    nsignals: isize,
    nvcsw: isize,
    nivcsw: isize,
    __reserved: [16]isize = [1]isize{0} ** 16,

    pub const SELF = 0;
    pub const CHILDREN = -1;
    pub const THREAD = 1;
};

pub const NCCS = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => 19,
    else => 32,
};

pub const speed_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => enum(u32) {
        B0 = 0o0000000,
        B50 = 0o0000001,
        B75 = 0o0000002,
        B110 = 0o0000003,
        B134 = 0o0000004,
        B150 = 0o0000005,
        B200 = 0o0000006,
        B300 = 0o0000007,
        B600 = 0o0000010,
        B1200 = 0o0000011,
        B1800 = 0o0000012,
        B2400 = 0o0000013,
        B4800 = 0o0000014,
        B9600 = 0o0000015,
        B19200 = 0o0000016,
        B38400 = 0o0000017,

        B57600 = 0o00020,
        B115200 = 0o00021,
        B230400 = 0o00022,
        B460800 = 0o00023,
        B500000 = 0o00024,
        B576000 = 0o00025,
        B921600 = 0o00026,
        B1000000 = 0o00027,
        B1152000 = 0o00030,
        B1500000 = 0o00031,
        B2000000 = 0o00032,
        B2500000 = 0o00033,
        B3000000 = 0o00034,
        B3500000 = 0o00035,
        B4000000 = 0o00036,
    },
    else => enum(u32) {
        B0 = 0o0000000,
        B50 = 0o0000001,
        B75 = 0o0000002,
        B110 = 0o0000003,
        B134 = 0o0000004,
        B150 = 0o0000005,
        B200 = 0o0000006,
        B300 = 0o0000007,
        B600 = 0o0000010,
        B1200 = 0o0000011,
        B1800 = 0o0000012,
        B2400 = 0o0000013,
        B4800 = 0o0000014,
        B9600 = 0o0000015,
        B19200 = 0o0000016,
        B38400 = 0o0000017,

        B57600 = 0o0010001,
        B115200 = 0o0010002,
        B230400 = 0o0010003,
        B460800 = 0o0010004,
        B500000 = 0o0010005,
        B576000 = 0o0010006,
        B921600 = 0o0010007,
        B1000000 = 0o0010010,
        B1152000 = 0o0010011,
        B1500000 = 0o0010012,
        B2000000 = 0o0010013,
        B2500000 = 0o0010014,
        B3000000 = 0o0010015,
        B3500000 = 0o0010016,
        B4000000 = 0o0010017,
    },
};

pub const tc_iflag_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IXON: bool = false,
        IXOFF: bool = false,
        IXANY: bool = false,
        IUCLC: bool = false,
        IMAXBEL: bool = false,
        IUTF8: bool = false,
        _: u17 = 0,
    },
    else => packed struct(u32) {
        IGNBRK: bool = false,
        BRKINT: bool = false,
        IGNPAR: bool = false,
        PARMRK: bool = false,
        INPCK: bool = false,
        ISTRIP: bool = false,
        INLCR: bool = false,
        IGNCR: bool = false,
        ICRNL: bool = false,
        IUCLC: bool = false,
        IXON: bool = false,
        IXANY: bool = false,
        IXOFF: bool = false,
        IMAXBEL: bool = false,
        IUTF8: bool = false,
        _: u17 = 0,
    },
};

pub const tc_oflag_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        OPOST: bool = false,
        ONLCR: bool = false,
        OLCUC: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        OFILL: bool = false,
        OFDEL: bool = false,
        NLDLY: u2 = 0,
        TABDLY: u2 = 0,
        CRDLY: u2 = 0,
        FFDLY: u1 = 0,
        BSDLY: u1 = 0,
        VTDLY: u1 = 0,
        _: u15 = 0,
    },
    else => packed struct(u32) {
        OPOST: bool = false,
        OLCUC: bool = false,
        ONLCR: bool = false,
        OCRNL: bool = false,
        ONOCR: bool = false,
        ONLRET: bool = false,
        OFILL: bool = false,
        OFDEL: bool = false,
        NLDLY: u1 = 0,
        CRDLY: u2 = 0,
        TABDLY: u2 = 0,
        BSDLY: u1 = 0,
        VTDLY: u1 = 0,
        FFDLY: u1 = 0,
        _: u16 = 0,
    },
};

pub const CSIZE = enum(u2) { CS5, CS6, CS7, CS8 };

pub const tc_cflag_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        _0: u8 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        _: u16 = 0,
    },
    else => packed struct(u32) {
        _0: u4 = 0,
        CSIZE: CSIZE = .CS5,
        CSTOPB: bool = false,
        CREAD: bool = false,
        PARENB: bool = false,
        PARODD: bool = false,
        HUPCL: bool = false,
        CLOCAL: bool = false,
        _: u20 = 0,
    },
};

pub const tc_lflag_t = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        _0: u1 = 0,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHO: bool = false,
        ECHONL: bool = false,
        _5: u2 = 0,
        ISIG: bool = false,
        ICANON: bool = false,
        _9: u1 = 0,
        IEXTEN: bool = false,
        _11: u11 = 0,
        TOSTOP: bool = false,
        _23: u8 = 0,
        NOFLSH: bool = false,
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        _2: u1 = 0,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        IEXTEN: bool = false,
        _9: u6 = 0,
        TOSTOP: bool = false,
        _: u16 = 0,
    },
    else => packed struct(u32) {
        ISIG: bool = false,
        ICANON: bool = false,
        _2: u1 = 0,
        ECHO: bool = false,
        ECHOE: bool = false,
        ECHOK: bool = false,
        ECHONL: bool = false,
        NOFLSH: bool = false,
        TOSTOP: bool = false,
        _9: u6 = 0,
        IEXTEN: bool = false,
        _: u16 = 0,
    },
};

pub const cc_t = u8;

/// Indices into the `cc` array in the `termios` struct.
pub const V = switch (native_arch) {
    .mips, .mipsel, .mips64, .mips64el => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        MIN,
        TIME,
        EOL2,
        SWTC,
        START,
        STOP,
        SUSP,
        reserved,
        REPRINT,
        DISCARD,
        WERASE,
        LNEXT,
        EOF,
        EOL,
    },
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        EOF,
        MIN,
        EOL,
        TIME,
        EOL2,
        SWTC,
        WERASE,
        REPRINT,
        SUSP,
        START,
        STOP,
        LNEXT,
        DISCARD,
    },
    else => enum {
        INTR,
        QUIT,
        ERASE,
        KILL,
        EOF,
        TIME,
        MIN,
        SWTC,
        START,
        STOP,
        SUSP,
        EOL,
        REPRINT,
        DISCARD,
        WERASE,
        LNEXT,
        EOL2,
    },
};

pub const TCSA = enum(c_uint) {
    NOW,
    DRAIN,
    FLUSH,
    _,
};

pub const termios = switch (native_arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        cc: [NCCS]cc_t,
        line: cc_t,
        ispeed: speed_t,
        ospeed: speed_t,
    },
    else => extern struct {
        iflag: tc_iflag_t,
        oflag: tc_oflag_t,
        cflag: tc_cflag_t,
        lflag: tc_lflag_t,
        line: cc_t,
        cc: [NCCS]cc_t,
        ispeed: speed_t,
        ospeed: speed_t,
    },
};

pub const SIOCGIFINDEX = 0x8933;
pub const IFNAMESIZE = 16;

pub const ifmap = extern struct {
    mem_start: u32,
    mem_end: u32,
    base_addr: u16,
    irq: u8,
    dma: u8,
    port: u8,
};

pub const ifreq = extern struct {
    ifrn: extern union {
        name: [IFNAMESIZE]u8,
    },
    ifru: extern union {
        addr: sockaddr,
        dstaddr: sockaddr,
        broadaddr: sockaddr,
        netmask: sockaddr,
        hwaddr: sockaddr,
        flags: i16,
        ivalue: i32,
        mtu: i32,
        map: ifmap,
        slave: [IFNAMESIZE - 1:0]u8,
        newname: [IFNAMESIZE - 1:0]u8,
        data: ?[*]u8,
    },
};

// doc comments copied from musl
pub const rlimit_resource = if (native_arch.isMIPS() or native_arch.isSPARC())
    arch_bits.rlimit_resource
else
    enum(c_int) {
        /// Per-process CPU limit, in seconds.
        CPU,

        /// Largest file that can be created, in bytes.
        FSIZE,

        /// Maximum size of data segment, in bytes.
        DATA,

        /// Maximum size of stack segment, in bytes.
        STACK,

        /// Largest core file that can be created, in bytes.
        CORE,

        /// Largest resident set size, in bytes.
        /// This affects swapping; processes that are exceeding their
        /// resident set size will be more likely to have physical memory
        /// taken from them.
        RSS,

        /// Number of processes.
        NPROC,

        /// Number of open files.
        NOFILE,

        /// Locked-in-memory address space.
        MEMLOCK,

        /// Address space limit.
        AS,

        /// Maximum number of file locks.
        LOCKS,

        /// Maximum number of pending signals.
        SIGPENDING,

        /// Maximum bytes in POSIX message queues.
        MSGQUEUE,

        /// Maximum nice priority allowed to raise to.
        /// Nice levels 19 .. -20 correspond to 0 .. 39
        /// values of this resource limit.
        NICE,

        /// Maximum realtime priority allowed for non-priviledged
        /// processes.
        RTPRIO,

        /// Maximum CPU time in µs that a process scheduled under a real-time
        /// scheduling policy may consume without making a blocking system
        /// call before being forcibly descheduled.
        RTTIME,

        _,
    };

pub const rlim_t = u64;

pub const RLIM = struct {
    /// No limit
    pub const INFINITY = ~@as(rlim_t, 0);

    pub const SAVED_MAX = INFINITY;
    pub const SAVED_CUR = INFINITY;
};

pub const rlimit = extern struct {
    /// Soft limit
    cur: rlim_t,
    /// Hard limit
    max: rlim_t,
};

pub const MADV = struct {
    pub const NORMAL = 0;
    pub const RANDOM = 1;
    pub const SEQUENTIAL = 2;
    pub const WILLNEED = 3;
    pub const DONTNEED = 4;
    pub const FREE = 8;
    pub const REMOVE = 9;
    pub const DONTFORK = 10;
    pub const DOFORK = 11;
    pub const MERGEABLE = 12;
    pub const UNMERGEABLE = 13;
    pub const HUGEPAGE = 14;
    pub const NOHUGEPAGE = 15;
    pub const DONTDUMP = 16;
    pub const DODUMP = 17;
    pub const WIPEONFORK = 18;
    pub const KEEPONFORK = 19;
    pub const COLD = 20;
    pub const PAGEOUT = 21;
    pub const HWPOISON = 100;
    pub const SOFT_OFFLINE = 101;
};

pub const POSIX_FADV = switch (native_arch) {
    .s390x => if (@typeInfo(usize).Int.bits == 64) struct {
        pub const NORMAL = 0;
        pub const RANDOM = 1;
        pub const SEQUENTIAL = 2;
        pub const WILLNEED = 3;
        pub const DONTNEED = 6;
        pub const NOREUSE = 7;
    } else struct {
        pub const NORMAL = 0;
        pub const RANDOM = 1;
        pub const SEQUENTIAL = 2;
        pub const WILLNEED = 3;
        pub const DONTNEED = 4;
        pub const NOREUSE = 5;
    },
    else => struct {
        pub const NORMAL = 0;
        pub const RANDOM = 1;
        pub const SEQUENTIAL = 2;
        pub const WILLNEED = 3;
        pub const DONTNEED = 4;
        pub const NOREUSE = 5;
    },
};

/// The timespec struct used by the kernel.
pub const kernel_timespec = if (@sizeOf(usize) >= 8) timespec else extern struct {
    tv_sec: i64,
    tv_nsec: i64,
};

pub const timespec = extern struct {
    tv_sec: isize,
    tv_nsec: isize,
};

pub const XDP = struct {
    pub const SHARED_UMEM = (1 << 0);
    pub const COPY = (1 << 1);
    pub const ZEROCOPY = (1 << 2);
    pub const UMEM_UNALIGNED_CHUNK_FLAG = (1 << 0);
    pub const USE_NEED_WAKEUP = (1 << 3);

    pub const MMAP_OFFSETS = 1;
    pub const RX_RING = 2;
    pub const TX_RING = 3;
    pub const UMEM_REG = 4;
    pub const UMEM_FILL_RING = 5;
    pub const UMEM_COMPLETION_RING = 6;
    pub const STATISTICS = 7;
    pub const OPTIONS = 8;

    pub const OPTIONS_ZEROCOPY = (1 << 0);

    pub const PGOFF_RX_RING = 0;
    pub const PGOFF_TX_RING = 0x80000000;
    pub const UMEM_PGOFF_FILL_RING = 0x100000000;
    pub const UMEM_PGOFF_COMPLETION_RING = 0x180000000;
};

pub const xdp_ring_offset = extern struct {
    producer: u64,
    consumer: u64,
    desc: u64,
    flags: u64,
};

pub const xdp_mmap_offsets = extern struct {
    rx: xdp_ring_offset,
    tx: xdp_ring_offset,
    fr: xdp_ring_offset,
    cr: xdp_ring_offset,
};

pub const xdp_umem_reg = extern struct {
    addr: u64,
    len: u64,
    chunk_size: u32,
    headroom: u32,
    flags: u32,
};

pub const xdp_statistics = extern struct {
    rx_dropped: u64,
    rx_invalid_descs: u64,
    tx_invalid_descs: u64,
    rx_ring_full: u64,
    rx_fill_ring_empty_descs: u64,
    tx_ring_empty_descs: u64,
};

pub const xdp_options = extern struct {
    flags: u32,
};

pub const XSK_UNALIGNED_BUF_OFFSET_SHIFT = 48;
pub const XSK_UNALIGNED_BUF_ADDR_MASK = (1 << XSK_UNALIGNED_BUF_OFFSET_SHIFT) - 1;

pub const xdp_desc = extern struct {
    addr: u64,
    len: u32,
    options: u32,
};

fn issecure_mask(comptime x: comptime_int) comptime_int {
    return 1 << x;
}

pub const SECUREBITS_DEFAULT = 0x00000000;

pub const SECURE_NOROOT = 0;
pub const SECURE_NOROOT_LOCKED = 1;

pub const SECBIT_NOROOT = issecure_mask(SECURE_NOROOT);
pub const SECBIT_NOROOT_LOCKED = issecure_mask(SECURE_NOROOT_LOCKED);

pub const SECURE_NO_SETUID_FIXUP = 2;
pub const SECURE_NO_SETUID_FIXUP_LOCKED = 3;

pub const SECBIT_NO_SETUID_FIXUP = issecure_mask(SECURE_NO_SETUID_FIXUP);
pub const SECBIT_NO_SETUID_FIXUP_LOCKED = issecure_mask(SECURE_NO_SETUID_FIXUP_LOCKED);

pub const SECURE_KEEP_CAPS = 4;
pub const SECURE_KEEP_CAPS_LOCKED = 5;

pub const SECBIT_KEEP_CAPS = issecure_mask(SECURE_KEEP_CAPS);
pub const SECBIT_KEEP_CAPS_LOCKED = issecure_mask(SECURE_KEEP_CAPS_LOCKED);

pub const SECURE_NO_CAP_AMBIENT_RAISE = 6;
pub const SECURE_NO_CAP_AMBIENT_RAISE_LOCKED = 7;

pub const SECBIT_NO_CAP_AMBIENT_RAISE = issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE);
pub const SECBIT_NO_CAP_AMBIENT_RAISE_LOCKED = issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE_LOCKED);

pub const SECURE_ALL_BITS = issecure_mask(SECURE_NOROOT) |
    issecure_mask(SECURE_NO_SETUID_FIXUP) |
    issecure_mask(SECURE_KEEP_CAPS) |
    issecure_mask(SECURE_NO_CAP_AMBIENT_RAISE);
pub const SECURE_ALL_LOCKS = SECURE_ALL_BITS << 1;

pub const PR = enum(i32) {
    SET_PDEATHSIG = 1,
    GET_PDEATHSIG = 2,

    GET_DUMPABLE = 3,
    SET_DUMPABLE = 4,

    GET_UNALIGN = 5,
    SET_UNALIGN = 6,

    GET_KEEPCAPS = 7,
    SET_KEEPCAPS = 8,

    GET_FPEMU = 9,
    SET_FPEMU = 10,

    GET_FPEXC = 11,
    SET_FPEXC = 12,

    GET_TIMING = 13,
    SET_TIMING = 14,

    SET_NAME = 15,
    GET_NAME = 16,

    GET_ENDIAN = 19,
    SET_ENDIAN = 20,

    GET_SECCOMP = 21,
    SET_SECCOMP = 22,

    CAPBSET_READ = 23,
    CAPBSET_DROP = 24,

    GET_TSC = 25,
    SET_TSC = 26,

    GET_SECUREBITS = 27,
    SET_SECUREBITS = 28,

    SET_TIMERSLACK = 29,
    GET_TIMERSLACK = 30,

    TASK_PERF_EVENTS_DISABLE = 31,
    TASK_PERF_EVENTS_ENABLE = 32,

    MCE_KILL = 33,

    MCE_KILL_GET = 34,

    SET_MM = 35,

    SET_PTRACER = 0x59616d61,

    SET_CHILD_SUBREAPER = 36,
    GET_CHILD_SUBREAPER = 37,

    SET_NO_NEW_PRIVS = 38,
    GET_NO_NEW_PRIVS = 39,

    GET_TID_ADDRESS = 40,

    SET_THP_DISABLE = 41,
    GET_THP_DISABLE = 42,

    MPX_ENABLE_MANAGEMENT = 43,
    MPX_DISABLE_MANAGEMENT = 44,

    SET_FP_MODE = 45,
    GET_FP_MODE = 46,

    CAP_AMBIENT = 47,

    SVE_SET_VL = 50,
    SVE_GET_VL = 51,

    GET_SPECULATION_CTRL = 52,
    SET_SPECULATION_CTRL = 53,

    _,

    pub const UNALIGN_NOPRINT = 1;
    pub const UNALIGN_SIGBUS = 2;

    pub const FPEMU_NOPRINT = 1;
    pub const FPEMU_SIGFPE = 2;

    pub const FP_EXC_SW_ENABLE = 0x80;
    pub const FP_EXC_DIV = 0x010000;
    pub const FP_EXC_OVF = 0x020000;
    pub const FP_EXC_UND = 0x040000;
    pub const FP_EXC_RES = 0x080000;
    pub const FP_EXC_INV = 0x100000;
    pub const FP_EXC_DISABLED = 0;
    pub const FP_EXC_NONRECOV = 1;
    pub const FP_EXC_ASYNC = 2;
    pub const FP_EXC_PRECISE = 3;

    pub const TIMING_STATISTICAL = 0;
    pub const TIMING_TIMESTAMP = 1;

    pub const ENDIAN_BIG = 0;
    pub const ENDIAN_LITTLE = 1;
    pub const ENDIAN_PPC_LITTLE = 2;

    pub const TSC_ENABLE = 1;
    pub const TSC_SIGSEGV = 2;

    pub const MCE_KILL_CLEAR = 0;
    pub const MCE_KILL_SET = 1;

    pub const MCE_KILL_LATE = 0;
    pub const MCE_KILL_EARLY = 1;
    pub const MCE_KILL_DEFAULT = 2;

    pub const SET_MM_START_CODE = 1;
    pub const SET_MM_END_CODE = 2;
    pub const SET_MM_START_DATA = 3;
    pub const SET_MM_END_DATA = 4;
    pub const SET_MM_START_STACK = 5;
    pub const SET_MM_START_BRK = 6;
    pub const SET_MM_BRK = 7;
    pub const SET_MM_ARG_START = 8;
    pub const SET_MM_ARG_END = 9;
    pub const SET_MM_ENV_START = 10;
    pub const SET_MM_ENV_END = 11;
    pub const SET_MM_AUXV = 12;
    pub const SET_MM_EXE_FILE = 13;
    pub const SET_MM_MAP = 14;
    pub const SET_MM_MAP_SIZE = 15;

    pub const SET_PTRACER_ANY = std.math.maxInt(c_ulong);

    pub const FP_MODE_FR = 1 << 0;
    pub const FP_MODE_FRE = 1 << 1;

    pub const CAP_AMBIENT_IS_SET = 1;
    pub const CAP_AMBIENT_RAISE = 2;
    pub const CAP_AMBIENT_LOWER = 3;
    pub const CAP_AMBIENT_CLEAR_ALL = 4;

    pub const SVE_SET_VL_ONEXEC = 1 << 18;
    pub const SVE_VL_LEN_MASK = 0xffff;
    pub const SVE_VL_INHERIT = 1 << 17;

    pub const SPEC_STORE_BYPASS = 0;
    pub const SPEC_NOT_AFFECTED = 0;
    pub const SPEC_PRCTL = 1 << 0;
    pub const SPEC_ENABLE = 1 << 1;
    pub const SPEC_DISABLE = 1 << 2;
    pub const SPEC_FORCE_DISABLE = 1 << 3;
};

pub const prctl_mm_map = extern struct {
    start_code: u64,
    end_code: u64,
    start_data: u64,
    end_data: u64,
    start_brk: u64,
    brk: u64,
    start_stack: u64,
    arg_start: u64,
    arg_end: u64,
    env_start: u64,
    env_end: u64,
    auxv: *u64,
    auxv_size: u32,
    exe_fd: u32,
};

pub const NETLINK = struct {
    /// Routing/device hook
    pub const ROUTE = 0;

    /// Unused number
    pub const UNUSED = 1;

    /// Reserved for user mode socket protocols
    pub const USERSOCK = 2;

    /// Unused number, formerly ip_queue
    pub const FIREWALL = 3;

    /// socket monitoring
    pub const SOCK_DIAG = 4;

    /// netfilter/iptables ULOG
    pub const NFLOG = 5;

    /// ipsec
    pub const XFRM = 6;

    /// SELinux event notifications
    pub const SELINUX = 7;

    /// Open-iSCSI
    pub const ISCSI = 8;

    /// auditing
    pub const AUDIT = 9;

    pub const FIB_LOOKUP = 10;

    pub const CONNECTOR = 11;

    /// netfilter subsystem
    pub const NETFILTER = 12;

    pub const IP6_FW = 13;

    /// DECnet routing messages
    pub const DNRTMSG = 14;

    /// Kernel messages to userspace
    pub const KOBJECT_UEVENT = 15;

    pub const GENERIC = 16;

    // leave room for NETLINK_DM (DM Events)

    /// SCSI Transports
    pub const SCSITRANSPORT = 18;

    pub const ECRYPTFS = 19;

    pub const RDMA = 20;

    /// Crypto layer
    pub const CRYPTO = 21;

    /// SMC monitoring
    pub const SMC = 22;
};

// Flags values

/// It is request message.
pub const NLM_F_REQUEST = 0x01;

/// Multipart message, terminated by NLMSG_DONE
pub const NLM_F_MULTI = 0x02;

/// Reply with ack, with zero or error code
pub const NLM_F_ACK = 0x04;

/// Echo this request
pub const NLM_F_ECHO = 0x08;

/// Dump was inconsistent due to sequence change
pub const NLM_F_DUMP_INTR = 0x10;

/// Dump was filtered as requested
pub const NLM_F_DUMP_FILTERED = 0x20;

// Modifiers to GET request

/// specify tree root
pub const NLM_F_ROOT = 0x100;

/// return all matching
pub const NLM_F_MATCH = 0x200;

/// atomic GET
pub const NLM_F_ATOMIC = 0x400;
pub const NLM_F_DUMP = NLM_F_ROOT | NLM_F_MATCH;

// Modifiers to NEW request

/// Override existing
pub const NLM_F_REPLACE = 0x100;

/// Do not touch, if it exists
pub const NLM_F_EXCL = 0x200;

/// Create, if it does not exist
pub const NLM_F_CREATE = 0x400;

/// Add to end of list
pub const NLM_F_APPEND = 0x800;

// Modifiers to DELETE request

/// Do not delete recursively
pub const NLM_F_NONREC = 0x100;

// Flags for ACK message

/// request was capped
pub const NLM_F_CAPPED = 0x100;

/// extended ACK TVLs were included
pub const NLM_F_ACK_TLVS = 0x200;

pub const NetlinkMessageType = enum(u16) {
    /// < 0x10: reserved control messages
    pub const MIN_TYPE = 0x10;

    /// Nothing.
    NOOP = 0x1,

    /// Error
    ERROR = 0x2,

    /// End of a dump
    DONE = 0x3,

    /// Data lost
    OVERRUN = 0x4,

    // rtlink types

    RTM_NEWLINK = 16,
    RTM_DELLINK,
    RTM_GETLINK,
    RTM_SETLINK,

    RTM_NEWADDR = 20,
    RTM_DELADDR,
    RTM_GETADDR,

    RTM_NEWROUTE = 24,
    RTM_DELROUTE,
    RTM_GETROUTE,

    RTM_NEWNEIGH = 28,
    RTM_DELNEIGH,
    RTM_GETNEIGH,

    RTM_NEWRULE = 32,
    RTM_DELRULE,
    RTM_GETRULE,

    RTM_NEWQDISC = 36,
    RTM_DELQDISC,
    RTM_GETQDISC,

    RTM_NEWTCLASS = 40,
    RTM_DELTCLASS,
    RTM_GETTCLASS,

    RTM_NEWTFILTER = 44,
    RTM_DELTFILTER,
    RTM_GETTFILTER,

    RTM_NEWACTION = 48,
    RTM_DELACTION,
    RTM_GETACTION,

    RTM_NEWPREFIX = 52,

    RTM_GETMULTICAST = 58,

    RTM_GETANYCAST = 62,

    RTM_NEWNEIGHTBL = 64,
    RTM_GETNEIGHTBL = 66,
    RTM_SETNEIGHTBL,

    RTM_NEWNDUSEROPT = 68,

    RTM_NEWADDRLABEL = 72,
    RTM_DELADDRLABEL,
    RTM_GETADDRLABEL,

    RTM_GETDCB = 78,
    RTM_SETDCB,

    RTM_NEWNETCONF = 80,
    RTM_DELNETCONF,
    RTM_GETNETCONF = 82,

    RTM_NEWMDB = 84,
    RTM_DELMDB = 85,
    RTM_GETMDB = 86,

    RTM_NEWNSID = 88,
    RTM_DELNSID = 89,
    RTM_GETNSID = 90,

    RTM_NEWSTATS = 92,
    RTM_GETSTATS = 94,

    RTM_NEWCACHEREPORT = 96,

    RTM_NEWCHAIN = 100,
    RTM_DELCHAIN,
    RTM_GETCHAIN,

    RTM_NEWNEXTHOP = 104,
    RTM_DELNEXTHOP,
    RTM_GETNEXTHOP,

    _,
};

/// Netlink message header
/// Specified in RFC 3549 Section 2.3.2
pub const nlmsghdr = extern struct {
    /// Length of message including header
    len: u32,

    /// Message content
    type: NetlinkMessageType,

    /// Additional flags
    flags: u16,

    /// Sequence number
    seq: u32,

    /// Sending process port ID
    pid: u32,
};

pub const ifinfomsg = extern struct {
    family: u8,
    __pad1: u8 = 0,

    /// ARPHRD_*
    type: c_ushort,

    /// Link index
    index: c_int,

    /// IFF_* flags
    flags: c_uint,

    /// IFF_* change mask
    change: c_uint,
};

pub const rtattr = extern struct {
    /// Length of option
    len: c_ushort,

    /// Type of option
    type: IFLA,

    pub const ALIGNTO = 4;
};

pub const IFLA = enum(c_ushort) {
    UNSPEC,
    ADDRESS,
    BROADCAST,
    IFNAME,
    MTU,
    LINK,
    QDISC,
    STATS,
    COST,
    PRIORITY,
    MASTER,

    /// Wireless Extension event
    WIRELESS,

    /// Protocol specific information for a link
    PROTINFO,

    TXQLEN,
    MAP,
    WEIGHT,
    OPERSTATE,
    LINKMODE,
    LINKINFO,
    NET_NS_PID,
    IFALIAS,

    /// Number of VFs if device is SR-IOV PF
    NUM_VF,

    VFINFO_LIST,
    STATS64,
    VF_PORTS,
    PORT_SELF,
    AF_SPEC,

    /// Group the device belongs to
    GROUP,

    NET_NS_FD,

    /// Extended info mask, VFs, etc
    EXT_MASK,

    /// Promiscuity count: > 0 means acts PROMISC
    PROMISCUITY,

    NUM_TX_QUEUES,
    NUM_RX_QUEUES,
    CARRIER,
    PHYS_PORT_ID,
    CARRIER_CHANGES,
    PHYS_SWITCH_ID,
    LINK_NETNSID,
    PHYS_PORT_NAME,
    PROTO_DOWN,
    GSO_MAX_SEGS,
    GSO_MAX_SIZE,
    PAD,
    XDP,
    EVENT,

    NEW_NETNSID,
    IF_NETNSID,

    CARRIER_UP_COUNT,
    CARRIER_DOWN_COUNT,
    NEW_IFINDEX,
    MIN_MTU,
    MAX_MTU,

    _,

    pub const TARGET_NETNSID: IFLA = .IF_NETNSID;
};

pub const rtnl_link_ifmap = extern struct {
    mem_start: u64,
    mem_end: u64,
    base_addr: u64,
    irq: u16,
    dma: u8,
    port: u8,
};

pub const rtnl_link_stats = extern struct {
    /// total packets received
    rx_packets: u32,

    /// total packets transmitted
    tx_packets: u32,

    /// total bytes received
    rx_bytes: u32,

    /// total bytes transmitted
    tx_bytes: u32,

    /// bad packets received
    rx_errors: u32,

    /// packet transmit problems
    tx_errors: u32,

    /// no space in linux buffers
    rx_dropped: u32,

    /// no space available in linux
    tx_dropped: u32,

    /// multicast packets received
    multicast: u32,

    collisions: u32,

    // detailed rx_errors

    rx_length_errors: u32,

    /// receiver ring buff overflow
    rx_over_errors: u32,

    /// recved pkt with crc error
    rx_crc_errors: u32,

    /// recv'd frame alignment error
    rx_frame_errors: u32,

    /// recv'r fifo overrun
    rx_fifo_errors: u32,

    /// receiver missed packet
    rx_missed_errors: u32,

    // detailed tx_errors
    tx_aborted_errors: u32,
    tx_carrier_errors: u32,
    tx_fifo_errors: u32,
    tx_heartbeat_errors: u32,
    tx_window_errors: u32,

    // for cslip etc

    rx_compressed: u32,
    tx_compressed: u32,

    /// dropped, no handler found
    rx_nohandler: u32,
};

pub const rtnl_link_stats64 = extern struct {
    /// total packets received
    rx_packets: u64,

    /// total packets transmitted
    tx_packets: u64,

    /// total bytes received
    rx_bytes: u64,

    /// total bytes transmitted
    tx_bytes: u64,

    /// bad packets received
    rx_errors: u64,

    /// packet transmit problems
    tx_errors: u64,

    /// no space in linux buffers
    rx_dropped: u64,

    /// no space available in linux
    tx_dropped: u64,

    /// multicast packets received
    multicast: u64,

    collisions: u64,

    // detailed rx_errors

    rx_length_errors: u64,

    /// receiver ring buff overflow
    rx_over_errors: u64,

    /// recved pkt with crc error
    rx_crc_errors: u64,

    /// recv'd frame alignment error
    rx_frame_errors: u64,

    /// recv'r fifo overrun
    rx_fifo_errors: u64,

    /// receiver missed packet
    rx_missed_errors: u64,

    // detailed tx_errors
    tx_aborted_errors: u64,
    tx_carrier_errors: u64,
    tx_fifo_errors: u64,
    tx_heartbeat_errors: u64,
    tx_window_errors: u64,

    // for cslip etc

    rx_compressed: u64,
    tx_compressed: u64,

    /// dropped, no handler found
    rx_nohandler: u64,
};

pub const perf_event_attr = extern struct {
    /// Major type: hardware/software/tracepoint/etc.
    type: PERF.TYPE = undefined,
    /// Size of the attr structure, for fwd/bwd compat.
    size: u32 = @sizeOf(perf_event_attr),
    /// Type specific configuration information.
    config: u64 = 0,

    sample_period_or_freq: u64 = 0,
    sample_type: u64 = 0,
    read_format: u64 = 0,

    flags: packed struct {
        /// off by default
        disabled: bool = false,
        /// children inherit it
        inherit: bool = false,
        /// must always be on PMU
        pinned: bool = false,
        /// only group on PMU
        exclusive: bool = false,
        /// don't count user
        exclude_user: bool = false,
        /// ditto kernel
        exclude_kernel: bool = false,
        /// ditto hypervisor
        exclude_hv: bool = false,
        /// don't count when idle
        exclude_idle: bool = false,
        /// include mmap data
        mmap: bool = false,
        /// include comm data
        comm: bool = false,
        /// use freq, not period
        freq: bool = false,
        /// per task counts
        inherit_stat: bool = false,
        /// next exec enables
        enable_on_exec: bool = false,
        /// trace fork/exit
        task: bool = false,
        /// wakeup_watermark
        watermark: bool = false,
        /// precise_ip:
        ///
        ///  0 - SAMPLE_IP can have arbitrary skid
        ///  1 - SAMPLE_IP must have constant skid
        ///  2 - SAMPLE_IP requested to have 0 skid
        ///  3 - SAMPLE_IP must have 0 skid
        ///
        ///  See also PERF_RECORD_MISC_EXACT_IP
        /// skid constraint
        precise_ip: u2 = 0,
        /// non-exec mmap data
        mmap_data: bool = false,
        /// sample_type all events
        sample_id_all: bool = false,

        /// don't count in host
        exclude_host: bool = false,
        /// don't count in guest
        exclude_guest: bool = false,

        /// exclude kernel callchains
        exclude_callchain_kernel: bool = false,
        /// exclude user callchains
        exclude_callchain_user: bool = false,
        /// include mmap with inode data
        mmap2: bool = false,
        /// flag comm events that are due to an exec
        comm_exec: bool = false,
        /// use @clockid for time fields
        use_clockid: bool = false,
        /// context switch data
        context_switch: bool = false,
        /// Write ring buffer from end to beginning
        write_backward: bool = false,
        /// include namespaces data
        namespaces: bool = false,

        __reserved_1: u35 = 0,
    } = .{},
    /// wakeup every n events, or
    /// bytes before wakeup
    wakeup_events_or_watermark: u32 = 0,

    bp_type: u32 = 0,

    /// This field is also used for:
    /// bp_addr
    /// kprobe_func for perf_kprobe
    /// uprobe_path for perf_uprobe
    config1: u64 = 0,
    /// This field is also used for:
    /// bp_len
    /// kprobe_addr when kprobe_func == null
    /// probe_offset for perf_[k,u]probe
    config2: u64 = 0,

    /// enum perf_branch_sample_type
    branch_sample_type: u64 = 0,

    /// Defines set of user regs to dump on samples.
    /// See asm/perf_regs.h for details.
    sample_regs_user: u64 = 0,

    /// Defines size of the user stack to dump on samples.
    sample_stack_user: u32 = 0,

    clockid: i32 = 0,
    /// Defines set of regs to dump for each sample
    /// state captured on:
    ///  - precise = 0: PMU interrupt
    ///  - precise > 0: sampled instruction
    ///
    /// See asm/perf_regs.h for details.
    sample_regs_intr: u64 = 0,

    /// Wakeup watermark for AUX area
    aux_watermark: u32 = 0,
    sample_max_stack: u16 = 0,
    /// Align to u64
    __reserved_2: u16 = 0,
};

pub const PERF = struct {
    pub const TYPE = enum(u32) {
        HARDWARE,
        SOFTWARE,
        TRACEPOINT,
        HW_CACHE,
        RAW,
        BREAKPOINT,
        MAX,
        _,
    };

    pub const COUNT = struct {
        pub const HW = enum(u32) {
            CPU_CYCLES,
            INSTRUCTIONS,
            CACHE_REFERENCES,
            CACHE_MISSES,
            BRANCH_INSTRUCTIONS,
            BRANCH_MISSES,
            BUS_CYCLES,
            STALLED_CYCLES_FRONTEND,
            STALLED_CYCLES_BACKEND,
            REF_CPU_CYCLES,
            MAX,

            pub const CACHE = enum(u32) {
                L1D,
                L1I,
                LL,
                DTLB,
                ITLB,
                BPU,
                NODE,
                MAX,

                pub const OP = enum(u32) {
                    READ,
                    WRITE,
                    PREFETCH,
                    MAX,
                };

                pub const RESULT = enum(u32) {
                    ACCESS,
                    MISS,
                    MAX,
                };
            };
        };

        pub const SW = enum(u32) {
            CPU_CLOCK,
            TASK_CLOCK,
            PAGE_FAULTS,
            CONTEXT_SWITCHES,
            CPU_MIGRATIONS,
            PAGE_FAULTS_MIN,
            PAGE_FAULTS_MAJ,
            ALIGNMENT_FAULTS,
            EMULATION_FAULTS,
            DUMMY,
            BPF_OUTPUT,
            MAX,
        };
    };

    pub const SAMPLE = struct {
        pub const IP = 1;
        pub const TID = 2;
        pub const TIME = 4;
        pub const ADDR = 8;
        pub const READ = 16;
        pub const CALLCHAIN = 32;
        pub const ID = 64;
        pub const CPU = 128;
        pub const PERIOD = 256;
        pub const STREAM_ID = 512;
        pub const RAW = 1024;
        pub const BRANCH_STACK = 2048;
        pub const REGS_USER = 4096;
        pub const STACK_USER = 8192;
        pub const WEIGHT = 16384;
        pub const DATA_SRC = 32768;
        pub const IDENTIFIER = 65536;
        pub const TRANSACTION = 131072;
        pub const REGS_INTR = 262144;
        pub const PHYS_ADDR = 524288;
        pub const MAX = 1048576;

        pub const BRANCH = struct {
            pub const USER = 1 << 0;
            pub const KERNEL = 1 << 1;
            pub const HV = 1 << 2;
            pub const ANY = 1 << 3;
            pub const ANY_CALL = 1 << 4;
            pub const ANY_RETURN = 1 << 5;
            pub const IND_CALL = 1 << 6;
            pub const ABORT_TX = 1 << 7;
            pub const IN_TX = 1 << 8;
            pub const NO_TX = 1 << 9;
            pub const COND = 1 << 10;
            pub const CALL_STACK = 1 << 11;
            pub const IND_JUMP = 1 << 12;
            pub const CALL = 1 << 13;
            pub const NO_FLAGS = 1 << 14;
            pub const NO_CYCLES = 1 << 15;
            pub const TYPE_SAVE = 1 << 16;
            pub const MAX = 1 << 17;
        };
    };

    pub const FLAG = struct {
        pub const FD_NO_GROUP = 1 << 0;
        pub const FD_OUTPUT = 1 << 1;
        pub const PID_CGROUP = 1 << 2;
        pub const FD_CLOEXEC = 1 << 3;
    };

    pub const EVENT_IOC = struct {
        pub const ENABLE = 9216;
        pub const DISABLE = 9217;
        pub const REFRESH = 9218;
        pub const RESET = 9219;
        pub const PERIOD = 1074275332;
        pub const SET_OUTPUT = 9221;
        pub const SET_FILTER = 1074275334;
        pub const SET_BPF = 1074013192;
        pub const PAUSE_OUTPUT = 1074013193;
        pub const QUERY_BPF = 3221758986;
        pub const MODIFY_ATTRIBUTES = 1074275339;
    };

    pub const IOC_FLAG_GROUP = 1;
};

// TODO: Add the rest of the AUDIT defines?
pub const AUDIT = struct {
    pub const ARCH = enum(u32) {
        const @"64BIT" = 0x80000000;
        const LE = 0x40000000;

        pub const current: AUDIT.ARCH = switch (native_arch) {
            .x86 => .X86,
            .x86_64 => .X86_64,
            .aarch64 => .AARCH64,
            .arm, .thumb => .ARM,
            .riscv64 => .RISCV64,
            .sparc64 => .SPARC64,
            .mips => .MIPS,
            .mipsel => .MIPSEL,
            .powerpc => .PPC,
            .powerpc64 => .PPC64,
            .powerpc64le => .PPC64LE,
            else => @compileError("unsupported architecture"),
        };

        AARCH64 = toAudit(.aarch64),
        ARM = toAudit(.arm),
        ARMEB = toAudit(.armeb),
        CSKY = toAudit(.csky),
        HEXAGON = @intFromEnum(std.elf.EM.HEXAGON),
        X86 = toAudit(.x86),
        M68K = toAudit(.m68k),
        MIPS = toAudit(.mips),
        MIPSEL = toAudit(.mips) | LE,
        MIPS64 = toAudit(.mips64),
        MIPSEL64 = toAudit(.mips64) | LE,
        PPC = toAudit(.powerpc),
        PPC64 = toAudit(.powerpc64),
        PPC64LE = toAudit(.powerpc64le),
        RISCV32 = toAudit(.riscv32),
        RISCV64 = toAudit(.riscv64),
        S390X = toAudit(.s390x),
        SPARC = toAudit(.sparc),
        SPARC64 = toAudit(.sparc64),
        X86_64 = toAudit(.x86_64),

        fn toAudit(arch: std.Target.Cpu.Arch) u32 {
            var res: u32 = @intFromEnum(arch.toElfMachine());
            if (arch.endian() == .little) res |= LE;
            switch (arch) {
                .aarch64,
                .mips64,
                .mips64el,
                .powerpc64,
                .powerpc64le,
                .riscv64,
                .sparc64,
                .x86_64,
                => res |= @"64BIT",
                else => {},
            }
            return res;
        }
    };
};

pub const PTRACE = struct {
    pub const TRACEME = 0;
    pub const PEEKTEXT = 1;
    pub const PEEKDATA = 2;
    pub const PEEKUSER = 3;
    pub const POKETEXT = 4;
    pub const POKEDATA = 5;
    pub const POKEUSER = 6;
    pub const CONT = 7;
    pub const KILL = 8;
    pub const SINGLESTEP = 9;
    pub const GETREGS = 12;
    pub const SETREGS = 13;
    pub const GETFPREGS = 14;
    pub const SETFPREGS = 15;
    pub const ATTACH = 16;
    pub const DETACH = 17;
    pub const GETFPXREGS = 18;
    pub const SETFPXREGS = 19;
    pub const SYSCALL = 24;
    pub const SETOPTIONS = 0x4200;
    pub const GETEVENTMSG = 0x4201;
    pub const GETSIGINFO = 0x4202;
    pub const SETSIGINFO = 0x4203;
    pub const GETREGSET = 0x4204;
    pub const SETREGSET = 0x4205;
    pub const SEIZE = 0x4206;
    pub const INTERRUPT = 0x4207;
    pub const LISTEN = 0x4208;
    pub const PEEKSIGINFO = 0x4209;
    pub const GETSIGMASK = 0x420a;
    pub const SETSIGMASK = 0x420b;
    pub const SECCOMP_GET_FILTER = 0x420c;
    pub const SECCOMP_GET_METADATA = 0x420d;
    pub const GET_SYSCALL_INFO = 0x420e;
};

/// A waiter for vectorized wait.
pub const futex_waitv = extern struct {
    // Expected value at uaddr
    val: u64,
    /// User address to wait on.
    uaddr: u64,
    /// Flags for this waiter.
    flags: u32,
    /// Reserved memeber to preserve alignment.
    /// Should be 0.
    __reserved: u32,
};

pub const cache_stat_range = extern struct {
    off: u64,
    len: u64,
};

pub const cache_stat = extern struct {
    /// Number of cached pages.
    cache: u64,
    /// Number of dirty pages.
    dirty: u64,
    /// Number of pages marked for writeback.
    writeback: u64,
    /// Number of pages evicted from the cache.
    evicted: u64,
    /// Number of recently evicted pages.
    /// A page is recently evicted if its last eviction was recent enough that its
    /// reentry to the cache would indicate that it is actively being used by the
    /// system, and that there is memory pressure on the system.
    recently_evicted: u64,
};

pub const SHADOW_STACK = struct {
    /// Set up a restore token in the shadow stack.
    pub const SET_TOKEN: u64 = 1 << 0;
};
