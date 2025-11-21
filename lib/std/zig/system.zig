const builtin = @import("builtin");
const std = @import("../std.zig");
const mem = std.mem;
const elf = std.elf;
const fs = std.fs;
const assert = std.debug.assert;
const Target = std.Target;
const native_endian = builtin.cpu.arch.endian();
const posix = std.posix;
const Io = std.Io;

pub const NativePaths = @import("system/NativePaths.zig");

pub const windows = @import("system/windows.zig");
pub const darwin = @import("system/darwin.zig");
pub const linux = @import("system/linux.zig");

pub const Executor = union(enum) {
    native,
    rosetta,
    qemu: []const u8,
    wine: []const u8,
    wasmtime: []const u8,
    darling: []const u8,
    bad_dl: []const u8,
    bad_os_or_cpu,
};

pub const GetExternalExecutorOptions = struct {
    allow_darling: bool = true,
    allow_qemu: bool = true,
    allow_rosetta: bool = true,
    allow_wasmtime: bool = true,
    allow_wine: bool = true,
    qemu_fixes_dl: bool = false,
    link_libc: bool = false,
};

/// Return whether or not the given host is capable of running executables of
/// the other target.
pub fn getExternalExecutor(
    host: *const std.Target,
    candidate: *const std.Target,
    options: GetExternalExecutorOptions,
) Executor {
    const os_match = host.os.tag == candidate.os.tag;
    const cpu_ok = cpu_ok: {
        if (host.cpu.arch == candidate.cpu.arch)
            break :cpu_ok true;

        if (host.cpu.arch == .x86_64 and candidate.cpu.arch == .x86)
            break :cpu_ok true;

        if (host.cpu.arch == .aarch64 and candidate.cpu.arch == .arm)
            break :cpu_ok true;

        if (host.cpu.arch == .aarch64_be and candidate.cpu.arch == .armeb)
            break :cpu_ok true;

        // TODO additionally detect incompatible CPU features.
        // Note that in some cases the OS kernel will emulate missing CPU features
        // when an illegal instruction is encountered.

        break :cpu_ok false;
    };

    var bad_result: Executor = .bad_os_or_cpu;

    if (os_match and cpu_ok) native: {
        if (options.link_libc) {
            if (candidate.dynamic_linker.get()) |candidate_dl| {
                fs.cwd().access(candidate_dl, .{}) catch {
                    bad_result = .{ .bad_dl = candidate_dl };
                    break :native;
                };
            }
        }
        return .native;
    }

    // If the OS match and OS is macOS and CPU is arm64, we can use Rosetta 2
    // to emulate the foreign architecture.
    if (options.allow_rosetta and os_match and
        (host.os.tag == .maccatalyst or host.os.tag == .macos) and host.cpu.arch == .aarch64)
    {
        switch (candidate.cpu.arch) {
            .x86_64 => return .rosetta,
            else => return bad_result,
        }
    }

    // If the OS matches, we can use QEMU to emulate a foreign architecture.
    if (options.allow_qemu and os_match and (!cpu_ok or options.qemu_fixes_dl)) {
        return switch (candidate.cpu.arch) {
            inline .aarch64,
            .arm,
            .riscv64,
            .x86,
            .x86_64,
            => |t| switch (candidate.os.tag) {
                .linux,
                .freebsd,
                => .{ .qemu = switch (t) {
                    .x86 => "qemu-i386",
                    .x86_64 => switch (candidate.abi) {
                        .gnux32, .muslx32 => return bad_result,
                        else => "qemu-x86_64",
                    },
                    else => "qemu-" ++ @tagName(t),
                } },
                else => bad_result,
            },
            inline .aarch64_be,
            .alpha,
            .armeb,
            .hexagon,
            .hppa,
            .loongarch64,
            .m68k,
            .microblaze,
            .microblazeel,
            .mips,
            .mipsel,
            .mips64,
            .mips64el,
            .or1k,
            .powerpc,
            .powerpc64,
            .powerpc64le,
            .riscv32,
            .s390x,
            .sh,
            .sheb,
            .sparc,
            .sparc64,
            .thumb,
            .thumbeb,
            .xtensa,
            .xtensaeb,
            => |t| switch (candidate.os.tag) {
                .linux,
                => .{
                    .qemu = switch (t) {
                        .powerpc => "qemu-ppc",
                        .powerpc64 => "qemu-ppc64",
                        .powerpc64le => "qemu-ppc64le",
                        .mips64, .mips64el => switch (candidate.abi) {
                            .gnuabin32, .muslabin32 => if (t == .mips64el) "qemu-mipsn32el" else "qemu-mipsn32",
                            else => "qemu-" ++ @tagName(t),
                        },
                        // TODO: Actually check the SuperH version.
                        .sh => "qemu-sh4",
                        .sheb => "qemu-sh4eb",
                        .sparc => if (candidate.cpu.has(.sparc, .v8plus)) "qemu-sparc32plus" else "qemu-sparc",
                        .thumb => "qemu-arm",
                        .thumbeb => "qemu-armeb",
                        else => "qemu-" ++ @tagName(t),
                    },
                },
                else => bad_result,
            },
            else => bad_result,
        };
    }

    if (options.allow_wasmtime and candidate.cpu.arch.isWasm()) {
        return .{ .wasmtime = "wasmtime" };
    }

    switch (candidate.os.tag) {
        .windows => {
            if (options.allow_wine) {
                const wine_supported = switch (candidate.cpu.arch) {
                    .thumb => switch (host.cpu.arch) {
                        .arm, .thumb, .aarch64 => true,
                        else => false,
                    },
                    .aarch64 => host.cpu.arch == .aarch64,
                    .x86 => host.cpu.arch.isX86(),
                    .x86_64 => host.cpu.arch == .x86_64,
                    else => false,
                };
                return if (wine_supported) .{ .wine = "wine" } else bad_result;
            }
            return bad_result;
        },
        .driverkit, .macos => {
            if (options.allow_darling) {
                // This check can be loosened once darling adds a QEMU-based emulation
                // layer for non-host architectures:
                // https://github.com/darlinghq/darling/issues/863
                if (candidate.cpu.arch != host.cpu.arch) {
                    return bad_result;
                }
                return .{ .darling = "darling" };
            }
            return bad_result;
        },
        else => return bad_result,
    }
}

