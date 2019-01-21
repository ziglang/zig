const std = @import("std");
const builtin = @import("builtin");
const assertOrPanic = std.debug.assertOrPanic;

test "async fn with inferred error set" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    const p = (async<&da.allocator> failing()) catch unreachable;
    resume p;
    cancel p;
}

async fn failing() !void {
    suspend;
    return error.Fail;
}

test "error return trace across suspend points - early return" {
    const p = nonFailing();
    resume p;
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    const p2 = try async<&da.allocator> printTrace(p);
    cancel p2;
}

test "error return trace across suspend points - async return" {
    const p = nonFailing();
    const p2 = try async<std.debug.global_allocator> printTrace(p);
    resume p;
    cancel p2;
}

fn nonFailing() (promise->anyerror!void) {
    return async<std.debug.global_allocator> suspendThenFail() catch unreachable;
}
async fn suspendThenFail() anyerror!void {
    suspend;
    return error.Fail;
}
async fn printTrace(p: promise->(anyerror!void)) void {
    (await p) catch |e| {
        std.debug.assertOrPanic(e == error.Fail);
        if (@errorReturnTrace()) |trace| {
            assertOrPanic(trace.index == 1);
        } else switch (builtin.mode) {
            builtin.Mode.Debug, builtin.Mode.ReleaseSafe => @panic("expected return trace"),
            builtin.Mode.ReleaseFast, builtin.Mode.ReleaseSmall => {},
        }
    };
}
