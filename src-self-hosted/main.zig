const std = @import("std");
const builtin = @import("builtin");

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

var stderr: &io.OutStream(io.FileOutStream.Error) = undefined;
var stdout: &io.OutStream(io.FileOutStream.Error) = undefined;

const usage =
    \\usage: zig [command] [options]
    \\
    \\Commands:
    \\
    \\  build                        Build project from build.zig
    \\  build-exe   [source]         Create executable from source or object files
    \\  build-lib   [source]         Create library from source or object files
    \\  build-obj   [source]         Create object from source or assembly
    \\  fmt         [source]         Parse file and render in canonical zig format
    \\  run         [source]         Create executable and run immediately
    \\  targets                      List available compilation targets
    \\  test        [source]         Create and run a test build
    \\  translate-c [source]         Convert c code to zig code
    \\  version                      Print version number and exit
    \\  zen                          Print zen of zig and exit
    \\
    \\
    ;

const Command = struct {
    name: []const u8,
    exec: fn(&Allocator, []const []const u8) error!void,
};

pub fn main() !void {
    var allocator = std.heap.c_allocator;

    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = std.io.FileOutStream.init(&stdout_file);
    stdout = &stdout_out_stream.stream;

    var stderr_file = try std.io.getStdErr();
    var stderr_out_stream = std.io.FileOutStream.init(&stderr_file);
    stderr = &stderr_out_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    if (args.len <= 1) {
        try stderr.write(usage);
        os.exit(1);
    }

    const commands = []Command {
        Command { .name = "build",       .exec = cmdBuild      },
        Command { .name = "build-exe",   .exec = cmdBuildExe   },
        Command { .name = "build-lib",   .exec = cmdBuildLib   },
        Command { .name = "build-obj",   .exec = cmdBuildObj   },
        Command { .name = "fmt",         .exec = cmdFmt        },
        Command { .name = "run",         .exec = cmdRun        },
        Command { .name = "targets",     .exec = cmdTargets    },
        Command { .name = "test",        .exec = cmdTest       },
        Command { .name = "translate-c", .exec = cmdTranslateC },
        Command { .name = "version",     .exec = cmdVersion    },
        Command { .name = "zen",         .exec = cmdZen        },

        // undocumented commands
        Command { .name = "help",        .exec = cmdHelp       },
        Command { .name = "internal",    .exec = cmdInternal   },
    };

    for (commands) |command| {
        if (mem.eql(u8, command.name, args[1])) {
            try command.exec(allocator, args[2..]);
            return;
        }
    }

    try stderr.print("unknown command: {}\n\n", args[1]);
    try stderr.write(usage);
}

// cmd:build ///////////////////////////////////////////////////////////////////////////////////////

const usage_build =
    \\usage: zig build <options>
    \\
    \\General Options:
    \\   --help                       Print this help and exit
    \\   --init                       Generate a build.zig template
    \\   --build-file [file]          Override path to build.zig
    \\   --cache-dir [path]           Override path to cache directory
    \\   --verbose                    Print commands before executing them
    \\   --prefix [path]              Override default install prefix
    \\
    \\Project-Specific Options:
    \\
    \\   Project-specific options become available when the build file is found.
    \\
    \\Advanced Options:
    \\   --build-file [file]          Override path to build.zig
    \\   --cache-dir [path]           Override path to cache directory
    \\   --verbose-tokenize           Enable compiler debug output for tokenization
    \\   --verbose-ast                Enable compiler debug output for parsing into an AST
    \\   --verbose-link               Enable compiler debug output for linking
    \\   --verbose-ir                 Enable compiler debug output for Zig IR
    \\   --verbose-llvm-ir            Enable compiler debug output for LLVM IR
    \\   --verbose-cimport            Enable compiler debug output for C imports
    \\
    \\
    ;

