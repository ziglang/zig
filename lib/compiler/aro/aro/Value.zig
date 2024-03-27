const std = @import("std");
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const backend = @import("../backend.zig");
const Interner = backend.Interner;
const BigIntSpace = Interner.Tag.Int.BigIntSpace;
const Compilation = @import("Compilation.zig");
const Type = @import("Type.zig");
const target_util = @import("target.zig");

const Value = @This();

opt_ref: Interner.OptRef = .none,

pub const zero = Value{ .opt_ref = .zero };
pub const one = Value{ .opt_ref = .one };
pub const @"null" = Value{ .opt_ref = .null };

pub fn intern(comp: *Compilation, k: Interner.Key) !Value {
    const r = try comp.interner.put(comp.gpa, k);
    return .{ .opt_ref = @enumFromInt(@intFromEnum(r)) };
}

pub fn int(i: anytype, comp: *Compilation) !Value {
    const info = @typeInfo(@TypeOf(i));
    if (info == .ComptimeInt or info.Int.signedness == .unsigned) {
        return intern(comp, .{ .int = .{ .u64 = i } });
    } else {
        return intern(comp, .{ .int = .{ .i64 = i } });
    }
}

pub fn ref(v: Value) Interner.Ref {
    std.debug.assert(v.opt_ref != .none);
    return @enumFromInt(@intFromEnum(v.opt_ref));
}

pub fn is(v: Value, tag: std.meta.Tag(Interner.Key), comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    return comp.interner.get(v.ref()) == tag;
}

/// Number of bits needed to hold `v`.
/// Asserts that `v` is not negative
pub fn minUnsignedBits(v: Value, comp: *const Compilation) usize {
    var space: BigIntSpace = undefined;
    const big = v.toBigInt(&space, comp);
    assert(big.positive);
    return big.bitCountAbs();
}

test "minUnsignedBits" {
    const Test = struct {
        fn checkIntBits(comp: *Compilation, v: u64, expected: usize) !void {
            const val = try intern(comp, .{ .int = .{ .u64 = v } });
            try std.testing.expectEqual(expected, val.minUnsignedBits(comp));
        }
    };

    var comp = Compilation.init(std.testing.allocator);
    defer comp.deinit();
    const target_query = try std.Target.Query.parse(.{ .arch_os_abi = "x86_64-linux-gnu" });
    comp.target = try std.zig.system.resolveTargetQuery(target_query);

    try Test.checkIntBits(&comp, 0, 0);
    try Test.checkIntBits(&comp, 1, 1);
    try Test.checkIntBits(&comp, 2, 2);
    try Test.checkIntBits(&comp, std.math.maxInt(i8), 7);
    try Test.checkIntBits(&comp, std.math.maxInt(u8), 8);
    try Test.checkIntBits(&comp, std.math.maxInt(i16), 15);
    try Test.checkIntBits(&comp, std.math.maxInt(u16), 16);
    try Test.checkIntBits(&comp, std.math.maxInt(i32), 31);
    try Test.checkIntBits(&comp, std.math.maxInt(u32), 32);
    try Test.checkIntBits(&comp, std.math.maxInt(i64), 63);
    try Test.checkIntBits(&comp, std.math.maxInt(u64), 64);
}

/// Minimum number of bits needed to represent `v` in 2's complement notation
/// Asserts that `v` is negative.
pub fn minSignedBits(v: Value, comp: *const Compilation) usize {
    var space: BigIntSpace = undefined;
    const big = v.toBigInt(&space, comp);
    assert(!big.positive);
    return big.bitCountTwosComp();
}

test "minSignedBits" {
    const Test = struct {
        fn checkIntBits(comp: *Compilation, v: i64, expected: usize) !void {
            const val = try intern(comp, .{ .int = .{ .i64 = v } });
            try std.testing.expectEqual(expected, val.minSignedBits(comp));
        }
    };

    var comp = Compilation.init(std.testing.allocator);
    defer comp.deinit();
    const target_query = try std.Target.Query.parse(.{ .arch_os_abi = "x86_64-linux-gnu" });
    comp.target = try std.zig.system.resolveTargetQuery(target_query);

    try Test.checkIntBits(&comp, -1, 1);
    try Test.checkIntBits(&comp, -2, 2);
    try Test.checkIntBits(&comp, -10, 5);
    try Test.checkIntBits(&comp, -101, 8);
    try Test.checkIntBits(&comp, std.math.minInt(i8), 8);
    try Test.checkIntBits(&comp, std.math.minInt(i16), 16);
    try Test.checkIntBits(&comp, std.math.minInt(i32), 32);
    try Test.checkIntBits(&comp, std.math.minInt(i64), 64);
}

