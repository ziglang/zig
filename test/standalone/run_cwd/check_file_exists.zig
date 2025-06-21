pub fn main() !void {
    var arena_state: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len != 2) return error.BadUsage;
    const path = args[1];

    std.fs.cwd().access(path, .{}) catch return error.AccessFailed;
}

const std = @import("std");
