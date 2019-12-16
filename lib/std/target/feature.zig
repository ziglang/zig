const builtin = @import("builtin");
const std = @import("std");
const Arch = std.Target.Arch;

pub const AArch64Feature = @import("feature/AArch64Feature.zig").AArch64Feature;
pub const AmdGpuFeature = @import("feature/AmdGpuFeature.zig").AmdGpuFeature;
pub const ArmFeature = @import("feature/ArmFeature.zig").ArmFeature;
pub const AvrFeature = @import("feature/AvrFeature.zig").AvrFeature;
pub const BpfFeature = @import("feature/BpfFeature.zig").BpfFeature;
pub const HexagonFeature = @import("feature/HexagonFeature.zig").HexagonFeature; pub const MipsFeature = @import("feature/MipsFeature.zig").MipsFeature;
pub const Msp430Feature = @import("feature/Msp430Feature.zig").Msp430Feature;
pub const NvptxFeature = @import("feature/NvptxFeature.zig").NvptxFeature;
pub const PowerPcFeature = @import("feature/PowerPcFeature.zig").PowerPcFeature;
pub const RiscVFeature = @import("feature/RiscVFeature.zig").RiscVFeature;
pub const SparcFeature = @import("feature/SparcFeature.zig").SparcFeature;
pub const SystemZFeature = @import("feature/SystemZFeature.zig").SystemZFeature;
pub const WebAssemblyFeature = @import("feature/WebAssemblyFeature.zig").WebAssemblyFeature;
pub const X86Feature = @import("feature/X86Feature.zig").X86Feature;

const EmptyFeature = @import("feature/empty.zig").EmptyFeature;

pub fn ArchFeature(comptime arch: @TagType(Arch)) type {
    return switch (arch) {
        .arm, .armeb, .thumb, .thumbeb => ArmFeature,
        .aarch64, .aarch64_be, .aarch64_32 => AArch64Feature,
        .avr => AvrFeature,
        .bpfel, .bpfeb => BpfFeature,
        .hexagon => HexagonFeature,
        .mips, .mipsel, .mips64, .mips64el => MipsFeature,
        .msp430 => Msp430Feature,
        .powerpc, .powerpc64, .powerpc64le => PowerPcFeature,
        .amdgcn => AmdGpuFeature,
        .riscv32, .riscv64 => RiscVFeature,
        .sparc, .sparcv9, .sparcel => SparcFeature,
        .s390x => SystemZFeature,
        .i386, .x86_64 => X86Feature,
        .nvptx, .nvptx64 => NvptxFeature,
        .wasm32, .wasm64 => WebAssemblyFeature,

        else => EmptyFeature,
    };
}

pub fn ArchFeatureInfo(comptime arch: @TagType(Arch)) type {
    return FeatureInfo(ArchFeature(arch));
}

pub fn FeatureInfo(comptime EnumType: type) type {
    return struct {
        value: EnumType,
        name: []const u8,

        subfeatures: []const EnumType,

        const Self = @This();

        fn create(value: EnumType, name: []const u8) Self {
            return Self {
                .value = value,
                .name = name,

                .subfeatures = &[_]EnumType{},
            };
        }

        fn createWithSubfeatures(value: EnumType, name: []const u8, subfeatures: []const EnumType) Self {
            return Self {
                .value = value,
                .name = name,

                .subfeatures = subfeatures,
            };
        }
    };
}
