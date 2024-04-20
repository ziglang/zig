const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const OptimizeMode = std.builtin.OptimizeMode;
const Step = std.Build.Step;

// Cases
const compare_output = @import("compare_output.zig");
const stack_traces = @import("stack_traces.zig");
const assemble_and_link = @import("assemble_and_link.zig");
const translate_c = @import("translate_c.zig");
const run_translated_c = @import("run_translated_c.zig");

// Implementations
pub const TranslateCContext = @import("src/TranslateC.zig");
pub const RunTranslatedCContext = @import("src/RunTranslatedC.zig");
pub const CompareOutputContext = @import("src/CompareOutput.zig");
pub const StackTracesContext = @import("src/StackTrace.zig");

const TestTarget = struct {
    target: std.Target.Query = .{},
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    pic: ?bool = null,
    strip: ?bool = null,
};

const test_targets = blk: {
    // getBaselineCpuFeatures calls populateDependencies which has a O(N ^ 2) algorithm
    // (where N is roughly 160, which technically makes it O(1), but it adds up to a
    // lot of branches)
    @setEvalBranchQuota(50000);
    break :blk [_]TestTarget{
        .{},
        .{
            .link_libc = true,
        },
        .{
            .single_threaded = true,
        },
        .{
            .optimize_mode = .ReleaseFast,
        },
        .{
            .link_libc = true,
            .optimize_mode = .ReleaseFast,
        },
        .{
            .optimize_mode = .ReleaseFast,
            .single_threaded = true,
        },

        .{
            .optimize_mode = .ReleaseSafe,
        },
        .{
            .link_libc = true,
            .optimize_mode = .ReleaseSafe,
        },
        .{
            .optimize_mode = .ReleaseSafe,
            .single_threaded = true,
        },

        .{
            .optimize_mode = .ReleaseSmall,
        },
        .{
            .link_libc = true,
            .optimize_mode = .ReleaseSmall,
        },
        .{
            .optimize_mode = .ReleaseSmall,
            .single_threaded = true,
        },

        .{
            .target = .{
                .ofmt = .c,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 },
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
            .pic = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
            .strip = true,
        },
        // Doesn't support new liveness
        //.{
        //    .target = .{
        //        .cpu_arch = .aarch64,
        //        .os_tag = .linux,
        //    },
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .use_llvm = false,
            .use_lld = false,
        },
        // https://github.com/ziglang/zig/issues/13623
        //.{
        //    .target = .{
        //        .cpu_arch = .arm,
        //        .os_tag = .linux,
        //    },
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        // https://github.com/ziglang/zig/issues/13623
        //.{
        //    .target = std.Target.Query.parse(.{
        //        .arch_os_abi = "arm-linux-none",
        //        .cpu_features = "generic+v8a",
        //    }) catch unreachable,
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        // Doesn't support new liveness
        //.{
        //    .target = .{
        //        .cpu_arch = .aarch64,
        //        .os_tag = .macos,
        //        .abi = .none,
        //    },
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .macos,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .gnu,
            },
            .use_llvm = false,
            .use_lld = false,
        },

        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .link_libc = false,
        },
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
            .use_lld = false,
        },

        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .windows,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "arm-linux-none",
                .cpu_features = "generic+v8a",
            }) catch unreachable,
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "arm-linux-musleabihf",
                .cpu_features = "generic+v8a",
            }) catch unreachable,
            .link_libc = true,
        },
        // https://github.com/ziglang/zig/issues/3287
        //.{
        //    .target = std.Target.Query.parse(.{
        //        .arch_os_abi = "arm-linux-gnueabihf",
        //        .cpu_features = "generic+v8a",
        //    }) catch unreachable,
        //    .link_libc = true,
        //},

        // https://github.com/ziglang/zig/issues/16846
        //.{
        //    .target = .{
        //        .cpu_arch = .mips,
        //        .os_tag = .linux,
        //        .abi = .none,
        //    },
        //},

        // https://github.com/ziglang/zig/issues/16846
        //.{
        //    .target = .{
        //        .cpu_arch = .mips,
        //        .os_tag = .linux,
        //        .abi = .musl,
        //    },
        //    .link_libc = true,
        //},

        // https://github.com/ziglang/zig/issues/4927
        //.{
        //    .target = .{
        //        .cpu_arch = .mips,
        //        .os_tag = .linux,
        //        .abi = .gnueabihf,
        //    },
        //    .link_libc = true,
        //},

        // https://github.com/ziglang/zig/issues/16846
        //.{
        //    .target = .{
        //        .cpu_arch = .mipsel,
        //        .os_tag = .linux,
        //        .abi = .none,
        //    },
        //},

        // https://github.com/ziglang/zig/issues/16846
        //.{
        //    .target = .{
        //        .cpu_arch = .mipsel,
        //        .os_tag = .linux,
        //        .abi = .musl,
        //    },
        //    .link_libc = true,
        //},

        // https://github.com/ziglang/zig/issues/4927
        //.{
        //    .target = .{
        //        .cpu_arch = .mipsel,
        //        .os_tag = .linux,
        //        .abi = .gnueabihf,
        //    },
        //    .link_libc = true,
        //},

        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        // https://github.com/ziglang/zig/issues/2256
        //.{
        //    .target = .{
        //        .cpu_arch = .powerpc,
        //        .os_tag = .linux,
        //        .abi = .gnueabihf,
        //    },
        //    .link_libc = true,
        //},

        .{
            .target = .{
                .cpu_arch = .powerpc64le,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc64le,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc64le,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        // Disabled until LLVM fixes their O(N^2) codegen.
        // https://github.com/ziglang/zig/issues/18872
        //.{
        //    .target = .{
        //        .cpu_arch = .riscv64,
        //        .os_tag = .linux,
        //        .abi = .none,
        //    },
        //    .use_llvm = true,
        //},

        // Disabled until LLVM fixes their O(N^2) codegen.
        // https://github.com/ziglang/zig/issues/18872
        //.{
        //    .target = .{
        //        .cpu_arch = .riscv64,
        //        .os_tag = .linux,
        //        .abi = .musl,
        //    },
        //    .link_libc = true,
        //    .use_llvm = true,
        //},

        // https://github.com/ziglang/zig/issues/3340
        //.{
        //    .target = .{
        //        .cpu_arch = .riscv64,
        //        .os = .linux,
        //        .abi = .gnu,
        //    },
        //    .link_libc = true,
        //},

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .macos,
                .abi = .none,
            },
        },

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .macos,
                .abi = .none,
            },
        },

        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .windows,
                .abi = .msvc,
            },
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .msvc,
            },
        },

        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .windows,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .gnu,
            },
            .link_libc = true,
        },
    };
};

