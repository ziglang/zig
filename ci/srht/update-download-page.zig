const std = @import("std");
const path = std.fs.path;
const mem = std.mem;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const out_dir = "out";
    try std.fs.cwd().makePath(out_dir);
    {
        const out_file = out_dir ++ path.sep_str ++ "index.html";
        const in_file = "index.html";
        try render(allocator, in_file, out_file, .html);
    }
    {
        const out_file = out_dir ++ path.sep_str ++ "index.json";
        const in_file = "index.json";
        try render(allocator, in_file, out_file, .plain);
    }
}

fn render(
    allocator: *mem.Allocator,
    in_file: []const u8,
    out_file: []const u8,
    fmt: enum {
        html,
        plain,
    },
) !void {
    const in_contents = try std.fs.cwd().readFileAlloc(allocator, in_file, 1 * 1024 * 1024);

    var vars = try std.process.getEnvMap(allocator);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const State = enum {
        Start,
        OpenBrace,
        VarName,
        EndBrace,
    };
    const writer = buffer.writer();
    var state = State.Start;
    var var_name_start: usize = undefined;
    var line: usize = 1;
    for (in_contents) |byte, index| {
        switch (state) {
            State.Start => switch (byte) {
                '{' => {
                    state = State.OpenBrace;
                },
                else => try writer.writeByte(byte),
            },
            State.OpenBrace => switch (byte) {
                '{' => {
                    state = State.VarName;
                    var_name_start = index + 1;
                },
                else => {
                    try writer.writeByte('{');
                    try writer.writeByte(byte);
                    state = State.Start;
                },
            },
            State.VarName => switch (byte) {
                '}' => {
                    const var_name = in_contents[var_name_start..index];
                    if (vars.get(var_name)) |value| {
                        const trimmed = mem.trim(u8, value, " \r\n");
                        if (fmt == .html and mem.endsWith(u8, var_name, "BYTESIZE")) {
                            try writer.print("{Bi:.1}", .{try std.fmt.parseInt(u64, trimmed, 10)});
                        } else {
                            try writer.writeAll(trimmed);
                        }
                    } else {
                        std.debug.warn("line {d}: missing variable: {s}\n", .{ line, var_name });
                        try writer.writeAll("(missing)");
                    }
                    state = State.EndBrace;
                },
                else => {},
            },
            State.EndBrace => switch (byte) {
                '}' => {
                    state = State.Start;
                },
                else => {
                    std.debug.warn("line {d}: invalid byte: '0x{x}'", .{ line, byte });
                    std.process.exit(1);
                },
            },
        }
        if (byte == '\n') {
            line += 1;
        }
    }
    try std.fs.cwd().writeFile(out_file, buffer.items);
}
