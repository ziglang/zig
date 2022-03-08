// Note: Some functions here are known to malfunction on MIPS.
// Functions whose tests fail on MIPS will trigger compile errors when compiled for that platform.

const std = @import("std");
const builtin = @import("builtin");

pub const Vector = std.meta.Vector;

/// Suggests a vector size for a given type and CPU, or null if it doesn't support SIMD natively.
/// Not yet implemented for every CPU architecture.
pub fn suggestVectorSizeForCpu(comptime T: type, cpu: std.Target.Cpu) ?usize {
    switch (cpu.arch) {
        .x86_64 => {
            if (T == bool and std.Target.x86.featureSetHas(.prefer_mask_registers)) return 64;

            const vector_bit_size = if (std.Target.x86.featureSetHas(.avx512f)) 512 else if (std.Target.x86.featureSetHas(.prefer_256_bit)) 256 else if (std.Target.x86.featureSetHas(.prefer_128_bit)) 128 else return null;
            const element_bit_size = std.math.max(8, std.math.ceilPowerOfTwo(T, @bitSizeOf(T)));
            return vector_bit_size / element_bit_size;
        },
        else => @compileError("No vector sizes for this CPU architecture have yet been recommended"),
    }
}

/// Suggests a vector size for a given type, or null if the target CPU doesn't support SIMD natively.
/// Not yet implemented for every CPU architecture.
pub fn suggestVectorSize(comptime T: type) ?usize {
    return suggestVectorSizeForCpu(T, builtin.cpu);
}

pub fn vectorLength(comptime VectorType: type) comptime_int {
    return switch (@typeInfo(VectorType)) {
        .Vector => |info| info.len,
        .Array => |info| info.len,
        else => @compileError("Invalid type " ++ @typeName(VectorType)),
    };
}

/// Returns the smallest type of an unsigned int capable of indexing any element within the given vector type.
pub fn VectorIndex(comptime VectorType: type) type {
    return std.math.IntFittingRange(0, vectorLength(VectorType) - 1);
}

/// Returns the smallest type of an unsigned int capable of holding the length of the given vector type.
pub fn VectorCount(comptime VectorType: type) type {
    return std.math.IntFittingRange(0, vectorLength(VectorType));
}

/// Returns a vector containing the integer sequence starting at 0.
/// For example, countUp(i32, 8) will return a vector containing {0, 1, 2, 3, 4, 5, 6, 7}.
pub fn countUp(comptime T: type, comptime len: usize) Vector(len, T) {
    var out: [len]T = undefined;
    for (out) |*element, i| {
        element.* = switch (@typeInfo(T)) {
            .Int => @intCast(T, i),
            .Float => @intToFloat(T, i),
            else => @compileError("Can't use type " ++ @typeName(T) ++ " in countUp."),
        };
    }
    return @as(Vector(len, T), out);
}

/// Returns a vector containing the same elements as the input, but repeated until the desired length is reached.
/// For example, repeat(8, [_]u32{1, 2, 3}) will return a vector containing {1, 2, 3, 1, 2, 3, 1, 2}.
pub fn repeat(comptime len: usize, vec: anytype) Vector(len, std.meta.Child(@TypeOf(vec))) {
    const Child = std.meta.Child(@TypeOf(vec));

    return @shuffle(Child, vec, undefined, countUp(i32, len) % @splat(len, @intCast(i32, vectorLength(@TypeOf(vec)))));
}

/// Returns a vector containing all elements of the first vector followed by all elements of the second vector.
pub fn join(a: anytype, b: anytype) Vector(vectorLength(@TypeOf(a)) + vectorLength(@TypeOf(b)), std.meta.Child(@TypeOf(a))) {
    const Child = std.meta.Child(@TypeOf(a));
    const a_len = vectorLength(@TypeOf(a));
    const b_len = vectorLength(@TypeOf(b));

    return @shuffle(Child, a, b, @as([a_len]i32, countUp(i32, a_len)) ++ @as([b_len]i32, ~countUp(i32, b_len)));
}

