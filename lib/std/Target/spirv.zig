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
    storage_push_constant16,
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
        .description = "Enable version 1.0",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@intFromEnum(Feature.v1_1)] = .{
        .llvm_name = null,
        .description = "Enable version 1.1",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.v1_2)] = .{
        .llvm_name = null,
        .description = "Enable version 1.2",
        .dependencies = featureSet(&[_]Feature{.v1_1}),
    };
    result[@intFromEnum(Feature.v1_3)] = .{
        .llvm_name = null,
        .description = "Enable version 1.3",
        .dependencies = featureSet(&[_]Feature{.v1_2}),
    };
    result[@intFromEnum(Feature.v1_4)] = .{
        .llvm_name = null,
        .description = "Enable version 1.4",
        .dependencies = featureSet(&[_]Feature{.v1_3}),
    };
    result[@intFromEnum(Feature.v1_5)] = .{
        .llvm_name = null,
        .description = "Enable version 1.5",
        .dependencies = featureSet(&[_]Feature{.v1_4}),
    };
    result[@intFromEnum(Feature.v1_6)] = .{
        .llvm_name = null,
        .description = "Enable version 1.6",
        .dependencies = featureSet(&[_]Feature{.v1_5}),
    };
    result[@intFromEnum(Feature.int8)] = .{
        .llvm_name = null,
        .description = "Enable Int8 capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.int16)] = .{
        .llvm_name = null,
        .description = "Enable Int16 capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.int64)] = .{
        .llvm_name = null,
        .description = "Enable Int64 capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.float16)] = .{
        .llvm_name = null,
        .description = "Enable Float16 capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.float64)] = .{
        .llvm_name = null,
        .description = "Enable Float64 capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.addresses)] = .{
        .llvm_name = null,
        .description = "Enable either the Addresses capability or, SPV_KHR_physical_storage_buffer extension and the PhysicalStorageBufferAddresses capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.matrix)] = .{
        .llvm_name = null,
        .description = "Enable Matrix capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.storage_push_constant16)] = .{
        .llvm_name = null,
        .description = "Enable SPV_KHR_16bit_storage extension and the StoragePushConstant16 capability",
        .dependencies = featureSet(&[_]Feature{.v1_3}),
    };
    result[@intFromEnum(Feature.kernel)] = .{
        .llvm_name = null,
        .description = "Enable Kernel capability",
        .dependencies = featureSet(&[_]Feature{.v1_0}),
    };
    result[@intFromEnum(Feature.generic_pointer)] = .{
        .llvm_name = null,
        .description = "Enable GenericPointer capability",
        .dependencies = featureSet(&[_]Feature{ .v1_0, .addresses }),
    };
    result[@intFromEnum(Feature.vector16)] = .{
        .llvm_name = null,
        .description = "Enable Vector16 capability",
        .dependencies = featureSet(&[_]Feature{ .v1_0, .kernel }),
    };
    result[@intFromEnum(Feature.shader)] = .{
        .llvm_name = null,
        .description = "Enable Shader capability",
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
