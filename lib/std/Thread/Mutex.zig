//! Mutex is a synchronization primitive which enforces atomic access to a shared region of code known as the "critical section".
//! It does this by blocking ensuring only one thread is in the critical section at any given point in time by blocking the others.
//! Mutex can be statically initialized and is at most `@sizeOf(u64)` large.
//! Use `lock()` or `tryLock()` to enter the critical section and `unlock()` to leave it.
//!
//! Example:
//! ```
//! var m = Mutex{};
//!
//! {
//!     m.lock();
//!     defer m.unlock();
//!     // ... critical section code
//! }
//!
//! if (m.tryLock()) {
//!     defer m.unlock();
//!     // ... critical section code
//! }
//! ```

const std = @import("../std.zig");
const builtin = @import("builtin");
const Mutex = @This();

const os = std.os;
const assert = std.debug.assert;
const testing = std.testing;
const Atomic = std.atomic.Atomic;
const Thread = std.Thread;
const Futex = Thread.Futex;

impl: Impl = .{},

/// Tries to acquire the mutex without blocking the caller's thread.
/// Returns `false` if the calling thread would have to block to acquire it.
/// Otherwise, returns `true` and the caller should `unlock()` the Mutex to release it.
pub fn tryLock(self: *Mutex) bool {
    return self.impl.tryLock();
}

/// Acquires the mutex, blocking the caller's thread until it can.
/// It is undefined behavior if the mutex is already held by the caller's thread.
/// Once acquired, call `unlock()` on the Mutex to release it.
pub fn lock(self: *Mutex) void {
    self.impl.lock();
}

/// Releases the mutex which was previously acquired with `lock()` or `tryLock()`.
/// It is undefined behavior if the mutex is unlocked from a different thread that it was locked from.
pub fn unlock(self: *Mutex) void {
    self.impl.unlock();
}

const Impl = if (builtin.mode == .Debug and !builtin.single_threaded)
    DebugImpl
else
    ReleaseImpl;

const ReleaseImpl = if (builtin.single_threaded)
    SingleThreadedImpl
else if (builtin.os.tag == .windows)
    WindowsImpl
else if (builtin.os.tag.isDarwin())
    DarwinImpl
else
    FutexImpl;

const DebugImpl = struct {
    locking_thread: Atomic(Thread.Id) = Atomic(Thread.Id).init(0), // 0 means it's not locked.
    impl: ReleaseImpl = .{},

    inline fn tryLock(self: *@This()) bool {
        const locking = self.impl.tryLock();
        if (locking) {
            self.locking_thread.store(Thread.getCurrentId(), .Unordered);
        }
        return locking;
    }

    inline fn lock(self: *@This()) void {
        const current_id = Thread.getCurrentId();
        if (self.locking_thread.load(.Unordered) == current_id and current_id != 0) {
            @panic("Deadlock detected");
        }
        self.impl.lock();
        self.locking_thread.store(current_id, .Unordered);
    }

    inline fn unlock(self: *@This()) void {
        assert(self.locking_thread.load(.Unordered) == Thread.getCurrentId());
        self.locking_thread.store(0, .Unordered);
        self.impl.unlock();
    }
};

const SingleThreadedImpl = struct {
    is_locked: bool = false,

    fn tryLock(self: *@This()) bool {
        if (self.is_locked) return false;
        self.is_locked = true;
        return true;
    }

    fn lock(self: *@This()) void {
        if (!self.tryLock()) {
            unreachable; // deadlock detected
        }
    }

    fn unlock(self: *@This()) void {
        assert(self.is_locked);
        self.is_locked = false;
    }
};

// SRWLOCK on windows is almost always faster than Futex solution.
// It also implements an efficient Condition with requeue support for us.
const WindowsImpl = struct {
    srwlock: os.windows.SRWLOCK = .{},

    fn tryLock(self: *@This()) bool {
        return os.windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != os.windows.FALSE;
    }

    fn lock(self: *@This()) void {
        os.windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
    }

    fn unlock(self: *@This()) void {
        os.windows.kernel32.ReleaseSRWLockExclusive(&self.srwlock);
    }
};

// os_unfair_lock on darwin supports priority inheritance and is generally faster than Futex solutions.
const DarwinImpl = struct {
    oul: os.darwin.os_unfair_lock = .{},

    fn tryLock(self: *@This()) bool {
        return os.darwin.os_unfair_lock_trylock(&self.oul);
    }

    fn lock(self: *@This()) void {
        os.darwin.os_unfair_lock_lock(&self.oul);
    }

    fn unlock(self: *@This()) void {
        os.darwin.os_unfair_lock_unlock(&self.oul);
    }
};

