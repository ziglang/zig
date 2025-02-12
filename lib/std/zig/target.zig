pub const ArchOsAbi = struct {
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
    os_ver: ?std.SemanticVersion = null,

    /// Minimum glibc version that provides support for the arch/OS when ABI is GNU. Note that Zig
    /// can only target glibc 2.2.5+, so `null` means the minimum is older than that.
    glibc_min: ?std.SemanticVersion = null,
    /// Override for `glibcRuntimeTriple` when glibc has an unusual directory name for the target.
    glibc_triple: ?[]const u8 = null,
};

pub const available_libcs = [_]ArchOsAbi{
    .{ .arch = .arc, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 4, .minor = 2, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 32, .patch = 0 } },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .arm, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .arm, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .arm, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .armeb, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .thumb, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 2, .minor = 1, .patch = 0 } },
    .{ .arch = .thumb, .os = .windows, .abi = .gnu },
    .{ .arch = .thumbeb, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .thumbeb, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .aarch64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 3, .minor = 7, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 17, .patch = 0 } },
    .{ .arch = .aarch64, .os = .linux, .abi = .musl, .os_ver = .{ .major = 3, .minor = 7, .patch = 0 } },
    .{ .arch = .aarch64, .os = .macos, .abi = .none, .os_ver = .{ .major = 11, .minor = 0, .patch = 0 } },
    .{ .arch = .aarch64, .os = .windows, .abi = .gnu },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 3, .minor = 13, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 17, .patch = 0 } },
    .{ .arch = .aarch64_be, .os = .linux, .abi = .musl, .os_ver = .{ .major = 3, .minor = 13, .patch = 0 } },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 4, .minor = 20, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 29, .patch = 0 }, .glibc_triple = "csky-linux-gnuabiv2-soft" },
    .{ .arch = .csky, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 4, .minor = 20, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 29, .patch = 0 }, .glibc_triple = "csky-linux-gnuabiv2" },
    .{ .arch = .loongarch64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 5, .minor = 19, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 36, .patch = 0 }, .glibc_triple = "loongarch64-linux-gnu-lp64d" },
    .{ .arch = .loongarch64, .os = .linux, .abi = .gnusf, .os_ver = .{ .major = 5, .minor = 19, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 36, .patch = 0 }, .glibc_triple = "loongarch64-linux-gnu-lp64s" },
    .{ .arch = .loongarch64, .os = .linux, .abi = .musl, .os_ver = .{ .major = 5, .minor = 19, .patch = 0 } },
    .{ .arch = .m68k, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 1, .minor = 3, .patch = 94 } },
    .{ .arch = .m68k, .os = .linux, .abi = .musl, .os_ver = .{ .major = 1, .minor = 3, .patch = 94 } },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 }, .glibc_triple = "mips-linux-gnu-soft" },
    .{ .arch = .mips, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 }, .glibc_triple = "mips-linux-gnu" },
    .{ .arch = .mips, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 } },
    .{ .arch = .mips, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 } },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 }, .glibc_triple = "mipsel-linux-gnu-soft" },
    .{ .arch = .mipsel, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 }, .glibc_triple = "mipsel-linux-gnu" },
    .{ .arch = .mipsel, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 } },
    .{ .arch = .mipsel, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 1, .minor = 1, .patch = 82 } },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabi64, .os_ver = .{ .major = 2, .minor = 3, .patch = 48 }, .glibc_triple = "mips64-linux-gnu-n64" },
    .{ .arch = .mips64, .os = .linux, .abi = .gnuabin32, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 }, .glibc_triple = "mips64-linux-gnu-n32" },
    .{ .arch = .mips64, .os = .linux, .abi = .muslabi64, .os_ver = .{ .major = 2, .minor = 3, .patch = 48 } },
    .{ .arch = .mips64, .os = .linux, .abi = .muslabin32, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabi64, .os_ver = .{ .major = 2, .minor = 3, .patch = 48 }, .glibc_triple = "mips64el-linux-gnu-n64" },
    .{ .arch = .mips64el, .os = .linux, .abi = .gnuabin32, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 }, .glibc_triple = "mips64el-linux-gnu-n32" },
    .{ .arch = .mips64el, .os = .linux, .abi = .muslabi64, .os_ver = .{ .major = 2, .minor = 3, .patch = 48 } },
    .{ .arch = .mips64el, .os = .linux, .abi = .muslabin32, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabi, .os_ver = .{ .major = 1, .minor = 3, .patch = 45 }, .glibc_triple = "powerpc-linux-gnu-soft" },
    .{ .arch = .powerpc, .os = .linux, .abi = .gnueabihf, .os_ver = .{ .major = 1, .minor = 3, .patch = 45 }, .glibc_triple = "powerpc-linux-gnu" },
    .{ .arch = .powerpc, .os = .linux, .abi = .musleabi, .os_ver = .{ .major = 1, .minor = 3, .patch = 45 } },
    .{ .arch = .powerpc, .os = .linux, .abi = .musleabihf, .os_ver = .{ .major = 1, .minor = 3, .patch = 45 } },
    .{ .arch = .powerpc64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .powerpc64, .os = .linux, .abi = .musl, .os_ver = .{ .major = 2, .minor = 6, .patch = 0 } },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 3, .minor = 14, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 19, .patch = 0 } },
    .{ .arch = .powerpc64le, .os = .linux, .abi = .musl, .os_ver = .{ .major = 3, .minor = 14, .patch = 0 } },
    .{ .arch = .riscv32, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 4, .minor = 15, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 33, .patch = 0 }, .glibc_triple = "riscv32-linux-gnu-rv32imafdc-ilp32d" },
    .{ .arch = .riscv32, .os = .linux, .abi = .musl, .os_ver = .{ .major = 4, .minor = 15, .patch = 0 } },
    .{ .arch = .riscv64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 4, .minor = 15, .patch = 0 }, .glibc_min = .{ .major = 2, .minor = 27, .patch = 0 }, .glibc_triple = "riscv64-linux-gnu-rv64imafdc-lp64d" },
    .{ .arch = .riscv64, .os = .linux, .abi = .musl, .os_ver = .{ .major = 4, .minor = 15, .patch = 0 } },
    .{ .arch = .s390x, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 2, .minor = 4, .patch = 2 } },
    .{ .arch = .s390x, .os = .linux, .abi = .musl, .os_ver = .{ .major = 2, .minor = 4, .patch = 2 } },
    .{ .arch = .sparc, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 2, .minor = 1, .patch = 19 }, .glibc_triple = "sparcv9-linux-gnu" },
    .{ .arch = .sparc64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 2, .minor = 1, .patch = 19 } },
    .{ .arch = .wasm32, .os = .wasi, .abi = .musl },
    .{ .arch = .x86, .os = .linux, .abi = .gnu, .glibc_triple = "i686-linux-gnu" },
    .{ .arch = .x86, .os = .linux, .abi = .musl },
    .{ .arch = .x86, .os = .windows, .abi = .gnu },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnu, .os_ver = .{ .major = 2, .minor = 6, .patch = 4 } },
    .{ .arch = .x86_64, .os = .linux, .abi = .gnux32, .os_ver = .{ .major = 3, .minor = 4, .patch = 0 }, .glibc_triple = "x86_64-linux-gnu-x32" },
    .{ .arch = .x86_64, .os = .linux, .abi = .musl, .os_ver = .{ .major = 2, .minor = 6, .patch = 4 } },
    .{ .arch = .x86_64, .os = .linux, .abi = .muslx32, .os_ver = .{ .major = 3, .minor = 4, .patch = 0 } },
    .{ .arch = .x86_64, .os = .macos, .abi = .none, .os_ver = .{ .major = 10, .minor = 7, .patch = 0 } },
    .{ .arch = .x86_64, .os = .windows, .abi = .gnu },
};

