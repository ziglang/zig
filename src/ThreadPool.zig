const std = @import("std");
const builtin = @import("builtin");
const ThreadPool = @This();

mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
run_queue: RunQueue = .{},
is_running: bool = true,
allocator: std.mem.Allocator,
threads: []std.Thread,

const RunQueue = std.SinglyLinkedList(Runnable);
const Runnable = struct {
    runFn: RunProto,
};

const RunProto = switch (builtin.zig_backend) {
    .stage1 => fn (*Runnable) void,
    else => *const fn (*Runnable) void,
};

pub fn init(self: *ThreadPool, allocator: std.mem.Allocator) !void {
    self.* = .{
        .allocator = allocator,
        .threads = &[_]std.Thread{},
    };

    if (builtin.single_threaded) {
        return;
    }

    const thread_count = std.math.max(1, std.Thread.getCpuCount() catch 1);
    self.threads = try allocator.alloc(std.Thread, thread_count);
    errdefer allocator.free(self.threads);

    // kill and join any threads we spawned previously on error.
    var spawned: usize = 0;
    errdefer self.join(spawned);

    for (self.threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, worker, .{self});
        spawned += 1;
    }
}

pub fn deinit(self: *ThreadPool) void {
    self.join(self.threads.len); // kill and join all threads.
    self.* = undefined;
}

fn join(self: *ThreadPool, spawned: usize) void {
    if (builtin.single_threaded) {
        return;
    }

    {
        self.mutex.lock();
        defer self.mutex.unlock();

        // ensure future worker threads exit the dequeue loop
        self.is_running = false;
    }

    // wake up any sleeping threads (this can be done outside the mutex)
    // then wait for all the threads we know are spawned to complete.
    self.cond.broadcast();
    for (self.threads[0..spawned]) |thread| {
        thread.join();
    }

    self.allocator.free(self.threads);
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

            // The thread pool's allocator is protected by the mutex.
            const mutex = &closure.pool.mutex;
            mutex.lock();
            defer mutex.unlock();

            closure.pool.allocator.destroy(closure);
        }
    };

    {
        self.mutex.lock();
        defer self.mutex.unlock();

        const closure = try self.allocator.create(Closure);
        closure.* = .{
            .arguments = args,
            .pool = self,
        };

        self.run_queue.prepend(&closure.run_node);
    }

    // Notify waiting threads outside the lock to try and keep the critical section small.
    self.cond.signal();
}

fn worker(self: *ThreadPool) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    while (true) {
        while (self.run_queue.popFirst()) |run_node| {
            // Temporarily unlock the mutex in order to execute the run_node
            self.mutex.unlock();
            defer self.mutex.lock();

            const runFn = run_node.data.runFn;
            runFn(&run_node.data);
        }

        // Stop executing instead of waiting if the thread pool is no longer running.
        if (self.is_running) {
            self.cond.wait(&self.mutex);
        } else {
            break;
        }
    }
}
