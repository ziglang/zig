const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
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
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    arg6: u32,
) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    asm volatile (
        \\      movl $0x40000038,%%eax // SYS_clone
        \\      mov %%rdi,%%r11
        \\      mov %%rdx,%%rdi
        \\      mov %%r8,%%rdx
        \\      mov %%r9,%%r8
        \\      mov 8(%%rsp),%%r10
        \\      mov %%r11,%%r9
        \\      and $-16,%%rsi
        \\      sub $8,%%rsi
        \\      mov %%rcx,(%%rsi)
        \\      syscall
        \\      test %%eax,%%eax
        \\      jz 1f
        \\      ret
        \\
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\      .cfi_undefined %%rip
    );
    asm volatile (
        \\      xor %%ebp,%%ebp
        \\
        \\      pop %%rdi
        \\      call *%%r9
        \\      mov %%eax,%%edi
        \\      movl $0x4000003c,%%eax // SYS_exit
        \\      syscall
        \\
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    switch (builtin.zig_backend) {
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

pub const mode_t = u32;
pub const time_t = i32;
pub const nlink_t = u32;
pub const blksize_t = i32;
pub const blkcnt_t = i32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;

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

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,

    mode: mode_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    __pad0: u32,
    rdev: dev_t,
    size: off_t,
    blksize: blksize_t,
    blocks: i64,

    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    __unused: [3]i32,

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
