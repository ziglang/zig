const std = @import("std");
const WaitGroup = @This();

counter: usize = 0,
event: ?*std.AutoResetEvent = null,

pub fn start(self: *WaitGroup) void {
    _ = @atomicRmw(usize, &self.counter, .Add, 1, .SeqCst);
}

pub fn stop(self: *WaitGroup) void {
    if (@atomicRmw(usize, &self.counter, .Sub, 1, .SeqCst) == 1)
        if (@atomicRmw(?*std.AutoResetEvent, &self.event, .Xchg, null, .SeqCst)) |event|
            event.set();
}

pub fn wait(self: *WaitGroup) void {
    var event = std.AutoResetEvent{};
    @atomicStore(?*std.AutoResetEvent, &self.event, &event, .SeqCst);
    if (@atomicLoad(usize, &self.counter, .SeqCst) != 0)
        event.wait();
}
