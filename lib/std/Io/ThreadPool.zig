const builtin = @import("builtin");
const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const WaitGroup = std.Thread.WaitGroup;
const Io = std.Io;
const Pool = @This();

/// Thread-safe.
allocator: Allocator,
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: std.SinglyLinkedList = .{},
join_requested: bool = false,
threads: std.ArrayListUnmanaged(std.Thread),
stack_size: usize,
cpu_count: std.Thread.CpuCountError!usize,
parallel_count: usize,

threadlocal var current_closure: ?*AsyncClosure = null;

pub const Runnable = struct {
    start: Start,
    node: std.SinglyLinkedList.Node = .{},
    is_parallel: bool,

    pub const Start = *const fn (*Runnable) void;
};

pub const InitError = std.Thread.CpuCountError || Allocator.Error;

pub fn init(gpa: Allocator) Pool {
    var pool: Pool = .{
        .allocator = gpa,
        .threads = .empty,
        .stack_size = std.Thread.SpawnConfig.default_stack_size,
        .cpu_count = std.Thread.getCpuCount(),
        .parallel_count = 0,
    };
    if (pool.cpu_count) |n| {
        pool.threads.ensureTotalCapacityPrecise(gpa, n - 1) catch {};
    } else |_| {}
    return pool;
}

pub fn deinit(pool: *Pool) void {
    const gpa = pool.allocator;
    pool.join();
    pool.threads.deinit(gpa);
    pool.* = undefined;
}

fn join(pool: *Pool) void {
    if (builtin.single_threaded) return;
    {
        pool.mutex.lock();
        defer pool.mutex.unlock();
        pool.join_requested = true;
    }
    pool.cond.broadcast();
    for (pool.threads.items) |thread| thread.join();
}

fn worker(pool: *Pool) void {
    pool.mutex.lock();
    defer pool.mutex.unlock();

    while (true) {
        while (pool.run_queue.popFirst()) |run_node| {
            pool.mutex.unlock();
            const runnable: *Runnable = @fieldParentPtr("node", run_node);
            runnable.start(runnable);
            pool.mutex.lock();
            if (runnable.is_parallel) {
                // TODO also pop thread and join sometimes
                pool.parallel_count -= 1;
            }
        }
        if (pool.join_requested) break;
        pool.cond.wait(&pool.mutex);
    }
}