/// Returns a vector whose elements alternates between those of each input vector.
/// For example, braid(.{[4]u32{11, 12, 13, 14}, [4]u32{21, 22, 23, 24}}) returns a vector containing {11, 21, 12, 22, 13, 23, 14, 24}.
pub fn braid(vecs: anytype) Vector(vectorLength(@TypeOf(vecs[0])) * vecs.len, std.meta.Child(@TypeOf(vecs[0]))) {
    // braid doesn't work on MIPS, for some reason.
    // Notes from earlier debug attempt:
    //  The indices are correct. The problem seems to be with the @shuffle builtin.
    //  On MIPS, the test that braids small_base gives { 0, 2, 0, 0, 64, 255, 248, 200, 0, 0 }.
    //  Calling this with two inputs seems to work fine, but I'll let the compile error trigger for all inputs, just to be safe.
    comptime if (builtin.cpu.arch.isMIPS() and !builtin.is_test) @compileError("TODO: Find out why braid() doesn't work on MIPS");

    const VecType = @TypeOf(vecs[0]);
    const vecs_arr = @as([vecs.len]VecType, vecs);
    const Child = std.meta.Child(@TypeOf(vecs_arr[0]));

    if (vecs_arr.len == 1) return vecs_arr[0];

    const a_vec_count = (1 + vecs_arr.len) >> 1;
    const b_vec_count = vecs_arr.len >> 1;

    const a = braid(@ptrCast(*const [a_vec_count]VecType, vecs_arr[0..a_vec_count]).*);
    const b = braid(@ptrCast(*const [b_vec_count]VecType, vecs_arr[a_vec_count..]).*);

    const a_len = vectorLength(@TypeOf(a));
    const b_len = vectorLength(@TypeOf(b));
    const len = a_len + b_len;

    const indices = comptime blk: {
        const count_up = countUp(i32, len);
        const cycle = @divFloor(count_up, @splat(len, @intCast(i32, vecs_arr.len)));
        const select_mask = repeat(len, join(@splat(a_vec_count, true), @splat(b_vec_count, false)));
        const a_indices = count_up - cycle * @splat(len, @intCast(i32, b_vec_count));
        const b_indices = shiftElementsUp(count_up - cycle * @splat(len, @intCast(i32, a_vec_count)), a_vec_count, 0);
        break :blk @select(i32, select_mask, a_indices, ~b_indices);
    };

    return @shuffle(Child, a, b, indices);
}

/// The contents of braided is evenly split between vec_count vectors that are returned as an array. They "take turns",
/// recieving one element from braided at a time.
pub fn unbraid(comptime vec_count: usize, braided: anytype) [vec_count]Vector(vectorLength(@TypeOf(braided)) / vec_count, std.meta.Child(@TypeOf(braided))) {
    const vec_len = vectorLength(@TypeOf(braided)) / vec_count;
    const Child = std.meta.Child(@TypeOf(braided));

    var out: [vec_count]Vector(vec_len, Child) = undefined;

    comptime var i: usize = 0; // for doesn't work, apparently.
    inline while (i < out.len) : (i += 1) {
        const indices = comptime countUp(i32, vec_len) * @splat(vec_len, @intCast(i32, vec_count)) + @splat(vec_len, @intCast(i32, i));
        out[i] = @shuffle(Child, braided, undefined, indices);
    }

    return out;
}

pub fn extract(vec: anytype, comptime first: VectorIndex(@TypeOf(vec)), comptime count: VectorCount(@TypeOf(vec))) Vector(count, std.meta.Child(@TypeOf(vec))) {
    const Child = std.meta.Child(@TypeOf(vec));
    const len = vectorLength(@TypeOf(vec));

    std.debug.assert(@intCast(comptime_int, first) + @intCast(comptime_int, count) <= len);

    return @shuffle(Child, vec, undefined, countUp(i32, count) + @splat(count, @intCast(i32, first)));
}

test "vector patterns" {
    const base = Vector(4, u32){ 10, 20, 30, 40 };
    const other_base = Vector(4, u32){ 55, 66, 77, 88 };

    const small_bases = [5]Vector(2, u8){
        Vector(2, u8){ 0, 1 },
        Vector(2, u8){ 2, 3 },
        Vector(2, u8){ 4, 5 },
        Vector(2, u8){ 6, 7 },
        Vector(2, u8){ 8, 9 },
    };

    try std.testing.expectEqual([6]u32{ 10, 20, 30, 40, 10, 20 }, repeat(6, base));
    try std.testing.expectEqual([8]u32{ 10, 20, 30, 40, 55, 66, 77, 88 }, join(base, other_base));
    try std.testing.expectEqual([2]u32{ 20, 30 }, extract(base, 1, 2));

    if (!builtin.cpu.arch.isMIPS()) {
        try std.testing.expectEqual([8]u32{ 10, 55, 20, 66, 30, 77, 40, 88 }, braid(.{ base, other_base }));

        const small_braid = braid(small_bases);
        try std.testing.expectEqual([10]u8{ 0, 2, 4, 6, 8, 1, 3, 5, 7, 9 }, small_braid);
        try std.testing.expectEqual(small_bases, unbraid(small_bases.len, small_braid));
    }
}

