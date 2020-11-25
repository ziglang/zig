// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    alu32,
    dummy,
    dwarfris,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.alu32)] = .{
        .llvm_name = "alu32",
        .description = "Enable ALU32 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dummy)] = .{
        .llvm_name = "dummy",
        .description = "unused feature",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dwarfris)] = .{
        .llvm_name = "dwarfris",
        .description = "Disable MCAsmInfo DwarfUsesRelocationsAcrossSections",
        .dependencies = featureSet(&[_]Feature{}),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{}),
    };
    pub const probe = CpuModel{
        .name = "probe",
        .llvm_name = "probe",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v1 = CpuModel{
        .name = "v1",
        .llvm_name = "v1",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v2 = CpuModel{
        .name = "v2",
        .llvm_name = "v2",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v3 = CpuModel{
        .name = "v3",
        .llvm_name = "v3",
        .features = featureSet(&[_]Feature{}),
    };
};
