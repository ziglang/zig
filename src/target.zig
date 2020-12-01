const std = @import("std");
const llvm = @import("llvm.zig");

pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64_be, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabi },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .armeb, .os = .windows, .abi = .gnu },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabi },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .arm, .os = .linux, .abi = .musleabi },
    .{ .arch = .arm, .os = .linux, .abi = .musleabihf },
    .{ .arch = .arm, .os = .windows, .abi = .gnu },
    .{ .arch = .i386, .os = .linux, .abi = .gnu },
    .{ .arch = .i386, .os = .linux, .abi = .musl },
    .{ .arch = .i386, .os = .windows, .abi = .gnu },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64el, .os = .linux, .abi = .musl },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabi64 },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabin32 },
    .{ .arch = .mips64, .os = .linux, .abi = .musl },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnu },
    .{ .arch = .mipsel, .os = .linux, .abi = .musl },
    .{ .arch = .mips, .os = .linux, .abi = .gnu },
    .{ .arch = .mips, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc, .os = .linux, .abi = .musl },
    .{ .arch = .riscv64, .os = .linux, .abi = .gnu },
    .{ .arch = .riscv64, .os = .linux, .abi = .musl },
    .{ .arch = .s390x, .os = .linux, .abi = .gnu },
    .{ .arch = .s390x, .os = .linux, .abi = .musl },
    .{ .arch = .sparc, .os = .linux, .abi = .gnu },
    .{ .arch = .sparcv9, .os = .linux, .abi = .gnu },
    .{ .arch = .wasm32, .os = .freestanding, .abi = .musl },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnu },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnux32 },
    .{ .arch = .x86_64, .os = .linux, .abi = .musl },
    .{ .arch = .x86_64, .os = .windows, .abi = .gnu },
    .{ .arch = .x86_64, .os = .macos, .abi = .gnu },
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
        => return "glibc",
        .musl,
        .musleabi,
        .musleabihf,
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

pub fn archMuslName(arch: std.Target.Cpu.Arch) [:0]const u8 {
    switch (arch) {
        .aarch64, .aarch64_be => return "aarch64",
        .arm, .armeb => return "arm",
        .mips, .mipsel => return "mips",
        .mips64el, .mips64 => return "mips64",
        .powerpc => return "powerpc",
        .powerpc64, .powerpc64le => return "powerpc64",
        .s390x => return "s390x",
        .i386 => return "i386",
        .x86_64 => return "x86_64",
        .riscv64 => return "riscv64",
        .wasm32, .wasm64 => return "wasm",
        else => unreachable,
    }
}

pub fn canBuildLibC(target: std.Target) bool {
    for (available_libcs) |libc| {
        if (target.cpu.arch == libc.arch and target.os.tag == libc.os and target.abi == libc.abi) {
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
    return switch (target.os.tag) {
        .freebsd, .netbsd, .dragonfly, .openbsd, .macos, .ios, .watchos, .tvos => true,
        else => false,
    };
}

pub fn libcNeedsLibUnwind(target: std.Target) bool {
    return switch (target.os.tag) {
        .macos,
        .ios,
        .watchos,
        .tvos,
        .freestanding,
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

pub fn libc_needs_crti_crtn(target: std.Target) bool {
    return !(target.cpu.arch.isRISCV() or target.isAndroid() or target.os.tag == .openbsd);
}

pub fn isSingleThreaded(target: std.Target) bool {
    return target.isWasm();
}

/// Valgrind supports more, but Zig does not support them yet.
pub fn hasValgrindSupport(target: std.Target) bool {
    switch (target.cpu.arch) {
        .x86_64 => {
            return target.os.tag == .linux or target.isDarwin() or target.os.tag == .solaris or
                (target.os.tag == .windows and target.abi != .msvc);
        },
        else => return false,
    }
}

pub fn supportsStackProbing(target: std.Target) bool {
    return target.os.tag != .windows and target.os.tag != .uefi and
        (target.cpu.arch == .i386 or target.cpu.arch == .x86_64);
}

pub fn osToLLVM(os_tag: std.Target.Os.Tag) llvm.OSType {
    return switch (os_tag) {
        .freestanding, .other => .UnknownOS,
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
        .haiku => .Haiku,
        .minix => .Minix,
        .rtems => .RTEMS,
        .nacl => .NaCl,
        .cnk => .CNK,
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
        .hexagon => .hexagon,
        .mips => .mips,
        .mipsel => .mipsel,
        .mips64 => .mips64,
        .mips64el => .mips64el,
        .msp430 => .msp430,
        .powerpc => .ppc,
        .powerpc64 => .ppc64,
        .powerpc64le => .ppc64le,
        .r600 => .r600,
        .amdgcn => .amdgcn,
        .riscv32 => .riscv32,
        .riscv64 => .riscv64,
        .sparc => .sparc,
        .sparcv9 => .sparcv9,
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
        .spu_2 => .UnknownArch,
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
        if (eqlIgnoreCase(ignore_case, name, "util"))
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

pub fn hasDebugInfo(target: std.Target) bool {
    return !target.cpu.arch.isWasm();
}
