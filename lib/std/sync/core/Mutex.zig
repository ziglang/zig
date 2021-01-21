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

const helgrind = std.valgrind.helgrind;
const use_valgrind = builtin.valgrind_support;

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

        pub fn deinit(self: *Self) void {
            if (use_valgrind) {
                helgrind.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        /// Try to acquire ownership of the Mutex if its not currently owned in a non-blocking manner.
        /// Returns true if it was successful in doing so.
        pub fn tryAcquire(self: *Self) ?Held {
            if (!self.tryAcquireFast(UNLOCKED)) {
                return null;
            }

            if (use_valgrind) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{ .mutex = self };
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
        
        fn acquireInner(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            if (!self.tryAcquireFast(UNLOCKED)) {
                try self.acquireSlow(deadline);
            }

            if (use_valgrind) {
                helgrind.annotateHappensAfter(@ptrToInt(self));
            }
            
            return Held{ .mutex = self };
        }

        inline fn tryAcquireFast(self: *Self, assume_state: u8) bool {
            // On x86, its better to use `lock bts` instead of `lock cmpxchg` loop below
            // due to it having a smaller instruction cache footprint making it great for inlining.
            if (is_x86) {
                return atomic.bitSet(
                    &self.state,
                    @ctz(u1, LOCKED),
                    .Acquire,
                ) == 0;
            }

            var state = assume_state;
            while (true) {
                if (state & LOCKED != 0) {
                    return false;
                }
                state = atomic.tryCompareAndSwap(
                    &self.state,
                    state,
                    state | LOCKED,
                    .Acquire,
                    .Relaxed,
                ) orelse return true;
            }
        }

        fn acquireSlow(self: *Self, deadline: ?u64) error{TimedOut}!void {
            @setCold(true);

            var spin_iter: usize = 0;
            var state = atomic.load(&self.state, .Relaxed);
            while (true) {
                // Try to acquire the Mutex even if there are pending waiters.
                // When fairness is employed, it keeps the LOCKED bit set so this still works.
                if (state & LOCKED == 0) {
                    if (self.tryAcquireFast(state)) {
                        return;
                    }

                    _ = parking_lot.Event.yield(null);
                    state = atomic.load(&self.state, .Relaxed);
                    continue;
                }
                
                // The Mutex is currently LOCKED so we should park our thread and wait for it to be unlocked.
                // If there is no other thread parked, then we need to set the PARKED bit so that the owning will see to wake us up.
                // We also spin a bit (or however long the Event implementation decides) before parking in hopes that the LOCKED bit will be released soon.
                if (state & PARKED == 0) {
                    if (parking_lot.Event.yield(spin_iter)) {
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
                        if (mutex_state != (LOCKED | PARKED)) {
                            return null;
                        }
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
                            _ = atomic.bitUnset(
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
                    TOKEN_HANDOFF => return,
                    TOKEN_RETRY => {},
                    else => unreachable,
                }

                spin_iter = 0;
                state = atomic.load(&self.state, .Relaxed);
            }
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

        fn releaseInner(self: *Self, be_fair: bool) void {
            if (use_valgrind) {
                helgrind.annotateHappensBefore(@ptrToInt(self));
            }

            if (atomic.tryCompareAndSwap(
                &self.state,
                LOCKED,
                UNLOCKED,
                .Release,
                .Relaxed,
            )) |updated| {
                self.releaseSlow(be_fair);
            }
        }

        fn releaseSlow(self: *Self, force_fair: bool) void {
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
                        if (!result.has_more) {
                            atomic.store(&this.mutex.state, LOCKED, .Relaxed);
                        }
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

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn tryAcquire(self: *Self) ?Held {
        if (std.debug.runtime_safety) {
            if (self.is_locked) return null;
            self.is_locked = true;
        }

        return Held{ .mutex = self };
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

    pub fn acquire(self: *Self) Held {
        return self.tryAcquire() orelse @panic("deadlock detected");
    }

    pub const Held = extern struct {
        mutex: *Self,

        pub fn release(self: Held) void {
            if (std.debug.runtime_safety) {
                assert(self.mutex.is_locked);
                self.mutex.is_locked = false;
            }
        }

        pub fn releaseFair(self: Held) void {
            self.release();
        }
    };
};

test "Mutex" {
    const TestMutex = std.sync.Mutex;

    {
        var mutex = TestMutex{};
        defer mutex.deinit();

        var held = mutex.tryAcquire() orelse unreachable;
        testing.expectEqual(mutex.tryAcquire(), null);
        held.release();

        held = mutex.acquire();
        defer held.release();

        const delay = 1 * std.time.ns_per_ms;
        testing.expectError(error.TimedOut, mutex.tryAcquireFor(delay));
        testing.expectError(error.TimedOut, mutex.tryAcquireUntil(std.time.now() + delay));
    }

    if (std.io.is_async) return;
    if (std.builtin.single_threaded) return;

    const Contention = struct {
        index: usize = 0,
        case: Case = undefined,
        start_event: std.sync.ResetEvent = .{},
        counters: [num_counters]Counter = undefined,

        const Self = @This();
        const num_counters = 100;
        const counters_init = [_]Counter{Counter{}} ** num_counters;

        const Counter = struct {
            mutex: TestMutex = .{},
            remaining: u128 = 10000,

            fn tryDecr(self: *Counter) bool {
                const held = self.mutex.acquire();
                defer held.release();

                if (self.remaining == 0) {
                    return false;
                }

                self.remaining -= 1;
                return true;
            }
        };

        const Case = union(enum){
            random: Random,
            high: High,
            forced: Forced,
            low: Low,

            /// The common case of many threads generally not touching other thread's Mutexes
            const Low = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.counters = counters_init;
                    self.index = 0;
                }

                fn run(_: @This(), self: *Self) void {
                    const local_index = atomic.fetchAdd(&self.index, 1, .SeqCst);
                    const local_counter = &self.counters[local_index];
                    const check_remote_every = 100;

                    var iter: usize = 0;
                    var seed: usize = undefined;
                    var prng = std.rand.DefaultPrng.init(@ptrToInt(&seed));

                    while (local_counter.tryDecr()) : (iter += 1) {
                        if (iter % check_remote_every == 0) {
                            const remote_index = prng.random.uintLessThan(usize, self.counters.len);
                            const remote_counter = &self.counters[remote_index];
                            _ = remote_counter.tryDecr();
                        }
                    }
                }
            };

            /// The extreme case of many threads fighting over the same Mutex.
            const High = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.counters[0] = Counter{};
                    self.counters[0].remaining = 500_000;
                }

                fn run(_: @This(), self: *Self) void {
                    while (self.counters[0].tryDecr()) {
                        atomic.spinLoopHint();
                    }
                }
            };

            /// The slightly-less extreme case of many threads fighting over the same Mutex.
            /// But they all eventually do an equal amount of work.
            const Forced = struct {
                const local_iters = 100_000;

                fn setup(_: @This(), self: *Self) void {
                    self.counters[0] = Counter{};
                    self.counters[0].remaining = local_iters * num_counters;
                }

                fn run(_: @This(), self: *Self) void {
                    var iters: usize = local_iters;
                    while (iters > 0) : (iters -= 1) {
                        _ = self.counters[0].tryDecr();
                    }
                }
            };
            
            /// Stresses the common use-case of random Mutex contention.
            const Random = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.counters = counters_init;
                }

                /// Each thread iterates the counters array starting from a random position.
                /// On each iteration, it tries to lock & decrement the value of each counter is comes across.
                /// When it is unable to decrement on any counter, it terminates (seeing that they've all reached 0).
                fn run(_: @This(), self: *Self) void {
                    var seed: usize = undefined;
                    var prng = std.rand.DefaultPrng.init(@ptrToInt(&seed));

                    while (true) {
                        var did_decr = false;
                        var iter = self.counters.len;
                        var index = prng.random.int(usize) % iter;

                        while (iter > 0) : (iter -= 1) {
                            const counter = &self.counters[index];
                            index = (index + 1) % self.counters.len;
                            did_decr = counter.tryDecr() or did_decr;
                        }

                        if (!did_decr) {
                            break;
                        }
                    }
                }
            };
        };

        fn run(self: *Self) void {
            self.start_event.wait();

            switch (self.case) {
                .random => |case| case.run(self),
                .high => |case| case.run(self),
                .forced => |case| case.run(self),
                .low => |case| case.run(self),
            }
        }

        fn execute(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*std.Thread, 10);
            defer allocator.free(threads);

            defer {
                self.start_event.deinit();
                for (self.counters) |*counter| {
                    counter.mutex.deinit();
                }
            }

            for ([_]Case{ .high, .random, .forced }) |contention_case| {
                self.case = contention_case;
                switch (self.case) {
                    .random => |case| case.setup(self),
                    .high => |case| case.setup(self),
                    .forced => |case| case.setup(self),
                    .low => |case| case.setup(self),
                }

                self.start_event.reset();
                for (threads) |*t| {
                    t.* = try std.Thread.spawn(self, Self.run);
                }

                self.start_event.set();
                for (threads) |t| {
                    t.wait();
                }
            }
        }
    };

    var contention = Contention{};
    try contention.execute();
}