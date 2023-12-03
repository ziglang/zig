const builtin = @import("builtin");
const std = @import("std");
const x86 = std.zig.system.x86;

const common = @import("common.zig");

const Target = std.Target;

comptime {
    @export(cpu, .{ .name = "__cpu_model", .linkage = common.linkage, .visibility = common.visibility });
    @export(init, .{ .name = "__cpu_indicator_init", .linkage = common.linkage, .visibility = common.visibility });
}

// Based on LLVM's compiler-rt implementation, including matching enum values.
// (https://github.com/llvm/llvm-project/blob/0e5da2eceb89f1e947e8b9b4aa42804e4ea89acc/compiler-rt/lib/builtins/cpu_model.c)

var cpu: Model = .{};
var cpu_extra_features: [3]u32 = [_]u32{0} ** 3;

// TODO: constructor attribute?
fn init() callconv(.C) c_int {
    if (cpu.vendor != .unknown) return 0;

    const features = blk: {
        var detected = Target.Cpu.Feature.Set.empty;
        x86.detectNativeFeatures(&detected, builtin.os.tag);

        var features = std.mem.zeroes(FeatureSet);
        inline for (@typeInfo(Target.x86.Feature).Enum.fields) |f| {
            const index: Target.Cpu.Feature.Set.Index = f.value;
            if (comptime !@hasField(Feature, f.name)) continue;
            if (detected.isEnabled(index)) setFeature(&features, @field(Feature, f.name));
        }

        if (hasFeature(features, .@"64bit") and hasFeature(features, .sse2)) {
            setFeature(&features, .x86_64_baseline);

            if (hasFeature(features, .cx16) and hasFeature(features, .popcnt) and
                hasFeature(features, .sahf) and hasFeature(features, .sse4_2))
            {
                setFeature(&features, .x86_64_v2);

                if (hasFeature(features, .avx2) and hasFeature(features, .bmi) and
                    hasFeature(features, .bmi2) and hasFeature(features, .f16c) and
                    hasFeature(features, .fma) and hasFeature(features, .lzcnt) and
                    hasFeature(features, .movbe))
                {
                    setFeature(&features, .x86_64_v3);

                    if (hasFeature(features, .avx512bw) and hasFeature(features, .avx512cd) and
                        hasFeature(features, .avx512dq) and hasFeature(features, .avx512vl))
                    {
                        setFeature(&features, .x86_64_v4);
                    }
                }
            }
        }

        break :blk features;
    };
    cpu.features[0] = features[0];
    cpu_extra_features = features[1..].*;

    return 0;
}

const Model = extern struct {
    vendor: Vendor = .unknown,
    type: Type = .unknown,
    subtype: Subtype = .unknown,
    features: [1]u32 = .{0},
};

const FeatureSet = [4]u32;
comptime {
    inline for (@typeInfo(Feature).Enum.fields) |f| {
        if (f.value >= @bitSizeOf(FeatureSet))
            @compileError(@import("std").fmt.comptimePrint("Feature.{s} ({}) bitindex too large", .{ f.name, f.value }));
    }
}

fn hasFeature(set: FeatureSet, f: Feature) bool {
    const f_value = @intFromEnum(f);
    const bit = set[f_value / 32] & (@as(u32, 1) << @as(u5, @intCast(f_value % 32)));
    return bit != 0;
}
fn setFeature(set: *FeatureSet, f: Feature) void {
    const f_value = @intFromEnum(f);
    set[f_value / 32] |= (@as(u32, 1) << @as(u5, @intCast(f_value % 32)));
}