const FutexImpl = struct {
    state: Atomic(u32) = Atomic(u32).init(unlocked),

    const unlocked = 0b00;
    const locked = 0b01;
    const contended = 0b11; // must contain the `locked` bit for x86 optimization below

    fn tryLock(self: *@This()) bool {
        // Lock with compareAndSwap instead of tryCompareAndSwap to avoid reporting spurious CAS failure.
        return self.lockFast("compareAndSwap");
    }

    fn lock(self: *@This()) void {
        // Lock with tryCompareAndSwap instead of compareAndSwap due to being more inline-able on LL/SC archs like ARM.
        if (!self.lockFast("tryCompareAndSwap")) {
            self.lockSlow();
        }
    }

    inline fn lockFast(self: *@This(), comptime cas_fn_name: []const u8) bool {
        // On x86, use `lock bts` instead of `lock cmpxchg` as:
        // - they both seem to mark the cache-line as modified regardless: https://stackoverflow.com/a/63350048
        // - `lock bts` is smaller instruction-wise which makes it better for inlining
        if (comptime builtin.target.cpu.arch.isX86()) {
            const locked_bit = @ctz(@as(u32, locked));
            return self.state.bitSet(locked_bit, .Acquire) == 0;
        }

        // Acquire barrier ensures grabbing the lock happens before the critical section
        // and that the previous lock holder's critical section happens before we grab the lock.
        const casFn = @field(@TypeOf(self.state), cas_fn_name);
        return casFn(&self.state, unlocked, locked, .Acquire, .Monotonic) == null;
    }

    fn lockSlow(self: *@This()) void {
        @setCold(true);

        // Avoid doing an atomic swap below if we already know the state is contended.
        // An atomic swap unconditionally stores which marks the cache-line as modified unnecessarily.
        if (self.state.load(.Monotonic) == contended) {
            Futex.wait(&self.state, contended);
        }

        // Try to acquire the lock while also telling the existing lock holder that there are threads waiting.
        //
        // Once we sleep on the Futex, we must acquire the mutex using `contended` rather than `locked`.
        // If not, threads sleeping on the Futex wouldn't see the state change in unlock and potentially deadlock.
        // The downside is that the last mutex unlocker will see `contended` and do an unnecessary Futex wake
        // but this is better than having to wake all waiting threads on mutex unlock.
        //
        // Acquire barrier ensures grabbing the lock happens before the critical section
        // and that the previous lock holder's critical section happens before we grab the lock.
        while (self.state.swap(contended, .Acquire) != unlocked) {
            Futex.wait(&self.state, contended);
        }
    }

    fn unlock(self: *@This()) void {
        // Unlock the mutex and wake up a waiting thread if any.
        //
        // A waiting thread will acquire with `contended` instead of `locked`
        // which ensures that it wakes up another thread on the next unlock().
        //
        // Release barrier ensures the critical section happens before we let go of the lock
        // and that our critical section happens before the next lock holder grabs the lock.
        const state = self.state.swap(unlocked, .Release);
        assert(state != unlocked);

        if (state == contended) {
            Futex.wake(&self.state, 1);
        }
    }
};

test "Mutex - smoke test" {
    var mutex = Mutex{};

    try testing.expect(mutex.tryLock());
    try testing.expect(!mutex.tryLock());
    mutex.unlock();

    mutex.lock();
    try testing.expect(!mutex.tryLock());
    mutex.unlock();
}

// A counter which is incremented without atomic instructions
const NonAtomicCounter = struct {
    // direct u128 could maybe use xmm ops on x86 which are atomic
    value: [2]u64 = [_]u64{ 0, 0 },

    fn get(self: NonAtomicCounter) u128 {
        return @as(u128, @bitCast(self.value));
    }

    fn inc(self: *NonAtomicCounter) void {
        for (@as([2]u64, @bitCast(self.get() + 1)), 0..) |v, i| {
            @as(*volatile u64, @ptrCast(&self.value[i])).* = v;
        }
    }
};

test "Mutex - many uncontended" {
    // This test requires spawning threads.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 4;
    const num_increments = 1000;

    const Runner = struct {
        mutex: Mutex = .{},
        thread: Thread = undefined,
        counter: NonAtomicCounter = .{},

        fn run(self: *@This()) void {
            var i: usize = num_increments;
            while (i > 0) : (i -= 1) {
                self.mutex.lock();
                defer self.mutex.unlock();

                self.counter.inc();
            }
        }
    };

    var runners = [_]Runner{.{}} ** num_threads;
    for (&runners) |*r| r.thread = try Thread.spawn(.{}, Runner.run, .{r});
    for (runners) |r| r.thread.join();
    for (runners) |r| try testing.expectEqual(r.counter.get(), num_increments);
}

test "Mutex - many contended" {
    // This test requires spawning threads.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 4;
    const num_increments = 1000;

    const Runner = struct {
        mutex: Mutex = .{},
        counter: NonAtomicCounter = .{},

        fn run(self: *@This()) void {
            var i: usize = num_increments;
            while (i > 0) : (i -= 1) {
                // Occasionally hint to let another thread run.
                defer if (i % 100 == 0) Thread.yield() catch {};

                self.mutex.lock();
                defer self.mutex.unlock();

                self.counter.inc();
            }
        }
    };

    var runner = Runner{};

    var threads: [num_threads]Thread = undefined;
    for (&threads) |*t| t.* = try Thread.spawn(.{}, Runner.run, .{&runner});
    for (threads) |t| t.join();

    try testing.expectEqual(runner.counter.get(), num_increments * num_threads);
}
