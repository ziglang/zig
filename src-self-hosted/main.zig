const std = @import("std");
const builtin = @import("builtin");

const event = std.event;
const os = std.os;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const c = @import("c.zig");
const introspect = @import("introspect.zig");
const ZigCompiler = @import("compilation.zig").ZigCompiler;
const Compilation = @import("compilation.zig").Compilation;
const Target = std.Target;
const errmsg = @import("errmsg.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;

var stderr_file: fs.File = undefined;
var stderr: *io.OutStream(fs.File.WriteError) = undefined;
var stdout: *io.OutStream(fs.File.WriteError) = undefined;

pub const io_mode = .evented;

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
    exec: async fn (*Allocator, []const []const u8) anyerror!void,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    stdout = &std.io.getStdOut().outStream().stream;

    stderr_file = std.io.getStdErr();
    stderr = &stderr_file.outStream().stream;

    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);

    if (args.len <= 1) {
        try stderr.write("expected command argument\n\n");
        try stderr.write(usage);
        process.exit(1);
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (mem.eql(u8, cmd, "build-exe")) {
        return buildOutputType(allocator, cmd_args, .Exe);
    } else if (mem.eql(u8, cmd, "build-lib")) {
        return buildOutputType(allocator, cmd_args, .Lib);
    } else if (mem.eql(u8, cmd, "build-obj")) {
        return buildOutputType(allocator, cmd_args, .Obj);
    } else if (mem.eql(u8, cmd, "fmt")) {
        return cmdFmt(allocator, cmd_args);
    } else if (mem.eql(u8, cmd, "libc")) {
        return cmdLibC(allocator, cmd_args);
    } else if (mem.eql(u8, cmd, "targets")) {
        const info = try std.zig.system.NativeTargetInfo.detect(allocator);
        defer info.deinit(allocator);
        return @import("print_targets.zig").cmdTargets(allocator, cmd_args, stdout, info.target);
    } else if (mem.eql(u8, cmd, "version")) {
        return cmdVersion(allocator, cmd_args);
    } else if (mem.eql(u8, cmd, "zen")) {
        return cmdZen(allocator, cmd_args);
    } else if (mem.eql(u8, cmd, "help")) {
        return cmdHelp(allocator, cmd_args);
    } else if (mem.eql(u8, cmd, "internal")) {
        return cmdInternal(allocator, cmd_args);
    } else {
        try stderr.print("unknown command: {}\n\n", .{args[1]});
        try stderr.write(usage);
        process.exit(1);
    }
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
    \\  --eh-frame-hdr               enable C++ exception handling by passing --eh-frame-hdr to linker
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
    \\  -framework [name]            (darwin) link against framework
    \\  -mios-version-min [ver]      (darwin) set iOS deployment target
    \\  -mmacosx-version-min [ver]   (darwin) set Mac OS X deployment target
    \\  --ver-major [ver]            Dynamic library semver major version
    \\  --ver-minor [ver]            Dynamic library semver minor version
    \\  --ver-patch [ver]            Dynamic library semver patch version
    \\
    \\
;

fn buildOutputType(allocator: *Allocator, args: []const []const u8, out_type: Compilation.Kind) !void {
    var color: errmsg.Color = .Auto;
    var build_mode: std.builtin.Mode = .Debug;
    var emit_bin = true;
    var emit_asm = false;
    var emit_llvm_ir = false;
    var emit_h = false;
    var provided_name: ?[]const u8 = null;
    var is_dynamic = false;
    var root_src_file: ?[]const u8 = null;
    var libc_arg: ?[]const u8 = null;
    var version: std.builtin.Version = .{ .major = 0, .minor = 0, .patch = 0 };
    var linker_script: ?[]const u8 = null;
    var strip = false;
    var verbose_tokenize = false;
    var verbose_ast_tree = false;
    var verbose_ast_fmt = false;
    var verbose_link = false;
    var verbose_ir = false;
    var verbose_llvm_ir = false;
    var verbose_cimport = false;
    var linker_rdynamic = false;
    var link_eh_frame_hdr = false;
    var macosx_version_min: ?[]const u8 = null;
    var ios_version_min: ?[]const u8 = null;

    var assembly_files = ArrayList([]const u8).init(allocator);
    defer assembly_files.deinit();

    var link_objects = ArrayList([]const u8).init(allocator);
    defer link_objects.deinit();

    var clang_argv_buf = ArrayList([]const u8).init(allocator);
    defer clang_argv_buf.deinit();

    var mllvm_flags = ArrayList([]const u8).init(allocator);
    defer mllvm_flags.deinit();

    var cur_pkg = try CliPkg.init(allocator, "", "", null);
    defer cur_pkg.deinit();

    var system_libs = ArrayList([]const u8).init(allocator);
    defer system_libs.deinit();

    var c_src_files = ArrayList([]const u8).init(allocator);
    defer c_src_files.deinit();

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "--help")) {
                    try stdout.write(usage_build_generic);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected [auto|on|off] after --color\n");
                        process.exit(1);
                    }
                    i += 1;
                    const next_arg = args[i];
                    if (mem.eql(u8, next_arg, "auto")) {
                        color = .Auto;
                    } else if (mem.eql(u8, next_arg, "on")) {
                        color = .On;
                    } else if (mem.eql(u8, next_arg, "off")) {
                        color = .Off;
                    } else {
                        try stderr.print("expected [auto|on|off] after --color, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--mode")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode\n");
                        process.exit(1);
                    }
                    i += 1;
                    const next_arg = args[i];
                    if (mem.eql(u8, next_arg, "Debug")) {
                        build_mode = .Debug;
                    } else if (mem.eql(u8, next_arg, "ReleaseSafe")) {
                        build_mode = .ReleaseSafe;
                    } else if (mem.eql(u8, next_arg, "ReleaseFast")) {
                        build_mode = .ReleaseFast;
                    } else if (mem.eql(u8, next_arg, "ReleaseSmall")) {
                        build_mode = .ReleaseSmall;
                    } else {
                        try stderr.print("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--name")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --name\n");
                        process.exit(1);
                    }
                    i += 1;
                    provided_name = args[i];
                } else if (mem.eql(u8, arg, "--ver-major")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --ver-major\n");
                        process.exit(1);
                    }
                    i += 1;
                    version.major = try std.fmt.parseInt(u32, args[i], 10);
                } else if (mem.eql(u8, arg, "--ver-minor")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --ver-minor\n");
                        process.exit(1);
                    }
                    i += 1;
                    version.minor = try std.fmt.parseInt(u32, args[i], 10);
                } else if (mem.eql(u8, arg, "--ver-patch")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --ver-patch\n");
                        process.exit(1);
                    }
                    i += 1;
                    version.patch = try std.fmt.parseInt(u32, args[i], 10);
                } else if (mem.eql(u8, arg, "--linker-script")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --linker-script\n");
                        process.exit(1);
                    }
                    i += 1;
                    linker_script = args[i];
                } else if (mem.eql(u8, arg, "--libc")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after --libc\n");
                        process.exit(1);
                    }
                    i += 1;
                    libc_arg = args[i];
                } else if (mem.eql(u8, arg, "-mllvm")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after -mllvm\n");
                        process.exit(1);
                    }
                    i += 1;
                    try clang_argv_buf.append("-mllvm");
                    try clang_argv_buf.append(args[i]);

                    try mllvm_flags.append(args[i]);
                } else if (mem.eql(u8, arg, "-mmacosx-version-min")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after -mmacosx-version-min\n");
                        process.exit(1);
                    }
                    i += 1;
                    macosx_version_min = args[i];
                } else if (mem.eql(u8, arg, "-mios-version-min")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected parameter after -mios-version-min\n");
                        process.exit(1);
                    }
                    i += 1;
                    ios_version_min = args[i];
                } else if (mem.eql(u8, arg, "-femit-bin")) {
                    emit_bin = true;
                } else if (mem.eql(u8, arg, "-fno-emit-bin")) {
                    emit_bin = false;
                } else if (mem.eql(u8, arg, "-femit-asm")) {
                    emit_asm = true;
                } else if (mem.eql(u8, arg, "-fno-emit-asm")) {
                    emit_asm = false;
                } else if (mem.eql(u8, arg, "-femit-llvm-ir")) {
                    emit_llvm_ir = true;
                } else if (mem.eql(u8, arg, "-fno-emit-llvm-ir")) {
                    emit_llvm_ir = false;
                } else if (mem.eql(u8, arg, "-dynamic")) {
                    is_dynamic = true;
                } else if (mem.eql(u8, arg, "--strip")) {
                    strip = true;
                } else if (mem.eql(u8, arg, "--verbose-tokenize")) {
                    verbose_tokenize = true;
                } else if (mem.eql(u8, arg, "--verbose-ast-tree")) {
                    verbose_ast_tree = true;
                } else if (mem.eql(u8, arg, "--verbose-ast-fmt")) {
                    verbose_ast_fmt = true;
                } else if (mem.eql(u8, arg, "--verbose-link")) {
                    verbose_link = true;
                } else if (mem.eql(u8, arg, "--verbose-ir")) {
                    verbose_ir = true;
                } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                    verbose_llvm_ir = true;
                } else if (mem.eql(u8, arg, "--eh-frame-hdr")) {
                    link_eh_frame_hdr = true;
                } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                    verbose_cimport = true;
                } else if (mem.eql(u8, arg, "-rdynamic")) {
                    linker_rdynamic = true;
                } else if (mem.eql(u8, arg, "--pkg-begin")) {
                    if (i + 2 >= args.len) {
                        try stderr.write("expected [name] [path] after --pkg-begin\n");
                        process.exit(1);
                    }
                    i += 1;
                    const new_pkg_name = args[i];
                    i += 1;
                    const new_pkg_path = args[i];

                    var new_cur_pkg = try CliPkg.init(allocator, new_pkg_name, new_pkg_path, cur_pkg);
                    try cur_pkg.children.append(new_cur_pkg);
                    cur_pkg = new_cur_pkg;
                } else if (mem.eql(u8, arg, "--pkg-end")) {
                    if (cur_pkg.parent) |parent| {
                        cur_pkg = parent;
                    } else {
                        try stderr.write("encountered --pkg-end with no matching --pkg-begin\n");
                        process.exit(1);
                    }
                } else if (mem.startsWith(u8, arg, "-l")) {
                    try system_libs.append(arg[2..]);
                } else {
                    try stderr.print("unrecognized parameter: '{}'", .{arg});
                    process.exit(1);
                }
            } else if (mem.endsWith(u8, arg, ".s")) {
                try assembly_files.append(arg);
            } else if (mem.endsWith(u8, arg, ".o") or
                mem.endsWith(u8, arg, ".obj") or
                mem.endsWith(u8, arg, ".a") or
                mem.endsWith(u8, arg, ".lib"))
            {
                try link_objects.append(arg);
            } else if (mem.endsWith(u8, arg, ".c") or
                mem.endsWith(u8, arg, ".cpp"))
            {
                try c_src_files.append(arg);
            } else if (mem.endsWith(u8, arg, ".zig")) {
                if (root_src_file) |other| {
                    try stderr.print("found another zig file '{}' after root source file '{}'", .{
                        arg,
                        other,
                    });
                    process.exit(1);
                } else {
                    root_src_file = arg;
                }
            } else {
                try stderr.print("unrecognized file extension of parameter '{}'", .{arg});
            }
        }
    }

    if (cur_pkg.parent != null) {
        try stderr.print("unmatched --pkg-begin\n", .{});
        process.exit(1);
    }

    const root_name = if (provided_name) |n| n else blk: {
        if (root_src_file) |file| {
            const basename = fs.path.basename(file);
            var it = mem.separate(basename, ".");
            break :blk it.next() orelse basename;
        } else {
            try stderr.write("--name [name] not provided and unable to infer\n");
            process.exit(1);
        }
    };

    if (root_src_file == null and link_objects.len == 0 and assembly_files.len == 0) {
        try stderr.write("Expected source file argument or at least one --object or --assembly argument\n");
        process.exit(1);
    }

    if (out_type == Compilation.Kind.Obj and link_objects.len != 0) {
        try stderr.write("When building an object file, --object arguments are invalid\n");
        process.exit(1);
    }

    try ZigCompiler.setLlvmArgv(allocator, mllvm_flags.toSliceConst());

    const zig_lib_dir = introspect.resolveZigLibDir(allocator) catch process.exit(1);
    defer allocator.free(zig_lib_dir);

    var override_libc: LibCInstallation = undefined;

    var zig_compiler = try ZigCompiler.init(allocator);
    defer zig_compiler.deinit();

    var comp = try Compilation.create(
        &zig_compiler,
        root_name,
        root_src_file,
        Target.Native,
        out_type,
        build_mode,
        !is_dynamic,
        zig_lib_dir,
    );
    defer comp.destroy();

    if (libc_arg) |libc_path| {
        parseLibcPaths(allocator, &override_libc, libc_path);
        comp.override_libc = &override_libc;
    }

    for (system_libs.toSliceConst()) |lib| {
        _ = try comp.addLinkLib(lib, true);
    }

    comp.version = version;
    comp.is_test = false;
    comp.linker_script = linker_script;
    comp.clang_argv = clang_argv_buf.toSliceConst();
    comp.strip = strip;

    comp.verbose_tokenize = verbose_tokenize;
    comp.verbose_ast_tree = verbose_ast_tree;
    comp.verbose_ast_fmt = verbose_ast_fmt;
    comp.verbose_link = verbose_link;
    comp.verbose_ir = verbose_ir;
    comp.verbose_llvm_ir = verbose_llvm_ir;
    comp.verbose_cimport = verbose_cimport;

    comp.link_eh_frame_hdr = link_eh_frame_hdr;

    comp.err_color = color;

    comp.linker_rdynamic = linker_rdynamic;

    if (macosx_version_min != null and ios_version_min != null) {
        try stderr.write("-mmacosx-version-min and -mios-version-min options not allowed together\n");
        process.exit(1);
    }

    if (macosx_version_min) |ver| {
        comp.darwin_version_min = Compilation.DarwinVersionMin{ .MacOS = ver };
    }
    if (ios_version_min) |ver| {
        comp.darwin_version_min = Compilation.DarwinVersionMin{ .Ios = ver };
    }

    comp.emit_bin = emit_bin;
    comp.emit_asm = emit_asm;
    comp.emit_llvm_ir = emit_llvm_ir;
    comp.emit_h = emit_h;
    comp.assembly_files = assembly_files.toSliceConst();
    comp.link_objects = link_objects.toSliceConst();

    comp.start();
    processBuildEvents(comp, color);
}

