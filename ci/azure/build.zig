const std = @import("std");
const builtin = std.builtin;
const Builder = std.build.Builder;
const BufMap = std.BufMap;
const mem = std.mem;
const ArrayList = std.ArrayList;
const io = std.io;
const fs = std.fs;
const InstallDirectoryOptions = std.build.InstallDirectoryOptions;
const assert = std.debug.assert;

const zig_version = std.builtin.Version{ .major = 0, .minor = 10, .patch = 0 };

pub fn build(b: *Builder) !void {
    b.setPreferredReleaseMode(.ReleaseFast);
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});
    const single_threaded = b.option(bool, "single-threaded", "Build artifacts that run in single threaded mode");
    const use_zig_libcxx = b.option(bool, "use-zig-libcxx", "If libc++ is needed, use zig's bundled version, don't try to integrate with the system") orelse false;

    const docgen_exe = b.addExecutable("docgen", "doc/docgen.zig");
    docgen_exe.single_threaded = single_threaded;

    const rel_zig_exe = try fs.path.relative(b.allocator, b.build_root, b.zig_exe);
    const langref_out_path = fs.path.join(
        b.allocator,
        &[_][]const u8{ b.cache_root, "langref.html" },
    ) catch unreachable;
    const docgen_cmd = docgen_exe.run();
    docgen_cmd.addArgs(&[_][]const u8{
        rel_zig_exe,
        "doc" ++ fs.path.sep_str ++ "langref.html.in",
        langref_out_path,
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);

    const is_stage1 = b.option(bool, "stage1", "Build the stage1 compiler, put stage2 behind a feature flag") orelse false;
    const omit_stage2 = b.option(bool, "omit-stage2", "Do not include stage2 behind a feature flag inside stage1") orelse false;
    const static_llvm = b.option(bool, "static-llvm", "Disable integration with system-installed LLVM, Clang, LLD, and libc++") orelse false;
    const enable_llvm = b.option(bool, "enable-llvm", "Build self-hosted compiler with LLVM backend enabled") orelse (is_stage1 or static_llvm);
    const llvm_has_m68k = b.option(
        bool,
        "llvm-has-m68k",
        "Whether LLVM has the experimental target m68k enabled",
    ) orelse false;
    const llvm_has_csky = b.option(
        bool,
        "llvm-has-csky",
        "Whether LLVM has the experimental target csky enabled",
    ) orelse false;
    const llvm_has_arc = b.option(
        bool,
        "llvm-has-arc",
        "Whether LLVM has the experimental target arc enabled",
    ) orelse false;
    const config_h_path_option = b.option([]const u8, "config_h", "Path to the generated config.h");

    b.installDirectory(InstallDirectoryOptions{
        .source_dir = "lib",
        .install_dir = .lib,
        .install_subdir = "zig",
        .exclude_extensions = &[_][]const u8{
            // exclude files from lib/std/compress/
            ".gz",
            ".z.0",
            ".z.9",
            "rfc1951.txt",
            "rfc1952.txt",
            // exclude files from lib/std/compress/deflate/testdata
            ".expect",
            ".expect-noinput",
            ".golden",
            ".input",
            "compress-e.txt",
            "compress-gettysburg.txt",
            "compress-pi.txt",
            "rfc1951.txt",
            // exclude files from lib/std/tz/
            ".tzif",
            // others
            "README.md",
        },
        .blank_extensions = &[_][]const u8{
            "test.zig",
        },
    });

    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const tracy_callstack = b.option(bool, "tracy-callstack", "Include callstack information with Tracy data. Does nothing if -Dtracy is not provided") orelse false;
    const tracy_allocation = b.option(bool, "tracy-allocation", "Include allocation information with Tracy data. Does nothing if -Dtracy is not provided") orelse false;
    const force_gpa = b.option(bool, "force-gpa", "Force the compiler to use GeneralPurposeAllocator") orelse false;
    const link_libc = b.option(bool, "force-link-libc", "Force self-hosted compiler to link libc") orelse enable_llvm;
    const strip = b.option(bool, "strip", "Omit debug information") orelse false;
    const value_tracing = b.option(bool, "value-tracing", "Enable extra state tracking to help troubleshoot bugs in the compiler (using the std.debug.Trace API)") orelse false;

    const mem_leak_frames: u32 = b.option(u32, "mem-leak-frames", "How many stack frames to print when a memory leak occurs. Tests get 2x this amount.") orelse blk: {
        if (strip) break :blk @as(u32, 0);
        if (mode != .Debug) break :blk 0;
        break :blk 4;
    };

    const main_file: ?[]const u8 = if (is_stage1) null else "src/main.zig";

    const exe = b.addExecutable("zig", main_file);
    exe.strip = strip;
    exe.install();
    exe.setBuildMode(mode);
    exe.setTarget(target);

    b.default_step.dependOn(&exe.step);
    exe.single_threaded = single_threaded;

    if (target.isWindows() and target.getAbi() == .gnu) {
        // LTO is currently broken on mingw, this can be removed when it's fixed.
        exe.want_lto = false;
    }

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);

    exe_options.addOption(u32, "mem_leak_frames", mem_leak_frames);
    exe_options.addOption(bool, "skip_non_native", false);
    exe_options.addOption(bool, "have_llvm", enable_llvm);
    exe_options.addOption(bool, "llvm_has_m68k", llvm_has_m68k);
    exe_options.addOption(bool, "llvm_has_csky", llvm_has_csky);
    exe_options.addOption(bool, "llvm_has_arc", llvm_has_arc);
    exe_options.addOption(bool, "force_gpa", force_gpa);

    if (link_libc) {
        exe.linkLibC();
    }

    const is_debug = mode == .Debug;
    const enable_logging = b.option(bool, "log", "Enable debug logging with --debug-log") orelse is_debug;
    const enable_link_snapshots = b.option(bool, "link-snapshot", "Whether to enable linker state snapshots") orelse false;

    const opt_version_string = b.option([]const u8, "version-string", "Override Zig version string. Default is to find out with git.");
    const version = if (opt_version_string) |version| version else v: {
        const version_string = b.fmt("{d}.{d}.{d}", .{ zig_version.major, zig_version.minor, zig_version.patch });

        var code: u8 = undefined;
        const git_describe_untrimmed = b.execAllowFail(&[_][]const u8{
            "git", "-C", b.build_root, "describe", "--match", "*.*.*", "--tags",
        }, &code, .Ignore) catch {
            break :v version_string;
        };
        const git_describe = mem.trim(u8, git_describe_untrimmed, " \n\r");

        switch (mem.count(u8, git_describe, "-")) {
            0 => {
                // Tagged release version (e.g. 0.9.0).
                if (!mem.eql(u8, git_describe, version_string)) {
                    std.debug.print("Zig version '{s}' does not match Git tag '{s}'\n", .{ version_string, git_describe });
                    std.process.exit(1);
                }
                break :v version_string;
            },
            2 => {
                // Untagged development build (e.g. 0.9.0-dev.2025+ecf0050a9).
                var it = mem.split(u8, git_describe, "-");
                const tagged_ancestor = it.next() orelse unreachable;
                const commit_height = it.next() orelse unreachable;
                const commit_id = it.next() orelse unreachable;

                const ancestor_ver = try std.builtin.Version.parse(tagged_ancestor);
                if (zig_version.order(ancestor_ver) != .gt) {
                    std.debug.print("Zig version '{}' must be greater than tagged ancestor '{}'\n", .{ zig_version, ancestor_ver });
                    std.process.exit(1);
                }

                // Check that the commit hash is prefixed with a 'g' (a Git convention).
                if (commit_id.len < 1 or commit_id[0] != 'g') {
                    std.debug.print("Unexpected `git describe` output: {s}\n", .{git_describe});
                    break :v version_string;
                }

                // The version is reformatted in accordance with the https://semver.org specification.
                break :v b.fmt("{s}-dev.{s}+{s}", .{ version_string, commit_height, commit_id[1..] });
            },
            else => {
                std.debug.print("Unexpected `git describe` output: {s}\n", .{git_describe});
                break :v version_string;
            },
        }
    };
    exe_options.addOption([:0]const u8, "version", try b.allocator.dupeZ(u8, version));

    if (enable_llvm) {
        const cmake_cfg = if (static_llvm) null else findAndParseConfigH(b, config_h_path_option);

        if (is_stage1) {
            const softfloat = b.addStaticLibrary("softfloat", null);
            softfloat.setBuildMode(.ReleaseFast);
            softfloat.setTarget(target);
            softfloat.addIncludeDir("deps/SoftFloat-3e-prebuilt");
            softfloat.addIncludeDir("deps/SoftFloat-3e/source/8086");
            softfloat.addIncludeDir("deps/SoftFloat-3e/source/include");
            softfloat.addCSourceFiles(&softfloat_sources, &[_][]const u8{ "-std=c99", "-O3" });
            softfloat.single_threaded = single_threaded;

            const zig0 = b.addExecutable("zig0", null);
            zig0.addCSourceFiles(&.{"src/stage1/zig0.cpp"}, &exe_cflags);
            zig0.addIncludeDir("zig-cache/tmp"); // for config.h
            zig0.defineCMacro("ZIG_VERSION_MAJOR", b.fmt("{d}", .{zig_version.major}));
            zig0.defineCMacro("ZIG_VERSION_MINOR", b.fmt("{d}", .{zig_version.minor}));
            zig0.defineCMacro("ZIG_VERSION_PATCH", b.fmt("{d}", .{zig_version.patch}));
            zig0.defineCMacro("ZIG_VERSION_STRING", b.fmt("\"{s}\"", .{version}));

            for ([_]*std.build.LibExeObjStep{ zig0, exe }) |artifact| {
                artifact.addIncludeDir("src");
                artifact.addIncludeDir("deps/SoftFloat-3e/source/include");
                artifact.addIncludeDir("deps/SoftFloat-3e-prebuilt");

                artifact.defineCMacro("ZIG_LINK_MODE", "Static");

                artifact.addCSourceFiles(&stage1_sources, &exe_cflags);
                artifact.addCSourceFiles(&optimized_c_sources, &[_][]const u8{ "-std=c99", "-O3" });

                artifact.linkLibrary(softfloat);
                artifact.linkLibCpp();
            }

            try addStaticLlvmOptionsToExe(zig0);

            const zig1_obj_ext = target.getObjectFormat().fileExt(target.getCpuArch());
            const zig1_obj_path = b.pathJoin(&.{ "zig-cache", "tmp", b.fmt("zig1{s}", .{zig1_obj_ext}) });
            const zig1_compiler_rt_path = b.pathJoin(&.{ b.pathFromRoot("lib"), "std", "special", "compiler_rt.zig" });

            const zig1_obj = zig0.run();
            zig1_obj.addArgs(&.{
                "src/stage1.zig",
                "-target",
                try target.zigTriple(b.allocator),
                "-mcpu=baseline",
                "--name",
                "zig1",
                "--zig-lib-dir",
                b.pathFromRoot("lib"),
                b.fmt("-femit-bin={s}", .{b.pathFromRoot(zig1_obj_path)}),
                "-fcompiler-rt",
                "-lc",
            });
            {
                zig1_obj.addArgs(&.{ "--pkg-begin", "build_options" });
                zig1_obj.addFileSourceArg(exe_options.getSource());
                zig1_obj.addArgs(&.{ "--pkg-end", "--pkg-begin", "compiler_rt", zig1_compiler_rt_path, "--pkg-end" });
            }
            switch (mode) {
                .Debug => {},
                .ReleaseFast => {
                    zig1_obj.addArg("-OReleaseFast");
                    zig1_obj.addArg("--strip");
                },
                .ReleaseSafe => {
                    zig1_obj.addArg("-OReleaseSafe");
                    zig1_obj.addArg("--strip");
                },
                .ReleaseSmall => {
                    zig1_obj.addArg("-OReleaseSmall");
                    zig1_obj.addArg("--strip");
                },
            }
            if (single_threaded orelse false) {
                zig1_obj.addArg("-fsingle-threaded");
            }

            exe.step.dependOn(&zig1_obj.step);
            exe.addObjectFile(zig1_obj_path);

            // This is intentionally a dummy path. stage1.zig tries to @import("compiler_rt") in case
            // of being built by cmake. But when built by zig it's gonna get a compiler_rt so that
            // is pointless.
            exe.addPackagePath("compiler_rt", "src/empty.zig");
        }
        if (cmake_cfg) |cfg| {
            // Inside this code path, we have to coordinate with system packaged LLVM, Clang, and LLD.
            // That means we also have to rely on stage1 compiled c++ files. We parse config.h to find
            // the information passed on to us from cmake.
            if (cfg.cmake_prefix_path.len > 0) {
                b.addSearchPrefix(cfg.cmake_prefix_path);
            }

            try addCmakeCfgOptionsToExe(b, cfg, exe, use_zig_libcxx);
        } else {
            // Here we are -Denable-llvm but no cmake integration.
            try addStaticLlvmOptionsToExe(exe);
        }
    }

    const semver = try std.SemanticVersion.parse(version);
    exe_options.addOption(std.SemanticVersion, "semver", semver);

    exe_options.addOption(bool, "enable_logging", enable_logging);
    exe_options.addOption(bool, "enable_link_snapshots", enable_link_snapshots);
    exe_options.addOption(bool, "enable_tracy", tracy != null);
    exe_options.addOption(bool, "enable_tracy_callstack", tracy_callstack);
    exe_options.addOption(bool, "enable_tracy_allocation", tracy_allocation);
    exe_options.addOption(bool, "value_tracing", value_tracing);
    exe_options.addOption(bool, "is_stage1", is_stage1);
    exe_options.addOption(bool, "omit_stage2", omit_stage2);
    if (tracy) |tracy_path| {
        const client_cpp = fs.path.join(
            b.allocator,
            &[_][]const u8{ tracy_path, "TracyClient.cpp" },
        ) catch unreachable;

        // On mingw, we need to opt into windows 7+ to get some features required by tracy.
        const tracy_c_flags: []const []const u8 = if (target.isWindows() and target.getAbi() == .gnu)
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined", "-D_WIN32_WINNT=0x601" }
        else
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" };

        exe.addIncludeDir(tracy_path);
        exe.addCSourceFile(client_cpp, tracy_c_flags);
        if (!enable_llvm) {
            exe.linkSystemLibraryName("c++");
        }
        exe.linkLibC();

        if (target.isWindows()) {
            exe.linkSystemLibrary("dbghelp");
            exe.linkSystemLibrary("ws2_32");
        }
    }
}

