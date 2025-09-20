const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const OptimizeMode = std.builtin.OptimizeMode;
const Step = std.Build.Step;

// Cases
const stack_traces = @import("stack_traces.zig");
const translate_c = @import("translate_c.zig");
const run_translated_c = @import("run_translated_c.zig");
const llvm_ir = @import("llvm_ir.zig");

// Implementations
pub const TranslateCContext = @import("src/TranslateC.zig");
pub const RunTranslatedCContext = @import("src/RunTranslatedC.zig");
pub const StackTracesContext = @import("src/StackTrace.zig");
pub const DebuggerContext = @import("src/Debugger.zig");
pub const LlvmIrContext = @import("src/LlvmIr.zig");

const TestTarget = struct {
    linkage: ?std.builtin.LinkMode = null,
    target: std.Target.Query = .{},
    optimize_mode: std.builtin.OptimizeMode = .Debug,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    pic: ?bool = null,
    strip: ?bool = null,
    skip_modules: []const []const u8 = &.{},

    // This is intended for targets that, for any reason, shouldn't be run as part of a normal test
    // invocation. This could be because of a slow backend, requiring a newer LLVM version, being
    // too niche, etc.
    extra_target: bool = false,
};

const test_targets = blk: {
    // getBaselineCpuFeatures calls populateDependencies which has a O(N ^ 2) algorithm
    // (where N is roughly 160, which technically makes it O(1), but it adds up to a
    // lot of branches)
    @setEvalBranchQuota(50000);
    break :blk [_]TestTarget{
        // Native Targets

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

        // FreeBSD Targets

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .freebsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .freebsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .powerpc64,
                .os_tag = .freebsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .powerpc64le,
                .os_tag = .freebsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .freebsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .freebsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        // Linux Targets

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
                .abi = .musl,
            },
            .linkage = .dynamic,
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
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
            .optimize_mode = .ReleaseFast,
            .strip = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.neoverse_n1 },
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = false,
            .use_lld = false,
            .optimize_mode = .ReleaseFast,
            .strip = true,
        },

        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .linux,
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .eabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .eabihf,
            },
        },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .link_libc = true,
        },
        // Crashes in weird ways when applying relocations.
        // .{
        //     .target = .{
        //         .cpu_arch = .arm,
        //         .os_tag = .linux,
        //         .abi = .musleabi,
        //     },
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     .extra_target = true,
        // },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .link_libc = true,
        },
        // Crashes in weird ways when applying relocations.
        // .{
        //     .target = .{
        //         .cpu_arch = .arm,
        //         .os_tag = .linux,
        //         .abi = .musleabihf,
        //     },
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     .extra_target = true,
        // },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .gnueabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .gnueabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .eabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .eabihf,
            },
        },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .link_libc = true,
        },
        // Crashes in weird ways when applying relocations.
        // .{
        //     .target = .{
        //         .cpu_arch = .armeb,
        //         .os_tag = .linux,
        //         .abi = .musleabi,
        //     },
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     .extra_target = true,
        // },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .link_libc = true,
        },
        // Crashes in weird ways when applying relocations.
        // .{
        //     .target = .{
        //         .cpu_arch = .armeb,
        //         .os_tag = .linux,
        //         .abi = .musleabihf,
        //     },
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     .extra_target = true,
        // },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .gnueabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .gnueabihf,
            },
            .link_libc = true,
        },

        // Similar to Thumb, we need long calls on Hexagon due to relocation range issues.
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "hexagon-linux-none",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            // https://github.com/llvm/llvm-project/pull/111217
            .skip_modules = &.{"std"},
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "hexagon-linux-musl",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .link_libc = true,
            // https://github.com/llvm/llvm-project/pull/111217
            .skip_modules = &.{"std"},
        },
        // Currently crashes in qemu-hexagon.
        // .{
        //     .target = std.Target.Query.parse(.{
        //         .arch_os_abi = "hexagon-linux-musl",
        //         .cpu_features = "baseline+long_calls",
        //     }) catch unreachable,
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     // https://github.com/llvm/llvm-project/pull/111217
        //     .skip_modules = &.{"std"},
        //     .extra_target = true,
        // },

        .{
            .target = .{
                .cpu_arch = .loongarch64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .loongarch64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .loongarch64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .loongarch64,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .eabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .eabihf,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .gnueabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .gnueabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .eabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .eabihf,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .gnueabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .gnueabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .gnuabi64,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .gnuabin32,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .gnuabi64,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .gnuabin32,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .eabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .eabihf,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabi,
            },
            .linkage = .dynamic,
            .link_libc = true,
            // https://github.com/ziglang/zig/issues/2256
            .skip_modules = &.{"std"},
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
            .linkage = .dynamic,
            .link_libc = true,
            // https://github.com/ziglang/zig/issues/2256
            .skip_modules = &.{"std"},
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .gnueabi,
            },
            .link_libc = true,
            // https://github.com/ziglang/zig/issues/2256
            .skip_modules = &.{"std"},
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .gnueabihf,
            },
            .link_libc = true,
            // https://github.com/ziglang/zig/issues/2256
            .skip_modules = &.{"std"},
        },

        .{
            .target = .{
                .cpu_arch = .powerpc64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        // Requires ELFv1 linker support.
        // .{
        //     .target = .{
        //         .cpu_arch = .powerpc64,
        //         .os_tag = .linux,
        //         .abi = .gnu,
        //     },
        //     .link_libc = true,
        // },
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
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
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
                .cpu_arch = .riscv32,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv32-linux-none",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv32,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv32,
                .os_tag = .linux,
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv32-linux-musl",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv32,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        // TODO implement codegen airFieldParentPtr
        // TODO implement airMemmove for riscv64
        //.{
        //    .target = std.Target.Query.parse(.{
        //        .arch_os_abi = "riscv64-linux-none",
        //        .cpu_features = "baseline+v+zbb",
        //    }) catch unreachable,
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv64-linux-none",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv64-linux-musl",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
            .link_libc = true,
            .extra_target = true,
        },
        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .s390x,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .s390x,
                .os_tag = .linux,
                .abi = .musl,
            },
            .link_libc = true,
        },
        // Currently hangs in qemu-s390x.
        // .{
        //     .target = .{
        //         .cpu_arch = .s390x,
        //         .os_tag = .linux,
        //         .abi = .musl,
        //     },
        //     .linkage = .dynamic,
        //     .link_libc = true,
        //     .extra_target = true,
        // },
        .{
            .target = .{
                .cpu_arch = .s390x,
                .os_tag = .linux,
                .abi = .gnu,
            },
            .link_libc = true,
        },

        // Calls are normally lowered to branch instructions that only support +/- 16 MB range when
        // targeting Thumb. This easily becomes insufficient for our test binaries, so use long
        // calls to avoid out-of-range relocations.
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-eabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-eabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-musleabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .link_libc = true,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-musleabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .link_libc = true,
            .pic = false, // Long calls don't work with PIC.
        },

        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-eabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-eabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-musleabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .link_libc = true,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-musleabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .link_libc = true,
            .pic = false, // Long calls don't work with PIC.
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
                .abi = .musl,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
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
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 },
                .os_tag = .linux,
                .abi = .none,
            },
            .pic = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
                .os_tag = .linux,
                .abi = .none,
            },
            .strip = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .none,
            },
            .use_llvm = true,
            .use_lld = true,
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
                .abi = .gnux32,
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
            .linkage = .dynamic,
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .muslx32,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .muslx32,
            },
            .linkage = .dynamic,
            .link_libc = true,
            .extra_target = true,
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

        // macOS Targets

        .{
            .target = .{
                .cpu_arch = .aarch64,
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
            .use_llvm = false,
            .use_lld = false,
            .optimize_mode = .ReleaseFast,
            .strip = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .macos,
                .abi = .none,
            },
            .use_llvm = false,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .macos,
                .abi = .none,
            },
        },

        // NetBSD Targets

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .netbsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .netbsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .netbsd,
                .abi = .eabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .netbsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .netbsd,
                .abi = .eabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .netbsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .netbsd,
                .abi = .eabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .netbsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .netbsd,
                .abi = .eabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .netbsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .netbsd,
                .abi = .eabi,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .netbsd,
                .abi = .eabihf,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .netbsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .netbsd,
                .abi = .none,
            },
            .link_libc = true,
        },

        // SPIR-V Targets

        // Disabled due to no active maintainer (feel free to fix the failures
        // and then re-enable at any time). The failures occur due to changing AIR
        // from the frontend, and backend being incomplete.
        //.{
        //    .target = std.Target.Query.parse(.{
        //        .arch_os_abi = "spirv64-vulkan",
        //        .cpu_features = "vulkan_v1_2+float16+float64",
        //    }) catch unreachable,
        //    .use_llvm = false,
        //    .use_lld = false,
        //    .skip_modules = &.{ "c-import", "zigc", "std" },
        //},

        // WASI Targets

        // Disabled due to no active maintainer (feel free to fix the failures
        // and then re-enable at any time). The failures occur due to backend
        // miscompilation of different AIR from the frontend.
        //.{
        //    .target = .{
        //        .cpu_arch = .wasm32,
        //        .os_tag = .wasi,
        //        .abi = .none,
        //    },
        //    .use_llvm = false,
        //    .use_lld = false,
        //},
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
                .abi = .none,
            },
        },
        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
                .abi = .musl,
            },
            .link_libc = true,
        },

        // Windows Targets

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .windows,
                .abi = .msvc,
            },
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .windows,
                .abi = .msvc,
            },
            .link_libc = true,
        },
        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .windows,
                .abi = .gnu,
            },
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
            .target = .{
                .cpu_arch = .thumb,
                .os_tag = .windows,
                .abi = .msvc,
            },
        },
        .{
            .target = .{
                .cpu_arch = .thumb,
                .os_tag = .windows,
                .abi = .msvc,
            },
            .link_libc = true,
        },
        // https://github.com/ziglang/zig/issues/24016
        // .{
        //     .target = .{
        //         .cpu_arch = .thumb,
        //         .os_tag = .windows,
        //         .abi = .gnu,
        //     },
        // },
        // .{
        //     .target = .{
        //         .cpu_arch = .thumb,
        //         .os_tag = .windows,
        //         .abi = .gnu,
        //     },
        //     .link_libc = true,
        // },

        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .windows,
                .abi = .msvc,
            },
        },
        .{
            .target = .{
                .cpu_arch = .x86,
                .os_tag = .windows,
                .abi = .msvc,
            },
            .link_libc = true,
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
                .abi = .msvc,
            },
            .use_llvm = false,
            .use_lld = false,
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
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .msvc,
            },
            .link_libc = true,
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
                .cpu_arch = .x86_64,
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

