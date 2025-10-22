const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall0(number: SYS) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
        : .{ .memory = true });
}

pub fn syscall1(number: SYS, arg1: u32) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
        : .{ .memory = true });
}

pub fn syscall2(number: SYS, arg1: u32, arg2: u32) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
        : .{ .memory = true });
}

pub fn syscall3(number: SYS, arg1: u32, arg2: u32, arg3: u32) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
        : .{ .memory = true });
}

pub fn syscall4(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
        : .{ .memory = true });
}

pub fn syscall5(number: SYS, arg1: u32, arg2: u32, arg3: u32, arg4: u32, arg5: u32) u32 {
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
          [arg5] "{d5}" (arg5),
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
    return asm volatile ("trap #0"
        : [ret] "={d0}" (-> u32),
        : [number] "{d0}" (@intFromEnum(number)),
          [arg1] "{d1}" (arg1),
          [arg2] "{d2}" (arg2),
          [arg3] "{d3}" (arg3),
          [arg4] "{d4}" (arg4),
          [arg5] "{d5}" (arg5),
          [arg6] "{a0}" (arg6),
        : .{ .memory = true });
}

pub fn clone() callconv(.naked) u32 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         +4,   +8,    +12,   +16, +20,  +24, +28
    //
    // syscall(SYS_clone, flags, stack, ptid, ctid, tls)
    //         d0,        d1,    d2,    d3,   d4,   d5
    asm volatile (
        \\ // Save callee-saved registers.
        \\ movem.l %%d2-%%d5, -(%%sp) // sp -= 16
        \\
        \\ // Save func and arg.
        \\ move.l 16+4(%%sp), %%a0
        \\ move.l 16+16(%%sp), %%a1
        \\
        \\ // d0 = syscall(d0, d1, d2, d3, d4, d5)
        \\ move.l #120, %%d0 // SYS_clone
        \\ move.l 16+12(%%sp), %%d1
        \\ move.l 16+8(%%sp), %%d2
        \\ move.l 16+20(%%sp), %%d3
        \\ move.l 16+28(%%sp), %%d4
        \\ move.l 16+24(%%sp), %%d5
        \\ and.l #-4, %%d2 // Align the child stack pointer.
        \\ trap #0
        \\
        \\ // Are we in the parent or child?
        \\ tst.l %%d0
        \\ beq 1f
        \\ // Parent:
        \\
        \\ // Restore callee-saved registers and return.
        \\ movem.l (%%sp)+, %%d2-%%d5 // sp += 16
        \\ rts
        \\
        \\ // Child:
        \\1:
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined %%pc
    );
    asm volatile (
        \\ suba.l %%fp, %%fp
        \\
        \\ // d0 = func(a1)
        \\ move.l %%a1, -(%%sp)
        \\ jsr (%%a0)
        \\
        \\ // syscall(d0, d1)
        \\ move.l %%d0, %%d1
        \\ move.l #1, %%d0 // SYS_exit
        \\ trap #0
    );
}

pub const restore = restore_rt;

pub fn restore_rt() callconv(.naked) noreturn {
    asm volatile ("trap #0"
        :
        : [number] "{d0}" (@intFromEnum(SYS.rt_sigreturn)),
    );
}

pub const blksize_t = i32;
pub const nlink_t = u32;
pub const time_t = i32;
pub const mode_t = u32;
pub const off_t = i64;
pub const ino_t = u64;
pub const dev_t = u64;
pub const blkcnt_t = i64;

pub const Stat = extern struct {
    dev: dev_t,
    __pad: i16,
    __ino_truncated: i32,
    mode: mode_t,
    nlink: nlink_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    rdev: dev_t,
    __pad2: i16,
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

// No VDSO used as of glibc 112a0ae18b831bf31f44d81b82666980312511d6.
pub const VDSO = void;
