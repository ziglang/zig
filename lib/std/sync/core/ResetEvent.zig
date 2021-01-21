// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const testing = std.testing;

const helgrind = std.valgrind.helgrind;
const use_valgrind = std.builtin.valgrind_support;

pub fn ResetEvent(comptime parking_lot: type) type {
    return extern struct {
        is_set: bool = false,

        const Self = @This();

        pub fn init(is_set: bool) Self {
            return .{ .is_set = is_set };
        }

        pub fn deinit(self: *Self) void {
            if (use_valgrind) {
                helgrind.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn isSet(self: *const Self) bool {
            const is_set = atomic.load(&self.is_set, .SeqCst);

            if (use_valgrind and is_set) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }

            return is_set;
        }

        pub fn reset(self: *Self) void {
            atomic.store(&self.is_set, false, .SeqCst);
        }

        pub fn tryWait(self: *Self) void {
            return self.isSet();
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
                    break;

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
            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            atomic.store(&self.is_set, true, .SeqCst);

            parking_lot.unparkAll(@ptrToInt(self));
        }
    };
}

pub const DebugResetEvent = extern struct {
    is_set: bool = false,

    const Self = @This();

    pub fn init(is_set: bool) Self {
        return .{ .is_set = is_set };
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn isSet(self: *const Self) bool {
        return self.is_set;
    }

    pub fn reset(self: *Self) void {
        self.is_set = false;
    }

    pub fn wait(self: *Self) void {
        if (!self.is_set) {
            @panic("deadlock detected");
        }
    }

    pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        if (!self.is_set) {
            std.time.sleep(duration);
            return error.TimedOut;
        }
    }

    pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        if (!self.is_set) {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        }
    }

    pub fn set(self: *Self) void {
        self.is_set = true;
    }
};

test "ResetEvent" {
    const TestRestEvent = std.sync.ResetEvent;

    {
        var event = TestRestEvent{};
        defer event.deinit();
        testing.expect(!event.isSet());

        const delay = 1 * std.time.ns_per_ms;
        testing.expectError(error.TimedOut, event.tryWaitFor(delay));
        testing.expectError(error.TimedOut, event.tryWaitUntil(std.time.now() + delay));

        event.set();
        testing.expect(event.isSet());
        
        event.wait();
        try event.tryWaitFor(delay);
        try event.tryWaitUntil(std.time.now() + delay);

        event.reset();
        testing.expect(!event.isSet());
        testing.expectError(error.TimedOut, event.tryWaitFor(delay));
        testing.expectError(error.TimedOut, event.tryWaitUntil(std.time.now() + delay));
    }

    if (std.io.is_async) return;
    if (std.builtin.single_threaded) return;

    const PingPong = struct {
        value: usize = 0,
        ping_event: TestRestEvent = .{},
        pong_event: TestRestEvent = .{},

        const Self = @This();
        const round_trips = 3;

        fn run(self: *Self) !void {
            const pong = try std.Thread.spawn(self, runPong);
            self.runPing();
            pong.wait();

            self.ping_event.deinit();
            self.pong_event.deinit();
        }

        fn runPing(self: *Self) void {
            var value = atomic.load(&self.value, .SeqCst);
            testing.expectEqual(value, 0);

            var rt: usize = round_trips;
            while (rt > 0) : (rt -= 1) {
                value += 1;
                atomic.store(&self.value, value, .SeqCst);
                self.ping_event.set();

                self.pong_event.wait();
                self.pong_event.reset();
                const new_value = atomic.load(&self.value, .SeqCst);

                testing.expectEqual(new_value, value + 1);
                value = new_value;
            }
        }

        fn runPong(self: *Self) void {
            var value: usize = 0;
            testing.expectEqual(value, 0);

            var rt: usize = round_trips;
            while (rt > 0) : (rt -= 1) {
                self.ping_event.wait();
                self.ping_event.reset();
                const new_value = atomic.load(&self.value, .SeqCst);

                testing.expectEqual(new_value, value + 1);
                value = new_value;

                value += 1;
                atomic.store(&self.value, value, .SeqCst);
                self.pong_event.set();
            }
        }
    };

    var ping_pong = PingPong{};
    try ping_pong.run();
}