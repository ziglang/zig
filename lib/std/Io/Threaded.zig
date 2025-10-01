const Pool = @This();

const builtin = @import("builtin");
const native_os = builtin.os.tag;
const is_windows = native_os == .windows;
const windows = std.os.windows;

const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const posix = std.posix;
const Io = std.Io;
const ResetEvent = std.Thread.ResetEvent;

/// Thread-safe.
allocator: Allocator,
mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: std.SinglyLinkedList = .{},
join_requested: bool = false,
threads: std.ArrayListUnmanaged(std.Thread),
stack_size: usize,
cpu_count: std.Thread.CpuCountError!usize,
concurrent_count: usize,

threadlocal var current_closure: ?*Closure = null;

const max_iovecs_len = 8;
const splat_buffer_size = 64;

comptime {
    assert(max_iovecs_len <= posix.IOV_MAX);
}

const Closure = struct {
    start: Start,
    node: std.SinglyLinkedList.Node = .{},
    cancel_tid: std.Thread.Id,
    /// Whether this task bumps minimum number of threads in the pool.
    is_concurrent: bool,

    const Start = *const fn (*Closure) void;

    const canceling_tid: std.Thread.Id = switch (@typeInfo(std.Thread.Id)) {
        .int => |int_info| switch (int_info.signedness) {
            .signed => -1,
            .unsigned => std.math.maxInt(std.Thread.Id),
        },
        .pointer => @ptrFromInt(std.math.maxInt(usize)),
        else => @compileError("unsupported std.Thread.Id: " ++ @typeName(std.Thread.Id)),
    };

    fn requestCancel(closure: *Closure) void {
        switch (@atomicRmw(std.Thread.Id, &closure.cancel_tid, .Xchg, canceling_tid, .acq_rel)) {
            0, canceling_tid => {},
            else => |tid| switch (builtin.os.tag) {
                .linux => _ = std.os.linux.tgkill(std.os.linux.getpid(), @bitCast(tid), posix.SIG.IO),
                else => {},
            },
        }
    }
};

pub const InitError = std.Thread.CpuCountError || Allocator.Error;

pub fn init(gpa: Allocator) Pool {
    var pool: Pool = .{
        .allocator = gpa,
        .threads = .empty,
        .stack_size = std.Thread.SpawnConfig.default_stack_size,
        .cpu_count = std.Thread.getCpuCount(),
        .concurrent_count = 0,
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
        while (pool.run_queue.popFirst()) |closure_node| {
            pool.mutex.unlock();
            const closure: *Closure = @fieldParentPtr("node", closure_node);
            const is_concurrent = closure.is_concurrent;
            closure.start(closure);
            pool.mutex.lock();
            if (is_concurrent) {
                // TODO also pop thread and join sometimes
                pool.concurrent_count -= 1;
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
            .concurrent = concurrent,
            .await = await,
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .select = select,
            .groupAsync = groupAsync,
            .groupWait = groupWait,
            .groupCancel = groupCancel,

            .mutexLock = mutexLock,
            .mutexUnlock = mutexUnlock,

            .conditionWait = conditionWait,
            .conditionWake = conditionWake,

            .createFile = createFile,
            .fileOpen = fileOpen,
            .fileClose = fileClose,
            .pwrite = pwrite,
            .fileReadStreaming = fileReadStreaming,
            .fileReadPositional = fileReadPositional,
            .fileSeekBy = fileSeekBy,
            .fileSeekTo = fileSeekTo,

            .now = now,
            .sleep = sleep,

            .listen = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => listenPosix,
            },
            .accept = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => acceptPosix,
            },
            .ipBind = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => ipBindPosix,
            },
            .netClose = netClose,
            .netRead = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => netReadPosix,
            },
            .netWrite = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => netWritePosix,
            },
            .netSend = netSend,
            .netReceive = netReceive,
            .netInterfaceNameResolve = netInterfaceNameResolve,
            .netInterfaceName = netInterfaceName,
        },
    };
}

