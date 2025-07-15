const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
    const stdout = &stdout_writer.interface;
    var args = try std.process.argsAlloc(arena);
    for (args[1..], 1..) |arg, i| {
        try stdout.writeAll(arg);
        if (i != args.len - 1) try stdout.writeByte('\x00');
    }
}
