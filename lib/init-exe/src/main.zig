const std = @import("std");

pub fn main() !void {
    // Prints to stderr
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // Prints to stdout
    const unbuffered_out = std.io.getStdOut().writer();
    const out = std.io.bufferedWriter(unbuffered_out).writer();
    try out.print("Run `zig build test` to run the tests.\n", .{});

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(list.pop(), 42);
}
