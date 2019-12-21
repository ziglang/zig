const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_abs2008 = Feature{
    .name = "abs2008",
    .description = "Disable IEEE 754-2008 abs.fmt mode",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crc = Feature{
    .name = "crc",
    .description = "Mips R6 CRC ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_cnmips = Feature{
    .name = "cnmips",
    .description = "Octeon cnMIPS Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_dsp = Feature{
    .name = "dsp",
    .description = "Mips DSP ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dspr2 = Feature{
    .name = "dspr2",
    .description = "Mips DSP-R2 ASE",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
    },
};

pub const feature_dspr3 = Feature{
    .name = "dspr3",
    .description = "Mips DSP-R3 ASE",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
    },
};

pub const feature_eva = Feature{
    .name = "eva",
    .description = "Mips EVA ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp64 = Feature{
    .name = "fp64",
    .description = "Support 64-bit FP registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpxx = Feature{
    .name = "fpxx",
    .description = "Support for FPXX",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ginv = Feature{
    .name = "ginv",
    .description = "Mips Global Invalidate ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_gp64 = Feature{
    .name = "gp64",
    .description = "General Purpose Registers are 64-bit wide",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "long-calls",
    .description = "Disable use of the jal instruction",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_msa = Feature{
    .name = "msa",
    .description = "Mips MSA ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mt = Feature{
    .name = "mt",
    .description = "Mips MT ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nomadd4 = Feature{
    .name = "nomadd4",
    .description = "Disable 4-operand madd.fmt and related instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_micromips = Feature{
    .name = "micromips",
    .description = "microMips mode",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips1 = Feature{
    .name = "mips1",
    .description = "Mips I ISA Support [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips2 = Feature{
    .name = "mips2",
    .description = "Mips II ISA Support [highly experimental]",
    .subfeatures = &[_]*const Feature {
        &feature_mips1,
    },
};

pub const feature_mips3 = Feature{
    .name = "mips3",
    .description = "MIPS III ISA Support [highly experimental]",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips1,
        &feature_fp64,
        &feature_gp64,
    },
};

pub const feature_mips3_32 = Feature{
    .name = "mips3_32",
    .description = "Subset of MIPS-III that is also in MIPS32 [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips3_32r2 = Feature{
    .name = "mips3_32r2",
    .description = "Subset of MIPS-III that is also in MIPS32r2 [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips4 = Feature{
    .name = "mips4",
    .description = "MIPS IV ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips4_32 = Feature{
    .name = "mips4_32",
    .description = "Subset of MIPS-IV that is also in MIPS32 [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips4_32r2 = Feature{
    .name = "mips4_32r2",
    .description = "Subset of MIPS-IV that is also in MIPS32r2 [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips5 = Feature{
    .name = "mips5",
    .description = "MIPS V ISA Support [highly experimental]",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips5_32r2 = Feature{
    .name = "mips5_32r2",
    .description = "Subset of MIPS-V that is also in MIPS32r2 [highly experimental]",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips16 = Feature{
    .name = "mips16",
    .description = "Mips16 mode",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mips32 = Feature{
    .name = "mips32",
    .description = "Mips32 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips1,
        &feature_mips4_32,
        &feature_mips3_32,
    },
};

pub const feature_mips32r2 = Feature{
    .name = "mips32r2",
    .description = "Mips32r2 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
    },
};

pub const feature_mips32r3 = Feature{
    .name = "mips32r3",
    .description = "Mips32r3 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
    },
};

pub const feature_mips32r5 = Feature{
    .name = "mips32r5",
    .description = "Mips32r5 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
    },
};

pub const feature_mips32r6 = Feature{
    .name = "mips32r6",
    .description = "Mips32r6 ISA Support [experimental]",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_nan2008,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_abs2008,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_mips4_32,
    },
};

pub const feature_mips64 = Feature{
    .name = "mips64",
    .description = "Mips64 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips64r2 = Feature{
    .name = "mips64r2",
    .description = "Mips64r2 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips64r3 = Feature{
    .name = "mips64r3",
    .description = "Mips64r3 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips64r5 = Feature{
    .name = "mips64r5",
    .description = "Mips64r5 ISA Support",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_mips64r6 = Feature{
    .name = "mips64r6",
    .description = "Mips64r6 ISA Support [experimental]",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_nan2008,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_abs2008,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
    },
};

