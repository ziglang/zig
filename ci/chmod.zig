const std = @import("std");

pub fn main() !void {
    var args_it = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args_it.deinit();
    _ = args_it.skip();
    while (args_it.next()) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => continue,
            else => |e| return e,
        };
        defer file.close();
        var got_access_denied = false;
        while (true) {
            const old_mode = try file.mode();
            const new_mode = old_mode | (std.posix.S.IXUSR | std.posix.S.IXGRP | std.posix.S.IXOTH);
            if (new_mode != old_mode) file.chmod(new_mode) catch |err| switch (err) {
                // This can happen on macOS during a race condition where another process adds the
                // executable bits and executes the file between this process reading the old mode
                // and setting the new mode.  In the case, getting the mode again will return the
                // newly set executable bits and so this code will not be reached the second time.
                error.AccessDenied => |e| {
                    if (got_access_denied) return e;
                    got_access_denied = true;
                    continue;
                },
                else => |e| return e,
            };
            break;
        }
    }
}
