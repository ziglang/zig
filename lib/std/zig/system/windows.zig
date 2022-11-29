const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Target = std.Target;

pub const WindowsVersion = std.Target.Os.WindowsVersion;
pub const PF = std.os.windows.PF;
pub const REG = std.os.windows.REG;
pub const IsProcessorFeaturePresent = std.os.windows.IsProcessorFeaturePresent;

/// Returns the highest known WindowsVersion deduced from reported runtime information.
/// Discards information about in-between versions we don't differentiate.
pub fn detectRuntimeVersion() WindowsVersion {
    var version_info: std.os.windows.RTL_OSVERSIONINFOW = undefined;
    version_info.dwOSVersionInfoSize = @sizeOf(@TypeOf(version_info));

    switch (std.os.windows.ntdll.RtlGetVersion(&version_info)) {
        .SUCCESS => {},
        else => unreachable,
    }

    // Starting from the system infos build a NTDDI-like version
    // constant whose format is:
    //   B0 B1 B2 B3
    //   `---` `` ``--> Sub-version (Starting from Windows 10 onwards)
    //     \    `--> Service pack (Always zero in the constants defined)
    //      `--> OS version (Major & minor)
    const os_ver: u16 = @intCast(u16, version_info.dwMajorVersion & 0xff) << 8 |
        @intCast(u16, version_info.dwMinorVersion & 0xff);
    const sp_ver: u8 = 0;
    const sub_ver: u8 = if (os_ver >= 0x0A00) subver: {
        // There's no other way to obtain this info beside
        // checking the build number against a known set of
        // values
        var last_idx: usize = 0;
        for (WindowsVersion.known_win10_build_numbers) |build, i| {
            if (version_info.dwBuildNumber >= build)
                last_idx = i;
        }
        break :subver @truncate(u8, last_idx);
    } else 0;

    const version: u32 = @as(u32, os_ver) << 16 | @as(u16, sp_ver) << 8 | sub_ver;

    return @intToEnum(WindowsVersion, version);
}

// Technically, a registry value can be as long as 1MB. However, MS recommends storing
// values larger than 2048 bytes in a file rather than directly in the registry, and since we
// are only accessing a system hive \Registry\Machine, we stick to MS guidelines.
// https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-element-size-limits
const max_value_len = 2048;

const RegistryPair = struct {
    key: []const u8,
    value: std.os.windows.ULONG,
};

