const std = @import("std");
const Abi = std.Target.Abi;
const Cpu = std.Target.Cpu;
const mem = std.mem;
const Os = std.Target.Os;
const testing = std.testing;

const builtin = @import("builtin");

const LangOpts = @import("LangOpts.zig");
const QualType = @import("TypeStore.zig").QualType;

pub const Vendor = enum {
    apple,
    pc,
    scei,
    sie,
    freescale,
    ibm,
    imagination_technologies,
    mips,
    nvidia,
    csr,
    amd,
    mesa,
    suse,
    open_embedded,
    intel,
    unknown,

    const vendor_strings = std.StaticStringMap(Vendor).initComptime(.{
        .{ "apple", .apple },
        .{ "pc", .pc },
        .{ "scei", .scei },
        .{ "sie", .scei },
        .{ "fsl", .freescale },
        .{ "ibm", .ibm },
        .{ "img", .imagination_technologies },
        .{ "mti", .mips },
        .{ "nvidia", .nvidia },
        .{ "csr", .csr },
        .{ "amd", .amd },
        .{ "mesa", .mesa },
        .{ "suse", .suse },
        .{ "oe", .open_embedded },
        .{ "intel", .intel },
    });

    pub fn parse(candidate: []const u8) ?Vendor {
        return vendor_strings.get(candidate);
    }
};

pub const SubArch = enum {
    arm_v4t,
    arm_v5,
    arm_v5te,
    arm_v6,
    arm_v6k,
    arm_v6m,
    arm_v6t2,
    arm_v7,
    arm_v7em,
    arm_v7k,
    arm_v7m,
    arm_v7s,
    arm_v7ve,
    arm_v8,
    arm_v8_1a,
    arm_v8_1m_mainline,
    arm_v8_2a,
    arm_v8_3a,
    arm_v8_4a,
    arm_v8_5a,
    arm_v8_6a,
    arm_v8_7a,
    arm_v8_8a,
    arm_v8_9a,
    arm_v8m_baseline,
    arm_v8m_mainline,
    arm_v8r,
    arm_v9,
    arm_v9_1a,
    arm_v9_2a,
    arm_v9_3a,
    arm_v9_4a,
    arm_v9_5a,
    arm_v9_6a,

    aarch64_arm64e,
    aarch64_arm64ec,

    mips_r6,

    powerpc_spe,

    spirv_v10,
    spirv_v11,
    spirv_v12,
    spirv_v13,
    spirv_v14,
    spirv_v15,
    spirv_v16,

    pub fn toFeature(sub: SubArch, arch: Cpu.Arch) ?std.Target.Cpu.Feature.Set.Index {
        if (arch.isPowerPC()) {
            if (sub == .powerpc_spe) return @intFromEnum(std.Target.powerpc.Feature.spe);
        } else if (arch.isMIPS32()) {
            return @intFromEnum(std.Target.mips.Feature.mips32r6);
        } else if (arch.isMIPS64()) {
            return @intFromEnum(std.Target.mips.Feature.mips64r6);
        } else if (arch.isSpirV()) {
            const spirv = std.Target.spirv.Feature;
            return @intFromEnum(switch (sub) {
                .spirv_v10 => spirv.v1_0,
                .spirv_v11 => spirv.v1_1,
                .spirv_v12 => spirv.v1_2,
                .spirv_v13 => spirv.v1_3,
                .spirv_v14 => spirv.v1_4,
                .spirv_v15 => spirv.v1_5,
                .spirv_v16 => spirv.v1_6,
                else => return null,
            });
        } else if (arch.isAARCH64()) {
            const aarch64 = std.Target.aarch64.Feature;
            return @intFromEnum(switch (sub) {
                .arm_v8_1a => aarch64.v8_1a,
                .arm_v8_2a => aarch64.v8_2a,
                .arm_v8_3a => aarch64.v8_3a,
                .arm_v8_4a => aarch64.v8_4a,
                .arm_v8_5a => aarch64.v8_5a,
                .arm_v8_6a => aarch64.v8_6a,
                .arm_v8_7a => aarch64.v8_7a,
                .arm_v8_8a => aarch64.v8_8a,
                .arm_v8_9a => aarch64.v8_9a,
                .arm_v8m_baseline => return null,
                .arm_v8r => aarch64.v8r,
                .arm_v9_1a => aarch64.v9_1a,
                .arm_v9_2a => aarch64.v9_2a,
                .arm_v9_3a => aarch64.v9_3a,
                .arm_v9_4a => aarch64.v9_4a,
                .arm_v9_5a => aarch64.v9_5a,
                .arm_v9_6a => aarch64.v9_6a,

                .aarch64_arm64e => return null,
                .aarch64_arm64ec => return null,

                else => return null,
            });
        } else if (arch.isArm()) {
            const arm = std.Target.arm.Feature;
            return @intFromEnum(switch (sub) {
                .arm_v4t => arm.v4t,
                .arm_v5 => arm.v5t,
                .arm_v5te => arm.v5te,
                .arm_v6 => arm.v6,
                .arm_v6k => arm.v6k,
                .arm_v6m => arm.v6m,
                .arm_v6t2 => arm.v6t2,
                .arm_v7 => arm.has_v7,
                .arm_v7em => arm.v7em,
                .arm_v7k => return null,
                .arm_v7m => arm.v7m,
                .arm_v7s => return null,
                .arm_v7ve => arm.v7ve,
                .arm_v8 => arm.has_v8,
                .arm_v8r => arm.v8r,
                .arm_v9 => arm.v9a,
                else => return null,
            });
        }
        return null;
    }
};

const Target = @This();

cpu: Cpu,
vendor: Vendor,
os: Os,
abi: Abi,
ofmt: std.Target.ObjectFormat,
dynamic_linker: std.Target.DynamicLinker = .none,

pub const default: Target = .{
    .cpu = builtin.cpu,
    .vendor = .unknown,
    .os = builtin.os,
    .abi = builtin.abi,
    .ofmt = builtin.target.ofmt,
};

pub inline fn fromZigTarget(target: std.Target) Target {
    return .{
        .cpu = target.cpu,
        .vendor = .unknown,
        .os = target.os,
        .abi = target.abi,
        .ofmt = target.ofmt,
        .dynamic_linker = target.dynamic_linker,
    };
}

pub inline fn toZigTarget(target: *const Target) std.Target {
    return .{
        .cpu = target.cpu,
        .os = target.os,
        .abi = target.abi,
        .ofmt = target.ofmt,
        .dynamic_linker = target.dynamic_linker,
    };
}

/// intmax_t for this target
pub fn intMaxType(target: *const Target) QualType {
    switch (target.cpu.arch) {
        .aarch64,
        .aarch64_be,
        .sparc64,
        => if (target.os.tag != .openbsd) return .long,

        .bpfel,
        .bpfeb,
        .loongarch64,
        .riscv64,
        .powerpc64,
        .powerpc64le,
        .ve,
        => return .long,

        .x86_64 => switch (target.os.tag) {
            .windows, .openbsd => {},
            else => switch (target.abi) {
                .gnux32, .muslx32 => {},
                else => return .long,
            },
        },

        else => {},
    }
    return .long_long;
}

