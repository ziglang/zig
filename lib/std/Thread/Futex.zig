// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! Futex is a mechanism used to block (`wait`) and unblock (`wake`) threads using a 32bit memory address as hints.
//! Blocking a thread is acknowledged only if the 32bit memory address is equal to a given value.
//! This check helps avoid block/unblock deadlocks which occur if a `wake()` happens before a `wait()`.
//! Using Futex, other Thread synchronization primitives can be built which efficiently wait for cross-thread events or signals.  

const std = @import("../std.zig");
const Futex = @This();

const target = std.Target.current;
const single_threaded = std.builtin.single_threaded;

const assert = std.debug.assert;
const testing = std.testing;

const Atomic = std.atomic.Atomic;
const spinLoopHint = std.atomic.spinLoopHint;

/// Checks if `ptr` still contains the value `expect` and, if so, blocks the caller until either:
/// - The value at `ptr` is no longer equal to `expect`.
/// - The caller is unblocked by a matching `wake()`.
/// - The caller is unblocked spuriously by an arbitrary internal signal.
/// 
/// If `timeout` is provided, and the caller is blocked for longer than `timeout` nanoseconds`, `error.TimedOut` is returned.
///
/// The checking of `ptr` and `expect`, along with blocking the caller, is done atomically
/// and totally ordered (sequentially consistent) with respect to other wait()/wake() calls on the same `ptr`.
pub fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{TimedOut}!void {
    if (single_threaded) {
        // check whether the caller should block
        if (ptr.loadUnchecked() != expect) {
            return;
        }

        // There are no other threads which could notify the caller on single_threaded.
        // Therefor a wait() without a timeout would block indefinitely.
        const timeout_ns = timeout orelse {
            @panic("deadlock");
        };

        // Simulate blocking with the timeout knowing that:
        // - no other thread can change the ptr value
        // - no other thread could unblock us if we waiting on the ptr
        std.time.sleep(timeout_ns);
        return error.TimedOut;
    }

    // Avoid calling into the OS for no-op waits()
    if (timeout) |timeout_ns| {
        if (timeout_ns == 0) {
            if (ptr.load(.SeqCst) != expect) return;
            return error.TimedOut;
        }
    }

    return OsFutex.wait(ptr, expect, timeout);
}

/// Unblocks at most `num_waiters` callers blocked in a `wait()` call on `ptr`.
/// `num_waiters` of 1 unblocks at most one `wait(ptr, ...)` and `maxInt(u32)` unblocks effectively all `wait(ptr, ...)`.
pub fn wake(ptr: *const Atomic(u32), num_waiters: u32) void {
    if (num_waiters == 0 or single_threaded) {
        return;
    }

    return OsFutex.wake(ptr, num_waiters);
}

const OsFutex = if (target.os.tag == .windows)
    WindowsFutex
else if (target.os.tag == .linux)
    LinuxFutex
else if (target.isDarwin())
    DarwinFutex
else if (std.builtin.link_libc)
    PosixFutex
else
    @compileError("Operating System unsupported");

const WindowsFutex = struct {
    const windows = std.os.windows;

    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{TimedOut}!void {
        var timeout_value: windows.LARGE_INTEGER = undefined;
        var timeout_ptr: ?*const windows.LARGE_INTEGER = null;

        // NTDLL functions work with time in units of 100 nanoseconds.
        // Positive values for timeouts are absolute time while negative is relative.
        if (timeout) |timeout_ns| {
            timeout_ptr = &timeout_value;
            timeout_value = -@intCast(windows.LARGE_INTEGER, timeout_ns / 100);
        }

        switch (windows.ntdll.RtlWaitOnAddress(
            @ptrCast(?*const c_void, ptr),
            @ptrCast(?*const c_void, &expect),
            @sizeOf(@TypeOf(expect)),
            timeout_ptr,
        )) {
            .SUCCESS => {},
            .TIMEOUT => return error.TimedOut,
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), num_waiters: u32) void {
        const address = @ptrCast(?*const c_void, ptr);
        switch (num_waiters) {
            1 => windows.ntdll.RtlWakeAddressSingle(address),
            else => windows.ntdll.RtlWakeAddressAll(address),
        }
    }
};

