const builtin = @import("builtin");
const std = @import("std");

pub fn detectNativeCpuAndFeatures(
    arch: std.Target.Cpu.Arch,
    os: std.Target.Os,
    query: std.Target.Query,
) ?std.Target.Cpu {
    _ = os;
    _ = query;

    // Clearly this code could do better in the future by actually querying specific CPU features
    // with the cpucfg instruction like on x86. But with the small number of well-known LoongArch
    // models that exist at the moment, simply checking the PRID is plenty.
    var cpu: std.Target.Cpu = .{
        .arch = arch,
        .model = switch (cpucfg(0) & 0xf000) {
            else => return null,
            0xc000 => &std.Target.loongarch.cpu.la464,
            0xd000 => &std.Target.loongarch.cpu.la664,
        },
        .features = .empty,
    };

    cpu.features.addFeatureSet(cpu.model.features);
    cpu.features.populateDependencies(cpu.arch.allFeaturesList());

    return cpu;
}

/// This is a workaround for the C backend until zig has the ability to put
/// C code in inline assembly.
extern fn zig_loongarch_cpucfg(word: u32, result: *u32) callconv(.c) void;

fn cpucfg(word: u32) u32 {
    var result: u32 = undefined;

    if (builtin.zig_backend == .stage2_c) {
        zig_loongarch_cpucfg(word, &result);
    } else {
        asm ("cpucfg %[result], %[word]"
            : [result] "=r" (result),
            : [word] "r" (word),
        );
    }

    return result;
}
