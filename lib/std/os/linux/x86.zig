const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
        : .{ .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
        : .{ .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
        : .{ .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
        : .{ .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
        : .{ .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [arg5] "{edi}" (arg5),
        : .{ .memory = true });
}

pub fn syscall6(
    number: SYS,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    arg6: u32,
) u32 {
    // arg6 can't be passed to asm in a register because ebp might be reserved as the frame pointer
    // and there are no more GPRs available; so we'll need a memory operand for it. Adding that
    // memory operand means that on PIC we might need a reference to the GOT, which in turn needs
    // *its* own GPR, so we need to pass another arg in memory too! This is surprisingly hard to get
    // right, because we can't touch esp or ebp until we're done with the memory input (as that
    // input could be relative to esp or ebp).
    const args56: [2]u32 = .{ arg5, arg6 };
    return asm volatile (
        \\ push %[args56]
        \\ push %%ebp
        \\ mov 4(%%esp), %%ebp
        \\ mov %%edi, 4(%%esp)
        \\ // The saved %edi and %ebp are on the stack, and %ebp points to `args56`.
        \\ // Prepare the last two args, syscall, then pop the saved %ebp and %edi.
        \\ mov (%%ebp), %%edi
        \\ mov 4(%%ebp), %%ebp
        \\ int  $0x80
        \\ pop  %%ebp
        \\ pop  %%edi
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(number)),
          [arg1] "{ebx}" (arg1),
          [arg2] "{ecx}" (arg2),
          [arg3] "{edx}" (arg3),
          [arg4] "{esi}" (arg4),
          [args56] "rm" (&args56),
        : .{ .memory = true });
}

pub fn socketcall(call: u32, args: [*]const u32) u32 {
    return asm volatile ("int $0x80"
        : [ret] "={eax}" (-> u32),
        : [number] "{eax}" (@intFromEnum(SYS.socketcall)),
          [arg1] "{ebx}" (call),
          [arg2] "{ecx}" (@intFromPtr(args)),
        : .{ .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         +8,   +12,   +16,   +20, +24,  +28, +32
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         eax,       ebx,   ecx,   edx,  esi, edi
    asm volatile (
        \\  pushl %%ebp
        \\  movl %%esp,%%ebp
        \\  pushl %%ebx
        \\  pushl %%esi
        \\  pushl %%edi
        \\  // Setup the arguments
        \\  movl 16(%%ebp),%%ebx
        \\  movl 12(%%ebp),%%ecx
        \\  andl $-16,%%ecx
        \\  subl $20,%%ecx
        \\  movl 20(%%ebp),%%eax
        \\  movl %%eax,4(%%ecx)
        \\  movl 8(%%ebp),%%eax
        \\  movl %%eax,0(%%ecx)
        \\  movl 24(%%ebp),%%edx
        \\  movl 28(%%ebp),%%esi
        \\  movl 32(%%ebp),%%edi
        \\  movl $120,%%eax // SYS_clone
        \\  int $128
        \\  testl %%eax,%%eax
        \\  jz 1f
        \\  popl %%edi
        \\  popl %%esi
        \\  popl %%ebx
        \\  popl %%ebp
        \\  retl
        \\
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\  .cfi_undefined %%eip
    );
    asm volatile (
        \\  xorl %%ebp,%%ebp
        \\
        \\  popl %%eax
        \\  calll *%%eax
        \\  movl %%eax,%%ebx
        \\  movl $1,%%eax // SYS_exit
        \\  int $128
    );
}

pub fn restore() callconv(.naked) noreturn {
    switch (builtin.zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ int $0x80
            :
            : [number] "i" (@intFromEnum(SYS.sigreturn)),
        ),
        else => asm volatile (
            \\ int $0x80
            :
            : [number] "{eax}" (@intFromEnum(SYS.sigreturn)),
        ),
    }
}

pub fn restore_rt() callconv(.naked) noreturn {
    switch (builtin.zig_backend) {
        .stage2_c => asm volatile (
            \\ movl %[number], %%eax
            \\ int $0x80
            :
            : [number] "i" (@intFromEnum(SYS.rt_sigreturn)),
        ),
        else => asm volatile (
            \\ int $0x80
            :
            : [number] "{eax}" (@intFromEnum(SYS.rt_sigreturn)),
        ),
    }
}

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
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
    __dev_padding: u32,
    __ino_truncated: u32,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    __rdev_padding: u32,
    size: off_t,
    blksize: blksize_t,
    blocks: blkcnt_t,
    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    ino: ino_t,

    pub fn atime(self: @This()) std.os.linux.timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) std.os.linux.timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) std.os.linux.timespec {
        return self.ctim;
    }
};

pub const user_desc = extern struct {
    entry_number: u32,
    base_addr: u32,
    limit: u32,
    flags: packed struct(u32) {
        seg_32bit: u1,
        contents: u2,
        read_exec_only: u1,
        limit_in_pages: u1,
        seg_not_present: u1,
        useable: u1,
        _: u25 = undefined,
    },
};

/// socketcall() call numbers
pub const SC = struct {
    pub const socket = 1;
    pub const bind = 2;
    pub const connect = 3;
    pub const listen = 4;
    pub const accept = 5;
    pub const getsockname = 6;
    pub const getpeername = 7;
    pub const socketpair = 8;
    pub const send = 9;
    pub const recv = 10;
    pub const sendto = 11;
    pub const recvfrom = 12;
    pub const shutdown = 13;
    pub const setsockopt = 14;
    pub const getsockopt = 15;
    pub const sendmsg = 16;
    pub const recvmsg = 17;
    pub const accept4 = 18;
    pub const recvmmsg = 19;
    pub const sendmmsg = 20;
};
