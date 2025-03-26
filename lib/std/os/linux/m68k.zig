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
    asm volatile (
        \\ // int clone(
        \\ //   fn, 
        \\ //   stack, (d2)
        \\ //   flags, (d1)
        \\ //   arg, 
        \\ //   ptid, (d3)
        \\ //   tls, (d4)
        \\ //   ctid (d5)
        \\ //)
        \\
        \\  // save child stack and func into scratch registers
        \\  movel 8(%%sp), a0
        \\  movel 4(%%sp), a1
        \\
        \\  // push arg to child stack
        \\  movel 16(%%sp), -(%%a0)  
        \\
        \\  // save callee saved register to parent and child stacks,
        \\  // then load arg
        \\
        \\  // flag (not callee saved)
        \\  movel 12(%%sp), %%d1 
        \\  
        \\  // ptid
        \\  movel %%d3, -(%%sp)
        \\  movel %%d3, -(%%a0)
        \\  movel 20+4(%%sp), %%d3 
        \\
        \\  // tls
        \\  movel %%d4, -(%%sp)
        \\  movel %%d4, -(%%a0)
        \\  movel 24+8(%%sp), %%d4 
        \\
        \\  // child_tidptr
        \\  movel %%d5, -(%%sp)
        \\  movel %%d5, -(%%a0)
        \\  movel 28+12(%%sp), %%d5
        \\ 
        \\  // stack
        \\  movel %%d2, -(%%sp)
        \\  movel %%d2, -(%%a0)
        \\  exg %%a0, %%d2
        \\  
        \\  movl #120, %%d0
        \\  trap #0
        \\
        \\  movel (%%sp)+, %%d2
        \\  movel (%%sp)+, %%d5
        \\  movel (%%sp)+, %%d4
        \\  movel (%%sp)+, %%d3
        \\
        \\  tstl %%d0
        \\
        \\  jeq 1f
        \\
        \\  // parent: returns pid of child or -1 on error
        \\  rts 
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined %%pc
    );
    asm volatile (
        \\ subl %%fp, %%fp // zero fp
        \\ jsr (%%a0) // call func 
        \\ 
        \\ // exit with return value
        \\ movel %%d0, %%d1
        \\ movel #1, %%d0
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
pub const off_t = i32;
pub const ino_t = u32;
pub const dev_t = u32;
pub const blkcnt_t = i32;

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
    __pad: u16,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: uid_t,
    gid: gid_t,
    rdev: dev_t,
    __pad2: u16,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [2]i32,

    // Old interface
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

// m68k has multiple minimum page sizes.
// glibc sets MMAP2_PAGE_UNIT to -1 so it is queried at runtime.
pub const MMAP2_UNIT = -1;

// glibc 112a0ae18b831bf31f44d81b82666980312511d6
pub const VDSO = void;

/// TODO
pub const ucontext_t = void;

/// TODO
pub const getcontext = {};
