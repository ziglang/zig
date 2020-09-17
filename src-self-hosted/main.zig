const std = @import("std");
const assert = std.debug.assert;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const ast = std.zig.ast;
const Compilation = @import("Compilation.zig");
const link = @import("link.zig");
const Package = @import("Package.zig");
const zir = @import("zir.zig");
const build_options = @import("build_options");
const warn = std.log.warn;
const introspect = @import("introspect.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.emerg(format, args);
    process.exit(1);
}

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
    \\  build-exe        Create executable from source or object files
    \\  build-lib        Create library from source or object files
    \\  build-obj        Create object from source or assembly
    \\  cc               Use Zig as a drop-in C compiler
    \\  c++              Use Zig as a drop-in C++ compiler
    \\  env              Print lib path, std path, compiler id and version
    \\  fmt              Parse file and render in canonical zig format
    \\  libc             Display native libc paths file or validate one
    \\  translate-c      Convert C code to Zig code
    \\  targets          List available compilation targets
    \\  version          Print version number and exit
    \\  zen              Print zen of zig and exit
    \\
    \\General Options:
    \\
    \\  --help           Print command-specific usage
    \\
;

pub const log_level: std.log.Level = switch (std.builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast => .info,
    .ReleaseSmall => .crit,
};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Hide debug messages unless added with `-Dlog=foo`.
    if (@enumToInt(level) > @enumToInt(std.log.level) or
        @enumToInt(level) > @enumToInt(std.log.Level.info))
    {
        const scope_name = @tagName(scope);
        const ok = comptime for (build_options.log_scopes) |log_scope| {
            if (mem.eql(u8, log_scope, scope_name))
                break true;
        } else return;
    }

    // We only recognize 4 log levels in this application.
    const level_txt = switch (level) {
        .emerg, .alert, .crit, .err => "error",
        .warn => "warning",
        .notice, .info => "info",
        .debug => "debug",
    };
    const prefix1 = level_txt;
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // Print the message to stderr, silently ignoring any errors
    std.debug.print(prefix1 ++ prefix2 ++ format ++ "\n", args);
}

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    const gpa = if (std.builtin.link_libc) std.heap.c_allocator else &general_purpose_allocator.allocator;
    defer if (!std.builtin.link_libc) {
        _ = general_purpose_allocator.deinit();
    };
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = &arena_instance.allocator;

    const args = try process.argsAlloc(arena);

    if (args.len <= 1) {
        std.log.info("{}", .{usage});
        fatal("expected command argument", .{});
    }

    const cmd = args[1];
    const cmd_args = args[2..];
    if (mem.eql(u8, cmd, "build-exe")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Exe });
    } else if (mem.eql(u8, cmd, "build-lib")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Lib });
    } else if (mem.eql(u8, cmd, "build-obj")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Obj });
    } else if (mem.eql(u8, cmd, "cc")) {
        return buildOutputType(gpa, arena, args, .cc);
    } else if (mem.eql(u8, cmd, "c++")) {
        return buildOutputType(gpa, arena, args, .cpp);
    } else if (mem.eql(u8, cmd, "translate-c")) {
        return buildOutputType(gpa, arena, args, .translate_c);
    } else if (mem.eql(u8, cmd, "clang") or
        mem.eql(u8, cmd, "-cc1") or mem.eql(u8, cmd, "-cc1as"))
    {
        return punt_to_clang(arena, args);
    } else if (mem.eql(u8, cmd, "fmt")) {
        return cmdFmt(gpa, cmd_args);
    } else if (mem.eql(u8, cmd, "libc")) {
        return cmdLibC(gpa, cmd_args);
    } else if (mem.eql(u8, cmd, "targets")) {
        const info = try std.zig.system.NativeTargetInfo.detect(arena, .{});
        const stdout = io.getStdOut().outStream();
        return @import("print_targets.zig").cmdTargets(arena, cmd_args, stdout, info.target);
    } else if (mem.eql(u8, cmd, "version")) {
        try std.io.getStdOut().writeAll(build_options.version ++ "\n");
    } else if (mem.eql(u8, cmd, "env")) {
        try @import("print_env.zig").cmdEnv(arena, cmd_args, io.getStdOut().outStream());
    } else if (mem.eql(u8, cmd, "zen")) {
        try io.getStdOut().writeAll(info_zen);
    } else if (mem.eql(u8, cmd, "help")) {
        try io.getStdOut().writeAll(usage);
    } else {
        std.log.info("{}", .{usage});
        fatal("unknown command: {}", .{args[1]});
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
    \\  -mcmodel=[default|tiny|   Limit range of code and data virtual addresses
    \\            small|kernel|
    \\            medium|large]
    \\  --name [name]             Override output name
    \\  --mode [mode]             Set the build mode
    \\    Debug                   (default) optimizations off, safety on
    \\    ReleaseFast             Optimizations on, safety off
    \\    ReleaseSafe             Optimizations on, safety on
    \\    ReleaseSmall            Optimize for small binary, safety off
    \\  -fPIC                     Force-enable Position Independent Code
    \\  -fno-PIC                  Force-disable Position Independent Code
    \\  -fstack-check             Enable stack probing in unsafe builds
    \\  -fno-stack-check          Disable stack probing in safe builds
    \\  -fsanitize-c              Enable C undefined behavior detection in unsafe builds
    \\  -fno-sanitize-c           Disable C undefined behavior detection in safe builds
    \\  -fvalgrind                Include valgrind client requests in release builds
    \\  -fno-valgrind             Omit valgrind client requests in debug builds
    \\  --strip                   Exclude debug symbols
    \\  --single-threaded         Code assumes it is only used single-threaded
    \\  -ofmt=[mode]              Override target object format
    \\    elf                     Executable and Linking Format
    \\    c                       Compile to C source code
    \\    wasm                    WebAssembly
    \\    pe                      Portable Executable (Windows)
    \\    coff   (planned)        Common Object File Format (Windows)
    \\    macho  (planned)        macOS relocatables
    \\    hex    (planned)        Intel IHEX
    \\    raw    (planned)        Dump machine code directly
    \\  -dirafter [dir]           Add directory to AFTER include search path
    \\  -isystem  [dir]           Add directory to SYSTEM include search path
    \\  -I[dir]                   Add directory to include search path
    \\  -D[macro]=[value]         Define C [macro] to [value] (1 if [value] omitted)
    \\  --libc [file]             Provide a file which specifies libc paths
    \\
    \\Link Options:
    \\  -l[lib], --library [lib]  Link against system library
    \\  -L[d], --library-directory [d] Add a directory to the library search path
    \\  -T[script]                Use a custom linker script
    \\  --dynamic-linker [path]   Set the dynamic interpreter path (usually ld.so)
    \\  --version [ver]           Dynamic library semver
    \\  -rdynamic                 Add all symbols to the dynamic symbol table
    \\  -rpath [path]             Add directory to the runtime library search path
    \\  --eh-frame-hdr            Enable C++ exception handling by passing --eh-frame-hdr to linker
    \\  -dynamic                  Force output to be dynamically linked
    \\  -static                   Force output to be statically linked
    \\
    \\Debug Options (Zig Compiler Development):
    \\  -ftime-report             Print timing diagnostics
    \\  --debug-link              Verbose linker invocation
    \\  --debug-cc                Verbose C compiler invocation
    \\
;

const repl_help =
    \\Commands:
    \\  update   Detect changes to source files and update output files.
    \\    help   Print this text
    \\    exit   Quit this repl
    \\
;

const Emit = union(enum) {
    no,
    yes_default_path,
    yes: []const u8,
};

pub fn buildOutputType(
    gpa: *Allocator,
    arena: *Allocator,
    all_args: []const []const u8,
    arg_mode: union(enum) {
        build: std.builtin.OutputMode,
        cc,
        cpp,
        translate_c,
    },
) !void {
    var color: Color = .Auto;
    var build_mode: std.builtin.Mode = .Debug;
    var provided_name: ?[]const u8 = null;
    var link_mode: ?std.builtin.LinkMode = null;
    var root_src_file: ?[]const u8 = null;
    var version: std.builtin.Version = .{ .major = 0, .minor = 0, .patch = 0 };
    var have_version = false;
    var strip = false;
    var single_threaded = false;
    var watch = false;
    var debug_link = false;
    var debug_cc = false;
    var time_report = false;
    var emit_bin: Emit = .yes_default_path;
    var emit_zir: Emit = .no;
    var target_arch_os_abi: []const u8 = "native";
    var target_mcpu: ?[]const u8 = null;
    var target_dynamic_linker: ?[]const u8 = null;
    var target_ofmt: ?[]const u8 = null;
    var output_mode: std.builtin.OutputMode = undefined;
    var emit_h: Emit = undefined;
    var ensure_libc_on_non_freestanding = false;
    var ensure_libcpp_on_non_freestanding = false;
    var link_libc = false;
    var link_libcpp = false;
    var want_native_include_dirs = false;
    var enable_cache: ?bool = null;
    var want_pic: ?bool = null;
    var want_sanitize_c: ?bool = null;
    var want_stack_check: ?bool = null;
    var want_valgrind: ?bool = null;
    var rdynamic: bool = false;
    var only_pp_or_asm = false;
    var linker_script: ?[]const u8 = null;
    var version_script: ?[]const u8 = null;
    var disable_c_depfile = false;
    var override_soname: ?[]const u8 = null;
    var linker_gc_sections: ?bool = null;
    var linker_allow_shlib_undefined: ?bool = null;
    var linker_bind_global_refs_locally: ?bool = null;
    var linker_z_nodelete = false;
    var linker_z_defs = false;
    var stack_size_override: ?u64 = null;
    var use_llvm: ?bool = null;
    var use_lld: ?bool = null;
    var use_clang: ?bool = null;
    var link_eh_frame_hdr = false;
    var libc_paths_file: ?[]const u8 = null;
    var machine_code_model: std.builtin.CodeModel = .default;

    var system_libs = std.ArrayList([]const u8).init(gpa);
    defer system_libs.deinit();

    var clang_argv = std.ArrayList([]const u8).init(gpa);
    defer clang_argv.deinit();

    var lld_argv = std.ArrayList([]const u8).init(gpa);
    defer lld_argv.deinit();

    var lib_dirs = std.ArrayList([]const u8).init(gpa);
    defer lib_dirs.deinit();

    var rpath_list = std.ArrayList([]const u8).init(gpa);
    defer rpath_list.deinit();

    var c_source_files = std.ArrayList(Compilation.CSourceFile).init(gpa);
    defer c_source_files.deinit();

    var link_objects = std.ArrayList([]const u8).init(gpa);
    defer link_objects.deinit();

    var framework_dirs = std.ArrayList([]const u8).init(gpa);
    defer framework_dirs.deinit();

    var frameworks = std.ArrayList([]const u8).init(gpa);
    defer frameworks.deinit();

    if (arg_mode == .build or arg_mode == .translate_c) {
        output_mode = switch (arg_mode) {
            .build => |m| m,
            .translate_c => .Obj,
            else => unreachable,
        };
        switch (arg_mode) {
            .build => switch (output_mode) {
                .Exe => emit_h = .no,
                .Obj, .Lib => emit_h = .yes_default_path,
            },
            .translate_c => emit_h = .no,
            else => unreachable,
        }
        const args = all_args[2..];
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    try io.getStdOut().writeAll(usage_build_generic);
                    process.exit(0);
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        fatal("expected [auto|on|off] after --color", .{});
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
                        fatal("expected [auto|on|off] after --color, found '{}'", .{next_arg});
                    }
                } else if (mem.eql(u8, arg, "--mode")) {
                    if (i + 1 >= args.len) {
                        fatal("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode", .{});
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
                        fatal("expected [Debug|ReleaseSafe|ReleaseFast|ReleaseSmall] after --mode, found '{}'", .{next_arg});
                    }
                } else if (mem.eql(u8, arg, "--stack")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    stack_size_override = std.fmt.parseInt(u64, args[i], 10) catch |err| {
                        fatal("unable to parse '{}': {}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--name")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    provided_name = args[i];
                } else if (mem.eql(u8, arg, "-rpath")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    try rpath_list.append(args[i]);
                } else if (mem.eql(u8, arg, "--library-directory") or mem.eql(u8, arg, "-L")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    try lib_dirs.append(args[i]);
                } else if (mem.eql(u8, arg, "-T")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    linker_script = args[i];
                } else if (mem.eql(u8, arg, "--version-script")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    version_script = args[i];
                } else if (mem.eql(u8, arg, "--library") or mem.eql(u8, arg, "-l")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    // We don't know whether this library is part of libc or libc++ until we resolve the target.
                    // So we simply append to the list for now.
                    i += 1;
                    try system_libs.append(args[i]);
                } else if (mem.eql(u8, arg, "-D") or
                    mem.eql(u8, arg, "-isystem") or
                    mem.eql(u8, arg, "-I") or
                    mem.eql(u8, arg, "-dirafter"))
                {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    try clang_argv.append(arg);
                    try clang_argv.append(args[i]);
                } else if (mem.eql(u8, arg, "--version")) {
                    if (i + 1 >= args.len) {
                        fatal("expected parameter after --version", .{});
                    }
                    i += 1;
                    version = std.builtin.Version.parse(args[i]) catch |err| {
                        fatal("unable to parse --version '{}': {}", .{ args[i], @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "-target")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    target_arch_os_abi = args[i];
                } else if (mem.eql(u8, arg, "-mcpu")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    target_mcpu = args[i];
                } else if (mem.eql(u8, arg, "-mcmodel")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    machine_code_model = parseCodeModel(args[i]);
                } else if (mem.startsWith(u8, arg, "-ofmt=")) {
                    target_ofmt = arg["-ofmt=".len..];
                } else if (mem.startsWith(u8, arg, "-mcpu=")) {
                    target_mcpu = arg["-mcpu=".len..];
                } else if (mem.startsWith(u8, arg, "-mcmodel=")) {
                    machine_code_model = parseCodeModel(arg["-mcmodel=".len..]);
                } else if (mem.eql(u8, arg, "--dynamic-linker")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    target_dynamic_linker = args[i];
                } else if (mem.eql(u8, arg, "--libc")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {}", .{arg});
                    i += 1;
                    libc_paths_file = args[i];
                } else if (mem.eql(u8, arg, "--watch")) {
                    watch = true;
                } else if (mem.eql(u8, arg, "-ftime-report")) {
                    time_report = true;
                } else if (mem.eql(u8, arg, "-fPIC")) {
                    want_pic = true;
                } else if (mem.eql(u8, arg, "-fno-PIC")) {
                    want_pic = false;
                } else if (mem.eql(u8, arg, "-fstack-check")) {
                    want_stack_check = true;
                } else if (mem.eql(u8, arg, "-fno-stack-check")) {
                    want_stack_check = false;
                } else if (mem.eql(u8, arg, "-fsanitize-c")) {
                    want_sanitize_c = true;
                } else if (mem.eql(u8, arg, "-fno-sanitize-c")) {
                    want_sanitize_c = false;
                } else if (mem.eql(u8, arg, "-fvalgrind")) {
                    want_valgrind = true;
                } else if (mem.eql(u8, arg, "-fno-valgrind")) {
                    want_valgrind = false;
                } else if (mem.eql(u8, arg, "-fLLVM")) {
                    use_llvm = true;
                } else if (mem.eql(u8, arg, "-fno-LLVM")) {
                    use_llvm = false;
                } else if (mem.eql(u8, arg, "-fLLD")) {
                    use_lld = true;
                } else if (mem.eql(u8, arg, "-fno-LLD")) {
                    use_lld = false;
                } else if (mem.eql(u8, arg, "-fClang")) {
                    use_clang = true;
                } else if (mem.eql(u8, arg, "-fno-Clang")) {
                    use_clang = false;
                } else if (mem.eql(u8, arg, "-rdynamic")) {
                    rdynamic = true;
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
                } else if (mem.eql(u8, arg, "-femit-h")) {
                    emit_h = .yes_default_path;
                } else if (mem.startsWith(u8, arg, "-femit-h=")) {
                    emit_h = .{ .yes = arg["-femit-h=".len..] };
                } else if (mem.eql(u8, arg, "-fno-emit-h")) {
                    emit_h = .no;
                } else if (mem.eql(u8, arg, "-dynamic")) {
                    link_mode = .Dynamic;
                } else if (mem.eql(u8, arg, "-static")) {
                    link_mode = .Static;
                } else if (mem.eql(u8, arg, "--strip")) {
                    strip = true;
                } else if (mem.eql(u8, arg, "--single-threaded")) {
                    single_threaded = true;
                } else if (mem.eql(u8, arg, "--eh-frame-hdr")) {
                    link_eh_frame_hdr = true;
                } else if (mem.eql(u8, arg, "-Bsymbolic")) {
                    linker_bind_global_refs_locally = true;
                } else if (mem.eql(u8, arg, "--debug-link")) {
                    debug_link = true;
                } else if (mem.eql(u8, arg, "--debug-cc")) {
                    debug_cc = true;
                } else if (mem.startsWith(u8, arg, "-T")) {
                    linker_script = arg[2..];
                } else if (mem.startsWith(u8, arg, "-L")) {
                    try lib_dirs.append(arg[2..]);
                } else if (mem.startsWith(u8, arg, "-l")) {
                    // We don't know whether this library is part of libc or libc++ until we resolve the target.
                    // So we simply append to the list for now.
                    try system_libs.append(arg[2..]);
                } else if (mem.startsWith(u8, arg, "-D") or
                    mem.startsWith(u8, arg, "-I"))
                {
                    try clang_argv.append(arg);
                } else {
                    fatal("unrecognized parameter: '{}'", .{arg});
                }
            } else if (mem.endsWith(u8, arg, ".o") or
                mem.endsWith(u8, arg, ".obj") or
                mem.endsWith(u8, arg, ".a") or
                mem.endsWith(u8, arg, ".lib"))
            {
                try link_objects.append(arg);
            } else if (Compilation.hasAsmExt(arg) or Compilation.hasCExt(arg) or Compilation.hasCppExt(arg)) {
                // TODO a way to pass extra flags on the CLI
                try c_source_files.append(.{ .src_path = arg });
            } else if (mem.endsWith(u8, arg, ".so") or
                mem.endsWith(u8, arg, ".dylib") or
                mem.endsWith(u8, arg, ".dll"))
            {
                fatal("linking against dynamic libraries not yet supported", .{});
            } else if (mem.endsWith(u8, arg, ".zig") or mem.endsWith(u8, arg, ".zir")) {
                if (root_src_file) |other| {
                    fatal("found another zig file '{}' after root source file '{}'", .{ arg, other });
                } else {
                    root_src_file = arg;
                }
            } else {
                fatal("unrecognized file extension of parameter '{}'", .{arg});
            }
        }
    } else {
        emit_h = .no;
        strip = true;
        ensure_libc_on_non_freestanding = true;
        ensure_libcpp_on_non_freestanding = arg_mode == .cpp;
        want_native_include_dirs = true;

        var c_arg = false;
        var is_shared_lib = false;
        var linker_args = std.ArrayList([]const u8).init(arena);
        var it = ClangArgIterator.init(arena, all_args);
        while (it.has_next) {
            it.next() catch |err| {
                fatal("unable to parse command line parameters: {}", .{@errorName(err)});
            };
            switch (it.zig_equivalent) {
                .target => target_arch_os_abi = it.only_arg, // example: -target riscv64-linux-unknown
                .o => {
                    // -o
                    emit_bin = .{ .yes = it.only_arg };
                    enable_cache = true;
                },
                .c => c_arg = true, // -c
                .other => {
                    try clang_argv.appendSlice(it.other_args);
                },
                .positional => {
                    const file_ext = Compilation.classifyFileExt(mem.spanZ(it.only_arg));
                    switch (file_ext) {
                        .assembly, .c, .cpp, .ll, .bc, .h => try c_source_files.append(.{ .src_path = it.only_arg }),
                        .unknown, .so => try link_objects.append(it.only_arg),
                    }
                },
                .l => {
                    // -l
                    // We don't know whether this library is part of libc or libc++ until we resolve the target.
                    // So we simply append to the list for now.
                    try system_libs.append(it.only_arg);
                },
                .ignore => {},
                .driver_punt => {
                    // Never mind what we're doing, just pass the args directly. For example --help.
                    return punt_to_clang(arena, all_args);
                },
                .pic => want_pic = true,
                .no_pic => want_pic = false,
                .nostdlib => ensure_libc_on_non_freestanding = false,
                .nostdlib_cpp => ensure_libcpp_on_non_freestanding = false,
                .shared => {
                    link_mode = .Dynamic;
                    is_shared_lib = true;
                },
                .rdynamic => rdynamic = true,
                .wl => {
                    var split_it = mem.split(it.only_arg, ",");
                    @breakpoint(); // TODO the first arg is empty string right? skip past that.
                    while (split_it.next()) |linker_arg| {
                        try linker_args.append(linker_arg);
                    }
                },
                .pp_or_asm => {
                    // This handles both -E and -S.
                    only_pp_or_asm = true;
                    try clang_argv.appendSlice(it.other_args);
                },
                .optimize => {
                    // Alright, what release mode do they want?
                    if (mem.eql(u8, it.only_arg, "Os")) {
                        build_mode = .ReleaseSmall;
                    } else if (mem.eql(u8, it.only_arg, "O2") or
                        mem.eql(u8, it.only_arg, "O3") or
                        mem.eql(u8, it.only_arg, "O4"))
                    {
                        build_mode = .ReleaseFast;
                    } else if (mem.eql(u8, it.only_arg, "Og") or
                        mem.eql(u8, it.only_arg, "O0"))
                    {
                        build_mode = .Debug;
                    } else {
                        try clang_argv.appendSlice(it.other_args);
                    }
                },
                .debug => {
                    strip = false;
                    if (mem.eql(u8, it.only_arg, "-g")) {
                        // We handled with strip = false above.
                    } else {
                        try clang_argv.appendSlice(it.other_args);
                    }
                },
                .sanitize => {
                    if (mem.eql(u8, it.only_arg, "undefined")) {
                        want_sanitize_c = true;
                    } else {
                        try clang_argv.appendSlice(it.other_args);
                    }
                },
                .linker_script => linker_script = it.only_arg,
                .verbose_cmds => {
                    debug_cc = true;
                    debug_link = true;
                },
                .for_linker => try linker_args.append(it.only_arg),
                .linker_input_z => {
                    try linker_args.append("-z");
                    try linker_args.append(it.only_arg);
                },
                .lib_dir => try lib_dirs.append(it.only_arg),
                .mcpu => target_mcpu = it.only_arg,
                .dep_file => {
                    disable_c_depfile = true;
                    try clang_argv.appendSlice(it.other_args);
                },
                .framework_dir => try framework_dirs.append(it.only_arg),
                .framework => try frameworks.append(it.only_arg),
                .nostdlibinc => want_native_include_dirs = false,
            }
        }
        // Parse linker args.
        var i: usize = 0;
        while (i < linker_args.items.len) : (i += 1) {
            const arg = linker_args.items[i];
            if (mem.eql(u8, arg, "-soname")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                const soname = linker_args.items[i];
                override_soname = soname;
                // Use it as --name.
                // Example: libsoundio.so.2
                var prefix: usize = 0;
                if (mem.startsWith(u8, soname, "lib")) {
                    prefix = 3;
                }
                var end: usize = soname.len;
                if (mem.endsWith(u8, soname, ".so")) {
                    end -= 3;
                } else {
                    var found_digit = false;
                    while (end > 0 and std.ascii.isDigit(soname[end - 1])) {
                        found_digit = true;
                        end -= 1;
                    }
                    if (found_digit and end > 0 and soname[end - 1] == '.') {
                        end -= 1;
                    } else {
                        end = soname.len;
                    }
                    if (mem.endsWith(u8, soname[prefix..end], ".so")) {
                        end -= 3;
                    }
                }
                provided_name = soname[prefix..end];
            } else if (mem.eql(u8, arg, "-rpath")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                try rpath_list.append(linker_args.items[i]);
            } else if (mem.eql(u8, arg, "-I") or
                mem.eql(u8, arg, "--dynamic-linker") or
                mem.eql(u8, arg, "-dynamic-linker"))
            {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                target_dynamic_linker = linker_args.items[i];
            } else if (mem.eql(u8, arg, "-E") or
                mem.eql(u8, arg, "--export-dynamic") or
                mem.eql(u8, arg, "-export-dynamic"))
            {
                rdynamic = true;
            } else if (mem.eql(u8, arg, "--version-script")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                version_script = linker_args.items[i];
            } else if (mem.startsWith(u8, arg, "-O")) {
                try lld_argv.append(arg);
            } else if (mem.eql(u8, arg, "--gc-sections")) {
                linker_gc_sections = true;
            } else if (mem.eql(u8, arg, "--no-gc-sections")) {
                linker_gc_sections = false;
            } else if (mem.eql(u8, arg, "--allow-shlib-undefined") or
                mem.eql(u8, arg, "-allow-shlib-undefined"))
            {
                linker_allow_shlib_undefined = true;
            } else if (mem.eql(u8, arg, "--no-allow-shlib-undefined") or
                mem.eql(u8, arg, "-no-allow-shlib-undefined"))
            {
                linker_allow_shlib_undefined = false;
            } else if (mem.eql(u8, arg, "-Bsymbolic")) {
                linker_bind_global_refs_locally = true;
            } else if (mem.eql(u8, arg, "-z")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                const z_arg = linker_args.items[i];
                if (mem.eql(u8, z_arg, "nodelete")) {
                    linker_z_nodelete = true;
                } else if (mem.eql(u8, z_arg, "defs")) {
                    linker_z_defs = true;
                } else {
                    warn("unsupported linker arg: -z {}", .{z_arg});
                }
            } else if (mem.eql(u8, arg, "--major-image-version")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                version.major = std.fmt.parseInt(u32, linker_args.items[i], 10) catch |err| {
                    fatal("unable to parse '{}': {}", .{ arg, @errorName(err) });
                };
                have_version = true;
            } else if (mem.eql(u8, arg, "--minor-image-version")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                version.minor = std.fmt.parseInt(u32, linker_args.items[i], 10) catch |err| {
                    fatal("unable to parse '{}': {}", .{ arg, @errorName(err) });
                };
                have_version = true;
            } else if (mem.eql(u8, arg, "--stack")) {
                i += 1;
                if (i >= linker_args.items.len) {
                    fatal("expected linker arg after '{}'", .{arg});
                }
                stack_size_override = std.fmt.parseInt(u64, linker_args.items[i], 10) catch |err| {
                    fatal("unable to parse '{}': {}", .{ arg, @errorName(err) });
                };
            } else {
                warn("unsupported linker arg: {}", .{arg});
            }
        }

        if (want_sanitize_c) |wsc| {
            if (wsc and build_mode == .ReleaseFast) {
                build_mode = .ReleaseSafe;
            }
        }

        if (only_pp_or_asm) {
            output_mode = .Obj;
            fatal("TODO implement using zig cc as a preprocessor", .{});
            //// Transfer "link_objects" into c_source_files so that all those
            //// args make it onto the command line.
            //try c_source_files.appendSlice(link_objects.items);
            //for (c_source_files.items) |c_source_file| {
            //    const src_path = switch (emit_bin) {
            //        .yes => |p| p,
            //        else => c_source_file.source_path,
            //    };
            //    const basename = fs.path.basename(src_path);
            //    c_source_file.preprocessor_only_basename = basename;
            //}
            //emit_bin = .no;
        } else if (!c_arg) {
            output_mode = if (is_shared_lib) .Lib else .Exe;
            switch (emit_bin) {
                .no, .yes_default_path => {
                    emit_bin = .{ .yes = "a.out" };
                    enable_cache = true;
                },
                .yes => {},
            }
        } else {
            output_mode = .Obj;
        }
        if (c_source_files.items.len == 0 and link_objects.items.len == 0) {
            // For example `zig cc` and no args should print the "no input files" message.
            return punt_to_clang(arena, all_args);
        }
    }

    const root_name = if (provided_name) |n| n else blk: {
        if (root_src_file) |file| {
            const basename = fs.path.basename(file);
            break :blk mem.split(basename, ".").next().?;
        } else if (c_source_files.items.len == 1) {
            const basename = fs.path.basename(c_source_files.items[0].src_path);
            break :blk mem.split(basename, ".").next().?;
        } else if (link_objects.items.len == 1) {
            const basename = fs.path.basename(link_objects.items[0]);
            break :blk mem.split(basename, ".").next().?;
        } else if (emit_bin == .yes) {
            const basename = fs.path.basename(emit_bin.yes);
            break :blk mem.split(basename, ".").next().?;
        } else {
            fatal("--name [name] not provided and unable to infer", .{});
        }
    };

    var diags: std.zig.CrossTarget.ParseOptions.Diagnostics = .{};
    const cross_target = std.zig.CrossTarget.parse(.{
        .arch_os_abi = target_arch_os_abi,
        .cpu_features = target_mcpu,
        .dynamic_linker = target_dynamic_linker,
        .diagnostics = &diags,
    }) catch |err| switch (err) {
        error.UnknownCpuModel => {
            help: {
                var help_text = std.ArrayList(u8).init(arena);
                for (diags.arch.?.allCpuModels()) |cpu| {
                    help_text.writer().print(" {}\n", .{cpu.name}) catch break :help;
                }
                std.log.info("Available CPUs for architecture '{}': {}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("Unknown CPU: '{}'", .{diags.cpu_name.?});
        },
        error.UnknownCpuFeature => {
            help: {
                var help_text = std.ArrayList(u8).init(arena);
                for (diags.arch.?.allFeaturesList()) |feature| {
                    help_text.writer().print(" {}: {}\n", .{ feature.name, feature.description }) catch break :help;
                }
                std.log.info("Available CPU features for architecture '{}': {}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("Unknown CPU feature: '{}'", .{diags.unknown_feature_name});
        },
        else => |e| return e,
    };

    const target_info = try std.zig.system.NativeTargetInfo.detect(gpa, cross_target);
    if (target_info.cpu_detection_unimplemented) {
        // TODO We want to just use detected_info.target but implementing
        // CPU model & feature detection is todo so here we rely on LLVM.
        // TODO The workaround to use LLVM to detect features needs to be used for
        // `zig targets` as well.
        fatal("CPU features detection is not yet available for this system without LLVM extensions", .{});
    }

    if (target_info.target.os.tag != .freestanding) {
        if (ensure_libc_on_non_freestanding)
            link_libc = true;
        if (ensure_libcpp_on_non_freestanding)
            link_libcpp = true;
    }

    // Now that we have target info, we can find out if any of the system libraries
    // are part of libc or libc++. We remove them from the list and communicate their
    // existence via flags instead.
    {
        var i: usize = 0;
        while (i < system_libs.items.len) {
            const lib_name = system_libs.items[i];
            if (is_libc_lib_name(target_info.target, lib_name)) {
                link_libc = true;
                _ = system_libs.orderedRemove(i);
                continue;
            }
            if (is_libcpp_lib_name(target_info.target, lib_name)) {
                link_libcpp = true;
                _ = system_libs.orderedRemove(i);
                continue;
            }
            i += 1;
        }
    }

    if (cross_target.isNativeOs() and (system_libs.items.len != 0 or want_native_include_dirs)) {
        const paths = std.zig.system.NativePaths.detect(arena) catch |err| {
            fatal("unable to detect native system paths: {}", .{@errorName(err)});
        };
        for (paths.warnings.items) |warning| {
            warn("{}", .{warning});
        }
        try clang_argv.ensureCapacity(clang_argv.items.len + paths.include_dirs.items.len * 2);
        for (paths.include_dirs.items) |include_dir| {
            clang_argv.appendAssumeCapacity("-isystem");
            clang_argv.appendAssumeCapacity(include_dir);
        }
        for (paths.lib_dirs.items) |lib_dir| {
            try lib_dirs.append(lib_dir);
        }
        for (paths.rpaths.items) |rpath| {
            try rpath_list.append(rpath);
        }
    }

    const object_format: ?std.Target.ObjectFormat = blk: {
        const ofmt = target_ofmt orelse break :blk null;
        if (mem.eql(u8, ofmt, "elf")) {
            break :blk .elf;
        } else if (mem.eql(u8, ofmt, "c")) {
            break :blk .c;
        } else if (mem.eql(u8, ofmt, "coff")) {
            break :blk .coff;
        } else if (mem.eql(u8, ofmt, "pe")) {
            break :blk .pe;
        } else if (mem.eql(u8, ofmt, "macho")) {
            break :blk .macho;
        } else if (mem.eql(u8, ofmt, "wasm")) {
            break :blk .wasm;
        } else if (mem.eql(u8, ofmt, "hex")) {
            break :blk .hex;
        } else if (mem.eql(u8, ofmt, "raw")) {
            break :blk .raw;
        } else {
            fatal("unsupported object format: {}", .{ofmt});
        }
    };

    var cleanup_emit_bin_dir: ?fs.Dir = null;
    defer if (cleanup_emit_bin_dir) |*dir| dir.close();

    const emit_bin_loc: ?Compilation.EmitLoc = switch (emit_bin) {
        .no => null,
        .yes_default_path => Compilation.EmitLoc{
            .directory = .{ .path = null, .handle = fs.cwd() },
            .basename = try std.zig.binNameAlloc(
                arena,
                root_name,
                target_info.target,
                output_mode,
                link_mode,
                object_format,
            ),
        },
        .yes => |full_path| b: {
            const basename = fs.path.basename(full_path);
            if (fs.path.dirname(full_path)) |dirname| {
                const handle = try fs.cwd().openDir(dirname, .{});
                cleanup_emit_bin_dir = handle;
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{
                        .path = dirname,
                        .handle = handle,
                    },
                };
            } else {
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{ .path = null, .handle = fs.cwd() },
                };
            }
        },
    };

    var cleanup_emit_h_dir: ?fs.Dir = null;
    defer if (cleanup_emit_h_dir) |*dir| dir.close();

    const emit_h_loc: ?Compilation.EmitLoc = switch (emit_h) {
        .no => null,
        .yes_default_path => Compilation.EmitLoc{
            .directory = .{ .path = null, .handle = fs.cwd() },
            .basename = try std.fmt.allocPrint(arena, "{}.h", .{root_name}),
        },
        .yes => |full_path| b: {
            const basename = fs.path.basename(full_path);
            if (fs.path.dirname(full_path)) |dirname| {
                const handle = try fs.cwd().openDir(dirname, .{});
                cleanup_emit_h_dir = handle;
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{
                        .path = dirname,
                        .handle = handle,
                    },
                };
            } else {
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{ .path = null, .handle = fs.cwd() },
                };
            }
        },
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

    const root_pkg = if (root_src_file) |src_path| try Package.create(gpa, fs.cwd(), ".", src_path) else null;
    defer if (root_pkg) |pkg| pkg.destroy(gpa);

    const self_exe_path = try fs.selfExePathAlloc(arena);
    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const random_seed = blk: {
        var random_seed: u64 = undefined;
        try std.crypto.randomBytes(mem.asBytes(&random_seed));
        break :blk random_seed;
    };
    var default_prng = std.rand.DefaultPrng.init(random_seed);

    var libc_installation: ?LibCInstallation = null;
    defer if (libc_installation) |*l| l.deinit(gpa);

    if (libc_paths_file) |paths_file| {
        libc_installation = LibCInstallation.parse(gpa, paths_file) catch |err| {
            fatal("unable to parse libc paths file: {}", .{@errorName(err)});
        };
    }

    const cache_parent_dir = if (root_pkg) |pkg| pkg.root_src_directory.handle else fs.cwd();
    var cache_dir = try cache_parent_dir.makeOpenPath("zig-cache", .{});
    defer cache_dir.close();
    const zig_cache_directory: Compilation.Directory = .{
        .handle = cache_dir,
        .path = blk: {
            if (root_pkg) |pkg| {
                if (pkg.root_src_directory.path) |p| {
                    break :blk try fs.path.join(arena, &[_][]const u8{ p, "zig-cache" });
                }
            }
            break :blk "zig-cache";
        },
    };

    const comp = Compilation.create(gpa, .{
        .zig_lib_directory = zig_lib_directory,
        .zig_cache_directory = zig_cache_directory,
        .root_name = root_name,
        .target = target_info.target,
        .is_native_os = cross_target.isNativeOs(),
        .dynamic_linker = target_info.dynamic_linker.get(),
        .output_mode = output_mode,
        .root_pkg = root_pkg,
        .emit_bin = emit_bin_loc,
        .emit_h = emit_h_loc,
        .link_mode = link_mode,
        .object_format = object_format,
        .optimize_mode = build_mode,
        .keep_source_files_loaded = zir_out_path != null,
        .clang_argv = clang_argv.items,
        .lld_argv = lld_argv.items,
        .lib_dirs = lib_dirs.items,
        .rpath_list = rpath_list.items,
        .c_source_files = c_source_files.items,
        .link_objects = link_objects.items,
        .framework_dirs = framework_dirs.items,
        .frameworks = frameworks.items,
        .system_libs = system_libs.items,
        .link_libc = link_libc,
        .link_libcpp = link_libcpp,
        .want_pic = want_pic,
        .want_sanitize_c = want_sanitize_c,
        .want_stack_check = want_stack_check,
        .want_valgrind = want_valgrind,
        .use_llvm = use_llvm,
        .use_lld = use_lld,
        .use_clang = use_clang,
        .rdynamic = rdynamic,
        .linker_script = linker_script,
        .version_script = version_script,
        .disable_c_depfile = disable_c_depfile,
        .override_soname = override_soname,
        .linker_gc_sections = linker_gc_sections,
        .linker_allow_shlib_undefined = linker_allow_shlib_undefined,
        .linker_bind_global_refs_locally = linker_bind_global_refs_locally,
        .linker_z_nodelete = linker_z_nodelete,
        .linker_z_defs = linker_z_defs,
        .link_eh_frame_hdr = link_eh_frame_hdr,
        .stack_size_override = stack_size_override,
        .strip = strip,
        .single_threaded = single_threaded,
        .self_exe_path = self_exe_path,
        .rand = &default_prng.random,
        .clang_passthrough_mode = arg_mode != .build,
        .version = if (have_version) version else null,
        .libc_installation = if (libc_installation) |*lci| lci else null,
        .debug_cc = debug_cc,
        .debug_link = debug_link,
        .machine_code_model = machine_code_model,
    }) catch |err| {
        fatal("unable to create compilation: {}", .{@errorName(err)});
    };
    defer comp.destroy();

    const stdin = std.io.getStdIn().inStream();
    const stderr = std.io.getStdErr().outStream();
    var repl_buf: [1024]u8 = undefined;

    try updateModule(gpa, comp, zir_out_path);

    if (build_options.have_llvm and only_pp_or_asm) {
        // this may include dumping the output to stdout
        fatal("TODO: implement `zig cc` when using it as a preprocessor", .{});
    }

    while (watch) {
        try stderr.print("🦎 ", .{});
        if (output_mode == .Exe) {
            try comp.makeBinFileExecutable();
        }
        if (stdin.readUntilDelimiterOrEof(&repl_buf, '\n') catch |err| {
            try stderr.print("\nUnable to parse command: {}\n", .{@errorName(err)});
            continue;
        }) |line| {
            const actual_line = mem.trimRight(u8, line, "\r\n ");

            if (mem.eql(u8, actual_line, "update")) {
                if (output_mode == .Exe) {
                    try comp.makeBinFileWritable();
                }
                try updateModule(gpa, comp, zir_out_path);
            } else if (mem.eql(u8, actual_line, "exit")) {
                break;
            } else if (mem.eql(u8, actual_line, "help")) {
                try stderr.writeAll(repl_help);
            } else {
                try stderr.print("unknown command: {}\n", .{actual_line});
            }
        } else {
            break;
        }
    }
}

fn updateModule(gpa: *Allocator, comp: *Compilation, zir_out_path: ?[]const u8) !void {
    try comp.update();

    var errors = try comp.getAllErrorsAlloc();
    defer errors.deinit(comp.gpa);

    if (errors.list.len != 0) {
        for (errors.list) |full_err_msg| {
            full_err_msg.renderToStdErr();
        }
    }

    if (zir_out_path) |zop| {
        const module = comp.bin_file.options.module orelse
            fatal("-femit-zir with no zig source code", .{});
        var new_zir_module = try zir.emit(gpa, module);
        defer new_zir_module.deinit(gpa);

        const baf = try io.BufferedAtomicFile.create(gpa, fs.cwd(), zop, .{});
        defer baf.destroy();

        try new_zir_module.writeToStream(gpa, baf.stream());

        try baf.finish();
    }
}

pub const usage_libc =
    \\Usage: zig libc
    \\
    \\    Detect the native libc installation and print the resulting
    \\    paths to stdout. You can save this into a file and then edit
    \\    the paths to create a cross compilation libc kit. Then you
    \\    can pass `--libc [file]` for Zig to use it.
    \\
    \\Usage: zig libc [paths_file]
    \\
    \\    Parse a libc installation text file and validate it.
    \\
;

pub fn cmdLibC(gpa: *Allocator, args: []const []const u8) !void {
    var input_file: ?[]const u8 = null;
    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "--help")) {
                    const stdout = io.getStdOut().writer();
                    try stdout.writeAll(usage_libc);
                    process.exit(0);
                } else {
                    fatal("unrecognized parameter: '{}'", .{arg});
                }
            } else if (input_file != null) {
                fatal("unexpected extra parameter: '{}'", .{arg});
            } else {
                input_file = arg;
            }
        }
    }
    if (input_file) |libc_file| {
        var libc = LibCInstallation.parse(gpa, libc_file) catch |err| {
            fatal("unable to parse libc file: {}", .{@errorName(err)});
        };
        defer libc.deinit(gpa);
    } else {
        var libc = LibCInstallation.findNative(.{
            .allocator = gpa,
            .verbose = true,
        }) catch |err| {
            fatal("unable to detect native libc: {}", .{@errorName(err)});
        };
        defer libc.deinit(gpa);

        var bos = io.bufferedOutStream(io.getStdOut().writer());
        try libc.render(bos.writer());
        try bos.flush();
    }
}

