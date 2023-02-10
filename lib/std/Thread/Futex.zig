//! Futex is a mechanism used to block (`wait`) and unblock (`wake`) threads using a 32bit memory address as hints.
//! Blocking a thread is acknowledged only if the 32bit memory address is equal to a given value.
//! This check helps avoid block/unblock deadlocks which occur if a `wake()` happens before a `wait()`.
//! Using Futex, other Thread synchronization primitives can be built which efficiently wait for cross-thread events or signals.

const std = @import("../std.zig");
const builtin = @import("builtin");
const Futex = @This();

const os = std.os;
const assert = std.debug.assert;
const testing = std.testing;
const Atomic = std.atomic.Atomic;

/// Checks if `ptr` still contains the value `expect` and, if so, blocks the caller until either:
/// - The value at `ptr` is no longer equal to `expect`.
/// - The caller is unblocked by a matching `wake()`.
/// - The caller is unblocked spuriously ("at random").
///
/// The checking of `ptr` and `expect`, along with blocking the caller, is done atomically
/// and totally ordered (sequentially consistent) with respect to other wait()/wake() calls on the same `ptr`.
pub fn wait(ptr: *const Atomic(u32), expect: u32) void {
    @setCold(true);

    Impl.wait(ptr, expect, null) catch |err| switch (err) {
        error.Timeout => unreachable, // null timeout meant to wait forever
    };
}

/// Checks if `ptr` still contains the value `expect` and, if so, blocks the caller until either:
/// - The value at `ptr` is no longer equal to `expect`.
/// - The caller is unblocked by a matching `wake()`.
/// - The caller is unblocked spuriously ("at random").
/// - The caller blocks for longer than the given timeout. In which case, `error.Timeout` is returned.
///
/// The checking of `ptr` and `expect`, along with blocking the caller, is done atomically
/// and totally ordered (sequentially consistent) with respect to other wait()/wake() calls on the same `ptr`.
pub fn timedWait(ptr: *const Atomic(u32), expect: u32, timeout_ns: u64) error{Timeout}!void {
    @setCold(true);

    // Avoid calling into the OS for no-op timeouts.
    if (timeout_ns == 0) {
        if (ptr.load(.SeqCst) != expect) return;
        return error.Timeout;
    }

    return Impl.wait(ptr, expect, timeout_ns);
}

/// Unblocks at most `max_waiters` callers blocked in a `wait()` call on `ptr`.
pub fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
    @setCold(true);

    // Avoid calling into the OS if there's nothing to wake up.
    if (max_waiters == 0) {
        return;
    }

    Impl.wake(ptr, max_waiters);
}

const Impl = if (builtin.single_threaded)
    SingleThreadedImpl
else if (builtin.os.tag == .windows)
    WindowsImpl
else if (builtin.os.tag.isDarwin())
    DarwinImpl
else if (builtin.os.tag == .linux)
    LinuxImpl
else if (builtin.os.tag == .freebsd)
    FreebsdImpl
else if (builtin.os.tag == .openbsd)
    OpenbsdImpl
else if (builtin.os.tag == .dragonfly)
    DragonflyImpl
else if (std.Thread.use_pthreads)
    PosixImpl
else
    UnsupportedImpl;

/// We can't do @compileError() in the `Impl` switch statement above as its eagerly evaluated.
/// So instead, we @compileError() on the methods themselves for platforms which don't support futex.
const UnsupportedImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        return unsupported(.{ ptr, expect, timeout });
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        return unsupported(.{ ptr, max_waiters });
    }

    fn unsupported(unused: anytype) noreturn {
        _ = unused;
        @compileError("Unsupported operating system " ++ @tagName(builtin.target.os.tag));
    }
};

const SingleThreadedImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        if (ptr.loadUnchecked() != expect) {
            return;
        }

        // There are no threads to wake us up.
        // So if we wait without a timeout we would never wake up.
        const delay = timeout orelse {
            unreachable; // deadlock detected
        };

        std.time.sleep(delay);
        return error.Timeout;
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        // There are no other threads to possibly wake up
        _ = ptr;
        _ = max_waiters;
    }
};

