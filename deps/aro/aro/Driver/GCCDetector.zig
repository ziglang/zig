const std = @import("std");
const Toolchain = @import("../Toolchain.zig");
const target_util = @import("../target.zig");
const system_defaults = @import("system_defaults");
const GCCVersion = @import("GCCVersion.zig");
const Multilib = @import("Multilib.zig");

const GCCDetector = @This();

is_valid: bool = false,
install_path: []const u8 = "",
parent_lib_path: []const u8 = "",
version: GCCVersion = .{},
gcc_triple: []const u8 = "",
selected: Multilib = .{},
biarch_sibling: ?Multilib = null,

pub fn deinit(self: *GCCDetector) void {
    if (!self.is_valid) return;
}

pub fn appendToolPath(self: *const GCCDetector, tc: *Toolchain) !void {
    if (!self.is_valid) return;
    return tc.addPathFromComponents(&.{
        self.parent_lib_path,
        "..",
        self.gcc_triple,
        "bin",
    }, .program);
}

fn addDefaultGCCPrefixes(prefixes: *std.ArrayListUnmanaged([]const u8), tc: *const Toolchain) !void {
    const sysroot = tc.getSysroot();
    const target = tc.getTarget();
    if (sysroot.len == 0 and target.os.tag == .linux and tc.filesystem.exists("/opt/rh")) {
        prefixes.appendAssumeCapacity("/opt/rh/gcc-toolset-12/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/gcc-toolset-11/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/gcc-toolset-10/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-12/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-11/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-10/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-9/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-8/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-7/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-6/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-4/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-3/root/usr");
        prefixes.appendAssumeCapacity("/opt/rh/devtoolset-2/root/usr");
    }
    if (sysroot.len == 0) {
        prefixes.appendAssumeCapacity("/usr");
    } else {
        var usr_path = try tc.arena.alloc(u8, 4 + sysroot.len);
        @memcpy(usr_path[0..4], "/usr");
        @memcpy(usr_path[4..], sysroot);
        prefixes.appendAssumeCapacity(usr_path);
    }
}

