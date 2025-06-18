const builtin = @import("builtin");
const std = @import("../../std.zig");
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const linux = std.os.linux;
const SYS = linux.SYS;
const uid_t = std.os.linux.uid_t;
const gid_t = std.os.linux.uid_t;
const pid_t = std.os.linux.pid_t;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const timespec = std.os.linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
          [arg5] "{d5}" (arg5),
        : "memory"
    );
}

pub fn syscall6(
    number: SYS,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
) usize {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> usize),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
          [arg5] "{d5}" (arg5),
          [arg6] "{a0}" (arg6),
        : "memory"
    );
}

pub fn clone() callconv(.naked) usize {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         +4,   +8,    +12,   +16, +20,  +24, +28
    //
    // syscall(SYS_clone, flags, stack, ptid, ctid, tls)
    //         d0,        d1,    d2,    d3,   d4,   d5
    asm volatile (
        \\ // Save callee-saved registers.
        \\ movem.l %%d2-%%d5, -(%%sp) // sp -= 16
        \\
        \\ // Save func and arg.
        \\ move.l 16+4(%%sp), %%a0
        \\ move.l 16+16(%%sp), %%a1
        \\
        \\ // d0 = syscall(d0, d1, d2, d3, d4, d5)
        \\ move.l #120, %%d0 // SYS_clone
        \\ move.l 16+12(%%sp), %%d1
        \\ move.l 16+8(%%sp), %%d2
        \\ move.l 16+20(%%sp), %%d3
        \\ move.l 16+28(%%sp), %%d4
        \\ move.l 16+24(%%sp), %%d5
        \\ and.l #-4, %%d2 // Align the child stack pointer.
        \\ trap #0
        \\
        \\ // Are we in the parent or child?
        \\ tst.l %%d0
        \\ beq 1f
        \\ // Parent:
        \\
        \\ // Restore callee-saved registers and return.
        \\ movem.l (%%sp)+, %%d2-%%d5 // sp += 16
        \\ rts
        \\
        \\ // Child:
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined %%pc
    );
    asm volatile (
        \\ suba.l %%fp, %%fp
        \\
        \\ // d0 = func(a1)
        \\ move.l %%a1, -(%%sp)
        \\ jsr (%%a0)
        \\
        \\ // syscall(d0, d1)
        \\ move.l %%d0, %%d1
        \\ move.l #1, %%d0 // SYS_exit
        \\ trap #0
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    asm volatile ("trap #0"
        :
        : [number] "{d0}" (@intFromEnum(SYS.rt_sigreturn)),
        : "memory"
    );
}

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const GETLK = 12;
    pub const SETLK = 13;
    pub const SETLKW = 14;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i32;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

pub const timeval = extern struct {
    sec: time_t,
    usec: i32,
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
};

// TODO: not 100% sure of padding for msghdr
pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: i32,
    control: ?*anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: i32,
    control: ?*const anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const Stat = extern struct {
    dev: dev_t,
    __pad: i16,
    __ino_truncated: i32,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad2: i16,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    ino: ino_t,

    pub fn atime(self: @This()) timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) timespec {
        return self.ctim;
    }
};

pub const Elf_Symndx = u32;

// No VDSO used as of glibc 112a0ae18b831bf31f44d81b82666980312511d6.
pub const VDSO = void;

/// TODO
pub const ucontext_t = void;

/// TODO
pub const getcontext = {};
