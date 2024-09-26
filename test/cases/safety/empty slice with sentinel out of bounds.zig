const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .index_out_of_bounds => |info| {
            if (info.index == 1 and info.len == 0) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf_zero = [0]u8{};
    const input: []u8 = &buf_zero;
    const slice = input[0..0 :0];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
