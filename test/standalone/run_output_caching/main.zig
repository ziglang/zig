const std = @import("std");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.skip();
    const filename = args.next().?;
    const file = try std.fs.createFileAbsolute(filename, .{});
    defer file.close();
    try file.writeAll(filename);
}
