const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_alu32 = Feature{
    .name = "alu32",
    .llvm_name = "alu32",
    .description = "Enable ALU32 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dummy = Feature{
    .name = "dummy",
    .llvm_name = "dummy",
    .description = "unused feature",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dwarfris = Feature{
    .name = "dwarfris",
    .llvm_name = "dwarfris",
    .description = "Disable MCAsmInfo DwarfUsesRelocationsAcrossSections",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_alu32,
    &feature_dummy,
    &feature_dwarfris,
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_probe = Cpu{
    .name = "probe",
    .llvm_name = "probe",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_v1 = Cpu{
    .name = "v1",
    .llvm_name = "v1",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_v2 = Cpu{
    .name = "v2",
    .llvm_name = "v2",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_v3 = Cpu{
    .name = "v3",
    .llvm_name = "v3",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_generic,
    &cpu_probe,
    &cpu_v1,
    &cpu_v2,
    &cpu_v3,
};