fn processBuildEvents(comp: *Compilation, color: errmsg.Color) void {
    var count: usize = 0;
    while (!comp.cancelled) {
        const build_event = comp.events.get();
        count += 1;

        switch (build_event) {
            .Ok => {
                stderr.print("Build {} succeeded\n", .{count}) catch process.exit(1);
            },
            .Error => |err| {
                stderr.print("Build {} failed: {}\n", .{ count, @errorName(err) }) catch process.exit(1);
            },
            .Fail => |msgs| {
                stderr.print("Build {} compile errors:\n", .{count}) catch process.exit(1);
                for (msgs) |msg| {
                    defer msg.destroy();
                    msg.printToFile(stderr_file, color) catch process.exit(1);
                }
            },
        }
    }
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

const Fmt = struct {
    seen: event.Locked(SeenMap),
    any_error: bool,
    color: errmsg.Color,
    allocator: *Allocator,

    const SeenMap = std.StringHashMap(void);
};

fn parseLibcPaths(allocator: *Allocator, libc: *LibCInstallation, libc_paths_file: []const u8) void {
    libc.parse(allocator, libc_paths_file, stderr) catch |err| {
        stderr.print("Unable to parse libc path file '{}': {}.\n" ++
            "Try running `zig libc` to see an example for the native target.\n", .{
            libc_paths_file,
            @errorName(err),
        }) catch {};
        process.exit(1);
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
            try stderr.print("unexpected extra parameter: {}\n", .{args[1]});
            process.exit(1);
        },
    }

    var zig_compiler = try ZigCompiler.init(allocator);
    defer zig_compiler.deinit();

    const libc = zig_compiler.getNativeLibC() catch |err| {
        stderr.print("unable to find libc: {}\n", .{@errorName(err)}) catch {};
        process.exit(1);
    };
    libc.render(stdout) catch process.exit(1);
}

