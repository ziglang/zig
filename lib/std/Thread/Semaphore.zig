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
const builtin = @import("builtin");
const testing = std.testing;

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

test "Thread.Semaphore" {
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const TestContext = struct {
        sem: *Semaphore,
        n: *i32,
        fn worker(ctx: *@This()) void {
            ctx.sem.wait();
            ctx.n.* += 1;
            ctx.sem.post();
        }
    };
    const num_threads = 3;
    var sem = Semaphore{ .permits = 1 };
    var threads: [num_threads]std.Thread = undefined;
    var n: i32 = 0;
    var ctx = TestContext{ .sem = &sem, .n = &n };

    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, TestContext.worker, .{&ctx});
    for (threads) |t| t.join();
    sem.wait();
    try testing.expect(n == num_threads);
}
