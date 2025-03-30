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
            .cancel = cancel,
            .cancelRequested = cancelRequested,
            .createFile = createFile,
            .openFile = openFile,
            .closeFile = closeFile,
            .read = read,
            .write = write,
        },
    };
}

const AsyncClosure = struct {
    func: *const fn (context: *anyopaque, result: *anyopaque) void,
    runnable: Runnable = .{ .runFn = runFn },
    reset_event: std.Thread.ResetEvent,
    cancel_flag: bool,
    context_offset: usize,
    result_offset: usize,

    fn runFn(runnable: *std.Thread.Pool.Runnable, _: ?usize) void {
        const closure: *AsyncClosure = @alignCast(@fieldParentPtr("runnable", runnable));
        current_closure = closure;
        closure.func(closure.contextPointer(), closure.resultPointer());
        current_closure = null;
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
        .cancel_flag = false,
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

fn @"await"(userdata: ?*anyopaque, any_future: *Io.AnyFuture, result: []u8) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    closure.waitAndFree(pool.allocator, result);
}

fn cancel(userdata: ?*anyopaque, any_future: *Io.AnyFuture, result: []u8) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    const closure: *AsyncClosure = @ptrCast(@alignCast(any_future));
    @atomicStore(bool, &closure.cancel_flag, true, .seq_cst);
    closure.waitAndFree(pool.allocator, result);
}

fn cancelRequested(userdata: ?*anyopaque) bool {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    const closure = current_closure orelse return false;
    return @atomicLoad(bool, &closure.cancel_flag, .unordered);
}

fn checkCancel(pool: *Pool) error{AsyncCancel}!void {
    if (cancelRequested(pool)) return error.AsyncCancel;
}

pub fn createFile(
    userdata: ?*anyopaque,
    dir: std.fs.Dir,
    sub_path: []const u8,
    flags: std.fs.File.CreateFlags,
) Io.FileOpenError!std.fs.File {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return dir.createFile(sub_path, flags);
}

pub fn openFile(
    userdata: ?*anyopaque,
    dir: std.fs.Dir,
    sub_path: []const u8,
    flags: std.fs.File.OpenFlags,
) Io.FileOpenError!std.fs.File {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return dir.openFile(sub_path, flags);
}

pub fn closeFile(userdata: ?*anyopaque, file: std.fs.File) void {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    _ = pool;
    return file.close();
}

pub fn read(userdata: ?*anyopaque, file: std.fs.File, buffer: []u8) Io.FileReadError!usize {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return file.read(buffer);
}

pub fn write(userdata: ?*anyopaque, file: std.fs.File, buffer: []const u8) Io.FileWriteError!usize {
    const pool: *std.Thread.Pool = @alignCast(@ptrCast(userdata));
    try pool.checkCancel();
    return file.write(buffer);
}
