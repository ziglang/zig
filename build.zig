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

const zig_version: std.SemanticVersion = .{ .major = 0, .minor = 13, .patch = 0 };
const stack_size = 32 * 1024 * 1024;

pub fn build(b: *std.Build) !void {
    const only_c = b.option(bool, "only-c", "Translate the Zig compiler to C code, with only the C backend enabled") orelse false;
    const target = t: {
        var default_target: std.zig.CrossTarget = .{};
        default_target.ofmt = b.option(std.Target.ObjectFormat, "ofmt", "Object format to target") orelse if (only_c) .c else null;
        break :t b.standardTargetOptions(.{ .default_target = default_target });
    };

    const optimize = b.standardOptimizeOption(.{});

    const flat = b.option(bool, "flat", "Put files into the installation prefix in a manner suited for upstream distribution rather than a posix file system hierarchy standard") orelse false;
    const single_threaded = b.option(bool, "single-threaded", "Build artifacts that run in single threaded mode");
    const use_zig_libcxx = b.option(bool, "use-zig-libcxx", "If libc++ is needed, use zig's bundled version, don't try to integrate with the system") orelse false;

    const test_step = b.step("test", "Run all the tests");
    const skip_install_lib_files = b.option(bool, "no-lib", "skip copying of lib/ files and langref to installation prefix. Useful for development") orelse false;
    const skip_install_langref = b.option(bool, "no-langref", "skip copying of langref to the installation prefix") orelse skip_install_lib_files;
    const std_docs = b.option(bool, "std-docs", "include standard library autodocs") orelse false;
    const no_bin = b.option(bool, "no-bin", "skip emitting compiler binary") orelse false;

    const langref_file = generateLangRef(b);
    const install_langref = b.addInstallFileWithDir(langref_file, .prefix, "doc/langref.html");
    if (!skip_install_langref) {
        b.getInstallStep().dependOn(&install_langref.step);
    }

    const autodoc_test = b.addObject(.{
        .name = "std",
        .root_source_file = b.path("lib/std/std.zig"),
        .target = target,
        .zig_lib_dir = b.path("lib"),
        .optimize = .Debug,
    });
    const install_std_docs = b.addInstallDirectory(.{
        .source_dir = autodoc_test.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc/std",
    });
    if (std_docs) {
        b.getInstallStep().dependOn(&install_std_docs.step);
    }

    if (flat) {
        b.installFile("LICENSE", "LICENSE");
        b.installFile("README.md", "README.md");
    }

    const langref_step = b.step("langref", "Build and install the language reference");
    langref_step.dependOn(&install_langref.step);

    const std_docs_step = b.step("std-docs", "Build and install the standard library documentation");
    std_docs_step.dependOn(&install_std_docs.step);

    const docs_step = b.step("docs", "Build and install documentation");
    docs_step.dependOn(langref_step);
    docs_step.dependOn(std_docs_step);

    const check_case_exe = b.addExecutable(.{
        .name = "check-case",
        .root_source_file = b.path("test/src/Cases.zig"),
        .target = b.host,
        .optimize = optimize,
        .single_threaded = single_threaded,
    });
    check_case_exe.stack_size = stack_size;

    const skip_debug = b.option(bool, "skip-debug", "Main test suite skips debug builds") orelse false;
    const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse false;
    const skip_release_small = b.option(bool, "skip-release-small", "Main test suite skips release-small builds") orelse skip_release;
    const skip_release_fast = b.option(bool, "skip-release-fast", "Main test suite skips release-fast builds") orelse skip_release;
    const skip_release_safe = b.option(bool, "skip-release-safe", "Main test suite skips release-safe builds") orelse skip_release;
    const skip_non_native = b.option(bool, "skip-non-native", "Main test suite skips non-native builds") orelse false;
    const skip_libc = b.option(bool, "skip-libc", "Main test suite skips tests that link libc") orelse false;
    const skip_single_threaded = b.option(bool, "skip-single-threaded", "Main test suite skips tests that are single-threaded") orelse false;
    const skip_translate_c = b.option(bool, "skip-translate-c", "Main test suite skips translate-c tests") orelse false;
    const skip_run_translated_c = b.option(bool, "skip-run-translated-c", "Main test suite skips run-translated-c tests") orelse false;

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
    const llvm_has_xtensa = b.option(
        bool,
        "llvm-has-xtensa",
        "Whether LLVM has the experimental target xtensa enabled",
    ) orelse false;
    const enable_ios_sdk = b.option(bool, "enable-ios-sdk", "Run tests requiring presence of iOS SDK and frameworks") orelse false;
    const enable_macos_sdk = b.option(bool, "enable-macos-sdk", "Run tests requiring presence of macOS SDK and frameworks") orelse enable_ios_sdk;
    const enable_symlinks_windows = b.option(bool, "enable-symlinks-windows", "Run tests requiring presence of symlinks on Windows") orelse false;
    const config_h_path_option = b.option([]const u8, "config_h", "Path to the generated config.h");

    if (!skip_install_lib_files) {
        b.installDirectory(.{
            .source_dir = b.path("lib"),
            .install_dir = if (flat) .prefix else .lib,
            .install_subdir = if (flat) "lib" else "zig",
            .exclude_extensions = &[_][]const u8{
                // exclude files from lib/std/compress/testdata
                ".gz",
                ".z.0",
                ".z.9",
                ".zst.3",
                ".zst.19",
                "rfc1951.txt",
                "rfc1952.txt",
                "rfc8478.txt",
                // exclude files from lib/std/compress/flate/testdata
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
                // exclude files from lib/std/tar/testdata
                ".tar",
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

    const entitlements = b.option([]const u8, "entitlements", "Path to entitlements file for hot-code swapping without sudo on macOS");
    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy source");
    const tracy_callstack = b.option(bool, "tracy-callstack", "Include callstack information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    const tracy_allocation = b.option(bool, "tracy-allocation", "Include allocation information with Tracy data. Does nothing if -Dtracy is not provided") orelse (tracy != null);
    const force_gpa = b.option(bool, "force-gpa", "Force the compiler to use GeneralPurposeAllocator") orelse false;
    const link_libc = b.option(bool, "force-link-libc", "Force self-hosted compiler to link libc") orelse (enable_llvm or only_c);
    const sanitize_thread = b.option(bool, "sanitize-thread", "Enable thread-sanitization") orelse false;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pie = b.option(bool, "pie", "Produce a Position Independent Executable");
    const value_tracing = b.option(bool, "value-tracing", "Enable extra state tracking to help troubleshoot bugs in the compiler (using the std.debug.Trace API)") orelse false;

    const mem_leak_frames: u32 = b.option(u32, "mem-leak-frames", "How many stack frames to print when a memory leak occurs. Tests get 2x this amount.") orelse blk: {
        if (strip == true) break :blk @as(u32, 0);
        if (optimize != .Debug) break :blk 0;
        break :blk 4;
    };

    const exe = addCompilerStep(b, .{
        .optimize = optimize,
        .target = target,
        .strip = strip,
        .sanitize_thread = sanitize_thread,
        .single_threaded = single_threaded,
    });
    exe.pie = pie;
    exe.entitlements = entitlements;

    exe.build_id = b.option(
        std.zig.BuildId,
        "build-id",
        "Request creation of '.note.gnu.build-id' section",
    );

    if (no_bin) {
        b.getInstallStep().dependOn(&exe.step);
    } else {
        const install_exe = b.addInstallArtifact(exe, .{
            .dest_dir = if (flat) .{ .override = .prefix } else .default,
        });
        b.getInstallStep().dependOn(&install_exe.step);
    }

    test_step.dependOn(&exe.step);

    if (target.result.os.tag == .windows and target.result.abi == .gnu) {
        // LTO is currently broken on mingw, this can be removed when it's fixed.
        exe.want_lto = false;
        check_case_exe.want_lto = false;
    }

    const use_llvm = b.option(bool, "use-llvm", "Use the llvm backend");
    exe.use_llvm = use_llvm;
    exe.use_lld = use_llvm;

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);

    exe_options.addOption(u32, "mem_leak_frames", mem_leak_frames);
    exe_options.addOption(bool, "skip_non_native", skip_non_native);
    exe_options.addOption(bool, "have_llvm", enable_llvm);
    exe_options.addOption(bool, "llvm_has_m68k", llvm_has_m68k);
    exe_options.addOption(bool, "llvm_has_csky", llvm_has_csky);
    exe_options.addOption(bool, "llvm_has_arc", llvm_has_arc);
    exe_options.addOption(bool, "llvm_has_xtensa", llvm_has_xtensa);
    exe_options.addOption(bool, "force_gpa", force_gpa);
    exe_options.addOption(bool, "only_c", only_c);
    exe_options.addOption(bool, "only_core_functionality", only_c);

    if (link_libc) {
        exe.linkLibC();
        check_case_exe.linkLibC();
    }

    const is_debug = optimize == .Debug;
    const enable_debug_extensions = b.option(bool, "debug-extensions", "Enable commands and options useful for debugging the compiler") orelse is_debug;
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
        const git_describe_untrimmed = b.runAllowFail(&[_][]const u8{
            "git",
            "-C",
            b.build_root.path orelse ".",
            "describe",
            "--match",
            "*.*.*",
            "--tags",
            "--abbrev=9",
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
                var it = mem.splitScalar(u8, git_describe, '-');
                const tagged_ancestor = it.first();
                const commit_height = it.next().?;
                const commit_id = it.next().?;

                const ancestor_ver = try std.SemanticVersion.parse(tagged_ancestor);
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
                var it = mem.tokenizeScalar(u8, cfg.cmake_prefix_path, ';');
                while (it.next()) |path| {
                    b.addSearchPrefix(path);
                }
            }

            try addCmakeCfgOptionsToExe(b, cfg, exe, use_zig_libcxx);
            try addCmakeCfgOptionsToExe(b, cfg, check_case_exe, use_zig_libcxx);
        } else {
            // Here we are -Denable-llvm but no cmake integration.
            try addStaticLlvmOptionsToExe(exe);
            try addStaticLlvmOptionsToExe(check_case_exe);
        }
        if (target.result.os.tag == .windows) {
            inline for (.{ exe, check_case_exe }) |artifact| {
                artifact.linkSystemLibrary("version");
                artifact.linkSystemLibrary("uuid");
                artifact.linkSystemLibrary("ole32");
            }
        }
    }

    const semver = try std.SemanticVersion.parse(version);
    exe_options.addOption(std.SemanticVersion, "semver", semver);

    exe_options.addOption(bool, "enable_debug_extensions", enable_debug_extensions);
    exe_options.addOption(bool, "enable_logging", enable_logging);
    exe_options.addOption(bool, "enable_link_snapshots", enable_link_snapshots);
    exe_options.addOption(bool, "enable_tracy", tracy != null);
    exe_options.addOption(bool, "enable_tracy_callstack", tracy_callstack);
    exe_options.addOption(bool, "enable_tracy_allocation", tracy_allocation);
    exe_options.addOption(bool, "value_tracing", value_tracing);
    if (tracy) |tracy_path| {
        const client_cpp = b.pathJoin(
            &[_][]const u8{ tracy_path, "public", "TracyClient.cpp" },
        );

        // On mingw, we need to opt into windows 7+ to get some features required by tracy.
        const tracy_c_flags: []const []const u8 = if (target.result.os.tag == .windows and target.result.abi == .gnu)
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined", "-D_WIN32_WINNT=0x601" }
        else
            &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" };

        exe.addIncludePath(.{ .cwd_relative = tracy_path });
        exe.addCSourceFile(.{ .file = .{ .cwd_relative = client_cpp }, .flags = tracy_c_flags });
        if (!enable_llvm) {
            exe.root_module.linkSystemLibrary("c++", .{ .use_pkg_config = .no });
        }
        exe.linkLibC();

        if (target.result.os.tag == .windows) {
            exe.linkSystemLibrary("dbghelp");
            exe.linkSystemLibrary("ws2_32");
        }
    }

    const test_filters = b.option([]const []const u8, "test-filter", "Skip tests that do not match any filter") orelse &[0][]const u8{};

    const test_cases_options = b.addOptions();
    check_case_exe.root_module.addOptions("build_options", test_cases_options);

    test_cases_options.addOption(bool, "enable_tracy", false);
    test_cases_options.addOption(bool, "enable_debug_extensions", enable_debug_extensions);
    test_cases_options.addOption(bool, "enable_logging", enable_logging);
    test_cases_options.addOption(bool, "enable_link_snapshots", enable_link_snapshots);
    test_cases_options.addOption(bool, "skip_non_native", skip_non_native);
    test_cases_options.addOption(bool, "have_llvm", enable_llvm);
    test_cases_options.addOption(bool, "llvm_has_m68k", llvm_has_m68k);
    test_cases_options.addOption(bool, "llvm_has_csky", llvm_has_csky);
    test_cases_options.addOption(bool, "llvm_has_arc", llvm_has_arc);
    test_cases_options.addOption(bool, "llvm_has_xtensa", llvm_has_xtensa);
    test_cases_options.addOption(bool, "force_gpa", force_gpa);
    test_cases_options.addOption(bool, "only_c", only_c);
    test_cases_options.addOption(bool, "only_core_functionality", true);
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
    test_cases_options.addOption([]const []const u8, "test_filters", test_filters);

    var chosen_opt_modes_buf: [4]builtin.OptimizeMode = undefined;
    var chosen_mode_index: usize = 0;
    if (!skip_debug) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.OptimizeMode.Debug;
        chosen_mode_index += 1;
    }
    if (!skip_release_safe) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.OptimizeMode.ReleaseSafe;
        chosen_mode_index += 1;
    }
    if (!skip_release_fast) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.OptimizeMode.ReleaseFast;
        chosen_mode_index += 1;
    }
    if (!skip_release_small) {
        chosen_opt_modes_buf[chosen_mode_index] = builtin.OptimizeMode.ReleaseSmall;
        chosen_mode_index += 1;
    }
    const optimization_modes = chosen_opt_modes_buf[0..chosen_mode_index];

    const fmt_include_paths = &.{ "doc", "lib", "src", "test", "tools", "build.zig" };
    const fmt_exclude_paths = &.{"test/cases"};
    const do_fmt = b.addFmt(.{
        .paths = fmt_include_paths,
        .exclude_paths = fmt_exclude_paths,
    });

    b.step("test-fmt", "Check source files having conforming formatting").dependOn(&b.addFmt(.{
        .paths = fmt_include_paths,
        .exclude_paths = fmt_exclude_paths,
        .check = true,
    }).step);

    const test_cases_step = b.step("test-cases", "Run the main compiler test cases");
    try tests.addCases(b, test_cases_step, test_filters, check_case_exe, target, .{
        .skip_translate_c = skip_translate_c,
        .skip_run_translated_c = skip_run_translated_c,
    }, .{
        .enable_llvm = enable_llvm,
        .llvm_has_m68k = llvm_has_m68k,
        .llvm_has_csky = llvm_has_csky,
        .llvm_has_arc = llvm_has_arc,
        .llvm_has_xtensa = llvm_has_xtensa,
    });
    test_step.dependOn(test_cases_step);

    test_step.dependOn(tests.addModuleTests(b, .{
        .test_filters = test_filters,
        .root_src = "test/behavior.zig",
        .name = "behavior",
        .desc = "Run the behavior tests",
        .optimize_modes = optimization_modes,
        .include_paths = &.{},
        .skip_single_threaded = skip_single_threaded,
        .skip_non_native = skip_non_native,
        .skip_libc = skip_libc,
        .max_rss = 1 * 1024 * 1024 * 1024,
    }));

    test_step.dependOn(tests.addModuleTests(b, .{
        .test_filters = test_filters,
        .root_src = "test/c_import.zig",
        .name = "c-import",
        .desc = "Run the @cImport tests",
        .optimize_modes = optimization_modes,
        .include_paths = &.{"test/c_import"},
        .skip_single_threaded = true,
        .skip_non_native = skip_non_native,
        .skip_libc = skip_libc,
    }));

    test_step.dependOn(tests.addModuleTests(b, .{
        .test_filters = test_filters,
        .root_src = "lib/compiler_rt.zig",
        .name = "compiler-rt",
        .desc = "Run the compiler_rt tests",
        .optimize_modes = optimization_modes,
        .include_paths = &.{},
        .skip_single_threaded = true,
        .skip_non_native = skip_non_native,
        .skip_libc = true,
    }));

    test_step.dependOn(tests.addModuleTests(b, .{
        .test_filters = test_filters,
        .root_src = "lib/c.zig",
        .name = "universal-libc",
        .desc = "Run the universal libc tests",
        .optimize_modes = optimization_modes,
        .include_paths = &.{},
        .skip_single_threaded = true,
        .skip_non_native = skip_non_native,
        .skip_libc = true,
    }));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filters, optimization_modes));
    test_step.dependOn(tests.addStandaloneTests(
        b,
        optimization_modes,
        enable_macos_sdk,
        enable_ios_sdk,
        enable_symlinks_windows,
    ));
    test_step.dependOn(tests.addCAbiTests(b, skip_non_native, skip_release));
    test_step.dependOn(tests.addLinkTests(b, enable_macos_sdk, enable_ios_sdk, enable_symlinks_windows));
    test_step.dependOn(tests.addStackTraceTests(b, test_filters, optimization_modes));
    test_step.dependOn(tests.addCliTests(b));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filters, optimization_modes));
    test_step.dependOn(tests.addModuleTests(b, .{
        .test_filters = test_filters,
        .root_src = "lib/std/std.zig",
        .name = "std",
        .desc = "Run the standard library tests",
        .optimize_modes = optimization_modes,
        .include_paths = &.{},
        .skip_single_threaded = skip_single_threaded,
        .skip_non_native = skip_non_native,
        .skip_libc = skip_libc,
        // I observed a value of 4572626944 on the M2 CI.
        .max_rss = 5029889638,
    }));

    try addWasiUpdateStep(b, version);

    b.step("fmt", "Modify source files in place to have conforming formatting")
        .dependOn(&do_fmt.step);

    const update_mingw_step = b.step("update-mingw", "Update zig's bundled mingw");
    const opt_mingw_src_path = b.option([]const u8, "mingw-src", "path to mingw-w64 source directory");
    const update_mingw_exe = b.addExecutable(.{
        .name = "update_mingw",
        .target = b.host,
        .root_source_file = b.path("tools/update_mingw.zig"),
    });
    const update_mingw_run = b.addRunArtifact(update_mingw_exe);
    update_mingw_run.addDirectoryArg(b.path("lib"));
    if (opt_mingw_src_path) |mingw_src_path| {
        update_mingw_run.addDirectoryArg(.{ .cwd_relative = mingw_src_path });
    } else {
        // Intentionally cause an error if this build step is requested.
        update_mingw_run.addArg("--missing-mingw-source-directory");
    }

    update_mingw_step.dependOn(&update_mingw_run.step);
}

