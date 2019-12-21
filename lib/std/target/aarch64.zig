const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_aes = Feature{
    .name = "aes",
    .description = "Enable AES support",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_am = Feature{
    .name = "am",
    .description = "Enable v8.4-A Activity Monitors extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_aggressiveFma = Feature{
    .name = "aggressive-fma",
    .description = "Enable Aggressive FMA for floating-point.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_altnzcv = Feature{
    .name = "altnzcv",
    .description = "Enable alternative NZCV format for floating point comparisons",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_alternateSextloadCvtF32Pattern = Feature{
    .name = "alternate-sextload-cvt-f32-pattern",
    .description = "Use alternative pattern for sextload convert to f32",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_arithBccFusion = Feature{
    .name = "arith-bcc-fusion",
    .description = "CPU fuses arithmetic+bcc operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_arithCbzFusion = Feature{
    .name = "arith-cbz-fusion",
    .description = "CPU fuses arithmetic + cbz/cbnz operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_balanceFpOps = Feature{
    .name = "balance-fp-ops",
    .description = "balance mix of odd and even D-registers for fp multiply(-accumulate) ops",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_bti = Feature{
    .name = "bti",
    .description = "Enable Branch Target Identification",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ccidx = Feature{
    .name = "ccidx",
    .description = "Enable v8.3-A Extend of the CCSIDR number of sets",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ccpp = Feature{
    .name = "ccpp",
    .description = "Enable v8.2 data Cache Clean to Point of Persistence",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crc = Feature{
    .name = "crc",
    .description = "Enable ARMv8 CRC-32 checksum instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ccdp = Feature{
    .name = "ccdp",
    .description = "Enable v8.5 Cache Clean to Point of Deep Persistence",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX8 = Feature{
    .name = "call-saved-x8",
    .description = "Make X8 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX9 = Feature{
    .name = "call-saved-x9",
    .description = "Make X9 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX10 = Feature{
    .name = "call-saved-x10",
    .description = "Make X10 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX11 = Feature{
    .name = "call-saved-x11",
    .description = "Make X11 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX12 = Feature{
    .name = "call-saved-x12",
    .description = "Make X12 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX13 = Feature{
    .name = "call-saved-x13",
    .description = "Make X13 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX14 = Feature{
    .name = "call-saved-x14",
    .description = "Make X14 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX15 = Feature{
    .name = "call-saved-x15",
    .description = "Make X15 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_callSavedX18 = Feature{
    .name = "call-saved-x18",
    .description = "Make X18 callee saved.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_complxnum = Feature{
    .name = "complxnum",
    .description = "Enable v8.3-A Floating-point complex number support",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .description = "Enable cryptographic instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_customCheapAsMove = Feature{
    .name = "custom-cheap-as-move",
    .description = "Use custom handling of cheap instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dit = Feature{
    .name = "dit",
    .description = "Enable v8.4-A Data Independent Timing instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_disableLatencySchedHeuristic = Feature{
    .name = "disable-latency-sched-heuristic",
    .description = "Disable latency scheduling heuristic",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dotprod = Feature{
    .name = "dotprod",
    .description = "Enable dot product support",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ete = Feature{
    .name = "ete",
    .description = "Enable Embedded Trace Extension",
    .subfeatures = &[_]*const Feature {
        &feature_trbe,
    },
};

pub const feature_exynosCheapAsMove = Feature{
    .name = "exynos-cheap-as-move",
    .description = "Use Exynos specific handling of cheap instructions",
    .subfeatures = &[_]*const Feature {
        &feature_customCheapAsMove,
    },
};

pub const feature_fmi = Feature{
    .name = "fmi",
    .description = "Enable v8.4-A Flag Manipulation Instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fp16fml = Feature{
    .name = "fp16fml",
    .description = "Enable FP16 FML instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_fpArmv8 = Feature{
    .name = "fp-armv8",
    .description = "Enable ARMv8 FP",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fptoint = Feature{
    .name = "fptoint",
    .description = "Enable FRInt[32|64][Z|X] instructions that round a floating-point number to an integer (in FP format) forcing it to fit into a 32- or 64-bit int",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_force32bitJumpTables = Feature{
    .name = "force-32bit-jump-tables",
    .description = "Force jump table entries to be 32-bits wide except at MinSize",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fullfp16 = Feature{
    .name = "fullfp16",
    .description = "Full FP16",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_fuseAes = Feature{
    .name = "fuse-aes",
    .description = "CPU fuses AES crypto operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseAddress = Feature{
    .name = "fuse-address",
    .description = "CPU fuses address generation and memory operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseArithLogic = Feature{
    .name = "fuse-arith-logic",
    .description = "CPU fuses arithmetic and logic operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseCsel = Feature{
    .name = "fuse-csel",
    .description = "CPU fuses conditional select operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseCryptoEor = Feature{
    .name = "fuse-crypto-eor",
    .description = "CPU fuses AES/PMULL and EOR operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fuseLiterals = Feature{
    .name = "fuse-literals",
    .description = "CPU fuses literal generation operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_jsconv = Feature{
    .name = "jsconv",
    .description = "Enable v8.3-A JavaScript FP conversion enchancement",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_lor = Feature{
    .name = "lor",
    .description = "Enables ARM v8.1 Limited Ordering Regions extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_lse = Feature{
    .name = "lse",
    .description = "Enable ARMv8.1 Large System Extension (LSE) atomic instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_lslFast = Feature{
    .name = "lsl-fast",
    .description = "CPU has a fastpath logical shift of up to 3 places",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mpam = Feature{
    .name = "mpam",
    .description = "Enable v8.4-A Memory system Partitioning and Monitoring extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mte = Feature{
    .name = "mte",
    .description = "Enable Memory Tagging Extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_neon = Feature{
    .name = "neon",
    .description = "Enable Advanced SIMD instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_nv = Feature{
    .name = "nv",
    .description = "Enable v8.4-A Nested Virtualization Enchancement",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_noNegImmediates = Feature{
    .name = "no-neg-immediates",
    .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_pa = Feature{
    .name = "pa",
    .description = "Enable v8.3-A Pointer Authentication enchancement",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_pan = Feature{
    .name = "pan",
    .description = "Enables ARM v8.1 Privileged Access-Never extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_panRwv = Feature{
    .name = "pan-rwv",
    .description = "Enable v8.2 PAN s1e1R and s1e1W Variants",
    .subfeatures = &[_]*const Feature {
        &feature_pan,
    },
};

pub const feature_perfmon = Feature{
    .name = "perfmon",
    .description = "Enable ARMv8 PMUv3 Performance Monitors extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_usePostraScheduler = Feature{
    .name = "use-postra-scheduler",
    .description = "Schedule again after register allocation",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_predres = Feature{
    .name = "predres",
    .description = "Enable v8.5a execution and data prediction invalidation instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_predictableSelectExpensive = Feature{
    .name = "predictable-select-expensive",
    .description = "Prefer likely predicted branches over selects",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_uaops = Feature{
    .name = "uaops",
    .description = "Enable v8.2 UAO PState",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ras = Feature{
    .name = "ras",
    .description = "Enable ARMv8 Reliability, Availability and Serviceability Extensions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rasv8_4 = Feature{
    .name = "rasv8_4",
    .description = "Enable v8.4-A Reliability, Availability and Serviceability extension",
    .subfeatures = &[_]*const Feature {
        &feature_ras,
    },
};

pub const feature_rcpc = Feature{
    .name = "rcpc",
    .description = "Enable support for RCPC extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rcpcImmo = Feature{
    .name = "rcpc-immo",
    .description = "Enable v8.4-A RCPC instructions with Immediate Offsets",
    .subfeatures = &[_]*const Feature {
        &feature_rcpc,
    },
};

pub const feature_rdm = Feature{
    .name = "rdm",
    .description = "Enable ARMv8.1 Rounding Double Multiply Add/Subtract instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_rand = Feature{
    .name = "rand",
    .description = "Enable Random Number generation instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX1 = Feature{
    .name = "reserve-x1",
    .description = "Reserve X1, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX2 = Feature{
    .name = "reserve-x2",
    .description = "Reserve X2, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX3 = Feature{
    .name = "reserve-x3",
    .description = "Reserve X3, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX4 = Feature{
    .name = "reserve-x4",
    .description = "Reserve X4, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX5 = Feature{
    .name = "reserve-x5",
    .description = "Reserve X5, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX6 = Feature{
    .name = "reserve-x6",
    .description = "Reserve X6, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX7 = Feature{
    .name = "reserve-x7",
    .description = "Reserve X7, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX9 = Feature{
    .name = "reserve-x9",
    .description = "Reserve X9, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX10 = Feature{
    .name = "reserve-x10",
    .description = "Reserve X10, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX11 = Feature{
    .name = "reserve-x11",
    .description = "Reserve X11, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX12 = Feature{
    .name = "reserve-x12",
    .description = "Reserve X12, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX13 = Feature{
    .name = "reserve-x13",
    .description = "Reserve X13, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX14 = Feature{
    .name = "reserve-x14",
    .description = "Reserve X14, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX15 = Feature{
    .name = "reserve-x15",
    .description = "Reserve X15, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX18 = Feature{
    .name = "reserve-x18",
    .description = "Reserve X18, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX20 = Feature{
    .name = "reserve-x20",
    .description = "Reserve X20, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX21 = Feature{
    .name = "reserve-x21",
    .description = "Reserve X21, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX22 = Feature{
    .name = "reserve-x22",
    .description = "Reserve X22, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX23 = Feature{
    .name = "reserve-x23",
    .description = "Reserve X23, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX24 = Feature{
    .name = "reserve-x24",
    .description = "Reserve X24, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX25 = Feature{
    .name = "reserve-x25",
    .description = "Reserve X25, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX26 = Feature{
    .name = "reserve-x26",
    .description = "Reserve X26, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX27 = Feature{
    .name = "reserve-x27",
    .description = "Reserve X27, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_reserveX28 = Feature{
    .name = "reserve-x28",
    .description = "Reserve X28, making it unavailable as a GPR",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sb = Feature{
    .name = "sb",
    .description = "Enable v8.5 Speculation Barrier",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sel2 = Feature{
    .name = "sel2",
    .description = "Enable v8.4-A Secure Exception Level 2 extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sha2 = Feature{
    .name = "sha2",
    .description = "Enable SHA1 and SHA256 support",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_sha3 = Feature{
    .name = "sha3",
    .description = "Enable SHA512 and SHA3 support",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_sm4 = Feature{
    .name = "sm4",
    .description = "Enable SM3 and SM4 support",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
    },
};

pub const feature_spe = Feature{
    .name = "spe",
    .description = "Enable Statistical Profiling extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ssbs = Feature{
    .name = "ssbs",
    .description = "Enable Speculative Store Bypass Safe bit",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sve = Feature{
    .name = "sve",
    .description = "Enable Scalable Vector Extension (SVE) instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sve2 = Feature{
    .name = "sve2",
    .description = "Enable Scalable Vector Extension 2 (SVE2) instructions",
    .subfeatures = &[_]*const Feature {
        &feature_sve,
    },
};

pub const feature_sve2Aes = Feature{
    .name = "sve2-aes",
    .description = "Enable AES SVE2 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_sve,
    },
};

pub const feature_sve2Bitperm = Feature{
    .name = "sve2-bitperm",
    .description = "Enable bit permutation SVE2 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_sve,
    },
};

pub const feature_sve2Sha3 = Feature{
    .name = "sve2-sha3",
    .description = "Enable SHA3 SVE2 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_sve,
    },
};

pub const feature_sve2Sm4 = Feature{
    .name = "sve2-sm4",
    .description = "Enable SM4 SVE2 instructions",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_sve,
    },
};

pub const feature_slowMisaligned128store = Feature{
    .name = "slow-misaligned-128store",
    .description = "Misaligned 128 bit stores are slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowPaired128 = Feature{
    .name = "slow-paired-128",
    .description = "Paired 128 bit loads and stores are slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowStrqroStore = Feature{
    .name = "slow-strqro-store",
    .description = "STR of Q register with register offset is slow",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_specrestrict = Feature{
    .name = "specrestrict",
    .description = "Enable architectural speculation restriction",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_strictAlign = Feature{
    .name = "strict-align",
    .description = "Disallow all unaligned memory access",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tlbRmi = Feature{
    .name = "tlb-rmi",
    .description = "Enable v8.4-A TLB Range and Maintenance Instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tme = Feature{
    .name = "tme",
    .description = "Enable Transactional Memory Extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tracev84 = Feature{
    .name = "tracev8.4",
    .description = "Enable v8.4-A Trace extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_trbe = Feature{
    .name = "trbe",
    .description = "Enable Trace Buffer Extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_taggedGlobals = Feature{
    .name = "tagged-globals",
    .description = "Use an instruction sequence for taking the address of a global that allows a memory tag in the upper address bits",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useAa = Feature{
    .name = "use-aa",
    .description = "Use alias analysis during codegen",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tpidrEl1 = Feature{
    .name = "tpidr-el1",
    .description = "Permit use of TPIDR_EL1 for the TLS base",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tpidrEl2 = Feature{
    .name = "tpidr-el2",
    .description = "Permit use of TPIDR_EL2 for the TLS base",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tpidrEl3 = Feature{
    .name = "tpidr-el3",
    .description = "Permit use of TPIDR_EL3 for the TLS base",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_useReciprocalSquareRoot = Feature{
    .name = "use-reciprocal-square-root",
    .description = "Use the reciprocal square root approximation",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vh = Feature{
    .name = "vh",
    .description = "Enables ARM v8.1 Virtual Host extension",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_zcm = Feature{
    .name = "zcm",
    .description = "Has zero-cycle register moves",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_zcz = Feature{
    .name = "zcz",
    .description = "Has zero-cycle zeroing instructions",
    .subfeatures = &[_]*const Feature {
        &feature_zczGp,
        &feature_zczFp,
    },
};

pub const feature_zczFp = Feature{
    .name = "zcz-fp",
    .description = "Has zero-cycle zeroing instructions for FP registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_zczFpWorkaround = Feature{
    .name = "zcz-fp-workaround",
    .description = "The zero-cycle floating-point zeroing instruction has a bug",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_zczGp = Feature{
    .name = "zcz-gp",
    .description = "Has zero-cycle zeroing instructions for generic registers",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_v81a = Feature{
    .name = "v8.1a",
    .description = "Support ARM v8.1a instructions",
    .subfeatures = &[_]*const Feature {
        &feature_lor,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_crc,
    },
};

pub const feature_v82a = Feature{
    .name = "v8.2a",
    .description = "Support ARM v8.2a instructions",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_ras,
        &feature_crc,
        &feature_uaops,
    },
};

pub const feature_v83a = Feature{
    .name = "v8.3a",
    .description = "Support ARM v8.3a instructions",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ccidx,
        &feature_crc,
        &feature_pa,
    },
};

pub const feature_v84a = Feature{
    .name = "v8.4a",
    .description = "Support ARM v8.4a instructions",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_crc,
        &feature_fmi,
        &feature_tracev84,
        &feature_tlbRmi,
        &feature_rdm,
        &feature_ccidx,
        &feature_mpam,
        &feature_pan,
        &feature_lse,
        &feature_rcpc,
        &feature_uaops,
        &feature_sel2,
        &feature_nv,
        &feature_am,
        &feature_dit,
        &feature_vh,
        &feature_ras,
        &feature_pa,
    },
};

pub const feature_v85a = Feature{
    .name = "v8.5a",
    .description = "Support ARM v8.5a instructions",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_ssbs,
        &feature_crc,
        &feature_fmi,
        &feature_bti,
        &feature_tracev84,
        &feature_tlbRmi,
        &feature_fptoint,
        &feature_rdm,
        &feature_sb,
        &feature_ccidx,
        &feature_mpam,
        &feature_pan,
        &feature_lse,
        &feature_predres,
        &feature_rcpc,
        &feature_uaops,
        &feature_sel2,
        &feature_nv,
        &feature_am,
        &feature_dit,
        &feature_specrestrict,
        &feature_vh,
        &feature_altnzcv,
        &feature_ras,
        &feature_ccdp,
        &feature_pa,
    },
};

pub const feature_a35 = Feature{
    .name = "a35",
    .description = "Cortex-A35 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_perfmon,
        &feature_crc,
    },
};

pub const feature_a53 = Feature{
    .name = "a53",
    .description = "Cortex-A53 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_useAa,
        &feature_balanceFpOps,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_crc,
    },
};

pub const feature_a55 = Feature{
    .name = "a55",
    .description = "Cortex-A55 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_perfmon,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_crc,
    },
};

pub const feature_a57 = Feature{
    .name = "a57",
    .description = "Cortex-A57 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_balanceFpOps,
        &feature_predictableSelectExpensive,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_crc,
    },
};

pub const feature_a65 = Feature{
    .name = "a65",
    .description = "Cortex-A65 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_rcpc,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_ras,
        &feature_ssbs,
        &feature_crc,
    },
};

pub const feature_a72 = Feature{
    .name = "a72",
    .description = "Cortex-A72 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_fuseAes,
        &feature_crc,
        &feature_perfmon,
    },
};

pub const feature_a73 = Feature{
    .name = "a73",
    .description = "Cortex-A73 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_fuseAes,
        &feature_crc,
        &feature_perfmon,
    },
};

pub const feature_a75 = Feature{
    .name = "a75",
    .description = "Cortex-A75 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_perfmon,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_crc,
    },
};

pub const feature_a76 = Feature{
    .name = "a76",
    .description = "Cortex-A76 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
    },
};

pub const feature_cyclone = Feature{
    .name = "cyclone",
    .description = "Cyclone",
    .subfeatures = &[_]*const Feature {
        &feature_zczFpWorkaround,
        &feature_fuseAes,
        &feature_zcm,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_alternateSextloadCvtF32Pattern,
        &feature_arithBccFusion,
        &feature_disableLatencySchedHeuristic,
        &feature_zczGp,
        &feature_fuseCryptoEor,
        &feature_fpArmv8,
        &feature_zczFp,
    },
};

pub const feature_exynosm1 = Feature{
    .name = "exynosm1",
    .description = "Samsung Exynos-M1 processors",
    .subfeatures = &[_]*const Feature {
        &feature_useReciprocalSquareRoot,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_slowMisaligned128store,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
        &feature_slowPaired128,
    },
};

pub const feature_exynosm2 = Feature{
    .name = "exynosm2",
    .description = "Samsung Exynos-M2 processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_slowMisaligned128store,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
        &feature_slowPaired128,
    },
};

pub const feature_exynosm3 = Feature{
    .name = "exynosm3",
    .description = "Samsung Exynos-M3 processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_predictableSelectExpensive,
        &feature_fuseAes,
        &feature_fuseAddress,
        &feature_fuseCsel,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
    },
};

pub const feature_exynosm4 = Feature{
    .name = "exynosm4",
    .description = "Samsung Exynos-M4 processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_crc,
        &feature_fuseAddress,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_arithBccFusion,
        &feature_zczGp,
        &feature_rdm,
        &feature_force32bitJumpTables,
        &feature_pan,
        &feature_lse,
        &feature_fuseCsel,
        &feature_uaops,
        &feature_fuseArithLogic,
        &feature_usePostraScheduler,
        &feature_vh,
        &feature_ras,
        &feature_zczFp,
    },
};

pub const feature_falkor = Feature{
    .name = "falkor",
    .description = "Qualcomm Falkor processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_slowStrqroStore,
        &feature_rdm,
        &feature_zczGp,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_zczFp,
        &feature_crc,
    },
};

pub const feature_kryo = Feature{
    .name = "kryo",
    .description = "Qualcomm Kryo processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_zczGp,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_zczFp,
        &feature_crc,
    },
};

pub const feature_neoversee1 = Feature{
    .name = "neoversee1",
    .description = "Neoverse E1 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
    },
};

pub const feature_neoversen1 = Feature{
    .name = "neoversen1",
    .description = "Neoverse N1 ARM processors",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_spe,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
    },
};

pub const feature_saphira = Feature{
    .name = "saphira",
    .description = "Qualcomm Saphira processors",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_crc,
        &feature_fmi,
        &feature_predictableSelectExpensive,
        &feature_tracev84,
        &feature_tlbRmi,
        &feature_perfmon,
        &feature_zczGp,
        &feature_rdm,
        &feature_ccidx,
        &feature_mpam,
        &feature_pan,
        &feature_lse,
        &feature_rcpc,
        &feature_uaops,
        &feature_sel2,
        &feature_usePostraScheduler,
        &feature_nv,
        &feature_am,
        &feature_spe,
        &feature_dit,
        &feature_vh,
        &feature_ras,
        &feature_zczFp,
        &feature_pa,
    },
};

pub const feature_tsv110 = Feature{
    .name = "tsv110",
    .description = "HiSilicon TS-V110 processors",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_uaops,
        &feature_perfmon,
        &feature_spe,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_ras,
        &feature_crc,
    },
};

pub const feature_thunderx = Feature{
    .name = "thunderx",
    .description = "Cavium ThunderX processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
    },
};

pub const feature_thunderx2t99 = Feature{
    .name = "thunderx2t99",
    .description = "Cavium ThunderX2 processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_lor,
        &feature_lse,
        &feature_pan,
        &feature_arithBccFusion,
        &feature_rdm,
        &feature_aggressiveFma,
        &feature_vh,
        &feature_fpArmv8,
        &feature_crc,
    },
};

pub const feature_thunderxt81 = Feature{
    .name = "thunderxt81",
    .description = "Cavium ThunderX processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
    },
};

pub const feature_thunderxt83 = Feature{
    .name = "thunderxt83",
    .description = "Cavium ThunderX processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
    },
};

pub const feature_thunderxt88 = Feature{
    .name = "thunderxt88",
    .description = "Cavium ThunderX processors",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
    },
};

pub const features = &[_]*const Feature {
    &feature_aes,
    &feature_am,
    &feature_aggressiveFma,
    &feature_altnzcv,
    &feature_alternateSextloadCvtF32Pattern,
    &feature_arithBccFusion,
    &feature_arithCbzFusion,
    &feature_balanceFpOps,
    &feature_bti,
    &feature_ccidx,
    &feature_ccpp,
    &feature_crc,
    &feature_ccdp,
    &feature_callSavedX8,
    &feature_callSavedX9,
    &feature_callSavedX10,
    &feature_callSavedX11,
    &feature_callSavedX12,
    &feature_callSavedX13,
    &feature_callSavedX14,
    &feature_callSavedX15,
    &feature_callSavedX18,
    &feature_complxnum,
    &feature_crypto,
    &feature_customCheapAsMove,
    &feature_dit,
    &feature_disableLatencySchedHeuristic,
    &feature_dotprod,
    &feature_ete,
    &feature_exynosCheapAsMove,
    &feature_fmi,
    &feature_fp16fml,
    &feature_fpArmv8,
    &feature_fptoint,
    &feature_force32bitJumpTables,
    &feature_fullfp16,
    &feature_fuseAes,
    &feature_fuseAddress,
    &feature_fuseArithLogic,
    &feature_fuseCsel,
    &feature_fuseCryptoEor,
    &feature_fuseLiterals,
    &feature_jsconv,
    &feature_lor,
    &feature_lse,
    &feature_lslFast,
    &feature_mpam,
    &feature_mte,
    &feature_neon,
    &feature_nv,
    &feature_noNegImmediates,
    &feature_pa,
    &feature_pan,
    &feature_panRwv,
    &feature_perfmon,
    &feature_usePostraScheduler,
    &feature_predres,
    &feature_predictableSelectExpensive,
    &feature_uaops,
    &feature_ras,
    &feature_rasv8_4,
    &feature_rcpc,
    &feature_rcpcImmo,
    &feature_rdm,
    &feature_rand,
    &feature_reserveX1,
    &feature_reserveX2,
    &feature_reserveX3,
    &feature_reserveX4,
    &feature_reserveX5,
    &feature_reserveX6,
    &feature_reserveX7,
    &feature_reserveX9,
    &feature_reserveX10,
    &feature_reserveX11,
    &feature_reserveX12,
    &feature_reserveX13,
    &feature_reserveX14,
    &feature_reserveX15,
    &feature_reserveX18,
    &feature_reserveX20,
    &feature_reserveX21,
    &feature_reserveX22,
    &feature_reserveX23,
    &feature_reserveX24,
    &feature_reserveX25,
    &feature_reserveX26,
    &feature_reserveX27,
    &feature_reserveX28,
    &feature_sb,
    &feature_sel2,
    &feature_sha2,
    &feature_sha3,
    &feature_sm4,
    &feature_spe,
    &feature_ssbs,
    &feature_sve,
    &feature_sve2,
    &feature_sve2Aes,
    &feature_sve2Bitperm,
    &feature_sve2Sha3,
    &feature_sve2Sm4,
    &feature_slowMisaligned128store,
    &feature_slowPaired128,
    &feature_slowStrqroStore,
    &feature_specrestrict,
    &feature_strictAlign,
    &feature_tlbRmi,
    &feature_tme,
    &feature_tracev84,
    &feature_trbe,
    &feature_taggedGlobals,
    &feature_useAa,
    &feature_tpidrEl1,
    &feature_tpidrEl2,
    &feature_tpidrEl3,
    &feature_useReciprocalSquareRoot,
    &feature_vh,
    &feature_zcm,
    &feature_zcz,
    &feature_zczFp,
    &feature_zczFpWorkaround,
    &feature_zczGp,
    &feature_v81a,
    &feature_v82a,
    &feature_v83a,
    &feature_v84a,
    &feature_v85a,
    &feature_a35,
    &feature_a53,
    &feature_a55,
    &feature_a57,
    &feature_a65,
    &feature_a72,
    &feature_a73,
    &feature_a75,
    &feature_a76,
    &feature_cyclone,
    &feature_exynosm1,
    &feature_exynosm2,
    &feature_exynosm3,
    &feature_exynosm4,
    &feature_falkor,
    &feature_kryo,
    &feature_neoversee1,
    &feature_neoversen1,
    &feature_saphira,
    &feature_tsv110,
    &feature_thunderx,
    &feature_thunderx2t99,
    &feature_thunderxt81,
    &feature_thunderxt83,
    &feature_thunderxt88,
};

pub const cpu_appleLatest = Cpu{
    .name = "apple-latest",
    .llvm_name = "apple-latest",
    .subfeatures = &[_]*const Feature {
        &feature_zczFpWorkaround,
        &feature_fuseAes,
        &feature_zcm,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_alternateSextloadCvtF32Pattern,
        &feature_arithBccFusion,
        &feature_disableLatencySchedHeuristic,
        &feature_zczGp,
        &feature_fuseCryptoEor,
        &feature_fpArmv8,
        &feature_zczFp,
        &feature_cyclone,
    },
};

pub const cpu_cortexA35 = Cpu{
    .name = "cortex-a35",
    .llvm_name = "cortex-a35",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_perfmon,
        &feature_crc,
        &feature_a35,
    },
};

pub const cpu_cortexA53 = Cpu{
    .name = "cortex-a53",
    .llvm_name = "cortex-a53",
    .subfeatures = &[_]*const Feature {
        &feature_useAa,
        &feature_balanceFpOps,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_crc,
        &feature_a53,
    },
};

pub const cpu_cortexA55 = Cpu{
    .name = "cortex-a55",
    .llvm_name = "cortex-a55",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_perfmon,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_crc,
        &feature_a55,
    },
};

pub const cpu_cortexA57 = Cpu{
    .name = "cortex-a57",
    .llvm_name = "cortex-a57",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_balanceFpOps,
        &feature_predictableSelectExpensive,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_crc,
        &feature_a57,
    },
};

pub const cpu_cortexA65 = Cpu{
    .name = "cortex-a65",
    .llvm_name = "cortex-a65",
    .subfeatures = &[_]*const Feature {
        &feature_rcpc,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_ras,
        &feature_ssbs,
        &feature_crc,
        &feature_a65,
    },
};

pub const cpu_cortexA65ae = Cpu{
    .name = "cortex-a65ae",
    .llvm_name = "cortex-a65ae",
    .subfeatures = &[_]*const Feature {
        &feature_rcpc,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_ras,
        &feature_ssbs,
        &feature_crc,
        &feature_a65,
    },
};

pub const cpu_cortexA72 = Cpu{
    .name = "cortex-a72",
    .llvm_name = "cortex-a72",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_fuseAes,
        &feature_crc,
        &feature_perfmon,
        &feature_a72,
    },
};

pub const cpu_cortexA73 = Cpu{
    .name = "cortex-a73",
    .llvm_name = "cortex-a73",
    .subfeatures = &[_]*const Feature {
        &feature_fpArmv8,
        &feature_fuseAes,
        &feature_crc,
        &feature_perfmon,
        &feature_a73,
    },
};

pub const cpu_cortexA75 = Cpu{
    .name = "cortex-a75",
    .llvm_name = "cortex-a75",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_perfmon,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_crc,
        &feature_a75,
    },
};

pub const cpu_cortexA76 = Cpu{
    .name = "cortex-a76",
    .llvm_name = "cortex-a76",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
        &feature_a76,
    },
};

pub const cpu_cortexA76ae = Cpu{
    .name = "cortex-a76ae",
    .llvm_name = "cortex-a76ae",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
        &feature_a76,
    },
};

pub const cpu_cyclone = Cpu{
    .name = "cyclone",
    .llvm_name = "cyclone",
    .subfeatures = &[_]*const Feature {
        &feature_zczFpWorkaround,
        &feature_fuseAes,
        &feature_zcm,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_alternateSextloadCvtF32Pattern,
        &feature_arithBccFusion,
        &feature_disableLatencySchedHeuristic,
        &feature_zczGp,
        &feature_fuseCryptoEor,
        &feature_fpArmv8,
        &feature_zczFp,
        &feature_cyclone,
    },
};

pub const cpu_exynosM1 = Cpu{
    .name = "exynos-m1",
    .llvm_name = "exynos-m1",
    .subfeatures = &[_]*const Feature {
        &feature_useReciprocalSquareRoot,
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_slowMisaligned128store,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
        &feature_slowPaired128,
        &feature_exynosm1,
    },
};

pub const cpu_exynosM2 = Cpu{
    .name = "exynos-m2",
    .llvm_name = "exynos-m2",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_slowMisaligned128store,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
        &feature_slowPaired128,
        &feature_exynosm2,
    },
};