const args_build_spec = []Flag {
    Flag.Bool("--help"),
    Flag.Bool("--init"),
    Flag.Arg1("--build-file"),
    Flag.Arg1("--cache-dir"),
    Flag.Bool("--verbose"),
    Flag.Arg1("--prefix"),

    Flag.Arg1("--build-file"),
    Flag.Arg1("--cache-dir"),
    Flag.Bool("--verbose-tokenize"),
    Flag.Bool("--verbose-ast"),
    Flag.Bool("--verbose-link"),
    Flag.Bool("--verbose-ir"),
    Flag.Bool("--verbose-llvm-ir"),
    Flag.Bool("--verbose-cimport"),
};

const missing_build_file =
    \\No 'build.zig' file found.
    \\
    \\Initialize a 'build.zig' template file with `zig build --init`,
    \\or build an executable directly with `zig build-exe $FILENAME.zig`.
    \\
    \\See: `zig build --help` or `zig help` for more options.
    \\
    ;

fn cmdBuild(allocator: &Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_build_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_build);
        os.exit(0);
    }

    const zig_lib_dir = try introspect.resolveZigLibDir(allocator);
    defer allocator.free(zig_lib_dir);

    const zig_std_dir = try os.path.join(allocator, zig_lib_dir, "std");
    defer allocator.free(zig_std_dir);

    const special_dir = try os.path.join(allocator, zig_std_dir, "special");
    defer allocator.free(special_dir);

    const build_runner_path = try os.path.join(allocator, special_dir, "build_runner.zig");
    defer allocator.free(build_runner_path);

    const build_file = flags.single("build-file") ?? "build.zig";
    const build_file_abs = try os.path.resolve(allocator, ".", build_file);
    defer allocator.free(build_file_abs);

    const build_file_exists = os.File.exists(allocator, build_file_abs);

    if (flags.present("init")) {
        if (build_file_exists) {
            try stderr.print("build.zig already exists\n");
            os.exit(1);
        }

        // need a new scope for proper defer scope finalization on exit
        {
            const build_template_path = try os.path.join(allocator, special_dir, "build_file_template.zig");
            defer allocator.free(build_template_path);

            try os.copyFile(allocator, build_template_path, build_file_abs);
            try stderr.print("wrote build.zig template\n");
        }

        os.exit(0);
    }

    if (!build_file_exists) {
        try stderr.write(missing_build_file);
        os.exit(1);
    }

    // TODO: Invoke build.zig entrypoint directly?
    var zig_exe_path = try os.selfExePath(allocator);
    defer allocator.free(zig_exe_path);

    var build_args = ArrayList([]const u8).init(allocator);
    defer build_args.deinit();

    const build_file_basename = os.path.basename(build_file_abs);
    const build_file_dirname = os.path.dirname(build_file_abs);

    var full_cache_dir: []u8 = undefined;
    if (flags.single("cache-dir")) |cache_dir| {
        full_cache_dir = try os.path.resolve(allocator, ".", cache_dir, full_cache_dir);
    } else {
        full_cache_dir = try os.path.join(allocator, build_file_dirname, "zig-cache");
    }
    defer allocator.free(full_cache_dir);

    const path_to_build_exe = try os.path.join(allocator, full_cache_dir, "build");
    defer allocator.free(path_to_build_exe);

    try build_args.append(path_to_build_exe);
    try build_args.append(zig_exe_path);
    try build_args.append(build_file_dirname);
    try build_args.append(full_cache_dir);

    var proc = try os.ChildProcess.init(build_args.toSliceConst(), allocator);
    defer proc.deinit();

    var term = try proc.spawnAndWait();
    switch (term) {
        os.ChildProcess.Term.Exited => |status| {
            if (status != 0) {
                try stderr.print("{} exited with status {}\n", build_args.at(0), status);
                os.exit(1);
            }
        },
        os.ChildProcess.Term.Signal => |signal| {
            try stderr.print("{} killed by signal {}\n", build_args.at(0), signal);
            os.exit(1);
        },
        os.ChildProcess.Term.Stopped => |signal| {
            try stderr.print("{} stopped by signal {}\n", build_args.at(0), signal);
            os.exit(1);
        },
        os.ChildProcess.Term.Unknown => |status| {
            try stderr.print("{} encountered unknown failure {}\n", build_args.at(0), status);
            os.exit(1);
        },
    }
}