fn addWasiUpdateStep(b: *std.Build, version: [:0]const u8) !void {
    const semver = try std.SemanticVersion.parse(version);

    var target_query: std.zig.CrossTarget = .{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    };
    target_query.cpu_features_add.addFeature(@intFromEnum(std.Target.wasm.Feature.bulk_memory));

    const exe = addCompilerStep(b, .{
        .optimize = .ReleaseSmall,
        .target = b.resolveTargetQuery(target_query),
    });

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);

    exe_options.addOption(u32, "mem_leak_frames", 0);
    exe_options.addOption(bool, "have_llvm", false);
    exe_options.addOption(bool, "force_gpa", false);
    exe_options.addOption(bool, "only_c", true);
    exe_options.addOption([:0]const u8, "version", version);
    exe_options.addOption(std.SemanticVersion, "semver", semver);
    exe_options.addOption(bool, "enable_debug_extensions", false);
    exe_options.addOption(bool, "enable_logging", false);
    exe_options.addOption(bool, "enable_link_snapshots", false);
    exe_options.addOption(bool, "enable_tracy", false);
    exe_options.addOption(bool, "enable_tracy_callstack", false);
    exe_options.addOption(bool, "enable_tracy_allocation", false);
    exe_options.addOption(bool, "value_tracing", false);
    exe_options.addOption(bool, "only_core_functionality", true);

    const run_opt = b.addSystemCommand(&.{
        "wasm-opt",
        "-Oz",
        "--enable-bulk-memory",
        "--enable-sign-ext",
    });
    run_opt.addArtifactArg(exe);
    run_opt.addArg("-o");
    run_opt.addFileArg(b.path("stage1/zig1.wasm"));

    const copy_zig_h = b.addWriteFiles();
    copy_zig_h.addCopyFileToSource(b.path("lib/zig.h"), "stage1/zig.h");

    const update_zig1_step = b.step("update-zig1", "Update stage1/zig1.wasm");
    update_zig1_step.dependOn(&run_opt.step);
    update_zig1_step.dependOn(&copy_zig_h.step);
}

