const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_msecext8 = Feature{
    .name = "8msecext",
    .description = "Enable support for ARMv8-M Security Extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_aclass = Feature{
    .name = "aclass",
    .description = "Is application profile ('A' series)",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_aes = Feature{
    .name = "aes",
    .description = "Enable AES support",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_acquireRelease = Feature{
    .name = "acquire-release",
    .description = "Has v8 acquire/release (lda/ldaex  etc) instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_avoidMovsShop = Feature{
    .name = "avoid-movs-shop",
    .description = "Avoid movs instructions with shifter operand",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_avoidPartialCpsr = Feature{
    .name = "avoid-partial-cpsr",
    .description = "Avoid CPSR partial update for OOO execution",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crc = Feature{
    .name = "crc",
    .description = "Enable support for CRC instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_cheapPredicableCpsr = Feature{
    .name = "cheap-predicable-cpsr",
    .description = "Disable +1 predication cost for instructions updating CPSR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vldnAlign = Feature{
    .name = "vldn-align",
    .description = "Check for VLDn unaligned access",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .description = "Enable support for Cryptography extensions",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_d32 = Feature{
    .name = "d32",
    .description = "Extend FP to 32 double registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_db = Feature{
    .name = "db",
    .description = "Has data barrier (dmb/dsb) instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dfb = Feature{
    .name = "dfb",
    .description = "Has full data barrier (dfb) instruction",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dsp = Feature{
    .name = "dsp",
    .description = "Supports DSP instructions in ARM and/or Thumb2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dontWidenVmovs = Feature{
    .name = "dont-widen-vmovs",
    .description = "Don't widen VMOVS to VMOVD",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dotprod = Feature{
    .name = "dotprod",
    .description = "Enable support for dot product instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_executeOnly = Feature{
    .name = "execute-only",
    .description = "Enable the generation of execute only code.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_expandFpMlx = Feature{
    .name = "expand-fp-mlx",
    .description = "Expand VFP/NEON MLA/MLS instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp16 = Feature{
    .name = "fp16",
    .description = "Enable half-precision floating point",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp16fml = Feature{
    .name = "fp16fml",
    .description = "Enable full half-precision floating point fml instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fp64 = Feature{
    .name = "fp64",
    .description = "Floating point unit supports double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpao = Feature{
    .name = "fpao",
    .description = "Enable fast computation of positive address offsets",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpArmv8 = Feature{
    .name = "fp-armv8",
    .description = "Enable ARMv8 FP",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_fpArmv8d16 = Feature{
    .name = "fp-armv8d16",
    .description = "Enable ARMv8 FP with only 16 d-registers",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8d16sp = Feature{
    .name = "fp-armv8d16sp",
    .description = "Enable ARMv8 FP with only 16 d-registers and no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8sp = Feature{
    .name = "fp-armv8sp",
    .description = "Enable ARMv8 FP with no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_fpregs = Feature{
    .name = "fpregs",
    .description = "Enable FP registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpregs16 = Feature{
    .name = "fpregs16",
    .description = "Enable 16-bit FP registers",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpregs64 = Feature{
    .name = "fpregs64",
    .description = "Enable 64-bit FP registers",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fullfp16 = Feature{
    .name = "fullfp16",
    .description = "Enable full half-precision floating point",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fuseAes = Feature{
    .name = "fuse-aes",
    .description = "CPU fuses AES crypto operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseLiterals = Feature{
    .name = "fuse-literals",
    .description = "CPU fuses literal generation operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwdivArm = Feature{
    .name = "hwdiv-arm",
    .description = "Enable divide instructions in ARM mode",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hwdiv = Feature{
    .name = "hwdiv",
    .description = "Enable divide instructions in Thumb",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noBranchPredictor = Feature{
    .name = "no-branch-predictor",
    .description = "Has no branch predictor",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_retAddrStack = Feature{
    .name = "ret-addr-stack",
    .description = "Has return address stack",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowfpvmlx = Feature{
    .name = "slowfpvmlx",
    .description = "Disable VFP / NEON MAC instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vmlxHazards = Feature{
    .name = "vmlx-hazards",
    .description = "Has VMLx hazards",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_lob = Feature{
    .name = "lob",
    .description = "Enable Low Overhead Branch extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "long-calls",
    .description = "Generate calls via indirect call instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mclass = Feature{
    .name = "mclass",
    .description = "Is microcontroller profile ('M' series)",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mp = Feature{
    .name = "mp",
    .description = "Supports Multiprocessing extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve1beat = Feature{
    .name = "mve1beat",
    .description = "Model MVE instructions as a 1 beat per tick architecture",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve2beat = Feature{
    .name = "mve2beat",
    .description = "Model MVE instructions as a 2 beats per tick architecture",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mve4beat = Feature{
    .name = "mve4beat",
    .description = "Model MVE instructions as a 4 beats per tick architecture",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_muxedUnits = Feature{
    .name = "muxed-units",
    .description = "Has muxed AGU and NEON/FPU",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_neon = Feature{
    .name = "neon",
    .description = "Enable NEON instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_neonfp = Feature{
    .name = "neonfp",
    .description = "Use NEON for single precision FP",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_neonFpmovs = Feature{
    .name = "neon-fpmovs",
    .description = "Convert VMOVSR, VMOVRS, VMOVS to NEON",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_naclTrap = Feature{
    .name = "nacl-trap",
    .description = "NaCl trap",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noarm = Feature{
    .name = "noarm",
    .description = "Does not support ARM mode execution",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noMovt = Feature{
    .name = "no-movt",
    .description = "Don't use movt/movw pairs for 32-bit imms",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noNegImmediates = Feature{
    .name = "no-neg-immediates",
    .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_disablePostraScheduler = Feature{
    .name = "disable-postra-scheduler",
    .description = "Don't schedule again after register allocation",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nonpipelinedVfp = Feature{
    .name = "nonpipelined-vfp",
    .description = "VFP instructions are not pipelined",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_perfmon = Feature{
    .name = "perfmon",
    .description = "Enable support for Performance Monitor extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_bit32 = Feature{
    .name = "32bit",
    .description = "Prefer 32-bit Thumb instrs",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_preferIshst = Feature{
    .name = "prefer-ishst",
    .description = "Prefer ISHST barriers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loopAlign = Feature{
    .name = "loop-align",
    .description = "Prefer 32-bit alignment for loops",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_preferVmovsr = Feature{
    .name = "prefer-vmovsr",
    .description = "Prefer VMOVSR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_profUnpr = Feature{
    .name = "prof-unpr",
    .description = "Is profitable to unpredicate",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ras = Feature{
    .name = "ras",
    .description = "Enable Reliability, Availability and Serviceability extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rclass = Feature{
    .name = "rclass",
    .description = "Is realtime profile ('R' series)",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_readTpHard = Feature{
    .name = "read-tp-hard",
    .description = "Reading thread pointer from register",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveR9 = Feature{
    .name = "reserve-r9",
    .description = "Reserve R9, making it unavailable as GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sb = Feature{
    .name = "sb",
    .description = "Enable v8.5a Speculation Barrier",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sha2 = Feature{
    .name = "sha2",
    .description = "Enable SHA1 and SHA256 support",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_slowFpBrcc = Feature{
    .name = "slow-fp-brcc",
    .description = "FP compare + branch is slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowLoadDSubreg = Feature{
    .name = "slow-load-D-subreg",
    .description = "Loading into D subregs is slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowOddReg = Feature{
    .name = "slow-odd-reg",
    .description = "VLDM/VSTM starting with an odd register is slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowVdup32 = Feature{
    .name = "slow-vdup32",
    .description = "Has slow VDUP32 - prefer VMOV",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowVgetlni32 = Feature{
    .name = "slow-vgetlni32",
    .description = "Has slow VGETLNi32 - prefer VMOV",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_splatVfpNeon = Feature{
    .name = "splat-vfp-neon",
    .description = "Splat register from VFP to NEON",
    .subfeatures = &[_]*const Feature {
        &feature_dontWidenVmovs,
    },
};

pub const feature_strictAlign = Feature{
    .name = "strict-align",
    .description = "Disallow all unaligned memory access",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_thumb2 = Feature{
    .name = "thumb2",
    .description = "Enable Thumb2 instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_trustzone = Feature{
    .name = "trustzone",
    .description = "Enable support for TrustZone security extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useAa = Feature{
    .name = "use-aa",
    .description = "Use alias analysis during codegen",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useMisched = Feature{
    .name = "use-misched",
    .description = "Use the MachineScheduler",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_wideStrideVfp = Feature{
    .name = "wide-stride-vfp",
    .description = "Use a wide stride when allocating VFP registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v7clrex = Feature{
    .name = "v7clrex",
    .description = "Has v7 clrex instruction",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vfp2 = Feature{
    .name = "vfp2",
    .description = "Enable VFP2 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp2sp = Feature{
    .name = "vfp2sp",
    .description = "Enable VFP2 instructions with no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3 = Feature{
    .name = "vfp3",
    .description = "Enable VFP3 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp3d16 = Feature{
    .name = "vfp3d16",
    .description = "Enable VFP3 instructions with only 16 d-registers",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3d16sp = Feature{
    .name = "vfp3d16sp",
    .description = "Enable VFP3 instructions with only 16 d-registers and no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3sp = Feature{
    .name = "vfp3sp",
    .description = "Enable VFP3 instructions with no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp4 = Feature{
    .name = "vfp4",
    .description = "Enable VFP4 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp4d16 = Feature{
    .name = "vfp4d16",
    .description = "Enable VFP4 instructions with only 16 d-registers",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4d16sp = Feature{
    .name = "vfp4d16sp",
    .description = "Enable VFP4 instructions with only 16 d-registers and no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4sp = Feature{
    .name = "vfp4sp",
    .description = "Enable VFP4 instructions with no double precision",
    .subfeatures = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vmlxForwarding = Feature{
    .name = "vmlx-forwarding",
    .description = "Has multiplier accumulator forwarding",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_virtualization = Feature{
    .name = "virtualization",
    .description = "Supports Virtualization extension",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_hwdivArm,
    },
};

pub const feature_zcz = Feature{
    .name = "zcz",
    .description = "Has zero-cycle zeroing instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
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
};

pub const cpu_arm1020e = Cpu{
    .name = "arm1020e",
    .llvm_name = "arm1020e",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm1020t = Cpu{
    .name = "arm1020t",
    .llvm_name = "arm1020t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm1022e = Cpu{
    .name = "arm1022e",
    .llvm_name = "arm1022e",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm10e = Cpu{
    .name = "arm10e",
    .llvm_name = "arm10e",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm10tdmi = Cpu{
    .name = "arm10tdmi",
    .llvm_name = "arm10tdmi",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm1136jS = Cpu{
    .name = "arm1136j-s",
    .llvm_name = "arm1136j-s",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
    },
};

pub const cpu_arm1136jfS = Cpu{
    .name = "arm1136jf-s",
    .llvm_name = "arm1136jf-s",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1156t2S = Cpu{
    .name = "arm1156t2-s",
    .llvm_name = "arm1156t2-s",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
        &feature_thumb2,
    },
};

pub const cpu_arm1156t2fS = Cpu{
    .name = "arm1156t2f-s",
    .llvm_name = "arm1156t2f-s",
    .subfeatures = &[_]*const Feature {
        &feature_dsp,
        &feature_thumb2,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1176jS = Cpu{
    .name = "arm1176j-s",
    .llvm_name = "arm1176j-s",
    .subfeatures = &[_]*const Feature {
        &feature_trustzone,
    },
};

pub const cpu_arm1176jzS = Cpu{
    .name = "arm1176jz-s",
    .llvm_name = "arm1176jz-s",
    .subfeatures = &[_]*const Feature {
        &feature_trustzone,
    },
};

pub const cpu_arm1176jzfS = Cpu{
    .name = "arm1176jzf-s",
    .llvm_name = "arm1176jzf-s",
    .subfeatures = &[_]*const Feature {
        &feature_trustzone,
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm710t = Cpu{
    .name = "arm710t",
    .llvm_name = "arm710t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm720t = Cpu{
    .name = "arm720t",
    .llvm_name = "arm720t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm7tdmi = Cpu{
    .name = "arm7tdmi",
    .llvm_name = "arm7tdmi",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm7tdmiS = Cpu{
    .name = "arm7tdmi-s",
    .llvm_name = "arm7tdmi-s",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm8 = Cpu{
    .name = "arm8",
    .llvm_name = "arm8",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm810 = Cpu{
    .name = "arm810",
    .llvm_name = "arm810",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm9 = Cpu{
    .name = "arm9",
    .llvm_name = "arm9",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm920 = Cpu{
    .name = "arm920",
    .llvm_name = "arm920",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm920t = Cpu{
    .name = "arm920t",
    .llvm_name = "arm920t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm922t = Cpu{
    .name = "arm922t",
    .llvm_name = "arm922t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm926ejS = Cpu{
    .name = "arm926ej-s",
    .llvm_name = "arm926ej-s",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm940t = Cpu{
    .name = "arm940t",
    .llvm_name = "arm940t",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm946eS = Cpu{
    .name = "arm946e-s",
    .llvm_name = "arm946e-s",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm966eS = Cpu{
    .name = "arm966e-s",
    .llvm_name = "arm966e-s",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm968eS = Cpu{
    .name = "arm968e-s",
    .llvm_name = "arm968e-s",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm9e = Cpu{
    .name = "arm9e",
    .llvm_name = "arm9e",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arm9tdmi = Cpu{
    .name = "arm9tdmi",
    .llvm_name = "arm9tdmi",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_cortexA12 = Cpu{
    .name = "cortex-a12",
    .llvm_name = "cortex-a12",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_cortexA15 = Cpu{
    .name = "cortex-a15",
    .llvm_name = "cortex-a15",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_cortexA17 = Cpu{
    .name = "cortex-a17",
    .llvm_name = "cortex-a17",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_cortexA32 = Cpu{
    .name = "cortex-a32",
    .llvm_name = "cortex-a32",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
    },
};

pub const cpu_cortexA35 = Cpu{
    .name = "cortex-a35",
    .llvm_name = "cortex-a35",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
    },
};

pub const cpu_cortexA5 = Cpu{
    .name = "cortex-a5",
    .llvm_name = "cortex-a5",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_mp,
        &feature_slowFpBrcc,
        &feature_trustzone,
        &feature_fp16,
        &feature_vfp4,
        &feature_vmlxForwarding,
    },
};

pub const cpu_cortexA53 = Cpu{
    .name = "cortex-a53",
    .llvm_name = "cortex-a53",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
        &feature_fpao,
    },
};

pub const cpu_cortexA55 = Cpu{
    .name = "cortex-a55",
    .llvm_name = "cortex-a55",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_dotprod,
    },
};

pub const cpu_cortexA57 = Cpu{
    .name = "cortex-a57",
    .llvm_name = "cortex-a57",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_avoidPartialCpsr,
        &feature_cheapPredicableCpsr,
        &feature_crypto,
        &feature_fpao,
    },
};

pub const cpu_cortexA7 = Cpu{
    .name = "cortex-a7",
    .llvm_name = "cortex-a7",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_cortexA72 = Cpu{
    .name = "cortex-a72",
    .llvm_name = "cortex-a72",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
    },
};

pub const cpu_cortexA73 = Cpu{
    .name = "cortex-a73",
    .llvm_name = "cortex-a73",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
    },
};

pub const cpu_cortexA75 = Cpu{
    .name = "cortex-a75",
    .llvm_name = "cortex-a75",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_dotprod,
    },
};

pub const cpu_cortexA76 = Cpu{
    .name = "cortex-a76",
    .llvm_name = "cortex-a76",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
    },
};

pub const cpu_cortexA76ae = Cpu{
    .name = "cortex-a76ae",
    .llvm_name = "cortex-a76ae",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
    },
};

pub const cpu_cortexA8 = Cpu{
    .name = "cortex-a8",
    .llvm_name = "cortex-a8",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_vmlxHazards,
        &feature_nonpipelinedVfp,
        &feature_slowFpBrcc,
        &feature_trustzone,
        &feature_vmlxForwarding,
    },
};

pub const cpu_cortexA9 = Cpu{
    .name = "cortex-a9",
    .llvm_name = "cortex-a9",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_cortexM0 = Cpu{
    .name = "cortex-m0",
    .llvm_name = "cortex-m0",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_strictAlign,
        &feature_noarm,
        &feature_mclass,
    },
};

pub const cpu_cortexM0plus = Cpu{
    .name = "cortex-m0plus",
    .llvm_name = "cortex-m0plus",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_strictAlign,
        &feature_noarm,
        &feature_mclass,
    },
};

pub const cpu_cortexM1 = Cpu{
    .name = "cortex-m1",
    .llvm_name = "cortex-m1",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_strictAlign,
        &feature_noarm,
        &feature_mclass,
    },
};

pub const cpu_cortexM23 = Cpu{
    .name = "cortex-m23",
    .llvm_name = "cortex-m23",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_msecext8,
        &feature_db,
        &feature_strictAlign,
        &feature_acquireRelease,
        &feature_noarm,
        &feature_v7clrex,
        &feature_mclass,
        &feature_noMovt,
    },
};

pub const cpu_cortexM3 = Cpu{
    .name = "cortex-m3",
    .llvm_name = "cortex-m3",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_db,
        &feature_perfmon,
        &feature_noarm,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
        &feature_noBranchPredictor,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexM33 = Cpu{
    .name = "cortex-m33",
    .llvm_name = "cortex-m33",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_msecext8,
        &feature_db,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_noarm,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
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
        &feature_hwdiv,
        &feature_msecext8,
        &feature_db,
        &feature_acquireRelease,
        &feature_perfmon,
        &feature_noarm,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
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
        &feature_hwdiv,
        &feature_db,
        &feature_perfmon,
        &feature_noarm,
        &feature_dsp,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
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
        &feature_hwdiv,
        &feature_db,
        &feature_perfmon,
        &feature_noarm,
        &feature_dsp,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
        &feature_fp16,
        &feature_fpregs,
        &feature_fpArmv8d16,
    },
};

pub const cpu_cortexR4 = Cpu{
    .name = "cortex-r4",
    .llvm_name = "cortex-r4",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_db,
        &feature_perfmon,
        &feature_dsp,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
    },
};

pub const cpu_cortexR4f = Cpu{
    .name = "cortex-r4f",
    .llvm_name = "cortex-r4f",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_db,
        &feature_perfmon,
        &feature_dsp,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
    },
};

pub const cpu_cortexR5 = Cpu{
    .name = "cortex-r5",
    .llvm_name = "cortex-r5",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_db,
        &feature_perfmon,
        &feature_dsp,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_avoidPartialCpsr,
        &feature_hwdivArm,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
    },
};

pub const cpu_cortexR52 = Cpu{
    .name = "cortex-r52",
    .llvm_name = "cortex-r52",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_dfb,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_fpao,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexR7 = Cpu{
    .name = "cortex-r7",
    .llvm_name = "cortex-r7",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_db,
        &feature_perfmon,
        &feature_dsp,
        &feature_v7clrex,
        &feature_thumb2,
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

pub const cpu_cortexR8 = Cpu{
    .name = "cortex-r8",
    .llvm_name = "cortex-r8",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_rclass,
        &feature_db,
        &feature_perfmon,
        &feature_dsp,
        &feature_v7clrex,
        &feature_thumb2,
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
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
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
    },
};

pub const cpu_ep9312 = Cpu{
    .name = "ep9312",
    .llvm_name = "ep9312",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_exynosM1 = Cpu{
    .name = "exynos-m1",
    .llvm_name = "exynos-m1",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_slowVdup32,
        &feature_expandFpMlx,
        &feature_slowVgetlni32,
        &feature_fuseLiterals,
        &feature_wideStrideVfp,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_dontWidenVmovs,
        &feature_zcz,
        &feature_fuseAes,
        &feature_slowfpvmlx,
        &feature_profUnpr,
        &feature_useAa,
    },
};

pub const cpu_exynosM2 = Cpu{
    .name = "exynos-m2",
    .llvm_name = "exynos-m2",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_slowVdup32,
        &feature_expandFpMlx,
        &feature_slowVgetlni32,
        &feature_fuseLiterals,
        &feature_wideStrideVfp,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_dontWidenVmovs,
        &feature_zcz,
        &feature_fuseAes,
        &feature_slowfpvmlx,
        &feature_profUnpr,
        &feature_useAa,
    },
};

pub const cpu_exynosM3 = Cpu{
    .name = "exynos-m3",
    .llvm_name = "exynos-m3",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_slowVdup32,
        &feature_expandFpMlx,
        &feature_slowVgetlni32,
        &feature_fuseLiterals,
        &feature_wideStrideVfp,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_dontWidenVmovs,
        &feature_zcz,
        &feature_fuseAes,
        &feature_slowfpvmlx,
        &feature_profUnpr,
        &feature_useAa,
    },
};

pub const cpu_exynosM4 = Cpu{
    .name = "exynos-m4",
    .llvm_name = "exynos-m4",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_slowVdup32,
        &feature_expandFpMlx,
        &feature_slowVgetlni32,
        &feature_fuseLiterals,
        &feature_wideStrideVfp,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_dontWidenVmovs,
        &feature_zcz,
        &feature_fuseAes,
        &feature_slowfpvmlx,
        &feature_profUnpr,
        &feature_useAa,
    },
};

pub const cpu_exynosM5 = Cpu{
    .name = "exynos-m5",
    .llvm_name = "exynos-m5",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_slowVdup32,
        &feature_expandFpMlx,
        &feature_slowVgetlni32,
        &feature_fuseLiterals,
        &feature_wideStrideVfp,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_dontWidenVmovs,
        &feature_zcz,
        &feature_fuseAes,
        &feature_slowfpvmlx,
        &feature_profUnpr,
        &feature_useAa,
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
    },
};

pub const cpu_krait = Cpu{
    .name = "krait",
    .llvm_name = "krait",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
        &feature_avoidPartialCpsr,
        &feature_vldnAlign,
        &feature_fp16,
        &feature_hwdivArm,
        &feature_hwdiv,
        &feature_retAddrStack,
        &feature_muxedUnits,
        &feature_vfp4,
        &feature_vmlxForwarding,
    },
};

pub const cpu_kryo = Cpu{
    .name = "kryo",
    .llvm_name = "kryo",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
    },
};

pub const cpu_mpcore = Cpu{
    .name = "mpcore",
    .llvm_name = "mpcore",
    .subfeatures = &[_]*const Feature {
        &feature_slowfpvmlx,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_mpcorenovfp = Cpu{
    .name = "mpcorenovfp",
    .llvm_name = "mpcorenovfp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_neoverseN1 = Cpu{
    .name = "neoverse-n1",
    .llvm_name = "neoverse-n1",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_trustzone,
        &feature_fpregs,
        &feature_db,
        &feature_acquireRelease,
        &feature_d32,
        &feature_perfmon,
        &feature_mp,
        &feature_ras,
        &feature_hwdivArm,
        &feature_dsp,
        &feature_aclass,
        &feature_fp16,
        &feature_v7clrex,
        &feature_crc,
        &feature_thumb2,
        &feature_crypto,
        &feature_dotprod,
    },
};

pub const cpu_sc000 = Cpu{
    .name = "sc000",
    .llvm_name = "sc000",
    .subfeatures = &[_]*const Feature {
        &feature_db,
        &feature_strictAlign,
        &feature_noarm,
        &feature_mclass,
    },
};

pub const cpu_sc300 = Cpu{
    .name = "sc300",
    .llvm_name = "sc300",
    .subfeatures = &[_]*const Feature {
        &feature_hwdiv,
        &feature_db,
        &feature_perfmon,
        &feature_noarm,
        &feature_v7clrex,
        &feature_mclass,
        &feature_thumb2,
        &feature_noBranchPredictor,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_strongarm = Cpu{
    .name = "strongarm",
    .llvm_name = "strongarm",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_strongarm110 = Cpu{
    .name = "strongarm110",
    .llvm_name = "strongarm110",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_strongarm1100 = Cpu{
    .name = "strongarm1100",
    .llvm_name = "strongarm1100",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_strongarm1110 = Cpu{
    .name = "strongarm1110",
    .llvm_name = "strongarm1110",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_swift = Cpu{
    .name = "swift",
    .llvm_name = "swift",
    .subfeatures = &[_]*const Feature {
        &feature_fpregs,
        &feature_db,
        &feature_d32,
        &feature_perfmon,
        &feature_dsp,
        &feature_aclass,
        &feature_v7clrex,
        &feature_thumb2,
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
    },
};

pub const cpu_xscale = Cpu{
    .name = "xscale",
    .llvm_name = "xscale",
    .subfeatures = &[_]*const Feature {
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
