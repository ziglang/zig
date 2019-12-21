const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_armv2 = Feature{
    .name = "armv2",
    .description = "ARMv2 architecture",
    .llvm_name = "armv2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_armv2a = Feature{
    .name = "armv2a",
    .description = "ARMv2a architecture",
    .llvm_name = "armv2a",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_armv3 = Feature{
    .name = "armv3",
    .description = "ARMv3 architecture",
    .llvm_name = "armv3",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_armv3m = Feature{
    .name = "armv3m",
    .description = "ARMv3m architecture",
    .llvm_name = "armv3m",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_armv4 = Feature{
    .name = "armv4",
    .description = "ARMv4 architecture",
    .llvm_name = "armv4",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_armv4t = Feature{
    .name = "armv4t",
    .description = "ARMv4t architecture",
    .llvm_name = "armv4t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_armv5t = Feature{
    .name = "armv5t",
    .description = "ARMv5t architecture",
    .llvm_name = "armv5t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_armv5te = Feature{
    .name = "armv5te",
    .description = "ARMv5te architecture",
    .llvm_name = "armv5te",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_armv5tej = Feature{
    .name = "armv5tej",
    .description = "ARMv5tej architecture",
    .llvm_name = "armv5tej",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_armv6 = Feature{
    .name = "armv6",
    .description = "ARMv6 architecture",
    .llvm_name = "armv6",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
    },
};

pub const feature_armv6j = Feature{
    .name = "armv6j",
    .description = "ARMv7a architecture",
    .llvm_name = "armv6j",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
    },
};

pub const feature_armv6k = Feature{
    .name = "armv6k",
    .description = "ARMv6k architecture",
    .llvm_name = "armv6k",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_armv6kz = Feature{
    .name = "armv6kz",
    .description = "ARMv6kz architecture",
    .llvm_name = "armv6kz",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_trustzone,
    },
};

pub const feature_armv6M = Feature{
    .name = "armv6-m",
    .description = "ARMv6m architecture",
    .llvm_name = "armv6-m",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
    },
};

pub const feature_armv6sM = Feature{
    .name = "armv6s-m",
    .description = "ARMv6sm architecture",
    .llvm_name = "armv6s-m",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
    },
};

pub const feature_armv6t2 = Feature{
    .name = "armv6t2",
    .description = "ARMv6t2 architecture",
    .llvm_name = "armv6t2",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
        &feature_thumb2,
    },
};

pub const feature_armv7A = Feature{
    .name = "armv7-a",
    .description = "ARMv7a architecture",
    .llvm_name = "armv7-a",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv7eM = Feature{
    .name = "armv7e-m",
    .description = "ARMv7em architecture",
    .llvm_name = "armv7e-m",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
    },
};

pub const feature_armv7k = Feature{
    .name = "armv7k",
    .description = "ARMv7a architecture",
    .llvm_name = "armv7k",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_dsp,
        &feature_aclass,
        &feature_perfmon,
        &feature_fpregs,
    },
};

pub const feature_armv7M = Feature{
    .name = "armv7-m",
    .description = "ARMv7m architecture",
    .llvm_name = "armv7-m",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
    },
};

pub const feature_armv7R = Feature{
    .name = "armv7-r",
    .description = "ARMv7r architecture",
    .llvm_name = "armv7-r",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
    },
};

pub const feature_armv7s = Feature{
    .name = "armv7s",
    .description = "ARMv7a architecture",
    .llvm_name = "armv7s",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_dsp,
        &feature_aclass,
        &feature_perfmon,
        &feature_fpregs,
    },
};

pub const feature_armv7ve = Feature{
    .name = "armv7ve",
    .description = "ARMv7ve architecture",
    .llvm_name = "armv7ve",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv8A = Feature{
    .name = "armv8-a",
    .description = "ARMv8a architecture",
    .llvm_name = "armv8-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv8Mbase = Feature{
    .name = "armv8-m.base",
    .description = "ARMv8mBaseline architecture",
    .llvm_name = "armv8-m.base",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_hwdiv,
    },
};

pub const feature_armv8Mmain = Feature{
    .name = "armv8-m.main",
    .description = "ARMv8mMainline architecture",
    .llvm_name = "armv8-m.main",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
    },
};

pub const feature_armv8R = Feature{
    .name = "armv8-r",
    .description = "ARMv8r architecture",
    .llvm_name = "armv8-r",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_dfb,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_rclass,
    },
};

pub const feature_armv81A = Feature{
    .name = "armv8.1-a",
    .description = "ARMv81a architecture",
    .llvm_name = "armv8.1-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv81Mmain = Feature{
    .name = "armv8.1-m.main",
    .description = "ARMv81mMainline architecture",
    .llvm_name = "armv8.1-m.main",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_lob,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumb2,
        &feature_mclass,
        &feature_ras,
        &feature_noarm,
        &feature_v4t,
        &feature_thumbMode,
        &feature_perfmon,
        &feature_hwdiv,
    },
};

