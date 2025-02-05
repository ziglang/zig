const std = @import("std");
const assert = std.debug.assert;

const Type = @import("Type.zig");
const AddressSpace = std.builtin.AddressSpace;
const Alignment = @import("InternPool.zig").Alignment;
const Compilation = @import("Compilation.zig");
const Feature = @import("Zcu.zig").Feature;

pub const default_stack_protector_buffer_size = 4;

pub fn cannotDynamicLink(target: std.Target) bool {
    return switch (target.os.tag) {
        .freestanding => true,
        else => target.cpu.arch.isSpirV(),
    };
}

/// On Darwin, we always link libSystem which contains libc.
/// Similarly on FreeBSD and NetBSD we always link system libc
/// since this is the stable syscall interface.
pub fn osRequiresLibC(target: std.Target) bool {
    return target.os.requiresLibC();
}

pub fn libcNeedsLibUnwind(target: std.Target) bool {
    return switch (target.os.tag) {
        .macos,
        .ios,
        .watchos,
        .tvos,
        .visionos,
        .freestanding,
        .wasi, // Wasm/WASI currently doesn't offer support for libunwind, so don't link it.
        => false,

        .windows => target.abi.isGnu(),
        else => true,
    };
}

pub fn requiresPIE(target: std.Target) bool {
    return target.abi.isAndroid() or target.os.tag.isDarwin() or target.os.tag == .openbsd;
}

/// This function returns whether non-pic code is completely invalid on the given target.
pub fn requiresPIC(target: std.Target, linking_libc: bool) bool {
    return target.abi.isAndroid() or
        target.os.tag == .windows or target.os.tag == .uefi or
        osRequiresLibC(target) or
        (linking_libc and target.isGnuLibC());
}

pub fn picLevel(target: std.Target) u32 {
    // MIPS always uses PIC level 1; other platforms vary in their default PIC levels, but they
    // support both level 1 and 2, in which case we prefer 2.
    return if (target.cpu.arch.isMIPS()) 1 else 2;
}

/// This is not whether the target supports Position Independent Code, but whether the -fPIC
/// C compiler argument is valid to Clang.
pub fn supports_fpic(target: std.Target) bool {
    return target.os.tag != .windows and target.os.tag != .uefi;
}

pub fn alwaysSingleThreaded(target: std.Target) bool {
    _ = target;
    return false;
}

pub fn defaultSingleThreaded(target: std.Target) bool {
    switch (target.cpu.arch) {
        .wasm32, .wasm64 => return true,
        else => {},
    }
    switch (target.os.tag) {
        .haiku => return true,
        else => {},
    }
    return false;
}

pub fn hasValgrindSupport(target: std.Target) bool {
    // We can't currently output the necessary Valgrind client request assembly when using the C
    // backend and compiling with an MSVC-like compiler.
    const ofmt_c_msvc = (target.abi == .msvc or target.abi == .itanium) and target.ofmt == .c;

    return switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => switch (target.os.tag) {
            .linux => true,
            else => false,
        },
        .aarch64, .aarch64_be => switch (target.os.tag) {
            .linux, .freebsd => true,
            else => false,
        },
        .mips, .mipsel, .mips64, .mips64el => switch (target.os.tag) {
            .linux => true,
            else => false,
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => switch (target.os.tag) {
            .linux => true,
            else => false,
        },
        .s390x => switch (target.os.tag) {
            .linux => true,
            else => false,
        },
        .x86 => switch (target.os.tag) {
            .linux, .freebsd, .solaris, .illumos => true,
            .windows => !ofmt_c_msvc,
            else => false,
        },
        .x86_64 => switch (target.os.tag) {
            .linux => target.abi != .gnux32 and target.abi != .muslx32,
            .freebsd, .solaris, .illumos => true,
            .windows => !ofmt_c_msvc,
            else => false,
        },
        else => false,
    };
}

