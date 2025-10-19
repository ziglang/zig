const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u64) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u64, arg2: u64) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
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
    arg1: u64,
    arg2: u64,
    arg3: u64,
    arg4: u64,
    arg5: u64,
    arg6: u64,
) u64 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(number)),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

pub fn clone() callconv(.naked) u64 {
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

pub const time_t = i64;

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
