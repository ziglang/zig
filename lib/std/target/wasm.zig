const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    atomics,
    bulk_memory,
    exception_handling,
    multivalue,
    mutable_globals,
    nontrapping_fptoint,
    sign_ext,
    simd128,
    tail_call,
    unimplemented_simd128,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Cpu.Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.atomics)] = .{
        .index = @enumToInt(Feature.atomics),
        .name = @tagName(Feature.atomics),
        .llvm_name = "atomics",
        .description = "Enable Atomics",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.bulk_memory)] = .{
        .index = @enumToInt(Feature.bulk_memory),
        .name = @tagName(Feature.bulk_memory),
        .llvm_name = "bulk-memory",
        .description = "Enable bulk memory operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.exception_handling)] = .{
        .index = @enumToInt(Feature.exception_handling),
        .name = @tagName(Feature.exception_handling),
        .llvm_name = "exception-handling",
        .description = "Enable Wasm exception handling",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.multivalue)] = .{
        .index = @enumToInt(Feature.multivalue),
        .name = @tagName(Feature.multivalue),
        .llvm_name = "multivalue",
        .description = "Enable multivalue blocks, instructions, and functions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mutable_globals)] = .{
        .index = @enumToInt(Feature.mutable_globals),
        .name = @tagName(Feature.mutable_globals),
        .llvm_name = "mutable-globals",
        .description = "Enable mutable globals",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.nontrapping_fptoint)] = .{
        .index = @enumToInt(Feature.nontrapping_fptoint),
        .name = @tagName(Feature.nontrapping_fptoint),
        .llvm_name = "nontrapping-fptoint",
        .description = "Enable non-trapping float-to-int conversion operators",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sign_ext)] = .{
        .index = @enumToInt(Feature.sign_ext),
        .name = @tagName(Feature.sign_ext),
        .llvm_name = "sign-ext",
        .description = "Enable sign extension operators",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.simd128)] = .{
        .index = @enumToInt(Feature.simd128),
        .name = @tagName(Feature.simd128),
        .llvm_name = "simd128",
        .description = "Enable 128-bit SIMD",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tail_call)] = .{
        .index = @enumToInt(Feature.tail_call),
        .name = @tagName(Feature.tail_call),
        .llvm_name = "tail-call",
        .description = "Enable tail call instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.unimplemented_simd128)] = .{
        .index = @enumToInt(Feature.unimplemented_simd128),
        .name = @tagName(Feature.unimplemented_simd128),
        .llvm_name = "unimplemented-simd128",
        .description = "Enable 128-bit SIMD not yet implemented in engines",
        .dependencies = featureSet(&[_]Feature{
            .simd128,
        }),
    };
    break :blk result;
};

pub const cpu = struct {
    pub const bleeding_edge = Cpu{
        .name = "bleeding_edge",
        .llvm_name = "bleeding-edge",
        .features = featureSet(&[_]Feature{
            .atomics,
            .mutable_globals,
            .nontrapping_fptoint,
            .sign_ext,
            .simd128,
        }),
    };
    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = 0,
    };
    pub const mvp = Cpu{
        .name = "mvp",
        .llvm_name = "mvp",
        .features = 0,
    };
};

/// All wasm CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.bleeding_edge,
    &cpu.generic,
    &cpu.mvp,
};
