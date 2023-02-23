const std = @import("std");
const builtin = std.builtin;
const tests = @import("test/tests.zig");
const BufMap = std.BufMap;
const mem = std.mem;
const ArrayList = std.ArrayList;
const io = std.io;
const fs = std.fs;
const InstallDirectoryOptions = std.Build.InstallDirectoryOptions;
const assert = std.debug.assert;

const zig_version = std.builtin.Version{ .major = 0, .minor = 11, .patch = 0 };
const stack_size = 32 * 1024 * 1024;

pub fn build(b: *std.Build) !void {
    const release = b.option(bool, "release", "Build in release mode") orelse false;
    const only_c = b.option(bool, "only-c", "Translate the Zig compiler to C code, with only the C backend enabled") orelse false;
    const target = t: {
        var default_target: std.zig.CrossTarget = .{};
        if (only_c) {
            default_target.ofmt = .c;
        }
        break :t b.standardTargetOptions(.{ .default_target = default_target });
    };
    const optimize: std.builtin.OptimizeMode = if (release) switch (target.getCpuArch()) {
        .wasm32 => .ReleaseSmall,
        else => .ReleaseFast,
    } else .Debug;

    const single_threaded = b.option(bool, "single-threaded", "Build artifacts that run in single threaded mode");
    const use_zig_libcxx = b.option(bool, "use-zig-libcxx", "If libc++ is needed, use zig's bundled version, don't try to integrate with the system") orelse false;

    const test_step = b.step("test", "Run all the tests");

    const docgen_exe = b.addExecutable(.{
        .name = "docgen",
        .root_source_file = .{ .path = "doc/docgen.zig" },
        .target = .{},
        .optimize = .Debug,
    });
    docgen_exe.single_threaded = single_threaded;

    const langref_out_path = try b.cache_root.join(b.allocator, &.{"langref.html"});
    const docgen_cmd = docgen_exe.run();
    docgen_cmd.addArgs(&[_][]const u8{
        "--zig",
        b.zig_exe,
        "doc" ++ fs.path.sep_str ++ "langref.html.in",
        langref_out_path,
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);

    const test_cases = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .optimize = optimize,
    });
    test_cases.main_pkg_path = ".";
    test_cases.stack_size = stack_size;
    test_cases.single_threaded = single_threaded;

    const fmt_build_zig = b.addFmt(&[_][]const u8{"build.zig"});

    const skip_debug = b.option(bool, "skip-debug", "Main test suite skips debug builds") orelse false;
    const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse false;
    const skip_release_small = b.option(bool, "skip-release-small", "Main test suite skips release-small builds") orelse skip_release;
    const skip_release_fast = b.option(bool, "skip-release-fast", "Main test suite skips release-fast builds") orelse skip_release;
    const skip_release_safe = b.option(bool, "skip-release-safe", "Main test suite skips release-safe builds") orelse skip_release;
    const skip_non_native = b.option(bool, "skip-non-native", "Main test suite skips non-native builds") orelse false;
    const skip_libc = b.option(bool, "skip-libc", "Main test suite skips tests that link libc") orelse false;
    const skip_single_threaded = b.option(bool, "skip-single-threaded", "Main test suite skips tests that are single-threaded") orelse false;
    const skip_stage1 = b.option(bool, "skip-stage1", "Main test suite skips stage1 compile error tests") orelse false;
    const skip_run_translated_c = b.option(bool, "skip-run-translated-c", "Main test suite skips run-translated-c tests") orelse false;
    const skip_stage2_tests = b.option(bool, "skip-stage2-tests", "Main test suite skips self-hosted compiler tests") orelse false;
    const deprecated_skip_install_lib_files = b.option(bool, "skip-install-lib-files", "deprecated. see no-lib") orelse false;
    if (deprecated_skip_install_lib_files) {
        std.log.warn("-Dskip-install-lib-files is deprecated in favor of -Dno-lib", .{});
    }
    const skip_install_lib_files = b.option(bool, "no-lib", "skip copying of lib/ files to installation prefix. Useful for development") orelse deprecated_skip_install_lib_files;

    const only_install_lib_files = b.option(bool, "lib-files-only", "Only install library files") orelse false;

    const static_llvm = b.option(bool, "static-llvm", "Disable integration with system-installed LLVM, Clang, LLD, and libc++") orelse false;
    const enable_llvm = b.option(bool, "enable-llvm", "Build self-hosted compiler with LLVM backend enabled") orelse static_llvm;
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
    const enable_macos_sdk = b.option(bool, "enable-macos-sdk", "Run tests requiring presence of macOS SDK and frameworks") orelse false;
    const enable_symlinks_windows = b.option(bool, "enable-symlinks-windows", "Run tests requiring presence of symlinks on Windows") orelse false;
    const config_h_path_option = b.option([]const u8, "config_h", "Path to the generated config.h");

    if (!skip_install_lib_files) {
        b.installDirectory(InstallDirectoryOptions{
            .source_dir = "lib",
            .install_dir = .lib,
            .install_subdir = "zig",
            .exclude_extensions = &[_][]const u8{
                // exclude files from lib/std/compress/testdata
                ".gz",
                ".z.0",
                ".z.9",
                ".zstd.3",
                ".zstd.19",
                "rfc1951.txt",
                "rfc1952.txt",
                "rfc8478.txt",
                // exclude files from lib/std/compress/deflate/testdata
                ".expect",
                ".expect-noinput",
                ".golden",
                ".input",
                "compress-e.txt",
                "compress-gettysburg.txt",
                "compress-pi.txt",
                "rfc1951.txt",
                // exclude files from lib/std/compress/lzma/testdata
                ".lzma",
                // exclude files from lib/std/compress/xz/testdata
                ".xz",
                // exclude files from lib/std/tz/
                ".tzif",
                // others
                "README.md",
            },
            .blank_extensions = &[_][]const u8{
                "test.zig",
            },
        });
    }

    if (only_install_lib_files)
        return;

    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const tracy_callstack = b.option(bool, "tracy-callstack", "Include callstack information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    const tracy_allocation = b.option(bool, "tracy-allocation", "Include allocation information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    const force_gpa = b.option(bool, "force-gpa", "Force the compiler to use GeneralPurposeAllocator") orelse false;
    const link_libc = b.option(bool, "force-link-libc", "Force self-hosted compiler to link libc") orelse (enable_llvm or only_c);
    const sanitize_thread = b.option(bool, "sanitize-thread", "Enable thread-sanitization") orelse false;
    const strip = b.option(bool, "strip", "Omit debug information");
    const value_tracing = b.option(bool, "value-tracing", "Enable extra state tracking to help troubleshoot bugs in the compiler (using the std.debug.Trace API)") orelse false;

    const mem_leak_frames: u32 = b.option(u32, "mem-leak-frames", "How many stack frames to print when a memory leak occurs. Tests get 2x this amount.") orelse blk: {
        if (strip == true) break :blk @as(u32, 0);
        if (optimize != .Debug) break :blk 0;
        break :blk 4;
    };

    const exe = addCompilerStep(b, optimize, target);
    exe.strip = strip;
    exe.sanitize_thread = sanitize_thread;
    exe.build_id = b.option(bool, "build-id", "Include a build id note") orelse false;
    exe.install();

    const compile_step = b.step("compile", "Build the self-hosted compiler");
    compile_step.dependOn(&exe.step);

    if (!skip_stage2_tests) {
        test_step.dependOn(&exe.step);
    }

    b.default_step.dependOn(&exe.step);
    exe.single_threaded = single_threaded;

    if (target.isWindows() and target.getAbi() == .gnu) {
        // LTO is currently broken on mingw, this can be removed when it's fixed.
        exe.want_lto = false;
        test_cases.want_lto = false;
    }

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);

    exe_options.addOption(u32, "mem_leak_frames", mem_leak_frames);
    exe_options.addOption(bool, "skip_non_native", skip_non_native);
    exe_options.addOption(bool, "have_llvm", enable_llvm);
    exe_options.addOption(bool, "llvm_has_m68k", llvm_has_m68k);
    exe_options.addOption(bool, "llvm_has_csky", llvm_has_csky);
    exe_options.addOption(bool, "llvm_has_arc", llvm_has_arc);
    exe_options.addOption(bool, "force_gpa", force_gpa);
    exe_options.addOption(bool, "only_c", only_c);
    exe_options.addOption(bool, "omit_pkg_fetching_code", false);

    if (link_libc) {
        exe.linkLibC();
        test_cases.linkLibC();
    }

    const is_debug = optimize == .Debug;
    const enable_logging = b.option(bool, "log", "Enable debug logging with --debug-log") orelse is_debug;
    const enable_link_snapshots = b.option(bool, "link-snapshot", "Whether to enable linker state snapshots") orelse false;

    const opt_version_string = b.option([]const u8, "version-string", "Override Zig version string. Default is to find out with git.");
    const version_slice = if (opt_version_string) |version| version else v: {
        if (!std.process.can_spawn) {
            std.debug.print("error: version info cannot be retrieved from git. Zig version must be provided using -Dversion-string\n", .{});
            std.process.exit(1);
        }
        const version_string = b.fmt("{d}.{d}.{d}", .{ zig_version.major, zig_version.minor, zig_version.patch });

        var code: u8 = undefined;
        const git_describe_untrimmed = b.execAllowFail(&[_][]const u8{
            "git", "-C", b.build_root.path orelse ".", "describe", "--match", "*.*.*", "--tags",
        }, &code, .Ignore) catch {
            break :v version_string;
        };
        const git_describe = mem.trim(u8, git_describe_untrimmed, " \n\r");

        switch (mem.count(u8, git_describe, "-")) {
            0 => {
                // Tagged release version (e.g. 0.10.0).
                if (!mem.eql(u8, git_describe, version_string)) {
                    std.debug.print("Zig version '{s}' does not match Git tag '{s}'\n", .{ version_string, git_describe });
                    std.process.exit(1);
                }
                break :v version_string;
            },
            2 => {
                // Untagged development build (e.g. 0.10.0-dev.2025+ecf0050a9).
                var it = mem.split(u8, git_describe, "-");
                const tagged_ancestor = it.first();
                const commit_height = it.next().?;
                const commit_id = it.next().?;

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
    const version = try b.allocator.dupeZ(u8, version_slice);
    exe_options.addOption([:0]const u8, "version", version);

    if (enable_llvm) {
        const cmake_cfg = if (static_llvm) null else blk: {
            if (findConfigH(b, config_h_path_option)) |config_h_path| {
                const file_contents = fs.cwd().readFileAlloc(b.allocator, config_h_path, max_config_h_bytes) catch unreachable;
                break :blk parseConfigH(b, file_contents);
            } else {
                std.log.warn("config.h could not be located automatically. Consider providing it explicitly via \"-Dconfig_h\"", .{});
                break :blk null;
            }
        };

        if (cmake_cfg) |cfg| {
            // Inside this code path, we have to coordinate with system packaged LLVM, Clang, and LLD.
            // That means we also have to rely on stage1 compiled c++ files. We parse config.h to find
            // the information passed on to us from cmake.
            if (cfg.cmake_prefix_path.len > 0) {
                var it = mem.tokenize(u8, cfg.cmake_prefix_path, ";");
                while (it.next()) |path| {
                    b.addSearchPrefix(path);
                }
            }

            try addCmakeCfgOptionsToExe(b, cfg, exe, use_zig_libcxx);
            try addCmakeCfgOptionsToExe(b, cfg, test_cases, use_zig_libcxx);
        } else {
            // Here we are -Denable-llvm but no cmake integration.
            try addStaticLlvmOptionsToExe(exe);
            try addStaticLlvmOptionsToExe(test_cases);
        }
        if (target.isWindows()) {
            inline for (.{ exe, test_cases }) |artifact| {
                artifact.linkSystemLibrary("version");
                artifact.linkSystemLibrary("uuid");
                artifact.linkSystemLibrary("ole32");
            }
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
    if (tracy) |tracy_path| {
        const client_cpp = fs.path.join(
            b.allocator,
            &[_][]const u8{ tracy_path, "public", "TracyClient.cpp" },
        ) catch unreachable;

        // On mingw, we need to opt into windows 7+ to get some features required by tracy.
        const tracy_c_flags: []const []const u8 = if (target.isWindows() and target.getAbi() == .gnu)
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined", "-D_WIN32_WINNT=0x601" }
        else
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" };

        exe.addIncludePath(tracy_path);
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

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const test_cases_options = b.addOptions();
    test_cases.addOptions("build_options", test_cases_options);

    test_cases_options.addOption(bool, "enable_logging", enable_logging);
    test_cases_options.addOption(bool, "enable_link_snapshots", enable_link_snapshots);
    test_cases_options.addOption(bool, "skip_non_native", skip_non_native);
    test_cases_options.addOption(bool, "skip_stage1", skip_stage1);
    test_cases_options.addOption(bool, "have_llvm", enable_llvm);
    test_cases_options.addOption(bool, "llvm_has_m68k", llvm_has_m68k);
    test_cases_options.addOption(bool, "llvm_has_csky", llvm_has_csky);
    test_cases_options.addOption(bool, "llvm_has_arc", llvm_has_arc);
    test_cases_options.addOption(bool, "force_gpa", force_gpa);
    test_cases_options.addOption(bool, "only_c", only_c);
    test_cases_options.addOption(bool, "enable_qemu", b.enable_qemu);
    test_cases_options.addOption(bool, "enable_wine", b.enable_wine);
    test_cases_options.addOption(bool, "enable_wasmtime", b.enable_wasmtime);
    test_cases_options.addOption(bool, "enable_rosetta", b.enable_rosetta);
    test_cases_options.addOption(bool, "enable_darling", b.enable_darling);
    test_cases_options.addOption(u32, "mem_leak_frames", mem_leak_frames * 2);
    test_cases_options.addOption(bool, "value_tracing", value_tracing);
    test_cases_options.addOption(?[]const u8, "glibc_runtimes_dir", b.glibc_runtimes_dir);
    test_cases_options.addOption([:0]const u8, "version", version);
    test_cases_options.addOption(std.SemanticVersion, "semver", semver);
    test_cases_options.addOption(?[]const u8, "test_filter", test_filter);

    const test_cases_step = b.step("test-cases", "Run the main compiler test cases");
    test_cases_step.dependOn(&test_cases.step);
    if (!skip_stage2_tests) {
        test_step.dependOn(test_cases_step);
    }

    var chosen_opt_modes_buf: [4]builtin.Mode = undefined;
    var chosen_mode_index: usize = 0;
    if (!skip_debug) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.Mode.Debug;
        chosen_mode_index += 1;
    }
    if (!skip_release_safe) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.Mode.ReleaseSafe;
        chosen_mode_index += 1;
    }
    if (!skip_release_fast) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.Mode.ReleaseFast;
        chosen_mode_index += 1;
    }
    if (!skip_release_small) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.Mode.ReleaseSmall;
        chosen_mode_index += 1;
    }
    const optimization_modes = chosen_opt_modes_buf[0..chosen_mode_index];

    // run stage1 `zig fmt` on this build.zig file just to make sure it works
    test_step.dependOn(&fmt_build_zig.step);
    const fmt_step = b.step("test-fmt", "Run zig fmt against build.zig to make sure it works");
    fmt_step.dependOn(&fmt_build_zig.step);

    test_step.dependOn(tests.addPkgTests(
        b,
        test_filter,
        "test/behavior.zig",
        "behavior",
        "Run the behavior tests",
        optimization_modes,
        skip_single_threaded,
        skip_non_native,
        skip_libc,
        skip_stage1,
        skip_stage2_tests,
    ));

    test_step.dependOn(tests.addPkgTests(
        b,
        test_filter,
        "lib/compiler_rt.zig",
        "compiler-rt",
        "Run the compiler_rt tests",
        optimization_modes,
        true, // skip_single_threaded
        skip_non_native,
        true, // skip_libc
        skip_stage1,
        skip_stage2_tests or true, // TODO get these all passing
    ));

    test_step.dependOn(tests.addPkgTests(
        b,
        test_filter,
        "lib/c.zig",
        "universal-libc",
        "Run the universal libc tests",
        optimization_modes,
        true, // skip_single_threaded
        skip_non_native,
        true, // skip_libc
        skip_stage1,
        skip_stage2_tests or true, // TODO get these all passing
    ));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter, optimization_modes));
    test_step.dependOn(tests.addStandaloneTests(
        b,
        test_filter,
        optimization_modes,
        skip_non_native,
        enable_macos_sdk,
        target,
        skip_stage2_tests,
        b.enable_darling,
        b.enable_qemu,
        b.enable_rosetta,
        b.enable_wasmtime,
        b.enable_wine,
        enable_symlinks_windows,
    ));
    test_step.dependOn(tests.addCAbiTests(b, skip_non_native, skip_release));
    test_step.dependOn(tests.addLinkTests(b, test_filter, optimization_modes, enable_macos_sdk, skip_stage2_tests, enable_symlinks_windows));
    test_step.dependOn(tests.addStackTraceTests(b, test_filter, optimization_modes));
    test_step.dependOn(tests.addCliTests(b, test_filter, optimization_modes));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter, optimization_modes));
    test_step.dependOn(tests.addTranslateCTests(b, test_filter));
    if (!skip_run_translated_c) {
        test_step.dependOn(tests.addRunTranslatedCTests(b, test_filter, target));
    }
    // tests for this feature are disabled until we have the self-hosted compiler available
    // test_step.dependOn(tests.addGenHTests(b, test_filter));

    test_step.dependOn(tests.addPkgTests(
        b,
        test_filter,
        "lib/std/std.zig",
        "std",
        "Run the standard library tests",
        optimization_modes,
        skip_single_threaded,
        skip_non_native,
        skip_libc,
        skip_stage1,
        true, // TODO get these all passing
    ));

    try addWasiUpdateStep(b, version);
}

