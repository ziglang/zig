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
const ZigCompiler = @import("compilation.zig").ZigCompiler;
const Compilation = @import("compilation.zig").Compilation;
const Target = @import("target.zig").Target;
const errmsg = @import("errmsg.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;

var stderr_file: os.File = undefined;
var stderr: *io.OutStream(os.File.WriteError) = undefined;
var stdout: *io.OutStream(os.File.WriteError) = undefined;

pub const max_src_size = 2 * 1024 * 1024 * 1024; // 2 GiB

const usage =
    \\usage: zig [command] [options]
    \\
    \\Commands:
    \\
    \\  build-exe  [source]      Create executable from source or object files
    \\  build-lib  [source]      Create library from source or object files
    \\  build-obj  [source]      Create object from source or assembly
    \\  fmt        [source]      Parse file and render in canonical zig format
    \\  libc       [paths_file]  Display native libc paths file or validate one
    \\  targets                  List available compilation targets
    \\  version                  Print version number and exit
    \\  zen                      Print zen of zig and exit
    \\
    \\
;

const Command = struct {
    name: []const u8,
    exec: fn (*Allocator, []const []const u8) anyerror!void,
};

pub fn main() !void {
    // This allocator needs to be thread-safe because we use it for the event.Loop
    // which multiplexes coroutines onto kernel threads.
    // libc allocator is guaranteed to have this property.
    const allocator = std.heap.c_allocator;

    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    stdout = &stdout_out_stream.stream;

    stderr_file = try std.io.getStdErr();
    var stderr_out_stream = stderr_file.outStream();
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
            .name = "libc",
            .exec = cmdLibC,
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
    \\  --libc [file]                Provide a file which specifies libc paths
    \\  --assembly [source]          Add assembly file to build
    \\  --emit [filetype]            Emit a specific file format as compilation output
    \\  --enable-timing-info         Print timing diagnostics
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
    \\  -target [name]               <arch><sub>-<os>-<abi> see the targets command
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
    \\  --each-lib-rpath             Add rpath for each used dynamic library
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
    Flag.Option("--emit", []const []const u8{
        "asm",
        "bin",
        "llvm-ir",
    }),
    Flag.Bool("--enable-timing-info"),
    Flag.Arg1("--libc"),
    Flag.Arg1("--name"),
    Flag.Arg1("--output"),
    Flag.Arg1("--output-h"),
    // NOTE: Parsed manually after initial check
    Flag.ArgN("--pkg-begin", 2),
    Flag.Bool("--pkg-end"),
    Flag.Bool("--static"),
    Flag.Bool("--strip"),
    Flag.Arg1("-target"),
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
    Flag.Bool("--each-lib-rpath"),
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

fn buildOutputType(allocator: *Allocator, args: []const []const u8, out_type: Compilation.Kind) !void {
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
                break :blk Compilation.Emit.Assembly;
            } else if (mem.eql(u8, emit_flag, "bin")) {
                break :blk Compilation.Emit.Binary;
            } else if (mem.eql(u8, emit_flag, "llvm-ir")) {
                break :blk Compilation.Emit.LlvmIr;
            } else unreachable;
        } else {
            break :blk Compilation.Emit.Binary;
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
            var it = mem.separate(basename, ".");
            break :blk it.next() orelse basename;
        } else {
            try stderr.write("--name [name] not provided and unable to infer\n");
            os.exit(1);
        }
    };

    const is_static = flags.present("static");

    const assembly_files = flags.many("assembly");
    const link_objects = flags.many("object");
    if (root_source_file == null and link_objects.len == 0 and assembly_files.len == 0) {
        try stderr.write("Expected source file argument or at least one --object or --assembly argument\n");
        os.exit(1);
    }

    if (out_type == Compilation.Kind.Obj and link_objects.len != 0) {
        try stderr.write("When building an object file, --object arguments are invalid\n");
        os.exit(1);
    }

    var clang_argv_buf = ArrayList([]const u8).init(allocator);
    defer clang_argv_buf.deinit();

    const mllvm_flags = flags.many("mllvm");
    for (mllvm_flags) |mllvm| {
        try clang_argv_buf.append("-mllvm");
        try clang_argv_buf.append(mllvm);
    }
    try ZigCompiler.setLlvmArgv(allocator, mllvm_flags);

    const zig_lib_dir = introspect.resolveZigLibDir(allocator) catch os.exit(1);
    defer allocator.free(zig_lib_dir);

    var override_libc: LibCInstallation = undefined;

    var loop: event.Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var zig_compiler = try ZigCompiler.init(&loop);
    defer zig_compiler.deinit();

    var comp = try Compilation.create(
        &zig_compiler,
        root_name,
        root_source_file,
        Target.Native,
        out_type,
        build_mode,
        is_static,
        zig_lib_dir,
    );
    defer comp.destroy();

    if (flags.single("libc")) |libc_path| {
        parseLibcPaths(loop.allocator, &override_libc, libc_path);
        comp.override_libc = &override_libc;
    }

    for (flags.many("library")) |lib| {
        _ = try comp.addLinkLib(lib, true);
    }

    comp.version_major = try std.fmt.parseUnsigned(u32, flags.single("ver-major") orelse "0", 10);
    comp.version_minor = try std.fmt.parseUnsigned(u32, flags.single("ver-minor") orelse "0", 10);
    comp.version_patch = try std.fmt.parseUnsigned(u32, flags.single("ver-patch") orelse "0", 10);

    comp.is_test = false;

    comp.linker_script = flags.single("linker-script");
    comp.each_lib_rpath = flags.present("each-lib-rpath");

    comp.clang_argv = clang_argv_buf.toSliceConst();

    comp.strip = flags.present("strip");

    comp.verbose_tokenize = flags.present("verbose-tokenize");
    comp.verbose_ast_tree = flags.present("verbose-ast-tree");
    comp.verbose_ast_fmt = flags.present("verbose-ast-fmt");
    comp.verbose_link = flags.present("verbose-link");
    comp.verbose_ir = flags.present("verbose-ir");
    comp.verbose_llvm_ir = flags.present("verbose-llvm-ir");
    comp.verbose_cimport = flags.present("verbose-cimport");

    comp.err_color = color;
    comp.lib_dirs = flags.many("library-path");
    comp.darwin_frameworks = flags.many("framework");
    comp.rpath_list = flags.many("rpath");

    if (flags.single("output-h")) |output_h| {
        comp.out_h_path = output_h;
    }

    comp.windows_subsystem_windows = flags.present("mwindows");
    comp.windows_subsystem_console = flags.present("mconsole");
    comp.linker_rdynamic = flags.present("rdynamic");

    if (flags.single("mmacosx-version-min") != null and flags.single("mios-version-min") != null) {
        try stderr.write("-mmacosx-version-min and -mios-version-min options not allowed together\n");
        os.exit(1);
    }

    if (flags.single("mmacosx-version-min")) |ver| {
        comp.darwin_version_min = Compilation.DarwinVersionMin{ .MacOS = ver };
    }
    if (flags.single("mios-version-min")) |ver| {
        comp.darwin_version_min = Compilation.DarwinVersionMin{ .Ios = ver };
    }

    comp.emit_file_type = emit_type;
    comp.assembly_files = assembly_files;
    comp.link_out_file = flags.single("output");
    comp.link_objects = link_objects;

    comp.start();
    const process_build_events_handle = try async<loop.allocator> processBuildEvents(comp, color);
    defer cancel process_build_events_handle;
    loop.run();
}

