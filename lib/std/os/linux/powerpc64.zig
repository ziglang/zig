const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const socklen_t = linux.socklen_t;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
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
        : [number] "{r0}" (@enumToInt(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
          [arg6] "{r8}" (arg6),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

const CloneFn = std.meta.FnPtr(fn (arg: usize) callconv(.C) u8);

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) void {
    return asm volatile ("sc"
        :
        : [number] "{r0}" (@enumToInt(SYS.rt_sigreturn)),
        : "memory", "cr0", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12"
    );
}

pub const O = struct {
    pub const CREAT = 0o100;
    pub const EXCL = 0o200;
    pub const NOCTTY = 0o400;
    pub const TRUNC = 0o1000;
    pub const APPEND = 0o2000;
    pub const NONBLOCK = 0o4000;
    pub const DSYNC = 0o10000;
    pub const SYNC = 0o4010000;
    pub const RSYNC = 0o4010000;
    pub const DIRECTORY = 0o40000;
    pub const NOFOLLOW = 0o100000;
    pub const CLOEXEC = 0o2000000;

    pub const ASYNC = 0o20000;
    pub const DIRECT = 0o400000;
    pub const LARGEFILE = 0o200000;
    pub const NOATIME = 0o1000000;
    pub const PATH = 0o10000000;
    pub const TMPFILE = 0o20200000;
    pub const NDELAY = NONBLOCK;
};

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

    pub const GETLK = 5;
    pub const SETLK = 6;
    pub const SETLKW = 7;

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const UN = 8;
    pub const NB = 4;
};

pub const MAP = struct {
    /// stack-like segment
    pub const GROWSDOWN = 0x0100;
    /// ETXTBSY
    pub const DENYWRITE = 0x0800;
    /// mark it as an executable
    pub const EXECUTABLE = 0x1000;
    /// pages are locked
    pub const LOCKED = 0x0080;
    /// don't check for reservations
    pub const NORESERVE = 0x0040;
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
    __unused: [4]u8,
};

pub const msghdr = extern struct {
    name: ?*sockaddr,
    namelen: socklen_t,
    iov: [*]iovec,
    iovlen: usize,
    control: ?*anyopaque,
    controllen: usize,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: usize,
    control: ?*const anyopaque,
    controllen: usize,
    flags: i32,
};

pub const blksize_t = i64;
pub const nlink_t = u64;
pub const time_t = i64;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,
    mode: mode_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]u64,

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
    tv_sec: isize,
    tv_usec: isize,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

pub const greg_t = u64;
pub const gregset_t = [48]greg_t;
pub const fpregset_t = [33]f64;

/// The position of the vscr register depends on endianness.
/// On C, macros are used to change vscr_word's offset to
/// account for this. Here we'll just define vscr_word_le
/// and vscr_word_be. Code must take care to use the correct one.
pub const vrregset = extern struct {
    vrregs: [32][4]u32 align(16),
    vscr_word_le: u32,
    _pad1: [2]u32,
    vscr_word_be: u32,
    vrsave: u32,
    _pad2: [3]u32,
};
pub const vrregset_t = vrregset;

pub const mcontext_t = extern struct {
    __unused: [4]u64,
    signal: i32,
    _pad0: i32,
    handler: u64,
    oldmask: u64,
    regs: ?*anyopaque,
    gp_regs: gregset_t,
    fp_regs: fpregset_t,
    v_regs: *vrregset_t,
    vmx_reserve: [34 + 34 + 32 + 1]i64,
};

pub const ucontext_t = extern struct {
    flags: u32,
    link: ?*ucontext_t,
    stack: stack_t,
    sigmask: sigset_t,
    mcontext: mcontext_t,
};

pub const Elf_Symndx = u32;
