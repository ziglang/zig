const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const SparcFeature = enum {
    Detectroundchange,
    HardQuadFloat,
    Leon,
    NoFmuls,
    NoFsmuld,
    Leonpwrpsr,
    SoftFloat,
    SoftMulDiv,
    DeprecatedV8,
    V9,
    Vis,
    Vis2,
    Vis3,
    Fixallfdivsqrt,
    Insertnopload,
    Hasleoncasa,
    Leoncyclecounter,
    Hasumacsmac,
    Popc,

    pub fn getInfo(self: @This()) FeatureInfo {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Detectroundchange, "detectroundchange", "LEON3 erratum detection: Detects any rounding mode change request: use only the round-to-nearest rounding mode", "detectroundchange"),
        FeatureInfo(@This()).create(.HardQuadFloat, "hard-quad-float", "Enable quad-word floating point instructions", "hard-quad-float"),
        FeatureInfo(@This()).create(.Leon, "leon", "Enable LEON extensions", "leon"),
        FeatureInfo(@This()).create(.NoFmuls, "no-fmuls", "Disable the fmuls instruction.", "no-fmuls"),
        FeatureInfo(@This()).create(.NoFsmuld, "no-fsmuld", "Disable the fsmuld instruction.", "no-fsmuld"),
        FeatureInfo(@This()).create(.Leonpwrpsr, "leonpwrpsr", "Enable the PWRPSR instruction", "leonpwrpsr"),
        FeatureInfo(@This()).create(.SoftFloat, "soft-float", "Use software emulation for floating point", "soft-float"),
        FeatureInfo(@This()).create(.SoftMulDiv, "soft-mul-div", "Use software emulation for integer multiply and divide", "soft-mul-div"),
        FeatureInfo(@This()).create(.DeprecatedV8, "deprecated-v8", "Enable deprecated V8 instructions in V9 mode", "deprecated-v8"),
        FeatureInfo(@This()).create(.V9, "v9", "Enable SPARC-V9 instructions", "v9"),
        FeatureInfo(@This()).create(.Vis, "vis", "Enable UltraSPARC Visual Instruction Set extensions", "vis"),
        FeatureInfo(@This()).create(.Vis2, "vis2", "Enable Visual Instruction Set extensions II", "vis2"),
        FeatureInfo(@This()).create(.Vis3, "vis3", "Enable Visual Instruction Set extensions III", "vis3"),
        FeatureInfo(@This()).create(.Fixallfdivsqrt, "fixallfdivsqrt", "LEON erratum fix: Fix FDIVS/FDIVD/FSQRTS/FSQRTD instructions with NOPs and floating-point store", "fixallfdivsqrt"),
        FeatureInfo(@This()).create(.Insertnopload, "insertnopload", "LEON3 erratum fix: Insert a NOP instruction after every single-cycle load instruction when the next instruction is another load/store instruction", "insertnopload"),
        FeatureInfo(@This()).create(.Hasleoncasa, "hasleoncasa", "Enable CASA instruction for LEON3 and LEON4 processors", "hasleoncasa"),
        FeatureInfo(@This()).create(.Leoncyclecounter, "leoncyclecounter", "Use the Leon cycle counter register", "leoncyclecounter"),
        FeatureInfo(@This()).create(.Hasumacsmac, "hasumacsmac", "Enable UMAC and SMAC for LEON3 and LEON4 processors", "hasumacsmac"),
        FeatureInfo(@This()).create(.Popc, "popc", "Use the popc (population count) instruction", "popc"),
    };
};