fn collectLibDirsAndTriples(
    tc: *Toolchain,
    lib_dirs: *std.ArrayListUnmanaged([]const u8),
    triple_aliases: *std.ArrayListUnmanaged([]const u8),
    biarch_libdirs: *std.ArrayListUnmanaged([]const u8),
    biarch_triple_aliases: *std.ArrayListUnmanaged([]const u8),
) !void {
    const AArch64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const AArch64Triples: [4][]const u8 = .{ "aarch64-none-linux-gnu", "aarch64-linux-gnu", "aarch64-redhat-linux", "aarch64-suse-linux" };
    const AArch64beLibDirs: [1][]const u8 = .{"/lib"};
    const AArch64beTriples: [2][]const u8 = .{ "aarch64_be-none-linux-gnu", "aarch64_be-linux-gnu" };

    const ARMLibDirs: [1][]const u8 = .{"/lib"};
    const ARMTriples: [1][]const u8 = .{"arm-linux-gnueabi"};
    const ARMHFTriples: [4][]const u8 = .{ "arm-linux-gnueabihf", "armv7hl-redhat-linux-gnueabi", "armv6hl-suse-linux-gnueabi", "armv7hl-suse-linux-gnueabi" };

    const ARMebLibDirs: [1][]const u8 = .{"/lib"};
    const ARMebTriples: [1][]const u8 = .{"armeb-linux-gnueabi"};
    const ARMebHFTriples: [2][]const u8 = .{ "armeb-linux-gnueabihf", "armebv7hl-redhat-linux-gnueabi" };

    const AVRLibDirs: [1][]const u8 = .{"/lib"};
    const AVRTriples: [1][]const u8 = .{"avr"};

    const CSKYLibDirs: [1][]const u8 = .{"/lib"};
    const CSKYTriples: [3][]const u8 = .{ "csky-linux-gnuabiv2", "csky-linux-uclibcabiv2", "csky-elf-noneabiv2" };

    const X86_64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const X86_64Triples: [11][]const u8 = .{
        "x86_64-linux-gnu",       "x86_64-unknown-linux-gnu",
        "x86_64-pc-linux-gnu",    "x86_64-redhat-linux6E",
        "x86_64-redhat-linux",    "x86_64-suse-linux",
        "x86_64-manbo-linux-gnu", "x86_64-linux-gnu",
        "x86_64-slackware-linux", "x86_64-unknown-linux",
        "x86_64-amazon-linux",
    };
    const X32Triples: [2][]const u8 = .{ "x86_64-linux-gnux32", "x86_64-pc-linux-gnux32" };
    const X32LibDirs: [2][]const u8 = .{ "/libx32", "/lib" };
    const X86LibDirs: [2][]const u8 = .{ "/lib32", "/lib" };
    const X86Triples: [9][]const u8 = .{
        "i586-linux-gnu",      "i686-linux-gnu",        "i686-pc-linux-gnu",
        "i386-redhat-linux6E", "i686-redhat-linux",     "i386-redhat-linux",
        "i586-suse-linux",     "i686-montavista-linux", "i686-gnu",
    };

    const LoongArch64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const LoongArch64Triples: [2][]const u8 = .{ "loongarch64-linux-gnu", "loongarch64-unknown-linux-gnu" };

    const M68kLibDirs: [1][]const u8 = .{"/lib"};
    const M68kTriples: [3][]const u8 = .{ "m68k-linux-gnu", "m68k-unknown-linux-gnu", "m68k-suse-linux" };

    const MIPSLibDirs: [2][]const u8 = .{ "/libo32", "/lib" };
    const MIPSTriples: [5][]const u8 = .{
        "mips-linux-gnu",        "mips-mti-linux",
        "mips-mti-linux-gnu",    "mips-img-linux-gnu",
        "mipsisa32r6-linux-gnu",
    };
    const MIPSELLibDirs: [2][]const u8 = .{ "/libo32", "/lib" };
    const MIPSELTriples: [3][]const u8 = .{ "mipsel-linux-gnu", "mips-img-linux-gnu", "mipsisa32r6el-linux-gnu" };

    const MIPS64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const MIPS64Triples: [6][]const u8 = .{
        "mips64-linux-gnu",      "mips-mti-linux-gnu",
        "mips-img-linux-gnu",    "mips64-linux-gnuabi64",
        "mipsisa64r6-linux-gnu", "mipsisa64r6-linux-gnuabi64",
    };
    const MIPS64ELLibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const MIPS64ELTriples: [6][]const u8 = .{
        "mips64el-linux-gnu",      "mips-mti-linux-gnu",
        "mips-img-linux-gnu",      "mips64el-linux-gnuabi64",
        "mipsisa64r6el-linux-gnu", "mipsisa64r6el-linux-gnuabi64",
    };

    const MIPSN32LibDirs: [1][]const u8 = .{"/lib32"};
    const MIPSN32Triples: [2][]const u8 = .{ "mips64-linux-gnuabin32", "mipsisa64r6-linux-gnuabin32" };
    const MIPSN32ELLibDirs: [1][]const u8 = .{"/lib32"};
    const MIPSN32ELTriples: [2][]const u8 = .{ "mips64el-linux-gnuabin32", "mipsisa64r6el-linux-gnuabin32" };

    const MSP430LibDirs: [1][]const u8 = .{"/lib"};
    const MSP430Triples: [1][]const u8 = .{"msp430-elf"};

    const PPCLibDirs: [2][]const u8 = .{ "/lib32", "/lib" };
    const PPCTriples: [5][]const u8 = .{
        "powerpc-linux-gnu",    "powerpc-unknown-linux-gnu",   "powerpc-linux-gnuspe",
        // On 32-bit PowerPC systems running SUSE Linux, gcc is configured as a
        // 64-bit compiler which defaults to "-m32", hence "powerpc64-suse-linux".
        "powerpc64-suse-linux", "powerpc-montavista-linuxspe",
    };
    const PPCLELibDirs: [2][]const u8 = .{ "/lib32", "/lib" };
    const PPCLETriples: [3][]const u8 = .{ "powerpcle-linux-gnu", "powerpcle-unknown-linux-gnu", "powerpcle-linux-musl" };

    const PPC64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const PPC64Triples: [4][]const u8 = .{
        "powerpc64-linux-gnu",  "powerpc64-unknown-linux-gnu",
        "powerpc64-suse-linux", "ppc64-redhat-linux",
    };
    const PPC64LELibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const PPC64LETriples: [5][]const u8 = .{
        "powerpc64le-linux-gnu",      "powerpc64le-unknown-linux-gnu",
        "powerpc64le-none-linux-gnu", "powerpc64le-suse-linux",
        "ppc64le-redhat-linux",
    };

    const RISCV32LibDirs: [2][]const u8 = .{ "/lib32", "/lib" };
    const RISCV32Triples: [3][]const u8 = .{ "riscv32-unknown-linux-gnu", "riscv32-linux-gnu", "riscv32-unknown-elf" };
    const RISCV64LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const RISCV64Triples: [3][]const u8 = .{
        "riscv64-unknown-linux-gnu",
        "riscv64-linux-gnu",
        "riscv64-unknown-elf",
    };

    const SPARCv8LibDirs: [2][]const u8 = .{ "/lib32", "/lib" };
    const SPARCv8Triples: [2][]const u8 = .{ "sparc-linux-gnu", "sparcv8-linux-gnu" };
    const SPARCv9LibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const SPARCv9Triples: [2][]const u8 = .{ "sparc64-linux-gnu", "sparcv9-linux-gnu" };

    const SystemZLibDirs: [2][]const u8 = .{ "/lib64", "/lib" };
    const SystemZTriples: [5][]const u8 = .{
        "s390x-linux-gnu",  "s390x-unknown-linux-gnu", "s390x-ibm-linux-gnu",
        "s390x-suse-linux", "s390x-redhat-linux",
    };
    const target = tc.getTarget();
    if (target.os.tag == .solaris) {
        // TODO
        return;
    }
    if (target.isAndroid()) {
        const AArch64AndroidTriples: [1][]const u8 = .{"aarch64-linux-android"};
        const ARMAndroidTriples: [1][]const u8 = .{"arm-linux-androideabi"};
        const MIPSELAndroidTriples: [1][]const u8 = .{"mipsel-linux-android"};
        const MIPS64ELAndroidTriples: [1][]const u8 = .{"mips64el-linux-android"};
        const X86AndroidTriples: [1][]const u8 = .{"i686-linux-android"};
        const X86_64AndroidTriples: [1][]const u8 = .{"x86_64-linux-android"};

        switch (target.cpu.arch) {
            .aarch64 => {
                lib_dirs.appendSliceAssumeCapacity(&AArch64LibDirs);
                triple_aliases.appendSliceAssumeCapacity(&AArch64AndroidTriples);
            },
            .arm,
            .thumb,
            => {
                lib_dirs.appendSliceAssumeCapacity(&ARMLibDirs);
                triple_aliases.appendSliceAssumeCapacity(&ARMAndroidTriples);
            },
            .mipsel => {
                lib_dirs.appendSliceAssumeCapacity(&MIPSELLibDirs);
                triple_aliases.appendSliceAssumeCapacity(&MIPSELAndroidTriples);
                biarch_libdirs.appendSliceAssumeCapacity(&MIPS64ELLibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&MIPS64ELAndroidTriples);
            },
            .mips64el => {
                lib_dirs.appendSliceAssumeCapacity(&MIPS64ELLibDirs);
                triple_aliases.appendSliceAssumeCapacity(&MIPS64ELAndroidTriples);
                biarch_libdirs.appendSliceAssumeCapacity(&MIPSELLibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSELAndroidTriples);
            },
            .x86_64 => {
                lib_dirs.appendSliceAssumeCapacity(&X86_64LibDirs);
                triple_aliases.appendSliceAssumeCapacity(&X86_64AndroidTriples);
                biarch_libdirs.appendSliceAssumeCapacity(&X86LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X86AndroidTriples);
            },
            .x86 => {
                lib_dirs.appendSliceAssumeCapacity(&X86LibDirs);
                triple_aliases.appendSliceAssumeCapacity(&X86AndroidTriples);
                biarch_libdirs.appendSliceAssumeCapacity(&X86_64LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X86_64AndroidTriples);
            },
            else => {},
        }
        return;
    }
    switch (target.cpu.arch) {
        .aarch64 => {
            lib_dirs.appendSliceAssumeCapacity(&AArch64LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&AArch64Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&AArch64LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&AArch64Triples);
        },
        .aarch64_be => {
            lib_dirs.appendSliceAssumeCapacity(&AArch64beLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&AArch64beTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&AArch64beLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&AArch64beTriples);
        },
        .arm, .thumb => {
            lib_dirs.appendSliceAssumeCapacity(&ARMLibDirs);
            if (target.abi == .gnueabihf) {
                triple_aliases.appendSliceAssumeCapacity(&ARMHFTriples);
            } else {
                triple_aliases.appendSliceAssumeCapacity(&ARMTriples);
            }
        },
        .armeb, .thumbeb => {
            lib_dirs.appendSliceAssumeCapacity(&ARMebLibDirs);
            if (target.abi == .gnueabihf) {
                triple_aliases.appendSliceAssumeCapacity(&ARMebHFTriples);
            } else {
                triple_aliases.appendSliceAssumeCapacity(&ARMebTriples);
            }
        },
        .avr => {
            lib_dirs.appendSliceAssumeCapacity(&AVRLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&AVRTriples);
        },
        .csky => {
            lib_dirs.appendSliceAssumeCapacity(&CSKYLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&CSKYTriples);
        },
        .x86_64 => {
            if (target.abi == .gnux32 or target.abi == .muslx32) {
                lib_dirs.appendSliceAssumeCapacity(&X32LibDirs);
                triple_aliases.appendSliceAssumeCapacity(&X32Triples);
                biarch_libdirs.appendSliceAssumeCapacity(&X86_64LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X86_64Triples);
            } else {
                lib_dirs.appendSliceAssumeCapacity(&X86_64LibDirs);
                triple_aliases.appendSliceAssumeCapacity(&X86_64Triples);
                biarch_libdirs.appendSliceAssumeCapacity(&X32LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X32Triples);
            }
            biarch_libdirs.appendSliceAssumeCapacity(&X86LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&X86Triples);
        },
        .x86 => {
            lib_dirs.appendSliceAssumeCapacity(&X86LibDirs);
            // MCU toolchain is 32 bit only and its triple alias is TargetTriple
            // itself, which will be appended below.
            if (target.os.tag != .elfiamcu) {
                triple_aliases.appendSliceAssumeCapacity(&X86Triples);
                biarch_libdirs.appendSliceAssumeCapacity(&X86_64LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X86_64Triples);
                biarch_libdirs.appendSliceAssumeCapacity(&X32LibDirs);
                biarch_triple_aliases.appendSliceAssumeCapacity(&X32Triples);
            }
        },
        .loongarch64 => {
            lib_dirs.appendSliceAssumeCapacity(&LoongArch64LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&LoongArch64Triples);
        },
        .m68k => {
            lib_dirs.appendSliceAssumeCapacity(&M68kLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&M68kTriples);
        },
        .mips => {
            lib_dirs.appendSliceAssumeCapacity(&MIPSLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&MIPSTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPS64LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPS64Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSN32LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSN32Triples);
        },
        .mipsel => {
            lib_dirs.appendSliceAssumeCapacity(&MIPSELLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&MIPSELTriples);
            triple_aliases.appendSliceAssumeCapacity(&MIPSTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPS64ELLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPS64ELTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSN32ELLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSN32ELTriples);
        },
        .mips64 => {
            lib_dirs.appendSliceAssumeCapacity(&MIPS64LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&MIPS64Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSN32LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSN32Triples);
        },
        .mips64el => {
            lib_dirs.appendSliceAssumeCapacity(&MIPS64ELLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&MIPS64ELTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSELLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSELTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&MIPSN32ELLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSN32ELTriples);
            biarch_triple_aliases.appendSliceAssumeCapacity(&MIPSTriples);
        },
        .msp430 => {
            lib_dirs.appendSliceAssumeCapacity(&MSP430LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&MSP430Triples);
        },
        .powerpc => {
            lib_dirs.appendSliceAssumeCapacity(&PPCLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&PPCTriples);
            biarch_libdirs.appendSliceAssumeCapacity(&PPC64LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&PPC64Triples);
        },
        .powerpcle => {
            lib_dirs.appendSliceAssumeCapacity(&PPCLELibDirs);
            triple_aliases.appendSliceAssumeCapacity(&PPCLETriples);
            biarch_libdirs.appendSliceAssumeCapacity(&PPC64LELibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&PPC64LETriples);
        },
        .powerpc64 => {
            lib_dirs.appendSliceAssumeCapacity(&PPC64LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&PPC64Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&PPCLibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&PPCTriples);
        },
        .powerpc64le => {
            lib_dirs.appendSliceAssumeCapacity(&PPC64LELibDirs);
            triple_aliases.appendSliceAssumeCapacity(&PPC64LETriples);
            biarch_libdirs.appendSliceAssumeCapacity(&PPCLELibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&PPCLETriples);
        },
        .riscv32 => {
            lib_dirs.appendSliceAssumeCapacity(&RISCV32LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&RISCV32Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&RISCV64LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&RISCV64Triples);
        },
        .riscv64 => {
            lib_dirs.appendSliceAssumeCapacity(&RISCV64LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&RISCV64Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&RISCV32LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&RISCV32Triples);
        },
        .sparc, .sparcel => {
            lib_dirs.appendSliceAssumeCapacity(&SPARCv8LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&SPARCv8Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&SPARCv9LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&SPARCv9Triples);
        },
        .sparc64 => {
            lib_dirs.appendSliceAssumeCapacity(&SPARCv9LibDirs);
            triple_aliases.appendSliceAssumeCapacity(&SPARCv9Triples);
            biarch_libdirs.appendSliceAssumeCapacity(&SPARCv8LibDirs);
            biarch_triple_aliases.appendSliceAssumeCapacity(&SPARCv8Triples);
        },
        .s390x => {
            lib_dirs.appendSliceAssumeCapacity(&SystemZLibDirs);
            triple_aliases.appendSliceAssumeCapacity(&SystemZTriples);
        },
        else => {},
    }
}

