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
const sockaddr = linux.sockaddr;
const timespec = linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
        : "$1", "$3", "$4", "$5", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall_pipe(fd: *[2]i32) usize {
    return asm volatile (
        \\ .set noat
        \\ .set noreorder
        \\ syscall
        \\ blez $7, 1f
        \\ nop
        \\ b 2f
        \\ subu $2, $0, $2
        \\ 1:
        \\ sw $2, 0($4)
        \\ sw $3, 4($4)
        \\ 2:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(SYS.pipe)),
          [fd] "{$4}" (fd),
        : "$1", "$3", "$5", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
        : "$1", "$3", "$5", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
        : "$1", "$3", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
        : "$1", "$3", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
        : "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "{$8}" (arg5),
        : "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

// NOTE: The o32 calling convention requires the callee to reserve 16 bytes for
// the first four arguments even though they're passed in $a0-$a3.

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
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "{$8}" (arg5),
          [arg6] "{$9}" (arg6),
        : "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn syscall7(
    number: SYS,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    arg6: usize,
    arg7: usize,
) usize {
    return asm volatile (
        \\ syscall
        \\ blez $7, 1f
        \\ dsubu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> usize),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "{$8}" (arg5),
          [arg6] "{$9}" (arg6),
          [arg7] "{$10}" (arg7),
        : "$1", "$3", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

const CloneFn = *const fn (arg: usize) callconv(.C) u8;

/// This matches the libc clone function.
pub extern fn clone(func: CloneFn, stack: usize, flags: u32, arg: usize, ptid: *i32, tls: usize, ctid: *i32) usize;

pub fn restore() callconv(.Naked) noreturn {
    asm volatile (
        \\ syscall
        :
        : [number] "{$2}" (@intFromEnum(SYS.rt_sigreturn)),
        : "$1", "$3", "$4", "$5", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub fn restore_rt() callconv(.Naked) noreturn {
    asm volatile (
        \\ syscall
        :
        : [number] "{$2}" (@intFromEnum(SYS.rt_sigreturn)),
        : "$1", "$3", "$4", "$5", "$6", "$7", "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$24", "$25", "hi", "lo", "memory"
    );
}

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;

    pub const SETOWN = 24;
    pub const GETOWN = 23;
    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const GETLK = 33;
    pub const SETLK = 34;
    pub const SETLKW = 35;

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

pub const MMAP2_UNIT = 4096;

pub const VDSO = struct {
    pub const CGT_SYM = "__kernel_clock_gettime";
    pub const CGT_VER = "LINUX_2.6.39";
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    __pad0: [4]u8,
    start: off_t,
    len: off_t,
    pid: pid_t,
    __unused: [4]u8,
};

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

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i32;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: u32,
    __pad0: [3]u32, // Reserved for st_dev expansion
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: u32,
    __pad1: [3]u32,
    size: off_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    __pad3: u32,
    blocks: blkcnt_t,
    __pad4: [14]usize,

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

pub const Elf_Symndx = u32;

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

    /// Number of open files.
    NOFILE,

    /// Address space limit.
    AS,

    /// Largest resident set size, in bytes.
    /// This affects swapping; processes that are exceeding their
    /// resident set size will be more likely to have physical memory
    /// taken from them.
    RSS,

    /// Number of processes.
    NPROC,

    /// Locked-in-memory address space.
    MEMLOCK,

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
