//! All the details about the machine that will be executing code.
//! Unlike `Query` which might leave some things as "default" or "host", this
//! data is fully resolved into a concrete set of OS versions, CPU features,
//! etc.

cpu: Cpu,
os: Os,
abi: Abi,
ofmt: ObjectFormat,
dynamic_linker: DynamicLinker = DynamicLinker.none,

pub const Query = @import("Target/Query.zig");

pub const Os = struct {
    tag: Tag,
    version_range: VersionRange,

    pub const Tag = enum {
        freestanding,
        other,

        contiki,
        elfiamcu,
        fuchsia,
        hermit,

        aix,
        haiku,
        hurd,
        linux,
        plan9,
        rtems,
        serenity,
        zos,

        dragonfly,
        freebsd,
        netbsd,
        openbsd,

        driverkit,
        ios,
        macos,
        tvos,
        visionos,
        watchos,

        illumos,
        solaris,

        windows,
        uefi,

        ps3,
        ps4,
        ps5,

        emscripten,
        wasi,

        amdhsa,
        amdpal,
        cuda,
        mesa3d,
        nvcl,
        opencl,
        opengl,
        vulkan,

        // LLVM tags deliberately omitted:
        // - bridgeos
        // - darwin
        // - kfreebsd
        // - nacl
        // - shadermodel

        pub inline fn isDarwin(tag: Tag) bool {
            return switch (tag) {
                .driverkit,
                .ios,
                .macos,
                .tvos,
                .visionos,
                .watchos,
                => true,
                else => false,
            };
        }

        pub inline fn isBSD(tag: Tag) bool {
            return tag.isDarwin() or switch (tag) {
                .freebsd, .openbsd, .netbsd, .dragonfly => true,
                else => false,
            };
        }

        pub inline fn isSolarish(tag: Tag) bool {
            return tag == .solaris or tag == .illumos;
        }

        pub fn exeFileExt(tag: Tag, arch: Cpu.Arch) [:0]const u8 {
            return switch (tag) {
                .windows => ".exe",
                .uefi => ".efi",
                .plan9 => arch.plan9Ext(),
                else => switch (arch) {
                    .wasm32, .wasm64 => ".wasm",
                    else => "",
                },
            };
        }

        pub fn staticLibSuffix(tag: Tag, abi: Abi) [:0]const u8 {
            return switch (abi) {
                .msvc, .itanium => ".lib",
                else => switch (tag) {
                    .windows, .uefi => ".lib",
                    else => ".a",
                },
            };
        }

        pub fn dynamicLibSuffix(tag: Tag) [:0]const u8 {
            return switch (tag) {
                .windows, .uefi => ".dll",
                .driverkit,
                .ios,
                .macos,
                .tvos,
                .visionos,
                .watchos,
                => ".dylib",
                else => ".so",
            };
        }

        pub fn libPrefix(tag: Os.Tag, abi: Abi) [:0]const u8 {
            return switch (abi) {
                .msvc, .itanium => "",
                else => switch (tag) {
                    .windows, .uefi => "",
                    else => "lib",
                },
            };
        }

        pub inline fn isGnuLibC(tag: Os.Tag, abi: Abi) bool {
            return (tag == .hurd or tag == .linux) and abi.isGnu();
        }

        pub fn defaultVersionRange(tag: Tag, arch: Cpu.Arch, abi: Abi) Os {
            return .{
                .tag = tag,
                .version_range = .default(arch, tag, abi),
            };
        }

        pub inline fn versionRangeTag(tag: Tag) @typeInfo(TaggedVersionRange).@"union".tag_type.? {
            return switch (tag) {
                .freestanding,
                .other,

                .elfiamcu,

                .haiku,
                .plan9,
                .serenity,

                .illumos,

                .ps3,
                .ps4,
                .ps5,

                .emscripten,

                .mesa3d,
                => .none,

                .contiki,
                .fuchsia,
                .hermit,

                .aix,
                .rtems,
                .zos,

                .dragonfly,
                .freebsd,
                .netbsd,
                .openbsd,

                .driverkit,
                .macos,
                .ios,
                .tvos,
                .visionos,
                .watchos,

                .solaris,

                .uefi,

                .wasi,

                .amdhsa,
                .amdpal,
                .cuda,
                .nvcl,
                .opencl,
                .opengl,
                .vulkan,
                => .semver,

                .hurd => .hurd,
                .linux => .linux,

                .windows => .windows,
            };
        }

        pub fn archName(tag: Tag, arch: Cpu.Arch) [:0]const u8 {
            return switch (tag) {
                .linux => switch (arch) {
                    .arm, .armeb, .thumb, .thumbeb => "arm",
                    .aarch64, .aarch64_be => "aarch64",
                    .loongarch32, .loongarch64 => "loongarch",
                    .mips, .mipsel, .mips64, .mips64el => "mips",
                    .powerpc, .powerpcle, .powerpc64, .powerpc64le => "powerpc",
                    .riscv32, .riscv64 => "riscv",
                    .sparc, .sparc64 => "sparc",
                    .x86, .x86_64 => "x86",
                    else => @tagName(arch),
                },
                else => @tagName(arch),
            };
        }
    };

    /// Based on NTDDI version constants from
    /// https://docs.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt
    pub const WindowsVersion = enum(u32) {
        nt4 = 0x04000000,
        win2k = 0x05000000,
        xp = 0x05010000,
        ws2003 = 0x05020000,
        vista = 0x06000000,
        win7 = 0x06010000,
        win8 = 0x06020000,
        win8_1 = 0x06030000,
        win10 = 0x0A000000, //aka win10_th1
        win10_th2 = 0x0A000001,
        win10_rs1 = 0x0A000002,
        win10_rs2 = 0x0A000003,
        win10_rs3 = 0x0A000004,
        win10_rs4 = 0x0A000005,
        win10_rs5 = 0x0A000006,
        win10_19h1 = 0x0A000007,
        win10_vb = 0x0A000008, //aka win10_19h2
        win10_mn = 0x0A000009, //aka win10_20h1
        win10_fe = 0x0A00000A, //aka win10_20h2
        win10_co = 0x0A00000B, //aka win10_21h1
        win10_ni = 0x0A00000C, //aka win10_21h2
        win10_cu = 0x0A00000D, //aka win10_22h2
        win11_zn = 0x0A00000E, //aka win11_21h2
        win11_ga = 0x0A00000F, //aka win11_22h2
        win11_ge = 0x0A000010, //aka win11_23h2
        win11_dt = 0x0A000011, //aka win11_24h2
        _,

        /// Latest Windows version that the Zig Standard Library is aware of
        pub const latest = WindowsVersion.win11_dt;

        /// Compared against build numbers reported by the runtime to distinguish win10 versions,
        /// where 0x0A000000 + index corresponds to the WindowsVersion u32 value.
        pub const known_win10_build_numbers = [_]u32{
            10240, //win10 aka win10_th1
            10586, //win10_th2
            14393, //win10_rs1
            15063, //win10_rs2
            16299, //win10_rs3
            17134, //win10_rs4
            17763, //win10_rs5
            18362, //win10_19h1
            18363, //win10_vb aka win10_19h2
            19041, //win10_mn aka win10_20h1
            19042, //win10_fe aka win10_20h2
            19043, //win10_co aka win10_21h1
            19044, //win10_ni aka win10_21h2
            19045, //win10_cu aka win10_22h2
            22000, //win11_zn aka win11_21h2
            22621, //win11_ga aka win11_22h2
            22631, //win11_ge aka win11_23h2
            26100, //win11_dt aka win11_24h2
        };

        /// Returns whether the first version `ver` is newer (greater) than or equal to the second version `ver`.
        pub inline fn isAtLeast(ver: WindowsVersion, min_ver: WindowsVersion) bool {
            return @intFromEnum(ver) >= @intFromEnum(min_ver);
        }

        pub const Range = struct {
            min: WindowsVersion,
            max: WindowsVersion,

            pub inline fn includesVersion(range: Range, ver: WindowsVersion) bool {
                return @intFromEnum(ver) >= @intFromEnum(range.min) and
                    @intFromEnum(ver) <= @intFromEnum(range.max);
            }

            /// Checks if system is guaranteed to be at least `version` or older than `version`.
            /// Returns `null` if a runtime check is required.
            pub inline fn isAtLeast(range: Range, min_ver: WindowsVersion) ?bool {
                if (@intFromEnum(range.min) >= @intFromEnum(min_ver)) return true;
                if (@intFromEnum(range.max) < @intFromEnum(min_ver)) return false;
                return null;
            }
        };

        pub fn parse(str: []const u8) !WindowsVersion {
            return std.meta.stringToEnum(WindowsVersion, str) orelse
                @enumFromInt(std.fmt.parseInt(u32, str, 0) catch
                return error.InvalidOperatingSystemVersion);
        }

        /// This function is defined to serialize a Zig source code representation of this
        /// type, that, when parsed, will deserialize into the same data.
        pub fn format(
            ver: WindowsVersion,
            comptime fmt_str: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            const maybe_name = std.enums.tagName(WindowsVersion, ver);
            if (comptime std.mem.eql(u8, fmt_str, "s")) {
                if (maybe_name) |name|
                    try writer.print(".{s}", .{name})
                else
                    try writer.print(".{d}", .{@intFromEnum(ver)});
            } else if (comptime std.mem.eql(u8, fmt_str, "c")) {
                if (maybe_name) |name|
                    try writer.print(".{s}", .{name})
                else
                    try writer.print("@enumFromInt(0x{X:0>8})", .{@intFromEnum(ver)});
            } else if (fmt_str.len == 0) {
                if (maybe_name) |name|
                    try writer.print("WindowsVersion.{s}", .{name})
                else
                    try writer.print("WindowsVersion(0x{X:0>8})", .{@intFromEnum(ver)});
            } else std.fmt.invalidFmtError(fmt_str, ver);
        }
    };

    pub const HurdVersionRange = struct {
        range: std.SemanticVersion.Range,
        glibc: std.SemanticVersion,

        pub inline fn includesVersion(range: HurdVersionRange, ver: std.SemanticVersion) bool {
            return range.range.includesVersion(ver);
        }

        /// Checks if system is guaranteed to be at least `version` or older than `version`.
        /// Returns `null` if a runtime check is required.
        pub inline fn isAtLeast(range: HurdVersionRange, ver: std.SemanticVersion) ?bool {
            return range.range.isAtLeast(ver);
        }
    };

    pub const LinuxVersionRange = struct {
        range: std.SemanticVersion.Range,
        glibc: std.SemanticVersion,
        /// Android API level.
        android: u32,

        pub inline fn includesVersion(range: LinuxVersionRange, ver: std.SemanticVersion) bool {
            return range.range.includesVersion(ver);
        }

        /// Checks if system is guaranteed to be at least `version` or older than `version`.
        /// Returns `null` if a runtime check is required.
        pub inline fn isAtLeast(range: LinuxVersionRange, ver: std.SemanticVersion) ?bool {
            return range.range.isAtLeast(ver);
        }
    };

    /// The version ranges here represent the minimum OS version to be supported
    /// and the maximum OS version to be supported. The default values represent
    /// the range that the Zig Standard Library bases its abstractions on.
    ///
    /// The minimum version of the range is the main setting to tweak for a target.
    /// Usually, the maximum target OS version will remain the default, which is
    /// the latest released version of the OS.
    ///
    /// To test at compile time if the target is guaranteed to support a given OS feature,
    /// one should check that the minimum version of the range is greater than or equal to
    /// the version the feature was introduced in.
    ///
    /// To test at compile time if the target certainly will not support a given OS feature,
    /// one should check that the maximum version of the range is less than the version the
    /// feature was introduced in.
    ///
    /// If neither of these cases apply, a runtime check should be used to determine if the
    /// target supports a given OS feature.
    ///
    /// Binaries built with a given maximum version will continue to function on newer
    /// operating system versions. However, such a binary may not take full advantage of the
    /// newer operating system APIs.
    ///
    /// See `Os.isAtLeast`.
    pub const VersionRange = union {
        none: void,
        semver: std.SemanticVersion.Range,
        hurd: HurdVersionRange,
        linux: LinuxVersionRange,
        windows: WindowsVersion.Range,

        /// The default `VersionRange` represents the range that the Zig Standard Library
        /// bases its abstractions on.
        pub fn default(arch: Cpu.Arch, tag: Tag, abi: Abi) VersionRange {
            return switch (tag) {
                .freestanding,
                .other,

                .elfiamcu,

                .haiku,
                .plan9,
                .serenity,

                .illumos,

                .ps3,
                .ps4,
                .ps5,

                .emscripten,

                .mesa3d,
                => .{ .none = {} },

                .contiki => .{
                    .semver = .{
                        .min = .{ .major = 4, .minor = 0, .patch = 0 },
                        .max = .{ .major = 4, .minor = 9, .patch = 0 },
                    },
                },
                .fuchsia => .{
                    .semver = .{
                        .min = .{ .major = 1, .minor = 1, .patch = 0 },
                        .max = .{ .major = 20, .minor = 1, .patch = 0 },
                    },
                },
                .hermit => .{
                    .semver = .{
                        .min = .{ .major = 0, .minor = 4, .patch = 0 },
                        .max = .{ .major = 0, .minor = 8, .patch = 0 },
                    },
                },

                .aix => .{
                    .semver = .{
                        .min = .{ .major = 7, .minor = 2, .patch = 5 },
                        .max = .{ .major = 7, .minor = 3, .patch = 2 },
                    },
                },
                .hurd => .{
                    .hurd = .{
                        .range = .{
                            .min = .{ .major = 0, .minor = 9, .patch = 0 },
                            .max = .{ .major = 0, .minor = 9, .patch = 0 },
                        },
                        .glibc = .{ .major = 2, .minor = 28, .patch = 0 },
                    },
                },
                .linux => .{
                    .linux = .{
                        .range = .{
                            .min = blk: {
                                const default_min: std.SemanticVersion = .{ .major = 4, .minor = 19, .patch = 0 };

                                for (std.zig.target.available_libcs) |libc| {
                                    if (libc.arch != arch or libc.os != tag or libc.abi != abi) continue;

                                    if (libc.os_ver) |min| {
                                        if (min.order(default_min) == .gt) break :blk min;
                                    }
                                }

                                break :blk default_min;
                            },
                            .max = .{ .major = 6, .minor = 11, .patch = 5 },
                        },
                        .glibc = blk: {
                            const default_min: std.SemanticVersion = .{ .major = 2, .minor = 28, .patch = 0 };

                            for (std.zig.target.available_libcs) |libc| {
                                if (libc.os != tag or libc.arch != arch or libc.abi != abi) continue;

                                if (libc.glibc_min) |min| {
                                    if (min.order(default_min) == .gt) break :blk min;
                                }
                            }

                            break :blk default_min;
                        },
                        .android = 14,
                    },
                },
                .rtems => .{
                    .semver = .{
                        .min = .{ .major = 5, .minor = 1, .patch = 0 },
                        .max = .{ .major = 5, .minor = 3, .patch = 0 },
                    },
                },
                .zos => .{
                    .semver = .{
                        .min = .{ .major = 2, .minor = 5, .patch = 0 },
                        .max = .{ .major = 3, .minor = 1, .patch = 0 },
                    },
                },

                .dragonfly => .{
                    .semver = .{
                        .min = .{ .major = 5, .minor = 8, .patch = 0 },
                        .max = .{ .major = 6, .minor = 4, .patch = 0 },
                    },
                },
                .freebsd => .{
                    .semver = .{
                        .min = .{ .major = 12, .minor = 0, .patch = 0 },
                        .max = .{ .major = 14, .minor = 2, .patch = 0 },
                    },
                },
                .netbsd => .{
                    .semver = .{
                        .min = .{ .major = 8, .minor = 0, .patch = 0 },
                        .max = .{ .major = 10, .minor = 1, .patch = 0 },
                    },
                },
                .openbsd => .{
                    .semver = .{
                        .min = .{ .major = 7, .minor = 3, .patch = 0 },
                        .max = .{ .major = 7, .minor = 6, .patch = 0 },
                    },
                },

                .driverkit => .{
                    .semver = .{
                        .min = .{ .major = 19, .minor = 0, .patch = 0 },
                        .max = .{ .major = 24, .minor = 2, .patch = 0 },
                    },
                },
                .macos => .{
                    .semver = .{
                        .min = .{ .major = 13, .minor = 0, .patch = 0 },
                        .max = .{ .major = 15, .minor = 3, .patch = 0 },
                    },
                },
                .ios => .{
                    .semver = .{
                        .min = .{ .major = 12, .minor = 0, .patch = 0 },
                        .max = .{ .major = 18, .minor = 3, .patch = 0 },
                    },
                },
                .tvos => .{
                    .semver = .{
                        .min = .{ .major = 13, .minor = 0, .patch = 0 },
                        .max = .{ .major = 18, .minor = 3, .patch = 0 },
                    },
                },
                .visionos => .{
                    .semver = .{
                        .min = .{ .major = 1, .minor = 0, .patch = 0 },
                        .max = .{ .major = 2, .minor = 3, .patch = 0 },
                    },
                },
                .watchos => .{
                    .semver = .{
                        .min = .{ .major = 6, .minor = 0, .patch = 0 },
                        .max = .{ .major = 11, .minor = 3, .patch = 0 },
                    },
                },

                .solaris => .{
                    .semver = .{
                        .min = .{ .major = 11, .minor = 0, .patch = 0 },
                        .max = .{ .major = 11, .minor = 4, .patch = 0 },
                    },
                },

                .windows => .{
                    .windows = .{
                        .min = .win10,
                        .max = WindowsVersion.latest,
                    },
                },
                .uefi => .{
                    .semver = .{
                        .min = .{ .major = 2, .minor = 0, .patch = 0 },
                        .max = .{ .major = 2, .minor = 11, .patch = 0 },
                    },
                },

                .wasi => .{
                    .semver = .{
                        .min = .{ .major = 0, .minor = 1, .patch = 0 },
                        .max = .{ .major = 0, .minor = 2, .patch = 2 },
                    },
                },

                .amdhsa => .{
                    .semver = .{
                        .min = .{ .major = 5, .minor = 0, .patch = 2 },
                        .max = .{ .major = 6, .minor = 2, .patch = 2 },
                    },
                },
                .amdpal => .{
                    .semver = .{
                        .min = .{ .major = 1, .minor = 1, .patch = 0 },
                        .max = .{ .major = 3, .minor = 5, .patch = 0 },
                    },
                },
                .cuda => .{
                    .semver = .{
                        .min = .{ .major = 11, .minor = 0, .patch = 1 },
                        .max = .{ .major = 12, .minor = 6, .patch = 1 },
                    },
                },
                .nvcl,
                .opencl,
                => .{
                    .semver = .{
                        .min = .{ .major = 2, .minor = 2, .patch = 0 },
                        .max = .{ .major = 3, .minor = 0, .patch = 0 },
                    },
                },
                .opengl => .{
                    .semver = .{
                        .min = .{ .major = 4, .minor = 5, .patch = 0 },
                        .max = .{ .major = 4, .minor = 6, .patch = 0 },
                    },
                },
                .vulkan => .{
                    .semver = .{
                        .min = .{ .major = 1, .minor = 2, .patch = 0 },
                        .max = .{ .major = 1, .minor = 3, .patch = 0 },
                    },
                },
            };
        }
    };

    pub const TaggedVersionRange = union(enum) {
        none: void,
        semver: std.SemanticVersion.Range,
        hurd: HurdVersionRange,
        linux: LinuxVersionRange,
        windows: WindowsVersion.Range,

        pub fn gnuLibCVersion(range: TaggedVersionRange) ?std.SemanticVersion {
            return switch (range) {
                .none, .semver, .windows => null,
                .hurd => |h| h.glibc,
                .linux => |l| l.glibc,
            };
        }
    };

    /// Provides a tagged union. `Target` does not store the tag because it is
    /// redundant with the OS tag; this function abstracts that part away.
    pub inline fn versionRange(os: Os) TaggedVersionRange {
        return switch (os.tag.versionRangeTag()) {
            .none => .{ .none = {} },
            .semver => .{ .semver = os.version_range.semver },
            .hurd => .{ .hurd = os.version_range.hurd },
            .linux => .{ .linux = os.version_range.linux },
            .windows => .{ .windows = os.version_range.windows },
        };
    }

    /// Checks if system is guaranteed to be at least `version` or older than `version`.
    /// Returns `null` if a runtime check is required.
    pub inline fn isAtLeast(os: Os, comptime tag: Tag, ver: switch (tag.versionRangeTag()) {
        .none => void,
        .semver, .hurd, .linux => std.SemanticVersion,
        .windows => WindowsVersion,
    }) ?bool {
        return if (os.tag != tag) false else switch (tag.versionRangeTag()) {
            .none => true,
            inline .semver,
            .hurd,
            .linux,
            .windows,
            => |field| @field(os.version_range, @tagName(field)).isAtLeast(ver),
        };
    }

    /// On Darwin, we always link libSystem which contains libc.
    /// Similarly on FreeBSD and NetBSD we always link system libc
    /// since this is the stable syscall interface.
    pub fn requiresLibC(os: Os) bool {
        return switch (os.tag) {
            .freebsd,
            .aix,
            .netbsd,
            .driverkit,
            .macos,
            .ios,
            .tvos,
            .watchos,
            .visionos,
            .dragonfly,
            .openbsd,
            .haiku,
            .solaris,
            .illumos,
            .serenity,
            => true,

            .linux,
            .windows,
            .freestanding,
            .fuchsia,
            .ps3,
            .zos,
            .rtems,
            .cuda,
            .nvcl,
            .amdhsa,
            .ps4,
            .ps5,
            .elfiamcu,
            .mesa3d,
            .contiki,
            .amdpal,
            .hermit,
            .hurd,
            .wasi,
            .emscripten,
            .uefi,
            .opencl,
            .opengl,
            .vulkan,
            .plan9,
            .other,
            => false,
        };
    }
};

