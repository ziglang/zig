const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Mutex = @This();

impl: Impl = .{},

pub fn tryAcquire(self: *Mutex) ?Held {
    if (self.impl.tryAcquire()) return Held{ .mutex = self };
    return null;
}

pub fn acquire(self: *Mutex) Held {
    self.impl.acquire();
    return Held{ .mutex = self };
}

pub const Held = struct {
    mutex: *Mutex,

    pub fn release(self: Held) void {
        self.mutex.impl.release();
    }
};

pub const Impl = if (std.builtin.single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.os.tag.isDarwin())
    DarwinImpl
else
    FutexImpl;

const SerialImpl = struct {
    is_locked: bool = false,

    pub fn tryAcquire(self: *Impl) bool {
        if (self.is_locked) return false;
        self.is_locked = true;
        return true;
    }

    pub fn acquire(self: *Impl) void {
        if (self.is_locked) unreachable; // deadlock detected
        self.is_locked = true;
    }

    pub fn release(self: *Impl) void {
        if (!self.is_locked) unreachable; // released when not acquired
        self.is_locked = false;
    }
};

const WindowsImpl = struct {
    srwlock: os.windows.SRWLOCK = os.windows.SRWLOCK_INIT,

    pub fn tryAcquire(self: *Impl) bool {
        return os.windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != os.windows.FALSE;
    }

    pub fn acquire(self: *Impl) void {
        os.windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
    }

    pub fn release(self: *Impl) void {
        os.windows.kernel32.ReleaseSRWLockExclusive(&self.srwlock);
    }

    pub fn unlock(m: *PthreadMutex) void {
        switch (std.c.pthread_mutex_unlock(&m.pthread_mutex)) {
            .SUCCESS => return,
            .INVAL => unreachable,
            .AGAIN => unreachable,
            .PERM => unreachable,
            else => unreachable,
        }
    }
};

const DarwinImpl = struct {
    oul: os.darwin.os_unfair_lock = .{},

    pub fn tryAcquire(self: *Impl) bool {
        return os.darwin.os_unfair_lock_trylock(&self.oul);
    }

    pub fn acquire(self: *Impl) void {
        return os.darwin.os_unfair_lock_lock(&self.oul);
    }

    pub fn release(self: *Impl) void {
        return os.darwin.os_unfair_lock_unlock(&self.oul);
    }
};

/// Modified implementation of glibc's LL_LOCK:
/// https://github.com/bminor/glibc/blob/master/sysdeps/nptl/lowlevellock.h
/// https://github.com/bminor/glibc/blob/master/nptl/lowlevellock.c
const FutexImpl = struct {
    state: Atomic(u32) = Atomic(u32).init(UNLOCKED),

    const UNLOCKED = 0;
    const LOCKED = 0b01;
    const CONTENDED = 0b11;
    const is_x86 = target.cpu.arch.isX86();

    pub fn tryAcquire(self: *Impl) bool {
        return self.acquireFast(true);
    }

    pub fn acquire(self: *Impl) void {
        if (!self.acquireFast(false)) {
            self.acquireSlow();
        }
    }

    inline fn acquireFast(self: *Impl, comptime strong: bool) bool {
        // On x86, "lock bts" uses less i-cache & can be faster than "lock cmpxchg" below.
        if (is_x86) {
            return self.state.bitSet(@ctz(u32, LOCKED), .Acquire) == UNLOCKED;
        }

        const cas_fn = switch (strong) {
            true => "compareAndSwap",
            else => "tryCompareAndSwap",
        };

        return @field(self.state, cas_fn)(
            UNLOCKED,
            LOCKED,
            .Acquire,
            .Monotonic,
        ) == null;
    }

    noinline fn acquireSlow(self: *Impl) void {
        // Spin a little bit on the Mutex state in the hopes that
        // we can acquire it without having to call Futex.wait().
        // Give up spinning if the Mutex is contended.
        // This helps acquire() latency under micro-contention.
        var spin = SpinWait{};
        while (spin.yield()) {
            switch (self.state.load(.Monotonic)) {
                UNLOCKED => _ = self.state.tryCompareAndSwap(
                    UNLOCKED,
                    LOCKED,
                    .Acquire,
                    .Monotonic,
                ) orelse return,
                LOCKED => continue,
                CONTENDED => break,
                else => unreachable, // invalid Mutex state
            }
        }

        // Make sure the state is CONTENDED before sleeping with Futex so release() can wake us up.
        // Transitioning to CONTENDED may also acquire the mutex in the process.
        //
        // If we sleep, we must acquire the Mutex with CONTENDED to ensure that other threads
        // sleeping on the Futex having seen CONTENDED before are eventually woken up by release().
        // This unfortunately ends up in an extra Futex.wake() for the last thread but that's ok.
        while (true) : (Futex.wait(&self.state, CONTENDED, null) catch unreachable) {
            // On x86, "xchg" can be faster than "lock cmpxchg" below.
            if (is_x86) {
                switch (self.state.swap(CONTENDED, .Acquire)) {
                    UNLOCKED => return,
                    LOCKED, CONTENDED => continue,
                    else => unreachable, // invalid Mutex state
                }
            }

            var state = self.state.load(.Monotonic);
            while (state != CONTENDED) {
                state = switch (state) {
                    UNLOCKED => self.state.tryCompareAndSwap(state, CONTENDED, .Acquire, .Monotonic) orelse return,
                    LOCKED => self.state.tryCompareAndSwap(state, CONTENDED, .Monotonic, .Monotonic) orelse break,
                    CONTENDED => unreachable, // checked above
                    else => unreachable, // invalid Mutex state
                };
            }
        }
    }

    pub fn release(self: *Impl) void {
        switch (self.state.swap(UNLOCKED, .Release)) {
            UNLOCKED => unreachable, // released without being acquired
            LOCKED => {},
            CONTENDED => Futex.wake(&self.state, 1),
            else => unreachable, // invalid Mutex state
        }
    }
};

test "Mutex - basic" {
    var mutex = Mutex{};
    
    // Test that tryAcquire() is mutually exclusive
    var held = mutex.tryAcquire() orelse return error.MutexTryAcquire;
    try testing.expectEqual(mutex.tryAcquire(), null);
    try testing.expectEqual(mutex.tryAcquire(), null);
    held.release();

    // Also test with acquire()
    held = mutex.acquire();
    try testing.expectEqual(mutex.tryAcquire(), null);
    held.release();
}

test "Mutex - racy" {
    if (std.builtin.single_threaded) return error.SkipZigTest;

    const num_threads = 4;
    const num_iters_per_thread = 100;

    const Context = struct {
        mutex: Mutex = .{},
        value: u128 = 0, // u128 to hint at disabling atomic updates

        fn run(self: *@This()) void {
            var i: usize = 0;
            while (i < num_iters_per_thread) : (i += 1) {
                const held = self.mutex.acquire();
                defer held.release();

                const value = self.value;
                std.os.sched_yield() catch {}; // hint to increase chance of thread interleaving
                self.value = std.math.add(u128, value, 1) catch return;
            }
        }
    };

    var context = Context{};

    var threads: [4]std.Thread = undefined;
    for (threads) |*t| t.* = try std.Thread.spawn(.{}, Context.run, .{&context});
    for (threads) |t| t.join();

    try testing.expect(context.value == num_iters_per_thread * num_threads);
}