pub const cpu_exynosM3 = Cpu{
    .name = "exynos-m3",
    .llvm_name = "exynos-m3",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_predictableSelectExpensive,
        &feature_fuseAes,
        &feature_fuseAddress,
        &feature_fuseCsel,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_force32bitJumpTables,
        &feature_zczFp,
        &feature_crc,
        &feature_exynosm3,
    },
};

pub const cpu_exynosM4 = Cpu{
    .name = "exynos-m4",
    .llvm_name = "exynos-m4",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_crc,
        &feature_fuseAddress,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_arithBccFusion,
        &feature_zczGp,
        &feature_rdm,
        &feature_force32bitJumpTables,
        &feature_pan,
        &feature_lse,
        &feature_fuseCsel,
        &feature_uaops,
        &feature_fuseArithLogic,
        &feature_usePostraScheduler,
        &feature_vh,
        &feature_ras,
        &feature_zczFp,
        &feature_exynosm4,
    },
};

pub const cpu_exynosM5 = Cpu{
    .name = "exynos-m5",
    .llvm_name = "exynos-m5",
    .subfeatures = &[_]*const Feature {
        &feature_fuseLiterals,
        &feature_fuseAes,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_crc,
        &feature_fuseAddress,
        &feature_arithCbzFusion,
        &feature_perfmon,
        &feature_arithBccFusion,
        &feature_zczGp,
        &feature_rdm,
        &feature_force32bitJumpTables,
        &feature_pan,
        &feature_lse,
        &feature_fuseCsel,
        &feature_uaops,
        &feature_fuseArithLogic,
        &feature_usePostraScheduler,
        &feature_vh,
        &feature_ras,
        &feature_zczFp,
        &feature_exynosm4,
    },
};

