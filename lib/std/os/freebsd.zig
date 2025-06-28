const std = @import("../std.zig");
const fd_t = std.c.fd_t;
const off_t = std.c.off_t;
const unexpectedErrno = std.posix.unexpectedErrno;
const errno = std.posix.errno;

pub const CopyFileRangeError = error{
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