const LinuxFutex = struct {
    const linux = std.os.linux;

    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{TimedOut}!void {
        var ts: std.os.timespec = undefined;
        var ts_ptr: ?*std.os.timespec = null;

        // Futex timespec timeout is already in relative time.
        if (timeout) |timeout_ns| {
            ts_ptr = &ts;
            ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
            ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
        }

        switch (linux.getErrno(linux.futex_wait(
            @ptrCast(*const i32, ptr),
            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAIT,
            @bitCast(i32, expect),
            ts_ptr,
        ))) {
            0 => {}, // notified by `wake()`
            std.os.EINTR => {}, // spurious wakeup
            std.os.EAGAIN => {}, // ptr.* != expect
            std.os.ETIMEDOUT => return error.TimedOut,
            std.os.EINVAL => {}, // possibly timeout overflow
            std.os.EFAULT => unreachable,
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), num_waiters: u32) void {
        switch (linux.getErrno(linux.futex_wake(
            @ptrCast(*const i32, ptr),
            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAKE,
            std.math.cast(i32, num_waiters) catch std.math.maxInt(i32),
        ))) {
            0 => {}, // successful wake up
            std.os.EINVAL => {}, // invalid futex_wait() on ptr done elsewhere
            std.os.EFAULT => {}, // pointer became invalid while doing the wake
            else => unreachable,
        }
    }
};

const DarwinFutex = struct {
    const darwin = std.os.darwin;

    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{TimedOut}!void {
        // ulock_wait() uses micro-second timeouts, where 0 = INIFITE or no-timeout
        var timeout_us: u32 = 0;
        if (timeout) |timeout_ns| {
            timeout_us = @intCast(u32, timeout_ns / std.time.ns_per_us);
        }

        // Darwin XNU 7195.50.7.100.1 introduced __ulock_wait2 and migrated code paths (notably pthread_cond_t) towards it:
        // https://github.com/apple/darwin-xnu/commit/d4061fb0260b3ed486147341b72468f836ed6c8f#diff-08f993cc40af475663274687b7c326cc6c3031e0db3ac8de7b24624610616be6
        //
        // This XNU version appears to correspond to 11.0.1:
        // https://kernelshaman.blogspot.com/2021/01/building-xnu-for-macos-big-sur-1101.html
        const addr = @ptrCast(*const c_void, ptr);
        const flags = darwin.UL_COMPARE_AND_WAIT | darwin.ULF_NO_ERRNO;
        const status = blk: {
            if (target.os.version_range.semver.max.major >= 11) {
                break :blk darwin.__ulock_wait2(flags, addr, expect, timeout_us, 0);
            } else {
                break :blk darwin.__ulock_wait(flags, addr, expect, timeout_us);
            }
        };

        if (status >= 0) return;
        switch (-status) {
            darwin.EINTR => {},
            darwin.EFAULT => unreachable,
            darwin.ETIMEDOUT => return error.TimedOut,
            else => unreachable,
        }
    }

    fn wake(ptr: *const Atomic(u32), num_waiters: u32) void {
        var flags: u32 = darwin.UL_COMPARE_AND_WAIT | darwin.ULF_NO_ERRNO;
        if (num_waiters > 1) {
            flags |= darwin.ULF_WAKE_ALL;
        }

        while (true) {
            const addr = @ptrCast(*const c_void, ptr);
            const status = darwin.__ulock_wake(flags, addr, 0);

            if (status >= 0) return;
            switch (-status) {
                darwin.EINTR => continue, // spurious wake()
                darwin.ENOENT => return, // nothing was woken up
                darwin.EALREADY => unreachable, // only for ULF_WAKE_THREAD
                else => unreachable,
            }
        }
    }
};

