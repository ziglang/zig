const std = @import("std.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const expect = std.testing.expect;
const windows = std.os.windows;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// This type is intended to be initialized statically. If you don't
/// require static initialization, use std.Mutex.
/// On Windows, this mutex allocates resources when it is
/// first used, and the resources cannot be freed.
/// On Linux, this is an alias of std.Mutex.
pub const StaticallyInitializedMutex = switch (builtin.os) {
    builtin.Os.linux => std.Mutex,
    builtin.Os.windows => struct {
        lock: windows.CRITICAL_SECTION,
        init_once: windows.RTL_RUN_ONCE,

        pub const Held = struct {
            mutex: *StaticallyInitializedMutex,

            pub fn release(self: Held) void {
                windows.kernel32.LeaveCriticalSection(&self.mutex.lock);
            }
        };

        pub fn init() StaticallyInitializedMutex {
            return StaticallyInitializedMutex{
                .lock = undefined,
                .init_once = windows.INIT_ONCE_STATIC_INIT,
            };
        }

        extern fn initCriticalSection(
            InitOnce: *windows.RTL_RUN_ONCE,
            Parameter: ?*c_void,
            Context: ?*c_void,
        ) windows.BOOL {
            const lock = @ptrCast(*windows.CRITICAL_SECTION, @alignCast(@alignOf(windows.CRITICAL_SECTION), Parameter));
            windows.kernel32.InitializeCriticalSection(lock);
            return windows.TRUE;
        }

        /// TODO: once https://github.com/ziglang/zig/issues/287 is solved and std.Mutex has a better
        /// implementation of a runtime initialized mutex, remove this function.
        pub fn deinit(self: *StaticallyInitializedMutex) void {
            windows.InitOnceExecuteOnce(&self.init_once, initCriticalSection, &self.lock, null);
            windows.kernel32.DeleteCriticalSection(&self.lock);
        }

        pub fn acquire(self: *StaticallyInitializedMutex) Held {
            windows.InitOnceExecuteOnce(&self.init_once, initCriticalSection, &self.lock, null);
            windows.kernel32.EnterCriticalSection(&self.lock);
            return Held{ .mutex = self };
        }
    },
    else => std.Mutex,
};

test "std.StaticallyInitializedMutex" {
    const TestContext = struct {
        data: i128,

        const TestContext = @This();
        const incr_count = 10000;

        var mutex = StaticallyInitializedMutex.init();

        fn worker(ctx: *TestContext) void {
            var i: usize = 0;
            while (i != TestContext.incr_count) : (i += 1) {
                const held = mutex.acquire();
                defer held.release();

                ctx.data += 1;
            }
        }
    };

    var plenty_of_memory = try std.heap.direct_allocator.alloc(u8, 300 * 1024);
    defer std.heap.direct_allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var context = TestContext{ .data = 0 };

    if (builtin.single_threaded) {
        TestContext.worker(&context);
        expect(context.data == TestContext.incr_count);
    } else {
        const thread_count = 10;
        var threads: [thread_count]*std.Thread = undefined;
        for (threads) |*t| {
            t.* = try std.Thread.spawn(&context, TestContext.worker);
        }
        for (threads) |t|
            t.wait();

        expect(context.data == thread_count * TestContext.incr_count);
    }
}
