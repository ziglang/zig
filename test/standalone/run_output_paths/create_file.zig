const std = @import("std");

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = args.skip();
    const dir_name = args.next().?;
    const dir = try std.fs.cwd().openDir(if (std.mem.startsWith(u8, dir_name, "--dir="))
        dir_name["--dir=".len..]
    else
        dir_name, .{});
    const file_name = args.next().?;
    const file = try dir.createFile(file_name, .{});
    try file.writer().print(
        \\{s}
        \\{s}
        \\Hello, world!
        \\
    , .{ dir_name, file_name });
}
