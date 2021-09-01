const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

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

/// Modified implementation of dispatch_semaphore_t but for Windows.
/// https://github.com/apple/swift-corelibs-libdispatch/blob/main/src/semaphore.c 
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
        const value = self.value.fetchSub(1, .Acquire);
        assert(value > std.math.minInt(i32));
        if (value <= 0) {
            return self.waitSlow(timeout);
        }
    }

    noinline fn waitSlow(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        // If there was nothing to consume, wait on the semaphore.
        // A post() will see the negative value and wake us up.
        NtKeyedEvent.waitFor(&self.value, timeout) catch {
            // If we time out, try to reverse what we did in the fast path.
            var value = self.value.load(.Monotonic);
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
        if (value < 0) {
            self.postSlow(count, value);
        }
    }

    noinline fn postSlow(self: *Impl, count: u31, value: i32) void {
        // Wake up some waiters that we posted to (doesn't touch the semaphore memory).
        var waiters = std.math.min(@as(i32, count), -value);
        assert(waiters > 0);
        while (waiters > 0) : (waiters -= 1) {
            NtKeyedEvent.release(&self.value);
        }
    }

    const NtKeyedEvent = struct {
        fn waitFor(key: anytype, timeout: ?u64) error{TimedOut}!void {
            return self.call("NtWaitForKeyedEvent", key, timeout);
        }

        fn release(key: anytype) void {
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
            var timeout_ptr: ?*const os.windows.LARGE_INTEGER = null;
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
                else => |status| std.debug.panic("{s} => {}", .{ keyed_event_fn, status }),
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
                    _ = once;
                    _ = param;
                    _ = ctx;
                    
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

/// Slightly modified implementation of glibc's 64bit sem_t:
/// https://code.woboq.org/userspace/glibc/nptl/sem_post.c.html
/// https://code.woboq.org/userspace/glibc/nptl/sem_waitcommon.c.html
const Futex64Impl = struct {
    sema: extern union {
        qword: Atomic(u64),
        dword: State,
    },

    const State = extern struct {
        // The classic semaphore count (despite being signed, it doesn't become negative)
        count: Atomic(i32) = Atomic(i32).init(0),
        // The number of threads waiting on the semaphore
        waiters: u32 = 0,
    };

    pub fn init(count: u31) Impl {
        return .{ .sema = .{ .dword = .{ .count = Atomic(i32).init(count) } } };
    }

    pub fn tryWait(self: *Impl) bool {
        return self.waitFast(true);
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        if (!self.waitFast(false)) {
            return self.waitSlow(timeout);
        }
    }

    /// Tries to acquire the semaphore count.
    /// If `strong`, then retries when it fails spuriously.
    inline fn waitFast(self: *Impl, comptime strong: bool) bool {
        var sema = self.sema.qword.load(.Monotonic);
        while (true) {
            var state = @bitCast(State, sema);
            if (state.count.value == 0) {
                return false;
            }

            state.count.value -= 1;
            sema = self.sema.qword.tryCompareAndSwap(
                sema,
                @bitCast(u64, state),
                .Acquire,
                .Monotonic,
            ) orelse return true;

            if (!strong) {
                return false;
            }
        }
    }

    noinline fn waitSlow(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        const deadline = try FutexDeadline.init(timeout);

        // Register ourselves as a waiter on the semaphore
        const one_waiter = @bitCast(u64, State{ .waiters = 1 });
        var sema = self.sema.qword.fetchAdd(one_waiter, .Monotonic);
        assert(@bitCast(State, sema).waiters != std.math.maxInt(u32));

        // If we timed out and failed to acquire a semaphore value
        // then remove our waiter from the semaphore
        errdefer {
            sema = self.seam.qword.fetchSub(one_waiter, .Monotonic);
            assert(@bitCast(State, sema).waiters != 0);
        }

        while (true) {
            var state = @bitCast(State, sema);
            assert(state.waiters > 0);

            // No values to acquire, sleep on the semaphore value futex
            if (state.count.value == 0) {
                try deadline.wait(&self.sema.dword.count, 0);
                sema = self.sema.qword.load(.Monotonic);
                continue;
            }

            // Acquire a semaphore value by decrementing it
            // but also removing our waiter we registered before in the process.
            state.waiters -= 1;
            state.count.value -= 1;
            sema = self.sema.qword.tryCompareAndSwap(
                sema,
                @bitCast(u64, state),
                .Acquire,
                .Monotonic,
            ) orelse return;
        }
    }

    pub fn post(self: *Impl, count: u31) void {
        // Post the count to the semaphore value
        const count_state = @bitCast(u64, State{ .count = Atomic(i32).init(count) });
        const sema = self.sema.qword.fetchAdd(count_state, .Release);

        const state = @bitCast(State, sema);
        assert(state.count.value <= std.math.maxInt(i32) - count);

        // If there's waiters, wake some up to consume the posted count
        if (state.waiters > 0) {
            self.postSlow(count, state);
        }
    }

    noinline fn postSlow(self: *Impl, count: u31, state: State) void {
        return Futex.wake(
            @ptrCast(*const Atomic(u32), &self.sema.dword.count),
            std.math.min(state.waiters, count), // could just be count but this is more accurate
        );
    }
};

/// Slightly modified semaphore implementation from here:
/// https://softwareengineering.stackexchange.com/a/362533
const Futex32Impl = struct {
    value: Atomic(i32),
    waiters: Atomic(u32) = Atomic(u32).init(0),

    pub fn init(count: u31) Impl {
        return .{ .value = Atomic(i32).init(count) };
    }

    /// Try to consume 1 from value
    pub fn tryWait(self: *Impl) bool {
        return self.waitFast(true);
    }

    pub fn wait(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        if (!self.waitFast(false)) {
            return self.waitSlow(timeout);
        }
    }

    inline fn waitFast(self: *Impl, comptime strong: bool) bool {
        var value = self.value.load(.Monotonic);
        while (true) {
            if (value <= 0) {
                return false;
            }

            value = self.value.tryCompareAndSwap(
                value,
                value - 1,
                .Acquire,
                .Monotonic,
            ) orelse return true;

            if (!strong) {
                return false;
            }
        }
    }

    noinline fn waitSlow(self: *Impl, timeout: ?u64) error{TimedOut}!void {
        // Ensure that there's nothing to consume from the semaphore before waiting below.
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
                    const value_ptr = @ptrCast(*const Atomic(u32), &self.value);
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
