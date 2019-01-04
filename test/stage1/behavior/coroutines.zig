const std = @import("std");
const builtin = @import("builtin");
const assertOrPanic = std.debug.assertOrPanic;

var x: i32 = 1;

test "create a coroutine and cancel it" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    const p = try async<&da.allocator> simpleAsyncFn();
    comptime assertOrPanic(@typeOf(p) == promise->void);
    cancel p;
    assertOrPanic(x == 2);
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

    assertOrPanic(std.mem.eql(u8, points, "abcdefg"));
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
    std.debug.assertOrPanic(!result);
    resume a_promise;
    std.debug.assertOrPanic(result);
    cancel p;
}

var a_promise: promise = undefined;
var result = false;
async fn testSuspendBlock() void {
    suspend {
        comptime assertOrPanic(@typeOf(@handle()) == promise->void);
        a_promise = @handle();
    }

    //Test to make sure that @handle() works as advertised (issue #1296)
    //var our_handle: promise = @handle();
    assertOrPanic(a_promise == @handle());

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
    assertOrPanic(await_final_result == 1234);
    assertOrPanic(std.mem.eql(u8, await_points, "abcdefghi"));
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
    suspend {
        await_seq('d');
        await_a_promise = @handle();
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
    assertOrPanic(early_final_result == 1234);
    assertOrPanic(std.mem.eql(u8, early_points, "abcdef"));
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

