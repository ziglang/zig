// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const builtin = std.builtin;

pub fn Mutex(comptime parking_lot: anytype) type {
    return extern struct {
        /// Eventually fair mutex implementation derived fron Amanieu's port of Webkits WTF::Lock.
        /// https://github.com/Amanieu/parking_lot/blob/master/src/raw_mutex.rs
        ///
        /// The state itself only requires two bits but needs to be rounded up to u8 in order to be used atomically.
        /// LOCKED: if set, then there is a thread which owns exclusive access to the Mutex
        /// PARKED: if set, there is at least one thread waiting on the Mutex that needs to be unparked.
        ///
        /// This implementations supports cancellation via timeouts as well as fair unlocking and eventual fairness powered by the parking_lot implementation.
        /// Fairness here refers to the scheduling of threads into having ownership of the Mutex (or the critical section).
        /// An unfair Mutex allows a previous owner to re-acquire the Mutex even if there are threads waiting to acquire it.
        /// A fair Mutex, on the other hand, forces a previous owner to wait in line again (generally in a FIFO fashion) if theres other pending threads trying to acquire.
        //
        /// Unfairness is important for throughput as it optimizes keeping execution going on the same thread as switching thread ownership (wakeup) is a relatively expensive operation.
        /// Fairness is important for latency as it optimizes for bounding the amount of time any given thread has to wait before acquiring Mutex ownership.
        /// Combining both, the term "eventual fairness" implies that an Unfair mechanism is employed first but it switches to a fair mechanism under load or at least eventually.
        /// This attribute, which can be triggered either by the user or the parking lot implementation, protects from live-locks and bounds latency when enabled/provided correctly.
        state: u8 = UNLOCKED,

        const UNLOCKED = 0;
        const LOCKED = 1 << 0;
        const PARKED = 1 << 1;

        const TOKEN_RETRY = 0;
        const TOKEN_HANDOFF = 1;

        const Self = @This();
        const is_x86 = switch (builtin.arch) {
            .i386, .x86_64 => true,
            else => false,
        };

        /// Try to acquire ownership of the Mutex if its not currently owned in a non-blocking manner.
        /// Returns true if it was successful in doing so.
        pub fn tryAcquire(self: *Self) ?Held {
            // On x86, its better to use `lock bts` instead of `lock cmpxchg` loop below
            // due to it having a smaller instruction cache footprint making it great for inlining.
            if (is_x86) {
                return atomic.bitSet(
                    &self.state,
                    @ctz(u3, LOCKED),
                    .Acquire,
                ) == 0;
            }

            var state = UNLOCKED;
            while (true) {
                state = atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state | LOCKED,
                    .Acquire,
                    .Relaxed,
                ) orelse return true;
                if (state & LOCKED != 0)
                    return false;
            }
        }

        /// Try to acquire ownership of the Mutex, blocking when necessary using the Event.
        /// An attempt is made to acquire the Mutex is no more than the duration in nanoseconds provided.
        /// If it fails to acquire the Mutex under that time, error.TimedOut is returned.
        pub fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!Held {
            return self.tryAcquireUntil(parking_lot.nanotime() + duration);
        }

        /// Try to acquire ownership of the Mutex, blocking when necessary using the Event.
        /// An attempt is made to acquire the Mutex before the Event-based deadline in nanoseconds provided.
        /// If it fails to acquire the Mutex under that time, error.TimedOut is returned.
        pub fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
            return self.acquireInner(deadline);
        }

        /// Acquire ownership of the Mutex, blocking using the Event when necessary.
        pub fn acquire(self: *Self) Held {
            return self.acquireInner(null) catch unreachable;
        }

        pub const Held = struct {
            mutex: *Self,

            /// Release ownership of the Mutex (assuming the caller has it)
            /// and wake up a thread waiting to acquire it if possible.
            pub fn release(self: Held) void {
                self.mutex.releaseInner(false);
            }

            /// Release ownership of the Mutex (assuming the caller has it)
            /// and wake up a thread waiting to acquire it if possible while also passing ownership of the Mutex to that thread.
            /// If no threads are available to be woken up, ownership is released as normal.
            /// This is commonly useful when the caller wants to enforce that another thread gets the Mutex as soon as possible for latency reasons.
            pub fn releaseFair(self: Held) void {
                self.mutex.releaseInner(true);
            }
        };
        
        fn acquireInner(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            if (self.tryAcquireInnerFast(UNLOCKED))
                return Held{ .mutex = self };
            return self.acquireInnerSlow(deadline);
        }

        fn releaseInner(self: *Self, be_fair: bool) void {
            if (!self.tryReleaseInnerFast())
                return self.releaseInnerSlow(be_fair);
        }

        inline fn tryAcquireInnerFast(self: *Self, assume_state: usize) bool {
            // On x86, we call tryAcquire() since it uses "lock bts"
            if (is_x86) {
                return self.tryAcquire();
            }

            return atomic.tryCompareAndSwap(
                &self.state,
                state,
                state | LOCKED,
                .Acquire,
                .relaxed,
            ) == null;
        }

        inline fn tryReleaseInnerFast(self: *Self) bool {
            return atomic.tryCompareAndSwap(
                &self.state,
                LOCKED,
                UNLOCKED,
                .Release,
                .Relaxed,
            ) == null;
        }

        fn acquireInnerSlow(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            @setCold(true);

            var spin_iter: usize = 0;
            var state = atomic.load(&self.state, .Relaxed);

            while (true) {
                // Try to acquire the Mutex even if there are pending waiters.
                // When fairness is employed, it keeps the LOCKED bit set so this still works.
                if (state & LOCKED == 0) {
                    if (self.tryAcquireInnerFast(state))
                        return Held{ .mutex = self };

                    _ = Event.yield(null);
                    state = atomic.load(&self.state, .Relaxed); 
                    continue;
                }
                
                // The Mutex is currently LOCKED so we should park our thread and wait for it to be unlocked.
                // If there is no other thread parked, then we need to set the PARKED bit so that the owning will see to wake us up.
                // We also spin a bit (or however long the Event implementation decides) before parking in hopes that the LOCKED bit will be released soon.
                if (state & PARKED == 0) {
                    if (Event.yield(spin_iter)) {
                        spin_iter +%= 1;
                        state = atomic.load(&self.state, .Relaxed);
                        continue;
                    }

                    if (atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        state | PARKED,
                        .Relaxed,
                        .Relaxed,
                    )) |updated| {
                        state = updated;
                        continue;
                    }
                }

                const Parker = struct {
                    mutex: *Self,

                    /// Before we park, we need to make sure that we setup the Mutex for us to actually be parked.
                    /// During the parking process, the state may have changed so we need to recheck it here unless we risk missing a wake-up.
                    pub fn onValidate(this: @This()) ?usize {
                        const mutex_state = atomic.load(&this.mutex.state, .Relaxed);
                        if (mutex_state != (LOCKED | PARKED))
                            return null;
                        return 0;
                    }

                    pub fn onBeforeWait(this: @This()) void {
                        // Nothing to be done before we wait.
                    }

                    /// On timeout, we should remove the PARKED bit on the Mutex
                    /// if there are no more threads waiting on the Mutex so that
                    /// the next `release*()` doesn't do an unnecessary wake-up.
                    pub fn onTimeout(this: @This(), has_more: bool) void {
                        if (!has_more) {
                            _ = atomic.bitReset(
                                &this.mutex.state,
                                @ctz(u3, @as(u8, PARKED)),
                                .Relaxed,
                            );
                        }
                    }
                };
                
                // Wait on the Mutex for a wake-up notification.
                const token = parking_lot.parkConditionally(
                    @ptrToInt(self),
                    deadline,
                    Parker{ .mutex = self },
                ) catch |err| switch (err) {
                    error.Invalid => TOKEN_RETRY,
                    error.TimedOut => return error.TimedOut,
                };
                
                // If the thread that woke us up handed off ownership to us,
                // then we don't need to try and acquire it again as we can
                // then assume that it has already been acquired for us.
                switch (token) {
                    TOKEN_RETRY => {},
                    TOKEN_HANDOFF => return,
                    else => unreachable,
                }

                spin_iter = 0;
                state = atomic.load(&self.state, .Relaxed);
            }
        }

        fn releaseInnerSlow(self: *Self, force_fair: bool) void {
            @setCold(true);

            // If the state is just LOCKED, that means the fast path release spuriously failed.
            // If so, we just need to unlock as normal, taking into account false negatives with a loop this time.
            var state = atomic.load(&self.state, .Relaxed);
            while (state == LOCKED) {
                state = atomic.tryCompareAndSwap(
                    &self.state,
                    LOCKED,
                    UNLOCKED,
                    .Release,
                    .Relaxed,
                ) orelse return;
            }

            const Unparker = struct {
                mutex: *Self,
                force_fair: bool,

                /// When we go to upark, we are the only thread that can remove set bits instead of add them.
                /// This is verified by the ownership of the WaitQueue to the Mutex provided by parking_lot in this callback.
                pub fn onUnpark(this: @This(), result: parking_lot.UnparkResult) usize {
                    // If we woke up a thread and we are doing a fair-unlock, then leave the LOCKED bit set.
                    // If this is the last thread parked on the Mutex, still leave the LOCKED bit set, but remove the PARKED bit.
                    //
                    // A Release memory barrier isn't needed as the fair-unlocked thread won't be re-checking the state with Acquire when woken up with handoff.
                    // Instead, we rely on the wake-up itself to provide the necessary Release/Acquire semantics needed for any data this Mutex protects.
                    if (result.token != null and (this.force_fair or result.be_fair)) {
                        if (!result.has_more)
                            atomic.store(&this.mutex.state, LOCKED, .Relaxed);
                        return TOKEN_HANDOFF;
                    }

                    // This is an unfair wake up, so unset the bits accordingly.
                    // The LOCKED bit is always unset to actually release Mutex ownership.
                    // The PARKED bit is unset if this is the last thread that is being unparked.
                    //
                    // Release ordering used to synchronize memory protected by the Mutex with the next acquiring threads 
                    // as they race to acquire the Mutex ownership while outside the WaitQueue so they dont have its happens-before guarantees.
                    const new_state = if (result.token == null) @as(u8, UNLOCKED) else PARKED;
                    atomic.store(&this.mutex.state, new_state, .Release);
                    return TOKEN_RETRY;
                }
            };

            parking_lot.unparkOne(@ptrToInt(self), Unparker{
                .mutex = self,
                .force_fair = force_fair,
            });
        }
    };
}

/// This has the sematics as `Mutex`, however it does not actually do any
/// synchronization. Operations are safety-checked no-ops.
pub const DebugMutex = extern struct {
    is_locked: @TypeOf(init) = init,

    const Self = @This();
    const init = if (std.debug.runtime_safety) false else {};

    pub fn tryAcquire(self: *Self) ?Held {
        if (std.debug.runtime_safety) {
            if (self.is_locked)
                return null;
            self.is_locked = true;
        }

        return Held{ .mutex = self };
    }

    pub fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!void {
        return self.tryAcquire() orelse error.TimedOut;
    }

    pub fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        return self.tryAcquire() orelse error.TimedOut;
    }

    pub fn acquire(self: *Self) void {
        return self.tryAcquire() orelse @panic("deadlock detected");
    }

    pub const Held = extern struct {
        mutex: *Mutex,

        pub fn release(self: Held) void {
            if (std.debug.runtime_safety)
                self.mutex.is_locked = false;
        }

        pub fn releaseFair(self: Held) void {
            self.release();
        }
    }
};