const exe_cflags = [_][]const u8{
    "-std=c++14",
    "-D__STDC_CONSTANT_MACROS",
    "-D__STDC_FORMAT_MACROS",
    "-D__STDC_LIMIT_MACROS",
    "-D_GNU_SOURCE",
    "-fvisibility-inlines-hidden",
    "-fno-exceptions",
    "-fno-rtti",
    "-Werror=type-limits",
    "-Wno-missing-braces",
    "-Wno-comment",
};

fn addCmakeCfgOptionsToExe(
    b: *Builder,
    cfg: CMakeConfig,
    exe: *std.build.LibExeObjStep,
    use_zig_libcxx: bool,
) !void {
    exe.addObjectFile(fs.path.join(b.allocator, &[_][]const u8{
        cfg.cmake_binary_dir,
        "zigcpp",
        b.fmt("{s}{s}{s}", .{ exe.target.libPrefix(), "zigcpp", exe.target.staticLibSuffix() }),
    }) catch unreachable);
    assert(cfg.lld_include_dir.len != 0);
    exe.addIncludeDir(cfg.lld_include_dir);
    addCMakeLibraryList(exe, cfg.clang_libraries);
    addCMakeLibraryList(exe, cfg.lld_libraries);
    addCMakeLibraryList(exe, cfg.llvm_libraries);

    if (use_zig_libcxx) {
        exe.linkLibCpp();
    } else {
        const need_cpp_includes = true;

        // System -lc++ must be used because in this code path we are attempting to link
        // against system-provided LLVM, Clang, LLD.
        if (exe.target.getOsTag() == .linux) {
            // First we try to static link against gcc libstdc++. If that doesn't work,
            // we fall back to -lc++ and cross our fingers.
            addCxxKnownPath(b, cfg, exe, "libstdc++.a", "", need_cpp_includes) catch |err| switch (err) {
                error.RequiredLibraryNotFound => {
                    exe.linkSystemLibrary("c++");
                },
                else => |e| return e,
            };
            exe.linkSystemLibrary("unwind");
        } else if (exe.target.isFreeBSD()) {
            try addCxxKnownPath(b, cfg, exe, "libc++.a", null, need_cpp_includes);
            exe.linkSystemLibrary("pthread");
        } else if (exe.target.getOsTag() == .openbsd) {
            try addCxxKnownPath(b, cfg, exe, "libc++.a", null, need_cpp_includes);
            try addCxxKnownPath(b, cfg, exe, "libc++abi.a", null, need_cpp_includes);
        } else if (exe.target.isDarwin()) {
            exe.linkSystemLibrary("c++");
        }
    }

    if (cfg.dia_guids_lib.len != 0) {
        exe.addObjectFile(cfg.dia_guids_lib);
    }
}

