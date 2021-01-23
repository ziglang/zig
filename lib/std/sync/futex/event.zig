// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const generic = @import("./generic.zig");

const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub usingnamespace generic.Futex(struct {
    state: usize,

    const EMPTY: usize = 0;
    const NOTIFIED: usize = 1;

    const Self = @This();
    const Loop = std.event.Loop;

    fn getLoop() *Loop {
        return Loop.instance orelse unreachable;
    }

    pub fn init(self: *Self) void {
        self.state = EMPTY;
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
        var node = Loop.NextTickNode{ .data = @frame() };

        var waited = false;
        suspend {
            if (atomic.compareAndSwap(
                &self.state,
                EMPTY,
                @ptrToInt(&node),
                .Release,
                .Acquire,
            )) |state| {
                assert(state == NOTIFIED);
                getLoop().onNextTick(&node);
            } else {
                waited = true;
            }
        }

        if (waited) {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(&node));
            }
        }
    }

    pub fn set(self: *Self) void {
        const node = switch (atomic.swap(&self.state, NOTIFIED, .AcqRel)) {
            EMPTY => return,
            NOTIFIED => unreachable,
            else => |state| @intToPtr(*Loop.NextTickNode, state),
        };

        if (helgrind) |hg| {
            hg.annotateHappensBefore(@ptrToInt(node));
        }

        getLoop().onNextTick(node);
    }

    pub fn reset(self: *Self) void {
        self.state = EMPTY;
    }

    pub fn now() u64 {
        return std.time.now();
    }
});