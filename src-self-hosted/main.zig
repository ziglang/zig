const std = @import("std");
const builtin = @import("builtin");

const event = std.event;
const os = std.os;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;

const arg = @import("arg.zig");
const c = @import("c.zig");
const introspect = @import("introspect.zig");
const Args = arg.Args;
const Flag = arg.Flag;
const Module = @import("module.zig").Module;
const Target = @import("target.zig").Target;
const errmsg = @import("errmsg.zig");

var stderr_file: os.File = undefined;
var stderr: *io.OutStream(io.FileOutStream.Error) = undefined;
var stdout: *io.OutStream(io.FileOutStream.Error) = undefined;

const usage =
    \\usage: zig [command] [options]
    \\
    \\Commands:
    \\
    \\  build-exe   [source]         Create executable from source or object files
    \\  build-lib   [source]         Create library from source or object files
    \\  build-obj   [source]         Create object from source or assembly
    \\  fmt         [source]         Parse file and render in canonical zig format
    \\  targets                      List available compilation targets
    \\  version                      Print version number and exit
    \\  zen                          Print zen of zig and exit
    \\
    \\
;

const Command = struct {
    name: []const u8,
    exec: fn (*Allocator, []const []const u8) error!void,
};

pub fn main() !void {
    // This allocator needs to be thread-safe because we use it for the event.Loop
    // which multiplexes coroutines onto kernel threads.
    // libc allocator is guaranteed to have this property.
    const allocator = std.heap.c_allocator;

    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = std.io.FileOutStream.init(&stdout_file);
    stdout = &stdout_out_stream.stream;

    stderr_file = try std.io.getStdErr();
    var stderr_out_stream = std.io.FileOutStream.init(&stderr_file);
    stderr = &stderr_out_stream.stream;

    const args = try os.argsAlloc(allocator);
    // TODO I'm getting  unreachable code here, which shouldn't happen
    //defer os.argsFree(allocator, args);

    if (args.len <= 1) {
        try stderr.write("expected command argument\n\n");
        try stderr.write(usage);
        os.exit(1);
    }

    const commands = []Command{
        Command{
            .name = "build-exe",
            .exec = cmdBuildExe,
        },
        Command{
            .name = "build-lib",
            .exec = cmdBuildLib,
        },
        Command{
            .name = "build-obj",
            .exec = cmdBuildObj,
        },
        Command{
            .name = "fmt",
            .exec = cmdFmt,
        },
        Command{
            .name = "targets",
            .exec = cmdTargets,
        },
        Command{
            .name = "version",
            .exec = cmdVersion,
        },
        Command{
            .name = "zen",
            .exec = cmdZen,
        },

        // undocumented commands
        Command{
            .name = "help",
            .exec = cmdHelp,
        },
        Command{
            .name = "internal",
            .exec = cmdInternal,
        },
    };

    for (commands) |command| {
        if (mem.eql(u8, command.name, args[1])) {
            return command.exec(allocator, args[2..]);
        }
    }

    try stderr.print("unknown command: {}\n\n", args[1]);
    try stderr.write(usage);
    os.exit(1);
}

