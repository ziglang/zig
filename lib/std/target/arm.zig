const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_msecext8 = Feature{
    .name = "msecext8",
    .llvm_name = "8msecext",
    .description = "Enable support for ARMv8-M Security Extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_aclass = Feature{
    .name = "aclass",
    .llvm_name = "aclass",
    .description = "Is application profile ('A' series)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_aes = Feature{
    .name = "aes",
    .llvm_name = "aes",
    .description = "Enable AES support",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_acquireRelease = Feature{
    .name = "acquireRelease",
    .llvm_name = "acquire-release",
    .description = "Has v8 acquire/release (lda/ldaex  etc) instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avoidMovsShop = Feature{
    .name = "avoidMovsShop",
    .llvm_name = "avoid-movs-shop",
    .description = "Avoid movs instructions with shifter operand",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avoidPartialCpsr = Feature{
    .name = "avoidPartialCpsr",
    .llvm_name = "avoid-partial-cpsr",
    .description = "Avoid CPSR partial update for OOO execution",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_crc = Feature{
    .name = "crc",
    .llvm_name = "crc",
    .description = "Enable support for CRC instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_cheapPredicableCpsr = Feature{
    .name = "cheapPredicableCpsr",
    .llvm_name = "cheap-predicable-cpsr",
    .description = "Disable +1 predication cost for instructions updating CPSR",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vldnAlign = Feature{
    .name = "vldnAlign",
    .llvm_name = "vldn-align",
    .description = "Check for VLDn unaligned access",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .llvm_name = "crypto",
    .description = "Enable support for Cryptography extensions",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_d32 = Feature{
    .name = "d32",
    .llvm_name = "d32",
    .description = "Extend FP to 32 double registers",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_db = Feature{
    .name = "db",
    .llvm_name = "db",
    .description = "Has data barrier (dmb/dsb) instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dfb = Feature{
    .name = "dfb",
    .llvm_name = "dfb",
    .description = "Has full data barrier (dfb) instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dsp = Feature{
    .name = "dsp",
    .llvm_name = "dsp",
    .description = "Supports DSP instructions in ARM and/or Thumb2",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dontWidenVmovs = Feature{
    .name = "dontWidenVmovs",
    .llvm_name = "dont-widen-vmovs",
    .description = "Don't widen VMOVS to VMOVD",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_dotprod = Feature{
    .name = "dotprod",
    .llvm_name = "dotprod",
    .description = "Enable support for dot product instructions",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_executeOnly = Feature{
    .name = "executeOnly",
    .llvm_name = "execute-only",
    .description = "Enable the generation of execute only code.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_expandFpMlx = Feature{
    .name = "expandFpMlx",
    .llvm_name = "expand-fp-mlx",
    .description = "Expand VFP/NEON MLA/MLS instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fp16 = Feature{
    .name = "fp16",
    .llvm_name = "fp16",
    .description = "Enable half-precision floating point",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fp16fml = Feature{
    .name = "fp16fml",
    .llvm_name = "fp16fml",
    .description = "Enable full half-precision floating point fml instructions",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fp64 = Feature{
    .name = "fp64",
    .llvm_name = "fp64",
    .description = "Floating point unit supports double precision",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpao = Feature{
    .name = "fpao",
    .llvm_name = "fpao",
    .description = "Enable fast computation of positive address offsets",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fpArmv8 = Feature{
    .name = "fpArmv8",
    .llvm_name = "fp-armv8",
    .description = "Enable ARMv8 FP",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8d16 = Feature{
    .name = "fpArmv8d16",
    .llvm_name = "fp-armv8d16",
    .description = "Enable ARMv8 FP with only 16 d-registers",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8d16sp = Feature{
    .name = "fpArmv8d16sp",
    .llvm_name = "fp-armv8d16sp",
    .description = "Enable ARMv8 FP with only 16 d-registers and no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fpArmv8sp = Feature{
    .name = "fpArmv8sp",
    .llvm_name = "fp-armv8sp",
    .description = "Enable ARMv8 FP with no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_fpregs = Feature{
    .name = "fpregs",
    .llvm_name = "fpregs",
    .description = "Enable FP registers",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fpregs16 = Feature{
    .name = "fpregs16",
    .llvm_name = "fpregs16",
    .description = "Enable 16-bit FP registers",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fpregs64 = Feature{
    .name = "fpregs64",
    .llvm_name = "fpregs64",
    .description = "Enable 64-bit FP registers",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_fullfp16 = Feature{
    .name = "fullfp16",
    .llvm_name = "fullfp16",
    .description = "Enable full half-precision floating point",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_fuseAes = Feature{
    .name = "fuseAes",
    .llvm_name = "fuse-aes",
    .description = "CPU fuses AES crypto operations",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fuseLiterals = Feature{
    .name = "fuseLiterals",
    .llvm_name = "fuse-literals",
    .description = "CPU fuses literal generation operations",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_hwdivArm = Feature{
    .name = "hwdivArm",
    .llvm_name = "hwdiv-arm",
    .description = "Enable divide instructions in ARM mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_hwdiv = Feature{
    .name = "hwdiv",
    .llvm_name = "hwdiv",
    .description = "Enable divide instructions in Thumb",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noBranchPredictor = Feature{
    .name = "noBranchPredictor",
    .llvm_name = "no-branch-predictor",
    .description = "Has no branch predictor",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_retAddrStack = Feature{
    .name = "retAddrStack",
    .llvm_name = "ret-addr-stack",
    .description = "Has return address stack",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowfpvmlx = Feature{
    .name = "slowfpvmlx",
    .llvm_name = "slowfpvmlx",
    .description = "Disable VFP / NEON MAC instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vmlxHazards = Feature{
    .name = "vmlxHazards",
    .llvm_name = "vmlx-hazards",
    .description = "Has VMLx hazards",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lob = Feature{
    .name = "lob",
    .llvm_name = "lob",
    .description = "Enable Low Overhead Branch extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_longCalls = Feature{
    .name = "longCalls",
    .llvm_name = "long-calls",
    .description = "Generate calls via indirect call instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mclass = Feature{
    .name = "mclass",
    .llvm_name = "mclass",
    .description = "Is microcontroller profile ('M' series)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mp = Feature{
    .name = "mp",
    .llvm_name = "mp",
    .description = "Supports Multiprocessing extension",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_muxedUnits = Feature{
    .name = "muxedUnits",
    .llvm_name = "muxed-units",
    .description = "Has muxed AGU and NEON/FPU",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_neon = Feature{
    .name = "neon",
    .llvm_name = "neon",
    .description = "Enable NEON instructions",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_neonfp = Feature{
    .name = "neonfp",
    .llvm_name = "neonfp",
    .description = "Use NEON for single precision FP",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_neonFpmovs = Feature{
    .name = "neonFpmovs",
    .llvm_name = "neon-fpmovs",
    .description = "Convert VMOVSR, VMOVRS, VMOVS to NEON",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_naclTrap = Feature{
    .name = "naclTrap",
    .llvm_name = "nacl-trap",
    .description = "NaCl trap",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noarm = Feature{
    .name = "noarm",
    .llvm_name = "noarm",
    .description = "Does not support ARM mode execution",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noMovt = Feature{
    .name = "noMovt",
    .llvm_name = "no-movt",
    .description = "Don't use movt/movw pairs for 32-bit imms",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_noNegImmediates = Feature{
    .name = "noNegImmediates",
    .llvm_name = "no-neg-immediates",
    .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_disablePostraScheduler = Feature{
    .name = "disablePostraScheduler",
    .llvm_name = "disable-postra-scheduler",
    .description = "Don't schedule again after register allocation",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nonpipelinedVfp = Feature{
    .name = "nonpipelinedVfp",
    .llvm_name = "nonpipelined-vfp",
    .description = "VFP instructions are not pipelined",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_perfmon = Feature{
    .name = "perfmon",
    .llvm_name = "perfmon",
    .description = "Enable support for Performance Monitor extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bit32 = Feature{
    .name = "bit32",
    .llvm_name = "32bit",
    .description = "Prefer 32-bit Thumb instrs",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_preferIshst = Feature{
    .name = "preferIshst",
    .llvm_name = "prefer-ishst",
    .description = "Prefer ISHST barriers",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_loopAlign = Feature{
    .name = "loopAlign",
    .llvm_name = "loop-align",
    .description = "Prefer 32-bit alignment for loops",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_preferVmovsr = Feature{
    .name = "preferVmovsr",
    .llvm_name = "prefer-vmovsr",
    .description = "Prefer VMOVSR",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_profUnpr = Feature{
    .name = "profUnpr",
    .llvm_name = "prof-unpr",
    .description = "Is profitable to unpredicate",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ras = Feature{
    .name = "ras",
    .llvm_name = "ras",
    .description = "Enable Reliability, Availability and Serviceability extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rclass = Feature{
    .name = "rclass",
    .llvm_name = "rclass",
    .description = "Is realtime profile ('R' series)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_readTpHard = Feature{
    .name = "readTpHard",
    .llvm_name = "read-tp-hard",
    .description = "Reading thread pointer from register",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_reserveR9 = Feature{
    .name = "reserveR9",
    .llvm_name = "reserve-r9",
    .description = "Reserve R9, making it unavailable as GPR",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sb = Feature{
    .name = "sb",
    .llvm_name = "sb",
    .description = "Enable v8.5a Speculation Barrier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sha2 = Feature{
    .name = "sha2",
    .llvm_name = "sha2",
    .description = "Enable SHA1 and SHA256 support",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_slowFpBrcc = Feature{
    .name = "slowFpBrcc",
    .llvm_name = "slow-fp-brcc",
    .description = "FP compare + branch is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowLoadDSubreg = Feature{
    .name = "slowLoadDSubreg",
    .llvm_name = "slow-load-D-subreg",
    .description = "Loading into D subregs is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowOddReg = Feature{
    .name = "slowOddReg",
    .llvm_name = "slow-odd-reg",
    .description = "VLDM/VSTM starting with an odd register is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowVdup32 = Feature{
    .name = "slowVdup32",
    .llvm_name = "slow-vdup32",
    .description = "Has slow VDUP32 - prefer VMOV",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowVgetlni32 = Feature{
    .name = "slowVgetlni32",
    .llvm_name = "slow-vgetlni32",
    .description = "Has slow VGETLNi32 - prefer VMOV",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_splatVfpNeon = Feature{
    .name = "splatVfpNeon",
    .llvm_name = "splat-vfp-neon",
    .description = "Splat register from VFP to NEON",
    .dependencies = &[_]*const Feature {
        &feature_dontWidenVmovs,
    },
};

pub const feature_strictAlign = Feature{
    .name = "strictAlign",
    .llvm_name = "strict-align",
    .description = "Disallow all unaligned memory access",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_thumb2 = Feature{
    .name = "thumb2",
    .llvm_name = "thumb2",
    .description = "Enable Thumb2 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_trustzone = Feature{
    .name = "trustzone",
    .llvm_name = "trustzone",
    .description = "Enable support for TrustZone security extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_useAa = Feature{
    .name = "useAa",
    .llvm_name = "use-aa",
    .description = "Use alias analysis during codegen",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_useMisched = Feature{
    .name = "useMisched",
    .llvm_name = "use-misched",
    .description = "Use the MachineScheduler",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_wideStrideVfp = Feature{
    .name = "wideStrideVfp",
    .llvm_name = "wide-stride-vfp",
    .description = "Use a wide stride when allocating VFP registers",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_v7clrex = Feature{
    .name = "v7clrex",
    .llvm_name = "v7clrex",
    .description = "Has v7 clrex instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vfp2 = Feature{
    .name = "vfp2",
    .llvm_name = "vfp2",
    .description = "Enable VFP2 instructions",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vfp2d16 = Feature{
    .name = "vfp2d16",
    .llvm_name = "vfp2d16",
    .description = "Enable VFP2 instructions with only 16 d-registers",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp2d16sp = Feature{
    .name = "vfp2d16sp",
    .llvm_name = "vfp2d16sp",
    .description = "Enable VFP2 instructions with only 16 d-registers and no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp2sp = Feature{
    .name = "vfp2sp",
    .llvm_name = "vfp2sp",
    .description = "Enable VFP2 instructions with no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp3 = Feature{
    .name = "vfp3",
    .llvm_name = "vfp3",
    .description = "Enable VFP3 instructions",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp3d16 = Feature{
    .name = "vfp3d16",
    .llvm_name = "vfp3d16",
    .description = "Enable VFP3 instructions with only 16 d-registers",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3d16sp = Feature{
    .name = "vfp3d16sp",
    .llvm_name = "vfp3d16sp",
    .description = "Enable VFP3 instructions with only 16 d-registers and no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
    },
};

pub const feature_vfp3sp = Feature{
    .name = "vfp3sp",
    .llvm_name = "vfp3sp",
    .description = "Enable VFP3 instructions with no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vfp4 = Feature{
    .name = "vfp4",
    .llvm_name = "vfp4",
    .description = "Enable VFP4 instructions",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_d32,
        &feature_fpregs,
    },
};

pub const feature_vfp4d16 = Feature{
    .name = "vfp4d16",
    .llvm_name = "vfp4d16",
    .description = "Enable VFP4 instructions with only 16 d-registers",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4d16sp = Feature{
    .name = "vfp4d16sp",
    .llvm_name = "vfp4d16sp",
    .description = "Enable VFP4 instructions with only 16 d-registers and no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
    },
};

pub const feature_vfp4sp = Feature{
    .name = "vfp4sp",
    .llvm_name = "vfp4sp",
    .description = "Enable VFP4 instructions with no double precision",
    .dependencies = &[_]*const Feature {
        &feature_fp16,
        &feature_fpregs,
        &feature_d32,
    },
};

pub const feature_vmlxForwarding = Feature{
    .name = "vmlxForwarding",
    .llvm_name = "vmlx-forwarding",
    .description = "Has multiplier accumulator forwarding",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_virtualization = Feature{
    .name = "virtualization",
    .llvm_name = "virtualization",
    .description = "Supports Virtualization extension",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_hwdivArm,
    },
};

pub const feature_zcz = Feature{
    .name = "zcz",
    .llvm_name = "zcz",
    .description = "Has zero-cycle zeroing instructions",
    .dependencies = &[_]*const Feature {
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
    &feature_vfp2d16,
    &feature_vfp2d16sp,
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
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm1020t = Cpu{
    .name = "arm1020t",
    .llvm_name = "arm1020t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm1022e = Cpu{
    .name = "arm1022e",
    .llvm_name = "arm1022e",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm10e = Cpu{
    .name = "arm10e",
    .llvm_name = "arm10e",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm10tdmi = Cpu{
    .name = "arm10tdmi",
    .llvm_name = "arm10tdmi",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm1136jS = Cpu{
    .name = "arm1136jS",
    .llvm_name = "arm1136j-s",
    .dependencies = &[_]*const Feature {
        &feature_dsp,
    },
};

pub const cpu_arm1136jfS = Cpu{
    .name = "arm1136jfS",
    .llvm_name = "arm1136jf-s",
    .dependencies = &[_]*const Feature {
        &feature_dsp,
        &feature_slowfpvmlx,
        &feature_d32,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1156t2S = Cpu{
    .name = "arm1156t2S",
    .llvm_name = "arm1156t2-s",
    .dependencies = &[_]*const Feature {
        &feature_dsp,
        &feature_thumb2,
    },
};

pub const cpu_arm1156t2fS = Cpu{
    .name = "arm1156t2fS",
    .llvm_name = "arm1156t2f-s",
    .dependencies = &[_]*const Feature {
        &feature_dsp,
        &feature_thumb2,
        &feature_slowfpvmlx,
        &feature_d32,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm1176jS = Cpu{
    .name = "arm1176jS",
    .llvm_name = "arm1176j-s",
    .dependencies = &[_]*const Feature {
        &feature_trustzone,
    },
};

pub const cpu_arm1176jzS = Cpu{
    .name = "arm1176jzS",
    .llvm_name = "arm1176jz-s",
    .dependencies = &[_]*const Feature {
        &feature_trustzone,
    },
};

pub const cpu_arm1176jzfS = Cpu{
    .name = "arm1176jzfS",
    .llvm_name = "arm1176jzf-s",
    .dependencies = &[_]*const Feature {
        &feature_trustzone,
        &feature_slowfpvmlx,
        &feature_d32,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_arm710t = Cpu{
    .name = "arm710t",
    .llvm_name = "arm710t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm720t = Cpu{
    .name = "arm720t",
    .llvm_name = "arm720t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm7tdmi = Cpu{
    .name = "arm7tdmi",
    .llvm_name = "arm7tdmi",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm7tdmiS = Cpu{
    .name = "arm7tdmiS",
    .llvm_name = "arm7tdmi-s",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm8 = Cpu{
    .name = "arm8",
    .llvm_name = "arm8",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm810 = Cpu{
    .name = "arm810",
    .llvm_name = "arm810",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm9 = Cpu{
    .name = "arm9",
    .llvm_name = "arm9",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm920 = Cpu{
    .name = "arm920",
    .llvm_name = "arm920",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm920t = Cpu{
    .name = "arm920t",
    .llvm_name = "arm920t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm922t = Cpu{
    .name = "arm922t",
    .llvm_name = "arm922t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm926ejS = Cpu{
    .name = "arm926ejS",
    .llvm_name = "arm926ej-s",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm940t = Cpu{
    .name = "arm940t",
    .llvm_name = "arm940t",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm946eS = Cpu{
    .name = "arm946eS",
    .llvm_name = "arm946e-s",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm966eS = Cpu{
    .name = "arm966eS",
    .llvm_name = "arm966e-s",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm968eS = Cpu{
    .name = "arm968eS",
    .llvm_name = "arm968e-s",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm9e = Cpu{
    .name = "arm9e",
    .llvm_name = "arm9e",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_arm9tdmi = Cpu{
    .name = "arm9tdmi",
    .llvm_name = "arm9tdmi",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_cortexA12 = Cpu{
    .name = "cortexA12",
    .llvm_name = "cortex-a12",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA15",
    .llvm_name = "cortex-a15",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA17",
    .llvm_name = "cortex-a17",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA32",
    .llvm_name = "cortex-a32",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
    },
};

pub const cpu_cortexA35 = Cpu{
    .name = "cortexA35",
    .llvm_name = "cortex-a35",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
    },
};

pub const cpu_cortexA5 = Cpu{
    .name = "cortexA5",
    .llvm_name = "cortex-a5",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA53",
    .llvm_name = "cortex-a53",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
        &feature_fpao,
    },
};

pub const cpu_cortexA55 = Cpu{
    .name = "cortexA55",
    .llvm_name = "cortex-a55",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_dotprod,
    },
};

pub const cpu_cortexA57 = Cpu{
    .name = "cortexA57",
    .llvm_name = "cortex-a57",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_avoidPartialCpsr,
        &feature_cheapPredicableCpsr,
        &feature_crypto,
        &feature_fpao,
    },
};

pub const cpu_cortexA7 = Cpu{
    .name = "cortexA7",
    .llvm_name = "cortex-a7",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA72",
    .llvm_name = "cortex-a72",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
    },
};

pub const cpu_cortexA73 = Cpu{
    .name = "cortexA73",
    .llvm_name = "cortex-a73",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
    },
};

pub const cpu_cortexA75 = Cpu{
    .name = "cortexA75",
    .llvm_name = "cortex-a75",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_dotprod,
    },
};

pub const cpu_cortexA76 = Cpu{
    .name = "cortexA76",
    .llvm_name = "cortex-a76",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
    },
};

pub const cpu_cortexA76ae = Cpu{
    .name = "cortexA76ae",
    .llvm_name = "cortex-a76ae",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_crypto,
        &feature_dotprod,
        &feature_fullfp16,
    },
};

pub const cpu_cortexA8 = Cpu{
    .name = "cortexA8",
    .llvm_name = "cortex-a8",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexA9",
    .llvm_name = "cortex-a9",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexM0",
    .llvm_name = "cortex-m0",
    .dependencies = &[_]*const Feature {
        &feature_mclass,
        &feature_db,
        &feature_noarm,
        &feature_strictAlign,
    },
};

pub const cpu_cortexM0plus = Cpu{
    .name = "cortexM0plus",
    .llvm_name = "cortex-m0plus",
    .dependencies = &[_]*const Feature {
        &feature_mclass,
        &feature_db,
        &feature_noarm,
        &feature_strictAlign,
    },
};

pub const cpu_cortexM1 = Cpu{
    .name = "cortexM1",
    .llvm_name = "cortex-m1",
    .dependencies = &[_]*const Feature {
        &feature_mclass,
        &feature_db,
        &feature_noarm,
        &feature_strictAlign,
    },
};

pub const cpu_cortexM23 = Cpu{
    .name = "cortexM23",
    .llvm_name = "cortex-m23",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mclass,
        &feature_db,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_noarm,
        &feature_msecext8,
        &feature_strictAlign,
        &feature_noMovt,
    },
};

pub const cpu_cortexM3 = Cpu{
    .name = "cortexM3",
    .llvm_name = "cortex-m3",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
        &feature_noBranchPredictor,
        &feature_loopAlign,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexM33 = Cpu{
    .name = "cortexM33",
    .llvm_name = "cortex-m33",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
        &feature_msecext8,
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
    .name = "cortexM35p",
    .llvm_name = "cortex-m35p",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
        &feature_msecext8,
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
    .name = "cortexM4",
    .llvm_name = "cortex-m4",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
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
    .name = "cortexM7",
    .llvm_name = "cortex-m7",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
        &feature_fp16,
        &feature_fpregs,
        &feature_fpArmv8d16,
    },
};

pub const cpu_cortexR4 = Cpu{
    .name = "cortexR4",
    .llvm_name = "cortex-r4",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
    },
};

pub const cpu_cortexR4f = Cpu{
    .name = "cortexR4f",
    .llvm_name = "cortex-r4f",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_avoidPartialCpsr,
        &feature_retAddrStack,
        &feature_slowfpvmlx,
        &feature_slowFpBrcc,
        &feature_fpregs,
        &feature_vfp3d16,
    },
};

pub const cpu_cortexR5 = Cpu{
    .name = "cortexR5",
    .llvm_name = "cortex-r5",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexR52",
    .llvm_name = "cortex-r52",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dfb,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_fpregs,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_fpao,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_cortexR7 = Cpu{
    .name = "cortexR7",
    .llvm_name = "cortex-r7",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
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
    .name = "cortexR8",
    .llvm_name = "cortex-r8",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_dsp,
        &feature_rclass,
        &feature_thumb2,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
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
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
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
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_exynosM1 = Cpu{
    .name = "exynosM1",
    .llvm_name = "exynos-m1",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_fuseLiterals,
        &feature_useAa,
        &feature_wideStrideVfp,
        &feature_slowVgetlni32,
        &feature_slowVdup32,
        &feature_profUnpr,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_zcz,
        &feature_slowfpvmlx,
        &feature_expandFpMlx,
        &feature_fuseAes,
        &feature_dontWidenVmovs,
    },
};

pub const cpu_exynosM2 = Cpu{
    .name = "exynosM2",
    .llvm_name = "exynos-m2",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_fuseLiterals,
        &feature_useAa,
        &feature_wideStrideVfp,
        &feature_slowVgetlni32,
        &feature_slowVdup32,
        &feature_profUnpr,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_zcz,
        &feature_slowfpvmlx,
        &feature_expandFpMlx,
        &feature_fuseAes,
        &feature_dontWidenVmovs,
    },
};

pub const cpu_exynosM3 = Cpu{
    .name = "exynosM3",
    .llvm_name = "exynos-m3",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_fuseLiterals,
        &feature_useAa,
        &feature_wideStrideVfp,
        &feature_slowVgetlni32,
        &feature_slowVdup32,
        &feature_profUnpr,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_zcz,
        &feature_slowfpvmlx,
        &feature_expandFpMlx,
        &feature_fuseAes,
        &feature_dontWidenVmovs,
    },
};

pub const cpu_exynosM4 = Cpu{
    .name = "exynosM4",
    .llvm_name = "exynos-m4",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_fuseLiterals,
        &feature_useAa,
        &feature_wideStrideVfp,
        &feature_slowVgetlni32,
        &feature_slowVdup32,
        &feature_profUnpr,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_zcz,
        &feature_slowfpvmlx,
        &feature_expandFpMlx,
        &feature_fuseAes,
        &feature_dontWidenVmovs,
    },
};

pub const cpu_exynosM5 = Cpu{
    .name = "exynosM5",
    .llvm_name = "exynos-m5",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_ras,
        &feature_dotprod,
        &feature_fullfp16,
        &feature_fuseLiterals,
        &feature_useAa,
        &feature_wideStrideVfp,
        &feature_slowVgetlni32,
        &feature_slowVdup32,
        &feature_profUnpr,
        &feature_slowFpBrcc,
        &feature_retAddrStack,
        &feature_zcz,
        &feature_slowfpvmlx,
        &feature_expandFpMlx,
        &feature_fuseAes,
        &feature_dontWidenVmovs,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_iwmmxt = Cpu{
    .name = "iwmmxt",
    .llvm_name = "iwmmxt",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_krait = Cpu{
    .name = "krait",
    .llvm_name = "krait",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_mp,
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_trustzone,
        &feature_crc,
        &feature_fp16,
        &feature_acquireRelease,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_hwdivArm,
        &feature_crypto,
    },
};

pub const cpu_mpcore = Cpu{
    .name = "mpcore",
    .llvm_name = "mpcore",
    .dependencies = &[_]*const Feature {
        &feature_slowfpvmlx,
        &feature_d32,
        &feature_fpregs,
        &feature_vfp2,
    },
};

pub const cpu_mpcorenovfp = Cpu{
    .name = "mpcorenovfp",
    .llvm_name = "mpcorenovfp",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_sc000 = Cpu{
    .name = "sc000",
    .llvm_name = "sc000",
    .dependencies = &[_]*const Feature {
        &feature_mclass,
        &feature_db,
        &feature_noarm,
        &feature_strictAlign,
    },
};

pub const cpu_sc300 = Cpu{
    .name = "sc300",
    .llvm_name = "sc300",
    .dependencies = &[_]*const Feature {
        &feature_hwdiv,
        &feature_thumb2,
        &feature_mclass,
        &feature_db,
        &feature_v7clrex,
        &feature_perfmon,
        &feature_noarm,
        &feature_noBranchPredictor,
        &feature_useAa,
        &feature_useMisched,
    },
};

pub const cpu_strongarm = Cpu{
    .name = "strongarm",
    .llvm_name = "strongarm",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_strongarm110 = Cpu{
    .name = "strongarm110",
    .llvm_name = "strongarm110",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_strongarm1100 = Cpu{
    .name = "strongarm1100",
    .llvm_name = "strongarm1100",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_strongarm1110 = Cpu{
    .name = "strongarm1110",
    .llvm_name = "strongarm1110",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_swift = Cpu{
    .name = "swift",
    .llvm_name = "swift",
    .dependencies = &[_]*const Feature {
        &feature_d32,
        &feature_dsp,
        &feature_thumb2,
        &feature_db,
        &feature_aclass,
        &feature_fpregs,
        &feature_v7clrex,
        &feature_perfmon,
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
    .dependencies = &[_]*const Feature {
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
    &cpu_sc000,
    &cpu_sc300,
    &cpu_strongarm,
    &cpu_strongarm110,
    &cpu_strongarm1100,
    &cpu_strongarm1110,
    &cpu_swift,
    &cpu_xscale,
};
