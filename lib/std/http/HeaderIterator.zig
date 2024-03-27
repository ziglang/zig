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
    if (it.index == end) { // found the trailer boundary (\r\n\r\n)
        if (it.is_trailer) return null;

        const next_end = std.mem.indexOfPosLinear(u8, it.bytes, end + 2, "\r\n") orelse
            return null;

        var kv_it = std.mem.splitScalar(u8, it.bytes[end + 2 .. next_end], ':');
        const name = kv_it.first();
        const value = kv_it.rest();

        it.is_trailer = true;
        it.index = next_end + 2;
        if (name.len == 0)
            return null;

        return .{
            .name = name,
            .value = std.mem.trim(u8, value, " \t"),
        };
    } else { // normal header
        var kv_it = std.mem.splitScalar(u8, it.bytes[it.index..end], ':');
        const name = kv_it.first();
        const value = kv_it.rest();

        it.index = end + 2;
        if (name.len == 0)
            return null;

        return .{
            .name = name,
            .value = std.mem.trim(u8, value, " \t"),
        };
    }
}

test next {
    var it = HeaderIterator.init("200 OK\r\na: b\r\nc:  \r\nd:e\r\n\r\nf: g\r\n\r\n");
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
        try std.testing.expectEqualStrings("", header.value);
    }
    {
        const header = it.next().?;
        try std.testing.expect(!it.is_trailer);
        try std.testing.expectEqualStrings("d", header.name);
        try std.testing.expectEqualStrings("e", header.value);
    }
    {
        const header = it.next().?;
        try std.testing.expect(it.is_trailer);
        try std.testing.expectEqualStrings("f", header.name);
        try std.testing.expectEqualStrings("g", header.value);
    }
    try std.testing.expectEqual(null, it.next());

    it = HeaderIterator.init("200 OK\r\n: ss\r\n\r\n");
    try std.testing.expect(!it.is_trailer);
    try std.testing.expectEqual(null, it.next());

    it = HeaderIterator.init("200 OK\r\na:b\r\n\r\n: ss\r\n\r\n");
    try std.testing.expect(!it.is_trailer);
    {
        const header = it.next().?;
        try std.testing.expect(!it.is_trailer);
        try std.testing.expectEqualStrings("a", header.name);
        try std.testing.expectEqualStrings("b", header.value);
    }
    try std.testing.expectEqual(null, it.next());
    try std.testing.expect(it.is_trailer);
}

const HeaderIterator = @This();
const std = @import("../std.zig");
const assert = std.debug.assert;
