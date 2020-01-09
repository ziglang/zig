const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_duplex = Feature{
    .name = "duplex",
    .llvm_name = "duplex",
    .description = "Enable generation of duplex instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "longCalls",
    .llvm_name = "long-calls",
    .description = "Use constant-extended calls",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mem_noshuf = Feature{
    .name = "mem_noshuf",
    .llvm_name = "mem_noshuf",
    .description = "Supports mem_noshuf feature",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_memops = Feature{
    .name = "memops",
    .llvm_name = "memops",
    .description = "Use memop instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nvj = Feature{
    .name = "nvj",
    .llvm_name = "nvj",
    .description = "Support for new-value jumps",
    .dependencies = &[_]*const Feature {
        &feature_packets,
    },
};

pub const feature_nvs = Feature{
    .name = "nvs",
    .llvm_name = "nvs",
    .description = "Support for new-value stores",
    .dependencies = &[_]*const Feature {
        &feature_packets,
    },
};

pub const feature_noreturnStackElim = Feature{
    .name = "noreturnStackElim",
    .llvm_name = "noreturn-stack-elim",
    .description = "Eliminate stack allocation in a noreturn function when possible",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_packets = Feature{
    .name = "packets",
    .llvm_name = "packets",
    .description = "Support for instruction packets",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_reservedR19 = Feature{
    .name = "reservedR19",
    .llvm_name = "reserved-r19",
    .description = "Reserve register R19",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_smallData = Feature{
    .name = "smallData",
    .llvm_name = "small-data",
    .description = "Allow GP-relative addressing of global variables",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
