const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .index_out_of_bounds => |info| {
            if (info.index == 16 and info.len == 5) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}
pub fn main() !void {
    var buf: [5]u8 = undefined;
    _ = buf[foo(6)..][0..10];
    return error.TestFailed;
}
fn foo(a: u32) u32 {
    return a;
}
// run
// backend=llvm
// target=native
