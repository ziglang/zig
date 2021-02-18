pub fn doSomething() !void {
    try @import("std").io.getStdOut().writeAll("a message from pkg.zig\n");
}
