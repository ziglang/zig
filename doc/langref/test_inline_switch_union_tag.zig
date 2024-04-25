const std = @import("std");
const expect = std.testing.expect;

const U = union(enum) {
    a: u32,
    b: f32,
};

fn getNum(u: U) u32 {
    switch (u) {
        // Here `num` is a runtime-known value that is either
        // `u.a` or `u.b` and `tag` is `u`'s comptime-known tag value.
        inline else => |num, tag| {
            if (tag == .b) {
                return @intFromFloat(num);
            }
            return num;
        }
    }
}

test "test" {
    const u = U{ .b = 42 };
    try expect(getNum(u) == 42);
}

// test
