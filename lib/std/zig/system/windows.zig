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

const Armv8CpuInfoImpl = struct {
    cores: [8]*const Target.Cpu.Model = undefined,
    core_no: usize = 0,

    const cpu_family_models = .{
        // Family, Model, Revision
        .{ 8, "D4C", 0, &Target.aarch64.cpu.microsoft_sq3 },
    };

    fn parseOne(self: *Armv8CpuInfoImpl, identifier: []const u8) void {
        if (mem.indexOf(u8, identifier, "ARMv8") == null) return; // Sanity check

        var family: ?usize = null;
        var model: ?[]const u8 = null;
        var revision: ?usize = null;

        var tokens = mem.tokenize(u8, identifier, " ");
        while (tokens.next()) |token| {
            if (mem.eql(u8, token, "Family")) {
                const raw = tokens.next() orelse continue;
                family = std.fmt.parseInt(usize, raw, 10) catch null;
            }
            if (mem.eql(u8, token, "Model")) {
                model = tokens.next();
            }
            if (mem.eql(u8, token, "Revision")) {
                const raw = tokens.next() orelse continue;
                revision = std.fmt.parseInt(usize, raw, 10) catch null;
            }
        }

        if (family == null or model == null or revision == null) return;

        inline for (cpu_family_models) |set| {
            if (set[0] == family.? and mem.eql(u8, set[1], model.?) and set[2] == revision.?) {
                self.cores[self.core_no] = set[3];
                self.core_no += 1;
                break;
            }
        }
    }

    fn finalize(self: Armv8CpuInfoImpl) ?*const Target.Cpu.Model {
        if (self.core_no != 8) return null; // Implies we have seen a core we don't know much about
        return self.cores[0];
    }
};

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
        const default: struct { ptr: *anyopaque, len: u32 } = blk: {
            switch (pair.value) {
                REG.SZ,
                REG.EXPAND_SZ,
                REG.MULTI_SZ,
                => {
                    const def = std.unicode.utf8ToUtf16LeStringLiteral("Unknown");
                    var buf: [def.len + 1]u16 = undefined;
                    mem.copy(u16, &buf, def);
                    buf[def.len] = 0;
                    break :blk .{ .ptr = &buf, .len = @intCast(u32, (buf.len + 1) * 2) };
                },

                REG.DWORD,
                REG.DWORD_BIG_ENDIAN,
                => {
                    var buf: [4]u8 = [_]u8{0} ** 4;
                    break :blk .{ .ptr = &buf, .len = 4 };
                },

                REG.QWORD => {
                    var buf: [8]u8 = [_]u8{0} ** 8;
                    break :blk .{ .ptr = &buf, .len = 8 };
                },

                else => unreachable,
            }
        };
        const key_name = std.unicode.utf8ToUtf16LeStringLiteral(pair.key);

        table[i + 1] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_DIRECT,
            .Name = @intToPtr([*:0]u16, @ptrToInt(key_name)),
            .EntryContext = ctx,
            .DefaultType = pair.value,
            .DefaultData = default.ptr,
            .DefaultLength = default.len,
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
                REG.NONE => unreachable,

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
        else => return std.os.windows.unexpectedStatus(res),
    }
}

fn detectCpuModelArm64() !*const Target.Cpu.Model {
    // Pull the CPU identifier from the registry.
    // Assume max number of cores to be at 8.
    const max_cpu_count = 8;
    const cpu_count = getCpuCount();

    if (cpu_count > max_cpu_count) return error.TooManyCpus;

    // Parse the models from strings
    var parser = Armv8CpuInfoImpl{};

    var out_buf: [3][max_value_len]u8 = undefined;

    var i: usize = 0;
    while (i < cpu_count) : (i += 1) {
        try getCpuInfoFromRegistry(i, 3, .{
            .{ .key = "CP 4000", .value = REG.QWORD },
            .{ .key = "Identifier", .value = REG.SZ },
            .{ .key = "VendorIdentifier", .value = REG.SZ },
        }, &out_buf);

        const hex = out_buf[0][0..8];
        const identifier = mem.sliceTo(out_buf[1][0..], 0);
        const vendor_identifier = mem.sliceTo(out_buf[2][0..], 0);
        std.log.warn("{d} => {x}, {s}, {s}", .{ i, std.fmt.fmtSliceHexLower(hex), identifier, vendor_identifier });
    }

    return parser.finalize() orelse Target.Cpu.Model.generic(.aarch64);
}

fn detectNativeCpuAndFeaturesArm64() Target.Cpu {
    const Feature = Target.aarch64.Feature;

    const model = detectCpuModelArm64() catch Target.Cpu.Model.generic(.aarch64);

    var cpu = Target.Cpu{
        .arch = .aarch64,
        .model = model,
        .features = model.features,
    };

    // Override any features that are either present or absent
    if (IsProcessorFeaturePresent(PF.ARM_NEON_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.neon));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.neon));
    }

    if (IsProcessorFeaturePresent(PF.ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.crc));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.crc));
    }

    if (IsProcessorFeaturePresent(PF.ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.crypto));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.crypto));
    }

    if (IsProcessorFeaturePresent(PF.ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.lse));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.lse));
    }

    if (IsProcessorFeaturePresent(PF.ARM_V82_DP_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.dotprod));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.dotprod));
    }

    if (IsProcessorFeaturePresent(PF.ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.jsconv));
    } else {
        cpu.features.removeFeature(@enumToInt(Feature.jsconv));
    }

    return cpu;
}

fn getCpuCount() usize {
    return std.os.windows.peb().NumberOfProcessors;
}

pub fn detectNativeCpuAndFeatures() ?Target.Cpu {
    switch (builtin.cpu.arch) {
        .aarch64 => return detectNativeCpuAndFeaturesArm64(),
        else => |arch| return .{
            .arch = arch,
            .model = Target.Cpu.Model.generic(arch),
            .features = Target.Cpu.Feature.Set.empty,
        },
    }
}
