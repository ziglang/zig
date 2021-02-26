// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    abs2008,
    cnmips,
    cnmipsp,
    crc,
    dsp,
    dspr2,
    dspr3,
    eva,
    fp64,
    fpxx,
    ginv,
    gp64,
    long_calls,
    micromips,
    mips1,
    mips16,
    mips2,
    mips3,
    mips32,
    mips32r2,
    mips32r3,
    mips32r5,
    mips32r6,
    mips3_32,
    mips3_32r2,
    mips3d,
    mips4,
    mips4_32,
    mips4_32r2,
    mips5,
    mips5_32r2,
    mips64,
    mips64r2,
    mips64r3,
    mips64r5,
    mips64r6,
    msa,
    mt,
    nan2008,
    noabicalls,
    nomadd4,
    nooddspreg,
    p5600,
    ptr64,
    single_float,
    soft_float,
    sym32,
    use_indirect_jump_hazard,
    use_tcc_in_div,
    vfpu,
    virt,
    xgot,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.abs2008)] = .{
        .llvm_name = "abs2008",
        .description = "Disable IEEE 754-2008 abs.fmt mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.cnmips)] = .{
        .llvm_name = "cnmips",
        .description = "Octeon cnMIPS Support",
        .dependencies = featureSet(&[_]Feature{
            .mips64r2,
        }),
    };
    result[@enumToInt(Feature.cnmipsp)] = .{
        .llvm_name = "cnmipsp",
        .description = "Octeon+ cnMIPS Support",
        .dependencies = featureSet(&[_]Feature{
            .cnmips,
        }),
    };
    result[@enumToInt(Feature.crc)] = .{
        .llvm_name = "crc",
        .description = "Mips R6 CRC ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dsp)] = .{
        .llvm_name = "dsp",
        .description = "Mips DSP ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dspr2)] = .{
        .llvm_name = "dspr2",
        .description = "Mips DSP-R2 ASE",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
        }),
    };
    result[@enumToInt(Feature.dspr3)] = .{
        .llvm_name = "dspr3",
        .description = "Mips DSP-R3 ASE",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .dspr2,
        }),
    };
    result[@enumToInt(Feature.eva)] = .{
        .llvm_name = "eva",
        .description = "Mips EVA ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp64)] = .{
        .llvm_name = "fp64",
        .description = "Support 64-bit FP registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fpxx)] = .{
        .llvm_name = "fpxx",
        .description = "Support for FPXX",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ginv)] = .{
        .llvm_name = "ginv",
        .description = "Mips Global Invalidate ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.gp64)] = .{
        .llvm_name = "gp64",
        .description = "General Purpose Registers are 64-bit wide",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.long_calls)] = .{
        .llvm_name = "long-calls",
        .description = "Disable use of the jal instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.micromips)] = .{
        .llvm_name = "micromips",
        .description = "microMips mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips1)] = .{
        .llvm_name = "mips1",
        .description = "Mips I ISA Support [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips16)] = .{
        .llvm_name = "mips16",
        .description = "Mips16 mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips2)] = .{
        .llvm_name = "mips2",
        .description = "Mips II ISA Support [highly experimental]",
        .dependencies = featureSet(&[_]Feature{
            .mips1,
        }),
    };
    result[@enumToInt(Feature.mips3)] = .{
        .llvm_name = "mips3",
        .description = "MIPS III ISA Support [highly experimental]",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .gp64,
            .mips2,
            .mips3_32,
            .mips3_32r2,
        }),
    };
    result[@enumToInt(Feature.mips32)] = .{
        .llvm_name = "mips32",
        .description = "Mips32 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips2,
            .mips3_32,
            .mips4_32,
        }),
    };
    result[@enumToInt(Feature.mips32r2)] = .{
        .llvm_name = "mips32r2",
        .description = "Mips32r2 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32,
            .mips3_32r2,
            .mips4_32r2,
            .mips5_32r2,
        }),
    };
    result[@enumToInt(Feature.mips32r3)] = .{
        .llvm_name = "mips32r3",
        .description = "Mips32r3 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32r2,
        }),
    };
    result[@enumToInt(Feature.mips32r5)] = .{
        .llvm_name = "mips32r5",
        .description = "Mips32r5 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32r3,
        }),
    };
    result[@enumToInt(Feature.mips32r6)] = .{
        .llvm_name = "mips32r6",
        .description = "Mips32r6 ISA Support [experimental]",
        .dependencies = featureSet(&[_]Feature{
            .abs2008,
            .fp64,
            .mips32r5,
            .nan2008,
        }),
    };
    result[@enumToInt(Feature.mips3_32)] = .{
        .llvm_name = "mips3_32",
        .description = "Subset of MIPS-III that is also in MIPS32 [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips3_32r2)] = .{
        .llvm_name = "mips3_32r2",
        .description = "Subset of MIPS-III that is also in MIPS32r2 [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips3d)] = .{
        .llvm_name = "mips3d",
        .description = "Mips 3D ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips4)] = .{
        .llvm_name = "mips4",
        .description = "MIPS IV ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips3,
            .mips4_32,
            .mips4_32r2,
        }),
    };
    result[@enumToInt(Feature.mips4_32)] = .{
        .llvm_name = "mips4_32",
        .description = "Subset of MIPS-IV that is also in MIPS32 [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips4_32r2)] = .{
        .llvm_name = "mips4_32r2",
        .description = "Subset of MIPS-IV that is also in MIPS32r2 [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips5)] = .{
        .llvm_name = "mips5",
        .description = "MIPS V ISA Support [highly experimental]",
        .dependencies = featureSet(&[_]Feature{
            .mips4,
            .mips5_32r2,
        }),
    };
    result[@enumToInt(Feature.mips5_32r2)] = .{
        .llvm_name = "mips5_32r2",
        .description = "Subset of MIPS-V that is also in MIPS32r2 [highly experimental]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mips64)] = .{
        .llvm_name = "mips64",
        .description = "Mips64 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32,
            .mips5,
        }),
    };
    result[@enumToInt(Feature.mips64r2)] = .{
        .llvm_name = "mips64r2",
        .description = "Mips64r2 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32r2,
            .mips64,
        }),
    };
    result[@enumToInt(Feature.mips64r3)] = .{
        .llvm_name = "mips64r3",
        .description = "Mips64r3 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32r3,
            .mips64r2,
        }),
    };
    result[@enumToInt(Feature.mips64r5)] = .{
        .llvm_name = "mips64r5",
        .description = "Mips64r5 ISA Support",
        .dependencies = featureSet(&[_]Feature{
            .mips32r5,
            .mips64r3,
        }),
    };
    result[@enumToInt(Feature.mips64r6)] = .{
        .llvm_name = "mips64r6",
        .description = "Mips64r6 ISA Support [experimental]",
        .dependencies = featureSet(&[_]Feature{
            .abs2008,
            .mips32r6,
            .mips64r5,
            .nan2008,
        }),
    };
    result[@enumToInt(Feature.msa)] = .{
        .llvm_name = "msa",
        .description = "Mips MSA ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mt)] = .{
        .llvm_name = "mt",
        .description = "Mips MT ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nan2008)] = .{
        .llvm_name = "nan2008",
        .description = "IEEE 754-2008 NaN encoding",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.noabicalls)] = .{
        .llvm_name = "noabicalls",
        .description = "Disable SVR4-style position-independent code",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nomadd4)] = .{
        .llvm_name = "nomadd4",
        .description = "Disable 4-operand madd.fmt and related instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nooddspreg)] = .{
        .llvm_name = "nooddspreg",
        .description = "Disable odd numbered single-precision registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.p5600)] = .{
        .llvm_name = "p5600",
        .description = "The P5600 Processor",
        .dependencies = featureSet(&[_]Feature{
            .mips32r5,
        }),
    };
    result[@enumToInt(Feature.ptr64)] = .{
        .llvm_name = "ptr64",
        .description = "Pointers are 64-bit wide",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.single_float)] = .{
        .llvm_name = "single-float",
        .description = "Only supports single precision float",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.soft_float)] = .{
        .llvm_name = "soft-float",
        .description = "Does not support floating point instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sym32)] = .{
        .llvm_name = "sym32",
        .description = "Symbols are 32 bit on Mips64",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_indirect_jump_hazard)] = .{
        .llvm_name = "use-indirect-jump-hazard",
        .description = "Use indirect jump guards to prevent certain speculation based attacks",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_tcc_in_div)] = .{
        .llvm_name = "use-tcc-in-div",
        .description = "Force the assembler to use trapping",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vfpu)] = .{
        .llvm_name = "vfpu",
        .description = "Enable vector FPU instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.virt)] = .{
        .llvm_name = "virt",
        .description = "Mips Virtualization ASE",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.xgot)] = .{
        .llvm_name = "xgot",
        .description = "Assume 32-bit GOT",
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
        .features = featureSet(&[_]Feature{
            .mips32,
        }),
    };
    pub const mips1 = CpuModel{
        .name = "mips1",
        .llvm_name = "mips1",
        .features = featureSet(&[_]Feature{
            .mips1,
        }),
    };
    pub const mips2 = CpuModel{
        .name = "mips2",
        .llvm_name = "mips2",
        .features = featureSet(&[_]Feature{
            .mips2,
        }),
    };
    pub const mips3 = CpuModel{
        .name = "mips3",
        .llvm_name = "mips3",
        .features = featureSet(&[_]Feature{
            .mips3,
        }),
    };
    pub const mips32 = CpuModel{
        .name = "mips32",
        .llvm_name = "mips32",
        .features = featureSet(&[_]Feature{
            .mips32,
        }),
    };
    pub const mips32r2 = CpuModel{
        .name = "mips32r2",
        .llvm_name = "mips32r2",
        .features = featureSet(&[_]Feature{
            .mips32r2,
        }),
    };
    pub const mips32r3 = CpuModel{
        .name = "mips32r3",
        .llvm_name = "mips32r3",
        .features = featureSet(&[_]Feature{
            .mips32r3,
        }),
    };
    pub const mips32r5 = CpuModel{
        .name = "mips32r5",
        .llvm_name = "mips32r5",
        .features = featureSet(&[_]Feature{
            .mips32r5,
        }),
    };
    pub const mips32r6 = CpuModel{
        .name = "mips32r6",
        .llvm_name = "mips32r6",
        .features = featureSet(&[_]Feature{
            .mips32r6,
        }),
    };
    pub const mips4 = CpuModel{
        .name = "mips4",
        .llvm_name = "mips4",
        .features = featureSet(&[_]Feature{
            .mips4,
        }),
    };
    pub const mips5 = CpuModel{
        .name = "mips5",
        .llvm_name = "mips5",
        .features = featureSet(&[_]Feature{
            .mips5,
        }),
    };
    pub const mips64 = CpuModel{
        .name = "mips64",
        .llvm_name = "mips64",
        .features = featureSet(&[_]Feature{
            .mips64,
        }),
    };
    pub const mips64r2 = CpuModel{
        .name = "mips64r2",
        .llvm_name = "mips64r2",
        .features = featureSet(&[_]Feature{
            .mips64r2,
        }),
    };
    pub const mips64r3 = CpuModel{
        .name = "mips64r3",
        .llvm_name = "mips64r3",
        .features = featureSet(&[_]Feature{
            .mips64r3,
        }),
    };
    pub const mips64r5 = CpuModel{
        .name = "mips64r5",
        .llvm_name = "mips64r5",
        .features = featureSet(&[_]Feature{
            .mips64r5,
        }),
    };
    pub const mips64r6 = CpuModel{
        .name = "mips64r6",
        .llvm_name = "mips64r6",
        .features = featureSet(&[_]Feature{
            .mips64r6,
        }),
    };
    pub const octeon = CpuModel{
        .name = "octeon",
        .llvm_name = "octeon",
        .features = featureSet(&[_]Feature{
            .cnmips,
            .mips64r2,
        }),
    };
    pub const @"octeon+" = CpuModel{
        .name = "octeon+",
        .llvm_name = "octeon+",
        .features = featureSet(&[_]Feature{
            .cnmips,
            .cnmipsp,
            .mips64r2,
        }),
    };
    pub const p5600 = CpuModel{
        .name = "p5600",
        .llvm_name = "p5600",
        .features = featureSet(&[_]Feature{
            .p5600,
        }),
    };
};
