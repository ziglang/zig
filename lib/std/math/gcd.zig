//! Greatest common divisor (https://mathworld.wolfram.com/GreatestCommonDivisor.html)
const std = @import("std");

/// Returns the greatest common divisor (GCD) of two unsigned integers (`a` and `b`) which are not both zero.
/// For example, the GCD of `8` and `12` is `4`, that is, `gcd(8, 12) == 4`.
pub fn gcd(a: anytype, b: anytype) @TypeOf(a, b) {
    const N = switch (@TypeOf(a, b)) {
        // convert comptime_int to some sized int type for @ctz
        comptime_int => std.math.IntFittingRange(@min(a, b), @max(a, b)),
        else => |T| T,
    };
    if (@typeInfo(N) != .int or @typeInfo(N).int.signedness != .unsigned) {
        @compileError("`a` and `b` must be usigned integers");
    }

    // using an optimised form of Stein's algorithm:
    // https://en.wikipedia.org/wiki/Binary_GCD_algorithm
    std.debug.assert(a != 0 or b != 0);

    if (a == 0) return b;
    if (b == 0) return a;

    var x: N = a;
    var y: N = b;

    const xz = @ctz(x);
    const yz = @ctz(y);
    const shift = @min(xz, yz);
    x >>= @intCast(xz);
    y >>= @intCast(yz);

    var diff = y -% x;
    while (diff != 0) : (diff = y -% x) {
        // ctz is invariant under negation, we
        // put it here to ease data dependencies,
        // makes the CPU happy.
        const zeros = @ctz(diff);
        if (x > y) diff = -%diff;
        y = @min(x, y);
        x = diff >> @intCast(zeros);
    }
    return y << @intCast(shift);
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
    try expectEqual(gcd(300_000, @as(u32, 2_300_000)), 100_000);
}
