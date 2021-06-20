const StackTrace = @import("std").builtin.StackTrace;
pub fn panic(msg: []const u8, stack_trace: ?*StackTrace) noreturn {
    _ = msg;
    _ = stack_trace;
    @breakpoint();
    while (true) {}
}

fn bar() anyerror!void {}

export fn foo() void {
    bar() catch unreachable;
}
