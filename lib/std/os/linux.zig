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
    .mips, .mipsel => @import("linux/mips.zig"),
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
    if (@hasField(SYS, "dup2")) {
        return syscall2(.dup2, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)));
    } else {
        if (old == new) {
            if (std.debug.runtime_safety) {
                const rc = syscall2(.fcntl, @bitCast(usize, @as(isize, old)), F_GETFD);
                if (@bitCast(isize, rc) < 0) return rc;
            }
            return @intCast(usize, old);
        } else {
            return syscall3(.dup3, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)), 0);
        }
    }
}

pub fn dup3(old: i32, new: i32, flags: u32) usize {
    return syscall3(.dup3, @bitCast(usize, @as(isize, old)), @bitCast(usize, @as(isize, new)), flags);
}

pub fn chdir(path: [*:0]const u8) usize {
    return syscall1(.chdir, @ptrToInt(path));
}

pub fn fchdir(fd: fd_t) usize {
    return syscall1(.fchdir, @bitCast(usize, @as(isize, fd)));
}

pub fn chroot(path: [*:0]const u8) usize {
    return syscall1(.chroot, @ptrToInt(path));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) usize {
    return syscall3(.execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn fork() usize {
    if (@hasField(SYS, "fork")) {
        return syscall0(.fork);
    } else {
        return syscall2(.clone, SIGCHLD, 0);
    }
}

/// This must be inline, and inline call the syscall function, because if the
/// child does a return it will clobber the parent's stack.
/// It is advised to avoid this function and use clone instead, because
/// the compiler is not aware of how vfork affects control flow and you may
/// see different results in optimized builds.
pub inline fn vfork() usize {
    return @call(.{ .modifier = .always_inline }, syscall0, .{.vfork});
}

pub fn futimens(fd: i32, times: *const [2]timespec) usize {
    return utimensat(fd, null, times, 0);
}

pub fn utimensat(dirfd: i32, path: ?[*:0]const u8, times: *const [2]timespec, flags: u32) usize {
    return syscall4(.utimensat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(times), flags);
}

pub fn futex_wait(uaddr: *const i32, futex_op: u32, val: i32, timeout: ?*timespec) usize {
    return syscall4(.futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val), @ptrToInt(timeout));
}

pub fn futex_wake(uaddr: *const i32, futex_op: u32, val: i32) usize {
    return syscall3(.futex, @ptrToInt(uaddr), futex_op, @bitCast(u32, val));
}

pub fn getcwd(buf: [*]u8, size: usize) usize {
    return syscall2(.getcwd, @ptrToInt(buf), size);
}

pub fn getdents(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        .getdents,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn getdents64(fd: i32, dirp: [*]u8, len: usize) usize {
    return syscall3(
        .getdents64,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(dirp),
        std.math.min(len, maxInt(c_int)),
    );
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(.inotify_init1, flags);
}

pub fn inotify_add_watch(fd: i32, pathname: [*:0]const u8, mask: u32) usize {
    return syscall3(.inotify_add_watch, @bitCast(usize, @as(isize, fd)), @ptrToInt(pathname), mask);
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(.inotify_rm_watch, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, wd)));
}

