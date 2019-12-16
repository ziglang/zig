const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const RiscVCpu = enum {
    GenericRv32,
    GenericRv64,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.RiscVFeature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.GenericRv32, "generic-rv32", &[_]FeatureType {
            .RvcHints,
        },
        CpuInfo(@This()).create(.GenericRv64, "generic-rv64", &[_]FeatureType {
            .Bit64,
            .RvcHints,
        },
    };
};
