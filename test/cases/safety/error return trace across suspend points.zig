const std = @import("std");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    std.process.exit(0);
}

var failing_frame: @Frame(failing) = undefined;

pub fn main() !void {
    const p = nonFailing();
    resume p;
    const p2 = async printTrace(p);
    _ = p2;
    return error.TestFailed;
}

fn nonFailing() anyframe->anyerror!void {
    failing_frame = async failing();
    return &failing_frame;
}

fn failing() anyerror!void {
    suspend {}
    return second();
}

fn second() callconv(.Async) anyerror!void {
    return error.Fail;
}

fn printTrace(p: anyframe->anyerror!void) void {
    (await p) catch unreachable;
}
// run
// backend=stage1
// target=native