// We use WaitOnAddress through NtDll instead of API-MS-Win-Core-Synch-l1-2-0.dll
// as it's generally already a linked target and is autoloaded into all processes anyway.
const WindowsImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        var timeout_value: os.windows.LARGE_INTEGER = undefined;
        var timeout_ptr: ?*const os.windows.LARGE_INTEGER = null;

        // NTDLL functions work with time in units of 100 nanoseconds.
        // Positive values are absolute deadlines while negative values are relative durations.
        if (timeout) |delay| {
            timeout_value = @intCast(os.windows.LARGE_INTEGER, delay / 100);
            timeout_value = -timeout_value;
            timeout_ptr = &timeout_value;
        }

        const rc = os.windows.ntdll.RtlWaitOnAddress(
            @ptrCast(?*const anyopaque, ptr),
            @ptrCast(?*const anyopaque, &expect),
            @sizeOf(@TypeOf(expect)),
            timeout_ptr,
        );

        switch (rc) {
            .SUCCESS => {},
            .TIMEOUT => {
                assert(timeout != null);
                return error.Timeout;
            },
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        const address = @ptrCast(?*const anyopaque, ptr);
        assert(max_waiters != 0);

        switch (max_waiters) {
            1 => os.windows.ntdll.RtlWakeAddressSingle(address),
            else => os.windows.ntdll.RtlWakeAddressAll(address),
        }
    }
};

const DarwinImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        // Darwin XNU 7195.50.7.100.1 introduced __ulock_wait2 and migrated code paths (notably pthread_cond_t) towards it:
        // https://github.com/apple/darwin-xnu/commit/d4061fb0260b3ed486147341b72468f836ed6c8f#diff-08f993cc40af475663274687b7c326cc6c3031e0db3ac8de7b24624610616be6
        //
        // This XNU version appears to correspond to 11.0.1:
        // https://kernelshaman.blogspot.com/2021/01/building-xnu-for-macos-big-sur-1101.html
        //
        // ulock_wait() uses 32-bit micro-second timeouts where 0 = INFINITE or no-timeout
        // ulock_wait2() uses 64-bit nano-second timeouts (with the same convention)
        const supports_ulock_wait2 = builtin.target.os.version_range.semver.min.major >= 11;

        var timeout_ns: u64 = 0;
        if (timeout) |delay| {
            assert(delay != 0); // handled by timedWait()
            timeout_ns = delay;
        }

        // If we're using `__ulock_wait` and `timeout` is too big to fit inside a `u32` count of
        // micro-seconds (around 70min), we'll request a shorter timeout. This is fine (users
        // should handle spurious wakeups), but we need to remember that we did so, so that
        // we don't return `Timeout` incorrectly. If that happens, we set this variable to
        // true so that we we know to ignore the ETIMEDOUT result.
        var timeout_overflowed = false;

        const addr = @ptrCast(*const anyopaque, ptr);
        const flags = os.darwin.UL_COMPARE_AND_WAIT | os.darwin.ULF_NO_ERRNO;
        const status = blk: {
            if (supports_ulock_wait2) {
                break :blk os.darwin.__ulock_wait2(flags, addr, expect, timeout_ns, 0);
            }

            const timeout_us = std.math.cast(u32, timeout_ns / std.time.ns_per_us) orelse overflow: {
                timeout_overflowed = true;
                break :overflow std.math.maxInt(u32);
            };

            break :blk os.darwin.__ulock_wait(flags, addr, expect, timeout_us);
        };

        if (status >= 0) return;
        switch (@intToEnum(std.os.E, -status)) {
            // Wait was interrupted by the OS or other spurious signalling.
            .INTR => {},
            // Address of the futex was paged out. This is unlikely, but possible in theory, and
            // pthread/libdispatch on darwin bother to handle it. In this case we'll return
            // without waiting, but the caller should retry anyway.
            .FAULT => {},
            // Only report Timeout if we didn't have to cap the timeout
            .TIMEDOUT => {
                assert(timeout != null);
                if (!timeout_overflowed) return error.Timeout;
            },
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        var flags: u32 = os.darwin.UL_COMPARE_AND_WAIT | os.darwin.ULF_NO_ERRNO;
        if (max_waiters > 1) {
            flags |= os.darwin.ULF_WAKE_ALL;
        }

        while (true) {
            const addr = @ptrCast(*const anyopaque, ptr);
            const status = os.darwin.__ulock_wake(flags, addr, 0);

            if (status >= 0) return;
            switch (@intToEnum(std.os.E, -status)) {
                .INTR => continue, // spurious wake()
                .FAULT => unreachable, // __ulock_wake doesn't generate EFAULT according to darwin pthread_cond_t
                .NOENT => return, // nothing was woken up
                .ALREADY => unreachable, // only for ULF_WAKE_THREAD
                else => unreachable,
            }
        }
    }
};