fn addStaticLlvmOptionsToExe(
    exe: *std.build.LibExeObjStep,
) !void {
    // Adds the Zig C++ sources which both stage1 and stage2 need.
    //
    // We need this because otherwise zig_clang_cc1_main.cpp ends up pulling
    // in a dependency on llvm::cfg::Update<llvm::BasicBlock*>::dump() which is
    // unavailable when LLVM is compiled in Release mode.
    const zig_cpp_cflags = exe_cflags ++ [_][]const u8{"-DNDEBUG=1"};
    exe.addCSourceFiles(&zig_cpp_sources, &zig_cpp_cflags);

    for (clang_libs) |lib_name| {
        exe.linkSystemLibrary(lib_name);
    }

    for (lld_libs) |lib_name| {
        exe.linkSystemLibrary(lib_name);
    }

    for (llvm_libs) |lib_name| {
        exe.linkSystemLibrary(lib_name);
    }

    exe.linkSystemLibrary("z");

    // This means we rely on clang-or-zig-built LLVM, Clang, LLD libraries.
    exe.linkSystemLibrary("c++");

    if (exe.target.getOs().tag == .windows) {
        exe.linkSystemLibrary("version");
        exe.linkSystemLibrary("uuid");
        exe.linkSystemLibrary("ole32");
    }
}

