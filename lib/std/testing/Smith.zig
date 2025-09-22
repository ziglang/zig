//! Used in conjuncation with `std.testing.fuzz` to generate values

const builtin = @import("builtin");
const std = @import("../std.zig");
const assert = std.debug.assert;
const fuzz_abi = std.Build.abi.fuzz;
const Smith = @This();

/// Null if the fuzzer is being used, in which case this struct will not be mutated.
///
/// Intended to be initialized directly.
in: ?[]const u8,

pub const Weight = fuzz_abi.Weight;

fn intUid(hash: u32) fuzz_abi.Uid {
    @disableInstrumentation();
    return @bitCast(hash << 1);
}

fn bytesUid(hash: u32) fuzz_abi.Uid {
    @disableInstrumentation();
    return @bitCast(hash | 1);
}

fn Backing(T: type) type {
    return std.meta.Int(.unsigned, @bitSizeOf(T));
}

fn toExcessK(T: type, x: T) Backing(T) {
    return @bitCast(x -% std.math.minInt(T));
}

fn fromExcessK(T: type, x: Backing(T)) T {
    return @as(T, @bitCast(x)) +% std.math.minInt(T);
}

fn enumFieldLessThan(_: void, a: std.builtin.Type.EnumField, b: std.builtin.Type.EnumField) bool {
    return a.value < b.value;
}

/// Returns an array of weights containing each possible value of `T`.
//
// `inline` to propogate the `comptime`ness of the result
pub inline fn baselineWeights(T: type) []const Weight {
    return comptime switch (@typeInfo(T)) {
        .bool, .int, .float => i: {
            // Reject types that don't have a fixed bitsize (esp. usize)
            // since they are not gauraunteed to fit in a u64 across targets.
            if (std.mem.indexOfScalar(type, &.{
                isize,      usize,
                c_char,     c_longdouble,
                c_short,    c_ushort,
                c_int,      c_uint,
                c_long,     c_ulong,
                c_longlong, c_ulonglong,
            }, T) != null) {
                @compileError("type does not have a fixed bitsize: " ++ @typeName(T));
            }
            break :i &.{.rangeAtMost(Backing(T), 0, (1 << @bitSizeOf(T)) - 1, 1)};
        },
        .@"struct" => |s| if (s.backing_integer) |B|
            baselineWeights(B)
        else
            @compileError("non-packed structs cannot be weighted"),
        .@"union" => |u| if (u.layout == .@"packed")
            baselineWeights(Backing(T))
        else
            @compileError("non-packed unions cannot be weighted"),
        .@"enum" => |e| if (!e.is_exhaustive)
            baselineWeights(e.tag_type)
        else if (e.fields.len == 0)
            // Cannot be included in below branch due to `log2_int_ceil`
            @compileError("exhaustive zero-field enums cannot be weighted")
        else e: {
            @setEvalBranchQuota(@intCast(4 * e.fields.len *
                std.math.log2_int_ceil(usize, e.fields.len)));

            var sorted_fields = e.fields[0..e.fields.len].*;
            std.mem.sortUnstable(std.builtin.Type.EnumField, &sorted_fields, {}, enumFieldLessThan);

            var weights: []const Weight = &.{};
            var seq_first: u64 = sorted_fields[0].value;
            for (sorted_fields[0 .. sorted_fields.len - 1], sorted_fields[1..]) |prev, field| {
                if (field.value != prev.value + 1) {
                    weights = weights ++ .{Weight.rangeAtMost(u64, seq_first, prev.value, 1)};
                    seq_first = field.value;
                }
            }
            weights = weights ++ .{Weight.rangeAtMost(
                u64,
                seq_first,
                sorted_fields[sorted_fields.len - 1].value,
                1,
            )};

            break :e weights;
        },
        else => @compileError("unexpected type: " ++ @typeName(T)),
    };
}