pub fn shiftElementsUp(vec: anytype, comptime amount: VectorCount(@TypeOf(vec)), shift_in: std.meta.Child(@TypeOf(vec))) @TypeOf(vec) {
    return join(@splat(amount, shift_in), extract(vec, 0, vectorLength(@TypeOf(vec)) - amount));
}

pub fn shiftElementsDown(vec: anytype, comptime amount: VectorCount(@TypeOf(vec)), shift_in: std.meta.Child(@TypeOf(vec))) @TypeOf(vec) {
    const len = vectorLength(@TypeOf(vec));

    return join(extract(vec, amount, len - amount), @splat(amount, shift_in));
}

pub fn rotateElementsDown(vec: anytype, comptime amount: VectorCount(@TypeOf(vec))) @TypeOf(vec) {
    const Child = std.meta.Child(@TypeOf(vec));
    const len = vectorLength(@TypeOf(vec));

    std.debug.assert(amount <= len);

    const indices = comptime @mod(countUp(i32, len) + @splat(len, @as(i32, amount)), @splat(len, @intCast(i32, len)));

    return @shuffle(Child, vec, undefined, indices);
}

pub fn rotateElementsUp(vec: anytype, comptime amount: VectorCount(@TypeOf(vec))) @TypeOf(vec) {
    return rotateElementsDown(vec, vectorLength(@TypeOf(vec)) - amount);
}

pub fn reverse(vec: anytype) @TypeOf(vec) {
    const Child = std.meta.Child(@TypeOf(vec));
    const len = vectorLength(@TypeOf(vec));

    return @shuffle(Child, vec, undefined, @splat(len, @intCast(i32, len) - 1) - countUp(i32, len));
}

test "vector shifting" {
    const base = Vector(4, u32){ 10, 20, 30, 40 };

    try std.testing.expectEqual([4]u32{ 30, 40, 999, 999 }, shiftElementsDown(base, 2, 999));
    try std.testing.expectEqual([4]u32{ 999, 999, 10, 20 }, shiftElementsUp(base, 2, 999));
    try std.testing.expectEqual([4]u32{ 20, 30, 40, 10 }, rotateElementsDown(base, 1));
    try std.testing.expectEqual([4]u32{ 40, 10, 20, 30 }, rotateElementsUp(base, 1));
    try std.testing.expectEqual([4]u32{ 40, 30, 20, 10 }, reverse(base));
}

pub fn firstTrue(vec: anytype) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const IndexInt = VectorIndex(@TypeOf(vec));

    if (!@reduce(.Or, vec)) {
        return null;
    }
    const indexes = @select(IndexInt, vec, countUp(IndexInt, len), @splat(len, ~@as(IndexInt, 0)));
    return @reduce(.Min, indexes);
}

pub fn lastTrue(vec: anytype) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const IndexInt = VectorIndex(@TypeOf(vec));

    if (!@reduce(.Or, vec)) {
        return null;
    }
    const indexes = @select(IndexInt, vec, countUp(IndexInt, len), @splat(len, @as(IndexInt, 0)));
    return @reduce(.Max, indexes);
}

pub fn countTrues(vec: anytype) VectorCount(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const CountIntType = VectorCount(@TypeOf(vec));

    const one_if_true = @select(CountIntType, vec, @splat(len, @as(CountIntType, 1)), @splat(len, @as(CountIntType, 0)));
    return @reduce(.Add, one_if_true);
}

pub fn firstIndexOfValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));

    return firstTrue(vec == @splat(len, value));
}

pub fn lastIndexOfValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));

    return lastTrue(vec == @splat(len, value));
}

pub fn countElementsWithValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) VectorCount(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));

    return countTrues(vec == @splat(len, value));
}

test "vector searching" {
    const base = Vector(8, u32){ 6, 4, 7, 4, 4, 2, 3, 7 };

    try std.testing.expectEqual(@as(?u3, 1), firstIndexOfValue(base, 4));
    try std.testing.expectEqual(@as(?u3, 4), lastIndexOfValue(base, 4));
    try std.testing.expectEqual(@as(?u3, null), lastIndexOfValue(base, 99));
    try std.testing.expectEqual(@as(u4, 3), countElementsWithValue(base, 4));
}

