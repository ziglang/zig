// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const builtin = @import("builtin");
const ThreadPool = @This();

mutex: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
is_running: bool = true,
allocator: *std.mem.Allocator,
threads: []std.Thread,
run_queue: RunQueue = .{},

const RunQueue = std.SinglyLinkedList(Runnable);
const Runnable = struct {
    runFn: fn (*Runnable) void,
};

pub fn init(self: *ThreadPool, allocator: *std.mem.Allocator) !void {
    self.* = .{
        .allocator = allocator,
        .threads = &[_]std.Thread{},
    };

    if (builtin.single_threaded)
        return;

    const thread_count = std.math.max(1, std.Thread.getCpuCount() catch 1);
    self.threads = try allocator.alloc(std.Thread, thread_count);
    
    var spawned: usize = 0;
    errdefer self.join(spawned);

    for (self.threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, runWorker, .{self});
        spawned += 1;
    }
}

pub fn deinit(self: *ThreadPool) void {
    const thread_count = self.threads.len;
    self.join(thread_count);
}

fn runWorker(self: *ThreadPool) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    while (self.is_running) {
        const run_node = self.run_queue.popFirst() orelse {
            self.cond.wait(&self.mutex, null) catch unreachable;
            continue;
        };

        // Don't hold the mutex lock while we're running a job/node.
        //
        // The job/node's runFn could call ThreadPool.spawn() which locks
        // the mutex and would result in a deadlock if held while calling runFn.
        //
        // The mutex also just doesn't need to be held while running
        // and keeping the critical section small reduces threads blocking on mutex.
        self.mutex.unlock();
        defer self.mutex.lock();
        
        (run_node.data.runFn)(&run_node.data);
    }
}

fn join(self: *ThreadPool, spawned: usize) void {
    // Notify all worker threads that the pool is shutdown
    {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.is_running = false;
        self.cond.broadcast();
    }

    // Then wait for them all to complete
    for (self.threads[0..spawned]) |thread| thread.join();
    self.allocator.free(self.threads);
    self.* = undefined;
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

            // Grab the mutex before accessing the allocator 
            // as the allocator it may not be thread-safe (i.e. ArenaAllocator)
            const mutex = &closure.pool.mutex;
            mutex.lock();
            defer mutex.unlock();

            closure.pool.allocator.destroy(closure);
        }
    };

    self.mutex.lock();
    defer self.mutex.unlock();

    // Use the allocator while the mutex is held 
    // as the allocator may not be thread safe (i.e. ArenaAllocator)
    const closure = try self.allocator.create(Closure);
    closure.* = .{
        .arguments = args,
        .pool = self,
    };

    self.run_queue.prepend(&closure.run_node);
    self.cond.signal();
}
