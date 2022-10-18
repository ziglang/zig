const std = @import("std");
const expect = std.testing.expect;

fn BuildType(comptime T: type) type {
    return struct {
        val: union {
            b: T,
        },
    };
}

test {
    const TestStruct = BuildType(u32);
    const c = TestStruct{ .val = .{ .b = 10 } };
    try expect(c.val.b == 10);
}