pub fn discover(self: *GCCDetector, tc: *Toolchain) !void {
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&path_buf);

    const target = tc.getTarget();
    const biarch_variant_target = if (target.ptrBitWidth() == 32)
        target_util.get64BitArchVariant(target)
    else
        target_util.get32BitArchVariant(target);

    var candidate_lib_dirs_buffer: [16][]const u8 = undefined;
    var candidate_lib_dirs = std.ArrayListUnmanaged([]const u8).initBuffer(&candidate_lib_dirs_buffer);

    var candidate_triple_aliases_buffer: [16][]const u8 = undefined;
    var candidate_triple_aliases = std.ArrayListUnmanaged([]const u8).initBuffer(&candidate_triple_aliases_buffer);

    var candidate_biarch_lib_dirs_buffer: [16][]const u8 = undefined;
    var candidate_biarch_lib_dirs = std.ArrayListUnmanaged([]const u8).initBuffer(&candidate_biarch_lib_dirs_buffer);

    var candidate_biarch_triple_aliases_buffer: [16][]const u8 = undefined;
    var candidate_biarch_triple_aliases = std.ArrayListUnmanaged([]const u8).initBuffer(&candidate_biarch_triple_aliases_buffer);

    try collectLibDirsAndTriples(
        tc,
        &candidate_lib_dirs,
        &candidate_triple_aliases,
        &candidate_biarch_lib_dirs,
        &candidate_biarch_triple_aliases,
    );

    var target_buf: [64]u8 = undefined;
    const triple_str = target_util.toLLVMTriple(target, &target_buf);
    candidate_triple_aliases.appendAssumeCapacity(triple_str);

    // Also include the multiarch variant if it's different.
    var biarch_buf: [64]u8 = undefined;
    if (biarch_variant_target) |biarch_target| {
        const biarch_triple_str = target_util.toLLVMTriple(biarch_target, &biarch_buf);
        if (!std.mem.eql(u8, biarch_triple_str, triple_str)) {
            candidate_triple_aliases.appendAssumeCapacity(biarch_triple_str);
        }
    }

    var prefixes_buf: [16][]const u8 = undefined;
    var prefixes = std.ArrayListUnmanaged([]const u8).initBuffer(&prefixes_buf);
    const gcc_toolchain_dir = gccToolchainDir(tc);
    if (gcc_toolchain_dir.len != 0) {
        const adjusted = if (gcc_toolchain_dir[gcc_toolchain_dir.len - 1] == '/')
            gcc_toolchain_dir[0 .. gcc_toolchain_dir.len - 1]
        else
            gcc_toolchain_dir;
        prefixes.appendAssumeCapacity(adjusted);
    } else {
        const sysroot = tc.getSysroot();
        if (sysroot.len > 0) {
            prefixes.appendAssumeCapacity(sysroot);
            try addDefaultGCCPrefixes(&prefixes, tc);
        }

        if (sysroot.len == 0) {
            try addDefaultGCCPrefixes(&prefixes, tc);
        }
        // TODO: Special-case handling for Gentoo
    }

    const v0 = GCCVersion.parse("0.0.0");
    for (prefixes.items) |prefix| {
        if (!tc.filesystem.exists(prefix)) continue;

        for (candidate_lib_dirs.items) |suffix| {
            defer fib.reset();
            const lib_dir = std.fs.path.join(fib.allocator(), &.{ prefix, suffix }) catch continue;
            if (!tc.filesystem.exists(lib_dir)) continue;

            const gcc_dir_exists = tc.filesystem.joinedExists(&.{ lib_dir, "/gcc" });
            const gcc_cross_dir_exists = tc.filesystem.joinedExists(&.{ lib_dir, "/gcc-cross" });

            try self.scanLibDirForGCCTriple(tc, target, lib_dir, triple_str, false, gcc_dir_exists, gcc_cross_dir_exists);
            for (candidate_triple_aliases.items) |candidate| {
                try self.scanLibDirForGCCTriple(tc, target, lib_dir, candidate, false, gcc_dir_exists, gcc_cross_dir_exists);
            }
        }
        for (candidate_biarch_lib_dirs.items) |suffix| {
            const lib_dir = std.fs.path.join(fib.allocator(), &.{ prefix, suffix }) catch continue;
            if (!tc.filesystem.exists(lib_dir)) continue;

            const gcc_dir_exists = tc.filesystem.joinedExists(&.{ lib_dir, "/gcc" });
            const gcc_cross_dir_exists = tc.filesystem.joinedExists(&.{ lib_dir, "/gcc-cross" });
            for (candidate_biarch_triple_aliases.items) |candidate| {
                try self.scanLibDirForGCCTriple(tc, target, lib_dir, candidate, true, gcc_dir_exists, gcc_cross_dir_exists);
            }
        }
        if (self.version.order(v0) == .gt) break;
    }
}

