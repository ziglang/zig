//! Prime Number (https://mathworld.wolfram.com/PrimeNumber.html)
const std = @import("std");
const expect = std.testing.expect;

/// Returns true if x is a Prime number.
pub fn isPrime(x: anytype) bool {

    // only an unsigned integer is allowed
    comptime switch (@typeInfo(@TypeOf(x))) {
        .Int => |int| std.debug.assert(int.signedness == .unsigned),
        .ComptimeInt => {
            std.debug.assert(x >= 0);
        },
        else => unreachable,
    };

    // corner cases
    if (x <= 1 or x == 4)
        return false;
    if (x <= 3) return true;
    if (x == 5) return true;
    if (x == 7) return true;
    if (x % 2 == 0) return false;
    if (x % 3 == 0) return false;

    // an optimised version of the 'Sieve of Eratosthenes' (https://mathworld.wolfram.com/SieveofEratosthenes.html)
    const r = std.math.sqrt(x);
    var f: u64 = 5;
    while (f <= r) : (f += 6) {
        if (x % f == 0) return false;
        if (x % (f + 2) == 0) return false;
    }
    return true;
}

test "isPrime" {
    try expect(isPrime(0) == false);
    try expect(isPrime(1) == false);
    try expect(isPrime(2) == true);
    try expect(isPrime(3) == true);
    try expect(isPrime(4) == false);
    try expect(isPrime(5) == true);
    try expect(isPrime(6) == false);
    try expect(isPrime(7) == true);
    try expect(isPrime(8) == false);
    try expect(isPrime(9) == false);
    try expect(isPrime(10) == false);
    try expect(isPrime(11) == true);
    try expect(isPrime(12) == false);
    try expect(isPrime(13) == true);
    try expect(isPrime(14) == false);
    try expect(isPrime(15) == false);

    // build the sum of all the primes below two million
    var sum: usize = 17;
    var n: usize = 9;
    while (n < 2_000_000) : (n += 2) {
        if (isPrime(n)) sum += n;
    }
    try expect(sum == 142913828922);

    // test of the biggest unsigned int
    var x: u128 = 340282366920938463463374607431768211455;
    try expect(isPrime(x) == false);
}


