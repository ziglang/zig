//! SIMD (Single Instruction; Multiple Data) convenience functions.
//!
//! May offer a potential boost in performance on some targets by performing
//! the same operations on multiple elements at once.
//!
//! Some functions are known to not work on MIPS.

const std = @import("std");
const builtin = @import("builtin");

pub const suggestVectorSizeForCpu = @compileError("deprecated; use 'suggestVectorLengthForCpu'");

pub fn suggestVectorLengthForCpu(comptime T: type, comptime cpu: std.Target.Cpu) ?comptime_int {
    // This is guesswork, if you have better suggestions can add it or edit the current here
    // This can run in comptime only, but stage 1 fails at it, stage 2 can understand it
    const element_bit_size = @max(8, std.math.ceilPowerOfTwo(u16, @bitSizeOf(T)) catch unreachable);
    const vector_bit_size: u16 = blk: {
        if (cpu.arch.isX86()) {
            if (T == bool and std.Target.x86.featureSetHas(cpu.features, .prefer_mask_registers)) return 64;
            if (builtin.zig_backend != .stage2_x86_64 and std.Target.x86.featureSetHas(cpu.features, .avx512f) and !std.Target.x86.featureSetHasAny(cpu.features, .{ .prefer_256_bit, .prefer_128_bit })) break :blk 512;
            if (std.Target.x86.featureSetHasAny(cpu.features, .{ .prefer_256_bit, .avx2 }) and !std.Target.x86.featureSetHas(cpu.features, .prefer_128_bit)) break :blk 256;
            if (std.Target.x86.featureSetHas(cpu.features, .sse)) break :blk 128;
            if (std.Target.x86.featureSetHasAny(cpu.features, .{ .mmx, .@"3dnow" })) break :blk 64;
        } else if (cpu.arch.isARM()) {
            if (std.Target.arm.featureSetHas(cpu.features, .neon)) break :blk 128;
        } else if (cpu.arch.isAARCH64()) {
            // SVE allows up to 2048 bits in the specification, as of 2022 the most powerful machine has implemented 512-bit
            // I think is safer to just be on 128 until is more common
            // TODO: Check on this return when bigger values are more common
            if (std.Target.aarch64.featureSetHas(cpu.features, .sve)) break :blk 128;
            if (std.Target.aarch64.featureSetHas(cpu.features, .neon)) break :blk 128;
        } else if (cpu.arch.isPPC() or cpu.arch.isPPC64()) {
            if (std.Target.powerpc.featureSetHas(cpu.features, .altivec)) break :blk 128;
        } else if (cpu.arch.isMIPS()) {
            if (std.Target.mips.featureSetHas(cpu.features, .msa)) break :blk 128;
            // TODO: Test MIPS capability to handle bigger vectors
            //       In theory MDMX and by extension mips3d have 32 registers of 64 bits which can use in parallel
            //       for multiple processing, but I don't know what's optimal here, if using
            //       the 2048 bits or using just 64 per vector or something in between
            if (std.Target.mips.featureSetHas(cpu.features, std.Target.mips.Feature.mips3d)) break :blk 64;
        } else if (cpu.arch.isRISCV()) {
            // in risc-v the Vector Extension allows configurable vector sizes, but a standard size of 128 is a safe estimate
            if (std.Target.riscv.featureSetHas(cpu.features, .v)) break :blk 128;
        } else if (cpu.arch.isSPARC()) {
            // TODO: Test Sparc capability to handle bigger vectors
            //       In theory Sparc have 32 registers of 64 bits which can use in parallel
            //       for multiple processing, but I don't know what's optimal here, if using
            //       the 2048 bits or using just 64 per vector or something in between
            if (std.Target.sparc.featureSetHasAny(cpu.features, .{ .vis, .vis2, .vis3 })) break :blk 64;
        } else if (cpu.arch.isWasm()) {
            if (std.Target.wasm.featureSetHas(cpu.features, .simd128)) break :blk 128;
        }
        return null;
    };
    if (vector_bit_size <= element_bit_size) return null;

    return @divExact(vector_bit_size, element_bit_size);
}

