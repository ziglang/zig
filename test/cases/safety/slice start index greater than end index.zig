const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .start_index_greater_than_end => |info| {
            if (info.start == 10 and info.end == 1) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}

pub fn main() !void {
    var a: usize = 1;
    var b: usize = 10;
    _ = .{ &a, &b };
    var buf: [16]u8 = undefined;

    const slice = buf[b..a];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
