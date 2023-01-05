const std = @import("std");

pub fn main() !void {
    var argv_iter = try std.process.ArgIterator.initWithAllocator(std.heap.page_allocator);
    defer argv_iter.deinit();

    _ = argv_iter.next() orelse @panic("missing arg[0]");

    const argv1 = argv_iter.next() orelse @panic("missing arg[1]");

    var file = try std.fs.openFileAbsolute(argv1, .{});
    defer file.close();

    const expected = "<-- content -->";
    var actual: [expected.len]u8 = undefined;

    try file.reader().readNoEof(&actual);

    if (!std.mem.eql(u8, expected, &actual))
        @panic("file contents not equal");
}
