const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const c = std.c;

const builtin = @import("builtin");
const target = builtin.target;
const single_threaded = builtin.single_threaded;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Once = @This();

impl: Impl = .{},

pub fn call(self: *Once, comptime func: anytype, args: anytype) void {
    self.impl.call(func, args);
}

// pthread_once() doesn't support arguments
// and can be simulated with std.Thread.Futex.
pub const Impl = if (single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.os.tag.isDarwin())
    DarwinImpl
else
    FutexImpl;

const SerialImpl = struct {
    was_called: bool = false,

    fn call(self: *Impl, comptime func: anytype, args: anytype) void {
        if (self.was_called) return;
        @call(.{}, func, args);
        self.was_called = true;
    }
};

/// Simple cross-platform Once implementation 
/// for maintainers in case the others become buggy or break somehow.
const SimpleFutexImpl = struct {
    mutex: std.Thread.Mutex = .{},
    called: Atomic(bool) = Atomic(bool).init(false),

    fn call(self: *Impl, comptime func: anytype, args: anytype) void {
        if (self.called.load(.Acquire))
            return;

        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.called.loadUnchecked()) {
            _ = @call(.{}, func, args);
            self.called.store(true, .Release);
        }
    }
};

/// Darwin implementation which relies on dispatch_once
/// which does some COMM_PAGE access magic 
/// and waits more efficiently than FutexImpl.
const DarwinImpl = struct {
    once: os.darwin.dispatch_once_t = 0,

    fn call(self: *Impl, comptime func: anytype, args: anytype) void {
        const Args = @TypeOf(args);
        const InitFn = struct {
            fn init(context: ?*c_void) callconv(.C) void {
                _ = @call(.{}, func, blk: {
                    // @alignCast() below doesn't support zero-sized-types (ZST)
                    if (@sizeOf(Args) == 0)
                        break :blk @as(Args, undefined);

                    const ptr = context orelse unreachable;
                    const args_ptr = @ptrCast(*Args, @alignCast(@alignOf(Args), ptr));
                    break :blk args_ptr.*;
                });
            }
        };

        var args_ptr: *c_void = undefined;
        if (@sizeOf(Args) > 0)
            args_ptr = @intToPtr(*c_void, @ptrToInt(&args));

        os.darwin.dispatch_once_f(&self.once, args_ptr, InitFn.init);
    }
};

/// Windows implementation relying on INIT_ONCE 
/// which uses NtWaitForAlertByThreadId
/// and waits for efficiently than FutexImpl.
const WindowsImpl = struct {
    once: os.windows.INIT_ONCE = os.windows.INIT_ONCE_STATIC_INIT,

    fn call(self: *Impl, comptime func: anytype, args: anytype) void {
        const Args = @TypeOf(args);
        const InitFn = struct {
            fn init(once: *os.windows.INIT_ONCE, parameter: ?*c_void, context: ?*c_void) callconv(.C) os.windows.BOOL {
                _ = once;
                _ = context;                
                _ = @call(.{}, func, blk: {
                    // @alignCast() below doesn't support zero-sized-types (ZST)
                    if (@sizeOf(Args) == 0)
                        break :blk @as(Args, undefined);

                    const ptr = parameter orelse unreachable;
                    const args_ptr = @ptrCast(*Args, @alignCast(@alignOf(Args), ptr));
                    break :blk args_ptr.*;
                });
                return os.windows.TRUE;
            }
        };

        var args_ptr: *c_void = undefined;
        if (@sizeOf(Args) > 0)
            args_ptr = @intToPtr(*c_void, @ptrToInt(&args));

        os.windows.InitOnceExecuteOnce(&self.once, InitFn.init, args_ptr, null);
    }
};

/// Futex implementation heavily optimized for fast paths
const FutexImpl = extern struct {
    state: Atomic(u32) = Atomic(u32).init(UNCALLED),

    const UNCALLED = 0;
    const CALLING = 1;
    const WAITING = 2;
    const CALLED = 3;

    fn call(self: *Impl, comptime func: anytype, args: anytype) void {
        // Fast path, Acquire barrier to ensure callSlow changes are seen on return.
        if (self.state.load(.Acquire) == CALLED) 
            return;

        self.callSlow(func, args);
    }

    noinline fn callSlow(self: *Impl, comptime func: anytype, args: anytype) void {
        @setCold(true);

        // Try to transition from UNCALLED -> CALLING in order to call func().
        // Once called, transition to CALLED and wake up waiting threads if WAITING.
        var state = self.state.load(.Acquire);
        if (state == UNCALLED) {
            state = self.state.compareAndSwap(UNCALLED, CALLING, .Acquire, .Acquire) orelse {
                _ = @call(.{}, func, args);
                return switch (self.state.swap(CALLED, .Release)) {
                    UNCALLED => unreachable, // invoked function while not CALLING
                    CALLING => {},
                    WAITING => Futex.wake(&self.state, std.math.maxInt(u32)),
                    CALLED => unreachable, // invoked function when already CALLED
                    else => unreachable, // invalid Once state
                };
            };
        }

        // Spin a bit on the Once in hopes the thread calling f() finishes quickly.
        // Only spin if there are no other threads waiting on the Once (!= WAITING).
        var spin = SpinWait{};
        while (state == CALLING and spin.yield()) {
            state = self.state.load(.Acquire);
        }

        // If we've spun for too long and the thread calling f() hasn't finished yet,
        // then update the state to WAITING to signify that threads are sleeping.
        if (state == CALLING) {
            state = self.state.compareAndSwap(
                CALLING,
                WAITING,
                .Acquire,
                .Acquire,
            ) orelse WAITING;
        }

        // Wait on the state until the thread calling f() finishes and wakes us up.
        while (state == WAITING) {
            Futex.wait(&self.state, WAITING, null) catch unreachable;
            state = self.state.load(.Acquire);
        }

        // It was called.. right?
        assert(state == CALLED);
    }
};

test "Once" {
    const num_threads = 4;
    const Context = struct {
        var once = Once{};
        var number: i32 = 0;

        fn inc(value: i32) void {
            number += value;
        }

        fn call() void {
            once.call(inc, .{1});
        }
    };

    if (single_threaded) {
        Context.call();
        Context.call();
    } else {
        var threads: [num_threads]std.Thread = undefined;
        for (threads) |*t| t.* = try std.Thread.spawn(.{}, Context.call, .{});
        for (threads) |t| t.join();
    }

    try testing.expectEqual(Context.number, 1);
}
