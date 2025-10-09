const builtin = @import("builtin");
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
    // r0 is both an input register and a clobber. musl and glibc achieve this with
    // a "+" constraint, which isn't supported in Zig, so instead we separately list
    // r0 as both an input and an output. (Listing it as an input and a clobber would
    // cause the C backend to emit invalid code; see #25209.)
    var r0_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
        : [number] "{r0}" (@intFromEnum(number)),
        : .{ .memory = true, .cr0 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn syscall1(number: SYS, arg1: usize) usize {
    // r0 is both an input and a clobber.
    var r0_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
        : .{ .memory = true, .cr0 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize {
    // These registers are both inputs and clobbers.
    var r0_out: usize = undefined;
    var r4_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
          [r4_out] "={r4}" (r4_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
        : .{ .memory = true, .cr0 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn syscall3(number: SYS, arg1: usize, arg2: usize, arg3: usize) usize {
    // These registers are both inputs and clobbers.
    var r0_out: usize = undefined;
    var r4_out: usize = undefined;
    var r5_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
          [r4_out] "={r4}" (r4_out),
          [r5_out] "={r5}" (r5_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
        : .{ .memory = true, .cr0 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn syscall4(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize) usize {
    // These registers are both inputs and clobbers.
    var r0_out: usize = undefined;
    var r4_out: usize = undefined;
    var r5_out: usize = undefined;
    var r6_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
          [r4_out] "={r4}" (r4_out),
          [r5_out] "={r5}" (r5_out),
          [r6_out] "={r6}" (r6_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
        : .{ .memory = true, .cr0 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn syscall5(number: SYS, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize) usize {
    // These registers are both inputs and clobbers.
    var r0_out: usize = undefined;
    var r4_out: usize = undefined;
    var r5_out: usize = undefined;
    var r6_out: usize = undefined;
    var r7_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
          [r4_out] "={r4}" (r4_out),
          [r5_out] "={r5}" (r5_out),
          [r6_out] "={r6}" (r6_out),
          [r7_out] "={r7}" (r7_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
        : .{ .memory = true, .cr0 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
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
    // These registers are both inputs and clobbers.
    var r0_out: usize = undefined;
    var r4_out: usize = undefined;
    var r5_out: usize = undefined;
    var r6_out: usize = undefined;
    var r7_out: usize = undefined;
    var r8_out: usize = undefined;
    return asm volatile (
        \\ sc
        \\ bns+ 1f
        \\ neg 3, 3
        \\ 1:
        : [ret] "={r3}" (-> usize),
          [r0_out] "={r0}" (r0_out),
          [r4_out] "={r4}" (r4_out),
          [r5_out] "={r5}" (r5_out),
          [r6_out] "={r6}" (r6_out),
          [r7_out] "={r7}" (r7_out),
          [r8_out] "={r8}" (r8_out),
        : [number] "{r0}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
          [arg6] "{r8}" (arg6),
        : .{ .memory = true, .cr0 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .ctr = true, .xer = true });
}

pub fn clone() callconv(.naked) usize {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         3,    4,     5,     6,   7,    8,   9
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         0          3,     4,     5,    6,   7
    asm volatile (
        \\  # create initial stack frame for new thread
        \\  clrrdi 4, 4, 4
        \\  li     0, 0
        \\  stdu   0,-32(4)
        \\
        \\  # save fn and arg to child stack
        \\  std    3,  8(4)
        \\  std    6, 16(4)
        \\
        \\  # shuffle args into correct registers and call SYS_clone
        \\  mr    3, 5
        \\  #mr   4, 4
        \\  mr    5, 7
        \\  mr    6, 8
        \\  mr    7, 9
        \\  li    0, 120  # SYS_clone = 120
        \\  sc
        \\
        \\  # if error, negate return (errno)
        \\  bns+  1f
        \\  neg   3, 3
        \\
        \\1:
        \\  # if we're the parent, return
        \\  cmpwi cr7, 3, 0
        \\  bnelr cr7
        \\
        \\  # we're the child
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\  .cfi_undefined lr
    );
    asm volatile (
        \\  li    31, 0
        \\  mtlr   0
        \\
        \\  # call fn(arg)
        \\  ld     3, 16(1)
        \\  ld    12,  8(1)
        \\  mtctr 12
        \\  bctrl
        \\
        \\  # call SYS_exit. exit code is already in r3 from fn return value
        \\  li    0, 1    # SYS_exit = 1
        \\  sc
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    switch (@import("builtin").zig_backend) {
        .stage2_c => asm volatile (
            \\ li 0, %[number]
            \\ sc
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
        ),
        else => _ = asm volatile (
            \\ sc
            :
            : [number] "{r0}" (@intFromEnum(SYS.rt_sigreturn)),
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
    sec: isize,
    usec: isize,
};

pub const timezone = extern struct {
    minuteswest: i32,
    dsttime: i32,
};

pub const Elf_Symndx = u32;
