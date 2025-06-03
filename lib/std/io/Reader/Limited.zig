const Limited = @This();

const std = @import("../../std.zig");
const Reader = std.io.Reader;
const Writer = std.io.Writer;
const Limit = std.io.Limit;

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

fn stream(context: ?*anyopaque, w: *Writer, limit: Limit) Reader.StreamError!usize {
    const l: *Limited = @alignCast(@ptrCast(context));
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited_reader.read(w, combined_limit);
    l.remaining = l.remaining.subtract(n).?;
    return n;
}

fn discard(context: ?*anyopaque, limit: Limit) Reader.Error!usize {
    const l: *Limited = @alignCast(@ptrCast(context));
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited_reader.discard(combined_limit);
    l.remaining = l.remaining.subtract(n).?;
    return n;
}
