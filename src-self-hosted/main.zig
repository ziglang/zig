const std = @import("std");
const mem = std.mem;
const io = std.io;
const os = std.os;
const heap = std.heap;
const warn = std.debug.warn;
const assert = std.debug.assert;
const target = @import("target.zig");
const Target = target.Target;
const Module = @import("module.zig").Module;
const ErrColor = Module.ErrColor;
const Emit = Module.Emit;
const builtin = @import("builtin");
const ArrayList = std.ArrayList;
const c = @import("c.zig");

error InvalidCommandLineArguments;
error ZigLibDirNotFound;
error ZigInstallationNotFound;

const default_zig_cache_name = "zig-cache";

pub fn main() -> %void {
    main2() %% |err| {
        if (err != error.InvalidCommandLineArguments) {
            warn("{}\n", @errorName(err));
        }
        return err;
    };
}

const Cmd = enum {
    None,
    Build,
    Test,
    Version,
    Zen,
    TranslateC,
    Targets,
};

fn badArgs(comptime format: []const u8, args: ...) -> error {
    var stderr = try io.getStdErr();
    var stderr_stream_adapter = io.FileOutStream.init(&stderr);
    const stderr_stream = &stderr_stream_adapter.stream;
    try stderr_stream.print(format ++ "\n\n", args);
    try printUsage(&stderr_stream_adapter.stream);
    return error.InvalidCommandLineArguments;
}