pub const feature_nan2008 = Feature{
    .name = "nan2008",
    .description = "IEEE 754-2008 NaN encoding",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noabicalls = Feature{
    .name = "noabicalls",
    .description = "Disable SVR4-style position-independent code",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nooddspreg = Feature{
    .name = "nooddspreg",
    .description = "Disable odd numbered single-precision registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptr64 = Feature{
    .name = "ptr64",
    .description = "Pointers are 64-bit wide",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_singleFloat = Feature{
    .name = "single-float",
    .description = "Only supports single precision float",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_softFloat = Feature{
    .name = "soft-float",
    .description = "Does not support floating point instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sym32 = Feature{
    .name = "sym32",
    .description = "Symbols are 32 bit on Mips64",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useIndirectJumpHazard = Feature{
    .name = "use-indirect-jump-hazard",
    .description = "Use indirect jump guards to prevent certain speculation based attacks",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useTccInDiv = Feature{
    .name = "use-tcc-in-div",
    .description = "Force the assembler to use trapping",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vfpu = Feature{
    .name = "vfpu",
    .description = "Enable vector FPU instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_virt = Feature{
    .name = "virt",
    .description = "Mips Virtualization ASE",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_xgot = Feature{
    .name = "xgot",
    .description = "Assume 32-bit GOT",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_p5600 = Feature{
    .name = "p5600",
    .description = "The P5600 Processor",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
    },
};

pub const features = &[_]*const Feature {
    &feature_abs2008,
    &feature_crc,
    &feature_cnmips,
    &feature_dsp,
    &feature_dspr2,
    &feature_dspr3,
    &feature_eva,
    &feature_fp64,
    &feature_fpxx,
    &feature_ginv,
    &feature_gp64,
    &feature_longCalls,
    &feature_msa,
    &feature_mt,
    &feature_nomadd4,
    &feature_micromips,
    &feature_mips1,
    &feature_mips2,
    &feature_mips3,
    &feature_mips3_32,
    &feature_mips3_32r2,
    &feature_mips4,
    &feature_mips4_32,
    &feature_mips4_32r2,
    &feature_mips5,
    &feature_mips5_32r2,
    &feature_mips16,
    &feature_mips32,
    &feature_mips32r2,
    &feature_mips32r3,
    &feature_mips32r5,
    &feature_mips32r6,
    &feature_mips64,
    &feature_mips64r2,
    &feature_mips64r3,
    &feature_mips64r5,
    &feature_mips64r6,
    &feature_nan2008,
    &feature_noabicalls,
    &feature_nooddspreg,
    &feature_ptr64,
    &feature_singleFloat,
    &feature_softFloat,
    &feature_sym32,
    &feature_useIndirectJumpHazard,
    &feature_useTccInDiv,
    &feature_vfpu,
    &feature_virt,
    &feature_xgot,
    &feature_p5600,
};

pub const cpu_mips1 = Cpu{
    .name = "mips1",
    .llvm_name = "mips1",
    .subfeatures = &[_]*const Feature {
        &feature_mips1,
    },
};

pub const cpu_mips2 = Cpu{
    .name = "mips2",
    .llvm_name = "mips2",
    .subfeatures = &[_]*const Feature {
        &feature_mips1,
        &feature_mips2,
    },
};

pub const cpu_mips3 = Cpu{
    .name = "mips3",
    .llvm_name = "mips3",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips1,
        &feature_fp64,
        &feature_gp64,
        &feature_mips3,
    },
};

pub const cpu_mips32 = Cpu{
    .name = "mips32",
    .llvm_name = "mips32",
    .subfeatures = &[_]*const Feature {
        &feature_mips1,
        &feature_mips4_32,
        &feature_mips3_32,
        &feature_mips32,
    },
};

pub const cpu_mips32r2 = Cpu{
    .name = "mips32r2",
    .llvm_name = "mips32r2",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
        &feature_mips32r2,
    },
};

pub const cpu_mips32r3 = Cpu{
    .name = "mips32r3",
    .llvm_name = "mips32r3",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
        &feature_mips32r3,
    },
};

pub const cpu_mips32r5 = Cpu{
    .name = "mips32r5",
    .llvm_name = "mips32r5",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
        &feature_mips32r5,
    },
};

pub const cpu_mips32r6 = Cpu{
    .name = "mips32r6",
    .llvm_name = "mips32r6",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_nan2008,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_abs2008,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_mips4_32,
        &feature_mips32r6,
    },
};

pub const cpu_mips4 = Cpu{
    .name = "mips4",
    .llvm_name = "mips4",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips4,
    },
};

pub const cpu_mips5 = Cpu{
    .name = "mips5",
    .llvm_name = "mips5",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips5,
    },
};

pub const cpu_mips64 = Cpu{
    .name = "mips64",
    .llvm_name = "mips64",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips64,
    },
};

pub const cpu_mips64r2 = Cpu{
    .name = "mips64r2",
    .llvm_name = "mips64r2",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips64r2,
    },
};

pub const cpu_mips64r3 = Cpu{
    .name = "mips64r3",
    .llvm_name = "mips64r3",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips64r3,
    },
};

pub const cpu_mips64r5 = Cpu{
    .name = "mips64r5",
    .llvm_name = "mips64r5",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips64r5,
    },
};

pub const cpu_mips64r6 = Cpu{
    .name = "mips64r6",
    .llvm_name = "mips64r6",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_nan2008,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_abs2008,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_mips64r6,
    },
};

pub const cpu_octeon = Cpu{
    .name = "octeon",
    .llvm_name = "octeon",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_fp64,
        &feature_mips5_32r2,
        &feature_gp64,
        &feature_mips4_32,
        &feature_cnmips,
        &feature_mips64r2,
    },
};

pub const cpu_p5600 = Cpu{
    .name = "p5600",
    .llvm_name = "p5600",
    .subfeatures = &[_]*const Feature {
        &feature_mips3_32r2,
        &feature_mips3_32,
        &feature_mips4_32r2,
        &feature_mips1,
        &feature_mips5_32r2,
        &feature_mips4_32,
        &feature_p5600,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_mips1,
    &cpu_mips2,
    &cpu_mips3,
    &cpu_mips32,
    &cpu_mips32r2,
    &cpu_mips32r3,
    &cpu_mips32r5,
    &cpu_mips32r6,
    &cpu_mips4,
    &cpu_mips5,
    &cpu_mips64,
    &cpu_mips64r2,
    &cpu_mips64r3,
    &cpu_mips64r5,
    &cpu_mips64r6,
    &cpu_octeon,
    &cpu_p5600,
};
