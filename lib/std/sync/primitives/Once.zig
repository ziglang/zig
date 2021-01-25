// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const builtin = std.builtin;
const testing = std.testing;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub fn Once(comptime Futex: type) fn (anytype) type {
    return struct {
        fn once(comptime initFn: anytype) type {
            return struct {
                state: State = .uninit,

                const Self = @This();
                const State = enum(u32) {
                    uninit,
                    calling,
                    init,
                };

                pub fn call(self: *Self) void {
                    const state = atomic.load(&self.state, .Acquire);
                    if (state != .init) {
                        self.callSlow();
                    }
                }

                fn callSlow(self: *Self) void {
                    @setCold(true);

                    const ptr = @ptrCast(*const u32, &self.state);
                    var state = atomic.compareAndSwap(
                        &self.state,
                        .uninit,
                        .calling,
                        .Relaxed,
                        .Relaxed,
                    ) orelse {
                        _ = initFn();

                        if (helgrind) |hg| {
                            hg.annotateHappensBefore(@ptrToInt(self));
                        }

                        atomic.store(&self.state, .init, .Release);
                        Futex.wake(ptr, std.math.maxInt(u32));
                        return;
                    };

                    const is_calling = switch (state) {
                        .uninit => unreachable,
                        .calling => true,
                        .init => false,
                    };

                    if (is_calling) {
                        const expect = @enumToInt(State.calling);
                        Futex.wait(ptr, expect, null) catch unreachable;
                    }

                    state = atomic.load(&self.state, .Acquire);
                    assert(state == .init);

                    if (helgrind) |hg| {
                        hg.annotateHappensAfter(@ptrToInt(self));
                    }
                }
            };
        }
    }.once;
}

pub fn DebugOnce(comptime initFn: anytype) type {
    return struct {
        is_init: bool = false,

        const Self = @This();

        pub fn call(self: *Self) void {
            if (!self.is_init) {
                _ = initFn();
                self.is_init = true;
            }
        }
    };
}