const usage_build_generic =
    \\usage: zig build-exe <options> [file]
    \\       zig build-lib <options> [file]
    \\       zig build-obj <options> [file]
    \\
    \\General Options:
    \\  --help                       Print this help and exit
    \\  --color [auto|off|on]        Enable or disable colored error messages
    \\
    \\Compile Options:
    \\  --assembly [source]          Add assembly file to build
    \\  --cache-dir [path]           Override the cache directory
    \\  --emit [filetype]            Emit a specific file format as compilation output
    \\  --enable-timing-info         Print timing diagnostics
    \\  --libc-include-dir [path]    Directory where libc stdlib.h resides
    \\  --name [name]                Override output name
    \\  --output [file]              Override destination path
    \\  --output-h [file]            Override generated header file path
    \\  --pkg-begin [name] [path]    Make package available to import and push current pkg
    \\  --pkg-end                    Pop current pkg
    \\  --mode [mode]                Set the build mode
    \\    debug                      (default) optimizations off, safety on
    \\    release-fast               optimizations on, safety off
    \\    release-safe               optimizations on, safety on
    \\    release-small              optimize for small binary, safety off
    \\  --static                     Output will be statically linked
    \\  --strip                      Exclude debug symbols
    \\  --target-arch [name]         Specify target architecture
    \\  --target-environ [name]      Specify target environment
    \\  --target-os [name]           Specify target operating system
    \\  --verbose-tokenize           Turn on compiler debug output for tokenization
    \\  --verbose-ast-tree           Turn on compiler debug output for parsing into an AST (tree view)
    \\  --verbose-ast-fmt            Turn on compiler debug output for parsing into an AST (render source)
    \\  --verbose-link               Turn on compiler debug output for linking
    \\  --verbose-ir                 Turn on compiler debug output for Zig IR
    \\  --verbose-llvm-ir            Turn on compiler debug output for LLVM IR
    \\  --verbose-cimport            Turn on compiler debug output for C imports
    \\  -dirafter [dir]              Same as -isystem but do it last
    \\  -isystem [dir]               Add additional search path for other .h files
    \\  -mllvm [arg]                 Additional arguments to forward to LLVM's option processing
    \\
    \\Link Options:
    \\  --ar-path [path]             Set the path to ar
    \\  --dynamic-linker [path]      Set the path to ld.so
    \\  --each-lib-rpath             Add rpath for each used dynamic library
    \\  --libc-lib-dir [path]        Directory where libc crt1.o resides
    \\  --libc-static-lib-dir [path] Directory where libc crtbegin.o resides
    \\  --msvc-lib-dir [path]        (windows) directory where vcruntime.lib resides
    \\  --kernel32-lib-dir [path]    (windows) directory where kernel32.lib resides
    \\  --library [lib]              Link against lib
    \\  --forbid-library [lib]       Make it an error to link against lib
    \\  --library-path [dir]         Add a directory to the library search path
    \\  --linker-script [path]       Use a custom linker script
    \\  --object [obj]               Add object file to build
    \\  -rdynamic                    Add all symbols to the dynamic symbol table
    \\  -rpath [path]                Add directory to the runtime library search path
    \\  -mconsole                    (windows) --subsystem console to the linker
    \\  -mwindows                    (windows) --subsystem windows to the linker
    \\  -framework [name]            (darwin) link against framework
    \\  -mios-version-min [ver]      (darwin) set iOS deployment target
    \\  -mmacosx-version-min [ver]   (darwin) set Mac OS X deployment target
    \\  --ver-major [ver]            Dynamic library semver major version
    \\  --ver-minor [ver]            Dynamic library semver minor version
    \\  --ver-patch [ver]            Dynamic library semver patch version
    \\
    \\
;

