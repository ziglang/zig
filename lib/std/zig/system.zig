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
    host: std.Target,
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
        host.os.tag == .macos and host.cpu.arch == .aarch64)
    {
        switch (candidate.cpu.arch) {
            .x86_64 => return .rosetta,
            else => return bad_result,
        }
    }

    // If the OS matches, we can use QEMU to emulate a foreign architecture.
    if (options.allow_qemu and os_match and (!cpu_ok or options.qemu_fixes_dl)) {
        return switch (candidate.cpu.arch) {
            .aarch64 => Executor{ .qemu = "qemu-aarch64" },
            .aarch64_be => Executor{ .qemu = "qemu-aarch64_be" },
            .arm => Executor{ .qemu = "qemu-arm" },
            .armeb => Executor{ .qemu = "qemu-armeb" },
            .hexagon => Executor{ .qemu = "qemu-hexagon" },
            .loongarch64 => Executor{ .qemu = "qemu-loongarch64" },
            .m68k => Executor{ .qemu = "qemu-m68k" },
            .mips => Executor{ .qemu = "qemu-mips" },
            .mipsel => Executor{ .qemu = "qemu-mipsel" },
            .mips64 => Executor{
                .qemu = if (candidate.abi == .gnuabin32)
                    "qemu-mipsn32"
                else
                    "qemu-mips64",
            },
            .mips64el => Executor{
                .qemu = if (candidate.abi == .gnuabin32)
                    "qemu-mipsn32el"
                else
                    "qemu-mips64el",
            },
            .powerpc => Executor{ .qemu = "qemu-ppc" },
            .powerpc64 => Executor{ .qemu = "qemu-ppc64" },
            .powerpc64le => Executor{ .qemu = "qemu-ppc64le" },
            .riscv32 => Executor{ .qemu = "qemu-riscv32" },
            .riscv64 => Executor{ .qemu = "qemu-riscv64" },
            .s390x => Executor{ .qemu = "qemu-s390x" },
            .sparc => Executor{
                .qemu = if (std.Target.sparc.featureSetHas(candidate.cpu.features, .v9))
                    "qemu-sparc32plus"
                else
                    "qemu-sparc",
            },
            .sparc64 => Executor{ .qemu = "qemu-sparc64" },
            .x86 => Executor{ .qemu = "qemu-i386" },
            .x86_64 => Executor{ .qemu = "qemu-x86_64" },
            .xtensa => Executor{ .qemu = "qemu-xtensa" },
            else => return bad_result,
        };
    }

    switch (candidate.os.tag) {
        .windows => {
            if (options.allow_wine) {
                // x86_64 wine does not support emulating aarch64-windows and
                // vice versa.
                if (candidate.cpu.arch != builtin.cpu.arch) {
                    return bad_result;
                }
                switch (candidate.ptrBitWidth()) {
                    32 => return Executor{ .wine = "wine" },
                    64 => return Executor{ .wine = "wine64" },
                    else => return bad_result,
                }
            }
            return bad_result;
        },
        .wasi => {
            if (options.allow_wasmtime) {
                switch (candidate.ptrBitWidth()) {
                    32 => return Executor{ .wasmtime = "wasmtime" },
                    else => return bad_result,
                }
            }
            return bad_result;
        },
        .macos => {
            if (options.allow_darling) {
                // This check can be loosened once darling adds a QEMU-based emulation
                // layer for non-host architectures:
                // https://github.com/darlinghq/darling/issues/863
                if (candidate.cpu.arch != builtin.cpu.arch) {
                    return bad_result;
                }
                return Executor{ .darling = "darling" };
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
};

/// Given a `Target.Query`, which specifies in detail which parts of the
/// target should be detected natively, which should be standard or default,
/// and which are provided explicitly, this function resolves the native
/// components by detecting the native system, and then resolves
/// standard/default parts relative to that.
pub fn resolveTargetQuery(query: Target.Query) DetectError!Target {
    const query_os_tag = query.os_tag orelse builtin.os.tag;
    var os = query_os_tag.defaultVersionRange(query.cpu_arch orelse builtin.cpu.arch);
    if (query.os_tag == null) {
        switch (builtin.target.os.tag) {
            .linux => {
                const uts = posix.uname();
                const release = mem.sliceTo(&uts.release, 0);
                // The release field sometimes has a weird format,
                // `Version.parse` will attempt to find some meaningful interpretation.
                if (std.SemanticVersion.parse(release)) |ver| {
                    os.version_range.linux.range.min = ver;
                    os.version_range.linux.range.max = ver;
                } else |err| switch (err) {
                    error.Overflow => {},
                    error.InvalidVersion => {},
                }
            },
            .solaris, .illumos => {
                const uts = posix.uname();
                const release = mem.sliceTo(&uts.release, 0);
                if (std.SemanticVersion.parse(release)) |ver| {
                    os.version_range.semver.min = ver;
                    os.version_range.semver.max = ver;
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
                    error.NameTooLong => unreachable, // constant, known good value
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
                var buf: [64]u8 = undefined;
                // consider that sysctl result includes null-termination
                // reserve 1 byte to ensure we never overflow when appending ".0"
                var len: usize = buf.len - 1;

                posix.sysctl(&mib, &buf, &len, null, 0) catch |err| switch (err) {
                    error.NameTooLong => unreachable, // constant, known good value
                    error.PermissionDenied => unreachable, // only when setting values,
                    error.SystemResources => unreachable, // memory already on the stack
                    error.UnknownName => unreachable, // constant, known good value
                    error.Unexpected => return error.OSVersionDetectionFail,
                };

                // append ".0" to satisfy semver
                buf[len - 1] = '.';
                buf[len] = '0';
                len += 1;

                if (std.SemanticVersion.parse(buf[0..len])) |ver| {
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
        .semver => |semver| switch (os.tag) {
            .linux => os.version_range.linux.range.min = semver,
            else => os.version_range.semver.min = semver,
        },
        .windows => |win_ver| os.version_range.windows.min = win_ver,
    };

    if (query.os_version_max) |max| switch (max) {
        .none => {},
        .semver => |semver| switch (os.tag) {
            .linux => os.version_range.linux.range.max = semver,
            else => os.version_range.semver.max = semver,
        },
        .windows => |win_ver| os.version_range.windows.max = win_ver,
    };

    if (query.glibc_version) |glibc| {
        os.version_range.linux.glibc = glibc;
    }

    // Until https://github.com/ziglang/zig/issues/4592 is implemented (support detecting the
    // native CPU architecture as being different than the current target), we use this:
    const cpu_arch = query.cpu_arch orelse builtin.cpu.arch;

    const cpu = switch (query.cpu_model) {
        .native => detectNativeCpuAndFeatures(cpu_arch, os, query),
        .baseline => Target.Cpu.baseline(cpu_arch),
        .determined_by_cpu_arch => if (query.cpu_arch == null)
            detectNativeCpuAndFeatures(cpu_arch, os, query)
        else
            Target.Cpu.baseline(cpu_arch),
        .explicit => |model| model.toCpu(cpu_arch),
    } orelse backup_cpu_detection: {
        break :backup_cpu_detection Target.Cpu.baseline(cpu_arch);
    };
    var result = try detectAbiAndDynamicLinker(cpu, os, query);
    // For x86, we need to populate some CPU feature flags depending on architecture
    // and mode:
    //  * 16bit_mode => if the abi is code16
    //  * 32bit_mode => if the arch is x86
    // However, the "mode" flags can be used as overrides, so if the user explicitly
    // sets one of them, that takes precedence.
    switch (cpu_arch) {
        .x86 => {
            if (!Target.x86.featureSetHasAny(query.cpu_features_add, .{
                .@"16bit_mode", .@"32bit_mode",
            })) {
                switch (result.abi) {
                    .code16 => result.cpu.features.addFeature(
                        @intFromEnum(Target.x86.Feature.@"16bit_mode"),
                    ),
                    else => result.cpu.features.addFeature(
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
            result.cpu.features.addFeature(
                @intFromEnum(Target.arm.Feature.thumb_mode),
            );
        },
        else => {},
    }
    updateCpuFeatures(
        &result.cpu.features,
        cpu_arch.allFeaturesList(),
        query.cpu_features_add,
        query.cpu_features_sub,
    );

    if (cpu_arch == .hexagon) {
        // Both LLVM and LLD have broken support for the small data area. Yet LLVM has the feature
        // on by default for all Hexagon CPUs. Clang sort of solves this by defaulting the `-gpsize`
        // command line parameter for the Hexagon backend to 0, so that no constants get placed in
        // the SDA. (This of course breaks down if the user passes `-G <n>` to Clang...) We can't do
        // the `-gpsize` hack because we can have multiple concurrent LLVM emit jobs, and command
        // line options in LLVM are shared globally. So just force this feature off. Lovely stuff.
        result.cpu.features.removeFeature(@intFromEnum(Target.hexagon.Feature.small_data));
    }

    // https://github.com/llvm/llvm-project/issues/105978
    if (result.cpu.arch.isArmOrThumb() and result.floatAbi() == .soft) {
        result.cpu.features.removeFeature(@intFromEnum(Target.arm.Feature.vfp2));
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

fn detectNativeCpuAndFeatures(cpu_arch: Target.Cpu.Arch, os: Target.Os, query: Target.Query) ?Target.Cpu {
    // Here we switch on a comptime value rather than `cpu_arch`. This is valid because `cpu_arch`,
    // although it is a runtime value, is guaranteed to be one of the architectures in the set
    // of the respective switch prong.
    switch (builtin.cpu.arch) {
        .x86_64, .x86 => {
            return @import("system/x86.zig").detectNativeCpuAndFeatures(cpu_arch, os, query);
        },
        else => {},
    }

    switch (builtin.os.tag) {
        .linux => return linux.detectNativeCpuAndFeatures(),
        .macos => return darwin.macos.detectNativeCpuAndFeatures(),
        .windows => return windows.detectNativeCpuAndFeatures(),
        else => {},
    }

    // This architecture does not have CPU model & feature detection yet.
    // See https://github.com/ziglang/zig/issues/4591
    return null;
}

pub const AbiAndDynamicLinkerFromFileError = error{
    FileSystem,
    SystemResources,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    UnableToReadElfFile,
    InvalidElfClass,
    InvalidElfVersion,
    InvalidElfEndian,
    InvalidElfFile,
    InvalidElfMagic,
    Unexpected,
    UnexpectedEndOfFile,
    NameTooLong,
    ProcessNotFound,
};

pub fn abiAndDynamicLinkerFromFile(
    file: fs.File,
    cpu: Target.Cpu,
    os: Target.Os,
    ld_info_list: []const LdInfo,
    query: Target.Query,
) AbiAndDynamicLinkerFromFileError!Target {
    var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 align(@alignOf(elf.Elf64_Ehdr)) = undefined;
    _ = try preadAtLeast(file, &hdr_buf, 0, hdr_buf.len);
    const hdr32: *elf.Elf32_Ehdr = @ptrCast(&hdr_buf);
    const hdr64: *elf.Elf64_Ehdr = @ptrCast(&hdr_buf);
    if (!mem.eql(u8, hdr32.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
    const elf_endian: std.builtin.Endian = switch (hdr32.e_ident[elf.EI_DATA]) {
        elf.ELFDATA2LSB => .little,
        elf.ELFDATA2MSB => .big,
        else => return error.InvalidElfEndian,
    };
    const need_bswap = elf_endian != native_endian;
    if (hdr32.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

    const is_64 = switch (hdr32.e_ident[elf.EI_CLASS]) {
        elf.ELFCLASS32 => false,
        elf.ELFCLASS64 => true,
        else => return error.InvalidElfClass,
    };
    var phoff = elfInt(is_64, need_bswap, hdr32.e_phoff, hdr64.e_phoff);
    const phentsize = elfInt(is_64, need_bswap, hdr32.e_phentsize, hdr64.e_phentsize);
    const phnum = elfInt(is_64, need_bswap, hdr32.e_phnum, hdr64.e_phnum);

    var result: Target = .{
        .cpu = cpu,
        .os = os,
        .abi = query.abi orelse Target.Abi.default(cpu.arch, os),
        .ofmt = query.ofmt orelse Target.ObjectFormat.default(os.tag, cpu.arch),
        .dynamic_linker = query.dynamic_linker,
    };
    var rpath_offset: ?u64 = null; // Found inside PT_DYNAMIC
    const look_for_ld = query.dynamic_linker.get() == null;

    var ph_buf: [16 * @sizeOf(elf.Elf64_Phdr)]u8 align(@alignOf(elf.Elf64_Phdr)) = undefined;
    if (phentsize > @sizeOf(elf.Elf64_Phdr)) return error.InvalidElfFile;

    var ph_i: u16 = 0;
    while (ph_i < phnum) {
        // Reserve some bytes so that we can deref the 64-bit struct fields
        // even when the ELF file is 32-bits.
        const ph_reserve: usize = @sizeOf(elf.Elf64_Phdr) - @sizeOf(elf.Elf32_Phdr);
        const ph_read_byte_len = try preadAtLeast(file, ph_buf[0 .. ph_buf.len - ph_reserve], phoff, phentsize);
        var ph_buf_i: usize = 0;
        while (ph_buf_i < ph_read_byte_len and ph_i < phnum) : ({
            ph_i += 1;
            phoff += phentsize;
            ph_buf_i += phentsize;
        }) {
            const ph32: *elf.Elf32_Phdr = @ptrCast(@alignCast(&ph_buf[ph_buf_i]));
            const ph64: *elf.Elf64_Phdr = @ptrCast(@alignCast(&ph_buf[ph_buf_i]));
            const p_type = elfInt(is_64, need_bswap, ph32.p_type, ph64.p_type);
            switch (p_type) {
                elf.PT_INTERP => if (look_for_ld) {
                    const p_offset = elfInt(is_64, need_bswap, ph32.p_offset, ph64.p_offset);
                    const p_filesz = elfInt(is_64, need_bswap, ph32.p_filesz, ph64.p_filesz);
                    if (p_filesz > result.dynamic_linker.buffer.len) return error.NameTooLong;
                    const filesz: usize = @intCast(p_filesz);
                    _ = try preadAtLeast(file, result.dynamic_linker.buffer[0..filesz], p_offset, filesz);
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
                },
                // We only need this for detecting glibc version.
                elf.PT_DYNAMIC => if (builtin.target.os.tag == .linux and result.isGnuLibC() and
                    query.glibc_version == null)
                {
                    var dyn_off = elfInt(is_64, need_bswap, ph32.p_offset, ph64.p_offset);
                    const p_filesz = elfInt(is_64, need_bswap, ph32.p_filesz, ph64.p_filesz);
                    const dyn_size: usize = if (is_64) @sizeOf(elf.Elf64_Dyn) else @sizeOf(elf.Elf32_Dyn);
                    const dyn_num = p_filesz / dyn_size;
                    var dyn_buf: [16 * @sizeOf(elf.Elf64_Dyn)]u8 align(@alignOf(elf.Elf64_Dyn)) = undefined;
                    var dyn_i: usize = 0;
                    dyn: while (dyn_i < dyn_num) {
                        // Reserve some bytes so that we can deref the 64-bit struct fields
                        // even when the ELF file is 32-bits.
                        const dyn_reserve: usize = @sizeOf(elf.Elf64_Dyn) - @sizeOf(elf.Elf32_Dyn);
                        const dyn_read_byte_len = try preadAtLeast(
                            file,
                            dyn_buf[0 .. dyn_buf.len - dyn_reserve],
                            dyn_off,
                            dyn_size,
                        );
                        var dyn_buf_i: usize = 0;
                        while (dyn_buf_i < dyn_read_byte_len and dyn_i < dyn_num) : ({
                            dyn_i += 1;
                            dyn_off += dyn_size;
                            dyn_buf_i += dyn_size;
                        }) {
                            const dyn32: *elf.Elf32_Dyn = @ptrCast(@alignCast(&dyn_buf[dyn_buf_i]));
                            const dyn64: *elf.Elf64_Dyn = @ptrCast(@alignCast(&dyn_buf[dyn_buf_i]));
                            const tag = elfInt(is_64, need_bswap, dyn32.d_tag, dyn64.d_tag);
                            const val = elfInt(is_64, need_bswap, dyn32.d_val, dyn64.d_val);
                            if (tag == elf.DT_RUNPATH) {
                                rpath_offset = val;
                                break :dyn;
                            }
                        }
                    }
                },
                else => continue,
            }
        }
    }

    if (builtin.target.os.tag == .linux and result.isGnuLibC() and
        query.glibc_version == null)
    {
        const shstrndx = elfInt(is_64, need_bswap, hdr32.e_shstrndx, hdr64.e_shstrndx);

        var shoff = elfInt(is_64, need_bswap, hdr32.e_shoff, hdr64.e_shoff);
        const shentsize = elfInt(is_64, need_bswap, hdr32.e_shentsize, hdr64.e_shentsize);
        const str_section_off = shoff + @as(u64, shentsize) * @as(u64, shstrndx);

        var sh_buf: [16 * @sizeOf(elf.Elf64_Shdr)]u8 align(@alignOf(elf.Elf64_Shdr)) = undefined;
        if (sh_buf.len < shentsize) return error.InvalidElfFile;

        _ = try preadAtLeast(file, &sh_buf, str_section_off, shentsize);
        const shstr32: *elf.Elf32_Shdr = @ptrCast(@alignCast(&sh_buf));
        const shstr64: *elf.Elf64_Shdr = @ptrCast(@alignCast(&sh_buf));
        const shstrtab_off = elfInt(is_64, need_bswap, shstr32.sh_offset, shstr64.sh_offset);
        const shstrtab_size = elfInt(is_64, need_bswap, shstr32.sh_size, shstr64.sh_size);
        var strtab_buf: [4096:0]u8 = undefined;
        const shstrtab_len = @min(shstrtab_size, strtab_buf.len);
        const shstrtab_read_len = try preadAtLeast(file, &strtab_buf, shstrtab_off, shstrtab_len);
        const shstrtab = strtab_buf[0..shstrtab_read_len];

        const shnum = elfInt(is_64, need_bswap, hdr32.e_shnum, hdr64.e_shnum);
        var sh_i: u16 = 0;
        const dynstr: ?struct { offset: u64, size: u64 } = find_dyn_str: while (sh_i < shnum) {
            // Reserve some bytes so that we can deref the 64-bit struct fields
            // even when the ELF file is 32-bits.
            const sh_reserve: usize = @sizeOf(elf.Elf64_Shdr) - @sizeOf(elf.Elf32_Shdr);
            const sh_read_byte_len = try preadAtLeast(
                file,
                sh_buf[0 .. sh_buf.len - sh_reserve],
                shoff,
                shentsize,
            );
            var sh_buf_i: usize = 0;
            while (sh_buf_i < sh_read_byte_len and sh_i < shnum) : ({
                sh_i += 1;
                shoff += shentsize;
                sh_buf_i += shentsize;
            }) {
                const sh32: *elf.Elf32_Shdr = @ptrCast(@alignCast(&sh_buf[sh_buf_i]));
                const sh64: *elf.Elf64_Shdr = @ptrCast(@alignCast(&sh_buf[sh_buf_i]));
                const sh_name_off = elfInt(is_64, need_bswap, sh32.sh_name, sh64.sh_name);
                const sh_name = mem.sliceTo(shstrtab[sh_name_off..], 0);
                if (mem.eql(u8, sh_name, ".dynstr")) {
                    break :find_dyn_str .{
                        .offset = elfInt(is_64, need_bswap, sh32.sh_offset, sh64.sh_offset),
                        .size = elfInt(is_64, need_bswap, sh32.sh_size, sh64.sh_size),
                    };
                }
            }
        } else null;

        if (dynstr) |ds| {
            if (rpath_offset) |rpoff| {
                if (rpoff > ds.size) return error.InvalidElfFile;
                const rpoff_file = ds.offset + rpoff;
                const rp_max_size = ds.size - rpoff;

                const strtab_len = @min(rp_max_size, strtab_buf.len);
                const strtab_read_len = try preadAtLeast(file, &strtab_buf, rpoff_file, strtab_len);
                const strtab = strtab_buf[0..strtab_read_len];

                const rpath_list = mem.sliceTo(strtab, 0);
                var it = mem.tokenizeScalar(u8, rpath_list, ':');
                while (it.next()) |rpath| {
                    if (glibcVerFromRPath(rpath)) |ver| {
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
                if (glibcVerFromRPath(rpath)) |ver| {
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
                error.InvalidUtf8 => unreachable, // WASI only
                error.InvalidWtf8 => unreachable, // Windows only
                error.BadPathName => unreachable, // Windows only
                error.UnsupportedReparsePointType => unreachable, // Windows only
                error.NetworkNotFound => unreachable, // Windows only

                error.AccessDenied,
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
        if (glibcVerFromRPath(rpath)) |ver| {
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

fn glibcVerFromRPath(rpath: []const u8) !std.SemanticVersion {
    var dir = fs.cwd().openDir(rpath, .{}) catch |err| switch (err) {
        error.NameTooLong => unreachable,
        error.InvalidUtf8 => unreachable, // WASI only
        error.InvalidWtf8 => unreachable, // Windows-only
        error.BadPathName => unreachable,
        error.DeviceBusy => unreachable,
        error.NetworkNotFound => unreachable, // Windows-only

        error.FileNotFound,
        error.NotDir,
        error.AccessDenied,
        error.NoDevice,
        => return error.GLibCNotFound,

        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        error.SystemResources,
        error.SymLinkLoop,
        error.Unexpected,
        => |e| return e,
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
    var f = dir.openFile(glibc_so_basename, .{}) catch |err| switch (err) {
        error.NameTooLong => unreachable,
        error.InvalidUtf8 => unreachable, // WASI only
        error.InvalidWtf8 => unreachable, // Windows only
        error.BadPathName => unreachable, // Windows only
        error.PipeBusy => unreachable, // Windows-only
        error.SharingViolation => unreachable, // Windows-only
        error.NetworkNotFound => unreachable, // Windows-only
        error.AntivirusInterference => unreachable, // Windows-only
        error.FileLocksNotSupported => unreachable, // No lock requested.
        error.NoSpaceLeft => unreachable, // read-only
        error.PathAlreadyExists => unreachable, // read-only
        error.DeviceBusy => unreachable, // read-only
        error.FileBusy => unreachable, // read-only
        error.WouldBlock => unreachable, // not using O_NONBLOCK
        error.NoDevice => unreachable, // not asking for a special device

        error.AccessDenied,
        error.FileNotFound,
        error.NotDir,
        error.IsDir,
        => return error.GLibCNotFound,

        error.FileTooBig => return error.Unexpected,

        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        error.SystemResources,
        error.SymLinkLoop,
        error.Unexpected,
        => |e| return e,
    };
    defer f.close();

    return glibcVerFromSoFile(f) catch |err| switch (err) {
        error.InvalidElfMagic,
        error.InvalidElfEndian,
        error.InvalidElfClass,
        error.InvalidElfFile,
        error.InvalidElfVersion,
        error.InvalidGnuLibCVersion,
        error.UnexpectedEndOfFile,
        => return error.GLibCNotFound,

        error.SystemResources,
        error.UnableToReadElfFile,
        error.Unexpected,
        error.FileSystem,
        error.ProcessNotFound,
        => |e| return e,
    };
}

fn glibcVerFromSoFile(file: fs.File) !std.SemanticVersion {
    var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 align(@alignOf(elf.Elf64_Ehdr)) = undefined;
    _ = try preadAtLeast(file, &hdr_buf, 0, hdr_buf.len);
    const hdr32: *elf.Elf32_Ehdr = @ptrCast(&hdr_buf);
    const hdr64: *elf.Elf64_Ehdr = @ptrCast(&hdr_buf);
    if (!mem.eql(u8, hdr32.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
    const elf_endian: std.builtin.Endian = switch (hdr32.e_ident[elf.EI_DATA]) {
        elf.ELFDATA2LSB => .little,
        elf.ELFDATA2MSB => .big,
        else => return error.InvalidElfEndian,
    };
    const need_bswap = elf_endian != native_endian;
    if (hdr32.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

    const is_64 = switch (hdr32.e_ident[elf.EI_CLASS]) {
        elf.ELFCLASS32 => false,
        elf.ELFCLASS64 => true,
        else => return error.InvalidElfClass,
    };
    const shstrndx = elfInt(is_64, need_bswap, hdr32.e_shstrndx, hdr64.e_shstrndx);
    var shoff = elfInt(is_64, need_bswap, hdr32.e_shoff, hdr64.e_shoff);
    const shentsize = elfInt(is_64, need_bswap, hdr32.e_shentsize, hdr64.e_shentsize);
    const str_section_off = shoff + @as(u64, shentsize) * @as(u64, shstrndx);
    var sh_buf: [16 * @sizeOf(elf.Elf64_Shdr)]u8 align(@alignOf(elf.Elf64_Shdr)) = undefined;
    if (sh_buf.len < shentsize) return error.InvalidElfFile;

    _ = try preadAtLeast(file, &sh_buf, str_section_off, shentsize);
    const shstr32: *elf.Elf32_Shdr = @ptrCast(@alignCast(&sh_buf));
    const shstr64: *elf.Elf64_Shdr = @ptrCast(@alignCast(&sh_buf));
    const shstrtab_off = elfInt(is_64, need_bswap, shstr32.sh_offset, shstr64.sh_offset);
    const shstrtab_size = elfInt(is_64, need_bswap, shstr32.sh_size, shstr64.sh_size);
    var strtab_buf: [4096:0]u8 = undefined;
    const shstrtab_len = @min(shstrtab_size, strtab_buf.len);
    const shstrtab_read_len = try preadAtLeast(file, &strtab_buf, shstrtab_off, shstrtab_len);
    const shstrtab = strtab_buf[0..shstrtab_read_len];
    const shnum = elfInt(is_64, need_bswap, hdr32.e_shnum, hdr64.e_shnum);
    var sh_i: u16 = 0;
    const dynstr: struct { offset: u64, size: u64 } = find_dyn_str: while (sh_i < shnum) {
        // Reserve some bytes so that we can deref the 64-bit struct fields
        // even when the ELF file is 32-bits.
        const sh_reserve: usize = @sizeOf(elf.Elf64_Shdr) - @sizeOf(elf.Elf32_Shdr);
        const sh_read_byte_len = try preadAtLeast(
            file,
            sh_buf[0 .. sh_buf.len - sh_reserve],
            shoff,
            shentsize,
        );
        var sh_buf_i: usize = 0;
        while (sh_buf_i < sh_read_byte_len and sh_i < shnum) : ({
            sh_i += 1;
            shoff += shentsize;
            sh_buf_i += shentsize;
        }) {
            const sh32: *elf.Elf32_Shdr = @ptrCast(@alignCast(&sh_buf[sh_buf_i]));
            const sh64: *elf.Elf64_Shdr = @ptrCast(@alignCast(&sh_buf[sh_buf_i]));
            const sh_name_off = elfInt(is_64, need_bswap, sh32.sh_name, sh64.sh_name);
            const sh_name = mem.sliceTo(shstrtab[sh_name_off..], 0);
            if (mem.eql(u8, sh_name, ".dynstr")) {
                break :find_dyn_str .{
                    .offset = elfInt(is_64, need_bswap, sh32.sh_offset, sh64.sh_offset),
                    .size = elfInt(is_64, need_bswap, sh32.sh_size, sh64.sh_size),
                };
            }
        }
    } else return error.InvalidGnuLibCVersion;

    // Here we loop over all the strings in the dynstr string table, assuming that any
    // strings that start with "GLIBC_2." indicate the existence of such a glibc version,
    // and furthermore, that the system-installed glibc is at minimum that version.

    // Empirically, glibc 2.34 libc.so .dynstr section is 32441 bytes on my system.
    // Here I use double this value plus some headroom. This makes it only need
    // a single read syscall here.
    var buf: [80000]u8 = undefined;
    if (buf.len < dynstr.size) return error.InvalidGnuLibCVersion;

    const dynstr_size: usize = @intCast(dynstr.size);
    const dynstr_bytes = buf[0..dynstr_size];
    _ = try preadAtLeast(file, dynstr_bytes, dynstr.offset, dynstr_bytes.len);
    var it = mem.splitScalar(u8, dynstr_bytes, 0);
    var max_ver: std.SemanticVersion = .{ .major = 2, .minor = 2, .patch = 5 };
    while (it.next()) |s| {
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
fn detectAbiAndDynamicLinker(
    cpu: Target.Cpu,
    os: Target.Os,
    query: Target.Query,
) DetectError!Target {
    const native_target_has_ld = comptime builtin.target.hasDynamicLinker();
    const is_linux = builtin.target.os.tag == .linux;
    const is_solarish = builtin.target.os.tag.isSolarish();
    const have_all_info = query.dynamic_linker.get() != null and
        query.abi != null and (!is_linux or query.abi.?.isGnu());
    const os_is_non_native = query.os_tag != null;
    // The Solaris/illumos environment is always the same.
    if (!native_target_has_ld or have_all_info or os_is_non_native or is_solarish) {
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
    const ofmt = query.ofmt orelse Target.ObjectFormat.default(os.tag, cpu.arch);

    for (all_abis) |abi| {
        // This may be a nonsensical parameter. We detect this with
        // error.UnknownDynamicLinkerPath and skip adding it to `ld_info_list`.
        const target: Target = .{
            .cpu = cpu,
            .os = os,
            .abi = abi,
            .ofmt = ofmt,
        };
        const ld = target.standardDynamicLinkerPath();
        if (ld.get() == null) continue;

        ld_info_list_buffer[ld_info_list_len] = .{
            .ld = ld,
            .abi = abi,
        };
        ld_info_list_len += 1;
    }
    const ld_info_list = ld_info_list_buffer[0..ld_info_list_len];

    // Best case scenario: the executable is dynamically linked, and we can iterate
    // over our own shared objects and find a dynamic linker.
    const elf_file = elf_file: {
        // This block looks for a shebang line in /usr/bin/env,
        // if it finds one, then instead of using /usr/bin/env as the ELF file to examine, it uses the file it references instead,
        // doing the same logic recursively in case it finds another shebang line.

        var file_name: []const u8 = switch (os.tag) {
            // Since /usr/bin/env is hard-coded into the shebang line of many portable scripts, it's a
            // reasonably reliable path to start with.
            else => "/usr/bin/env",
            // Haiku does not have a /usr root directory.
            .haiku => "/bin/env",
        };

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
        var buffer: [255 + 1]u8 = undefined;
        while (true) {
            // Interpreter path can be relative on Linux, but
            // for simplicity we are asserting it is an absolute path.
            const file = fs.openFileAbsolute(file_name, .{}) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
                error.NameTooLong => unreachable,
                error.PathAlreadyExists => unreachable,
                error.SharingViolation => unreachable,
                error.InvalidUtf8 => unreachable, // WASI only
                error.InvalidWtf8 => unreachable, // Windows only
                error.BadPathName => unreachable,
                error.PipeBusy => unreachable,
                error.FileLocksNotSupported => unreachable,
                error.WouldBlock => unreachable,
                error.FileBusy => unreachable, // opened without write permissions
                error.AntivirusInterference => unreachable, // Windows-only error

                error.IsDir,
                error.NotDir,
                error.AccessDenied,
                error.NoDevice,
                error.FileNotFound,
                error.NetworkNotFound,
                error.FileTooBig,
                error.Unexpected,
                => |e| {
                    std.log.warn("Encountered error: {s}, falling back to default ABI and dynamic linker.", .{@errorName(e)});
                    return defaultAbiAndDynamicLinker(cpu, os, query);
                },

                else => |e| return e,
            };
            var is_elf_file = false;
            defer if (is_elf_file == false) file.close();

            // Shortest working interpreter path is "#!/i" (4)
            // (interpreter is "/i", assuming all paths are absolute, like in above comment).
            // ELF magic number length is also 4.
            //
            // If file is shorter than that, it is definitely not ELF file
            // nor file with "shebang" line.
            const min_len: usize = 4;

            const len = preadAtLeast(file, &buffer, 0, min_len) catch |err| switch (err) {
                error.UnexpectedEndOfFile,
                error.UnableToReadElfFile,
                error.ProcessNotFound,
                => return defaultAbiAndDynamicLinker(cpu, os, query),

                else => |e| return e,
            };
            const content = buffer[0..len];

            if (mem.eql(u8, content[0..4], std.elf.MAGIC)) {
                // It is very likely ELF file!
                is_elf_file = true;
                break :elf_file file;
            } else if (mem.eql(u8, content[0..2], "#!")) {
                // We detected shebang, now parse entire line.

                // Trim leading "#!", spaces and tabs.
                const trimmed_line = mem.trimLeft(u8, content[2..], &.{ ' ', '\t' });

                // This line can have:
                // * Interpreter path only,
                // * Interpreter path and arguments, all separated by space, tab or NUL character.
                // And optionally newline at the end.
                const path_maybe_args = mem.trimRight(u8, trimmed_line, "\n");

                // Separate path and args.
                const path_end = mem.indexOfAny(u8, path_maybe_args, &.{ ' ', '\t', 0 }) orelse path_maybe_args.len;

                file_name = path_maybe_args[0..path_end];
                continue;
            } else {
                // Not a ELF file, not a shell script with "shebang line", invalid duck.
                return defaultAbiAndDynamicLinker(cpu, os, query);
            }
        }
    };
    defer elf_file.close();

    // TODO: inline this function and combine the buffer we already read above to find
    // the possible shebang line with the buffer we use for the ELF header.
    return abiAndDynamicLinkerFromFile(elf_file, cpu, os, ld_info_list, query) catch |err| switch (err) {
        error.FileSystem,
        error.SystemResources,
        error.SymLinkLoop,
        error.ProcessFdQuotaExceeded,
        error.SystemFdQuotaExceeded,
        error.ProcessNotFound,
        => |e| return e,

        error.UnableToReadElfFile,
        error.InvalidElfClass,
        error.InvalidElfVersion,
        error.InvalidElfEndian,
        error.InvalidElfFile,
        error.InvalidElfMagic,
        error.Unexpected,
        error.UnexpectedEndOfFile,
        error.NameTooLong,
        // Finally, we fall back on the standard path.
        => |e| {
            std.log.warn("Encountered error: {s}, falling back to default ABI and dynamic linker.", .{@errorName(e)});
            return defaultAbiAndDynamicLinker(cpu, os, query);
        },
    };
}

fn defaultAbiAndDynamicLinker(cpu: Target.Cpu, os: Target.Os, query: Target.Query) Target {
    const abi = query.abi orelse Target.Abi.default(cpu.arch, os);
    return .{
        .cpu = cpu,
        .os = os,
        .abi = abi,
        .ofmt = query.ofmt orelse Target.ObjectFormat.default(os.tag, cpu.arch),
        .dynamic_linker = if (query.dynamic_linker.get() == null)
            Target.DynamicLinker.standard(cpu, os, abi)
        else
            query.dynamic_linker,
    };
}

const LdInfo = struct {
    ld: Target.DynamicLinker,
    abi: Target.Abi,
};

fn preadAtLeast(file: fs.File, buf: []u8, offset: u64, min_read_len: usize) !usize {
    var i: usize = 0;
    while (i < min_read_len) {
        const len = file.pread(buf[i..], offset + i) catch |err| switch (err) {
            error.OperationAborted => unreachable, // Windows-only
            error.WouldBlock => unreachable, // Did not request blocking mode
            error.Canceled => unreachable, // timerfd is unseekable
            error.NotOpenForReading => unreachable,
            error.SystemResources => return error.SystemResources,
            error.IsDir => return error.UnableToReadElfFile,
            error.BrokenPipe => return error.UnableToReadElfFile,
            error.Unseekable => return error.UnableToReadElfFile,
            error.ConnectionResetByPeer => return error.UnableToReadElfFile,
            error.ConnectionTimedOut => return error.UnableToReadElfFile,
            error.SocketNotConnected => return error.UnableToReadElfFile,
            error.Unexpected => return error.Unexpected,
            error.InputOutput => return error.FileSystem,
            error.AccessDenied => return error.Unexpected,
            error.ProcessNotFound => return error.ProcessNotFound,
            error.LockViolation => return error.UnableToReadElfFile,
        };
        if (len == 0) return error.UnexpectedEndOfFile;
        i += len;
    }
    return i;
}

fn elfInt(is_64: bool, need_bswap: bool, int_32: anytype, int_64: anytype) @TypeOf(int_64) {
    if (is_64) {
        if (need_bswap) {
            return @byteSwap(int_64);
        } else {
            return int_64;
        }
    } else {
        if (need_bswap) {
            return @byteSwap(int_32);
        } else {
            return int_32;
        }
    }
}

const builtin = @import("builtin");
const std = @import("../std.zig");
const mem = std.mem;
const elf = std.elf;
const fs = std.fs;
const assert = std.debug.assert;
const Target = std.Target;
const native_endian = builtin.cpu.arch.endian();
const posix = std.posix;

test {
    _ = NativePaths;

    _ = darwin;
    _ = linux;
    _ = windows;
}
