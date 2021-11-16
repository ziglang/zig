const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;

const builtin = @import("builtin");
const target = builtin.target;
const single_threaded = builtin.single_threaded;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Mutex = @This();

impl: Impl = .{},

pub fn tryLock(self: *Mutex) bool {
    return self.impl.tryLock();
}

pub fn lock(self: *Mutex) void {
    self.impl.lock();
}

pub fn unlock(self: *Mutex) void {
    self.impl.unlock();
}

pub const Impl = if (single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.os.tag.isDarwin())
    DarwinImpl
else
    FutexImpl;

const SerialImpl = struct {
    is_locked: bool = false,

    pub fn tryLock(self: *Impl) bool {
        if (self.is_locked) return false;
        self.is_locked = true;
        return true;
    }

    pub fn lock(self: *Impl) void {
        if (self.is_locked) unreachable; // deadlock detected
        self.is_locked = true;
    }

    pub fn unlock(self: *Impl) void {
        if (!self.is_locked) unreachable; // unlocked when not locked
        self.is_locked = false;
    }
};

const WindowsImpl = struct {
    srwlock: os.windows.SRWLOCK = os.windows.SRWLOCK_INIT,

    pub fn tryLock(self: *Impl) bool {
        return os.windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != os.windows.FALSE;
    }

    pub fn lock(self: *Impl) void {
        os.windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
    }

    pub fn unlock(self: *Impl) void {
        os.windows.kernel32.ReleaseSRWLockExclusive(&self.srwlock);
    }
};

const DarwinImpl = struct {
    oul: os.darwin.os_unfair_lock = .{},

    pub fn tryLock(self: *Impl) bool {
        return os.darwin.os_unfair_lock_trylock(&self.oul);
    }

    pub fn lock(self: *Impl) void {
        return os.darwin.os_unfair_lock_lock(&self.oul);
    }

    pub fn unlock(self: *Impl) void {
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
    const CONTENDED = 0b11; // must have same bit set as LOCKED for x86

    const is_x86 = target.cpu.arch.isX86();

    pub fn tryLock(self: *Impl) bool {
        return self.lockFast(.strong);
    }

    pub fn lock(self: *Impl) void {
        if (!self.lockFast(.weak)) {
            self.lockSlow();
        }
    }

    const LockRetry = enum { weak, strong };

    inline fn lockFast(self: *Impl, comptime lock_retry: LockRetry) bool {
        // On x86, "lock bts" uses less i-cache & can be faster than "lock cmpxchg" below.
        if (is_x86) {
            return self.state.bitSet(@ctz(u32, LOCKED), .Acquire) == UNLOCKED;
        }

        const cas_fn = switch (lock_retry) {
            .weak => "tryCompareAndSwap",
            .strong => "compareAndSwap",
        };

        return @field(self.state, cas_fn)(
            UNLOCKED,
            LOCKED,
            .Acquire,
            .Monotonic,
        ) == null;
    }

    noinline fn lockSlow(self: *Impl) void {
        // Spin a little bit on the Mutex state in the hopes that
        // we can lock it without having to call Futex.wait().
        var spin = SpinWait{};
        while (spin.yield()) {
            switch (self.state.load(.Monotonic)) {
                UNLOCKED => {
                    // Only try to grab the Mutex when it's unlocked
                    _ = self.state.tryCompareAndSwap(
                        UNLOCKED,
                        LOCKED,
                        .Acquire,
                        .Monotonic,
                    ) orelse return;
                },
                LOCKED => {
                    continue;
                },
                CONTENDED => {
                    // Give up spinning if the Mutex is contended.
                    // This helps bound spin latency under contention.
                    break;
                },
                else => unreachable, // invalid Mutex state
            }
        }

        // Make sure the state is CONTENDED before sleeping with Futex so unlock() can wake us up.
        // Transitioning to CONTENDED may also lock the mutex in the process.
        //
        // If we sleep, we must lock the Mutex with CONTENDED to ensure that other threads sleeping 
        // on the Futex that have seen state=CONTENDED before are eventually woken up by unlock().
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

            // UNLOCKED -> CONTENDED (acquires the lock)
            // LOCKED -> CONTENDED (marks that there's threads waiting)
            // CONTENDED -> nothing (just go to sleep)
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

    pub fn unlock(self: *Impl) void {
        switch (self.state.swap(UNLOCKED, .Release)) {
            UNLOCKED => unreachable, // unlocked without being locked
            LOCKED => {},
            CONTENDED => Futex.wake(&self.state, 1),
            else => unreachable, // invalid Mutex state
        }
    }
};

test "Mutex - basic" {
    var mutex = Mutex{};

    // Test that tryLock() is mutually exclusive
    try testing.expect(mutex.tryLock());
    try testing.expect(!mutex.tryLock());
    try testing.expect(!mutex.tryLock());
    mutex.unlock();

    // Also test with lock()
    mutex.lock();
    try testing.expect(!mutex.tryLock());
    mutex.unlock();
}

test "Mutex - racy" {
    if (single_threaded) 
        return error.SkipZigTest;

    const num_threads = 4;
    const num_iters_per_thread = 100;

    const Context = struct {
        mutex: Mutex = .{},
        // u128 >= to hint at disabling atomic reads/writes as entire value shouldn't fit in native registers
        value: u128 = 0, 

        fn run(self: *@This()) void {
            var i: usize = 0;
            while (i < num_iters_per_thread) : (i += 1) {
                self.mutex.lock();
                defer self.mutex.unlock();

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
