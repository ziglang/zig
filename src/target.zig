const std = @import("std");
const llvm = @import("codegen/llvm/bindings.zig");
const Type = @import("type.zig").Type;

pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
    os_ver: ?std.builtin.Version = null,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64_be, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0 } },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 12, .minor = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabi },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .armeb, .os = .windows, .abi = .gnu },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabi },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .arm, .os = .linux, .abi = .musleabi },
    .{ .arch = .arm, .os = .linux, .abi = .musleabihf },
    .{ .arch = .thumb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .thumb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabi },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .arm, .os = .windows, .abi = .gnu },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabi },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .i386, .os = .linux, .abi = .gnu },
    .{ .arch = .i386, .os = .linux, .abi = .musl },
    .{ .arch = .i386, .os = .windows, .abi = .gnu },
    .{ .arch = .m68k, .os = .linux, .abi = .gnu },
    .{ .arch = .m68k, .os = .linux, .abi = .musl },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64el, .os = .linux, .abi = .musl },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64, .os = .linux, .abi = .musl },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabi },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .mipsel, .os = .linux, .abi = .musl },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabi },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .mips, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabi },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .powerpc, .os = .linux, .abi = .musl },
    .{ .arch = .riscv64, .os = .linux, .abi = .gnu },
    .{ .arch = .riscv64, .os = .linux, .abi = .musl },
    .{ .arch = .s390x, .os = .linux, .abi = .gnu },
    .{ .arch = .s390x, .os = .linux, .abi = .musl },
    .{ .arch = .sparc, .os = .linux, .abi = .gnu },
    .{ .arch = .sparc64, .os = .linux, .abi = .gnu },
    .{ .arch = .wasm32, .os = .freestanding, .abi = .musl },
    .{ .arch = .wasm32, .os = .wasi, .abi = .musl },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnu },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnux32 },
    .{ .arch = .x86_64, .os = .linux, .abi = .musl },
    .{ .arch = .x86_64, .os = .windows, .abi = .gnu },
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 10, .minor = 0 } },
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0 } },
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 12, .minor = 0 } },
};

pub fn libCGenericName(target: std.Target) [:0]const u8 {
    switch (target.os.tag) {
        .windows => return "mingw",
        .macos, .ios, .tvos, .watchos => return "darwin",
        else => {},
    }
    switch (target.abi) {
        .gnu,
        .gnuabin32,
        .gnuabi64,
        .gnueabi,
        .gnueabihf,
        .gnux32,
        .gnuilp32,
        => return "glibc",
        .musl,
        .musleabi,
        .musleabihf,
        .muslx32,
        .none,
        => return "musl",
        .code16,
        .eabi,
        .eabihf,
        .android,
        .msvc,
        .itanium,
        .cygnus,
        .coreclr,
        .simulator,
        .macabi,
        => unreachable,
    }
}

pub fn osArchName(target: std.Target) [:0]const u8 {
    return switch (target.os.tag) {
        .linux => switch (target.cpu.arch) {
            .arm, .armeb, .thumb, .thumbeb => "arm",
            .aarch64, .aarch64_be, .aarch64_32 => "aarch64",
            .mips, .mipsel, .mips64, .mips64el => "mips",
            .powerpc, .powerpcle, .powerpc64, .powerpc64le => "powerpc",
            .riscv32, .riscv64 => "riscv",
            .sparc, .sparcel, .sparc64 => "sparc",
            .i386, .x86_64 => "x86",
            else => @tagName(target.cpu.arch),
        },
        else => @tagName(target.cpu.arch),
    };
}

pub fn canBuildLibC(target: std.Target) bool {
    for (available_libcs) |libc| {
        if (target.cpu.arch == libc.arch and target.os.tag == libc.os and target.abi == libc.abi) {
            if (target.os.tag == .macos) {
                const ver = target.os.version_range.semver;
                if (ver.min.major != libc.os_ver.?.major) continue; // no match, keep going
            }
            return true;
        }
    }
    return false;
}

