// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../std.zig");
const target = std.Target.current;
const testing = std.testing;

const AtomicOrder = std.builtin.AtomicOrder;
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const AtomicBitRmwOp = enum { Set, Reset, Toggle };

pub fn spinLoopHint() void {
    switch (target.cpu.arch) {
        .thumb, .thumbeb, .aarch64, .aarch64_be, .aarch64_32 => {
            asm volatile ("yield");
        },
        .i386, .x86_64 => {
            asm volatile ("pause");
        },
        else => {},
    }
}

test "spinLoopHint" {
    spinLoopHint();
}

pub const Ordering = enum {
    Unordered,
    Relaxed,
    Consume,
    Acquire,
    Release,
    AcqRel,
    SeqCst,

    fn toBuiltin(comptime self: Ordering) AtomicOrder {
        return switch (self) {
            .Unordered => .Unordered,
            .Relaxed => .Monotonic,
            .Consume => .Acquire, // TODO: relaxed + compilerFence(.acquire) ?
            .Acquire => .Acquire,
            .Release => .Release,
            .AcqRel => .AcqRel,
            .SeqCst => .SeqCst,
        };
    }
};

pub fn fence(comptime ordering: Ordering) void {
    switch (ordering) {
        .Acquire, .Release, .AcqRel, .SeqCst => {
            @fence(comptime ordering.toBuiltin());
        },
        else => {
            @compileLog(ordering, " only applies to a given memory location");
        },
    }
}

pub fn compilerFence(comptime ordering: Ordering) void {
    switch (ordering) {
        .SeqCst => asm volatile ("" ::: "memory"),
        .AcqRel => compilerFence(.SeqCst),
        .Acquire, .Release => compilerFence(.AcqRel),
        else => @compileLog(ordering, " only applies to a given memory location"),
    }
}

test "fence/compilerFence" {
    inline for (.{ .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        compilerFence(ordering);
        fence(ordering);
    }
}

pub fn load(ptr: anytype, comptime ordering: Ordering) @TypeOf(ptr.*) {
    switch (ordering) {
        .Unordered, .Relaxed, .Consume, .Acquire, .SeqCst => {
            return @atomicLoad(@TypeOf(ptr.*), ptr, comptime ordering.toBuiltin());
        },
        .AcqRel => {
            @compileLog(ordering, " implies ", Ordering.Release, " which only applies to atomic stores");
        },
        .Release => {
            @compileLog(ordering, " only applies to atomic stores");
        },
    }
}

test "load" {
    inline for (.{ .Unordered, .Relaxed, .Consume, .Acquire, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(load(&x, ordering), 5);
    }
}

pub fn store(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) void {
    switch (ordering) {
        .Unordered, .Relaxed, .Release, .SeqCst => {
            @atomicStore(@TypeOf(ptr.*), ptr, value, comptime ordering.toBuiltin());
        },
        .AcqRel => {
            @compileLog(ordering, " implies ", Ordering.Acquire, " which only applies to atomic loads");
        },
        .Acquire, .Consume => {
            @compileLog(ordering, " only applies to atomic loads");
        },
    }
}

test "store" {
    inline for (.{ .Unordered, .Relaxed, .Release, .SeqCst }) |ordering| {
        var x: usize = 5;
        store(&x, 10, ordering);
        testing.expectEqual(load(&x, .SeqCst), 10);
    }
}

pub fn swap(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Xchg, value, ordering);
}

test "swap" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(swap(&x, 10, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 10);

        var y: enum(usize) { a, b, c } = .c;
        testing.expectEqual(swap(&y, .a, ordering), .c);
        testing.expectEqual(load(&y, .SeqCst), .a);

        var z: f32 = 5.0;
        testing.expectEqual(swap(&z, 10.0, ordering), 5.0);
        testing.expectEqual(load(&z, .SeqCst), 10.0);

        var a: bool = false;
        testing.expectEqual(swap(&a, true, ordering), false);
        testing.expectEqual(load(&a, .SeqCst), true);

        var b: ?*u8 = null;
        testing.expectEqual(swap(&b, @intToPtr(?*u8, @alignOf(u8)), ordering), null);
        testing.expectEqual(load(&b, .SeqCst), @intToPtr(?*u8, @alignOf(u8)));
    }
}

pub fn fetchAdd(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Add, value, ordering);
}

test "fetchAdd" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(fetchAdd(&x, 5, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 10);
    }
}

