const std = @import("std");
const assert = std.debug.assert;
const Compilation = @import("Compilation.zig");
const Type = @import("Type.zig");

const Value = @This();

pub const ByteRange = struct {
    start: u32,
    end: u32,

    pub fn len(self: ByteRange) u32 {
        return self.end - self.start;
    }

    pub fn trim(self: ByteRange, amount: u32) ByteRange {
        std.debug.assert(self.start <= self.end - amount);
        return .{ .start = self.start, .end = self.end - amount };
    }

    pub fn slice(self: ByteRange, all_bytes: []const u8) []const u8 {
        return all_bytes[self.start..self.end];
    }
};

tag: Tag = .unavailable,
data: union {
    none: void,
    int: u64,
    float: f64,
    bytes: ByteRange,
} = .{ .none = {} },

const Tag = enum {
    unavailable,
    nullptr_t,
    /// int is used to store integer, boolean and pointer values
    int,
    float,
    bytes,
};

pub fn zero(v: Value) Value {
    return switch (v.tag) {
        .int => int(0),
        .float => float(0),
        else => unreachable,
    };
}

pub fn one(v: Value) Value {
    return switch (v.tag) {
        .int => int(1),
        .float => float(1),
        else => unreachable,
    };
}

pub fn int(v: anytype) Value {
    if (@TypeOf(v) == comptime_int or @typeInfo(@TypeOf(v)).Int.signedness == .unsigned)
        return .{ .tag = .int, .data = .{ .int = v } }
    else
        return .{ .tag = .int, .data = .{ .int = @bitCast(@as(i64, v)) } };
}

pub fn float(v: anytype) Value {
    return .{ .tag = .float, .data = .{ .float = v } };
}

pub fn bytes(start: u32, end: u32) Value {
    return .{ .tag = .bytes, .data = .{ .bytes = .{ .start = start, .end = end } } };
}

pub fn signExtend(v: Value, old_ty: Type, comp: *Compilation) i64 {
    const size = old_ty.sizeof(comp).?;
    return switch (size) {
        1 => v.getInt(i8),
        2 => v.getInt(i16),
        4 => v.getInt(i32),
        8 => v.getInt(i64),
        else => unreachable,
    };
}

/// Number of bits needed to hold `v` which is of type `ty`.
/// Asserts that `v` is not negative
pub fn minUnsignedBits(v: Value, ty: Type, comp: *const Compilation) usize {
    assert(v.compare(.gte, Value.int(0), ty, comp));
    return switch (ty.sizeof(comp).?) {
        1 => 8 - @clz(v.getInt(u8)),
        2 => 16 - @clz(v.getInt(u16)),
        4 => 32 - @clz(v.getInt(u32)),
        8 => 64 - @clz(v.getInt(u64)),
        else => unreachable,
    };
}

test "minUnsignedBits" {
    const Test = struct {
        fn checkIntBits(comp: *const Compilation, specifier: Type.Specifier, v: u64, expected: usize) !void {
            const val = Value.int(v);
            try std.testing.expectEqual(expected, val.minUnsignedBits(.{ .specifier = specifier }, comp));
        }
    };

    var comp = Compilation.init(std.testing.allocator);
    defer comp.deinit();
    comp.target = (try std.zig.CrossTarget.parse(.{ .arch_os_abi = "x86_64-linux-gnu" })).toTarget();

    try Test.checkIntBits(&comp, .int, 0, 0);
    try Test.checkIntBits(&comp, .int, 1, 1);
    try Test.checkIntBits(&comp, .int, 2, 2);
    try Test.checkIntBits(&comp, .int, std.math.maxInt(i8), 7);
    try Test.checkIntBits(&comp, .int, std.math.maxInt(u8), 8);
    try Test.checkIntBits(&comp, .int, std.math.maxInt(i16), 15);
    try Test.checkIntBits(&comp, .int, std.math.maxInt(u16), 16);
    try Test.checkIntBits(&comp, .int, std.math.maxInt(i32), 31);
    try Test.checkIntBits(&comp, .uint, std.math.maxInt(u32), 32);
    try Test.checkIntBits(&comp, .long, std.math.maxInt(i64), 63);
    try Test.checkIntBits(&comp, .ulong, std.math.maxInt(u64), 64);
    try Test.checkIntBits(&comp, .long_long, std.math.maxInt(i64), 63);
    try Test.checkIntBits(&comp, .ulong_long, std.math.maxInt(u64), 64);
}

