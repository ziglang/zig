const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var global_x: i32 = 1;

test "simple coroutine suspend and resume" {
    const frame = async simpleAsyncFn();
    expect(global_x == 2);
    resume frame;
    expect(global_x == 3);
    const af: anyframe->void = &frame;
    resume frame;
    expect(global_x == 4);
}
fn simpleAsyncFn() void {
    global_x += 1;
    suspend;
    global_x += 1;
    suspend;
    global_x += 1;
}

var global_y: i32 = 1;

test "pass parameter to coroutine" {
    const p = async simpleAsyncFnWithArg(2);
    expect(global_y == 3);
    resume p;
    expect(global_y == 5);
}
fn simpleAsyncFnWithArg(delta: i32) void {
    global_y += delta;
    suspend;
    global_y += delta;
}

test "suspend at end of function" {
    const S = struct {
        var x: i32 = 1;

        fn doTheTest() void {
            expect(x == 1);
            const p = async suspendAtEnd();
            expect(x == 2);
        }

        fn suspendAtEnd() void {
            x += 1;
            suspend;
        }
    };
    S.doTheTest();
}

test "local variable in async function" {
    const S = struct {
        var x: i32 = 0;

        fn doTheTest() void {
            expect(x == 0);
            const p = async add(1, 2);
            expect(x == 0);
            resume p;
            expect(x == 0);
            resume p;
            expect(x == 0);
            resume p;
            expect(x == 3);
        }

        fn add(a: i32, b: i32) void {
            var accum: i32 = 0;
            suspend;
            accum += a;
            suspend;
            accum += b;
            suspend;
            x = accum;
        }
    };
    S.doTheTest();
}

test "calling an inferred async function" {
    const S = struct {
        var x: i32 = 1;
        var other_frame: *@Frame(other) = undefined;

        fn doTheTest() void {
            const p = async first();
            expect(x == 1);
            resume other_frame.*;
            expect(x == 2);
        }

        fn first() void {
            other();
        }
        fn other() void {
            other_frame = @frame();
            suspend;
            x += 1;
        }
    };
    S.doTheTest();
}

test "@frameSize" {
    const S = struct {
        fn doTheTest() void {
            {
                var ptr = @ptrCast(async fn(i32) void, other);
                const size = @frameSize(ptr);
                expect(size == @sizeOf(@Frame(other)));
            }
            {
                var ptr = @ptrCast(async fn() void, first);
                const size = @frameSize(ptr);
                expect(size == @sizeOf(@Frame(first)));
            }
        }

        fn first() void {
            other(1);
        }
        fn other(param: i32) void {
            var local: i32 = undefined;
            suspend;
        }
    };
    S.doTheTest();
}

test "coroutine suspend, resume" {
    seq('a');
    const p = async testAsyncSeq();
    seq('c');
    resume p;
    seq('f');
    // `cancel` is now a suspend point so it cannot be done here
    seq('g');

    expect(std.mem.eql(u8, points, "abcdefg"));
}
async fn testAsyncSeq() void {
    defer seq('e');

    seq('b');
    suspend;
    seq('d');
}
var points = [_]u8{0} ** "abcdefg".len;
var index: usize = 0;

fn seq(c: u8) void {
    points[index] = c;
    index += 1;
}

test "coroutine suspend with block" {
    const p = async testSuspendBlock();
    expect(!result);
    resume a_promise;
    expect(result);
}

var a_promise: anyframe = undefined;
var result = false;
async fn testSuspendBlock() void {
    suspend {
        comptime expect(@typeOf(@frame()) == *@Frame(testSuspendBlock));
        a_promise = @frame();
    }

    // Test to make sure that @frame() works as advertised (issue #1296)
    // var our_handle: anyframe = @frame();
    expect(a_promise == anyframe(@frame()));

    result = true;
}

var await_a_promise: anyframe = undefined;
var await_final_result: i32 = 0;