const args_build_generic = []Flag{
    Flag.Bool("--help"),
    Flag.Option("--color", []const []const u8{
        "auto",
        "off",
        "on",
    }),
    Flag.Option("--mode", []const []const u8{
        "debug",
        "release-fast",
        "release-safe",
        "release-small",
    }),

    Flag.ArgMergeN("--assembly", 1),
    Flag.Arg1("--cache-dir"),
    Flag.Option("--emit", []const []const u8{
        "asm",
        "bin",
        "llvm-ir",
    }),
    Flag.Bool("--enable-timing-info"),
    Flag.Arg1("--libc-include-dir"),
    Flag.Arg1("--name"),
    Flag.Arg1("--output"),
    Flag.Arg1("--output-h"),
    // NOTE: Parsed manually after initial check
    Flag.ArgN("--pkg-begin", 2),
    Flag.Bool("--pkg-end"),
    Flag.Bool("--static"),
    Flag.Bool("--strip"),
    Flag.Arg1("--target-arch"),
    Flag.Arg1("--target-environ"),
    Flag.Arg1("--target-os"),
    Flag.Bool("--verbose-tokenize"),
    Flag.Bool("--verbose-ast-tree"),
    Flag.Bool("--verbose-ast-fmt"),
    Flag.Bool("--verbose-link"),
    Flag.Bool("--verbose-ir"),
    Flag.Bool("--verbose-llvm-ir"),
    Flag.Bool("--verbose-cimport"),
    Flag.Arg1("-dirafter"),
    Flag.ArgMergeN("-isystem", 1),
    Flag.Arg1("-mllvm"),

    Flag.Arg1("--ar-path"),
    Flag.Arg1("--dynamic-linker"),
    Flag.Bool("--each-lib-rpath"),
    Flag.Arg1("--libc-lib-dir"),
    Flag.Arg1("--libc-static-lib-dir"),
    Flag.Arg1("--msvc-lib-dir"),
    Flag.Arg1("--kernel32-lib-dir"),
    Flag.ArgMergeN("--library", 1),
    Flag.ArgMergeN("--forbid-library", 1),
    Flag.ArgMergeN("--library-path", 1),
    Flag.Arg1("--linker-script"),
    Flag.ArgMergeN("--object", 1),
    // NOTE: Removed -L since it would need to be special-cased and we have an alias in library-path
    Flag.Bool("-rdynamic"),
    Flag.Arg1("-rpath"),
    Flag.Bool("-mconsole"),
    Flag.Bool("-mwindows"),
    Flag.ArgMergeN("-framework", 1),
    Flag.Arg1("-mios-version-min"),
    Flag.Arg1("-mmacosx-version-min"),
    Flag.Arg1("--ver-major"),
    Flag.Arg1("--ver-minor"),
    Flag.Arg1("--ver-patch"),
};