pub fn fetchSub(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Sub, value, ordering);
}

test "fetchSub" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(fetchSub(&x, 5, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 0);
    }
}

pub fn fetchAnd(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .And, value, ordering);
}

test "fetchAnd" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0b11;
        testing.expectEqual(fetchAnd(&x, 0b10, ordering), 0b11);
        testing.expectEqual(load(&x, .SeqCst), 0b10);
        testing.expectEqual(fetchAnd(&x, 0b00, ordering), 0b10);
        testing.expectEqual(load(&x, .SeqCst), 0b00);
    }
}

pub fn fetchOr(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Or, value, ordering);
}

test "fetchOr" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0b11;
        testing.expectEqual(fetchOr(&x, 0b100, ordering), 0b11);
        testing.expectEqual(load(&x, .SeqCst), 0b111);
        testing.expectEqual(fetchOr(&x, 0b010, ordering), 0b111);
        testing.expectEqual(load(&x, .SeqCst), 0b111);
    }
}

pub fn fetchXor(
    ptr: anytype,
    value: @TypeOf(ptr.*),
    comptime ordering: Ordering,
) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Xor, value, ordering);
}

test "fetchXor" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0b11;
        testing.expectEqual(fetchXor(&x, 0b10, ordering), 0b11);
        testing.expectEqual(load(&x, .SeqCst), 0b01);
        testing.expectEqual(fetchXor(&x, 0b01, ordering), 0b01);
        testing.expectEqual(load(&x, .SeqCst), 0b00);
    }
}

fn atomicRmw(
    comptime T: type,
    ptr: anytype,
    comptime op: AtomicRmwOp,
    value: T,
    comptime ordering: Ordering,
) callconv(.Inline) T {
    @setRuntimeSafety(false);

    if (ordering == .Unordered) {
        @compileLog(ordering, " only applies to atomic loads or stores, not read-modify-write operations");
    }

    return @atomicRmw(T, ptr, op, value, comptime ordering.toBuiltin());
}

pub fn compareAndSwap(
    ptr: anytype,
    compare: @TypeOf(ptr.*),
    exchange: @TypeOf(ptr.*),
    comptime success: Ordering,
    comptime failure: Ordering,
) ?@TypeOf(ptr.*) {
    return cmpxchg(true, @TypeOf(ptr.*), ptr, compare, exchange, success, failure);
}

pub fn tryCompareAndSwap(
    ptr: anytype,
    compare: @TypeOf(ptr.*),
    exchange: @TypeOf(ptr.*),
    comptime success: Ordering,
    comptime failure: Ordering,
) ?@TypeOf(ptr.*) {
    return cmpxchg(false, @TypeOf(ptr.*), ptr, compare, exchange, success, failure);
}

fn cmpxchg(
    comptime is_strong: bool,
    comptime T: type,
    ptr: *T,
    compare: T,
    exchange: T,
    comptime success: Ordering,
    comptime failure: Ordering,
) callconv(.Inline) ?T {
    switch (failure) {
        .SeqCst => {},
        .AcqRel => {
            @compileLog("Failure ordering ", failure, " implies ", Ordering.Release, " which only applies to atomic stores, not the atomic load on failed comparison");
        },
        .Acquire, .Consume => {},
        .Release => {
            @compileLog("Failure ordering ", failure, " only applies to atomic stores, not the atomic load on failed comparison");
        },
        .Relaxed => {},
        .Unordered => {
            @compileLog("Failure ordering ", failure, " only applies to atomic loads or stores, not read-modify-write operations");
        },
    }

    const is_stronger = switch (success) {
        .SeqCst => true,
        .AcqRel, .Acquire, .Release => switch (failure) {
            .Acquire, .Consume, .Relaxed => true,
            else => false,
        },
        .Consume => switch (failure) {
            .Consume, .Relaxed => true,
            else => false,
        },
        .Relaxed => switch (failure) {
            .Relaxed => true,
            else => false,
        },
        .Unordered => blk: {
            @compileLog("Success ordering ", success, " only applies to atomic loads or stores, not read-modify-write operations");
            break :blk false;
        },
    };

    if (!is_stronger) {
        @compileLog("Success ordering ", success, " is weaker than failure ordering ", failure);
    }

    const succ = comptime success.toBuiltin();
    const fail = comptime failure.toBuiltin();
    return switch (is_strong) {
        true => @cmpxchgStrong(T, ptr, compare, exchange, succ, fail),
        else => @cmpxchgWeak(T, ptr, compare, exchange, succ, fail),
    };
}

