const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const Msp430Feature = enum {
    Hwmult16,
    Hwmult32,
    Hwmultf5,
    Ext,

    pub fn getInfo(self: @This()) FeatureInfo(@This()) {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Hwmult16, "hwmult16", "Enable 16-bit hardware multiplier", "hwmult16"),
        FeatureInfo(@This()).create(.Hwmult32, "hwmult32", "Enable 32-bit hardware multiplier", "hwmult32"),
        FeatureInfo(@This()).create(.Hwmultf5, "hwmultf5", "Enable F5 series hardware multiplier", "hwmultf5"),
        FeatureInfo(@This()).create(.Ext, "ext", "Enable MSP430-X extensions", "ext"),
    };
};