pub fn main2() -> %void {
    const allocator = std.heap.c_allocator;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    var cmd = Cmd.None;
    var build_kind: Module.Kind = undefined;
    var build_mode: builtin.Mode = builtin.Mode.Debug;
    var color = ErrColor.Auto;
    var emit_file_type = Emit.Binary;

    var strip = false;
    var is_static = false;
    var verbose_tokenize = false;
    var verbose_ast_tree = false;
    var verbose_ast_fmt = false;
    var verbose_link = false;
    var verbose_ir = false;
    var verbose_llvm_ir = false;
    var verbose_cimport = false;
    var mwindows = false;
    var mconsole = false;
    var rdynamic = false;
    var each_lib_rpath = false;
    var timing_info = false;

    var in_file_arg: ?[]u8 = null;
    var out_file: ?[]u8 = null;
    var out_file_h: ?[]u8 = null;
    var out_name_arg: ?[]u8 = null;
    var libc_lib_dir_arg: ?[]u8 = null;
    var libc_static_lib_dir_arg: ?[]u8 = null;
    var libc_include_dir_arg: ?[]u8 = null;
    var msvc_lib_dir_arg: ?[]u8 = null;
    var kernel32_lib_dir_arg: ?[]u8 = null;
    var zig_install_prefix: ?[]u8 = null;
    var dynamic_linker_arg: ?[]u8 = null;
    var cache_dir_arg: ?[]const u8 = null;
    var target_arch: ?[]u8 = null;
    var target_os: ?[]u8 = null;
    var target_environ: ?[]u8 = null;
    var mmacosx_version_min: ?[]u8 = null;
    var mios_version_min: ?[]u8 = null;
    var linker_script_arg: ?[]u8 = null;
    var test_name_prefix_arg: ?[]u8 = null;

    var test_filters = ArrayList([]const u8).init(allocator);
    defer test_filters.deinit();

    var lib_dirs = ArrayList([]const u8).init(allocator);
    defer lib_dirs.deinit();

    var clang_argv = ArrayList([]const u8).init(allocator);
    defer clang_argv.deinit();

    var llvm_argv = ArrayList([]const u8).init(allocator);
    defer llvm_argv.deinit();

    var link_libs = ArrayList([]const u8).init(allocator);
    defer link_libs.deinit();

    var frameworks = ArrayList([]const u8).init(allocator);
    defer frameworks.deinit();

    var objects = ArrayList([]const u8).init(allocator);
    defer objects.deinit();

    var asm_files = ArrayList([]const u8).init(allocator);
    defer asm_files.deinit();

    var rpath_list = ArrayList([]const u8).init(allocator);
    defer rpath_list.deinit();

    var ver_major: u32 = 0;
    var ver_minor: u32 = 0;
    var ver_patch: u32 = 0;

    var arg_i: usize = 1;
    while (arg_i < args.len) : (arg_i += 1) {
        const arg = args[arg_i];

        if (arg.len != 0 and arg[0] == '-') {
            if (mem.eql(u8, arg, "--release-fast")) {
                build_mode = builtin.Mode.ReleaseFast;
            } else if (mem.eql(u8, arg, "--release-safe")) {
                build_mode = builtin.Mode.ReleaseSafe;
            } else if (mem.eql(u8, arg, "--strip")) {
                strip = true;
            } else if (mem.eql(u8, arg, "--static")) {
                is_static = true;
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
            } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                verbose_cimport = true;
            } else if (mem.eql(u8, arg, "-mwindows")) {
                mwindows = true;
            } else if (mem.eql(u8, arg, "-mconsole")) {
                mconsole = true;
            } else if (mem.eql(u8, arg, "-rdynamic")) {
                rdynamic = true;
            } else if (mem.eql(u8, arg, "--each-lib-rpath")) {
                each_lib_rpath = true;
            } else if (mem.eql(u8, arg, "--enable-timing-info")) {
                timing_info = true;
            } else if (mem.eql(u8, arg, "--test-cmd-bin")) {
                @panic("TODO --test-cmd-bin");
            } else if (arg[1] == 'L' and arg.len > 2) {
                // alias for --library-path
                try lib_dirs.append(arg[1..]);
            } else if (mem.eql(u8, arg, "--pkg-begin")) {
                @panic("TODO --pkg-begin");
            } else if (mem.eql(u8, arg, "--pkg-end")) {
                @panic("TODO --pkg-end");
            } else if (arg_i + 1 >= args.len) {
                return badArgs("expected another argument after {}", arg);
            } else {
                arg_i += 1;
                if (mem.eql(u8, arg, "--output")) {
                    out_file = args[arg_i];
                } else if (mem.eql(u8, arg, "--output-h")) {
                    out_file_h = args[arg_i];
                } else if (mem.eql(u8, arg, "--color")) {
                    if (mem.eql(u8, args[arg_i], "auto")) {
                        color = ErrColor.Auto;
                    } else if (mem.eql(u8, args[arg_i], "on")) {
                        color = ErrColor.On;
                    } else if (mem.eql(u8, args[arg_i], "off")) {
                        color = ErrColor.Off;
                    } else {
                        return badArgs("--color options are 'auto', 'on', or 'off'");
                    }
                } else if (mem.eql(u8, arg, "--emit")) {
                    if (mem.eql(u8, args[arg_i], "asm")) {
                        emit_file_type = Emit.Assembly;
                    } else if (mem.eql(u8, args[arg_i], "bin")) {
                        emit_file_type = Emit.Binary;
                    } else if (mem.eql(u8, args[arg_i], "llvm-ir")) {
                        emit_file_type = Emit.LlvmIr;
                    } else {
                        return badArgs("--emit options are 'asm', 'bin', or 'llvm-ir'");
                    }
                } else if (mem.eql(u8, arg, "--name")) {
                    out_name_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--libc-lib-dir")) {
                    libc_lib_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--libc-static-lib-dir")) {
                    libc_static_lib_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--libc-include-dir")) {
                    libc_include_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--msvc-lib-dir")) {
                    msvc_lib_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--kernel32-lib-dir")) {
                    kernel32_lib_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--zig-install-prefix")) {
                    zig_install_prefix = args[arg_i];
                } else if (mem.eql(u8, arg, "--dynamic-linker")) {
                    dynamic_linker_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "-isystem")) {
                    try clang_argv.append("-isystem");
                    try clang_argv.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "-dirafter")) {
                    try clang_argv.append("-dirafter");
                    try clang_argv.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "-mllvm")) {
                    try clang_argv.append("-mllvm");
                    try clang_argv.append(args[arg_i]);

                    try llvm_argv.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--library-path") or mem.eql(u8, arg, "-L")) {
                    try lib_dirs.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--library")) {
                    try link_libs.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--object")) {
                    try objects.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--assembly")) {
                    try asm_files.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--cache-dir")) {
                    cache_dir_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--target-arch")) {
                    target_arch = args[arg_i];
                } else if (mem.eql(u8, arg, "--target-os")) {
                    target_os = args[arg_i];
                } else if (mem.eql(u8, arg, "--target-environ")) {
                    target_environ = args[arg_i];
                } else if (mem.eql(u8, arg, "-mmacosx-version-min")) {
                    mmacosx_version_min = args[arg_i];
                } else if (mem.eql(u8, arg, "-mios-version-min")) {
                    mios_version_min = args[arg_i];
                } else if (mem.eql(u8, arg, "-framework")) {
                    try frameworks.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--linker-script")) {
                    linker_script_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "-rpath")) {
                    try rpath_list.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--test-filter")) {
                    try test_filters.append(args[arg_i]);
                } else if (mem.eql(u8, arg, "--test-name-prefix")) {
                    test_name_prefix_arg = args[arg_i];
                } else if (mem.eql(u8, arg, "--ver-major")) {
                    ver_major = try std.fmt.parseUnsigned(u32, args[arg_i], 10);
                } else if (mem.eql(u8, arg, "--ver-minor")) {
                    ver_minor = try std.fmt.parseUnsigned(u32, args[arg_i], 10);
                } else if (mem.eql(u8, arg, "--ver-patch")) {
                    ver_patch = try std.fmt.parseUnsigned(u32, args[arg_i], 10);
                } else if (mem.eql(u8, arg, "--test-cmd")) {
                    @panic("TODO --test-cmd");
                } else {
                    return badArgs("invalid argument: {}", arg);
                }
            }
        } else if (cmd == Cmd.None) {
            if (mem.eql(u8, arg, "build-obj")) {
                cmd = Cmd.Build;
                build_kind = Module.Kind.Obj;
            } else if (mem.eql(u8, arg, "build-exe")) {
                cmd = Cmd.Build;
                build_kind = Module.Kind.Exe;
            } else if (mem.eql(u8, arg, "build-lib")) {
                cmd = Cmd.Build;
                build_kind = Module.Kind.Lib;
            } else if (mem.eql(u8, arg, "version")) {
                cmd = Cmd.Version;
            } else if (mem.eql(u8, arg, "zen")) {
                cmd = Cmd.Zen;
            } else if (mem.eql(u8, arg, "translate-c")) {
                cmd = Cmd.TranslateC;
            } else if (mem.eql(u8, arg, "test")) {
                cmd = Cmd.Test;
                build_kind = Module.Kind.Exe;
            } else {
                return badArgs("unrecognized command: {}", arg);
            }
        } else switch (cmd) {
            Cmd.Build, Cmd.TranslateC, Cmd.Test => {
                if (in_file_arg == null) {
                    in_file_arg = arg;
                } else {
                    return badArgs("unexpected extra parameter: {}", arg);
                }
            },
            Cmd.Version, Cmd.Zen, Cmd.Targets => {
                return badArgs("unexpected extra parameter: {}", arg);
            },
            Cmd.None => unreachable,
        }
    }

    target.initializeAll();

    // TODO
