// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

pub fn detectNativeCpuAndFeatures(arch: Target.Cpu.Arch, os: Target.Os, cross_target: CrossTarget) Target.Cpu {
    const model = Target.Cpu.Model.baseline(arch);
    var cpu = Target.Cpu{
        .arch = arch,
        .model = model,
        .features = model.features,
    };

    // TODO: add feature detection for SPARC systems.
    // Currently we just return the baseline model.

    return cpu;
}