pub const FloatToIntChangeKind = enum {
    /// value did not change
    none,
    /// floating point number too small or large for destination integer type
    out_of_range,
    /// tried to convert a NaN or Infinity
    overflow,
    /// fractional value was converted to zero
    nonzero_to_zero,
    /// fractional part truncated
    value_changed,
};

/// Converts the stored value from a float to an integer.
/// `.none` value remains unchanged.
pub fn floatToInt(v: *Value, dest_ty: Type, comp: *Compilation) !FloatToIntChangeKind {
    if (v.opt_ref == .none) return .none;

    const float_val = v.toFloat(f128, comp);
    const was_zero = float_val == 0;

    if (dest_ty.is(.bool)) {
        const was_one = float_val == 1.0;
        v.* = fromBool(!was_zero);
        if (was_zero or was_one) return .none;
        return .value_changed;
    } else if (dest_ty.isUnsignedInt(comp) and v.compare(.lt, zero, comp)) {
        v.* = zero;
        return .out_of_range;
    }

    const had_fraction = @rem(float_val, 1) != 0;
    const is_negative = std.math.signbit(float_val);
    const floored = @floor(@abs(float_val));

    var rational = try std.math.big.Rational.init(comp.gpa);
    defer rational.deinit();
    rational.setFloat(f128, floored) catch |err| switch (err) {
        error.NonFiniteFloat => {
            v.* = .{};
            return .overflow;
        },
        error.OutOfMemory => return error.OutOfMemory,
    };

    // The float is reduced in rational.setFloat, so we assert that denominator is equal to one
    const big_one = std.math.big.int.Const{ .limbs = &.{1}, .positive = true };
    assert(rational.q.toConst().eqlAbs(big_one));

    if (is_negative) {
        rational.negate();
    }

    const signedness = dest_ty.signedness(comp);
    const bits: usize = @intCast(dest_ty.bitSizeof(comp).?);

    // rational.p.truncate(rational.p.toConst(), signedness: Signedness, bit_count: usize)
    const fits = rational.p.fitsInTwosComp(signedness, bits);
    v.* = try intern(comp, .{ .int = .{ .big_int = rational.p.toConst() } });
    try rational.p.truncate(&rational.p, signedness, bits);

    if (!was_zero and v.isZero(comp)) return .nonzero_to_zero;
    if (!fits) return .out_of_range;
    if (had_fraction) return .value_changed;
    return .none;
}

/// Converts the stored value from an integer to a float.
/// `.none` value remains unchanged.
pub fn intToFloat(v: *Value, dest_ty: Type, comp: *Compilation) !void {
    if (v.opt_ref == .none) return;
    const bits = dest_ty.bitSizeof(comp).?;
    return switch (comp.interner.get(v.ref()).int) {
        inline .u64, .i64 => |data| {
            const f: Interner.Key.Float = switch (bits) {
                16 => .{ .f16 = @floatFromInt(data) },
                32 => .{ .f32 = @floatFromInt(data) },
                64 => .{ .f64 = @floatFromInt(data) },
                80 => .{ .f80 = @floatFromInt(data) },
                128 => .{ .f128 = @floatFromInt(data) },
                else => unreachable,
            };
            v.* = try intern(comp, .{ .float = f });
        },
        .big_int => |data| {
            const big_f = bigIntToFloat(data.limbs, data.positive);
            const f: Interner.Key.Float = switch (bits) {
                16 => .{ .f16 = @floatCast(big_f) },
                32 => .{ .f32 = @floatCast(big_f) },
                64 => .{ .f64 = @floatCast(big_f) },
                80 => .{ .f80 = @floatCast(big_f) },
                128 => .{ .f128 = @floatCast(big_f) },
                else => unreachable,
            };
            v.* = try intern(comp, .{ .float = f });
        },
    };
}

