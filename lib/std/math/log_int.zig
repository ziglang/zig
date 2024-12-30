const std = @import("../std.zig");
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const Log2Int = math.Log2Int;

/// Returns the logarithm of `x` for the provided `base`, rounding down to the nearest integer.
/// Asserts that `base > 1` and `x > 0`.
pub fn log_int(comptime T: type, base: T, x: T) Log2Int(T) {
    const valid = switch (@typeInfo(T)) {
        .comptime_int => true,
        .int => |IntType| IntType.signedness == .unsigned,
        else => false,
    };
    if (!valid) @compileError("log_int requires an unsigned integer, found " ++ @typeName(T));

    assert(base > 1 and x > 0);
    if (base == 2) return math.log2_int(T, x);

    // Let's denote by [y] the integer part of y.

    // Throughout the iteration the following invariant is preserved:
    //     power = base ^ exponent

    // Safety and termination.
    //
    // We never overflow inside the loop because when we enter the loop we have
    //     power <= [maxInt(T) / base]
    // therefore
    //     power * base <= maxInt(T)
    // is a valid multiplication for type `T` and
    //     exponent + 1 <= log(base, maxInt(T)) <= log2(maxInt(T)) <= maxInt(Log2Int(T))
    // is a valid addition for type `Log2Int(T)`.
    //
    // This implies also termination because power is strictly increasing,
    // hence it must eventually surpass [x / base] < maxInt(T) and we then exit the loop.

    var exponent: Log2Int(T) = 0;
    var power: T = 1;
    while (power <= x / base) {
        power *= base;
        exponent += 1;
    }

    // If we never entered the loop we must have
    //     [x / base] < 1
    // hence
    //     x <= [x / base] * base < base
    // thus the result is 0. We can then return exponent, which is still 0.
    //
    // Otherwise, if we entered the loop at least once,
    // when we exit the loop we have that power is exactly divisible by base and
    //     power / base <= [x / base] < power
    // hence
    //     power <= [x / base] * base <= x < power * base
    // This means that
    //     base^exponent <= x < base^(exponent+1)
    // hence the result is exponent.

    return exponent;
}

test "log_int" {
    // Test all unsigned integers with 2, 3, ..., 64 bits.
    // We cannot test 0 or 1 bits since base must be > 1.
    inline for (2..64 + 1) |bits| {
        const T = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @intCast(bits) } });

        // for base = 2, 3, ..., min(maxInt(T),1024)
        var base: T = 1;
        while (base < math.maxInt(T) and base <= 1024) {
            base += 1;

            // test that `log_int(T, base, 1) == 0`
            try testing.expectEqual(@as(Log2Int(T), 0), log_int(T, base, 1));

            // For powers `pow = base^exp > 1` that fit inside T,
            // test that `log_int` correctly detects the jump in the logarithm
            // from `log(pow-1) == exp-1` to `log(pow) == exp`.
            var exp: Log2Int(T) = 0;
            var pow: T = 1;
            while (pow <= math.maxInt(T) / base) {
                exp += 1;
                pow *= base;

                try testing.expectEqual(exp - 1, log_int(T, base, pow - 1));
                try testing.expectEqual(exp, log_int(T, base, pow));
            }
        }
    }
}

test "log_int vs math.log2" {
    const types = [_]type{ u2, u3, u4, u8, u16 };
    inline for (types) |T| {
        var n: T = 0;
        while (n < math.maxInt(T)) {
            n += 1;
            const special = math.log2_int(T, n);
            const general = log_int(T, 2, n);
            try testing.expectEqual(special, general);
        }
    }
}

test "log_int vs math.log10" {
    const types = [_]type{ u4, u5, u6, u8, u16 };
    inline for (types) |T| {
        var n: T = 0;
        while (n < math.maxInt(T)) {
            n += 1;
            const special = math.log10_int(n);
            const general = log_int(T, 10, n);
            try testing.expectEqual(special, general);
        }
    }
}

test "log_int at comptime" {
    const x = 59049; // 9 ** 5;
    comptime {
        if (math.log_int(comptime_int, 9, x) != 5) {
            @compileError("log(9, 59049) should be 5");
        }
    }
}
