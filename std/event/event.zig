const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

fn event_t(comptime T: type) -> type {
    struct {
        fd: i32,
        handler: fn(T) -> void,
        closure: T
    }
}

fn mk_wrapper(comptime T: type) -> fn(u64, u64) -> void {
    fn(handler_int: u64, closure_int: u64) -> void {
        var handler = @intToPtr(&fn(T) -> void, handler_int);
        var closure = @intToPtr(&T, closure_int);

        handler(closure);
    }
}

event_context = struct {
    wrapper,
    handler_as_int,
    closure_as_int
};


fn mk_timer(timeout: u64, closure: var, handler: fn(@typeOf(closure)) -> void) -> event_t(@typeOf(closure)) {
    var fd = timerfd_create(stuff);
    settimer

    event_t {
        .fd = timerfd,
        .context = event_context {
            .wrapper = mk_wrapper(@typeOf(closure)),
            .handler_as_int = handler,
            .closure_as_int = closure
        }
    }
}
