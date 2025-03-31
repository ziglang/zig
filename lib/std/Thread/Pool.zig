const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const WaitGroup = @import("WaitGroup.zig");
const Io = std.Io;
const Pool = @This();

/// Must be a thread-safe allocator.
allocator: std.mem.Allocator,
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: std.SinglyLinkedList = .{},
is_running: bool = true,
threads: std.ArrayListUnmanaged(std.Thread),
ids: if (builtin.single_threaded) struct {
    inline fn deinit(_: @This(), _: std.mem.Allocator) void {}
    fn getIndex(_: @This(), _: std.Thread.Id) usize {
        return 0;
    }
} else std.AutoArrayHashMapUnmanaged(std.Thread.Id, void),
stack_size: usize,

threadlocal var current_closure: ?*AsyncClosure = null;

pub const Runnable = struct {
    runFn: RunProto,
    node: std.SinglyLinkedList.Node = .{},
};

pub const RunProto = *const fn (*Runnable, id: ?usize) void;

pub const Options = struct {
    allocator: std.mem.Allocator,
    n_jobs: ?usize = null,
    track_ids: bool = false,
    stack_size: usize = std.Thread.SpawnConfig.default_stack_size,
};

pub fn init(pool: *Pool, options: Options) !void {
    const gpa = options.allocator;
    const thread_count = options.n_jobs orelse @max(1, std.Thread.getCpuCount() catch 1);
    const threads = try gpa.alloc(std.Thread, thread_count);
    errdefer gpa.free(threads);

    pool.* = .{
        .allocator = gpa,
        .threads = .initBuffer(threads),
        .ids = .{},
        .stack_size = options.stack_size,
    };

    if (builtin.single_threaded) return;

    if (options.track_ids) {
        try pool.ids.ensureTotalCapacity(gpa, 1 + thread_count);
        pool.ids.putAssumeCapacityNoClobber(std.Thread.getCurrentId(), {});
    }
}

pub fn deinit(pool: *Pool) void {
    const gpa = pool.allocator;
    pool.join();
    pool.threads.deinit(gpa);
    pool.ids.deinit(gpa);
    pool.* = undefined;
}

fn join(pool: *Pool) void {
    if (builtin.single_threaded) return;

    {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        // ensure future worker threads exit the dequeue loop
        pool.is_running = false;
    }

    // wake up any sleeping threads (this can be done outside the mutex)
    // then wait for all the threads we know are spawned to complete.
    pool.cond.broadcast();
    for (pool.threads.items) |thread| thread.join();
}

/// Runs `func` in the thread pool, calling `WaitGroup.start` beforehand, and
/// `WaitGroup.finish` after it returns.
///
/// In the case that queuing the function call fails to allocate memory, or the
/// target is single-threaded, the function is called directly.
pub fn spawnWg(pool: *Pool, wait_group: *WaitGroup, comptime func: anytype, args: anytype) void {
    wait_group.start();

    if (builtin.single_threaded) {
        @call(.auto, func, args);
        wait_group.finish();
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *Pool,
        runnable: Runnable = .{ .runFn = runFn },
        wait_group: *WaitGroup,

        fn runFn(runnable: *Runnable, _: ?usize) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("runnable", runnable));
            @call(.auto, func, closure.arguments);
            closure.wait_group.finish();
            closure.pool.allocator.destroy(closure);
        }
    };

    pool.mutex.lock();

    const gpa = pool.allocator;
    const closure = gpa.create(Closure) catch {
        pool.mutex.unlock();
        @call(.auto, func, args);
        wait_group.finish();
        return;
    };
    closure.* = .{
        .arguments = args,
        .pool = pool,
        .wait_group = wait_group,
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < pool.threads.capacity) {
        pool.threads.addOneAssumeCapacity().* = std.Thread.spawn(.{
            .stack_size = pool.stack_size,
            .allocator = gpa,
        }, worker, .{pool}) catch t: {
            pool.threads.items.len -= 1;
            break :t undefined;
        };
    }

    pool.mutex.unlock();
    pool.cond.signal();
}