/// intptr_t for this target
pub fn intPtrType(target: *const Target) QualType {
    if (target.os.tag == .haiku) return .long;

    switch (target.cpu.arch) {
        .aarch64, .aarch64_be => switch (target.os.tag) {
            .windows => return .long_long,
            else => {},
        },

        .msp430,
        .csky,
        .loongarch32,
        .riscv32,
        .xcore,
        .hexagon,
        .m68k,
        .spirv32,
        .arc,
        .avr,
        => return .int,

        .sparc => switch (target.os.tag) {
            .netbsd, .openbsd => {},
            else => return .int,
        },

        .powerpc, .powerpcle => switch (target.os.tag) {
            .linux, .freebsd, .netbsd => return .int,
            else => {},
        },

        // 32-bit x86 Darwin, OpenBSD, and RTEMS use long (the default); others use int
        .x86 => switch (target.os.tag) {
            .openbsd, .rtems => {},
            else => if (!target.os.tag.isDarwin()) return .int,
        },

        .x86_64 => switch (target.os.tag) {
            .windows => return .long_long,
            else => switch (target.abi) {
                .gnux32, .muslx32 => return .int,
                else => {},
            },
        },

        else => {},
    }

    return .long;
}

/// int16_t for this target
pub fn int16Type(target: *const Target) QualType {
    return switch (target.cpu.arch) {
        .avr => .int,
        else => .short,
    };
}

/// sig_atomic_t for this target
pub fn sigAtomicType(target: *const Target) QualType {
    if (target.cpu.arch.isWasm()) return .long;
    return switch (target.cpu.arch) {
        .avr => .schar,
        .msp430 => .long,
        else => .int,
    };
}

/// int64_t for this target
pub fn int64Type(target: *const Target) QualType {
    switch (target.cpu.arch) {
        .loongarch64,
        .ve,
        .riscv64,
        .powerpc64,
        .powerpc64le,
        .bpfel,
        .bpfeb,
        => return .long,

        .sparc64 => return intMaxType(target),

        .x86, .x86_64 => if (!target.os.tag.isDarwin()) return intMaxType(target),
        .aarch64, .aarch64_be => if (!target.os.tag.isDarwin() and target.os.tag != .openbsd and target.os.tag != .windows) return .long,
        else => {},
    }
    return .long_long;
}

pub fn float80Type(target: *const Target) ?QualType {
    switch (target.cpu.arch) {
        .x86, .x86_64 => return .long_double,
        else => {},
    }
    return null;
}

/// This function returns 1 if function alignment is not observable or settable.
pub fn defaultFunctionAlignment(target: *const Target) u8 {
    // Overrides of the minimum for performance.
    return switch (target.cpu.arch) {
        .csky,
        .thumb,
        .thumbeb,
        .xcore,
        => 4,
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
        => 16,
        .loongarch32,
        .loongarch64,
        => 32,
        else => minFunctionAlignment(target),
    };
}

/// This function returns 1 if function alignment is not observable or settable.
pub fn minFunctionAlignment(target: *const Target) u8 {
    return switch (target.cpu.arch) {
        .riscv32,
        .riscv32be,
        .riscv64,
        .riscv64be,
        => if (target.cpu.hasAny(.riscv, &.{ .c, .zca })) 2 else 4,
        .thumb,
        .thumbeb,
        .csky,
        .m68k,
        .msp430,
        .sh,
        .sheb,
        .s390x,
        .xcore,
        => 2,
        .aarch64,
        .aarch64_be,
        .alpha,
        .arc,
        .arceb,
        .arm,
        .armeb,
        .hexagon,
        .hppa,
        .hppa64,
        .lanai,
        .loongarch32,
        .loongarch64,
        .microblaze,
        .microblazeel,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .sparc,
        .sparc64,
        .xtensa,
        .xtensaeb,
        => 4,
        .bpfeb,
        .bpfel,
        .mips64,
        .mips64el,
        => 8,
        .ve,
        => 16,
        else => 1,
    };
}

pub fn isTlsSupported(target: *const Target) bool {
    if (target.os.tag.isDarwin()) {
        var supported = false;
        switch (target.os.tag) {
            .macos => supported = !(target.os.isAtLeast(.macos, .{ .major = 10, .minor = 7, .patch = 0 }) orelse false),
            else => {},
        }
        return supported;
    }
    return switch (target.cpu.arch) {
        .bpfel, .bpfeb, .msp430, .nvptx, .nvptx64, .x86, .arm, .armeb, .thumb, .thumbeb => false,
        else => true,
    };
}

pub fn ignoreNonZeroSizedBitfieldTypeAlignment(target: *const Target) bool {
    switch (target.cpu.arch) {
        .avr => return true,
        .arm => {
            if (std.Target.arm.featureSetHas(target.cpu.features, .has_v7)) {
                switch (target.os.tag) {
                    .ios => return true,
                    else => return false,
                }
            }
        },
        else => return false,
    }
    return false;
}

pub fn ignoreZeroSizedBitfieldTypeAlignment(target: *const Target) bool {
    switch (target.cpu.arch) {
        .avr => return true,
        else => return false,
    }
}

pub fn minZeroWidthBitfieldAlignment(target: *const Target) ?u29 {
    switch (target.cpu.arch) {
        .avr => return 8,
        .arm => {
            if (std.Target.arm.featureSetHas(target.cpu.features, .has_v7)) {
                switch (target.os.tag) {
                    .ios => return 32,
                    else => return null,
                }
            } else return null;
        },
        else => return null,
    }
}

pub fn unnamedFieldAffectsAlignment(target: *const Target) bool {
    switch (target.cpu.arch) {
        .aarch64 => {
            if (target.os.tag.isDarwin() or target.os.tag == .windows) return false;
            return true;
        },
        .armeb => {
            if (std.Target.arm.featureSetHas(target.cpu.features, .has_v7)) {
                if (Abi.default(target.cpu.arch, target.os.tag) == .eabi) return true;
            }
        },
        .arm => return true,
        .avr => return true,
        .thumb => {
            if (target.os.tag == .windows) return false;
            return true;
        },
        else => return false,
    }
    return false;
}

pub fn packAllEnums(target: *const Target) bool {
    return switch (target.cpu.arch) {
        .hexagon => true,
        else => false,
    };
}

/// Default alignment (in bytes) for __attribute__((aligned)) when no alignment is specified
pub fn defaultAlignment(target: *const Target) u29 {
    switch (target.cpu.arch) {
        .avr => return 1,
        .arm => if (target.abi.isAndroid() or target.os.tag == .ios) return 16 else return 8,
        .sparc => if (std.Target.sparc.featureSetHas(target.cpu.features, .v9)) return 16 else return 8,
        .mips, .mipsel => switch (target.abi) {
            .none, .gnuabi64 => return 16,
            else => return 8,
        },
        .s390x, .armeb, .thumbeb, .thumb => return 8,
        else => return 16,
    }
}
pub fn systemCompiler(target: *const Target) LangOpts.Compiler {
    // Android is linux but not gcc, so these checks go first
    // the rest for documentation as fn returns .clang
    if (target.os.tag.isDarwin() or
        target.abi.isAndroid() or
        target.os.tag.isBSD() or
        target.os.tag == .fuchsia or
        target.os.tag == .illumos or
        target.os.tag == .haiku or
        target.cpu.arch == .hexagon)
    {
        return .clang;
    }
    if (target.os.tag == .uefi) return .msvc;
    // this is before windows to grab WindowsGnu
    if (target.abi.isGnu() or
        target.os.tag == .linux)
    {
        return .gcc;
    }
    if (target.os.tag == .windows) {
        return .msvc;
    }
    if (target.cpu.arch == .avr) return .gcc;
    return .clang;
}

