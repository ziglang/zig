const builtin = @import("builtin");
const std = @import("../../std.zig");
const SYS = std.os.linux.SYS;

pub fn syscall_pipe(fd: *[2]i32) u64 {
    return asm volatile (
        \\ mov %[arg], %%g3
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ # Return the error code
        \\ ba 2f
        \\ neg %%o0
        \\1:
        \\ st %%o0, [%%g3+0]
        \\ st %%o1, [%%g3+4]
        \\ clr %%o0
        \\2:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(SYS.pipe)),
          [arg] "r" (fd),
        : .{ .memory = true, .g3 = true });
}

pub fn syscall_fork() u64 {
    // Linux/sparc64 fork() returns two values in %o0 and %o1:
    // - On the parent's side, %o0 is the child's PID and %o1 is 0.
    // - On the child's side, %o0 is the parent's PID and %o1 is 1.
    // We need to clear the child's %o0 so that the return values
    // conform to the libc convention.
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ ba 2f
        \\ neg %%o0
        \\ 1:
        \\ # Clear the child's %%o0
        \\ dec %%o1
        \\ and %%o1, %%o0, %%o0
        \\ 2:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(SYS.fork)),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall0(number: SYS) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall1(number: SYS, arg1: u64) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall2(number: SYS, arg1: u64, arg2: u64) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall3(number: SYS, arg1: u64, arg2: u64, arg3: u64) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall4(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn syscall5(number: SYS, arg1: u64, arg2: u64, arg3: u64, arg4: u64, arg5: u64) u64 {
    return asm volatile (
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
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
        \\ t 0x6d
        \\ bcc,pt %%xcc, 1f
        \\ nop
        \\ neg %%o0
        \\ 1:
        : [ret] "={o0}" (-> u64),
        : [number] "{g1}" (@intFromEnum(number)),
          [arg1] "{o0}" (arg1),
          [arg2] "{o1}" (arg2),
          [arg3] "{o2}" (arg3),
          [arg4] "{o3}" (arg4),
          [arg5] "{o4}" (arg5),
          [arg6] "{o5}" (arg6),
        : .{ .memory = true, .xcc = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub fn clone() callconv(.naked) u64 {
    // __clone(func, stack, flags, arg, ptid, tls, ctid)
    //         i0,   i1,    i2,    i3,  i4,   i5,  sp
    //
    // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
    //         g1         o0,    o1,    o2,   o3,  o4
    asm volatile (
        \\ save %%sp, -192, %%sp
        \\ # Save the func pointer and the arg pointer
        \\ mov %%i0, %%g2
        \\ mov %%i3, %%g3
        \\ # Shuffle the arguments
        \\ mov 217, %%g1 // SYS_clone
        \\ mov %%i2, %%o0
        \\ # Add some extra space for the initial frame
        \\ sub %%i1, 176 + 2047, %%o1
        \\ mov %%i4, %%o2
        \\ mov %%i5, %%o3
        \\ ldx [%%fp + 0x8af], %%o4
        \\ t 0x6d
        \\ bcs,pn %%xcc, 1f
        \\ nop
        \\ # The child pid is returned in o0 while o1 tells if this
        \\ # process is # the child (=1) or the parent (=0).
        \\ brnz %%o1, 2f
        \\ nop
        \\ # Parent process, return the child pid
        \\ mov %%o0, %%i0
        \\ ret
        \\ restore
        \\1:
        \\ # The syscall failed
        \\ sub %%g0, %%o0, %%i0
        \\ ret
        \\ restore
        \\2:
        \\ # Child process
    );
    if (builtin.unwind_tables != .none or !builtin.strip_debug_info) asm volatile (
        \\ .cfi_undefined %%i7
    );
    asm volatile (
        \\ mov %%g0, %%fp
        \\ mov %%g0, %%i7
        \\
        \\ # call func(arg)
        \\ mov %%g0, %%fp
        \\ call %%g2
        \\ mov %%g3, %%o0
        \\ # Exit
        \\ mov 1, %%g1 // SYS_exit
        \\ t 0x6d
    );
}

pub const restore = restore_rt;

// Need to use C ABI here instead of naked
// to prevent an infinite loop when calling rt_sigreturn.
pub fn restore_rt() callconv(.c) void {
    return asm volatile ("t 0x6d"
        :
        : [number] "{g1}" (@intFromEnum(SYS.rt_sigreturn)),
        : .{ .memory = true, .xcc = true, .o0 = true, .o1 = true, .o2 = true, .o3 = true, .o4 = true, .o5 = true, .o7 = true });
}

pub const VDSO = struct {
    pub const CGT_SYM = "__vdso_clock_gettime";
    pub const CGT_VER = "LINUX_2.6";
};

pub const off_t = i64;
pub const ino_t = u64;
pub const time_t = i64;
pub const mode_t = u32;
pub const dev_t = u64;
pub const nlink_t = u32;
pub const blksize_t = i64;
pub const blkcnt_t = i64;

// The `stat64` definition used by the kernel.
pub const Stat = extern struct {
    dev: dev_t,
    ino: ino_t,
    nlink: nlink_t,
    _pad: i32,

    mode: mode_t,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    __pad0: u32,

    rdev: dev_t,
    size: i64,
    blksize: blksize_t,
    blocks: blkcnt_t,

    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    __unused: [3]u64,

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
