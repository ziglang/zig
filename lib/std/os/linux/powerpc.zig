const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const socklen_t = linux.socklen_t;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const sockaddr = linux.sockaddr;
const timespec = linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
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
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
          [arg6] "{r8}" (arg6),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

const CloneFn = *const fn (arg: usize) callconv(.C) u8;

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) noreturn {
    asm volatile (
        \\ sc
        :
        : [number] "{r0}" (@intFromEnum(SYS.rt_sigreturn)),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
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

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const VDSO = struct {
    pub const CGT_SYM = "__kernel_clock_gettime";
    pub const CGT_VER = "LINUX_2.6.15";
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
};

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: usize,
    control: ?*anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: usize,
    control: ?*const anyopaque,
    controllen: socklen_t,
    flags: i32,
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __rdev_padding: i16,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [2]u32,

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

pub const timeval = extern struct {
    tv_sec: time_t,
    tv_usec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const greg_t = u32;
pub const gregset_t = [48]greg_t;
pub const fpregset_t = [33]f64;

pub const vrregset = extern struct {
    vrregs: [32][4]u32,
    vrsave: u32,
    _pad: [2]u32,
    vscr: u32,
};
pub const vrregset_t = vrregset;

pub const mcontext_t = extern struct {
    gp_regs: gregset_t,
    fp_regs: fpregset_t,
    v_regs: vrregset_t align(16),
};

pub const ucontext_t = extern struct {
    flags: u32,
    link: ?*ucontext_t,
    stack: stack_t,
    pad: [7]i32,
    regs: *mcontext_t,
    sigmask: sigset_t,
    pad2: [3]i32,
    mcontext: mcontext_t,
};

pub const Elf_Symndx = u32;

pub const MMAP2_UNIT = 4096;