/// Trailing data:
/// 1. context
/// 2. result
const AsyncClosure = struct {
    closure: Closure,
    func: *const fn (context: *anyopaque, result: *anyopaque) void,
    reset_event: ResetEvent,
    select_condition: ?*ResetEvent,
    context_alignment: std.mem.Alignment,
    result_offset: usize,
    /// Whether the task has a return type with nonzero bits.
    has_result: bool,

    const done_reset_event: *ResetEvent = @ptrFromInt(@alignOf(ResetEvent));

    fn start(closure: *Closure) void {
        const ac: *AsyncClosure = @alignCast(@fieldParentPtr("closure", closure));
        const tid = std.Thread.getCurrentId();
        if (@cmpxchgStrong(std.Thread.Id, &closure.cancel_tid, 0, tid, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == Closure.canceling_tid);
            // Even though we already know the task is canceled, we must still
            // run the closure in order to make the return value valid - that
            // is, unless the result is zero bytes!
            if (!ac.has_result) {
                ac.reset_event.set();
                return;
            }
        }
        current_closure = closure;
        ac.func(ac.contextPointer(), ac.resultPointer());
        current_closure = null;

        // In case a cancel happens after successful task completion, prevents
        // signal from being delivered to the thread in `requestCancel`.
        if (@cmpxchgStrong(std.Thread.Id, &closure.cancel_tid, tid, 0, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == Closure.canceling_tid);
        }

        if (@atomicRmw(?*ResetEvent, &ac.select_condition, .Xchg, done_reset_event, .release)) |select_reset| {
            assert(select_reset != done_reset_event);
            select_reset.set();
        }
        ac.reset_event.set();
    }

    fn resultPointer(ac: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(ac);
        return base + ac.result_offset;
    }

    fn contextPointer(ac: *AsyncClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(ac);
        return base + ac.context_alignment.forward(@sizeOf(AsyncClosure));
    }

    fn waitAndFree(ac: *AsyncClosure, gpa: Allocator, result: []u8) void {
        ac.reset_event.wait();
        @memcpy(result, ac.resultPointer()[0..result.len]);
        free(ac, gpa, result.len);
    }

    fn free(ac: *AsyncClosure, gpa: Allocator, result_len: usize) void {
        if (!ac.has_result) assert(result_len == 0);
        const base: [*]align(@alignOf(AsyncClosure)) u8 = @ptrCast(ac);
        gpa.free(base[0 .. ac.result_offset + result_len]);
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
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const cpu_count = pool.cpu_count catch {
        return concurrent(userdata, result.len, result_alignment, context, context_alignment, start) catch {
            start(context.ptr, result.ptr);
            return null;
        };
    };
    const gpa = pool.allocator;
    const context_offset = context_alignment.forward(@sizeOf(AsyncClosure));
    const result_offset = result_alignment.forward(context_offset + context.len);
    const n = result_offset + result.len;
    const ac: *AsyncClosure = @ptrCast(@alignCast(gpa.alignedAlloc(u8, .of(AsyncClosure), n) catch {
        start(context.ptr, result.ptr);
        return null;
    }));

    ac.* = .{
        .closure = .{
            .cancel_tid = 0,
            .start = AsyncClosure.start,
            .is_concurrent = false,
        },
        .func = start,
        .context_alignment = context_alignment,
        .result_offset = result_offset,
        .has_result = result.len != 0,
        .reset_event = .unset,
        .select_condition = null,
    };

    @memcpy(ac.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    const thread_capacity = cpu_count - 1 + pool.concurrent_count;

    pool.threads.ensureTotalCapacityPrecise(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        ac.free(gpa, result.len);
        start(context.ptr, result.ptr);
        return null;
    };

    pool.run_queue.prepend(&ac.closure.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            if (pool.threads.items.len == 0) {
                assert(pool.run_queue.popFirst() == &ac.closure.node);
                pool.mutex.unlock();
                ac.free(gpa, result.len);
                start(context.ptr, result.ptr);
                return null;
            }
            // Rely on other workers to do it.
            pool.mutex.unlock();
            pool.cond.signal();
            return @ptrCast(ac);
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    pool.mutex.unlock();
    pool.cond.signal();
    return @ptrCast(ac);
}

fn concurrent(
    userdata: ?*anyopaque,
    result_len: usize,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) error{OutOfMemory}!*Io.AnyFuture {
    if (builtin.single_threaded) unreachable;

    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const cpu_count = pool.cpu_count catch 1;
    const gpa = pool.allocator;
    const context_offset = context_alignment.forward(@sizeOf(AsyncClosure));
    const result_offset = result_alignment.forward(context_offset + context.len);
    const n = result_offset + result_len;
    const ac: *AsyncClosure = @ptrCast(@alignCast(try gpa.alignedAlloc(u8, .of(AsyncClosure), n)));

    ac.* = .{
        .closure = .{
            .cancel_tid = 0,
            .start = AsyncClosure.start,
            .is_concurrent = true,
        },
        .func = start,
        .context_alignment = context_alignment,
        .result_offset = result_offset,
        .has_result = result_len != 0,
        .reset_event = .unset,
        .select_condition = null,
    };
    @memcpy(ac.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    pool.concurrent_count += 1;
    const thread_capacity = cpu_count - 1 + pool.concurrent_count;

    pool.threads.ensureTotalCapacity(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        ac.free(gpa, result_len);
        return error.OutOfMemory;
    };

    pool.run_queue.prepend(&ac.closure.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            assert(pool.run_queue.popFirst() == &ac.closure.node);
            pool.mutex.unlock();
            ac.free(gpa, result_len);
            return error.OutOfMemory;
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    pool.mutex.unlock();
    pool.cond.signal();
    return @ptrCast(ac);
}

const GroupClosure = struct {
    closure: Closure,
    pool: *Pool,
    group: *Io.Group,
    /// Points to sibling `GroupClosure`. Used for walking the group to cancel all.
    node: std.SinglyLinkedList.Node,
    func: *const fn (context: *anyopaque) void,
    context_alignment: std.mem.Alignment,
    context_len: usize,

    fn start(closure: *Closure) void {
        const gc: *GroupClosure = @alignCast(@fieldParentPtr("closure", closure));
        const tid = std.Thread.getCurrentId();
        const group = gc.group;
        const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
        const reset_event: *ResetEvent = @ptrCast(&group.context);
        if (@cmpxchgStrong(std.Thread.Id, &closure.cancel_tid, 0, tid, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == Closure.canceling_tid);
            // We already know the task is canceled before running the callback. Since all closures
            // in a Group have void return type, we can return early.
            std.Thread.WaitGroup.finishStateless(group_state, reset_event);
            return;
        }
        current_closure = closure;
        gc.func(gc.contextPointer());
        current_closure = null;

        // In case a cancel happens after successful task completion, prevents
        // signal from being delivered to the thread in `requestCancel`.
        if (@cmpxchgStrong(std.Thread.Id, &closure.cancel_tid, tid, 0, .acq_rel, .acquire)) |cancel_tid| {
            assert(cancel_tid == Closure.canceling_tid);
        }

        std.Thread.WaitGroup.finishStateless(group_state, reset_event);
    }

    fn free(gc: *GroupClosure, gpa: Allocator) void {
        const base: [*]align(@alignOf(GroupClosure)) u8 = @ptrCast(gc);
        gpa.free(base[0..contextEnd(gc.context_alignment, gc.context_len)]);
    }

    fn contextOffset(context_alignment: std.mem.Alignment) usize {
        return context_alignment.forward(@sizeOf(GroupClosure));
    }

    fn contextEnd(context_alignment: std.mem.Alignment, context_len: usize) usize {
        return contextOffset(context_alignment) + context_len;
    }

    fn contextPointer(gc: *GroupClosure) [*]u8 {
        const base: [*]u8 = @ptrCast(gc);
        return base + contextOffset(gc.context_alignment);
    }
};

fn groupAsync(
    userdata: ?*anyopaque,
    group: *Io.Group,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque) void,
) void {
    if (builtin.single_threaded) return start(context.ptr);
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const cpu_count = pool.cpu_count catch 1;
    const gpa = pool.allocator;
    const n = GroupClosure.contextEnd(context_alignment, context.len);
    const gc: *GroupClosure = @ptrCast(@alignCast(gpa.alignedAlloc(u8, .of(GroupClosure), n) catch {
        return start(context.ptr);
    }));
    gc.* = .{
        .closure = .{
            .cancel_tid = 0,
            .start = GroupClosure.start,
            .is_concurrent = false,
        },
        .pool = pool,
        .group = group,
        .node = undefined,
        .func = start,
        .context_alignment = context_alignment,
        .context_len = context.len,
    };
    @memcpy(gc.contextPointer()[0..context.len], context);

    pool.mutex.lock();

    // Append to the group linked list inside the mutex to make `Io.Group.async` thread-safe.
    gc.node = .{ .next = @ptrCast(@alignCast(group.token)) };
    group.token = &gc.node;

    const thread_capacity = cpu_count - 1 + pool.concurrent_count;

    pool.threads.ensureTotalCapacityPrecise(gpa, thread_capacity) catch {
        pool.mutex.unlock();
        gc.free(gpa);
        return start(context.ptr);
    };

    pool.run_queue.prepend(&gc.closure.node);

    if (pool.threads.items.len < thread_capacity) {
        const thread = std.Thread.spawn(.{ .stack_size = pool.stack_size }, worker, .{pool}) catch {
            assert(pool.run_queue.popFirst() == &gc.closure.node);
            pool.mutex.unlock();
            gc.free(gpa);
            return start(context.ptr);
        };
        pool.threads.appendAssumeCapacity(thread);
    }

    // This needs to be done before unlocking the mutex to avoid a race with
    // the associated task finishing.
    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    std.Thread.WaitGroup.startStateless(group_state);

    pool.mutex.unlock();
    pool.cond.signal();
}

fn groupWait(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;

    if (builtin.single_threaded) return;

    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const reset_event: *ResetEvent = @ptrCast(&group.context);
    std.Thread.WaitGroup.waitStateless(group_state, reset_event);

    var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
    while (true) {
        const gc: *GroupClosure = @fieldParentPtr("node", node);
        gc.closure.requestCancel();
        node = node.next orelse break;
    }
}

fn groupCancel(userdata: ?*anyopaque, group: *Io.Group, token: *anyopaque) void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const gpa = pool.allocator;

    if (builtin.single_threaded) return;

    {
        var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
        while (true) {
            const gc: *GroupClosure = @fieldParentPtr("node", node);
            gc.closure.requestCancel();
            node = node.next orelse break;
        }
    }

    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const reset_event: *ResetEvent = @ptrCast(&group.context);
    std.Thread.WaitGroup.waitStateless(group_state, reset_event);

    {
        var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
        while (true) {
            const gc: *GroupClosure = @fieldParentPtr("node", node);
            const node_next = node.next;
            gc.free(gpa);
            node = node_next orelse break;
        }
    }
}

fn await(
    userdata: ?*anyopaque,
    any_future: *Io.AnyFuture,
    result: []u8,
    result_alignment: std.mem.Alignment,
) void {
    _ = result_alignment;
    const pool: *Pool = @ptrCast(@alignCast(userdata));
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
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const ac: *AsyncClosure = @ptrCast(@alignCast(any_future));
    ac.closure.requestCancel();
    ac.waitAndFree(pool.allocator, result);
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    const closure = current_closure orelse return false;
    return @atomicLoad(std.Thread.Id, &closure.cancel_tid, .acquire) == Closure.canceling_tid;
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
    const pool: *Pool = @ptrCast(@alignCast(userdata));
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
    const pool: *Pool = @ptrCast(@alignCast(userdata));
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
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();
    const fs_dir: std.fs.Dir = .{ .fd = dir.handle };
    const fs_file = try fs_dir.createFile(sub_path, flags);
    return .{ .handle = fs_file.handle };
}

fn fileOpen(
    userdata: ?*anyopaque,
    dir: Io.Dir,
    sub_path: []const u8,
    flags: Io.File.OpenFlags,
) Io.File.OpenError!Io.File {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();
    const fs_dir: std.fs.Dir = .{ .fd = dir.handle };
    const fs_file = try fs_dir.openFile(sub_path, flags);
    return .{ .handle = fs_file.handle };
}

fn fileClose(userdata: ?*anyopaque, file: Io.File) void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    const fs_file: std.fs.File = .{ .handle = file.handle };
    return fs_file.close();
}

fn fileReadStreaming(userdata: ?*anyopaque, file: Io.File, data: [][]u8) Io.File.ReadStreamingError!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));

    if (is_windows) {
        const DWORD = windows.DWORD;
        var index: usize = 0;
        var truncate: usize = 0;
        var total: usize = 0;
        while (index < data.len) {
            try pool.checkCancel();
            {
                const untruncated = data[index];
                data[index] = untruncated[truncate..];
                defer data[index] = untruncated;
                const buffer = data[index..];
                const want_read_count: DWORD = @min(std.math.maxInt(DWORD), buffer.len);
                var n: DWORD = undefined;
                if (windows.kernel32.ReadFile(file.handle, buffer.ptr, want_read_count, &n, null) == 0) {
                    switch (windows.GetLastError()) {
                        .IO_PENDING => unreachable,
                        .OPERATION_ABORTED => continue,
                        .BROKEN_PIPE => return 0,
                        .HANDLE_EOF => return 0,
                        .NETNAME_DELETED => return error.ConnectionResetByPeer,
                        .LOCK_VIOLATION => return error.LockViolation,
                        .ACCESS_DENIED => return error.AccessDenied,
                        .INVALID_HANDLE => return error.NotOpenForReading,
                        else => |err| return windows.unexpectedError(err),
                    }
                }
                total += n;
                truncate += n;
            }
            while (index < data.len and truncate >= data[index].len) {
                truncate -= data[index].len;
                index += 1;
            }
        }
        return total;
    }

    var iovecs_buffer: [max_iovecs_len]posix.iovec = undefined;
    var i: usize = 0;
    for (data) |buf| {
        if (iovecs_buffer.len - i == 0) break;
        if (buf.len != 0) {
            iovecs_buffer[i] = .{ .base = buf.ptr, .len = buf.len };
            i += 1;
        }
    }
    const dest = iovecs_buffer[0..i];
    assert(dest[0].len > 0);

    if (native_os == .wasi and !builtin.link_libc) {
        try pool.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_read(file.handle, dest.ptr, dest.len, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => |err| return errnoBug(err),
            .AGAIN => unreachable, // currently not support in WASI
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    while (true) {
        try pool.checkCancel();
        const rc = posix.system.readv(file.handle, dest.ptr, dest.len);
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileReadPositional(userdata: ?*anyopaque, file: Io.File, data: [][]u8, offset: u64) Io.File.ReadPositionalError!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));

    const have_pread_but_not_preadv = switch (native_os) {
        .windows, .macos, .ios, .watchos, .tvos, .visionos, .haiku, .serenity => true,
        else => false,
    };
    if (have_pread_but_not_preadv) {
        @compileError("TODO");
    }

    if (is_windows) {
        const DWORD = windows.DWORD;
        const OVERLAPPED = windows.OVERLAPPED;
        var index: usize = 0;
        var truncate: usize = 0;
        var total: usize = 0;
        while (true) {
            try pool.checkCancel();
            {
                const untruncated = data[index];
                data[index] = untruncated[truncate..];
                defer data[index] = untruncated;
                const buffer = data[index..];
                const want_read_count: DWORD = @min(std.math.maxInt(DWORD), buffer.len);
                var n: DWORD = undefined;
                var overlapped_data: OVERLAPPED = undefined;
                const overlapped: ?*OVERLAPPED = if (offset) |off| blk: {
                    overlapped_data = .{
                        .Internal = 0,
                        .InternalHigh = 0,
                        .DUMMYUNIONNAME = .{
                            .DUMMYSTRUCTNAME = .{
                                .Offset = @as(u32, @truncate(off)),
                                .OffsetHigh = @as(u32, @truncate(off >> 32)),
                            },
                        },
                        .hEvent = null,
                    };
                    break :blk &overlapped_data;
                } else null;
                if (windows.kernel32.ReadFile(file.handle, buffer.ptr, want_read_count, &n, overlapped) == 0) {
                    switch (windows.GetLastError()) {
                        .IO_PENDING => unreachable,
                        .OPERATION_ABORTED => continue,
                        .BROKEN_PIPE => return 0,
                        .HANDLE_EOF => return 0,
                        .NETNAME_DELETED => return error.ConnectionResetByPeer,
                        .LOCK_VIOLATION => return error.LockViolation,
                        .ACCESS_DENIED => return error.AccessDenied,
                        .INVALID_HANDLE => return error.NotOpenForReading,
                        else => |err| return windows.unexpectedError(err),
                    }
                }
                total += n;
                truncate += n;
            }
            while (index < data.len and truncate >= data[index].len) {
                truncate -= data[index].len;
                index += 1;
            }
        }
        return total;
    }

    var iovecs_buffer: [max_iovecs_len]posix.iovec = undefined;
    var i: usize = 0;
    for (data) |buf| {
        if (iovecs_buffer.len - i == 0) break;
        if (buf.len != 0) {
            iovecs_buffer[i] = .{ .base = buf.ptr, .len = buf.len };
            i += 1;
        }
    }
    const dest = iovecs_buffer[0..i];
    assert(dest[0].len > 0);

    if (native_os == .wasi and !builtin.link_libc) {
        try pool.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_pread(file.handle, dest.ptr, dest.len, offset, &nread)) {
            .SUCCESS => return nread,
            .INTR => unreachable,
            .INVAL => unreachable,
            .FAULT => |err| return errnoBug(err),
            .AGAIN => unreachable,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    const preadv_sym = if (posix.lfs64_abi) posix.system.preadv64 else posix.system.preadv;
    while (true) {
        try pool.checkCancel();
        const rc = preadv_sym(file.handle, dest.ptr, dest.len, @bitCast(offset));
        switch (posix.errno(rc)) {
            .SUCCESS => return @bitCast(rc),
            .INTR => continue,
            .INVAL => unreachable,
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketNotConnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileSeekBy(userdata: ?*anyopaque, file: Io.File, offset: i64) Io.File.SeekError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = file;
    _ = offset;
    @panic("TODO");
}

fn fileSeekTo(userdata: ?*anyopaque, file: Io.File, offset: u64) Io.File.SeekError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = file;
    _ = offset;
    @panic("TODO");
}

fn pwrite(userdata: ?*anyopaque, file: Io.File, buffer: []const u8, offset: posix.off_t) Io.File.PWriteError!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();
    const fs_file: std.fs.File = .{ .handle = file.handle };
    return switch (offset) {
        -1 => fs_file.write(buffer),
        else => fs_file.pwrite(buffer, @bitCast(offset)),
    };
}

fn now(userdata: ?*anyopaque, clockid: posix.clockid_t) Io.NowError!Io.Timestamp {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();
    const timespec = try posix.clock_gettime(clockid);
    return @enumFromInt(@as(i128, timespec.sec) * std.time.ns_per_s + timespec.nsec);
}

fn sleep(userdata: ?*anyopaque, clockid: posix.clockid_t, timeout: Io.Timeout) Io.SleepError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const deadline_nanoseconds: i96 = switch (timeout) {
        .none => std.math.maxInt(i96),
        .duration => |duration| duration.nanoseconds,
        .deadline => |deadline| @intFromEnum(deadline),
    };
    var timespec: posix.timespec = .{
        .sec = @intCast(@divFloor(deadline_nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(deadline_nanoseconds, std.time.ns_per_s)),
    };
    while (true) {
        try pool.checkCancel();
        switch (std.os.linux.E.init(std.os.linux.clock_nanosleep(clockid, .{ .ABSTIME = switch (timeout) {
            .none, .duration => false,
            .deadline => true,
        } }, &timespec, &timespec))) {
            .SUCCESS => return,
            .FAULT => |err| return errnoBug(err),
            .INTR => {},
            .INVAL => return error.UnsupportedClock,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn select(userdata: ?*anyopaque, futures: []const *Io.AnyFuture) usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;

    var reset_event: ResetEvent = .unset;

    for (futures, 0..) |future, i| {
        const closure: *AsyncClosure = @ptrCast(@alignCast(future));
        if (@atomicRmw(?*ResetEvent, &closure.select_condition, .Xchg, &reset_event, .seq_cst) == AsyncClosure.done_reset_event) {
            for (futures[0..i]) |cleanup_future| {
                const cleanup_closure: *AsyncClosure = @ptrCast(@alignCast(cleanup_future));
                if (@atomicRmw(?*ResetEvent, &cleanup_closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
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
        if (@atomicRmw(?*ResetEvent, &closure.select_condition, .Xchg, null, .seq_cst) == AsyncClosure.done_reset_event) {
            closure.reset_event.wait(); // Ensure no reference to our stack-allocated reset_event.
            if (result == null) result = i; // In case multiple are ready, return first.
        }
    }
    return result.?;
}

fn listenPosix(
    userdata: ?*anyopaque,
    address: Io.net.IpAddress,
    options: Io.net.IpAddress.ListenOptions,
) Io.net.IpAddress.ListenError!Io.net.Server {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(&address);
    const protocol: u32 = posix.IPPROTO.TCP;
    const socket_fd = while (true) {
        try pool.checkCancel();
        const flags: u32 = posix.SOCK.STREAM | if (socket_flags_unsupported) 0 else posix.SOCK.CLOEXEC;
        const socket_rc = posix.system.socket(family, flags, protocol);
        switch (posix.errno(socket_rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(socket_rc);
                errdefer posix.close(fd);
                if (socket_flags_unsupported) while (true) {
                    try pool.checkCancel();
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, posix.FD_CLOEXEC))) {
                        .SUCCESS => break,
                        .INTR => continue,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                };
                break fd;
            },
            .INTR => continue,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    errdefer posix.close(socket_fd);

    if (options.reuse_address) {
        try setSocketOption(pool, socket_fd, posix.SOL.SOCKET, posix.SO.REUSEADDR, 1);
        if (@hasDecl(posix.SO, "REUSEPORT"))
            try setSocketOption(pool, socket_fd, posix.SOL.SOCKET, posix.SO.REUSEPORT, 1);
    }

    var storage: PosixAddress = undefined;
    var socklen = addressToPosix(address, &storage);
    try posixBind(pool, socket_fd, &storage.any, socklen);

    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.listen(socket_fd, options.kernel_backlog))) {
            .SUCCESS => break,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    try posixGetSockName(pool, socket_fd, &storage.any, &socklen);
    return .{
        .socket = .{
            .handle = socket_fd,
            .address = addressFromPosix(&storage),
        },
    };
}

fn posixBind(pool: *Pool, socket_fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.bind(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err), // always a race condition if this error is returned
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // invalid `sockfd`
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .FAULT => |err| return errnoBug(err), // invalid `addr` pointer
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn posixGetSockName(pool: *Pool, socket_fd: posix.fd_t, addr: *posix.sockaddr, addr_len: *posix.socklen_t) !void {
    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.getsockname(socket_fd, addr, addr_len))) {
            .SUCCESS => break,
            .INTR => continue,
            .BADF => |err| return errnoBug(err), // always a race condition
            .FAULT => |err| return errnoBug(err),
            .INVAL => |err| return errnoBug(err), // invalid parameters
            .NOTSOCK => |err| return errnoBug(err), // always a race condition
            .NOBUFS => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn setSocketOption(pool: *Pool, fd: posix.fd_t, level: i32, opt_name: u32, option: u32) !void {
    const o: []const u8 = @ptrCast(&option);
    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.setsockopt(fd, level, opt_name, o.ptr, @intCast(o.len)))) {
            .SUCCESS => return,
            .INTR => continue,
            .BADF => |err| return errnoBug(err), // always a race condition
            .NOTSOCK => |err| return errnoBug(err), // always a race condition
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn ipBindPosix(
    userdata: ?*anyopaque,
    address: Io.net.IpAddress,
    options: Io.net.IpAddress.BindOptions,
) Io.net.IpAddress.BindError!Io.net.Socket {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const mode = posixSocketMode(options.mode);
    const family = posixAddressFamily(&address);
    const protocol = posixProtocol(options.protocol);
    const socket_fd = while (true) {
        try pool.checkCancel();
        const flags: u32 = mode | if (socket_flags_unsupported) 0 else posix.SOCK.CLOEXEC;
        const socket_rc = posix.system.socket(family, flags, protocol);
        switch (posix.errno(socket_rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(socket_rc);
                errdefer posix.close(fd);
                if (socket_flags_unsupported) while (true) {
                    try pool.checkCancel();
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, posix.FD_CLOEXEC))) {
                        .SUCCESS => break,
                        .INTR => continue,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                };
                break fd;
            },
            .INTR => continue,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .INVAL => return error.ProtocolUnsupportedBySystem,
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .PROTONOSUPPORT => return error.ProtocolUnsupportedByAddressFamily,
            .PROTOTYPE => return error.SocketModeUnsupported,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    if (options.ip6_only) {
        try setSocketOption(pool, socket_fd, posix.IPPROTO.IPV6, posix.IPV6.V6ONLY, 0);
    }

    var storage: PosixAddress = undefined;
    var socklen = addressToPosix(address, &storage);
    try posixBind(pool, socket_fd, &storage.any, socklen);
    try posixGetSockName(pool, socket_fd, &storage.any, &socklen);
    return .{
        .handle = socket_fd,
        .address = addressFromPosix(&storage),
    };
}

const socket_flags_unsupported = builtin.os.tag.isDarwin() or native_os == .haiku; // 💩💩
const have_accept4 = !socket_flags_unsupported;

fn acceptPosix(userdata: ?*anyopaque, server: *Io.net.Server) Io.net.Server.AcceptError!Io.net.Stream {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const listen_fd = server.socket.handle;
    var storage: PosixAddress = undefined;
    var addr_len: posix.socklen_t = @sizeOf(PosixAddress);
    const fd = while (true) {
        try pool.checkCancel();
        const rc = if (have_accept4)
            posix.system.accept4(listen_fd, &storage.any, &addr_len, posix.SOCK.CLOEXEC)
        else
            posix.system.accept(listen_fd, &storage.any, &addr_len);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                const fd: posix.fd_t = @intCast(rc);
                errdefer posix.close(fd);
                if (!have_accept4) while (true) {
                    try pool.checkCancel();
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, posix.FD_CLOEXEC))) {
                        .SUCCESS => break,
                        .INTR => continue,
                        else => |err| return posix.unexpectedErrno(err),
                    }
                };
                break fd;
            },
            .INTR => continue,
            .AGAIN => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err), // always a race condition
            .CONNABORTED => return error.ConnectionAborted,
            .FAULT => |err| return errnoBug(err),
            .INVAL => return error.SocketNotListening,
            .NOTSOCK => |err| return errnoBug(err),
            .MFILE => return error.ProcessFdQuotaExceeded,
            .NFILE => return error.SystemFdQuotaExceeded,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .OPNOTSUPP => |err| return errnoBug(err),
            .PROTO => return error.ProtocolFailure,
            .PERM => return error.BlockedByFirewall,
            else => |err| return posix.unexpectedErrno(err),
        }
    };
    return .{ .socket = .{
        .handle = fd,
        .address = addressFromPosix(&storage),
    } };
}

fn netReadPosix(userdata: ?*anyopaque, stream: Io.net.Stream, data: [][]u8) Io.net.Stream.Reader.Error!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    var iovecs_buffer: [max_iovecs_len]posix.iovec = undefined;
    var i: usize = 0;
    for (data) |buf| {
        if (iovecs_buffer.len - i == 0) break;
        if (buf.len != 0) {
            iovecs_buffer[i] = .{ .base = buf.ptr, .len = buf.len };
            i += 1;
        }
    }
    const dest = iovecs_buffer[0..i];
    assert(dest[0].len > 0);
    const n = try posix.readv(stream.socket.handle, dest);
    if (n == 0) return error.EndOfStream;
    return n;
}