fn buildOutputType(allocator: *Allocator, args: []const []const u8, out_type: Module.Kind) !void {
    var flags = try Args.parse(allocator, args_build_generic, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stdout.write(usage_build_generic);
        os.exit(0);
    }

    const build_mode = blk: {
        if (flags.single("mode")) |mode_flag| {
            if (mem.eql(u8, mode_flag, "debug")) {
                break :blk builtin.Mode.Debug;
            } else if (mem.eql(u8, mode_flag, "release-fast")) {
                break :blk builtin.Mode.ReleaseFast;
            } else if (mem.eql(u8, mode_flag, "release-safe")) {
                break :blk builtin.Mode.ReleaseSafe;
            } else if (mem.eql(u8, mode_flag, "release-small")) {
                break :blk builtin.Mode.ReleaseSmall;
            } else unreachable;
        } else {
            break :blk builtin.Mode.Debug;
        }
    };

    const color = blk: {
        if (flags.single("color")) |color_flag| {
            if (mem.eql(u8, color_flag, "auto")) {
                break :blk errmsg.Color.Auto;
            } else if (mem.eql(u8, color_flag, "on")) {
                break :blk errmsg.Color.On;
            } else if (mem.eql(u8, color_flag, "off")) {
                break :blk errmsg.Color.Off;
            } else unreachable;
        } else {
            break :blk errmsg.Color.Auto;
        }
    };

    const emit_type = blk: {
        if (flags.single("emit")) |emit_flag| {
            if (mem.eql(u8, emit_flag, "asm")) {
                break :blk Module.Emit.Assembly;
            } else if (mem.eql(u8, emit_flag, "bin")) {
                break :blk Module.Emit.Binary;
            } else if (mem.eql(u8, emit_flag, "llvm-ir")) {
                break :blk Module.Emit.LlvmIr;
            } else unreachable;
        } else {
            break :blk Module.Emit.Binary;
        }
    };

    var cur_pkg = try CliPkg.init(allocator, "", "", null);
    defer cur_pkg.deinit();

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg_name = args[i];
        if (mem.eql(u8, "--pkg-begin", arg_name)) {
            // following two arguments guaranteed to exist due to arg parsing
            i += 1;
            const new_pkg_name = args[i];
            i += 1;
            const new_pkg_path = args[i];

            var new_cur_pkg = try CliPkg.init(allocator, new_pkg_name, new_pkg_path, cur_pkg);
            try cur_pkg.children.append(new_cur_pkg);
            cur_pkg = new_cur_pkg;
        } else if (mem.eql(u8, "--pkg-end", arg_name)) {
            if (cur_pkg.parent) |parent| {
                cur_pkg = parent;
            } else {
                try stderr.print("encountered --pkg-end with no matching --pkg-begin\n");
                os.exit(1);
            }
        }
    }

    if (cur_pkg.parent != null) {
        try stderr.print("unmatched --pkg-begin\n");
        os.exit(1);
    }

    const provided_name = flags.single("name");
    const root_source_file = switch (flags.positionals.len) {
        0 => null,
        1 => flags.positionals.at(0),
        else => {
            try stderr.print("unexpected extra parameter: {}\n", flags.positionals.at(1));
            os.exit(1);
        },
    };

    const root_name = if (provided_name) |n| n else blk: {
        if (root_source_file) |file| {
            const basename = os.path.basename(file);
            var it = mem.split(basename, ".");
            break :blk it.next() orelse basename;
        } else {
            try stderr.write("--name [name] not provided and unable to infer\n");
            os.exit(1);
        }
    };

    const assembly_files = flags.many("assembly");
    const link_objects = flags.many("object");
    if (root_source_file == null and link_objects.len == 0 and assembly_files.len == 0) {
        try stderr.write("Expected source file argument or at least one --object or --assembly argument\n");
        os.exit(1);
    }

    if (out_type == Module.Kind.Obj and link_objects.len != 0) {
        try stderr.write("When building an object file, --object arguments are invalid\n");
        os.exit(1);
    }

    const rel_cache_dir = flags.single("cache-dir") orelse "zig-cache"[0..];
    const full_cache_dir = os.path.resolve(allocator, ".", rel_cache_dir) catch {
        try stderr.print("invalid cache dir: {}\n", rel_cache_dir);
        os.exit(1);
    };
    defer allocator.free(full_cache_dir);

    const zig_lib_dir = introspect.resolveZigLibDir(allocator) catch os.exit(1);
    defer allocator.free(zig_lib_dir);

    var loop = try event.Loop.init(allocator);

    var module = try Module.create(
        &loop,
        root_name,
        root_source_file,
        Target.Native,
        out_type,
        build_mode,
        zig_lib_dir,
        full_cache_dir,
    );
    defer module.destroy();

    module.version_major = try std.fmt.parseUnsigned(u32, flags.single("ver-major") orelse "0", 10);
    module.version_minor = try std.fmt.parseUnsigned(u32, flags.single("ver-minor") orelse "0", 10);
    module.version_patch = try std.fmt.parseUnsigned(u32, flags.single("ver-patch") orelse "0", 10);

    module.is_test = false;

    module.linker_script = flags.single("linker-script");
    module.each_lib_rpath = flags.present("each-lib-rpath");

    var clang_argv_buf = ArrayList([]const u8).init(allocator);
    defer clang_argv_buf.deinit();

    const mllvm_flags = flags.many("mllvm");
    for (mllvm_flags) |mllvm| {
        try clang_argv_buf.append("-mllvm");
        try clang_argv_buf.append(mllvm);
    }

    module.llvm_argv = mllvm_flags;
    module.clang_argv = clang_argv_buf.toSliceConst();

    module.strip = flags.present("strip");
    module.is_static = flags.present("static");

    if (flags.single("libc-lib-dir")) |libc_lib_dir| {
        module.libc_lib_dir = libc_lib_dir;
    }
    if (flags.single("libc-static-lib-dir")) |libc_static_lib_dir| {
        module.libc_static_lib_dir = libc_static_lib_dir;
    }
    if (flags.single("libc-include-dir")) |libc_include_dir| {
        module.libc_include_dir = libc_include_dir;
    }
    if (flags.single("msvc-lib-dir")) |msvc_lib_dir| {
        module.msvc_lib_dir = msvc_lib_dir;
    }
    if (flags.single("kernel32-lib-dir")) |kernel32_lib_dir| {
        module.kernel32_lib_dir = kernel32_lib_dir;
    }
    if (flags.single("dynamic-linker")) |dynamic_linker| {
        module.dynamic_linker = dynamic_linker;
    }

    module.verbose_tokenize = flags.present("verbose-tokenize");
    module.verbose_ast_tree = flags.present("verbose-ast-tree");
    module.verbose_ast_fmt = flags.present("verbose-ast-fmt");
    module.verbose_link = flags.present("verbose-link");
    module.verbose_ir = flags.present("verbose-ir");
    module.verbose_llvm_ir = flags.present("verbose-llvm-ir");
    module.verbose_cimport = flags.present("verbose-cimport");

    module.err_color = color;
    module.lib_dirs = flags.many("library-path");
    module.darwin_frameworks = flags.many("framework");
    module.rpath_list = flags.many("rpath");

    if (flags.single("output-h")) |output_h| {
        module.out_h_path = output_h;
    }

    module.windows_subsystem_windows = flags.present("mwindows");
    module.windows_subsystem_console = flags.present("mconsole");
    module.linker_rdynamic = flags.present("rdynamic");

    if (flags.single("mmacosx-version-min") != null and flags.single("mios-version-min") != null) {
        try stderr.write("-mmacosx-version-min and -mios-version-min options not allowed together\n");
        os.exit(1);
    }

    if (flags.single("mmacosx-version-min")) |ver| {
        module.darwin_version_min = Module.DarwinVersionMin{ .MacOS = ver };
    }
    if (flags.single("mios-version-min")) |ver| {
        module.darwin_version_min = Module.DarwinVersionMin{ .Ios = ver };
    }

    module.emit_file_type = emit_type;
    module.link_objects = link_objects;
    module.assembly_files = assembly_files;
    module.link_out_file = flags.single("out-file");

    try module.build();
    const process_build_events_handle = try async<loop.allocator> processBuildEvents(module, true);
    defer cancel process_build_events_handle;
    loop.run();
}

