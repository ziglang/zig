// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    deprecated_v8,
    detectroundchange,
    fixallfdivsqrt,
    hard_quad_float,
    hasleoncasa,
    hasumacsmac,
    insertnopload,
    leon,
    leoncyclecounter,
    leonpwrpsr,
    no_fmuls,
    no_fsmuld,
    popc,
    soft_float,
    soft_mul_div,
    v9,
    vis,
    vis2,
    vis3,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.deprecated_v8)] = .{
        .llvm_name = "deprecated-v8",
        .description = "Enable deprecated V8 instructions in V9 mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.detectroundchange)] = .{
        .llvm_name = "detectroundchange",
        .description = "LEON3 erratum detection: Detects any rounding mode change request: use only the round-to-nearest rounding mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fixallfdivsqrt)] = .{
        .llvm_name = "fixallfdivsqrt",
        .description = "LEON erratum fix: Fix FDIVS/FDIVD/FSQRTS/FSQRTD instructions with NOPs and floating-point store",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.hard_quad_float)] = .{
        .llvm_name = "hard-quad-float",
        .description = "Enable quad-word floating point instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.hasleoncasa)] = .{
        .llvm_name = "hasleoncasa",
        .description = "Enable CASA instruction for LEON3 and LEON4 processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.hasumacsmac)] = .{
        .llvm_name = "hasumacsmac",
        .description = "Enable UMAC and SMAC for LEON3 and LEON4 processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.insertnopload)] = .{
        .llvm_name = "insertnopload",
        .description = "LEON3 erratum fix: Insert a NOP instruction after every single-cycle load instruction when the next instruction is another load/store instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.leon)] = .{
        .llvm_name = "leon",
        .description = "Enable LEON extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.leoncyclecounter)] = .{
        .llvm_name = "leoncyclecounter",
        .description = "Use the Leon cycle counter register",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.leonpwrpsr)] = .{
        .llvm_name = "leonpwrpsr",
        .description = "Enable the PWRPSR instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_fmuls)] = .{
        .llvm_name = "no-fmuls",
        .description = "Disable the fmuls instruction.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_fsmuld)] = .{
        .llvm_name = "no-fsmuld",
        .description = "Disable the fsmuld instruction.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.popc)] = .{
        .llvm_name = "popc",
        .description = "Use the popc (population count) instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.soft_float)] = .{
        .llvm_name = "soft-float",
        .description = "Use software emulation for floating point",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.soft_mul_div)] = .{
        .llvm_name = "soft-mul-div",
        .description = "Use software emulation for integer multiply and divide",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.v9)] = .{
        .llvm_name = "v9",
        .description = "Enable SPARC-V9 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vis)] = .{
        .llvm_name = "vis",
        .description = "Enable UltraSPARC Visual Instruction Set extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vis2)] = .{
        .llvm_name = "vis2",
        .description = "Enable Visual Instruction Set extensions II",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vis3)] = .{
        .llvm_name = "vis3",
        .description = "Enable Visual Instruction Set extensions III",
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
    pub const at697e = CpuModel{
        .name = "at697e",
        .llvm_name = "at697e",
        .features = featureSet(&[_]Feature{
            .insertnopload,
            .leon,
        }),
    };
    pub const at697f = CpuModel{
        .name = "at697f",
        .llvm_name = "at697f",
        .features = featureSet(&[_]Feature{
            .insertnopload,
            .leon,
        }),
    };
    pub const f934 = CpuModel{
        .name = "f934",
        .llvm_name = "f934",
        .features = featureSet(&[_]Feature{}),
    };
    pub const gr712rc = CpuModel{
        .name = "gr712rc",
        .llvm_name = "gr712rc",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const gr740 = CpuModel{
        .name = "gr740",
        .llvm_name = "gr740",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .hasumacsmac,
            .leon,
            .leoncyclecounter,
            .leonpwrpsr,
        }),
    };
    pub const hypersparc = CpuModel{
        .name = "hypersparc",
        .llvm_name = "hypersparc",
        .features = featureSet(&[_]Feature{}),
    };
    pub const leon2 = CpuModel{
        .name = "leon2",
        .llvm_name = "leon2",
        .features = featureSet(&[_]Feature{
            .leon,
        }),
    };
    pub const leon3 = CpuModel{
        .name = "leon3",
        .llvm_name = "leon3",
        .features = featureSet(&[_]Feature{
            .hasumacsmac,
            .leon,
        }),
    };
    pub const leon4 = CpuModel{
        .name = "leon4",
        .llvm_name = "leon4",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .hasumacsmac,
            .leon,
        }),
    };
    pub const ma2080 = CpuModel{
        .name = "ma2080",
        .llvm_name = "ma2080",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2085 = CpuModel{
        .name = "ma2085",
        .llvm_name = "ma2085",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2100 = CpuModel{
        .name = "ma2100",
        .llvm_name = "ma2100",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2150 = CpuModel{
        .name = "ma2150",
        .llvm_name = "ma2150",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2155 = CpuModel{
        .name = "ma2155",
        .llvm_name = "ma2155",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2450 = CpuModel{
        .name = "ma2450",
        .llvm_name = "ma2450",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2455 = CpuModel{
        .name = "ma2455",
        .llvm_name = "ma2455",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2480 = CpuModel{
        .name = "ma2480",
        .llvm_name = "ma2480",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2485 = CpuModel{
        .name = "ma2485",
        .llvm_name = "ma2485",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2x5x = CpuModel{
        .name = "ma2x5x",
        .llvm_name = "ma2x5x",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const ma2x8x = CpuModel{
        .name = "ma2x8x",
        .llvm_name = "ma2x8x",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const myriad2 = CpuModel{
        .name = "myriad2",
        .llvm_name = "myriad2",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const myriad2_1 = CpuModel{
        .name = "myriad2_1",
        .llvm_name = "myriad2.1",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const myriad2_2 = CpuModel{
        .name = "myriad2_2",
        .llvm_name = "myriad2.2",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const myriad2_3 = CpuModel{
        .name = "myriad2_3",
        .llvm_name = "myriad2.3",
        .features = featureSet(&[_]Feature{
            .hasleoncasa,
            .leon,
        }),
    };
    pub const niagara = CpuModel{
        .name = "niagara",
        .llvm_name = "niagara",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .v9,
            .vis,
            .vis2,
        }),
    };
    pub const niagara2 = CpuModel{
        .name = "niagara2",
        .llvm_name = "niagara2",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .popc,
            .v9,
            .vis,
            .vis2,
        }),
    };
    pub const niagara3 = CpuModel{
        .name = "niagara3",
        .llvm_name = "niagara3",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .popc,
            .v9,
            .vis,
            .vis2,
        }),
    };
    pub const niagara4 = CpuModel{
        .name = "niagara4",
        .llvm_name = "niagara4",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .popc,
            .v9,
            .vis,
            .vis2,
            .vis3,
        }),
    };
    pub const sparclet = CpuModel{
        .name = "sparclet",
        .llvm_name = "sparclet",
        .features = featureSet(&[_]Feature{}),
    };
    pub const sparclite = CpuModel{
        .name = "sparclite",
        .llvm_name = "sparclite",
        .features = featureSet(&[_]Feature{}),
    };
    pub const sparclite86x = CpuModel{
        .name = "sparclite86x",
        .llvm_name = "sparclite86x",
        .features = featureSet(&[_]Feature{}),
    };
    pub const supersparc = CpuModel{
        .name = "supersparc",
        .llvm_name = "supersparc",
        .features = featureSet(&[_]Feature{}),
    };
    pub const tsc701 = CpuModel{
        .name = "tsc701",
        .llvm_name = "tsc701",
        .features = featureSet(&[_]Feature{}),
    };
    pub const ultrasparc = CpuModel{
        .name = "ultrasparc",
        .llvm_name = "ultrasparc",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .v9,
            .vis,
        }),
    };
    pub const ultrasparc3 = CpuModel{
        .name = "ultrasparc3",
        .llvm_name = "ultrasparc3",
        .features = featureSet(&[_]Feature{
            .deprecated_v8,
            .v9,
            .vis,
            .vis2,
        }),
    };
    pub const ut699 = CpuModel{
        .name = "ut699",
        .llvm_name = "ut699",
        .features = featureSet(&[_]Feature{
            .fixallfdivsqrt,
            .insertnopload,
            .leon,
            .no_fmuls,
            .no_fsmuld,
        }),
    };
    pub const v7 = CpuModel{
        .name = "v7",
        .llvm_name = "v7",
        .features = featureSet(&[_]Feature{
            .no_fsmuld,
            .soft_mul_div,
        }),
    };
    pub const v8 = CpuModel{
        .name = "v8",
        .llvm_name = "v8",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v9 = CpuModel{
        .name = "v9",
        .llvm_name = "v9",
        .features = featureSet(&[_]Feature{
            .v9,
        }),
    };
};