const AddCompilerStepOptions = struct {
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    strip: ?bool = null,
    sanitize_thread: ?bool = null,
    single_threaded: ?bool = null,
};

fn addCompilerStep(b: *std.Build, options: AddCompilerStepOptions) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "zig",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .max_rss = 7_000_000_000,
        .strip = options.strip,
        .sanitize_thread = options.sanitize_thread,
        .single_threaded = options.single_threaded,
    });
    exe.stack_size = stack_size;

    const aro_module = b.createModule(.{
        .root_source_file = b.path("lib/compiler/aro/aro.zig"),
    });

    const aro_translate_c_module = b.createModule(.{
        .root_source_file = b.path("lib/compiler/aro_translate_c.zig"),
        .imports = &.{
            .{
                .name = "aro",
                .module = aro_module,
            },
        },
    });

    exe.root_module.addImport("aro", aro_module);
    exe.root_module.addImport("aro_translate_c", aro_translate_c_module);
    return exe;
}

const exe_cflags = [_][]const u8{
    "-std=c++17",
    "-D__STDC_CONSTANT_MACROS",
    "-D__STDC_FORMAT_MACROS",
    "-D__STDC_LIMIT_MACROS",
    "-D_GNU_SOURCE",
    "-fvisibility-inlines-hidden",
    "-fno-exceptions",
    "-fno-rtti",
    "-Wno-type-limits",
    "-Wno-missing-braces",
    "-Wno-comment",
};

