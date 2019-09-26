const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const Loop = std.event.Loop;

/// Thread-safe async/await lock.
/// Functions which are waiting for the lock are suspended, and
/// are resumed when the lock is released, in order.
/// Many readers can hold the lock at the same time; however locking for writing is exclusive.
/// When a read lock is held, it will not be released until the reader queue is empty.
/// When a write lock is held, it will not be released until the writer queue is empty.
pub const RwLock = struct {
    loop: *Loop,
    shared_state: u8, // TODO make this an enum
    writer_queue: Queue,
    reader_queue: Queue,
    writer_queue_empty_bit: u8, // TODO make this a bool
    reader_queue_empty_bit: u8, // TODO make this a bool
    reader_lock_count: usize,

    const State = struct {
        const Unlocked = 0;
        const WriteLock = 1;
        const ReadLock = 2;
    };

    const Queue = std.atomic.Queue(anyframe);

    pub const HeldRead = struct {
        lock: *RwLock,

        pub fn release(self: HeldRead) void {
            // If other readers still hold the lock, we're done.
            if (@atomicRmw(usize, &self.lock.reader_lock_count, .Sub, 1, .SeqCst) != 1) {
                return;
            }

            _ = @atomicRmw(u8, &self.lock.reader_queue_empty_bit, .Xchg, 1, .SeqCst);
            if (@cmpxchgStrong(u8, &self.lock.shared_state, State.ReadLock, State.Unlocked, .SeqCst, .SeqCst) != null) {
                // Didn't unlock. Someone else's problem.
                return;
            }

            self.lock.commonPostUnlock();
        }
    };

    pub const HeldWrite = struct {
        lock: *RwLock,

        pub fn release(self: HeldWrite) void {
            // See if we can leave it locked for writing, and pass the lock to the next writer
            // in the queue to grab the lock.
            if (self.lock.writer_queue.get()) |node| {
                self.lock.loop.onNextTick(node);
                return;
            }

            // We need to release the write lock. Check if any readers are waiting to grab the lock.
            if (@atomicLoad(u8, &self.lock.reader_queue_empty_bit, .SeqCst) == 0) {
                // Switch to a read lock.
                _ = @atomicRmw(u8, &self.lock.shared_state, .Xchg, State.ReadLock, .SeqCst);
                while (self.lock.reader_queue.get()) |node| {
                    self.lock.loop.onNextTick(node);
                }
                return;
            }

            _ = @atomicRmw(u8, &self.lock.writer_queue_empty_bit, .Xchg, 1, .SeqCst);
            _ = @atomicRmw(u8, &self.lock.shared_state, .Xchg, State.Unlocked, .SeqCst);

            self.lock.commonPostUnlock();
        }
    };

    pub fn init(loop: *Loop) RwLock {
        return RwLock{
            .loop = loop,
            .shared_state = State.Unlocked,
            .writer_queue = Queue.init(),
            .writer_queue_empty_bit = 1,
            .reader_queue = Queue.init(),
            .reader_queue_empty_bit = 1,
            .reader_lock_count = 0,
        };
    }

    /// Must be called when not locked. Not thread safe.
    /// All calls to acquire() and release() must complete before calling deinit().
    pub fn deinit(self: *RwLock) void {
        assert(self.shared_state == State.Unlocked);
        while (self.writer_queue.get()) |node| resume node.data;
        while (self.reader_queue.get()) |node| resume node.data;
    }

    pub async fn acquireRead(self: *RwLock) HeldRead {
        _ = @atomicRmw(usize, &self.reader_lock_count, .Add, 1, .SeqCst);

        suspend {
            var my_tick_node = Loop.NextTickNode{
                .data = @frame(),
                .prev = undefined,
                .next = undefined,
            };

            self.reader_queue.put(&my_tick_node);

            // At this point, we are in the reader_queue, so we might have already been resumed.

            // We set this bit so that later we can rely on the fact, that if reader_queue_empty_bit is 1,
            // some actor will attempt to grab the lock.
            _ = @atomicRmw(u8, &self.reader_queue_empty_bit, .Xchg, 0, .SeqCst);

            // Here we don't care if we are the one to do the locking or if it was already locked for reading.
            const have_read_lock = if (@cmpxchgStrong(u8, &self.shared_state, State.Unlocked, State.ReadLock, .SeqCst, .SeqCst)) |old_state| old_state == State.ReadLock else true;
            if (have_read_lock) {
                // Give out all the read locks.
                if (self.reader_queue.get()) |first_node| {
                    while (self.reader_queue.get()) |node| {
                        self.loop.onNextTick(node);
                    }
                    resume first_node.data;
                }
            }
        }
        return HeldRead{ .lock = self };
    }

    pub async fn acquireWrite(self: *RwLock) HeldWrite {
        suspend {
            var my_tick_node = Loop.NextTickNode{
                .data = @frame(),
                .prev = undefined,
                .next = undefined,
            };

            self.writer_queue.put(&my_tick_node);

            // At this point, we are in the writer_queue, so we might have already been resumed.

            // We set this bit so that later we can rely on the fact, that if writer_queue_empty_bit is 1,
            // some actor will attempt to grab the lock.
            _ = @atomicRmw(u8, &self.writer_queue_empty_bit, .Xchg, 0, .SeqCst);

            // Here we must be the one to acquire the write lock. It cannot already be locked.
            if (@cmpxchgStrong(u8, &self.shared_state, State.Unlocked, State.WriteLock, .SeqCst, .SeqCst) == null) {
                // We now have a write lock.
                if (self.writer_queue.get()) |node| {
                    // Whether this node is us or someone else, we tail resume it.
                    resume node.data;
                }
            }
        }
        return HeldWrite{ .lock = self };
    }

    fn commonPostUnlock(self: *RwLock) void {
        while (true) {
            // There might be a writer_queue item or a reader_queue item
            // If we check and both are empty, we can be done, because the other actors will try to
            // obtain the lock.
            // But if there's a writer_queue item or a reader_queue item,
            // we are the actor which must loop and attempt to grab the lock again.
            if (@atomicLoad(u8, &self.writer_queue_empty_bit, .SeqCst) == 0) {
                if (@cmpxchgStrong(u8, &self.shared_state, State.Unlocked, State.WriteLock, .SeqCst, .SeqCst) != null) {
                    // We did not obtain the lock. Great, the queues are someone else's problem.
                    return;
                }
                // If there's an item in the writer queue, give them the lock, and we're done.
                if (self.writer_queue.get()) |node| {
                    self.loop.onNextTick(node);
                    return;
                }
                // Release the lock again.
                _ = @atomicRmw(u8, &self.writer_queue_empty_bit, .Xchg, 1, .SeqCst);
                _ = @atomicRmw(u8, &self.shared_state, .Xchg, State.Unlocked, .SeqCst);
                continue;
            }

            if (@atomicLoad(u8, &self.reader_queue_empty_bit, .SeqCst) == 0) {
                if (@cmpxchgStrong(u8, &self.shared_state, State.Unlocked, State.ReadLock, .SeqCst, .SeqCst) != null) {
                    // We did not obtain the lock. Great, the queues are someone else's problem.
                    return;
                }
                // If there are any items in the reader queue, give out all the reader locks, and we're done.
                if (self.reader_queue.get()) |first_node| {
                    self.loop.onNextTick(first_node);
                    while (self.reader_queue.get()) |node| {
                        self.loop.onNextTick(node);
                    }
                    return;
                }
                // Release the lock again.
                _ = @atomicRmw(u8, &self.reader_queue_empty_bit, .Xchg, 1, .SeqCst);
                if (@cmpxchgStrong(u8, &self.shared_state, State.ReadLock, State.Unlocked, .SeqCst, .SeqCst) != null) {
                    // Didn't unlock. Someone else's problem.
                    return;
                }
                continue;
            }
            return;
        }
    }
};

