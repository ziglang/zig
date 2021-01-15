// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

pub fn RwLock(comptime parking_lot: type) type {
    // TODO: better implementation which doesn't rely on Mutex + Semaphore
    return extern struct {
        state: usize = 0,
        mutex: Mutex = .{},
        semaphore: Semaphore = .{},

        const IS_WRITING = 1;
        const WRITER = 1 << 1;
        const READER = 1 << (1 + std.meta.bitCount(Count));
        const WRITER_MASK = std.math.maxInt(Count) << @ctz(usize, WRITER);
        const READER_MASK = std.math.maxInt(Count) << @ctz(usize, READER);
        const Count = std.meta.Int(.unsigned, @divFloor(std.meta.bitCount(usize) - 1, 2));

        const Self = @This();
        const Mutex = @import("./Mutex.zig").Mutex(parking_lot);
        const Semaphore = @import("./Semaphore.zig").Semaphore(parking_lot);

        pub fn tryAcquire(self: *Self) ?Held {
            if (self.mutex.tryAcquire()) |held| {
                const state = atomic.load(&self.state, .SeqCst);

                if (state & READER_MASK == 0) {
                    _ = atomic.bitSet(&self.state, @ctz(u3, IS_WRITING), .SeqCst);
                    return Held{
                        .held = held,
                        .rwlock = self,
                    };
                }

                held.release();
            }

            return null;
        }

        pub fn acquire(self: *Self) Held {
            _ = atomic.fetchAdd(&self.state, WRITER, .SeqCst);
            const held = self.mutex.acquire();

            const state = atomic.fetchAdd(&self.state, IS_WRITING, .SeqCst);
            if (state & READER_MASK != 0)
                self.semaphore.wait();

            return Held{
                .held = held,
                .rwlock = self,
            };
        }

        pub fn tryAcquireShared(self: *Self) ?Held {
            var state = atomic.load(&self.state, .SeqCst);
            if (state & (IS_WRITING | WRITER_MASK) == 0) {
                _ = atomic.compareAndSwap(
                    &self.state,
                    state,
                    state + READER,
                    .SeqCst,
                    .SeqCst,
                ) orelse return Held{
                    .held = null,
                    .rwlock = self,
                };
            }

            if (self.mutex.tryAcquire()) |held| {
                _ = atomic.fetchAdd(&self.state, READER, .SeqCst);
                held.release();

                return Held{
                    .held = null,
                    .rwlock = self,
                };
            }

            return null;
        }

        pub fn acquireShared(self: *Self) Held {
            var state = atomic.load(&self.state, .SeqCst);
            while (state & (IS_WRITING | WRITER_MASK) == 0) {
                _ = atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state + READER,
                    .SeqCst,
                    .SeqCst,
                ) orelse return Held{
                    .held = null,
                    .rwlock = self,
                };
            }

            const held = self.mutex.acquire();
            defer held.release();

            _ = atomic.fetchAdd(&self.state, READER, .SeqCst);
            
            return Held{
                .held = null,
                .rwlock = self,
            };
        }

        pub const Held = struct {
            rwlock: *Self,
            held: ?Mutex.Held,

            pub fn release(self: Held) void {
                if (self.held) |held|
                    return self.rwlock.release(held);
                return self.rwlock.releaseShared();
            }
        };

        fn release(self: *Self, held: Mutex.Held) void {
            _ = atomic.bitReset(&self.state, @ctz(u3, IS_WRITING), .SeqCst);
            held.release();
        }

        fn releaseShared(self: *Self) void {
            const state = atomic.fetchSub(&self.state, READER, .SeqCst);

            if ((state & READER_MASK == READER) and (state & IS_WRITING != 0))
                self.semaphore.post();
        }
    };
}