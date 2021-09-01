const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

const SpinWait = @import("SpinWait.zig");
const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Once = @This();

impl: Impl = .{},

pub fn call(self: *Once, comptime f: fn() void) void {
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

    fn call(self: *Impl, comptime f: fn() void) void {
        if (self.was_called) return;
        f();
        self.was_called = true;
    }
};

const DarwinImpl = struct {
    once: os.darwin.dispatch_once_t = 0,

    fn call(self: *Impl, comptime f: fn() void) void {
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

    fn call(self: *Impl, comptime f: fn() void) void {
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

    fn call(self: *Impl, comptime f: fn() void) void {
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

    fn call(self: *Impl, comptime f: fn() void) void {
        if (self.state.load(.Acquire) == CALLED) return;
        self.callSlow(f);
    }

    noinline fn callSlow(self: *Impl, comptime f: fn() void) void {
        @setCold(true);

        var spin = SpinWait{};
        var state = self.state.load(.Acquire);
        while (true) {
            state = switch (state) {
                // Transition from UNCALLED -> CALLING in order to invoke f().
                // Once done, transition to CALLED and wake any waiting threads if WAITING.
                UNCALLED => self.state.tryCompareAndSwap(state, CALLING, .Acquire, .Acquire) orelse {
                    f();
                    return switch (self.state.swap(CALLED, .Release)) {
                        UNCALLED => unreachable, // CALLED function while not CALLING
                        CALLING => {},
                        WAITING => Futex.wake(&self.state, std.math.maxInt(u32)),
                        CALLED => unreachable, // CALLED function when already CALLED
                    };
                },
                CALLING => blk: {
                    // Spin a bit in hopes that the CALLING thread will be finished soon.
                    if (spin.yield()) {
                        break :blk self.state.load(.Acquire);
                    }

                    // Transition to WAITING to ensure that the CALLING thread wakes us up when it's done.
                    break :blk self.state.tryCompareAndSwap(
                        CALLING,
                        WAITING,
                        .Acquire,
                        .Acquire,
                    ) orelse WAITING;
                },
                WAITING => blk: {
                    // Wait on the state for the CALLING thread to finish and wake us up.
                    Futex.wait(&self.state, WAITING, null) catch unreachable;
                    break :Blk self.state.load(.Acquire);
                },
                CALLED => {
                    // The function has finally been called
                    return;
                },
            };
        }
    }
};