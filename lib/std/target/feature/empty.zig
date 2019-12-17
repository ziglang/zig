const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const EmptyFeature = struct {
    pub const feature_infos = [0]FeatureInfo(@This()) {};
};