async fn processBuildEvents(module: *Module, watch: bool) void {
    while (watch) {
        // TODO directly awaiting async should guarantee memory allocation elision
        const build_event = await (async module.events.get() catch unreachable);

        switch (build_event) {
            Module.Event.Ok => {
                std.debug.warn("Build succeeded\n");
                // for now we stop after 1
                module.loop.stop();
                return;
            },
            Module.Event.Error => |err| {
                std.debug.warn("build failed: {}\n", @errorName(err));
                @panic("TODO error return trace");
            },
            Module.Event.Fail => |errs| {
                @panic("TODO print compile error messages");
            },
        }
    }
}

fn cmdBuildExe(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Module.Kind.Exe);
}

fn cmdBuildLib(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Module.Kind.Lib);
}

fn cmdBuildObj(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Module.Kind.Obj);
}

const usage_fmt =
    \\usage: zig fmt [file]...
    \\
    \\   Formats the input files and modifies them in-place.
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\   --color [auto|off|on]  Enable or disable colored error messages
    \\
    \\
;

const args_fmt_spec = []Flag{
    Flag.Bool("--help"),
    Flag.Option("--color", []const []const u8{
        "auto",
        "off",
        "on",
    }),
};

const Fmt = struct {
    seen: std.HashMap([]const u8, void, mem.hash_slice_u8, mem.eql_slice_u8),
    queue: std.LinkedList([]const u8),
    any_error: bool,

    // file_path must outlive Fmt
    fn addToQueue(self: *Fmt, file_path: []const u8) !void {
        const new_node = try self.seen.allocator.create(std.LinkedList([]const u8).Node{
            .prev = undefined,
            .next = undefined,
            .data = file_path,
        });

        if (try self.seen.put(file_path, {})) |_| return;

        self.queue.append(new_node);
    }

    fn addDirToQueue(self: *Fmt, file_path: []const u8) !void {
        var dir = try std.os.Dir.open(self.seen.allocator, file_path);
        defer dir.close();
        while (try dir.next()) |entry| {
            if (entry.kind == std.os.Dir.Entry.Kind.Directory or mem.endsWith(u8, entry.name, ".zig")) {
                const full_path = try os.path.join(self.seen.allocator, file_path, entry.name);
                try self.addToQueue(full_path);
            }
        }
    }
};

