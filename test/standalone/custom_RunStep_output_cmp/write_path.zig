pub fn main() !void {
    const stdout = @import("std").io.getStdOut();
    try stdout.writeAll("/bruh/ok");
}