pub const DetectError = error{
    FileSystem,
    SystemResources,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    DeviceBusy,
    OSVersionDetectionFail,
    Unexpected,
    ProcessNotFound,
} || Io.Cancelable;

/// Given a `Target.Query`, which specifies in detail which parts of the
/// target should be detected natively, which should be standard or default,
/// and which are provided explicitly, this function resolves the native
/// components by detecting the native system, and then resolves
/// standard/default parts relative to that.
pub fn resolveTargetQuery(io: Io, query: Target.Query) DetectError!Target {
    // Until https://github.com/ziglang/zig/issues/4592 is implemented (support detecting the
    // native CPU architecture as being different than the current target), we use this:
    const query_cpu_arch = query.cpu_arch orelse builtin.cpu.arch;
    const query_os_tag = query.os_tag orelse builtin.os.tag;
    const query_abi = query.abi orelse builtin.abi;
    var os = query_os_tag.defaultVersionRange(query_cpu_arch, query_abi);
    if (query.os_tag == null) {
        switch (builtin.target.os.tag) {
            .linux, .illumos => {
                const uts = posix.uname();
                const release = mem.sliceTo(&uts.release, 0);
                // The release field sometimes has a weird format,
                // `Version.parse` will attempt to find some meaningful interpretation.
                if (std.SemanticVersion.parse(release)) |ver| {
                    var stripped = ver;
                    stripped.pre = null;
                    stripped.build = null;
                    os.version_range.linux.range.min = stripped;
                    os.version_range.linux.range.max = stripped;
                } else |err| switch (err) {
                    error.Overflow => {},
                    error.InvalidVersion => {},
                }
            },
            .windows => {
                const detected_version = windows.detectRuntimeVersion();
                os.version_range.windows.min = detected_version;
                os.version_range.windows.max = detected_version;
            },
            .macos => try darwin.macos.detect(&os),
            .freebsd, .netbsd, .dragonfly => {
                const key = switch (builtin.target.os.tag) {
                    .freebsd => "kern.osreldate",
                    .netbsd, .dragonfly => "kern.osrevision",
                    else => unreachable,
                };
                var value: u32 = undefined;
                var len: usize = @sizeOf(@TypeOf(value));

                posix.sysctlbynameZ(key, &value, &len, null, 0) catch |err| switch (err) {
                    error.PermissionDenied => unreachable, // only when setting values,
                    error.SystemResources => unreachable, // memory already on the stack
                    error.UnknownName => unreachable, // constant, known good value
                    error.Unexpected => return error.OSVersionDetectionFail,
                };

                switch (builtin.target.os.tag) {
                    .freebsd => {
                        // https://www.freebsd.org/doc/en_US.ISO8859-1/books/porters-handbook/versions.html
                        // Major * 100,000 has been convention since FreeBSD 2.2 (1997)
                        // Minor * 1(0),000 summed has been convention since FreeBSD 2.2 (1997)
                        // e.g. 492101 = 4.11-STABLE = 4.(9+2)
                        const major = value / 100_000;
                        const minor1 = value % 100_000 / 10_000; // usually 0 since 5.1
                        const minor2 = value % 10_000 / 1_000; // 0 before 5.1, minor version since
                        const patch = value % 1_000;
                        os.version_range.semver.min = .{ .major = major, .minor = minor1 + minor2, .patch = patch };
                        os.version_range.semver.max = os.version_range.semver.min;
                    },
                    .netbsd => {
                        // #define __NetBSD_Version__ MMmmrrpp00
                        //
                        // M = major version
                        // m = minor version; a minor number of 99 indicates current.
                        // r = 0 (*)
                        // p = patchlevel
                        const major = value / 100_000_000;
                        const minor = value % 100_000_000 / 1_000_000;
                        const patch = value % 10_000 / 100;
                        os.version_range.semver.min = .{ .major = major, .minor = minor, .patch = patch };
                        os.version_range.semver.max = os.version_range.semver.min;
                    },
                    .dragonfly => {
                        // https://github.com/DragonFlyBSD/DragonFlyBSD/blob/cb2cde83771754aeef9bb3251ee48959138dec87/Makefile.inc1#L15-L17
                        // flat base10 format: Mmmmpp
                        //   M = major
                        //   m = minor; odd-numbers indicate current dev branch
                        //   p = patch
                        const major = value / 100_000;
                        const minor = value % 100_000 / 100;
                        const patch = value % 100;
                        os.version_range.semver.min = .{ .major = major, .minor = minor, .patch = patch };
                        os.version_range.semver.max = os.version_range.semver.min;
                    },
                    else => unreachable,
                }
            },
            .openbsd => {
                const mib: [2]c_int = [_]c_int{
                    posix.CTL.KERN,
                    posix.KERN.OSRELEASE,
                };
                var buf: [64:0]u8 = undefined;
                // consider that sysctl result includes null-termination
                var len: usize = buf.len + 1;

                posix.sysctl(&mib, &buf, &len, null, 0) catch |err| switch (err) {
                    error.NameTooLong => unreachable, // constant, known good value
                    error.PermissionDenied => unreachable, // only when setting values,
                    error.SystemResources => unreachable, // memory already on the stack
                    error.UnknownName => unreachable, // constant, known good value
                    error.Unexpected => return error.OSVersionDetectionFail,
                };

                if (Target.Query.parseVersion(buf[0..len :0])) |ver| {
                    assert(ver.build == null);
                    assert(ver.pre == null);
                    os.version_range.semver.min = ver;
                    os.version_range.semver.max = ver;
                } else |_| {
                    return error.OSVersionDetectionFail;
                }
            },
            else => {
                // Unimplemented, fall back to default version range.
            },
        }
    }

    if (query.os_version_min) |min| switch (min) {
        .none => {},
        .semver => |semver| switch (os.tag.versionRangeTag()) {
            inline .hurd, .linux => |t| @field(os.version_range, @tagName(t)).range.min = semver,
            else => os.version_range.semver.min = semver,
        },
        .windows => |win_ver| os.version_range.windows.min = win_ver,
    };

    if (query.os_version_max) |max| switch (max) {
        .none => {},
        .semver => |semver| switch (os.tag.versionRangeTag()) {
            inline .hurd, .linux => |t| @field(os.version_range, @tagName(t)).range.max = semver,
            else => os.version_range.semver.max = semver,
        },
        .windows => |win_ver| os.version_range.windows.max = win_ver,
    };

    if (query.glibc_version) |glibc| {
        switch (os.tag.versionRangeTag()) {
            inline .hurd, .linux => |t| @field(os.version_range, @tagName(t)).glibc = glibc,
            else => {},
        }
    }

    if (query.android_api_level) |android| {
        os.version_range.linux.android = android;
    }

    var cpu = switch (query.cpu_model) {
        .native => detectNativeCpuAndFeatures(io, query_cpu_arch, os, query),
        .baseline => Target.Cpu.baseline(query_cpu_arch, os),
        .determined_by_arch_os => if (query.cpu_arch == null)
            detectNativeCpuAndFeatures(io, query_cpu_arch, os, query)
        else
            Target.Cpu.baseline(query_cpu_arch, os),
        .explicit => |model| model.toCpu(query_cpu_arch),
    } orelse backup_cpu_detection: {
        break :backup_cpu_detection Target.Cpu.baseline(query_cpu_arch, os);
    };

    // For x86, we need to populate some CPU feature flags depending on architecture
    // and mode:
    //  * 16bit_mode => if the abi is code16
    //  * 32bit_mode => if the arch is x86
    // However, the "mode" flags can be used as overrides, so if the user explicitly
    // sets one of them, that takes precedence.
    switch (query_cpu_arch) {
        .x86_16 => {
            cpu.features.addFeature(
                @intFromEnum(Target.x86.Feature.@"16bit_mode"),
            );
        },
        .x86 => {
            if (!Target.x86.featureSetHasAny(query.cpu_features_add, .{
                .@"16bit_mode", .@"32bit_mode",
            })) {
                switch (query_abi) {
                    .code16 => cpu.features.addFeature(
                        @intFromEnum(Target.x86.Feature.@"16bit_mode"),
                    ),
                    else => cpu.features.addFeature(
                        @intFromEnum(Target.x86.Feature.@"32bit_mode"),
                    ),
                }
            }
        },
        .arm, .armeb => {
            // XXX What do we do if the target has the noarm feature?
            //     What do we do if the user specifies +thumb_mode?
        },
        .thumb, .thumbeb => {
            cpu.features.addFeature(
                @intFromEnum(Target.arm.Feature.thumb_mode),
            );
        },
        else => {},
    }
    updateCpuFeatures(
        &cpu.features,
        cpu.arch.allFeaturesList(),
        query.cpu_features_add,
        query.cpu_features_sub,
    );

    var result = detectAbiAndDynamicLinker(io, cpu, os, query) catch |err| switch (err) {
        error.Canceled => |e| return e,
        error.Unexpected => |e| return e,
        error.WouldBlock => return error.Unexpected,
        error.BrokenPipe => return error.Unexpected,
        error.ConnectionResetByPeer => return error.Unexpected,
        error.Timeout => return error.Unexpected,
        error.NotOpenForReading => return error.Unexpected,
        error.SocketUnconnected => return error.Unexpected,

        error.AccessDenied,
        error.ProcessNotFound,
        error.SymLinkLoop,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        error.SystemResources,
        error.IsDir,
        error.DeviceBusy,
        error.InputOutput,
        error.LockViolation,
        error.FileSystem,

        error.UnableToOpenElfFile,
        error.UnhelpfulFile,
        error.InvalidElfFile,
        error.RelativeShebang,
        => return defaultAbiAndDynamicLinker(cpu, os, query),
    };

    // These CPU feature hacks have to come after ABI detection.
    {
        if (result.cpu.arch == .hexagon) {
            // Both LLVM and LLD have broken support for the small data area. Yet LLVM has the
            // feature on by default for all Hexagon CPUs. Clang sort of solves this by defaulting
            // the `-gpsize` command line parameter for the Hexagon backend to 0, so that no
            // constants get placed in the SDA. (This of course breaks down if the user passes
            // `-G <n>` to Clang...) We can't do the `-gpsize` hack because we can have multiple
            // concurrent LLVM emit jobs, and command line options in LLVM are shared globally. So
            // just force this feature off. Lovely stuff.
            result.cpu.features.removeFeature(@intFromEnum(Target.hexagon.Feature.small_data));
        }

        // https://github.com/llvm/llvm-project/issues/105978
        if (result.cpu.arch.isArm() and result.abi.float() == .soft) {
            result.cpu.features.removeFeature(@intFromEnum(Target.arm.Feature.vfp2));
        }

        // https://github.com/llvm/llvm-project/issues/135283
        if (result.cpu.arch.isMIPS() and result.abi.float() == .soft) {
            result.cpu.features.addFeature(@intFromEnum(Target.mips.Feature.soft_float));
        }

        // https://github.com/llvm/llvm-project/issues/168992
        if (result.cpu.arch == .s390x) {
            result.cpu.features.removeFeature(@intFromEnum(Target.s390x.Feature.vector));
        }
    }

    // It's possible that we detect the native ABI, but fail to detect the OS version or were told
    // to use the default OS version range. In that case, while we can't determine the exact native
    // OS version, we do at least know that some ABIs require a particular OS version (by way of
    // `std.zig.target.available_libcs`). So in this case, adjust the OS version to the minimum that
    // we know is required.
    if (result.abi != query_abi and query.os_version_min == null) {
        const result_ver_range = &result.os.version_range;
        const abi_ver_range = result.os.tag.defaultVersionRange(result.cpu.arch, result.abi).version_range;

        switch (result.os.tag.versionRangeTag()) {
            .none => {},
            .semver => if (result_ver_range.semver.min.order(abi_ver_range.semver.min) == .lt) {
                result_ver_range.semver.min = abi_ver_range.semver.min;
            },
            inline .hurd, .linux => |t| {
                if (@field(result_ver_range, @tagName(t)).range.min.order(@field(abi_ver_range, @tagName(t)).range.min) == .lt) {
                    @field(result_ver_range, @tagName(t)).range.min = @field(abi_ver_range, @tagName(t)).range.min;
                }

                if (@field(result_ver_range, @tagName(t)).glibc.order(@field(abi_ver_range, @tagName(t)).glibc) == .lt and
                    query.glibc_version == null)
                {
                    @field(result_ver_range, @tagName(t)).glibc = @field(abi_ver_range, @tagName(t)).glibc;
                }
            },
            .windows => if (!result_ver_range.windows.min.isAtLeast(abi_ver_range.windows.min)) {
                result_ver_range.windows.min = abi_ver_range.windows.min;
            },
        }
    }

    return result;
}

