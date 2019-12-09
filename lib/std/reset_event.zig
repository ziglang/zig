const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const assert = std.debug.assert;
const Backoff = std.SpinLock.Backoff;
const c = std.c;
const os = std.os;
const time = std.time;
const linux = os.linux;
const windows = os.windows;

/// A resource object which supports blocking until signaled.
/// Once finished, the `deinit()` method should be called for correctness.
pub const ResetEvent = struct {
    os_event: OsEvent,

    pub fn init() ResetEvent {
        return ResetEvent{ .os_event = OsEvent.init() };
    }

    pub fn deinit(self: *ResetEvent) void {
        self.os_event.deinit();
        self.* = undefined;
    }

    /// Returns whether or not the event is currenetly set
    pub fn isSet(self: *ResetEvent) bool {
        return self.os_event.isSet();
    }

    /// Sets the event if not already set and
    /// wakes up AT LEAST one thread waiting the event.
    /// Returns whether or not a thread was woken up.
    pub fn set(self: *ResetEvent, auto_reset: bool) bool {
        return self.os_event.set(auto_reset);
    }

    /// Resets the event to its original, unset state.
    /// Returns whether or not the event was currently set before un-setting.
    pub fn reset(self: *ResetEvent) bool {
        return self.os_event.reset();
    }

    const WaitError = error{
        /// The thread blocked longer than the maximum time specified.
        TimedOut,
    };

    /// Wait for the event to be set by blocking the current thread.
    /// Optionally provided timeout in nanoseconds which throws an
    /// `error.TimedOut` if the thread blocked AT LEAST longer than specified.
    /// Returns whether or not the thread blocked from the event being unset at the time of calling.
    pub fn wait(self: *ResetEvent, timeout_ns: ?u64) WaitError!bool {
        return self.os_event.wait(timeout_ns);
    }
};

const OsEvent = if (builtin.single_threaded) DebugEvent else switch (builtin.os) {
    .windows => WindowsEvent,
    .linux => if (builtin.link_libc) PosixEvent else LinuxEvent,
    else => if (builtin.link_libc) PosixEvent else SpinEvent,
};

const DebugEvent = struct {
    is_set: @TypeOf(set_init),

    const set_init = if (std.debug.runtime_safety) false else {};

    pub fn init() DebugEvent {
        return DebugEvent{ .is_set = set_init };
    }

    pub fn deinit(self: *DebugEvent) void {
        self.* = undefined;
    }

    pub fn isSet(self: *DebugEvent) bool {
        if (!std.debug.runtime_safety)
            return true;
        return self.is_set;
    }

    pub fn set(self: *DebugEvent, auto_reset: bool) bool {
        if (std.debug.runtime_safety)
            self.is_set = !auto_reset;
        return false;
    }

    pub fn reset(self: *DebugEvent) bool {
        if (!std.debug.runtime_safety)
            return false;
        const was_set = self.is_set;
        self.is_set = false;
        return was_set;
    }

    pub fn wait(self: *DebugEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        if (std.debug.runtime_safety and !self.is_set)
            @panic("deadlock detected");
        return ResetEvent.WaitError.TimedOut;
    }
};

fn AtomicEvent(comptime FutexImpl: type) type {
    return struct {
        state: u32,

        const IS_SET: u32 = 1 << 0;
        const WAIT_MASK = ~IS_SET;

        pub const Self = @This();
        pub const Futex = FutexImpl;

        pub fn init() Self {
            return Self{ .state = 0 };
        }

        pub fn deinit(self: *Self) void {
            self.* = undefined;
        }

        pub fn isSet(self: *const Self) bool {
            const state = @atomicLoad(u32, &self.state, .Acquire);
            return (state & IS_SET) != 0;
        }

        pub fn reset(self: *Self) bool {
            const old_state = @atomicRmw(u32, &self.state, .Xchg, 0, .Monotonic);
            return (old_state & IS_SET) != 0;
        }

        pub fn set(self: *Self, auto_reset: bool) bool {
            const new_state = if (auto_reset) 0 else IS_SET;
            const old_state = @atomicRmw(u32, &self.state, .Xchg, new_state, .Release);
            if ((old_state & WAIT_MASK) == 0) {
                return false;
            }

            Futex.wake(&self.state);
            return true;
        }

        pub fn wait(self: *Self, timeout: ?u64) ResetEvent.WaitError!bool {
            var dummy_value: u32 = undefined;
            const wait_token = @truncate(u32, @ptrToInt(&dummy_value));

            var state = @atomicLoad(u32, &self.state, .Monotonic);
            while (true) {
                if ((state & IS_SET) != 0)
                    return false;
                state = @cmpxchgWeak(u32, &self.state, state, wait_token, .Acquire, .Monotonic) orelse break;
            }

            try Futex.wait(&self.state, wait_token, timeout);
            return true;
        }
    };
}

