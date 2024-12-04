const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const DebugFormat = enum {
    symbols,
    dwarf32,
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    const input_path = args[1];
    const debug_format_text = args[2];

    const input_bytes = try std.fs.cwd().readFileAlloc(arena, input_path, 5 * 1024 * 1024);
    const debug_format = std.meta.stringToEnum(DebugFormat, debug_format_text).?;
    _ = debug_format;

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
            const delims = [_][]const u8{ ":", ":", ":", " in ", " (", ")" };
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

            const source_file = line[0..marks[0]];
            const source_line = line[marks[0] + delims[0].len .. marks[1]];
            const source_column = line[marks[1] + delims[1].len .. marks[2]];
            const trace_address = line[marks[2] + delims[2].len .. marks[3]];
            const source_symbol = line[marks[3] + delims[3].len .. marks[4]];
            const source_compile_unit = line[marks[4] + delims[4].len .. marks[5]];

            _ = trace_address;

            const source_file_basename = std.fs.path.basename(source_file);
            const is_unknown_source_file = mem.allEqual(u8, source_file, '?');

            // stop processing once the symbols are no longer the source file
            if (!is_unknown_source_file and !mem.eql(u8, source_file_basename, "source.zig")) {
                break;
            } else if (is_unknown_source_file and !mem.startsWith(u8, source_symbol, "source.")) {
                break;
            }

            // On Windows specifically, the compile unit can end with `.exe` or `.exe.obj`
            const source_compile_unit_extension_stripped = if (mem.indexOfScalar(u8, source_compile_unit, '.')) |idot|
                source_compile_unit[0..idot]
            else
                source_compile_unit;

            // emit substituted line
            try buf.writer().print("{s}:{s}:{s}: [address] in {s} ({s})", .{
                source_file_basename,
                source_line,
                source_column,
                source_symbol,
                source_compile_unit_extension_stripped,
            });

            try buf.appendSlice("\n");
        }
        break :got_result try buf.toOwnedSlice();
    };

    try std.io.getStdOut().writeAll(got);
}