fn updateCpuFeatures(
    set: *Target.Cpu.Feature.Set,
    all_features_list: []const Target.Cpu.Feature,
    add_set: Target.Cpu.Feature.Set,
    sub_set: Target.Cpu.Feature.Set,
) void {
    set.removeFeatureSet(sub_set);
    set.addFeatureSet(add_set);
    set.populateDependencies(all_features_list);
    set.removeFeatureSet(sub_set);
}

fn detectNativeCpuAndFeatures(io: Io, cpu_arch: Target.Cpu.Arch, os: Target.Os, query: Target.Query) ?Target.Cpu {
    // Here we switch on a comptime value rather than `cpu_arch`. This is valid because `cpu_arch`,
    // although it is a runtime value, is guaranteed to be one of the architectures in the set
    // of the respective switch prong.
    switch (builtin.cpu.arch) {
        .loongarch32, .loongarch64 => return @import("system/loongarch.zig").detectNativeCpuAndFeatures(cpu_arch, os, query),
        .x86_64, .x86 => return @import("system/x86.zig").detectNativeCpuAndFeatures(cpu_arch, os, query),
        else => {},
    }

    switch (builtin.os.tag) {
        .linux => return linux.detectNativeCpuAndFeatures(io),
        .macos => return darwin.macos.detectNativeCpuAndFeatures(),
        .windows => return windows.detectNativeCpuAndFeatures(),
        else => {},
    }

    // This architecture does not have CPU model & feature detection yet.
    // See https://github.com/ziglang/zig/issues/4591
    return null;
}

