const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const BpfCpu = enum {
    Generic,
    Probe,
    V1,
    V2,
    V3,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.BpfFeature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.Generic, "generic", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.Probe, "probe", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.V1, "v1", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.V2, "v2", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.V3, "v3", &[_]FeatureType {
        },
    };
};