fn cmdFmt(allocator: *Allocator, args: []const []const u8) !void {
    var color: errmsg.Color = .Auto;
    var stdin_flag: bool = false;
    var check_flag: bool = false;
    var input_files = ArrayList([]const u8).init(allocator);

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "--help")) {
                    try stdout.write(usage_fmt);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        try stderr.write("expected [auto|on|off] after --color\n");
                        process.exit(1);
                    }
                    i += 1;
                    const next_arg = args[i];
                    if (mem.eql(u8, next_arg, "auto")) {
                        color = .Auto;
                    } else if (mem.eql(u8, next_arg, "on")) {
                        color = .On;
                    } else if (mem.eql(u8, next_arg, "off")) {
                        color = .Off;
                    } else {
                        try stderr.print("expected [auto|on|off] after --color, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--stdin")) {
                    stdin_flag = true;
                } else if (mem.eql(u8, arg, "--check")) {
                    check_flag = true;
                } else {
                    try stderr.print("unrecognized parameter: '{}'", .{arg});
                    process.exit(1);
                }
            } else {
                try input_files.append(arg);
            }
        }
    }

    if (stdin_flag) {
        if (input_files.len != 0) {
            try stderr.write("cannot use --stdin with positional arguments\n");
            process.exit(1);
        }

        var stdin_file = io.getStdIn();
        var stdin = stdin_file.inStream();

        const source_code = try stdin.stream.readAllAlloc(allocator, max_src_size);
        defer allocator.free(source_code);

        const tree = std.zig.parse(allocator, source_code) catch |err| {
            try stderr.print("error parsing stdin: {}\n", .{err});
            process.exit(1);
        };
        defer tree.deinit();

        var error_it = tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            const msg = try errmsg.Msg.createFromParseError(allocator, parse_error, tree, "<stdin>");
            defer msg.destroy();

            try msg.printToFile(stderr_file, color);
        }
        if (tree.errors.len != 0) {
            process.exit(1);
        }
        if (check_flag) {
            const anything_changed = try std.zig.render(allocator, io.null_out_stream, tree);
            const code: u8 = if (anything_changed) 1 else 0;
            process.exit(code);
        }

        _ = try std.zig.render(allocator, stdout, tree);
        return;
    }

    if (input_files.len == 0) {
        try stderr.write("expected at least one source file argument\n");
        process.exit(1);
    }

    var fmt = Fmt{
        .allocator = allocator,
        .seen = event.Locked(Fmt.SeenMap).init(Fmt.SeenMap.init(allocator)),
        .any_error = false,
        .color = color,
    };

    var group = event.Group(FmtError!void).init(allocator);
    for (input_files.toSliceConst()) |file_path| {
        try group.call(fmtPath, .{ &fmt, file_path, check_flag });
    }
    try group.wait();
    if (fmt.any_error) {
        process.exit(1);
    }
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
    CurrentWorkingDirectoryUnlinked,
} || fs.File.OpenError;

