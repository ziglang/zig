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

/// Related:
/// * `init_single_threaded`
pub fn init(
    /// Must be threadsafe. Only used for the following functions:
    /// * `Io.VTable.async`
    /// * `Io.VTable.concurrent`
    /// * `Io.VTable.groupAsync`
    /// If these functions are avoided, then `Allocator.failing` may be passed
    /// here.
    gpa: Allocator,
) Pool {
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

/// Statically initialize such that any call to the following functions will
/// fail with `error.OutOfMemory`:
/// * `Io.VTable.async`
/// * `Io.VTable.concurrent`
/// * `Io.VTable.groupAsync`
/// When initialized this way, `deinit` is safe, but unnecessary to call.
pub const init_single_threaded: Pool = .{
    .allocator = .failing,
    .threads = .empty,
    .stack_size = std.Thread.SpawnConfig.default_stack_size,
    .cpu_count = 1,
    .concurrent_count = 0,
};

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

            .dirMake = dirMake,
            .dirStat = dirStat,
            .dirStatPath = dirStatPath,
            .fileStat = fileStat,
            .createFile = createFile,
            .fileOpen = fileOpen,
            .fileClose = fileClose,
            .pwrite = pwrite,
            .fileReadStreaming = fileReadStreaming,
            .fileReadPositional = fileReadPositional,
            .fileSeekBy = fileSeekBy,
            .fileSeekTo = fileSeekTo,

            .now = switch (builtin.os.tag) {
                .windows => nowWindows,
                .wasi => nowWasi,
                else => nowPosix,
            },
            .sleep = switch (builtin.os.tag) {
                .windows => sleepWindows,
                .wasi => sleepWasi,
                .linux => sleepLinux,
                else => sleepPosix,
            },

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
            .ipConnect = switch (builtin.os.tag) {
                .windows => @panic("TODO"),
                else => ipConnectPosix,
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
    const gpa = pool.allocator;

    if (builtin.single_threaded) return;

    // TODO these primitives are too high level, need to check cancel on EINTR
    const group_state: *std.atomic.Value(usize) = @ptrCast(&group.state);
    const reset_event: *ResetEvent = @ptrCast(&group.context);
    std.Thread.WaitGroup.waitStateless(group_state, reset_event);

    var node: *std.SinglyLinkedList.Node = @ptrCast(@alignCast(token));
    while (true) {
        const gc: *GroupClosure = @fieldParentPtr("node", node);
        const node_next = node.next;
        gc.free(gpa);
        node = node_next orelse break;
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

fn dirMake(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8, mode: Io.Dir.Mode) Io.Dir.MakeError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = dir;
    _ = sub_path;
    _ = mode;
    @panic("TODO");
}

fn dirStat(userdata: ?*anyopaque, dir: Io.Dir) Io.Dir.StatError!Io.Dir.Stat {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = dir;
    @panic("TODO");
}

fn dirStatPath(userdata: ?*anyopaque, dir: Io.Dir, sub_path: []const u8) Io.Dir.StatError!Io.File.Stat {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = dir;
    _ = sub_path;
    @panic("TODO");
}

fn fileStat(userdata: ?*anyopaque, file: Io.File) Io.File.StatError!Io.File.Stat {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    _ = file;
    @panic("TODO");
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

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try pool.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_read(file.handle, dest.ptr, dest.len, &nread)) {
            .SUCCESS => return nread,
            .INTR => continue,
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .BADF => |err| return errnoBug(err),
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    while (true) {
        try pool.checkCancel();
        const rc = posix.system.readv(file.handle, dest.ptr, @intCast(dest.len));
        switch (posix.errno(rc)) {
            .SUCCESS => return @intCast(rc),
            .INTR => continue,
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn fileReadPositional(userdata: ?*anyopaque, file: Io.File, data: [][]u8, offset: u64) Io.File.ReadPositionalError!usize {
    const pool: *Pool = @ptrCast(@alignCast(userdata));

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

    const have_pread_but_not_preadv = switch (native_os) {
        .windows, .haiku, .serenity => true,
        else => false,
    };
    if (have_pread_but_not_preadv) {
        @compileError("TODO");
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

    if (native_os == .wasi and !builtin.link_libc) while (true) {
        try pool.checkCancel();
        var nread: usize = undefined;
        switch (std.os.wasi.fd_pread(file.handle, dest.ptr, dest.len, offset, &nread)) {
            .SUCCESS => return nread,
            .INTR => continue,
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .AGAIN => |err| return errnoBug(err),
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
            .CONNRESET => return error.ConnectionResetByPeer,
            .TIMEDOUT => return error.ConnectionTimedOut,
            .NXIO => return error.Unseekable,
            .SPIPE => return error.Unseekable,
            .OVERFLOW => return error.Unseekable,
            .NOTCAPABLE => return error.AccessDenied,
            else => |err| return posix.unexpectedErrno(err),
        }
    };

    const preadv_sym = if (posix.lfs64_abi) posix.system.preadv64 else posix.system.preadv;
    while (true) {
        try pool.checkCancel();
        const rc = preadv_sym(file.handle, dest.ptr, @intCast(dest.len), @bitCast(offset));
        switch (posix.errno(rc)) {
            .SUCCESS => return @bitCast(rc),
            .INTR => continue,
            .INVAL => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .SRCH => return error.ProcessNotFound,
            .AGAIN => return error.WouldBlock,
            .BADF => return error.NotOpenForReading, // can be a race condition
            .IO => return error.InputOutput,
            .ISDIR => return error.IsDir,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTCONN => return error.SocketUnconnected,
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

fn nowPosix(userdata: ?*anyopaque, clock: Io.Timestamp.Clock) Io.Timestamp.Error!i96 {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    const clock_id: posix.clockid_t = clockToPosix(clock);
    var tp: posix.timespec = undefined;
    switch (posix.errno(posix.system.clock_gettime(clock_id, &tp))) {
        .SUCCESS => return @intCast(@as(i128, tp.sec) * std.time.ns_per_s + tp.nsec),
        .INVAL => return error.UnsupportedClock,
        else => |err| return posix.unexpectedErrno(err),
    }
}

fn nowWindows(userdata: ?*anyopaque, clock: Io.Timestamp.Clock) Io.Timestamp.Error!i96 {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    switch (clock) {
        .realtime => {
            // RtlGetSystemTimePrecise() has a granularity of 100 nanoseconds
            // and uses the NTFS/Windows epoch, which is 1601-01-01.
            return @as(i96, windows.ntdll.RtlGetSystemTimePrecise()) * 100;
        },
        .monotonic, .uptime => {
            // QPC on windows doesn't fail on >= XP/2000 and includes time suspended.
            return .{ .timestamp = windows.QueryPerformanceCounter() };
        },
        .process_cputime_id,
        .thread_cputime_id,
        => return error.UnsupportedClock,
    }
}

fn nowWasi(userdata: ?*anyopaque, clock: Io.Timestamp.Clock) Io.Timestamp.Error!i96 {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    _ = pool;
    var ns: std.os.wasi.timestamp_t = undefined;
    const err = std.os.wasi.clock_time_get(clockToWasi(clock), 1, &ns);
    if (err != .SUCCESS) return error.Unexpected;
    return ns;
}

fn sleepLinux(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const clock_id: posix.clockid_t = clockToPosix(switch (timeout) {
        .none => .awake,
        .duration => |d| d.clock,
        .deadline => |d| d.clock,
    });
    const deadline_nanoseconds: i96 = switch (timeout) {
        .none => std.math.maxInt(i96),
        .duration => |d| d.duration.nanoseconds,
        .deadline => |deadline| deadline.nanoseconds,
    };
    var timespec: posix.timespec = .{
        .sec = @intCast(@divFloor(deadline_nanoseconds, std.time.ns_per_s)),
        .nsec = @intCast(@mod(deadline_nanoseconds, std.time.ns_per_s)),
    };
    while (true) {
        try pool.checkCancel();
        switch (std.os.linux.E.init(std.os.linux.clock_nanosleep(clock_id, .{ .ABSTIME = switch (timeout) {
            .none, .duration => false,
            .deadline => true,
        } }, &timespec, &timespec))) {
            .SUCCESS => return,
            .INTR => continue,
            .INVAL => return error.UnsupportedClock,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn sleepWindows(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();
    const ms = ms: {
        const duration_and_clock = (try timeout.toDurationFromNow(pool.io())) orelse
            break :ms std.math.maxInt(windows.DWORD);
        break :ms std.math.lossyCast(windows.DWORD, duration_and_clock.duration.toMilliseconds());
    };
    windows.kernel32.Sleep(ms);
}

fn sleepWasi(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    try pool.checkCancel();

    const w = std.os.wasi;

    const clock: w.subscription_clock_t = if (try timeout.toDurationFromNow(pool.io())) |d| .{
        .id = clockToWasi(d.clock),
        .timeout = std.math.lossyCast(u64, d.duration.nanoseconds),
        .precision = 0,
        .flags = 0,
    } else .{
        .id = .MONOTONIC,
        .timeout = std.math.maxInt(u64),
        .precision = 0,
        .flags = 0,
    };
    const in: w.subscription_t = .{
        .userdata = 0,
        .u = .{
            .tag = .CLOCK,
            .u = .{ .clock = clock },
        },
    };
    var event: w.event_t = undefined;
    var nevents: usize = undefined;
    _ = w.poll_oneoff(&in, &event, 1, &nevents);
}

fn sleepPosix(userdata: ?*anyopaque, timeout: Io.Timeout) Io.SleepError!void {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const sec_type = @typeInfo(posix.timespec).@"struct".fields[0].type;
    const nsec_type = @typeInfo(posix.timespec).@"struct".fields[1].type;

    var timespec: posix.timespec = t: {
        const d = (try timeout.toDurationFromNow(pool.io())) orelse break :t .{
            .sec = std.math.maxInt(sec_type),
            .nsec = std.math.maxInt(nsec_type),
        };
        const ns = d.duration.nanoseconds;
        break :t .{
            .sec = @intCast(@divFloor(ns, std.time.ns_per_s)),
            .nsec = @intCast(@mod(ns, std.time.ns_per_s)),
        };
    };
    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.nanosleep(&timespec, &timespec))) {
            .INTR => continue,
            else => return, // This prong handles success as well as unexpected errors.
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
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
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
    var addr_len = addressToPosix(&address, &storage);
    try posixBind(pool, socket_fd, &storage.any, addr_len);

    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.listen(socket_fd, options.kernel_backlog))) {
            .SUCCESS => break,
            .ADDRINUSE => return error.AddressInUse,
            .BADF => |err| return errnoBug(err),
            else => |err| return posix.unexpectedErrno(err),
        }
    }

    try posixGetSockName(pool, socket_fd, &storage.any, &addr_len);
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

fn posixConnect(pool: *Pool, socket_fd: posix.socket_t, addr: *const posix.sockaddr, addr_len: posix.socklen_t) !void {
    while (true) {
        try pool.checkCancel();
        switch (posix.errno(posix.system.connect(socket_fd, addr, addr_len))) {
            .SUCCESS => return,
            .INTR => continue,
            .ADDRINUSE => return error.AddressInUse,
            .ADDRNOTAVAIL => return error.AddressUnavailable,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .AGAIN, .INPROGRESS => |err| return errnoBug(err),
            .ALREADY => return error.ConnectionPending,
            .BADF => |err| return errnoBug(err),
            .CONNREFUSED => return error.ConnectionRefused,
            .CONNRESET => return error.ConnectionResetByPeer,
            .FAULT => |err| return errnoBug(err),
            .ISCONN => return error.AlreadyConnected,
            .HOSTUNREACH => return error.HostUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTSOCK => |err| return errnoBug(err),
            .PROTOTYPE => |err| return errnoBug(err),
            .TIMEDOUT => return error.ConnectionTimedOut,
            .CONNABORTED => |err| return errnoBug(err),
            // UNIX socket error codes:
            .ACCES => |err| return errnoBug(err),
            .PERM => |err| return errnoBug(err),
            .NOENT => |err| return errnoBug(err),
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

fn ipConnectPosix(
    userdata: ?*anyopaque,
    address: *const Io.net.IpAddress,
    options: Io.net.IpAddress.ConnectOptions,
) Io.net.IpAddress.ConnectError!Io.net.Stream {
    if (options.timeout != .none) @panic("TODO");
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_fd = try openSocketPosix(pool, family, .{
        .mode = options.mode,
        .protocol = options.protocol,
    });
    var storage: PosixAddress = undefined;
    var addr_len = addressToPosix(address, &storage);
    try posixConnect(pool, socket_fd, &storage.any, addr_len);
    try posixGetSockName(pool, socket_fd, &storage.any, &addr_len);
    return .{ .socket = .{
        .handle = socket_fd,
        .address = addressFromPosix(&storage),
    } };
}

fn ipBindPosix(
    userdata: ?*anyopaque,
    address: *const Io.net.IpAddress,
    options: Io.net.IpAddress.BindOptions,
) Io.net.IpAddress.BindError!Io.net.Socket {
    const pool: *Pool = @ptrCast(@alignCast(userdata));
    const family = posixAddressFamily(address);
    const socket_fd = try openSocketPosix(pool, family, options);
    errdefer posix.close(socket_fd);
    var storage: PosixAddress = undefined;
    var addr_len = addressToPosix(address, &storage);
    try posixBind(pool, socket_fd, &storage.any, addr_len);
    try posixGetSockName(pool, socket_fd, &storage.any, &addr_len);
    return .{
        .handle = socket_fd,
        .address = addressFromPosix(&storage),
    };
}

fn openSocketPosix(pool: *Pool, family: posix.sa_family_t, options: Io.net.IpAddress.BindOptions) !posix.socket_t {
    const mode = posixSocketMode(options.mode);
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
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
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
    errdefer posix.close(socket_fd);

    if (options.ip6_only) {
        if (posix.IPV6 == void) return error.OptionUnsupported;
        try setSocketOption(pool, socket_fd, posix.IPPROTO.IPV6, posix.IPV6.V6ONLY, 0);
    }

    return socket_fd;
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
                    switch (posix.errno(posix.system.fcntl(fd, posix.F.SETFD, @as(usize, posix.FD_CLOEXEC)))) {
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

const have_sendmmsg = builtin.os.tag == .linux;

fn netSend(
    userdata: ?*anyopaque,
    handle: Io.net.Socket.Handle,
    messages: []Io.net.OutgoingMessage,
    flags: Io.net.SendFlags,
) struct { ?Io.net.Socket.SendError, usize } {
    const pool: *Pool = @ptrCast(@alignCast(userdata));

    const posix_flags: u32 =
        @as(u32, if (@hasDecl(posix.MSG, "CONFIRM") and flags.confirm) posix.MSG.CONFIRM else 0) |
        @as(u32, if (flags.dont_route) posix.MSG.DONTROUTE else 0) |
        @as(u32, if (flags.eor) posix.MSG.EOR else 0) |
        @as(u32, if (flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (@hasDecl(posix.MSG, "FASTOPEN") and flags.fastopen) posix.MSG.FASTOPEN else 0) |
        posix.MSG.NOSIGNAL;

    var i: usize = 0;
    while (messages.len - i != 0) {
        if (have_sendmmsg) {
            i += netSendMany(pool, handle, messages[i..], posix_flags) catch |err| return .{ err, i };
            continue;
        }
        netSendOne(pool, handle, &messages[i], posix_flags) catch |err| return .{ err, i };
        i += 1;
    }
    return .{ null, i };
}

fn netSendOne(
    pool: *Pool,
    handle: Io.net.Socket.Handle,
    message: *Io.net.OutgoingMessage,
    flags: u32,
) Io.net.Socket.SendError!void {
    var addr: PosixAddress = undefined;
    var iovec: posix.iovec = .{ .base = @constCast(message.data_ptr), .len = message.data_len };
    const msg: posix.msghdr = .{
        .name = &addr.any,
        .namelen = addressToPosix(message.address, &addr),
        .iov = iovec[0..1],
        .iovlen = 1,
        .control = @constCast(message.control.ptr),
        .controllen = message.control.len,
        .flags = 0,
    };
    while (true) {
        try pool.checkCancel();
        const rc = posix.system.sendmsg(handle, msg, flags);
        if (is_windows) {
            if (rc == windows.ws2_32.SOCKET_ERROR) {
                switch (windows.ws2_32.WSAGetLastError()) {
                    .WSAEACCES => return error.AccessDenied,
                    .WSAEADDRNOTAVAIL => return error.AddressNotAvailable,
                    .WSAECONNRESET => return error.ConnectionResetByPeer,
                    .WSAEMSGSIZE => return error.MessageTooBig,
                    .WSAENOBUFS => return error.SystemResources,
                    .WSAENOTSOCK => return error.FileDescriptorNotASocket,
                    .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
                    .WSAEDESTADDRREQ => unreachable, // A destination address is required.
                    .WSAEFAULT => unreachable, // The lpBuffers, lpTo, lpOverlapped, lpNumberOfBytesSent, or lpCompletionRoutine parameters are not part of the user address space, or the lpTo parameter is too small.
                    .WSAEHOSTUNREACH => return error.NetworkUnreachable,
                    // TODO: WSAEINPROGRESS, WSAEINTR
                    .WSAEINVAL => unreachable,
                    .WSAENETDOWN => return error.NetworkSubsystemFailed,
                    .WSAENETRESET => return error.ConnectionResetByPeer,
                    .WSAENETUNREACH => return error.NetworkUnreachable,
                    .WSAENOTCONN => return error.SocketUnconnected,
                    .WSAESHUTDOWN => unreachable, // The socket has been shut down; it is not possible to WSASendTo on a socket after shutdown has been invoked with how set to SD_SEND or SD_BOTH.
                    .WSAEWOULDBLOCK => return error.WouldBlock,
                    .WSANOTINITIALISED => unreachable, // A successful WSAStartup call must occur before using this function.
                    else => |err| return windows.unexpectedWSAError(err),
                }
            } else {
                message.data_len = @intCast(rc);
                return;
            }
        }
        switch (posix.errno(rc)) {
            .SUCCESS => {
                message.data_len = @intCast(rc);
                return;
            },
            .ACCES => return error.AccessDenied,
            .AGAIN => return error.WouldBlock,
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => |err| return errnoBug(err),
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => |err| return errnoBug(err),
            .FAULT => |err| return errnoBug(err),
            .INTR => continue,
            .INVAL => |err| return errnoBug(err),
            .ISCONN => |err| return errnoBug(err),
            .MSGSIZE => return error.MessageTooBig,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => |err| return errnoBug(err),
            .OPNOTSUPP => |err| return errnoBug(err),
            .PIPE => return error.BrokenPipe,
            .AFNOSUPPORT => return error.AddressFamilyNotSupported,
            .LOOP => return error.SymLinkLoop,
            .NAMETOOLONG => return error.NameTooLong,
            .NOENT => return error.FileNotFound,
            .NOTDIR => return error.NotDir,
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTCONN => return error.SocketUnconnected,
            .NETDOWN => return error.NetworkSubsystemFailed,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn netSendMany(
    pool: *Pool,
    handle: Io.net.Socket.Handle,
    messages: []Io.net.OutgoingMessage,
    flags: u32,
) Io.net.Socket.SendError!usize {
    var msg_buffer: [64]std.os.linux.mmsghdr = undefined;
    var addr_buffer: [msg_buffer.len]PosixAddress = undefined;
    var iovecs_buffer: [msg_buffer.len]posix.iovec = undefined;
    const min_len: usize = @min(messages.len, msg_buffer.len);
    const clamped_messages = messages[0..min_len];
    const clamped_msgs = (&msg_buffer)[0..min_len];
    const clamped_addrs = (&addr_buffer)[0..min_len];
    const clamped_iovecs = (&iovecs_buffer)[0..min_len];

    for (clamped_messages, clamped_msgs, clamped_addrs, clamped_iovecs) |*message, *msg, *addr, *iovec| {
        iovec.* = .{ .base = @constCast(message.data_ptr), .len = message.data_len };
        msg.* = .{
            .hdr = .{
                .name = &addr.any,
                .namelen = addressToPosix(message.address, addr),
                .iov = iovec[0..1],
                .iovlen = 1,
                .control = @constCast(message.control.ptr),
                .controllen = message.control.len,
                .flags = 0,
            },
            .len = undefined, // Populated by calling sendmmsg below.
        };
    }

    while (true) {
        try pool.checkCancel();
        const rc = posix.system.sendmmsg(handle, clamped_msgs.ptr, @intCast(clamped_msgs.len), flags);
        switch (posix.errno(rc)) {
            .SUCCESS => {
                for (clamped_messages[0..rc], clamped_msgs[0..rc]) |*message, *msg| {
                    message.data_len = msg.len;
                }
                return rc;
            },
            .AGAIN => |err| return errnoBug(err),
            .ALREADY => return error.FastOpenAlreadyInProgress,
            .BADF => |err| return errnoBug(err), // Always a race condition.
            .CONNRESET => return error.ConnectionResetByPeer,
            .DESTADDRREQ => |err| return errnoBug(err), // The socket is not connection-mode, and no peer address is set.
            .FAULT => |err| return errnoBug(err), // An invalid user space address was specified for an argument.
            .INTR => continue,
            .INVAL => |err| return errnoBug(err), // Invalid argument passed.
            .ISCONN => |err| return errnoBug(err), // connection-mode socket was connected already but a recipient was specified
            .MSGSIZE => return error.MessageOversize,
            .NOBUFS => return error.SystemResources,
            .NOMEM => return error.SystemResources,
            .NOTSOCK => |err| return errnoBug(err), // The file descriptor sockfd does not refer to a socket.
            .OPNOTSUPP => |err| return errnoBug(err), // Some bit in the flags argument is inappropriate for the socket type.
            .PIPE => return error.SocketUnconnected,
            .AFNOSUPPORT => return error.AddressFamilyUnsupported,
            .HOSTUNREACH => return error.NetworkUnreachable,
            .NETUNREACH => return error.NetworkUnreachable,
            .NOTCONN => return error.SocketUnconnected,
            .NETDOWN => return error.NetworkDown,
            else => |err| return posix.unexpectedErrno(err),
        }
    }
}

fn netReceive(
    userdata: ?*anyopaque,
    handle: Io.net.Socket.Handle,
    message_buffer: []Io.net.IncomingMessage,
    data_buffer: []u8,
    flags: Io.net.ReceiveFlags,
    timeout: Io.Timeout,
) struct { ?Io.net.Socket.ReceiveTimeoutError, usize } {
    const pool: *Pool = @ptrCast(@alignCast(userdata));

    // recvmmsg is useless, here's why:
    // * [timeout bug](https://bugzilla.kernel.org/show_bug.cgi?id=75371)
    // * it wants iovecs for each message but we have a better API: one data
    //   buffer to handle all the messages. The better API cannot be lowered to
    //   the split vectors though because reducing the buffer size might make
    //   some messages unreceivable.

    // So the strategy instead is to use non-blocking recvmsg calls, calling
    // poll() with timeout if the first one returns EAGAIN.
    const posix_flags: u32 =
        @as(u32, if (flags.oob) posix.MSG.OOB else 0) |
        @as(u32, if (flags.peek) posix.MSG.PEEK else 0) |
        @as(u32, if (flags.trunc) posix.MSG.TRUNC else 0) |
        posix.MSG.DONTWAIT | posix.MSG.NOSIGNAL;

    var poll_fds: [1]posix.pollfd = .{
        .{
            .fd = handle,
            .events = posix.POLL.IN,
            .revents = undefined,
        },
    };
    var message_i: usize = 0;
    var data_i: usize = 0;

    const deadline = timeout.toDeadline(pool.io()) catch |err| return .{ err, message_i };

    recv: while (true) {
        pool.checkCancel() catch |err| return .{ err, message_i };

        if (message_buffer.len - message_i == 0) return .{ null, message_i };
        const message = &message_buffer[message_i];
        const remaining_data_buffer = data_buffer[data_i..];
        var storage: PosixAddress = undefined;
        var iov: posix.iovec = .{ .base = remaining_data_buffer.ptr, .len = remaining_data_buffer.len };
        var msg: posix.msghdr = .{
            .name = &storage.any,
            .namelen = @sizeOf(PosixAddress),
            .iov = (&iov)[0..1],
            .iovlen = 1,
            .control = message.control.ptr,
            .controllen = message.control.len,
            .flags = undefined,
        };

        const recv_rc = posix.system.recvmsg(handle, &msg, posix_flags);
        switch (posix.errno(recv_rc)) {
            .SUCCESS => {
                const data = remaining_data_buffer[0..@intCast(recv_rc)];
                data_i += data.len;
                message.* = .{
                    .from = addressFromPosix(&storage),
                    .data = data,
                    .control = if (msg.control) |ptr| @as([*]u8, @ptrCast(ptr))[0..msg.controllen] else message.control,
                    .flags = .{
                        .eor = (msg.flags & posix.MSG.EOR) != 0,
                        .trunc = (msg.flags & posix.MSG.TRUNC) != 0,
                        .ctrunc = (msg.flags & posix.MSG.CTRUNC) != 0,
                        .oob = (msg.flags & posix.MSG.OOB) != 0,
                        .errqueue = (msg.flags & posix.MSG.ERRQUEUE) != 0,
                    },
                };
                message_i += 1;
                continue;
            },
            .AGAIN => while (true) {
                pool.checkCancel() catch |err| return .{ err, message_i };
                if (message_i != 0) return .{ null, message_i };

                const max_poll_ms = std.math.maxInt(u31);
                const timeout_ms: u31 = if (deadline) |d| t: {
                    const duration = d.durationFromNow(pool.io()) catch |err| return .{ err, message_i };
                    if (duration.nanoseconds <= 0) return .{ error.Timeout, message_i };
                    break :t @intCast(@min(max_poll_ms, duration.toMilliseconds()));
                } else max_poll_ms;

                const poll_rc = posix.system.poll(&poll_fds, poll_fds.len, timeout_ms);
                switch (posix.errno(poll_rc)) {
                    .SUCCESS => {
                        if (poll_rc == 0) {
                            // Although spurious timeouts are OK, when no deadline
                            // is passed we must not return `error.Timeout`.
                            if (deadline == null) continue;
                            return .{ error.Timeout, message_i };
                        }
                        continue :recv;
                    },
                    .INTR => continue,

                    .FAULT => |err| return .{ errnoBug(err), message_i },
                    .INVAL => |err| return .{ errnoBug(err), message_i },
                    .NOMEM => return .{ error.SystemResources, message_i },
                    else => |err| return .{ posix.unexpectedErrno(err), message_i },
                }
            },
            .INTR => continue,

            .BADF => |err| return .{ errnoBug(err), message_i },
            .NFILE => return .{ error.SystemFdQuotaExceeded, message_i },
            .MFILE => return .{ error.ProcessFdQuotaExceeded, message_i },
            .FAULT => |err| return .{ errnoBug(err), message_i },
            .INVAL => |err| return .{ errnoBug(err), message_i },
            .NOBUFS => return .{ error.SystemResources, message_i },
            .NOMEM => return .{ error.SystemResources, message_i },
            .NOTCONN => return .{ error.SocketUnconnected, message_i },
            .NOTSOCK => |err| return .{ errnoBug(err), message_i },
            .MSGSIZE => return .{ error.MessageOversize, message_i },
            .PIPE => return .{ error.SocketUnconnected, message_i },
            .OPNOTSUPP => |err| return .{ errnoBug(err), message_i },
            .CONNRESET => return .{ error.ConnectionResetByPeer, message_i },
            .NETDOWN => return .{ error.NetworkDown, message_i },
            else => |err| return .{ posix.unexpectedErrno(err), message_i },
        }
    }
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

fn addressToPosix(a: *const Io.net.IpAddress, storage: *PosixAddress) posix.socklen_t {
    return switch (a.*) {
        .ip4 => |ip4| {
            storage.in = address4ToPosix(ip4);
            return @sizeOf(posix.sockaddr.in);
        },
        .ip6 => |*ip6| {
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

fn address6ToPosix(a: *const Io.net.Ip6Address) posix.sockaddr.in6 {
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

fn clockToPosix(clock: Io.Timestamp.Clock) posix.clockid_t {
    return switch (clock) {
        .real => posix.CLOCK.REALTIME,
        .awake => switch (builtin.os.tag) {
            .macos, .ios, .watchos, .tvos => posix.CLOCK.UPTIME_RAW,
            else => posix.CLOCK.MONOTONIC,
        },
        .boot => switch (builtin.os.tag) {
            .macos, .ios, .watchos, .tvos => posix.CLOCK.MONOTONIC_RAW,
            else => posix.CLOCK.BOOTTIME,
        },
        .cpu_process => posix.CLOCK.PROCESS_CPUTIME_ID,
        .cpu_thread => posix.CLOCK.THREAD_CPUTIME_ID,
    };
}

fn clockToWasi(clock: Io.Timestamp.Clock) std.os.wasi.clockid_t {
    return switch (clock) {
        .realtime => .REALTIME,
        .awake => .MONOTONIC,
        .boot => .MONOTONIC,
        .cpu_process => .PROCESS_CPUTIME_ID,
        .cpu_thread => .THREAD_CPUTIME_ID,
    };
}
