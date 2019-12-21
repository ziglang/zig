const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_v5 = Feature{
    .name = "v5",
    .description = "Enable Hexagon V5 architecture",
    .llvm_name = "v5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v55 = Feature{
    .name = "v55",
    .description = "Enable Hexagon V55 architecture",
    .llvm_name = "v55",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v60 = Feature{
    .name = "v60",
    .description = "Enable Hexagon V60 architecture",
    .llvm_name = "v60",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v62 = Feature{
    .name = "v62",
    .description = "Enable Hexagon V62 architecture",
    .llvm_name = "v62",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v65 = Feature{
    .name = "v65",
    .description = "Enable Hexagon V65 architecture",
    .llvm_name = "v65",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v66 = Feature{
    .name = "v66",
    .description = "Enable Hexagon V66 architecture",
    .llvm_name = "v66",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hvx = Feature{
    .name = "hvx",
    .description = "Hexagon HVX instructions",
    .llvm_name = "hvx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hvxLength64b = Feature{
    .name = "hvx-length64b",
    .description = "Hexagon HVX 64B instructions",
    .llvm_name = "hvx-length64b",
    .subfeatures = &[_]*const Feature {
        &feature_hvx,
    },
};

pub const feature_hvxLength128b = Feature{
    .name = "hvx-length128b",
    .description = "Hexagon HVX 128B instructions",
    .llvm_name = "hvx-length128b",
    .subfeatures = &[_]*const Feature {
        &feature_hvx,
    },
};

pub const feature_hvxv60 = Feature{
    .name = "hvxv60",
    .description = "Hexagon HVX instructions",
    .llvm_name = "hvxv60",
    .subfeatures = &[_]*const Feature {
        &feature_hvx,
    },
};

pub const feature_hvxv62 = Feature{
    .name = "hvxv62",
    .description = "Hexagon HVX instructions",
    .llvm_name = "hvxv62",
    .subfeatures = &[_]*const Feature {
        &feature_hvx,
    },
};

pub const feature_hvxv65 = Feature{
    .name = "hvxv65",
    .description = "Hexagon HVX instructions",
    .llvm_name = "hvxv65",
    .subfeatures = &[_]*const Feature {
        &feature_hvx,
    },
};

pub const feature_hvxv66 = Feature{
    .name = "hvxv66",
    .description = "Hexagon HVX instructions",
    .llvm_name = "hvxv66",
    .subfeatures = &[_]*const Feature {
        &feature_zreg,
        &feature_hvx,
    },
};

pub const feature_zreg = Feature{
    .name = "zreg",
    .description = "Hexagon ZReg extension instructions",
    .llvm_name = "zreg",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_duplex = Feature{
    .name = "duplex",
    .description = "Enable generation of duplex instruction",
    .llvm_name = "duplex",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "long-calls",
    .description = "Use constant-extended calls",
    .llvm_name = "long-calls",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mem_noshuf = Feature{
    .name = "mem_noshuf",
    .description = "Supports mem_noshuf feature",
    .llvm_name = "mem_noshuf",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_memops = Feature{
    .name = "memops",
    .description = "Use memop instructions",
    .llvm_name = "memops",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nvj = Feature{
    .name = "nvj",
    .description = "Support for new-value jumps",
    .llvm_name = "nvj",
    .subfeatures = &[_]*const Feature {
        &feature_packets,
    },
};

pub const feature_nvs = Feature{
    .name = "nvs",
    .description = "Support for new-value stores",
    .llvm_name = "nvs",
    .subfeatures = &[_]*const Feature {
        &feature_packets,
    },
};

pub const feature_noreturnStackElim = Feature{
    .name = "noreturn-stack-elim",
    .description = "Eliminate stack allocation in a noreturn function when possible",
    .llvm_name = "noreturn-stack-elim",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_packets = Feature{
    .name = "packets",
    .description = "Support for instruction packets",
    .llvm_name = "packets",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reservedR19 = Feature{
    .name = "reserved-r19",
    .description = "Reserve register R19",
    .llvm_name = "reserved-r19",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_smallData = Feature{
    .name = "small-data",
    .description = "Allow GP-relative addressing of global variables",
    .llvm_name = "small-data",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_v5,
    &feature_v55,
    &feature_v60,
    &feature_v62,
    &feature_v65,
    &feature_v66,
    &feature_hvx,
    &feature_hvxLength64b,
    &feature_hvxLength128b,
    &feature_hvxv60,
    &feature_hvxv62,
    &feature_hvxv65,
    &feature_hvxv66,
    &feature_zreg,
    &feature_duplex,
    &feature_longCalls,
    &feature_mem_noshuf,
    &feature_memops,
    &feature_nvj,
    &feature_nvs,
    &feature_noreturnStackElim,
    &feature_packets,
    &feature_reservedR19,
    &feature_smallData,
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_v60,
        &feature_duplex,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv5 = Cpu{
    .name = "hexagonv5",
    .llvm_name = "hexagonv5",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_duplex,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv55 = Cpu{
    .name = "hexagonv55",
    .llvm_name = "hexagonv55",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_duplex,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv60 = Cpu{
    .name = "hexagonv60",
    .llvm_name = "hexagonv60",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_v60,
        &feature_duplex,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv62 = Cpu{
    .name = "hexagonv62",
    .llvm_name = "hexagonv62",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_v60,
        &feature_v62,
        &feature_duplex,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv65 = Cpu{
    .name = "hexagonv65",
    .llvm_name = "hexagonv65",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_v60,
        &feature_v62,
        &feature_v65,
        &feature_duplex,
        &feature_mem_noshuf,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpu_hexagonv66 = Cpu{
    .name = "hexagonv66",
    .llvm_name = "hexagonv66",
    .subfeatures = &[_]*const Feature {
        &feature_v5,
        &feature_v55,
        &feature_v60,
        &feature_v62,
        &feature_v65,
        &feature_v66,
        &feature_duplex,
        &feature_mem_noshuf,
        &feature_memops,
        &feature_packets,
        &feature_nvj,
        &feature_nvs,
        &feature_smallData,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_generic,
    &cpu_hexagonv5,
    &cpu_hexagonv55,
    &cpu_hexagonv60,
    &cpu_hexagonv62,
    &cpu_hexagonv65,
    &cpu_hexagonv66,
};
