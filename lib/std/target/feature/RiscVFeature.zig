const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const RiscVFeature = enum {
    Bit64,
    E,
    RvcHints,
    Relax,
    A,
    C,
    D,
    F,
    M,

    pub fn getInfo(self: @This()) FeatureInfo {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Bit64, "64bit", "Implements RV64", "64bit"),
        FeatureInfo(@This()).create(.E, "e", "Implements RV32E (provides 16 rather than 32 GPRs)", "e"),
        FeatureInfo(@This()).create(.RvcHints, "rvc-hints", "Enable RVC Hint Instructions.", "rvc-hints"),
        FeatureInfo(@This()).create(.Relax, "relax", "Enable Linker relaxation.", "relax"),
        FeatureInfo(@This()).create(.A, "a", "'A' (Atomic Instructions)", "a"),
        FeatureInfo(@This()).create(.C, "c", "'C' (Compressed Instructions)", "c"),
        FeatureInfo(@This()).createWithSubfeatures(.D, "d", "'D' (Double-Precision Floating-Point)", "d", &[_]@This() {
            .F,
        }),
        FeatureInfo(@This()).create(.F, "f", "'F' (Single-Precision Floating-Point)", "f"),
        FeatureInfo(@This()).create(.M, "m", "'M' (Integer Multiplication and Division)", "m"),
    };
};
