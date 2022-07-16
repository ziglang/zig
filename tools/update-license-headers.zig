const std = @import("std");

/// This script replaces a matching license header from .zig source files in a directory tree
/// with the `new_header` below.
const new_header = "";

pub fn main() !void {
    var progress = std.Progress{};
    const root_node = progress.start("", 0);
    defer root_node.end();

    var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_allocator.allocator();

    const args = try std.process.argsAlloc(arena);
    const path_to_walk = args[1];
    const iterable_dir = try std.fs.cwd().openIterableDir(path_to_walk, .{});

    var walker = try iterable_dir.walk(arena);
    defer walker.deinit();

    var buffer: [500]u8 = undefined;
    const expected_header = buffer[0..try std.io.getStdIn().readAll(&buffer)];

    while (try walker.next()) |entry| {
        if (!std.mem.endsWith(u8, entry.basename, ".zig"))
            continue;

        var node = root_node.start(entry.basename, 0);
        node.activate();
        defer node.end();

        const source = try iterable_dir.dir.readFileAlloc(arena, entry.path, 20 * 1024 * 1024);
        if (!std.mem.startsWith(u8, source, expected_header)) {
            std.debug.print("no match: {s}\n", .{entry.path});
            continue;
        }

        const truncated_source = source[expected_header.len..];

        const new_source = try arena.alloc(u8, truncated_source.len + new_header.len);
        std.mem.copy(u8, new_source, new_header);
        std.mem.copy(u8, new_source[new_header.len..], truncated_source);

        try iterable_dir.dir.writeFile(entry.path, new_source);
    }
}
