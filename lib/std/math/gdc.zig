/// Find the greatest common divisor (GCD) of two integers.
const std = @import("std");
const expect = std.testing.expect;

// Greatest common divisor
pub fn gcd(a: anytype, b: anytype) @TypeOf(a) {
    if (a < 0 or b < 0) @compileError("gcd is only defined for positive numbers (integer)");

    var x = a;
    var y = b;
    var m = a;

    while (y != 0) {
        m = x % y;
        x = y;
        y = m;
    }
    return x;
}

test "gcd" {
    try expect(gcd(0, 5) == 5);
    try expect(gcd(33, 77) == 11);
    try expect(gcd(49865, 69811) == 9973);
    try expect(gcd(300_000, 2_300_000) == 100_000);
}
