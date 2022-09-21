const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}
var frame: anyframe = undefined;

pub fn main() !void {
    _ = async amain();
    resume frame;
    return error.TestFailed;
}

fn amain() void {
    var f = async func();
    await f;
    await f;
}

fn func() void {
    suspend {
        frame = @frame();
    }
}
// run
// backend=stage1
// target=native