pub const cpu_falkor = Cpu{
    .name = "falkor",
    .llvm_name = "falkor",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_slowStrqroStore,
        &feature_rdm,
        &feature_zczGp,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_zczFp,
        &feature_crc,
        &feature_falkor,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
        &feature_trbe,
        &feature_ete,
        &feature_fpArmv8,
        &feature_fuseAes,
        &feature_neon,
        &feature_perfmon,
        &feature_usePostraScheduler,
    },
};

pub const cpu_kryo = Cpu{
    .name = "kryo",
    .llvm_name = "kryo",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_zczGp,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_zczFp,
        &feature_crc,
        &feature_kryo,
    },
};

pub const cpu_neoverseE1 = Cpu{
    .name = "neoverse-e1",
    .llvm_name = "neoverse-e1",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
        &feature_neoversee1,
    },
};

pub const cpu_neoverseN1 = Cpu{
    .name = "neoverse-n1",
    .llvm_name = "neoverse-n1",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_spe,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_ras,
        &feature_vh,
        &feature_fpArmv8,
        &feature_uaops,
        &feature_rcpc,
        &feature_ssbs,
        &feature_crc,
        &feature_neoversen1,
    },
};

pub const cpu_saphira = Cpu{
    .name = "saphira",
    .llvm_name = "saphira",
    .subfeatures = &[_]*const Feature {
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_lslFast,
        &feature_crc,
        &feature_fmi,
        &feature_predictableSelectExpensive,
        &feature_tracev84,
        &feature_tlbRmi,
        &feature_perfmon,
        &feature_zczGp,
        &feature_rdm,
        &feature_ccidx,
        &feature_mpam,
        &feature_pan,
        &feature_lse,
        &feature_rcpc,
        &feature_uaops,
        &feature_sel2,
        &feature_usePostraScheduler,
        &feature_nv,
        &feature_am,
        &feature_spe,
        &feature_dit,
        &feature_vh,
        &feature_ras,
        &feature_zczFp,
        &feature_pa,
        &feature_saphira,
    },
};

