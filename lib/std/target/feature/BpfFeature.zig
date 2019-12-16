const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const BpfFeature = enum {
    Alu32,
    Dummy,
    Dwarfris,

    pub fn getInfo(self: @This()) FeatureInfo {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Alu32, "alu32", "Enable ALU32 instructions", "alu32"),
        FeatureInfo(@This()).create(.Dummy, "dummy", "unused feature", "dummy"),
        FeatureInfo(@This()).create(.Dwarfris, "dwarfris", "Disable MCAsmInfo DwarfUsesRelocationsAcrossSections", "dwarfris"),
    };
};
