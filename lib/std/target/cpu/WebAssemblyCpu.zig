const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const WebAssemblyCpu = enum {
    BleedingEdge,
    Generic,
    Mvp,

    const FeatureType = feature.WebAssemblyFeature;

    pub fn getInfo(self: @This()) CpuInfo(@This(), FeatureType) {
        return cpu_infos[@enumToInt(self)];
    }

    pub const cpu_infos = [@memberCount(@This())]CpuInfo(@This(), FeatureType) {
        CpuInfo(@This(), FeatureType).create(.BleedingEdge, "bleeding-edge", &[_]FeatureType {
            .Atomics,
            .MutableGlobals,
            .NontrappingFptoint,
            .Simd128,
            .SignExt,
        }),
        CpuInfo(@This(), FeatureType).create(.Generic, "generic", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.Mvp, "mvp", &[_]FeatureType {
        }),
    };
};
