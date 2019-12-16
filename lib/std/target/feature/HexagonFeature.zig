const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const HexagonFeature = enum {
    V5,
    V55,
    V60,
    V62,
    V65,
    V66,
    Hvx,
    HvxLength64b,
    HvxLength128b,
    Hvxv60,
    Hvxv62,
    Hvxv65,
    Hvxv66,
    Zreg,
    Duplex,
    LongCalls,
    Mem_noshuf,
    Memops,
    Nvj,
    Nvs,
    NoreturnStackElim,
    Packets,
    ReservedR19,
    SmallData,

    pub fn getInfo(self: @This()) FeatureInfo {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.V5, "v5", "Enable Hexagon V5 architecture", "v5"),
        FeatureInfo(@This()).create(.V55, "v55", "Enable Hexagon V55 architecture", "v55"),
        FeatureInfo(@This()).create(.V60, "v60", "Enable Hexagon V60 architecture", "v60"),
        FeatureInfo(@This()).create(.V62, "v62", "Enable Hexagon V62 architecture", "v62"),
        FeatureInfo(@This()).create(.V65, "v65", "Enable Hexagon V65 architecture", "v65"),
        FeatureInfo(@This()).create(.V66, "v66", "Enable Hexagon V66 architecture", "v66"),
        FeatureInfo(@This()).create(.Hvx, "hvx", "Hexagon HVX instructions", "hvx"),
        FeatureInfo(@This()).createWithSubfeatures(.HvxLength64b, "hvx-length64b", "Hexagon HVX 64B instructions", "hvx-length64b", &[_]@This() {
            .Hvx,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.HvxLength128b, "hvx-length128b", "Hexagon HVX 128B instructions", "hvx-length128b", &[_]@This() {
            .Hvx,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Hvxv60, "hvxv60", "Hexagon HVX instructions", "hvxv60", &[_]@This() {
            .Hvx,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Hvxv62, "hvxv62", "Hexagon HVX instructions", "hvxv62", &[_]@This() {
            .Hvx,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Hvxv65, "hvxv65", "Hexagon HVX instructions", "hvxv65", &[_]@This() {
            .Hvx,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Hvxv66, "hvxv66", "Hexagon HVX instructions", "hvxv66", &[_]@This() {
            .Hvx,
            .Zreg,
        }),
        FeatureInfo(@This()).create(.Zreg, "zreg", "Hexagon ZReg extension instructions", "zreg"),
        FeatureInfo(@This()).create(.Duplex, "duplex", "Enable generation of duplex instruction", "duplex"),
        FeatureInfo(@This()).create(.LongCalls, "long-calls", "Use constant-extended calls", "long-calls"),
        FeatureInfo(@This()).create(.Mem_noshuf, "mem_noshuf", "Supports mem_noshuf feature", "mem_noshuf"),
        FeatureInfo(@This()).create(.Memops, "memops", "Use memop instructions", "memops"),
        FeatureInfo(@This()).createWithSubfeatures(.Nvj, "nvj", "Support for new-value jumps", "nvj", &[_]@This() {
            .Packets,
        }),
        FeatureInfo(@This()).createWithSubfeatures(.Nvs, "nvs", "Support for new-value stores", "nvs", &[_]@This() {
            .Packets,
        }),
        FeatureInfo(@This()).create(.NoreturnStackElim, "noreturn-stack-elim", "Eliminate stack allocation in a noreturn function when possible", "noreturn-stack-elim"),
        FeatureInfo(@This()).create(.Packets, "packets", "Support for instruction packets", "packets"),
        FeatureInfo(@This()).create(.ReservedR19, "reserved-r19", "Reserve register R19", "reserved-r19"),
        FeatureInfo(@This()).create(.SmallData, "small-data", "Allow GP-relative addressing of global variables", "small-data"),
    };
};
