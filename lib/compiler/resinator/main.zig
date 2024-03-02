const std = @import("std");
const builtin = @import("builtin");
const removeComments = @import("comments.zig").removeComments;
const parseAndRemoveLineCommands = @import("source_mapping.zig").parseAndRemoveLineCommands;
const compile = @import("compile.zig").compile;
const Diagnostics = @import("errors.zig").Diagnostics;
const cli = @import("cli.zig");
const preprocess = @import("preprocess.zig");
const renderErrorMessage = @import("utils.zig").renderErrorMessage;
const aro = @import("aro");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const stderr = std.io.getStdErr();
    const stderr_config = std.io.tty.detectConfig(stderr);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try renderErrorMessage(stderr.writer(), stderr_config, .err, "expected zig lib dir as first argument", .{});
        std.os.exit(1);
    }
    const zig_lib_dir = args[1];

    var options = options: {
        var cli_diagnostics = cli.Diagnostics.init(allocator);
        defer cli_diagnostics.deinit();
        var options = cli.parse(allocator, args[2..], &cli_diagnostics) catch |err| switch (err) {
            error.ParseError => {
                cli_diagnostics.renderToStdErr(args, stderr_config);
                std.os.exit(1);
            },
            else => |e| return e,
        };
        try options.maybeAppendRC(std.fs.cwd());

        // print any warnings/notes
        cli_diagnostics.renderToStdErr(args, stderr_config);
        // If there was something printed, then add an extra newline separator
        // so that there is a clear separation between the cli diagnostics and whatever
        // gets printed after
        if (cli_diagnostics.errors.items.len > 0) {
            try stderr.writeAll("\n");
        }
        break :options options;
    };
    defer options.deinit();

    if (options.print_help_and_exit) {
        try cli.writeUsage(stderr.writer(), "zig rc");
        return;
    }

    const stdout_writer = std.io.getStdOut().writer();
    if (options.verbose) {
        try options.dumpVerbose(stdout_writer);
        try stdout_writer.writeByte('\n');
    }

    var dependencies_list = std.ArrayList([]const u8).init(allocator);
    defer {
        for (dependencies_list.items) |item| {
            allocator.free(item);
        }
        dependencies_list.deinit();
    }
    const maybe_dependencies_list: ?*std.ArrayList([]const u8) = if (options.depfile_path != null) &dependencies_list else null;

    const full_input = full_input: {
        if (options.preprocess != .no) {
            var preprocessed_buf = std.ArrayList(u8).init(allocator);
            errdefer preprocessed_buf.deinit();

            // We're going to throw away everything except the final preprocessed output anyway,
            // so we can use a scoped arena for everything else.
            var aro_arena_state = std.heap.ArenaAllocator.init(allocator);
            defer aro_arena_state.deinit();
            const aro_arena = aro_arena_state.allocator();

            const include_paths = getIncludePaths(aro_arena, options.auto_includes, zig_lib_dir) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => |e| {
                    switch (e) {
                        error.MsvcIncludesNotFound => {
                            try renderErrorMessage(stderr.writer(), stderr_config, .err, "MSVC include paths could not be automatically detected", .{});
                        },
                        error.MingwIncludesNotFound => {
                            try renderErrorMessage(stderr.writer(), stderr_config, .err, "MinGW include paths could not be automatically detected", .{});
                        },
                    }
                    try renderErrorMessage(stderr.writer(), stderr_config, .note, "to disable auto includes, use the option /:auto-includes none", .{});
                    std.os.exit(1);
                },
            };

            var comp = aro.Compilation.init(aro_arena);
            defer comp.deinit();

            var argv = std.ArrayList([]const u8).init(comp.gpa);
            defer argv.deinit();

            try argv.append("arocc"); // dummy command name
            try preprocess.appendAroArgs(aro_arena, &argv, options, include_paths);
            try argv.append(options.input_filename);

            if (options.verbose) {
                try stdout_writer.writeAll("Preprocessor: arocc (built-in)\n");
                for (argv.items[0 .. argv.items.len - 1]) |arg| {
                    try stdout_writer.print("{s} ", .{arg});
                }
                try stdout_writer.print("{s}\n\n", .{argv.items[argv.items.len - 1]});
            }

            preprocess.preprocess(&comp, preprocessed_buf.writer(), argv.items, maybe_dependencies_list) catch |err| switch (err) {
                error.GeneratedSourceError => {
                    // extra newline to separate this line from the aro errors
                    try renderErrorMessage(stderr.writer(), stderr_config, .err, "failed during preprocessor setup (this is always a bug):\n", .{});
                    aro.Diagnostics.render(&comp, stderr_config);
                    std.os.exit(1);
                },
                // ArgError can occur if e.g. the .rc file is not found
                error.ArgError, error.PreprocessError => {
                    // extra newline to separate this line from the aro errors
                    try renderErrorMessage(stderr.writer(), stderr_config, .err, "failed during preprocessing:\n", .{});
                    aro.Diagnostics.render(&comp, stderr_config);
                    std.os.exit(1);
                },
                error.StreamTooLong => {
                    try renderErrorMessage(stderr.writer(), stderr_config, .err, "failed during preprocessing: maximum file size exceeded", .{});
                    std.os.exit(1);
                },
                error.OutOfMemory => |e| return e,
            };

            break :full_input try preprocessed_buf.toOwnedSlice();
        } else {
            break :full_input std.fs.cwd().readFileAlloc(allocator, options.input_filename, std.math.maxInt(usize)) catch |err| {
                try renderErrorMessage(stderr.writer(), stderr_config, .err, "unable to read input file path '{s}': {s}", .{ options.input_filename, @errorName(err) });
                std.os.exit(1);
            };
        }
    };
    defer allocator.free(full_input);

    if (options.preprocess == .only) {
        try std.fs.cwd().writeFile(options.output_filename, full_input);
        return;
    }

    // Note: We still want to run this when no-preprocess is set because:
    //   1. We want to print accurate line numbers after removing multiline comments
    //   2. We want to be able to handle an already-preprocessed input with #line commands in it
    var mapping_results = try parseAndRemoveLineCommands(allocator, full_input, full_input, .{ .initial_filename = options.input_filename });
    defer mapping_results.mappings.deinit(allocator);

    const final_input = removeComments(mapping_results.result, mapping_results.result, &mapping_results.mappings) catch |err| switch (err) {
        error.InvalidSourceMappingCollapse => {
            try renderErrorMessage(stderr.writer(), stderr_config, .err, "failed during comment removal; this is a known bug", .{});
            std.os.exit(1);
        },
        else => |e| return e,
    };

    var output_file = std.fs.cwd().createFile(options.output_filename, .{}) catch |err| {
        try renderErrorMessage(stderr.writer(), stderr_config, .err, "unable to create output file '{s}': {s}", .{ options.output_filename, @errorName(err) });
        std.os.exit(1);
    };
    var output_file_closed = false;
    defer if (!output_file_closed) output_file.close();

    var diagnostics = Diagnostics.init(allocator);
    defer diagnostics.deinit();

    var output_buffered_stream = std.io.bufferedWriter(output_file.writer());

    compile(allocator, final_input, output_buffered_stream.writer(), .{
        .cwd = std.fs.cwd(),
        .diagnostics = &diagnostics,
        .source_mappings = &mapping_results.mappings,
        .dependencies_list = maybe_dependencies_list,
        .ignore_include_env_var = options.ignore_include_env_var,
        .extra_include_paths = options.extra_include_paths.items,
        .default_language_id = options.default_language_id,
        .default_code_page = options.default_code_page orelse .windows1252,
        .verbose = options.verbose,
        .null_terminate_string_table_strings = options.null_terminate_string_table_strings,
        .max_string_literal_codepoints = options.max_string_literal_codepoints,
        .silent_duplicate_control_ids = options.silent_duplicate_control_ids,
        .warn_instead_of_error_on_invalid_code_page = options.warn_instead_of_error_on_invalid_code_page,
    }) catch |err| switch (err) {
        error.ParseError, error.CompileError => {
            diagnostics.renderToStdErr(std.fs.cwd(), final_input, stderr_config, mapping_results.mappings);
            // Delete the output file on error
            output_file.close();
            output_file_closed = true;
            // Failing to delete is not really a big deal, so swallow any errors
            std.fs.cwd().deleteFile(options.output_filename) catch {};
            std.os.exit(1);
        },
        else => |e| return e,
    };

    try output_buffered_stream.flush();

    // print any warnings/notes
    diagnostics.renderToStdErr(std.fs.cwd(), final_input, stderr_config, mapping_results.mappings);

    // write the depfile
    if (options.depfile_path) |depfile_path| {
        var depfile = std.fs.cwd().createFile(depfile_path, .{}) catch |err| {
            try renderErrorMessage(stderr.writer(), stderr_config, .err, "unable to create depfile '{s}': {s}", .{ depfile_path, @errorName(err) });
            std.os.exit(1);
        };
        defer depfile.close();

        const depfile_writer = depfile.writer();
        var depfile_buffered_writer = std.io.bufferedWriter(depfile_writer);
        switch (options.depfile_fmt) {
            .json => {
                var write_stream = std.json.writeStream(depfile_buffered_writer.writer(), .{ .whitespace = .indent_2 });
                defer write_stream.deinit();

                try write_stream.beginArray();
                for (dependencies_list.items) |dep_path| {
                    try write_stream.write(dep_path);
                }
                try write_stream.endArray();
            },
        }
        try depfile_buffered_writer.flush();
    }
}

