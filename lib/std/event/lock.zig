// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Loop = std.event.Loop;

/// Thread-safe async/await lock.
/// Functions which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
/// Allows only one actor to hold the lock.
/// TODO: make this API also work in blocking I/O mode.
pub const Lock = struct {
    shared: bool,
    queue: Queue,
    queue_empty: bool,

    const Queue = std.atomic.Queue(anyframe);

    const global_event_loop = Loop.instance orelse
        @compileError("std.event.Lock currently only works with event-based I/O");

    pub const Held = struct {
        lock: *Lock,

        pub fn release(self: Held) void {
            // Resume the next item from the queue.
            if (self.lock.queue.get()) |node| {
                global_event_loop.onNextTick(node);
                return;
            }

            // We need to release the lock.
            @atomicStore(bool, &self.lock.queue_empty, true, .SeqCst);
            @atomicStore(bool, &self.lock.shared, false, .SeqCst);

            // There might be a queue item. If we know the queue is empty, we can be done,
            // because the other actor will try to obtain the lock.
            // But if there's a queue item, we are the actor which must loop and attempt
            // to grab the lock again.
            if (@atomicLoad(bool, &self.lock.queue_empty, .SeqCst)) {
                return;
            }

            while (true) {
                if (@atomicRmw(bool, &self.lock.shared, .Xchg, true, .SeqCst)) {
                    // We did not obtain the lock. Great, the queue is someone else's problem.
                    return;
                }

                // Resume the next item from the queue.
                if (self.lock.queue.get()) |node| {
                    global_event_loop.onNextTick(node);
                    return;
                }

                // Release the lock again.
                @atomicStore(bool, &self.lock.queue_empty, true, .SeqCst);
                @atomicStore(bool, &self.lock.shared, false, .SeqCst);

                // Find out if we can be done.
                if (@atomicLoad(bool, &self.lock.queue_empty, .SeqCst)) {
                    return;
                }
            }
        }
    };

    pub fn init() Lock {
        return Lock{
            .shared = false,
            .queue = Queue.init(),
            .queue_empty = true,
        };
    }

    pub fn initLocked() Lock {
        return Lock{
            .shared = true,
            .queue = Queue.init(),
            .queue_empty = true,
        };
    }

    /// Must be called when not locked. Not thread safe.
    /// All calls to acquire() and release() must complete before calling deinit().
    pub fn deinit(self: *Lock) void {
        assert(!self.shared);
        while (self.queue.get()) |node| resume node.data;
    }

    pub fn acquire(self: *Lock) callconv(.Async) Held {
        var my_tick_node = Loop.NextTickNode.init(@frame());

        errdefer _ = self.queue.remove(&my_tick_node); // TODO test canceling an acquire
        suspend {
            self.queue.put(&my_tick_node);

            // At this point, we are in the queue, so we might have already been resumed.

            // We set this bit so that later we can rely on the fact, that if queue_empty == true, some actor
            // will attempt to grab the lock.
            @atomicStore(bool, &self.queue_empty, false, .SeqCst);

            if (!@atomicRmw(bool, &self.shared, .Xchg, true, .SeqCst)) {
                if (self.queue.get()) |node| {
                    // Whether this node is us or someone else, we tail resume it.
                    resume node.data;
                }
            }
        }

        return Held{ .lock = self };
    }
};

test "std.event.Lock" {
    if (!std.io.is_async) return error.SkipZigTest;

    // TODO https://github.com/ziglang/zig/issues/1908
    if (builtin.single_threaded) return error.SkipZigTest;

    // TODO https://github.com/ziglang/zig/issues/3251
    if (builtin.os.tag == .freebsd) return error.SkipZigTest;

    // TODO this file has bit-rotted. repair it
    if (true) return error.SkipZigTest;

    var lock = Lock.init();
    defer lock.deinit();

    _ = async testLock(&lock);

    const expected_result = [1]i32{3 * @intCast(i32, shared_test_data.len)} ** shared_test_data.len;
    testing.expectEqualSlices(i32, &expected_result, &shared_test_data);
}
fn testLock(lock: *Lock) callconv(.Async) void {
    var handle1 = async lockRunner(lock);
    var tick_node1 = Loop.NextTickNode{
        .prev = undefined,
        .next = undefined,
        .data = &handle1,
    };
    Loop.instance.?.onNextTick(&tick_node1);

    var handle2 = async lockRunner(lock);
    var tick_node2 = Loop.NextTickNode{
        .prev = undefined,
        .next = undefined,
        .data = &handle2,
    };
    Loop.instance.?.onNextTick(&tick_node2);

    var handle3 = async lockRunner(lock);
    var tick_node3 = Loop.NextTickNode{
        .prev = undefined,
        .next = undefined,
        .data = &handle3,
    };
    Loop.instance.?.onNextTick(&tick_node3);

    await handle1;
    await handle2;
    await handle3;
}

var shared_test_data = [1]i32{0} ** 10;
var shared_test_index: usize = 0;
fn lockRunner(lock: *Lock) callconv(.Async) void {
    suspend; // resumed by onNextTick

    var i: usize = 0;
    while (i < shared_test_data.len) : (i += 1) {
        var lock_frame = async lock.acquire();
        const handle = await lock_frame;
        defer handle.release();

        shared_test_index = 0;
        while (shared_test_index < shared_test_data.len) : (shared_test_index += 1) {
            shared_test_data[shared_test_index] = shared_test_data[shared_test_index] + 1;
        }
    }
}