pub fn hasFloat128(target: *const Target) bool {
    if (target.cpu.arch.isWasm()) return true;
    if (target.os.tag.isDarwin()) return false;
    if (target.cpu.arch.isPowerPC()) return std.Target.powerpc.featureSetHas(target.cpu.features, .float128);
    return switch (target.os.tag) {
        .dragonfly,
        .haiku,
        .linux,
        .openbsd,
        .illumos,
        => target.cpu.arch.isX86(),
        else => false,
    };
}

pub fn hasInt128(target: *const Target) bool {
    if (target.cpu.arch == .wasm32) return true;
    if (target.cpu.arch == .x86_64) return true;
    return target.ptrBitWidth() >= 64;
}

pub fn hasHalfPrecisionFloatABI(target: *const Target) bool {
    return switch (target.cpu.arch) {
        .thumb, .thumbeb, .arm, .aarch64 => true,
        else => false,
    };
}

pub const FPSemantics = enum {
    None,
    IEEEHalf,
    BFloat,
    IEEESingle,
    IEEEDouble,
    IEEEQuad,
    /// Minifloat 5-bit exponent 2-bit mantissa
    E5M2,
    /// Minifloat 4-bit exponent 3-bit mantissa
    E4M3,
    x87ExtendedDouble,
    IBMExtendedDouble,

    /// Only intended for generating float.h macros for the preprocessor
    pub fn forType(ty: std.Target.CType, target: *const Target) FPSemantics {
        std.debug.assert(ty == .float or ty == .double or ty == .longdouble);
        return switch (target.cTypeBitSize(ty)) {
            32 => .IEEESingle,
            64 => .IEEEDouble,
            80 => .x87ExtendedDouble,
            128 => switch (target.cpu.arch) {
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => .IBMExtendedDouble,
                else => .IEEEQuad,
            },
            else => unreachable,
        };
    }

    pub fn halfPrecisionType(target: *const Target) ?FPSemantics {
        switch (target.cpu.arch) {
            .aarch64,
            .aarch64_be,
            .arm,
            .armeb,
            .hexagon,
            .riscv32,
            .riscv64,
            .spirv32,
            .spirv64,
            => return .IEEEHalf,
            .x86, .x86_64 => if (std.Target.x86.featureSetHas(target.cpu.features, .sse2)) return .IEEEHalf,
            else => {},
        }
        return null;
    }

    pub fn chooseValue(self: FPSemantics, comptime T: type, values: [6]T) T {
        return switch (self) {
            .IEEEHalf => values[0],
            .IEEESingle => values[1],
            .IEEEDouble => values[2],
            .x87ExtendedDouble => values[3],
            .IBMExtendedDouble => values[4],
            .IEEEQuad => values[5],
            else => unreachable,
        };
    }
};

pub fn isLP64(target: *const Target) bool {
    return target.cTypeBitSize(.int) == 32 and target.ptrBitWidth() == 64;
}

pub fn isKnownWindowsMSVCEnvironment(target: *const Target) bool {
    return target.os.tag == .windows and target.abi == .msvc;
}

pub fn isWindowsMSVCEnvironment(target: *const Target) bool {
    return target.os.tag == .windows and (target.abi == .msvc or target.abi == .none);
}

pub fn isMinGW(target: *const Target) bool {
    return target.os.tag == .windows and target.abi.isGnu();
}

pub fn isPS(target: *const Target) bool {
    return (target.os.tag == .ps4 or target.os.tag == .ps5) and target.cpu.arch == .x86_64;
}

fn toLower(src: []const u8, dest: []u8) ?[]const u8 {
    if (src.len > dest.len) return null;
    for (src, dest[0..src.len]) |a, *b| {
        b.* = std.ascii.toLower(a);
    }
    return dest[0..src.len];
}

