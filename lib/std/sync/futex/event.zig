// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const generic = @import("./generic.zig");

const assert = std.debug.assert;
const builtin = std.builtin;
const Loop = std.event.Loop;
const global_event_loop = Loop.instance orelse @compileError("std.event.Loop is not enabled");

pub usingnamespace EventFutex;

const EventFutex = generic.Futex(Event);
const Event = struct {
    mutex: std.Thread.Mutex,
    state: State,

    pub const Lock = std.Thread.Mutex;
    pub const bucket_count = 256;

    const Self = @This();
    const State = union(enum) {
        unset,
        wait: *Loop.NextTickNode,
        timed_wait: *Waiter,
        set,
    };

    const Waiter = struct {
        node: Loop.NextTickNode,
        delay: Loop.Delay,
        timed_out: bool,
    };

    pub fn init(self: *Self) void {
        self.* = .{
            .mutex = .{},
            .state = .unset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn now() u64 {
        return Loop.Delay.now();
    }

    pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
        const held = self.mutex.acquire();

        // Begin waiting on the event.
        // No other waiters can be waiting on the event since its SPSC.
        // It however can already be set if the set() thread grabs the mutex first.
        switch (self.state) {
            .unset => {},
            .wait => unreachable,
            .timed_wait => unreachable,
            .set => {
                held.release();
                return;
            },
        }

        const TimedWait = struct {
            fn run(event: *Self, waiter: *Waiter, deadline_ns: u64) void {
                // Schedule this async frame after the deadline using the Delay.
                // The set() thread can cancel() the delay if its still waiting.
                global_event_loop.beginOneEvent();
                suspend {
                    waiter.delay.schedule(@frame(), deadline_ns);
                }
                global_event_loop.finishOneEvent();

                // If we're rescheduled, it means the timer was not cancelled
                // and that it has expired normally.
                {
                    const event_held = event.mutex.acquire();
                    defer event_held.release();

                    switch (event.state) {
                        .unset => unreachable,
                        .wait => unreachable,
                        // If we're still waiting, unset the state to indicate we stopped.
                        // Stopping a wait implies we timed out.
                        .timed_wait => |timed_waiter| {
                            assert(timed_waiter == waiter);
                            waiter.timed_out = true;
                            event.state = .unset;
                        },
                        // If the timer elapsed but the state is already set,
                        // it means the set() thread beat us to the state
                        // but ignored it since it already saw that we were timing out.
                        .set => {
                            // Since the set() thread technically beat us,
                            // we won't count it as the Event timing out (timed_out = false).
                            assert(!waiter.timed_out);
                        },
                    }
                }

                // Wake up the wait() thread for it to see the .timed_out value we set.
                // Do this in a suspend block to avoid having the wait() thread await us.
                suspend {
                    global_event_loop.onNextTick(&waiter.node);
                }
            }
        };

        var waiter = Waiter{
            .node = .{ .data = @frame() },
            .delay = undefined,
            .timed_out = false,
        };

        // Update the state to indicate that theres a waiter.
        // If theres a deadline, start an asynchronous timer as well.
        var timeout_frame: @Frame(TimedWait.run) = undefined;
        if (deadline) |deadline_ns| {
            self.state = .{ .timed_wait = &waiter };
            timeout_frame = async TimedWait.run(self, &waiter, deadline_ns);
        } else {
            self.state = .{ .wait = &waiter.node };
        }

        // Release the mutex and start sleeping.
        // Must be done inside suspend block or there can be a race where
        // the set() thread wakes it but before it hits suspend; and it deadlocks.
        global_event_loop.beginOneEvent();
        suspend {
            held.release();
        }
        global_event_loop.finishOneEvent();

        // We are rescheduled in one of threee ways:
        // - a set() thread saw .wait and scheduled us
        // - a set() thread saw .timed_wait, cancelled the timer frame, and scheduled us.
        // - the timer frame expired and scheduled us (it suspended, no need to await it).
        if (waiter.timed_out) {
            return error.TimedOut;
        }
    }

    pub fn set(self: *Self) void {
        const maybe_node = blk: {
            const held = self.mutex.acquire();
            defer held.release();

            // Mark the event as set
            const state = self.state;
            self.state = .set;

            // Then try to wake up a waiter if there was any.
            // If we manage to cancel a timed_wait, then we need to schedule the waiter.
            // If not, the timed_wait is already scheduled and will wake up the waiter instead.
            break :blk switch (state) {
                .unset => null,
                .wait => |node| node,
                .timed_wait => |waiter| {
                    if (waiter.delay.cancel()) {
                        global_event_loop.finishOneEvent();
                        break :blk &waiter.node;
                    } else {
                        break :blk null;
                    }
                },
                .set => unreachable,
            };
        };

        if (maybe_node) |node| {
            global_event_loop.onNextTick(node);
        }
    }

    pub fn reset(self: *Self) void {
        self.state = .unset;
    }
};

/// A mimic of std.Thread for testing, but backed with std.event.Loop
pub const TestThread = struct {
    event: Event,
    allocator: *std.mem.Allocator,

    pub usingnamespace std.sync.primitives.with(EventFutex);

    const Self = @This();

    pub fn spawn(context: anytype, comptime entryFn: anytype) !*Self {
        // TODO: using std.testing.allocator reports a racy leak
        const allocator = std.heap.page_allocator;

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.event.init();
        errdefer self.event.deinit();

        const Context = @TypeOf(context);
        const Wrapper = struct {
            fn entry(ctx: Context, thread: *Self) void {
                const result = entryFn(ctx);
                thread.event.set();
            }
        };

        try global_event_loop.runDetached(allocator, Wrapper.entry, .{ context, self });
        return self;
    }

    pub fn wait(self: *Self) void {
        self.event.wait(null) catch unreachable;
        self.event.deinit();
        self.allocator.destroy(self);
    }
};