fn addCxxKnownPath(
    b: *Builder,
    ctx: CMakeConfig,
    exe: *std.build.LibExeObjStep,
    objname: []const u8,
    errtxt: ?[]const u8,
    need_cpp_includes: bool,
) !void {
    const path_padded = try b.exec(&[_][]const u8{
        ctx.cxx_compiler,
        b.fmt("-print-file-name={s}", .{objname}),
    });
    const path_unpadded = mem.tokenize(u8, path_padded, "\r\n").next().?;
    if (mem.eql(u8, path_unpadded, objname)) {
        if (errtxt) |msg| {
            std.debug.print("{s}", .{msg});
        } else {
            std.debug.print("Unable to determine path to {s}\n", .{objname});
        }
        return error.RequiredLibraryNotFound;
    }
    exe.addObjectFile(path_unpadded);

    // TODO a way to integrate with system c++ include files here
    // cc -E -Wp,-v -xc++ /dev/null
    if (need_cpp_includes) {
        // I used these temporarily for testing something but we obviously need a
        // more general purpose solution here.
        //exe.addIncludeDir("/nix/store/fvf3qjqa5qpcjjkq37pb6ypnk1mzhf5h-gcc-9.3.0/lib/gcc/x86_64-unknown-linux-gnu/9.3.0/../../../../include/c++/9.3.0");
        //exe.addIncludeDir("/nix/store/fvf3qjqa5qpcjjkq37pb6ypnk1mzhf5h-gcc-9.3.0/lib/gcc/x86_64-unknown-linux-gnu/9.3.0/../../../../include/c++/9.3.0/x86_64-unknown-linux-gnu");
        //exe.addIncludeDir("/nix/store/fvf3qjqa5qpcjjkq37pb6ypnk1mzhf5h-gcc-9.3.0/lib/gcc/x86_64-unknown-linux-gnu/9.3.0/../../../../include/c++/9.3.0/backward");
    }
}

fn addCMakeLibraryList(exe: *std.build.LibExeObjStep, list: []const u8) void {
    var it = mem.tokenize(u8, list, ";");
    while (it.next()) |lib| {
        if (mem.startsWith(u8, lib, "-l")) {
            exe.linkSystemLibrary(lib["-l".len..]);
        } else {
            exe.addObjectFile(lib);
        }
    }
}

const CMakeConfig = struct {
    cmake_binary_dir: []const u8,
    cmake_prefix_path: []const u8,
    cxx_compiler: []const u8,
    lld_include_dir: []const u8,
    lld_libraries: []const u8,
    clang_libraries: []const u8,
    llvm_libraries: []const u8,
    dia_guids_lib: []const u8,
};

const max_config_h_bytes = 1 * 1024 * 1024;

