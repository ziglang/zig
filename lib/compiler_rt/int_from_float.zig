const std = @import("std");
const Int = std.meta.Int;
const math = std.math;
const Log2Int = math.Log2Int;

pub inline fn intFromFloat(comptime I: type, a: anytype) I {
    const F = @TypeOf(a);
    const float_bits = @typeInfo(F).float.bits;
    const int_bits = @typeInfo(I).int.bits;
    const rep_t = Int(.unsigned, float_bits);
    const sig_bits = math.floatMantissaBits(F);
    const exp_bits = math.floatExponentBits(F);
    const fractional_bits = math.floatFractionalBits(F);

    const implicit_bit = if (F != f80) (@as(rep_t, 1) << sig_bits) else 0;
    const max_exp = (1 << (exp_bits - 1));
    const exp_bias = max_exp - 1;
    const sig_mask = (@as(rep_t, 1) << sig_bits) - 1;

    // Break a into sign, exponent, significand
    const a_rep: rep_t = @bitCast(a);
    const negative = (a_rep >> (float_bits - 1)) != 0;
    const exponent = @as(i32, @intCast((a_rep << 1) >> (sig_bits + 1))) - exp_bias;
    const significand: rep_t = (a_rep & sig_mask) | implicit_bit;

    // If the exponent is negative, the result rounds to zero.
    if (exponent < 0) return 0;

    // If the value is too large for the integer type, saturate.
    switch (@typeInfo(I).int.signedness) {
        .unsigned => {
            if (negative) return 0;
            if (@as(c_uint, @intCast(exponent)) >= @min(int_bits, max_exp)) return math.maxInt(I);
        },
        .signed => if (@as(c_uint, @intCast(exponent)) >= @min(int_bits - 1, max_exp)) {
            return if (negative) math.minInt(I) else math.maxInt(I);
        },
    }

    // If 0 <= exponent < sig_bits, right shift to get the result.
    // Otherwise, shift left.
    var result: I = undefined;
    if (exponent < fractional_bits) {
        result = @intCast(significand >> @intCast(fractional_bits - exponent));
    } else {
        result = @as(I, @intCast(significand)) << @intCast(exponent - fractional_bits);
    }

    if ((@typeInfo(I).int.signedness == .signed) and negative)
        return ~result +% 1;
    return result;
}

pub inline fn bigIntFromFloat(comptime signedness: std.builtin.Signedness, result: []u32, a: anytype) void {
    switch (result.len) {
        0 => return,
        inline 1...4 => |limbs_len| {
            result[0..limbs_len].* = @bitCast(@as(
                @Type(.{ .int = .{ .signedness = signedness, .bits = 32 * limbs_len } }),
                @intFromFloat(a),
            ));
            return;
        },
        else => {},
    }

    // sign implicit fraction
    const significand_bits = 1 + math.floatFractionalBits(@TypeOf(a));
    const I = @Type(comptime .{ .int = .{
        .signedness = signedness,
        .bits = @as(u16, @intFromBool(signedness == .signed)) + significand_bits,
    } });

    const parts = math.frexp(a);
    const exponent = @max(parts.exponent - significand_bits, 0);
    const int: I = @intFromFloat(switch (exponent) {
        0 => a,
        else => math.ldexp(parts.significand, significand_bits),
    });
    switch (signedness) {
        .signed => {
            const endian = @import("builtin").cpu.arch.endian();
            const exponent_limb = switch (endian) {
                .little => exponent / 32,
                .big => result.len - 1 - exponent / 32,
            };
            const sign_bits: u32 = if (int < 0) math.maxInt(u32) else 0;
            @memset(result[0..exponent_limb], switch (endian) {
                .little => 0,
                .big => sign_bits,
            });
            result[exponent_limb] = sign_bits << @truncate(exponent);
            @memset(result[exponent_limb + 1 ..], switch (endian) {
                .little => sign_bits,
                .big => 0,
            });
        },
        .unsigned => @memset(result, 0),
    }
    std.mem.writePackedIntNative(I, std.mem.sliceAsBytes(result), exponent, int);
}

test {
    _ = @import("int_from_float_test.zig");
}
