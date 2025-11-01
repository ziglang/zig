const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
        : .{ .r1 = true, .r3 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall_pipe(fd: *[2]i32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 2f
        \\ subu $v0, $zero, $v0
        \\ b 2f
        \\1:
        \\ sw $v0, 0($a0)
        \\ sw $v1, 4($a0)
        \\2:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(SYS.pipe)),
          [fd] "{$4}" (fd),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
        : .{ .r1 = true, .r3 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
        : .{ .r1 = true, .r3 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

// NOTE: The o32 calling convention requires the callee to reserve 16 bytes for
// the first four arguments even though they're passed in $a0-$a3.

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile (
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
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
    return asm volatile (
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ sw %[arg6], 20($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5),
          [arg6] "r" (arg6),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall7(
    number: SYS,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    arg6: u32,
    arg7: u32,
) u32 {
    return asm volatile (
        \\ subu $sp, $sp, 32
        \\ sw %[arg5], 16($sp)
        \\ sw %[arg6], 20($sp)
        \\ sw %[arg7], 24($sp)
        \\ syscall
        \\ addu $sp, $sp, 32
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ subu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5),
          [arg6] "r" (arg6),
          [arg7] "r" (arg7),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         a0,   a1,    a2,    a3,  +0,   +4,  +8
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         v0         a0,    a1,    a2,   a3,  +0
    asm volatile (
        \\ # Save function pointer and argument pointer on new thread stack
        \\ and $a1, $a1, -8
        \\ subu $a1, $a1, 16
        \\ sw $a0, 0($a1)
        \\ sw $a3, 4($a1)
        \\
        \\ # Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
        \\ move $a0, $a2
        \\ lw $a2, 16($sp)
        \\ lw $a3, 20($sp)
        \\ lw $t1, 24($sp)
        \\ subu $sp, $sp, 16
        \\ sw $t1, 16($sp)
        \\ li $v0, 4120 # SYS_clone
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 2f
        \\ subu $v0, $zero, $v0
        \\ b 2f
        \\1:
        \\ beq $v0, $zero, 3f
        \\2:
        \\ addu $sp, $sp, 16
        \\ jr $ra
        \\3:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined $ra
    );
    asm volatile (
        \\ move $fp, $zero
        \\ move $ra, $zero
        \\
        \\ lw $t9, 0($sp)
        \\ lw $a0, 4($sp)
        \\ jalr $t9
        \\
        \\ move $a0, $v0
        \\ li $v0, 4001 # SYS_exit
        \\ syscall
    );
}

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
};

pub const blksize_t = u32;
pub const nlink_t = u32;
pub const time_t = i32;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;
