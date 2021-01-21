// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const assert = std.debug.assert;
const testing = std.testing;

const helgrind = std.valgrind.helgrind;
const use_valgrind = std.builtin.valgrind_support;

pub fn WaitGroup(comptime parking_lot: type) type {
    return extern struct {
        counter: usize = 0,

        const Self = @This();

        pub fn init(amount: usize) Self {
            return .{ .counter = amount };
        }

        pub fn deinit(self: *Self) void {
            if (use_valgrind) {
                helgrind.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

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
            var counter = atomic.load(&self.counter, .SeqCst);

            while (true) {
                if (switch (is_add) {
                    true => @addWithOverflow(usize, counter, amount, &new_counter),
                    else => @subWithOverflow(usize, counter, amount, &new_counter),
                }) {
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

            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            if (new_counter == 0) {
                parking_lot.unparkAll(@ptrToInt(self));
            }

            return true;
        }

        pub fn tryWait(self: *Self) bool {
            const is_done = atomic.load(&self.counter, .SeqCst) == 0;

            if (use_valgrind and is_done) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }

            return is_done;
        }

        pub fn wait(self: *Self) void {
            return self.waitInner(null) catch unreachable;
        }

        pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(parking_lot.nanotime() + duration);
        }

        pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
            return self.waitInner(deadline);
        }

        fn waitInner(self: *Self, deadline: ?u64) error{TimedOut}!void {
            const Parker = struct {
                wg: *Self,

                pub fn onValidate(this: @This()) ?usize {
                    if (atomic.load(&this.wg.counter, .SeqCst) == 0)
                        return null;
                    return 0;
                }

                pub fn onBeforeWait(this: @This()) void {}
                pub fn onTimeout(this: @This(), has_more: bool) void {}
            };

            while (true) {
                if (self.tryWait()) {
                    break;
                }
                
                _ = parking_lot.parkConditionally(
                    @ptrToInt(self),
                    deadline,
                    Parker{ .wg = self },
                ) catch |err| switch (err) {
                    error.Invalid => {},
                    error.TimedOut => return error.TimedOut,
                };
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
        const value = @intCast(usize, if (add) amount else -amount);
        return self.apply(is_add, value);
    }

    pub fn done(self: *Self) void {
        self.end(1);
    }

    fn apply(self: *Self, is_add: bool, amount: usize) bool {
        if (amount == 0) {
            return true;
        }

        const overflowed = switch (is_add) {
            true => @addWithOverflow(usize, counter, amount, &new_counter),
            else => @subWithOverflow(usize, counter, amount, &new_counter),
        };

        return !overflowed;
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

test "WaitGroup" {
    const TestWaitGroup = std.sync.WaitGroup;

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

    if (std.io.is_async) return;
    if (std.builtin.single_threaded) return;

    const TestUpdateCounter = struct {
        counter: usize = 0,
        counter_wg: TestWaitGroup = .{},
        complete_wg: TestWaitGroup = .{},

        const Self = @This();
        const num_threads = 10;
        const increments = 100;

        fn run(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*std.Thread, num_threads);
            defer allocator.free(threads);

            self.complete_wg.add(1);
            for (threads) |*t| {
                self.counter_wg.add(1);
                t.* = try std.Thread.spawn(self, runThread);
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