fn addCmakeCfgOptionsToExe(
    b: *std.Build,
    cfg: CMakeConfig,
    exe: *std.Build.Step.Compile,
    use_zig_libcxx: bool,
) !void {
    if (exe.rootModuleTarget().isDarwin()) {
        // useful for package maintainers
        exe.headerpad_max_install_names = true;
    }
    exe.addObjectFile(.{ .cwd_relative = b.pathJoin(&[_][]const u8{
        cfg.cmake_binary_dir,
        "zigcpp",
        b.fmt("{s}{s}{s}", .{
            cfg.cmake_static_library_prefix,
            "zigcpp",
            cfg.cmake_static_library_suffix,
        }),
    }) });
    assert(cfg.lld_include_dir.len != 0);
    exe.addIncludePath(.{ .cwd_relative = cfg.lld_include_dir });
    exe.addIncludePath(.{ .cwd_relative = cfg.llvm_include_dir });
    exe.addLibraryPath(.{ .cwd_relative = cfg.llvm_lib_dir });
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
        const lib_suffix = if (static) exe.rootModuleTarget().staticLibSuffix()[1..] else exe.rootModuleTarget().dynamicLibSuffix()[1..];
        switch (exe.rootModuleTarget().os.tag) {
            .linux => {
                // First we try to link against the detected libcxx name. If that doesn't work, we fall
                // back to -lc++ and cross our fingers.
                addCxxKnownPath(b, cfg, exe, b.fmt("lib{s}.{s}", .{ cfg.system_libcxx, lib_suffix }), "", need_cpp_includes) catch |err| switch (err) {
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
                if (exe.rootModuleTarget().abi != .msvc) exe.linkLibCpp();
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
            .solaris, .illumos => {
                try addCxxKnownPath(b, cfg, exe, b.fmt("libstdc++.{s}", .{lib_suffix}), null, need_cpp_includes);
                try addCxxKnownPath(b, cfg, exe, b.fmt("libgcc_eh.{s}", .{lib_suffix}), null, need_cpp_includes);
            },
            .haiku => {
                try addCxxKnownPath(b, cfg, exe, b.fmt("libstdc++.{s}", .{lib_suffix}), null, need_cpp_includes);
            },
            else => {},
        }
    }

    if (cfg.dia_guids_lib.len != 0) {
        exe.addObjectFile(.{ .cwd_relative = cfg.dia_guids_lib });
    }
}

fn addStaticLlvmOptionsToExe(exe: *std.Build.Step.Compile) !void {
    // Adds the Zig C++ sources which both stage1 and stage2 need.
    //
    // We need this because otherwise zig_clang_cc1_main.cpp ends up pulling
    // in a dependency on llvm::cfg::Update<llvm::BasicBlock*>::dump() which is
    // unavailable when LLVM is compiled in Release mode.
    const zig_cpp_cflags = exe_cflags ++ [_][]const u8{"-DNDEBUG=1"};
    exe.addCSourceFiles(.{
        .files = &zig_cpp_sources,
        .flags = &zig_cpp_cflags,
    });

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

    if (exe.rootModuleTarget().os.tag != .windows or exe.rootModuleTarget().abi != .msvc) {
        // This means we rely on clang-or-zig-built LLVM, Clang, LLD libraries.
        exe.linkSystemLibrary("c++");
    }

    if (exe.rootModuleTarget().os.tag == .windows) {
        exe.linkSystemLibrary("version");
        exe.linkSystemLibrary("uuid");
        exe.linkSystemLibrary("ole32");
    }
}

fn addCxxKnownPath(
    b: *std.Build,
    ctx: CMakeConfig,
    exe: *std.Build.Step.Compile,
    objname: []const u8,
    errtxt: ?[]const u8,
    need_cpp_includes: bool,
) !void {
    if (!std.process.can_spawn)
        return error.RequiredLibraryNotFound;

    const path_padded = run: {
        var args = std.ArrayList([]const u8).init(b.allocator);
        try args.append(ctx.cxx_compiler);
        var it = std.mem.tokenizeAny(u8, ctx.cxx_compiler_arg1, &std.ascii.whitespace);
        while (it.next()) |arg| try args.append(arg);
        try args.append(b.fmt("-print-file-name={s}", .{objname}));
        break :run b.run(args.items);
    };
    var tokenizer = mem.tokenizeAny(u8, path_padded, "\r\n");
    const path_unpadded = tokenizer.next().?;
    if (mem.eql(u8, path_unpadded, objname)) {
        if (errtxt) |msg| {
            std.debug.print("{s}", .{msg});
        } else {
            std.debug.print("Unable to determine path to {s}\n", .{objname});
        }
        return error.RequiredLibraryNotFound;
    }
    exe.addObjectFile(.{ .cwd_relative = path_unpadded });

    // TODO a way to integrate with system c++ include files here
    // c++ -E -Wp,-v -xc++ /dev/null
    if (need_cpp_includes) {
        // I used these temporarily for testing something but we obviously need a
        // more general purpose solution here.
        //exe.addIncludePath("/nix/store/2lr0fc0ak8rwj0k8n3shcyz1hz63wzma-gcc-11.3.0/include/c++/11.3.0");
        //exe.addIncludePath("/nix/store/2lr0fc0ak8rwj0k8n3shcyz1hz63wzma-gcc-11.3.0/include/c++/11.3.0/x86_64-unknown-linux-gnu");
    }
}

fn addCMakeLibraryList(exe: *std.Build.Step.Compile, list: []const u8) void {
    var it = mem.tokenizeScalar(u8, list, ';');
    while (it.next()) |lib| {
        if (mem.startsWith(u8, lib, "-l")) {
            exe.linkSystemLibrary(lib["-l".len..]);
        } else if (exe.rootModuleTarget().os.tag == .windows and
            mem.endsWith(u8, lib, ".lib") and !fs.path.isAbsolute(lib))
        {
            exe.linkSystemLibrary(lib[0 .. lib.len - ".lib".len]);
        } else {
            exe.addObjectFile(.{ .cwd_relative = lib });
        }
    }
}

const CMakeConfig = struct {
    llvm_linkage: std.builtin.LinkMode,
    cmake_binary_dir: []const u8,
    cmake_prefix_path: []const u8,
    cmake_static_library_prefix: []const u8,
    cmake_static_library_suffix: []const u8,
    cxx_compiler: []const u8,
    cxx_compiler_arg1: []const u8,
    lld_include_dir: []const u8,
    lld_libraries: []const u8,
    clang_libraries: []const u8,
    llvm_lib_dir: []const u8,
    llvm_include_dir: []const u8,
    llvm_libraries: []const u8,
    dia_guids_lib: []const u8,
    system_libcxx: []const u8,
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
            std.process.exit(1);
        }
    }

    var check_dir = fs.path.dirname(b.graph.zig_exe).?;
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
    }
}

