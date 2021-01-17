// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const assert = std.debug.assert;

pub fn WaitGroup(comptime parking_lot: type) type {
    return extern struct {
        counter: usize = 0,

        const Self = @This();

        pub fn init(amount: usize) Self {
            return .{ .counter = amount };
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
            const max = std.math.maxInt(usize);
            if (amount == 0)
                return true;
            
            var counter = atomic.load(&self.counter, .SeqCst);
            while (true) {
                var new_counter: usize = undefined;
                if (is_add) {
                    if (counter > max - amount)
                        return false;
                    new_counter = counter + amount;
                } else {
                    if (amount > counter)
                        return false;
                    new_counter = counter - amount;
                }

                counter = atomic.tryCompareAndSwap(
                    &self.counter,
                    counter,
                    new_counter,
                    .SeqCst,
                    .SeqCst,
                ) orelse {
                    if (new_counter == 0)
                        parking_lot.unparkAll(@ptrToInt(self));
                    return true;
                };
            }
        }

        pub fn tryWait(self: *Self) bool {
            return atomic.load(&self.counter, .relaxed);
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
                timed_out: bool = false,

                pub fn onValidate(this: @This()) ?usize {
                    if (atomic.load(&this.wg.counter, .SeqCst) == 0)
                        return null;
                    return 0;
                }

                pub fn onBeforeWait(this: @This()) void {}
                pub fn onTimeout(this: *@This(), has_more: bool) void {
                    this.timed_out = true;
                }
            };

            while (true) {
                if (atomic.load(&self.counter, .SeqCst) == 0)
                    return;
                
                var parker = Parker{ .wg = self };
                _ = parking_lot.parkConditionally(@ptrToInt(self), deadline, &parker);

                if (parker.timed_out)
                    return error.TimedOut;
            }
        }
    };
}