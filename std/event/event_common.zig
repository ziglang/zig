//fn event_t(comptime T: type) -> type {
//    struct {
//        fd: i32,
//        handler: fn(T) -> void,
//        closure: T
//    }
//}
//fn mk_wrapper(comptime T: type) -> fn(u64, u64) -> void {
//    fn(handler_int: u64, closure_int: u64) -> void {
//        var handler = @intToPtr(&fn(T) -> void, handler_int);
//        var closure = @intToPtr(&T, closure_int);
//
//        handler(closure);
//    }
//}

pub const EventClosure = usize;
pub const TimerHandler = fn(EventClosure) -> void;
pub const ManagedHandler = fn(EventClosure) -> void;

pub const ReadHandler = fn(&const []u8, EventClosure) -> void;
pub const ConnectionHandler = fn(&StreamEvent, EventClosure) -> void;

pub const LoopStepBehavior = enum {
    Blocking,
    Nonblocking
};