pub const suggestVectorSize = @compileError("deprecated; use 'suggestVectorLength'");

/// Suggests a target-dependant vector length for a given type, or null if scalars are recommended.
/// Not yet implemented for every CPU architecture.
pub fn suggestVectorLength(comptime T: type) ?comptime_int {
    return suggestVectorLengthForCpu(T, builtin.cpu);
}

test "suggestVectorLengthForCpu works with signed and unsigned values" {
    comptime var cpu = std.Target.Cpu.baseline(std.Target.Cpu.Arch.x86_64);
    comptime cpu.features.addFeature(@intFromEnum(std.Target.x86.Feature.avx512f));
    comptime cpu.features.populateDependencies(&std.Target.x86.all_features);
    const expected_len: usize = switch (builtin.zig_backend) {
        .stage2_x86_64 => 8,
        else => 16,
    };
    const signed_integer_len = suggestVectorLengthForCpu(i32, cpu).?;
    const unsigned_integer_len = suggestVectorLengthForCpu(u32, cpu).?;
    try std.testing.expectEqual(expected_len, unsigned_integer_len);
    try std.testing.expectEqual(expected_len, signed_integer_len);
}

fn vectorLength(comptime VectorType: type) comptime_int {
    return switch (@typeInfo(VectorType)) {
        .Vector => |info| info.len,
        .Array => |info| info.len,
        else => @compileError("Invalid type " ++ @typeName(VectorType)),
    };
}

/// Returns the smallest type of unsigned ints capable of indexing any element within the given vector type.
pub fn VectorIndex(comptime VectorType: type) type {
    return std.math.IntFittingRange(0, vectorLength(VectorType) - 1);
}

/// Returns the smallest type of unsigned ints capable of holding the length of the given vector type.
pub fn VectorCount(comptime VectorType: type) type {
    return std.math.IntFittingRange(0, vectorLength(VectorType));
}

/// Returns a vector containing the first `len` integers in order from 0 to `len`-1.
/// For example, `iota(i32, 8)` will return a vector containing `.{0, 1, 2, 3, 4, 5, 6, 7}`.
pub inline fn iota(comptime T: type, comptime len: usize) @Vector(len, T) {
    comptime {
        var out: [len]T = undefined;
        for (&out, 0..) |*element, i| {
            element.* = switch (@typeInfo(T)) {
                .Int => @as(T, @intCast(i)),
                .Float => @as(T, @floatFromInt(i)),
                else => @compileError("Can't use type " ++ @typeName(T) ++ " in iota."),
            };
        }
        return @as(@Vector(len, T), out);
    }
}

/// Returns a vector containing the same elements as the input, but repeated until the desired length is reached.
/// For example, `repeat(8, [_]u32{1, 2, 3})` will return a vector containing `.{1, 2, 3, 1, 2, 3, 1, 2}`.
pub fn repeat(comptime len: usize, vec: anytype) @Vector(len, std.meta.Child(@TypeOf(vec))) {
    const Child = std.meta.Child(@TypeOf(vec));

    return @shuffle(Child, vec, undefined, iota(i32, len) % @as(@Vector(len, i32), @splat(@intCast(vectorLength(@TypeOf(vec))))));
}

/// Returns a vector containing all elements of the first vector at the lower indices followed by all elements of the second vector
/// at the higher indices.
pub fn join(a: anytype, b: anytype) @Vector(vectorLength(@TypeOf(a)) + vectorLength(@TypeOf(b)), std.meta.Child(@TypeOf(a))) {
    const Child = std.meta.Child(@TypeOf(a));
    const a_len = vectorLength(@TypeOf(a));
    const b_len = vectorLength(@TypeOf(b));

    return @shuffle(Child, a, b, @as([a_len]i32, iota(i32, a_len)) ++ @as([b_len]i32, ~iota(i32, b_len)));
}