// https://man7.org/linux/man-pages/man2/futex.2.html
const LinuxImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        var ts: os.timespec = undefined;
        if (timeout) |timeout_ns| {
            ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
            ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
        }

        const rc = os.linux.futex_wait(
            @ptrCast(*const i32, &ptr.value),
            os.linux.FUTEX.PRIVATE_FLAG | os.linux.FUTEX.WAIT,
            @bitCast(i32, expect),
            if (timeout != null) &ts else null,
        );

        switch (os.linux.getErrno(rc)) {
            .SUCCESS => {}, // notified by `wake()`
            .INTR => {}, // spurious wakeup
            .AGAIN => {}, // ptr.* != expect
            .TIMEDOUT => {
                assert(timeout != null);
                return error.Timeout;
            },
            .INVAL => {}, // possibly timeout overflow
            .FAULT => unreachable, // ptr was invalid
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        const rc = os.linux.futex_wake(
            @ptrCast(*const i32, &ptr.value),
            os.linux.FUTEX.PRIVATE_FLAG | os.linux.FUTEX.WAKE,
            std.math.cast(i32, max_waiters) orelse std.math.maxInt(i32),
        );

        switch (os.linux.getErrno(rc)) {
            .SUCCESS => {}, // successful wake up
            .INVAL => {}, // invalid futex_wait() on ptr done elsewhere
            .FAULT => {}, // pointer became invalid while doing the wake
            else => unreachable,
        }
    }
};

// https://www.freebsd.org/cgi/man.cgi?query=_umtx_op&sektion=2&n=1
const FreebsdImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        var tm_size: usize = 0;
        var tm: os.freebsd._umtx_time = undefined;
        var tm_ptr: ?*const os.freebsd._umtx_time = null;

        if (timeout) |timeout_ns| {
            tm_ptr = &tm;
            tm_size = @sizeOf(@TypeOf(tm));

            tm._flags = 0; // use relative time not UMTX_ABSTIME
            tm._clockid = os.CLOCK.MONOTONIC;
            tm._timeout.tv_sec = @intCast(@TypeOf(tm._timeout.tv_sec), timeout_ns / std.time.ns_per_s);
            tm._timeout.tv_nsec = @intCast(@TypeOf(tm._timeout.tv_nsec), timeout_ns % std.time.ns_per_s);
        }

        const rc = os.freebsd._umtx_op(
            @ptrToInt(&ptr.value),
            @enumToInt(os.freebsd.UMTX_OP.WAIT_UINT_PRIVATE),
            @as(c_ulong, expect),
            tm_size,
            @ptrToInt(tm_ptr),
        );

        switch (os.errno(rc)) {
            .SUCCESS => {},
            .FAULT => unreachable, // one of the args points to invalid memory
            .INVAL => unreachable, // arguments should be correct
            .TIMEDOUT => {
                assert(timeout != null);
                return error.Timeout;
            },
            .INTR => {}, // spurious wake
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        const rc = os.freebsd._umtx_op(
            @ptrToInt(&ptr.value),
            @enumToInt(os.freebsd.UMTX_OP.WAKE_PRIVATE),
            @as(c_ulong, max_waiters),
            0, // there is no timeout struct
            0, // there is no timeout struct pointer
        );

        switch (os.errno(rc)) {
            .SUCCESS => {},
            .FAULT => {}, // it's ok if the ptr doesn't point to valid memory
            .INVAL => unreachable, // arguments should be correct
            else => unreachable,
        }
    }
};

// https://man.openbsd.org/futex.2
const OpenbsdImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        var ts: os.timespec = undefined;
        if (timeout) |timeout_ns| {
            ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
            ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
        }

        const rc = os.openbsd.futex(
            @ptrCast(*const volatile u32, &ptr.value),
            os.openbsd.FUTEX_WAIT | os.openbsd.FUTEX_PRIVATE_FLAG,
            @bitCast(c_int, expect),
            if (timeout != null) &ts else null,
            null, // FUTEX_WAIT takes no requeue address
        );

        switch (os.errno(rc)) {
            .SUCCESS => {}, // woken up by wake
            .NOSYS => unreachable, // the futex operation shouldn't be invalid
            .FAULT => unreachable, // ptr was invalid
            .AGAIN => {}, // ptr != expect
            .INVAL => unreachable, // invalid timeout
            .TIMEDOUT => {
                assert(timeout != null);
                return error.Timeout;
            },
            .INTR => {}, // spurious wake from signal
            .CANCELED => {}, // spurious wake from signal with SA_RESTART
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        const rc = os.openbsd.futex(
            @ptrCast(*const volatile u32, &ptr.value),
            os.openbsd.FUTEX_WAKE | os.openbsd.FUTEX_PRIVATE_FLAG,
            std.math.cast(c_int, max_waiters) orelse std.math.maxInt(c_int),
            null, // FUTEX_WAKE takes no timeout ptr
            null, // FUTEX_WAKE takes no requeue address
        );

        // returns number of threads woken up.
        assert(rc >= 0);
    }
};

