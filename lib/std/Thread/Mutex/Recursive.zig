//! A synchronization primitive enforcing atomic access to a shared region of
//! code known as the "critical section".
//!
//! Equivalent to `std.Mutex` except it allows the same thread to obtain the
//! lock multiple times.
//!
//! A recursive mutex is an abstraction layer on top of a regular mutex;
//! therefore it is recommended to use instead `std.Mutex` unless there is a
//! specific reason a recursive mutex is warranted.

const std = @import("../../std.zig");
const Recursive = @This();
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

mutex: Mutex,
thread_id: std.Thread.Id,
lock_count: usize,

pub const init: Recursive = .{
    .mutex = .{},
    .thread_id = invalid_thread_id,
    .lock_count = 0,
};

/// Acquires the `Mutex` without blocking the caller's thread.
///
/// Returns `false` if the calling thread would have to block to acquire it.
///
/// Otherwise, returns `true` and the caller should `unlock()` the Mutex to release it.
pub fn tryLock(r: *Recursive) bool {
    const current_thread_id = std.Thread.getCurrentId();
    return tryLockInner(r, current_thread_id);
}

/// Acquires the `Mutex`, blocking the current thread while the mutex is
/// already held by another thread.
///
/// The `Mutex` can be held multiple times by the same thread.
///
/// Once acquired, call `unlock` on the `Mutex` to release it, regardless
/// of whether the lock was already held by the same thread.
pub fn lock(r: *Recursive) void {
    const current_thread_id = std.Thread.getCurrentId();
    if (!tryLockInner(r, current_thread_id)) {
        r.mutex.lock();
        assert(r.lock_count == 0);
        r.lock_count = 1;
        @atomicStore(std.Thread.Id, &r.thread_id, current_thread_id, .monotonic);
    }
}

/// Releases the `Mutex` which was previously acquired with `lock` or `tryLock`.
///
/// It is undefined behavior to unlock from a different thread that it was
/// locked from.
pub fn unlock(r: *Recursive) void {
    r.lock_count -= 1;
    if (r.lock_count == 0) {
        // Prevent race where:
        // * Thread A obtains lock and has not yet stored the new thread id.
        // * Thread B loads the thread id after tryLock() false and observes stale thread id.
        @atomicStore(std.Thread.Id, &r.thread_id, invalid_thread_id, .seq_cst);
        r.mutex.unlock();
    }
}

fn tryLockInner(r: *Recursive, current_thread_id: std.Thread.Id) bool {
    if (r.mutex.tryLock()) {
        assert(r.lock_count == 0);
        r.lock_count = 1;
        @atomicStore(std.Thread.Id, &r.thread_id, current_thread_id, .monotonic);
        return true;
    }

    const locked_thread_id = @atomicLoad(std.Thread.Id, &r.thread_id, .monotonic);
    if (locked_thread_id == current_thread_id) {
        r.lock_count += 1;
        return true;
    }

    return false;
}

/// A value that does not alias any other thread id.
const invalid_thread_id: std.Thread.Id = 0;