const CAbiTarget = struct {
    target: std.Target.Query = .{},
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    pic: ?bool = null,
    strip: ?bool = null,
    c_defines: []const []const u8 = &.{},
};

const c_abi_targets = [_]CAbiTarget{
    .{},
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .musl,
        },
        .use_llvm = false,
        .use_lld = false,
        .c_defines = &.{"ZIG_BACKEND_STAGE2_X86_64"},
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 },
            .os_tag = .linux,
            .abi = .musl,
        },
        .use_llvm = false,
        .use_lld = false,
        .strip = true,
        .c_defines = &.{"ZIG_BACKEND_STAGE2_X86_64"},
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
            .os_tag = .linux,
            .abi = .musl,
        },
        .use_llvm = false,
        .use_lld = false,
        .pic = true,
        .c_defines = &.{"ZIG_BACKEND_STAGE2_X86_64"},
    },
    .{
        .target = .{
            .cpu_arch = .x86,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .arm,
            .os_tag = .linux,
            .abi = .musleabihf,
        },
    },
    .{
        .target = .{
            .cpu_arch = .mips,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .riscv64,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .powerpc,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .powerpc64le,
            .os_tag = .linux,
            .abi = .musl,
        },
    },
    .{
        .target = .{
            .cpu_arch = .x86,
            .os_tag = .windows,
            .abi = .gnu,
        },
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        },
    },
};

