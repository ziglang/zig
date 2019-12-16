const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const WebAssemblyCpu = enum {
    BleedingEdge,
    Generic,
    Mvp,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.WebAssemblyFeature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.BleedingEdge, "bleeding-edge", &[_]FeatureType {
            .Atomics,
            .MutableGlobals,
            .NontrappingFptoint,
            .Simd128,
            .SignExt,
        },
        CpuInfo(@This()).create(.Generic, "generic", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.Mvp, "mvp", &[_]FeatureType {
        },
    };
};