fn cmdFmt(allocator: *Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_fmt_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stdout.write(usage_fmt);
        os.exit(0);
    }

    if (flags.positionals.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        os.exit(1);
    }

    const color = blk: {
        if (flags.single("color")) |color_flag| {
            if (mem.eql(u8, color_flag, "auto")) {
                break :blk errmsg.Color.Auto;
            } else if (mem.eql(u8, color_flag, "on")) {
                break :blk errmsg.Color.On;
            } else if (mem.eql(u8, color_flag, "off")) {
                break :blk errmsg.Color.Off;
            } else unreachable;
        } else {
            break :blk errmsg.Color.Auto;
        }
    };

    var fmt = Fmt{
        .seen = std.HashMap([]const u8, void, mem.hash_slice_u8, mem.eql_slice_u8).init(allocator),
        .queue = std.LinkedList([]const u8).init(),
        .any_error = false,
    };

    for (flags.positionals.toSliceConst()) |file_path| {
        try fmt.addToQueue(file_path);
    }

    while (fmt.queue.popFirst()) |node| {
        const file_path = node.data;

        var file = try os.File.openRead(allocator, file_path);
        defer file.close();

        const source_code = io.readFileAlloc(allocator, file_path) catch |err| switch (err) {
            error.IsDir => {
                try fmt.addDirToQueue(file_path);
                continue;
            },
            else => {
                try stderr.print("unable to open '{}': {}\n", file_path, err);
                fmt.any_error = true;
                continue;
            },
        };
        defer allocator.free(source_code);

        var tree = std.zig.parse(allocator, source_code) catch |err| {
            try stderr.print("error parsing file '{}': {}\n", file_path, err);
            fmt.any_error = true;
            continue;
        };
        defer tree.deinit();

        var error_it = tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            const msg = try errmsg.createFromParseError(allocator, parse_error, &tree, file_path);
            defer allocator.destroy(msg);

            try errmsg.printToFile(&stderr_file, msg, color);
        }
        if (tree.errors.len != 0) {
            fmt.any_error = true;
            continue;
        }

        const baf = try io.BufferedAtomicFile.create(allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(allocator, baf.stream(), &tree);
        if (anything_changed) {
            try stderr.print("{}\n", file_path);
            try baf.finish();
        }
    }

    if (fmt.any_error) {
        os.exit(1);
    }
}

// cmd:targets /////////////////////////////////////////////////////////////////////////////////////

fn cmdTargets(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.write("Architectures:\n");
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(builtin.Arch)) : (i += 1) {
            comptime const arch_tag = @memberName(builtin.Arch, i);
            // NOTE: Cannot use empty string, see #918.
            comptime const native_str = if (comptime mem.eql(u8, arch_tag, @tagName(builtin.arch))) " (native)\n" else "\n";

            try stdout.print("  {}{}", arch_tag, native_str);
        }
    }
    try stdout.write("\n");

    try stdout.write("Operating Systems:\n");
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(builtin.Os)) : (i += 1) {
            comptime const os_tag = @memberName(builtin.Os, i);
            // NOTE: Cannot use empty string, see #918.
            comptime const native_str = if (comptime mem.eql(u8, os_tag, @tagName(builtin.os))) " (native)\n" else "\n";

            try stdout.print("  {}{}", os_tag, native_str);
        }
    }
    try stdout.write("\n");

    try stdout.write("Environments:\n");
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(builtin.Environ)) : (i += 1) {
            comptime const environ_tag = @memberName(builtin.Environ, i);
            // NOTE: Cannot use empty string, see #918.
            comptime const native_str = if (comptime mem.eql(u8, environ_tag, @tagName(builtin.environ))) " (native)\n" else "\n";

            try stdout.print("  {}{}", environ_tag, native_str);
        }
    }
}

