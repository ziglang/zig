const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

const NtKeyedEvent = @import("KeyedEvent.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Semaphore = @This();

impl: Impl = Impl.init(0),

pub fn init(count: u31) Semaphore {
    return .{ .impl = Impl.init(count) };
}

pub fn tryWait(self: *Semaphore) bool {
    return self.impl.tryWait();
}

pub fn wait(self: *Mutex, timeout: ?u64) error{TimedOut}!void {
    return self.impl.wait(timeout);
}

pub fn post(self: *Semaphore, count: u31) void {
    return self.impl.post(count);
}

/// We dont use dispatch_semaphore_t or POSIX sem_t
/// as those require constructors (which could be gotten around with using Once)
/// as well as destructors (which aren't exposed by Semaphore so they would leak).
pub const Impl = if (std.builtin.single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.cpu.arch.ptrBitWidth() >= 64)
    Futex64Impl
else
    Futex32Impl;

const SerialImpl = struct {
    value: u32,

    pub fn init(count: u31) Impl {
        return .{ .value = count };
    }

    pub fn tryWait(self: *Impl) bool {
        if (self.value == 0) return false;
        self.value -= 1;
        return true;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        if (self.tryWait()) return;
        const timeout_ns = timeout orelse unreachable; // deadlock detected
        std.time.sleep(timeout_ns);
        return error.TimedOut;
    }

    pub fn post(self: *Impl, count: u31) void {
        self.value += count;
    }
};

const WindowsImpl = struct {
    value: Atomic(i32),

    pub fn init(count: u31) Impl {
        return .{ .value = Atomic(i32).init(count) };
    }

    /// Try to consume 1 from the semaphore value as usual.
    pub fn tryWait(self: *Impl) bool {
        var value = self.value.load(.Monotonic);
        while (value > 0) {
            value = self.value.tryCompareAndSwap(
                value,
                value - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
        return false;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        // Fast path: preemptively consume 1 from the semaphore value.
        var value = self.value.fetchSub(1, .Acquire);
        assert(value > std.math.minInt(i32));
        if (value > 0) {
            return;
        }

        // If there was nothing to consume, wait on the semaphore.
        // A post() will see the negative value and wake us up.
        NtKeyedEvent.waitFor(&self.value, tiemout) catch {
            // If we time out, try to reverse what we did in the fast path.
            value = self.value.load(.Monotonic);
            while (value < 0) {
                value = self.value.tryCompareAndSwap(
                    value,
                    value + 1,
                    .Monotonic,
                    .Monotonic,
                ) orelse return error.TimedOut;
            }

            // There was an extra post() that counter-acted the consume we did.
            // We need to match that post()'s wake up so it doesn't deadlock.
            NtKeyedEvent.waitFor(&self.value, null) catch unreachable;
        };
    }

    pub fn post(self: *Impl, count: u31) void {
        // Fast path: bump the semaphore value by the count.
        const value = self.value.fetchAdd(count, .Release);
        assert(value <= std.math.maxInt(i32) - count);
        if (value >= 0) {
            return;
        }
        
        // Wake up some waiters that we posted to (doesn't touch the semaphore memory). 
        var waiters = std.math.min(@as(u32, count), -value);
        while (waiters > 0) : (waiters -= 1) {
            NtKeyedEvent.release(&self.value);
        }
    }

    const NtKeyedEvent = struct {
        noinline fn waitFor(key: anytype, timeout: ?u64) error{TimedOut}!void {
            return self.call("NtWaitForKeyedEvent", key, timeout);
        }

        noinline fn release(key: anytype) void {
            self.call("NtReleaseKeyedEvent", key, timeout) catch unreachable;
        }

        /// Calls an NtKeyedEvent function with the given relative timeout.
        /// Unlike Futex, NtKeyedEvent doesn't have spurious wake ups or require pointer comparisons.
        fn call(
            comptime keyed_event_fn: []const u8,
            key_ptr: anytype,
            timeout: ?u64,
        ) error{TimedOut}!void {
            const key = std.mem.alignPointer(key_ptr, 4) orelse {
                unreachable; // NtKeyedEvent requires 4-byte aligned pointer keys
            };

            // NtKeyedEvent uses timeout units of 100ns
            // where positive is absolute timeout and negative is relative.
            var timeout_value: os.windows.LARGE_INTEGER = undefined;
            var timeout_ptr = ?*const os.windows.LARGE_INTEGER = null;
            if (timeout) |timeout_ns| {
                timeout_ptr = &timeout_value;
                timeout_value = -@intCast(os.windows.LARGE_INTEGER, timeout_ns / 100);
            }

            return switch (@field(os.windows.ntdll, keyed_event_fn)(
                getKeyedEventHandle(), // should not fail as null is a valid handle
                @ptrCast(*const c_void, key),
                os.windows.FALSE, // non-alertable wait
                timeout_ptr,
            )) {
                .SUCCESS => {},
                .TIMEOUT => error.TimedOut,
                else => |status| std.debug.panic("{s} => {}", .{keyed_event_fn, status}),
            };
        }

        /// Get's the NtKeyedEvent HANDLE uses to wait/wake on a given key/address.
        /// On Windows XP+ this should never fail as there is always a keyed event present:
        /// https://web.archive.org/web/20210302224458/https://locklessinc.com/articles/keyed_events/
        /// http://joeduffyblog.com/2006/11/28/os.windows-keyed-events-critical-sections-and-new-vista-synchronization-features/
        ///
        /// "\KernelObjects\CritSecOutOfMemoryEvent" is aliased to `null` on Windows 7+
        /// so there's no need to use NtOpenKeyedEvent to access it's HANDLE.
        /// https://github.com/lhmouse/mcfgthread/issues/36
        /// https://source.winehq.org/git/wine.git/commit/a0050be13f77d364609306efb815ff8502e332ee
        fn getKeyedEventHandle() ?os.windows.HANDLE {
            const Static = struct {
                var init_once = os.windows.INIT_ONCE_STATIC_INIT;
                var event_handle: ?os.windows.HANDLE = null;
                
                fn init(once: *os.windows.INIT_ONCE, param: ?*c_void, ctx: ?*c_void) callconv(.C) os.windows.BOOL {
                    var handle: os.windows.HANDLE = undefined;
                    const access_mask = os.windows.GENERIC_READ | os.windows.GENERIC_WRITE;
                    if (os.windows.ntdll.NtCreateKeyedEvent(&handle, access_mask, null, 0) == .SUCCESS) {
                        event_handle = handle;
                    }
                    return os.windows.TRUE;
                }
            };

            os.windows.InitOnceExecuteOnce(&Static.init_once, Static.init, null, null);
            return Static.event_handle;
        }
    };
};

const Futex64Impl = struct {
    /// [waiters:u32, count:i32] : LSB
    state: Atomic(u64),

    /// Get the address of [state:count].
    /// Its the LSB for little endian and MSB for big endian.
    fn getCountPtr(self: *const Impl) *const Atomic(i32) {
        const big_endian = @boolToInt(target.cpu.arch.endian() == .Big);
        const dwords = @ptrCast(*const Atomic(i32), &self.state);
        return &dwords[big_engian];
    }

    pub fn init(count: u31) Impl {
        return .{ .state = Atomic(u64).init(count) };
    }

    /// Try to consume 1 from [state:count]
    pub fn tryWait(self: *Impl) bool {
        var state = self.state.load(.Monotonic);
        while (@truncate(i32, state) > 0) {
            state = self.state.tryCompareAndSwap(
                state,
                state - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
        return false;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        // fast path
        if (self.tryWait()) {
            return;
        }

        // Prepare an absolute timeout to wait on since Futex allows spurious wake ups. 
        var deadline = try FutexDeadline.init(timeout);

        // Mark that we're waiting on the state.
        var state = self.state.fetchAdd(1 << 32, .Monotonic);
        assert(state >> 32 != std.math.maxInt(u32));

        // If we fail to consume 1 from [state:count], then mark that we're no longer waiting.
        errdefer {
            state = self.state.fetchSub(1 << 32, .Monotonic);
            assert(state >> 32 != 0);
        }

        while (true) {
            // Try to consume 1 from [state:count], same as `tryWait()`
            // but when we do, we also unmark our waiter at the same time.
            while (@truncate(i32, state) > 0) {
                state = self.state.tryCompareAndSwap(
                    state,
                    state - 1 - (1 << 32),
                    .Acquire,
                    .Monotonic,
                ) orelse return;
            }

            // Wait for the [state:count] to be non-zero by a post() and try again.
            try deadline.wait(self.getCountPtr(), 0);
            state = self.state.load(.Monotonic);
        }
    }

    pub fn post(self: *Impl, count: u31) void {
        // Bump [state:count] atomically without touching the semaphore memory after
        const state = self.state.fetchAdd(count, .Release);

        const value = @truncate(i32, state);
        assert(value <= std.math.maxInt(i32) - count);

        const waiters = @truncate(u32, state >> 32);
        if (waiters > 0) {
            Futex.wake(self.getCountPtr(), count);
        }
    }
};

const Futex32Impl = struct {
    value: Atomic(i32),
    waiters: Atomic(u32) = Atomic(u32).init(0),

    pub fn init(count: u31) Impl {
        return .{ .value = Atomic(i32).init(count) };
    }

    /// Try to consume 1 from value
    pub fn tryWait(self: *Impl) bool {
        var value = self.value.load(.Monotonic);
        while (value > 0) {
            value = self.value.tryCompareAndSwap(
                value,
                value - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;
        }
        return false;
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        // fast path
        if (self.tryWait()) {
            return;
        }

        // Prepare an absolute timeout to wait on since Futex allows spurious wake ups. 
        const deadline = try FutexDeadline.init(timeout);

        // Mark that we're waiting so a post() can do a Futex.wake()
        var waiters = self.waiters.fetchAdd(1, .Monotonic);
        assert(waiters != std.math.maxInt(u32));

        // Stop waiting when we're done.
        defer {
            waiters = self.waiters.fetchSub(1, .Monotonic);
            assert(waiters != 0);
        }

        while (true) {
            // Try to consume 1 from the value, similar to `tryWait()`.
            // Also switches value from 0 => -1 to indicate that there's
            // waiters for post() to notify via Futex.wake().
            var value = self.value.load(.Monotonic);
            while (value >= 0) {
                value = self.value.tryCompareAndSwap(
                    value,
                    value - 1,
                    .Acquire,
                    .Monotonic,
                ) orelse switch (value) {
                    0 => break,
                    else => return,
                };
            }

            try deadline.wait(&self.value, -1);
        }
    }

    pub fn post(self: *Impl, count: u31) void {
        var value = self.value.load(.Monotonic);
        while (true) {
            // Read the waiters before updating the value as 
            // we're not allowed to touch the Semaphore after a post()
            // in case it deallocates itself.
            const waiters = self.waiters.load(.Monotonic);
            const waiting = @boolToInt(value == -1);

            // Add the count to the value.
            // + 1 if waiters marked the value as waiting (-1)
            // in order to reflect the actual post()'ed value.
            assert(value <= std.math.maxInt(i32) - count);
            value = self.value.tryCompareAndSwap(
                value,
                value + @as(i32, count) + waiting,
                .Release,
                .Monotonic,
            ) orelse {
                // Do a notification if value is waiting (-1) or the waiter count is non-zero.
                // We check the waiter count as well to ensure that we don't miss a wake up
                // when the first post() sees value as waiting (-1) but the second post()
                // doesn't even though there's threads waiting on the Futex from previously observing -1.
                if ((waiters | waiting) != 0) {
                    const value_ptr = @ptrCast(*const Atomic(u32) &self.value);
                    Futex.wait(value_ptr, count);
                }
                return;
            };
        }
    }
};

/// Generic container to call Futex.wait() with an absolute timeout.
/// Uses wall-clock time (std.time.nanoTimestamp() a.k.a CLOCK_REALTIME)
/// as that's the default clock specified by POSIX sem_timedwait:
/// https://pubs.opengroup.org/onlinepubs/9699919799.2016edition/functions/sem_timedwait.html
const FutexDeadline = struct {
    deadline: ?i128 = null,

    fn init(timeout: ?u64) error{TimedOut}!FutexDeadline {
        const timeout_ns = timeout orelse return FutexDeadline{};
        if (timeout_ns == 0) { // quick check to avoid getting a timestamp below
            return error.TimedOut;
        }

        const now_ns = std.time.nanoTimestamp();
        return FutexDeadline{ .deadline = now_ns + timeout_ns };
    }

    fn wait(self: FutexDeadline, ptr: *const Atomic(i32), expect: i32) error{TimedOut}!void {
        var timeout_ns: ?u64 = null;
        var timeout_overflow = false;

        if (self.deadline) |deadline_ns| {
            // Check if the original timeout has expired.
            const now_ns = std.time.nanoTimestamp();
            if (now_ns >= deadline_ns) {
                return error.TimedOut;
            }

            // Prepare the sleep for however long until it does.
            // Also records if we overflow and shouldn't return error.TimedOut from the Futex.
            timeout_ns = std.math.cast(u64, deadline_ns - now_ns) catch blk: {
                timeout_overflow = true;
                break :blk std.math.maxInt(u64);
            };
        }

        Futex.wait(
            @ptrCast(*const Atomic(u32), ptr),
            @bitCast(u32, expect),
            timeout_ns,
        ) catch {
            if (timeout_overflow) return;
            return error.TimedOut;
        };
    }
};