pub const feature_armv82A = Feature{
    .name = "armv8.2-a",
    .description = "ARMv82a architecture",
    .llvm_name = "armv8.2-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv83A = Feature{
    .name = "armv8.3-a",
    .description = "ARMv83a architecture",
    .llvm_name = "armv8.3-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv84A = Feature{
    .name = "armv8.4-a",
    .description = "ARMv84a architecture",
    .llvm_name = "armv8.4-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_armv85A = Feature{
    .name = "armv8.5-a",
    .description = "ARMv85a architecture",
    .llvm_name = "armv8.5-a",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_sb,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_msecext8 = Feature{
    .name = "8msecext",
    .description = "Enable support for ARMv8-M Security Extensions",
    .llvm_name = "8msecext",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_aclass = Feature{
    .name = "aclass",
    .description = "Is application profile ('A' series)",
    .llvm_name = "aclass",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_aes = Feature{
    .name = "aes",
    .description = "Enable AES support",
    .llvm_name = "aes",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_acquireRelease = Feature{
    .name = "acquire-release",
    .description = "Has v8 acquire/release (lda/ldaex  etc) instructions",
    .llvm_name = "acquire-release",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_avoidMovsShop = Feature{
    .name = "avoid-movs-shop",
    .description = "Avoid movs instructions with shifter operand",
    .llvm_name = "avoid-movs-shop",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_avoidPartialCpsr = Feature{
    .name = "avoid-partial-cpsr",
    .description = "Avoid CPSR partial update for OOO execution",
    .llvm_name = "avoid-partial-cpsr",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crc = Feature{
    .name = "crc",
    .description = "Enable support for CRC instructions",
    .llvm_name = "crc",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_cheapPredicableCpsr = Feature{
    .name = "cheap-predicable-cpsr",
    .description = "Disable +1 predication cost for instructions updating CPSR",
    .llvm_name = "cheap-predicable-cpsr",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vldnAlign = Feature{
    .name = "vldn-align",
    .description = "Check for VLDn unaligned access",
    .llvm_name = "vldn-align",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .description = "Enable support for Cryptography extensions",
    .llvm_name = "crypto",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_d32 = Feature{
    .name = "d32",
    .description = "Extend FP to 32 double registers",
    .llvm_name = "d32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_db = Feature{
    .name = "db",
    .description = "Has data barrier (dmb/dsb) instructions",
    .llvm_name = "db",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dfb = Feature{
    .name = "dfb",
    .description = "Has full data barrier (dfb) instruction",
    .llvm_name = "dfb",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dsp = Feature{
    .name = "dsp",
    .description = "Supports DSP instructions in ARM and/or Thumb2",
    .llvm_name = "dsp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dontWidenVmovs = Feature{
    .name = "dont-widen-vmovs",
    .description = "Don't widen VMOVS to VMOVD",
    .llvm_name = "dont-widen-vmovs",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dotprod = Feature{
    .name = "dotprod",
    .description = "Enable support for dot product instructions",
    .llvm_name = "dotprod",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_executeOnly = Feature{
    .name = "execute-only",
    .description = "Enable the generation of execute only code.",
    .llvm_name = "execute-only",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_expandFpMlx = Feature{
    .name = "expand-fp-mlx",
    .description = "Expand VFP/NEON MLA/MLS instructions",
    .llvm_name = "expand-fp-mlx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp16 = Feature{
    .name = "fp16",
    .description = "Enable half-precision floating point",
    .llvm_name = "fp16",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp16fml = Feature{
    .name = "fp16fml",
    .description = "Enable full half-precision floating point fml instructions",
    .llvm_name = "fp16fml",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fp64 = Feature{
    .name = "fp64",
    .description = "Floating point unit supports double precision",
    .llvm_name = "fp64",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpao = Feature{
    .name = "fpao",
    .description = "Enable fast computation of positive address offsets",
    .llvm_name = "fpao",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpArmv8 = Feature{
    .name = "fp-armv8",
    .description = "Enable ARMv8 FP",
    .llvm_name = "fp-armv8",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8d16 = Feature{
    .name = "fp-armv8d16",
    .description = "Enable ARMv8 FP with only 16 d-registers",
    .llvm_name = "fp-armv8d16",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8d16sp = Feature{
    .name = "fp-armv8d16sp",
    .description = "Enable ARMv8 FP with only 16 d-registers and no double precision",
    .llvm_name = "fp-armv8d16sp",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8sp = Feature{
    .name = "fp-armv8sp",
    .description = "Enable ARMv8 FP with no double precision",
    .llvm_name = "fp-armv8sp",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_fpregs = Feature{
    .name = "fpregs",
    .description = "Enable FP registers",
    .llvm_name = "fpregs",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpregs16 = Feature{
    .name = "fpregs16",
    .description = "Enable 16-bit FP registers",
    .llvm_name = "fpregs16",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpregs64 = Feature{
    .name = "fpregs64",
    .description = "Enable 64-bit FP registers",
    .llvm_name = "fpregs64",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fullfp16 = Feature{
    .name = "fullfp16",
    .description = "Enable full half-precision floating point",
    .llvm_name = "fullfp16",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fuseAes = Feature{
    .name = "fuse-aes",
    .description = "CPU fuses AES crypto operations",
    .llvm_name = "fuse-aes",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseLiterals = Feature{
    .name = "fuse-literals",
    .description = "CPU fuses literal generation operations",
    .llvm_name = "fuse-literals",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwdivArm = Feature{
    .name = "hwdiv-arm",
    .description = "Enable divide instructions in ARM mode",
    .llvm_name = "hwdiv-arm",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwdiv = Feature{
    .name = "hwdiv",
    .description = "Enable divide instructions in Thumb",
    .llvm_name = "hwdiv",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noBranchPredictor = Feature{
    .name = "no-branch-predictor",
    .description = "Has no branch predictor",
    .llvm_name = "no-branch-predictor",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_retAddrStack = Feature{
    .name = "ret-addr-stack",
    .description = "Has return address stack",
    .llvm_name = "ret-addr-stack",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowfpvmlx = Feature{
    .name = "slowfpvmlx",
    .description = "Disable VFP / NEON MAC instructions",
    .llvm_name = "slowfpvmlx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vmlxHazards = Feature{
    .name = "vmlx-hazards",
    .description = "Has VMLx hazards",
    .llvm_name = "vmlx-hazards",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_lob = Feature{
    .name = "lob",
    .description = "Enable Low Overhead Branch extensions",
    .llvm_name = "lob",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "long-calls",
    .description = "Generate calls via indirect call instructions",
    .llvm_name = "long-calls",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mclass = Feature{
    .name = "mclass",
    .description = "Is microcontroller profile ('M' series)",
    .llvm_name = "mclass",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mp = Feature{
    .name = "mp",
    .description = "Supports Multiprocessing extension",
    .llvm_name = "mp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve1beat = Feature{
    .name = "mve1beat",
    .description = "Model MVE instructions as a 1 beat per tick architecture",
    .llvm_name = "mve1beat",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve2beat = Feature{
    .name = "mve2beat",
    .description = "Model MVE instructions as a 2 beats per tick architecture",
    .llvm_name = "mve2beat",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve4beat = Feature{
    .name = "mve4beat",
    .description = "Model MVE instructions as a 4 beats per tick architecture",
    .llvm_name = "mve4beat",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_muxedUnits = Feature{
    .name = "muxed-units",
    .description = "Has muxed AGU and NEON/FPU",
    .llvm_name = "muxed-units",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_neon = Feature{
    .name = "neon",
    .description = "Enable NEON instructions",
    .llvm_name = "neon",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_neonfp = Feature{
    .name = "neonfp",
    .description = "Use NEON for single precision FP",
    .llvm_name = "neonfp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_neonFpmovs = Feature{
    .name = "neon-fpmovs",
    .description = "Convert VMOVSR, VMOVRS, VMOVS to NEON",
    .llvm_name = "neon-fpmovs",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_naclTrap = Feature{
    .name = "nacl-trap",
    .description = "NaCl trap",
    .llvm_name = "nacl-trap",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noarm = Feature{
    .name = "noarm",
    .description = "Does not support ARM mode execution",
    .llvm_name = "noarm",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noMovt = Feature{
    .name = "no-movt",
    .description = "Don't use movt/movw pairs for 32-bit imms",
    .llvm_name = "no-movt",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noNegImmediates = Feature{
    .name = "no-neg-immediates",
    .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
    .llvm_name = "no-neg-immediates",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_disablePostraScheduler = Feature{
    .name = "disable-postra-scheduler",
    .description = "Don't schedule again after register allocation",
    .llvm_name = "disable-postra-scheduler",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nonpipelinedVfp = Feature{
    .name = "nonpipelined-vfp",
    .description = "VFP instructions are not pipelined",
    .llvm_name = "nonpipelined-vfp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_perfmon = Feature{
    .name = "perfmon",
    .description = "Enable support for Performance Monitor extensions",
    .llvm_name = "perfmon",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_bit32 = Feature{
    .name = "32bit",
    .description = "Prefer 32-bit Thumb instrs",
    .llvm_name = "32bit",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_preferIshst = Feature{
    .name = "prefer-ishst",
    .description = "Prefer ISHST barriers",
    .llvm_name = "prefer-ishst",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loopAlign = Feature{
    .name = "loop-align",
    .description = "Prefer 32-bit alignment for loops",
    .llvm_name = "loop-align",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_preferVmovsr = Feature{
    .name = "prefer-vmovsr",
    .description = "Prefer VMOVSR",
    .llvm_name = "prefer-vmovsr",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_profUnpr = Feature{
    .name = "prof-unpr",
    .description = "Is profitable to unpredicate",
    .llvm_name = "prof-unpr",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ras = Feature{
    .name = "ras",
    .description = "Enable Reliability, Availability and Serviceability extensions",
    .llvm_name = "ras",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rclass = Feature{
    .name = "rclass",
    .description = "Is realtime profile ('R' series)",
    .llvm_name = "rclass",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_readTpHard = Feature{
    .name = "read-tp-hard",
    .description = "Reading thread pointer from register",
    .llvm_name = "read-tp-hard",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveR9 = Feature{
    .name = "reserve-r9",
    .description = "Reserve R9, making it unavailable as GPR",
    .llvm_name = "reserve-r9",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sb = Feature{
    .name = "sb",
    .description = "Enable v8.5a Speculation Barrier",
    .llvm_name = "sb",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sha2 = Feature{
    .name = "sha2",
    .description = "Enable SHA1 and SHA256 support",
    .llvm_name = "sha2",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_slowFpBrcc = Feature{
    .name = "slow-fp-brcc",
    .description = "FP compare + branch is slow",
    .llvm_name = "slow-fp-brcc",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowLoadDSubreg = Feature{
    .name = "slow-load-D-subreg",
    .description = "Loading into D subregs is slow",
    .llvm_name = "slow-load-D-subreg",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowOddReg = Feature{
    .name = "slow-odd-reg",
    .description = "VLDM/VSTM starting with an odd register is slow",
    .llvm_name = "slow-odd-reg",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowVdup32 = Feature{
    .name = "slow-vdup32",
    .description = "Has slow VDUP32 - prefer VMOV",
    .llvm_name = "slow-vdup32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowVgetlni32 = Feature{
    .name = "slow-vgetlni32",
    .description = "Has slow VGETLNi32 - prefer VMOV",
    .llvm_name = "slow-vgetlni32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_splatVfpNeon = Feature{
    .name = "splat-vfp-neon",
    .description = "Splat register from VFP to NEON",
    .llvm_name = "splat-vfp-neon",
    .subfeatures = &[_]*const Feature {
        &feature_dontWidenVmovs,
    },
};

pub const feature_strictAlign = Feature{
    .name = "strict-align",
    .description = "Disallow all unaligned memory access",
    .llvm_name = "strict-align",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_thumb2 = Feature{
    .name = "thumb2",
    .description = "Enable Thumb2 instructions",
    .llvm_name = "thumb2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_trustzone = Feature{
    .name = "trustzone",
    .description = "Enable support for TrustZone security extensions",
    .llvm_name = "trustzone",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useAa = Feature{
    .name = "use-aa",
    .description = "Use alias analysis during codegen",
    .llvm_name = "use-aa",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useMisched = Feature{
    .name = "use-misched",
    .description = "Use the MachineScheduler",
    .llvm_name = "use-misched",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_wideStrideVfp = Feature{
    .name = "wide-stride-vfp",
    .description = "Use a wide stride when allocating VFP registers",
    .llvm_name = "wide-stride-vfp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v7clrex = Feature{
    .name = "v7clrex",
    .description = "Has v7 clrex instruction",
    .llvm_name = "v7clrex",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vfp2 = Feature{
    .name = "vfp2",
    .description = "Enable VFP2 instructions",
    .llvm_name = "vfp2",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp2sp = Feature{
    .name = "vfp2sp",
    .description = "Enable VFP2 instructions with no double precision",
    .llvm_name = "vfp2sp",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3 = Feature{
    .name = "vfp3",
    .description = "Enable VFP3 instructions",
    .llvm_name = "vfp3",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vfp3d16 = Feature{
    .name = "vfp3d16",
    .description = "Enable VFP3 instructions with only 16 d-registers",
    .llvm_name = "vfp3d16",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3d16sp = Feature{
    .name = "vfp3d16sp",
    .description = "Enable VFP3 instructions with only 16 d-registers and no double precision",
    .llvm_name = "vfp3d16sp",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3sp = Feature{
    .name = "vfp3sp",
    .description = "Enable VFP3 instructions with no double precision",
    .llvm_name = "vfp3sp",
    .subfeatures = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vfp4 = Feature{
    .name = "vfp4",
    .description = "Enable VFP4 instructions",
    .llvm_name = "vfp4",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vfp4d16 = Feature{
    .name = "vfp4d16",
    .description = "Enable VFP4 instructions with only 16 d-registers",
    .llvm_name = "vfp4d16",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4d16sp = Feature{
    .name = "vfp4d16sp",
    .description = "Enable VFP4 instructions with only 16 d-registers and no double precision",
    .llvm_name = "vfp4d16sp",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4sp = Feature{
    .name = "vfp4sp",
    .description = "Enable VFP4 instructions with no double precision",
    .llvm_name = "vfp4sp",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vmlxForwarding = Feature{
    .name = "vmlx-forwarding",
    .description = "Has multiplier accumulator forwarding",
    .llvm_name = "vmlx-forwarding",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_virtualization = Feature{
    .name = "virtualization",
    .description = "Supports Virtualization extension",
    .llvm_name = "virtualization",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_hwdivArm,
    },
};

pub const feature_zcz = Feature{
    .name = "zcz",
    .description = "Has zero-cycle zeroing instructions",
    .llvm_name = "zcz",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mvefp = Feature{
    .name = "mve.fp",
    .description = "Support M-Class Vector Extension with integer and floating ops",
    .llvm_name = "mve.fp",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_dsp,
        &feature_perfmon,
        &feature_fpregs,
    },
};

pub const feature_mve = Feature{
    .name = "mve",
    .description = "Support M-Class Vector Extension with integer ops",
    .llvm_name = "mve",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_fpregs,
    },
};

pub const feature_v4t = Feature{
    .name = "v4t",
    .description = "Support ARM v4T instructions",
    .llvm_name = "v4t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v5te = Feature{
    .name = "v5te",
    .description = "Support ARM v5TE, v5TEj, and v5TExp instructions",
    .llvm_name = "v5te",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v5t = Feature{
    .name = "v5t",
    .description = "Support ARM v5T instructions",
    .llvm_name = "v5t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v6k = Feature{
    .name = "v6k",
    .description = "Support ARM v6k instructions",
    .llvm_name = "v6k",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v6m = Feature{
    .name = "v6m",
    .description = "Support ARM v6M instructions",
    .llvm_name = "v6m",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v6 = Feature{
    .name = "v6",
    .description = "Support ARM v6 instructions",
    .llvm_name = "v6",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v6t2 = Feature{
    .name = "v6t2",
    .description = "Support ARM v6t2 instructions",
    .llvm_name = "v6t2",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_thumb2,
    },
};

pub const feature_v7 = Feature{
    .name = "v7",
    .description = "Support ARM v7 instructions",
    .llvm_name = "v7",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_thumb2,
    },
};

pub const feature_v8m = Feature{
    .name = "v8m",
    .description = "Support ARM v8M Baseline instructions",
    .llvm_name = "v8m",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_v8mmain = Feature{
    .name = "v8m.main",
    .description = "Support ARM v8M Mainline instructions",
    .llvm_name = "v8m.main",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_perfmon,
        &feature_v7clrex,
        &feature_thumb2,
    },
};

pub const feature_v8 = Feature{
    .name = "v8",
    .description = "Support ARM v8 instructions",
    .llvm_name = "v8",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_perfmon,
    },
};

pub const feature_v81mmain = Feature{
    .name = "v8.1m.main",
    .description = "Support ARM v8-1M Mainline instructions",
    .llvm_name = "v8.1m.main",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_thumb2,
    },
};

pub const feature_v81a = Feature{
    .name = "v8.1a",
    .description = "Support ARM v8.1a instructions",
    .llvm_name = "v8.1a",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_perfmon,
    },
};

pub const feature_v82a = Feature{
    .name = "v8.2a",
    .description = "Support ARM v8.2a instructions",
    .llvm_name = "v8.2a",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_perfmon,
    },
};

pub const feature_v83a = Feature{
    .name = "v8.3a",
    .description = "Support ARM v8.3a instructions",
    .llvm_name = "v8.3a",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_perfmon,
    },
};

pub const feature_v84a = Feature{
    .name = "v8.4a",
    .description = "Support ARM v8.4a instructions",
    .llvm_name = "v8.4a",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_perfmon,
        &feature_fpregs,
    },
};

pub const feature_v85a = Feature{
    .name = "v8.5a",
    .description = "Support ARM v8.5a instructions",
    .llvm_name = "v8.5a",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_sb,
        &feature_perfmon,
        &feature_fpregs,
    },
};

pub const feature_iwmmxt = Feature{
    .name = "iwmmxt",
    .description = "ARMv5te architecture",
    .llvm_name = "iwmmxt",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_iwmmxt2 = Feature{
    .name = "iwmmxt2",
    .description = "ARMv5te architecture",
    .llvm_name = "iwmmxt2",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const feature_softFloat = Feature{
    .name = "soft-float",
    .description = "Use software floating point features.",
    .llvm_name = "soft-float",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_thumbMode = Feature{
    .name = "thumb-mode",
    .description = "Thumb mode",
    .llvm_name = "thumb-mode",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a5 = Feature{
    .name = "a5",
    .description = "Cortex-A5 ARM processors",
    .llvm_name = "a5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a7 = Feature{
    .name = "a7",
    .description = "Cortex-A7 ARM processors",
    .llvm_name = "a7",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a8 = Feature{
    .name = "a8",
    .description = "Cortex-A8 ARM processors",
    .llvm_name = "a8",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a9 = Feature{
    .name = "a9",
    .description = "Cortex-A9 ARM processors",
    .llvm_name = "a9",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a12 = Feature{
    .name = "a12",
    .description = "Cortex-A12 ARM processors",
    .llvm_name = "a12",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a15 = Feature{
    .name = "a15",
    .description = "Cortex-A15 ARM processors",
    .llvm_name = "a15",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a17 = Feature{
    .name = "a17",
    .description = "Cortex-A17 ARM processors",
    .llvm_name = "a17",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a32 = Feature{
    .name = "a32",
    .description = "Cortex-A32 ARM processors",
    .llvm_name = "a32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a35 = Feature{
    .name = "a35",
    .description = "Cortex-A35 ARM processors",
    .llvm_name = "a35",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a53 = Feature{
    .name = "a53",
    .description = "Cortex-A53 ARM processors",
    .llvm_name = "a53",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a55 = Feature{
    .name = "a55",
    .description = "Cortex-A55 ARM processors",
    .llvm_name = "a55",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a57 = Feature{
    .name = "a57",
    .description = "Cortex-A57 ARM processors",
    .llvm_name = "a57",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a72 = Feature{
    .name = "a72",
    .description = "Cortex-A72 ARM processors",
    .llvm_name = "a72",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a73 = Feature{
    .name = "a73",
    .description = "Cortex-A73 ARM processors",
    .llvm_name = "a73",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a75 = Feature{
    .name = "a75",
    .description = "Cortex-A75 ARM processors",
    .llvm_name = "a75",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_a76 = Feature{
    .name = "a76",
    .description = "Cortex-A76 ARM processors",
    .llvm_name = "a76",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_exynos = Feature{
    .name = "exynos",
    .description = "Samsung Exynos processors",
    .llvm_name = "exynos",
    .subfeatures = &[_]*const Feature {
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_hwdiv,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_d32,
        &feature_hwdivArm,
        &feature_retAddrStack,
        &feature_crc,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fpregs,
        &feature_fuseLiterals,
    },
};

pub const feature_krait = Feature{
    .name = "krait",
    .description = "Qualcomm Krait processors",
    .llvm_name = "krait",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_kryo = Feature{
    .name = "kryo",
    .description = "Qualcomm Kryo processors",
    .llvm_name = "kryo",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_m3 = Feature{
    .name = "m3",
    .description = "Cortex-M3 ARM processors",
    .llvm_name = "m3",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_r4 = Feature{
    .name = "r4",
    .description = "Cortex-R4 ARM processors",
    .llvm_name = "r4",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_r5 = Feature{
    .name = "r5",
    .description = "Cortex-R5 ARM processors",
    .llvm_name = "r5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_r7 = Feature{
    .name = "r7",
    .description = "Cortex-R7 ARM processors",
    .llvm_name = "r7",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_r52 = Feature{
    .name = "r52",
    .description = "Cortex-R52 ARM processors",
    .llvm_name = "r52",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_swift = Feature{
    .name = "swift",
    .description = "Swift ARM processors",
    .llvm_name = "swift",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_xscale = Feature{
    .name = "xscale",
    .description = "ARMv5te architecture",
    .llvm_name = "xscale",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
    },
};

pub const features = &[_]*const Feature {
    &feature_armv2,
    &feature_armv2a,
    &feature_armv3,
    &feature_armv3m,
    &feature_armv4,
    &feature_armv4t,
    &feature_armv5t,
    &feature_armv5te,
    &feature_armv5tej,
    &feature_armv6,
    &feature_armv6j,
    &feature_armv6k,
    &feature_armv6kz,
    &feature_armv6M,
    &feature_armv6sM,
    &feature_armv6t2,
    &feature_armv7A,
    &feature_armv7eM,
    &feature_armv7k,
    &feature_armv7M,
    &feature_armv7R,
    &feature_armv7s,
    &feature_armv7ve,
    &feature_armv8A,
    &feature_armv8Mbase,
    &feature_armv8Mmain,
    &feature_armv8R,
    &feature_armv81A,
    &feature_armv81Mmain,
    &feature_armv82A,
    &feature_armv83A,
    &feature_armv84A,
    &feature_armv85A,
    &feature_msecext8,
    &feature_aclass,
    &feature_aes,
    &feature_acquireRelease,
    &feature_avoidMovsShop,
    &feature_avoidPartialCpsr,
    &feature_crc,
    &feature_cheapPredicableCpsr,
    &feature_vldnAlign,
    &feature_crypto,
    &feature_d32,
    &feature_db,
    &feature_dfb,
    &feature_dsp,
    &feature_dontWidenVmovs,
    &feature_dotprod,
    &feature_executeOnly,
    &feature_expandFpMlx,
    &feature_fp16,
    &feature_fp16fml,
    &feature_fp64,
    &feature_fpao,
    &feature_fpArmv8,
    &feature_fpArmv8d16,
    &feature_fpArmv8d16sp,
    &feature_fpArmv8sp,
    &feature_fpregs,
    &feature_fpregs16,
    &feature_fpregs64,
    &feature_fullfp16,
    &feature_fuseAes,
    &feature_fuseLiterals,
    &feature_hwdivArm,
    &feature_hwdiv,
    &feature_noBranchPredictor,
    &feature_retAddrStack,
    &feature_slowfpvmlx,
    &feature_vmlxHazards,
    &feature_lob,
    &feature_longCalls,
    &feature_mclass,
    &feature_mp,
    &feature_mve1beat,
    &feature_mve2beat,
    &feature_mve4beat,
    &feature_muxedUnits,
    &feature_neon,
    &feature_neonfp,
    &feature_neonFpmovs,
    &feature_naclTrap,
    &feature_noarm,
    &feature_noMovt,
    &feature_noNegImmediates,
    &feature_disablePostraScheduler,
    &feature_nonpipelinedVfp,
    &feature_perfmon,
    &feature_bit32,
    &feature_preferIshst,
    &feature_loopAlign,
    &feature_preferVmovsr,
    &feature_profUnpr,
    &feature_ras,
    &feature_rclass,
    &feature_readTpHard,
    &feature_reserveR9,
    &feature_sb,
    &feature_sha2,
    &feature_slowFpBrcc,
    &feature_slowLoadDSubreg,
    &feature_slowOddReg,
    &feature_slowVdup32,
    &feature_slowVgetlni32,
    &feature_splatVfpNeon,
    &feature_strictAlign,
    &feature_thumb2,
    &feature_trustzone,
    &feature_useAa,
    &feature_useMisched,
    &feature_wideStrideVfp,
    &feature_v7clrex,
    &feature_vfp2,
    &feature_vfp2sp,
    &feature_vfp3,
    &feature_vfp3d16,
    &feature_vfp3d16sp,
    &feature_vfp3sp,
    &feature_vfp4,
    &feature_vfp4d16,
    &feature_vfp4d16sp,
    &feature_vfp4sp,
    &feature_vmlxForwarding,
    &feature_virtualization,
    &feature_zcz,
    &feature_mvefp,
    &feature_mve,
    &feature_v4t,
    &feature_v5te,
    &feature_v5t,
    &feature_v6k,
    &feature_v6m,
    &feature_v6,
    &feature_v6t2,
    &feature_v7,
    &feature_v8m,
    &feature_v8mmain,
    &feature_v8,
    &feature_v81mmain,
    &feature_v81a,
    &feature_v82a,
    &feature_v83a,
    &feature_v84a,
    &feature_v85a,
    &feature_iwmmxt,
    &feature_iwmmxt2,
    &feature_softFloat,
    &feature_thumbMode,
    &feature_a5,
    &feature_a7,
    &feature_a8,
    &feature_a9,
    &feature_a12,
    &feature_a15,
    &feature_a17,
    &feature_a32,
    &feature_a35,
    &feature_a53,
    &feature_a55,
    &feature_a57,
    &feature_a72,
    &feature_a73,
    &feature_a75,
    &feature_a76,
    &feature_exynos,
    &feature_krait,
    &feature_kryo,
    &feature_m3,
    &feature_r4,
    &feature_r5,
    &feature_r7,
    &feature_r52,
    &feature_swift,
    &feature_xscale,
};

pub const cpu_arm1020e = Cpu{
    .name = "arm1020e",
    .llvm_name = "arm1020e",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm1020t = Cpu{
    .name = "arm1020t",
    .llvm_name = "arm1020t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5t,
    },
};

pub const cpu_arm1022e = Cpu{
    .name = "arm1022e",
    .llvm_name = "arm1022e",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm10e = Cpu{
    .name = "arm10e",
    .llvm_name = "arm10e",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm10tdmi = Cpu{
    .name = "arm10tdmi",
    .llvm_name = "arm10tdmi",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5t,
    },
};

pub const cpu_arm1136jS = Cpu{
    .name = "arm1136j-s",
    .llvm_name = "arm1136j-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
        &feature_armv6,
    },
};

pub const cpu_arm1136jfS = Cpu{
    .name = "arm1136jf-s",
    .llvm_name = "arm1136jf-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
        &feature_armv6,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1156t2S = Cpu{
    .name = "arm1156t2-s",
    .llvm_name = "arm1156t2-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
        &feature_thumb2,
        &feature_armv6t2,
    },
};

pub const cpu_arm1156t2fS = Cpu{
    .name = "arm1156t2f-s",
    .llvm_name = "arm1156t2f-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_dsp,
        &feature_thumb2,
        &feature_armv6t2,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1176jS = Cpu{
    .name = "arm1176j-s",
    .llvm_name = "arm1176j-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_trustzone,
        &feature_armv6kz,
    },
};

pub const cpu_arm1176jzS = Cpu{
    .name = "arm1176jz-s",
    .llvm_name = "arm1176jz-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_trustzone,
        &feature_armv6kz,
    },
};

pub const cpu_arm1176jzfS = Cpu{
    .name = "arm1176jzf-s",
    .llvm_name = "arm1176jzf-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_trustzone,
        &feature_armv6kz,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm710t = Cpu{
    .name = "arm710t",
    .llvm_name = "arm710t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm720t = Cpu{
    .name = "arm720t",
    .llvm_name = "arm720t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm7tdmi = Cpu{
    .name = "arm7tdmi",
    .llvm_name = "arm7tdmi",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm7tdmiS = Cpu{
    .name = "arm7tdmi-s",
    .llvm_name = "arm7tdmi-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm8 = Cpu{
    .name = "arm8",
    .llvm_name = "arm8",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_arm810 = Cpu{
    .name = "arm810",
    .llvm_name = "arm810",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_arm9 = Cpu{
    .name = "arm9",
    .llvm_name = "arm9",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm920 = Cpu{
    .name = "arm920",
    .llvm_name = "arm920",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm920t = Cpu{
    .name = "arm920t",
    .llvm_name = "arm920t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm922t = Cpu{
    .name = "arm922t",
    .llvm_name = "arm922t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm926ejS = Cpu{
    .name = "arm926ej-s",
    .llvm_name = "arm926ej-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm940t = Cpu{
    .name = "arm940t",
    .llvm_name = "arm940t",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_arm946eS = Cpu{
    .name = "arm946e-s",
    .llvm_name = "arm946e-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm966eS = Cpu{
    .name = "arm966e-s",
    .llvm_name = "arm966e-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm968eS = Cpu{
    .name = "arm968e-s",
    .llvm_name = "arm968e-s",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm9e = Cpu{
    .name = "arm9e",
    .llvm_name = "arm9e",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_arm9tdmi = Cpu{
    .name = "arm9tdmi",
    .llvm_name = "arm9tdmi",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_cortexA12 = Cpu{
    .name = "cortex-a12",
    .llvm_name = "cortex-a12",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_mp,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_vmlxForwarding,
        &feature_hwdiv,
        &feature_hwdivArm,
        &feature_virtualization,
        &feature_a12,
    },
};

pub const cpu_cortexA15 = Cpu{
    .name = "cortex-a15",
    .llvm_name = "cortex-a15",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidPartialCpsr,
        &feature_vldnAlign,
        &feature_dontWidenVmovs,
        &feature_retAddrStack,
        &feature_mp,
        &feature_muxedUnits,
        &feature_splatVfpNeon,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_hwdiv,
        &feature_hwdivArm,
        &feature_virtualization,
        &feature_a15,
    },
};

pub const cpu_cortexA17 = Cpu{
    .name = "cortex-a17",
    .llvm_name = "cortex-a17",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_mp,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_vmlxForwarding,
        &feature_hwdiv,
        &feature_hwdivArm,
        &feature_virtualization,
        &feature_a17,
    },
};

pub const cpu_cortexA32 = Cpu{
    .name = "cortex-a32",
    .llvm_name = "cortex-a32",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
    },
};

pub const cpu_cortexA35 = Cpu{
    .name = "cortex-a35",
    .llvm_name = "cortex-a35",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
        &feature_a35,
    },
};

pub const cpu_cortexA5 = Cpu{
    .name = "cortex-a5",
    .llvm_name = "cortex-a5",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_mp,
        &feature_slowFpBrcc,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_vmlxForwarding,
        &feature_a5,
    },
};

pub const cpu_cortexA53 = Cpu{
    .name = "cortex-a53",
    .llvm_name = "cortex-a53",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
        &feature_fpao,
        &feature_a53,
    },
};

pub const cpu_cortexA55 = Cpu{
    .name = "cortex-a55",
    .llvm_name = "cortex-a55",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_dotprod,
        &feature_a55,
    },
};

pub const cpu_cortexA57 = Cpu{
    .name = "cortex-a57",
    .llvm_name = "cortex-a57",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_avoidPartialCpsr,
        &feature_cheapPredicableCpsr,
        &feature_crypto,
        &feature_fpao,
        &feature_a57,
    },
};

pub const cpu_cortexA7 = Cpu{
    .name = "cortex-a7",
    .llvm_name = "cortex-a7",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_vmlxHazards,
        &feature_mp,
        &feature_slowFpBrcc,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_vmlxForwarding,
        &feature_hwdiv,
        &feature_hwdivArm,
        &feature_virtualization,
        &feature_a7,
    },
};

pub const cpu_cortexA72 = Cpu{
    .name = "cortex-a72",
    .llvm_name = "cortex-a72",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
        &feature_a72,
    },
};

pub const cpu_cortexA73 = Cpu{
    .name = "cortex-a73",
    .llvm_name = "cortex-a73",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
        &feature_a73,
    },
};

pub const cpu_cortexA75 = Cpu{
    .name = "cortex-a75",
    .llvm_name = "cortex-a75",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_dotprod,
        &feature_a75,
    },
};

pub const cpu_cortexA76 = Cpu{
    .name = "cortex-a76",
    .llvm_name = "cortex-a76",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_a76,
    },
};

pub const cpu_cortexA76ae = Cpu{
    .name = "cortex-a76ae",
    .llvm_name = "cortex-a76ae",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_a76,
    },
};

pub const cpu_cortexA8 = Cpu{
    .name = "cortex-a8",
    .llvm_name = "cortex-a8",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_vmlxHazards,
        &feature_nonpipelinedVfp,
        &feature_slowFpBrcc,
        &feature_trustzone,
        &feature_vmlxForwarding,
        &feature_a8,
    },
};

pub const cpu_cortexA9 = Cpu{
    .name = "cortex-a9",
    .llvm_name = "cortex-a9",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidPartialCpsr,
        &feature_vldnAlign,
        &feature_expandFpMlx,
        &feature_fp16,
        &feature_retAddrStack,
        &feature_vmlxHazards,
        &feature_mp,
        &feature_muxedUnits,
        &feature_neonFpmovs,
        &feature_preferVmovsr,
        &feature_trustzone,
        &feature_vmlxForwarding,
        &feature_a9,
    },
};

pub const cpu_cortexM0 = Cpu{
    .name = "cortex-m0",
    .llvm_name = "cortex-m0",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_armv6M,
    },
};

pub const cpu_cortexM0plus = Cpu{
    .name = "cortex-m0plus",
    .llvm_name = "cortex-m0plus",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_armv6M,
    },
};

pub const cpu_cortexM1 = Cpu{
    .name = "cortex-m1",
    .llvm_name = "cortex-m1",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_armv6M,
    },
};

pub const cpu_cortexM23 = Cpu{
    .name = "cortex-m23",
    .llvm_name = "cortex-m23",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_hwdiv,
        &feature_armv8Mbase,
        &feature_noMovt,
    },
};

pub const cpu_cortexM3 = Cpu{
    .name = "cortex-m3",
    .llvm_name = "cortex-m3",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_armv7M,
        &feature_noBranchPredictor,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
        &feature_m3,
    },
};

pub const cpu_cortexM33 = Cpu{
    .name = "cortex-m33",
    .llvm_name = "cortex-m33",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_armv8Mmain,
        &feature_dsp,
        &feature_fp16,
        &feature_fpregs,
        &feature_fpArmv8d16sp,
        &feature_noBranchPredictor,
        &feature_slowfpvmlx,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexM35p = Cpu{
    .name = "cortex-m35p",
    .llvm_name = "cortex-m35p",
    .subfeatures = &[_]*const Feature {
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_db,
        &feature_msecext8,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_armv8Mmain,
        &feature_dsp,
        &feature_fp16,
        &feature_fpregs,
        &feature_fpArmv8d16sp,
        &feature_noBranchPredictor,
        &feature_slowfpvmlx,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexM4 = Cpu{
    .name = "cortex-m4",
    .llvm_name = "cortex-m4",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_armv7eM,
        &feature_noBranchPredictor,
        &feature_slowfpvmlx,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
        &feature_fp16,
        &feature_fpregs,
        &feature_vfp4d16sp,
    },
};

pub const cpu_cortexM7 = Cpu{
    .name = "cortex-m7",
    .llvm_name = "cortex-m7",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_armv7eM,
        &feature_fp16,
        &feature_fpregs,
        &feature_fpArmv8d16,
    },
};

pub const cpu_cortexR4 = Cpu{
    .name = "cortex-r4",
    .llvm_name = "cortex-r4",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
        &feature_armv7R,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_r4,
    },
};

pub const cpu_cortexR4f = Cpu{
    .name = "cortex-r4f",
    .llvm_name = "cortex-r4f",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
        &feature_armv7R,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
        &feature_r4,
    },
};

pub const cpu_cortexR5 = Cpu{
    .name = "cortex-r5",
    .llvm_name = "cortex-r5",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
        &feature_armv7R,
        &feature_avoidPartialCpsr,
        &feature_hwdivArm,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
        &feature_r5,
    },
};

pub const cpu_cortexR52 = Cpu{
    .name = "cortex-r52",
    .llvm_name = "cortex-r52",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_dfb,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_rclass,
        &feature_armv8R,
        &feature_fpao,
        &feature_useAa,
        &feature_useMisched,
        &feature_r52,
    },
};

pub const cpu_cortexR7 = Cpu{
    .name = "cortex-r7",
    .llvm_name = "cortex-r7",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
        &feature_armv7R,
        &feature_avoidPartialCpsr,
        &feature_fp16,
        &feature_hwdivArm,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_mp,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
        &feature_r7,
    },
};

pub const cpu_cortexR8 = Cpu{
    .name = "cortex-r8",
    .llvm_name = "cortex-r8",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_dsp,
        &feature_hwdiv,
        &feature_rclass,
        &feature_armv7R,
        &feature_avoidPartialCpsr,
        &feature_fp16,
        &feature_hwdivArm,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_mp,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
    },
};

pub const cpu_cyclone = Cpu{
    .name = "cyclone",
    .llvm_name = "cyclone",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_avoidMovsShop,
        &feature_avoidPartialCpsr,
        &feature_crypto,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_neonfp,
        &feature_disablePostraScheduler,
        &feature_useMisched,
        &feature_vfp4,
        &feature_zcz,
        &feature_swift,
    },
};

pub const cpu_ep9312 = Cpu{
    .name = "ep9312",
    .llvm_name = "ep9312",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv4t,
    },
};

pub const cpu_exynosM1 = Cpu{
    .name = "exynos-m1",
    .llvm_name = "exynos-m1",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_retAddrStack,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fuseLiterals,
        &feature_exynos,
    },
};

pub const cpu_exynosM2 = Cpu{
    .name = "exynos-m2",
    .llvm_name = "exynos-m2",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_retAddrStack,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fuseLiterals,
        &feature_exynos,
    },
};

pub const cpu_exynosM3 = Cpu{
    .name = "exynos-m3",
    .llvm_name = "exynos-m3",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_retAddrStack,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fuseLiterals,
        &feature_exynos,
    },
};

pub const cpu_exynosM4 = Cpu{
    .name = "exynos-m4",
    .llvm_name = "exynos-m4",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_retAddrStack,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fuseLiterals,
        &feature_exynos,
    },
};

pub const cpu_exynosM5 = Cpu{
    .name = "exynos-m5",
    .llvm_name = "exynos-m5",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_slowFpBrcc,
        &feature_slowfpvmlx,
        &feature_slowVdup32,
        &feature_wideStrideVfp,
        &feature_fuseAes,
        &feature_slowVgetlni32,
        &feature_zcz,
        &feature_profUnpr,
        &feature_retAddrStack,
        &feature_expandFpMlx,
        &feature_useAa,
        &feature_dontWidenVmovs,
        &feature_fuseLiterals,
        &feature_exynos,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_iwmmxt = Cpu{
    .name = "iwmmxt",
    .llvm_name = "iwmmxt",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpu_krait = Cpu{
    .name = "krait",
    .llvm_name = "krait",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidPartialCpsr,
        &feature_vldnAlign,
        &feature_fp16,
        &feature_hwdivArm,
        &feature_hwdiv,
        &feature_retAddrStack,
        &feature_muxedUnits,
        &feature_vfp4,
        &feature_vmlxForwarding,
        &feature_krait,
    },
};

pub const cpu_kryo = Cpu{
    .name = "kryo",
    .llvm_name = "kryo",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv8A,
        &feature_crypto,
        &feature_kryo,
    },
};

pub const cpu_mpcore = Cpu{
    .name = "mpcore",
    .llvm_name = "mpcore",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv6k,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_mpcorenovfp = Cpu{
    .name = "mpcorenovfp",
    .llvm_name = "mpcorenovfp",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv6k,
    },
};

pub const cpu_neoverseN1 = Cpu{
    .name = "neoverse-n1",
    .llvm_name = "neoverse-n1",
    .subfeatures = &[_]*const Feature {
        &feature_mp,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_trustzone,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_ras,
        &feature_fp16,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_hwdivArm,
        &feature_crc,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv82A,
        &feature_crypto,
        &feature_dotprod,
    },
};

pub const cpu_sc000 = Cpu{
    .name = "sc000",
    .llvm_name = "sc000",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_thumbMode,
        &feature_mclass,
        &feature_noarm,
        &feature_v4t,
        &feature_strictAlign,
        &feature_armv6M,
    },
};

pub const cpu_sc300 = Cpu{
    .name = "sc300",
    .llvm_name = "sc300",
    .subfeatures = &[_]*const Feature {
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_mclass,
        &feature_thumbMode,
        &feature_noarm,
        &feature_v4t,
        &feature_perfmon,
        &feature_hwdiv,
        &feature_armv7M,
        &feature_noBranchPredictor,
        &feature_useAa,
        &feature_useMisched,
        &feature_m3,
    },
};

pub const cpu_strongarm = Cpu{
    .name = "strongarm",
    .llvm_name = "strongarm",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_strongarm110 = Cpu{
    .name = "strongarm110",
    .llvm_name = "strongarm110",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_strongarm1100 = Cpu{
    .name = "strongarm1100",
    .llvm_name = "strongarm1100",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_strongarm1110 = Cpu{
    .name = "strongarm1110",
    .llvm_name = "strongarm1110",
    .subfeatures = &[_]*const Feature {
        &feature_armv4,
    },
};

pub const cpu_swift = Cpu{
    .name = "swift",
    .llvm_name = "swift",
    .subfeatures = &[_]*const Feature {
        &feature_perfmon,
        &feature_v7clrex,
        &feature_db,
        &feature_thumb2,
        &feature_v4t,
        &feature_d32,
        &feature_aclass,
        &feature_dsp,
        &feature_fpregs,
        &feature_armv7A,
        &feature_avoidMovsShop,
        &feature_avoidPartialCpsr,
        &feature_hwdivArm,
        &feature_hwdiv,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_vmlxHazards,
        &feature_mp,
        &feature_neonfp,
        &feature_disablePostraScheduler,
        &feature_preferIshst,
        &feature_profUnpr,
        &feature_slowLoadDSubreg,
        &feature_slowOddReg,
        &feature_slowVdup32,
        &feature_slowVgetlni32,
        &feature_useMisched,
        &feature_wideStrideVfp,
        &feature_fp16,
        &feature_vfp4,
        &feature_swift,
    },
};

pub const cpu_xscale = Cpu{
    .name = "xscale",
    .llvm_name = "xscale",
    .subfeatures = &[_]*const Feature {
        &feature_v4t,
        &feature_armv5te,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_arm1020e,
    &cpu_arm1020t,
    &cpu_arm1022e,
    &cpu_arm10e,
    &cpu_arm10tdmi,
    &cpu_arm1136jS,
    &cpu_arm1136jfS,
    &cpu_arm1156t2S,
    &cpu_arm1156t2fS,
    &cpu_arm1176jS,
    &cpu_arm1176jzS,
    &cpu_arm1176jzfS,
    &cpu_arm710t,
    &cpu_arm720t,
    &cpu_arm7tdmi,
    &cpu_arm7tdmiS,
    &cpu_arm8,
    &cpu_arm810,
    &cpu_arm9,
    &cpu_arm920,
    &cpu_arm920t,
    &cpu_arm922t,
    &cpu_arm926ejS,
    &cpu_arm940t,
    &cpu_arm946eS,
    &cpu_arm966eS,
    &cpu_arm968eS,
    &cpu_arm9e,
    &cpu_arm9tdmi,
    &cpu_cortexA12,
    &cpu_cortexA15,
    &cpu_cortexA17,
    &cpu_cortexA32,
    &cpu_cortexA35,
    &cpu_cortexA5,
    &cpu_cortexA53,
    &cpu_cortexA55,
    &cpu_cortexA57,
    &cpu_cortexA7,
    &cpu_cortexA72,
    &cpu_cortexA73,
    &cpu_cortexA75,
    &cpu_cortexA76,
    &cpu_cortexA76ae,
    &cpu_cortexA8,
    &cpu_cortexA9,
    &cpu_cortexM0,
    &cpu_cortexM0plus,
    &cpu_cortexM1,
    &cpu_cortexM23,
    &cpu_cortexM3,
    &cpu_cortexM33,
    &cpu_cortexM35p,
    &cpu_cortexM4,
    &cpu_cortexM7,
    &cpu_cortexR4,
    &cpu_cortexR4f,
    &cpu_cortexR5,
    &cpu_cortexR52,
    &cpu_cortexR7,
    &cpu_cortexR8,
    &cpu_cyclone,
    &cpu_ep9312,
    &cpu_exynosM1,
    &cpu_exynosM2,
    &cpu_exynosM3,
    &cpu_exynosM4,
    &cpu_exynosM5,
    &cpu_generic,
    &cpu_iwmmxt,
    &cpu_krait,
    &cpu_kryo,
    &cpu_mpcore,
    &cpu_mpcorenovfp,
    &cpu_neoverseN1,
    &cpu_sc000,
    &cpu_sc300,
    &cpu_strongarm,
    &cpu_strongarm110,
    &cpu_strongarm1100,
    &cpu_strongarm1110,
    &cpu_swift,
    &cpu_xscale,
};
