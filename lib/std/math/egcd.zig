//! Extended Greatest Common Divisor (https://mathworld.wolfram.com/ExtendedGreatestCommonDivisor.html)
const std = @import("../std.zig");

/// Result type of `egcd`.
pub fn ExtendedGreatestCommonDivisor(S: anytype) type {
    return struct {
        gcd: S,
        bezout_coeff_1: S,
        bezout_coeff_2: S,
    };
}

/// Returns the Extended Greatest Common Divisor (EGCD) of two signed integers (`a` and `b`) which are not both zero.
pub fn egcd(a: anytype, b: anytype) ExtendedGreatestCommonDivisor(@TypeOf(a, b)) {
    const S = switch (@TypeOf(a, b)) {
        // convert comptime_int to some sized int type for @ctz
        comptime_int => b: {
            const n = @max(@abs(a), @abs(b));
            break :b std.math.IntFittingRange(-n, n);
        },
        else => |T| T,
    };

    if (@typeInfo(S) != .int or @typeInfo(S).int.signedness != .signed) {
        @compileError("`a` and `b` must be signed integers");
    }

    std.debug.assert(a != 0 or b != 0);

    var x: S = @intCast(@abs(a));
    var y: S = @intCast(@abs(b));

    // Mantain a = s * x + t * y.
    var s: S = std.math.sign(a);
    var t: S = 0;

    // Mantain b = u * x + v * y.
    var u: S = 0;
    var v: S = std.math.sign(b);

    while (x != 0) {
        const q = @divTrunc(y, x);
        const old_x = x;
        const old_s = s;
        const old_t = t;
        x = y - q * x;
        s = u - q * s;
        t = v - q * t;
        y = old_x;
        u = old_s;
        v = old_t;
    }

    return .{ .gcd = y, .bezout_coeff_1 = u, .bezout_coeff_2 = v };
}

test {
    {
        const a: i32 = 0;
        const b: i32 = 5;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i32 = 5;
        const b: i32 = 0;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }

    {
        const a: i32 = 21;
        const b: i32 = 15;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i32 = -21;
        const b: i32 = 15;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a = -21;
        const b = 15;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a = 927372692193078999176;
        const b = 573147844013817084101;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a = 453973694165307953197296969697410619233826;
        const b = 280571172992510140037611932413038677189525;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
}
