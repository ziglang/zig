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
const gen_h = @import("gen_h.zig");
const link = @import("link.zig");

// Implementations
pub const TranslateCContext = @import("src/translate_c.zig").TranslateCContext;
pub const RunTranslatedCContext = @import("src/run_translated_c.zig").RunTranslatedCContext;
pub const CompareOutputContext = @import("src/compare_output.zig").CompareOutputContext;

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

const max_stdout_size = 1 * 1024 * 1024; // 1 MB

pub fn addCompareOutputTests(b: *std.Build, test_filter: ?[]const u8, optimize_modes: []const OptimizeMode) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch unreachable;
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

pub fn addStackTraceTests(b: *std.Build, test_filter: ?[]const u8, optimize_modes: []const OptimizeMode) *Step {
    const cases = b.allocator.create(StackTracesContext) catch unreachable;
    cases.* = StackTracesContext{
        .b = b,
        .step = b.step("test-stack-traces", "Run the stack trace tests"),
        .test_index = 0,
        .test_filter = test_filter,
        .optimize_modes = optimize_modes,
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
    const cases = b.allocator.create(StandaloneContext) catch unreachable;
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
    const cases = b.allocator.create(StandaloneContext) catch unreachable;
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
        fs.realpathAlloc(b.allocator, b.zig_exe) catch unreachable,
        b.pathFromRoot(b.cache_root.path orelse "."),
    });

    step.dependOn(&run_cmd.step);
    return step;
}