fn netSend(
    userdata: ?*anyopaque,
    handle: Io.net.Socket.Handle,
    messages: []const Io.net.OutgoingMessage,
    flags: Io.net.SendFlags,
) Io.net.Socket.SendError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = handle;
    _ = messages;
    _ = flags;
    @panic("TODO");
}

fn netReceive(
    userdata: ?*anyopaque,
    handle: Io.net.Socket.Handle,
    buffer: []u8,
    timeout: Io.Timeout,
) Io.net.Socket.ReceiveTimeoutError!Io.net.ReceivedMessage {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = handle;
    _ = buffer;
    _ = timeout;
    @panic("TODO");
}

fn netWritePosix(
    userdata: ?*anyopaque,
    stream: Io.net.Stream,
    header: []const u8,
    data: []const []const u8,
    splat: usize,
) Io.net.Stream.Writer.Error!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    var iovecs: [max_iovecs_len]posix.iovec_const = undefined;
    var msg: posix.msghdr_const = .{
        .name = null,
        .namelen = 0,
        .iov = &iovecs,
        .iovlen = 0,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    addBuf(&iovecs, &msg.iovlen, header);
    for (data[0 .. data.len - 1]) |bytes| addBuf(&iovecs, &msg.iovlen, bytes);
    const pattern = data[data.len - 1];
    if (iovecs.len - msg.iovlen != 0) switch (splat) {
        0 => {},
        1 => addBuf(&iovecs, &msg.iovlen, pattern),
        else => switch (pattern.len) {
            0 => {},
            1 => {
                var backup_buffer: [splat_buffer_size]u8 = undefined;
                const splat_buffer = &backup_buffer;
                const memset_len = @min(splat_buffer.len, splat);
                const buf = splat_buffer[0..memset_len];
                @memset(buf, pattern[0]);
                addBuf(&iovecs, &msg.iovlen, buf);
                var remaining_splat = splat - buf.len;
                while (remaining_splat > splat_buffer.len and iovecs.len - msg.iovlen != 0) {
                    assert(buf.len == splat_buffer.len);
                    addBuf(&iovecs, &msg.iovlen, splat_buffer);
                    remaining_splat -= splat_buffer.len;
                }
                addBuf(&iovecs, &msg.iovlen, splat_buffer[0..remaining_splat]);
            },
            else => for (0..@min(splat, iovecs.len - msg.iovlen)) |_| {
                addBuf(&iovecs, &msg.iovlen, pattern);
            },
        },
    };
    const flags = posix.MSG.NOSIGNAL;
    return posix.sendmsg(stream.socket.handle, &msg, flags);
}

