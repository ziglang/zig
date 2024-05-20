const std = @import("std");
const Type = @import("type.zig").Type;
const AddressSpace = std.builtin.AddressSpace;
const Alignment = @import("InternPool.zig").Alignment;
const Feature = @import("Module.zig").Feature;

pub const default_stack_protector_buffer_size = 4;

pub fn cannotDynamicLink(target: std.Target) bool {
    return switch (target.os.tag) {
        .freestanding, .other => true,
        else => target.isSpirV(),
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

        .windows => target.abi != .msvc,
        else => true,
    };
}

pub fn requiresPIE(target: std.Target) bool {
    return target.isAndroid() or target.isDarwin() or target.os.tag == .openbsd;
}

/// This function returns whether non-pic code is completely invalid on the given target.
pub fn requiresPIC(target: std.Target, linking_libc: bool) bool {
    return target.isAndroid() or
        target.os.tag == .windows or target.os.tag == .uefi or
        osRequiresLibC(target) or
        (linking_libc and target.isGnuLibC()) or
        (target.abi == .ohos and target.cpu.arch == .aarch64);
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

/// Valgrind supports more, but Zig does not support them yet.
pub fn hasValgrindSupport(target: std.Target) bool {
    switch (target.cpu.arch) {
        .x86,
        .x86_64,
        .aarch64,
        .aarch64_32,
        .aarch64_be,
        => {
            return target.os.tag == .linux or target.os.tag == .solaris or target.os.tag == .illumos or
                (target.os.tag == .windows and target.abi != .msvc);
        },
        else => return false,
    }
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
        .macho,
        .wasm,
        .spirv,
        .hex,
        .raw,
        .nvptx,
        .dxcontainer,
        => {},
    }

    return switch (target.cpu.arch) {
        .arm,
        .armeb,
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        .arc,
        .avr,
        .bpfel,
        .bpfeb,
        .csky,
        .dxil,
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
        .r600,
        .amdgcn,
        .riscv32,
        .riscv64,
        .sparc,
        .sparc64,
        .sparcel,
        .s390x,
        .tce,
        .tcele,
        .thumb,
        .thumbeb,
        .x86,
        .x86_64,
        .xcore,
        .xtensa,
        .nvptx,
        .nvptx64,
        .le32,
        .le64,
        .amdil,
        .amdil64,
        .hsail,
        .hsail64,
        .spir,
        .spir64,
        .spirv,
        .spirv32,
        .spirv64,
        .kalimba,
        .shave,
        .lanai,
        .wasm32,
        .wasm64,
        .renderscript32,
        .renderscript64,
        .ve,
        => true,

        .spu_2 => false,
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
        .spirv32, .spirv64 => return false,
        else => {},
    }
    return switch (backend) {
        .stage2_llvm => true,
        else => false,
    };
}

pub fn clangSupportsStackProtector(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .spirv32, .spirv64 => return false,
        else => true,
    };
}

pub fn libcProvidesStackProtector(target: std.Target) bool {
    return !target.isMinGW() and target.os.tag != .wasi and !target.isSpirV();
}

pub fn supportsReturnAddress(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => target.os.tag == .emscripten,
        .bpfel, .bpfeb => false,
        .spirv32, .spirv64 => false,
        else => true,
    };
}

pub const CompilerRtClassification = enum { none, only_compiler_rt, only_libunwind, both };

pub fn classifyCompilerRtLibName(target: std.Target, name: []const u8) CompilerRtClassification {
    if (target.abi.isGnu() and std.mem.eql(u8, name, "gcc_s")) {
        // libgcc_s includes exception handling functions, so if linking this library
        // is requested, zig needs to instead link libunwind. Otherwise we end up with
        // the linker unable to find `_Unwind_RaiseException` and other related symbols.
        return .both;
    }
    if (std.mem.eql(u8, name, "compiler_rt")) {
        return .only_compiler_rt;
    }
    if (std.mem.eql(u8, name, "unwind")) {
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
            std.Target.nvptx.featureSetHas(target.cpu.features, .ptx81),
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
        .x86_64,
        .x86,
        .aarch64,
        .aarch64_be,
        .aarch64_32,
        => true,

        else => false,
    };
}