pub const aarch64 = @import("Target/aarch64.zig");
pub const arc = @import("Target/arc.zig");
pub const amdgcn = @import("Target/amdgcn.zig");
pub const arm = @import("Target/arm.zig");
pub const avr = @import("Target/avr.zig");
pub const bpf = @import("Target/bpf.zig");
pub const csky = @import("Target/csky.zig");
pub const hexagon = @import("Target/hexagon.zig");
pub const lanai = @import("Target/lanai.zig");
pub const loongarch = @import("Target/loongarch.zig");
pub const m68k = @import("Target/m68k.zig");
pub const mips = @import("Target/mips.zig");
pub const msp430 = @import("Target/msp430.zig");
pub const nvptx = @import("Target/nvptx.zig");
pub const powerpc = @import("Target/powerpc.zig");
pub const riscv = @import("Target/riscv.zig");
pub const sparc = @import("Target/sparc.zig");
pub const spirv = @import("Target/spirv.zig");
pub const s390x = @import("Target/s390x.zig");
pub const ve = @import("Target/ve.zig");
pub const wasm = @import("Target/wasm.zig");
pub const x86 = @import("Target/x86.zig");
pub const xcore = @import("Target/xcore.zig");
pub const xtensa = @import("Target/xtensa.zig");
pub const propeller = @import("Target/propeller.zig");

