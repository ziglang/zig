// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const builtin = std.builtin;
const testing = std.testing;

/// Thread-safe, lock-free integer
pub fn Int(comptime T: type) type {
    if (!std.meta.trait.isIntegral(T))
        @compileError("Expected integral type, got '" ++ @typeName(T) ++ "'");

    return extern struct {
        unprotected_value: T,

        pub const Self = @This();

        pub fn init(init_val: T) Self {
            return Self{ .unprotected_value = init_val };
        }

        /// Read, Modify, Write
        pub fn rmw(self: *Self, comptime op: builtin.AtomicRmwOp, operand: T, comptime ordering: builtin.AtomicOrder) T {
            switch (ordering) {
                .Monotonic, .Acquire, .Release, .AcqRel, .SeqCst => {},
                else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a RMW operation"),
            }
            return @atomicRmw(T, &self.unprotected_value, op, operand, ordering);
        }

        pub fn load(self: *const Self, comptime ordering: builtin.AtomicOrder) T {
            switch (ordering) {
                .Unordered, .Monotonic, .Acquire, .SeqCst => {},
                else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a load operation"),
            }
            return @atomicLoad(T, &self.unprotected_value, ordering);
        }

        pub fn store(self: *Self, value: T, comptime ordering: builtin.AtomicOrder) void {
            switch (ordering) {
                .Unordered, .Monotonic, .Release, .SeqCst => {},
                else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a store operation"),
            }
            @atomicStore(T, &self.unprotected_value, value, ordering);
        }

        /// Twos complement wraparound increment
        /// Returns previous value
        pub fn incr(self: *Self) T {
            return self.rmw(.Add, 1, .SeqCst);
        }

        /// Twos complement wraparound decrement
        /// Returns previous value
        pub fn decr(self: *Self) T {
            return self.rmw(.Sub, 1, .SeqCst);
        }

        pub fn get(self: *const Self) T {
            return self.load(.SeqCst);
        }

        pub fn set(self: *Self, new_value: T) void {
            self.store(new_value, .SeqCst);
        }

        pub fn xchg(self: *Self, new_value: T) T {
            return self.rmw(.Xchg, new_value, .SeqCst);
        }

        /// Twos complement wraparound add
        /// Returns previous value
        pub fn fetchAdd(self: *Self, op: T) T {
            return self.rmw(.Add, op, .SeqCst);
        }
    };
}

test "std.atomic.Int" {
    var a = Int(u8).init(0);
    testing.expectEqual(@as(u8, 0), a.incr());
    testing.expectEqual(@as(u8, 1), a.load(.SeqCst));
    a.store(42, .SeqCst);
    testing.expectEqual(@as(u8, 42), a.decr());
    testing.expectEqual(@as(u8, 41), a.xchg(100));
    testing.expectEqual(@as(u8, 100), a.fetchAdd(5));
    testing.expectEqual(@as(u8, 105), a.get());
    a.set(200);
}
