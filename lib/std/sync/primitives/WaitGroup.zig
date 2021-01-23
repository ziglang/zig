// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub fn WaitGroup(comptime Futex: type) type {
    return extern struct {
        counter: u32 = 0,

        const Self = @This();

        pub const Dummy = DebugWaitGroup;

        pub fn init(amount: u32) Self {
            return .{ .counter = amount };
        }

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn begin(self: *Self, amount: u32) void {
            if (amount == 0) {
                return;
            }

            _ = atomic.fetchAdd(&self.counter, amount, .SeqCst);
        }

        pub fn tryBegin(self: *Self, amount: u32) bool {
            return self.apply(true, amount);
        }

        pub fn end(self: *Self, amount: u32) void {
            if (amount == 0) {
                return;
            }

            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            const counter = atomic.fetchSub(&self.counter, amount, .SeqCst);
            if (counter - amount == 0) {
                Futex.notifyAll(&self.counter);
            }
        }

        pub fn tryEnd(self: *Self, amount: u32) bool {
            return self.apply(false, amount);
        }

        pub fn add(self: *Self, amount: i32) void {
            if (amount == 0) {
                return;
            } else if (amount < 0) {
                self.end(@intCast(u32, -amount));
            } else {
                self.begin(@intCast(u32, amount));
            }
        }

        pub fn tryAdd(self: *Self, amount: i32) bool {
            const is_add = amount > 0;
            const value = @intCast(u32, if (is_add) amount else -amount);
            return self.apply(is_add, value);
        }

        pub fn done(self: *Self) void {
            self.end(1);
        }

        fn apply(self: *Self, is_add: bool, amount: u32) bool {
            if (amount == 0) {
                return true;
            }

            if (helgrind) |hg| {
                if (!is_add) {
                    hg.annotateHappensBefore(@ptrToInt(self));
                }
            }

            var new_counter: u32 = undefined;
            var counter = atomic.load(&self.counter, .SeqCst);
            while (true) {
                const overflowed = switch (is_add) {
                    true => @addWithOverflow(u32, counter, amount, &new_counter),
                    else => @subWithOverflow(u32, counter, amount, &new_counter),
                };

                if (overflowed) {
                    return false;
                }

                counter = atomic.tryCompareAndSwap(
                    &self.counter,
                    counter,
                    new_counter,
                    .SeqCst,
                    .SeqCst,
                ) orelse break;
            }

            if (!is_add and new_counter == 0) {
                Futex.notifyAll(&self.counter);
            }

            return true;
        }

        pub fn tryWait(self: *Self) bool {
            const would_block = atomic.load(&self.counter, .SeqCst) != 0;

            if (helgrind) |hg| {
                if (!would_block) {
                    hg.annotateHappensAfter(@ptrToInt(self));
                }
            }

            return !would_block;
        }

        pub fn wait(self: *Self) void {
            return self.waitInner(null) catch unreachable;
        }

        pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(Futex.now() + duration);
        }

        pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
            return self.waitInner(deadline);
        }

        fn waitInner(self: *Self, deadline: ?u64) error{TimedOut}!void { 
            while (true) {
                const counter = atomic.load(&self.counter, .SeqCst);
                if (counter == 0) {
                    break;
                }

                try Futex.wait(
                    &self.counter,
                    counter,
                    deadline,
                );
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }
        }
    };
}

pub const DebugWaitGroup = extern struct {
    counter: u32 = 0,

    const Self = @This();

    pub fn init(amount: u32) Self {
        return .{ .counter = amount };
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn begin(self: *Self, amount: u32) void {
        assert(self.tryBegin(amount));
    }

    pub fn tryBegin(self: *Self, amount: u32) bool {
        return self.apply(true, amount);
    }

    pub fn end(self: *Self, amount: u32) void {
        assert(self.tryEnd(amount));
    }

    pub fn tryEnd(self: *Self, amount: u32) bool {
        return self.apply(false, amount);
    }

    pub fn add(self: *Self, amount: i32) void {
        assert(self.tryAdd(amount));
    }

    pub fn tryAdd(self: *Self, amount: i32) bool {
        const is_add = amount > 0;
        const value = @intCast(u32, if (is_add) amount else -amount);
        return self.apply(is_add, value);
    }

    pub fn done(self: *Self) void {
        self.end(1);
    }

    fn apply(self: *Self, is_add: bool, amount: u32) bool {
        if (amount == 0) {
            return true;
        }

        var new_counter: u32 = undefined;
        const overflowed = switch (is_add) {
            true => @addWithOverflow(u32, self.counter, amount, &new_counter),
            else => @subWithOverflow(u32, self.counter, amount, &new_counter),
        };

        if (!overflowed) {
            self.counter = new_counter;
            return true;
        }

        return false;
    }

    pub fn tryWait(self: *Self) bool {
        return self.counter == 0;
    }

    pub fn wait(self: *Self) void {
        if (!self.tryWait()) {
            @panic("deadlock detected");
        }
    }

    pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        if (!self.tryWait()) {
            std.time.sleep(duration);
            return error.TimedOut;
        }
    }

    pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        if (!self.tryWait()) {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        }
    }
};

test "WaitGroup - Debug" {
    try testWaitGroup(DebugWaitGroup, null);
}

test "WaitGroup - OS" {
    try testWaitGroup(WaitGroup(std.sync.futex.os), std.Thread);
}

test "WaitGroup - Spin" {
    try testWaitGroup(WaitGroup(std.sync.futex.spin), std.Thread);
}

test "WaitGroup - Evented" {
    // TODO: std.event.Thread
    // try testWaitGroup(WaitGroup(std.sync.futex.event), null);
}

fn testWaitGroup(
    comptime TestWaitGroup: type,
    comptime TestThread: ?type,
) !void {
    {
        var wg = TestWaitGroup.init(0);

        wg.begin(1);
        wg.end(1);
        testing.expect(wg.tryWait());

        wg.add(1);
        wg.done();
        wg.wait();

        const max = std.math.maxInt(u32);
        wg.begin(1);
        testing.expect(!wg.tryBegin(max));
        testing.expect(!wg.tryEnd(2));

        wg.begin(max - 1);
        wg.end(max);
    }

    const Thread = TestThread orelse return;

    const TestUpdateCounter = struct {
        counter: usize = 0,
        counter_wg: TestWaitGroup = .{},
        complete_wg: TestWaitGroup = .{},

        const Self = @This();
        const num_threads = 10;
        const increments = 100;

        fn run(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*Thread, num_threads);
            defer allocator.free(threads);

            self.complete_wg.add(1);
            for (threads) |*t| {
                self.counter_wg.add(1);
                t.* = try Thread.spawn(self, runThread);
            }

            self.counter_wg.wait();
            testing.expectEqual(
                atomic.load(&self.counter, .Relaxed),
                num_threads * increments,
            );

            self.complete_wg.done();
            for (threads) |t| {
                t.wait();
            }

            self.counter_wg.deinit();
            self.complete_wg.deinit();
        }

        fn runThread(self: *Self) void {
            var incr: usize = increments;
            while (incr > 0) : (incr -= 1) {
                _ = atomic.fetchAdd(&self.counter, 1, .Relaxed);
            }

            self.counter_wg.done();
            self.counter_wg.wait();
        }
    };

    var tuc = TestUpdateCounter{};
    try tuc.run();
}