pub const ArchSubArch = struct { std.Target.Cpu.Arch, ?SubArch };
pub fn parseArchName(query: []const u8) ?ArchSubArch {
    var buf: [64]u8 = undefined;
    const lower = toLower(query, &buf) orelse return null;
    if (std.meta.stringToEnum(std.Target.Cpu.Arch, lower)) |arch| return .{ arch, null };
    if (std.StaticStringMap(ArchSubArch).initComptime(.{
        .{ "i386", .{ .x86, null } },
        .{ "i486", .{ .x86, null } },
        .{ "i586", .{ .x86, null } },
        .{ "i686", .{ .x86, null } },
        .{ "i786", .{ .x86, null } },
        .{ "i886", .{ .x86, null } },
        .{ "i986", .{ .x86, null } },
        .{ "amd64", .{ .x86_64, null } },
        .{ "x86_64h", .{ .x86_64, null } },
        .{ "powerpcspe", .{ .powerpc, .powerpc_spe } },
        .{ "ppc", .{ .powerpc, null } },
        .{ "ppc32", .{ .powerpc, null } },
        .{ "ppcle", .{ .powerpcle, null } },
        .{ "ppc32le", .{ .powerpcle, null } },
        .{ "ppu", .{ .powerpc64, null } },
        .{ "ppc64", .{ .powerpc64, null } },
        .{ "ppc64le", .{ .powerpc64le, null } },
        .{ "xscale", .{ .arm, null } },
        .{ "xscaleeb", .{ .armeb, null } },
        .{ "arm64", .{ .aarch64, null } },
        .{ "arm64e", .{ .aarch64, .aarch64_arm64e } },
        .{ "arm64ec", .{ .aarch64, .aarch64_arm64ec } },
        .{ "mipseb", .{ .mips, null } },
        .{ "mipsallegrex", .{ .mips, null } },
        .{ "mipsisa32r6", .{ .mips, .mips_r6 } },
        .{ "mipsr6", .{ .mips, .mips_r6 } },
        .{ "mipsallegrexel", .{ .mipsel, null } },
        .{ "mipsisa32r6el", .{ .mipsel, .mips_r6 } },
        .{ "mipsr6el", .{ .mipsel, .mips_r6 } },
        .{ "mips64eb", .{ .mips64, null } },
        .{ "mipsn32", .{ .mips64, null } },
        .{ "mipsisa64r6", .{ .mips64, .mips_r6 } },
        .{ "mips64r6", .{ .mips64, .mips_r6 } },
        .{ "mipsn32r6", .{ .mips64, .mips_r6 } },
        .{ "mipsn32el", .{ .mips64el, null } },
        .{ "mipsisa64r6el", .{ .mips64el, .mips_r6 } },
        .{ "mips64r6el", .{ .mips64el, .mips_r6 } },
        .{ "mipsn32r6el", .{ .mips64el, .mips_r6 } },
        .{ "systemz", .{ .s390x, null } },
        .{ "sparcv9", .{ .sparc64, null } },
        .{ "spirv32", .{ .spirv32, null } },
        .{ "spirv32v1.0", .{ .spirv32, .spirv_v10 } },
        .{ "spirv32v1.1", .{ .spirv32, .spirv_v11 } },
        .{ "spirv32v1.2", .{ .spirv32, .spirv_v12 } },
        .{ "spirv32v1.3", .{ .spirv32, .spirv_v13 } },
        .{ "spirv32v1.4", .{ .spirv32, .spirv_v14 } },
        .{ "spirv32v1.5", .{ .spirv32, .spirv_v15 } },
        .{ "spirv32v1.6", .{ .spirv32, .spirv_v16 } },
        .{ "spirv64v1.0", .{ .spirv64, .spirv_v10 } },
        .{ "spirv64v1.1", .{ .spirv64, .spirv_v11 } },
        .{ "spirv64v1.2", .{ .spirv64, .spirv_v12 } },
        .{ "spirv64v1.3", .{ .spirv64, .spirv_v13 } },
        .{ "spirv64v1.4", .{ .spirv64, .spirv_v14 } },
        .{ "spirv64v1.5", .{ .spirv64, .spirv_v15 } },
        .{ "spirv64v1.6", .{ .spirv64, .spirv_v16 } },
    }).get(lower)) |arch_sub_arch| return arch_sub_arch;

    const arm_subarch = std.StaticStringMap(SubArch).initComptime(.{
        .{ "v4t", .arm_v4t },
        .{ "v5", .arm_v5 },
        .{ "v5t", .arm_v5 },
        .{ "v5e", .arm_v5te },
        .{ "v5te", .arm_v5te },
        .{ "v6", .arm_v6 },
        .{ "v6j", .arm_v6 },
        .{ "v6k", .arm_v6k },
        .{ "v6hl", .arm_v6k },
        .{ "v6m", .arm_v6m },
        .{ "v6sm", .arm_v6m },
        .{ "v6s-m", .arm_v6m },
        .{ "v6-m", .arm_v6m },
        .{ "v6z", .arm_v6k },
        .{ "v6zk", .arm_v6k },
        .{ "v6kz", .arm_v6k },
        .{ "v7", .arm_v7 },
        .{ "v7a", .arm_v7 },
        .{ "v7hl", .arm_v7 },
        .{ "v7l", .arm_v7 },
        .{ "v7-a", .arm_v7 },
        .{ "v7r", .arm_v7 },
        .{ "v7r", .arm_v7 },
        .{ "v7m", .arm_v7s },
        .{ "v7-m", .arm_v7s },
        .{ "v7em", .arm_v7em },
        .{ "v7e-m", .arm_v7em },
        .{ "v8", .arm_v8 },
        .{ "v8a", .arm_v8 },
        .{ "v8l", .arm_v8 },
        .{ "v8-a", .arm_v8 },
        .{ "v8.1a", .arm_v8_1a },
        .{ "v8.1-a", .arm_v8_1a },
        .{ "v82.a", .arm_v8_2a },
        .{ "v82.-a", .arm_v8_2a },
        .{ "v83.a", .arm_v8_3a },
        .{ "v83.-a", .arm_v8_3a },
        .{ "v84.a", .arm_v8_4a },
        .{ "v84.-a", .arm_v8_4a },
        .{ "v85.a", .arm_v8_5a },
        .{ "v85.-a", .arm_v8_5a },
        .{ "v86.a", .arm_v8_6a },
        .{ "v86.-a", .arm_v8_6a },
        .{ "v8.7a", .arm_v8_7a },
        .{ "v8.7-a", .arm_v8_7a },
        .{ "v8.8a", .arm_v8_8a },
        .{ "v8.8-a", .arm_v8_8a },
        .{ "v8.9a", .arm_v8_9a },
        .{ "v8.9-a", .arm_v8_9a },
        .{ "v8r", .arm_v8r },
        .{ "v8-r", .arm_v8r },
        .{ "v9", .arm_v9 },
        .{ "v9a", .arm_v9 },
        .{ "v9-a", .arm_v9 },
        .{ "v9.1a", .arm_v9_1a },
        .{ "v9.1-a", .arm_v9_1a },
        .{ "v9.2a", .arm_v9_2a },
        .{ "v9.2-a", .arm_v9_2a },
        .{ "v9.3a", .arm_v9_3a },
        .{ "v9.3-a", .arm_v9_3a },
        .{ "v9.4a", .arm_v9_4a },
        .{ "v9.4-a", .arm_v9_4a },
        .{ "v9.5a", .arm_v9_5a },
        .{ "v9.5-a", .arm_v9_5a },
        .{ "v9.6a", .arm_v9_6a },
        .{ "v9.6-a", .arm_v9_6a },
        .{ "v8m.base", .arm_v8m_baseline },
        .{ "v8-m.base", .arm_v8m_baseline },
        .{ "v8m.main", .arm_v8m_mainline },
        .{ "v8-m.main", .arm_v8m_mainline },
        .{ "v8.1m.main", .arm_v8_1m_mainline },
        .{ "v8.1-m.main", .arm_v8_1m_mainline },
    });

    for ([_]Cpu.Arch{ .arm, .armeb, .thumb, .thumbeb, .aarch64, .aarch64_be }) |arch| {
        const name = @tagName(arch);
        if (!mem.startsWith(u8, lower, name)) continue;
        var actual_arch = arch;
        var trimmed = lower[name.len..];
        if (arch == .arm and mem.endsWith(u8, trimmed, "eb")) {
            actual_arch = .armeb;
            trimmed.len -= 2;
        } else if (arch == .thumb and mem.endsWith(u8, trimmed, "eb")) {
            actual_arch = .thumbeb;
            trimmed.len -= 2;
        }

        if (arm_subarch.get(trimmed)) |sub_arch| {
            if (actual_arch.isThumb()) {
                switch (sub_arch) {
                    .arm_v6m, .arm_v7em, .arm_v7m => {},
                    else => if (actual_arch == .thumb) {
                        actual_arch = .arm;
                    } else {
                        actual_arch = .armeb;
                    },
                }
            } else if (actual_arch.isArm()) {
                switch (sub_arch) {
                    .arm_v6m, .arm_v7em, .arm_v7m => if (actual_arch == .arm) {
                        actual_arch = .thumb;
                    } else {
                        actual_arch = .thumbeb;
                    },
                    else => {},
                }
            }
            return .{ actual_arch, sub_arch };
        }
    }

    if (mem.startsWith(u8, lower, "bpf")) {
        if (lower.len == 3) return switch (@import("builtin").cpu.arch.endian()) {
            .little => return .{ .bpfel, null },
            .big => return .{ .bpfeb, null },
        };
        const rest = lower[3..];
        if (mem.eql(u8, rest, "_le") or mem.eql(u8, rest, "el")) return .{ .bpfel, null };
        if (mem.eql(u8, rest, "_be") or mem.eql(u8, rest, "eb")) return .{ .bpfeb, null };
    }

    return null;
}