/// The set of targets that LLVM has non-experimental support for.
/// Used to select between LLVM backend and self-hosted backend when compiling in
/// release modes.
pub fn hasLlvmSupport(target: std.Target, ofmt: std.Target.ObjectFormat) bool {
    switch (ofmt) {
        // LLVM does not support these object formats:
        .c,
        .plan9,
        => return false,

        .coff,
        .elf,
        .goff,
        .hex,
        .macho,
        .nvptx,
        .spirv,
        .raw,
        .wasm,
        .xcoff,
        => {},
    }

    return switch (target.cpu.arch) {
        .arm,
        .armeb,
        .aarch64,
        .aarch64_be,
        .arc,
        .avr,
        .bpfel,
        .bpfeb,
        .csky,
        .hexagon,
        .loongarch32,
        .loongarch64,
        .m68k,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .msp430,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .amdgcn,
        .riscv32,
        .riscv64,
        .sparc,
        .sparc64,
        .s390x,
        .thumb,
        .thumbeb,
        .x86,
        .x86_64,
        .xcore,
        .xtensa,
        .nvptx,
        .nvptx64,
        .lanai,
        .wasm32,
        .wasm64,
        .ve,
        => true,

        // An LLVM backend exists but we don't currently support using it.
        .spirv,
        .spirv32,
        .spirv64,
        => false,

        // No LLVM backend exists.
        .kalimba,
        .propeller,
        => false,
    };
}

/// The set of targets that Zig supports using LLD to link for.
pub fn hasLldSupport(ofmt: std.Target.ObjectFormat) bool {
    return switch (ofmt) {
        .elf, .coff, .wasm => true,
        else => false,
    };
}

/// The set of targets that our own self-hosted backends have robust support for.
/// Used to select between LLVM backend and self-hosted backend when compiling in
/// debug mode. A given target should only return true here if it is passing greater
/// than or equal to the number of behavior tests as the respective LLVM backend.
pub fn selfHostedBackendIsAsRobustAsLlvm(target: std.Target) bool {
    _ = target;
    return false;
}

pub fn supportsStackProbing(target: std.Target) bool {
    return target.os.tag != .windows and target.os.tag != .uefi and
        (target.cpu.arch == .x86 or target.cpu.arch == .x86_64);
}

pub fn supportsStackProtector(target: std.Target, backend: std.builtin.CompilerBackend) bool {
    switch (target.os.tag) {
        .plan9 => return false,
        else => {},
    }
    switch (target.cpu.arch) {
        .spirv, .spirv32, .spirv64 => return false,
        else => {},
    }
    return switch (backend) {
        .stage2_llvm => true,
        else => false,
    };
}

pub fn clangSupportsStackProtector(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .spirv, .spirv32, .spirv64 => return false,
        else => true,
    };
}

pub fn libcProvidesStackProtector(target: std.Target) bool {
    return !target.isMinGW() and target.os.tag != .wasi and !target.cpu.arch.isSpirV();
}

pub fn supportsReturnAddress(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => target.os.tag == .emscripten,
        .bpfel, .bpfeb => false,
        .spirv, .spirv32, .spirv64 => false,
        else => true,
    };
}

pub const CompilerRtClassification = enum { none, only_compiler_rt, only_libunwind, both };

pub fn classifyCompilerRtLibName(name: []const u8) CompilerRtClassification {
    if (std.mem.eql(u8, name, "gcc_s")) {
        // libgcc_s includes exception handling functions, so if linking this library
        // is requested, zig needs to instead link libunwind. Otherwise we end up with
        // the linker unable to find `_Unwind_RaiseException` and other related symbols.
        return .both;
    }
    if (std.mem.eql(u8, name, "compiler_rt") or
        std.mem.eql(u8, name, "gcc") or
        std.mem.eql(u8, name, "atomic") or
        std.mem.eql(u8, name, "ssp"))
    {
        return .only_compiler_rt;
    }
    if (std.mem.eql(u8, name, "unwind") or
        std.mem.eql(u8, name, "gcc_eh"))
    {
        return .only_libunwind;
    }
    return .none;
}

pub fn hasDebugInfo(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .nvptx, .nvptx64 => std.Target.nvptx.featureSetHas(target.cpu.features, .ptx75) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx76) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx77) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx78) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx80) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx81) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx82) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx83) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx84) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx85) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx86) or
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx87),
        .bpfel, .bpfeb => false,
        else => true,
    };
}

pub fn defaultCompilerRtOptimizeMode(target: std.Target) std.builtin.OptimizeMode {
    if (target.cpu.arch.isWasm() and target.os.tag == .freestanding) {
        return .ReleaseSmall;
    } else {
        return .ReleaseFast;
    }
}

pub fn hasRedZone(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .aarch64,
        .aarch64_be,
        .x86,
        .x86_64,
        => true,

        else => false,
    };
}

