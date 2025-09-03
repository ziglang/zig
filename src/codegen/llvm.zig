const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);
const math = std.math;
const DW = std.dwarf;

const Builder = std.zig.llvm.Builder;
const llvm = if (build_options.have_llvm)
    @import("llvm/bindings.zig")
else
    @compileError("LLVM unavailable");
const link = @import("../link.zig");
const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const Package = @import("../Package.zig");
const Air = @import("../Air.zig");
const Value = @import("../Value.zig");
const Type = @import("../Type.zig");
const codegen = @import("../codegen.zig");
const x86_64_abi = @import("../arch/x86_64/abi.zig");
const wasm_c_abi = @import("wasm/abi.zig");
const aarch64_c_abi = @import("aarch64/abi.zig");
const arm_c_abi = @import("arm/abi.zig");
const riscv_c_abi = @import("../arch/riscv64/abi.zig");
const mips_c_abi = @import("mips/abi.zig");
const dev = @import("../dev.zig");

const target_util = @import("../target.zig");
const libcFloatPrefix = target_util.libcFloatPrefix;
const libcFloatSuffix = target_util.libcFloatSuffix;
const compilerRtFloatAbbrev = target_util.compilerRtFloatAbbrev;
const compilerRtIntAbbrev = target_util.compilerRtIntAbbrev;

const Error = error{ OutOfMemory, CodegenFail };

pub fn legalizeFeatures(_: *const std.Target) ?*const Air.Legalize.Features {
    return comptime &.initMany(&.{
        .expand_int_from_float_safe,
        .expand_int_from_float_optimized_safe,
    });
}

fn subArchName(target: *const std.Target, comptime family: std.Target.Cpu.Arch.Family, mappings: anytype) ?[]const u8 {
    inline for (mappings) |mapping| {
        if (target.cpu.has(family, mapping[0])) return mapping[1];
    }

    return null;
}

pub fn targetTriple(allocator: Allocator, target: *const std.Target) ![]const u8 {
    var llvm_triple = std.array_list.Managed(u8).init(allocator);
    defer llvm_triple.deinit();

    const llvm_arch = switch (target.cpu.arch) {
        .arm => "arm",
        .armeb => "armeb",
        .aarch64 => if (target.abi == .ilp32) "aarch64_32" else "aarch64",
        .aarch64_be => "aarch64_be",
        .arc => "arc",
        .avr => "avr",
        .bpfel => "bpfel",
        .bpfeb => "bpfeb",
        .csky => "csky",
        .hexagon => "hexagon",
        .loongarch32 => "loongarch32",
        .loongarch64 => "loongarch64",
        .m68k => "m68k",
        // MIPS sub-architectures are a bit irregular, so we handle them manually here.
        .mips => if (target.cpu.has(.mips, .mips32r6)) "mipsisa32r6" else "mips",
        .mipsel => if (target.cpu.has(.mips, .mips32r6)) "mipsisa32r6el" else "mipsel",
        .mips64 => if (target.cpu.has(.mips, .mips64r6)) "mipsisa64r6" else "mips64",
        .mips64el => if (target.cpu.has(.mips, .mips64r6)) "mipsisa64r6el" else "mips64el",
        .msp430 => "msp430",
        .powerpc => "powerpc",
        .powerpcle => "powerpcle",
        .powerpc64 => "powerpc64",
        .powerpc64le => "powerpc64le",
        .amdgcn => "amdgcn",
        .riscv32 => "riscv32",
        .riscv32be => "riscv32be",
        .riscv64 => "riscv64",
        .riscv64be => "riscv64be",
        .sparc => "sparc",
        .sparc64 => "sparc64",
        .s390x => "s390x",
        .thumb => "thumb",
        .thumbeb => "thumbeb",
        .x86 => "i386",
        .x86_64 => "x86_64",
        .xcore => "xcore",
        .xtensa => "xtensa",
        .nvptx => "nvptx",
        .nvptx64 => "nvptx64",
        .spirv32 => switch (target.os.tag) {
            .vulkan, .opengl => "spirv",
            else => "spirv32",
        },
        .spirv64 => "spirv64",
        .lanai => "lanai",
        .wasm32 => "wasm32",
        .wasm64 => "wasm64",
        .ve => "ve",

        .kalimba,
        .or1k,
        .propeller,
        => unreachable, // Gated by hasLlvmSupport().
    };

    try llvm_triple.appendSlice(llvm_arch);

    const llvm_sub_arch: ?[]const u8 = switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => subArchName(target, .arm, .{
            .{ .v4t, "v4t" },
            .{ .v5t, "v5t" },
            .{ .v5te, "v5te" },
            .{ .v5tej, "v5tej" },
            .{ .v6, "v6" },
            .{ .v6k, "v6k" },
            .{ .v6kz, "v6kz" },
            .{ .v6m, "v6m" },
            .{ .v6t2, "v6t2" },
            .{ .v7a, "v7a" },
            .{ .v7em, "v7em" },
            .{ .v7m, "v7m" },
            .{ .v7r, "v7r" },
            .{ .v7ve, "v7ve" },
            .{ .v8a, "v8a" },
            .{ .v8_1a, "v8.1a" },
            .{ .v8_2a, "v8.2a" },
            .{ .v8_3a, "v8.3a" },
            .{ .v8_4a, "v8.4a" },
            .{ .v8_5a, "v8.5a" },
            .{ .v8_6a, "v8.6a" },
            .{ .v8_7a, "v8.7a" },
            .{ .v8_8a, "v8.8a" },
            .{ .v8_9a, "v8.9a" },
            .{ .v8m, "v8m.base" },
            .{ .v8m_main, "v8m.main" },
            .{ .v8_1m_main, "v8.1m.main" },
            .{ .v8r, "v8r" },
            .{ .v9a, "v9a" },
            .{ .v9_1a, "v9.1a" },
            .{ .v9_2a, "v9.2a" },
            .{ .v9_3a, "v9.3a" },
            .{ .v9_4a, "v9.4a" },
            .{ .v9_5a, "v9.5a" },
            .{ .v9_6a, "v9.6a" },
        }),
        .powerpc => subArchName(target, .powerpc, .{
            .{ .spe, "spe" },
        }),
        .spirv32, .spirv64 => subArchName(target, .spirv, .{
            .{ .v1_5, "1.5" },
            .{ .v1_4, "1.4" },
            .{ .v1_3, "1.3" },
            .{ .v1_2, "1.2" },
            .{ .v1_1, "1.1" },
        }),
        else => null,
    };

    if (llvm_sub_arch) |sub| try llvm_triple.appendSlice(sub);
    try llvm_triple.append('-');

    try llvm_triple.appendSlice(switch (target.os.tag) {
        .aix,
        .zos,
        => "ibm",
        .driverkit,
        .ios,
        .macos,
        .tvos,
        .visionos,
        .watchos,
        => "apple",
        .ps4,
        .ps5,
        => "scei",
        .amdhsa,
        .amdpal,
        => "amd",
        .cuda,
        .nvcl,
        => "nvidia",
        .mesa3d,
        => "mesa",
        else => "unknown",
    });
    try llvm_triple.append('-');

    const llvm_os = switch (target.os.tag) {
        .freestanding => "unknown",
        .dragonfly => "dragonfly",
        .freebsd => "freebsd",
        .fuchsia => "fuchsia",
        .linux => "linux",
        .netbsd => "netbsd",
        .openbsd => "openbsd",
        .solaris, .illumos => "solaris",
        .windows, .uefi => "windows",
        .zos => "zos",
        .haiku => "haiku",
        .rtems => "rtems",
        .aix => "aix",
        .cuda => "cuda",
        .nvcl => "nvcl",
        .amdhsa => "amdhsa",
        .opencl => "unknown", // https://llvm.org/docs/SPIRVUsage.html#target-triples
        .ps3 => "lv2",
        .ps4 => "ps4",
        .ps5 => "ps5",
        .vita => "unknown", // LLVM doesn't know about this target
        .mesa3d => "mesa3d",
        .amdpal => "amdpal",
        .hermit => "hermit",
        .hurd => "hurd",
        .wasi => "wasi",
        .emscripten => "emscripten",
        .macos => "macosx",
        .ios => "ios",
        .tvos => "tvos",
        .watchos => "watchos",
        .driverkit => "driverkit",
        .visionos => "xros",
        .serenity => "serenity",
        .vulkan => "vulkan",
        .managarm => "managarm",

        .@"3ds",
        .opengl,
        .plan9,
        .contiki,
        .other,
        => "unknown",
    };
    try llvm_triple.appendSlice(llvm_os);

    switch (target.os.versionRange()) {
        .none,
        .windows,
        => {},
        .semver => |ver| try llvm_triple.print("{d}.{d}.{d}", .{
            ver.min.major,
            ver.min.minor,
            ver.min.patch,
        }),
        inline .linux, .hurd => |ver| try llvm_triple.print("{d}.{d}.{d}", .{
            ver.range.min.major,
            ver.range.min.minor,
            ver.range.min.patch,
        }),
    }
    try llvm_triple.append('-');

    const llvm_abi = switch (target.abi) {
        .none, .ilp32 => "unknown",
        .gnu => "gnu",
        .gnuabin32 => "gnuabin32",
        .gnuabi64 => "gnuabi64",
        .gnueabi => "gnueabi",
        .gnueabihf => "gnueabihf",
        .gnuf32 => "gnuf32",
        .gnusf => "gnusf",
        .gnux32 => "gnux32",
        .code16 => "code16",
        .eabi => "eabi",
        .eabihf => "eabihf",
        .android => "android",
        .androideabi => "androideabi",
        .musl => switch (target.os.tag) {
            // For WASI/Emscripten, "musl" refers to the libc, not really the ABI.
            // "unknown" provides better compatibility with LLVM-based tooling for these targets.
            .wasi, .emscripten => "unknown",
            else => "musl",
        },
        .muslabin32 => "muslabin32",
        .muslabi64 => "muslabi64",
        .musleabi => "musleabi",
        .musleabihf => "musleabihf",
        .muslf32 => "muslf32",
        .muslsf => "muslsf",
        .muslx32 => "muslx32",
        .msvc => "msvc",
        .itanium => "itanium",
        .cygnus => "cygnus",
        .simulator => "simulator",
        .macabi => "macabi",
        .ohos, .ohoseabi => "ohos",
    };
    try llvm_triple.appendSlice(llvm_abi);

    switch (target.os.versionRange()) {
        .none,
        .semver,
        .windows,
        => {},
        inline .hurd, .linux => |ver| if (target.abi.isGnu()) {
            try llvm_triple.print("{d}.{d}.{d}", .{
                ver.glibc.major,
                ver.glibc.minor,
                ver.glibc.patch,
            });
        } else if (@TypeOf(ver) == std.Target.Os.LinuxVersionRange and target.abi.isAndroid()) {
            try llvm_triple.print("{d}", .{ver.android});
        },
    }

    return llvm_triple.toOwnedSlice();
}

pub fn supportsTailCall(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => target.cpu.has(.wasm, .tail_call),
        // Although these ISAs support tail calls, LLVM does not support tail calls on them.
        .mips, .mipsel, .mips64, .mips64el => false,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => false,
        else => true,
    };
}

pub fn dataLayout(target: *const std.Target) []const u8 {
    // These data layouts should match Clang.
    return switch (target.cpu.arch) {
        .arc => "e-m:e-p:32:32-i1:8:32-i8:8:32-i16:16:32-i32:32:32-f32:32:32-i64:32-f64:32-a:0:32-n32",
        .xcore => "e-m:e-p:32:32-i1:8:32-i8:8:32-i16:16:32-i64:32-f64:32-a:0:32-n32",
        .hexagon => "e-m:e-p:32:32:32-a:0-n16:32-i64:64:64-i32:32:32-i16:16:16-i1:8:8-f32:32:32-f64:64:64-v32:32:32-v64:64:64-v512:512:512-v1024:1024:1024-v2048:2048:2048",
        .lanai => "E-m:e-p:32:32-i64:64-a:0:32-n32-S64",
        .aarch64 => if (target.ofmt == .macho)
            if (target.os.tag == .windows)
                "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
            else if (target.abi == .ilp32)
                "e-m:o-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
            else
                "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
        else if (target.os.tag == .windows)
            "e-m:w-p270:32:32-p271:32:32-p272:64:64-p:64:64-i32:32-i64:64-i128:128-n32:64-S128-Fn32"
        else
            "e-m:e-p270:32:32-p271:32:32-p272:64:64-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128-Fn32",
        .aarch64_be => "E-m:e-p270:32:32-p271:32:32-p272:64:64-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128-Fn32",
        .arm => if (target.ofmt == .macho)
            "e-m:o-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
        else
            "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64",
        .armeb, .thumbeb => if (target.ofmt == .macho)
            "E-m:o-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
        else
            "E-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64",
        .thumb => if (target.ofmt == .macho)
            "e-m:o-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
        else if (target.os.tag == .windows)
            "e-m:w-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64"
        else
            "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64",
        .avr => "e-P1-p:16:8-i8:8-i16:8-i32:8-i64:8-f32:8-f64:8-n8-a:8",
        .bpfeb => "E-m:e-p:64:64-i64:64-i128:128-n32:64-S128",
        .bpfel => "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128",
        .msp430 => "e-m:e-p:16:16-i32:16-i64:16-f32:16-f64:16-a:8-n8:16-S16",
        .mips => "E-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32-S64",
        .mipsel => "e-m:m-p:32:32-i8:8:32-i16:16:32-i64:64-n32-S64",
        .mips64 => switch (target.abi) {
            .gnuabin32, .muslabin32 => "E-m:e-p:32:32-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128",
            else => "E-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128",
        },
        .mips64el => switch (target.abi) {
            .gnuabin32, .muslabin32 => "e-m:e-p:32:32-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128",
            else => "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128",
        },
        .m68k => "E-m:e-p:32:16:32-i8:8:8-i16:16:16-i32:16:32-n8:16:32-a:0:16-S16",
        .powerpc => if (target.os.tag == .aix)
            "E-m:a-p:32:32-Fi32-i64:64-n32"
        else
            "E-m:e-p:32:32-Fn32-i64:64-n32",
        .powerpcle => "e-m:e-p:32:32-Fn32-i64:64-n32",
        .powerpc64 => switch (target.os.tag) {
            .aix => "E-m:a-Fi64-i64:64-i128:128-n32:64-S128-v256:256:256-v512:512:512",
            .linux => if (target.abi.isMusl())
                "E-m:e-Fn32-i64:64-i128:128-n32:64-S128-v256:256:256-v512:512:512"
            else
                "E-m:e-Fi64-i64:64-i128:128-n32:64-S128-v256:256:256-v512:512:512",
            .ps3 => "E-m:e-p:32:32-Fi64-i64:64-i128:128-n32:64",
            else => if (target.os.tag == .openbsd or
                (target.os.tag == .freebsd and target.os.version_range.semver.isAtLeast(.{ .major = 13, .minor = 0, .patch = 0 }) orelse false))
                "E-m:e-Fn32-i64:64-i128:128-n32:64"
            else
                "E-m:e-Fi64-i64:64-i128:128-n32:64",
        },
        .powerpc64le => if (target.os.tag == .linux)
            "e-m:e-Fn32-i64:64-i128:128-n32:64-S128-v256:256:256-v512:512:512"
        else
            "e-m:e-Fn32-i64:64-i128:128-n32:64",
        .nvptx => "e-p:32:32-p6:32:32-p7:32:32-i64:64-i128:128-v16:16-v32:32-n16:32:64",
        .nvptx64 => "e-p6:32:32-i64:64-i128:128-v16:16-v32:32-n16:32:64",
        .amdgcn => "e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9",
        .riscv32 => if (target.cpu.has(.riscv, .e))
            "e-m:e-p:32:32-i64:64-n32-S32"
        else
            "e-m:e-p:32:32-i64:64-n32-S128",
        .riscv32be => if (target.cpu.has(.riscv, .e))
            "E-m:e-p:32:32-i64:64-n32-S32"
        else
            "E-m:e-p:32:32-i64:64-n32-S128",
        .riscv64 => if (target.cpu.has(.riscv, .e))
            "e-m:e-p:64:64-i64:64-i128:128-n32:64-S64"
        else
            "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128",
        .riscv64be => if (target.cpu.has(.riscv, .e))
            "E-m:e-p:64:64-i64:64-i128:128-n32:64-S64"
        else
            "E-m:e-p:64:64-i64:64-i128:128-n32:64-S128",
        .sparc => "E-m:e-p:32:32-i64:64-i128:128-f128:64-n32-S64",
        .sparc64 => "E-m:e-i64:64-i128:128-n32:64-S128",
        .s390x => if (target.os.tag == .zos)
            "E-m:l-p1:32:32-i1:8:16-i8:8:16-i64:64-f128:64-v128:64-a:8:16-n32:64"
        else
            "E-m:e-i1:8:16-i8:8:16-i64:64-f128:64-v128:64-a:8:16-n32:64",
        .x86 => if (target.os.tag == .windows) switch (target.abi) {
            .cygnus => "e-m:x-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:32-n8:16:32-a:0:32-S32",
            .gnu => if (target.ofmt == .coff)
                "e-m:x-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:32-n8:16:32-a:0:32-S32"
            else
                "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:32-n8:16:32-a:0:32-S32",
            else => blk: {
                const msvc = switch (target.abi) {
                    .none, .msvc => true,
                    else => false,
                };

                break :blk if (target.ofmt == .coff)
                    if (msvc)
                        "e-m:x-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32-a:0:32-S32"
                    else
                        "e-m:x-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:32-n8:16:32-a:0:32-S32"
                else if (msvc)
                    "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32-a:0:32-S32"
                else
                    "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:32-n8:16:32-a:0:32-S32";
            },
        } else if (target.ofmt == .macho)
            "e-m:o-p:32:32-p270:32:32-p271:32:32-p272:64:64-i128:128-f64:32:64-f80:32-n8:16:32-S128"
        else
            "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i128:128-f64:32:64-f80:32-n8:16:32-S128",
        .x86_64 => if (target.os.tag.isDarwin() or target.ofmt == .macho)
            "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
        else switch (target.abi) {
            .gnux32, .muslx32 => "e-m:e-p:32:32-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128",
            else => if (target.os.tag == .windows and target.ofmt == .coff)
                "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
            else
                "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128",
        },
        .spirv32 => switch (target.os.tag) {
            .vulkan, .opengl => "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1",
            else => "e-p:32:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1",
        },
        .spirv64 => "e-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-G1",
        .wasm32 => if (target.os.tag == .emscripten)
            "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-i128:128-f128:64-n32:64-S128-ni:1:10:20"
        else
            "e-m:e-p:32:32-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20",
        .wasm64 => if (target.os.tag == .emscripten)
            "e-m:e-p:64:64-p10:8:8-p20:8:8-i64:64-i128:128-f128:64-n32:64-S128-ni:1:10:20"
        else
            "e-m:e-p:64:64-p10:8:8-p20:8:8-i64:64-i128:128-n32:64-S128-ni:1:10:20",
        .ve => "e-m:e-i64:64-n32:64-S128-v64:64:64-v128:64:64-v256:64:64-v512:64:64-v1024:64:64-v2048:64:64-v4096:64:64-v8192:64:64-v16384:64:64",
        .csky => "e-m:e-S32-p:32:32-i32:32:32-i64:32:32-f32:32:32-f64:32:32-v64:32:32-v128:32:32-a:0:32-Fi32-n32",
        .loongarch32 => "e-m:e-p:32:32-i64:64-n32-S128",
        .loongarch64 => "e-m:e-p:64:64-i64:64-i128:128-n32:64-S128",
        .xtensa => "e-m:e-p:32:32-i8:8:32-i16:16:32-i64:64-n32",

        .kalimba,
        .or1k,
        .propeller,
        => unreachable, // Gated by hasLlvmSupport().
    };
}

// Avoid depending on `llvm.CodeModel` in the bitcode-only case.
const CodeModel = enum {
    default,
    tiny,
    small,
    kernel,
    medium,
    large,
};

fn codeModel(model: std.builtin.CodeModel, target: *const std.Target) CodeModel {
    // Roughly match Clang's mapping of GCC code models to LLVM code models.
    return switch (model) {
        .default => .default,
        .extreme, .large => .large,
        .kernel => .kernel,
        .medany => if (target.cpu.arch.isRISCV()) .medium else .large,
        .medium => if (target.os.tag == .aix) .large else .medium,
        .medmid => .medium,
        .normal, .medlow, .small => .small,
        .tiny => .tiny,
    };
}

pub const Object = struct {
    gpa: Allocator,
    builder: Builder,

    debug_compile_unit: Builder.Metadata,

    debug_enums_fwd_ref: Builder.Metadata,
    debug_globals_fwd_ref: Builder.Metadata,

    debug_enums: std.ArrayListUnmanaged(Builder.Metadata),
    debug_globals: std.ArrayListUnmanaged(Builder.Metadata),

    debug_file_map: std.AutoHashMapUnmanaged(Zcu.File.Index, Builder.Metadata),
    debug_type_map: std.AutoHashMapUnmanaged(Type, Builder.Metadata),

    debug_unresolved_namespace_scopes: std.AutoArrayHashMapUnmanaged(InternPool.NamespaceIndex, Builder.Metadata),

    target: *const std.Target,
    /// Ideally we would use `llvm_module.getNamedFunction` to go from *Decl to LLVM function,
    /// but that has some downsides:
    /// * we have to compute the fully qualified name every time we want to do the lookup
    /// * for externally linked functions, the name is not fully qualified, but when
    ///   a Decl goes from exported to not exported and vice-versa, we would use the wrong
    ///   version of the name and incorrectly get function not found in the llvm module.
    /// * it works for functions not all globals.
    /// Therefore, this table keeps track of the mapping.
    nav_map: std.AutoHashMapUnmanaged(InternPool.Nav.Index, Builder.Global.Index),
    /// Same deal as `decl_map` but for anonymous declarations, which are always global constants.
    uav_map: std.AutoHashMapUnmanaged(InternPool.Index, Builder.Global.Index),
    /// Maps enum types to their corresponding LLVM functions for implementing the `tag_name` instruction.
    enum_tag_name_map: std.AutoHashMapUnmanaged(InternPool.Index, Builder.Global.Index),
    /// Serves the same purpose as `enum_tag_name_map` but for the `is_named_enum_value` instruction.
    named_enum_map: std.AutoHashMapUnmanaged(InternPool.Index, Builder.Function.Index),
    /// Maps Zig types to LLVM types. The table memory is backed by the GPA of
    /// the compiler.
    /// TODO when InternPool garbage collection is implemented, this map needs
    /// to be garbage collected as well.
    type_map: TypeMap,
    /// The LLVM global table which holds the names corresponding to Zig errors.
    /// Note that the values are not added until `emit`, when all errors in
    /// the compilation are known.
    error_name_table: Builder.Variable.Index,

    /// Memoizes a null `?usize` value.
    null_opt_usize: Builder.Constant,

    /// When an LLVM struct type is created, an entry is inserted into this
    /// table for every zig source field of the struct that has a corresponding
    /// LLVM struct field. comptime fields are not included. Zero-bit fields are
    /// mapped to a field at the correct byte, which may be a padding field, or
    /// are not mapped, in which case they are semantically at the end of the
    /// struct.
    /// The value is the LLVM struct field index.
    /// This is denormalized data.
    struct_field_map: std.AutoHashMapUnmanaged(ZigStructField, c_uint),

    /// Values for `@llvm.used`.
    used: std.ArrayListUnmanaged(Builder.Constant),

    const ZigStructField = struct {
        struct_ty: InternPool.Index,
        field_index: u32,
    };

    pub const Ptr = if (dev.env.supports(.llvm_backend)) *Object else noreturn;

    pub const TypeMap = std.AutoHashMapUnmanaged(InternPool.Index, Builder.Type);

    pub fn create(arena: Allocator, comp: *Compilation) !Ptr {
        dev.check(.llvm_backend);
        const gpa = comp.gpa;
        const target = &comp.root_mod.resolved_target.result;
        const llvm_target_triple = try targetTriple(arena, target);

        var builder = try Builder.init(.{
            .allocator = gpa,
            .strip = comp.config.debug_format == .strip,
            .name = comp.root_name,
            .target = target,
            .triple = llvm_target_triple,
        });
        errdefer builder.deinit();

        builder.data_layout = try builder.string(dataLayout(target));

        const debug_compile_unit, const debug_enums_fwd_ref, const debug_globals_fwd_ref =
            if (!builder.strip) debug_info: {
                // We fully resolve all paths at this point to avoid lack of
                // source line info in stack traces or lack of debugging
                // information which, if relative paths were used, would be
                // very location dependent.
                // TODO: the only concern I have with this is WASI as either host or target, should
                // we leave the paths as relative then?
                // TODO: This is totally wrong. In dwarf, paths are encoded as relative to
                // a particular directory, and then the directory path is specified elsewhere.
                // In the compiler frontend we have it stored correctly in this
                // way already, but here we throw all that sweet information
                // into the garbage can by converting into absolute paths. What
                // a terrible tragedy.
                const compile_unit_dir = blk: {
                    const zcu = comp.zcu orelse break :blk comp.dirs.cwd;
                    break :blk try zcu.main_mod.root.toAbsolute(comp.dirs, arena);
                };

                const debug_file = try builder.debugFile(
                    try builder.metadataString(comp.root_name),
                    try builder.metadataString(compile_unit_dir),
                );

                const debug_enums_fwd_ref = try builder.debugForwardReference();
                const debug_globals_fwd_ref = try builder.debugForwardReference();

                const debug_compile_unit = try builder.debugCompileUnit(
                    debug_file,
                    // Don't use the version string here; LLVM misparses it when it
                    // includes the git revision.
                    try builder.metadataStringFmt("zig {d}.{d}.{d}", .{
                        build_options.semver.major,
                        build_options.semver.minor,
                        build_options.semver.patch,
                    }),
                    debug_enums_fwd_ref,
                    debug_globals_fwd_ref,
                    .{ .optimized = comp.root_mod.optimize_mode != .Debug },
                );

                try builder.metadataNamed(try builder.metadataString("llvm.dbg.cu"), &.{debug_compile_unit});
                break :debug_info .{ debug_compile_unit, debug_enums_fwd_ref, debug_globals_fwd_ref };
            } else .{.none} ** 3;

        const obj = try arena.create(Object);
        obj.* = .{
            .gpa = gpa,
            .builder = builder,
            .debug_compile_unit = debug_compile_unit,
            .debug_enums_fwd_ref = debug_enums_fwd_ref,
            .debug_globals_fwd_ref = debug_globals_fwd_ref,
            .debug_enums = .{},
            .debug_globals = .{},
            .debug_file_map = .{},
            .debug_type_map = .{},
            .debug_unresolved_namespace_scopes = .{},
            .target = target,
            .nav_map = .{},
            .uav_map = .{},
            .enum_tag_name_map = .{},
            .named_enum_map = .{},
            .type_map = .{},
            .error_name_table = .none,
            .null_opt_usize = .no_init,
            .struct_field_map = .{},
            .used = .{},
        };
        return obj;
    }

    pub fn deinit(self: *Object) void {
        const gpa = self.gpa;
        self.debug_enums.deinit(gpa);
        self.debug_globals.deinit(gpa);
        self.debug_file_map.deinit(gpa);
        self.debug_type_map.deinit(gpa);
        self.debug_unresolved_namespace_scopes.deinit(gpa);
        self.nav_map.deinit(gpa);
        self.uav_map.deinit(gpa);
        self.enum_tag_name_map.deinit(gpa);
        self.named_enum_map.deinit(gpa);
        self.type_map.deinit(gpa);
        self.builder.deinit();
        self.struct_field_map.deinit(gpa);
        self.* = undefined;
    }

    fn genErrorNameTable(o: *Object, pt: Zcu.PerThread) Allocator.Error!void {
        // If o.error_name_table is null, then it was not referenced by any instructions.
        if (o.error_name_table == .none) return;

        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;

        const error_name_list = ip.global_error_set.getNamesFromMainThread();
        const llvm_errors = try zcu.gpa.alloc(Builder.Constant, 1 + error_name_list.len);
        defer zcu.gpa.free(llvm_errors);

        // TODO: Address space
        const slice_ty = Type.slice_const_u8_sentinel_0;
        const llvm_usize_ty = try o.lowerType(pt, Type.usize);
        const llvm_slice_ty = try o.lowerType(pt, slice_ty);
        const llvm_table_ty = try o.builder.arrayType(1 + error_name_list.len, llvm_slice_ty);

        llvm_errors[0] = try o.builder.undefConst(llvm_slice_ty);
        for (llvm_errors[1..], error_name_list) |*llvm_error, name| {
            const name_string = try o.builder.stringNull(name.toSlice(ip));
            const name_init = try o.builder.stringConst(name_string);
            const name_variable_index =
                try o.builder.addVariable(.empty, name_init.typeOf(&o.builder), .default);
            try name_variable_index.setInitializer(name_init, &o.builder);
            name_variable_index.setLinkage(.private, &o.builder);
            name_variable_index.setMutability(.constant, &o.builder);
            name_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
            name_variable_index.setAlignment(comptime Builder.Alignment.fromByteUnits(1), &o.builder);

            llvm_error.* = try o.builder.structConst(llvm_slice_ty, &.{
                name_variable_index.toConst(&o.builder),
                try o.builder.intConst(llvm_usize_ty, name_string.slice(&o.builder).?.len - 1),
            });
        }

        const table_variable_index = try o.builder.addVariable(.empty, llvm_table_ty, .default);
        try table_variable_index.setInitializer(
            try o.builder.arrayConst(llvm_table_ty, llvm_errors),
            &o.builder,
        );
        table_variable_index.setLinkage(.private, &o.builder);
        table_variable_index.setMutability(.constant, &o.builder);
        table_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        table_variable_index.setAlignment(
            slice_ty.abiAlignment(zcu).toLlvm(),
            &o.builder,
        );

        try o.error_name_table.setInitializer(table_variable_index.toConst(&o.builder), &o.builder);
    }

    fn genCmpLtErrorsLenFunction(o: *Object, pt: Zcu.PerThread) !void {
        // If there is no such function in the module, it means the source code does not need it.
        const name = o.builder.strtabStringIfExists(lt_errors_fn_name) orelse return;
        const llvm_fn = o.builder.getGlobal(name) orelse return;
        const errors_len = pt.zcu.intern_pool.global_error_set.getNamesFromMainThread().len;

        var wip = try Builder.WipFunction.init(&o.builder, .{
            .function = llvm_fn.ptrConst(&o.builder).kind.function,
            .strip = true,
        });
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        // Example source of the following LLVM IR:
        // fn __zig_lt_errors_len(index: u16) bool {
        //     return index <= total_errors_len;
        // }

        const lhs = wip.arg(0);
        const rhs = try o.builder.intValue(try o.errorIntType(pt), errors_len);
        const is_lt = try wip.icmp(.ule, lhs, rhs, "");
        _ = try wip.ret(is_lt);
        try wip.finish();
    }

    fn genModuleLevelAssembly(object: *Object, pt: Zcu.PerThread) Allocator.Error!void {
        const b = &object.builder;
        const gpa = b.gpa;
        b.module_asm.clearRetainingCapacity();
        for (pt.zcu.global_assembly.values()) |assembly| {
            try b.module_asm.ensureUnusedCapacity(gpa, assembly.len + 1);
            b.module_asm.appendSliceAssumeCapacity(assembly);
            b.module_asm.appendAssumeCapacity('\n');
        }
        if (b.module_asm.getLastOrNull()) |last| {
            if (last != '\n') try b.module_asm.append(gpa, '\n');
        }
    }

    pub const EmitOptions = struct {
        pre_ir_path: ?[]const u8,
        pre_bc_path: ?[]const u8,
        bin_path: ?[*:0]const u8,
        asm_path: ?[*:0]const u8,
        post_ir_path: ?[*:0]const u8,
        post_bc_path: ?[*:0]const u8,

        is_debug: bool,
        is_small: bool,
        time_report: ?*Compilation.TimeReport,
        sanitize_thread: bool,
        fuzz: bool,
        lto: std.zig.LtoMode,
    };

    pub fn emit(o: *Object, pt: Zcu.PerThread, options: EmitOptions) error{ LinkFailure, OutOfMemory }!void {
        const zcu = pt.zcu;
        const comp = zcu.comp;
        const diags = &comp.link_diags;

        {
            try o.genErrorNameTable(pt);
            try o.genCmpLtErrorsLenFunction(pt);
            try o.genModuleLevelAssembly(pt);

            if (o.used.items.len > 0) {
                const array_llvm_ty = try o.builder.arrayType(o.used.items.len, .ptr);
                const init_val = try o.builder.arrayConst(array_llvm_ty, o.used.items);
                const compiler_used_variable = try o.builder.addVariable(
                    try o.builder.strtabString("llvm.used"),
                    array_llvm_ty,
                    .default,
                );
                compiler_used_variable.setLinkage(.appending, &o.builder);
                compiler_used_variable.setSection(try o.builder.string("llvm.metadata"), &o.builder);
                try compiler_used_variable.setInitializer(init_val, &o.builder);
            }

            if (!o.builder.strip) {
                {
                    var i: usize = 0;
                    while (i < o.debug_unresolved_namespace_scopes.count()) : (i += 1) {
                        const namespace_index = o.debug_unresolved_namespace_scopes.keys()[i];
                        const fwd_ref = o.debug_unresolved_namespace_scopes.values()[i];

                        const namespace = zcu.namespacePtr(namespace_index);
                        const debug_type = try o.lowerDebugType(pt, Type.fromInterned(namespace.owner_type));

                        o.builder.debugForwardReferenceSetType(fwd_ref, debug_type);
                    }
                }

                o.builder.debugForwardReferenceSetType(
                    o.debug_enums_fwd_ref,
                    try o.builder.metadataTuple(o.debug_enums.items),
                );

                o.builder.debugForwardReferenceSetType(
                    o.debug_globals_fwd_ref,
                    try o.builder.metadataTuple(o.debug_globals.items),
                );
            }
        }

        {
            var module_flags = try std.array_list.Managed(Builder.Metadata).initCapacity(o.gpa, 8);
            defer module_flags.deinit();

            const behavior_error = try o.builder.metadataConstant(try o.builder.intConst(.i32, 1));
            const behavior_warning = try o.builder.metadataConstant(try o.builder.intConst(.i32, 2));
            const behavior_max = try o.builder.metadataConstant(try o.builder.intConst(.i32, 7));
            const behavior_min = try o.builder.metadataConstant(try o.builder.intConst(.i32, 8));

            if (target_util.llvmMachineAbi(&comp.root_mod.resolved_target.result)) |abi| {
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_error,
                    try o.builder.metadataString("target-abi"),
                    try o.builder.metadataConstant(
                        try o.builder.stringConst(try o.builder.string(abi)),
                    ),
                ));
            }

            const pic_level = target_util.picLevel(&comp.root_mod.resolved_target.result);
            if (comp.root_mod.pic) {
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_min,
                    try o.builder.metadataString("PIC Level"),
                    try o.builder.metadataConstant(try o.builder.intConst(.i32, pic_level)),
                ));
            }

            if (comp.config.pie) {
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_max,
                    try o.builder.metadataString("PIE Level"),
                    try o.builder.metadataConstant(try o.builder.intConst(.i32, pic_level)),
                ));
            }

            if (comp.root_mod.code_model != .default) {
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_error,
                    try o.builder.metadataString("Code Model"),
                    try o.builder.metadataConstant(try o.builder.intConst(.i32, @as(
                        i32,
                        switch (codeModel(comp.root_mod.code_model, &comp.root_mod.resolved_target.result)) {
                            .default => unreachable,
                            .tiny => 0,
                            .small => 1,
                            .kernel => 2,
                            .medium => 3,
                            .large => 4,
                        },
                    ))),
                ));
            }

            if (!o.builder.strip) {
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_warning,
                    try o.builder.metadataString("Debug Info Version"),
                    try o.builder.metadataConstant(try o.builder.intConst(.i32, 3)),
                ));

                switch (comp.config.debug_format) {
                    .strip => unreachable,
                    .dwarf => |f| {
                        module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                            behavior_max,
                            try o.builder.metadataString("Dwarf Version"),
                            try o.builder.metadataConstant(try o.builder.intConst(.i32, 4)),
                        ));

                        if (f == .@"64") {
                            module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                                behavior_max,
                                try o.builder.metadataString("DWARF64"),
                                try o.builder.metadataConstant(.@"1"),
                            ));
                        }
                    },
                    .code_view => {
                        module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                            behavior_warning,
                            try o.builder.metadataString("CodeView"),
                            try o.builder.metadataConstant(.@"1"),
                        ));
                    },
                }
            }

            const target = &comp.root_mod.resolved_target.result;
            if (target.os.tag == .windows and (target.cpu.arch == .x86_64 or target.cpu.arch == .x86)) {
                // Add the "RegCallv4" flag so that any functions using `x86_regcallcc` use regcall
                // v4, which is essentially a requirement on Windows. See corresponding logic in
                // `toLlvmCallConvTag`.
                module_flags.appendAssumeCapacity(try o.builder.metadataModuleFlag(
                    behavior_max,
                    try o.builder.metadataString("RegCallv4"),
                    try o.builder.metadataConstant(.@"1"),
                ));
            }

            try o.builder.metadataNamed(try o.builder.metadataString("llvm.module.flags"), module_flags.items);
        }

        const target_triple_sentinel =
            try o.gpa.dupeZ(u8, o.builder.target_triple.slice(&o.builder).?);
        defer o.gpa.free(target_triple_sentinel);

        const emit_asm_msg = options.asm_path orelse "(none)";
        const emit_bin_msg = options.bin_path orelse "(none)";
        const post_llvm_ir_msg = options.post_ir_path orelse "(none)";
        const post_llvm_bc_msg = options.post_bc_path orelse "(none)";
        log.debug("emit LLVM object asm={s} bin={s} ir={s} bc={s}", .{
            emit_asm_msg, emit_bin_msg, post_llvm_ir_msg, post_llvm_bc_msg,
        });

        const context, const module = emit: {
            if (options.pre_ir_path) |path| {
                if (std.mem.eql(u8, path, "-")) {
                    o.builder.dump();
                } else {
                    o.builder.printToFilePath(std.fs.cwd(), path) catch |err| {
                        log.err("failed printing LLVM module to \"{s}\": {s}", .{ path, @errorName(err) });
                    };
                }
            }

            const bitcode = try o.builder.toBitcode(o.gpa, .{
                .name = "zig",
                .version = build_options.semver,
            });
            defer o.gpa.free(bitcode);
            o.builder.clearAndFree();

            if (options.pre_bc_path) |path| {
                var file = std.fs.cwd().createFile(path, .{}) catch |err|
                    return diags.fail("failed to create '{s}': {s}", .{ path, @errorName(err) });
                defer file.close();

                const ptr: [*]const u8 = @ptrCast(bitcode.ptr);
                file.writeAll(ptr[0..(bitcode.len * 4)]) catch |err|
                    return diags.fail("failed to write to '{s}': {s}", .{ path, @errorName(err) });
            }

            if (options.asm_path == null and options.bin_path == null and
                options.post_ir_path == null and options.post_bc_path == null) return;

            if (options.post_bc_path) |path| {
                var file = std.fs.cwd().createFileZ(path, .{}) catch |err|
                    return diags.fail("failed to create '{s}': {s}", .{ path, @errorName(err) });
                defer file.close();

                const ptr: [*]const u8 = @ptrCast(bitcode.ptr);
                file.writeAll(ptr[0..(bitcode.len * 4)]) catch |err|
                    return diags.fail("failed to write to '{s}': {s}", .{ path, @errorName(err) });
            }

            if (!build_options.have_llvm or !comp.config.use_lib_llvm) {
                return diags.fail("emitting without libllvm not implemented", .{});
            }

            initializeLLVMTarget(comp.root_mod.resolved_target.result.cpu.arch);

            const context: *llvm.Context = llvm.Context.create();
            errdefer context.dispose();

            const bitcode_memory_buffer = llvm.MemoryBuffer.createMemoryBufferWithMemoryRange(
                @ptrCast(bitcode.ptr),
                bitcode.len * 4,
                "BitcodeBuffer",
                llvm.Bool.False,
            );
            defer bitcode_memory_buffer.dispose();

            context.enableBrokenDebugInfoCheck();

            var module: *llvm.Module = undefined;
            if (context.parseBitcodeInContext2(bitcode_memory_buffer, &module).toBool() or context.getBrokenDebugInfo()) {
                return diags.fail("Failed to parse bitcode", .{});
            }
            break :emit .{ context, module };
        };
        defer context.dispose();

        var target: *llvm.Target = undefined;
        var error_message: [*:0]const u8 = undefined;
        if (llvm.Target.getFromTriple(target_triple_sentinel, &target, &error_message).toBool()) {
            defer llvm.disposeMessage(error_message);
            return diags.fail("LLVM failed to parse '{s}': {s}", .{ target_triple_sentinel, error_message });
        }

        const optimize_mode = comp.root_mod.optimize_mode;

        const opt_level: llvm.CodeGenOptLevel = if (optimize_mode == .Debug)
            .None
        else
            .Aggressive;

        const reloc_mode: llvm.RelocMode = if (comp.root_mod.pic)
            .PIC
        else if (comp.config.link_mode == .dynamic)
            llvm.RelocMode.DynamicNoPIC
        else
            .Static;

        const code_model: llvm.CodeModel = switch (codeModel(comp.root_mod.code_model, &comp.root_mod.resolved_target.result)) {
            .default => .Default,
            .tiny => .Tiny,
            .small => .Small,
            .kernel => .Kernel,
            .medium => .Medium,
            .large => .Large,
        };

        const float_abi: llvm.TargetMachine.FloatABI = if (comp.root_mod.resolved_target.result.abi.float() == .hard)
            .Hard
        else
            .Soft;

        var target_machine = llvm.TargetMachine.create(
            target,
            target_triple_sentinel,
            if (comp.root_mod.resolved_target.result.cpu.model.llvm_name) |s| s.ptr else null,
            comp.root_mod.resolved_target.llvm_cpu_features.?,
            opt_level,
            reloc_mode,
            code_model,
            comp.function_sections,
            comp.data_sections,
            float_abi,
            if (target_util.llvmMachineAbi(&comp.root_mod.resolved_target.result)) |s| s.ptr else null,
            target_util.useEmulatedTls(&comp.root_mod.resolved_target.result),
        );
        errdefer target_machine.dispose();

        if (comp.llvm_opt_bisect_limit >= 0) {
            context.setOptBisectLimit(comp.llvm_opt_bisect_limit);
        }

        // Unfortunately, LLVM shits the bed when we ask for both binary and assembly.
        // So we call the entire pipeline multiple times if this is requested.
        // var error_message: [*:0]const u8 = undefined;
        var lowered_options: llvm.TargetMachine.EmitOptions = .{
            .is_debug = options.is_debug,
            .is_small = options.is_small,
            .time_report_out = null, // set below to make sure it's only set for a single `emitToFile`
            .tsan = options.sanitize_thread,
            .lto = switch (options.lto) {
                .none => .None,
                .thin => .ThinPreLink,
                .full => .FullPreLink,
            },
            .allow_fast_isel = true,
            // LLVM's RISC-V backend for some reason enables the machine outliner by default even
            // though it's clearly not ready and produces multiple miscompilations in our std tests.
            .allow_machine_outliner = !comp.root_mod.resolved_target.result.cpu.arch.isRISCV(),
            .asm_filename = null,
            .bin_filename = options.bin_path,
            .llvm_ir_filename = options.post_ir_path,
            .bitcode_filename = null,

            // `.coverage` value is only used when `.sancov` is enabled.
            .sancov = options.fuzz or comp.config.san_cov_trace_pc_guard,
            .coverage = .{
                .CoverageType = .Edge,
                // Works in tandem with Inline8bitCounters or InlineBoolFlag.
                // Zig does not yet implement its own version of this but it
                // needs to for better fuzzing logic.
                .IndirectCalls = false,
                .TraceBB = false,
                .TraceCmp = options.fuzz,
                .TraceDiv = false,
                .TraceGep = false,
                .Use8bitCounters = false,
                .TracePC = false,
                .TracePCGuard = comp.config.san_cov_trace_pc_guard,
                // Zig emits its own inline 8-bit counters instrumentation.
                .Inline8bitCounters = false,
                .InlineBoolFlag = false,
                // Zig emits its own PC table instrumentation.
                .PCTable = false,
                .NoPrune = false,
                // Workaround for https://github.com/llvm/llvm-project/pull/106464
                .StackDepth = true,
                .TraceLoads = false,
                .TraceStores = false,
                .CollectControlFlow = false,
            },
        };
        if (options.asm_path != null and options.bin_path != null) {
            if (target_machine.emitToFile(module, &error_message, &lowered_options)) {
                defer llvm.disposeMessage(error_message);
                return diags.fail("LLVM failed to emit bin={s} ir={s}: {s}", .{
                    emit_bin_msg, post_llvm_ir_msg, error_message,
                });
            }
            lowered_options.bin_filename = null;
            lowered_options.llvm_ir_filename = null;
        }

        var time_report_c_str: [*:0]u8 = undefined;
        if (options.time_report != null) {
            lowered_options.time_report_out = &time_report_c_str;
        }

        lowered_options.asm_filename = options.asm_path;
        if (target_machine.emitToFile(module, &error_message, &lowered_options)) {
            defer llvm.disposeMessage(error_message);
            return diags.fail("LLVM failed to emit asm={s} bin={s} ir={s} bc={s}: {s}", .{
                emit_asm_msg, emit_bin_msg, post_llvm_ir_msg, post_llvm_bc_msg, error_message,
            });
        }
        if (options.time_report) |tr| {
            defer std.c.free(time_report_c_str);
            const time_report_data = std.mem.span(time_report_c_str);
            assert(tr.llvm_pass_timings.len == 0);
            tr.llvm_pass_timings = try comp.gpa.dupe(u8, time_report_data);
        }
    }

    pub fn updateFunc(
        o: *Object,
        pt: Zcu.PerThread,
        func_index: InternPool.Index,
        air: *const Air,
        liveness: *const ?Air.Liveness,
    ) !void {
        const zcu = pt.zcu;
        const comp = zcu.comp;
        const ip = &zcu.intern_pool;
        const func = zcu.funcInfo(func_index);
        const nav = ip.getNav(func.owner_nav);
        const file_scope = zcu.navFileScopeIndex(func.owner_nav);
        const owner_mod = zcu.fileByIndex(file_scope).mod.?;
        const fn_ty = Type.fromInterned(func.ty);
        const fn_info = zcu.typeToFunc(fn_ty).?;
        const target = &owner_mod.resolved_target.result;

        var ng: NavGen = .{
            .object = o,
            .nav_index = func.owner_nav,
            .pt = pt,
            .err_msg = null,
        };

        const function_index = try o.resolveLlvmFunction(pt, func.owner_nav);

        var attributes = try function_index.ptrConst(&o.builder).attributes.toWip(&o.builder);
        defer attributes.deinit(&o.builder);

        const func_analysis = func.analysisUnordered(ip);
        if (func_analysis.is_noinline) {
            try attributes.addFnAttr(.@"noinline", &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.@"noinline");
        }

        if (func_analysis.branch_hint == .cold) {
            try attributes.addFnAttr(.cold, &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.cold);
        }

        if (owner_mod.sanitize_thread and !func_analysis.disable_instrumentation) {
            try attributes.addFnAttr(.sanitize_thread, &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.sanitize_thread);
        }
        const is_naked = fn_info.cc == .naked;
        if (!func_analysis.disable_instrumentation and !is_naked) {
            if (owner_mod.fuzz) {
                try attributes.addFnAttr(.optforfuzzing, &o.builder);
            }
            _ = try attributes.removeFnAttr(.skipprofile);
            _ = try attributes.removeFnAttr(.nosanitize_coverage);
        } else {
            _ = try attributes.removeFnAttr(.optforfuzzing);
            try attributes.addFnAttr(.skipprofile, &o.builder);
            try attributes.addFnAttr(.nosanitize_coverage, &o.builder);
        }

        const disable_intrinsics = func_analysis.disable_intrinsics or owner_mod.no_builtin;
        if (disable_intrinsics) {
            // The intent here is for compiler-rt and libc functions to not generate
            // infinite recursion. For example, if we are compiling the memcpy function,
            // and llvm detects that the body is equivalent to memcpy, it may replace the
            // body of memcpy with a call to memcpy, which would then cause a stack
            // overflow instead of performing memcpy.
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("no-builtins"),
                .value = .empty,
            } }, &o.builder);
        }

        // TODO: disable this if safety is off for the function scope
        const ssp_buf_size = owner_mod.stack_protector;
        if (ssp_buf_size != 0) {
            try attributes.addFnAttr(.sspstrong, &o.builder);
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("stack-protector-buffer-size"),
                .value = try o.builder.fmt("{d}", .{ssp_buf_size}),
            } }, &o.builder);
        }

        // TODO: disable this if safety is off for the function scope
        if (owner_mod.stack_check) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("probe-stack"),
                .value = try o.builder.string("__zig_probe_stack"),
            } }, &o.builder);
        } else if (target.os.tag == .uefi) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("no-stack-arg-probe"),
                .value = .empty,
            } }, &o.builder);
        }

        if (nav.status.fully_resolved.@"linksection".toSlice(ip)) |section|
            function_index.setSection(try o.builder.string(section), &o.builder);

        var deinit_wip = true;
        var wip = try Builder.WipFunction.init(&o.builder, .{
            .function = function_index,
            .strip = owner_mod.strip,
        });
        defer if (deinit_wip) wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        var llvm_arg_i: u32 = 0;

        // This gets the LLVM values from the function and stores them in `ng.args`.
        const sret = firstParamSRet(fn_info, zcu, target);
        const ret_ptr: Builder.Value = if (sret) param: {
            const param = wip.arg(llvm_arg_i);
            llvm_arg_i += 1;
            break :param param;
        } else .none;

        if (ccAbiPromoteInt(fn_info.cc, zcu, Type.fromInterned(fn_info.return_type))) |s| switch (s) {
            .signed => try attributes.addRetAttr(.signext, &o.builder),
            .unsigned => try attributes.addRetAttr(.zeroext, &o.builder),
        };

        const err_return_tracing = fn_info.cc == .auto and comp.config.any_error_tracing;

        const err_ret_trace: Builder.Value = if (err_return_tracing) param: {
            const param = wip.arg(llvm_arg_i);
            llvm_arg_i += 1;
            break :param param;
        } else .none;

        // This is the list of args we will use that correspond directly to the AIR arg
        // instructions. Depending on the calling convention, this list is not necessarily
        // a bijection with the actual LLVM parameters of the function.
        const gpa = o.gpa;
        var args: std.ArrayListUnmanaged(Builder.Value) = .empty;
        defer args.deinit(gpa);

        {
            var it = iterateParamTypes(o, pt, fn_info);
            while (try it.next()) |lowering| {
                try args.ensureUnusedCapacity(gpa, 1);

                switch (lowering) {
                    .no_bits => continue,
                    .byval => {
                        assert(!it.byval_attr);
                        const param_index = it.zig_index - 1;
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                        const param = wip.arg(llvm_arg_i);

                        if (isByRef(param_ty, zcu)) {
                            const alignment = param_ty.abiAlignment(zcu).toLlvm();
                            const param_llvm_ty = param.typeOfWip(&wip);
                            const arg_ptr = try buildAllocaInner(&wip, param_llvm_ty, alignment, target);
                            _ = try wip.store(.normal, param, arg_ptr, alignment);
                            args.appendAssumeCapacity(arg_ptr);
                        } else {
                            args.appendAssumeCapacity(param);

                            try o.addByValParamAttrs(pt, &attributes, param_ty, param_index, fn_info, llvm_arg_i);
                        }
                        llvm_arg_i += 1;
                    },
                    .byref => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const param = wip.arg(llvm_arg_i);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();

                        try o.addByRefParamAttrs(&attributes, llvm_arg_i, alignment, it.byval_attr, param_llvm_ty);
                        llvm_arg_i += 1;

                        if (isByRef(param_ty, zcu)) {
                            args.appendAssumeCapacity(param);
                        } else {
                            args.appendAssumeCapacity(try wip.load(.normal, param_llvm_ty, param, alignment, ""));
                        }
                    },
                    .byref_mut => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const param = wip.arg(llvm_arg_i);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();

                        try attributes.addParamAttr(llvm_arg_i, .noundef, &o.builder);
                        llvm_arg_i += 1;

                        if (isByRef(param_ty, zcu)) {
                            args.appendAssumeCapacity(param);
                        } else {
                            args.appendAssumeCapacity(try wip.load(.normal, param_llvm_ty, param, alignment, ""));
                        }
                    },
                    .abi_sized_int => {
                        assert(!it.byval_attr);
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, param_llvm_ty, alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                    .slice => {
                        assert(!it.byval_attr);
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const ptr_info = param_ty.ptrInfo(zcu);

                        if (math.cast(u5, it.zig_index - 1)) |i| {
                            if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                                try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                            }
                        }
                        if (param_ty.zigTypeTag(zcu) != .optional and
                            !ptr_info.flags.is_allowzero and
                            ptr_info.flags.address_space == .generic)
                        {
                            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
                        }
                        if (ptr_info.flags.is_const) {
                            try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
                        }
                        const elem_align = (if (ptr_info.flags.alignment != .none)
                            @as(InternPool.Alignment, ptr_info.flags.alignment)
                        else
                            Type.fromInterned(ptr_info.child).abiAlignment(zcu).max(.@"1")).toLlvm();
                        try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align }, &o.builder);
                        const ptr_param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;
                        const len_param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const slice_llvm_ty = try o.lowerType(pt, param_ty);
                        args.appendAssumeCapacity(
                            try wip.buildAggregate(slice_llvm_ty, &.{ ptr_param, len_param }, ""),
                        );
                    },
                    .multiple_llvm_types => {
                        assert(!it.byval_attr);
                        const field_types = it.types_buffer[0..it.types_len];
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const param_alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, param_llvm_ty, param_alignment, target);
                        const llvm_ty = try o.builder.structType(.normal, field_types);
                        for (0..field_types.len) |field_i| {
                            const param = wip.arg(llvm_arg_i);
                            llvm_arg_i += 1;
                            const field_ptr = try wip.gepStruct(llvm_ty, arg_ptr, field_i, "");
                            const alignment =
                                Builder.Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8));
                            _ = try wip.store(.normal, param, field_ptr, alignment);
                        }

                        const is_by_ref = isByRef(param_ty, zcu);
                        args.appendAssumeCapacity(if (is_by_ref)
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, param_alignment, ""));
                    },
                    .float_array => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, param_llvm_ty, alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                    .i32_array, .i64_array => {
                        const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                        const param_llvm_ty = try o.lowerType(pt, param_ty);
                        const param = wip.arg(llvm_arg_i);
                        llvm_arg_i += 1;

                        const alignment = param_ty.abiAlignment(zcu).toLlvm();
                        const arg_ptr = try buildAllocaInner(&wip, param.typeOfWip(&wip), alignment, target);
                        _ = try wip.store(.normal, param, arg_ptr, alignment);

                        args.appendAssumeCapacity(if (isByRef(param_ty, zcu))
                            arg_ptr
                        else
                            try wip.load(.normal, param_llvm_ty, arg_ptr, alignment, ""));
                    },
                }
            }
        }

        const file, const subprogram = if (!wip.strip) debug_info: {
            const file = try o.getDebugFile(pt, file_scope);

            const line_number = zcu.navSrcLine(func.owner_nav) + 1;
            const is_internal_linkage = ip.indexToKey(nav.status.fully_resolved.val) != .@"extern";
            const debug_decl_type = try o.lowerDebugType(pt, fn_ty);

            const subprogram = try o.builder.debugSubprogram(
                file,
                try o.builder.metadataString(nav.name.toSlice(ip)),
                try o.builder.metadataStringFromStrtabString(function_index.name(&o.builder)),
                line_number,
                line_number + func.lbrace_line,
                debug_decl_type,
                .{
                    .di_flags = .{
                        .StaticMember = true,
                        .NoReturn = fn_info.return_type == .noreturn_type,
                    },
                    .sp_flags = .{
                        .Optimized = owner_mod.optimize_mode != .Debug,
                        .Definition = true,
                        .LocalToUnit = is_internal_linkage,
                    },
                },
                o.debug_compile_unit,
            );
            function_index.setSubprogram(subprogram, &o.builder);
            break :debug_info .{ file, subprogram };
        } else .{.none} ** 2;

        const fuzz: ?FuncGen.Fuzz = f: {
            if (!owner_mod.fuzz) break :f null;
            if (func_analysis.disable_instrumentation) break :f null;
            if (is_naked) break :f null;
            if (comp.config.san_cov_trace_pc_guard) break :f null;

            // The void type used here is a placeholder to be replaced with an
            // array of the appropriate size after the POI count is known.

            // Due to error "members of llvm.compiler.used must be named", this global needs a name.
            const anon_name = try o.builder.strtabStringFmt("__sancov_gen_.{d}", .{o.used.items.len});
            const counters_variable = try o.builder.addVariable(anon_name, .void, .default);
            try o.used.append(gpa, counters_variable.toConst(&o.builder));
            counters_variable.setLinkage(.private, &o.builder);
            counters_variable.setAlignment(comptime Builder.Alignment.fromByteUnits(1), &o.builder);

            if (target.ofmt == .macho) {
                counters_variable.setSection(try o.builder.string("__DATA,__sancov_cntrs"), &o.builder);
            } else {
                counters_variable.setSection(try o.builder.string("__sancov_cntrs"), &o.builder);
            }

            break :f .{
                .counters_variable = counters_variable,
                .pcs = .{},
            };
        };

        var fg: FuncGen = .{
            .gpa = gpa,
            .air = air.*,
            .liveness = liveness.*.?,
            .ng = &ng,
            .wip = wip,
            .is_naked = fn_info.cc == .naked,
            .fuzz = fuzz,
            .ret_ptr = ret_ptr,
            .args = args.items,
            .arg_index = 0,
            .arg_inline_index = 0,
            .func_inst_table = .{},
            .blocks = .{},
            .loops = .{},
            .switch_dispatch_info = .{},
            .sync_scope = if (owner_mod.single_threaded) .singlethread else .system,
            .file = file,
            .scope = subprogram,
            .base_line = zcu.navSrcLine(func.owner_nav),
            .prev_dbg_line = 0,
            .prev_dbg_column = 0,
            .err_ret_trace = err_ret_trace,
            .disable_intrinsics = disable_intrinsics,
        };
        defer fg.deinit();
        deinit_wip = false;

        fg.genBody(air.getMainBody(), .poi) catch |err| switch (err) {
            error.CodegenFail => switch (zcu.codegenFailMsg(func.owner_nav, ng.err_msg.?)) {
                error.CodegenFail => return,
                error.OutOfMemory => |e| return e,
            },
            else => |e| return e,
        };

        // If we saw any loads or stores involving `allowzero` pointers, we need to mark the whole
        // function as considering null pointers valid so that LLVM's optimizers don't remove these
        // operations on the assumption that they're undefined behavior.
        if (fg.allowzero_access) {
            try attributes.addFnAttr(.null_pointer_is_valid, &o.builder);
        } else {
            _ = try attributes.removeFnAttr(.null_pointer_is_valid);
        }

        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);

        if (fg.fuzz) |*f| {
            {
                const array_llvm_ty = try o.builder.arrayType(f.pcs.items.len, .i8);
                f.counters_variable.ptrConst(&o.builder).global.ptr(&o.builder).type = array_llvm_ty;
                const zero_init = try o.builder.zeroInitConst(array_llvm_ty);
                try f.counters_variable.setInitializer(zero_init, &o.builder);
            }

            const array_llvm_ty = try o.builder.arrayType(f.pcs.items.len, .ptr);
            const init_val = try o.builder.arrayConst(array_llvm_ty, f.pcs.items);
            // Due to error "members of llvm.compiler.used must be named", this global needs a name.
            const anon_name = try o.builder.strtabStringFmt("__sancov_gen_.{d}", .{o.used.items.len});
            const pcs_variable = try o.builder.addVariable(anon_name, array_llvm_ty, .default);
            try o.used.append(gpa, pcs_variable.toConst(&o.builder));
            pcs_variable.setLinkage(.private, &o.builder);
            pcs_variable.setMutability(.constant, &o.builder);
            pcs_variable.setAlignment(Type.usize.abiAlignment(zcu).toLlvm(), &o.builder);
            if (target.ofmt == .macho) {
                pcs_variable.setSection(try o.builder.string("__DATA,__sancov_pcs1"), &o.builder);
            } else {
                pcs_variable.setSection(try o.builder.string("__sancov_pcs1"), &o.builder);
            }
            try pcs_variable.setInitializer(init_val, &o.builder);
        }

        try fg.wip.finish();
    }

    pub fn updateNav(self: *Object, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
        var ng: NavGen = .{
            .object = self,
            .nav_index = nav_index,
            .pt = pt,
            .err_msg = null,
        };
        ng.genDecl() catch |err| switch (err) {
            error.CodegenFail => switch (pt.zcu.codegenFailMsg(nav_index, ng.err_msg.?)) {
                error.CodegenFail => return,
                error.OutOfMemory => |e| return e,
            },
            else => |e| return e,
        };
    }

    pub fn updateExports(
        self: *Object,
        pt: Zcu.PerThread,
        exported: Zcu.Exported,
        export_indices: []const Zcu.Export.Index,
    ) link.File.UpdateExportsError!void {
        const zcu = pt.zcu;
        const nav_index = switch (exported) {
            .nav => |nav| nav,
            .uav => |uav| return updateExportedValue(self, pt, uav, export_indices),
        };
        const ip = &zcu.intern_pool;
        const global_index = self.nav_map.get(nav_index).?;
        const comp = zcu.comp;

        // If we're on COFF and linking with LLD, the linker cares about our exports to determine the subsystem in use.
        coff_export_flags: {
            const lf = comp.bin_file orelse break :coff_export_flags;
            const lld = lf.cast(.lld) orelse break :coff_export_flags;
            const coff = switch (lld.ofmt) {
                .elf, .wasm => break :coff_export_flags,
                .coff => |*coff| coff,
            };
            if (!ip.isFunctionType(ip.getNav(nav_index).typeOf(ip))) break :coff_export_flags;
            const flags = &coff.lld_export_flags;
            for (export_indices) |export_index| {
                const name = export_index.ptr(zcu).opts.name;
                if (name.eqlSlice("main", ip)) flags.c_main = true;
                if (name.eqlSlice("WinMain", ip)) flags.winmain = true;
                if (name.eqlSlice("wWinMain", ip)) flags.wwinmain = true;
                if (name.eqlSlice("WinMainCRTStartup", ip)) flags.winmain_crt_startup = true;
                if (name.eqlSlice("wWinMainCRTStartup", ip)) flags.wwinmain_crt_startup = true;
                if (name.eqlSlice("DllMainCRTStartup", ip)) flags.dllmain_crt_startup = true;
            }
        }

        if (export_indices.len != 0) {
            return updateExportedGlobal(self, zcu, global_index, export_indices);
        } else {
            const fqn = try self.builder.strtabString(ip.getNav(nav_index).fqn.toSlice(ip));
            try global_index.rename(fqn, &self.builder);
            global_index.setLinkage(.internal, &self.builder);
            if (comp.config.dll_export_fns)
                global_index.setDllStorageClass(.default, &self.builder);
            global_index.setUnnamedAddr(.unnamed_addr, &self.builder);
        }
    }

    fn updateExportedValue(
        o: *Object,
        pt: Zcu.PerThread,
        exported_value: InternPool.Index,
        export_indices: []const Zcu.Export.Index,
    ) link.File.UpdateExportsError!void {
        const zcu = pt.zcu;
        const gpa = zcu.gpa;
        const ip = &zcu.intern_pool;
        const main_exp_name = try o.builder.strtabString(export_indices[0].ptr(zcu).opts.name.toSlice(ip));
        const global_index = i: {
            const gop = try o.uav_map.getOrPut(gpa, exported_value);
            if (gop.found_existing) {
                const global_index = gop.value_ptr.*;
                try global_index.rename(main_exp_name, &o.builder);
                break :i global_index;
            }
            const llvm_addr_space = toLlvmAddressSpace(.generic, o.target);
            const variable_index = try o.builder.addVariable(
                main_exp_name,
                try o.lowerType(pt, Type.fromInterned(ip.typeOf(exported_value))),
                llvm_addr_space,
            );
            const global_index = variable_index.ptrConst(&o.builder).global;
            gop.value_ptr.* = global_index;
            // This line invalidates `gop`.
            const init_val = o.lowerValue(pt, exported_value) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.CodegenFail => return error.AnalysisFail,
            };
            try variable_index.setInitializer(init_val, &o.builder);
            break :i global_index;
        };
        return updateExportedGlobal(o, zcu, global_index, export_indices);
    }

    fn updateExportedGlobal(
        o: *Object,
        zcu: *Zcu,
        global_index: Builder.Global.Index,
        export_indices: []const Zcu.Export.Index,
    ) link.File.UpdateExportsError!void {
        const comp = zcu.comp;
        const ip = &zcu.intern_pool;
        const first_export = export_indices[0].ptr(zcu);

        // We will rename this global to have a name matching `first_export`.
        // Successive exports become aliases.
        // If the first export name already exists, then there is a corresponding
        // extern global - we replace it with this global.
        const first_exp_name = try o.builder.strtabString(first_export.opts.name.toSlice(ip));
        if (o.builder.getGlobal(first_exp_name)) |other_global| replace: {
            if (other_global.toConst().getBase(&o.builder) == global_index.toConst().getBase(&o.builder)) {
                break :replace; // this global already has the name we want
            }
            try global_index.takeName(other_global, &o.builder);
            try other_global.replace(global_index, &o.builder);
            // Problem: now we need to replace in the decl_map that
            // the extern decl index points to this new global. However we don't
            // know the decl index.
            // Even if we did, a future incremental update to the extern would then
            // treat the LLVM global as an extern rather than an export, so it would
            // need a way to check that.
            // This is a TODO that needs to be solved when making
            // the LLVM backend support incremental compilation.
        } else {
            try global_index.rename(first_exp_name, &o.builder);
        }

        global_index.setUnnamedAddr(.default, &o.builder);
        if (comp.config.dll_export_fns)
            global_index.setDllStorageClass(.dllexport, &o.builder);
        global_index.setLinkage(switch (first_export.opts.linkage) {
            .internal => unreachable,
            .strong => .external,
            .weak => .weak_odr,
            .link_once => .linkonce_odr,
        }, &o.builder);
        global_index.setVisibility(switch (first_export.opts.visibility) {
            .default => .default,
            .hidden => .hidden,
            .protected => .protected,
        }, &o.builder);
        if (first_export.opts.section.toSlice(ip)) |section|
            switch (global_index.ptrConst(&o.builder).kind) {
                .variable => |impl_index| impl_index.setSection(
                    try o.builder.string(section),
                    &o.builder,
                ),
                .function => unreachable,
                .alias => unreachable,
                .replaced => unreachable,
            };

        // If a Decl is exported more than one time (which is rare),
        // we add aliases for all but the first export.
        // TODO LLVM C API does not support deleting aliases.
        // The planned solution to this is https://github.com/ziglang/zig/issues/13265
        // Until then we iterate over existing aliases and make them point
        // to the correct decl, or otherwise add a new alias. Old aliases are leaked.
        for (export_indices[1..]) |export_idx| {
            const exp = export_idx.ptr(zcu);
            const exp_name = try o.builder.strtabString(exp.opts.name.toSlice(ip));
            if (o.builder.getGlobal(exp_name)) |global| {
                switch (global.ptrConst(&o.builder).kind) {
                    .alias => |alias| {
                        alias.setAliasee(global_index.toConst(), &o.builder);
                        continue;
                    },
                    .variable, .function => {
                        // This existing global is an `extern` corresponding to this export.
                        // Replace it with the global being exported.
                        // This existing global must be replaced with the alias.
                        try global.rename(.empty, &o.builder);
                        try global.replace(global_index, &o.builder);
                    },
                    .replaced => unreachable,
                }
            }
            const alias_index = try o.builder.addAlias(
                .empty,
                global_index.typeOf(&o.builder),
                .default,
                global_index.toConst(),
            );
            try alias_index.rename(exp_name, &o.builder);
        }
    }

    fn getDebugFile(o: *Object, pt: Zcu.PerThread, file_index: Zcu.File.Index) Allocator.Error!Builder.Metadata {
        const gpa = o.gpa;
        const gop = try o.debug_file_map.getOrPut(gpa, file_index);
        errdefer assert(o.debug_file_map.remove(file_index));
        if (gop.found_existing) return gop.value_ptr.*;
        const path = pt.zcu.fileByIndex(file_index).path;
        const abs_path = try path.toAbsolute(pt.zcu.comp.dirs, gpa);
        defer gpa.free(abs_path);

        gop.value_ptr.* = try o.builder.debugFile(
            try o.builder.metadataString(std.fs.path.basename(abs_path)),
            try o.builder.metadataString(std.fs.path.dirname(abs_path) orelse ""),
        );
        return gop.value_ptr.*;
    }

    pub fn lowerDebugType(
        o: *Object,
        pt: Zcu.PerThread,
        ty: Type,
    ) Allocator.Error!Builder.Metadata {
        assert(!o.builder.strip);

        const gpa = o.gpa;
        const target = o.target;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;

        if (o.debug_type_map.get(ty)) |debug_type| return debug_type;

        switch (ty.zigTypeTag(zcu)) {
            .void,
            .noreturn,
            => {
                const debug_void_type = try o.builder.debugSignedType(
                    try o.builder.metadataString("void"),
                    0,
                );
                try o.debug_type_map.put(gpa, ty, debug_void_type);
                return debug_void_type;
            },
            .int => {
                const info = ty.intInfo(zcu);
                assert(info.bits != 0);
                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);
                const builder_name = try o.builder.metadataString(name);
                const debug_bits = ty.abiSize(zcu) * 8; // lldb cannot handle non-byte sized types
                const debug_int_type = switch (info.signedness) {
                    .signed => try o.builder.debugSignedType(builder_name, debug_bits),
                    .unsigned => try o.builder.debugUnsignedType(builder_name, debug_bits),
                };
                try o.debug_type_map.put(gpa, ty, debug_int_type);
                return debug_int_type;
            },
            .@"enum" => {
                if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    const debug_enum_type = try o.makeEmptyNamespaceDebugType(pt, ty);
                    try o.debug_type_map.put(gpa, ty, debug_enum_type);
                    return debug_enum_type;
                }

                const enum_type = ip.loadEnumType(ty.toIntern());
                const enumerators = try gpa.alloc(Builder.Metadata, enum_type.names.len);
                defer gpa.free(enumerators);

                const int_ty = Type.fromInterned(enum_type.tag_ty);
                const int_info = ty.intInfo(zcu);
                assert(int_info.bits != 0);

                for (enum_type.names.get(ip), 0..) |field_name_ip, i| {
                    var bigint_space: Value.BigIntSpace = undefined;
                    const bigint = if (enum_type.values.len != 0)
                        Value.fromInterned(enum_type.values.get(ip)[i]).toBigInt(&bigint_space, zcu)
                    else
                        std.math.big.int.Mutable.init(&bigint_space.limbs, i).toConst();

                    enumerators[i] = try o.builder.debugEnumerator(
                        try o.builder.metadataString(field_name_ip.toSlice(ip)),
                        int_info.signedness == .unsigned,
                        int_info.bits,
                        bigint,
                    );
                }

                const file = try o.getDebugFile(pt, ty.typeDeclInstAllowGeneratedTag(zcu).?.resolveFile(ip));
                const scope = if (ty.getParentNamespace(zcu).unwrap()) |parent_namespace|
                    try o.namespaceToDebugScope(pt, parent_namespace)
                else
                    file;

                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                const debug_enum_type = try o.builder.debugEnumerationType(
                    try o.builder.metadataString(name),
                    file,
                    scope,
                    ty.typeDeclSrcLine(zcu).? + 1, // Line
                    try o.lowerDebugType(pt, int_ty),
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(enumerators),
                );

                try o.debug_type_map.put(gpa, ty, debug_enum_type);
                try o.debug_enums.append(gpa, debug_enum_type);
                return debug_enum_type;
            },
            .float => {
                const bits = ty.floatBits(target);
                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);
                const debug_float_type = try o.builder.debugFloatType(
                    try o.builder.metadataString(name),
                    bits,
                );
                try o.debug_type_map.put(gpa, ty, debug_float_type);
                return debug_float_type;
            },
            .bool => {
                const debug_bool_type = try o.builder.debugBoolType(
                    try o.builder.metadataString("bool"),
                    8, // lldb cannot handle non-byte sized types
                );
                try o.debug_type_map.put(gpa, ty, debug_bool_type);
                return debug_bool_type;
            },
            .pointer => {
                // Normalize everything that the debug info does not represent.
                const ptr_info = ty.ptrInfo(zcu);

                if (ptr_info.sentinel != .none or
                    ptr_info.flags.address_space != .generic or
                    ptr_info.packed_offset.bit_offset != 0 or
                    ptr_info.packed_offset.host_size != 0 or
                    ptr_info.flags.vector_index != .none or
                    ptr_info.flags.is_allowzero or
                    ptr_info.flags.is_const or
                    ptr_info.flags.is_volatile or
                    ptr_info.flags.size == .many or ptr_info.flags.size == .c or
                    !Type.fromInterned(ptr_info.child).hasRuntimeBitsIgnoreComptime(zcu))
                {
                    const bland_ptr_ty = try pt.ptrType(.{
                        .child = if (!Type.fromInterned(ptr_info.child).hasRuntimeBitsIgnoreComptime(zcu))
                            .anyopaque_type
                        else
                            ptr_info.child,
                        .flags = .{
                            .alignment = ptr_info.flags.alignment,
                            .size = switch (ptr_info.flags.size) {
                                .many, .c, .one => .one,
                                .slice => .slice,
                            },
                        },
                    });
                    const debug_ptr_type = try o.lowerDebugType(pt, bland_ptr_ty);
                    try o.debug_type_map.put(gpa, ty, debug_ptr_type);
                    return debug_ptr_type;
                }

                const debug_fwd_ref = try o.builder.debugForwardReference();

                // Set as forward reference while the type is lowered in case it references itself
                try o.debug_type_map.put(gpa, ty, debug_fwd_ref);

                if (ty.isSlice(zcu)) {
                    const ptr_ty = ty.slicePtrFieldType(zcu);
                    const len_ty = Type.usize;

                    const name = try o.allocTypeName(pt, ty);
                    defer gpa.free(name);
                    const line = 0;

                    const ptr_size = ptr_ty.abiSize(zcu);
                    const ptr_align = ptr_ty.abiAlignment(zcu);
                    const len_size = len_ty.abiSize(zcu);
                    const len_align = len_ty.abiAlignment(zcu);

                    const len_offset = len_align.forward(ptr_size);

                    const debug_ptr_type = try o.builder.debugMemberType(
                        try o.builder.metadataString("ptr"),
                        .none, // File
                        debug_fwd_ref,
                        0, // Line
                        try o.lowerDebugType(pt, ptr_ty),
                        ptr_size * 8,
                        (ptr_align.toByteUnits() orelse 0) * 8,
                        0, // Offset
                    );

                    const debug_len_type = try o.builder.debugMemberType(
                        try o.builder.metadataString("len"),
                        .none, // File
                        debug_fwd_ref,
                        0, // Line
                        try o.lowerDebugType(pt, len_ty),
                        len_size * 8,
                        (len_align.toByteUnits() orelse 0) * 8,
                        len_offset * 8,
                    );

                    const debug_slice_type = try o.builder.debugStructType(
                        try o.builder.metadataString(name),
                        .none, // File
                        o.debug_compile_unit, // Scope
                        line,
                        .none, // Underlying type
                        ty.abiSize(zcu) * 8,
                        (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                        try o.builder.metadataTuple(&.{
                            debug_ptr_type,
                            debug_len_type,
                        }),
                    );

                    o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_slice_type);

                    // Set to real type now that it has been lowered fully
                    const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                    map_ptr.* = debug_slice_type;

                    return debug_slice_type;
                }

                const debug_elem_ty = try o.lowerDebugType(pt, Type.fromInterned(ptr_info.child));

                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                const debug_ptr_type = try o.builder.debugPointerType(
                    try o.builder.metadataString(name),
                    .none, // File
                    .none, // Scope
                    0, // Line
                    debug_elem_ty,
                    target.ptrBitWidth(),
                    (ty.ptrAlignment(zcu).toByteUnits() orelse 0) * 8,
                    0, // Offset
                );

                o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_ptr_type);

                // Set to real type now that it has been lowered fully
                const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                map_ptr.* = debug_ptr_type;

                return debug_ptr_type;
            },
            .@"opaque" => {
                if (ty.toIntern() == .anyopaque_type) {
                    const debug_opaque_type = try o.builder.debugSignedType(
                        try o.builder.metadataString("anyopaque"),
                        0,
                    );
                    try o.debug_type_map.put(gpa, ty, debug_opaque_type);
                    return debug_opaque_type;
                }

                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                const file = try o.getDebugFile(pt, ty.typeDeclInstAllowGeneratedTag(zcu).?.resolveFile(ip));
                const scope = if (ty.getParentNamespace(zcu).unwrap()) |parent_namespace|
                    try o.namespaceToDebugScope(pt, parent_namespace)
                else
                    file;

                const debug_opaque_type = try o.builder.debugStructType(
                    try o.builder.metadataString(name),
                    file,
                    scope,
                    ty.typeDeclSrcLine(zcu).? + 1, // Line
                    .none, // Underlying type
                    0, // Size
                    0, // Align
                    .none, // Fields
                );
                try o.debug_type_map.put(gpa, ty, debug_opaque_type);
                return debug_opaque_type;
            },
            .array => {
                const debug_array_type = try o.builder.debugArrayType(
                    .none, // Name
                    .none, // File
                    .none, // Scope
                    0, // Line
                    try o.lowerDebugType(pt, ty.childType(zcu)),
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(&.{
                        try o.builder.debugSubrange(
                            try o.builder.metadataConstant(try o.builder.intConst(.i64, 0)),
                            try o.builder.metadataConstant(try o.builder.intConst(.i64, ty.arrayLen(zcu))),
                        ),
                    }),
                );
                try o.debug_type_map.put(gpa, ty, debug_array_type);
                return debug_array_type;
            },
            .vector => {
                const elem_ty = ty.elemType2(zcu);
                // Vector elements cannot be padded since that would make
                // @bitSizOf(elem) * len > @bitSizOf(vec).
                // Neither gdb nor lldb seem to be able to display non-byte sized
                // vectors properly.
                const debug_elem_type = switch (elem_ty.zigTypeTag(zcu)) {
                    .int => blk: {
                        const info = elem_ty.intInfo(zcu);
                        assert(info.bits != 0);
                        const name = try o.allocTypeName(pt, ty);
                        defer gpa.free(name);
                        const builder_name = try o.builder.metadataString(name);
                        break :blk switch (info.signedness) {
                            .signed => try o.builder.debugSignedType(builder_name, info.bits),
                            .unsigned => try o.builder.debugUnsignedType(builder_name, info.bits),
                        };
                    },
                    .bool => try o.builder.debugBoolType(
                        try o.builder.metadataString("bool"),
                        1,
                    ),
                    else => try o.lowerDebugType(pt, ty.childType(zcu)),
                };

                const debug_vector_type = try o.builder.debugVectorType(
                    .none, // Name
                    .none, // File
                    .none, // Scope
                    0, // Line
                    debug_elem_type,
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(&.{
                        try o.builder.debugSubrange(
                            try o.builder.metadataConstant(try o.builder.intConst(.i64, 0)),
                            try o.builder.metadataConstant(try o.builder.intConst(.i64, ty.vectorLen(zcu))),
                        ),
                    }),
                );

                try o.debug_type_map.put(gpa, ty, debug_vector_type);
                return debug_vector_type;
            },
            .optional => {
                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);
                const child_ty = ty.optionalChild(zcu);
                if (!child_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    const debug_bool_type = try o.builder.debugBoolType(
                        try o.builder.metadataString(name),
                        8,
                    );
                    try o.debug_type_map.put(gpa, ty, debug_bool_type);
                    return debug_bool_type;
                }

                const debug_fwd_ref = try o.builder.debugForwardReference();

                // Set as forward reference while the type is lowered in case it references itself
                try o.debug_type_map.put(gpa, ty, debug_fwd_ref);

                if (ty.optionalReprIsPayload(zcu)) {
                    const debug_optional_type = try o.lowerDebugType(pt, child_ty);

                    o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_optional_type);

                    // Set to real type now that it has been lowered fully
                    const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                    map_ptr.* = debug_optional_type;

                    return debug_optional_type;
                }

                const non_null_ty = Type.u8;
                const payload_size = child_ty.abiSize(zcu);
                const payload_align = child_ty.abiAlignment(zcu);
                const non_null_size = non_null_ty.abiSize(zcu);
                const non_null_align = non_null_ty.abiAlignment(zcu);
                const non_null_offset = non_null_align.forward(payload_size);

                const debug_data_type = try o.builder.debugMemberType(
                    try o.builder.metadataString("data"),
                    .none, // File
                    debug_fwd_ref,
                    0, // Line
                    try o.lowerDebugType(pt, child_ty),
                    payload_size * 8,
                    (payload_align.toByteUnits() orelse 0) * 8,
                    0, // Offset
                );

                const debug_some_type = try o.builder.debugMemberType(
                    try o.builder.metadataString("some"),
                    .none,
                    debug_fwd_ref,
                    0,
                    try o.lowerDebugType(pt, non_null_ty),
                    non_null_size * 8,
                    (non_null_align.toByteUnits() orelse 0) * 8,
                    non_null_offset * 8,
                );

                const debug_optional_type = try o.builder.debugStructType(
                    try o.builder.metadataString(name),
                    .none, // File
                    o.debug_compile_unit, // Scope
                    0, // Line
                    .none, // Underlying type
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(&.{
                        debug_data_type,
                        debug_some_type,
                    }),
                );

                o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_optional_type);

                // Set to real type now that it has been lowered fully
                const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                map_ptr.* = debug_optional_type;

                return debug_optional_type;
            },
            .error_union => {
                const payload_ty = ty.errorUnionPayload(zcu);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    // TODO: Maybe remove?
                    const debug_error_union_type = try o.lowerDebugType(pt, Type.anyerror);
                    try o.debug_type_map.put(gpa, ty, debug_error_union_type);
                    return debug_error_union_type;
                }

                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                const error_size = Type.anyerror.abiSize(zcu);
                const error_align = Type.anyerror.abiAlignment(zcu);
                const payload_size = payload_ty.abiSize(zcu);
                const payload_align = payload_ty.abiAlignment(zcu);

                var error_index: u32 = undefined;
                var payload_index: u32 = undefined;
                var error_offset: u64 = undefined;
                var payload_offset: u64 = undefined;
                if (error_align.compare(.gt, payload_align)) {
                    error_index = 0;
                    payload_index = 1;
                    error_offset = 0;
                    payload_offset = payload_align.forward(error_size);
                } else {
                    payload_index = 0;
                    error_index = 1;
                    payload_offset = 0;
                    error_offset = error_align.forward(payload_size);
                }

                const debug_fwd_ref = try o.builder.debugForwardReference();

                var fields: [2]Builder.Metadata = undefined;
                fields[error_index] = try o.builder.debugMemberType(
                    try o.builder.metadataString("tag"),
                    .none, // File
                    debug_fwd_ref,
                    0, // Line
                    try o.lowerDebugType(pt, Type.anyerror),
                    error_size * 8,
                    (error_align.toByteUnits() orelse 0) * 8,
                    error_offset * 8,
                );
                fields[payload_index] = try o.builder.debugMemberType(
                    try o.builder.metadataString("value"),
                    .none, // File
                    debug_fwd_ref,
                    0, // Line
                    try o.lowerDebugType(pt, payload_ty),
                    payload_size * 8,
                    (payload_align.toByteUnits() orelse 0) * 8,
                    payload_offset * 8,
                );

                const debug_error_union_type = try o.builder.debugStructType(
                    try o.builder.metadataString(name),
                    .none, // File
                    o.debug_compile_unit, // Sope
                    0, // Line
                    .none, // Underlying type
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(&fields),
                );

                o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_error_union_type);

                try o.debug_type_map.put(gpa, ty, debug_error_union_type);
                return debug_error_union_type;
            },
            .error_set => {
                const debug_error_set = try o.builder.debugUnsignedType(
                    try o.builder.metadataString("anyerror"),
                    16,
                );
                try o.debug_type_map.put(gpa, ty, debug_error_set);
                return debug_error_set;
            },
            .@"struct" => {
                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                if (zcu.typeToPackedStruct(ty)) |struct_type| {
                    const backing_int_ty = struct_type.backingIntTypeUnordered(ip);
                    if (backing_int_ty != .none) {
                        const info = Type.fromInterned(backing_int_ty).intInfo(zcu);
                        const builder_name = try o.builder.metadataString(name);
                        const debug_int_type = switch (info.signedness) {
                            .signed => try o.builder.debugSignedType(builder_name, ty.abiSize(zcu) * 8),
                            .unsigned => try o.builder.debugUnsignedType(builder_name, ty.abiSize(zcu) * 8),
                        };
                        try o.debug_type_map.put(gpa, ty, debug_int_type);
                        return debug_int_type;
                    }
                }

                switch (ip.indexToKey(ty.toIntern())) {
                    .tuple_type => |tuple| {
                        var fields: std.ArrayListUnmanaged(Builder.Metadata) = .empty;
                        defer fields.deinit(gpa);

                        try fields.ensureUnusedCapacity(gpa, tuple.types.len);

                        comptime assert(struct_layout_version == 2);
                        var offset: u64 = 0;

                        const debug_fwd_ref = try o.builder.debugForwardReference();

                        for (tuple.types.get(ip), tuple.values.get(ip), 0..) |field_ty, field_val, i| {
                            if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;

                            const field_size = Type.fromInterned(field_ty).abiSize(zcu);
                            const field_align = Type.fromInterned(field_ty).abiAlignment(zcu);
                            const field_offset = field_align.forward(offset);
                            offset = field_offset + field_size;

                            var name_buf: [32]u8 = undefined;
                            const field_name = std.fmt.bufPrint(&name_buf, "{d}", .{i}) catch unreachable;

                            fields.appendAssumeCapacity(try o.builder.debugMemberType(
                                try o.builder.metadataString(field_name),
                                .none, // File
                                debug_fwd_ref,
                                0,
                                try o.lowerDebugType(pt, Type.fromInterned(field_ty)),
                                field_size * 8,
                                (field_align.toByteUnits() orelse 0) * 8,
                                field_offset * 8,
                            ));
                        }

                        const debug_struct_type = try o.builder.debugStructType(
                            try o.builder.metadataString(name),
                            .none, // File
                            o.debug_compile_unit, // Scope
                            0, // Line
                            .none, // Underlying type
                            ty.abiSize(zcu) * 8,
                            (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                            try o.builder.metadataTuple(fields.items),
                        );

                        o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_struct_type);

                        try o.debug_type_map.put(gpa, ty, debug_struct_type);
                        return debug_struct_type;
                    },
                    .struct_type => {
                        if (!ip.loadStructType(ty.toIntern()).haveFieldTypes(ip)) {
                            // This can happen if a struct type makes it all the way to
                            // flush() without ever being instantiated or referenced (even
                            // via pointer). The only reason we are hearing about it now is
                            // that it is being used as a namespace to put other debug types
                            // into. Therefore we can satisfy this by making an empty namespace,
                            // rather than changing the frontend to unnecessarily resolve the
                            // struct field types.
                            const debug_struct_type = try o.makeEmptyNamespaceDebugType(pt, ty);
                            try o.debug_type_map.put(gpa, ty, debug_struct_type);
                            return debug_struct_type;
                        }
                    },
                    else => {},
                }

                if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    const debug_struct_type = try o.makeEmptyNamespaceDebugType(pt, ty);
                    try o.debug_type_map.put(gpa, ty, debug_struct_type);
                    return debug_struct_type;
                }

                const struct_type = zcu.typeToStruct(ty).?;

                var fields: std.ArrayListUnmanaged(Builder.Metadata) = .empty;
                defer fields.deinit(gpa);

                try fields.ensureUnusedCapacity(gpa, struct_type.field_types.len);

                const debug_fwd_ref = try o.builder.debugForwardReference();

                // Set as forward reference while the type is lowered in case it references itself
                try o.debug_type_map.put(gpa, ty, debug_fwd_ref);

                comptime assert(struct_layout_version == 2);
                var it = struct_type.iterateRuntimeOrder(ip);
                while (it.next()) |field_index| {
                    const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
                    const field_size = field_ty.abiSize(zcu);
                    const field_align = ty.fieldAlignment(field_index, zcu);
                    const field_offset = ty.structFieldOffset(field_index, zcu);
                    const field_name = struct_type.fieldName(ip, field_index).unwrap() orelse
                        try ip.getOrPutStringFmt(gpa, pt.tid, "{d}", .{field_index}, .no_embedded_nulls);
                    fields.appendAssumeCapacity(try o.builder.debugMemberType(
                        try o.builder.metadataString(field_name.toSlice(ip)),
                        .none, // File
                        debug_fwd_ref,
                        0, // Line
                        try o.lowerDebugType(pt, field_ty),
                        field_size * 8,
                        (field_align.toByteUnits() orelse 0) * 8,
                        field_offset * 8,
                    ));
                }

                const debug_struct_type = try o.builder.debugStructType(
                    try o.builder.metadataString(name),
                    .none, // File
                    o.debug_compile_unit, // Scope
                    0, // Line
                    .none, // Underlying type
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(fields.items),
                );

                o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_struct_type);

                // Set to real type now that it has been lowered fully
                const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                map_ptr.* = debug_struct_type;

                return debug_struct_type;
            },
            .@"union" => {
                const name = try o.allocTypeName(pt, ty);
                defer gpa.free(name);

                const union_type = ip.loadUnionType(ty.toIntern());
                if (!union_type.haveFieldTypes(ip) or
                    !ty.hasRuntimeBitsIgnoreComptime(zcu) or
                    !union_type.haveLayout(ip))
                {
                    const debug_union_type = try o.makeEmptyNamespaceDebugType(pt, ty);
                    try o.debug_type_map.put(gpa, ty, debug_union_type);
                    return debug_union_type;
                }

                const layout = Type.getUnionLayout(union_type, zcu);

                const debug_fwd_ref = try o.builder.debugForwardReference();

                // Set as forward reference while the type is lowered in case it references itself
                try o.debug_type_map.put(gpa, ty, debug_fwd_ref);

                if (layout.payload_size == 0) {
                    const debug_union_type = try o.builder.debugStructType(
                        try o.builder.metadataString(name),
                        .none, // File
                        o.debug_compile_unit, // Scope
                        0, // Line
                        .none, // Underlying type
                        ty.abiSize(zcu) * 8,
                        (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                        try o.builder.metadataTuple(
                            &.{try o.lowerDebugType(pt, Type.fromInterned(union_type.enum_tag_ty))},
                        ),
                    );

                    // Set to real type now that it has been lowered fully
                    const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                    map_ptr.* = debug_union_type;

                    return debug_union_type;
                }

                var fields: std.ArrayListUnmanaged(Builder.Metadata) = .empty;
                defer fields.deinit(gpa);

                try fields.ensureUnusedCapacity(gpa, union_type.loadTagType(ip).names.len);

                const debug_union_fwd_ref = if (layout.tag_size == 0)
                    debug_fwd_ref
                else
                    try o.builder.debugForwardReference();

                const tag_type = union_type.loadTagType(ip);

                for (0..tag_type.names.len) |field_index| {
                    const field_ty = union_type.field_types.get(ip)[field_index];
                    if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(zcu)) continue;

                    const field_size = Type.fromInterned(field_ty).abiSize(zcu);
                    const field_align: InternPool.Alignment = switch (union_type.flagsUnordered(ip).layout) {
                        .@"packed" => .none,
                        .auto, .@"extern" => ty.fieldAlignment(field_index, zcu),
                    };

                    const field_name = tag_type.names.get(ip)[field_index];
                    fields.appendAssumeCapacity(try o.builder.debugMemberType(
                        try o.builder.metadataString(field_name.toSlice(ip)),
                        .none, // File
                        debug_union_fwd_ref,
                        0, // Line
                        try o.lowerDebugType(pt, Type.fromInterned(field_ty)),
                        field_size * 8,
                        (field_align.toByteUnits() orelse 0) * 8,
                        0, // Offset
                    ));
                }

                var union_name_buf: ?[:0]const u8 = null;
                defer if (union_name_buf) |buf| gpa.free(buf);
                const union_name = if (layout.tag_size == 0) name else name: {
                    union_name_buf = try std.fmt.allocPrintSentinel(gpa, "{s}:Payload", .{name}, 0);
                    break :name union_name_buf.?;
                };

                const debug_union_type = try o.builder.debugUnionType(
                    try o.builder.metadataString(union_name),
                    .none, // File
                    o.debug_compile_unit, // Scope
                    0, // Line
                    .none, // Underlying type
                    layout.payload_size * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(fields.items),
                );

                o.builder.debugForwardReferenceSetType(debug_union_fwd_ref, debug_union_type);

                if (layout.tag_size == 0) {
                    // Set to real type now that it has been lowered fully
                    const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                    map_ptr.* = debug_union_type;

                    return debug_union_type;
                }

                var tag_offset: u64 = undefined;
                var payload_offset: u64 = undefined;
                if (layout.tag_align.compare(.gte, layout.payload_align)) {
                    tag_offset = 0;
                    payload_offset = layout.payload_align.forward(layout.tag_size);
                } else {
                    payload_offset = 0;
                    tag_offset = layout.tag_align.forward(layout.payload_size);
                }

                const debug_tag_type = try o.builder.debugMemberType(
                    try o.builder.metadataString("tag"),
                    .none, // File
                    debug_fwd_ref,
                    0, // Line
                    try o.lowerDebugType(pt, Type.fromInterned(union_type.enum_tag_ty)),
                    layout.tag_size * 8,
                    (layout.tag_align.toByteUnits() orelse 0) * 8,
                    tag_offset * 8,
                );

                const debug_payload_type = try o.builder.debugMemberType(
                    try o.builder.metadataString("payload"),
                    .none, // File
                    debug_fwd_ref,
                    0, // Line
                    debug_union_type,
                    layout.payload_size * 8,
                    (layout.payload_align.toByteUnits() orelse 0) * 8,
                    payload_offset * 8,
                );

                const full_fields: [2]Builder.Metadata =
                    if (layout.tag_align.compare(.gte, layout.payload_align))
                        .{ debug_tag_type, debug_payload_type }
                    else
                        .{ debug_payload_type, debug_tag_type };

                const debug_tagged_union_type = try o.builder.debugStructType(
                    try o.builder.metadataString(name),
                    .none, // File
                    o.debug_compile_unit, // Scope
                    0, // Line
                    .none, // Underlying type
                    ty.abiSize(zcu) * 8,
                    (ty.abiAlignment(zcu).toByteUnits() orelse 0) * 8,
                    try o.builder.metadataTuple(&full_fields),
                );

                o.builder.debugForwardReferenceSetType(debug_fwd_ref, debug_tagged_union_type);

                // Set to real type now that it has been lowered fully
                const map_ptr = o.debug_type_map.getPtr(ty) orelse unreachable;
                map_ptr.* = debug_tagged_union_type;

                return debug_tagged_union_type;
            },
            .@"fn" => {
                const fn_info = zcu.typeToFunc(ty).?;

                var debug_param_types = std.array_list.Managed(Builder.Metadata).init(gpa);
                defer debug_param_types.deinit();

                try debug_param_types.ensureUnusedCapacity(3 + fn_info.param_types.len);

                // Return type goes first.
                if (Type.fromInterned(fn_info.return_type).hasRuntimeBitsIgnoreComptime(zcu)) {
                    const sret = firstParamSRet(fn_info, zcu, target);
                    const ret_ty = if (sret) Type.void else Type.fromInterned(fn_info.return_type);
                    debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, ret_ty));

                    if (sret) {
                        const ptr_ty = try pt.singleMutPtrType(Type.fromInterned(fn_info.return_type));
                        debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, ptr_ty));
                    }
                } else {
                    debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, Type.void));
                }

                if (fn_info.cc == .auto and zcu.comp.config.any_error_tracing) {
                    // Stack trace pointer.
                    debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, .fromInterned(.ptr_usize_type)));
                }

                for (0..fn_info.param_types.len) |i| {
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[i]);
                    if (!param_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;

                    if (isByRef(param_ty, zcu)) {
                        const ptr_ty = try pt.singleMutPtrType(param_ty);
                        debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, ptr_ty));
                    } else {
                        debug_param_types.appendAssumeCapacity(try o.lowerDebugType(pt, param_ty));
                    }
                }

                const debug_function_type = try o.builder.debugSubroutineType(
                    try o.builder.metadataTuple(debug_param_types.items),
                );

                try o.debug_type_map.put(gpa, ty, debug_function_type);
                return debug_function_type;
            },
            .comptime_int => unreachable,
            .comptime_float => unreachable,
            .type => unreachable,
            .undefined => unreachable,
            .null => unreachable,
            .enum_literal => unreachable,

            .frame => @panic("TODO implement lowerDebugType for Frame types"),
            .@"anyframe" => @panic("TODO implement lowerDebugType for AnyFrame types"),
        }
    }

    fn namespaceToDebugScope(o: *Object, pt: Zcu.PerThread, namespace_index: InternPool.NamespaceIndex) !Builder.Metadata {
        const zcu = pt.zcu;
        const namespace = zcu.namespacePtr(namespace_index);
        if (namespace.parent == .none) return try o.getDebugFile(pt, namespace.file_scope);

        const gop = try o.debug_unresolved_namespace_scopes.getOrPut(o.gpa, namespace_index);

        if (!gop.found_existing) gop.value_ptr.* = try o.builder.debugForwardReference();

        return gop.value_ptr.*;
    }

    fn makeEmptyNamespaceDebugType(o: *Object, pt: Zcu.PerThread, ty: Type) !Builder.Metadata {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const file = try o.getDebugFile(pt, ty.typeDeclInstAllowGeneratedTag(zcu).?.resolveFile(ip));
        const scope = if (ty.getParentNamespace(zcu).unwrap()) |parent_namespace|
            try o.namespaceToDebugScope(pt, parent_namespace)
        else
            file;
        return o.builder.debugStructType(
            try o.builder.metadataString(ty.containerTypeName(ip).toSlice(ip)), // TODO use fully qualified name
            file,
            scope,
            ty.typeDeclSrcLine(zcu).? + 1,
            .none,
            0,
            0,
            .none,
        );
    }

    fn allocTypeName(o: *Object, pt: Zcu.PerThread, ty: Type) Allocator.Error![:0]const u8 {
        var aw: std.Io.Writer.Allocating = .init(o.gpa);
        defer aw.deinit();
        ty.print(&aw.writer, pt) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
        };
        return aw.toOwnedSliceSentinel(0);
    }

    /// If the llvm function does not exist, create it.
    /// Note that this can be called before the function's semantic analysis has
    /// completed, so if any attributes rely on that, they must be done in updateFunc, not here.
    fn resolveLlvmFunction(
        o: *Object,
        pt: Zcu.PerThread,
        nav_index: InternPool.Nav.Index,
    ) Allocator.Error!Builder.Function.Index {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const gpa = o.gpa;
        const nav = ip.getNav(nav_index);
        const owner_mod = zcu.navFileScope(nav_index).mod.?;
        const ty: Type = .fromInterned(nav.typeOf(ip));
        const gop = try o.nav_map.getOrPut(gpa, nav_index);
        if (gop.found_existing) return gop.value_ptr.ptr(&o.builder).kind.function;

        const fn_info = zcu.typeToFunc(ty).?;
        const target = &owner_mod.resolved_target.result;
        const sret = firstParamSRet(fn_info, zcu, target);

        const is_extern, const lib_name = if (nav.getExtern(ip)) |@"extern"|
            .{ true, @"extern".lib_name }
        else
            .{ false, .none };
        const function_index = try o.builder.addFunction(
            try o.lowerType(pt, ty),
            try o.builder.strtabString((if (is_extern) nav.name else nav.fqn).toSlice(ip)),
            toLlvmAddressSpace(nav.getAddrspace(), target),
        );
        gop.value_ptr.* = function_index.ptrConst(&o.builder).global;

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);

        if (!is_extern) {
            function_index.setLinkage(.internal, &o.builder);
            function_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        } else {
            if (target.cpu.arch.isWasm()) {
                try attributes.addFnAttr(.{ .string = .{
                    .kind = try o.builder.string("wasm-import-name"),
                    .value = try o.builder.string(nav.name.toSlice(ip)),
                } }, &o.builder);
                if (lib_name.toSlice(ip)) |lib_name_slice| {
                    if (!std.mem.eql(u8, lib_name_slice, "c")) try attributes.addFnAttr(.{ .string = .{
                        .kind = try o.builder.string("wasm-import-module"),
                        .value = try o.builder.string(lib_name_slice),
                    } }, &o.builder);
                }
            }
        }

        var llvm_arg_i: u32 = 0;
        if (sret) {
            // Sret pointers must not be address 0
            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);

            const raw_llvm_ret_ty = try o.lowerType(pt, Type.fromInterned(fn_info.return_type));
            try attributes.addParamAttr(llvm_arg_i, .{ .sret = raw_llvm_ret_ty }, &o.builder);

            llvm_arg_i += 1;
        }

        const err_return_tracing = fn_info.cc == .auto and zcu.comp.config.any_error_tracing;

        if (err_return_tracing) {
            try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            llvm_arg_i += 1;
        }

        if (fn_info.cc == .async) {
            @panic("TODO: LLVM backend lower async function");
        }

        {
            const cc_info = toLlvmCallConv(fn_info.cc, target).?;

            function_index.setCallConv(cc_info.llvm_cc, &o.builder);

            if (cc_info.align_stack) {
                try attributes.addFnAttr(.{ .alignstack = .fromByteUnits(target.stackAlignment()) }, &o.builder);
            } else {
                _ = try attributes.removeFnAttr(.alignstack);
            }

            if (cc_info.naked) {
                try attributes.addFnAttr(.naked, &o.builder);
            } else {
                _ = try attributes.removeFnAttr(.naked);
            }

            for (0..cc_info.inreg_param_count) |param_idx| {
                try attributes.addParamAttr(param_idx, .inreg, &o.builder);
            }
            for (cc_info.inreg_param_count..std.math.maxInt(u2)) |param_idx| {
                _ = try attributes.removeParamAttr(param_idx, .inreg);
            }

            switch (fn_info.cc) {
                inline .riscv64_interrupt,
                .riscv32_interrupt,
                .mips_interrupt,
                .mips64_interrupt,
                => |info| {
                    try attributes.addFnAttr(.{ .string = .{
                        .kind = try o.builder.string("interrupt"),
                        .value = try o.builder.string(@tagName(info.mode)),
                    } }, &o.builder);
                },
                .arm_interrupt,
                => |info| {
                    try attributes.addFnAttr(.{ .string = .{
                        .kind = try o.builder.string("interrupt"),
                        .value = try o.builder.string(switch (info.type) {
                            .generic => "",
                            .irq => "IRQ",
                            .fiq => "FIQ",
                            .swi => "SWI",
                            .abort => "ABORT",
                            .undef => "UNDEF",
                        }),
                    } }, &o.builder);
                },
                // these function attributes serve as a backup against any mistakes LLVM makes.
                // clang sets both the function's calling convention and the function attributes
                // in its backend, so future patches to the AVR backend could end up checking only one,
                // possibly breaking our support. it's safer to just emit both.
                .avr_interrupt, .avr_signal, .csky_interrupt => {
                    try attributes.addFnAttr(.{ .string = .{
                        .kind = try o.builder.string(switch (fn_info.cc) {
                            .avr_interrupt,
                            .csky_interrupt,
                            => "interrupt",
                            .avr_signal => "signal",
                            else => unreachable,
                        }),
                        .value = .empty,
                    } }, &o.builder);
                },
                else => {},
            }
        }

        if (nav.getAlignment() != .none)
            function_index.setAlignment(nav.getAlignment().toLlvm(), &o.builder);

        // Function attributes that are independent of analysis results of the function body.
        try o.addCommonFnAttributes(
            &attributes,
            owner_mod,
            // Some backends don't respect the `naked` attribute in `TargetFrameLowering::hasFP()`,
            // so for these backends, LLVM will happily emit code that accesses the stack through
            // the frame pointer. This is nonsensical since what the `naked` attribute does is
            // suppress generation of the prologue and epilogue, and the prologue is where the
            // frame pointer normally gets set up. At time of writing, this is the case for at
            // least x86 and RISC-V.
            owner_mod.omit_frame_pointer or fn_info.cc == .naked,
        );

        if (fn_info.return_type == .noreturn_type) try attributes.addFnAttr(.noreturn, &o.builder);

        // Add parameter attributes. We handle only the case of extern functions (no body)
        // because functions with bodies are handled in `updateFunc`.
        if (is_extern) {
            var it = iterateParamTypes(o, pt, fn_info);
            it.llvm_index = llvm_arg_i;
            while (try it.next()) |lowering| switch (lowering) {
                .byval => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    if (!isByRef(param_ty, zcu)) {
                        try o.addByValParamAttrs(pt, &attributes, param_ty, param_index, fn_info, it.llvm_index - 1);
                    }
                },
                .byref => {
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                    const param_llvm_ty = try o.lowerType(pt, param_ty);
                    const alignment = param_ty.abiAlignment(zcu);
                    try o.addByRefParamAttrs(&attributes, it.llvm_index - 1, alignment.toLlvm(), it.byval_attr, param_llvm_ty);
                },
                .byref_mut => try attributes.addParamAttr(it.llvm_index - 1, .noundef, &o.builder),
                // No attributes needed for these.
                .no_bits,
                .abi_sized_int,
                .multiple_llvm_types,
                .float_array,
                .i32_array,
                .i64_array,
                => continue,

                .slice => unreachable, // extern functions do not support slice types.

            };
        }

        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        return function_index;
    }

    fn addCommonFnAttributes(
        o: *Object,
        attributes: *Builder.FunctionAttributes.Wip,
        owner_mod: *Package.Module,
        omit_frame_pointer: bool,
    ) Allocator.Error!void {
        if (!owner_mod.red_zone) {
            try attributes.addFnAttr(.noredzone, &o.builder);
        }
        if (omit_frame_pointer) {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("frame-pointer"),
                .value = try o.builder.string("none"),
            } }, &o.builder);
        } else {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("frame-pointer"),
                .value = try o.builder.string("all"),
            } }, &o.builder);
        }
        try attributes.addFnAttr(.nounwind, &o.builder);
        if (owner_mod.unwind_tables != .none) {
            try attributes.addFnAttr(
                .{ .uwtable = if (owner_mod.unwind_tables == .async) .async else .sync },
                &o.builder,
            );
        }
        if (owner_mod.optimize_mode == .ReleaseSmall) {
            try attributes.addFnAttr(.minsize, &o.builder);
            try attributes.addFnAttr(.optsize, &o.builder);
        }
        const target = &owner_mod.resolved_target.result;
        if (target.cpu.model.llvm_name) |s| {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("target-cpu"),
                .value = try o.builder.string(s),
            } }, &o.builder);
        }
        if (owner_mod.resolved_target.llvm_cpu_features) |s| {
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("target-features"),
                .value = try o.builder.string(std.mem.span(s)),
            } }, &o.builder);
        }
        if (target.abi.float() == .soft) {
            // `use-soft-float` means "use software routines for floating point computations". In
            // other words, it configures how LLVM lowers basic float instructions like `fcmp`,
            // `fadd`, etc. The float calling convention is configured on `TargetMachine` and is
            // mostly an orthogonal concept, although obviously we do need hardware float operations
            // to actually be able to pass float values in float registers.
            //
            // Ideally, we would support something akin to the `-mfloat-abi=softfp` option that GCC
            // and Clang support for Arm32 and CSKY. We don't currently expose such an option in
            // Zig, and using CPU features as the source of truth for this makes for a miserable
            // user experience since people expect e.g. `arm-linux-gnueabi` to mean full soft float
            // unless the compiler has explicitly been told otherwise. (And note that our baseline
            // CPU models almost all include FPU features!)
            //
            // Revisit this at some point.
            try attributes.addFnAttr(.{ .string = .{
                .kind = try o.builder.string("use-soft-float"),
                .value = try o.builder.string("true"),
            } }, &o.builder);

            // This prevents LLVM from using FPU/SIMD code for things like `memcpy`. As for the
            // above, this should be revisited if `softfp` support is added.
            try attributes.addFnAttr(.noimplicitfloat, &o.builder);
        }
    }

    fn resolveGlobalUav(
        o: *Object,
        pt: Zcu.PerThread,
        uav: InternPool.Index,
        llvm_addr_space: Builder.AddrSpace,
        alignment: InternPool.Alignment,
    ) Error!Builder.Variable.Index {
        assert(alignment != .none);
        // TODO: Add address space to the anon_decl_map
        const gop = try o.uav_map.getOrPut(o.gpa, uav);
        if (gop.found_existing) {
            // Keep the greater of the two alignments.
            const variable_index = gop.value_ptr.ptr(&o.builder).kind.variable;
            const old_alignment = InternPool.Alignment.fromLlvm(variable_index.getAlignment(&o.builder));
            const max_alignment = old_alignment.maxStrict(alignment);
            variable_index.setAlignment(max_alignment.toLlvm(), &o.builder);
            return variable_index;
        }
        errdefer assert(o.uav_map.remove(uav));

        const zcu = pt.zcu;
        const decl_ty = zcu.intern_pool.typeOf(uav);

        const variable_index = try o.builder.addVariable(
            try o.builder.strtabStringFmt("__anon_{d}", .{@intFromEnum(uav)}),
            try o.lowerType(pt, Type.fromInterned(decl_ty)),
            llvm_addr_space,
        );
        gop.value_ptr.* = variable_index.ptrConst(&o.builder).global;

        try variable_index.setInitializer(try o.lowerValue(pt, uav), &o.builder);
        variable_index.setLinkage(.internal, &o.builder);
        variable_index.setMutability(.constant, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(alignment.toLlvm(), &o.builder);
        return variable_index;
    }

    fn resolveGlobalNav(
        o: *Object,
        pt: Zcu.PerThread,
        nav_index: InternPool.Nav.Index,
    ) Allocator.Error!Builder.Variable.Index {
        const gop = try o.nav_map.getOrPut(o.gpa, nav_index);
        if (gop.found_existing) return gop.value_ptr.ptr(&o.builder).kind.variable;
        errdefer assert(o.nav_map.remove(nav_index));

        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(nav_index);
        const linkage: std.builtin.GlobalLinkage, const visibility: Builder.Visibility, const is_threadlocal, const is_dll_import = switch (nav.status) {
            .unresolved => unreachable,
            .fully_resolved => |r| switch (ip.indexToKey(r.val)) {
                .variable => |variable| .{ .internal, .default, variable.is_threadlocal, false },
                .@"extern" => |@"extern"| .{ @"extern".linkage, .fromSymbolVisibility(@"extern".visibility), @"extern".is_threadlocal, @"extern".is_dll_import },
                else => .{ .internal, .default, false, false },
            },
            // This means it's a source declaration which is not `extern`!
            .type_resolved => |r| .{ .internal, .default, r.is_threadlocal, false },
        };

        const variable_index = try o.builder.addVariable(
            try o.builder.strtabString(switch (linkage) {
                .internal => nav.fqn,
                .strong, .weak => nav.name,
                .link_once => unreachable,
            }.toSlice(ip)),
            try o.lowerType(pt, Type.fromInterned(nav.typeOf(ip))),
            toLlvmGlobalAddressSpace(nav.getAddrspace(), zcu.getTarget()),
        );
        gop.value_ptr.* = variable_index.ptrConst(&o.builder).global;

        // This is needed for declarations created by `@extern`.
        switch (linkage) {
            .internal => {
                variable_index.setLinkage(.internal, &o.builder);
                variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
            },
            .strong, .weak => {
                variable_index.setLinkage(switch (linkage) {
                    .internal => unreachable,
                    .strong => .external,
                    .weak => .extern_weak,
                    .link_once => unreachable,
                }, &o.builder);
                variable_index.setUnnamedAddr(.default, &o.builder);
                if (is_threadlocal and !zcu.navFileScope(nav_index).mod.?.single_threaded)
                    variable_index.setThreadLocal(.generaldynamic, &o.builder);
                if (is_dll_import) variable_index.setDllStorageClass(.dllimport, &o.builder);
            },
            .link_once => unreachable,
        }
        variable_index.setVisibility(visibility, &o.builder);
        return variable_index;
    }

    fn errorIntType(o: *Object, pt: Zcu.PerThread) Allocator.Error!Builder.Type {
        return o.builder.intType(pt.zcu.errorSetBits());
    }

    fn lowerType(o: *Object, pt: Zcu.PerThread, t: Type) Allocator.Error!Builder.Type {
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        const ip = &zcu.intern_pool;
        return switch (t.toIntern()) {
            .u0_type, .i0_type => unreachable,
            inline .u1_type,
            .u8_type,
            .i8_type,
            .u16_type,
            .i16_type,
            .u29_type,
            .u32_type,
            .i32_type,
            .u64_type,
            .i64_type,
            .u80_type,
            .u128_type,
            .i128_type,
            => |tag| @field(Builder.Type, "i" ++ @tagName(tag)[1 .. @tagName(tag).len - "_type".len]),
            .usize_type, .isize_type => try o.builder.intType(target.ptrBitWidth()),
            inline .c_char_type,
            .c_short_type,
            .c_ushort_type,
            .c_int_type,
            .c_uint_type,
            .c_long_type,
            .c_ulong_type,
            .c_longlong_type,
            .c_ulonglong_type,
            => |tag| try o.builder.intType(target.cTypeBitSize(
                @field(std.Target.CType, @tagName(tag)["c_".len .. @tagName(tag).len - "_type".len]),
            )),
            .c_longdouble_type,
            .f16_type,
            .f32_type,
            .f64_type,
            .f80_type,
            .f128_type,
            => switch (t.floatBits(target)) {
                16 => if (backendSupportsF16(target)) .half else .i16,
                32 => .float,
                64 => .double,
                80 => if (backendSupportsF80(target)) .x86_fp80 else .i80,
                128 => .fp128,
                else => unreachable,
            },
            .anyopaque_type => {
                // This is unreachable except when used as the type for an extern global.
                // For example: `@extern(*anyopaque, .{ .name = "foo"})` should produce
                // @foo = external global i8
                return .i8;
            },
            .bool_type => .i1,
            .void_type => .void,
            .type_type => unreachable,
            .anyerror_type => try o.errorIntType(pt),
            .comptime_int_type,
            .comptime_float_type,
            .noreturn_type,
            => unreachable,
            .anyframe_type => @panic("TODO implement lowerType for AnyFrame types"),
            .null_type,
            .undefined_type,
            .enum_literal_type,
            => unreachable,
            .ptr_usize_type,
            .ptr_const_comptime_int_type,
            .manyptr_u8_type,
            .manyptr_const_u8_type,
            .manyptr_const_u8_sentinel_0_type,
            => .ptr,
            .slice_const_u8_type,
            .slice_const_u8_sentinel_0_type,
            => try o.builder.structType(.normal, &.{ .ptr, try o.lowerType(pt, Type.usize) }),
            .optional_noreturn_type => unreachable,
            .anyerror_void_error_union_type,
            .adhoc_inferred_error_set_type,
            => try o.errorIntType(pt),
            .generic_poison_type,
            .empty_tuple_type,
            => unreachable,
            // values, not types
            .undef,
            .undef_bool,
            .undef_usize,
            .undef_u1,
            .zero,
            .zero_usize,
            .zero_u1,
            .zero_u8,
            .one,
            .one_usize,
            .one_u1,
            .one_u8,
            .four_u8,
            .negative_one,
            .void_value,
            .unreachable_value,
            .null_value,
            .bool_true,
            .bool_false,
            .empty_tuple,
            .none,
            => unreachable,
            else => switch (ip.indexToKey(t.toIntern())) {
                .int_type => |int_type| try o.builder.intType(int_type.bits),
                .ptr_type => |ptr_type| type: {
                    const ptr_ty = try o.builder.ptrType(
                        toLlvmAddressSpace(ptr_type.flags.address_space, target),
                    );
                    break :type switch (ptr_type.flags.size) {
                        .one, .many, .c => ptr_ty,
                        .slice => try o.builder.structType(.normal, &.{
                            ptr_ty,
                            try o.lowerType(pt, Type.usize),
                        }),
                    };
                },
                .array_type => |array_type| o.builder.arrayType(
                    array_type.lenIncludingSentinel(),
                    try o.lowerType(pt, Type.fromInterned(array_type.child)),
                ),
                .vector_type => |vector_type| o.builder.vectorType(
                    .normal,
                    vector_type.len,
                    try o.lowerType(pt, Type.fromInterned(vector_type.child)),
                ),
                .opt_type => |child_ty| {
                    // Must stay in sync with `opt_payload` logic in `lowerPtr`.
                    if (!Type.fromInterned(child_ty).hasRuntimeBitsIgnoreComptime(zcu)) return .i8;

                    const payload_ty = try o.lowerType(pt, Type.fromInterned(child_ty));
                    if (t.optionalReprIsPayload(zcu)) return payload_ty;

                    comptime assert(optional_layout_version == 3);
                    var fields: [3]Builder.Type = .{ payload_ty, .i8, undefined };
                    var fields_len: usize = 2;
                    const offset = Type.fromInterned(child_ty).abiSize(zcu) + 1;
                    const abi_size = t.abiSize(zcu);
                    const padding_len = abi_size - offset;
                    if (padding_len > 0) {
                        fields[2] = try o.builder.arrayType(padding_len, .i8);
                        fields_len = 3;
                    }
                    return o.builder.structType(.normal, fields[0..fields_len]);
                },
                .anyframe_type => @panic("TODO implement lowerType for AnyFrame types"),
                .error_union_type => |error_union_type| {
                    // Must stay in sync with `codegen.errUnionPayloadOffset`.
                    // See logic in `lowerPtr`.
                    const error_type = try o.errorIntType(pt);
                    if (!Type.fromInterned(error_union_type.payload_type).hasRuntimeBitsIgnoreComptime(zcu))
                        return error_type;
                    const payload_type = try o.lowerType(pt, Type.fromInterned(error_union_type.payload_type));

                    const payload_align = Type.fromInterned(error_union_type.payload_type).abiAlignment(zcu);
                    const error_align: InternPool.Alignment = .fromByteUnits(std.zig.target.intAlignment(target, zcu.errorSetBits()));

                    const payload_size = Type.fromInterned(error_union_type.payload_type).abiSize(zcu);
                    const error_size = std.zig.target.intByteSize(target, zcu.errorSetBits());

                    var fields: [3]Builder.Type = undefined;
                    var fields_len: usize = 2;
                    const padding_len = if (error_align.compare(.gt, payload_align)) pad: {
                        fields[0] = error_type;
                        fields[1] = payload_type;
                        const payload_end =
                            payload_align.forward(error_size) +
                            payload_size;
                        const abi_size = error_align.forward(payload_end);
                        break :pad abi_size - payload_end;
                    } else pad: {
                        fields[0] = payload_type;
                        fields[1] = error_type;
                        const error_end =
                            error_align.forward(payload_size) +
                            error_size;
                        const abi_size = payload_align.forward(error_end);
                        break :pad abi_size - error_end;
                    };
                    if (padding_len > 0) {
                        fields[2] = try o.builder.arrayType(padding_len, .i8);
                        fields_len = 3;
                    }
                    return o.builder.structType(.normal, fields[0..fields_len]);
                },
                .simple_type => unreachable,
                .struct_type => {
                    if (o.type_map.get(t.toIntern())) |value| return value;

                    const struct_type = ip.loadStructType(t.toIntern());

                    if (struct_type.layout == .@"packed") {
                        const int_ty = try o.lowerType(pt, Type.fromInterned(struct_type.backingIntTypeUnordered(ip)));
                        try o.type_map.put(o.gpa, t.toIntern(), int_ty);
                        return int_ty;
                    }

                    var llvm_field_types: std.ArrayListUnmanaged(Builder.Type) = .empty;
                    defer llvm_field_types.deinit(o.gpa);
                    // Although we can estimate how much capacity to add, these cannot be
                    // relied upon because of the recursive calls to lowerType below.
                    try llvm_field_types.ensureUnusedCapacity(o.gpa, struct_type.field_types.len);
                    try o.struct_field_map.ensureUnusedCapacity(o.gpa, struct_type.field_types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .@"1";
                    var struct_kind: Builder.Type.Structure.Kind = .normal;
                    // When we encounter a zero-bit field, we place it here so we know to map it to the next non-zero-bit field (if any).
                    var it = struct_type.iterateRuntimeOrder(ip);
                    while (it.next()) |field_index| {
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                        const field_align = t.fieldAlignment(field_index, zcu);
                        const field_ty_align = field_ty.abiAlignment(zcu);
                        if (field_align.compare(.lt, field_ty_align)) struct_kind = .@"packed";
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );

                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                            // This is a zero-bit field. If there are runtime bits after this field,
                            // map to the next LLVM field (which we know exists): otherwise, don't
                            // map the field, indicating it's at the end of the struct.
                            if (offset != struct_type.sizeUnordered(ip)) {
                                try o.struct_field_map.put(o.gpa, .{
                                    .struct_ty = t.toIntern(),
                                    .field_index = field_index,
                                }, @intCast(llvm_field_types.items.len));
                            }
                            continue;
                        }

                        try o.struct_field_map.put(o.gpa, .{
                            .struct_ty = t.toIntern(),
                            .field_index = field_index,
                        }, @intCast(llvm_field_types.items.len));
                        try llvm_field_types.append(o.gpa, try o.lowerType(pt, field_ty));

                        offset += field_ty.abiSize(zcu);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                    }

                    const ty = try o.builder.opaqueType(try o.builder.string(t.containerTypeName(ip).toSlice(ip)));
                    try o.type_map.put(o.gpa, t.toIntern(), ty);

                    o.builder.namedTypeSetBody(
                        ty,
                        try o.builder.structType(struct_kind, llvm_field_types.items),
                    );
                    return ty;
                },
                .tuple_type => |tuple_type| {
                    var llvm_field_types: std.ArrayListUnmanaged(Builder.Type) = .empty;
                    defer llvm_field_types.deinit(o.gpa);
                    // Although we can estimate how much capacity to add, these cannot be
                    // relied upon because of the recursive calls to lowerType below.
                    try llvm_field_types.ensureUnusedCapacity(o.gpa, tuple_type.types.len);
                    try o.struct_field_map.ensureUnusedCapacity(o.gpa, tuple_type.types.len);

                    comptime assert(struct_layout_version == 2);
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .none;

                    const struct_size = t.abiSize(zcu);

                    for (
                        tuple_type.types.get(ip),
                        tuple_type.values.get(ip),
                        0..,
                    ) |field_ty, field_val, field_index| {
                        if (field_val != .none) continue;

                        const field_align = Type.fromInterned(field_ty).abiAlignment(zcu);
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(zcu)) {
                            // This is a zero-bit field. If there are runtime bits after this field,
                            // map to the next LLVM field (which we know exists): otherwise, don't
                            // map the field, indicating it's at the end of the struct.
                            if (offset != struct_size) {
                                try o.struct_field_map.put(o.gpa, .{
                                    .struct_ty = t.toIntern(),
                                    .field_index = @intCast(field_index),
                                }, @intCast(llvm_field_types.items.len));
                            }
                            continue;
                        }
                        try o.struct_field_map.put(o.gpa, .{
                            .struct_ty = t.toIntern(),
                            .field_index = @intCast(field_index),
                        }, @intCast(llvm_field_types.items.len));
                        try llvm_field_types.append(o.gpa, try o.lowerType(pt, Type.fromInterned(field_ty)));

                        offset += Type.fromInterned(field_ty).abiSize(zcu);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) try llvm_field_types.append(
                            o.gpa,
                            try o.builder.arrayType(padding_len, .i8),
                        );
                    }
                    return o.builder.structType(.normal, llvm_field_types.items);
                },
                .union_type => {
                    if (o.type_map.get(t.toIntern())) |value| return value;

                    const union_obj = ip.loadUnionType(t.toIntern());
                    const layout = Type.getUnionLayout(union_obj, zcu);

                    if (union_obj.flagsUnordered(ip).layout == .@"packed") {
                        const int_ty = try o.builder.intType(@intCast(t.bitSize(zcu)));
                        try o.type_map.put(o.gpa, t.toIntern(), int_ty);
                        return int_ty;
                    }

                    if (layout.payload_size == 0) {
                        const enum_tag_ty = try o.lowerType(pt, Type.fromInterned(union_obj.enum_tag_ty));
                        try o.type_map.put(o.gpa, t.toIntern(), enum_tag_ty);
                        return enum_tag_ty;
                    }

                    const aligned_field_ty = Type.fromInterned(union_obj.field_types.get(ip)[layout.most_aligned_field]);
                    const aligned_field_llvm_ty = try o.lowerType(pt, aligned_field_ty);

                    const payload_ty = ty: {
                        if (layout.most_aligned_field_size == layout.payload_size) {
                            break :ty aligned_field_llvm_ty;
                        }
                        const padding_len = if (layout.tag_size == 0)
                            layout.abi_size - layout.most_aligned_field_size
                        else
                            layout.payload_size - layout.most_aligned_field_size;
                        break :ty try o.builder.structType(.@"packed", &.{
                            aligned_field_llvm_ty,
                            try o.builder.arrayType(padding_len, .i8),
                        });
                    };

                    if (layout.tag_size == 0) {
                        const ty = try o.builder.opaqueType(try o.builder.string(t.containerTypeName(ip).toSlice(ip)));
                        try o.type_map.put(o.gpa, t.toIntern(), ty);

                        o.builder.namedTypeSetBody(
                            ty,
                            try o.builder.structType(.normal, &.{payload_ty}),
                        );
                        return ty;
                    }
                    const enum_tag_ty = try o.lowerType(pt, Type.fromInterned(union_obj.enum_tag_ty));

                    // Put the tag before or after the payload depending on which one's
                    // alignment is greater.
                    var llvm_fields: [3]Builder.Type = undefined;
                    var llvm_fields_len: usize = 2;

                    if (layout.tag_align.compare(.gte, layout.payload_align)) {
                        llvm_fields = .{ enum_tag_ty, payload_ty, .none };
                    } else {
                        llvm_fields = .{ payload_ty, enum_tag_ty, .none };
                    }

                    // Insert padding to make the LLVM struct ABI size match the Zig union ABI size.
                    if (layout.padding != 0) {
                        llvm_fields[llvm_fields_len] = try o.builder.arrayType(layout.padding, .i8);
                        llvm_fields_len += 1;
                    }

                    const ty = try o.builder.opaqueType(try o.builder.string(t.containerTypeName(ip).toSlice(ip)));
                    try o.type_map.put(o.gpa, t.toIntern(), ty);

                    o.builder.namedTypeSetBody(
                        ty,
                        try o.builder.structType(.normal, llvm_fields[0..llvm_fields_len]),
                    );
                    return ty;
                },
                .opaque_type => {
                    const gop = try o.type_map.getOrPut(o.gpa, t.toIntern());
                    if (!gop.found_existing) {
                        gop.value_ptr.* = try o.builder.opaqueType(try o.builder.string(t.containerTypeName(ip).toSlice(ip)));
                    }
                    return gop.value_ptr.*;
                },
                .enum_type => try o.lowerType(pt, Type.fromInterned(ip.loadEnumType(t.toIntern()).tag_ty)),
                .func_type => |func_type| try o.lowerTypeFn(pt, func_type),
                .error_set_type, .inferred_error_set_type => try o.errorIntType(pt),
                // values, not types
                .undef,
                .simple_value,
                .variable,
                .@"extern",
                .func,
                .int,
                .err,
                .error_union,
                .enum_literal,
                .enum_tag,
                .empty_enum_value,
                .float,
                .ptr,
                .slice,
                .opt,
                .aggregate,
                .un,
                // memoization, not types
                .memoized_call,
                => unreachable,
            },
        };
    }

    /// Use this instead of lowerType when you want to handle correctly the case of elem_ty
    /// being a zero bit type, but it should still be lowered as an i8 in such case.
    /// There are other similar cases handled here as well.
    fn lowerPtrElemTy(o: *Object, pt: Zcu.PerThread, elem_ty: Type) Allocator.Error!Builder.Type {
        const zcu = pt.zcu;
        const lower_elem_ty = switch (elem_ty.zigTypeTag(zcu)) {
            .@"opaque" => true,
            .@"fn" => !zcu.typeToFunc(elem_ty).?.is_generic,
            .array => elem_ty.childType(zcu).hasRuntimeBitsIgnoreComptime(zcu),
            else => elem_ty.hasRuntimeBitsIgnoreComptime(zcu),
        };
        return if (lower_elem_ty) try o.lowerType(pt, elem_ty) else .i8;
    }

    fn lowerTypeFn(o: *Object, pt: Zcu.PerThread, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();
        const ret_ty = try lowerFnRetTy(o, pt, fn_info);

        var llvm_params: std.ArrayListUnmanaged(Builder.Type) = .empty;
        defer llvm_params.deinit(o.gpa);

        if (firstParamSRet(fn_info, zcu, target)) {
            try llvm_params.append(o.gpa, .ptr);
        }

        if (fn_info.cc == .auto and zcu.comp.config.any_error_tracing) {
            const stack_trace_ty = zcu.builtin_decl_values.get(.StackTrace);
            const ptr_ty = try pt.ptrType(.{ .child = stack_trace_ty });
            try llvm_params.append(o.gpa, try o.lowerType(pt, ptr_ty));
        }

        var it = iterateParamTypes(o, pt, fn_info);
        while (try it.next()) |lowering| switch (lowering) {
            .no_bits => continue,
            .byval => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.append(o.gpa, try o.lowerType(pt, param_ty));
            },
            .byref, .byref_mut => {
                try llvm_params.append(o.gpa, .ptr);
            },
            .abi_sized_int => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.append(o.gpa, try o.builder.intType(
                    @intCast(param_ty.abiSize(zcu) * 8),
                ));
            },
            .slice => {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                try llvm_params.appendSlice(o.gpa, &.{
                    try o.builder.ptrType(toLlvmAddressSpace(param_ty.ptrAddressSpace(zcu), target)),
                    try o.lowerType(pt, Type.usize),
                });
            },
            .multiple_llvm_types => {
                try llvm_params.appendSlice(o.gpa, it.types_buffer[0..it.types_len]);
            },
            .float_array => |count| {
                const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                const float_ty = try o.lowerType(pt, aarch64_c_abi.getFloatArrayType(param_ty, zcu).?);
                try llvm_params.append(o.gpa, try o.builder.arrayType(count, float_ty));
            },
            .i32_array, .i64_array => |arr_len| {
                try llvm_params.append(o.gpa, try o.builder.arrayType(arr_len, switch (lowering) {
                    .i32_array => .i32,
                    .i64_array => .i64,
                    else => unreachable,
                }));
            },
        };

        return o.builder.fnType(
            ret_ty,
            llvm_params.items,
            if (fn_info.is_var_args) .vararg else .normal,
        );
    }

    fn lowerValueToInt(o: *Object, pt: Zcu.PerThread, llvm_int_ty: Builder.Type, arg_val: InternPool.Index) Error!Builder.Constant {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();

        const val = Value.fromInterned(arg_val);
        const val_key = ip.indexToKey(val.toIntern());

        if (val.isUndef(zcu)) return o.builder.undefConst(llvm_int_ty);

        const ty = Type.fromInterned(val_key.typeOf());
        switch (val_key) {
            .@"extern" => |@"extern"| {
                const function_index = try o.resolveLlvmFunction(pt, @"extern".owner_nav);
                const ptr = function_index.ptrConst(&o.builder).global.toConst();
                return o.builder.convConst(ptr, llvm_int_ty);
            },
            .func => |func| {
                const function_index = try o.resolveLlvmFunction(pt, func.owner_nav);
                const ptr = function_index.ptrConst(&o.builder).global.toConst();
                return o.builder.convConst(ptr, llvm_int_ty);
            },
            .ptr => return o.builder.convConst(try o.lowerPtr(pt, arg_val, 0), llvm_int_ty),
            .aggregate => switch (ip.indexToKey(ty.toIntern())) {
                .struct_type, .vector_type => {},
                else => unreachable,
            },
            .un => |un| {
                const layout = ty.unionGetLayout(zcu);
                if (layout.payload_size == 0) return o.lowerValue(pt, un.tag);

                const union_obj = zcu.typeToUnion(ty).?;
                const container_layout = union_obj.flagsUnordered(ip).layout;

                assert(container_layout == .@"packed");

                var need_unnamed = false;
                if (un.tag == .none) {
                    assert(layout.tag_size == 0);
                    const union_val = try o.lowerValueToInt(pt, llvm_int_ty, un.val);

                    need_unnamed = true;
                    return union_val;
                }
                const field_index = zcu.unionTagFieldIndex(union_obj, Value.fromInterned(un.tag)).?;
                const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                if (!field_ty.hasRuntimeBits(zcu)) return o.builder.intConst(llvm_int_ty, 0);
                return o.lowerValueToInt(pt, llvm_int_ty, un.val);
            },
            .simple_value => |simple_value| switch (simple_value) {
                .false, .true => {},
                else => unreachable,
            },
            .int,
            .float,
            .enum_tag,
            => {},
            .opt => {}, // pointer like optional expected
            else => unreachable,
        }
        const bits = ty.bitSize(zcu);
        const bytes: usize = @intCast(std.mem.alignForward(u64, bits, 8) / 8);

        var stack = std.heap.stackFallback(32, o.gpa);
        const allocator = stack.get();

        const limbs = try allocator.alloc(
            std.math.big.Limb,
            std.mem.alignForward(usize, bytes, @sizeOf(std.math.big.Limb)) /
                @sizeOf(std.math.big.Limb),
        );
        defer allocator.free(limbs);
        @memset(limbs, 0);

        val.writeToPackedMemory(ty, pt, std.mem.sliceAsBytes(limbs)[0..bytes], 0) catch unreachable;

        if (builtin.target.cpu.arch.endian() == .little) {
            if (target.cpu.arch.endian() == .big)
                std.mem.reverse(u8, std.mem.sliceAsBytes(limbs)[0..bytes]);
        } else if (target.cpu.arch.endian() == .little) {
            for (limbs) |*limb| {
                limb.* = std.mem.nativeToLittle(usize, limb.*);
            }
        }

        return o.builder.bigIntConst(llvm_int_ty, .{
            .limbs = limbs,
            .positive = true,
        });
    }

    fn lowerValue(o: *Object, pt: Zcu.PerThread, arg_val: InternPool.Index) Error!Builder.Constant {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const target = zcu.getTarget();

        const val = Value.fromInterned(arg_val);
        const val_key = ip.indexToKey(val.toIntern());

        if (val.isUndef(zcu)) {
            return o.builder.undefConst(try o.lowerType(pt, Type.fromInterned(val_key.typeOf())));
        }

        const ty = Type.fromInterned(val_key.typeOf());
        return switch (val_key) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .struct_type,
            .tuple_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .func_type,
            .error_set_type,
            .inferred_error_set_type,
            => unreachable, // types, not values

            .undef => unreachable, // handled above
            .simple_value => |simple_value| switch (simple_value) {
                .undefined => unreachable, // non-runtime value
                .void => unreachable, // non-runtime value
                .null => unreachable, // non-runtime value
                .empty_tuple => unreachable, // non-runtime value
                .@"unreachable" => unreachable, // non-runtime value

                .false => .false,
                .true => .true,
            },
            .variable,
            .enum_literal,
            .empty_enum_value,
            => unreachable, // non-runtime values
            .@"extern" => |@"extern"| {
                const function_index = try o.resolveLlvmFunction(pt, @"extern".owner_nav);
                return function_index.ptrConst(&o.builder).global.toConst();
            },
            .func => |func| {
                const function_index = try o.resolveLlvmFunction(pt, func.owner_nav);
                return function_index.ptrConst(&o.builder).global.toConst();
            },
            .int => {
                var bigint_space: Value.BigIntSpace = undefined;
                const bigint = val.toBigInt(&bigint_space, zcu);
                return lowerBigInt(o, pt, ty, bigint);
            },
            .err => |err| {
                const int = try pt.getErrorValue(err.name);
                const llvm_int = try o.builder.intConst(try o.errorIntType(pt), int);
                return llvm_int;
            },
            .error_union => |error_union| {
                const err_val = switch (error_union.val) {
                    .err_name => |err_name| try pt.intern(.{ .err = .{
                        .ty = ty.errorUnionSet(zcu).toIntern(),
                        .name = err_name,
                    } }),
                    .payload => (try pt.intValue(try pt.errorIntType(), 0)).toIntern(),
                };
                const err_int_ty = try pt.errorIntType();
                const payload_type = ty.errorUnionPayload(zcu);
                if (!payload_type.hasRuntimeBitsIgnoreComptime(zcu)) {
                    // We use the error type directly as the type.
                    return o.lowerValue(pt, err_val);
                }

                const payload_align = payload_type.abiAlignment(zcu);
                const error_align = err_int_ty.abiAlignment(zcu);
                const llvm_error_value = try o.lowerValue(pt, err_val);
                const llvm_payload_value = try o.lowerValue(pt, switch (error_union.val) {
                    .err_name => try pt.intern(.{ .undef = payload_type.toIntern() }),
                    .payload => |payload| payload,
                });

                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                if (error_align.compare(.gt, payload_align)) {
                    vals[0] = llvm_error_value;
                    vals[1] = llvm_payload_value;
                } else {
                    vals[0] = llvm_payload_value;
                    vals[1] = llvm_error_value;
                }
                fields[0] = vals[0].typeOf(&o.builder);
                fields[1] = vals[1].typeOf(&o.builder);

                const llvm_ty = try o.lowerType(pt, ty);
                const llvm_ty_fields = llvm_ty.structFields(&o.builder);
                if (llvm_ty_fields.len > 2) {
                    assert(llvm_ty_fields.len == 3);
                    fields[2] = llvm_ty_fields[2];
                    vals[2] = try o.builder.undefConst(fields[2]);
                }
                return o.builder.structConst(try o.builder.structType(
                    llvm_ty.structKind(&o.builder),
                    fields[0..llvm_ty_fields.len],
                ), vals[0..llvm_ty_fields.len]);
            },
            .enum_tag => |enum_tag| o.lowerValue(pt, enum_tag.int),
            .float => switch (ty.floatBits(target)) {
                16 => if (backendSupportsF16(target))
                    try o.builder.halfConst(val.toFloat(f16, zcu))
                else
                    try o.builder.intConst(.i16, @as(i16, @bitCast(val.toFloat(f16, zcu)))),
                32 => try o.builder.floatConst(val.toFloat(f32, zcu)),
                64 => try o.builder.doubleConst(val.toFloat(f64, zcu)),
                80 => if (backendSupportsF80(target))
                    try o.builder.x86_fp80Const(val.toFloat(f80, zcu))
                else
                    try o.builder.intConst(.i80, @as(i80, @bitCast(val.toFloat(f80, zcu)))),
                128 => try o.builder.fp128Const(val.toFloat(f128, zcu)),
                else => unreachable,
            },
            .ptr => try o.lowerPtr(pt, arg_val, 0),
            .slice => |slice| return o.builder.structConst(try o.lowerType(pt, ty), &.{
                try o.lowerValue(pt, slice.ptr),
                try o.lowerValue(pt, slice.len),
            }),
            .opt => |opt| {
                comptime assert(optional_layout_version == 3);
                const payload_ty = ty.optionalChild(zcu);

                const non_null_bit = try o.builder.intConst(.i8, @intFromBool(opt.val != .none));
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    return non_null_bit;
                }
                const llvm_ty = try o.lowerType(pt, ty);
                if (ty.optionalReprIsPayload(zcu)) return switch (opt.val) {
                    .none => switch (llvm_ty.tag(&o.builder)) {
                        .integer => try o.builder.intConst(llvm_ty, 0),
                        .pointer => try o.builder.nullConst(llvm_ty),
                        .structure => try o.builder.zeroInitConst(llvm_ty),
                        else => unreachable,
                    },
                    else => |payload| try o.lowerValue(pt, payload),
                };
                assert(payload_ty.zigTypeTag(zcu) != .@"fn");

                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                vals[0] = try o.lowerValue(pt, switch (opt.val) {
                    .none => try pt.intern(.{ .undef = payload_ty.toIntern() }),
                    else => |payload| payload,
                });
                vals[1] = non_null_bit;
                fields[0] = vals[0].typeOf(&o.builder);
                fields[1] = vals[1].typeOf(&o.builder);

                const llvm_ty_fields = llvm_ty.structFields(&o.builder);
                if (llvm_ty_fields.len > 2) {
                    assert(llvm_ty_fields.len == 3);
                    fields[2] = llvm_ty_fields[2];
                    vals[2] = try o.builder.undefConst(fields[2]);
                }
                return o.builder.structConst(try o.builder.structType(
                    llvm_ty.structKind(&o.builder),
                    fields[0..llvm_ty_fields.len],
                ), vals[0..llvm_ty_fields.len]);
            },
            .aggregate => |aggregate| switch (ip.indexToKey(ty.toIntern())) {
                .array_type => |array_type| switch (aggregate.storage) {
                    .bytes => |bytes| try o.builder.stringConst(try o.builder.string(
                        bytes.toSlice(array_type.lenIncludingSentinel(), ip),
                    )),
                    .elems => |elems| {
                        const array_ty = try o.lowerType(pt, ty);
                        const elem_ty = array_ty.childType(&o.builder);
                        assert(elems.len == array_ty.aggregateLen(&o.builder));

                        const ExpectedContents = extern struct {
                            vals: [Builder.expected_fields_len]Builder.Constant,
                            fields: [Builder.expected_fields_len]Builder.Type,
                        };
                        var stack align(@max(
                            @alignOf(std.heap.StackFallbackAllocator(0)),
                            @alignOf(ExpectedContents),
                        )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                        const allocator = stack.get();
                        const vals = try allocator.alloc(Builder.Constant, elems.len);
                        defer allocator.free(vals);
                        const fields = try allocator.alloc(Builder.Type, elems.len);
                        defer allocator.free(fields);

                        var need_unnamed = false;
                        for (vals, fields, elems) |*result_val, *result_field, elem| {
                            result_val.* = try o.lowerValue(pt, elem);
                            result_field.* = result_val.typeOf(&o.builder);
                            if (result_field.* != elem_ty) need_unnamed = true;
                        }
                        return if (need_unnamed) try o.builder.structConst(
                            try o.builder.structType(.normal, fields),
                            vals,
                        ) else try o.builder.arrayConst(array_ty, vals);
                    },
                    .repeated_elem => |elem| {
                        const len: usize = @intCast(array_type.len);
                        const len_including_sentinel: usize = @intCast(array_type.lenIncludingSentinel());
                        const array_ty = try o.lowerType(pt, ty);
                        const elem_ty = array_ty.childType(&o.builder);

                        const ExpectedContents = extern struct {
                            vals: [Builder.expected_fields_len]Builder.Constant,
                            fields: [Builder.expected_fields_len]Builder.Type,
                        };
                        var stack align(@max(
                            @alignOf(std.heap.StackFallbackAllocator(0)),
                            @alignOf(ExpectedContents),
                        )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                        const allocator = stack.get();
                        const vals = try allocator.alloc(Builder.Constant, len_including_sentinel);
                        defer allocator.free(vals);
                        const fields = try allocator.alloc(Builder.Type, len_including_sentinel);
                        defer allocator.free(fields);

                        var need_unnamed = false;
                        @memset(vals[0..len], try o.lowerValue(pt, elem));
                        @memset(fields[0..len], vals[0].typeOf(&o.builder));
                        if (fields[0] != elem_ty) need_unnamed = true;

                        if (array_type.sentinel != .none) {
                            vals[len] = try o.lowerValue(pt, array_type.sentinel);
                            fields[len] = vals[len].typeOf(&o.builder);
                            if (fields[len] != elem_ty) need_unnamed = true;
                        }

                        return if (need_unnamed) try o.builder.structConst(
                            try o.builder.structType(.@"packed", fields),
                            vals,
                        ) else try o.builder.arrayConst(array_ty, vals);
                    },
                },
                .vector_type => |vector_type| {
                    const vector_ty = try o.lowerType(pt, ty);
                    switch (aggregate.storage) {
                        .bytes, .elems => {
                            const ExpectedContents = [Builder.expected_fields_len]Builder.Constant;
                            var stack align(@max(
                                @alignOf(std.heap.StackFallbackAllocator(0)),
                                @alignOf(ExpectedContents),
                            )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                            const allocator = stack.get();
                            const vals = try allocator.alloc(Builder.Constant, vector_type.len);
                            defer allocator.free(vals);

                            switch (aggregate.storage) {
                                .bytes => |bytes| for (vals, bytes.toSlice(vector_type.len, ip)) |*result_val, byte| {
                                    result_val.* = try o.builder.intConst(.i8, byte);
                                },
                                .elems => |elems| for (vals, elems) |*result_val, elem| {
                                    result_val.* = try o.lowerValue(pt, elem);
                                },
                                .repeated_elem => unreachable,
                            }
                            return o.builder.vectorConst(vector_ty, vals);
                        },
                        .repeated_elem => |elem| return o.builder.splatConst(
                            vector_ty,
                            try o.lowerValue(pt, elem),
                        ),
                    }
                },
                .tuple_type => |tuple| {
                    const struct_ty = try o.lowerType(pt, ty);
                    const llvm_len = struct_ty.aggregateLen(&o.builder);

                    const ExpectedContents = extern struct {
                        vals: [Builder.expected_fields_len]Builder.Constant,
                        fields: [Builder.expected_fields_len]Builder.Type,
                    };
                    var stack align(@max(
                        @alignOf(std.heap.StackFallbackAllocator(0)),
                        @alignOf(ExpectedContents),
                    )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                    const allocator = stack.get();
                    const vals = try allocator.alloc(Builder.Constant, llvm_len);
                    defer allocator.free(vals);
                    const fields = try allocator.alloc(Builder.Type, llvm_len);
                    defer allocator.free(fields);

                    comptime assert(struct_layout_version == 2);
                    var llvm_index: usize = 0;
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .none;
                    var need_unnamed = false;
                    for (
                        tuple.types.get(ip),
                        tuple.values.get(ip),
                        0..,
                    ) |field_ty, field_val, field_index| {
                        if (field_val != .none) continue;
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        const field_align = Type.fromInterned(field_ty).abiAlignment(zcu);
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            // TODO make this and all other padding elsewhere in debug
                            // builds be 0xaa not undef.
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }

                        vals[llvm_index] =
                            try o.lowerValue(pt, (try val.fieldValue(pt, field_index)).toIntern());
                        fields[llvm_index] = vals[llvm_index].typeOf(&o.builder);
                        if (fields[llvm_index] != struct_ty.structFields(&o.builder)[llvm_index])
                            need_unnamed = true;
                        llvm_index += 1;

                        offset += Type.fromInterned(field_ty).abiSize(zcu);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }
                    }
                    assert(llvm_index == llvm_len);

                    return o.builder.structConst(if (need_unnamed)
                        try o.builder.structType(struct_ty.structKind(&o.builder), fields)
                    else
                        struct_ty, vals);
                },
                .struct_type => {
                    const struct_type = ip.loadStructType(ty.toIntern());
                    assert(struct_type.haveLayout(ip));
                    const struct_ty = try o.lowerType(pt, ty);
                    if (struct_type.layout == .@"packed") {
                        comptime assert(Type.packed_struct_layout_version == 2);

                        const bits = ty.bitSize(zcu);
                        const llvm_int_ty = try o.builder.intType(@intCast(bits));

                        return o.lowerValueToInt(pt, llvm_int_ty, arg_val);
                    }
                    const llvm_len = struct_ty.aggregateLen(&o.builder);

                    const ExpectedContents = extern struct {
                        vals: [Builder.expected_fields_len]Builder.Constant,
                        fields: [Builder.expected_fields_len]Builder.Type,
                    };
                    var stack align(@max(
                        @alignOf(std.heap.StackFallbackAllocator(0)),
                        @alignOf(ExpectedContents),
                    )) = std.heap.stackFallback(@sizeOf(ExpectedContents), o.gpa);
                    const allocator = stack.get();
                    const vals = try allocator.alloc(Builder.Constant, llvm_len);
                    defer allocator.free(vals);
                    const fields = try allocator.alloc(Builder.Type, llvm_len);
                    defer allocator.free(fields);

                    comptime assert(struct_layout_version == 2);
                    var llvm_index: usize = 0;
                    var offset: u64 = 0;
                    var big_align: InternPool.Alignment = .@"1";
                    var need_unnamed = false;
                    var field_it = struct_type.iterateRuntimeOrder(ip);
                    while (field_it.next()) |field_index| {
                        const field_ty = Type.fromInterned(struct_type.field_types.get(ip)[field_index]);
                        const field_align = ty.fieldAlignment(field_index, zcu);
                        big_align = big_align.max(field_align);
                        const prev_offset = offset;
                        offset = field_align.forward(offset);

                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            // TODO make this and all other padding elsewhere in debug
                            // builds be 0xaa not undef.
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] ==
                                struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }

                        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                            // This is a zero-bit field - we only needed it for the alignment.
                            continue;
                        }

                        vals[llvm_index] = try o.lowerValue(
                            pt,
                            (try val.fieldValue(pt, field_index)).toIntern(),
                        );
                        fields[llvm_index] = vals[llvm_index].typeOf(&o.builder);
                        if (fields[llvm_index] != struct_ty.structFields(&o.builder)[llvm_index])
                            need_unnamed = true;
                        llvm_index += 1;

                        offset += field_ty.abiSize(zcu);
                    }
                    {
                        const prev_offset = offset;
                        offset = big_align.forward(offset);
                        const padding_len = offset - prev_offset;
                        if (padding_len > 0) {
                            fields[llvm_index] = try o.builder.arrayType(padding_len, .i8);
                            vals[llvm_index] = try o.builder.undefConst(fields[llvm_index]);
                            assert(fields[llvm_index] == struct_ty.structFields(&o.builder)[llvm_index]);
                            llvm_index += 1;
                        }
                    }
                    assert(llvm_index == llvm_len);

                    return o.builder.structConst(if (need_unnamed)
                        try o.builder.structType(struct_ty.structKind(&o.builder), fields)
                    else
                        struct_ty, vals);
                },
                else => unreachable,
            },
            .un => |un| {
                const union_ty = try o.lowerType(pt, ty);
                const layout = ty.unionGetLayout(zcu);
                if (layout.payload_size == 0) return o.lowerValue(pt, un.tag);

                const union_obj = zcu.typeToUnion(ty).?;
                const container_layout = union_obj.flagsUnordered(ip).layout;

                var need_unnamed = false;
                const payload = if (un.tag != .none) p: {
                    const field_index = zcu.unionTagFieldIndex(union_obj, Value.fromInterned(un.tag)).?;
                    const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
                    if (container_layout == .@"packed") {
                        if (!field_ty.hasRuntimeBits(zcu)) return o.builder.intConst(union_ty, 0);
                        const bits = ty.bitSize(zcu);
                        const llvm_int_ty = try o.builder.intType(@intCast(bits));

                        return o.lowerValueToInt(pt, llvm_int_ty, arg_val);
                    }

                    // Sometimes we must make an unnamed struct because LLVM does
                    // not support bitcasting our payload struct to the true union payload type.
                    // Instead we use an unnamed struct and every reference to the global
                    // must pointer cast to the expected type before accessing the union.
                    need_unnamed = layout.most_aligned_field != field_index;

                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                        const padding_len = layout.payload_size;
                        break :p try o.builder.undefConst(try o.builder.arrayType(padding_len, .i8));
                    }
                    const payload = try o.lowerValue(pt, un.val);
                    const payload_ty = payload.typeOf(&o.builder);
                    if (payload_ty != union_ty.structFields(&o.builder)[
                        @intFromBool(layout.tag_align.compare(.gte, layout.payload_align))
                    ]) need_unnamed = true;
                    const field_size = field_ty.abiSize(zcu);
                    if (field_size == layout.payload_size) break :p payload;
                    const padding_len = layout.payload_size - field_size;
                    const padding_ty = try o.builder.arrayType(padding_len, .i8);
                    break :p try o.builder.structConst(
                        try o.builder.structType(.@"packed", &.{ payload_ty, padding_ty }),
                        &.{ payload, try o.builder.undefConst(padding_ty) },
                    );
                } else p: {
                    assert(layout.tag_size == 0);
                    if (container_layout == .@"packed") {
                        const bits = ty.bitSize(zcu);
                        const llvm_int_ty = try o.builder.intType(@intCast(bits));

                        return o.lowerValueToInt(pt, llvm_int_ty, arg_val);
                    }

                    const union_val = try o.lowerValue(pt, un.val);
                    need_unnamed = true;
                    break :p union_val;
                };

                const payload_ty = payload.typeOf(&o.builder);
                if (layout.tag_size == 0) return o.builder.structConst(if (need_unnamed)
                    try o.builder.structType(union_ty.structKind(&o.builder), &.{payload_ty})
                else
                    union_ty, &.{payload});
                const tag = try o.lowerValue(pt, un.tag);
                const tag_ty = tag.typeOf(&o.builder);
                var fields: [3]Builder.Type = undefined;
                var vals: [3]Builder.Constant = undefined;
                var len: usize = 2;
                if (layout.tag_align.compare(.gte, layout.payload_align)) {
                    fields = .{ tag_ty, payload_ty, undefined };
                    vals = .{ tag, payload, undefined };
                } else {
                    fields = .{ payload_ty, tag_ty, undefined };
                    vals = .{ payload, tag, undefined };
                }
                if (layout.padding != 0) {
                    fields[2] = try o.builder.arrayType(layout.padding, .i8);
                    vals[2] = try o.builder.undefConst(fields[2]);
                    len = 3;
                }
                return o.builder.structConst(if (need_unnamed)
                    try o.builder.structType(union_ty.structKind(&o.builder), fields[0..len])
                else
                    union_ty, vals[0..len]);
            },
            .memoized_call => unreachable,
        };
    }

    fn lowerBigInt(
        o: *Object,
        pt: Zcu.PerThread,
        ty: Type,
        bigint: std.math.big.int.Const,
    ) Allocator.Error!Builder.Constant {
        const zcu = pt.zcu;
        return o.builder.bigIntConst(try o.builder.intType(ty.intInfo(zcu).bits), bigint);
    }

    fn lowerPtr(
        o: *Object,
        pt: Zcu.PerThread,
        ptr_val: InternPool.Index,
        prev_offset: u64,
    ) Error!Builder.Constant {
        const zcu = pt.zcu;
        const ptr = zcu.intern_pool.indexToKey(ptr_val).ptr;
        const offset: u64 = prev_offset + ptr.byte_offset;
        return switch (ptr.base_addr) {
            .nav => |nav| {
                const base_ptr = try o.lowerNavRefValue(pt, nav);
                return o.builder.gepConst(.inbounds, .i8, base_ptr, null, &.{
                    try o.builder.intConst(.i64, offset),
                });
            },
            .uav => |uav| {
                const base_ptr = try o.lowerUavRef(pt, uav);
                return o.builder.gepConst(.inbounds, .i8, base_ptr, null, &.{
                    try o.builder.intConst(.i64, offset),
                });
            },
            .int => try o.builder.castConst(
                .inttoptr,
                try o.builder.intConst(try o.lowerType(pt, Type.usize), offset),
                try o.lowerType(pt, Type.fromInterned(ptr.ty)),
            ),
            .eu_payload => |eu_ptr| try o.lowerPtr(
                pt,
                eu_ptr,
                offset + codegen.errUnionPayloadOffset(
                    Value.fromInterned(eu_ptr).typeOf(zcu).childType(zcu),
                    zcu,
                ),
            ),
            .opt_payload => |opt_ptr| try o.lowerPtr(pt, opt_ptr, offset),
            .field => |field| {
                const agg_ty = Value.fromInterned(field.base).typeOf(zcu).childType(zcu);
                const field_off: u64 = switch (agg_ty.zigTypeTag(zcu)) {
                    .pointer => off: {
                        assert(agg_ty.isSlice(zcu));
                        break :off switch (field.index) {
                            Value.slice_ptr_index => 0,
                            Value.slice_len_index => @divExact(zcu.getTarget().ptrBitWidth(), 8),
                            else => unreachable,
                        };
                    },
                    .@"struct", .@"union" => switch (agg_ty.containerLayout(zcu)) {
                        .auto => agg_ty.structFieldOffset(@intCast(field.index), zcu),
                        .@"extern", .@"packed" => unreachable,
                    },
                    else => unreachable,
                };
                return o.lowerPtr(pt, field.base, offset + field_off);
            },
            .arr_elem, .comptime_field, .comptime_alloc => unreachable,
        };
    }

    /// This logic is very similar to `lowerNavRefValue` but for anonymous declarations.
    /// Maybe the logic could be unified.
    fn lowerUavRef(
        o: *Object,
        pt: Zcu.PerThread,
        uav: InternPool.Key.Ptr.BaseAddr.Uav,
    ) Error!Builder.Constant {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const uav_val = uav.val;
        const uav_ty = Type.fromInterned(ip.typeOf(uav_val));
        const target = zcu.getTarget();

        switch (ip.indexToKey(uav_val)) {
            .func => @panic("TODO"),
            .@"extern" => @panic("TODO"),
            else => {},
        }

        const ptr_ty = Type.fromInterned(uav.orig_ty);

        const is_fn_body = uav_ty.zigTypeTag(zcu) == .@"fn";
        if ((!is_fn_body and !uav_ty.hasRuntimeBits(zcu)) or
            (is_fn_body and zcu.typeToFunc(uav_ty).?.is_generic)) return o.lowerPtrToVoid(pt, ptr_ty);

        if (is_fn_body)
            @panic("TODO");

        const llvm_addr_space = toLlvmAddressSpace(ptr_ty.ptrAddressSpace(zcu), target);
        const alignment = ptr_ty.ptrAlignment(zcu);
        const llvm_global = (try o.resolveGlobalUav(pt, uav.val, llvm_addr_space, alignment)).ptrConst(&o.builder).global;

        const llvm_val = try o.builder.convConst(
            llvm_global.toConst(),
            try o.builder.ptrType(llvm_addr_space),
        );

        return o.builder.convConst(llvm_val, try o.lowerType(pt, ptr_ty));
    }

    fn lowerNavRefValue(o: *Object, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) Allocator.Error!Builder.Constant {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;

        const nav = ip.getNav(nav_index);

        const nav_ty = Type.fromInterned(nav.typeOf(ip));
        const ptr_ty = try pt.navPtrType(nav_index);

        const is_fn_body = nav_ty.zigTypeTag(zcu) == .@"fn";
        if ((!is_fn_body and !nav_ty.hasRuntimeBits(zcu)) or
            (is_fn_body and zcu.typeToFunc(nav_ty).?.is_generic))
        {
            return o.lowerPtrToVoid(pt, ptr_ty);
        }

        const llvm_global = if (is_fn_body)
            (try o.resolveLlvmFunction(pt, nav_index)).ptrConst(&o.builder).global
        else
            (try o.resolveGlobalNav(pt, nav_index)).ptrConst(&o.builder).global;

        const llvm_val = try o.builder.convConst(
            llvm_global.toConst(),
            try o.builder.ptrType(toLlvmAddressSpace(nav.getAddrspace(), zcu.getTarget())),
        );

        return o.builder.convConst(llvm_val, try o.lowerType(pt, ptr_ty));
    }

    fn lowerPtrToVoid(o: *Object, pt: Zcu.PerThread, ptr_ty: Type) Allocator.Error!Builder.Constant {
        const zcu = pt.zcu;
        // Even though we are pointing at something which has zero bits (e.g. `void`),
        // Pointers are defined to have bits. So we must return something here.
        // The value cannot be undefined, because we use the `nonnull` annotation
        // for non-optional pointers. We also need to respect the alignment, even though
        // the address will never be dereferenced.
        const int: u64 = ptr_ty.ptrInfo(zcu).flags.alignment.toByteUnits() orelse
            // Note that these 0xaa values are appropriate even in release-optimized builds
            // because we need a well-defined value that is not null, and LLVM does not
            // have an "undef_but_not_null" attribute. As an example, if this `alloc` AIR
            // instruction is followed by a `wrap_optional`, it will return this value
            // verbatim, and the result should test as non-null.
            switch (zcu.getTarget().ptrBitWidth()) {
                16 => 0xaaaa,
                32 => 0xaaaaaaaa,
                64 => 0xaaaaaaaa_aaaaaaaa,
                else => unreachable,
            };
        const llvm_usize = try o.lowerType(pt, Type.usize);
        const llvm_ptr_ty = try o.lowerType(pt, ptr_ty);
        return o.builder.castConst(.inttoptr, try o.builder.intConst(llvm_usize, int), llvm_ptr_ty);
    }

    /// If the operand type of an atomic operation is not byte sized we need to
    /// widen it before using it and then truncate the result.
    /// RMW exchange of floating-point values is bitcasted to same-sized integer
    /// types to work around a LLVM deficiency when targeting ARM/AArch64.
    fn getAtomicAbiType(o: *Object, pt: Zcu.PerThread, ty: Type, is_rmw_xchg: bool) Allocator.Error!Builder.Type {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const int_ty = switch (ty.zigTypeTag(zcu)) {
            .int => ty,
            .@"enum" => ty.intTagType(zcu),
            .@"struct" => Type.fromInterned(ip.loadStructType(ty.toIntern()).backingIntTypeUnordered(ip)),
            .float => {
                if (!is_rmw_xchg) return .none;
                return o.builder.intType(@intCast(ty.abiSize(zcu) * 8));
            },
            .bool => return .i8,
            else => return .none,
        };
        const bit_count = int_ty.intInfo(zcu).bits;
        if (!std.math.isPowerOfTwo(bit_count) or (bit_count % 8) != 0) {
            return o.builder.intType(@intCast(int_ty.abiSize(zcu) * 8));
        } else {
            return .none;
        }
    }

    fn addByValParamAttrs(
        o: *Object,
        pt: Zcu.PerThread,
        attributes: *Builder.FunctionAttributes.Wip,
        param_ty: Type,
        param_index: u32,
        fn_info: InternPool.Key.FuncType,
        llvm_arg_i: u32,
    ) Allocator.Error!void {
        const zcu = pt.zcu;
        if (param_ty.isPtrAtRuntime(zcu)) {
            const ptr_info = param_ty.ptrInfo(zcu);
            if (math.cast(u5, param_index)) |i| {
                if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                    try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                }
            }
            if (!param_ty.isPtrLikeOptional(zcu) and
                !ptr_info.flags.is_allowzero and
                ptr_info.flags.address_space == .generic)
            {
                try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
            }
            switch (fn_info.cc) {
                else => {},
                .x86_64_interrupt,
                .x86_interrupt,
                => {
                    const child_type = try lowerType(o, pt, Type.fromInterned(ptr_info.child));
                    try attributes.addParamAttr(llvm_arg_i, .{ .byval = child_type }, &o.builder);
                },
            }
            if (ptr_info.flags.is_const) {
                try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
            }
            const elem_align = if (ptr_info.flags.alignment != .none)
                ptr_info.flags.alignment
            else
                Type.fromInterned(ptr_info.child).abiAlignment(zcu).max(.@"1");
            try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align.toLlvm() }, &o.builder);
        } else if (ccAbiPromoteInt(fn_info.cc, zcu, param_ty)) |s| switch (s) {
            .signed => try attributes.addParamAttr(llvm_arg_i, .signext, &o.builder),
            .unsigned => try attributes.addParamAttr(llvm_arg_i, .zeroext, &o.builder),
        };
    }

    fn addByRefParamAttrs(
        o: *Object,
        attributes: *Builder.FunctionAttributes.Wip,
        llvm_arg_i: u32,
        alignment: Builder.Alignment,
        byval: bool,
        param_llvm_ty: Builder.Type,
    ) Allocator.Error!void {
        try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
        try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
        try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = alignment }, &o.builder);
        if (byval) try attributes.addParamAttr(llvm_arg_i, .{ .byval = param_llvm_ty }, &o.builder);
    }

    fn llvmFieldIndex(o: *Object, struct_ty: Type, field_index: usize) ?c_uint {
        return o.struct_field_map.get(.{
            .struct_ty = struct_ty.toIntern(),
            .field_index = @intCast(field_index),
        });
    }

    fn getCmpLtErrorsLenFunction(o: *Object, pt: Zcu.PerThread) !Builder.Function.Index {
        const name = try o.builder.strtabString(lt_errors_fn_name);
        if (o.builder.getGlobal(name)) |llvm_fn| return llvm_fn.ptrConst(&o.builder).kind.function;

        const zcu = pt.zcu;
        const target = &zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(.i1, &.{try o.errorIntType(pt)}, .normal),
            name,
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod, zcu.root_mod.omit_frame_pointer);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        return function_index;
    }

    fn getEnumTagNameFunction(o: *Object, pt: Zcu.PerThread, enum_ty: Type) !Builder.Function.Index {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const enum_type = ip.loadEnumType(enum_ty.toIntern());

        const gop = try o.enum_tag_name_map.getOrPut(o.gpa, enum_ty.toIntern());
        if (gop.found_existing) return gop.value_ptr.ptrConst(&o.builder).kind.function;
        errdefer assert(o.enum_tag_name_map.remove(enum_ty.toIntern()));

        const usize_ty = try o.lowerType(pt, Type.usize);
        const ret_ty = try o.lowerType(pt, Type.slice_const_u8_sentinel_0);
        const target = &zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(ret_ty, &.{try o.lowerType(pt, Type.fromInterned(enum_type.tag_ty))}, .normal),
            try o.builder.strtabStringFmt("__zig_tag_name_{f}", .{enum_type.name.fmt(ip)}),
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod, zcu.root_mod.omit_frame_pointer);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        gop.value_ptr.* = function_index.ptrConst(&o.builder).global;

        var wip = try Builder.WipFunction.init(&o.builder, .{
            .function = function_index,
            .strip = true,
        });
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        const bad_value_block = try wip.block(1, "BadValue");
        const tag_int_value = wip.arg(0);
        var wip_switch =
            try wip.@"switch"(tag_int_value, bad_value_block, @intCast(enum_type.names.len), .none);
        defer wip_switch.finish(&wip);

        for (0..enum_type.names.len) |field_index| {
            const name = try o.builder.stringNull(enum_type.names.get(ip)[field_index].toSlice(ip));
            const name_init = try o.builder.stringConst(name);
            const name_variable_index =
                try o.builder.addVariable(.empty, name_init.typeOf(&o.builder), .default);
            try name_variable_index.setInitializer(name_init, &o.builder);
            name_variable_index.setLinkage(.private, &o.builder);
            name_variable_index.setMutability(.constant, &o.builder);
            name_variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
            name_variable_index.setAlignment(comptime Builder.Alignment.fromByteUnits(1), &o.builder);

            const name_val = try o.builder.structValue(ret_ty, &.{
                name_variable_index.toConst(&o.builder),
                try o.builder.intConst(usize_ty, name.slice(&o.builder).?.len - 1),
            });

            const return_block = try wip.block(1, "Name");
            const this_tag_int_value = try o.lowerValue(
                pt,
                (try pt.enumValueFieldIndex(enum_ty, @intCast(field_index))).toIntern(),
            );
            try wip_switch.addCase(this_tag_int_value, return_block, &wip);

            wip.cursor = .{ .block = return_block };
            _ = try wip.ret(name_val);
        }

        wip.cursor = .{ .block = bad_value_block };
        _ = try wip.@"unreachable"();

        try wip.finish();
        return function_index;
    }
};

pub const NavGen = struct {
    object: *Object,
    nav_index: InternPool.Nav.Index,
    pt: Zcu.PerThread,
    err_msg: ?*Zcu.ErrorMsg,

    fn ownerModule(ng: NavGen) *Package.Module {
        return ng.pt.zcu.navFileScope(ng.nav_index).mod.?;
    }

    fn todo(ng: *NavGen, comptime format: []const u8, args: anytype) Error {
        @branchHint(.cold);
        assert(ng.err_msg == null);
        const o = ng.object;
        const gpa = o.gpa;
        const src_loc = ng.pt.zcu.navSrcLoc(ng.nav_index);
        ng.err_msg = try Zcu.ErrorMsg.create(gpa, src_loc, "TODO (LLVM): " ++ format, args);
        return error.CodegenFail;
    }

    fn genDecl(ng: *NavGen) !void {
        const o = ng.object;
        const pt = ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const nav_index = ng.nav_index;
        const nav = ip.getNav(nav_index);
        const resolved = nav.status.fully_resolved;

        const lib_name, const linkage, const visibility: Builder.Visibility, const is_threadlocal, const is_dll_import, const is_const, const init_val, const owner_nav = switch (ip.indexToKey(resolved.val)) {
            .variable => |variable| .{ .none, .internal, .default, variable.is_threadlocal, false, false, variable.init, variable.owner_nav },
            .@"extern" => |@"extern"| .{ @"extern".lib_name, @"extern".linkage, .fromSymbolVisibility(@"extern".visibility), @"extern".is_threadlocal, @"extern".is_dll_import, @"extern".is_const, .none, @"extern".owner_nav },
            else => .{ .none, .internal, .default, false, false, true, resolved.val, nav_index },
        };
        const ty = Type.fromInterned(nav.typeOf(ip));

        if (linkage != .internal and ip.isFunctionType(ty.toIntern())) {
            _ = try o.resolveLlvmFunction(pt, owner_nav);
        } else {
            const variable_index = try o.resolveGlobalNav(pt, nav_index);
            variable_index.setAlignment(pt.navAlignment(nav_index).toLlvm(), &o.builder);
            if (resolved.@"linksection".toSlice(ip)) |section|
                variable_index.setSection(try o.builder.string(section), &o.builder);
            if (is_const) variable_index.setMutability(.constant, &o.builder);
            try variable_index.setInitializer(switch (init_val) {
                .none => .no_init,
                else => try o.lowerValue(pt, init_val),
            }, &o.builder);
            variable_index.setVisibility(visibility, &o.builder);

            const file_scope = zcu.navFileScopeIndex(nav_index);
            const mod = zcu.fileByIndex(file_scope).mod.?;
            if (is_threadlocal and !mod.single_threaded)
                variable_index.setThreadLocal(.generaldynamic, &o.builder);

            const line_number = zcu.navSrcLine(nav_index) + 1;

            if (!mod.strip) {
                const debug_file = try o.getDebugFile(pt, file_scope);

                const debug_global_var = try o.builder.debugGlobalVar(
                    try o.builder.metadataString(nav.name.toSlice(ip)), // Name
                    try o.builder.metadataStringFromStrtabString(variable_index.name(&o.builder)), // Linkage name
                    debug_file, // File
                    debug_file, // Scope
                    line_number,
                    try o.lowerDebugType(pt, ty),
                    variable_index,
                    .{ .local = linkage == .internal },
                );

                const debug_expression = try o.builder.debugExpression(&.{});

                const debug_global_var_expression = try o.builder.debugGlobalVarExpression(
                    debug_global_var,
                    debug_expression,
                );

                variable_index.setGlobalVariableExpression(debug_global_var_expression, &o.builder);
                try o.debug_globals.append(o.gpa, debug_global_var_expression);
            }
        }

        switch (linkage) {
            .internal => {},
            .strong, .weak => {
                const global_index = o.nav_map.get(nav_index).?;

                const decl_name = decl_name: {
                    if (zcu.getTarget().cpu.arch.isWasm() and ty.zigTypeTag(zcu) == .@"fn") {
                        if (lib_name.toSlice(ip)) |lib_name_slice| {
                            if (!std.mem.eql(u8, lib_name_slice, "c")) {
                                break :decl_name try o.builder.strtabStringFmt("{f}|{s}", .{ nav.name.fmt(ip), lib_name_slice });
                            }
                        }
                    }
                    break :decl_name try o.builder.strtabString(nav.name.toSlice(ip));
                };

                if (o.builder.getGlobal(decl_name)) |other_global| {
                    if (other_global != global_index) {
                        // Another global already has this name; just use it in place of this global.
                        try global_index.replace(other_global, &o.builder);
                        return;
                    }
                }

                try global_index.rename(decl_name, &o.builder);
                global_index.setUnnamedAddr(.default, &o.builder);
                if (is_dll_import) {
                    global_index.setDllStorageClass(.dllimport, &o.builder);
                } else if (zcu.comp.config.dll_export_fns) {
                    global_index.setDllStorageClass(.default, &o.builder);
                }

                global_index.setLinkage(switch (linkage) {
                    .internal => unreachable,
                    .strong => .external,
                    .weak => .extern_weak,
                    .link_once => unreachable,
                }, &o.builder);
                global_index.setVisibility(visibility, &o.builder);
            },
            .link_once => unreachable,
        }
    }
};

pub const FuncGen = struct {
    gpa: Allocator,
    ng: *NavGen,
    air: Air,
    liveness: Air.Liveness,
    wip: Builder.WipFunction,
    is_naked: bool,
    fuzz: ?Fuzz,

    file: Builder.Metadata,
    scope: Builder.Metadata,

    inlined: Builder.DebugLocation = .no_location,

    base_line: u32,
    prev_dbg_line: c_uint,
    prev_dbg_column: c_uint,

    /// This stores the LLVM values used in a function, such that they can be referred to
    /// in other instructions. This table is cleared before every function is generated.
    func_inst_table: std.AutoHashMapUnmanaged(Air.Inst.Ref, Builder.Value),

    /// If the return type is sret, this is the result pointer. Otherwise null.
    /// Note that this can disagree with isByRef for the return type in the case
    /// of C ABI functions.
    ret_ptr: Builder.Value,
    /// Any function that needs to perform Valgrind client requests needs an array alloca
    /// instruction, however a maximum of one per function is needed.
    valgrind_client_request_array: Builder.Value = .none,
    /// These fields are used to refer to the LLVM value of the function parameters
    /// in an Arg instruction.
    /// This list may be shorter than the list according to the zig type system;
    /// it omits 0-bit types. If the function uses sret as the first parameter,
    /// this slice does not include it.
    args: []const Builder.Value,
    arg_index: u32,
    arg_inline_index: u32,

    err_ret_trace: Builder.Value = .none,

    /// This data structure is used to implement breaking to blocks.
    blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, struct {
        parent_bb: Builder.Function.Block.Index,
        breaks: *BreakList,
    }),

    /// Maps `loop` instructions to the bb to branch to to repeat the loop.
    loops: std.AutoHashMapUnmanaged(Air.Inst.Index, Builder.Function.Block.Index),

    /// Maps `loop_switch_br` instructions to the information required to lower
    /// dispatches (`switch_dispatch` instructions).
    switch_dispatch_info: std.AutoHashMapUnmanaged(Air.Inst.Index, SwitchDispatchInfo),

    sync_scope: Builder.SyncScope,

    disable_intrinsics: bool,

    /// Have we seen loads or stores involving `allowzero` pointers?
    allowzero_access: bool = false,

    pub fn maybeMarkAllowZeroAccess(self: *FuncGen, info: InternPool.Key.PtrType) void {
        // LLVM already considers null pointers to be valid in non-generic address spaces, so avoid
        // pessimizing optimization for functions with accesses to such pointers.
        if (info.flags.address_space == .generic and info.flags.is_allowzero) self.allowzero_access = true;
    }

    const Fuzz = struct {
        counters_variable: Builder.Variable.Index,
        pcs: std.ArrayListUnmanaged(Builder.Constant),

        fn deinit(f: *Fuzz, gpa: Allocator) void {
            f.pcs.deinit(gpa);
            f.* = undefined;
        }
    };

    const SwitchDispatchInfo = struct {
        /// These are the blocks corresponding to each switch case.
        /// The final element corresponds to the `else` case.
        /// Slices allocated into `gpa`.
        case_blocks: []Builder.Function.Block.Index,
        /// This is `.none` if `jmp_table` is set, since we won't use a `switch` instruction to dispatch.
        switch_weights: Builder.Function.Instruction.BrCond.Weights,
        /// If not `null`, we have manually constructed a jump table to reach the desired block.
        /// `table` can be used if the value is between `min` and `max` inclusive.
        /// We perform this lowering manually to avoid some questionable behavior from LLVM.
        /// See `airSwitchBr` for details.
        jmp_table: ?JmpTable,

        const JmpTable = struct {
            min: Builder.Constant,
            max: Builder.Constant,
            in_bounds_hint: enum { none, unpredictable, likely, unlikely },
            /// Pointer to the jump table itself, to be used with `indirectbr`.
            /// The index into the jump table is the dispatch condition minus `min`.
            /// The table values are `blockaddress` constants corresponding to blocks in `case_blocks`.
            table: Builder.Constant,
            /// `true` if `table` conatins a reference to the `else` block.
            /// In this case, the `indirectbr` must include the `else` block in its target list.
            table_includes_else: bool,
        };
    };

    const BreakList = union {
        list: std.MultiArrayList(struct {
            bb: Builder.Function.Block.Index,
            val: Builder.Value,
        }),
        len: usize,
    };

    fn deinit(self: *FuncGen) void {
        const gpa = self.gpa;
        if (self.fuzz) |*f| f.deinit(self.gpa);
        self.wip.deinit();
        self.func_inst_table.deinit(gpa);
        self.blocks.deinit(gpa);
        self.loops.deinit(gpa);
        var it = self.switch_dispatch_info.valueIterator();
        while (it.next()) |info| {
            self.gpa.free(info.case_blocks);
        }
        self.switch_dispatch_info.deinit(gpa);
    }

    fn todo(self: *FuncGen, comptime format: []const u8, args: anytype) Error {
        @branchHint(.cold);
        return self.ng.todo(format, args);
    }

    fn resolveInst(self: *FuncGen, inst: Air.Inst.Ref) !Builder.Value {
        const gpa = self.gpa;
        const gop = try self.func_inst_table.getOrPut(gpa, inst);
        if (gop.found_existing) return gop.value_ptr.*;

        const llvm_val = try self.resolveValue((try self.air.value(inst, self.ng.pt)).?);
        gop.value_ptr.* = llvm_val.toValue();
        return llvm_val.toValue();
    }

    fn resolveValue(self: *FuncGen, val: Value) Error!Builder.Constant {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty = val.typeOf(zcu);
        const llvm_val = try o.lowerValue(pt, val.toIntern());
        if (!isByRef(ty, zcu)) return llvm_val;

        // We have an LLVM value but we need to create a global constant and
        // set the value as its initializer, and then return a pointer to the global.
        const target = zcu.getTarget();
        const variable_index = try o.builder.addVariable(
            .empty,
            llvm_val.typeOf(&o.builder),
            toLlvmGlobalAddressSpace(.generic, target),
        );
        try variable_index.setInitializer(llvm_val, &o.builder);
        variable_index.setLinkage(.private, &o.builder);
        variable_index.setMutability(.constant, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(ty.abiAlignment(zcu).toLlvm(), &o.builder);
        return o.builder.convConst(
            variable_index.toConst(&o.builder),
            try o.builder.ptrType(toLlvmAddressSpace(.generic, target)),
        );
    }

    fn genBody(self: *FuncGen, body: []const Air.Inst.Index, coverage_point: Air.CoveragePoint) Error!void {
        const o = self.ng.object;
        const zcu = self.ng.pt.zcu;
        const ip = &zcu.intern_pool;
        const air_tags = self.air.instructions.items(.tag);
        switch (coverage_point) {
            .none => {},
            .poi => if (self.fuzz) |*fuzz| {
                const poi_index = fuzz.pcs.items.len;
                const base_ptr = fuzz.counters_variable.toValue(&o.builder);
                const ptr = if (poi_index == 0) base_ptr else try self.wip.gep(.inbounds, .i8, base_ptr, &.{
                    try o.builder.intValue(.i32, poi_index),
                }, "");
                const counter = try self.wip.load(.normal, .i8, ptr, .default, "");
                const one = try o.builder.intValue(.i8, 1);
                const counter_incremented = try self.wip.bin(.add, counter, one, "");
                _ = try self.wip.store(.normal, counter_incremented, ptr, .default);

                // LLVM does not allow blockaddress on the entry block.
                const pc = if (self.wip.cursor.block == .entry)
                    self.wip.function.toConst(&o.builder)
                else
                    try o.builder.blockAddrConst(self.wip.function, self.wip.cursor.block);
                const gpa = self.gpa;
                try fuzz.pcs.append(gpa, pc);
            },
        }
        for (body, 0..) |inst, i| {
            if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip)) continue;

            const val: Builder.Value = switch (air_tags[@intFromEnum(inst)]) {
                // zig fmt: off
                .add            => try self.airAdd(inst, .normal),
                .add_optimized  => try self.airAdd(inst, .fast),
                .add_wrap       => try self.airAddWrap(inst),
                .add_sat        => try self.airAddSat(inst),

                .sub            => try self.airSub(inst, .normal),
                .sub_optimized  => try self.airSub(inst, .fast),
                .sub_wrap       => try self.airSubWrap(inst),
                .sub_sat        => try self.airSubSat(inst),

                .mul           => try self.airMul(inst, .normal),
                .mul_optimized => try self.airMul(inst, .fast),
                .mul_wrap      => try self.airMulWrap(inst),
                .mul_sat       => try self.airMulSat(inst),

                .add_safe => try self.airSafeArithmetic(inst, .@"sadd.with.overflow", .@"uadd.with.overflow"),
                .sub_safe => try self.airSafeArithmetic(inst, .@"ssub.with.overflow", .@"usub.with.overflow"),
                .mul_safe => try self.airSafeArithmetic(inst, .@"smul.with.overflow", .@"umul.with.overflow"),

                .div_float => try self.airDivFloat(inst, .normal),
                .div_trunc => try self.airDivTrunc(inst, .normal),
                .div_floor => try self.airDivFloor(inst, .normal),
                .div_exact => try self.airDivExact(inst, .normal),
                .rem       => try self.airRem(inst, .normal),
                .mod       => try self.airMod(inst, .normal),
                .abs       => try self.airAbs(inst),
                .ptr_add   => try self.airPtrAdd(inst),
                .ptr_sub   => try self.airPtrSub(inst),
                .shl       => try self.airShl(inst),
                .shl_sat   => try self.airShlSat(inst),
                .shl_exact => try self.airShlExact(inst),
                .min       => try self.airMin(inst),
                .max       => try self.airMax(inst),
                .slice     => try self.airSlice(inst),
                .mul_add   => try self.airMulAdd(inst),

                .div_float_optimized => try self.airDivFloat(inst, .fast),
                .div_trunc_optimized => try self.airDivTrunc(inst, .fast),
                .div_floor_optimized => try self.airDivFloor(inst, .fast),
                .div_exact_optimized => try self.airDivExact(inst, .fast),
                .rem_optimized       => try self.airRem(inst, .fast),
                .mod_optimized       => try self.airMod(inst, .fast),

                .add_with_overflow => try self.airOverflow(inst, .@"sadd.with.overflow", .@"uadd.with.overflow"),
                .sub_with_overflow => try self.airOverflow(inst, .@"ssub.with.overflow", .@"usub.with.overflow"),
                .mul_with_overflow => try self.airOverflow(inst, .@"smul.with.overflow", .@"umul.with.overflow"),
                .shl_with_overflow => try self.airShlWithOverflow(inst),

                .bit_and, .bool_and => try self.airAnd(inst),
                .bit_or, .bool_or   => try self.airOr(inst),
                .xor                => try self.airXor(inst),
                .shr                => try self.airShr(inst, false),
                .shr_exact          => try self.airShr(inst, true),

                .sqrt         => try self.airUnaryOp(inst, .sqrt),
                .sin          => try self.airUnaryOp(inst, .sin),
                .cos          => try self.airUnaryOp(inst, .cos),
                .tan          => try self.airUnaryOp(inst, .tan),
                .exp          => try self.airUnaryOp(inst, .exp),
                .exp2         => try self.airUnaryOp(inst, .exp2),
                .log          => try self.airUnaryOp(inst, .log),
                .log2         => try self.airUnaryOp(inst, .log2),
                .log10        => try self.airUnaryOp(inst, .log10),
                .floor        => try self.airUnaryOp(inst, .floor),
                .ceil         => try self.airUnaryOp(inst, .ceil),
                .round        => try self.airUnaryOp(inst, .round),
                .trunc_float  => try self.airUnaryOp(inst, .trunc),

                .neg           => try self.airNeg(inst, .normal),
                .neg_optimized => try self.airNeg(inst, .fast),

                .cmp_eq  => try self.airCmp(inst, .eq, .normal),
                .cmp_gt  => try self.airCmp(inst, .gt, .normal),
                .cmp_gte => try self.airCmp(inst, .gte, .normal),
                .cmp_lt  => try self.airCmp(inst, .lt, .normal),
                .cmp_lte => try self.airCmp(inst, .lte, .normal),
                .cmp_neq => try self.airCmp(inst, .neq, .normal),

                .cmp_eq_optimized  => try self.airCmp(inst, .eq, .fast),
                .cmp_gt_optimized  => try self.airCmp(inst, .gt, .fast),
                .cmp_gte_optimized => try self.airCmp(inst, .gte, .fast),
                .cmp_lt_optimized  => try self.airCmp(inst, .lt, .fast),
                .cmp_lte_optimized => try self.airCmp(inst, .lte, .fast),
                .cmp_neq_optimized => try self.airCmp(inst, .neq, .fast),

                .cmp_vector           => try self.airCmpVector(inst, .normal),
                .cmp_vector_optimized => try self.airCmpVector(inst, .fast),
                .cmp_lt_errors_len    => try self.airCmpLtErrorsLen(inst),

                .is_non_null     => try self.airIsNonNull(inst, false, .ne),
                .is_non_null_ptr => try self.airIsNonNull(inst, true , .ne),
                .is_null         => try self.airIsNonNull(inst, false, .eq),
                .is_null_ptr     => try self.airIsNonNull(inst, true , .eq),

                .is_non_err      => try self.airIsErr(inst, .eq, false),
                .is_non_err_ptr  => try self.airIsErr(inst, .eq, true),
                .is_err          => try self.airIsErr(inst, .ne, false),
                .is_err_ptr      => try self.airIsErr(inst, .ne, true),

                .alloc          => try self.airAlloc(inst),
                .ret_ptr        => try self.airRetPtr(inst),
                .arg            => try self.airArg(inst),
                .bitcast        => try self.airBitCast(inst),
                .breakpoint     => try self.airBreakpoint(inst),
                .ret_addr       => try self.airRetAddr(inst),
                .frame_addr     => try self.airFrameAddress(inst),
                .@"try"         => try self.airTry(inst, false),
                .try_cold       => try self.airTry(inst, true),
                .try_ptr        => try self.airTryPtr(inst, false),
                .try_ptr_cold   => try self.airTryPtr(inst, true),
                .intcast        => try self.airIntCast(inst, false),
                .intcast_safe   => try self.airIntCast(inst, true),
                .trunc          => try self.airTrunc(inst),
                .fptrunc        => try self.airFptrunc(inst),
                .fpext          => try self.airFpext(inst),
                .load           => try self.airLoad(inst),
                .not            => try self.airNot(inst),
                .store          => try self.airStore(inst, false),
                .store_safe     => try self.airStore(inst, true),
                .assembly       => try self.airAssembly(inst),
                .slice_ptr      => try self.airSliceField(inst, 0),
                .slice_len      => try self.airSliceField(inst, 1),

                .ptr_slice_ptr_ptr => try self.airPtrSliceFieldPtr(inst, 0),
                .ptr_slice_len_ptr => try self.airPtrSliceFieldPtr(inst, 1),

                .int_from_float           => try self.airIntFromFloat(inst, .normal),
                .int_from_float_optimized => try self.airIntFromFloat(inst, .fast),
                .int_from_float_safe           => unreachable, // handled by `legalizeFeatures`
                .int_from_float_optimized_safe => unreachable, // handled by `legalizeFeatures`

                .array_to_slice => try self.airArrayToSlice(inst),
                .float_from_int => try self.airFloatFromInt(inst),
                .cmpxchg_weak   => try self.airCmpxchg(inst, .weak),
                .cmpxchg_strong => try self.airCmpxchg(inst, .strong),
                .atomic_rmw     => try self.airAtomicRmw(inst),
                .atomic_load    => try self.airAtomicLoad(inst),
                .memset         => try self.airMemset(inst, false),
                .memset_safe    => try self.airMemset(inst, true),
                .memcpy         => try self.airMemcpy(inst),
                .memmove        => try self.airMemmove(inst),
                .set_union_tag  => try self.airSetUnionTag(inst),
                .get_union_tag  => try self.airGetUnionTag(inst),
                .clz            => try self.airClzCtz(inst, .ctlz),
                .ctz            => try self.airClzCtz(inst, .cttz),
                .popcount       => try self.airBitOp(inst, .ctpop),
                .byte_swap      => try self.airByteSwap(inst),
                .bit_reverse    => try self.airBitOp(inst, .bitreverse),
                .tag_name       => try self.airTagName(inst),
                .error_name     => try self.airErrorName(inst),
                .splat          => try self.airSplat(inst),
                .select         => try self.airSelect(inst),
                .shuffle_one    => try self.airShuffleOne(inst),
                .shuffle_two    => try self.airShuffleTwo(inst),
                .aggregate_init => try self.airAggregateInit(inst),
                .union_init     => try self.airUnionInit(inst),
                .prefetch       => try self.airPrefetch(inst),
                .addrspace_cast => try self.airAddrSpaceCast(inst),

                .is_named_enum_value => try self.airIsNamedEnumValue(inst),
                .error_set_has_value => try self.airErrorSetHasValue(inst),

                .reduce           => try self.airReduce(inst, .normal),
                .reduce_optimized => try self.airReduce(inst, .fast),

                .atomic_store_unordered => try self.airAtomicStore(inst, .unordered),
                .atomic_store_monotonic => try self.airAtomicStore(inst, .monotonic),
                .atomic_store_release   => try self.airAtomicStore(inst, .release),
                .atomic_store_seq_cst   => try self.airAtomicStore(inst, .seq_cst),

                .struct_field_ptr => try self.airStructFieldPtr(inst),
                .struct_field_val => try self.airStructFieldVal(inst),

                .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
                .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
                .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
                .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

                .field_parent_ptr => try self.airFieldParentPtr(inst),

                .array_elem_val     => try self.airArrayElemVal(inst),
                .slice_elem_val     => try self.airSliceElemVal(inst),
                .slice_elem_ptr     => try self.airSliceElemPtr(inst),
                .ptr_elem_val       => try self.airPtrElemVal(inst),
                .ptr_elem_ptr       => try self.airPtrElemPtr(inst),

                .optional_payload         => try self.airOptionalPayload(inst),
                .optional_payload_ptr     => try self.airOptionalPayloadPtr(inst),
                .optional_payload_ptr_set => try self.airOptionalPayloadPtrSet(inst),

                .unwrap_errunion_payload     => try self.airErrUnionPayload(inst, false),
                .unwrap_errunion_payload_ptr => try self.airErrUnionPayload(inst, true),
                .unwrap_errunion_err         => try self.airErrUnionErr(inst, false),
                .unwrap_errunion_err_ptr     => try self.airErrUnionErr(inst, true),
                .errunion_payload_ptr_set    => try self.airErrUnionPayloadPtrSet(inst),
                .err_return_trace            => try self.airErrReturnTrace(inst),
                .set_err_return_trace        => try self.airSetErrReturnTrace(inst),
                .save_err_return_trace_index => try self.airSaveErrReturnTraceIndex(inst),

                .wrap_optional         => try self.airWrapOptional(body[i..]),
                .wrap_errunion_payload => try self.airWrapErrUnionPayload(body[i..]),
                .wrap_errunion_err     => try self.airWrapErrUnionErr(body[i..]),

                .wasm_memory_size => try self.airWasmMemorySize(inst),
                .wasm_memory_grow => try self.airWasmMemoryGrow(inst),

                .vector_store_elem => try self.airVectorStoreElem(inst),

                .runtime_nav_ptr => try self.airRuntimeNavPtr(inst),

                .inferred_alloc, .inferred_alloc_comptime => unreachable,

                .dbg_stmt => try self.airDbgStmt(inst),
                .dbg_empty_stmt => try self.airDbgEmptyStmt(inst),
                .dbg_var_ptr => try self.airDbgVarPtr(inst),
                .dbg_var_val => try self.airDbgVarVal(inst, false),
                .dbg_arg_inline => try self.airDbgVarVal(inst, true),

                .c_va_arg => try self.airCVaArg(inst),
                .c_va_copy => try self.airCVaCopy(inst),
                .c_va_end => try self.airCVaEnd(inst),
                .c_va_start => try self.airCVaStart(inst),

                .work_item_id => try self.airWorkItemId(inst),
                .work_group_size => try self.airWorkGroupSize(inst),
                .work_group_id => try self.airWorkGroupId(inst),

                // Instructions that are known to always be `noreturn` based on their tag.
                .br              => return self.airBr(inst),
                .repeat          => return self.airRepeat(inst),
                .switch_dispatch => return self.airSwitchDispatch(inst),
                .cond_br         => return self.airCondBr(inst),
                .switch_br       => return self.airSwitchBr(inst, false),
                .loop_switch_br  => return self.airSwitchBr(inst, true),
                .loop            => return self.airLoop(inst),
                .ret             => return self.airRet(inst, false),
                .ret_safe        => return self.airRet(inst, true),
                .ret_load        => return self.airRetLoad(inst),
                .trap            => return self.airTrap(inst),
                .unreach         => return self.airUnreach(inst),

                // Instructions which may be `noreturn`.
                .block => res: {
                    const res = try self.airBlock(inst);
                    if (self.typeOfIndex(inst).isNoReturn(zcu)) return;
                    break :res res;
                },
                .dbg_inline_block => res: {
                    const res = try self.airDbgInlineBlock(inst);
                    if (self.typeOfIndex(inst).isNoReturn(zcu)) return;
                    break :res res;
                },
                .call, .call_always_tail, .call_never_tail, .call_never_inline => |tag| res: {
                    const res = try self.airCall(inst, switch (tag) {
                        .call              => .auto,
                        .call_always_tail  => .always_tail,
                        .call_never_tail   => .never_tail,
                        .call_never_inline => .never_inline,
                        else               => unreachable,
                    });
                    // TODO: the AIR we emit for calls is a bit weird - the instruction has
                    // type `noreturn`, but there are instructions (and maybe a safety check) following
                    // nonetheless. The `unreachable` or safety check should be emitted by backends instead.
                    //if (self.typeOfIndex(inst).isNoReturn(mod)) return;
                    break :res res;
                },

                // zig fmt: on
            };
            if (val != .none) try self.func_inst_table.putNoClobber(self.gpa, inst.toRef(), val);
        }
        unreachable;
    }

    fn genBodyDebugScope(
        self: *FuncGen,
        maybe_inline_func: ?InternPool.Index,
        body: []const Air.Inst.Index,
        coverage_point: Air.CoveragePoint,
    ) Error!void {
        if (self.wip.strip) return self.genBody(body, coverage_point);

        const old_file = self.file;
        const old_inlined = self.inlined;
        const old_base_line = self.base_line;
        const old_scope = self.scope;
        defer if (maybe_inline_func) |_| {
            self.wip.debug_location = self.inlined;
            self.file = old_file;
            self.inlined = old_inlined;
            self.base_line = old_base_line;
        };
        defer self.scope = old_scope;

        if (maybe_inline_func) |inline_func| {
            const o = self.ng.object;
            const pt = self.ng.pt;
            const zcu = pt.zcu;
            const ip = &zcu.intern_pool;

            const func = zcu.funcInfo(inline_func);
            const nav = ip.getNav(func.owner_nav);
            const file_scope = zcu.navFileScopeIndex(func.owner_nav);
            const mod = zcu.fileByIndex(file_scope).mod.?;

            self.file = try o.getDebugFile(pt, file_scope);

            const line_number = zcu.navSrcLine(func.owner_nav) + 1;
            self.inlined = self.wip.debug_location;

            const fn_ty = try pt.funcType(.{
                .param_types = &.{},
                .return_type = .void_type,
            });

            self.scope = try o.builder.debugSubprogram(
                self.file,
                try o.builder.metadataString(nav.name.toSlice(&zcu.intern_pool)),
                try o.builder.metadataString(nav.fqn.toSlice(&zcu.intern_pool)),
                line_number,
                line_number + func.lbrace_line,
                try o.lowerDebugType(pt, fn_ty),
                .{
                    .di_flags = .{ .StaticMember = true },
                    .sp_flags = .{
                        .Optimized = mod.optimize_mode != .Debug,
                        .Definition = true,
                        // TODO: we can't know this at this point, since the function could be exported later!
                        .LocalToUnit = true,
                    },
                },
                o.debug_compile_unit,
            );

            self.base_line = zcu.navSrcLine(func.owner_nav);
            const inlined_at_location = try self.wip.debug_location.toMetadata(&o.builder);
            self.wip.debug_location = .{
                .location = .{
                    .line = line_number,
                    .column = 0,
                    .scope = self.scope,
                    .inlined_at = inlined_at_location,
                },
            };
        }

        self.scope = try self.ng.object.builder.debugLexicalBlock(
            self.scope,
            self.file,
            self.prev_dbg_line,
            self.prev_dbg_column,
        );

        switch (self.wip.debug_location) {
            .location => |*l| l.scope = self.scope,
            .no_location => {},
        }
        defer switch (self.wip.debug_location) {
            .location => |*l| l.scope = old_scope,
            .no_location => {},
        };

        try self.genBody(body, coverage_point);
    }

    pub const CallAttr = enum {
        Auto,
        NeverTail,
        NeverInline,
        AlwaysTail,
        AlwaysInline,
    };

    fn airCall(self: *FuncGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Call, pl_op.payload);
        const args: []const Air.Inst.Ref = @ptrCast(self.air.extra.items[extra.end..][0..extra.data.args_len]);
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const callee_ty = self.typeOf(pl_op.operand);
        const zig_fn_ty = switch (callee_ty.zigTypeTag(zcu)) {
            .@"fn" => callee_ty,
            .pointer => callee_ty.childType(zcu),
            else => unreachable,
        };
        const fn_info = zcu.typeToFunc(zig_fn_ty).?;
        const return_type = Type.fromInterned(fn_info.return_type);
        const llvm_fn = try self.resolveInst(pl_op.operand);
        const target = zcu.getTarget();
        const sret = firstParamSRet(fn_info, zcu, target);

        var llvm_args = std.array_list.Managed(Builder.Value).init(self.gpa);
        defer llvm_args.deinit();

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);

        if (self.disable_intrinsics) {
            try attributes.addFnAttr(.nobuiltin, &o.builder);
        }

        switch (modifier) {
            .auto, .always_tail => {},
            .never_tail, .never_inline => try attributes.addFnAttr(.@"noinline", &o.builder),
            .no_suspend, .always_inline, .compile_time => unreachable,
        }

        const ret_ptr = if (!sret) null else blk: {
            const llvm_ret_ty = try o.lowerType(pt, return_type);
            try attributes.addParamAttr(0, .{ .sret = llvm_ret_ty }, &o.builder);

            const alignment = return_type.abiAlignment(zcu).toLlvm();
            const ret_ptr = try self.buildAlloca(llvm_ret_ty, alignment);
            try llvm_args.append(ret_ptr);
            break :blk ret_ptr;
        };

        const err_return_tracing = fn_info.cc == .auto and zcu.comp.config.any_error_tracing;
        if (err_return_tracing) {
            assert(self.err_ret_trace != .none);
            try llvm_args.append(self.err_ret_trace);
        }

        var it = iterateParamTypes(o, pt, fn_info);
        while (try it.nextCall(self, args)) |lowering| switch (lowering) {
            .no_bits => continue,
            .byval => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                const llvm_param_ty = try o.lowerType(pt, param_ty);
                if (isByRef(param_ty, zcu)) {
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    const loaded = try self.wip.load(.normal, llvm_param_ty, llvm_arg, alignment, "");
                    try llvm_args.append(loaded);
                } else {
                    try llvm_args.append(llvm_arg);
                }
            },
            .byref => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                if (isByRef(param_ty, zcu)) {
                    try llvm_args.append(llvm_arg);
                } else {
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    const param_llvm_ty = llvm_arg.typeOfWip(&self.wip);
                    const arg_ptr = try self.buildAlloca(param_llvm_ty, alignment);
                    _ = try self.wip.store(.normal, llvm_arg, arg_ptr, alignment);
                    try llvm_args.append(arg_ptr);
                }
            },
            .byref_mut => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);

                const alignment = param_ty.abiAlignment(zcu).toLlvm();
                const param_llvm_ty = try o.lowerType(pt, param_ty);
                const arg_ptr = try self.buildAlloca(param_llvm_ty, alignment);
                if (isByRef(param_ty, zcu)) {
                    const loaded = try self.wip.load(.normal, param_llvm_ty, llvm_arg, alignment, "");
                    _ = try self.wip.store(.normal, loaded, arg_ptr, alignment);
                } else {
                    _ = try self.wip.store(.normal, llvm_arg, arg_ptr, alignment);
                }
                try llvm_args.append(arg_ptr);
            },
            .abi_sized_int => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_arg = try self.resolveInst(arg);
                const int_llvm_ty = try o.builder.intType(@intCast(param_ty.abiSize(zcu) * 8));

                if (isByRef(param_ty, zcu)) {
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    const loaded = try self.wip.load(.normal, int_llvm_ty, llvm_arg, alignment, "");
                    try llvm_args.append(loaded);
                } else {
                    // LLVM does not allow bitcasting structs so we must allocate
                    // a local, store as one type, and then load as another type.
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    const int_ptr = try self.buildAlloca(int_llvm_ty, alignment);
                    _ = try self.wip.store(.normal, llvm_arg, int_ptr, alignment);
                    const loaded = try self.wip.load(.normal, int_llvm_ty, int_ptr, alignment, "");
                    try llvm_args.append(loaded);
                }
            },
            .slice => {
                const arg = args[it.zig_index - 1];
                const llvm_arg = try self.resolveInst(arg);
                const ptr = try self.wip.extractValue(llvm_arg, &.{0}, "");
                const len = try self.wip.extractValue(llvm_arg, &.{1}, "");
                try llvm_args.appendSlice(&.{ ptr, len });
            },
            .multiple_llvm_types => {
                const arg = args[it.zig_index - 1];
                const param_ty = self.typeOf(arg);
                const llvm_types = it.types_buffer[0..it.types_len];
                const llvm_arg = try self.resolveInst(arg);
                const is_by_ref = isByRef(param_ty, zcu);
                const arg_ptr = if (is_by_ref) llvm_arg else ptr: {
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    break :ptr ptr;
                };

                const llvm_ty = try o.builder.structType(.normal, llvm_types);
                try llvm_args.ensureUnusedCapacity(it.types_len);
                for (llvm_types, 0..) |field_ty, i| {
                    const alignment =
                        Builder.Alignment.fromByteUnits(@divExact(target.ptrBitWidth(), 8));
                    const field_ptr = try self.wip.gepStruct(llvm_ty, arg_ptr, i, "");
                    const loaded = try self.wip.load(.normal, field_ty, field_ptr, alignment, "");
                    llvm_args.appendAssumeCapacity(loaded);
                }
            },
            .float_array => |count| {
                const arg = args[it.zig_index - 1];
                const arg_ty = self.typeOf(arg);
                var llvm_arg = try self.resolveInst(arg);
                const alignment = arg_ty.abiAlignment(zcu).toLlvm();
                if (!isByRef(arg_ty, zcu)) {
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    llvm_arg = ptr;
                }

                const float_ty = try o.lowerType(pt, aarch64_c_abi.getFloatArrayType(arg_ty, zcu).?);
                const array_ty = try o.builder.arrayType(count, float_ty);

                const loaded = try self.wip.load(.normal, array_ty, llvm_arg, alignment, "");
                try llvm_args.append(loaded);
            },
            .i32_array, .i64_array => |arr_len| {
                const elem_size: u8 = if (lowering == .i32_array) 32 else 64;
                const arg = args[it.zig_index - 1];
                const arg_ty = self.typeOf(arg);
                var llvm_arg = try self.resolveInst(arg);
                const alignment = arg_ty.abiAlignment(zcu).toLlvm();
                if (!isByRef(arg_ty, zcu)) {
                    const ptr = try self.buildAlloca(llvm_arg.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, llvm_arg, ptr, alignment);
                    llvm_arg = ptr;
                }

                const array_ty =
                    try o.builder.arrayType(arr_len, try o.builder.intType(@intCast(elem_size)));
                const loaded = try self.wip.load(.normal, array_ty, llvm_arg, alignment, "");
                try llvm_args.append(loaded);
            },
        };

        {
            // Add argument attributes.
            it = iterateParamTypes(o, pt, fn_info);
            it.llvm_index += @intFromBool(sret);
            it.llvm_index += @intFromBool(err_return_tracing);
            while (try it.next()) |lowering| switch (lowering) {
                .byval => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    if (!isByRef(param_ty, zcu)) {
                        try o.addByValParamAttrs(pt, &attributes, param_ty, param_index, fn_info, it.llvm_index - 1);
                    }
                },
                .byref => {
                    const param_index = it.zig_index - 1;
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[param_index]);
                    const param_llvm_ty = try o.lowerType(pt, param_ty);
                    const alignment = param_ty.abiAlignment(zcu).toLlvm();
                    try o.addByRefParamAttrs(&attributes, it.llvm_index - 1, alignment, it.byval_attr, param_llvm_ty);
                },
                .byref_mut => try attributes.addParamAttr(it.llvm_index - 1, .noundef, &o.builder),
                // No attributes needed for these.
                .no_bits,
                .abi_sized_int,
                .multiple_llvm_types,
                .float_array,
                .i32_array,
                .i64_array,
                => continue,

                .slice => {
                    assert(!it.byval_attr);
                    const param_ty = Type.fromInterned(fn_info.param_types.get(ip)[it.zig_index - 1]);
                    const ptr_info = param_ty.ptrInfo(zcu);
                    const llvm_arg_i = it.llvm_index - 2;

                    if (math.cast(u5, it.zig_index - 1)) |i| {
                        if (@as(u1, @truncate(fn_info.noalias_bits >> i)) != 0) {
                            try attributes.addParamAttr(llvm_arg_i, .@"noalias", &o.builder);
                        }
                    }
                    if (param_ty.zigTypeTag(zcu) != .optional and
                        !ptr_info.flags.is_allowzero and
                        ptr_info.flags.address_space == .generic)
                    {
                        try attributes.addParamAttr(llvm_arg_i, .nonnull, &o.builder);
                    }
                    if (ptr_info.flags.is_const) {
                        try attributes.addParamAttr(llvm_arg_i, .readonly, &o.builder);
                    }
                    const elem_align = (if (ptr_info.flags.alignment != .none)
                        @as(InternPool.Alignment, ptr_info.flags.alignment)
                    else
                        Type.fromInterned(ptr_info.child).abiAlignment(zcu).max(.@"1")).toLlvm();
                    try attributes.addParamAttr(llvm_arg_i, .{ .@"align" = elem_align }, &o.builder);
                },
            };
        }

        const call = try self.wip.call(
            switch (modifier) {
                .auto, .never_inline => .normal,
                .never_tail => .notail,
                .always_tail => .musttail,
                .no_suspend, .always_inline, .compile_time => unreachable,
            },
            toLlvmCallConvTag(fn_info.cc, target).?,
            try attributes.finish(&o.builder),
            try o.lowerType(pt, zig_fn_ty),
            llvm_fn,
            llvm_args.items,
            "",
        );

        if (fn_info.return_type == .noreturn_type and modifier != .always_tail) {
            return .none;
        }

        if (self.liveness.isUnused(inst) or !return_type.hasRuntimeBitsIgnoreComptime(zcu)) {
            return .none;
        }

        const llvm_ret_ty = try o.lowerType(pt, return_type);
        if (ret_ptr) |rp| {
            if (isByRef(return_type, zcu)) {
                return rp;
            } else {
                // our by-ref status disagrees with sret so we must load.
                const return_alignment = return_type.abiAlignment(zcu).toLlvm();
                return self.wip.load(.normal, llvm_ret_ty, rp, return_alignment, "");
            }
        }

        const abi_ret_ty = try lowerFnRetTy(o, pt, fn_info);

        if (abi_ret_ty != llvm_ret_ty) {
            // In this case the function return type is honoring the calling convention by having
            // a different LLVM type than the usual one. We solve this here at the callsite
            // by using our canonical type, then loading it if necessary.
            const alignment = return_type.abiAlignment(zcu).toLlvm();
            const rp = try self.buildAlloca(abi_ret_ty, alignment);
            _ = try self.wip.store(.normal, call, rp, alignment);
            return if (isByRef(return_type, zcu))
                rp
            else
                try self.wip.load(.normal, llvm_ret_ty, rp, alignment, "");
        }

        if (isByRef(return_type, zcu)) {
            // our by-ref status disagrees with sret so we must allocate, store,
            // and return the allocation pointer.
            const alignment = return_type.abiAlignment(zcu).toLlvm();
            const rp = try self.buildAlloca(llvm_ret_ty, alignment);
            _ = try self.wip.store(.normal, call, rp, alignment);
            return rp;
        } else {
            return call;
        }
    }

    fn buildSimplePanic(fg: *FuncGen, panic_id: Zcu.SimplePanicId) !void {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        const panic_func = zcu.funcInfo(zcu.builtin_decl_values.get(panic_id.toBuiltin()));
        const fn_info = zcu.typeToFunc(.fromInterned(panic_func.ty)).?;
        const panic_global = try o.resolveLlvmFunction(pt, panic_func.owner_nav);

        const has_err_trace = zcu.comp.config.any_error_tracing and fn_info.cc == .auto;
        if (has_err_trace) assert(fg.err_ret_trace != .none);
        _ = try fg.wip.callIntrinsicAssumeCold();
        _ = try fg.wip.call(
            .normal,
            toLlvmCallConvTag(fn_info.cc, target).?,
            .none,
            panic_global.typeOf(&o.builder),
            panic_global.toValue(&o.builder),
            if (has_err_trace) &.{fg.err_ret_trace} else &.{},
            "",
        );
        _ = try fg.wip.@"unreachable"();
    }

    fn airRet(self: *FuncGen, inst: Air.Inst.Index, safety: bool) !void {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ret_ty = self.typeOf(un_op);

        if (self.ret_ptr != .none) {
            const ptr_ty = try pt.singleMutPtrType(ret_ty);

            const operand = try self.resolveInst(un_op);
            const val_is_undef = if (try self.air.value(un_op, pt)) |val| val.isUndef(zcu) else false;
            if (val_is_undef and safety) undef: {
                const ptr_info = ptr_ty.ptrInfo(zcu);
                const needs_bitmask = (ptr_info.packed_offset.host_size != 0);
                if (needs_bitmask) {
                    // TODO: only some bits are to be undef, we cannot write with a simple memset.
                    // meanwhile, ignore the write rather than stomping over valid bits.
                    // https://github.com/ziglang/zig/issues/15337
                    break :undef;
                }
                const len = try o.builder.intValue(try o.lowerType(pt, Type.usize), ret_ty.abiSize(zcu));
                _ = try self.wip.callMemSet(
                    self.ret_ptr,
                    ptr_ty.ptrAlignment(zcu).toLlvm(),
                    try o.builder.intValue(.i8, 0xaa),
                    len,
                    .normal,
                    self.disable_intrinsics,
                );
                const owner_mod = self.ng.ownerModule();
                if (owner_mod.valgrind) {
                    try self.valgrindMarkUndef(self.ret_ptr, len);
                }
                _ = try self.wip.retVoid();
                return;
            }

            const unwrapped_operand = operand.unwrap();
            const unwrapped_ret = self.ret_ptr.unwrap();

            // Return value was stored previously
            if (unwrapped_operand == .instruction and unwrapped_ret == .instruction and unwrapped_operand.instruction == unwrapped_ret.instruction) {
                _ = try self.wip.retVoid();
                return;
            }

            try self.store(self.ret_ptr, ptr_ty, operand, .none);
            _ = try self.wip.retVoid();
            return;
        }
        const fn_info = zcu.typeToFunc(Type.fromInterned(ip.getNav(self.ng.nav_index).typeOf(ip))).?;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            if (Type.fromInterned(fn_info.return_type).isError(zcu)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                _ = try self.wip.ret(try o.builder.intValue(try o.errorIntType(pt), 0));
            } else {
                _ = try self.wip.retVoid();
            }
            return;
        }

        const abi_ret_ty = try lowerFnRetTy(o, pt, fn_info);
        const operand = try self.resolveInst(un_op);
        const val_is_undef = if (try self.air.value(un_op, pt)) |val| val.isUndef(zcu) else false;
        const alignment = ret_ty.abiAlignment(zcu).toLlvm();

        if (val_is_undef and safety) {
            const llvm_ret_ty = operand.typeOfWip(&self.wip);
            const rp = try self.buildAlloca(llvm_ret_ty, alignment);
            const len = try o.builder.intValue(try o.lowerType(pt, Type.usize), ret_ty.abiSize(zcu));
            _ = try self.wip.callMemSet(
                rp,
                alignment,
                try o.builder.intValue(.i8, 0xaa),
                len,
                .normal,
                self.disable_intrinsics,
            );
            const owner_mod = self.ng.ownerModule();
            if (owner_mod.valgrind) {
                try self.valgrindMarkUndef(rp, len);
            }
            _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, rp, alignment, ""));
            return;
        }

        if (isByRef(ret_ty, zcu)) {
            // operand is a pointer however self.ret_ptr is null so that means
            // we need to return a value.
            _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, operand, alignment, ""));
            return;
        }

        const llvm_ret_ty = operand.typeOfWip(&self.wip);
        if (abi_ret_ty == llvm_ret_ty) {
            _ = try self.wip.ret(operand);
            return;
        }

        const rp = try self.buildAlloca(llvm_ret_ty, alignment);
        _ = try self.wip.store(.normal, operand, rp, alignment);
        _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, rp, alignment, ""));
        return;
    }

    fn airRetLoad(self: *FuncGen, inst: Air.Inst.Index) !void {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const ptr_ty = self.typeOf(un_op);
        const ret_ty = ptr_ty.childType(zcu);
        const fn_info = zcu.typeToFunc(Type.fromInterned(ip.getNav(self.ng.nav_index).typeOf(ip))).?;
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            if (Type.fromInterned(fn_info.return_type).isError(zcu)) {
                // Functions with an empty error set are emitted with an error code
                // return type and return zero so they can be function pointers coerced
                // to functions that return anyerror.
                _ = try self.wip.ret(try o.builder.intValue(try o.errorIntType(pt), 0));
            } else {
                _ = try self.wip.retVoid();
            }
            return;
        }
        if (self.ret_ptr != .none) {
            _ = try self.wip.retVoid();
            return;
        }
        const ptr = try self.resolveInst(un_op);
        const abi_ret_ty = try lowerFnRetTy(o, pt, fn_info);
        const alignment = ret_ty.abiAlignment(zcu).toLlvm();
        _ = try self.wip.ret(try self.wip.load(.normal, abi_ret_ty, ptr, alignment, ""));
        return;
    }

    fn airCVaArg(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const list = try self.resolveInst(ty_op.operand);
        const arg_ty = ty_op.ty.toType();
        const llvm_arg_ty = try o.lowerType(pt, arg_ty);

        return self.wip.vaArg(list, llvm_arg_ty, "");
    }

    fn airCVaCopy(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const src_list = try self.resolveInst(ty_op.operand);
        const va_list_ty = ty_op.ty.toType();
        const llvm_va_list_ty = try o.lowerType(pt, va_list_ty);

        const result_alignment = va_list_ty.abiAlignment(pt.zcu).toLlvm();
        const dest_list = try self.buildAlloca(llvm_va_list_ty, result_alignment);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_copy, &.{dest_list.typeOfWip(&self.wip)}, &.{ dest_list, src_list }, "");
        return if (isByRef(va_list_ty, zcu))
            dest_list
        else
            try self.wip.load(.normal, llvm_va_list_ty, dest_list, result_alignment, "");
    }

    fn airCVaEnd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const src_list = try self.resolveInst(un_op);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_end, &.{src_list.typeOfWip(&self.wip)}, &.{src_list}, "");
        return .none;
    }

    fn airCVaStart(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const va_list_ty = self.typeOfIndex(inst);
        const llvm_va_list_ty = try o.lowerType(pt, va_list_ty);

        const result_alignment = va_list_ty.abiAlignment(pt.zcu).toLlvm();
        const dest_list = try self.buildAlloca(llvm_va_list_ty, result_alignment);

        _ = try self.wip.callIntrinsic(.normal, .none, .va_start, &.{dest_list.typeOfWip(&self.wip)}, &.{dest_list}, "");
        return if (isByRef(va_list_ty, zcu))
            dest_list
        else
            try self.wip.load(.normal, llvm_va_list_ty, dest_list, result_alignment, "");
    }

    fn airCmp(
        self: *FuncGen,
        inst: Air.Inst.Index,
        op: math.CompareOperator,
        fast: Builder.FastMathKind,
    ) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const operand_ty = self.typeOf(bin_op.lhs);

        return self.cmp(fast, op, operand_ty, lhs, rhs);
    }

    fn airCmpVector(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.VectorCmp, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const vec_ty = self.typeOf(extra.lhs);
        const cmp_op = extra.compareOperator();

        return self.cmp(fast, cmp_op, vec_ty, lhs, rhs);
    }

    fn airCmpLtErrorsLen(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const llvm_fn = try o.getCmpLtErrorsLenFunction(pt);
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn cmp(
        self: *FuncGen,
        fast: Builder.FastMathKind,
        op: math.CompareOperator,
        operand_ty: Type,
        lhs: Builder.Value,
        rhs: Builder.Value,
    ) Allocator.Error!Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const scalar_ty = operand_ty.scalarType(zcu);
        const int_ty = switch (scalar_ty.zigTypeTag(zcu)) {
            .@"enum" => scalar_ty.intTagType(zcu),
            .int, .bool, .pointer, .error_set => scalar_ty,
            .optional => blk: {
                const payload_ty = operand_ty.optionalChild(zcu);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu) or
                    operand_ty.optionalReprIsPayload(zcu))
                {
                    break :blk operand_ty;
                }
                // We need to emit instructions to check for equality/inequality
                // of optionals that are not pointers.
                const is_by_ref = isByRef(scalar_ty, zcu);
                const opt_llvm_ty = try o.lowerType(pt, scalar_ty);
                const lhs_non_null = try self.optCmpNull(.ne, opt_llvm_ty, lhs, is_by_ref, .normal);
                const rhs_non_null = try self.optCmpNull(.ne, opt_llvm_ty, rhs, is_by_ref, .normal);
                const llvm_i2 = try o.builder.intType(2);
                const lhs_non_null_i2 = try self.wip.cast(.zext, lhs_non_null, llvm_i2, "");
                const rhs_non_null_i2 = try self.wip.cast(.zext, rhs_non_null, llvm_i2, "");
                const lhs_shifted = try self.wip.bin(.shl, lhs_non_null_i2, try o.builder.intValue(llvm_i2, 1), "");
                const lhs_rhs_ored = try self.wip.bin(.@"or", lhs_shifted, rhs_non_null_i2, "");
                const both_null_block = try self.wip.block(1, "BothNull");
                const mixed_block = try self.wip.block(1, "Mixed");
                const both_pl_block = try self.wip.block(1, "BothNonNull");
                const end_block = try self.wip.block(3, "End");
                var wip_switch = try self.wip.@"switch"(lhs_rhs_ored, mixed_block, 2, .none);
                defer wip_switch.finish(&self.wip);
                try wip_switch.addCase(
                    try o.builder.intConst(llvm_i2, 0b00),
                    both_null_block,
                    &self.wip,
                );
                try wip_switch.addCase(
                    try o.builder.intConst(llvm_i2, 0b11),
                    both_pl_block,
                    &self.wip,
                );

                self.wip.cursor = .{ .block = both_null_block };
                _ = try self.wip.br(end_block);

                self.wip.cursor = .{ .block = mixed_block };
                _ = try self.wip.br(end_block);

                self.wip.cursor = .{ .block = both_pl_block };
                const lhs_payload = try self.optPayloadHandle(opt_llvm_ty, lhs, scalar_ty, true);
                const rhs_payload = try self.optPayloadHandle(opt_llvm_ty, rhs, scalar_ty, true);
                const payload_cmp = try self.cmp(fast, op, payload_ty, lhs_payload, rhs_payload);
                _ = try self.wip.br(end_block);
                const both_pl_block_end = self.wip.cursor.block;

                self.wip.cursor = .{ .block = end_block };
                const llvm_i1_0 = Builder.Value.false;
                const llvm_i1_1 = Builder.Value.true;
                const incoming_values: [3]Builder.Value = .{
                    switch (op) {
                        .eq => llvm_i1_1,
                        .neq => llvm_i1_0,
                        else => unreachable,
                    },
                    switch (op) {
                        .eq => llvm_i1_0,
                        .neq => llvm_i1_1,
                        else => unreachable,
                    },
                    payload_cmp,
                };

                const phi = try self.wip.phi(.i1, "");
                phi.finish(
                    &incoming_values,
                    &.{ both_null_block, mixed_block, both_pl_block_end },
                    &self.wip,
                );
                return phi.toValue();
            },
            .float => return self.buildFloatCmp(fast, op, operand_ty, .{ lhs, rhs }),
            .@"struct" => blk: {
                const struct_obj = ip.loadStructType(scalar_ty.toIntern());
                assert(struct_obj.layout == .@"packed");
                const backing_index = struct_obj.backingIntTypeUnordered(ip);
                break :blk Type.fromInterned(backing_index);
            },
            else => unreachable,
        };
        const is_signed = int_ty.isSignedInt(zcu);
        const cond: Builder.IntegerCondition = switch (op) {
            .eq => .eq,
            .neq => .ne,
            .lt => if (is_signed) .slt else .ult,
            .lte => if (is_signed) .sle else .ule,
            .gt => if (is_signed) .sgt else .ugt,
            .gte => if (is_signed) .sge else .uge,
        };
        return self.wip.icmp(cond, lhs, rhs, "");
    }

    fn airBlock(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Block, ty_pl.payload);
        return self.lowerBlock(inst, null, @ptrCast(self.air.extra.items[extra.end..][0..extra.data.body_len]));
    }

    fn lowerBlock(
        self: *FuncGen,
        inst: Air.Inst.Index,
        maybe_inline_func: ?InternPool.Index,
        body: []const Air.Inst.Index,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const inst_ty = self.typeOfIndex(inst);

        if (inst_ty.isNoReturn(zcu)) {
            try self.genBodyDebugScope(maybe_inline_func, body, .none);
            return .none;
        }

        const have_block_result = inst_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu);

        var breaks: BreakList = if (have_block_result) .{ .list = .{} } else .{ .len = 0 };
        defer if (have_block_result) breaks.list.deinit(self.gpa);

        const parent_bb = try self.wip.block(0, "Block");
        try self.blocks.putNoClobber(self.gpa, inst, .{
            .parent_bb = parent_bb,
            .breaks = &breaks,
        });
        defer assert(self.blocks.remove(inst));

        try self.genBodyDebugScope(maybe_inline_func, body, .none);

        self.wip.cursor = .{ .block = parent_bb };

        // Create a phi node only if the block returns a value.
        if (have_block_result) {
            const raw_llvm_ty = try o.lowerType(pt, inst_ty);
            const llvm_ty: Builder.Type = ty: {
                // If the zig tag type is a function, this represents an actual function body; not
                // a pointer to it. LLVM IR allows the call instruction to use function bodies instead
                // of function pointers, however the phi makes it a runtime value and therefore
                // the LLVM type has to be wrapped in a pointer.
                if (inst_ty.zigTypeTag(zcu) == .@"fn" or isByRef(inst_ty, zcu)) {
                    break :ty .ptr;
                }
                break :ty raw_llvm_ty;
            };

            parent_bb.ptr(&self.wip).incoming = @intCast(breaks.list.len);
            const phi = try self.wip.phi(llvm_ty, "");
            phi.finish(breaks.list.items(.val), breaks.list.items(.bb), &self.wip);
            return phi.toValue();
        } else {
            parent_bb.ptr(&self.wip).incoming = @intCast(breaks.len);
            return .none;
        }
    }

    fn airBr(self: *FuncGen, inst: Air.Inst.Index) !void {
        const zcu = self.ng.pt.zcu;
        const branch = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
        const block = self.blocks.get(branch.block_inst).?;

        // Add the values to the lists only if the break provides a value.
        const operand_ty = self.typeOf(branch.operand);
        if (operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
            const val = try self.resolveInst(branch.operand);

            // For the phi node, we need the basic blocks and the values of the
            // break instructions.
            try block.breaks.list.append(self.gpa, .{ .bb = self.wip.cursor.block, .val = val });
        } else block.breaks.len += 1;
        _ = try self.wip.br(block.parent_bb);
    }

    fn airRepeat(self: *FuncGen, inst: Air.Inst.Index) !void {
        const repeat = self.air.instructions.items(.data)[@intFromEnum(inst)].repeat;
        const loop_bb = self.loops.get(repeat.loop_inst).?;
        loop_bb.ptr(&self.wip).incoming += 1;
        _ = try self.wip.br(loop_bb);
    }

    fn lowerSwitchDispatch(
        self: *FuncGen,
        switch_inst: Air.Inst.Index,
        cond_ref: Air.Inst.Ref,
        dispatch_info: SwitchDispatchInfo,
    ) !void {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const cond_ty = self.typeOf(cond_ref);
        const switch_br = self.air.unwrapSwitch(switch_inst);

        if (try self.air.value(cond_ref, pt)) |cond_val| {
            // Comptime-known dispatch. Iterate the cases to find the correct
            // one, and branch to the corresponding element of `case_blocks`.
            var it = switch_br.iterateCases();
            const target_case_idx = target: while (it.next()) |case| {
                for (case.items) |item| {
                    const val = Value.fromInterned(item.toInterned().?);
                    if (cond_val.compareHetero(.eq, val, zcu)) break :target case.idx;
                }
                for (case.ranges) |range| {
                    const low = Value.fromInterned(range[0].toInterned().?);
                    const high = Value.fromInterned(range[1].toInterned().?);
                    if (cond_val.compareHetero(.gte, low, zcu) and
                        cond_val.compareHetero(.lte, high, zcu))
                    {
                        break :target case.idx;
                    }
                }
            } else dispatch_info.case_blocks.len - 1;
            const target_block = dispatch_info.case_blocks[target_case_idx];
            target_block.ptr(&self.wip).incoming += 1;
            _ = try self.wip.br(target_block);
            return;
        }

        // Runtime-known dispatch.
        const cond = try self.resolveInst(cond_ref);

        if (dispatch_info.jmp_table) |jmp_table| {
            // We should use the constructed jump table.
            // First, check the bounds to branch to the `else` case if needed.
            const inbounds = try self.wip.bin(
                .@"and",
                try self.cmp(.normal, .gte, cond_ty, cond, jmp_table.min.toValue()),
                try self.cmp(.normal, .lte, cond_ty, cond, jmp_table.max.toValue()),
                "",
            );
            const jmp_table_block = try self.wip.block(1, "Then");
            const else_block = dispatch_info.case_blocks[dispatch_info.case_blocks.len - 1];
            else_block.ptr(&self.wip).incoming += 1;
            _ = try self.wip.brCond(inbounds, jmp_table_block, else_block, switch (jmp_table.in_bounds_hint) {
                .none => .none,
                .unpredictable => .unpredictable,
                .likely => .then_likely,
                .unlikely => .else_likely,
            });

            self.wip.cursor = .{ .block = jmp_table_block };

            // Figure out the list of blocks we might branch to.
            // This includes all case blocks, but it might not include the `else` block if
            // the table is dense.
            const target_blocks_len = dispatch_info.case_blocks.len - @intFromBool(!jmp_table.table_includes_else);
            const target_blocks = dispatch_info.case_blocks[0..target_blocks_len];

            // Make sure to cast the index to a usize so it's not treated as negative!
            const table_index = try self.wip.conv(
                .unsigned,
                try self.wip.bin(.@"sub nuw", cond, jmp_table.min.toValue(), ""),
                try o.lowerType(pt, .usize),
                "",
            );
            const target_ptr_ptr = try self.wip.gep(
                .inbounds,
                .ptr,
                jmp_table.table.toValue(),
                &.{table_index},
                "",
            );
            const target_ptr = try self.wip.load(.normal, .ptr, target_ptr_ptr, .default, "");

            // Do the branch!
            _ = try self.wip.indirectbr(target_ptr, target_blocks);

            // Mark all target blocks as having one more incoming branch.
            for (target_blocks) |case_block| {
                case_block.ptr(&self.wip).incoming += 1;
            }

            return;
        }

        // We must lower to an actual LLVM `switch` instruction.
        // The switch prongs will correspond to our scalar cases. Ranges will
        // be handled by conditional branches in the `else` prong.

        const llvm_usize = try o.lowerType(pt, Type.usize);
        const cond_int = if (cond.typeOfWip(&self.wip).isPointer(&o.builder))
            try self.wip.cast(.ptrtoint, cond, llvm_usize, "")
        else
            cond;

        const llvm_cases_len, const last_range_case = info: {
            var llvm_cases_len: u32 = 0;
            var last_range_case: ?u32 = null;
            var it = switch_br.iterateCases();
            while (it.next()) |case| {
                if (case.ranges.len > 0) last_range_case = case.idx;
                llvm_cases_len += @intCast(case.items.len);
            }
            break :info .{ llvm_cases_len, last_range_case };
        };

        // The `else` of the LLVM `switch` is the actual `else` prong only
        // if there are no ranges. Otherwise, the `else` will have a
        // conditional chain before the "true" `else` prong.
        const llvm_else_block = if (last_range_case == null)
            dispatch_info.case_blocks[dispatch_info.case_blocks.len - 1]
        else
            try self.wip.block(0, "RangeTest");

        llvm_else_block.ptr(&self.wip).incoming += 1;

        var wip_switch = try self.wip.@"switch"(cond_int, llvm_else_block, llvm_cases_len, dispatch_info.switch_weights);
        defer wip_switch.finish(&self.wip);

        // Construct the actual cases. Set the cursor to the `else` block so
        // we can construct ranges at the same time as scalar cases.
        self.wip.cursor = .{ .block = llvm_else_block };

        var it = switch_br.iterateCases();
        while (it.next()) |case| {
            const case_block = dispatch_info.case_blocks[case.idx];

            for (case.items) |item| {
                const llvm_item = (try self.resolveInst(item)).toConst().?;
                const llvm_int_item = if (llvm_item.typeOf(&o.builder).isPointer(&o.builder))
                    try o.builder.castConst(.ptrtoint, llvm_item, llvm_usize)
                else
                    llvm_item;
                try wip_switch.addCase(llvm_int_item, case_block, &self.wip);
            }
            case_block.ptr(&self.wip).incoming += @intCast(case.items.len);

            if (case.ranges.len == 0) continue;

            // Add a conditional for the ranges, directing to the relevant bb.
            // We don't need to consider `cold` branch hints since that information is stored
            // in the target bb body, but we do care about likely/unlikely/unpredictable.

            const hint = switch_br.getHint(case.idx);

            var range_cond: ?Builder.Value = null;
            for (case.ranges) |range| {
                const llvm_min = try self.resolveInst(range[0]);
                const llvm_max = try self.resolveInst(range[1]);
                const cond_part = try self.wip.bin(
                    .@"and",
                    try self.cmp(.normal, .gte, cond_ty, cond, llvm_min),
                    try self.cmp(.normal, .lte, cond_ty, cond, llvm_max),
                    "",
                );
                if (range_cond) |prev| {
                    range_cond = try self.wip.bin(.@"or", prev, cond_part, "");
                } else range_cond = cond_part;
            }

            // If the check fails, we either branch to the "true" `else` case,
            // or to the next range condition.
            const range_else_block = if (case.idx == last_range_case.?)
                dispatch_info.case_blocks[dispatch_info.case_blocks.len - 1]
            else
                try self.wip.block(0, "RangeTest");

            _ = try self.wip.brCond(range_cond.?, case_block, range_else_block, switch (hint) {
                .none, .cold => .none,
                .unpredictable => .unpredictable,
                .likely => .then_likely,
                .unlikely => .else_likely,
            });
            case_block.ptr(&self.wip).incoming += 1;
            range_else_block.ptr(&self.wip).incoming += 1;

            // Construct the next range conditional (if any) in the false branch.
            self.wip.cursor = .{ .block = range_else_block };
        }
    }

    fn airSwitchDispatch(self: *FuncGen, inst: Air.Inst.Index) !void {
        const br = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
        const dispatch_info = self.switch_dispatch_info.get(br.block_inst).?;
        return self.lowerSwitchDispatch(br.block_inst, br.operand, dispatch_info);
    }

    fn airCondBr(self: *FuncGen, inst: Air.Inst.Index) !void {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const cond = try self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.CondBr, pl_op.payload);
        const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra.items[extra.end..][0..extra.data.then_body_len]);
        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra.items[extra.end + then_body.len ..][0..extra.data.else_body_len]);

        const Hint = enum {
            none,
            unpredictable,
            then_likely,
            else_likely,
            then_cold,
            else_cold,
        };
        const hint: Hint = switch (extra.data.branch_hints.true) {
            .none => switch (extra.data.branch_hints.false) {
                .none => .none,
                .likely => .else_likely,
                .unlikely => .then_likely,
                .cold => .else_cold,
                .unpredictable => .unpredictable,
            },
            .likely => switch (extra.data.branch_hints.false) {
                .none => .then_likely,
                .likely => .unpredictable,
                .unlikely => .then_likely,
                .cold => .else_cold,
                .unpredictable => .unpredictable,
            },
            .unlikely => switch (extra.data.branch_hints.false) {
                .none => .else_likely,
                .likely => .else_likely,
                .unlikely => .unpredictable,
                .cold => .else_cold,
                .unpredictable => .unpredictable,
            },
            .cold => .then_cold,
            .unpredictable => .unpredictable,
        };

        const then_block = try self.wip.block(1, "Then");
        const else_block = try self.wip.block(1, "Else");
        _ = try self.wip.brCond(cond, then_block, else_block, switch (hint) {
            .none, .then_cold, .else_cold => .none,
            .unpredictable => .unpredictable,
            .then_likely => .then_likely,
            .else_likely => .else_likely,
        });

        self.wip.cursor = .{ .block = then_block };
        if (hint == .then_cold) _ = try self.wip.callIntrinsicAssumeCold();
        try self.genBodyDebugScope(null, then_body, extra.data.branch_hints.then_cov);

        self.wip.cursor = .{ .block = else_block };
        if (hint == .else_cold) _ = try self.wip.callIntrinsicAssumeCold();
        try self.genBodyDebugScope(null, else_body, extra.data.branch_hints.else_cov);

        // No need to reset the insert cursor since this instruction is noreturn.
    }

    fn airTry(self: *FuncGen, inst: Air.Inst.Index, err_cold: bool) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const err_union = try self.resolveInst(pl_op.operand);
        const extra = self.air.extraData(Air.Try, pl_op.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra.items[extra.end..][0..extra.data.body_len]);
        const err_union_ty = self.typeOf(pl_op.operand);
        const is_unused = self.liveness.isUnused(inst);
        return lowerTry(self, err_union, body, err_union_ty, false, false, is_unused, err_cold);
    }

    fn airTryPtr(self: *FuncGen, inst: Air.Inst.Index, err_cold: bool) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
        const err_union_ptr = try self.resolveInst(extra.data.ptr);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra.items[extra.end..][0..extra.data.body_len]);
        const err_union_ty = self.typeOf(extra.data.ptr).childType(zcu);
        const is_unused = self.liveness.isUnused(inst);

        self.maybeMarkAllowZeroAccess(self.typeOf(extra.data.ptr).ptrInfo(zcu));

        return lowerTry(self, err_union_ptr, body, err_union_ty, true, true, is_unused, err_cold);
    }

    fn lowerTry(
        fg: *FuncGen,
        err_union: Builder.Value,
        body: []const Air.Inst.Index,
        err_union_ty: Type,
        operand_is_ptr: bool,
        can_elide_load: bool,
        is_unused: bool,
        err_cold: bool,
    ) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const payload_ty = err_union_ty.errorUnionPayload(zcu);
        const payload_has_bits = payload_ty.hasRuntimeBitsIgnoreComptime(zcu);
        const err_union_llvm_ty = try o.lowerType(pt, err_union_ty);
        const error_type = try o.errorIntType(pt);

        if (!err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
            const loaded = loaded: {
                const access_kind: Builder.MemoryAccessKind =
                    if (err_union_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

                if (!payload_has_bits) {
                    // TODO add alignment to this load
                    break :loaded if (operand_is_ptr)
                        try fg.wip.load(access_kind, error_type, err_union, .default, "")
                    else
                        err_union;
                }
                const err_field_index = try errUnionErrorOffset(payload_ty, pt);
                if (operand_is_ptr or isByRef(err_union_ty, zcu)) {
                    const err_field_ptr =
                        try fg.wip.gepStruct(err_union_llvm_ty, err_union, err_field_index, "");
                    // TODO add alignment to this load
                    break :loaded try fg.wip.load(
                        if (operand_is_ptr) access_kind else .normal,
                        error_type,
                        err_field_ptr,
                        .default,
                        "",
                    );
                }
                break :loaded try fg.wip.extractValue(err_union, &.{err_field_index}, "");
            };
            const zero = try o.builder.intValue(error_type, 0);
            const is_err = try fg.wip.icmp(.ne, loaded, zero, "");

            const return_block = try fg.wip.block(1, "TryRet");
            const continue_block = try fg.wip.block(1, "TryCont");
            _ = try fg.wip.brCond(is_err, return_block, continue_block, if (err_cold) .none else .else_likely);

            fg.wip.cursor = .{ .block = return_block };
            if (err_cold) _ = try fg.wip.callIntrinsicAssumeCold();
            try fg.genBodyDebugScope(null, body, .poi);

            fg.wip.cursor = .{ .block = continue_block };
        }
        if (is_unused) return .none;
        if (!payload_has_bits) return if (operand_is_ptr) err_union else .none;
        const offset = try errUnionPayloadOffset(payload_ty, pt);
        if (operand_is_ptr) {
            return fg.wip.gepStruct(err_union_llvm_ty, err_union, offset, "");
        } else if (isByRef(err_union_ty, zcu)) {
            const payload_ptr = try fg.wip.gepStruct(err_union_llvm_ty, err_union, offset, "");
            const payload_alignment = payload_ty.abiAlignment(zcu).toLlvm();
            if (isByRef(payload_ty, zcu)) {
                if (can_elide_load)
                    return payload_ptr;

                return fg.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            const load_ty = err_union_llvm_ty.structFields(&o.builder)[offset];
            return fg.wip.load(.normal, load_ty, payload_ptr, payload_alignment, "");
        }
        return fg.wip.extractValue(err_union, &.{offset}, "");
    }

    fn airSwitchBr(self: *FuncGen, inst: Air.Inst.Index, is_dispatch_loop: bool) !void {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;

        const switch_br = self.air.unwrapSwitch(inst);

        // For `loop_switch_br`, we need these BBs prepared ahead of time to generate dispatches.
        // For `switch_br`, they allow us to sometimes generate better IR by sharing a BB between
        // scalar and range cases in the same prong.
        // +1 for `else` case. This is not the same as the LLVM `else` prong, as that may first contain
        // conditionals to handle ranges.
        const case_blocks = try self.gpa.alloc(Builder.Function.Block.Index, switch_br.cases_len + 1);
        defer self.gpa.free(case_blocks);
        // We set incoming as 0 for now, and increment it as we construct dispatches.
        for (case_blocks[0 .. case_blocks.len - 1]) |*b| b.* = try self.wip.block(0, "Case");
        case_blocks[case_blocks.len - 1] = try self.wip.block(0, "Default");

        // There's a special case here to manually generate a jump table in some cases.
        //
        // Labeled switch in Zig is intended to follow the "direct threading" pattern. We would ideally use a jump
        // table, and each `continue` has its own indirect `jmp`, to allow the branch predictor to more accurately
        // use data patterns to predict future dispatches. The problem, however, is that LLVM emits fascinatingly
        // bad asm for this. Not only does it not share the jump table -- which we really need it to do to prevent
        // destroying the cache -- but it also actually generates slightly different jump tables for each case,
        // and *a separate conditional branch beforehand* to handle dispatching back to the case we're currently
        // within(!!).
        //
        // This asm is really, really, not what we want. As such, we will construct the jump table manually where
        // appropriate (the values are dense and relatively few), and use it when lowering dispatches.

        const jmp_table: ?SwitchDispatchInfo.JmpTable = jmp_table: {
            if (!is_dispatch_loop) break :jmp_table null;

            // Workaround for:
            // * https://github.com/llvm/llvm-project/blob/56905dab7da50bccfcceaeb496b206ff476127e1/llvm/lib/MC/WasmObjectWriter.cpp#L560
            // * https://github.com/llvm/llvm-project/blob/56905dab7da50bccfcceaeb496b206ff476127e1/llvm/test/MC/WebAssembly/blockaddress.ll
            if (zcu.comp.getTarget().cpu.arch.isWasm()) break :jmp_table null;

            // On a 64-bit target, 1024 pointers in our jump table is about 8K of pointers. This seems just
            // about acceptable - it won't fill L1d cache on most CPUs.
            const max_table_len = 1024;

            const cond_ty = self.typeOf(switch_br.operand);
            switch (cond_ty.zigTypeTag(zcu)) {
                .bool, .pointer => break :jmp_table null,
                .@"enum", .int, .error_set => {},
                else => unreachable,
            }

            if (cond_ty.intInfo(zcu).signedness == .signed) break :jmp_table null;

            // Don't worry about the size of the type -- it's irrelevant, because the prong values could be fairly dense.
            // If they are, then we will construct a jump table.
            const min, const max = self.switchCaseItemRange(switch_br);
            const min_int = min.getUnsignedInt(zcu) orelse break :jmp_table null;
            const max_int = max.getUnsignedInt(zcu) orelse break :jmp_table null;
            const table_len = max_int - min_int + 1;
            if (table_len > max_table_len) break :jmp_table null;

            const table_elems = try self.gpa.alloc(Builder.Constant, @intCast(table_len));
            defer self.gpa.free(table_elems);

            // Set them all to the `else` branch, then iterate over the AIR switch
            // and replace all values which correspond to other prongs.
            @memset(table_elems, try o.builder.blockAddrConst(
                self.wip.function,
                case_blocks[case_blocks.len - 1],
            ));
            var item_count: u32 = 0;
            var it = switch_br.iterateCases();
            while (it.next()) |case| {
                const case_block = case_blocks[case.idx];
                const case_block_addr = try o.builder.blockAddrConst(
                    self.wip.function,
                    case_block,
                );
                for (case.items) |item| {
                    const val = Value.fromInterned(item.toInterned().?);
                    const table_idx = val.toUnsignedInt(zcu) - min_int;
                    table_elems[@intCast(table_idx)] = case_block_addr;
                    item_count += 1;
                }
                for (case.ranges) |range| {
                    const low = Value.fromInterned(range[0].toInterned().?);
                    const high = Value.fromInterned(range[1].toInterned().?);
                    const low_idx = low.toUnsignedInt(zcu) - min_int;
                    const high_idx = high.toUnsignedInt(zcu) - min_int;
                    @memset(table_elems[@intCast(low_idx)..@intCast(high_idx + 1)], case_block_addr);
                    item_count += @intCast(high_idx + 1 - low_idx);
                }
            }

            const table_llvm_ty = try o.builder.arrayType(table_elems.len, .ptr);
            const table_val = try o.builder.arrayConst(table_llvm_ty, table_elems);

            const table_variable = try o.builder.addVariable(
                try o.builder.strtabStringFmt("__jmptab_{d}", .{@intFromEnum(inst)}),
                table_llvm_ty,
                .default,
            );
            try table_variable.setInitializer(table_val, &o.builder);
            table_variable.setLinkage(.internal, &o.builder);
            table_variable.setUnnamedAddr(.unnamed_addr, &o.builder);

            const table_includes_else = item_count != table_len;

            break :jmp_table .{
                .min = try o.lowerValue(pt, min.toIntern()),
                .max = try o.lowerValue(pt, max.toIntern()),
                .in_bounds_hint = if (table_includes_else) .none else switch (switch_br.getElseHint()) {
                    .none, .cold => .none,
                    .unpredictable => .unpredictable,
                    .likely => .likely,
                    .unlikely => .unlikely,
                },
                .table = table_variable.toConst(&o.builder),
                .table_includes_else = table_includes_else,
            };
        };

        const weights: Builder.Function.Instruction.BrCond.Weights = weights: {
            if (jmp_table != null) break :weights .none; // not used

            // First pass. If any weights are `.unpredictable`, unpredictable.
            // If all are `.none` or `.cold`, none.
            var any_likely = false;
            for (0..switch_br.cases_len) |case_idx| {
                switch (switch_br.getHint(@intCast(case_idx))) {
                    .none, .cold => {},
                    .likely, .unlikely => any_likely = true,
                    .unpredictable => break :weights .unpredictable,
                }
            }
            switch (switch_br.getElseHint()) {
                .none, .cold => {},
                .likely, .unlikely => any_likely = true,
                .unpredictable => break :weights .unpredictable,
            }
            if (!any_likely) break :weights .none;

            const llvm_cases_len = llvm_cases_len: {
                var len: u32 = 0;
                var it = switch_br.iterateCases();
                while (it.next()) |case| len += @intCast(case.items.len);
                break :llvm_cases_len len;
            };

            var weights = try self.gpa.alloc(Builder.Metadata, llvm_cases_len + 1);
            defer self.gpa.free(weights);

            const else_weight: u32 = switch (switch_br.getElseHint()) {
                .unpredictable => unreachable,
                .none, .cold => 1000,
                .likely => 2000,
                .unlikely => 1,
            };
            weights[0] = try o.builder.metadataConstant(try o.builder.intConst(.i32, else_weight));

            var weight_idx: usize = 1;
            var it = switch_br.iterateCases();
            while (it.next()) |case| {
                const weight_val: u32 = switch (switch_br.getHint(case.idx)) {
                    .unpredictable => unreachable,
                    .none, .cold => 1000,
                    .likely => 2000,
                    .unlikely => 1,
                };
                const weight_meta = try o.builder.metadataConstant(try o.builder.intConst(.i32, weight_val));
                @memset(weights[weight_idx..][0..case.items.len], weight_meta);
                weight_idx += case.items.len;
            }

            assert(weight_idx == weights.len);

            const branch_weights_str = try o.builder.metadataString("branch_weights");
            const tuple = try o.builder.strTuple(branch_weights_str, weights);
            break :weights @enumFromInt(@intFromEnum(tuple));
        };

        const dispatch_info: SwitchDispatchInfo = .{
            .case_blocks = case_blocks,
            .switch_weights = weights,
            .jmp_table = jmp_table,
        };

        if (is_dispatch_loop) {
            try self.switch_dispatch_info.putNoClobber(self.gpa, inst, dispatch_info);
        }
        defer if (is_dispatch_loop) {
            assert(self.switch_dispatch_info.remove(inst));
        };

        // Generate the initial dispatch.
        // If this is a simple `switch_br`, this is the only dispatch.
        try self.lowerSwitchDispatch(inst, switch_br.operand, dispatch_info);

        // Iterate the cases and generate their bodies.
        var it = switch_br.iterateCases();
        while (it.next()) |case| {
            const case_block = case_blocks[case.idx];
            self.wip.cursor = .{ .block = case_block };
            if (switch_br.getHint(case.idx) == .cold) _ = try self.wip.callIntrinsicAssumeCold();
            try self.genBodyDebugScope(null, case.body, .none);
        }
        self.wip.cursor = .{ .block = case_blocks[case_blocks.len - 1] };
        const else_body = it.elseBody();
        if (switch_br.getElseHint() == .cold) _ = try self.wip.callIntrinsicAssumeCold();
        if (else_body.len > 0) {
            try self.genBodyDebugScope(null, it.elseBody(), .none);
        } else {
            _ = try self.wip.@"unreachable"();
        }
    }

    fn switchCaseItemRange(self: *FuncGen, switch_br: Air.UnwrappedSwitch) [2]Value {
        const zcu = self.ng.pt.zcu;
        var it = switch_br.iterateCases();
        var min: ?Value = null;
        var max: ?Value = null;
        while (it.next()) |case| {
            for (case.items) |item| {
                const val = Value.fromInterned(item.toInterned().?);
                const low = if (min) |m| val.compareHetero(.lt, m, zcu) else true;
                const high = if (max) |m| val.compareHetero(.gt, m, zcu) else true;
                if (low) min = val;
                if (high) max = val;
            }
            for (case.ranges) |range| {
                const vals: [2]Value = .{
                    Value.fromInterned(range[0].toInterned().?),
                    Value.fromInterned(range[1].toInterned().?),
                };
                const low = if (min) |m| vals[0].compareHetero(.lt, m, zcu) else true;
                const high = if (max) |m| vals[1].compareHetero(.gt, m, zcu) else true;
                if (low) min = vals[0];
                if (high) max = vals[1];
            }
        }
        return .{ min.?, max.? };
    }

    fn airLoop(self: *FuncGen, inst: Air.Inst.Index) !void {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const loop = self.air.extraData(Air.Block, ty_pl.payload);
        const body: []const Air.Inst.Index = @ptrCast(self.air.extra.items[loop.end..][0..loop.data.body_len]);
        const loop_block = try self.wip.block(1, "Loop"); // `airRepeat` will increment incoming each time
        _ = try self.wip.br(loop_block);

        try self.loops.putNoClobber(self.gpa, inst, loop_block);
        defer assert(self.loops.remove(inst));

        self.wip.cursor = .{ .block = loop_block };
        try self.genBodyDebugScope(null, body, .none);
    }

    fn airArrayToSlice(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const array_ty = operand_ty.childType(zcu);
        const llvm_usize = try o.lowerType(pt, Type.usize);
        const len = try o.builder.intValue(llvm_usize, array_ty.arrayLen(zcu));
        const slice_llvm_ty = try o.lowerType(pt, self.typeOfIndex(inst));
        const operand = try self.resolveInst(ty_op.operand);
        if (!array_ty.hasRuntimeBitsIgnoreComptime(zcu))
            return self.wip.buildAggregate(slice_llvm_ty, &.{ operand, len }, "");
        const ptr = try self.wip.gep(.inbounds, try o.lowerType(pt, array_ty), operand, &.{
            try o.builder.intValue(llvm_usize, 0), try o.builder.intValue(llvm_usize, 0),
        }, "");
        return self.wip.buildAggregate(slice_llvm_ty, &.{ ptr, len }, "");
    }

    fn airFloatFromInt(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_scalar_ty = operand_ty.scalarType(zcu);
        const is_signed_int = operand_scalar_ty.isSignedInt(zcu);

        const dest_ty = self.typeOfIndex(inst);
        const dest_scalar_ty = dest_ty.scalarType(zcu);
        const dest_llvm_ty = try o.lowerType(pt, dest_ty);
        const target = zcu.getTarget();

        if (intrinsicsAllowed(dest_scalar_ty, target)) return self.wip.conv(
            if (is_signed_int) .signed else .unsigned,
            operand,
            dest_llvm_ty,
            "",
        );

        const rt_int_bits = compilerRtIntBits(@intCast(operand_scalar_ty.bitSize(zcu)));
        const rt_int_ty = try o.builder.intType(rt_int_bits);
        var extended = try self.wip.conv(
            if (is_signed_int) .signed else .unsigned,
            operand,
            rt_int_ty,
            "",
        );
        const dest_bits = dest_scalar_ty.floatBits(target);
        const compiler_rt_operand_abbrev = compilerRtIntAbbrev(rt_int_bits);
        const compiler_rt_dest_abbrev = compilerRtFloatAbbrev(dest_bits);
        const sign_prefix = if (is_signed_int) "" else "un";
        const fn_name = try o.builder.strtabStringFmt("__float{s}{s}i{s}f", .{
            sign_prefix,
            compiler_rt_operand_abbrev,
            compiler_rt_dest_abbrev,
        });

        var param_type = rt_int_ty;
        if (rt_int_bits == 128 and (target.os.tag == .windows and target.cpu.arch == .x86_64)) {
            // On Windows x86-64, "ti" functions must use Vector(2, u64) instead of the standard
            // i128 calling convention to adhere to the ABI that LLVM expects compiler-rt to have.
            param_type = try o.builder.vectorType(.normal, 2, .i64);
            extended = try self.wip.cast(.bitcast, extended, param_type, "");
        }

        const libc_fn = try self.getLibcFunction(fn_name, &.{param_type}, dest_llvm_ty);
        return self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &.{extended},
            "",
        );
    }

    fn airIntFromFloat(
        self: *FuncGen,
        inst: Air.Inst.Index,
        fast: Builder.FastMathKind,
    ) !Builder.Value {
        _ = fast;

        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand_scalar_ty = operand_ty.scalarType(zcu);

        const dest_ty = self.typeOfIndex(inst);
        const dest_scalar_ty = dest_ty.scalarType(zcu);
        const dest_llvm_ty = try o.lowerType(pt, dest_ty);

        if (intrinsicsAllowed(operand_scalar_ty, target)) {
            // TODO set fast math flag
            return self.wip.conv(
                if (dest_scalar_ty.isSignedInt(zcu)) .signed else .unsigned,
                operand,
                dest_llvm_ty,
                "",
            );
        }

        const rt_int_bits = compilerRtIntBits(@intCast(dest_scalar_ty.bitSize(zcu)));
        const ret_ty = try o.builder.intType(rt_int_bits);
        const libc_ret_ty = if (rt_int_bits == 128 and (target.os.tag == .windows and target.cpu.arch == .x86_64)) b: {
            // On Windows x86-64, "ti" functions must use Vector(2, u64) instead of the standard
            // i128 calling convention to adhere to the ABI that LLVM expects compiler-rt to have.
            break :b try o.builder.vectorType(.normal, 2, .i64);
        } else ret_ty;

        const operand_bits = operand_scalar_ty.floatBits(target);
        const compiler_rt_operand_abbrev = compilerRtFloatAbbrev(operand_bits);

        const compiler_rt_dest_abbrev = compilerRtIntAbbrev(rt_int_bits);
        const sign_prefix = if (dest_scalar_ty.isSignedInt(zcu)) "" else "uns";

        const fn_name = try o.builder.strtabStringFmt("__fix{s}{s}f{s}i", .{
            sign_prefix,
            compiler_rt_operand_abbrev,
            compiler_rt_dest_abbrev,
        });

        const operand_llvm_ty = try o.lowerType(pt, operand_ty);
        const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, libc_ret_ty);
        var result = try self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &.{operand},
            "",
        );

        if (libc_ret_ty != ret_ty) result = try self.wip.cast(.bitcast, result, ret_ty, "");
        if (ret_ty != dest_llvm_ty) result = try self.wip.cast(.trunc, result, dest_llvm_ty, "");
        return result;
    }

    fn sliceOrArrayPtr(fg: *FuncGen, ptr: Builder.Value, ty: Type) Allocator.Error!Builder.Value {
        const zcu = fg.ng.pt.zcu;
        return if (ty.isSlice(zcu)) fg.wip.extractValue(ptr, &.{0}, "") else ptr;
    }

    fn sliceOrArrayLenInBytes(fg: *FuncGen, ptr: Builder.Value, ty: Type) Allocator.Error!Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const llvm_usize = try o.lowerType(pt, Type.usize);
        switch (ty.ptrSize(zcu)) {
            .slice => {
                const len = try fg.wip.extractValue(ptr, &.{1}, "");
                const elem_ty = ty.childType(zcu);
                const abi_size = elem_ty.abiSize(zcu);
                if (abi_size == 1) return len;
                const abi_size_llvm_val = try o.builder.intValue(llvm_usize, abi_size);
                return fg.wip.bin(.@"mul nuw", len, abi_size_llvm_val, "");
            },
            .one => {
                const array_ty = ty.childType(zcu);
                const elem_ty = array_ty.childType(zcu);
                const abi_size = elem_ty.abiSize(zcu);
                return o.builder.intValue(llvm_usize, array_ty.arrayLen(zcu) * abi_size);
            },
            .many, .c => unreachable,
        }
    }

    fn airSliceField(self: *FuncGen, inst: Air.Inst.Index, index: u32) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        return self.wip.extractValue(operand, &.{index}, "");
    }

    fn airPtrSliceFieldPtr(self: *FuncGen, inst: Air.Inst.Index, index: c_uint) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const slice_ptr = try self.resolveInst(ty_op.operand);
        const slice_ptr_ty = self.typeOf(ty_op.operand);
        const slice_llvm_ty = try o.lowerPtrElemTy(pt, slice_ptr_ty.childType(zcu));

        return self.wip.gepStruct(slice_llvm_ty, slice_ptr, index, "");
    }

    fn airSliceElemVal(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const slice_ty = self.typeOf(bin_op.lhs);
        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        const elem_ty = slice_ty.childType(zcu);
        const llvm_elem_ty = try o.lowerPtrElemTy(pt, elem_ty);
        const base_ptr = try self.wip.extractValue(slice, &.{0}, "");
        const ptr = try self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, &.{index}, "");
        if (isByRef(elem_ty, zcu)) {
            self.maybeMarkAllowZeroAccess(slice_ty.ptrInfo(zcu));

            const slice_align = (slice_ty.ptrAlignment(zcu).min(elem_ty.abiAlignment(zcu))).toLlvm();
            return self.loadByRef(ptr, elem_ty, slice_align, if (slice_ty.isVolatilePtr(zcu)) .@"volatile" else .normal);
        }

        self.maybeMarkAllowZeroAccess(slice_ty.ptrInfo(zcu));

        return self.load(ptr, slice_ty);
    }

    fn airSliceElemPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const slice_ty = self.typeOf(bin_op.lhs);

        const slice = try self.resolveInst(bin_op.lhs);
        const index = try self.resolveInst(bin_op.rhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(pt, slice_ty.childType(zcu));
        const base_ptr = try self.wip.extractValue(slice, &.{0}, "");
        return self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, &.{index}, "");
    }

    fn airArrayElemVal(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;

        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const array_ty = self.typeOf(bin_op.lhs);
        const array_llvm_val = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const array_llvm_ty = try o.lowerType(pt, array_ty);
        const elem_ty = array_ty.childType(zcu);
        if (isByRef(array_ty, zcu)) {
            const indices: [2]Builder.Value = .{
                try o.builder.intValue(try o.lowerType(pt, Type.usize), 0), rhs,
            };
            if (isByRef(elem_ty, zcu)) {
                const elem_ptr = try self.wip.gep(.inbounds, array_llvm_ty, array_llvm_val, &indices, "");
                const elem_alignment = elem_ty.abiAlignment(zcu).toLlvm();
                return self.loadByRef(elem_ptr, elem_ty, elem_alignment, .normal);
            } else {
                const elem_ptr =
                    try self.wip.gep(.inbounds, array_llvm_ty, array_llvm_val, &indices, "");
                return self.loadTruncate(.normal, elem_ty, elem_ptr, .default);
            }
        }

        // This branch can be reached for vectors, which are always by-value.
        return self.wip.extractElement(array_llvm_val, rhs, "");
    }

    fn airPtrElemVal(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(zcu);
        const llvm_elem_ty = try o.lowerPtrElemTy(pt, elem_ty);
        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        // TODO: when we go fully opaque pointers in LLVM 16 we can remove this branch
        const ptr = try self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, if (ptr_ty.isSinglePointer(zcu))
            // If this is a single-item pointer to an array, we need another index in the GEP.
            &.{ try o.builder.intValue(try o.lowerType(pt, Type.usize), 0), rhs }
        else
            &.{rhs}, "");
        if (isByRef(elem_ty, zcu)) {
            self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));
            const ptr_align = (ptr_ty.ptrAlignment(zcu).min(elem_ty.abiAlignment(zcu))).toLlvm();
            return self.loadByRef(ptr, elem_ty, ptr_align, if (ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal);
        }

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        return self.load(ptr, ptr_ty);
    }

    fn airPtrElemPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = ptr_ty.childType(zcu);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) return self.resolveInst(bin_op.lhs);

        const base_ptr = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const elem_ptr = ty_pl.ty.toType();
        if (elem_ptr.ptrInfo(zcu).flags.vector_index != .none) return base_ptr;

        const llvm_elem_ty = try o.lowerPtrElemTy(pt, elem_ty);
        return self.wip.gep(.inbounds, llvm_elem_ty, base_ptr, if (ptr_ty.isSinglePointer(zcu))
            // If this is a single-item pointer to an array, we need another index in the GEP.
            &.{ try o.builder.intValue(try o.lowerType(pt, Type.usize), 0), rhs }
        else
            &.{rhs}, "");
    }

    fn airStructFieldPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ptr = try self.resolveInst(struct_field.struct_operand);
        const struct_ptr_ty = self.typeOf(struct_field.struct_operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, struct_field.field_index);
    }

    fn airStructFieldPtrIndex(
        self: *FuncGen,
        inst: Air.Inst.Index,
        field_index: u32,
    ) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const struct_ptr = try self.resolveInst(ty_op.operand);
        const struct_ptr_ty = self.typeOf(ty_op.operand);
        return self.fieldPtr(inst, struct_ptr, struct_ptr_ty, field_index);
    }

    fn airStructFieldVal(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
        const struct_ty = self.typeOf(struct_field.struct_operand);
        const struct_llvm_val = try self.resolveInst(struct_field.struct_operand);
        const field_index = struct_field.field_index;
        const field_ty = struct_ty.fieldType(field_index, zcu);
        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

        if (!isByRef(struct_ty, zcu)) {
            assert(!isByRef(field_ty, zcu));
            switch (struct_ty.zigTypeTag(zcu)) {
                .@"struct" => switch (struct_ty.containerLayout(zcu)) {
                    .@"packed" => {
                        const struct_type = zcu.typeToStruct(struct_ty).?;
                        const bit_offset = zcu.structPackedFieldBitOffset(struct_type, field_index);
                        const containing_int = struct_llvm_val;
                        const shift_amt =
                            try o.builder.intValue(containing_int.typeOfWip(&self.wip), bit_offset);
                        const shifted_value = try self.wip.bin(.lshr, containing_int, shift_amt, "");
                        const elem_llvm_ty = try o.lowerType(pt, field_ty);
                        if (field_ty.zigTypeTag(zcu) == .float or field_ty.zigTypeTag(zcu) == .vector) {
                            const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(zcu)));
                            const truncated_int =
                                try self.wip.cast(.trunc, shifted_value, same_size_int, "");
                            return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
                        } else if (field_ty.isPtrAtRuntime(zcu)) {
                            const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(zcu)));
                            const truncated_int =
                                try self.wip.cast(.trunc, shifted_value, same_size_int, "");
                            return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
                        }
                        return self.wip.cast(.trunc, shifted_value, elem_llvm_ty, "");
                    },
                    else => {
                        const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
                        return self.wip.extractValue(struct_llvm_val, &.{llvm_field_index}, "");
                    },
                },
                .@"union" => {
                    assert(struct_ty.containerLayout(zcu) == .@"packed");
                    const containing_int = struct_llvm_val;
                    const elem_llvm_ty = try o.lowerType(pt, field_ty);
                    if (field_ty.zigTypeTag(zcu) == .float or field_ty.zigTypeTag(zcu) == .vector) {
                        const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(zcu)));
                        const truncated_int =
                            try self.wip.cast(.trunc, containing_int, same_size_int, "");
                        return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
                    } else if (field_ty.isPtrAtRuntime(zcu)) {
                        const same_size_int = try o.builder.intType(@intCast(field_ty.bitSize(zcu)));
                        const truncated_int =
                            try self.wip.cast(.trunc, containing_int, same_size_int, "");
                        return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
                    }
                    return self.wip.cast(.trunc, containing_int, elem_llvm_ty, "");
                },
                else => unreachable,
            }
        }

        switch (struct_ty.zigTypeTag(zcu)) {
            .@"struct" => {
                const layout = struct_ty.containerLayout(zcu);
                assert(layout != .@"packed");
                const struct_llvm_ty = try o.lowerType(pt, struct_ty);
                const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
                const field_ptr =
                    try self.wip.gepStruct(struct_llvm_ty, struct_llvm_val, llvm_field_index, "");
                const alignment = struct_ty.fieldAlignment(field_index, zcu);
                const field_ptr_ty = try pt.ptrType(.{
                    .child = field_ty.toIntern(),
                    .flags = .{ .alignment = alignment },
                });
                if (isByRef(field_ty, zcu)) {
                    assert(alignment != .none);
                    const field_alignment = alignment.toLlvm();
                    return self.loadByRef(field_ptr, field_ty, field_alignment, .normal);
                } else {
                    return self.load(field_ptr, field_ptr_ty);
                }
            },
            .@"union" => {
                const union_llvm_ty = try o.lowerType(pt, struct_ty);
                const layout = struct_ty.unionGetLayout(zcu);
                const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
                const field_ptr =
                    try self.wip.gepStruct(union_llvm_ty, struct_llvm_val, payload_index, "");
                const payload_alignment = layout.payload_align.toLlvm();
                if (isByRef(field_ty, zcu)) {
                    return self.loadByRef(field_ptr, field_ty, payload_alignment, .normal);
                } else {
                    return self.loadTruncate(.normal, field_ty, field_ptr, payload_alignment);
                }
            },
            else => unreachable,
        }
    }

    fn airFieldParentPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

        const field_ptr = try self.resolveInst(extra.field_ptr);

        const parent_ty = ty_pl.ty.toType().childType(zcu);
        const field_offset = parent_ty.structFieldOffset(extra.field_index, zcu);
        if (field_offset == 0) return field_ptr;

        const res_ty = try o.lowerType(pt, ty_pl.ty.toType());
        const llvm_usize = try o.lowerType(pt, Type.usize);

        const field_ptr_int = try self.wip.cast(.ptrtoint, field_ptr, llvm_usize, "");
        const base_ptr_int = try self.wip.bin(
            .@"sub nuw",
            field_ptr_int,
            try o.builder.intValue(llvm_usize, field_offset),
            "",
        );
        return self.wip.cast(.inttoptr, base_ptr_int, res_ty, "");
    }

    fn airNot(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);

        return self.wip.not(operand, "");
    }

    fn airUnreach(self: *FuncGen, inst: Air.Inst.Index) !void {
        _ = inst;
        _ = try self.wip.@"unreachable"();
    }

    fn airDbgStmt(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
        self.prev_dbg_line = @intCast(self.base_line + dbg_stmt.line + 1);
        self.prev_dbg_column = @intCast(dbg_stmt.column + 1);

        self.wip.debug_location = .{
            .location = .{
                .line = self.prev_dbg_line,
                .column = self.prev_dbg_column,
                .scope = self.scope,
                .inlined_at = try self.inlined.toMetadata(self.wip.builder),
            },
        };

        return .none;
    }

    fn airDbgEmptyStmt(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = self;
        _ = inst;
        return .none;
    }

    fn airDbgInlineBlock(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
        self.arg_inline_index = 0;
        return self.lowerBlock(inst, extra.data.func, @ptrCast(self.air.extra.items[extra.end..][0..extra.data.body_len]));
    }

    fn airDbgVarPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);
        const ptr_ty = self.typeOf(pl_op.operand);

        const debug_local_var = try o.builder.debugLocalVar(
            try o.builder.metadataString(name.toSlice(self.air)),
            self.file,
            self.scope,
            self.prev_dbg_line,
            try o.lowerDebugType(pt, ptr_ty.childType(zcu)),
        );

        _ = try self.wip.callIntrinsic(
            .normal,
            .none,
            .@"dbg.declare",
            &.{},
            &.{
                (try self.wip.debugValue(operand)).toValue(),
                debug_local_var.toValue(),
                (try o.builder.debugExpression(&.{})).toValue(),
            },
            "",
        );

        return .none;
    }

    fn airDbgVarVal(self: *FuncGen, inst: Air.Inst.Index, is_arg: bool) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const operand = try self.resolveInst(pl_op.operand);
        const operand_ty = self.typeOf(pl_op.operand);
        const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);

        const debug_local_var = if (is_arg) try o.builder.debugParameter(
            try o.builder.metadataString(name.toSlice(self.air)),
            self.file,
            self.scope,
            self.prev_dbg_line,
            try o.lowerDebugType(pt, operand_ty),
            arg_no: {
                self.arg_inline_index += 1;
                break :arg_no self.arg_inline_index;
            },
        ) else try o.builder.debugLocalVar(
            try o.builder.metadataString(name.toSlice(self.air)),
            self.file,
            self.scope,
            self.prev_dbg_line,
            try o.lowerDebugType(pt, operand_ty),
        );

        const zcu = pt.zcu;
        const owner_mod = self.ng.ownerModule();
        if (isByRef(operand_ty, zcu)) {
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.declare",
                &.{},
                &.{
                    (try self.wip.debugValue(operand)).toValue(),
                    debug_local_var.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        } else if (owner_mod.optimize_mode == .Debug and !self.is_naked) {
            // We avoid taking this path for naked functions because there's no guarantee that such
            // functions even have a valid stack pointer, making the `alloca` + `store` unsafe.

            const alignment = operand_ty.abiAlignment(zcu).toLlvm();
            const alloca = try self.buildAlloca(operand.typeOfWip(&self.wip), alignment);
            _ = try self.wip.store(.normal, operand, alloca, alignment);
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.declare",
                &.{},
                &.{
                    (try self.wip.debugValue(alloca)).toValue(),
                    debug_local_var.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        } else {
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.value",
                &.{},
                &.{
                    (try self.wip.debugValue(operand)).toValue(),
                    debug_local_var.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        }
        return .none;
    }

    fn airAssembly(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        // Eventually, the Zig compiler needs to be reworked to have inline
        // assembly go through the same parsing code regardless of backend, and
        // have LLVM-flavored inline assembly be *output* from that assembler.
        // We don't have such an assembler implemented yet though. For now,
        // this implementation feeds the inline assembly code directly to LLVM.

        const o = self.ng.object;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Asm, ty_pl.payload);
        const is_volatile = extra.data.flags.is_volatile;
        const outputs_len = extra.data.flags.outputs_len;
        const gpa = self.gpa;
        var extra_i: usize = extra.end;

        const outputs: []const Air.Inst.Ref = @ptrCast(self.air.extra.items[extra_i..][0..outputs_len]);
        extra_i += outputs.len;
        const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra.items[extra_i..][0..extra.data.inputs_len]);
        extra_i += inputs.len;

        var llvm_constraints: std.ArrayListUnmanaged(u8) = .empty;
        defer llvm_constraints.deinit(gpa);

        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        // The exact number of return / parameter values depends on which output values
        // are passed by reference as indirect outputs (determined below).
        const max_return_count = outputs.len;
        const llvm_ret_types = try arena.alloc(Builder.Type, max_return_count);
        const llvm_ret_indirect = try arena.alloc(bool, max_return_count);
        const llvm_rw_vals = try arena.alloc(Builder.Value, max_return_count);

        const max_param_count = max_return_count + inputs.len + outputs.len;
        const llvm_param_types = try arena.alloc(Builder.Type, max_param_count);
        const llvm_param_values = try arena.alloc(Builder.Value, max_param_count);
        // This stores whether we need to add an elementtype attribute and
        // if so, the element type itself.
        const llvm_param_attrs = try arena.alloc(Builder.Type, max_param_count);
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();

        var llvm_ret_i: usize = 0;
        var llvm_param_i: usize = 0;
        var total_i: usize = 0;

        var name_map: std.StringArrayHashMapUnmanaged(u16) = .empty;
        try name_map.ensureUnusedCapacity(arena, max_param_count);

        var rw_extra_i = extra_i;
        for (outputs, llvm_ret_indirect, llvm_rw_vals) |output, *is_indirect, *llvm_rw_val| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra.items[extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra.items[extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            try llvm_constraints.ensureUnusedCapacity(gpa, constraint.len + 3);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            llvm_constraints.appendAssumeCapacity('=');

            if (output != .none) {
                const output_inst = try self.resolveInst(output);
                const output_ty = self.typeOf(output);
                assert(output_ty.zigTypeTag(zcu) == .pointer);
                const elem_llvm_ty = try o.lowerPtrElemTy(pt, output_ty.childType(zcu));

                switch (constraint[0]) {
                    '=' => {},
                    '+' => llvm_rw_val.* = output_inst,
                    else => return self.todo("unsupported output constraint on output type '{c}'", .{
                        constraint[0],
                    }),
                }

                self.maybeMarkAllowZeroAccess(output_ty.ptrInfo(zcu));

                // Pass any non-return outputs indirectly, if the constraint accepts a memory location
                is_indirect.* = constraintAllowsMemory(constraint);
                if (is_indirect.*) {
                    // Pass the result by reference as an indirect output (e.g. "=*m")
                    llvm_constraints.appendAssumeCapacity('*');

                    llvm_param_values[llvm_param_i] = output_inst;
                    llvm_param_types[llvm_param_i] = output_inst.typeOfWip(&self.wip);
                    llvm_param_attrs[llvm_param_i] = elem_llvm_ty;
                    llvm_param_i += 1;
                } else {
                    // Pass the result directly (e.g. "=r")
                    llvm_ret_types[llvm_ret_i] = elem_llvm_ty;
                    llvm_ret_i += 1;
                }
            } else {
                switch (constraint[0]) {
                    '=' => {},
                    else => return self.todo("unsupported output constraint on result type '{s}'", .{
                        constraint,
                    }),
                }

                is_indirect.* = false;

                const ret_ty = self.typeOfIndex(inst);
                llvm_ret_types[llvm_ret_i] = try o.lowerType(pt, ret_ty);
                llvm_ret_i += 1;
            }

            // LLVM uses commas internally to separate different constraints,
            // alternative constraints are achieved with pipes.
            // We still allow the user to use commas in a way that is similar
            // to GCC's inline assembly.
            // http://llvm.org/docs/LangRef.html#constraint-codes
            for (constraint[1..]) |byte| {
                switch (byte) {
                    ',' => llvm_constraints.appendAssumeCapacity('|'),
                    '*' => {}, // Indirect outputs are handled above
                    else => llvm_constraints.appendAssumeCapacity(byte),
                }
            }

            if (!std.mem.eql(u8, name, "_")) {
                const gop = name_map.getOrPutAssumeCapacity(name);
                if (gop.found_existing) return self.todo("duplicate asm output name '{s}'", .{name});
                gop.value_ptr.* = @intCast(total_i);
            }
            total_i += 1;
        }

        for (inputs) |input| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra.items[extra_i..]);
            const constraint = std.mem.sliceTo(extra_bytes, 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const arg_llvm_value = try self.resolveInst(input);
            const arg_ty = self.typeOf(input);
            const is_by_ref = isByRef(arg_ty, zcu);
            if (is_by_ref) {
                if (constraintAllowsMemory(constraint)) {
                    llvm_param_values[llvm_param_i] = arg_llvm_value;
                    llvm_param_types[llvm_param_i] = arg_llvm_value.typeOfWip(&self.wip);
                } else {
                    const alignment = arg_ty.abiAlignment(zcu).toLlvm();
                    const arg_llvm_ty = try o.lowerType(pt, arg_ty);
                    const load_inst =
                        try self.wip.load(.normal, arg_llvm_ty, arg_llvm_value, alignment, "");
                    llvm_param_values[llvm_param_i] = load_inst;
                    llvm_param_types[llvm_param_i] = arg_llvm_ty;
                }
            } else {
                if (constraintAllowsRegister(constraint)) {
                    llvm_param_values[llvm_param_i] = arg_llvm_value;
                    llvm_param_types[llvm_param_i] = arg_llvm_value.typeOfWip(&self.wip);
                } else {
                    const alignment = arg_ty.abiAlignment(zcu).toLlvm();
                    const arg_ptr = try self.buildAlloca(arg_llvm_value.typeOfWip(&self.wip), alignment);
                    _ = try self.wip.store(.normal, arg_llvm_value, arg_ptr, alignment);
                    llvm_param_values[llvm_param_i] = arg_ptr;
                    llvm_param_types[llvm_param_i] = arg_ptr.typeOfWip(&self.wip);
                }
            }

            try llvm_constraints.ensureUnusedCapacity(gpa, constraint.len + 1);
            if (total_i != 0) {
                llvm_constraints.appendAssumeCapacity(',');
            }
            for (constraint) |byte| {
                llvm_constraints.appendAssumeCapacity(switch (byte) {
                    ',' => '|',
                    else => byte,
                });
            }

            if (!std.mem.eql(u8, name, "_")) {
                const gop = name_map.getOrPutAssumeCapacity(name);
                if (gop.found_existing) return self.todo("duplicate asm input name '{s}'", .{name});
                gop.value_ptr.* = @intCast(total_i);
            }

            // In the case of indirect inputs, LLVM requires the callsite to have
            // an elementtype(<ty>) attribute.
            llvm_param_attrs[llvm_param_i] = if (constraint[0] == '*') blk: {
                if (!is_by_ref) self.maybeMarkAllowZeroAccess(arg_ty.ptrInfo(zcu));

                break :blk try o.lowerPtrElemTy(pt, if (is_by_ref) arg_ty else arg_ty.childType(zcu));
            } else .none;

            llvm_param_i += 1;
            total_i += 1;
        }

        for (outputs, llvm_ret_indirect, llvm_rw_vals, 0..) |output, is_indirect, llvm_rw_val, output_index| {
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra.items[rw_extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra.items[rw_extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            rw_extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint[0] != '+') continue;

            const rw_ty = self.typeOf(output);
            const llvm_elem_ty = try o.lowerPtrElemTy(pt, rw_ty.childType(zcu));
            if (is_indirect) {
                llvm_param_values[llvm_param_i] = llvm_rw_val;
                llvm_param_types[llvm_param_i] = llvm_rw_val.typeOfWip(&self.wip);
            } else {
                const alignment = rw_ty.abiAlignment(zcu).toLlvm();
                const loaded = try self.wip.load(
                    if (rw_ty.isVolatilePtr(zcu)) .@"volatile" else .normal,
                    llvm_elem_ty,
                    llvm_rw_val,
                    alignment,
                    "",
                );
                llvm_param_values[llvm_param_i] = loaded;
                llvm_param_types[llvm_param_i] = llvm_elem_ty;
            }

            try llvm_constraints.print(gpa, ",{d}", .{output_index});

            // In the case of indirect inputs, LLVM requires the callsite to have
            // an elementtype(<ty>) attribute.
            llvm_param_attrs[llvm_param_i] = if (is_indirect) llvm_elem_ty else .none;

            llvm_param_i += 1;
            total_i += 1;
        }

        const ip = &zcu.intern_pool;
        const aggregate = ip.indexToKey(extra.data.clobbers).aggregate;
        const struct_type: Type = .fromInterned(aggregate.ty);
        if (total_i != 0) try llvm_constraints.append(gpa, ',');
        switch (aggregate.storage) {
            .elems => |elems| for (elems, 0..) |elem, i| {
                switch (elem) {
                    .bool_true => {
                        const name = struct_type.structFieldName(i, zcu).toSlice(ip).?;
                        total_i += try appendConstraints(gpa, &llvm_constraints, name, target);
                    },
                    .bool_false => continue,
                    else => unreachable,
                }
            },
            .repeated_elem => |elem| switch (elem) {
                .bool_true => for (0..struct_type.structFieldCount(zcu)) |i| {
                    const name = struct_type.structFieldName(i, zcu).toSlice(ip).?;
                    total_i += try appendConstraints(gpa, &llvm_constraints, name, target);
                },
                .bool_false => {},
                else => unreachable,
            },
            .bytes => @panic("TODO"),
        }

        // We have finished scanning through all inputs/outputs, so the number of
        // parameters and return values is known.
        const param_count = llvm_param_i;
        const return_count = llvm_ret_i;

        // For some targets, Clang unconditionally adds some clobbers to all inline assembly.
        // While this is probably not strictly necessary, if we don't follow Clang's lead
        // here then we may risk tripping LLVM bugs since anything not used by Clang tends
        // to be buggy and regress often.
        switch (target.cpu.arch) {
            .x86_64, .x86 => {
                try llvm_constraints.appendSlice(gpa, "~{dirflag},~{fpsr},~{flags},");
                total_i += 3;
            },
            .mips, .mipsel, .mips64, .mips64el => {
                try llvm_constraints.appendSlice(gpa, "~{$1},");
                total_i += 1;
            },
            else => {},
        }

        if (std.mem.endsWith(u8, llvm_constraints.items, ",")) llvm_constraints.items.len -= 1;

        const asm_source = std.mem.sliceAsBytes(self.air.extra.items[extra_i..])[0..extra.data.source_len];

        // hackety hacks until stage2 has proper inline asm in the frontend.
        var rendered_template = std.array_list.Managed(u8).init(gpa);
        defer rendered_template.deinit();

        const State = enum { start, percent, input, modifier };

        var state: State = .start;

        var name_start: usize = undefined;
        var modifier_start: usize = undefined;
        for (asm_source, 0..) |byte, i| {
            switch (state) {
                .start => switch (byte) {
                    '%' => state = .percent,
                    '$' => try rendered_template.appendSlice("$$"),
                    else => try rendered_template.append(byte),
                },
                .percent => switch (byte) {
                    '%' => {
                        try rendered_template.append('%');
                        state = .start;
                    },
                    '[' => {
                        try rendered_template.append('$');
                        try rendered_template.append('{');
                        name_start = i + 1;
                        state = .input;
                    },
                    '=' => {
                        try rendered_template.appendSlice("${:uid}");
                        state = .start;
                    },
                    else => {
                        try rendered_template.append('%');
                        try rendered_template.append(byte);
                        state = .start;
                    },
                },
                .input => switch (byte) {
                    ']', ':' => {
                        const name = asm_source[name_start..i];

                        const index = name_map.get(name) orelse {
                            // we should validate the assembly in Sema; by now it is too late
                            return self.todo("unknown input or output name: '{s}'", .{name});
                        };
                        try rendered_template.print("{d}", .{index});
                        if (byte == ':') {
                            try rendered_template.append(':');
                            modifier_start = i + 1;
                            state = .modifier;
                        } else {
                            try rendered_template.append('}');
                            state = .start;
                        }
                    },
                    else => {},
                },
                .modifier => switch (byte) {
                    ']' => {
                        try rendered_template.appendSlice(asm_source[modifier_start..i]);
                        try rendered_template.append('}');
                        state = .start;
                    },
                    else => {},
                },
            }
        }

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        for (llvm_param_attrs[0..param_count], 0..) |llvm_elem_ty, i| if (llvm_elem_ty != .none)
            try attributes.addParamAttr(i, .{ .elementtype = llvm_elem_ty }, &o.builder);

        const ret_llvm_ty = switch (return_count) {
            0 => .void,
            1 => llvm_ret_types[0],
            else => try o.builder.structType(.normal, llvm_ret_types),
        };
        const llvm_fn_ty = try o.builder.fnType(ret_llvm_ty, llvm_param_types[0..param_count], .normal);
        const call = try self.wip.callAsm(
            try attributes.finish(&o.builder),
            llvm_fn_ty,
            .{ .sideeffect = is_volatile },
            try o.builder.string(rendered_template.items),
            try o.builder.string(llvm_constraints.items),
            llvm_param_values[0..param_count],
            "",
        );

        var ret_val = call;
        llvm_ret_i = 0;
        for (outputs, 0..) |output, i| {
            if (llvm_ret_indirect[i]) continue;

            const output_value = if (return_count > 1)
                try self.wip.extractValue(call, &[_]u32{@intCast(llvm_ret_i)}, "")
            else
                call;

            if (output != .none) {
                const output_ptr = try self.resolveInst(output);
                const output_ptr_ty = self.typeOf(output);
                const alignment = output_ptr_ty.ptrAlignment(zcu).toLlvm();
                _ = try self.wip.store(
                    if (output_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal,
                    output_value,
                    output_ptr,
                    alignment,
                );
            } else {
                ret_val = output_value;
            }
            llvm_ret_i += 1;
        }

        return ret_val;
    }

    fn airIsNonNull(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
        cond: Builder.IntegerCondition,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);
        const optional_ty = if (operand_is_ptr) operand_ty.childType(zcu) else operand_ty;
        const optional_llvm_ty = try o.lowerType(pt, optional_ty);
        const payload_ty = optional_ty.optionalChild(zcu);

        const access_kind: Builder.MemoryAccessKind =
            if (operand_is_ptr and operand_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        if (operand_is_ptr) self.maybeMarkAllowZeroAccess(operand_ty.ptrInfo(zcu));

        if (optional_ty.optionalReprIsPayload(zcu)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(access_kind, optional_llvm_ty, operand, .default, "")
            else
                operand;
            if (payload_ty.isSlice(zcu)) {
                const slice_ptr = try self.wip.extractValue(loaded, &.{0}, "");
                const ptr_ty = try o.builder.ptrType(toLlvmAddressSpace(
                    payload_ty.ptrAddressSpace(zcu),
                    zcu.getTarget(),
                ));
                return self.wip.icmp(cond, slice_ptr, try o.builder.nullValue(ptr_ty), "");
            }
            return self.wip.icmp(cond, loaded, try o.builder.zeroInitValue(optional_llvm_ty), "");
        }

        comptime assert(optional_layout_version == 3);

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(access_kind, optional_llvm_ty, operand, .default, "")
            else
                operand;
            return self.wip.icmp(cond, loaded, try o.builder.intValue(.i8, 0), "");
        }

        const is_by_ref = operand_is_ptr or isByRef(optional_ty, zcu);
        return self.optCmpNull(cond, optional_llvm_ty, operand, is_by_ref, access_kind);
    }

    fn airIsErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        cond: Builder.IntegerCondition,
        operand_is_ptr: bool,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(zcu) else operand_ty;
        const payload_ty = err_union_ty.errorUnionPayload(zcu);
        const error_type = try o.errorIntType(pt);
        const zero = try o.builder.intValue(error_type, 0);

        const access_kind: Builder.MemoryAccessKind =
            if (operand_is_ptr and operand_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        if (err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
            const val: Builder.Constant = switch (cond) {
                .eq => .true, // 0 == 0
                .ne => .false, // 0 != 0
                else => unreachable,
            };
            return val.toValue();
        }

        if (operand_is_ptr) self.maybeMarkAllowZeroAccess(operand_ty.ptrInfo(zcu));

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            const loaded = if (operand_is_ptr)
                try self.wip.load(access_kind, try o.lowerType(pt, err_union_ty), operand, .default, "")
            else
                operand;
            return self.wip.icmp(cond, loaded, zero, "");
        }

        const err_field_index = try errUnionErrorOffset(payload_ty, pt);

        const loaded = if (operand_is_ptr or isByRef(err_union_ty, zcu)) loaded: {
            const err_union_llvm_ty = try o.lowerType(pt, err_union_ty);
            const err_field_ptr =
                try self.wip.gepStruct(err_union_llvm_ty, operand, err_field_index, "");
            break :loaded try self.wip.load(access_kind, error_type, err_field_ptr, .default, "");
        } else try self.wip.extractValue(operand, &.{err_field_index}, "");
        return self.wip.icmp(cond, loaded, zero, "");
    }

    fn airOptionalPayloadPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand).childType(zcu);
        const payload_ty = optional_ty.optionalChild(zcu);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            // We have a pointer to a zero-bit value and we need to return
            // a pointer to a zero-bit value.
            return operand;
        }
        if (optional_ty.optionalReprIsPayload(zcu)) {
            // The payload and the optional are the same value.
            return operand;
        }
        return self.wip.gepStruct(try o.lowerType(pt, optional_ty), operand, 0, "");
    }

    fn airOptionalPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        comptime assert(optional_layout_version == 3);

        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ptr_ty = self.typeOf(ty_op.operand);
        const optional_ty = optional_ptr_ty.childType(zcu);
        const payload_ty = optional_ty.optionalChild(zcu);
        const non_null_bit = try o.builder.intValue(.i8, 1);

        const access_kind: Builder.MemoryAccessKind =
            if (optional_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            self.maybeMarkAllowZeroAccess(optional_ptr_ty.ptrInfo(zcu));

            // We have a pointer to a i8. We need to set it to 1 and then return the same pointer.
            _ = try self.wip.store(access_kind, non_null_bit, operand, .default);
            return operand;
        }
        if (optional_ty.optionalReprIsPayload(zcu)) {
            // The payload and the optional are the same value.
            // Setting to non-null will be done when the payload is set.
            return operand;
        }

        // First set the non-null bit.
        const optional_llvm_ty = try o.lowerType(pt, optional_ty);
        const non_null_ptr = try self.wip.gepStruct(optional_llvm_ty, operand, 1, "");

        self.maybeMarkAllowZeroAccess(optional_ptr_ty.ptrInfo(zcu));

        // TODO set alignment on this store
        _ = try self.wip.store(access_kind, non_null_bit, non_null_ptr, .default);

        // Then return the payload pointer (only if it's used).
        if (self.liveness.isUnused(inst)) return .none;

        return self.wip.gepStruct(optional_llvm_ty, operand, 0, "");
    }

    fn airOptionalPayload(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOf(ty_op.operand);
        const payload_ty = self.typeOfIndex(inst);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

        if (optional_ty.optionalReprIsPayload(zcu)) {
            // Payload value is the same as the optional value.
            return operand;
        }

        const opt_llvm_ty = try o.lowerType(pt, optional_ty);
        return self.optPayloadHandle(opt_llvm_ty, operand, optional_ty, false);
    }

    fn airErrUnionPayload(self: *FuncGen, inst: Air.Inst.Index, operand_is_ptr: bool) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(zcu) else operand_ty;
        const result_ty = self.typeOfIndex(inst);
        const payload_ty = if (operand_is_ptr) result_ty.childType(zcu) else result_ty;

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            return if (operand_is_ptr) operand else .none;
        }
        const offset = try errUnionPayloadOffset(payload_ty, pt);
        const err_union_llvm_ty = try o.lowerType(pt, err_union_ty);
        if (operand_is_ptr) {
            return self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
        } else if (isByRef(err_union_ty, zcu)) {
            const payload_alignment = payload_ty.abiAlignment(zcu).toLlvm();
            const payload_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
            if (isByRef(payload_ty, zcu)) {
                return self.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            const payload_llvm_ty = err_union_llvm_ty.structFields(&o.builder)[offset];
            return self.wip.load(.normal, payload_llvm_ty, payload_ptr, payload_alignment, "");
        }
        return self.wip.extractValue(operand, &.{offset}, "");
    }

    fn airErrUnionErr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        operand_is_ptr: bool,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const error_type = try o.errorIntType(pt);
        const err_union_ty = if (operand_is_ptr) operand_ty.childType(zcu) else operand_ty;
        if (err_union_ty.errorUnionSet(zcu).errorSetIsEmpty(zcu)) {
            if (operand_is_ptr) {
                return operand;
            } else {
                return o.builder.intValue(error_type, 0);
            }
        }

        const access_kind: Builder.MemoryAccessKind =
            if (operand_is_ptr and operand_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        const payload_ty = err_union_ty.errorUnionPayload(zcu);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            if (!operand_is_ptr) return operand;

            self.maybeMarkAllowZeroAccess(operand_ty.ptrInfo(zcu));

            return self.wip.load(access_kind, error_type, operand, .default, "");
        }

        const offset = try errUnionErrorOffset(payload_ty, pt);

        if (operand_is_ptr or isByRef(err_union_ty, zcu)) {
            if (operand_is_ptr) self.maybeMarkAllowZeroAccess(operand_ty.ptrInfo(zcu));

            const err_union_llvm_ty = try o.lowerType(pt, err_union_ty);
            const err_field_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, offset, "");
            return self.wip.load(access_kind, error_type, err_field_ptr, .default, "");
        }

        return self.wip.extractValue(operand, &.{offset}, "");
    }

    fn airErrUnionPayloadPtrSet(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const err_union_ptr_ty = self.typeOf(ty_op.operand);
        const err_union_ty = err_union_ptr_ty.childType(zcu);

        const payload_ty = err_union_ty.errorUnionPayload(zcu);
        const non_error_val = try o.builder.intValue(try o.errorIntType(pt), 0);

        const access_kind: Builder.MemoryAccessKind =
            if (err_union_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            self.maybeMarkAllowZeroAccess(err_union_ptr_ty.ptrInfo(zcu));

            _ = try self.wip.store(access_kind, non_error_val, operand, .default);
            return operand;
        }
        const err_union_llvm_ty = try o.lowerType(pt, err_union_ty);
        {
            self.maybeMarkAllowZeroAccess(err_union_ptr_ty.ptrInfo(zcu));

            const err_int_ty = try pt.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(zcu).toLlvm();
            const error_offset = try errUnionErrorOffset(payload_ty, pt);
            // First set the non-error value.
            const non_null_ptr = try self.wip.gepStruct(err_union_llvm_ty, operand, error_offset, "");
            _ = try self.wip.store(access_kind, non_error_val, non_null_ptr, error_alignment);
        }
        // Then return the payload pointer (only if it is used).
        if (self.liveness.isUnused(inst)) return .none;

        const payload_offset = try errUnionPayloadOffset(payload_ty, pt);
        return self.wip.gepStruct(err_union_llvm_ty, operand, payload_offset, "");
    }

    fn airErrReturnTrace(self: *FuncGen, _: Air.Inst.Index) !Builder.Value {
        assert(self.err_ret_trace != .none);
        return self.err_ret_trace;
    }

    fn airSetErrReturnTrace(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        self.err_ret_trace = try self.resolveInst(un_op);
        return .none;
    }

    fn airSaveErrReturnTraceIndex(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;

        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const struct_ty = ty_pl.ty.toType();
        const field_index = ty_pl.payload;

        const struct_llvm_ty = try o.lowerType(pt, struct_ty);
        const llvm_field_index = o.llvmFieldIndex(struct_ty, field_index).?;
        assert(self.err_ret_trace != .none);
        const field_ptr =
            try self.wip.gepStruct(struct_llvm_ty, self.err_ret_trace, llvm_field_index, "");
        const field_alignment = struct_ty.fieldAlignment(field_index, zcu);
        const field_ty = struct_ty.fieldType(field_index, zcu);
        const field_ptr_ty = try pt.ptrType(.{
            .child = field_ty.toIntern(),
            .flags = .{ .alignment = field_alignment },
        });
        return self.load(field_ptr, field_ptr_ty);
    }

    /// As an optimization, we want to avoid unnecessary copies of
    /// error union/optional types when returning from a function.
    /// Here, we scan forward in the current block, looking to see
    /// if the next instruction is a return (ignoring debug instructions).
    ///
    /// The first instruction of `body_tail` is a wrap instruction.
    fn isNextRet(
        self: *FuncGen,
        body_tail: []const Air.Inst.Index,
    ) bool {
        const air_tags = self.air.instructions.items(.tag);
        for (body_tail[1..]) |body_inst| {
            switch (air_tags[@intFromEnum(body_inst)]) {
                .ret => return true,
                .dbg_stmt => continue,
                else => return false,
            }
        }
        // The only way to get here is to hit the end of a loop instruction
        // (implicit repeat).
        return false;
    }

    fn airWrapOptional(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const payload_ty = self.typeOf(ty_op.operand);
        const non_null_bit = try o.builder.intValue(.i8, 1);
        comptime assert(optional_layout_version == 3);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return non_null_bit;
        const operand = try self.resolveInst(ty_op.operand);
        const optional_ty = self.typeOfIndex(inst);
        if (optional_ty.optionalReprIsPayload(zcu)) return operand;
        const llvm_optional_ty = try o.lowerType(pt, optional_ty);
        if (isByRef(optional_ty, zcu)) {
            const directReturn = self.isNextRet(body_tail);
            const optional_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = optional_ty.abiAlignment(zcu).toLlvm();
                const optional_ptr = try self.buildAlloca(llvm_optional_ty, alignment);
                break :brk optional_ptr;
            };

            const payload_ptr = try self.wip.gepStruct(llvm_optional_ty, optional_ptr, 0, "");
            const payload_ptr_ty = try pt.singleMutPtrType(payload_ty);
            try self.store(payload_ptr, payload_ptr_ty, operand, .none);
            const non_null_ptr = try self.wip.gepStruct(llvm_optional_ty, optional_ptr, 1, "");
            _ = try self.wip.store(.normal, non_null_bit, non_null_ptr, .default);
            return optional_ptr;
        }
        return self.wip.buildAggregate(llvm_optional_ty, &.{ operand, non_null_bit }, "");
    }

    fn airWrapErrUnionPayload(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_un_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);
        const payload_ty = self.typeOf(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            return operand;
        }
        const ok_err_code = try o.builder.intValue(try o.errorIntType(pt), 0);
        const err_un_llvm_ty = try o.lowerType(pt, err_un_ty);

        const payload_offset = try errUnionPayloadOffset(payload_ty, pt);
        const error_offset = try errUnionErrorOffset(payload_ty, pt);
        if (isByRef(err_un_ty, zcu)) {
            const directReturn = self.isNextRet(body_tail);
            const result_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = err_un_ty.abiAlignment(pt.zcu).toLlvm();
                const result_ptr = try self.buildAlloca(err_un_llvm_ty, alignment);
                break :brk result_ptr;
            };

            const err_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, error_offset, "");
            const err_int_ty = try pt.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(pt.zcu).toLlvm();
            _ = try self.wip.store(.normal, ok_err_code, err_ptr, error_alignment);
            const payload_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, payload_offset, "");
            const payload_ptr_ty = try pt.singleMutPtrType(payload_ty);
            try self.store(payload_ptr, payload_ptr_ty, operand, .none);
            return result_ptr;
        }
        var fields: [2]Builder.Value = undefined;
        fields[payload_offset] = operand;
        fields[error_offset] = ok_err_code;
        return self.wip.buildAggregate(err_un_llvm_ty, &fields, "");
    }

    fn airWrapErrUnionErr(self: *FuncGen, body_tail: []const Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const inst = body_tail[0];
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const err_un_ty = self.typeOfIndex(inst);
        const payload_ty = err_un_ty.errorUnionPayload(zcu);
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return operand;
        const err_un_llvm_ty = try o.lowerType(pt, err_un_ty);

        const payload_offset = try errUnionPayloadOffset(payload_ty, pt);
        const error_offset = try errUnionErrorOffset(payload_ty, pt);
        if (isByRef(err_un_ty, zcu)) {
            const directReturn = self.isNextRet(body_tail);
            const result_ptr = if (directReturn)
                self.ret_ptr
            else brk: {
                const alignment = err_un_ty.abiAlignment(zcu).toLlvm();
                const result_ptr = try self.buildAlloca(err_un_llvm_ty, alignment);
                break :brk result_ptr;
            };

            const err_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, error_offset, "");
            const err_int_ty = try pt.errorIntType();
            const error_alignment = err_int_ty.abiAlignment(zcu).toLlvm();
            _ = try self.wip.store(.normal, operand, err_ptr, error_alignment);
            const payload_ptr = try self.wip.gepStruct(err_un_llvm_ty, result_ptr, payload_offset, "");
            const payload_ptr_ty = try pt.singleMutPtrType(payload_ty);
            // TODO store undef to payload_ptr
            _ = payload_ptr;
            _ = payload_ptr_ty;
            return result_ptr;
        }

        // TODO set payload bytes to undef
        const undef = try o.builder.undefValue(err_un_llvm_ty);
        return self.wip.insertValue(undef, operand, &.{error_offset}, "");
    }

    fn airWasmMemorySize(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const index = pl_op.payload;
        const llvm_usize = try o.lowerType(pt, Type.usize);
        return self.wip.callIntrinsic(.normal, .none, .@"wasm.memory.size", &.{llvm_usize}, &.{
            try o.builder.intValue(.i32, index),
        }, "");
    }

    fn airWasmMemoryGrow(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const index = pl_op.payload;
        const llvm_isize = try o.lowerType(pt, Type.isize);
        return self.wip.callIntrinsic(.normal, .none, .@"wasm.memory.grow", &.{llvm_isize}, &.{
            try o.builder.intValue(.i32, index), try self.resolveInst(pl_op.operand),
        }, "");
    }

    fn airVectorStoreElem(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const data = self.air.instructions.items(.data)[@intFromEnum(inst)].vector_store_elem;
        const extra = self.air.extraData(Air.Bin, data.payload).data;

        const vector_ptr = try self.resolveInst(data.vector_ptr);
        const vector_ptr_ty = self.typeOf(data.vector_ptr);
        const index = try self.resolveInst(extra.lhs);
        const operand = try self.resolveInst(extra.rhs);

        self.maybeMarkAllowZeroAccess(vector_ptr_ty.ptrInfo(zcu));

        // TODO: Emitting a load here is a violation of volatile semantics. Not fixable in general.
        // https://github.com/ziglang/zig/issues/18652#issuecomment-2452844908
        const access_kind: Builder.MemoryAccessKind =
            if (vector_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;
        const elem_llvm_ty = try o.lowerType(pt, vector_ptr_ty.childType(zcu));
        const alignment = vector_ptr_ty.ptrAlignment(zcu).toLlvm();
        const loaded = try self.wip.load(access_kind, elem_llvm_ty, vector_ptr, alignment, "");

        const new_vector = try self.wip.insertElement(loaded, operand, index, "");
        _ = try self.store(vector_ptr, vector_ptr_ty, new_vector, .none);
        return .none;
    }

    fn airRuntimeNavPtr(fg: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const ty_nav = fg.air.instructions.items(.data)[@intFromEnum(inst)].ty_nav;
        const llvm_ptr_const = try o.lowerNavRefValue(pt, ty_nav.nav);
        return llvm_ptr_const.toValue();
    }

    fn airMin(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.fmin, .normal, inst_ty, 2, .{ lhs, rhs });
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(zcu)) .smin else .umin,
            &.{try o.lowerType(pt, inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airMax(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.fmax, .normal, inst_ty, 2, .{ lhs, rhs });
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(zcu)) .smax else .umax,
            &.{try o.lowerType(pt, inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airSlice(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        return self.wip.buildAggregate(try o.lowerType(pt, inst_ty), &.{ ptr, len }, "");
    }

    fn airAdd(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.add, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(zcu)) .@"add nsw" else .@"add nuw", lhs, rhs, "");
    }

    fn airSafeArithmetic(
        fg: *FuncGen,
        inst: Air.Inst.Index,
        signed_intrinsic: Builder.Intrinsic,
        unsigned_intrinsic: Builder.Intrinsic,
    ) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;

        const bin_op = fg.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try fg.resolveInst(bin_op.lhs);
        const rhs = try fg.resolveInst(bin_op.rhs);
        const inst_ty = fg.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        const intrinsic = if (scalar_ty.isSignedInt(zcu)) signed_intrinsic else unsigned_intrinsic;
        const llvm_inst_ty = try o.lowerType(pt, inst_ty);
        const results =
            try fg.wip.callIntrinsic(.normal, .none, intrinsic, &.{llvm_inst_ty}, &.{ lhs, rhs }, "");

        const overflow_bits = try fg.wip.extractValue(results, &.{1}, "");
        const overflow_bits_ty = overflow_bits.typeOfWip(&fg.wip);
        const overflow_bit = if (overflow_bits_ty.isVector(&o.builder))
            try fg.wip.callIntrinsic(
                .normal,
                .none,
                .@"vector.reduce.or",
                &.{overflow_bits_ty},
                &.{overflow_bits},
                "",
            )
        else
            overflow_bits;

        const fail_block = try fg.wip.block(1, "OverflowFail");
        const ok_block = try fg.wip.block(1, "OverflowOk");
        _ = try fg.wip.brCond(overflow_bit, fail_block, ok_block, .none);

        fg.wip.cursor = .{ .block = fail_block };
        try fg.buildSimplePanic(.integer_overflow);

        fg.wip.cursor = .{ .block = ok_block };
        return fg.wip.extractValue(results, &.{0}, "");
    }

    fn airAddWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.add, lhs, rhs, "");
    }

    fn airAddSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float add", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(zcu)) .@"sadd.sat" else .@"uadd.sat",
            &.{try o.lowerType(pt, inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airSub(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.sub, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(zcu)) .@"sub nsw" else .@"sub nuw", lhs, rhs, "");
    }

    fn airSubWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.sub, lhs, rhs, "");
    }

    fn airSubSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float sub", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(zcu)) .@"ssub.sat" else .@"usub.sat",
            &.{try o.lowerType(pt, inst_ty)},
            &.{ lhs, rhs },
            "",
        );
    }

    fn airMul(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.buildFloatOp(.mul, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(zcu)) .@"mul nsw" else .@"mul nuw", lhs, rhs, "");
    }

    fn airMulWrap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        return self.wip.bin(.mul, lhs, rhs, "");
    }

    fn airMulSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isAnyFloat()) return self.todo("saturating float mul", .{});
        return self.wip.callIntrinsic(
            .normal,
            .none,
            if (scalar_ty.isSignedInt(zcu)) .@"smul.fix.sat" else .@"umul.fix.sat",
            &.{try o.lowerType(pt, inst_ty)},
            &.{ lhs, rhs, .@"0" },
            "",
        );
    }

    fn airDivFloat(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);

        return self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
    }

    fn airDivTrunc(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isRuntimeFloat()) {
            const result = try self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
            return self.buildFloatOp(.trunc, fast, inst_ty, 1, .{result});
        }
        return self.wip.bin(if (scalar_ty.isSignedInt(zcu)) .sdiv else .udiv, lhs, rhs, "");
    }

    fn airDivFloor(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isRuntimeFloat()) {
            const result = try self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
            return self.buildFloatOp(.floor, fast, inst_ty, 1, .{result});
        }
        if (scalar_ty.isSignedInt(zcu)) {
            const inst_llvm_ty = try o.lowerType(pt, inst_ty);

            const ExpectedContents = [std.math.big.int.calcTwosCompLimbCount(256)]std.math.big.Limb;
            var stack align(@max(
                @alignOf(std.heap.StackFallbackAllocator(0)),
                @alignOf(ExpectedContents),
            )) = std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
            const allocator = stack.get();

            const scalar_bits = inst_llvm_ty.scalarBits(&o.builder);
            var smin_big_int: std.math.big.int.Mutable = .{
                .limbs = try allocator.alloc(
                    std.math.big.Limb,
                    std.math.big.int.calcTwosCompLimbCount(scalar_bits),
                ),
                .len = undefined,
                .positive = undefined,
            };
            defer allocator.free(smin_big_int.limbs);
            smin_big_int.setTwosCompIntLimit(.min, .signed, scalar_bits);
            const smin = try o.builder.splatValue(inst_llvm_ty, try o.builder.bigIntConst(
                inst_llvm_ty.scalarType(&o.builder),
                smin_big_int.toConst(),
            ));

            const div = try self.wip.bin(.sdiv, lhs, rhs, "divFloor.div");
            const rem = try self.wip.bin(.srem, lhs, rhs, "divFloor.rem");
            const rhs_sign = try self.wip.bin(.@"and", rhs, smin, "divFloor.rhs_sign");
            const rem_xor_rhs_sign = try self.wip.bin(.xor, rem, rhs_sign, "divFloor.rem_xor_rhs_sign");
            const need_correction = try self.wip.icmp(.ugt, rem_xor_rhs_sign, smin, "divFloor.need_correction");
            const correction = try self.wip.cast(.sext, need_correction, inst_llvm_ty, "divFloor.correction");
            return self.wip.bin(.@"add nsw", div, correction, "divFloor");
        }
        return self.wip.bin(.udiv, lhs, rhs, "");
    }

    fn airDivExact(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isRuntimeFloat()) return self.buildFloatOp(.div, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(
            if (scalar_ty.isSignedInt(zcu)) .@"sdiv exact" else .@"udiv exact",
            lhs,
            rhs,
            "",
        );
    }

    fn airRem(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const zcu = self.ng.pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isRuntimeFloat())
            return self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ lhs, rhs });
        return self.wip.bin(if (scalar_ty.isSignedInt(zcu))
            .srem
        else
            .urem, lhs, rhs, "");
    }

    fn airMod(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const inst_ty = self.typeOfIndex(inst);
        const inst_llvm_ty = try o.lowerType(pt, inst_ty);
        const scalar_ty = inst_ty.scalarType(zcu);

        if (scalar_ty.isRuntimeFloat()) {
            const a = try self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ lhs, rhs });
            const b = try self.buildFloatOp(.add, fast, inst_ty, 2, .{ a, rhs });
            const c = try self.buildFloatOp(.fmod, fast, inst_ty, 2, .{ b, rhs });
            const zero = try o.builder.zeroInitValue(inst_llvm_ty);
            const ltz = try self.buildFloatCmp(fast, .lt, inst_ty, .{ lhs, zero });
            return self.wip.select(fast, ltz, c, a, "");
        }
        if (scalar_ty.isSignedInt(zcu)) {
            const ExpectedContents = [std.math.big.int.calcTwosCompLimbCount(256)]std.math.big.Limb;
            var stack align(@max(
                @alignOf(std.heap.StackFallbackAllocator(0)),
                @alignOf(ExpectedContents),
            )) = std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
            const allocator = stack.get();

            const scalar_bits = inst_llvm_ty.scalarBits(&o.builder);
            var smin_big_int: std.math.big.int.Mutable = .{
                .limbs = try allocator.alloc(
                    std.math.big.Limb,
                    std.math.big.int.calcTwosCompLimbCount(scalar_bits),
                ),
                .len = undefined,
                .positive = undefined,
            };
            defer allocator.free(smin_big_int.limbs);
            smin_big_int.setTwosCompIntLimit(.min, .signed, scalar_bits);
            const smin = try o.builder.splatValue(inst_llvm_ty, try o.builder.bigIntConst(
                inst_llvm_ty.scalarType(&o.builder),
                smin_big_int.toConst(),
            ));

            const rem = try self.wip.bin(.srem, lhs, rhs, "mod.rem");
            const rhs_sign = try self.wip.bin(.@"and", rhs, smin, "mod.rhs_sign");
            const rem_xor_rhs_sign = try self.wip.bin(.xor, rem, rhs_sign, "mod.rem_xor_rhs_sign");
            const need_correction = try self.wip.icmp(.ugt, rem_xor_rhs_sign, smin, "mod.need_correction");
            const zero = try o.builder.zeroInitValue(inst_llvm_ty);
            const correction = try self.wip.select(.normal, need_correction, rhs, zero, "mod.correction");
            return self.wip.bin(.@"add nsw", correction, rem, "mod");
        }
        return self.wip.bin(.urem, lhs, rhs, "");
    }

    fn airPtrAdd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(pt, ptr_ty.childType(zcu));
        switch (ptr_ty.ptrSize(zcu)) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            .one => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{
                try o.builder.intValue(try o.lowerType(pt, Type.usize), 0), offset,
            }, ""),
            .c, .many => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{offset}, ""),
            .slice => {
                const base = try self.wip.extractValue(ptr, &.{0}, "");
                return self.wip.gep(.inbounds, llvm_elem_ty, base, &.{offset}, "");
            },
        }
    }

    fn airPtrSub(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
        const ptr = try self.resolveInst(bin_op.lhs);
        const offset = try self.resolveInst(bin_op.rhs);
        const negative_offset = try self.wip.neg(offset, "");
        const ptr_ty = self.typeOf(bin_op.lhs);
        const llvm_elem_ty = try o.lowerPtrElemTy(pt, ptr_ty.childType(zcu));
        switch (ptr_ty.ptrSize(zcu)) {
            // It's a pointer to an array, so according to LLVM we need an extra GEP index.
            .one => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{
                try o.builder.intValue(try o.lowerType(pt, Type.usize), 0), negative_offset,
            }, ""),
            .c, .many => return self.wip.gep(.inbounds, llvm_elem_ty, ptr, &.{negative_offset}, ""),
            .slice => {
                const base = try self.wip.extractValue(ptr, &.{0}, "");
                return self.wip.gep(.inbounds, llvm_elem_ty, base, &.{negative_offset}, "");
            },
        }
    }

    fn airOverflow(
        self: *FuncGen,
        inst: Air.Inst.Index,
        signed_intrinsic: Builder.Intrinsic,
        unsigned_intrinsic: Builder.Intrinsic,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.typeOf(extra.lhs);
        const scalar_ty = lhs_ty.scalarType(zcu);
        const inst_ty = self.typeOfIndex(inst);

        const intrinsic = if (scalar_ty.isSignedInt(zcu)) signed_intrinsic else unsigned_intrinsic;
        const llvm_inst_ty = try o.lowerType(pt, inst_ty);
        const llvm_lhs_ty = try o.lowerType(pt, lhs_ty);
        const results =
            try self.wip.callIntrinsic(.normal, .none, intrinsic, &.{llvm_lhs_ty}, &.{ lhs, rhs }, "");

        const result_val = try self.wip.extractValue(results, &.{0}, "");
        const overflow_bit = try self.wip.extractValue(results, &.{1}, "");

        const result_index = o.llvmFieldIndex(inst_ty, 0).?;
        const overflow_index = o.llvmFieldIndex(inst_ty, 1).?;

        if (isByRef(inst_ty, zcu)) {
            const result_alignment = inst_ty.abiAlignment(zcu).toLlvm();
            const alloca_inst = try self.buildAlloca(llvm_inst_ty, result_alignment);
            {
                const field_ptr = try self.wip.gepStruct(llvm_inst_ty, alloca_inst, result_index, "");
                _ = try self.wip.store(.normal, result_val, field_ptr, result_alignment);
            }
            {
                const overflow_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(llvm_inst_ty, alloca_inst, overflow_index, "");
                _ = try self.wip.store(.normal, overflow_bit, field_ptr, overflow_alignment);
            }

            return alloca_inst;
        }

        var fields: [2]Builder.Value = undefined;
        fields[result_index] = result_val;
        fields[overflow_index] = overflow_bit;
        return self.wip.buildAggregate(llvm_inst_ty, &fields, "");
    }

    fn buildElementwiseCall(
        self: *FuncGen,
        llvm_fn: Builder.Function.Index,
        args_vectors: []const Builder.Value,
        result_vector: Builder.Value,
        vector_len: usize,
    ) !Builder.Value {
        const o = self.ng.object;
        assert(args_vectors.len <= 3);

        var i: usize = 0;
        var result = result_vector;
        while (i < vector_len) : (i += 1) {
            const index_i32 = try o.builder.intValue(.i32, i);

            var args: [3]Builder.Value = undefined;
            for (args[0..args_vectors.len], args_vectors) |*arg_elem, arg_vector| {
                arg_elem.* = try self.wip.extractElement(arg_vector, index_i32, "");
            }
            const result_elem = try self.wip.call(
                .normal,
                .ccc,
                .none,
                llvm_fn.typeOf(&o.builder),
                llvm_fn.toValue(&o.builder),
                args[0..args_vectors.len],
                "",
            );
            result = try self.wip.insertElement(result, result_elem, index_i32, "");
        }
        return result;
    }

    fn getLibcFunction(
        self: *FuncGen,
        fn_name: Builder.StrtabString,
        param_types: []const Builder.Type,
        return_type: Builder.Type,
    ) Allocator.Error!Builder.Function.Index {
        const o = self.ng.object;
        if (o.builder.getGlobal(fn_name)) |global| return switch (global.ptrConst(&o.builder).kind) {
            .alias => |alias| alias.getAliasee(&o.builder).ptrConst(&o.builder).kind.function,
            .function => |function| function,
            .variable, .replaced => unreachable,
        };
        return o.builder.addFunction(
            try o.builder.fnType(return_type, param_types, .normal),
            fn_name,
            toLlvmAddressSpace(.generic, self.ng.pt.zcu.getTarget()),
        );
    }

    /// Creates a floating point comparison by lowering to the appropriate
    /// hardware instruction or softfloat routine for the target
    fn buildFloatCmp(
        self: *FuncGen,
        fast: Builder.FastMathKind,
        pred: math.CompareOperator,
        ty: Type,
        params: [2]Builder.Value,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        const scalar_ty = ty.scalarType(zcu);
        const scalar_llvm_ty = try o.lowerType(pt, scalar_ty);

        if (intrinsicsAllowed(scalar_ty, target)) {
            const cond: Builder.FloatCondition = switch (pred) {
                .eq => .oeq,
                .neq => .une,
                .lt => .olt,
                .lte => .ole,
                .gt => .ogt,
                .gte => .oge,
            };
            return self.wip.fcmp(fast, cond, params[0], params[1], "");
        }

        const float_bits = scalar_ty.floatBits(target);
        const compiler_rt_float_abbrev = compilerRtFloatAbbrev(float_bits);
        const fn_base_name = switch (pred) {
            .neq => "ne",
            .eq => "eq",
            .lt => "lt",
            .lte => "le",
            .gt => "gt",
            .gte => "ge",
        };
        const fn_name = try o.builder.strtabStringFmt("__{s}{s}f2", .{ fn_base_name, compiler_rt_float_abbrev });

        const libc_fn = try self.getLibcFunction(fn_name, &.{ scalar_llvm_ty, scalar_llvm_ty }, .i32);

        const int_cond: Builder.IntegerCondition = switch (pred) {
            .eq => .eq,
            .neq => .ne,
            .lt => .slt,
            .lte => .sle,
            .gt => .sgt,
            .gte => .sge,
        };

        if (ty.zigTypeTag(zcu) == .vector) {
            const vec_len = ty.vectorLen(zcu);
            const vector_result_ty = try o.builder.vectorType(.normal, vec_len, .i32);

            const init = try o.builder.poisonValue(vector_result_ty);
            const result = try self.buildElementwiseCall(libc_fn, &params, init, vec_len);

            const zero_vector = try o.builder.splatValue(vector_result_ty, .@"0");
            return self.wip.icmp(int_cond, result, zero_vector, "");
        }

        const result = try self.wip.call(
            .normal,
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &params,
            "",
        );
        return self.wip.icmp(int_cond, result, .@"0", "");
    }

    const FloatOp = enum {
        add,
        ceil,
        cos,
        div,
        exp,
        exp2,
        fabs,
        floor,
        fma,
        fmax,
        fmin,
        fmod,
        log,
        log10,
        log2,
        mul,
        neg,
        round,
        sin,
        sqrt,
        sub,
        tan,
        trunc,
    };

    const FloatOpStrat = union(enum) {
        intrinsic: []const u8,
        libc: Builder.String,
    };

    /// Creates a floating point operation (add, sub, fma, sqrt, exp, etc.)
    /// by lowering to the appropriate hardware instruction or softfloat
    /// routine for the target
    fn buildFloatOp(
        self: *FuncGen,
        comptime op: FloatOp,
        fast: Builder.FastMathKind,
        ty: Type,
        comptime params_len: usize,
        params: [params_len]Builder.Value,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        const scalar_ty = ty.scalarType(zcu);
        const llvm_ty = try o.lowerType(pt, ty);

        if (op != .tan and intrinsicsAllowed(scalar_ty, target)) switch (op) {
            // Some operations are dedicated LLVM instructions, not available as intrinsics
            .neg => return self.wip.un(.fneg, params[0], ""),
            .add, .sub, .mul, .div, .fmod => return self.wip.bin(switch (fast) {
                .normal => switch (op) {
                    .add => .fadd,
                    .sub => .fsub,
                    .mul => .fmul,
                    .div => .fdiv,
                    .fmod => .frem,
                    else => unreachable,
                },
                .fast => switch (op) {
                    .add => .@"fadd fast",
                    .sub => .@"fsub fast",
                    .mul => .@"fmul fast",
                    .div => .@"fdiv fast",
                    .fmod => .@"frem fast",
                    else => unreachable,
                },
            }, params[0], params[1], ""),
            .fmax,
            .fmin,
            .ceil,
            .cos,
            .exp,
            .exp2,
            .fabs,
            .floor,
            .log,
            .log10,
            .log2,
            .round,
            .sin,
            .sqrt,
            .trunc,
            .fma,
            => return self.wip.callIntrinsic(fast, .none, switch (op) {
                .fmax => .maxnum,
                .fmin => .minnum,
                .ceil => .ceil,
                .cos => .cos,
                .exp => .exp,
                .exp2 => .exp2,
                .fabs => .fabs,
                .floor => .floor,
                .log => .log,
                .log10 => .log10,
                .log2 => .log2,
                .round => .round,
                .sin => .sin,
                .sqrt => .sqrt,
                .trunc => .trunc,
                .fma => .fma,
                else => unreachable,
            }, &.{llvm_ty}, &params, ""),
            .tan => unreachable,
        };

        const float_bits = scalar_ty.floatBits(target);
        const fn_name = switch (op) {
            .neg => {
                // In this case we can generate a softfloat negation by XORing the
                // bits with a constant.
                const int_ty = try o.builder.intType(@intCast(float_bits));
                const cast_ty = try llvm_ty.changeScalar(int_ty, &o.builder);
                const sign_mask = try o.builder.splatValue(
                    cast_ty,
                    try o.builder.intConst(int_ty, @as(u128, 1) << @intCast(float_bits - 1)),
                );
                const bitcasted_operand = try self.wip.cast(.bitcast, params[0], cast_ty, "");
                const result = try self.wip.bin(.xor, bitcasted_operand, sign_mask, "");
                return self.wip.cast(.bitcast, result, llvm_ty, "");
            },
            .add, .sub, .div, .mul => try o.builder.strtabStringFmt("__{s}{s}f3", .{
                @tagName(op), compilerRtFloatAbbrev(float_bits),
            }),
            .ceil,
            .cos,
            .exp,
            .exp2,
            .fabs,
            .floor,
            .fma,
            .fmax,
            .fmin,
            .fmod,
            .log,
            .log10,
            .log2,
            .round,
            .sin,
            .sqrt,
            .tan,
            .trunc,
            => try o.builder.strtabStringFmt("{s}{s}{s}", .{
                libcFloatPrefix(float_bits), @tagName(op), libcFloatSuffix(float_bits),
            }),
        };

        const scalar_llvm_ty = llvm_ty.scalarType(&o.builder);
        const libc_fn = try self.getLibcFunction(
            fn_name,
            ([1]Builder.Type{scalar_llvm_ty} ** 3)[0..params.len],
            scalar_llvm_ty,
        );
        if (ty.zigTypeTag(zcu) == .vector) {
            const result = try o.builder.poisonValue(llvm_ty);
            return self.buildElementwiseCall(libc_fn, &params, result, ty.vectorLen(zcu));
        }

        return self.wip.call(
            fast.toCallKind(),
            .ccc,
            .none,
            libc_fn.typeOf(&o.builder),
            libc_fn.toValue(&o.builder),
            &params,
            "",
        );
    }

    fn airMulAdd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

        const mulend1 = try self.resolveInst(extra.lhs);
        const mulend2 = try self.resolveInst(extra.rhs);
        const addend = try self.resolveInst(pl_op.operand);

        const ty = self.typeOfIndex(inst);
        return self.buildFloatOp(.fma, .normal, ty, 3, .{ mulend1, mulend2, addend });
    }

    fn airShlWithOverflow(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);

        const lhs_ty = self.typeOf(extra.lhs);
        if (lhs_ty.isVector(zcu) and !self.typeOf(extra.rhs).isVector(zcu))
            return self.ng.todo("implement vector shifts with scalar rhs", .{});
        const lhs_scalar_ty = lhs_ty.scalarType(zcu);

        const dest_ty = self.typeOfIndex(inst);
        const llvm_dest_ty = try o.lowerType(pt, dest_ty);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(pt, lhs_ty), "");

        const result = try self.wip.bin(.shl, lhs, casted_rhs, "");
        const reconstructed = try self.wip.bin(if (lhs_scalar_ty.isSignedInt(zcu))
            .ashr
        else
            .lshr, result, casted_rhs, "");

        const overflow_bit = try self.wip.icmp(.ne, lhs, reconstructed, "");

        const result_index = o.llvmFieldIndex(dest_ty, 0).?;
        const overflow_index = o.llvmFieldIndex(dest_ty, 1).?;

        if (isByRef(dest_ty, zcu)) {
            const result_alignment = dest_ty.abiAlignment(zcu).toLlvm();
            const alloca_inst = try self.buildAlloca(llvm_dest_ty, result_alignment);
            {
                const field_ptr = try self.wip.gepStruct(llvm_dest_ty, alloca_inst, result_index, "");
                _ = try self.wip.store(.normal, result, field_ptr, result_alignment);
            }
            {
                const field_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(llvm_dest_ty, alloca_inst, overflow_index, "");
                _ = try self.wip.store(.normal, overflow_bit, field_ptr, field_alignment);
            }
            return alloca_inst;
        }

        var fields: [2]Builder.Value = undefined;
        fields[result_index] = result;
        fields[overflow_index] = overflow_bit;
        return self.wip.buildAggregate(llvm_dest_ty, &fields, "");
    }

    fn airAnd(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.@"and", lhs, rhs, "");
    }

    fn airOr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.@"or", lhs, rhs, "");
    }

    fn airXor(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        return self.wip.bin(.xor, lhs, rhs, "");
    }

    fn airShlExact(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        if (lhs_ty.isVector(zcu) and !self.typeOf(bin_op.rhs).isVector(zcu))
            return self.ng.todo("implement vector shifts with scalar rhs", .{});
        const lhs_scalar_ty = lhs_ty.scalarType(zcu);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(pt, lhs_ty), "");
        return self.wip.bin(if (lhs_scalar_ty.isSignedInt(zcu))
            .@"shl nsw"
        else
            .@"shl nuw", lhs, casted_rhs, "");
    }

    fn airShl(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        if (lhs_ty.isVector(zcu) and !self.typeOf(bin_op.rhs).isVector(zcu))
            return self.ng.todo("implement vector shifts with scalar rhs", .{});

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(pt, lhs_ty), "");
        return self.wip.bin(.shl, lhs, casted_rhs, "");
    }

    fn airShlSat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        const lhs_info = lhs_ty.intInfo(zcu);
        const llvm_lhs_ty = try o.lowerType(pt, lhs_ty);
        const llvm_lhs_scalar_ty = llvm_lhs_ty.scalarType(&o.builder);

        const rhs_ty = self.typeOf(bin_op.rhs);
        if (lhs_ty.isVector(zcu) and !rhs_ty.isVector(zcu))
            return self.ng.todo("implement vector shifts with scalar rhs", .{});
        const rhs_info = rhs_ty.intInfo(zcu);
        assert(rhs_info.signedness == .unsigned);
        const llvm_rhs_ty = try o.lowerType(pt, rhs_ty);
        const llvm_rhs_scalar_ty = llvm_rhs_ty.scalarType(&o.builder);

        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            switch (lhs_info.signedness) {
                .signed => .@"sshl.sat",
                .unsigned => .@"ushl.sat",
            },
            &.{llvm_lhs_ty},
            &.{ lhs, try self.wip.conv(.unsigned, rhs, llvm_lhs_ty, "") },
            "",
        );

        // LLVM langref says "If b is (statically or dynamically) equal to or
        // larger than the integer bit width of the arguments, the result is a
        // poison value."
        // However Zig semantics says that saturating shift left can never produce
        // undefined; instead it saturates.
        if (rhs_info.bits <= math.log2_int(u16, lhs_info.bits)) return result;
        const bits = try o.builder.splatValue(
            llvm_rhs_ty,
            try o.builder.intConst(llvm_rhs_scalar_ty, lhs_info.bits),
        );
        const in_range = try self.wip.icmp(.ult, rhs, bits, "");
        const lhs_sat = lhs_sat: switch (lhs_info.signedness) {
            .signed => {
                const zero = try o.builder.splatValue(
                    llvm_lhs_ty,
                    try o.builder.intConst(llvm_lhs_scalar_ty, 0),
                );
                const smin = try o.builder.splatValue(
                    llvm_lhs_ty,
                    try minIntConst(&o.builder, lhs_ty, llvm_lhs_ty, zcu),
                );
                const smax = try o.builder.splatValue(
                    llvm_lhs_ty,
                    try maxIntConst(&o.builder, lhs_ty, llvm_lhs_ty, zcu),
                );
                const lhs_lt_zero = try self.wip.icmp(.slt, lhs, zero, "");
                const slimit = try self.wip.select(.normal, lhs_lt_zero, smin, smax, "");
                const lhs_eq_zero = try self.wip.icmp(.eq, lhs, zero, "");
                break :lhs_sat try self.wip.select(.normal, lhs_eq_zero, zero, slimit, "");
            },
            .unsigned => {
                const zero = try o.builder.splatValue(
                    llvm_lhs_ty,
                    try o.builder.intConst(llvm_lhs_scalar_ty, 0),
                );
                const umax = try o.builder.splatValue(
                    llvm_lhs_ty,
                    try o.builder.intConst(llvm_lhs_scalar_ty, -1),
                );
                const lhs_eq_zero = try self.wip.icmp(.eq, lhs, zero, "");
                break :lhs_sat try self.wip.select(.normal, lhs_eq_zero, zero, umax, "");
            },
        };
        return self.wip.select(.normal, in_range, result, lhs_sat, "");
    }

    fn airShr(self: *FuncGen, inst: Air.Inst.Index, is_exact: bool) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const lhs_ty = self.typeOf(bin_op.lhs);
        if (lhs_ty.isVector(zcu) and !self.typeOf(bin_op.rhs).isVector(zcu))
            return self.ng.todo("implement vector shifts with scalar rhs", .{});
        const lhs_scalar_ty = lhs_ty.scalarType(zcu);

        const casted_rhs = try self.wip.conv(.unsigned, rhs, try o.lowerType(pt, lhs_ty), "");
        const is_signed_int = lhs_scalar_ty.isSignedInt(zcu);

        return self.wip.bin(if (is_exact)
            if (is_signed_int) .@"ashr exact" else .@"lshr exact"
        else if (is_signed_int) .ashr else .lshr, lhs, casted_rhs, "");
    }

    fn airAbs(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const scalar_ty = operand_ty.scalarType(zcu);

        switch (scalar_ty.zigTypeTag(zcu)) {
            .int => return self.wip.callIntrinsic(
                .normal,
                .none,
                .abs,
                &.{try o.lowerType(pt, operand_ty)},
                &.{ operand, try o.builder.intValue(.i1, 0) },
                "",
            ),
            .float => return self.buildFloatOp(.fabs, .normal, operand_ty, 1, .{operand}),
            else => unreachable,
        }
    }

    fn airIntCast(fg: *FuncGen, inst: Air.Inst.Index, safety: bool) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const ty_op = fg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const dest_ty = fg.typeOfIndex(inst);
        const dest_llvm_ty = try o.lowerType(pt, dest_ty);
        const operand = try fg.resolveInst(ty_op.operand);
        const operand_ty = fg.typeOf(ty_op.operand);
        const operand_info = operand_ty.intInfo(zcu);

        const dest_is_enum = dest_ty.zigTypeTag(zcu) == .@"enum";

        bounds_check: {
            const dest_scalar = dest_ty.scalarType(zcu);
            const operand_scalar = operand_ty.scalarType(zcu);

            const dest_info = dest_ty.intInfo(zcu);

            const have_min_check, const have_max_check = c: {
                const dest_pos_bits = dest_info.bits - @intFromBool(dest_info.signedness == .signed);
                const operand_pos_bits = operand_info.bits - @intFromBool(operand_info.signedness == .signed);

                const dest_allows_neg = dest_info.signedness == .signed and dest_info.bits > 0;
                const operand_maybe_neg = operand_info.signedness == .signed and operand_info.bits > 0;

                break :c .{
                    operand_maybe_neg and (!dest_allows_neg or dest_info.bits < operand_info.bits),
                    dest_pos_bits < operand_pos_bits,
                };
            };

            if (!have_min_check and !have_max_check) break :bounds_check;

            const operand_llvm_ty = try o.lowerType(pt, operand_ty);
            const operand_scalar_llvm_ty = try o.lowerType(pt, operand_scalar);

            const is_vector = operand_ty.zigTypeTag(zcu) == .vector;
            assert(is_vector == (dest_ty.zigTypeTag(zcu) == .vector));

            const panic_id: Zcu.SimplePanicId = if (dest_is_enum) .invalid_enum_value else .integer_out_of_bounds;

            if (have_min_check) {
                const min_const_scalar = try minIntConst(&o.builder, dest_scalar, operand_scalar_llvm_ty, zcu);
                const min_val = if (is_vector) try o.builder.splatValue(operand_llvm_ty, min_const_scalar) else min_const_scalar.toValue();
                const ok_maybe_vec = try fg.cmp(.normal, .gte, operand_ty, operand, min_val);
                const ok = if (is_vector) ok: {
                    const vec_ty = ok_maybe_vec.typeOfWip(&fg.wip);
                    break :ok try fg.wip.callIntrinsic(.normal, .none, .@"vector.reduce.and", &.{vec_ty}, &.{ok_maybe_vec}, "");
                } else ok_maybe_vec;
                if (safety) {
                    const fail_block = try fg.wip.block(1, "IntMinFail");
                    const ok_block = try fg.wip.block(1, "IntMinOk");
                    _ = try fg.wip.brCond(ok, ok_block, fail_block, .none);
                    fg.wip.cursor = .{ .block = fail_block };
                    try fg.buildSimplePanic(panic_id);
                    fg.wip.cursor = .{ .block = ok_block };
                } else {
                    _ = try fg.wip.callIntrinsic(.normal, .none, .assume, &.{}, &.{ok}, "");
                }
            }

            if (have_max_check) {
                const max_const_scalar = try maxIntConst(&o.builder, dest_scalar, operand_scalar_llvm_ty, zcu);
                const max_val = if (is_vector) try o.builder.splatValue(operand_llvm_ty, max_const_scalar) else max_const_scalar.toValue();
                const ok_maybe_vec = try fg.cmp(.normal, .lte, operand_ty, operand, max_val);
                const ok = if (is_vector) ok: {
                    const vec_ty = ok_maybe_vec.typeOfWip(&fg.wip);
                    break :ok try fg.wip.callIntrinsic(.normal, .none, .@"vector.reduce.and", &.{vec_ty}, &.{ok_maybe_vec}, "");
                } else ok_maybe_vec;
                if (safety) {
                    const fail_block = try fg.wip.block(1, "IntMaxFail");
                    const ok_block = try fg.wip.block(1, "IntMaxOk");
                    _ = try fg.wip.brCond(ok, ok_block, fail_block, .none);
                    fg.wip.cursor = .{ .block = fail_block };
                    try fg.buildSimplePanic(panic_id);
                    fg.wip.cursor = .{ .block = ok_block };
                } else {
                    _ = try fg.wip.callIntrinsic(.normal, .none, .assume, &.{}, &.{ok}, "");
                }
            }
        }

        const result = try fg.wip.conv(switch (operand_info.signedness) {
            .signed => .signed,
            .unsigned => .unsigned,
        }, operand, dest_llvm_ty, "");

        if (safety and dest_is_enum and !dest_ty.isNonexhaustiveEnum(zcu)) {
            const llvm_fn = try fg.getIsNamedEnumValueFunction(dest_ty);
            const is_valid_enum_val = try fg.wip.call(
                .normal,
                .fastcc,
                .none,
                llvm_fn.typeOf(&o.builder),
                llvm_fn.toValue(&o.builder),
                &.{result},
                "",
            );
            const fail_block = try fg.wip.block(1, "ValidEnumFail");
            const ok_block = try fg.wip.block(1, "ValidEnumOk");
            _ = try fg.wip.brCond(is_valid_enum_val, ok_block, fail_block, .none);
            fg.wip.cursor = .{ .block = fail_block };
            try fg.buildSimplePanic(.invalid_enum_value);
            fg.wip.cursor = .{ .block = ok_block };
        }

        return result;
    }

    fn airTrunc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const dest_llvm_ty = try o.lowerType(pt, self.typeOfIndex(inst));
        return self.wip.cast(.trunc, operand, dest_llvm_ty, "");
    }

    fn airFptrunc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const target = zcu.getTarget();

        if (intrinsicsAllowed(dest_ty, target) and intrinsicsAllowed(operand_ty, target)) {
            return self.wip.cast(.fptrunc, operand, try o.lowerType(pt, dest_ty), "");
        } else {
            const operand_llvm_ty = try o.lowerType(pt, operand_ty);
            const dest_llvm_ty = try o.lowerType(pt, dest_ty);

            const dest_bits = dest_ty.floatBits(target);
            const src_bits = operand_ty.floatBits(target);
            const fn_name = try o.builder.strtabStringFmt("__trunc{s}f{s}f2", .{
                compilerRtFloatAbbrev(src_bits), compilerRtFloatAbbrev(dest_bits),
            });

            const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, dest_llvm_ty);
            return self.wip.call(
                .normal,
                .ccc,
                .none,
                libc_fn.typeOf(&o.builder),
                libc_fn.toValue(&o.builder),
                &.{operand},
                "",
            );
        }
    }

    fn airFpext(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        const dest_ty = self.typeOfIndex(inst);
        const target = zcu.getTarget();

        if (intrinsicsAllowed(dest_ty, target) and intrinsicsAllowed(operand_ty, target)) {
            return self.wip.cast(.fpext, operand, try o.lowerType(pt, dest_ty), "");
        } else {
            const operand_llvm_ty = try o.lowerType(pt, operand_ty);
            const dest_llvm_ty = try o.lowerType(pt, dest_ty);

            const dest_bits = dest_ty.scalarType(zcu).floatBits(target);
            const src_bits = operand_ty.scalarType(zcu).floatBits(target);
            const fn_name = try o.builder.strtabStringFmt("__extend{s}f{s}f2", .{
                compilerRtFloatAbbrev(src_bits), compilerRtFloatAbbrev(dest_bits),
            });

            const libc_fn = try self.getLibcFunction(fn_name, &.{operand_llvm_ty}, dest_llvm_ty);
            if (dest_ty.isVector(zcu)) return self.buildElementwiseCall(
                libc_fn,
                &.{operand},
                try o.builder.poisonValue(dest_llvm_ty),
                dest_ty.vectorLen(zcu),
            );
            return self.wip.call(
                .normal,
                .ccc,
                .none,
                libc_fn.typeOf(&o.builder),
                libc_fn.toValue(&o.builder),
                &.{operand},
                "",
            );
        }
    }

    fn airBitCast(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        const inst_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);
        return self.bitCast(operand, operand_ty, inst_ty);
    }

    fn bitCast(self: *FuncGen, operand: Builder.Value, operand_ty: Type, inst_ty: Type) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const operand_is_ref = isByRef(operand_ty, zcu);
        const result_is_ref = isByRef(inst_ty, zcu);
        const llvm_dest_ty = try o.lowerType(pt, inst_ty);

        if (operand_is_ref and result_is_ref) {
            // They are both pointers, so just return the same opaque pointer :)
            return operand;
        }

        if (llvm_dest_ty.isInteger(&o.builder) and
            operand.typeOfWip(&self.wip).isInteger(&o.builder))
        {
            return self.wip.conv(.unsigned, operand, llvm_dest_ty, "");
        }

        const operand_scalar_ty = operand_ty.scalarType(zcu);
        const inst_scalar_ty = inst_ty.scalarType(zcu);
        if (operand_scalar_ty.zigTypeTag(zcu) == .int and inst_scalar_ty.isPtrAtRuntime(zcu)) {
            return self.wip.cast(.inttoptr, operand, llvm_dest_ty, "");
        }
        if (operand_scalar_ty.isPtrAtRuntime(zcu) and inst_scalar_ty.zigTypeTag(zcu) == .int) {
            return self.wip.cast(.ptrtoint, operand, llvm_dest_ty, "");
        }

        if (operand_ty.zigTypeTag(zcu) == .vector and inst_ty.zigTypeTag(zcu) == .array) {
            const elem_ty = operand_ty.childType(zcu);
            if (!result_is_ref) {
                return self.ng.todo("implement bitcast vector to non-ref array", .{});
            }
            const alignment = inst_ty.abiAlignment(zcu).toLlvm();
            const array_ptr = try self.buildAlloca(llvm_dest_ty, alignment);
            const bitcast_ok = elem_ty.bitSize(zcu) == elem_ty.abiSize(zcu) * 8;
            if (bitcast_ok) {
                _ = try self.wip.store(.normal, operand, array_ptr, alignment);
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const llvm_usize = try o.lowerType(pt, Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const vector_len = operand_ty.arrayLen(zcu);
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_dest_ty, array_ptr, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const elem =
                        try self.wip.extractElement(operand, try o.builder.intValue(.i32, i), "");
                    _ = try self.wip.store(.normal, elem, elem_ptr, .default);
                }
            }
            return array_ptr;
        } else if (operand_ty.zigTypeTag(zcu) == .array and inst_ty.zigTypeTag(zcu) == .vector) {
            const elem_ty = operand_ty.childType(zcu);
            const llvm_vector_ty = try o.lowerType(pt, inst_ty);
            if (!operand_is_ref) return self.ng.todo("implement bitcast non-ref array to vector", .{});

            const bitcast_ok = elem_ty.bitSize(zcu) == elem_ty.abiSize(zcu) * 8;
            if (bitcast_ok) {
                // The array is aligned to the element's alignment, while the vector might have a completely
                // different alignment. This means we need to enforce the alignment of this load.
                const alignment = elem_ty.abiAlignment(zcu).toLlvm();
                return self.wip.load(.normal, llvm_vector_ty, operand, alignment, "");
            } else {
                // If the ABI size of the element type is not evenly divisible by size in bits;
                // a simple bitcast will not work, and we fall back to extractelement.
                const array_llvm_ty = try o.lowerType(pt, operand_ty);
                const elem_llvm_ty = try o.lowerType(pt, elem_ty);
                const llvm_usize = try o.lowerType(pt, Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const vector_len = operand_ty.arrayLen(zcu);
                var vector = try o.builder.poisonValue(llvm_vector_ty);
                var i: u64 = 0;
                while (i < vector_len) : (i += 1) {
                    const elem_ptr = try self.wip.gep(.inbounds, array_llvm_ty, operand, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const elem = try self.wip.load(.normal, elem_llvm_ty, elem_ptr, .default, "");
                    vector =
                        try self.wip.insertElement(vector, elem, try o.builder.intValue(.i32, i), "");
                }
                return vector;
            }
        }

        if (operand_is_ref) {
            const alignment = operand_ty.abiAlignment(zcu).toLlvm();
            return self.wip.load(.normal, llvm_dest_ty, operand, alignment, "");
        }

        if (result_is_ref) {
            const alignment = operand_ty.abiAlignment(zcu).max(inst_ty.abiAlignment(zcu)).toLlvm();
            const result_ptr = try self.buildAlloca(llvm_dest_ty, alignment);
            _ = try self.wip.store(.normal, operand, result_ptr, alignment);
            return result_ptr;
        }

        if (llvm_dest_ty.isStruct(&o.builder) or
            ((operand_ty.zigTypeTag(zcu) == .vector or inst_ty.zigTypeTag(zcu) == .vector) and
                operand_ty.bitSize(zcu) != inst_ty.bitSize(zcu)))
        {
            // Both our operand and our result are values, not pointers,
            // but LLVM won't let us bitcast struct values or vectors with padding bits.
            // Therefore, we store operand to alloca, then load for result.
            const alignment = operand_ty.abiAlignment(zcu).max(inst_ty.abiAlignment(zcu)).toLlvm();
            const result_ptr = try self.buildAlloca(llvm_dest_ty, alignment);
            _ = try self.wip.store(.normal, operand, result_ptr, alignment);
            return self.wip.load(.normal, llvm_dest_ty, result_ptr, alignment, "");
        }

        return self.wip.cast(.bitcast, operand, llvm_dest_ty, "");
    }

    fn airArg(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const arg_val = self.args[self.arg_index];
        self.arg_index += 1;

        // llvm does not support debug info for naked function arguments
        if (self.is_naked) return arg_val;

        const inst_ty = self.typeOfIndex(inst);

        const func = zcu.funcInfo(zcu.navValue(self.ng.nav_index).toIntern());
        const func_zir = func.zir_body_inst.resolveFull(&zcu.intern_pool).?;
        const file = zcu.fileByIndex(func_zir.file);

        const mod = file.mod.?;
        if (mod.strip) return arg_val;
        const arg = self.air.instructions.items(.data)[@intFromEnum(inst)].arg;
        const zir = &file.zir.?;
        const name = zir.nullTerminatedString(zir.getParamName(zir.getParamBody(func_zir.inst)[arg.zir_param_index]).?);

        const lbrace_line = zcu.navSrcLine(func.owner_nav) + func.lbrace_line + 1;
        const lbrace_col = func.lbrace_column + 1;

        const debug_parameter = try o.builder.debugParameter(
            try o.builder.metadataString(name),
            self.file,
            self.scope,
            lbrace_line,
            try o.lowerDebugType(pt, inst_ty),
            self.arg_index,
        );

        const old_location = self.wip.debug_location;
        self.wip.debug_location = .{
            .location = .{
                .line = lbrace_line,
                .column = lbrace_col,
                .scope = self.scope,
                .inlined_at = .none,
            },
        };

        if (isByRef(inst_ty, zcu)) {
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.declare",
                &.{},
                &.{
                    (try self.wip.debugValue(arg_val)).toValue(),
                    debug_parameter.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        } else if (mod.optimize_mode == .Debug) {
            const alignment = inst_ty.abiAlignment(zcu).toLlvm();
            const alloca = try self.buildAlloca(arg_val.typeOfWip(&self.wip), alignment);
            _ = try self.wip.store(.normal, arg_val, alloca, alignment);
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.declare",
                &.{},
                &.{
                    (try self.wip.debugValue(alloca)).toValue(),
                    debug_parameter.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        } else {
            _ = try self.wip.callIntrinsic(
                .normal,
                .none,
                .@"dbg.value",
                &.{},
                &.{
                    (try self.wip.debugValue(arg_val)).toValue(),
                    debug_parameter.toValue(),
                    (try o.builder.debugExpression(&.{})).toValue(),
                },
                "",
            );
        }

        self.wip.debug_location = old_location;
        return arg_val;
    }

    fn airAlloc(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ptr_ty = self.typeOfIndex(inst);
        const pointee_type = ptr_ty.childType(zcu);
        if (!pointee_type.isFnOrHasRuntimeBitsIgnoreComptime(zcu))
            return (try o.lowerPtrToVoid(pt, ptr_ty)).toValue();

        const pointee_llvm_ty = try o.lowerType(pt, pointee_type);
        const alignment = ptr_ty.ptrAlignment(zcu).toLlvm();
        return self.buildAlloca(pointee_llvm_ty, alignment);
    }

    fn airRetPtr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ptr_ty = self.typeOfIndex(inst);
        const ret_ty = ptr_ty.childType(zcu);
        if (!ret_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu))
            return (try o.lowerPtrToVoid(pt, ptr_ty)).toValue();
        if (self.ret_ptr != .none) return self.ret_ptr;
        const ret_llvm_ty = try o.lowerType(pt, ret_ty);
        const alignment = ptr_ty.ptrAlignment(zcu).toLlvm();
        return self.buildAlloca(ret_llvm_ty, alignment);
    }

    /// Use this instead of builder.buildAlloca, because this function makes sure to
    /// put the alloca instruction at the top of the function!
    fn buildAlloca(
        self: *FuncGen,
        llvm_ty: Builder.Type,
        alignment: Builder.Alignment,
    ) Allocator.Error!Builder.Value {
        const target = self.ng.pt.zcu.getTarget();
        return buildAllocaInner(&self.wip, llvm_ty, alignment, target);
    }

    fn airStore(self: *FuncGen, inst: Air.Inst.Index, safety: bool) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType(zcu);

        const val_is_undef = if (try self.air.value(bin_op.rhs, pt)) |val| val.isUndef(zcu) else false;
        if (val_is_undef) {
            const owner_mod = self.ng.ownerModule();

            // Even if safety is disabled, we still emit a memset to undefined since it conveys
            // extra information to LLVM, and LLVM will optimize it out. Safety makes the difference
            // between using 0xaa or actual undefined for the fill byte.
            //
            // However, for Debug builds specifically, we avoid emitting the memset because LLVM
            // will neither use the information nor get rid of the memset, thus leaving an
            // unexpected call in the user's code. This is problematic if the code in question is
            // not ready to correctly make calls yet, such as in our early PIE startup code, or in
            // the early stages of a dynamic linker, etc.
            if (!safety and owner_mod.optimize_mode == .Debug) {
                return .none;
            }

            const ptr_info = ptr_ty.ptrInfo(zcu);
            const needs_bitmask = (ptr_info.packed_offset.host_size != 0);
            if (needs_bitmask) {
                // TODO: only some bits are to be undef, we cannot write with a simple memset.
                // meanwhile, ignore the write rather than stomping over valid bits.
                // https://github.com/ziglang/zig/issues/15337
                return .none;
            }

            self.maybeMarkAllowZeroAccess(ptr_info);

            const len = try o.builder.intValue(try o.lowerType(pt, Type.usize), operand_ty.abiSize(zcu));
            _ = try self.wip.callMemSet(
                dest_ptr,
                ptr_ty.ptrAlignment(zcu).toLlvm(),
                if (safety) try o.builder.intValue(.i8, 0xaa) else try o.builder.undefValue(.i8),
                len,
                if (ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal,
                self.disable_intrinsics,
            );
            if (safety and owner_mod.valgrind) {
                try self.valgrindMarkUndef(dest_ptr, len);
            }
            return .none;
        }

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        const src_operand = try self.resolveInst(bin_op.rhs);
        try self.store(dest_ptr, ptr_ty, src_operand, .none);
        return .none;
    }

    fn airLoad(fg: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const ty_op = fg.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const ptr_ty = fg.typeOf(ty_op.operand);
        const ptr_info = ptr_ty.ptrInfo(zcu);
        const ptr = try fg.resolveInst(ty_op.operand);
        fg.maybeMarkAllowZeroAccess(ptr_info);
        return fg.load(ptr, ptr_ty);
    }

    fn airTrap(self: *FuncGen, inst: Air.Inst.Index) !void {
        _ = inst;
        _ = try self.wip.callIntrinsic(.normal, .none, .trap, &.{}, &.{}, "");
        _ = try self.wip.@"unreachable"();
    }

    fn airBreakpoint(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        _ = try self.wip.callIntrinsic(.normal, .none, .debugtrap, &.{}, &.{}, "");
        return .none;
    }

    fn airRetAddr(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        const o = self.ng.object;
        const pt = self.ng.pt;
        const llvm_usize = try o.lowerType(pt, Type.usize);
        if (!target_util.supportsReturnAddress(self.ng.pt.zcu.getTarget(), self.ng.ownerModule().optimize_mode)) {
            // https://github.com/ziglang/zig/issues/11946
            return o.builder.intValue(llvm_usize, 0);
        }
        const result = try self.wip.callIntrinsic(.normal, .none, .returnaddress, &.{}, &.{.@"0"}, "");
        return self.wip.cast(.ptrtoint, result, llvm_usize, "");
    }

    fn airFrameAddress(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        _ = inst;
        const o = self.ng.object;
        const pt = self.ng.pt;
        const result = try self.wip.callIntrinsic(.normal, .none, .frameaddress, &.{.ptr}, &.{.@"0"}, "");
        return self.wip.cast(.ptrtoint, result, try o.lowerType(pt, Type.usize), "");
    }

    fn airCmpxchg(
        self: *FuncGen,
        inst: Air.Inst.Index,
        kind: Builder.Function.Instruction.CmpXchg.Kind,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;
        const ptr = try self.resolveInst(extra.ptr);
        const ptr_ty = self.typeOf(extra.ptr);
        var expected_value = try self.resolveInst(extra.expected_value);
        var new_value = try self.resolveInst(extra.new_value);
        const operand_ty = ptr_ty.childType(zcu);
        const llvm_operand_ty = try o.lowerType(pt, operand_ty);
        const llvm_abi_ty = try o.getAtomicAbiType(pt, operand_ty, false);
        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating
            const signedness: Builder.Function.Instruction.Cast.Signedness =
                if (operand_ty.isSignedInt(zcu)) .signed else .unsigned;
            expected_value = try self.wip.conv(signedness, expected_value, llvm_abi_ty, "");
            new_value = try self.wip.conv(signedness, new_value, llvm_abi_ty, "");
        }

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        const result = try self.wip.cmpxchg(
            kind,
            if (ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal,
            ptr,
            expected_value,
            new_value,
            self.sync_scope,
            toLlvmAtomicOrdering(extra.successOrder()),
            toLlvmAtomicOrdering(extra.failureOrder()),
            ptr_ty.ptrAlignment(zcu).toLlvm(),
            "",
        );

        const optional_ty = self.typeOfIndex(inst);

        var payload = try self.wip.extractValue(result, &.{0}, "");
        if (llvm_abi_ty != .none) payload = try self.wip.cast(.trunc, payload, llvm_operand_ty, "");
        const success_bit = try self.wip.extractValue(result, &.{1}, "");

        if (optional_ty.optionalReprIsPayload(zcu)) {
            const zero = try o.builder.zeroInitValue(payload.typeOfWip(&self.wip));
            return self.wip.select(.normal, success_bit, zero, payload, "");
        }

        comptime assert(optional_layout_version == 3);

        const non_null_bit = try self.wip.not(success_bit, "");
        return buildOptional(self, optional_ty, payload, non_null_bit);
    }

    fn airAtomicRmw(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;
        const ptr = try self.resolveInst(pl_op.operand);
        const ptr_ty = self.typeOf(pl_op.operand);
        const operand_ty = ptr_ty.childType(zcu);
        const operand = try self.resolveInst(extra.operand);
        const is_signed_int = operand_ty.isSignedInt(zcu);
        const is_float = operand_ty.isRuntimeFloat();
        const op = toLlvmAtomicRmwBinOp(extra.op(), is_signed_int, is_float);
        const ordering = toLlvmAtomicOrdering(extra.ordering());
        const llvm_abi_ty = try o.getAtomicAbiType(pt, operand_ty, op == .xchg);
        const llvm_operand_ty = try o.lowerType(pt, operand_ty);

        const access_kind: Builder.MemoryAccessKind =
            if (ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;
        const ptr_alignment = ptr_ty.ptrAlignment(zcu).toLlvm();

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating or bitcasting.
            return self.wip.cast(if (is_float) .bitcast else .trunc, try self.wip.atomicrmw(
                access_kind,
                op,
                ptr,
                try self.wip.cast(
                    if (is_float) .bitcast else if (is_signed_int) .sext else .zext,
                    operand,
                    llvm_abi_ty,
                    "",
                ),
                self.sync_scope,
                ordering,
                ptr_alignment,
                "",
            ), llvm_operand_ty, "");
        }

        if (!llvm_operand_ty.isPointer(&o.builder)) return self.wip.atomicrmw(
            access_kind,
            op,
            ptr,
            operand,
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        );

        // It's a pointer but we need to treat it as an int.
        return self.wip.cast(.inttoptr, try self.wip.atomicrmw(
            access_kind,
            op,
            ptr,
            try self.wip.cast(.ptrtoint, operand, try o.lowerType(pt, Type.usize), ""),
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        ), llvm_operand_ty, "");
    }

    fn airAtomicLoad(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const atomic_load = self.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;
        const ptr = try self.resolveInst(atomic_load.ptr);
        const ptr_ty = self.typeOf(atomic_load.ptr);
        const info = ptr_ty.ptrInfo(zcu);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;
        const ordering = toLlvmAtomicOrdering(atomic_load.order);
        const llvm_abi_ty = try o.getAtomicAbiType(pt, elem_ty, false);
        const ptr_alignment = (if (info.flags.alignment != .none)
            @as(InternPool.Alignment, info.flags.alignment)
        else
            Type.fromInterned(info.child).abiAlignment(zcu)).toLlvm();
        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;
        const elem_llvm_ty = try o.lowerType(pt, elem_ty);

        self.maybeMarkAllowZeroAccess(info);

        if (llvm_abi_ty != .none) {
            // operand needs widening and truncating
            const loaded = try self.wip.loadAtomic(
                access_kind,
                llvm_abi_ty,
                ptr,
                self.sync_scope,
                ordering,
                ptr_alignment,
                "",
            );
            return self.wip.cast(.trunc, loaded, elem_llvm_ty, "");
        }
        return self.wip.loadAtomic(
            access_kind,
            elem_llvm_ty,
            ptr,
            self.sync_scope,
            ordering,
            ptr_alignment,
            "",
        );
    }

    fn airAtomicStore(
        self: *FuncGen,
        inst: Air.Inst.Index,
        ordering: Builder.AtomicOrdering,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const ptr_ty = self.typeOf(bin_op.lhs);
        const operand_ty = ptr_ty.childType(zcu);
        if (!operand_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) return .none;
        const ptr = try self.resolveInst(bin_op.lhs);
        var element = try self.resolveInst(bin_op.rhs);
        const llvm_abi_ty = try o.getAtomicAbiType(pt, operand_ty, false);

        if (llvm_abi_ty != .none) {
            // operand needs widening
            element = try self.wip.conv(
                if (operand_ty.isSignedInt(zcu)) .signed else .unsigned,
                element,
                llvm_abi_ty,
                "",
            );
        }

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        try self.store(ptr, ptr_ty, element, ordering);
        return .none;
    }

    fn airMemset(self: *FuncGen, inst: Air.Inst.Index, safety: bool) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_slice = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const elem_ty = self.typeOf(bin_op.rhs);
        const dest_ptr_align = ptr_ty.ptrAlignment(zcu).toLlvm();
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, ptr_ty);
        const access_kind: Builder.MemoryAccessKind =
            if (ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        self.maybeMarkAllowZeroAccess(ptr_ty.ptrInfo(zcu));

        if (try self.air.value(bin_op.rhs, pt)) |elem_val| {
            if (elem_val.isUndef(zcu)) {
                // Even if safety is disabled, we still emit a memset to undefined since it conveys
                // extra information to LLVM. However, safety makes the difference between using
                // 0xaa or actual undefined for the fill byte.
                const fill_byte = if (safety)
                    try o.builder.intValue(.i8, 0xaa)
                else
                    try o.builder.undefValue(.i8);
                const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);
                _ = try self.wip.callMemSet(
                    dest_ptr,
                    dest_ptr_align,
                    fill_byte,
                    len,
                    access_kind,
                    self.disable_intrinsics,
                );
                const owner_mod = self.ng.ownerModule();
                if (safety and owner_mod.valgrind) {
                    try self.valgrindMarkUndef(dest_ptr, len);
                }
                return .none;
            }

            // Test if the element value is compile-time known to be a
            // repeating byte pattern, for example, `@as(u64, 0)` has a
            // repeating byte pattern of 0 bytes. In such case, the memset
            // intrinsic can be used.
            if (try elem_val.hasRepeatedByteRepr(pt)) |byte_val| {
                const fill_byte = try o.builder.intValue(.i8, byte_val);
                const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);
                _ = try self.wip.callMemSet(
                    dest_ptr,
                    dest_ptr_align,
                    fill_byte,
                    len,
                    access_kind,
                    self.disable_intrinsics,
                );
                return .none;
            }
        }

        const value = try self.resolveInst(bin_op.rhs);
        const elem_abi_size = elem_ty.abiSize(zcu);

        if (elem_abi_size == 1) {
            // In this case we can take advantage of LLVM's intrinsic.
            const fill_byte = try self.bitCast(value, elem_ty, Type.u8);
            const len = try self.sliceOrArrayLenInBytes(dest_slice, ptr_ty);

            _ = try self.wip.callMemSet(
                dest_ptr,
                dest_ptr_align,
                fill_byte,
                len,
                access_kind,
                self.disable_intrinsics,
            );
            return .none;
        }

        // non-byte-sized element. lower with a loop. something like this:

        // entry:
        //   ...
        //   %end_ptr = getelementptr %ptr, %len
        //   br %loop
        // loop:
        //   %it_ptr = phi body %next_ptr, entry %ptr
        //   %end = cmp eq %it_ptr, %end_ptr
        //   br %end, %body, %end
        // body:
        //   store %it_ptr, %value
        //   %next_ptr = getelementptr %it_ptr, 1
        //   br %loop
        // end:
        //   ...
        const entry_block = self.wip.cursor.block;
        const loop_block = try self.wip.block(2, "InlineMemsetLoop");
        const body_block = try self.wip.block(1, "InlineMemsetBody");
        const end_block = try self.wip.block(1, "InlineMemsetEnd");

        const llvm_usize_ty = try o.lowerType(pt, Type.usize);
        const len = switch (ptr_ty.ptrSize(zcu)) {
            .slice => try self.wip.extractValue(dest_slice, &.{1}, ""),
            .one => try o.builder.intValue(llvm_usize_ty, ptr_ty.childType(zcu).arrayLen(zcu)),
            .many, .c => unreachable,
        };
        const elem_llvm_ty = try o.lowerType(pt, elem_ty);
        const end_ptr = try self.wip.gep(.inbounds, elem_llvm_ty, dest_ptr, &.{len}, "");
        _ = try self.wip.br(loop_block);

        self.wip.cursor = .{ .block = loop_block };
        const it_ptr = try self.wip.phi(.ptr, "");
        const end = try self.wip.icmp(.ne, it_ptr.toValue(), end_ptr, "");
        _ = try self.wip.brCond(end, body_block, end_block, .none);

        self.wip.cursor = .{ .block = body_block };
        const elem_abi_align = elem_ty.abiAlignment(zcu);
        const it_ptr_align = InternPool.Alignment.fromLlvm(dest_ptr_align).min(elem_abi_align).toLlvm();
        if (isByRef(elem_ty, zcu)) {
            _ = try self.wip.callMemCpy(
                it_ptr.toValue(),
                it_ptr_align,
                value,
                elem_abi_align.toLlvm(),
                try o.builder.intValue(llvm_usize_ty, elem_abi_size),
                access_kind,
                self.disable_intrinsics,
            );
        } else _ = try self.wip.store(access_kind, value, it_ptr.toValue(), it_ptr_align);
        const next_ptr = try self.wip.gep(.inbounds, elem_llvm_ty, it_ptr.toValue(), &.{
            try o.builder.intValue(llvm_usize_ty, 1),
        }, "");
        _ = try self.wip.br(loop_block);

        self.wip.cursor = .{ .block = end_block };
        it_ptr.finish(&.{ next_ptr, dest_ptr }, &.{ body_block, entry_block }, &self.wip);
        return .none;
    }

    fn airMemcpy(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_slice = try self.resolveInst(bin_op.lhs);
        const dest_ptr_ty = self.typeOf(bin_op.lhs);
        const src_slice = try self.resolveInst(bin_op.rhs);
        const src_ptr_ty = self.typeOf(bin_op.rhs);
        const src_ptr = try self.sliceOrArrayPtr(src_slice, src_ptr_ty);
        const len = try self.sliceOrArrayLenInBytes(dest_slice, dest_ptr_ty);
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, dest_ptr_ty);
        const access_kind: Builder.MemoryAccessKind = if (src_ptr_ty.isVolatilePtr(zcu) or
            dest_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        self.maybeMarkAllowZeroAccess(dest_ptr_ty.ptrInfo(zcu));
        self.maybeMarkAllowZeroAccess(src_ptr_ty.ptrInfo(zcu));

        _ = try self.wip.callMemCpy(
            dest_ptr,
            dest_ptr_ty.ptrAlignment(zcu).toLlvm(),
            src_ptr,
            src_ptr_ty.ptrAlignment(zcu).toLlvm(),
            len,
            access_kind,
            self.disable_intrinsics,
        );
        return .none;
    }

    fn airMemmove(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const dest_slice = try self.resolveInst(bin_op.lhs);
        const dest_ptr_ty = self.typeOf(bin_op.lhs);
        const src_slice = try self.resolveInst(bin_op.rhs);
        const src_ptr_ty = self.typeOf(bin_op.rhs);
        const src_ptr = try self.sliceOrArrayPtr(src_slice, src_ptr_ty);
        const len = try self.sliceOrArrayLenInBytes(dest_slice, dest_ptr_ty);
        const dest_ptr = try self.sliceOrArrayPtr(dest_slice, dest_ptr_ty);
        const access_kind: Builder.MemoryAccessKind = if (src_ptr_ty.isVolatilePtr(zcu) or
            dest_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        _ = try self.wip.callMemMove(
            dest_ptr,
            dest_ptr_ty.ptrAlignment(zcu).toLlvm(),
            src_ptr,
            src_ptr_ty.ptrAlignment(zcu).toLlvm(),
            len,
            access_kind,
        );
        return .none;
    }

    fn airSetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
        const un_ptr_ty = self.typeOf(bin_op.lhs);
        const un_ty = un_ptr_ty.childType(zcu);
        const layout = un_ty.unionGetLayout(zcu);
        if (layout.tag_size == 0) return .none;

        const access_kind: Builder.MemoryAccessKind =
            if (un_ptr_ty.isVolatilePtr(zcu)) .@"volatile" else .normal;

        self.maybeMarkAllowZeroAccess(un_ptr_ty.ptrInfo(zcu));

        const union_ptr = try self.resolveInst(bin_op.lhs);
        const new_tag = try self.resolveInst(bin_op.rhs);
        if (layout.payload_size == 0) {
            // TODO alignment on this store
            _ = try self.wip.store(access_kind, new_tag, union_ptr, .default);
            return .none;
        }
        const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
        const tag_field_ptr = try self.wip.gepStruct(try o.lowerType(pt, un_ty), union_ptr, tag_index, "");
        // TODO alignment on this store
        _ = try self.wip.store(access_kind, new_tag, tag_field_ptr, .default);
        return .none;
    }

    fn airGetUnionTag(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const un_ty = self.typeOf(ty_op.operand);
        const layout = un_ty.unionGetLayout(zcu);
        if (layout.tag_size == 0) return .none;
        const union_handle = try self.resolveInst(ty_op.operand);
        if (isByRef(un_ty, zcu)) {
            const llvm_un_ty = try o.lowerType(pt, un_ty);
            if (layout.payload_size == 0)
                return self.wip.load(.normal, llvm_un_ty, union_handle, .default, "");
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            const tag_field_ptr = try self.wip.gepStruct(llvm_un_ty, union_handle, tag_index, "");
            const llvm_tag_ty = llvm_un_ty.structFields(&o.builder)[tag_index];
            return self.wip.load(.normal, llvm_tag_ty, tag_field_ptr, .default, "");
        } else {
            if (layout.payload_size == 0) return union_handle;
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            return self.wip.extractValue(union_handle, &.{tag_index}, "");
        }
    }

    fn airUnaryOp(self: *FuncGen, inst: Air.Inst.Index, comptime op: FloatOp) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);

        return self.buildFloatOp(op, .normal, operand_ty, 1, .{operand});
    }

    fn airNeg(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);

        return self.buildFloatOp(.neg, fast, operand_ty, 1, .{operand});
    }

    fn airClzCtz(self: *FuncGen, inst: Air.Inst.Index, intrinsic: Builder.Intrinsic) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            intrinsic,
            &.{try o.lowerType(pt, operand_ty)},
            &.{ operand, .false },
            "",
        );
        return self.wip.conv(.unsigned, result, try o.lowerType(pt, inst_ty), "");
    }

    fn airBitOp(self: *FuncGen, inst: Air.Inst.Index, intrinsic: Builder.Intrinsic) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand_ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const result = try self.wip.callIntrinsic(
            .normal,
            .none,
            intrinsic,
            &.{try o.lowerType(pt, operand_ty)},
            &.{operand},
            "",
        );
        return self.wip.conv(.unsigned, result, try o.lowerType(pt, inst_ty), "");
    }

    fn airByteSwap(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand_ty = self.typeOf(ty_op.operand);
        var bits = operand_ty.intInfo(zcu).bits;
        assert(bits % 8 == 0);

        const inst_ty = self.typeOfIndex(inst);
        var operand = try self.resolveInst(ty_op.operand);
        var llvm_operand_ty = try o.lowerType(pt, operand_ty);

        if (bits % 16 == 8) {
            // If not an even byte-multiple, we need zero-extend + shift-left 1 byte
            // The truncated result at the end will be the correct bswap
            const scalar_ty = try o.builder.intType(@intCast(bits + 8));
            if (operand_ty.zigTypeTag(zcu) == .vector) {
                const vec_len = operand_ty.vectorLen(zcu);
                llvm_operand_ty = try o.builder.vectorType(.normal, vec_len, scalar_ty);
            } else llvm_operand_ty = scalar_ty;

            const shift_amt =
                try o.builder.splatValue(llvm_operand_ty, try o.builder.intConst(scalar_ty, 8));
            const extended = try self.wip.cast(.zext, operand, llvm_operand_ty, "");
            operand = try self.wip.bin(.shl, extended, shift_amt, "");

            bits = bits + 8;
        }

        const result =
            try self.wip.callIntrinsic(.normal, .none, .bswap, &.{llvm_operand_ty}, &.{operand}, "");
        return self.wip.conv(.unsigned, result, try o.lowerType(pt, inst_ty), "");
    }

    fn airErrorSetHasValue(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const operand = try self.resolveInst(ty_op.operand);
        const error_set_ty = ty_op.ty.toType();

        const names = error_set_ty.errorSetNames(zcu);
        const valid_block = try self.wip.block(@intCast(names.len), "Valid");
        const invalid_block = try self.wip.block(1, "Invalid");
        const end_block = try self.wip.block(2, "End");
        var wip_switch = try self.wip.@"switch"(operand, invalid_block, @intCast(names.len), .none);
        defer wip_switch.finish(&self.wip);

        for (0..names.len) |name_index| {
            const err_int = ip.getErrorValueIfExists(names.get(ip)[name_index]).?;
            const this_tag_int_value = try o.builder.intConst(try o.errorIntType(pt), err_int);
            try wip_switch.addCase(this_tag_int_value, valid_block, &self.wip);
        }
        self.wip.cursor = .{ .block = valid_block };
        _ = try self.wip.br(end_block);

        self.wip.cursor = .{ .block = invalid_block };
        _ = try self.wip.br(end_block);

        self.wip.cursor = .{ .block = end_block };
        const phi = try self.wip.phi(.i1, "");
        phi.finish(&.{ .true, .false }, &.{ valid_block, invalid_block }, &self.wip);
        return phi.toValue();
    }

    fn airIsNamedEnumValue(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const enum_ty = self.typeOf(un_op);

        const llvm_fn = try self.getIsNamedEnumValueFunction(enum_ty);
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn getIsNamedEnumValueFunction(self: *FuncGen, enum_ty: Type) !Builder.Function.Index {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const enum_type = ip.loadEnumType(enum_ty.toIntern());

        // TODO: detect when the type changes and re-emit this function.
        const gop = try o.named_enum_map.getOrPut(o.gpa, enum_ty.toIntern());
        if (gop.found_existing) return gop.value_ptr.*;
        errdefer assert(o.named_enum_map.remove(enum_ty.toIntern()));

        const target = &zcu.root_mod.resolved_target.result;
        const function_index = try o.builder.addFunction(
            try o.builder.fnType(.i1, &.{try o.lowerType(pt, Type.fromInterned(enum_type.tag_ty))}, .normal),
            try o.builder.strtabStringFmt("__zig_is_named_enum_value_{f}", .{enum_type.name.fmt(ip)}),
            toLlvmAddressSpace(.generic, target),
        );

        var attributes: Builder.FunctionAttributes.Wip = .{};
        defer attributes.deinit(&o.builder);
        try o.addCommonFnAttributes(&attributes, zcu.root_mod, zcu.root_mod.omit_frame_pointer);

        function_index.setLinkage(.internal, &o.builder);
        function_index.setCallConv(.fastcc, &o.builder);
        function_index.setAttributes(try attributes.finish(&o.builder), &o.builder);
        gop.value_ptr.* = function_index;

        var wip = try Builder.WipFunction.init(&o.builder, .{
            .function = function_index,
            .strip = true,
        });
        defer wip.deinit();
        wip.cursor = .{ .block = try wip.block(0, "Entry") };

        const named_block = try wip.block(@intCast(enum_type.names.len), "Named");
        const unnamed_block = try wip.block(1, "Unnamed");
        const tag_int_value = wip.arg(0);
        var wip_switch = try wip.@"switch"(tag_int_value, unnamed_block, @intCast(enum_type.names.len), .none);
        defer wip_switch.finish(&wip);

        for (0..enum_type.names.len) |field_index| {
            const this_tag_int_value = try o.lowerValue(
                pt,
                (try pt.enumValueFieldIndex(enum_ty, @intCast(field_index))).toIntern(),
            );
            try wip_switch.addCase(this_tag_int_value, named_block, &wip);
        }
        wip.cursor = .{ .block = named_block };
        _ = try wip.ret(.true);

        wip.cursor = .{ .block = unnamed_block };
        _ = try wip.ret(.false);

        try wip.finish();
        return function_index;
    }

    fn airTagName(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const enum_ty = self.typeOf(un_op);

        const llvm_fn = try o.getEnumTagNameFunction(pt, enum_ty);
        return self.wip.call(
            .normal,
            .fastcc,
            .none,
            llvm_fn.typeOf(&o.builder),
            llvm_fn.toValue(&o.builder),
            &.{operand},
            "",
        );
    }

    fn airErrorName(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
        const operand = try self.resolveInst(un_op);
        const slice_ty = self.typeOfIndex(inst);
        const slice_llvm_ty = try o.lowerType(pt, slice_ty);

        // If operand is small (e.g. `u8`), then signedness becomes a problem -- GEP always treats the index as signed.
        const extended_operand = try self.wip.conv(.unsigned, operand, try o.lowerType(pt, .usize), "");

        const error_name_table_ptr = try self.getErrorNameTable();
        const error_name_table =
            try self.wip.load(.normal, .ptr, error_name_table_ptr.toValue(&o.builder), .default, "");
        const error_name_ptr =
            try self.wip.gep(.inbounds, slice_llvm_ty, error_name_table, &.{extended_operand}, "");
        return self.wip.load(.normal, slice_llvm_ty, error_name_ptr, .default, "");
    }

    fn airSplat(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const scalar = try self.resolveInst(ty_op.operand);
        const vector_ty = self.typeOfIndex(inst);
        return self.wip.splatVector(try o.lowerType(pt, vector_ty), scalar, "");
    }

    fn airSelect(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
        const pred = try self.resolveInst(pl_op.operand);
        const a = try self.resolveInst(extra.lhs);
        const b = try self.resolveInst(extra.rhs);

        return self.wip.select(.normal, pred, a, b, "");
    }

    fn airShuffleOne(fg: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const gpa = zcu.gpa;

        const unwrapped = fg.air.unwrapShuffleOne(zcu, inst);

        const operand = try fg.resolveInst(unwrapped.operand);
        const mask = unwrapped.mask;
        const operand_ty = fg.typeOf(unwrapped.operand);
        const llvm_operand_ty = try o.lowerType(pt, operand_ty);
        const llvm_result_ty = try o.lowerType(pt, unwrapped.result_ty);
        const llvm_elem_ty = try o.lowerType(pt, unwrapped.result_ty.childType(zcu));
        const llvm_poison_elem = try o.builder.poisonConst(llvm_elem_ty);
        const llvm_poison_mask_elem = try o.builder.poisonConst(.i32);
        const llvm_mask_ty = try o.builder.vectorType(.normal, @intCast(mask.len), .i32);

        // LLVM requires that the two input vectors have the same length, so lowering isn't trivial.
        // And, in the words of jacobly0: "llvm sucks at shuffles so we do have to hold its hand at
        // least a bit". So, there are two cases here.
        //
        // If the operand length equals the mask length, we do just the one `shufflevector`, where
        // the second operand is a constant vector with comptime-known elements at the right indices
        // and poison values elsewhere (in the indices which won't be selected).
        //
        // Otherwise, we lower to *two* `shufflevector` instructions. The first shuffles the runtime
        // operand with an all-poison vector to extract and correctly position all of the runtime
        // elements. We also make a constant vector with all of the comptime elements correctly
        // positioned. Then, our second instruction selects elements from those "runtime-or-poison"
        // and "comptime-or-poison" vectors to compute the result.

        // This buffer is used primarily for the mask constants.
        const llvm_elem_buf = try gpa.alloc(Builder.Constant, mask.len);
        defer gpa.free(llvm_elem_buf);

        // ...but first, we'll collect all of the comptime-known values.
        var any_defined_comptime_value = false;
        for (mask, llvm_elem_buf) |mask_elem, *llvm_elem| {
            llvm_elem.* = switch (mask_elem.unwrap()) {
                .elem => llvm_poison_elem,
                .value => |val| if (!Value.fromInterned(val).isUndef(zcu)) elem: {
                    any_defined_comptime_value = true;
                    break :elem try o.lowerValue(pt, val);
                } else llvm_poison_elem,
            };
        }
        // This vector is like the result, but runtime elements are replaced with poison.
        const comptime_and_poison: Builder.Value = if (any_defined_comptime_value) vec: {
            break :vec try o.builder.vectorValue(llvm_result_ty, llvm_elem_buf);
        } else try o.builder.poisonValue(llvm_result_ty);

        if (operand_ty.vectorLen(zcu) == mask.len) {
            // input length equals mask/output length, so we lower to one instruction
            for (mask, llvm_elem_buf, 0..) |mask_elem, *llvm_elem, elem_idx| {
                llvm_elem.* = switch (mask_elem.unwrap()) {
                    .elem => |idx| try o.builder.intConst(.i32, idx),
                    .value => |val| if (!Value.fromInterned(val).isUndef(zcu)) mask_val: {
                        break :mask_val try o.builder.intConst(.i32, mask.len + elem_idx);
                    } else llvm_poison_mask_elem,
                };
            }
            return fg.wip.shuffleVector(
                operand,
                comptime_and_poison,
                try o.builder.vectorValue(llvm_mask_ty, llvm_elem_buf),
                "",
            );
        }

        for (mask, llvm_elem_buf) |mask_elem, *llvm_elem| {
            llvm_elem.* = switch (mask_elem.unwrap()) {
                .elem => |idx| try o.builder.intConst(.i32, idx),
                .value => llvm_poison_mask_elem,
            };
        }
        // This vector is like our result, but all comptime-known elements are poison.
        const runtime_and_poison = try fg.wip.shuffleVector(
            operand,
            try o.builder.poisonValue(llvm_operand_ty),
            try o.builder.vectorValue(llvm_mask_ty, llvm_elem_buf),
            "",
        );

        if (!any_defined_comptime_value) {
            // `comptime_and_poison` is just poison; a second shuffle would be a nop.
            return runtime_and_poison;
        }

        // In this second shuffle, the inputs, the mask, and the output all have the same length.
        for (mask, llvm_elem_buf, 0..) |mask_elem, *llvm_elem, elem_idx| {
            llvm_elem.* = switch (mask_elem.unwrap()) {
                .elem => try o.builder.intConst(.i32, elem_idx),
                .value => |val| if (!Value.fromInterned(val).isUndef(zcu)) mask_val: {
                    break :mask_val try o.builder.intConst(.i32, mask.len + elem_idx);
                } else llvm_poison_mask_elem,
            };
        }
        // Merge the runtime and comptime elements with the mask we just built.
        return fg.wip.shuffleVector(
            runtime_and_poison,
            comptime_and_poison,
            try o.builder.vectorValue(llvm_mask_ty, llvm_elem_buf),
            "",
        );
    }

    fn airShuffleTwo(fg: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const gpa = zcu.gpa;

        const unwrapped = fg.air.unwrapShuffleTwo(zcu, inst);

        const mask = unwrapped.mask;
        const llvm_elem_ty = try o.lowerType(pt, unwrapped.result_ty.childType(zcu));
        const llvm_mask_ty = try o.builder.vectorType(.normal, @intCast(mask.len), .i32);
        const llvm_poison_mask_elem = try o.builder.poisonConst(.i32);

        // This is kind of simpler than in `airShuffleOne`. We extend the shorter vector to the
        // length of the longer one with an initial `shufflevector` if necessary, and then do the
        // actual computation with a second `shufflevector`.

        const operand_a_len = fg.typeOf(unwrapped.operand_a).vectorLen(zcu);
        const operand_b_len = fg.typeOf(unwrapped.operand_b).vectorLen(zcu);
        const operand_len: u32 = @max(operand_a_len, operand_b_len);

        // If we need to extend an operand, this is the type that mask will have.
        const llvm_operand_mask_ty = try o.builder.vectorType(.normal, operand_len, .i32);

        const llvm_elem_buf = try gpa.alloc(Builder.Constant, @max(mask.len, operand_len));
        defer gpa.free(llvm_elem_buf);

        const operand_a: Builder.Value = extend: {
            const raw = try fg.resolveInst(unwrapped.operand_a);
            if (operand_a_len == operand_len) break :extend raw;
            // Extend with a `shufflevector`, with a mask `<0, 1, ..., n, poison, poison, ..., poison>`
            const mask_elems = llvm_elem_buf[0..operand_len];
            for (mask_elems[0..operand_a_len], 0..) |*llvm_elem, elem_idx| {
                llvm_elem.* = try o.builder.intConst(.i32, elem_idx);
            }
            @memset(mask_elems[operand_a_len..], llvm_poison_mask_elem);
            const llvm_this_operand_ty = try o.builder.vectorType(.normal, operand_a_len, llvm_elem_ty);
            break :extend try fg.wip.shuffleVector(
                raw,
                try o.builder.poisonValue(llvm_this_operand_ty),
                try o.builder.vectorValue(llvm_operand_mask_ty, mask_elems),
                "",
            );
        };
        const operand_b: Builder.Value = extend: {
            const raw = try fg.resolveInst(unwrapped.operand_b);
            if (operand_b_len == operand_len) break :extend raw;
            // Extend with a `shufflevector`, with a mask `<0, 1, ..., n, poison, poison, ..., poison>`
            const mask_elems = llvm_elem_buf[0..operand_len];
            for (mask_elems[0..operand_b_len], 0..) |*llvm_elem, elem_idx| {
                llvm_elem.* = try o.builder.intConst(.i32, elem_idx);
            }
            @memset(mask_elems[operand_b_len..], llvm_poison_mask_elem);
            const llvm_this_operand_ty = try o.builder.vectorType(.normal, operand_b_len, llvm_elem_ty);
            break :extend try fg.wip.shuffleVector(
                raw,
                try o.builder.poisonValue(llvm_this_operand_ty),
                try o.builder.vectorValue(llvm_operand_mask_ty, mask_elems),
                "",
            );
        };

        // `operand_a` and `operand_b` now have the same length (we've extended the shorter one with
        // an initial shuffle if necessary). Now for the easy bit.

        const mask_elems = llvm_elem_buf[0..mask.len];
        for (mask, mask_elems) |mask_elem, *llvm_mask_elem| {
            llvm_mask_elem.* = switch (mask_elem.unwrap()) {
                .a_elem => |idx| try o.builder.intConst(.i32, idx),
                .b_elem => |idx| try o.builder.intConst(.i32, operand_len + idx),
                .undef => llvm_poison_mask_elem,
            };
        }
        return fg.wip.shuffleVector(
            operand_a,
            operand_b,
            try o.builder.vectorValue(llvm_mask_ty, mask_elems),
            "",
        );
    }

    /// Reduce a vector by repeatedly applying `llvm_fn` to produce an accumulated result.
    ///
    /// Equivalent to:
    ///   reduce: {
    ///     var i: usize = 0;
    ///     var accum: T = init;
    ///     while (i < vec.len) : (i += 1) {
    ///       accum = llvm_fn(accum, vec[i]);
    ///     }
    ///     break :reduce accum;
    ///   }
    ///
    fn buildReducedCall(
        self: *FuncGen,
        llvm_fn: Builder.Function.Index,
        operand_vector: Builder.Value,
        vector_len: usize,
        accum_init: Builder.Value,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const usize_ty = try o.lowerType(pt, Type.usize);
        const llvm_vector_len = try o.builder.intValue(usize_ty, vector_len);
        const llvm_result_ty = accum_init.typeOfWip(&self.wip);

        // Allocate and initialize our mutable variables
        const i_ptr = try self.buildAlloca(usize_ty, .default);
        _ = try self.wip.store(.normal, try o.builder.intValue(usize_ty, 0), i_ptr, .default);
        const accum_ptr = try self.buildAlloca(llvm_result_ty, .default);
        _ = try self.wip.store(.normal, accum_init, accum_ptr, .default);

        // Setup the loop
        const loop = try self.wip.block(2, "ReduceLoop");
        const loop_exit = try self.wip.block(1, "AfterReduce");
        _ = try self.wip.br(loop);
        {
            self.wip.cursor = .{ .block = loop };

            // while (i < vec.len)
            const i = try self.wip.load(.normal, usize_ty, i_ptr, .default, "");
            const cond = try self.wip.icmp(.ult, i, llvm_vector_len, "");
            const loop_then = try self.wip.block(1, "ReduceLoopThen");

            _ = try self.wip.brCond(cond, loop_then, loop_exit, .none);

            {
                self.wip.cursor = .{ .block = loop_then };

                // accum = f(accum, vec[i]);
                const accum = try self.wip.load(.normal, llvm_result_ty, accum_ptr, .default, "");
                const element = try self.wip.extractElement(operand_vector, i, "");
                const new_accum = try self.wip.call(
                    .normal,
                    .ccc,
                    .none,
                    llvm_fn.typeOf(&o.builder),
                    llvm_fn.toValue(&o.builder),
                    &.{ accum, element },
                    "",
                );
                _ = try self.wip.store(.normal, new_accum, accum_ptr, .default);

                // i += 1
                const new_i = try self.wip.bin(.add, i, try o.builder.intValue(usize_ty, 1), "");
                _ = try self.wip.store(.normal, new_i, i_ptr, .default);
                _ = try self.wip.br(loop);
            }
        }

        self.wip.cursor = .{ .block = loop_exit };
        return self.wip.load(.normal, llvm_result_ty, accum_ptr, .default, "");
    }

    fn airReduce(self: *FuncGen, inst: Air.Inst.Index, fast: Builder.FastMathKind) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();

        const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
        const operand = try self.resolveInst(reduce.operand);
        const operand_ty = self.typeOf(reduce.operand);
        const llvm_operand_ty = try o.lowerType(pt, operand_ty);
        const scalar_ty = self.typeOfIndex(inst);
        const llvm_scalar_ty = try o.lowerType(pt, scalar_ty);

        switch (reduce.operation) {
            .And, .Or, .Xor => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                .And => .@"vector.reduce.and",
                .Or => .@"vector.reduce.or",
                .Xor => .@"vector.reduce.xor",
                else => unreachable,
            }, &.{llvm_operand_ty}, &.{operand}, ""),
            .Min, .Max => switch (scalar_ty.zigTypeTag(zcu)) {
                .int => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                    .Min => if (scalar_ty.isSignedInt(zcu))
                        .@"vector.reduce.smin"
                    else
                        .@"vector.reduce.umin",
                    .Max => if (scalar_ty.isSignedInt(zcu))
                        .@"vector.reduce.smax"
                    else
                        .@"vector.reduce.umax",
                    else => unreachable,
                }, &.{llvm_operand_ty}, &.{operand}, ""),
                .float => if (intrinsicsAllowed(scalar_ty, target))
                    return self.wip.callIntrinsic(fast, .none, switch (reduce.operation) {
                        .Min => .@"vector.reduce.fmin",
                        .Max => .@"vector.reduce.fmax",
                        else => unreachable,
                    }, &.{llvm_operand_ty}, &.{operand}, ""),
                else => unreachable,
            },
            .Add, .Mul => switch (scalar_ty.zigTypeTag(zcu)) {
                .int => return self.wip.callIntrinsic(.normal, .none, switch (reduce.operation) {
                    .Add => .@"vector.reduce.add",
                    .Mul => .@"vector.reduce.mul",
                    else => unreachable,
                }, &.{llvm_operand_ty}, &.{operand}, ""),
                .float => if (intrinsicsAllowed(scalar_ty, target))
                    return self.wip.callIntrinsic(fast, .none, switch (reduce.operation) {
                        .Add => .@"vector.reduce.fadd",
                        .Mul => .@"vector.reduce.fmul",
                        else => unreachable,
                    }, &.{llvm_operand_ty}, &.{ switch (reduce.operation) {
                        .Add => try o.builder.fpValue(llvm_scalar_ty, -0.0),
                        .Mul => try o.builder.fpValue(llvm_scalar_ty, 1.0),
                        else => unreachable,
                    }, operand }, ""),
                else => unreachable,
            },
        }

        // Reduction could not be performed with intrinsics.
        // Use a manual loop over a softfloat call instead.
        const float_bits = scalar_ty.floatBits(target);
        const fn_name = switch (reduce.operation) {
            .Min => try o.builder.strtabStringFmt("{s}fmin{s}", .{
                libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
            }),
            .Max => try o.builder.strtabStringFmt("{s}fmax{s}", .{
                libcFloatPrefix(float_bits), libcFloatSuffix(float_bits),
            }),
            .Add => try o.builder.strtabStringFmt("__add{s}f3", .{
                compilerRtFloatAbbrev(float_bits),
            }),
            .Mul => try o.builder.strtabStringFmt("__mul{s}f3", .{
                compilerRtFloatAbbrev(float_bits),
            }),
            else => unreachable,
        };

        const libc_fn =
            try self.getLibcFunction(fn_name, &.{ llvm_scalar_ty, llvm_scalar_ty }, llvm_scalar_ty);
        const init_val = switch (llvm_scalar_ty) {
            .i16 => try o.builder.intValue(.i16, @as(i16, @bitCast(
                @as(f16, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f16),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            .i80 => try o.builder.intValue(.i80, @as(i80, @bitCast(
                @as(f80, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f80),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            .i128 => try o.builder.intValue(.i128, @as(i128, @bitCast(
                @as(f128, switch (reduce.operation) {
                    .Min, .Max => std.math.nan(f128),
                    .Add => -0.0,
                    .Mul => 1.0,
                    else => unreachable,
                }),
            ))),
            else => unreachable,
        };
        return self.buildReducedCall(libc_fn, operand, operand_ty.vectorLen(zcu), init_val);
    }

    fn airAggregateInit(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const result_ty = self.typeOfIndex(inst);
        const len: usize = @intCast(result_ty.arrayLen(zcu));
        const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra.items[ty_pl.payload..][0..len]);
        const llvm_result_ty = try o.lowerType(pt, result_ty);

        switch (result_ty.zigTypeTag(zcu)) {
            .vector => {
                var vector = try o.builder.poisonValue(llvm_result_ty);
                for (elements, 0..) |elem, i| {
                    const index_u32 = try o.builder.intValue(.i32, i);
                    const llvm_elem = try self.resolveInst(elem);
                    vector = try self.wip.insertElement(vector, llvm_elem, index_u32, "");
                }
                return vector;
            },
            .@"struct" => {
                if (zcu.typeToPackedStruct(result_ty)) |struct_type| {
                    const backing_int_ty = struct_type.backingIntTypeUnordered(ip);
                    assert(backing_int_ty != .none);
                    const big_bits = Type.fromInterned(backing_int_ty).bitSize(zcu);
                    const int_ty = try o.builder.intType(@intCast(big_bits));
                    comptime assert(Type.packed_struct_layout_version == 2);
                    var running_int = try o.builder.intValue(int_ty, 0);
                    var running_bits: u16 = 0;
                    for (elements, struct_type.field_types.get(ip)) |elem, field_ty| {
                        if (!Type.fromInterned(field_ty).hasRuntimeBitsIgnoreComptime(zcu)) continue;

                        const non_int_val = try self.resolveInst(elem);
                        const ty_bit_size: u16 = @intCast(Type.fromInterned(field_ty).bitSize(zcu));
                        const small_int_ty = try o.builder.intType(ty_bit_size);
                        const small_int_val = if (Type.fromInterned(field_ty).isPtrAtRuntime(zcu))
                            try self.wip.cast(.ptrtoint, non_int_val, small_int_ty, "")
                        else
                            try self.wip.cast(.bitcast, non_int_val, small_int_ty, "");
                        const shift_rhs = try o.builder.intValue(int_ty, running_bits);
                        const extended_int_val =
                            try self.wip.conv(.unsigned, small_int_val, int_ty, "");
                        const shifted = try self.wip.bin(.shl, extended_int_val, shift_rhs, "");
                        running_int = try self.wip.bin(.@"or", running_int, shifted, "");
                        running_bits += ty_bit_size;
                    }
                    return running_int;
                }

                assert(result_ty.containerLayout(zcu) != .@"packed");

                if (isByRef(result_ty, zcu)) {
                    // TODO in debug builds init to undef so that the padding will be 0xaa
                    // even if we fully populate the fields.
                    const alignment = result_ty.abiAlignment(zcu).toLlvm();
                    const alloca_inst = try self.buildAlloca(llvm_result_ty, alignment);

                    for (elements, 0..) |elem, i| {
                        if ((try result_ty.structFieldValueComptime(pt, i)) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = o.llvmFieldIndex(result_ty, i).?;
                        const field_ptr =
                            try self.wip.gepStruct(llvm_result_ty, alloca_inst, llvm_i, "");
                        const field_ptr_ty = try pt.ptrType(.{
                            .child = self.typeOf(elem).toIntern(),
                            .flags = .{
                                .alignment = result_ty.fieldAlignment(i, zcu),
                            },
                        });
                        try self.store(field_ptr, field_ptr_ty, llvm_elem, .none);
                    }

                    return alloca_inst;
                } else {
                    var result = try o.builder.poisonValue(llvm_result_ty);
                    for (elements, 0..) |elem, i| {
                        if ((try result_ty.structFieldValueComptime(pt, i)) != null) continue;

                        const llvm_elem = try self.resolveInst(elem);
                        const llvm_i = o.llvmFieldIndex(result_ty, i).?;
                        result = try self.wip.insertValue(result, llvm_elem, &.{llvm_i}, "");
                    }
                    return result;
                }
            },
            .array => {
                assert(isByRef(result_ty, zcu));

                const llvm_usize = try o.lowerType(pt, Type.usize);
                const usize_zero = try o.builder.intValue(llvm_usize, 0);
                const alignment = result_ty.abiAlignment(zcu).toLlvm();
                const alloca_inst = try self.buildAlloca(llvm_result_ty, alignment);

                const array_info = result_ty.arrayInfo(zcu);
                const elem_ptr_ty = try pt.ptrType(.{
                    .child = array_info.elem_type.toIntern(),
                });

                for (elements, 0..) |elem, i| {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_result_ty, alloca_inst, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, i),
                    }, "");
                    const llvm_elem = try self.resolveInst(elem);
                    try self.store(elem_ptr, elem_ptr_ty, llvm_elem, .none);
                }
                if (array_info.sentinel) |sent_val| {
                    const elem_ptr = try self.wip.gep(.inbounds, llvm_result_ty, alloca_inst, &.{
                        usize_zero, try o.builder.intValue(llvm_usize, array_info.len),
                    }, "");
                    const llvm_elem = try self.resolveValue(sent_val);
                    try self.store(elem_ptr, elem_ptr_ty, llvm_elem.toValue(), .none);
                }

                return alloca_inst;
            },
            else => unreachable,
        }
    }

    fn airUnionInit(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
        const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
        const union_ty = self.typeOfIndex(inst);
        const union_llvm_ty = try o.lowerType(pt, union_ty);
        const layout = union_ty.unionGetLayout(zcu);
        const union_obj = zcu.typeToUnion(union_ty).?;

        if (union_obj.flagsUnordered(ip).layout == .@"packed") {
            const big_bits = union_ty.bitSize(zcu);
            const int_llvm_ty = try o.builder.intType(@intCast(big_bits));
            const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
            const non_int_val = try self.resolveInst(extra.init);
            const small_int_ty = try o.builder.intType(@intCast(field_ty.bitSize(zcu)));
            const small_int_val = if (field_ty.isPtrAtRuntime(zcu))
                try self.wip.cast(.ptrtoint, non_int_val, small_int_ty, "")
            else
                try self.wip.cast(.bitcast, non_int_val, small_int_ty, "");
            return self.wip.conv(.unsigned, small_int_val, int_llvm_ty, "");
        }

        const tag_int_val = blk: {
            const tag_ty = union_ty.unionTagTypeHypothetical(zcu);
            const union_field_name = union_obj.loadTagType(ip).names.get(ip)[extra.field_index];
            const enum_field_index = tag_ty.enumFieldIndex(union_field_name, zcu).?;
            const tag_val = try pt.enumValueFieldIndex(tag_ty, enum_field_index);
            break :blk try tag_val.intFromEnum(tag_ty, pt);
        };
        if (layout.payload_size == 0) {
            if (layout.tag_size == 0) {
                return .none;
            }
            assert(!isByRef(union_ty, zcu));
            var big_int_space: Value.BigIntSpace = undefined;
            const tag_big_int = tag_int_val.toBigInt(&big_int_space, zcu);
            return try o.builder.bigIntValue(union_llvm_ty, tag_big_int);
        }
        assert(isByRef(union_ty, zcu));
        // The llvm type of the alloca will be the named LLVM union type, and will not
        // necessarily match the format that we need, depending on which tag is active.
        // We must construct the correct unnamed struct type here, in order to then set
        // the fields appropriately.
        const alignment = layout.abi_align.toLlvm();
        const result_ptr = try self.buildAlloca(union_llvm_ty, alignment);
        const llvm_payload = try self.resolveInst(extra.init);
        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
        const field_llvm_ty = try o.lowerType(pt, field_ty);
        const field_size = field_ty.abiSize(zcu);
        const field_align = union_ty.fieldAlignment(extra.field_index, zcu);
        const llvm_usize = try o.lowerType(pt, Type.usize);
        const usize_zero = try o.builder.intValue(llvm_usize, 0);

        const llvm_union_ty = t: {
            const payload_ty = p: {
                if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    const padding_len = layout.payload_size;
                    break :p try o.builder.arrayType(padding_len, .i8);
                }
                if (field_size == layout.payload_size) {
                    break :p field_llvm_ty;
                }
                const padding_len = layout.payload_size - field_size;
                break :p try o.builder.structType(.@"packed", &.{
                    field_llvm_ty, try o.builder.arrayType(padding_len, .i8),
                });
            };
            if (layout.tag_size == 0) break :t try o.builder.structType(.normal, &.{payload_ty});
            const tag_ty = try o.lowerType(pt, Type.fromInterned(union_obj.enum_tag_ty));
            var fields: [3]Builder.Type = undefined;
            var fields_len: usize = 2;
            if (layout.tag_align.compare(.gte, layout.payload_align)) {
                fields = .{ tag_ty, payload_ty, undefined };
            } else {
                fields = .{ payload_ty, tag_ty, undefined };
            }
            if (layout.padding != 0) {
                fields[fields_len] = try o.builder.arrayType(layout.padding, .i8);
                fields_len += 1;
            }
            break :t try o.builder.structType(.normal, fields[0..fields_len]);
        };

        // Now we follow the layout as expressed above with GEP instructions to set the
        // tag and the payload.
        const field_ptr_ty = try pt.ptrType(.{
            .child = field_ty.toIntern(),
            .flags = .{ .alignment = field_align },
        });
        if (layout.tag_size == 0) {
            const indices = [3]Builder.Value{ usize_zero, .@"0", .@"0" };
            const len: usize = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr =
                try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, indices[0..len], "");
            try self.store(field_ptr, field_ptr_ty, llvm_payload, .none);
            return result_ptr;
        }

        {
            const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
            const indices: [3]Builder.Value = .{ usize_zero, try o.builder.intValue(.i32, payload_index), .@"0" };
            const len: usize = if (field_size == layout.payload_size) 2 else 3;
            const field_ptr = try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, indices[0..len], "");
            try self.store(field_ptr, field_ptr_ty, llvm_payload, .none);
        }
        {
            const tag_index = @intFromBool(layout.tag_align.compare(.lt, layout.payload_align));
            const indices: [2]Builder.Value = .{ usize_zero, try o.builder.intValue(.i32, tag_index) };
            const field_ptr = try self.wip.gep(.inbounds, llvm_union_ty, result_ptr, &indices, "");
            const tag_ty = try o.lowerType(pt, Type.fromInterned(union_obj.enum_tag_ty));
            var big_int_space: Value.BigIntSpace = undefined;
            const tag_big_int = tag_int_val.toBigInt(&big_int_space, zcu);
            const llvm_tag = try o.builder.bigIntValue(tag_ty, tag_big_int);
            const tag_alignment = Type.fromInterned(union_obj.enum_tag_ty).abiAlignment(zcu).toLlvm();
            _ = try self.wip.store(.normal, llvm_tag, field_ptr, tag_alignment);
        }

        return result_ptr;
    }

    fn airPrefetch(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;

        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Rw.read) == 0);
        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Rw.write) == 1);

        // TODO these two asserts should be able to be comptime because the type is a u2
        assert(prefetch.locality >= 0);
        assert(prefetch.locality <= 3);

        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Cache.instruction) == 0);
        comptime assert(@intFromEnum(std.builtin.PrefetchOptions.Cache.data) == 1);

        // LLVM fails during codegen of instruction cache prefetchs for these architectures.
        // This is an LLVM bug as the prefetch intrinsic should be a noop if not supported
        // by the target.
        // To work around this, don't emit llvm.prefetch in this case.
        // See https://bugs.llvm.org/show_bug.cgi?id=21037
        const zcu = self.ng.pt.zcu;
        const target = zcu.getTarget();
        switch (prefetch.cache) {
            .instruction => switch (target.cpu.arch) {
                .x86_64,
                .x86,
                .powerpc,
                .powerpcle,
                .powerpc64,
                .powerpc64le,
                => return .none,
                .arm, .armeb, .thumb, .thumbeb => {
                    switch (prefetch.rw) {
                        .write => return .none,
                        else => {},
                    }
                },
                else => {},
            },
            .data => {},
        }

        _ = try self.wip.callIntrinsic(.normal, .none, .prefetch, &.{.ptr}, &.{
            try self.sliceOrArrayPtr(try self.resolveInst(prefetch.ptr), self.typeOf(prefetch.ptr)),
            try o.builder.intValue(.i32, prefetch.rw),
            try o.builder.intValue(.i32, prefetch.locality),
            try o.builder.intValue(.i32, prefetch.cache),
        }, "");
        return .none;
    }

    fn airAddrSpaceCast(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
        const inst_ty = self.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);

        return self.wip.cast(.addrspacecast, operand, try o.lowerType(pt, inst_ty), "");
    }

    fn workIntrinsic(
        self: *FuncGen,
        dimension: u32,
        default: u32,
        comptime basename: []const u8,
    ) !Builder.Value {
        return self.wip.callIntrinsic(.normal, .none, switch (dimension) {
            0 => @field(Builder.Intrinsic, basename ++ ".x"),
            1 => @field(Builder.Intrinsic, basename ++ ".y"),
            2 => @field(Builder.Intrinsic, basename ++ ".z"),
            else => return self.ng.object.builder.intValue(.i32, default),
        }, &.{}, &.{}, "");
    }

    fn airWorkItemId(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const target = self.ng.pt.zcu.getTarget();

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;

        return switch (target.cpu.arch) {
            .amdgcn => self.workIntrinsic(dimension, 0, "amdgcn.workitem.id"),
            .nvptx, .nvptx64 => self.workIntrinsic(dimension, 0, "nvvm.read.ptx.sreg.tid"),
            else => unreachable,
        };
    }

    fn airWorkGroupSize(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const target = pt.zcu.getTarget();

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;

        switch (target.cpu.arch) {
            .amdgcn => {
                if (dimension >= 3) return .@"1";

                // Fetch the dispatch pointer, which points to this structure:
                // https://github.com/RadeonOpenCompute/ROCR-Runtime/blob/adae6c61e10d371f7cbc3d0e94ae2c070cab18a4/src/inc/hsa.h#L2913
                const dispatch_ptr =
                    try self.wip.callIntrinsic(.normal, .none, .@"amdgcn.dispatch.ptr", &.{}, &.{}, "");

                // Load the work_group_* member from the struct as u16.
                // Just treat the dispatch pointer as an array of u16 to keep things simple.
                const workgroup_size_ptr = try self.wip.gep(.inbounds, .i16, dispatch_ptr, &.{
                    try o.builder.intValue(try o.lowerType(pt, Type.usize), 2 + dimension),
                }, "");
                const workgroup_size_alignment = comptime Builder.Alignment.fromByteUnits(2);
                return self.wip.load(.normal, .i16, workgroup_size_ptr, workgroup_size_alignment, "");
            },
            .nvptx, .nvptx64 => {
                return self.workIntrinsic(dimension, 1, "nvvm.read.ptx.sreg.ntid");
            },
            else => unreachable,
        }
    }

    fn airWorkGroupId(self: *FuncGen, inst: Air.Inst.Index) !Builder.Value {
        const target = self.ng.pt.zcu.getTarget();

        const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
        const dimension = pl_op.payload;

        return switch (target.cpu.arch) {
            .amdgcn => self.workIntrinsic(dimension, 0, "amdgcn.workgroup.id"),
            .nvptx, .nvptx64 => self.workIntrinsic(dimension, 0, "nvvm.read.ptx.sreg.ctaid"),
            else => unreachable,
        };
    }

    fn getErrorNameTable(self: *FuncGen) Allocator.Error!Builder.Variable.Index {
        const o = self.ng.object;
        const pt = self.ng.pt;

        const table = o.error_name_table;
        if (table != .none) return table;

        // TODO: Address space
        const variable_index =
            try o.builder.addVariable(try o.builder.strtabString("__zig_err_name_table"), .ptr, .default);
        variable_index.setLinkage(.private, &o.builder);
        variable_index.setMutability(.constant, &o.builder);
        variable_index.setUnnamedAddr(.unnamed_addr, &o.builder);
        variable_index.setAlignment(
            Type.slice_const_u8_sentinel_0.abiAlignment(pt.zcu).toLlvm(),
            &o.builder,
        );

        o.error_name_table = variable_index;
        return variable_index;
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optCmpNull(
        self: *FuncGen,
        cond: Builder.IntegerCondition,
        opt_llvm_ty: Builder.Type,
        opt_handle: Builder.Value,
        is_by_ref: bool,
        access_kind: Builder.MemoryAccessKind,
    ) Allocator.Error!Builder.Value {
        const o = self.ng.object;
        const field = b: {
            if (is_by_ref) {
                const field_ptr = try self.wip.gepStruct(opt_llvm_ty, opt_handle, 1, "");
                break :b try self.wip.load(access_kind, .i8, field_ptr, .default, "");
            }
            break :b try self.wip.extractValue(opt_handle, &.{1}, "");
        };
        comptime assert(optional_layout_version == 3);

        return self.wip.icmp(cond, field, try o.builder.intValue(.i8, 0), "");
    }

    /// Assumes the optional is not pointer-like and payload has bits.
    fn optPayloadHandle(
        fg: *FuncGen,
        opt_llvm_ty: Builder.Type,
        opt_handle: Builder.Value,
        opt_ty: Type,
        can_elide_load: bool,
    ) !Builder.Value {
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const payload_ty = opt_ty.optionalChild(zcu);

        if (isByRef(opt_ty, zcu)) {
            // We have a pointer and we need to return a pointer to the first field.
            const payload_ptr = try fg.wip.gepStruct(opt_llvm_ty, opt_handle, 0, "");

            const payload_alignment = payload_ty.abiAlignment(zcu).toLlvm();
            if (isByRef(payload_ty, zcu)) {
                if (can_elide_load)
                    return payload_ptr;

                return fg.loadByRef(payload_ptr, payload_ty, payload_alignment, .normal);
            }
            return fg.loadTruncate(.normal, payload_ty, payload_ptr, payload_alignment);
        }

        assert(!isByRef(payload_ty, zcu));
        return fg.wip.extractValue(opt_handle, &.{0}, "");
    }

    fn buildOptional(
        self: *FuncGen,
        optional_ty: Type,
        payload: Builder.Value,
        non_null_bit: Builder.Value,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const optional_llvm_ty = try o.lowerType(pt, optional_ty);
        const non_null_field = try self.wip.cast(.zext, non_null_bit, .i8, "");

        if (isByRef(optional_ty, zcu)) {
            const payload_alignment = optional_ty.abiAlignment(pt.zcu).toLlvm();
            const alloca_inst = try self.buildAlloca(optional_llvm_ty, payload_alignment);

            {
                const field_ptr = try self.wip.gepStruct(optional_llvm_ty, alloca_inst, 0, "");
                _ = try self.wip.store(.normal, payload, field_ptr, payload_alignment);
            }
            {
                const non_null_alignment = comptime Builder.Alignment.fromByteUnits(1);
                const field_ptr = try self.wip.gepStruct(optional_llvm_ty, alloca_inst, 1, "");
                _ = try self.wip.store(.normal, non_null_field, field_ptr, non_null_alignment);
            }

            return alloca_inst;
        }

        return self.wip.buildAggregate(optional_llvm_ty, &.{ payload, non_null_field }, "");
    }

    fn fieldPtr(
        self: *FuncGen,
        inst: Air.Inst.Index,
        struct_ptr: Builder.Value,
        struct_ptr_ty: Type,
        field_index: u32,
    ) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const struct_ty = struct_ptr_ty.childType(zcu);
        switch (struct_ty.zigTypeTag(zcu)) {
            .@"struct" => switch (struct_ty.containerLayout(zcu)) {
                .@"packed" => {
                    const result_ty = self.typeOfIndex(inst);
                    const result_ty_info = result_ty.ptrInfo(zcu);
                    const struct_ptr_ty_info = struct_ptr_ty.ptrInfo(zcu);
                    const struct_type = zcu.typeToStruct(struct_ty).?;

                    if (result_ty_info.packed_offset.host_size != 0) {
                        // From LLVM's perspective, a pointer to a packed struct and a pointer
                        // to a field of a packed struct are the same. The difference is in the
                        // Zig pointer type which provides information for how to mask and shift
                        // out the relevant bits when accessing the pointee.
                        return struct_ptr;
                    }

                    // We have a pointer to a packed struct field that happens to be byte-aligned.
                    // Offset our operand pointer by the correct number of bytes.
                    const byte_offset = @divExact(zcu.structPackedFieldBitOffset(struct_type, field_index) + struct_ptr_ty_info.packed_offset.bit_offset, 8);
                    if (byte_offset == 0) return struct_ptr;
                    const usize_ty = try o.lowerType(pt, Type.usize);
                    const llvm_index = try o.builder.intValue(usize_ty, byte_offset);
                    return self.wip.gep(.inbounds, .i8, struct_ptr, &.{llvm_index}, "");
                },
                else => {
                    const struct_llvm_ty = try o.lowerPtrElemTy(pt, struct_ty);

                    if (o.llvmFieldIndex(struct_ty, field_index)) |llvm_field_index| {
                        return self.wip.gepStruct(struct_llvm_ty, struct_ptr, llvm_field_index, "");
                    } else {
                        // If we found no index then this means this is a zero sized field at the
                        // end of the struct. Treat our struct pointer as an array of two and get
                        // the index to the element at index `1` to get a pointer to the end of
                        // the struct.
                        const llvm_index = try o.builder.intValue(
                            try o.lowerType(pt, Type.usize),
                            @intFromBool(struct_ty.hasRuntimeBitsIgnoreComptime(zcu)),
                        );
                        return self.wip.gep(.inbounds, struct_llvm_ty, struct_ptr, &.{llvm_index}, "");
                    }
                },
            },
            .@"union" => {
                const layout = struct_ty.unionGetLayout(zcu);
                if (layout.payload_size == 0 or struct_ty.containerLayout(zcu) == .@"packed") return struct_ptr;
                const payload_index = @intFromBool(layout.tag_align.compare(.gte, layout.payload_align));
                const union_llvm_ty = try o.lowerType(pt, struct_ty);
                return self.wip.gepStruct(union_llvm_ty, struct_ptr, payload_index, "");
            },
            else => unreachable,
        }
    }

    /// Load a value and, if needed, mask out padding bits for non byte-sized integer values.
    fn loadTruncate(
        fg: *FuncGen,
        access_kind: Builder.MemoryAccessKind,
        payload_ty: Type,
        payload_ptr: Builder.Value,
        payload_alignment: Builder.Alignment,
    ) !Builder.Value {
        // from https://llvm.org/docs/LangRef.html#load-instruction :
        // "When loading a value of a type like i20 with a size that is not an integral number of bytes, the result is undefined if the value was not originally written using a store of the same type. "
        // => so load the byte aligned value and trunc the unwanted bits.

        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const payload_llvm_ty = try o.lowerType(pt, payload_ty);
        const abi_size = payload_ty.abiSize(zcu);

        // llvm bug workarounds:
        const workaround_explicit_mask = o.target.cpu.arch == .powerpc and abi_size >= 4;
        const workaround_disable_truncate = o.target.cpu.arch == .wasm32 and abi_size >= 4;

        if (workaround_disable_truncate) {
            // see https://github.com/llvm/llvm-project/issues/64222
            // disable the truncation codepath for larger than 32bits value - with this heuristic, the backend passes the test suite.
            return try fg.wip.load(access_kind, payload_llvm_ty, payload_ptr, payload_alignment, "");
        }

        const load_llvm_ty = if (payload_ty.isAbiInt(zcu))
            try o.builder.intType(@intCast(abi_size * 8))
        else
            payload_llvm_ty;
        const loaded = try fg.wip.load(access_kind, load_llvm_ty, payload_ptr, payload_alignment, "");
        const shifted = if (payload_llvm_ty != load_llvm_ty and o.target.cpu.arch.endian() == .big)
            try fg.wip.bin(.lshr, loaded, try o.builder.intValue(
                load_llvm_ty,
                (payload_ty.abiSize(zcu) - (std.math.divCeil(u64, payload_ty.bitSize(zcu), 8) catch unreachable)) * 8,
            ), "")
        else
            loaded;

        const anded = if (workaround_explicit_mask and payload_llvm_ty != load_llvm_ty) blk: {
            // this is rendundant with llvm.trunc. But without it, llvm17 emits invalid code for powerpc.
            const mask_val = try o.builder.intValue(payload_llvm_ty, -1);
            const zext_mask_val = try fg.wip.cast(.zext, mask_val, load_llvm_ty, "");
            break :blk try fg.wip.bin(.@"and", shifted, zext_mask_val, "");
        } else shifted;

        return fg.wip.conv(.unneeded, anded, payload_llvm_ty, "");
    }

    /// Load a by-ref type by constructing a new alloca and performing a memcpy.
    fn loadByRef(
        fg: *FuncGen,
        ptr: Builder.Value,
        pointee_type: Type,
        ptr_alignment: Builder.Alignment,
        access_kind: Builder.MemoryAccessKind,
    ) !Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const pointee_llvm_ty = try o.lowerType(pt, pointee_type);
        const result_align = InternPool.Alignment.fromLlvm(ptr_alignment)
            .max(pointee_type.abiAlignment(pt.zcu)).toLlvm();
        const result_ptr = try fg.buildAlloca(pointee_llvm_ty, result_align);
        const size_bytes = pointee_type.abiSize(pt.zcu);
        _ = try fg.wip.callMemCpy(
            result_ptr,
            result_align,
            ptr,
            ptr_alignment,
            try o.builder.intValue(try o.lowerType(pt, Type.usize), size_bytes),
            access_kind,
            fg.disable_intrinsics,
        );
        return result_ptr;
    }

    /// This function always performs a copy. For isByRef=true types, it creates a new
    /// alloca and copies the value into it, then returns the alloca instruction.
    /// For isByRef=false types, it creates a load instruction and returns it.
    fn load(self: *FuncGen, ptr: Builder.Value, ptr_ty: Type) !Builder.Value {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const info = ptr_ty.ptrInfo(zcu);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.hasRuntimeBitsIgnoreComptime(zcu)) return .none;

        const ptr_alignment = (if (info.flags.alignment != .none)
            @as(InternPool.Alignment, info.flags.alignment)
        else
            elem_ty.abiAlignment(zcu)).toLlvm();

        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;

        assert(info.flags.vector_index != .runtime);
        if (info.flags.vector_index != .none) {
            const index_u32 = try o.builder.intValue(.i32, info.flags.vector_index);
            const vec_elem_ty = try o.lowerType(pt, elem_ty);
            const vec_ty = try o.builder.vectorType(.normal, info.packed_offset.host_size, vec_elem_ty);

            const loaded_vector = try self.wip.load(access_kind, vec_ty, ptr, ptr_alignment, "");
            return self.wip.extractElement(loaded_vector, index_u32, "");
        }

        if (info.packed_offset.host_size == 0) {
            if (isByRef(elem_ty, zcu)) {
                return self.loadByRef(ptr, elem_ty, ptr_alignment, access_kind);
            }
            return self.loadTruncate(access_kind, elem_ty, ptr, ptr_alignment);
        }

        const containing_int_ty = try o.builder.intType(@intCast(info.packed_offset.host_size * 8));
        const containing_int =
            try self.wip.load(access_kind, containing_int_ty, ptr, ptr_alignment, "");

        const elem_bits = ptr_ty.childType(zcu).bitSize(zcu);
        const shift_amt = try o.builder.intValue(containing_int_ty, info.packed_offset.bit_offset);
        const shifted_value = try self.wip.bin(.lshr, containing_int, shift_amt, "");
        const elem_llvm_ty = try o.lowerType(pt, elem_ty);

        if (isByRef(elem_ty, zcu)) {
            const result_align = elem_ty.abiAlignment(zcu).toLlvm();
            const result_ptr = try self.buildAlloca(elem_llvm_ty, result_align);

            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            _ = try self.wip.store(.normal, truncated_int, result_ptr, result_align);
            return result_ptr;
        }

        if (elem_ty.zigTypeTag(zcu) == .float or elem_ty.zigTypeTag(zcu) == .vector) {
            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            return self.wip.cast(.bitcast, truncated_int, elem_llvm_ty, "");
        }

        if (elem_ty.isPtrAtRuntime(zcu)) {
            const same_size_int = try o.builder.intType(@intCast(elem_bits));
            const truncated_int = try self.wip.cast(.trunc, shifted_value, same_size_int, "");
            return self.wip.cast(.inttoptr, truncated_int, elem_llvm_ty, "");
        }

        return self.wip.cast(.trunc, shifted_value, elem_llvm_ty, "");
    }

    fn store(
        self: *FuncGen,
        ptr: Builder.Value,
        ptr_ty: Type,
        elem: Builder.Value,
        ordering: Builder.AtomicOrdering,
    ) !void {
        const o = self.ng.object;
        const pt = self.ng.pt;
        const zcu = pt.zcu;
        const info = ptr_ty.ptrInfo(zcu);
        const elem_ty = Type.fromInterned(info.child);
        if (!elem_ty.isFnOrHasRuntimeBitsIgnoreComptime(zcu)) {
            return;
        }
        const ptr_alignment = ptr_ty.ptrAlignment(zcu).toLlvm();
        const access_kind: Builder.MemoryAccessKind =
            if (info.flags.is_volatile) .@"volatile" else .normal;

        assert(info.flags.vector_index != .runtime);
        if (info.flags.vector_index != .none) {
            const index_u32 = try o.builder.intValue(.i32, info.flags.vector_index);
            const vec_elem_ty = try o.lowerType(pt, elem_ty);
            const vec_ty = try o.builder.vectorType(.normal, info.packed_offset.host_size, vec_elem_ty);

            const loaded_vector = try self.wip.load(.normal, vec_ty, ptr, ptr_alignment, "");

            const modified_vector = try self.wip.insertElement(loaded_vector, elem, index_u32, "");

            assert(ordering == .none);
            _ = try self.wip.store(access_kind, modified_vector, ptr, ptr_alignment);
            return;
        }

        if (info.packed_offset.host_size != 0) {
            const containing_int_ty = try o.builder.intType(@intCast(info.packed_offset.host_size * 8));
            assert(ordering == .none);
            const containing_int =
                try self.wip.load(.normal, containing_int_ty, ptr, ptr_alignment, "");
            const elem_bits = ptr_ty.childType(zcu).bitSize(zcu);
            const shift_amt = try o.builder.intConst(containing_int_ty, info.packed_offset.bit_offset);
            // Convert to equally-sized integer type in order to perform the bit
            // operations on the value to store
            const value_bits_type = try o.builder.intType(@intCast(elem_bits));
            const value_bits = if (elem_ty.isPtrAtRuntime(zcu))
                try self.wip.cast(.ptrtoint, elem, value_bits_type, "")
            else
                try self.wip.cast(.bitcast, elem, value_bits_type, "");

            const mask_val = blk: {
                const zext = try self.wip.cast(
                    .zext,
                    try o.builder.intValue(value_bits_type, -1),
                    containing_int_ty,
                    "",
                );
                const shl = try self.wip.bin(.shl, zext, shift_amt.toValue(), "");
                break :blk try self.wip.bin(
                    .xor,
                    shl,
                    try o.builder.intValue(containing_int_ty, -1),
                    "",
                );
            };

            const anded_containing_int = try self.wip.bin(.@"and", containing_int, mask_val, "");
            const extended_value = try self.wip.cast(.zext, value_bits, containing_int_ty, "");
            const shifted_value = try self.wip.bin(.shl, extended_value, shift_amt.toValue(), "");
            const ored_value = try self.wip.bin(.@"or", shifted_value, anded_containing_int, "");

            assert(ordering == .none);
            _ = try self.wip.store(access_kind, ored_value, ptr, ptr_alignment);
            return;
        }
        if (!isByRef(elem_ty, zcu)) {
            _ = try self.wip.storeAtomic(
                access_kind,
                elem,
                ptr,
                self.sync_scope,
                ordering,
                ptr_alignment,
            );
            return;
        }
        assert(ordering == .none);
        _ = try self.wip.callMemCpy(
            ptr,
            ptr_alignment,
            elem,
            elem_ty.abiAlignment(zcu).toLlvm(),
            try o.builder.intValue(try o.lowerType(pt, Type.usize), elem_ty.abiSize(zcu)),
            access_kind,
            self.disable_intrinsics,
        );
    }

    fn valgrindMarkUndef(fg: *FuncGen, ptr: Builder.Value, len: Builder.Value) Allocator.Error!void {
        const VG_USERREQ__MAKE_MEM_UNDEFINED = 1296236545;
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const usize_ty = try o.lowerType(pt, Type.usize);
        const zero = try o.builder.intValue(usize_ty, 0);
        const req = try o.builder.intValue(usize_ty, VG_USERREQ__MAKE_MEM_UNDEFINED);
        const ptr_as_usize = try fg.wip.cast(.ptrtoint, ptr, usize_ty, "");
        _ = try valgrindClientRequest(fg, zero, req, ptr_as_usize, len, zero, zero, zero);
    }

    fn valgrindClientRequest(
        fg: *FuncGen,
        default_value: Builder.Value,
        request: Builder.Value,
        a1: Builder.Value,
        a2: Builder.Value,
        a3: Builder.Value,
        a4: Builder.Value,
        a5: Builder.Value,
    ) Allocator.Error!Builder.Value {
        const o = fg.ng.object;
        const pt = fg.ng.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();
        if (!target_util.hasValgrindSupport(target, .stage2_llvm)) return default_value;

        const llvm_usize = try o.lowerType(pt, Type.usize);
        const usize_alignment = Type.usize.abiAlignment(zcu).toLlvm();

        const array_llvm_ty = try o.builder.arrayType(6, llvm_usize);
        const array_ptr = if (fg.valgrind_client_request_array == .none) a: {
            const array_ptr = try fg.buildAlloca(array_llvm_ty, usize_alignment);
            fg.valgrind_client_request_array = array_ptr;
            break :a array_ptr;
        } else fg.valgrind_client_request_array;
        const array_elements = [_]Builder.Value{ request, a1, a2, a3, a4, a5 };
        const zero = try o.builder.intValue(llvm_usize, 0);
        for (array_elements, 0..) |elem, i| {
            const elem_ptr = try fg.wip.gep(.inbounds, array_llvm_ty, array_ptr, &.{
                zero, try o.builder.intValue(llvm_usize, i),
            }, "");
            _ = try fg.wip.store(.normal, elem, elem_ptr, usize_alignment);
        }

        const arch_specific: struct {
            template: [:0]const u8,
            constraints: [:0]const u8,
        } = switch (target.cpu.arch) {
            .arm, .armeb, .thumb, .thumbeb => .{
                .template =
                \\ mov r12, r12, ror #3  ; mov r12, r12, ror #13
                \\ mov r12, r12, ror #29 ; mov r12, r12, ror #19
                \\ orr r10, r10, r10
                ,
                .constraints = "={r3},{r4},{r3},~{cc},~{memory}",
            },
            .aarch64, .aarch64_be => .{
                .template =
                \\ ror x12, x12, #3  ; ror x12, x12, #13
                \\ ror x12, x12, #51 ; ror x12, x12, #61
                \\ orr x10, x10, x10
                ,
                .constraints = "={x3},{x4},{x3},~{cc},~{memory}",
            },
            .mips, .mipsel => .{
                .template =
                \\ srl $$0,  $$0,  13
                \\ srl $$0,  $$0,  29
                \\ srl $$0,  $$0,  3
                \\ srl $$0,  $$0,  19
                \\ or  $$13, $$13, $$13
                ,
                .constraints = "={$11},{$12},{$11},~{memory}",
            },
            .mips64, .mips64el => .{
                .template =
                \\ dsll $$0,  $$0,  3    ; dsll $$0, $$0, 13
                \\ dsll $$0,  $$0,  29   ; dsll $$0, $$0, 19
                \\ or   $$13, $$13, $$13
                ,
                .constraints = "={$11},{$12},{$11},~{memory}",
            },
            .powerpc, .powerpcle => .{
                .template =
                \\ rlwinm 0, 0, 3,  0, 31 ; rlwinm 0, 0, 13, 0, 31
                \\ rlwinm 0, 0, 29, 0, 31 ; rlwinm 0, 0, 19, 0, 31
                \\ or     1, 1, 1
                ,
                .constraints = "={r3},{r4},{r3},~{cc},~{memory}",
            },
            .powerpc64, .powerpc64le => .{
                .template =
                \\ rotldi 0, 0, 3  ; rotldi 0, 0, 13
                \\ rotldi 0, 0, 61 ; rotldi 0, 0, 51
                \\ or     1, 1, 1
                ,
                .constraints = "={r3},{r4},{r3},~{cc},~{memory}",
            },
            .riscv64 => .{
                .template =
                \\ .option push
                \\ .option norvc
                \\ srli zero, zero, 3
                \\ srli zero, zero, 13
                \\ srli zero, zero, 51
                \\ srli zero, zero, 61
                \\ or   a0,   a0,   a0
                \\ .option pop
                ,
                .constraints = "={a3},{a4},{a3},~{cc},~{memory}",
            },
            .s390x => .{
                .template =
                \\ lr %r15, %r15
                \\ lr %r1,  %r1
                \\ lr %r2,  %r2
                \\ lr %r3,  %r3
                \\ lr %r2,  %r2
                ,
                .constraints = "={r3},{r2},{r3},~{cc},~{memory}",
            },
            .x86 => .{
                .template =
                \\ roll  $$3,  %edi ; roll $$13, %edi
                \\ roll  $$61, %edi ; roll $$51, %edi
                \\ xchgl %ebx, %ebx
                ,
                .constraints = "={edx},{eax},{edx},~{cc},~{memory}",
            },
            .x86_64 => .{
                .template =
                \\ rolq  $$3,  %rdi ; rolq $$13, %rdi
                \\ rolq  $$61, %rdi ; rolq $$51, %rdi
                \\ xchgq %rbx, %rbx
                ,
                .constraints = "={rdx},{rax},{edx},~{cc},~{memory}",
            },
            else => unreachable,
        };

        return fg.wip.callAsm(
            .none,
            try o.builder.fnType(llvm_usize, &.{ llvm_usize, llvm_usize }, .normal),
            .{ .sideeffect = true },
            try o.builder.string(arch_specific.template),
            try o.builder.string(arch_specific.constraints),
            &.{ try fg.wip.cast(.ptrtoint, array_ptr, llvm_usize, ""), default_value },
            "",
        );
    }

    fn typeOf(fg: *FuncGen, inst: Air.Inst.Ref) Type {
        const zcu = fg.ng.pt.zcu;
        return fg.air.typeOf(inst, &zcu.intern_pool);
    }

    fn typeOfIndex(fg: *FuncGen, inst: Air.Inst.Index) Type {
        const zcu = fg.ng.pt.zcu;
        return fg.air.typeOfIndex(inst, &zcu.intern_pool);
    }
};

fn toLlvmAtomicOrdering(atomic_order: std.builtin.AtomicOrder) Builder.AtomicOrdering {
    return switch (atomic_order) {
        .unordered => .unordered,
        .monotonic => .monotonic,
        .acquire => .acquire,
        .release => .release,
        .acq_rel => .acq_rel,
        .seq_cst => .seq_cst,
    };
}

fn toLlvmAtomicRmwBinOp(
    op: std.builtin.AtomicRmwOp,
    is_signed: bool,
    is_float: bool,
) Builder.Function.Instruction.AtomicRmw.Operation {
    return switch (op) {
        .Xchg => .xchg,
        .Add => if (is_float) .fadd else return .add,
        .Sub => if (is_float) .fsub else return .sub,
        .And => .@"and",
        .Nand => .nand,
        .Or => .@"or",
        .Xor => .xor,
        .Max => if (is_float) .fmax else if (is_signed) .max else return .umax,
        .Min => if (is_float) .fmin else if (is_signed) .min else return .umin,
    };
}

const CallingConventionInfo = struct {
    /// The LLVM calling convention to use.
    llvm_cc: Builder.CallConv,
    /// Whether to use an `alignstack` attribute to forcibly re-align the stack pointer in the function's prologue.
    align_stack: bool,
    /// Whether the function needs a `naked` attribute.
    naked: bool,
    /// How many leading parameters to apply the `inreg` attribute to.
    inreg_param_count: u2 = 0,
};

pub fn toLlvmCallConv(cc: std.builtin.CallingConvention, target: *const std.Target) ?CallingConventionInfo {
    const llvm_cc = toLlvmCallConvTag(cc, target) orelse return null;
    const incoming_stack_alignment: ?u64, const register_params: u2 = switch (cc) {
        inline else => |pl| switch (@TypeOf(pl)) {
            void => .{ null, 0 },
            std.builtin.CallingConvention.ArmInterruptOptions,
            std.builtin.CallingConvention.RiscvInterruptOptions,
            std.builtin.CallingConvention.MipsInterruptOptions,
            std.builtin.CallingConvention.CommonOptions,
            => .{ pl.incoming_stack_alignment, 0 },
            std.builtin.CallingConvention.X86RegparmOptions => .{ pl.incoming_stack_alignment, pl.register_params },
            else => @compileError("TODO: toLlvmCallConv" ++ @tagName(pl)),
        },
    };
    return .{
        .llvm_cc = llvm_cc,
        .align_stack = if (incoming_stack_alignment) |a| need_align: {
            const normal_stack_align = target.stackAlignment();
            break :need_align a < normal_stack_align;
        } else false,
        .naked = cc == .naked,
        .inreg_param_count = register_params,
    };
}
fn toLlvmCallConvTag(cc_tag: std.builtin.CallingConvention.Tag, target: *const std.Target) ?Builder.CallConv {
    if (target.cCallingConvention()) |default_c| {
        if (cc_tag == default_c) {
            return .ccc;
        }
    }
    return switch (cc_tag) {
        .@"inline" => unreachable,
        .auto, .async => .fastcc,
        .naked => .ccc,
        .x86_64_sysv => .x86_64_sysvcc,
        .x86_64_win => .win64cc,
        .x86_64_regcall_v3_sysv => if (target.cpu.arch == .x86_64 and target.os.tag != .windows)
            .x86_regcallcc
        else
            null,
        .x86_64_regcall_v4_win => if (target.cpu.arch == .x86_64 and target.os.tag == .windows)
            .x86_regcallcc // we use the "RegCallv4" module flag to make this correct
        else
            null,
        .x86_64_vectorcall => .x86_vectorcallcc,
        .x86_64_interrupt => .x86_intrcc,
        .x86_stdcall => .x86_stdcallcc,
        .x86_fastcall => .x86_fastcallcc,
        .x86_thiscall => .x86_thiscallcc,
        .x86_regcall_v3 => if (target.cpu.arch == .x86 and target.os.tag != .windows)
            .x86_regcallcc
        else
            null,
        .x86_regcall_v4_win => if (target.cpu.arch == .x86 and target.os.tag == .windows)
            .x86_regcallcc // we use the "RegCallv4" module flag to make this correct
        else
            null,
        .x86_vectorcall => .x86_vectorcallcc,
        .x86_interrupt => .x86_intrcc,
        .aarch64_vfabi => .aarch64_vector_pcs,
        .aarch64_vfabi_sve => .aarch64_sve_vector_pcs,
        .arm_aapcs => .arm_aapcscc,
        .arm_aapcs_vfp => .arm_aapcs_vfpcc,
        .riscv64_lp64_v => .riscv_vectorcallcc,
        .riscv32_ilp32_v => .riscv_vectorcallcc,
        .avr_builtin => .avr_builtincc,
        .avr_signal => .avr_signalcc,
        .avr_interrupt => .avr_intrcc,
        .m68k_rtd => .m68k_rtdcc,
        .m68k_interrupt => .m68k_intrcc,
        .amdgcn_kernel => .amdgpu_kernel,
        .amdgcn_cs => .amdgpu_cs,
        .nvptx_device => .ptx_device,
        .nvptx_kernel => .ptx_kernel,

        // Calling conventions which LLVM uses function attributes for.
        .riscv64_interrupt,
        .riscv32_interrupt,
        .arm_interrupt,
        .mips64_interrupt,
        .mips_interrupt,
        .csky_interrupt,
        => .ccc,

        // All the calling conventions which LLVM does not have a general representation for.
        // Note that these are often still supported through the `cCallingConvention` path above via `ccc`.
        .x86_sysv,
        .x86_win,
        .x86_thiscall_mingw,
        .aarch64_aapcs,
        .aarch64_aapcs_darwin,
        .aarch64_aapcs_win,
        .mips64_n64,
        .mips64_n32,
        .mips_o32,
        .riscv64_lp64,
        .riscv32_ilp32,
        .sparc64_sysv,
        .sparc_sysv,
        .powerpc64_elf,
        .powerpc64_elf_altivec,
        .powerpc64_elf_v2,
        .powerpc_sysv,
        .powerpc_sysv_altivec,
        .powerpc_aix,
        .powerpc_aix_altivec,
        .wasm_mvp,
        .arc_sysv,
        .avr_gnu,
        .bpf_std,
        .csky_sysv,
        .hexagon_sysv,
        .hexagon_sysv_hvx,
        .lanai_sysv,
        .loongarch64_lp64,
        .loongarch32_ilp32,
        .m68k_sysv,
        .m68k_gnu,
        .msp430_eabi,
        .or1k_sysv,
        .propeller_sysv,
        .s390x_sysv,
        .s390x_sysv_vx,
        .ve_sysv,
        .xcore_xs1,
        .xcore_xs2,
        .xtensa_call0,
        .xtensa_windowed,
        .amdgcn_device,
        .spirv_device,
        .spirv_kernel,
        .spirv_fragment,
        .spirv_vertex,
        => null,
    };
}

/// Convert a zig-address space to an llvm address space.
fn toLlvmAddressSpace(address_space: std.builtin.AddressSpace, target: *const std.Target) Builder.AddrSpace {
    for (llvmAddrSpaceInfo(target)) |info| if (info.zig == address_space) return info.llvm;
    unreachable;
}

const AddrSpaceInfo = struct {
    zig: ?std.builtin.AddressSpace,
    llvm: Builder.AddrSpace,
    non_integral: bool = false,
    size: ?u16 = null,
    abi: ?u16 = null,
    pref: ?u16 = null,
    idx: ?u16 = null,
    force_in_data_layout: bool = false,
};
fn llvmAddrSpaceInfo(target: *const std.Target) []const AddrSpaceInfo {
    return switch (target.cpu.arch) {
        .x86, .x86_64 => &.{
            .{ .zig = .generic, .llvm = .default },
            .{ .zig = .gs, .llvm = Builder.AddrSpace.x86.gs },
            .{ .zig = .fs, .llvm = Builder.AddrSpace.x86.fs },
            .{ .zig = .ss, .llvm = Builder.AddrSpace.x86.ss },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr32_sptr, .size = 32, .abi = 32, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr32_uptr, .size = 32, .abi = 32, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.x86.ptr64, .size = 64, .abi = 64, .force_in_data_layout = true },
        },
        .nvptx, .nvptx64 => &.{
            .{ .zig = .generic, .llvm = Builder.AddrSpace.nvptx.generic },
            .{ .zig = .global, .llvm = Builder.AddrSpace.nvptx.global },
            .{ .zig = .constant, .llvm = Builder.AddrSpace.nvptx.constant },
            .{ .zig = .param, .llvm = Builder.AddrSpace.nvptx.param },
            .{ .zig = .shared, .llvm = Builder.AddrSpace.nvptx.shared },
            .{ .zig = .local, .llvm = Builder.AddrSpace.nvptx.local },
        },
        .amdgcn => &.{
            .{ .zig = .generic, .llvm = Builder.AddrSpace.amdgpu.flat, .force_in_data_layout = true },
            .{ .zig = .global, .llvm = Builder.AddrSpace.amdgpu.global, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.region, .size = 32, .abi = 32 },
            .{ .zig = .shared, .llvm = Builder.AddrSpace.amdgpu.local, .size = 32, .abi = 32 },
            .{ .zig = .constant, .llvm = Builder.AddrSpace.amdgpu.constant, .force_in_data_layout = true },
            .{ .zig = .local, .llvm = Builder.AddrSpace.amdgpu.private, .size = 32, .abi = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_32bit, .size = 32, .abi = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.buffer_fat_pointer, .non_integral = true, .size = 160, .abi = 256, .idx = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.buffer_resource, .non_integral = true, .size = 128, .abi = 128 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.buffer_strided_pointer, .non_integral = true, .size = 192, .abi = 256, .idx = 32 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_0 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_1 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_2 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_3 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_4 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_5 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_6 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_7 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_8 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_9 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_10 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_11 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_12 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_13 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_14 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.constant_buffer_15 },
            .{ .zig = null, .llvm = Builder.AddrSpace.amdgpu.streamout_register },
        },
        .avr => &.{
            .{ .zig = .generic, .llvm = Builder.AddrSpace.avr.data, .abi = 8 },
            .{ .zig = .flash, .llvm = Builder.AddrSpace.avr.program, .abi = 8 },
            .{ .zig = .flash1, .llvm = Builder.AddrSpace.avr.program1, .abi = 8 },
            .{ .zig = .flash2, .llvm = Builder.AddrSpace.avr.program2, .abi = 8 },
            .{ .zig = .flash3, .llvm = Builder.AddrSpace.avr.program3, .abi = 8 },
            .{ .zig = .flash4, .llvm = Builder.AddrSpace.avr.program4, .abi = 8 },
            .{ .zig = .flash5, .llvm = Builder.AddrSpace.avr.program5, .abi = 8 },
        },
        .wasm32, .wasm64 => &.{
            .{ .zig = .generic, .llvm = Builder.AddrSpace.wasm.default, .force_in_data_layout = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.variable, .non_integral = true },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.externref, .non_integral = true, .size = 8, .abi = 8 },
            .{ .zig = null, .llvm = Builder.AddrSpace.wasm.funcref, .non_integral = true, .size = 8, .abi = 8 },
        },
        .m68k => &.{
            .{ .zig = .generic, .llvm = .default, .abi = 16, .pref = 32 },
        },
        else => &.{
            .{ .zig = .generic, .llvm = .default },
        },
    };
}

/// On some targets, local values that are in the generic address space must be generated into a
/// different address, space and then cast back to the generic address space.
/// For example, on GPUs local variable declarations must be generated into the local address space.
/// This function returns the address space local values should be generated into.
fn llvmAllocaAddressSpace(target: *const std.Target) Builder.AddrSpace {
    return switch (target.cpu.arch) {
        // On amdgcn, locals should be generated into the private address space.
        // To make Zig not impossible to use, these are then converted to addresses in the
        // generic address space and treates as regular pointers. This is the way that HIP also does it.
        .amdgcn => Builder.AddrSpace.amdgpu.private,
        else => .default,
    };
}

/// On some targets, global values that are in the generic address space must be generated into a
/// different address space, and then cast back to the generic address space.
fn llvmDefaultGlobalAddressSpace(target: *const std.Target) Builder.AddrSpace {
    return switch (target.cpu.arch) {
        // On amdgcn, globals must be explicitly allocated and uploaded so that the program can access
        // them.
        .amdgcn => Builder.AddrSpace.amdgpu.global,
        else => .default,
    };
}

/// Return the actual address space that a value should be stored in if its a global address space.
/// When a value is placed in the resulting address space, it needs to be cast back into wanted_address_space.
fn toLlvmGlobalAddressSpace(wanted_address_space: std.builtin.AddressSpace, target: *const std.Target) Builder.AddrSpace {
    return switch (wanted_address_space) {
        .generic => llvmDefaultGlobalAddressSpace(target),
        else => |as| toLlvmAddressSpace(as, target),
    };
}

fn returnTypeByRef(zcu: *Zcu, target: *const std.Target, ty: Type) bool {
    if (isByRef(ty, zcu)) {
        return true;
    } else if (target.cpu.arch.isX86() and
        !target.cpu.has(.x86, .evex512) and
        ty.totalVectorBits(zcu) >= 512)
    {
        // As of LLVM 18, passing a vector byval with fastcc that is 512 bits or more returns
        // "512-bit vector arguments require 'evex512' for AVX512"
        return true;
    } else {
        return false;
    }
}

fn firstParamSRet(fn_info: InternPool.Key.FuncType, zcu: *Zcu, target: *const std.Target) bool {
    const return_type = Type.fromInterned(fn_info.return_type);
    if (!return_type.hasRuntimeBitsIgnoreComptime(zcu)) return false;

    return switch (fn_info.cc) {
        .auto => returnTypeByRef(zcu, target, return_type),
        .x86_64_sysv => firstParamSRetSystemV(return_type, zcu, target),
        .x86_64_win => x86_64_abi.classifyWindows(return_type, zcu, target) == .memory,
        .x86_sysv, .x86_win => isByRef(return_type, zcu),
        .x86_stdcall => !isScalar(zcu, return_type),
        .wasm_mvp => wasm_c_abi.classifyType(return_type, zcu) == .indirect,
        .aarch64_aapcs,
        .aarch64_aapcs_darwin,
        .aarch64_aapcs_win,
        => aarch64_c_abi.classifyType(return_type, zcu) == .memory,
        .arm_aapcs, .arm_aapcs_vfp => switch (arm_c_abi.classifyType(return_type, zcu, .ret)) {
            .memory, .i64_array => true,
            .i32_array => |size| size != 1,
            .byval => false,
        },
        .riscv64_lp64, .riscv32_ilp32 => riscv_c_abi.classifyType(return_type, zcu) == .memory,
        .mips_o32 => switch (mips_c_abi.classifyType(return_type, zcu, .ret)) {
            .memory, .i32_array => true,
            .byval => false,
        },
        else => false, // TODO: investigate other targets/callconvs
    };
}

fn firstParamSRetSystemV(ty: Type, zcu: *Zcu, target: *const std.Target) bool {
    const class = x86_64_abi.classifySystemV(ty, zcu, target, .ret);
    if (class[0] == .memory) return true;
    if (class[0] == .x87 and class[2] != .none) return true;
    return false;
}

/// In order to support the C calling convention, some return types need to be lowered
/// completely differently in the function prototype to honor the C ABI, and then
/// be effectively bitcasted to the actual return type.
fn lowerFnRetTy(o: *Object, pt: Zcu.PerThread, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const zcu = pt.zcu;
    const return_type = Type.fromInterned(fn_info.return_type);
    if (!return_type.hasRuntimeBitsIgnoreComptime(zcu)) {
        // If the return type is an error set or an error union, then we make this
        // anyerror return type instead, so that it can be coerced into a function
        // pointer type which has anyerror as the return type.
        return if (return_type.isError(zcu)) try o.errorIntType(pt) else .void;
    }
    const target = zcu.getTarget();
    switch (fn_info.cc) {
        .@"inline" => unreachable,
        .auto => return if (returnTypeByRef(zcu, target, return_type)) .void else o.lowerType(pt, return_type),

        .x86_64_sysv => return lowerSystemVFnRetTy(o, pt, fn_info),
        .x86_64_win => return lowerWin64FnRetTy(o, pt, fn_info),
        .x86_stdcall => return if (isScalar(zcu, return_type)) o.lowerType(pt, return_type) else .void,
        .x86_sysv, .x86_win => return if (isByRef(return_type, zcu)) .void else o.lowerType(pt, return_type),
        .aarch64_aapcs, .aarch64_aapcs_darwin, .aarch64_aapcs_win => switch (aarch64_c_abi.classifyType(return_type, zcu)) {
            .memory => return .void,
            .float_array => return o.lowerType(pt, return_type),
            .byval => return o.lowerType(pt, return_type),
            .integer => return o.builder.intType(@intCast(return_type.bitSize(zcu))),
            .double_integer => return o.builder.arrayType(2, .i64),
        },
        .arm_aapcs, .arm_aapcs_vfp => switch (arm_c_abi.classifyType(return_type, zcu, .ret)) {
            .memory, .i64_array => return .void,
            .i32_array => |len| return if (len == 1) .i32 else .void,
            .byval => return o.lowerType(pt, return_type),
        },
        .mips_o32 => switch (mips_c_abi.classifyType(return_type, zcu, .ret)) {
            .memory, .i32_array => return .void,
            .byval => return o.lowerType(pt, return_type),
        },
        .riscv64_lp64, .riscv32_ilp32 => switch (riscv_c_abi.classifyType(return_type, zcu)) {
            .memory => return .void,
            .integer => return o.builder.intType(@intCast(return_type.bitSize(zcu))),
            .double_integer => {
                const integer: Builder.Type = switch (zcu.getTarget().cpu.arch) {
                    .riscv64, .riscv64be => .i64,
                    .riscv32, .riscv32be => .i32,
                    else => unreachable,
                };
                return o.builder.structType(.normal, &.{ integer, integer });
            },
            .byval => return o.lowerType(pt, return_type),
            .fields => {
                var types_len: usize = 0;
                var types: [8]Builder.Type = undefined;
                for (0..return_type.structFieldCount(zcu)) |field_index| {
                    const field_ty = return_type.fieldType(field_index, zcu);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
                    types[types_len] = try o.lowerType(pt, field_ty);
                    types_len += 1;
                }
                return o.builder.structType(.normal, types[0..types_len]);
            },
        },
        .wasm_mvp => switch (wasm_c_abi.classifyType(return_type, zcu)) {
            .direct => |scalar_ty| return o.lowerType(pt, scalar_ty),
            .indirect => return .void,
        },
        // TODO investigate other callconvs
        else => return o.lowerType(pt, return_type),
    }
}

fn lowerWin64FnRetTy(o: *Object, pt: Zcu.PerThread, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const zcu = pt.zcu;
    const return_type = Type.fromInterned(fn_info.return_type);
    switch (x86_64_abi.classifyWindows(return_type, zcu, zcu.getTarget())) {
        .integer => {
            if (isScalar(zcu, return_type)) {
                return o.lowerType(pt, return_type);
            } else {
                return o.builder.intType(@intCast(return_type.abiSize(zcu) * 8));
            }
        },
        .win_i128 => return o.builder.vectorType(.normal, 2, .i64),
        .memory => return .void,
        .sse => return o.lowerType(pt, return_type),
        else => unreachable,
    }
}

fn lowerSystemVFnRetTy(o: *Object, pt: Zcu.PerThread, fn_info: InternPool.Key.FuncType) Allocator.Error!Builder.Type {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const return_type = Type.fromInterned(fn_info.return_type);
    if (isScalar(zcu, return_type)) {
        return o.lowerType(pt, return_type);
    }
    const classes = x86_64_abi.classifySystemV(return_type, zcu, zcu.getTarget(), .ret);
    var types_index: u32 = 0;
    var types_buffer: [8]Builder.Type = undefined;
    for (classes) |class| {
        switch (class) {
            .integer => {
                types_buffer[types_index] = .i64;
                types_index += 1;
            },
            .sse => {
                types_buffer[types_index] = .double;
                types_index += 1;
            },
            .sseup => {
                if (types_buffer[types_index - 1] == .double) {
                    types_buffer[types_index - 1] = .fp128;
                } else {
                    types_buffer[types_index] = .double;
                    types_index += 1;
                }
            },
            .float => {
                types_buffer[types_index] = .float;
                types_index += 1;
            },
            .float_combine => {
                types_buffer[types_index] = try o.builder.vectorType(.normal, 2, .float);
                types_index += 1;
            },
            .x87 => {
                if (types_index != 0 or classes[2] != .none) return .void;
                types_buffer[types_index] = .x86_fp80;
                types_index += 1;
            },
            .x87up => continue,
            .none => break,
            .memory, .integer_per_element => return .void,
            .win_i128 => unreachable, // windows only
        }
    }
    const first_non_integer = std.mem.indexOfNone(x86_64_abi.Class, &classes, &.{.integer});
    if (first_non_integer == null or classes[first_non_integer.?] == .none) {
        assert(first_non_integer orelse classes.len == types_index);
        switch (ip.indexToKey(return_type.toIntern())) {
            .struct_type => {
                const struct_type = ip.loadStructType(return_type.toIntern());
                assert(struct_type.haveLayout(ip));
                const size: u64 = struct_type.sizeUnordered(ip);
                assert((std.math.divCeil(u64, size, 8) catch unreachable) == types_index);
                if (size % 8 > 0) {
                    types_buffer[types_index - 1] = try o.builder.intType(@intCast(size % 8 * 8));
                }
            },
            else => {},
        }
        if (types_index == 1) return types_buffer[0];
    }
    return o.builder.structType(.normal, types_buffer[0..types_index]);
}

const ParamTypeIterator = struct {
    object: *Object,
    pt: Zcu.PerThread,
    fn_info: InternPool.Key.FuncType,
    zig_index: u32,
    llvm_index: u32,
    types_len: u32,
    types_buffer: [8]Builder.Type,
    byval_attr: bool,

    const Lowering = union(enum) {
        no_bits,
        byval,
        byref,
        byref_mut,
        abi_sized_int,
        multiple_llvm_types,
        slice,
        float_array: u8,
        i32_array: u8,
        i64_array: u8,
    };

    pub fn next(it: *ParamTypeIterator) Allocator.Error!?Lowering {
        if (it.zig_index >= it.fn_info.param_types.len) return null;
        const ip = &it.pt.zcu.intern_pool;
        const ty = it.fn_info.param_types.get(ip)[it.zig_index];
        it.byval_attr = false;
        return nextInner(it, Type.fromInterned(ty));
    }

    /// `airCall` uses this instead of `next` so that it can take into account variadic functions.
    pub fn nextCall(it: *ParamTypeIterator, fg: *FuncGen, args: []const Air.Inst.Ref) Allocator.Error!?Lowering {
        assert(std.meta.eql(it.pt, fg.ng.pt));
        const ip = &it.pt.zcu.intern_pool;
        if (it.zig_index >= it.fn_info.param_types.len) {
            if (it.zig_index >= args.len) {
                return null;
            } else {
                return nextInner(it, fg.typeOf(args[it.zig_index]));
            }
        } else {
            return nextInner(it, Type.fromInterned(it.fn_info.param_types.get(ip)[it.zig_index]));
        }
    }

    fn nextInner(it: *ParamTypeIterator, ty: Type) Allocator.Error!?Lowering {
        const pt = it.pt;
        const zcu = pt.zcu;
        const target = zcu.getTarget();

        if (!ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            it.zig_index += 1;
            return .no_bits;
        }
        switch (it.fn_info.cc) {
            .@"inline" => unreachable,
            .auto => {
                it.zig_index += 1;
                it.llvm_index += 1;
                if (ty.isSlice(zcu) or
                    (ty.zigTypeTag(zcu) == .optional and ty.optionalChild(zcu).isSlice(zcu) and !ty.ptrAllowsZero(zcu)))
                {
                    it.llvm_index += 1;
                    return .slice;
                } else if (isByRef(ty, zcu)) {
                    return .byref;
                } else if (target.cpu.arch.isX86() and
                    !target.cpu.has(.x86, .evex512) and
                    ty.totalVectorBits(zcu) >= 512)
                {
                    // As of LLVM 18, passing a vector byval with fastcc that is 512 bits or more returns
                    // "512-bit vector arguments require 'evex512' for AVX512"
                    return .byref;
                } else {
                    return .byval;
                }
            },
            .async => {
                @panic("TODO implement async function lowering in the LLVM backend");
            },
            .x86_64_sysv => return it.nextSystemV(ty),
            .x86_64_win => return it.nextWin64(ty),
            .x86_stdcall => {
                it.zig_index += 1;
                it.llvm_index += 1;

                if (isScalar(zcu, ty)) {
                    return .byval;
                } else {
                    it.byval_attr = true;
                    return .byref;
                }
            },
            .aarch64_aapcs, .aarch64_aapcs_darwin, .aarch64_aapcs_win => {
                it.zig_index += 1;
                it.llvm_index += 1;
                switch (aarch64_c_abi.classifyType(ty, zcu)) {
                    .memory => return .byref_mut,
                    .float_array => |len| return Lowering{ .float_array = len },
                    .byval => return .byval,
                    .integer => {
                        it.types_len = 1;
                        it.types_buffer[0] = .i64;
                        return .multiple_llvm_types;
                    },
                    .double_integer => return Lowering{ .i64_array = 2 },
                }
            },
            .arm_aapcs, .arm_aapcs_vfp => {
                it.zig_index += 1;
                it.llvm_index += 1;
                switch (arm_c_abi.classifyType(ty, zcu, .arg)) {
                    .memory => {
                        it.byval_attr = true;
                        return .byref;
                    },
                    .byval => return .byval,
                    .i32_array => |size| return Lowering{ .i32_array = size },
                    .i64_array => |size| return Lowering{ .i64_array = size },
                }
            },
            .mips_o32 => {
                it.zig_index += 1;
                it.llvm_index += 1;
                switch (mips_c_abi.classifyType(ty, zcu, .arg)) {
                    .memory => {
                        it.byval_attr = true;
                        return .byref;
                    },
                    .byval => return .byval,
                    .i32_array => |size| return Lowering{ .i32_array = size },
                }
            },
            .riscv64_lp64, .riscv32_ilp32 => {
                it.zig_index += 1;
                it.llvm_index += 1;
                switch (riscv_c_abi.classifyType(ty, zcu)) {
                    .memory => return .byref_mut,
                    .byval => return .byval,
                    .integer => return .abi_sized_int,
                    .double_integer => return Lowering{ .i64_array = 2 },
                    .fields => {
                        it.types_len = 0;
                        for (0..ty.structFieldCount(zcu)) |field_index| {
                            const field_ty = ty.fieldType(field_index, zcu);
                            if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) continue;
                            it.types_buffer[it.types_len] = try it.object.lowerType(pt, field_ty);
                            it.types_len += 1;
                        }
                        it.llvm_index += it.types_len - 1;
                        return .multiple_llvm_types;
                    },
                }
            },
            .wasm_mvp => switch (wasm_c_abi.classifyType(ty, zcu)) {
                .direct => |scalar_ty| {
                    if (isScalar(zcu, ty)) {
                        it.zig_index += 1;
                        it.llvm_index += 1;
                        return .byval;
                    } else {
                        var types_buffer: [8]Builder.Type = undefined;
                        types_buffer[0] = try it.object.lowerType(pt, scalar_ty);
                        it.types_buffer = types_buffer;
                        it.types_len = 1;
                        it.llvm_index += 1;
                        it.zig_index += 1;
                        return .multiple_llvm_types;
                    }
                },
                .indirect => {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    it.byval_attr = true;
                    return .byref;
                },
            },
            // TODO investigate other callconvs
            else => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byval;
            },
        }
    }

    fn nextWin64(it: *ParamTypeIterator, ty: Type) ?Lowering {
        const zcu = it.pt.zcu;
        switch (x86_64_abi.classifyWindows(ty, zcu, zcu.getTarget())) {
            .integer => {
                if (isScalar(zcu, ty)) {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    return .byval;
                } else {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    return .abi_sized_int;
                }
            },
            .win_i128 => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byref;
            },
            .memory => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byref_mut;
            },
            .sse => {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .byval;
            },
            else => unreachable,
        }
    }

    fn nextSystemV(it: *ParamTypeIterator, ty: Type) Allocator.Error!?Lowering {
        const zcu = it.pt.zcu;
        const ip = &zcu.intern_pool;
        const classes = x86_64_abi.classifySystemV(ty, zcu, zcu.getTarget(), .arg);
        if (classes[0] == .memory) {
            it.zig_index += 1;
            it.llvm_index += 1;
            it.byval_attr = true;
            return .byref;
        }
        if (isScalar(zcu, ty)) {
            it.zig_index += 1;
            it.llvm_index += 1;
            return .byval;
        }
        var types_index: u32 = 0;
        var types_buffer: [8]Builder.Type = undefined;
        for (classes) |class| {
            switch (class) {
                .integer => {
                    types_buffer[types_index] = .i64;
                    types_index += 1;
                },
                .sse => {
                    types_buffer[types_index] = .double;
                    types_index += 1;
                },
                .sseup => {
                    if (types_buffer[types_index - 1] == .double) {
                        types_buffer[types_index - 1] = .fp128;
                    } else {
                        types_buffer[types_index] = .double;
                        types_index += 1;
                    }
                },
                .float => {
                    types_buffer[types_index] = .float;
                    types_index += 1;
                },
                .float_combine => {
                    types_buffer[types_index] = try it.object.builder.vectorType(.normal, 2, .float);
                    types_index += 1;
                },
                .x87 => {
                    it.zig_index += 1;
                    it.llvm_index += 1;
                    it.byval_attr = true;
                    return .byref;
                },
                .x87up => unreachable,
                .none => break,
                .memory => unreachable, // handled above
                .win_i128 => unreachable, // windows only
                .integer_per_element => {
                    @panic("TODO");
                },
            }
        }
        const first_non_integer = std.mem.indexOfNone(x86_64_abi.Class, &classes, &.{.integer});
        if (first_non_integer == null or classes[first_non_integer.?] == .none) {
            assert(first_non_integer orelse classes.len == types_index);
            if (types_index == 1) {
                it.zig_index += 1;
                it.llvm_index += 1;
                return .abi_sized_int;
            }
            if (it.llvm_index + types_index > 6) {
                it.zig_index += 1;
                it.llvm_index += 1;
                it.byval_attr = true;
                return .byref;
            }
            switch (ip.indexToKey(ty.toIntern())) {
                .struct_type => {
                    const struct_type = ip.loadStructType(ty.toIntern());
                    assert(struct_type.haveLayout(ip));
                    const size: u64 = struct_type.sizeUnordered(ip);
                    assert((std.math.divCeil(u64, size, 8) catch unreachable) == types_index);
                    if (size % 8 > 0) {
                        types_buffer[types_index - 1] =
                            try it.object.builder.intType(@intCast(size % 8 * 8));
                    }
                },
                else => {},
            }
        }
        it.types_len = types_index;
        it.types_buffer = types_buffer;
        it.llvm_index += types_index;
        it.zig_index += 1;
        return .multiple_llvm_types;
    }
};

fn iterateParamTypes(object: *Object, pt: Zcu.PerThread, fn_info: InternPool.Key.FuncType) ParamTypeIterator {
    return .{
        .object = object,
        .pt = pt,
        .fn_info = fn_info,
        .zig_index = 0,
        .llvm_index = 0,
        .types_len = 0,
        .types_buffer = undefined,
        .byval_attr = false,
    };
}

fn ccAbiPromoteInt(
    cc: std.builtin.CallingConvention,
    zcu: *Zcu,
    ty: Type,
) ?std.builtin.Signedness {
    const target = zcu.getTarget();
    switch (cc) {
        .auto, .@"inline", .async => return null,
        else => {},
    }
    const int_info = switch (ty.zigTypeTag(zcu)) {
        .bool => Type.u1.intInfo(zcu),
        .int, .@"enum", .error_set => ty.intInfo(zcu),
        else => return null,
    };
    return switch (target.os.tag) {
        .macos, .ios, .watchos, .tvos, .visionos => switch (int_info.bits) {
            0...16 => int_info.signedness,
            else => null,
        },
        else => switch (target.cpu.arch) {
            .loongarch64, .riscv64, .riscv64be => switch (int_info.bits) {
                0...16 => int_info.signedness,
                32 => .signed, // LLVM always signextends 32 bit ints, unsure if bug.
                17...31, 33...63 => int_info.signedness,
                else => null,
            },

            .sparc64,
            .powerpc64,
            .powerpc64le,
            .s390x,
            => switch (int_info.bits) {
                0...63 => int_info.signedness,
                else => null,
            },

            .aarch64,
            .aarch64_be,
            => null,

            else => switch (int_info.bits) {
                0...16 => int_info.signedness,
                else => null,
            },
        },
    };
}

/// This is the one source of truth for whether a type is passed around as an LLVM pointer,
/// or as an LLVM value.
fn isByRef(ty: Type, zcu: *Zcu) bool {
    // For tuples and structs, if there are more than this many non-void
    // fields, then we make it byref, otherwise byval.
    const max_fields_byval = 0;
    const ip = &zcu.intern_pool;

    switch (ty.zigTypeTag(zcu)) {
        .type,
        .comptime_int,
        .comptime_float,
        .enum_literal,
        .undefined,
        .null,
        .@"opaque",
        => unreachable,

        .noreturn,
        .void,
        .bool,
        .int,
        .float,
        .pointer,
        .error_set,
        .@"fn",
        .@"enum",
        .vector,
        .@"anyframe",
        => return false,

        .array, .frame => return ty.hasRuntimeBits(zcu),
        .@"struct" => {
            const struct_type = switch (ip.indexToKey(ty.toIntern())) {
                .tuple_type => |tuple| {
                    var count: usize = 0;
                    for (tuple.types.get(ip), tuple.values.get(ip)) |field_ty, field_val| {
                        if (field_val != .none or !Type.fromInterned(field_ty).hasRuntimeBits(zcu)) continue;

                        count += 1;
                        if (count > max_fields_byval) return true;
                        if (isByRef(Type.fromInterned(field_ty), zcu)) return true;
                    }
                    return false;
                },
                .struct_type => ip.loadStructType(ty.toIntern()),
                else => unreachable,
            };

            // Packed structs are represented to LLVM as integers.
            if (struct_type.layout == .@"packed") return false;

            const field_types = struct_type.field_types.get(ip);
            var it = struct_type.iterateRuntimeOrder(ip);
            var count: usize = 0;
            while (it.next()) |field_index| {
                count += 1;
                if (count > max_fields_byval) return true;
                const field_ty = Type.fromInterned(field_types[field_index]);
                if (isByRef(field_ty, zcu)) return true;
            }
            return false;
        },
        .@"union" => switch (ty.containerLayout(zcu)) {
            .@"packed" => return false,
            else => return ty.hasRuntimeBits(zcu) and !ty.unionHasAllZeroBitFieldTypes(zcu),
        },
        .error_union => {
            const payload_ty = ty.errorUnionPayload(zcu);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                return false;
            }
            return true;
        },
        .optional => {
            const payload_ty = ty.optionalChild(zcu);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                return false;
            }
            if (ty.optionalReprIsPayload(zcu)) {
                return false;
            }
            return true;
        },
    }
}

fn isScalar(zcu: *Zcu, ty: Type) bool {
    return switch (ty.zigTypeTag(zcu)) {
        .void,
        .bool,
        .noreturn,
        .int,
        .float,
        .pointer,
        .optional,
        .error_set,
        .@"enum",
        .@"anyframe",
        .vector,
        => true,

        .@"struct" => ty.containerLayout(zcu) == .@"packed",
        .@"union" => ty.containerLayout(zcu) == .@"packed",
        else => false,
    };
}

/// This function returns true if we expect LLVM to lower x86_fp80 correctly
/// and false if we expect LLVM to crash if it encounters an x86_fp80 type,
/// or if it produces miscompilations.
fn backendSupportsF80(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        .x86, .x86_64 => !target.cpu.has(.x86, .soft_float),
        else => false,
    };
}

/// This function returns true if we expect LLVM to lower f16 correctly
/// and false if we expect LLVM to crash if it encounters an f16 type,
/// or if it produces miscompilations.
fn backendSupportsF16(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        // https://github.com/llvm/llvm-project/issues/97981
        .csky,
        // https://github.com/llvm/llvm-project/issues/97981
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        // https://github.com/llvm/llvm-project/issues/97981
        .wasm32,
        .wasm64,
        // https://github.com/llvm/llvm-project/issues/97981
        .sparc,
        .sparc64,
        => false,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => target.abi.float() == .soft or target.cpu.has(.arm, .fullfp16),
        else => true,
    };
}

/// This function returns true if we expect LLVM to lower f128 correctly,
/// and false if we expect LLVM to crash if it encounters an f128 type,
/// or if it produces miscompilations.
fn backendSupportsF128(target: *const std.Target) bool {
    return switch (target.cpu.arch) {
        // https://github.com/llvm/llvm-project/issues/121122
        .amdgcn,
        // Test failures all over the place.
        .mips64,
        .mips64el,
        // https://github.com/llvm/llvm-project/issues/41838
        .sparc,
        => false,
        // https://github.com/llvm/llvm-project/issues/101545
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        => target.os.tag != .aix,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => target.abi.float() == .soft or target.cpu.has(.arm, .fp_armv8),
        else => true,
    };
}

/// LLVM does not support all relevant intrinsics for all targets, so we
/// may need to manually generate a compiler-rt call.
fn intrinsicsAllowed(scalar_ty: Type, target: *const std.Target) bool {
    return switch (scalar_ty.toIntern()) {
        .f16_type => backendSupportsF16(target),
        .f80_type => (target.cTypeBitSize(.longdouble) == 80) and backendSupportsF80(target),
        .f128_type => (target.cTypeBitSize(.longdouble) == 128) and backendSupportsF128(target),
        else => true,
    };
}

/// We need to insert extra padding if LLVM's isn't enough.
/// However we don't want to ever call LLVMABIAlignmentOfType or
/// LLVMABISizeOfType because these functions will trip assertions
/// when using them for self-referential types. So our strategy is
/// to use non-packed llvm structs but to emit all padding explicitly.
/// We can do this because for all types, Zig ABI alignment >= LLVM ABI
/// alignment.
const struct_layout_version = 2;

// TODO: Restore the non_null field to i1 once
//       https://github.com/llvm/llvm-project/issues/56585/ is fixed
const optional_layout_version = 3;

const lt_errors_fn_name = "__zig_lt_errors_len";

fn compilerRtIntBits(bits: u16) u16 {
    inline for (.{ 32, 64, 128 }) |b| {
        if (bits <= b) {
            return b;
        }
    }
    return bits;
}

fn buildAllocaInner(
    wip: *Builder.WipFunction,
    llvm_ty: Builder.Type,
    alignment: Builder.Alignment,
    target: *const std.Target,
) Allocator.Error!Builder.Value {
    const address_space = llvmAllocaAddressSpace(target);

    const alloca = blk: {
        const prev_cursor = wip.cursor;
        const prev_debug_location = wip.debug_location;
        defer {
            wip.cursor = prev_cursor;
            if (wip.cursor.block == .entry) wip.cursor.instruction += 1;
            wip.debug_location = prev_debug_location;
        }

        wip.cursor = .{ .block = .entry };
        wip.debug_location = .no_location;
        break :blk try wip.alloca(.normal, llvm_ty, .none, alignment, address_space, "");
    };

    // The pointer returned from this function should have the generic address space,
    // if this isn't the case then cast it to the generic address space.
    return wip.conv(.unneeded, alloca, .ptr, "");
}

fn errUnionPayloadOffset(payload_ty: Type, pt: Zcu.PerThread) !u1 {
    const zcu = pt.zcu;
    const err_int_ty = try pt.errorIntType();
    return @intFromBool(err_int_ty.abiAlignment(zcu).compare(.gt, payload_ty.abiAlignment(zcu)));
}

fn errUnionErrorOffset(payload_ty: Type, pt: Zcu.PerThread) !u1 {
    const zcu = pt.zcu;
    const err_int_ty = try pt.errorIntType();
    return @intFromBool(err_int_ty.abiAlignment(zcu).compare(.lte, payload_ty.abiAlignment(zcu)));
}

/// Returns true for asm constraint (e.g. "=*m", "=r") if it accepts a memory location
///
/// See also TargetInfo::validateOutputConstraint, AArch64TargetInfo::validateAsmConstraint, etc. in Clang
fn constraintAllowsMemory(constraint: []const u8) bool {
    // TODO: This implementation is woefully incomplete.
    for (constraint) |byte| {
        switch (byte) {
            '=', '*', ',', '&' => {},
            'm', 'o', 'X', 'g' => return true,
            else => {},
        }
    } else return false;
}

/// Returns true for asm constraint (e.g. "=*m", "=r") if it accepts a register
///
/// See also TargetInfo::validateOutputConstraint, AArch64TargetInfo::validateAsmConstraint, etc. in Clang
fn constraintAllowsRegister(constraint: []const u8) bool {
    // TODO: This implementation is woefully incomplete.
    for (constraint) |byte| {
        switch (byte) {
            '=', '*', ',', '&' => {},
            'm', 'o' => {},
            else => return true,
        }
    } else return false;
}

pub fn initializeLLVMTarget(arch: std.Target.Cpu.Arch) void {
    switch (arch) {
        .aarch64, .aarch64_be => {
            llvm.LLVMInitializeAArch64Target();
            llvm.LLVMInitializeAArch64TargetInfo();
            llvm.LLVMInitializeAArch64TargetMC();
            llvm.LLVMInitializeAArch64AsmPrinter();
            llvm.LLVMInitializeAArch64AsmParser();
        },
        .amdgcn => {
            llvm.LLVMInitializeAMDGPUTarget();
            llvm.LLVMInitializeAMDGPUTargetInfo();
            llvm.LLVMInitializeAMDGPUTargetMC();
            llvm.LLVMInitializeAMDGPUAsmPrinter();
            llvm.LLVMInitializeAMDGPUAsmParser();
        },
        .thumb, .thumbeb, .arm, .armeb => {
            llvm.LLVMInitializeARMTarget();
            llvm.LLVMInitializeARMTargetInfo();
            llvm.LLVMInitializeARMTargetMC();
            llvm.LLVMInitializeARMAsmPrinter();
            llvm.LLVMInitializeARMAsmParser();
        },
        .avr => {
            llvm.LLVMInitializeAVRTarget();
            llvm.LLVMInitializeAVRTargetInfo();
            llvm.LLVMInitializeAVRTargetMC();
            llvm.LLVMInitializeAVRAsmPrinter();
            llvm.LLVMInitializeAVRAsmParser();
        },
        .bpfel, .bpfeb => {
            llvm.LLVMInitializeBPFTarget();
            llvm.LLVMInitializeBPFTargetInfo();
            llvm.LLVMInitializeBPFTargetMC();
            llvm.LLVMInitializeBPFAsmPrinter();
            llvm.LLVMInitializeBPFAsmParser();
        },
        .hexagon => {
            llvm.LLVMInitializeHexagonTarget();
            llvm.LLVMInitializeHexagonTargetInfo();
            llvm.LLVMInitializeHexagonTargetMC();
            llvm.LLVMInitializeHexagonAsmPrinter();
            llvm.LLVMInitializeHexagonAsmParser();
        },
        .lanai => {
            llvm.LLVMInitializeLanaiTarget();
            llvm.LLVMInitializeLanaiTargetInfo();
            llvm.LLVMInitializeLanaiTargetMC();
            llvm.LLVMInitializeLanaiAsmPrinter();
            llvm.LLVMInitializeLanaiAsmParser();
        },
        .mips, .mipsel, .mips64, .mips64el => {
            llvm.LLVMInitializeMipsTarget();
            llvm.LLVMInitializeMipsTargetInfo();
            llvm.LLVMInitializeMipsTargetMC();
            llvm.LLVMInitializeMipsAsmPrinter();
            llvm.LLVMInitializeMipsAsmParser();
        },
        .msp430 => {
            llvm.LLVMInitializeMSP430Target();
            llvm.LLVMInitializeMSP430TargetInfo();
            llvm.LLVMInitializeMSP430TargetMC();
            llvm.LLVMInitializeMSP430AsmPrinter();
            llvm.LLVMInitializeMSP430AsmParser();
        },
        .nvptx, .nvptx64 => {
            llvm.LLVMInitializeNVPTXTarget();
            llvm.LLVMInitializeNVPTXTargetInfo();
            llvm.LLVMInitializeNVPTXTargetMC();
            llvm.LLVMInitializeNVPTXAsmPrinter();
            // There is no LLVMInitializeNVPTXAsmParser function available.
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => {
            llvm.LLVMInitializePowerPCTarget();
            llvm.LLVMInitializePowerPCTargetInfo();
            llvm.LLVMInitializePowerPCTargetMC();
            llvm.LLVMInitializePowerPCAsmPrinter();
            llvm.LLVMInitializePowerPCAsmParser();
        },
        .riscv32, .riscv32be, .riscv64, .riscv64be => {
            llvm.LLVMInitializeRISCVTarget();
            llvm.LLVMInitializeRISCVTargetInfo();
            llvm.LLVMInitializeRISCVTargetMC();
            llvm.LLVMInitializeRISCVAsmPrinter();
            llvm.LLVMInitializeRISCVAsmParser();
        },
        .sparc, .sparc64 => {
            llvm.LLVMInitializeSparcTarget();
            llvm.LLVMInitializeSparcTargetInfo();
            llvm.LLVMInitializeSparcTargetMC();
            llvm.LLVMInitializeSparcAsmPrinter();
            llvm.LLVMInitializeSparcAsmParser();
        },
        .s390x => {
            llvm.LLVMInitializeSystemZTarget();
            llvm.LLVMInitializeSystemZTargetInfo();
            llvm.LLVMInitializeSystemZTargetMC();
            llvm.LLVMInitializeSystemZAsmPrinter();
            llvm.LLVMInitializeSystemZAsmParser();
        },
        .wasm32, .wasm64 => {
            llvm.LLVMInitializeWebAssemblyTarget();
            llvm.LLVMInitializeWebAssemblyTargetInfo();
            llvm.LLVMInitializeWebAssemblyTargetMC();
            llvm.LLVMInitializeWebAssemblyAsmPrinter();
            llvm.LLVMInitializeWebAssemblyAsmParser();
        },
        .x86, .x86_64 => {
            llvm.LLVMInitializeX86Target();
            llvm.LLVMInitializeX86TargetInfo();
            llvm.LLVMInitializeX86TargetMC();
            llvm.LLVMInitializeX86AsmPrinter();
            llvm.LLVMInitializeX86AsmParser();
        },
        .xtensa => {
            if (build_options.llvm_has_xtensa) {
                llvm.LLVMInitializeXtensaTarget();
                llvm.LLVMInitializeXtensaTargetInfo();
                llvm.LLVMInitializeXtensaTargetMC();
                // There is no LLVMInitializeXtensaAsmPrinter function.
                llvm.LLVMInitializeXtensaAsmParser();
            }
        },
        .xcore => {
            llvm.LLVMInitializeXCoreTarget();
            llvm.LLVMInitializeXCoreTargetInfo();
            llvm.LLVMInitializeXCoreTargetMC();
            llvm.LLVMInitializeXCoreAsmPrinter();
            // There is no LLVMInitializeXCoreAsmParser function.
        },
        .m68k => {
            if (build_options.llvm_has_m68k) {
                llvm.LLVMInitializeM68kTarget();
                llvm.LLVMInitializeM68kTargetInfo();
                llvm.LLVMInitializeM68kTargetMC();
                llvm.LLVMInitializeM68kAsmPrinter();
                llvm.LLVMInitializeM68kAsmParser();
            }
        },
        .csky => {
            if (build_options.llvm_has_csky) {
                llvm.LLVMInitializeCSKYTarget();
                llvm.LLVMInitializeCSKYTargetInfo();
                llvm.LLVMInitializeCSKYTargetMC();
                // There is no LLVMInitializeCSKYAsmPrinter function.
                llvm.LLVMInitializeCSKYAsmParser();
            }
        },
        .ve => {
            llvm.LLVMInitializeVETarget();
            llvm.LLVMInitializeVETargetInfo();
            llvm.LLVMInitializeVETargetMC();
            llvm.LLVMInitializeVEAsmPrinter();
            llvm.LLVMInitializeVEAsmParser();
        },
        .arc => {
            if (build_options.llvm_has_arc) {
                llvm.LLVMInitializeARCTarget();
                llvm.LLVMInitializeARCTargetInfo();
                llvm.LLVMInitializeARCTargetMC();
                llvm.LLVMInitializeARCAsmPrinter();
                // There is no LLVMInitializeARCAsmParser function.
            }
        },
        .loongarch32, .loongarch64 => {
            llvm.LLVMInitializeLoongArchTarget();
            llvm.LLVMInitializeLoongArchTargetInfo();
            llvm.LLVMInitializeLoongArchTargetMC();
            llvm.LLVMInitializeLoongArchAsmPrinter();
            llvm.LLVMInitializeLoongArchAsmParser();
        },
        .spirv32,
        .spirv64,
        => {
            llvm.LLVMInitializeSPIRVTarget();
            llvm.LLVMInitializeSPIRVTargetInfo();
            llvm.LLVMInitializeSPIRVTargetMC();
            llvm.LLVMInitializeSPIRVAsmPrinter();
        },

        // LLVM does does not have a backend for these.
        .kalimba,
        .or1k,
        .propeller,
        => unreachable,
    }
}

fn minIntConst(b: *Builder, min_ty: Type, as_ty: Builder.Type, zcu: *const Zcu) Allocator.Error!Builder.Constant {
    const info = min_ty.intInfo(zcu);
    if (info.signedness == .unsigned or info.bits == 0) {
        return b.intConst(as_ty, 0);
    }
    if (std.math.cast(u6, info.bits - 1)) |shift| {
        const min_val: i64 = @as(i64, std.math.minInt(i64)) >> (63 - shift);
        return b.intConst(as_ty, min_val);
    }
    var res: std.math.big.int.Managed = try .init(zcu.gpa);
    defer res.deinit();
    try res.setTwosCompIntLimit(.min, info.signedness, info.bits);
    return b.bigIntConst(as_ty, res.toConst());
}

fn maxIntConst(b: *Builder, max_ty: Type, as_ty: Builder.Type, zcu: *const Zcu) Allocator.Error!Builder.Constant {
    const info = max_ty.intInfo(zcu);
    switch (info.bits) {
        0 => return b.intConst(as_ty, 0),
        1 => switch (info.signedness) {
            .signed => return b.intConst(as_ty, 0),
            .unsigned => return b.intConst(as_ty, 1),
        },
        else => {},
    }
    const unsigned_bits = switch (info.signedness) {
        .unsigned => info.bits,
        .signed => info.bits - 1,
    };
    if (std.math.cast(u6, unsigned_bits)) |shift| {
        const max_val: u64 = (@as(u64, 1) << shift) - 1;
        return b.intConst(as_ty, max_val);
    }
    var res: std.math.big.int.Managed = try .init(zcu.gpa);
    defer res.deinit();
    try res.setTwosCompIntLimit(.max, info.signedness, info.bits);
    return b.bigIntConst(as_ty, res.toConst());
}

/// Appends zero or more LLVM constraints to `llvm_constraints`, returning how many were added.
fn appendConstraints(
    gpa: Allocator,
    llvm_constraints: *std.ArrayListUnmanaged(u8),
    zig_name: []const u8,
    target: *const std.Target,
) error{OutOfMemory}!usize {
    switch (target.cpu.arch) {
        .mips, .mipsel, .mips64, .mips64el => if (mips_clobber_overrides.get(zig_name)) |llvm_tag| {
            const llvm_name = @tagName(llvm_tag);
            try llvm_constraints.ensureUnusedCapacity(gpa, llvm_name.len + 4);
            llvm_constraints.appendSliceAssumeCapacity("~{");
            llvm_constraints.appendSliceAssumeCapacity(llvm_name);
            llvm_constraints.appendSliceAssumeCapacity("},");
            return 1;
        },
        else => {},
    }

    try llvm_constraints.ensureUnusedCapacity(gpa, zig_name.len + 4);
    llvm_constraints.appendSliceAssumeCapacity("~{");
    llvm_constraints.appendSliceAssumeCapacity(zig_name);
    llvm_constraints.appendSliceAssumeCapacity("},");
    return 1;
}

const mips_clobber_overrides = std.StaticStringMap(enum {
    @"$msair",
    @"$msacsr",
    @"$msaaccess",
    @"$msasave",
    @"$msamodify",
    @"$msarequest",
    @"$msamap",
    @"$msaunmap",
    @"$f0",
    @"$f1",
    @"$f2",
    @"$f3",
    @"$f4",
    @"$f5",
    @"$f6",
    @"$f7",
    @"$f8",
    @"$f9",
    @"$f10",
    @"$f11",
    @"$f12",
    @"$f13",
    @"$f14",
    @"$f15",
    @"$f16",
    @"$f17",
    @"$f18",
    @"$f19",
    @"$f20",
    @"$f21",
    @"$f22",
    @"$f23",
    @"$f24",
    @"$f25",
    @"$f26",
    @"$f27",
    @"$f28",
    @"$f29",
    @"$f30",
    @"$f31",
    @"$fcc0",
    @"$fcc1",
    @"$fcc2",
    @"$fcc3",
    @"$fcc4",
    @"$fcc5",
    @"$fcc6",
    @"$fcc7",
    @"$w0",
    @"$w1",
    @"$w2",
    @"$w3",
    @"$w4",
    @"$w5",
    @"$w6",
    @"$w7",
    @"$w8",
    @"$w9",
    @"$w10",
    @"$w11",
    @"$w12",
    @"$w13",
    @"$w14",
    @"$w15",
    @"$w16",
    @"$w17",
    @"$w18",
    @"$w19",
    @"$w20",
    @"$w21",
    @"$w22",
    @"$w23",
    @"$w24",
    @"$w25",
    @"$w26",
    @"$w27",
    @"$w28",
    @"$w29",
    @"$w30",
    @"$w31",
    @"$0",
    @"$1",
    @"$2",
    @"$3",
    @"$4",
    @"$5",
    @"$6",
    @"$7",
    @"$8",
    @"$9",
    @"$10",
    @"$11",
    @"$12",
    @"$13",
    @"$14",
    @"$15",
    @"$16",
    @"$17",
    @"$18",
    @"$19",
    @"$20",
    @"$21",
    @"$22",
    @"$23",
    @"$24",
    @"$25",
    @"$26",
    @"$27",
    @"$28",
    @"$29",
    @"$30",
    @"$31",
}).initComptime(.{
    .{ "msa_ir", .@"$msair" },
    .{ "msa_csr", .@"$msacsr" },
    .{ "msa_access", .@"$msaaccess" },
    .{ "msa_save", .@"$msasave" },
    .{ "msa_modify", .@"$msamodify" },
    .{ "msa_request", .@"$msarequest" },
    .{ "msa_map", .@"$msamap" },
    .{ "msa_unmap", .@"$msaunmap" },
    .{ "f0", .@"$f0" },
    .{ "f1", .@"$f1" },
    .{ "f2", .@"$f2" },
    .{ "f3", .@"$f3" },
    .{ "f4", .@"$f4" },
    .{ "f5", .@"$f5" },
    .{ "f6", .@"$f6" },
    .{ "f7", .@"$f7" },
    .{ "f8", .@"$f8" },
    .{ "f9", .@"$f9" },
    .{ "f10", .@"$f10" },
    .{ "f11", .@"$f11" },
    .{ "f12", .@"$f12" },
    .{ "f13", .@"$f13" },
    .{ "f14", .@"$f14" },
    .{ "f15", .@"$f15" },
    .{ "f16", .@"$f16" },
    .{ "f17", .@"$f17" },
    .{ "f18", .@"$f18" },
    .{ "f19", .@"$f19" },
    .{ "f20", .@"$f20" },
    .{ "f21", .@"$f21" },
    .{ "f22", .@"$f22" },
    .{ "f23", .@"$f23" },
    .{ "f24", .@"$f24" },
    .{ "f25", .@"$f25" },
    .{ "f26", .@"$f26" },
    .{ "f27", .@"$f27" },
    .{ "f28", .@"$f28" },
    .{ "f29", .@"$f29" },
    .{ "f30", .@"$f30" },
    .{ "f31", .@"$f31" },
    .{ "fcc0", .@"$fcc0" },
    .{ "fcc1", .@"$fcc1" },
    .{ "fcc2", .@"$fcc2" },
    .{ "fcc3", .@"$fcc3" },
    .{ "fcc4", .@"$fcc4" },
    .{ "fcc5", .@"$fcc5" },
    .{ "fcc6", .@"$fcc6" },
    .{ "fcc7", .@"$fcc7" },
    .{ "w0", .@"$w0" },
    .{ "w1", .@"$w1" },
    .{ "w2", .@"$w2" },
    .{ "w3", .@"$w3" },
    .{ "w4", .@"$w4" },
    .{ "w5", .@"$w5" },
    .{ "w6", .@"$w6" },
    .{ "w7", .@"$w7" },
    .{ "w8", .@"$w8" },
    .{ "w9", .@"$w9" },
    .{ "w10", .@"$w10" },
    .{ "w11", .@"$w11" },
    .{ "w12", .@"$w12" },
    .{ "w13", .@"$w13" },
    .{ "w14", .@"$w14" },
    .{ "w15", .@"$w15" },
    .{ "w16", .@"$w16" },
    .{ "w17", .@"$w17" },
    .{ "w18", .@"$w18" },
    .{ "w19", .@"$w19" },
    .{ "w20", .@"$w20" },
    .{ "w21", .@"$w21" },
    .{ "w22", .@"$w22" },
    .{ "w23", .@"$w23" },
    .{ "w24", .@"$w24" },
    .{ "w25", .@"$w25" },
    .{ "w26", .@"$w26" },
    .{ "w27", .@"$w27" },
    .{ "w28", .@"$w28" },
    .{ "w29", .@"$w29" },
    .{ "w30", .@"$w30" },
    .{ "w31", .@"$w31" },
    .{ "r0", .@"$0" },
    .{ "r1", .@"$1" },
    .{ "r2", .@"$2" },
    .{ "r3", .@"$3" },
    .{ "r4", .@"$4" },
    .{ "r5", .@"$5" },
    .{ "r6", .@"$6" },
    .{ "r7", .@"$7" },
    .{ "r8", .@"$8" },
    .{ "r9", .@"$9" },
    .{ "r10", .@"$10" },
    .{ "r11", .@"$11" },
    .{ "r12", .@"$12" },
    .{ "r13", .@"$13" },
    .{ "r14", .@"$14" },
    .{ "r15", .@"$15" },
    .{ "r16", .@"$16" },
    .{ "r17", .@"$17" },
    .{ "r18", .@"$18" },
    .{ "r19", .@"$19" },
    .{ "r20", .@"$20" },
    .{ "r21", .@"$21" },
    .{ "r22", .@"$22" },
    .{ "r23", .@"$23" },
    .{ "r24", .@"$24" },
    .{ "r25", .@"$25" },
    .{ "r26", .@"$26" },
    .{ "r27", .@"$27" },
    .{ "r28", .@"$28" },
    .{ "r29", .@"$29" },
    .{ "r30", .@"$30" },
    .{ "r31", .@"$31" },
});
