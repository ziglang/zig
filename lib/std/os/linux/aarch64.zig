const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const socklen_t = linux.socklen_t;
const sockaddr = linux.sockaddr;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const pid_t = linux.pid_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const timespec = std.os.linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
        : "memory", "cc"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
        : "memory", "cc"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
        : "memory", "cc"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
        : "memory", "cc"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4),
        : "memory", "cc"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4),
          [arg5] "{x4}" (arg5),
        : "memory", "cc"
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
    return asm volatile ("svc #0"
        : [ret] "={x0}" (-> usize),
        : [number] "{x8}" (@intFromEnum(number)),
          [arg1] "{x0}" (arg1),
          [arg2] "{x1}" (arg2),
          [arg3] "{x2}" (arg3),
          [arg4] "{x3}" (arg4),
          [arg5] "{x4}" (arg5),
          [arg6] "{x5}" (arg6),
        : "memory", "cc"
    );
}

pub fn clone() callconv(.Naked) usize {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         x0,   x1,    w2,    x3,  x4,   x5,  x6
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         x8,        x0,    x1,    x2,   x3,  x4
    asm volatile (
        \\      // align stack and save func,arg
        \\      and x1,x1,#-16
        \\      stp x0,x3,[x1,#-16]!
        \\
        \\      // syscall
        \\      uxtw x0,w2
        \\      mov x2,x4
        \\      mov x3,x5
        \\      mov x4,x6
        \\      mov x8,#220 // SYS_clone
        \\      svc #0
        \\
        \\      cbz x0,1f
        \\      // parent
        \\      ret
        \\      // child
        \\1:    ldp x1,x0,[sp],#16
        \\      blr x1
        \\      mov x8,#93 // SYS_exit
        \\      svc #0
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ mov x8, %[number]
            \\ svc #0
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
            : "memory", "cc"
        ),
        else => asm volatile (
            \\ svc #0
            :
            : [number] "{x8}" (@intFromEnum(SYS.rt_sigreturn)),
            : "memory", "cc"
        ),
    }
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

pub const VDSO = struct {
    pub const CGT_SYM = "__kernel_clock_gettime";
    pub const CGT_VER = "LINUX_2.6.39";
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
    iovlen: i32,
    __pad1: i32 = 0,
    control: ?*anyopaque,
    controllen: socklen_t,
    __pad2: socklen_t = 0,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    iovlen: i32,
    __pad1: i32 = 0,
    control: ?*const anyopaque,
    controllen: socklen_t,
    __pad2: socklen_t = 0,
    flags: i32,
};

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = isize;
pub const mode_t = u32;
pub const off_t = isize;
pub const ino_t = usize;
pub const dev_t = usize;
pub const blkcnt_t = isize;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad: usize,
    size: off_t,
    blksize: blksize_t,
    __pad2: i32,
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
    sec: isize,
    usec: isize,
};

pub const timezone = extern struct {
    minuteswest: i32,
    dsttime: i32,
};

pub const mcontext_t = extern struct {
    fault_address: usize,
    regs: [31]usize,
    sp: usize,
    pc: usize,
    pstate: usize,
    // Make sure the field is correctly aligned since this area
    // holds various FP/vector registers
    reserved1: [256 * 16]u8 align(16),
};

pub const ucontext_t = extern struct {
    flags: usize,
    link: ?*ucontext_t,
    stack: stack_t,
    sigmask: sigset_t,
    mcontext: mcontext_t,
};

/// TODO
pub const getcontext = {};

pub const Elf_Symndx = u32;
