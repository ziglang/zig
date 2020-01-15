// This file provides the system interface functions for Linux matching those
// that are provided by libc, whether or not libc is linked. The following
// abstractions are made:
// * Work around kernel bugs and limitations. For example, see sendmmsg.
// * Implement all the syscalls in the same way that libc functions will
//   provide `rename` when only the `renameat` syscall exists.
// * Does not support POSIX thread cancellation.
const std = @import("../std.zig");
const builtin = std.builtin;
const assert = std.debug.assert;
const maxInt = std.math.maxInt;
const elf = std.elf;
const vdso = @import("linux/vdso.zig");
const dl = @import("../dynamic_library.zig");

pub usingnamespace switch (builtin.arch) {
    .i386 => @import("linux/i386.zig"),
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

// Some architectures require 64bit parameters for some syscalls to be passed in
// even-aligned register pair
const require_aligned_register_pair = //
    std.Target.current.cpu.arch.isMIPS() or
    std.Target.current.cpu.arch.isARM() or
    std.Target.current.cpu.arch.isThumb();

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) u12 {
    const signed_r = @bitCast(isize, r);
    return if (signed_r > -4096 and signed_r < 0) @intCast(u12, -signed_r) else 0;
}

pub fn dup2(old: i32, new: i32) usize {
    if (@hasDecl(@This(), "SYS_dup2")) {
        return syscall2(SYS_dup2, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)));
    } else {
        if (old == new) {
            if (std.debug.runtime_safety) {
                const rc = syscall2(SYS_fcntl, @bitCast(usize, @as(isize, old)), F_GETFD);
                if (@bitCast(isize, rc) < 0) return rc;
            }
            return @intCast(usize, old);
        } else {
            return syscall3(SYS_dup3, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)), 0);
        }
    }
}

pub fn dup3(old: i32, new: i32, flags: u32) usize {
    return syscall3(SYS_dup3, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)), flags);
}

pub fn chdir(path: [*:0]const u8) usize {
    return syscall1(SYS_chdir, @ptrToInt(path));
}

pub fn fchdir(fd: fd_t) usize {
    return syscall1(SYS_fchdir, @bitCast(usize, @as(isize, fd)));
}

pub fn chroot(path: [*:0]const u8) usize {
    return syscall1(SYS_chroot, @ptrToInt(path));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) usize {
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
    return @call(.{ .modifier = .always_inline }, syscall0, .{SYS_vfork});
}

pub fn futimens(fd: i32, times: *const [2]timespec) usize {
    return utimensat(fd, null, times, 0);
}

pub fn utimensat(dirfd: i32, path: ?[*:0]const u8, times: *const [2]timespec, flags: u32) usize {
    return syscall4(SYS_utimensat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(times), flags);
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
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn getdents64(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        SYS_getdents64,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(SYS_inotify_init1, flags);
}

pub fn inotify_add_watch(fd: i32, pathname: [*:0]const u8, mask: u32) usize {
    return syscall3(SYS_inotify_add_watch, @bitCast(usize, @as(isize, fd)), @ptrToInt(pathname), mask);
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(SYS_inotify_rm_watch, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, wd)));
}

pub fn readlink(noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    if (@hasDecl(@This(), "SYS_readlink")) {
        return syscall3(SYS_readlink, @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    } else {
        return syscall4(SYS_readlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    }
}

pub fn readlinkat(dirfd: i32, noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(SYS_readlinkat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

pub fn mkdir(path: [*:0]const u8, mode: u32) usize {
    if (@hasDecl(@This(), "SYS_mkdir")) {
        return syscall2(SYS_mkdir, @ptrToInt(path), mode);
    } else {
        return syscall3(SYS_mkdirat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), mode);
    }
}

pub fn mkdirat(dirfd: i32, path: [*:0]const u8, mode: u32) usize {
    return syscall3(SYS_mkdirat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), mode);
}

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: [*:0]const u8, flags: u32, data: usize) usize {
    return syscall5(SYS_mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
}

pub fn umount(special: [*:0]const u8) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), 0);
}