const PosixFutex = struct {
    fn wait(ptr: *const Atomic(u32), expect: u32, timeout: ?u64) error{TimedOut}!void {
        const address = @ptrToInt(ptr);
        const bucket = Bucket.from(address);
        var waiter: List.Node = undefined;

        {
            assert(std.c.pthread_mutex_lock(&bucket.mutex) == 0);
            defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == 0);

            if (ptr.load(.SeqCst) != expect) {
                return;
            }

            waiter.data = .{ .address = address };
            bucket.list.prepend(&waiter);
        }

        var timed_out = false;
        waiter.data.wait(timeout) catch {
            defer if (!timed_out) {
                waiter.data.wait(null) catch unreachable;
            };

            assert(std.c.pthread_mutex_lock(&bucket.mutex) == 0);
            defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == 0);

            if (waiter.data.address == address) {
                timed_out = true;
                bucket.list.remove(&waiter);
            }
        };

        waiter.data.deinit();
        if (timed_out) {
            return error.TimedOut;
        }
    }

    fn wake(ptr: *const Atomic(u32), num_waiters: u32) void {
        const address = @ptrToInt(ptr);
        const bucket = Bucket.from(address);
        var can_notify = num_waiters;

        var notified = List{};
        defer while (notified.popFirst()) |waiter| {
            waiter.data.notify();
        };

        assert(std.c.pthread_mutex_lock(&bucket.mutex) == 0);
        defer assert(std.c.pthread_mutex_unlock(&bucket.mutex) == 0);

        var waiters = bucket.list.first;
        while (waiters) |waiter| {
            assert(waiter.data.address != null);
            waiters = waiter.next;

            if (waiter.data.address != address) continue;
            if (can_notify == 0) break;
            can_notify -= 1;

            bucket.list.remove(waiter);
            waiter.data.address = null;
            notified.prepend(waiter);
        }
    }

    const Bucket = struct {
        mutex: std.c.pthread_mutex_t = .{},
        list: List = .{},

        var buckets = [_]Bucket{.{}} ** 64;

        fn from(address: usize) *Bucket {
            return &buckets[address % buckets.len];
        }
    };

    const List = std.TailQueue(struct {
        address: ?usize,
        state: State = .empty,
        cond: std.c.pthread_cond_t = .{},
        mutex: std.c.pthread_mutex_t = .{},

        const Self = @This();
        const State = enum {
            empty,
            waiting,
            notified,
        };

        fn deinit(self: *Self) void {
            const rc = std.c.pthread_cond_destroy(&self.cond);
            assert(rc == 0 or rc == std.os.EINVAL);

            const rm = std.c.pthread_mutex_destroy(&self.mutex);
            assert(rm == 0 or rm == std.os.EINVAL);
        }

        fn wait(self: *Self, timeout: ?u64) error{TimedOut}!void {
            assert(std.c.pthread_mutex_lock(&self.mutex) == 0);
            defer assert(std.c.pthread_mutex_unlock(&self.mutex) == 0);

            switch (self.state) {
                .empty => self.state = .waiting,
                .waiting => unreachable,
                .notified => return,
            }

            var ts: std.os.timespec = undefined;
            var ts_ptr: ?*const std.os.timespec = null;
            if (timeout) |timeout_ns| {
                ts_ptr = &ts;
                std.os.clock_gettime(std.os.CLOCK_REALTIME, &ts) catch unreachable;
                ts.tv_sec += @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
                ts.tv_nsec += @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
                if (ts.tv_nsec >= std.time.ns_per_s) {
                    ts.tv_sec += 1;
                    ts.tv_nsec -= std.time.ns_per_s;
                }
            }

            while (true) {
                switch (self.state) {
                    .empty => unreachable,
                    .waiting => {},
                    .notified => return,
                }

                const ts_ref = ts_ptr orelse {
                    assert(std.c.pthread_cond_wait(&self.cond, &self.mutex) == 0);
                    continue;
                };

                const rc = std.c.pthread_cond_timedwait(&self.cond, &self.mutex, ts_ref);
                assert(rc == 0 or rc == std.os.ETIMEDOUT);
                if (rc == std.os.ETIMEDOUT) {
                    self.state = .empty;
                    return error.TimedOut;
                }
            }
        }

        fn notify(self: *Self) void {
            assert(std.c.pthread_mutex_lock(&self.mutex) == 0);
            defer assert(std.c.pthread_mutex_unlock(&self.mutex) == 0);

            switch (self.state) {
                .empty => self.state = .notified,
                .waiting => {
                    self.state = .notified;
                    assert(std.c.pthread_cond_signal(&self.cond) == 0);
                },
                .notified => unreachable,
            }
        }
    });
};

test "Futex - wait/wake" {
    var value = Atomic(u32).init(0);
    Futex.wait(&value, 1, null) catch unreachable;

    const wait_noop_result = Futex.wait(&value, 0, 0);
    try testing.expectError(error.TimedOut, wait_noop_result);

    const wait_longer_result = Futex.wait(&value, 0, std.time.ns_per_ms);
    try testing.expectError(error.TimedOut, wait_longer_result);

    Futex.wake(&value, 0);
    Futex.wake(&value, 1);
    Futex.wake(&value, std.math.maxInt(u32));
}