pub const usage_fmt =
    \\Usage: zig fmt [file]...
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
                        fatal("expected [auto|on|off] after --color", .{});
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
                        fatal("expected [auto|on|off] after --color, found '{}'", .{next_arg});
                    }
                } else if (mem.eql(u8, arg, "--stdin")) {
                    stdin_flag = true;
                } else if (mem.eql(u8, arg, "--check")) {
                    check_flag = true;
                } else {
                    fatal("unrecognized parameter: '{}'", .{arg});
                }
            } else {
                try input_files.append(arg);
            }
        }
    }

    if (stdin_flag) {
        if (input_files.items.len != 0) {
            fatal("cannot use --stdin with positional arguments", .{});
        }

        const stdin = io.getStdIn().inStream();

        const source_code = try stdin.readAllAlloc(gpa, max_src_size);
        defer gpa.free(source_code);

        const tree = std.zig.parse(gpa, source_code) catch |err| {
            fatal("error parsing stdin: {}", .{err});
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
        fatal("expected at least one source file argument", .{});
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
            fatal("unable to open '{}': {}", .{ file_path, err });
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
    Unseekable,
    NotOpenForWriting,
} || fs.File.OpenError;

fn fmtPath(fmt: *Fmt, file_path: []const u8, check_mode: bool, dir: fs.Dir, sub_path: []const u8) FmtError!void {
    fmtPathFile(fmt, file_path, check_mode, dir, sub_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => return fmtPathDir(fmt, file_path, check_mode, dir, sub_path),
        else => {
            warn("unable to format '{}': {}", .{ file_path, err });
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
                    warn("unable to format '{}': {}", .{ full_path, err });
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

    const source_code = source_file.readToEndAllocOptions(
        fmt.gpa,
        max_src_size,
        stat.size,
        @alignOf(u8),
        null,
    ) catch |err| switch (err) {
        error.ConnectionResetByPeer => unreachable,
        error.ConnectionTimedOut => unreachable,
        error.NotOpenForReading => unreachable,
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
            // TODO this should output to stdout instead of stderr.
            std.debug.print("{}\n", .{file_path});
            fmt.any_error = true;
        }
    } else {
        // As a heuristic, we make enough capacity for the same as the input source.
        try fmt.out_buffer.ensureCapacity(source_code.len);
        fmt.out_buffer.items.len = 0;
        const writer = fmt.out_buffer.writer();
        const anything_changed = try std.zig.render(fmt.gpa, writer, tree);
        if (!anything_changed)
            return; // Good thing we didn't waste any file system access on this.

        var af = try dir.atomicFile(sub_path, .{ .mode = stat.mode });
        defer af.deinit();

        try af.file.writeAll(fmt.out_buffer.items);
        try af.finish();
        // TODO this should output to stdout instead of stderr.
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
    \\ * Focus on code rather than style.
    \\ * Resource allocation may fail; resource deallocation must succeed.
    \\ * Memory is a resource.
    \\ * Together we serve the users.
    \\
    \\
;

extern "c" fn ZigClang_main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;

/// TODO https://github.com/ziglang/zig/issues/3257
fn punt_to_clang(arena: *Allocator, args: []const []const u8) error{OutOfMemory} {
    if (!build_options.have_llvm)
        fatal("`zig cc` and `zig c++` unavailable: compiler not built with LLVM extensions enabled", .{});
    // Convert the args to the format Clang expects.
    const argv = try arena.alloc(?[*:0]u8, args.len + 1);
    for (args) |arg, i| {
        argv[i] = try arena.dupeZ(u8, arg); // TODO If there was an argsAllocZ we could avoid this allocation.
    }
    argv[args.len] = null;
    const exit_code = ZigClang_main(@intCast(c_int, args.len), argv[0..args.len :null].ptr);
    process.exit(@bitCast(u8, @truncate(i8, exit_code)));
}

const clang_args = @import("clang_options.zig").list;

pub const ClangArgIterator = struct {
    has_next: bool,
    zig_equivalent: ZigEquivalent,
    only_arg: []const u8,
    second_arg: []const u8,
    other_args: []const []const u8,
    argv: []const []const u8,
    next_index: usize,
    root_args: ?*Args,
    allocator: *Allocator,

    pub const ZigEquivalent = enum {
        target,
        o,
        c,
        other,
        positional,
        l,
        ignore,
        driver_punt,
        pic,
        no_pic,
        nostdlib,
        nostdlib_cpp,
        shared,
        rdynamic,
        wl,
        pp_or_asm,
        optimize,
        debug,
        sanitize,
        linker_script,
        verbose_cmds,
        for_linker,
        linker_input_z,
        lib_dir,
        mcpu,
        dep_file,
        framework_dir,
        framework,
        nostdlibinc,
    };

    const Args = struct {
        next_index: usize,
        argv: []const []const u8,
    };

    fn init(allocator: *Allocator, argv: []const []const u8) ClangArgIterator {
        return .{
            .next_index = 2, // `zig cc foo` this points to `foo`
            .has_next = argv.len > 2,
            .zig_equivalent = undefined,
            .only_arg = undefined,
            .second_arg = undefined,
            .other_args = undefined,
            .argv = argv,
            .root_args = null,
            .allocator = allocator,
        };
    }

    fn next(self: *ClangArgIterator) !void {
        assert(self.has_next);
        assert(self.next_index < self.argv.len);
        // In this state we know that the parameter we are looking at is a root parameter
        // rather than an argument to a parameter.
        // We adjust the len below when necessary.
        self.other_args = (self.argv.ptr + self.next_index)[0..1];
        var arg = mem.span(self.argv[self.next_index]);
        self.incrementArgIndex();

        if (mem.startsWith(u8, arg, "@")) {
            if (self.root_args != null) return error.NestedResponseFile;

            // This is a "compiler response file". We must parse the file and treat its
            // contents as command line parameters.
            const allocator = self.allocator;
            const max_bytes = 10 * 1024 * 1024; // 10 MiB of command line arguments is a reasonable limit
            const resp_file_path = arg[1..];
            const resp_contents = fs.cwd().readFileAlloc(allocator, resp_file_path, max_bytes) catch |err| {
                fatal("unable to read response file '{}': {}", .{ resp_file_path, @errorName(err) });
            };
            defer allocator.free(resp_contents);
            // TODO is there a specification for this file format? Let's find it and make this parsing more robust
            // at the very least I'm guessing this needs to handle quotes and `#` comments.
            var it = mem.tokenize(resp_contents, " \t\r\n");
            var resp_arg_list = std.ArrayList([]const u8).init(allocator);
            defer resp_arg_list.deinit();
            {
                errdefer {
                    for (resp_arg_list.span()) |item| {
                        allocator.free(mem.span(item));
                    }
                }
                while (it.next()) |token| {
                    const dupe_token = try mem.dupeZ(allocator, u8, token);
                    errdefer allocator.free(dupe_token);
                    try resp_arg_list.append(dupe_token);
                }
                const args = try allocator.create(Args);
                errdefer allocator.destroy(args);
                args.* = .{
                    .next_index = self.next_index,
                    .argv = self.argv,
                };
                self.root_args = args;
            }
            const resp_arg_slice = resp_arg_list.toOwnedSlice();
            self.next_index = 0;
            self.argv = resp_arg_slice;

            if (resp_arg_slice.len == 0) {
                self.resolveRespFileArgs();
                return;
            }

            self.has_next = true;
            self.other_args = (self.argv.ptr + self.next_index)[0..1]; // We adjust len below when necessary.
            arg = mem.span(self.argv[self.next_index]);
            self.incrementArgIndex();
        }
        if (!mem.startsWith(u8, arg, "-")) {
            self.zig_equivalent = .positional;
            self.only_arg = arg;
            return;
        }

        find_clang_arg: for (clang_args) |clang_arg| switch (clang_arg.syntax) {
            .flag => {
                const prefix_len = clang_arg.matchEql(arg);
                if (prefix_len > 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..];

                    break :find_clang_arg;
                }
            },
            .joined, .comma_joined => {
                // joined example: --target=foo
                // comma_joined example: -Wl,-soname,libsoundio.so.2
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..]; // This will skip over the "--target=" part.

                    break :find_clang_arg;
                }
            },
            .joined_or_separate => {
                // Examples: `-lfoo`, `-l foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len == arg.len) {
                    if (self.next_index >= self.argv.len) {
                        fatal("Expected parameter after '{}'", .{arg});
                    }
                    self.only_arg = self.argv[self.next_index];
                    self.incrementArgIndex();
                    self.other_args.len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;

                    break :find_clang_arg;
                } else if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..];

                    break :find_clang_arg;
                }
            },
            .joined_and_separate => {
                // Example: `-Xopenmp-target=riscv64-linux-unknown foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.only_arg = arg[prefix_len..];
                    if (self.next_index >= self.argv.len) {
                        fatal("Expected parameter after '{}'", .{arg});
                    }
                    self.second_arg = self.argv[self.next_index];
                    self.incrementArgIndex();
                    self.other_args.len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    break :find_clang_arg;
                }
            },
            .separate => if (clang_arg.matchEql(arg) > 0) {
                if (self.next_index >= self.argv.len) {
                    fatal("Expected parameter after '{}'", .{arg});
                }
                self.only_arg = self.argv[self.next_index];
                self.incrementArgIndex();
                self.other_args.len += 1;
                self.zig_equivalent = clang_arg.zig_equivalent;
                break :find_clang_arg;
            },
            .remaining_args_joined => {
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    @panic("TODO");
                }
            },
            .multi_arg => if (clang_arg.matchEql(arg) > 0) {
                @panic("TODO");
            },
        }
        else {
            fatal("Unknown Clang option: '{}'", .{arg});
        }
    }

    fn incrementArgIndex(self: *ClangArgIterator) void {
        self.next_index += 1;
        self.resolveRespFileArgs();
    }

    fn resolveRespFileArgs(self: *ClangArgIterator) void {
        const allocator = self.allocator;
        if (self.next_index >= self.argv.len) {
            if (self.root_args) |root_args| {
                self.next_index = root_args.next_index;
                self.argv = root_args.argv;

                allocator.destroy(root_args);
                self.root_args = null;
            }
            if (self.next_index >= self.argv.len) {
                self.has_next = false;
            }
        }
    }
};

fn eqlIgnoreCase(ignore_case: bool, a: []const u8, b: []const u8) bool {
    if (ignore_case) {
        return std.ascii.eqlIgnoreCase(a, b);
    } else {
        return mem.eql(u8, a, b);
    }
}

fn is_libc_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    if (eqlIgnoreCase(ignore_case, name, "c"))
        return true;

    if (target.isMinGW()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;

        return false;
    }

    if (target.abi.isGnu() or target.abi.isMusl() or target.os.tag.isDarwin()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "rt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "pthread"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "crypt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "util"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "xnet"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "resolv"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dl"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "util"))
            return true;
    }

    if (target.os.tag.isDarwin() and eqlIgnoreCase(ignore_case, name, "System"))
        return true;

    return false;
}

fn is_libcpp_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    return eqlIgnoreCase(ignore_case, name, "c++") or
        eqlIgnoreCase(ignore_case, name, "stdc++") or
        eqlIgnoreCase(ignore_case, name, "c++abi");
}

fn parseCodeModel(arg: []const u8) std.builtin.CodeModel {
    return std.meta.stringToEnum(std.builtin.CodeModel, arg) orelse
        fatal("unsupported machine code model: '{}'", .{arg});
}
