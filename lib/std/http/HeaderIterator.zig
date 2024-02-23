bytes: []const u8,
index: usize,
is_trailer: bool,

pub fn init(bytes: []const u8) HeaderIterator {
    return .{
        .bytes = bytes,
        .index = std.mem.indexOfPosLinear(u8, bytes, 0, "\r\n").? + 2,
        .is_trailer = false,
    };
}

pub fn next(it: *HeaderIterator) ?std.http.Header {
    const end = std.mem.indexOfPosLinear(u8, it.bytes, it.index, "\r\n").?;
    var kv_it = std.mem.splitSequence(u8, it.bytes[it.index..end], ": ");
    const name = kv_it.next().?;
    const value = kv_it.rest();
    if (value.len == 0) {
        if (it.is_trailer) return null;
        const next_end = std.mem.indexOfPosLinear(u8, it.bytes, end + 2, "\r\n") orelse
            return null;
        it.is_trailer = true;
        it.index = next_end + 2;
        kv_it = std.mem.splitSequence(u8, it.bytes[end + 2 .. next_end], ": ");
        return .{
            .name = kv_it.next().?,
            .value = kv_it.rest(),
        };
    }
    it.index = end + 2;
    return .{
        .name = name,
        .value = value,
    };
}

test next {
    var it = HeaderIterator.init("200 OK\r\na: b\r\nc: d\r\n\r\ne: f\r\n\r\n");
    try std.testing.expect(!it.is_trailer);
    {
        const header = it.next().?;
        try std.testing.expect(!it.is_trailer);
        try std.testing.expectEqualStrings("a", header.name);
        try std.testing.expectEqualStrings("b", header.value);
    }
    {
        const header = it.next().?;
        try std.testing.expect(!it.is_trailer);
        try std.testing.expectEqualStrings("c", header.name);
        try std.testing.expectEqualStrings("d", header.value);
    }
    {
        const header = it.next().?;
        try std.testing.expect(it.is_trailer);
        try std.testing.expectEqualStrings("e", header.name);
        try std.testing.expectEqualStrings("f", header.value);
    }
    try std.testing.expectEqual(null, it.next());
}

const HeaderIterator = @This();
const std = @import("../std.zig");