pub fn umount2(special: [*:0]const u8, flags: u32) usize {
    return syscall2(SYS_umount2, @ptrToInt(special), flags);
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: u64) usize {
    if (@hasDecl(@This(), "SYS_mmap2")) {
        // Make sure the offset is also specified in multiples of page size
        if ((offset & (MMAP2_UNIT - 1)) != 0)
            return @bitCast(usize, @as(isize, -EINVAL));

        return syscall6(
            SYS_mmap2,
            @ptrToInt(address),
            length,
            prot,
            flags,
            @bitCast(usize, @as(isize, fd)),
            @truncate(usize, offset / MMAP2_UNIT),
        );
    } else {
        return syscall6(
            SYS_mmap,
            @ptrToInt(address),
            length,
            prot,
            flags,
            @bitCast(usize, @as(isize, fd)),
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

pub fn poll(fds: [*]pollfd, n: nfds_t, timeout: i32) usize {
    if (@hasDecl(@This(), "SYS_poll")) {
        return syscall3(SYS_poll, @ptrToInt(fds), n, @bitCast(u32, timeout));
    } else {
        return syscall6(
            SYS_ppoll,
            @ptrToInt(fds),
            n,
            @ptrToInt(if (timeout >= 0)
                &timespec{
                    .tv_sec = @divTrunc(timeout, 1000),
                    .tv_nsec = @rem(timeout, 1000) * 1000000,
                }
            else
                null),
            0,
            0,
            NSIG / 8,
        );
    }
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return syscall3(SYS_read, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: u64) usize {
    return syscall5(
        SYS_preadv,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn preadv2(fd: i32, iov: [*]const iovec, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        SYS_preadv2,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(SYS_readv, @bitCast(usize, @as(isize, fd)), @ptrToInt(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(SYS_writev, @bitCast(usize, @as(isize, fd)), @ptrToInt(iov), count);
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64) usize {
    return syscall5(
        SYS_pwritev,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn pwritev2(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        SYS_pwritev2,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

pub fn rmdir(path: [*:0]const u8) usize {
    if (@hasDecl(@This(), "SYS_rmdir")) {
        return syscall1(SYS_rmdir, @ptrToInt(path));
    } else {
        return syscall3(SYS_unlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), AT_REMOVEDIR);
    }
}

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasDecl(@This(), "SYS_symlink")) {
        return syscall2(SYS_symlink, @ptrToInt(existing), @ptrToInt(new));
    } else {
        return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new));
    }
}

pub fn symlinkat(existing: [*:0]const u8, newfd: i32, newpath: [*:0]const u8) usize {
    return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, @as(isize, newfd)), @ptrToInt(newpath));
}

pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: u64) usize {
    if (@hasDecl(@This(), "SYS_pread64")) {
        if (require_aligned_register_pair) {
            return syscall6(
                SYS_pread64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                0,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        } else {
            return syscall5(
                SYS_pread64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        }
    } else {
        return syscall4(SYS_pread, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count, offset);
    }
}

pub fn access(path: [*:0]const u8, mode: u32) usize {
    if (@hasDecl(@This(), "SYS_access")) {
        return syscall2(SYS_access, @ptrToInt(path), mode);
    } else {
        return syscall4(SYS_faccessat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), mode, 0);
    }
}

pub fn faccessat(dirfd: i32, path: [*:0]const u8, mode: u32, flags: u32) usize {
    return syscall4(SYS_faccessat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), mode, flags);
}

pub fn pipe(fd: *[2]i32) usize {
    if (comptime builtin.arch.isMIPS()) {
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
    return syscall3(SYS_write, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count);
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: usize) usize {
    return syscall4(SYS_pwrite, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count, offset);
}

pub fn rename(old: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasDecl(@This(), "SYS_rename")) {
        return syscall2(SYS_rename, @ptrToInt(old), @ptrToInt(new));
    } else if (@hasDecl(@This(), "SYS_renameat")) {
        return syscall4(SYS_renameat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(old), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new));
    } else {
        return syscall5(SYS_renameat2, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(old), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new), 0);
    }
}

pub fn renameat(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    if (@hasDecl(@This(), "SYS_renameat")) {
        return syscall4(
            SYS_renameat,
            @bitCast(usize, @as(isize, oldfd)),
            @ptrToInt(old),
            @bitCast(usize, @as(isize, newfd)),
            @ptrToInt(new),
        );
    } else {
        return syscall5(
            SYS_renameat2,
            @bitCast(usize, @as(isize, oldfd)),
            @ptrToInt(old),
            @bitCast(usize, @as(isize, newfd)),
            @ptrToInt(new),
            0,
        );
    }
}

pub fn renameat2(oldfd: i32, oldpath: [*:0]const u8, newfd: i32, newpath: [*:0]const u8, flags: u32) usize {
    return syscall5(
        SYS_renameat2,
        @bitCast(usize, @as(isize, oldfd)),
        @ptrToInt(oldpath),
        @bitCast(usize, @as(isize, newfd)),
        @ptrToInt(newpath),
        flags,
    );
}

pub fn open(path: [*:0]const u8, flags: u32, perm: usize) usize {
    if (@hasDecl(@This(), "SYS_open")) {
        return syscall3(SYS_open, @ptrToInt(path), flags, perm);
    } else {
        return syscall4(
            SYS_openat,
            @bitCast(usize, @as(isize, AT_FDCWD)),
            @ptrToInt(path),
            flags,
            perm,
        );
    }
}

pub fn create(path: [*:0]const u8, perm: usize) usize {
    return syscall2(SYS_creat, @ptrToInt(path), perm);
}

pub fn openat(dirfd: i32, path: [*:0]const u8, flags: u32, mode: usize) usize {
    // dirfd could be negative, for example AT_FDCWD is -100
    return syscall4(SYS_openat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), flags, mode);
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
    return syscall1(SYS_close, @bitCast(usize, @as(isize, fd)));
}

