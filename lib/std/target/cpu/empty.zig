const feature = @import("std").target.feature;
const CpuInfo = @import("std").target.cpu.CpuInfo;

pub const EmptyCpu = enum {
    pub const cpu_infos = [0]CpuInfo(@This()) {};
};
