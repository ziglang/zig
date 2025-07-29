const std = @import("std");
const assert = std.debug.assert;
const info = std.log.info;
const fatal = std.process.fatal;

const Allocator = std.mem.Allocator;

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = general_purpose_allocator.allocator();

const usage =
    \\gen_macos_headers_c [dir]
    \\
    \\General Options:
    \\-h, --help                    Print this help and exit
;

pub fn main() anyerror!void {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const args = try std.process.argsAlloc(arena);
    if (args.len == 1) fatal("no command or option specified", .{});

    var positionals = std.ArrayList([]const u8).init(arena);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return info(usage, .{});
        } else try positionals.append(arg);
    }

    if (positionals.items.len != 1) fatal("expected one positional argument: [dir]", .{});

    var dir = try std.fs.cwd().openDir(positionals.items[0], .{ .no_follow = true });
    defer dir.close();
    var paths = std.ArrayList([]const u8).init(arena);
    try findHeaders(arena, dir, "", &paths);

    const SortFn = struct {
        pub fn lessThan(ctx: void, lhs: []const u8, rhs: []const u8) bool {
            _ = ctx;
            return std.mem.lessThan(u8, lhs, rhs);
        }
    };

    std.mem.sort([]const u8, paths.items, {}, SortFn.lessThan);

    var buffer: [2000]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&buffer);
    const w = &stdout_writer.interface;
    try w.writeAll("#define _XOPEN_SOURCE\n");
    for (paths.items) |path| {
        try w.print("#include <{s}>\n", .{path});
    }
    try w.writeAll(
        \\int main(int argc, char **argv) {
        \\    return 0;
        \\}
    );
    try w.flush();
}

fn findHeaders(
    arena: Allocator,
    dir: std.fs.Dir,
    prefix: []const u8,
    paths: *std.ArrayList([]const u8),
) anyerror!void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                const path = try std.fs.path.join(arena, &.{ prefix, entry.name });
                var subdir = try dir.openDir(entry.name, .{ .no_follow = true });
                defer subdir.close();
                try findHeaders(arena, subdir, path, paths);
            },
            .file, .sym_link => {
                const ext = std.fs.path.extension(entry.name);
                if (!std.mem.eql(u8, ext, ".h")) continue;
                const path = try std.fs.path.join(arena, &.{ prefix, entry.name });
                try paths.append(path);
            },
            else => {},
        }
    }
}
