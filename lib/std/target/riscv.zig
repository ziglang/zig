const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    @"64bit",
    a,
    c,
    d,
    e,
    f,
    m,
    relax,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Cpu.Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.@"64bit")] = .{
        .index = @enumToInt(Feature.@"64bit"),
        .name = @tagName(Feature.@"64bit"),
        .llvm_name = "64bit",
        .description = "Implements RV64",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a)] = .{
        .index = @enumToInt(Feature.a),
        .name = @tagName(Feature.a),
        .llvm_name = "a",
        .description = "'A' (Atomic Instructions)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.c)] = .{
        .index = @enumToInt(Feature.c),
        .name = @tagName(Feature.c),
        .llvm_name = "c",
        .description = "'C' (Compressed Instructions)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.d)] = .{
        .index = @enumToInt(Feature.d),
        .name = @tagName(Feature.d),
        .llvm_name = "d",
        .description = "'D' (Double-Precision Floating-Point)",
        .dependencies = featureSet(&[_]Feature{
            .f,
        }),
    };
    result[@enumToInt(Feature.e)] = .{
        .index = @enumToInt(Feature.e),
        .name = @tagName(Feature.e),
        .llvm_name = "e",
        .description = "Implements RV32E (provides 16 rather than 32 GPRs)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.f)] = .{
        .index = @enumToInt(Feature.f),
        .name = @tagName(Feature.f),
        .llvm_name = "f",
        .description = "'F' (Single-Precision Floating-Point)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.m)] = .{
        .index = @enumToInt(Feature.m),
        .name = @tagName(Feature.m),
        .llvm_name = "m",
        .description = "'M' (Integer Multiplication and Division)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.relax)] = .{
        .index = @enumToInt(Feature.relax),
        .name = @tagName(Feature.relax),
        .llvm_name = "relax",
        .description = "Enable Linker relaxation.",
        .dependencies = 0,
    };
    break :blk result;
};

pub const cpu = struct {
    pub const generic_rv32 = Cpu{
        .name = "generic_rv32",
        .llvm_name = "generic-rv32",
        .features = 0,
    };
    pub const generic_rv64 = Cpu{
        .name = "generic_rv64",
        .llvm_name = "generic-rv64",
        .features = featureSet(&[_]Feature{
            .@"64bit",
        }),
    };
};

/// All riscv CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.generic_rv32,
    &cpu.generic_rv64,
};
