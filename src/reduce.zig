const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const usage =
    \\zig reduce [source_file] [transformation]
    \\
;

const Transformation = enum {
    none,
};

pub fn main(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    const file_path = args[2];
    const transformation = std.meta.stringToEnum(Transformation, args[3]);

    assert(transformation == .none);

    const source_code = try std.fs.cwd().readFileAllocOptions(
        arena,
        file_path,
        std.math.maxInt(u32),
        null,
        1,
        0,
    );

    var tree = try std.zig.Ast.parse(gpa, source_code, .zig);
    defer tree.deinit(gpa);

    if (tree.errors.len != 0) {
        @panic("syntax errors occurred");
    }
    var rendered = std.ArrayList(u8).init(gpa);
    defer rendered.deinit();
    rendered.clearRetainingCapacity();
    try tree.renderToArrayList(&rendered);

    const stdout = std.io.getStdOut();
    try stdout.writeAll(rendered.items);

    return std.process.cleanExit();
}
