//! Greatest common divisor (https://mathworld.wolfram.com/GreatestCommonDivisor.html)
const std = @import("std");

/// Returns the greatest common divisor (GCD) of two unsigned integers (`a` and `b`) which are not both zero.
/// For example, the GCD of `8` and `12` is `4`, that is, `gcd(8, 12) == 4`.
pub fn gcd(a: anytype, b: anytype) @TypeOf(a, b) {
    const N = switch (@TypeOf(a, b)) {
        // convert comptime_int to some sized int so we can @ctz on it.
        // type coercion takes care of the conversion back to comptime_int
        // at function's return
        comptime_int => std.math.IntFittingRange(@min(a, b), @max(a, b)),
        else => |T| T,
    };
    // integers are unsigned, at least one is nonzero
    comptime std.debug.assert(@typeInfo(N).Int.signedness == .unsigned);
    std.debug.assert(a != 0 or b != 0);

    // using Stein's algorithm (https://en.wikipedia.org/wiki/Binary_GCD_algorithm)
    if (a == 0) return b;
    if (b == 0) return a;

    var x: N = a;
    var y: N = b;

    const i = @ctz(x);
    const j = @ctz(y);
    // x, y are nonzero, @intCast(@ctz(self)) does not overflow
    x >>= @intCast(i);
    y >>= @intCast(j);

    // invariants: x, y are odd
    while (true) {
        // ensure x ≥ y
        if (y > x) std.mem.swap(N, &x, &y);

        // odd - odd is even
        x -= y;

        // gcd(0, y) == y, remultiply by the common power of 2
        if (x == 0) return y << @intCast(@min(i, j));

        // x is nonzero, @intCast(@ctz(self)) does not overflow
        // x is even, its value decreases
        x >>= @intCast(@ctz(x));
    }
}

test gcd {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(gcd(0, 5), 5);
    try expectEqual(gcd(5, 0), 5);
    try expectEqual(gcd(8, 12), 4);
    try expectEqual(gcd(12, 8), 4);
    try expectEqual(gcd(33, 77), 11);
    try expectEqual(gcd(77, 33), 11);
    try expectEqual(gcd(49865, 69811), 9973);
    try expectEqual(gcd(300_000, 2_300_000), 100_000);
    try expectEqual(gcd(90000000_000_000_000_000_000, 2), 2);
    try expectEqual(gcd(@as(u80, 90000000_000_000_000_000_000), 2), 2);

    // an important test case! @ctz's returned type is different from the
    // type of >>'s rhs - an @intCast is required!
    try expectEqual(gcd(300_000, @as(u32, 2_300_000)), 100_000);
}