/// Can only be called on 32 bit systems. For 64 bit see `lseek`.
pub fn llseek(fd: i32, offset: u64, result: ?*u64, whence: usize) usize {
    return syscall5(
        SYS__llseek,
        @bitCast(usize, @as(isize, fd)),
        @truncate(usize, offset >> 32),
        @truncate(usize, offset),
        @ptrToInt(result),
        whence,
    );
}

/// Can only be called on 64 bit systems. For 32 bit see `llseek`.
pub fn lseek(fd: i32, offset: i64, whence: usize) usize {
    return syscall3(SYS_lseek, @bitCast(usize, @as(isize, fd)), @bitCast(usize, offset), whence);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(SYS_exit, @bitCast(usize, @as(isize, status)));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(SYS_exit_group, @bitCast(usize, @as(isize, status)));
    unreachable;
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(SYS_getrandom, @ptrToInt(buf), count, flags);
}

pub fn kill(pid: pid_t, sig: i32) usize {
    return syscall2(SYS_kill, @bitCast(usize, @as(isize, pid)), @bitCast(usize, @as(isize, sig)));
}

pub fn tkill(tid: pid_t, sig: i32) usize {
    return syscall2(SYS_tkill, @bitCast(usize, @as(isize, tid)), @bitCast(usize, @as(isize, sig)));
}

pub fn tgkill(tgid: pid_t, tid: pid_t, sig: i32) usize {
    return syscall2(SYS_tgkill, @bitCast(usize, @as(isize, tgid)), @bitCast(usize, @as(isize, tid)), @bitCast(usize, @as(isize, sig)));
}

pub fn unlink(path: [*:0]const u8) usize {
    if (@hasDecl(@This(), "SYS_unlink")) {
        return syscall1(SYS_unlink, @ptrToInt(path));
    } else {
        return syscall3(SYS_unlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), 0);
    }
}

pub fn unlinkat(dirfd: i32, path: [*:0]const u8, flags: u32) usize {
    return syscall3(SYS_unlinkat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), flags);
}

pub fn waitpid(pid: pid_t, status: *u32, flags: u32) usize {
    return syscall4(SYS_wait4, @bitCast(usize, @as(isize, pid)), @ptrToInt(status), flags, 0);
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
                0, @bitCast(usize, @as(isize, -EINVAL)) => return rc,
                else => {},
            }
        }
    }
    return syscall2(SYS_clock_gettime, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
}

