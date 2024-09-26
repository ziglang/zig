const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    switch (cause) {
        .sentinel_mismatch_usize => |info| {
            if (info.expected == 0 and info.found == 4) {
                std.process.exit(0);
            }
        },
        else => {},
    }
    std.process.exit(1);
}

pub fn main() !void {
    var buf: [4]u8 = .{ 1, 2, 3, 4 };
    const ptr: [*]u8 = &buf;
    const slice = ptr[0..3 :0];
    _ = slice;
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