pub const Abi = enum {
    none,
    gnu,
    gnuabin32,
    gnuabi64,
    gnueabi,
    gnueabihf,
    gnuf32,
    gnusf,
    gnux32,
    gnuilp32,
    code16,
    eabi,
    eabihf,
    ilp32,
    android,
    androideabi,
    musl,
    muslabin32,
    muslabi64,
    musleabi,
    musleabihf,
    muslx32,
    msvc,
    itanium,
    cygnus,
    simulator,
    macabi,
    ohos,
    ohoseabi,

    // LLVM tags deliberately omitted:
    // - amplification
    // - anyhit
    // - callable
    // - closesthit
    // - compute
    // - coreclr
    // - domain
    // - geometry
    // - gnuf64
    // - hull
    // - intersection
    // - library
    // - mesh
    // - miss
    // - pixel
    // - raygeneration
    // - vertex

    pub fn default(arch: Cpu.Arch, os: Os) Abi {
        return switch (os.tag) {
            .freestanding, .other => switch (arch) {
                // Soft float is usually a sane default for freestanding.
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .csky,
                .mips,
                .mipsel,
                .powerpc,
                .powerpcle,
                => .eabi,
                else => .none,
            },
            .aix => if (arch == .powerpc) .eabihf else .none,
            .haiku => switch (arch) {
                .arm,
                .thumb,
                .powerpc,
                => .eabihf,
                else => .none,
            },
            .hurd => .gnu,
            .linux => switch (arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .powerpc,
                .powerpcle,
                => .musleabihf,
                // Soft float tends to be more common for CSKY and MIPS.
                .csky,
                => .gnueabi, // No musl support.
                .mips,
                .mipsel,
                => .musleabi,
                .mips64,
                .mips64el,
                => .muslabi64,
                else => .musl,
            },
            .rtems => switch (arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .mips,
                .mipsel,
                => .eabi,
                .powerpc,
                => .eabihf,
                else => .none,
            },
            .freebsd => switch (arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .powerpc,
                => .eabihf,
                // Soft float tends to be more common for MIPS.
                .mips,
                .mipsel,
                => .eabi,
                else => .none,
            },
            .netbsd => switch (arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .powerpc,
                => .eabihf,
                // Soft float tends to be more common for MIPS.
                .mips,
                .mipsel,
                => .eabi,
                else => .none,
            },
            .openbsd => switch (arch) {
                .arm,
                .thumb,
                => .eabi,
                .powerpc,
                => .eabihf,
                else => .none,
            },
            .ios => if (arch == .x86_64) .macabi else .none,
            .tvos, .visionos, .watchos => if (arch == .x86_64) .simulator else .none,
            .windows => .gnu,
            .uefi => .msvc,
            .wasi, .emscripten => .musl,

            .contiki,
            .elfiamcu,
            .fuchsia,
            .hermit,
            .plan9,
            .serenity,
            .zos,
            .dragonfly,
            .driverkit,
            .macos,
            .illumos,
            .solaris,
            .ps3,
            .ps4,
            .ps5,
            .amdhsa,
            .amdpal,
            .cuda,
            .mesa3d,
            .nvcl,
            .opencl,
            .opengl,
            .vulkan,
            => .none,
        };
    }

    pub inline fn isGnu(abi: Abi) bool {
        return switch (abi) {
            .gnu,
            .gnuabin32,
            .gnuabi64,
            .gnueabi,
            .gnueabihf,
            .gnuf32,
            .gnusf,
            .gnux32,
            .gnuilp32,
            => true,
            else => false,
        };
    }

    pub inline fn isMusl(abi: Abi) bool {
        return switch (abi) {
            .musl,
            .muslabin32,
            .muslabi64,
            .musleabi,
            .musleabihf,
            .muslx32,
            => true,
            else => abi.isOpenHarmony(),
        };
    }

    pub inline fn isOpenHarmony(abi: Abi) bool {
        return switch (abi) {
            .ohos, .ohoseabi => true,
            else => false,
        };
    }

    pub inline fn isAndroid(abi: Abi) bool {
        return switch (abi) {
            .android, .androideabi => true,
            else => false,
        };
    }

    pub inline fn floatAbi(abi: Abi) FloatAbi {
        return switch (abi) {
            .androideabi,
            .eabi,
            .gnueabi,
            .musleabi,
            .gnusf,
            .ohoseabi,
            => .soft,
            else => .hard,
        };
    }
};

pub const ObjectFormat = enum {
    /// C source code.
    c,
    /// The Common Object File Format used by Windows and UEFI.
    coff,
    /// The Executable and Linkable Format used by many Unixes.
    elf,
    /// The Generalized Object File Format used by z/OS.
    goff,
    /// The Intel HEX format for storing binary code in ASCII text.
    hex,
    /// The Mach object format used by macOS and other Apple platforms.
    macho,
    /// Nvidia's PTX (Parallel Thread Execution) assembly language.
    nvptx,
    /// The a.out format used by Plan 9 from Bell Labs.
    plan9,
    /// Machine code with no metadata.
    raw,
    /// The Khronos Group's Standard Portable Intermediate Representation V.
    spirv,
    /// The WebAssembly binary format.
    wasm,
    /// The eXtended Common Object File Format used by AIX.
    xcoff,

    // LLVM tags deliberately omitted:
    // - dxcontainer

    pub fn fileExt(of: ObjectFormat, arch: Cpu.Arch) [:0]const u8 {
        return switch (of) {
            .c => ".c",
            .coff => ".obj",
            .elf, .goff, .macho, .wasm, .xcoff => ".o",
            .hex => ".ihex",
            .nvptx => ".ptx",
            .plan9 => arch.plan9Ext(),
            .raw => ".bin",
            .spirv => ".spv",
        };
    }

    pub fn default(os_tag: Os.Tag, arch: Cpu.Arch) ObjectFormat {
        return switch (os_tag) {
            .aix => .xcoff,
            .driverkit, .ios, .macos, .tvos, .visionos, .watchos => .macho,
            .plan9 => .plan9,
            .uefi, .windows => .coff,
            .zos => .goff,
            else => switch (arch) {
                .nvptx, .nvptx64 => .nvptx,
                .spirv, .spirv32, .spirv64 => .spirv,
                .wasm32, .wasm64 => .wasm,
                else => .elf,
            },
        };
    }
};

pub fn toElfMachine(target: Target) std.elf.EM {
    return switch (target.cpu.arch) {
        .amdgcn => .AMDGPU,
        .arc => .ARC_COMPACT,
        .arm, .armeb, .thumb, .thumbeb => .ARM,
        .aarch64, .aarch64_be => .AARCH64,
        .avr => .AVR,
        .bpfel, .bpfeb => .BPF,
        .csky => .CSKY,
        .hexagon => .QDSP6,
        .kalimba => .CSR_KALIMBA,
        .lanai => .LANAI,
        .loongarch32, .loongarch64 => .LOONGARCH,
        .m68k => .@"68K",
        .mips, .mips64, .mipsel, .mips64el => .MIPS,
        .msp430 => .MSP430,
        .powerpc, .powerpcle => .PPC,
        .powerpc64, .powerpc64le => .PPC64,
        .riscv32, .riscv64 => .RISCV,
        .s390x => .S390,
        .sparc => if (Target.sparc.featureSetHas(target.cpu.features, .v9)) .SPARC32PLUS else .SPARC,
        .sparc64 => .SPARCV9,
        .spu_2 => .SPU_2,
        .ve => .VE,
        .x86 => if (target.os.tag == .elfiamcu) .IAMCU else .@"386",
        .x86_64 => .X86_64,
        .xcore => .XCORE,
        .xtensa => .XTENSA,

        .propeller1 => .PROPELLER,
        .propeller2 => .PROPELLER2,

        .nvptx,
        .nvptx64,
        .spirv,
        .spirv32,
        .spirv64,
        .wasm32,
        .wasm64,
        => .NONE,
    };
}

pub fn toCoffMachine(target: Target) std.coff.MachineType {
    return switch (target.cpu.arch) {
        .arm => .ARM,
        .thumb => .ARMNT,
        .aarch64 => .ARM64,
        .loongarch32 => .LOONGARCH32,
        .loongarch64 => .LOONGARCH64,
        .riscv32 => .RISCV32,
        .riscv64 => .RISCV64,
        .x86 => .I386,
        .x86_64 => .X64,

        .amdgcn,
        .arc,
        .armeb,
        .thumbeb,
        .aarch64_be,
        .avr,
        .bpfel,
        .bpfeb,
        .csky,
        .hexagon,
        .kalimba,
        .lanai,
        .m68k,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .msp430,
        .nvptx,
        .nvptx64,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .s390x,
        .sparc,
        .sparc64,
        .spirv,
        .spirv32,
        .spirv64,
        .spu_2,
        .ve,
        .wasm32,
        .wasm64,
        .xcore,
        .xtensa,
        .propeller1,
        .propeller2,
        => .UNKNOWN,
    };
}

pub const SubSystem = enum {
    Console,
    Windows,
    Posix,
    Native,
    EfiApplication,
    EfiBootServiceDriver,
    EfiRom,
    EfiRuntimeDriver,
};