fn getCpuInfoFromRegistry(
    core: usize,
    comptime pairs_num: comptime_int,
    comptime pairs: [pairs_num]RegistryPair,
    out_buf: *[pairs_num][max_value_len]u8,
) !void {
    // Originally, I wanted to issue a single call with a more complex table structure such that we
    // would sequentially visit each CPU#d subkey in the registry and pull the value of interest into
    // a buffer, however, NT seems to be expecting a single buffer per each table meaning we would
    // end up pulling only the last CPU core info, overwriting everything else.
    // If anyone can come up with a solution to this, please do!
    const table_size = 1 + pairs.len;
    var table: [table_size + 1]std.os.windows.RTL_QUERY_REGISTRY_TABLE = undefined;

    const topkey = std.unicode.utf8ToUtf16LeStringLiteral("\\Registry\\Machine\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor");

    const max_cpu_buf = 4;
    var next_cpu_buf: [max_cpu_buf]u8 = undefined;
    const next_cpu = try std.fmt.bufPrint(&next_cpu_buf, "{d}", .{core});

    var subkey: [max_cpu_buf + 1]u16 = undefined;
    const subkey_len = try std.unicode.utf8ToUtf16Le(&subkey, next_cpu);
    subkey[subkey_len] = 0;

    table[0] = .{
        .QueryRoutine = null,
        .Flags = std.os.windows.RTL_QUERY_REGISTRY_SUBKEY | std.os.windows.RTL_QUERY_REGISTRY_REQUIRED,
        .Name = subkey[0..subkey_len :0],
        .EntryContext = null,
        .DefaultType = REG.NONE,
        .DefaultData = null,
        .DefaultLength = 0,
    };

    inline for (pairs) |pair, i| {
        const ctx: *anyopaque = blk: {
            switch (pair.value) {
                REG.SZ,
                REG.EXPAND_SZ,
                REG.MULTI_SZ,
                => {
                    var buf: [max_value_len / 2]u16 = undefined;
                    var unicode = std.os.windows.UNICODE_STRING{
                        .Length = 0,
                        .MaximumLength = max_value_len,
                        .Buffer = &buf,
                    };
                    break :blk &unicode;
                },

                REG.DWORD,
                REG.DWORD_BIG_ENDIAN,
                => {
                    var buf: [4]u8 = undefined;
                    break :blk &buf;
                },

                REG.QWORD => {
                    var buf: [8]u8 = undefined;
                    break :blk &buf;
                },

                else => unreachable,
            }
        };
        const key_name = std.unicode.utf8ToUtf16LeStringLiteral(pair.key);

        table[i + 1] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_DIRECT | std.os.windows.RTL_QUERY_REGISTRY_REQUIRED,
            .Name = @intToPtr([*:0]u16, @ptrToInt(key_name)),
            .EntryContext = ctx,
            .DefaultType = REG.NONE,
            .DefaultData = null,
            .DefaultLength = 0,
        };
    }

    // Table sentinel
    table[table_size] = .{
        .QueryRoutine = null,
        .Flags = 0,
        .Name = null,
        .EntryContext = null,
        .DefaultType = 0,
        .DefaultData = null,
        .DefaultLength = 0,
    };

    const res = std.os.windows.ntdll.RtlQueryRegistryValues(
        std.os.windows.RTL_REGISTRY_ABSOLUTE,
        topkey,
        &table,
        null,
        null,
    );
    switch (res) {
        .SUCCESS => {
            inline for (pairs) |pair, i| switch (pair.value) {
                REG.SZ,
                REG.EXPAND_SZ,
                REG.MULTI_SZ,
                => {
                    const entry = @ptrCast(*align(1) const std.os.windows.UNICODE_STRING, table[i + 1].EntryContext);
                    const len = try std.unicode.utf16leToUtf8(out_buf[i][0..], entry.Buffer[0 .. entry.Length / 2]);
                    out_buf[i][len] = 0;
                },

                REG.DWORD,
                REG.DWORD_BIG_ENDIAN,
                REG.QWORD,
                => {
                    const entry = @ptrCast([*]align(1) const u8, table[i + 1].EntryContext);
                    switch (pair.value) {
                        REG.DWORD, REG.DWORD_BIG_ENDIAN => {
                            mem.copy(u8, out_buf[i][0..4], entry[0..4]);
                        },
                        REG.QWORD => {
                            mem.copy(u8, out_buf[i][0..8], entry[0..8]);
                        },
                        else => unreachable,
                    }
                },

                else => unreachable,
            };
        },
        else => return error.Unexpected,
    }
}

fn setFeature(comptime Feature: type, cpu: *Target.Cpu, feature: Feature, enabled: bool) void {
    const idx = @as(Target.Cpu.Feature.Set.Index, @enumToInt(feature));

    if (enabled) cpu.features.addFeature(idx) else cpu.features.removeFeature(idx);
}

fn getCpuCount() usize {
    return std.os.windows.peb().NumberOfProcessors;
}

