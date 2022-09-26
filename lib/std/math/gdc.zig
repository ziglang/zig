/// Find the greatest common divisor (GCD) of two integers (uint), which are not all zero.
/// For example, the GCD of 8 and 12 is 4, that is, gcd(8, 12) == 4.
const std = @import("std");
const expect = std.testing.expect;

// Greatest common divisor (https://mathworld.wolfram.com/GreatestCommonDivisor.html)
pub fn gcd(a: anytype, b: anytype) @TypeOf(a, b) {

    // only integers are allowed and not both must be zero
    std.debug.assert(a != 0 or b != 0);
    std.debug.assert(a >= 0 and b >= 0);

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
    // try expect(gcd(0, 0) == 0);
    try expect(gcd(0, 5) == 5);
    try expect(gcd(5, 0) == 5);
    try expect(gcd(8, 12) == 4);
    try expect(gcd(33, 77) == 11);
    try expect(gcd(49865, 69811) == 9973);
    try expect(gcd(300_000, 2_300_000) == 100_000);
}
