const std = @import("std");
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ast = std.zig.ast;
const Module = @import("Module.zig");
const link = @import("link.zig");
const Package = @import("Package.zig");
const zir = @import("zir.zig");

// TODO Improve async I/O enough that we feel comfortable doing this.
//pub const io_mode = .evented;

pub const max_src_size = 2 * 1024 * 1024 * 1024; // 2 GiB

pub const Color = enum {
    Auto,
    Off,
    On,
};

const usage =
    \\Usage: zig [command] [options]
    \\
    \\Commands:
    \\
    \\  build-exe  [source]      Create executable from source or object files
    \\  build-lib  [source]      Create library from source or object files
    \\  build-obj  [source]      Create object from source or assembly
    \\  fmt        [source]      Parse file and render in canonical zig format
    \\  targets                  List available compilation targets
    \\  version                  Print version number and exit
    \\  zen                      Print zen of zig and exit
    \\
    \\
;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@enumToInt(level) > @enumToInt(std.log.level))
        return;

    const scope_prefix = "(" ++ switch (scope) {
        // Uncomment to hide logs
        //.compiler,
        .module,
        .liveness,
        .link,
        => return,

        else => @tagName(scope),
    } ++ "): ";

    const prefix = "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    std.debug.print(prefix ++ format, args);
}

