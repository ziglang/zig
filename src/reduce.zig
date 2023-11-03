const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = @import("./main.zig").fatal;

const usage =
    \\zig reduce [options] ./checker root_source_file.zig [-- [argv]]
    \\
    \\root_source_file.zig is relative to --main-mod-path.
    \\
    \\checker:
    \\  An executable that communicates interestingness by returning these exit codes:
    \\    exit(0):     interesting
    \\    exit(1):     unknown (infinite loop or other mishap)
    \\    exit(other): not interesting
    \\
    \\options:
    \\  --mod [name]:[deps]:[src] Make a module available for dependency under the given name
    \\      deps: [dep],[dep],...
    \\      dep:  [[import=]name]
    \\  --deps [dep],[dep],...    Set dependency names for the root package
    \\      dep:  [[import=]name]
    \\  --main-mod-path           Set the directory of the root module
    \\
    \\argv:
    \\  Forwarded directly to the interestingness script.
    \\
;

const Interestingness = enum { interesting, unknown, boring };

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
    var opt_checker_path: ?[]const u8 = null;
    var opt_root_source_file_path: ?[]const u8 = null;
    var argv: []const []const u8 = &.{};

    {
        var i: usize = 2; // skip over "zig" and "reduce"
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    const stdout = std.io.getStdOut().writer();
                    try stdout.writeAll(usage);
                    return std.process.cleanExit();
                } else if (mem.eql(u8, arg, "--")) {
                    argv = args[i + 1 ..];
                    break;
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else if (opt_checker_path == null) {
                opt_checker_path = arg;
            } else if (opt_root_source_file_path == null) {
                opt_root_source_file_path = arg;
            } else {
                fatal("unexpected extra parameter: '{s}'", .{arg});
            }
        }
    }

    const checker_path = opt_checker_path orelse
        fatal("missing interestingness checker argument; see -h for usage", .{});
    const root_source_file_path = opt_root_source_file_path orelse
        fatal("missing root source file path argument; see -h for usage", .{});

    var interestingness_argv: std.ArrayListUnmanaged([]const u8) = .{};
    try interestingness_argv.ensureUnusedCapacity(arena, argv.len + 1);
    interestingness_argv.appendAssumeCapacity(checker_path);
    interestingness_argv.appendSliceAssumeCapacity(argv);

    var rendered = std.ArrayList(u8).init(gpa);
    defer rendered.deinit();

    var prev_rendered = std.ArrayList(u8).init(gpa);
    defer prev_rendered.deinit();

    const source_code = try std.fs.cwd().readFileAllocOptions(
        arena,
        root_source_file_path,
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

    {
        // smoke test the interestingness check
        switch (try runCheck(arena, interestingness_argv.items)) {
            .interesting => {},
            .boring, .unknown => |t| {
                fatal("interestingness check returned {s} for unmodified input\n", .{
                    @tagName(t),
                });
            },
        }
    }

    while (true) {
        try fixups.gut_functions.put(arena, next_gut_fn_index, {});

        rendered.clearRetainingCapacity();
        try tree.renderToArrayList(&rendered, fixups);

        if (mem.eql(u8, rendered.items, prev_rendered.items)) {
            std.debug.print("no remaining transformations\n", .{});
            break;
        }
        prev_rendered.clearRetainingCapacity();
        try prev_rendered.appendSlice(rendered.items);

        try std.fs.cwd().writeFile(root_source_file_path, rendered.items);

        const interestingness = try runCheck(arena, interestingness_argv.items);
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

fn termToInteresting(term: std.process.Child.Term) Interestingness {
    return switch (term) {
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
}

fn runCheck(arena: std.mem.Allocator, argv: []const []const u8) !Interestingness {
    const result = try std.process.Child.run(.{
        .allocator = arena,
        .argv = argv,
    });
    if (result.stderr.len != 0)
        std.debug.print("{s}", .{result.stderr});
    return termToInteresting(result.term);
}