/// Minimum number of bits needed to represent `v` in 2's complement notation
/// Asserts that `v` is negative.
pub fn minSignedBits(v: Value, ty: Type, comp: *const Compilation) usize {
    assert(v.compare(.lt, Value.int(0), ty, comp));
    return switch (ty.sizeof(comp).?) {
        1 => 8 - @clz(~v.getInt(u8)) + 1,
        2 => 16 - @clz(~v.getInt(u16)) + 1,
        4 => 32 - @clz(~v.getInt(u32)) + 1,
        8 => 64 - @clz(~v.getInt(u64)) + 1,
        else => unreachable,
    };
}

test "minSignedBits" {
    const Test = struct {
        fn checkIntBits(comp: *const Compilation, specifier: Type.Specifier, v: i64, expected: usize) !void {
            const val = Value.int(v);
            try std.testing.expectEqual(expected, val.minSignedBits(.{ .specifier = specifier }, comp));
        }
    };

    var comp = Compilation.init(std.testing.allocator);
    defer comp.deinit();
    comp.target = (try std.zig.CrossTarget.parse(.{ .arch_os_abi = "x86_64-linux-gnu" })).toTarget();

    for ([_]Type.Specifier{ .int, .long, .long_long }) |specifier| {
        try Test.checkIntBits(&comp, specifier, -1, 1);
        try Test.checkIntBits(&comp, specifier, -2, 2);
        try Test.checkIntBits(&comp, specifier, -10, 5);
        try Test.checkIntBits(&comp, specifier, -101, 8);

        try Test.checkIntBits(&comp, specifier, std.math.minInt(i8), 8);
        try Test.checkIntBits(&comp, specifier, std.math.minInt(i16), 16);
        try Test.checkIntBits(&comp, specifier, std.math.minInt(i32), 32);
    }

    try Test.checkIntBits(&comp, .long, std.math.minInt(i64), 64);
    try Test.checkIntBits(&comp, .long_long, std.math.minInt(i64), 64);
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

fn floatToIntExtra(comptime FloatTy: type, int_ty_signedness: std.builtin.Signedness, int_ty_size: u16, v: *Value) FloatToIntChangeKind {
    const float_val = v.getFloat(FloatTy);
    const was_zero = float_val == 0;
    const had_fraction = std.math.modf(float_val).fpart != 0;

    switch (int_ty_signedness) {
        inline else => |signedness| switch (int_ty_size) {
            inline 1, 2, 4, 8 => |bytecount| {
                const IntTy = std.meta.Int(signedness, bytecount * 8);

                const intVal = std.math.lossyCast(IntTy, float_val);
                v.* = int(intVal);
                if (!was_zero and v.isZero()) return .nonzero_to_zero;
                if (float_val <= std.math.minInt(IntTy) or float_val >= std.math.maxInt(IntTy)) return .out_of_range;
                if (had_fraction) return .value_changed;
                return .none;
            },
            else => unreachable,
        },
    }
}

/// Converts the stored value from a float to an integer.
/// `.unavailable` value remains unchanged.
pub fn floatToInt(v: *Value, old_ty: Type, new_ty: Type, comp: *Compilation) FloatToIntChangeKind {
    assert(old_ty.isFloat());
    if (v.tag == .unavailable) return .none;
    if (new_ty.is(.bool)) {
        const was_zero = v.isZero();
        const was_one = v.getFloat(f64) == 1.0;
        v.toBool();
        if (was_zero or was_one) return .none;
        return .value_changed;
    } else if (new_ty.isUnsignedInt(comp) and v.data.float < 0) {
        v.* = int(0);
        return .out_of_range;
    } else if (!std.math.isFinite(v.data.float)) {
        v.tag = .unavailable;
        return .overflow;
    }
    const old_size = old_ty.sizeof(comp).?;
    const new_size: u16 = @intCast(new_ty.sizeof(comp).?);
    if (new_ty.isUnsignedInt(comp)) switch (old_size) {
        1 => unreachable, // promoted to int
        2 => unreachable, // promoted to int
        4 => return floatToIntExtra(f32, .unsigned, new_size, v),
        8 => return floatToIntExtra(f64, .unsigned, new_size, v),
        else => unreachable,
    } else switch (old_size) {
        1 => unreachable, // promoted to int
        2 => unreachable, // promoted to int
        4 => return floatToIntExtra(f32, .signed, new_size, v),
        8 => return floatToIntExtra(f64, .signed, new_size, v),
        else => unreachable,
    }
}

/// Converts the stored value from an integer to a float.
/// `.unavailable` value remains unchanged.
pub fn intToFloat(v: *Value, old_ty: Type, new_ty: Type, comp: *Compilation) void {
    assert(old_ty.isInt());
    if (v.tag == .unavailable) return;
    if (!new_ty.isReal() or new_ty.sizeof(comp).? > 8) {
        v.tag = .unavailable;
    } else if (old_ty.isUnsignedInt(comp)) {
        v.* = float(@as(f64, @floatFromInt(v.data.int)));
    } else {
        v.* = float(@as(f64, @floatFromInt(@as(i64, @bitCast(v.data.int)))));
    }
}

/// Truncates or extends bits based on type.
/// old_ty is only used for size.
pub fn intCast(v: *Value, old_ty: Type, new_ty: Type, comp: *Compilation) void {
    // assert(old_ty.isInt() and new_ty.isInt());
    if (v.tag == .unavailable) return;
    if (new_ty.is(.bool)) return v.toBool();
    if (!old_ty.isUnsignedInt(comp)) {
        const size = new_ty.sizeof(comp).?;
        switch (size) {
            1 => v.* = int(@as(u8, @truncate(@as(u64, @bitCast(v.signExtend(old_ty, comp)))))),
            2 => v.* = int(@as(u16, @truncate(@as(u64, @bitCast(v.signExtend(old_ty, comp)))))),
            4 => v.* = int(@as(u32, @truncate(@as(u64, @bitCast(v.signExtend(old_ty, comp)))))),
            8 => return,
            else => unreachable,
        }
    }
}

/// Converts the stored value from an integer to a float.
/// `.unavailable` value remains unchanged.
pub fn floatCast(v: *Value, old_ty: Type, new_ty: Type, comp: *Compilation) void {
    assert(old_ty.isFloat() and new_ty.isFloat());
    if (v.tag == .unavailable) return;
    const size = new_ty.sizeof(comp).?;
    if (!new_ty.isReal() or size > 8) {
        v.tag = .unavailable;
    } else if (size == 32) {
        v.* = float(@as(f32, @floatCast(v.data.float)));
    }
}

/// Truncates data.int to one bit
pub fn toBool(v: *Value) void {
    if (v.tag == .unavailable) return;
    const res = v.getBool();
    v.* = int(@intFromBool(res));
}

pub fn isZero(v: Value) bool {
    return switch (v.tag) {
        .unavailable => false,
        .nullptr_t => false,
        .int => v.data.int == 0,
        .float => v.data.float == 0,
        .bytes => false,
    };
}

pub fn getBool(v: Value) bool {
    return switch (v.tag) {
        .unavailable => unreachable,
        .nullptr_t => false,
        .int => v.data.int != 0,
        .float => v.data.float != 0,
        .bytes => true,
    };
}

pub fn getInt(v: Value, comptime T: type) T {
    if (T == u64) return v.data.int;
    return if (@typeInfo(T).Int.signedness == .unsigned)
        @truncate(v.data.int)
    else
        @truncate(@as(i64, @bitCast(v.data.int)));
}

pub fn getFloat(v: Value, comptime T: type) T {
    if (T == f64) return v.data.float;
    return @floatCast(v.data.float);
}

const bin_overflow = struct {
    inline fn addInt(comptime T: type, out: *Value, a: Value, b: Value) bool {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        const sum, const overflowed = @addWithOverflow(a_val, b_val);
        out.* = int(sum);
        return overflowed != 0;
    }
    inline fn addFloat(comptime T: type, aa: Value, bb: Value) Value {
        const a_val = aa.getFloat(T);
        const b_val = bb.getFloat(T);
        return float(a_val + b_val);
    }

    inline fn subInt(comptime T: type, out: *Value, a: Value, b: Value) bool {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        const difference, const overflowed = @subWithOverflow(a_val, b_val);
        out.* = int(difference);
        return overflowed != 0;
    }
    inline fn subFloat(comptime T: type, aa: Value, bb: Value) Value {
        const a_val = aa.getFloat(T);
        const b_val = bb.getFloat(T);
        return float(a_val - b_val);
    }

    inline fn mulInt(comptime T: type, out: *Value, a: Value, b: Value) bool {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        const product, const overflowed = @mulWithOverflow(a_val, b_val);
        out.* = int(product);
        return overflowed != 0;
    }
    inline fn mulFloat(comptime T: type, aa: Value, bb: Value) Value {
        const a_val = aa.getFloat(T);
        const b_val = bb.getFloat(T);
        return float(a_val * b_val);
    }

    const FT = fn (*Value, Value, Value, Type, *Compilation) bool;
    fn getOp(comptime intFunc: anytype, comptime floatFunc: anytype) FT {
        return struct {
            fn op(res: *Value, a: Value, b: Value, ty: Type, comp: *Compilation) bool {
                const size = ty.sizeof(comp).?;
                if (@TypeOf(floatFunc) != @TypeOf(null) and ty.isFloat()) {
                    res.* = switch (size) {
                        4 => floatFunc(f32, a, b),
                        8 => floatFunc(f64, a, b),
                        else => unreachable,
                    };
                    return false;
                }

                if (ty.isUnsignedInt(comp)) switch (size) {
                    1 => return intFunc(u8, res, a, b),
                    2 => return intFunc(u16, res, a, b),
                    4 => return intFunc(u32, res, a, b),
                    8 => return intFunc(u64, res, a, b),
                    else => unreachable,
                } else switch (size) {
                    1 => return intFunc(u8, res, a, b),
                    2 => return intFunc(u16, res, a, b),
                    4 => return intFunc(i32, res, a, b),
                    8 => return intFunc(i64, res, a, b),
                    else => unreachable,
                }
            }
        }.op;
    }
};

pub const add = bin_overflow.getOp(bin_overflow.addInt, bin_overflow.addFloat);
pub const sub = bin_overflow.getOp(bin_overflow.subInt, bin_overflow.subFloat);
pub const mul = bin_overflow.getOp(bin_overflow.mulInt, bin_overflow.mulFloat);

const bin_ops = struct {
    inline fn divInt(comptime T: type, aa: Value, bb: Value) Value {
        const a_val = aa.getInt(T);
        const b_val = bb.getInt(T);
        return int(@divTrunc(a_val, b_val));
    }
    inline fn divFloat(comptime T: type, aa: Value, bb: Value) Value {
        const a_val = aa.getFloat(T);
        const b_val = bb.getFloat(T);
        return float(a_val / b_val);
    }

    inline fn remInt(comptime T: type, a: Value, b: Value) Value {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);

        if (@typeInfo(T).Int.signedness == .signed) {
            if (a_val == std.math.minInt(T) and b_val == -1) {
                return Value{ .tag = .unavailable, .data = .{ .none = {} } };
            } else {
                if (b_val > 0) return int(@rem(a_val, b_val));
                return int(a_val - @divTrunc(a_val, b_val) * b_val);
            }
        } else {
            return int(a_val % b_val);
        }
    }

    inline fn orInt(comptime T: type, a: Value, b: Value) Value {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        return int(a_val | b_val);
    }
    inline fn xorInt(comptime T: type, a: Value, b: Value) Value {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        return int(a_val ^ b_val);
    }
    inline fn andInt(comptime T: type, a: Value, b: Value) Value {
        const a_val = a.getInt(T);
        const b_val = b.getInt(T);
        return int(a_val & b_val);
    }

    inline fn shl(comptime T: type, a: Value, b: Value) Value {
        const ShiftT = std.math.Log2Int(T);
        const info = @typeInfo(T).Int;
        const UT = std.meta.Int(.unsigned, info.bits);
        const b_val = b.getInt(T);

        if (b_val > std.math.maxInt(ShiftT)) {
            return if (info.signedness == .unsigned)
                int(@as(UT, std.math.maxInt(UT)))
            else
                int(@as(T, std.math.minInt(T)));
        }
        const amt: ShiftT = @truncate(@as(UT, @bitCast(b_val)));
        const a_val = a.getInt(T);
        return int(a_val << amt);
    }
    inline fn shr(comptime T: type, a: Value, b: Value) Value {
        const ShiftT = std.math.Log2Int(T);
        const UT = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);

        const b_val = b.getInt(T);
        if (b_val > std.math.maxInt(ShiftT)) return Value.int(0);

        const amt: ShiftT = @truncate(@as(UT, @intCast(b_val)));
        const a_val = a.getInt(T);
        return int(a_val >> amt);
    }

    const FT = fn (Value, Value, Type, *Compilation) Value;
    fn getOp(comptime intFunc: anytype, comptime floatFunc: anytype) FT {
        return struct {
            fn op(a: Value, b: Value, ty: Type, comp: *Compilation) Value {
                const size = ty.sizeof(comp).?;
                if (@TypeOf(floatFunc) != @TypeOf(null) and ty.isFloat()) {
                    switch (size) {
                        4 => return floatFunc(f32, a, b),
                        8 => return floatFunc(f64, a, b),
                        else => unreachable,
                    }
                }

                if (ty.isUnsignedInt(comp)) switch (size) {
                    1 => unreachable, // promoted to int
                    2 => unreachable, // promoted to int
                    4 => return intFunc(u32, a, b),
                    8 => return intFunc(u64, a, b),
                    else => unreachable,
                } else switch (size) {
                    1 => unreachable, // promoted to int
                    2 => unreachable, // promoted to int
                    4 => return intFunc(i32, a, b),
                    8 => return intFunc(i64, a, b),
                    else => unreachable,
                }
            }
        }.op;
    }
};

