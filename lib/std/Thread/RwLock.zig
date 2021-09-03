const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const RwLock = @This();

impl: Impl = .{},

pub fn tryAcquire(self: *RwLock) ?Held {
    if (self.impl.tryAcquireWriter()) return Held.initExclusive(self);
    return null;
}

pub fn acquire(self: *RwLock) Held {
    self.impl.acquireWriter();
    return Held.initExclusive(self);
}

pub fn tryAcquireShared(self: *RwLock) ?Held {
    if (self.impl.tryAcquireReader()) return Held.initShared(self);
    return null;
}

pub fn acquireShared(self: *RwLock) Held {
    self.impl.acquireReader();
    return Held.initShared(self);
}

pub const Held = struct {
    ptr: usize,

    fn initExclusive(rwlock: *RwLock) Held {
        return .{ .ptr = @ptrToInt(rwlock) };
    }

    fn initShared(rwlock: *RwLock) Held {
        return .{ .ptr = @ptrToInt(rwlock) | 1 };
    }

    pub fn release(self: Held) void {
        const is_shared = self.ptr & 1 != 0;
        const rwlock = @intToPtr(*RwLock, self.ptr & ~@as(usize, 1));

        switch (is_shared) {
            true => rwlock.impl.releaseReader(),
            else => rwlock.impl.releaseWriter(),
        }
    }
};

