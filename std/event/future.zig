const std = @import("../index.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const Lock = std.event.Lock;
const Loop = std.event.Loop;

/// This is a value that starts out unavailable, until a value is put().
/// While it is unavailable, coroutines suspend when they try to get() it,
/// and then are resumed when the value is put().
/// At this point the value remains forever available, and another put() is not allowed.
pub fn Future(comptime T: type) type {
    return struct {
        lock: Lock,
        data: T,
        available: u8, // TODO make this a bool

        const Self = this;
        const Queue = std.atomic.QueueMpsc(promise);

        pub fn init(loop: *Loop) Self {
            return Self{
                .lock = Lock.initLocked(loop),
                .available = 0,
                .data = undefined,
            };
        }

        /// Obtain the value. If it's not available, wait until it becomes
        /// available.
        /// Thread-safe.
        pub async fn get(self: *Self) T {
            if (@atomicLoad(u8, &self.available, AtomicOrder.SeqCst) == 1) {
                return self.data;
            }
            const held = await (async self.lock.acquire() catch unreachable);
            defer held.release();

            return self.data;
        }

        /// Make the data become available. May be called only once.
        pub fn put(self: *Self, value: T) void {
            self.data = value;
            const prev = @atomicRmw(u8, &self.available, AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst);
            assert(prev == 0); // put() called twice
            Lock.Held.release(Lock.Held{ .lock = &self.lock });
        }
    };
}

test "std.event.Future" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const allocator = &da.allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    const handle = try async<allocator> testFuture(&loop);
    defer cancel handle;

    loop.run();
}

async fn testFuture(loop: *Loop) void {
    var future = Future(i32).init(loop);

    const a = async waitOnFuture(&future) catch @panic("memory");
    const b = async waitOnFuture(&future) catch @panic("memory");
    const c = async resolveFuture(&future) catch @panic("memory");

    const result = (await a) + (await b);
    cancel c;
    assert(result == 12);
}

async fn waitOnFuture(future: *Future(i32)) i32 {
    return await (async future.get() catch @panic("memory"));
}

async fn resolveFuture(future: *Future(i32)) void {
    future.put(6);
}