/// Truncates or extends bits based on type.
/// `.none` value remains unchanged.
pub fn intCast(v: *Value, dest_ty: Type, comp: *Compilation) !void {
    if (v.opt_ref == .none) return;
    const bits: usize = @intCast(dest_ty.bitSizeof(comp).?);
    var space: BigIntSpace = undefined;
    const big = v.toBigInt(&space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(@max(big.bitCountTwosComp(), bits)),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.truncate(big, dest_ty.signedness(comp), bits);

    v.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

/// Converts the stored value to a float of the specified type
/// `.none` value remains unchanged.
pub fn floatCast(v: *Value, dest_ty: Type, comp: *Compilation) !void {
    if (v.opt_ref == .none) return;
    // TODO complex values
    const bits = dest_ty.makeReal().bitSizeof(comp).?;
    const f: Interner.Key.Float = switch (bits) {
        16 => .{ .f16 = v.toFloat(f16, comp) },
        32 => .{ .f32 = v.toFloat(f32, comp) },
        64 => .{ .f64 = v.toFloat(f64, comp) },
        80 => .{ .f80 = v.toFloat(f80, comp) },
        128 => .{ .f128 = v.toFloat(f128, comp) },
        else => unreachable,
    };
    v.* = try intern(comp, .{ .float = f });
}

pub fn toFloat(v: Value, comptime T: type, comp: *const Compilation) T {
    return switch (comp.interner.get(v.ref())) {
        .int => |repr| switch (repr) {
            inline .u64, .i64 => |data| @floatFromInt(data),
            .big_int => |data| @floatCast(bigIntToFloat(data.limbs, data.positive)),
        },
        .float => |repr| switch (repr) {
            inline else => |data| @floatCast(data),
        },
        else => unreachable,
    };
}

fn bigIntToFloat(limbs: []const std.math.big.Limb, positive: bool) f128 {
    if (limbs.len == 0) return 0;

    const base = std.math.maxInt(std.math.big.Limb) + 1;
    var result: f128 = 0;
    var i: usize = limbs.len;
    while (i != 0) {
        i -= 1;
        const limb: f128 = @as(f128, @floatFromInt(limbs[i]));
        result = @mulAdd(f128, base, result, limb);
    }
    if (positive) {
        return result;
    } else {
        return -result;
    }
}

pub fn toBigInt(val: Value, space: *BigIntSpace, comp: *const Compilation) BigIntConst {
    return switch (comp.interner.get(val.ref()).int) {
        inline .u64, .i64 => |x| BigIntMutable.init(&space.limbs, x).toConst(),
        .big_int => |b| b,
    };
}

pub fn isZero(v: Value, comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    switch (v.ref()) {
        .zero => return true,
        .one => return false,
        .null => return target_util.nullRepr(comp.target) == 0,
        else => {},
    }
    const key = comp.interner.get(v.ref());
    switch (key) {
        .float => |repr| switch (repr) {
            inline else => |data| return data == 0,
        },
        .int => |repr| switch (repr) {
            inline .i64, .u64 => |data| return data == 0,
            .big_int => |data| return data.eqlZero(),
        },
        .bytes => return false,
        else => unreachable,
    }
}

/// Converts value to zero or one;
/// `.none` value remains unchanged.
pub fn boolCast(v: *Value, comp: *const Compilation) void {
    if (v.opt_ref == .none) return;
    v.* = fromBool(v.toBool(comp));
}

pub fn fromBool(b: bool) Value {
    return if (b) one else zero;
}

pub fn toBool(v: Value, comp: *const Compilation) bool {
    return !v.isZero(comp);
}

pub fn toInt(v: Value, comptime T: type, comp: *const Compilation) ?T {
    if (v.opt_ref == .none) return null;
    if (comp.interner.get(v.ref()) != .int) return null;
    var space: BigIntSpace = undefined;
    const big_int = v.toBigInt(&space, comp);
    return big_int.to(T) catch null;
}

pub fn add(res: *Value, lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !bool {
    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    if (ty.isFloat()) {
        const f: Interner.Key.Float = switch (bits) {
            16 => .{ .f16 = lhs.toFloat(f16, comp) + rhs.toFloat(f16, comp) },
            32 => .{ .f32 = lhs.toFloat(f32, comp) + rhs.toFloat(f32, comp) },
            64 => .{ .f64 = lhs.toFloat(f64, comp) + rhs.toFloat(f64, comp) },
            80 => .{ .f80 = lhs.toFloat(f80, comp) + rhs.toFloat(f80, comp) },
            128 => .{ .f128 = lhs.toFloat(f128, comp) + rhs.toFloat(f128, comp) },
            else => unreachable,
        };
        res.* = try intern(comp, .{ .float = f });
        return false;
    } else {
        var lhs_space: BigIntSpace = undefined;
        var rhs_space: BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
        const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

        const limbs = try comp.gpa.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(bits),
        );
        defer comp.gpa.free(limbs);
        var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

        const overflowed = result_bigint.addWrap(lhs_bigint, rhs_bigint, ty.signedness(comp), bits);
        res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
        return overflowed;
    }
}

pub fn sub(res: *Value, lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !bool {
    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    if (ty.isFloat()) {
        const f: Interner.Key.Float = switch (bits) {
            16 => .{ .f16 = lhs.toFloat(f16, comp) - rhs.toFloat(f16, comp) },
            32 => .{ .f32 = lhs.toFloat(f32, comp) - rhs.toFloat(f32, comp) },
            64 => .{ .f64 = lhs.toFloat(f64, comp) - rhs.toFloat(f64, comp) },
            80 => .{ .f80 = lhs.toFloat(f80, comp) - rhs.toFloat(f80, comp) },
            128 => .{ .f128 = lhs.toFloat(f128, comp) - rhs.toFloat(f128, comp) },
            else => unreachable,
        };
        res.* = try intern(comp, .{ .float = f });
        return false;
    } else {
        var lhs_space: BigIntSpace = undefined;
        var rhs_space: BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
        const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

        const limbs = try comp.gpa.alloc(
            std.math.big.Limb,
            std.math.big.int.calcTwosCompLimbCount(bits),
        );
        defer comp.gpa.free(limbs);
        var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

        const overflowed = result_bigint.subWrap(lhs_bigint, rhs_bigint, ty.signedness(comp), bits);
        res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
        return overflowed;
    }
}

pub fn mul(res: *Value, lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !bool {
    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    if (ty.isFloat()) {
        const f: Interner.Key.Float = switch (bits) {
            16 => .{ .f16 = lhs.toFloat(f16, comp) * rhs.toFloat(f16, comp) },
            32 => .{ .f32 = lhs.toFloat(f32, comp) * rhs.toFloat(f32, comp) },
            64 => .{ .f64 = lhs.toFloat(f64, comp) * rhs.toFloat(f64, comp) },
            80 => .{ .f80 = lhs.toFloat(f80, comp) * rhs.toFloat(f80, comp) },
            128 => .{ .f128 = lhs.toFloat(f128, comp) * rhs.toFloat(f128, comp) },
            else => unreachable,
        };
        res.* = try intern(comp, .{ .float = f });
        return false;
    } else {
        var lhs_space: BigIntSpace = undefined;
        var rhs_space: BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
        const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

        const limbs = try comp.gpa.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len + rhs_bigint.limbs.len,
        );
        defer comp.gpa.free(limbs);
        var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

        const limbs_buffer = try comp.gpa.alloc(
            std.math.big.Limb,
            std.math.big.int.calcMulLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len, 1),
        );
        defer comp.gpa.free(limbs_buffer);

        result_bigint.mul(lhs_bigint, rhs_bigint, limbs_buffer, comp.gpa);

        const signedness = ty.signedness(comp);
        const overflowed = !result_bigint.toConst().fitsInTwosComp(signedness, bits);
        if (overflowed) {
            result_bigint.truncate(result_bigint.toConst(), signedness, bits);
        }
        res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
        return overflowed;
    }
}

/// caller guarantees rhs != 0
pub fn div(res: *Value, lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !bool {
    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    if (ty.isFloat()) {
        const f: Interner.Key.Float = switch (bits) {
            16 => .{ .f16 = lhs.toFloat(f16, comp) / rhs.toFloat(f16, comp) },
            32 => .{ .f32 = lhs.toFloat(f32, comp) / rhs.toFloat(f32, comp) },
            64 => .{ .f64 = lhs.toFloat(f64, comp) / rhs.toFloat(f64, comp) },
            80 => .{ .f80 = lhs.toFloat(f80, comp) / rhs.toFloat(f80, comp) },
            128 => .{ .f128 = lhs.toFloat(f128, comp) / rhs.toFloat(f128, comp) },
            else => unreachable,
        };
        res.* = try intern(comp, .{ .float = f });
        return false;
    } else {
        var lhs_space: BigIntSpace = undefined;
        var rhs_space: BigIntSpace = undefined;
        const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
        const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

        const limbs_q = try comp.gpa.alloc(
            std.math.big.Limb,
            lhs_bigint.limbs.len,
        );
        defer comp.gpa.free(limbs_q);
        var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };

        const limbs_r = try comp.gpa.alloc(
            std.math.big.Limb,
            rhs_bigint.limbs.len,
        );
        defer comp.gpa.free(limbs_r);
        var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };

        const limbs_buffer = try comp.gpa.alloc(
            std.math.big.Limb,
            std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
        );
        defer comp.gpa.free(limbs_buffer);

        result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);

        res.* = try intern(comp, .{ .int = .{ .big_int = result_q.toConst() } });
        return !result_q.toConst().fitsInTwosComp(ty.signedness(comp), bits);
    }
}

