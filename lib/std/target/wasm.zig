const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    atomics,
    bulk_memory,
    exception_handling,
    multivalue,
    mutable_globals,
    nontrapping_fptoint,
    sign_ext,
    simd128,
    tail_call,
    unimplemented_simd128,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.atomics)] = .{
        .llvm_name = "atomics",
        .description = "Enable Atomics",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.bulk_memory)] = .{
        .llvm_name = "bulk-memory",
        .description = "Enable bulk memory operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.exception_handling)] = .{
        .llvm_name = "exception-handling",
        .description = "Enable Wasm exception handling",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.multivalue)] = .{
        .llvm_name = "multivalue",
        .description = "Enable multivalue blocks, instructions, and functions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mutable_globals)] = .{
        .llvm_name = "mutable-globals",
        .description = "Enable mutable globals",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nontrapping_fptoint)] = .{
        .llvm_name = "nontrapping-fptoint",
        .description = "Enable non-trapping float-to-int conversion operators",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sign_ext)] = .{
        .llvm_name = "sign-ext",
        .description = "Enable sign extension operators",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.simd128)] = .{
        .llvm_name = "simd128",
        .description = "Enable 128-bit SIMD",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tail_call)] = .{
        .llvm_name = "tail-call",
        .description = "Enable tail call instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.unimplemented_simd128)] = .{
        .llvm_name = "unimplemented-simd128",
        .description = "Enable 128-bit SIMD not yet implemented in engines",
        .dependencies = featureSet(&[_]Feature{
            .simd128,
        }),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const bleeding_edge = CpuModel{
        .name = "bleeding_edge",
        .llvm_name = "bleeding-edge",
        .features = featureSet(&[_]Feature{
            .atomics,
            .mutable_globals,
            .nontrapping_fptoint,
            .sign_ext,
            .simd128,
        }),
    };
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{}),
    };
    pub const mvp = CpuModel{
        .name = "mvp",
        .llvm_name = "mvp",
        .features = featureSet(&[_]Feature{}),
    };
};
