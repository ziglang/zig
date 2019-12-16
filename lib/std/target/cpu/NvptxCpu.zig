const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const NvptxCpu = enum {
    Sm_20,
    Sm_21,
    Sm_30,
    Sm_32,
    Sm_35,
    Sm_37,
    Sm_50,
    Sm_52,
    Sm_53,
    Sm_60,
    Sm_61,
    Sm_62,
    Sm_70,
    Sm_72,
    Sm_75,

    pub fn getInfo(self: @This()) CpuInfo {
        return cpu_infos[@enumToInt(self)];
    }

    pub const FeatureType = feature.NvptxFeature;

    const cpu_infos = [@memberCount(@This())]CpuInfo(@This()) {
        CpuInfo(@This()).create(.Sm_20, "sm_20", &[_]FeatureType {
            .Sm_20,
        },
        CpuInfo(@This()).create(.Sm_21, "sm_21", &[_]FeatureType {
            .Sm_21,
        },
        CpuInfo(@This()).create(.Sm_30, "sm_30", &[_]FeatureType {
            .Sm_30,
        },
        CpuInfo(@This()).create(.Sm_32, "sm_32", &[_]FeatureType {
            .Ptx40,
            .Sm_32,
        },
        CpuInfo(@This()).create(.Sm_35, "sm_35", &[_]FeatureType {
            .Sm_35,
        },
        CpuInfo(@This()).create(.Sm_37, "sm_37", &[_]FeatureType {
            .Ptx41,
            .Sm_37,
        },
        CpuInfo(@This()).create(.Sm_50, "sm_50", &[_]FeatureType {
            .Ptx40,
            .Sm_50,
        },
        CpuInfo(@This()).create(.Sm_52, "sm_52", &[_]FeatureType {
            .Ptx41,
            .Sm_52,
        },
        CpuInfo(@This()).create(.Sm_53, "sm_53", &[_]FeatureType {
            .Ptx42,
            .Sm_53,
        },
        CpuInfo(@This()).create(.Sm_60, "sm_60", &[_]FeatureType {
            .Ptx50,
            .Sm_60,
        },
        CpuInfo(@This()).create(.Sm_61, "sm_61", &[_]FeatureType {
            .Ptx50,
            .Sm_61,
        },
        CpuInfo(@This()).create(.Sm_62, "sm_62", &[_]FeatureType {
            .Ptx50,
            .Sm_62,
        },
        CpuInfo(@This()).create(.Sm_70, "sm_70", &[_]FeatureType {
            .Ptx60,
            .Sm_70,
        },
        CpuInfo(@This()).create(.Sm_72, "sm_72", &[_]FeatureType {
            .Ptx61,
            .Sm_72,
        },
        CpuInfo(@This()).create(.Sm_75, "sm_75", &[_]FeatureType {
            .Ptx63,
            .Sm_75,
        },
    };
};