const c_abi_targets = blk: {
    @setEvalBranchQuota(20000);
    break :blk [_]CAbiTarget{
        // Native Targets

        .{
            .use_llvm = true,
        },

        // Linux Targets

        .{
            .target = .{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        .{
            .target = .{
                .cpu_arch = .aarch64_be,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        .{
            .target = .{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .musleabi,
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
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .musleabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .armeb,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
        },

        .{
            .target = .{
                .cpu_arch = .hexagon,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        .{
            .target = .{
                .cpu_arch = .loongarch64,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mipsel,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips64,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
        },

        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabi64,
            },
        },
        .{
            .target = .{
                .cpu_arch = .mips64el,
                .os_tag = .linux,
                .abi = .muslabin32,
            },
        },

        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabi,
            },
        },
        .{
            .target = .{
                .cpu_arch = .powerpc,
                .os_tag = .linux,
                .abi = .musleabihf,
            },
        },

        .{
            .target = .{
                .cpu_arch = .powerpc64,
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
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv32-linux-musl",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
        },
        .{
            .target = .{
                .cpu_arch = .riscv32,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "riscv64-linux-musl",
                .cpu_features = "baseline-d-f",
            }) catch unreachable,
        },
        .{
            .target = .{
                .cpu_arch = .riscv64,
                .os_tag = .linux,
                .abi = .musl,
            },
        },

        // Clang explodes when parsing `cfuncs.c`.
        // .{
        //     .target = .{
        //         .cpu_arch = .s390x,
        //         .os_tag = .linux,
        //         .abi = .musl,
        //     },
        // },

        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-musleabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumb-linux-musleabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },

        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-musleabi",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
        },
        .{
            .target = std.Target.Query.parse(.{
                .arch_os_abi = "thumbeb-linux-musleabihf",
                .cpu_features = "baseline+long_calls",
            }) catch unreachable,
            .pic = false, // Long calls don't work with PIC.
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
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .use_llvm = false,
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
            .pic = true,
            .c_defines = &.{"ZIG_BACKEND_STAGE2_X86_64"},
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .musl,
            },
            .use_llvm = true,
        },
        .{
            .target = .{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .muslx32,
            },
            .use_llvm = true,
        },

        // WASI Targets

        .{
            .target = .{
                .cpu_arch = .wasm32,
                .os_tag = .wasi,
                .abi = .musl,
            },
        },

        // Windows Targets

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
};

pub fn addStackTraceTests(
    b: *std.Build,
    test_filters: []const []const u8,
    optimize_modes: []const OptimizeMode,
) *Step {
    const check_exe = b.addExecutable(.{
        .name = "check-stack-trace",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/src/check-stack-trace.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
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
    skip_translate_c: bool,
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
            .skip_translate_c = skip_translate_c,
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

        const cleanup = b.addRemoveDirTree(.{ .cwd_relative = tmp_path });
        cleanup.step.dependOn(&run_test.step);
        cleanup.step.dependOn(&run_run.step);
        cleanup.step.dependOn(&run_bad.step);

        step.dependOn(&cleanup.step);
    }

    {
        // Test `zig init -m`.
        const tmp_path = b.makeTempPath();
        const init_exe = b.addSystemCommand(&.{ b.graph.zig_exe, "init", "-m" });
        init_exe.setCwd(.{ .cwd_relative = tmp_path });
        init_exe.setName("zig init -m");
        init_exe.expectStdOutEqual("");
        init_exe.expectStdErrEqual("info: successfully populated 'build.zig.zon' and 'build.zig'\n");
    }

    // Test Godbolt API
    if (builtin.os.tag == .linux and builtin.cpu.arch == .x86_64) {
        const tmp_path = b.makeTempPath();

        const example_zig = b.addWriteFiles().add("example.zig",
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
        run.addFileArg(example_zig);
        const example_s = run.addPrefixedOutputFileArg("-femit-asm=", "example.s");

        const checkfile = b.addCheckFile(example_s, .{
            .expected_matches = &.{
                "square:",
                "mov\teax, edi",
                "imul\teax, edi",
            },
        });
        checkfile.setName("check godbolt.org CLI usage generating valid asm");

        const cleanup = b.addRemoveDirTree(.{ .cwd_relative = tmp_path });
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
        dir.writeFile(.{ .sub_path = "fmt1.zig", .data = unformatted_code }) catch @panic("unhandled");
        dir.writeFile(.{ .sub_path = "fmt2.zig", .data = unformatted_code }) catch @panic("unhandled");
        dir.makeDir("subdir") catch @panic("unhandled");
        var subdir = dir.openDir("subdir", .{}) catch @panic("unhandled");
        defer subdir.close();
        subdir.writeFile(.{ .sub_path = "fmt3.zig", .data = unformatted_code }) catch @panic("unhandled");

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
        const fmt6_path = b.pathJoin(&.{ tmp_path, "fmt6.zig" });
        const write6 = b.addUpdateSourceFiles();
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

        const cleanup = b.addRemoveDirTree(.{ .cwd_relative = tmp_path });
        cleanup.step.dependOn(&check6.step);

        step.dependOn(&cleanup.step);
    }

    {
        const run_test = b.addSystemCommand(&.{
            b.graph.zig_exe,
            "build",
            "test",
            "-Dbool_true",
            "-Dbool_false=false",
            "-Dint=1234",
            "-De=two",
            "-Dstring=hello",
        });
        run_test.addArg("--build-file");
        run_test.addFileArg(b.path("test/standalone/options/build.zig"));
        run_test.addArg("--cache-dir");
        run_test.addFileArg(.{ .cwd_relative = b.cache_root.join(b.allocator, &.{}) catch @panic("OOM") });
        run_test.setName("test build options");

        step.dependOn(&run_test.step);
    }

    return step;
}

pub fn addTranslateCTests(
    b: *std.Build,
    parent_step: *std.Build.Step,
    test_filters: []const []const u8,
    test_target_filters: []const []const u8,
) void {
    const cases = b.allocator.create(TranslateCContext) catch @panic("OOM");
    cases.* = TranslateCContext{
        .b = b,
        .step = parent_step,
        .test_index = 0,
        .test_filters = test_filters,
        .test_target_filters = test_target_filters,
    };

    translate_c.addCases(cases);
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
}

const ModuleTestOptions = struct {
    test_filters: []const []const u8,
    test_target_filters: []const []const u8,
    test_extra_targets: bool,
    root_src: []const u8,
    name: []const u8,
    desc: []const u8,
    optimize_modes: []const OptimizeMode,
    include_paths: []const []const u8,
    skip_single_threaded: bool,
    skip_non_native: bool,
    skip_freebsd: bool,
    skip_netbsd: bool,
    skip_windows: bool,
    skip_macos: bool,
    skip_linux: bool,
    skip_llvm: bool,
    skip_libc: bool,
    max_rss: usize = 0,
    no_builtin: bool = false,
    build_options: ?*std.Build.Step.Options = null,
};

pub fn addModuleTests(b: *std.Build, options: ModuleTestOptions) *Step {
    const step = b.step(b.fmt("test-{s}", .{options.name}), options.desc);

    for_targets: for (test_targets) |test_target| {
        if (test_target.skip_modules.len > 0) {
            for (test_target.skip_modules) |skip_mod| {
                if (std.mem.eql(u8, options.name, skip_mod)) continue :for_targets;
            }
        }

        if (!options.test_extra_targets and test_target.extra_target) continue;

        if (options.skip_non_native and !test_target.target.isNative())
            continue;

        if (options.skip_freebsd and test_target.target.os_tag == .freebsd) continue;
        if (options.skip_netbsd and test_target.target.os_tag == .netbsd) continue;
        if (options.skip_windows and test_target.target.os_tag == .windows) continue;
        if (options.skip_macos and test_target.target.os_tag == .macos) continue;
        if (options.skip_linux and test_target.target.os_tag == .linux) continue;

        const would_use_llvm = wouldUseLlvm(test_target.use_llvm, test_target.target, test_target.optimize_mode);
        if (options.skip_llvm and would_use_llvm) continue;

        const resolved_target = b.resolveTargetQuery(test_target.target);
        const triple_txt = resolved_target.query.zigTriple(b.allocator) catch @panic("OOM");
        const target = &resolved_target.result;

        if (options.test_target_filters.len > 0) {
            for (options.test_target_filters) |filter| {
                if (std.mem.indexOf(u8, triple_txt, filter) != null) break;
            } else continue;
        }

        if (options.skip_libc and test_target.link_libc == true)
            continue;

        // We can't provide MSVC libc when cross-compiling.
        if (target.abi == .msvc and test_target.link_libc == true and builtin.os.tag != .windows)
            continue;

        if (options.skip_single_threaded and test_target.single_threaded == true)
            continue;

        // TODO get compiler-rt tests passing for self-hosted backends.
        if (((target.cpu.arch != .x86_64 and target.cpu.arch != .aarch64) or target.ofmt == .coff) and
            test_target.use_llvm == false and mem.eql(u8, options.name, "compiler-rt"))
            continue;

        // TODO get zigc tests passing for other self-hosted backends.
        if (target.cpu.arch != .x86_64 and
            test_target.use_llvm == false and mem.eql(u8, options.name, "zigc"))
            continue;

        // TODO get std lib tests passing for other self-hosted backends.
        if ((target.cpu.arch != .x86_64 or target.os.tag != .linux) and
            test_target.use_llvm == false and mem.eql(u8, options.name, "std"))
            continue;

        if (target.cpu.arch != .x86_64 and
            test_target.use_llvm == false and mem.eql(u8, options.name, "c-import"))
            continue;

        const want_this_mode = for (options.optimize_modes) |m| {
            if (m == test_target.optimize_mode) break true;
        } else false;
        if (!want_this_mode) continue;

        const libc_suffix = if (test_target.link_libc == true) "-libc" else "";
        const model_txt = target.cpu.model.name;

        // wasm32-wasi builds need more RAM, idk why
        const max_rss = if (target.os.tag == .wasi)
            options.max_rss * 2
        else
            options.max_rss;

        const these_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(options.root_src),
                .optimize = test_target.optimize_mode,
                .target = resolved_target,
                .link_libc = test_target.link_libc,
                .pic = test_target.pic,
                .strip = test_target.strip,
                .single_threaded = test_target.single_threaded,
            }),
            .max_rss = max_rss,
            .filters = options.test_filters,
            .use_llvm = test_target.use_llvm,
            .use_lld = test_target.use_lld,
            .zig_lib_dir = b.path("lib"),
        });
        these_tests.linkage = test_target.linkage;
        if (options.no_builtin) these_tests.root_module.no_builtin = false;
        if (options.build_options) |build_options| {
            these_tests.root_module.addOptions("build_options", build_options);
        }
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
        const linkage_name = if (test_target.linkage) |linkage| switch (linkage) {
            inline else => |t| "-" ++ @tagName(t),
        } else "";
        const use_pic = if (test_target.pic == true) "-pic" else "";

        for (options.include_paths) |include_path| these_tests.root_module.addIncludePath(b.path(include_path));

        const qualified_name = b.fmt("{s}-{s}-{s}-{s}{s}{s}{s}{s}{s}{s}", .{
            options.name,
            triple_txt,
            model_txt,
            @tagName(test_target.optimize_mode),
            libc_suffix,
            single_threaded_suffix,
            backend_suffix,
            use_lld,
            linkage_name,
            use_pic,
        });

        if (target.ofmt == std.Target.ObjectFormat.c) {
            var altered_query = test_target.target;
            altered_query.ofmt = null;

            const compile_c = b.createModule(.{
                .root_source_file = null,
                .link_libc = test_target.link_libc,
                .target = b.resolveTargetQuery(altered_query),
            });
            const compile_c_exe = b.addExecutable(.{
                .name = qualified_name,
                .root_module = compile_c,
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

                    // https://github.com/llvm/llvm-project/issues/153314
                    "-Wno-unterminated-string-initialization",
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
                    compile_c_exe.subsystem = .Console;
                    compile_c.linkSystemLibrary("kernel32", .{});
                    compile_c.linkSystemLibrary("ntdll", .{});
                }
                if (mem.eql(u8, options.name, "std")) {
                    if (test_target.link_libc == false) {
                        compile_c.linkSystemLibrary("shell32", .{});
                        compile_c.linkSystemLibrary("advapi32", .{});
                    }
                    compile_c.linkSystemLibrary("crypt32", .{});
                    compile_c.linkSystemLibrary("ws2_32", .{});
                    compile_c.linkSystemLibrary("ole32", .{});
                }
            }

            const run = b.addRunArtifact(compile_c_exe);
            run.skip_foreign_checks = true;
            run.enableTestRunnerMode();
            run.setName(b.fmt("run test {s}", .{qualified_name}));

            step.dependOn(&run.step);
        } else if (target.cpu.arch.isSpirV()) {
            // Don't run spirv binaries
            _ = these_tests.getEmittedBin();
            step.dependOn(&these_tests.step);
        } else {
            const run = b.addRunArtifact(these_tests);
            run.skip_foreign_checks = true;
            run.setName(b.fmt("run test {s}", .{qualified_name}));

            step.dependOn(&run.step);
        }
    }
    return step;
}

