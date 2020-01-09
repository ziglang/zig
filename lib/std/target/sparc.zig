const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_hardQuadFloat = Feature{
    .name = "hardQuadFloat",
    .llvm_name = "hard-quad-float",
    .description = "Enable quad-word floating point instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_leon = Feature{
    .name = "leon",
    .llvm_name = "leon",
    .description = "Enable LEON extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noFmuls = Feature{
    .name = "noFmuls",
    .llvm_name = "no-fmuls",
    .description = "Disable the fmuls instruction.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noFsmuld = Feature{
    .name = "noFsmuld",
    .llvm_name = "no-fsmuld",
    .description = "Disable the fsmuld instruction.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_leonpwrpsr = Feature{
    .name = "leonpwrpsr",
    .llvm_name = "leonpwrpsr",
    .description = "Enable the PWRPSR instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_softFloat = Feature{
    .name = "softFloat",
    .llvm_name = "soft-float",
    .description = "Use software emulation for floating point",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_softMulDiv = Feature{
    .name = "softMulDiv",
    .llvm_name = "soft-mul-div",
    .description = "Use software emulation for integer multiply and divide",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_deprecatedV8 = Feature{
    .name = "deprecatedV8",
    .llvm_name = "deprecated-v8",
    .description = "Enable deprecated V8 instructions in V9 mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_v9 = Feature{
    .name = "v9",
    .llvm_name = "v9",
    .description = "Enable SPARC-V9 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vis = Feature{
    .name = "vis",
    .llvm_name = "vis",
    .description = "Enable UltraSPARC Visual Instruction Set extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vis2 = Feature{
    .name = "vis2",
    .llvm_name = "vis2",
    .description = "Enable Visual Instruction Set extensions II",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vis3 = Feature{
    .name = "vis3",
    .llvm_name = "vis3",
    .description = "Enable Visual Instruction Set extensions III",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_hardQuadFloat,
    &feature_leon,
    &feature_noFmuls,
    &feature_noFsmuld,
    &feature_leonpwrpsr,
    &feature_softFloat,
    &feature_softMulDiv,
    &feature_deprecatedV8,
    &feature_v9,
    &feature_vis,
    &feature_vis2,
    &feature_vis3,
};

pub const cpu_at697e = Cpu{
    .name = "at697e",
    .llvm_name = "at697e",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_at697f = Cpu{
    .name = "at697f",
    .llvm_name = "at697f",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_f934 = Cpu{
    .name = "f934",
    .llvm_name = "f934",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_gr712rc = Cpu{
    .name = "gr712rc",
    .llvm_name = "gr712rc",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_gr740 = Cpu{
    .name = "gr740",
    .llvm_name = "gr740",
    .dependencies = &[_]*const Feature {
        &feature_leon,
        &feature_leonpwrpsr,
    },
};

pub const cpu_hypersparc = Cpu{
    .name = "hypersparc",
    .llvm_name = "hypersparc",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_leon2 = Cpu{
    .name = "leon2",
    .llvm_name = "leon2",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_leon3 = Cpu{
    .name = "leon3",
    .llvm_name = "leon3",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_leon4 = Cpu{
    .name = "leon4",
    .llvm_name = "leon4",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2080 = Cpu{
    .name = "ma2080",
    .llvm_name = "ma2080",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2085 = Cpu{
    .name = "ma2085",
    .llvm_name = "ma2085",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2100 = Cpu{
    .name = "ma2100",
    .llvm_name = "ma2100",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2150 = Cpu{
    .name = "ma2150",
    .llvm_name = "ma2150",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2155 = Cpu{
    .name = "ma2155",
    .llvm_name = "ma2155",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2450 = Cpu{
    .name = "ma2450",
    .llvm_name = "ma2450",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2455 = Cpu{
    .name = "ma2455",
    .llvm_name = "ma2455",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2480 = Cpu{
    .name = "ma2480",
    .llvm_name = "ma2480",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2485 = Cpu{
    .name = "ma2485",
    .llvm_name = "ma2485",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2x5x = Cpu{
    .name = "ma2x5x",
    .llvm_name = "ma2x5x",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_ma2x8x = Cpu{
    .name = "ma2x8x",
    .llvm_name = "ma2x8x",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_myriad2 = Cpu{
    .name = "myriad2",
    .llvm_name = "myriad2",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_myriad21 = Cpu{
    .name = "myriad21",
    .llvm_name = "myriad2.1",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_myriad22 = Cpu{
    .name = "myriad22",
    .llvm_name = "myriad2.2",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_myriad23 = Cpu{
    .name = "myriad23",
    .llvm_name = "myriad2.3",
    .dependencies = &[_]*const Feature {
        &feature_leon,
    },
};

pub const cpu_niagara = Cpu{
    .name = "niagara",
    .llvm_name = "niagara",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
        &feature_vis2,
    },
};

pub const cpu_niagara2 = Cpu{
    .name = "niagara2",
    .llvm_name = "niagara2",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
        &feature_vis2,
    },
};

pub const cpu_niagara3 = Cpu{
    .name = "niagara3",
    .llvm_name = "niagara3",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
        &feature_vis2,
    },
};

pub const cpu_niagara4 = Cpu{
    .name = "niagara4",
    .llvm_name = "niagara4",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
        &feature_vis2,
        &feature_vis3,
    },
};

pub const cpu_sparclet = Cpu{
    .name = "sparclet",
    .llvm_name = "sparclet",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_sparclite = Cpu{
    .name = "sparclite",
    .llvm_name = "sparclite",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_sparclite86x = Cpu{
    .name = "sparclite86x",
    .llvm_name = "sparclite86x",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_supersparc = Cpu{
    .name = "supersparc",
    .llvm_name = "supersparc",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_tsc701 = Cpu{
    .name = "tsc701",
    .llvm_name = "tsc701",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_ultrasparc = Cpu{
    .name = "ultrasparc",
    .llvm_name = "ultrasparc",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
    },
};

pub const cpu_ultrasparc3 = Cpu{
    .name = "ultrasparc3",
    .llvm_name = "ultrasparc3",
    .dependencies = &[_]*const Feature {
        &feature_deprecatedV8,
        &feature_v9,
        &feature_vis,
        &feature_vis2,
    },
};

pub const cpu_ut699 = Cpu{
    .name = "ut699",
    .llvm_name = "ut699",
    .dependencies = &[_]*const Feature {
        &feature_leon,
        &feature_noFmuls,
        &feature_noFsmuld,
    },
};

pub const cpu_v7 = Cpu{
    .name = "v7",
    .llvm_name = "v7",
    .dependencies = &[_]*const Feature {
        &feature_noFsmuld,
        &feature_softMulDiv,
    },
};

pub const cpu_v8 = Cpu{
    .name = "v8",
    .llvm_name = "v8",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_v9 = Cpu{
    .name = "v9",
    .llvm_name = "v9",
    .dependencies = &[_]*const Feature {
        &feature_v9,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_at697e,
    &cpu_at697f,
    &cpu_f934,
    &cpu_generic,
    &cpu_gr712rc,
    &cpu_gr740,
    &cpu_hypersparc,
    &cpu_leon2,
    &cpu_leon3,
    &cpu_leon4,
    &cpu_ma2080,
    &cpu_ma2085,
    &cpu_ma2100,
    &cpu_ma2150,
    &cpu_ma2155,
    &cpu_ma2450,
    &cpu_ma2455,
    &cpu_ma2480,
    &cpu_ma2485,
    &cpu_ma2x5x,
    &cpu_ma2x8x,
    &cpu_myriad2,
    &cpu_myriad21,
    &cpu_myriad22,
    &cpu_myriad23,
    &cpu_niagara,
    &cpu_niagara2,
    &cpu_niagara3,
    &cpu_niagara4,
    &cpu_sparclet,
    &cpu_sparclite,
    &cpu_sparclite86x,
    &cpu_supersparc,
    &cpu_tsc701,
    &cpu_ultrasparc,
    &cpu_ultrasparc3,
    &cpu_ut699,
    &cpu_v7,
    &cpu_v8,
    &cpu_v9,
};
