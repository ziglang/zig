const std = @import("std");
const builtin = @import("builtin");
const removeComments = @import("comments.zig").removeComments;
const parseAndRemoveLineCommands = @import("source_mapping.zig").parseAndRemoveLineCommands;
const compile = @import("compile.zig").compile;
const Diagnostics = @import("errors.zig").Diagnostics;
const cli = @import("cli.zig");
const preprocess = @import("preprocess.zig");
const renderErrorMessage = @import("utils.zig").renderErrorMessage;
const hasDisjointCodePage = @import("disjoint_code_page.zig").hasDisjointCodePage;
const aro = @import("aro");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const stderr = std.io.getStdErr();
    const stderr_config = std.io.tty.detectConfig(stderr);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try renderErrorMessage(stderr.writer(), stderr_config, .err, "expected zig lib dir as first argument", .{});
        std.process.exit(1);
    }
    const zig_lib_dir = args[1];
    var cli_args = args[2..];

    var zig_integration = false;
    if (cli_args.len > 0 and std.mem.eql(u8, cli_args[0], "--zig-integration")) {
        zig_integration = true;
        cli_args = args[3..];
    }

    var error_handler: ErrorHandler = switch (zig_integration) {
        true => .{
            .server = .{
                .out = std.io.getStdOut(),
                .in = undefined, // won't be receiving messages
                .receive_fifo = undefined, // won't be receiving messages
            },
        },
        false => .{
            .tty = stderr_config,
        },
    };

    var options = options: {
        var cli_diagnostics = cli.Diagnostics.init(allocator);
        defer cli_diagnostics.deinit();
        var options = cli.parse(allocator, cli_args, &cli_diagnostics) catch |err| switch (err) {
            error.ParseError => {
                try error_handler.emitCliDiagnostics(allocator, cli_args, &cli_diagnostics);
                std.process.exit(1);
            },
            else => |e| return e,
        };
        try options.maybeAppendRC(std.fs.cwd());

        if (!zig_integration) {
            // print any warnings/notes
            cli_diagnostics.renderToStdErr(cli_args, stderr_config);
            // If there was something printed, then add an extra newline separator
            // so that there is a clear separation between the cli diagnostics and whatever
            // gets printed after
            if (cli_diagnostics.errors.items.len > 0) {
                try stderr.writeAll("\n");
            }
        }
        break :options options;
    };
    defer options.deinit();

    if (options.print_help_and_exit) {
        try cli.writeUsage(stderr.writer(), "zig rc");
        return;
    }

    // Don't allow verbose when integrating with Zig via stdout
    options.verbose = false;

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

    const include_paths = getIncludePaths(arena, options.auto_includes, zig_lib_dir) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        else => |e| {
            switch (e) {
                error.MsvcIncludesNotFound => {
                    try error_handler.emitMessage(allocator, .err, "MSVC include paths could not be automatically detected", .{});
                },
                error.MingwIncludesNotFound => {
                    try error_handler.emitMessage(allocator, .err, "MinGW include paths could not be automatically detected", .{});
                },
            }
            try error_handler.emitMessage(allocator, .note, "to disable auto includes, use the option /:auto-includes none", .{});
            std.process.exit(1);
        },
    };

    const full_input = full_input: {
        if (options.preprocess != .no) {
            var preprocessed_buf = std.ArrayList(u8).init(allocator);
            errdefer preprocessed_buf.deinit();

            // We're going to throw away everything except the final preprocessed output anyway,
            // so we can use a scoped arena for everything else.
            var aro_arena_state = std.heap.ArenaAllocator.init(allocator);
            defer aro_arena_state.deinit();
            const aro_arena = aro_arena_state.allocator();

            var comp = aro.Compilation.init(aro_arena, std.fs.cwd());
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
                    try error_handler.emitAroDiagnostics(allocator, "failed during preprocessor setup (this is always a bug):", &comp);
                    std.process.exit(1);
                },
                // ArgError can occur if e.g. the .rc file is not found
                error.ArgError, error.PreprocessError => {
                    try error_handler.emitAroDiagnostics(allocator, "failed during preprocessing:", &comp);
                    std.process.exit(1);
                },
                error.StreamTooLong => {
                    try error_handler.emitMessage(allocator, .err, "failed during preprocessing: maximum file size exceeded", .{});
                    std.process.exit(1);
                },
                error.OutOfMemory => |e| return e,
            };

            break :full_input try preprocessed_buf.toOwnedSlice();
        } else {
            break :full_input std.fs.cwd().readFileAlloc(allocator, options.input_filename, std.math.maxInt(usize)) catch |err| {
                try error_handler.emitMessage(allocator, .err, "unable to read input file path '{s}': {s}", .{ options.input_filename, @errorName(err) });
                std.process.exit(1);
            };
        }
    };
    defer allocator.free(full_input);

    if (options.preprocess == .only) {
        try std.fs.cwd().writeFile(.{ .sub_path = options.output_filename, .data = full_input });
        return;
    }

    // Note: We still want to run this when no-preprocess is set because:
    //   1. We want to print accurate line numbers after removing multiline comments
    //   2. We want to be able to handle an already-preprocessed input with #line commands in it
    var mapping_results = parseAndRemoveLineCommands(allocator, full_input, full_input, .{ .initial_filename = options.input_filename }) catch |err| switch (err) {
        error.InvalidLineCommand => {
            // TODO: Maybe output the invalid line command
            try error_handler.emitMessage(allocator, .err, "invalid line command in the preprocessed source", .{});
            if (options.preprocess == .no) {
                try error_handler.emitMessage(allocator, .note, "line commands must be of the format: #line <num> \"<path>\"", .{});
            } else {
                try error_handler.emitMessage(allocator, .note, "this is likely to be a bug, please report it", .{});
            }
            std.process.exit(1);
        },
        error.LineNumberOverflow => {
            // TODO: Better error message
            try error_handler.emitMessage(allocator, .err, "line number count exceeded maximum of {}", .{std.math.maxInt(usize)});
            std.process.exit(1);
        },
        error.OutOfMemory => |e| return e,
    };
    defer mapping_results.mappings.deinit(allocator);

    const default_code_page = options.default_code_page orelse .windows1252;
    const has_disjoint_code_page = hasDisjointCodePage(mapping_results.result, &mapping_results.mappings, default_code_page);

    const final_input = try removeComments(mapping_results.result, mapping_results.result, &mapping_results.mappings);

    var output_file = std.fs.cwd().createFile(options.output_filename, .{}) catch |err| {
        try error_handler.emitMessage(allocator, .err, "unable to create output file '{s}': {s}", .{ options.output_filename, @errorName(err) });
        std.process.exit(1);
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
        .system_include_paths = include_paths,
        .default_language_id = options.default_language_id,
        .default_code_page = default_code_page,
        .disjoint_code_page = has_disjoint_code_page,
        .verbose = options.verbose,
        .null_terminate_string_table_strings = options.null_terminate_string_table_strings,
        .max_string_literal_codepoints = options.max_string_literal_codepoints,
        .silent_duplicate_control_ids = options.silent_duplicate_control_ids,
        .warn_instead_of_error_on_invalid_code_page = options.warn_instead_of_error_on_invalid_code_page,
    }) catch |err| switch (err) {
        error.ParseError, error.CompileError => {
            try error_handler.emitDiagnostics(allocator, std.fs.cwd(), final_input, &diagnostics, mapping_results.mappings);
            // Delete the output file on error
            output_file.close();
            output_file_closed = true;
            // Failing to delete is not really a big deal, so swallow any errors
            std.fs.cwd().deleteFile(options.output_filename) catch {};
            std.process.exit(1);
        },
        else => |e| return e,
    };

    try output_buffered_stream.flush();

    // print any warnings/notes
    if (!zig_integration) {
        diagnostics.renderToStdErr(std.fs.cwd(), final_input, stderr_config, mapping_results.mappings);
    }

    // write the depfile
    if (options.depfile_path) |depfile_path| {
        var depfile = std.fs.cwd().createFile(depfile_path, .{}) catch |err| {
            try error_handler.emitMessage(allocator, .err, "unable to create depfile '{s}': {s}", .{ depfile_path, @errorName(err) });
            std.process.exit(1);
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

const ErrorBundle = std.zig.ErrorBundle;
const SourceMappings = @import("source_mapping.zig").SourceMappings;

const ErrorHandler = union(enum) {
    server: std.zig.Server,
    tty: std.io.tty.Config,

    pub fn emitCliDiagnostics(
        self: *ErrorHandler,
        allocator: std.mem.Allocator,
        args: []const []const u8,
        diagnostics: *cli.Diagnostics,
    ) !void {
        switch (self.*) {
            .server => |*server| {
                var error_bundle = try cliDiagnosticsToErrorBundle(allocator, diagnostics);
                defer error_bundle.deinit(allocator);

                try server.serveErrorBundle(error_bundle);
            },
            .tty => {
                diagnostics.renderToStdErr(args, self.tty);
            },
        }
    }

    pub fn emitAroDiagnostics(
        self: *ErrorHandler,
        allocator: std.mem.Allocator,
        fail_msg: []const u8,
        comp: *aro.Compilation,
    ) !void {
        switch (self.*) {
            .server => |*server| {
                var error_bundle = try aroDiagnosticsToErrorBundle(allocator, fail_msg, comp);
                defer error_bundle.deinit(allocator);

                try server.serveErrorBundle(error_bundle);
            },
            .tty => {
                // extra newline to separate this line from the aro errors
                try renderErrorMessage(std.io.getStdErr().writer(), self.tty, .err, "{s}\n", .{fail_msg});
                aro.Diagnostics.render(comp, self.tty);
            },
        }
    }

    pub fn emitDiagnostics(
        self: *ErrorHandler,
        allocator: std.mem.Allocator,
        cwd: std.fs.Dir,
        source: []const u8,
        diagnostics: *Diagnostics,
        mappings: SourceMappings,
    ) !void {
        switch (self.*) {
            .server => |*server| {
                var error_bundle = try diagnosticsToErrorBundle(allocator, source, diagnostics, mappings);
                defer error_bundle.deinit(allocator);

                try server.serveErrorBundle(error_bundle);
            },
            .tty => {
                diagnostics.renderToStdErr(cwd, source, self.tty, mappings);
            },
        }
    }

    pub fn emitMessage(
        self: *ErrorHandler,
        allocator: std.mem.Allocator,
        msg_type: @import("utils.zig").ErrorMessageType,
        comptime format: []const u8,
        args: anytype,
    ) !void {
        switch (self.*) {
            .server => |*server| {
                // only emit errors
                if (msg_type != .err) return;

                var error_bundle = try errorStringToErrorBundle(allocator, format, args);
                defer error_bundle.deinit(allocator);

                try server.serveErrorBundle(error_bundle);
            },
            .tty => {
                try renderErrorMessage(std.io.getStdErr().writer(), self.tty, msg_type, format, args);
            },
        }
    }
};

fn cliDiagnosticsToErrorBundle(
    gpa: std.mem.Allocator,
    diagnostics: *cli.Diagnostics,
) !ErrorBundle {
    @branchHint(.cold);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    errdefer bundle.deinit();

    try bundle.addRootErrorMessage(.{
        .msg = try bundle.addString("invalid command line option(s)"),
    });

    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayListUnmanaged(ErrorBundle.ErrorMessage) = .empty;
    defer cur_notes.deinit(gpa);
    for (diagnostics.errors.items) |err_details| {
        switch (err_details.type) {
            .err => {
                if (cur_err) |err| {
                    try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(err_details.msg.items),
                };
                cur_notes.clearRetainingCapacity();
            },
            .warning => cur_err = null,
            .note => {
                if (cur_err == null) continue;
                cur_err.?.notes_len += 1;
                try cur_notes.append(gpa, .{
                    .msg = try bundle.addString(err_details.msg.items),
                });
            },
        }
    }
    if (cur_err) |err| {
        try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
    }

    return try bundle.toOwnedBundle("");
}

fn diagnosticsToErrorBundle(
    gpa: std.mem.Allocator,
    source: []const u8,
    diagnostics: *Diagnostics,
    mappings: SourceMappings,
) !ErrorBundle {
    @branchHint(.cold);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    errdefer bundle.deinit();

    var msg_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer msg_buf.deinit(gpa);
    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayListUnmanaged(ErrorBundle.ErrorMessage) = .empty;
    defer cur_notes.deinit(gpa);
    for (diagnostics.errors.items) |err_details| {
        switch (err_details.type) {
            .hint => continue,
            // Clear the current error so that notes don't bleed into unassociated errors
            .warning => {
                cur_err = null;
                continue;
            },
            .note => if (cur_err == null) continue,
            .err => {},
        }
        const corresponding_span = mappings.getCorrespondingSpan(err_details.token.line_number).?;
        const err_line = corresponding_span.start_line;
        const err_filename = mappings.files.get(corresponding_span.filename_offset);

        const source_line_start = err_details.token.getLineStartForErrorDisplay(source);
        // Treat tab stops as 1 column wide for error display purposes,
        // and add one to get a 1-based column
        const column = err_details.token.calculateColumn(source, 1, source_line_start) + 1;

        msg_buf.clearRetainingCapacity();
        try err_details.render(msg_buf.writer(gpa), source, diagnostics.strings.items);

        const src_loc = src_loc: {
            var src_loc: ErrorBundle.SourceLocation = .{
                .src_path = try bundle.addString(err_filename),
                .line = @intCast(err_line - 1), // 1-based -> 0-based
                .column = @intCast(column - 1), // 1-based -> 0-based
                .span_start = 0,
                .span_main = 0,
                .span_end = 0,
            };
            if (err_details.print_source_line) {
                const source_line = err_details.token.getLineForErrorDisplay(source, source_line_start);
                const visual_info = err_details.visualTokenInfo(source_line_start, source_line_start + source_line.len, source);
                src_loc.span_start = @intCast(visual_info.point_offset - visual_info.before_len);
                src_loc.span_main = @intCast(visual_info.point_offset);
                src_loc.span_end = @intCast(visual_info.point_offset + 1 + visual_info.after_len);
                src_loc.source_line = try bundle.addString(source_line);
            }
            break :src_loc try bundle.addSourceLocation(src_loc);
        };

        switch (err_details.type) {
            .err => {
                if (cur_err) |err| {
                    try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(msg_buf.items),
                    .src_loc = src_loc,
                };
                cur_notes.clearRetainingCapacity();
            },
            .note => {
                cur_err.?.notes_len += 1;
                try cur_notes.append(gpa, .{
                    .msg = try bundle.addString(msg_buf.items),
                    .src_loc = src_loc,
                });
            },
            .warning, .hint => unreachable,
        }
    }
    if (cur_err) |err| {
        try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
    }

    return try bundle.toOwnedBundle("");
}

fn flushErrorMessageIntoBundle(wip: *ErrorBundle.Wip, msg: ErrorBundle.ErrorMessage, notes: []const ErrorBundle.ErrorMessage) !void {
    try wip.addRootErrorMessage(msg);
    const notes_start = try wip.reserveNotes(@intCast(notes.len));
    for (notes_start.., notes) |i, note| {
        wip.extra.items[i] = @intFromEnum(wip.addErrorMessageAssumeCapacity(note));
    }
}

fn errorStringToErrorBundle(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) !ErrorBundle {
    @branchHint(.cold);
    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(allocator);
    errdefer bundle.deinit();
    try bundle.addRootErrorMessage(.{
        .msg = try bundle.printString(format, args),
    });
    return try bundle.toOwnedBundle("");
}

fn aroDiagnosticsToErrorBundle(
    gpa: std.mem.Allocator,
    fail_msg: []const u8,
    comp: *aro.Compilation,
) !ErrorBundle {
    @branchHint(.cold);

    var bundle: ErrorBundle.Wip = undefined;
    try bundle.init(gpa);
    errdefer bundle.deinit();

    try bundle.addRootErrorMessage(.{
        .msg = try bundle.addString(fail_msg),
    });

    var msg_writer = MsgWriter.init(gpa);
    defer msg_writer.deinit();
    var cur_err: ?ErrorBundle.ErrorMessage = null;
    var cur_notes: std.ArrayListUnmanaged(ErrorBundle.ErrorMessage) = .empty;
    defer cur_notes.deinit(gpa);
    for (comp.diagnostics.list.items) |msg| {
        switch (msg.kind) {
            // Clear the current error so that notes don't bleed into unassociated errors
            .off, .warning => {
                cur_err = null;
                continue;
            },
            .note => if (cur_err == null) continue,
            .@"fatal error", .@"error" => {},
            .default => unreachable,
        }
        msg_writer.resetRetainingCapacity();
        aro.Diagnostics.renderMessage(comp, &msg_writer, msg);

        const src_loc = src_loc: {
            if (msg_writer.path) |src_path| {
                var src_loc: ErrorBundle.SourceLocation = .{
                    .src_path = try bundle.addString(src_path),
                    .line = msg_writer.line - 1, // 1-based -> 0-based
                    .column = msg_writer.col - 1, // 1-based -> 0-based
                    .span_start = 0,
                    .span_main = 0,
                    .span_end = 0,
                };
                if (msg_writer.source_line) |source_line| {
                    src_loc.span_start = msg_writer.span_main;
                    src_loc.span_main = msg_writer.span_main;
                    src_loc.span_end = msg_writer.span_main;
                    src_loc.source_line = try bundle.addString(source_line);
                }
                break :src_loc try bundle.addSourceLocation(src_loc);
            }
            break :src_loc ErrorBundle.SourceLocationIndex.none;
        };

        switch (msg.kind) {
            .@"fatal error", .@"error" => {
                if (cur_err) |err| {
                    try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
                }
                cur_err = .{
                    .msg = try bundle.addString(msg_writer.buf.items),
                    .src_loc = src_loc,
                };
                cur_notes.clearRetainingCapacity();
            },
            .note => {
                cur_err.?.notes_len += 1;
                try cur_notes.append(gpa, .{
                    .msg = try bundle.addString(msg_writer.buf.items),
                    .src_loc = src_loc,
                });
            },
            .off, .warning, .default => unreachable,
        }
    }
    if (cur_err) |err| {
        try flushErrorMessageIntoBundle(&bundle, err, cur_notes.items);
    }

    return try bundle.toOwnedBundle("");
}

// Similar to aro.Diagnostics.MsgWriter but:
// - Writers to an ArrayList
// - Only prints the message itself (no location, source line, error: prefix, etc)
// - Keeps track of source path/line/col instead
const MsgWriter = struct {
    buf: std.ArrayList(u8),
    path: ?[]const u8 = null,
    // 1-indexed
    line: u32 = undefined,
    col: u32 = undefined,
    source_line: ?[]const u8 = null,
    span_main: u32 = undefined,

    fn init(allocator: std.mem.Allocator) MsgWriter {
        return .{
            .buf = std.ArrayList(u8).init(allocator),
        };
    }

    fn deinit(m: *MsgWriter) void {
        m.buf.deinit();
    }

    fn resetRetainingCapacity(m: *MsgWriter) void {
        m.buf.clearRetainingCapacity();
        m.path = null;
        m.source_line = null;
    }

    pub fn print(m: *MsgWriter, comptime fmt: []const u8, args: anytype) void {
        m.buf.writer().print(fmt, args) catch {};
    }

    pub fn write(m: *MsgWriter, msg: []const u8) void {
        m.buf.writer().writeAll(msg) catch {};
    }

    pub fn setColor(m: *MsgWriter, color: std.io.tty.Color) void {
        _ = m;
        _ = color;
    }

    pub fn location(m: *MsgWriter, path: []const u8, line: u32, col: u32) void {
        m.path = path;
        m.line = line;
        m.col = col;
    }

    pub fn start(m: *MsgWriter, kind: aro.Diagnostics.Kind) void {
        _ = m;
        _ = kind;
    }

    pub fn end(m: *MsgWriter, maybe_line: ?[]const u8, col: u32, end_with_splice: bool) void {
        _ = end_with_splice;
        m.source_line = maybe_line;
        m.span_main = col;
    }
};