pub fn wouldUseLlvm(use_llvm: ?bool, query: std.Target.Query, optimize_mode: OptimizeMode) bool {
    if (use_llvm) |x| return x;
    if (query.ofmt == .c) return false;
    switch (optimize_mode) {
        .Debug => {},
        else => return true,
    }
    const cpu_arch = query.cpu_arch orelse builtin.cpu.arch;
    switch (cpu_arch) {
        .x86_64 => if (std.Target.ptrBitWidth_arch_abi(cpu_arch, query.abi orelse .none) != 64) return true,
        .spirv32, .spirv64 => return false,
        else => return true,
    }
    return false;
}

const CAbiTestOptions = struct {
    test_target_filters: []const []const u8,
    skip_non_native: bool,
    skip_freebsd: bool,
    skip_netbsd: bool,
    skip_windows: bool,
    skip_macos: bool,
    skip_linux: bool,
    skip_llvm: bool,
    skip_release: bool,
};

pub fn addCAbiTests(b: *std.Build, options: CAbiTestOptions) *Step {
    const step = b.step("test-c-abi", "Run the C ABI tests");

    const optimize_modes: [3]OptimizeMode = .{ .Debug, .ReleaseSafe, .ReleaseFast };

    for (optimize_modes) |optimize_mode| {
        if (optimize_mode != .Debug and options.skip_release) continue;

        for (c_abi_targets) |c_abi_target| {
            if (options.skip_non_native and !c_abi_target.target.isNative()) continue;
            if (options.skip_freebsd and c_abi_target.target.os_tag == .freebsd) continue;
            if (options.skip_netbsd and c_abi_target.target.os_tag == .netbsd) continue;
            if (options.skip_windows and c_abi_target.target.os_tag == .windows) continue;
            if (options.skip_macos and c_abi_target.target.os_tag == .macos) continue;
            if (options.skip_linux and c_abi_target.target.os_tag == .linux) continue;

            const would_use_llvm = wouldUseLlvm(c_abi_target.use_llvm, c_abi_target.target, .Debug);
            if (options.skip_llvm and would_use_llvm) continue;

            const resolved_target = b.resolveTargetQuery(c_abi_target.target);
            const triple_txt = resolved_target.query.zigTriple(b.allocator) catch @panic("OOM");
            const target = &resolved_target.result;

            if (options.test_target_filters.len > 0) {
                for (options.test_target_filters) |filter| {
                    if (std.mem.indexOf(u8, triple_txt, filter) != null) break;
                } else continue;
            }

            if (target.os.tag == .windows and target.cpu.arch == .aarch64) {
                // https://github.com/ziglang/zig/issues/14908
                continue;
            }

            const test_mod = b.createModule(.{
                .root_source_file = b.path("test/c_abi/main.zig"),
                .target = resolved_target,
                .optimize = optimize_mode,
                .link_libc = true,
                .pic = c_abi_target.pic,
                .strip = c_abi_target.strip,
            });
            test_mod.addCSourceFile(.{
                .file = b.path("test/c_abi/cfuncs.c"),
                .flags = &.{"-std=c99"},
            });
            for (c_abi_target.c_defines) |define| test_mod.addCMacro(define, "1");

            const test_step = b.addTest(.{
                .name = b.fmt("test-c-abi-{s}-{s}-{s}{s}{s}{s}", .{
                    triple_txt,
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
                .root_module = test_mod,
                .use_llvm = c_abi_target.use_llvm,
                .use_lld = c_abi_target.use_lld,
            });

            // This test is intentionally trying to check if the external ABI is
            // done properly. LTO would be a hindrance to this.
            test_step.lto = .none;

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
    target: std.Build.ResolvedTarget,
    case_test_options: @import("src/Cases.zig").CaseTestOptions,
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

    cases.lowerToTranslateCSteps(
        b,
        parent_step,
        case_test_options.test_filters,
        case_test_options.test_target_filters,
        target,
        translate_c_options,
    );

    cases.lowerToBuildSteps(
        b,
        parent_step,
        case_test_options,
    );
}

pub fn addDebuggerTests(b: *std.Build, options: DebuggerContext.Options) ?*Step {
    const step = b.step("test-debugger", "Run the debugger tests");
    if (options.gdb == null and options.lldb == null) {
        step.dependOn(&b.addFail("test-debugger requires -Dgdb and/or -Dlldb").step);
        return null;
    }

    var context: DebuggerContext = .{
        .b = b,
        .options = options,
        .root_step = step,
    };
    context.addTestsForTarget(&.{
        .resolved = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        }),
        .pic = false,
        .test_name_suffix = "x86_64-linux",
    });
    context.addTestsForTarget(&.{
        .resolved = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        }),
        .pic = true,
        .test_name_suffix = "x86_64-linux-pic",
    });
    return step;
}

