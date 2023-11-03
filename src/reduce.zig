const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const usage =
    \\zig reduce [source_file] [interestingness]
    \\
;

const Interestingness = enum { interesting, boring, unknown };

// Roadmap:
// - add thread pool
// - add support for `@import` detection and other files
// - more fancy transformations
// - reduce flags sent to the compiler
//   - @import inlining
//   - deleting unused functions and other globals
//   - removing statements or blocks of code
//   - replacing operands of `and` and `or` with `true` and `false`
//   - replacing if conditions with `true` and `false`
// - integrate the build system?

pub fn main(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    const file_path = args[2];
    const interestingness_argv_template = args[3..];

    var interestingness_argv: std.ArrayListUnmanaged([]const u8) = .{};
    try interestingness_argv.ensureUnusedCapacity(arena, interestingness_argv_template.len + 1);
    interestingness_argv.appendSliceAssumeCapacity(interestingness_argv_template);
    interestingness_argv.appendAssumeCapacity(file_path);

    var rendered = std.ArrayList(u8).init(gpa);
    defer rendered.deinit();

    var prev_rendered = std.ArrayList(u8).init(gpa);
    defer prev_rendered.deinit();

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

    var next_gut_fn_index: u32 = 0;
    var fixups: std.zig.Ast.Fixups = .{};

    while (true) {
        try fixups.gut_functions.put(arena, next_gut_fn_index, {});

        rendered.clearRetainingCapacity();
        try tree.renderToArrayList(&rendered, fixups);

        if (std.mem.eql(u8, rendered.items, prev_rendered.items)) {
            std.debug.print("no remaining transformations\n", .{});
            break;
        }
        prev_rendered.clearRetainingCapacity();
        try prev_rendered.appendSlice(rendered.items);

        try std.fs.cwd().writeFile(file_path, rendered.items);

        const result = try std.process.Child.run(.{
            .allocator = arena,
            .argv = interestingness_argv.items,
        });
        if (result.stderr.len != 0)
            std.debug.print("{s}", .{result.stderr});
        const interestingness: Interestingness = switch (result.term) {
            .Exited => |code| switch (code) {
                0 => .interesting,
                1 => .unknown,
                else => .boring,
            },
            else => b: {
                std.debug.print("interestingness check aborted unexpectedly\n", .{});
                break :b .boring;
            },
        };
        std.debug.print("{s}\n", .{@tagName(interestingness)});
        switch (interestingness) {
            .interesting => {
                next_gut_fn_index += 1;
            },
            .unknown, .boring => {
                // revert the change and try the next transformation
                assert(fixups.gut_functions.remove(next_gut_fn_index));
                next_gut_fn_index += 1;

                rendered.clearRetainingCapacity();
                try tree.renderToArrayList(&rendered, fixups);
            },
        }
    }
    return std.process.cleanExit();
}