pub const Cpu = struct {
    /// Architecture
    arch: Arch,

    /// The CPU model to target. It has a set of features
    /// which are overridden with the `features` field.
    model: *const Model,

    /// An explicit list of the entire CPU feature set. It may differ from the specific CPU model's features.
    features: Feature.Set,

    pub const Feature = struct {
        /// The bit index into `Set`. Has a default value of `undefined` because the canonical
        /// structures are populated via comptime logic.
        index: Set.Index = undefined,

        /// Has a default value of `undefined` because the canonical
        /// structures are populated via comptime logic.
        name: []const u8 = undefined,

        /// If this corresponds to an LLVM-recognized feature, this will be populated;
        /// otherwise null.
        llvm_name: ?[:0]const u8,

        /// Human-friendly UTF-8 text.
        description: []const u8,

        /// Sparse `Set` of features this depends on.
        dependencies: Set,

        /// A bit set of all the features.
        pub const Set = struct {
            ints: [usize_count]usize,

            pub const needed_bit_count = 288;
            pub const byte_count = (needed_bit_count + 7) / 8;
            pub const usize_count = (byte_count + (@sizeOf(usize) - 1)) / @sizeOf(usize);
            pub const Index = std.math.Log2Int(std.meta.Int(.unsigned, usize_count * @bitSizeOf(usize)));
            pub const ShiftInt = std.math.Log2Int(usize);

            pub const empty = Set{ .ints = [1]usize{0} ** usize_count };

            pub fn isEmpty(set: Set) bool {
                return for (set.ints) |x| {
                    if (x != 0) break false;
                } else true;
            }

            pub fn count(set: Set) std.math.IntFittingRange(0, needed_bit_count) {
                var sum: usize = 0;
                for (set.ints) |x| sum += @popCount(x);
                return @intCast(sum);
            }

            pub fn isEnabled(set: Set, arch_feature_index: Index) bool {
                const usize_index = arch_feature_index / @bitSizeOf(usize);
                const bit_index: ShiftInt = @intCast(arch_feature_index % @bitSizeOf(usize));
                return (set.ints[usize_index] & (@as(usize, 1) << bit_index)) != 0;
            }

            /// Adds the specified feature but not its dependencies.
            pub fn addFeature(set: *Set, arch_feature_index: Index) void {
                const usize_index = arch_feature_index / @bitSizeOf(usize);
                const bit_index: ShiftInt = @intCast(arch_feature_index % @bitSizeOf(usize));
                set.ints[usize_index] |= @as(usize, 1) << bit_index;
            }

            /// Adds the specified feature set but not its dependencies.
            pub fn addFeatureSet(set: *Set, other_set: Set) void {
                switch (builtin.zig_backend) {
                    .stage2_x86_64 => {
                        for (&set.ints, other_set.ints) |*set_int, other_set_int| set_int.* |= other_set_int;
                    },
                    else => {
                        set.ints = @as(@Vector(usize_count, usize), set.ints) | @as(@Vector(usize_count, usize), other_set.ints);
                    },
                }
            }

            /// Removes the specified feature but not its dependents.
            pub fn removeFeature(set: *Set, arch_feature_index: Index) void {
                const usize_index = arch_feature_index / @bitSizeOf(usize);
                const bit_index: ShiftInt = @intCast(arch_feature_index % @bitSizeOf(usize));
                set.ints[usize_index] &= ~(@as(usize, 1) << bit_index);
            }

            /// Removes the specified feature but not its dependents.
            pub fn removeFeatureSet(set: *Set, other_set: Set) void {
                switch (builtin.zig_backend) {
                    .stage2_x86_64 => {
                        for (&set.ints, other_set.ints) |*set_int, other_set_int| set_int.* &= ~other_set_int;
                    },
                    else => {
                        set.ints = @as(@Vector(usize_count, usize), set.ints) & ~@as(@Vector(usize_count, usize), other_set.ints);
                    },
                }
            }

            pub fn populateDependencies(set: *Set, all_features_list: []const Cpu.Feature) void {
                @setEvalBranchQuota(1000000);

                var old = set.ints;
                while (true) {
                    for (all_features_list, 0..) |feature, index_usize| {
                        const index: Index = @intCast(index_usize);
                        if (set.isEnabled(index)) {
                            set.addFeatureSet(feature.dependencies);
                        }
                    }
                    const nothing_changed = std.mem.eql(usize, &old, &set.ints);
                    if (nothing_changed) return;
                    old = set.ints;
                }
            }

            pub fn asBytes(set: *const Set) *const [byte_count]u8 {
                return std.mem.sliceAsBytes(&set.ints)[0..byte_count];
            }

            pub fn eql(set: Set, other_set: Set) bool {
                return std.mem.eql(usize, &set.ints, &other_set.ints);
            }

            pub fn isSuperSetOf(set: Set, other_set: Set) bool {
                switch (builtin.zig_backend) {
                    .stage2_x86_64 => {
                        var result = true;
                        for (&set.ints, other_set.ints) |*set_int, other_set_int|
                            result = result and (set_int.* & other_set_int) == other_set_int;
                        return result;
                    },
                    else => {
                        const V = @Vector(usize_count, usize);
                        const set_v: V = set.ints;
                        const other_v: V = other_set.ints;
                        return @reduce(.And, (set_v & other_v) == other_v);
                    },
                }
            }
        };

        pub fn FeatureSetFns(comptime F: type) type {
            return struct {
                /// Populates only the feature bits specified.
                pub fn featureSet(features: []const F) Set {
                    var x = Set.empty;
                    for (features) |feature| {
                        x.addFeature(@intFromEnum(feature));
                    }
                    return x;
                }

                /// Returns true if the specified feature is enabled.
                pub fn featureSetHas(set: Set, feature: F) bool {
                    return set.isEnabled(@intFromEnum(feature));
                }

                /// Returns true if any specified feature is enabled.
                pub fn featureSetHasAny(set: Set, features: anytype) bool {
                    inline for (features) |feature| {
                        if (set.isEnabled(@intFromEnum(@as(F, feature)))) return true;
                    }
                    return false;
                }

                /// Returns true if every specified feature is enabled.
                pub fn featureSetHasAll(set: Set, features: anytype) bool {
                    inline for (features) |feature| {
                        if (!set.isEnabled(@intFromEnum(@as(F, feature)))) return false;
                    }
                    return true;
                }
            };
        }
    };

    pub const Arch = enum {
        amdgcn,
        arc,
        arm,
        armeb,
        thumb,
        thumbeb,
        aarch64,
        aarch64_be,
        avr,
        bpfel,
        bpfeb,
        csky,
        hexagon,
        kalimba,
        lanai,
        loongarch32,
        loongarch64,
        m68k,
        mips,
        mipsel,
        mips64,
        mips64el,
        msp430,
        nvptx,
        nvptx64,
        powerpc,
        powerpcle,
        powerpc64,
        powerpc64le,
        propeller1,
        propeller2,
        riscv32,
        riscv64,
        s390x,
        sparc,
        sparc64,
        spirv,
        spirv32,
        spirv64,
        spu_2,
        ve,
        wasm32,
        wasm64,
        x86,
        x86_64,
        xcore,
        xtensa,

        // LLVM tags deliberately omitted:
        // - aarch64_32
        // - amdil
        // - amdil64
        // - dxil
        // - le32
        // - le64
        // - r600
        // - hsail
        // - hsail64
        // - renderscript32
        // - renderscript64
        // - shave
        // - sparcel
        // - spir
        // - spir64
        // - tce
        // - tcele

        pub inline fn isX86(arch: Arch) bool {
            return switch (arch) {
                .x86, .x86_64 => true,
                else => false,
            };
        }

        /// Note that this includes Thumb.
        pub inline fn isArm(arch: Arch) bool {
            return switch (arch) {
                .arm, .armeb => true,
                else => arch.isThumb(),
            };
        }

        pub inline fn isThumb(arch: Arch) bool {
            return switch (arch) {
                .thumb, .thumbeb => true,
                else => false,
            };
        }

        pub inline fn isAARCH64(arch: Arch) bool {
            return switch (arch) {
                .aarch64, .aarch64_be => true,
                else => false,
            };
        }

        pub inline fn isWasm(arch: Arch) bool {
            return switch (arch) {
                .wasm32, .wasm64 => true,
                else => false,
            };
        }

        pub inline fn isLoongArch(arch: Arch) bool {
            return switch (arch) {
                .loongarch32, .loongarch64 => true,
                else => false,
            };
        }

        pub inline fn isRISCV(arch: Arch) bool {
            return switch (arch) {
                .riscv32, .riscv64 => true,
                else => false,
            };
        }

        pub inline fn isMIPS(arch: Arch) bool {
            return arch.isMIPS32() or arch.isMIPS64();
        }

        pub inline fn isMIPS32(arch: Arch) bool {
            return switch (arch) {
                .mips, .mipsel => true,
                else => false,
            };
        }

        pub inline fn isMIPS64(arch: Arch) bool {
            return switch (arch) {
                .mips64, .mips64el => true,
                else => false,
            };
        }

        pub inline fn isPowerPC(arch: Arch) bool {
            return arch.isPowerPC32() or arch.isPowerPC64();
        }

        pub inline fn isPowerPC32(arch: Arch) bool {
            return switch (arch) {
                .powerpc, .powerpcle => true,
                else => false,
            };
        }

        pub inline fn isPowerPC64(arch: Arch) bool {
            return switch (arch) {
                .powerpc64, .powerpc64le => true,
                else => false,
            };
        }

        pub inline fn isSPARC(arch: Arch) bool {
            return switch (arch) {
                .sparc, .sparc64 => true,
                else => false,
            };
        }

        pub inline fn isSpirV(arch: Arch) bool {
            return switch (arch) {
                .spirv, .spirv32, .spirv64 => true,
                else => false,
            };
        }

        pub inline fn isBpf(arch: Arch) bool {
            return switch (arch) {
                .bpfel, .bpfeb => true,
                else => false,
            };
        }

        pub inline fn isNvptx(arch: Arch) bool {
            return switch (arch) {
                .nvptx, .nvptx64 => true,
                else => false,
            };
        }

        /// Returns if the architecture is a Parallax propeller architecture.
        pub inline fn isPropeller(arch: Arch) bool {
            return switch (arch) {
                .propeller1, .propeller2 => true,
                else => false,
            };
        }

        pub fn parseCpuModel(arch: Arch, cpu_name: []const u8) !*const Cpu.Model {
            for (arch.allCpuModels()) |cpu| {
                if (std.mem.eql(u8, cpu_name, cpu.name)) {
                    return cpu;
                }
            }
            return error.UnknownCpuModel;
        }

        pub fn endian(arch: Arch) std.builtin.Endian {
            return switch (arch) {
                .avr,
                .arm,
                .aarch64,
                .amdgcn,
                .bpfel,
                .csky,
                .xtensa,
                .hexagon,
                .kalimba,
                .mipsel,
                .mips64el,
                .msp430,
                .nvptx,
                .nvptx64,
                .powerpcle,
                .powerpc64le,
                .riscv32,
                .riscv64,
                .x86,
                .x86_64,
                .wasm32,
                .wasm64,
                .xcore,
                .thumb,
                .ve,
                .spu_2,
                // GPU bitness is opaque. For now, assume little endian.
                .spirv,
                .spirv32,
                .spirv64,
                .loongarch32,
                .loongarch64,
                .arc,
                .propeller1,
                .propeller2,
                => .little,

                .armeb,
                .aarch64_be,
                .bpfeb,
                .m68k,
                .mips,
                .mips64,
                .powerpc,
                .powerpc64,
                .thumbeb,
                .sparc,
                .sparc64,
                .lanai,
                .s390x,
                => .big,
            };
        }

        /// Returns whether this architecture supports the address space
        pub fn supportsAddressSpace(arch: Arch, address_space: std.builtin.AddressSpace) bool {
            const is_nvptx = arch.isNvptx();
            const is_spirv = arch.isSpirV();
            const is_gpu = is_nvptx or is_spirv or arch == .amdgcn;
            return switch (address_space) {
                .generic => true,
                .fs, .gs, .ss => arch == .x86_64 or arch == .x86,
                .global, .constant, .local, .shared => is_gpu,
                .param => is_nvptx,
                .input, .output, .uniform, .push_constant, .storage_buffer => is_spirv,
                // TODO this should also check how many flash banks the cpu has
                .flash, .flash1, .flash2, .flash3, .flash4, .flash5 => arch == .avr,

                // Propeller address spaces:
                .cog, .hub => arch.isPropeller(),
                .lut => (arch == .propeller2),
            };
        }

        /// Returns a name that matches the lib/std/target/* source file name.
        pub fn genericName(arch: Arch) [:0]const u8 {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => "arm",
                .aarch64, .aarch64_be => "aarch64",
                .bpfel, .bpfeb => "bpf",
                .loongarch32, .loongarch64 => "loongarch",
                .mips, .mipsel, .mips64, .mips64el => "mips",
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => "powerpc",
                .riscv32, .riscv64 => "riscv",
                .sparc, .sparc64 => "sparc",
                .s390x => "s390x",
                .x86, .x86_64 => "x86",
                .nvptx, .nvptx64 => "nvptx",
                .wasm32, .wasm64 => "wasm",
                .spirv, .spirv32, .spirv64 => "spirv",
                .propeller1, .propeller2 => "propeller",
                else => @tagName(arch),
            };
        }

        /// All CPU features Zig is aware of, sorted lexicographically by name.
        pub fn allFeaturesList(arch: Arch) []const Cpu.Feature {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.all_features,
                .aarch64, .aarch64_be => &aarch64.all_features,
                .arc => &arc.all_features,
                .avr => &avr.all_features,
                .bpfel, .bpfeb => &bpf.all_features,
                .csky => &csky.all_features,
                .hexagon => &hexagon.all_features,
                .lanai => &lanai.all_features,
                .loongarch32, .loongarch64 => &loongarch.all_features,
                .m68k => &m68k.all_features,
                .mips, .mipsel, .mips64, .mips64el => &mips.all_features,
                .msp430 => &msp430.all_features,
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => &powerpc.all_features,
                .amdgcn => &amdgcn.all_features,
                .riscv32, .riscv64 => &riscv.all_features,
                .sparc, .sparc64 => &sparc.all_features,
                .spirv, .spirv32, .spirv64 => &spirv.all_features,
                .s390x => &s390x.all_features,
                .x86, .x86_64 => &x86.all_features,
                .xcore => &xcore.all_features,
                .xtensa => &xtensa.all_features,
                .nvptx, .nvptx64 => &nvptx.all_features,
                .ve => &ve.all_features,
                .wasm32, .wasm64 => &wasm.all_features,

                else => &[0]Cpu.Feature{},
            };
        }

        /// All processors Zig is aware of, sorted lexicographically by name.
        pub fn allCpuModels(arch: Arch) []const *const Cpu.Model {
            return switch (arch) {
                .arc => comptime allCpusFromDecls(arc.cpu),
                .arm, .armeb, .thumb, .thumbeb => comptime allCpusFromDecls(arm.cpu),
                .aarch64, .aarch64_be => comptime allCpusFromDecls(aarch64.cpu),
                .avr => comptime allCpusFromDecls(avr.cpu),
                .bpfel, .bpfeb => comptime allCpusFromDecls(bpf.cpu),
                .csky => comptime allCpusFromDecls(csky.cpu),
                .hexagon => comptime allCpusFromDecls(hexagon.cpu),
                .lanai => comptime allCpusFromDecls(lanai.cpu),
                .loongarch32, .loongarch64 => comptime allCpusFromDecls(loongarch.cpu),
                .m68k => comptime allCpusFromDecls(m68k.cpu),
                .mips, .mipsel, .mips64, .mips64el => comptime allCpusFromDecls(mips.cpu),
                .msp430 => comptime allCpusFromDecls(msp430.cpu),
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => comptime allCpusFromDecls(powerpc.cpu),
                .amdgcn => comptime allCpusFromDecls(amdgcn.cpu),
                .riscv32, .riscv64 => comptime allCpusFromDecls(riscv.cpu),
                .sparc, .sparc64 => comptime allCpusFromDecls(sparc.cpu),
                .spirv, .spirv32, .spirv64 => comptime allCpusFromDecls(spirv.cpu),
                .s390x => comptime allCpusFromDecls(s390x.cpu),
                .x86, .x86_64 => comptime allCpusFromDecls(x86.cpu),
                .xcore => comptime allCpusFromDecls(xcore.cpu),
                .xtensa => comptime allCpusFromDecls(xtensa.cpu),
                .nvptx, .nvptx64 => comptime allCpusFromDecls(nvptx.cpu),
                .ve => comptime allCpusFromDecls(ve.cpu),
                .wasm32, .wasm64 => comptime allCpusFromDecls(wasm.cpu),

                else => &[0]*const Model{},
            };
        }

        fn allCpusFromDecls(comptime cpus: type) []const *const Cpu.Model {
            @setEvalBranchQuota(2000);
            const decls = @typeInfo(cpus).@"struct".decls;
            var array: [decls.len]*const Cpu.Model = undefined;
            for (decls, 0..) |decl, i| {
                array[i] = &@field(cpus, decl.name);
            }
            const finalized = array;
            return &finalized;
        }

        /// 0c spim    little-endian MIPS 3000 family
        /// 1c 68000   Motorola MC68000
        /// 2c 68020   Motorola MC68020
        /// 5c arm     little-endian ARM
        /// 6c amd64   AMD64 and compatibles (e.g., Intel EM64T)
        /// 7c arm64   ARM64 (ARMv8)
        /// 8c 386     Intel x86, i486, Pentium, etc.
        /// kc sparc   Sun SPARC
        /// qc power   Power PC
        /// vc mips    big-endian MIPS 3000 family
        pub fn plan9Ext(arch: Cpu.Arch) [:0]const u8 {
            return switch (arch) {
                .arm => ".5",
                .x86_64 => ".6",
                .aarch64 => ".7",
                .x86 => ".8",
                .sparc => ".k",
                .powerpc, .powerpcle => ".q",
                .mips, .mipsel => ".v",
                // ISAs without designated characters get 'X' for lack of a better option.
                else => ".X",
            };
        }

        /// Returns the array of `Arch` to which a specific `std.builtin.CallingConvention` applies.
        /// Asserts that `cc` is not `.auto`, `.@"async"`, `.naked`, or `.@"inline"`.
        pub fn fromCallingConvention(cc: std.builtin.CallingConvention.Tag) []const Arch {
            return switch (cc) {
                .auto,
                .@"async",
                .naked,
                .@"inline",
                => unreachable,

                .x86_64_sysv,
                .x86_64_win,
                .x86_64_regcall_v3_sysv,
                .x86_64_regcall_v4_win,
                .x86_64_vectorcall,
                .x86_64_interrupt,
                => &.{.x86_64},

                .x86_sysv,
                .x86_win,
                .x86_stdcall,
                .x86_fastcall,
                .x86_thiscall,
                .x86_thiscall_mingw,
                .x86_regcall_v3,
                .x86_regcall_v4_win,
                .x86_vectorcall,
                .x86_interrupt,
                => &.{.x86},

                .aarch64_aapcs,
                .aarch64_aapcs_darwin,
                .aarch64_aapcs_win,
                .aarch64_vfabi,
                .aarch64_vfabi_sve,
                => &.{ .aarch64, .aarch64_be },

                .arm_apcs,
                .arm_aapcs,
                .arm_aapcs_vfp,
                .arm_aapcs16_vfp,
                .arm_interrupt,
                => &.{ .arm, .armeb, .thumb, .thumbeb },

                .mips64_n64,
                .mips64_n32,
                .mips64_interrupt,
                => &.{ .mips64, .mips64el },

                .mips_o32,
                .mips_interrupt,
                => &.{ .mips, .mipsel },

                .riscv64_lp64,
                .riscv64_lp64_v,
                .riscv64_interrupt,
                => &.{.riscv64},

                .riscv32_ilp32,
                .riscv32_ilp32_v,
                .riscv32_interrupt,
                => &.{.riscv32},

                .sparc64_sysv,
                => &.{.sparc64},

                .sparc_sysv,
                => &.{.sparc},

                .powerpc64_elf,
                .powerpc64_elf_altivec,
                .powerpc64_elf_v2,
                => &.{ .powerpc64, .powerpc64le },

                .powerpc_sysv,
                .powerpc_sysv_altivec,
                .powerpc_aix,
                .powerpc_aix_altivec,
                => &.{ .powerpc, .powerpcle },

                .wasm_watc,
                => &.{ .wasm64, .wasm32 },

                .arc_sysv,
                => &.{.arc},

                .avr_gnu,
                .avr_builtin,
                .avr_signal,
                .avr_interrupt,
                => &.{.avr},

                .bpf_std,
                => &.{ .bpfel, .bpfeb },

                .csky_sysv,
                .csky_interrupt,
                => &.{.csky},

                .hexagon_sysv,
                .hexagon_sysv_hvx,
                => &.{.hexagon},

                .lanai_sysv,
                => &.{.lanai},

                .loongarch64_lp64,
                => &.{.loongarch64},

                .loongarch32_ilp32,
                => &.{.loongarch32},

                .m68k_sysv,
                .m68k_gnu,
                .m68k_rtd,
                .m68k_interrupt,
                => &.{.m68k},

                .msp430_eabi,
                => &.{.msp430},

                .propeller1_sysv,
                => &.{.propeller1},

                .propeller2_sysv,
                => &.{.propeller2},

                .s390x_sysv,
                .s390x_sysv_vx,
                => &.{.s390x},

                .ve_sysv,
                => &.{.ve},

                .xcore_xs1,
                .xcore_xs2,
                => &.{.xcore},

                .xtensa_call0,
                .xtensa_windowed,
                => &.{.xtensa},

                .amdgcn_device,
                .amdgcn_kernel,
                .amdgcn_cs,
                => &.{.amdgcn},

                .nvptx_device,
                .nvptx_kernel,
                => &.{ .nvptx, .nvptx64 },

                .spirv_device,
                .spirv_kernel,
                .spirv_fragment,
                .spirv_vertex,
                => &.{ .spirv, .spirv32, .spirv64 },
            };
        }
    };

    pub const Model = struct {
        name: []const u8,
        llvm_name: ?[:0]const u8,
        features: Feature.Set,

        pub fn toCpu(model: *const Model, arch: Arch) Cpu {
            var features = model.features;
            features.populateDependencies(arch.allFeaturesList());
            return .{
                .arch = arch,
                .model = model,
                .features = features,
            };
        }

        /// Returns the most bare-bones CPU model that is valid for `arch`. Note that this function
        /// can return CPU models that are understood by LLVM, but *not* understood by Clang. If
        /// Clang compatibility is important, consider using `baseline` instead.
        pub fn generic(arch: Arch) *const Model {
            const S = struct {
                const generic_model = Model{
                    .name = "generic",
                    .llvm_name = null,
                    .features = Cpu.Feature.Set.empty,
                };
            };
            return switch (arch) {
                .amdgcn => &amdgcn.cpu.gfx600,
                .arc => &arc.cpu.generic,
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.generic,
                .aarch64, .aarch64_be => &aarch64.cpu.generic,
                .avr => &avr.cpu.avr1,
                .bpfel, .bpfeb => &bpf.cpu.generic,
                .csky => &csky.cpu.generic,
                .hexagon => &hexagon.cpu.generic,
                .lanai => &lanai.cpu.generic,
                .loongarch32 => &loongarch.cpu.generic_la32,
                .loongarch64 => &loongarch.cpu.generic_la64,
                .m68k => &m68k.cpu.generic,
                .mips, .mipsel => &mips.cpu.mips32,
                .mips64, .mips64el => &mips.cpu.mips64,
                .msp430 => &msp430.cpu.generic,
                .powerpc, .powerpcle => &powerpc.cpu.ppc,
                .powerpc64, .powerpc64le => &powerpc.cpu.ppc64,
                .propeller1 => &propeller.cpu.generic,
                .propeller2 => &propeller.cpu.generic,
                .riscv32 => &riscv.cpu.generic_rv32,
                .riscv64 => &riscv.cpu.generic_rv64,
                .spirv, .spirv32, .spirv64 => &spirv.cpu.generic,
                .sparc => &sparc.cpu.generic,
                .sparc64 => &sparc.cpu.v9, // 64-bit SPARC needs v9 as the baseline
                .s390x => &s390x.cpu.generic,
                .x86 => &x86.cpu.i386,
                .x86_64 => &x86.cpu.x86_64,
                .nvptx, .nvptx64 => &nvptx.cpu.sm_20,
                .ve => &ve.cpu.generic,
                .wasm32, .wasm64 => &wasm.cpu.mvp,
                .xcore => &xcore.cpu.generic,
                .xtensa => &xtensa.cpu.generic,

                .kalimba,
                .spu_2,
                => &S.generic_model,
            };
        }

        /// Returns a conservative CPU model for `arch` that is expected to be compatible with the
        /// vast majority of hardware available. This function is guaranteed to return CPU models
        /// that are understood by both LLVM and Clang, unlike `generic`.
        ///
        /// For certain `os` values, this function will additionally bump the baseline higher than
        /// the baseline would be for `arch` in isolation; for example, for `aarch64-macos`, the
        /// baseline is considered to be `apple_m1`. To avoid this behavior entirely, pass
        /// `Os.Tag.freestanding`.
        pub fn baseline(arch: Arch, os: Os) *const Model {
            return switch (arch) {
                .amdgcn => &amdgcn.cpu.gfx906,
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.baseline,
                .aarch64 => switch (os.tag) {
                    .driverkit, .macos => &aarch64.cpu.apple_m1,
                    .ios, .tvos => &aarch64.cpu.apple_a7,
                    .visionos => &aarch64.cpu.apple_m2,
                    .watchos => &aarch64.cpu.apple_s4,
                    else => generic(arch),
                },
                .avr => &avr.cpu.avr2,
                .bpfel, .bpfeb => &bpf.cpu.v1,
                .csky => &csky.cpu.ck810, // gcc/clang do not have a generic csky model.
                .hexagon => &hexagon.cpu.hexagonv60, // gcc/clang do not have a generic hexagon model.
                .lanai => &lanai.cpu.v11, // clang does not have a generic lanai model.
                .loongarch64 => &loongarch.cpu.loongarch64,
                .m68k => &m68k.cpu.M68000,
                .mips, .mipsel => &mips.cpu.mips32r2,
                .mips64, .mips64el => &mips.cpu.mips64r2,
                .msp430 => &msp430.cpu.msp430,
                .nvptx, .nvptx64 => &nvptx.cpu.sm_52,
                .powerpc64le => &powerpc.cpu.ppc64le,
                .riscv32 => &riscv.cpu.baseline_rv32,
                .riscv64 => &riscv.cpu.baseline_rv64,
                .s390x => &s390x.cpu.arch8, // gcc/clang do not have a generic s390x model.
                .sparc => &sparc.cpu.v9, // glibc does not work with 'plain' v8.
                .x86 => &x86.cpu.pentium4,
                .x86_64 => switch (os.tag) {
                    .driverkit => &x86.cpu.nehalem,
                    .ios, .macos, .tvos, .visionos, .watchos => &x86.cpu.core2,
                    .ps4 => &x86.cpu.btver2,
                    .ps5 => &x86.cpu.znver2,
                    else => generic(arch),
                },
                .xcore => &xcore.cpu.xs1b_generic,
                .wasm32, .wasm64 => &wasm.cpu.lime1,

                else => generic(arch),
            };
        }
    };

    /// The "default" set of CPU features for cross-compiling. A conservative set
    /// of features that is expected to be supported on most available hardware.
    pub fn baseline(arch: Arch, os: Os) Cpu {
        return Model.baseline(arch, os).toCpu(arch);
    }
};

