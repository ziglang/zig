const std = @import("std");
const Type = @import("type.zig").Type;
const AddressSpace = std.builtin.AddressSpace;
const Alignment = @import("InternPool.zig").Alignment;

pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
    os_ver: ?std.SemanticVersion = null,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64_be, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0, .patch = 0 } },
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
    .{ .arch = .x86, .os = .linux, .abi = .gnu },
    .{ .arch = .x86, .os = .linux, .abi = .musl },
    .{ .arch = .x86, .os = .windows, .abi = .gnu },
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
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 10, .minor = 7, .patch = 0 } },
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
        .gnuf32,
        .gnuf64,
        .gnusf,
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

        .pixel,
        .vertex,
        .geometry,
        .hull,
        .domain,
        .compute,
        .library,
        .raygeneration,
        .intersection,
        .anyhit,
        .closesthit,
        .miss,
        .callable,
        .mesh,
        .amplification,
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
            .x86, .x86_64 => "x86",
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
                return ver.min.order(libc.os_ver.?) != .lt;
            }
            return true;
        }
    }
    return false;
}

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
    return target.os.tag != .windows and target.os.tag != .uefi;
}

pub fn isSingleThreaded(target: std.Target) bool {
    _ = target;
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

fn eqlIgnoreCase(ignore_case: bool, a: []const u8, b: []const u8) bool {
    if (ignore_case) {
        return std.ascii.eqlIgnoreCase(a, b);
    } else {
        return std.mem.eql(u8, a, b);
    }
}

pub fn is_libc_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag == .macos or target.os.tag == .windows;

    if (eqlIgnoreCase(ignore_case, name, "c"))
        return true;

    if (target.isMinGW()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "uuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingw32"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "msvcrt-os"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingwex"))
            return true;

        return false;
    }

    if (target.abi.isGnu() or target.abi.isMusl()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "rt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "pthread"))
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

    if (target.abi.isMusl()) {
        if (eqlIgnoreCase(ignore_case, name, "crypt"))
            return true;
    }

    if (target.os.tag.isDarwin()) {
        if (eqlIgnoreCase(ignore_case, name, "System"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "c"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dbm"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dl"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "info"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "poll"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "proc"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "pthread"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "rpcsvc"))
            return true;
    }

    if (target.os.isAtLeast(.macos, .{ .major = 10, .minor = 8, .patch = 0 }) orelse false) {
        if (eqlIgnoreCase(ignore_case, name, "mx"))
            return true;
    }

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
    if (target.cpu.arch.isNvptx()) {
        // TODO: not sure how to test "ptx >= 7.5" with featureset
        return std.Target.nvptx.featureSetHas(target.cpu.features, .ptx75);
    }

    return true;
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