fn findBiarchMultilibs(
    tc: *const Toolchain,
    result: *Multilib.Detected,
    target: std.Target,
    path: [2][]const u8,
    needs_biarch_suffix: bool,
) !bool {
    const suff64 = if (target.os.tag == .solaris) switch (target.cpu.arch) {
        .x86, .x86_64 => "/amd64",
        .sparc => "/sparcv9",
        else => "/64",
    } else "/64";

    const alt_64 = Multilib.init(suff64, suff64, &.{ "-m32", "+m64", "-mx32" });
    const alt_32 = Multilib.init("/32", "/32", &.{ "+m32", "-m64", "-mx32" });
    const alt_x32 = Multilib.init("/x32", "/x32", &.{ "-m32", "-m64", "+mx32" });

    const multilib_filter = Multilib.Filter{
        .base = path,
        .file = if (target.os.tag == .elfiamcu) "libgcc.a" else "crtbegin.o",
    };

    const Want = enum {
        want32,
        want64,
        wantx32,
    };
    const is_x32 = target.abi == .gnux32 or target.abi == .muslx32;
    const target_ptr_width = target.ptrBitWidth();
    const want: Want = if (target_ptr_width == 32 and multilib_filter.exists(alt_32, tc.filesystem))
        .want64
    else if (target_ptr_width == 64 and is_x32 and multilib_filter.exists(alt_x32, tc.filesystem))
        .want64
    else if (target_ptr_width == 64 and !is_x32 and multilib_filter.exists(alt_64, tc.filesystem))
        .want32
    else if (target_ptr_width == 32)
        if (needs_biarch_suffix) .want64 else .want32
    else if (is_x32)
        if (needs_biarch_suffix) .want64 else .wantx32
    else if (needs_biarch_suffix) .want32 else .want64;

    const default = switch (want) {
        .want32 => Multilib.init("", "", &.{ "+m32", "-m64", "-mx32" }),
        .want64 => Multilib.init("", "", &.{ "-m32", "+m64", "-mx32" }),
        .wantx32 => Multilib.init("", "", &.{ "-m32", "-m64", "+mx32" }),
    };
    result.multilibs.appendSliceAssumeCapacity(&.{
        default,
        alt_64,
        alt_32,
        alt_x32,
    });
    result.filter(multilib_filter, tc.filesystem);
    var flags: Multilib.Flags = .{};
    flags.appendAssumeCapacity(if (target_ptr_width == 64 and !is_x32) "+m64" else "-m64");
    flags.appendAssumeCapacity(if (target_ptr_width == 32) "+m32" else "-m32");
    flags.appendAssumeCapacity(if (target_ptr_width == 64 and is_x32) "+mx32" else "-mx32");

    return result.select(flags);
}