pub fn addCompareOutputTests(
    b: *std.Build,
    test_filters: []const []const u8,
    optimize_modes: []const OptimizeMode,
) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch @panic("OOM");
    cases.* = CompareOutputContext{
        .b = b,
        .step = b.step("test-compare-output", "Run the compare output tests"),
        .test_index = 0,
        .test_filters = test_filters,
        .optimize_modes = optimize_modes,
    };

    compare_output.addCases(cases);

    return cases.step;
}

pub fn addStackTraceTests(
    b: *std.Build,
    test_filters: []const []const u8,
    optimize_modes: []const OptimizeMode,
) *Step {
    const check_exe = b.addExecutable(.{
        .name = "check-stack-trace",
        .root_source_file = b.path("test/src/check-stack-trace.zig"),
        .target = b.host,
        .optimize = .Debug,
    });

    const cases = b.allocator.create(StackTracesContext) catch @panic("OOM");
    cases.* = .{
        .b = b,
        .step = b.step("test-stack-traces", "Run the stack trace tests"),
        .test_index = 0,
        .test_filters = test_filters,
        .optimize_modes = optimize_modes,
        .check_exe = check_exe,
    };

    stack_traces.addCases(cases);

    return cases.step;
}

fn compilerHasPackageManager(b: *std.Build) bool {
    // We can only use dependencies if the compiler was built with support for package management.
    // (zig2 doesn't support it, but we still need to construct a build graph to build stage3.)
    return b.available_deps.len != 0;
}

pub fn addStandaloneTests(
    b: *std.Build,
    optimize_modes: []const OptimizeMode,
    enable_macos_sdk: bool,
    enable_ios_sdk: bool,
    enable_symlinks_windows: bool,
) *Step {
    const step = b.step("test-standalone", "Run the standalone tests");
    if (compilerHasPackageManager(b)) {
        const test_cases_dep_name = "standalone_test_cases";
        const test_cases_dep = b.dependency(test_cases_dep_name, .{
            .enable_ios_sdk = enable_ios_sdk,
            .enable_macos_sdk = enable_macos_sdk,
            .enable_symlinks_windows = enable_symlinks_windows,
            .simple_skip_debug = mem.indexOfScalar(OptimizeMode, optimize_modes, .Debug) == null,
            .simple_skip_release_safe = mem.indexOfScalar(OptimizeMode, optimize_modes, .ReleaseSafe) == null,
            .simple_skip_release_fast = mem.indexOfScalar(OptimizeMode, optimize_modes, .ReleaseFast) == null,
            .simple_skip_release_small = mem.indexOfScalar(OptimizeMode, optimize_modes, .ReleaseSmall) == null,
        });
        const test_cases_dep_step = test_cases_dep.builder.default_step;
        test_cases_dep_step.name = b.dupe(test_cases_dep_name);
        step.dependOn(test_cases_dep.builder.default_step);
    }
    return step;
}

pub fn addLinkTests(
    b: *std.Build,
    enable_macos_sdk: bool,
    enable_ios_sdk: bool,
    enable_symlinks_windows: bool,
) *Step {
    const step = b.step("test-link", "Run the linker tests");
    if (compilerHasPackageManager(b)) {
        const test_cases_dep_name = "link_test_cases";
        const test_cases_dep = b.dependency(test_cases_dep_name, .{
            .enable_ios_sdk = enable_ios_sdk,
            .enable_macos_sdk = enable_macos_sdk,
            .enable_symlinks_windows = enable_symlinks_windows,
        });
        const test_cases_dep_step = test_cases_dep.builder.default_step;
        test_cases_dep_step.name = b.dupe(test_cases_dep_name);
        step.dependOn(test_cases_dep.builder.default_step);
    }
    return step;
}