test parseArchName {
    {
        const arch, const sub_arch = parseArchName("spirv64v1.6").?;
        try testing.expect(arch == .spirv64);
        try testing.expect(sub_arch == .spirv_v16);
    }
    {
        const arch, const sub_arch = parseArchName("i786").?;
        try testing.expect(arch == .x86);
        try testing.expect(sub_arch == null);
    }
    {
        const arch, const sub_arch = parseArchName("bpf_le").?;
        try testing.expect(arch == .bpfel);
        try testing.expect(sub_arch == null);
    }
    {
        const arch, const sub_arch = parseArchName("armv8eb").?;
        try testing.expect(arch == .armeb);
        try testing.expect(sub_arch == .arm_v8);
    }
}

pub fn parseOsName(query: []const u8) ?Os.Tag {
    var buf: [64]u8 = undefined;
    const lower = toLower(query, &buf) orelse return null;
    return std.meta.stringToEnum(Os.Tag, lower) orelse
        std.StaticStringMap(Os.Tag).initComptime(.{
            .{ "darwin", .macos },
            .{ "macosx", .macos },
            .{ "win32", .windows },
            .{ "xros", .visionos },
        }).get(lower) orelse return null;
}

pub fn isOs(target: *const Target, query: []const u8) bool {
    const parsed = parseOsName(query) orelse return false;

    if (parsed.isDarwin()) {
        // clang treats all darwin OS's as equivalent
        return target.os.tag.isDarwin();
    }
    return parsed == target.os.tag;
}

pub fn parseVendorName(query: []const u8) ?Vendor {
    var buf: [64]u8 = undefined;
    const lower = toLower(query, &buf) orelse return null;
    return Vendor.parse(lower);
}

pub fn parseAbiName(query: []const u8) ?Abi {
    var buf: [64]u8 = undefined;
    const lower = toLower(query, &buf) orelse return null;
    return std.meta.stringToEnum(Abi, lower);
}

pub fn isAbi(target: *const Target, query: []const u8) bool {
    var buf: [64]u8 = undefined;
    const lower = toLower(query, &buf) orelse return false;
    if (std.meta.stringToEnum(Abi, lower)) |some| {
        if (some == .none and target.os.tag == .maccatalyst) {
            // Clang thinks maccatalyst has macabi
            return false;
        }
        return target.abi == some;
    }
    if (mem.eql(u8, lower, "macabi")) {
        return target.os.tag == .maccatalyst;
    }
    return false;
}

pub fn defaultFpEvalMethod(target: *const Target) LangOpts.FPEvalMethod {
    switch (target.cpu.arch) {
        .x86, .x86_64 => {
            if (target.ptrBitWidth() == 32 and target.os.tag == .netbsd) {
                if (target.os.version_range.semver.min.order(.{ .major = 6, .minor = 99, .patch = 26 }) != .gt) {
                    // NETBSD <= 6.99.26 on 32-bit x86 defaults to double
                    return .double;
                }
            }
            if (std.Target.x86.featureSetHas(target.cpu.features, .sse)) {
                return .source;
            }
            return .extended;
        },
        else => {},
    }
    return .source;
}

/// Value of the `-m` flag for `ld` for this target
pub fn ldEmulationOption(target: *const Target, arm_endianness: ?std.builtin.Endian) ?[]const u8 {
    return switch (target.cpu.arch) {
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => switch (arm_endianness orelse target.cpu.arch.endian()) {
            .little => "armelf_linux_eabi",
            .big => "armelfb_linux_eabi",
        },
        .aarch64 => "aarch64linux",
        .aarch64_be => "aarch64linuxb",
        .csky => "cskyelf_linux",
        .loongarch32 => "elf32loongarch",
        .loongarch64 => "elf64loongarch",
        .m68k => "m68kelf",
        .mips => "elf32btsmip",
        .mips64 => switch (target.abi) {
            .gnuabin32, .muslabin32 => "elf32btsmipn32",
            else => "elf64btsmip",
        },
        .mips64el => switch (target.abi) {
            .gnuabin32, .muslabin32 => "elf32ltsmipn32",
            else => "elf64ltsmip",
        },
        .mipsel => "elf32ltsmip",
        .powerpc => if (target.os.tag == .linux) "elf32ppclinux" else "elf32ppc",
        .powerpc64 => "elf64ppc",
        .powerpc64le => "elf64lppc",
        .powerpcle => if (target.os.tag == .linux) "elf32lppclinux" else "elf32lppc",
        .riscv32 => "elf32lriscv",
        .riscv64 => "elf64lriscv",
        .sparc => "elf32_sparc",
        .sparc64 => "elf64_sparc",
        .ve => "elf64ve",
        .x86 => "elf_i386",
        .x86_64 => switch (target.abi) {
            .gnux32, .muslx32 => "elf32_x86_64",
            else => "elf_x86_64",
        },
        else => null,
    };
}

pub fn get32BitArchVariant(target: *const Target) ?Target {
    var copy = target.*;
    switch (target.cpu.arch) {
        .alpha,
        .amdgcn,
        .avr,
        .bpfeb,
        .bpfel,
        .kvx,
        .msp430,
        .s390x,
        .ve,
        => return null,

        .arc,
        .arceb,
        .arm,
        .armeb,
        .csky,
        .hexagon,
        .hppa,
        .kalimba,
        .lanai,
        .loongarch32,
        .m68k,
        .microblaze,
        .microblazeel,
        .mips,
        .mipsel,
        .nvptx,
        .or1k,
        .powerpc,
        .powerpcle,
        .propeller,
        .riscv32,
        .riscv32be,
        .sh,
        .sheb,
        .sparc,
        .spirv32,
        .thumb,
        .thumbeb,
        .wasm32,
        .x86,
        .xcore,
        .xtensa,
        .xtensaeb,
        => {}, // Already 32 bit

        .aarch64 => copy.cpu.arch = .arm,
        .aarch64_be => copy.cpu.arch = .armeb,
        .hppa64 => copy.cpu.arch = .hppa,
        .loongarch64 => copy.cpu.arch = .loongarch32,
        .mips64 => copy.cpu.arch = .mips,
        .mips64el => copy.cpu.arch = .mipsel,
        .nvptx64 => copy.cpu.arch = .nvptx,
        .powerpc64 => copy.cpu.arch = .powerpc,
        .powerpc64le => copy.cpu.arch = .powerpcle,
        .riscv64 => copy.cpu.arch = .riscv32,
        .riscv64be => copy.cpu.arch = .riscv32be,
        .sparc64 => copy.cpu.arch = .sparc,
        .spirv64 => copy.cpu.arch = .spirv32,
        .wasm64 => copy.cpu.arch = .wasm32,
        .x86_16 => copy.cpu.arch = .x86,
        .x86_64 => copy.cpu.arch = .x86,
    }
    return copy;
}

