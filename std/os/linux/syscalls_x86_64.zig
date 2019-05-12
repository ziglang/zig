use @import("x86_64.zig");
const std = @import("../../std.zig");
const linux = std.os.linux;
const sockaddr = linux.sockaddr;
const socklen_t = linux.socklen_t;
const iovec = linux.iovec;
const iovec_const = linux.iovec_const;
const sigset_t = linux.sigset_t;

pub fn mmap(address: ?[*]u8, length: usize, prot: usize, flags: u32, fd: i32, offset: usize) usize {
    return syscall6(SYS_mmap, @ptrToInt(address), length, prot, usize(flags), @bitCast(usize, isize(fd)), offset);
}

pub fn mprotect(address: usize, length: usize, protection: usize) usize {
    return syscall3(SYS_mprotect, address, length, protection);
}

pub fn munmap(address: usize, length: usize) usize {
    return syscall2(SYS_munmap, address, length);
}

pub fn openat(dirfd: i32, path: [*]const u8, flags: u32, mode: usize) usize {
    return syscall4(SYS_openat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), usize(flags), mode);
}

pub fn creat(path: [*]const u8, perm: usize) usize {
    return syscall2(SYS_creat, @ptrToInt(path), perm);
}

pub fn read(fd: i32, buf: [*]u8, count: usize) usize {
    return syscall3(SYS_read, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn write(fd: i32, buf: [*]const u8, count: usize) usize {
    return syscall3(SYS_write, @bitCast(usize, isize(fd)), @ptrToInt(buf), count);
}

pub fn close(fd: i32) usize {
    return syscall1(SYS_close, @bitCast(usize, isize(fd)));
}

pub fn ioctl(fd: i32, ctl: i32, arg: usize) usize {
    return syscall3(SYS_ioctl, @bitCast(usize, isize(fd)), @bitCast(usize, isize(ctl)), arg);
}

pub fn readlinkat(dirfd: i32, path: [*]const u8, buf_ptr: [*]u8, buf_len: usize) usize {
    return syscall4(SYS_readlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(buf_ptr), buf_len);
}

pub fn mkdirat(dirfd: i32, path: [*]const u8, mode: u32) usize {
    return syscall3(SYS_mkdirat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), usize(mode));
}

pub fn symlinkat(existing: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    return syscall3(SYS_symlinkat, @ptrToInt(existing), @bitCast(usize, isize(newfd)), @ptrToInt(newpath));
}

pub fn faccessat(dirfd: i32, path: [*]const u8, mode: u32) usize {
    return syscall3(SYS_faccessat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), usize(mode));
}

pub fn renameat(oldfd: i32, oldpath: [*]const u8, newfd: i32, newpath: [*]const u8) usize {
    return syscall4(SYS_renameat, @bitCast(usize, isize(oldfd)), @ptrToInt(oldpath), @bitCast(usize, isize(newfd)), @ptrToInt(newpath));
}

pub fn unlinkat(dirfd: i32, path: [*]const u8, flags: u32) usize {
    return syscall3(SYS_unlinkat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), usize(flags));
}

pub fn fstatat(dirfd: i32, path: [*]const u8, stat_buf: *Stat, flags: u32) usize {
    return syscall4(SYS_fstatat, @bitCast(usize, isize(dirfd)), @ptrToInt(path), @ptrToInt(stat_buf), usize(flags));
}

pub fn lseek(fd: i32, offset: i64, whence: usize) usize {
    return syscall5(SYS_lseek, @bitCast(usize, isize(fd)), 0, @truncate(usize, @bitCast(u64, offset) >> 32), @truncate(usize, @bitCast(u64, offset)), whence);
}

pub fn pread(fd: i32, buf: [*]u8, count: usize, offset: i64) usize {
    return syscall6(SYS_pread, @bitCast(usize, isize(fd)), @ptrToInt(buf), count, 0, @truncate(usize, @bitCast(u64, offset) >> 32), @truncate(usize, @bitCast(u64, offset)));
}