pub const AbiAndDynamicLinkerFromFileError = error{
    Canceled,
    AccessDenied,
    Unexpected,
    Unseekable,
    ReadFailed,
    EndOfStream,
    NameTooLong,
    StaticElfFile,
    InvalidElfFile,
    StreamTooLong,
    Timeout,
    SymLinkLoop,
    SystemResources,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    ProcessNotFound,
    IsDir,
    WouldBlock,
    InputOutput,
    BrokenPipe,
    ConnectionResetByPeer,
    NotOpenForReading,
    SocketUnconnected,
    LockViolation,
    FileSystem,
};

fn abiAndDynamicLinkerFromFile(
    file_reader: *Io.File.Reader,
    header: *const elf.Header,
    cpu: Target.Cpu,
    os: Target.Os,
    ld_info_list: []const LdInfo,
    query: Target.Query,
) AbiAndDynamicLinkerFromFileError!Target {
    const io = file_reader.io;
    var result: Target = .{
        .cpu = cpu,
        .os = os,
        .abi = query.abi orelse Target.Abi.default(cpu.arch, os.tag),
        .ofmt = query.ofmt orelse Target.ObjectFormat.default(os.tag, cpu.arch),
        .dynamic_linker = query.dynamic_linker orelse .none,
    };
    var rpath_offset: ?u64 = null; // Found inside PT_DYNAMIC
    const look_for_ld = query.dynamic_linker == null;

    var got_dyn_section: bool = false;
    {
        var it = header.iterateProgramHeaders(file_reader);
        while (try it.next()) |phdr| switch (phdr.p_type) {
            elf.PT_INTERP => {
                got_dyn_section = true;

                if (look_for_ld) {
                    const p_filesz = phdr.p_filesz;
                    if (p_filesz > result.dynamic_linker.buffer.len) return error.NameTooLong;
                    const filesz: usize = @intCast(p_filesz);
                    try file_reader.seekTo(phdr.p_offset);
                    try file_reader.interface.readSliceAll(result.dynamic_linker.buffer[0..filesz]);
                    // PT_INTERP includes a null byte in filesz.
                    const len = filesz - 1;
                    // dynamic_linker.max_byte is "max", not "len".
                    // We know it will fit in u8 because we check against dynamic_linker.buffer.len above.
                    result.dynamic_linker.len = @intCast(len);

                    // Use it to determine ABI.
                    const full_ld_path = result.dynamic_linker.buffer[0..len];
                    for (ld_info_list) |ld_info| {
                        const standard_ld_basename = fs.path.basename(ld_info.ld.get().?);
                        if (std.mem.endsWith(u8, full_ld_path, standard_ld_basename)) {
                            result.abi = ld_info.abi;
                            break;
                        }
                    }
                }
            },
            // We only need this for detecting glibc version.
            elf.PT_DYNAMIC => {
                got_dyn_section = true;

                if (builtin.target.os.tag == .linux and result.isGnuLibC() and query.glibc_version == null) {
                    var dyn_it = header.iterateDynamicSection(file_reader, phdr.p_offset, phdr.p_filesz);
                    while (try dyn_it.next()) |dyn| {
                        if (dyn.d_tag == elf.DT_RUNPATH) {
                            rpath_offset = dyn.d_val;
                            break;
                        }
                    }
                }
            },
            else => continue,
        };
    }

    if (!got_dyn_section) {
        return error.StaticElfFile;
    }

    if (builtin.target.os.tag == .linux and result.isGnuLibC() and query.glibc_version == null) {
        const str_section_off = header.shoff + @as(u64, header.shentsize) * @as(u64, header.shstrndx);
        try file_reader.seekTo(str_section_off);
        const shstr = try elf.takeSectionHeader(&file_reader.interface, header.is_64, header.endian);
        var strtab_buf: [4096]u8 = undefined;
        const shstrtab = strtab_buf[0..@min(shstr.sh_size, strtab_buf.len)];
        try file_reader.seekTo(shstr.sh_offset);
        try file_reader.interface.readSliceAll(shstrtab);
        const dynstr: ?struct { offset: u64, size: u64 } = find_dyn_str: {
            var it = header.iterateSectionHeaders(file_reader);
            while (try it.next()) |shdr| {
                const end = mem.findScalarPos(u8, shstrtab, shdr.sh_name, 0) orelse continue;
                const sh_name = shstrtab[shdr.sh_name..end :0];
                if (mem.eql(u8, sh_name, ".dynstr")) break :find_dyn_str .{
                    .offset = shdr.sh_offset,
                    .size = shdr.sh_size,
                };
            } else break :find_dyn_str null;
        };
        if (dynstr) |ds| {
            if (rpath_offset) |rpoff| {
                if (rpoff > ds.size) return error.InvalidElfFile;
                const rpoff_file = ds.offset + rpoff;
                const rp_max_size = ds.size - rpoff;

                try file_reader.seekTo(rpoff_file);
                const rpath_list = try file_reader.interface.takeSentinel(0);
                if (rpath_list.len > rp_max_size) return error.StreamTooLong;

                var it = mem.tokenizeScalar(u8, rpath_list, ':');
                while (it.next()) |rpath| {
                    if (glibcVerFromRPath(io, rpath)) |ver| {
                        result.os.version_range.linux.glibc = ver;
                        return result;
                    } else |err| switch (err) {
                        error.GLibCNotFound => continue,
                        else => |e| return e,
                    }
                }
            }
        }

        if (result.dynamic_linker.get()) |dl_path| glibc_ver: {
            // There is no DT_RUNPATH so we try to find libc.so.6 inside the same
            // directory as the dynamic linker.
            if (fs.path.dirname(dl_path)) |rpath| {
                if (glibcVerFromRPath(io, rpath)) |ver| {
                    result.os.version_range.linux.glibc = ver;
                    return result;
                } else |err| switch (err) {
                    error.GLibCNotFound => {},
                    else => |e| return e,
                }
            }

            // So far, no luck. Next we try to see if the information is
            // present in the symlink data for the dynamic linker path.
            var link_buf: [posix.PATH_MAX]u8 = undefined;
            const link_name = posix.readlink(dl_path, &link_buf) catch |err| switch (err) {
                error.NameTooLong => unreachable,
                error.BadPathName => unreachable, // Windows only
                error.UnsupportedReparsePointType => unreachable, // Windows only
                error.NetworkNotFound => unreachable, // Windows only
                error.AntivirusInterference => unreachable, // Windows only

                error.AccessDenied,
                error.PermissionDenied,
                error.FileNotFound,
                error.NotLink,
                error.NotDir,
                => break :glibc_ver,

                error.SystemResources,
                error.FileSystem,
                error.SymLinkLoop,
                error.Unexpected,
                => |e| return e,
            };
            result.os.version_range.linux.glibc = glibcVerFromLinkName(
                fs.path.basename(link_name),
                "ld-",
            ) catch |err| switch (err) {
                error.UnrecognizedGnuLibCFileName,
                error.InvalidGnuLibCVersion,
                => break :glibc_ver,
            };
            return result;
        }

        // Nothing worked so far. Finally we fall back to hard-coded search paths.
        // Some distros such as Debian keep their libc.so.6 in `/lib/$triple/`.
        var path_buf: [posix.PATH_MAX]u8 = undefined;
        var index: usize = 0;
        const prefix = "/lib/";
        const cpu_arch = @tagName(result.cpu.arch);
        const os_tag = @tagName(result.os.tag);
        const abi = @tagName(result.abi);
        @memcpy(path_buf[index..][0..prefix.len], prefix);
        index += prefix.len;
        @memcpy(path_buf[index..][0..cpu_arch.len], cpu_arch);
        index += cpu_arch.len;
        path_buf[index] = '-';
        index += 1;
        @memcpy(path_buf[index..][0..os_tag.len], os_tag);
        index += os_tag.len;
        path_buf[index] = '-';
        index += 1;
        @memcpy(path_buf[index..][0..abi.len], abi);
        index += abi.len;
        const rpath = path_buf[0..index];
        if (glibcVerFromRPath(io, rpath)) |ver| {
            result.os.version_range.linux.glibc = ver;
            return result;
        } else |err| switch (err) {
            error.GLibCNotFound => {},
            else => |e| return e,
        }
    }

    return result;
}