pub fn cannotDynamicLink(target: std.Target) bool {
    return switch (target.os.tag) {
        .freestanding, .other => true,
        else => false,
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
        (linking_libc and target.isGnuLibC());
}

/// This is not whether the target supports Position Independent Code, but whether the -fPIC
/// C compiler argument is valid to Clang.
pub fn supports_fpic(target: std.Target) bool {
    return target.os.tag != .windows;
}

pub fn isSingleThreaded(target: std.Target) bool {
    return target.isWasm();
}

/// Valgrind supports more, but Zig does not support them yet.
pub fn hasValgrindSupport(target: std.Target) bool {
    switch (target.cpu.arch) {
        .x86_64 => {
            return target.os.tag == .linux or target.os.tag == .solaris or
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
        .hexagon,
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
        .i386,
        .x86_64,
        .xcore,
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
        .kalimba,
        .shave,
        .lanai,
        .wasm32,
        .wasm64,
        .renderscript32,
        .renderscript64,
        .ve,
        => true,

        .spu_2,
        .spirv32,
        .spirv64,
        => false,
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
        (target.cpu.arch == .i386 or target.cpu.arch == .x86_64);
}

pub fn supportsReturnAddress(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .wasm32, .wasm64 => target.os.tag == .emscripten,
        .bpfel, .bpfeb => false,
        else => true,
    };
}

pub fn osToLLVM(os_tag: std.Target.Os.Tag) llvm.OSType {
    return switch (os_tag) {
        .freestanding, .other, .opencl, .glsl450, .vulkan, .plan9 => .UnknownOS,
        .windows, .uefi => .Win32,
        .ananas => .Ananas,
        .cloudabi => .CloudABI,
        .dragonfly => .DragonFly,
        .freebsd => .FreeBSD,
        .fuchsia => .Fuchsia,
        .ios => .IOS,
        .kfreebsd => .KFreeBSD,
        .linux => .Linux,
        .lv2 => .Lv2,
        .macos => .MacOSX,
        .netbsd => .NetBSD,
        .openbsd => .OpenBSD,
        .solaris => .Solaris,
        .zos => .ZOS,
        .haiku => .Haiku,
        .minix => .Minix,
        .rtems => .RTEMS,
        .nacl => .NaCl,
        .aix => .AIX,
        .cuda => .CUDA,
        .nvcl => .NVCL,
        .amdhsa => .AMDHSA,
        .ps4 => .PS4,
        .elfiamcu => .ELFIAMCU,
        .tvos => .TvOS,
        .watchos => .WatchOS,
        .mesa3d => .Mesa3D,
        .contiki => .Contiki,
        .amdpal => .AMDPAL,
        .hermit => .HermitCore,
        .hurd => .Hurd,
        .wasi => .WASI,
        .emscripten => .Emscripten,
    };
}

pub fn archToLLVM(arch_tag: std.Target.Cpu.Arch) llvm.ArchType {
    return switch (arch_tag) {
        .arm => .arm,
        .armeb => .armeb,
        .aarch64 => .aarch64,
        .aarch64_be => .aarch64_be,
        .aarch64_32 => .aarch64_32,
        .arc => .arc,
        .avr => .avr,
        .bpfel => .bpfel,
        .bpfeb => .bpfeb,
        .csky => .csky,
        .hexagon => .hexagon,
        .m68k => .m68k,
        .mips => .mips,
        .mipsel => .mipsel,
        .mips64 => .mips64,
        .mips64el => .mips64el,
        .msp430 => .msp430,
        .powerpc => .ppc,
        .powerpcle => .ppcle,
        .powerpc64 => .ppc64,
        .powerpc64le => .ppc64le,
        .r600 => .r600,
        .amdgcn => .amdgcn,
        .riscv32 => .riscv32,
        .riscv64 => .riscv64,
        .sparc => .sparc,
        .sparc64 => .sparcv9, // In LLVM, sparc64 == sparcv9.
        .sparcel => .sparcel,
        .s390x => .systemz,
        .tce => .tce,
        .tcele => .tcele,
        .thumb => .thumb,
        .thumbeb => .thumbeb,
        .i386 => .x86,
        .x86_64 => .x86_64,
        .xcore => .xcore,
        .nvptx => .nvptx,
        .nvptx64 => .nvptx64,
        .le32 => .le32,
        .le64 => .le64,
        .amdil => .amdil,
        .amdil64 => .amdil64,
        .hsail => .hsail,
        .hsail64 => .hsail64,
        .spir => .spir,
        .spir64 => .spir64,
        .kalimba => .kalimba,
        .shave => .shave,
        .lanai => .lanai,
        .wasm32 => .wasm32,
        .wasm64 => .wasm64,
        .renderscript32 => .renderscript32,
        .renderscript64 => .renderscript64,
        .ve => .ve,
        .spu_2, .spirv32, .spirv64 => .UnknownArch,
    };
}

fn eqlIgnoreCase(ignore_case: bool, a: []const u8, b: []const u8) bool {
    if (ignore_case) {
        return std.ascii.eqlIgnoreCase(a, b);
    } else {
        return std.mem.eql(u8, a, b);
    }
}

pub fn is_libc_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    if (eqlIgnoreCase(ignore_case, name, "c"))
        return true;

    if (target.isMinGW()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;

        return false;
    }

    if (target.abi.isGnu() or target.abi.isMusl() or target.os.tag.isDarwin()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "rt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "pthread"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "crypt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "util"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "xnet"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "resolv"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dl"))
            return true;
    }

    if (target.os.tag.isDarwin() and eqlIgnoreCase(ignore_case, name, "System"))
        return true;

    return false;
}

pub fn is_libcpp_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    return eqlIgnoreCase(ignore_case, name, "c++") or
        eqlIgnoreCase(ignore_case, name, "stdc++") or
        eqlIgnoreCase(ignore_case, name, "c++abi");
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
    _ = target;
    return true;
}

