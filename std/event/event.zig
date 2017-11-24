const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

use @import("event_common.zig");

const event_os = switch (builtin.os) {
    builtin.Os.linux => @import("event_linux.zig"),
    else => @compileError("unsupported event os"),
};

error OsError;

// All structs in this file are thin wrappers around the OS-specific versions
// of the equivalent structs.  In some cases the internal OS implementations
// rely on the fact that these two data types are identical, so there should
// not be extra data fields added to these wrapper structs.
// The main benefit that this additional layer provides right now is that
// it enforces type safety between client callbacks and client-provided closures.
// However, once that is no longer necessary we should remove this intermediate
// layer altogether and simply enforce that all platforms expose identical
// interfaces.

//pub const Event = struct {
//    os: event_os.Event,
//    context: EventContext
//};

pub const Loop = struct {
    os: event_os.Loop,

    const Self = this;

    pub fn init() -> %Self {
        Self {
            .os = %return event_os.Loop.init()
        }
    }

    pub fn step(loop: &Loop, blocking: LoopStepBehavior) -> %void {
        loop.os.step(blocking)
    }

    pub fn run(loop: &Loop) -> %void {
        loop.os.run()
    }
};

// timeouts represented in nanoseconds
pub const Timer = struct {
    os: event_os.Timer,

    const Self = this;

    pub fn init(timeout: u64, closure: var, handler: &const fn(@typeOf(closure)) -> void) -> %Self {
        Self {
            .os = %return event_os.Timer.init(timeout, @ptrToInt(closure), @ptrToInt(handler))
        }
    }

    pub fn start(timer: &Self, loop: &Loop) -> %void {
        timer.os.start(&loop.os)
    }

    pub fn stop(timer: &Self, loop: &Loop) -> %void {
        timer.os.stop(&loop.os)
    }
};

pub const ManagedEvent = struct {
    os: event_os.ManagedEvent,

    const Self = this;

    pub fn init(closure: var, handler: &const fn(@typeOf(closure)) -> void) -> %Self {
        Self {
            .os = %return event_os.ManagedEvent.init(@ptrToInt(closure), @ptrToInt(handler))
        }
    }

    pub fn register(event: &Self, loop: &Loop) -> %void {
        event.os.register(&loop.os)
    }

    pub fn unregister(event: &Self, loop: &Loop) -> %void {
        event.os.unregister(&loop.os)
    }

    pub fn trigger(event: &Self) -> %void {
        event.os.trigger()
    }
};

pub const NetworkEvent = struct {
    os: event_os.NetworkEvent,

    const Self = this;

    pub fn init(md: &const event_os.EventMd,
            closure: var,
            read_handler: &const fn(&const []u8, @typeOf(closure)) -> void)
            -> %Self {
        NetworkEvent {
            .os = %return event_os.NetworkEvent.init(md, @ptrToInt(closure),
                @ptrToInt(read_handler))
        }
    }

    pub fn register(event: &Self, loop: &Loop) -> %void {
        event.os.register(&loop.os)
    }

    pub fn unregister(event: &Self, loop: &Loop) -> %void {
        event.os.unregister(&loop.os)
    }


};

pub const StreamListener = struct {
    os: event_os.StreamListener,

    const Self = this;

    pub fn init(context: var,
            conn_handler: &const fn(&const event_os.EventMd, @typeOf(context)) -> %void)
            -> Self {
        Self {
            .os = event_os.StreamListener.init(
                @ptrToInt(context),
                @ptrToInt(conn_handler))
        }
    }

    pub fn listen_tcp(listener: &Self, hostname: []const u8, port: u16) -> %void {
        listener.os.listen_tcp(hostname, port)
    }

    pub fn register(listener: &Self, loop: &Loop) -> %void {
        listener.os.register(&loop.os)
    }
};