pub fn main() !void {
    // TODO general purpose allocator in the zig std lib
    const gpa = if (std.builtin.link_libc) std.heap.c_allocator else std.heap.page_allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = &arena_instance.allocator;

    const args = try process.argsAlloc(arena);

    if (args.len <= 1) {
        std.debug.print("expected command argument\n\n{}", .{usage});
        process.exit(1);
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (mem.eql(u8, cmd, "build-exe")) {
        return buildOutputType(gpa, arena, cmd_args, .Exe);
    } else if (mem.eql(u8, cmd, "build-lib")) {
        return buildOutputType(gpa, arena, cmd_args, .Lib);
    } else if (mem.eql(u8, cmd, "build-obj")) {
        return buildOutputType(gpa, arena, cmd_args, .Obj);
    } else if (mem.eql(u8, cmd, "fmt")) {
        return cmdFmt(gpa, cmd_args);
    } else if (mem.eql(u8, cmd, "targets")) {
        const info = try std.zig.system.NativeTargetInfo.detect(arena, .{});
        const stdout = io.getStdOut().outStream();
        return @import("print_targets.zig").cmdTargets(arena, cmd_args, stdout, info.target);
    } else if (mem.eql(u8, cmd, "version")) {
        // Need to set up the build script to give the version as a comptime value.
        std.debug.print("TODO version command not implemented yet\n", .{});
        return error.Unimplemented;
    } else if (mem.eql(u8, cmd, "zen")) {
        try io.getStdOut().writeAll(info_zen);
    } else if (mem.eql(u8, cmd, "help")) {
        try io.getStdOut().writeAll(usage);
    } else {
        std.debug.print("unknown command: {}\n\n{}", .{ args[1], usage });
        process.exit(1);
    }
}

const usage_build_generic =
    \\Usage: zig build-exe <options> [files]
    \\       zig build-lib <options> [files]
    \\       zig build-obj <options> [files]
    \\
    \\Supported file types:
    \\                    .zig    Zig source code
    \\                    .zir    Zig Intermediate Representation code
    \\     (planned)        .o    ELF object file
    \\     (planned)        .o    MACH-O (macOS) object file
    \\     (planned)      .obj    COFF (Windows) object file
    \\     (planned)      .lib    COFF (Windows) static library
    \\     (planned)        .a    ELF static library
    \\     (planned)       .so    ELF shared object (dynamic link)
    \\     (planned)      .dll    Windows Dynamic Link Library
    \\     (planned)    .dylib    MACH-O (macOS) dynamic library
    \\     (planned)        .s    Target-specific assembly source code
    \\     (planned)        .S    Assembly with C preprocessor (requires LLVM extensions)
    \\     (planned)        .c    C source code (requires LLVM extensions)
    \\     (planned)      .cpp    C++ source code (requires LLVM extensions)
    \\                            Other C++ extensions: .C .cc .cxx
    \\
    \\General Options:
    \\  -h, --help                Print this help and exit
    \\  --watch                   Enable compiler REPL
    \\  --color [auto|off|on]     Enable or disable colored error messages
    \\  -femit-bin[=path]         (default) output machine code
    \\  -fno-emit-bin             Do not output machine code
    \\
    \\Compile Options:
    \\  -target [name]            <arch><sub>-<os>-<abi> see the targets command
    \\  -mcpu [cpu]               Specify target CPU and feature set
    \\  --name [name]             Override output name
    \\  --mode [mode]             Set the build mode
    \\    Debug                   (default) optimizations off, safety on
    \\    ReleaseFast             optimizations on, safety off
    \\    ReleaseSafe             optimizations on, safety on
    \\    ReleaseSmall            optimize for small binary, safety off
    \\  --dynamic                 Force output to be dynamically linked
    \\  --strip                   Exclude debug symbols
    \\
    \\Link Options:
    \\  -l[lib], --library [lib]  Link against system library
    \\  --dynamic-linker [path]   Set the dynamic interpreter path (usually ld.so)
    \\  --version [ver]           Dynamic library semver
    \\
    \\Debug Options (Zig Compiler Development):
    \\  -ftime-report             Print timing diagnostics
    \\  --debug-tokenize          verbose tokenization
    \\  --debug-ast-tree          verbose parsing into an AST (tree view)
    \\  --debug-ast-fmt           verbose parsing into an AST (render source)
    \\  --debug-ir                verbose Zig IR
    \\  --debug-link              verbose linking
    \\  --debug-codegen           verbose machine code generation
    \\
;

const Emit = union(enum) {
    no,
    yes_default_path,
    yes: []const u8,
};

fn buildOutputType(
    gpa: *Allocator,
    arena: *Allocator,
    args: []const []const u8,
    output_mode: std.builtin.OutputMode,
) !void {
    var color: Color = .Auto;
    var build_mode: std.builtin.Mode = .Debug;
    var provided_name: ?[]const u8 = null;
    var link_mode: ?std.builtin.LinkMode = null;
    var root_src_file: ?[]const u8 = null;
    var version: std.builtin.Version = .{ .major = 0, .minor = 0, .patch = 0 };
    var strip = false;
    var watch = false;
    var debug_tokenize = false;
    var debug_ast_tree = false;
    var debug_ast_fmt = false;
    var debug_link = false;
    var debug_ir = false;
    var debug_codegen = false;
    var time_report = false;
    var emit_bin: Emit = .yes_default_path;
    var emit_zir: Emit = .no;
    var target_arch_os_abi: []const u8 = "native";
    var target_mcpu: ?[]const u8 = null;
    var target_dynamic_linker: ?[]const u8 = null;
    var object_format: ?std.builtin.ObjectFormat = null;

    var system_libs = std.ArrayList([]const u8).init(gpa);
    defer system_libs.deinit();

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    try io.getStdOut().writeAll(usage_build_generic);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected [auto|on|off] after --color\n", .{});
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
                        std.debug.print("expected [auto|on|off] after --color, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--mode")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode\n", .{});
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
                        std.debug.print("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--name")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after --name\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    provided_name = args[i];
                } else if (mem.eql(u8, arg, "--library")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after --library\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    try system_libs.append(args[i]);
                } else if (mem.eql(u8, arg, "--version")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after --version\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    version = std.builtin.Version.parse(args[i]) catch |err| {
                        std.debug.print("unable to parse --version '{}': {}\n", .{ args[i], @errorName(err) });
                        process.exit(1);
                    };
                } else if (mem.eql(u8, arg, "-target")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after -target\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    target_arch_os_abi = args[i];
                } else if (mem.eql(u8, arg, "-mcpu")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after -mcpu\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    target_mcpu = args[i];
                } else if (mem.eql(u8, arg, "--c")) {
                    if (object_format) |old| {
                        std.debug.print("attempted to override object format {} with C\n", .{old});
                        process.exit(1);
                    }
                    object_format = .c;
                } else if (mem.startsWith(u8, arg, "-mcpu=")) {
                    target_mcpu = arg["-mcpu=".len..];
                } else if (mem.eql(u8, arg, "--dynamic-linker")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected parameter after --dynamic-linker\n", .{});
                        process.exit(1);
                    }
                    i += 1;
                    target_dynamic_linker = args[i];
                } else if (mem.eql(u8, arg, "--watch")) {
                    watch = true;
                } else if (mem.eql(u8, arg, "-ftime-report")) {
                    time_report = true;
                } else if (mem.eql(u8, arg, "-femit-bin")) {
                    emit_bin = .yes_default_path;
                } else if (mem.startsWith(u8, arg, "-femit-bin=")) {
                    emit_bin = .{ .yes = arg["-femit-bin=".len..] };
                } else if (mem.eql(u8, arg, "-fno-emit-bin")) {
                    emit_bin = .no;
                } else if (mem.eql(u8, arg, "-femit-zir")) {
                    emit_zir = .yes_default_path;
                } else if (mem.startsWith(u8, arg, "-femit-zir=")) {
                    emit_zir = .{ .yes = arg["-femit-zir=".len..] };
                } else if (mem.eql(u8, arg, "-fno-emit-zir")) {
                    emit_zir = .no;
                } else if (mem.eql(u8, arg, "-dynamic")) {
                    link_mode = .Dynamic;
                } else if (mem.eql(u8, arg, "-static")) {
                    link_mode = .Static;
                } else if (mem.eql(u8, arg, "--strip")) {
                    strip = true;
                } else if (mem.eql(u8, arg, "--debug-tokenize")) {
                    debug_tokenize = true;
                } else if (mem.eql(u8, arg, "--debug-ast-tree")) {
                    debug_ast_tree = true;
                } else if (mem.eql(u8, arg, "--debug-ast-fmt")) {
                    debug_ast_fmt = true;
                } else if (mem.eql(u8, arg, "--debug-link")) {
                    debug_link = true;
                } else if (mem.eql(u8, arg, "--debug-ir")) {
                    debug_ir = true;
                } else if (mem.eql(u8, arg, "--debug-codegen")) {
                    debug_codegen = true;
                } else if (mem.startsWith(u8, arg, "-l")) {
                    try system_libs.append(arg[2..]);
                } else {
                    std.debug.print("unrecognized parameter: '{}'", .{arg});
                    process.exit(1);
                }
            } else if (mem.endsWith(u8, arg, ".s") or mem.endsWith(u8, arg, ".S")) {
                std.debug.print("assembly files not supported yet", .{});
                process.exit(1);
            } else if (mem.endsWith(u8, arg, ".o") or
                mem.endsWith(u8, arg, ".obj") or
                mem.endsWith(u8, arg, ".a") or
                mem.endsWith(u8, arg, ".lib"))
            {
                std.debug.print("object files and static libraries not supported yet", .{});
                process.exit(1);
            } else if (mem.endsWith(u8, arg, ".c") or
                mem.endsWith(u8, arg, ".cpp"))
            {
                std.debug.print("compilation of C and C++ source code requires LLVM extensions which are not implemented yet", .{});
                process.exit(1);
            } else if (mem.endsWith(u8, arg, ".so") or
                mem.endsWith(u8, arg, ".dylib") or
                mem.endsWith(u8, arg, ".dll"))
            {
                std.debug.print("linking against dynamic libraries not yet supported", .{});
                process.exit(1);
            } else if (mem.endsWith(u8, arg, ".zig") or mem.endsWith(u8, arg, ".zir")) {
                if (root_src_file) |other| {
                    std.debug.print("found another zig file '{}' after root source file '{}'", .{ arg, other });
                    process.exit(1);
                } else {
                    root_src_file = arg;
                }
            } else {
                std.debug.print("unrecognized file extension of parameter '{}'", .{arg});
            }
        }
    }

    const root_name = if (provided_name) |n| n else blk: {
        if (root_src_file) |file| {
            const basename = fs.path.basename(file);
            var it = mem.split(basename, ".");
            break :blk it.next() orelse basename;
        } else {
            std.debug.print("--name [name] not provided and unable to infer\n", .{});
            process.exit(1);
        }
    };

    if (system_libs.items.len != 0) {
        std.debug.print("linking against system libraries not yet supported", .{});
        process.exit(1);
    }

    var diags: std.zig.CrossTarget.ParseOptions.Diagnostics = .{};
    const cross_target = std.zig.CrossTarget.parse(.{
        .arch_os_abi = target_arch_os_abi,
        .cpu_features = target_mcpu,
        .dynamic_linker = target_dynamic_linker,
        .diagnostics = &diags,
    }) catch |err| switch (err) {
        error.UnknownCpuModel => {
            std.debug.print("Unknown CPU: '{}'\nAvailable CPUs for architecture '{}':\n", .{
                diags.cpu_name.?,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allCpuModels()) |cpu| {
                std.debug.print(" {}\n", .{cpu.name});
            }
            process.exit(1);
        },
        error.UnknownCpuFeature => {
            std.debug.print(
                \\Unknown CPU feature: '{}'
                \\Available CPU features for architecture '{}':
                \\
            , .{
                diags.unknown_feature_name,
                @tagName(diags.arch.?),
            });
            for (diags.arch.?.allFeaturesList()) |feature| {
                std.debug.print(" {}: {}\n", .{ feature.name, feature.description });
            }
            process.exit(1);
        },
        else => |e| return e,
    };

    var target_info = try std.zig.system.NativeTargetInfo.detect(gpa, cross_target);
    if (target_info.cpu_detection_unimplemented) {
        // TODO We want to just use detected_info.target but implementing
        // CPU model & feature detection is todo so here we rely on LLVM.
        std.debug.print("CPU features detection is not yet available for this system without LLVM extensions\n", .{});
        process.exit(1);
    }

    const src_path = root_src_file orelse {
        std.debug.print("expected at least one file argument", .{});
        process.exit(1);
    };

    const bin_path = switch (emit_bin) {
        .no => {
            std.debug.print("-fno-emit-bin not supported yet", .{});
            process.exit(1);
        },
        .yes_default_path => if (object_format != null and object_format.? == .c)
            try std.fmt.allocPrint(arena, "{}.c", .{root_name})
        else
            try std.zig.binNameAlloc(arena, root_name, target_info.target, output_mode, link_mode),

        .yes => |p| p,
    };

    const zir_out_path: ?[]const u8 = switch (emit_zir) {
        .no => null,
        .yes_default_path => blk: {
            if (root_src_file) |rsf| {
                if (mem.endsWith(u8, rsf, ".zir")) {
                    break :blk try std.fmt.allocPrint(arena, "{}.out.zir", .{root_name});
                }
            }
            break :blk try std.fmt.allocPrint(arena, "{}.zir", .{root_name});
        },
        .yes => |p| p,
    };

    const root_pkg = try Package.create(gpa, fs.cwd(), ".", src_path);
    defer root_pkg.destroy();

    var module = try Module.init(gpa, .{
        .target = target_info.target,
        .output_mode = output_mode,
        .root_pkg = root_pkg,
        .bin_file_dir = fs.cwd(),
        .bin_file_path = bin_path,
        .link_mode = link_mode,
        .object_format = object_format,
        .optimize_mode = build_mode,
        .keep_source_files_loaded = zir_out_path != null,
    });
    defer module.deinit();

    const stdin = std.io.getStdIn().inStream();
    const stderr = std.io.getStdErr().outStream();
    var repl_buf: [1024]u8 = undefined;

    try updateModule(gpa, &module, zir_out_path);

    while (watch) {
        try stderr.print("🦎 ", .{});
        if (output_mode == .Exe) {
            try module.makeBinFileExecutable();
        }
        if (stdin.readUntilDelimiterOrEof(&repl_buf, '\n') catch |err| {
            try stderr.print("\nUnable to parse command: {}\n", .{@errorName(err)});
            continue;
        }) |line| {
            if (mem.eql(u8, line, "update")) {
                if (output_mode == .Exe) {
                    try module.makeBinFileWritable();
                }
                try updateModule(gpa, &module, zir_out_path);
            } else if (mem.eql(u8, line, "exit")) {
                break;
            } else if (mem.eql(u8, line, "help")) {
                try stderr.writeAll(repl_help);
            } else {
                try stderr.print("unknown command: {}\n", .{line});
            }
        } else {
            break;
        }
    }
}

