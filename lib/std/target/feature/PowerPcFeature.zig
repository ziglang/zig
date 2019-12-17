const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const PowerPcFeature = enum {
    Bit64,
    Bitregs64,
    Altivec,
    Bpermd,
    Booke,
    Cmpb,
    Crbits,
    DirectMove,
    E500,
    Extdiv,
    Fcpsgn,
    Fpcvt,
    Fprnd,
    Fpu,
    Fre,
    Fres,
    Frsqrte,
    Frsqrtes,
    Fsqrt,
    Float128,
    Htm,
    HardFloat,
    Icbt,
    IsaV30Instructions,
    Isel,
    InvariantFunctionDescriptors,
    Ldbrx,
    Lfiwax,
    Longcall,
    Mfocrf,
    Msync,
    Power8Altivec,
    Crypto,
    Power8Vector,
    Power9Altivec,
    Power9Vector,
    Popcntd,
    Ppc4xx,
    Ppc6xx,
    PpcPostraSched,
    PpcPreraSched,
    PartwordAtomics,
    Qpx,
    Recipprec,
    Spe,
    Stfiwx,
    SecurePlt,
    SlowPopcntd,
    TwoConstNr,
    Vsx,
    VectorsUseTwoUnits,

    pub fn getInfo(self: @This()) FeatureInfo(@This()) {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Bit64, "64bit", "Enable 64-bit instructions", "64bit"),
        FeatureInfo(@This()).create(.Bitregs64, "64bitregs", "Enable 64-bit registers usage for ppc32 [beta]", "64bitregs"),
        FeatureInfo(@This()).createWithSubfeatures(.Altivec, "altivec", "Enable Altivec instructions", "altivec", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.Bpermd, "bpermd", "Enable the bpermd instruction", "bpermd"),
        FeatureInfo(@This()).createWithSubfeatures(.Booke, "booke", "Enable Book E instructions", "booke", &[_]@This() {
            .Icbt,
        }),
        FeatureInfo(@This()).create(.Cmpb, "cmpb", "Enable the cmpb instruction", "cmpb"),
        FeatureInfo(@This()).create(.Crbits, "crbits", "Use condition-register bits individually", "crbits"),
        FeatureInfo(@This()).createWithSubfeatures(.DirectMove, "direct-move", "Enable Power8 direct move instructions", "direct-move", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.E500, "e500", "Enable E500/E500mc instructions", "e500"),
        FeatureInfo(@This()).create(.Extdiv, "extdiv", "Enable extended divide instructions", "extdiv"),
        FeatureInfo(@This()).createWithSubfeatures(.Fcpsgn, "fcpsgn", "Enable the fcpsgn instruction", "fcpsgn", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fpcvt, "fpcvt", "Enable fc[ft]* (unsigned and single-precision) and lfiwzx instructions", "fpcvt", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fprnd, "fprnd", "Enable the fri[mnpz] instructions", "fprnd", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fpu, "fpu", "Enable classic FPU instructions", "fpu", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fre, "fre", "Enable the fre instruction", "fre", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fres, "fres", "Enable the fres instruction", "fres", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Frsqrte, "frsqrte", "Enable the frsqrte instruction", "frsqrte", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Frsqrtes, "frsqrtes", "Enable the frsqrtes instruction", "frsqrtes", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Fsqrt, "fsqrt", "Enable the fsqrt instruction", "fsqrt", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Float128, "float128", "Enable the __float128 data type for IEEE-754R Binary128.", "float128", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.Htm, "htm", "Enable Hardware Transactional Memory instructions", "htm"),
        FeatureInfo(@This()).create(.HardFloat, "hard-float", "Enable floating-point instructions", "hard-float"),
        FeatureInfo(@This()).create(.Icbt, "icbt", "Enable icbt instruction", "icbt"),
        FeatureInfo(@This()).create(.IsaV30Instructions, "isa-v30-instructions", "Enable instructions added in ISA 3.0.", "isa-v30-instructions"),
        FeatureInfo(@This()).create(.Isel, "isel", "Enable the isel instruction", "isel"),
        FeatureInfo(@This()).create(.InvariantFunctionDescriptors, "invariant-function-descriptors", "Assume function descriptors are invariant", "invariant-function-descriptors"),
        FeatureInfo(@This()).create(.Ldbrx, "ldbrx", "Enable the ldbrx instruction", "ldbrx"),
        FeatureInfo(@This()).createWithSubfeatures(.Lfiwax, "lfiwax", "Enable the lfiwax instruction", "lfiwax", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.Longcall, "longcall", "Always use indirect calls", "longcall"),
        FeatureInfo(@This()).create(.Mfocrf, "mfocrf", "Enable the MFOCRF instruction", "mfocrf"),
        FeatureInfo(@This()).createWithSubfeatures(.Msync, "msync", "Has only the msync instruction instead of sync", "msync", &[_]@This() {
            .Icbt,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Power8Altivec, "power8-altivec", "Enable POWER8 Altivec instructions", "power8-altivec", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Crypto, "crypto", "Enable POWER8 Crypto instructions", "crypto", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Power8Vector, "power8-vector", "Enable POWER8 vector instructions", "power8-vector", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Power9Altivec, "power9-altivec", "Enable POWER9 Altivec instructions", "power9-altivec", &[_]@This() {
            .IsaV30Instructions,
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Power9Vector, "power9-vector", "Enable POWER9 vector instructions", "power9-vector", &[_]@This() {
            .IsaV30Instructions,
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.Popcntd, "popcntd", "Enable the popcnt[dw] instructions", "popcntd"),
        FeatureInfo(@This()).create(.Ppc4xx, "ppc4xx", "Enable PPC 4xx instructions", "ppc4xx"),
        FeatureInfo(@This()).create(.Ppc6xx, "ppc6xx", "Enable PPC 6xx instructions", "ppc6xx"),
        FeatureInfo(@This()).create(.PpcPostraSched, "ppc-postra-sched", "Use PowerPC post-RA scheduling strategy", "ppc-postra-sched"),
        FeatureInfo(@This()).create(.PpcPreraSched, "ppc-prera-sched", "Use PowerPC pre-RA scheduling strategy", "ppc-prera-sched"),
        FeatureInfo(@This()).create(.PartwordAtomics, "partword-atomics", "Enable l[bh]arx and st[bh]cx.", "partword-atomics"),
        FeatureInfo(@This()).createWithSubfeatures(.Qpx, "qpx", "Enable QPX instructions", "qpx", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.Recipprec, "recipprec", "Assume higher precision reciprocal estimates", "recipprec"),
        FeatureInfo(@This()).createWithSubfeatures(.Spe, "spe", "Enable SPE instructions", "spe", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Stfiwx, "stfiwx", "Enable the stfiwx instruction", "stfiwx", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.SecurePlt, "secure-plt", "Enable secure plt mode", "secure-plt"),
        FeatureInfo(@This()).create(.SlowPopcntd, "slow-popcntd", "Has slow popcnt[dw] instructions", "slow-popcntd"),
        FeatureInfo(@This()).create(.TwoConstNr, "two-const-nr", "Requires two constant Newton-Raphson computation", "two-const-nr"),
        FeatureInfo(@This()).createWithSubfeatures(.Vsx, "vsx", "Enable VSX instructions", "vsx", &[_]@This() {
            .HardFloat,
        }),
        FeatureInfo(@This()).create(.VectorsUseTwoUnits, "vectors-use-two-units", "Vectors use two units", "vectors-use-two-units"),
    };
};
