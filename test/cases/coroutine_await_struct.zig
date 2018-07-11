const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const Foo = struct {
    x: i32,
};

var await_a_promise: promise = undefined;
var await_final_result = Foo{ .x = 0 };

test "coroutine await struct" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();

    await_seq('a');
    const p = async<&da.allocator> await_amain() catch unreachable;
    await_seq('f');
    resume await_a_promise;
    await_seq('i');
    assert(await_final_result.x == 1234);
    assert(std.mem.eql(u8, await_points, "abcdefghi"));
}
async fn await_amain() void {
    await_seq('b');
    const p = async await_another() catch unreachable;
    await_seq('e');
    await_final_result = await p;
    await_seq('h');
}
async fn await_another() Foo {
    await_seq('c');
    suspend |p| {
        await_seq('d');
        await_a_promise = p;
    }
    await_seq('g');
    return Foo{ .x = 1234 };
}

var await_points = []u8{0} ** "abcdefghi".len;
var await_seq_index: usize = 0;

fn await_seq(c: u8) void {
    await_points[await_seq_index] = c;
    await_seq_index += 1;
}
