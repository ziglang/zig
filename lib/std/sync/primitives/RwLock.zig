// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

/// https://github.com/bloomberg/rwl-bench/blob/master/bench11.cpp
const IS_WRITING: isize = 0x10 << (std.meta.bitCount(isize) - 8);
const PENDING_WRITER: isize = 1 << (std.meta.bitCount(isize) / 2);
const HAS_PENDING_WRITERS: isize = IS_WRITING - 1;
const READER: isize = 1;
const HAS_READERS: isize = PENDING_WRITER - 1;

pub fn RwLock(comptime Futex: anytype) type {
    return extern struct {
        state: isize = 0,
        mutex: Mutex = .{},
        semaphore: Semaphore = .{},

        const Self = @This();
        const Mutex = @import("./Mutex.zig").Mutex(Futex);
        const Semaphore = @import("./Semaphore.zig").Semaphore(Futex);

        pub const Dummy = DebugRwLock;

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.semaphore.deinit();
            self.mutex.deinit();
            self.* = undefined;
        }

        pub fn tryAcquire(self: *Self) ?Held {
            // Try to acquire the mutex without blocking
            const held = self.mutex.tryAcquire() orelse return null;

            // If theres still pending readers, give up since we can't block/wait for them here
            const state = atomic.load(&self.state, .Relaxed);
            if (state & HAS_READERS != 0) {
                held.release();
                return null;
            }

            // Tell the state that we are now writing.
            _ = atomic.fetchAdd(&self.state, IS_WRITING, .Relaxed);

            return Held{
                .rwlock = self,
                .mutex_held = held,
            };
        }

        pub fn acquire(self: *Self) Held {
            return self.acquireInner(null) catch unreachable;
        }

        pub fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!Held {
            return self.tryAcquireUntil(Futex.now() + duration);
        }

        pub fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
            return self.acquireInner(deadline);
        }
        
        fn acquireInner(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            // Tell the state that theres a writer waiting to acquire the mutex before doing so.
            // This causes new readers to fail and sleep on the mutex.
            _ = atomic.fetchAdd(&self.state, PENDING_WRITER, .Relaxed);

            const held = self.mutex.acquire();

            // After we acquire the mutex, we are no longer pending.
            // We also now have exclusive ownership so set the IS_WRITING bit.
            var state = atomic.fetchAdd(&self.state, IS_WRITING - PENDING_WRITER, .Relaxed);

            wait_for_readers: {
                // Nothing to do if theres no readers to wait for
                if (state & HAS_READERS == 0) {
                    break :wait_for_readers;
                }

                // Wait for the readers to complete
                const deadline_ns = deadline orelse {
                    self.semaphore.wait();
                    break :wait_for_readers;
                };

                if (self.semaphore.tryWaitUntil(deadline_ns)) {
                    break :wait_for_readers;    
                } else |timed_out| {}

                // If we timeout, we need to unset the IS_WRITING bit as we no longer will be.
                // If during that time the readers complete, then we have acquired it and dont need to timeout.
                state = atomic.load(&self.state, .Relaxed);
                while (true) {
                    if (state & HAS_READERS == 0) {
                        break :wait_for_readers;
                    }
                    state = atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        state - IS_WRITING,
                        .Release,
                        .Relaxed,
                    ) orelse {
                        held.release();
                        return error.TimedOut;
                    };
                }
            }

            return Held{
                .rwlock = self,
                .mutex_held = held,
            };
        }

        inline fn tryAcquireSharedFast(self: *Self) bool {
            // If there are no writers, try to add a READER to the state so announce that we're reading.
            var state = atomic.load(&self.state, .Relaxed);
            while (true) {
                if (state & (HAS_PENDING_WRITERS | IS_WRITING) != 0) {
                    return false;
                }

                state = atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state + READER,
                    .Acquire,
                    .Relaxed,
                ) orelse return true;
            }
        }

        inline fn tryAcquireSharedInner(self: *Self) bool {
            if (self.tryAcquireSharedFast()) {
                return true;
            }

            // If there are writers, try to grab the mutex to announce that we're reading.
            // Use tryAcquire() instead of acquire() since we're not allowed to block here.
            const held = self.mutex.tryAcquire() orelse return false;
            defer held.release();

            _ = atomic.fetchAdd(&self.state, READER, .Acquire);
            return true;
        }

        pub fn tryAcquireShared(self: *Self) ?Held {
            if (!self.tryAcquireSharedInner()) {
                return null;
            }
            
            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{
                .rwlock = self,
                .mutex_held = null,
            };
        }

        pub fn acquireShared(self: *Self) Held {
            return self.acquireSharedInner(null) catch unreachable;
        }

        pub fn tryAcquireSharedFor(self: *Self, duration: u64) error{TimedOut}!Held {
            return self.tryAcquireSharedUntil(Futex.now() + duration);
        }

        pub fn tryAcquireSharedUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
            return self.acquireSharedInner(deadline);
        }

        fn acquireSharedInner(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            acquired: {
                // Try to start reading by adding a READER if theres no writers.
                if (self.tryAcquireSharedFast()) {
                    break :acquired;
                }

                // If there are writers, try to acquire the lock in order to add the READER.
                if (blk: {
                    const deadline_ns = deadline orelse break :blk self.mutex.acquire();
                    break :blk self.mutex.tryAcquireUntil(deadline_ns) catch null;
                }) |held| {
                    _ = atomic.fetchAdd(&self.state, READER, .Acquire);
                    held.release();
                    break :acquired;
                }

                // If we failed to acquire the lock, try to add a READER again.
                // At this point, there may be no more writers so it could be free.
                if (!self.tryAcquireSharedFast()) {
                    return error.TimedOut;
                }
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{
                .rwlock = self,
                .mutex_held = null,
            };
        }

        pub const Held = struct {
            rwlock: *Self,
            mutex_held: ?Mutex.Held,

            pub fn isShared(self: Held) bool {
                return self.mutex_held == null;
            }

            pub fn release(self: Held) void {
                if (self.mutex_held) |held| {
                    self.rwlock.release(held);
                } else {
                    self.rwlock.releaseShared();
                }
            }
        };

        fn release(self: *Self, held: Mutex.Held) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            _ = atomic.fetchSub(&self.state, IS_WRITING, .Release);
            held.release();
        }

        fn releaseShared(self: *Self) void {
            const state = atomic.fetchSub(&self.state, READER, .Relaxed);

            // If we're the last reader and theres a reader waitinf for all the readers to wake up, signal it.
            if ((state & HAS_READERS == READER) and (state & IS_WRITING != 0)) {
                self.semaphore.post();
            }
        }
    };
}