pub fn get64BitArchVariant(target: *const Target) ?Target {
    var copy = target.*;
    switch (target.cpu.arch) {
        .arc,
        .arceb,
        .avr,
        .csky,
        .hexagon,
        .kalimba,
        .lanai,
        .m68k,
        .microblaze,
        .microblazeel,
        .msp430,
        .or1k,
        .propeller,
        .sh,
        .sheb,
        .xcore,
        .xtensa,
        .xtensaeb,
        => return null,

        .aarch64_be,
        .aarch64,
        .alpha,
        .amdgcn,
        .bpfeb,
        .bpfel,
        .hppa64,
        .kvx,
        .loongarch64,
        .mips64,
        .mips64el,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .riscv64,
        .riscv64be,
        .s390x,
        .sparc64,
        .spirv64,
        .ve,
        .wasm64,
        .x86_64,
        => {}, // Already 64 bit

        .arm => copy.cpu.arch = .aarch64,
        .armeb => copy.cpu.arch = .aarch64_be,
        .hppa => copy.cpu.arch = .hppa64,
        .loongarch32 => copy.cpu.arch = .loongarch64,
        .mips => copy.cpu.arch = .mips64,
        .mipsel => copy.cpu.arch = .mips64el,
        .nvptx => copy.cpu.arch = .nvptx64,
        .powerpc => copy.cpu.arch = .powerpc64,
        .powerpcle => copy.cpu.arch = .powerpc64le,
        .riscv32 => copy.cpu.arch = .riscv64,
        .riscv32be => copy.cpu.arch = .riscv64be,
        .sparc => copy.cpu.arch = .sparc64,
        .spirv32 => copy.cpu.arch = .spirv64,
        .thumb => copy.cpu.arch = .aarch64,
        .thumbeb => copy.cpu.arch = .aarch64_be,
        .wasm32 => copy.cpu.arch = .wasm64,
        .x86 => copy.cpu.arch = .x86_64,
        .x86_16 => copy.cpu.arch = .x86_64,
    }
    return copy;
}

/// Adapted from Zig's src/codegen/llvm.zig
pub fn toLLVMTriple(target: *const Target, buf: []u8) []const u8 {
    // 64 bytes is assumed to be large enough to hold any target triple; increase if necessary
    std.debug.assert(buf.len >= 64);

    var writer: std.Io.Writer = .fixed(buf);

    const llvm_arch = switch (target.cpu.arch) {
        .aarch64 => if (target.abi == .ilp32) "aarch64_32" else "aarch64",
        .aarch64_be => "aarch64_be",
        .amdgcn => "amdgcn",
        .arc => "arc",
        .arm => "arm",
        .armeb => "armeb",
        .avr => "avr",
        .bpfeb => "bpfeb",
        .bpfel => "bpfel",
        .csky => "csky",
        .hexagon => "hexagon",
        .lanai => "lanai",
        .loongarch32 => "loongarch32",
        .loongarch64 => "loongarch64",
        .m68k => "m68k",
        .mips => "mips",
        .mips64 => "mips64",
        .mips64el => "mips64el",
        .mipsel => "mipsel",
        .msp430 => "msp430",
        .nvptx => "nvptx",
        .nvptx64 => "nvptx64",
        .powerpc => "powerpc",
        .powerpc64 => "powerpc64",
        .powerpc64le => "powerpc64le",
        .powerpcle => "powerpcle",
        .riscv32 => "riscv32",
        .riscv32be => "riscv32be",
        .riscv64 => "riscv64",
        .riscv64be => "riscv64be",
        .s390x => "s390x",
        .sparc => "sparc",
        .sparc64 => "sparc64",
        .spirv32 => "spirv32",
        .spirv64 => "spirv64",
        .thumb => "thumb",
        .thumbeb => "thumbeb",
        .ve => "ve",
        .wasm32 => "wasm32",
        .wasm64 => "wasm64",
        .x86 => "i386",
        .x86_64 => "x86_64",
        .xcore => "xcore",
        .xtensa => "xtensa",

        // Note: these are not supported in LLVM; this is the Zig arch name
        .alpha => "alpha",
        .arceb => "arceb",
        .hppa => "hppa",
        .hppa64 => "hppa64",
        .kalimba => "kalimba",
        .kvx => "kvx",
        .microblaze => "microblaze",
        .microblazeel => "microblazeel",
        .or1k => "or1k",
        .propeller => "propeller",
        .sh => "sh",
        .sheb => "sheb",
        .x86_16 => "i86",
        .xtensaeb => "xtensaeb",
    };
    writer.writeAll(llvm_arch) catch unreachable;
    writer.writeByte('-') catch unreachable;

    const llvm_os = switch (target.os.tag) {
        .amdhsa => "amdhsa",
        .amdpal => "amdpal",
        .contiki => "contiki",
        .cuda => "cuda",
        .dragonfly => "dragonfly",
        .driverkit => "driverkit",
        .emscripten => "emscripten",
        .freebsd => "freebsd",
        .freestanding => "unknown",
        .fuchsia => "fuchsia",
        .haiku => "haiku",
        .hermit => "hermit",
        .hurd => "hurd",
        .illumos => "illumos",
        .ios, .maccatalyst => "ios",
        .linux => "linux",
        .macos => "macosx",
        .managarm => "managarm",
        .mesa3d => "mesa3d",
        .netbsd => "netbsd",
        .nvcl => "nvcl",
        .openbsd => "openbsd",
        .ps3 => "lv2",
        .ps4 => "ps4",
        .ps5 => "ps5",
        .rtems => "rtems",
        .serenity => "serenity",
        .tvos => "tvos",
        .uefi => "windows",
        .visionos => "xros",
        .vulkan => "vulkan",
        .wasi => "wasi",
        .watchos => "watchos",
        .windows => "windows",

        .@"3ds",
        .opencl,
        .opengl,
        .other,
        .plan9,
        .vita,
        => "unknown",
    };
    writer.writeAll(llvm_os) catch unreachable;

    if (target.os.tag.isDarwin()) {
        const min_version = target.os.version_range.semver.min;
        writer.print("{d}.{d}.{d}", .{
            min_version.major,
            min_version.minor,
            min_version.patch,
        }) catch unreachable;
    }
    writer.writeByte('-') catch unreachable;

    const llvm_abi = switch (target.abi) {
        .none => if (target.os.tag == .maccatalyst) "macabi" else "unknown",
        .ilp32 => "unknown",

        .android => "android",
        .androideabi => "androideabi",
        .eabi => "eabi",
        .eabihf => "eabihf",
        .gnu => "gnu",
        .gnuabi64 => "gnuabi64",
        .gnuabin32 => "gnuabin32",
        .gnueabi => "gnueabi",
        .gnueabihf => "gnueabihf",
        .gnuf32 => "gnuf32",
        .gnusf => "gnusf",
        .gnux32 => "gnux32",
        .itanium => "itanium",
        .msvc => "msvc",
        .musl => "musl",
        .muslabi64 => "muslabi64",
        .muslabin32 => "muslabin32",
        .musleabi => "musleabi",
        .musleabihf => "musleabihf",
        .muslf32 => "muslf32",
        .muslsf => "muslsf",
        .muslx32 => "muslx32",
        .ohos => "ohos",
        .ohoseabi => "ohoseabi",
        .simulator => "simulator",
    };
    writer.writeAll(llvm_abi) catch unreachable;
    return writer.buffered();
}

pub const DefaultPIStatus = enum { yes, no, depends_on_linker };

