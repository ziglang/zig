const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

var x: i32 = 1;

test "create a coroutine and cancel it" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const p = try async<&da.allocator> simpleAsyncFn();
    comptime assert(@typeOf(p) == promise->void);
    cancel p;
    assert(x == 2);
}
async fn simpleAsyncFn() void {
    x += 1;
    suspend;
    x += 1;
}

test "coroutine suspend, resume, cancel" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    seq('a');
    const p = try async<&da.allocator> testAsyncSeq();
    seq('c');
    resume p;
    seq('f');
    cancel p;
    seq('g');

    assert(std.mem.eql(u8, points, "abcdefg"));
}
async fn testAsyncSeq() void {
    defer seq('e');

    seq('b');
    suspend;
    seq('d');
}
var points = []u8{0} ** "abcdefg".len;
var index: usize = 0;

fn seq(c: u8) void {
    points[index] = c;
    index += 1;
}

test "coroutine suspend with block" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const p = try async<&da.allocator> testSuspendBlock();
    std.debug.assert(!result);
    resume a_promise;
    std.debug.assert(result);
    cancel p;
}

var a_promise: promise = undefined;
var result = false;
async fn testSuspendBlock() void {
    suspend |p| {
        comptime assert(@typeOf(p) == promise->void);
        a_promise = p;
    }
    result = true;
}

var await_a_promise: promise = undefined;
var await_final_result: i32 = 0;

test "coroutine await" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    await_seq('a');
    const p = async<&da.allocator> await_amain() catch unreachable;
    await_seq('f');
    resume await_a_promise;
    await_seq('i');
    assert(await_final_result == 1234);
    assert(std.mem.eql(u8, await_points, "abcdefghi"));
}
async fn await_amain() void {
    await_seq('b');
    const p = async await_another() catch unreachable;
    await_seq('e');
    await_final_result = await p;
    await_seq('h');
}
async fn await_another() i32 {
    await_seq('c');
    suspend |p| {
        await_seq('d');
        await_a_promise = p;
    }
    await_seq('g');
    return 1234;
}

var await_points = []u8{0} ** "abcdefghi".len;
var await_seq_index: usize = 0;

fn await_seq(c: u8) void {
    await_points[await_seq_index] = c;
    await_seq_index += 1;
}

var early_final_result: i32 = 0;

test "coroutine await early return" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    early_seq('a');
    const p = async<&da.allocator> early_amain() catch @panic("out of memory");
    early_seq('f');
    assert(early_final_result == 1234);
    assert(std.mem.eql(u8, early_points, "abcdef"));
}
async fn early_amain() void {
    early_seq('b');
    const p = async early_another() catch @panic("out of memory");
    early_seq('d');
    early_final_result = await p;
    early_seq('e');
}
async fn early_another() i32 {
    early_seq('c');
    return 1234;
}

var early_points = []u8{0} ** "abcdef".len;
var early_seq_index: usize = 0;

fn early_seq(c: u8) void {
    early_points[early_seq_index] = c;
    early_seq_index += 1;
}

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
    assert(S.y == 2);
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
    assert(data == 2);
    cancel p;
    assert(data == 4);
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

// TODO https://github.com/ziglang/zig/issues/760
fn nonFailing() (promise->error!void) {
    return async<std.debug.global_allocator> suspendThenFail() catch unreachable;
}
async fn suspendThenFail() error!void {
    suspend;
    return error.Fail;
}
async fn printTrace(p: promise->error!void) void {
    (await p) catch |e| {
        std.debug.assert(e == error.Fail);
        if (@errorReturnTrace()) |trace| {
            assert(trace.index == 1);
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
    std.debug.assert(my_result == 2);
}
async fn testBreakFromSuspend(my_result: *i32) void {
    s: suspend |p| {
        break :s;
    }
    my_result.* += 1;
    suspend;
    my_result.* += 1;
}
