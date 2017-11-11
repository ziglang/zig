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

    pub fn step(loop: &Loop) -> %void {
        loop.os.step()
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
        var os = %return event_os.Timer.init(timeout, @ptrToInt(closure), @ptrToInt(handler));
        Self {
            .os = os
        }
    }

    pub fn start(timer: &Self, loop: &Loop) -> %void {
        timer.os.start(&loop.os)
    }

    pub fn stop(timer: &Self, loop: &Loop) -> %void {
        timer.os.stop(&loop.os)
    }
};