// cmd:build-exe ///////////////////////////////////////////////////////////////////////////////////

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
    \\  --release-fast               Build with optimizations on and safety off
    \\  --release-safe               Build with optimizations on and safety on
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

const args_build_generic = []Flag {
    Flag.Bool("--help"),
    Flag.Option("--color", []const []const u8 { "auto", "off", "on" }),

    Flag.ArgMergeN("--assembly", 1),
    Flag.Arg1("--cache-dir"),
    Flag.Option("--emit", []const []const u8 { "asm", "bin", "llvm-ir" }),
    Flag.Bool("--enable-timing-info"),
    Flag.Arg1("--libc-include-dir"),
    Flag.Arg1("--name"),
    Flag.Arg1("--output"),
    Flag.Arg1("--output-h"),
    // NOTE: Parsed manually after initial check
    Flag.ArgN("--pkg-begin", 2),
    Flag.Bool("--pkg-end"),
    Flag.Bool("--release-fast"),
    Flag.Bool("--release-safe"),
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

fn buildOutputType(allocator: &Allocator, args: []const []const u8, out_type: Module.Kind) !void {
    var flags = try Args.parse(allocator, args_build_generic, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_build_generic);
        os.exit(0);
    }

    var build_mode = builtin.Mode.Debug;
    if (flags.present("release-fast")) {
        build_mode = builtin.Mode.ReleaseFast;
    } else if (flags.present("release-safe")) {
        build_mode = builtin.Mode.ReleaseSafe;
    }

    var color = Module.ErrColor.Auto;
    if (flags.single("color")) |color_flag| {
        if (mem.eql(u8, color_flag, "auto")) {
            color = Module.ErrColor.Auto;
        } else if (mem.eql(u8, color_flag, "on")) {
            color = Module.ErrColor.On;
        } else if (mem.eql(u8, color_flag, "off")) {
            color = Module.ErrColor.Off;
        } else {
            unreachable;
        }
    }

    var emit_type = Module.Emit.Binary;
    if (flags.single("emit")) |emit_flag| {
        if (mem.eql(u8, emit_flag, "asm")) {
            emit_type = Module.Emit.Assembly;
        } else if (mem.eql(u8, emit_flag, "bin")) {
            emit_type = Module.Emit.Binary;
        } else if (mem.eql(u8, emit_flag, "llvm-ir")) {
            emit_type = Module.Emit.LlvmIr;
        } else {
            unreachable;
        }
    }

    var cur_pkg = try Module.CliPkg.init(allocator, "", "", null); // TODO: Need a path, name?
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

            var new_cur_pkg = try Module.CliPkg.init(allocator, new_pkg_name, new_pkg_path, cur_pkg);
            try cur_pkg.children.append(new_cur_pkg);
            cur_pkg = new_cur_pkg;
        } else if (mem.eql(u8, "--pkg-end", arg_name)) {
            if (cur_pkg.parent == null) {
                try stderr.print("encountered --pkg-end with no matching --pkg-begin\n");
                os.exit(1);
            }
            cur_pkg = ??cur_pkg.parent;
        }
    }

    if (cur_pkg.parent != null) {
        try stderr.print("unmatched --pkg-begin\n");
        os.exit(1);
    }

    var in_file: ?[]const u8 = undefined;
    switch (flags.positionals.len) {
        0 => {
            try stderr.write("--name [name] not provided and unable to infer\n");
            os.exit(1);
        },
        1 => {
            in_file = flags.positionals.at(0);
        },
        else => {
            try stderr.write("only one zig input file is accepted during build\n");
            os.exit(1);
        },
    }

    const basename = os.path.basename(??in_file);
    var it = mem.split(basename, ".");
    const root_name = it.next() ?? {
        try stderr.write("file name cannot be empty\n");
        os.exit(1);
    };

    const asm_a= flags.many("assembly");
    const obj_a = flags.many("object");
    if (in_file == null and (obj_a == null or (??obj_a).len == 0) and (asm_a == null or (??asm_a).len == 0)) {
        try stderr.write("Expected source file argument or at least one --object or --assembly argument\n");
        os.exit(1);
    }

    if (out_type == Module.Kind.Obj and (obj_a != null and (??obj_a).len != 0)) {
        try stderr.write("When building an object file, --object arguments are invalid\n");
        os.exit(1);
    }

    const zig_root_source_file = in_file;

    const full_cache_dir = os.path.resolve(allocator, ".", flags.single("cache-dir") ?? "zig-cache"[0..]) catch {
        os.exit(1);
    };
    defer allocator.free(full_cache_dir);

    const zig_lib_dir = introspect.resolveZigLibDir(allocator) catch os.exit(1);
    defer allocator.free(zig_lib_dir);

    var module =
        try Module.create(
            allocator,
            root_name,
            zig_root_source_file,
            Target.Native,
            out_type,
            build_mode,
            zig_lib_dir,
            full_cache_dir
        );
    defer module.destroy();

    module.version_major = try std.fmt.parseUnsigned(u32, flags.single("ver-major") ?? "0", 10);
    module.version_minor = try std.fmt.parseUnsigned(u32, flags.single("ver-minor") ?? "0", 10);
    module.version_patch = try std.fmt.parseUnsigned(u32, flags.single("ver-patch") ?? "0", 10);

    module.is_test = false;

    if (flags.single("linker-script")) |linker_script| {
        module.linker_script = linker_script;
    }

    module.each_lib_rpath = flags.present("each-lib-rpath");

    var clang_argv_buf = ArrayList([]const u8).init(allocator);
    defer clang_argv_buf.deinit();
    if (flags.many("mllvm")) |mllvm_flags| {
        for (mllvm_flags) |mllvm| {
            try clang_argv_buf.append("-mllvm");
            try clang_argv_buf.append(mllvm);
        }

        module.llvm_argv = mllvm_flags;
        module.clang_argv = clang_argv_buf.toSliceConst();
    }

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

    if (flags.many("library-path")) |lib_dirs| {
        module.lib_dirs = lib_dirs;
    }

    if (flags.many("framework")) |frameworks| {
        module.darwin_frameworks = frameworks;
    }

    if (flags.many("rpath")) |rpath_list| {
        module.rpath_list = rpath_list;
    }

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
        module.darwin_version_min = Module.DarwinVersionMin { .MacOS = ver };
    }
    if (flags.single("mios-version-min")) |ver| {
        module.darwin_version_min = Module.DarwinVersionMin { .Ios = ver };
    }

    module.emit_file_type = emit_type;
    if (flags.many("object")) |objects| {
        module.link_objects = objects;
    }
    if (flags.many("assembly")) |assembly_files| {
        module.assembly_files = assembly_files;
    }

    try module.build();
    try module.link(flags.single("out-file") ?? null);

    if (flags.present("print-timing-info")) {
        // codegen_print_timing_info(g, stderr);
    }

    try stderr.print("building {}: {}\n", @tagName(out_type), in_file);
}