/// caller guarantees rhs != 0
/// caller guarantees lhs != std.math.minInt(T) OR rhs != -1
pub fn rem(lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const signedness = ty.signedness(comp);
    if (signedness == .signed) {
        var spaces: [3]BigIntSpace = undefined;
        const min_val = BigIntMutable.init(&spaces[0].limbs, ty.minInt(comp)).toConst();
        const negative = BigIntMutable.init(&spaces[1].limbs, -1).toConst();
        const big_one = BigIntMutable.init(&spaces[2].limbs, 1).toConst();
        if (lhs_bigint.eql(min_val) and rhs_bigint.eql(negative)) {
            return .{};
        } else if (rhs_bigint.order(big_one).compare(.lt)) {
            // lhs - @divTrunc(lhs, rhs) * rhs
            var tmp: Value = undefined;
            _ = try tmp.div(lhs, rhs, ty, comp);
            _ = try tmp.mul(tmp, rhs, ty, comp);
            _ = try tmp.sub(lhs, tmp, ty, comp);
            return tmp;
        }
    }

    const limbs_q = try comp.gpa.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len,
    );
    defer comp.gpa.free(limbs_q);
    var result_q = BigIntMutable{ .limbs = limbs_q, .positive = undefined, .len = undefined };

    const limbs_r = try comp.gpa.alloc(
        std.math.big.Limb,
        rhs_bigint.limbs.len,
    );
    defer comp.gpa.free(limbs_r);
    var result_r = BigIntMutable{ .limbs = limbs_r, .positive = undefined, .len = undefined };

    const limbs_buffer = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcDivLimbsBufferLen(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    defer comp.gpa.free(limbs_buffer);

    result_q.divTrunc(&result_r, lhs_bigint, rhs_bigint, limbs_buffer);
    return intern(comp, .{ .int = .{ .big_int = result_r.toConst() } });
}

