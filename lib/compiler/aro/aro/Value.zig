const std = @import("std");
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;

const Interner = @import("../backend.zig").Interner;
const BigIntSpace = Interner.Tag.Int.BigIntSpace;

const annex_g = @import("annex_g.zig");
const Compilation = @import("Compilation.zig");
const target_util = @import("target.zig");
const QualType = @import("TypeStore.zig").QualType;

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
    if (info == .comptime_int or info.int.signedness == .unsigned) {
        return intern(comp, .{ .int = .{ .u64 = i } });
    } else {
        return intern(comp, .{ .int = .{ .i64 = i } });
    }
}

pub fn pointer(r: Interner.Key.Pointer, comp: *Compilation) !Value {
    return intern(comp, .{ .pointer = r });
}

pub fn ref(v: Value) Interner.Ref {
    std.debug.assert(v.opt_ref != .none);
    return @enumFromInt(@intFromEnum(v.opt_ref));
}

pub fn fromRef(r: Interner.Ref) Value {
    return .{ .opt_ref = @enumFromInt(@intFromEnum(r)) };
}

pub fn is(v: Value, tag: std.meta.Tag(Interner.Key), comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    return comp.interner.get(v.ref()) == tag;
}

pub fn isArithmetic(v: Value, comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    return switch (comp.interner.get(v.ref())) {
        .int, .float, .complex => true,
        else => false,
    };
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

    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var comp = Compilation.init(std.testing.allocator, arena, undefined, std.fs.cwd());
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

    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var comp = Compilation.init(std.testing.allocator, arena, undefined, std.fs.cwd());
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
pub fn floatToInt(v: *Value, dest_ty: QualType, comp: *Compilation) !FloatToIntChangeKind {
    if (v.opt_ref == .none) return .none;

    const float_val = v.toFloat(f128, comp);
    const was_zero = float_val == 0;

    if (dest_ty.is(comp, .bool)) {
        const was_one = float_val == 1.0;
        v.* = fromBool(!was_zero);
        if (was_zero or was_one) return .none;
        return .value_changed;
    } else if (dest_ty.signedness(comp) == .unsigned and float_val < 0) {
        v.* = zero;
        return .out_of_range;
    } else if (!std.math.isFinite(float_val)) {
        v.* = .{};
        return .overflow;
    }

    const signedness = dest_ty.signedness(comp);
    const bits: usize = @intCast(dest_ty.bitSizeof(comp));

    var big_int: std.math.big.int.Mutable = .{
        .limbs = try comp.gpa.alloc(std.math.big.Limb, @max(
            std.math.big.int.calcLimbLen(float_val),
            std.math.big.int.calcTwosCompLimbCount(bits),
        )),
        .len = undefined,
        .positive = undefined,
    };
    defer comp.gpa.free(big_int.limbs);
    const had_fraction = switch (big_int.setFloat(float_val, .trunc)) {
        .inexact => true,
        .exact => false,
    };

    const fits = big_int.toConst().fitsInTwosComp(signedness, bits);
    v.* = try intern(comp, .{ .int = .{ .big_int = big_int.toConst() } });
    big_int.truncate(big_int.toConst(), signedness, bits);

    if (!was_zero and v.isZero(comp)) return .nonzero_to_zero;
    if (!fits) return .out_of_range;
    if (had_fraction) return .value_changed;
    return .none;
}

/// Converts the stored value from an integer to a float.
/// `.none` value remains unchanged.
pub fn intToFloat(v: *Value, dest_ty: QualType, comp: *Compilation) !void {
    if (v.opt_ref == .none) return;

    if (dest_ty.is(comp, .complex)) {
        const bits = dest_ty.bitSizeof(comp);
        const cf: Interner.Key.Complex = switch (bits) {
            32 => .{ .cf16 = .{ v.toFloat(f16, comp), 0 } },
            64 => .{ .cf32 = .{ v.toFloat(f32, comp), 0 } },
            128 => .{ .cf64 = .{ v.toFloat(f64, comp), 0 } },
            160 => .{ .cf80 = .{ v.toFloat(f80, comp), 0 } },
            256 => .{ .cf128 = .{ v.toFloat(f128, comp), 0 } },
            else => unreachable,
        };
        v.* = try intern(comp, .{ .complex = cf });
        return;
    }
    const bits = dest_ty.bitSizeof(comp);
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

pub const IntCastChangeKind = enum {
    /// value did not change
    none,
    /// Truncation occurred (e.g., i32 to i16)
    truncated,
    /// Sign conversion occurred (e.g., i32 to u32)
    sign_changed,
};

/// Truncates or extends bits based on type.
/// `.none` value remains unchanged.
pub fn intCast(v: *Value, dest_ty: QualType, comp: *Compilation) !IntCastChangeKind {
    if (v.opt_ref == .none) return .none;
    const key = comp.interner.get(v.ref());
    if (key == .pointer or key == .bytes) return .none;

    const dest_bits: usize = @intCast(dest_ty.bitSizeof(comp));
    const dest_signed = dest_ty.signedness(comp) == .signed;

    var space: BigIntSpace = undefined;
    const big = key.toBigInt(&space);
    const value_bits = big.bitCountTwosComp();

    // if big is negative, then is signed.
    const src_signed = !big.positive;
    const sign_change = src_signed != dest_signed;

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(@max(value_bits, dest_bits)),
    );
    defer comp.gpa.free(limbs);

    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.truncate(big, dest_ty.signedness(comp), dest_bits);

    v.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });

    const truncation_occurred = value_bits > dest_bits;
    if (truncation_occurred) {
        return .truncated;
    } else if (sign_change) {
        return .sign_changed;
    } else {
        return .none;
    }
}