pub fn canBuildLibC(target: std.Target) bool {
    for (available_libcs) |libc| {
        if (target.cpu.arch == libc.arch and target.os.tag == libc.os and target.abi == libc.abi) {
            if (libc.os_ver) |libc_os_ver| {
                if (switch (target.os.versionRange()) {
                    .semver => |v| v,
                    .linux => |v| v.range,
                    else => null,
                }) |ver| {
                    if (ver.min.order(libc_os_ver) == .lt) return false;
                }
            }
            if (libc.glibc_min) |glibc_min| {
                if (target.os.versionRange().gnuLibCVersion().?.order(glibc_min) == .lt) return false;
            }
            return true;
        }
    }
    return false;
}

/// Returns the subdirectory triple to be used to find the correct glibc for the given `arch`, `os`,
/// and `abi` in an installation directory created by glibc's `build-many-glibcs.py` script.
///
/// `os` must be `.linux` or `.hurd`. `abi` must be a GNU ABI, i.e. `.isGnu()`.
pub fn glibcRuntimeTriple(
    allocator: Allocator,
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os.Tag,
    abi: std.Target.Abi,
) Allocator.Error![]const u8 {
    assert(abi.isGnu());

    for (available_libcs) |libc| {
        if (libc.arch == arch and libc.os == os and libc.abi == abi) {
            if (libc.glibc_triple) |triple| return allocator.dupe(u8, triple);
        }
    }

    return switch (os) {
        .hurd => std.Target.hurdTupleSimple(allocator, arch, abi),
        .linux => std.Target.linuxTripleSimple(allocator, arch, os, abi),
        else => unreachable,
    };
}

