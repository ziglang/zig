const builtin = @import("builtin");

const common = @import("common.zig");

comptime {
    @export(cpu, .{ .name = "__cpu_model", .linkage = common.linkage, .visibility = common.visibility });
    @export(init, .{ .name = "__cpu_indicator_init", .linkage = common.linkage, .visibility = common.visibility });
}

// Based on LLVM's compiler-rt implementation.

var cpu: Model = .{};
var cpu_extra_features: [3]u32 = [_]u32{0} ** 3;

// TODO: constructor attribute?
fn init() callconv(.C) c_int {
    return 0;
}

const Model = extern struct {
    vendor: Vendor = .unknown,
    type: Type = .unknown,
    subtype: Subtype = .unknown,
    features: [1]u32 = .{0},
};

// Same values as: https://github.com/llvm/llvm-project/blob/main/compiler-rt/lib/builtins/cpu_model.c

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
const Feature = enum(u8) {
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
    sse4_a,
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
    avx5124vnniw,
    avx5124fmaps,
    avx512vpopcntdq,
    avx512vbmi2,
    gfni,
    vpclmulqdq,
    avx512vnni,
    avx512bitalg,
    avx512bf16,
    avx512vp2intersect,

    cmpxchg16b = 46,
    f16c = 49,
    lahf_lm = 54,
    lm,
    wp,
    lzcnt,
    movbe,

    x86_64_baseline = 95,
    x86_64_v2,
    x86_64_v3,
    x86_64_v4,
};