async fn processBuildEvents(comp: *Compilation, color: errmsg.Color) void {
    var count: usize = 0;
    while (true) {
        // TODO directly awaiting async should guarantee memory allocation elision
        const build_event = await (async comp.events.get() catch unreachable);
        count += 1;

        switch (build_event) {
            Compilation.Event.Ok => {
                stderr.print("Build {} succeeded\n", count) catch os.exit(1);
            },
            Compilation.Event.Error => |err| {
                stderr.print("Build {} failed: {}\n", count, @errorName(err)) catch os.exit(1);
            },
            Compilation.Event.Fail => |msgs| {
                stderr.print("Build {} compile errors:\n", count) catch os.exit(1);
                for (msgs) |msg| {
                    defer msg.destroy();
                    msg.printToFile(stderr_file, color) catch os.exit(1);
                }
            },
        }
    }
}

fn cmdBuildExe(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Compilation.Kind.Exe);
}

fn cmdBuildLib(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Compilation.Kind.Lib);
}

fn cmdBuildObj(allocator: *Allocator, args: []const []const u8) !void {
    return buildOutputType(allocator, args, Compilation.Kind.Obj);
}

pub const usage_fmt =
    \\usage: zig fmt [file]...
    \\
    \\   Formats the input files and modifies them in-place.
    \\   Arguments can be files or directories, which are searched
    \\   recursively.
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\   --color [auto|off|on]  Enable or disable colored error messages
    \\   --stdin                Format code from stdin; output to stdout
    \\   --check                List non-conforming files and exit with an error
    \\                          if the list is non-empty
    \\
    \\