test "coroutine await" {
    await_seq('a');
    const p = async await_amain();
    await_seq('f');
    resume await_a_promise;
    await_seq('i');
    expect(await_final_result == 1234);
    expect(std.mem.eql(u8, await_points, "abcdefghi"));
}
async fn await_amain() void {
    await_seq('b');
    const p = async await_another();
    await_seq('e');
    await_final_result = await p;
    await_seq('h');
}
async fn await_another() i32 {
    await_seq('c');
    suspend {
        await_seq('d');
        await_a_promise = @frame();
    }
    await_seq('g');
    return 1234;
}

var await_points = [_]u8{0} ** "abcdefghi".len;
var await_seq_index: usize = 0;

fn await_seq(c: u8) void {
    await_points[await_seq_index] = c;
    await_seq_index += 1;
}

var early_final_result: i32 = 0;

test "coroutine await early return" {
    early_seq('a');
    const p = async early_amain();
    early_seq('f');
    expect(early_final_result == 1234);
    expect(std.mem.eql(u8, early_points, "abcdef"));
}
async fn early_amain() void {
    early_seq('b');
    const p = async early_another();
    early_seq('d');
    early_final_result = await p;
    early_seq('e');
}
async fn early_another() i32 {
    early_seq('c');
    return 1234;
}

var early_points = [_]u8{0} ** "abcdef".len;
var early_seq_index: usize = 0;

fn early_seq(c: u8) void {
    early_points[early_seq_index] = c;
    early_seq_index += 1;
}

test "async function with dot syntax" {
    const S = struct {
        var y: i32 = 1;
        async fn foo() void {
            y += 1;
            suspend;
        }
    };
    const p = async S.foo();
    // can't cancel in tests because they are non-async functions
    expect(S.y == 2);
}

//test "async fn pointer in a struct field" {
//    var data: i32 = 1;
//    const Foo = struct {
//        bar: async<*std.mem.Allocator> fn (*i32) void,
//    };
//    var foo = Foo{ .bar = simpleAsyncFn2 };
//    const p = (async<allocator> foo.bar(&data)) catch unreachable;
//    expect(data == 2);
//    cancel p;
//    expect(data == 4);
//}
//async<*std.mem.Allocator> fn simpleAsyncFn2(y: *i32) void {
//    defer y.* += 2;
//    y.* += 1;
//    suspend;
//}

//test "async fn with inferred error set" {
//    const p = async failing();
//    resume p;
//}
//
//async fn failing() !void {
//    suspend;
//    return error.Fail;
//}

//test "error return trace across suspend points - early return" {
//    const p = nonFailing();
//    resume p;
//    const p2 = try async<allocator> printTrace(p);
//    cancel p2;
//}
//
//test "error return trace across suspend points - async return" {
//    const p = nonFailing();
//    const p2 = try async<std.debug.global_allocator> printTrace(p);
//    resume p;
//    cancel p2;
//}
//
//fn nonFailing() (anyframe->anyerror!void) {
//    return async<std.debug.global_allocator> suspendThenFail() catch unreachable;
//}
//async fn suspendThenFail() anyerror!void {
//    suspend;
//    return error.Fail;
//}
//async fn printTrace(p: anyframe->(anyerror!void)) void {
//    (await p) catch |e| {
//        std.testing.expect(e == error.Fail);
//        if (@errorReturnTrace()) |trace| {
//            expect(trace.index == 1);
//        } else switch (builtin.mode) {
//            builtin.Mode.Debug, builtin.Mode.ReleaseSafe => @panic("expected return trace"),
//            builtin.Mode.ReleaseFast, builtin.Mode.ReleaseSmall => {},
//        }
//    };
//}

test "break from suspend" {
    var my_result: i32 = 1;
    const p = async testBreakFromSuspend(&my_result);
    // can't cancel here
    std.testing.expect(my_result == 2);
}
async fn testBreakFromSuspend(my_result: *i32) void {
    suspend {
        resume @frame();
    }
    my_result.* += 1;
    suspend;
    my_result.* += 1;
}