fn addBuf(v: []posix.iovec_const, i: *@FieldType(posix.msghdr_const, "iovlen"), bytes: []const u8) void {
    // OS checks ptr addr before length so zero length vectors must be omitted.
    if (bytes.len == 0) return;
    if (v.len - i.* == 0) return;
    v[i.*] = .{ .base = bytes.ptr, .len = bytes.len };
    i.* += 1;
}

fn netClose(userdata: ?*anyopaque, handle: Io.net.Socket.Handle) void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    switch (native_os) {
        .windows => windows.closesocket(handle) catch recoverableOsBugDetected(),
        else => posix.close(handle),
    }
}

fn netInterfaceNameResolve(
    userdata: ?*anyopaque,
    name: *const Io.net.Interface.Name,
) Io.net.Interface.Name.ResolveError!Io.net.Interface {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    if (native_os == .linux) {
        const rc = posix.system.socket(posix.AF.UNIX, posix.SOCK.DGRAM | posix.SOCK.CLOEXEC, 0);
        const sock_fd: posix.fd_t = switch (posix.errno(rc)) {
            .SUCCESS => @intCast(rc),
            .ACCES => return error.AccessDenied,
            .MFILE => return error.SystemResources,
            .NFILE => return error.SystemResources,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            else => |err| return posix.unexpectedErrno(err),
        };
        defer posix.close(sock_fd);

        var ifr: posix.ifreq = .{
            .ifrn = .{ .name = @bitCast(name.bytes) },
            .ifru = undefined,
        };

        while (true) {
            try pool.checkCancel();
            switch (posix.errno(posix.system.ioctl(sock_fd, posix.SIOCGIFINDEX, @intFromPtr(&ifr)))) {
                .SUCCESS => return .{ .index = @bitCast(ifr.ifru.ivalue) },
                .INVAL => |err| return errnoBug(err), // Bad parameters.
                .NOTTY => |err| return errnoBug(err),
                .NXIO => |err| return errnoBug(err),
                .BADF => |err| return errnoBug(err), // Always a race condition.
                .FAULT => |err| return errnoBug(err), // Bad pointer parameter.
                .INTR => continue,
                .IO => |err| return errnoBug(err), // sock_fd is not a file descriptor
                .NODEV => return error.InterfaceNotFound,
                else => |err| return posix.unexpectedErrno(err),
            }
        }
    }

    if (native_os == .windows) {
        const index = std.os.windows.ws2_32.if_nametoindex(&name.bytes);
        if (index == 0) return error.InterfaceNotFound;
        return .{ .index = index };
    }

    if (builtin.link_libc) {
        const index = std.c.if_nametoindex(&name.bytes);
        if (index == 0) return error.InterfaceNotFound;
        return .{ .index = @bitCast(index) };
    }

    @panic("unimplemented");
}