pub fn addCliTests(b: *std.Build) *Step {
    const step = b.step("test-cli", "Test the command line interface");
    const s = std.fs.path.sep_str;

    {
        // Test `zig init`.
        const tmp_path = b.makeTempPath();
        const init_exe = b.addSystemCommand(&.{ b.graph.zig_exe, "init" });
        init_exe.setCwd(.{ .cwd_relative = tmp_path });
        init_exe.setName("zig init");
        init_exe.expectStdOutEqual("");
        init_exe.expectStdErrEqual("info: created build.zig\n" ++
            "info: created build.zig.zon\n" ++
            "info: created src" ++ s ++ "main.zig\n" ++
            "info: created src" ++ s ++ "root.zig\n" ++
            "info: see `zig build --help` for a menu of options\n");

        // Test missing output path.
        const bad_out_arg = "-femit-bin=does" ++ s ++ "not" ++ s ++ "exist" ++ s ++ "foo.exe";
        const ok_src_arg = "src" ++ s ++ "main.zig";
        const expected = "error: unable to open output directory 'does" ++ s ++ "not" ++ s ++ "exist': FileNotFound\n";
        const run_bad = b.addSystemCommand(&.{ b.graph.zig_exe, "build-exe", ok_src_arg, bad_out_arg });
        run_bad.setName("zig build-exe error message for bad -femit-bin arg");
        run_bad.expectExitCode(1);
        run_bad.expectStdErrEqual(expected);
        run_bad.expectStdOutEqual("");
        run_bad.step.dependOn(&init_exe.step);

        const run_test = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "test" });
        run_test.setCwd(.{ .cwd_relative = tmp_path });
        run_test.setName("zig build test");
        run_test.expectStdOutEqual("");
        run_test.step.dependOn(&init_exe.step);

        const run_run = b.addSystemCommand(&.{ b.graph.zig_exe, "build", "run" });
        run_run.setCwd(.{ .cwd_relative = tmp_path });
        run_run.setName("zig build run");
        run_run.expectStdOutEqual("Run `zig build test` to run the tests.\n");
        run_run.expectStdErrEqual("All your codebase are belong to us.\n");
        run_run.step.dependOn(&init_exe.step);

        const cleanup = b.addRemoveDirTree(tmp_path);
        cleanup.step.dependOn(&run_test.step);
        cleanup.step.dependOn(&run_run.step);
        cleanup.step.dependOn(&run_bad.step);

        step.dependOn(&cleanup.step);
    }

    // Test Godbolt API
    if (builtin.os.tag == .linux and builtin.cpu.arch == .x86_64) {
        const tmp_path = b.makeTempPath();

        const writefile = b.addWriteFile("example.zig",
            \\// Type your code here, or load an example.
            \\export fn square(num: i32) i32 {
            \\    return num * num;
            \\}
            \\extern fn zig_panic() noreturn;
            \\pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
            \\    _ = msg;
            \\    _ = error_return_trace;
            \\    zig_panic();
            \\}
        );

        // This is intended to be the exact CLI usage used by godbolt.org.
        const run = b.addSystemCommand(&.{
            b.graph.zig_exe, "build-obj",
            "--cache-dir",   tmp_path,
            "--name",        "example",
            "-fno-emit-bin", "-fno-emit-h",
            "-fstrip",       "-OReleaseFast",
        });
        run.addFileArg(writefile.files.items[0].getPath());
        const example_s = run.addPrefixedOutputFileArg("-femit-asm=", "example.s");

        const checkfile = b.addCheckFile(example_s, .{
            .expected_matches = &.{
                "square:",
                "mov\teax, edi",
                "imul\teax, edi",
            },
        });
        checkfile.setName("check godbolt.org CLI usage generating valid asm");

        const cleanup = b.addRemoveDirTree(tmp_path);
        cleanup.step.dependOn(&checkfile.step);

        step.dependOn(&cleanup.step);
    }

    {
        // Test `zig fmt`.
        // This test must use a temporary directory rather than a cache
        // directory because this test will be mutating the files. The cache
        // system relies on cache directories being mutated only by their
        // owners.
        const tmp_path = b.makeTempPath();
        const unformatted_code = "    // no reason for indent";

        var dir = std.fs.cwd().openDir(tmp_path, .{}) catch @panic("unhandled");
        defer dir.close();
        dir.writeFile("fmt1.zig", unformatted_code) catch @panic("unhandled");
        dir.writeFile("fmt2.zig", unformatted_code) catch @panic("unhandled");
        dir.makeDir("subdir") catch @panic("unhandled");
        var subdir = dir.openDir("subdir", .{}) catch @panic("unhandled");
        defer subdir.close();
        subdir.writeFile("fmt3.zig", unformatted_code) catch @panic("unhandled");

        // Test zig fmt affecting only the appropriate files.
        const run1 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "fmt1.zig" });
        run1.setName("run zig fmt one file");
        run1.setCwd(.{ .cwd_relative = tmp_path });
        run1.has_side_effects = true;
        // stdout should be file path + \n
        run1.expectStdOutEqual("fmt1.zig\n");

        // Test excluding files and directories from a run
        const run2 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "--exclude", "fmt2.zig", "--exclude", "subdir", "." });
        run2.setName("run zig fmt on directory with exclusions");
        run2.setCwd(.{ .cwd_relative = tmp_path });
        run2.has_side_effects = true;
        run2.expectStdOutEqual("");
        run2.step.dependOn(&run1.step);

        // Test excluding non-existent file
        const run3 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "--exclude", "fmt2.zig", "--exclude", "nonexistent.zig", "." });
        run3.setName("run zig fmt on directory with non-existent exclusion");
        run3.setCwd(.{ .cwd_relative = tmp_path });
        run3.has_side_effects = true;
        run3.expectStdOutEqual("." ++ s ++ "subdir" ++ s ++ "fmt3.zig\n");
        run3.step.dependOn(&run2.step);

        // running it on the dir, only the new file should be changed
        const run4 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "." });
        run4.setName("run zig fmt the directory");
        run4.setCwd(.{ .cwd_relative = tmp_path });
        run4.has_side_effects = true;
        run4.expectStdOutEqual("." ++ s ++ "fmt2.zig\n");
        run4.step.dependOn(&run3.step);

        // both files have been formatted, nothing should change now
        const run5 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "." });
        run5.setName("run zig fmt with nothing to do");
        run5.setCwd(.{ .cwd_relative = tmp_path });
        run5.has_side_effects = true;
        run5.expectStdOutEqual("");
        run5.step.dependOn(&run4.step);

        const unformatted_code_utf16 = "\xff\xfe \x00 \x00 \x00 \x00/\x00/\x00 \x00n\x00o\x00 \x00r\x00e\x00a\x00s\x00o\x00n\x00";
        const fmt6_path = std.fs.path.join(b.allocator, &.{ tmp_path, "fmt6.zig" }) catch @panic("OOM");
        const write6 = b.addWriteFiles();
        write6.addBytesToSource(unformatted_code_utf16, fmt6_path);
        write6.step.dependOn(&run5.step);

        // Test `zig fmt` handling UTF-16 decoding.
        const run6 = b.addSystemCommand(&.{ b.graph.zig_exe, "fmt", "." });
        run6.setName("run zig fmt convert UTF-16 to UTF-8");
        run6.setCwd(.{ .cwd_relative = tmp_path });
        run6.has_side_effects = true;
        run6.expectStdOutEqual("." ++ s ++ "fmt6.zig\n");
        run6.step.dependOn(&write6.step);

        // TODO change this to an exact match
        const check6 = b.addCheckFile(.{ .cwd_relative = fmt6_path }, .{
            .expected_matches = &.{
                "// no reason",
            },
        });
        check6.step.dependOn(&run6.step);

        const cleanup = b.addRemoveDirTree(tmp_path);
        cleanup.step.dependOn(&check6.step);

        step.dependOn(&cleanup.step);
    }

    {
        // TODO this should move to become a CLI test rather than standalone
        //    cases.addBuildFile("test/standalone/options/build.zig", .{
        //        .extra_argv = &.{
        //            "-Dbool_true",
        //            "-Dbool_false=false",
        //            "-Dint=1234",
        //            "-De=two",
        //            "-Dstring=hello",
        //        },
        //    });
    }

    return step;
}

