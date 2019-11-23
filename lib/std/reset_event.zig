const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const assert = std.debug.assert;
const Backoff = std.SpinLock.Backoff;
const c = std.c;
const time = std.time;
const linux = std.os.linux;
const windows = std.os.windows;

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
    pub fn isSet(self: *const ResetEvent) bool {
        return self.os_event.isSet();
    }
    
    /// Sets the event if not already set and
    /// wakes up AT LEAST one thread waiting the event.
    /// Returns whether or not a thread was woken up.
    pub fn set(self: *ResetEvent) bool {
        return self.os_event.set();
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
    is_set: @typeOf(set_init),

    const set_init = if (std.debug.runtime_safety) false else {};

    pub fn init() DebugEvent {
        return DebugEvent{ .is_set = set_init };
    }

    pub fn deinit(self: *DebugEvent) void {
        self.* = undefined;
    }

    pub fn isSet(self: *const DebugEvent) bool {
        if (!std.debug.runtime_safety)
            return true;
        return self.is_set;
    }

    pub fn set(self: *DebugEvent) bool {
        if (std.debug.runtime_safety)
            self.is_set = true;
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

fn EventState(comptime TagType: type) type {
    return enum(TagType) {
        Empty,
        Waiting,
        Signaled,
    };
}

const SpinEvent = struct {
    state: State,

    const State = EventState(u8);

    pub fn init() SpinEvent {
        return SpinEvent{ .state = .Empty };
    }

    pub fn deinit(self: *SpinEvent) void {
        self.* = undefined;
    }

    pub fn isSet(self: *const SpinEvent) bool {
        return @atomicLoad(State, &self.state, .Acquire) == .Signaled;
    }

    pub fn set(self: *SpinEvent) bool {
        return @atomicRmw(State, &self.state, .Xchg, .Signaled, .Release) == .Waiting;
    }

    pub fn reset(self: *SpinEvent) bool {
        return @atomicRmw(State, &self.state, .Xchg, .Empty, .Monotonic) == .Signaled;
    }

    pub fn wait(self: *SpinEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        var state = @atomicLoad(State, &self.state, .Monotonic);
        while (true) {
            switch (state) {
                .Empty => state = @cmpxchgWeak(State, &self.state, state, .Waiting, .Acquire, .Monotonic) orelse break,
                .Waiting => break,
                .Signaled => return false,
            }
        }

        // TODO: handle case for time.Timer.start() fails
        var spin = Backoff.init();
        var timer = if (timeout == null) null else time.Timer.start() catch unreachable;
        while (@atomicLoad(State, &self.state, .Monotonic) == .Waiting) {
            spin.yield();
            if (timeout) |timeout_ns| {
                if (timer.?.read() > timeout_ns)
                    return ResetEvent.WaitError.TimedOut;
            }
        }
        return true;
    }
};

const LinuxEvent = struct {
    state: State,

    const State = EventState(i32);

    pub fn init() LinuxEvent {
        return LinuxEvent{ .state = .Empty };
    }

    pub fn deinit(self: *LinuxEvent) void {
        self.* = undefined;
    }

    pub fn isSet(self: *const LinuxEvent) bool {
        return @atomicLoad(State, &self.state, .Acquire) == .Signaled;
    }

    pub fn set(self: *LinuxEvent) bool {
        if (@atomicRmw(State, &self.state, .Xchg, .Signaled, .Release) != .Waiting)
            return false;
        const rc = linux.futex_wake(@ptrCast(*const i32, &self.state), linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
        assert(linux.getErrno(rc) == 0);
        return true;
    }

    pub fn reset(self: *LinuxEvent) bool {
        return @atomicRmw(State, &self.state, .Xchg, .Empty, .Monotonic) == .Signaled;
    }

    pub fn wait(self: *LinuxEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        var state = @atomicLoad(State, &self.state, .Monotonic);
        while (true) {
            switch (state) {
                .Empty => state = @cmpxchgWeak(State, &self.state, .Empty, .Waiting, .Acquire, .Monotonic) orelse break,
                .Waiting => break,
                .Signaled => return false,
            }
        }
        
        var ts: linux.timespec = undefined;
        var ts_ptr: ?*linux.timespec = null;
        if (timeout) |timeout_ns| {
            ts_ptr = &ts;
            ts.tv_sec = @intCast(isize, timeout_ns / time.ns_per_s);
            ts.tv_nsec = @intCast(isize, timeout_ns % time.ns_per_s);
        }

        while (@atomicLoad(State, &self.state, .Monotonic) == .Waiting) {
            const rc = linux.futex_wait(@ptrCast(*const i32, &self.state), linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, @enumToInt(State.Waiting), ts_ptr);
            switch (linux.getErrno(rc)) {
                0, linux.EINTR => continue,
                linux.EAGAIN => break,
                linux.ETIMEDOUT => return ResetEvent.WaitError.TimedOut,
                else => unreachable,
            }
        }
    }
};

const PosixEvent = struct {
    state: State,
    cond: c.pthread_cond_t,
    mutex: c.pthread_mutex_t,

    const State = EventState(u8);

    pub fn init() PosixEvent {
        return PosixEvent{
            .state = .Empty,
            .cond = c.PTHREAD_COND_INITIALIZER,
            .mutex = c.PTHREAD_MUTEX_INITIALIZER,
        };
    }

    pub fn deinit(self: *PosixEvent) void {
        // On dragonfly, the destroy functions return EINVAL if they were initialized statically.
        const retm = c.pthread_mutex_destroy(&self.mutex);
        assert(retm == 0 or retm == (if (builtin.os == .dragonfly) std.os.EINVAL else 0));
        const retc = c.pthread_cond_destroy(&self.cond);
        assert(retc == 0 or retc == (if (builtin.os == .dragonfly) std.os.EINVAL else 0));
        self.* = undefined;
    }

    pub fn isSet(self: *const PosixEvent) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        return self.state == .Signaled;
    }

    pub fn set(self: *PosixEvent) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        const woken = self.state == .Waiting;
        self.state = .Signaled;
        return woken;
    }

    pub fn reset(self: *PosixEvent) bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        const was_set = self.state == .Signaled;
        self.state = .Empty;
        return was_set;
    }

    pub fn wait(self: *PosixEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        if (self.state == .Signaled)
            return false;

        var ts: std.os.timespec = undefined;
        var ts_ptr = &ts;
        if (timeout) |timeout_ns| {
            var tv: std.os.timeval = undefined;
            assert(c.gettimeofday(&tv, null) == 0);
            ts.tv_sec = @intCast(isize, tv.tv_sec + (timeout_ns / time.ns_per_s));
            ts.tv_nsec = @intCast(isize, (tv.tv_usec * time.microsecond) + (timeout_ns % time.ns_per_s));
        }

        self.state = .Waiting;
        while (self.state == .Waiting) {
            const rc = switch (timeout == null) {
                true => c.pthread_cond_wait(&self.cond, &self.mutex),
                else => c.pthread_cond_timedwait(&self.cond, &self.mutex, ts_ptr),
            };
            assert(rc == 0);
        }
    }
};

