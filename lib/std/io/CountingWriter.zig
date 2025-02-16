const std = @import("../std.zig");
const CountingWriter = @This();
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();
const Writer = std.io.Writer;
const testing = std.testing;

/// Underlying stream to passthrough bytes to.
child_writer: Writer,
bytes_written: u64 = 0,

pub fn writer(cw: *CountingWriter) Writer {
    return .{
        .context = cw,
        .vtable = &.{
            .writev = passthru_writev,
            .splat = passthru_splat,
            .writeFile = passthru_writeFile,
        },
    };
}

pub fn unbufferedWriter(cw: *CountingWriter) std.io.BufferedWriter {
    return .{
        .buffer = &.{},
        .unbuffered_writer = writer(cw),
    };
}

fn passthru_writev(context: *anyopaque, data: []const []const u8) anyerror!usize {
    const cw: *CountingWriter = @alignCast(@ptrCast(context));
    const written = try cw.child_writer.writev(data);
    cw.bytes_written += written;
    return written;
}

fn passthru_splat(context: *anyopaque, header: []const u8, pattern: []const u8, n: usize) anyerror!usize {
    const cw: *CountingWriter = @alignCast(@ptrCast(context));
    const written = try cw.child_writer.splat(header, pattern, n);
    cw.bytes_written += written;
    return written;
}

fn passthru_writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: Writer.VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    const cw: *CountingWriter = @alignCast(@ptrCast(context));
    const written = try cw.child_writer.writeFile(file, offset, len, headers_and_trailers, headers_len);
    cw.bytes_written += written;
    return written;
}

test CountingWriter {
    var cw: CountingWriter = .{ .child_writer = std.io.null_writer };
    var bw = cw.unbufferedWriter();
    const bytes = "yay";
    try bw.writeAll(bytes);
    try testing.expect(cw.bytes_written == bytes.len);
}
