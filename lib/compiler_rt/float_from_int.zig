const std = @import("std");
const Int = std.meta.Int;
const math = std.math;

pub fn floatFromInt(comptime T: type, x: anytype) T {
    if (x == 0) return 0;

    // Various constants whose values follow from the type parameters.
    // Any reasonable optimizer will fold and propagate all of these.
    const Z = Int(.unsigned, @bitSizeOf(@TypeOf(x)));
    const uT = Int(.unsigned, @bitSizeOf(T));
    const inf = math.inf(T);
    const float_bits = @bitSizeOf(T);
    const int_bits = @bitSizeOf(@TypeOf(x));
    const exp_bits = math.floatExponentBits(T);
    const fractional_bits = math.floatFractionalBits(T);
    const exp_bias = math.maxInt(Int(.unsigned, exp_bits - 1));
    const implicit_bit = if (T != f80) @as(uT, 1) << fractional_bits else 0;
    const max_exp = exp_bias;

    // Sign
    const abs_val = @abs(x);
    const sign_bit = if (x < 0) @as(uT, 1) << (float_bits - 1) else 0;
    var result: uT = sign_bit;

    // Compute significand
    const exp = int_bits - @clz(abs_val) - 1;
    if (int_bits <= fractional_bits or exp <= fractional_bits) {
        const shift_amt = fractional_bits - @as(math.Log2Int(uT), @intCast(exp));

        // Shift up result to line up with the significand - no rounding required
        result = @as(uT, @intCast(abs_val)) << shift_amt;
        result ^= implicit_bit; // Remove implicit integer bit
    } else {
        const shift_amt: math.Log2Int(Z) = @intCast(exp - fractional_bits);
        const exact_tie: bool = @ctz(abs_val) == shift_amt - 1;

        // Shift down result and remove implicit integer bit
        result = @as(uT, @intCast((abs_val >> (shift_amt - 1)))) ^ (implicit_bit << 1);

        // Round result, including round-to-even for exact ties
        result = ((result + 1) >> 1) & ~@as(uT, @intFromBool(exact_tie));
    }

    // Compute exponent
    if ((int_bits > max_exp) and (exp > max_exp)) // If exponent too large, overflow to infinity
        return @bitCast(sign_bit | @as(uT, @bitCast(inf)));

    result += (@as(uT, exp) + exp_bias) << math.floatMantissaBits(T);

    // If the result included a carry, we need to restore the explicit integer bit
    if (T == f80) result |= 1 << fractional_bits;

    return @bitCast(sign_bit | result);
}

const endian = @import("builtin").cpu.arch.endian();
inline fn limb(limbs: []const u32, index: usize) u32 {
    return switch (endian) {
        .little => limbs[index],
        .big => limbs[limbs.len - 1 - index],
    };
}

pub inline fn floatFromBigInt(comptime T: type, comptime signedness: std.builtin.Signedness, x: []const u32) T {
    switch (x.len) {
        0 => return 0,
        inline 1...4 => |limbs_len| return @floatFromInt(@as(
            @Type(.{ .int = .{ .signedness = signedness, .bits = 32 * limbs_len } }),
            @bitCast(x[0..limbs_len].*),
        )),
        else => {},
    }

    // sign implicit fraction round sticky
    const I = comptime @Type(.{ .int = .{
        .signedness = signedness,
        .bits = @as(u16, @intFromBool(signedness == .signed)) + 1 + math.floatFractionalBits(T) + 1 + 1,
    } });

    const clrsb = clrsb: {
        var clsb: usize = 0;
        const sign_bits: u32 = switch (signedness) {
            .signed => @bitCast(@as(i32, @bitCast(limb(x, x.len - 1))) >> 31),
            .unsigned => 0,
        };
        for (0..x.len) |limb_index| {
            const l = limb(x, x.len - 1 - limb_index) ^ sign_bits;
            clsb += @clz(l);
            if (l != 0) break;
        }
        break :clrsb clsb - @intFromBool(signedness == .signed);
    };
    const active_bits = 32 * x.len - clrsb;
    const exponent = active_bits -| @bitSizeOf(I);
    const exponent_limb = exponent / 32;
    const sticky = for (0..exponent_limb) |limb_index| {
        if (limb(x, limb_index) != 0) break true;
    } else limb(x, exponent_limb) & ((@as(u32, 1) << @truncate(exponent)) - 1) != 0;
    return math.ldexp(@as(T, @floatFromInt(
        std.mem.readPackedIntNative(I, std.mem.sliceAsBytes(x), exponent) | @intFromBool(sticky),
    )), @intCast(exponent));
}

test {
    _ = @import("float_from_int_test.zig");
}