async fn fmtPath(fmt: *Fmt, file_path_ref: []const u8, check_mode: bool) FmtError!void {
    const file_path = try std.mem.dupe(fmt.allocator, u8, file_path_ref);
    defer fmt.allocator.free(file_path);

    {
        const held = fmt.seen.acquire();
        defer held.release();

        if (try held.value.put(file_path, {})) |_| return;
    }

    const source_code = fs.cwd().readFileAlloc(
        fmt.allocator,
        file_path,
        max_src_size,
    ) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => {
            var dir = try fs.cwd().openDirList(file_path);
            defer dir.close();

            var group = event.Group(FmtError!void).init(fmt.allocator);
            var it = dir.iterate();
            while (try it.next()) |entry| {
                if (entry.kind == .Directory or mem.endsWith(u8, entry.name, ".zig")) {
                    const full_path = try fs.path.join(fmt.allocator, &[_][]const u8{ file_path, entry.name });
                    @panic("TODO https://github.com/ziglang/zig/issues/3777");
                    // try group.call(fmtPath, .{fmt, full_path, check_mode});
                }
            }
            return group.wait();
        },
        else => {
            // TODO lock stderr printing
            try stderr.print("unable to open '{}': {}\n", .{ file_path, err });
            fmt.any_error = true;
            return;
        },
    };
    defer fmt.allocator.free(source_code);

    const tree = std.zig.parse(fmt.allocator, source_code) catch |err| {
        try stderr.print("error parsing file '{}': {}\n", .{ file_path, err });
        fmt.any_error = true;
        return;
    };
    defer tree.deinit();

    var error_it = tree.errors.iterator(0);
    while (error_it.next()) |parse_error| {
        const msg = try errmsg.Msg.createFromParseError(fmt.allocator, parse_error, tree, file_path);
        defer fmt.allocator.destroy(msg);

        try msg.printToFile(stderr_file, fmt.color);
    }
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (check_mode) {
        const anything_changed = try std.zig.render(fmt.allocator, io.null_out_stream, tree);
        if (anything_changed) {
            try stderr.print("{}\n", .{file_path});
            fmt.any_error = true;
        }
    } else {
        // TODO make this evented
        const baf = try io.BufferedAtomicFile.create(fmt.allocator, file_path);
        defer baf.destroy();

        const anything_changed = try std.zig.render(fmt.allocator, baf.stream(), tree);
        if (anything_changed) {
            try stderr.print("{}\n", .{file_path});
            try baf.finish();
        }
    }
}

