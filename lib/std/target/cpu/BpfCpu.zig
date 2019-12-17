const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const BpfCpu = enum {
    Generic,
    Probe,
    V1,
    V2,
    V3,

    const FeatureType = feature.BpfFeature;

    pub fn getInfo(self: @This()) CpuInfo(@This(), FeatureType) {
        return cpu_infos[@enumToInt(self)];
    }

    pub const cpu_infos = [@memberCount(@This())]CpuInfo(@This(), FeatureType) {
        CpuInfo(@This(), FeatureType).create(.Generic, "generic", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.Probe, "probe", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.V1, "v1", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.V2, "v2", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.V3, "v3", &[_]FeatureType {
        }),
    };
};