fn addWasiUpdateStep(b: *std.Build, version: [:0]const u8) !void {
    const semver = try std.SemanticVersion.parse(version);

    var target: std.zig.CrossTarget = .{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    };
    target.cpu_features_add.addFeature(@enumToInt(std.Target.wasm.Feature.bulk_memory));

    const exe = addCompilerStep(b, .ReleaseSmall, target);

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);

    exe_options.addOption(u32, "mem_leak_frames", 0);
    exe_options.addOption(bool, "have_llvm", false);
    exe_options.addOption(bool, "force_gpa", false);
    exe_options.addOption(bool, "only_c", true);
    exe_options.addOption([:0]const u8, "version", version);
    exe_options.addOption(std.SemanticVersion, "semver", semver);
    exe_options.addOption(bool, "enable_logging", false);
    exe_options.addOption(bool, "enable_link_snapshots", false);
    exe_options.addOption(bool, "enable_tracy", false);
    exe_options.addOption(bool, "enable_tracy_callstack", false);
    exe_options.addOption(bool, "enable_tracy_allocation", false);
    exe_options.addOption(bool, "value_tracing", false);

    const run_opt = b.addSystemCommand(&.{ "wasm-opt", "-Oz", "--enable-bulk-memory" });
    run_opt.addArtifactArg(exe);
    run_opt.addArg("-o");
    run_opt.addFileSourceArg(.{ .path = "stage1/zig1.wasm" });

    const copy_zig_h = b.addWriteFiles();
    copy_zig_h.addCopyFileToSource(.{ .path = "lib/zig.h" }, "stage1/zig.h");

    const update_zig1_step = b.step("update-zig1", "Update stage1/zig1.wasm");
    update_zig1_step.dependOn(&run_opt.step);
    update_zig1_step.dependOn(&copy_zig_h.step);
}

