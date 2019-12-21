const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_bit64 = Feature{
    .name = "64bit",
    .description = "Enable 64-bit instructions",
    .llvm_name = "64bit",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_bitregs64 = Feature{
    .name = "64bitregs",
    .description = "Enable 64-bit registers usage for ppc32 [beta]",
    .llvm_name = "64bitregs",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_altivec = Feature{
    .name = "altivec",
    .description = "Enable Altivec instructions",
    .llvm_name = "altivec",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_bpermd = Feature{
    .name = "bpermd",
    .description = "Enable the bpermd instruction",
    .llvm_name = "bpermd",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_booke = Feature{
    .name = "booke",
    .description = "Enable Book E instructions",
    .llvm_name = "booke",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
    },
};

pub const feature_cmpb = Feature{
    .name = "cmpb",
    .description = "Enable the cmpb instruction",
    .llvm_name = "cmpb",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_crbits = Feature{
    .name = "crbits",
    .description = "Use condition-register bits individually",
    .llvm_name = "crbits",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_directMove = Feature{
    .name = "direct-move",
    .description = "Enable Power8 direct move instructions",
    .llvm_name = "direct-move",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_e500 = Feature{
    .name = "e500",
    .description = "Enable E500/E500mc instructions",
    .llvm_name = "e500",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_extdiv = Feature{
    .name = "extdiv",
    .description = "Enable extended divide instructions",
    .llvm_name = "extdiv",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fcpsgn = Feature{
    .name = "fcpsgn",
    .description = "Enable the fcpsgn instruction",
    .llvm_name = "fcpsgn",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fpcvt = Feature{
    .name = "fpcvt",
    .description = "Enable fc[ft]* (unsigned and single-precision) and lfiwzx instructions",
    .llvm_name = "fpcvt",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fprnd = Feature{
    .name = "fprnd",
    .description = "Enable the fri[mnpz] instructions",
    .llvm_name = "fprnd",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fpu = Feature{
    .name = "fpu",
    .description = "Enable classic FPU instructions",
    .llvm_name = "fpu",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fre = Feature{
    .name = "fre",
    .description = "Enable the fre instruction",
    .llvm_name = "fre",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fres = Feature{
    .name = "fres",
    .description = "Enable the fres instruction",
    .llvm_name = "fres",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_frsqrte = Feature{
    .name = "frsqrte",
    .description = "Enable the frsqrte instruction",
    .llvm_name = "frsqrte",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_frsqrtes = Feature{
    .name = "frsqrtes",
    .description = "Enable the frsqrtes instruction",
    .llvm_name = "frsqrtes",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fsqrt = Feature{
    .name = "fsqrt",
    .description = "Enable the fsqrt instruction",
    .llvm_name = "fsqrt",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_float128 = Feature{
    .name = "float128",
    .description = "Enable the __float128 data type for IEEE-754R Binary128.",
    .llvm_name = "float128",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_htm = Feature{
    .name = "htm",
    .description = "Enable Hardware Transactional Memory instructions",
    .llvm_name = "htm",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_hardFloat = Feature{
    .name = "hard-float",
    .description = "Enable floating-point instructions",
    .llvm_name = "hard-float",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_icbt = Feature{
    .name = "icbt",
    .description = "Enable icbt instruction",
    .llvm_name = "icbt",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_isaV30Instructions = Feature{
    .name = "isa-v30-instructions",
    .description = "Enable instructions added in ISA 3.0.",
    .llvm_name = "isa-v30-instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_isel = Feature{
    .name = "isel",
    .description = "Enable the isel instruction",
    .llvm_name = "isel",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_invariantFunctionDescriptors = Feature{
    .name = "invariant-function-descriptors",
    .description = "Assume function descriptors are invariant",
    .llvm_name = "invariant-function-descriptors",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ldbrx = Feature{
    .name = "ldbrx",
    .description = "Enable the ldbrx instruction",
    .llvm_name = "ldbrx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_lfiwax = Feature{
    .name = "lfiwax",
    .description = "Enable the lfiwax instruction",
    .llvm_name = "lfiwax",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_longcall = Feature{
    .name = "longcall",
    .description = "Always use indirect calls",
    .llvm_name = "longcall",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mfocrf = Feature{
    .name = "mfocrf",
    .description = "Enable the MFOCRF instruction",
    .llvm_name = "mfocrf",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_msync = Feature{
    .name = "msync",
    .description = "Has only the msync instruction instead of sync",
    .llvm_name = "msync",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
    },
};

pub const feature_power8Altivec = Feature{
    .name = "power8-altivec",
    .description = "Enable POWER8 Altivec instructions",
    .llvm_name = "power8-altivec",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .description = "Enable POWER8 Crypto instructions",
    .llvm_name = "crypto",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_power8Vector = Feature{
    .name = "power8-vector",
    .description = "Enable POWER8 vector instructions",
    .llvm_name = "power8-vector",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_power9Altivec = Feature{
    .name = "power9-altivec",
    .description = "Enable POWER9 Altivec instructions",
    .llvm_name = "power9-altivec",
    .subfeatures = &[_]*const Feature {
        &feature_isaV30Instructions,
        &feature_hardFloat,
    },
};

pub const feature_power9Vector = Feature{
    .name = "power9-vector",
    .description = "Enable POWER9 vector instructions",
    .llvm_name = "power9-vector",
    .subfeatures = &[_]*const Feature {
        &feature_isaV30Instructions,
        &feature_hardFloat,
    },
};

pub const feature_popcntd = Feature{
    .name = "popcntd",
    .description = "Enable the popcnt[dw] instructions",
    .llvm_name = "popcntd",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ppc4xx = Feature{
    .name = "ppc4xx",
    .description = "Enable PPC 4xx instructions",
    .llvm_name = "ppc4xx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ppc6xx = Feature{
    .name = "ppc6xx",
    .description = "Enable PPC 6xx instructions",
    .llvm_name = "ppc6xx",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ppcPostraSched = Feature{
    .name = "ppc-postra-sched",
    .description = "Use PowerPC post-RA scheduling strategy",
    .llvm_name = "ppc-postra-sched",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ppcPreraSched = Feature{
    .name = "ppc-prera-sched",
    .description = "Use PowerPC pre-RA scheduling strategy",
    .llvm_name = "ppc-prera-sched",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_partwordAtomics = Feature{
    .name = "partword-atomics",
    .description = "Enable l[bh]arx and st[bh]cx.",
    .llvm_name = "partword-atomics",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_qpx = Feature{
    .name = "qpx",
    .description = "Enable QPX instructions",
    .llvm_name = "qpx",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_recipprec = Feature{
    .name = "recipprec",
    .description = "Assume higher precision reciprocal estimates",
    .llvm_name = "recipprec",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_spe = Feature{
    .name = "spe",
    .description = "Enable SPE instructions",
    .llvm_name = "spe",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_stfiwx = Feature{
    .name = "stfiwx",
    .description = "Enable the stfiwx instruction",
    .llvm_name = "stfiwx",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_securePlt = Feature{
    .name = "secure-plt",
    .description = "Enable secure plt mode",
    .llvm_name = "secure-plt",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_slowPopcntd = Feature{
    .name = "slow-popcntd",
    .description = "Has slow popcnt[dw] instructions",
    .llvm_name = "slow-popcntd",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_twoConstNr = Feature{
    .name = "two-const-nr",
    .description = "Requires two constant Newton-Raphson computation",
    .llvm_name = "two-const-nr",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vsx = Feature{
    .name = "vsx",
    .description = "Enable VSX instructions",
    .llvm_name = "vsx",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_vectorsUseTwoUnits = Feature{
    .name = "vectors-use-two-units",
    .description = "Vectors use two units",
    .llvm_name = "vectors-use-two-units",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_bit64,
    &feature_bitregs64,
    &feature_altivec,
    &feature_bpermd,
    &feature_booke,
    &feature_cmpb,
    &feature_crbits,
    &feature_directMove,
    &feature_e500,
    &feature_extdiv,
    &feature_fcpsgn,
    &feature_fpcvt,
    &feature_fprnd,
    &feature_fpu,
    &feature_fre,
    &feature_fres,
    &feature_frsqrte,
    &feature_frsqrtes,
    &feature_fsqrt,
    &feature_float128,
    &feature_htm,
    &feature_hardFloat,
    &feature_icbt,
    &feature_isaV30Instructions,
    &feature_isel,
    &feature_invariantFunctionDescriptors,
    &feature_ldbrx,
    &feature_lfiwax,
    &feature_longcall,
    &feature_mfocrf,
    &feature_msync,
    &feature_power8Altivec,
    &feature_crypto,
    &feature_power8Vector,
    &feature_power9Altivec,
    &feature_power9Vector,
    &feature_popcntd,
    &feature_ppc4xx,
    &feature_ppc6xx,
    &feature_ppcPostraSched,
    &feature_ppcPreraSched,
    &feature_partwordAtomics,
    &feature_qpx,
    &feature_recipprec,
    &feature_spe,
    &feature_stfiwx,
    &feature_securePlt,
    &feature_slowPopcntd,
    &feature_twoConstNr,
    &feature_vsx,
    &feature_vectorsUseTwoUnits,
};

pub const cpu_440 = Cpu{
    .name = "440",
    .llvm_name = "440",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
        &feature_booke,
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
        &feature_isel,
        &feature_msync,
    },
};

pub const cpu_450 = Cpu{
    .name = "450",
    .llvm_name = "450",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
        &feature_booke,
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
        &feature_isel,
        &feature_msync,
    },
};

pub const cpu_601 = Cpu{
    .name = "601",
    .llvm_name = "601",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fpu,
    },
};

pub const cpu_602 = Cpu{
    .name = "602",
    .llvm_name = "602",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fpu,
    },
};

pub const cpu_603 = Cpu{
    .name = "603",
    .llvm_name = "603",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_e603 = Cpu{
    .name = "603e",
    .llvm_name = "603e",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_ev603 = Cpu{
    .name = "603ev",
    .llvm_name = "603ev",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_604 = Cpu{
    .name = "604",
    .llvm_name = "604",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_e604 = Cpu{
    .name = "604e",
    .llvm_name = "604e",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_620 = Cpu{
    .name = "620",
    .llvm_name = "620",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_7400 = Cpu{
    .name = "7400",
    .llvm_name = "7400",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_7450 = Cpu{
    .name = "7450",
    .llvm_name = "7450",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_750 = Cpu{
    .name = "750",
    .llvm_name = "750",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_970 = Cpu{
    .name = "970",
    .llvm_name = "970",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_a2 = Cpu{
    .name = "a2",
    .llvm_name = "a2",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_icbt,
        &feature_booke,
        &feature_cmpb,
        &feature_hardFloat,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_slowPopcntd,
    },
};

pub const cpu_a2q = Cpu{
    .name = "a2q",
    .llvm_name = "a2q",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_icbt,
        &feature_booke,
        &feature_cmpb,
        &feature_hardFloat,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_qpx,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_slowPopcntd,
    },
};

pub const cpu_e500 = Cpu{
    .name = "e500",
    .llvm_name = "e500",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
        &feature_booke,
        &feature_isel,
    },
};

pub const cpu_e500mc = Cpu{
    .name = "e500mc",
    .llvm_name = "e500mc",
    .subfeatures = &[_]*const Feature {
        &feature_icbt,
        &feature_booke,
        &feature_isel,
        &feature_hardFloat,
        &feature_stfiwx,
    },
};

pub const cpu_e5500 = Cpu{
    .name = "e5500",
    .llvm_name = "e5500",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_icbt,
        &feature_booke,
        &feature_isel,
        &feature_mfocrf,
        &feature_hardFloat,
        &feature_stfiwx,
    },
};

pub const cpu_g3 = Cpu{
    .name = "g3",
    .llvm_name = "g3",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g4 = Cpu{
    .name = "g4",
    .llvm_name = "g4",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g4Plus = Cpu{
    .name = "g4+",
    .llvm_name = "g4+",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g5 = Cpu{
    .name = "g5",
    .llvm_name = "g5",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc = Cpu{
    .name = "ppc",
    .llvm_name = "ppc",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc32 = Cpu{
    .name = "ppc32",
    .llvm_name = "ppc32",
    .subfeatures = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc64 = Cpu{
    .name = "ppc64",
    .llvm_name = "ppc64",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_ppc64le = Cpu{
    .name = "ppc64le",
    .llvm_name = "ppc64le",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_bpermd,
        &feature_cmpb,
        &feature_directMove,
        &feature_extdiv,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_htm,
        &feature_icbt,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_power8Altivec,
        &feature_crypto,
        &feature_power8Vector,
        &feature_popcntd,
        &feature_partwordAtomics,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_twoConstNr,
        &feature_vsx,
    },
};

pub const cpu_pwr3 = Cpu{
    .name = "pwr3",
    .llvm_name = "pwr3",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_pwr4 = Cpu{
    .name = "pwr4",
    .llvm_name = "pwr4",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_pwr5 = Cpu{
    .name = "pwr5",
    .llvm_name = "pwr5",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_pwr5x = Cpu{
    .name = "pwr5x",
    .llvm_name = "pwr5x",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_mfocrf,
        &feature_stfiwx,
    },
};

pub const cpu_pwr6 = Cpu{
    .name = "pwr6",
    .llvm_name = "pwr6",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_cmpb,
        &feature_fcpsgn,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_recipprec,
        &feature_stfiwx,
    },
};

pub const cpu_pwr6x = Cpu{
    .name = "pwr6x",
    .llvm_name = "pwr6x",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_cmpb,
        &feature_fcpsgn,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_recipprec,
        &feature_stfiwx,
    },
};

pub const cpu_pwr7 = Cpu{
    .name = "pwr7",
    .llvm_name = "pwr7",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_bpermd,
        &feature_cmpb,
        &feature_extdiv,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_popcntd,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_twoConstNr,
        &feature_vsx,
    },
};

pub const cpu_pwr8 = Cpu{
    .name = "pwr8",
    .llvm_name = "pwr8",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_bpermd,
        &feature_cmpb,
        &feature_directMove,
        &feature_extdiv,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_htm,
        &feature_icbt,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_power8Altivec,
        &feature_crypto,
        &feature_power8Vector,
        &feature_popcntd,
        &feature_partwordAtomics,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_twoConstNr,
        &feature_vsx,
    },
};

pub const cpu_pwr9 = Cpu{
    .name = "pwr9",
    .llvm_name = "pwr9",
    .subfeatures = &[_]*const Feature {
        &feature_bit64,
        &feature_hardFloat,
        &feature_altivec,
        &feature_bpermd,
        &feature_cmpb,
        &feature_directMove,
        &feature_extdiv,
        &feature_fcpsgn,
        &feature_fpcvt,
        &feature_fprnd,
        &feature_fre,
        &feature_fres,
        &feature_frsqrte,
        &feature_frsqrtes,
        &feature_fsqrt,
        &feature_htm,
        &feature_icbt,
        &feature_isaV30Instructions,
        &feature_isel,
        &feature_ldbrx,
        &feature_lfiwax,
        &feature_mfocrf,
        &feature_power8Altivec,
        &feature_crypto,
        &feature_power8Vector,
        &feature_power9Altivec,
        &feature_power9Vector,
        &feature_popcntd,
        &feature_ppcPostraSched,
        &feature_ppcPreraSched,
        &feature_partwordAtomics,
        &feature_recipprec,
        &feature_stfiwx,
        &feature_twoConstNr,
        &feature_vsx,
        &feature_vectorsUseTwoUnits,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_440,
    &cpu_450,
    &cpu_601,
    &cpu_602,
    &cpu_603,
    &cpu_e603,
    &cpu_ev603,
    &cpu_604,
    &cpu_e604,
    &cpu_620,
    &cpu_7400,
    &cpu_7450,
    &cpu_750,
    &cpu_970,
    &cpu_a2,
    &cpu_a2q,
    &cpu_e500,
    &cpu_e500mc,
    &cpu_e5500,
    &cpu_g3,
    &cpu_g4,
    &cpu_g4Plus,
    &cpu_g5,
    &cpu_generic,
    &cpu_ppc,
    &cpu_ppc32,
    &cpu_ppc64,
    &cpu_ppc64le,
    &cpu_pwr3,
    &cpu_pwr4,
    &cpu_pwr5,
    &cpu_pwr5x,
    &cpu_pwr6,
    &cpu_pwr6x,
    &cpu_pwr7,
    &cpu_pwr8,
    &cpu_pwr9,
};