fn findAndParseConfigH(b: *Builder, config_h_path_option: ?[]const u8) ?CMakeConfig {
    const config_h_text: []const u8 = if (config_h_path_option) |config_h_path| blk: {
        break :blk fs.cwd().readFileAlloc(b.allocator, config_h_path, max_config_h_bytes) catch unreachable;
    } else blk: {
        // TODO this should stop looking for config.h once it detects we hit the
        // zig source root directory.
        var check_dir = fs.path.dirname(b.zig_exe).?;
        while (true) {
            var dir = fs.cwd().openDir(check_dir, .{}) catch unreachable;
            defer dir.close();

            break :blk dir.readFileAlloc(b.allocator, "config.h", max_config_h_bytes) catch |err| switch (err) {
                error.FileNotFound => {
                    const new_check_dir = fs.path.dirname(check_dir);
                    if (new_check_dir == null or mem.eql(u8, new_check_dir.?, check_dir)) {
                        return null;
                    }
                    check_dir = new_check_dir.?;
                    continue;
                },
                else => unreachable,
            };
        } else unreachable; // TODO should not need `else unreachable`.
    };

    var ctx: CMakeConfig = .{
        .cmake_binary_dir = undefined,
        .cmake_prefix_path = undefined,
        .cxx_compiler = undefined,
        .lld_include_dir = undefined,
        .lld_libraries = undefined,
        .clang_libraries = undefined,
        .llvm_libraries = undefined,
        .dia_guids_lib = undefined,
    };

    const mappings = [_]struct { prefix: []const u8, field: []const u8 }{
        .{
            .prefix = "#define ZIG_CMAKE_BINARY_DIR ",
            .field = "cmake_binary_dir",
        },
        .{
            .prefix = "#define ZIG_CMAKE_PREFIX_PATH ",
            .field = "cmake_prefix_path",
        },
        .{
            .prefix = "#define ZIG_CXX_COMPILER ",
            .field = "cxx_compiler",
        },
        .{
            .prefix = "#define ZIG_LLD_INCLUDE_PATH ",
            .field = "lld_include_dir",
        },
        .{
            .prefix = "#define ZIG_LLD_LIBRARIES ",
            .field = "lld_libraries",
        },
        .{
            .prefix = "#define ZIG_CLANG_LIBRARIES ",
            .field = "clang_libraries",
        },
        .{
            .prefix = "#define ZIG_LLVM_LIBRARIES ",
            .field = "llvm_libraries",
        },
        .{
            .prefix = "#define ZIG_DIA_GUIDS_LIB ",
            .field = "dia_guids_lib",
        },
    };

    var lines_it = mem.tokenize(u8, config_h_text, "\r\n");
    while (lines_it.next()) |line| {
        inline for (mappings) |mapping| {
            if (mem.startsWith(u8, line, mapping.prefix)) {
                var it = mem.split(u8, line, "\"");
                _ = it.next().?; // skip the stuff before the quote
                const quoted = it.next().?; // the stuff inside the quote
                @field(ctx, mapping.field) = toNativePathSep(b, quoted);
            }
        }
    }
    return ctx;
}

fn toNativePathSep(b: *Builder, s: []const u8) []u8 {
    const duplicated = b.allocator.dupe(u8, s) catch unreachable;
    for (duplicated) |*byte| switch (byte.*) {
        '/' => byte.* = fs.path.sep,
        else => {},
    };
    return duplicated;
}