test "Futex - Signal" {
    if (!single_threaded) {
        return;
    }

    try (struct {
        value: Atomic(u32) = Atomic(u32).init(0),

        const Self = @This();

        fn send(self: *Self, value: u32) void {
            self.value.store(value, .Release);
            Futex.wake(&self.value, 1);
        }

        fn recv(self: *Self, expected: u32) void {
            while (true) {
                const value = self.value.load(.Acquire);
                if (value == expected) break;
                Futex.wait(&self.value, value, null) catch unreachable;
            }
        }

        const Thread = struct {
            tx: *Self,
            rx: *Self,

            const start_value = 1;

            fn run(self: Thread) void {
                var iterations: u32 = start_value;
                while (iterations < 10) : (iterations += 1) {
                    self.rx.recv(iterations);
                    self.tx.send(iterations);
                }
            }
        };

        fn run() !void {
            var ping = Self{};
            var pong = Self{};

            const t1 = try std.Thread.spawn(Thread.run, .{ .rx = &ping, .tx = &pong });
            defer t1.wait();

            const t2 = try std.Thread.spawn(Thread.run, .{ .rx = &pong, .tx = &ping });
            defer t2.wait();

            ping.send(Thread.start_value);
        }
    }).run();
}

test "Futex - Broadcast" {
    if (!single_threaded) {
        return;
    }

    try (struct {
        threads: [10]*std.Thread = undefined,
        broadcast: Atomic(u32) = Atomic(u32).init(0),
        notified: Atomic(usize) = Atomic(usize).init(0),

        const Self = @This();

        const BROADCAST_EMPTY = 0;
        const BROADCAST_SENT = 1;
        const BROADCAST_RECEIVED = 2;

        fn runReceiver(self: *Self) void {
            while (true) {
                const broadcast = self.broadcast.load(.Acquire);
                if (broadcast == BROADCAST_SENT) break;
                assert(broadcast == BROADCAST_EMPTY);
                Futex.wait(&self.broadcast, broadcast, null) catch unreachable;
            }

            const notified = self.notified.fetchAdd(1, .Monotonic);
            if (notified + 1 == self.threads.len) {
                self.broadcast.store(BROADCAST_RECEIVED, .Release);
                Futex.wake(&self.broadcast, 1);
            }
        }

        fn run() !void {
            var self = Self{};

            for (self.threads) |*thread|
                thread.* = try std.Thread.spawn(runReceiver, &self);
            defer for (self.threads) |thread|
                thread.wait();

            std.time.sleep(16 * std.time.ns_per_ms);
            self.broadcast.store(BROADCAST_SENT, .Monotonic);
            Futex.wake(&self.broadcast, @intCast(u32, self.threads.len));

            while (true) {
                const broadcast = self.broadcast.load(.Acquire);
                if (broadcast == BROADCAST_RECEIVED) break;
                try testing.expectEqual(broadcast, BROADCAST_SENT);
                Futex.wait(&self.broadcast, broadcast, null) catch unreachable;
            }

            const notified = self.notified.load(.Monotonic);
            try testing.expectEqual(notified, self.threads.len);
        }
    }).run();
}

test "Futex - Chain" {
    if (!single_threaded) {
        return;
    }

    try (struct {
        completed: Signal = .{},
        threads: [10]struct {
            thread: *std.Thread,
            signal: Signal,
        } = undefined,

        const Signal = struct {
            state: Atomic(u32) = Atomic(u32).init(0),

            fn wait(self: *Signal) void {
                while (true) {
                    const value = self.value.load(.Acquire);
                    if (value == 1) break;
                    assert(value == 0);
                    Futex.wait(&self.value, 0, null) catch unreachable;
                }
            }

            fn notify(self: *Signal) void {
                assert(self.value.load(.Unordered) == 0);
                self.value.store(1, .Release);
                Futex.wake(&self.value, 1);
            }
        };

        const Self = @This();
        const Chain = struct {
            self: *Self,
            index: usize,

            fn run(chain: Chain) void {
                const this_signal = &chain.self.threads[chain.index].signal;

                var next_signal = &chain.self.completed;
                if (chain.index + 1 < chain.self.threads.len) {
                    next_signal = &chain.self.threads[chain.index + 1].signal;
                }

                this_signal.wait();
                next_signal.notify();
            }
        };

        fn run() !void {
            var self = Self{};

            for (self.threads) |*entry, index| {
                entry.signal = .{};
                entry.thread = try std.Thread.spawn(Chain.run, .{
                    .self = &self,
                    .index = index,
                });
            }

            self.threads[0].signal.notify();
            self.completed.wait();

            for (self.threads) |entry| {
                entry.thread.wait();
            }
        }
    }).run();
}
