const std = @import("std");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();
    const args = try std.process.argsAlloc(arena);
    std.debug.assert(args.len == 4);
    const out_dir = args[1];
    const hash = args[2];
    const no_unpack = args[3];

    if (!std.fs.path.isAbsolute(out_dir)) {
        std.log.err("directory '{s}' must be absolute", .{out_dir});
        std.process.exit(0xff);
    }

    var dir = try std.fs.openDirAbsolute(out_dir, .{});
    defer dir.close();

    try writeFile(dir, "example_dep_file.txt", @embedFile("example/example_dep_file.txt"));

    const package_path_absolute = try arena.dupe(u8, out_dir);
    for (package_path_absolute) |*c| {
        c.* = if (c.* == '\\') '/' else c.*;
    }
    const template: Template = .{
        .package_path_absolute = package_path_absolute,
        .hash = hash,
        .no_unpack = no_unpack,
    };
    try writeFile(dir, "build.zig", try template.process(arena, @embedFile("example/build.zig.template")));
    try writeFile(dir, "build.zig.zon", try template.process(arena, @embedFile("example/build.zig.zon.template")));
}

const Template = struct {
    package_path_absolute: []const u8,
    hash: []const u8,
    no_unpack: []const u8,
    pub fn process(self: Template, arena: std.mem.Allocator, template: []const u8) ![]const u8 {
        const content1 = try std.mem.replaceOwned(u8, arena, template, "<PACKAGE_PATH_ABSOLUTE>", self.package_path_absolute);
        defer arena.free(content1);
        const content2 = try std.mem.replaceOwned(u8, arena, content1, "<HASH>", self.hash);
        defer arena.free(content2);
        return try std.mem.replaceOwned(u8, arena, content2, "<NO_UNPACK>", self.no_unpack);
    }
};

fn writeFile(dir: std.fs.Dir, name: []const u8, content: []const u8) !void {
    const file = try dir.createFile(name, .{});
    defer file.close();
    try file.writer().writeAll(content);
}