const softfloat_sources = [_][]const u8{
    "deps/SoftFloat-3e/source/8086/f128M_isSignalingNaN.c",
    "deps/SoftFloat-3e/source/8086/extF80M_isSignalingNaN.c",
    "deps/SoftFloat-3e/source/8086/s_commonNaNToF128M.c",
    "deps/SoftFloat-3e/source/8086/s_commonNaNToExtF80M.c",
    "deps/SoftFloat-3e/source/8086/s_commonNaNToF16UI.c",
    "deps/SoftFloat-3e/source/8086/s_commonNaNToF32UI.c",
    "deps/SoftFloat-3e/source/8086/s_commonNaNToF64UI.c",
    "deps/SoftFloat-3e/source/8086/s_f128MToCommonNaN.c",
    "deps/SoftFloat-3e/source/8086/s_extF80MToCommonNaN.c",
    "deps/SoftFloat-3e/source/8086/s_f16UIToCommonNaN.c",
    "deps/SoftFloat-3e/source/8086/s_f32UIToCommonNaN.c",
    "deps/SoftFloat-3e/source/8086/s_f64UIToCommonNaN.c",
    "deps/SoftFloat-3e/source/8086/s_propagateNaNF128M.c",
    "deps/SoftFloat-3e/source/8086/s_propagateNaNExtF80M.c",
    "deps/SoftFloat-3e/source/8086/s_propagateNaNF16UI.c",
    "deps/SoftFloat-3e/source/8086/softfloat_raiseFlags.c",
    "deps/SoftFloat-3e/source/f128M_add.c",
    "deps/SoftFloat-3e/source/f128M_div.c",
    "deps/SoftFloat-3e/source/f128M_eq.c",
    "deps/SoftFloat-3e/source/f128M_eq_signaling.c",
    "deps/SoftFloat-3e/source/f128M_le.c",
    "deps/SoftFloat-3e/source/f128M_le_quiet.c",
    "deps/SoftFloat-3e/source/f128M_lt.c",
    "deps/SoftFloat-3e/source/f128M_lt_quiet.c",
    "deps/SoftFloat-3e/source/f128M_mul.c",
    "deps/SoftFloat-3e/source/f128M_mulAdd.c",
    "deps/SoftFloat-3e/source/f128M_rem.c",
    "deps/SoftFloat-3e/source/f128M_roundToInt.c",
    "deps/SoftFloat-3e/source/f128M_sqrt.c",
    "deps/SoftFloat-3e/source/f128M_sub.c",
    "deps/SoftFloat-3e/source/f128M_to_f16.c",
    "deps/SoftFloat-3e/source/f128M_to_f32.c",
    "deps/SoftFloat-3e/source/f128M_to_f64.c",
    "deps/SoftFloat-3e/source/f128M_to_extF80M.c",
    "deps/SoftFloat-3e/source/f128M_to_i32.c",
    "deps/SoftFloat-3e/source/f128M_to_i32_r_minMag.c",
    "deps/SoftFloat-3e/source/f128M_to_i64.c",
    "deps/SoftFloat-3e/source/f128M_to_i64_r_minMag.c",
    "deps/SoftFloat-3e/source/f128M_to_ui32.c",
    "deps/SoftFloat-3e/source/f128M_to_ui32_r_minMag.c",
    "deps/SoftFloat-3e/source/f128M_to_ui64.c",
    "deps/SoftFloat-3e/source/f128M_to_ui64_r_minMag.c",
    "deps/SoftFloat-3e/source/extF80M_add.c",
    "deps/SoftFloat-3e/source/extF80M_div.c",
    "deps/SoftFloat-3e/source/extF80M_eq.c",
    "deps/SoftFloat-3e/source/extF80M_le.c",
    "deps/SoftFloat-3e/source/extF80M_lt.c",
    "deps/SoftFloat-3e/source/extF80M_mul.c",
    "deps/SoftFloat-3e/source/extF80M_rem.c",
    "deps/SoftFloat-3e/source/extF80M_roundToInt.c",
    "deps/SoftFloat-3e/source/extF80M_sqrt.c",
    "deps/SoftFloat-3e/source/extF80M_sub.c",
    "deps/SoftFloat-3e/source/extF80M_to_f16.c",
    "deps/SoftFloat-3e/source/extF80M_to_f32.c",
    "deps/SoftFloat-3e/source/extF80M_to_f64.c",
    "deps/SoftFloat-3e/source/extF80M_to_f128M.c",
    "deps/SoftFloat-3e/source/f16_add.c",
    "deps/SoftFloat-3e/source/f16_div.c",
    "deps/SoftFloat-3e/source/f16_eq.c",
    "deps/SoftFloat-3e/source/f16_isSignalingNaN.c",
    "deps/SoftFloat-3e/source/f16_lt.c",
    "deps/SoftFloat-3e/source/f16_mul.c",
    "deps/SoftFloat-3e/source/f16_mulAdd.c",
    "deps/SoftFloat-3e/source/f16_rem.c",
    "deps/SoftFloat-3e/source/f16_roundToInt.c",
    "deps/SoftFloat-3e/source/f16_sqrt.c",
    "deps/SoftFloat-3e/source/f16_sub.c",
    "deps/SoftFloat-3e/source/f16_to_extF80M.c",
    "deps/SoftFloat-3e/source/f16_to_f128M.c",
    "deps/SoftFloat-3e/source/f16_to_f64.c",
    "deps/SoftFloat-3e/source/f32_to_extF80M.c",
    "deps/SoftFloat-3e/source/f32_to_f128M.c",
    "deps/SoftFloat-3e/source/f64_to_extF80M.c",
    "deps/SoftFloat-3e/source/f64_to_f128M.c",
    "deps/SoftFloat-3e/source/f64_to_f16.c",
    "deps/SoftFloat-3e/source/i32_to_f128M.c",
    "deps/SoftFloat-3e/source/s_add256M.c",
    "deps/SoftFloat-3e/source/s_addCarryM.c",
    "deps/SoftFloat-3e/source/s_addComplCarryM.c",
    "deps/SoftFloat-3e/source/s_addF128M.c",
    "deps/SoftFloat-3e/source/s_addExtF80M.c",
    "deps/SoftFloat-3e/source/s_addM.c",
    "deps/SoftFloat-3e/source/s_addMagsF16.c",
    "deps/SoftFloat-3e/source/s_addMagsF32.c",
    "deps/SoftFloat-3e/source/s_addMagsF64.c",
    "deps/SoftFloat-3e/source/s_approxRecip32_1.c",
    "deps/SoftFloat-3e/source/s_approxRecipSqrt32_1.c",
    "deps/SoftFloat-3e/source/s_approxRecipSqrt_1Ks.c",
    "deps/SoftFloat-3e/source/s_approxRecip_1Ks.c",
    "deps/SoftFloat-3e/source/s_compare128M.c",
    "deps/SoftFloat-3e/source/s_compare96M.c",
    "deps/SoftFloat-3e/source/s_compareNonnormExtF80M.c",
    "deps/SoftFloat-3e/source/s_countLeadingZeros16.c",
    "deps/SoftFloat-3e/source/s_countLeadingZeros32.c",
    "deps/SoftFloat-3e/source/s_countLeadingZeros64.c",
    "deps/SoftFloat-3e/source/s_countLeadingZeros8.c",
    "deps/SoftFloat-3e/source/s_eq128.c",
    "deps/SoftFloat-3e/source/s_invalidF128M.c",
    "deps/SoftFloat-3e/source/s_invalidExtF80M.c",
    "deps/SoftFloat-3e/source/s_isNaNF128M.c",
    "deps/SoftFloat-3e/source/s_le128.c",
    "deps/SoftFloat-3e/source/s_lt128.c",
    "deps/SoftFloat-3e/source/s_mul128MTo256M.c",
    "deps/SoftFloat-3e/source/s_mul64To128M.c",
    "deps/SoftFloat-3e/source/s_mulAddF128M.c",
    "deps/SoftFloat-3e/source/s_mulAddF16.c",
    "deps/SoftFloat-3e/source/s_mulAddF32.c",
    "deps/SoftFloat-3e/source/s_mulAddF64.c",
    "deps/SoftFloat-3e/source/s_negXM.c",
    "deps/SoftFloat-3e/source/s_normExtF80SigM.c",
    "deps/SoftFloat-3e/source/s_normRoundPackMToF128M.c",
    "deps/SoftFloat-3e/source/s_normRoundPackMToExtF80M.c",
    "deps/SoftFloat-3e/source/s_normRoundPackToF16.c",
    "deps/SoftFloat-3e/source/s_normRoundPackToF32.c",
    "deps/SoftFloat-3e/source/s_normRoundPackToF64.c",
    "deps/SoftFloat-3e/source/s_normSubnormalF128SigM.c",
    "deps/SoftFloat-3e/source/s_normSubnormalF16Sig.c",
    "deps/SoftFloat-3e/source/s_normSubnormalF32Sig.c",
    "deps/SoftFloat-3e/source/s_normSubnormalF64Sig.c",
    "deps/SoftFloat-3e/source/s_remStepMBy32.c",
    "deps/SoftFloat-3e/source/s_roundMToI64.c",
    "deps/SoftFloat-3e/source/s_roundMToUI64.c",
    "deps/SoftFloat-3e/source/s_roundPackMToExtF80M.c",
    "deps/SoftFloat-3e/source/s_roundPackMToF128M.c",
    "deps/SoftFloat-3e/source/s_roundPackToF16.c",
    "deps/SoftFloat-3e/source/s_roundPackToF32.c",
    "deps/SoftFloat-3e/source/s_roundPackToF64.c",
    "deps/SoftFloat-3e/source/s_roundToI32.c",
    "deps/SoftFloat-3e/source/s_roundToI64.c",
    "deps/SoftFloat-3e/source/s_roundToUI32.c",
    "deps/SoftFloat-3e/source/s_roundToUI64.c",
    "deps/SoftFloat-3e/source/s_shiftLeftM.c",
    "deps/SoftFloat-3e/source/s_shiftNormSigF128M.c",
    "deps/SoftFloat-3e/source/s_shiftRightJam256M.c",
    "deps/SoftFloat-3e/source/s_shiftRightJam32.c",
    "deps/SoftFloat-3e/source/s_shiftRightJam64.c",
    "deps/SoftFloat-3e/source/s_shiftRightJamM.c",
    "deps/SoftFloat-3e/source/s_shiftRightM.c",
    "deps/SoftFloat-3e/source/s_shortShiftLeft64To96M.c",
    "deps/SoftFloat-3e/source/s_shortShiftLeftM.c",
    "deps/SoftFloat-3e/source/s_shortShiftRightExtendM.c",
    "deps/SoftFloat-3e/source/s_shortShiftRightJam64.c",
    "deps/SoftFloat-3e/source/s_shortShiftRightJamM.c",
    "deps/SoftFloat-3e/source/s_shortShiftRightM.c",
    "deps/SoftFloat-3e/source/s_sub1XM.c",
    "deps/SoftFloat-3e/source/s_sub256M.c",
    "deps/SoftFloat-3e/source/s_subM.c",
    "deps/SoftFloat-3e/source/s_subMagsF16.c",
    "deps/SoftFloat-3e/source/s_subMagsF32.c",
    "deps/SoftFloat-3e/source/s_subMagsF64.c",
    "deps/SoftFloat-3e/source/s_tryPropagateNaNF128M.c",
    "deps/SoftFloat-3e/source/s_tryPropagateNaNExtF80M.c",
    "deps/SoftFloat-3e/source/softfloat_state.c",
    "deps/SoftFloat-3e/source/ui32_to_f128M.c",
    "deps/SoftFloat-3e/source/ui64_to_f128M.c",
    "deps/SoftFloat-3e/source/ui32_to_extF80M.c",
    "deps/SoftFloat-3e/source/ui64_to_extF80M.c",
};