const ArmCpuInfoImpl = struct {
    cores: [4]CoreInfo = undefined,
    core_no: usize = 0,
    have_fields: usize = 0,

    const CoreInfo = @import("arm.zig").CoreInfo;
    const cpu_models = @import("arm.zig").cpu_models;

    const Data = struct {
        cp_4000: []const u8,
        identifier: []const u8,
    };

    fn parseDataHook(self: *ArmCpuInfoImpl, data: Data) !void {
        const info = &self.cores[self.core_no];
        info.* = .{};

        // CPU part
        info.part = mem.readIntLittle(u16, data.cp_4000[0..2]) >> 4;
        self.have_fields += 1;

        // CPU implementer
        info.implementer = data.cp_4000[3];
        self.have_fields += 1;

        var tokens = mem.tokenize(u8, data.identifier, " ");
        while (tokens.next()) |token| {
            if (mem.eql(u8, "Family", token)) {
                // CPU architecture
                const family = tokens.next() orelse continue;
                info.architecture = try std.fmt.parseInt(u8, family, 10);
                self.have_fields += 1;
                break;
            }
        } else return;

        self.addOne();
    }

    fn addOne(self: *ArmCpuInfoImpl) void {
        if (self.have_fields == 3 and self.core_no < self.cores.len) {
            if (self.core_no > 0) {
                // Deduplicate the core info.
                for (self.cores[0..self.core_no]) |it| {
                    if (std.meta.eql(it, self.cores[self.core_no]))
                        return;
                }
            }
            self.core_no += 1;
        }
    }

    fn finalize(self: ArmCpuInfoImpl, arch: Target.Cpu.Arch) ?Target.Cpu {
        if (self.core_no == 0) return null;

        const is_64bit = switch (arch) {
            .aarch64, .aarch64_be, .aarch64_32 => true,
            else => false,
        };

        var known_models: [self.cores.len]?*const Target.Cpu.Model = undefined;
        for (self.cores[0..self.core_no]) |core, i| {
            known_models[i] = cpu_models.isKnown(core, is_64bit);
        }

        // XXX We pick the first core on big.LITTLE systems, hopefully the
        // LITTLE one.
        const model = known_models[0] orelse return null;
        return Target.Cpu{
            .arch = arch,
            .model = model,
            .features = model.features,
        };
    }
};

const ArmCpuInfoParser = CpuInfoParser(ArmCpuInfoImpl);

fn CpuInfoParser(comptime impl: anytype) type {
    return struct {
        fn parse(arch: Target.Cpu.Arch) !?Target.Cpu {
            var obj: impl = .{};
            var out_buf: [2][max_value_len]u8 = undefined;

            var i: usize = 0;
            while (i < getCpuCount()) : (i += 1) {
                try getCpuInfoFromRegistry(i, 2, .{
                    .{ .key = "CP 4000", .value = REG.QWORD },
                    .{ .key = "Identifier", .value = REG.SZ },
                }, &out_buf);

                const cp_4000 = out_buf[0][0..8];
                const identifier = mem.sliceTo(out_buf[1][0..], 0);

                try obj.parseDataHook(.{
                    .cp_4000 = cp_4000,
                    .identifier = identifier,
                });
            }

            return obj.finalize(arch);
        }
    };
}

/// If the fine-grained detection of CPU features via Win registry fails,
/// we fallback to a generic CPU model but we override the feature set
/// using `SharedUserData` contents.
/// This is effectively what LLVM does for all ARM chips on Windows.
fn genericCpuAndNativeFeatures(arch: Target.Cpu.Arch) Target.Cpu {
    var cpu = Target.Cpu{
        .arch = arch,
        .model = Target.Cpu.Model.generic(arch),
        .features = Target.Cpu.Feature.Set.empty,
    };

    switch (arch) {
        .aarch64, .aarch64_be, .aarch64_32 => {
            const Feature = Target.aarch64.Feature;

            // Override any features that are either present or absent
            setFeature(Feature, &cpu, .neon, IsProcessorFeaturePresent(PF.ARM_NEON_INSTRUCTIONS_AVAILABLE));
            setFeature(Feature, &cpu, .crc, IsProcessorFeaturePresent(PF.ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE));
            setFeature(Feature, &cpu, .crypto, IsProcessorFeaturePresent(PF.ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE));
            setFeature(Feature, &cpu, .lse, IsProcessorFeaturePresent(PF.ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE));
            setFeature(Feature, &cpu, .dotprod, IsProcessorFeaturePresent(PF.ARM_V82_DP_INSTRUCTIONS_AVAILABLE));
            setFeature(Feature, &cpu, .jsconv, IsProcessorFeaturePresent(PF.ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE));
        },
        else => {},
    }

    return cpu;
}

pub fn detectNativeCpuAndFeatures() ?Target.Cpu {
    const current_arch = builtin.cpu.arch;
    switch (current_arch) {
        .aarch64, .aarch64_be, .aarch64_32 => {
            return ArmCpuInfoParser.parse(current_arch) catch genericCpuAndNativeFeatures(current_arch);
        },
        else => return null,
    }
}
