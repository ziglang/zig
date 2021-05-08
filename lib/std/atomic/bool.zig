// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const builtin = std.builtin;
const testing = std.testing;

/// Thread-safe, lock-free boolean
pub const Bool = extern struct {
    unprotected_value: bool,

    pub const Self = @This();

    pub fn init(init_val: bool) Self {
        return Self{ .unprotected_value = init_val };
    }

    // xchg is only valid rmw operation for a bool
    /// Atomically modifies memory and then returns the previous value.
    pub fn xchg(self: *Self, operand: bool, comptime ordering: std.builtin.AtomicOrder) bool {
        switch (ordering) {
            .Monotonic, .Acquire, .Release, .AcqRel, .SeqCst => {},
            else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a RMW operation"),
        }
        return @atomicRmw(bool, &self.unprotected_value, .Xchg, operand, ordering);
    }

    pub fn load(self: *const Self, comptime ordering: std.builtin.AtomicOrder) bool {
        switch (ordering) {
            .Unordered, .Monotonic, .Acquire, .SeqCst => {},
            else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a load operation"),
        }
        return @atomicLoad(bool, &self.unprotected_value, ordering);
    }

    pub fn store(self: *Self, value: bool, comptime ordering: std.builtin.AtomicOrder) void {
        switch (ordering) {
            .Unordered, .Monotonic, .Release, .SeqCst => {},
            else => @compileError("Invalid ordering '" ++ @tagName(ordering) ++ "' for a store operation"),
        }
        @atomicStore(bool, &self.unprotected_value, value, ordering);
    }
};

test "std.atomic.Bool" {
    var a = Bool.init(false);
    try testing.expectEqual(false, a.xchg(false, .SeqCst));
    try testing.expectEqual(false, a.load(.SeqCst));
    a.store(true, .SeqCst);
    try testing.expectEqual(true, a.xchg(false, .SeqCst));
    try testing.expectEqual(false, a.load(.SeqCst));
}
