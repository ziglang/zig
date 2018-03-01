const std = @import("std");
const assert = std.debug.assert;

var x: i32 = 1;

test "create a coroutine and cancel it" {
    const p = try (async(std.debug.global_allocator) simpleAsyncFn());
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
    const p = (async(std.debug.global_allocator) testAsyncSeq()) catch unreachable;
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
