const std = @import("std");
const assert = std.debug.assert;

var x: i32 = 1;

test "create a coroutine and cancel it" {
    const p = try async(std.debug.global_allocator) simpleAsyncFn();
    cancel p;
    assert(x == 2);
}

async fn simpleAsyncFn() void {
    x += 1;
    suspend;
    x += 1;
}

test "coroutine suspend, resume, cancel" {
    seq('a');
    const p = try async(std.debug.global_allocator) testAsyncSeq();
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
    const p = try async(std.debug.global_allocator) testSuspendBlock();
    std.debug.assert(!result);
    resume a_promise;
    std.debug.assert(result);
    cancel p;
}

var a_promise: promise = undefined;
var result = false;

async fn testSuspendBlock() void {
    suspend |p| {
        a_promise = p;
    }
    result = true;
}

var await_a_promise: promise = undefined;
var await_final_result: i32 = 0;

test "coroutine await" {
    await_seq('a');
    const p = async(std.debug.global_allocator) await_amain() catch unreachable;
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
    early_seq('a');
    const p = async(std.debug.global_allocator) early_amain() catch unreachable;
    early_seq('f');
    assert(early_final_result == 1234);
    assert(std.mem.eql(u8, early_points, "abcdef"));
}

async fn early_amain() void {
    early_seq('b');
    const p = async early_another() catch unreachable;
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
    if (async(&failing_allocator.allocator) asyncFuncThatNeverGetsRun()) {
        @panic("expected allocation failure");
    } else |err| switch (err) {
        error.OutOfMemory => {},
    }
}

async fn asyncFuncThatNeverGetsRun() void {
    @panic("coro frame allocation should fail");
}
