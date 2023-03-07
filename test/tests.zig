const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const CrossTarget = std.zig.CrossTarget;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const OptimizeMode = std.builtin.OptimizeMode;
const CompileStep = std.Build.CompileStep;
const Allocator = mem.Allocator;
const ExecError = std.Build.ExecError;
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
pub const CompareOutputContext = @import("src/compare_output.zig").CompareOutputContext;
pub const StackTracesContext = @import("src/StackTrace.zig");
pub const StandaloneContext = @import("src/Standalone.zig");

const TestTarget = struct {
    target: CrossTarget = @as(CrossTarget, .{}),
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    link_libc: bool = false,
    single_threaded: bool = false,
    disable_native: bool = false,
    backend: ?std.builtin.CompilerBackend = null,
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
            .target = .{
                .ofmt = .c,
            },
            .link_libc = true,
            .backend = .stage2_c,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .none,
            },
            .backend = .stage2_x86_64,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
            },
            .backend = .stage2_aarch64,
        },
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .single_threaded = true,
            .backend = .stage2_wasm,
        },
        // https://github.com/ziglang/zig/issues/13623
        //.{
        //    .target = .{
        //        .cpu_arch = .arm,
        //        .os_tag = .linux,
        //    },
        //    .backend = .stage2_arm,
        //},
        // https://github.com/ziglang/zig/issues/13623
        //.{
        //    .target = CrossTarget.parse(.{
        //        .arch_os_abi = "arm-linux-none",
        //        .cpu_features = "generic+v8a",
        //    }) catch unreachable,
        //    .backend = .stage2_arm,
        //},
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .macos,
                .abi = .none,
            },
            .backend = .stage2_aarch64,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .macos,
                .abi = .none,
            },
            .backend = .stage2_x86_64,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .gnu,
            },
            .backend = .stage2_x86_64,
        },

        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .link_libc = false,
            .single_threaded = true,
        },
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
            },
            .link_libc = true,
            .single_threaded = true,
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

        // Do the release tests last because they take a long time
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
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,
    skip_non_native: bool,
    enable_macos_sdk: bool,
    target: std.zig.CrossTarget,
    omit_stage2: bool,
    enable_darling: bool,
    enable_qemu: bool,
    enable_rosetta: bool,
    enable_wasmtime: bool,
    enable_wine: bool,
    enable_symlinks_windows: bool,
) *Step {
    const cases = b.allocator.create(StandaloneContext) catch @panic("OOM");
    cases.* = StandaloneContext{
        .b = b,
        .step = b.step("test-standalone", "Run the standalone tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
        .skip_non_native = skip_non_native,
        .enable_macos_sdk = enable_macos_sdk,
        .target = target,
        .omit_stage2 = omit_stage2,
        .enable_darling = enable_darling,
        .enable_qemu = enable_qemu,
        .enable_rosetta = enable_rosetta,
        .enable_wasmtime = enable_wasmtime,
        .enable_wine = enable_wine,
        .enable_symlinks_windows = enable_symlinks_windows,
    };

    standalone.addCases(cases);

    return cases.step;
}

pub fn addLinkTests(
    b: *std.Build,
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,
    enable_macos_sdk: bool,
    omit_stage2: bool,
    enable_symlinks_windows: bool,
) *Step {
    const cases = b.allocator.create(StandaloneContext) catch @panic("OOM");
    cases.* = StandaloneContext{
        .b = b,
        .step = b.step("test-link", "Run the linker tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
        .skip_non_native = true,
        .enable_macos_sdk = enable_macos_sdk,
        .target = .{},
        .omit_stage2 = omit_stage2,
        .enable_symlinks_windows = enable_symlinks_windows,
    };
    link.addCases(cases);
    return cases.step;
}

pub fn addCliTests(b: *std.Build, test_filter: ?[]const u8, optimize_modes: []const OptimizeMode) *Step {
    _ = test_filter;
    _ = optimize_modes;
    const step = b.step("test-cli", "Test the command line interface");

    const exe = b.addExecutable(.{
        .name = "test-cli",
        .root_source_file = .{ .path = "test/cli.zig" },
        .target = .{},
        .optimize = .Debug,
    });
    const run_cmd = exe.run();
    run_cmd.addArgs(&[_][]const u8{
        fs.realpathAlloc(b.allocator, b.zig_exe) catch @panic("OOM"),
        b.pathFromRoot(b.cache_root.path orelse "."),
    });

    step.dependOn(&run_cmd.step);
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
    skip_libc: bool,
    skip_stage1: bool,
    skip_stage2: bool,
    max_rss: usize = 0,
};

pub fn addModuleTests(b: *std.Build, options: ModuleTestOptions) *Step {
    const step = b.step(b.fmt("test-{s}", .{options.name}), options.desc);

    for (test_targets) |test_target| {
        if (options.skip_non_native and !test_target.target.isNative())
            continue;

        if (options.skip_libc and test_target.link_libc)
            continue;

        if (test_target.link_libc and test_target.target.getOs().requiresLibC()) {
            // This would be a redundant test.
            continue;
        }

        if (options.skip_single_threaded and test_target.single_threaded)
            continue;

        if (test_target.disable_native and
            test_target.target.getOsTag() == builtin.os.tag and
            test_target.target.getCpuArch() == builtin.cpu.arch)
        {
            continue;
        }

        if (test_target.backend) |backend| switch (backend) {
            .stage1 => if (options.skip_stage1) continue,
            .stage2_llvm => {},
            else => if (options.skip_stage2) continue,
        };

        const want_this_mode = for (options.optimize_modes) |m| {
            if (m == test_target.optimize_mode) break true;
        } else false;
        if (!want_this_mode) continue;

        const libc_prefix = if (test_target.target.getOs().requiresLibC())
            ""
        else if (test_target.link_libc)
            "c"
        else
            "bare";

        const triple_prefix = test_target.target.zigTriple(b.allocator) catch @panic("OOM");

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
        });
        const single_threaded_txt = if (test_target.single_threaded) "single" else "multi";
        const backend_txt = if (test_target.backend) |backend| @tagName(backend) else "default";
        these_tests.setNamePrefix(b.fmt("{s}-{s}-{s}-{s}-{s}-{s} ", .{
            options.name,
            triple_prefix,
            @tagName(test_target.optimize_mode),
            libc_prefix,
            single_threaded_txt,
            backend_txt,
        }));
        these_tests.single_threaded = test_target.single_threaded;
        these_tests.setFilter(options.test_filter);
        if (test_target.link_libc) {
            these_tests.linkSystemLibrary("c");
        }
        these_tests.overrideZigLibDir("lib");
        these_tests.addIncludePath("test");
        if (test_target.backend) |backend| switch (backend) {
            .stage1 => {
                @panic("stage1 testing requested");
            },
            .stage2_llvm => {
                these_tests.use_llvm = true;
            },
            .stage2_c => {
                these_tests.use_llvm = false;
            },
            else => {
                these_tests.use_llvm = false;
                // TODO: force self-hosted linkers to avoid LLD creeping in
                // until the auto-select mechanism deems them worthy
                these_tests.use_lld = false;
            },
        };

        step.dependOn(&these_tests.step);
    }
    return step;
}