test baselineWeights {
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(bool, false, true, 1)},
        baselineWeights(bool),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u4, 0, 15, 1)},
        baselineWeights(u4),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u4, 0, 15, 1)},
        baselineWeights(i4),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u16, 0, 0xffff, 1)},
        baselineWeights(f16),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u4, 0, 15, 1)},
        baselineWeights(packed struct(u4) { _: u4 }),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u4, 0, 15, 1)},
        baselineWeights(packed union { _: u4 }),
    );
    try std.testing.expectEqualSlices(
        Weight,
        &.{.rangeAtMost(u4, 0, 15, 1)},
        baselineWeights(enum(u4) { _ }),
    );
    try std.testing.expectEqualSlices(Weight, &.{
        .rangeAtMost(u4, 0, 1, 1),
        .value(u4, 3, 1),
        .value(u4, 5, 1),
        .rangeAtMost(u4, 8, 10, 1),
    }, baselineWeights(enum(u4) {
        a = 1,
        b = 5,
        c = 8,
        d = 3,
        e = 0,
        f = 9,
        g = 10,
    }));
}

fn valueFromInt(T: anytype, int: Backing(T)) T {
    @disableInstrumentation();
    return switch (@typeInfo(T)) {
        .@"enum" => @enumFromInt(int),
        else => @bitCast(int),
    };
}

fn checkWeights(weights: []const Weight, max_incl: u64) void {
    @disableInstrumentation();
    const w0 = weights[0]; // Sum of weights is zero
    assert(w0.weight != 0);
    assert(w0.max <= max_incl);

    var incl_sum: u64 = (w0.max - w0.min) * w0.weight + (w0.weight - 1); // Sum of weights greater than 2^64
    for (weights[1..]) |w| {
        assert(w.weight != 0);
        assert(w.max <= max_incl);
        // This addition will not overflow except with an illegal combination of weights since
        // the exclusive sum must be at least one so a span of all values is impossible.
        incl_sum += (w.max - w.min + 1) * w.weight; // Sum of weights greater than 2^64
    }
}

// `inline` to propogate callee's unique return address
inline fn firstHash() u32 {
    return @truncate(std.hash.int(@returnAddress()));
}

// `noinline` to capture a unique return address
pub noinline fn value(s: *Smith, T: type) T {
    @disableInstrumentation();
    return s.valueWithHash(T, firstHash());
}

// `noinline` to capture a unique return address
pub noinline fn valueWeighted(s: *Smith, T: type, weights: []const Weight) T {
    @disableInstrumentation();
    return s.valueWeightedWithHash(T, weights, firstHash());
}

// `noinline` to capture a unique return address
pub noinline fn valueRangeAtMost(s: *Smith, T: type, at_least: T, at_most: T) T {
    @disableInstrumentation();
    return s.valueRangeAtMostWithHash(T, at_least, at_most, firstHash());
}