fn netInterfaceName(userdata: ?*anyopaque, interface: Io.net.Interface) Io.net.Interface.NameError!Io.net.Interface.Name {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    if (native_os == .linux) {
        _ = interface;
        @panic("TODO");
    }

    if (native_os == .windows) {
        @panic("TODO");
    }

    if (builtin.link_libc) {
        @panic("TODO");
    }

    @panic("unimplemented");
}

const PosixAddress = extern union {
    any: posix.sockaddr,
    in: posix.sockaddr.in,
    in6: posix.sockaddr.in6,
};

fn posixAddressFamily(a: *const Io.net.IpAddress) posix.sa_family_t {
    return switch (a.*) {
        .ip4 => posix.AF.INET,
        .ip6 => posix.AF.INET6,
    };
}

fn addressFromPosix(posix_address: *PosixAddress) Io.net.IpAddress {
    return switch (posix_address.any.family) {
        posix.AF.INET => .{ .ip4 = address4FromPosix(&posix_address.in) },
        posix.AF.INET6 => .{ .ip6 = address6FromPosix(&posix_address.in6) },
        else => unreachable,
    };
}

fn addressToPosix(a: Io.net.IpAddress, storage: *PosixAddress) posix.socklen_t {
    return switch (a) {
        .ip4 => |ip4| {
            storage.in = address4ToPosix(ip4);
            return @sizeOf(posix.sockaddr.in);
        },
        .ip6 => |ip6| {
            storage.in6 = address6ToPosix(ip6);
            return @sizeOf(posix.sockaddr.in6);
        },
    };
}

