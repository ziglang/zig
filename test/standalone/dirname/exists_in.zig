//! Verifies that a file exists in a directory.
//!
//! Usage:
//!
//! ```
//! exists_in <dir> <path>
//! ```
//!
//! Where `<dir>/<path>` is the full path to the file.
//! `<dir>` must be an absolute path.

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

    const dir_path = args.next() orelse {
        std.log.err("missing <dir> argument", .{});
        return error.BadUsage;
    };

    if (!std.fs.path.isAbsolute(dir_path)) {
        std.log.err("expected <dir> to be an absolute path", .{});
        return error.BadUsage;
    }

    const relpath = args.next() orelse {
        std.log.err("missing <path> argument", .{});
        return error.BadUsage;
    };

    var dir = try std.fs.openDirAbsolute(dir_path, .{});
    defer dir.close();

    _ = try dir.statFile(relpath);
}
