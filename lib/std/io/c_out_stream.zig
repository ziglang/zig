const std = @import("../std.zig");
const os = std.os;
const OutStream = std.io.OutStream;
const builtin = @import("builtin");

/// TODO make a proposal to make `std.fs.File` use *FILE when linking libc and this just becomes
/// std.io.FileOutStream because std.fs.File.write would do this when linking
/// libc.
pub const COutStream = struct {
    pub const Error = std.fs.File.WriteError;
    pub const Stream = OutStream(Error);

    stream: Stream,
    c_file: *std.c.FILE,

    pub fn init(c_file: *std.c.FILE) COutStream {
        return COutStream{
            .c_file = c_file,
            .stream = Stream{ .writeFn = writeFn },
        };
    }

    fn writeFn(out_stream: *Stream, bytes: []const u8) Error!void {
        const self = @fieldParentPtr(COutStream, "stream", out_stream);
        const amt_written = std.c.fwrite(bytes.ptr, 1, bytes.len, self.c_file);
        if (amt_written == bytes.len) return;
        switch (std.c.getErrno(-1)) {
            @intToEnum(os.Errno, 0) => unreachable,
            .EINVAL => unreachable,
            .EFAULT => unreachable,
            .EAGAIN => unreachable, // this is a blocking API
            .EBADF => unreachable, // always a race condition
            .EDESTADDRREQ => unreachable, // connect was never called
            .EDQUOT => return error.DiskQuota,
            .EFBIG => return error.FileTooBig,
            .EIO => return error.InputOutput,
            .ENOSPC => return error.NoSpaceLeft,
            .EPERM => return error.AccessDenied,
            .EPIPE => return error.BrokenPipe,
            else => |err| return os.unexpectedErrno(err),
        }
    }
};
