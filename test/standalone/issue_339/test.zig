const StackTrace = @import("builtin").StackTrace;
pub fn panic(msg: []const u8, stack_trace: ?*StackTrace) noreturn {
    @breakpoint();
    while (true) {}
}

fn bar() error!void {}

export fn foo() void {
    bar() catch unreachable;
}