fn glibcVerFromLinkName(link_name: []const u8, prefix: []const u8) error{ UnrecognizedGnuLibCFileName, InvalidGnuLibCVersion }!std.SemanticVersion {
    // example: "libc-2.3.4.so"
    // example: "libc-2.27.so"
    // example: "ld-2.33.so"
    const suffix = ".so";
    if (!mem.startsWith(u8, link_name, prefix) or !mem.endsWith(u8, link_name, suffix)) {
        return error.UnrecognizedGnuLibCFileName;
    }
    // chop off "libc-" and ".so"
    const link_name_chopped = link_name[prefix.len .. link_name.len - suffix.len];
    return Target.Query.parseVersion(link_name_chopped) catch |err| switch (err) {
        error.Overflow => return error.InvalidGnuLibCVersion,
        error.InvalidVersion => return error.InvalidGnuLibCVersion,
    };
}

test glibcVerFromLinkName {
    try std.testing.expectError(error.UnrecognizedGnuLibCFileName, glibcVerFromLinkName("ld-2.37.so", "this-prefix-does-not-exist"));
    try std.testing.expectError(error.UnrecognizedGnuLibCFileName, glibcVerFromLinkName("libc-2.37.so-is-not-end", "libc-"));

    try std.testing.expectError(error.InvalidGnuLibCVersion, glibcVerFromLinkName("ld-2.so", "ld-"));
    try std.testing.expectEqual(std.SemanticVersion{ .major = 2, .minor = 37, .patch = 0 }, try glibcVerFromLinkName("ld-2.37.so", "ld-"));
    try std.testing.expectEqual(std.SemanticVersion{ .major = 2, .minor = 37, .patch = 0 }, try glibcVerFromLinkName("ld-2.37.0.so", "ld-"));
    try std.testing.expectEqual(std.SemanticVersion{ .major = 2, .minor = 37, .patch = 1 }, try glibcVerFromLinkName("ld-2.37.1.so", "ld-"));
    try std.testing.expectError(error.InvalidGnuLibCVersion, glibcVerFromLinkName("ld-2.37.4.5.so", "ld-"));
}