/// Runs `func` in the thread pool, calling `WaitGroup.start` beforehand, and
/// `WaitGroup.finish` after it returns.
///
/// The first argument passed to `func` is a dense `usize` thread id, the rest
/// of the arguments are passed from `args`. Requires the pool to have been
/// initialized with `.track_ids = true`.
///
/// In the case that queuing the function call fails to allocate memory, or the
/// target is single-threaded, the function is called directly.
pub fn spawnWgId(pool: *Pool, wait_group: *WaitGroup, comptime func: anytype, args: anytype) void {
    wait_group.start();

    if (builtin.single_threaded) {
        @call(.auto, func, .{0} ++ args);
        wait_group.finish();
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *Pool,
        runnable: Runnable = .{ .runFn = runFn },
        wait_group: *WaitGroup,

        fn runFn(runnable: *Runnable, id: ?usize) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("runnable", runnable));
            @call(.auto, func, .{id.?} ++ closure.arguments);
            closure.wait_group.finish();
            closure.pool.allocator.destroy(closure);
        }
    };

    pool.mutex.lock();

    const gpa = pool.allocator;
    const closure = gpa.create(Closure) catch {
        const id: ?usize = pool.ids.getIndex(std.Thread.getCurrentId());
        pool.mutex.unlock();
        @call(.auto, func, .{id.?} ++ args);
        wait_group.finish();
        return;
    };
    closure.* = .{
        .arguments = args,
        .pool = pool,
        .wait_group = wait_group,
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < pool.threads.capacity) {
        pool.threads.addOneAssumeCapacity().* = std.Thread.spawn(.{
            .stack_size = pool.stack_size,
            .allocator = gpa,
        }, worker, .{pool}) catch t: {
            pool.threads.items.len -= 1;
            break :t undefined;
        };
    }

    pool.mutex.unlock();
    pool.cond.signal();
}

pub fn spawn(pool: *Pool, comptime func: anytype, args: anytype) void {
    if (builtin.single_threaded) {
        @call(.auto, func, args);
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *Pool,
        runnable: Runnable = .{ .runFn = runFn },

        fn runFn(runnable: *Runnable, _: ?usize) void {
            const closure: *@This() = @alignCast(@fieldParentPtr("runnable", runnable));
            @call(.auto, func, closure.arguments);
            closure.pool.allocator.destroy(closure);
        }
    };

    pool.mutex.lock();

    const gpa = pool.allocator;
    const closure = gpa.create(Closure) catch {
        pool.mutex.unlock();
        @call(.auto, func, args);
        return;
    };
    closure.* = .{
        .arguments = args,
        .pool = pool,
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < pool.threads.capacity) {
        pool.threads.addOneAssumeCapacity().* = std.Thread.spawn(.{
            .stack_size = pool.stack_size,
            .allocator = gpa,
        }, worker, .{pool}) catch t: {
            pool.threads.items.len -= 1;
            break :t undefined;
        };
    }

    pool.mutex.unlock();
    pool.cond.signal();
}

test spawn {
    const TestFn = struct {
        fn checkRun(completed: *bool) void {
            completed.* = true;
        }
    };

    var completed: bool = false;

    {
        var pool: Pool = undefined;
        try pool.init(.{
            .allocator = std.testing.allocator,
        });
        defer pool.deinit();
        pool.spawn(TestFn.checkRun, .{&completed});
    }

    try std.testing.expectEqual(true, completed);
}

fn worker(pool: *Pool) void {
    pool.mutex.lock();
    defer pool.mutex.unlock();

    const id: ?usize = if (pool.ids.count() > 0) @intCast(pool.ids.count()) else null;
    if (id) |_| pool.ids.putAssumeCapacityNoClobber(std.Thread.getCurrentId(), {});

    while (true) {
        while (pool.run_queue.popFirst()) |run_node| {
            // Temporarily unlock the mutex in order to execute the run_node
            pool.mutex.unlock();
            defer pool.mutex.lock();

            const runnable: *Runnable = @fieldParentPtr("node", run_node);
            runnable.runFn(runnable, id);
        }

        // Stop executing instead of waiting if the thread pool is no longer running.
        if (pool.is_running) {
            pool.cond.wait(&pool.mutex);
        } else {
            break;
        }
    }
}

pub fn waitAndWork(pool: *Pool, wait_group: *WaitGroup) void {
    var id: ?usize = null;

    while (!wait_group.isDone()) {
        pool.mutex.lock();
        if (pool.run_queue.popFirst()) |run_node| {
            id = id orelse pool.ids.getIndex(std.Thread.getCurrentId());
            pool.mutex.unlock();
            const runnable: *Runnable = @fieldParentPtr("node", run_node);
            runnable.runFn(runnable, id);
            continue;
        }

        pool.mutex.unlock();
        wait_group.wait();
        return;
    }
}

