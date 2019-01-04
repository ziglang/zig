const std = @import("std");
const builtin = @import("builtin");
const assertOrPanic = std.debug.assertOrPanic;

test "coro allocation failure" {
    var failing_allocator = std.debug.FailingAllocator.init(std.debug.global_allocator, 0);
    if (async<&failing_allocator.allocator> asyncFuncThatNeverGetsRun()) {
        @panic("expected allocation failure");
    } else |err| switch (err) {
        error.OutOfMemory => {},
    }
}
async fn asyncFuncThatNeverGetsRun() void {
    @panic("coro frame allocation should fail");
}

test "async function with dot syntax" {
    const S = struct {
        var y: i32 = 1;
        async fn foo() void {
            y += 1;
            suspend;
        }
    };
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    const p = try async<&da.allocator> S.foo();
    cancel p;
    assertOrPanic(S.y == 2);
}

test "async fn pointer in a struct field" {
    var data: i32 = 1;
    const Foo = struct {
        bar: async<*std.mem.Allocator> fn (*i32) void,
    };
    var foo = Foo{ .bar = simpleAsyncFn2 };
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    const p = (async<&da.allocator> foo.bar(&data)) catch unreachable;
    assertOrPanic(data == 2);
    cancel p;
    assertOrPanic(data == 4);
}
async<*std.mem.Allocator> fn simpleAsyncFn2(y: *i32) void {
    defer y.* += 2;
    y.* += 1;
    suspend;
}

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

test "break from suspend" {
    var buf: [500]u8 = undefined;
    var a = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;
    var my_result: i32 = 1;
    const p = try async<a> testBreakFromSuspend(&my_result);
    cancel p;
    std.debug.assertOrPanic(my_result == 2);
}
async fn testBreakFromSuspend(my_result: *i32) void {
    suspend {
        resume @handle();
    }
    my_result.* += 1;
    suspend;
    my_result.* += 1;
}