// https://man.dragonflybsd.org/?command=umtx&section=2
const DragonflyImpl = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        // Dragonfly uses a scheme where 0 timeout means wait until signaled or spurious wake.
        // It's reporting of timeout's is also unrealiable so we use an external timing source (Timer) instead.
        var timeout_us: c_int = 0;
        var timeout_overflowed = false;
        var sleep_timer: std.time.Timer = undefined;

        if (timeout) |delay| {
            assert(delay != 0); // handled by timedWait().
            timeout_us = std.math.cast(c_int, delay / std.time.ns_per_us) orelse blk: {
                timeout_overflowed = true;
                break :blk std.math.maxInt(c_int);
            };

            // Only need to record the start time if we can provide somewhat accurate error.Timeout's
            if (!timeout_overflowed) {
                sleep_timer = std.time.Timer.start() catch unreachable;
            }
        }

        const value = @bitCast(c_int, expect);
        const addr = @ptrCast(*const volatile c_int, &ptr.value);
        const rc = os.dragonfly.umtx_sleep(addr, value, timeout_us);

        switch (os.errno(rc)) {
            .SUCCESS => {},
            .BUSY => {}, // ptr != expect
            .AGAIN => { // maybe timed out, or paged out, or hit 2s kernel refresh
                if (timeout) |timeout_ns| {
                    // Report error.Timeout only if we know the timeout duration has passed.
                    // If not, there's not much choice other than treating it as a spurious wake.
                    if (!timeout_overflowed and sleep_timer.read() >= timeout_ns) {
                        return error.Timeout;
                    }
                }
            },
            .INTR => {}, // spurious wake
            .INVAL => unreachable, // invalid timeout
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        // A count of zero means wake all waiters.
        assert(max_waiters != 0);
        const to_wake = std.math.cast(c_int, max_waiters) orelse 0;

        // https://man.dragonflybsd.org/?command=umtx&section=2
        // > umtx_wakeup() will generally return 0 unless the address is bad.
        // We are fine with the address being bad (e.g. for Semaphore.post() where Semaphore.wait() frees the Semaphore)
        const addr = @ptrCast(*const volatile c_int, &ptr.value);
        _ = os.dragonfly.umtx_wakeup(addr, to_wake);
    }
};

