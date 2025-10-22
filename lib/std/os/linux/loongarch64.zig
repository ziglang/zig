const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u64) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u64, arg2: u64) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
          [arg2] "{$r5}" (arg2),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
          [arg2] "{$r5}" (arg2),
          [arg3] "{$r6}" (arg3),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
          [arg2] "{$r5}" (arg2),
          [arg3] "{$r6}" (arg3),
          [arg4] "{$r7}" (arg4),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) u64 {
    return asm volatile (
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
          [arg2] "{$r5}" (arg2),
          [arg3] "{$r6}" (arg3),
          [arg4] "{$r7}" (arg4),
          [arg5] "{$r8}" (arg5),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
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
        \\ syscall 0
        : [ret] "={$r4}" (-> u64),
        : [number] "{$r11}" (@intFromEnum(number)),
          [arg1] "{$r4}" (arg1),
          [arg2] "{$r5}" (arg2),
          [arg3] "{$r6}" (arg3),
          [arg4] "{$r7}" (arg4),
          [arg5] "{$r8}" (arg5),
          [arg6] "{$r9}" (arg6),
        : .{ .r12 = true, .r13 = true, .r14 = true, .r15 = true, .r16 = true, .r17 = true, .r18 = true, .r19 = true, .r20 = true, .memory = true });
}

pub fn clone() callconv(.naked) u64 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //           a0,    a1,    a2,  a3,   a4,  a5,   a6
    // sys_clone(flags, stack, ptid, ctid, tls)
    //              a0,    a1,   a2,   a3,  a4
    asm volatile (
        \\ bstrins.d $a1, $zero, 3, 0   # stack to 16 align
        \\
        \\ # Save function pointer and argument pointer on new thread stack
        \\ addi.d  $a1, $a1, -16
        \\ st.d    $a0, $a1, 0     # save function pointer
        \\ st.d    $a3, $a1, 8     # save argument pointer
        \\ or      $a0, $a2, $zero
        \\ or      $a2, $a4, $zero
        \\ or      $a3, $a6, $zero
        \\ or      $a4, $a5, $zero
        \\ ori     $a7, $zero, 220 # SYS_clone
        \\ syscall 0               # call clone
        \\
        \\ beqz    $a0, 1f         # whether child process
        \\ jirl    $zero, $ra, 0   # parent process return
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined 1
    );
    asm volatile (
        \\ move    $fp, $zero
        \\ move    $ra, $zero
        \\
        \\ ld.d    $t8, $sp, 0     # function pointer
        \\ ld.d    $a0, $sp, 8     # argument pointer
        \\ jirl    $ra, $t8, 0     # call the user's function
        \\ ori     $a7, $zero, 93  # SYS_exit
        \\ syscall 0               # child process exit
    );
}

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i64;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u32;
pub const blkcnt_t = i64;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    _pad1: u64,
    size: off_t,
    blksize: blksize_t,
    _pad2: i32,
    blocks: blkcnt_t,
    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    _pad3: [2]u32,

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

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_5.10";
};
