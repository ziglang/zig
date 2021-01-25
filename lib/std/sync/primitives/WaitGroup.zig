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
        counter: usize = 0,
        state: State = .empty,

        const Self = @This();
        const State = extern enum(u32) {
            empty,
            waiting,
        };

        pub const Dummy = DebugWaitGroup;

        pub fn init(amount: usize) Self {
            return .{ .counter = amount };
        }

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn begin(self: *Self, amount: usize) void {
            if (amount == 0) {
                return;
            }

            _ = atomic.fetchAdd(&self.counter, amount, .Relaxed);
        }

        pub fn tryBegin(self: *Self, amount: usize) bool {
            return self.apply(true, amount);
        }

        pub inline fn done(self: *Self) void {
            self.end(1);
        }

        pub fn end(self: *Self, amount: usize) void {
            if (amount == 0) {
                return;
            }

            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            const counter = atomic.fetchSub(&self.counter, amount, .Release);
            assert(counter >= amount);

            if (counter - amount == 0) {
                self.notify();
            }
        }

        pub inline fn tryEnd(self: *Self, amount: usize) bool {
            return self.apply(false, amount);
        }

        pub fn add(self: *Self, amount: isize) void {
            if (amount == 0) {
                return;
            } else if (amount < 0) {
                self.end(@intCast(usize, -amount));
            } else {
                self.begin(@intCast(usize, amount));
            }
        }

        pub fn tryAdd(self: *Self, amount: isize) bool {
            const is_add = amount > 0;
            const value = @intCast(usize, if (is_add) amount else -amount);
            return self.apply(is_add, value);
        }

        fn apply(self: *Self, is_add: bool, amount: usize) bool {
            if (amount == 0) {
                return true;
            }

            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            var new_counter: usize = undefined;
            var counter = atomic.load(&self.counter, .Relaxed);
            while (true) {
                const overflowed = switch (is_add) {
                    true => @addWithOverflow(usize, counter, amount, &new_counter),
                    else => @subWithOverflow(usize, counter, amount, &new_counter),
                };

                if (overflowed) {
                    return false;
                }

                counter = atomic.tryCompareAndSwap(
                    &self.counter,
                    counter,
                    new_counter,
                    .Release,
                    .Relaxed,
                ) orelse break;
            }

            if (!is_add and new_counter == 0) {
                self.notify();
            }

            return true;
        }

        pub fn tryWait(self: *Self) bool {
            const counter = atomic.load(&self.counter, .Acquire);
            if (counter != 0) {
                return false;
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return true;
        }

        pub inline fn wait(self: *Self) void {
            return self.waitInner(null) catch unreachable;
        }

        pub inline fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(Futex.now() + duration);
        }

        pub inline fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
            return self.waitInner(deadline);
        }

        fn waitInner(self: *Self, deadline: ?u64) error{TimedOut}!void {
            while (true) {
                if (self.tryWait()) {
                    return;
                }

                var state = atomic.load(&self.state, .Relaxed);
                if (state != .waiting) {
                    if (atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        .waiting,
                        .Relaxed,
                        .Relaxed,
                    )) |failed| {
                        atomic.spinLoopHint();
                        continue;
                    }

                    if (self.tryWait()) {
                        return;
                    }
                }

                try Futex.wait(
                    @ptrCast(*const u32, &self.state),
                    @enumToInt(State.waiting),
                    deadline,
                );
            }
        }

        fn notify(self: *Self) void {
            @setCold(true);

            const state = atomic.swap(&self.state, .empty, .Relaxed);
            if (state == .waiting) {
                Futex.wake(
                    @ptrCast(*const u32, &self.state),
                    std.math.maxInt(u32),
                );
            }
        }
    };
}

pub const DebugWaitGroup = extern struct {
    counter: usize = 0,

    const Self = @This();

    pub fn init(amount: usize) Self {
        return .{ .counter = amount };
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn begin(self: *Self, amount: usize) void {
        assert(self.tryBegin(amount));
    }

    pub fn tryBegin(self: *Self, amount: usize) bool {
        return self.apply(true, amount);
    }

    pub fn end(self: *Self, amount: usize) void {
        assert(self.tryEnd(amount));
    }

    pub fn tryEnd(self: *Self, amount: usize) bool {
        return self.apply(false, amount);
    }

    pub fn add(self: *Self, amount: isize) void {
        assert(self.tryAdd(amount));
    }

    pub fn tryAdd(self: *Self, amount: isize) bool {
        const is_add = amount > 0;
        const value = @intCast(usize, if (is_add) amount else -amount);
        return self.apply(is_add, value);
    }

    pub fn done(self: *Self) void {
        self.end(1);
    }

    fn apply(self: *Self, is_add: bool, amount: usize) bool {
        if (amount == 0) {
            return true;
        }

        var new_counter: usize = undefined;
        const overflowed = switch (is_add) {
            true => @addWithOverflow(usize, self.counter, amount, &new_counter),
            else => @subWithOverflow(usize, self.counter, amount, &new_counter),
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

test "WaitGroup - Os" {
    try testWaitGroup(WaitGroup(std.sync.futex.os), std.Thread);
}

test "WaitGroup - Spin" {
    try testWaitGroup(WaitGroup(std.sync.futex.spin), std.Thread);
}

test "WaitGroup - Evented" {
    if (!std.io.is_async or std.builtin.single_threaded) return error.SkipZigTest;
    try testWaitGroup(
        WaitGroup(std.sync.futex.event),
        @import("../futex/event.zig").TestThread,
    );
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

        const max = std.math.maxInt(usize);
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