/// Modified version of linux's futex and Go's sema to implement userspace wait queues with pthread:
/// https://code.woboq.org/linux/linux/kernel/futex.c.html
/// https://go.dev/src/runtime/sema.go
const PosixImpl = struct {
    const Event = struct {
        cond: std.c.pthread_cond_t,
        mutex: std.c.pthread_mutex_t,
        state: enum { empty, waiting, notified },

        fn init(self: *Event) void {
            // Use static init instead of pthread_cond/mutex_init() since this is generally faster.
            self.cond = .{};
            self.mutex = .{};
            self.state = .empty;
        }

        fn deinit(self: *Event) void {
            // Some platforms reportedly give EINVAL for statically initialized pthread types.
            const rc = std.c.pthread_cond_destroy(&self.cond);
            assert(rc == .SUCCESS or rc == .INVAL);

            const rm = std.c.pthread_mutex_destroy(&self.mutex);
            assert(rm == .SUCCESS or rm == .INVAL);

            self.* = undefined;
        }

        fn wait(self: *Event, timeout: ?u64) error{Timeout}!void {
            assert(std.c.pthread_mutex_lock(&self.mutex) == .SUCCESS);
            defer assert(std.c.pthread_mutex_unlock(&self.mutex) == .SUCCESS);

            // Early return if the event was already set.
            if (self.state == .notified) {
                return;
            }

            // Compute the absolute timeout if one was specified.
            // POSIX requires that REALTIME is used by default for the pthread timedwait functions.
            // This can be changed with pthread_condattr_setclock, but it's an extension and may not be available everywhere.
            var ts: os.timespec = undefined;
            if (timeout) |timeout_ns| {
                os.clock_gettime(os.CLOCK.REALTIME, &ts) catch unreachable;
                ts.tv_sec +|= @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
                ts.tv_nsec += @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);

                if (ts.tv_nsec >= std.time.ns_per_s) {
                    ts.tv_sec +|= 1;
                    ts.tv_nsec -= std.time.ns_per_s;
                }
            }

            // Start waiting on the event - there can be only one thread waiting.
            assert(self.state == .empty);
            self.state = .waiting;

            while (true) {
                // Block using either pthread_cond_wait or pthread_cond_timewait if there's an absolute timeout.
                const rc = blk: {
                    if (timeout == null) break :blk std.c.pthread_cond_wait(&self.cond, &self.mutex);
                    break :blk std.c.pthread_cond_timedwait(&self.cond, &self.mutex, &ts);
                };

                // After waking up, check if the event was set.
                if (self.state == .notified) {
                    return;
                }

                assert(self.state == .waiting);
                switch (rc) {
                    .SUCCESS => {},
                    .TIMEDOUT => {
                        // If timed out, reset the event to avoid the set() thread doing an unnecessary signal().
                        self.state = .empty;
                        return error.Timeout;
                    },
                    .INVAL => unreachable, // cond, mutex, and potentially ts should all be valid
                    .PERM => unreachable, // mutex is locked when cond_*wait() functions are called
                    else => unreachable,
                }
            }
        }

        fn set(self: *Event) void {
            assert(std.c.pthread_mutex_lock(&self.mutex) == .SUCCESS);
            defer assert(std.c.pthread_mutex_unlock(&self.mutex) == .SUCCESS);

            // Make sure that multiple calls to set() were not done on the same Event.
            const old_state = self.state;
            assert(old_state != .notified);

            // Mark the event as set and wake up the waiting thread if there was one.
            // This must be done while the mutex as the wait() thread could deallocate
            // the condition variable once it observes the new state, potentially causing a UAF if done unlocked.
            self.state = .notified;
            if (old_state == .waiting) {
                assert(std.c.pthread_cond_signal(&self.cond) == .SUCCESS);
            }
        }
    };

    const Treap = std.Treap(usize, std.math.order);
    const Waiter = struct {
        node: Treap.Node,
        prev: ?*Waiter,
        next: ?*Waiter,
        tail: ?*Waiter,
        is_queued: bool,
        event: Event,
    };

    // An unordered set of Waiters
    const WaitList = struct {
        top: ?*Waiter = null,
        len: usize = 0,

        fn push(self: *WaitList, waiter: *Waiter) void {
            waiter.next = self.top;
            self.top = waiter;
            self.len += 1;
        }

        fn pop(self: *WaitList) ?*Waiter {
            const waiter = self.top orelse return null;
            self.top = waiter.next;
            self.len -= 1;
            return waiter;
        }
    };

    const WaitQueue = struct {
        fn insert(treap: *Treap, address: usize, waiter: *Waiter) void {
            // prepare the waiter to be inserted.
            waiter.next = null;
            waiter.is_queued = true;

            // Find the wait queue entry associated with the address.
            // If there isn't a wait queue on the address, this waiter creates the queue.
            var entry = treap.getEntryFor(address);
            const entry_node = entry.node orelse {
                waiter.prev = null;
                waiter.tail = waiter;
                entry.set(&waiter.node);
                return;
            };

            // There's a wait queue on the address; get the queue head and tail.
            const head = @fieldParentPtr(Waiter, "node", entry_node);
            const tail = head.tail orelse unreachable;

            // Push the waiter to the tail by replacing it and linking to the previous tail.
            head.tail = waiter;
            tail.next = waiter;
            waiter.prev = tail;
        }

        fn remove(treap: *Treap, address: usize, max_waiters: usize) WaitList {
            // Find the wait queue associated with this address and get the head/tail if any.
            var entry = treap.getEntryFor(address);
            var queue_head = if (entry.node) |node| @fieldParentPtr(Waiter, "node", node) else null;
            const queue_tail = if (queue_head) |head| head.tail else null;

            // Once we're done updating the head, fix it's tail pointer and update the treap's queue head as well.
            defer entry.set(blk: {
                const new_head = queue_head orelse break :blk null;
                new_head.tail = queue_tail;
                break :blk &new_head.node;
            });

            var removed = WaitList{};
            while (removed.len < max_waiters) {
                // dequeue and collect waiters from their wait queue.
                const waiter = queue_head orelse break;
                queue_head = waiter.next;
                removed.push(waiter);

                // When dequeueing, we must mark is_queued as false.
                // This ensures that a waiter which calls tryRemove() returns false.
                assert(waiter.is_queued);
                waiter.is_queued = false;
            }

            return removed;
        }

        fn tryRemove(treap: *Treap, address: usize, waiter: *Waiter) bool {
            if (!waiter.is_queued) {
                return false;
            }

            queue_remove: {
                // Find the wait queue associated with the address.
                var entry = blk: {
                    // A waiter without a previous link means it's the queue head that's in the treap so we can avoid lookup.
                    if (waiter.prev == null) {
                        assert(waiter.node.key == address);
                        break :blk treap.getEntryForExisting(&waiter.node);
                    }
                    break :blk treap.getEntryFor(address);
                };

                // The queue head and tail must exist if we're removing a queued waiter.
                const head = @fieldParentPtr(Waiter, "node", entry.node orelse unreachable);
                const tail = head.tail orelse unreachable;

                // A waiter with a previous link is never the head of the queue.
                if (waiter.prev) |prev| {
                    assert(waiter != head);
                    prev.next = waiter.next;

                    // A waiter with both a previous and next link is in the middle.
                    // We only need to update the surrounding waiter's links to remove it.
                    if (waiter.next) |next| {
                        assert(waiter != tail);
                        next.prev = waiter.prev;
                        break :queue_remove;
                    }

                    // A waiter with a previous but no next link means it's the tail of the queue.
                    // In that case, we need to update the head's tail reference.
                    assert(waiter == tail);
                    head.tail = waiter.prev;
                    break :queue_remove;
                }

                // A waiter with no previous link means it's the queue head of queue.
                // We must replace (or remove) the head waiter reference in the treap.
                assert(waiter == head);
                entry.set(blk: {
                    const new_head = waiter.next orelse break :blk null;
                    new_head.tail = head.tail;
                    break :blk &new_head.node;
                });
            }

            // Mark the waiter as successfully removed.
            waiter.is_queued = false;
            return true;
        }
    };

    const Bucket = struct {
        mutex: std.c.pthread_mutex_t align(std.atomic.cache_line) = .{},
        pending: Atomic(usize) = Atomic(usize).init(0),
        treap: Treap = .{},

        // Global array of buckets that addresses map to.
        // Bucket array size is pretty much arbitrary here, but it must be a power of two for fibonacci hashing.
        var buckets = [_]Bucket{.{}} ** @bitSizeOf(usize);

        // https://github.com/Amanieu/parking_lot/blob/1cf12744d097233316afa6c8b7d37389e4211756/core/src/parking_lot.rs#L343-L353
        fn from(address: usize) *Bucket {
            // The upper `@bitSizeOf(usize)` bits of the fibonacci golden ratio.
            // Hashing this via (h * k) >> (64 - b) where k=golden-ration and b=bitsize-of-array
            // evenly lays out h=hash values over the bit range even when the hash has poor entropy (identity-hash for pointers).
            const max_multiplier_bits = @bitSizeOf(usize);
            const fibonacci_multiplier = 0x9E3779B97F4A7C15 >> (64 - max_multiplier_bits);

            const max_bucket_bits = @ctz(buckets.len);
            comptime assert(std.math.isPowerOfTwo(buckets.len));

            const index = (address *% fibonacci_multiplier) >> (max_multiplier_bits - max_bucket_bits);
            return &buckets[index];
        }
    };

    const Address = struct {
        fn from(ptr: *const Atomic(u32)) usize {
            // Get the alignment of the pointer.
            const alignment = @alignOf(Atomic(u32));
            comptime assert(std.math.isPowerOfTwo(alignment));

            // Make sure the pointer is aligned,
            // then cut off the zero bits from the alignment to get the unique address.
            const addr = @ptrToInt(ptr);
            assert(addr & (alignment - 1) == 0);
            return addr >> @ctz(@as(usize, alignment));
        }
    };

    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{Timeout}!void {
        const address = Address.from(ptr);
        const bucket = Bucket.from(address);

        // Announce that there's a waiter in the bucket before checking the ptr/expect condition.
        // If the announcement is reordered after the ptr check, the waiter could deadlock:
        //
        // - T1: checks ptr == expect which is true
        // - T2: updates ptr to != expect
        // - T2: does Futex.wake(), sees no pending waiters, exits
        // - T1: bumps pending waiters (was reordered after the ptr == expect check)
        // - T1: goes to sleep and misses both the ptr change and T2's wake up
        //
        // SeqCst as Acquire barrier to ensure the announcement happens before the ptr check below.
        // SeqCst as shared modification order to form a happens-before edge with the fence(.SeqCst)+load() in wake().
        var pending = bucket.pending.fetchAdd(1, .SeqCst);
        assert(pending < std.math.maxInt(usize));

        // If the wait gets cancelled, remove the pending count we previously added.
        // This is done outside the mutex lock to keep the critical section short in case of contention.
        var cancelled = false;
        defer if (cancelled) {
            pending = bucket.pending.fetchSub(1, .Monotonic);
            assert(pending > 0);
        };

        var waiter: Waiter = undefined;
        {
            assert(std.c.pthread_mutex_lock(&bucket.mutex) == .SUCCESS);
            defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == .SUCCESS);

            cancelled = ptr.load(.Monotonic) != expect;
            if (cancelled) {
                return;
            }

            waiter.event.init();
            WaitQueue.insert(&bucket.treap, address, &waiter);
        }

        defer {
            assert(!waiter.is_queued);
            waiter.event.deinit();
        }

        waiter.event.wait(timeout) catch {
            // If we fail to cancel after a timeout, it means a wake() thread dequeued us and will wake us up.
            // We must wait until the event is set as that's a signal that the wake() thread wont access the waiter memory anymore.
            // If we return early without waiting, the waiter on the stack would be invalidated and the wake() thread risks a UAF.
            defer if (!cancelled) waiter.event.wait(null) catch unreachable;

            assert(std.c.pthread_mutex_lock(&bucket.mutex) == .SUCCESS);
            defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == .SUCCESS);

            cancelled = WaitQueue.tryRemove(&bucket.treap, address, &waiter);
            if (cancelled) {
                return error.Timeout;
            }
        };
    }

    fn wake(ptr: *const Atomic(u32), max_waiters: u32) void {
        const address = Address.from(ptr);
        const bucket = Bucket.from(address);

        // Quick check if there's even anything to wake up.
        // The change to the ptr's value must happen before we check for pending waiters.
        // If not, the wake() thread could miss a sleeping waiter and have it deadlock:
        //
        // - T2: p = has pending waiters (reordered before the ptr update)
        // - T1: bump pending waiters
        // - T1: if ptr == expected: sleep()
        // - T2: update ptr != expected
        // - T2: p is false from earlier so doesn't wake (T1 missed ptr update and T2 missed T1 sleeping)
        //
        // What we really want here is a Release load, but that doesn't exist under the C11 memory model.
        // We could instead do `bucket.pending.fetchAdd(0, Release) == 0` which achieves effectively the same thing,
        // but the RMW operation unconditionally marks the cache-line as modified for others causing unnecessary fetching/contention.
        //
        // Instead we opt to do a full-fence + load instead which avoids taking ownership of the cache-line.
        // fence(SeqCst) effectively converts the ptr update to SeqCst and the pending load to SeqCst: creating a Store-Load barrier.
        //
        // The pending count increment in wait() must also now use SeqCst for the update + this pending load
        // to be in the same modification order as our load isn't using Release/Acquire to guarantee it.
        bucket.pending.fence(.SeqCst);
        if (bucket.pending.load(.Monotonic) == 0) {
            return;
        }

        // Keep a list of all the waiters notified and wake then up outside the mutex critical section.
        var notified = WaitList{};
        defer if (notified.len > 0) {
            const pending = bucket.pending.fetchSub(notified.len, .Monotonic);
            assert(pending >= notified.len);

            while (notified.pop()) |waiter| {
                assert(!waiter.is_queued);
                waiter.event.set();
            }
        };

        assert(std.c.pthread_mutex_lock(&bucket.mutex) == .SUCCESS);
        defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == .SUCCESS);

        // Another pending check again to avoid the WaitQueue lookup if not necessary.
        if (bucket.pending.load(.Monotonic) > 0) {
            notified = WaitQueue.remove(&bucket.treap, address, max_waiters);
        }
    }
};

