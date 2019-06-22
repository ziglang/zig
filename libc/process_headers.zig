// To get started, run this tool with no args and read the help message.
//
// The build systems of musl-libc and glibc require specifying a single target
// architecture. Meanwhile, Zig supports out-of-the-box cross compilation for
// every target. So the process to create libc headers that Zig ships is to use
// this tool.
// First, use the musl/glibc build systems to create installations of all the
// targets in the `glibc_targets`/`musl_targets` variables.
// Next, run this tool to create a new directory which puts .h files into
// <arch> subdirectories, with `generic` being files that apply to all architectures.
// You'll then have to manually update Zig source repo with these new files.

const std = @import("std");
const builtin = @import("builtin");
const Arch = builtin.Arch;
const Abi = builtin.Abi;
const Os = builtin.Os;
const assert = std.debug.assert;

const LibCTarget = struct {
    name: []const u8,
    zig_arch: ?@TagType(Arch),
    zig_abi: ?Abi,
};

const glibc_targets = []LibCTarget{
    LibCTarget{
        .name = "aarch64_be-linux-gnu",
        .zig_arch = Arch.aarch64_be,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "aarch64-linux-gnu",
        .zig_arch = Arch.aarch64,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "aarch64-linux-gnu-disable-multi-arch",
        .zig_arch = Arch.aarch64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "alpha-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "armeb-linux-gnueabi",
        .zig_arch = Arch.armeb,
        .zig_abi = Abi.gnueabi,
    },
    LibCTarget{
        .name = "armeb-linux-gnueabi-be8",
        .zig_arch = Arch.armeb,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "armeb-linux-gnueabihf",
        .zig_arch = Arch.armeb,
        .zig_abi = Abi.gnueabihf,
    },
    LibCTarget{
        .name = "armeb-linux-gnueabihf-be8",
        .zig_arch = Arch.armeb,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "arm-linux-gnueabi",
        .zig_arch = Arch.arm,
        .zig_abi = Abi.gnueabi,
    },
    LibCTarget{
        .name = "arm-linux-gnueabihf",
        .zig_arch = Arch.arm,
        .zig_abi = Abi.gnueabihf,
    },
    LibCTarget{
        .name = "arm-linux-gnueabihf-v7a",
        .zig_arch = Arch.arm,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "arm-linux-gnueabihf-v7a-disable-multi-arch",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "hppa-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "i486-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "i586-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "i686-gnu",
        .zig_arch = Arch.i386,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "i686-linux-gnu",
        .zig_arch = Arch.i386,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "i686-linux-gnu-disable-multi-arch",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "i686-linux-gnu-enable-obsolete",
        .zig_arch = Arch.i386,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "i686-linux-gnu-static-pie",
        .zig_arch = Arch.i386,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "ia64-linux-gnu",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "m68k-linux-gnu",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "m68k-linux-gnu-coldfire",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "m68k-linux-gnu-coldfire-soft",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "microblazeel-linux-gnu",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "microblaze-linux-gnu",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n32",
        .zig_arch = Arch.mips64el,
        .zig_abi = Abi.gnuabin32,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n32-nan2008",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n32-nan2008-soft",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n32-soft",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n64",
        .zig_arch = Arch.mips64el,
        .zig_abi = Abi.gnuabi64,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n64-nan2008",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n64-nan2008-soft",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n64-soft",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n32",
        .zig_arch = Arch.mips64,
        .zig_abi = Abi.gnuabin32,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n32-nan2008",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n32-nan2008-soft",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n32-soft",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n64",
        .zig_arch = Arch.mips64,
        .zig_abi = Abi.gnuabi64,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n64-nan2008",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n64-nan2008-soft",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n64-soft",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mipsel-linux-gnu",
        .zig_arch = Arch.mipsel,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "mipsel-linux-gnu-nan2008",
        .zig_arch = Arch.mipsel,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mipsel-linux-gnu-nan2008-soft",
        .zig_arch = Arch.mipsel,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mipsel-linux-gnu-soft",
        .zig_arch = Arch.mipsel,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips-linux-gnu",
        .zig_arch = Arch.mips,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "mips-linux-gnu-nan2008",
        .zig_arch = Arch.mips,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips-linux-gnu-nan2008-soft",
        .zig_arch = Arch.mips,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips-linux-gnu-soft",
        .zig_arch = Arch.mips,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "nios2-linux-gnu",
        .zig_arch = Arch.nios2,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "powerpc64le-linux-gnu",
        .zig_arch = Arch.powerpc64le,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "powerpc64-linux-gnu",
        .zig_arch = Arch.powerpc64,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "powerpc-linux-gnu",
        .zig_arch = Arch.powerpc,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "powerpc-linux-gnu-power4",
        .zig_arch = Arch.powerpc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "powerpc-linux-gnu-soft",
        .zig_arch = Arch.powerpc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "powerpc-linux-gnuspe",
        .zig_arch = Arch.powerpc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "powerpc-linux-gnuspe-e500v1",
        .zig_arch = Arch.powerpc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "riscv64-linux-gnu-rv64imac-lp64",
        .zig_arch = Arch.riscv64,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "riscv64-linux-gnu-rv64imafdc-lp64",
        .zig_arch = Arch.riscv64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "riscv64-linux-gnu-rv64imafdc-lp64d",
        .zig_arch = Arch.riscv64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "s390-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "s390x-linux-gnu",
        .zig_arch = Arch.s390x,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sh3eb-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sh3-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sh4eb-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sh4eb-linux-gnu-soft",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "sh4-linux-gnu",
        .zig_arch = null,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sh4-linux-gnu-soft",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "sparc64-linux-gnu",
        .zig_arch = Arch.sparc,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sparc64-linux-gnu-disable-multi-arch",
        .zig_arch = Arch.sparc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "sparcv9-linux-gnu",
        .zig_arch = Arch.sparcv9,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "sparcv9-linux-gnu-disable-multi-arch",
        .zig_arch = Arch.sparcv9,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu",
        .zig_arch = Arch.x86_64,
        .zig_abi = Abi.gnu,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-disable-multi-arch",
        .zig_arch = Arch.x86_64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-enable-obsolete",
        .zig_arch = Arch.x86_64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-static-pie",
        .zig_arch = Arch.x86_64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-x32",
        .zig_arch = Arch.x86_64,
        .zig_abi = Abi.gnux32,
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-x32-static-pie",
        .zig_arch = Arch.x86_64,
        .zig_abi = null,
    },
};
const musl_targets = []LibCTarget{
    LibCTarget{
        .name = "aarch64_be-linux-musl-native",
        .zig_arch = Arch.aarch64_be,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "aarch64-linux-musleabi-native",
        .zig_arch = Arch.aarch64,
        .zig_abi = Abi.musleabi,
    },
    LibCTarget{
        .name = "armeb-linux-musleabihf-native",
        .zig_arch = Arch.armeb,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "armeb-linux-musleabi-native",
        .zig_arch = Arch.armeb,
        .zig_abi = Abi.musleabi,
    },
    LibCTarget{
        .name = "armel-linux-musleabihf-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "armel-linux-musleabi-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabi,
    },
    LibCTarget{
        .name = "arm-linux-musleabihf-native",
        .zig_arch = Arch.arm,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "arm-linux-musleabi-native",
        .zig_arch = Arch.arm,
        .zig_abi = Abi.musleabi,
    },
    LibCTarget{
        .name = "armv5l-linux-musleabihf-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "armv7l-linux-musleabihf-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "armv7m-linux-musleabi-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabi,
    },
    LibCTarget{
        .name = "armv7r-linux-musleabihf-native",
        .zig_arch = null,
        .zig_abi = Abi.musleabihf,
    },
    LibCTarget{
        .name = "i486-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "i686-linux-musl-native",
        .zig_arch = Arch.i386,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "i686-w64-mingw32-native",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "m68k-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "microblazeel-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "microblaze-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mips64el-linux-musln32-native",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-musln32sf-native",
        .zig_arch = Arch.mips64el,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64el-linux-musl-native",
        .zig_arch = Arch.mips64el,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mips64-linux-musln32-native",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-musln32sf-native",
        .zig_arch = Arch.mips64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips64-linux-musl-native",
        .zig_arch = Arch.mips64,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mipsel-linux-musln32-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mipsel-linux-musln32sf-native",
        .zig_arch = Arch.mipsel,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mipsel-linux-musl-native",
        .zig_arch = Arch.mipsel,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mipsel-linux-muslsf-native",
        .zig_arch = Arch.mipsel,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips-linux-musln32sf-native",
        .zig_arch = Arch.mips,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "mips-linux-musl-native",
        .zig_arch = Arch.mips,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "mips-linux-muslsf-native",
        .zig_arch = Arch.mips,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "or1k-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "powerpc64le-linux-musl-native",
        .zig_arch = Arch.powerpc64le,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "powerpc64-linux-musl-native",
        .zig_arch = Arch.powerpc64,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "powerpcle-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "powerpcle-linux-muslsf-native",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "powerpc-linux-musl-native",
        .zig_arch = Arch.powerpc,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "powerpc-linux-muslsf-native",
        .zig_arch = Arch.powerpc,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "riscv32-linux-musl-native",
        .zig_arch = Arch.riscv32,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "riscv64-linux-musl-native",
        .zig_arch = Arch.riscv64,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "s390x-linux-musl-native",
        .zig_arch = Arch.s390x,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "sh2eb-linux-muslfdpic-native",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "sh2eb-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "sh2-linux-muslfdpic-native",
        .zig_arch = null,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "sh2-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "sh4eb-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "sh4-linux-musl-native",
        .zig_arch = null,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "x86_64-linux-musl-native",
        .zig_arch = Arch.x86_64,
        .zig_abi = Abi.musl,
    },
    LibCTarget{
        .name = "x86_64-linux-muslx32-native",
        .zig_arch = Arch.x86_64,
        .zig_abi = null,
    },
    LibCTarget{
        .name = "x86_64-w64-mingw32-native",
        .zig_arch = null,
        .zig_abi = null,
    },
};

