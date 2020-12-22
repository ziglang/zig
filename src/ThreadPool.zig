// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const ThreadPool = @This();

lock: std.Mutex = .{},
is_running: bool = true,
allocator: *std.mem.Allocator,
spawned: usize = 0,
threads: []*std.Thread,
run_queue: RunQueue = .{},
idle_queue: IdleQueue = .{},

const IdleQueue = std.SinglyLinkedList(std.ResetEvent);
const RunQueue = std.SinglyLinkedList(Runnable);
const Runnable = struct {
    runFn: fn (*Runnable) void,
};

pub fn init(self: *ThreadPool, allocator: *std.mem.Allocator) !void {
    self.* = .{
        .allocator = allocator,
        .threads = &[_]*std.Thread{},
    };
    if (std.builtin.single_threaded)
        return;

    errdefer self.deinit();

    var num_threads = std.math.max(1, std.Thread.cpuCount() catch 1);
    self.threads = try allocator.alloc(*std.Thread, num_threads);

    while (num_threads > 0) : (num_threads -= 1) {
        const thread = try std.Thread.spawn(self, runWorker);
        self.threads[self.spawned] = thread;
        self.spawned += 1;
    }
}

pub fn deinit(self: *ThreadPool) void {
    {
        const held = self.lock.acquire();
        defer held.release();

        self.is_running = false;
        while (self.idle_queue.popFirst()) |idle_node|
            idle_node.data.set();
    }

    defer self.allocator.free(self.threads);
    for (self.threads[0..self.spawned]) |thread|
        thread.wait();
}

pub fn spawn(self: *ThreadPool, comptime func: anytype, args: anytype) !void {
    if (std.builtin.single_threaded) {
        const result = @call(.{}, func, args);
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
            const result = @call(.{}, func, closure.arguments);

            const held = closure.pool.lock.acquire();
            defer held.release();
            closure.pool.allocator.destroy(closure);
        }
    };

    const held = self.lock.acquire();
    defer held.release();

    const closure = try self.allocator.create(Closure);
    closure.* = .{
        .arguments = args,
        .pool = self,
    };

    self.run_queue.prepend(&closure.run_node);

    if (self.idle_queue.popFirst()) |idle_node|
        idle_node.data.set();
}

fn runWorker(self: *ThreadPool) void {
    while (true) {
        const held = self.lock.acquire();

        if (self.run_queue.popFirst()) |run_node| {
            held.release();
            (run_node.data.runFn)(&run_node.data);
            continue;
        }

        if (self.is_running) {
            var idle_node = IdleQueue.Node{ .data = std.ResetEvent.init() };

            self.idle_queue.prepend(&idle_node);
            held.release();

            idle_node.data.wait();
            idle_node.data.deinit();
            continue;
        }

        held.release();
        return;
    }
}