const stage1_sources = [_][]const u8{
    "src/stage1/analyze.cpp",
    "src/stage1/astgen.cpp",
    "src/stage1/bigfloat.cpp",
    "src/stage1/bigint.cpp",
    "src/stage1/buffer.cpp",
    "src/stage1/codegen.cpp",
    "src/stage1/dump_analysis.cpp",
    "src/stage1/errmsg.cpp",
    "src/stage1/error.cpp",
    "src/stage1/heap.cpp",
    "src/stage1/ir.cpp",
    "src/stage1/ir_print.cpp",
    "src/stage1/mem.cpp",
    "src/stage1/os.cpp",
    "src/stage1/parser.cpp",
    "src/stage1/range_set.cpp",
    "src/stage1/stage1.cpp",
    "src/stage1/target.cpp",
    "src/stage1/tokenizer.cpp",
    "src/stage1/util.cpp",
    "src/stage1/softfloat_ext.cpp",
};
const optimized_c_sources = [_][]const u8{
    "src/stage1/parse_f128.c",
};
const zig_cpp_sources = [_][]const u8{
    // These are planned to stay even when we are self-hosted.
    "src/zig_llvm.cpp",
    "src/zig_clang.cpp",
    "src/zig_llvm-ar.cpp",
    "src/zig_clang_driver.cpp",
    "src/zig_clang_cc1_main.cpp",
    "src/zig_clang_cc1as_main.cpp",
    // https://github.com/ziglang/zig/issues/6363
    "src/windows_sdk.cpp",
};

