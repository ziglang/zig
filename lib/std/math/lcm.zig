//! Least common multiple (https://mathworld.wolfram.com/LeastCommonMultiple.html)
const std = @import("std");

/// Returns the least common multiple (LCM) of two integers (`a` and `b`).
/// For example, the LCM of `8` and `12` is `24`, that is, `lcm(8, 12) == 24`.
/// If any of the arguments is zero, then the returned value is 0.
pub fn lcm(a: anytype, b: anytype) @TypeOf(a, b) {
    // Behavior from C++ and Python
    // If an argument is zero, then the returned value is 0.
    if (a == 0 or b == 0) return 0;
    return @abs(b) * (@abs(a) / std.math.gcd(@abs(a), @abs(b)));
}

test lcm {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(lcm(0, 0), 0);
    try expectEqual(lcm(1, 0), 0);
    try expectEqual(lcm(-1, 0), 0);
    try expectEqual(lcm(0, 1), 0);
    try expectEqual(lcm(0, -1), 0);
    try expectEqual(lcm(7, 1), 7);
    try expectEqual(lcm(7, -1), 7);
    try expectEqual(lcm(8, 12), 24);
    try expectEqual(lcm(-23, 15), 345);
    try expectEqual(lcm(120, 84), 840);
    try expectEqual(lcm(84, -120), 840);
    try expectEqual(lcm(1216342683557601535506311712, 436522681849110124616458784), 16592536571065866494401400422922201534178938447014944);
}
