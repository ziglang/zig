//! This file provides the system interface functions for Linux matching those
//! that are provided by libc, whether or not libc is linked. The following
//! abstractions are made:
//! * Implement all the syscalls in the same way that libc functions will
//!   provide `rename` when only the `renameat` syscall exists.
const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const elf = std.elf;
const vdso = @import("linux/vdso.zig");
const dl = @import("../dynamic_library.zig");
const native_arch = builtin.cpu.arch;
const native_abi = builtin.abi;
const native_endian = native_arch.endian();
const is_loongarch = native_arch.isLoongArch();
const is_mips = native_arch.isMIPS();
const is_ppc = native_arch.isPowerPC();
const is_riscv = native_arch.isRISCV();
const is_sparc = native_arch.isSPARC();
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const winsize = std.posix.winsize;
const ACCMODE = std.posix.ACCMODE;
pub const IoUring = @import("linux/IoUring.zig");

test {
    if (builtin.os.tag == .linux) {
        _ = @import("linux/test.zig");
    }
}

const arch_bits = switch (native_arch) {
    .aarch64, .aarch64_be => @import("linux/aarch64.zig"),
    .arm, .armeb, .thumb, .thumbeb => @import("linux/arm.zig"),
    .hexagon => @import("linux/hexagon.zig"),
    .loongarch64 => @import("linux/loongarch64.zig"),
    .m68k => @import("linux/m68k.zig"),
    .mips, .mipsel => @import("linux/mips.zig"),
    .mips64, .mips64el => switch (builtin.abi) {
        .gnuabin32, .muslabin32 => @import("linux/mipsn32.zig"),
        else => @import("linux/mips64.zig"),
    },
    .or1k => @import("linux/or1k.zig"),
    .powerpc, .powerpcle => @import("linux/powerpc.zig"),
    .powerpc64, .powerpc64le => @import("linux/powerpc64.zig"),
    .riscv32 => @import("linux/riscv32.zig"),
    .riscv64 => @import("linux/riscv64.zig"),
    .s390x => @import("linux/s390x.zig"),
    .sparc64 => @import("linux/sparc64.zig"),
    .x86 => @import("linux/x86.zig"),
    .x86_64 => switch (builtin.abi) {
        .gnux32, .muslx32 => @import("linux/x32.zig"),
        else => @import("linux/x86_64.zig"),
    },
    else => struct {},
};

const syscall_bits = if (native_arch.isThumb()) @import("linux/thumb.zig") else arch_bits;

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

pub fn clone(
    func: *const fn (arg: usize) callconv(.c) u8,
    stack: usize,
    flags: u32,
    arg: usize,
    ptid: ?*i32,
    tp: usize, // aka tls
    ctid: ?*i32,
) usize {
    // Can't directly call a naked function; cast to C calling convention first.
    return @as(*const fn (
        *const fn (arg: usize) callconv(.c) u8,
        usize,
        u32,
        usize,
        ?*i32,
        usize,
        ?*i32,
    ) callconv(.c) usize, @ptrCast(&syscall_bits.clone))(func, stack, flags, arg, ptid, tp, ctid);
}

pub const ARCH = arch_bits.ARCH;
pub const HWCAP = arch_bits.HWCAP;
pub const SC = arch_bits.SC;
pub const Stat = arch_bits.Stat;
pub const VDSO = arch_bits.VDSO;
pub const blkcnt_t = arch_bits.blkcnt_t;
pub const blksize_t = arch_bits.blksize_t;
pub const dev_t = arch_bits.dev_t;
pub const ino_t = arch_bits.ino_t;
pub const mode_t = arch_bits.mode_t;
pub const nlink_t = arch_bits.nlink_t;
pub const off_t = arch_bits.off_t;
pub const time_t = arch_bits.time_t;
pub const user_desc = arch_bits.user_desc;

pub const tls = @import("linux/tls.zig");
pub const BPF = @import("linux/bpf.zig");
pub const IOCTL = @import("linux/ioctl.zig");
pub const SECCOMP = @import("linux/seccomp.zig");

pub const syscalls = @import("linux/syscalls.zig");
pub const SYS = switch (native_arch) {
    .arc, .arceb => syscalls.Arc,
    .aarch64, .aarch64_be => syscalls.Arm64,
    .arm, .armeb, .thumb, .thumbeb => syscalls.Arm,
    .csky => syscalls.CSky,
    .hexagon => syscalls.Hexagon,
    .loongarch64 => syscalls.LoongArch64,
    .m68k => syscalls.M68k,
    .mips, .mipsel => syscalls.MipsO32,
    .mips64, .mips64el => switch (builtin.abi) {
        .gnuabin32, .muslabin32 => syscalls.MipsN32,
        else => syscalls.MipsN64,
    },
    .or1k => syscalls.OpenRisc,
    .powerpc, .powerpcle => syscalls.PowerPC,
    .powerpc64, .powerpc64le => syscalls.PowerPC64,
    .riscv32 => syscalls.RiscV32,
    .riscv64 => syscalls.RiscV64,
    .s390x => syscalls.S390x,
    .sparc => syscalls.Sparc,
    .sparc64 => syscalls.Sparc64,
    .x86 => syscalls.X86,
    .x86_64 => switch (builtin.abi) {
        .gnux32, .muslx32 => syscalls.X32,
        else => syscalls.X64,
    },
    .xtensa, .xtensaeb => syscalls.Xtensa,
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
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb => packed struct(u32) {
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
    .riscv32, .riscv64, .loongarch64 => packed struct(u32) {
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
    .hexagon, .m68k, .or1k, .s390x => packed struct(u32) {
        TYPE: MAP_TYPE,
        FIXED: bool = false,
        ANONYMOUS: bool = false,
        _4: u1 = 0,
        _5: u1 = 0,
        GROWSDOWN: bool = false,
        _7: u1 = 0,
        _8: u1 = 0,
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
        _19: u5 = 0,
        UNINITIALIZED: bool = false,
        _: u5 = 0,
    },
    else => @compileError("missing std.os.linux.MAP constants for this architecture"),
};

pub const MREMAP = packed struct(u32) {
    MAYMOVE: bool = false,
    FIXED: bool = false,
    DONTUNMAP: bool = false,
    _: u29 = 0,
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
        _23: u9 = 0,
    },
    .x86, .riscv32, .riscv64, .loongarch64 => packed struct(u32) {
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
        _23: u9 = 0,
    },
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb => packed struct(u32) {
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
        _23: u9 = 0,
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
        _27: u6 = 0,
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
        _23: u9 = 0,
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
        _23: u9 = 0,
    },
    .hexagon, .or1k, .s390x => packed struct(u32) {
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
        _20: u1 = 0,
        PATH: bool = false,
        _22: u10 = 0,

        // #define O_RSYNC    04010000
        // #define O_SYNC     04010000
        // #define O_TMPFILE 020200000
        // #define O_NDELAY O_NONBLOCK
    },
    .m68k => packed struct(u32) {
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
        _20: u1 = 0,
        PATH: bool = false,
        _22: u10 = 0,
    },
    else => @compileError("missing std.os.linux.O constants for this architecture"),
};

/// flags for `pipe2` and `IoUring.pipe`
/// matches flags in `O` but specific to `pipe2` syscall
pub const Pipe2 = switch (native_arch) {
    .x86_64, .x86, .riscv32, .riscv64, .loongarch64, .hexagon, .or1k, .s390x => packed struct(u32) {
        _: u7 = 0,
        notification_pipe: bool = false,
        _9: u3 = 0,
        nonblock: bool = false,
        _13: u2 = 0,
        direct: bool = false,
        _16: u4 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    },
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb, .m68k => packed struct(u32) {
        _: u7 = 0,
        notification_pipe: bool = false,
        _9: u3 = 0,
        nonblock: bool = false,
        _13: u4 = 0,
        direct: bool = false,
        _18: u2 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    },
    .sparc64 => packed struct(u32) {
        _: u11 = 0,
        notification_pipe: bool = false,
        _13: u2 = 0,
        nonblock: bool = false,
        _16: u5 = 0,
        direct: bool = false,
        _22: u1 = 0,
        cloexec: bool = false,
        _24: u9 = 0,
    },
    .mips, .mipsel, .mips64, .mips64el => packed struct(u32) {
        _: u7 = 0,
        nonblock: bool = false,
        _9: u2 = 0,
        notification_pipe: bool = false,
        _12: u4 = 0,
        direct: bool = false,
        _17: u3 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    },
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => packed struct(u32) {
        _: u7 = 0,
        notification_pipe: bool = false,
        _9: u3 = 0,
        nonblock: bool = false,
        _13: u5 = 0,
        direct: bool = false,
        _19: u1 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    },
    else => @compileError("missing std.os.linux.Pipe2 flags for this architecture"),
};

/// Set by startup code, used by `getauxval`.
pub var elf_aux_maybe: ?[*]std.elf.Auxv = null;

/// Whether an external or internal getauxval implementation is used.
const extern_getauxval = switch (builtin.zig_backend) {
    // Calling extern functions is not yet supported with these backends
    .stage2_arm,
    .stage2_powerpc,
    .stage2_riscv64,
    .stage2_sparc64,
    => false,
    else => !builtin.link_libc,
};

pub const getauxval = if (extern_getauxval) struct {
    comptime {
        const root = @import("root");
        // Export this only when building an executable, otherwise it is overriding
        // the libc implementation
        if (builtin.output_mode == .Exe or @hasDecl(root, "main")) {
            @export(&getauxvalImpl, .{ .name = "getauxval", .linkage = .weak });
        }
    }
    extern fn getauxval(index: usize) usize;
}.getauxval else getauxvalImpl;

fn getauxvalImpl(index: usize) callconv(.c) usize {
    @disableInstrumentation();
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
    builtin.cpu.arch.isArm() or
    builtin.cpu.arch == .hexagon or
    builtin.cpu.arch.isMIPS32() or
    builtin.cpu.arch.isPowerPC32();

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

/// Get the errno from a syscall return value. SUCCESS means no error.
pub fn errno(r: usize) E {
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
                const rc = fcntl(F.GETFD, @as(fd_t, old), 0);
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
        return syscall2(.clone, @intFromEnum(SIG.CHLD), 0);
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

pub fn futimens(fd: i32, times: ?*const [2]timespec) usize {
    return utimensat(fd, null, times, 0);
}

pub fn utimensat(dirfd: i32, path: ?[*:0]const u8, times: ?*const [2]timespec, flags: u32) usize {
    return syscall4(
        if (@hasField(SYS, "utimensat") and native_arch != .hexagon) .utimensat else .utimensat_time64,
        @as(usize, @bitCast(@as(isize, dirfd))),
        @intFromPtr(path),
        @intFromPtr(times),
        flags,
    );
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

// The 4th parameter to the v1 futex syscall can either be an optional
// pointer to a timespec, or a uint32, depending on which "op" is being
// performed.
pub const futex_param4 = extern union {
    timeout: ?*const timespec,
    /// On all platforms only the bottom 32-bits of `val2` are relevant.
    /// This is 64-bit to match the pointer in the union.
    val2: usize,
};

/// The futex v1 syscall, see also the newer the futex2_{wait,wakeup,requeue,waitv} syscalls.
///
/// The futex_op parameter is a sub-command and flags.  The sub-command
/// defines which of the subsequent paramters are relevant.
pub fn futex(
    uaddr: *const u32,
    futex_op: FUTEX_OP,
    val: u32,
    val2timeout: futex_param4,
    uaddr2: ?*const anyopaque,
    val3: u32,
) usize {
    return syscall6(
        if (@hasField(SYS, "futex") and native_arch != .hexagon) .futex else .futex_time64,
        @intFromPtr(uaddr),
        @as(u32, @bitCast(futex_op)),
        val,
        @intFromPtr(val2timeout.timeout),
        @intFromPtr(uaddr2),
        val3,
    );
}

/// Three-argument variation of the v1 futex call.  Only suitable for a
/// futex_op that ignores the remaining arguments (e.g., FUTUX_OP.WAKE).
pub fn futex_3arg(uaddr: *const u32, futex_op: FUTEX_OP, val: u32) usize {
    return syscall3(
        if (@hasField(SYS, "futex") and native_arch != .hexagon) .futex else .futex_time64,
        @intFromPtr(uaddr),
        @as(u32, @bitCast(futex_op)),
        val,
    );
}

/// Four-argument variation on the v1 futex call.  Only suitable for
/// futex_op that ignores the remaining arguments (e.g., FUTEX_OP.WAIT).
pub fn futex_4arg(uaddr: *const u32, futex_op: FUTEX_OP, val: u32, timeout: ?*const timespec) usize {
    return syscall4(
        if (@hasField(SYS, "futex") and native_arch != .hexagon) .futex else .futex_time64,
        @intFromPtr(uaddr),
        @as(u32, @bitCast(futex_op)),
        val,
        @intFromPtr(timeout),
    );
}

/// Given an array of `Futex2.WaitOne`, wait on each uaddr.
/// The thread wakes if a futex_wake() is performed at any uaddr.
/// The syscall returns immediately if any futex has *uaddr != val.
/// timeout is an optional, absolute timeout value for the operation.
/// The `flags` argument is for future use and currently should be `.{}`.
/// Flags for private futexes, sizes, etc. should be set on the
/// individual flags of each `Futex2.WaitOne`.
///
/// Returns the array index of one of the woken futexes.
/// No further information is provided: any number of other futexes may also
/// have been woken by the same event, and if more than one futex was woken,
/// the returned index may refer to any one of them.
/// (It is not necessaryily the futex with the smallest index, nor the one
/// most recently woken, nor...)
///
/// Requires at least kernel v5.16.
pub fn futex2_waitv(
    /// The length of `futexes` slice must not exceed `Futex2.waitone_max`
    futexes: []const Futex2.WaitOne,
    flags: Futex2.Waitv,
    /// Optional absolute timeout.  Always 64-bit, even on 32-bit platforms.
    timeout: ?*const kernel_timespec,
    /// Clock to be used for the timeout, realtime or monotonic.
    clockid: clockid_t,
) usize {
    assert(futexes.len <= Futex2.waitone_max);
    return syscall5(
        .futex_waitv,
        @intFromPtr(futexes.ptr),
        @intCast(futexes.len),
        @as(u32, @bitCast(flags)),
        @intFromPtr(timeout),
        @intFromEnum(clockid),
    );
}

/// Wait on a single futex.
/// Identical to the futex v1 `FUTEX.FUTEX_WAIT_BITSET` op, except it is part of the
/// futex2 family of calls.
///
/// Requires at least kernel v6.7.
pub fn futex2_wait(
    /// Address of the futex to wait on.
    uaddr: *const u32,
    /// Value of `uaddr`.
    val: usize,
    /// Bitmask to match against incoming wakeup masks.  Must not be zero.
    mask: Futex2.Bitset,
    flags: Futex2.Wait,
    /// Optional absolute timeout.  Always 64-bit, even on 32-bit platforms.
    timeout: ?*const kernel_timespec,
    /// Clock to be used for the timeout, realtime or monotonic.
    clockid: clockid_t,
) usize {
    return syscall6(
        .futex_wait,
        @intFromPtr(uaddr),
        val,
        @intCast(mask.toInt()),
        @as(u32, @bitCast(flags)),
        @intFromPtr(timeout),
        @intFromEnum(clockid),
    );
}

/// Wake (subset of) waiters on given futex.
/// Identical to the traditional `FUTEX.FUTEX_WAKE_BITSET` op, except it is part of the
/// futex2 family of calls.
///
/// Requires at least kernel v6.7.
pub fn futex2_wake(
    /// Futex to wake
    uaddr: *const u32,
    /// Bitmask to match against waiters.
    mask: Futex2.Bitset,
    /// Maximum number of waiters on the futex to wake.
    nr_wake: i32,
    flags: Futex2.Wake,
) usize {
    return syscall4(
        .futex_wake,
        @intFromPtr(uaddr),
        @intCast(mask.toInt()),
        @intCast(nr_wake),
        @as(u32, @bitCast(flags)),
    );
}

/// Wake and/or requeue waiter(s) from one futex to another.
/// Identical to `FUTEX.CMP_REQUEUE`, except it is part of the futex2 family of calls.
///
/// Requires at least kernel v6.7.
// TODO: test to ensure I didn't break it
pub fn futex2_requeue(
    /// The source and destination futexes.  Must be a 2-element array.
    waiters: *const [2]Futex2.WaitOne,
    /// Currently unused.
    flags: Futex2.Requeue,
    /// Maximum number of waiters to wake on the source futex.
    nr_wake: i32,
    /// Maximum number of waiters to transfer to the destination futex.
    nr_requeue: i32,
) usize {
    return syscall4(
        .futex_requeue,
        @intFromPtr(waiters),
        @as(u32, @bitCast(flags)),
        @intCast(nr_wake),
        @intCast(nr_requeue),
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

pub fn fanotify_init(flags: fanotify.InitFlags, event_f_flags: u32) usize {
    return syscall2(.fanotify_init, @as(u32, @bitCast(flags)), event_f_flags);
}

pub fn fanotify_mark(
    fd: fd_t,
    flags: fanotify.MarkFlags,
    mask: fanotify.MarkMask,
    dirfd: fd_t,
    pathname: ?[*:0]const u8,
) usize {
    if (usize_bits < 64) {
        const mask_halves = splitValue64(@bitCast(mask));
        return syscall6(
            .fanotify_mark,
            @bitCast(@as(isize, fd)),
            @as(u32, @bitCast(flags)),
            mask_halves[0],
            mask_halves[1],
            @bitCast(@as(isize, dirfd)),
            @intFromPtr(pathname),
        );
    } else {
        return syscall5(
            .fanotify_mark,
            @bitCast(@as(isize, fd)),
            @as(u32, @bitCast(flags)),
            @bitCast(mask),
            @bitCast(@as(isize, dirfd)),
            @intFromPtr(pathname),
        );
    }
}

pub fn name_to_handle_at(
    dirfd: fd_t,
    pathname: [*:0]const u8,
    handle: *std.os.linux.file_handle,
    mount_id: *i32,
    flags: u32,
) usize {
    return syscall5(
        .name_to_handle_at,
        @as(u32, @bitCast(dirfd)),
        @intFromPtr(pathname),
        @intFromPtr(handle),
        @intFromPtr(mount_id),
        flags,
    );
}

pub fn readlink(noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    if (@hasField(SYS, "readlink")) {
        return syscall3(.readlink, @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
    } else {
        return syscall4(.readlinkat, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
    }
}

pub fn readlinkat(dirfd: i32, noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(.readlinkat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), @intFromPtr(buf_ptr), buf_len);
}

pub fn mkdir(path: [*:0]const u8, mode: mode_t) usize {
    if (@hasField(SYS, "mkdir")) {
        return syscall2(.mkdir, @intFromPtr(path), mode);
    } else {
        return syscall3(.mkdirat, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(path), mode);
    }
}

pub fn mkdirat(dirfd: i32, path: [*:0]const u8, mode: mode_t) usize {
    return syscall3(.mkdirat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode);
}

pub fn mknod(path: [*:0]const u8, mode: u32, dev: u32) usize {
    if (@hasField(SYS, "mknod")) {
        return syscall3(.mknod, @intFromPtr(path), mode, dev);
    } else {
        return mknodat(At.fdcwd, path, mode, dev);
    }
}

pub fn mknodat(dirfd: i32, path: [*:0]const u8, mode: u32, dev: u32) usize {
    return syscall4(.mknodat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode, dev);
}

pub fn mount(special: ?[*:0]const u8, dir: [*:0]const u8, fstype: ?[*:0]const u8, flags: u32, data: usize) usize {
    return syscall5(.mount, @intFromPtr(special), @intFromPtr(dir), @intFromPtr(fstype), flags, data);
}

pub fn umount(special: [*:0]const u8) usize {
    return syscall2(.umount2, @intFromPtr(special), 0);
}

pub fn umount2(special: [*:0]const u8, flags: u32) usize {
    return syscall2(.umount2, @intFromPtr(special), flags);
}

pub fn pivot_root(new_root: [*:0]const u8, put_old: [*:0]const u8) usize {
    return syscall2(.pivot_root, @intFromPtr(new_root), @intFromPtr(put_old));
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: MAP, fd: i32, offset: i64) usize {
    if (@hasField(SYS, "mmap2")) {
        return syscall6(
            .mmap2,
            @intFromPtr(address),
            length,
            prot,
            @as(u32, @bitCast(flags)),
            @bitCast(@as(isize, fd)),
            @truncate(@as(u64, @bitCast(offset)) / std.heap.pageSize()),
        );
    } else {
        // The s390x mmap() syscall existed before Linux supported syscalls with 5+ parameters, so
        // it takes a single pointer to an array of arguments instead.
        return if (native_arch == .s390x) syscall1(
            .mmap,
            @intFromPtr(&[_]usize{
                @intFromPtr(address),
                length,
                prot,
                @as(u32, @bitCast(flags)),
                @bitCast(@as(isize, fd)),
                @as(u64, @bitCast(offset)),
            }),
        ) else syscall6(
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

pub fn mremap(old_addr: ?[*]const u8, old_len: usize, new_len: usize, flags: MREMAP, new_addr: ?[*]const u8) usize {
    return syscall5(
        .mremap,
        @intFromPtr(old_addr),
        old_len,
        new_len,
        @as(u32, @bitCast(flags)),
        @intFromPtr(new_addr),
    );
}

pub const MSF = struct {
    pub const ASYNC = 1;
    pub const INVALIDATE = 2;
    pub const SYNC = 4;
};

/// Can only be called on 64 bit systems.
pub fn mseal(address: [*]const u8, length: usize, flags: usize) usize {
    return syscall3(.mseal, @intFromPtr(address), length, flags);
}

pub fn msync(address: [*]const u8, length: usize, flags: i32) usize {
    return syscall3(.msync, @intFromPtr(address), length, @as(u32, @bitCast(flags)));
}

pub fn munmap(address: [*]const u8, length: usize) usize {
    return syscall2(.munmap, @intFromPtr(address), length);
}

pub fn mlock(address: [*]const u8, length: usize) usize {
    return syscall2(.mlock, @intFromPtr(address), length);
}

pub fn munlock(address: [*]const u8, length: usize) usize {
    return syscall2(.munlock, @intFromPtr(address), length);
}

pub const MLOCK = packed struct(u32) {
    ONFAULT: bool = false,
    _1: u31 = 0,
};

pub fn mlock2(address: [*]const u8, length: usize, flags: MLOCK) usize {
    return syscall3(.mlock2, @intFromPtr(address), length, @as(u32, @bitCast(flags)));
}

pub const MCL = if (native_arch.isSPARC() or native_arch.isPowerPC()) packed struct(u32) {
    _0: u13 = 0,
    CURRENT: bool = false,
    FUTURE: bool = false,
    ONFAULT: bool = false,
    _4: u16 = 0,
} else packed struct(u32) {
    CURRENT: bool = false,
    FUTURE: bool = false,
    ONFAULT: bool = false,
    _3: u29 = 0,
};

pub fn mlockall(flags: MCL) usize {
    return syscall1(.mlockall, @as(u32, @bitCast(flags)));
}

pub fn munlockall() usize {
    return syscall0(.munlockall);
}

pub fn poll(fds: [*]pollfd, n: nfds_t, timeout: i32) usize {
    return if (@hasField(SYS, "poll"))
        return syscall3(.poll, @intFromPtr(fds), n, @as(u32, @bitCast(timeout)))
    else
        ppoll(
            fds,
            n,
            if (timeout >= 0)
                @constCast(&timespec{
                    .sec = @divTrunc(timeout, 1000),
                    .nsec = @rem(timeout, 1000) * 1000000,
                })
            else
                null,
            null,
        );
}

pub fn ppoll(fds: [*]pollfd, n: nfds_t, timeout: ?*timespec, sigmask: ?*const sigset_t) usize {
    return syscall5(
        if (@hasField(SYS, "ppoll") and native_arch != .hexagon) .ppoll else .ppoll_time64,
        @intFromPtr(fds),
        n,
        @intFromPtr(timeout),
        @intFromPtr(sigmask),
        NSIG / 8,
    );
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
        return syscall3(.unlinkat, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(path), @as(u32, @bitCast(At{ .removedir_or_handle_fid = .{ .removedir = true } })));
    }
}

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasField(SYS, "symlink")) {
        return syscall2(.symlink, @intFromPtr(existing), @intFromPtr(new));
    } else {
        return syscall3(.symlinkat, @intFromPtr(existing), @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(new));
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
        return faccessat(At.fdcwd, path, mode, 0);
    }
}

pub fn faccessat(dirfd: i32, path: [*:0]const u8, mode: u32, flags: u32) usize {
    if (flags == 0) {
        return syscall3(.faccessat, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode);
    }
    return syscall4(.faccessat2, @as(usize, @bitCast(@as(isize, dirfd))), @intFromPtr(path), mode, flags);
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

pub fn pipe2(fd: *[2]i32, flags: Pipe2) usize {
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
        return syscall4(.renameat, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(old), @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(new));
    } else {
        return syscall5(.renameat2, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(old), @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(new), 0);
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
            @bitCast(@as(isize, At.fdcwd)),
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
    // dirfd could be negative, for example At.fdcwd is -100
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
        return fchmodat(At.fdcwd, path, mode, 0);
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
        .llseek,
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

pub fn kill(pid: pid_t, sig: SIG) usize {
    return syscall2(.kill, @as(usize, @bitCast(@as(isize, pid))), @intFromEnum(sig));
}

pub fn tkill(tid: pid_t, sig: SIG) usize {
    return syscall2(.tkill, @as(usize, @bitCast(@as(isize, tid))), @intFromEnum(sig));
}

pub fn tgkill(tgid: pid_t, tid: pid_t, sig: SIG) usize {
    return syscall3(.tgkill, @as(usize, @bitCast(@as(isize, tgid))), @as(usize, @bitCast(@as(isize, tid))), @intFromEnum(sig));
}

pub fn link(oldpath: [*:0]const u8, newpath: [*:0]const u8) usize {
    if (@hasField(SYS, "link")) {
        return syscall2(
            .link,
            @intFromPtr(oldpath),
            @intFromPtr(newpath),
        );
    } else {
        return syscall5(
            .linkat,
            @as(usize, @bitCast(@as(isize, At.fdcwd))),
            @intFromPtr(oldpath),
            @as(usize, @bitCast(@as(isize, At.fdcwd))),
            @intFromPtr(newpath),
            0,
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
        return syscall3(.unlinkat, @as(usize, @bitCast(@as(isize, At.fdcwd))), @intFromPtr(path), 0);
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

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const GETLK = GET_SET_LK.GETLK;
    pub const SETLK = GET_SET_LK.SETLK;
    pub const SETLKW = GET_SET_LK.SETLKW;

    const GET_SET_LK = if (@sizeOf(usize) == 64) extern struct {
        pub const GETLK = if (is_mips) 14 else if (is_sparc) 7 else 5;
        pub const SETLK = if (is_mips) 6 else if (is_sparc) 8 else 6;
        pub const SETLKW = if (is_mips) 7 else if (is_sparc) 9 else 7;
    } else extern struct {
        // Ensure that 32-bit code uses the large-file variants (GETLK64, etc).

        pub const GETLK = if (is_mips) 33 else 12;
        pub const SETLK = if (is_mips) 34 else 13;
        pub const SETLKW = if (is_mips) 35 else 14;
    };

    pub const SETOWN = if (is_mips) 24 else if (is_sparc) 6 else 8;
    pub const GETOWN = if (is_mips) 23 else if (is_sparc) 5 else 9;

    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;

    pub const OFD_GETLK = 36;
    pub const OFD_SETLK = 37;
    pub const OFD_SETLKW = 38;

    pub const RDLCK = if (is_sparc) 1 else 0;
    pub const WRLCK = if (is_sparc) 2 else 1;
    pub const UNLCK = if (is_sparc) 3 else 2;
};

pub const F_OWNER = enum(i32) {
    TID = 0,
    PID = 1,
    PGRP = 2,
    _,
};

pub const f_owner_ex = extern struct {
    type: F_OWNER,
    pid: pid_t,
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
    _unused: if (is_sparc) i16 else void,
};

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) usize {
    if (@hasField(SYS, "fcntl64")) {
        return syscall3(.fcntl64, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, cmd))), arg);
    } else {
        return syscall3(.fcntl, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, cmd))), arg);
    }
}

pub fn flock(fd: fd_t, operation: i32) usize {
    return syscall2(.flock, @as(usize, @bitCast(@as(isize, fd))), @as(usize, @bitCast(@as(isize, operation))));
}

pub const Elf_Symndx = if (native_arch == .s390x) u64 else u32;

// We must follow the C calling convention when we call into the VDSO
const VdsoClockGettime = *align(1) const fn (clockid_t, *timespec) callconv(.c) usize;
var vdso_clock_gettime: ?VdsoClockGettime = &init_vdso_clock_gettime;

pub fn clock_gettime(clk_id: clockid_t, tp: *timespec) usize {
    if (VDSO != void) {
        const ptr = @atomicLoad(?VdsoClockGettime, &vdso_clock_gettime, .unordered);
        if (ptr) |f| {
            const rc = f(clk_id, tp);
            switch (rc) {
                0, @as(usize, @bitCast(-@as(isize, @intFromEnum(E.INVAL)))) => return rc,
                else => {},
            }
        }
    }
    return syscall2(
        if (@hasField(SYS, "clock_gettime") and native_arch != .hexagon) .clock_gettime else .clock_gettime64,
        @intFromEnum(clk_id),
        @intFromPtr(tp),
    );
}

fn init_vdso_clock_gettime(clk: clockid_t, ts: *timespec) callconv(.c) usize {
    const ptr: ?VdsoClockGettime = @ptrFromInt(vdso.lookup(VDSO.CGT_VER, VDSO.CGT_SYM));
    // Note that we may not have a VDSO at all, update the stub address anyway
    // so that clock_gettime will fall back on the good old (and slow) syscall
    @atomicStore(?VdsoClockGettime, &vdso_clock_gettime, ptr, .monotonic);
    // Call into the VDSO if available
    if (ptr) |f| return f(clk, ts);
    return @as(usize, @bitCast(-@as(isize, @intFromEnum(E.NOSYS))));
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return syscall2(
        if (@hasField(SYS, "clock_getres") and native_arch != .hexagon) .clock_getres else .clock_getres_time64,
        @as(usize, @bitCast(@as(isize, clk_id))),
        @intFromPtr(tp),
    );
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(
        if (@hasField(SYS, "clock_settime") and native_arch != .hexagon) .clock_settime else .clock_settime64,
        @as(usize, @bitCast(@as(isize, clk_id))),
        @intFromPtr(tp),
    );
}

pub fn clock_nanosleep(clockid: clockid_t, flags: TIMER, request: *const timespec, remain: ?*timespec) usize {
    return syscall4(
        if (@hasField(SYS, "clock_nanosleep") and native_arch != .hexagon) .clock_nanosleep else .clock_nanosleep_time64,
        @intFromEnum(clockid),
        @as(u32, @bitCast(flags)),
        @intFromPtr(request),
        @intFromPtr(remain),
    );
}

pub fn gettimeofday(tv: ?*timeval, tz: ?*timezone) usize {
    return syscall2(.gettimeofday, @intFromPtr(tv), @intFromPtr(tz));
}

pub fn settimeofday(tv: *const timeval, tz: *const timezone) usize {
    return syscall2(.settimeofday, @intFromPtr(tv), @intFromPtr(tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    if (native_arch == .riscv32) {
        @compileError("No nanosleep syscall on this architecture.");
    } else return syscall2(.nanosleep, @intFromPtr(req), @intFromPtr(rem));
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
    comptime assert(@typeInfo(uid_t) == .int and @typeInfo(uid_t).int.signedness == .unsigned);
    return setresuid(maxInt(uid_t), euid, maxInt(uid_t));
}

pub fn setegid(egid: gid_t) usize {
    // We use setresgid here instead of setregid to ensure that the saved uid
    // is not changed. This is what musl and recent glibc versions do as well.
    //
    // The setresgid(2) man page says that if -1 is passed the corresponding
    // id will not be changed. Since gid_t is unsigned, this wraps around to the
    // max value in C.
    comptime assert(@typeInfo(uid_t) == .int and @typeInfo(uid_t).int.signedness == .unsigned);
    return setresgid(maxInt(gid_t), egid, maxInt(gid_t));
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

pub fn setpgid(pid: pid_t, pgid: pid_t) usize {
    return syscall2(.setpgid, @intCast(pid), @intCast(pgid));
}

pub fn getgroups(size: usize, list: ?*gid_t) usize {
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

pub fn setsid() usize {
    return syscall0(.setsid);
}

pub fn getpid() pid_t {
    // Casts result to a pid_t, safety-checking >= 0, because getpid() cannot fail
    return @intCast(@as(u32, @truncate(syscall0(.getpid))));
}

pub fn getppid() pid_t {
    // Casts result to a pid_t, safety-checking >= 0, because getppid() cannot fail
    return @intCast(@as(u32, @truncate(syscall0(.getppid))));
}

pub fn gettid() pid_t {
    // Casts result to a pid_t, safety-checking >= 0, because gettid() cannot fail
    return @intCast(@as(u32, @truncate(syscall0(.gettid))));
}

pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) usize {
    return syscall4(.rt_sigprocmask, flags, @intFromPtr(set), @intFromPtr(oldset), NSIG / 8);
}

pub fn sigaction(sig: SIG, noalias act: ?*const Sigaction, noalias oact: ?*Sigaction) usize {
    assert(@intFromEnum(sig) > 0);
    assert(@intFromEnum(sig) < NSIG);
    assert(sig != .KILL);
    assert(sig != .STOP);

    var ksa: k_sigaction = undefined;
    var oldksa: k_sigaction = undefined;
    const mask_size = @sizeOf(@TypeOf(ksa.mask));

    if (act) |new| {
        if (native_arch == .hexagon or is_loongarch or is_mips or native_arch == .or1k or is_riscv) {
            ksa = .{
                .handler = new.handler.handler,
                .flags = new.flags,
                .mask = new.mask,
            };
        } else {
            // Zig needs to install our arch restorer function with any signal handler, so
            // must copy the Sigaction struct
            const restorer_fn = if ((new.flags & SA.SIGINFO) != 0) &restore_rt else &restore;
            ksa = .{
                .handler = new.handler.handler,
                .flags = new.flags | SA.RESTORER,
                .mask = new.mask,
                .restorer = @ptrCast(restorer_fn),
            };
        }
    }

    const ksa_arg = if (act != null) @intFromPtr(&ksa) else 0;
    const oldksa_arg = if (oact != null) @intFromPtr(&oldksa) else 0;

    const result = switch (native_arch) {
        // The sparc version of rt_sigaction needs the restorer function to be passed as an argument too.
        .sparc, .sparc64 => syscall5(.rt_sigaction, @intFromEnum(sig), ksa_arg, oldksa_arg, @intFromPtr(ksa.restorer), mask_size),
        else => syscall4(.rt_sigaction, @intFromEnum(sig), ksa_arg, oldksa_arg, mask_size),
    };
    if (errno(result) != .SUCCESS) return result;

    if (oact) |old| {
        old.handler.handler = oldksa.handler;
        old.flags = oldksa.flags;
        old.mask = oldksa.mask;
    }

    return 0;
}

const usize_bits = @typeInfo(usize).int.bits;

/// Defined as one greater than the largest defined signal number.
pub const NSIG = if (is_mips) 128 else 65;

/// Linux kernel's sigset_t.  This is logically 64-bit on most
/// architectures, but 128-bit on MIPS.  Contrast with the 1024-bit
/// sigset_t exported by the glibc and musl library ABIs.
pub const sigset_t = [(NSIG - 1 + 7) / @bitSizeOf(SigsetElement)]SigsetElement;

const SigsetElement = c_ulong;

const sigset_len = @typeInfo(sigset_t).array.len;

/// Zig's SIGRTMIN, but is a function for compatibility with glibc
pub fn sigrtmin() u8 {
    // Default is 32 in the kernel UAPI: https://github.com/torvalds/linux/blob/78109c591b806e41987e0b83390e61d675d1f724/include/uapi/asm-generic/signal.h#L50
    // AFAICT, all architectures that override this also set it to 32:
    // https://github.com/search?q=repo%3Atorvalds%2Flinux+sigrtmin+path%3Auapi&type=code
    return 32;
}

/// Zig's SIGRTMAX, but is a function for compatibility with glibc
pub fn sigrtmax() u8 {
    return NSIG - 1;
}

/// Zig's version of sigemptyset.  Returns initialized sigset_t.
pub fn sigemptyset() sigset_t {
    return [_]SigsetElement{0} ** sigset_len;
}

/// Zig's version of sigfillset.  Returns initalized sigset_t.
pub fn sigfillset() sigset_t {
    return [_]SigsetElement{~@as(SigsetElement, 0)} ** sigset_len;
}

fn sigset_bit_index(sig: SIG) struct { word: usize, mask: SigsetElement } {
    assert(@intFromEnum(sig) > 0);
    assert(@intFromEnum(sig) < NSIG);
    const bit = @intFromEnum(sig) - 1;
    return .{
        .word = bit / @bitSizeOf(SigsetElement),
        .mask = @as(SigsetElement, 1) << @truncate(bit % @bitSizeOf(SigsetElement)),
    };
}

pub fn sigaddset(set: *sigset_t, sig: SIG) void {
    const index = sigset_bit_index(sig);
    (set.*)[index.word] |= index.mask;
}

pub fn sigdelset(set: *sigset_t, sig: SIG) void {
    const index = sigset_bit_index(sig);
    (set.*)[index.word] ^= index.mask;
}

pub fn sigismember(set: *const sigset_t, sig: SIG) bool {
    const index = sigset_bit_index(sig);
    return ((set.*)[index.word] & index.mask) != 0;
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

pub fn sendmmsg(fd: i32, msgvec: [*]mmsghdr, vlen: u32, flags: u32) usize {
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

pub fn recvmmsg(fd: i32, msgvec: ?[*]mmsghdr, vlen: u32, flags: u32, timeout: ?*timespec) usize {
    return syscall5(
        if (@hasField(SYS, "recvmmsg") and native_arch != .hexagon) .recvmmsg else .recvmmsg_time64,
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(msgvec),
        vlen,
        flags,
        @intFromPtr(timeout),
    );
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

pub fn socketpair(domain: u32, socket_type: u32, protocol: u32, fd: *[2]i32) usize {
    if (native_arch == .x86) {
        return socketcall(SC.socketpair, &[4]usize{ domain, socket_type, protocol, @intFromPtr(fd) });
    }
    return syscall4(.socketpair, domain, socket_type, protocol, @intFromPtr(fd));
}

pub fn accept(fd: i32, noalias addr: ?*sockaddr, noalias len: ?*socklen_t) usize {
    if (native_arch == .x86) {
        return socketcall(SC.accept, &[4]usize{ @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(addr), @intFromPtr(len), 0 });
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
    if (native_arch == .riscv32 or native_arch.isLoongArch()) {
        // riscv32 and loongarch have made the interesting decision to not implement some of
        // the older stat syscalls, including this one.
        @compileError("No fstat syscall on this architecture.");
    } else if (@hasField(SYS, "fstat64")) {
        return syscall2(.fstat64, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(stat_buf));
    } else {
        return syscall2(.fstat, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(stat_buf));
    }
}

pub fn stat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (native_arch == .riscv32 or native_arch.isLoongArch()) {
        // riscv32 and loongarch have made the interesting decision to not implement some of
        // the older stat syscalls, including this one.
        @compileError("No stat syscall on this architecture.");
    } else if (@hasField(SYS, "stat64")) {
        return syscall2(.stat64, @intFromPtr(pathname), @intFromPtr(statbuf));
    } else {
        return syscall2(.stat, @intFromPtr(pathname), @intFromPtr(statbuf));
    }
}

pub fn lstat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (native_arch == .riscv32 or native_arch.isLoongArch()) {
        // riscv32 and loongarch have made the interesting decision to not implement some of
        // the older stat syscalls, including this one.
        @compileError("No lstat syscall on this architecture.");
    } else if (@hasField(SYS, "lstat64")) {
        return syscall2(.lstat64, @intFromPtr(pathname), @intFromPtr(statbuf));
    } else {
        return syscall2(.lstat, @intFromPtr(pathname), @intFromPtr(statbuf));
    }
}

pub fn fstatat(dirfd: i32, path: [*:0]const u8, stat_buf: *Stat, flags: At) usize {
    if (native_arch == .riscv32 or native_arch.isLoongArch()) {
        // riscv32 and loongarch have made the interesting decision to not implement some of
        // the older stat syscalls, including this one.
        @compileError("No fstatat syscall on this architecture.");
    } else if (@hasField(SYS, "fstatat64")) {
        return syscall4(
            .fstatat64,
            @as(usize, @bitCast(@as(isize, dirfd))),
            @intFromPtr(path),
            @intFromPtr(stat_buf),
            @intCast(@as(u32, @bitCast(flags))),
        );
    } else {
        return syscall4(
            .fstatat,
            @as(usize, @bitCast(@as(isize, dirfd))),
            @intFromPtr(path),
            @intFromPtr(stat_buf),
            @bitCast(flags),
        );
    }
}

pub fn statx(dirfd: i32, path: [*:0]const u8, flags: At, mask: Statx.Mask, statx_buf: *Statx) usize {
    return syscall5(
        .statx,
        @as(usize, @bitCast(@as(isize, dirfd))),
        @intFromPtr(path),
        @intCast(@as(u32, @bitCast(flags))),
        @intCast(@as(u32, @bitCast(mask))),
        @intFromPtr(statx_buf),
    );
}

pub fn listxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(.listxattr, @intFromPtr(path), @intFromPtr(list), size);
}

pub fn llistxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(.llistxattr, @intFromPtr(path), @intFromPtr(list), size);
}

pub fn flistxattr(fd: fd_t, list: [*]u8, size: usize) usize {
    return syscall3(.flistxattr, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(list), size);
}

pub fn getxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.getxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size);
}

pub fn lgetxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.lgetxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size);
}

pub fn fgetxattr(fd: fd_t, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.fgetxattr, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(name), @intFromPtr(value), size);
}

pub fn setxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]const u8, size: usize, flags: usize) usize {
    return syscall5(.setxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size, flags);
}

