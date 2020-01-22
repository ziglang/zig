const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    alu32,
    dummy,
    dwarfris,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= Cpu.Feature.Set.needed_bit_count);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.alu32)] = .{
        .llvm_name = "alu32",
        .description = "Enable ALU32 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dummy)] = .{
        .llvm_name = "dummy",
        .description = "unused feature",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dwarfris)] = .{
        .llvm_name = "dwarfris",
        .description = "Disable MCAsmInfo DwarfUsesRelocationsAcrossSections",
        .dependencies = featureSet(&[_]Feature{}),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{}),
    };
    pub const probe = Cpu{
        .name = "probe",
        .llvm_name = "probe",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v1 = Cpu{
        .name = "v1",
        .llvm_name = "v1",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v2 = Cpu{
        .name = "v2",
        .llvm_name = "v2",
        .features = featureSet(&[_]Feature{}),
    };
    pub const v3 = Cpu{
        .name = "v3",
        .llvm_name = "v3",
        .features = featureSet(&[_]Feature{}),
    };
};

/// All bpf CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.generic,
    &cpu.probe,
    &cpu.v1,
    &cpu.v2,
    &cpu.v3,
};
