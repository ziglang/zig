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

// triggered on newly accepted network connections
// returns a newly allocated closure to be used for all subsequent operations on
// this connection.
// the user is responsible for the memory management of this closure (i.e. its
// lifetime must be such that it is available for future callbacks, and the user
// must free it once the connection is closed)
pub const ConnectionHandler = fn(EventClosure) -> EventClosure;

// triggered when data is read from a network connection
// the first argument is the data read from the connection and the second
// argument is the closure created by the connection handler when the connection
// was first opened.
pub const ReadHandler = fn(&const []u8, EventClosure) -> void;

pub const LoopStepBehavior = enum {
    Blocking,
    Nonblocking
};