pub fn addCAbiTests(b: *std.Build, skip_non_native: bool, skip_release: bool) *Step {
    const step = b.step("test-c-abi", "Run the C ABI tests");

    const optimize_modes: [2]OptimizeMode = .{ .Debug, .ReleaseFast };

    for (optimize_modes[0 .. @as(u8, 1) + @boolToInt(!skip_release)]) |optimize_mode| for (c_abi_targets) |c_abi_target| {
        if (skip_non_native and !c_abi_target.isNative())
            continue;

        const test_step = b.addTest(.{
            .root_source_file = .{ .path = "test/c_abi/main.zig" },
            .optimize = optimize_mode,
            .target = c_abi_target,
        });
        if (c_abi_target.abi != null and c_abi_target.abi.?.isMusl()) {
            // TODO NativeTargetInfo insists on dynamically linking musl
            // for some reason?
            test_step.target_info.dynamic_linker.max_byte = null;
        }
        test_step.linkLibC();
        test_step.addCSourceFile("test/c_abi/cfuncs.c", &.{"-std=c99"});

        if (c_abi_target.isWindows() and (c_abi_target.getCpuArch() == .x86 or builtin.target.os.tag == .linux)) {
            // LTO currently incorrectly strips stdcall name-mangled functions
            // LLD crashes in LTO here when cross compiling for windows on linux
            test_step.want_lto = false;
        }

        const triple_prefix = c_abi_target.zigTriple(b.allocator) catch @panic("OOM");
        test_step.setNamePrefix(b.fmt("{s}-{s}-{s} ", .{
            "test-c-abi",
            triple_prefix,
            @tagName(optimize_mode),
        }));

        step.dependOn(&test_step.step);
    };
    return step;
}
