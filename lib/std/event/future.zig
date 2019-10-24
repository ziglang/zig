const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const builtin = @import("builtin");
const Lock = std.event.Lock;
const Loop = std.event.Loop;

/// This is a value that starts out unavailable, until resolve() is called
/// While it is unavailable, functions suspend when they try to get() it,
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
        const Queue = std.atomic.Queue(anyframe);

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
            if (@atomicLoad(u8, &self.available, .SeqCst) == 2) {
                return &self.data;
            }
            const held = self.lock.acquire();
            held.release();

            return &self.data;
        }

        /// Gets the data without waiting for it. If it's available, a pointer is
        /// returned. Otherwise, null is returned.
        pub fn getOrNull(self: *Self) ?*T {
            if (@atomicLoad(u8, &self.available, .SeqCst) == 2) {
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
            const state = @cmpxchgStrong(u8, &self.available, 0, 1, .SeqCst, .SeqCst) orelse return null;
            switch (state) {
                1 => {
                    const held = self.lock.acquire();
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
            const prev = @atomicRmw(u8, &self.available, .Xchg, 2, .SeqCst);
            assert(prev == 0 or prev == 1); // resolve() called twice
            Lock.Held.release(Lock.Held{ .lock = &self.lock });
        }
    };
}

test "std.event.Future" {
    // https://github.com/ziglang/zig/issues/1908
    if (builtin.single_threaded) return error.SkipZigTest;
    // https://github.com/ziglang/zig/issues/3251
    if (builtin.os == .freebsd) return error.SkipZigTest;

    const allocator = std.heap.direct_allocator;

    var loop: Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    const handle = async testFuture(&loop);

    loop.run();
}

fn testFuture(loop: *Loop) void {
    var future = Future(i32).init(loop);

    var a = async waitOnFuture(&future);
    var b = async waitOnFuture(&future);
    resolveFuture(&future);

    const result = (await a) + (await b);

    testing.expect(result == 12);
}

fn waitOnFuture(future: *Future(i32)) i32 {
    return future.get().*;
}

fn resolveFuture(future: *Future(i32)) void {
    future.data = 6;
    future.resolve();
}
