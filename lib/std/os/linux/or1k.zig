const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
        : .{ .r3 = true, .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
        : .{ .r4 = true, .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
        : .{ .r5 = true, .r6 = true, .r7 = true, .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
        : .{ .r6 = true, .r7 = true, .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
        : .{ .r7 = true, .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile (
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
        : .{ .r8 = true, .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
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
        \\ l.sys 1
        : [ret] "={r11}" (-> u32),
        : [number] "{r11}" (@intFromEnum(number)),
          [arg1] "{r3}" (arg1),
          [arg2] "{r4}" (arg2),
          [arg3] "{r5}" (arg3),
          [arg4] "{r6}" (arg4),
          [arg5] "{r7}" (arg5),
          [arg6] "{r8}" (arg6),
        : .{ .r12 = true, .r13 = true, .r15 = true, .r17 = true, .r19 = true, .r21 = true, .r23 = true, .r25 = true, .r27 = true, .r29 = true, .r31 = true, .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         r3,   r4,    r5,    r6,  r7,   r8,  +0
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         r11        r3,    r4,    r5,   r6,  r7
    asm volatile (
        \\ # Save function pointer and argument pointer on new thread stack
        \\ l.andi r4, r4, -4
        \\ l.addi r4, r4, -8
        \\ l.sw 0(r4), r3
        \\ l.sw 4(r4), r6
        \\
        \\ # Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
        \\ l.ori r11, r0, 220 # SYS_clone
        \\ l.ori r3, r5, 0
        \\ l.ori r5, r7, 0
        \\ l.ori r6, r8, 0
        \\ l.lwz r7, 0(r1)
        \\ l.sys 1
        \\ l.sfeqi r11, 0
        \\ l.bf 1f
        \\ l.jr r9
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined r9
    );
    asm volatile (
        \\ l.ori r2, r0, 0
        \\ l.ori r9, r0, 0
        \\
        \\ l.lwz r11, 0(r1)
        \\ l.lwz r3, 4(r1)
        \\ l.jalr r11
        \\
        \\ l.ori r3, r11, 0
        \\ l.ori r11, r0, 93 # SYS_exit
        \\ l.sys 1
    );
}

pub const VDSO = void;

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
    ino: ino_t,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    _pad0: [2]u32,
    size: off_t,
    blksize: blksize_t,
    _pad1: u32,
    blocks: blkcnt_t,
    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    _pad2: [2]u32,

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
