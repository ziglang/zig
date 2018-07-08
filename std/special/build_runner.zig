const root = @import("@build");
const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const fmt = std.fmt;
const os = std.os;
const Builder = std.build.Builder;
const mem = std.mem;
const ArrayList = std.ArrayList;
const warn = std.debug.warn;

pub fn main() !void {
    var arg_it = os.args();

    // Here we use an ArenaAllocator backed by a DirectAllocator because a build is a short-lived,
    // one shot program. We don't need to waste time freeing memory and finding places to squish
    // bytes into. So we free everything all at once at the very end.

    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    // skip my own exe name
    _ = arg_it.skip();

    const zig_exe = try unwrapArg(arg_it.next(allocator) orelse {
        warn("Expected first argument to be path to zig compiler\n");
        return error.InvalidArgs;
    });
    const build_root = try unwrapArg(arg_it.next(allocator) orelse {
        warn("Expected second argument to be build root directory path\n");
        return error.InvalidArgs;
    });
    const cache_root = try unwrapArg(arg_it.next(allocator) orelse {
        warn("Expected third argument to be cache root directory path\n");
        return error.InvalidArgs;
    });

    var builder = Builder.init(allocator, zig_exe, build_root, cache_root);
    defer builder.deinit();

    var targets = ArrayList([]const u8).init(allocator);

    var prefix: ?[]const u8 = null;

    var stderr_file = io.getStdErr();
    var stderr_file_stream: io.FileOutStream = undefined;
    var stderr_stream = if (stderr_file) |*f| x: {
        stderr_file_stream = io.FileOutStream.init(f);
        break :x &stderr_file_stream.stream;
    } else |err| err;

    var stdout_file = io.getStdOut();
    var stdout_file_stream: io.FileOutStream = undefined;
    var stdout_stream = if (stdout_file) |*f| x: {
        stdout_file_stream = io.FileOutStream.init(f);
        break :x &stdout_file_stream.stream;
    } else |err| err;

    while (arg_it.next(allocator)) |err_or_arg| {
        const arg = try unwrapArg(err_or_arg);
        if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2..];
            if (option_contents.len == 0) {
                warn("Expected option name after '-D'\n\n");
                return usageAndErr(&builder, false, try stderr_stream);
            }
            if (mem.indexOfScalar(u8, option_contents, '=')) |name_end| {
                const option_name = option_contents[0..name_end];
                const option_value = option_contents[name_end + 1 ..];
                if (builder.addUserInputOption(option_name, option_value))
                    return usageAndErr(&builder, false, try stderr_stream);
            } else {
                if (builder.addUserInputFlag(option_contents))
                    return usageAndErr(&builder, false, try stderr_stream);
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "--help")) {
                return usage(&builder, false, try stdout_stream);
            } else if (mem.eql(u8, arg, "--prefix")) {
                prefix = try unwrapArg(arg_it.next(allocator) orelse {
                    warn("Expected argument after --prefix\n\n");
                    return usageAndErr(&builder, false, try stderr_stream);
                });
            } else if (mem.eql(u8, arg, "--search-prefix")) {
                const search_prefix = try unwrapArg(arg_it.next(allocator) orelse {
                    warn("Expected argument after --search-prefix\n\n");
                    return usageAndErr(&builder, false, try stderr_stream);
                });
                builder.addSearchPrefix(search_prefix);
            } else if (mem.eql(u8, arg, "--verbose-tokenize")) {
                builder.verbose_tokenize = true;
            } else if (mem.eql(u8, arg, "--verbose-ast")) {
                builder.verbose_ast = true;
            } else if (mem.eql(u8, arg, "--verbose-link")) {
                builder.verbose_link = true;
            } else if (mem.eql(u8, arg, "--verbose-ir")) {
                builder.verbose_ir = true;
            } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                builder.verbose_llvm_ir = true;
            } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                builder.verbose_cimport = true;
            } else {
                warn("Unrecognized argument: {}\n\n", arg);
                return usageAndErr(&builder, false, try stderr_stream);
            }
        } else {
            try targets.append(arg);
        }
    }

    builder.setInstallPrefix(prefix);
    try runBuild(&builder);

    if (builder.validateUserInputDidItFail())
        return usageAndErr(&builder, true, try stderr_stream);

    builder.make(targets.toSliceConst()) catch |err| {
        switch (err) {
            error.InvalidStepName => {
                return usageAndErr(&builder, true, try stderr_stream);
            },
            error.UncleanExit => os.exit(1),
            else => return err,
        }
    };
}

fn runBuild(builder: *Builder) error!void {
    switch (@typeId(@typeOf(root.build).ReturnType)) {
        builtin.TypeId.Void => root.build(builder),
        builtin.TypeId.ErrorUnion => try root.build(builder),
        else => @compileError("expected return type of build to be 'void' or '!void'"),
    }
}

fn usage(builder: *Builder, already_ran_build: bool, out_stream: var) !void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.setInstallPrefix(null);
        try runBuild(builder);
    }

    // This usage text has to be synchronized with src/main.cpp
    try out_stream.print(
        \\Usage: {} build [steps] [options]
        \\
        \\Steps:
        \\
    , builder.zig_exe);

    const allocator = builder.allocator;
    for (builder.top_level_steps.toSliceConst()) |top_level_step| {
        try out_stream.print("  {s22} {}\n", top_level_step.step.name, top_level_step.description);
    }

    try out_stream.write(
        \\
        \\General Options:
        \\  --help                 Print this help and exit
        \\  --init                 Generate a build.zig template
        \\  --verbose              Print commands before executing them
        \\  --prefix [path]        Override default install prefix
        \\  --search-prefix [path] Add a path to look for binaries, libraries, headers
        \\
        \\Project-Specific Options:
        \\
    );

    if (builder.available_options_list.len == 0) {
        try out_stream.print("  (none)\n");
    } else {
        for (builder.available_options_list.toSliceConst()) |option| {
            const name = try fmt.allocPrint(allocator, "  -D{}=[{}]", option.name, Builder.typeIdName(option.type_id));
            defer allocator.free(name);
            try out_stream.print("{s24} {}\n", name, option.description);
        }
    }

    try out_stream.write(
        \\
        \\Advanced Options:
        \\  --build-file [file]    Override path to build.zig
        \\  --cache-dir [path]     Override path to zig cache directory
        \\  --verbose-tokenize     Enable compiler debug output for tokenization
        \\  --verbose-ast          Enable compiler debug output for parsing into an AST
        \\  --verbose-link         Enable compiler debug output for linking
        \\  --verbose-ir           Enable compiler debug output for Zig IR
        \\  --verbose-llvm-ir      Enable compiler debug output for LLVM IR
        \\  --verbose-cimport      Enable compiler debug output for C imports
        \\
    );
}

fn usageAndErr(builder: *Builder, already_ran_build: bool, out_stream: var) error {
    usage(builder, already_ran_build, out_stream) catch {};
    return error.InvalidArgs;
}

const UnwrapArgError = error{OutOfMemory};

fn unwrapArg(arg: UnwrapArgError![]u8) UnwrapArgError![]u8 {
    return arg catch |err| {
        warn("Unable to parse command line: {}\n", err);
        return err;
    };
}
