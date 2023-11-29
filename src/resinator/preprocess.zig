const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const cli = @import("cli.zig");

pub const IncludeArgs = struct {
    clang_target: ?[]const u8 = null,
    system_include_paths: []const []const u8,
    /// Should be set to `true` when -target has the GNU abi
    /// (either because `clang_target` has `-gnu` or `-target`
    /// is appended via other means and it has `-gnu`)
    needs_gnu_workaround: bool = false,
    nostdinc: bool = false,

    pub const IncludeAbi = enum {
        msvc,
        gnu,
    };
};

/// `arena` is used for temporary -D argument strings and the INCLUDE environment variable.
/// The arena should be kept alive at least as long as `argv`.
pub fn appendClangArgs(arena: Allocator, argv: *std.ArrayList([]const u8), options: cli.Options, include_args: IncludeArgs) !void {
    try argv.appendSlice(&[_][]const u8{
        "-E", // preprocessor only
        "--comments",
        "-fuse-line-directives", // #line <num> instead of # <num>
        // TODO: could use --trace-includes to give info about what's included from where
        "-xc", // output c
        // TODO: Turn this off, check the warnings, and convert the spaces back to NUL
        "-Werror=null-character", // error on null characters instead of converting them to spaces
        // TODO: could remove -Werror=null-character and instead parse warnings looking for 'warning: null character ignored'
        //       since the only real problem is when clang doesn't preserve null characters
        //"-Werror=invalid-pp-token", // will error on unfinished string literals
        // TODO: could use -Werror instead
        "-fms-compatibility", // Allow things like "header.h" to be resolved relative to the 'root' .rc file, among other things
        // https://learn.microsoft.com/en-us/windows/win32/menurc/predefined-macros
        "-DRC_INVOKED",
    });
    for (options.extra_include_paths.items) |extra_include_path| {
        try argv.append("-I");
        try argv.append(extra_include_path);
    }

    if (include_args.nostdinc) {
        try argv.append("-nostdinc");
    }
    for (include_args.system_include_paths) |include_path| {
        try argv.append("-isystem");
        try argv.append(include_path);
    }
    if (include_args.clang_target) |target| {
        try argv.append("-target");
        try argv.append(target);
    }
    // Using -fms-compatibility and targeting the GNU abi interact in a strange way:
    // - Targeting the GNU abi stops _MSC_VER from being defined
    // - Passing -fms-compatibility stops __GNUC__ from being defined
    // Neither being defined is a problem for things like MinGW's vadefs.h,
    // which will fail during preprocessing if neither are defined.
    // So, when targeting the GNU abi, we need to force __GNUC__ to be defined.
    //
    // TODO: This is a workaround that should be removed if possible.
    if (include_args.needs_gnu_workaround) {
        // This is the same default gnuc version that Clang uses:
        // https://github.com/llvm/llvm-project/blob/4b5366c9512aa273a5272af1d833961e1ed156e7/clang/lib/Driver/ToolChains/Clang.cpp#L6738
        try argv.append("-fgnuc-version=4.2.1");
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