pub fn zigTriple(target: Target, allocator: Allocator) Allocator.Error![]u8 {
    return Query.fromTarget(target).zigTriple(allocator);
}

pub fn hurdTupleSimple(allocator: Allocator, arch: Cpu.Arch, abi: Abi) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}-{s}", .{ @tagName(arch), @tagName(abi) });
}

pub fn hurdTuple(target: Target, allocator: Allocator) ![]u8 {
    return hurdTupleSimple(allocator, target.cpu.arch, target.abi);
}

pub fn linuxTripleSimple(allocator: Allocator, arch: Cpu.Arch, os_tag: Os.Tag, abi: Abi) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ @tagName(arch), @tagName(os_tag), @tagName(abi) });
}

pub fn linuxTriple(target: Target, allocator: Allocator) ![]u8 {
    return linuxTripleSimple(allocator, target.cpu.arch, target.os.tag, target.abi);
}

pub fn exeFileExt(target: Target) [:0]const u8 {
    return target.os.tag.exeFileExt(target.cpu.arch);
}

pub fn staticLibSuffix(target: Target) [:0]const u8 {
    return target.os.tag.staticLibSuffix(target.abi);
}

pub fn dynamicLibSuffix(target: Target) [:0]const u8 {
    return target.os.tag.dynamicLibSuffix();
}