pub const cpu_thunderx = Cpu{
    .name = "thunderx",
    .llvm_name = "thunderx",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
        &feature_thunderx,
    },
};

pub const cpu_thunderx2t99 = Cpu{
    .name = "thunderx2t99",
    .llvm_name = "thunderx2t99",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_lor,
        &feature_lse,
        &feature_pan,
        &feature_arithBccFusion,
        &feature_rdm,
        &feature_aggressiveFma,
        &feature_vh,
        &feature_fpArmv8,
        &feature_crc,
        &feature_thunderx2t99,
    },
};

pub const cpu_thunderxt81 = Cpu{
    .name = "thunderxt81",
    .llvm_name = "thunderxt81",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
        &feature_thunderxt81,
    },
};

pub const cpu_thunderxt83 = Cpu{
    .name = "thunderxt83",
    .llvm_name = "thunderxt83",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
        &feature_thunderxt83,
    },
};

pub const cpu_thunderxt88 = Cpu{
    .name = "thunderxt88",
    .llvm_name = "thunderxt88",
    .subfeatures = &[_]*const Feature {
        &feature_predictableSelectExpensive,
        &feature_usePostraScheduler,
        &feature_perfmon,
        &feature_fpArmv8,
        &feature_crc,
        &feature_thunderxt88,
    },
};