pub fn getIdCount(pool: *Pool) usize {
    return @intCast(1 + pool.threads.items.len);
}

pub fn io(pool: *Pool) Io {
    return .{
        .userdata = pool,
        .vtable = &.{
            .@"async" = @"async",
            .@"await" = @"await",
            .go = go,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .mutexLock = mutexLock,
            .mutexUnlock = mutexUnlock,
            .conditionWait = conditionWait,
            .conditionWake = conditionWake,

            .createFile = createFile,
            .openFile = openFile,
            .closeFile = closeFile,
            .pread = pread,
            .pwrite = pwrite,

            .now = now,
            .sleep = sleep,
        },
    };
}

const AsyncClosure = struct {
    func: *const fn (context: *anyopaque, result: *anyopaque) void,
    runnable: Runnable = .{ .runFn = runFn },
    reset_event: std.Thread.ResetEvent,
    cancel_tid: std.Thread.Id,
    context_offset: usize,
    result_offset: usize,

    const canceling_tid: std.Thread.Id = switch (@typeInfo(std.Thread.Id)) {
        .int => |int_info| switch (int_info.signedness) {
            .signed => -1,
            .unsigned => std.math.maxInt(std.Thread.Id),
        },
        .pointer => @ptrFromInt(std.math.maxInt(usize)),
        else => @compileError("unsupported std.Thread.Id: " ++ @typeName(std.Thread.Id)),
    };

    fn runFn(runnable: *std.Thread.Pool.Runnable, _: ?usize) void {
        const closure: *AsyncClosure = @alignCast(@fieldParentPtr("runnable", runnable));
        const tid = std.Thread.getCurrentId();
        if (@cmpxchgStrong(
            std.Thread.Id,
            &closure.cancel_tid,
            0,
            tid,
            .acq_rel,
            .acquire,
        )) |cancel_tid| {
            assert(cancel_tid == canceling_tid);
            return;
        }
        current_closure = closure;
        closure.func(closure.contextPointer(), closure.resultPointer());
        current_closure = null;
        if (@cmpxchgStrong(
            std.Thread.Id,
            &closure.cancel_tid,
            tid,
            0,
            .acq_rel,
            .acquire,
        )) |cancel_tid| assert(cancel_tid == canceling_tid);
        closure.reset_event.set();
    }

    fn contextOffset(context_alignment: std.mem.Alignment) usize {
        return context_alignment.forward(@sizeOf(AsyncClosure));
    }

    fn resultOffset(
        context_alignment: std.mem.Alignment,
        context_len: usize,
        result_alignment: std.mem.Alignment,
    ) usize {
        return result_alignment.forward(contextOffset(context_alignment) + context_len);
    }

    fn resultPointer(closure: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(closure);
        return base + closure.result_offset;
    }

    fn contextPointer(closure: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(closure);
        return base + closure.context_offset;
    }

    fn waitAndFree(closure: *AsyncClosure, gpa: Allocator, result: []u8) void {
        closure.reset_event.wait();
        const base: [*]align(@alignOf(AsyncClosure)) u8 = @ptrCast(closure);
        @memcpy(result, closure.resultPointer()[0..result.len]);
        gpa.free(base[0 .. closure.result_offset + result.len]);
    }
};

fn @"async"(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*Io.AnyFuture {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    pool.mutex.lock();

    const gpa = pool.allocator;
    const context_offset = context_alignment.forward(@sizeOf(AsyncClosure));
    const result_offset = result_alignment.forward(context_offset + context.len);
    const n = result_offset + result.len;
    const closure: *AsyncClosure = @alignCast(@ptrCast(gpa.alignedAlloc(u8, @alignOf(AsyncClosure), n) catch {
        pool.mutex.unlock();
        start(context.ptr, result.ptr);
        return null;
    }));
    closure.* = .{
        .func = start,
        .context_offset = context_offset,
        .result_offset = result_offset,
        .reset_event = .{},
        .cancel_tid = 0,
    };
    @memcpy(closure.contextPointer()[0..context.len], context);
    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < pool.threads.capacity) {
        pool.threads.addOneAssumeCapacity().* = std.Thread.spawn(.{
            .stack_size = pool.stack_size,
            .allocator = gpa,
        }, worker, .{pool}) catch t: {
            pool.threads.items.len -= 1;
            break :t undefined;
        };
    }

    pool.mutex.unlock();
    pool.cond.signal();

    return @ptrCast(closure);
}