pub fn readv(fd: i32, iov: [*]const iovec, count: usize) usize {
    return syscall3(SYS_readv, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn writev(fd: i32, iov: [*]const iovec_const, count: usize) usize {
    return syscall3(SYS_writev, @bitCast(usize, isize(fd)), @ptrToInt(iov), count);
}

pub fn preadv(fd: i32, iov: [*]const iovec, count: usize, offset: u64) usize {
    return syscall6(SYS_preadv, @bitCast(usize, isize(fd)), @ptrToInt(iov), count, 0, @truncate(usize, offset >> 32), @truncate(usize, offset));
}

pub fn pwritev(fd: i32, iov: [*]const iovec_const, count: usize, offset: u64) usize {
    return syscall6(SYS_pwritev, @bitCast(usize, isize(fd)), @ptrToInt(iov), count, 0, @truncate(usize, offset >> 32), @truncate(usize, offset));
}

pub fn chdir(path: [*]const u8) usize {
    return syscall1(SYS_chdir, @ptrToInt(path));
}

pub fn chroot(path: [*]const u8) usize {
    return syscall1(SYS_chroot, @ptrToInt(path));
}

pub fn getcwd(path: [*]const u8, size: usize) usize {
    return syscall2(SYS_getcwd, @ptrToInt(path), size);
}

pub fn getdents64(fd: i32, dirp: [*]u8, count: usize) usize {
    return syscall3(SYS_getdents64, @bitCast(usize, isize(fd)), @ptrToInt(dirp), count);
}

pub fn futex4(uaddr: *const i32, futex_op: i32, val: i32, timeout: ?*timespec) usize {
    return syscall4(SYS_futex, @ptrToInt(uaddr), @bitCast(usize, isize(futex_op)), @bitCast(usize, isize(val)), @ptrToInt(timeout));
}

pub fn getrandom(buf: [*]u8, count: usize, flags: u32) usize {
    return syscall3(SYS_getrandom, @ptrToInt(buf), count, usize(flags));
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

pub fn rt_sigprocmask(how: i32, set: *const sigset_t, oldset: ?*sigset_t, sigsetsize: usize) usize {
    return syscall4(SYS_rt_sigprocmask, @bitCast(usize, isize(how)), @ptrToInt(set), @ptrToInt(oldset), sigsetsize);
}

pub fn getgid() u32 {
    return @truncate(u32, syscall0(SYS_getgid));
}

pub fn getpid() i32 {
    return @bitCast(i32, @truncate(u32, syscall0(SYS_getpid)));
}

pub fn dup3(oldfd: i32, newfd: i32, flags: i32) usize {
    return syscall3(SYS_dup3, @bitCast(usize, isize(oldfd)), @bitCast(usize, isize(newfd)), @bitCast(usize, isize(flags)));
}

pub fn pipe2(fd: *[2]i32, flags: u32) usize {
    return syscall2(SYS_pipe2, @ptrToInt(fd), usize(flags));
}

pub fn clone5(flags: u32, child_stack_ptr: usize, parent_tid: *i32, child_tid: *i32, newtls: usize) usize {
    return syscall5(SYS_clone, usize(flags), child_stack_ptr, @ptrToInt(parent_tid), @ptrToInt(child_tid), newtls);
}

pub fn clone2(flags: u32, child_stack_ptr: usize) usize {
    return syscall2(SYS_clone, usize(flags), child_stack_ptr);
}

pub fn execve(path: [*]const u8, argv: [*]const ?[*]const u8, envp: [*]const ?[*]const u8) usize {
    return syscall3(SYS_execve, @ptrToInt(path), @ptrToInt(argv), @ptrToInt(envp));
}

pub fn kill(pid: i32, sig: i32) usize {
    return syscall2(SYS_kill, @bitCast(usize, isize(pid)), @bitCast(usize, isize(sig)));
}

pub fn wait4(pid: i32, status: *i32, options: i32, rusage: usize) usize {
    return syscall4(SYS_wait4, @bitCast(usize, isize(pid)), @ptrToInt(status), @bitCast(usize, isize(options)), rusage);
}

pub fn exit(status: i32) noreturn {
    _ = syscall1(SYS_exit, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn exit_group(status: i32) noreturn {
    _ = syscall1(SYS_exit_group, @bitCast(usize, isize(status)));
    unreachable;
}

pub fn inotify_init1(flags: u32) usize {
    return syscall1(SYS_inotify_init1, usize(flags));
}

pub fn inotify_add_watch(fd: i32, pathname: [*]const u8, mask: u32) usize {
    return syscall3(SYS_inotify_add_watch, @bitCast(usize, isize(fd)), @ptrToInt(pathname), usize(mask));
}

pub fn inotify_rm_watch(fd: i32, wd: i32) usize {
    return syscall2(SYS_inotify_rm_watch, @bitCast(usize, isize(fd)), @bitCast(usize, isize(wd)));
}

pub fn arch_prctl(code: i32, addr: usize) usize {
    return syscall2(SYS_arch_prctl, @bitCast(usize, isize(code)), addr);
}

