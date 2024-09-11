const std = @import("std");
const expectEqual = std.testing.expectEqual;

test "switch continue" {
    const value: i32 = 54;
    const result = sw: switch (value) {
        10...60 => |v| continue :sw v - 10,
        4 => continue :sw 3,
        3 => continue :sw 2,
        2 => continue :sw 1,

        // A switch statement can be targeted by a break, even if the switch and
        // the break are unlabeled.
        1 => break -6,

        else => unreachable,
    };

    try expectEqual(-6, result);
}

// test