pub fn libcFullLinkFlags(target: std.Target) []const []const u8 {
    // The linking order of these is significant and should match the order other
    // c compilers such as gcc or clang use.
    return switch (target.os.tag) {
        .netbsd, .openbsd => &[_][]const u8{
            "-lm",
            "-lpthread",
            "-lc",
            "-lutil",
        },
        .solaris, .illumos => &[_][]const u8{
            "-lm",
            "-lsocket",
            "-lnsl",
            // Solaris releases after 10 merged the threading libraries into libc.
            "-lc",
        },
        .haiku => &[_][]const u8{
            "-lm",
            "-lroot",
            "-lpthread",
            "-lc",
            "-lnetwork",
        },
        else => switch (target.abi) {
            .android => &[_][]const u8{
                "-lm",
                "-lc",
                "-ldl",
            },
            else => &[_][]const u8{
                "-lm",
                "-lpthread",
                "-lc",
                "-ldl",
                "-lrt",
                "-lutil",
            },
        },
    };
}

pub fn clangMightShellOutForAssembly(target: std.Target) bool {
    // Clang defaults to using the system assembler over the internal one
    // when targeting a non-BSD OS.
    return target.cpu.arch.isSPARC();
}

/// Each backend architecture in Clang has a different codepath which may or may not
/// support an -mcpu flag.
pub fn clangAssemblerSupportsMcpuArg(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => true,
        else => false,
    };
}

pub fn needUnwindTables(target: std.Target) bool {
    return target.os.tag == .windows or target.isDarwin() or std.dwarf.abi.supportsUnwinding(target);
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
    const arch = target.cpu.arch;
    switch (arch) {
        .x86_64, .x86 => return arch.supportsAddressSpace(from) and arch.supportsAddressSpace(to),
        .nvptx64, .nvptx, .amdgcn => {
            const to_generic = arch.supportsAddressSpace(from) and to == .generic;
            const from_generic = arch.supportsAddressSpace(to) and from == .generic;
            return to_generic or from_generic;
        },
        else => return from == .generic and to == .generic,
    }
}

pub fn llvmMachineAbi(target: std.Target) ?[:0]const u8 {
    const have_float = switch (target.abi) {
        .gnuilp32 => return "ilp32",
        .gnueabihf, .musleabihf, .eabihf => true,
        else => false,
    };

    switch (target.cpu.arch) {
        .riscv64 => {
            const featureSetHas = std.Target.riscv.featureSetHas;
            if (featureSetHas(target.cpu.features, .d)) {
                return "lp64d";
            } else if (have_float) {
                return "lp64f";
            } else {
                return "lp64";
            }
        },
        .riscv32 => {
            const featureSetHas = std.Target.riscv.featureSetHas;
            if (featureSetHas(target.cpu.features, .d)) {
                return "ilp32d";
            } else if (have_float) {
                return "ilp32f";
            } else if (featureSetHas(target.cpu.features, .e)) {
                return "ilp32e";
            } else {
                return "ilp32";
            }
        },
        //TODO add ARM, Mips, and PowerPC
        else => return null,
    }
}

/// This function returns 1 if function alignment is not observable or settable.
pub fn defaultFunctionAlignment(target: std.Target) Alignment {
    return switch (target.cpu.arch) {
        .arm, .armeb => .@"4",
        .aarch64, .aarch64_32, .aarch64_be => .@"4",
        .sparc, .sparcel, .sparc64 => .@"4",
        .riscv64 => .@"2",
        else => .@"1",
    };
}

pub fn supportsFunctionAlignment(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => false,
        else => true,
    };
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

pub fn fnCallConvAllowsZigTypes(target: std.Target, cc: std.builtin.CallingConvention) bool {
    return switch (cc) {
        .Unspecified, .Async, .Inline => true,
        // For now we want to authorize PTX kernel to use zig objects, even if
        // we end up exposing the ABI. The goal is to experiment with more
        // integrated CPU/GPU code.
        .Kernel => target.cpu.arch == .nvptx or target.cpu.arch == .nvptx64,
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
        .aarch64, .aarch64_be, .aarch64_32 => .stage2_aarch64,
        .riscv64 => .stage2_riscv64,
        .sparc64 => .stage2_sparc64,
        .spirv64 => .stage2_spirv64,
        else => .other,
    };
}

pub fn backendSupportsFeature(
    cpu_arch: std.Target.Cpu.Arch,
    ofmt: std.Target.ObjectFormat,
    use_llvm: bool,
    feature: Feature,
) bool {
    return switch (feature) {
        .panic_fn => ofmt == .c or use_llvm or cpu_arch == .x86_64 or cpu_arch == .riscv64,
        .panic_unwrap_error => ofmt == .c or use_llvm,
        .safety_check_formatted => ofmt == .c or use_llvm,
        .error_return_trace => use_llvm,
        .is_named_enum_value => use_llvm,
        .error_set_has_value => use_llvm or cpu_arch.isWasm(),
        .field_reordering => ofmt == .c or use_llvm,
        .safety_checked_instructions => use_llvm,
    };
}