pub fn bitOr(lhs: Value, rhs: Value, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitOr(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitXor(lhs: Value, rhs: Value, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitXor(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitAnd(lhs: Value, rhs: Value, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitNot(val: Value, ty: Type, comp: *Compilation) !Value {
    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitNotWrap(val_bigint, ty.signedness(comp), bits);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn shl(res: *Value, lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !bool {
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const shift = rhs.toInt(usize, comp) orelse std.math.maxInt(usize);

    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    if (shift > bits) {
        if (lhs_bigint.positive) {
            res.* = try intern(comp, .{ .int = .{ .u64 = ty.maxInt(comp) } });
        } else {
            res.* = try intern(comp, .{ .int = .{ .i64 = ty.minInt(comp) } });
        }
        return true;
    }

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.shiftLeft(lhs_bigint, shift);
    const signedness = ty.signedness(comp);
    const overflowed = !result_bigint.toConst().fitsInTwosComp(signedness, bits);
    if (overflowed) {
        result_bigint.truncate(result_bigint.toConst(), signedness, bits);
    }
    res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
    return overflowed;
}

pub fn shr(lhs: Value, rhs: Value, ty: Type, comp: *Compilation) !Value {
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const shift = rhs.toInt(usize, comp) orelse return zero;

    const result_limbs = lhs_bigint.limbs.len -| (shift / (@sizeOf(std.math.big.Limb) * 8));
    if (result_limbs == 0) {
        // The shift is enough to remove all the bits from the number, which means the
        // result is 0 or -1 depending on the sign.
        if (lhs_bigint.positive) {
            return zero;
        } else {
            return intern(comp, .{ .int = .{ .i64 = -1 } });
        }
    }

    const bits: usize = @intCast(ty.bitSizeof(comp).?);
    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = std.math.big.int.Mutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.shiftRight(lhs_bigint, shift);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn compare(lhs: Value, op: std.math.CompareOperator, rhs: Value, comp: *const Compilation) bool {
    if (op == .eq) {
        return lhs.opt_ref == rhs.opt_ref;
    } else if (lhs.opt_ref == rhs.opt_ref) {
        return std.math.Order.eq.compare(op);
    }

    const lhs_key = comp.interner.get(lhs.ref());
    const rhs_key = comp.interner.get(rhs.ref());
    if (lhs_key == .float or rhs_key == .float) {
        const lhs_f128 = lhs.toFloat(f128, comp);
        const rhs_f128 = rhs.toFloat(f128, comp);
        return std.math.compare(lhs_f128, op, rhs_f128);
    }

    var lhs_bigint_space: BigIntSpace = undefined;
    var rhs_bigint_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_bigint_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_bigint_space, comp);
    return lhs_bigint.order(rhs_bigint).compare(op);
}

pub fn print(v: Value, ty: Type, comp: *const Compilation, w: anytype) @TypeOf(w).Error!void {
    if (ty.is(.bool)) {
        return w.writeAll(if (v.isZero(comp)) "false" else "true");
    }
    const key = comp.interner.get(v.ref());
    switch (key) {
        .null => return w.writeAll("nullptr_t"),
        .int => |repr| switch (repr) {
            inline else => |x| return w.print("{d}", .{x}),
        },
        .float => |repr| switch (repr) {
            .f16 => |x| return w.print("{d}", .{@round(@as(f64, @floatCast(x)) * 1000) / 1000}),
            .f32 => |x| return w.print("{d}", .{@round(@as(f64, @floatCast(x)) * 1000000) / 1000000}),
            inline else => |x| return w.print("{d}", .{@as(f64, @floatCast(x))}),
        },
        .bytes => |b| return printString(b, ty, comp, w),
        else => unreachable, // not a value
    }
}

pub fn printString(bytes: []const u8, ty: Type, comp: *const Compilation, w: anytype) @TypeOf(w).Error!void {
    const size: Compilation.CharUnitSize = @enumFromInt(ty.elemType().sizeof(comp).?);
    const without_null = bytes[0 .. bytes.len - @intFromEnum(size)];
    switch (size) {
        inline .@"1", .@"2" => |sz| {
            const data_slice: []const sz.Type() = @alignCast(std.mem.bytesAsSlice(sz.Type(), without_null));
            const formatter = if (sz == .@"1") std.zig.fmtEscapes(data_slice) else std.unicode.fmtUtf16le(data_slice);
            try w.print("\"{}\"", .{formatter});
        },
        .@"4" => {
            try w.writeByte('"');
            const data_slice = std.mem.bytesAsSlice(u32, without_null);
            var buf: [4]u8 = undefined;
            for (data_slice) |item| {
                if (item <= std.math.maxInt(u21) and std.unicode.utf8ValidCodepoint(@intCast(item))) {
                    const codepoint: u21 = @intCast(item);
                    const written = std.unicode.utf8Encode(codepoint, &buf) catch unreachable;
                    try w.print("{s}", .{buf[0..written]});
                } else {
                    try w.print("\\x{x}", .{item});
                }
            }
            try w.writeByte('"');
        },
    }
}
