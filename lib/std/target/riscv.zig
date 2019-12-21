const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_bit64 = Feature{
    .name = "64bit",
    .description = "Implements RV64",
    .llvm_name = "64bit",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_e = Feature{
    .name = "e",
    .description = "Implements RV32E (provides 16 rather than 32 GPRs)",
    .llvm_name = "e",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rvcHints = Feature{
    .name = "rvc-hints",
    .description = "Enable RVC Hint Instructions.",
    .llvm_name = "rvc-hints",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_relax = Feature{
    .name = "relax",
    .description = "Enable Linker relaxation.",
    .llvm_name = "relax",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a = Feature{
    .name = "a",
    .description = "'A' (Atomic Instructions)",
    .llvm_name = "a",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_c = Feature{
    .name = "c",
    .description = "'C' (Compressed Instructions)",
    .llvm_name = "c",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_d = Feature{
    .name = "d",
    .description = "'D' (Double-Precision Floating-Point)",
    .llvm_name = "d",
    .subfeatures = &[_]*const Feature {
        &feature_f,
    },
};

pub const feature_f = Feature{
    .name = "f",
    .description = "'F' (Single-Precision Floating-Point)",
    .llvm_name = "f",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_m = Feature{
    .name = "m",
    .description = "'M' (Integer Multiplication and Division)",
    .llvm_name = "m",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_bit64,
    &feature_e,
    &feature_rvcHints,
    &feature_relax,
    &feature_a,
    &feature_c,
    &feature_d,
    &feature_f,
    &feature_m,
};

pub const cpu_genericRv32 = Cpu{
    .name = "generic-rv32",
    .llvm_name = "generic-rv32",
    .subfeatures = &[_]*const Feature {
        &feature_rvcHints,
    },
};

pub const cpu_genericRv64 = Cpu{
    .name = "generic-rv64",
    .llvm_name = "generic-rv64",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_rvcHints,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_genericRv32,
    &cpu_genericRv64,
};