const WindowsEvent = struct {
    state: State,

    const State = EventState(u32);

    pub fn init() WindowsEvent {
        return WindowsEvent{ .state = .Empty };
    }

    pub fn deinit(self: *WindowsEvent) void {
        self.* = undefined;
    }

    pub fn isSet(self: *const WindowsEvent) bool {
        return @atomicLoad(State, &self.state, .Acquire) == .Signaled;
    }

    pub fn set(self: *WindowsEvent) bool {
        if (@atomicRmw(State, &self.state, .Xchg, .Signaled, .Release) != .Waiting)
            return false;

        if (getEventHandle()) |handle| {
            const key = @ptrCast(*const c_void, &self.state);
            const rc = windows.ntdll.NtReleaseKeyedEvent(handle, key, windows.FALSE, null);
            assert(rc == 0);
        }
        return true;
    }

    pub fn reset(self: *WindowsEvent) bool {
        return @atomicRmw(State, &self.state, .Xchg, .Empty, .Monotonic) == .Signaled;
    }

    pub fn wait(self: *WindowsEvent, timeout: ?u64) ResetEvent.WaitError!bool {
        var state = @atomicLoad(State, &self.state, .Monotonic);
        while (true) {
            switch (state) {
                .Empty => state = @cmpxchgWeak(State, &self.state, .Empty, .Waiting, .Acquire, .Monotonic) orelse break,
                .Waiting => break,
                .Signaled => return false,
            }
        }

        const timeout_ms = if (timeout @intCast(windows.LARGE_INTEGER, )
    }
};