const SpinEvent = AtomicEvent(struct {
    fn wake(ptr: *const u32) void {}

    fn wait(ptr: *const u32, expected: u32, timeout: ?u64) ResetEvent.WaitError!void {
        // TODO: handle platforms where time.Timer.start() fails
        var spin = Backoff.init();
        var timer = if (timeout == null) null else time.Timer.start() catch unreachable;
        while (@atomicLoad(u32, ptr, .Acquire) == expected) {
            spin.yield();
            if (timeout) |timeout_ns| {
                if (timer.?.read() > timeout_ns)
                    return ResetEvent.WaitError.TimedOut;
            }
        }
    }
});

const LinuxEvent = AtomicEvent(struct {
    fn wake(ptr: *const u32) void {
        const key = @ptrCast(*const i32, ptr);
        const rc = linux.futex_wake(key, linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
        assert(linux.getErrno(rc) == 0);
    }

    fn wait(ptr: *const u32, expected: u32, timeout: ?u64) ResetEvent.WaitError!void {
        var ts: linux.timespec = undefined;
        var ts_ptr: ?*linux.timespec = null;
        if (timeout) |timeout_ns| {
            ts_ptr = &ts;
            ts.tv_sec = @intCast(isize, timeout_ns / time.ns_per_s);
            ts.tv_nsec = @intCast(isize, timeout_ns % time.ns_per_s);
        }

        const key = @ptrCast(*const i32, ptr);
        const key_expect = @bitCast(i32, expected);
        while (@atomicLoad(i32, key, .Acquire) == key_expect) {
            const rc = linux.futex_wait(key, linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, key_expect, ts_ptr);
            switch (linux.getErrno(rc)) {
                0, linux.EAGAIN => break,
                linux.EINTR => continue,
                linux.ETIMEDOUT => return ResetEvent.WaitError.TimedOut,
                else => unreachable,
            }
        }
    }
});

const WindowsEvent = AtomicEvent(struct {
    fn wake(ptr: *const u32) void {
        if (getEventHandle()) |handle| {
            const key = @ptrCast(*const c_void, ptr);
            const rc = windows.ntdll.NtReleaseKeyedEvent(handle, key, windows.FALSE, null);
            assert(rc == 0);
        }
    }

    fn wait(ptr: *const u32, expected: u32, timeout: ?u64) ResetEvent.WaitError!void {
        // fallback to spinlock if NT Keyed Events arent available
        const handle = getEventHandle() orelse {
            return SpinEvent.Futex.wait(ptr, expected, timeout);
        };

        // NT uses timeouts in units of 100ns with negative value being relative
        var timeout_ptr: ?*windows.LARGE_INTEGER = null;
        var timeout_value: windows.LARGE_INTEGER = undefined;
        if (timeout) |timeout_ns| {
            timeout_ptr = &timeout_value;
            timeout_value = -@intCast(windows.LARGE_INTEGER, timeout_ns / 100);
        }

        // NtWaitForKeyedEvent doesnt have spurious wake-ups
        if (@atomicLoad(u32, ptr, .Acquire) == expected) {
            const key = @ptrCast(*const c_void, ptr);
            const rc = windows.ntdll.NtWaitForKeyedEvent(handle, key, windows.FALSE, timeout_ptr);
            switch (rc) {
                0 => {},
                windows.WAIT_TIMEOUT => return ResetEvent.WaitError.TimedOut,
                else => unreachable,
            }
        }
    }

    var keyed_state = State.Uninitialized;
    var keyed_handle: ?windows.HANDLE = null;

    const State = enum(u8) {
        Uninitialized,
        Intializing,
        Initialized,
    };

    fn getEventHandle() ?windows.HANDLE {
        var spin = Backoff.init();
        var state = @atomicLoad(State, &keyed_state, .Monotonic);

        while (true) {
            switch (state) {
                .Initialized => {
                    return keyed_handle;
                },
                .Intializing => {
                    spin.yield();
                    state = @atomicLoad(State, &keyed_state, .Acquire);
                },
                .Uninitialized => state = @cmpxchgWeak(State, &keyed_state, state, .Intializing, .Acquire, .Monotonic) orelse {
                    var handle: windows.HANDLE = undefined;
                    const access_mask = windows.GENERIC_READ | windows.GENERIC_WRITE;
                    if (windows.ntdll.NtCreateKeyedEvent(&handle, access_mask, null, 0) == 0)
                        keyed_handle = handle;
                    @atomicStore(State, &keyed_state, .Initialized, .Release);
                    return keyed_handle;
                },
            }
        }
    }
});

const PosixEvent = struct {
    state: u32,
    cond: c.pthread_cond_t,
    mutex: c.pthread_mutex_t,

    const IS_SET: u32 = 1;

    pub fn init() PosixEvent {
        return PosixEvent{
            .state = 0,
            .cond = c.PTHREAD_COND_INITIALIZER,
            .mutex = c.PTHREAD_MUTEX_INITIALIZER,
        };
    }

    pub fn deinit(self: *PosixEvent) void {
        // On dragonfly, the destroy functions return EINVAL if they were initialized statically.
        const retm = c.pthread_mutex_destroy(&self.mutex);
        assert(retm == 0 or retm == (if (builtin.os == .dragonfly) os.EINVAL else 0));
        const retc = c.pthread_cond_destroy(&self.cond);
        assert(retc == 0 or retc == (if (builtin.os == .dragonfly) os.EINVAL else 0));
    }

    pub fn isSet(self: *PosixEvent) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        return self.state == IS_SET;
    }

    pub fn reset(self: *PosixEvent) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        const was_set = self.state == IS_SET;
        self.state = 0;
        return was_set;
    }

    pub fn set(self: *PosixEvent, auto_reset: bool) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        const had_waiter = self.state > IS_SET;
        self.state = if (auto_reset) 0 else IS_SET;
        if (had_waiter) {
            assert(c.pthread_cond_signal(&self.cond) == 0);
        }
        return had_waiter;
    }

    pub fn wait(self: *PosixEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        if (self.state == IS_SET)
            return false;

        var ts: os.timespec = undefined;
        if (timeout) |timeout_ns| {
            var timeout_abs = timeout_ns;
            if (comptime std.Target.current.isDarwin()) {
                var tv: os.darwin.timeval = undefined;
                assert(os.darwin.gettimeofday(&tv, null) == 0);
                timeout_abs += @intCast(u64, tv.tv_sec) * time.second;
                timeout_abs += @intCast(u64, tv.tv_usec) * time.microsecond;
            } else {
                os.clock_gettime(os.CLOCK_REALTIME, &ts) catch unreachable;
                timeout_abs += @intCast(u64, ts.tv_sec) * time.second;
                timeout_abs += @intCast(u64, ts.tv_nsec);
            }
            ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), @divFloor(timeout_abs, time.second));
            ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), @mod(timeout_abs, time.second));
        }

        var dummy_value: u32 = undefined;
        var wait_token = @truncate(u32, @ptrToInt(&dummy_value));
        self.state = wait_token;

        while (self.state == wait_token) {
            const rc = switch (timeout == null) {
                true => c.pthread_cond_wait(&self.cond, &self.mutex),
                else => c.pthread_cond_timedwait(&self.cond, &self.mutex, &ts),
            };
            // TODO: rc appears to be the positive error code making os.errno() always return 0 on linux
            switch (std.math.max(@as(c_int, os.errno(rc)), rc)) {
                0 => {},
                os.ETIMEDOUT => return ResetEvent.WaitError.TimedOut,
                os.EINVAL => unreachable,
                os.EPERM => unreachable,
                else => unreachable,
            }
        }
        return true;
    }
};