fn updateModule(gpa: *Allocator, module: *Module, zir_out_path: ?[]const u8) !void {
    var timer = try std.time.Timer.start();
    try module.update();
    const update_nanos = timer.read();

    var errors = try module.getAllErrorsAlloc();
    defer errors.deinit(module.gpa);

    if (errors.list.len != 0) {
        for (errors.list) |full_err_msg| {
            std.debug.print("{}:{}:{}: error: {}\n", .{
                full_err_msg.src_path,
                full_err_msg.line + 1,
                full_err_msg.column + 1,
                full_err_msg.msg,
            });
        }
    } else {
        std.log.info(.compiler, "Update completed in {} ms\n", .{update_nanos / std.time.ns_per_ms});
    }

    if (zir_out_path) |zop| {
        var new_zir_module = try zir.emit(gpa, module.*);
        defer new_zir_module.deinit(gpa);

        const baf = try io.BufferedAtomicFile.create(gpa, fs.cwd(), zop, .{});
        defer baf.destroy();

        try new_zir_module.writeToStream(gpa, baf.stream());

        try baf.finish();
    }
}

const repl_help =
    \\Commands:
    \\  update   Detect changes to source files and update output files.
    \\    help   Print this text
    \\    exit   Quit this repl
    \\
;

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
    seen: SeenMap,
    any_error: bool,
    color: Color,
    gpa: *Allocator,
    out_buffer: std.ArrayList(u8),

    const SeenMap = std.AutoHashMap(fs.File.INode, void);
};

