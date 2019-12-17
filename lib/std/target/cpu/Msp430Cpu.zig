const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const Msp430Cpu = enum {
    Generic,
    Msp430,
    Msp430x,

    const FeatureType = feature.Msp430Feature;

    pub fn getInfo(self: @This()) CpuInfo(@This(), FeatureType) {
        return cpu_infos[@enumToInt(self)];
    }

    pub const cpu_infos = [@memberCount(@This())]CpuInfo(@This(), FeatureType) {
        CpuInfo(@This(), FeatureType).create(.Generic, "generic", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.Msp430, "msp430", &[_]FeatureType {
        }),
        CpuInfo(@This(), FeatureType).create(.Msp430x, "msp430x", &[_]FeatureType {
            .Ext,
        }),
    };
};