pub fn isPIEDefault(target: *const Target) DefaultPIStatus {
    return switch (target.os.tag) {
        .haiku,

        .maccatalyst,
        .macos,
        .ios,
        .tvos,
        .watchos,
        .visionos,
        .driverkit,

        .dragonfly,
        .netbsd,
        .freebsd,
        .illumos,

        .cuda,
        .amdhsa,
        .amdpal,
        .mesa3d,

        .ps4,
        .ps5,

        .hurd,
        => .no,

        .openbsd,
        .fuchsia,
        => .yes,

        .linux => {
            if (target.abi == .ohos)
                return .yes;

            switch (target.cpu.arch) {
                .ve => return .no,
                else => return if (target.os.tag == .linux or target.abi.isAndroid() or target.abi.isMusl()) .yes else .no,
            }
        },

        .windows => {
            if (target.isMinGW())
                return .no;

            if (target.abi == .itanium)
                return if (target.cpu.arch == .x86_64) .yes else .no;

            if (target.abi == .msvc or target.abi == .none)
                return .depends_on_linker;

            return .no;
        },

        else => {
            switch (target.cpu.arch) {
                .hexagon => {
                    // CLANG_DEFAULT_PIE_ON_LINUX
                    return if (target.os.tag == .linux or target.abi.isAndroid() or target.abi.isMusl()) .yes else .no;
                },

                else => return .no,
            }
        },
    };
}

pub fn isPICdefault(target: *const Target) DefaultPIStatus {
    return switch (target.os.tag) {
        .haiku,

        .maccatalyst,
        .macos,
        .ios,
        .tvos,
        .watchos,
        .visionos,
        .driverkit,

        .amdhsa,
        .amdpal,
        .mesa3d,

        .ps4,
        .ps5,
        => .yes,

        .fuchsia,
        .cuda,
        => .no,

        .dragonfly,
        .openbsd,
        .netbsd,
        .freebsd,
        .illumos,
        .hurd,
        => {
            return switch (target.cpu.arch) {
                .mips64, .mips64el => .yes,
                else => .no,
            };
        },

        .linux => {
            if (target.abi == .ohos)
                return .no;

            return switch (target.cpu.arch) {
                .mips64, .mips64el => .yes,
                else => .no,
            };
        },

        .windows => {
            if (target.isMinGW())
                return if (target.cpu.arch == .x86_64 or target.cpu.arch == .aarch64) .yes else .no;

            if (target.abi == .itanium)
                return if (target.cpu.arch == .x86_64) .yes else .no;

            if (target.abi == .msvc or target.abi == .none)
                return .depends_on_linker;

            if (target.ofmt == .macho)
                return .yes;

            return switch (target.cpu.arch) {
                .x86_64, .mips64, .mips64el => .yes,
                else => .no,
            };
        },

        else => {
            if (target.ofmt == .macho)
                return .yes;

            return switch (target.cpu.arch) {
                .mips64, .mips64el => .yes,
                else => .no,
            };
        },
    };
}

pub fn isPICDefaultForced(target: *const Target) DefaultPIStatus {
    return switch (target.os.tag) {
        .amdhsa, .amdpal, .mesa3d => .yes,

        .haiku,
        .dragonfly,
        .openbsd,
        .netbsd,
        .freebsd,
        .illumos,
        .cuda,
        .ps4,
        .ps5,
        .hurd,
        .linux,
        .fuchsia,
        => .no,

        .windows => {
            if (target.isMinGW())
                return .yes;

            if (target.abi == .itanium)
                return if (target.cpu.arch == .x86_64) .yes else .no;

            // if (bfd) return target.cpu.arch == .x86_64 else target.cpu.arch == .x86_64 or target.cpu.arch == .aarch64;
            if (target.abi == .msvc or target.abi == .none)
                return .depends_on_linker;

            if (target.ofmt == .macho)
                return if (target.cpu.arch == .aarch64 or target.cpu.arch == .x86_64) .yes else .no;

            return if (target.cpu.arch == .x86_64) .yes else .no;
        },

        .maccatalyst,
        .macos,
        .ios,
        .tvos,
        .watchos,
        .visionos,
        .driverkit,
        => if (target.cpu.arch == .x86_64 or target.cpu.arch == .aarch64) .yes else .no,

        else => {
            return switch (target.cpu.arch) {
                .hexagon,
                .lanai,
                .avr,
                .riscv32,
                .riscv64,
                .csky,
                .xcore,
                .wasm32,
                .wasm64,
                .ve,
                .spirv32,
                .spirv64,
                => .no,

                .msp430 => .yes,

                else => {
                    if (target.ofmt == .macho)
                        return if (target.cpu.arch == .aarch64 or target.cpu.arch == .x86_64) .yes else .no;
                    return .no;
                },
            };
        },
    };
}

test "alignment functions - smoke test" {
    const linux: Os = .{ .tag = .linux, .version_range = .{ .none = {} } };
    const x86_64_target: Target = .{
        .abi = .default(.x86_64, linux.tag),
        .vendor = .unknown,
        .cpu = Cpu.Model.generic(.x86_64).toCpu(.x86_64),
        .os = linux,
        .ofmt = .elf,
    };

    try std.testing.expect(isTlsSupported(&x86_64_target));
    try std.testing.expect(!ignoreNonZeroSizedBitfieldTypeAlignment(&x86_64_target));
    try std.testing.expect(minZeroWidthBitfieldAlignment(&x86_64_target) == null);
    try std.testing.expect(!unnamedFieldAffectsAlignment(&x86_64_target));
    try std.testing.expect(defaultAlignment(&x86_64_target) == 16);
    try std.testing.expect(!packAllEnums(&x86_64_target));
    try std.testing.expect(systemCompiler(&x86_64_target) == .gcc);
}

test "target size/align tests" {
    var comp: @import("Compilation.zig") = undefined;

    const linux: Os = .{ .tag = .linux, .version_range = .{ .none = {} } };
    const x86_target: Target = .{
        .abi = .default(.x86, linux.tag),
        .vendor = .unknown,
        .cpu = Cpu.Model.generic(.x86).toCpu(.x86),
        .os = linux,
        .ofmt = .elf,
    };
    comp.target = x86_target;

    const tt: QualType = .long_long;

    try std.testing.expectEqual(@as(u64, 8), tt.sizeof(&comp));
    try std.testing.expectEqual(@as(u64, 4), tt.alignof(&comp));
}

/// The canonical integer representation of nullptr_t.
pub fn nullRepr(_: *const Target) u64 {
    return 0;
}

pub fn ptrBitWidth(target: *const Target) u16 {
    return std.Target.ptrBitWidth_cpu_abi(target.cpu, target.abi);
}

pub fn cCharSignedness(target: *const Target) std.builtin.Signedness {
    return target.toZigTarget().cCharSignedness();
}

pub fn cTypeBitSize(target: *const Target, c_type: std.Target.CType) u16 {
    return target.toZigTarget().cTypeBitSize(c_type);
}

pub fn cTypeAlignment(target: *const Target, c_type: std.Target.CType) u16 {
    return target.toZigTarget().cTypeAlignment(c_type);
}

pub fn standardDynamicLinkerPath(target: *const Target) std.Target.DynamicLinker {
    return .standard(target.cpu, target.os, target.abi);
}