pub fn libcFullLinkFlags(target: std.Target) []const []const u8 {
    // The linking order of these is significant and should match the order other
    // c compilers such as gcc or clang use.
    const result: []const []const u8 = switch (target.os.tag) {
        .dragonfly, .freebsd, .netbsd, .openbsd => &.{ "-lm", "-lpthread", "-lc", "-lutil" },
        // Solaris releases after 10 merged the threading libraries into libc.
        .solaris, .illumos => &.{ "-lm", "-lsocket", "-lnsl", "-lc" },
        .haiku => &.{ "-lm", "-lroot", "-lpthread", "-lc", "-lnetwork" },
        .linux => switch (target.abi) {
            .android, .androideabi, .ohos, .ohoseabi => &.{ "-lm", "-lc", "-ldl" },
            else => &.{ "-lm", "-lpthread", "-lc", "-ldl", "-lrt", "-lutil" },
        },
        else => &.{},
    };
    return result;
}

pub fn clangMightShellOutForAssembly(target: std.Target) bool {
    // Clang defaults to using the system assembler in some cases.
    return target.cpu.arch.isNvptx() or target.cpu.arch == .xcore;
}

/// Each backend architecture in Clang has a different codepath which may or may not
/// support an -mcpu flag.
pub fn clangAssemblerSupportsMcpuArg(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => true,
        else => false,
    };
}

/// Some experimental or poorly-maintained LLVM targets do not properly process CPU models in their
/// Clang driver code. For these, we should omit the `-Xclang -target-cpu -Xclang <model>` flags.
pub fn clangSupportsTargetCpuArg(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .arc,
        .msp430,
        .ve,
        .xcore,
        .xtensa,
        => false,
        else => true,
    };
}

pub fn clangSupportsFloatAbiArg(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .csky,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .s390x,
        .sparc,
        .sparc64,
        => true,
        // We use the target triple for LoongArch.
        .loongarch32, .loongarch64 => false,
        else => false,
    };
}

pub fn clangSupportsNoImplicitFloatArg(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .aarch64,
        .aarch64_be,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .riscv32,
        .riscv64,
        .x86,
        .x86_64,
        => true,
        else => false,
    };
}

pub fn defaultUnwindTables(target: std.Target, libunwind: bool, libtsan: bool) std.builtin.UnwindTables {
    if (target.os.tag == .windows) {
        // The old 32-bit x86 variant of SEH doesn't use tables.
        return if (target.cpu.arch != .x86) .@"async" else .none;
    }
    if (target.os.tag.isDarwin()) return .@"async";
    if (libunwind) return .@"async";
    if (libtsan) return .@"async";
    if (std.debug.Dwarf.abi.supportsUnwinding(target)) return .@"async";
    return .none;
}

pub fn defaultAddressSpace(
    target: std.Target,
    context: enum {
        /// Query the default address space for global constant values.
        global_constant,
        /// Query the default address space for global mutable values.
        global_mutable,
        /// Query the default address space for function-local values.
        local,
        /// Query the default address space for functions themselves.
        function,
    },
) AddressSpace {
    // The default address space for functions on AVR is .flash to produce
    // correct fixups into progmem.
    if (context == .function and target.cpu.arch == .avr) return .flash;
    return .generic;
}

/// Returns true if pointers in `from` can be converted to a pointer in `to`.
pub fn addrSpaceCastIsValid(
    target: std.Target,
    from: AddressSpace,
    to: AddressSpace,
) bool {
    switch (target.cpu.arch) {
        .x86_64, .x86 => return target.cpu.supportsAddressSpace(from, null) and target.cpu.supportsAddressSpace(to, null),
        .nvptx64, .nvptx, .amdgcn => {
            const to_generic = target.cpu.supportsAddressSpace(from, null) and to == .generic;
            const from_generic = target.cpu.supportsAddressSpace(to, null) and from == .generic;
            return to_generic or from_generic;
        },
        else => return from == .generic and to == .generic,
    }
}

/// Under SPIR-V with Vulkan, pointers are not 'real' (physical), but rather 'logical'. Effectively,
/// this means that all such pointers have to be resolvable to a location at compile time, and places
/// a number of restrictions on usage of such pointers. For example, a logical pointer may not be
/// part of a merge (result of a branch) and may not be stored in memory at all. This function returns
/// for a particular architecture and address space wether such pointers are logical.
pub fn arePointersLogical(target: std.Target, as: AddressSpace) bool {
    if (target.os.tag != .vulkan) {
        return false;
    }

    return switch (as) {
        // TODO: Vulkan doesn't support pointers in the generic address space, we
        // should remove this case but this requires a change in defaultAddressSpace().
        // For now, at least disable them from being regarded as physical.
        .generic => true,
        // For now, all global pointers are represented using PhysicalStorageBuffer, so these are real
        // pointers.
        .global => false,
        // TODO: Allowed with VK_KHR_variable_pointers.
        .shared => true,
        .constant, .local, .input, .output, .uniform, .push_constant, .storage_buffer => true,
        else => unreachable,
    };
}