/// Returns a vector whose elements alternates between those of each input vector.
/// For example, `interlace(.{[4]u32{11, 12, 13, 14}, [4]u32{21, 22, 23, 24}})` returns a vector containing `.{11, 21, 12, 22, 13, 23, 14, 24}`.
pub fn interlace(vecs: anytype) @Vector(vectorLength(@TypeOf(vecs[0])) * vecs.len, std.meta.Child(@TypeOf(vecs[0]))) {
    // interlace doesn't work on MIPS, for some reason.
    // Notes from earlier debug attempt:
    //  The indices are correct. The problem seems to be with the @shuffle builtin.
    //  On MIPS, the test that interlaces small_base gives { 0, 2, 0, 0, 64, 255, 248, 200, 0, 0 }.
    //  Calling this with two inputs seems to work fine, but I'll let the compile error trigger for all inputs, just to be safe.
    comptime if (builtin.cpu.arch.isMIPS()) @compileError("TODO: Find out why interlace() doesn't work on MIPS");

    const VecType = @TypeOf(vecs[0]);
    const vecs_arr = @as([vecs.len]VecType, vecs);
    const Child = std.meta.Child(@TypeOf(vecs_arr[0]));

    if (vecs_arr.len == 1) return vecs_arr[0];

    const a_vec_count = (1 + vecs_arr.len) >> 1;
    const b_vec_count = vecs_arr.len >> 1;

    const a = interlace(@as(*const [a_vec_count]VecType, @ptrCast(vecs_arr[0..a_vec_count])).*);
    const b = interlace(@as(*const [b_vec_count]VecType, @ptrCast(vecs_arr[a_vec_count..])).*);

    const a_len = vectorLength(@TypeOf(a));
    const b_len = vectorLength(@TypeOf(b));
    const len = a_len + b_len;

    const indices = comptime blk: {
        const Vi32 = @Vector(len, i32);
        const count_up = iota(i32, len);
        const cycle = @divFloor(count_up, @as(Vi32, @splat(@intCast(vecs_arr.len))));
        const select_mask = repeat(len, join(@as(@Vector(a_vec_count, bool), @splat(true)), @as(@Vector(b_vec_count, bool), @splat(false))));
        const a_indices = count_up - cycle * @as(Vi32, @splat(@intCast(b_vec_count)));
        const b_indices = shiftElementsRight(count_up - cycle * @as(Vi32, @splat(@intCast(a_vec_count))), a_vec_count, 0);
        break :blk @select(i32, select_mask, a_indices, ~b_indices);
    };

    return @shuffle(Child, a, b, indices);
}

/// The contents of `interlaced` is evenly split between vec_count vectors that are returned as an array. They "take turns",
/// receiving one element from `interlaced` at a time.
pub fn deinterlace(
    comptime vec_count: usize,
    interlaced: anytype,
) [vec_count]@Vector(
    vectorLength(@TypeOf(interlaced)) / vec_count,
    std.meta.Child(@TypeOf(interlaced)),
) {
    const vec_len = vectorLength(@TypeOf(interlaced)) / vec_count;
    const Child = std.meta.Child(@TypeOf(interlaced));

    var out: [vec_count]@Vector(vec_len, Child) = undefined;

    comptime var i: usize = 0; // for-loops don't work for this, apparently.
    inline while (i < out.len) : (i += 1) {
        const indices = comptime iota(i32, vec_len) * @as(@Vector(vec_len, i32), @splat(@intCast(vec_count))) + @as(@Vector(vec_len, i32), @splat(@intCast(i)));
        out[i] = @shuffle(Child, interlaced, undefined, indices);
    }

    return out;
}

pub fn extract(
    vec: anytype,
    comptime first: VectorIndex(@TypeOf(vec)),
    comptime count: VectorCount(@TypeOf(vec)),
) @Vector(count, std.meta.Child(@TypeOf(vec))) {
    const Child = std.meta.Child(@TypeOf(vec));
    const len = vectorLength(@TypeOf(vec));

    std.debug.assert(@as(comptime_int, @intCast(first)) + @as(comptime_int, @intCast(count)) <= len);

    return @shuffle(Child, vec, undefined, iota(i32, count) + @as(@Vector(count, i32), @splat(@intCast(first))));
}