fn init_vdso_clock_gettime(clk: i32, ts: *timespec) callconv(.C) usize {
    const ptr = @intToPtr(?*const c_void, vdso.lookup(VDSO_CGT_VER, VDSO_CGT_SYM));
    // Note that we may not have a VDSO at all, update the stub address anyway
    // so that clock_gettime will fall back on the good old (and slow) syscall
    @atomicStore(?*const c_void, &vdso_clock_gettime, ptr, .Monotonic);
    // Call into the VDSO if available
    if (ptr) |fn_ptr| {
        const f = @ptrCast(vdso_clock_gettime_ty, fn_ptr);
        return f(clk, ts);
    }
    return @bitCast(usize, @as(isize, -ENOSYS));
}

pub fn clock_getres(clk_id: i32, tp: *timespec) usize {
    return syscall2(SYS_clock_getres, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(SYS_clock_settime, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
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
        return @as(u32, syscall0(SYS_getuid32));
    } else {
        return @as(u32, syscall0(SYS_getuid));
    }
}

pub fn getgid() u32 {
    if (@hasDecl(@This(), "SYS_getgid32")) {
        return @as(u32, syscall0(SYS_getgid32));
    } else {
        return @as(u32, syscall0(SYS_getgid));
    }
}

pub fn geteuid() u32 {
    if (@hasDecl(@This(), "SYS_geteuid32")) {
        return @as(u32, syscall0(SYS_geteuid32));
    } else {
        return @as(u32, syscall0(SYS_geteuid));
    }
}

pub fn getegid() u32 {
    if (@hasDecl(@This(), "SYS_getegid32")) {
        return @as(u32, syscall0(SYS_getegid32));
    } else {
        return @as(u32, syscall0(SYS_getegid));
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

pub fn getpid() pid_t {
    return @bitCast(pid_t, @truncate(u32, syscall0(SYS_getpid)));
}

pub fn gettid() pid_t {
    return @bitCast(pid_t, @truncate(u32, syscall0(SYS_gettid)));
}

pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) usize {
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
    const ksa_mask_size = @sizeOf(@TypeOf(ksa_old.mask));
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

pub fn sigaddset(set: *sigset_t, sig: u6) void {
    const s = sig - 1;
    (set.*)[@intCast(usize, s) / usize.bit_count] |= @intCast(usize, 1) << (s & (usize.bit_count - 1));
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((set.*)[@intCast(usize, s) / usize.bit_count] & (@intCast(usize, 1) << (s & (usize.bit_count - 1)))) != 0;
}

pub fn getsockname(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getsockname, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len) });
    }
    return syscall3(SYS_getsockname, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn getpeername(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getpeername, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len) });
    }
    return syscall3(SYS_getpeername, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_socket, &[3]usize{ domain, socket_type, protocol });
    }
    return syscall3(SYS_socket, domain, socket_type, protocol);
}

pub fn setsockopt(fd: i32, level: u32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_setsockopt, &[5]usize{ @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen) });
    }
    return syscall5(SYS_setsockopt, @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen));
}

pub fn getsockopt(fd: i32, level: u32, optname: u32, noalias optval: [*]u8, noalias optlen: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getsockopt, &[5]usize{ @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen) });
    }
    return syscall5(SYS_getsockopt, @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen));
}

pub fn sendmsg(fd: i32, msg: *msghdr_const, flags: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_sendmsg, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags });
    }
    return syscall3(SYS_sendmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags);
}

pub fn sendmmsg(fd: i32, msgvec: [*]mmsghdr_const, vlen: u32, flags: u32) usize {
    if (@typeInfo(usize).Int.bits > @typeInfo(@TypeOf(mmsghdr(undefined).msg_len)).Int.bits) {
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
                        const r = syscall4(SYS_sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
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
            const r = syscall4(SYS_sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
            if (getErrno(r) != 0) return r;
            return next_unsent + r;
        }
        return kvlen;
    }
    return syscall4(SYS_sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msgvec), vlen, flags);
}