fn parseConfigH(b: *std.Build, config_h_text: []const u8) ?CMakeConfig {
    var ctx: CMakeConfig = .{
        .llvm_linkage = undefined,
        .cmake_binary_dir = undefined,
        .cmake_prefix_path = undefined,
        .cmake_static_library_prefix = undefined,
        .cmake_static_library_suffix = undefined,
        .cxx_compiler = undefined,
        .cxx_compiler_arg1 = "",
        .lld_include_dir = undefined,
        .lld_libraries = undefined,
        .clang_libraries = undefined,
        .llvm_lib_dir = undefined,
        .llvm_include_dir = undefined,
        .llvm_libraries = undefined,
        .dia_guids_lib = undefined,
        .system_libcxx = undefined,
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
            .prefix = "#define ZIG_CXX_COMPILER_ARG1 ",
            .field = "cxx_compiler_arg1",
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
        .{
            .prefix = "#define ZIG_SYSTEM_LIBCXX",
            .field = "system_libcxx",
        },
        // .prefix = ZIG_LLVM_LINK_MODE parsed manually below
    };

    var lines_it = mem.tokenizeAny(u8, config_h_text, "\r\n");
    while (lines_it.next()) |line| {
        inline for (mappings) |mapping| {
            if (mem.startsWith(u8, line, mapping.prefix)) {
                var it = mem.splitScalar(u8, line, '"');
                _ = it.first(); // skip the stuff before the quote
                const quoted = it.next().?; // the stuff inside the quote
                const trimmed = mem.trim(u8, quoted, " ");
                @field(ctx, mapping.field) = toNativePathSep(b, trimmed);
            }
        }
        if (mem.startsWith(u8, line, "#define ZIG_LLVM_LINK_MODE ")) {
            var it = mem.splitScalar(u8, line, '"');
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
    "clangAPINotes",
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
    "LLVMXRay",
    "LLVMLibDriver",
    "LLVMDlltoolDriver",
    "LLVMTextAPIBinaryReader",
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
    "LLVMWebAssemblyUtils",
    "LLVMWebAssemblyDesc",
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
    "LLVMRISCVTargetMCA",
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
    "LLVMLoongArchDisassembler",
    "LLVMLoongArchAsmParser",
    "LLVMLoongArchCodeGen",
    "LLVMLoongArchDesc",
    "LLVMLoongArchInfo",
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
    "LLVMOrcDebugging",
    "LLVMOrcJIT",
    "LLVMWindowsDriver",
    "LLVMMCJIT",
    "LLVMJITLink",
    "LLVMInterpreter",
    "LLVMExecutionEngine",
    "LLVMRuntimeDyld",
    "LLVMOrcTargetProcess",
    "LLVMOrcShared",
    "LLVMDWP",
    "LLVMDebugInfoLogicalView",
    "LLVMDebugInfoGSYM",
    "LLVMOption",
    "LLVMObjectYAML",
    "LLVMObjCopy",
    "LLVMMCA",
    "LLVMMCDisassembler",
    "LLVMLTO",
    "LLVMPasses",
    "LLVMHipStdPar",
    "LLVMCFGuard",
    "LLVMCoroutines",
    "LLVMipo",
    "LLVMVectorize",
    "LLVMLinker",
    "LLVMInstrumentation",
    "LLVMFrontendOpenMP",
    "LLVMFrontendOffloading",
    "LLVMFrontendOpenACC",
    "LLVMFrontendHLSL",
    "LLVMFrontendDriver",
    "LLVMExtensions",
    "LLVMDWARFLinkerParallel",
    "LLVMDWARFLinkerClassic",
    "LLVMDWARFLinker",
    "LLVMGlobalISel",
    "LLVMMIRParser",
    "LLVMAsmPrinter",
    "LLVMSelectionDAG",
    "LLVMCodeGen",
    "LLVMTarget",
    "LLVMObjCARCOpts",
    "LLVMCodeGenTypes",
    "LLVMIRPrinter",
    "LLVMInterfaceStub",
    "LLVMFileCheck",
    "LLVMFuzzMutate",
    "LLVMScalarOpts",
    "LLVMInstCombine",
    "LLVMAggressiveInstCombine",
    "LLVMTransformUtils",
    "LLVMBitWriter",
    "LLVMAnalysis",
    "LLVMProfileData",
    "LLVMSymbolize",
    "LLVMDebugInfoBTF",
    "LLVMDebugInfoPDB",
    "LLVMDebugInfoMSF",
    "LLVMDebugInfoDWARF",
    "LLVMObject",
    "LLVMTextAPI",
    "LLVMMCParser",
    "LLVMIRReader",
    "LLVMAsmParser",
    "LLVMMC",
    "LLVMDebugInfoCodeView",
    "LLVMBitReader",
    "LLVMFuzzerCLI",
    "LLVMCore",
    "LLVMRemarks",
    "LLVMBitstreamReader",
    "LLVMBinaryFormat",
    "LLVMTargetParser",
    "LLVMSupport",
    "LLVMDemangle",
};

fn generateLangRef(b: *std.Build) std.Build.LazyPath {
    const doctest_exe = b.addExecutable(.{
        .name = "doctest",
        .root_source_file = b.path("tools/doctest.zig"),
        .target = b.host,
        .optimize = .Debug,
    });

    var dir = b.build_root.handle.openDir("doc/langref", .{ .iterate = true }) catch |err| {
        std.debug.panic("unable to open 'doc/langref' directory: {s}", .{@errorName(err)});
    };
    defer dir.close();

    var wf = b.addWriteFiles();

    var it = dir.iterateAssumeFirstIteration();
    while (it.next() catch @panic("failed to read dir")) |entry| {
        if (std.mem.startsWith(u8, entry.name, ".") or entry.kind != .file)
            continue;

        const out_basename = b.fmt("{s}.out", .{std.fs.path.stem(entry.name)});
        const cmd = b.addRunArtifact(doctest_exe);
        cmd.addArgs(&.{
            "--zig",        b.graph.zig_exe,
            // TODO: enhance doctest to use "--listen=-" rather than operating
            // in a temporary directory
            "--cache-root", b.cache_root.path orelse ".",
        });
        if (b.zig_lib_dir) |p| {
            cmd.addArg("--zig-lib-dir");
            cmd.addDirectoryArg(p);
        }
        cmd.addArgs(&.{"-i"});
        cmd.addFileArg(b.path(b.fmt("doc/langref/{s}", .{entry.name})));

        cmd.addArgs(&.{"-o"});
        _ = wf.addCopyFile(cmd.addOutputFileArg(out_basename), out_basename);
    }

    const docgen_exe = b.addExecutable(.{
        .name = "docgen",
        .root_source_file = b.path("tools/docgen.zig"),
        .target = b.host,
        .optimize = .Debug,
    });

    const docgen_cmd = b.addRunArtifact(docgen_exe);
    docgen_cmd.addArgs(&.{"--code-dir"});
    docgen_cmd.addDirectoryArg(wf.getDirectory());

    docgen_cmd.addFileArg(b.path("doc/langref.html.in"));
    return docgen_cmd.addOutputFileArg("langref.html");
}
