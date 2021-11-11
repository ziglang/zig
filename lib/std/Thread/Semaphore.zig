//! A semaphore is an unsigned integer that blocks the kernel thread if
//! the number would become negative.
//! This API supports static initialization and does not require deinitialization.

mutex: Mutex = .{},
cond: Condition = .{},
/// It is OK to initialize this field to any value.
permits: usize = 0,

const Semaphore = @This();
const std = @import("../std.zig");
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;

pub fn wait(sem: *Semaphore) void {
    sem.mutex.lock();
    defer sem.mutex.unlock();

    while (sem.permits == 0)
        sem.cond.wait(&sem.mutex);

    sem.permits -= 1;
    if (sem.permits > 0)
        sem.cond.signal();
}

pub fn post(sem: *Semaphore) void {
    sem.mutex.lock();
    defer sem.mutex.unlock();

    sem.permits += 1;
    sem.cond.signal();
}
