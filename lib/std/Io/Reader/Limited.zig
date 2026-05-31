const Limited = @This();

const std = @import("../../std.zig");
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Limit = std.Io.Limit;

unlimited: *Reader,
remaining: Limit,
interface: Reader,

pub fn init(reader: *Reader, limit: Limit, buffer: []u8) Limited {
    return .{
        .unlimited = reader,
        .remaining = limit,
        .interface = .{
            .vtable = &.{
                .stream = stream,
                .discard = discard,
            },
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        },
    };
}

fn stream(r: *Reader, w: *Writer, limit: Limit) Reader.StreamError!usize {
    const l: *Limited = @fieldParentPtr("interface", r);
    if (l.remaining == .nothing) return error.EndOfStream;
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited.stream(w, combined_limit);
    l.remaining = l.remaining.subtract(n).?;
    return n;
}

test stream {
    var orig_buf: [10]u8 = undefined;
    @memcpy(&orig_buf, "test bytes");
    var fixed: std.Io.Reader = .fixed(&orig_buf);

    var limit_buf: [1]u8 = undefined;
    var limited: std.Io.Reader.Limited = .init(&fixed, @enumFromInt(4), &limit_buf);

    var result_buf: [10]u8 = undefined;
    var fixed_writer: std.Io.Writer = .fixed(&result_buf);
    const streamed = try limited.interface.stream(&fixed_writer, @enumFromInt(7));

    try std.testing.expect(streamed == 4);
    try std.testing.expectEqualStrings("test", result_buf[0..streamed]);
}

fn discard(r: *Reader, limit: Limit) Reader.Error!usize {
    const l: *Limited = @fieldParentPtr("interface", r);
    if (l.remaining == .nothing) return error.EndOfStream;
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited.discard(combined_limit);
    l.remaining = l.remaining.subtract(n).?;
    return n;
}

test "end of stream, read, hit limit exactly" {
    var f: Reader = .fixed("i'm dying");
    var l = f.limited(.limited(4), &.{});
    const r = &l.interface;

    var buf: [2]u8 = undefined;
    try r.readSliceAll(&buf);
    try r.readSliceAll(&buf);
    try std.testing.expectError(error.EndOfStream, l.interface.readSliceAll(&buf));
}

test "end of stream, read, hit limit after partial read" {
    var f: Reader = .fixed("i'm dying");
    var l = f.limited(.limited(5), &.{});
    const r = &l.interface;

    var buf: [2]u8 = undefined;
    try r.readSliceAll(&buf);
    try r.readSliceAll(&buf);
    try std.testing.expectError(error.EndOfStream, l.interface.readSliceAll(&buf));
}

test "end of stream, discard, hit limit exactly" {
    var f: Reader = .fixed("i'm dying");
    var l = f.limited(.limited(4), &.{});
    const r = &l.interface;

    try r.discardAll(2);
    try r.discardAll(2);
    try std.testing.expectError(error.EndOfStream, l.interface.discardAll(2));
}

test "end of stream, discard, hit limit after partial read" {
    var f: Reader = .fixed("i'm dying");
    var l = f.limited(.limited(5), &.{});
    const r = &l.interface;

    try r.discardAll(2);
    try r.discardAll(2);
    try std.testing.expectError(error.EndOfStream, l.interface.discardAll(2));
}
