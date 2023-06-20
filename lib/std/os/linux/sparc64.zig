const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const pid_t = linux.pid_t;
const uid_t = linux.uid_t;
const clock_t = linux.clock_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;

const linux = std.os.linux;
const SYS = linux.SYS;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const iovec = std.os.iovec;
const iovec_const = std.os.iovec_const;
const timespec = linux.timespec;

pub fn syscall_pipe(fd: *[2]i32) usize {
    return asm volatile (
        \\ mov %[arg], %%g3
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ # Return the error code
        \\ ba 2f
        \\ neg %%o0
        \\1:
        \\ st %%o0, [%%g3+0]
        \\ st %%o1, [%%g3+4]
        \\ clr %%o0
        \\2:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(SYS.pipe)),
          [arg] "r" (fd),
        : "memory", "g3"
    );
}

pub fn syscall_fork() usize {
    // Linux/sparc64 fork() returns two values in %o0 and %o1:
    // - On the parent's side, %o0 is the child's PID and %o1 is 0.
    // - On the child's side, %o0 is the parent's PID and %o1 is 1.
    // We need to clear the child's %o0 so that the return values
    // conform to the libc convention.
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ ba 2f
        \\ neg %%o0
        \\ 1:
        \\ # Clear the child's %%o0
        \\ dec %%o1
        \\ and %%o1, %%o0, %%o0
        \\ 2:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(SYS.fork)),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall0(number: SYS) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
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
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> usize),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
          [arg6] "{o5}" (arg6),
        : "memory", "xcc", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

const CloneFn = *const fn (arg: usize) callconv(.C) u8;

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: usize, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub const restore = restore_rt;

// Need to use C ABI here instead of naked
// to prevent an infinite loop when calling rt_sigreturn.
pub fn restore_rt() callconv(.C) void {
    return asm volatile ("t 0x6d"
        :
        : [number] "{g1}" (@intFromEnum(SYS.rt_sigreturn)),
        : "memory", "xcc", "o0", "o1", "o2", "o3", "o4", "o5", "o7"
    );
}

pub const O = struct {
    pub const CREAT = 0x200;
    pub const EXCL = 0x800;
    pub const NOCTTY = 0x8000;
    pub const TRUNC = 0x400;
    pub const APPEND = 0x8;
    pub const NONBLOCK = 0x4000;
    pub const SYNC = 0x802000;
    pub const DSYNC = 0x2000;
    pub const RSYNC = SYNC;
    pub const DIRECTORY = 0x10000;
    pub const NOFOLLOW = 0x20000;
    pub const CLOEXEC = 0x400000;

    pub const ASYNC = 0x40;
    pub const DIRECT = 0x100000;
    pub const LARGEFILE = 0;
    pub const NOATIME = 0x200000;
    pub const PATH = 0x1000000;
    pub const TMPFILE = 0x2010000;
    pub const NDELAY = NONBLOCK | 0x4;
};

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const SETOWN = 5;
    pub const GETOWN = 6;
    pub const GETLK = 7;
    pub const SETLK = 8;
    pub const SETLKW = 9;

    pub const RDLCK = 1;
    pub const WRLCK = 2;
    pub const UNLCK = 3;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const LOCK = struct {
    pub const SH = 1;
    pub const EX = 2;
    pub const NB = 4;
    pub const UN = 8;
};

pub const MAP = struct {
    /// stack-like segment
    pub const GROWSDOWN = 0x0200;
    /// ETXTBSY
    pub const DENYWRITE = 0x0800;
    /// mark it as an executable
    pub const EXECUTABLE = 0x1000;
    /// pages are locked
    pub const LOCKED = 0x0100;
    /// don't check for reservations
    pub const NORESERVE = 0x0040;
};

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
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
    iovlen: u64,
    control: ?*anyopaque,
    controllen: u64,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: u64,
    control: ?*const anyopaque,
    controllen: u64,
    flags: i32,
};

pub const off_t = i64;
pub const ino_t = u64;
pub const mode_t = u32;
pub const dev_t = usize;
pub const nlink_t = u32;
pub const blksize_t = isize;
pub const blkcnt_t = isize;

// The `stat64` definition used by the kernel.
pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: u64,

    mode: u32,
    uid: u32,
    gid: u32,
    __pad0: u32,

    rdev: u64,
    size: i64,
    blksize: i64,
    blocks: i64,

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
    tv_usec: i32,
};

pub const timezone = extern struct {
    tz_minuteswest: i32,
    tz_dsttime: i32,
};

// TODO I'm not sure if the code below is correct, need someone with more
// knowledge about sparc64 linux internals to look into.

pub const Elf_Symndx = u32;

pub const fpstate = extern struct {
    regs: [32]u64,
    fsr: u64,
    gsr: u64,
    fprs: u64,
};

pub const __fpq = extern struct {
    fpq_addr: *u32,
    fpq_instr: u32,
};

pub const __fq = extern struct {
    FQu: extern union {
        whole: f64,
        fpq: __fpq,
    },
};

pub const fpregset_t = extern struct {
    fpu_fr: extern union {
        fpu_regs: [32]u32,
        fpu_dregs: [32]f64,
        fpu_qregs: [16]c_longdouble,
    },
    fpu_q: *__fq,
    fpu_fsr: u64,
    fpu_qcnt: u8,
    fpu_q_entrysize: u8,
    fpu_en: u8,
};

pub const siginfo_fpu_t = extern struct {
    float_regs: [64]u32,
    fsr: u64,
    gsr: u64,
    fprs: u64,
};

pub const sigcontext = extern struct {
    info: [128]i8,
    regs: extern struct {
        u_regs: [16]u64,
        tstate: u64,
        tpc: u64,
        tnpc: u64,
        y: u64,
        fprs: u64,
    },
    fpu_save: *siginfo_fpu_t,
    stack: extern struct {
        sp: usize,
        flags: i32,
        size: u64,
    },
    mask: u64,
};

pub const greg_t = u64;
pub const gregset_t = [19]greg_t;

pub const fq = extern struct {
    addr: *u64,
    insn: u32,
};

pub const fpu_t = extern struct {
    fregs: extern union {
        sregs: [32]u32,
        dregs: [32]u64,
        qregs: [16]c_longdouble,
    },
    fsr: u64,
    fprs: u64,
    gsr: u64,
    fq: *fq,
    qcnt: u8,
    qentsz: u8,
    enab: u8,
};

pub const mcontext_t = extern struct {
    gregs: gregset_t,
    fp: greg_t,
    i7: greg_t,
    fpregs: fpu_t,
};

pub const ucontext_t = extern struct {
    link: ?*ucontext_t,
    flags: u64,
    sigmask: u64,
    mcontext: mcontext_t,
    stack: stack_t,
    sigmask: sigset_t,
};

pub const rlimit_resource = enum(c_int) {
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

    /// Number of open files.
    NOFILE,

    /// Number of processes.
    NPROC,

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
