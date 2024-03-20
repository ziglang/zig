const std = @import("../std.zig");
const builtin = @import("builtin");
const io = std.io;
const testing = std.testing;

pub const CWriter = io.Writer(*std.c.FILE, std.fs.File.WriteError, cWriterWrite);

pub fn cWriter(c_file: *std.c.FILE) CWriter {
    return .{ .context = c_file };
}

fn cWriterWrite(c_file: *std.c.FILE, bytes: []const u8) std.fs.File.WriteError!usize {
    const amt_written = std.c.fwrite(bytes.ptr, 1, bytes.len, c_file);
    if (amt_written >= 0) return amt_written;
    switch (@as(std.c.E, @enumFromInt(std.c._errno().*))) {
        .SUCCESS => unreachable,
        .INVAL => unreachable,
        .FAULT => unreachable,
        .AGAIN => unreachable, // this is a blocking API
        .BADF => unreachable, // always a race condition
        .DESTADDRREQ => unreachable, // connect was never called
        .DQUOT => return error.DiskQuota,
        .FBIG => return error.FileTooBig,
        .IO => return error.InputOutput,
        .NOSPC => return error.NoSpaceLeft,
        .PERM => return error.AccessDenied,
        .PIPE => return error.BrokenPipe,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}

test cWriter {
    if (!builtin.link_libc or builtin.os.tag == .wasi) return error.SkipZigTest;

    const filename = "tmp_io_test_file.txt";
    const out_file = std.c.fopen(filename, "w") orelse return error.UnableToOpenTestFile;
    defer {
        _ = std.c.fclose(out_file);
        std.fs.cwd().deleteFileZ(filename) catch {};
    }

    const writer = cWriter(out_file);
    try writer.print("hi: {}\n", .{@as(i32, 123)});
}
