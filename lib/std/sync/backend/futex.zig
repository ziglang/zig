// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const assert = std.debug.assert;

const helgrind = std.valgrind.helgrind;
const use_valgrind = builtin.valgrind_support;

pub fn Backend(comptime Futex: type) type {
    return struct {
        pub const Lock = extern struct {
            state: State = .unlocked,

            const Self = @This();
            const State = enum(u32) {
                unlocked,
                locked,
                contended,
            };

            pub fn tryAcquire(self: *Self) ?Held {
                const acquired = atomic.compareAndSwap(
                    &self.state,
                    .unlocked,
                    .locked,
                    .Acquire,
                    .Relaxed,
                ) == null;

                if (use_valgrind and acquired) {
                    helgrind.annotateHappensAfter(@ptrToInt(self));
                }

                if (acquired) {
                    return Held{ .lock = self };
                }

                return null;
            }

            pub fn acquire(self: *Self) Held {
                switch (atomic.swap(&self.state, .locked, .Acquire)) {
                    .unlocked => {},
                    else => |state| self.acquireSlow(state),
                }

                if (use_valgrind) {
                    helgrind.annotateHappensAfter(@ptrToInt(self));
                }

                return Held{ .lock = self };
            }

            fn acquireSlow(self: *Self, current_state: State) void {
                @setCold(true);

                var spin_iter: usize = 0;
                while (true) {
                    const state = atomic.tryCompareAndSwap(
                        &self.state,
                        .unlocked,
                        current_state,
                        .Acquire,
                        .Relaxed,
                    ) orelse return;

                    if (state == .contended)
                        break;

                    switch (Futex.yield(spin_iter)) {
                        true => spin_iter +%= 1,
                        else => break,
                    }
                }

                while (true) {
                    switch (atomic.swap(&self.state, .contended, .Acquire)) {
                        .unlocked => return,
                        else => {},
                    }

                    Futex.wait(
                        @ptrCast(*const u32, &self.state),
                        @enumToInt(State.contended),
                        null,
                    );
                }
            }

            pub const Held = extern struct {
                lock: *Self,

                pub fn release(self: Held) void {
                    self.lock.release();
                }
            };

            fn release(self: *Self) void {
                if (use_valgrind) {
                    helgrind.annotateHappensBefore(@ptrToInt(self));
                }

                switch (atomic.swap(&self.state, .unlocked, .Release)) {
                    .unlocked => unreachable,
                    .locked => {},
                    .contended => self.releaseSlow(),
                }
            }

            fn releaseSlow(self: *Self) void {
                @setCold(true);

                Futex.wake(@ptrCast(*const u32, &self.state));
            }
        };

        pub const Event = extern struct {
            state: State,

            const Self = @This();
            const State = enum(u32) {
                empty,
                waiting,
                notified,
            };

            pub fn init(self: *Self) void {
                self.state = .empty;
            } 

            pub fn deinit(self: *Self) void {
                self.* = undefined;
            }

            pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
                if (atomic.compareAndSwap(
                    &self.state,
                    .empty,
                    .waiting,
                    .Acquire,
                    .Acquire,
                )) |state| {
                    assert(state == .notified);
                    return;
                }

                while (true) {
                    var timeout: ?u64 = null;
                    if (deadline) |deadline_ns| {
                        const now = std.time.now();
                        if (now > deadline_ns)
                            break;
                        timeout = deadline_ns - now;
                    }

                    Futex.wait(
                        @ptrCast(*const u32, &self.state),
                        @enumToInt(State.waiting),
                        timeout,
                    );

                    switch (atomic.load(&self.state, .Acquire)) {
                        .empty => unreachable,
                        .waiting => {},
                        .notified => return,
                    }
                }

                const state = atomic.compareAndSwap(
                    &self.state,
                    .waiting,
                    .empty,
                    .Acquire,
                    .Acquire,
                ) orelse return error.TimedOut;
                assert(state == .notified);
            }

            pub fn set(self: *Self) void {
                switch (atomic.swap(&self.state, .notified, .Release)) {
                    .empty => {},
                    .waiting => Futex.wake(@ptrCast(*const u32, &self.state)),
                    .notified => unreachable,
                }
            }

            pub fn reset(self: *Self) void {
                self.state = .empty;
            }

            pub fn yield(iteration: ?usize) bool {
                return Futex.yield(iteration);
            }
        };
    };
}