pub fn cmdFmt(gpa: *Allocator, args: []const []const u8) !void {
    const stderr_file = io.getStdErr();
    var color: Color = .Auto;
    var stdin_flag: bool = false;
    var check_flag: bool = false;
    var input_files = ArrayList([]const u8).init(gpa);

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "--help")) {
                    const stdout = io.getStdOut().outStream();
                    try stdout.writeAll(usage_fmt);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        std.debug.print("expected [auto|on|off] after --color\n", .{});
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
                        std.debug.print("expected [auto|on|off] after --color, found '{}'\n", .{next_arg});
                        process.exit(1);
                    }
                } else if (mem.eql(u8, arg, "--stdin")) {
                    stdin_flag = true;
                } else if (mem.eql(u8, arg, "--check")) {
                    check_flag = true;
                } else {
                    std.debug.print("unrecognized parameter: '{}'", .{arg});
                    process.exit(1);
                }
            } else {
                try input_files.append(arg);
            }
        }
    }

    if (stdin_flag) {
        if (input_files.items.len != 0) {
            std.debug.print("cannot use --stdin with positional arguments\n", .{});
            process.exit(1);
        }

        const stdin = io.getStdIn().inStream();

        const source_code = try stdin.readAllAlloc(gpa, max_src_size);
        defer gpa.free(source_code);

        const tree = std.zig.parse(gpa, source_code) catch |err| {
            std.debug.print("error parsing stdin: {}\n", .{err});
            process.exit(1);
        };
        defer tree.deinit();

        for (tree.errors) |parse_error| {
            try printErrMsgToFile(gpa, parse_error, tree, "<stdin>", stderr_file, color);
        }
        if (tree.errors.len != 0) {
            process.exit(1);
        }
        if (check_flag) {
            const anything_changed = try std.zig.render(gpa, io.null_out_stream, tree);
            const code = if (anything_changed) @as(u8, 1) else @as(u8, 0);
            process.exit(code);
        }

        const stdout = io.getStdOut().outStream();
        _ = try std.zig.render(gpa, stdout, tree);
        return;
    }

    if (input_files.items.len == 0) {
        std.debug.print("expected at least one source file argument\n", .{});
        process.exit(1);
    }

    var fmt = Fmt{
        .gpa = gpa,
        .seen = Fmt.SeenMap.init(gpa),
        .any_error = false,
        .color = color,
        .out_buffer = std.ArrayList(u8).init(gpa),
    };
    defer fmt.seen.deinit();
    defer fmt.out_buffer.deinit();

    for (input_files.span()) |file_path| {
        // Get the real path here to avoid Windows failing on relative file paths with . or .. in them.
        const real_path = fs.realpathAlloc(gpa, file_path) catch |err| {
            std.debug.print("unable to open '{}': {}\n", .{ file_path, err });
            process.exit(1);
        };
        defer gpa.free(real_path);

        try fmtPath(&fmt, file_path, check_flag, fs.cwd(), real_path);
    }
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
    EndOfStream,
} || fs.File.OpenError;

