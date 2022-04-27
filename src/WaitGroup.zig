const std = @import("std");
const Atomic = std.atomic.Atomic;
const assert = std.debug.assert;
const WaitGroup = @This();

const is_waiting: usize = 1 << 0;
const one_pending: usize = 1 << 1;

state: usize = 0,
event: std.Thread.ResetEvent = .{},

pub fn start(self: *WaitGroup) void {
    const state = @atomicRmw(usize, &self.state, .Add, one_pending, .Monotonic);
    assert((state / one_pending) < (std.math.maxInt(usize) / one_pending));
}

pub fn finish(self: *WaitGroup) void {
    // AcqRel as Release to ensure accesses before the finish() call happen-before the thread which Acquires.
    // AcqRel as Acquire to ensure accesses before previous finish() calls happen-before the last pending thread to set the event.
    const state = @atomicRmw(usize, &self.state, .Sub, one_pending, .AcqRel);
    assert((state / one_pending) > 0);

    if (state == (one_pending | is_waiting)) {
        // ResetEvent's Release barrier ensures the pending decrement happens-before the event is set().
        // The Acquire barrier on the pending decrement ensures all thread's finish() happen-before the event is set().
        self.event.set();
    }
}

// Must be called by the single consumer thread.
pub fn wait(self: *WaitGroup) void {
    // Mark the WaitGroup as waiting while observing the state (there should be only one waiter).
    // Acquire barrier ensures that if we observe pending=0 then all finish() calls happen-before we return.
    var state = @atomicRmw(usize, &self.state, .Add, is_waiting, .Acquire);
    assert(state & is_waiting == 0);

    if ((state / one_pending) > 0) {
        // Wait until all pending threads call finish() which should see is_waiting and set the ResetEvent.
        // ResetEvent's Acquire barrier ensures that all finish()s happen-before we return.
        self.event.wait();
    }
}

// Must be called by the single consumer thread.
pub fn reset(self: *WaitGroup) void {
    @atomicStore(usize, &self.state, 0, .Monotonic);
    self.event.reset();
}