//    ZigTarget alloc_target;
//    ZigTarget *target;
//    if (!target_arch && !target_os && !target_environ) {
//        target = nullptr;
//    } else {
//        target = &alloc_target;
//        get_unknown_target(target);
//        if (target_arch) {
//            if (parse_target_arch(target_arch, &target->arch)) {
//                fprintf(stderr, "invalid --target-arch argument\n");
//                return usage(arg0);
//            }
//        }
//        if (target_os) {
//            if (parse_target_os(target_os, &target->os)) {
//                fprintf(stderr, "invalid --target-os argument\n");
//                return usage(arg0);
//            }
//        }
//        if (target_environ) {
//            if (parse_target_environ(target_environ, &target->env_type)) {
//                fprintf(stderr, "invalid --target-environ argument\n");
//                return usage(arg0);
//            }
//        }
//    }

    switch (cmd) {
        Cmd.None => return badArgs("expected command"),
        Cmd.Zen => return printZen(),
        Cmd.Build, Cmd.Test, Cmd.TranslateC => {
            if (cmd == Cmd.Build and in_file_arg == null and objects.len == 0 and asm_files.len == 0) {
                return badArgs("expected source file argument or at least one --object or --assembly argument");
            } else if ((cmd == Cmd.TranslateC or cmd == Cmd.Test) and in_file_arg == null) {
                return badArgs("expected source file argument");
            } else if (cmd == Cmd.Build and build_kind == Module.Kind.Obj and objects.len != 0) {
                return badArgs("When building an object file, --object arguments are invalid");
            }

            const root_name = switch (cmd) {
                Cmd.Build, Cmd.TranslateC => x: {
                    if (out_name_arg) |out_name| {
                        break :x out_name;
                    } else if (in_file_arg) |in_file_path| {
                        const basename = os.path.basename(in_file_path);
                        var it = mem.split(basename, ".");
                        break :x it.next() ?? return badArgs("file name cannot be empty");
                    } else {
                        return badArgs("--name [name] not provided and unable to infer");
                    }
                },
                Cmd.Test => "test",
                else => unreachable,
            };

            const zig_root_source_file = if (cmd == Cmd.TranslateC) null else in_file_arg;

            const chosen_cache_dir = cache_dir_arg ?? default_zig_cache_name;
            const full_cache_dir = try os.path.resolve(allocator, ".", chosen_cache_dir);
            defer allocator.free(full_cache_dir);

            const zig_lib_dir = try resolveZigLibDir(allocator, zig_install_prefix);
            %defer allocator.free(zig_lib_dir);

            const module = try Module.create(allocator, root_name, zig_root_source_file,
                Target.Native, build_kind, build_mode, zig_lib_dir, full_cache_dir);
            defer module.destroy();

            module.version_major = ver_major;
            module.version_minor = ver_minor;
            module.version_patch = ver_patch;

            module.is_test = cmd == Cmd.Test;
            if (linker_script_arg) |linker_script| {
                module.linker_script = linker_script;
            }
            module.each_lib_rpath = each_lib_rpath;
            module.clang_argv = clang_argv.toSliceConst();
            module.llvm_argv = llvm_argv.toSliceConst();
            module.strip = strip;
            module.is_static = is_static;

            if (libc_lib_dir_arg) |libc_lib_dir| {
                module.libc_lib_dir = libc_lib_dir;
            }
            if (libc_static_lib_dir_arg) |libc_static_lib_dir| {
                module.libc_static_lib_dir = libc_static_lib_dir;
            }
            if (libc_include_dir_arg) |libc_include_dir| {
                module.libc_include_dir = libc_include_dir;
            }
            if (msvc_lib_dir_arg) |msvc_lib_dir| {
                module.msvc_lib_dir = msvc_lib_dir;
            }
            if (kernel32_lib_dir_arg) |kernel32_lib_dir| {
                module.kernel32_lib_dir = kernel32_lib_dir;
            }
            if (dynamic_linker_arg) |dynamic_linker| {
                module.dynamic_linker = dynamic_linker;
            }
            module.verbose_tokenize = verbose_tokenize;
            module.verbose_ast_tree = verbose_ast_tree;
            module.verbose_ast_fmt = verbose_ast_fmt;
            module.verbose_link = verbose_link;
            module.verbose_ir = verbose_ir;
            module.verbose_llvm_ir = verbose_llvm_ir;
            module.verbose_cimport = verbose_cimport;

            module.err_color = color;

            module.lib_dirs = lib_dirs.toSliceConst();
            module.darwin_frameworks = frameworks.toSliceConst();
            module.rpath_list = rpath_list.toSliceConst();

            for (link_libs.toSliceConst()) |name| {
                _ = try module.addLinkLib(name, true);
            }

            module.windows_subsystem_windows = mwindows;
            module.windows_subsystem_console = mconsole;
            module.linker_rdynamic = rdynamic;

            if (mmacosx_version_min != null and mios_version_min != null) {
                return badArgs("-mmacosx-version-min and -mios-version-min options not allowed together");
            }

            if (mmacosx_version_min) |ver| {
                module.darwin_version_min = Module.DarwinVersionMin { .MacOS = ver };
            } else if (mios_version_min) |ver| {
                module.darwin_version_min = Module.DarwinVersionMin { .Ios = ver };
            }

            module.test_filters = test_filters.toSliceConst();
            module.test_name_prefix = test_name_prefix_arg;
            module.out_h_path = out_file_h;

            // TODO
            //add_package(g, cur_pkg, g->root_package);

            switch (cmd) {
                Cmd.Build => {
                    module.emit_file_type = emit_file_type;

                    module.link_objects = objects.toSliceConst();
                    module.assembly_files = asm_files.toSliceConst();

                    try module.build();
                    try module.link(out_file);
                },
                Cmd.TranslateC => @panic("TODO translate-c"),
                Cmd.Test => @panic("TODO test cmd"),
                else => unreachable,
            }
        },
        Cmd.Version => {
            var stdout_file = try io.getStdErr();
            try stdout_file.write(std.cstr.toSliceConst(c.ZIG_VERSION_STRING));
            try stdout_file.write("\n");
        },
        Cmd.Targets => @panic("TODO zig targets"),
    }
}