pub fn addAssembleAndLinkTests(b: *std.Build, test_filters: []const []const u8, optimize_modes: []const OptimizeMode) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch @panic("OOM");
    cases.* = CompareOutputContext{
        .b = b,
        .step = b.step("test-asm-link", "Run the assemble and link tests"),
        .test_index = 0,
        .test_filters = test_filters,
        .optimize_modes = optimize_modes,
    };

    assemble_and_link.addCases(cases);

    return cases.step;
}

pub fn addTranslateCTests(b: *std.Build, parent_step: *std.Build.Step, test_filters: []const []const u8) void {
    const cases = b.allocator.create(TranslateCContext) catch @panic("OOM");
    cases.* = TranslateCContext{
        .b = b,
        .step = parent_step,
        .test_index = 0,
        .test_filters = test_filters,
    };

    translate_c.addCases(cases);

    return;
}

pub fn addRunTranslatedCTests(
    b: *std.Build,
    parent_step: *std.Build.Step,
    test_filters: []const []const u8,
    target: std.Build.ResolvedTarget,
) void {
    const cases = b.allocator.create(RunTranslatedCContext) catch @panic("OOM");
    cases.* = .{
        .b = b,
        .step = parent_step,
        .test_index = 0,
        .test_filters = test_filters,
        .target = target,
    };

    run_translated_c.addCases(cases);

    return;
}

