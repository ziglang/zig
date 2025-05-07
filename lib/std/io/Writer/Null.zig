//! A `Writer` that discards all data.

const std = @import("../../std.zig");
const Writer = std.io.Writer;

const NullWriter = @This();

err: ?Error = null,

pub const Error = std.fs.File.StatError;

pub fn writer(nw: *NullWriter) Writer {
    return .{
        .context = nw,
        .vtable = &.{
            .writeSplat = writeSplat,
            .writeFile = writeFile,
        },
    };
}

fn writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Writer.Error!usize {
    _ = context;
    const headers = data[0 .. data.len - 1];
    const pattern = data[headers.len..];
    var written: usize = pattern.len * splat;
    for (headers) |bytes| written += bytes.len;
    return written;
}

fn writeFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: Writer.Offset,
    limit: Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Writer.FileError!usize {
    const nw: *NullWriter = @alignCast(@ptrCast(context));
    var n: usize = 0;
    if (offset == .none) {
        @panic("TODO seek the file forwards");
    }
    const limit_int = limit.toInt() orelse {
        const headers = headers_and_trailers[0..headers_len];
        for (headers) |bytes| n += bytes.len;
        if (offset.toInt()) |off| {
            const stat = file.stat() catch |err| {
                nw.err = err;
                return error.WriteFailed;
            };
            n += stat.size - off;
            for (headers_and_trailers[headers_len..]) |bytes| n += bytes.len;
            return n;
        }
        @panic("TODO stream from file until eof, counting");
    };
    for (headers_and_trailers) |bytes| n += bytes.len;
    return limit_int + n;
}

test "writing a small string" {
    var nw: NullWriter = undefined;
    var bw = nw.writer().unbuffered();
    try bw.writeAll("yay");
}
