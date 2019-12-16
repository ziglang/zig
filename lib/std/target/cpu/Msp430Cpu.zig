const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const Msp430Cpu = enum {
    Generic,
    Msp430,
    Msp430x,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.Msp430Feature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.Generic, "generic", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.Msp430, "msp430", &[_]FeatureType {
        },
        CpuInfo(@This()).create(.Msp430x, "msp430x", &[_]FeatureType {
            .Ext,
        },
    };
};