pub fn libPrefix(target: Target) [:0]const u8 {
    return target.os.tag.libPrefix(target.abi);
}

pub inline fn isMinGW(target: Target) bool {
    return target.os.tag == .windows and target.isGnu();
}

pub inline fn isGnu(target: Target) bool {
    return target.abi.isGnu();
}

pub inline fn isMusl(target: Target) bool {
    return target.abi.isMusl();
}

pub inline fn isAndroid(target: Target) bool {
    return target.abi.isAndroid();
}

pub inline fn isWasm(target: Target) bool {
    return target.cpu.arch.isWasm();
}

pub inline fn isDarwin(target: Target) bool {
    return target.os.tag.isDarwin();
}

pub inline fn isBSD(target: Target) bool {
    return target.os.tag.isBSD();
}

pub inline fn isGnuLibC(target: Target) bool {
    return target.os.tag.isGnuLibC(target.abi);
}

pub inline fn isSpirV(target: Target) bool {
    return target.cpu.arch.isSpirV();
}

pub const FloatAbi = enum {
    hard,
    soft,
};

pub inline fn floatAbi(target: Target) FloatAbi {
    return target.abi.floatAbi();
}

pub const DynamicLinker = struct {
    /// Contains the memory used to store the dynamic linker path. This field
    /// should not be used directly. See `get` and `set`. This field exists so
    /// that this API requires no allocator.
    buffer: [255]u8,

    /// Used to construct the dynamic linker path. This field should not be used
    /// directly. See `get` and `set`.
    len: u8,

    pub const none: DynamicLinker = .{ .buffer = undefined, .len = 0 };

    /// Asserts that the length is less than or equal to 255 bytes.
    pub fn init(maybe_path: ?[]const u8) DynamicLinker {
        var dl: DynamicLinker = undefined;
        dl.set(maybe_path);
        return dl;
    }

    pub fn initFmt(comptime fmt_str: []const u8, args: anytype) !DynamicLinker {
        var dl: DynamicLinker = undefined;
        try dl.setFmt(fmt_str, args);
        return dl;
    }

    /// The returned memory has the same lifetime as the `DynamicLinker`.
    pub fn get(dl: *const DynamicLinker) ?[]const u8 {
        return if (dl.len > 0) dl.buffer[0..dl.len] else null;
    }

    /// Asserts that the length is less than or equal to 255 bytes.
    pub fn set(dl: *DynamicLinker, maybe_path: ?[]const u8) void {
        const path = maybe_path orelse "";
        @memcpy(dl.buffer[0..path.len], path);
        dl.len = @intCast(path.len);
    }

    /// Asserts that the length is less than or equal to 255 bytes.
    pub fn setFmt(dl: *DynamicLinker, comptime fmt_str: []const u8, args: anytype) !void {
        dl.len = @intCast((try std.fmt.bufPrint(&dl.buffer, fmt_str, args)).len);
    }

    pub fn eql(lhs: DynamicLinker, rhs: DynamicLinker) bool {
        return std.mem.eql(u8, lhs.buffer[0..lhs.len], rhs.buffer[0..rhs.len]);
    }

    pub const Kind = enum {
        /// No dynamic linker.
        none,
        /// Dynamic linker path is determined by the arch/OS components.
        arch_os,
        /// Dynamic linker path is determined by the arch/OS/ABI components.
        arch_os_abi,
    };

    pub fn kind(os: Os.Tag) Kind {
        return switch (os) {
            .fuchsia,

            .haiku,
            .serenity,

            .dragonfly,
            .freebsd,
            .netbsd,
            .openbsd,

            .driverkit,
            .ios,
            .macos,
            .tvos,
            .visionos,
            .watchos,

            .illumos,
            .solaris,
            => .arch_os,
            .hurd,
            .linux,
            => .arch_os_abi,
            .freestanding,
            .other,

            .contiki,
            .elfiamcu,
            .hermit,

            .aix,
            .plan9,
            .rtems,
            .zos,

            .uefi,
            .windows,

            .emscripten,
            .wasi,

            .amdhsa,
            .amdpal,
            .cuda,
            .mesa3d,
            .nvcl,
            .opencl,
            .opengl,
            .vulkan,

            .ps3,
            .ps4,
            .ps5,
            => .none,
        };
    }

    /// The strictness of this function depends on the value of `kind(os.tag)`:
    ///
    /// * `.none`: Ignores all arguments and just returns `none`.
    /// * `.arch_os`: Ignores `abi` and returns the dynamic linker matching `cpu` and `os`.
    /// * `.arch_os_abi`: Returns the dynamic linker matching `cpu`, `os`, and `abi`.
    ///
    /// In the case of `.arch_os` in particular, callers should be aware that a valid dynamic linker
    /// being returned only means that the `cpu` + `os` combination represents a platform that
    /// actually exists and which has an established dynamic linker path that does not change with
    /// the ABI; it does not necessarily mean that `abi` makes any sense at all for that platform.
    /// The responsibility for determining whether `abi` is valid in this case rests with the
    /// caller. `Abi.default()` can be used to pick a best-effort default ABI for such platforms.
    pub fn standard(cpu: Cpu, os: Os, abi: Abi) DynamicLinker {
        return switch (os.tag) {
            .fuchsia => switch (cpu.arch) {
                .aarch64,
                .riscv64,
                .x86_64,
                => init("ld.so.1"), // Fuchsia is unusual in that `DT_INTERP` is just a basename.
                else => none,
            },

            .haiku => switch (cpu.arch) {
                .arm,
                .thumb,
                .aarch64,
                .m68k,
                .powerpc,
                .riscv64,
                .sparc64,
                .x86,
                .x86_64,
                => init("/system/runtime_loader"),
                else => none,
            },

            .hurd => switch (cpu.arch) {
                .aarch64,
                .aarch64_be,
                => |arch| initFmt("/lib/ld-{s}{s}.so.1", .{
                    @tagName(arch),
                    switch (abi) {
                        .gnu => "",
                        .gnuilp32 => "_ilp32",
                        else => return none,
                    },
                }),

                .x86 => if (abi == .gnu) init("/lib/ld.so.1") else none,
                .x86_64 => initFmt("/lib/ld-{s}.so.1", .{switch (abi) {
                    .gnu => "x86-64",
                    .gnux32 => "x32",
                    else => return none,
                }}),

                else => none,
            },

            .linux => if (abi.isAndroid())
                switch (cpu.arch) {
                    .arm,
                    .thumb,
                    => if (abi == .androideabi) init("/system/bin/linker") else none,

                    .aarch64,
                    .riscv64,
                    .x86,
                    .x86_64,
                    => if (abi == .android) initFmt("/system/bin/linker{s}", .{
                        if (ptrBitWidth_cpu_abi(cpu, abi) == 64) "64" else "",
                    }) else none,

                    else => none,
                }
            else if (abi.isMusl())
                switch (cpu.arch) {
                    .arm,
                    .armeb,
                    .thumb,
                    .thumbeb,
                    => |arch| initFmt("/lib/ld-musl-arm{s}{s}.so.1", .{
                        if (arch == .armeb or arch == .thumbeb) "eb" else "",
                        switch (abi) {
                            .musleabi => "",
                            .musleabihf => "hf",
                            else => return none,
                        },
                    }),

                    .aarch64,
                    .aarch64_be,
                    .loongarch64, // TODO: `-sp` and `-sf` ABI support in LLVM 20.
                    .m68k,
                    .powerpc64,
                    .powerpc64le,
                    .s390x,
                    => |arch| if (abi == .musl) initFmt("/lib/ld-musl-{s}.so.1", .{@tagName(arch)}) else none,

                    .mips,
                    .mipsel,
                    => |arch| initFmt("/lib/ld-musl-mips{s}{s}{s}.so.1", .{
                        if (mips.featureSetHas(cpu.features, .mips32r6)) "r6" else "",
                        if (arch == .mipsel) "el" else "",
                        switch (abi) {
                            .musleabi => "-sf",
                            .musleabihf => "",
                            else => return none,
                        },
                    }),

                    .mips64,
                    .mips64el,
                    => |arch| initFmt("/lib/ld-musl-mips{s}{s}{s}.so.1", .{
                        switch (abi) {
                            .muslabi64 => "64",
                            .muslabin32 => "n32",
                            else => return none,
                        },
                        if (mips.featureSetHas(cpu.features, .mips64r6)) "r6" else "",
                        if (arch == .mips64el) "el" else "",
                    }),

                    .powerpc => initFmt("/lib/ld-musl-powerpc{s}.so.1", .{switch (abi) {
                        .musleabi => "-sf",
                        .musleabihf => "",
                        else => return none,
                    }}),

                    .riscv32,
                    .riscv64,
                    => |arch| if (abi == .musl) initFmt("/lib/ld-musl-{s}{s}.so.1", .{
                        @tagName(arch),
                        if (riscv.featureSetHas(cpu.features, .d))
                            ""
                        else if (riscv.featureSetHas(cpu.features, .f))
                            "-sp"
                        else
                            "-sf",
                    }) else none,

                    .x86 => if (abi == .musl) init("/lib/ld-musl-i386.so.1") else none,
                    .x86_64 => initFmt("/lib/ld-musl-{s}.so.1", .{switch (abi) {
                        .musl => "x86_64",
                        .muslx32 => "x32",
                        else => return none,
                    }}),

                    else => none,
                }
            else if (abi.isGnu())
                switch (cpu.arch) {
                    // TODO: `eb` architecture support.
                    // TODO: `700` ABI support.
                    .arc => if (abi == .gnu) init("/lib/ld-linux-arc.so.2") else none,

                    .arm,
                    .armeb,
                    .thumb,
                    .thumbeb,
                    => initFmt("/lib/ld-linux{s}.so.3", .{switch (abi) {
                        .gnueabi => "",
                        .gnueabihf => "-armhf",
                        else => return none,
                    }}),

                    .aarch64,
                    .aarch64_be,
                    => |arch| initFmt("/lib/ld-linux-{s}{s}.so.1", .{
                        @tagName(arch),
                        switch (abi) {
                            .gnu => "",
                            .gnuilp32 => "_ilp32",
                            else => return none,
                        },
                    }),

                    // TODO: `-be` architecture support.
                    .csky => initFmt("/lib/ld-linux-cskyv2{s}.so.1", .{switch (abi) {
                        .gnueabi => "",
                        .gnueabihf => "-hf",
                        else => return none,
                    }}),

                    .loongarch64 => initFmt("/lib64/ld-linux-loongarch-{s}.so.1", .{switch (abi) {
                        .gnu => "lp64d",
                        .gnuf32 => "lp64f",
                        .gnusf => "lp64s",
                        else => return none,
                    }}),

                    .m68k => if (abi == .gnu) init("/lib/ld.so.1") else none,

                    .mips,
                    .mipsel,
                    => switch (abi) {
                        .gnueabi,
                        .gnueabihf,
                        => initFmt("/lib/ld{s}.so.1", .{
                            if (mips.featureSetHas(cpu.features, .nan2008)) "-linux-mipsn8" else "",
                        }),
                        else => none,
                    },

                    .mips64,
                    .mips64el,
                    => initFmt("/lib{s}/ld{s}.so.1", .{
                        switch (abi) {
                            .gnuabi64 => "64",
                            .gnuabin32 => "32",
                            else => return none,
                        },
                        if (mips.featureSetHas(cpu.features, .nan2008)) "-linux-mipsn8" else "",
                    }),

                    .powerpc => switch (abi) {
                        .gnueabi,
                        .gnueabihf,
                        => init("/lib/ld.so.1"),
                        else => none,
                    },
                    // TODO: ELFv2 ABI (`/lib64/ld64.so.2`) opt-in support.
                    .powerpc64 => if (abi == .gnu) init("/lib64/ld64.so.1") else none,
                    .powerpc64le => if (abi == .gnu) init("/lib64/ld64.so.2") else none,

                    .riscv32,
                    .riscv64,
                    => |arch| if (abi == .gnu) initFmt("/lib/ld-linux-{s}{s}.so.1", .{
                        switch (arch) {
                            .riscv32 => "riscv32-ilp32",
                            .riscv64 => "riscv64-lp64",
                            else => unreachable,
                        },
                        if (riscv.featureSetHas(cpu.features, .d))
                            "d"
                        else if (riscv.featureSetHas(cpu.features, .f))
                            "f"
                        else
                            "",
                    }) else none,

                    .s390x => if (abi == .gnu) init("/lib/ld64.so.1") else none,

                    .sparc => if (abi == .gnu) init("/lib/ld-linux.so.2") else none,
                    .sparc64 => if (abi == .gnu) init("/lib64/ld-linux.so.2") else none,

                    .x86 => if (abi == .gnu) init("/lib/ld-linux.so.2") else none,
                    .x86_64 => switch (abi) {
                        .gnu => init("/lib64/ld-linux-x86-64.so.2"),
                        .gnux32 => init("/libx32/ld-linux-x32.so.2"),
                        else => none,
                    },

                    .xtensa => if (abi == .gnu) init("/lib/ld.so.1") else none,

                    else => none,
                }
            else
                none, // Not a known Linux libc.

            .serenity => switch (cpu.arch) {
                .aarch64,
                .riscv64,
                .x86_64,
                => init("/usr/lib/Loader.so"),
                else => none,
            },

            .dragonfly => if (cpu.arch == .x86_64) initFmt("{s}/libexec/ld-elf.so.2", .{
                if (os.version_range.semver.isAtLeast(.{ .major = 3, .minor = 8, .patch = 0 }) orelse false)
                    ""
                else
                    "/usr",
            }) else none,

            .freebsd => switch (cpu.arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .aarch64,
                .mips,
                .mipsel,
                .mips64,
                .mips64el,
                .powerpc,
                .powerpc64,
                .powerpc64le,
                .riscv64,
                .sparc64,
                .x86,
                .x86_64,
                => initFmt("{s}/libexec/ld-elf.so.1", .{
                    if (os.version_range.semver.isAtLeast(.{ .major = 6, .minor = 0, .patch = 0 }) orelse false)
                        ""
                    else
                        "/usr",
                }),
                else => none,
            },

            .netbsd => switch (cpu.arch) {
                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                .aarch64,
                .aarch64_be,
                .m68k,
                .mips,
                .mipsel,
                .mips64,
                .mips64el,
                .powerpc,
                .riscv64,
                .sparc,
                .sparc64,
                .x86,
                .x86_64,
                => init("/libexec/ld.elf_so"),
                else => none,
            },

            .openbsd => switch (cpu.arch) {
                .arm,
                .thumb,
                .aarch64,
                .mips64,
                .mips64el,
                .powerpc,
                .powerpc64,
                .riscv64,
                .sparc64,
                .x86,
                .x86_64,
                => init("/usr/libexec/ld.so"),
                else => none,
            },

            .driverkit,
            .ios,
            .macos,
            .tvos,
            .visionos,
            .watchos,
            => switch (cpu.arch) {
                .aarch64,
                .x86_64,
                => init("/usr/lib/dyld"),
                else => none,
            },

            .illumos,
            .solaris,
            => switch (cpu.arch) {
                .sparc,
                .sparc64,
                .x86,
                .x86_64,
                => initFmt("/lib/{s}ld.so.1", .{if (ptrBitWidth_cpu_abi(cpu, .none) == 64) "64/" else ""}),
                else => none,
            },

            // Operating systems in this list have been verified as not having a standard
            // dynamic linker path.
            .freestanding,
            .other,

            .contiki,
            .elfiamcu,
            .hermit,

            .aix,
            .plan9,
            .rtems,
            .zos,

            .uefi,
            .windows,

            .emscripten,
            .wasi,

            .amdhsa,
            .amdpal,
            .cuda,
            .mesa3d,
            .nvcl,
            .opencl,
            .opengl,
            .vulkan,
            => none,

            // TODO go over each item in this list and either move it to the above list, or
            // implement the standard dynamic linker path code for it.
            .ps3,
            .ps4,
            .ps5,
            => none,
        } catch unreachable;
    }
};

