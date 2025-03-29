const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const WaitGroup = @import("WaitGroup.zig");
const Pool = @This();

mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: std.SinglyLinkedList = .{},
is_running: bool = true,
/// Must be a thread-safe allocator.
allocator: std.mem.Allocator,
threads: if (builtin.single_threaded) [0]std.Thread else []std.Thread,
ids: if (builtin.single_threaded) struct {
    inline fn deinit(_: @This(), _: std.mem.Allocator) void {}
    fn getIndex(_: @This(), _: std.Thread.Id) usize {
        return 0;
    }
} else std.AutoArrayHashMapUnmanaged(std.Thread.Id, void),

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
    const allocator = options.allocator;

    pool.* = .{
        .allocator = allocator,
        .threads = if (builtin.single_threaded) .{} else &.{},
        .ids = .{},
    };

    if (builtin.single_threaded) {
        return;
    }

    const thread_count = options.n_jobs orelse @max(1, std.Thread.getCpuCount() catch 1);
    if (options.track_ids) {
        try pool.ids.ensureTotalCapacity(allocator, 1 + thread_count);
        pool.ids.putAssumeCapacityNoClobber(std.Thread.getCurrentId(), {});
    }

    // kill and join any threads we spawned and free memory on error.
    pool.threads = try allocator.alloc(std.Thread, thread_count);
    var spawned: usize = 0;
    errdefer pool.join(spawned);

    for (pool.threads) |*thread| {
        thread.* = try std.Thread.spawn(.{
            .stack_size = options.stack_size,
            .allocator = allocator,
        }, worker, .{pool});
        spawned += 1;
    }
}

pub fn deinit(pool: *Pool) void {
    pool.join(pool.threads.len); // kill and join all threads.
    pool.ids.deinit(pool.allocator);
    pool.* = undefined;
}

fn join(pool: *Pool, spawned: usize) void {
    if (builtin.single_threaded) {
        return;
    }

    {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        // ensure future worker threads exit the dequeue loop
        pool.is_running = false;
    }

    // wake up any sleeping threads (this can be done outside the mutex)
    // then wait for all the threads we know are spawned to complete.
    pool.cond.broadcast();
    for (pool.threads[0..spawned]) |thread| {
        thread.join();
    }

    pool.allocator.free(pool.threads);
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

    {
        pool.mutex.lock();

        const closure = pool.allocator.create(Closure) catch {
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
        pool.mutex.unlock();
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
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

    {
        pool.mutex.lock();

        const closure = pool.allocator.create(Closure) catch {
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
        pool.mutex.unlock();
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
    pool.cond.signal();
}

pub fn spawn(pool: *Pool, comptime func: anytype, args: anytype) !void {
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

    {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const closure = try pool.allocator.create(Closure);
        closure.* = .{
            .arguments = args,
            .pool = pool,
        };

        pool.run_queue.prepend(&closure.runnable.node);
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
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
        try pool.spawn(TestFn.checkRun, .{&completed});
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
    return @intCast(1 + pool.threads.len);
}

pub fn io(pool: *Pool) std.Io {
    return .{
        .userdata = pool,
        .vtable = &.{
            .@"async" = @"async",
            .@"await" = @"await",
        },
    };
}

const AsyncClosure = struct {
    func: *const fn (context: *anyopaque, result: *anyopaque) void,
    run_node: std.Thread.Pool.RunQueue.Node = .{ .data = .{ .runFn = runFn } },
    reset_event: std.Thread.ResetEvent,
    context_offset: usize,
    result_offset: usize,

    fn runFn(runnable: *std.Thread.Pool.Runnable, _: ?usize) void {
        const run_node: *std.Thread.Pool.RunQueue.Node = @fieldParentPtr("data", runnable);
        const closure: *AsyncClosure = @alignCast(@fieldParentPtr("run_node", run_node));
        closure.func(closure.contextPointer(), closure.resultPointer());
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
};

pub fn @"async"(
    userdata: ?*anyopaque,
    result: []u8,
    result_alignment: std.mem.Alignment,
    context: []const u8,
    context_alignment: std.mem.Alignment,
    start: *const fn (context: *const anyopaque, result: *anyopaque) void,
) ?*std.Io.AnyFuture {
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
    };
    @memcpy(closure.contextPointer()[0..context.len], context);
    pool.run_queue.prepend(&closure.run_node);
    pool.mutex.unlock();

    pool.cond.signal();

    return @ptrCast(closure);
}

pub fn @"await"(userdata: ?*anyopaque, any_future: *std.Io.AnyFuture, result: []u8) void {
    const thread_pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    closure.reset_event.wait();
    const base: [*]align(@alignOf(AsyncClosure)) u8 = @ptrCast(closure);
    @memcpy(result, closure.resultPointer()[0..result.len]);
    thread_pool.allocator.free(base[0 .. closure.result_offset + result.len]);
}
