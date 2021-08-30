const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Mutex = @This();

impl: Impl = .{},

pub fn tryAcquire(self: *Mutex) ?Held {
    if (self.impl.tryAcquire()) return Held{ .lock = self };
    return null;
}

pub fn acquire(self: *Mutex) Held {
    self.impl.acquire();
    return Held{ .lock = self };
}

pub const Held = struct {
    lock: *Mutex,

    pub fn release(self: Held) void {
        self.lock.impl.release();
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
    srwlock: os.windows.SWRLOCK = os.windows.SRWLOCK_INIT,

    pub fn tryAcquire(self: *Impl) bool {
        const rc = os.windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock);
        return rc != os.windows.FALSE;
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

const FutexImpl = struct {
    state: Atomic(u32) = Atomic(u32).init(UNLOCKED),

    const UNLOCKED = 0;
    const LOCKED = 0b01;
    const CONTENDED = 0b11;

    pub fn tryAcquire(self: *Impl) bool {
        // On x86, "lock bts" uses less i-cache & can be faster than "lock cmpxchg" below.
        if (comptime target.cpu.arch.isX86()) {
            return self.state.bitSet(@ctz(u32, LOCKED), .Acquire) == UNLOCKED;
        }

        return self.state.compareAndSwap(
            UNLOCKED,
            LOCKED,
            .Acquire,
            .Monotonic,
        ) == null;  
    }  
    
    pub fn acquire(self: *Impl) void {
        if (self.tryAcquire()) {
            return;
        }

        /// Spin a little bit on the Mutex state in the hopes that
        /// we can acquire it without having to call Futex.wait().
        /// This helps acquire() latency under micro-contention.
        /// This also gives up spinning if the Mutex is contended.
        var spin: u8 = 100;
        while (spin > 0) : (spin -= 1) {
            std.atomic.spinLoopHint();

            switch (self.state.load(.Monotonic)) {
                UNLOCKED => if (self.tryAcquire()) return,
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
            switch (self.state.swap(CONTENDED, .Acquire)) {
                UNLOCKED => return,
                LOCKED, CONTENDED => continue,
                else => unreachable, // invalid Mutex state
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