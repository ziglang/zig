// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const assert = std.debug.assert;

/// Similar to std.ResetEvent but on `set()` it also (atomically) does `reset()`.
/// Unlike std.ResetEvent, `wait()` can only be called by one thread (MPSC-like).
pub const AutoResetEvent = struct {
    // AutoResetEvent has 3 possible states:
    // - UNSET: the AutoResetEvent is currently unset
    // - SET: the AutoResetEvent was notified before a wait() was called
    // - <std.ResetEvent pointer>: there is an active waiter waiting for a notification.
    //
    // When attempting to wait:
    //  if the event is unset, it registers a ResetEvent pointer to be notified when the event is set
    //  if the event is already set, then it consumes the notification and resets the event.
    //
    // When attempting to notify:
    //  if the event is unset, then we set the event
    //  if theres a waiting ResetEvent, then we unset the event and notify the ResetEvent
    //
    // This ensures that the event is automatically reset after a wait() has been issued
    // and avoids the race condition when using std.ResetEvent in the following scenario:
    //  thread 1                | thread 2
    //  std.ResetEvent.wait()   |
    //                          | std.ResetEvent.set()
    //                          | std.ResetEvent.set()
    //  std.ResetEvent.reset()  | 
    //  std.ResetEvent.wait()   | (missed the second .set() notification above)


    state: usize = UNSET,

    const UNSET = 0;
    const SET = 1;

    // the minimum alignment for the `*std.ResetEvent` created by wait*()
    const event_align = std.math.max(@alignOf(std.ResetEvent), 2);

    pub fn wait(self: *AutoResetEvent) void {
        self.waitInner(null) catch unreachable;
    }

    pub fn timedWait(self: *AutoResetEvent, timeout: u64) error{TimedOut}!void {
        return self.waitInner(timeout);
    }

    fn waitInner(self: *AutoResetEvent, timeout: ?u64) error{TimedOut}!void {
        // the local ResetEvent is lazily initialized
        var has_reset_event = false;
        var reset_event: std.ResetEvent align(event_align) = undefined;
        defer if (has_reset_event) {
            reset_event.deinit();
        };

        var state = @atomicLoad(usize, &self.state, .SeqCst);
        while (true) {
            switch (state) {
                UNSET => {
                    if (!has_reset_event) {
                        has_reset_event = true;
                        reset_event = std.ResetEvent.init();
                    }
                    state = @cmpxchgWeak(
                        usize,
                        &self.state,
                        state,
                        @ptrToInt(&reset_event),
                        .SeqCst,
                        .SeqCst,
                    ) orelse {
                        if (timeout) |timeout_ns| {
                            reset_event.timedWait(timeout_ns) catch {
                                state = @cmpxchgStrong(
                                    usize,
                                    &self.state,
                                    @ptrToInt(&reset_event),
                                    UNSET,
                                    .SeqCst,
                                    .SeqCst,
                                ) orelse return error.TimedOut;
                                assert(state == SET);
                                reset_event.wait();
                            };
                        } else {
                            reset_event.wait();
                        }
                        return;
                    };
                },
                SET => {
                    @atomicStore(usize, &self.state, UNSET, .SeqCst);
                    return;
                },
                else => {
                    unreachable; // multiple waiters on the same Event
                }
            }
        }
    }

    pub fn set(self: *AutoResetEvent) void {
        var state = @atomicLoad(usize, &self.state, .SeqCst);
        while (true) {
            switch (state) {
                UNSET => {
                    state = @cmpxchgWeak(
                        usize,
                        &self.state,
                        state,
                        SET,
                        .SeqCst,
                        .SeqCst,
                    ) orelse return;
                },
                SET => {
                    return;
                },
                else => |reset_event_ptr| {
                    state = @cmpxchgWeak(
                        usize,
                        &self.state,
                        state,
                        UNSET,
                        .SeqCst,
                        .SeqCst,
                    ) orelse {
                        const reset_event = @intToPtr(*align(event_align) std.ResetEvent, reset_event_ptr);
                        reset_event.set();
                        return;
                    };
                }
            }
        }
    }
};

test "std.AutoResetEvent" {
    // test local code paths
    {
        var event = AutoResetEvent{};
        testing.expectError(error.TimedOut, event.timedWait(1));
        event.set();
        event.wait();
    }

    // test cross-thread signaling
    if (builtin.single_threaded)
        return;

    const Context = struct {
        value: u128 = 0,
        in: AutoResetEvent = AutoResetEvent{},
        out: AutoResetEvent = AutoResetEvent{},

        const Self = @This();

        fn sender(self: *Self) void {
            std.debug.print("\n", .{});
            testing.expect(self.value == 0);
            self.value = 1;
            self.out.set();

            self.in.wait();
            testing.expect(self.value == 2);
            self.value = 3;
            self.out.set();

            self.in.wait();
            testing.expect(self.value == 4);
        }

        fn receiver(self: *Self) void {
            self.out.wait();
            testing.expect(self.value == 1);
            self.value = 2;
            self.in.set();

            self.out.wait();
            testing.expect(self.value == 3);
            self.value = 4;
            self.in.set();
        }
    };

    var context = Context{};
    const send_thread = try std.Thread.spawn(&context, Context.sender);
    const recv_thread = try std.Thread.spawn(&context, Context.receiver);

    send_thread.wait();
    recv_thread.wait();
}