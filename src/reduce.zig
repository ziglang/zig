const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = @import("./main.zig").fatal;
const Ast = std.zig.Ast;
const Walk = @import("reduce/Walk.zig");

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
    \\  --seed [integer]          Override the random seed. Defaults to 0
    \\  --skip-smoke-test         Skip interestingness check smoke test
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
// - add support for parsing the module flags
// - more fancy transformations
//   - @import inlining of modules
//   - @import inlining of files
//   - deleting unused functions and other globals
//   - removing statements or blocks of code
//   - replacing operands of `and` and `or` with `true` and `false`
//   - replacing if conditions with `true` and `false`
// - reduce flags sent to the compiler
// - integrate with the build system?

pub fn main(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    var opt_checker_path: ?[]const u8 = null;
    var opt_root_source_file_path: ?[]const u8 = null;
    var argv: []const []const u8 = &.{};
    var seed: u32 = 0;
    var skip_smoke_test = false;

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
                } else if (mem.eql(u8, arg, "--skip-smoke-test")) {
                    skip_smoke_test = true;
                } else if (mem.eql(u8, arg, "--main-mod-path")) {
                    @panic("TODO: implement --main-mod-path");
                } else if (mem.eql(u8, arg, "--mod")) {
                    @panic("TODO: implement --mod");
                } else if (mem.eql(u8, arg, "--deps")) {
                    @panic("TODO: implement --deps");
                } else if (mem.eql(u8, arg, "--seed")) {
                    i += 1;
                    if (i >= args.len) fatal("expected 32-bit integer after {s}", .{arg});
                    const next_arg = args[i];
                    seed = std.fmt.parseUnsigned(u32, next_arg, 0) catch |err| {
                        fatal("unable to parse seed '{s}' as 32-bit integer: {s}", .{
                            next_arg, @errorName(err),
                        });
                    };
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

    var tree = try parse(gpa, arena, root_source_file_path);
    defer tree.deinit(gpa);

    if (!skip_smoke_test) {
        std.debug.print("smoke testing the interestingness check...\n", .{});
        switch (try runCheck(arena, interestingness_argv.items)) {
            .interesting => {},
            .boring, .unknown => |t| {
                fatal("interestingness check returned {s} for unmodified input\n", .{
                    @tagName(t),
                });
            },
        }
    }

    var fixups: Ast.Fixups = .{};
    defer fixups.deinit(gpa);
    var rng = std.rand.DefaultPrng.init(seed);

    // 1. Walk the AST of the source file looking for independent
    //    reductions and collecting them all into an array list.
    // 2. Randomize the list of transformations. A future enhancement will add
    //    priority weights to the sorting but for now they are completely
    //    shuffled.
    // 3. Apply a subset consisting of 1/2 of the transformations and check for
    //    interestingness.
    // 4. If not interesting, half the subset size again and check again.
    // 5. Repeat until the subset size is 1, then march the transformation
    //    index forward by 1 with each non-interesting attempt.
    //
    // At any point if a subset of transformations succeeds in producing an interesting
    // result, restart the whole process, reparsing the AST and re-generating the list
    // of all possible transformations and shuffling it again.

    var transformations = std.ArrayList(Walk.Transformation).init(gpa);
    defer transformations.deinit();
    try Walk.findTransformations(&tree, &transformations);
    sortTransformations(transformations.items, rng.random());

    fresh: while (transformations.items.len > 0) {
        std.debug.print("found {d} possible transformations\n", .{
            transformations.items.len,
        });
        var subset_size: usize = transformations.items.len;
        var start_index: usize = 0;

        while (start_index < transformations.items.len) {
            subset_size = @max(1, subset_size / 2);

            const this_set = transformations.items[start_index..][0..subset_size];
            try transformationsToFixups(gpa, this_set, &fixups);

            rendered.clearRetainingCapacity();
            try tree.renderToArrayList(&rendered, fixups);
            try std.fs.cwd().writeFile(root_source_file_path, rendered.items);

            const interestingness = try runCheck(arena, interestingness_argv.items);
            std.debug.print("{d} random transformations: {s}. {d} remaining\n", .{
                subset_size, @tagName(interestingness), transformations.items.len - start_index,
            });
            switch (interestingness) {
                .interesting => {
                    const new_tree = try parse(gpa, arena, root_source_file_path);
                    tree.deinit(gpa);
                    tree = new_tree;

                    try Walk.findTransformations(&tree, &transformations);
                    // Resetting based on the seed again means we will get the same
                    // results if restarting the reduction process from this new point.
                    rng = std.rand.DefaultPrng.init(seed);
                    sortTransformations(transformations.items, rng.random());

                    continue :fresh;
                },
                .unknown, .boring => {
                    // Continue to try the next set of transformations.
                    // If we tested only one transformation, move on to the next one.
                    if (subset_size == 1) {
                        start_index += 1;
                    }
                },
            }
        }
        std.debug.print("all {d} remaining transformations are uninteresting\n", .{
            transformations.items.len,
        });

        // Revert the source back to not be transformed.
        fixups.clearRetainingCapacity();
        rendered.clearRetainingCapacity();
        try tree.renderToArrayList(&rendered, fixups);
        try std.fs.cwd().writeFile(root_source_file_path, rendered.items);

        return std.process.cleanExit();
    }
    std.debug.print("no more transformations found\n", .{});
    return std.process.cleanExit();
}

fn sortTransformations(transformations: []Walk.Transformation, rng: std.rand.Random) void {
    rng.shuffle(Walk.Transformation, transformations);
    // Stable sort based on priority to keep randomness as the secondary sort.
    // TODO: introduce transformation priorities
    // std.mem.sort(transformations);
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

fn transformationsToFixups(
    gpa: Allocator,
    transforms: []const Walk.Transformation,
    fixups: *Ast.Fixups,
) !void {
    fixups.clearRetainingCapacity();

    for (transforms) |t| switch (t) {
        .gut_function => |fn_decl_node| {
            try fixups.gut_functions.put(gpa, fn_decl_node, {});
        },
        .delete_node => |decl_node| {
            try fixups.omit_nodes.put(gpa, decl_node, {});
        },
        .replace_with_undef => |node| {
            try fixups.replace_nodes.put(gpa, node, {});
        },
    };
}

fn parse(gpa: Allocator, arena: Allocator, root_source_file_path: []const u8) !Ast {
    const source_code = try std.fs.cwd().readFileAllocOptions(
        arena,
        root_source_file_path,
        std.math.maxInt(u32),
        null,
        1,
        0,
    );

    var tree = try Ast.parse(gpa, source_code, .zig);
    errdefer tree.deinit(gpa);

    if (tree.errors.len != 0) {
        @panic("syntax errors occurred");
    }

    return tree;
}
