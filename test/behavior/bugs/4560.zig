const std = @import("std");
const builtin = @import("builtin");

test "fixed" {
    var s: S = .{
        .a = 1,
        .b = .{
            .size = 123,
            .max_distance_from_start_index = 456,
        },
    };
    try std.testing.expect(s.a == 1);
    try std.testing.expect(s.b.size == 123);
    try std.testing.expect(s.b.max_distance_from_start_index == 456);
}

const S = struct {
    a: u32,
    b: Map,

    const Map = StringHashMap(*S);
};

pub fn StringHashMap(comptime V: type) type {
    return HashMap([]const u8, V);
}

pub fn HashMap(comptime K: type, comptime V: type) type {
    if (false) {
        K;
        V;
    }
    return struct {
        size: usize,
        max_distance_from_start_index: usize,
    };
}
