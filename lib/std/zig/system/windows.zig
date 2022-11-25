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

fn detectNativeCpuAndFeaturesArm64() Target.Cpu {
    const Feature = Target.aarch64.Feature;

    var cpu = Target.Cpu{
        .arch = .aarch64,
        .model = Target.Cpu.Model.generic(.aarch64),
        .features = Target.Cpu.Feature.Set.empty,
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
