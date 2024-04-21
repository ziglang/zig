const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Ast = std.zig.Ast;
const Walk = @import("reduce/Walk.zig");
const AstGen = std.zig.AstGen;
const Zir = std.zig.Zir;

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
//   - removing statements or blocks of code
//   - replacing operands of `and` and `or` with `true` and `false`
//   - replacing if conditions with `true` and `false`
// - reduce flags sent to the compiler
// - integrate with the build system?

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);

    var opt_checker_path: ?[]const u8 = null;
    var opt_root_source_file_path: ?[]const u8 = null;
    var argv: []const []const u8 = &.{};
    var seed: u32 = 0;
    var skip_smoke_test = false;

    {
        var i: usize = 1;
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

    var astgen_input = std.ArrayList(u8).init(gpa);
    defer astgen_input.deinit();

    var tree = try parse(gpa, root_source_file_path);
    defer {
        gpa.free(tree.source);
        tree.deinit(gpa);
    }

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

    var more_fixups: Ast.Fixups = .{};
    defer more_fixups.deinit(gpa);

    var rng = std.Random.DefaultPrng.init(seed);

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
    try Walk.findTransformations(arena, &tree, &transformations);
    sortTransformations(transformations.items, rng.random());

    fresh: while (transformations.items.len > 0) {
        std.debug.print("found {d} possible transformations\n", .{
            transformations.items.len,
        });
        var subset_size: usize = transformations.items.len;
        var start_index: usize = 0;

        while (start_index < transformations.items.len) {
            const prev_subset_size = subset_size;
            subset_size = @max(1, subset_size * 3 / 4);
            if (prev_subset_size > 1 and subset_size == 1)
                start_index = 0;

            const this_set = transformations.items[start_index..][0..subset_size];
            std.debug.print("trying {d} random transformations: ", .{subset_size});
            for (this_set[0..@min(this_set.len, 20)]) |t| {
                std.debug.print("{s} ", .{@tagName(t)});
            }
            std.debug.print("\n", .{});
            try transformationsToFixups(gpa, arena, root_source_file_path, this_set, &fixups);

            rendered.clearRetainingCapacity();
            try tree.renderToArrayList(&rendered, fixups);

            // The transformations we applied may have resulted in unused locals,
            // in which case we would like to add the respective discards.
            {
                try astgen_input.resize(rendered.items.len);
                @memcpy(astgen_input.items, rendered.items);
                try astgen_input.append(0);
                const source_with_null = astgen_input.items[0 .. astgen_input.items.len - 1 :0];
                var astgen_tree = try Ast.parse(gpa, source_with_null, .zig);
                defer astgen_tree.deinit(gpa);
                if (astgen_tree.errors.len != 0) {
                    @panic("syntax errors occurred");
                }
                var zir = try AstGen.generate(gpa, astgen_tree);
                defer zir.deinit(gpa);

                if (zir.hasCompileErrors()) {
                    more_fixups.clearRetainingCapacity();
                    const payload_index = zir.extra[@intFromEnum(Zir.ExtraIndex.compile_errors)];
                    assert(payload_index != 0);
                    const header = zir.extraData(Zir.Inst.CompileErrors, payload_index);
                    var extra_index = header.end;
                    for (0..header.data.items_len) |_| {
                        const item = zir.extraData(Zir.Inst.CompileErrors.Item, extra_index);
                        extra_index = item.end;
                        const msg = zir.nullTerminatedString(item.data.msg);
                        if (mem.eql(u8, msg, "unused local constant") or
                            mem.eql(u8, msg, "unused local variable") or
                            mem.eql(u8, msg, "unused function parameter") or
                            mem.eql(u8, msg, "unused capture"))
                        {
                            const ident_token = item.data.token;
                            try more_fixups.unused_var_decls.put(gpa, ident_token, {});
                        } else {
                            std.debug.print("found other ZIR error: '{s}'\n", .{msg});
                        }
                    }
                    if (more_fixups.count() != 0) {
                        rendered.clearRetainingCapacity();
                        try astgen_tree.renderToArrayList(&rendered, more_fixups);
                    }
                }
            }

            try std.fs.cwd().writeFile(root_source_file_path, rendered.items);
            // std.debug.print("trying this code:\n{s}\n", .{rendered.items});

            const interestingness = try runCheck(arena, interestingness_argv.items);
            std.debug.print("{d} random transformations: {s}. {d}/{d}\n", .{
                subset_size, @tagName(interestingness), start_index, transformations.items.len,
            });
            switch (interestingness) {
                .interesting => {
                    const new_tree = try parse(gpa, root_source_file_path);
                    gpa.free(tree.source);
                    tree.deinit(gpa);
                    tree = new_tree;

                    try Walk.findTransformations(arena, &tree, &transformations);
                    sortTransformations(transformations.items, rng.random());

                    continue :fresh;
                },
                .unknown, .boring => {
                    // Continue to try the next set of transformations.
                    // If we tested only one transformation, move on to the next one.
                    if (subset_size == 1) {
                        start_index += 1;
                    } else {
                        start_index += subset_size;
                        if (start_index + subset_size > transformations.items.len) {
                            start_index = 0;
                        }
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

fn sortTransformations(transformations: []Walk.Transformation, rng: std.Random) void {
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
    arena: Allocator,
    root_source_file_path: []const u8,
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
        .delete_var_decl => |delete_var_decl| {
            try fixups.omit_nodes.put(gpa, delete_var_decl.var_decl_node, {});
            for (delete_var_decl.references.items) |ident_node| {
                try fixups.replace_nodes_with_string.put(gpa, ident_node, "undefined");
            }
        },
        .replace_with_undef => |node| {
            try fixups.replace_nodes_with_string.put(gpa, node, "undefined");
        },
        .replace_with_true => |node| {
            try fixups.replace_nodes_with_string.put(gpa, node, "true");
        },
        .replace_with_false => |node| {
            try fixups.replace_nodes_with_string.put(gpa, node, "false");
        },
        .replace_node => |r| {
            try fixups.replace_nodes_with_node.put(gpa, r.to_replace, r.replacement);
        },
        .inline_imported_file => |inline_imported_file| {
            const full_imported_path = try std.fs.path.join(gpa, &.{
                std.fs.path.dirname(root_source_file_path) orelse ".",
                inline_imported_file.imported_string,
            });
            defer gpa.free(full_imported_path);
            var other_file_ast = try parse(gpa, full_imported_path);
            defer {
                gpa.free(other_file_ast.source);
                other_file_ast.deinit(gpa);
            }

            var inlined_fixups: Ast.Fixups = .{};
            defer inlined_fixups.deinit(gpa);
            if (std.fs.path.dirname(inline_imported_file.imported_string)) |dirname| {
                inlined_fixups.rebase_imported_paths = dirname;
            }
            for (inline_imported_file.in_scope_names.keys()) |name| {
                // This name needs to be mangled in order to not cause an
                // ambiguous reference error.
                var i: u32 = 2;
                const mangled = while (true) : (i += 1) {
                    const mangled = try std.fmt.allocPrint(gpa, "{s}{d}", .{ name, i });
                    if (!inline_imported_file.in_scope_names.contains(mangled))
                        break mangled;
                    gpa.free(mangled);
                };
                try inlined_fixups.rename_identifiers.put(gpa, name, mangled);
            }
            defer {
                for (inlined_fixups.rename_identifiers.values()) |v| {
                    gpa.free(v);
                }
            }

            var other_source = std.ArrayList(u8).init(gpa);
            defer other_source.deinit();
            try other_source.appendSlice("struct {\n");
            try other_file_ast.renderToArrayList(&other_source, inlined_fixups);
            try other_source.appendSlice("}");

            try fixups.replace_nodes_with_string.put(
                gpa,
                inline_imported_file.builtin_call_node,
                try arena.dupe(u8, other_source.items),
            );
        },
    };
}

fn parse(gpa: Allocator, file_path: []const u8) !Ast {
    const source_code = std.fs.cwd().readFileAllocOptions(
        gpa,
        file_path,
        std.math.maxInt(u32),
        null,
        1,
        0,
    ) catch |err| {
        fatal("unable to open '{s}': {s}", .{ file_path, @errorName(err) });
    };
    errdefer gpa.free(source_code);

    var tree = try Ast.parse(gpa, source_code, .zig);
    errdefer tree.deinit(gpa);

    if (tree.errors.len != 0) {
        @panic("syntax errors occurred");
    }

    return tree;
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}