pub fn muslArchName(arch: std.Target.Cpu.Arch, abi: std.Target.Abi) [:0]const u8 {
    return switch (abi) {
        .muslabin32 => "mipsn32",
        .muslx32 => "x32",
        else => switch (arch) {
            .arm, .armeb, .thumb, .thumbeb => "arm",
            .aarch64, .aarch64_be => "aarch64",
            .loongarch64 => "loongarch64",
            .m68k => "m68k",
            .mips, .mipsel => "mips",
            .mips64el, .mips64 => "mips64",
            .powerpc => "powerpc",
            .powerpc64, .powerpc64le => "powerpc64",
            .riscv32 => "riscv32",
            .riscv64 => "riscv64",
            .s390x => "s390x",
            .wasm32, .wasm64 => "wasm",
            .x86 => "i386",
            .x86_64 => "x86_64",
            else => unreachable,
        },
    };
}

pub fn muslArchNameHeaders(arch: std.Target.Cpu.Arch) [:0]const u8 {
    return switch (arch) {
        .x86 => "x86",
        else => muslArchName(arch, .musl),
    };
}

pub fn muslAbiNameHeaders(abi: std.Target.Abi) [:0]const u8 {
    return switch (abi) {
        .muslabin32 => "muslabin32",
        .muslx32 => "muslx32",
        else => "musl",
    };
}

pub fn isLibCLibName(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    if (eqlIgnoreCase(ignore_case, name, "c"))
        return true;

    if (target.isMinGW()) {
        if (eqlIgnoreCase(ignore_case, name, "adsiid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "amstrmid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "bits"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "delayimp"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dloadhelper"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dmoguids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxerr8"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxerr9"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxguid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "ksguid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "largeint"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mfuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingw32"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingwex"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingwthrd"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "moldname"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "msvcrt-os"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "portabledeviceguids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "pthread"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "scrnsave"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "scrnsavw"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "strmiids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "uuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "wbemuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "winpthread"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "wmcodecdspuuid"))
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
        if (eqlIgnoreCase(ignore_case, name, "resolv"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dl"))
            return true;
    }

    if (target.abi.isMusl()) {
        if (eqlIgnoreCase(ignore_case, name, "crypt"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "xnet"))
            return true;

        if (target.os.tag == .wasi) {
            if (eqlIgnoreCase(ignore_case, name, "wasi-emulated-getpid"))
                return true;
            if (eqlIgnoreCase(ignore_case, name, "wasi-emulated-mman"))
                return true;
            if (eqlIgnoreCase(ignore_case, name, "wasi-emulated-process-clocks"))
                return true;
            if (eqlIgnoreCase(ignore_case, name, "wasi-emulated-signal"))
                return true;
        }
    }

    if (target.os.tag.isDarwin()) {
        if (eqlIgnoreCase(ignore_case, name, "System"))
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

    if (target.os.tag == .haiku) {
        if (eqlIgnoreCase(ignore_case, name, "root"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "network"))
            return true;
    }

    return false;
}

pub fn isLibCxxLibName(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag.isDarwin() or target.os.tag == .windows;

    return eqlIgnoreCase(ignore_case, name, "c++") or
        eqlIgnoreCase(ignore_case, name, "stdc++") or
        eqlIgnoreCase(ignore_case, name, "c++abi") or
        eqlIgnoreCase(ignore_case, name, "supc++");
}

fn eqlIgnoreCase(ignore_case: bool, a: []const u8, b: []const u8) bool {
    if (ignore_case) {
        return std.ascii.eqlIgnoreCase(a, b);
    } else {
        return std.mem.eql(u8, a, b);
    }
}

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