fn addCompilerStep(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
) *std.Build.CompileStep {
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.stack_size = stack_size;
    return exe;
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
    b: *std.Build,
    cfg: CMakeConfig,
    exe: *std.Build.CompileStep,
    use_zig_libcxx: bool,
) !void {
    if (exe.target.isDarwin()) {
        // useful for package maintainers
        exe.headerpad_max_install_names = true;
    }
    exe.addObjectFile(fs.path.join(b.allocator, &[_][]const u8{
        cfg.cmake_binary_dir,
        "zigcpp",
        b.fmt("{s}{s}{s}", .{
            cfg.cmake_static_library_prefix,
            "zigcpp",
            cfg.cmake_static_library_suffix,
        }),
    }) catch unreachable);
    assert(cfg.lld_include_dir.len != 0);
    exe.addIncludePath(cfg.lld_include_dir);
    exe.addIncludePath(cfg.llvm_include_dir);
    exe.addLibraryPath(cfg.llvm_lib_dir);
    addCMakeLibraryList(exe, cfg.clang_libraries);
    addCMakeLibraryList(exe, cfg.lld_libraries);
    addCMakeLibraryList(exe, cfg.llvm_libraries);

    if (use_zig_libcxx) {
        exe.linkLibCpp();
    } else {
        // System -lc++ must be used because in this code path we are attempting to link
        // against system-provided LLVM, Clang, LLD.
        const need_cpp_includes = true;
        const static = cfg.llvm_linkage == .static;
        const lib_suffix = if (static) exe.target.staticLibSuffix()[1..] else exe.target.dynamicLibSuffix()[1..];
        switch (exe.target.getOsTag()) {
            .linux => {
                // First we try to link against gcc libstdc++. If that doesn't work, we fall
                // back to -lc++ and cross our fingers.
                addCxxKnownPath(b, cfg, exe, b.fmt("libstdc++.{s}", .{lib_suffix}), "", need_cpp_includes) catch |err| switch (err) {
                    error.RequiredLibraryNotFound => {
                        exe.linkLibCpp();
                    },
                    else => |e| return e,
                };
                exe.linkSystemLibrary("unwind");
            },
            .ios, .macos, .watchos, .tvos => {
                exe.linkLibCpp();
            },
            .windows => {
                if (exe.target.getAbi() != .msvc) exe.linkLibCpp();
            },
            .freebsd => {
                if (static) {
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libgcc_eh.{s}", .{lib_suffix}), null, need_cpp_includes);
                } else {
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                }
            },
            .openbsd => {
                try addCxxKnownPath(b, cfg, exe, b.fmt("libc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                try addCxxKnownPath(b, cfg, exe, b.fmt("libc++abi.{s}", .{lib_suffix}), null, need_cpp_includes);
            },
            .netbsd, .dragonfly => {
                if (static) {
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libstdc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libgcc_eh.{s}", .{lib_suffix}), null, need_cpp_includes);
                } else {
                    try addCxxKnownPath(b, cfg, exe, b.fmt("libstdc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                }
            },
            else => {},
        }
    }

    if (cfg.dia_guids_lib.len != 0) {
        exe.addObjectFile(cfg.dia_guids_lib);
    }
}

fn addStaticLlvmOptionsToExe(exe: *std.Build.CompileStep) !void {
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
    exe.linkSystemLibrary("zstd");

    if (exe.target.getOs().tag != .windows or exe.target.getAbi() != .msvc) {
        // This means we rely on clang-or-zig-built LLVM, Clang, LLD libraries.
        exe.linkSystemLibrary("c++");
    }

    if (exe.target.getOs().tag == .windows) {
        exe.linkSystemLibrary("version");
        exe.linkSystemLibrary("uuid");
        exe.linkSystemLibrary("ole32");
    }
}

fn addCxxKnownPath(
    b: *std.Build,
    ctx: CMakeConfig,
    exe: *std.Build.CompileStep,
    objname: []const u8,
    errtxt: ?[]const u8,
    need_cpp_includes: bool,
) !void {
    if (!std.process.can_spawn)
        return error.RequiredLibraryNotFound;
    const path_padded = try b.exec(&[_][]const u8{
        ctx.cxx_compiler,
        b.fmt("-print-file-name={s}", .{objname}),
    });
    var tokenizer = mem.tokenize(u8, path_padded, "\r\n");
    const path_unpadded = tokenizer.next().?;
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
    // c++ -E -Wp,-v -xc++ /dev/null
    if (need_cpp_includes) {
        // I used these temporarily for testing something but we obviously need a
        // more general purpose solution here.
        //exe.addIncludePath("/nix/store/2lr0fc0ak8rwj0k8n3shcyz1hz63wzma-gcc-11.3.0/include/c++/11.3.0");
        //exe.addIncludePath("/nix/store/2lr0fc0ak8rwj0k8n3shcyz1hz63wzma-gcc-11.3.0/include/c++/11.3.0/x86_64-unknown-linux-gnu");
    }
}

fn addCMakeLibraryList(exe: *std.Build.CompileStep, list: []const u8) void {
    var it = mem.tokenize(u8, list, ";");
    while (it.next()) |lib| {
        if (mem.startsWith(u8, lib, "-l")) {
            exe.linkSystemLibrary(lib["-l".len..]);
        } else if (exe.target.isWindows() and mem.endsWith(u8, lib, ".lib") and !fs.path.isAbsolute(lib)) {
            exe.linkSystemLibrary(lib[0 .. lib.len - ".lib".len]);
        } else {
            exe.addObjectFile(lib);
        }
    }
}

const CMakeConfig = struct {
    llvm_linkage: std.Build.CompileStep.Linkage,
    cmake_binary_dir: []const u8,
    cmake_prefix_path: []const u8,
    cmake_static_library_prefix: []const u8,
    cmake_static_library_suffix: []const u8,
    cxx_compiler: []const u8,
    lld_include_dir: []const u8,
    lld_libraries: []const u8,
    clang_libraries: []const u8,
    llvm_lib_dir: []const u8,
    llvm_include_dir: []const u8,
    llvm_libraries: []const u8,
    dia_guids_lib: []const u8,
};

const max_config_h_bytes = 1 * 1024 * 1024;

fn findConfigH(b: *std.Build, config_h_path_option: ?[]const u8) ?[]const u8 {
    if (config_h_path_option) |path| {
        var config_h_or_err = fs.cwd().openFile(path, .{});
        if (config_h_or_err) |*file| {
            file.close();
            return path;
        } else |_| {
            std.log.err("Could not open provided config.h: \"{s}\"", .{path});
            std.os.exit(1);
        }
    }

    var check_dir = fs.path.dirname(b.zig_exe).?;
    while (true) {
        var dir = fs.cwd().openDir(check_dir, .{}) catch unreachable;
        defer dir.close();

        // Check if config.h is present in dir
        var config_h_or_err = dir.openFile("config.h", .{});
        if (config_h_or_err) |*file| {
            file.close();
            return fs.path.join(
                b.allocator,
                &[_][]const u8{ check_dir, "config.h" },
            ) catch unreachable;
        } else |e| switch (e) {
            error.FileNotFound => {},
            else => unreachable,
        }

        // Check if we reached the source root by looking for .git, and bail if so
        var git_dir_or_err = dir.openDir(".git", .{});
        if (git_dir_or_err) |*git_dir| {
            git_dir.close();
            return null;
        } else |_| {}

        // Otherwise, continue search in the parent directory
        const new_check_dir = fs.path.dirname(check_dir);
        if (new_check_dir == null or mem.eql(u8, new_check_dir.?, check_dir)) {
            return null;
        }
        check_dir = new_check_dir.?;
    } else unreachable; // TODO should not need `else unreachable`.
}

fn parseConfigH(b: *std.Build, config_h_text: []const u8) ?CMakeConfig {
    var ctx: CMakeConfig = .{
        .llvm_linkage = undefined,
        .cmake_binary_dir = undefined,
        .cmake_prefix_path = undefined,
        .cmake_static_library_prefix = undefined,
        .cmake_static_library_suffix = undefined,
        .cxx_compiler = undefined,
        .lld_include_dir = undefined,
        .lld_libraries = undefined,
        .clang_libraries = undefined,
        .llvm_lib_dir = undefined,
        .llvm_include_dir = undefined,
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
            .prefix = "#define ZIG_CMAKE_STATIC_LIBRARY_PREFIX ",
            .field = "cmake_static_library_prefix",
        },
        .{
            .prefix = "#define ZIG_CMAKE_STATIC_LIBRARY_SUFFIX ",
            .field = "cmake_static_library_suffix",
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
        .{
            .prefix = "#define ZIG_LLVM_INCLUDE_PATH ",
            .field = "llvm_include_dir",
        },
        .{
            .prefix = "#define ZIG_LLVM_LIB_PATH ",
            .field = "llvm_lib_dir",
        },
        // .prefix = ZIG_LLVM_LINK_MODE parsed manually below
    };

    var lines_it = mem.tokenize(u8, config_h_text, "\r\n");
    while (lines_it.next()) |line| {
        inline for (mappings) |mapping| {
            if (mem.startsWith(u8, line, mapping.prefix)) {
                var it = mem.split(u8, line, "\"");
                _ = it.first(); // skip the stuff before the quote
                const quoted = it.next().?; // the stuff inside the quote
                @field(ctx, mapping.field) = toNativePathSep(b, quoted);
            }
        }
        if (mem.startsWith(u8, line, "#define ZIG_LLVM_LINK_MODE ")) {
            var it = mem.split(u8, line, "\"");
            _ = it.next().?; // skip the stuff before the quote
            const quoted = it.next().?; // the stuff inside the quote
            ctx.llvm_linkage = if (mem.eql(u8, quoted, "shared")) .dynamic else .static;
        }
    }
    return ctx;
}

fn toNativePathSep(b: *std.Build, s: []const u8) []u8 {
    const duplicated = b.allocator.dupe(u8, s) catch unreachable;
    for (duplicated) |*byte| switch (byte.*) {
        '/' => byte.* = fs.path.sep,
        else => {},
    };
    return duplicated;
}

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
    "clangExtractAPI",
    "clangSupport",
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
    "LLVMWindowsDriver",
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
    "LLVMDebugInfoGSYM",
    "LLVMOption",
    "LLVMObjectYAML",
    "LLVMObjCopy",
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
    "LLVMSymbolize",
    "LLVMDebugInfoPDB",
    "LLVMDebugInfoMSF",
    "LLVMDebugInfoDWARF",
    "LLVMObject",
    "LLVMTextAPI",
    "LLVMMCParser",
    "LLVMMC",
    "LLVMDebugInfoCodeView",
    "LLVMBitReader",
    "LLVMFuzzerCLI",
    "LLVMCore",
    "LLVMRemarks",
    "LLVMBitstreamReader",
    "LLVMBinaryFormat",
    "LLVMSupport",
    "LLVMDemangle",
};
