const std = @import("std.zig");
const builtin = @import("builtin");
const time = std.time;
const testing = std.testing;
const assert = std.debug.assert;
const SpinLock = std.SpinLock;
const linux = std.os.linux;
const windows = std.os.windows;

pub const ThreadParker = switch (builtin.os) {
    .linux => if (builtin.link_libc) PosixParker else LinuxParker,
    .windows => WindowsParker,
    else => if (builtin.link_libc) PosixParker else SpinParker,
};

const SpinParker = struct {
    pub fn init() SpinParker {
        return SpinParker{};
    }
    pub fn deinit(self: *SpinParker) void {}

    pub fn unpark(self: *SpinParker, ptr: *const u32) void {}

    pub fn park(self: *SpinParker, ptr: *const u32, expected: u32) void {
        var backoff = SpinLock.Backoff.init();
        while (@atomicLoad(u32, ptr, .Acquire) == expected)
            backoff.yield();
    }
};

const LinuxParker = struct {
    pub fn init() LinuxParker {
        return LinuxParker{};
    }
    pub fn deinit(self: *LinuxParker) void {}

    pub fn unpark(self: *LinuxParker, ptr: *const u32) void {
        const rc = linux.futex_wake(@ptrCast(*const i32, ptr), linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
        assert(linux.getErrno(rc) == 0);
    }

    pub fn park(self: *LinuxParker, ptr: *const u32, expected: u32) void {
        const value = @intCast(i32, expected);
        while (@atomicLoad(u32, ptr, .Acquire) == expected) {
            const rc = linux.futex_wait(@ptrCast(*const i32, ptr), linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, value, null);
            switch (linux.getErrno(rc)) {
                0, linux.EAGAIN => return,
                linux.EINTR => continue,
                linux.EINVAL => unreachable,
                else => continue,
            }
        }
    }
};

const WindowsParker = struct {
    waiters: u32,

    pub fn init() WindowsParker {
        return WindowsParker{ .waiters = 0 };
    }
    pub fn deinit(self: *WindowsParker) void {}

    pub fn unpark(self: *WindowsParker, ptr: *const u32) void {
        const key = @ptrCast(*const c_void, ptr);
        const handle = getEventHandle() orelse return;

        var waiting = @atomicLoad(u32, &self.waiters, .Monotonic);
        while (waiting != 0) {
            waiting = @cmpxchgWeak(u32, &self.waiters, waiting, waiting - 1, .Acquire, .Monotonic) orelse {
                const rc = windows.ntdll.NtReleaseKeyedEvent(handle, key, windows.FALSE, null);
                assert(rc == 0);
                return;
            };
        }
    }

    pub fn park(self: *WindowsParker, ptr: *const u32, expected: u32) void {
        var spin = SpinLock.Backoff.init();
        const ev_handle = getEventHandle();
        const key = @ptrCast(*const c_void, ptr);

        while (@atomicLoad(u32, ptr, .Monotonic) == expected) {
            if (ev_handle) |handle| {
                _ = @atomicRmw(u32, &self.waiters, .Add, 1, .Release);
                const rc = windows.ntdll.NtWaitForKeyedEvent(handle, key, windows.FALSE, null);
                assert(rc == 0);
            } else {
                spin.yield();
            }
        }
    }

    var event_handle = std.lazyInit(windows.HANDLE);

    fn getEventHandle() ?windows.HANDLE {
        if (event_handle.get()) |handle_ptr|
            return handle_ptr.*;
        defer event_handle.resolve();

        const access_mask = windows.GENERIC_READ | windows.GENERIC_WRITE;
        if (windows.ntdll.NtCreateKeyedEvent(&event_handle.data, access_mask, null, 0) != 0)
            return null;
        return event_handle.data;
    }
};

const PosixParker = struct {
    cond: c.pthread_cond_t,
    mutex: c.pthread_mutex_t,

    const c = std.c;

    pub fn init() PosixParker {
        return PosixParker{
            .cond = c.PTHREAD_COND_INITIALIZER,
            .mutex = c.PTHREAD_MUTEX_INITIALIZER,
        };
    }

    pub fn deinit(self: *PosixParker) void {
        // On dragonfly, the destroy functions return EINVAL if they were initialized statically.
        const retm = c.pthread_mutex_destroy(&self.mutex);
        assert(retm == 0 or retm == (if (builtin.os == .dragonfly) os.EINVAL else 0));
        const retc = c.pthread_cond_destroy(&self.cond);
        assert(retc == 0 or retc == (if (builtin.os == .dragonfly) os.EINVAL else 0));
    }

    pub fn unpark(self: *PosixParker, ptr: *const u32) void {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);
        assert(c.pthread_cond_signal(&self.cond) == 0);
    }

    pub fn park(self: *PosixParker, ptr: *const u32, expected: u32) void {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);
        while (@atomicLoad(u32, ptr, .Acquire) == expected)
            assert(c.pthread_cond_wait(&self.cond, &self.mutex) == 0);
    }
};

test "std.ThreadParker" {
    if (builtin.single_threaded)
        return error.SkipZigTest;

    const Context = struct {
        parker: ThreadParker,
        data: u32,

        fn receiver(self: *@This()) void {
            self.parker.park(&self.data, 0); // receives 1
            assert(@atomicRmw(u32, &self.data, .Xchg, 2, .SeqCst) == 1); // sends 2
            self.parker.unpark(&self.data); // wakes up waiters on 2
            self.parker.park(&self.data, 2); // receives 3
            assert(@atomicRmw(u32, &self.data, .Xchg, 4, .SeqCst) == 3); // sends 4
            self.parker.unpark(&self.data); // wakes up waiters on 4
        }

        fn sender(self: *@This()) void {
            assert(@atomicRmw(u32, &self.data, .Xchg, 1, .SeqCst) == 0); // sends 1
            self.parker.unpark(&self.data); // wakes up waiters on 1
            self.parker.park(&self.data, 1); // receives 2
            assert(@atomicRmw(u32, &self.data, .Xchg, 3, .SeqCst) == 2); // sends 3
            self.parker.unpark(&self.data); // wakes up waiters on 3
            self.parker.park(&self.data, 3); // receives 4
        }
    };

    var context = Context{
        .parker = ThreadParker.init(),
        .data = 0,
    };
    defer context.parker.deinit();

    var receiver = try std.Thread.spawn(&context, Context.receiver);
    defer receiver.wait();

    context.sender();
}