pub const cpu_tsv110 = Cpu{
    .name = "tsv110",
    .llvm_name = "tsv110",
    .subfeatures = &[_]*const Feature {
        &feature_fuseAes,
        &feature_usePostraScheduler,
        &feature_ccpp,
        &feature_lor,
        &feature_dotprod,
        &feature_uaops,
        &feature_perfmon,
        &feature_spe,
        &feature_pan,
        &feature_lse,
        &feature_rdm,
        &feature_vh,
        &feature_fpArmv8,
        &feature_customCheapAsMove,
        &feature_ras,
        &feature_crc,
        &feature_tsv110,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_appleLatest,
    &cpu_cortexA35,
    &cpu_cortexA53,
    &cpu_cortexA55,
    &cpu_cortexA57,
    &cpu_cortexA65,
    &cpu_cortexA65ae,
    &cpu_cortexA72,
    &cpu_cortexA73,
    &cpu_cortexA75,
    &cpu_cortexA76,
    &cpu_cortexA76ae,
    &cpu_cyclone,
    &cpu_exynosM1,
    &cpu_exynosM2,
    &cpu_exynosM3,
    &cpu_exynosM4,
    &cpu_exynosM5,
    &cpu_falkor,
    &cpu_generic,
    &cpu_kryo,
    &cpu_neoverseE1,
    &cpu_neoverseN1,
    &cpu_saphira,
    &cpu_thunderx,
    &cpu_thunderx2t99,
    &cpu_thunderxt81,
    &cpu_thunderxt83,
    &cpu_thunderxt88,
    &cpu_tsv110,
};
