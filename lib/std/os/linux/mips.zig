const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
        : .{ .r1 = true, .r3 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall_pipe(fd: *[2]i32) u32 {
    return asm volatile (
        \\ .set noat
        \\ .set noreorder
        \\ syscall
        \\ beq $7, $zero, 1f
        \\ nop
        \\ b 2f
        \\ subu $2, $0, $2
        \\ 1:
        \\ sw $2, 0($4)
        \\ sw $3, 4($4)
        \\ 2:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(SYS.pipe)),
          [fd] "{$4}" (fd),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
        : .{ .r1 = true, .r3 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile (
        \\ syscall
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
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
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile (
        \\ .set noat
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
        : [ret] "={$2}" (-> u32),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "r" (arg5),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

// NOTE: The o32 calling convention requires the callee to reserve 16 bytes for
// the first four arguments even though they're passed in $a0-$a3.

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
        \\ .set noat
        \\ subu $sp, $sp, 24
        \\ sw %[arg5], 16($sp)
        \\ sw %[arg6], 20($sp)
        \\ syscall
        \\ addu $sp, $sp, 24
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
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
        \\ .set noat
        \\ subu $sp, $sp, 32
        \\ sw %[arg5], 16($sp)
        \\ sw %[arg6], 20($sp)
        \\ sw %[arg7], 24($sp)
        \\ syscall
        \\ addu $sp, $sp, 32
        \\ beq $7, $zero, 1f
        \\ blez $2, 1f
        \\ subu $2, $0, $2
        \\ 1:
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
    //         3,    4,     5,     6,   7,    8,   9
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         2          4,     5,     6,    7,   8
    asm volatile (
        \\  # Save function pointer and argument pointer on new thread stack
        \\  and $5, $5, -8
        \\  subu $5, $5, 16
        \\  sw $4, 0($5)
        \\  sw $7, 4($5)
        \\  # Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
        \\  move $4, $6
        \\  lw $6, 16($sp)
        \\  lw $7, 20($sp)
        \\  lw $9, 24($sp)
        \\  subu $sp, $sp, 16
        \\  sw $9, 16($sp)
        \\  li $2, 4120 # SYS_clone
        \\  syscall
        \\  beq $7, $0, 1f
        \\  nop
        \\  addu $sp, $sp, 16
        \\  jr $ra
        \\  subu $2, $0, $2
        \\1:
        \\  beq $2, $0, 1f
        \\  nop
        \\  addu $sp, $sp, 16
        \\  jr $ra
        \\  nop
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\  .cfi_undefined $ra
    );
    asm volatile (
        \\  move $fp, $zero
        \\  move $ra, $zero
        \\
        \\  lw $25, 0($sp)
        \\  lw $4, 4($sp)
        \\  jalr $25
        \\  nop
        \\  move $4, $2
        \\  li $2, 4001 # SYS_exit
        \\  syscall
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

// The `stat64` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    __pad0: [2]u32, // -1 because our dev_t is u64 (kernel dev_t is really u32).
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    __pad1: [2]u32,
    size: off_t,
    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    blksize: blksize_t,
    __pad3: u32,
    blocks: blkcnt_t,

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