pub fn connect(fd: i32, addr: *const c_void, len: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_connect, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), len });
    }
    return syscall3(SYS_connect, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), len);
}

pub fn recvmsg(fd: i32, msg: *msghdr, flags: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_recvmsg, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags });
    }
    return syscall3(SYS_recvmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags);
}

pub fn recvfrom(fd: i32, noalias buf: [*]u8, len: usize, flags: u32, noalias addr: ?*sockaddr, noalias alen: ?*socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_recvfrom, &[6]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen) });
    }
    return syscall6(SYS_recvfrom, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen));
}

pub fn shutdown(fd: i32, how: i32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_shutdown, &[2]usize{ @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, how)) });
    }
    return syscall2(SYS_shutdown, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, how)));
}

pub fn bind(fd: i32, addr: *const sockaddr, len: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_bind, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @intCast(usize, len) });
    }
    return syscall3(SYS_bind, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @intCast(usize, len));
}

pub fn listen(fd: i32, backlog: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_listen, &[2]usize{ @bitCast(usize, @as(isize, fd)), backlog });
    }
    return syscall2(SYS_listen, @bitCast(usize, @as(isize, fd)), backlog);
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: u32, addr: ?*const sockaddr, alen: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_sendto, &[6]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen) });
    }
    return syscall6(SYS_sendto, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen));
}

pub fn sendfile(outfd: i32, infd: i32, offset: ?*i64, count: usize) usize {
    if (@hasDecl(@This(), "SYS_sendfile64")) {
        return syscall4(
            SYS_sendfile64,
            @bitCast(usize, @as(isize, outfd)),
            @bitCast(usize, @as(isize, infd)),
            @ptrToInt(offset),
            count,
        );
    } else {
        return syscall4(
            SYS_sendfile,
            @bitCast(usize, @as(isize, outfd)),
            @bitCast(usize, @as(isize, infd)),
            @ptrToInt(offset),
            count,
        );
    }
}

pub fn socketpair(domain: i32, socket_type: i32, protocol: i32, fd: [2]i32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_socketpair, &[4]usize{ @intCast(usize, domain), @intCast(usize, socket_type), @intCast(usize, protocol), @ptrToInt(&fd[0]) });
    }
    return syscall4(SYS_socketpair, @intCast(usize, domain), @intCast(usize, socket_type), @intCast(usize, protocol), @ptrToInt(&fd[0]));
}

pub fn accept(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_accept, &[4]usize{ fd, addr, len, 0 });
    }
    return accept4(fd, addr, len, 0);
}

pub fn accept4(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t, flags: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_accept4, &[4]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len), flags });
    }
    return syscall4(SYS_accept4, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len), flags);
}

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_fstat64")) {
        return syscall2(SYS_fstat64, @bitCast(usize, @as(isize, fd)), @ptrToInt(stat_buf));
    } else {
        return syscall2(SYS_fstat, @bitCast(usize, @as(isize, fd)), @ptrToInt(stat_buf));
    }
}