fn cmdBuildExe(allocator: &Allocator, args: []const []const u8) !void {
    try buildOutputType(allocator, args, Module.Kind.Exe);
}

// cmd:build-lib ///////////////////////////////////////////////////////////////////////////////////

fn cmdBuildLib(allocator: &Allocator, args: []const []const u8) !void {
    try buildOutputType(allocator, args, Module.Kind.Lib);
}

// cmd:build-obj ///////////////////////////////////////////////////////////////////////////////////

fn cmdBuildObj(allocator: &Allocator, args: []const []const u8) !void {
    try buildOutputType(allocator, args, Module.Kind.Obj);
}

// cmd:fmt /////////////////////////////////////////////////////////////////////////////////////////

const usage_fmt =
    \\usage: zig fmt [file]...
    \\
    \\   Formats the input files and modifies them in-place.
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\   --keep-backups         Retain backup entries for every file
    \\
    \\
    ;

const args_fmt_spec = []Flag {
    Flag.Bool("--help"),
    Flag.Bool("--keep-backups"),
};

fn cmdFmt(allocator: &Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_fmt_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_fmt);
        os.exit(0);
    }

    if (flags.positionals.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        os.exit(1);
    }

    for (flags.positionals.toSliceConst()) |file_path| {
        var file = try os.File.openRead(allocator, file_path);
        defer file.close();

        const source_code = io.readFileAlloc(allocator, file_path) catch |err| {
            try stderr.print("unable to open '{}': {}", file_path, err);
            continue;
        };
        defer allocator.free(source_code);

        var tokenizer = std.zig.Tokenizer.init(source_code);
        var parser = std.zig.Parser.init(&tokenizer, allocator, file_path);
        defer parser.deinit();

        var tree = parser.parse() catch |err| {
            try stderr.print("error parsing file '{}': {}\n", file_path, err);
            continue;
        };
        defer tree.deinit();

        var original_file_backup = try Buffer.init(allocator, file_path);
        defer original_file_backup.deinit();
        try original_file_backup.append(".backup");

        try os.rename(allocator, file_path, original_file_backup.toSliceConst());

        try stderr.print("{}\n", file_path);

        // TODO: BufferedAtomicFile has some access problems.
        var out_file = try os.File.openWrite(allocator, file_path);
        defer out_file.close();

        var out_file_stream = io.FileOutStream.init(&out_file);
        try parser.renderSource(out_file_stream.stream, tree.root_node);

        if (!flags.present("keep-backups")) {
            try os.deleteFile(allocator, original_file_backup.toSliceConst());
        }
    }
}

