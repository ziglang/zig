const std = @import("std");

const feature = @import("feature.zig");
const Arch = std.Target.Arch;

pub const AArch64Cpu = @import("cpu/AArch64Cpu.zig").AArch64Cpu;
pub const AmdGpuCpu = @import("cpu/AmdGpuCpu.zig").AmdGpuCpu;
pub const ArmCpu = @import("cpu/ArmCpu.zig").ArmCpu;
pub const AvrCpu = @import("cpu/AvrCpu.zig").AvrCpu;
pub const BpfCpu = @import("cpu/BpfCpu.zig").BpfCpu;
pub const HexagonCpu = @import("cpu/HexagonCpu.zig").HexagonCpu;
pub const MipsCpu = @import("cpu/MipsCpu.zig").MipsCpu;
pub const Msp430Cpu = @import("cpu/Msp430Cpu.zig").Msp430Cpu;
pub const NvptxCpu = @import("cpu/NvptxCpu.zig").NvptxCpu;
pub const PowerPcCpu = @import("cpu/PowerPcCpu.zig").PowerPcCpu;
pub const RiscVCpu = @import("cpu/RiscVCpu.zig").RiscVCpu;
pub const SparcCpu = @import("cpu/SparcCpu.zig").SparcCpu;
pub const SystemZCpu = @import("cpu/SystemZCpu.zig").SystemZCpu;
pub const WebAssemblyCpu = @import("cpu/WebAssemblyCpu.zig").WebAssemblyCpu;
pub const X86Cpu = @import("cpu/X86Cpu.zig").X86Cpu;

pub const EmptyCpu = @import("cpu/empty.zig").EmptyCpu;

pub fn ArchCpu(comptime arch: @TagType(Arch)) type {
    return switch (arch) {
        .arm, .armeb, .thumb, .thumbeb => ArmCpu,
        .aarch64, .aarch64_be, .aarch64_32 => AArch64Cpu,
        .avr => AvrCpu,
        .bpfel, .bpfeb => BpfCpu,
        .hexagon => HexagonCpu,
        .mips, .mipsel, .mips64, .mips64el => MipsCpu,
        .msp430 => Msp430Cpu,
        .powerpc, .powerpc64, .powerpc64le => PowerPcCpu,
        .amdgcn => AmdGpuCpu,
        .riscv32, .riscv64 => RiscVCpu,
        .sparc, .sparcv9, .sparcel => SparcCpu,
        .s390x => SystemZCpu,
        .i386, .x86_64 => X86Cpu,
        .nvptx, .nvptx64 => NvptxCpu,
        .wasm32, .wasm64 => WebAssemblyCpu,

        else => EmptyCpu,
    };
}

pub fn ArchCpuInfo(comptime arch: @TagType(Arch)) type {
    return CpuInfo(ArchCpu(arch), feature.ArchFeature(arch));
}

pub fn CpuInfo(comptime CpuType: type, comptime FeatureType: type) type {
    return struct {
        value: CpuType,
        name: []const u8,

        features: []const FeatureType,

        const Self = @This();

        pub fn create(value: CpuType, name: []const u8, features: []const FeatureType) Self {
            return Self {
                .value = value,
                .name = name,
                .features = features,
            };
        }
    };
}