pub fn standardDynamicLinkerPath(target: Target) DynamicLinker {
    return DynamicLinker.standard(target.cpu, target.os, target.abi);
}

pub fn ptrBitWidth_cpu_abi(cpu: Cpu, abi: Abi) u16 {
    switch (abi) {
        .gnux32, .muslx32, .gnuabin32, .muslabin32, .gnuilp32, .ilp32 => return 32,
        .gnuabi64, .muslabi64 => return 64,
        else => {},
    }
    return switch (cpu.arch) {
        .avr,
        .msp430,
        .spu_2,
        => 16,

        .arc,
        .arm,
        .armeb,
        .csky,
        .hexagon,
        .m68k,
        .mips,
        .mipsel,
        .powerpc,
        .powerpcle,
        .riscv32,
        .thumb,
        .thumbeb,
        .x86,
        .xcore,
        .nvptx,
        .kalimba,
        .lanai,
        .wasm32,
        .sparc,
        .spirv32,
        .loongarch32,
        .xtensa,
        .propeller1,
        .propeller2,
        => 32,

        .aarch64,
        .aarch64_be,
        .mips64,
        .mips64el,
        .powerpc64,
        .powerpc64le,
        .riscv64,
        .x86_64,
        .nvptx64,
        .wasm64,
        .amdgcn,
        .bpfel,
        .bpfeb,
        .sparc64,
        .s390x,
        .ve,
        .spirv,
        .spirv64,
        .loongarch64,
        => 64,
    };
}

pub fn ptrBitWidth(target: Target) u16 {
    return ptrBitWidth_cpu_abi(target.cpu, target.abi);
}

pub fn stackAlignment(target: Target) u16 {
    // Overrides for when the stack alignment is not equal to the pointer width.
    switch (target.cpu.arch) {
        .m68k,
        => return 2,
        .amdgcn,
        => return 4,
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .lanai,
        .mips,
        .mipsel,
        .sparc,
        => return 8,
        .aarch64,
        .aarch64_be,
        .bpfeb,
        .bpfel,
        .loongarch32,
        .loongarch64,
        .mips64,
        .mips64el,
        .sparc64,
        .ve,
        .wasm32,
        .wasm64,
        => return 16,
        // Some of the following prongs should really be testing the ABI, but our current `Abi` enum
        // can't handle that level of nuance yet.
        .powerpc64,
        .powerpc64le,
        => if (target.os.tag == .linux or target.os.tag == .aix) return 16,
        .riscv32,
        .riscv64,
        => if (!Target.riscv.featureSetHas(target.cpu.features, .e)) return 16,
        .x86 => if (target.os.tag != .windows and target.os.tag != .uefi) return 16,
        .x86_64 => return if (target.os.tag == .elfiamcu) 4 else 16,
        else => {},
    }

    return @divExact(target.ptrBitWidth(), 8);
}

/// Default signedness of `char` for the native C compiler for this target
/// Note that char signedness is implementation-defined and many compilers provide
/// an option to override the default signedness e.g. GCC's -funsigned-char / -fsigned-char
pub fn charSignedness(target: Target) std.builtin.Signedness {
    if (target.isDarwin() or target.os.tag == .windows or target.os.tag == .uefi) return .signed;

    return switch (target.cpu.arch) {
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        .aarch64,
        .aarch64_be,
        .arc,
        .csky,
        .hexagon,
        .msp430,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .s390x,
        .riscv32,
        .riscv64,
        .xcore,
        .xtensa,
        => .unsigned,
        else => .signed,
    };
}

pub const CType = enum {
    char,
    short,
    ushort,
    int,
    uint,
    long,
    ulong,
    longlong,
    ulonglong,
    float,
    double,
    longdouble,
};

pub fn cTypeByteSize(t: Target, c_type: CType) u16 {
    return switch (c_type) {
        .char,
        .short,
        .ushort,
        .int,
        .uint,
        .long,
        .ulong,
        .longlong,
        .ulonglong,
        .float,
        .double,
        => @divExact(cTypeBitSize(t, c_type), 8),

        .longdouble => switch (cTypeBitSize(t, c_type)) {
            16 => 2,
            32 => 4,
            64 => 8,
            80 => @intCast(std.mem.alignForward(usize, 10, cTypeAlignment(t, .longdouble))),
            128 => 16,
            else => unreachable,
        },
    };
}