const Vendor = enum(u32) {
    unknown = 0,
    intel,
    amd,
    other,
};
const Type = enum(u32) {
    unknown = 0,
    intel_bonnell,
    intel_core2,
    intel_corei7,
    amdfam10h,
    amdfam15h,
    intel_silvermont,
    intel_knl,
    amd_btver1,
    amd_btver2,
    amdfam17h,
    intel_knm,
    intel_goldmont,
    intel_goldmont_plus,
    intel_tremont,
    amdfam19h,
    zhaoxin_fam7h,
    intel_sierraforest,
    intel_grandridge,
    intel_clearwaterforest,
};
const Subtype = enum(u32) {
    unknown = 0,
    intel_corei7_nehalem,
    intel_corei7_westmere,
    intel_corei7_sandybridge,
    amdfam10h_barcelona,
    amdfam10h_shanghai,
    amdfam10h_istanbul,
    amdfam15h_bdver1,
    amdfam15h_bdver2,
    amdfam15h_bdver3,
    amdfam15h_bdver4,
    amdfam17h_znver1,
    intel_corei7_ivybridge,
    intel_corei7_haswell,
    intel_corei7_broadwell,
    intel_corei7_skylake,
    intel_corei7_skylake_avx512,
    intel_corei7_cannonlake,
    intel_corei7_icelake_client,
    intel_corei7_icelake_server,
    amdfam17h_znver2,
    intel_corei7_cascadelake,
    intel_corei7_tigerlake,
    intel_corei7_cooperlake,
    intel_corei7_sapphirerapids,
    intel_corei7_alderlake,
    amdfam19h_znver3,
    intel_corei7_rocketlake,
    zhaoxin_fam7h_lujiazui,
    amdfam19h_znver4,
    intel_corei7_graniterapids,
    intel_corei7_graniterapids_d,
    intel_corei7_arrowlake,
    intel_corei7_arrowlake_s,
    intel_corei7_pantherlake,
};
const Feature = enum(u32) {
    cmov = 0,
    mmx,
    popcnt,
    sse,
    sse2,
    sse3,
    ssse3,
    sse4_1,
    sse4_2,
    avx,
    avx2,
    sse4a,
    fma4,
    xop,
    fma,
    avx512f,
    bmi,
    bmi2,
    aes,
    pclmul,
    avx512vl,
    avx512bw,
    avx512dq,
    avx512cd,
    avx512er,
    avx512pf,
    avx512vbmi,
    avx512ifma,
    avx5124vnniw, // TODO: detect this in std/zig/system/x86.zig
    avx5124fmaps, // TODO: detect this in std/zig/system/x86.zig
    avx512vpopcntdq,
    avx512vbmi2,
    gfni,
    vpclmulqdq,
    avx512vnni,
    avx512bitalg,
    avx512bf16,
    avx512vp2intersect,

    cx16 = 46, // NOTE: named `cmpxchg16b` in LLVM source
    f16c = 49,
    sahf = 54, // NOTE: named `lahf_lm` in LLVM source
    @"64bit", // NOTE: named `lm` in LLVM source
    wp, // NOTE: unused in LLVM source
    lzcnt,
    movbe,

    x86_64_baseline = 95,
    x86_64_v2,
    x86_64_v3,
    x86_64_v4,
};

comptime {
    // Check that every name in Feature has a corresponding name  in std.Target.x86.Feature.

    const ignored = std.ComptimeStringMap(void, .{
        // These are aggregate features so they won't have a corresponding
        // value in std.Target.x86.Feature.
        .{ "x86_64_baseline", {} },
        .{ "x86_64_v2", {} },
        .{ "x86_64_v3", {} },
        .{ "x86_64_v4", {} },

        // Unused in LLVM
        .{ "wp", {} },

        // TODO: detect in std/zig/system/x86.zig
        .{ "avx5124vnniw", {} },
        .{ "avx5124fmaps", {} },
    });

    var missing = false;
    inline for (@typeInfo(Feature).Enum.fields) |field| {
        if (ignored.has(field.name)) {
            continue;
        } else if (!@hasField(Target.x86.Feature, field.name)) {
            missing = true;
            @compileLog(field);
        }
    }
    if (missing) @compileError("missing enum values in std.Target.x86.Feature (see compile log)");
}
