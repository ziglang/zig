const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .index_out_of_bounds => |info| {
            if (info.index == 4 and info.len == 4) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}
pub fn main() !void {
    const a = [_]i32{ 1, 2, 3, 4 };
    baz(bar(&a));
    return error.TestFailed;
}
fn bar(a: []const i32) i32 {
    return a[4];
}
fn baz(_: i32) void {}
// run
// backend=llvm
// target=native
