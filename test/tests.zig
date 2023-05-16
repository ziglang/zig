const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const CrossTarget = std.zig.CrossTarget;
const mem = std.mem;
const OptimizeMode = std.builtin.OptimizeMode;
const Step = std.Build.Step;

// Cases
const compare_output = @import("compare_output.zig");
const standalone = @import("standalone.zig");
const stack_traces = @import("stack_traces.zig");
const assemble_and_link = @import("assemble_and_link.zig");
const translate_c = @import("translate_c.zig");
const run_translated_c = @import("run_translated_c.zig");
const link = @import("link.zig");

// Implementations
pub const TranslateCContext = @import("src/translate_c.zig").TranslateCContext;
pub const RunTranslatedCContext = @import("src/run_translated_c.zig").RunTranslatedCContext;
pub const CompareOutputContext = @import("src/CompareOutput.zig");
pub const StackTracesContext = @import("src/StackTrace.zig");

const TestTarget = struct {
    target: CrossTarget = .{},
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
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
        //    .target = CrossTarget.parse(.{
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
            .target = CrossTarget.parse(.{
                .arch_os_abi = "arm-linux-none",
                .cpu_features = "generic+v8a",
            }) catch unreachable,
        },
        .{
            .target = CrossTarget.parse(.{
                .arch_os_abi = "arm-linux-musleabihf",
                .cpu_features = "generic+v8a",
            }) catch unreachable,
            .link_libc = true,
        },
        // https://github.com/ziglang/zig/issues/3287
        //.{
        //    .target = CrossTarget.parse(.{
        //        .arch_os_abi = "arm-linux-gnueabihf",
        //        .cpu_features = "generic+v8a",
        //    }) catch unreachable,
        //    .link_libc = true,
        //},

        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .none,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },

        // https://github.com/ziglang/zig/issues/4927
        //.{
        //    .target = .{
        //        .cpu_arch = .mips,
        //        .os_tag = .linux,
        //        .abi = .gnueabihf,
        //    },
        //    .link_libc = true,
        //},

        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .none,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },

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

        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .none,
            },
        },

        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },

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

const c_abi_targets = [_]CrossTarget{
    .{},
    .{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .x86,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .arm,
        .os_tag = .linux,
        .abi = .musleabihf,
    },
    .{
        .cpu_arch = .mips,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .riscv64,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
        .abi = .musl,
    },
    .{
        .cpu_arch = .powerpc,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .powerpc64le,
        .os_tag = .linux,
        .abi = .musl,
    },
    .{
        .cpu_arch = .x86,
        .os_tag = .windows,
        .abi = .gnu,
    },
    .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    },
};

pub fn addCompareOutputTests(
    b: *std.Build,
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,
) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch @panic("OOM");
    cases.* = CompareOutputContext{
        .b = b,
        .step = b.step("test-compare-output", "Run the compare output tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
    };

    compare_output.addCases(cases);

    return cases.step;
}