pub fn readlink(noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    if (@hasField(SYS, "readlink")) {
        return syscall3(.readlink, @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    } else {
        return syscall4(.readlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
    }
}

pub fn readlinkat(dirfd: i32, noalias path: [*:0]const u8, noalias buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(.readlinkat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

pub fn mkdir(path: [*:0]const u8, mode: u32) usize {
    if (@hasField(SYS, "mkdir")) {
        return syscall2(.mkdir, @ptrToInt(path), mode);
    } else {
        return syscall3(.mkdirat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), mode);
    }
}

pub fn mkdirat(dirfd: i32, path: [*:0]const u8, mode: u32) usize {
    return syscall3(.mkdirat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), mode);
}

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: [*:0]const u8, flags: u32, data: usize) usize {
    return syscall5(.mount, @ptrToInt(special), @ptrToInt(dir), @ptrToInt(fstype), flags, data);
}

pub fn umount(special: [*:0]const u8) usize {
    return syscall2(.umount2, @ptrToInt(special), 0);
}

pub fn umount2(special: [*:0]const u8, flags: u32) usize {
    return syscall2(.umount2, @ptrToInt(special), flags);
}

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: u64) usize {
    if (@hasField(SYS, "mmap2")) {
        // Make sure the offset is also specified in multiples of page size
        if ((offset & (MMAP2_UNIT - 1)) != 0)
            return @bitCast(usize, @as(isize, -EINVAL));

        return syscall6(
            .mmap2,
            @ptrToInt(address),
            length,
            prot,
            flags,
            @bitCast(usize, @as(isize, fd)),
            @truncate(usize, offset / MMAP2_UNIT),
        );
    } else {
        return syscall6(
            .mmap,
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
    return syscall3(.mprotect, @ptrToInt(address), length, protection);
}

pub fn munmap(address: [*]const u8, length: usize) usize {
    return syscall2(.munmap, @ptrToInt(address), length);
}

pub fn poll(fds: [*]pollfd, n: nfds_t, timeout: i32) usize {
    if (@hasField(SYS, "poll")) {
        return syscall3(.poll, @ptrToInt(fds), n, @bitCast(u32, timeout));
    } else {
        return syscall6(
            .ppoll,
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
    return syscall3(.read, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: u64) usize {
    return syscall5(
        .preadv,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn preadv2(fd: i32, iov: [*]const iovec, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        .preadv2,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(.readv, @bitCast(usize, @as(isize, fd)), @ptrToInt(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(.writev, @bitCast(usize, @as(isize, fd)), @ptrToInt(iov), count);
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64) usize {
    return syscall5(
        .pwritev,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
    );
}

pub fn pwritev2(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64, flags: kernel_rwf) usize {
    return syscall6(
        .pwritev2,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(iov),
        count,
        @truncate(usize, offset),
        @truncate(usize, offset >> 32),
        flags,
    );
}

pub fn rmdir(path: [*:0]const u8) usize {
    if (@hasField(SYS, "rmdir")) {
        return syscall1(.rmdir, @ptrToInt(path));
    } else {
        return syscall3(.unlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), AT_REMOVEDIR);
    }
}

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasField(SYS, "symlink")) {
        return syscall2(.symlink, @ptrToInt(existing), @ptrToInt(new));
    } else {
        return syscall3(.symlinkat, @ptrToInt(existing), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new));
    }
}

pub fn symlinkat(existing: [*:0]const u8, newfd: i32, newpath: [*:0]const u8) usize {
    return syscall3(.symlinkat, @ptrToInt(existing), @bitCast(usize, @as(isize, newfd)), @ptrToInt(newpath));
}

pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: u64) usize {
    if (@hasField(SYS, "pread64")) {
        if (require_aligned_register_pair) {
            return syscall6(
                .pread64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                0,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        } else {
            return syscall5(
                .pread64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        }
    } else {
        return syscall4(
            .pread,
            @bitCast(usize, @as(isize, fd)),
            @ptrToInt(buf),
            count,
            offset,
        );
    }
}

pub fn access(path: [*:0]const u8, mode: u32) usize {
    if (@hasField(SYS, "access")) {
        return syscall2(.access, @ptrToInt(path), mode);
    } else {
        return syscall4(.faccessat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), mode, 0);
    }
}

pub fn faccessat(dirfd: i32, path: [*:0]const u8, mode: u32, flags: u32) usize {
    return syscall4(.faccessat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), mode, flags);
}

pub fn pipe(fd: *[2]i32) usize {
    if (comptime builtin.arch.isMIPS()) {
        return syscall_pipe(fd);
    } else if (@hasField(SYS, "pipe")) {
        return syscall1(.pipe, @ptrToInt(fd));
    } else {
        return syscall2(.pipe2, @ptrToInt(fd), 0);
    }
}

pub fn pipe2(fd: *[2]i32, flags: u32) usize {
    return syscall2(.pipe2, @ptrToInt(fd), flags);
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall3(.write, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), count);
}

pub fn ftruncate(fd: i32, length: u64) usize {
    if (@hasField(SYS, "ftruncate64")) {
        if (require_aligned_register_pair) {
            return syscall4(
                .ftruncate64,
                @bitCast(usize, @as(isize, fd)),
                0,
                @truncate(usize, length),
                @truncate(usize, length >> 32),
            );
        } else {
            return syscall3(
                .ftruncate64,
                @bitCast(usize, @as(isize, fd)),
                @truncate(usize, length),
                @truncate(usize, length >> 32),
            );
        }
    } else {
        return syscall2(
            .ftruncate,
            @bitCast(usize, @as(isize, fd)),
            @truncate(usize, length),
        );
    }
}

pub fn pwrite(fd: i32, buf: [*]const u8, count: usize, offset: u64) usize {
    if (@hasField(SYS, "pwrite64")) {
        if (require_aligned_register_pair) {
            return syscall6(
                .pwrite64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                0,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        } else {
            return syscall5(
                .pwrite64,
                @bitCast(usize, @as(isize, fd)),
                @ptrToInt(buf),
                count,
                @truncate(usize, offset),
                @truncate(usize, offset >> 32),
            );
        }
    } else {
        return syscall4(
            .pwrite,
            @bitCast(usize, @as(isize, fd)),
            @ptrToInt(buf),
            count,
            offset,
        );
    }
}

pub fn rename(old: [*:0]const u8, new: [*:0]const u8) usize {
    if (@hasField(SYS, "rename")) {
        return syscall2(.rename, @ptrToInt(old), @ptrToInt(new));
    } else if (@hasField(SYS, "renameat")) {
        return syscall4(.renameat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(old), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new));
    } else {
        return syscall5(.renameat2, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(old), @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(new), 0);
    }
}

pub fn renameat(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    if (@hasField(SYS, "renameat")) {
        return syscall4(
            .renameat,
            @bitCast(usize, @as(isize, oldfd)),
            @ptrToInt(oldpath),
            @bitCast(usize, @as(isize, newfd)),
            @ptrToInt(newpath),
        );
    } else {
        return syscall5(
            .renameat2,
            @bitCast(usize, @as(isize, oldfd)),
            @ptrToInt(oldpath),
            @bitCast(usize, @as(isize, newfd)),
            @ptrToInt(newpath),
            0,
        );
    }
}

pub fn renameat2(oldfd: i32, oldpath: [*:0]const u8, newfd: i32, newpath: [*:0]const u8, flags: u32) usize {
    return syscall5(
        .renameat2,
        @bitCast(usize, @as(isize, oldfd)),
        @ptrToInt(oldpath),
        @bitCast(usize, @as(isize, newfd)),
        @ptrToInt(newpath),
        flags,
    );
}

pub fn open(path: [*:0]const u8, flags: u32, perm: mode_t) usize {
    if (@hasField(SYS, "open")) {
        return syscall3(.open, @ptrToInt(path), flags, perm);
    } else {
        return syscall4(
            .openat,
            @bitCast(usize, @as(isize, AT_FDCWD)),
            @ptrToInt(path),
            flags,
            perm,
        );
    }
}

pub fn create(path: [*:0]const u8, perm: mode_t) usize {
    return syscall2(.creat, @ptrToInt(path), perm);
}

pub fn openat(dirfd: i32, path: [*:0]const u8, flags: u32, mode: mode_t) usize {
    // dirfd could be negative, for example AT_FDCWD is -100
    return syscall4(.openat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), flags, mode);
}

/// See also `clone` (from the arch-specific include)
pub fn clone5(flags: usize, child_stack_ptr: usize, parent_tid: *i32, child_tid: *i32, newtls: usize) usize {
    return syscall5(.clone, flags, child_stack_ptr, @ptrToInt(parent_tid), @ptrToInt(child_tid), newtls);
}

/// See also `clone` (from the arch-specific include)
pub fn clone2(flags: u32, child_stack_ptr: usize) usize {
    return syscall2(.clone, flags, child_stack_ptr);
}

pub fn close(fd: i32) usize {
    return syscall1(.close, @bitCast(usize, @as(isize, fd)));
}

/// Can only be called on 32 bit systems. For 64 bit see `lseek`.
pub fn llseek(fd: i32, offset: u64, result: ?*u64, whence: usize) usize {
    return syscall5(
        ._llseek,
        @bitCast(usize, @as(isize, fd)),
        @truncate(usize, offset >> 32),
        @truncate(usize, offset),
        @ptrToInt(result),
        whence,
    );
}

/// Can only be called on 64 bit systems. For 32 bit see `llseek`.
pub fn lseek(fd: i32, offset: i64, whence: usize) usize {
    return syscall3(.lseek, @bitCast(usize, @as(isize, fd)), @bitCast(usize, offset), whence);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(.exit, @bitCast(usize, @as(isize, status)));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(.exit_group, @bitCast(usize, @as(isize, status)));
    unreachable;
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(.getrandom, @ptrToInt(buf), count, flags);
}

pub fn kill(pid: pid_t, sig: i32) usize {
    return syscall2(.kill, @bitCast(usize, @as(isize, pid)), @bitCast(usize, @as(isize, sig)));
}

pub fn tkill(tid: pid_t, sig: i32) usize {
    return syscall2(.tkill, @bitCast(usize, @as(isize, tid)), @bitCast(usize, @as(isize, sig)));
}

pub fn tgkill(tgid: pid_t, tid: pid_t, sig: i32) usize {
    return syscall2(.tgkill, @bitCast(usize, @as(isize, tgid)), @bitCast(usize, @as(isize, tid)), @bitCast(usize, @as(isize, sig)));
}

pub fn unlink(path: [*:0]const u8) usize {
    if (@hasField(SYS, "unlink")) {
        return syscall1(.unlink, @ptrToInt(path));
    } else {
        return syscall3(.unlinkat, @bitCast(usize, @as(isize, AT_FDCWD)), @ptrToInt(path), 0);
    }
}

pub fn unlinkat(dirfd: i32, path: [*:0]const u8, flags: u32) usize {
    return syscall3(.unlinkat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), flags);
}

pub fn waitpid(pid: pid_t, status: *u32, flags: u32) usize {
    return syscall4(.wait4, @bitCast(usize, @as(isize, pid)), @ptrToInt(status), flags, 0);
}

pub fn fcntl(fd: fd_t, cmd: i32, arg: usize) usize {
    return syscall3(.fcntl, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, cmd)), arg);
}