test "vector patterns" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/12012
        return error.SkipZigTest;
    }

    const base = @Vector(4, u32){ 10, 20, 30, 40 };
    const other_base = @Vector(4, u32){ 55, 66, 77, 88 };

    const small_bases = [5]@Vector(2, u8){
        @Vector(2, u8){ 0, 1 },
        @Vector(2, u8){ 2, 3 },
        @Vector(2, u8){ 4, 5 },
        @Vector(2, u8){ 6, 7 },
        @Vector(2, u8){ 8, 9 },
    };

    try std.testing.expectEqual([6]u32{ 10, 20, 30, 40, 10, 20 }, repeat(6, base));
    try std.testing.expectEqual([8]u32{ 10, 20, 30, 40, 55, 66, 77, 88 }, join(base, other_base));
    try std.testing.expectEqual([2]u32{ 20, 30 }, extract(base, 1, 2));

    if (comptime !builtin.cpu.arch.isMIPS()) {
        try std.testing.expectEqual([8]u32{ 10, 55, 20, 66, 30, 77, 40, 88 }, interlace(.{ base, other_base }));

        const small_braid = interlace(small_bases);
        try std.testing.expectEqual([10]u8{ 0, 2, 4, 6, 8, 1, 3, 5, 7, 9 }, small_braid);
        try std.testing.expectEqual(small_bases, deinterlace(small_bases.len, small_braid));
    }
}

/// Joins two vectors, shifts them leftwards (towards lower indices) and extracts the leftmost elements into a vector the length of a and b.
pub fn mergeShift(a: anytype, b: anytype, comptime shift: VectorCount(@TypeOf(a, b))) @TypeOf(a, b) {
    const len = vectorLength(@TypeOf(a, b));

    return extract(join(a, b), shift, len);
}

/// Elements are shifted rightwards (towards higher indices). New elements are added to the left, and the rightmost elements are cut off
/// so that the length of the vector stays the same.
pub fn shiftElementsRight(vec: anytype, comptime amount: VectorCount(@TypeOf(vec)), shift_in: std.meta.Child(@TypeOf(vec))) @TypeOf(vec) {
    // It may be possible to implement shifts and rotates with a runtime-friendly slice of two joined vectors, as the length of the
    // slice would be comptime-known. This would permit vector shifts and rotates by a non-comptime-known amount.
    // However, I am unsure whether compiler optimizations would handle that well enough on all platforms.
    const V = @TypeOf(vec);
    const len = vectorLength(V);

    return mergeShift(@as(V, @splat(shift_in)), vec, len - amount);
}

/// Elements are shifted leftwards (towards lower indices). New elements are added to the right, and the leftmost elements are cut off
/// so that no elements with indices below 0 remain.
pub fn shiftElementsLeft(vec: anytype, comptime amount: VectorCount(@TypeOf(vec)), shift_in: std.meta.Child(@TypeOf(vec))) @TypeOf(vec) {
    const V = @TypeOf(vec);

    return mergeShift(vec, @as(V, @splat(shift_in)), amount);
}

/// Elements are shifted leftwards (towards lower indices). Elements that leave to the left will reappear to the right in the same order.
pub fn rotateElementsLeft(vec: anytype, comptime amount: VectorCount(@TypeOf(vec))) @TypeOf(vec) {
    return mergeShift(vec, vec, amount);
}

/// Elements are shifted rightwards (towards higher indices). Elements that leave to the right will reappear to the left in the same order.
pub fn rotateElementsRight(vec: anytype, comptime amount: VectorCount(@TypeOf(vec))) @TypeOf(vec) {
    return rotateElementsLeft(vec, vectorLength(@TypeOf(vec)) - amount);
}

pub fn reverseOrder(vec: anytype) @TypeOf(vec) {
    const Child = std.meta.Child(@TypeOf(vec));
    const len = vectorLength(@TypeOf(vec));

    return @shuffle(Child, vec, undefined, @as(@Vector(len, i32), @splat(@as(i32, @intCast(len)) - 1)) - iota(i32, len));
}