const clang_libs = [_][]const u8{
    "clangFrontendTool",
    "clangCodeGen",
    "clangFrontend",
    "clangDriver",
    "clangSerialization",
    "clangSema",
    "clangStaticAnalyzerFrontend",
    "clangStaticAnalyzerCheckers",
    "clangStaticAnalyzerCore",
    "clangAnalysis",
    "clangASTMatchers",
    "clangAST",
    "clangParse",
    "clangSema",
    "clangBasic",
    "clangEdit",
    "clangLex",
    "clangARCMigrate",
    "clangRewriteFrontend",
    "clangRewrite",
    "clangCrossTU",
    "clangIndex",
    "clangToolingCore",
};
const lld_libs = [_][]const u8{
    "lldMinGW",
    "lldELF",
    "lldCOFF",
    "lldWasm",
    "lldMachO",
    "lldCommon",
};
// This list can be re-generated with `llvm-config --libfiles` and then
// reformatting using your favorite text editor. Note we do not execute
// `llvm-config` here because we are cross compiling. Also omit LLVMTableGen
// from these libs.
const llvm_libs = [_][]const u8{
    "LLVMWindowsManifest",
    "LLVMXRay",
    "LLVMLibDriver",
    "LLVMDlltoolDriver",
    "LLVMCoverage",
    "LLVMLineEditor",
    "LLVMXCoreDisassembler",
    "LLVMXCoreCodeGen",
    "LLVMXCoreDesc",
    "LLVMXCoreInfo",
    "LLVMX86TargetMCA",
    "LLVMX86Disassembler",
    "LLVMX86AsmParser",
    "LLVMX86CodeGen",
    "LLVMX86Desc",
    "LLVMX86Info",
    "LLVMWebAssemblyDisassembler",
    "LLVMWebAssemblyAsmParser",
    "LLVMWebAssemblyCodeGen",
    "LLVMWebAssemblyDesc",
    "LLVMWebAssemblyUtils",
    "LLVMWebAssemblyInfo",
    "LLVMVEDisassembler",
    "LLVMVEAsmParser",
    "LLVMVECodeGen",
    "LLVMVEDesc",
    "LLVMVEInfo",
    "LLVMSystemZDisassembler",
    "LLVMSystemZAsmParser",
    "LLVMSystemZCodeGen",
    "LLVMSystemZDesc",
    "LLVMSystemZInfo",
    "LLVMSparcDisassembler",
    "LLVMSparcAsmParser",
    "LLVMSparcCodeGen",
    "LLVMSparcDesc",
    "LLVMSparcInfo",
    "LLVMRISCVDisassembler",
    "LLVMRISCVAsmParser",
    "LLVMRISCVCodeGen",
    "LLVMRISCVDesc",
    "LLVMRISCVInfo",
    "LLVMPowerPCDisassembler",
    "LLVMPowerPCAsmParser",
    "LLVMPowerPCCodeGen",
    "LLVMPowerPCDesc",
    "LLVMPowerPCInfo",
    "LLVMNVPTXCodeGen",
    "LLVMNVPTXDesc",
    "LLVMNVPTXInfo",
    "LLVMMSP430Disassembler",
    "LLVMMSP430AsmParser",
    "LLVMMSP430CodeGen",
    "LLVMMSP430Desc",
    "LLVMMSP430Info",
    "LLVMMipsDisassembler",
    "LLVMMipsAsmParser",
    "LLVMMipsCodeGen",
    "LLVMMipsDesc",
    "LLVMMipsInfo",
    "LLVMLanaiDisassembler",
    "LLVMLanaiCodeGen",
    "LLVMLanaiAsmParser",
    "LLVMLanaiDesc",
    "LLVMLanaiInfo",
    "LLVMHexagonDisassembler",
    "LLVMHexagonCodeGen",
    "LLVMHexagonAsmParser",
    "LLVMHexagonDesc",
    "LLVMHexagonInfo",
    "LLVMBPFDisassembler",
    "LLVMBPFAsmParser",
    "LLVMBPFCodeGen",
    "LLVMBPFDesc",
    "LLVMBPFInfo",
    "LLVMAVRDisassembler",
    "LLVMAVRAsmParser",
    "LLVMAVRCodeGen",
    "LLVMAVRDesc",
    "LLVMAVRInfo",
    "LLVMARMDisassembler",
    "LLVMARMAsmParser",
    "LLVMARMCodeGen",
    "LLVMARMDesc",
    "LLVMARMUtils",
    "LLVMARMInfo",
    "LLVMAMDGPUTargetMCA",
    "LLVMAMDGPUDisassembler",
    "LLVMAMDGPUAsmParser",
    "LLVMAMDGPUCodeGen",
    "LLVMAMDGPUDesc",
    "LLVMAMDGPUUtils",
    "LLVMAMDGPUInfo",
    "LLVMAArch64Disassembler",
    "LLVMAArch64AsmParser",
    "LLVMAArch64CodeGen",
    "LLVMAArch64Desc",
    "LLVMAArch64Utils",
    "LLVMAArch64Info",
    "LLVMOrcJIT",
    "LLVMMCJIT",
    "LLVMJITLink",
    "LLVMInterpreter",
    "LLVMExecutionEngine",
    "LLVMRuntimeDyld",
    "LLVMOrcTargetProcess",
    "LLVMOrcShared",
    "LLVMDWP",
    "LLVMSymbolize",
    "LLVMDebugInfoPDB",
    "LLVMDebugInfoGSYM",
    "LLVMOption",
    "LLVMObjectYAML",
    "LLVMMCA",
    "LLVMMCDisassembler",
    "LLVMLTO",
    "LLVMPasses",
    "LLVMCFGuard",
    "LLVMCoroutines",
    "LLVMObjCARCOpts",
    "LLVMipo",
    "LLVMVectorize",
    "LLVMLinker",
    "LLVMInstrumentation",
    "LLVMFrontendOpenMP",
    "LLVMFrontendOpenACC",
    "LLVMExtensions",
    "LLVMDWARFLinker",
    "LLVMGlobalISel",
    "LLVMMIRParser",
    "LLVMAsmPrinter",
    "LLVMDebugInfoMSF",
    "LLVMSelectionDAG",
    "LLVMCodeGen",
    "LLVMIRReader",
    "LLVMAsmParser",
    "LLVMInterfaceStub",
    "LLVMFileCheck",
    "LLVMFuzzMutate",
    "LLVMTarget",
    "LLVMScalarOpts",
    "LLVMInstCombine",
    "LLVMAggressiveInstCombine",
    "LLVMTransformUtils",
    "LLVMBitWriter",
    "LLVMAnalysis",
    "LLVMProfileData",
    "LLVMDebugInfoDWARF",
    "LLVMObject",
    "LLVMTextAPI",
    "LLVMMCParser",
    "LLVMMC",
    "LLVMDebugInfoCodeView",
    "LLVMBitReader",
    "LLVMCore",
    "LLVMRemarks",
    "LLVMBitstreamReader",
    "LLVMBinaryFormat",
    "LLVMSupport",
    "LLVMDemangle",
};