fn fmtPath(fmt: *Fmt, file_path: []const u8, check_mode: bool, dir: fs.Dir, sub_path: []const u8) FmtError!void {
    fmtPathFile(fmt, file_path, check_mode, dir, sub_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => return fmtPathDir(fmt, file_path, check_mode, dir, sub_path),
        else => {
            std.debug.print("unable to format '{}': {}\n", .{ file_path, err });
            fmt.any_error = true;
            return;
        },
    };
}

fn fmtPathDir(
    fmt: *Fmt,
    file_path: []const u8,
    check_mode: bool,
    parent_dir: fs.Dir,
    parent_sub_path: []const u8,
) FmtError!void {
    var dir = try parent_dir.openDir(parent_sub_path, .{ .iterate = true });
    defer dir.close();

    const stat = try dir.stat();
    if (try fmt.seen.fetchPut(stat.inode, {})) |_| return;

    var dir_it = dir.iterate();
    while (try dir_it.next()) |entry| {
        const is_dir = entry.kind == .Directory;
        if (is_dir or mem.endsWith(u8, entry.name, ".zig")) {
            const full_path = try fs.path.join(fmt.gpa, &[_][]const u8{ file_path, entry.name });
            defer fmt.gpa.free(full_path);

            if (is_dir) {
                try fmtPathDir(fmt, full_path, check_mode, dir, entry.name);
            } else {
                fmtPathFile(fmt, full_path, check_mode, dir, entry.name) catch |err| {
                    std.debug.print("unable to format '{}': {}\n", .{ full_path, err });
                    fmt.any_error = true;
                    return;
                };
            }
        }
    }
}