pub fn flock(fd: fd_t, operation: i32) usize {
    return syscall2(.flock, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, operation)));
}

var vdso_clock_gettime = @ptrCast(?*const c_void, init_vdso_clock_gettime);

// We must follow the C calling convention when we call into the VDSO
const vdso_clock_gettime_ty = fn (i32, *timespec) callconv(.C) usize;

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
    return syscall2(.clock_gettime, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
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
    return syscall2(.clock_getres, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
}

pub fn clock_settime(clk_id: i32, tp: *const timespec) usize {
    return syscall2(.clock_settime, @bitCast(usize, @as(isize, clk_id)), @ptrToInt(tp));
}

pub fn gettimeofday(tv: *timeval, tz: *timezone) usize {
    return syscall2(.gettimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn settimeofday(tv: *const timeval, tz: *const timezone) usize {
    return syscall2(.settimeofday, @ptrToInt(tv), @ptrToInt(tz));
}

pub fn nanosleep(req: *const timespec, rem: ?*timespec) usize {
    return syscall2(.nanosleep, @ptrToInt(req), @ptrToInt(rem));
}

pub fn setuid(uid: u32) usize {
    if (@hasField(SYS, "setuid32")) {
        return syscall1(.setuid32, uid);
    } else {
        return syscall1(.setuid, uid);
    }
}

pub fn setgid(gid: u32) usize {
    if (@hasField(SYS, "setgid32")) {
        return syscall1(.setgid32, gid);
    } else {
        return syscall1(.setgid, gid);
    }
}

pub fn setreuid(ruid: u32, euid: u32) usize {
    if (@hasField(SYS, "setreuid32")) {
        return syscall2(.setreuid32, ruid, euid);
    } else {
        return syscall2(.setreuid, ruid, euid);
    }
}

pub fn setregid(rgid: u32, egid: u32) usize {
    if (@hasField(SYS, "setregid32")) {
        return syscall2(.setregid32, rgid, egid);
    } else {
        return syscall2(.setregid, rgid, egid);
    }
}

pub fn getuid() u32 {
    if (@hasField(SYS, "getuid32")) {
        return @as(u32, syscall0(.getuid32));
    } else {
        return @as(u32, syscall0(.getuid));
    }
}

pub fn getgid() u32 {
    if (@hasField(SYS, "getgid32")) {
        return @as(u32, syscall0(.getgid32));
    } else {
        return @as(u32, syscall0(.getgid));
    }
}

pub fn geteuid() u32 {
    if (@hasField(SYS, "geteuid32")) {
        return @as(u32, syscall0(.geteuid32));
    } else {
        return @as(u32, syscall0(.geteuid));
    }
}

pub fn getegid() u32 {
    if (@hasField(SYS, "getegid32")) {
        return @as(u32, syscall0(.getegid32));
    } else {
        return @as(u32, syscall0(.getegid));
    }
}

pub fn seteuid(euid: u32) usize {
    return setreuid(std.math.maxInt(u32), euid);
}

pub fn setegid(egid: u32) usize {
    return setregid(std.math.maxInt(u32), egid);
}

pub fn getresuid(ruid: *u32, euid: *u32, suid: *u32) usize {
    if (@hasField(SYS, "getresuid32")) {
        return syscall3(.getresuid32, @ptrToInt(ruid), @ptrToInt(euid), @ptrToInt(suid));
    } else {
        return syscall3(.getresuid, @ptrToInt(ruid), @ptrToInt(euid), @ptrToInt(suid));
    }
}

pub fn getresgid(rgid: *u32, egid: *u32, sgid: *u32) usize {
    if (@hasField(SYS, "getresgid32")) {
        return syscall3(.getresgid32, @ptrToInt(rgid), @ptrToInt(egid), @ptrToInt(sgid));
    } else {
        return syscall3(.getresgid, @ptrToInt(rgid), @ptrToInt(egid), @ptrToInt(sgid));
    }
}

pub fn setresuid(ruid: u32, euid: u32, suid: u32) usize {
    if (@hasField(SYS, "setresuid32")) {
        return syscall3(.setresuid32, ruid, euid, suid);
    } else {
        return syscall3(.setresuid, ruid, euid, suid);
    }
}

pub fn setresgid(rgid: u32, egid: u32, sgid: u32) usize {
    if (@hasField(SYS, "setresgid32")) {
        return syscall3(.setresgid32, rgid, egid, sgid);
    } else {
        return syscall3(.setresgid, rgid, egid, sgid);
    }
}

pub fn getgroups(size: usize, list: *u32) usize {
    if (@hasField(SYS, "getgroups32")) {
        return syscall2(.getgroups32, size, @ptrToInt(list));
    } else {
        return syscall2(.getgroups, size, @ptrToInt(list));
    }
}

pub fn setgroups(size: usize, list: *const u32) usize {
    if (@hasField(SYS, "setgroups32")) {
        return syscall2(.setgroups32, size, @ptrToInt(list));
    } else {
        return syscall2(.setgroups, size, @ptrToInt(list));
    }
}

pub fn getpid() pid_t {
    return @bitCast(pid_t, @truncate(u32, syscall0(.getpid)));
}

pub fn gettid() pid_t {
    return @bitCast(pid_t, @truncate(u32, syscall0(.gettid)));
}

pub fn sigprocmask(flags: u32, noalias set: ?*const sigset_t, noalias oldset: ?*sigset_t) usize {
    return syscall4(.rt_sigprocmask, flags, @ptrToInt(set), @ptrToInt(oldset), NSIG / 8);
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
        .restorer = @ptrCast(fn () callconv(.C) void, restorer_fn),
    };
    var ksa_old: k_sigaction = undefined;
    const ksa_mask_size = @sizeOf(@TypeOf(ksa_old.mask));
    @memcpy(@ptrCast([*]u8, &ksa.mask), @ptrCast([*]const u8, &act.mask), ksa_mask_size);
    const result = syscall4(.rt_sigaction, sig, @ptrToInt(&ksa), @ptrToInt(&ksa_old), ksa_mask_size);
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
    // shift in musl: s&8*sizeof *set->__bits-1
    const shift = @intCast(u5, s & (usize.bit_count - 1));
    const val = @intCast(u32, 1) << shift;
    (set.*)[@intCast(usize, s) / usize.bit_count] |= val;
}

pub fn sigismember(set: *const sigset_t, sig: u6) bool {
    const s = sig - 1;
    return ((set.*)[@intCast(usize, s) / usize.bit_count] & (@intCast(usize, 1) << (s & (usize.bit_count - 1)))) != 0;
}

pub fn getsockname(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getsockname, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len) });
    }
    return syscall3(.getsockname, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn getpeername(fd: i32, noalias addr: *sockaddr, noalias len: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getpeername, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len) });
    }
    return syscall3(.getpeername, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_socket, &[3]usize{ domain, socket_type, protocol });
    }
    return syscall3(.socket, domain, socket_type, protocol);
}

