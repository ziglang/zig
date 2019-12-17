const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const RiscVCpu = enum {
    GenericRv32,
    GenericRv64,

    const FeatureType = feature.RiscVFeature;

    pub fn getInfo(self: @This()) CpuInfo(@This(), FeatureType) {
        return cpu_infos[@enumToInt(self)];
    }

    pub const cpu_infos = [@memberCount(@This())]CpuInfo(@This(), FeatureType) {
        CpuInfo(@This(), FeatureType).create(.GenericRv32, "generic-rv32", &[_]FeatureType {
            .RvcHints,
        }),
        CpuInfo(@This(), FeatureType).create(.GenericRv64, "generic-rv64", &[_]FeatureType {
            .Bit64,
            .RvcHints,
        }),
    };
};