pub const Impl = if (std.builtin.single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else
    FutexImpl;

const SerialImpl = struct {
    readers: u32 = 0,

    const MAX_READERS = std.math.maxInt(u32);

    fn tryAcquireReader(self: *Impl) bool {
        if (self.readers == MAX_READERS) return false; // writer locked
        if (self.readers == MAX_READERS - 1) return false; // reader count would overflow
        self.readers += 1;
        return true;
    }

    fn acquireReader(self: *Impl) void {
        if (!self.tryAcquireReader()) {
            unreachable; // deadlock detected
        }
    }

    fn releaseReader(self: *Impl) void {
        if (self.readers == MAX_READERS) unreachable; // released reader when writer acquired
        if (self.readers == 0) unreachable; // released reader when not acquired
        self.readers -= 1;
    }

    fn tryAcquireWriter(self: *Impl) bool {
        if (self.readers == MAX_READERS) return false; // writer locked
        if (self.readers != 0) return false; // pending readers
        self.readers = MAX_READERS;
        return true;
    }

    fn acquireWriter(self: *Impl) void {
        if (!self.tryAcquireWriter()) {
            unreachable; // deadlock detected
        }
    }

    fn releaseWriter(self: *Impl) void {
        if (self.readers == 0) unreachable; // released writer when not acquired
        if (self.readers != MAX_READERS) unreachable; // released writer when readers acquired
        self.readers = 0;
    }
};

const WindowsImpl = struct {
    srwlock: os.windows.SRWLOCK = os.windows.SRWLOCK_INIT,

    fn tryAcquireReader(self: *Impl) bool {
        return os.windows.kernel32.TryAcquireSRWLockShared(&self.srwlock) != os.windows.FALSE;
    }

    fn acquireReader(self: *Impl) void {
        os.windows.kernel32.AcquireSRWLockShared(&self.srwlock);
    }

    fn releaseReader(self: *Impl) void {
        os.windows.kernel32.ReleaseSRWLockShared(&self.srwlock);
    }

    fn tryAcquireWriter(self: *Impl) bool {
        return os.windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != os.windows.FALSE;
    }

    fn acquireWriter(self: *Impl) void {
        os.windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
    }

    fn releaseWriter(self: *Impl) void {
        os.windows.kernel32.ReleaseSRWLockExclusive(&self.srwlock);
    }
};

/// Modified implementation of Amanieus's parking_lot::RwLock:
/// https://raw.githubusercontent.com/Amanieu/parking_lot/master/src/raw_rwlock.rs
const FutexImpl = struct {
    state: Atomic(usize) = Atomic(usize).init(UNLOCKED),
    queue: Atomic(usize) = Atomic(usize).init(UNLOCKED),

    const UNLOCKED = 0;
    const WRITER = 1 << 0;
    const PARKED = 1 << 1;
    const WRITER_PARKED = 1 << 2;
    const READER = 1 << 3;
    const READER_MASK = ~@as(usize, READER - 1);

    fn tryAcquireReader(self: *Impl) bool {
        var state = self.state.load(.Monotonic);
        while (true) {
            const result = self.tryAcquireReaderWith(state) catch return false;
            state = result orelse return true;
        }
    }

    inline fn tryAcquireReaderWith(self: *Impl, state: usize) error{ Writer, Overflow }!?usize {
        if (state & WRITER != 0) {
            return error.Writer;
        }

        var new_state: usize = undefined;
        if (@addWithOverflow(usize, state, READER, &new_state)) {
            return error.Overflow;
        }

        return self.state.tryCompareAndSwap(
            state,
            new_state,
            .Acquire,
            .Monotonic,
        );
    }

    fn acquireReader(self: *Impl) void {
        if (!self.acquireReaderFast()) {
            self.acquireReaderSlow();
        }
    }

    inline fn acquireReaderFast(self: *Impl) bool {
        const state = self.state.load(.Monotonic);
        const result = self.tryAcquireReaderWith(state) catch return false;
        return result == null;
    }

    noinline fn acquireReaderSlow(self: *Impl) void {
        self.acquireWith(READER, PARKED, struct {
            /// Try to acquire a reader using tryAcquireReaderWith().
            pub fn tryAcquireWith(impl: *Impl) ?usize {
                var spin = SpinWait{};
                while (true) {
                    const state = impl.state.load(.Monotonic);
                    const result = impl.tryAcquireReaderWith(state) catch |err| switch (err) {
                        error.Writer => return state,
                        error.Overflow => unreachable, // RwLock reader count overflowed
                    };

                    _ = result orelse return null;

                    // Always yield in some form after a failed tryAcquireReaderWith()
                    // in order decrease contention when a bunch of readers are trying to acquire.
                    if (!spin.yield()) {
                        std.os.sched_yield() catch {};
                        spin = .{};
                    }
                }
            }

            // The writer bit must be set to wait (if it's not set, then we can acquire a reader).
            // The parked bit must be set to wait (if it's not set, releaseWriter() won't know to wake us up).
            pub fn shouldWait(state: usize) bool {
                return state & (WRITER | PARKED) == (WRITER | PARKED);
            }
        });
    }

    fn releaseReader(self: *Impl) void {
        // Remove one reader from the RwLock.
        // Release barrier to ensure all the reads on the protected state
        // happen before the RwLock relenquishes it's READER and synchronizes
        // with the Acquire in acquireWriterSlow() waiting for readers to exit.
        const state = self.state.fetchSub(READER, .Release);
        assert(state >= READER);

        // Wake up the writer waiting for readers to finish if
        // we're the last reader while the writer is waiting.
        if (state & (READER_MASK | WRITER_PARKED) == (READER | WRITER_PARKED)) {
            self.releaseReaderSlow();
        }
    }

    noinline fn releaseReaderSlow(self: *Impl) void {
        const old_state = self.state.fetchSub(WRITER_PARKED, .Monotonic);
        assert(old_state & WRITER_PARKED != 0);

        self.wake(WRITER_PARKED, struct {
            pub fn onWake(impl: *Impl, has_more: bool) void {
                _ = impl;
                assert(!has_more); // there should be no more than one WRITER_PARKED
            }
        });
    }

    fn tryAcquireWriter(self: *Impl) bool {
        return self.state.compareAndSwap(
            UNLOCKED,
            WRITER,
            .Acquire,
            .Monotonic,
        ) == null;
    }

    fn acquireWriter(self: *Impl) void {
        _ = self.state.tryCompareAndSwap(
            UNLOCKED,
            WRITER,
            .Acquire,
            .Monotonic,
        ) orelse return;
        self.acquireWriterSlow();
    }

    noinline fn acquireWriterSlow(self: *Impl) void {
        // Acquire the WRITER bit, waiting on PARKED to do so.
        self.acquireWith(WRITER, PARKED, struct {
            pub fn tryAcquireWith(impl: *Impl) ?usize {
                var state = impl.state.load(.Monotonic);
                while (true) {
                    if (state & WRITER != 0) {
                        return state;
                    }

                    state = impl.state.tryCompareAndSwap(
                        state,
                        state | WRITER,
                        .Acquire,
                        .Monotonic,
                    ) orelse return null;
                }
            }

            pub fn shouldWait(state: usize) bool {
                return state & (WRITER | PARKED) == (WRITER | PARKED);
            }
        });

        // Having acquired the WRITER bit, wait for all pending readers to exit.
        self.acquireWith(WRITER, WRITER_PARKED, struct {
            pub fn tryAcquireWith(impl: *Impl) ?usize {
                // Acquire to synchronize with the Release of readers
                // which ensures the loads done by the readers happen
                // before this writer fully acquires the RwLock and starts writing.
                const state = impl.state.load(.Acquire);
                assert(state & WRITER != 0);

                return switch (state & READER_MASK) {
                    0 => null,
                    else => state,
                };
            }

            pub fn shouldWait(state: usize) bool {
                assert(state & WRITER != 0);
                if (state & READER_MASK == 0) {
                    return false;
                }

                assert(state & WRITER_PARKED != 0);
                return true;
            }
        });
    }

    fn releaseWriter(self: *Impl) void {
        _ = self.state.compareAndSwap(
            WRITER,
            UNLOCKED,
            .Release,
            .Monotonic,
        ) orelse return;
        self.releaseWriterSlow();
    }

    noinline fn releaseWriterSlow(self: *Impl) void {
        // Wake up at most some readers + one writer on the PARKED bit.
        // Before we do, we unlock the RwLock by removing the WRITER bit.
        self.wake(PARKED, struct {
            pub fn onWake(impl: *Impl, has_more: bool) void {
                // Quick sanity check to make sure we still are WRITER locked.
                if (std.debug.runtime_safety) {
                    const old_state = impl.state.load(.Unordered);
                    assert(old_state == WRITER or old_state == WRITER | PARKED);
                }

                // Remove the WRITER bit and also remove the PARKED bit if
                // there's no more waiters on the PARKED bit.
                const new_state = if (has_more) PARKED else UNLOCKED;
                impl.state.store(new_state, .Release);
            }
        });
    }

    /// Runs `AcquireWithImpl.tryAcquireWith` until it succeedds (returns null)
    /// while setting/waiting on the `parked` bit using `access` as the waiter tag.
    fn acquireWith(
        self: *Impl,
        comptime access: usize,
        comptime parked: usize,
        comptime AcquireWithImpl: type,
    ) void {
        var spin = SpinWait{};
        assert(access == READER or access == WRITER);
        assert(parked == PARKED or parked == WRITER_PARKED);

        while (true) {
            const state = AcquireWithImpl.tryAcquireWith(self) orelse return;

            if (state & parked == 0) blk: {
                // Try to spin a bit on tryAcquireWith() if there's no one waiting.
                if (spin.yield()) {
                    continue;
                }

                // Set the `parked` bit or try again to acquire
                _ = self.state.tryCompareAndSwap(
                    state,
                    state | parked,
                    .Monotonic,
                    .Monotonic,
                ) orelse break :blk;
                std.atomic.spinLoopHint();
                continue;
            }

            // Try to wait on the `parked` bit
            spin = .{};
            self.wait(parked, struct {
                pub fn shouldWait(impl: *const Impl) ?usize {
                    const current_state = impl.state.load(.Monotonic);
                    if (!AcquireWithImpl.shouldWait(current_state)) return null;
                    return access;
                }
            });
        }
    }

    const Waiter = struct {
        /// (Either PARKED or WRITER_PARKED) Key representing the wait queue is waiter is on.
        addr: usize,
        /// If this waiter is it's wait queue head, points to possibly another distict wait queue's head.
        addr_prev: ?*Waiter,
        /// If this waiter is it's wait queue head, points to possibly another distinct wait queue's head.
        addr_next: ?*Waiter,
        // (Either READER or WRITER) Tag representing what type of waiter this is.
        tag: usize,
        /// The next waiter in the this wait queue
        next: ?*Waiter,
        /// If this waiter is it's wait queue head, points to the tail of the wait queue
        tail: *Waiter,
        /// What the waiter uses wait on for a direct notification
        futex: Atomic(u32),
    };

    fn wait(self: *Impl, address: usize, comptime WaitImpl: type) void {
        var waiter: Waiter = undefined;
        assert(address == PARKED or address == WRITER_PARKED);

        {
            var queue = self.acquireWaitQueue();
            defer self.releaseWaitQueue(queue);

            // Check the validation condition for if the waiter
            // should actually wait after acquiring the queue lock.
            // If it should wait, it returns the tag it will use to do so.
            const tag = WaitImpl.shouldWait(self) orelse return;
            assert(tag == READER or tag == WRITER);

            waiter = Waiter{
                .addr = address,
                .addr_prev = null,
                .addr_next = null,
                .tag = tag,
                .next = null,
                .tail = &self,
                .futex = Atomic(u32).init(0),
            };

            // Find the head of the wait queue for our addr.
            // Noting down the neighboring wait queue head
            // if we need to insert ourselves when its not found.
            var head = queue;
            while (head) |h| {
                if (h.addr == address) break;
                waiter.addr_prev = h;
                head = h.addr_next;
            }

            // Insert our node into either an existing wait queue
            // or create a new wait queue for our address.
            if (head) |h| {
                h.tail.next = &waiter;
                h.tail = &waiter;
            } else if (waiter.addr_prev) |p| {
                p.addr_next = &waiter;
            } else {
                queue = &waiter;
            }
        }

        // Wait to be notified by a wake() on the same address
        while (waiter.futex.load(.Acquire) == 0) {
            Futex.wait(&waiter.futex, 0, null) catch unreachable;
        }
    }

    fn wake(self: *Impl, address: usize, comptime WakeImpl: type) void {
        assert(address == PARKED or address == WRITER_PARKED);

        // Dequeued waiters from the wait queue on address go
        // here and are woken up after the queue lock is released
        var notified: ?*Waiter = null;
        defer while (notified) |waiter| {
            notified = waiter.next;
            waiter.futex.store(1, .Release);
            Futex.wake(&waiter.futex, 1);
        };

        var queue = self.acquireWaitQueue();
        defer self.releaseWaitQueue(queue);

        // Find the head node of the wait queue for `address`.
        var head = queue;
        while (head) |h| {
            if (h.addr == address) break;
            head = h.addr_next;
        }

        // After dequeuing some waiters, invoke the callback
        // with whether or not the wait queue for address is empty.
        defer {
            const has_more = head != null;
            WakeImpl.onWake(self, has_more);
        }

        while (head) |waiter| {
            // Dequeue a waiter on the wait queue for address.
            // Since we're dequeuing the head, transfer over its fields to the new head.
            head = waiter.next;
            if (head) |new_head| {
                new_head.tail = waiter.tail;
                new_head.addr_prev = waiter.addr_prev;
                new_head.addr_next = waiter.addr_next;
            }

            // Update any external wait queue links to point to the new head.
            if (waiter.addr_next) |n| {
                n.addr_prev = head orelse waiter.addr_prev;
            }
            if (waiter.addr_prev) |p| {
                p.addr_next = head orelse waiter.addr_next;
            } else {
                queue = head orelse waiter.addr_next;
            }

            // Push the waiter on a list to be notified after the queue lock is released.
            if (notified) |top| {
                top.tail.next = waiter;
                top.tail = waiter;
            } else {
                notified = waiter;
                waiter.tail = waiter;
            }

            // Stop dequeuing after the first WRITER.
            // This wakes up at most N WRITER and 1 WRITER.
            assert(waiter.tag == READER or waiter.tag == WRITER);
            if (waiter.tag == WRITER) {
                break;
            }
        }
    }

    const STATE_MASK = (WRITER | PARKED);
    const PTR_MASK = ~@as(usize, STATE_MASK);

    /// Grab exclusive ownership of the Waiter queues for the RwLock.
    /// Blocks the caller until it can acquire ownership.
    fn acquireWaitQueue(noalias self: *Impl) ?*Waiter {
        var spin = SpinWait{};
        var acquire_with: usize = WRITER;
        var queue = self.queue.load(.Monotonic);

        while (true) {
            // Try to acquire exclusive ownership of the Waiter queue.
            if (queue & STATE_MASK == UNLOCKED) {
                queue = self.queue.tryCompareAndSwap(
                    queue,
                    (queue & PTR_MASK) | acquire_with,
                    .Acquire,
                    .Monotonic,
                ) orelse return @intToPtr(?*Waiter, queue & PTR_MASK);
                continue;
            }

            // Ensure that it's tagged with PARKED before we sleep on the Futex.
            if (queue & STATE_MASK != PARKED) blk: {
                // The Waiter queue lock is only held to push/pop Waiter nodes.
                // Handle the case of micro-contention by spinning on the queue lock
                // if there are no other threads waiting for it.
                if (spin.yield()) {
                    queue = self.queue.load(.Monotonic);
                    continue;
                }

                // Try to tag the queue lock with PARKED.
                queue = self.queue.tryCompareAndSwap(
                    queue,
                    (queue & PTR_MASK) | PARKED,
                    .Monotonic,
                    .Monotonic,
                ) orelse break :blk;
                continue;
            }

            // Wait on the lower 32 bits of the Waiters queue lock.
            // This only changes if exclusive access is released (we should re-acquire)
            // Or if the PARKED bit was unset (we should set it back).
            Futex.wait(
                @ptrCast(*const Atomic(u32), &self.queue),
                @truncate(u32, (queue & PTR_MASK) | PARKED),
                null,
            ) catch unreachable;

            // Try to acquire the Waiters queue lock again (or sleep again).
            // Given we just woke up from sleeping, we should acquire with PARKED instead of WRITER.
            // This ensures that on release we wake up threads sleeping in Futex who didn't observe UNLOCKED.
            // This unfortunately reults in one extra Futex.wake() call for the last sleeping thread but it's fine.
            spin = .{};
            acquire_with = PARKED;
            queue = self.queue.load(.Monotonic);
        }
    }

    fn releaseWaitQueue(noalias self: *Impl, noalias waiter: ?*Waiter) void {
        // Release mutual exclusion of the Waiters queue lock
        // by updating the root pointer and setting the state to UNLOCKED.
        const new_state = @ptrToInt(waiter) | UNLOCKED;
        const old_state = self.state.swap(new_state, .Release);

        switch (old_state & STATE_MASK) {
            UNLOCKED => unreachable, // released when not acquired
            WRITER => {},
            PARKED => Futex.wake(@ptrCast(*const Atomic(u32), &self.state), 1),
            else => unreachable, // invalid MutexPtr state
        }
    }
};
