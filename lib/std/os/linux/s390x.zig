const std = @import("../../std.zig");
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;
const linux = std.os.linux;
const SYS = linux.SYS;
const uid_t = std.os.linux.uid_t;
const gid_t = std.os.linux.gid_t;
const pid_t = std.os.linux.pid_t;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const timespec = std.os.linux.timespec;
const stack_t = std.os.linux.stack_t;
const sigset_t = std.os.linux.sigset_t;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
          [arg2] "{r3}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
          [arg2] "{r3}" (arg2),
          [arg3] "{r4}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
          [arg2] "{r3}" (arg2),
          [arg3] "{r4}" (arg3),
          [arg4] "{r5}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
          [arg2] "{r3}" (arg2),
          [arg3] "{r4}" (arg3),
          [arg4] "{r5}" (arg4),
          [arg5] "{r6}" (arg5),
        : "memory"
    );
}

pub fn syscall6(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, arg6: usize) usize {
    return asm volatile ("svc 0"
        : [ret] "={r2}" (-> usize),
        : [number] "{r1}" (@intFromEnum(number)),
          [arg1] "{r2}" (arg1),
          [arg2] "{r3}" (arg2),
          [arg3] "{r4}" (arg3),
          [arg4] "{r5}" (arg4),
          [arg5] "{r6}" (arg5),
          [arg6] "{r7}" (arg6),
        : "memory"
    );
}

pub fn clone() callconv(.Naked) usize {
    asm volatile (
        \\# int clone(
        \\#    fn,      a = r2
        \\#    stack,   b = r3
        \\#    flags,   c = r4
        \\#    arg,     d = r5
        \\#    ptid,    e = r6
        \\#    tls,     f = *(r15+160)
        \\#    ctid)    g = *(r15+168)
        \\#
        \\# pseudo C code:
        \\# tid = syscall(SYS_clone,b,c,e,g,f);
        \\# if (!tid) syscall(SYS_exit, a(d));
        \\# return tid;
        \\
        \\# preserve call-saved register used as syscall arg
        \\stg  %%r6, 48(%%r15)
        \\
        \\# create initial stack frame for new thread
        \\nill %%r3, 0xfff8
        \\aghi %%r3, -160
        \\lghi %%r0, 0
        \\stg  %%r0, 0(%%r3)
        \\
        \\# save fn and arg to child stack
        \\stg  %%r2,  8(%%r3)
        \\stg  %%r5, 16(%%r3)
        \\
        \\# shuffle args into correct registers and call SYS_clone
        \\lgr  %%r2, %%r3
        \\lgr  %%r3, %%r4
        \\lgr  %%r4, %%r6
        \\lg   %%r5, 168(%%r15)
        \\lg   %%r6, 160(%%r15)
        \\svc  120
        \\
        \\# restore call-saved register
        \\lg   %%r6, 48(%%r15)
        \\
        \\# if error or if we're the parent, return
        \\ltgr %%r2, %%r2
        \\bnzr %%r14
        \\
        \\# we're the child. call fn(arg)
        \\lg   %%r1,  8(%%r15)
        \\lg   %%r2, 16(%%r15)
        \\basr %%r14, %%r1
        \\
        \\# call SYS_exit. exit code is already in r2 from fn return value
        \\svc  1
        \\
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) noreturn {
    asm volatile (
        \\svc 0
        :
        : [number] "{r1}" (@intFromEnum(SYS.rt_sigreturn)),
        : "memory"
    );
}

pub const F = struct {
    pub const DUPFD = 0;
    pub const GETFD = 1;
    pub const SETFD = 2;
    pub const GETFL = 3;
    pub const SETFL = 4;
    pub const GETLK = 5;
    pub const SETLK = 6;
    pub const SETLKW = 7;
    pub const SETOWN = 8;
    pub const GETOWN = 9;
    pub const SETSIG = 10;
    pub const GETSIG = 11;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

pub const blksize_t = i64;
pub const nlink_t = u64;
pub const time_t = i64;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

pub const timeval = extern struct {
    sec: time_t,
    usec: i64,
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
    __pad1: i32 = 0,
    iovlen: i32,
    control: ?*anyopaque,
    __pad2: i32 = 0,
    controllen: socklen_t,
    flags: i32,
};

pub const msghdr_const = extern struct {
    name: ?*const sockaddr,
    namelen: socklen_t,
    iov: [*]const iovec_const,
    __pad1: i32 = 0,
    iovlen: i32,
    control: ?*const anyopaque,
    __pad2: i32 = 0,
    controllen: socklen_t,
    flags: i32,
};

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
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    blksize: blksize_t,
    blocks: blkcnt_t,
    __unused: [3]c_ulong,

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

pub const Elf_Symndx = u64;

pub const VDSO = struct {
    pub const CGT_SYM = "__kernel_clock_gettime";
    pub const CGT_VER = "LINUX_2.6.29";
};

pub const ucontext_t = extern struct {
    flags: u64,
    link: ?*ucontext_t,
    stack: stack_t,
    mcontext: mcontext_t,
    sigmask: sigset_t,
};

pub const mcontext_t = extern struct {
    __regs1: [18]u64,
    __regs2: [18]u32,
    __regs3: [16]f64,
};

/// TODO
pub const getcontext = {};
