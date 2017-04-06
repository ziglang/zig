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
    // TODO use a more general purpose allocator here
    var inc_allocator = %%mem.IncrementingAllocator.init(10 * 1024 * 1024);
    defer inc_allocator.deinit();

    const allocator = &inc_allocator.allocator;

    var builder = Builder.init(allocator);
    defer builder.deinit();

    var maybe_zig_exe: ?[]const u8 = null;
    var targets = List([]const u8).init(allocator);

    var arg_i: usize = 1;
    while (arg_i < os.args.count(); arg_i += 1) {
        const arg = os.args.at(arg_i);
        if (mem.startsWith(u8, arg, "-O")) {
            const option_contents = arg[2...];
            if (option_contents.len == 0) {
                %%io.stderr.printf("Expected option name after '-O'\n\n");
                return usage(&builder, maybe_zig_exe, false, &io.stderr);
            }
            if (const name_end ?= mem.indexOfScalar(u8, option_contents, '=')) {
                const option_name = option_contents[0...name_end];
                const option_value = option_contents[name_end...];
                if (builder.addUserInputOption(option_name, option_value))
                    return usage(&builder, maybe_zig_exe, false, &io.stderr);
            } else {
                if (builder.addUserInputFlag(option_contents))
                    return usage(&builder, maybe_zig_exe, false, &io.stderr);
            }
        } else if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "--verbose")) {
                builder.verbose = true;
            } else if (mem.eql(u8, arg, "--help")) {
                 return usage(&builder, maybe_zig_exe, false, &io.stdout);
            } else {
                %%io.stderr.printf("Unrecognized argument: {}\n\n", arg);
                return usage(&builder, maybe_zig_exe, false, &io.stderr);
            }
        } else if (maybe_zig_exe == null) {
            maybe_zig_exe = arg;
        } else {
            %%targets.append(arg);
        }
    }

    const zig_exe = maybe_zig_exe ?? return usage(&builder, null, false, &io.stderr);

    root.build(&builder);

    if (builder.validateUserInputDidItFail())
        return usage(&builder, maybe_zig_exe, true, &io.stderr);

    %return builder.make(zig_exe, targets.toSliceConst());
}

fn usage(builder: &Builder, maybe_zig_exe: ?[]const u8, already_ran_build: bool, out_stream: &io.OutStream) -> %void {
    const zig_exe = maybe_zig_exe ?? {
        %%out_stream.printf("Expected first argument to be path to zig compiler\n");
        return error.InvalidArgs;
    };

    // run the build script to collect the options
    if (!already_ran_build) {
        root.build(builder);
    }

    %%out_stream.printf(
        \\Usage: {} build [options]
        \\
        \\General Options:
        \\  --help                 Print this help and exit.
        \\  --verbose              Print commands before executing them.
        \\  --debug-build-verbose  Print verbose debugging information for the build system itself.
        \\
        \\Project-Specific Options:
        \\
    , zig_exe);

    if (builder.available_options_list.len == 0) {
        %%out_stream.printf("  (none)\n");
    } else {
        const allocator = builder.allocator;
        for (builder.available_options_list.toSliceConst()) |option| {
            const name = %%fmt.allocPrint(allocator,
                "  -O{}=({})", option.name, Builder.typeIdName(option.type_id));
            defer allocator.free(name);
            %%out_stream.printf("{s24} {}\n", name, option.description);
        }
    }

    if (out_stream == &io.stderr)
        return error.InvalidArgs;
}
