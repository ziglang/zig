const std = @import("std");
const Atomic = std.atomic.Atomic;
const assert = std.debug.assert;
const WaitGroup = @This();

const is_waiting: usize = 1 << 0;
const one_pending: usize = 1 << 1;

state: Atomic(usize) = Atomic(usize).init(0),
event: std.Thread.ResetEvent = .{},

pub fn start(self: *WaitGroup) void {
    const state = self.state.fetchAdd(one_pending, .Monotonic);
    assert((state / one_pending) < (std.math.maxInt(usize) / one_pending));
}

pub fn finish(self: *WaitGroup) void {
    const state = self.state.fetchSub(one_pending, .Release);
    assert((state / one_pending) > 0);

    if (state == (one_pending | is_waiting)) {
        self.state.fence(.Acquire);
        self.event.set();
    }
}

pub fn wait(self: *WaitGroup) void {
    var state = self.state.fetchAdd(is_waiting, .Acquire);
    assert(state & is_waiting == 0);

    if ((state / one_pending) > 0) {
        self.event.wait();
    }
}

pub fn reset(self: *WaitGroup) void {
    self.state.store(0, .Monotonic);
    self.event.reset();
}

pub fn isDone(wg: *WaitGroup) bool {
    const state = wg.state.load(.Acquire);
    assert(state & is_waiting == 0);

    return (state / one_pending) == 0;
}
