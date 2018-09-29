const std = @import("../index.zig");
const assert = std.debug.assert;
const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const Lock = std.event.Lock;
const Loop = std.event.Loop;

/// This is a value that starts out unavailable, until resolve() is called
/// While it is unavailable, coroutines suspend when they try to get() it,
/// and then are resumed when resolve() is called.
/// At this point the value remains forever available, and another resolve() is not allowed.
pub fn Future(comptime T: type) type {
    return struct {
        lock: Lock,
        data: T,

        /// TODO make this an enum
        /// 0 - not started
        /// 1 - started
        /// 2 - finished
        available: u8,

        const Self = @This();
        const Queue = std.atomic.Queue(promise);

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
        pub async fn get(self: *Self) *T {
            if (@atomicLoad(u8, &self.available, AtomicOrder.SeqCst) == 2) {
                return &self.data;
            }
            const held = await (async self.lock.acquire() catch unreachable);
            held.release();

            return &self.data;
        }

        /// Gets the data without waiting for it. If it's available, a pointer is
        /// returned. Otherwise, null is returned.
        pub fn getOrNull(self: *Self) ?*T {
            if (@atomicLoad(u8, &self.available, AtomicOrder.SeqCst) == 2) {
                return &self.data;
            } else {
                return null;
            }
        }

        /// If someone else has started working on the data, wait for them to complete
        /// and return a pointer to the data. Otherwise, return null, and the caller
        /// should start working on the data.
        /// It's not required to call start() before resolve() but it can be useful since
        /// this method is thread-safe.
        pub async fn start(self: *Self) ?*T {
            const state = @cmpxchgStrong(u8, &self.available, 0, 1, AtomicOrder.SeqCst, AtomicOrder.SeqCst) orelse return null;
            switch (state) {
                1 => {
                    const held = await (async self.lock.acquire() catch unreachable);
                    held.release();
                    return &self.data;
                },
                2 => return &self.data,
                else => unreachable,
            }
        }

        /// Make the data become available. May be called only once.
        /// Before calling this, modify the `data` property.
        pub fn resolve(self: *Self) void {
            const prev = @atomicRmw(u8, &self.available, AtomicRmwOp.Xchg, 2, AtomicOrder.SeqCst);
            assert(prev == 0 or prev == 1); // resolve() called twice
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
    suspend {
        resume @handle();
    }
    var future = Future(i32).init(loop);

    const a = async waitOnFuture(&future) catch @panic("memory");
    const b = async waitOnFuture(&future) catch @panic("memory");
    const c = async resolveFuture(&future) catch @panic("memory");

    const result = (await a) + (await b);
    cancel c;
    assert(result == 12);
}

async fn waitOnFuture(future: *Future(i32)) i32 {
    suspend {
        resume @handle();
    }
    return (await (async future.get() catch @panic("memory"))).*;
}

async fn resolveFuture(future: *Future(i32)) void {
    suspend {
        resume @handle();
    }
    future.data = 6;
    future.resolve();
}