fn printUsage(stream: &io.OutStream) -> %void {
    try stream.write(
        \\Usage: zig [command] [options]
        \\
        \\Commands:
        \\  build                        build project from build.zig
        \\  build-exe [source]           create executable from source or object files
        \\  build-lib [source]           create library from source or object files
        \\  build-obj [source]           create object from source or assembly
        \\  translate-c [source]         convert c code to zig code
        \\  targets                      list available compilation targets
        \\  test [source]                create and run a test build
        \\  version                      print version number and exit
        \\  zen                          print zen of zig and exit
        \\Compile Options:
        \\  --assembly [source]          add assembly file to build
        \\  --cache-dir [path]           override the cache directory
        \\  --color [auto|off|on]        enable or disable colored error messages
        \\  --emit [filetype]            emit a specific file format as compilation output
        \\  --enable-timing-info         print timing diagnostics
        \\  --libc-include-dir [path]    directory where libc stdlib.h resides
        \\  --name [name]                override output name
        \\  --output [file]              override destination path
        \\  --output-h [file]            override generated header file path
        \\  --pkg-begin [name] [path]    make package available to import and push current pkg
        \\  --pkg-end                    pop current pkg
        \\  --release-fast               build with optimizations on and safety off
        \\  --release-safe               build with optimizations on and safety on
        \\  --static                     output will be statically linked
        \\  --strip                      exclude debug symbols
        \\  --target-arch [name]         specify target architecture
        \\  --target-environ [name]      specify target environment
        \\  --target-os [name]           specify target operating system
        \\  --verbose-tokenize           enable compiler debug info: tokenization
        \\  --verbose-ast-tree           enable compiler debug info: parsing into an AST (treeview)
        \\  --verbose-ast-fmt            enable compiler debug info: parsing into an AST (render source)
        \\  --verbose-cimport            enable compiler debug info: C imports
        \\  --verbose-ir                 enable compiler debug info: Zig IR
        \\  --verbose-llvm-ir            enable compiler debug info: LLVM IR
        \\  --verbose-link               enable compiler debug info: linking
        \\  --zig-install-prefix [path]  override directory where zig thinks it is installed
        \\  -dirafter [dir]              same as -isystem but do it last
        \\  -isystem [dir]               add additional search path for other .h files
        \\  -mllvm [arg]                 additional arguments to forward to LLVM's option processing
        \\Link Options:
        \\  --ar-path [path]             set the path to ar
        \\  --dynamic-linker [path]      set the path to ld.so
        \\  --each-lib-rpath             add rpath for each used dynamic library
        \\  --libc-lib-dir [path]        directory where libc crt1.o resides
        \\  --libc-static-lib-dir [path] directory where libc crtbegin.o resides
        \\  --msvc-lib-dir [path]        (windows) directory where vcruntime.lib resides
        \\  --kernel32-lib-dir [path]    (windows) directory where kernel32.lib resides
        \\  --library [lib]              link against lib
        \\  --library-path [dir]         add a directory to the library search path
        \\  --linker-script [path]       use a custom linker script
        \\  --object [obj]               add object file to build
        \\  -L[dir]                      alias for --library-path
        \\  -rdynamic                    add all symbols to the dynamic symbol table
        \\  -rpath [path]                add directory to the runtime library search path
        \\  -mconsole                    (windows) --subsystem console to the linker
        \\  -mwindows                    (windows) --subsystem windows to the linker
        \\  -framework [name]            (darwin) link against framework
        \\  -mios-version-min [ver]      (darwin) set iOS deployment target
        \\  -mmacosx-version-min [ver]   (darwin) set Mac OS X deployment target
        \\  --ver-major [ver]            dynamic library semver major version
        \\  --ver-minor [ver]            dynamic library semver minor version
        \\  --ver-patch [ver]            dynamic library semver patch version
        \\Test Options:
        \\  --test-filter [text]         skip tests that do not match filter
        \\  --test-name-prefix [text]    add prefix to all tests
        \\  --test-cmd [arg]             specify test execution command one arg at a time
        \\  --test-cmd-bin               appends test binary path to test cmd args
        \\
    );
}