pub fn addAssembleAndLinkTests(b: *std.Build, test_filter: ?[]const u8, optimize_modes: []const OptimizeMode) *Step {
    const cases = b.allocator.create(CompareOutputContext) catch unreachable;
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
    const cases = b.allocator.create(TranslateCContext) catch unreachable;
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
    const cases = b.allocator.create(RunTranslatedCContext) catch unreachable;
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

pub fn addGenHTests(b: *std.Build, test_filter: ?[]const u8) *Step {
    const cases = b.allocator.create(GenHContext) catch unreachable;
    cases.* = GenHContext{
        .b = b,
        .step = b.step("test-gen-h", "Run the C header file generation tests"),
        .test_index = 0,
        .test_filter = test_filter,
    };

    gen_h.addCases(cases);

    return cases.step;
}

pub fn addPkgTests(
    b: *std.Build,
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
) *Step {
    const step = b.step(b.fmt("test-{s}", .{name}), desc);

    for (test_targets) |test_target| {
        if (skip_non_native and !test_target.target.isNative())
            continue;

        if (skip_libc and test_target.link_libc)
            continue;

        if (test_target.link_libc and test_target.target.getOs().requiresLibC()) {
            // This would be a redundant test.
            continue;
        }

        if (skip_single_threaded and test_target.single_threaded)
            continue;

        if (test_target.disable_native and
            test_target.target.getOsTag() == builtin.os.tag and
            test_target.target.getCpuArch() == builtin.cpu.arch)
        {
            continue;
        }

        if (test_target.backend) |backend| switch (backend) {
            .stage1 => if (skip_stage1) continue,
            .stage2_llvm => {},
            else => if (skip_stage2) continue,
        };

        const want_this_mode = for (optimize_modes) |m| {
            if (m == test_target.optimize_mode) break true;
        } else false;
        if (!want_this_mode) continue;

        const libc_prefix = if (test_target.target.getOs().requiresLibC())
            ""
        else if (test_target.link_libc)
            "c"
        else
            "bare";

        const triple_prefix = test_target.target.zigTriple(b.allocator) catch unreachable;

        const these_tests = b.addTest(.{
            .root_source_file = .{ .path = root_src },
            .optimize = test_target.optimize_mode,
            .target = test_target.target,
        });
        const single_threaded_txt = if (test_target.single_threaded) "single" else "multi";
        const backend_txt = if (test_target.backend) |backend| @tagName(backend) else "default";
        these_tests.setNamePrefix(b.fmt("{s}-{s}-{s}-{s}-{s}-{s} ", .{
            name,
            triple_prefix,
            @tagName(test_target.optimize_mode),
            libc_prefix,
            single_threaded_txt,
            backend_txt,
        }));
        these_tests.single_threaded = test_target.single_threaded;
        these_tests.setFilter(test_filter);
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

pub const StackTracesContext = struct {
    b: *std.Build,
    step: *Step,
    test_index: usize,
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,

    const Expect = [@typeInfo(OptimizeMode).Enum.fields.len][]const u8;

    pub fn addCase(self: *StackTracesContext, config: anytype) void {
        if (@hasField(@TypeOf(config), "exclude")) {
            if (config.exclude.exclude()) return;
        }
        if (@hasField(@TypeOf(config), "exclude_arch")) {
            const exclude_arch: []const std.Target.Cpu.Arch = &config.exclude_arch;
            for (exclude_arch) |arch| if (arch == builtin.cpu.arch) return;
        }
        if (@hasField(@TypeOf(config), "exclude_os")) {
            const exclude_os: []const std.Target.Os.Tag = &config.exclude_os;
            for (exclude_os) |os| if (os == builtin.os.tag) return;
        }
        for (self.optimize_modes) |optimize_mode| {
            switch (optimize_mode) {
                .Debug => {
                    if (@hasField(@TypeOf(config), "Debug")) {
                        self.addExpect(config.name, config.source, optimize_mode, config.Debug);
                    }
                },
                .ReleaseSafe => {
                    if (@hasField(@TypeOf(config), "ReleaseSafe")) {
                        self.addExpect(config.name, config.source, optimize_mode, config.ReleaseSafe);
                    }
                },
                .ReleaseFast => {
                    if (@hasField(@TypeOf(config), "ReleaseFast")) {
                        self.addExpect(config.name, config.source, optimize_mode, config.ReleaseFast);
                    }
                },
                .ReleaseSmall => {
                    if (@hasField(@TypeOf(config), "ReleaseSmall")) {
                        self.addExpect(config.name, config.source, optimize_mode, config.ReleaseSmall);
                    }
                },
            }
        }
    }

    fn addExpect(
        self: *StackTracesContext,
        name: []const u8,
        source: []const u8,
        optimize_mode: OptimizeMode,
        mode_config: anytype,
    ) void {
        if (@hasField(@TypeOf(mode_config), "exclude")) {
            if (mode_config.exclude.exclude()) return;
        }
        if (@hasField(@TypeOf(mode_config), "exclude_arch")) {
            const exclude_arch: []const std.Target.Cpu.Arch = &mode_config.exclude_arch;
            for (exclude_arch) |arch| if (arch == builtin.cpu.arch) return;
        }
        if (@hasField(@TypeOf(mode_config), "exclude_os")) {
            const exclude_os: []const std.Target.Os.Tag = &mode_config.exclude_os;
            for (exclude_os) |os| if (os == builtin.os.tag) return;
        }

        const annotated_case_name = fmt.allocPrint(self.b.allocator, "{s} {s} ({s})", .{
            "stack-trace",
            name,
            @tagName(optimize_mode),
        }) catch unreachable;
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
        }

        const b = self.b;
        const src_basename = "source.zig";
        const write_src = b.addWriteFile(src_basename, source);
        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = write_src.getFileSource(src_basename).?,
            .optimize = optimize_mode,
            .target = .{},
        });

        const run_and_compare = RunAndCompareStep.create(
            self,
            exe,
            annotated_case_name,
            optimize_mode,
            mode_config.expect,
        );

        self.step.dependOn(&run_and_compare.step);
    }

    const RunAndCompareStep = struct {
        pub const base_id = .custom;

        step: Step,
        context: *StackTracesContext,
        exe: *CompileStep,
        name: []const u8,
        optimize_mode: OptimizeMode,
        expect_output: []const u8,
        test_index: usize,

        pub fn create(
            context: *StackTracesContext,
            exe: *CompileStep,
            name: []const u8,
            optimize_mode: OptimizeMode,
            expect_output: []const u8,
        ) *RunAndCompareStep {
            const allocator = context.b.allocator;
            const ptr = allocator.create(RunAndCompareStep) catch unreachable;
            ptr.* = RunAndCompareStep{
                .step = Step.init(.custom, "StackTraceCompareOutputStep", allocator, make),
                .context = context,
                .exe = exe,
                .name = name,
                .optimize_mode = optimize_mode,
                .expect_output = expect_output,
                .test_index = context.test_index,
            };
            ptr.step.dependOn(&exe.step);
            context.test_index += 1;
            return ptr;
        }

        fn make(step: *Step) !void {
            const self = @fieldParentPtr(RunAndCompareStep, "step", step);
            const b = self.context.b;

            const full_exe_path = self.exe.getOutputSource().getPath(b);
            var args = ArrayList([]const u8).init(b.allocator);
            defer args.deinit();
            args.append(full_exe_path) catch unreachable;

            std.debug.print("Test {d}/{d} {s}...", .{ self.test_index + 1, self.context.test_index, self.name });

            if (!std.process.can_spawn) {
                const cmd = try std.mem.join(b.allocator, " ", args.items);
                std.debug.print("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{ @tagName(builtin.os.tag), cmd });
                b.allocator.free(cmd);
                return ExecError.ExecNotSupported;
            }

            var child = std.ChildProcess.init(args.items, b.allocator);
            child.stdin_behavior = .Ignore;
            child.stdout_behavior = .Pipe;
            child.stderr_behavior = .Pipe;
            child.env_map = b.env_map;

            if (b.verbose) {
                printInvocation(args.items);
            }
            child.spawn() catch |err| debug.panic("Unable to spawn {s}: {s}\n", .{ full_exe_path, @errorName(err) });

            const stdout = child.stdout.?.reader().readAllAlloc(b.allocator, max_stdout_size) catch unreachable;
            defer b.allocator.free(stdout);
            const stderrFull = child.stderr.?.reader().readAllAlloc(b.allocator, max_stdout_size) catch unreachable;
            defer b.allocator.free(stderrFull);
            var stderr = stderrFull;

            const term = child.wait() catch |err| {
                debug.panic("Unable to spawn {s}: {s}\n", .{ full_exe_path, @errorName(err) });
            };

            switch (term) {
                .Exited => |code| {
                    const expect_code: u32 = 1;
                    if (code != expect_code) {
                        std.debug.print("Process {s} exited with error code {d} but expected code {d}\n", .{
                            full_exe_path,
                            code,
                            expect_code,
                        });
                        printInvocation(args.items);
                        return error.TestFailed;
                    }
                },
                .Signal => |signum| {
                    std.debug.print("Process {s} terminated on signal {d}\n", .{ full_exe_path, signum });
                    printInvocation(args.items);
                    return error.TestFailed;
                },
                .Stopped => |signum| {
                    std.debug.print("Process {s} stopped on signal {d}\n", .{ full_exe_path, signum });
                    printInvocation(args.items);
                    return error.TestFailed;
                },
                .Unknown => |code| {
                    std.debug.print("Process {s} terminated unexpectedly with error code {d}\n", .{ full_exe_path, code });
                    printInvocation(args.items);
                    return error.TestFailed;
                },
            }

            // process result
            // - keep only basename of source file path
            // - replace address with symbolic string
            // - replace function name with symbolic string when optimize_mode != .Debug
            // - skip empty lines
            const got: []const u8 = got_result: {
                var buf = ArrayList(u8).init(b.allocator);
                defer buf.deinit();
                if (stderr.len != 0 and stderr[stderr.len - 1] == '\n') stderr = stderr[0 .. stderr.len - 1];
                var it = mem.split(u8, stderr, "\n");
                process_lines: while (it.next()) |line| {
                    if (line.len == 0) continue;

                    // offset search past `[drive]:` on windows
                    var pos: usize = if (builtin.os.tag == .windows) 2 else 0;
                    // locate delims/anchor
                    const delims = [_][]const u8{ ":", ":", ":", " in ", "(", ")" };
                    var marks = [_]usize{0} ** delims.len;
                    for (delims, 0..) |delim, i| {
                        marks[i] = mem.indexOfPos(u8, line, pos, delim) orelse {
                            // unexpected pattern: emit raw line and cont
                            try buf.appendSlice(line);
                            try buf.appendSlice("\n");
                            continue :process_lines;
                        };
                        pos = marks[i] + delim.len;
                    }
                    // locate source basename
                    pos = mem.lastIndexOfScalar(u8, line[0..marks[0]], fs.path.sep) orelse {
                        // unexpected pattern: emit raw line and cont
                        try buf.appendSlice(line);
                        try buf.appendSlice("\n");
                        continue :process_lines;
                    };
                    // end processing if source basename changes
                    if (!mem.eql(u8, "source.zig", line[pos + 1 .. marks[0]])) break;
                    // emit substituted line
                    try buf.appendSlice(line[pos + 1 .. marks[2] + delims[2].len]);
                    try buf.appendSlice(" [address]");
                    if (self.optimize_mode == .Debug) {
                        // On certain platforms (windows) or possibly depending on how we choose to link main
                        // the object file extension may be present so we simply strip any extension.
                        if (mem.indexOfScalar(u8, line[marks[4]..marks[5]], '.')) |idot| {
                            try buf.appendSlice(line[marks[3] .. marks[4] + idot]);
                            try buf.appendSlice(line[marks[5]..]);
                        } else {
                            try buf.appendSlice(line[marks[3]..]);
                        }
                    } else {
                        try buf.appendSlice(line[marks[3] .. marks[3] + delims[3].len]);
                        try buf.appendSlice("[function]");
                    }
                    try buf.appendSlice("\n");
                }
                break :got_result try buf.toOwnedSlice();
            };

            if (!mem.eql(u8, self.expect_output, got)) {
                std.debug.print(
                    \\
                    \\========= Expected this output: =========
                    \\{s}
                    \\================================================
                    \\{s}
                    \\
                , .{ self.expect_output, got });
                return error.TestFailed;
            }
            std.debug.print("OK\n", .{});
        }
    };
};

pub const StandaloneContext = struct {
    b: *std.Build,
    step: *Step,
    test_index: usize,
    test_filter: ?[]const u8,
    optimize_modes: []const OptimizeMode,
    skip_non_native: bool,
    enable_macos_sdk: bool,
    target: std.zig.CrossTarget,
    omit_stage2: bool,
    enable_darling: bool = false,
    enable_qemu: bool = false,
    enable_rosetta: bool = false,
    enable_wasmtime: bool = false,
    enable_wine: bool = false,
    enable_symlinks_windows: bool,

    pub fn addC(self: *StandaloneContext, root_src: []const u8) void {
        self.addAllArgs(root_src, true);
    }

    pub fn add(self: *StandaloneContext, root_src: []const u8) void {
        self.addAllArgs(root_src, false);
    }

    pub fn addBuildFile(self: *StandaloneContext, build_file: []const u8, features: struct {
        build_modes: bool = false,
        cross_targets: bool = false,
        requires_macos_sdk: bool = false,
        requires_stage2: bool = false,
        use_emulation: bool = false,
        requires_symlinks: bool = false,
        extra_argv: []const []const u8 = &.{},
    }) void {
        const b = self.b;

        if (features.requires_macos_sdk and !self.enable_macos_sdk) return;
        if (features.requires_stage2 and self.omit_stage2) return;
        if (features.requires_symlinks and !self.enable_symlinks_windows and builtin.os.tag == .windows) return;

        const annotated_case_name = b.fmt("build {s}", .{build_file});
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
        }

        var zig_args = ArrayList([]const u8).init(b.allocator);
        const rel_zig_exe = fs.path.relative(b.allocator, b.build_root.path orelse ".", b.zig_exe) catch unreachable;
        zig_args.append(rel_zig_exe) catch unreachable;
        zig_args.append("build") catch unreachable;

        zig_args.append("--build-file") catch unreachable;
        zig_args.append(b.pathFromRoot(build_file)) catch unreachable;

        zig_args.appendSlice(features.extra_argv) catch unreachable;

        zig_args.append("test") catch unreachable;

        if (b.verbose) {
            zig_args.append("--verbose") catch unreachable;
        }

        if (features.cross_targets and !self.target.isNative()) {
            const target_triple = self.target.zigTriple(b.allocator) catch unreachable;
            const target_arg = fmt.allocPrint(b.allocator, "-Dtarget={s}", .{target_triple}) catch unreachable;
            zig_args.append(target_arg) catch unreachable;
        }

        if (features.use_emulation) {
            if (self.enable_darling) {
                zig_args.append("-fdarling") catch unreachable;
            }
            if (self.enable_qemu) {
                zig_args.append("-fqemu") catch unreachable;
            }
            if (self.enable_rosetta) {
                zig_args.append("-frosetta") catch unreachable;
            }
            if (self.enable_wasmtime) {
                zig_args.append("-fwasmtime") catch unreachable;
            }
            if (self.enable_wine) {
                zig_args.append("-fwine") catch unreachable;
            }
        }

        const optimize_modes = if (features.build_modes) self.optimize_modes else &[1]OptimizeMode{.Debug};
        for (optimize_modes) |optimize_mode| {
            const arg = switch (optimize_mode) {
                .Debug => "",
                .ReleaseFast => "-Doptimize=ReleaseFast",
                .ReleaseSafe => "-Doptimize=ReleaseSafe",
                .ReleaseSmall => "-Doptimize=ReleaseSmall",
            };
            const zig_args_base_len = zig_args.items.len;
            if (arg.len > 0)
                zig_args.append(arg) catch unreachable;
            defer zig_args.resize(zig_args_base_len) catch unreachable;

            const run_cmd = b.addSystemCommand(zig_args.items);
            const log_step = b.addLog("PASS {s} ({s})", .{ annotated_case_name, @tagName(optimize_mode) });
            log_step.step.dependOn(&run_cmd.step);

            self.step.dependOn(&log_step.step);
        }
    }

    pub fn addAllArgs(self: *StandaloneContext, root_src: []const u8, link_libc: bool) void {
        const b = self.b;

        for (self.optimize_modes) |optimize| {
            const annotated_case_name = fmt.allocPrint(self.b.allocator, "build {s} ({s})", .{
                root_src,
                @tagName(optimize),
            }) catch unreachable;
            if (self.test_filter) |filter| {
                if (mem.indexOf(u8, annotated_case_name, filter) == null) continue;
            }

            const exe = b.addExecutable(.{
                .name = "test",
                .root_source_file = .{ .path = root_src },
                .optimize = optimize,
                .target = .{},
            });
            if (link_libc) {
                exe.linkSystemLibrary("c");
            }

            const log_step = b.addLog("PASS {s}", .{annotated_case_name});
            log_step.step.dependOn(&exe.step);

            self.step.dependOn(&log_step.step);
        }
    }
};