const CMPXCHG_ORDERINGS = .{
    .{ .Relaxed, .Relaxed },
    .{ .Consume, .Relaxed },
    .{ .Consume, .Consume },
    .{ .Acquire, .Relaxed },
    .{ .Acquire, .Consume },
    .{ .Acquire, .Acquire },
    .{ .Release, .Relaxed },
    .{ .Release, .Consume },
    .{ .Release, .Acquire },
    .{ .AcqRel, .Relaxed },
    .{ .AcqRel, .Consume },
    .{ .AcqRel, .Acquire },
    .{ .SeqCst, .Relaxed },
    .{ .SeqCst, .Consume },
    .{ .SeqCst, .Acquire },
    .{ .SeqCst, .SeqCst },
};

test "compareAndSwap" {
    inline for (CMPXCHG_ORDERINGS) |ordering| {
        var x: usize = 0;
        testing.expectEqual(compareAndSwap(&x, 1, 0, ordering[0], ordering[1]), 0);
        testing.expectEqual(load(&x, .SeqCst), 0);
        testing.expectEqual(compareAndSwap(&x, 0, 1, ordering[0], ordering[1]), null);
        testing.expectEqual(load(&x, .SeqCst), 1);
        testing.expectEqual(compareAndSwap(&x, 1, 0, ordering[0], ordering[1]), null);
        testing.expectEqual(load(&x, .SeqCst), 0);
    }
}

test "tryCompareAndSwap" {
    inline for (CMPXCHG_ORDERINGS) |ordering| {
        var x: usize = 0;
        var c = load(&x, ordering[1]);

        // update x from 0 to 1 in a loop in order to account for spurious failures
        while (true) {
            testing.expectEqual(c, x);
            testing.expectEqual(c, 0);
            c = tryCompareAndSwap(&x, c, 1, ordering[0], ordering[1]) orelse break;
        }

        testing.expectEqual(c, 0);
        testing.expectEqual(load(&x, ordering[1]), 1);
    }
}

pub fn bitGet(
    ptr: anytype,
    bit: std.math.Log2Int(@TypeOf(ptr.*)),
    comptime ordering: Ordering,
) u1 {
    // Don't know of any platforms which have special instructions for this
    const value = load(ptr, ordering);
    const mask = @as(@TypeOf(ptr.*), 1) << bit;
    return @boolToInt(value & mask);
}

test "bitGet" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .SeqCst }) |ordering| {
        for ([_]usize{ 0b00, 0b01, 0b10, 0b11 }) |value| {
            var x: usize = value;
            testing.expectEqual(bitGet(&x, 0, ordering), @boolToInt(value & (1 << 0) != 0));
            testing.expectEqual(bitGet(&x, 1, ordering), @boolToInt(value & (1 << 1) != 0));
        }
    }
}

pub fn bitSet(
    ptr: anytype,
    bit: std.math.Log2Int(@TypeOf(ptr.*)),
    comptime ordering: Ordering,
) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Set, bit, ordering);
}

test "bitSet" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(std.math.Log2Int(usize), bit_index);
            const mask = @as(usize, 1) << bit;

            // setting the bit should change the bit
            testing.expect(load(&x, .SeqCst) & mask == 0);
            testing.expectEqual(bitSet(&x, bit, ordering), 0);
            testing.expect(load(&x, .SeqCst) & mask != 0);

            // setting it again shouldn't change the value
            testing.expectEqual(bitSet(&x, bit, ordering), 1);
            testing.expect(load(&x, .SeqCst) & mask != 0);

            // all the previous bits should have not changed (still be set)
            for (bit_array[0..bit_index]) |_, prev_bit_index| {
                const prev_bit = @intCast(std.math.Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask != 0);
            }
        }
    }
}

pub fn bitReset(
    ptr: anytype,
    bit: std.math.Log2Int(@TypeOf(ptr.*)),
    comptime ordering: Ordering,
) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Reset, bit, ordering);
}