pub fn stat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_stat64")) {
        return syscall2(SYS_stat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(SYS_stat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

pub fn lstat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasDecl(@This(), "SYS_lstat64")) {
        return syscall2(SYS_lstat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(SYS_lstat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

pub fn fstatat(dirfd: i32, path: [*:0]const u8, stat_buf: *Stat, flags: u32) usize {
    if (@hasDecl(@This(), "SYS_fstatat64")) {
        return syscall4(SYS_fstatat64, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    } else {
        return syscall4(SYS_fstatat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    }
}

pub fn statx(dirfd: i32, path: [*]const u8, flags: u32, mask: u32, statx_buf: *Statx) usize {
    if (@hasDecl(@This(), "SYS_statx")) {
        return syscall5(
            SYS_statx,
            @bitCast(usize, @as(isize, dirfd)),
            @ptrToInt(path),
            flags,
            mask,
            @ptrToInt(statx_buf),
        );
    }
    return @bitCast(usize, @as(isize, -ENOSYS));
}

pub fn listxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_listxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn llistxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(SYS_llistxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn flistxattr(fd: usize, list: [*]u8, size: usize) usize {
    return syscall3(SYS_flistxattr, fd, @ptrToInt(list), size);
}

pub fn getxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_getxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

pub fn lgetxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

pub fn fgetxattr(fd: usize, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(SYS_lgetxattr, fd, @ptrToInt(name), @ptrToInt(value), size);
}

pub fn setxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_setxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn lsetxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_lsetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn fsetxattr(fd: usize, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(SYS_fsetxattr, fd, @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn removexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(SYS_removexattr, @ptrToInt(path), @ptrToInt(name));
}

pub fn lremovexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(SYS_lremovexattr, @ptrToInt(path), @ptrToInt(name));
}

pub fn fremovexattr(fd: usize, name: [*:0]const u8) usize {
    return syscall2(SYS_fremovexattr, fd, @ptrToInt(name));
}

pub fn sched_yield() usize {
    return syscall0(SYS_sched_yield);
}

pub fn sched_getaffinity(pid: pid_t, size: usize, set: *cpu_set_t) usize {
    const rc = syscall3(SYS_sched_getaffinity, @bitCast(usize, @as(isize, pid)), size, @ptrToInt(set));
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
    return syscall4(SYS_epoll_ctl, @bitCast(usize, @as(isize, epoll_fd)), @intCast(usize, op), @bitCast(usize, @as(isize, fd)), @ptrToInt(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32) usize {
    return epoll_pwait(epoll_fd, events, maxevents, timeout, null);
}

pub fn epoll_pwait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32, sigmask: ?*sigset_t) usize {
    return syscall6(
        SYS_epoll_pwait,
        @bitCast(usize, @as(isize, epoll_fd)),
        @ptrToInt(events),
        @intCast(usize, maxevents),
        @bitCast(usize, @as(isize, timeout)),
        @ptrToInt(sigmask),
        @sizeOf(sigset_t),
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(SYS_eventfd2, count, flags);
}

pub fn timerfd_create(clockid: i32, flags: u32) usize {
    return syscall2(SYS_timerfd_create, @bitCast(usize, @as(isize, clockid)), flags);
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(SYS_timerfd_gettime, @bitCast(usize, @as(isize, fd)), @ptrToInt(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: u32, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(SYS_timerfd_settime, @bitCast(usize, @as(isize, fd)), flags, @ptrToInt(new_value), @ptrToInt(old_value));
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

pub fn io_uring_setup(entries: u32, p: *io_uring_params) usize {
    return syscall2(SYS_io_uring_setup, entries, @ptrToInt(p));
}

pub fn io_uring_enter(fd: i32, to_submit: u32, min_complete: u32, flags: u32, sig: ?*sigset_t) usize {
    return syscall6(SYS_io_uring_enter, @bitCast(usize, @as(isize, fd)), to_submit, min_complete, flags, @ptrToInt(sig), NSIG / 8);
}

pub fn io_uring_register(fd: i32, opcode: u32, arg: ?*const c_void, nr_args: u32) usize {
    return syscall4(SYS_io_uring_register, @bitCast(usize, @as(isize, fd)), opcode, @ptrToInt(arg), nr_args);
}

pub fn memfd_create(name: [*:0]const u8, flags: u32) usize {
    return syscall2(SYS_memfd_create, @ptrToInt(name), flags);
}

pub fn getrusage(who: i32, usage: *rusage) usize {
    return syscall2(SYS_getrusage, @bitCast(usize, @as(isize, who)), @ptrToInt(usage));
}

pub fn tcgetattr(fd: fd_t, termios_p: *termios) usize {
    return syscall3(SYS_ioctl, @bitCast(usize, @as(isize, fd)), TCGETS, @ptrToInt(termios_p));
}

pub fn tcsetattr(fd: fd_t, optional_action: TCSA, termios_p: *const termios) usize {
    return syscall3(SYS_ioctl, @bitCast(usize, @as(isize, fd)), TCSETS + @enumToInt(optional_action), @ptrToInt(termios_p));
}

test "" {
    if (builtin.os.tag == .linux) {
        _ = @import("linux/test.zig");
    }
}
