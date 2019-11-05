const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const time = std.time;
const linux = std.os.linux;
const windows = std.os.windows;

pub const SpinLock = struct {
    lock: u8, // TODO use a bool or enum

    pub const Held = struct {
        spinlock: *SpinLock,

        pub fn release(self: Held) void {
            // TODO: @atomicStore() https://github.com/ziglang/zig/issues/2995
            assert(@atomicRmw(u8, &self.spinlock.lock, .Xchg, 0, .Release) == 1);
        }
    };

    pub fn init() SpinLock {
        return SpinLock{ .lock = 0 };
    }

    // Hybrid spinning from
    // http://www.1024cores.net/home/lock-free-algorithms/tricks/spinning
    pub fn acquire(self: *SpinLock) Held {
        var backoff: usize = 0;
        while (@atomicRmw(u8, &self.lock, .Xchg, 1, .Acquire) != 0) : (backoff +%= 1) {
            if (backoff < 10) {
                yieldCpu();
            } else if (backoff < 20) {
                for (([30]void)(undefined)) |_| yieldCpu();
            } else if (backoff < 24) {
                yieldThread();
            } else if (backoff < 26) {
                time.sleep(1 * time.millisecond);
            } else {
                time.sleep(10 * time.millisecond);
            }
        }
        return Held{ .spinlock = self };
    }

    fn yieldCpu() void {
        switch (builtin.arch) {
            .i386, .x86_64 => asm volatile("pause" ::: "memory"),
            .arm, .aarch64 => asm volatile("yield"),
            else => time.sleep(0),
        }
    }

    fn yieldThread() void {
        switch (builtin.os) {
            .linux => assert(linux.syscall0(linux.SYS_sched_yield) == 0),
            .windows => _ = windows.kernel32.SwitchToThread(),
            else => time.sleep(1 * time.microsecond),
        }
    }
};

test "spinlock" {
    var lock = SpinLock.init();
    const held = lock.acquire();
    defer held.release();
}
