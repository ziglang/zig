// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const helgrind = std.valgrind.helgrind;
const use_valgrind = std.builtin.valgrind_support;

pub fn Condvar(comptime parking_lot: type) type {
    return extern struct {
        has_waiters: bool = false,

        const Self = @This();

        pub fn wait(self: *Self, held: anytype) void {
            return self.waitInner(held, null) catch unreachable;
        }

        pub fn tryWaitFor(self: *Self, held: anytype, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(held, parking_lot.nanotime() + duration);
        }

        pub fn tryWaitUntil(self: *Self, held: anytype, deadline: u64) error{TimedOut}!void {
            return self.waitInner(held, deadline);
        }

        fn waitInner(self: *Self, held: anytype, deadline: ?u64) error{TimedOut}!void {
            const Held = @TypeOf(held);
            const Parker = struct {
                cond: *Self,
                held_ref: Held,
                timed_out: bool = false,

                pub fn onValidate(this: @This()) ?usize {
                    atomic.store(&this.cond.has_waiters, true, .SeqCst);
                    return 0;
                }

                pub fn onBeforeWait(this: @This()) void {
                    this.held_ref.release();
                }

                pub fn onTimeout(this: *@This(), has_more: bool) void {
                    this.timed_out = true;
                }
            };

            var parker = Parker{
                .cond = self,
                .held_ref = held,
            };

            _ = parking_lot.parkConditionally(@ptrToInt(self), deadline, &parker);
            
            _ = held.mutex.acquire();

            if (use_valgrind) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }

            if (parker.timed_out) {
                return error.TimedOut;
            }
        }

        pub fn notifyOne(self: *Self) void {
            if (!atomic.load(&self.has_waiters, .SeqCst)) {
                return;
            }

            const Unparker = struct {
                cond: *Self,

                pub fn onUnpark(this: @This(), result: parking_lot.UnparkResult) usize {
                    atomic.store(&this.cond.has_waiters, result.has_more, .SeqCst);
                    return 0;
                }
            };

            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            parking_lot.unparkOne(
                @ptrToInt(self),
                Unparker{ .cond = self },
            );
        }

        pub fn notifyAll(self: *Self) void {
            if (!atomic.load(&self.has_waiters, .SeqCst)) {
                return;
            }

            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            atomic.store(&self.has_waiters, false, .SeqCst);

            parking_lot.unparkAll(@ptrToInt(self));
        }
    };
}

pub const DebugCondvar = extern struct {
    const Self = @This();

    pub fn wait(self: *Self, held: anytype) void {
       @panic("deadlock detected"); // there would be no thread to wake us up
    }

    pub fn tryWaitFor(self: *Self, held: anytype, duration: u64) error{TimedOut}!void {
        return self.wait();
    }

    pub fn tryWaitUntil(self: *Self, held: anytype, deadline: u64) error{TimedOut}!void {
        return self.wait();
    }

    pub fn notifyOne(self: *Self) void {
        return self.notifyAll();
    }

    pub fn notifyAll(self: *Self) void {
        // no-op since there cant be any other thread to notify
    }
};