/// Converts the stored value to a float of the specified type
/// `.none` value remains unchanged.
pub fn floatCast(v: *Value, dest_ty: QualType, comp: *Compilation) !void {
    if (v.opt_ref == .none) return;
    const bits = dest_ty.bitSizeof(comp);
    if (dest_ty.is(comp, .complex)) {
        const cf: Interner.Key.Complex = switch (bits) {
            32 => .{ .cf16 = .{ v.toFloat(f16, comp), v.imag(f16, comp) } },
            64 => .{ .cf32 = .{ v.toFloat(f32, comp), v.imag(f32, comp) } },
            128 => .{ .cf64 = .{ v.toFloat(f64, comp), v.imag(f64, comp) } },
            160 => .{ .cf80 = .{ v.toFloat(f80, comp), v.imag(f80, comp) } },
            256 => .{ .cf128 = .{ v.toFloat(f128, comp), v.imag(f128, comp) } },
            else => unreachable,
        };
        v.* = try intern(comp, .{ .complex = cf });
    } else {
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
}

pub fn imag(v: Value, comptime T: type, comp: *const Compilation) T {
    return switch (comp.interner.get(v.ref())) {
        .int => 0.0,
        .float => 0.0,
        .complex => |repr| switch (repr) {
            inline else => |components| return @floatCast(components[1]),
        },
        else => unreachable,
    };
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
        .complex => |repr| switch (repr) {
            inline else => |components| @floatCast(components[0]),
        },
        else => unreachable,
    };
}

pub fn realPart(v: Value, comp: *Compilation) !Value {
    if (v.opt_ref == .none) return v;
    return switch (comp.interner.get(v.ref())) {
        .int, .float => v,
        .complex => |repr| Value.intern(comp, switch (repr) {
            .cf16 => |components| .{ .float = .{ .f16 = components[0] } },
            .cf32 => |components| .{ .float = .{ .f32 = components[0] } },
            .cf64 => |components| .{ .float = .{ .f64 = components[0] } },
            .cf80 => |components| .{ .float = .{ .f80 = components[0] } },
            .cf128 => |components| .{ .float = .{ .f128 = components[0] } },
        }),
        else => unreachable,
    };
}

