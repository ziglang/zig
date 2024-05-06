const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
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
    const os_ver: u16 = @as(u16, @intCast(version_info.dwMajorVersion & 0xff)) << 8 |
        @as(u16, @intCast(version_info.dwMinorVersion & 0xff));
    const sp_ver: u8 = 0;
    const sub_ver: u8 = if (os_ver >= 0x0A00) subver: {
        // There's no other way to obtain this info beside
        // checking the build number against a known set of
        // values
        var last_idx: usize = 0;
        for (WindowsVersion.known_win10_build_numbers, 0..) |build, i| {
            if (version_info.dwBuildNumber >= build)
                last_idx = i;
        }
        break :subver @as(u8, @truncate(last_idx));
    } else 0;

    const version: u32 = @as(u32, os_ver) << 16 | @as(u16, sp_ver) << 8 | sub_ver;

    return @as(WindowsVersion, @enumFromInt(version));
}

// Technically, a registry value can be as long as 1MB. However, MS recommends storing
// values larger than 2048 bytes in a file rather than directly in the registry, and since we
// are only accessing a system hive \Registry\Machine, we stick to MS guidelines.
// https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-element-size-limits
const max_value_len = 2048;

fn getCpuInfoFromRegistry(core: usize, args: anytype) !void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .Struct) {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }

    const fields_info = args_type_info.Struct.fields;

    // Originally, I wanted to issue a single call with a more complex table structure such that we
    // would sequentially visit each CPU#d subkey in the registry and pull the value of interest into
    // a buffer, however, NT seems to be expecting a single buffer per each table meaning we would
    // end up pulling only the last CPU core info, overwriting everything else.
    // If anyone can come up with a solution to this, please do!
    const table_size = 1 + fields_info.len;
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

    var tmp_bufs: [fields_info.len][max_value_len]u8 align(@alignOf(std.os.windows.UNICODE_STRING)) = undefined;

    inline for (fields_info, 0..) |field, i| {
        const ctx: *anyopaque = blk: {
            switch (@field(args, field.name).value_type) {
                REG.SZ,
                REG.EXPAND_SZ,
                REG.MULTI_SZ,
                => {
                    comptime assert(@sizeOf(std.os.windows.UNICODE_STRING) % 2 == 0);
                    const unicode = @as(*std.os.windows.UNICODE_STRING, @ptrCast(&tmp_bufs[i]));
                    unicode.* = .{
                        .Length = 0,
                        .MaximumLength = max_value_len - @sizeOf(std.os.windows.UNICODE_STRING),
                        .Buffer = @as([*]u16, @ptrCast(tmp_bufs[i][@sizeOf(std.os.windows.UNICODE_STRING)..])),
                    };
                    break :blk unicode;
                },

                REG.DWORD,
                REG.DWORD_BIG_ENDIAN,
                REG.QWORD,
                => break :blk &tmp_bufs[i],

                else => unreachable,
            }
        };

        var key_buf: [max_value_len / 2 + 1]u16 = undefined;
        const key_len = try std.unicode.utf8ToUtf16Le(&key_buf, @field(args, field.name).key);
        key_buf[key_len] = 0;

        table[i + 1] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_DIRECT | std.os.windows.RTL_QUERY_REGISTRY_REQUIRED,
            .Name = key_buf[0..key_len :0],
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
            inline for (fields_info, 0..) |field, i| switch (@field(args, field.name).value_type) {
                REG.SZ,
                REG.EXPAND_SZ,
                REG.MULTI_SZ,
                => {
                    var buf = @field(args, field.name).value_buf;
                    const entry = @as(*align(1) const std.os.windows.UNICODE_STRING, @ptrCast(table[i + 1].EntryContext));
                    const len = try std.unicode.utf16LeToUtf8(buf, entry.Buffer.?[0 .. entry.Length / 2]);
                    buf[len] = 0;
                },

                REG.DWORD,
                REG.DWORD_BIG_ENDIAN,
                REG.QWORD,
                => {
                    const entry = @as([*]align(1) const u8, @ptrCast(table[i + 1].EntryContext));
                    switch (@field(args, field.name).value_type) {
                        REG.DWORD, REG.DWORD_BIG_ENDIAN => {
                            @memcpy(@field(args, field.name).value_buf[0..4], entry[0..4]);
                        },
                        REG.QWORD => {
                            @memcpy(@field(args, field.name).value_buf[0..8], entry[0..8]);
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
    const idx = @as(Target.Cpu.Feature.Set.Index, @intFromEnum(feature));

    if (enabled) cpu.features.addFeature(idx) else cpu.features.removeFeature(idx);
}

fn getCpuCount() usize {
    return std.os.windows.peb().NumberOfProcessors;
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
    const cpu: ?Target.Cpu = switch (current_arch) {
        .aarch64, .aarch64_be, .aarch64_32 => blk: {
            var cores: [128]Target.Cpu = undefined;
            const core_count = getCpuCount();

            if (core_count > cores.len) break :blk null;

            var i: usize = 0;
            while (i < core_count) : (i += 1) {
                // Backing datastore
                var registers: [12]u64 = undefined;

                // Registry key to system ID register mapping
                // CP 4000 -> MIDR_EL1
                // CP 4020 -> ID_AA64PFR0_EL1
                // CP 4021 -> ID_AA64PFR1_EL1
                // CP 4028 -> ID_AA64DFR0_EL1
                // CP 4029 -> ID_AA64DFR1_EL1
                // CP 402C -> ID_AA64AFR0_EL1
                // CP 402D -> ID_AA64AFR1_EL1
                // CP 4030 -> ID_AA64ISAR0_EL1
                // CP 4031 -> ID_AA64ISAR1_EL1
                // CP 4038 -> ID_AA64MMFR0_EL1
                // CP 4039 -> ID_AA64MMFR1_EL1
                // CP 403A -> ID_AA64MMFR2_EL1
                getCpuInfoFromRegistry(i, .{
                    .{ .key = "CP 4000", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[0])) },
                    .{ .key = "CP 4020", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[1])) },
                    .{ .key = "CP 4021", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[2])) },
                    .{ .key = "CP 4028", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[3])) },
                    .{ .key = "CP 4029", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[4])) },
                    .{ .key = "CP 402C", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[5])) },
                    .{ .key = "CP 402D", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[6])) },
                    .{ .key = "CP 4030", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[7])) },
                    .{ .key = "CP 4031", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[8])) },
                    .{ .key = "CP 4038", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[9])) },
                    .{ .key = "CP 4039", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[10])) },
                    .{ .key = "CP 403A", .value_type = REG.QWORD, .value_buf = @as(*[8]u8, @ptrCast(&registers[11])) },
                }) catch break :blk null;

                cores[i] = @import("arm.zig").aarch64.detectNativeCpuAndFeatures(current_arch, registers) orelse
                    break :blk null;
            }

            // Pick the first core, usually LITTLE in big.LITTLE architecture.
            break :blk cores[0];
        },
        else => null,
    };
    return cpu orelse genericCpuAndNativeFeatures(current_arch);
}
