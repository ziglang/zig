const builtin = @import("builtin");
const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
const linux = std.os.linux;
const SYS = linux.SYS;
const iovec = std.posix.iovec;
const iovec_const = std.posix.iovec_const;

const pid_t = linux.pid_t;
const uid_t = linux.uid_t;
const gid_t = linux.gid_t;
const clock_t = linux.clock_t;
const stack_t = linux.stack_t;
const sigset_t = linux.sigset_t;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const timespec = linux.timespec;

pub fn syscall0(number: SYS) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
        : .{ .rcx = true, .r11 = true, .memory = true });
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
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> usize),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn clone() callconv(.naked) usize {
    asm volatile (
        \\      movl $56,%%eax // SYS_clone
        \\      movq %%rdi,%%r11
        \\      movq %%rdx,%%rdi
        \\      movq %%r8,%%rdx
        \\      movq %%r9,%%r8
        \\      movq 8(%%rsp),%%r10
        \\      movq %%r11,%%r9
        \\      andq $-16,%%rsi
        \\      subq $8,%%rsi
        \\      movq %%rcx,(%%rsi)
        \\      syscall
        \\      testq %%rax,%%rax
        \\      jz 1f
        \\      retq
        \\
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\      .cfi_undefined %%rip
    );
    asm volatile (
        \\      xorl %%ebp,%%ebp
        \\
        \\      popq %%rdi
        \\      callq *%%r9
        \\      movl %%eax,%%edi
        \\      movl $60,%%eax // SYS_exit
        \\      syscall
        \\
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ syscall
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
        ),
        else => asm volatile (
            \\ syscall
            :
            : [number] "{rax}" (@intFromEnum(SYS.rt_sigreturn)),
        ),
    }
}

pub const mode_t = usize;
pub const time_t = isize;
pub const nlink_t = usize;
pub const blksize_t = isize;
pub const blkcnt_t = isize;

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

    pub const RDLCK = 0;
    pub const WRLCK = 1;
    pub const UNLCK = 2;
};

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";

    pub const GETCPU_SYM = "__vdso_getcpu";
    pub const GETCPU_VER = "LINUX_2.6";
};

pub const ARCH = struct {
    pub const SET_GS = 0x1001;
    pub const SET_FS = 0x1002;
    pub const GET_FS = 0x1003;
    pub const GET_GS = 0x1004;
};

pub const Flock = extern struct {
    type: i16,
    whence: i16,
    start: off_t,
    len: off_t,
    pid: pid_t,
};

pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: usize,

    mode: u32,
    uid: uid_t,
    gid: gid_t,
    __pad0: u32,
    rdev: dev_t,
    size: off_t,
    blksize: isize,
    blocks: i64,

    atim: timespec,
    mtim: timespec,
    ctim: timespec,
    __unused: [3]isize,

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

pub const Elf_Symndx = u32;
