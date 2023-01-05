const std = @import("std");

pub fn main() !void {
    var argv_iter = try std.process.ArgIterator.initWithAllocator(std.heap.page_allocator);
    defer argv_iter.deinit();

    _ = argv_iter.next() orelse @panic("missing arg[0]");

    const argv1 = argv_iter.next() orelse @panic("missing arg[1]");

    var file = try std.fs.createFileAbsolute(argv1, .{});
    defer file.close();

    try file.writeAll("<-- content -->");
}