pub fn llvmMachineAbi(target: std.Target) ?[:0]const u8 {
    // LLD does not support ELFv1. Rather than having LLVM produce ELFv1 code and then linking it
    // into a broken ELFv2 binary, just force LLVM to use ELFv2 as well. This will break when glibc
    // is linked as glibc only supports ELFv2 for little endian, but there's nothing we can do about
    // that. With this hack, `powerpc64-linux-none` will at least work.
    //
    // Once our self-hosted linker can handle both ABIs, this hack should go away.
    if (target.cpu.arch == .powerpc64) return "elfv2";

    return switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => "aapcs",
        // TODO: `muslsf` and `muslf32` in LLVM 20.
        .loongarch64 => switch (target.abi) {
            .gnusf => "lp64s",
            .gnuf32 => "lp64f",
            else => "lp64d",
        },
        .loongarch32 => switch (target.abi) {
            .gnusf => "ilp32s",
            .gnuf32 => "ilp32f",
            else => "ilp32d",
        },
        .mips, .mipsel => "o32",
        .mips64, .mips64el => switch (target.abi) {
            .gnuabin32, .muslabin32 => "n32",
            else => "n64",
        },
        .powerpc64 => switch (target.os.tag) {
            .freebsd => if (target.os.version_range.semver.isAtLeast(.{ .major = 13, .minor = 0, .patch = 0 }) orelse false)
                "elfv2"
            else
                "elfv1",
            .openbsd => "elfv2",
            else => if (target.abi.isMusl()) "elfv2" else "elfv1",
        },
        .powerpc64le => "elfv2",
        .riscv64 => b: {
            const featureSetHas = std.Target.riscv.featureSetHas;
            break :b if (featureSetHas(target.cpu.features, .e))
                "lp64e"
            else if (featureSetHas(target.cpu.features, .d))
                "lp64d"
            else if (featureSetHas(target.cpu.features, .f))
                "lp64f"
            else
                "lp64";
        },
        .riscv32 => b: {
            const featureSetHas = std.Target.riscv.featureSetHas;
            break :b if (featureSetHas(target.cpu.features, .e))
                "ilp32e"
            else if (featureSetHas(target.cpu.features, .d))
                "ilp32d"
            else if (featureSetHas(target.cpu.features, .f))
                "ilp32f"
            else
                "ilp32";
        },
        else => null,
    };
}

/// This function returns 1 if function alignment is not observable or settable. Note that this
/// value will not necessarily match the backend's default function alignment (e.g. for LLVM).
pub fn defaultFunctionAlignment(target: std.Target) Alignment {
    // Overrides of the minimum for performance.
    return switch (target.cpu.arch) {
        .csky,
        .thumb,
        .thumbeb,
        .xcore,
        => .@"4",
        .aarch64,
        .aarch64_be,
        .hexagon,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .s390x,
        .x86,
        .x86_64,
        => .@"16",
        .loongarch32,
        .loongarch64,
        => .@"32",
        else => minFunctionAlignment(target),
    };
}

/// This function returns 1 if function alignment is not observable or settable.
pub fn minFunctionAlignment(target: std.Target) Alignment {
    return switch (target.cpu.arch) {
        .riscv32,
        .riscv64,
        => if (std.Target.riscv.featureSetHasAny(target.cpu.features, .{ .c, .zca })) .@"2" else .@"4",
        .thumb,
        .thumbeb,
        .csky,
        .m68k,
        .msp430,
        .s390x,
        .xcore,
        => .@"2",
        .arc,
        .arm,
        .armeb,
        .aarch64,
        .aarch64_be,
        .hexagon,
        .lanai,
        .loongarch32,
        .loongarch64,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .sparc,
        .sparc64,
        .xtensa,
        => .@"4",
        .bpfel,
        .bpfeb,
        .mips64,
        .mips64el,
        => .@"8",
        .ve,
        => .@"16",
        else => .@"1",
    };
}