fn cmdVersion(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.print("{}\n", .{c.ZIG_VERSION_STRING});
}

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
        process.exit(1);
    }

    const sub_commands = [_]Command{Command{
        .name = "build-info",
        .exec = cmdInternalBuildInfo,
    }};

    inline for (sub_commands) |sub_command| {
        if (mem.eql(u8, sub_command.name, args[0])) {
            var frame = try allocator.create(@Frame(sub_command.exec));
            defer allocator.destroy(frame);
            frame.* = async sub_command.exec(allocator, args[1..]);
            return await frame;
        }
    }

    try stderr.print("unknown sub command: {}\n\n", .{args[0]});
    try stderr.write(usage_internal);
}

fn cmdInternalBuildInfo(allocator: *Allocator, args: []const []const u8) !void {
    try stdout.print(
        \\ZIG_CMAKE_BINARY_DIR {}
        \\ZIG_CXX_COMPILER     {}
        \\ZIG_LLD_INCLUDE_PATH {}
        \\ZIG_LLD_LIBRARIES    {}
        \\ZIG_LLVM_CONFIG_EXE  {}
        \\ZIG_DIA_GUIDS_LIB    {}
        \\
    , .{
        c.ZIG_CMAKE_BINARY_DIR,
        c.ZIG_CXX_COMPILER,
        c.ZIG_LLD_INCLUDE_PATH,
        c.ZIG_LLD_LIBRARIES,
        c.ZIG_LLVM_CONFIG_EXE,
        c.ZIG_DIA_GUIDS_LIB,
    });
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
