const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const WaitGroup = @This();

const is_waiting: usize = 1 << 0;
const one_pending: usize = 1 << 1;

state: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
event: std.Thread.ResetEvent = .{},

/// Increments the wait group counter. Thread-safe.
pub fn start(self: *WaitGroup) void {
    const state = self.state.fetchAdd(one_pending, .monotonic);
    assert((state / one_pending) < (std.math.maxInt(usize) / one_pending));
}

/// Decrements the wait group counter. Thread-safe.
/// If this sets the counter to zero, all waiters are woken.
pub fn finish(self: *WaitGroup) void {
    const state = self.state.fetchSub(one_pending, .release);
    assert((state / one_pending) > 0);

    if (state == (one_pending | is_waiting)) {
        self.state.fence(.acquire);
        self.event.set();
    }
}

/// Blocks until the wait group counter reaches zero. Thread-safe.
pub fn wait(self: *WaitGroup) void {
    const state = self.state.fetchAdd(is_waiting, .acquire);
    assert(state & is_waiting == 0);

    if ((state / one_pending) > 0) {
        self.event.wait();
    }
}

/// Resets the wait group to its initial state for reuse.
pub fn reset(self: *WaitGroup) void {
    self.state.store(0, .monotonic);
    self.event.reset();
}

/// Returns `true` if the wait group counter is zero, `false` otherwise. Thread-safe.
/// Depending on the behavior of other threads, it may be a race condition to rely on this value.
pub fn isDone(wg: *WaitGroup) bool {
    const state = wg.state.load(.acquire);
    assert(state & is_waiting == 0);

    return (state / one_pending) == 0;
}

/// Spawns a new thread for the task. This is appropriate when the callee
/// delegates all work.
pub fn spawnManager(
    wg: *WaitGroup,
    comptime func: anytype,
    args: anytype,
) void {
    if (builtin.single_threaded) {
        @call(.auto, func, args);
        return;
    }
    const Manager = struct {
        fn run(wg_inner: *WaitGroup, args_inner: @TypeOf(args)) void {
            defer wg_inner.finish();
            @call(.auto, func, args_inner);
        }
    };
    wg.start();
    _ = std.Thread.spawn(.{}, Manager.run, .{ wg, args }) catch Manager.run(wg, args);
}
