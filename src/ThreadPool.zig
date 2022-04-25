const std = @import("std");
const builtin = @import("builtin");
const ThreadPool = @This();

mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
is_running: bool = true,
allocator: std.mem.Allocator,
workers: []Worker,
run_queue: RunQueue = .{},

const RunQueue = std.SinglyLinkedList(Runnable);
const Runnable = struct {
    runFn: RunProto,
};

const RunProto = switch (builtin.zig_backend) {
    .stage1 => fn (*Runnable) void,
    else => *const fn (*Runnable) void,
};

const Worker = struct {
    pool: *ThreadPool,
    thread: std.Thread,

    fn run(worker: *Worker) void {
        const pool = worker.pool;

        while (true) {
            pool.mutex.lock();

            if (pool.run_queue.popFirst()) |run_node| {
                pool.mutex.unlock();
                (run_node.data.runFn)(&run_node.data);
                continue;
            }

            if (pool.is_running) {
                worker.idle_node.data.reset();

                pool.idle_queue.prepend(&worker.idle_node);
                pool.mutex.unlock();

                worker.idle_node.data.wait();
                continue;
            }

            pool.mutex.unlock();
            return;
        }
    }
};

pub fn init(self: *ThreadPool, allocator: std.mem.Allocator) !void {
    self.* = .{
        .allocator = allocator,
        .workers = &[_]Worker{},
    };
    if (builtin.single_threaded)
        return;

    const worker_count = std.math.max(1, std.Thread.getCpuCount() catch 1);
    self.workers = try allocator.alloc(Worker, worker_count);
    errdefer allocator.free(self.workers);

    var worker_index: usize = 0;
    errdefer self.destroyWorkers(worker_index);
    while (worker_index < worker_count) : (worker_index += 1) {
        const worker = &self.workers[worker_index];
        worker.pool = self;

        // Each worker requires its ResetEvent to be pre-initialized.
        try worker.idle_node.data.init();
        errdefer worker.idle_node.data.deinit();

        worker.thread = try std.Thread.spawn(.{}, Worker.run, .{worker});
    }
}

fn destroyWorkers(self: *ThreadPool, spawned: usize) void {
    if (builtin.single_threaded)
        return;

    for (self.workers[0..spawned]) |*worker| {
        worker.thread.join();
        worker.idle_node.data.deinit();
    }
}

pub fn deinit(self: *ThreadPool) void {
    {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.is_running = false;
        while (self.idle_queue.popFirst()) |idle_node|
            idle_node.data.set();
    }

    self.destroyWorkers(self.workers.len);
    self.allocator.free(self.workers);
}

pub fn spawn(self: *ThreadPool, comptime func: anytype, args: anytype) !void {
    if (builtin.single_threaded) {
        @call(.{}, func, args);
        return;
    }

    const Args = @TypeOf(args);
    const Closure = struct {
        arguments: Args,
        pool: *ThreadPool,
        run_node: RunQueue.Node = .{ .data = .{ .runFn = runFn } },

        fn runFn(runnable: *Runnable) void {
            const run_node = @fieldParentPtr(RunQueue.Node, "data", runnable);
            const closure = @fieldParentPtr(@This(), "run_node", run_node);
            @call(.{}, func, closure.arguments);

            const mutex = &closure.pool.mutex;
            mutex.lock();
            defer mutex.unlock();
            closure.pool.allocator.destroy(closure);
        }
    };

    self.mutex.lock();
    defer self.mutex.unlock();

    const closure = try self.allocator.create(Closure);
    closure.* = .{
        .arguments = args,
        .pool = self,
    };

    self.run_queue.prepend(&closure.run_node);

    if (self.idle_queue.popFirst()) |idle_node|
        idle_node.data.set();
}
