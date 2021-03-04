// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

const FeatureMapEntry = struct {
    mask: usize,
    feature: Target.arm.Feature,
};

const hwcap_feature_map = [_]FeatureMapEntry{
    .{ .mask = std.os.HWCAP_HALF, .feature = .fp16 },
    .{ .mask = std.os.HWCAP_NEON, .feature = .neon },
    .{ .mask = std.os.HWCAP_VFPv3, .feature = .vfp3 },
    .{ .mask = std.os.HWCAP_VFPv3D16, .feature = .vfp3d16 },
    .{ .mask = std.os.HWCAP_VFPv4, .feature = .vfp4 },
    .{ .mask = std.os.HWCAP_IDIVA, .feature = .hwdiv_arm },
    .{ .mask = std.os.HWCAP_IDIVT, .feature = .hwdiv },
};

fn detectNativeCpuAndFeaturesLinux(arch: Target.Cpu.Arch, cross_target: CrossTarget) ?Target.Cpu {
    // TODO detect CPU model and use that as a starting point
    const baseline = Target.Cpu.Model.baseline(arch);

    var cpu = Target.Cpu{
        .arch = arch,
        .model = baseline,
        .features = baseline.features,
    };

    const hwcap = std.os.linux.getauxval(std.elf.AT_HWCAP);

    for (hwcap_feature_map) |entry| {
        if (hwcap & entry.mask != 0) {
            const idx = @as(Target.Cpu.Feature.Set.Index, @enumToInt(entry.feature));
            cpu.features.addFeature(idx);
        }
    }

    cpu.features.populateDependencies(cpu.arch.allFeaturesList());

    return cpu;
}

pub fn detectNativeCpuAndFeatures(arch: Target.Cpu.Arch, os: Target.Os, cross_target: CrossTarget) ?Target.Cpu {
    return switch (os.tag) {
        .linux => return detectNativeCpuAndFeaturesLinux(arch, cross_target),
        else => return null,
    };
}
