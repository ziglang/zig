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
running: usize = 0,
threads: []*std.Thread,
run_queue: RunQueue = .{},
idle_queue: IdleQueue = .{},

const IdleQueue = std.SinglyLinkedList(std.AutoResetEvent);
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

    var num_threads = std.Thread.cpuCount() catch 1;
    if (num_threads > 0)
        self.threads = try allocator.alloc(*std.Thread, num_threads);

    while (num_threads > 0) : (num_threads -= 1) {
        const thread = try std.Thread.spawn(self, runWorker);
        self.threads[self.running] = thread;
        self.running += 1;
    }
}

pub fn deinit(self: *ThreadPool) void {
    self.shutdown();

    std.debug.assert(!self.is_running);
    for (self.threads[0..self.running]) |thread|
        thread.wait();

    defer self.threads = &[_]*std.Thread{};
    if (self.running > 0)
        self.allocator.free(self.threads);
}

pub fn shutdown(self: *ThreadPool) void {
    const held = self.lock.acquire();

    if (!self.is_running)
        return held.release();

    var idle_queue = self.idle_queue;
    self.idle_queue = .{};
    self.is_running = false;
    held.release();

    while (idle_queue.popFirst()) |idle_node|
        idle_node.data.set();
}

pub fn spawn(self: *ThreadPool, comptime func: anytype, args: anytype) !void {
    if (std.builtin.single_threaded) {
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
            const result = @call(.{}, func, closure.arguments);
            closure.pool.allocator.destroy(closure);
        }
    };

    const closure = try self.allocator.create(Closure);
    closure.* = .{
        .arguments = args,
        .pool = self,
    };

    const held = self.lock.acquire();
    self.run_queue.prepend(&closure.run_node);

    const idle_node = self.idle_queue.popFirst();
    held.release();

    if (idle_node) |node|
        node.data.set();
}

fn runWorker(self: *ThreadPool) void {
    while (true) {
        const held = self.lock.acquire();

        if (self.run_queue.popFirst()) |run_node| {
            held.release();
            (run_node.data.runFn)(&run_node.data);
            continue;
        }

        if (!self.is_running) {
            held.release();
            return;
        }

        var idle_node = IdleQueue.Node{ .data = .{} };
        self.idle_queue.prepend(&idle_node);
        held.release();
        idle_node.data.wait();
    }
}