// cmd:targets /////////////////////////////////////////////////////////////////////////////////////

fn cmdTargets(allocator: &Allocator, args: []const []const u8) !void {
    try stdout.write("Architectures:\n");
    {
        comptime var i: usize = 0;
        inline while (i < @memberCount(builtin.Arch)) : (i += 1) {
            comptime const arch_tag = @memberName(builtin.Arch, i);
            // NOTE: Cannot use empty string, see #918.
            comptime const native_str =
                if (comptime mem.eql(u8, arch_tag, @tagName(builtin.arch))) " (native)\n" else "\n";

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
            comptime const native_str =
                if (comptime mem.eql(u8, os_tag, @tagName(builtin.os))) " (native)\n" else "\n";

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
            comptime const native_str =
                if (comptime mem.eql(u8, environ_tag, @tagName(builtin.environ))) " (native)\n" else "\n";

            try stdout.print("  {}{}", environ_tag, native_str);
        }
    }
}

// cmd:version /////////////////////////////////////////////////////////////////////////////////////

fn cmdVersion(allocator: &Allocator, args: []const []const u8) !void {
    try stdout.print("{}\n", std.cstr.toSliceConst(c.ZIG_VERSION_STRING));
}

// cmd:test ////////////////////////////////////////////////////////////////////////////////////////

const usage_test =
    \\usage: zig test [file]...
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\
    \\
    ;

const args_test_spec = []Flag {
    Flag.Bool("--help"),
};


fn cmdTest(allocator: &Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_build_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_test);
        os.exit(0);
    }

    if (flags.positionals.len != 1) {
        try stderr.write("expected exactly one zig source file\n");
        os.exit(1);
    }

    // compile the test program into the cache and run

    // NOTE: May be overlap with buildOutput, take the shared part out.
    try stderr.print("testing file {}\n", flags.positionals.at(0));
}

// cmd:run /////////////////////////////////////////////////////////////////////////////////////////

// Run should be simple and not expose the full set of arguments provided by build-exe. If specific
// build requirements are need, the user should `build-exe` then `run` manually.
const usage_run =
    \\usage: zig run [file] -- <runtime args>
    \\
    \\Options:
    \\   --help                 Print this help and exit
    \\
    \\
    ;