fn address4FromPosix(in: *posix.sockaddr.in) Io.net.Ip4Address {
    return .{
        .port = std.mem.bigToNative(u16, in.port),
        .bytes = @bitCast(in.addr),
    };
}

fn address6FromPosix(in6: *posix.sockaddr.in6) Io.net.Ip6Address {
    return .{
        .port = std.mem.bigToNative(u16, in6.port),
        .bytes = in6.addr,
        .flow = in6.flowinfo,
        .interface = .{ .index = in6.scope_id },
    };
}

fn address4ToPosix(a: Io.net.Ip4Address) posix.sockaddr.in {
    return .{
        .port = std.mem.nativeToBig(u16, a.port),
        .addr = @bitCast(a.bytes),
    };
}

fn address6ToPosix(a: Io.net.Ip6Address) posix.sockaddr.in6 {
    return .{
        .port = std.mem.nativeToBig(u16, a.port),
        .flowinfo = a.flow,
        .addr = a.bytes,
        .scope_id = a.interface.index,
    };
}

fn errnoBug(err: posix.E) Io.UnexpectedError {
    switch (builtin.mode) {
        .Debug => std.debug.panic("programmer bug caused syscall error: {t}", .{err}),
        else => return error.Unexpected,
    }
}

fn posixSocketMode(mode: Io.net.Socket.Mode) u32 {
    return switch (mode) {
        .stream => posix.SOCK.STREAM,
        .dgram => posix.SOCK.DGRAM,
        .seqpacket => posix.SOCK.SEQPACKET,
        .raw => posix.SOCK.RAW,
        .rdm => posix.SOCK.RDM,
    };
}

fn posixProtocol(protocol: ?Io.net.Protocol) u32 {
    return @intFromEnum(protocol orelse return 0);
}

fn recoverableOsBugDetected() void {
    if (builtin.mode == .Debug) unreachable;
}
