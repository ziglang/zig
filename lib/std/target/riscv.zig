const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_bit64 = Feature{
    .name = "bit64",
    .llvm_name = "64bit",
    .description = "Implements RV64",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_e = Feature{
    .name = "e",
    .llvm_name = "e",
    .description = "Implements RV32E (provides 16 rather than 32 GPRs)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_relax = Feature{
    .name = "relax",
    .llvm_name = "relax",
    .description = "Enable Linker relaxation.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_a = Feature{
    .name = "a",
    .llvm_name = "a",
    .description = "'A' (Atomic Instructions)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_c = Feature{
    .name = "c",
    .llvm_name = "c",
    .description = "'C' (Compressed Instructions)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_d = Feature{
    .name = "d",
    .llvm_name = "d",
    .description = "'D' (Double-Precision Floating-Point)",
    .dependencies = &[_]*const Feature {
        &feature_f,
    },
};

pub const feature_f = Feature{
    .name = "f",
    .llvm_name = "f",
    .description = "'F' (Single-Precision Floating-Point)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_m = Feature{
    .name = "m",
    .llvm_name = "m",
    .description = "'M' (Integer Multiplication and Division)",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_bit64,
    &feature_e,
    &feature_relax,
    &feature_a,
    &feature_c,
    &feature_d,
    &feature_f,
    &feature_m,
};

pub const cpu_genericRv32 = Cpu{
    .name = "genericRv32",
    .llvm_name = "generic-rv32",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_genericRv64 = Cpu{
    .name = "genericRv64",
    .llvm_name = "generic-rv64",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_genericRv32,
    &cpu_genericRv64,
};
