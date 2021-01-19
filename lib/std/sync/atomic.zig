// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../std.zig");
const builtin = std.builtin;
const Log2Int = std.math.Log2Int;
const testing = std.testing;

const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicBitOp = enum {
    Get,
    Set,
    Reset,
    Toggle,
};

pub fn spinLoopHint() void {
    switch (builtin.arch) {
        .i386, .x86_64 => asm volatile("pause" ::: "memory"),
        .arm, .aarch64 => asm volatile("yield" ::: "memory"),
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
    @fence(comptime ordering.toBuiltin());
}

pub fn compilerFence(comptime ordering: Ordering) void {
    switch (ordering) {
        .Unordered => @compileError("Unordered memory ordering can only be on atomic variables"),
        .Relaxed => @compileError("Relaxed memory ordering can only be on atomic variables"),
        .Consume => @compileError("Consume memory ordering can only be on atomic variables"),
        else => asm volatile("" ::: "memory"),
    }
}

test "fence/compilerFence" {
    inline for (.{ .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        compilerFence(ordering);
        fence(ordering);
    }
}

pub fn load(ptr: anytype, comptime ordering: Ordering) @TypeOf(ptr.*) {
    return @atomicLoad(@TypeOf(ptr.*), ptr, comptime ordering.toBuiltin());
}

test "load" {
    inline for (.{ .Unordered, .Relaxed, .Consume, .Acquire, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(load(&x, ordering), 5);
    }
}

pub fn store(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) void {
    return @atomicStore(@TypeOf(ptr.*), ptr, value, comptime ordering.toBuiltin());
}

test "store" {
    inline for (.{ .Unordered, .Relaxed, .Release, .SeqCst }) |ordering| {
        var x: usize = 5;
        store(&x, 10, ordering);
        testing.expectEqual(load(&x, .SeqCst), 10);
    }
}

pub fn swap(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Xchg, value, ordering);
}

test "swap" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(swap(&x, 10, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 10);
    }
}

pub fn fetchAdd(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Add, value, ordering);
}

test "fetchAdd" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(fetchAdd(&x, 5, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 10);
    }
}

pub fn fetchSub(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
    return atomicRmw(@TypeOf(ptr.*), ptr, .Sub, value, ordering);
}

test "fetchSub" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 5;
        testing.expectEqual(fetchSub(&x, 5, ordering), 5);
        testing.expectEqual(load(&x, .SeqCst), 0);
    }
}

pub fn fetchAnd(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
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

pub fn fetchOr(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
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

pub fn fetchXor(ptr: anytype, value: @TypeOf(ptr.*), comptime ordering: Ordering) @TypeOf(ptr.*) {
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

inline fn atomicRmw(comptime T: type, ptr: *T, comptime op: AtomicRmwOp, value: T, comptime ordering: Ordering) T {
    return @atomicRmw(T, ptr, op, value, comptime ordering.toBuiltin());
}

pub fn compareAndSwap(
    ptr: anytype,
    cmp: @TypeOf(ptr.*),
    xchg: @TypeOf(ptr.*),
    comptime success: Ordering, 
    comptime failure: Ordering,
) ?@TypeOf(ptr.*) {
    return @cmpxchgStrong(@TypeOf(ptr.*), ptr, cmp, xchg, comptime success.toBuiltin(), comptime failure.toBuiltin());
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

pub fn tryCompareAndSwap(
    ptr: anytype,
    cmp: @TypeOf(ptr.*),
    xchg: @TypeOf(ptr.*),
    comptime success: Ordering,
    comptime failure: Ordering,
) ?@TypeOf(ptr.*) {
    return @cmpxchgWeak(@TypeOf(ptr.*), ptr, cmp, xchg, comptime success.toBuiltin(), comptime failure.toBuiltin());
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

pub fn bitGet(ptr: anytype, bit: Log2Int(@TypeOf(ptr.*)), comptime ordering: Ordering) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Get, bit, ordering);
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

pub fn bitSet(ptr: anytype, bit: Log2Int(@TypeOf(ptr.*)), comptime ordering: Ordering) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Set, bit, ordering);
}

test "bitSet" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(Log2Int(usize), bit_index);
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
                const prev_bit = @intCast(Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask != 0);
            }
        }
    }
}

pub fn bitUnset(ptr: anytype, bit: Log2Int(@TypeOf(ptr.*)), comptime ordering: Ordering) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Reset, bit, ordering);
}

test "bitUnset" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(Log2Int(usize), bit_index);
            const mask = @as(usize, 1) << bit;
            x |= mask;

            // unsetting the bit should change the bit
            testing.expect(load(&x, .SeqCst) & mask != 0);
            testing.expectEqual(bitUnset(&x, bit, ordering), 1);
            testing.expect(load(&x, .SeqCst) & mask == 0);

            // unsetting it again shouldn't change the value
            testing.expectEqual(bitUnset(&x, bit, ordering), 0);
            testing.expect(load(&x, .SeqCst) & mask == 0);

            // all the previous bits should have not changed (still be reset)
            for (bit_array[0..bit_index]) |_, prev_bit_index| {
                const prev_bit = @intCast(Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask == 0);
            }
        }
    }
}

pub fn bitToggle(ptr: anytype, bit: Log2Int(@TypeOf(ptr.*)), comptime ordering: Ordering) u1 {
    return atomicBitRmw(@TypeOf(ptr.*), ptr, .Toggle, bit, ordering);
}

test "bitToggle" {
    inline for (.{ .Relaxed, .Consume, .Acquire, .Release, .AcqRel, .SeqCst }) |ordering| {
        var x: usize = 0;
        const bit_array = @as([std.meta.bitCount(usize)]void, undefined);

        for (bit_array) |_, bit_index| {
            const bit = @intCast(Log2Int(usize), bit_index);
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
                const prev_bit = @intCast(Log2Int(usize), prev_bit_index);
                const prev_mask = @as(usize, 1) << prev_bit;
                testing.expect(load(&x, .SeqCst) & prev_mask == 0);
            }
        }
    }
}

fn atomicBitRmw(comptime T: type, ptr: *T, comptime op: AtomicBitOp, bit: Log2Int(T), comptime ordering: Ordering) u1 {
    const bytes = @sizeOf(T);
    const mask = @as(T, 1) << bit;
    const is_x86 = switch (builtin.arch) {
        .i386, .x86_64 => true,
        else => false,
    };

    if (is_x86 and (op != .Get) and (bytes <= @sizeOf(usize))) {
        const instruction: []const u8 = switch (op) {
            .Get => unreachable,
            .Set => "lock bts",
            .Reset => "lock btr",
            .Toggle => "lock btc",
        };

        const suffix: []const u8 = switch (bytes) {
            // On x86, address faults are by page. 
            // If at least one byte is valid, the memory operation will succeed.
            1, 2 => "w", 
            4 => "l",
            8 => "q",
            else => unreachable,
        };

        const Bit = std.meta.Int(
            .unsigned,
            std.math.max(2, bytes) * 8,
        );

        return @intCast(u1, asm volatile(
            instruction ++ suffix ++ " %[bit], %[ptr]"
            : [result] "={@ccc}" (-> u8)
            : [ptr] "*p" (ptr),
              [bit] "X" (@as(Bit, bit))
            : "cc", "memory"
        ));
    }

    const value = switch (op) {
        .Get => load(ptr, ordering),
        .Set => fetchOr(ptr, mask, ordering),
        .Reset => fetchAnd(ptr, ~mask, ordering),
        .Toggle => fetchXor(ptr, mask, ordering),
    };

    return @boolToInt(value & mask != 0);
}