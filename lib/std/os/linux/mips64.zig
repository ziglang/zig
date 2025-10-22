const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
        : .{ .r1 = true, .r3 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall_pipe(fd: *[2]i32) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 2f
        \\ dsubu $v0, $zero, $v0
        \\ b 2f
        \\1:
        \\ sw $v0, 0($a0)
        \\ sw $v1, 4($a0)
        \\2:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(SYS.pipe)),
          [fd] "{$4}" (fd),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u64) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
        : .{ .r1 = true, .r3 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u64, arg2: u64) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
        : .{ .r1 = true, .r3 = true, .r6 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
        : .{ .r1 = true, .r3 = true, .r7 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) u64 {
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "{$8}" (arg5),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
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
    return asm volatile (
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 1f
        \\ dsubu $v0, $zero, $v0
        \\1:
        : [ret] "={$2}" (-> u64),
        : [number] "{$2}" (@intFromEnum(number)),
          [arg1] "{$4}" (arg1),
          [arg2] "{$5}" (arg2),
          [arg3] "{$6}" (arg3),
          [arg4] "{$7}" (arg4),
          [arg5] "{$8}" (arg5),
          [arg6] "{$9}" (arg6),
        : .{ .r1 = true, .r3 = true, .r8 = true, .r9 = true, .r10 = true, .r11 = true, .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r24 = true, .r25 = true, .hi = true, .lo = true, .memory = true });
}

pub fn clone() callconv(.naked) u64 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         a0,   a1,    a2,    a3,  a4,   a5,  a6
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         v0         a0,    a1,    a2,   a3,  a4
    asm volatile (
        \\ # Save function pointer and argument pointer on new thread stack
        \\ and $a1, $a1, -16
        \\ dsubu $a1, $a1, 16
        \\ sd $a0, 0($a1)
        \\ sd $a3, 8($a1)
        \\
        \\ # Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
        \\ move $a0, $a2
        \\ move $a2, $a4
        \\ move $a3, $a5
        \\ move $a4, $a6
        \\ li $v0, 5055 # SYS_clone
        \\ syscall
        \\ beq $a3, $zero, 1f
        \\ blez $v0, 2f
        \\ dsubu $v0, $zero, $v0
        \\ b 2f
        \\1:
        \\ beq $v0, $zero, 3f
        \\2:
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
        \\ ld $t9, 0($sp)
        \\ ld $a0, 8($sp)
        \\ jalr $t9
        \\
        \\ move $a0, $v0
        \\ li $v0, 5058 # SYS_exit
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

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    __pad0: [2]u32, // -1 because our dev_t is u64 (kernel dev_t is really u32).
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    __pad1: [2]u32, // -1 because our dev_t is u64 (kernel dev_t is really u32).
    size: off_t,
    atim: u32,
    atim_nsec: u32,
    mtim: u32,
    mtim_nsec: u32,
    ctim: u32,
    ctim_nsec: u32,
    blksize: blksize_t,
    __pad3: u32,
    blocks: blkcnt_t,

    pub fn atime(self: @This()) std.os.linux.timespec {
        return .{
            .sec = self.atim,
            .nsec = self.atim_nsec,
        };
    }

    pub fn mtime(self: @This()) std.os.linux.timespec {
        return .{
            .sec = self.mtim,
            .nsec = self.mtim_nsec,
        };
    }

    pub fn ctime(self: @This()) std.os.linux.timespec {
        return .{
            .sec = self.ctim,
            .nsec = self.ctim_nsec,
        };
    }
};
