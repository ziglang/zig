const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const HexagonCpu = enum {
    Generic,
    Hexagonv5,
    Hexagonv55,
    Hexagonv60,
    Hexagonv62,
    Hexagonv65,
    Hexagonv66,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.HexagonFeature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.Generic, "generic", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv5, "hexagonv5", &[_]FeatureType {
            .V5,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv55, "hexagonv55", &[_]FeatureType {
            .V5,
            .V55,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv60, "hexagonv60", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv62, "hexagonv62", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .V62,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv65, "hexagonv65", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .V62,
            .V65,
            .Duplex,
            .Mem_noshuf,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
        CpuInfo(@This()).create(.Hexagonv66, "hexagonv66", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .V62,
            .V65,
            .V66,
            .Duplex,
            .Mem_noshuf,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        },
    };
};