pub fn cTypeBitSize(target: Target, c_type: CType) u16 {
    switch (target.os.tag) {
        .freestanding, .other => switch (target.cpu.arch) {
            .msp430 => switch (c_type) {
                .char => return 8,
                .short, .ushort, .int, .uint => return 16,
                .float, .long, .ulong => return 32,
                .longlong, .ulonglong, .double, .longdouble => return 64,
            },
            .avr => switch (c_type) {
                .char => return 8,
                .short, .ushort, .int, .uint => return 16,
                .long, .ulong, .float, .double, .longdouble => return 32,
                .longlong, .ulonglong => return 64,
            },
            .mips64, .mips64el => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => switch (target.abi) {
                    .gnuabin32, .muslabin32 => return 32,
                    else => return 64,
                },
                .longlong, .ulonglong, .double => return 64,
                .longdouble => return 128,
            },
            .x86_64 => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => switch (target.abi) {
                    .gnux32, .muslx32 => return 32,
                    else => return 64,
                },
                .longlong, .ulonglong, .double => return 64,
                .longdouble => return 80,
            },
            else => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => return target.ptrBitWidth(),
                .longlong, .ulonglong, .double => return 64,
                .longdouble => switch (target.cpu.arch) {
                    .x86 => switch (target.abi) {
                        .android => return 64,
                        else => return 80,
                    },

                    .powerpc,
                    .powerpcle,
                    .powerpc64,
                    .powerpc64le,
                    => switch (target.abi) {
                        .musl,
                        .muslabin32,
                        .muslabi64,
                        .musleabi,
                        .musleabihf,
                        .muslx32,
                        => return 64,
                        else => return 128,
                    },

                    .riscv32,
                    .riscv64,
                    .aarch64,
                    .aarch64_be,
                    .s390x,
                    .sparc64,
                    .wasm32,
                    .wasm64,
                    .loongarch32,
                    .loongarch64,
                    .ve,
                    => return 128,

                    else => return 64,
                },
            },
        },

        .elfiamcu,
        .fuchsia,
        .hermit,

        .aix,
        .haiku,
        .hurd,
        .linux,
        .plan9,
        .rtems,
        .serenity,
        .zos,

        .freebsd,
        .dragonfly,
        .netbsd,
        .openbsd,

        .illumos,
        .solaris,

        .wasi,
        .emscripten,
        => switch (target.cpu.arch) {
            .msp430 => switch (c_type) {
                .char => return 8,
                .short, .ushort, .int, .uint => return 16,
                .long, .ulong, .float => return 32,
                .longlong, .ulonglong, .double, .longdouble => return 64,
            },
            .avr => switch (c_type) {
                .char => return 8,
                .short, .ushort, .int, .uint => return 16,
                .long, .ulong, .float, .double, .longdouble => return 32,
                .longlong, .ulonglong => return 64,
            },
            .mips64, .mips64el => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => switch (target.abi) {
                    .gnuabin32, .muslabin32 => return 32,
                    else => return 64,
                },
                .longlong, .ulonglong, .double => return 64,
                .longdouble => if (target.os.tag == .freebsd) return 64 else return 128,
            },
            .x86_64 => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => switch (target.abi) {
                    .gnux32, .muslx32 => return 32,
                    else => return 64,
                },
                .longlong, .ulonglong, .double => return 64,
                .longdouble => return 80,
            },
            else => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => return target.ptrBitWidth(),
                .longlong, .ulonglong, .double => return 64,
                .longdouble => switch (target.cpu.arch) {
                    .x86 => switch (target.abi) {
                        .android => return 64,
                        else => switch (target.os.tag) {
                            .elfiamcu => return 64,
                            else => return 80,
                        },
                    },

                    .powerpc,
                    .powerpcle,
                    => switch (target.abi) {
                        .musl,
                        .muslabin32,
                        .muslabi64,
                        .musleabi,
                        .musleabihf,
                        .muslx32,
                        => return 64,
                        else => switch (target.os.tag) {
                            .aix, .freebsd, .netbsd, .openbsd => return 64,
                            else => return 128,
                        },
                    },

                    .powerpc64,
                    .powerpc64le,
                    => switch (target.abi) {
                        .musl,
                        .muslabin32,
                        .muslabi64,
                        .musleabi,
                        .musleabihf,
                        .muslx32,
                        => return 64,
                        else => switch (target.os.tag) {
                            .aix, .freebsd, .openbsd => return 64,
                            else => return 128,
                        },
                    },

                    .riscv32,
                    .riscv64,
                    .aarch64,
                    .aarch64_be,
                    .s390x,
                    .mips64,
                    .mips64el,
                    .sparc64,
                    .wasm32,
                    .wasm64,
                    .loongarch32,
                    .loongarch64,
                    .ve,
                    => return 128,

                    else => return 64,
                },
            },
        },

        .windows, .uefi => switch (target.cpu.arch) {
            .x86 => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => return 32,
                .longlong, .ulonglong, .double => return 64,
                .longdouble => switch (target.abi) {
                    .gnu, .gnuilp32, .ilp32, .cygnus => return 80,
                    else => return 64,
                },
            },
            .x86_64 => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => switch (target.abi) {
                    .cygnus => return 64,
                    else => return 32,
                },
                .longlong, .ulonglong, .double => return 64,
                .longdouble => switch (target.abi) {
                    .gnu, .gnuilp32, .ilp32, .cygnus => return 80,
                    else => return 64,
                },
            },
            else => switch (c_type) {
                .char => return 8,
                .short, .ushort => return 16,
                .int, .uint, .float => return 32,
                .long, .ulong => return 32,
                .longlong, .ulonglong, .double => return 64,
                .longdouble => return 64,
            },
        },

        .driverkit,
        .ios,
        .macos,
        .tvos,
        .visionos,
        .watchos,
        => switch (c_type) {
            .char => return 8,
            .short, .ushort => return 16,
            .int, .uint, .float => return 32,
            .long, .ulong => switch (target.cpu.arch) {
                .x86_64 => return 64,
                else => switch (target.abi) {
                    .ilp32 => return 32,
                    else => return 64,
                },
            },
            .longlong, .ulonglong, .double => return 64,
            .longdouble => switch (target.cpu.arch) {
                .x86_64 => return 80,
                else => return 64,
            },
        },

        .nvcl, .cuda => switch (c_type) {
            .char => return 8,
            .short, .ushort => return 16,
            .int, .uint, .float => return 32,
            .long, .ulong => switch (target.cpu.arch) {
                .nvptx => return 32,
                .nvptx64 => return 64,
                else => return 64,
            },
            .longlong, .ulonglong, .double => return 64,
            .longdouble => return 64,
        },

        .amdhsa, .amdpal, .mesa3d => switch (c_type) {
            .char => return 8,
            .short, .ushort => return 16,
            .int, .uint, .float => return 32,
            .long, .ulong, .longlong, .ulonglong, .double => return 64,
            .longdouble => return 128,
        },

        .opencl, .vulkan => switch (c_type) {
            .char => return 8,
            .short, .ushort => return 16,
            .int, .uint, .float => return 32,
            .long, .ulong, .double => return 64,
            .longlong, .ulonglong => return 128,
            // Note: The OpenCL specification does not guarantee a particular size for long double,
            // but clang uses 128 bits.
            .longdouble => return 128,
        },

        .ps4, .ps5 => switch (c_type) {
            .char => return 8,
            .short, .ushort => return 16,
            .int, .uint, .float => return 32,
            .long, .ulong => return 64,
            .longlong, .ulonglong, .double => return 64,
            .longdouble => return 80,
        },

        .ps3,
        .contiki,
        .opengl,
        => @panic("specify the C integer and float type sizes for this OS"),
    }
}

pub fn cTypeAlignment(target: Target, c_type: CType) u16 {
    // Overrides for unusual alignments
    switch (target.cpu.arch) {
        .avr => return 1,
        .x86 => switch (target.os.tag) {
            .elfiamcu => switch (c_type) {
                .longlong, .ulonglong, .double => return 4,
                else => {},
            },
            .windows, .uefi => switch (c_type) {
                .longlong, .ulonglong, .double => return 8,
                .longdouble => switch (target.abi) {
                    .gnu, .gnuilp32, .ilp32, .cygnus => return 4,
                    else => return 8,
                },
                else => {},
            },
            else => {},
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => switch (target.os.tag) {
            .aix => switch (c_type) {
                .double, .longdouble => return 4,
                else => {},
            },
            else => {},
        },
        .wasm32, .wasm64 => switch (target.os.tag) {
            .emscripten => switch (c_type) {
                .longdouble => return 8,
                else => {},
            },
            else => {},
        },
        else => {},
    }

    // Next-power-of-two-aligned, up to a maximum.
    return @min(
        std.math.ceilPowerOfTwoAssert(u16, (cTypeBitSize(target, c_type) + 7) / 8),
        @as(u16, switch (target.cpu.arch) {
            .msp430,
            => 2,

            .arc,
            .csky,
            .x86,
            .xcore,
            .kalimba,
            .spu_2,
            .xtensa,
            .propeller1,
            .propeller2,
            => 4,

            .arm,
            .armeb,
            .thumb,
            .thumbeb,
            .amdgcn,
            .bpfel,
            .bpfeb,
            .hexagon,
            .m68k,
            .mips,
            .mipsel,
            .sparc,
            .lanai,
            .nvptx,
            .nvptx64,
            .s390x,
            => 8,

            .aarch64,
            .aarch64_be,
            .loongarch32,
            .loongarch64,
            .mips64,
            .mips64el,
            .powerpc,
            .powerpcle,
            .powerpc64,
            .powerpc64le,
            .riscv32,
            .riscv64,
            .sparc64,
            .spirv,
            .spirv32,
            .spirv64,
            .x86_64,
            .ve,
            .wasm32,
            .wasm64,
            => 16,

            .avr,
            => unreachable, // Handled above.
        }),
    );
}

pub fn cTypePreferredAlignment(target: Target, c_type: CType) u16 {
    // Overrides for unusual alignments
    switch (target.cpu.arch) {
        .arc => switch (c_type) {
            .longdouble => return 4,
            else => {},
        },
        .avr => return 1,
        .x86 => switch (target.os.tag) {
            .elfiamcu => switch (c_type) {
                .longlong, .ulonglong, .double, .longdouble => return 4,
                else => {},
            },
            .windows, .uefi => switch (c_type) {
                .longdouble => switch (target.abi) {
                    .gnu, .gnuilp32, .ilp32, .cygnus => return 4,
                    else => return 8,
                },
                else => {},
            },
            else => switch (c_type) {
                .longdouble => return 4,
                else => {},
            },
        },
        .wasm32, .wasm64 => switch (target.os.tag) {
            .emscripten => switch (c_type) {
                .longdouble => return 8,
                else => {},
            },
            else => {},
        },
        else => {},
    }

    // Next-power-of-two-aligned, up to a maximum.
    return @min(
        std.math.ceilPowerOfTwoAssert(u16, (cTypeBitSize(target, c_type) + 7) / 8),
        @as(u16, switch (target.cpu.arch) {
            .msp430 => 2,

            .csky,
            .xcore,
            .kalimba,
            .spu_2,
            .xtensa,
            .propeller1,
            .propeller2,
            => 4,

            .arc,
            .arm,
            .armeb,
            .thumb,
            .thumbeb,
            .amdgcn,
            .bpfel,
            .bpfeb,
            .hexagon,
            .x86,
            .m68k,
            .mips,
            .mipsel,
            .sparc,
            .lanai,
            .nvptx,
            .nvptx64,
            .s390x,
            => 8,

            .aarch64,
            .aarch64_be,
            .loongarch32,
            .loongarch64,
            .mips64,
            .mips64el,
            .powerpc,
            .powerpcle,
            .powerpc64,
            .powerpc64le,
            .riscv32,
            .riscv64,
            .sparc64,
            .spirv,
            .spirv32,
            .spirv64,
            .x86_64,
            .ve,
            .wasm32,
            .wasm64,
            => 16,

            .avr,
            => unreachable, // Handled above.
        }),
    );
}

pub fn cCallingConvention(target: Target) ?std.builtin.CallingConvention {
    return switch (target.cpu.arch) {
        .x86_64 => switch (target.os.tag) {
            .windows, .uefi => .{ .x86_64_win = .{} },
            else => .{ .x86_64_sysv = .{} },
        },
        .x86 => switch (target.os.tag) {
            .windows, .uefi => .{ .x86_win = .{} },
            else => .{ .x86_sysv = .{} },
        },
        .aarch64, .aarch64_be => if (target.os.tag.isDarwin()) cc: {
            break :cc .{ .aarch64_aapcs_darwin = .{} };
        } else switch (target.os.tag) {
            .windows => .{ .aarch64_aapcs_win = .{} },
            else => .{ .aarch64_aapcs = .{} },
        },
        .arm, .armeb, .thumb, .thumbeb => switch (target.abi.floatAbi()) {
            .soft => .{ .arm_aapcs = .{} },
            .hard => .{ .arm_aapcs_vfp = .{} },
        },
        .mips64, .mips64el => switch (target.abi) {
            .gnuabin32 => .{ .mips64_n32 = .{} },
            else => .{ .mips64_n64 = .{} },
        },
        .mips, .mipsel => .{ .mips_o32 = .{} },
        .riscv64 => .{ .riscv64_lp64 = .{} },
        .riscv32 => .{ .riscv32_ilp32 = .{} },
        .sparc64 => .{ .sparc64_sysv = .{} },
        .sparc => .{ .sparc_sysv = .{} },
        .powerpc64 => if (target.isMusl())
            .{ .powerpc64_elf_v2 = .{} }
        else
            .{ .powerpc64_elf = .{} },
        .powerpc64le => .{ .powerpc64_elf_v2 = .{} },
        .powerpc, .powerpcle => switch (target.os.tag) {
            .aix => .{ .powerpc_aix = .{} },
            else => .{ .powerpc_sysv = .{} },
        },
        .wasm32 => .{ .wasm_watc = .{} },
        .wasm64 => .{ .wasm_watc = .{} },
        .arc => .{ .arc_sysv = .{} },
        .avr => .avr_gnu,
        .bpfel, .bpfeb => .{ .bpf_std = .{} },
        .csky => .{ .csky_sysv = .{} },
        .hexagon => .{ .hexagon_sysv = .{} },
        .kalimba => null,
        .lanai => .{ .lanai_sysv = .{} },
        .loongarch64 => .{ .loongarch64_lp64 = .{} },
        .loongarch32 => .{ .loongarch32_ilp32 = .{} },
        .m68k => if (target.abi.isGnu() or target.abi.isMusl())
            .{ .m68k_gnu = .{} }
        else
            .{ .m68k_sysv = .{} },
        .msp430 => .{ .msp430_eabi = .{} },
        .propeller1 => .{ .propeller1_sysv = .{} },
        .propeller2 => .{ .propeller2_sysv = .{} },
        .s390x => .{ .s390x_sysv = .{} },
        .spu_2 => null,
        .ve => .{ .ve_sysv = .{} },
        .xcore => .{ .xcore_xs1 = .{} },
        .xtensa => .{ .xtensa_call0 = .{} },
        .amdgcn => .{ .amdgcn_device = .{} },
        .nvptx, .nvptx64 => .nvptx_device,
        .spirv, .spirv32, .spirv64 => .spirv_device,
    };
}

pub fn osArchName(target: std.Target) [:0]const u8 {
    return target.os.tag.archName(target.cpu.arch);
}

const Target = @This();
const std = @import("std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

test {
    std.testing.refAllDecls(Cpu.Arch);
}