;

pub const args_fmt_spec = []Flag{
    Flag.Bool("--help"),
    Flag.Bool("--check"),
    Flag.Option("--color", []const []const u8{
        "auto",
        "off",
        "on",
    }),
    Flag.Bool("--stdin"),
};

const Fmt = struct {
    seen: event.Locked(SeenMap),
    any_error: bool,
    color: errmsg.Color,
    loop: *event.Loop,

    const SeenMap = std.HashMap([]const u8, void, mem.hash_slice_u8, mem.eql_slice_u8);
};

fn parseLibcPaths(allocator: *Allocator, libc: *LibCInstallation, libc_paths_file: []const u8) void {
    libc.parse(allocator, libc_paths_file, stderr) catch |err| {
        stderr.print(
            "Unable to parse libc path file '{}': {}.\n" ++
                "Try running `zig libc` to see an example for the native target.\n",
            libc_paths_file,
            @errorName(err),
        ) catch os.exit(1);
        os.exit(1);
    };
}

fn cmdLibC(allocator: *Allocator, args: []const []const u8) !void {
    switch (args.len) {
        0 => {},
        1 => {
            var libc_installation: LibCInstallation = undefined;
            parseLibcPaths(allocator, &libc_installation, args[0]);
            return;
        },
        else => {
            try stderr.print("unexpected extra parameter: {}\n", args[1]);
            os.exit(1);
        },
    }

    var loop: event.Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var zig_compiler = try ZigCompiler.init(&loop);
    defer zig_compiler.deinit();

    const handle = try async<loop.allocator> findLibCAsync(&zig_compiler);
    defer cancel handle;

    loop.run();
}

async fn findLibCAsync(zig_compiler: *ZigCompiler) void {
    const libc = (await (async zig_compiler.getNativeLibC() catch unreachable)) catch |err| {
        stderr.print("unable to find libc: {}\n", @errorName(err)) catch os.exit(1);
        os.exit(1);
    };
    libc.render(stdout) catch os.exit(1);
}

fn cmdFmt(allocator: *Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_fmt_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stdout.write(usage_fmt);
        os.exit(0);
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

    if (flags.present("stdin")) {
        if (flags.positionals.len != 0) {
            try stderr.write("cannot use --stdin with positional arguments\n");
            os.exit(1);
        }

        var stdin_file = try io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.stream.readAllAlloc(allocator, max_src_size);
        defer allocator.free(source_code);

        var tree = std.zig.parse(allocator, source_code) catch |err| {
            try stderr.print("error parsing stdin: {}\n", err);
            os.exit(1);
        };
        defer tree.deinit();

        var error_it = tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            const msg = try errmsg.Msg.createFromParseError(allocator, parse_error, &tree, "<stdin>");
            defer msg.destroy();

            try msg.printToFile(stderr_file, color);
        }
        if (tree.errors.len != 0) {
            os.exit(1);
        }
        if (flags.present("check")) {
            const anything_changed = try std.zig.render(allocator, io.null_out_stream, &tree);
            const code = if (anything_changed) u8(1) else u8(0);
            os.exit(code);
        }

        _ = try std.zig.render(allocator, stdout, &tree);
        return;
    }

    if (flags.positionals.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        os.exit(1);
    }

    var loop: event.Loop = undefined;
    try loop.initMultiThreaded(allocator);
    defer loop.deinit();

    var result: FmtError!void = undefined;
    const main_handle = try async<allocator> asyncFmtMainChecked(
        &result,
        &loop,
        &flags,
        color,
    );
    defer cancel main_handle;
    loop.run();
    return result;
}

async fn asyncFmtMainChecked(
    result: *(FmtError!void),
    loop: *event.Loop,
    flags: *const Args,
    color: errmsg.Color,
) void {
    result.* = await (async asyncFmtMain(loop, flags, color) catch unreachable);
}