/// Same as accum, but with a user-provided function that mathematically must be associative.
/// The function must also do nothing when called with identity as either argument.
pub fn accumWithFunc(comptime hop: isize, vec: anytype, comptime func: fn (@TypeOf(vec), @TypeOf(vec)) @TypeOf(vec), comptime identity: std.meta.Child(@TypeOf(vec))) @TypeOf(vec) {
    // I haven't debugged this, but it might be a cousin of sorts to what's going on with braid.
    comptime if (builtin.cpu.arch.isMIPS() and !builtin.is_test) @compileError("TODO: Find out why accum doesn't work on MIPS");

    const len = vectorLength(@TypeOf(vec));

    if (hop == 0) @compileError("hop can not be 0; you'd be going nowhere forever!");
    const abs_hop = if (hop < 0) -hop else hop;

    var acc = vec;
    comptime var i = 0;
    inline while ((abs_hop << i) < len) : (i += 1) {
        const shifted = if (hop < 0) shiftElementsDown(acc, abs_hop << i, identity) else shiftElementsUp(acc, abs_hop << i, identity);

        acc = func(acc, shifted);
    }
    return acc;
}

/// Returns a vector whose elements are the result of performing the specified operation on the corresponding
/// element of the input vector and every hop'th element that came before it (or after, if hop is negative).
/// Supports the same operations as the @reduce() builtin. Takes O(logN) to compute.
pub fn accum(comptime op: std.builtin.ReduceOp, comptime hop: isize, vec: anytype) @TypeOf(vec) {
    const VecType = @TypeOf(vec);
    const Child = std.meta.Child(VecType);
    const len = vectorLength(VecType);

    const identity = comptime switch (@typeInfo(Child)) {
        .Bool => switch (op) {
            .Or, .Xor => false,
            .And => true,
            else => @compileError("Invalid accum operation " ++ @tagName(op) ++ " for vector of booleans."),
        },
        .Int => switch (op) {
            .Max => std.math.minInt(Child),
            .Add, .Or, .Xor => 0,
            .Mul => 1,
            .And, .Min => std.math.maxInt(Child),
        },
        .Float => switch (op) {
            .Max => -std.math.inf(Child),
            .Add => 0,
            .Mul => 1,
            .Min => std.math.inf(Child),
            else => @compileError("Invalid accum operation " ++ @tagName(op) ++ " for vector of floats."),
        },
        else => @compileError("Invalid type " ++ @typeName(VecType) ++ " for accum."),
    };

    const fn_container = struct {
        fn opFn(a: VecType, b: VecType) VecType {
            return if (Child == bool) switch (op) {
                .And => @select(bool, a, b, @splat(len, false)),
                .Or => @select(bool, a, @splat(len, true), b),
                .Xor => a != b,
                else => unreachable,
            } else switch (op) {
                .And => a & b,
                .Or => a | b,
                .Xor => a ^ b,
                .Add => a + b,
                .Mul => a * b,
                .Min => @minimum(a, b),
                .Max => @maximum(a, b),
            };
        }
    };

    return accumWithFunc(hop, vec, fn_container.opFn, identity);
}

test "vector accum" {
    if (comptime builtin.cpu.arch.isMIPS()) {
        return error.SkipZigTest;
    }

    const int_base = Vector(4, i32){ 11, 23, 9, -21 };
    const float_base = Vector(4, f32){ 2, 0.5, -10, 6.54321 };
    const bool_base = Vector(4, bool){ true, false, true, false };

    try std.testing.expectEqual(countUp(u8, 32) + @splat(32, @as(u8, 1)), accum(.Add, 1, @splat(32, @as(u8, 1))));
    try std.testing.expectEqual(Vector(4, i32){ 11, 3, 1, 1 }, accum(.And, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 31, 31, -1 }, accum(.Or, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 28, 21, -2 }, accum(.Xor, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 34, 43, 22 }, accum(.Add, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 253, 2277, -47817 }, accum(.Mul, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 11, 9, -21 }, accum(.Min, 1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 23, 23, 23 }, accum(.Max, 1, int_base));

    // Not testing add and mul because I'm not gonna try predicting those rounding errors.
    try std.testing.expectEqual(Vector(4, f32){ 2, 0.5, -10, -10 }, accum(.Min, 1, float_base));
    try std.testing.expectEqual(Vector(4, f32){ 2, 2, 2, 6.54321 }, accum(.Max, 1, float_base));

    try std.testing.expectEqual(Vector(4, bool){ true, true, false, false }, accum(.Xor, 1, bool_base));
    try std.testing.expectEqual(Vector(4, bool){ true, true, true, true }, accum(.Or, 1, bool_base));
    try std.testing.expectEqual(Vector(4, bool){ true, false, false, false }, accum(.And, 1, bool_base));

    try std.testing.expectEqual(Vector(4, i32){ 11, 23, 20, 2 }, accum(.Add, 2, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 22, 11, -12, -21 }, accum(.Add, -1, int_base));
    try std.testing.expectEqual(Vector(4, i32){ 11, 23, 9, -10 }, accum(.Add, 3, int_base));
}
