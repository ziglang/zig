const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    const input_path = args[1];
    const optimize_mode_text = args[2];

    const input_bytes = try std.fs.cwd().readFileAlloc(arena, input_path, 5 * 1024 * 1024);
    const optimize_mode = std.meta.stringToEnum(std.builtin.OptimizeMode, optimize_mode_text).?;

    var stderr = input_bytes;

    // process result
    // - keep only basename of source file path
    // - replace address with symbolic string
    // - replace function name with symbolic string when optimize_mode != .Debug
    // - skip empty lines
    const got: []const u8 = got_result: {
        var buf = std.ArrayList(u8).init(arena);
        defer buf.deinit();
        if (stderr.len != 0 and stderr[stderr.len - 1] == '\n') stderr = stderr[0 .. stderr.len - 1];
        var it = mem.splitScalar(u8, stderr, '\n');
        process_lines: while (it.next()) |line| {
            if (line.len == 0) continue;

            // offset search past `[drive]:` on windows
            var pos: usize = if (builtin.os.tag == .windows) 2 else 0;
            // locate delims/anchor
            const delims = [_][]const u8{ ":", ":", ":", " in ", "(", ")" };
            var marks = [_]usize{0} ** delims.len;
            for (delims, 0..) |delim, i| {
                marks[i] = mem.indexOfPos(u8, line, pos, delim) orelse {
                    // unexpected pattern: emit raw line and cont
                    try buf.appendSlice(line);
                    try buf.appendSlice("\n");
                    continue :process_lines;
                };
                pos = marks[i] + delim.len;
            }
            // locate source basename
            pos = mem.lastIndexOfScalar(u8, line[0..marks[0]], fs.path.sep) orelse {
                // unexpected pattern: emit raw line and cont
                try buf.appendSlice(line);
                try buf.appendSlice("\n");
                continue :process_lines;
            };
            // end processing if source basename changes
            if (!mem.eql(u8, "source.zig", line[pos + 1 .. marks[0]])) break;
            // emit substituted line
            try buf.appendSlice(line[pos + 1 .. marks[2] + delims[2].len]);
            try buf.appendSlice(" [address]");
            if (optimize_mode == .Debug) {
                // On certain platforms (windows) or possibly depending on how we choose to link main
                // the object file extension may be present so we simply strip any extension.
                if (mem.indexOfScalar(u8, line[marks[4]..marks[5]], '.')) |idot| {
                    try buf.appendSlice(line[marks[3] .. marks[4] + idot]);
                    try buf.appendSlice(line[marks[5]..]);
                } else {
                    try buf.appendSlice(line[marks[3]..]);
                }
            } else {
                try buf.appendSlice(line[marks[3] .. marks[3] + delims[3].len]);
                try buf.appendSlice("[function]");
            }
            try buf.appendSlice("\n");
        }
        break :got_result try buf.toOwnedSlice();
    };

    try std.io.getStdOut().writeAll(got);
}
