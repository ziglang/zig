const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const cli = @import("cli.zig");
const aro = @import("aro");

const PreprocessError = error{ ArgError, GeneratedSourceError, PreprocessError, StreamTooLong, OutOfMemory };

pub fn preprocess(
    comp: *aro.Compilation,
    writer: anytype,
    /// Expects argv[0] to be the command name
    argv: []const []const u8,
    maybe_dependencies_list: ?*std.ArrayList([]const u8),
) PreprocessError!void {
    try comp.addDefaultPragmaHandlers();

    var driver: aro.Driver = .{ .comp = comp, .aro_name = "arocc" };
    defer driver.deinit();

    var macro_buf = std.ArrayList(u8).init(comp.gpa);
    defer macro_buf.deinit();

    _ = driver.parseArgs(std.io.null_writer, macro_buf.writer(), argv) catch |err| switch (err) {
        error.FatalError => return error.ArgError,
        error.OutOfMemory => |e| return e,
    };

    if (hasAnyErrors(comp)) return error.ArgError;

    // .include_system_defines gives us things like _WIN32
    const builtin_macros = comp.generateBuiltinMacros(.include_system_defines) catch |err| switch (err) {
        error.FatalError => return error.GeneratedSourceError,
        else => |e| return e,
    };
    const user_macros = comp.addSourceFromBuffer("<command line>", macro_buf.items) catch |err| switch (err) {
        error.FatalError => return error.GeneratedSourceError,
        else => |e| return e,
    };
    const source = driver.inputs.items[0];

    if (hasAnyErrors(comp)) return error.GeneratedSourceError;

    comp.generated_buf.items.len = 0;
    var pp = try aro.Preprocessor.initDefault(comp);
    defer pp.deinit();

    if (comp.langopts.ms_extensions) {
        comp.ms_cwd_source_id = source.id;
    }

    pp.preserve_whitespace = true;
    pp.linemarkers = .line_directives;

    pp.preprocessSources(&.{ source, builtin_macros, user_macros }) catch |err| switch (err) {
        error.FatalError => return error.PreprocessError,
        else => |e| return e,
    };

    if (hasAnyErrors(comp)) return error.PreprocessError;

    try pp.prettyPrintTokens(writer);

    if (maybe_dependencies_list) |dependencies_list| {
        for (comp.sources.values()) |comp_source| {
            if (comp_source.id == builtin_macros.id or comp_source.id == user_macros.id) continue;
            if (comp_source.id == .unused or comp_source.id == .generated) continue;
            const duped_path = try dependencies_list.allocator.dupe(u8, comp_source.path);
            errdefer dependencies_list.allocator.free(duped_path);
            try dependencies_list.append(duped_path);
        }
    }
}

fn hasAnyErrors(comp: *aro.Compilation) bool {
    // In theory we could just check Diagnostics.errors != 0, but that only
    // gets set during rendering of the error messages, see:
    // https://github.com/Vexu/arocc/issues/603
    for (comp.diagnostics.list.items) |msg| {
        switch (msg.kind) {
            .@"fatal error", .@"error" => return true,
            else => {},
        }
    }
    return false;
}

/// `arena` is used for temporary -D argument strings and the INCLUDE environment variable.
/// The arena should be kept alive at least as long as `argv`.
pub fn appendAroArgs(arena: Allocator, argv: *std.ArrayList([]const u8), options: cli.Options, system_include_paths: []const []const u8) !void {
    try argv.appendSlice(&.{
        "-E",
        "--comments",
        "-fuse-line-directives",
        "--target=x86_64-windows-msvc",
        "--emulate=msvc",
        "-nostdinc",
        "-DRC_INVOKED",
    });
    for (options.extra_include_paths.items) |extra_include_path| {
        try argv.append("-I");
        try argv.append(extra_include_path);
    }

    for (system_include_paths) |include_path| {
        try argv.append("-isystem");
        try argv.append(include_path);
    }

    if (!options.ignore_include_env_var) {
        const INCLUDE = std.process.getEnvVarOwned(arena, "INCLUDE") catch "";

        // The only precedence here is llvm-rc which also uses the platform-specific
        // delimiter. There's no precedence set by `rc.exe` since it's Windows-only.
        const delimiter = switch (builtin.os.tag) {
            .windows => ';',
            else => ':',
        };
        var it = std.mem.tokenizeScalar(u8, INCLUDE, delimiter);
        while (it.next()) |include_path| {
            try argv.append("-isystem");
            try argv.append(include_path);
        }
    }

    var symbol_it = options.symbols.iterator();
    while (symbol_it.next()) |entry| {
        switch (entry.value_ptr.*) {
            .define => |value| {
                try argv.append("-D");
                const define_arg = try std.fmt.allocPrint(arena, "{s}={s}", .{ entry.key_ptr.*, value });
                try argv.append(define_arg);
            },
            .undefine => {
                try argv.append("-U");
                try argv.append(entry.key_ptr.*);
            },
        }
    }
}
