//! Thus file implements x86/x86_64 CPU detection compatible with LLVM/Clang
//! (i.e. multiversioned functions with attribute `target` or `target_clones`) which
//! itself is compatible with libgcc multiversioning.

const builtin = @import("builtin");
const std = @import("std");
const x86 = std.zig.system.x86;

const common = @import("common.zig");

const Target = std.Target;

comptime {
    const linkage: std.builtin.GlobalLinkage = common.linkage;
    const visibility: std.builtin.SymbolVisibility = if (linkage != .internal) .hidden else .default;

    @export(&cpu, .{ .name = "__cpu_model", .linkage = linkage, .visibility = visibility });
    @export(&cpu_extra_features, .{ .name = "__cpu_features2", .linkage = linkage, .visibility = visibility });
    @export(&init, .{ .name = "__cpu_indicator_init", .linkage = linkage, .visibility = visibility });
}

var cpu: Model = .{};
var cpu_extra_features: [feature_set_size - 1]u32 = [_]u32{0} ** (feature_set_size - 1);

fn init() callconv(.C) c_int {
    if (@atomicLoad(Vendor, &cpu.vendor, .acquire) != .unknown) {
        @branchHint(.likely);
        return 0;
    }

    const detected_features = blk: {
        var detected = Target.Cpu.Feature.Set.empty;
        x86.detectNativeFeatures(&detected, builtin.os.tag);
        break :blk detected;
    };
    const detected = x86.detectNativeProcessor(builtin.cpu.arch, detected_features);

    const feature_set = blk: {
        var features = std.mem.zeroes(FeatureSet);
        inline for (@typeInfo(Target.x86.Feature).@"enum".fields) |f| {
            const index: Target.Cpu.Feature.Set.Index = f.value;
            if (comptime !@hasField(Feature, f.name)) continue;
            if (detected_features.isEnabled(index)) setFeature(&features, @field(Feature, f.name));
        }

        const isDetected = struct {
            fn isDetected(set: Target.Cpu.Feature.Set, feats: []const Target.x86.Feature) bool {
                for (feats) |f| {
                    if (!set.isEnabled(@intFromEnum(f))) return false;
                }
                return true;
            }
        }.isDetected;

        // Compared to upstream LLVM,
        //  - FEATURE_LM -> @"64bit"
        if (isDetected(detected_features, &.{ .@"64bit", .sse2 })) {
            setFeature(&features, .x86_64);

            // Compared to upstream LLVM,
            //  - FEATURE_CMPXCHG16B -> cx16
            //  - FEATURE_LAHF_LM -> sahf
            if (isDetected(detected_features, &.{ .cx16, .popcnt, .sahf, .sse4_2 })) {
                setFeature(&features, .x86_64_v2);

                if (isDetected(detected_features, &.{ .avx2, .bmi, .bmi2, .f16c, .fma, .lzcnt, .movbe })) {
                    setFeature(&features, .x86_64_v3);

                    if (isDetected(detected_features, &.{ .avx512bw, .avx512cd, .avx512dq, .avx512vl })) {
                        setFeature(&features, .x86_64_v4);
                    }
                }
            }
        }

        break :blk features;
    };

    cpu_extra_features = feature_set[1..].*;
    cpu.features = feature_set[0..1].*;
    cpu.subtype = detected.subtype;
    cpu.type = detected.type;
    @atomicStore(Vendor, &cpu.vendor, detected.vendor, .release);

    return 0;
}

const Model = extern struct {
    vendor: Vendor = .unknown,
    type: Type = .unknown,
    subtype: Subtype = .unknown,
    features: [1]u32 = .{0},
};

const FeatureSet = [feature_set_size]u32;
comptime {
    for (@typeInfo(Feature).@"enum".fields) |f| {
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

const Vendor = x86.enums.Vendor;
const Type = x86.enums.Type;
const Subtype = x86.enums.Subtype;
const Feature = x86.enums.Feature;

const feature_set_size = blk: {
    var max_index: comptime_int = 0;
    for (@typeInfo(Feature).@"enum".fields) |f| {
        if (f.value > max_index) max_index = f.value;
    }
    break :blk (max_index + 32) / 32;
};
