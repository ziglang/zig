const root = @import("@build");
const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const fmt = std.fmt;
const mem = std.mem;
const process = std.process;
const ArrayList = std.ArrayList;
const File = std.fs.File;

pub const dependencies = @import("@dependencies");

pub fn main() !void {
    // Here we use an ArenaAllocator backed by a DirectAllocator because a build is a short-lived,
    // one shot program. We don't need to waste time freeing memory and finding places to squish
    // bytes into. So we free everything all at once at the very end.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    // skip my own exe name
    var arg_idx: usize = 1;

    const zig_exe = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected path to zig compiler\n", .{});
        return error.InvalidArgs;
    };
    const build_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected build root directory path\n", .{});
        return error.InvalidArgs;
    };
    const cache_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected cache root directory path\n", .{});
        return error.InvalidArgs;
    };
    const global_cache_root = nextArg(args, &arg_idx) orelse {
        std.debug.print("Expected global cache root directory path\n", .{});
        return error.InvalidArgs;
    };

    const host = try std.zig.system.NativeTargetInfo.detect(.{});

    const builder = try std.Build.create(
        allocator,
        zig_exe,
        build_root,
        cache_root,
        global_cache_root,
        host,
    );
    defer builder.destroy();

    var targets = ArrayList([]const u8).init(allocator);
    var debug_log_scopes = ArrayList([]const u8).init(allocator);

    const stderr_stream = io.getStdErr().writer();
    const stdout_stream = io.getStdOut().writer();

    var install_prefix: ?[]const u8 = null;
    var dir_list = std.Build.DirList{};

    // before arg parsing, check for the NO_COLOR environment variable
    // if it exists, default the color setting to .off
    // explicit --color arguments will still override this setting.
    builder.color = if (std.process.hasEnvVarConstant("NO_COLOR")) .off else .auto;

    while (nextArg(args, &arg_idx)) |arg| {
        if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2..];
            if (option_contents.len == 0) {
                std.debug.print("Expected option name after '-D'\n\n", .{});
                return usageAndErr(builder, false, stderr_stream);
            }
            if (mem.indexOfScalar(u8, option_contents, '=')) |name_end| {
                const option_name = option_contents[0..name_end];
                const option_value = option_contents[name_end + 1 ..];
                if (try builder.addUserInputOption(option_name, option_value))
                    return usageAndErr(builder, false, stderr_stream);
            } else {
                if (try builder.addUserInputFlag(option_contents))
                    return usageAndErr(builder, false, stderr_stream);
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                return usage(builder, false, stdout_stream);
            } else if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--prefix")) {
                install_prefix = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "-l") or mem.eql(u8, arg, "--list-steps")) {
                return steps(builder, false, stdout_stream);
            } else if (mem.eql(u8, arg, "--prefix-lib-dir")) {
                dir_list.lib_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--prefix-exe-dir")) {
                dir_list.exe_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--prefix-include-dir")) {
                dir_list.include_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--sysroot")) {
                const sysroot = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --sysroot\n\n", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
                builder.sysroot = sysroot;
            } else if (mem.eql(u8, arg, "--search-prefix")) {
                const search_prefix = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --search-prefix\n\n", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
                builder.addSearchPrefix(search_prefix);
            } else if (mem.eql(u8, arg, "--libc")) {
                const libc_file = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --libc\n\n", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
                builder.libc_file = libc_file;
            } else if (mem.eql(u8, arg, "--color")) {
                const next_arg = nextArg(args, &arg_idx) orelse {
                    std.debug.print("expected [auto|on|off] after --color", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
                builder.color = std.meta.stringToEnum(@TypeOf(builder.color), next_arg) orelse {
                    std.debug.print("expected [auto|on|off] after --color, found '{s}'", .{next_arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                builder.override_lib_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --zig-lib-dir\n\n", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--debug-log")) {
                const next_arg = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after {s}\n\n", .{arg});
                    return usageAndErr(builder, false, stderr_stream);
                };
                try debug_log_scopes.append(next_arg);
            } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                builder.debug_compile_errors = true;
            } else if (mem.eql(u8, arg, "--glibc-runtimes")) {
                builder.glibc_runtimes_dir = nextArg(args, &arg_idx) orelse {
                    std.debug.print("Expected argument after --glibc-runtimes\n\n", .{});
                    return usageAndErr(builder, false, stderr_stream);
                };
            } else if (mem.eql(u8, arg, "--verbose-link")) {
                builder.verbose_link = true;
            } else if (mem.eql(u8, arg, "--verbose-air")) {
                builder.verbose_air = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                builder.verbose_llvm_ir = true;
            } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                builder.verbose_cimport = true;
            } else if (mem.eql(u8, arg, "--verbose-cc")) {
                builder.verbose_cc = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-cpu-features")) {
                builder.verbose_llvm_cpu_features = true;
            } else if (mem.eql(u8, arg, "--prominent-compile-errors")) {
                builder.prominent_compile_errors = true;
            } else if (mem.eql(u8, arg, "-fwine")) {
                builder.enable_wine = true;
            } else if (mem.eql(u8, arg, "-fno-wine")) {
                builder.enable_wine = false;
            } else if (mem.eql(u8, arg, "-fqemu")) {
                builder.enable_qemu = true;
            } else if (mem.eql(u8, arg, "-fno-qemu")) {
                builder.enable_qemu = false;
            } else if (mem.eql(u8, arg, "-fwasmtime")) {
                builder.enable_wasmtime = true;
            } else if (mem.eql(u8, arg, "-fno-wasmtime")) {
                builder.enable_wasmtime = false;
            } else if (mem.eql(u8, arg, "-frosetta")) {
                builder.enable_rosetta = true;
            } else if (mem.eql(u8, arg, "-fno-rosetta")) {
                builder.enable_rosetta = false;
            } else if (mem.eql(u8, arg, "-fdarling")) {
                builder.enable_darling = true;
            } else if (mem.eql(u8, arg, "-fno-darling")) {
                builder.enable_darling = false;
            } else if (mem.eql(u8, arg, "-freference-trace")) {
                builder.reference_trace = 256;
            } else if (mem.startsWith(u8, arg, "-freference-trace=")) {
                const num = arg["-freference-trace=".len..];
                builder.reference_trace = std.fmt.parseUnsigned(u32, num, 10) catch |err| {
                    std.debug.print("unable to parse reference_trace count '{s}': {s}", .{ num, @errorName(err) });
                    process.exit(1);
                };
            } else if (mem.eql(u8, arg, "-fno-reference-trace")) {
                builder.reference_trace = null;
            } else if (mem.eql(u8, arg, "--")) {
                builder.args = argsRest(args, arg_idx);
                break;
            } else {
                std.debug.print("Unrecognized argument: {s}\n\n", .{arg});
                return usageAndErr(builder, false, stderr_stream);
            }
        } else {
            try targets.append(arg);
        }
    }

    builder.debug_log_scopes = debug_log_scopes.items;
    builder.resolveInstallPrefix(install_prefix, dir_list);
    try builder.runBuild(root);

    if (builder.validateUserInputDidItFail())
        return usageAndErr(builder, true, stderr_stream);

    builder.make(targets.items) catch |err| {
        switch (err) {
            error.InvalidStepName => {
                return usageAndErr(builder, true, stderr_stream);
            },
            error.UncleanExit => process.exit(1),
            // This error is intended to indicate that the step has already
            // logged an error message and so printing the error return trace
            // here would be unwanted extra information, unless the user opts
            // into it with a debug flag.
            error.StepFailed => process.exit(1),
            else => return err,
        }
    };
}