const DetachedClosure = struct {
    pool: *Pool,
    func: *const fn (context: *anyopaque) void,
    run_node: std.Thread.Pool.RunQueue.Node = .{ .data = .{ .runFn = runFn } },
    context_alignment: std.mem.Alignment,
    context_len: usize,

    fn runFn(runnable: *std.Thread.Pool.Runnable, _: ?usize) void {
        const run_node: *std.Thread.Pool.RunQueue.Node = @fieldParentPtr("data", runnable);
        const closure: *DetachedClosure = @alignCast(@fieldParentPtr("run_node", run_node));
        closure.func(closure.contextPointer());
        const gpa = closure.pool.allocator;
        const base: [*]align(@alignOf(DetachedClosure)) u8 = @ptrCast(closure);
        gpa.free(base[0..contextEnd(closure.context_alignment, closure.context_len)]);
    }

    fn contextOffset(context_alignment: std.mem.Alignment) usize {
        return context_alignment.forward(@sizeOf(DetachedClosure));
    }

    fn contextEnd(context_alignment: std.mem.Alignment, context_len: usize) usize {
        return contextOffset(context_alignment) + context_len;
    }

    fn contextPointer(closure: *DetachedClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(closure);
        return base + contextOffset(closure.context_alignment);
    }
};

fn go(
    userdata: ?*anyopaque,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque) void,
) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    pool.mutex.lock();

    const gpa = pool.allocator;
    const n = DetachedClosure.contextEnd(context_alignment, context.len);
    const closure: *DetachedClosure = @alignCast(@ptrCast(gpa.alignedAlloc(u8, @alignOf(DetachedClosure), n) catch {
        pool.mutex.unlock();
        start(context.ptr);
        return;
    }));
    closure.* = .{
        .pool = pool,
        .func = start,
        .context_alignment = context_alignment,
        .context_len = context.len,
    };
    @memcpy(closure.contextPointer()[0..context.len], context);
    pool.run_queue.prepend(&closure.run_node);

    if (pool.threads.items.len < pool.threads.capacity) {
        pool.threads.addOneAssumeCapacity().* = std.Thread.spawn(.{
            .stack_size = pool.stack_size,
            .allocator = gpa,
        }, worker, .{pool}) catch t: {
            pool.threads.items.len -= 1;
            break :t undefined;
        };
    }

    pool.mutex.unlock();
    pool.cond.signal();
}

fn @"await"(
    userdata: ?*anyopaque,
    any_future: *std.Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    _ = result_alignment;
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    closure.waitAndFree(pool.allocator, result);
}

fn cancel(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    _ = result_alignment;
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    switch (@atomicRmw(
        std.Thread.Id,
        &closure.cancel_tid,
        .Xchg,
        AsyncClosure.canceling_tid,
        .acq_rel,
    )) {
        0, AsyncClosure.canceling_tid => {},
        else => |cancel_tid| switch (builtin.os.tag) {
            .linux => _ = std.os.linux.tgkill(
                std.os.linux.getpid(),
                @bitCast(cancel_tid),
                std.posix.SIG.IO,
            ),
            else => {},
        },
    }
    closure.waitAndFree(pool.allocator, result);
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    const closure = current_closure orelse return false;
    return @atomicLoad(std.Thread.Id, &closure.cancel_tid, .acquire) == AsyncClosure.canceling_tid;
}

fn checkCancel(pool: *Pool) error{Canceled}!void {
    if (cancelRequested(pool)) return error.Canceled;
}