fn getIncludePaths(arena: std.mem.Allocator, auto_includes_option: cli.Options.AutoIncludes, zig_lib_dir: []const u8) ![]const []const u8 {
    var includes = auto_includes_option;
    if (builtin.target.os.tag != .windows) {
        switch (includes) {
            // MSVC can't be found when the host isn't Windows, so short-circuit.
            .msvc => return error.MsvcIncludesNotFound,
            // Skip straight to gnu since we won't be able to detect MSVC on non-Windows hosts.
            .any => includes = .gnu,
            .none, .gnu => {},
        }
    }

    while (true) {
        switch (includes) {
            .none => return &[_][]const u8{},
            .any, .msvc => {
                // MSVC is only detectable on Windows targets. This unreachable is to signify
                // that .any and .msvc should be dealt with on non-Windows targets before this point,
                // since getting MSVC include paths uses Windows-only APIs.
                if (builtin.target.os.tag != .windows) unreachable;

                const target_query: std.Target.Query = .{
                    .os_tag = .windows,
                    .abi = .msvc,
                };
                const target = std.zig.resolveTargetQueryOrFatal(target_query);
                const is_native_abi = target_query.isNativeAbi();
                const detected_libc = std.zig.LibCDirs.detect(arena, zig_lib_dir, target, is_native_abi, true, null) catch {
                    if (includes == .any) {
                        // fall back to mingw
                        includes = .gnu;
                        continue;
                    }
                    return error.MsvcIncludesNotFound;
                };
                if (detected_libc.libc_include_dir_list.len == 0) {
                    if (includes == .any) {
                        // fall back to mingw
                        includes = .gnu;
                        continue;
                    }
                    return error.MsvcIncludesNotFound;
                }
                return detected_libc.libc_include_dir_list;
            },
            .gnu => {
                const target_query: std.Target.Query = .{
                    .os_tag = .windows,
                    .abi = .gnu,
                };
                const target = std.zig.resolveTargetQueryOrFatal(target_query);
                const is_native_abi = target_query.isNativeAbi();
                const detected_libc = std.zig.LibCDirs.detect(arena, zig_lib_dir, target, is_native_abi, true, null) catch |err| switch (err) {
                    error.OutOfMemory => |e| return e,
                    else => return error.MingwIncludesNotFound,
                };
                return detected_libc.libc_include_dir_list;
            },
        }
    }
}
