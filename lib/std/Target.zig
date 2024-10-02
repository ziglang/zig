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

        bridgeos,
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
        shadermodel,
        vulkan,

        // LLVM tags deliberately omitted:
        // - darwin
        // - kfreebsd
        // - nacl

        pub inline fn isDarwin(tag: Tag) bool {
            return switch (tag) {
                .bridgeos,
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
                .msvc => ".lib",
                else => switch (tag) {
                    .windows, .uefi => ".lib",
                    else => ".a",
                },
            };
        }

        pub fn dynamicLibSuffix(tag: Tag) [:0]const u8 {
            return switch (tag) {
                .windows, .uefi => ".dll",
                .bridgeos,
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
                .msvc => "",
                else => switch (tag) {
                    .windows, .uefi => "",
                    else => "lib",
                },
            };
        }

        pub inline fn isGnuLibC(tag: Os.Tag, abi: Abi) bool {
            return (tag == .hurd or tag == .linux) and abi.isGnu();
        }

        pub fn defaultVersionRange(tag: Tag, arch: Cpu.Arch) Os {
            return .{
                .tag = tag,
                .version_range = VersionRange.default(tag, arch),
            };
        }

        pub inline fn getVersionRangeTag(tag: Tag) @typeInfo(TaggedVersionRange).@"union".tag_type.? {
            return switch (tag) {
                .freestanding,
                .fuchsia,
                .ps3,
                .zos,
                .haiku,
                .rtems,
                .aix,
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
                .emscripten,
                .shadermodel,
                .uefi,
                .opencl, // TODO: OpenCL versions
                .opengl, // TODO: GLSL versions
                .vulkan,
                .plan9,
                .illumos,
                .serenity,
                .other,
                => .none,

                .bridgeos,
                .driverkit,
                .freebsd,
                .macos,
                .ios,
                .tvos,
                .watchos,
                .visionos,
                .netbsd,
                .openbsd,
                .dragonfly,
                .solaris,
                .wasi,
                => .semver,

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
        _,

        /// Latest Windows version that the Zig Standard Library is aware of
        pub const latest = WindowsVersion.win11_ge;

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

    pub const LinuxVersionRange = struct {
        range: std.SemanticVersion.Range,
        glibc: std.SemanticVersion,

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
        linux: LinuxVersionRange,
        windows: WindowsVersion.Range,

        /// The default `VersionRange` represents the range that the Zig Standard Library
        /// bases its abstractions on.
        pub fn default(tag: Tag, arch: Cpu.Arch) VersionRange {
            return switch (tag) {
                .freestanding,
                .fuchsia,
                .ps3,
                .zos,
                .haiku,
                .rtems,
                .aix,
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
                .emscripten,
                .shadermodel,
                .uefi,
                .opencl, // TODO: OpenCL versions
                .opengl, // TODO: GLSL versions
                .vulkan,
                .plan9,
                .illumos,
                .serenity,
                .bridgeos,
                .other,
                => .{ .none = {} },

                .freebsd => .{
                    .semver = std.SemanticVersion.Range{
                        .min = .{ .major = 12, .minor = 0, .patch = 0 },
                        .max = .{ .major = 14, .minor = 0, .patch = 0 },
                    },
                },
                .driverkit => .{
                    .semver = .{
                        .min = .{ .major = 19, .minor = 0, .patch = 0 },
                        .max = .{ .major = 24, .minor = 0, .patch = 0 },
                    },
                },
                .macos => switch (arch) {
                    .aarch64 => VersionRange{
                        .semver = .{
                            .min = .{ .major = 11, .minor = 7, .patch = 1 },
                            .max = .{ .major = 14, .minor = 6, .patch = 1 },
                        },
                    },
                    .x86_64 => VersionRange{
                        .semver = .{
                            .min = .{ .major = 11, .minor = 7, .patch = 1 },
                            .max = .{ .major = 14, .minor = 6, .patch = 1 },
                        },
                    },
                    else => unreachable,
                },
                .ios => .{
                    .semver = .{
                        .min = .{ .major = 12, .minor = 0, .patch = 0 },
                        .max = .{ .major = 17, .minor = 6, .patch = 1 },
                    },
                },
                .watchos => .{
                    .semver = .{
                        .min = .{ .major = 6, .minor = 0, .patch = 0 },
                        .max = .{ .major = 10, .minor = 6, .patch = 0 },
                    },
                },
                .tvos => .{
                    .semver = .{
                        .min = .{ .major = 13, .minor = 0, .patch = 0 },
                        .max = .{ .major = 17, .minor = 6, .patch = 0 },
                    },
                },
                .visionos => .{
                    .semver = .{
                        .min = .{ .major = 1, .minor = 0, .patch = 0 },
                        .max = .{ .major = 1, .minor = 3, .patch = 0 },
                    },
                },
                .netbsd => .{
                    .semver = .{
                        .min = .{ .major = 8, .minor = 0, .patch = 0 },
                        .max = .{ .major = 10, .minor = 0, .patch = 0 },
                    },
                },
                .openbsd => .{
                    .semver = .{
                        .min = .{ .major = 7, .minor = 3, .patch = 0 },
                        .max = .{ .major = 7, .minor = 5, .patch = 0 },
                    },
                },
                .dragonfly => .{
                    .semver = .{
                        .min = .{ .major = 5, .minor = 8, .patch = 0 },
                        .max = .{ .major = 6, .minor = 4, .patch = 0 },
                    },
                },
                .solaris => .{
                    .semver = .{
                        .min = .{ .major = 11, .minor = 0, .patch = 0 },
                        .max = .{ .major = 11, .minor = 4, .patch = 0 },
                    },
                },
                .wasi => .{
                    .semver = .{
                        .min = .{ .major = 0, .minor = 1, .patch = 0 },
                        .max = .{ .major = 0, .minor = 1, .patch = 0 },
                    },
                },

                .linux => .{
                    .linux = .{
                        .range = .{
                            .min = .{ .major = 4, .minor = 19, .patch = 0 },
                            .max = .{ .major = 6, .minor = 10, .patch = 3 },
                        },
                        .glibc = blk: {
                            const default_min = .{ .major = 2, .minor = 28, .patch = 0 };

                            for (std.zig.target.available_libcs) |libc| {
                                // We don't know the ABI here. We can get away with not checking it
                                // for now, but that may not always remain true.
                                if (libc.os != tag or libc.arch != arch) continue;

                                if (libc.glibc_min) |min| {
                                    if (min.order(default_min) == .gt) break :blk min;
                                }
                            }

                            break :blk default_min;
                        },
                    },
                },

                .windows => .{
                    .windows = .{
                        .min = .win10,
                        .max = WindowsVersion.latest,
                    },
                },
            };
        }
    };

    pub const TaggedVersionRange = union(enum) {
        none: void,
        semver: std.SemanticVersion.Range,
        linux: LinuxVersionRange,
        windows: WindowsVersion.Range,
    };

    /// Provides a tagged union. `Target` does not store the tag because it is
    /// redundant with the OS tag; this function abstracts that part away.
    pub inline fn getVersionRange(os: Os) TaggedVersionRange {
        return switch (os.tag.getVersionRangeTag()) {
            .none => .{ .none = {} },
            .semver => .{ .semver = os.version_range.semver },
            .linux => .{ .linux = os.version_range.linux },
            .windows => .{ .windows = os.version_range.windows },
        };
    }

    /// Checks if system is guaranteed to be at least `version` or older than `version`.
    /// Returns `null` if a runtime check is required.
    pub inline fn isAtLeast(os: Os, comptime tag: Tag, ver: switch (tag.getVersionRangeTag()) {
        .none => void,
        .semver, .linux => std.SemanticVersion,
        .windows => WindowsVersion,
    }) ?bool {
        return if (os.tag != tag) false else switch (tag.getVersionRangeTag()) {
            .none => true,
            inline .semver,
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
            .bridgeos,
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
            .shadermodel,
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
pub const amdgpu = @import("Target/amdgpu.zig");
pub const arm = @import("Target/arm.zig");
pub const avr = @import("Target/avr.zig");
pub const bpf = @import("Target/bpf.zig");
pub const csky = @import("Target/csky.zig");
pub const hexagon = @import("Target/hexagon.zig");
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
pub const xtensa = @import("Target/xtensa.zig");

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
    musleabi,
    musleabihf,
    muslx32,
    msvc,
    itanium,
    cygnus,
    simulator,
    macabi,
    ohos,

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
        return if (arch.isWasm()) .musl else switch (os.tag) {
            .freestanding,
            .dragonfly,
            .ps3,
            .zos,
            .rtems,
            .aix,
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
            .other,
            => .eabi,
            .openbsd,
            .freebsd,
            .fuchsia,
            .netbsd,
            .hurd,
            .haiku,
            .windows,
            => .gnu,
            .uefi => .msvc,
            .linux,
            .wasi,
            .emscripten,
            => .musl,
            .bridgeos,
            .opencl,
            .opengl,
            .vulkan,
            .plan9, // TODO specify abi
            .macos,
            .ios,
            .tvos,
            .watchos,
            .visionos,
            .driverkit,
            .shadermodel,
            .solaris,
            .illumos,
            .serenity,
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
            .musl, .musleabi, .musleabihf, .muslx32 => true,
            .ohos => true,
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
            .ohos,
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
            .bridgeos, .driverkit, .ios, .macos, .tvos, .visionos, .watchos => .macho,
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
    if (target.os.tag == .elfiamcu) return .IAMCU;

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
        .x86 => .@"386",
        .x86_64 => .X86_64,
        .xcore => .XCORE,
        .xtensa => .XTENSA,

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
        .thumb => .THUMB,
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

        pub inline fn isARM(arch: Arch) bool {
            return switch (arch) {
                .arm, .armeb => true,
                else => false,
            };
        }

        pub inline fn isAARCH64(arch: Arch) bool {
            return switch (arch) {
                .aarch64, .aarch64_be => true,
                else => false,
            };
        }

        pub inline fn isThumb(arch: Arch) bool {
            return switch (arch) {
                .thumb, .thumbeb => true,
                else => false,
            };
        }

        pub inline fn isArmOrThumb(arch: Arch) bool {
            return arch.isARM() or arch.isThumb();
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
                .input, .output, .uniform => is_spirv,
                // TODO this should also check how many flash banks the cpu has
                .flash, .flash1, .flash2, .flash3, .flash4, .flash5 => arch == .avr,
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
                .amdgcn => "amdgpu",
                .riscv32, .riscv64 => "riscv",
                .sparc, .sparc64 => "sparc",
                .s390x => "s390x",
                .x86, .x86_64 => "x86",
                .nvptx, .nvptx64 => "nvptx",
                .wasm32, .wasm64 => "wasm",
                .spirv, .spirv32, .spirv64 => "spirv",
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
                .loongarch32, .loongarch64 => &loongarch.all_features,
                .m68k => &m68k.all_features,
                .mips, .mipsel, .mips64, .mips64el => &mips.all_features,
                .msp430 => &msp430.all_features,
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => &powerpc.all_features,
                .amdgcn => &amdgpu.all_features,
                .riscv32, .riscv64 => &riscv.all_features,
                .sparc, .sparc64 => &sparc.all_features,
                .spirv, .spirv32, .spirv64 => &spirv.all_features,
                .s390x => &s390x.all_features,
                .x86, .x86_64 => &x86.all_features,
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
                .loongarch32, .loongarch64 => comptime allCpusFromDecls(loongarch.cpu),
                .m68k => comptime allCpusFromDecls(m68k.cpu),
                .mips, .mipsel, .mips64, .mips64el => comptime allCpusFromDecls(mips.cpu),
                .msp430 => comptime allCpusFromDecls(msp430.cpu),
                .powerpc, .powerpcle, .powerpc64, .powerpc64le => comptime allCpusFromDecls(powerpc.cpu),
                .amdgcn => comptime allCpusFromDecls(amdgpu.cpu),
                .riscv32, .riscv64 => comptime allCpusFromDecls(riscv.cpu),
                .sparc, .sparc64 => comptime allCpusFromDecls(sparc.cpu),
                .spirv, .spirv32, .spirv64 => comptime allCpusFromDecls(spirv.cpu),
                .s390x => comptime allCpusFromDecls(s390x.cpu),
                .x86, .x86_64 => comptime allCpusFromDecls(x86.cpu),
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

        pub fn generic(arch: Arch) *const Model {
            const S = struct {
                const generic_model = Model{
                    .name = "generic",
                    .llvm_name = null,
                    .features = Cpu.Feature.Set.empty,
                };
            };
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.generic,
                .aarch64, .aarch64_be => &aarch64.cpu.generic,
                .avr => &avr.cpu.avr2,
                .bpfel, .bpfeb => &bpf.cpu.generic,
                .hexagon => &hexagon.cpu.generic,
                .loongarch32 => &loongarch.cpu.generic_la32,
                .loongarch64 => &loongarch.cpu.generic_la64,
                .m68k => &m68k.cpu.generic,
                .mips, .mipsel => &mips.cpu.mips32,
                .mips64, .mips64el => &mips.cpu.mips64,
                .msp430 => &msp430.cpu.generic,
                .powerpc => &powerpc.cpu.ppc,
                .powerpcle => &powerpc.cpu.ppc,
                .powerpc64 => &powerpc.cpu.ppc64,
                .powerpc64le => &powerpc.cpu.ppc64le,
                .amdgcn => &amdgpu.cpu.generic,
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
                .wasm32, .wasm64 => &wasm.cpu.generic,

                else => &S.generic_model,
            };
        }

        pub fn baseline(arch: Arch) *const Model {
            return switch (arch) {
                .arm, .armeb, .thumb, .thumbeb => &arm.cpu.baseline,
                .hexagon => &hexagon.cpu.hexagonv60, // gcc/clang do not have a generic hexagon model.
                .riscv32 => &riscv.cpu.baseline_rv32,
                .riscv64 => &riscv.cpu.baseline_rv64,
                .x86 => &x86.cpu.pentium4,
                .nvptx, .nvptx64 => &nvptx.cpu.sm_20,
                .s390x => &s390x.cpu.arch8, // gcc/clang do not have a generic s390x model.
                .sparc => &sparc.cpu.v9, // glibc does not work with 'plain' v8.
                .loongarch64 => &loongarch.cpu.loongarch64,

                else => generic(arch),
            };
        }
    };

    /// The "default" set of CPU features for cross-compiling. A conservative set
    /// of features that is expected to be supported on most available hardware.
    pub fn baseline(arch: Arch) Cpu {
        return Model.baseline(arch).toCpu(arch);
    }
};

pub fn zigTriple(target: Target, allocator: Allocator) Allocator.Error![]u8 {
    return Query.fromTarget(target).zigTriple(allocator);
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

pub inline fn isBpfFreestanding(target: Target) bool {
    return target.cpu.arch.isBpf() and target.os.tag == .freestanding;
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

pub inline fn hasDynamicLinker(target: Target) bool {
    if (target.cpu.arch.isWasm()) {
        return false;
    }
    switch (target.os.tag) {
        .freestanding,
        .ios,
        .tvos,
        .watchos,
        .macos,
        .visionos,
        .uefi,
        .windows,
        .emscripten,
        .opencl,
        .opengl,
        .vulkan,
        .plan9,
        .other,
        => return false,
        else => return true,
    }
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

    pub fn standard(cpu: Cpu, os_tag: Os.Tag, abi: Abi) DynamicLinker {
        return if (abi.isAndroid()) initFmt("/system/bin/linker{s}", .{
            if (ptrBitWidth_cpu_abi(cpu, abi) == 64) "64" else "",
        }) catch unreachable else if (abi.isMusl()) return initFmt("/lib/ld-musl-{s}{s}.so.1", .{
            @tagName(switch (cpu.arch) {
                .thumb => .arm,
                .thumbeb => .armeb,
                else => cpu.arch,
            }),
            if (cpu.arch.isArmOrThumb() and abi.floatAbi() == .hard) "hf" else "",
        }) catch unreachable else switch (os_tag) {
            .freebsd => init("/libexec/ld-elf.so.1"),
            .netbsd => init("/libexec/ld.elf_so"),
            .openbsd => init("/usr/libexec/ld.so"),
            .dragonfly => init("/libexec/ld-elf.so.2"),
            .solaris, .illumos => init("/lib/64/ld.so.1"),
            .linux => switch (cpu.arch) {
                .x86,
                .sparc,
                => init("/lib/ld-linux.so.2"),

                .aarch64 => init("/lib/ld-linux-aarch64.so.1"),
                .aarch64_be => init("/lib/ld-linux-aarch64_be.so.1"),

                .arm,
                .armeb,
                .thumb,
                .thumbeb,
                => initFmt("/lib/ld-linux{s}.so.3", .{switch (abi.floatAbi()) {
                    .hard => "-armhf",
                    else => "",
                }}) catch unreachable,

                .loongarch64 => init("/lib64/ld-linux-loongarch-lp64d.so.1"),

                .mips,
                .mipsel,
                .mips64,
                .mips64el,
                => initFmt("/lib{s}/{s}", .{
                    switch (abi) {
                        .gnuabin32, .gnux32 => "32",
                        .gnuabi64 => "64",
                        else => "",
                    },
                    if (mips.featureSetHas(cpu.features, .nan2008))
                        "ld-linux-mipsn8.so.1"
                    else
                        "ld.so.1",
                }) catch unreachable,

                .powerpc, .powerpcle => init("/lib/ld.so.1"),
                .powerpc64, .powerpc64le => init("/lib64/ld64.so.2"),
                .s390x => init("/lib64/ld64.so.1"),
                .sparc64 => init("/lib64/ld-linux.so.2"),
                .x86_64 => init(switch (abi) {
                    .gnux32 => "/libx32/ld-linux-x32.so.2",
                    else => "/lib64/ld-linux-x86-64.so.2",
                }),

                .riscv32 => init("/lib/ld-linux-riscv32-ilp32d.so.1"),
                .riscv64 => init("/lib/ld-linux-riscv64-lp64d.so.1"),

                // Architectures in this list have been verified as not having a standard
                // dynamic linker path.
                .wasm32,
                .wasm64,
                .bpfel,
                .bpfeb,
                .nvptx,
                .nvptx64,
                .spu_2,
                .avr,
                .spirv,
                .spirv32,
                .spirv64,
                => none,

                // TODO go over each item in this list and either move it to the above list, or
                // implement the standard dynamic linker path code for it.
                .arc,
                .csky,
                .hexagon,
                .m68k,
                .msp430,
                .amdgcn,
                .xcore,
                .kalimba,
                .lanai,
                .ve,
                .loongarch32,
                .xtensa,
                => none,
            },

            .bridgeos,
            .driverkit,
            .ios,
            .tvos,
            .watchos,
            .macos,
            .visionos,
            => init("/usr/lib/dyld"),

            .serenity => init("/usr/lib/Loader.so"),

            // Operating systems in this list have been verified as not having a standard
            // dynamic linker path.
            .freestanding,
            .uefi,
            .windows,
            .emscripten,
            .wasi,
            .opencl,
            .opengl,
            .vulkan,
            .other,
            .plan9,
            => none,

            // TODO revisit when multi-arch for Haiku is available
            .haiku => init("/system/runtime_loader"),

            // TODO go over each item in this list and either move it to the above list, or
            // implement the standard dynamic linker path code for it.
            .fuchsia,
            .ps3,
            .zos,
            .rtems,
            .aix,
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
            .shadermodel,
            => none,
        };
    }
};

pub fn standardDynamicLinkerPath(target: Target) DynamicLinker {
    return DynamicLinker.standard(target.cpu, target.os.tag, target.abi);
}

pub fn ptrBitWidth_cpu_abi(cpu: Cpu, abi: Abi) u16 {
    switch (abi) {
        .gnux32, .muslx32, .gnuabin32, .gnuilp32, .ilp32 => return 32,
        .gnuabi64 => return 64,
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
        // Some of the following prongs should really be testing the ABI (e.g. for Arm, it's APCS vs
        // AAPCS16 vs AAPCS). But our current Abi enum is not able to handle that level of nuance.
        .arm,
        .armeb,
        .thumb,
        .thumbeb,
        => switch (target.os.tag) {
            .netbsd => {},
            .watchos => return 16,
            else => return 8,
        },
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
                .long, .ulong => return if (target.abi != .gnuabin32) 64 else 32,
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

        .linux,
        .freebsd,
        .netbsd,
        .dragonfly,
        .openbsd,
        .wasi,
        .emscripten,
        .plan9,
        .solaris,
        .illumos,
        .haiku,
        .fuchsia,
        .serenity,
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
                .long, .ulong => return if (target.abi != .gnuabin32) 64 else 32,
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
                        else => return 80,
                    },

                    .powerpc,
                    .powerpcle,
                    => switch (target.abi) {
                        .musl,
                        .musleabi,
                        .musleabihf,
                        .muslx32,
                        => return 64,
                        else => switch (target.os.tag) {
                            .freebsd, .netbsd, .openbsd => return 64,
                            else => return 128,
                        },
                    },

                    .powerpc64,
                    .powerpc64le,
                    => switch (target.abi) {
                        .musl,
                        .musleabi,
                        .musleabihf,
                        .muslx32,
                        => return 64,
                        else => switch (target.os.tag) {
                            .freebsd, .openbsd => return 64,
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

        .bridgeos,
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
                .x86, .arm => return 32,
                .x86_64 => switch (target.abi) {
                    .gnux32, .muslx32 => return 32,
                    else => return 64,
                },
                else => return 64,
            },
            .longlong, .ulonglong, .double => return 64,
            .longdouble => switch (target.cpu.arch) {
                .x86 => switch (target.abi) {
                    .android => return 64,
                    else => return 80,
                },
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
        .zos,
        .rtems,
        .aix,
        .elfiamcu,
        .contiki,
        .hermit,
        .hurd,
        .opengl,
        .shadermodel,
        => @panic("TODO specify the C integer and float type sizes for this OS"),
    }
}

pub fn cTypeAlignment(target: Target, c_type: CType) u16 {
    // Overrides for unusual alignments
    switch (target.cpu.arch) {
        .avr => return 1,
        .x86 => switch (target.os.tag) {
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
        else => {},
    }

    // Next-power-of-two-aligned, up to a maximum.
    return @min(
        std.math.ceilPowerOfTwoAssert(u16, (cTypeBitSize(target, c_type) + 7) / 8),
        @as(u16, switch (target.cpu.arch) {
            .arm, .armeb, .thumb, .thumbeb => switch (target.os.tag) {
                .netbsd => switch (target.abi) {
                    .gnueabi,
                    .gnueabihf,
                    .eabi,
                    .eabihf,
                    .android,
                    .androideabi,
                    .musleabi,
                    .musleabihf,
                    => 8,

                    else => 4,
                },
                .ios, .tvos, .watchos, .visionos => 4,
                else => 8,
            },

            .msp430,
            .avr,
            => 2,

            .arc,
            .csky,
            .x86,
            .xcore,
            .loongarch32,
            .kalimba,
            .spu_2,
            .xtensa,
            => 4,

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
        }),
    );
}

pub fn cTypePreferredAlignment(target: Target, c_type: CType) u16 {
    // Overrides for unusual alignments
    switch (target.cpu.arch) {
        .arm, .armeb, .thumb, .thumbeb => switch (target.os.tag) {
            .netbsd => switch (target.abi) {
                .gnueabi,
                .gnueabihf,
                .eabi,
                .eabihf,
                .android,
                .androideabi,
                .musleabi,
                .musleabihf,
                => {},

                else => switch (c_type) {
                    .longdouble => return 4,
                    else => {},
                },
            },
            .ios, .tvos, .watchos, .visionos => switch (c_type) {
                .longdouble => return 4,
                else => {},
            },
            else => {},
        },
        .arc => switch (c_type) {
            .longdouble => return 4,
            else => {},
        },
        .avr => switch (c_type) {
            .char, .int, .uint, .long, .ulong, .float, .longdouble => return 1,
            .short, .ushort => return 2,
            .double => return 4,
            .longlong, .ulonglong => return 8,
        },
        .x86 => switch (target.os.tag) {
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
        else => {},
    }

    // Next-power-of-two-aligned, up to a maximum.
    return @min(
        std.math.ceilPowerOfTwoAssert(u16, (cTypeBitSize(target, c_type) + 7) / 8),
        @as(u16, switch (target.cpu.arch) {
            .msp430 => 2,

            .csky,
            .xcore,
            .loongarch32,
            .kalimba,
            .spu_2,
            .xtensa,
            => 4,

            .arc,
            .arm,
            .armeb,
            .avr,
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
        }),
    );
}

pub fn is_libc_lib_name(target: std.Target, name: []const u8) bool {
    const ignore_case = target.os.tag == .macos or target.os.tag == .windows;

    if (eqlIgnoreCase(ignore_case, name, "c"))
        return true;

    if (target.isMinGW()) {
        if (eqlIgnoreCase(ignore_case, name, "m"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingw32"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "msvcrt-os"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mingwex"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "uuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "bits"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dmoguids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxerr8"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxerr9"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mfuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "msxml2"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "msxml6"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "amstrmid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "wbemuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "wmcodecdspuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dxguid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "ksguid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "locationapi"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "portabledeviceguids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mfuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "dloadhelper"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "strmiids"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "mfuuid"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "adsiid"))
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

    if (target.os.tag == .haiku) {
        if (eqlIgnoreCase(ignore_case, name, "root"))
            return true;
        if (eqlIgnoreCase(ignore_case, name, "network"))
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

fn eqlIgnoreCase(ignore_case: bool, a: []const u8, b: []const u8) bool {
    if (ignore_case) {
        return std.ascii.eqlIgnoreCase(a, b);
    } else {
        return std.mem.eql(u8, a, b);
    }
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
