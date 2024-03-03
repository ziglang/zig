const std = @import("std");

/// Checks the existence of files relative to cwd.
/// A path starting with ! should not exist.
pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();

    const arena = arena_state.allocator();

    var arg_it = try std.process.argsWithAllocator(arena);
    _ = arg_it.next();

    const cwd = std.fs.cwd();
    const cwd_realpath = try cwd.realpathAlloc(arena, ".");

    while (arg_it.next()) |file_path| {
        if (file_path.len > 0 and file_path[0] == '!') {
            errdefer std.log.err(
                "exclusive file check '{s}{c}{s}' failed",
                .{ cwd_realpath, std.fs.path.sep, file_path[1..] },
            );
            if (std.fs.cwd().statFile(file_path[1..])) |_| {
                return error.FileFound;
            } else |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            }
        } else {
            errdefer std.log.err(
                "inclusive file check '{s}{c}{s}' failed",
                .{ cwd_realpath, std.fs.path.sep, file_path },
            );
            _ = try std.fs.cwd().statFile(file_path);
        }
    }
}