fn glibcVerFromRPath(io: Io, rpath: []const u8) !std.SemanticVersion {
    var dir = fs.cwd().openDir(rpath, .{}) catch |err| switch (err) {
        error.NameTooLong => return error.Unexpected,
        error.BadPathName => return error.Unexpected,
        error.DeviceBusy => return error.Unexpected,
        error.NetworkNotFound => return error.Unexpected, // Windows-only

        error.FileNotFound => return error.GLibCNotFound,
        error.NotDir => return error.GLibCNotFound,
        error.AccessDenied => return error.GLibCNotFound,
        error.PermissionDenied => return error.GLibCNotFound,
        error.NoDevice => return error.GLibCNotFound,

        error.ProcessFdQuotaExceeded => |e| return e,
        error.SystemFdQuotaExceeded => |e| return e,
        error.SystemResources => |e| return e,
        error.SymLinkLoop => |e| return e,
        error.Unexpected => |e| return e,
        error.Canceled => |e| return e,
    };
    defer dir.close();

    // Now we have a candidate for the path to libc shared object. In
    // the past, we used readlink() here because the link name would
    // reveal the glibc version. However, in more recent GNU/Linux
    // installations, there is no symlink. Thus we instead use a more
    // robust check of opening the libc shared object and looking at the
    // .dynstr section, and finding the max version number of symbols
    // that start with "GLIBC_2.".
    const glibc_so_basename = "libc.so.6";
    var file = dir.openFile(glibc_so_basename, .{}) catch |err| switch (err) {
        error.NameTooLong => return error.Unexpected,
        error.BadPathName => return error.Unexpected,
        error.PipeBusy => return error.Unexpected, // Windows-only
        error.SharingViolation => return error.Unexpected, // Windows-only
        error.NetworkNotFound => return error.Unexpected, // Windows-only
        error.AntivirusInterference => return error.Unexpected, // Windows-only
        error.FileLocksNotSupported => return error.Unexpected, // No lock requested.
        error.NoSpaceLeft => return error.Unexpected, // read-only
        error.PathAlreadyExists => return error.Unexpected, // read-only
        error.DeviceBusy => return error.Unexpected, // read-only
        error.FileBusy => return error.Unexpected, // read-only
        error.NoDevice => return error.Unexpected, // not asking for a special device
        error.FileTooBig => return error.Unexpected,
        error.WouldBlock => return error.Unexpected, // not opened in non-blocking

        error.AccessDenied => return error.GLibCNotFound,
        error.PermissionDenied => return error.GLibCNotFound,
        error.FileNotFound => return error.GLibCNotFound,
        error.NotDir => return error.GLibCNotFound,
        error.IsDir => return error.GLibCNotFound,

        error.ProcessNotFound => |e| return e,
        error.ProcessFdQuotaExceeded => |e| return e,
        error.SystemFdQuotaExceeded => |e| return e,
        error.SystemResources => |e| return e,
        error.SymLinkLoop => |e| return e,
        error.Unexpected => |e| return e,
        error.Canceled => |e| return e,
    };
    defer file.close();

    // Empirically, glibc 2.34 libc.so .dynstr section is 32441 bytes on my system.
    var buffer: [8000]u8 = undefined;
    var file_reader: Io.File.Reader = .initAdapted(file, io, &buffer);

    return glibcVerFromSoFile(&file_reader) catch |err| switch (err) {
        error.InvalidElfMagic,
        error.InvalidElfEndian,
        error.InvalidElfClass,
        error.InvalidElfVersion,
        error.InvalidGnuLibCVersion,
        error.EndOfStream,
        => return error.GLibCNotFound,

        error.ReadFailed => return file_reader.err.?,
        else => |e| return e,
    };
}

