const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const usage =
    \\zig reduce [source_file] [transformation]
    \\
;

// Roadmap:
// - add the main loop that checks for interestingness
// - add transformations
// - add thread pool
// - add support for `@import` detection and other files
// - reduce flags sent to the compiler

pub fn main(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    const file_path = args[2];
    const transformation_index = try std.fmt.parseInt(u32, args[3], 0);

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

    var gut_functions: std.AutoHashMapUnmanaged(u32, void) = .{};
    try gut_functions.put(arena, transformation_index, {});

    try tree.renderToArrayList(&rendered, .{
        .gut_functions = gut_functions,
    });

    const stdout = std.io.getStdOut();
    try stdout.writeAll(rendered.items);

    return std.process.cleanExit();
}
