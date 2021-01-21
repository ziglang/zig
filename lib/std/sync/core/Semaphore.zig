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

pub fn Semaphore(comptime parking_lot: type) type {
    return extern struct {
        permits: usize = 0,

        const Self = @This();

        pub fn init(permits: usize) Self {
            return .{ .permits = permits };
        }

        pub fn deinit(self: *Self) void {
            if (use_valgrind) {
                helgrind.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn tryWait(self: *Self) bool {
            return self.tryAcquire(1);
        }

        pub fn wait(self: *Self) void {
            return self.acquire(1);
        }

        pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryAcquireFor(1, duration);
        }

        pub fn tryWaitUntil(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryAcquireUntil(1, duration);
        }

        pub fn tryAcquire(self: *Self, permits: usize) bool {
            var perms = atomic.load(&self.permits, .SeqCst);

            while (true) {
                if (perms < permits)
                    return false;

                perms = atomic.tryCompareAndSwap(
                    &self.permits,
                    perms,
                    perms - permits,
                    .SeqCst,
                    .SeqCst,
                ) orelse break;
            }

            if (use_valgrind) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }

            return true;
        }

        pub fn acquire(self: *Self, permits: usize) void {
            self.acquireInner(permits, null) catch unreachable;
        }

        pub fn tryAcquireFor(self: *Self, permits: usize, duration: u64) error{TimedOut}!void {
            return self.tryAcquireUntil(permits, parking_lot.nanotime() + duration);
        }

        pub fn tryAcquireUntil(self: *Self, permits: usize, deadline: u64) error{TimedOut}!void {
            return self.acquireInner(permits, deadline);
        }

        fn acquireInner(self: *Self, permits: usize, deadline: ?u64) error{TimedOut}!void {
            const Parker = struct {
                semaphore: *Self,
                perms: usize,

                pub fn onValidate(this: @This()) ?usize {
                    const perms = atomic.load(&this.semaphore.permits, .SeqCst);
                    if (perms >= this.perms) {
                        return null;
                    }
                    return this.perms;
                }

                pub fn onBeforeWait(this: @This()) void {}
                pub fn onTimeout(this: @This(), has_more: bool) void {}
            };

            while (true) {
                if (self.tryAcquire(permits)) {
                    break;
                }

                _ = parking_lot.parkConditionally(
                    @ptrToInt(self),
                    deadline,
                    Parker{
                        .semaphore = self,
                        .perms = permits,
                    },
                ) catch |err| switch (err) {
                    error.Invalid => {},
                    error.TimedOut => return error.TimedOut,
                };
            }

            if (use_valgrind) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }
        }

        pub fn tryRelease(self: *Self, permits: usize) bool {
            // TODO: if the release() fails, is there a way to cancel the happensBefore edge?
            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            var perms = atomic.load(&self.permits, .SeqCst);
            while (true) {
                var new_perms: usize = undefined;
                if (@addWithOverflow(usize, perms, permits, &new_perms)) {
                    return false;
                }

                perms = atomic.tryCompareAndSwap(
                    &self.permits,
                    perms,
                    new_perms,
                    .SeqCst,
                    .SeqCst,
                ) orelse break;
            }

            const Filter = struct {
                sema: *Self,
                consumed: usize = 0,

                pub fn onBeforeWake(this: @This()) void {}
                pub fn onFilter(this: *@This(), unpark_context: UnparkContext) UnparkFilter {
                    const waiter_perms = unpark_context.getToken();
                    const perms = atomic.load(&this.sema.permits, .SeqCst);

                    if (
                        (perms < this.consumed) or
                        ((perms - this.consumed) < waiter_perms) or
                        (this.consumed > (std.math.maxInt(usize) - waiter_perms))
                    ) {
                        return .stop;
                    }

                    this.consumed += waiter_perms;
                    return .{ .unpark = 0 };
                }
            };

            var filter = Filter{ .sema = self };
            parking_lot.unparkFilter(@ptrToInt(self), &filter);
            return true;
        }

        pub fn post(self: *Self) void {
            return self.release(1);
        }

        pub fn release(self: *Self, permits: usize) void {
            assert(self.tryRelease(permits));
        }
    };
}

pub const DebugSemaphore = extern struct {
    permits: usize = 0,

    const Self = @This();

    pub fn init(permits: usize) Self {
        return .{ .permits = permits };
    }

    pub fn tryWait(self: *Self) bool {
        return self.tryAcquire(1);
    }

    pub fn wait(self: *Self) void {
        return self.tryAcquire(1);
    }

    pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        return self.tryAcquireFor(1, duration);
    }

    pub fn tryWaitUntil(self: *Self, duration: u64) error{TimedOut}!void {
        return self.tryAcquireUntil(1, duration);
    }

    pub fn tryAcquire(self: *Self, permits: usize) bool {
        if (self.permits < permits)
            return false;
        
        self.permits -= permits;
        return true;
    }

    pub fn acquire(self: *Self, permits: usize) void {
        if (!self.tryAcquire(permits))
            @panic("deadlock detected");
    }

    pub fn tryAcquireFor(self: *Self, permits: usize, duration: u64) error{TimedOut}!void {
        return self.acquire(permits);
    }

    pub fn tryAcquireUntil(self: *Self, permits: usize, deadline: u64) error{TimedOut}!void {
        return self.acquire(permits);
    }

    pub fn post(self: *Self) void {
        return self.release(1);
    }

    pub fn tryRelease(self: *Self, permits: usize) bool {
        if (self.permits > std.math.maxInt(usize) - permits)
            return false;

        self.permits += permits;
        return true;
    }

    pub fn release(self: *Self, permits: usize) void {
        assert(self.tryRelease(permits));
    }
};