const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_hwmult16 = Feature{
    .name = "hwmult16",
    .llvm_name = "hwmult16",
    .description = "Enable 16-bit hardware multiplier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_hwmult32 = Feature{
    .name = "hwmult32",
    .llvm_name = "hwmult32",
    .description = "Enable 32-bit hardware multiplier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_hwmultf5 = Feature{
    .name = "hwmultf5",
    .llvm_name = "hwmultf5",
    .description = "Enable F5 series hardware multiplier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ext = Feature{
    .name = "ext",
    .llvm_name = "ext",
    .description = "Enable MSP430-X extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_hwmult16,
    &feature_hwmult32,
    &feature_hwmultf5,
    &feature_ext,
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_msp430 = Cpu{
    .name = "msp430",
    .llvm_name = "msp430",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_msp430x = Cpu{
    .name = "msp430x",
    .llvm_name = "msp430x",
    .dependencies = &[_]*const Feature {
        &feature_ext,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_generic,
    &cpu_msp430,
    &cpu_msp430x,
};