fn cmdVersion(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.print("{}\n", std.cstr.toSliceConst(c.ZIG_VERSION_STRING));
}

const args_test_spec = []Flag{Flag.Bool("--help")};

fn cmdHelp(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.write(usage);
}

const info_zen =
    \\
    \\ * Communicate intent precisely.
    \\ * Edge cases matter.
    \\ * Favor reading code over writing code.
    \\ * Only one obvious way to do things.
    \\ * Runtime crashes are better than bugs.
    \\ * Compile errors are better than runtime crashes.
    \\ * Incremental improvements.
    \\ * Avoid local maximums.
    \\ * Reduce the amount one must remember.
    \\ * Minimize energy spent on coding style.
    \\ * Together we serve end users.
    \\
    \\
;

fn cmdZen(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.write(info_zen);
}

const usage_internal =
    \\usage: zig internal [subcommand]
    \\
    \\Sub-Commands:
    \\  build-info                   Print static compiler build-info
    \\
    \\
;

fn cmdInternal(allocator: *Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try stderr.write(usage_internal);
        os.exit(1);
    }

    const sub_commands = []Command{Command{
        .name = "build-info",
        .exec = cmdInternalBuildInfo,
    }};

    for (sub_commands) |sub_command| {
        if (mem.eql(u8, sub_command.name, args[0])) {
            try sub_command.exec(allocator, args[1..]);
            return;
        }
    }

    try stderr.print("unknown sub command: {}\n\n", args[0]);
    try stderr.write(usage_internal);
}

fn cmdInternalBuildInfo(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.print(
        \\ZIG_CMAKE_BINARY_DIR {}
        \\ZIG_CXX_COMPILER     {}
        \\ZIG_LLVM_CONFIG_EXE  {}
        \\ZIG_LLD_INCLUDE_PATH {}
        \\ZIG_LLD_LIBRARIES    {}
        \\ZIG_STD_FILES        {}
        \\ZIG_C_HEADER_FILES   {}
        \\ZIG_DIA_GUIDS_LIB    {}
        \\
    ,
        std.cstr.toSliceConst(c.ZIG_CMAKE_BINARY_DIR),
        std.cstr.toSliceConst(c.ZIG_CXX_COMPILER),
        std.cstr.toSliceConst(c.ZIG_LLVM_CONFIG_EXE),
        std.cstr.toSliceConst(c.ZIG_LLD_INCLUDE_PATH),
        std.cstr.toSliceConst(c.ZIG_LLD_LIBRARIES),
        std.cstr.toSliceConst(c.ZIG_STD_FILES),
        std.cstr.toSliceConst(c.ZIG_C_HEADER_FILES),
        std.cstr.toSliceConst(c.ZIG_DIA_GUIDS_LIB),
    );
}

const CliPkg = struct {
    name: []const u8,
    path: []const u8,
    children: ArrayList(*CliPkg),
    parent: ?*CliPkg,

    pub fn init(allocator: *mem.Allocator, name: []const u8, path: []const u8, parent: ?*CliPkg) !*CliPkg {
        var pkg = try allocator.create(CliPkg{
            .name = name,
            .path = path,
            .children = ArrayList(*CliPkg).init(allocator),
            .parent = parent,
        });
        return pkg;
    }

    pub fn deinit(self: *CliPkg) void {
        for (self.children.toSliceConst()) |child| {
            child.deinit();
        }
        self.children.deinit();
    }
};
