const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

use @import("event_common.zig");

const event_os = switch (builtin.os) {
    builtin.Os.linux => @import("event_linux.zig"),
    else => @compileError("unsupported event os"),
};

error OsError;

pub const Event = struct {
    os: event_os.Event,
    context: EventContext
};

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

    pub fn register(event: &ManagedEvent, loop: &Loop) -> %void {
        event.os.register(&loop.os)
    }

    pub fn unregister(event: &ManagedEvent, loop: &Loop) -> %void {
        event.os.unregister(&loop.os)
    }

    pub fn trigger(event: &Self) -> %void {
        event.os.trigger()
    }
};

pub const NetworkEvent = struct {
    os: event_os.NetworkEvent,

    const Self = this;

    pub fn init() -> %Self {

    }
};

pub const StreamListener = struct {
    os: event_os.StreamListener,

    const Self = this;

    pub fn init(context: var, comptime read_context_type: type,
            conn_handler: &const fn(@typeOf(context)) -> %&read_context_type,
            read_handler: &const fn(&const []u8, &read_context_type) -> void) -> Self {
        Self {
            .os = event_os.StreamListener.init(
                @ptrToInt(context),
                @ptrToInt(conn_handler),
                @ptrToInt(read_handler))
        }
    }

    pub fn listen_tcp(listener: &Self, hostname: []const u8, port: u16) -> %void {
        listener.os.listen_tcp(hostname, port)
    }

    pub fn register(listener: &Self, loop: &Loop) -> %void {
        listener.os.register(&loop.os)
    }
};