pub fn supportsFunctionAlignment(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .nvptx,
        .nvptx64,
        .spirv,
        .spirv32,
        .spirv64,
        .wasm32,
        .wasm64,
        => false,
        else => true,
    };
}

pub fn functionPointerMask(target: std.Target) ?u64 {
    // 32-bit Arm uses the LSB to mean that the target function contains Thumb code.
    // MIPS uses the LSB to mean that the target function contains MIPS16/microMIPS code.
    return if (target.cpu.arch.isArm() or target.cpu.arch.isMIPS32())
        ~@as(u32, 1)
    else if (target.cpu.arch.isMIPS64())
        ~@as(u64, 1)
    else
        null;
}

pub fn supportsTailCall(target: std.Target, backend: std.builtin.CompilerBackend) bool {
    switch (backend) {
        .stage1, .stage2_llvm => return @import("codegen/llvm.zig").supportsTailCall(target),
        .stage2_c => return true,
        else => return false,
    }
}

pub fn supportsThreads(target: std.Target, backend: std.builtin.CompilerBackend) bool {
    return switch (backend) {
        .stage2_x86_64 => target.ofmt == .macho or target.ofmt == .elf,
        else => true,
    };
}

pub fn libcFloatPrefix(float_bits: u16) []const u8 {
    return switch (float_bits) {
        16, 80 => "__",
        32, 64, 128 => "",
        else => unreachable,
    };
}

pub fn libcFloatSuffix(float_bits: u16) []const u8 {
    return switch (float_bits) {
        16 => "h", // Non-standard
        32 => "f",
        64 => "",
        80 => "x", // Non-standard
        128 => "q", // Non-standard (mimics convention in GCC libquadmath)
        else => unreachable,
    };
}

pub fn compilerRtFloatAbbrev(float_bits: u16) []const u8 {
    return switch (float_bits) {
        16 => "h",
        32 => "s",
        64 => "d",
        80 => "x",
        128 => "t",
        else => unreachable,
    };
}

pub fn compilerRtIntAbbrev(bits: u16) []const u8 {
    return switch (bits) {
        16 => "h",
        32 => "s",
        64 => "d",
        128 => "t",
        else => "o", // Non-standard
    };
}

pub fn fnCallConvAllowsZigTypes(cc: std.builtin.CallingConvention) bool {
    return switch (cc) {
        .auto, .@"async", .@"inline" => true,
        // For now we want to authorize PTX kernel to use zig objects, even if
        // we end up exposing the ABI. The goal is to experiment with more
        // integrated CPU/GPU code.
        .nvptx_kernel => true,
        else => false,
    };
}

pub fn zigBackend(target: std.Target, use_llvm: bool) std.builtin.CompilerBackend {
    if (use_llvm) return .stage2_llvm;
    if (target.ofmt == .c) return .stage2_c;
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => .stage2_wasm,
        .arm, .armeb, .thumb, .thumbeb => .stage2_arm,
        .x86_64 => .stage2_x86_64,
        .x86 => .stage2_x86,
        .aarch64, .aarch64_be => .stage2_aarch64,
        .riscv64 => .stage2_riscv64,
        .sparc64 => .stage2_sparc64,
        .spirv64 => .stage2_spirv64,
        else => .other,
    };
}

pub inline fn backendSupportsFeature(backend: std.builtin.CompilerBackend, comptime feature: Feature) bool {
    return switch (feature) {
        .panic_fn => switch (backend) {
            .stage2_c,
            .stage2_llvm,
            .stage2_x86_64,
            .stage2_riscv64,
            => true,
            else => false,
        },
        .error_return_trace => switch (backend) {
            .stage2_llvm, .stage2_x86_64 => true,
            else => false,
        },
        .is_named_enum_value => switch (backend) {
            .stage2_llvm, .stage2_x86_64 => true,
            else => false,
        },
        .error_set_has_value => switch (backend) {
            .stage2_llvm, .stage2_wasm, .stage2_x86_64 => true,
            else => false,
        },
        .field_reordering => switch (backend) {
            .stage2_c, .stage2_llvm, .stage2_x86_64 => true,
            else => false,
        },
        .safety_checked_instructions => switch (backend) {
            .stage2_llvm => true,
            else => false,
        },
        .separate_thread => switch (backend) {
            .stage2_llvm => false,
            else => true,
        },
        .all_vector_instructions => switch (backend) {
            .stage2_x86_64 => true,
            else => false,
        },
    };
}
