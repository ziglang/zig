//! Checks that the basename of the given path matches a string.
//!
//! Usage:
//!
//! ```
//! has_basename <path> <basename>
//! ```
//!
//! <path> must be absolute.
//!
//! Returns a non-zero exit code if basename
//! does not match the given string.

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
        std.log.err("path must be absolute", .{});
        return error.BadUsage;
    }

    const basename = args.next() orelse {
        std.log.err("missing <basename> argument", .{});
        return error.BadUsage;
    };

    const actual_basename = std.fs.path.basename(path);
    if (std.mem.eql(u8, actual_basename, basename)) {
        return;
    }

    return error.NotEqual;
}
