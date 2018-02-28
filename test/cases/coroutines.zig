const std = @import("std");
const assert = std.debug.assert;

var x: i32 = 1;

test "create a coroutine and cancel it" {
    const p = try (async(std.debug.global_allocator) emptyAsyncFn());
    cancel p;
    assert(x == 2);
}

async fn emptyAsyncFn() void {
    x += 1;
    suspend;
    x += 1;
}
