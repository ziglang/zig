const std = @import("std");
const builtin = @import("builtin");
const Target = std.Target;

pub const WindowsVersion = std.Target.Os.WindowsVersion;
pub const PF = std.os.windows.PF;
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

fn detectCpuModelArm64() !*const Target.Cpu.Model {
    // Pull the CPU identifier from the registry.
    // Assume max number of cores to be at 128.
    const max_cpu_count = 128;
    const cpu_count = getCpuCount();

    if (cpu_count > max_cpu_count) return error.TooManyCpus;

    const table_size = max_cpu_count * 3 + 1;
    const actual_table_size = cpu_count * 3 + 1;
    var table: [table_size]std.os.windows.RTL_QUERY_REGISTRY_TABLE = undefined;

    // Table sentinel
    table[actual_table_size - 1] = .{
        .QueryRoutine = null,
        .Flags = 0,
        .Name = null,
        .EntryContext = null,
        .DefaultType = 0,
        .DefaultData = null,
        .DefaultLength = 0,
    };

    // Technically, a registry value can be as long as 16k u16s. However, MS recommends storing
    // values larger than 2048 in a file rather than directly in the registry, and since we
    // are only accessing a system hive \Registry\Machine, we stick to MS guidelines.
    // https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-element-size-limits
    const max_sz_value = 2048;
    const key_name = std.unicode.utf8ToUtf16LeStringLiteral("Identifier");

    var i: usize = 0;
    var index: usize = 0;
    while (i < cpu_count) : (i += 1) {
        var buf: [max_sz_value]u16 = undefined;
        var buf_uni = std.os.windows.UNICODE_STRING{
            .Length = buf.len * 2,
            .MaximumLength = buf.len * 2,
            .Buffer = &buf,
        };

        var next_cpu_buf: [std.math.log2(max_cpu_count)]u8 = undefined;
        const next_cpu = try std.fmt.bufPrint(&next_cpu_buf, "{d}", .{i});

        var subkey: [std.math.log2(max_cpu_count) / 2]u16 = undefined;
        const subkey_len = try std.unicode.utf8ToUtf16Le(&subkey, next_cpu);
        subkey[subkey_len] = 0;

        table[index] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_SUBKEY | std.os.windows.RTL_QUERY_REGISTRY_REQUIRED,
            .Name = subkey[0..subkey_len :0],
            .EntryContext = null,
            .DefaultType = std.os.windows.REG_NONE,
            .DefaultData = null,
            .DefaultLength = 0,
        };

        table[index + 1] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_DIRECT | std.os.windows.RTL_QUERY_REGISTRY_REQUIRED,
            .Name = @intToPtr([*:0]u16, @ptrToInt(key_name)),
            .EntryContext = &buf_uni,
            .DefaultType = std.os.windows.REG_NONE,
            .DefaultData = null,
            .DefaultLength = 0,
        };

        table[index + 2] = .{
            .QueryRoutine = null,
            .Flags = std.os.windows.RTL_QUERY_REGISTRY_TOPKEY,
            .Name = null,
            .EntryContext = null,
            .DefaultType = std.os.windows.REG_NONE,
            .DefaultData = null,
            .DefaultLength = 0,
        };

        index += 3;
    }

    const topkey = std.unicode.utf8ToUtf16LeStringLiteral("\\Registry\\Machine\\HARDWARE\\DESCRIPTION\\System\\CentralProcessor");
    const res = std.os.windows.ntdll.RtlQueryRegistryValues(
        std.os.windows.RTL_REGISTRY_ABSOLUTE,
        topkey,
        &table,
        null,
        null,
    );
    switch (res) {
        .SUCCESS => {},
        else => return error.QueryRegistryFailed,
    }

    // Parse the models from strings
    i = 0;
    index = 0;
    while (i < cpu_count) : (i += 1) {
        const entry = @ptrCast(*align(1) const std.os.windows.UNICODE_STRING, table[index + 1].EntryContext);
        index += 3;

        var identifier_buf: [max_sz_value * 2]u8 = undefined;
        const len = try std.unicode.utf16leToUtf8(&identifier_buf, entry.Buffer[0 .. entry.Length / 2]);
        const identifier = identifier_buf[0..len];
        _ = identifier;
    }

    return &Target.aarch64.cpu.microsoft_sq3;
}

fn detectNativeCpuAndFeaturesArm64() Target.Cpu {
    const Feature = Target.aarch64.Feature;

    const model = detectCpuModelArm64() catch Target.Cpu.Model.generic(.aarch64);

    var cpu = Target.Cpu{
        .arch = .aarch64,
        .model = model,
        .features = model.features,
    };

    if (IsProcessorFeaturePresent(PF.ARM_NEON_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.neon));
    }
    if (IsProcessorFeaturePresent(PF.ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.crc));
    }
    if (IsProcessorFeaturePresent(PF.ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.crypto));
    }
    if (IsProcessorFeaturePresent(PF.ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.lse));
    }
    if (IsProcessorFeaturePresent(PF.ARM_V82_DP_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.dotprod));
    }
    if (IsProcessorFeaturePresent(PF.ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE)) {
        cpu.features.addFeature(@enumToInt(Feature.jsconv));
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
