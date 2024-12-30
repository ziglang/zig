const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;

pub fn once(comptime f: fn () void) Once(f) {
    return Once(f){};
}

/// An object that executes the function `f` just once.
/// It is undefined behavior if `f` re-enters the same Once instance.
pub fn Once(comptime f: fn () void) type {
    return struct {
        done: bool = false,
        mutex: std.Thread.Mutex = std.Thread.Mutex{},

        /// Call the function `f`.
        /// If `call` is invoked multiple times `f` will be executed only the
        /// first time.
        /// The invocations are thread-safe.
        pub fn call(self: *@This()) void {
            if (@atomicLoad(bool, &self.done, .acquire))
                return;

            return self.callSlow();
        }

        fn callSlow(self: *@This()) void {
            @branchHint(.cold);

            self.mutex.lock();
            defer self.mutex.unlock();

            // The first thread to acquire the mutex gets to run the initializer
            if (!self.done) {
                f();
                @atomicStore(bool, &self.done, true, .release);
            }
        }
    };
}

var global_number: i32 = 0;
var global_once = once(incr);

fn incr() void {
    global_number += 1;
}

test "Once executes its function just once" {
    if (builtin.single_threaded) {
        global_once.call();
        global_once.call();
    } else {
        var threads: [10]std.Thread = undefined;
        var thread_count: usize = 0;
        defer for (threads[0..thread_count]) |handle| handle.join();

        for (&threads) |*handle| {
            handle.* = try std.Thread.spawn(.{}, struct {
                fn thread_fn(x: u8) void {
                    _ = x;
                    global_once.call();
                    if (global_number != 1) @panic("memory ordering bug");
                }
            }.thread_fn, .{0});
            thread_count += 1;
        }
    }

    try testing.expectEqual(@as(i32, 1), global_number);
}
