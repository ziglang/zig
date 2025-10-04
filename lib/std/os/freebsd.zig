const std = @import("../std.zig");
const fd_t = std.c.fd_t;
const off_t = std.c.off_t;
const unexpectedErrno = std.posix.unexpectedErrno;
const errno = std.posix.errno;
const builtin = @import("builtin");

pub const CopyFileRangeError = std.posix.UnexpectedError || error{
    /// If infd is not open for reading or outfd is not open for writing, or
    /// opened for writing with O_APPEND, or if infd and outfd refer to the
    /// same file.
    BadFileFlags,
    /// If the copy exceeds the process's file size limit or the maximum
    /// file size for the file system outfd  re- sides on.
    FileTooBig,
    /// A signal interrupted the system call before it could be completed.
    /// This may happen for files on some NFS mounts.  When this happens,
    /// the values pointed to by inoffp  and  outoffp are reset to the
    /// initial values for the system call.
    Interrupted,
    /// One of:
    /// * infd and outfd refer to the same file and  the  byte ranges overlap.
    /// * The flags argument is not zero.
    /// * Either infd or outfd refers to a file object that is not a regular file.
    InvalidArguments,
    /// An  I/O  error  occurred  while  reading/writing the files.
    InputOutput,
    /// Corrupted data was detected  while  reading  from  a file system.
    CorruptedData,
    /// Either infd or outfd refers to a directory.
    IsDir,
    /// File system that stores outfd is full.
    NoSpaceLeft,
};

pub fn copy_file_range(fd_in: fd_t, off_in: ?*i64, fd_out: fd_t, off_out: ?*i64, len: usize, flags: u32) CopyFileRangeError!usize {
    const rc = std.c.copy_file_range(fd_in, off_in, fd_out, off_out, len, flags);
    switch (errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .BADF => return error.BadFileFlags,
        .FBIG => return error.FileTooBig,
        .INTR => return error.Interrupted,
        .INVAL => return error.InvalidArguments,
        .IO => return error.InputOutput,
        .INTEGRITY => return error.CorruptedData,
        .ISDIR => return error.IsDir,
        .NOSPC => return error.NoSpaceLeft,
        else => |err| return unexpectedErrno(err),
    }
}

pub const ucontext_t = extern struct {
    sigmask: std.c.sigset_t,
    mcontext: mcontext_t,
    link: ?*ucontext_t,
    stack: std.c.stack_t,
    flags: c_int,
    __spare__: [4]c_int,
    const mcontext_t = switch (builtin.cpu.arch) {
        .x86_64 => extern struct {
            onstack: u64,
            rdi: u64,
            rsi: u64,
            rdx: u64,
            rcx: u64,
            r8: u64,
            r9: u64,
            rax: u64,
            rbx: u64,
            rbp: u64,
            r10: u64,
            r11: u64,
            r12: u64,
            r13: u64,
            r14: u64,
            r15: u64,
            trapno: u32,
            fs: u16,
            gs: u16,
            addr: u64,
            flags: u32,
            es: u16,
            ds: u16,
            err: u64,
            rip: u64,
            cs: u64,
            rflags: u64,
            rsp: u64,
            ss: u64,
            len: u64,
            fpformat: u64,
            ownedfp: u64,
            fpstate: [64]u64 align(16),
            fsbase: u64,
            gsbase: u64,
            xfpustate: u64,
            xfpustate_len: u64,
            spare: [4]u64,
        },
        .aarch64 => extern struct {
            gpregs: extern struct {
                x: [30]u64,
                lr: u64,
                sp: u64,
                elr: u64,
                spsr: u32,
                _pad: u32,
            },
            fpregs: extern struct {
                q: [32]u128,
                sr: u32,
                cr: u32,
                flags: u32,
                _pad: u32,
            },
            flags: u32,
            _pad: u32,
            _spare: [8]u64,
        },
        else => void,
    };
};
