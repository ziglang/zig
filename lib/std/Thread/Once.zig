const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const c = std.c;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Once = @This();

impl: Impl = .{},

pub fn call(self: *Once, comptime f: fn () void) void {
    self.impl.call(f);
}

pub const Impl = if (std.builtin.single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.os.tag.isDarwin())
    DarwinImpl
else if (std.Thread.use_pthreads)
    PosixImpl
else
    FutexImpl;

const SerialImpl = struct {
    was_called: bool = false,

    fn call(self: *Impl, f: fn () void) void {
        if (self.was_called) return;
        f();
        self.was_called = true;
    }
};

const DarwinImpl = struct {
    once: os.darwin.dispatch_once_t = 0,

    fn call(self: *Impl, comptime f: fn () void) void {
        const InitFn = struct {
            fn init(ctx: ?*c_void) callconv(.C) void {
                _ = ctx;
                f();
            }
        };
        os.darwin.dispatch_once_f(&self.once, null, InitFn.init);
    }
};

const WindowsImpl = struct {
    once: os.windows.INIT_ONCE = os.windows.INIT_ONCE_STATIC_INIT,

    fn call(self: *Impl, comptime f: fn () void) void {
        const InitFn = struct {
            fn init(once: *os.windows.INIT_ONCE, param: ?*c_void, ctx: ?*c_void) callconv(.C) os.windows.BOOL {
                _ = once;
                _ = param;
                _ = ctx;
                f();
                return os.windows.TRUE;
            }
        };
        os.windows.InitOnceExecuteOnce(&self.once, InitFn.init, null, null);
    }
};

const PosixImpl = extern struct {
    once: c.pthread_once_t = .{},

    fn call(self: *Impl, comptime f: fn () void) void {
        const InitFn = struct {
            fn init() callconv(.C) void {
                f();
            }
        };
        assert(c.pthread_once(&self.once, InitFn.init) == .SUCCESS);
    }
};

const FutexImpl = extern struct {
    state: Atomic(u32) = Atomic(u32).init(UNCALLED),

    const UNCALLED = 0;
    const CALLING = 1;
    const WAITING = 2;
    const CALLED = 3;

    fn call(self: *Impl, f: fn () void) void {
        if (self.state.load(.Acquire) == CALLED) return;
        self.callSlow(f);
    }

    noinline fn callSlow(self: *Impl, f: fn () void) void {
        @setCold(true);

        // Try to transition from UNCALLED -> CALLING in order to call f().
        // Once called, transition to CALLED and wake up waiting threads if WAITING.
        var state = self.state.load(.Acquire);
        if (state == UNCALLED) {
            state = self.state.compareAndSwap(UNCALLED, CALLING, .Acquire, .Acquire) orelse {
                f();
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

        fn inc() void {
            number += 1;
        }

        fn call() void {
            once.call(inc);
        }
    };

    if (std.builtin.single_threaded) {
        Context.call();
        Context.call();
    } else {
        var threads: [num_threads]std.Thread = undefined;
        for (threads) |*t| t.* = try std.Thread.spawn(.{}, Context.call, .{});
        for (threads) |t| t.join();
    }

    try testing.expectEqual(Context.number, 1);
}
