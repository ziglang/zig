const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    ext,
    hwmult16,
    hwmult32,
    hwmultf5,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Cpu.Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.ext)] = .{
        .index = @enumToInt(Feature.ext),
        .name = @tagName(Feature.ext),
        .llvm_name = "ext",
        .description = "Enable MSP430-X extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.hwmult16)] = .{
        .index = @enumToInt(Feature.hwmult16),
        .name = @tagName(Feature.hwmult16),
        .llvm_name = "hwmult16",
        .description = "Enable 16-bit hardware multiplier",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.hwmult32)] = .{
        .index = @enumToInt(Feature.hwmult32),
        .name = @tagName(Feature.hwmult32),
        .llvm_name = "hwmult32",
        .description = "Enable 32-bit hardware multiplier",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.hwmultf5)] = .{
        .index = @enumToInt(Feature.hwmultf5),
        .name = @tagName(Feature.hwmultf5),
        .llvm_name = "hwmultf5",
        .description = "Enable F5 series hardware multiplier",
        .dependencies = 0,
    };
    break :blk result;
};

pub const cpu = struct {
    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = 0,
    };
    pub const msp430 = Cpu{
        .name = "msp430",
        .llvm_name = "msp430",
        .features = 0,
    };
    pub const msp430x = Cpu{
        .name = "msp430x",
        .llvm_name = "msp430x",
        .features = featureSet(&[_]Feature{
            .ext,
        }),
    };
};

/// All msp430 CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.generic,
    &cpu.msp430,
    &cpu.msp430x,
};