pub fn setsockopt(fd: i32, level: u32, optname: u32, optval: [*]const u8, optlen: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_setsockopt, &[5]usize{ @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen) });
    }
    return syscall5(.setsockopt, @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @intCast(usize, optlen));
}

pub fn getsockopt(fd: i32, level: u32, optname: u32, noalias optval: [*]u8, noalias optlen: *socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_getsockopt, &[5]usize{ @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen) });
    }
    return syscall5(.getsockopt, @bitCast(usize, @as(isize, fd)), level, optname, @ptrToInt(optval), @ptrToInt(optlen));
}

pub fn sendmsg(fd: i32, msg: *msghdr_const, flags: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_sendmsg, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags });
    }
    return syscall3(.sendmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags);
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
                        const r = syscall4(.sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
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
            const r = syscall4(.sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(&msgvec[next_unsent]), batch_size, flags);
            if (getErrno(r) != 0) return r;
            return next_unsent + r;
        }
        return kvlen;
    }
    return syscall4(.sendmmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msgvec), vlen, flags);
}

pub fn connect(fd: i32, addr: *const c_void, len: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_connect, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), len });
    }
    return syscall3(.connect, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), len);
}

pub fn recvmsg(fd: i32, msg: *msghdr, flags: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_recvmsg, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags });
    }
    return syscall3(.recvmsg, @bitCast(usize, @as(isize, fd)), @ptrToInt(msg), flags);
}

pub fn recvfrom(fd: i32, noalias buf: [*]u8, len: usize, flags: u32, noalias addr: ?*sockaddr, noalias alen: ?*socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_recvfrom, &[6]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen) });
    }
    return syscall6(.recvfrom, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @ptrToInt(alen));
}

pub fn shutdown(fd: i32, how: i32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_shutdown, &[2]usize{ @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, how)) });
    }
    return syscall2(.shutdown, @bitCast(usize, @as(isize, fd)), @bitCast(usize, @as(isize, how)));
}