pub fn addIncrementalTests(b: *std.Build, test_step: *Step) !void {
    const incr_check = b.addExecutable(.{
        .name = "incr-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/incr-check.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    var dir = try b.build_root.handle.openDir("test/incremental", .{ .iterate = true });
    defer dir.close();

    var it = try dir.walk(b.graph.arena);
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        const run = b.addRunArtifact(incr_check);
        run.setName(b.fmt("incr-check '{s}'", .{entry.basename}));

        run.addArg(b.graph.zig_exe);
        run.addFileArg(b.path("test/incremental/").path(b, entry.path));
        run.addArgs(&.{ "--zig-lib-dir", b.fmt("{f}", .{b.graph.zig_lib_directory}) });

        run.addCheck(.{ .expect_term = .{ .Exited = 0 } });

        test_step.dependOn(&run.step);
    }
}

pub fn addLlvmIrTests(b: *std.Build, options: LlvmIrContext.Options) ?*Step {
    const step = b.step("test-llvm-ir", "Run the LLVM IR tests");

    if (!options.enable_llvm) {
        step.dependOn(&b.addFail("test-llvm-ir requires -Denable-llvm").step);
        return null;
    }

    var context: LlvmIrContext = .{
        .b = b,
        .options = options,
        .root_step = step,
    };

    llvm_ir.addCases(&context);

    return step;
}
