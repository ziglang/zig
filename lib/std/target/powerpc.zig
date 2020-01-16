const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_bit64 = Feature{
    .name = "bit64",
    .llvm_name = "64bit",
    .description = "Enable 64-bit instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bitregs64 = Feature{
    .name = "bitregs64",
    .llvm_name = "64bitregs",
    .description = "Enable 64-bit registers usage for ppc32 [beta]",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_altivec = Feature{
    .name = "altivec",
    .llvm_name = "altivec",
    .description = "Enable Altivec instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_bpermd = Feature{
    .name = "bpermd",
    .llvm_name = "bpermd",
    .description = "Enable the bpermd instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_booke = Feature{
    .name = "booke",
    .llvm_name = "booke",
    .description = "Enable Book E instructions",
    .dependencies = &[_]*const Feature {
        &feature_icbt,
    },
};

pub const feature_cmpb = Feature{
    .name = "cmpb",
    .llvm_name = "cmpb",
    .description = "Enable the cmpb instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_crbits = Feature{
    .name = "crbits",
    .llvm_name = "crbits",
    .description = "Use condition-register bits individually",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_directMove = Feature{
    .name = "directMove",
    .llvm_name = "direct-move",
    .description = "Enable Power8 direct move instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_e500 = Feature{
    .name = "e500",
    .llvm_name = "e500",
    .description = "Enable E500/E500mc instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_extdiv = Feature{
    .name = "extdiv",
    .llvm_name = "extdiv",
    .description = "Enable extended divide instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fcpsgn = Feature{
    .name = "fcpsgn",
    .llvm_name = "fcpsgn",
    .description = "Enable the fcpsgn instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fpcvt = Feature{
    .name = "fpcvt",
    .llvm_name = "fpcvt",
    .description = "Enable fc[ft]* (unsigned and single-precision) and lfiwzx instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fprnd = Feature{
    .name = "fprnd",
    .llvm_name = "fprnd",
    .description = "Enable the fri[mnpz] instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fpu = Feature{
    .name = "fpu",
    .llvm_name = "fpu",
    .description = "Enable classic FPU instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fre = Feature{
    .name = "fre",
    .llvm_name = "fre",
    .description = "Enable the fre instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fres = Feature{
    .name = "fres",
    .llvm_name = "fres",
    .description = "Enable the fres instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_frsqrte = Feature{
    .name = "frsqrte",
    .llvm_name = "frsqrte",
    .description = "Enable the frsqrte instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_frsqrtes = Feature{
    .name = "frsqrtes",
    .llvm_name = "frsqrtes",
    .description = "Enable the frsqrtes instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_fsqrt = Feature{
    .name = "fsqrt",
    .llvm_name = "fsqrt",
    .description = "Enable the fsqrt instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_float128 = Feature{
    .name = "float128",
    .llvm_name = "float128",
    .description = "Enable the __float128 data type for IEEE-754R Binary128.",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_htm = Feature{
    .name = "htm",
    .llvm_name = "htm",
    .description = "Enable Hardware Transactional Memory instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_hardFloat = Feature{
    .name = "hardFloat",
    .llvm_name = "hard-float",
    .description = "Enable floating-point instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_icbt = Feature{
    .name = "icbt",
    .llvm_name = "icbt",
    .description = "Enable icbt instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_isaV30Instructions = Feature{
    .name = "isaV30Instructions",
    .llvm_name = "isa-v30-instructions",
    .description = "Enable instructions added in ISA 3.0.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_isel = Feature{
    .name = "isel",
    .llvm_name = "isel",
    .description = "Enable the isel instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_invariantFunctionDescriptors = Feature{
    .name = "invariantFunctionDescriptors",
    .llvm_name = "invariant-function-descriptors",
    .description = "Assume function descriptors are invariant",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ldbrx = Feature{
    .name = "ldbrx",
    .llvm_name = "ldbrx",
    .description = "Enable the ldbrx instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lfiwax = Feature{
    .name = "lfiwax",
    .llvm_name = "lfiwax",
    .description = "Enable the lfiwax instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_longcall = Feature{
    .name = "longcall",
    .llvm_name = "longcall",
    .description = "Always use indirect calls",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mfocrf = Feature{
    .name = "mfocrf",
    .llvm_name = "mfocrf",
    .description = "Enable the MFOCRF instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_msync = Feature{
    .name = "msync",
    .llvm_name = "msync",
    .description = "Has only the msync instruction instead of sync",
    .dependencies = &[_]*const Feature {
        &feature_icbt,
    },
};

pub const feature_power8Altivec = Feature{
    .name = "power8Altivec",
    .llvm_name = "power8-altivec",
    .description = "Enable POWER8 Altivec instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_crypto = Feature{
    .name = "crypto",
    .llvm_name = "crypto",
    .description = "Enable POWER8 Crypto instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_power8Vector = Feature{
    .name = "power8Vector",
    .llvm_name = "power8-vector",
    .description = "Enable POWER8 vector instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_power9Altivec = Feature{
    .name = "power9Altivec",
    .llvm_name = "power9-altivec",
    .description = "Enable POWER9 Altivec instructions",
    .dependencies = &[_]*const Feature {
        &feature_isaV30Instructions,
        &feature_hardFloat,
    },
};

pub const feature_power9Vector = Feature{
    .name = "power9Vector",
    .llvm_name = "power9-vector",
    .description = "Enable POWER9 vector instructions",
    .dependencies = &[_]*const Feature {
        &feature_isaV30Instructions,
        &feature_hardFloat,
    },
};

pub const feature_popcntd = Feature{
    .name = "popcntd",
    .llvm_name = "popcntd",
    .description = "Enable the popcnt[dw] instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ppc4xx = Feature{
    .name = "ppc4xx",
    .llvm_name = "ppc4xx",
    .description = "Enable PPC 4xx instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ppc6xx = Feature{
    .name = "ppc6xx",
    .llvm_name = "ppc6xx",
    .description = "Enable PPC 6xx instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ppcPostraSched = Feature{
    .name = "ppcPostraSched",
    .llvm_name = "ppc-postra-sched",
    .description = "Use PowerPC post-RA scheduling strategy",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ppcPreraSched = Feature{
    .name = "ppcPreraSched",
    .llvm_name = "ppc-prera-sched",
    .description = "Use PowerPC pre-RA scheduling strategy",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_partwordAtomics = Feature{
    .name = "partwordAtomics",
    .llvm_name = "partword-atomics",
    .description = "Enable l[bh]arx and st[bh]cx.",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_qpx = Feature{
    .name = "qpx",
    .llvm_name = "qpx",
    .description = "Enable QPX instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_recipprec = Feature{
    .name = "recipprec",
    .llvm_name = "recipprec",
    .description = "Assume higher precision reciprocal estimates",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_spe = Feature{
    .name = "spe",
    .llvm_name = "spe",
    .description = "Enable SPE instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_stfiwx = Feature{
    .name = "stfiwx",
    .llvm_name = "stfiwx",
    .description = "Enable the stfiwx instruction",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_securePlt = Feature{
    .name = "securePlt",
    .llvm_name = "secure-plt",
    .description = "Enable secure plt mode",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowPopcntd = Feature{
    .name = "slowPopcntd",
    .llvm_name = "slow-popcntd",
    .description = "Has slow popcnt[dw] instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_twoConstNr = Feature{
    .name = "twoConstNr",
    .llvm_name = "two-const-nr",
    .description = "Requires two constant Newton-Raphson computation",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vsx = Feature{
    .name = "vsx",
    .llvm_name = "vsx",
    .description = "Enable VSX instructions",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const feature_vectorsUseTwoUnits = Feature{
    .name = "vectorsUseTwoUnits",
    .llvm_name = "vectors-use-two-units",
    .description = "Vectors use two units",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fpu,
    },
};

pub const cpu_602 = Cpu{
    .name = "602",
    .llvm_name = "602",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fpu,
    },
};

pub const cpu_603 = Cpu{
    .name = "603",
    .llvm_name = "603",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_e603 = Cpu{
    .name = "e603",
    .llvm_name = "603e",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_ev603 = Cpu{
    .name = "ev603",
    .llvm_name = "603ev",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_604 = Cpu{
    .name = "604",
    .llvm_name = "604",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_e604 = Cpu{
    .name = "e604",
    .llvm_name = "604e",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_620 = Cpu{
    .name = "620",
    .llvm_name = "620",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_7400 = Cpu{
    .name = "7400",
    .llvm_name = "7400",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_7450 = Cpu{
    .name = "7450",
    .llvm_name = "7450",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_750 = Cpu{
    .name = "750",
    .llvm_name = "750",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_970 = Cpu{
    .name = "970",
    .llvm_name = "970",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
        &feature_icbt,
        &feature_booke,
        &feature_isel,
    },
};

pub const cpu_e500mc = Cpu{
    .name = "e500mc",
    .llvm_name = "e500mc",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g4 = Cpu{
    .name = "g4",
    .llvm_name = "g4",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g4Plus = Cpu{
    .name = "g4Plus",
    .llvm_name = "g4+",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
        &feature_altivec,
        &feature_fres,
        &feature_frsqrte,
    },
};

pub const cpu_g5 = Cpu{
    .name = "g5",
    .llvm_name = "g5",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc = Cpu{
    .name = "ppc",
    .llvm_name = "ppc",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc32 = Cpu{
    .name = "ppc32",
    .llvm_name = "ppc32",
    .dependencies = &[_]*const Feature {
        &feature_hardFloat,
    },
};

pub const cpu_ppc64 = Cpu{
    .name = "ppc64",
    .llvm_name = "ppc64",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
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
