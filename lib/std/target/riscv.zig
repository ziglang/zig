const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    @"64bit",
    a,
    c,
    d,
    e,
    f,
    m,
    relax,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.@"64bit")] = .{
        .llvm_name = "64bit",
        .description = "Implements RV64",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.a)] = .{
        .llvm_name = "a",
        .description = "'A' (Atomic Instructions)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.c)] = .{
        .llvm_name = "c",
        .description = "'C' (Compressed Instructions)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.d)] = .{
        .llvm_name = "d",
        .description = "'D' (Double-Precision Floating-Point)",
        .dependencies = featureSet(&[_]Feature{
            .f,
        }),
    };
    result[@enumToInt(Feature.e)] = .{
        .llvm_name = "e",
        .description = "Implements RV32E (provides 16 rather than 32 GPRs)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.f)] = .{
        .llvm_name = "f",
        .description = "'F' (Single-Precision Floating-Point)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.m)] = .{
        .llvm_name = "m",
        .description = "'M' (Integer Multiplication and Division)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.relax)] = .{
        .llvm_name = "relax",
        .description = "Enable Linker relaxation.",
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
    pub const baseline_rv32 = CpuModel{
        .name = "baseline_rv32",
        .llvm_name = "generic-rv32",
        .features = featureSet(&[_]Feature{
            .a,
            .c,
            .d,
            .f,
            .m,
        }),
    };

    pub const baseline_rv64 = CpuModel{
        .name = "baseline_rv64",
        .llvm_name = "generic-rv64",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .a,
            .c,
            .d,
            .f,
            .m,
        }),
    };

    pub const generic_rv32 = CpuModel{
        .name = "generic_rv32",
        .llvm_name = "generic-rv32",
        .features = featureSet(&[_]Feature{}),
    };

    pub const generic_rv64 = CpuModel{
        .name = "generic_rv64",
        .llvm_name = "generic-rv64",
        .features = featureSet(&[_]Feature{
            .@"64bit",
        }),
    };
};

/// All riscv CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const CpuModel{
    &cpu.baseline_rv32,
    &cpu.baseline_rv64,
    &cpu.generic_rv32,
    &cpu.generic_rv64,
};
