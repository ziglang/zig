// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
/// Thread-safe, lock-free integer
pub fn Int(comptime T: type) type {
    return struct {
        unprotected_value: T,

        pub const Self = @This();

        pub fn init(init_val: T) Self {
            return Self{ .unprotected_value = init_val };
        }

        /// Returns previous value
        pub fn incr(self: *Self) T {
            return @atomicRmw(T, &self.unprotected_value, .Add, 1, .SeqCst);
        }

        /// Returns previous value
        pub fn decr(self: *Self) T {
            return @atomicRmw(T, &self.unprotected_value, .Sub, 1, .SeqCst);
        }

        pub fn get(self: *Self) T {
            return @atomicLoad(T, &self.unprotected_value, .SeqCst);
        }

        pub fn set(self: *Self, new_value: T) void {
            _ = self.xchg(new_value);
        }

        pub fn xchg(self: *Self, new_value: T) T {
            return @atomicRmw(T, &self.unprotected_value, .Xchg, new_value, .SeqCst);
        }

        pub fn fetchAdd(self: *Self, op: T) T {
            return @atomicRmw(T, &self.unprotected_value, .Add, op, .SeqCst);
        }
    };
}