test "Futex - smoke test" {
    var value = Atomic(u32).init(0);

    // Try waits with invalid values.
    Futex.wait(&value, 0xdeadbeef);
    Futex.timedWait(&value, 0xdeadbeef, 0) catch {};

    // Try timeout waits.
    try testing.expectError(error.Timeout, Futex.timedWait(&value, 0, 0));
    try testing.expectError(error.Timeout, Futex.timedWait(&value, 0, std.time.ns_per_ms));

    // Try wakes
    Futex.wake(&value, 0);
    Futex.wake(&value, 1);
    Futex.wake(&value, std.math.maxInt(u32));
}

test "Futex - signaling" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 4;
    const num_iterations = 4;

    const Paddle = struct {
        value: Atomic(u32) = Atomic(u32).init(0),
        current: u32 = 0,

        fn hit(self: *@This()) void {
            _ = self.value.fetchAdd(1, .Release);
            Futex.wake(&self.value, 1);
        }

        fn run(self: *@This(), hit_to: *@This()) !void {
            while (self.current < num_iterations) {
                // Wait for the value to change from hit()
                var new_value: u32 = undefined;
                while (true) {
                    new_value = self.value.load(.Acquire);
                    if (new_value != self.current) break;
                    Futex.wait(&self.value, self.current);
                }

                // change the internal "current" value
                try testing.expectEqual(new_value, self.current + 1);
                self.current = new_value;

                // hit the next paddle
                hit_to.hit();
            }
        }
    };

    var paddles = [_]Paddle{.{}} ** num_threads;
    var threads = [_]std.Thread{undefined} ** num_threads;

    // Create a circle of paddles which hit each other
    for (threads) |*t, i| {
        const paddle = &paddles[i];
        const hit_to = &paddles[(i + 1) % paddles.len];
        t.* = try std.Thread.spawn(.{}, Paddle.run, .{ paddle, hit_to });
    }

    // Hit the first paddle and wait for them all to complete by hitting each other for num_iterations.
    paddles[0].hit();
    for (threads) |t| t.join();
    for (paddles) |p| try testing.expectEqual(p.current, num_iterations);
}

