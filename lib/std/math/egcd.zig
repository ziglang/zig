//! Extended Greatest Common Divisor (https://mathworld.wolfram.com/ExtendedGreatestCommonDivisor.html)
const std = @import("../std.zig");

/// Result type of `egcd`.
pub fn ExtendedGreatestCommonDivisor(S: anytype) type {
    const N = switch (S) {
        comptime_int => comptime_int,
        else => |T| std.meta.Int(.unsigned, @bitSizeOf(T)),
    };

    return struct {
        gcd: N,
        bezout_coeff_1: S,
        bezout_coeff_2: S,
    };
}

/// Returns the Extended Greatest Common Divisor (EGCD) of two signed integers (`a` and `b`) which are not both zero.
pub fn egcd(a: anytype, b: anytype) ExtendedGreatestCommonDivisor(@TypeOf(a, b)) {
    const S = switch (@TypeOf(a, b)) {
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

    if (a == 0) return .{ .gcd = @abs(b), .bezout_coeff_1 = 0, .bezout_coeff_2 = std.math.sign(b) };
    if (b == 0) return .{ .gcd = @abs(a), .bezout_coeff_1 = std.math.sign(a), .bezout_coeff_2 = 0 };

    const other: S, const odd: S, const shift, const switch_coeff = b: {
        const xz = @ctz(@as(S, a));
        const yz = @ctz(@as(S, b));
        break :b if (xz < yz) .{ b, a, xz, true } else .{ a, b, yz, false };
    };
    const toinv = @shrExact(other, @intCast(shift));
    const ctrl = @shrExact(odd, @intCast(shift)); // Invariant: |s|, |t|, |ctrl| < |MIN_OF(S)|
    const half_ctrl = 1 + @shrExact(ctrl - 1, 1);
    const abs_ctrl = @abs(ctrl);

    var s: S = std.math.sign(toinv);
    var t: S = 0;

    var x = @abs(toinv);
    var y = abs_ctrl;

    {
        const xz = @ctz(x);
        x = @shrExact(x, @intCast(xz));
        for (0..xz) |_| {
            const half_s = s >> 1;
            if (s & 1 == 0)
                s = half_s
            else
                s = half_s + half_ctrl;
        }
    }

    var y_minus_x = y -% x;
    while (y_minus_x != 0) : (y_minus_x = y -% x) {
        const t_minus_s = t - s;
        const copy_x = x;
        const copy_s = s;
        const xz = @ctz(y_minus_x);

        s -= t;
        const carry = x < y;
        x -%= y;
        if (carry) {
            x = y_minus_x;
            y = copy_x;
            s = t_minus_s;
            t = copy_s;
        }
        x = @shrExact(x, @intCast(xz));
        for (0..xz) |_| {
            const half_s = s >> 1;
            if (s & 1 == 0)
                s = half_s
            else
                s = half_s + half_ctrl;
        }

        if (s < 0) s = @intCast(abs_ctrl - @abs(s));
    }

    // Using integer widening is only a temporary solution.
    const W = std.meta.Int(.signed, @bitSizeOf(S) * 2);
    t = @intCast(@divExact(y - @as(W, s) * toinv, ctrl));
    const final_s, const final_t = if (switch_coeff) .{ t, s } else .{ s, t };
    return .{
        .gcd = @shlExact(y, @intCast(shift)),
        .bezout_coeff_1 = final_s,
        .bezout_coeff_2 = final_t,
    };
}

test {
    {
        const a: i2 = 0;
        const b: i2 = 1;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i2 = r.bezout_coeff_1;
        const t: i2 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i8 = -128;
        const b: i8 = 127;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i16 = r.bezout_coeff_1;
        const t: i16 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i16 = -32768;
        const b: i16 = -32768;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i32 = r.bezout_coeff_1;
        const t: i32 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i32 = 128;
        const b: i32 = 112;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i64 = r.bezout_coeff_1;
        const t: i64 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i32 = 4 * 89;
        const b: i32 = 2 * 17;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i64 = r.bezout_coeff_1;
        const t: i64 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i8 = 127;
        const b: i8 = 126;
        const r = egcd(a, b);
        const g = r.gcd;
        const s: i16 = r.bezout_coeff_1;
        const t: i16 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i4 = -8;
        const b: i4 = 1;
        const r = egcd(a, b);
        const g = r.gcd;
        const s = r.bezout_coeff_1;
        const t = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
    {
        const a: i4 = -8;
        const b: i4 = 5;
        const r = egcd(a, b);
        const g = r.gcd;
        // Avoid overflow in assert.
        const s: i8 = r.bezout_coeff_1;
        const t: i8 = r.bezout_coeff_2;
        try std.testing.expect(s * a + t * b == g);
    }
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