fn glibcVerFromSoFile(file_reader: *Io.File.Reader) !std.SemanticVersion {
    const header = try elf.Header.read(&file_reader.interface);
    const str_section_off = header.shoff + @as(u64, header.shentsize) * @as(u64, header.shstrndx);
    try file_reader.seekTo(str_section_off);
    const shstr = try elf.takeSectionHeader(&file_reader.interface, header.is_64, header.endian);
    var strtab_buf: [4096]u8 = undefined;
    const shstrtab = strtab_buf[0..@min(shstr.sh_size, strtab_buf.len)];
    try file_reader.seekTo(shstr.sh_offset);
    try file_reader.interface.readSliceAll(shstrtab);
    const dynstr: struct { offset: u64, size: u64 } = find_dyn_str: {
        var it = header.iterateSectionHeaders(file_reader);
        while (try it.next()) |shdr| {
            const end = mem.findScalarPos(u8, shstrtab, shdr.sh_name, 0) orelse continue;
            const sh_name = shstrtab[shdr.sh_name..end :0];
            if (mem.eql(u8, sh_name, ".dynstr")) break :find_dyn_str .{
                .offset = shdr.sh_offset,
                .size = shdr.sh_size,
            };
        } else return error.InvalidGnuLibCVersion;
    };

    // Here we loop over all the strings in the dynstr string table, assuming that any
    // strings that start with "GLIBC_2." indicate the existence of such a glibc version,
    // and furthermore, that the system-installed glibc is at minimum that version.
    var max_ver: std.SemanticVersion = .{ .major = 2, .minor = 2, .patch = 5 };
    var offset: u64 = 0;
    try file_reader.seekTo(dynstr.offset);
    while (offset < dynstr.size) {
        if (file_reader.interface.takeSentinel(0)) |s| {
            if (mem.startsWith(u8, s, "GLIBC_2.")) {
                const chopped = s["GLIBC_".len..];
                const ver = Target.Query.parseVersion(chopped) catch |err| switch (err) {
                    error.Overflow => return error.InvalidGnuLibCVersion,
                    error.InvalidVersion => return error.InvalidGnuLibCVersion,
                };
                switch (ver.order(max_ver)) {
                    .gt => max_ver = ver,
                    .lt, .eq => continue,
                }
            }
            offset += s.len + 1;
        } else |err| switch (err) {
            error.EndOfStream, error.StreamTooLong => break,
            error.ReadFailed => |e| return e,
        }
    }

    return max_ver;
}