const DestTarget = struct {
    arch: @TagType(Arch),
    os: Os,
    abi: Abi,

    fn hash(a: DestTarget) u32 {
        return @enumToInt(a.arch) +%
            (@enumToInt(a.os) *% u32(4202347608)) +%
            (@enumToInt(a.abi) *% u32(4082223418));
    }

    fn eql(a: DestTarget, b: DestTarget) bool {
        return a.arch == b.arch and
            a.os == b.os and
            a.abi == b.abi;
    }
};

const Contents = struct {
    bytes: []const u8,
    hit_count: usize,
    hash: []const u8,
    is_generic: bool,

    fn hitCountLessThan(lhs: *const Contents, rhs: *const Contents) bool {
        return lhs.hit_count < rhs.hit_count;
    }
};

const HashToContents = std.AutoHashMap([]const u8, Contents);
const TargetToHash = std.HashMap(DestTarget, []const u8, DestTarget.hash, DestTarget.eql);
const PathTable = std.AutoHashMap([]const u8, *TargetToHash);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    const allocator = &arena.allocator;
    const args = try std.os.argsAlloc(allocator);
    var search_paths = std.ArrayList([]const u8).init(allocator);
    var opt_out_dir: ?[]const u8 = null;
    var opt_abi: ?[]const u8 = null;

    var arg_i: usize = 1;
    while (arg_i < args.len) : (arg_i += 1) {
        if (std.mem.eql(u8, args[arg_i], "--help"))
            usageAndExit(args[0]);
        if (arg_i + 1 >= args.len) {
            std.debug.warn("expected argument after '{}'\n", args[arg_i]);
            usageAndExit(args[0]);
        }

        if (std.mem.eql(u8, args[arg_i], "--search-path")) {
            try search_paths.append(args[arg_i + 1]);
        } else if (std.mem.eql(u8, args[arg_i], "--out")) {
            assert(opt_out_dir == null);
            opt_out_dir = args[arg_i + 1];
        } else if (std.mem.eql(u8, args[arg_i], "--abi")) {
            assert(opt_abi == null);
            opt_abi = args[arg_i + 1];
        } else {
            std.debug.warn("unrecognized argument: {}\n", args[arg_i]);
            usageAndExit(args[0]);
        }

        arg_i += 1;
    }

    const out_dir = opt_out_dir orelse usageAndExit(args[0]);
    const abi_name = opt_abi orelse usageAndExit(args[0]);
    const libc_targets = if (std.mem.eql(u8, abi_name, "musl"))
        musl_targets
    else if (std.mem.eql(u8, abi_name, "glibc"))
        glibc_targets
    else {
        std.debug.warn("unrecognized C ABI: {}\n", abi_name);
        usageAndExit(args[0]);
    };

    var path_table = PathTable.init(allocator);
    var hash_to_contents = HashToContents.init(allocator);
    var max_bytes_saved: usize = 0;
    var total_bytes: usize = 0;

    var hasher = std.crypto.Sha256.init();

    for (libc_targets) |libc_target| {
        const dest_target = DestTarget{
            .arch = libc_target.zig_arch orelse continue,
            .abi = libc_target.zig_abi orelse continue,
            .os = builtin.Os.linux,
        };
        search: for (search_paths.toSliceConst()) |search_path| {
            const target_include_dir = try std.os.path.join(
                allocator,
                [][]const u8{ search_path, libc_target.name, "usr", "include" },
            );
            var dir_stack = std.ArrayList([]const u8).init(allocator);
            try dir_stack.append(target_include_dir);

            while (dir_stack.popOrNull()) |full_dir_name| {
                var dir = std.os.Dir.open(allocator, full_dir_name) catch |err| switch (err) {
                    error.FileNotFound => continue :search,
                    error.AccessDenied => continue :search,
                    else => return err,
                };
                defer dir.close();

                while (try dir.next()) |entry| {
                    const full_path = try std.os.path.join(allocator, [][]const u8{ full_dir_name, entry.name });
                    switch (entry.kind) {
                        std.os.Dir.Entry.Kind.Directory => try dir_stack.append(full_path),
                        std.os.Dir.Entry.Kind.File => {
                            const rel_path = try std.os.path.relative(allocator, target_include_dir, full_path);
                            const raw_bytes = try std.io.readFileAlloc(allocator, full_path);
                            const trimmed = std.mem.trim(u8, raw_bytes, " \r\n\t");
                            total_bytes += raw_bytes.len;
                            const hash = try allocator.alloc(u8, 32);
                            hasher.reset();
                            hasher.update(rel_path);
                            hasher.update(trimmed);
                            hasher.final(hash);
                            const gop = try hash_to_contents.getOrPut(hash);
                            if (gop.found_existing) {
                                max_bytes_saved += raw_bytes.len;
                                gop.kv.value.hit_count += 1;
                                std.debug.warn(
                                    "duplicate: {} {} ({Bi2})\n",
                                    libc_target.name,
                                    rel_path,
                                    raw_bytes.len,
                                );
                            } else {
                                gop.kv.value = Contents{
                                    .bytes = trimmed,
                                    .hit_count = 1,
                                    .hash = hash,
                                    .is_generic = false,
                                };
                            }
                            const path_gop = try path_table.getOrPut(rel_path);
                            const target_to_hash = if (path_gop.found_existing) path_gop.kv.value else blk: {
                                const ptr = try allocator.create(TargetToHash);
                                ptr.* = TargetToHash.init(allocator);
                                path_gop.kv.value = ptr;
                                break :blk ptr;
                            };
                            assert((try target_to_hash.put(dest_target, hash)) == null);
                        },
                        else => std.debug.warn("warning: weird file: {}\n", full_path),
                    }
                }
            }
            break;
        } else {
            std.debug.warn("warning: libc target not found: {}\n", libc_target.name);
        }
    }
    std.debug.warn("summary: {Bi2} could be reduced to {Bi2}\n", total_bytes, total_bytes - max_bytes_saved);
    try std.os.makePath(allocator, out_dir);

    var missed_opportunity_bytes: usize = 0;
    // iterate path_table. for each path, put all the hashes into a list. sort by hit_count.
    // the hash with the highest hit_count gets to be the "generic" one. everybody else
    // gets their header in a separate arch directory.
    var path_it = path_table.iterator();
    while (path_it.next()) |path_kv| {
        var contents_list = std.ArrayList(*Contents).init(allocator);
        {
            var hash_it = path_kv.value.iterator();
            while (hash_it.next()) |hash_kv| {
                const contents = &hash_to_contents.get(hash_kv.value).?.value;
                try contents_list.append(contents);
            }
        }
        std.sort.sort(*Contents, contents_list.toSlice(), Contents.hitCountLessThan);
        var best_contents = contents_list.popOrNull().?;
        if (best_contents.hit_count > 1) {
            // worth it to make it generic
            const full_path = try std.os.path.join(allocator, [][]const u8{ out_dir, "generic", path_kv.key });
            try std.os.makePath(allocator, std.os.path.dirname(full_path).?);
            try std.io.writeFile(full_path, best_contents.bytes);
            best_contents.is_generic = true;
            while (contents_list.popOrNull()) |contender| {
                if (contender.hit_count > 1) {
                    const this_missed_bytes = contender.hit_count * contender.bytes.len;
                    missed_opportunity_bytes += this_missed_bytes;
                    std.debug.warn("Missed opportunity ({Bi2}): {}\n", this_missed_bytes, path_kv.key);
                } else break;
            }
        }
        var hash_it = path_kv.value.iterator();
        while (hash_it.next()) |hash_kv| {
            const contents = &hash_to_contents.get(hash_kv.value).?.value;
            if (contents.is_generic) continue;

            const dest_target = hash_kv.key;
            const out_subpath = try std.fmt.allocPrint(
                allocator,
                "{}-{}-{}",
                @tagName(dest_target.arch),
                @tagName(dest_target.os),
                @tagName(dest_target.abi),
            );
            const full_path = try std.os.path.join(allocator, [][]const u8{ out_dir, out_subpath, path_kv.key });
            try std.os.makePath(allocator, std.os.path.dirname(full_path).?);
            try std.io.writeFile(full_path, contents.bytes);
        }
    }
}

fn usageAndExit(arg0: []const u8) noreturn {
    std.debug.warn("Usage: {} [--search-path <dir>] --out <dir> --abi <name>\n", arg0);
    std.debug.warn("--search-path can be used any number of times.\n");
    std.debug.warn("    subdirectories of search paths look like, e.g. x86_64-linux-gnu\n");
    std.debug.warn("--out is a dir that will be created, and populated with the results\n");
    std.debug.warn("--abi is either musl or glibc\n");
    std.os.exit(1);
}