/// Parse ABI string in `<abi>(.?<version>)?` format.
///
/// Poplates `abi`, `glibc_version` and `android_api_level` fields of `result`.
///
/// If given `version_string` will be populated when `InvalidAbiVersion` or `InvalidApiVerson` is returned.
pub fn parseAbi(result: *std.Target.Query, text: []const u8, version_string: ?*[]const u8) !void {
    const abi, const version_text = for (text, 0..) |c, i| switch (c) {
        '0'...'9' => {
            if (parseAbiName(text[0..i])) |abi| {
                break .{ abi, text[i..] };
            }
        },
        '.' => break .{
            parseAbiName(text[0..i]) orelse return error.UnknownAbi, text[i + 1 ..],
        },
        else => {},
    } else .{ parseAbiName(text) orelse {
        if (mem.eql(u8, text, "macabi")) {
            if (result.os_tag == .ios) {
                result.os_tag = .maccatalyst;
                return;
            }
        }
        return error.UnknownAbi;
    }, "" };
    result.abi = abi;
    if (version_string) |ptr| ptr.* = version_text;

    if (version_text.len != 0) {
        if (abi.isGnu()) {
            result.glibc_version = std.Target.Query.parseVersion(version_text) catch |er| switch (er) {
                error.Overflow, error.InvalidVersion => return error.InvalidAbiVersion,
            };
        } else if (abi.isAndroid()) {
            result.android_api_level = std.fmt.parseUnsigned(u32, version_text, 10) catch |er| switch (er) {
                error.Overflow, error.InvalidCharacter => return error.InvalidApiVersion,
            };
        } else return error.InvalidAbiVersion;
    }
}

test parseAbi {
    const V = std.SemanticVersion;
    var query: std.Target.Query = .{};
    try parseAbi(&query, "gnuabin322.3", null);
    try testing.expect(query.abi == .gnuabin32);
    try testing.expectEqual(query.glibc_version, V{ .major = 2, .minor = 3, .patch = 0 });

    try parseAbi(&query, "gnuabin32.2.3", null);
    try testing.expect(query.abi == .gnuabin32);
    try testing.expectEqual(query.glibc_version, V{ .major = 2, .minor = 3, .patch = 0 });

    try parseAbi(&query, "android17", null);
    try testing.expect(query.abi == .android);
    try testing.expectEqual(query.android_api_level, 17);

    try parseAbi(&query, "android.17", null);
    try testing.expect(query.abi == .android);
    try testing.expectEqual(query.android_api_level, 17);

    try testing.expectError(error.InvalidAbiVersion, parseAbi(&query, "ilp322", null));
    try testing.expect(query.abi == .ilp32);

    try testing.expectError(error.InvalidAbiVersion, parseAbi(&query, "ilp32.2", null));
    try testing.expect(query.abi == .ilp32);
}

/// Parse OS string with common aliases in `<os>(.?<version>(...<version>))?` format.
///
/// `native` <os> results in `builtin.os.tag`.
///
/// Poplates `os_tag`, `os_version_min` and `os_version_max` fields of `result`.
///
/// If given `version_string` will be populated when `InvalidOsVersion` is returned.
pub fn parseOs(result: *std.Target.Query, text: []const u8, version_string: ?*[]const u8) !void {
    const checkOs = struct {
        fn checkOs(os_text: []const u8) ?Os.Tag {
            const os_is_native = mem.eql(u8, os_text, "native");
            if (os_is_native) return @import("builtin").os.tag;
            return parseOsName(os_text);
        }
    }.checkOs;

    var seen_digit = false;
    const tag, const version_text = for (text, 0..) |c, i| switch (c) {
        '0'...'9' => {
            if (i == 0) continue;
            if (checkOs(text[0..i])) |os| {
                break .{ os, text[i..] };
            }
            seen_digit = true;
        },
        '.' => break .{
            checkOs(text[0..i]) orelse return error.UnknownOs, text[i + 1 ..],
        },
        else => if (seen_digit) {
            if (checkOs(text[0..i])) |os| {
                break .{ os, text[i..] };
            }
        },
    } else .{ checkOs(text) orelse return error.UnknownOs, "" };
    result.os_tag = tag;
    if (version_string) |ptr| ptr.* = version_text;

    if (version_text.len > 0) switch (tag.versionRangeTag()) {
        .none => return error.InvalidOsVersion,
        .semver, .hurd, .linux => {
            var range_it = mem.splitSequence(u8, version_text, "...");
            result.os_version_min = .{
                .semver = std.Target.Query.parseVersion(range_it.first()) catch |er| switch (er) {
                    error.Overflow, error.InvalidVersion => return error.InvalidOsVersion,
                },
            };
            if (range_it.next()) |v| {
                result.os_version_max = .{
                    .semver = std.Target.Query.parseVersion(v) catch |er| switch (er) {
                        error.Overflow, error.InvalidVersion => return error.InvalidOsVersion,
                    },
                };
            }
        },
        .windows => {
            var range_it = mem.splitSequence(u8, version_text, "...");
            result.os_version_min = .{
                .windows = Os.WindowsVersion.parse(range_it.first()) catch |er| switch (er) {
                    error.InvalidOperatingSystemVersion => return error.InvalidOsVersion,
                },
            };
            if (range_it.next()) |v| {
                result.os_version_max = .{
                    .windows = Os.WindowsVersion.parse(v) catch |er| switch (er) {
                        error.InvalidOperatingSystemVersion => return error.InvalidOsVersion,
                    },
                };
            }
        },
    };
}

test parseOs {
    const V = std.Target.Query.OsVersion;
    var query: std.Target.Query = .{};
    try parseOs(&query, "3ds2.3", null);
    try testing.expect(query.os_tag == .@"3ds");
    try testing.expectEqual(query.os_version_min, V{ .semver = .{ .major = 2, .minor = 3, .patch = 0 } });

    try parseOs(&query, "3ds.2.3", null);
    try testing.expect(query.os_tag == .@"3ds");
    try testing.expectEqual(query.os_version_min, V{ .semver = .{ .major = 2, .minor = 3, .patch = 0 } });

    try testing.expectError(error.InvalidOsVersion, parseOs(&query, "ps33.3", null));
    try testing.expect(query.os_tag == .ps3);

    try testing.expectError(error.InvalidOsVersion, parseOs(&query, "ps3.3.3", null));
    try testing.expect(query.os_tag == .ps3);

    try parseOs(&query, "linux6.17", null);
    try testing.expect(query.os_tag == .linux);
    try testing.expectEqual(query.os_version_min, V{ .semver = .{ .major = 6, .minor = 17, .patch = 0 } });

    try parseOs(&query, "linux.6.17", null);
    try testing.expect(query.os_tag == .linux);
    try testing.expectEqual(query.os_version_min, V{ .semver = .{ .major = 6, .minor = 17, .patch = 0 } });

    try parseOs(&query, "win32win10", null);
    try testing.expect(query.os_tag == .windows);
    try testing.expectEqual(query.os_version_min, V{ .windows = .win10 });

    try parseOs(&query, "win32.win10", null);
    try testing.expect(query.os_tag == .windows);
    try testing.expectEqual(query.os_version_min, V{ .windows = .win10 });
}
