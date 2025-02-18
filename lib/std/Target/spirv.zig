const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    v1_0,
    v1_1,
    v1_2,
    v1_3,
    v1_4,
    v1_5,
    v1_6,
    int8,
    int16,
    int64,
    float16,
    float64,
    addresses,
    matrix,
    kernel,
    generic_pointer,
    vector16,
    shader,
};

pub const featureSet = CpuFeature.FeatureSetFns(Feature).featureSet;
pub const featureSetHas = CpuFeature.FeatureSetFns(Feature).featureSetHas;
pub const featureSetHasAny = CpuFeature.FeatureSetFns(Feature).featureSetHasAny;
pub const featureSetHasAll = CpuFeature.FeatureSetFns(Feature).featureSetHasAll;

pub const all_features = blk: {
    @setEvalBranchQuota(2000);
    const len = @typeInfo(Feature).@"enum".fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@intFromEnum(Feature.v1_0)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.0",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@intFromEnum(Feature.v1_1)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.1",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.v1_2)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.2",
        .dependencies = featureSet(&[_]Feature{.v1_1}),
    };
    result[@intFromEnum(Feature.v1_3)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.3",
        .dependencies = featureSet(&[_]Feature{.v1_2}),
    };
    result[@intFromEnum(Feature.v1_4)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.4",
        .dependencies = featureSet(&[_]Feature{.v1_3}),
    };
    result[@intFromEnum(Feature.v1_5)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.5",
        .dependencies = featureSet(&[_]Feature{.v1_4}),
    };
    result[@intFromEnum(Feature.v1_6)] = .{
        .llvm_name = null,
        .description = "SPIR-V version 1.6",
        .dependencies = featureSet(&[_]Feature{.v1_5}),
    };
    result[@intFromEnum(Feature.int8)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Int8",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.int16)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Int16",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.int64)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Int64",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.float16)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Float16",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.float64)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Float64",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.addresses)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Addresses",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.matrix)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Matrix",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.kernel)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Kernel",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.generic_pointer)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability GenericPointer",
        .dependencies = featureSet(&[_]Feature{ .v1_0, .addresses }),
    };
    result[@intFromEnum(Feature.vector16)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Vector16",
        .dependencies = featureSet(&[_]Feature{ .v1_0, .kernel }),
    };
    result[@intFromEnum(Feature.shader)] = .{
        .llvm_name = null,
        .description = "Enable SPIR-V capability Shader",
        .dependencies = featureSet(&[_]Feature{ .v1_0, .matrix }),
    };
    const ti = @typeInfo(Feature);
    for (&result, 0..) |*elem, i| {
        elem.index = i;
        elem.name = ti.@"enum".fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const generic: CpuModel = .{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{.v1_0}),
    };

    pub const vulkan_v1_2: CpuModel = .{
        .name = "vulkan_v1_2",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{ .v1_5, .shader, .addresses }),
    };

    pub const opencl_v2: CpuModel = .{
        .name = "opencl_v2",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{ .v1_2, .kernel, .addresses, .generic_pointer }),
    };
};