pub fn io(pool: *Pool) Io {
    return .{
        .userdata = pool,
        .vtable = &.{
            .async = async,
            .asyncConcurrent = asyncConcurrent,
            .await = await,
            .asyncDetached = asyncDetached,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,

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
    runnable: Runnable,
    reset_event: std.Thread.ResetEvent,
    select_condition: ?*std.Thread.ResetEvent,
    cancel_tid: std.Thread.Id,
    context_offset: usize,
    result_offset: usize,

    const done_reset_event: *std.Thread.ResetEvent = @ptrFromInt(@alignOf(std.Thread.ResetEvent));

    const canceling_tid: std.Thread.Id = switch (@typeInfo(std.Thread.Id)) {
        .int => |int_info| switch (int_info.signedness) {
            .signed => -1,
            .unsigned => std.math.maxInt(std.Thread.Id),
        },
        .pointer => @ptrFromInt(std.math.maxInt(usize)),
        else => @compileError("unsupported std.Thread.Id: " ++ @typeName(std.Thread.Id)),
    };

    fn start(runnable: *Runnable) void {
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
            closure.reset_event.set();
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

        if (@atomicRmw(
            ?*std.Thread.ResetEvent,
            &closure.select_condition,
            .Xchg,
            done_reset_event,
            .release,
        )) |select_reset| {
            assert(select_reset != done_reset_event);
            select_reset.set();
        }
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
        @memcpy(result, closure.resultPointer()[0..result.len]);
        free(closure, gpa, result.len);
    }

    fn free(closure: *AsyncClosure, gpa: Allocator, result_len: usize) void {
        const base: [*]align(@alignOf(AsyncClosure)) u8 = @ptrCast(closure);
        gpa.free(base[0 .. closure.result_offset + result_len]);
    }
};

fn async(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*Io.AnyFuture {
    if (builtin.single_threaded) {
        start(context.ptr, result.ptr);
        return null;
    }
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    const cpu_count = pool.cpu_count catch {
        return asyncConcurrent(userdata, result.len, result_alignment, context, context_alignment, start) catch {
            start(context.ptr, result.ptr);
            return null;
        };
    };
    const gpa = pool.allocator;
    const context_offset = context_alignment.forward(@sizeOf(AsyncClosure));
    const result_offset = result_alignment.forward(context_offset + context.len);
    const n = result_offset + result.len;
    const closure: *AsyncClosure = @alignCast(@ptrCast(gpa.alignedAlloc(u8, .of(AsyncClosure), n) catch {
        start(context.ptr, result.ptr);
        return null;
    }));

    closure.* = .{
        .func = start,
        .context_offset = context_offset,
        .result_offset = result_offset,
        .reset_event = .{},
        .cancel_tid = 0,
        .select_condition = null,
        .runnable = .{
            .start = AsyncClosure.start,
            .is_parallel = false,
        },
    };

    @memcpy(closure.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    const thread_capacity = cpu_count - 1 + pool.parallel_count;

    pool.threads.ensureTotalCapacityPrecise(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        closure.free(gpa, result.len);
        start(context.ptr, result.ptr);
        return null;
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            if (pool.threads.items.len == 0) {
                assert(pool.run_queue.popFirst() == &closure.runnable.node);
                pool.mutex.unlock();
                closure.free(gpa, result.len);
                start(context.ptr, result.ptr);
                return null;
            }
            // Rely on other workers to do it.
            pool.mutex.unlock();
            pool.cond.signal();
            return @ptrCast(closure);
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    pool.mutex.unlock();
    pool.cond.signal();
    return @ptrCast(closure);
}

fn asyncConcurrent(
    userdata: ?*anyopaque,
    result_len: usize,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) error{OutOfMemory}!*Io.AnyFuture {
    if (builtin.single_threaded) unreachable;

    const pool: *Pool = @alignCast(@ptrCast(userdata));
    const cpu_count = pool.cpu_count catch 1;
    const gpa = pool.allocator;
    const context_offset = context_alignment.forward(@sizeOf(AsyncClosure));
    const result_offset = result_alignment.forward(context_offset + context.len);
    const n = result_offset + result_len;
    const closure: *AsyncClosure = @alignCast(@ptrCast(try gpa.alignedAlloc(u8, .of(AsyncClosure), n)));

    closure.* = .{
        .func = start,
        .context_offset = context_offset,
        .result_offset = result_offset,
        .reset_event = .{},
        .cancel_tid = 0,
        .select_condition = null,
        .runnable = .{
            .start = AsyncClosure.start,
            .is_parallel = true,
        },
    };
    @memcpy(closure.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    pool.parallel_count += 1;
    const thread_capacity = cpu_count - 1 + pool.parallel_count;

    pool.threads.ensureTotalCapacity(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        closure.free(gpa, result_len);
        return error.OutOfMemory;
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            assert(pool.run_queue.popFirst() == &closure.runnable.node);
            pool.mutex.unlock();
            closure.free(gpa, result_len);
            return error.OutOfMemory;
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    pool.mutex.unlock();
    pool.cond.signal();
    return @ptrCast(closure);
}

const DetachedClosure = struct {
    pool: *Pool,
    func: *const fn (context: *anyopaque) void,
    runnable: Runnable,
    context_alignment: std.mem.Alignment,
    context_len: usize,

    fn start(runnable: *Runnable) void {
        const closure: *DetachedClosure = @alignCast(@fieldParentPtr("runnable", runnable));
        closure.func(closure.contextPointer());
        const gpa = closure.pool.allocator;
        free(closure, gpa);
    }

    fn free(closure: *DetachedClosure, gpa: Allocator) void {
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

fn asyncDetached(
    userdata: ?*anyopaque,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque) void,
) void {
    if (builtin.single_threaded) return start(context.ptr);
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    const cpu_count = pool.cpu_count catch 1;
    const gpa = pool.allocator;
    const n = DetachedClosure.contextEnd(context_alignment, context.len);
    const closure: *DetachedClosure = @alignCast(@ptrCast(gpa.alignedAlloc(u8, .of(DetachedClosure), n) catch {
        return start(context.ptr);
    }));
    closure.* = .{
        .pool = pool,
        .func = start,
        .context_alignment = context_alignment,
        .context_len = context.len,
        .runnable = .{
            .start = DetachedClosure.start,
            .is_parallel = false,
        },
    };
    @memcpy(closure.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    const thread_capacity = cpu_count - 1 + pool.parallel_count;

    pool.threads.ensureTotalCapacityPrecise(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        closure.free(gpa);
        return start(context.ptr);
    };

    pool.run_queue.prepend(&closure.runnable.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            assert(pool.run_queue.popFirst() == &closure.runnable.node);
            pool.mutex.unlock();
            closure.free(gpa);
            return start(context.ptr);
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    pool.mutex.unlock();
    pool.cond.signal();
}

fn await(
    userdata: ?*anyopaque,
    any_future: *std.Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    _ = result_alignment;
    const pool: *Pool = @alignCast(@ptrCast(userdata));
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
    const pool: *Pool = @alignCast(@ptrCast(userdata));
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
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    const closure = current_closure orelse return false;
    return @atomicLoad(std.Thread.Id, &closure.cancel_tid, .acquire) == AsyncClosure.canceling_tid;
}

fn checkCancel(pool: *Pool) error{Canceled}!void {
    if (cancelRequested(pool)) return error.Canceled;
}

fn mutexLock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) error{Canceled}!void {
    _ = userdata;
    if (prev_state == .contended) {
        std.Thread.Futex.wait(@ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
    while (@atomicRmw(
        Io.Mutex.State,
        &mutex.state,
        .Xchg,
        .contended,
        .acquire,
    ) != .unlocked) {
        std.Thread.Futex.wait(@ptrCast(&mutex.state), @intFromEnum(Io.Mutex.State.contended));
    }
}
fn mutexUnlock(userdata: ?*anyopaque, prev_state: Io.Mutex.State, mutex: *Io.Mutex) void {
    _ = userdata;
    _ = prev_state;
    if (@atomicRmw(Io.Mutex.State, &mutex.state, .Xchg, .unlocked, .release) == .contended) {
        std.Thread.Futex.wake(@ptrCast(&mutex.state), 1);
    }
}

fn conditionWait(userdata: ?*anyopaque, cond: *Io.Condition, mutex: *Io.Mutex) Io.Cancelable!void {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
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

    mutex.unlock(pool.io());
    defer mutex.lock(pool.io()) catch @panic("TODO");

    var futex_deadline = std.Thread.Futex.Deadline.init(null);

    while (true) {
        futex_deadline.wait(cond_epoch, epoch) catch |err| switch (err) {
            error.Timeout => unreachable,
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

fn conditionWake(userdata: ?*anyopaque, cond: *Io.Condition, wake: Io.Condition.Wake) void {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
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

        const to_wake = switch (wake) {
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
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.CreateFlags,
) Io.File.OpenError!Io.File {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const fs_dir: std.fs.Dir = .{ .fd = dir.handle };
    const fs_file = try fs_dir.createFile(sub_path, flags);
    return .{ .handle = fs_file.handle };
}

fn openFile(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const fs_dir: std.fs.Dir = .{ .fd = dir.handle };
    const fs_file = try fs_dir.openFile(sub_path, flags);
    return .{ .handle = fs_file.handle };
}

fn closeFile(userdata: ?*anyopaque, file: Io.File) void {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    const fs_file: std.fs.File = .{ .handle = file.handle };
    return fs_file.close();
}

fn pread(userdata: ?*anyopaque, file: Io.File, buffer: []u8, offset: std.posix.off_t) Io.File.PReadError!usize {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const fs_file: std.fs.File = .{ .handle = file.handle };
    return switch (offset) {
        -1 => fs_file.read(buffer),
        else => fs_file.pread(buffer, @bitCast(offset)),
    };
}

fn pwrite(userdata: ?*anyopaque, file: Io.File, buffer: []const u8, offset: std.posix.off_t) Io.File.PWriteError!usize {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const fs_file: std.fs.File = .{ .handle = file.handle };
    return switch (offset) {
        -1 => fs_file.write(buffer),
        else => fs_file.pwrite(buffer, @bitCast(offset)),
    };
}

fn now(userdata: ?*anyopaque, clockid: std.posix.clockid_t) Io.ClockGetTimeError!Io.Timestamp {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    const timespec = try std.posix.clock_gettime(clockid);
    return @enumFromInt(@as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec);
}

fn sleep(userdata: ?*anyopaque, clockid: std.posix.clockid_t, deadline: Io.Deadline) Io.SleepError!void {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    const deadline_nanoseconds: i96 = switch (deadline) {
        .duration => |duration| duration.nanoseconds,
        .timestamp => |timestamp| @intFromEnum(timestamp),
    };
    var timespec: std.posix.timespec = .{
        .sec = @intCast(@divFloor(deadline_nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(deadline_nanoseconds, std.time.ns_per_s)),
    };
    while (true) {
        try pool.checkCancel();
        switch (std.os.linux.E.init(std.os.linux.clock_nanosleep(clockid, .{ .ABSTIME = switch (deadline) {
            .duration => false,
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

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) usize {
    const pool: *Pool = @alignCast(@ptrCast(userdata));
    _ = pool;

    var reset_event: std.Thread.ResetEvent = .{};

    for (futures, 0..) |future, i| {
        const closure: *AsyncClosure = @ptrCast(@alignCast(future));
        if (@atomicRmw(?*std.Thread.ResetEvent, &closure.select_condition, .Xchg, &reset_event, .seq_cst) == AsyncClosure.done_reset_event) {
            for (futures[0..i]) |cleanup_future| {
                const cleanup_closure: *AsyncClosure = @ptrCast(@alignCast(cleanup_future));
                if (@atomicRmw(?*std.Thread.ResetEvent, &cleanup_closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
                    cleanup_closure.reset_event.wait(); // Ensure no reference to our stack-allocated reset_event.
                }
            }
            return i;
        }
    }

    reset_event.wait();

    var result: ?usize = null;
    for (futures, 0..) |future, i| {
        const closure: *AsyncClosure = @ptrCast(@alignCast(future));
        if (@atomicRmw(?*std.Thread.ResetEvent, &closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
            closure.reset_event.wait(); // Ensure no reference to our stack-allocated reset_event.
            if (result == null) result = i; // In case multiple are ready, return first.
        }
    }
    return result.?;
}