const ModuleTestOptions = struct {
    test_filters: []const []const u8,
    root_src: []const u8,
    name: []const u8,
    desc: []const u8,
    optimize_modes: []const OptimizeMode,
    include_paths: []const []const u8,
    skip_single_threaded: bool,
    skip_non_native: bool,
    skip_libc: bool,
    max_rss: usize = 0,
};

pub fn addModuleTests(b: *std.Build, options: ModuleTestOptions) *Step {
    const step = b.step(b.fmt("test-{s}", .{options.name}), options.desc);

    for (test_targets) |test_target| {
        const is_native = test_target.target.isNative() or
            (test_target.target.os_tag == builtin.os.tag and
            test_target.target.cpu_arch == builtin.cpu.arch);

        if (options.skip_non_native and !is_native)
            continue;

        const resolved_target = b.resolveTargetQuery(test_target.target);
        const target = resolved_target.result;

        if (options.skip_libc and test_target.link_libc == true)
            continue;

        if (options.skip_single_threaded and test_target.single_threaded == true)
            continue;

        // TODO get compiler-rt tests passing for self-hosted backends.
        if ((target.cpu.arch != .x86_64 or target.ofmt != .elf) and
            test_target.use_llvm == false and mem.eql(u8, options.name, "compiler-rt"))
            continue;

        // TODO get compiler-rt tests passing for wasm32-wasi
        // currently causes "LLVM ERROR: Unable to expand fixed point multiplication."
        if (target.cpu.arch == .wasm32 and target.os.tag == .wasi and
            mem.eql(u8, options.name, "compiler-rt"))
        {
            continue;
        }

        // TODO get universal-libc tests passing for other self-hosted backends.
        if (target.cpu.arch != .x86_64 and
            test_target.use_llvm == false and mem.eql(u8, options.name, "universal-libc"))
            continue;

        // TODO get std lib tests passing for other self-hosted backends.
        if ((target.cpu.arch != .x86_64 or target.os.tag != .linux) and
            test_target.use_llvm == false and mem.eql(u8, options.name, "std"))
            continue;

        if (target.cpu.arch == .x86_64 and target.os.tag == .windows and
            test_target.target.cpu_arch == null and test_target.optimize_mode != .Debug and
            mem.eql(u8, options.name, "std"))
        {
            // https://github.com/ziglang/zig/issues/17902
            continue;
        }

        const want_this_mode = for (options.optimize_modes) |m| {
            if (m == test_target.optimize_mode) break true;
        } else false;
        if (!want_this_mode) continue;

        const libc_suffix = if (test_target.link_libc == true) "-libc" else "";
        const triple_txt = target.zigTriple(b.allocator) catch @panic("OOM");
        const model_txt = target.cpu.model.name;

        // wasm32-wasi builds need more RAM, idk why
        const max_rss = if (target.os.tag == .wasi)
            options.max_rss * 2
        else
            options.max_rss;

        const these_tests = b.addTest(.{
            .root_source_file = b.path(options.root_src),
            .optimize = test_target.optimize_mode,
            .target = resolved_target,
            .max_rss = max_rss,
            .filters = options.test_filters,
            .link_libc = test_target.link_libc,
            .single_threaded = test_target.single_threaded,
            .use_llvm = test_target.use_llvm,
            .use_lld = test_target.use_lld,
            .zig_lib_dir = b.path("lib"),
            .pic = test_target.pic,
            .strip = test_target.strip,
        });
        const single_threaded_suffix = if (test_target.single_threaded == true) "-single" else "";
        const backend_suffix = if (test_target.use_llvm == true)
            "-llvm"
        else if (target.ofmt == std.Target.ObjectFormat.c)
            "-cbe"
        else if (test_target.use_llvm == false)
            "-selfhosted"
        else
            "";
        const use_lld = if (test_target.use_lld == false) "-no-lld" else "";
        const use_pic = if (test_target.pic == true) "-pic" else "";

        for (options.include_paths) |include_path| these_tests.addIncludePath(b.path(include_path));

        const qualified_name = b.fmt("{s}-{s}-{s}-{s}{s}{s}{s}{s}{s}", .{
            options.name,
            triple_txt,
            model_txt,
            @tagName(test_target.optimize_mode),
            libc_suffix,
            single_threaded_suffix,
            backend_suffix,
            use_lld,
            use_pic,
        });

        if (target.ofmt == std.Target.ObjectFormat.c) {
            var altered_query = test_target.target;
            altered_query.ofmt = null;

            const compile_c = b.addExecutable(.{
                .name = qualified_name,
                .link_libc = test_target.link_libc,
                .target = b.resolveTargetQuery(altered_query),
                .zig_lib_dir = b.path("lib"),
            });
            compile_c.addCSourceFile(.{
                .file = these_tests.getEmittedBin(),
                .flags = &.{
                    // Tracking issue for making the C backend generate C89 compatible code:
                    // https://github.com/ziglang/zig/issues/19468
                    "-std=c99",
                    "-Werror",

                    "-Wall",
                    "-Wembedded-directive",
                    "-Wempty-translation-unit",
                    "-Wextra",
                    "-Wgnu",
                    "-Winvalid-utf8",
                    "-Wkeyword-macro",
                    "-Woverlength-strings",

                    // Tracking issue for making the C backend generate code
                    // that does not trigger warnings:
                    // https://github.com/ziglang/zig/issues/19467

                    // spotted everywhere
                    "-Wno-builtin-requires-header",

                    // spotted on linux
                    "-Wno-braced-scalar-init",
                    "-Wno-excess-initializers",
                    "-Wno-incompatible-pointer-types-discards-qualifiers",
                    "-Wno-unused",
                    "-Wno-unused-parameter",

                    // spotted on darwin
                    "-Wno-incompatible-pointer-types",
                },
            });
            compile_c.addIncludePath(b.path("lib")); // for zig.h
            if (target.os.tag == .windows) {
                if (true) {
                    // Unfortunately this requires about 8G of RAM for clang to compile
                    // and our Windows CI runners do not have this much.
                    step.dependOn(&these_tests.step);
                    continue;
                }
                if (test_target.link_libc == false) {
                    compile_c.subsystem = .Console;
                    compile_c.linkSystemLibrary("kernel32");
                    compile_c.linkSystemLibrary("ntdll");
                }
                if (mem.eql(u8, options.name, "std")) {
                    if (test_target.link_libc == false) {
                        compile_c.linkSystemLibrary("shell32");
                        compile_c.linkSystemLibrary("advapi32");
                    }
                    compile_c.linkSystemLibrary("crypt32");
                    compile_c.linkSystemLibrary("ws2_32");
                    compile_c.linkSystemLibrary("ole32");
                }
            }

            const run = b.addRunArtifact(compile_c);
            run.skip_foreign_checks = true;
            run.enableTestRunnerMode();
            run.setName(b.fmt("run test {s}", .{qualified_name}));

            step.dependOn(&run.step);
        } else {
            const run = b.addRunArtifact(these_tests);
            run.skip_foreign_checks = true;
            run.setName(b.fmt("run test {s}", .{qualified_name}));

            step.dependOn(&run.step);
        }
    }
    return step;
}