// `noinline` to capture a unique return address
pub noinline fn valueRangeLessThan(s: *Smith, T: type, at_least: T, less_than: T) T {
    @disableInstrumentation();
    return s.valueRangeLessThanWithHash(T, at_least, less_than, firstHash());
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
//
// `noinline` to capture a unique return address
pub noinline fn eos(s: *Smith) bool {
    @disableInstrumentation();
    return s.eosWithHash(firstHash());
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
///
/// It is asserted that the weight of `true` is non-zero.
//
// `noinline` to capture a unique return address
pub noinline fn eosWeighted(s: *Smith, weights: []const Weight) bool {
    @disableInstrumentation();
    return s.eosWeightedWithHash(weights, firstHash());
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
///
/// It is asserted that the weight of `true` is non-zero.
//
// `noinline` to capture a unique return address
pub noinline fn eosWeightedSimple(s: *Smith, false_weight: u64, true_weight: u64) bool {
    @disableInstrumentation();
    return s.eosWeightedSimpleWithHash(false_weight, true_weight, firstHash());
}

// `noinline` to capture a unique return address
pub noinline fn bytes(s: *Smith, out: []u8) void {
    @disableInstrumentation();
    return s.bytesWithHash(out, firstHash());
}

// `noinline` to capture a unique return address
pub noinline fn bytesWeighted(s: *Smith, out: []u8, weights: []const Weight) void {
    @disableInstrumentation();
    return s.bytesWeightedWithHash(out, weights, firstHash());
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
// `noinline` to capture a unique return address
pub noinline fn slice(s: *Smith, buf: []u8) u32 {
    @disableInstrumentation();
    return s.sliceWithHash(buf, firstHash());
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
//
// `noinline` to capture a unique return address
pub noinline fn sliceWeightedBytes(s: *Smith, buf: []u8, byte_weights: []const Weight) u32 {
    @disableInstrumentation();
    return s.sliceWeightedBytesWithHash(buf, byte_weights, firstHash());
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
//
// `noinline` to capture a unique return address
pub noinline fn sliceWeighted(
    s: *Smith,
    buf: []u8,
    len_weights: []const Weight,
    byte_weights: []const Weight,
) u32 {
    @disableInstrumentation();
    return s.sliceWeightedWithHash(buf, len_weights, byte_weights, firstHash());
}

fn weightsContain(int: u64, weights: []const Weight) bool {
    @disableInstrumentation();
    var contains: bool = false;
    for (weights) |w| {
        contains |= w.min <= int and int <= w.max;
    }
    return contains;
}

/// Asserts `T` can be a member of a packed type
//
// `inline` to propogate the `comptime`ness of the result
inline fn allBitPatternsValid(T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .void, .bool, .int, .float => true,
        inline .@"struct", .@"union" => |c| c.layout == .@"packed" and for (c.fields) |f| {
            if (!allBitPatternsValid(f.type)) break false;
        } else true,
        .@"enum" => |e| !e.is_exhaustive,
        else => unreachable,
    };
}

test allBitPatternsValid {
    try std.testing.expect(allBitPatternsValid(packed struct {
        a: void,
        b: u8,
        c: f16,
        d: packed union {
            a: u16,
            b: i16,
            c: f16,
        },
        e: enum(u4) { _ },
    }));
    try std.testing.expect(!allBitPatternsValid(packed union {
        a: i4,
        b: enum(u4) { a },
    }));
}

fn UnionTagWithoutUninitializable(T: type) type {
    const u = @typeInfo(T).@"union";
    const Tag = u.tag_type orelse @compileError("union must have tag");
    const e = @typeInfo(Tag).@"enum";
    var fields: [e.fields.len]std.builtin.Type.EnumField = undefined;
    var n_fields = 0;
    for (u.fields) |f| {
        switch (f.type) {
            noreturn => continue,
            else => {},
        }
        fields[n_fields] = .{ .name = f.name, .value = @intFromEnum(@field(Tag, f.name)) };
        n_fields += 1;
    }
    return @Type(.{ .@"enum" = .{
        .tag_type = e.tag_type,
        .is_exhaustive = e.is_exhaustive,
        .fields = fields[0..n_fields],
        .decls = &.{},
    } });
}

pub fn valueWithHash(s: *Smith, T: type, hash: u32) T {
    @disableInstrumentation();
    return switch (@typeInfo(T)) {
        .void => {},
        .bool, .int, .float => full: {
            var int: Backing(T) = 0;
            comptime var biti = 0;
            var rhash = hash; // 'running' hash
            inline while (biti < @bitSizeOf(T)) {
                const n = @min(@bitSizeOf(T) - biti, 64);
                const P = std.meta.Int(.unsigned, n);
                int |= @as(
                    @TypeOf(int),
                    s.valueWeightedWithHash(P, baselineWeights(P), rhash),
                ) << biti;
                biti += n;
                rhash = std.hash.int(rhash);
            }
            break :full @bitCast(int);
        },
        .@"enum" => |e| if (e.is_exhaustive) v: {
            if (@bitSizeOf(e.tag_type) <= 64) {
                break :v s.valueWeightedWithHash(T, baselineWeights(T), hash);
            }
            break :v std.enums.fromInt(T, s.valueWithHash(e.tag_type, hash)) orelse
                @enumFromInt(e.fields[0].value);
        } else @enumFromInt(s.valueWithHash(e.tag_type, hash)),
        .optional => |o| if (s.valueWithHash(bool, hash))
            null
        else
            s.valueWithHash(o.child, std.hash.int(hash)),
        inline .array, .vector => |a| arr: {
            var arr: [a.len]a.child = undefined; // `T` cannot be used due to the vector case
            if (a.child != u8) {
                for (&arr) |*v| {
                    v.* = s.valueWithHash(a.child, hash);
                }
            } else {
                s.bytesWithHash(&arr, hash);
            }
            break :arr arr;
        },
        .@"struct" => |st| if (!allBitPatternsValid(T)) v: {
            var v: T = undefined;
            var rhash = hash;
            inline for (st.fields) |f| {
                // rhash is incremented in the call so our rhash state is not reused (e.g. with
                // two nested structs. note that xor cannot work for this case as the bit would
                // be flipped back here)
                @field(v, f.name) = s.valueWithHash(f.type, rhash +% 1);
                rhash = std.hash.int(rhash);
            }
            break :v v;
        } else @bitCast(s.valueWithHash(st.backing_integer.?, hash)),
        .@"union" => if (!allBitPatternsValid(T))
            switch (s.valueWithHash(
                UnionTagWithoutUninitializable(T),
                // hash is incremented in the call so our hash state is not reused for below
                std.hash.int(hash +% 1),
            )) {
                inline else => |t| @unionInit(
                    T,
                    @tagName(t),
                    s.valueWithHash(@FieldType(T, @tagName(t)), hash),
                ),
            }
        else
            @bitCast(s.valueWithHash(Backing(T), hash)),
        else => @compileError("unexpected type '" ++ @typeName(T) ++ "'"),
    };
}

pub fn valueWeightedWithHash(s: *Smith, T: type, weights: []const Weight, hash: u32) T {
    @disableInstrumentation();
    checkWeights(weights, (1 << @bitSizeOf(T)) - 1);
    return valueFromInt(T, @intCast(s.valueWeightedWithHashInner(weights, hash)));
}

fn valueWeightedWithHashInner(s: *Smith, weights: []const Weight, hash: u32) u64 {
    @disableInstrumentation();
    return if (s.in) |*in| int: {
        if (in.len < 8) {
            @branchHint(.unlikely);
            in.* = &.{};
            break :int weights[0].min;
        }
        const int = std.mem.readInt(u64, in.*[0..8], .little);
        in.* = in.*[8..];
        break :int if (weightsContain(int, weights)) int else weights[0].min;
    } else if (builtin.fuzz) int: {
        @branchHint(.likely);
        break :int fuzz_abi.fuzzer_int(intUid(hash), .fromSlice(weights));
    } else unreachable;
}

pub fn valueRangeAtMostWithHash(s: *Smith, T: type, at_least: T, at_most: T, hash: u32) T {
    @disableInstrumentation();
    if (@typeInfo(T) == .int and @typeInfo(T).int.signedness == .signed) {
        return fromExcessK(T, s.valueRangeAtMostWithHash(
            Backing(T),
            toExcessK(T, at_least),
            toExcessK(T, at_most),
            hash,
        ));
    }
    return s.valueWeightedWithHash(T, &.{.rangeAtMost(T, at_least, at_most, 1)}, hash);
}

pub fn valueRangeLessThanWithHash(s: *Smith, T: type, at_least: T, less_than: T, hash: u32) T {
    @disableInstrumentation();
    if (@typeInfo(T) == .int and @typeInfo(T).int.signedness == .signed) {
        return fromExcessK(T, s.valueRangeLessThanWithHash(
            Backing(T),
            toExcessK(T, at_least),
            toExcessK(T, less_than),
            hash,
        ));
    }
    return s.valueWeightedWithHash(T, &.{.rangeLessThan(T, at_least, less_than, 1)}, hash);
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
pub fn eosWithHash(s: *Smith, hash: u32) bool {
    @disableInstrumentation();
    return s.eosWeightedWithHash(baselineWeights(bool), hash);
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
///
/// It is asserted that the weight of `true` is non-zero.
pub fn eosWeightedWithHash(s: *Smith, weights: []const Weight, hash: u32) bool {
    @disableInstrumentation();
    checkWeights(weights, 1);
    for (weights) |w| (if (w.max == 1) break) else unreachable; // `true` must have non-zero weight

    if (s.in) |*in| {
        if (in.len == 0) {
            @branchHint(.unlikely);
            return true;
        }
        const eos_val = in.*[0] != 0;
        in.* = in.*[1..];
        return eos_val or b: {
            var only_true: bool = true;
            for (weights) |w| {
                only_true &= @as(u1, @intCast(w.min)) == 1;
            }
            break :b only_true;
        };
    } else if (builtin.fuzz) {
        @branchHint(.likely);
        return fuzz_abi.fuzzer_eos(intUid(hash), .fromSlice(weights));
    } else unreachable;
}

/// This is similar to `value(bool)` however it is gauraunteed to eventually
/// return `true` and provides the fuzzer with an extra hint about the data.
///
/// It is asserted that the weight of `false` is non-zero.
/// It is asserted that the weight of `true` is non-zero.
//
// `noinline` to capture a unique return address
pub fn eosWeightedSimpleWithHash(s: *Smith, false_weight: u64, true_weight: u64, hash: u32) bool {
    @disableInstrumentation();
    return s.eosWeightedWithHash(&.{
        .value(bool, false, false_weight),
        .value(bool, true, true_weight),
    }, hash);
}

pub fn bytesWithHash(s: *Smith, out: []u8, hash: u32) void {
    @disableInstrumentation();
    return s.bytesWeightedWithHash(out, baselineWeights(u8), hash);
}

pub fn bytesWeightedWithHash(s: *Smith, out: []u8, weights: []const Weight, hash: u32) void {
    @disableInstrumentation();
    checkWeights(weights, 255);

    if (s.in) |*in| {
        var present_weights: [256]bool = @splat(false);
        for (weights) |w| {
            @memset(present_weights[@intCast(w.min)..@intCast(w.max + 1)], true);
        }
        const default: u8 = @intCast(weights[0].min);

        const copy_len = @min(out.len, in.len);
        for (in.*[0..copy_len], out[0..copy_len]) |i, *o| {
            o.* = if (present_weights[i]) i else default;
        }
        in.* = in.*[copy_len..];
        @memset(out[copy_len..], default);
    } else if (builtin.fuzz) {
        @branchHint(.likely);
        fuzz_abi.fuzzer_bytes(bytesUid(hash), .fromSlice(out), .fromSlice(weights));
    } else unreachable;
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
pub fn sliceWithHash(s: *Smith, buf: []u8, hash: u32) u32 {
    @disableInstrumentation();
    return s.sliceWeightedBytesWithHash(buf, baselineWeights(u8), hash);
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
pub fn sliceWeightedBytesWithHash(
    s: *Smith,
    buf: []u8,
    byte_weights: []const Weight,
    hash: u32,
) u32 {
    @disableInstrumentation();
    return s.sliceWeightedWithHash(
        buf,
        &.{.rangeAtMost(u32, 0, @intCast(buf.len), 1)},
        byte_weights,
        hash,
    );
}

/// Returns the length of the filled slice
///
/// It is asserted that `buf.len` fits within a u32
pub fn sliceWeightedWithHash(
    s: *Smith,
    buf: []u8,
    len_weights: []const Weight,
    byte_weights: []const Weight,
    hash: u32,
) u32 {
    @disableInstrumentation();
    checkWeights(byte_weights, 255);
    checkWeights(len_weights, @as(u32, @intCast(buf.len)));

    if (s.in) |*in| {
        const in_len = len: {
            if (in.len < 4) {
                @branchHint(.unlikely);
                in.* = &.{};
                break :len 0;
            }
            const len = std.mem.readInt(u32, in.*[0..4], .little);
            in.* = in.*[4..];
            break :len @min(len, in.len);
        };
        const out_len: u32 = if (weightsContain(in_len, len_weights))
            in_len
        else
            @intCast(len_weights[0].min);

        var present_weights: [256]bool = @splat(false);
        for (byte_weights) |w| {
            @memset(present_weights[@intCast(w.min)..@intCast(w.max + 1)], true);
        }
        const default: u8 = @intCast(byte_weights[0].min);

        const copy_len = @min(out_len, in_len);
        for (in.*[0..copy_len], buf[0..copy_len]) |i, *o| {
            o.* = if (present_weights[i]) i else default;
        }
        in.* = in.*[in_len..];
        @memset(buf[copy_len..], default);
        return out_len;
    } else if (builtin.fuzz) {
        @branchHint(.likely);
        return fuzz_abi.fuzzer_slice(
            bytesUid(hash),
            .fromSlice(buf),
            .fromSlice(len_weights),
            .fromSlice(byte_weights),
        );
    } else unreachable;
}

fn constructInput(comptime values: []const union(enum) {
    eos: bool,
    int: u64,
    bytes: []const u8,
    slice: []const u8,
}) []const u8 {
    const result = comptime result: {
        var result: [
            len: {
                var len = 0;
                for (values) |v| len += switch (v) {
                    .eos => 1,
                    .int => 8,
                    .bytes => |b| b.len,
                    .slice => |s| 4 + s.len,
                };
                break :len len;
            }
        ]u8 = undefined;
        var w: std.Io.Writer = .fixed(&result);

        for (values) |v| switch (v) {
            .eos => |e| w.writeByte(@intFromBool(e)) catch unreachable,
            .int => |i| w.writeInt(u64, i, .little) catch unreachable,
            .bytes => |b| w.writeAll(b) catch unreachable,
            .slice => |s| {
                w.writeInt(u32, @intCast(s.len), .little) catch unreachable;
                w.writeAll(s) catch unreachable;
            },
        };

        break :result result;
    };
    return &result;
}

test value {
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    const S = struct {
        v: void = {},
        b: bool = true,
        ih: u16 = 123,
        iq: u64 = 55555,
        io: u128 = (1 << 80) | (1 << 23),
        fd: f64 = std.math.pi,
        ft: f80 = std.math.e,
        eh: enum(u16) { a, _ } = @enumFromInt(999),
        eo: enum(u128) { a, b, _ } = .b,
        aw: [3]u32 = .{ 1 << 30, 1 << 20, 1 << 10 },
        vw: @Vector(3, u32) = .{ 1 << 10, 1 << 20, 1 << 30 },
        ab: [3]u8 = .{ 55, 33, 88 },
        vb: @Vector(3, u8) = .{ 22, 44, 99 },
        s: struct { q: u64 } = .{ .q = 1 },
        sz: struct {} = .{},
        sp: packed struct(u8) { a: u5, b: u3 } = .{ .a = 31, .b = 3 },
        si: packed struct(u8) { a: u5, b: enum(u3) { a, b } } = .{ .a = 15, .b = .b },
        u: union(enum(u2)) {
            a: u64,
            b: u64,
            c: noreturn,
        } = .{ .b = 777777 },
        up: packed union {
            a: u16,
            b: f16,
        } = .{ .b = std.math.phi },

        invalid: struct {
            ib: u8 = 0,
            eb: enum(u8) { a, b } = .a,
            eo: enum(u128) { a, b } = .a,
            u: union(enum(u1)) { a: noreturn, b: void } = .{ .b = {} },
        } = .{},
    };
    const s: S = .{};
    const ft_bits: u80 = @bitCast(s.ft);
    const eo_bits = @intFromEnum(s.eo);

    var smith: Smith = .{
        .in = constructInput(&.{
            // v
            .{ .int = @intFromBool(s.b) }, // b
            .{ .int = s.ih }, // ih
            .{ .int = s.iq }, // iq
            .{ .int = @truncate(s.io) }, .{ .int = @intCast(s.io >> 64) }, // io
            .{ .int = @bitCast(s.fd) }, // fd
            .{ .int = @truncate(ft_bits) }, .{ .int = @intCast(ft_bits >> 64) }, // ft
            .{ .int = @intFromEnum(s.eh) }, // eh
            .{ .int = @truncate(eo_bits) }, .{ .int = @intCast(eo_bits >> 64) }, // eo
            .{ .int = s.aw[0] }, .{ .int = s.aw[1] }, .{ .int = s.aw[2] }, // aw
            .{ .int = s.vw[0] }, .{ .int = s.vw[1] }, .{ .int = s.vw[2] }, // vw
            .{ .bytes = &s.ab }, // ab
            .{ .bytes = &@as([3]u8, s.vb) }, // vb
            .{ .int = s.s.q }, // s.q
            //sz
            .{ .int = @as(u8, @bitCast(s.sp)) }, // sp
            .{ .int = s.si.a }, .{ .int = @intFromEnum(s.si.b) }, // si
            .{ .int = @intFromEnum(s.u) }, .{ .int = s.u.b }, // u
            .{ .int = @as(u16, @bitCast(s.up)) }, // up
            // invalid values
            .{ .int = 555 }, // invalid.ib
            .{ .int = 123 }, // invalid.eb
            .{ .int = 0 }, .{ .int = 1 }, // invalid.eo
            .{ .int = 0 }, // invalid.u
        }),
    };

    try std.testing.expectEqual(s, smith.value(S));
}

test valueWeighted {
    var smith: Smith = .{
        .in = constructInput(&.{
            .{ .int = 200 },
            .{ .int = 200 },
            .{ .int = 300 },
            .{ .int = 400 },
        }),
    };

    try std.testing.expectEqual(200, smith.valueWeighted(u8, &.{.rangeAtMost(u8, 50, 200, 1)}));
    try std.testing.expectEqual(50, smith.valueWeighted(u8, &.{.rangeLessThan(u8, 50, 200, 1)}));
    const E = enum(u64) { a = 100, b = 200, c = 300 };
    try std.testing.expectEqual(E.c, smith.valueWeighted(E, baselineWeights(E)));
    try std.testing.expectEqual(E.a, smith.valueWeighted(E, baselineWeights(E)));
    try std.testing.expectEqual(12345, smith.valueWeighted(u64, &.{.value(u64, 12345, 1)}));
}

test valueRangeAtMost {
    var smith: Smith = .{
        .in = constructInput(&.{
            .{ .int = 100 },
            .{ .int = 100 },
            .{ .int = 200 },
            .{ .int = 100 },
            .{ .int = 200 },
            .{ .int = 0 },
        }),
    };
    try std.testing.expectEqual(100, smith.valueRangeAtMost(u8, 0, 250));
    try std.testing.expectEqual(100, smith.valueRangeAtMost(u8, 100, 100));
    try std.testing.expectEqual(0, smith.valueRangeAtMost(u8, 0, 100));
    try std.testing.expectEqual(100 - 128, smith.valueRangeAtMost(i8, -100, 100));
    try std.testing.expectEqual(200 - 128, smith.valueRangeAtMost(i8, -100, 100));
    try std.testing.expectEqual(-100, smith.valueRangeAtMost(i8, -100, 100));
}

test valueRangeLessThan {
    var smith: Smith = .{
        .in = constructInput(&.{
            .{ .int = 100 },
            .{ .int = 100 },
            .{ .int = 100 },
            .{ .int = 100 + 128 },
        }),
    };
    try std.testing.expectEqual(100, smith.valueRangeLessThan(u8, 0, 250));
    try std.testing.expectEqual(0, smith.valueRangeLessThan(u8, 0, 100));
    try std.testing.expectEqual(100 - 128, smith.valueRangeLessThan(i8, -100, 100));
    try std.testing.expectEqual(-100, smith.valueRangeLessThan(i8, -100, 100));
}

test eos {
    var smith: Smith = .{
        .in = constructInput(&.{
            .{ .eos = false },
            .{ .eos = true },
        }),
    };
    try std.testing.expect(!smith.eos());
    try std.testing.expect(smith.eos());
    try std.testing.expect(smith.eos());
}

test eosWeighted {
    var smith: Smith = .{ .in = constructInput(&.{.{ .eos = false }}) };
    try std.testing.expect(smith.eosWeighted(&.{.value(bool, true, std.math.maxInt(u64))}));
}

test bytes {
    var smith: Smith = .{ .in = constructInput(&.{
        .{ .bytes = "testing!" },
        .{ .bytes = "ab" },
    }) };
    var buf: [8]u8 = undefined;

    smith.bytes(&buf);
    try std.testing.expectEqualSlices(u8, "testing!", &buf);
    smith.bytes(buf[0..0]);
    smith.bytes(buf[0..3]);
    try std.testing.expectEqualSlices(u8, "ab\x00", buf[0..3]);
}

test bytesWeighted {
    var smith: Smith = .{ .in = constructInput(&.{
        .{ .bytes = "testing!" },
        .{ .bytes = "ab" },
    }) };
    const weights: []const Weight = &.{.rangeAtMost(u8, 'a', 'z', 1)};
    var buf: [8]u8 = undefined;

    smith.bytesWeighted(&buf, weights);
    try std.testing.expectEqualSlices(u8, "testinga", &buf);
    smith.bytesWeighted(buf[0..0], weights);
    smith.bytesWeighted(buf[0..3], weights);
    try std.testing.expectEqualSlices(u8, "aba", buf[0..3]);
}

test slice {
    var smith: Smith = .{
        .in = constructInput(&.{
            .{ .slice = "testing!" },
            .{ .slice = "" },
            .{ .slice = "ab" },
            .{ .bytes = std.mem.asBytes(&std.mem.nativeToLittle(u32, 4)) }, // length past end
        }),
    };
    var buf: [8]u8 = undefined;

    try std.testing.expectEqualSlices(u8, "testing!", buf[0..smith.slice(&buf)]);
    try std.testing.expectEqualSlices(u8, "", buf[0..smith.slice(&buf)]);
    try std.testing.expectEqualSlices(u8, "ab", buf[0..smith.slice(&buf)]);
    try std.testing.expectEqualSlices(u8, "", buf[0..smith.slice(&buf)]);
}

test sliceWeightedBytes {
    const weights: []const Weight = &.{.rangeAtMost(u8, 'a', 'z', 1)};
    var smith: Smith = .{ .in = constructInput(&.{
        .{ .slice = "testing!" },
    }) };
    var buf: [8]u8 = undefined;

    try std.testing.expectEqualSlices(
        u8,
        "testinga",
        buf[0..smith.sliceWeightedBytes(&buf, weights)],
    );
    try std.testing.expectEqualSlices(u8, "", buf[0..smith.sliceWeightedBytes(&buf, weights)]);
}

test sliceWeighted {
    const len_weights: []const Weight = &.{.rangeAtMost(u8, 3, 6, 1)};
    const weights: []const Weight = &.{.rangeAtMost(u8, 'a', 'z', 1)};
    var smith: Smith = .{ .in = constructInput(&.{
        .{ .slice = "testing!" },
        .{ .slice = "ing!" },
        .{ .slice = "ab" },
    }) };
    var buf: [8]u8 = undefined;

    try std.testing.expectEqualSlices(
        u8,
        "tes",
        buf[0..smith.sliceWeighted(&buf, len_weights, weights)],
    );
    try std.testing.expectEqualSlices(
        u8,
        "inga",
        buf[0..smith.sliceWeighted(&buf, len_weights, weights)],
    );
    try std.testing.expectEqualSlices(
        u8,
        "aba",
        buf[0..smith.sliceWeighted(&buf, len_weights, weights)],
    );
    try std.testing.expectEqualSlices(
        u8,
        "aaa",
        buf[0..smith.sliceWeighted(&buf, len_weights, weights)],
    );
}
