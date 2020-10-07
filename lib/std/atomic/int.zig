// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const builtin = @import("std").builtin;

/// Thread-safe, lock-free integer
pub fn Int(comptime T: type) type {
    return struct {
        unprotected_value: T,

        pub const Self = @This();

        pub fn init(init_val: T) Self {
            return Self{ .unprotected_value = init_val };
        }

        /// Read, Modify, Write
        pub fn rmw(self: *Self, comptime op: builtin.AtomicRmwOp, operand: T, comptime ordering: builtin.AtomicOrder) T {
            return @atomicRmw(T, &self.unprotected_value, operand, ordering);
        }

        pub fn load(self: *Self, comptime ordering: builtin.AtomicOrder) T {
            return @atomicLoad(T, &self.unprotected_value, ordering);
        }

        pub fn store(self: *Self, value: T, comptime ordering: builtin.AtomicOrder) void {
            @atomicStore(T, &self.unprotected_value, value, ordering);
        }

        /// Returns previous value
        pub fn incr(self: *Self) T {
            return self.rmw(.Add, 1, .SeqCst);
        }

        /// Returns previous value
        pub fn decr(self: *Self) T {
            return self.rmw(.Sub, 1, .SeqCst);
        }

        pub fn get(self: *Self) T {
            return self.load(.SeqCst);
        }

        pub fn set(self: *Self, new_value: T) void {
            self.store(new_value, .SeqCst);
        }

        pub fn xchg(self: *Self, new_value: T) T {
            return self.rmw(.Xchg, new_value, .SeqCst);
        }

        pub fn fetchAdd(self: *Self, op: T) T {
            return self.rmw(.Add, op, .SeqCst);
        }
    };
}
