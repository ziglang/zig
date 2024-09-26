const std = @import("std");

pub fn panic(cause: std.builtin.PanicCause, stack_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = stack_trace;
    if (cause == .corrupt_switch) {
        std.process.exit(0);
    }
    std.process.exit(1);
}

const E = enum(u32) {
    X = 1,
    Y = 2,
};

pub fn main() !void {
    var e: E = undefined;
    @memset(@as([*]u8, @ptrCast(&e))[0..@sizeOf(E)], 0x55);
    switch (e) {
        .X, .Y => @breakpoint(),
    }
    return error.TestFailed;
}

// run
// backend=llvm
// target=native