pub fn bind(fd: i32, addr: *const sockaddr, len: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_bind, &[3]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @intCast(usize, len) });
    }
    return syscall3(.bind, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @intCast(usize, len));
}

pub fn listen(fd: i32, backlog: u32) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_listen, &[2]usize{ @bitCast(usize, @as(isize, fd)), backlog });
    }
    return syscall2(.listen, @bitCast(usize, @as(isize, fd)), backlog);
}

pub fn sendto(fd: i32, buf: [*]const u8, len: usize, flags: u32, addr: ?*const sockaddr, alen: socklen_t) usize {
    if (builtin.arch == .i386) {
        return socketcall(SC_sendto, &[6]usize{ @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen) });
    }
    return syscall6(.sendto, @bitCast(usize, @as(isize, fd)), @ptrToInt(buf), len, flags, @ptrToInt(addr), @intCast(usize, alen));
}

pub fn sendfile(outfd: i32, infd: i32, offset: ?*i64, count: usize) usize {
    if (@hasField(SYS, "sendfile64")) {
        return syscall4(
            .sendfile64,
            @bitCast(usize, @as(isize, outfd)),
            @bitCast(usize, @as(isize, infd)),
            @ptrToInt(offset),
            count,
        );
    } else {
        return syscall4(
            .sendfile,
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
    return syscall4(.socketpair, @intCast(usize, domain), @intCast(usize, socket_type), @intCast(usize, protocol), @ptrToInt(&fd[0]));
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
    return syscall4(.accept4, @bitCast(usize, @as(isize, fd)), @ptrToInt(addr), @ptrToInt(len), flags);
}

pub fn fstat(fd: i32, stat_buf: *Stat) usize {
    if (@hasField(SYS, "fstat64")) {
        return syscall2(.fstat64, @bitCast(usize, @as(isize, fd)), @ptrToInt(stat_buf));
    } else {
        return syscall2(.fstat, @bitCast(usize, @as(isize, fd)), @ptrToInt(stat_buf));
    }
}

pub fn stat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasField(SYS, "stat64")) {
        return syscall2(.stat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(.stat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

pub fn lstat(pathname: [*:0]const u8, statbuf: *Stat) usize {
    if (@hasField(SYS, "lstat64")) {
        return syscall2(.lstat64, @ptrToInt(pathname), @ptrToInt(statbuf));
    } else {
        return syscall2(.lstat, @ptrToInt(pathname), @ptrToInt(statbuf));
    }
}

pub fn fstatat(dirfd: i32, path: [*:0]const u8, stat_buf: *Stat, flags: u32) usize {
    if (@hasField(SYS, "fstatat64")) {
        return syscall4(.fstatat64, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    } else {
        return syscall4(.fstatat, @bitCast(usize, @as(isize, dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), flags);
    }
}

pub fn statx(dirfd: i32, path: [*]const u8, flags: u32, mask: u32, statx_buf: *Statx) usize {
    if (@hasField(SYS, "statx")) {
        return syscall5(
            .statx,
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
    return syscall3(.listxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn llistxattr(path: [*:0]const u8, list: [*]u8, size: usize) usize {
    return syscall3(.llistxattr, @ptrToInt(path), @ptrToInt(list), size);
}

pub fn flistxattr(fd: usize, list: [*]u8, size: usize) usize {
    return syscall3(.flistxattr, fd, @ptrToInt(list), size);
}

pub fn getxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.getxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

pub fn lgetxattr(path: [*:0]const u8, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.lgetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size);
}

pub fn fgetxattr(fd: usize, name: [*:0]const u8, value: [*]u8, size: usize) usize {
    return syscall4(.lgetxattr, fd, @ptrToInt(name), @ptrToInt(value), size);
}

pub fn setxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.setxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn lsetxattr(path: [*:0]const u8, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.lsetxattr, @ptrToInt(path), @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn fsetxattr(fd: usize, name: [*:0]const u8, value: *const void, size: usize, flags: usize) usize {
    return syscall5(.fsetxattr, fd, @ptrToInt(name), @ptrToInt(value), size, flags);
}

pub fn removexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(.removexattr, @ptrToInt(path), @ptrToInt(name));
}

pub fn lremovexattr(path: [*:0]const u8, name: [*:0]const u8) usize {
    return syscall2(.lremovexattr, @ptrToInt(path), @ptrToInt(name));
}

pub fn fremovexattr(fd: usize, name: [*:0]const u8) usize {
    return syscall2(.fremovexattr, fd, @ptrToInt(name));
}

pub fn sched_yield() usize {
    return syscall0(.sched_yield);
}

pub fn sched_getaffinity(pid: pid_t, size: usize, set: *cpu_set_t) usize {
    const rc = syscall3(.sched_getaffinity, @bitCast(usize, @as(isize, pid)), size, @ptrToInt(set));
    if (@bitCast(isize, rc) < 0) return rc;
    if (rc < size) @memset(@ptrCast([*]u8, set) + rc, 0, size - rc);
    return 0;
}

pub fn epoll_create() usize {
    return epoll_create1(0);
}

pub fn epoll_create1(flags: usize) usize {
    return syscall1(.epoll_create1, flags);
}

pub fn epoll_ctl(epoll_fd: i32, op: u32, fd: i32, ev: ?*epoll_event) usize {
    return syscall4(.epoll_ctl, @bitCast(usize, @as(isize, epoll_fd)), @intCast(usize, op), @bitCast(usize, @as(isize, fd)), @ptrToInt(ev));
}

pub fn epoll_wait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32) usize {
    return epoll_pwait(epoll_fd, events, maxevents, timeout, null);
}

pub fn epoll_pwait(epoll_fd: i32, events: [*]epoll_event, maxevents: u32, timeout: i32, sigmask: ?*sigset_t) usize {
    return syscall6(
        .epoll_pwait,
        @bitCast(usize, @as(isize, epoll_fd)),
        @ptrToInt(events),
        @intCast(usize, maxevents),
        @bitCast(usize, @as(isize, timeout)),
        @ptrToInt(sigmask),
        @sizeOf(sigset_t),
    );
}

pub fn eventfd(count: u32, flags: u32) usize {
    return syscall2(.eventfd2, count, flags);
}

pub fn timerfd_create(clockid: i32, flags: u32) usize {
    return syscall2(.timerfd_create, @bitCast(usize, @as(isize, clockid)), flags);
}

pub const itimerspec = extern struct {
    it_interval: timespec,
    it_value: timespec,
};

pub fn timerfd_gettime(fd: i32, curr_value: *itimerspec) usize {
    return syscall2(.timerfd_gettime, @bitCast(usize, @as(isize, fd)), @ptrToInt(curr_value));
}

pub fn timerfd_settime(fd: i32, flags: u32, new_value: *const itimerspec, old_value: ?*itimerspec) usize {
    return syscall4(.timerfd_settime, @bitCast(usize, @as(isize, fd)), flags, @ptrToInt(new_value), @ptrToInt(old_value));
}

pub fn unshare(flags: usize) usize {
    return syscall1(.unshare, flags);
}

pub fn capget(hdrp: *cap_user_header_t, datap: *cap_user_data_t) usize {
    return syscall2(.capget, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub fn capset(hdrp: *cap_user_header_t, datap: *const cap_user_data_t) usize {
    return syscall2(.capset, @ptrToInt(hdrp), @ptrToInt(datap));
}

pub fn sigaltstack(ss: ?*stack_t, old_ss: ?*stack_t) usize {
    return syscall2(.sigaltstack, @ptrToInt(ss), @ptrToInt(old_ss));
}

pub fn uname(uts: *utsname) usize {
    return syscall1(.uname, @ptrToInt(uts));
}

pub fn io_uring_setup(entries: u32, p: *io_uring_params) usize {
    return syscall2(.io_uring_setup, entries, @ptrToInt(p));
}

pub fn io_uring_enter(fd: i32, to_submit: u32, min_complete: u32, flags: u32, sig: ?*sigset_t) usize {
    return syscall6(.io_uring_enter, @bitCast(usize, @as(isize, fd)), to_submit, min_complete, flags, @ptrToInt(sig), NSIG / 8);
}

pub fn io_uring_register(fd: i32, opcode: IORING_REGISTER, arg: ?*const c_void, nr_args: u32) usize {
    return syscall4(.io_uring_register, @bitCast(usize, @as(isize, fd)), @enumToInt(opcode), @ptrToInt(arg), nr_args);
}

pub fn memfd_create(name: [*:0]const u8, flags: u32) usize {
    return syscall2(.memfd_create, @ptrToInt(name), flags);
}

pub fn getrusage(who: i32, usage: *rusage) usize {
    return syscall2(.getrusage, @bitCast(usize, @as(isize, who)), @ptrToInt(usage));
}

pub fn tcgetattr(fd: fd_t, termios_p: *termios) usize {
    return syscall3(.ioctl, @bitCast(usize, @as(isize, fd)), TCGETS, @ptrToInt(termios_p));
}

pub fn tcsetattr(fd: fd_t, optional_action: TCSA, termios_p: *const termios) usize {
    return syscall3(.ioctl, @bitCast(usize, @as(isize, fd)), TCSETS + @enumToInt(optional_action), @ptrToInt(termios_p));
}

pub fn ioctl(fd: fd_t, request: u32, arg: usize) usize {
    return syscall3(.ioctl, @bitCast(usize, @as(isize, fd)), request, arg);
}

pub fn signalfd4(fd: fd_t, mask: *const sigset_t, flags: i32) usize {
    return syscall4(
        .signalfd4,
        @bitCast(usize, @as(isize, fd)),
        @ptrToInt(mask),
        @bitCast(usize, @as(usize, NSIG / 8)),
        @intCast(usize, flags),
    );
}

pub fn copy_file_range(fd_in: fd_t, off_in: ?*i64, fd_out: fd_t, off_out: ?*i64, len: usize, flags: u32) usize {
    return syscall6(
        .copy_file_range,
        @bitCast(usize, @as(isize, fd_in)),
        @ptrToInt(off_in),
        @bitCast(usize, @as(isize, fd_out)),
        @ptrToInt(off_out),
        len,
        flags,
    );
}

test "" {
    if (builtin.os.tag == .linux) {
        _ = @import("linux/test.zig");
    }
}

pub const bpf = struct {
    /// a single BPF instruction
    pub const Insn = packed struct {
        code: u8,
        dst: u4,
        src: u4,
        off: i16,
        imm: i32,

        /// r0 - r9 are general purpose 64-bit registers, r10 points to the stack
        /// frame
        pub const Reg = enum(u4) {
            r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10
        };

        const alu = 0x04;
        const jmp = 0x05;
        const mov = 0xb0;
        const k = 0;
        const exit_code = 0x90;

        // TODO: implement more factory functions for the other instructions
        /// load immediate value into a register
        pub fn load_imm(dst: Reg, imm: i32) Insn {
            return Insn{
                .code = alu | mov | k,
                .dst = @enumToInt(dst),
                .src = 0,
                .off = 0,
                .imm = imm,
            };
        }

        /// exit BPF program
        pub fn exit() Insn {
            return Insn{
                .code = jmp | exit_code,
                .dst = 0,
                .src = 0,
                .off = 0,
                .imm = 0,
            };
        }
    };

    /// flags for how to update a BPF map
    pub const MapUpdateFlags = enum(u64) {
        /// create new element of update existing
        any = 0,
        /// create new element if it didn't exist
        no_exist = 1,
        /// update existing element
        exist = 2,
    };

    pub const MapCreateFlags = enum(u32) {
        no_prealloc = 1 << 0,
        /// Instead of having one common LRU list in the
        /// BPF_MAP_TYPE_LRU_[PERCPU_]HASH map, use a percpu LRU list which can
        /// scale and perform better.  Note, the LRU nodes (including free
        /// nodes) cannot be moved across different LRU lists.
        no_common_lru = 1 << 1,
        /// specify numa node during map creation
        numa_node = 1 << 2,
        /// flags for accessing BPF object from syscall side
        rdonly = 1 << 3,
        wronly = 1 << 4,
        /// flag for stack_map, store build_id+offset instead of pointer
        stack_build_id = 1 << 5,
        /// zero-initialize hash function seed. This should only be used for
        /// testing
        zero_seed = 1 << 6,
        /// flags for accessing BPF object from program side
        rdonly_prog = 1 << 7,
        wronly_prog = 1 << 8,
        /// Clone map from listener for newly accepted socket
        clone = 1 << 9,
        /// Enable memory-mapping BPF map
        mmapable = 1 << 10,
    };

    pub const ProgQueryFlags = enum(64) {
        /// Query effective (directly attached + inherited from ancestor
        /// cgroups) programs that will be executed for events within a cgroup.
        /// attach_flags with this flag are returned only for directly attached
        /// programs.
        effective = 1,
    };

    pub const MapType = enum(u32) {
        unspec,
        hash,
        array,
        prog_array,
        perf_event_array,
        percpu_hash,
        percpu_array,
        stack_trace,
        cgroup_array,
        lru_hash,
        lru_percpu_hash,
        lpm_trie,
        array_of_maps,
        hash_of_maps,
        devmap,
        sockmap,
        cpumap,
        xskmap,
        sockhash,
        cgroup_storage,
        reuseport_sockarray,
        percpu_cgroup_storage,
        queue,
        stack,
        sk_storage,
        devmap_hash,
        struct_ops,
        ringbuf,
    };

    pub const AttachType = enum(u32) {
        cgroup_inet_ingress,
        cgroup_inet_egress,
        cgroup_inet_sock_create,
        cgroup_sock_ops,
        sk_skb_stream_parser,
        sk_skb_stream_verdict,
        cgroup_device,
        sk_msg_verdict,
        cgroup_inet4_bind,
        cgroup_inet6_bind,
        cgroup_inet4_connect,
        cgroup_inet6_connect,
        cgroup_inet4_post_bind,
        cgroup_inet6_post_bind,
        cgroup_udp4_sendmsg,
        cgroup_udp6_sendmsg,
        lirc_mode2,
        flow_dissector,
        cgroup_sysctl,
        cgroup_udp4_recvmsg,
        cgroup_udp6_recvmsg,
        cgroup_getsockopt,
        cgroup_setsockopt,
        trace_raw_tp,
        trace_fentry,
        trace_fexit,
        modify_return,
        lsm_mac,
        trace_iter,
        cgroup_inet4_getpeername,
        cgroup_inet6_getpeername,
        cgroup_inet4_getsockname,
        cgroup_inet6_getsockname,
        xdp_devmap,
    };

    pub const Cmd = enum(usize) {
        map_create,
        map_lookup_elem,
        map_update_elem,
        map_delete_elem,
        map_get_next_key,
        prog_load,
        obj_pin,
        obj_get,
        prog_attach,
        prog_detach,
        prog_test_run,
        prog_get_next_id,
        map_get_next_id,
        prog_get_fd_by_id,
        map_get_fd_by_id,
        obj_get_info_by_fd,
        prog_query,
        raw_tracepoint_open,
        btf_load,
        btf_get_fd_by_id,
        task_fd_query,
        map_lookup_and_delete_elem,
        map_freeze,
        btf_get_next_id,
        map_lookup_batch,
        map_lookup_and_delete_batch,
        map_update_batch,
        map_delete_batch,
        link_create,
        link_update,
        link_get_fd_by_id,
        link_get_next_id,
        enable_stats,
        iter_create,
    };

    const obj_name_len = 16;
    /// struct used by Cmd.map_create command
    pub const MapCreateAttr = extern struct {
        /// one of MapType
        map_type: u32,
        /// size of key in bytes
        key_size: u32,
        /// size of value in bytes
        value_size: u32,
        /// max number of entries in a map
        max_entries: u32,
        /// .map_create related flags
        map_flags: u32,
        /// fd pointing to the inner map
        inner_map_fd: u32,
        /// numa node (effective only if MapCreateFlags.numa_node is set)
        numa_node: u32,
        map_name: [obj_name_len]u8,
        /// ifindex of netdev to create on
        map_ifindex: u32,
        /// fd pointing to a BTF type data
        btf_fd: u32,
        /// BTF type_id of the key
        btf_key_type_id: u32,
        /// BTF type_id of the value
        bpf_value_type_id: u32,
        /// BTF type_id of a kernel struct stored as the map value
        btf_vmlinux_value_type_id: u32,
    };

    /// struct used by Cmd.map_*_elem commands
    pub const MapElemAttr = extern struct {
        map_fd: u32,
        key: u64,
        result: extern union {
            value: u64,
            next_key: u64,
        },
        flags: u64,
    };

    /// struct used by Cmd.map_*_batch commands
    pub const MapBatchAttr = extern struct {
        /// start batch, NULL to start from beginning
        in_batch: u64,
        /// output: next start batch
        out_batch: u64,
        keys: u64,
        values: u64,
        /// input/output:
        /// input: # of key/value elements
        /// output: # of filled elements
        count: u32,
        map_fd: u32,
        elem_flags: u64,
        flags: u64,
    };

    /// struct used by Cmd.prog_load command
    pub const ProgLoadAttr = extern struct {
        /// one of ProgType
        prog_type: u32,
        insn_cnt: u32,
        insns: u64,
        license: u64,
        /// verbosity level of verifier
        log_level: u32,
        /// size of user buffer
        log_size: u32,
        /// user supplied buffer
        log_buf: u64,
        /// not used
        kern_version: u32,
        prog_flags: u32,
        prog_name: [obj_name_len]u8,
        /// ifindex of netdev to prep for. For some prog types expected attach
        /// type must be known at load time to verify attach type specific parts
        /// of prog (context accesses, allowed helpers, etc).
        prog_ifindex: u32,
        expected_attach_type: u32,
        /// fd pointing to BTF type data
        prog_btf_fd: u32,
        /// userspace bpf_func_info size
        func_info_rec_size: u32,
        func_info: u64,
        /// number of bpf_func_info records
        func_info_cnt: u32,
        /// userspace bpf_line_info size
        line_info_rec_size: u32,
        line_info: u64,
        /// number of bpf_line_info records
        line_info_cnt: u32,
        /// in-kernel BTF type id to attach to
        attact_btf_id: u32,
        /// 0 to attach to vmlinux
        attach_prog_id: u32,
    };

    /// struct used by Cmd.obj_* commands
    pub const ObjAttr = extern struct {
        pathname: u64,
        bpf_fd: u32,
        file_flags: u32,
    };

    /// struct used by Cmd.prog_attach/detach commands
    pub const ProgAttachAttr = extern struct {
        /// container object to attach to
        target_fd: u32,
        /// eBPF program to attach
        attach_bpf_fd: u32,
        attach_type: u32,
        attach_flags: u32,
        // TODO: BPF_F_REPLACE flags
        /// previously attached eBPF program to replace if .replace is used
        replace_bpf_fd: u32,
    };

    /// struct used by Cmd.prog_test_run command
    pub const TestAttr = extern struct {
        prog_fd: u32,
        retval: u32,
        /// input: len of data_in
        data_size_in: u32,
        /// input/output: len of data_out. returns ENOSPC if data_out is too small.
        data_size_out: u32,
        data_in: u64,
        data_out: u64,
        repeat: u32,
        duration: u32,
        /// input: len of ctx_in
        ctx_size_in: u32,
        /// input/output: len of ctx_out. returns ENOSPC if ctx_out is too small.
        ctx_size_out: u32,
        ctx_in: u64,
        ctx_out: u64,
    };

    /// struct used by Cmd.*_get_*_id commands
    pub const GetIdAttr = extern struct {
        id: extern union {
            start_id: u32,
            prog_id: u32,
            map_id: u32,
            btf_id: u32,
            link_id: u32,
        },
        next_id: u32,
        open_flags: u32,
    };

    /// struct used by Cmd.obj_get_info_by_fd command
    pub const InfoAttr = extern struct {
        bpf_fd: u32,
        info_len: u32,
        info: u64,
    };

    /// struct used by Cmd.prog_query command
    pub const QueryAttr = extern struct {
        /// container object to query
        target_fd: u32,
        attach_type: u32,
        query_flags: u32,
        attach_flags: u32,
        prog_ids: u64,
        prog_cnt: u32,
    };

    /// struct used by Cmd.raw_tracepoint_open command
    pub const RawTracepointAttr = extern struct {
        name: u64,
        prog_fd: u32,
    };

    /// struct used by Cmd.btf_load command
    pub const BtfLoadAttr = extern struct {
        btf: u64,
        btf_log_buf: u64,
        btf_size: u32,
        btf_log_size: u32,
        btf_log_level: u32,
    };

    pub const TaskFdQueryAttr = extern struct {
        /// input: pid
        pid: u32,
        /// input: fd
        fd: u32,
        /// input: flags
        flags: u32,
        /// input/output: buf len
        buf_len: u32,
        /// input/output:
        ///     tp_name for tracepoint
        ///     symbol for kprobe
        ///     filename for uprobe
        buf: u64,
        /// output: prod_id
        prog_id: u32,
        /// output: BPF_FD_TYPE
        fd_type: u32,
        /// output: probe_offset
        probe_offset: u64,
        /// output: probe_addr
        probe_addr: u64,
    };

    /// struct used by Cmd.link_create command
    pub const LinkCreateAttr = extern struct {
        /// eBPF program to attach
        prog_fd: u32,
        /// object to attach to
        target_fd: u32,
        attach_type: u32,
        /// extra flags
        flags: u32,
    };

    /// struct used by Cmd.link_update command
    pub const LinkUpdateAttr = extern struct {
        link_fd: u32,
        /// new program to update link with
        new_prog_fd: u32,
        /// extra flags
        flags: u32,
        /// expected link's program fd, it is specified only if BPF_F_REPLACE is
        /// set in flags
        old_prog_fd: u32,
    };

    /// struct used by Cmd.enable_stats command
    pub const EnableStatsAttr = extern struct {
        type: u32,
    };

    /// struct used by Cmd.iter_create command
    pub const IterCreateAttr = extern struct {
        link_fd: u32,
        flags: u32,
    };

    pub const Attr = extern union {
        map_create: MapCreateAttr,
        map_elem: MapElemAttr,
        map_batch: MapBatchAttr,
        prog_load: ProgLoadAttr,
        obj: ObjAttr,
        prog_attach: ProgAttachAttr,
        test_run: TestRunAttr,
        get_id: GetIdAttr,
        info: InfoAttr,
        query: QueryAttr,
        raw_tracepoint: RawTracepointAttr,
        btf_load: BtfLoadAttr,
        task_fd_query: TaskFdQueryAttr,
        link_create: LinkCreateAttr,
        link_update: LinkUpdateAttr,
        enable_stats: EnableStatsAttr,
        iter_create: IterCreateAttr,
    };

    pub fn bpf(cmd: Cmd, attr: *Attr, size: u32) usize {
        return syscall3(.bpf, @enumToInt(cmd), @ptrToInt(attr), size);
    }
};