test "std.ResetEvent" {
    // TODO
    if (builtin.single_threaded)
        return error.SkipZigTest;

    var event = ResetEvent.init();
    defer event.deinit();

    // test event setting
    testing.expect(event.isSet() == false);
    testing.expect(event.set(false) == false);
    testing.expect(event.isSet() == true);

    // test event resetting
    testing.expect(event.reset() == true);
    testing.expect(event.isSet() == false);
    testing.expect(event.reset() == false);

    // test cross thread signaling
    const Context = struct {
        event: ResetEvent,
        value: u128,

        fn receiver(self: *@This()) void {
            // wait for the sender to notify us with updated value
            assert(self.value == 0);
            assert((self.event.wait(1 * time.second) catch unreachable) == true);
            assert(self.value == 1);

            // wait for sender to sleep, then notify it of new value
            time.sleep(50 * time.millisecond);
            self.value = 2;
            assert(self.event.set(false) == true);
        }

        fn sender(self: *@This()) !void {
            // wait for the receiver() to start wait()'ing
            time.sleep(50 * time.millisecond);

            // update value to 1 and notify the receiver()
            assert(self.value == 0);
            self.value = 1;
            assert(self.event.set(true) == true);

            // wait for the receiver to update the value & notify us
            assert((try self.event.wait(1 * time.second)) == true);
            assert(self.value == 2);
        }
    };

    _ = event.reset();
    var context = Context{
        .event = event,
        .value = 0,
    };

    var receiver = try std.Thread.spawn(&context, Context.receiver);
    defer receiver.wait();
    try context.sender();
}