const args_run_spec = []Flag {
    Flag.Bool("--help"),
};


fn cmdRun(allocator: &Allocator, args: []const []const u8) !void {
    var compile_args = args;
    var runtime_args: []const []const u8 = []const []const u8 {};

    for (args) |argv, i| {
        if (mem.eql(u8, argv, "--")) {
            compile_args = args[0..i];
            runtime_args = args[i+1..];
            break;
        }
    }
    var flags = try Args.parse(allocator, args_run_spec, compile_args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_run);
        os.exit(0);
    }

    if (flags.positionals.len != 1) {
        try stderr.write("expected exactly one zig source file\n");
        os.exit(1);
    }

    try stderr.print("runtime args:\n");
    for (runtime_args) |cargs| {
        try stderr.print("{}\n", cargs);
    }
}

// cmd:translate-c /////////////////////////////////////////////////////////////////////////////////

const usage_translate_c =
    \\usage: zig translate-c [file]
    \\
    \\Options:
    \\  --help                       Print this help and exit
    \\  --enable-timing-info         Print timing diagnostics
    \\  --output [path]              Output file to write generated zig file (default: stdout)
    \\
    \\
    ;

const args_translate_c_spec = []Flag {
    Flag.Bool("--help"),
    Flag.Bool("--enable-timing-info"),
    Flag.Arg1("--libc-include-dir"),
    Flag.Arg1("--output"),
};

fn cmdTranslateC(allocator: &Allocator, args: []const []const u8) !void {
    var flags = try Args.parse(allocator, args_translate_c_spec, args);
    defer flags.deinit();

    if (flags.present("help")) {
        try stderr.write(usage_translate_c);
        os.exit(0);
    }

    if (flags.positionals.len != 1) {
        try stderr.write("expected exactly one c source file\n");
        os.exit(1);
    }

    // set up codegen

    const zig_root_source_file = null;

    // NOTE: translate-c shouldn't require setting up the full codegen instance as it does in
    // the C++ compiler.

    // codegen_create(g);
    // codegen_set_out_name(g, null);
    // codegen_translate_c(g, flags.positional.at(0))

    var output_stream = stdout;
    if (flags.single("output")) |output_file| {
        var file = try os.File.openWrite(allocator, output_file);
        defer file.close();

        var file_stream = io.FileOutStream.init(&file);
        // TODO: Not being set correctly, still stdout
        output_stream = &file_stream.stream;
    }

    // ast_render(g, output_stream, g->root_import->root, 4);
    try output_stream.write("pub const example = 10;\n");

    if (flags.present("enable-timing-info")) {
        // codegen_print_timing_info(g, stdout);
        try stderr.write("printing timing info for translate-c\n");
    }
}

// cmd:help ////////////////////////////////////////////////////////////////////////////////////////

fn cmdHelp(allocator: &Allocator, args: []const []const u8) !void {
    try stderr.write(usage);
}

// cmd:zen /////////////////////////////////////////////////////////////////////////////////////////

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

fn cmdZen(allocator: &Allocator, args: []const []const u8) !void {
    try stdout.write(info_zen);
}

// cmd:internal ////////////////////////////////////////////////////////////////////////////////////

const usage_internal =
    \\usage: zig internal [subcommand]
    \\
    \\Sub-Commands:
    \\  build-info                   Print static compiler build-info
    \\
    \\
    ;

fn cmdInternal(allocator: &Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try stderr.write(usage_internal);
        os.exit(1);
    }

    const sub_commands = []Command {
        Command { .name = "build-info", .exec = cmdInternalBuildInfo },
    };

    for (sub_commands) |sub_command| {
        if (mem.eql(u8, sub_command.name, args[0])) {
            try sub_command.exec(allocator, args[1..]);
            return;
        }
    }

    try stderr.print("unknown sub command: {}\n\n", args[0]);
    try stderr.write(usage_internal);
}

fn cmdInternalBuildInfo(allocator: &Allocator, args: []const []const u8) !void {
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
