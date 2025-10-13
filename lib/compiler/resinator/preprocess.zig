const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const cli = @import("cli.zig");
const Dependencies = @import("compile.zig").Dependencies;
const aro = @import("aro");

const PreprocessError = error{ ArgError, GeneratedSourceError, PreprocessError, FileTooBig, OutOfMemory, WriteFailed };

pub fn preprocess(
    comp: *aro.Compilation,
    writer: *std.Io.Writer,
    /// Expects argv[0] to be the command name
    argv: []const []const u8,
    maybe_dependencies: ?*Dependencies,
) PreprocessError!void {
    try comp.addDefaultPragmaHandlers();

    var driver: aro.Driver = .{ .comp = comp, .diagnostics = comp.diagnostics, .aro_name = "arocc" };
    defer driver.deinit();

    var macro_buf: std.ArrayList(u8) = .empty;
    defer macro_buf.deinit(comp.gpa);

    var discard_buffer: [64]u8 = undefined;
    var discarding: std.Io.Writer.Discarding = .init(&discard_buffer);
    _ = driver.parseArgs(&discarding.writer, &macro_buf, argv) catch |err| switch (err) {
        error.FatalError => return error.ArgError,
        error.OutOfMemory => |e| return e,
        error.WriteFailed => unreachable,
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
    var pp = aro.Preprocessor.initDefault(comp) catch |err| switch (err) {
        error.FatalError => return error.GeneratedSourceError,
        error.OutOfMemory => |e| return e,
    };
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

    try pp.prettyPrintTokens(writer, .result_only);

    if (maybe_dependencies) |dependencies| {
        for (comp.sources.values()) |comp_source| {
            if (comp_source.id == builtin_macros.id or comp_source.id == user_macros.id) continue;
            if (comp_source.id == .unused or comp_source.id == .generated) continue;
            const duped_path = try dependencies.allocator.dupe(u8, comp_source.path);
            errdefer dependencies.allocator.free(duped_path);
            try dependencies.list.append(dependencies.allocator, duped_path);
        }
    }
}

fn hasAnyErrors(comp: *aro.Compilation) bool {
    return comp.diagnostics.errors != 0;
}

/// `arena` is used for temporary -D argument strings and the INCLUDE environment variable.
/// The arena should be kept alive at least as long as `argv`.
pub fn appendAroArgs(arena: Allocator, argv: *std.ArrayList([]const u8), options: cli.Options, system_include_paths: []const []const u8) !void {
    try argv.appendSlice(arena, &.{
        "-E",
        "--comments",
        "-fuse-line-directives",
        "-fgnuc-version=4.2.1",
        "--target=x86_64-windows-msvc",
        "--emulate=msvc",
        "-nostdinc",
        "-DRC_INVOKED",
        "-D_WIN32", // undocumented, but defined by default
    });
    for (options.extra_include_paths.items) |extra_include_path| {
        try argv.append(arena, "-I");
        try argv.append(arena, extra_include_path);
    }

    for (system_include_paths) |include_path| {
        try argv.append(arena, "-isystem");
        try argv.append(arena, include_path);
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
            try argv.append(arena, "-isystem");
            try argv.append(arena, include_path);
        }
    }

    var symbol_it = options.symbols.iterator();
    while (symbol_it.next()) |entry| {
        switch (entry.value_ptr.*) {
            .define => |value| {
                try argv.append(arena, "-D");
                const define_arg = try std.fmt.allocPrint(arena, "{s}={s}", .{ entry.key_ptr.*, value });
                try argv.append(arena, define_arg);
            },
            .undefine => {
                try argv.append(arena, "-U");
                try argv.append(arena, entry.key_ptr.*);
            },
        }
    }
}