fn steps(builder: *std.Build, already_ran_build: bool, out_stream: anytype) !void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.resolveInstallPrefix(null, .{});
        try builder.runBuild(root);
    }

    const allocator = builder.allocator;
    for (builder.top_level_steps.items) |top_level_step| {
        const name = if (&top_level_step.step == builder.default_step)
            try fmt.allocPrint(allocator, "{s} (default)", .{top_level_step.step.name})
        else
            top_level_step.step.name;
        try out_stream.print("  {s:<28} {s}\n", .{ name, top_level_step.description });
    }
}

fn usage(builder: *std.Build, already_ran_build: bool, out_stream: anytype) !void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.resolveInstallPrefix(null, .{});
        try builder.runBuild(root);
    }

    try out_stream.print(
        \\
        \\Usage: {s} build [steps] [options]
        \\
        \\Steps:
        \\
    , .{builder.zig_exe});
    try steps(builder, true, out_stream);

    try out_stream.writeAll(
        \\
        \\General Options:
        \\  -p, --prefix [path]          Override default install prefix
        \\  --prefix-lib-dir [path]      Override default library directory path
        \\  --prefix-exe-dir [path]      Override default executable directory path
        \\  --prefix-include-dir [path]  Override default include directory path
        \\
        \\  --sysroot [path]             Set the system root directory (usually /)
        \\  --search-prefix [path]       Add a path to look for binaries, libraries, headers
        \\  --libc [file]                Provide a file which specifies libc paths
        \\
        \\  -fdarling,  -fno-darling     Integration with system-installed Darling to
        \\                               execute macOS programs on Linux hosts
        \\                               (default: no)
        \\  -fqemu,     -fno-qemu        Integration with system-installed QEMU to execute
        \\                               foreign-architecture programs on Linux hosts
        \\                               (default: no)
        \\  --glibc-runtimes [path]      Enhances QEMU integration by providing glibc built
        \\                               for multiple foreign architectures, allowing
        \\                               execution of non-native programs that link with glibc.
        \\  -frosetta,  -fno-rosetta     Rely on Rosetta to execute x86_64 programs on
        \\                               ARM64 macOS hosts. (default: no)
        \\  -fwasmtime, -fno-wasmtime    Integration with system-installed wasmtime to
        \\                               execute WASI binaries. (default: no)
        \\  -fwine,     -fno-wine        Integration with system-installed Wine to execute
        \\                               Windows programs on Linux hosts. (default: no)
        \\
        \\  -h, --help                   Print this help and exit
        \\  -l, --list-steps             Print available steps
        \\  --verbose                    Print commands before executing them
        \\  --color [auto|off|on]        Enable or disable colored error messages
        \\  --prominent-compile-errors   Output compile errors formatted for a human to read
        \\
        \\Project-Specific Options:
        \\
    );

    const allocator = builder.allocator;
    if (builder.available_options_list.items.len == 0) {
        try out_stream.print("  (none)\n", .{});
    } else {
        for (builder.available_options_list.items) |option| {
            const name = try fmt.allocPrint(allocator, "  -D{s}=[{s}]", .{
                option.name,
                @tagName(option.type_id),
            });
            defer allocator.free(name);
            try out_stream.print("{s:<30} {s}\n", .{ name, option.description });
            if (option.enum_options) |enum_options| {
                const padding = " " ** 33;
                try out_stream.writeAll(padding ++ "Supported Values:\n");
                for (enum_options) |enum_option| {
                    try out_stream.print(padding ++ "  {s}\n", .{enum_option});
                }
            }
        }
    }

    try out_stream.writeAll(
        \\
        \\Advanced Options:
        \\  -freference-trace[=num]      How many lines of reference trace should be shown per compile error
        \\  -fno-reference-trace         Disable reference trace
        \\  --build-file [file]          Override path to build.zig
        \\  --cache-dir [path]           Override path to local Zig cache directory
        \\  --global-cache-dir [path]    Override path to global Zig cache directory
        \\  --zig-lib-dir [arg]          Override path to Zig lib directory
        \\  --debug-log [scope]          Enable debugging the compiler
        \\  --verbose-link               Enable compiler debug output for linking
        \\  --verbose-air                Enable compiler debug output for Zig AIR
        \\  --verbose-llvm-ir            Enable compiler debug output for LLVM IR
        \\  --verbose-cimport            Enable compiler debug output for C imports
        \\  --verbose-cc                 Enable compiler debug output for C compilation
        \\  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
        \\
    );
}

fn usageAndErr(builder: *std.Build, already_ran_build: bool, out_stream: anytype) void {
    usage(builder, already_ran_build, out_stream) catch {};
    process.exit(1);
}

fn nextArg(args: [][]const u8, idx: *usize) ?[]const u8 {
    if (idx.* >= args.len) return null;
    defer idx.* += 1;
    return args[idx.*];
}

fn argsRest(args: [][]const u8, idx: usize) ?[][]const u8 {
    if (idx >= args.len) return null;
    return args[idx..];
}
