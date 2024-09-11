const std = @import("std");
const expectEqual = std.testing.expectEqual;

test "switch continue" {
    const value: i32 = 54;

    const result = sw: switch (value) {
        10...60 => |v| continue :sw v - 10,
        4 => continue :sw 3,
        3 => continue :sw 2,
        2 => continue :sw 1,

        // A labeled switch statement can be targeted by an unlabeled break.
        1 => break -6,

        else => unreachable,
    };

    try expectEqual(-6, result);

    // Semantically, the labeled switch statement shown above is identical to
    // the following loop:
    var sw: i32 = value;
    const result_with_loop = while (true) {
        sw = switch (sw) {
            10...60 => |v| v - 10,
            4 => 3,
            3 => 2,
            2 => 1,

            1 => break -6,

            else => unreachable,
        };
    };

    try expectEqual(result, result_with_loop);
}

// test
