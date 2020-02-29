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
    shared_bit: u8, // TODO make this a bool
    queue: Queue,
    queue_empty_bit: u8, // TODO make this a bool

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
            @atomicStore(u8, &self.lock.queue_empty_bit, 1, .SeqCst);
            @atomicStore(u8, &self.lock.shared_bit, 0, .SeqCst);

            // There might be a queue item. If we know the queue is empty, we can be done,
            // because the other actor will try to obtain the lock.
            // But if there's a queue item, we are the actor which must loop and attempt
            // to grab the lock again.
            if (@atomicLoad(u8, &self.lock.queue_empty_bit, .SeqCst) == 1) {
                return;
            }

            while (true) {
                const old_bit = @atomicRmw(u8, &self.lock.shared_bit, .Xchg, 1, .SeqCst);
                if (old_bit != 0) {
                    // We did not obtain the lock. Great, the queue is someone else's problem.
                    return;
                }

                // Resume the next item from the queue.
                if (self.lock.queue.get()) |node| {
                    global_event_loop.onNextTick(node);
                    return;
                }

                // Release the lock again.
                @atomicStore(u8, &self.lock.queue_empty_bit, 1, .SeqCst);
                @atomicStore(u8, &self.lock.shared_bit, 0, .SeqCst);

                // Find out if we can be done.
                if (@atomicLoad(u8, &self.lock.queue_empty_bit, .SeqCst) == 1) {
                    return;
                }
            }
        }
    };

    pub fn init() Lock {
        return Lock{
            .shared_bit = 0,
            .queue = Queue.init(),
            .queue_empty_bit = 1,
        };
    }

    pub fn initLocked() Lock {
        return Lock{
            .shared_bit = 1,
            .queue = Queue.init(),
            .queue_empty_bit = 1,
        };
    }

    /// Must be called when not locked. Not thread safe.
    /// All calls to acquire() and release() must complete before calling deinit().
    pub fn deinit(self: *Lock) void {
        assert(self.shared_bit == 0);
        while (self.queue.get()) |node| resume node.data;
    }

    pub async fn acquire(self: *Lock) Held {
        var my_tick_node = Loop.NextTickNode.init(@frame());

        errdefer _ = self.queue.remove(&my_tick_node); // TODO test canceling an acquire
        suspend {
            self.queue.put(&my_tick_node);

            // At this point, we are in the queue, so we might have already been resumed.

            // We set this bit so that later we can rely on the fact, that if queue_empty_bit is 1, some actor
            // will attempt to grab the lock.
            @atomicStore(u8, &self.queue_empty_bit, 0, .SeqCst);

            const old_bit = @atomicRmw(u8, &self.shared_bit, .Xchg, 1, .SeqCst);
            if (old_bit == 0) {
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

    var lock = Lock.init();
    defer lock.deinit();

    _ = async testLock(&lock);

    const expected_result = [1]i32{3 * @intCast(i32, shared_test_data.len)} ** shared_test_data.len;
    testing.expectEqualSlices(i32, &expected_result, &shared_test_data);
}

async fn testLock(lock: *Lock) void {
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

async fn lockRunner(lock: *Lock) void {
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
