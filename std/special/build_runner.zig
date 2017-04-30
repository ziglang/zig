const root = @import("@build");
const std = @import("std");
const io = std.io;
const fmt = std.fmt;
const os = std.os;
const Builder = std.build.Builder;
const mem = std.mem;
const List = std.list.List;

error InvalidArgs;

pub fn main() -> %void {
    var arg_i: usize = 1;

    const zig_exe = {
        if (arg_i >= os.args.count()) {
            %%io.stderr.printf("Expected first argument to be path to zig compiler\n");
            return error.InvalidArgs;
        }
        const result = os.args.at(arg_i);
        arg_i += 1;
        result
    };

    const build_root = {
        if (arg_i >= os.args.count()) {
            %%io.stderr.printf("Expected second argument to be build root directory path\n");
            return error.InvalidArgs;
        }
        const result = os.args.at(arg_i);
        arg_i += 1;
        result
    };

    const cache_root = {
        if (arg_i >= os.args.count()) {
            %%io.stderr.printf("Expected third argument to be cache root directory path\n");
            return error.InvalidArgs;
        }
        const result = os.args.at(arg_i);
        arg_i += 1;
        result
    };

    // TODO use a more general purpose allocator here
    var inc_allocator = %%mem.IncrementingAllocator.init(10 * 1024 * 1024);
    defer inc_allocator.deinit();

    const allocator = &inc_allocator.allocator;

    var builder = Builder.init(allocator, zig_exe, build_root, cache_root);
    defer builder.deinit();

    var targets = List([]const u8).init(allocator);

    var prefix: ?[]const u8 = null;

    while (arg_i < os.args.count(); arg_i += 1) {
        const arg = os.args.at(arg_i);
        if (mem.startsWith(u8, arg, "-D")) {
            const option_contents = arg[2...];
            if (option_contents.len == 0) {
                %%io.stderr.printf("Expected option name after '-D'\n\n");
                return usage(&builder, false, &io.stderr);
            }
            test (mem.indexOfScalar(u8, option_contents, '=')) |name_end| {
                const option_name = option_contents[0...name_end];
                const option_value = option_contents[name_end + 1...];
                if (builder.addUserInputOption(option_name, option_value))
                    return usage(&builder, false, &io.stderr);
            } else {
                if (builder.addUserInputFlag(option_contents))
                    return usage(&builder, false, &io.stderr);
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "--help")) {
                 return usage(&builder, false, &io.stdout);
            } else if (mem.eql(u8, arg, "--prefix") and arg_i + 1 < os.args.count()) {
                 arg_i += 1;
                 prefix = os.args.at(arg_i);
            } else {
                %%io.stderr.printf("Unrecognized argument: {}\n\n", arg);
                return usage(&builder, false, &io.stderr);
            }
        } else {
            %%targets.append(arg);
        }
    }

    builder.setInstallPrefix(prefix);
    root.build(&builder);

    if (builder.validateUserInputDidItFail())
        return usage(&builder, true, &io.stderr);

    builder.make(targets.toSliceConst()) %% |err| {
        if (err == error.InvalidStepName) {
            return usage(&builder, true, &io.stderr);
        }
        return err;
    };
}

fn usage(builder: &Builder, already_ran_build: bool, out_stream: &io.OutStream) -> %void {
    // run the build script to collect the options
    if (!already_ran_build) {
        builder.setInstallPrefix(null);
        root.build(builder);
    }

    // This usage text has to be synchronized with src/main.cpp
    %%out_stream.printf(
        \\Usage: {} build [steps] [options]
        \\
        \\Steps:
        \\
    , builder.zig_exe);

    const allocator = builder.allocator;
    for (builder.top_level_steps.toSliceConst()) |top_level_step| {
        %%out_stream.printf("  {s22} {}\n", top_level_step.step.name, top_level_step.description);
    }

    %%out_stream.write(
        \\
        \\General Options:
        \\  --help                 Print this help and exit
        \\  --build-file [file]    Override path to build.zig
        \\  --cache-dir [path]     Override path to cache directory
        \\  --verbose              Print commands before executing them
        \\  --debug-build-verbose  Print verbose debugging information for the build system itself
        \\  --prefix [prefix]      Override default install prefix
        \\
        \\Project-Specific Options:
        \\
    );

    if (builder.available_options_list.len == 0) {
        %%out_stream.printf("  (none)\n");
    } else {
        for (builder.available_options_list.toSliceConst()) |option| {
            const name = %%fmt.allocPrint(allocator,
                "  -D{}=({})", option.name, Builder.typeIdName(option.type_id));
            defer allocator.free(name);
            %%out_stream.printf("{s24} {}\n", name, option.description);
        }
    }

    if (out_stream == &io.stderr)
        return error.InvalidArgs;
}