pub fn imaginaryPart(v: Value, comp: *Compilation) !Value {
    if (v.opt_ref == .none) return v;
    return switch (comp.interner.get(v.ref())) {
        .int, .float => Value.zero,
        .complex => |repr| Value.intern(comp, switch (repr) {
            .cf16 => |components| .{ .float = .{ .f16 = components[1] } },
            .cf32 => |components| .{ .float = .{ .f32 = components[1] } },
            .cf64 => |components| .{ .float = .{ .f64 = components[1] } },
            .cf80 => |components| .{ .float = .{ .f80 = components[1] } },
            .cf128 => |components| .{ .float = .{ .f128 = components[1] } },
        }),
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

fn toBigInt(val: Value, space: *BigIntSpace, comp: *const Compilation) BigIntConst {
    return comp.interner.get(val.ref()).toBigInt(space);
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
        .complex => |repr| switch (repr) {
            inline else => |data| return data[0] == 0.0 and data[1] == 0.0,
        },
        .bytes => return false,
        .pointer => return false,
        else => unreachable,
    }
}

const IsInfKind = enum(i32) {
    negative = -1,
    finite = 0,
    positive = 1,
    unknown = std.math.maxInt(i32),
};

pub fn isInfSign(v: Value, comp: *const Compilation) IsInfKind {
    if (v.opt_ref == .none) return .unknown;
    return switch (comp.interner.get(v.ref())) {
        .float => |repr| switch (repr) {
            inline else => |data| if (std.math.isPositiveInf(data)) .positive else if (std.math.isNegativeInf(data)) .negative else .finite,
        },
        else => .unknown,
    };
}
pub fn isInf(v: Value, comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    return switch (comp.interner.get(v.ref())) {
        .float => |repr| switch (repr) {
            inline else => |data| std.math.isInf(data),
        },
        .complex => |repr| switch (repr) {
            inline else => |components| std.math.isInf(components[0]) or std.math.isInf(components[1]),
        },
        else => false,
    };
}

pub fn isNan(v: Value, comp: *const Compilation) bool {
    if (v.opt_ref == .none) return false;
    return switch (comp.interner.get(v.ref())) {
        .float => |repr| switch (repr) {
            inline else => |data| std.math.isNan(data),
        },
        .complex => |repr| switch (repr) {
            inline else => |components| std.math.isNan(components[0]) or std.math.isNan(components[1]),
        },
        else => false,
    };
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
    const key = comp.interner.get(v.ref());
    if (key != .int) return null;
    var space: BigIntSpace = undefined;
    const big_int = key.toBigInt(&space);
    return big_int.toInt(T) catch null;
}

pub fn toBytes(v: Value, comp: *const Compilation) []const u8 {
    assert(v.opt_ref != .none);
    const key = comp.interner.get(v.ref());
    return key.bytes;
}

const ComplexOp = enum {
    add,
    sub,
};

fn complexAddSub(lhs: Value, rhs: Value, comptime T: type, op: ComplexOp, comp: *Compilation) !Value {
    const res_re = switch (op) {
        .add => lhs.toFloat(T, comp) + rhs.toFloat(T, comp),
        .sub => lhs.toFloat(T, comp) - rhs.toFloat(T, comp),
    };
    const res_im = switch (op) {
        .add => lhs.imag(T, comp) + rhs.imag(T, comp),
        .sub => lhs.imag(T, comp) - rhs.imag(T, comp),
    };

    return switch (T) {
        f16 => intern(comp, .{ .complex = .{ .cf16 = .{ res_re, res_im } } }),
        f32 => intern(comp, .{ .complex = .{ .cf32 = .{ res_re, res_im } } }),
        f64 => intern(comp, .{ .complex = .{ .cf64 = .{ res_re, res_im } } }),
        f80 => intern(comp, .{ .complex = .{ .cf80 = .{ res_re, res_im } } }),
        f128 => intern(comp, .{ .complex = .{ .cf128 = .{ res_re, res_im } } }),
        else => unreachable,
    };
}

pub fn add(res: *Value, lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !bool {
    const bits: usize = @intCast(qt.bitSizeof(comp));
    const scalar_kind = qt.scalarKind(comp);
    if (scalar_kind.isFloat()) {
        if (scalar_kind == .complex_float) {
            res.* = switch (bits) {
                32 => try complexAddSub(lhs, rhs, f16, .add, comp),
                64 => try complexAddSub(lhs, rhs, f32, .add, comp),
                128 => try complexAddSub(lhs, rhs, f64, .add, comp),
                160 => try complexAddSub(lhs, rhs, f80, .add, comp),
                256 => try complexAddSub(lhs, rhs, f128, .add, comp),
                else => unreachable,
            };
            return false;
        }
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
    }
    const lhs_key = comp.interner.get(lhs.ref());
    const rhs_key = comp.interner.get(rhs.ref());
    if (lhs_key == .bytes or rhs_key == .bytes) {
        res.* = .{};
        return false;
    }
    if (lhs_key == .pointer or rhs_key == .pointer) {
        const rel, const index = if (lhs_key == .pointer)
            .{ lhs_key.pointer, rhs }
        else
            .{ rhs_key.pointer, lhs };

        const elem_size = try int(qt.childType(comp).sizeofOrNull(comp) orelse 1, comp);
        var total_offset: Value = undefined;
        const mul_overflow = try total_offset.mul(elem_size, index, comp.type_store.ptrdiff, comp);
        const old_offset = fromRef(rel.offset);
        const add_overflow = try total_offset.add(total_offset, old_offset, comp.type_store.ptrdiff, comp);
        _ = try total_offset.intCast(comp.type_store.ptrdiff, comp);
        res.* = try pointer(.{ .node = rel.node, .offset = total_offset.ref() }, comp);
        return mul_overflow or add_overflow;
    }

    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs_key.toBigInt(&lhs_space);
    const rhs_bigint = rhs_key.toBigInt(&rhs_space);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    const overflowed = result_bigint.addWrap(lhs_bigint, rhs_bigint, qt.signedness(comp), bits);
    res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
    return overflowed;
}

pub fn negate(res: *Value, val: Value, qt: QualType, comp: *Compilation) !bool {
    return res.sub(zero, val, qt, undefined, comp);
}

pub fn decrement(res: *Value, val: Value, qt: QualType, comp: *Compilation) !bool {
    return res.sub(val, one, qt, undefined, comp);
}

/// elem_size is only used when subtracting two pointers, so we can scale the result by the size of the element type
pub fn sub(res: *Value, lhs: Value, rhs: Value, qt: QualType, elem_size: u64, comp: *Compilation) !bool {
    const bits: usize = @intCast(qt.bitSizeof(comp));
    const scalar_kind = qt.scalarKind(comp);
    if (scalar_kind.isFloat()) {
        if (scalar_kind == .complex_float) {
            res.* = switch (bits) {
                32 => try complexAddSub(lhs, rhs, f16, .sub, comp),
                64 => try complexAddSub(lhs, rhs, f32, .sub, comp),
                128 => try complexAddSub(lhs, rhs, f64, .sub, comp),
                160 => try complexAddSub(lhs, rhs, f80, .sub, comp),
                256 => try complexAddSub(lhs, rhs, f128, .sub, comp),
                else => unreachable,
            };
            return false;
        }
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
    }
    const lhs_key = comp.interner.get(lhs.ref());
    const rhs_key = comp.interner.get(rhs.ref());
    if (lhs_key == .bytes or rhs_key == .bytes) {
        res.* = .{};
        return false;
    }
    if (lhs_key == .pointer and rhs_key == .pointer) {
        const lhs_pointer = lhs_key.pointer;
        const rhs_pointer = rhs_key.pointer;
        if (lhs_pointer.node != rhs_pointer.node) {
            res.* = .{};
            return false;
        }
        const lhs_offset = fromRef(lhs_pointer.offset);
        const rhs_offset = fromRef(rhs_pointer.offset);
        const overflowed = try res.sub(lhs_offset, rhs_offset, comp.type_store.ptrdiff, undefined, comp);
        const rhs_size = try int(elem_size, comp);
        _ = try res.div(res.*, rhs_size, comp.type_store.ptrdiff, comp);
        return overflowed;
    } else if (lhs_key == .pointer) {
        const rel = lhs_key.pointer;

        const lhs_size = try int(elem_size, comp);
        var total_offset: Value = undefined;
        const mul_overflow = try total_offset.mul(lhs_size, rhs, comp.type_store.ptrdiff, comp);
        const old_offset = fromRef(rel.offset);
        const add_overflow = try total_offset.sub(old_offset, total_offset, comp.type_store.ptrdiff, undefined, comp);
        _ = try total_offset.intCast(comp.type_store.ptrdiff, comp);
        res.* = try pointer(.{ .node = rel.node, .offset = total_offset.ref() }, comp);
        return mul_overflow or add_overflow;
    }

    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs_key.toBigInt(&lhs_space);
    const rhs_bigint = rhs_key.toBigInt(&rhs_space);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    const overflowed = result_bigint.subWrap(lhs_bigint, rhs_bigint, qt.signedness(comp), bits);
    res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
    return overflowed;
}

pub fn mul(res: *Value, lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !bool {
    const bits: usize = @intCast(qt.bitSizeof(comp));
    const scalar_kind = qt.scalarKind(comp);
    if (scalar_kind.isFloat()) {
        if (scalar_kind == .complex_float) {
            const cf: Interner.Key.Complex = switch (bits) {
                32 => .{ .cf16 = annex_g.complexFloatMul(f16, lhs.toFloat(f16, comp), lhs.imag(f16, comp), rhs.toFloat(f16, comp), rhs.imag(f16, comp)) },
                64 => .{ .cf32 = annex_g.complexFloatMul(f32, lhs.toFloat(f32, comp), lhs.imag(f32, comp), rhs.toFloat(f32, comp), rhs.imag(f32, comp)) },
                128 => .{ .cf64 = annex_g.complexFloatMul(f64, lhs.toFloat(f64, comp), lhs.imag(f64, comp), rhs.toFloat(f64, comp), rhs.imag(f64, comp)) },
                160 => .{ .cf80 = annex_g.complexFloatMul(f80, lhs.toFloat(f80, comp), lhs.imag(f80, comp), rhs.toFloat(f80, comp), rhs.imag(f80, comp)) },
                256 => .{ .cf128 = annex_g.complexFloatMul(f128, lhs.toFloat(f128, comp), lhs.imag(f128, comp), rhs.toFloat(f128, comp), rhs.imag(f128, comp)) },
                else => unreachable,
            };
            res.* = try intern(comp, .{ .complex = cf });
            return false;
        }
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

        const signedness = qt.signedness(comp);
        const overflowed = !result_bigint.toConst().fitsInTwosComp(signedness, bits);
        if (overflowed) {
            result_bigint.truncate(result_bigint.toConst(), signedness, bits);
        }
        res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
        return overflowed;
    }
}

/// caller guarantees rhs != 0
pub fn div(res: *Value, lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !bool {
    const bits: usize = @intCast(qt.bitSizeof(comp));
    const scalar_kind = qt.scalarKind(comp);
    if (scalar_kind.isFloat()) {
        if (scalar_kind == .complex_float) {
            const cf: Interner.Key.Complex = switch (bits) {
                32 => .{ .cf16 = annex_g.complexFloatDiv(f16, lhs.toFloat(f16, comp), lhs.imag(f16, comp), rhs.toFloat(f16, comp), rhs.imag(f16, comp)) },
                64 => .{ .cf32 = annex_g.complexFloatDiv(f32, lhs.toFloat(f32, comp), lhs.imag(f32, comp), rhs.toFloat(f32, comp), rhs.imag(f32, comp)) },
                128 => .{ .cf64 = annex_g.complexFloatDiv(f64, lhs.toFloat(f64, comp), lhs.imag(f64, comp), rhs.toFloat(f64, comp), rhs.imag(f64, comp)) },
                160 => .{ .cf80 = annex_g.complexFloatDiv(f80, lhs.toFloat(f80, comp), lhs.imag(f80, comp), rhs.toFloat(f80, comp), rhs.imag(f80, comp)) },
                256 => .{ .cf128 = annex_g.complexFloatDiv(f128, lhs.toFloat(f128, comp), lhs.imag(f128, comp), rhs.toFloat(f128, comp), rhs.imag(f128, comp)) },
                else => unreachable,
            };
            res.* = try intern(comp, .{ .complex = cf });
            return false;
        }
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
        return !result_q.toConst().fitsInTwosComp(qt.signedness(comp), bits);
    }
}

/// caller guarantees rhs != 0
/// caller guarantees lhs != std.math.minInt(T) OR rhs != -1
pub fn rem(lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    if (qt.signedness(comp) == .signed) {
        var spaces: [2]BigIntSpace = undefined;
        const min_val = try Value.minInt(qt, comp);
        const negative = BigIntMutable.init(&spaces[0].limbs, -1).toConst();
        const big_one = BigIntMutable.init(&spaces[1].limbs, 1).toConst();
        if (lhs.compare(.eq, min_val, comp) and rhs_bigint.eql(negative)) {
            return .{};
        } else if (rhs_bigint.order(big_one).compare(.lt)) {
            // lhs - @divTrunc(lhs, rhs) * rhs
            var tmp: Value = undefined;
            _ = try tmp.div(lhs, rhs, qt, comp);
            _ = try tmp.mul(tmp, rhs, qt, comp);
            _ = try tmp.sub(lhs, tmp, qt, undefined, comp);
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
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitOr(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitXor(lhs: Value, rhs: Value, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const extra = @intFromBool(lhs_bigint.positive != rhs_bigint.positive);
    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + extra,
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitXor(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitAnd(lhs: Value, rhs: Value, comp: *Compilation) !Value {
    var lhs_space: BigIntSpace = undefined;
    var rhs_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_space, comp);

    const limb_count = if (lhs_bigint.positive and rhs_bigint.positive)
        @min(lhs_bigint.limbs.len, rhs_bigint.limbs.len)
    else if (lhs_bigint.positive)
        lhs_bigint.limbs.len
    else if (rhs_bigint.positive)
        rhs_bigint.limbs.len
    else
        @max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1;

    const limbs = try comp.gpa.alloc(std.math.big.Limb, limb_count);
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitAnd(lhs_bigint, rhs_bigint);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn bitNot(val: Value, qt: QualType, comp: *Compilation) !Value {
    const bits: usize = @intCast(qt.bitSizeof(comp));
    var val_space: Value.BigIntSpace = undefined;
    const val_bigint = val.toBigInt(&val_space, comp);

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.bitNotWrap(val_bigint, qt.signedness(comp), bits);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn shl(res: *Value, lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !bool {
    var lhs_space: Value.BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_space, comp);
    const shift = rhs.toInt(usize, comp) orelse std.math.maxInt(usize);

    const bits: usize = @intCast(qt.bitSizeof(comp));
    if (shift > bits) {
        if (lhs_bigint.positive) {
            res.* = try Value.maxInt(qt, comp);
        } else {
            res.* = try Value.minInt(qt, comp);
        }
        return true;
    }

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        lhs_bigint.limbs.len + (shift / (@sizeOf(std.math.big.Limb) * 8)) + 1,
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.shiftLeft(lhs_bigint, shift);
    const signedness = qt.signedness(comp);
    const overflowed = !result_bigint.toConst().fitsInTwosComp(signedness, bits);
    if (overflowed) {
        result_bigint.truncate(result_bigint.toConst(), signedness, bits);
    }
    res.* = try intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
    return overflowed;
}

pub fn shr(lhs: Value, rhs: Value, qt: QualType, comp: *Compilation) !Value {
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

    const bits: usize = @intCast(qt.bitSizeof(comp));
    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(bits),
    );
    defer comp.gpa.free(limbs);
    var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };

    result_bigint.shiftRight(lhs_bigint, shift);
    return intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn complexConj(val: Value, qt: QualType, comp: *Compilation) !Value {
    const bits = qt.bitSizeof(comp);
    const cf: Interner.Key.Complex = switch (bits) {
        32 => .{ .cf16 = .{ val.toFloat(f16, comp), -val.imag(f16, comp) } },
        64 => .{ .cf32 = .{ val.toFloat(f32, comp), -val.imag(f32, comp) } },
        128 => .{ .cf64 = .{ val.toFloat(f64, comp), -val.imag(f64, comp) } },
        160 => .{ .cf80 = .{ val.toFloat(f80, comp), -val.imag(f80, comp) } },
        256 => .{ .cf128 = .{ val.toFloat(f128, comp), -val.imag(f128, comp) } },
        else => unreachable,
    };
    return intern(comp, .{ .complex = cf });
}

fn shallowCompare(lhs: Value, op: std.math.CompareOperator, rhs: Value) ?bool {
    if (op == .eq) {
        return lhs.opt_ref == rhs.opt_ref;
    } else if (lhs.opt_ref == rhs.opt_ref) {
        return std.math.Order.eq.compare(op);
    }
    return null;
}

pub fn compare(lhs: Value, op: std.math.CompareOperator, rhs: Value, comp: *const Compilation) bool {
    if (lhs.shallowCompare(op, rhs)) |val| return val;

    const lhs_key = comp.interner.get(lhs.ref());
    const rhs_key = comp.interner.get(rhs.ref());
    if (lhs_key == .float or rhs_key == .float) {
        const lhs_f128 = lhs.toFloat(f128, comp);
        const rhs_f128 = rhs.toFloat(f128, comp);
        return std.math.compare(lhs_f128, op, rhs_f128);
    }
    if (lhs_key == .complex or rhs_key == .complex) {
        assert(op == .neq);
        const real_equal = std.math.compare(lhs.toFloat(f128, comp), .eq, rhs.toFloat(f128, comp));
        const imag_equal = std.math.compare(lhs.imag(f128, comp), .eq, rhs.imag(f128, comp));
        return !real_equal or !imag_equal;
    }

    var lhs_bigint_space: BigIntSpace = undefined;
    var rhs_bigint_space: BigIntSpace = undefined;
    const lhs_bigint = lhs.toBigInt(&lhs_bigint_space, comp);
    const rhs_bigint = rhs.toBigInt(&rhs_bigint_space, comp);
    return lhs_bigint.order(rhs_bigint).compare(op);
}

/// Returns null for values that cannot be compared at compile time (e.g. `&x < &y`) for globals `x` and `y`.
pub fn comparePointers(lhs: Value, op: std.math.CompareOperator, rhs: Value, comp: *const Compilation) ?bool {
    if (lhs.shallowCompare(op, rhs)) |val| return val;

    const lhs_key = comp.interner.get(lhs.ref());
    const rhs_key = comp.interner.get(rhs.ref());

    if (lhs_key == .pointer and rhs_key == .pointer) {
        const lhs_pointer = lhs_key.pointer;
        const rhs_pointer = rhs_key.pointer;
        switch (op) {
            .eq => if (lhs_pointer.node != rhs_pointer.node) return false,
            .neq => if (lhs_pointer.node != rhs_pointer.node) return true,
            else => if (lhs_pointer.node != rhs_pointer.node) return null,
        }

        const lhs_offset = fromRef(lhs_pointer.offset);
        const rhs_offset = fromRef(rhs_pointer.offset);
        return lhs_offset.compare(op, rhs_offset, comp);
    }
    return null;
}

fn twosCompIntLimit(limit: std.math.big.int.TwosCompIntLimit, qt: QualType, comp: *Compilation) !Value {
    const signedness = qt.signedness(comp);
    if (limit == .min and signedness == .unsigned) return Value.zero;
    const mag_bits: usize = @intCast(qt.bitSizeof(comp));
    switch (mag_bits) {
        inline 8, 16, 32, 64 => |bits| {
            if (limit == .min) return Value.int(@as(i64, std.math.minInt(std.meta.Int(.signed, bits))), comp);
            return switch (signedness) {
                inline else => |sign| Value.int(std.math.maxInt(std.meta.Int(sign, bits)), comp),
            };
        },
        else => {},
    }

    const sign_bits = @intFromBool(signedness == .signed);
    const total_bits = mag_bits + sign_bits;

    const limbs = try comp.gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(total_bits),
    );
    defer comp.gpa.free(limbs);

    var result_bigint: BigIntMutable = .{ .limbs = limbs, .positive = undefined, .len = undefined };
    result_bigint.setTwosCompIntLimit(limit, signedness, mag_bits);
    return Value.intern(comp, .{ .int = .{ .big_int = result_bigint.toConst() } });
}

pub fn minInt(qt: QualType, comp: *Compilation) !Value {
    return twosCompIntLimit(.min, qt, comp);
}

pub fn maxInt(qt: QualType, comp: *Compilation) !Value {
    return twosCompIntLimit(.max, qt, comp);
}

const NestedPrint = union(enum) {
    pointer: struct {
        node: u32,
        offset: Value,
    },
};

pub fn printPointer(offset: Value, base: []const u8, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeByte('&');
    try w.writeAll(base);
    if (!offset.isZero(comp)) {
        const maybe_nested = try offset.print(comp.type_store.ptrdiff, comp, w);
        std.debug.assert(maybe_nested == null);
    }
}

pub fn print(v: Value, qt: QualType, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!?NestedPrint {
    if (qt.is(comp, .bool)) {
        try w.writeAll(if (v.isZero(comp)) "false" else "true");
        return null;
    }
    const key = comp.interner.get(v.ref());
    switch (key) {
        .null => try w.writeAll("nullptr_t"),
        .int => |repr| switch (repr) {
            inline else => |x| try w.print("{d}", .{x}),
        },
        .float => |repr| switch (repr) {
            .f16 => |x| try w.print("{d}", .{@round(@as(f64, @floatCast(x)) * 1000) / 1000}),
            .f32 => |x| try w.print("{d}", .{@round(@as(f64, @floatCast(x)) * 1000000) / 1000000}),
            inline else => |x| try w.print("{d}", .{@as(f64, @floatCast(x))}),
        },
        .bytes => |b| try printString(b, qt, comp, w),
        .complex => |repr| switch (repr) {
            .cf32 => |components| try w.print("{d} + {d}i", .{ @round(@as(f64, @floatCast(components[0])) * 1000000) / 1000000, @round(@as(f64, @floatCast(components[1])) * 1000000) / 1000000 }),
            inline else => |components| try w.print("{d} + {d}i", .{ @as(f64, @floatCast(components[0])), @as(f64, @floatCast(components[1])) }),
        },
        .pointer => |ptr| return .{ .pointer = .{ .node = ptr.node, .offset = fromRef(ptr.offset) } },
        else => unreachable, // not a value
    }
    return null;
}

pub fn printString(bytes: []const u8, qt: QualType, comp: *const Compilation, w: *std.Io.Writer) std.Io.Writer.Error!void {
    const size: Compilation.CharUnitSize = @enumFromInt(qt.childType(comp).sizeof(comp));
    const without_null = bytes[0 .. bytes.len - @intFromEnum(size)];
    try w.writeByte('"');
    switch (size) {
        .@"1" => try std.zig.stringEscape(without_null, w),
        .@"2" => {
            var items: [2]u16 = undefined;
            var i: usize = 0;
            while (i < without_null.len) {
                @memcpy(std.mem.sliceAsBytes(items[0..1]), without_null[i..][0..2]);
                i += 2;
                const is_surrogate = std.unicode.utf16IsHighSurrogate(items[0]);
                if (is_surrogate and i < without_null.len) {
                    @memcpy(std.mem.sliceAsBytes(items[1..2]), without_null[i..][0..2]);
                    if (std.unicode.utf16DecodeSurrogatePair(&items)) |decoded| {
                        i += 2;
                        try w.print("{u}", .{decoded});
                    } else |_| {
                        try w.print("\\x{x}", .{items[0]});
                    }
                } else if (is_surrogate) {
                    try w.print("\\x{x}", .{items[0]});
                } else {
                    try w.print("{u}", .{items[0]});
                }
            }
        },
        .@"4" => {
            var item: [1]u32 = undefined;
            const data_slice = std.mem.sliceAsBytes(item[0..1]);
            for (0..@divExact(without_null.len, 4)) |n| {
                @memcpy(data_slice, without_null[n * 4 ..][0..4]);
                if (item[0] <= std.math.maxInt(u21) and std.unicode.utf8ValidCodepoint(@intCast(item[0]))) {
                    const codepoint: u21 = @intCast(item[0]);
                    try w.print("{u}", .{codepoint});
                } else {
                    try w.print("\\x{x}", .{item[0]});
                }
            }
        },
    }
    try w.writeByte('"');
}
