const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    @"64bit",
    @"64bitregs",
    allow_unaligned_fp_access,
    altivec,
    booke,
    bpermd,
    cmpb,
    crbits,
    crypto,
    direct_move,
    e500,
    extdiv,
    fcpsgn,
    float128,
    fpcvt,
    fprnd,
    fpu,
    fre,
    fres,
    frsqrte,
    frsqrtes,
    fsqrt,
    hard_float,
    htm,
    icbt,
    invariant_function_descriptors,
    isa_v30_instructions,
    isel,
    ldbrx,
    lfiwax,
    longcall,
    mfocrf,
    msync,
    partword_atomics,
    popcntd,
    power8_altivec,
    power8_vector,
    power9_altivec,
    power9_vector,
    ppc_postra_sched,
    ppc_prera_sched,
    ppc4xx,
    ppc6xx,
    qpx,
    recipprec,
    secure_plt,
    slow_popcntd,
    spe,
    stfiwx,
    two_const_nr,
    vectors_use_two_units,
    vsx,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.@"64bit")] = .{
        .llvm_name = "64bit",
        .description = "Enable 64-bit instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.@"64bitregs")] = .{
        .llvm_name = "64bitregs",
        .description = "Enable 64-bit registers usage for ppc32 [beta]",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.allow_unaligned_fp_access)] = .{
        .llvm_name = "allow-unaligned-fp-access",
        .description = "CPU does not trap on unaligned FP access",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.altivec)] = .{
        .llvm_name = "altivec",
        .description = "Enable Altivec instructions",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.booke)] = .{
        .llvm_name = "booke",
        .description = "Enable Book E instructions",
        .dependencies = featureSet(&[_]Feature{
            .icbt,
        }),
    };
    result[@enumToInt(Feature.bpermd)] = .{
        .llvm_name = "bpermd",
        .description = "Enable the bpermd instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.cmpb)] = .{
        .llvm_name = "cmpb",
        .description = "Enable the cmpb instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.crbits)] = .{
        .llvm_name = "crbits",
        .description = "Use condition-register bits individually",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.crypto)] = .{
        .llvm_name = "crypto",
        .description = "Enable POWER8 Crypto instructions",
        .dependencies = featureSet(&[_]Feature{
            .power8_altivec,
        }),
    };
    result[@enumToInt(Feature.direct_move)] = .{
        .llvm_name = "direct-move",
        .description = "Enable Power8 direct move instructions",
        .dependencies = featureSet(&[_]Feature{
            .vsx,
        }),
    };
    result[@enumToInt(Feature.e500)] = .{
        .llvm_name = "e500",
        .description = "Enable E500/E500mc instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.extdiv)] = .{
        .llvm_name = "extdiv",
        .description = "Enable extended divide instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fcpsgn)] = .{
        .llvm_name = "fcpsgn",
        .description = "Enable the fcpsgn instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.float128)] = .{
        .llvm_name = "float128",
        .description = "Enable the __float128 data type for IEEE-754R Binary128.",
        .dependencies = featureSet(&[_]Feature{
            .vsx,
        }),
    };
    result[@enumToInt(Feature.fpcvt)] = .{
        .llvm_name = "fpcvt",
        .description = "Enable fc[ft]* (unsigned and single-precision) and lfiwzx instructions",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.fprnd)] = .{
        .llvm_name = "fprnd",
        .description = "Enable the fri[mnpz] instructions",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.fpu)] = .{
        .llvm_name = "fpu",
        .description = "Enable classic FPU instructions",
        .dependencies = featureSet(&[_]Feature{
            .hard_float,
        }),
    };
    result[@enumToInt(Feature.fre)] = .{
        .llvm_name = "fre",
        .description = "Enable the fre instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.fres)] = .{
        .llvm_name = "fres",
        .description = "Enable the fres instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.frsqrte)] = .{
        .llvm_name = "frsqrte",
        .description = "Enable the frsqrte instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.frsqrtes)] = .{
        .llvm_name = "frsqrtes",
        .description = "Enable the frsqrtes instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.fsqrt)] = .{
        .llvm_name = "fsqrt",
        .description = "Enable the fsqrt instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.hard_float)] = .{
        .llvm_name = "hard-float",
        .description = "Enable floating-point instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.htm)] = .{
        .llvm_name = "htm",
        .description = "Enable Hardware Transactional Memory instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.icbt)] = .{
        .llvm_name = "icbt",
        .description = "Enable icbt instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.invariant_function_descriptors)] = .{
        .llvm_name = "invariant-function-descriptors",
        .description = "Assume function descriptors are invariant",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.isa_v30_instructions)] = .{
        .llvm_name = "isa-v30-instructions",
        .description = "Enable instructions added in ISA 3.0.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.isel)] = .{
        .llvm_name = "isel",
        .description = "Enable the isel instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ldbrx)] = .{
        .llvm_name = "ldbrx",
        .description = "Enable the ldbrx instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lfiwax)] = .{
        .llvm_name = "lfiwax",
        .description = "Enable the lfiwax instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.longcall)] = .{
        .llvm_name = "longcall",
        .description = "Always use indirect calls",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mfocrf)] = .{
        .llvm_name = "mfocrf",
        .description = "Enable the MFOCRF instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.msync)] = .{
        .llvm_name = "msync",
        .description = "Has only the msync instruction instead of sync",
        .dependencies = featureSet(&[_]Feature{
            .booke,
        }),
    };
    result[@enumToInt(Feature.partword_atomics)] = .{
        .llvm_name = "partword-atomics",
        .description = "Enable l[bh]arx and st[bh]cx.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.popcntd)] = .{
        .llvm_name = "popcntd",
        .description = "Enable the popcnt[dw] instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.power8_altivec)] = .{
        .llvm_name = "power8-altivec",
        .description = "Enable POWER8 Altivec instructions",
        .dependencies = featureSet(&[_]Feature{
            .altivec,
        }),
    };
    result[@enumToInt(Feature.power8_vector)] = .{
        .llvm_name = "power8-vector",
        .description = "Enable POWER8 vector instructions",
        .dependencies = featureSet(&[_]Feature{
            .power8_altivec,
            .vsx,
        }),
    };
    result[@enumToInt(Feature.power9_altivec)] = .{
        .llvm_name = "power9-altivec",
        .description = "Enable POWER9 Altivec instructions",
        .dependencies = featureSet(&[_]Feature{
            .isa_v30_instructions,
            .power8_altivec,
        }),
    };
    result[@enumToInt(Feature.power9_vector)] = .{
        .llvm_name = "power9-vector",
        .description = "Enable POWER9 vector instructions",
        .dependencies = featureSet(&[_]Feature{
            .isa_v30_instructions,
            .power8_vector,
            .power9_altivec,
        }),
    };
    result[@enumToInt(Feature.ppc_postra_sched)] = .{
        .llvm_name = "ppc-postra-sched",
        .description = "Use PowerPC post-RA scheduling strategy",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ppc_prera_sched)] = .{
        .llvm_name = "ppc-prera-sched",
        .description = "Use PowerPC pre-RA scheduling strategy",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ppc4xx)] = .{
        .llvm_name = "ppc4xx",
        .description = "Enable PPC 4xx instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ppc6xx)] = .{
        .llvm_name = "ppc6xx",
        .description = "Enable PPC 6xx instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.qpx)] = .{
        .llvm_name = "qpx",
        .description = "Enable QPX instructions",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.recipprec)] = .{
        .llvm_name = "recipprec",
        .description = "Assume higher precision reciprocal estimates",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.secure_plt)] = .{
        .llvm_name = "secure-plt",
        .description = "Enable secure plt mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_popcntd)] = .{
        .llvm_name = "slow-popcntd",
        .description = "Has slow popcnt[dw] instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.spe)] = .{
        .llvm_name = "spe",
        .description = "Enable SPE instructions",
        .dependencies = featureSet(&[_]Feature{
            .hard_float,
        }),
    };
    result[@enumToInt(Feature.stfiwx)] = .{
        .llvm_name = "stfiwx",
        .description = "Enable the stfiwx instruction",
        .dependencies = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    result[@enumToInt(Feature.two_const_nr)] = .{
        .llvm_name = "two-const-nr",
        .description = "Requires two constant Newton-Raphson computation",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vectors_use_two_units)] = .{
        .llvm_name = "vectors-use-two-units",
        .description = "Vectors use two units",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vsx)] = .{
        .llvm_name = "vsx",
        .description = "Enable VSX instructions",
        .dependencies = featureSet(&[_]Feature{
            .altivec,
        }),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const @"ppc440" = CpuModel{
        .name = "ppc440",
        .llvm_name = "440",
        .features = featureSet(&[_]Feature{
            .booke,
            .fres,
            .frsqrte,
            .icbt,
            .isel,
            .msync,
        }),
    };
    pub const @"ppc450" = CpuModel{
        .name = "ppc450",
        .llvm_name = "450",
        .features = featureSet(&[_]Feature{
            .booke,
            .fres,
            .frsqrte,
            .icbt,
            .isel,
            .msync,
        }),
    };
    pub const @"ppc601" = CpuModel{
        .name = "ppc601",
        .llvm_name = "601",
        .features = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    pub const @"ppc602" = CpuModel{
        .name = "ppc602",
        .llvm_name = "602",
        .features = featureSet(&[_]Feature{
            .fpu,
        }),
    };
    pub const @"ppc603" = CpuModel{
        .name = "ppc603",
        .llvm_name = "603",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc603e" = CpuModel{
        .name = "ppc603e",
        .llvm_name = "603e",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc603ev" = CpuModel{
        .name = "ppc603ev",
        .llvm_name = "603ev",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc604" = CpuModel{
        .name = "ppc604",
        .llvm_name = "604",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc604e" = CpuModel{
        .name = "ppc604e",
        .llvm_name = "604e",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc620" = CpuModel{
        .name = "ppc620",
        .llvm_name = "620",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc7400" = CpuModel{
        .name = "ppc7400",
        .llvm_name = "7400",
        .features = featureSet(&[_]Feature{
            .altivec,
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc7450" = CpuModel{
        .name = "ppc7450",
        .llvm_name = "7450",
        .features = featureSet(&[_]Feature{
            .altivec,
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc750" = CpuModel{
        .name = "ppc750",
        .llvm_name = "750",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const @"ppc970" = CpuModel{
        .name = "ppc970",
        .llvm_name = "970",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fres,
            .frsqrte,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const a2 = CpuModel{
        .name = "a2",
        .llvm_name = "a2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .booke,
            .cmpb,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .icbt,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .recipprec,
            .slow_popcntd,
            .stfiwx,
        }),
    };
    pub const a2q = CpuModel{
        .name = "a2q",
        .llvm_name = "a2q",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .booke,
            .cmpb,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .icbt,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .qpx,
            .recipprec,
            .slow_popcntd,
            .stfiwx,
        }),
    };
    pub const e500 = CpuModel{
        .name = "e500",
        .llvm_name = "e500",
        .features = featureSet(&[_]Feature{
            .booke,
            .icbt,
            .isel,
            .spe,
        }),
    };
    pub const e500mc = CpuModel{
        .name = "e500mc",
        .llvm_name = "e500mc",
        .features = featureSet(&[_]Feature{
            .booke,
            .icbt,
            .isel,
            .stfiwx,
        }),
    };
    pub const e5500 = CpuModel{
        .name = "e5500",
        .llvm_name = "e5500",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .booke,
            .icbt,
            .isel,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const future = CpuModel{
        .name = "future",
        .llvm_name = "future",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .allow_unaligned_fp_access,
            .altivec,
            .bpermd,
            .cmpb,
            .crypto,
            .direct_move,
            .extdiv,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .htm,
            .icbt,
            .isa_v30_instructions,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .partword_atomics,
            .popcntd,
            .power8_altivec,
            .power8_vector,
            .power9_altivec,
            .power9_vector,
            .recipprec,
            .stfiwx,
            .two_const_nr,
            .vsx,
        }),
    };
    pub const g3 = CpuModel{
        .name = "g3",
        .llvm_name = "g3",
        .features = featureSet(&[_]Feature{
            .fres,
            .frsqrte,
        }),
    };
    pub const g4 = CpuModel{
        .name = "g4",
        .llvm_name = "g4",
        .features = featureSet(&[_]Feature{
            .altivec,
            .fres,
            .frsqrte,
        }),
    };
    pub const @"g4+" = CpuModel{
        .name = "g4+",
        .llvm_name = "g4+",
        .features = featureSet(&[_]Feature{
            .altivec,
            .fres,
            .frsqrte,
        }),
    };
    pub const g5 = CpuModel{
        .name = "g5",
        .llvm_name = "g5",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fres,
            .frsqrte,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .hard_float,
        }),
    };
    pub const ppc = CpuModel{
        .name = "ppc",
        .llvm_name = "ppc",
        .features = featureSet(&[_]Feature{
            .hard_float,
        }),
    };
    pub const ppc32 = CpuModel{
        .name = "ppc32",
        .llvm_name = "ppc32",
        .features = featureSet(&[_]Feature{
            .hard_float,
        }),
    };
    pub const ppc64 = CpuModel{
        .name = "ppc64",
        .llvm_name = "ppc64",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fres,
            .frsqrte,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const ppc64le = CpuModel{
        .name = "ppc64le",
        .llvm_name = "ppc64le",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .allow_unaligned_fp_access,
            .altivec,
            .bpermd,
            .cmpb,
            .crypto,
            .direct_move,
            .extdiv,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .htm,
            .icbt,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .partword_atomics,
            .popcntd,
            .power8_altivec,
            .power8_vector,
            .recipprec,
            .stfiwx,
            .two_const_nr,
            .vsx,
        }),
    };
    pub const pwr3 = CpuModel{
        .name = "pwr3",
        .llvm_name = "pwr3",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fres,
            .frsqrte,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const pwr4 = CpuModel{
        .name = "pwr4",
        .llvm_name = "pwr4",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fres,
            .frsqrte,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const pwr5 = CpuModel{
        .name = "pwr5",
        .llvm_name = "pwr5",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const pwr5x = CpuModel{
        .name = "pwr5x",
        .llvm_name = "pwr5x",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .mfocrf,
            .stfiwx,
        }),
    };
    pub const pwr6 = CpuModel{
        .name = "pwr6",
        .llvm_name = "pwr6",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .cmpb,
            .fcpsgn,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .lfiwax,
            .mfocrf,
            .recipprec,
            .stfiwx,
        }),
    };
    pub const pwr6x = CpuModel{
        .name = "pwr6x",
        .llvm_name = "pwr6x",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .altivec,
            .cmpb,
            .fcpsgn,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .lfiwax,
            .mfocrf,
            .recipprec,
            .stfiwx,
        }),
    };
    pub const pwr7 = CpuModel{
        .name = "pwr7",
        .llvm_name = "pwr7",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .allow_unaligned_fp_access,
            .altivec,
            .bpermd,
            .cmpb,
            .extdiv,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .popcntd,
            .recipprec,
            .stfiwx,
            .two_const_nr,
            .vsx,
        }),
    };
    pub const pwr8 = CpuModel{
        .name = "pwr8",
        .llvm_name = "pwr8",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .allow_unaligned_fp_access,
            .altivec,
            .bpermd,
            .cmpb,
            .crypto,
            .direct_move,
            .extdiv,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .htm,
            .icbt,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .partword_atomics,
            .popcntd,
            .power8_altivec,
            .power8_vector,
            .recipprec,
            .stfiwx,
            .two_const_nr,
            .vsx,
        }),
    };
    pub const pwr9 = CpuModel{
        .name = "pwr9",
        .llvm_name = "pwr9",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .allow_unaligned_fp_access,
            .altivec,
            .bpermd,
            .cmpb,
            .crypto,
            .direct_move,
            .extdiv,
            .fcpsgn,
            .fpcvt,
            .fprnd,
            .fre,
            .fres,
            .frsqrte,
            .frsqrtes,
            .fsqrt,
            .htm,
            .icbt,
            .isa_v30_instructions,
            .isel,
            .ldbrx,
            .lfiwax,
            .mfocrf,
            .partword_atomics,
            .popcntd,
            .power8_altivec,
            .power8_vector,
            .power9_altivec,
            .power9_vector,
            .ppc_postra_sched,
            .ppc_prera_sched,
            .recipprec,
            .stfiwx,
            .two_const_nr,
            .vectors_use_two_units,
            .vsx,
        }),
    };
};