/// In the past, this function attempted to use the executable's own binary if it was dynamically
/// linked to answer both the C ABI question and the dynamic linker question. However, this
/// could be problematic on a system that uses a RUNPATH for the compiler binary, locking
/// it to an older glibc version, while system binaries such as /usr/bin/env use a newer glibc
/// version. The problem is that libc.so.6 glibc version will match that of the system while
/// the dynamic linker will match that of the compiler binary. Executables with these versions
/// mismatching will fail to run.
///
/// Therefore, this function works the same regardless of whether the compiler binary is
/// dynamically or statically linked. It inspects `/usr/bin/env` as an ELF file to find the
/// answer to these questions, or if there is a shebang line, then it chases the referenced
/// file recursively. If that does not provide the answer, then the function falls back to
/// defaults.
fn detectAbiAndDynamicLinker(io: Io, cpu: Target.Cpu, os: Target.Os, query: Target.Query) !Target {
    const native_target_has_ld = comptime Target.DynamicLinker.kind(builtin.os.tag) != .none;
    const is_linux = builtin.target.os.tag == .linux;
    const is_illumos = builtin.target.os.tag == .illumos;
    const is_darwin = builtin.target.os.tag.isDarwin();
    const have_all_info = query.dynamic_linker != null and
        query.abi != null and (!is_linux or query.abi.?.isGnu());
    const os_is_non_native = query.os_tag != null;
    // The illumos environment is always the same.
    if (!native_target_has_ld or have_all_info or os_is_non_native or is_illumos or is_darwin) {
        return defaultAbiAndDynamicLinker(cpu, os, query);
    }
    if (query.abi) |abi| {
        if (abi.isMusl()) {
            // musl implies static linking.
            return defaultAbiAndDynamicLinker(cpu, os, query);
        }
    }
    // The current target's ABI cannot be relied on for this. For example, we may build the zig
    // compiler for target riscv64-linux-musl and provide a tarball for users to download.
    // A user could then run that zig compiler on riscv64-linux-gnu. This use case is well-defined
    // and supported by Zig. But that means that we must detect the system ABI here rather than
    // relying on `builtin.target`.
    const all_abis = comptime blk: {
        assert(@intFromEnum(Target.Abi.none) == 0);
        const fields = std.meta.fields(Target.Abi)[1..];
        var array: [fields.len]Target.Abi = undefined;
        for (fields, 0..) |field, i| {
            array[i] = @field(Target.Abi, field.name);
        }
        break :blk array;
    };
    var ld_info_list_buffer: [all_abis.len]LdInfo = undefined;
    var ld_info_list_len: usize = 0;

    switch (Target.DynamicLinker.kind(os.tag)) {
        // The OS has no dynamic linker. Leave the list empty and rely on `Abi.default()` to pick
        // something sensible in `abiAndDynamicLinkerFromFile()`.
        .none => {},
        // The OS has a system-wide dynamic linker. Unfortunately, this implies that there's no
        // useful ABI information that we can glean from it merely being present. That means the
        // best we can do for this case (for now) is also `Abi.default()`.
        .arch_os => {},
        // The OS can have different dynamic linker paths depending on libc/ABI. In this case, we
        // need to gather all the valid arch/OS/ABI combinations. `abiAndDynamicLinkerFromFile()`
        // will then look for a dynamic linker with a matching path on the system and pick the ABI
        // we associated it with here.
        .arch_os_abi => for (all_abis) |abi| {
            const ld = Target.DynamicLinker.standard(cpu, os, abi);

            // Does the generated target triple actually have a standard dynamic linker path?
            if (ld.get() == null) continue;

            ld_info_list_buffer[ld_info_list_len] = .{
                .ld = ld,
                .abi = abi,
            };
            ld_info_list_len += 1;
        },
    }

    const ld_info_list = ld_info_list_buffer[0..ld_info_list_len];

    var file_reader: Io.File.Reader = undefined;
    // According to `man 2 execve`:
    //
    // The kernel imposes a maximum length on the text
    // that follows the "#!" characters at the start of a script;
    // characters beyond the limit are ignored.
    // Before Linux 5.1, the limit is 127 characters.
    // Since Linux 5.1, the limit is 255 characters.
    //
    // Tests show that bash and zsh consider 255 as total limit,
    // *including* "#!" characters and ignoring newline.
    // For safety, we set max length as 255 + \n (1).
    const max_shebang_line_size = 256;
    var file_reader_buffer: [4096]u8 = undefined;
    comptime assert(file_reader_buffer.len >= max_shebang_line_size);

    // Best case scenario: the executable is dynamically linked, and we can iterate
    // over our own shared objects and find a dynamic linker.
    const header = elf_file: {
        // This block looks for a shebang line in "/usr/bin/env". If it finds
        // one, then instead of using "/usr/bin/env" as the ELF file to examine,
        // it uses the file it references instead, doing the same logic
        // recursively in case it finds another shebang line.

        var file_name: []const u8 = switch (os.tag) {
            // Since /usr/bin/env is hard-coded into the shebang line of many
            // portable scripts, it's a reasonably reliable path to start with.
            else => "/usr/bin/env",
            // Haiku does not have a /usr root directory.
            .haiku => "/bin/env",
        };

        while (true) {
            const file = fs.openFileAbsolute(file_name, .{}) catch |err| switch (err) {
                error.NoSpaceLeft => return error.Unexpected,
                error.NameTooLong => return error.Unexpected,
                error.PathAlreadyExists => return error.Unexpected,
                error.SharingViolation => return error.Unexpected,
                error.BadPathName => return error.Unexpected,
                error.PipeBusy => return error.Unexpected,
                error.FileLocksNotSupported => return error.Unexpected,
                error.FileBusy => return error.Unexpected, // opened without write permissions
                error.AntivirusInterference => return error.Unexpected, // Windows-only error

                error.IsDir,
                error.NotDir,
                error.AccessDenied,
                error.PermissionDenied,
                error.NoDevice,
                error.FileNotFound,
                error.NetworkNotFound,
                error.FileTooBig,
                error.Unexpected,
                => return error.UnableToOpenElfFile,

                else => |e| return e,
            };
            var is_elf_file = false;
            defer if (!is_elf_file) file.close();

            file_reader = .initAdapted(file, io, &file_reader_buffer);
            file_name = undefined; // it aliases file_reader_buffer

            const header = elf.Header.read(&file_reader.interface) catch |hdr_err| switch (hdr_err) {
                error.EndOfStream,
                error.InvalidElfMagic,
                => {
                    const shebang_line = file_reader.interface.takeSentinel('\n') catch |err| switch (err) {
                        error.ReadFailed => return file_reader.err.?,
                        // It's neither an ELF file nor file with shebang line.
                        error.EndOfStream, error.StreamTooLong => return error.UnhelpfulFile,
                    };
                    if (!mem.startsWith(u8, shebang_line, "#!")) return error.UnhelpfulFile;
                    // We detected shebang, now parse entire line.

                    // Trim leading "#!", spaces and tabs.
                    const trimmed_line = mem.trimStart(u8, shebang_line[2..], &.{ ' ', '\t' });

                    // This line can have:
                    // * Interpreter path only,
                    // * Interpreter path and arguments, all separated by space, tab or NUL character.
                    // And optionally newline at the end.
                    const path_maybe_args = mem.trimEnd(u8, trimmed_line, "\n");

                    // Separate path and args.
                    const path_end = mem.indexOfAny(u8, path_maybe_args, &.{ ' ', '\t', 0 }) orelse path_maybe_args.len;
                    const unvalidated_path = path_maybe_args[0..path_end];
                    file_name = if (fs.path.isAbsolute(unvalidated_path)) unvalidated_path else return error.RelativeShebang;
                    continue;
                },

                error.InvalidElfVersion,
                error.InvalidElfClass,
                error.InvalidElfEndian,
                => return error.InvalidElfFile,

                error.ReadFailed => return file_reader.err.?,
            };
            is_elf_file = true;
            break :elf_file header;
        }
    };
    defer file_reader.file.close(io);

    return abiAndDynamicLinkerFromFile(&file_reader, &header, cpu, os, ld_info_list, query) catch |err| switch (err) {
        error.FileSystem,
        error.SystemResources,
        error.SymLinkLoop,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        error.ProcessNotFound,
        error.Canceled,
        => |e| return e,

        error.ReadFailed => return file_reader.err.?,

        else => |e| {
            std.log.warn("encountered {t}; falling back to default ABI and dynamic linker", .{e});
            return defaultAbiAndDynamicLinker(cpu, os, query);
        },
    };
}

fn defaultAbiAndDynamicLinker(cpu: Target.Cpu, os: Target.Os, query: Target.Query) Target {
    const abi = query.abi orelse Target.Abi.default(cpu.arch, os.tag);
    return .{
        .cpu = cpu,
        .os = os,
        .abi = abi,
        .ofmt = query.ofmt orelse Target.ObjectFormat.default(os.tag, cpu.arch),
        .dynamic_linker = query.dynamic_linker orelse .standard(cpu, os, abi),
    };
}

const LdInfo = struct {
    ld: Target.DynamicLinker,
    abi: Target.Abi,
};

test {
    _ = NativePaths;

    _ = darwin;
    _ = linux;
    _ = windows;
}