test "Futex - broadcasting" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 4;
    const num_iterations = 4;

    const Barrier = struct {
        count: Atomic(u32) = Atomic(u32).init(num_threads),
        futex: Atomic(u32) = Atomic(u32).init(0),

        fn wait(self: *@This()) !void {
            // Decrement the counter.
            // Release ensures stuff before this barrier.wait() happens before the last one.
            const count = self.count.fetchSub(1, .Release);
            try testing.expect(count <= num_threads);
            try testing.expect(count > 0);

            // First counter to reach zero wakes all other threads.
            // Acquire for the last counter ensures stuff before previous barrier.wait()s happened before it.
            // Release on futex update ensures stuff before all barrier.wait()'s happens before they all return.
            if (count - 1 == 0) {
                _ = self.count.load(.Acquire); // TODO: could be fence(Acquire) if not for TSAN
                self.futex.store(1, .Release);
                Futex.wake(&self.futex, num_threads - 1);
                return;
            }

            // Other threads wait until last counter wakes them up.
            // Acquire on futex synchronizes with last barrier count to ensure stuff before all barrier.wait()'s happen before us.
            while (self.futex.load(.Acquire) == 0) {
                Futex.wait(&self.futex, 0);
            }
        }
    };

    const Broadcast = struct {
        barriers: [num_iterations]Barrier = [_]Barrier{.{}} ** num_iterations,
        threads: [num_threads]std.Thread = undefined,

        fn run(self: *@This()) !void {
            for (self.barriers) |*barrier| {
                try barrier.wait();
            }
        }
    };

    var broadcast = Broadcast{};
    for (broadcast.threads) |*t| t.* = try std.Thread.spawn(.{}, Broadcast.run, .{&broadcast});
    for (broadcast.threads) |t| t.join();
}

