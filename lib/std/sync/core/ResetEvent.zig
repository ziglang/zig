// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

pub fn ResetEvent(comptime parking_lot: type) type {
    return extern struct {
        is_set: bool = false,

        const Self = @This();

        pub fn isSet(self: *const Self) bool {
            return atomic.load(&self.is_set, .SeqCst);
        }

        pub fn reset(self: *Self) void {
            atomic.store(&self.is_set, false, .SeqCst);
        }

        pub fn wait(self: *Self) void {
            self.waitInner(null) catch unreachable;
        }

        pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(parking_lot.nanotime() + duration);
        }

        pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
            return self.waitInner(deadline);
        }

        fn waitInner(self: *Self, deadline: ?u64) error{TimedOut}!void {
            const Parker = struct {
                event: *Self,

                pub fn onValidate(this: @This()) ?usize {
                    if (this.event.isSet())
                        return null;
                    return 0;
                }

                pub fn onBeforeWait(this: @This()) void {}
                pub fn onTimeout(this: @This(), has_more: bool) void {}
            };

            while (true) {
                if (self.isSet())
                    return;

                _ = parking_lot.parkConditionally(
                    @ptrToInt(self),
                    deadline,
                    Parker{ .event = self },
                ) catch |err| switch (err) {
                    error.Invalid => {},
                    error.TimedOut => return error.TimedOut,
                };
            }
        }

        pub fn set(self: *Self) void {
            atomic.store(&self.is_set, true, .SeqCst);

            parking_lot.unparkAll(@ptrToInt(self));
        }
    };
}

pub const DebugResetEvent = extern struct {
    is_set: bool = false,

    const Self = @This();

    pub fn isSet(self: *const Self) bool {
        return self.is_set;
    }

    pub fn reset(self: *Self) void {
        self.is_set = false;
    }

    pub fn wait(self: *Self) void {
        if (!self.is_set)
            @panic("deadlock detected");
    }

    pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        return self.wait();
    }

    pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        return self.wait();
    }

    pub fn set(self: *Self) void {
        self.is_set = true;
    }
};