pub const DebugRwLock = extern struct {
    state: isize = 0,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn tryAcquire(self: *Self) ?Held {
        if (self.state & (HAS_READERS | IS_WRITING) != 0) {
            return null;
        }

        self.state |= IS_WRITING;
        return Held{
            .rwlock = self,
            .is_shared = false,
        };
    }

    pub fn acquire(self: *Self) Held {
        return self.tryAcquire() orelse @panic("deadlock detected");
    }

    pub fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!Held {
        return self.tryAcquire() orelse {
            std.time.sleep(duration);
            return error.TimedOut;
        };
    }

    pub fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
        return self.tryAcquire() orelse {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        };
    }
    
    pub fn tryAcquireShared(self: *Self) ?Held {
        if (self.state & IS_WRITING != 0) {
            return null;
        }

        self.state += READER;
        return Held{
            .rwlock = self,
            .is_shared = true,
        };
    }

    pub fn acquireShared(self: *Self) Held {
        return self.tryAcquireShared() orelse @panic("deadlock detected");
    }

    pub fn tryAcquireSharedFor(self: *Self, duration: u64) error{TimedOut}!Held {
        return self.tryAcquireShared() orelse {
            std.time.sleep(duration);
            return error.TimedOut;
        };
    }

    pub fn tryAcquireSharedUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
        return self.tryAcquireShared() orelse {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        };
    }

    pub const Held = struct {
        rwlock: *Self,
        is_shared: bool,

        pub fn isShared(self: Held) bool {
            return self.is_shared;
        }

        pub fn release(self: Held) void {
            const subtract = if (self.is_shared) READER else IS_WRITING;
            self.rwlock.state -= subtract;
        }
    };
};