pub fn lsetxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]const u8, size: usize, flags: usize) usize {
    return syscall5(.lsetxattr, @intFromPtr(path), @intFromPtr(name), @intFromPtr(value), size, flags);
}

pub fn fsetxattr(fd: fd_t, name: [*:0]const u8, value: [*]const u8, size: usize, flags: usize) usize {
    return syscall5(.fsetxattr, @as(usize, @bitCast(@as(isize, fd))), @intFromPtr(name), @intFromPtr(value), size, flags);
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

pub const sched_param = extern struct {
    priority: i32,
};

pub const SCHED = packed struct(i32) {
    pub const Mode = enum(u3) {
        /// normal multi-user scheduling
        NORMAL = 0,
        /// FIFO realtime scheduling
        FIFO = 1,
        /// Round-robin realtime scheduling
        RR = 2,
        /// For "batch" style execution of processes
        BATCH = 3,
        /// Low latency scheduling
        IDLE = 5,
        /// Sporadic task model deadline scheduling
        DEADLINE = 6,
    };
    mode: Mode, //bits [0, 2]
    _3: u27 = 0, //bits [3, 29]
    /// set to true to stop children from inheriting policies
    RESET_ON_FORK: bool = false, //bit 30
    _31: u1 = 0, //bit 31
};

pub fn sched_setparam(pid: pid_t, param: *const sched_param) usize {
    return syscall2(.sched_setparam, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(param));
}

pub fn sched_getparam(pid: pid_t, param: *sched_param) usize {
    return syscall2(.sched_getparam, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(param));
}

pub fn sched_setscheduler(pid: pid_t, policy: SCHED, param: *const sched_param) usize {
    return syscall3(.sched_setscheduler, @as(usize, @bitCast(@as(isize, pid))), @intCast(@as(u32, @bitCast(policy))), @intFromPtr(param));
}

pub fn sched_getscheduler(pid: pid_t) usize {
    return syscall1(.sched_getscheduler, @as(usize, @bitCast(@as(isize, pid))));
}

pub fn sched_get_priority_max(policy: SCHED) usize {
    return syscall1(.sched_get_priority_max, @intCast(@as(u32, @bitCast(policy))));
}

pub fn sched_get_priority_min(policy: SCHED) usize {
    return syscall1(.sched_get_priority_min, @intCast(@as(u32, @bitCast(policy))));
}

pub fn getcpu(cpu: ?*usize, node: ?*usize) usize {
    return syscall2(.getcpu, @intFromPtr(cpu), @intFromPtr(node));
}

pub const sched_attr = extern struct {
    size: u32 = 48, // Size of this structure
    policy: u32 = 0, // Policy (SCHED_*)
    flags: u64 = 0, // Flags
    nice: u32 = 0, // Nice value (SCHED_OTHER, SCHED_BATCH)
    priority: u32 = 0, // Static priority (SCHED_FIFO, SCHED_RR)
    // Remaining fields are for SCHED_DEADLINE
    runtime: u64 = 0,
    deadline: u64 = 0,
    period: u64 = 0,
};

pub fn sched_setattr(pid: pid_t, attr: *const sched_attr, flags: usize) usize {
    return syscall3(.sched_setattr, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(attr), flags);
}

pub fn sched_getattr(pid: pid_t, attr: *sched_attr, size: usize, flags: usize) usize {
    return syscall4(.sched_getattr, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(attr), size, flags);
}

pub fn sched_rr_get_interval(pid: pid_t, tp: *timespec) usize {
    return syscall2(.sched_rr_get_interval, @as(usize, @bitCast(@as(isize, pid))), @intFromPtr(tp));
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

    switch (errno(rc)) {
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

pub fn epoll_ctl(epoll_fd: i32, op: EpollOp, fd: i32, ev: ?*epoll_event) usize {
    return syscall4(
        .epoll_ctl,
        @as(usize, @bitCast(@as(isize, epoll_fd))),
        @as(usize, @intFromEnum(op)),
        @as(usize, @bitCast(@as(isize, fd))),
        @intFromPtr(ev),
    );
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
        NSIG / 8,
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(.eventfd2, count, flags);
}

pub fn timerfd_create(clockid: timerfd_clockid_t, flags: TFD) usize {
    return syscall2(
        .timerfd_create,
        @intFromEnum(clockid),
        @as(u32, @bitCast(flags)),
    );
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(
        if (@hasField(SYS, "timerfd_gettime") and native_arch != .hexagon) .timerfd_gettime else .timerfd_gettime64,
        @bitCast(@as(isize, fd)),
        @intFromPtr(curr_value),
    );
}

pub fn timerfd_settime(fd: i32, flags: TFD.TIMER, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(
        if (@hasField(SYS, "timerfd_settime") and native_arch != .hexagon) .timerfd_settime else .timerfd_settime64,
        @bitCast(@as(isize, fd)),
        @as(u32, @bitCast(flags)),
        @intFromPtr(new_value),
        @intFromPtr(old_value),
    );
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

pub fn setns(fd: fd_t, flags: u32) usize {
    return syscall2(.setns, fd, flags);
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

pub fn io_uring_setup(entries: u32, p: *IoUring.Params) usize {
    return syscall2(.io_uring_setup, entries, @intFromPtr(p));
}

pub fn io_uring_enter(fd: i32, to_submit: u32, min_complete: u32, flags: IoUring.uflags.Enter, sig: ?*sigset_t) usize {
    return syscall6(.io_uring_enter, @as(usize, @bitCast(@as(isize, fd))), to_submit, min_complete, @intCast(@as(u32, @bitCast(flags))), @intFromPtr(sig), NSIG / 8);
}

pub fn io_uring_register(fd: i32, opcode: IoUring.RegisterOp, arg: ?*const anyopaque, nr_args: u32) usize {
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

pub fn pidfd_send_signal(pidfd: fd_t, sig: SIG, info: ?*siginfo_t, flags: u32) usize {
    return syscall4(
        .pidfd_send_signal,
        @as(usize, @bitCast(@as(isize, pidfd))),
        @intFromEnum(sig),
        @intFromPtr(info),
        flags,
    );
}

pub fn process_vm_readv(pid: pid_t, local: []const iovec, remote: []const iovec_const, flags: usize) usize {
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
    if (comptime native_arch.isArm() or native_arch == .hexagon or native_arch.isPowerPC32()) {
        // These architectures reorder the arguments so that a register is not skipped to align the
        // register number that `offset` is passed in.

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
    } else if (native_arch.isMIPS32()) {
        // MIPS O32 does not deal with the register alignment issue, so pass a dummy value.

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
    } else if (comptime usize_bits < 64) {
        // Other 32-bit architectures do not require register alignment.

        const offset_halves = splitValue64(offset);
        const length_halves = splitValue64(len);

        return syscall6(
            switch (builtin.abi) {
                .gnuabin32, .gnux32, .muslabin32, .muslx32 => .fadvise64,
                else => .fadvise64_64,
            },
            @as(usize, @bitCast(@as(isize, fd))),
            offset_halves[0],
            offset_halves[1],
            length_halves[0],
            length_halves[1],
            advice,
        );
    } else {
        // On 64-bit architectures, fadvise64_64 and fadvise64 are the same. Generally, older ports
        // call it fadvise64 (x86, PowerPC, etc), while newer ports call it fadvise64_64 (RISC-V,
        // LoongArch, etc). SPARC is the odd one out because it has both.
        return syscall4(
            if (@hasField(SYS, "fadvise64_64")) .fadvise64_64 else .fadvise64,
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

pub const Sysinfo = switch (native_abi) {
    .gnux32, .muslx32 => extern struct {
        /// Seconds since boot
        uptime: i64,
        /// 1, 5, and 15 minute load averages
        loads: [3]u64,
        /// Total usable main memory size
        totalram: u64,
        /// Available memory size
        freeram: u64,
        /// Amount of shared memory
        sharedram: u64,
        /// Memory used by buffers
        bufferram: u64,
        /// Total swap space size
        totalswap: u64,
        /// swap space still available
        freeswap: u64,
        /// Number of current processes
        procs: u16,
        /// Explicit padding for m68k
        pad: u16,
        /// Total high memory size
        totalhigh: u64,
        /// Available high memory size
        freehigh: u64,
        /// Memory unit size in bytes
        mem_unit: u32,
    },
    else => extern struct {
        /// Seconds since boot
        uptime: isize,
        /// 1, 5, and 15 minute load averages
        loads: [3]usize,
        /// Total usable main memory size
        totalram: usize,
        /// Available memory size
        freeram: usize,
        /// Amount of shared memory
        sharedram: usize,
        /// Memory used by buffers
        bufferram: usize,
        /// Total swap space size
        totalswap: usize,
        /// swap space still available
        freeswap: usize,
        /// Number of current processes
        procs: u16,
        /// Explicit padding for m68k
        pad: u16,
        /// Total high memory size
        totalhigh: usize,
        /// Available high memory size
        freehigh: usize,
        /// Memory unit size in bytes
        mem_unit: u32,
        /// Pad
        _f: [20 - 2 * @sizeOf(usize) - @sizeOf(u32)]u8,
    },
};

pub fn sysinfo(info: *Sysinfo) usize {
    return syscall1(.sysinfo, @intFromPtr(info));
}

pub const E = switch (native_arch) {
    .mips, .mipsel, .mips64, .mips64el => enum(u16) {
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
    },
    .sparc, .sparc64 => enum(u16) {
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

/// Deprecated alias to At
pub const AT = At;
/// matches AT_* and AT_STATX_*
pub const At = packed struct(u32) {
    _u1: u8 = 0,
    /// Do not follow symbolic links
    symlink_nofollow: bool = false,
    /// Remove directory instead of unlinking file
    removedir: bool = false,
    /// Follow symbolic links.
    symlink_follow: bool = false,
    /// Suppress terminal automount traversal
    no_automount: bool = false,
    /// Allow empty relative pathname
    empty_path: bool = false,
    /// Force the attributes to be sync'd with the server
    statx_force_sync: bool = false,
    /// Don't sync attributes with the server
    statx_dont_sync: bool = false,
    /// Apply to the entire subtree
    recursive: bool = false,
    _17: u16 = 0,

    /// File handle is needed to compare object identity and may not be usable
    /// with open_by_handle_at(2)
    pub const handle_fid: At = .{ .removedir = true };

    /// Special value used to indicate openat should use the current working directory
    pub const fdcwd = -100;

    // https://github.com/torvalds/linux/blob/d3479214c05dbd07bc56f8823e7bd8719fcd39a9/tools/perf/trace/beauty/fs_at_flags.sh#L15
    /// AT_STATX_SYNC_TYPE is not a bit, its a mask of
    /// AT_STATX_SYNC_AS_STAT, AT_STATX_FORCE_SYNC and AT_STATX_DONT_SYNC
    /// Type of synchronisation required from statx()
    pub const statx_sync_type = 0x6000;

    /// Do whatever stat() does
    /// This is the default and is very much filesystem-specific
    pub const statx_sync_as_stat: At = .{};

    // DEPRECATED ALIASES
    //
    //
    /// Special value used to indicate openat should use the current working directory
    pub const FDCWD = fdcwd;
    /// Do not follow symbolic links
    pub const SYMLINK_NOFOLLOW: u32 = @bitCast(At{ .symlink_nofollow = true });
    /// Remove directory instead of unlinking file
    pub const REMOVEDIR: u32 = @bitCast(At{ .removedir = true });
    pub const HANDLE_FID: u32 = @bitCast(handle_fid);
    /// Follow symbolic links.
    pub const SYMLINK_FOLLOW: u32 = @bitCast(At{ .symlink_follow = true });
    /// Suppress terminal automount traversal
    pub const NO_AUTOMOUNT: u32 = @bitCast(At{ .no_automount = true });
    /// Allow empty relative pathname
    pub const EMPTY_PATH: u32 = @bitCast(At{ .empty_path = true });
    /// Type of synchronisation required from statx()
    pub const STATX_SYNC_TYPE: u32 = @bitCast(statx_sync_type);
    /// - Do whatever stat() does
    pub const STATX_SYNC_AS_STAT: u32 = @bitCast(statx_sync_as_stat);
    /// - Force the attributes to be sync'd with the server
    pub const STATX_FORCE_SYNC: u32 = @bitCast(At{ .statx_force_sync = true });
    /// - Don't sync attributes with the server
    pub const STATX_DONT_SYNC: u32 = @bitCast(At{ .statx_dont_sync = true });
    /// Apply to the entire subtree
    pub const RECURSIVE: u32 = @bitCast(At{ .recursive = true });
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

// Futex v1 API commands.  See futex man page for each command's
// interpretation of the futex arguments.
pub const FUTEX_COMMAND = enum(u7) {
    WAIT = 0,
    WAKE = 1,
    FD = 2,
    REQUEUE = 3,
    CMP_REQUEUE = 4,
    WAKE_OP = 5,
    LOCK_PI = 6,
    UNLOCK_PI = 7,
    TRYLOCK_PI = 8,
    WAIT_BITSET = 9,
    WAKE_BITSET = 10,
    WAIT_REQUEUE_PI = 11,
    CMP_REQUEUE_PI = 12,
};

/// Futex v1 API command and flags for the `futex_op` parameter
pub const FUTEX_OP = packed struct(u32) {
    cmd: FUTEX_COMMAND,
    private: bool,
    realtime: bool = false, // realtime clock vs. monotonic clock
    _reserved: u23 = 0,
};

/// Futex v1 FUTEX_WAKE_OP `val3` operation:
pub const FUTEX_WAKE_OP = packed struct(u32) {
    cmd: FUTEX_WAKE_OP_CMD,
    /// From C API `FUTEX_OP_ARG_SHIFT`:  Use (1 << oparg) as operand
    arg_shift: bool = false,
    cmp: FUTEX_WAKE_OP_CMP,
    oparg: u12,
    cmdarg: u12,
};

/// Futex v1 cmd for FUTEX_WAKE_OP `val3` command.
pub const FUTEX_WAKE_OP_CMD = enum(u3) {
    /// uaddr2 = oparg
    SET = 0,
    /// uaddr2 += oparg
    ADD = 1,
    /// uaddr2 |= oparg
    OR = 2,
    /// uaddr2 &= ~oparg
    ANDN = 3,
    /// uaddr2 ^= oparg
    XOR = 4,
};

/// Futex v1 comparison op for FUTEX_WAKE_OP `val3` cmp
pub const FUTEX_WAKE_OP_CMP = enum(u4) {
    EQ = 0,
    NE = 1,
    LT = 2,
    LE = 3,
    GT = 4,
    GE = 5,
};

pub const Futex2 = struct {
    /// Max numbers of elements in a `futex_waitv` .ie `WaitOne` array
    /// matches FUTEX_WAITV_MAX
    pub const waitone_max = 128;

    /// For futex v2 API, the size of the futex at the uaddr.  v1 futex are
    /// always implicitly U32.  As of kernel v6.14, only U32 is implemented
    /// for v2 futexes.
    pub const Size = enum(u2) {
        U8 = 0,
        U16 = 1,
        U32 = 2,
        U64 = 3,
    };

    /// flags for `futex2_requeue` syscall
    /// As of kernel 6.14 there are no defined flags to futex2_requeue.
    pub const Requeue = packed struct(u32) {
        _: u32 = 0,
    };

    /// flags for `futex2_waitv` syscall
    /// As of kernel 6.14 there are no defined flags to futex2_waitv.
    pub const Waitv = packed struct(u32) {
        _: u32 = 0,
    };

    /// flags for `futex2_wait` syscall
    // COMMIT: add mpol and fix private field as its 128 not 32
    pub const Wait = packed struct(u32) {
        size: Size,
        numa: bool = false,
        mpol: bool = false,
        _5: u3 = 0,
        private: bool,
        _9: u24 = 0,
    };

    /// flags for `futex2_wake` syscall
    pub const Wake = Wait;

    /// A waiter for vectorized wait
    /// For `futex2_waitv` and `futex2_requeue`. Arrays of `WaitOne`
    /// allow waiting on multiple futexes in one call.
    /// matches `futex_waitv` in kernel
    pub const WaitOne = extern struct {
        /// Expected value at uaddr, should match size of futex.
        val: u64,
        /// User address to wait on.  Top-bits must be 0 on 32-bit.
        uaddr: u64,
        /// Flags for this waiter.
        flags: Wait,
        /// Reserved member to preserve data alignment.
        __reserved: u32 = 0,
    };

    /// `Bitset` for `futex2_wait`, `futex2_wake`, `IoUring.futex_wait` and
    /// `IoUring.futex_wake` operations
    /// At least one bit must be set before performing supported operations
    /// The bitset is stored in the kernel-internal state of a waiter. During a
    /// wake operation, the same mask previously set during the wait call can
    /// be used to select which waiters to woke up
    /// See https://man7.org/linux/man-pages/man2/futex_wake_bitset.2const.html
    /// `IoUring` supports a u64 `Bitset` while the raw syscalls uses only u32
    /// bits of `Bitset`
    pub const Bitset = packed struct(u64) {
        waiter1: bool = false,
        waiter2: bool = false,
        waiter3: bool = false,
        waiter4: bool = false,
        waiter5: bool = false,
        waiter6: bool = false,
        waiter7: bool = false,
        waiter8: bool = false,
        waiter9: bool = false,
        waiter10: bool = false,
        waiter11: bool = false,
        waiter12: bool = false,
        waiter13: bool = false,
        waiter14: bool = false,
        waiter15: bool = false,
        waiter16: bool = false,
        waiter17: bool = false,
        waiter18: bool = false,
        waiter19: bool = false,
        waiter20: bool = false,
        waiter21: bool = false,
        waiter22: bool = false,
        waiter23: bool = false,
        waiter24: bool = false,
        waiter25: bool = false,
        waiter26: bool = false,
        waiter27: bool = false,
        waiter28: bool = false,
        waiter29: bool = false,
        waiter30: bool = false,
        waiter31: bool = false,
        waiter32: bool = false,
        io_uring_extra: u32 = 0,

        /// `Bitset` with all bits set for the FUTEX_xxx_BITSET OPs to request a
        /// match of any bit. matches FUTEX_BITSET_MATCH_ANY
        pub const match_any: Bitset = @bitCast(@as(u64, 0x0000_0000_ffff_ffff));
        /// An empty `Bitset` will not wake any threads because the kernel
        /// requires at least one bit to be set in the bitmask to identify
        /// which waiters should be woken up. Therefore, no action will be
        /// taken if the bitset is zero, this is only useful in test
        pub const empty: Bitset = .{};

        /// Create from raw u64 value
        pub fn fromInt(value: u64) Bitset {
            const bitset: Bitset = @bitCast(value);
            assert(bitset != empty);
            return bitset;
        }

        /// Convert to raw u64 for syscall
        pub fn toInt(self: Bitset) u64 {
            return @bitCast(self);
        }
    };
};

/// DEPRECATED use `Futex2.WaitOne`
pub const futex2_waitone = Futex2.WaitOne;

/// DEPRECATED use constant in `Futex2`
pub const FUTEX2_WAITONE_MAX = Futex2.waitone_max;

/// DEPRECATED use `Size` type in `Futex2`
pub const FUTEX2_SIZE = Futex2.Size;

/// DEPRECATED use `Waitv` in `Futex2`
pub const FUTEX2_FLAGS_WAITV = Futex2.Waitv;

/// DEPRECATED use `Requeue` in `Futex2`
pub const FUTEX2_FLAGS_REQUEUE = Futex2.Requeue;

/// DEPRECATED use `Wait` in `Futex2`
pub const FUTEX2_FLAGS = Futex2.Wait;

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
        .mips, .mipsel, .mips64, .mips64el, .xtensa, .xtensaeb => 0x10,
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

pub const W = packed struct(u32) {
    nohang: bool = false,
    stopped: bool = false,
    exited: bool = false,
    continued: bool = false,
    _5: u20 = 0,
    nowait: bool = false,
    _26: u7 = 0,
    /// alias to stopped
    pub const untraced: W = .{ .stopped = true };

    fn toInt(s: W) u32 {
        return @bitCast(s);
    }

    /// matches EXITSTATUS in C
    pub fn exitStatus(s: W) u8 {
        return @intCast((s.toInt() & 0xff00) >> 8);
    }

    /// matches TERMSIG in C
    pub fn termSig(s: W) u32 {
        return s.toInt() & 0x7f;
    }

    /// matches STOPSIG in C
    pub fn stopSig(s: W) u32 {
        return exitStatus(s);
    }

    /// matches IFEXITED in C
    pub fn ifExited(s: W) bool {
        return termSig(s) == 0;
    }

    /// matches IFSTOPPED in C
    pub fn ifStopped(s: W) bool {
        return @as(u16, @truncate(((s.toInt() & 0xffff) *% 0x10001) >> 8)) > 0x7f00;
    }

    /// matches IFSIGNALED in C
    pub fn ifSignaled(s: W) bool {
        return (s.toInt() & 0xffff) -% 1 < 0xff;
    }

    // Deprecated constants
    pub const NOHANG: u32 = @bitCast(W{ .nohang = true });
    pub const STOPPED: u32 = @bitCast(W{ .stopped = true });
    pub const UNTRACED: u32 = @bitCast(untraced);
    pub const EXITED: u32 = @bitCast(W{ .exited = true });
    pub const CONTINUED: u32 = @bitCast(W{ .continued = true });
    pub const NOWAIT: u32 = @bitCast(W{ .nowait = true });

    /// DEPRECATED alias to exitStatus
    pub fn EXITSTATUS(s: u32) u8 {
        return exitStatus(@bitCast(s));
    }

    /// DEPRECATED alias to termSig
    pub fn TERMSIG(s: u32) u32 {
        return termSig(@bitCast(s));
    }

    /// DEPRECATED alias to stopSig
    pub fn STOPSIG(s: u32) u32 {
        return stopSig(@bitCast(s));
    }

    /// DEPRECATED alias to ifExited
    pub fn IFEXITED(s: u32) bool {
        return ifExited(@bitCast(s));
    }

    /// DEPRECATED alias to ifStopped
    pub fn IFSTOPPED(s: u32) bool {
        return ifStopped(@bitCast(s));
    }

    /// DEPRECATED alias to ifSignaled
    pub fn IFSIGNALED(s: u32) bool {
        return ifSignaled(@bitCast(s));
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
} else if (is_sparc) struct {
    pub const NOCLDSTOP = 0x8;
    pub const NOCLDWAIT = 0x100;
    pub const SIGINFO = 0x200;
    pub const RESTART = 0x2;
    pub const RESETHAND = 0x4;
    pub const ONSTACK = 0x1;
    pub const NODEFER = 0x20;
    pub const RESTORER = 0x04000000;
} else if (native_arch == .hexagon or is_loongarch or native_arch == .or1k or is_riscv) struct {
    pub const NOCLDSTOP = 1;
    pub const NOCLDWAIT = 2;
    pub const SIGINFO = 4;
    pub const RESTART = 0x10000000;
    pub const RESETHAND = 0x80000000;
    pub const ONSTACK = 0x08000000;
    pub const NODEFER = 0x40000000;
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

pub const SIG = if (is_mips) enum(u32) {
    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 3;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);

    pub const IOT: SIG = .ABRT;
    pub const POLL: SIG = .IO;

    // /arch/mips/include/uapi/asm/signal.h#L25
    HUP = 1,
    INT = 2,
    QUIT = 3,
    ILL = 4,
    TRAP = 5,
    ABRT = 6,
    EMT = 7,
    FPE = 8,
    KILL = 9,
    BUS = 10,
    SEGV = 11,
    SYS = 12,
    PIPE = 13,
    ALRM = 14,
    TERM = 15,
    USR1 = 16,
    USR2 = 17,
    CHLD = 18,
    PWR = 19,
    WINCH = 20,
    URG = 21,
    IO = 22,
    STOP = 23,
    TSTP = 24,
    CONT = 25,
    TTIN = 26,
    TTOU = 27,
    VTALRM = 28,
    PROF = 29,
    XCPU = 30,
    XFZ = 31,
} else if (is_sparc) enum(u32) {
    pub const BLOCK = 1;
    pub const UNBLOCK = 2;
    pub const SETMASK = 4;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);

    pub const IOT: SIG = .ABRT;
    pub const CLD: SIG = .CHLD;
    pub const PWR: SIG = .LOST;
    pub const POLL: SIG = .IO;

    HUP = 1,
    INT = 2,
    QUIT = 3,
    ILL = 4,
    TRAP = 5,
    ABRT = 6,
    EMT = 7,
    FPE = 8,
    KILL = 9,
    BUS = 10,
    SEGV = 11,
    SYS = 12,
    PIPE = 13,
    ALRM = 14,
    TERM = 15,
    URG = 16,
    STOP = 17,
    TSTP = 18,
    CONT = 19,
    CHLD = 20,
    TTIN = 21,
    TTOU = 22,
    IO = 23,
    XCPU = 24,
    XFSZ = 25,
    VTALRM = 26,
    PROF = 27,
    WINCH = 28,
    LOST = 29,
    USR1 = 30,
    USR2 = 31,
} else enum(u32) {
    pub const BLOCK = 0;
    pub const UNBLOCK = 1;
    pub const SETMASK = 2;

    pub const ERR: ?Sigaction.handler_fn = @ptrFromInt(maxInt(usize));
    pub const DFL: ?Sigaction.handler_fn = @ptrFromInt(0);
    pub const IGN: ?Sigaction.handler_fn = @ptrFromInt(1);

    pub const POLL: SIG = .IO;
    pub const IOT: SIG = .ABRT;

    HUP = 1,
    INT = 2,
    QUIT = 3,
    ILL = 4,
    TRAP = 5,
    ABRT = 6,
    BUS = 7,
    FPE = 8,
    KILL = 9,
    USR1 = 10,
    SEGV = 11,
    USR2 = 12,
    PIPE = 13,
    ALRM = 14,
    TERM = 15,
    STKFLT = 16,
    CHLD = 17,
    CONT = 18,
    STOP = 19,
    TSTP = 20,
    TTIN = 21,
    TTOU = 22,
    URG = 23,
    XCPU = 24,
    XFSZ = 25,
    VTALRM = 26,
    PROF = 27,
    WINCH = 28,
    IO = 29,
    PWR = 30,
    SYS = 31,
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

/// Deprecated alias to Shut
pub const SHUT = Shut;
/// enum sock_shutdown_cmd - Shutdown types
/// matches SHUT_* in kenel
pub const Shut = enum(u32) {
    /// SHUT_RD: shutdown receptions
    rd = 0,
    /// SHUT_WR: shutdown transmissions
    wd = 1,
    /// SHUT_RDWR: shutdown receptions/transmissions
    rdwr = 2,

    _,

    // deprecated constants of the fields
    pub const RD: u32 = @intFromEnum(Shut.rd);
    pub const WR: u32 = @intFromEnum(Shut.wd);
    pub const RDWR: u32 = @intFromEnum(Shut.rdwr);
};

/// SYNC_FILE_RANGE_* flags
pub const SyncFileRange = packed struct(u32) {
    _: u32 = 0, // TODO: fill out
};

/// Deprecated alias to Sock
pub const SOCK = Sock;
/// SOCK_* Socket type and flags
pub const Sock = packed struct(u32) {
    type: Type = .default,
    flags: Flags = .{},

    /// matches sock_type in kernel
    pub const Type = enum(u7) {
        default = 0,
        stream = if (is_mips) 2 else 1,
        dgram = if (is_mips) 1 else 2,
        raw = 3,
        rdm = 4,
        seqpacket = 5,
        dccp = 6,
        packet = 10,

        _,
    };

    // bit range is (8 - 32] of the u32
    /// Flags for socket, socketpair, accept4
    pub const Flags = if (is_sparc) packed struct(u25) {
        _8: u7 = 0, // start from u7 since Type comes before Flags
        nonblock: bool = false,
        _16: u7 = 0,
        cloexec: bool = false,
        _24: u9 = 0,
    } else if (is_mips) packed struct(u25) {
        nonblock: bool = false,
        _9: u11 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    } else packed struct(u25) {
        _8: u4 = 0,
        nonblock: bool = false,
        _13: u7 = 0,
        cloexec: bool = false,
        _21: u12 = 0,
    };

    // Deprecated aliases for SOCK
    pub const STREAM: u32 = @intFromEnum(Type.stream);
    pub const DGRAM: u32 = @intFromEnum(Type.dgram);
    pub const RAW: u32 = @intFromEnum(Type.raw);
    pub const RDM: u32 = @intFromEnum(Type.rdm);
    pub const SEQPACKET: u32 = @intFromEnum(Type.seqpacket);
    pub const DCCP: u32 = @intFromEnum(Type.dccp);
    pub const PACKET: u32 = @intFromEnum(Type.packet);
    pub const CLOEXEC: u32 = (@as(u25, @bitCast(Flags{ .cloexec = true })) << 7);
    pub const NONBLOCK: u32 = (@as(u25, @bitCast(Flags{ .nonblock = true })) << 7);
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

pub const UDP = struct {
    /// Never send partially complete segments
    pub const CORK = 1;
    /// Set the socket to accept encapsulated packets
    pub const ENCAP = 100;
    /// Disable sending checksum for UDP6X
    pub const NO_CHECK6_TX = 101;
    /// Disable accepting checksum for UDP6
    pub const NO_CHECK6_RX = 102;
    /// Set GSO segmentation size
    pub const SEGMENT = 103;
    /// This socket can receive UDP GRO packets
    pub const GRO = 104;
};

pub const UDP_ENCAP = struct {
    pub const ESPINUDP_NON_IKE = 1;
    pub const ESPINUDP = 2;
    pub const L2TPINUDP = 3;
    pub const GTP0 = 4;
    pub const GTP1U = 5;
    pub const RXRPC = 6;
};

// Deprecated Alias
pub const AF = Af;
pub const PF = Af;
/// Protocol Family (same values as Protocol Family)
pub const Pf = Af;
/// Address Family
pub const Af = enum(u16) {
    unspec = 0,
    unix = 1,
    inet = 2,
    ax25 = 3,
    ipx = 4,
    appletalk = 5,
    netrom = 6,
    bridge = 7,
    atmpvc = 8,
    x25 = 9,
    inet6 = 10,
    rose = 11,
    decnet = 12,
    netbeui = 13,
    security = 14,
    key = 15,
    route = 16,
    packet = 17,
    ash = 18,
    econet = 19,
    atmsvc = 20,
    rds = 21,
    sna = 22,
    irda = 23,
    pppox = 24,
    wanpipe = 25,
    llc = 26,
    ib = 27,
    mpls = 28,
    can = 29,
    tipc = 30,
    bluetooth = 31,
    iucv = 32,
    rxrpc = 33,
    isdn = 34,
    phonet = 35,
    ieee802154 = 36,
    caif = 37,
    alg = 38,
    nfc = 39,
    vsock = 40,
    kcm = 41,
    qipcrtr = 42,
    smc = 43,
    xdp = 44,
    max = 45,
    _,

    // Aliases
    pub const local = Af.unix;
    pub const file = Af.unix;
    pub const netlink = Af.route;

    // Deprecated constants for backward compatibility
    pub const UNSPEC: u16 = @intFromEnum(Af.unspec);
    pub const UNIX: u16 = @intFromEnum(Af.unix);
    pub const LOCAL: u16 = @intFromEnum(local);
    pub const FILE: u16 = @intFromEnum(file);
    pub const INET: u16 = @intFromEnum(Af.inet);
    pub const AX25: u16 = @intFromEnum(Af.ax25);
    pub const IPX: u16 = @intFromEnum(Af.ipx);
    pub const APPLETALK: u16 = @intFromEnum(Af.appletalk);
    pub const NETROM: u16 = @intFromEnum(Af.netrom);
    pub const BRIDGE: u16 = @intFromEnum(Af.bridge);
    pub const ATMPVC: u16 = @intFromEnum(Af.atmpvc);
    pub const X25: u16 = @intFromEnum(Af.x25);
    pub const INET6: u16 = @intFromEnum(Af.inet6);
    pub const ROSE: u16 = @intFromEnum(Af.rose);
    pub const DECnet: u16 = @intFromEnum(Af.decnet);
    pub const NETBEUI: u16 = @intFromEnum(Af.netbeui);
    pub const SECURITY: u16 = @intFromEnum(Af.security);
    pub const KEY: u16 = @intFromEnum(Af.key);
    pub const ROUTE: u16 = @intFromEnum(Af.route);
    pub const NETLINK: u16 = @intFromEnum(netlink);
    pub const PACKET: u16 = @intFromEnum(Af.packet);
    pub const ASH: u16 = @intFromEnum(Af.ash);
    pub const ECONET: u16 = @intFromEnum(Af.econet);
    pub const ATMSVC: u16 = @intFromEnum(Af.atmsvc);
    pub const RDS: u16 = @intFromEnum(Af.rds);
    pub const SNA: u16 = @intFromEnum(Af.sna);
    pub const IRDA: u16 = @intFromEnum(Af.irda);
    pub const PPPOX: u16 = @intFromEnum(Af.pppox);
    pub const WANPIPE: u16 = @intFromEnum(Af.wanpipe);
    pub const LLC: u16 = @intFromEnum(Af.llc);
    pub const IB: u16 = @intFromEnum(Af.ib);
    pub const MPLS: u16 = @intFromEnum(Af.mpls);
    pub const CAN: u16 = @intFromEnum(Af.can);
    pub const TIPC: u16 = @intFromEnum(Af.tipc);
    pub const BLUETOOTH: u16 = @intFromEnum(Af.bluetooth);
    pub const IUCV: u16 = @intFromEnum(Af.iucv);
    pub const RXRPC: u16 = @intFromEnum(Af.rxrpc);
    pub const ISDN: u16 = @intFromEnum(Af.isdn);
    pub const PHONET: u16 = @intFromEnum(Af.phonet);
    pub const IEEE802154: u16 = @intFromEnum(Af.ieee802154);
    pub const CAIF: u16 = @intFromEnum(Af.caif);
    pub const ALG: u16 = @intFromEnum(Af.alg);
    pub const NFC: u16 = @intFromEnum(Af.nfc);
    pub const VSOCK: u16 = @intFromEnum(Af.vsock);
    pub const KCM: u16 = @intFromEnum(Af.kcm);
    pub const QIPCRTR: u16 = @intFromEnum(Af.qipcrtr);
    pub const SMC: u16 = @intFromEnum(Af.smc);
    pub const XDP: u16 = @intFromEnum(Af.xdp);
    pub const MAX: u16 = @intFromEnum(Af.max);
};

// COMMIT: add new Typed So enum
/// SO_* type
pub const So = if (is_mips) enum(u16) {
    debug = 1,
    reuseaddr = 0x0004,
    keepalive = 0x0008,
    dontroute = 0x0010,
    broadcast = 0x0020,
    linger = 0x0080,
    oobinline = 0x0100,
    reuseport = 0x0200,
    sndbuf = 0x1001,
    rcvbuf = 0x1002,
    sndlowat = 0x1003,
    rcvlowat = 0x1004,
    sndtimeo = 0x1005,
    rcvtimeo = 0x1006,
    @"error" = 0x1007,
    type = 0x1008,
    acceptconn = 0x1009,
    protocol = 0x1028,
    domain = 0x1029,
    no_check = 11,
    priority = 12,
    bsdcompat = 14,
    passcred = 17,
    peercred = 18,
    peersec = 30,
    sndbufforce = 31,
    rcvbufforce = 33,
    security_authentication = 22,
    security_encryption_transport = 23,
    security_encryption_network = 24,
    bindtodevice = 25,
    attach_filter = 26,
    detach_filter = 27,
    peername = 28,
    timestamp_old = 29,
    passsec = 34,
    timestampns_old = 35,
    mark = 36,
    timestamping_old = 37,
    rxq_ovfl = 40,
    wifi_status = 41,
    peek_off = 42,
    nofcs = 43,
    lock_filter = 44,
    select_err_queue = 45,
    busy_poll = 46,
    max_pacing_rate = 47,
    bpf_extensions = 48,
    incoming_cpu = 49,
    attach_bpf = 50,
    attach_reuseport_cbpf = 51,
    attach_reuseport_ebpf = 52,
    cnx_advice = 53,
    meminfo = 55,
    incoming_napi_id = 56,
    cookie = 57,
    peergroups = 59,
    zerocopy = 60,
    txtime = 61,
    bindtoifindex = 62,
    timestamp_new = 63,
    timestampns_new = 64,
    timestamping_new = 65,
    rcvtimeo_new = 66,
    sndtimeo_new = 67,
    detach_reuseport_bpf = 68,
    _,

    // aliases
    pub const get_filter: So = .attach_filter;
    pub const detach_bpf: So = .detach_filter;
} else if (is_ppc) enum(u16) {
    debug = 1,
    reuseaddr = 2,
    type = 3,
    @"error" = 4,
    dontroute = 5,
    broadcast = 6,
    sndbuf = 7,
    rcvbuf = 8,
    keepalive = 9,
    oobinline = 10,
    no_check = 11,
    priority = 12,
    linger = 13,
    bsdcompat = 14,
    reuseport = 15,
    rcvlowat = 16,
    sndlowat = 17,
    rcvtimeo = 18,
    sndtimeo = 19,
    passcred = 20,
    peercred = 21,
    acceptconn = 30,
    peersec = 31,
    sndbufforce = 32,
    rcvbufforce = 33,
    protocol = 38,
    domain = 39,
    security_authentication = 22,
    security_encryption_transport = 23,
    security_encryption_network = 24,
    bindtodevice = 25,
    attach_filter = 26,
    detach_filter = 27,
    peername = 28,
    timestamp_old = 29,
    passsec = 34,
    timestampns_old = 35,
    mark = 36,
    timestamping_old = 37,
    rxq_ovfl = 40,
    wifi_status = 41,
    peek_off = 42,
    nofcs = 43,
    lock_filter = 44,
    select_err_queue = 45,
    busy_poll = 46,
    max_pacing_rate = 47,
    bpf_extensions = 48,
    incoming_cpu = 49,
    attach_bpf = 50,
    attach_reuseport_cbpf = 51,
    attach_reuseport_ebpf = 52,
    cnx_advice = 53,
    meminfo = 55,
    incoming_napi_id = 56,
    cookie = 57,
    peergroups = 59,
    zerocopy = 60,
    txtime = 61,
    bindtoifindex = 62,
    timestamp_new = 63,
    timestampns_new = 64,
    timestamping_new = 65,
    rcvtimeo_new = 66,
    sndtimeo_new = 67,
    detach_reuseport_bpf = 68,
    _,

    // aliases
    pub const get_filter: So = .attach_filter;
    pub const detach_bpf: So = .detach_filter;
} else if (is_sparc) enum(u16) {
    debug = 1,
    reuseaddr = 4,
    type = 4104,
    @"error" = 4103,
    dontroute = 16,
    broadcast = 32,
    sndbuf = 4097,
    rcvbuf = 4098,
    keepalive = 8,
    oobinline = 256,
    no_check = 11,
    priority = 12,
    linger = 128,
    bsdcompat = 1024,
    reuseport = 512,
    passcred = 2,
    peercred = 64,
    rcvlowat = 2048,
    sndlowat = 4096,
    rcvtimeo = 8192,
    sndtimeo = 16384,
    acceptconn = 32768,
    peersec = 30,
    sndbufforce = 4106,
    rcvbufforce = 4107,
    protocol = 4136,
    domain = 4137,
    security_authentication = 20481,
    security_encryption_transport = 20482,
    security_encryption_network = 20484,
    bindtodevice = 13,
    attach_filter = 26,
    detach_filter = 27,
    peername = 28,
    timestamp_old = 29,
    passsec = 31,
    timestampns_old = 33,
    mark = 34,
    timestamping_old = 35,
    rxq_ovfl = 36,
    wifi_status = 37,
    peek_off = 38,
    nofcs = 39,
    lock_filter = 40,
    select_err_queue = 41,
    busy_poll = 48,
    max_pacing_rate = 49,
    bpf_extensions = 50,
    incoming_cpu = 51,
    attach_bpf = 52,
    attach_reuseport_cbpf = 53,
    attach_reuseport_ebpf = 54,
    cnx_advice = 55,
    meminfo = 57,
    incoming_napi_id = 58,
    cookie = 59,
    peergroups = 61,
    zerocopy = 62,
    txtime = 63,
    bindtoifindex = 65,
    timestamp_new = 70,
    timestampns_new = 66,
    timestamping_new = 67,
    rcvtimeo_new = 68,
    sndtimeo_new = 69,
    detach_reuseport_bpf = 71,
    _,

    // aliases
    pub const get_filter: So = .attach_filter;
    pub const detach_bpf: So = .detach_filter;
} else enum(u16) {
    debug = 1,
    reuseaddr = 2,
    type = 3,
    @"error" = 4,
    dontroute = 5,
    broadcast = 6,
    sndbuf = 7,
    rcvbuf = 8,
    keepalive = 9,
    oobinline = 10,
    no_check = 11,
    priority = 12,
    linger = 13,
    bsdcompat = 14,
    reuseport = 15,
    passcred = 16,
    peercred = 17,
    rcvlowat = 18,
    sndlowat = 19,
    rcvtimeo = 20,
    sndtimeo = 21,
    acceptconn = 30,
    peersec = 31,
    sndbufforce = 32,
    rcvbufforce = 33,
    passsec = 34,
    timestampns_old = 35,
    mark = 36,
    timestamping_old = 37,
    protocol = 38,
    domain = 39,
    rxq_ovfl = 40,
    wifi_status = 41,
    peek_off = 42,
    nofcs = 43,
    lock_filter = 44,
    select_err_queue = 45,
    busy_poll = 46,
    max_pacing_rate = 47,
    bpf_extensions = 48,
    incoming_cpu = 49,
    attach_bpf = 50,
    attach_reuseport_cbpf = 51,
    attach_reuseport_ebpf = 52,
    cnx_advice = 53,
    meminfo = 55,
    incoming_napi_id = 56,
    cookie = 57,
    peergroups = 59,
    zerocopy = 60,
    txtime = 61,
    bindtoifindex = 62,
    timestamp_new = 63,
    timestampns_new = 64,
    timestamping_new = 65,
    rcvtimeo_new = 66,
    sndtimeo_new = 67,
    detach_reuseport_bpf = 68,
    security_authentication = 22,
    security_encryption_transport = 23,
    security_encryption_network = 24,
    bindtodevice = 25,
    attach_filter = 26,
    detach_filter = 27,
    peername = 28,
    timestamp_old = 29,
    _,

    // aliases
    pub const get_filter: So = .attach_filter;
    pub const detach_bpf: So = .detach_filter;
};

// COMMIT: add SO constants
/// Backwards-compatible SO_* constants
pub const SO = struct {
    pub const DEBUG: u16 = @intFromEnum(So.debug);
    pub const REUSEADDR: u16 = @intFromEnum(So.reuseaddr);
    pub const KEEPALIVE: u16 = @intFromEnum(So.keepalive);
    pub const DONTROUTE: u16 = @intFromEnum(So.dontroute);
    pub const BROADCAST: u16 = @intFromEnum(So.broadcast);
    pub const LINGER: u16 = @intFromEnum(So.linger);
    pub const OOBINLINE: u16 = @intFromEnum(So.oobinline);
    pub const REUSEPORT: u16 = @intFromEnum(So.reuseport);
    pub const SNDBUF: u16 = @intFromEnum(So.sndbuf);
    pub const RCVBUF: u16 = @intFromEnum(So.rcvbuf);
    pub const SNDLOWAT: u16 = @intFromEnum(So.sndlowat);
    pub const RCVLOWAT: u16 = @intFromEnum(So.rcvlowat);
    pub const RCVTIMEO: u16 = @intFromEnum(So.rcvtimeo);
    pub const SNDTIMEO: u16 = @intFromEnum(So.sndtimeo);
    pub const ERROR: u16 = @intFromEnum(So.@"error");
    pub const TYPE: u16 = @intFromEnum(So.type);
    pub const ACCEPTCONN: u16 = @intFromEnum(So.acceptconn);
    pub const PROTOCOL: u16 = @intFromEnum(So.protocol);
    pub const DOMAIN: u16 = @intFromEnum(So.domain);
    pub const NO_CHECK: u16 = @intFromEnum(So.no_check);
    pub const PRIORITY: u16 = @intFromEnum(So.priority);
    pub const BSDCOMPAT: u16 = @intFromEnum(So.bsdcompat);
    pub const PASSCRED: u16 = @intFromEnum(So.passcred);
    pub const PEERCRED: u16 = @intFromEnum(So.peercred);
    pub const PEERSEC: u16 = @intFromEnum(So.peersec);
    pub const SNDBUFFORCE: u16 = @intFromEnum(So.sndbufforce);
    pub const RCVBUFFORCE: u16 = @intFromEnum(So.rcvbufforce);
    pub const SECURITY_AUTHENTICATION: u16 = @intFromEnum(So.security_authentication);
    pub const SECURITY_ENCRYPTION_TRANSPORT: u16 = @intFromEnum(So.security_encryption_transport);
    pub const SECURITY_ENCRYPTION_NETWORK: u16 = @intFromEnum(So.security_encryption_network);
    pub const BINDTODEVICE: u16 = @intFromEnum(So.bindtodevice);
    pub const ATTACH_FILTER: u16 = @intFromEnum(So.attach_filter);
    pub const DETACH_FILTER: u16 = @intFromEnum(So.detach_filter);
    pub const GET_FILTER: u16 = ATTACH_FILTER; // alias
    pub const PEERNAME: u16 = @intFromEnum(So.peername);
    pub const TIMESTAMP_OLD: u16 = @intFromEnum(So.timestamp_old);
    pub const PASSSEC: u16 = @intFromEnum(So.passsec);
    pub const TIMESTAMPNS_OLD: u16 = @intFromEnum(So.timestampns_old);
    pub const MARK: u16 = @intFromEnum(So.mark);
    pub const TIMESTAMPING_OLD: u16 = @intFromEnum(So.timestamping_old);
    pub const RXQ_OVFL: u16 = @intFromEnum(So.rxq_ovfl);
    pub const WIFI_STATUS: u16 = @intFromEnum(So.wifi_status);
    pub const PEEK_OFF: u16 = @intFromEnum(So.peek_off);
    pub const NOFCS: u16 = @intFromEnum(So.nofcs);
    pub const LOCK_FILTER: u16 = @intFromEnum(So.lock_filter);
    pub const SELECT_ERR_QUEUE: u16 = @intFromEnum(So.select_err_queue);
    pub const BUSY_POLL: u16 = @intFromEnum(So.busy_poll);
    pub const MAX_PACING_RATE: u16 = @intFromEnum(So.max_pacing_rate);
    pub const BPF_EXTENSIONS: u16 = @intFromEnum(So.bpf_extensions);
    pub const INCOMING_CPU: u16 = @intFromEnum(So.incoming_cpu);
    pub const ATTACH_BPF: u16 = @intFromEnum(So.attach_bpf);
    pub const DETACH_BPF: u16 = DETACH_FILTER; // alias in original
    pub const ATTACH_REUSEPORT_CBPF: u16 = @intFromEnum(So.attach_reuseport_cbpf);
    pub const ATTACH_REUSEPORT_EBPF: u16 = @intFromEnum(So.attach_reuseport_ebpf);
    pub const CNX_ADVICE: u16 = @intFromEnum(So.cnx_advice);
    pub const MEMINFO: u16 = @intFromEnum(So.meminfo);
    pub const INCOMING_NAPI_ID: u16 = @intFromEnum(So.incoming_napi_id);
    pub const COOKIE: u16 = @intFromEnum(So.cookie);
    pub const PEERGROUPS: u16 = @intFromEnum(So.peergroups);
    pub const ZEROCOPY: u16 = @intFromEnum(So.zerocopy);
    pub const TXTIME: u16 = @intFromEnum(So.txtime);
    pub const BINDTOIFINDEX: u16 = @intFromEnum(So.bindtoifindex);
    pub const TIMESTAMP_NEW: u16 = @intFromEnum(So.timestamp_new);
    pub const TIMESTAMPNS_NEW: u16 = @intFromEnum(So.timestampns_new);
    pub const TIMESTAMPING_NEW: u16 = @intFromEnum(So.timestamping_new);
    pub const RCVTIMEO_NEW: u16 = @intFromEnum(So.rcvtimeo_new);
    pub const SNDTIMEO_NEW: u16 = @intFromEnum(So.sndtimeo_new);
    pub const DETACH_REUSEPORT_BPF: u16 = @intFromEnum(So.detach_reuseport_bpf);
};

pub const SCM = struct {
    // https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/linux/socket.h?id=f777d1112ee597d7f7dd3ca232220873a34ad0c8#n178
    pub const RIGHTS = 1;
    pub const CREDENTIALS = 2;
    pub const SECURITY = 3;
    pub const PIDFD = 4;

    pub const WIFI_STATUS = SO.WIFI_STATUS;
    pub const TIMESTAMPING_OPT_STATS = 54;
    pub const TIMESTAMPING_PKTINFO = 58;
    pub const TXTIME = SO.TXTIME;
};

/// Deprecated in favor of Sol
pub const SOL = Sol;
// https://github.com/torvalds/linux/blob/0d97f2067c166eb495771fede9f7b73999c67f66/include/linux/socket.h#L347C1-L388C22
/// Socket option level for setsockopt(2)/getsockopt(2)
pub const Sol = enum(u16) {
    ip = 0,
    socket = if (is_mips or is_sparc) 65535 else 1,
    tcp = 6,
    udp = 17,
    ipv6 = 41,
    icmpv6 = 58,
    sctp = 132,
    /// UDP-Lite (RFC 3828)
    udplite = 136,
    raw = 255,
    ipx = 256,
    ax25 = 257,
    atalk = 258,
    netrom = 259,
    rose = 260,
    decnet = 261,
    x25 = 262,
    packet = 263,
    /// ATM layer (cell level)
    atm = 264,
    /// ATM Adaption Layer (packet level)
    aal = 265,
    irda = 266,
    netbeui = 267,
    llc = 268,
    dccp = 269,
    netlink = 270,
    tipc = 271,
    rxrpc = 272,
    pppol2tp = 273,
    bluetooth = 274,
    pnpipe = 275,
    rds = 276,
    iucv = 277,
    caif = 278,
    alg = 279,
    nfc = 280,
    kcm = 281,
    tls = 282,
    xdp = 283,
    mptcp = 284,
    mctp = 285,
    smc = 286,
    vsock = 287,
    _,

    /// Deprecated constants for compatibility with current Zig
    pub const IP: u16 = @intFromEnum(Sol.ip);
    pub const SOCKET: u16 = @intFromEnum(Sol.socket);
    pub const TCP: u16 = @intFromEnum(Sol.tcp);
    pub const UDP: u16 = @intFromEnum(Sol.udp);
    pub const IPV6: u16 = @intFromEnum(Sol.ipv6);
    pub const ICMPV6: u16 = @intFromEnum(Sol.icmpv6);
    pub const SCTP: u16 = @intFromEnum(Sol.sctp);
    pub const UDPLITE: u16 = @intFromEnum(Sol.udplite);

    pub const RAW: u16 = @intFromEnum(Sol.raw);
    pub const IPX: u16 = @intFromEnum(Sol.ipx);
    pub const AX25: u16 = @intFromEnum(Sol.ax25);
    pub const ATALK: u16 = @intFromEnum(Sol.atalk);
    pub const NETROM: u16 = @intFromEnum(Sol.netrom);
    pub const ROSE: u16 = @intFromEnum(Sol.rose);
    pub const DECNET: u16 = @intFromEnum(Sol.decnet);
    pub const X25: u16 = @intFromEnum(Sol.x25);
    pub const PACKET: u16 = @intFromEnum(Sol.packet);
    pub const ATM: u16 = @intFromEnum(Sol.atm);
    pub const AAL: u16 = @intFromEnum(Sol.aal);
    pub const IRDA: u16 = @intFromEnum(Sol.irda);
    pub const NETBEUI: u16 = @intFromEnum(Sol.netbeui);
    pub const LLC: u16 = @intFromEnum(Sol.llc);
    pub const DCCP: u16 = @intFromEnum(Sol.dccp);
    pub const NETLINK: u16 = @intFromEnum(Sol.netlink);
    pub const TIPC: u16 = @intFromEnum(Sol.tipc);
    pub const RXRPC: u16 = @intFromEnum(Sol.rxrpc);
    pub const PPPOL2TP: u16 = @intFromEnum(Sol.pppol2tp);
    pub const BLUETOOTH: u16 = @intFromEnum(Sol.bluetooth);
    pub const PNPIPE: u16 = @intFromEnum(Sol.pnpipe);
    pub const RDS: u16 = @intFromEnum(Sol.rds);
    pub const IUCV: u16 = @intFromEnum(Sol.iucv);
    pub const CAIF: u16 = @intFromEnum(Sol.caif);
    pub const ALG: u16 = @intFromEnum(Sol.alg);
    pub const NFC: u16 = @intFromEnum(Sol.nfc);
    pub const KCM: u16 = @intFromEnum(Sol.kcm);
    pub const TLS: u16 = @intFromEnum(Sol.tls);
    pub const XDP: u16 = @intFromEnum(Sol.xdp);
    pub const MPTCP: u16 = @intFromEnum(Sol.mptcp);
    pub const MCTP: u16 = @intFromEnum(Sol.mctp);
    pub const SMC: u16 = @intFromEnum(Sol.smc);
    pub const VSOCK: u16 = @intFromEnum(Sol.vsock);
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

// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/ip.h?id=64e844505bc08cde3f346f193cbbbab0096fef54#n24
pub const IPTOS = struct {
    pub const TOS_MASK = 0x1e;
    pub fn TOS(t: anytype) @TypeOf(t) {
        return t & TOS_MASK;
    }

    pub const MINCOST = 0x02;
    pub const RELIABILITY = 0x04;
    pub const THROUGHPUT = 0x08;
    pub const LOWDELAY = 0x10;

    pub const PREC_MASK = 0xe0;
    pub fn PREC(t: anytype) @TypeOf(t) {
        return t & PREC_MASK;
    }

    pub const PREC_ROUTINE = 0x00;
    pub const PREC_PRIORITY = 0x20;
    pub const PREC_IMMEDIATE = 0x40;
    pub const PREC_FLASH = 0x60;
    pub const PREC_FLASHOVERRIDE = 0x80;
    pub const PREC_CRITIC_ECP = 0xa0;
    pub const PREC_INTERNETCONTROL = 0xc0;
    pub const PREC_NETCONTROL = 0xe0;
};

// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/linux/socket.h?id=b1e904999542ad6764eafa54545f1c55776006d1#n43
pub const linger = extern struct {
    onoff: i32, // non-zero to linger on close
    linger: i32, // time to linger in seconds
};

// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/in.h?id=64e844505bc08cde3f346f193cbbbab0096fef54#n250
pub const in_pktinfo = extern struct {
    ifindex: i32,
    spec_dst: u32,
    addr: u32,
};

// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/linux/ipv6.h?id=f24987ef6959a7efaf79bffd265522c3df18d431#n22
pub const in6_pktinfo = extern struct {
    addr: [16]u8,
    ifindex: i32,
};

/// IEEE 802.3 Ethernet magic constants. The frame sizes omit the preamble
/// and FCS/CRC (frame check sequence).
pub const ETH = struct {
    /// Octets in one ethernet addr
    pub const ALEN = 6;
    /// Octets in ethernet type field
    pub const TLEN = 2;
    /// Total octets in header
    pub const HLEN = 14;
    /// Min. octets in frame sans FC
    pub const ZLEN = 60;
    /// Max. octets in payload
    pub const DATA_LEN = 1500;
    /// Max. octets in frame sans FCS
    pub const FRAME_LEN = 1514;
    /// Octets in the FCS
    pub const FCS_LEN = 4;

    /// Min IPv4 MTU per RFC791
    pub const MIN_MTU = 68;
    /// 65535, same as IP_MAX_MTU
    pub const MAX_MTU = 0xFFFF;

    /// These are the defined Ethernet Protocol ID's.
    pub const P = struct {
        /// Ethernet Loopback packet
        pub const LOOP = 0x0060;
        /// Xerox PUP packet
        pub const PUP = 0x0200;
        /// Xerox PUP Addr Trans packet
        pub const PUPAT = 0x0201;
        /// TSN (IEEE 1722) packet
        pub const TSN = 0x22F0;
        /// ERSPAN version 2 (type III)
        pub const ERSPAN2 = 0x22EB;
        /// Internet Protocol packet
        pub const IP = 0x0800;
        /// CCITT X.25
        pub const X25 = 0x0805;
        /// Address Resolution packet
        pub const ARP = 0x0806;
        /// G8BPQ AX.25 Ethernet Packet [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const BPQ = 0x08FF;
        /// Xerox IEEE802.3 PUP packet
        pub const IEEEPUP = 0x0a00;
        /// Xerox IEEE802.3 PUP Addr Trans packet
        pub const IEEEPUPAT = 0x0a01;
        /// B.A.T.M.A.N.-Advanced packet [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const BATMAN = 0x4305;
        /// DEC Assigned proto
        pub const DEC = 0x6000;
        /// DEC DNA Dump/Load
        pub const DNA_DL = 0x6001;
        /// DEC DNA Remote Console
        pub const DNA_RC = 0x6002;
        /// DEC DNA Routing
        pub const DNA_RT = 0x6003;
        /// DEC LAT
        pub const LAT = 0x6004;
        /// DEC Diagnostics
        pub const DIAG = 0x6005;
        /// DEC Customer use
        pub const CUST = 0x6006;
        /// DEC Systems Comms Arch
        pub const SCA = 0x6007;
        /// Trans Ether Bridging
        pub const TEB = 0x6558;
        /// Reverse Addr Res packet
        pub const RARP = 0x8035;
        /// Appletalk DDP
        pub const ATALK = 0x809B;
        /// Appletalk AARP
        pub const AARP = 0x80F3;
        /// 802.1Q VLAN Extended Header
        pub const P_8021Q = 0x8100;
        /// ERSPAN type II
        pub const ERSPAN = 0x88BE;
        /// IPX over DIX
        pub const IPX = 0x8137;
        /// IPv6 over bluebook
        pub const IPV6 = 0x86DD;
        /// IEEE Pause frames. See 802.3 31B
        pub const PAUSE = 0x8808;
        /// Slow Protocol. See 802.3ad 43B
        pub const SLOW = 0x8809;
        /// Web-cache coordination protocol defined in draft-wilson-wrec-wccp-v2-00.txt
        pub const WCCP = 0x883E;
        /// MPLS Unicast traffic
        pub const MPLS_UC = 0x8847;
        /// MPLS Multicast traffic
        pub const MPLS_MC = 0x8848;
        /// MultiProtocol Over ATM
        pub const ATMMPOA = 0x884c;
        /// PPPoE discovery messages
        pub const PPP_DISC = 0x8863;
        /// PPPoE session messages
        pub const PPP_SES = 0x8864;
        /// HPNA, wlan link local tunnel
        pub const LINK_CTL = 0x886c;
        /// Frame-based ATM Transport over Ethernet
        pub const ATMFATE = 0x8884;
        /// Port Access Entity (IEEE 802.1X)
        pub const PAE = 0x888E;
        /// PROFINET
        pub const PROFINET = 0x8892;
        /// Multiple proprietary protocols
        pub const REALTEK = 0x8899;
        /// ATA over Ethernet
        pub const AOE = 0x88A2;
        /// EtherCAT
        pub const ETHERCAT = 0x88A4;
        /// 802.1ad Service VLAN
        pub const @"8021AD" = 0x88A8;
        /// 802.1 Local Experimental 1.
        pub const @"802_EX1" = 0x88B5;
        /// 802.11 Preauthentication
        pub const PREAUTH = 0x88C7;
        /// TIPC
        pub const TIPC = 0x88CA;
        /// Link Layer Discovery Protocol
        pub const LLDP = 0x88CC;
        /// Media Redundancy Protocol
        pub const MRP = 0x88E3;
        /// 802.1ae MACsec
        pub const MACSEC = 0x88E5;
        /// 802.1ah Backbone Service Tag
        pub const @"8021AH" = 0x88E7;
        /// 802.1Q MVRP
        pub const MVRP = 0x88F5;
        /// IEEE 1588 Timesync
        pub const @"1588" = 0x88F7;
        /// NCSI protocol
        pub const NCSI = 0x88F8;
        /// IEC 62439-3 PRP/HSRv0
        pub const PRP = 0x88FB;
        /// Connectivity Fault Management
        pub const CFM = 0x8902;
        /// Fibre Channel over Ethernet
        pub const FCOE = 0x8906;
        /// Infiniband over Ethernet
        pub const IBOE = 0x8915;
        /// TDLS
        pub const TDLS = 0x890D;
        /// FCoE Initialization Protocol
        pub const FIP = 0x8914;
        /// IEEE 802.21 Media Independent Handover Protocol
        pub const @"80221" = 0x8917;
        /// IEC 62439-3 HSRv1
        pub const HSR = 0x892F;
        /// Network Service Header
        pub const NSH = 0x894F;
        /// Ethernet loopback packet, per IEEE 802.3
        pub const LOOPBACK = 0x9000;
        /// deprecated QinQ VLAN [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const QINQ1 = 0x9100;
        /// deprecated QinQ VLAN [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const QINQ2 = 0x9200;
        /// deprecated QinQ VLAN [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const QINQ3 = 0x9300;
        /// Ethertype DSA [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const EDSA = 0xDADA;
        /// Fake VLAN Header for DSA [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const DSA_8021Q = 0xDADB;
        /// A5PSW Tag Value [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const DSA_A5PSW = 0xE001;
        /// ForCES inter-FE LFB type
        pub const IFE = 0xED3E;
        /// IBM af_iucv [ NOT AN OFFICIALLY REGISTERED ID ]
        pub const AF_IUCV = 0xFBFB;
        /// If the value in the ethernet type is more than this value then the frame is Ethernet II. Else it is 802.3
        pub const @"802_3_MIN" = 0x0600;

        // Non DIX types. Won't clash for 1500 types.

        /// Dummy type for 802.3 frames
        pub const @"802_3" = 0x0001;
        /// Dummy protocol id for AX.25
        pub const AX25 = 0x0002;
        /// Every packet (be careful!!!)
        pub const ALL = 0x0003;
        /// 802.2 frames
        pub const @"802_2" = 0x0004;
        /// Internal only
        pub const SNAP = 0x0005;
        /// DEC DDCMP: Internal only
        pub const DDCMP = 0x0006;
        /// Dummy type for WAN PPP frames
        pub const WAN_PPP = 0x0007;
        /// Dummy type for PPP MP frames
        pub const PPP_MP = 0x0008;
        /// Localtalk pseudo type
        pub const LOCALTALK = 0x0009;
        /// CAN: Controller Area Network
        pub const CAN = 0x000C;
        /// CANFD: CAN flexible data rate
        pub const CANFD = 0x000D;
        /// CANXL: eXtended frame Length
        pub const CANXL = 0x000E;
        /// Dummy type for Atalk over PPP
        pub const PPPTALK = 0x0010;
        /// 802.2 frames
        pub const TR_802_2 = 0x0011;
        /// Mobitex (kaz@cafe.net)
        pub const MOBITEX = 0x0015;
        /// Card specific control frames
        pub const CONTROL = 0x0016;
        /// Linux-IrDA
        pub const IRDA = 0x0017;
        /// Acorn Econet
        pub const ECONET = 0x0018;
        /// HDLC frames
        pub const HDLC = 0x0019;
        /// 1A for ArcNet :-)
        pub const ARCNET = 0x001A;
        /// Distributed Switch Arch.
        pub const DSA = 0x001B;
        /// Trailer switch tagging
        pub const TRAILER = 0x001C;
        /// Nokia Phonet frames
        pub const PHONET = 0x00F5;
        /// IEEE802.15.4 frame
        pub const IEEE802154 = 0x00F6;
        /// ST-Ericsson CAIF protocol
        pub const CAIF = 0x00F7;
        /// Multiplexed DSA protocol
        pub const XDSA = 0x00F8;
        /// Qualcomm multiplexing and aggregation protocol
        pub const MAP = 0x00F9;
        /// Management component transport protocol packets
        pub const MCTP = 0x00FA;
    };
};

// Deprecated alias for Msg
pub const MSG = Msg;
pub const Msg = packed struct(u32) {
    /// Process out-of-band data
    oob: bool = false,
    /// Peek at incoming message
    peek: bool = false,
    /// Send without using routing tables
    dontroute: bool = false,
    /// Control data truncated
    ctrunc: bool = false,
    /// Do not send. Only probe path (e.g. for MTU)
    probe: bool = false,
    /// Normal data truncated
    trunc: bool = false,
    /// Nonblocking I/O
    dontwait: bool = false,
    /// End of record
    eor: bool = false,
    /// Wait for a full request
    waitall: bool = false,
    /// FIN flag
    fin: bool = false,
    /// SYN flag
    syn: bool = false,
    /// Confirm path validity
    confirm: bool = false,
    /// RST flag
    rst: bool = false,
    /// Fetch message from error queue
    errqueue: bool = false,
    /// Do not generate SIGPIPE
    nosignal: bool = false,
    /// Sender will send more
    more: bool = false,
    /// recvmmsg(): block until 1+ packets available
    waitforone: bool = false,
    _18: u1 = 0,
    /// sendmmsg(): more messages coming
    batch: bool = false,
    /// sendpage() internal: page frags are not shared
    no_shared_frags: bool = false,
    /// sendpage() internal: page may carry plain text and require encryption
    sendpage_decrypted: bool = false,
    _22: u4 = 0,
    // COMMIT: new flags
    /// Receive devmem skbs as cmsg
    sock_devmem: bool = false,
    /// Use user data in kernel path
    zerocopy: bool = false,
    /// Splice the pages from the iterator in sendmsg()
    splice_pages: bool = false,
    _29: u1 = 0,
    /// Send data in TCP SYN
    fastopen: bool = false,
    /// Set close_on_exec for file descriptor received through SCM_RIGHTS
    cmsg_cloexec: bool = false,
    _: u1 = 0,

    // DEPRECATED CONSTANTS
    pub const OOB: u32 = @bitCast(Msg{ .oob = true });
    pub const PEEK: u32 = @bitCast(Msg{ .peek = true });
    pub const DONTROUTE: u32 = @bitCast(Msg{ .dontroute = true });
    pub const CTRUNC: u32 = @bitCast(Msg{ .ctrunc = true });
    // fix typo PROBE not PROXY
    pub const PROBE: u32 = @bitCast(Msg{ .probe = true });
    pub const TRUNC: u32 = @bitCast(Msg{ .trunc = true });
    pub const DONTWAIT: u32 = @bitCast(Msg{ .dontwait = true });
    pub const EOR: u32 = @bitCast(Msg{ .eor = true });
    pub const WAITALL: u32 = @bitCast(Msg{ .waitall = true });
    pub const FIN: u32 = @bitCast(Msg{ .fin = true });
    pub const SYN: u32 = @bitCast(Msg{ .syn = true });
    pub const CONFIRM: u32 = @bitCast(Msg{ .confirm = true });
    pub const RST: u32 = @bitCast(Msg{ .rst = true });
    pub const ERRQUEUE: u32 = @bitCast(Msg{ .errqueue = true });
    pub const NOSIGNAL: u32 = @bitCast(Msg{ .nosignal = true });
    pub const MORE: u32 = @bitCast(Msg{ .more = true });
    pub const WAITFORONE: u32 = @bitCast(Msg{ .waitforone = true });
    pub const BATCH: u32 = @bitCast(Msg{ .batch = true });
    pub const ZEROCOPY: u32 = @bitCast(Msg{ .zerocopy = true });
    pub const FASTOPEN: u32 = @bitCast(Msg{ .fastopen = true });
    pub const CMSG_CLOEXEC: u32 = @bitCast(Msg{ .cmsg_cloexec = true });
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

pub const T = if (is_mips) struct {
    pub const CGETA = 0x5401;
    pub const CSETA = 0x5402;
    pub const CSETAW = 0x5403;
    pub const CSETAF = 0x5404;

    pub const CSBRK = 0x5405;
    pub const CXONC = 0x5406;
    pub const CFLSH = 0x5407;

    pub const CGETS = 0x540d;
    pub const CSETS = 0x540e;
    pub const CSETSW = 0x540f;
    pub const CSETSF = 0x5410;

    pub const IOCEXCL = 0x740d;
    pub const IOCNXCL = 0x740e;
    pub const IOCOUTQ = 0x7472;
    pub const IOCSTI = 0x5472;
    pub const IOCMGET = 0x741d;
    pub const IOCMBIS = 0x741b;
    pub const IOCMBIC = 0x741c;
    pub const IOCMSET = 0x741a;
    pub const IOCPKT = 0x5470;
    pub const IOCPKT_DATA = 0x00;
    pub const IOCPKT_FLUSHREAD = 0x01;
    pub const IOCPKT_FLUSHWRITE = 0x02;
    pub const IOCPKT_STOP = 0x04;
    pub const IOCPKT_START = 0x08;
    pub const IOCPKT_NOSTOP = 0x10;
    pub const IOCPKT_DOSTOP = 0x20;
    pub const IOCPKT_IOCTL = 0x40;
    pub const IOCSWINSZ = IOCTL.IOW('t', 103, winsize);
    pub const IOCGWINSZ = IOCTL.IOR('t', 104, winsize);
    pub const IOCNOTTY = 0x5471;
    pub const IOCSETD = 0x7401;
    pub const IOCGETD = 0x7400;

    pub const FIOCLEX = 0x6601;
    pub const FIONCLEX = 0x6602;
    pub const FIOASYNC = 0x667d;
    pub const FIONBIO = 0x667e;
    pub const FIOQSIZE = 0x667f;

    pub const IOCGLTC = 0x7474;
    pub const IOCSLTC = 0x7475;
    pub const IOCSPGRP = IOCTL.IOW('t', 118, c_int);
    pub const IOCGPGRP = IOCTL.IOR('t', 119, c_int);
    pub const IOCCONS = IOCTL.IOW('t', 120, c_int);

    pub const FIONREAD = 0x467f;
    pub const IOCINQ = FIONREAD;

    pub const IOCGETP = 0x7408;
    pub const IOCSETP = 0x7409;
    pub const IOCSETN = 0x740a;

    pub const IOCSBRK = 0x5427;
    pub const IOCCBRK = 0x5428;
    pub const IOCGSID = 0x7416;
    pub const CGETS2 = IOCTL.IOR('T', 0x2a, termios2);
    pub const CSETS2 = IOCTL.IOW('T', 0x2b, termios2);
    pub const CSETSW2 = IOCTL.IOW('T', 0x2c, termios2);
    pub const CSETSF2 = IOCTL.IOW('T', 0x2d, termios2);
    pub const IOCGRS485 = IOCTL.IOR('T', 0x2e, serial_rs485);
    pub const IOCSRS485 = IOCTL.IOWR('T', 0x2f, serial_rs485);
    pub const IOCGPTN = IOCTL.IOR('T', 0x30, c_uint);
    pub const IOCSPTLCK = IOCTL.IOW('T', 0x31, c_int);
    pub const IOCGDEV = IOCTL.IOR('T', 0x32, c_uint);
    pub const IOCSIG = IOCTL.IOW('T', 0x36, c_int);
    pub const IOCVHANGUP = 0x5437;
    pub const IOCGPKT = IOCTL.IOR('T', 0x38, c_int);
    pub const IOCGPTLCK = IOCTL.IOR('T', 0x39, c_int);
    pub const IOCGEXCL = IOCTL.IOR('T', 0x40, c_int);
    pub const IOCGPTPEER = IOCTL.IO('T', 0x41);
    pub const IOCGISO7816 = IOCTL.IOR('T', 0x42, serial_iso7816);
    pub const IOCSISO7816 = IOCTL.IOWR('T', 0x43, serial_iso7816);

    pub const IOCSCTTY = 0x5480;
    pub const IOCGSOFTCAR = 0x5481;
    pub const IOCSSOFTCAR = 0x5482;
    pub const IOCLINUX = 0x5483;
    pub const IOCGSERIAL = 0x5484;
    pub const IOCSSERIAL = 0x5485;
    pub const CSBRKP = 0x5486;
    pub const IOCSERCONFIG = 0x5488;
    pub const IOCSERGWILD = 0x5489;
    pub const IOCSERSWILD = 0x548a;
    pub const IOCGLCKTRMIOS = 0x548b;
    pub const IOCSLCKTRMIOS = 0x548c;
    pub const IOCSERGSTRUCT = 0x548d;
    pub const IOCSERGETLSR = 0x548e;
    pub const IOCSERGETMULTI = 0x548f;
    pub const IOCSERSETMULTI = 0x5490;
    pub const IOCMIWAIT = 0x5491;
    pub const IOCGICOUNT = 0x5492;
} else if (is_ppc) struct {
    pub const FIOCLEX = IOCTL.IO('f', 1);
    pub const FIONCLEX = IOCTL.IO('f', 2);
    pub const FIOASYNC = IOCTL.IOW('f', 125, c_int);
    pub const FIONBIO = IOCTL.IOW('f', 126, c_int);
    pub const FIONREAD = IOCTL.IOR('f', 127, c_int);
    pub const IOCINQ = FIONREAD;
    pub const FIOQSIZE = IOCTL.IOR('f', 128, c_longlong); // loff_t -> __kernel_loff_t -> long long

    pub const IOCGETP = IOCTL.IOR('t', 8, sgttyb);
    pub const IOCSETP = IOCTL.IOW('t', 9, sgttyb);
    pub const IOCSETN = IOCTL.IOW('t', 10, sgttyb);

    pub const IOCSETC = IOCTL.IOW('t', 17, tchars);
    pub const IOCGETC = IOCTL.IOR('t', 18, tchars);
    pub const CGETS = IOCTL.IOR('t', 19, termios);
    pub const CSETS = IOCTL.IOW('t', 20, termios);
    pub const CSETSW = IOCTL.IOW('t', 21, termios);
    pub const CSETSF = IOCTL.IOW('t', 22, termios);

    pub const CGETA = IOCTL.IOR('t', 23, termio);
    pub const CSETA = IOCTL.IOW('t', 24, termio);
    pub const CSETAW = IOCTL.IOW('t', 25, termio);
    pub const CSETAF = IOCTL.IOW('t', 28, termio);

    pub const CSBRK = IOCTL.IO('t', 29);
    pub const CXONC = IOCTL.IO('t', 30);
    pub const CFLSH = IOCTL.IO('t', 31);

    pub const IOCSWINSZ = IOCTL.IOW('t', 103, winsize);
    pub const IOCGWINSZ = IOCTL.IOR('t', 104, winsize);
    pub const IOCSTART = IOCTL.IO('t', 110);
    pub const IOCSTOP = IOCTL.IO('t', 111);
    pub const IOCOUTQ = IOCTL.IOR('t', 115, c_int);

    pub const IOCGLTC = IOCTL.IOR('t', 116, ltchars);
    pub const IOCSLTC = IOCTL.IOW('t', 117, ltchars);
    pub const IOCSPGRP = IOCTL.IOW('t', 118, c_int);
    pub const IOCGPGRP = IOCTL.IOR('t', 119, c_int);

    pub const IOCEXCL = 0x540c;
    pub const IOCNXCL = 0x540d;
    pub const IOCSCTTY = 0x540e;

    pub const IOCSTI = 0x5412;
    pub const IOCMGET = 0x5415;
    pub const IOCMBIS = 0x5416;
    pub const IOCMBIC = 0x5417;
    pub const IOCMSET = 0x5418;
    pub const IOCM_LE = 0x001;
    pub const IOCM_DTR = 0x002;
    pub const IOCM_RTS = 0x004;
    pub const IOCM_ST = 0x008;
    pub const IOCM_SR = 0x010;
    pub const IOCM_CTS = 0x020;
    pub const IOCM_CAR = 0x040;
    pub const IOCM_RNG = 0x080;
    pub const IOCM_DSR = 0x100;
    pub const IOCM_CD = IOCM_CAR;
    pub const IOCM_RI = IOCM_RNG;
    pub const IOCM_OUT1 = 0x2000;
    pub const IOCM_OUT2 = 0x4000;
    pub const IOCM_LOOP = 0x8000;

    pub const IOCGSOFTCAR = 0x5419;
    pub const IOCSSOFTCAR = 0x541a;
    pub const IOCLINUX = 0x541c;
    pub const IOCCONS = 0x541d;
    pub const IOCGSERIAL = 0x541e;
    pub const IOCSSERIAL = 0x541f;
    pub const IOCPKT = 0x5420;
    pub const IOCPKT_DATA = 0;
    pub const IOCPKT_FLUSHREAD = 1;
    pub const IOCPKT_FLUSHWRITE = 2;
    pub const IOCPKT_STOP = 4;
    pub const IOCPKT_START = 8;
    pub const IOCPKT_NOSTOP = 16;
    pub const IOCPKT_DOSTOP = 32;
    pub const IOCPKT_IOCTL = 64;

    pub const IOCNOTTY = 0x5422;
    pub const IOCSETD = 0x5423;
    pub const IOCGETD = 0x5424;
    pub const CSBRKP = 0x5425;
    pub const IOCSBRK = 0x5427;
    pub const IOCCBRK = 0x5428;
    pub const IOCGSID = 0x5429;
    pub const IOCGRS485 = 0x542e;
    pub const IOCSRS485 = 0x542f;
    pub const IOCGPTN = IOCTL.IOR('T', 0x30, c_uint);
    pub const IOCSPTLCK = IOCTL.IOW('T', 0x31, c_int);
    pub const IOCGDEV = IOCTL.IOR('T', 0x32, c_uint);
    pub const IOCSIG = IOCTL.IOW('T', 0x36, c_int);
    pub const IOCVHANGUP = 0x5437;
    pub const IOCGPKT = IOCTL.IOR('T', 0x38, c_int);
    pub const IOCGPTLCK = IOCTL.IOR('T', 0x39, c_int);
    pub const IOCGEXCL = IOCTL.IOR('T', 0x40, c_int);
    pub const IOCGPTPEER = IOCTL.IO('T', 0x41);
    pub const IOCGISO7816 = IOCTL.IOR('T', 0x42, serial_iso7816);
    pub const IOCSISO7816 = IOCTL.IOWR('T', 0x43, serial_iso7816);

    pub const IOCSERCONFIG = 0x5453;
    pub const IOCSERGWILD = 0x5454;
    pub const IOCSERSWILD = 0x5455;
    pub const IOCGLCKTRMIOS = 0x5456;
    pub const IOCSLCKTRMIOS = 0x5457;
    pub const IOCSERGSTRUCT = 0x5458;
    pub const IOCSERGETLSR = 0x5459;
    pub const IOCSER_TEMT = 0x01;
    pub const IOCSERGETMULTI = 0x545a;
    pub const IOCSERSETMULTI = 0x545b;

    pub const IOCMIWAIT = 0x545c;
    pub const IOCGICOUNT = 0x545d;
} else if (is_sparc) struct {
    // Entries with double-underscore prefix have not been translated as they are unsupported.

    pub const CGETA = IOCTL.IOR('T', 1, termio);
    pub const CSETA = IOCTL.IOW('T', 2, termio);
    pub const CSETAW = IOCTL.IOW('T', 3, termio);
    pub const CSETAF = IOCTL.IOW('T', 4, termio);
    pub const CSBRK = IOCTL.IO('T', 5);
    pub const CXONC = IOCTL.IO('T', 6);
    pub const CFLSH = IOCTL.IO('T', 7);
    pub const CGETS = IOCTL.IOR('T', 8, termios);
    pub const CSETS = IOCTL.IOW('T', 9, termios);
    pub const CSETSW = IOCTL.IOW('T', 10, termios);
    pub const CSETSF = IOCTL.IOW('T', 11, termios);
    pub const CGETS2 = IOCTL.IOR('T', 12, termios2);
    pub const CSETS2 = IOCTL.IOW('T', 13, termios2);
    pub const CSETSW2 = IOCTL.IOW('T', 14, termios2);
    pub const CSETSF2 = IOCTL.IOW('T', 15, termios2);
    pub const IOCGDEV = IOCTL.IOR('T', 0x32, c_uint);
    pub const IOCVHANGUP = IOCTL.IO('T', 0x37);
    pub const IOCGPKT = IOCTL.IOR('T', 0x38, c_int);
    pub const IOCGPTLCK = IOCTL.IOR('T', 0x39, c_int);
    pub const IOCGEXCL = IOCTL.IOR('T', 0x40, c_int);
    pub const IOCGRS485 = IOCTL.IOR('T', 0x41, serial_rs485);
    pub const IOCSRS485 = IOCTL.IOWR('T', 0x42, serial_rs485);
    pub const IOCGISO7816 = IOCTL.IOR('T', 0x43, serial_iso7816);
    pub const IOCSISO7816 = IOCTL.IOWR('T', 0x44, serial_iso7816);

    pub const IOCGETD = IOCTL.IOR('t', 0, c_int);
    pub const IOCSETD = IOCTL.IOW('t', 1, c_int);
    pub const IOCEXCL = IOCTL.IO('t', 13);
    pub const IOCNXCL = IOCTL.IO('t', 14);
    pub const IOCCONS = IOCTL.IO('t', 36);
    pub const IOCGSOFTCAR = IOCTL.IOR('t', 100, c_int);
    pub const IOCSSOFTCAR = IOCTL.IOW('t', 101, c_int);
    pub const IOCSWINSZ = IOCTL.IOW('t', 103, winsize);
    pub const IOCGWINSZ = IOCTL.IOR('t', 104, winsize);
    pub const IOCMGET = IOCTL.IOR('t', 106, c_int);
    pub const IOCMBIC = IOCTL.IOW('t', 107, c_int);
    pub const IOCMBIS = IOCTL.IOW('t', 108, c_int);
    pub const IOCMSET = IOCTL.IOW('t', 109, c_int);
    pub const IOCSTART = IOCTL.IO('t', 110);
    pub const IOCSTOP = IOCTL.IO('t', 111);
    pub const IOCPKT = IOCTL.IOW('t', 112, c_int);
    pub const IOCNOTTY = IOCTL.IO('t', 113);
    pub const IOCSTI = IOCTL.IOW('t', 114, c_char);
    pub const IOCOUTQ = IOCTL.IOR('t', 115, c_int);
    pub const IOCCBRK = IOCTL.IO('t', 122);
    pub const IOCSBRK = IOCTL.IO('t', 123);
    pub const IOCSPGRP = IOCTL.IOW('t', 130, c_int);
    pub const IOCGPGRP = IOCTL.IOR('t', 131, c_int);
    pub const IOCSCTTY = IOCTL.IO('t', 132);
    pub const IOCGSID = IOCTL.IOR('t', 133, c_int);
    pub const IOCGPTN = IOCTL.IOR('t', 134, c_uint);
    pub const IOCSPTLCK = IOCTL.IOW('t', 135, c_int);
    pub const IOCSIG = IOCTL.IOW('t', 136, c_int);
    pub const IOCGPTPEER = IOCTL.IO('t', 137);

    pub const FIOCLEX = IOCTL.IO('f', 1);
    pub const FIONCLEX = IOCTL.IO('f', 2);
    pub const FIOASYNC = IOCTL.IOW('f', 125, c_int);
    pub const FIONBIO = IOCTL.IOW('f', 126, c_int);
    pub const FIONREAD = IOCTL.IOR('f', 127, c_int);
    pub const IOCINQ = FIONREAD;
    pub const FIOQSIZE = IOCTL.IOR('f', 128, c_longlong); // loff_t -> __kernel_loff_t -> long long

    pub const IOCLINUX = 0x541c;
    pub const IOCGSERIAL = 0x541e;
    pub const IOCSSERIAL = 0x541f;
    pub const CSBRKP = 0x5425;
    pub const IOCSERCONFIG = 0x5453;
    pub const IOCSERGWILD = 0x5454;
    pub const IOCSERSWILD = 0x5455;
    pub const IOCGLCKTRMIOS = 0x5456;
    pub const IOCSLCKTRMIOS = 0x5457;
    pub const IOCSERGSTRUCT = 0x5458;
    pub const IOCSERGETLSR = 0x5459;
    pub const IOCSERGETMULTI = 0x545a;
    pub const IOCSERSETMULTI = 0x545b;
    pub const IOCMIWAIT = 0x545c;
    pub const IOCGICOUNT = 0x545d;

    pub const IOCPKT_DATA = 0;
    pub const IOCPKT_FLUSHREAD = 1;
    pub const IOCPKT_FLUSHWRITE = 2;
    pub const IOCPKT_STOP = 4;
    pub const IOCPKT_START = 8;
    pub const IOCPKT_NOSTOP = 16;
    pub const IOCPKT_DOSTOP = 32;
    pub const IOCPKT_IOCTL = 64;
} else struct {
    pub const CGETS = 0x5401;
    pub const CSETS = 0x5402;
    pub const CSETSW = 0x5403;
    pub const CSETSF = 0x5404;
    pub const CGETA = 0x5405;
    pub const CSETA = 0x5406;
    pub const CSETAW = 0x5407;
    pub const CSETAF = 0x5408;
    pub const CSBRK = 0x5409;
    pub const CXONC = 0x540a;
    pub const CFLSH = 0x540b;
    pub const IOCEXCL = 0x540c;
    pub const IOCNXCL = 0x540d;
    pub const IOCSCTTY = 0x540e;
    pub const IOCGPGRP = 0x540f;
    pub const IOCSPGRP = 0x5410;
    pub const IOCOUTQ = 0x5411;
    pub const IOCSTI = 0x5412;
    pub const IOCGWINSZ = 0x5413;
    pub const IOCSWINSZ = 0x5414;
    pub const IOCMGET = 0x5415;
    pub const IOCMBIS = 0x5416;
    pub const IOCMBIC = 0x5417;
    pub const IOCMSET = 0x5418;
    pub const IOCGSOFTCAR = 0x5419;
    pub const IOCSSOFTCAR = 0x541a;
    pub const FIONREAD = 0x541b;
    pub const IOCINQ = FIONREAD;
    pub const IOCLINUX = 0x541c;
    pub const IOCCONS = 0x541d;
    pub const IOCGSERIAL = 0x541e;
    pub const IOCSSERIAL = 0x541f;
    pub const IOCPKT = 0x5420;
    pub const FIONBIO = 0x5421;
    pub const IOCNOTTY = 0x5422;
    pub const IOCSETD = 0x5423;
    pub const IOCGETD = 0x5424;
    pub const CSBRKP = 0x5425;
    pub const IOCSBRK = 0x5427;
    pub const IOCCBRK = 0x5428;
    pub const IOCGSID = 0x5429;
    pub const CGETS2 = IOCTL.IOR('T', 0x2a, termios2);
    pub const CSETS2 = IOCTL.IOW('T', 0x2b, termios2);
    pub const CSETSW2 = IOCTL.IOW('T', 0x2c, termios2);
    pub const CSETSF2 = IOCTL.IOW('T', 0x2d, termios2);
    pub const IOCGRS485 = 0x542e;
    pub const IOCSRS485 = 0x542f;
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
    pub const IOCGPTPEER = IOCTL.IO('T', 0x41);
    pub const IOCGISO7816 = IOCTL.IOR('T', 0x42, serial_iso7816);
    pub const IOCSISO7816 = IOCTL.IOWR('T', 0x43, serial_iso7816);

    pub const FIONCLEX = 0x5450;
    pub const FIOCLEX = 0x5451;
    pub const FIOASYNC = 0x5452;
    pub const IOCSERCONFIG = 0x5453;
    pub const IOCSERGWILD = 0x5454;
    pub const IOCSERSWILD = 0x5455;
    pub const IOCGLCKTRMIOS = 0x5456;
    pub const IOCSLCKTRMIOS = 0x5457;
    pub const IOCSERGSTRUCT = 0x5458;
    pub const IOCSERGETLSR = 0x5459;
    pub const IOCSERGETMULTI = 0x545a;
    pub const IOCSERSETMULTI = 0x545b;

    pub const IOCMIWAIT = 0x545c;
    pub const IOCGICOUNT = 0x545d;

    pub const FIOQSIZE = switch (native_arch) {
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .m68k,
        .s390x,
        => 0x545e,
        else => 0x5460,
    };

    pub const IOCPKT_DATA = 0;
    pub const IOCPKT_FLUSHREAD = 1;
    pub const IOCPKT_FLUSHWRITE = 2;
    pub const IOCPKT_STOP = 4;
    pub const IOCPKT_START = 8;
    pub const IOCPKT_NOSTOP = 16;
    pub const IOCPKT_DOSTOP = 32;
    pub const IOCPKT_IOCTL = 64;

    pub const IOCSER_TEMT = 0x01;
};

pub const serial_rs485 = extern struct {
    flags: u32,
    delay_rts_before_send: u32,
    delay_rts_after_send: u32,
    extra: extern union {
        _pad1: [5]u32,
        s: extern struct {
            addr_recv: u8,
            addr_dest: u8,
            _pad2: [2]u8,
            _pad3: [4]u32,
        },
    },
};

pub const serial_iso7816 = extern struct {
    flags: u32,
    tg: u32,
    sc_fi: u32,
    sc_di: u32,
    clk: u32,
    _reserved: [5]u32,
};

pub const SER = struct {
    pub const RS485 = struct {
        pub const ENABLED = 1 << 0;
        pub const RTS_ON_SEND = 1 << 1;
        pub const RTS_AFTER_SEND = 1 << 2;
        pub const RX_DURING_TX = 1 << 4;
        pub const TERMINATE_BUS = 1 << 5;
        pub const ADDRB = 1 << 6;
        pub const ADDR_RECV = 1 << 7;
        pub const ADDR_DEST = 1 << 8;
    };

    pub const ISO7816 = struct {
        pub const ENABLED = 1 << 0;
        pub const T_PARAM = 0x0f << 4;

        pub fn T(t: anytype) @TypeOf(t) {
            return (t & 0x0f) << 4;
        }
    };
};

/// Valid opcodes to issue to sys_epoll_ctl()
pub const EpollOp = enum(u32) {
    ctl_add = 1,
    ctl_del = 2,
    ctl_mod = 3,
    _,

    // Deprecated Constants
    pub const CTL_ADD: u32 = @intFromEnum(EpollOp.ctl_add);
    pub const CTL_DEL: u32 = @intFromEnum(EpollOp.ctl_del);
    pub const CTL_MOD: u32 = @intFromEnum(EpollOp.ctl_mod);
};

/// Deprecated alias for Epoll
pub const EPOLL = Epoll;
/// Epoll event masks
// https://github.com/torvalds/linux/blob/18a7e218cfcdca6666e1f7356533e4c988780b57/include/uapi/linux/eventpoll.h#L30
pub const Epoll = if (is_mips) packed struct(u32) {
    // EPOLL event types (lower 16 bits)
    //
    /// The associated file is available for read(2) operations
    in: bool = false,
    /// There is an exceptional condition on the file descriptor
    pri: bool = false,
    /// The associated file is available for write(2) operations
    out: bool = false,
    /// Error condition happened on the associated file descriptor
    err: bool = false,
    /// Hang up happened on the associated file descriptor
    hup: bool = false,
    /// Invalid request: fd not open
    nval: bool = false,
    /// Normal data may be read
    rdnorm: bool = false,
    /// Priority data may be read
    rdband: bool = false,
    /// Priority data may be written
    wrband: bool = false,
    _10: u1 = 0,
    /// Message available (unused on Linux)
    msg: bool = false,
    _12: u2 = 0,
    /// Stream socket peer closed connection
    rdhup: bool = false,
    _15: u13 = 0,
    // EPOLL input flags (Higher order flags are included as internal stat)
    //
    /// Internal flag - wakeup generated by io_uring, used to detect
    /// recursion back into the io_uring poll handler
    uring_wake: bool = false,
    /// Set exclusive wakeup mode for the target file descriptor
    exclusive: bool = false,
    /// Request the handling of system wakeup events so as to prevent system
    /// suspends from happening while those events are being processed.
    /// Assuming neither EPOLLET nor EPOLLONESHOT is set, system suspends will
    /// not be re-allowed until epoll_wait is called again after consuming the
    /// wakeup event(s).
    /// Requires CAP_BLOCK_SUSPEND
    wakeup: bool = false,
    /// Set the One Shot behaviour for the target file descriptor
    oneshot: bool = false,
    /// Set the Edge Triggered behaviour for the target file descriptor
    et: bool = false,

    /// Alias to out on Mips
    /// Writing is now possible (normal data)
    pub const wrnorm: Epoll = .{ .out = true };

    // Deprecated Named constants
    // EPOLL event types
    pub const IN: u32 = @bitCast(Epoll{ .in = true });
    pub const PRI: u32 = @bitCast(Epoll{ .pri = true });
    pub const OUT: u32 = @bitCast(Epoll{ .out = true });
    pub const ERR: u32 = @bitCast(Epoll{ .err = true });
    pub const HUP: u32 = @bitCast(Epoll{ .hup = true });
    pub const NVAL: u32 = @bitCast(Epoll{ .nval = true });
    pub const RDNORM: u32 = @bitCast(Epoll{ .rdnorm = true });
    pub const RDBAND: u32 = @bitCast(Epoll{ .rdband = true });
    pub const WRNORM: u32 = @bitCast(wrnorm);
    pub const WRBAND: u32 = @bitCast(Epoll{ .wrband = true });
    pub const MSG: u32 = @bitCast(Epoll{ .msg = true });
    pub const RDHUP: u32 = @bitCast(Epoll{ .rdhup = true });

    // EPOLL input flags
    pub const URING_WAKE: u32 = @bitCast(Epoll{ .uring_wake = true });
    pub const EXCLUSIVE: u32 = @bitCast(Epoll{ .exclusive = true });
    pub const WAKEUP: u32 = @bitCast(Epoll{ .wakeup = true });
    pub const ONESHOT: u32 = @bitCast(Epoll{ .oneshot = true });
    pub const ET: u32 = @bitCast(Epoll{ .et = true });

    /// Flags for epoll_create1
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");

    // Deprecated Op Constants use EpollOp enum type
    pub const CTL_ADD: u32 = @intFromEnum(EpollOp.ctl_add);
    pub const CTL_DEL: u32 = @intFromEnum(EpollOp.ctl_del);
    pub const CTL_MOD: u32 = @intFromEnum(EpollOp.ctl_mod);
} else packed struct(u32) {
    // EPOLL event types (lower 16 bits)
    //
    /// The associated file is available for read(2) operations
    in: bool = false,
    /// There is an exceptional condition on the file descriptor
    pri: bool = false,
    /// The associated file is available for write(2) operations
    out: bool = false,
    /// Error condition happened on the associated file descriptor
    err: bool = false,
    /// Hang up happened on the associated file descriptor
    hup: bool = false,
    /// Invalid request: fd not open
    nval: bool = false,
    /// Normal data may be read
    rdnorm: bool = false,
    /// Priority data may be read
    rdband: bool = false,
    // COMMIT: new flags
    /// Writing is now possible (normal data)
    wrnorm: bool = false,
    /// Priority data may be written
    wrband: bool = false,
    /// Message available (unused on Linux)
    msg: bool = false,
    _12: u2 = 0,
    /// Stream socket peer closed connection
    rdhup: bool = false,
    _15: u13 = 0,
    // EPOLL input flags (Higher order flags are included as internal stat)
    //
    /// Internal flag - wakeup generated by io_uring, used to detect
    /// recursion back into the io_uring poll handler
    uring_wake: bool = false,
    /// Set exclusive wakeup mode for the target file descriptor
    exclusive: bool = false,
    /// Request the handling of system wakeup events so as to prevent system
    /// suspends from happening while those events are being processed.
    /// Assuming neither EPOLLET nor EPOLLONESHOT is set, system suspends will
    /// not be re-allowed until epoll_wait is called again after consuming the
    /// wakeup event(s).
    /// Requires CAP_BLOCK_SUSPEND
    wakeup: bool = false,
    /// Set the One Shot behaviour for the target file descriptor
    oneshot: bool = false,
    /// Set the Edge Triggered behaviour for the target file descriptor
    et: bool = false,

    // Deprecated Named constants
    // EPOLL event types
    pub const IN: u32 = @bitCast(Epoll{ .in = true });
    pub const PRI: u32 = @bitCast(Epoll{ .pri = true });
    pub const OUT: u32 = @bitCast(Epoll{ .out = true });
    pub const ERR: u32 = @bitCast(Epoll{ .err = true });
    pub const HUP: u32 = @bitCast(Epoll{ .hup = true });
    pub const NVAL: u32 = @bitCast(Epoll{ .nval = true });
    pub const RDNORM: u32 = @bitCast(Epoll{ .rdnorm = true });
    pub const RDBAND: u32 = @bitCast(Epoll{ .rdband = true });
    pub const WRNORM: u32 = @bitCast(Epoll{ .wrnorm = true });
    pub const WRBAND: u32 = @bitCast(Epoll{ .wrband = true });
    pub const MSG: u32 = @bitCast(Epoll{ .msg = true });
    pub const RDHUP: u32 = @bitCast(Epoll{ .rdhup = true });

    // EPOLL input flags
    pub const URING_WAKE: u32 = @bitCast(Epoll{ .uring_wake = true });
    pub const EXCLUSIVE: u32 = @bitCast(Epoll{ .exclusive = true });
    pub const WAKEUP: u32 = @bitCast(Epoll{ .wakeup = true });
    pub const ONESHOT: u32 = @bitCast(Epoll{ .oneshot = true });
    pub const ET: u32 = @bitCast(Epoll{ .et = true });

    /// Flags for epoll_create1
    pub const CLOEXEC = 1 << @bitOffsetOf(O, "CLOEXEC");

    // Deprecated Op Constants use EpollOp enum type
    pub const CTL_ADD: u32 = @intFromEnum(EpollOp.ctl_add);
    pub const CTL_DEL: u32 = @intFromEnum(EpollOp.ctl_del);
    pub const CTL_MOD: u32 = @intFromEnum(EpollOp.ctl_mod);
};

pub const CLOCK = clockid_t;

pub const clockid_t = enum(u32) {
    REALTIME = 0,
    MONOTONIC = 1,
    PROCESS_CPUTIME_ID = 2,
    THREAD_CPUTIME_ID = 3,
    MONOTONIC_RAW = 4,
    REALTIME_COARSE = 5,
    MONOTONIC_COARSE = 6,
    BOOTTIME = 7,
    REALTIME_ALARM = 8,
    BOOTTIME_ALARM = 9,
    // In the linux kernel header file (time.h) is the following note:
    // * The driver implementing this got removed. The clock ID is kept as a
    // * place holder. Do not reuse!
    // Therefore, calling clock_gettime() with these IDs will result in an error.
    //
    // Some backgrond:
    // - SGI_CYCLE was for Silicon Graphics (SGI) workstations,
    // which are probably no longer in use, so it makes sense to disable
    // - TAI_CLOCK was designed as CLOCK_REALTIME(UTC) + tai_offset,
    // but tai_offset was always 0 in the kernel.
    // So there is no point in using this clock.
    // SGI_CYCLE = 10,
    // TAI = 11,
    _,
};

// For use with posix.timerfd_create()
// Actually, the parameter for the timerfd_create() function is in integer,
// which means that the developer has to figure out which value is appropriate.
// To make this easier and, above all, safer, because an incorrect value leads
// to a panic, an enum is introduced which only allows the values
// that actually work.
pub const TIMERFD_CLOCK = timerfd_clockid_t;
pub const timerfd_clockid_t = enum(u32) {
    REALTIME = 0,
    MONOTONIC = 1,
    BOOTTIME = 7,
    REALTIME_ALARM = 8,
    BOOTTIME_ALARM = 9,
    _,
};

pub const TIMER = packed struct(u32) {
    ABSTIME: bool,
    _: u31 = 0,
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

pub const fanotify = struct {
    pub const InitFlags = packed struct(u32) {
        CLOEXEC: bool = false,
        NONBLOCK: bool = false,
        CLASS: enum(u2) {
            NOTIF = 0,
            CONTENT = 1,
            PRE_CONTENT = 2,
        } = .NOTIF,
        UNLIMITED_QUEUE: bool = false,
        UNLIMITED_MARKS: bool = false,
        ENABLE_AUDIT: bool = false,
        REPORT_PIDFD: bool = false,
        REPORT_TID: bool = false,
        REPORT_FID: bool = false,
        REPORT_DIR_FID: bool = false,
        REPORT_NAME: bool = false,
        REPORT_TARGET_FID: bool = false,
        _: u19 = 0,
    };

    pub const MarkFlags = packed struct(u32) {
        ADD: bool = false,
        REMOVE: bool = false,
        DONT_FOLLOW: bool = false,
        ONLYDIR: bool = false,
        MOUNT: bool = false,
        /// Mutually exclusive with `IGNORE`
        IGNORED_MASK: bool = false,
        IGNORED_SURV_MODIFY: bool = false,
        FLUSH: bool = false,
        FILESYSTEM: bool = false,
        EVICTABLE: bool = false,
        /// Mutually exclusive with `IGNORED_MASK`
        IGNORE: bool = false,
        _: u21 = 0,
    };

    pub const MarkMask = packed struct(u64) {
        /// File was accessed
        ACCESS: bool = false,
        /// File was modified
        MODIFY: bool = false,
        /// Metadata changed
        ATTRIB: bool = false,
        /// Writtable file closed
        CLOSE_WRITE: bool = false,
        /// Unwrittable file closed
        CLOSE_NOWRITE: bool = false,
        /// File was opened
        OPEN: bool = false,
        /// File was moved from X
        MOVED_FROM: bool = false,
        /// File was moved to Y
        MOVED_TO: bool = false,

        /// Subfile was created
        CREATE: bool = false,
        /// Subfile was deleted
        DELETE: bool = false,
        /// Self was deleted
        DELETE_SELF: bool = false,
        /// Self was moved
        MOVE_SELF: bool = false,
        /// File was opened for exec
        OPEN_EXEC: bool = false,
        reserved13: u1 = 0,
        /// Event queued overflowed
        Q_OVERFLOW: bool = false,
        /// Filesystem error
        FS_ERROR: bool = false,

        /// File open in perm check
        OPEN_PERM: bool = false,
        /// File accessed in perm check
        ACCESS_PERM: bool = false,
        /// File open/exec in perm check
        OPEN_EXEC_PERM: bool = false,
        reserved19: u8 = 0,
        /// Interested in child events
        EVENT_ON_CHILD: bool = false,
        /// File was renamed
        RENAME: bool = false,
        reserved30: u1 = 0,
        /// Event occurred against dir
        ONDIR: bool = false,
        reserved31: u33 = 0,
    };

    pub const event_metadata = extern struct {
        event_len: u32,
        vers: u8,
        reserved: u8,
        metadata_len: u16,
        mask: MarkMask align(8),
        fd: i32,
        pid: i32,

        pub const VERSION = 3;
    };

    pub const response = extern struct {
        fd: i32,
        response: u32,
    };

    /// Unique file identifier info record.
    ///
    /// This structure is used for records of types `EVENT_INFO_TYPE.FID`.
    /// `EVENT_INFO_TYPE.DFID` and `EVENT_INFO_TYPE.DFID_NAME`.
    ///
    /// For `EVENT_INFO_TYPE.DFID_NAME` there is additionally a null terminated
    /// name immediately after the file handle.
    pub const event_info_fid = extern struct {
        hdr: event_info_header,
        fsid: kernel_fsid_t,
        /// Following is an opaque struct file_handle that can be passed as
        /// an argument to open_by_handle_at(2).
        handle: [0]u8,
    };

    /// Variable length info record following event metadata.
    pub const event_info_header = extern struct {
        info_type: EVENT_INFO_TYPE,
        pad: u8,
        len: u16,
    };

    pub const EVENT_INFO_TYPE = enum(u8) {
        FID = 1,
        DFID_NAME = 2,
        DFID = 3,
        PIDFD = 4,
        ERROR = 5,
        OLD_DFID_NAME = 10,
        OLD_DFID = 11,
        NEW_DFID_NAME = 12,
        NEW_DFID = 13,
    };
};

pub const file_handle = extern struct {
    handle_bytes: u32,
    handle_type: i32,
    f_handle: [0]u8,
};

pub const kernel_fsid_t = fsid_t;
pub const fsid_t = [2]i32;

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

const k_sigaction_funcs = struct {
    const handler = ?*align(1) const fn (SIG) callconv(.c) void;
    const restorer = *const fn () callconv(.c) void;
};

/// Kernel sigaction struct, as expected by the `rt_sigaction` syscall.  Includes `restorer` on
/// targets where userspace is responsible for hooking up `rt_sigreturn`.
pub const k_sigaction = switch (native_arch) {
    .mips, .mipsel, .mips64, .mips64el => extern struct {
        flags: c_uint,
        handler: k_sigaction_funcs.handler,
        mask: sigset_t,
    },
    .hexagon, .loongarch32, .loongarch64, .or1k, .riscv32, .riscv64 => extern struct {
        handler: k_sigaction_funcs.handler,
        flags: c_ulong,
        mask: sigset_t,
    },
    else => extern struct {
        handler: k_sigaction_funcs.handler,
        flags: c_ulong,
        restorer: k_sigaction_funcs.restorer,
        mask: sigset_t,
    },
};

/// Kernel Sigaction wrapper for the actual ABI `k_sigaction`.  The Zig
/// linux.zig wrapper library still does some pre-processing on
/// sigaction() calls (to add the `restorer` field).
///
/// Renamed from `sigaction` to `Sigaction` to avoid conflict with the syscall.
pub const Sigaction = struct {
    pub const handler_fn = *align(1) const fn (SIG) callconv(.c) void;
    pub const sigaction_fn = *const fn (SIG, *const siginfo_t, ?*anyopaque) callconv(.c) void;

    handler: extern union {
        handler: ?handler_fn,
        sigaction: ?sigaction_fn,
    },
    mask: sigset_t,
    flags: switch (native_arch) {
        .mips, .mipsel, .mips64, .mips64el => c_uint,
        else => c_ulong,
    },
};

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
// TODO: change to AF type
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
        family: sa_family_t = Af.INET,
        port: in_port_t,
        addr: u32,
        zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    /// IPv6 socket address
    pub const in6 = extern struct {
        family: sa_family_t = Af.INET6,
        port: in_port_t,
        flowinfo: u32,
        addr: [16]u8,
        scope_id: u32,
    };

    /// UNIX domain socket address
    pub const un = extern struct {
        family: sa_family_t = Af.UNIX,
        path: [108]u8,
    };

    /// Packet socket address
    pub const ll = extern struct {
        family: sa_family_t = Af.PACKET,
        protocol: u16,
        ifindex: i32,
        hatype: u16,
        pkttype: u8,
        halen: u8,
        addr: [8]u8,
    };

    /// Netlink socket address
    pub const nl = extern struct {
        family: sa_family_t = Af.NETLINK,
        __pad1: c_ushort = 0,

        /// port ID
        pid: u32,

        /// multicast groups mask
        groups: u32,
    };

    pub const xdp = extern struct {
        family: u16 = Af.XDP,
        flags: u16,
        ifindex: u32,
        queue_id: u32,
        shared_umem_fd: u32,
    };

    /// Address structure for vSockets
    pub const vm = extern struct {
        family: sa_family_t = Af.VSOCK,
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
    hdr: msghdr,
    len: u32,
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
pub const VFS_CAP_FLAGS_MASK = ~@as(u32, VFS_CAP_REVISION_MASK);
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
    const Data = extern struct {
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
    addr: usize,
    name: ?[*:0]const u8,
    phdr: [*]std.elf.ElfN.Phdr,
    phnum: u16,
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
    .arc,
    .arceb,
    .arm,
    .armeb,
    .csky,
    .hexagon,
    .m68k,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .or1k,
    .powerpc,
    .powerpcle,
    .riscv32,
    .riscv64,
    .s390x,
    .thumb,
    .thumbeb,
    .x86,
    .x86_64,
    .xtensa,
    .xtensaeb,
    => 2048,
    .loongarch64,
    .sparc,
    .sparc64,
    => 4096,
    .aarch64,
    .aarch64_be,
    => 5120,
    .powerpc64,
    .powerpc64le,
    => 8192,
    else => @compileError("MINSIGSTKSZ not defined for this architecture"),
};
pub const SIGSTKSZ = switch (native_arch) {
    .arc,
    .arceb,
    .arm,
    .armeb,
    .csky,
    .hexagon,
    .m68k,
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .or1k,
    .powerpc,
    .powerpcle,
    .riscv32,
    .riscv64,
    .s390x,
    .thumb,
    .thumbeb,
    .x86,
    .x86_64,
    .xtensa,
    .xtensaeb,
    => 8192,
    .aarch64,
    .aarch64_be,
    .loongarch64,
    .sparc,
    .sparc64,
    => 16384,
    .powerpc64,
    .powerpc64le,
    => 32768,
    else => @compileError("SIGSTKSZ not defined for this architecture"),
};

pub const SS = struct {
    pub const ONSTACK = 1;
    pub const DISABLE = 2;
    pub const AUTODISARM = 1 << 31;
};

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
        signo: SIG,
        code: i32,
        errno: i32,
        fields: siginfo_fields_union,
    }
else
    extern struct {
        signo: SIG,
        errno: i32,
        code: i32,
        fields: siginfo_fields_union,
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

// COMMIT: RenameFlags
pub const Rename = packed struct(u32) {
    /// Don't overwrite target
    noreplace: bool = false,
    /// Exchange source and dest
    exchange: bool = false,
    /// Whiteout source
    whiteout: bool = false,
    _: u29 = 0,
};

pub const SetXattr = packed struct(u32) {
    _: u32 = 0, // TODO: add flags
};
pub const statx_timestamp = extern struct {
    sec: i64,
    nsec: u32,
    __pad1: u32,
};

/// Renamed to `Statx` to not conflict with the `statx` function.
pub const Statx = extern struct {
    /// Mask of bits indicating filled fields
    mask: Mask,

    /// Block size for filesystem I/O
    blksize: u32,

    /// Extra file attribute indicators
    attributes: Attr,

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
    attributes_mask: Attr,

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

    // COMMIT: add new StatxMask fields
    // https://github.com/torvalds/linux/blob/755fa5b4fb36627796af19932a432d343220ec63/include/uapi/linux/stat.h#L203
    /// matches STATX_* in kernel
    pub const Mask = packed struct(u32) {
        type: bool = false,
        /// Want/got stx_mode & ~S_IFMT
        mode: bool = false,
        /// Want/got stx_nlink
        nlink: bool = false,
        /// Want/got stx_uid
        uid: bool = false,
        /// Want/got stx_gid
        gid: bool = false,
        /// Want/got stx_atime
        atime: bool = false,
        /// Want/got stx_mtime
        mtime: bool = false,
        /// Want/got stx_ctime
        ctime: bool = false,
        /// Want/got stx_ino
        ino: bool = false,
        /// Want/got stx_size
        size: bool = false,
        /// Want/got stx_blocks
        blocks: bool = false,
        /// Want/got stx_btime
        btime: bool = false,
        /// Got stx_mnt_id
        mnt_id: bool = false,
        /// Want/got direct I/O alignment info
        dioalign: bool = false,
        /// Want/got extended stx_mount_id
        mnt_id_unique: bool = false,
        /// Want/got stx_subvol
        subvol: bool = false,
        /// Want/got atomic_write_* fields
        write_atomic: bool = false,
        /// Want/got dio read alignment info
        dio_read_align: bool = false,
        /// Reserved for future struct statx expansion
        _: u14 = 0,

        /// The stuff in the normal stat struct (bits 0-10)
        pub const basic_stats: Mask = .{
            .type = true,
            .mode = true,
            .nlink = true,
            .uid = true,
            .gid = true,
            .atime = true,
            .mtime = true,
            .ctime = true,
            .ino = true,
            .size = true,
            .blocks = true,
        };
    };

    // COMMIT: Statx as Packed Struct
    // https://github.com/torvalds/linux/blob/755fa5b4fb36627796af19932a432d343220ec63/include/uapi/linux/stat.h#L248
    /// matches STATX_ATTR_* in kernel
    pub const Attr = packed struct(u64) {
        _0: u2 = 0,
        /// File is compressed by the fs
        compressed: bool = false,
        _1: u1 = 0,
        /// File is marked immutable
        immutable: bool = false,
        /// File is append-only
        append: bool = false,
        /// File is not to be dumped
        nodump: bool = false,
        _2: u4 = 0,
        /// File requires key to decrypt in fs
        encrypted: bool = false,
        /// Dir: Automount trigger
        automount: bool = false,
        /// Root of a mount
        mount_root: bool = false,
        _3: u6 = 0,
        /// Verity protected file
        verity: bool = false,
        /// File is currently in DAX state
        dax: bool = false,
        /// File supports atomic write operations
        write_atomic: bool = false,
        _: u41 = 0,
    };
};

// DEPRECATED aliases to Statx.Mask and Statx.Attr
const STATX_TYPE: u32 = @bitCast(Statx.Mask{ .type = true });
const STATX_MODE: u32 = @bitCast(Statx.Mask{ .mode = true });
const STATX_NLINK: u32 = @bitCast(Statx.Mask{ .nlink = true });
const STATX_UID: u32 = @bitCast(Statx.Mask{ .uid = true });
const STATX_GID: u32 = @bitCast(Statx.Mask{ .gid = true });
const STATX_ATIME: u32 = @bitCast(Statx.Mask{ .atime = true });
const STATX_MTIME: u32 = @bitCast(Statx.Mask{ .mtime = true });
const STATX_CTIME: u32 = @bitCast(Statx.Mask{ .ctime = true });
const STATX_INO: u32 = @bitCast(Statx.Mask{ .ino = true });
const STATX_SIZE: u32 = @bitCast(Statx.Mask{ .size = true });
const STATX_BLOCKS: u32 = @bitCast(Statx.Mask{ .blocks = true });
const STATX_BASIC_STATS: u32 = @bitCast(Statx.Mask.basic_stats);
const STATX_BTIME: u32 = @bitCast(Statx.Mask{ .btime = true });
const STATX_MNT_ID: u32 = @bitCast(Statx.Mask{ .mnt_id = true });
const STATX_DIOALIGN: u32 = @bitCast(Statx.Mask{ .dioalign = true });
const STATX_MNT_ID_UNIQUE: u32 = @bitCast(Statx.Mask{ .mnt_id_unique = true });
const STATX_SUBVOL: u32 = @bitCast(Statx.Mask{ .subvol = true });
const STATX_WRITE_ATOMIC: u32 = @bitCast(Statx.Mask{ .write_atomic = true });
const STATX_DIO_READ_ALIGN: u32 = @bitCast(Statx.Mask{ .dio_read_align = true });

const STATX_ATTR_COMPRESSED: u64 = @bitCast(Statx.Attr{ .compressed = true });
const STATX_ATTR_IMMUTABLE: u64 = @bitCast(Statx.Attr{ .immutable = true });
const STATX_ATTR_APPEND: u64 = @bitCast(Statx.Attr{ .append = true });
const STATX_ATTR_NODUMP: u64 = @bitCast(Statx.Attr{ .nodump = true });
const STATX_ATTR_ENCRYPTED: u64 = @bitCast(Statx.Attr{ .encrypted = true });
const STATX_ATTR_AUTOMOUNT: u64 = @bitCast(Statx.Attr{ .automount = true });
const STATX_ATTR_MOUNT_ROOT: u64 = @bitCast(Statx.Attr{ .mount_root = true });
const STATX_ATTR_VERITY: u64 = @bitCast(Statx.Attr{ .verity = true });
const STATX_ATTR_DAX: u64 = @bitCast(Statx.Attr{ .dax = true });
const STATX_ATTR_WRITE_ATOMIC: u64 = @bitCast(Statx.Attr{ .write_atomic = true });

pub const addrinfo = extern struct {
    flags: AI,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: socklen_t,
    addr: ?*sockaddr,
    canonname: ?[*:0]u8,
    next: ?*addrinfo,
};

pub const AI = packed struct(u32) {
    PASSIVE: bool = false,
    CANONNAME: bool = false,
    NUMERICHOST: bool = false,
    V4MAPPED: bool = false,
    ALL: bool = false,
    ADDRCONFIG: bool = false,
    _6: u4 = 0,
    NUMERICSERV: bool = false,
    _: u21 = 0,
};

pub const IPPORT_RESERVED = 1024;

/// Deprecated alias to IpProto
pub const IPPROTO = IpProto;
/// IP Protocol numbers
pub const IpProto = enum(u16) {
    ip = 0,
    icmp = 1,
    igmp = 2,
    ipip = 4,
    tcp = 6,
    egp = 8,
    pup = 12,
    udp = 17,
    idp = 22,
    tp = 29,
    dccp = 33,
    ipv6 = 41,
    routing = 43,
    fragment = 44,
    rsvp = 46,
    gre = 47,
    esp = 50,
    ah = 51,
    icmpv6 = 58,
    none = 59,
    dstopts = 60,
    mtp = 92,
    beetph = 94,
    encap = 98,
    pim = 103,
    comp = 108,
    sctp = 132,
    mh = 135,
    udplite = 136,
    mpls = 137,
    raw = 255,
    max = 256,
    _,

    // Aliases
    pub const hopopts = IpProto.ip;
    pub const default = IpProto.ip;

    // Deprecated constants use enum instead
    // Legacy constants for backward compatibility
    pub const IP: u16 = @intFromEnum(IpProto.ip);
    pub const HOPOPTS: u16 = @intFromEnum(hopopts);
    pub const ICMP: u16 = @intFromEnum(IpProto.icmp);
    pub const IGMP: u16 = @intFromEnum(IpProto.igmp);
    pub const IPIP: u16 = @intFromEnum(IpProto.ipip);
    pub const TCP: u16 = @intFromEnum(IpProto.tcp);
    pub const EGP: u16 = @intFromEnum(IpProto.egp);
    pub const PUP: u16 = @intFromEnum(IpProto.pup);
    pub const UDP: u16 = @intFromEnum(IpProto.udp);
    pub const IDP: u16 = @intFromEnum(IpProto.idp);
    pub const TP: u16 = @intFromEnum(IpProto.tp);
    pub const DCCP: u16 = @intFromEnum(IpProto.dccp);
    pub const IPV6: u16 = @intFromEnum(IpProto.ipv6);
    pub const ROUTING: u16 = @intFromEnum(IpProto.routing);
    pub const FRAGMENT: u16 = @intFromEnum(IpProto.fragment);
    pub const RSVP: u16 = @intFromEnum(IpProto.rsvp);
    pub const GRE: u16 = @intFromEnum(IpProto.gre);
    pub const ESP: u16 = @intFromEnum(IpProto.esp);
    pub const AH: u16 = @intFromEnum(IpProto.ah);
    pub const ICMPV6: u16 = @intFromEnum(IpProto.icmpv6);
    pub const NONE: u16 = @intFromEnum(IpProto.none);
    pub const DSTOPTS: u16 = @intFromEnum(IpProto.DSTOPTS);
    pub const MTP: u16 = @intFromEnum(IpProto.mtp);
    pub const BEETPH: u16 = @intFromEnum(IpProto.beetph);
    pub const ENCAP: u16 = @intFromEnum(IpProto.encap);
    pub const PIM: u16 = @intFromEnum(IpProto.pim);
    pub const COMP: u16 = @intFromEnum(IpProto.comp);
    pub const SCTP: u16 = @intFromEnum(IpProto.sctp);
    pub const MH: u16 = @intFromEnum(IpProto.mh);
    pub const UDPLITE: u16 = @intFromEnum(IpProto.udplite);
    pub const MPLS: u16 = @intFromEnum(IpProto.mpls);
    pub const RAW: u16 = @intFromEnum(IpProto.raw);
    pub const MAX: u16 = @intFromEnum(IpProto.max);
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

pub const NCC = if (is_ppc) 10 else 8;
pub const NCCS = if (is_mips) 32 else if (is_ppc) 19 else if (is_sparc) 17 else 32;

pub const speed_t = if (is_ppc) enum(c_uint) {
    B0 = 0x0000000,
    B50 = 0x0000001,
    B75 = 0x0000002,
    B110 = 0x0000003,
    B134 = 0x0000004,
    B150 = 0x0000005,
    B200 = 0x0000006,
    B300 = 0x0000007,
    B600 = 0x0000008,
    B1200 = 0x0000009,
    B1800 = 0x000000a,
    B2400 = 0x000000b,
    B4800 = 0x000000c,
    B9600 = 0x000000d,
    B19200 = 0x000000e,
    B38400 = 0x000000f,

    B57600 = 0x00000010,
    B115200 = 0x00000011,
    B230400 = 0x00000012,
    B460800 = 0x00000013,
    B500000 = 0x00000014,
    B576000 = 0x00000015,
    B921600 = 0x00000016,
    B1000000 = 0x00000017,
    B1152000 = 0x00000018,
    B1500000 = 0x00000019,
    B2000000 = 0x0000001a,
    B2500000 = 0x0000001b,
    B3000000 = 0x0000001c,
    B3500000 = 0x0000001d,
    B4000000 = 0x0000001e,

    pub const EXTA = speed_t.B19200;
    pub const EXTB = speed_t.B38400;
} else if (is_sparc) enum(c_uint) {
    B0 = 0x0000000,
    B50 = 0x0000001,
    B75 = 0x0000002,
    B110 = 0x0000003,
    B134 = 0x0000004,
    B150 = 0x0000005,
    B200 = 0x0000006,
    B300 = 0x0000007,
    B600 = 0x0000008,
    B1200 = 0x0000009,
    B1800 = 0x000000a,
    B2400 = 0x000000b,
    B4800 = 0x000000c,
    B9600 = 0x000000d,
    B19200 = 0x000000e,
    B38400 = 0x000000f,

    B57600 = 0x00001001,
    B115200 = 0x00001002,
    B230400 = 0x00001003,
    B460800 = 0x00001004,
    B76800 = 0x00001005,
    B153600 = 0x00001006,
    B307200 = 0x00001007,
    B614400 = 0x00001008,
    B921600 = 0x00001009,
    B500000 = 0x0000100a,
    B576000 = 0x0000100b,
    B1000000 = 0x0000100c,
    B1152000 = 0x0000100d,
    B1500000 = 0x0000100e,
    B2000000 = 0x0000100f,

    pub const EXTA = speed_t.B19200;
    pub const EXTB = speed_t.B38400;
} else enum(c_uint) {
    B0 = 0x0000000,
    B50 = 0x0000001,
    B75 = 0x0000002,
    B110 = 0x0000003,
    B134 = 0x0000004,
    B150 = 0x0000005,
    B200 = 0x0000006,
    B300 = 0x0000007,
    B600 = 0x0000008,
    B1200 = 0x0000009,
    B1800 = 0x000000a,
    B2400 = 0x000000b,
    B4800 = 0x000000c,
    B9600 = 0x000000d,
    B19200 = 0x000000e,
    B38400 = 0x000000f,

    B57600 = 0x00001001,
    B115200 = 0x00001002,
    B230400 = 0x00001003,
    B460800 = 0x00001004,
    B500000 = 0x00001005,
    B576000 = 0x00001006,
    B921600 = 0x00001007,
    B1000000 = 0x00001008,
    B1152000 = 0x00001009,
    B1500000 = 0x0000100a,
    B2000000 = 0x0000100b,
    B2500000 = 0x0000100c,
    B3000000 = 0x0000100d,
    B3500000 = 0x0000100e,
    B4000000 = 0x0000100f,

    pub const EXTA = speed_t.B19200;
    pub const EXTB = speed_t.B38400;
};

pub const tcflag_t = if (native_arch == .sparc) c_ulong else c_uint;

pub const tc_iflag_t = if (is_ppc) packed struct(tcflag_t) {
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
    _15: u17 = 0,
} else packed struct(tcflag_t) {
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
    _15: u17 = 0,
};

pub const NLDLY = if (is_ppc) enum(u2) {
    NL0 = 0,
    NL1 = 1,
    NL2 = 2,
    NL3 = 3,
} else enum(u1) {
    NL0 = 0,
    NL1 = 1,
};

pub const CRDLY = enum(u2) {
    CR0 = 0,
    CR1 = 1,
    CR2 = 2,
    CR3 = 3,
};

pub const TABDLY = enum(u2) {
    TAB0 = 0,
    TAB1 = 1,
    TAB2 = 2,
    TAB3 = 3,

    pub const XTABS = TABDLY.TAB3;
};

pub const BSDLY = enum(u1) {
    BS0 = 0,
    BS1 = 1,
};

pub const VTDLY = enum(u1) {
    VT0 = 0,
    VT1 = 1,
};

pub const FFDLY = enum(u1) {
    FF0 = 0,
    FF1 = 1,
};

pub const tc_oflag_t = if (is_ppc) packed struct(tcflag_t) {
    OPOST: bool = false,
    ONLCR: bool = false,
    OLCUC: bool = false,
    OCRNL: bool = false,
    ONOCR: bool = false,
    ONLRET: bool = false,
    OFILL: bool = false,
    OFDEL: bool = false,
    NLDLY: NLDLY = .NL0,
    TABDLY: TABDLY = .TAB0,
    CRDLY: CRDLY = .CR0,
    FFDLY: FFDLY = .FF0,
    BSDLY: BSDLY = .BS0,
    VTDLY: VTDLY = .VT0,
    _17: u15 = 0,
} else if (is_sparc) packed struct(tcflag_t) {
    OPOST: bool = false,
    OLCUC: bool = false,
    ONLCR: bool = false,
    OCRNL: bool = false,
    ONOCR: bool = false,
    ONLRET: bool = false,
    OFILL: bool = false,
    OFDEL: bool = false,
    NLDLY: NLDLY = .NL0,
    CRDLY: CRDLY = .CR0,
    TABDLY: TABDLY = .TAB0,
    BSDLY: BSDLY = .BS0,
    VTDLY: VTDLY = .VT0,
    FFDLY: FFDLY = .FF0,
    PAGEOUT: bool = false,
    WRAP: bool = false,
    _18: u14 = 0,
} else packed struct(tcflag_t) {
    OPOST: bool = false,
    OLCUC: bool = false,
    ONLCR: bool = false,
    OCRNL: bool = false,
    ONOCR: bool = false,
    ONLRET: bool = false,
    OFILL: bool = false,
    OFDEL: bool = false,
    NLDLY: NLDLY = .NL0,
    CRDLY: CRDLY = .CR0,
    TABDLY: TABDLY = .TAB0,
    BSDLY: BSDLY = .BS0,
    VTDLY: VTDLY = .VT0,
    FFDLY: FFDLY = .FF0,
    _16: u16 = 0,
};

pub const CSIZE = enum(u2) {
    CS5 = 0,
    CS6 = 1,
    CS7 = 2,
    CS8 = 3,
};

pub const tc_cflag_t = if (is_ppc) packed struct(tcflag_t) {
    _0: u8 = 0,
    CSIZE: CSIZE = .CS5,
    CSTOPB: bool = false,
    CREAD: bool = false,
    PARENB: bool = false,
    PARODD: bool = false,
    HUPCL: bool = false,
    CLOCAL: bool = false,
    _16: u13 = 0,
    ADDRB: bool = false,
    CMSPAR: bool = false,
    CRTSCTS: bool = false,
} else packed struct(tcflag_t) {
    _0: u4 = 0,
    CSIZE: CSIZE = .CS5,
    CSTOPB: bool = false,
    CREAD: bool = false,
    PARENB: bool = false,
    PARODD: bool = false,
    HUPCL: bool = false,
    CLOCAL: bool = false,
    _12: u17 = 0,
    ADDRB: bool = false,
    CMSPAR: bool = false,
    CRTSCTS: bool = false,
};

pub const tc_lflag_t = if (is_mips) packed struct(tcflag_t) {
    ISIG: bool = false,
    ICANON: bool = false,
    XCASE: bool = false,
    ECHO: bool = false,
    ECHOE: bool = false,
    ECHOK: bool = false,
    ECHONL: bool = false,
    NOFLSH: bool = false,
    IEXTEN: bool = false,
    ECHOCTL: bool = false,
    ECHOPRT: bool = false,
    ECHOKE: bool = false,
    _12: u1 = 0,
    FLUSHO: bool = false,
    PENDIN: bool = false,
    TOSTOP: bool = false,
    EXTPROC: bool = false,
    _17: u15 = 0,
} else if (is_ppc) packed struct(tcflag_t) {
    ECHOKE: bool = false,
    ECHOE: bool = false,
    ECHOK: bool = false,
    ECHO: bool = false,
    ECHONL: bool = false,
    ECHOPRT: bool = false,
    ECHOCTL: bool = false,
    ISIG: bool = false,
    ICANON: bool = false,
    _9: u1 = 0,
    IEXTEN: bool = false,
    _11: u3 = 0,
    XCASE: bool = false,
    _15: u7 = 0,
    TOSTOP: bool = false,
    FLUSHO: bool = false,
    _24: u4 = 0,
    EXTPROC: bool = false,
    PENDIN: bool = false,
    _30: u1 = 0,
    NOFLSH: bool = false,
} else if (is_sparc) packed struct(tcflag_t) {
    ISIG: bool = false,
    ICANON: bool = false,
    XCASE: bool = false,
    ECHO: bool = false,
    ECHOE: bool = false,
    ECHOK: bool = false,
    ECHONL: bool = false,
    NOFLSH: bool = false,
    TOSTOP: bool = false,
    ECHOCTL: bool = false,
    ECHOPRT: bool = false,
    ECHOKE: bool = false,
    DEFECHO: bool = false,
    FLUSHO: bool = false,
    PENDIN: bool = false,
    IEXTEN: bool = false,
    EXTPROC: bool = false,
    _17: u15 = 0,
} else packed struct(tcflag_t) {
    ISIG: bool = false,
    ICANON: bool = false,
    XCASE: bool = false,
    ECHO: bool = false,
    ECHOE: bool = false,
    ECHOK: bool = false,
    ECHONL: bool = false,
    NOFLSH: bool = false,
    TOSTOP: bool = false,
    ECHOCTL: bool = false,
    ECHOPRT: bool = false,
    ECHOKE: bool = false,
    FLUSHO: bool = false,
    _13: u1 = 0,
    PENDIN: bool = false,
    IEXTEN: bool = false,
    EXTPROC: bool = false,
    _17: u15 = 0,
};

pub const cc_t = u8;

/// Indices into the `cc` array in the `termios` struct.
pub const V = if (is_mips) enum(u32) {
    INTR = 0,
    QUIT = 1,
    ERASE = 2,
    KILL = 3,
    MIN = 4,
    TIME = 5,
    EOL2 = 6,
    SWTC = 7,
    START = 8,
    STOP = 9,
    SUSP = 10,
    REPRINT = 12,
    DISCARD = 13,
    WERASE = 14,
    LNEXT = 15,
    EOF = 16,
    EOL = 17,
} else if (is_ppc) enum(u32) {
    INTR = 0,
    QUIT = 1,
    ERASE = 2,
    KILL = 3,
    EOF = 4,
    MIN = 5,
    EOL = 6,
    TIME = 7,
    EOL2 = 8,
    SWTC = 9,
    WERASE = 10,
    REPRINT = 11,
    SUSP = 12,
    START = 13,
    STOP = 14,
    LNEXT = 15,
    DISCARD = 16,
} else enum(u32) {
    INTR = 0,
    QUIT = 1,
    ERASE = 2,
    KILL = 3,
    EOF = 4,
    TIME = 5,
    MIN = 6,
    SWTC = 7,
    START = 8,
    STOP = 9,
    SUSP = 10,
    EOL = 11,
    REPRINT = 12,
    DISCARD = 13,
    WERASE = 14,
    LNEXT = 15,
    EOL2 = 16,
};

pub const TCSA = std.posix.TCSA;

pub const sgttyb = if (is_mips or is_ppc or is_sparc) extern struct {
    ispeed: c_char,
    ospeed: c_char,
    erase: c_char,
    kill: c_char,
    flags: if (is_mips) c_int else c_short,
} else void;

pub const tchars = if (is_mips or is_ppc or is_sparc) extern struct {
    intrc: c_char,
    quitc: c_char,
    startc: c_char,
    stopc: c_char,
    eofc: c_char,
    brkc: c_char,
} else void;

pub const ltchars = if (is_mips or is_ppc or is_sparc) extern struct {
    suspc: c_char,
    dsuspc: c_char,
    rprntc: c_char,
    flushc: c_char,
    werasc: c_char,
    lnextc: c_char,
} else void;

pub const termio = extern struct {
    iflag: c_ushort,
    oflag: c_ushort,
    cflag: c_ushort,
    lflag: c_ushort,
    line: if (is_mips) c_char else u8,
    cc: [if (is_mips) NCCS else NCC]u8,
};

pub const termios = if (is_mips or is_sparc) extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    line: cc_t,
    cc: [NCCS]cc_t,
} else if (is_ppc) extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    cc: [NCCS]cc_t,
    line: cc_t,
    ispeed: speed_t,
    ospeed: speed_t,
} else extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    line: cc_t,
    cc: [NCCS]cc_t,
    ispeed: speed_t,
    ospeed: speed_t,
};

pub const termios2 = if (is_mips) extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    cc: [NCCS]cc_t,
    line: cc_t,
    ispeed: speed_t,
    ospeed: speed_t,
} else extern struct {
    iflag: tc_iflag_t,
    oflag: tc_oflag_t,
    cflag: tc_cflag_t,
    lflag: tc_lflag_t,
    line: cc_t,
    cc: [NCCS + if (is_sparc) 2 else 0]cc_t,
    ispeed: speed_t,
    ospeed: speed_t,
};

/// Linux-specific socket ioctls
pub const SIOCINQ = T.FIONREAD;

/// Linux-specific socket ioctls
/// output queue size (not sent + not acked)
pub const SIOCOUTQ = T.IOCOUTQ;

pub const SOCK_IOC_TYPE = 0x89;

pub const SIOCGSTAMP_NEW = IOCTL.IOR(SOCK_IOC_TYPE, 0x06, i64[2]);
pub const SIOCGSTAMP_OLD = IOCTL.IOR('s', 100, timeval);

/// Get stamp (timeval)
pub const SIOCGSTAMP = if (native_arch == .x86_64 or @sizeOf(timeval) == 8) SIOCGSTAMP_OLD else SIOCGSTAMP_NEW;

pub const SIOCGSTAMPNS_NEW = IOCTL.IOR(SOCK_IOC_TYPE, 0x07, i64[2]);
pub const SIOCGSTAMPNS_OLD = IOCTL.IOR('s', 101, kernel_timespec);

/// Get stamp (timespec)
pub const SIOCGSTAMPNS = if (native_arch == .x86_64 or @sizeOf(timespec) == 8) SIOCGSTAMPNS_OLD else SIOCGSTAMPNS_NEW;

// Routing table calls.
/// Add routing table entry
pub const SIOCADDRT = 0x890B;

/// Delete routing table entry
pub const SIOCDELRT = 0x890C;

/// Unused
pub const SIOCRTMSG = 0x890D;

// Socket configuration controls.
/// Get iface name
pub const SIOCGIFNAME = 0x8910;

/// Set iface channel
pub const SIOCSIFLINK = 0x8911;

/// Get iface list
pub const SIOCGIFCONF = 0x8912;

/// Get flags
pub const SIOCGIFFLAGS = 0x8913;

/// Set flags
pub const SIOCSIFFLAGS = 0x8914;

/// Get PA address
pub const SIOCGIFADDR = 0x8915;

/// Set PA address
pub const SIOCSIFADDR = 0x8916;

/// Get remote PA address
pub const SIOCGIFDSTADDR = 0x8917;

/// Set remote PA address
pub const SIOCSIFDSTADDR = 0x8918;

/// Get broadcast PA address
pub const SIOCGIFBRDADDR = 0x8919;

/// Set broadcast PA address
pub const SIOCSIFBRDADDR = 0x891a;

/// Get network PA mask
pub const SIOCGIFNETMASK = 0x891b;

/// Set network PA mask
pub const SIOCSIFNETMASK = 0x891c;

/// Get metric
pub const SIOCGIFMETRIC = 0x891d;

/// Set metric
pub const SIOCSIFMETRIC = 0x891e;

/// Get memory address (BSD)
pub const SIOCGIFMEM = 0x891f;

/// Set memory address (BSD)
pub const SIOCSIFMEM = 0x8920;

/// Get MTU size
pub const SIOCGIFMTU = 0x8921;

/// Set MTU size
pub const SIOCSIFMTU = 0x8922;

/// Set interface name
pub const SIOCSIFNAME = 0x8923;

/// Set hardware address
pub const SIOCSIFHWADDR = 0x8924;

/// Get encapsulations
pub const SIOCGIFENCAP = 0x8925;

/// Set encapsulations
pub const SIOCSIFENCAP = 0x8926;

/// Get hardware address
pub const SIOCGIFHWADDR = 0x8927;

/// Driver slaving support
pub const SIOCGIFSLAVE = 0x8929;

/// Driver slaving support
pub const SIOCSIFSLAVE = 0x8930;

/// Add to Multicast address lists
pub const SIOCADDMULTI = 0x8931;

/// Delete from Multicast address lists
pub const SIOCDELMULTI = 0x8932;

/// name -> if_index mapping
pub const SIOCGIFINDEX = 0x8933;

/// Set extended flags set
pub const SIOCSIFPFLAGS = 0x8934;

/// Get extended flags set
pub const SIOCGIFPFLAGS = 0x8935;

/// Delete PA address
pub const SIOCDIFADDR = 0x8936;

/// Set hardware broadcast addr
pub const SIOCSIFHWBROADCAST = 0x8937;

/// Get number of devices
pub const SIOCGIFCOUNT = 0x8938;

/// Bridging support
pub const SIOCGIFBR = 0x8940;

/// Set bridging options
pub const SIOCSIFBR = 0x8941;

/// Get the tx queue length
pub const SIOCGIFTXQLEN = 0x8942;

/// Set the tx queue length
pub const SIOCSIFTXQLEN = 0x8943;

/// Ethtool interface
pub const SIOCETHTOOL = 0x8946;

/// Get address of MII PHY in use.
pub const SIOCGMIIPHY = 0x8947;

/// Read MII PHY register.
pub const SIOCGMIIREG = 0x8948;

/// Write MII PHY register.
pub const SIOCSMIIREG = 0x8949;

/// Get / Set netdev parameters
pub const SIOCWANDEV = 0x894A;

/// Output queue size (not sent only)
pub const SIOCOUTQNSD = 0x894B;

/// Get socket network namespace
pub const SIOCGSKNS = 0x894C;

// ARP cache control calls.
//  0x8950 - 0x8952 obsolete calls.
/// Delete ARP table entry
pub const SIOCDARP = 0x8953;

/// Get ARP table entry
pub const SIOCGARP = 0x8954;

/// Set ARP table entry
pub const SIOCSARP = 0x8955;

// RARP cache control calls.
/// Delete RARP table entry
pub const SIOCDRARP = 0x8960;

/// Get RARP table entry
pub const SIOCGRARP = 0x8961;

/// Set RARP table entry
pub const SIOCSRARP = 0x8962;

// Driver configuration calls
/// Get device parameters
pub const SIOCGIFMAP = 0x8970;

/// Set device parameters
pub const SIOCSIFMAP = 0x8971;

// DLCI configuration calls
/// Create new DLCI device
pub const SIOCADDDLCI = 0x8980;

/// Delete DLCI device
pub const SIOCDELDLCI = 0x8981;

/// 802.1Q VLAN support
pub const SIOCGIFVLAN = 0x8982;

/// Set 802.1Q VLAN options
pub const SIOCSIFVLAN = 0x8983;

// bonding calls
/// Enslave a device to the bond
pub const SIOCBONDENSLAVE = 0x8990;

/// Release a slave from the bond
pub const SIOCBONDRELEASE = 0x8991;

/// Set the hw addr of the bond
pub const SIOCBONDSETHWADDR = 0x8992;

/// rtn info about slave state
pub const SIOCBONDSLAVEINFOQUERY = 0x8993;

/// rtn info about bond state
pub const SIOCBONDINFOQUERY = 0x8994;

/// Update to a new active slave
pub const SIOCBONDCHANGEACTIVE = 0x8995;

// Bridge calls
/// Create new bridge device
pub const SIOCBRADDBR = 0x89a0;

/// Remove bridge device
pub const SIOCBRDELBR = 0x89a1;

/// Add interface to bridge
pub const SIOCBRADDIF = 0x89a2;

/// Remove interface from bridge
pub const SIOCBRDELIF = 0x89a3;

/// Get hardware time stamp config
pub const SIOCSHWTSTAMP = 0x89b0;

/// Set hardware time stamp config
pub const SIOCGHWTSTAMP = 0x89b1;

/// Device private ioctl calls
pub const SIOCDEVPRIVATE = 0x89F0;

/// These 16 ioctl calls are protocol private
pub const SIOCPROTOPRIVATE = 0x89E0;

pub const IFNAMESIZE = 16;

pub const IFF = packed struct(u16) {
    UP: bool = false,
    BROADCAST: bool = false,
    DEBUG: bool = false,
    LOOPBACK: bool = false,
    POINTOPOINT: bool = false,
    NOTRAILERS: bool = false,
    RUNNING: bool = false,
    NOARP: bool = false,
    PROMISC: bool = false,
    _9: u7 = 0,
};

pub const ifmap = extern struct {
    mem_start: usize,
    mem_end: usize,
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
        flags: IFF,
        ivalue: i32,
        mtu: i32,
        map: ifmap,
        slave: [IFNAMESIZE - 1:0]u8,
        newname: [IFNAMESIZE - 1:0]u8,
        data: ?[*]u8,
    },
};

pub const PACKET = struct {
    pub const HOST = 0;
    pub const BROADCAST = 1;
    pub const MULTICAST = 2;
    pub const OTHERHOST = 3;
    pub const OUTGOING = 4;
    pub const LOOPBACK = 5;
    pub const USER = 6;
    pub const KERNEL = 7;

    pub const ADD_MEMBERSHIP = 1;
    pub const DROP_MEMBERSHIP = 2;
    pub const RECV_OUTPUT = 3;
    pub const RX_RING = 5;
    pub const STATISTICS = 6;
    pub const COPY_THRESH = 7;
    pub const AUXDATA = 8;
    pub const ORIGDEV = 9;
    pub const VERSION = 10;
    pub const HDRLEN = 11;
    pub const RESERVE = 12;
    pub const TX_RING = 13;
    pub const LOSS = 14;
    pub const VNET_HDR = 15;
    pub const TX_TIMESTAMP = 16;
    pub const TIMESTAMP = 17;
    pub const FANOUT = 18;
    pub const TX_HAS_OFF = 19;
    pub const QDISC_BYPASS = 20;
    pub const ROLLOVER_STATS = 21;
    pub const FANOUT_DATA = 22;
    pub const IGNORE_OUTGOING = 23;
    pub const VNET_HDR_SZ = 24;

    pub const FANOUT_HASH = 0;
    pub const FANOUT_LB = 1;
    pub const FANOUT_CPU = 2;
    pub const FANOUT_ROLLOVER = 3;
    pub const FANOUT_RND = 4;
    pub const FANOUT_QM = 5;
    pub const FANOUT_CBPF = 6;
    pub const FANOUT_EBPF = 7;
    pub const FANOUT_FLAG_ROLLOVER = 0x1000;
    pub const FANOUT_FLAG_UNIQUEID = 0x2000;
    pub const FANOUT_FLAG_IGNORE_OUTGOING = 0x4000;
    pub const FANOUT_FLAG_DEFRAG = 0x8000;
};

pub const tpacket_versions = enum(u32) {
    V1 = 0,
    V2 = 1,
    V3 = 2,
};

pub const tpacket_req3 = extern struct {
    block_size: c_uint, // Minimal size of contiguous block
    block_nr: c_uint, // Number of blocks
    frame_size: c_uint, // Size of frame
    frame_nr: c_uint, // Total number of frames
    retire_blk_tov: c_uint, // Timeout in msecs
    sizeof_priv: c_uint, // Offset to private data area
    feature_req_word: c_uint,
};

pub const tpacket_bd_ts = extern struct {
    sec: c_uint,
    frac: extern union {
        usec: c_uint,
        nsec: c_uint,
    },
};

pub const TP_STATUS = extern union {
    rx: packed struct(u32) {
        USER: bool,
        COPY: bool,
        LOSING: bool,
        CSUMNOTREADY: bool,
        VLAN_VALID: bool,
        BLK_TMO: bool,
        VLAN_TPID_VALID: bool,
        CSUM_VALID: bool,
        GSO_TCP: bool,
        _: u20,
        TS_SOFTWARE: bool,
        TS_SYS_HARDWARE: bool,
        TS_RAW_HARDWARE: bool,
    },
    tx: packed struct(u32) {
        SEND_REQUEST: bool,
        SENDING: bool,
        WRONG_FORMAT: bool,
        _: u26,
        TS_SOFTWARE: bool,
        TS_SYS_HARDWARE: bool,
        TS_RAW_HARDWARE: bool,
    },
};

pub const tpacket_hdr_v1 = extern struct {
    block_status: TP_STATUS,
    num_pkts: u32,
    offset_to_first_pkt: u32,
    blk_len: u32,
    seq_num: u64 align(8),
    ts_first_pkt: tpacket_bd_ts,
    ts_last_pkt: tpacket_bd_ts,
};

pub const tpacket_bd_header_u = extern union {
    bh1: tpacket_hdr_v1,
};

pub const tpacket_block_desc = extern struct {
    version: u32,
    offset_to_priv: u32,
    hdr: tpacket_bd_header_u,
};

pub const tpacket_hdr_variant1 = extern struct {
    rxhash: u32,
    vlan_tci: u32,
    vlan_tpid: u16,
    padding: u16,
};

pub const tpacket3_hdr = extern struct {
    next_offset: u32,
    sec: u32,
    nsec: u32,
    snaplen: u32,
    len: u32,
    status: u32,
    mac: u16,
    net: u16,
    variant: extern union {
        hv1: tpacket_hdr_variant1,
    },
    padding: [8]u8,
};

pub const tpacket_stats_v3 = extern struct {
    packets: c_uint,
    drops: c_uint,
    freeze_q_cnt: c_uint,
};

// doc comments copied from musl
pub const rlimit_resource = if (native_arch.isMIPS()) enum(c_int) {
    /// Per-process CPU limit, in seconds.
    CPU = 0,

    /// Largest file that can be created, in bytes.
    FSIZE = 1,

    /// Maximum size of data segment, in bytes.
    DATA = 2,

    /// Maximum size of stack segment, in bytes.
    STACK = 3,

    /// Largest core file that can be created, in bytes.
    CORE = 4,

    /// Number of open files.
    NOFILE = 5,

    /// Address space limit.
    AS = 6,

    /// Largest resident set size, in bytes.
    /// This affects swapping; processes that are exceeding their
    /// resident set size will be more likely to have physical memory
    /// taken from them.
    RSS = 7,

    /// Number of processes.
    NPROC = 8,

    /// Locked-in-memory address space.
    MEMLOCK = 9,

    /// Maximum number of file locks.
    LOCKS = 10,

    /// Maximum number of pending signals.
    SIGPENDING = 11,

    /// Maximum bytes in POSIX message queues.
    MSGQUEUE = 12,

    /// Maximum nice priority allowed to raise to.
    /// Nice levels 19 .. -20 correspond to 0 .. 39
    /// values of this resource limit.
    NICE = 13,

    /// Maximum realtime priority allowed for non-privileged
    /// processes.
    RTPRIO = 14,

    /// Maximum CPU time in µs that a process scheduled under a real-time
    /// scheduling policy may consume without making a blocking system
    /// call before being forcibly descheduled.
    RTTIME = 15,

    _,
} else if (native_arch.isSPARC()) enum(c_int) {
    /// Per-process CPU limit, in seconds.
    CPU = 0,

    /// Largest file that can be created, in bytes.
    FSIZE = 1,

    /// Maximum size of data segment, in bytes.
    DATA = 2,

    /// Maximum size of stack segment, in bytes.
    STACK = 3,

    /// Largest core file that can be created, in bytes.
    CORE = 4,

    /// Largest resident set size, in bytes.
    /// This affects swapping; processes that are exceeding their
    /// resident set size will be more likely to have physical memory
    /// taken from them.
    RSS = 5,

    /// Number of open files.
    NOFILE = 6,

    /// Number of processes.
    NPROC = 7,

    /// Locked-in-memory address space.
    MEMLOCK = 8,

    /// Address space limit.
    AS = 9,

    /// Maximum number of file locks.
    LOCKS = 10,

    /// Maximum number of pending signals.
    SIGPENDING = 11,

    /// Maximum bytes in POSIX message queues.
    MSGQUEUE = 12,

    /// Maximum nice priority allowed to raise to.
    /// Nice levels 19 .. -20 correspond to 0 .. 39
    /// values of this resource limit.
    NICE = 13,

    /// Maximum realtime priority allowed for non-privileged
    /// processes.
    RTPRIO = 14,

    /// Maximum CPU time in µs that a process scheduled under a real-time
    /// scheduling policy may consume without making a blocking system
    /// call before being forcibly descheduled.
    RTTIME = 15,

    _,
} else enum(c_int) {
    /// Per-process CPU limit, in seconds.
    CPU = 0,
    /// Largest file that can be created, in bytes.
    FSIZE = 1,
    /// Maximum size of data segment, in bytes.
    DATA = 2,
    /// Maximum size of stack segment, in bytes.
    STACK = 3,
    /// Largest core file that can be created, in bytes.
    CORE = 4,
    /// Largest resident set size, in bytes.
    /// This affects swapping; processes that are exceeding their
    /// resident set size will be more likely to have physical memory
    /// taken from them.
    RSS = 5,
    /// Number of processes.
    NPROC = 6,
    /// Number of open files.
    NOFILE = 7,
    /// Locked-in-memory address space.
    MEMLOCK = 8,
    /// Address space limit.
    AS = 9,
    /// Maximum number of file locks.
    LOCKS = 10,
    /// Maximum number of pending signals.
    SIGPENDING = 11,
    /// Maximum bytes in POSIX message queues.
    MSGQUEUE = 12,
    /// Maximum nice priority allowed to raise to.
    /// Nice levels 19 .. -20 correspond to 0 .. 39
    /// values of this resource limit.
    NICE = 13,
    /// Maximum realtime priority allowed for non-privileged
    /// processes.
    RTPRIO = 14,
    /// Maximum CPU time in µs that a process scheduled under a real-time
    /// scheduling policy may consume without making a blocking system
    /// call before being forcibly descheduled.
    RTTIME = 15,

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

pub const Madvice = enum(u32) {
    _, // TODO: add options
};
pub const Fadvice = enum(u32) {
    _, // TODO: add options
};

pub const POSIX_FADV = switch (native_arch) {
    .s390x => if (@typeInfo(usize).int.bits == 64) struct {
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

pub const timeval = extern struct {
    sec: isize,
    usec: i64,
};

pub const timezone = extern struct {
    minuteswest: i32,
    dsttime: i32,
};

/// The timespec struct used by the kernel.
pub const kernel_timespec = extern struct {
    sec: i64,
    nsec: i64,
};

// https://github.com/ziglang/zig/issues/4726#issuecomment-2190337877
pub const timespec = if (native_arch == .hexagon or native_arch == .riscv32) kernel_timespec else extern struct {
    sec: isize,
    nsec: isize,
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

    pub const SET_PTRACER_ANY = maxInt(c_ulong);

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
    type: extern union {
        /// IFLA_* from linux/if_link.h
        link: IFLA,
        /// IFA_* from linux/if_addr.h
        addr: IFA,
    },

    pub const ALIGNTO = 4;
};

pub const IFA = enum(c_ushort) {
    UNSPEC,
    ADDRESS,
    LOCAL,
    LABEL,
    BROADCAST,
    ANYCAST,
    CACHEINFO,
    MULTICAST,
    FLAGS,
    RT_PRIORITY,
    TARGET_NETNSID,
    PROTO,

    _,
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
        /// include ksymbol events
        ksymbol: bool = false,
        /// include BPF events
        bpf_event: bool = false,
        /// generate AUX records instead of events
        aux_output: bool = false,
        /// include cgroup events
        cgroup: bool = false,
        /// include text poke events
        text_poke: bool = false,
        /// use build ID in mmap2 events
        build_id: bool = false,
        /// children only inherit if cloned with CLONE_THREAD
        inherit_thread: bool = false,
        /// event is removed from task on exec
        remove_on_exec: bool = false,
        /// send synchronous SIGTRAP on event
        sigtrap: bool = false,

        __reserved_1: u26 = 0,
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

    clockid: clockid_t = .REALTIME,
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

    aux_sample_size: u32 = 0,
    aux_action: packed struct(u32) {
        /// start AUX area tracing paused
        start_paused: bool = false,
        /// on overflow, pause AUX area tracing
        pause: bool = false,
        /// on overflow, resume AUX area tracing
        @"resume": bool = false,

        __reserved_3: u29 = 0,
    } = .{},

    /// User provided data if sigtrap == true
    sig_data: u64 = 0,

    /// Extension of config2
    config3: u64 = 0,
};

pub const perf_event_header = extern struct {
    /// Event type: sample/mmap/fork/etc.
    type: PERF.RECORD,
    /// Additional informations on the event: kernel/user/hypervisor/etc.
    misc: packed struct(u16) {
        cpu_mode: PERF.RECORD.MISC.CPU_MODE,
        _: u9,
        PROC_MAP_PARSE_TIMEOUT: bool,
        bit13: packed union {
            MMAP_DATA: bool,
            COMM_EXEC: bool,
            FORK_EXEC: bool,
            SWITCH_OUT: bool,
        },
        bit14: packed union {
            EXACT_IP: bool,
            SWITCH_OUT_PREEMPT: bool,
            MMAP_BUILD_ID: bool,
        },
        EXT_RESERVED: bool,
    },
    /// Size of the following record
    size: u16,
};

pub const perf_event_mmap_page = extern struct {
    /// Version number of this struct
    version: u32,
    /// Lowest version this is compatible with
    compt_version: u32,
    /// Seqlock for synchronization
    lock: u32,
    /// Hardware counter identifier
    index: u32,
    /// Add to hardware counter value
    offset: i64,
    /// Time the event was active
    time_enabled: u64,
    /// Time the event was running
    time_running: u64,
    capabilities: packed struct(u64) {
        /// If kernel version < 3.12
        /// this rapresents both user_rdpmc and user_time (user_rdpmc | user_time)
        /// otherwise deprecated.
        bit0: bool,
        /// Set if bit0 is deprecated
        bit0_is_deprecated: bool,
        /// Hardware support for userspace read of performance counters
        user_rdpmc: bool,
        /// Hardware support for a constant non stop timestamp counter (Eg. TSC on x86)
        user_time: bool,
        /// The time_zero field is used
        user_time_zero: bool,
        /// The time_{cycle,mask} fields are used
        user_time_short: bool,
        ____res: u58,
    },
    /// If capabilities.user_rdpmc
    /// this field reports the bit-width of the value read with rdpmc() or equivalent
    pcm_width: u16,
    /// If capabilities.user_time the following fields can be used to compute the time
    /// delta since time_enabled (in ns) using RDTSC or similar
    time_shift: u16,
    time_mult: u32,
    time_offset: u64,
    /// If capabilities.user_time_zero the hardware clock can be calculated from
    /// sample timestamps
    time_zero: u64,
    /// Header size
    size: u32,
    __reserved_1: u32,
    /// The following fields are used to compute the timestamp when the hardware clock
    /// is less than 64bit wide
    time_cycles: u64,
    time_mask: u64,
    __reserved: [116 * 8]u8,
    /// Head in the data section
    data_head: u64,
    /// Userspace written tail
    data_tail: u64,
    /// Where the buffer starts
    data_offset: u64,
    /// Data buffer size
    data_size: u64,
    // if aux is used, head in the data section
    aux_head: u64,
    // if aux is used, userspace written tail
    aux_tail: u64,
    // if aux is used, where the buffer starts
    aux_offset: u64,
    // if aux is used, data buffer size
    aux_size: u64,
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

    pub const RECORD = enum(u32) {
        MMAP = 1,
        LOST = 2,
        COMM = 3,
        EXIT = 4,
        THROTTLE = 5,
        UNTHROTTLE = 6,
        FORK = 7,
        READ = 8,
        SAMPLE = 9,
        MMAP2 = 10,
        AUX = 11,
        ITRACE_START = 12,
        LOST_SAMPLES = 13,
        SWITCH = 14,
        SWITCH_CPU_WIDE = 15,
        NAMESPACES = 16,
        KSYMBOL = 17,
        BPF_EVENT = 18,
        CGROUP = 19,
        TEXT_POKE = 20,
        AUX_OUTPUT_HW_ID = 21,

        const MISC = struct {
            pub const CPU_MODE = enum(u3) {
                UNKNOWN = 0,
                KERNEL = 1,
                USER = 2,
                HYPERVISOR = 3,
                GUEST_KERNEL = 4,
                GUEST_USER = 5,
            };
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
        const CONVENTION_MIPS64_N32 = 0x20000000;
        const @"64BIT" = 0x80000000;
        const LE = 0x40000000;

        AARCH64 = toAudit(.AARCH64, @"64BIT" | LE),
        ALPHA = toAudit(.ALPHA, @"64BIT" | LE),
        ARCOMPACT = toAudit(.ARC_COMPACT, LE),
        ARCOMPACTBE = toAudit(.ARC_COMPACT, 0),
        ARCV2 = toAudit(.ARC_COMPACT2, LE),
        ARCV2BE = toAudit(.ARC_COMPACT2, 0),
        ARM = toAudit(.ARM, LE),
        ARMEB = toAudit(.ARM, 0),
        C6X = toAudit(.TI_C6000, LE),
        C6XBE = toAudit(.TI_C6000, 0),
        CRIS = toAudit(.CRIS, LE),
        CSKY = toAudit(.CSKY, LE),
        FRV = toAudit(.FRV, 0),
        H8300 = toAudit(.H8_300, 0),
        HEXAGON = toAudit(.HEXAGON, 0),
        I386 = toAudit(.@"386", LE),
        IA64 = toAudit(.IA_64, @"64BIT" | LE),
        M32R = toAudit(.M32R, 0),
        M68K = toAudit(.@"68K", 0),
        MICROBLAZE = toAudit(.MICROBLAZE, 0),
        MIPS = toAudit(.MIPS, 0),
        MIPSEL = toAudit(.MIPS, LE),
        MIPS64 = toAudit(.MIPS, @"64BIT"),
        MIPS64N32 = toAudit(.MIPS, @"64BIT" | CONVENTION_MIPS64_N32),
        MIPSEL64 = toAudit(.MIPS, @"64BIT" | LE),
        MIPSEL64N32 = toAudit(.MIPS, @"64BIT" | LE | CONVENTION_MIPS64_N32),
        NDS32 = toAudit(.NDS32, LE),
        NDS32BE = toAudit(.NDS32, 0),
        NIOS2 = toAudit(.ALTERA_NIOS2, LE),
        OPENRISC = toAudit(.OPENRISC, 0),
        PARISC = toAudit(.PARISC, 0),
        PARISC64 = toAudit(.PARISC, @"64BIT"),
        PPC = toAudit(.PPC, 0),
        PPC64 = toAudit(.PPC64, @"64BIT"),
        PPC64LE = toAudit(.PPC64, @"64BIT" | LE),
        RISCV32 = toAudit(.RISCV, LE),
        RISCV64 = toAudit(.RISCV, @"64BIT" | LE),
        S390 = toAudit(.S390, 0),
        S390X = toAudit(.S390, @"64BIT"),
        SH = toAudit(.SH, 0),
        SHEL = toAudit(.SH, LE),
        SH64 = toAudit(.SH, @"64BIT"),
        SHEL64 = toAudit(.SH, @"64BIT" | LE),
        SPARC = toAudit(.SPARC, 0),
        SPARC64 = toAudit(.SPARCV9, @"64BIT"),
        TILEGX = toAudit(.TILEGX, @"64BIT" | LE),
        TILEGX32 = toAudit(.TILEGX, LE),
        TILEPRO = toAudit(.TILEPRO, LE),
        UNICORE = toAudit(.UNICORE, LE),
        X86_64 = toAudit(.X86_64, @"64BIT" | LE),
        XTENSA = toAudit(.XTENSA, 0),
        LOONGARCH32 = toAudit(.LOONGARCH, LE),
        LOONGARCH64 = toAudit(.LOONGARCH, @"64BIT" | LE),

        fn toAudit(em: elf.EM, flags: u32) u32 {
            return @intFromEnum(em) | flags;
        }

        pub const current: AUDIT.ARCH = switch (native_arch) {
            .arm, .thumb => .ARM,
            .armeb, .thumbeb => .ARMEB,
            .aarch64 => .AARCH64,
            .arc => .ARCV2,
            .arceb => .ARCV2BE,
            .csky => .CSKY,
            .hexagon => .HEXAGON,
            .loongarch32 => .LOONGARCH32,
            .loongarch64 => .LOONGARCH64,
            .m68k => .M68K,
            .mips => .MIPS,
            .mipsel => .MIPSEL,
            .mips64 => switch (native_abi) {
                .gnuabin32, .muslabin32 => .MIPS64N32,
                else => .MIPS64,
            },
            .mips64el => switch (native_abi) {
                .gnuabin32, .muslabin32 => .MIPSEL64N32,
                else => .MIPSEL64,
            },
            .or1k => .OPENRISC,
            .powerpc => .PPC,
            .powerpc64 => .PPC64,
            .powerpc64le => .PPC64LE,
            .riscv32 => .RISCV32,
            .riscv64 => .RISCV64,
            .sparc => .SPARC,
            .sparc64 => .SPARC64,
            .s390x => .S390X,
            .x86 => .I386,
            .x86_64 => .X86_64,
            .xtensa => .XTENSA,
            else => @compileError("unsupported architecture"),
        };
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

    pub const EVENT = struct {
        pub const FORK = 1;
        pub const VFORK = 2;
        pub const CLONE = 3;
        pub const EXEC = 4;
        pub const VFORK_DONE = 5;
        pub const EXIT = 6;
        pub const SECCOMP = 7;
        pub const STOP = 128;
    };

    pub const O = struct {
        pub const TRACESYSGOOD = 1;
        pub const TRACEFORK = 1 << PTRACE.EVENT.FORK;
        pub const TRACEVFORK = 1 << PTRACE.EVENT.VFORK;
        pub const TRACECLONE = 1 << PTRACE.EVENT.CLONE;
        pub const TRACEEXEC = 1 << PTRACE.EVENT.EXEC;
        pub const TRACEVFORKDONE = 1 << PTRACE.EVENT.VFORK_DONE;
        pub const TRACEEXIT = 1 << PTRACE.EVENT.EXIT;
        pub const TRACESECCOMP = 1 << PTRACE.EVENT.SECCOMP;

        pub const EXITKILL = 1 << 20;
        pub const SUSPEND_SECCOMP = 1 << 21;

        pub const MASK = 0x000000ff | PTRACE.O.EXITKILL | PTRACE.O.SUSPEND_SECCOMP;
    };
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

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    /// The kernel and glibc use `usize` for this field; POSIX and musl use `c_int`.
    iovlen: usize,
    control: ?*anyopaque,
    /// The kernel and glibc use `usize` for this field; POSIX and musl use `socklen_t`.
    controllen: usize,
    flags: u32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: usize,
    control: ?*const anyopaque,
    controllen: usize,
    flags: u32,
};

// https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/linux/socket.h?id=b320789d6883cc00ac78ce83bccbfe7ed58afcf0#n105
pub const cmsghdr = extern struct {
    /// The kernel and glibc use `usize` for this field; musl uses `socklen_t`.
    len: usize,
    level: i32,
    type: i32,
};

/// The syscalls, but with Zig error sets, going through libc if linking libc,
/// and with some footguns eliminated.
pub const wrapped = struct {
    pub const lfs64_abi = builtin.link_libc and (builtin.abi.isGnu() or builtin.abi.isAndroid());
    const system = if (builtin.link_libc) std.c else std.os.linux;

    pub const SendfileError = std.posix.UnexpectedError || error{
        /// `out_fd` is an unconnected socket, or out_fd closed its read end.
        BrokenPipe,
        /// Descriptor is not valid or locked, or an mmap(2)-like operation is not available for in_fd.
        UnsupportedOperation,
        /// Nonblocking I/O has been selected but the write would block.
        WouldBlock,
        /// Unspecified error while reading from in_fd.
        InputOutput,
        /// Insufficient kernel memory to read from in_fd.
        SystemResources,
        /// `offset` is not `null` but the input file is not seekable.
        Unseekable,
    };

    pub fn sendfile(
        out_fd: fd_t,
        in_fd: fd_t,
        in_offset: ?*off_t,
        in_len: usize,
    ) SendfileError!usize {
        const adjusted_len = @min(in_len, 0x7ffff000); // Prevents EOVERFLOW.
        const sendfileSymbol = if (lfs64_abi) system.sendfile64 else system.sendfile;
        const rc = sendfileSymbol(out_fd, in_fd, in_offset, adjusted_len);
        switch (system.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .BADF => return invalidApiUsage(), // Always a race condition.
            .FAULT => return invalidApiUsage(), // Segmentation fault.
            .OVERFLOW => return unexpectedErrno(.OVERFLOW), // We avoid passing too large of a `count`.
            .NOTCONN => return error.BrokenPipe, // `out_fd` is an unconnected socket
            .INVAL => return error.UnsupportedOperation,
            .AGAIN => return error.WouldBlock,
            .IO => return error.InputOutput,
            .PIPE => return error.BrokenPipe,
            .NOMEM => return error.SystemResources,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            else => |err| return unexpectedErrno(err),
        }
    }

    pub const CopyFileRangeError = std.posix.UnexpectedError || error{
        /// One of:
        /// * One or more file descriptors are not valid.
        /// * fd_in is not open for reading; or fd_out is not open for writing.
        /// * The O_APPEND flag is set for the open file description referred
        /// to by the file descriptor fd_out.
        BadFileFlags,
        /// One of:
        /// * An attempt was made to write at a position past the maximum file
        ///   offset the kernel supports.
        /// * An attempt was made to write a range that exceeds the allowed
        ///   maximum file size. The maximum file size differs between
        ///   filesystem implementations and can be different from the maximum
        ///   allowed file offset.
        /// * An attempt was made to write beyond the process's file size
        ///   resource limit. This may also result in the process receiving a
        ///   SIGXFSZ signal.
        FileTooBig,
        /// One of:
        /// * either fd_in or fd_out is not a regular file
        /// * flags argument is not zero
        /// * fd_in and fd_out refer to the same file and the source and target ranges overlap.
        InvalidArguments,
        /// A low-level I/O error occurred while copying.
        InputOutput,
        /// Either fd_in or fd_out refers to a directory.
        IsDir,
        OutOfMemory,
        /// There is not enough space on the target filesystem to complete the copy.
        NoSpaceLeft,
        /// (since Linux 5.19) the filesystem does not support this operation.
        OperationNotSupported,
        /// The requested source or destination range is too large to represent
        /// in the specified data types.
        Overflow,
        /// fd_out refers to an immutable file.
        PermissionDenied,
        /// Either fd_in or fd_out refers to an active swap file.
        SwapFile,
        /// The files referred to by fd_in and fd_out are not on the same
        /// filesystem, and the source and target filesystems are not of the
        /// same type, or do not support cross-filesystem copy.
        NotSameFileSystem,
    };

    pub fn copy_file_range(fd_in: fd_t, off_in: ?*i64, fd_out: fd_t, off_out: ?*i64, len: usize, flags: u32) CopyFileRangeError!usize {
        const use_c = std.c.versionCheck(if (builtin.abi.isAndroid()) .{ .major = 34, .minor = 0, .patch = 0 } else .{ .major = 2, .minor = 27, .patch = 0 });
        const sys = if (use_c) std.c else std.os.linux;
        const rc = sys.copy_file_range(fd_in, off_in, fd_out, off_out, len, flags);
        switch (sys.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .BADF => return error.BadFileFlags,
            .FBIG => return error.FileTooBig,
            .INVAL => return error.InvalidArguments,
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOMEM => return error.OutOfMemory,
            .NOSPC => return error.NoSpaceLeft,
            .OPNOTSUPP => return error.OperationNotSupported,
            .OVERFLOW => return error.Overflow,
            .PERM => return error.PermissionDenied,
            .TXTBSY => return error.SwapFile,
            .XDEV => return error.NotSameFileSystem,
            else => |err| return unexpectedErrno(err),
        }
    }

    const unexpectedErrno = std.posix.unexpectedErrno;

    fn invalidApiUsage() error{Unexpected} {
        if (builtin.mode == .Debug) @panic("invalid API usage");
        return error.Unexpected;
    }
};