pub fn addCAbiTests(b: *std.Build, skip_non_native: bool, skip_release: bool) *Step {
    const step = b.step("test-c-abi", "Run the C ABI tests");

    const optimize_modes: [3]OptimizeMode = .{ .Debug, .ReleaseSafe, .ReleaseFast };

    for (optimize_modes) |optimize_mode| {
        if (optimize_mode != .Debug and skip_release) continue;

        for (c_abi_targets) |c_abi_target| {
            if (skip_non_native and !c_abi_target.target.isNative()) continue;

            const resolved_target = b.resolveTargetQuery(c_abi_target.target);
            const target = resolved_target.result;

            if (target.os.tag == .windows and target.cpu.arch == .aarch64) {
                // https://github.com/ziglang/zig/issues/14908
                continue;
            }

            const test_step = b.addTest(.{
                .name = b.fmt("test-c-abi-{s}-{s}-{s}{s}{s}{s}", .{
                    target.zigTriple(b.allocator) catch @panic("OOM"),
                    target.cpu.model.name,
                    @tagName(optimize_mode),
                    if (c_abi_target.use_llvm == true)
                        "-llvm"
                    else if (target.ofmt == .c)
                        "-cbe"
                    else if (c_abi_target.use_llvm == false)
                        "-selfhosted"
                    else
                        "",
                    if (c_abi_target.use_lld == false) "-no-lld" else "",
                    if (c_abi_target.pic == true) "-pic" else "",
                }),
                .root_source_file = b.path("test/c_abi/main.zig"),
                .target = resolved_target,
                .optimize = optimize_mode,
                .link_libc = true,
                .use_llvm = c_abi_target.use_llvm,
                .use_lld = c_abi_target.use_lld,
                .pic = c_abi_target.pic,
                .strip = c_abi_target.strip,
            });
            test_step.addCSourceFile(.{
                .file = b.path("test/c_abi/cfuncs.c"),
                .flags = &.{"-std=c99"},
            });
            for (c_abi_target.c_defines) |define| test_step.defineCMacro(define, null);

            // This test is intentionally trying to check if the external ABI is
            // done properly. LTO would be a hindrance to this.
            test_step.want_lto = false;

            const run = b.addRunArtifact(test_step);
            run.skip_foreign_checks = true;
            step.dependOn(&run.step);
        }
    }
    return step;
}

pub fn addCases(
    b: *std.Build,
    parent_step: *Step,
    test_filters: []const []const u8,
    check_case_exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    translate_c_options: @import("src/Cases.zig").TranslateCOptions,
    build_options: @import("cases.zig").BuildOptions,
) !void {
    const arena = b.allocator;
    const gpa = b.allocator;

    var cases = @import("src/Cases.zig").init(gpa, arena);

    var dir = try b.build_root.handle.openDir("test/cases", .{ .iterate = true });
    defer dir.close();

    cases.addFromDir(dir, b);
    try @import("cases.zig").addCases(&cases, build_options, b);

    cases.lowerToTranslateCSteps(b, parent_step, test_filters, target, translate_c_options);

    const cases_dir_path = try b.build_root.join(b.allocator, &.{ "test", "cases" });
    cases.lowerToBuildSteps(
        b,
        parent_step,
        test_filters,
        cases_dir_path,
        check_case_exe,
    );
}