test "std.event.RwLock" {
    // https://github.com/ziglang/zig/issues/2377
    if (true) return error.SkipZigTest;

    // https://github.com/ziglang/zig/issues/1908
    if (builtin.single_threaded) return error.SkipZigTest;

    const allocator = std.heap.direct_allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var lock = RwLock.init(&loop);
    defer lock.deinit();

    const handle = testLock(&loop, &lock);
    loop.run();

    const expected_result = [1]i32{shared_it_count * @intCast(i32, shared_test_data.len)} ** shared_test_data.len;
    testing.expectEqualSlices(i32, expected_result, shared_test_data);
}

async fn testLock(loop: *Loop, lock: *RwLock) void {
    var read_nodes: [100]Loop.NextTickNode = undefined;
    for (read_nodes) |*read_node| {
        const frame = loop.allocator.create(@Frame(readRunner)) catch @panic("memory");
        read_node.data = frame;
        frame.* = async readRunner(lock);
        loop.onNextTick(read_node);
    }

    var write_nodes: [shared_it_count]Loop.NextTickNode = undefined;
    for (write_nodes) |*write_node| {
        const frame = loop.allocator.create(@Frame(writeRunner)) catch @panic("memory");
        write_node.data = frame;
        frame.* = async writeRunner(lock);
        loop.onNextTick(write_node);
    }

    for (write_nodes) |*write_node| {
        const casted = @ptrCast(*const @Frame(writeRunner), write_node.data);
        await casted;
        loop.allocator.destroy(casted);
    }
    for (read_nodes) |*read_node| {
        const casted = @ptrCast(*const @Frame(readRunner), read_node.data);
        await casted;
        loop.allocator.destroy(casted);
    }
}

const shared_it_count = 10;
var shared_test_data = [1]i32{0} ** 10;
var shared_test_index: usize = 0;
var shared_count: usize = 0;

async fn writeRunner(lock: *RwLock) void {
    suspend; // resumed by onNextTick

    var i: usize = 0;
    while (i < shared_test_data.len) : (i += 1) {
        std.time.sleep(100 * std.time.microsecond);
        const lock_promise = async lock.acquireWrite();
        const handle = await lock_promise;
        defer handle.release();

        shared_count += 1;
        while (shared_test_index < shared_test_data.len) : (shared_test_index += 1) {
            shared_test_data[shared_test_index] = shared_test_data[shared_test_index] + 1;
        }
        shared_test_index = 0;
    }
}

async fn readRunner(lock: *RwLock) void {
    suspend; // resumed by onNextTick
    std.time.sleep(1);

    var i: usize = 0;
    while (i < shared_test_data.len) : (i += 1) {
        const lock_promise = async lock.acquireRead();
        const handle = await lock_promise;
        defer handle.release();

        testing.expect(shared_test_index == 0);
        testing.expect(shared_test_data[i] == @intCast(i32, shared_count));
    }
}