test "vector shifting" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const base = @Vector(4, u32){ 10, 20, 30, 40 };

    try std.testing.expectEqual([4]u32{ 30, 40, 999, 999 }, shiftElementsLeft(base, 2, 999));
    try std.testing.expectEqual([4]u32{ 999, 999, 10, 20 }, shiftElementsRight(base, 2, 999));
    try std.testing.expectEqual([4]u32{ 20, 30, 40, 10 }, rotateElementsLeft(base, 1));
    try std.testing.expectEqual([4]u32{ 40, 10, 20, 30 }, rotateElementsRight(base, 1));
    try std.testing.expectEqual([4]u32{ 40, 30, 20, 10 }, reverseOrder(base));
}

pub fn firstTrue(vec: anytype) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const IndexInt = VectorIndex(@TypeOf(vec));

    if (!@reduce(.Or, vec)) {
        return null;
    }
    const all_max: @Vector(len, IndexInt) = @splat(~@as(IndexInt, 0));
    const indices = @select(IndexInt, vec, iota(IndexInt, len), all_max);
    return @reduce(.Min, indices);
}

pub fn lastTrue(vec: anytype) ?VectorIndex(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const IndexInt = VectorIndex(@TypeOf(vec));

    if (!@reduce(.Or, vec)) {
        return null;
    }

    const all_zeroes: @Vector(len, IndexInt) = @splat(0);
    const indices = @select(IndexInt, vec, iota(IndexInt, len), all_zeroes);
    return @reduce(.Max, indices);
}

pub fn countTrues(vec: anytype) VectorCount(@TypeOf(vec)) {
    const len = vectorLength(@TypeOf(vec));
    const CountIntType = VectorCount(@TypeOf(vec));

    const all_ones: @Vector(len, CountIntType) = @splat(1);
    const all_zeroes: @Vector(len, CountIntType) = @splat(0);

    const one_if_true = @select(CountIntType, vec, all_ones, all_zeroes);
    return @reduce(.Add, one_if_true);
}

pub fn firstIndexOfValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) ?VectorIndex(@TypeOf(vec)) {
    const V = @TypeOf(vec);

    return firstTrue(vec == @as(V, @splat(value)));
}

pub fn lastIndexOfValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) ?VectorIndex(@TypeOf(vec)) {
    const V = @TypeOf(vec);

    return lastTrue(vec == @as(V, @splat(value)));
}

pub fn countElementsWithValue(vec: anytype, value: std.meta.Child(@TypeOf(vec))) VectorCount(@TypeOf(vec)) {
    const V = @TypeOf(vec);

    return countTrues(vec == @as(V, @splat(value)));
}

test "vector searching" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const base = @Vector(8, u32){ 6, 4, 7, 4, 4, 2, 3, 7 };

    try std.testing.expectEqual(@as(?u3, 1), firstIndexOfValue(base, 4));
    try std.testing.expectEqual(@as(?u3, 4), lastIndexOfValue(base, 4));
    try std.testing.expectEqual(@as(?u3, null), lastIndexOfValue(base, 99));
    try std.testing.expectEqual(@as(u4, 3), countElementsWithValue(base, 4));
}

/// Same as prefixScan, but with a user-provided, mathematically associative function.
pub fn prefixScanWithFunc(
    comptime hop: isize,
    vec: anytype,
    /// The error type that `func` might return. Set this to `void` if `func` doesn't return an error union.
    comptime ErrorType: type,
    comptime func: fn (@TypeOf(vec), @TypeOf(vec)) if (ErrorType == void) @TypeOf(vec) else ErrorType!@TypeOf(vec),
    /// When one operand of the operation performed by `func` is this value, the result must equal the other operand.
    /// For example, this should be 0 for addition or 1 for multiplication.
    comptime identity: std.meta.Child(@TypeOf(vec)),
) if (ErrorType == void) @TypeOf(vec) else ErrorType!@TypeOf(vec) {
    // I haven't debugged this, but it might be a cousin of sorts to what's going on with interlace.
    comptime if (builtin.cpu.arch.isMIPS()) @compileError("TODO: Find out why prefixScan doesn't work on MIPS");

    const len = vectorLength(@TypeOf(vec));

    if (hop == 0) @compileError("hop can not be 0; you'd be going nowhere forever!");
    const abs_hop = if (hop < 0) -hop else hop;

    var acc = vec;
    comptime var i = 0;
    inline while ((abs_hop << i) < len) : (i += 1) {
        const shifted = if (hop < 0) shiftElementsLeft(acc, abs_hop << i, identity) else shiftElementsRight(acc, abs_hop << i, identity);

        acc = if (ErrorType == void) func(acc, shifted) else try func(acc, shifted);
    }
    return acc;
}