/// Deadline is used to wait efficiently for a pointer's value to change using Futex and a fixed timeout.
///
/// Futex's timedWait() api uses a relative duration which suffers from over-waiting
/// when used in a loop which is often required due to the possibility of spurious wakeups.
///
/// Deadline instead converts the relative timeout to an absolute one so that multiple calls
/// to Futex timedWait() can block for and report more accurate error.Timeouts.
pub const Deadline = struct {
    timeout: ?u64,
    started: std.time.Timer,

    /// Create the deadline to expire after the given amount of time in nanoseconds passes.
    /// Pass in `null` to have the deadline call `Futex.wait()` and never expire.
    pub fn init(expires_in_ns: ?u64) Deadline {
        var deadline: Deadline = undefined;
        deadline.timeout = expires_in_ns;

        // std.time.Timer is required to be supported for somewhat accurate reportings of error.Timeout.
        if (deadline.timeout != null) {
            deadline.started = std.time.Timer.start() catch unreachable;
        }

        return deadline;
    }

    /// Wait until either:
    /// - the `ptr`'s value changes from `expect`.
    /// - `Futex.wake()` is called on the `ptr`.
    /// - A spurious wake occurs.
    /// - The deadline expires; In which case `error.Timeout` is returned.
    pub fn wait(self: *Deadline, ptr: *const Atomic(u32), expect: u32) error{Timeout}!void {
        @setCold(true);

        // Check if we actually have a timeout to wait until.
        // If not just wait "forever".
        const timeout_ns = self.timeout orelse {
            return Futex.wait(ptr, expect);
        };

        // Get how much time has passed since we started waiting
        // then subtract that from the init() timeout to get how much longer to wait.
        // Use overflow to detect when we've been waiting longer than the init() timeout.
        const elapsed_ns = self.started.read();
        const until_timeout_ns = std.math.sub(u64, timeout_ns, elapsed_ns) catch 0;
        return Futex.timedWait(ptr, expect, until_timeout_ns);
    }
};

test "Futex - Deadline" {
    var deadline = Deadline.init(100 * std.time.ns_per_ms);
    var futex_word = Atomic(u32).init(0);

    while (true) {
        deadline.wait(&futex_word, 0) catch break;
    }
}
