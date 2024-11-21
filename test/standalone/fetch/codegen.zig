const std = @import("std");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();
    const args = try std.process.argsAlloc(arena);
    std.debug.assert(args.len == 2);
    const out_dir = args[1];

    if (!std.fs.path.isAbsolute(out_dir)) {
        std.log.err("directory '{s}' must be absolute", .{out_dir});
        std.process.exit(0xff);
    }

    var dir = try std.fs.openDirAbsolute(out_dir, .{});
    defer dir.close();

    try writeFile(dir, "build.zig", @embedFile("example/build.zig"));
    try writeFile(dir, "example_dep_file.txt", @embedFile("example/example_dep_file.txt"));

    {
        const template = @embedFile("example/build.zig.zon.template");
        const package_path_absolute = try arena.dupe(u8, out_dir);
        for (package_path_absolute) |*c| {
            c.* = if (c.* == '\\') '/' else c.*;
        }
        const content = try std.mem.replaceOwned(u8, arena, template, "<PACKAGE_PATH_ABSOLUTE>", package_path_absolute);
        try writeFile(dir, "build.zig.zon", content);
    }
}

fn writeFile(dir: std.fs.Dir, name: []const u8, content: []const u8) !void {
    const file = try dir.createFile(name, .{});
    defer file.close();
    try file.writer().writeAll(content);
}
