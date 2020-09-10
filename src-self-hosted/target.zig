const std = @import("std");

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
};

pub fn libCGenericName(target: std.Target) [:0]const u8 {
    if (target.os.tag == .windows)
        return "mingw";
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

pub fn osRequiresLibC(target: std.Target) bool {
    // On Darwin, we always link libSystem which contains libc.
    // Similarly on FreeBSD and NetBSD we always link system libc
    // since this is the stable syscall interface.
    return switch (target.os.tag) {
        .freebsd, .netbsd, .dragonfly, .macosx, .ios, .watchos, .tvos => true,
        else => false,
    };
}

pub fn requiresPIE(target: std.Target) bool {
    return target.isAndroid();
}

pub fn libc_needs_crti_crtn(target: std.Target) bool {
    return !(target.cpu.arch.isRISCV() or target.isAndroid());
}
