// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const generic = @import("./generic.zig");

const Loop = std.event.Loop;
const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;
const global_event_loop = Loop.instance orelse @compileError("std.event.Loop is not enabled");

pub usingnamespace EventFutex;

const EventFutex = generic.Futex(Event);
const Event = struct {
    mutex: std.Thread.Mutex,
    state: State,

    const Self = @This();
    const State = union(enum){
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

    fn waitTimeout(self: *Self, waiter: *Waiter, deadline: u64) void {
        suspend {
            waiter.delay.schedule(@frame(), deadline);
        }

        {
            const held = self.mutex.acquire();
            defer held.release();

            switch (self.state) {
                .unset => unreachable,
                .wait => unreachable,
                .timed_wait => {
                    self.state = .unset;
                    waiter.timed_out = true;
                },
                .set => {},
            }
        }

        if (waiter.timed_out) {
            global_event_loop.onNextTick(&waiter.node);
        }
    }

    pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
        const held = self.mutex.acquire();

        switch (self.state) {
            .unset => {},
            .wait => unreachable,
            .timed_wait => unreachable,
            .set => {
                held.release();
                return;
            },
        }

        var waiter = Waiter{
            .node = .{ .data = @frame() },
            .delay = undefined,
            .timed_out = false,
        };

        var timeout_frame: @Frame(waitTimeout) = undefined;
        if (deadline) |deadline_ns| {
            self.state = .{ .timed_wait = &waiter };
            timeout_frame = async self.waitTimeout(&waiter, deadline_ns);
        } else {
            self.state = .{ .wait = &waiter.node };
        }

        suspend {
            held.release();
        }

        if (deadline != null) {
            await timeout_frame;
            if (waiter.timed_out) {
                return error.TimedOut;
            }
        }
    }

    pub fn set(self: *Self) void {
        const maybe_node = blk :{
            const held = self.mutex.acquire();
            defer held.release();

            const state = self.state;
            self.state = .set;

            break :blk switch (state) {
                .unset => null,
                .wait => |node| node,
                .timed_wait => |waiter| if (waiter.delay.cancel()) &waiter.node else null,
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

pub const TestThread = struct {
    event: Event,
    freeFn: fn(*TestThread) void,

    const Self = @This();

    pub usingnamespace std.sync.primitives.with(EventFutex);

    pub fn spawn(context: anytype, comptime entryFn: anytype) !*Self {
        const allocator = std.testing.allocator;
        
        const Context = @TypeOf(context);
        const FrameThread = struct {
            thread: TestThread,
            entry_frame: @Frame(entry),

            fn entry(thread: *TestThread, ctx: Context) void {
                defer thread.event.set();

                global_event_loop.beginOneEvent();
                defer global_event_loop.finishOneEvent();
                
                global_event_loop.yield();
                const result = entryFn(ctx);
            }

            fn free(thread: *TestThread) void {
                const self = @fieldParentPtr(@This(), "thread", thread);
                allocator.destroy(self);
            }
        };

        const frame_thread = try allocator.create(FrameThread);
        const thread = &frame_thread.thread;
        const frame = &frame_thread.entry_frame;

        thread.event.init();
        thread.freeFn = FrameThread.free;
        frame.* = async FrameThread.entry(thread, context);

        return thread;
    }

    pub fn wait(self: *Self) void {
        self.event.wait(null) catch unreachable;
        self.event.deinit();
        (self.freeFn)(self);
    }
};