pub const GenHContext = struct {
    b: *std.Build,
    step: *Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const TestCase = struct {
        name: []const u8,
        sources: ArrayList(SourceFile),
        expected_lines: ArrayList([]const u8),

        const SourceFile = struct {
            filename: []const u8,
            source: []const u8,
        };

        pub fn addSourceFile(self: *TestCase, filename: []const u8, source: []const u8) void {
            self.sources.append(SourceFile{
                .filename = filename,
                .source = source,
            }) catch unreachable;
        }

        pub fn addExpectedLine(self: *TestCase, text: []const u8) void {
            self.expected_lines.append(text) catch unreachable;
        }
    };

    const GenHCmpOutputStep = struct {
        step: Step,
        context: *GenHContext,
        obj: *CompileStep,
        name: []const u8,
        test_index: usize,
        case: *const TestCase,

        pub fn create(
            context: *GenHContext,
            obj: *CompileStep,
            name: []const u8,
            case: *const TestCase,
        ) *GenHCmpOutputStep {
            const allocator = context.b.allocator;
            const ptr = allocator.create(GenHCmpOutputStep) catch unreachable;
            ptr.* = GenHCmpOutputStep{
                .step = Step.init(.Custom, "ParseCCmpOutput", allocator, make),
                .context = context,
                .obj = obj,
                .name = name,
                .test_index = context.test_index,
                .case = case,
            };
            ptr.step.dependOn(&obj.step);
            context.test_index += 1;
            return ptr;
        }

        fn make(step: *Step) !void {
            const self = @fieldParentPtr(GenHCmpOutputStep, "step", step);
            const b = self.context.b;

            std.debug.print("Test {d}/{d} {s}...", .{ self.test_index + 1, self.context.test_index, self.name });

            const full_h_path = self.obj.getOutputHPath();
            const actual_h = try io.readFileAlloc(b.allocator, full_h_path);

            for (self.case.expected_lines.items) |expected_line| {
                if (mem.indexOf(u8, actual_h, expected_line) == null) {
                    std.debug.print(
                        \\
                        \\========= Expected this output: ================
                        \\{s}
                        \\========= But found: ===========================
                        \\{s}
                        \\
                    , .{ expected_line, actual_h });
                    return error.TestFailed;
                }
            }
            std.debug.print("OK\n", .{});
        }
    };

    pub fn create(
        self: *GenHContext,
        filename: []const u8,
        name: []const u8,
        source: []const u8,
        expected_lines: []const []const u8,
    ) *TestCase {
        const tc = self.b.allocator.create(TestCase) catch unreachable;
        tc.* = TestCase{
            .name = name,
            .sources = ArrayList(TestCase.SourceFile).init(self.b.allocator),
            .expected_lines = ArrayList([]const u8).init(self.b.allocator),
        };

        tc.addSourceFile(filename, source);
        var arg_i: usize = 0;
        while (arg_i < expected_lines.len) : (arg_i += 1) {
            tc.addExpectedLine(expected_lines[arg_i]);
        }
        return tc;
    }

    pub fn add(self: *GenHContext, name: []const u8, source: []const u8, expected_lines: []const []const u8) void {
        const tc = self.create("test.zig", name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addCase(self: *GenHContext, case: *const TestCase) void {
        const b = self.b;

        const optimize_mode = std.builtin.OptimizeMode.Debug;
        const annotated_case_name = fmt.allocPrint(self.b.allocator, "gen-h {s} ({s})", .{ case.name, @tagName(optimize_mode) }) catch unreachable;
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
        }

        const write_src = b.addWriteFiles();
        for (case.sources.items) |src_file| {
            write_src.add(src_file.filename, src_file.source);
        }

        const obj = b.addObjectFromWriteFileStep("test", write_src, case.sources.items[0].filename);
        obj.setBuildMode(optimize_mode);

        const cmp_h = GenHCmpOutputStep.create(self, obj, annotated_case_name, case);

        self.step.dependOn(&cmp_h.step);
    }
};

fn printInvocation(args: []const []const u8) void {
    for (args) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}

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

        const triple_prefix = c_abi_target.zigTriple(b.allocator) catch unreachable;
        test_step.setNamePrefix(b.fmt("{s}-{s}-{s} ", .{
            "test-c-abi",
            triple_prefix,
            @tagName(optimize_mode),
        }));

        step.dependOn(&test_step.step);
    };
    return step;
}