const FmtError = error{
    SystemResources,
    OperationAborted,
    IoPending,
    BrokenPipe,
    Unexpected,
    WouldBlock,
    FileClosed,
    DestinationAddressRequired,
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    AccessDenied,
    OutOfMemory,
    RenameAcrossMountPoints,
    ReadOnlyFileSystem,
    LinkQuotaExceeded,
    FileBusy,
} || os.File.OpenError;

async fn asyncFmtMain(
    loop: *event.Loop,
    flags: *const Args,
    color: errmsg.Color,
) FmtError!void {
    suspend {
        resume @handle();
    }
    var fmt = Fmt{
        .seen = event.Locked(Fmt.SeenMap).init(loop, Fmt.SeenMap.init(loop.allocator)),
        .any_error = false,
        .color = color,
        .loop = loop,
    };

    const check_mode = flags.present("check");

    var group = event.Group(FmtError!void).init(loop);
    for (flags.positionals.toSliceConst()) |file_path| {
        try group.call(fmtPath, &fmt, file_path, check_mode);
    }
    try await (async group.wait() catch unreachable);
    if (fmt.any_error) {
        os.exit(1);
    }
}

async fn fmtPath(fmt: *Fmt, file_path_ref: []const u8, check_mode: bool) FmtError!void {
    const file_path = try std.mem.dupe(fmt.loop.allocator, u8, file_path_ref);
    defer fmt.loop.allocator.free(file_path);

    {
        const held = await (async fmt.seen.acquire() catch unreachable);
        defer held.release();

        if (try held.value.put(file_path, {})) |_| return;
    }

    const source_code = (await try async event.fs.readFile(
        fmt.loop,
        file_path,
        max_src_size,
    )) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => {
            // TODO make event based (and dir.next())
            var dir = try std.os.Dir.open(fmt.loop.allocator, file_path);
            defer dir.close();

            var group = event.Group(FmtError!void).init(fmt.loop);
            while (try dir.next()) |entry| {
                if (entry.kind == std.os.Dir.Entry.Kind.Directory or mem.endsWith(u8, entry.name, ".zig")) {
                    const full_path = try os.path.join(fmt.loop.allocator, [][]const u8{ file_path, entry.name });
                    try group.call(fmtPath, fmt, full_path, check_mode);
                }
            }
            return await (async group.wait() catch unreachable);
        },
        else => {
            // TODO lock stderr printing
            try stderr.print("unable to open '{}': {}\n", file_path, err);
            fmt.any_error = true;
            return;
        },
    };
    defer fmt.loop.allocator.free(source_code);

    var tree = std.zig.parse(fmt.loop.allocator, source_code) catch |err| {
        try stderr.print("error parsing file '{}': {}\n", file_path, err);
        fmt.any_error = true;
        return;
    };
    defer tree.deinit();

    var error_it = tree.errors.iterator(0);
    while (error_it.next()) |parse_error| {
        const msg = try errmsg.Msg.createFromParseError(fmt.loop.allocator, parse_error, &tree, file_path);
        defer fmt.loop.allocator.destroy(msg);

        try msg.printToFile(stderr_file, fmt.color);
    }
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (check_mode) {
        const anything_changed = try std.zig.render(fmt.loop.allocator, io.null_out_stream, &tree);
        if (anything_changed) {
            try stderr.print("{}\n", file_path);
            fmt.any_error = true;
        }
    } else {
        // TODO make this evented
        const baf = try io.BufferedAtomicFile.create(fmt.loop.allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(fmt.loop.allocator, baf.stream(), &tree);
        if (anything_changed) {
            try stderr.print("{}\n", file_path);
            try baf.finish();
        }
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

    try stdout.write("C ABIs:\n");
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(builtin.Abi)) : (i += 1) {
            comptime const abi_tag = @memberName(builtin.Abi, i);
            // NOTE: Cannot use empty string, see #918.
            comptime const native_str = if (comptime mem.eql(u8, abi_tag, @tagName(builtin.abi))) " (native)\n" else "\n";

            try stdout.print("  {}{}", abi_tag, native_str);
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

pub const info_zen =
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
        var pkg = try allocator.create(CliPkg);
        pkg.* = CliPkg{
            .name = name,
            .path = path,
            .children = ArrayList(*CliPkg).init(allocator),
            .parent = parent,
        };
        return pkg;
    }

    pub fn deinit(self: *CliPkg) void {
        for (self.children.toSliceConst()) |child| {
            child.deinit();
        }
        self.children.deinit();
    }
};