fn printZen() -> %void {
    var stdout_file = try io.getStdErr();
    try stdout_file.write(
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
    );
}

/// Caller must free result
fn resolveZigLibDir(allocator: &mem.Allocator, zig_install_prefix_arg: ?[]const u8) -> %[]u8 {
    if (zig_install_prefix_arg) |zig_install_prefix| {
        return testZigInstallPrefix(allocator, zig_install_prefix) %% |err| {
            warn("No Zig installation found at prefix {}: {}\n", zig_install_prefix_arg, @errorName(err));
            return error.ZigInstallationNotFound;
        };
    } else {
        return findZigLibDir(allocator) %% |err| {
            warn("Unable to find zig lib directory: {}.\nReinstall Zig or use --zig-install-prefix.\n",
                @errorName(err));
            return error.ZigLibDirNotFound;
        };
    }
}

/// Caller must free result
fn testZigInstallPrefix(allocator: &mem.Allocator, test_path: []const u8) -> %[]u8 {
    const test_zig_dir = try os.path.join(allocator, test_path, "lib", "zig");
    %defer allocator.free(test_zig_dir);

    const test_index_file = try os.path.join(allocator, test_zig_dir, "std", "index.zig");
    defer allocator.free(test_index_file);

    var file = try io.File.openRead(test_index_file, allocator);
    file.close();

    return test_zig_dir;
}

/// Caller must free result
fn findZigLibDir(allocator: &mem.Allocator) -> %[]u8 {
    const self_exe_path = try os.selfExeDirPath(allocator);
    defer allocator.free(self_exe_path);

    var cur_path: []const u8 = self_exe_path;
    while (true) {
        const test_dir = os.path.dirname(cur_path);

        if (mem.eql(u8, test_dir, cur_path)) {
            break;
        }

        return testZigInstallPrefix(allocator, test_dir) %% |err| {
            cur_path = test_dir;
            continue;
        };
    }

    // TODO look in hard coded installation path from configuration
    //if (ZIG_INSTALL_PREFIX != nullptr) {
    //    if (test_zig_install_prefix(buf_create_from_str(ZIG_INSTALL_PREFIX), out_path)) {
    //        return 0;
    //    }
    //}

    return error.FileNotFound;
}

test "import tests" {
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
}
