/// Find the greatest common divisor (GCD) of two integers (uint), which are not all zero.
/// For example, the GCD of 8 and 12 is 4, that is, gcd(8, 12) == 4.
const std = @import("std");
const expectEQ = std.testing.expectEqual;

// Greatest common divisor (https://mathworld.wolfram.com/GreatestCommonDivisor.html)
pub fn gcd(a: anytype, b: anytype) @TypeOf(a, b) {

    // only integers are allowed and not both must be zero
    std.debug.assert(a != 0 or b != 0);
    std.debug.assert(a >= 0 and b >= 0);

    // if one of them is zero, the other is returned
    if (a == 0) return b;
    if (b == 0) return a;

    // init vars
    var x: @TypeOf(a, b) = a;
    var y: @TypeOf(a, b) = b;
    var m: @TypeOf(a, b) = a;

    // using the Euclidean algorithm (https://mathworld.wolfram.com/EuclideanAlgorithm.html)
    while (y != 0) {
        m = x % y;
        x = y;
        y = m;
    }
    return x;
}

test "gcd" {
    try expectEQ(gcd(0, 5), 5);
    try expectEQ(gcd(5, 0), 5);
    try expectEQ(gcd(8, 12), 4);
    try expectEQ(gcd(12, 8), 4);
    try expectEQ(gcd(33, 77), 11);
    try expectEQ(gcd(77, 33), 11);
    try expectEQ(gcd(49865, 69811), 9973);
    try expectEQ(gcd(300_000, 2_300_000), 100_000);
    try expectEQ(gcd(90000000_000_000_000_000_000, 2), 2);
}