fn scanGCCForMultilibs(
    self: *GCCDetector,
    tc: *const Toolchain,
    target: std.Target,
    path: [2][]const u8,
    needs_biarch_suffix: bool,
) !bool {
    var detected: Multilib.Detected = .{};
    if (target.cpu.arch == .csky) {
        // TODO
    } else if (target.cpu.arch.isMIPS()) {
        // TODO
    } else if (target.cpu.arch.isRISCV()) {
        // TODO
    } else if (target.cpu.arch == .msp430) {
        // TODO
    } else if (target.cpu.arch == .avr) {
        // No multilibs
    } else if (!try findBiarchMultilibs(tc, &detected, target, path, needs_biarch_suffix)) {
        return false;
    }
    self.selected = detected.selected;
    self.biarch_sibling = detected.biarch_sibling;
    return true;
}

fn scanLibDirForGCCTriple(
    self: *GCCDetector,
    tc: *const Toolchain,
    target: std.Target,
    lib_dir: []const u8,
    candidate_triple: []const u8,
    needs_biarch_suffix: bool,
    gcc_dir_exists: bool,
    gcc_cross_dir_exists: bool,
) !void {
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&path_buf);
    for (0..2) |i| {
        if (i == 0 and !gcc_dir_exists) continue;
        if (i == 1 and !gcc_cross_dir_exists) continue;
        defer fib.reset();

        const base: []const u8 = if (i == 0) "gcc" else "gcc-cross";
        var lib_suffix_buf: [64]u8 = undefined;
        var suffix_buf_fib = std.heap.FixedBufferAllocator.init(&lib_suffix_buf);
        const lib_suffix = std.fs.path.join(suffix_buf_fib.allocator(), &.{ base, candidate_triple }) catch continue;

        const dir_name = std.fs.path.join(fib.allocator(), &.{ lib_dir, lib_suffix }) catch continue;
        var parent_dir = tc.filesystem.openDir(dir_name) catch continue;
        defer parent_dir.close();

        var it = parent_dir.iterate();
        while (it.next() catch continue) |entry| {
            if (entry.kind != .directory) continue;

            const version_text = entry.name;
            const candidate_version = GCCVersion.parse(version_text);
            if (candidate_version.major != -1) {
                // TODO: cache path so we're not repeatedly scanning
            }
            if (candidate_version.isLessThan(4, 1, 1, "")) continue;
            switch (candidate_version.order(self.version)) {
                .lt, .eq => continue,
                .gt => {},
            }

            if (!try self.scanGCCForMultilibs(tc, target, .{ dir_name, version_text }, needs_biarch_suffix)) continue;

            self.version = candidate_version;
            self.gcc_triple = try tc.arena.dupe(u8, candidate_triple);
            self.install_path = try std.fs.path.join(tc.arena, &.{ lib_dir, lib_suffix, version_text });
            self.parent_lib_path = try std.fs.path.join(tc.arena, &.{ self.install_path, "..", "..", ".." });
            self.is_valid = true;
        }
    }
}

fn gccToolchainDir(tc: *const Toolchain) []const u8 {
    const sysroot = tc.getSysroot();
    if (sysroot.len != 0) return "";
    return system_defaults.gcc_install_prefix;
}
