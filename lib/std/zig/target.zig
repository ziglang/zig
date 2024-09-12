pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
    os_ver: ?std.SemanticVersion = null,

    // Minimum glibc version that provides support for the arch/os when ABI is GNU.
    glibc_min: ?std.SemanticVersion = null,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 17, .patch = 0 } },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 17, .patch = 0 } },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0, .patch = 0 } },
    .{ .arch = .arc, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 32, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabi },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabi },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabi },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .arm, .os = .linux, .abi = .musleabi },
    .{ .arch = .arm, .os = .linux, .abi = .musleabihf },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabi },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .thumbeb, .os = .linux, .abi = .musleabi },
    .{ .arch = .thumbeb, .os = .linux, .abi = .musleabihf },
    .{ .arch = .thumb, .os = .windows, .abi = .gnu },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabi, .glibc_min = .{ .major = 2, .minor = 29, .patch = 0 } },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabihf, .glibc_min = .{ .major = 2, .minor = 29, .patch = 0 } },
    .{ .arch = .x86, .os = .linux, .abi = .gnu },
    .{ .arch = .x86, .os = .linux, .abi = .musl },
    .{ .arch = .x86, .os = .windows, .abi = .gnu },
    .{ .arch = .loongarch64, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 36, .patch = 0 } },
    .{ .arch = .loongarch64, .os = .linux, .abi = .musl },
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
    .{ .arch = .mipsel, .os = .linux, .abi = .musleabi },
    .{ .arch = .mipsel, .os = .linux, .abi = .musleabihf },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabi },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .mips, .os = .linux, .abi = .musleabi },
    .{ .arch = .mips, .os = .linux, .abi = .musleabihf },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 19, .patch = 0 } },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc64, .os = .linux, .abi = .gnu },
    .{ .arch = .powerpc64, .os = .linux, .abi = .musl },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabi },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabihf },
    .{ .arch = .powerpc, .os = .linux, .abi = .musleabi },
    .{ .arch = .powerpc, .os = .linux, .abi = .musleabihf },
    .{ .arch = .riscv32, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 33, .patch = 0 } },
    .{ .arch = .riscv32, .os = .linux, .abi = .musl },
    .{ .arch = .riscv64, .os = .linux, .abi = .gnu, .glibc_min = .{ .major = 2, .minor = 27, .patch = 0 } },
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

pub fn canBuildLibC(target: std.Target) bool {
    for (available_libcs) |libc| {
        if (target.cpu.arch == libc.arch and target.os.tag == libc.os and target.abi == libc.abi) {
            if (target.os.tag == .macos) {
                const ver = target.os.version_range.semver;
                return ver.min.order(libc.os_ver.?) != .lt;
            }
            // Ensure glibc (aka *-linux-gnu) version is supported
            if (target.isGnuLibC()) {
                const min_glibc_ver = libc.glibc_min orelse return true;
                const target_glibc_ver = target.os.version_range.linux.glibc;
                return target_glibc_ver.order(min_glibc_ver) != .lt;
            }
            return true;
        }
    }
    return false;
}

pub fn muslArchNameHeaders(arch: std.Target.Cpu.Arch) [:0]const u8 {
    return switch (arch) {
        .x86 => return "x86",
        else => muslArchName(arch),
    };
}

pub fn muslArchName(arch: std.Target.Cpu.Arch) [:0]const u8 {
    switch (arch) {
        .aarch64, .aarch64_be => return "aarch64",
        .arm, .armeb, .thumb, .thumbeb => return "arm",
        .x86 => return "i386",
        .loongarch64 => return "loongarch64",
        .m68k => return "m68k",
        .mips, .mipsel => return "mips",
        .mips64el, .mips64 => return "mips64",
        .powerpc => return "powerpc",
        .powerpc64, .powerpc64le => return "powerpc64",
        .riscv32 => return "riscv32",
        .riscv64 => return "riscv64",
        .s390x => return "s390x",
        .wasm32, .wasm64 => return "wasm",
        .x86_64 => return "x86_64",
        else => unreachable,
    }
}

const std = @import("std");
