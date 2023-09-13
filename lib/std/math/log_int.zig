const std = @import("../std.zig");
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const Log2Int = math.Log2Int;

/// Returns the logarithm of `x` for the provided `base`, rounding down to the nearest integer.
/// Asserts that `base > 1` and `x != 0`.
pub fn log_int(comptime T: type, base: T, x: T) Log2Int(T) {
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("log_int requires an unsigned integer, found " ++ @typeName(T));

    assert(base > 1 and x != 0);

    var exponent: Log2Int(T) = 0;
    var power: T = 1;
    while (power <= x / base) {
        power *= base;
        exponent += 1;
    }

    return exponent;
}

test "math.log_int" {
    // Test all unsigned integers with 2, 3, ..., 64 bits.
    // We cannot test 0 or 1 bits since base must be > 1.
    inline for (2..64 + 1) |bits| {
        const T = @Type(std.builtin.Type{
            .Int = std.builtin.Type.Int{ .signedness = .unsigned, .bits = @intCast(bits) },
        });

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

test "math.log_int vs math.log2" {
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

test "math.log_int vs math.log10" {
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