fn fmtPathFile(
    fmt: *Fmt,
    file_path: []const u8,
    check_mode: bool,
    dir: fs.Dir,
    sub_path: []const u8,
) FmtError!void {
    const source_file = try dir.openFile(sub_path, .{});
    var file_closed = false;
    errdefer if (!file_closed) source_file.close();

    const stat = try source_file.stat();

    if (stat.kind == .Directory)
        return error.IsDir;

    const source_code = source_file.readAllAlloc(fmt.gpa, stat.size, max_src_size) catch |err| switch (err) {
        error.ConnectionResetByPeer => unreachable,
        error.ConnectionTimedOut => unreachable,
        else => |e| return e,
    };
    source_file.close();
    file_closed = true;
    defer fmt.gpa.free(source_code);

    // Add to set after no longer possible to get error.IsDir.
    if (try fmt.seen.fetchPut(stat.inode, {})) |_| return;

    const tree = try std.zig.parse(fmt.gpa, source_code);
    defer tree.deinit();

    for (tree.errors) |parse_error| {
        try printErrMsgToFile(fmt.gpa, parse_error, tree, file_path, std.io.getStdErr(), fmt.color);
    }
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (check_mode) {
        const anything_changed = try std.zig.render(fmt.gpa, io.null_out_stream, tree);
        if (anything_changed) {
            std.debug.print("{}\n", .{file_path});
            fmt.any_error = true;
        }
    } else {
        // As a heuristic, we make enough capacity for the same as the input source.
        try fmt.out_buffer.ensureCapacity(source_code.len);
        fmt.out_buffer.items.len = 0;
        const anything_changed = try std.zig.render(fmt.gpa, fmt.out_buffer.writer(), tree);
        if (!anything_changed)
            return; // Good thing we didn't waste any file system access on this.

        var af = try dir.atomicFile(sub_path, .{ .mode = stat.mode });
        defer af.deinit();

        try af.file.writeAll(fmt.out_buffer.items);
        try af.finish();
        std.debug.print("{}\n", .{file_path});
    }
}

fn printErrMsgToFile(
    gpa: *mem.Allocator,
    parse_error: ast.Error,
    tree: *ast.Tree,
    path: []const u8,
    file: fs.File,
    color: Color,
) !void {
    const color_on = switch (color) {
        .Auto => file.isTty(),
        .On => true,
        .Off => false,
    };
    const lok_token = parse_error.loc();
    const span_first = lok_token;
    const span_last = lok_token;

    const first_token = tree.token_locs[span_first];
    const last_token = tree.token_locs[span_last];
    const start_loc = tree.tokenLocationLoc(0, first_token);
    const end_loc = tree.tokenLocationLoc(first_token.end, last_token);

    var text_buf = std.ArrayList(u8).init(gpa);
    defer text_buf.deinit();
    const out_stream = text_buf.outStream();
    try parse_error.render(tree.token_ids, out_stream);
    const text = text_buf.span();

    const stream = file.outStream();
    try stream.print("{}:{}:{}: error: {}\n", .{ path, start_loc.line + 1, start_loc.column + 1, text });

    if (!color_on) return;

    // Print \r and \t as one space each so that column counts line up
    for (tree.source[start_loc.line_start..start_loc.line_end]) |byte| {
        try stream.writeByte(switch (byte) {
            '\r', '\t' => ' ',
            else => byte,
        });
    }
    try stream.writeByte('\n');
    try stream.writeByteNTimes(' ', start_loc.column);
    try stream.writeByteNTimes('~', last_token.end - first_token.start);
    try stream.writeByte('\n');
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
    \\ * Resource deallocation must succeed.
    \\ * Together we serve end users.
    \\
    \\
;
