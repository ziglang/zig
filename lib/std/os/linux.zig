// This file provides the system interface functions for Linux matching those
// that are provided by libc, whether or not libc is linked. The following
// abstractions are made:
// * Work around kernel bugs and limitations. For example, see sendmmsg.
// * Implement all the syscalls in the same way that libc functions will
//   provide `rename` when only the `renameat` syscall exists.
// * Does not support POSIX thread cancellation.
const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const elf = std.elf;
const vdso = @import("linux/vdso.zig");
const dl = @import("../dynamic_library.zig");

pub usingnamespace switch (builtin.arch) {
    .x86_64 => @import("linux/x86_64.zig"),
    .aarch64 => @import("linux/arm64.zig"),
    .arm => @import("linux/arm-eabi.zig"),
    .riscv64 => @import("linux/riscv64.zig"),
    .mipsel => @import("linux/mipsel.zig"),
    else => struct {},
};
pub usingnamespace @import("bits.zig");
pub const tls = @import("linux/tls.zig");

/// Set by startup code, used by `getauxval`.
pub var elf_aux_maybe: ?[*]std.elf.Auxv = null;

/// See `std.elf` for the constants.
pub fn getauxval(index: usize) usize {
    const auxv = elf_aux_maybe orelse return 0;
    var i: usize = 0;
    while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
        if (auxv[i].a_type == index)
            return auxv[i].a_un.a_val;
    }
    return 0;
}

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) u12 {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(u12, -signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    if (@hasDecl(@This(), "SYS_dup2")) {
        return syscall2(SYS_dup2, @bitCast(usize, isize(old)), @bitCast(usize, isize(new)));
    } else {
        if (old == new) {
            if (std.debug.runtime_safety) {
                const rc = syscall2(SYS_fcntl, @bitCast(usize, isize(old)), F_GETFD);
                if (@bitCast(isize, rc) < 0) return rc;
            }
            return @intCast(usize, old);
        } else {
            return syscall3(SYS_dup3, @bitCast(usize, isize(old)), @bitCast(usize, isize(new)), 0);
        }
    }
}

pub fn dup3(old: i32, new: i32, flags: u32) usize {
    return syscall3(SYS_dup3, @bitCast(usize, isize(old)), @bitCast(usize, isize(new)), flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn chdir(path: [*]const u8) usize {
    return syscall1(SYS_chdir, @ptrToInt(path));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn chroot(path: [*]const u8) usize {
    return syscall1(SYS_chroot, @ptrToInt(path));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return syscall3(SYS_execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn fork() usize {
    if (@hasDecl(@This(), "SYS_fork")) {
        return syscall0(SYS_fork);
    } else {
        return syscall2(SYS_clone, SIGCHLD, 0);
    }
}

/// This must be inline, and inline call the syscall function, because if the
/// child does a return it will clobber the parent's stack.
/// It is advised to avoid this function and use clone instead, because
/// the compiler is not aware of how vfork affects control flow and you may
/// see different results in optimized builds.
pub inline fn vfork() usize {
    return @inlineCall(syscall0, SYS_vfork);
}

pub fn futimens(fd: i32, times: *const [2]timespec) usize {
    return utimensat(fd, null, times, 0);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn utimensat(dirfd: i32, path: ?[*]const u8, times: *const [2]timespec, flags: u32) usize {
    return syscall4(SYS_utimensat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(times), flags);
}

pub fn futex_wait(uaddr: *const i32, futex_op: u32, val: i32, timeout: ?*timespec) usize {
    return syscall4(SYS_futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val), @ptrToInt(timeout));
}

pub fn futex_wake(uaddr: *const i32, futex_op: u32, val: i32) usize {
    return syscall3(SYS_futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return syscall2(SYS_getcwd, @ptrToInt(buf), size);
}

pub fn getdents(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        SYS_getdents,
        @bitCast(usize, isize(fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn getdents64(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        SYS_getdents64,
        @bitCast(usize, isize(fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(SYS_inotify_init1, flags);
}

pub fn inotify_add_watch(fd: i32, pathname: [*]const u8, mask: u32) usize {
    return syscall3(SYS_inotify_add_watch, @bitCast(usize, isize(fd)), @ptrToInt(pathname), mask);
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(SYS_inotify_rm_watch, @bitCast(usize, isize(fd)), @bitCast(usize, isize(wd)));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn readlink(noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    if (@hasDecl(@This(), "SYS_readlink")) {
        return syscall3(SYS_readlink, @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    } else {
        return syscall4(SYS_readlinkat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn readlinkat(dirfd: i32, noalias path: [*]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(SYS_readlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mkdir(path: [*]const u8, mode: u32) usize {
    if (@hasDecl(@This(), "SYS_mkdir")) {
        return syscall2(SYS_mkdir, @ptrToInt(path), mode);
    } else {
        return syscall3(SYS_mkdirat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(path), mode);
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mkdirat(dirfd: i32, path: [*]const u8, mode: u32) usize {
    return syscall3(SYS_mkdirat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), mode);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn mount(special: [*]const u8, dir: [*]const u8, fstype: [*]const u8, flags: u32, data: usize) usize {
    return syscall5(SYS_mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn umount(special: [*]const u8) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), 0);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn umount2(special: [*]const u8, flags: u32) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), flags);
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: u64) usize {
    if (@hasDecl(@This(), "SYS_mmap2")) {
        // Make sure the offset is also specified in multiples of page size
        if ((offset & (MMAP2_UNIT - 1)) != 0)
            return @bitCast(usize, isize(-EINVAL));

        return syscall6(
            SYS_mmap2,
            @ptrToInt(address),
            length,
            prot,
            flags,
            @bitCast(usize, isize(fd)),
            @truncate(usize, offset / MMAP2_UNIT),
        );
    } else {
        return syscall6(
            SYS_mmap,
            @ptrToInt(address),
            length,
            prot,
            flags,
            @bitCast(usize, isize(fd)),
            offset,
        );
    }
}

pub fn mprotect(address: [*]const u8, length: usize, protection: usize) usize {
    return syscall3(SYS_mprotect, @ptrToInt(address), length, protection);
}

pub fn munmap(address: [*]const u8, length: usize) usize {
    return syscall2(SYS_munmap, @ptrToInt(address), length);
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return syscall3(SYS_read, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: u64) usize {
    return syscall5(
        SYS_preadv,
        @bitCast(usize, isize(fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn preadv2(fd: i32, iov: [*]const iovec, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        SYS_preadv2,
        @bitCast(usize, isize(fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(SYS_readv, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(SYS_writev, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64) usize {
    return syscall5(
        SYS_pwritev,
        @bitCast(usize, isize(fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn pwritev2(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        SYS_pwritev2,
        @bitCast(usize, isize(fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn rmdir(path: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_rmdir")) {
        return syscall1(SYS_rmdir, @ptrToInt(path));
    } else {
        return syscall3(SYS_unlinkat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(path), AT_REMOVEDIR);
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn symlink(existing: [*]const u8, new: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_symlink")) {
        return syscall2(SYS_symlink, @ptrToInt(existing), @ptrToInt(new));
    } else {
        return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(new));
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn symlinkat(existing: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, isize(newfd)), @ptrToInt(newpath));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: usize) usize {
    return syscall4(SYS_pread, @bitCast(usize, isize(fd)), @ptrToInt(buf), count, offset);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn access(path: [*]const u8, mode: u32) usize {
    if (@hasDecl(@This(), "SYS_access")) {
        return syscall2(SYS_access, @ptrToInt(path), mode);
    } else {
        return syscall4(SYS_faccessat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(path), mode, 0);
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn faccessat(dirfd: i32, path: [*]const u8, mode: u32, flags: u32) usize {
    return syscall4(SYS_faccessat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), mode, flags);
}

pub fn pipe(fd: *[2]i32) usize {
    if (builtin.arch == .mipsel) {
        return syscall_pipe(fd);
    } else if (@hasDecl(@This(), "SYS_pipe")) {
        return syscall1(SYS_pipe, @ptrToInt(fd));
    } else {
        return syscall2(SYS_pipe2, @ptrToInt(fd), 0);
    }
}

pub fn pipe2(fd: *[2]i32, flags: u32) usize {
    return syscall2(SYS_pipe2, @ptrToInt(fd), flags);
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall3(SYS_write, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: usize) usize {
    return syscall4(SYS_pwrite, @bitCast(usize, isize(fd)), @ptrToInt(buf), count, offset);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn rename(old: [*]const u8, new: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_rename")) {
        return syscall2(SYS_rename, @ptrToInt(old), @ptrToInt(new));
    } else if (@hasDecl(@This(), "SYS_renameat")) {
        return syscall4(SYS_renameat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(old), @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(new));
    } else {
        return syscall5(SYS_renameat2, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(old), @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(new), 0);
    }
}

pub fn renameat(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_renameat")) {
        return syscall4(
            SYS_renameat,
            @bitCast(usize, isize(oldfd)),
            @ptrToInt(old),
            @bitCast(usize, isize(newfd)),
            @ptrToInt(new),
        );
    } else {
        return syscall5(
            SYS_renameat2,
            @bitCast(usize, isize(oldfd)),
            @ptrToInt(old),
            @bitCast(usize, isize(newfd)),
            @ptrToInt(new),
            0,
        );
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn renameat2(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8, flags: u32) usize {
    return syscall5(
        SYS_renameat2,
        @bitCast(usize, isize(oldfd)),
        @ptrToInt(oldpath),
        @bitCast(usize, isize(newfd)),
        @ptrToInt(newpath),
        flags,
    );
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn open(path: [*]const u8, flags: u32, perm: usize) usize {
    if (@hasDecl(@This(), "SYS_open")) {
        return syscall3(SYS_open, @ptrToInt(path), flags, perm);
    } else {
        return syscall4(
            SYS_openat,
            @bitCast(usize, isize(AT_FDCWD)),
            @ptrToInt(path),
            flags,
            perm,
        );
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn create(path: [*]const u8, perm: usize) usize {
    return syscall2(SYS_creat, @ptrToInt(path), perm);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn openat(dirfd: i32, path: [*]const u8, flags: u32, mode: usize) usize {
    // dirfd could be negative, for example AT_FDCWD is -100
    return syscall4(SYS_openat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), flags, mode);
}

/// See also `clone` (from the arch-specific include)
pub fn clone5(flags: usize, child_stack_ptr: usize, parent_tid: *i32, child_tid: *i32, newtls: usize) usize {
    return syscall5(SYS_clone, flags, child_stack_ptr, @ptrToInt(parent_tid), @ptrToInt(child_tid), newtls);
}

/// See also `clone` (from the arch-specific include)
pub fn clone2(flags: u32, child_stack_ptr: usize) usize {
    return syscall2(SYS_clone, flags, child_stack_ptr);
}

pub fn close(fd: i32) usize {
    return syscall1(SYS_close, @bitCast(usize, isize(fd)));
}

/// Can only be called on 32 bit systems. For 64 bit see `lseek`.
pub fn llseek(fd: i32, offset: u64, result: ?*u64, whence: usize) usize {
    return syscall5(
        SYS__llseek,
        @bitCast(usize, isize(fd)),
        @truncate(usize, offset >> 32),
        @truncate(usize, offset),
        @ptrToInt(result),
        whence,
    );
}

/// Can only be called on 64 bit systems. For 32 bit see `llseek`.
pub fn lseek(fd: i32, offset: i64, whence: usize) usize {
    return syscall3(SYS_lseek, @bitCast(usize, isize(fd)), @bitCast(usize, offset), whence);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(SYS_exit_group, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(SYS_getrandom, @ptrToInt(buf), count, flags);
}

pub fn kill(pid: i32, sig: i32) usize {
    return syscall2(SYS_kill, @bitCast(usize, isize(pid)), @bitCast(usize, isize(sig)));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn unlink(path: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_unlink")) {
        return syscall1(SYS_unlink, @ptrToInt(path));
    } else {
        return syscall3(SYS_unlinkat, @bitCast(usize, isize(AT_FDCWD)), @ptrToInt(path), 0);
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn unlinkat(dirfd: i32, path: [*]const u8, flags: u32) usize {
    return syscall3(SYS_unlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), flags);
}

pub fn waitpid(pid: i32, status: *u32, flags: u32) usize {
    return syscall4(SYS_wait4, @bitCast(usize, isize(pid)), @ptrToInt(status), flags, 0);
}

var vdso_clock_gettime = @ptrCast(?*const c_void, init_vdso_clock_gettime);

// We must follow the C calling convention when we call into the VDSO
const vdso_clock_gettime_ty = extern fn (i32, *timespec) usize;

pub fn clock_gettime(clk_id: i32, tp: *timespec) usize {
    if (@hasDecl(@This(), "VDSO_CGT_SYM")) {
        const ptr = @atomicLoad(?*const c_void, &vdso_clock_gettime, .Unordered);
        if (ptr) |fn_ptr| {
            const f = @ptrCast(vdso_clock_gettime_ty, fn_ptr);
            const rc = f(clk_id, tp);
            switch (rc) {
                0, @bitCast(usize, isize(-EINVAL)) => return rc,
                else => {},
            }
        }
    }
    return syscall2(SYS_clock_gettime, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}

extern fn init_vdso_clock_gettime(clk: i32, ts: *timespec) usize {
    const ptr = @intToPtr(?*const c_void, vdso.lookup(VDSO_CGT_VER, VDSO_CGT_SYM));
    // Note that we may not have a VDSO at all, update the stub address anyway
    // so that clock_gettime will fall back on the good old (and slow) syscall
    _ = @cmpxchgStrong(?*const c_void, &vdso_clock_gettime, &init_vdso_clock_gettime, ptr, .Monotonic, .Monotonic);
    // Call into the VDSO if available
    if (ptr) |fn_ptr| {
        const f = @ptrCast(vdso_clock_gettime_ty, fn_ptr);
        return f(clk, ts);
    }
    return @bitCast(usize, isize(-ENOSYS));
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return syscall2(SYS_clock_getres, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(SYS_clock_settime, @bitCast(usize, isize(clk_id)), @ptrToInt(tp));
}

pub fn gettimeofday(tv: *timeval, tz: *timezone) usize {
    return syscall2(SYS_gettimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn settimeofday(tv: *const timeval, tz: *const timezone) usize {
    return syscall2(SYS_settimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return syscall2(SYS_nanosleep, @ptrToInt(req), @ptrToInt(rem));
}

pub fn setuid(uid: u32) usize {
    if (@hasDecl(@This(), "SYS_setuid32")) {
        return syscall1(SYS_setuid32, uid);
    } else {
        return syscall1(SYS_setuid, uid);
    }
}

pub fn setgid(gid: u32) usize {
    if (@hasDecl(@This(), "SYS_setgid32")) {
        return syscall1(SYS_setgid32, gid);
    } else {
        return syscall1(SYS_setgid, gid);
    }
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    if (@hasDecl(@This(), "SYS_setreuid32")) {
        return syscall2(SYS_setreuid32, ruid, euid);
    } else {
        return syscall2(SYS_setreuid, ruid, euid);
    }
}

pub fn setregid(rgid: u32, egid: u32) usize {
    if (@hasDecl(@This(), "SYS_setregid32")) {
        return syscall2(SYS_setregid32, rgid, egid);
    } else {
        return syscall2(SYS_setregid, rgid, egid);
    }
}

pub fn getuid() u32 {
    if (@hasDecl(@This(), "SYS_getuid32")) {
        return u32(syscall0(SYS_getuid32));
    } else {
        return u32(syscall0(SYS_getuid));
    }
}

pub fn getgid() u32 {
    if (@hasDecl(@This(), "SYS_getgid32")) {
        return u32(syscall0(SYS_getgid32));
    } else {
        return u32(syscall0(SYS_getgid));
    }
}

pub fn geteuid() u32 {
    if (@hasDecl(@This(), "SYS_geteuid32")) {
        return u32(syscall0(SYS_geteuid32));
    } else {
        return u32(syscall0(SYS_geteuid));
    }
}

pub fn getegid() u32 {
    if (@hasDecl(@This(), "SYS_getegid32")) {
        return u32(syscall0(SYS_getegid32));
    } else {
        return u32(syscall0(SYS_getegid));
    }
}

pub fn seteuid(euid: u32) usize {
    return setreuid(std.math.maxInt(u32), euid);
}

pub fn setegid(egid: u32) usize {
    return setregid(std.math.maxInt(u32), egid);
}

pub fn getresuid(ruid: *u32, euid: *u32, suid: *u32) usize {
    if (@hasDecl(@This(), "SYS_getresuid32")) {
        return syscall3(SYS_getresuid32, @ptrToInt(ruid), @ptrToInt(euid), @ptrToInt(suid));
    } else {
        return syscall3(SYS_getresuid, @ptrToInt(ruid), @ptrToInt(euid), @ptrToInt(suid));
    }
}

pub fn getresgid(rgid: *u32, egid: *u32, sgid: *u32) usize {
    if (@hasDecl(@This(), "SYS_getresgid32")) {
        return syscall3(SYS_getresgid32, @ptrToInt(rgid), @ptrToInt(egid), @ptrToInt(sgid));
    } else {
        return syscall3(SYS_getresgid, @ptrToInt(rgid), @ptrToInt(egid), @ptrToInt(sgid));
    }
}

pub fn setresuid(ruid: u32, euid: u32, suid: u32) usize {
    if (@hasDecl(@This(), "SYS_setresuid32")) {
        return syscall3(SYS_setresuid32, ruid, euid, suid);
    } else {
        return syscall3(SYS_setresuid, ruid, euid, suid);
    }
}

pub fn setresgid(rgid: u32, egid: u32, sgid: u32) usize {
    if (@hasDecl(@This(), "SYS_setresgid32")) {
        return syscall3(SYS_setresgid32, rgid, egid, sgid);
    } else {
        return syscall3(SYS_setresgid, rgid, egid, sgid);
    }
}

pub fn getgroups(size: usize, list: *u32) usize {
    if (@hasDecl(@This(), "SYS_getgroups32")) {
        return syscall2(SYS_getgroups32, size, @ptrToInt(list));
    } else {
        return syscall2(SYS_getgroups, size, @ptrToInt(list));
    }
}

pub fn setgroups(size: usize, list: *const u32) usize {
    if (@hasDecl(@This(), "SYS_setgroups32")) {
        return syscall2(SYS_setgroups32, size, @ptrToInt(list));
    } else {
        return syscall2(SYS_setgroups, size, @ptrToInt(list));
    }
}

pub fn getpid() i32 {
    return @bitCast(i32, @truncate(u32, syscall0(SYS_getpid)));
}

pub fn gettid() i32 {
    return @bitCast(i32, @truncate(u32, syscall0(SYS_gettid)));
}

pub fn sigprocmask(flags: u32, noalias set: *const sigset_t, noalias oldset: ?*sigset_t) usize {
    return syscall4(SYS_rt_sigprocmask, flags, @ptrToInt(set), @ptrToInt(oldset), NSIG / 8);
}

pub fn sigaction(sig: u6, noalias act: *const Sigaction, noalias oact: ?*Sigaction) usize {
    assert(sig >= 1);
    assert(sig != SIGKILL);
    assert(sig != SIGSTOP);

    const restorer_fn = if ((act.flags & SA_SIGINFO) != 0) restore_rt else restore;
    var ksa = k_sigaction{
        .sigaction = act.sigaction,
        .flags = act.flags | SA_RESTORER,
        .mask = undefined,
        .restorer = @ptrCast(extern fn () void, restorer_fn),
    };
    var ksa_old: k_sigaction = undefined;
    const ksa_mask_size = @sizeOf(@typeOf(ksa_old.mask));
    @memcpy(@ptrCast([*]u8, &ksa.mask), @ptrCast([*]const u8, &act.mask), ksa_mask_size);
    const result = syscall4(SYS_rt_sigaction, sig, @ptrToInt(&ksa), @ptrToInt(&ksa_old), ksa_mask_size);
    const err = getErrno(result);
    if (err != 0) {
        return result;
    }
    if (oact) |old| {
        old.sigaction = ksa_old.sigaction;
        old.flags = @truncate(u32, ksa_old.flags);
        @memcpy(@ptrCast([*]u8, &old.mask), @ptrCast([*]const u8, &ksa_old.mask), ksa_mask_size);
    }
    return 0;
}

pub fn blockAllSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&all_mask), @ptrToInt(set), NSIG / 8);
}

pub fn blockAppSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_BLOCK, @ptrToInt(&app_mask), @ptrToInt(set), NSIG / 8);
}

pub fn restoreSignals(set: *sigset_t) void {
    _ = syscall4(SYS_rt_sigprocmask, SIG_SETMASK, @ptrToInt(set), 0, NSIG / 8);
}

pub fn sigaddset(set: *sigset_t, sig: u6) void {
    const s = sig - 1;
    (set.*)[@intCast(usize, s) / usize.bit_count] |= @intCast(usize, 1) << (s & (usize.bit_count - 1));
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((set.*)[@intCast(usize, s) / usize.bit_count] & (@intCast(usize, 1) << (s & (usize.bit_count - 1)))) != 0;
}

pub fn getsockname(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return syscall3(SYS_getsockname, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn getpeername(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return syscall3(SYS_getpeername, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) usize {
    return syscall3(SYS_socket, domain, socket_type, protocol);
}

pub fn setsockopt(fd: i32, level: u32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    return syscall5(SYS_setsockopt, @bitCast(usize, isize(fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen));
}

pub fn getsockopt(fd: i32, level: u32, optname: u32, noalias optval: [*]u8, noalias optlen: *socklen_t) usize {
    return syscall5(SYS_getsockopt, @bitCast(usize, isize(fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen));
}

pub fn sendmsg(fd: i32, msg: *msghdr_const, flags: u32) usize {
    return syscall3(SYS_sendmsg, @bitCast(usize, isize(fd)), @ptrToInt(msg), flags);
}

pub fn sendmmsg(fd: i32, msgvec: [*]mmsghdr_const, vlen: u32, flags: u32) usize {
    if (@typeInfo(usize).Int.bits > @typeInfo(@typeOf(mmsghdr(undefined).msg_len)).Int.bits) {
        // workaround kernel brokenness:
        // if adding up all iov_len overflows a i32 then split into multiple calls
        // see https://www.openwall.com/lists/musl/2014/06/07/5
        const kvlen = if (vlen > IOV_MAX) IOV_MAX else vlen; // matches kernel
        var next_unsent: usize = 0;
        for (msgvec[0..kvlen]) |*msg, i| {
            var size: i32 = 0;
            const msg_iovlen = @intCast(usize, msg.msg_hdr.msg_iovlen); // kernel side this is treated as unsigned
            for (msg.msg_hdr.msg_iov[0..msg_iovlen]) |iov, j| {
                if (iov.iov_len > std.math.maxInt(i32) or @addWithOverflow(i32, size, @intCast(i32, iov.iov_len), &size)) {
                    // batch-send all messages up to the current message
                    if (next_unsent < i) {
                        const batch_size = i - next_unsent;
                        const r = syscall4(SYS_sendmmsg, @bitCast(usize, isize(fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
                        if (getErrno(r) != 0) return next_unsent;
                        if (r < batch_size) return next_unsent + r;
                    }
                    // send current message as own packet
                    const r = sendmsg(fd, &msg.msg_hdr, flags);
                    if (getErrno(r) != 0) return r;
                    // Linux limits the total bytes sent by sendmsg to INT_MAX, so this cast is safe.
                    msg.msg_len = @intCast(u32, r);
                    next_unsent = i + 1;
                    break;
                }
            }
        }
        if (next_unsent < kvlen or next_unsent == 0) { // want to make sure at least one syscall occurs (e.g. to trigger MSG_EOR)
            const batch_size = kvlen - next_unsent;
            const r = syscall4(SYS_sendmmsg, @bitCast(usize, isize(fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
            if (getErrno(r) != 0) return r;
            return next_unsent + r;
        }
        return kvlen;
    }
    return syscall4(SYS_sendmmsg, @bitCast(usize, isize(fd)), @ptrToInt(msgvec), vlen, flags);
}

pub fn connect(fd: i32, addr: *const c_void, len: socklen_t) usize {
    return syscall3(SYS_connect, @bitCast(usize, isize(fd)), @ptrToInt(addr), len);
}

pub fn recvmsg(fd: i32, msg: *msghdr, flags: u32) usize {
    return syscall3(SYS_recvmsg, @bitCast(usize, isize(fd)), @ptrToInt(msg), flags);
}

pub fn recvfrom(fd: i32, noalias buf: [*]u8, len: usize, flags: u32, noalias addr: ?*sockaddr, noalias alen: ?*socklen_t) usize {
    return syscall6(SYS_recvfrom, @bitCast(usize, isize(fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen));
}

pub fn shutdown(fd: i32, how: i32) usize {
    return syscall2(SYS_shutdown, @bitCast(usize, isize(fd)), @bitCast(usize, isize(how)));
}

pub fn bind(fd: i32, addr: *const sockaddr, len: socklen_t) usize {
    return syscall3(SYS_bind, @bitCast(usize, isize(fd)), @ptrToInt(addr), @intCast(usize, len));
}

pub fn listen(fd: i32, backlog: u32) usize {
    return syscall2(SYS_listen, @bitCast(usize, isize(fd)), backlog);
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: u32, addr: ?*const sockaddr, alen: socklen_t) usize {
    return syscall6(SYS_sendto, @bitCast(usize, isize(fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen));
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: [2]i32) usize {
    return syscall4(SYS_socketpair, @intCast(usize, domain), @intCast(usize, socket_type), @intCast(usize, protocol), @ptrToInt(&fd[0]));
}

pub fn accept(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    return accept4(fd, addr, len, 0);
}

pub fn accept4(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t, flags: u32) usize {
    return syscall4(SYS_accept4, @bitCast(usize, isize(fd)), @ptrToInt(addr), @ptrToInt(len), flags);
}

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_fstat64")) {
        return syscall2(SYS_fstat64, @bitCast(usize, isize(fd)), @ptrToInt(stat_buf));
    } else {
        return syscall2(SYS_fstat, @bitCast(usize, isize(fd)), @ptrToInt(stat_buf));
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn stat(pathname: [*]const u8, statbuf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_stat64")) {
        return syscall2(SYS_stat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(SYS_stat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lstat(pathname: [*]const u8, statbuf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_lstat64")) {
        return syscall2(SYS_lstat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(SYS_lstat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fstatat(dirfd: i32, path: [*]const u8, stat_buf: *Stat, flags: u32) usize {
    if (@hasDecl(@This(), "SYS_fstatat64")) {
        return syscall4(SYS_fstatat64, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    } else {
        return syscall4(SYS_fstatat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    }
}

pub fn statx(dirfd: i32, path: [*]const u8, flags: u32, mask: u32, statx_buf: *Statx) usize {
    if (@hasDecl(@This(), "SYS_statx")) {
        return syscall5(
            SYS_statx,
            @bitCast(usize, isize(dirfd)),
            @ptrToInt(path),
            flags,
            mask,
            @ptrToInt(statx_buf),
        );
    }
    return @bitCast(usize, isize(-ENOSYS));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn listxattr(path: [*]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_listxattr, @ptrToInt(path), @ptrToInt(list), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn llistxattr(path: [*]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_llistxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn flistxattr(fd: usize, list: [*]u8, size: usize) usize {
    return syscall3(SYS_flistxattr, fd, @ptrToInt(list), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn getxattr(path: [*]const u8, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_getxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lgetxattr(path: [*]const u8, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fgetxattr(fd: usize, name: [*]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, fd, @ptrToInt(name), @ptrToInt(value), size);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn setxattr(path: [*]const u8, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_setxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lsetxattr(path: [*]const u8, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_lsetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fsetxattr(fd: usize, name: [*]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_fsetxattr, fd, @ptrToInt(name), @ptrToInt(value), size, flags);
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn removexattr(path: [*]const u8, name: [*]const u8) usize {
    return syscall2(SYS_removexattr, @ptrToInt(path), @ptrToInt(name));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn lremovexattr(path: [*]const u8, name: [*]const u8) usize {
    return syscall2(SYS_lremovexattr, @ptrToInt(path), @ptrToInt(name));
}

// TODO https://github.com/ziglang/zig/issues/265
pub fn fremovexattr(fd: usize, name: [*]const u8) usize {
    return syscall2(SYS_fremovexattr, fd, @ptrToInt(name));
}

pub fn sched_getaffinity(pid: i32, size: usize, set: *cpu_set_t) usize {
    const rc = syscall3(SYS_sched_getaffinity, @bitCast(usize, isize(pid)), size, @ptrToInt(set));
    if (@bitCast(isize, rc) < 0) return rc;
    if (rc < size) @memset(@ptrCast([*]u8, set) + rc, 0, size - rc);
    return 0;
}

pub fn epoll_create() usize {
    return epoll_create1(0);
}

pub fn epoll_create1(flags: usize) usize {
    return syscall1(SYS_epoll_create1, flags);
}

pub fn epoll_ctl(epoll_fd: i32, op: u32, fd: i32, ev: ?*epoll_event) usize {
    return syscall4(SYS_epoll_ctl, @bitCast(usize, isize(epoll_fd)), @intCast(usize, op), @bitCast(usize, isize(fd)), @ptrToInt(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32) usize {
    return epoll_pwait(epoll_fd, events, maxevents, timeout, null);
}

pub fn epoll_pwait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32, sigmask: ?*sigset_t) usize {
    return syscall6(
        SYS_epoll_pwait,
        @bitCast(usize, isize(epoll_fd)),
        @ptrToInt(events),
        @intCast(usize, maxevents),
        @bitCast(usize, isize(timeout)),
        @ptrToInt(sigmask),
        @sizeOf(sigset_t),
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(SYS_eventfd2, count, flags);
}

pub fn timerfd_create(clockid: i32, flags: u32) usize {
    return syscall2(SYS_timerfd_create, @bitCast(usize, isize(clockid)), flags);
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(SYS_timerfd_gettime, @bitCast(usize, isize(fd)), @ptrToInt(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: u32, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(SYS_timerfd_settime, @bitCast(usize, isize(fd)), flags, @ptrToInt(new_value), @ptrToInt(old_value));
}

pub fn unshare(flags: usize) usize {
    return syscall1(SYS_unshare, flags);
}

pub fn capget(hdrp: *cap_user_header_t, datap: *cap_user_data_t) usize {
    return syscall2(SYS_capget, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub fn capset(hdrp: *cap_user_header_t, datap: *const cap_user_data_t) usize {
    return syscall2(SYS_capset, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) usize {
    return syscall2(SYS_sigaltstack, @ptrToInt(ss), @ptrToInt(old_ss));
}

pub fn uname(uts: *utsname) usize {
    return syscall1(SYS_uname, @ptrToInt(uts));
}

// XXX: This should be weak
extern const __ehdr_start: elf.Ehdr = undefined;

pub fn dl_iterate_phdr(comptime T: type, callback: extern fn (info: *dl_phdr_info, size: usize, data: ?*T) i32, data: ?*T) isize {
    if (builtin.link_libc) {
        return std.c.dl_iterate_phdr(@ptrCast(std.c.dl_iterate_phdr_callback, callback), @ptrCast(?*c_void, data));
    }

    const elf_base = @ptrToInt(&__ehdr_start);
    const n_phdr = __ehdr_start.e_phnum;
    const phdrs = (@intToPtr([*]elf.Phdr, elf_base + __ehdr_start.e_phoff))[0..n_phdr];

    var it = dl.linkmap_iterator(phdrs) catch return 0;

    // The executable has no dynamic link segment, create a single entry for
    // the whole ELF image
    if (it.end()) {
        var info = dl_phdr_info{
            .dlpi_addr = elf_base,
            .dlpi_name = c"/proc/self/exe",
            .dlpi_phdr = @intToPtr([*]elf.Phdr, elf_base + __ehdr_start.e_phoff),
            .dlpi_phnum = __ehdr_start.e_phnum,
        };

        return callback(&info, @sizeOf(dl_phdr_info), data);
    }

    // Last return value from the callback function
    var last_r: isize = 0;
    while (it.next()) |entry| {
        var dlpi_phdr: usize = undefined;
        var dlpi_phnum: u16 = undefined;

        if (entry.l_addr != 0) {
            const elf_header = @intToPtr(*elf.Ehdr, entry.l_addr);
            dlpi_phdr = entry.l_addr + elf_header.e_phoff;
            dlpi_phnum = elf_header.e_phnum;
        } else {
            // This is the running ELF image
            dlpi_phdr = elf_base + __ehdr_start.e_phoff;
            dlpi_phnum = __ehdr_start.e_phnum;
        }

        var info = dl_phdr_info{
            .dlpi_addr = entry.l_addr,
            .dlpi_name = entry.l_name,
            .dlpi_phdr = @intToPtr([*]elf.Phdr, dlpi_phdr),
            .dlpi_phnum = dlpi_phnum,
        };

        last_r = callback(&info, @sizeOf(dl_phdr_info), data);
        if (last_r != 0) break;
    }

    return last_r;
}

pub fn io_uring_setup(entries: u32, p: *io_uring_params) usize {
    return syscall2(SYS_io_uring_setup, entries, @ptrToInt(p));
}

pub fn io_uring_enter(fd: i32, to_submit: u32, min_complete: u32, flags: u32, sig: ?*sigset_t) usize {
    return syscall6(SYS_io_uring_enter, @bitCast(usize, isize(fd)), to_submit, min_complete, flags, @ptrToInt(sig), NSIG / 8);
}

pub fn io_uring_register(fd: i32, opcode: u32, arg: ?*const c_void, nr_args: u32) usize {
    return syscall4(SYS_io_uring_register, @bitCast(usize, isize(fd)), opcode, @ptrToInt(arg), nr_args);
}

test "" {
    if (builtin.os == .linux) {
        _ = @import("linux/test.zig");
    }
}