fn mutexLock(userdata: ?*anyopaque, m: *Io.Mutex) void {
    @branchHint(.cold);
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;

    // Avoid doing an atomic swap below if we already know the state is contended.
    // An atomic swap unconditionally stores which marks the cache-line as modified unnecessarily.
    if (m.state.load(.monotonic) == Io.Mutex.contended) {
        std.Thread.Futex.wait(&m.state, Io.Mutex.contended);
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
    while (m.state.swap(Io.Mutex.contended, .acquire) != Io.Mutex.unlocked) {
        std.Thread.Futex.wait(&m.state, Io.Mutex.contended);
    }
}

fn mutexUnlock(userdata: ?*anyopaque, m: *Io.Mutex) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    // Needs to also wake up a waiting thread if any.
    //
    // A waiting thread will acquire with `contended` instead of `locked`
    // which ensures that it wakes up another thread on the next unlock().
    //
    // Release barrier ensures the critical section happens before we let go of the lock
    // and that our critical section happens before the next lock holder grabs the lock.
    const state = m.state.swap(Io.Mutex.unlocked, .release);
    assert(state != Io.Mutex.unlocked);

    if (state == Io.Mutex.contended) {
        std.Thread.Futex.wake(&m.state, 1);
    }
}

fn mutexLockInternal(pool: *std.Thread.Pool, m: *Io.Mutex) void {
    if (!m.tryLock()) {
        @branchHint(.unlikely);
        mutexLock(pool, m);
    }
}

fn conditionWait(
    userdata: ?*anyopaque,
    cond: *Io.Condition,
    mutex: *Io.Mutex,
    timeout: ?u64,
) Io.Condition.WaitError!void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    comptime assert(@TypeOf(cond.state) == u64);
    const ints: *[2]std.atomic.Value(u32) = @ptrCast(&cond.state);
    const cond_state = &ints[0];
    const cond_epoch = &ints[1];
    const one_waiter = 1;
    const waiter_mask = 0xffff;
    const one_signal = 1 << 16;
    const signal_mask = 0xffff << 16;
    // Observe the epoch, then check the state again to see if we should wake up.
    // The epoch must be observed before we check the state or we could potentially miss a wake() and deadlock:
    //
    // - T1: s = LOAD(&state)
    // - T2: UPDATE(&s, signal)
    // - T2: UPDATE(&epoch, 1) + FUTEX_WAKE(&epoch)
    // - T1: e = LOAD(&epoch) (was reordered after the state load)
    // - T1: s & signals == 0 -> FUTEX_WAIT(&epoch, e) (missed the state update + the epoch change)
    //
    // Acquire barrier to ensure the epoch load happens before the state load.
    var epoch = cond_epoch.load(.acquire);
    var state = cond_state.fetchAdd(one_waiter, .monotonic);
    assert(state & waiter_mask != waiter_mask);
    state += one_waiter;

    mutexUnlock(pool, mutex);
    defer mutexLockInternal(pool, mutex);

    var futex_deadline = std.Thread.Futex.Deadline.init(timeout);

    while (true) {
        futex_deadline.wait(cond_epoch, epoch) catch |err| switch (err) {
            // On timeout, we must decrement the waiter we added above.
            error.Timeout => {
                while (true) {
                    // If there's a signal when we're timing out, consume it and report being woken up instead.
                    // Acquire barrier ensures code before the wake() which added the signal happens before we decrement it and return.
                    while (state & signal_mask != 0) {
                        const new_state = state - one_waiter - one_signal;
                        state = cond_state.cmpxchgWeak(state, new_state, .acquire, .monotonic) orelse return;
                    }

                    // Remove the waiter we added and officially return timed out.
                    const new_state = state - one_waiter;
                    state = cond_state.cmpxchgWeak(state, new_state, .monotonic, .monotonic) orelse return err;
                }
            },
        };

        epoch = cond_epoch.load(.acquire);
        state = cond_state.load(.monotonic);

        // Try to wake up by consuming a signal and decremented the waiter we added previously.
        // Acquire barrier ensures code before the wake() which added the signal happens before we decrement it and return.
        while (state & signal_mask != 0) {
            const new_state = state - one_waiter - one_signal;
            state = cond_state.cmpxchgWeak(state, new_state, .acquire, .monotonic) orelse return;
        }
    }
}

fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, notify: Io.Condition.Notify) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    comptime assert(@TypeOf(cond.state) == u64);
    const ints: *[2]std.atomic.Value(u32) = @ptrCast(&cond.state);
    const cond_state = &ints[0];
    const cond_epoch = &ints[1];
    const one_waiter = 1;
    const waiter_mask = 0xffff;
    const one_signal = 1 << 16;
    const signal_mask = 0xffff << 16;
    var state = cond_state.load(.monotonic);
    while (true) {
        const waiters = (state & waiter_mask) / one_waiter;
        const signals = (state & signal_mask) / one_signal;

        // Reserves which waiters to wake up by incrementing the signals count.
        // Therefore, the signals count is always less than or equal to the waiters count.
        // We don't need to Futex.wake if there's nothing to wake up or if other wake() threads have reserved to wake up the current waiters.
        const wakeable = waiters - signals;
        if (wakeable == 0) {
            return;
        }

        const to_wake = switch (notify) {
            .one => 1,
            .all => wakeable,
        };

        // Reserve the amount of waiters to wake by incrementing the signals count.
        // Release barrier ensures code before the wake() happens before the signal it posted and consumed by the wait() threads.
        const new_state = state + (one_signal * to_wake);
        state = cond_state.cmpxchgWeak(state, new_state, .release, .monotonic) orelse {
            // Wake up the waiting threads we reserved above by changing the epoch value.
            // NOTE: a waiting thread could miss a wake up if *exactly* ((1<<32)-1) wake()s happen between it observing the epoch and sleeping on it.
            // This is very unlikely due to how many precise amount of Futex.wake() calls that would be between the waiting thread's potential preemption.
            //
            // Release barrier ensures the signal being added to the state happens before the epoch is changed.
            // If not, the waiting thread could potentially deadlock from missing both the state and epoch change:
            //
            // - T2: UPDATE(&epoch, 1) (reordered before the state change)
            // - T1: e = LOAD(&epoch)
            // - T1: s = LOAD(&state)
            // - T2: UPDATE(&state, signal) + FUTEX_WAKE(&epoch)
            // - T1: s & signals == 0 -> FUTEX_WAIT(&epoch, e) (missed both epoch change and state change)
            _ = cond_epoch.fetchAdd(1, .release);
            std.Thread.Futex.wake(cond_epoch, to_wake);
            return;
        };
    }
}

fn createFile(
    userdata: ?*anyopaque,
    dir: std.fs.Dir,
    sub_path: []const u8,
    flags: std.fs.File.CreateFlags,
) Io.FileOpenError!std.fs.File {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return dir.createFile(sub_path, flags);
}

fn openFile(
    userdata: ?*anyopaque,
    dir: std.fs.Dir,
    sub_path: []const u8,
    flags: std.fs.File.OpenFlags,
) Io.FileOpenError!std.fs.File {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return dir.openFile(sub_path, flags);
}

fn closeFile(userdata: ?*anyopaque, file: std.fs.File) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    return file.close();
}

fn pread(userdata: ?*anyopaque, file: std.fs.File, buffer: []u8, offset: std.posix.off_t) Io.FilePReadError!usize {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return switch (offset) {
        -1 => file.read(buffer),
        else => file.pread(buffer, @bitCast(offset)),
    };
}

fn pwrite(userdata: ?*anyopaque, file: std.fs.File, buffer: []const u8, offset: std.posix.off_t) Io.FilePWriteError!usize {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return switch (offset) {
        -1 => file.write(buffer),
        else => file.pwrite(buffer, @bitCast(offset)),
    };
}

pub fn now(userdata: ?*anyopaque, clockid: std.posix.clockid_t) Io.ClockGetTimeError!Io.Timestamp {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const timespec = try std.posix.clock_gettime(clockid);
    return @enumFromInt(@as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec);
}

pub fn sleep(userdata: ?*anyopaque, clockid: std.posix.clockid_t, deadline: Io.Deadline) Io.SleepError!void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const deadline_nanoseconds: i96 = switch (deadline) {
        .nanoseconds => |nanoseconds| nanoseconds,
        .timestamp => |timestamp| @intFromEnum(timestamp),
    };
    var timespec: std.posix.timespec = .{
        .sec = @intCast(@divFloor(deadline_nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(deadline_nanoseconds, std.time.ns_per_s)),
    };
    while (true) {
        try pool.checkCancel();
        switch (std.os.linux.E.init(std.os.linux.clock_nanosleep(clockid, .{ .ABSTIME = switch (deadline) {
            .nanoseconds => false,
            .timestamp => true,
        } }, &timespec, &timespec))) {
            .SUCCESS => return,
            .FAULT => unreachable,
            .INTR => {},
            .INVAL => return error.UnsupportedClock,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }
}