pub fn defaultCompilerRtOptimizeMode(target: std.Target) std.builtin.Mode {
    if (target.cpu.arch.isWasm() and target.os.tag == .freestanding) {
        return .ReleaseSmall;
    } else {
        return .ReleaseFast;
    }
}

pub fn hasRedZone(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .x86_64,
        .i386,
        .powerpc,
        .powerpc64,
        .powerpc64le,
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
        .solaris => &[_][]const u8{
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
    return target.os.tag == .windows;
}

pub const AtomicPtrAlignmentError = error{
    FloatTooBig,
    IntTooBig,
    BadType,
};

pub const AtomicPtrAlignmentDiagnostics = struct {
    bits: u16 = undefined,
    max_bits: u16 = undefined,
};

/// If ABI alignment of `ty` is OK for atomic operations, returns 0.
/// Otherwise returns the alignment required on a pointer for the target
/// to perform atomic operations.
pub fn atomicPtrAlignment(
    target: std.Target,
    ty: Type,
    diags: *AtomicPtrAlignmentDiagnostics,
) AtomicPtrAlignmentError!u32 {
    // TODO this was ported from stage1 but it does not take into account CPU features,
    // which can affect this value. Audit this!
    const max_atomic_bits: u16 = switch (target.cpu.arch) {
        .avr,
        .msp430,
        .spu_2,
        => 16,

        .arc,
        .arm,
        .armeb,
        .hexagon,
        .m68k,
        .le32,
        .mips,
        .mipsel,
        .nvptx,
        .powerpc,
        .powerpcle,
        .r600,
        .riscv32,
        .sparc,
        .sparcel,
        .tce,
        .tcele,
        .thumb,
        .thumbeb,
        .i386,
        .xcore,
        .amdil,
        .hsail,
        .spir,
        .kalimba,
        .lanai,
        .shave,
        .wasm32,
        .renderscript32,
        .csky,
        .spirv32,
        => 32,

        .aarch64,
        .aarch64_be,
        .aarch64_32,
        .amdgcn,
        .bpfel,
        .bpfeb,
        .le64,
        .mips64,
        .mips64el,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .riscv64,
        .sparc64,
        .s390x,
        .amdil64,
        .hsail64,
        .spir64,
        .wasm64,
        .renderscript64,
        .ve,
        .spirv64,
        => 64,

        .x86_64 => 128,
    };

    var buffer: Type.Payload.Bits = undefined;

    const int_ty = switch (ty.zigTypeTag()) {
        .Int => ty,
        .Enum => ty.intTagType(&buffer),
        .Float => {
            const bit_count = ty.floatBits(target);
            if (bit_count > max_atomic_bits) {
                diags.* = .{
                    .bits = bit_count,
                    .max_bits = max_atomic_bits,
                };
                return error.FloatTooBig;
            }
            return 0;
        },
        .Bool => return 0,
        else => {
            if (ty.isPtrAtRuntime()) return 0;
            return error.BadType;
        },
    };

    const bit_count = int_ty.intInfo(target).bits;
    if (bit_count > max_atomic_bits) {
        diags.* = .{
            .bits = bit_count,
            .max_bits = max_atomic_bits,
        };
        return error.IntTooBig;
    }

    return 0;
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
) std.builtin.AddressSpace {
    _ = target;
    _ = context;
    return .generic;
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

pub fn defaultFunctionAlignment(target: std.Target) u32 {
    return switch (target.cpu.arch) {
        .arm, .armeb => 4,
        .aarch64, .aarch64_32, .aarch64_be => 4,
        .sparc, .sparcel, .sparc64 => 4,
        .riscv64 => 2,
        else => 1,
    };
}
