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

    const FeatureType = feature.HexagonFeature;

    pub fn getInfo(self: @This()) CpuInfo(@This(), FeatureType) {
        return cpu_infos[@enumToInt(self)];
    }

    pub const cpu_infos = [@memberCount(@This())]CpuInfo(@This(), FeatureType) {
        CpuInfo(@This(), FeatureType).create(.Generic, "generic", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv5, "hexagonv5", &[_]FeatureType {
            .V5,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv55, "hexagonv55", &[_]FeatureType {
            .V5,
            .V55,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv60, "hexagonv60", &[_]FeatureType {
            .V5,
            .V55,
            .V60,
            .Duplex,
            .Memops,
            .Packets,
            .Nvj,
            .Nvs,
            .SmallData,
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv62, "hexagonv62", &[_]FeatureType {
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
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv65, "hexagonv65", &[_]FeatureType {
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
        }),
        CpuInfo(@This(), FeatureType).create(.Hexagonv66, "hexagonv66", &[_]FeatureType {
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
        }),
    };
};
