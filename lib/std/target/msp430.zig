const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_hwmult16 = Feature{
    .name = "hwmult16",
    .description = "Enable 16-bit hardware multiplier",
    .llvm_name = "hwmult16",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwmult32 = Feature{
    .name = "hwmult32",
    .description = "Enable 32-bit hardware multiplier",
    .llvm_name = "hwmult32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwmultf5 = Feature{
    .name = "hwmultf5",
    .description = "Enable F5 series hardware multiplier",
    .llvm_name = "hwmultf5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ext = Feature{
    .name = "ext",
    .description = "Enable MSP430-X extensions",
    .llvm_name = "ext",
    .subfeatures = &[_]*const Feature {
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
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_msp430 = Cpu{
    .name = "msp430",
    .llvm_name = "msp430",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_msp430x = Cpu{
    .name = "msp430x",
    .llvm_name = "msp430x",
    .subfeatures = &[_]*const Feature {
        &feature_ext,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_generic,
    &cpu_msp430,
    &cpu_msp430x,
};
