//! Creates a file at the given path, if it doesn't already exist.
//!
//! ```
//! touch <path>
//! ```
//!
//! Path must be absolute.

const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_state.allocator();
    defer arena_state.deinit();

    try run(arena);
}

fn run(allocator: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next() orelse unreachable; // skip binary name

    const path = args.next() orelse {
        std.log.err("missing <path> argument", .{});
        return error.BadUsage;
    };

    if (!std.fs.path.isAbsolute(path)) {
        std.log.err("path must be absolute: {s}", .{path});
        return error.BadUsage;
    }

    const dir_path = std.fs.path.dirname(path) orelse unreachable;
    const basename = std.fs.path.basename(path);

    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    _ = dir.statFile(basename) catch {
        var file = try dir.createFile(basename, .{});
        file.close();
    };
}