/// caller guarantees rhs != 0
pub const div = bin_ops.getOp(bin_ops.divInt, bin_ops.divFloat);
/// caller guarantees rhs != 0
/// caller guarantees lhs != std.math.minInt(T) OR rhs != -1
pub const rem = bin_ops.getOp(bin_ops.remInt, null);

pub const bitOr = bin_ops.getOp(bin_ops.orInt, null);
pub const bitXor = bin_ops.getOp(bin_ops.xorInt, null);
pub const bitAnd = bin_ops.getOp(bin_ops.andInt, null);

pub const shl = bin_ops.getOp(bin_ops.shl, null);
pub const shr = bin_ops.getOp(bin_ops.shr, null);

pub fn bitNot(v: Value, ty: Type, comp: *Compilation) Value {
    const size = ty.sizeof(comp).?;
    var out: Value = undefined;
    if (ty.isUnsignedInt(comp)) switch (size) {
        1 => unreachable, // promoted to int
        2 => unreachable, // promoted to int
        4 => out = int(~v.getInt(u32)),
        8 => out = int(~v.getInt(u64)),
        else => unreachable,
    } else switch (size) {
        1 => unreachable, // promoted to int
        2 => unreachable, // promoted to int
        4 => out = int(~v.getInt(i32)),
        8 => out = int(~v.getInt(i64)),
        else => unreachable,
    }
    return out;
}