test "bitReset" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(std.math.Log2Int(usize), bit_index);
            const mask = @as(usize, 1) << bit;
            x |= mask;

            // unsetting the bit should change the bit
            testing.expect(load(&x, .SeqCst) & mask != 0);
            testing.expectEqual(bitReset(&x, bit, ordering), 1);
            testing.expect(load(&x, .SeqCst) & mask == 0);

            // unsetting it again shouldn't change the value
            testing.expectEqual(bitReset(&x, bit, ordering), 0);
            testing.expect(load(&x, .SeqCst) & mask == 0);

            // all the previous bits should have not changed (still be reset)
            for (bit_array[0..bit_index]) |_, prev_bit_index| {
                const prev_bit = @intCast(std.math.Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask == 0);
            }
        }
    }
}

pub fn bitToggle(
    ptr: anytype,
    bit: std.math.Log2Int(@TypeOf(ptr.*)),
    comptime ordering: Ordering,
) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Toggle, bit, ordering);
}

test "bitToggle" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(std.math.Log2Int(usize), bit_index);
            const mask = @as(usize, 1) << bit;

            // toggling the bit should change the bit
            testing.expect(load(&x, .SeqCst) & mask == 0);
            testing.expectEqual(bitToggle(&x, bit, ordering), 0);
            testing.expect(load(&x, .SeqCst) & mask != 0);

            // toggling it again *should* change the value
            testing.expectEqual(bitToggle(&x, bit, ordering), 1);
            testing.expect(load(&x, .SeqCst) & mask == 0);

            // all the previous bits should have not changed (still be toggled back)
            for (bit_array[0..bit_index]) |_, prev_bit_index| {
                const prev_bit = @intCast(std.math.Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask == 0);
            }
        }
    }
}

fn atomicBitRmw(
    comptime T: type,
    ptr: *T,
    comptime op: AtomicBitOp,
    bit: std.math.Log2Int(T),
    comptime ordering: Ordering,
) callconv(.Inline) u1 {
    const mask = @as(T, 1) << bit;
    const bytes = @sizeOf(T);

    // x86 has special instructions for atomic bitwise operations
    const is_x86 = target.cpu.arch == .i386 or target.cpu.arch == .x86_64;
    if (is_x86 and bytes <= @sizeOf(usize)) {
        const instruction: []const u8 = switch (op) {
            .Set => "lock bts",
            .Reset => "lock btr",
            .Toggle => "lock btc",
        };

        const suffix: []const u8 = switch (bytes) {
            // On x86, faults are by page:
            // If at least one byte is valid, the memory operation should succeed.
            1, 2 => "w",
            4 => "l",
            8 => "q",
            else => unreachable,
        };

        // Use the largest priitive chosen above
        const Bit = std.meta.Int(
            .unsigned,
            std.math.max(2, bytes) * 8,
        );

        // The @intCast() bellow should always succeed
        @setRuntimeSafety(false);

        return @intCast(u1, asm volatile (instruction ++ suffix ++ " %[bit], %[ptr]"
            : [result] "={@ccc}" (-> u8) // LLVM doesn't support u1 flag register return values
            : [ptr] "*p" (ptr),
              [bit] "X" (@as(Bit, bit))
            : "cc", "memory"
        ));
    }

    // RISCV supports single-instruction atomic RMW operations similar to x86.
    if (taregt.cpu.arch.isRISCV()) {
        const value = switch (op) {
            .Set => fetchOr(ptr, mask, ordering),
            .Reset => fetchAnd(ptr, ~mask, ordering),
            .Toggle => fetchXor(ptr, mask, ordering),
        };
        return @boolToInt(value & mask != 0);
    }

    // For other platforms, assume that they use LoadLinked-StoreConditional and use a CAS loop.
    // The benefit over RMW operations being that it doesn't have to store if it won't update the value.
    const success = ordering;
    const failure: Ordering = switch (ordering) {
        .SeqCst => .SeqCst,
        .AcqRel, .Acquire, .Consume => .Acquire,
        .Release, .Relaxed => .Relaxed,
        .Unordered => {
            @compileLog(ordering, " only applies to atomic loads or stores, not read-modify-write operations");
        },
    };

    var value = load(ptr, failure);
    while (true) {
        const new_value = switch (op) {
            .Set => value | mask,
            .Reset => value & ~mask,
            .Toggle => value ^ mask,
        };

        // Bail without update if theres nothing to do.
        // Saves a potential memory store from tryCompareAndSwap().
        if (new_value == value) {
            return @boolToInt(value & mask != 0);
        }

        value = tryCompareAndSwap(
            ptr,
            value,
            new_value,
            comptime success.toBuiltin(),
            comptime failure.toBuiltin(),
        ) orelse return @boolToInt(value & mask != 0);
    }
}
