const std = @import("std");
const expect = std.testing.expect;

const Tagged = union(enum(u32)) {
    int: i64 = 123,
    boolean: bool = 67,
};

test "tag values" {
    const int: Tagged = .{ .int = -40 };
    try expect(@intFromEnum(int) == 123);

    const boolean: Tagged = .{ .boolean = false };
    try expect(@intFromEnum(boolean) == 67);
}

// test
