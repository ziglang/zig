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

pub fn syscall0(number: SYS) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
        : "memory"
    );
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
        : "memory"
    );
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
        : "memory"
    );
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
        : "memory"
    );
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
        : "memory"
    );
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
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
    return asm volatile ("trap0(#1)"
        : [ret] "={r0}" (-> usize),
        : [number] "{r6}" (@intFromEnum(number)),
          [arg1] "{r0}" (arg1),
          [arg2] "{r1}" (arg2),
          [arg3] "{r2}" (arg3),
          [arg4] "{r3}" (arg4),
          [arg5] "{r4}" (arg5),
          [arg6] "{r5}" (arg6),
        : "memory"
    );
}

pub fn clone() callconv(.Naked) usize {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         r0,   r1,    r2,    r3,  r4,   r5,  +0
    //
    // syscall(SYS_clone, flags, stack, ptid, ctid, tls)
    //         r6         r0,    r1,    r2,   r3,   r4
    asm volatile (
        \\ allocframe(#8)
        \\
        \\ r11 = r0
        \\ r10 = r3
        \\
        \\ r6 = #220 // SYS_clone
        \\ r0 = r2
        \\ r1 = and(r1, #-8)
        \\ r2 = r4
        \\ r3 = memw(r30 + #8)
        \\ r4 = r5
        \\ trap0(#1)
        \\
        \\ p0 = cmp.eq(r0, #0)
        \\ if (!p0) dealloc_return
        \\
        \\ r0 = r10
        \\ callr r11
        \\
        \\ r6 = #93 // SYS_exit
        \\ r0 = #0
        \\ trap0(#1)
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.Naked) noreturn {
    asm volatile (
        \\ trap0(#0)
        :
        : [number] "{r6}" (@intFromEnum(SYS.rt_sigreturn)),
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

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;

    pub const SETOWN_EX = 15;
    pub const GETOWN_EX = 16;

    pub const GETOWNER_UIDS = 17;
};

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
pub const time_t = i32;
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
    __pad: u32,
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

pub const Elf_Symndx = u32;

pub const MMAP2_UNIT = 4096;

pub const VDSO = void;

/// TODO
pub const ucontext_t = void;

/// TODO
pub const getcontext = {};