pub fn compare(a: Value, op: std.math.CompareOperator, b: Value, ty: Type, comp: *const Compilation) bool {
    assert(a.tag == b.tag);
    if (a.tag == .nullptr_t) {
        return switch (op) {
            .eq => true,
            .neq => false,
            else => unreachable,
        };
    }
    const S = struct {
        inline fn doICompare(comptime T: type, aa: Value, opp: std.math.CompareOperator, bb: Value) bool {
            const a_val = aa.getInt(T);
            const b_val = bb.getInt(T);
            return std.math.compare(a_val, opp, b_val);
        }
        inline fn doFCompare(comptime T: type, aa: Value, opp: std.math.CompareOperator, bb: Value) bool {
            const a_val = aa.getFloat(T);
            const b_val = bb.getFloat(T);
            return std.math.compare(a_val, opp, b_val);
        }
    };
    const size = ty.sizeof(comp).?;
    switch (a.tag) {
        .unavailable => return true,
        .int => if (ty.isUnsignedInt(comp)) switch (size) {
            1 => return S.doICompare(u8, a, op, b),
            2 => return S.doICompare(u16, a, op, b),
            4 => return S.doICompare(u32, a, op, b),
            8 => return S.doICompare(u64, a, op, b),
            else => unreachable,
        } else switch (size) {
            1 => return S.doICompare(i8, a, op, b),
            2 => return S.doICompare(i16, a, op, b),
            4 => return S.doICompare(i32, a, op, b),
            8 => return S.doICompare(i64, a, op, b),
            else => unreachable,
        },
        .float => switch (size) {
            4 => return S.doFCompare(f32, a, op, b),
            8 => return S.doFCompare(f64, a, op, b),
            else => unreachable,
        },
        else => @panic("TODO"),
    }
    return false;
}

pub fn hash(v: Value) u64 {
    switch (v.tag) {
        .unavailable => unreachable,
        .int => return std.hash.Wyhash.hash(0, std.mem.asBytes(&v.data.int)),
        else => @panic("TODO"),
    }
}

pub fn dump(v: Value, ty: Type, comp: *Compilation, strings: []const u8, w: anytype) !void {
    switch (v.tag) {
        .unavailable => try w.writeAll("unavailable"),
        .int => if (ty.is(.bool) and comp.langopts.standard.atLeast(.c2x)) {
            try w.print("{s}", .{if (v.isZero()) "false" else "true"});
        } else if (ty.isUnsignedInt(comp)) {
            try w.print("{d}", .{v.data.int});
        } else {
            try w.print("{d}", .{v.signExtend(ty, comp)});
        },
        .bytes => try w.print("\"{s}\"", .{v.data.bytes.slice(strings)}),
        // std.fmt does @as instead of @floatCast
        .float => try w.print("{d}", .{@as(f64, @floatCast(v.data.float))}),
        else => try w.print("({s})", .{@tagName(v.tag)}),
    }
}