/// Returns a vector whose elements are the result of performing the specified operation on the corresponding
/// element of the input vector and every hop'th element that came before it (or after, if hop is negative).
/// Supports the same operations as the @reduce() builtin. Takes O(logN) to compute.
/// The scan is not linear, which may affect floating point errors. This may affect the determinism of
/// algorithms that use this function.
pub fn prefixScan(comptime op: std.builtin.ReduceOp, comptime hop: isize, vec: anytype) @TypeOf(vec) {
    const VecType = @TypeOf(vec);
    const Child = std.meta.Child(VecType);

    const identity = comptime switch (@typeInfo(Child)) {
        .Bool => switch (op) {
            .Or, .Xor => false,
            .And => true,
            else => @compileError("Invalid prefixScan operation " ++ @tagName(op) ++ " for vector of booleans."),
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
            else => @compileError("Invalid prefixScan operation " ++ @tagName(op) ++ " for vector of floats."),
        },
        else => @compileError("Invalid type " ++ @typeName(VecType) ++ " for prefixScan."),
    };

    const fn_container = struct {
        fn opFn(a: VecType, b: VecType) VecType {
            return if (Child == bool) switch (op) {
                .And => @select(bool, a, b, @as(VecType, @splat(false))),
                .Or => @select(bool, a, @as(VecType, @splat(true)), b),
                .Xor => a != b,
                else => unreachable,
            } else switch (op) {
                .And => a & b,
                .Or => a | b,
                .Xor => a ^ b,
                .Add => a + b,
                .Mul => a * b,
                .Min => @min(a, b),
                .Max => @max(a, b),
            };
        }
    };

    return prefixScanWithFunc(hop, vec, void, fn_container.opFn, identity);
}

test "vector prefix scan" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (comptime builtin.cpu.arch.isMIPS()) {
        return error.SkipZigTest;
    }

    const int_base = @Vector(4, i32){ 11, 23, 9, -21 };
    const float_base = @Vector(4, f32){ 2, 0.5, -10, 6.54321 };
    const bool_base = @Vector(4, bool){ true, false, true, false };

    const ones: @Vector(32, u8) = @splat(1);

    try std.testing.expectEqual(iota(u8, 32) + ones, prefixScan(.Add, 1, ones));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 3, 1, 1 }, prefixScan(.And, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 31, 31, -1 }, prefixScan(.Or, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 28, 21, -2 }, prefixScan(.Xor, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 34, 43, 22 }, prefixScan(.Add, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 253, 2277, -47817 }, prefixScan(.Mul, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 11, 9, -21 }, prefixScan(.Min, 1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 23, 23, 23 }, prefixScan(.Max, 1, int_base));

    // Trying to predict all inaccuracies when adding and multiplying floats with prefixScans would be a mess, so we don't test those.
    try std.testing.expectEqual(@Vector(4, f32){ 2, 0.5, -10, -10 }, prefixScan(.Min, 1, float_base));
    try std.testing.expectEqual(@Vector(4, f32){ 2, 2, 2, 6.54321 }, prefixScan(.Max, 1, float_base));

    try std.testing.expectEqual(@Vector(4, bool){ true, true, false, false }, prefixScan(.Xor, 1, bool_base));
    try std.testing.expectEqual(@Vector(4, bool){ true, true, true, true }, prefixScan(.Or, 1, bool_base));
    try std.testing.expectEqual(@Vector(4, bool){ true, false, false, false }, prefixScan(.And, 1, bool_base));

    try std.testing.expectEqual(@Vector(4, i32){ 11, 23, 20, 2 }, prefixScan(.Add, 2, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 22, 11, -12, -21 }, prefixScan(.Add, -1, int_base));
    try std.testing.expectEqual(@Vector(4, i32){ 11, 23, 9, -10 }, prefixScan(.Add, 3, int_base));
}