pub fn addStackTraceTests(
    b: *std.Build,
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,
) *Step {
    const check_exe = b.addExecutable(.{
        .name = "check-stack-trace",
        .root_source_file = .{ .path = "test/src/check-stack-trace.zig" },
        .target = .{},
        .optimize = .Debug,
    });

    const cases = b.allocator.create(StackTracesContext) catch @panic("OOM");
    cases.* = .{
        .b = b,
        .step = b.step("test-stack-traces", "Run the stack trace tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
        .check_exe = check_exe,
    };

    stack_traces.addCases(cases);

    return cases.step;
}

pub fn addStandaloneTests(
    b: *std.Build,
    optimize_modes: []const OptimizeMode,
    enable_macos_sdk: bool,
    omit_stage2: bool,
    enable_symlinks_windows: bool,
) *Step {
    const step = b.step("test-standalone", "Run the standalone tests");
    const omit_symlinks = builtin.os.tag == .windows and !enable_symlinks_windows;

    for (standalone.simple_cases) |case| {
        for (optimize_modes) |optimize| {
            if (!case.all_modes and optimize != .Debug) continue;
            if (case.os_filter) |os_tag| {
                if (os_tag != builtin.os.tag) continue;
            }

            if (case.is_exe) {
                const exe = b.addExecutable(.{
                    .name = std.fs.path.stem(case.src_path),
                    .root_source_file = .{ .path = case.src_path },
                    .optimize = optimize,
                    .target = case.target,
                });
                if (case.link_libc) exe.linkLibC();

                step.dependOn(&exe.step);
            }

            if (case.is_test) {
                const exe = b.addTest(.{
                    .name = std.fs.path.stem(case.src_path),
                    .root_source_file = .{ .path = case.src_path },
                    .optimize = optimize,
                    .target = case.target,
                });
                if (case.link_libc) exe.linkLibC();

                const run = b.addRunArtifact(exe);
                step.dependOn(&run.step);
            }
        }
    }

    inline for (standalone.build_cases) |case| {
        const requires_stage2 = @hasDecl(case.import, "requires_stage2") and
            case.import.requires_stage2;
        const requires_symlinks = @hasDecl(case.import, "requires_symlinks") and
            case.import.requires_symlinks;
        const requires_macos_sdk = @hasDecl(case.import, "requires_macos_sdk") and
            case.import.requires_macos_sdk;
        const bad =
            (requires_stage2 and omit_stage2) or
            (requires_symlinks and omit_symlinks) or
            (requires_macos_sdk and !enable_macos_sdk);
        if (!bad) {
            const dep = b.anonymousDependency(case.build_root, case.import, .{});
            const dep_step = dep.builder.default_step;
            assert(mem.startsWith(u8, dep.builder.dep_prefix, "test."));
            const dep_prefix_adjusted = dep.builder.dep_prefix["test.".len..];
            dep_step.name = b.fmt("{s}{s}", .{ dep_prefix_adjusted, dep_step.name });
            step.dependOn(dep_step);
        }
    }

    return step;
}

pub fn addLinkTests(
    b: *std.Build,
    enable_macos_sdk: bool,
    omit_stage2: bool,
    enable_symlinks_windows: bool,
) *Step {
    const step = b.step("test-link", "Run the linker tests");
    const omit_symlinks = builtin.os.tag == .windows and !enable_symlinks_windows;

    inline for (link.cases) |case| {
        const requires_stage2 = @hasDecl(case.import, "requires_stage2") and
            case.import.requires_stage2;
        const requires_symlinks = @hasDecl(case.import, "requires_symlinks") and
            case.import.requires_symlinks;
        const requires_macos_sdk = @hasDecl(case.import, "requires_macos_sdk") and
            case.import.requires_macos_sdk;
        const bad =
            (requires_stage2 and omit_stage2) or
            (requires_symlinks and omit_symlinks) or
            (requires_macos_sdk and !enable_macos_sdk);
        if (!bad) {
            const dep = b.anonymousDependency(case.build_root, case.import, .{});
            const dep_step = dep.builder.default_step;
            assert(mem.startsWith(u8, dep.builder.dep_prefix, "test."));
            const dep_prefix_adjusted = dep.builder.dep_prefix["test.".len..];
            dep_step.name = b.fmt("{s}{s}", .{ dep_prefix_adjusted, dep_step.name });
            step.dependOn(dep_step);
        }
    }

    return step;
}

pub fn addCliTests(b: *std.Build) *Step {
    const step = b.step("test-cli", "Test the command line interface");
    const s = std.fs.path.sep_str;

    {

        // Test `zig init-lib`.
        const tmp_path = b.makeTempPath();
        const init_lib = b.addSystemCommand(&.{ b.zig_exe, "init-lib" });
        init_lib.cwd = tmp_path;
        init_lib.setName("zig init-lib");
        init_lib.expectStdOutEqual("");
        init_lib.expectStdErrEqual("info: Created build.zig\n" ++
            "info: Created src" ++ s ++ "main.zig\n" ++
            "info: Next, try `zig build --help` or `zig build test`\n");

        const run_test = b.addSystemCommand(&.{ b.zig_exe, "build", "test" });
        run_test.cwd = tmp_path;
        run_test.setName("zig build test");
        run_test.expectStdOutEqual("");
        run_test.step.dependOn(&init_lib.step);

        const cleanup = b.addRemoveDirTree(tmp_path);
        cleanup.step.dependOn(&run_test.step);

        step.dependOn(&cleanup.step);
    }

    {
        // Test `zig init-exe`.
        const tmp_path = b.makeTempPath();
        const init_exe = b.addSystemCommand(&.{ b.zig_exe, "init-exe" });
        init_exe.cwd = tmp_path;
        init_exe.setName("zig init-exe");
        init_exe.expectStdOutEqual("");
        init_exe.expectStdErrEqual("info: Created build.zig\n" ++
            "info: Created src" ++ s ++ "main.zig\n" ++
            "info: Next, try `zig build --help` or `zig build run`\n");

        // Test missing output path.
        const bad_out_arg = "-femit-bin=does" ++ s ++ "not" ++ s ++ "exist" ++ s ++ "foo.exe";
        const ok_src_arg = "src" ++ s ++ "main.zig";
        const expected = "error: unable to open output directory 'does" ++ s ++ "not" ++ s ++ "exist': FileNotFound\n";
        const run_bad = b.addSystemCommand(&.{ b.zig_exe, "build-exe", ok_src_arg, bad_out_arg });
        run_bad.setName("zig build-exe error message for bad -femit-bin arg");
        run_bad.expectExitCode(1);
        run_bad.expectStdErrEqual(expected);
        run_bad.expectStdOutEqual("");
        run_bad.step.dependOn(&init_exe.step);

        const run_test = b.addSystemCommand(&.{ b.zig_exe, "build", "test" });
        run_test.cwd = tmp_path;
        run_test.setName("zig build test");
        run_test.expectStdOutEqual("");
        run_test.step.dependOn(&init_exe.step);

        const run_run = b.addSystemCommand(&.{ b.zig_exe, "build", "run" });
        run_run.cwd = tmp_path;
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
            b.zig_exe,       "build-obj",
            "--cache-dir",   tmp_path,
            "--name",        "example",
            "-fno-emit-bin", "-fno-emit-h",
            "-fstrip",       "-OReleaseFast",
        });
        run.addFileSourceArg(writefile.getFileSource("example.zig").?);
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

        // Test zig fmt affecting only the appropriate files.
        const run1 = b.addSystemCommand(&.{ b.zig_exe, "fmt", "fmt1.zig" });
        run1.setName("run zig fmt one file");
        run1.cwd = tmp_path;
        run1.has_side_effects = true;
        // stdout should be file path + \n
        run1.expectStdOutEqual("fmt1.zig\n");

        // running it on the dir, only the new file should be changed
        const run2 = b.addSystemCommand(&.{ b.zig_exe, "fmt", "." });
        run2.setName("run zig fmt the directory");
        run2.cwd = tmp_path;
        run2.has_side_effects = true;
        run2.expectStdOutEqual("." ++ s ++ "fmt2.zig\n");
        run2.step.dependOn(&run1.step);

        // both files have been formatted, nothing should change now
        const run3 = b.addSystemCommand(&.{ b.zig_exe, "fmt", "." });
        run3.setName("run zig fmt with nothing to do");
        run3.cwd = tmp_path;
        run3.has_side_effects = true;
        run3.expectStdOutEqual("");
        run3.step.dependOn(&run2.step);

        const unformatted_code_utf16 = "\xff\xfe \x00 \x00 \x00 \x00/\x00/\x00 \x00n\x00o\x00 \x00r\x00e\x00a\x00s\x00o\x00n\x00";
        const fmt4_path = std.fs.path.join(b.allocator, &.{ tmp_path, "fmt4.zig" }) catch @panic("OOM");
        const write4 = b.addWriteFiles();
        write4.addBytesToSource(unformatted_code_utf16, fmt4_path);
        write4.step.dependOn(&run3.step);

        // Test `zig fmt` handling UTF-16 decoding.
        const run4 = b.addSystemCommand(&.{ b.zig_exe, "fmt", "." });
        run4.setName("run zig fmt convert UTF-16 to UTF-8");
        run4.cwd = tmp_path;
        run4.has_side_effects = true;
        run4.expectStdOutEqual("." ++ s ++ "fmt4.zig\n");
        run4.step.dependOn(&write4.step);

        // TODO change this to an exact match
        const check4 = b.addCheckFile(.{ .path = fmt4_path }, .{
            .expected_matches = &.{
                "// no reason",
            },
        });
        check4.step.dependOn(&run4.step);

        const cleanup = b.addRemoveDirTree(tmp_path);
        cleanup.step.dependOn(&check4.step);

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

pub fn addAssembleAndLinkTests(b: *std.Build, test_filter: ?[]const u8, optimize_modes: []const OptimizeMode) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch @panic("OOM");
    cases.* = CompareOutputContext{
        .b = b,
        .step = b.step("test-asm-link", "Run the assemble and link tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
    };

    assemble_and_link.addCases(cases);

    return cases.step;
}

pub fn addTranslateCTests(b: *std.Build, test_filter: ?[]const u8) *Step {
    const cases = b.allocator.create(TranslateCContext) catch @panic("OOM");
    cases.* = TranslateCContext{
        .b = b,
        .step = b.step("test-translate-c", "Run the C translation tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    translate_c.addCases(cases);

    return cases.step;
}

pub fn addRunTranslatedCTests(
    b: *std.Build,
    test_filter: ?[]const u8,
    target: std.zig.CrossTarget,
) *Step {
    const cases = b.allocator.create(RunTranslatedCContext) catch @panic("OOM");
    cases.* = .{
        .b = b,
        .step = b.step("test-run-translated-c", "Run the Run-Translated-C tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .target = target,
    };

    run_translated_c.addCases(cases);

    return cases.step;
}

const ModuleTestOptions = struct {
    test_filter: ?[]const u8,
    root_src: []const u8,
    name: []const u8,
    desc: []const u8,
    optimize_modes: []const OptimizeMode,
    skip_single_threaded: bool,
    skip_non_native: bool,
    skip_cross_glibc: bool,
    skip_libc: bool,
    max_rss: usize = 0,
};

pub fn addModuleTests(b: *std.Build, options: ModuleTestOptions) *Step {
    const step = b.step(b.fmt("test-{s}", .{options.name}), options.desc);

    for (test_targets) |test_target| {
        const is_native = test_target.target.isNative() or
            (test_target.target.getOsTag() == builtin.os.tag and
            test_target.target.getCpuArch() == builtin.cpu.arch);

        if (options.skip_non_native and !is_native)
            continue;

        if (options.skip_cross_glibc and !test_target.target.isNative() and
            test_target.target.isGnuLibC() and test_target.link_libc == true)
            continue;

        if (options.skip_libc and test_target.link_libc == true)
            continue;

        if (options.skip_single_threaded and test_target.single_threaded == true)
            continue;

        // TODO get compiler-rt tests passing for self-hosted backends.
        if (test_target.use_llvm == false and mem.eql(u8, options.name, "compiler-rt"))
            continue;

        // TODO get compiler-rt tests passing for wasm32-wasi
        // currently causes "LLVM ERROR: Unable to expand fixed point multiplication."
        if (test_target.target.getCpuArch() == .wasm32 and
            test_target.target.getOsTag() == .wasi and
            mem.eql(u8, options.name, "compiler-rt"))
        {
            continue;
        }

        // TODO get universal-libc tests passing for self-hosted backends.
        if (test_target.use_llvm == false and mem.eql(u8, options.name, "universal-libc"))
            continue;

        // TODO get std lib tests passing for self-hosted backends.
        if (test_target.use_llvm == false and mem.eql(u8, options.name, "std"))
            continue;

        const want_this_mode = for (options.optimize_modes) |m| {
            if (m == test_target.optimize_mode) break true;
        } else false;
        if (!want_this_mode) continue;

        const libc_suffix = if (test_target.link_libc == true) "-libc" else "";
        const triple_txt = test_target.target.zigTriple(b.allocator) catch @panic("OOM");

        // wasm32-wasi builds need more RAM, idk why
        const max_rss = if (test_target.target.getOs().tag == .wasi)
            options.max_rss * 2
        else
            options.max_rss;

        const these_tests = b.addTest(.{
            .root_source_file = .{ .path = options.root_src },
            .optimize = test_target.optimize_mode,
            .target = test_target.target,
            .max_rss = max_rss,
            .filter = options.test_filter,
            .link_libc = test_target.link_libc,
            .single_threaded = test_target.single_threaded,
            .use_llvm = test_target.use_llvm,
            .use_lld = test_target.use_lld,
        });
        const single_threaded_suffix = if (test_target.single_threaded == true) "-single" else "";
        const backend_suffix = if (test_target.use_llvm == true)
            "-llvm"
        else if (test_target.target.ofmt == std.Target.ObjectFormat.c)
            "-cbe"
        else if (test_target.use_llvm == false)
            "-selfhosted"
        else
            "";

        these_tests.overrideZigLibDir("lib");
        these_tests.addIncludePath("test");

        const qualified_name = b.fmt("{s}-{s}-{s}{s}{s}{s}", .{
            options.name,
            triple_txt,
            @tagName(test_target.optimize_mode),
            libc_suffix,
            single_threaded_suffix,
            backend_suffix,
        });

        if (test_target.target.ofmt == std.Target.ObjectFormat.c) {
            var altered_target = test_target.target;
            altered_target.ofmt = null;

            const compile_c = b.addExecutable(.{
                .name = qualified_name,
                .link_libc = test_target.link_libc,
                .target = altered_target,
            });
            compile_c.overrideZigLibDir("lib");
            compile_c.addCSourceFileSource(.{
                .source = these_tests.getOutputSource(),
                .args = &.{
                    // TODO output -std=c89 compatible C code
                    "-std=c99",
                    "-pedantic",
                    "-Werror",
                    // TODO stop violating these pedantic errors. spotted everywhere
                    "-Wno-builtin-requires-header",
                    // TODO stop violating these pedantic errors. spotted on linux
                    "-Wno-address-of-packed-member",
                    "-Wno-gnu-folding-constant",
                    "-Wno-incompatible-pointer-types",
                    "-Wno-overlength-strings",
                    // TODO stop violating these pedantic errors. spotted on darwin
                    "-Wno-dollar-in-identifier-extension",
                    "-Wno-absolute-value",
                },
            });
            compile_c.addIncludePath("lib"); // for zig.h
            if (test_target.target.getOsTag() == .windows) {
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

    const optimize_modes: [2]OptimizeMode = .{ .Debug, .ReleaseFast };

    for (optimize_modes) |optimize_mode| {
        if (optimize_mode != .Debug and skip_release) continue;

        for (c_abi_targets) |c_abi_target| {
            if (skip_non_native and !c_abi_target.isNative()) continue;

            if (c_abi_target.isWindows() and c_abi_target.getCpuArch() == .aarch64) {
                // https://github.com/ziglang/zig/issues/14908
                continue;
            }

            const triple_prefix = c_abi_target.zigTriple(b.allocator) catch @panic("OOM");

            const test_step = b.addTest(.{
                .root_source_file = .{ .path = "test/c_abi/main.zig" },
                .optimize = optimize_mode,
                .target = c_abi_target,
                .name = b.fmt("test-c-abi-{s}-{s}", .{
                    triple_prefix, @tagName(optimize_mode),
                }),
            });
            if (c_abi_target.abi != null and c_abi_target.abi.?.isMusl()) {
                // TODO NativeTargetInfo insists on dynamically linking musl
                // for some reason?
                test_step.target_info.dynamic_linker.max_byte = null;
            }
            test_step.linkLibC();
            test_step.addCSourceFile("test/c_abi/cfuncs.c", &.{"-std=c99"});

            // test-c-abi should test both with LTO on and with LTO off. Only
            // some combinations are passing currently:
            // https://github.com/ziglang/zig/issues/14908
            if (c_abi_target.isWindows()) {
                test_step.want_lto = false;
            }

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
    opt_test_filter: ?[]const u8,
    check_case_exe: *std.Build.Step.Compile,
) !void {
    const arena = b.allocator;
    const gpa = b.allocator;

    var cases = @import("src/Cases.zig").init(gpa, arena);

    var dir = try b.build_root.handle.openIterableDir("test/cases", .{});
    defer dir.close();

    cases.addFromDir(dir);
    try @import("cases.zig").addCases(&cases);

    const cases_dir_path = try b.build_root.join(b.allocator, &.{ "test", "cases" });
    cases.lowerToBuildSteps(
        b,
        parent_step,
        opt_test_filter,
        cases_dir_path,
        check_case_exe,
    );
}
