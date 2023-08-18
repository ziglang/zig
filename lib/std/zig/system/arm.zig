const std = @import("std");
const Target = std.Target;

pub const CoreInfo = struct {
    architecture: u8 = 0,
    implementer: u8 = 0,
    variant: u8 = 0,
    part: u16 = 0,
};

pub const cpu_models = struct {
    // Shorthands to simplify the tables below.
    const A32 = Target.arm.cpu;
    const A64 = Target.aarch64.cpu;

    const E = struct {
        part: u16,
        variant: ?u8 = null, // null if matches any variant
        m32: ?*const Target.Cpu.Model = null,
        m64: ?*const Target.Cpu.Model = null,
    };

    // implementer = 0x41
    const ARM = [_]E{
        E{ .part = 0x926, .m32 = &A32.arm926ej_s, .m64 = null },
        E{ .part = 0xb02, .m32 = &A32.mpcore, .m64 = null },
        E{ .part = 0xb36, .m32 = &A32.arm1136j_s, .m64 = null },
        E{ .part = 0xb56, .m32 = &A32.arm1156t2_s, .m64 = null },
        E{ .part = 0xb76, .m32 = &A32.arm1176jz_s, .m64 = null },
        E{ .part = 0xc05, .m32 = &A32.cortex_a5, .m64 = null },
        E{ .part = 0xc07, .m32 = &A32.cortex_a7, .m64 = null },
        E{ .part = 0xc08, .m32 = &A32.cortex_a8, .m64 = null },
        E{ .part = 0xc09, .m32 = &A32.cortex_a9, .m64 = null },
        E{ .part = 0xc0d, .m32 = &A32.cortex_a17, .m64 = null },
        E{ .part = 0xc0f, .m32 = &A32.cortex_a15, .m64 = null },
        E{ .part = 0xc0e, .m32 = &A32.cortex_a17, .m64 = null },
        E{ .part = 0xc14, .m32 = &A32.cortex_r4, .m64 = null },
        E{ .part = 0xc15, .m32 = &A32.cortex_r5, .m64 = null },
        E{ .part = 0xc17, .m32 = &A32.cortex_r7, .m64 = null },
        E{ .part = 0xc18, .m32 = &A32.cortex_r8, .m64 = null },
        E{ .part = 0xc20, .m32 = &A32.cortex_m0, .m64 = null },
        E{ .part = 0xc21, .m32 = &A32.cortex_m1, .m64 = null },
        E{ .part = 0xc23, .m32 = &A32.cortex_m3, .m64 = null },
        E{ .part = 0xc24, .m32 = &A32.cortex_m4, .m64 = null },
        E{ .part = 0xc27, .m32 = &A32.cortex_m7, .m64 = null },
        E{ .part = 0xc60, .m32 = &A32.cortex_m0plus, .m64 = null },
        E{ .part = 0xd01, .m32 = &A32.cortex_a32, .m64 = null },
        E{ .part = 0xd03, .m32 = &A32.cortex_a53, .m64 = &A64.cortex_a53 },
        E{ .part = 0xd04, .m32 = &A32.cortex_a35, .m64 = &A64.cortex_a35 },
        E{ .part = 0xd05, .m32 = &A32.cortex_a55, .m64 = &A64.cortex_a55 },
        E{ .part = 0xd07, .m32 = &A32.cortex_a57, .m64 = &A64.cortex_a57 },
        E{ .part = 0xd08, .m32 = &A32.cortex_a72, .m64 = &A64.cortex_a72 },
        E{ .part = 0xd09, .m32 = &A32.cortex_a73, .m64 = &A64.cortex_a73 },
        E{ .part = 0xd0a, .m32 = &A32.cortex_a75, .m64 = &A64.cortex_a75 },
        E{ .part = 0xd0b, .m32 = &A32.cortex_a76, .m64 = &A64.cortex_a76 },
        E{ .part = 0xd0c, .m32 = &A32.neoverse_n1, .m64 = &A64.neoverse_n1 },
        E{ .part = 0xd0d, .m32 = &A32.cortex_a77, .m64 = &A64.cortex_a77 },
        E{ .part = 0xd13, .m32 = &A32.cortex_r52, .m64 = null },
        E{ .part = 0xd20, .m32 = &A32.cortex_m23, .m64 = null },
        E{ .part = 0xd21, .m32 = &A32.cortex_m33, .m64 = null },
        E{ .part = 0xd41, .m32 = &A32.cortex_a78, .m64 = &A64.cortex_a78 },
        E{ .part = 0xd4b, .m32 = &A32.cortex_a78c, .m64 = &A64.cortex_a78c },
        E{ .part = 0xd4c, .m32 = &A32.cortex_x1c, .m64 = &A64.cortex_x1c },
        E{ .part = 0xd44, .m32 = &A32.cortex_x1, .m64 = &A64.cortex_x1 },
        E{ .part = 0xd02, .m64 = &A64.cortex_a34 },
        E{ .part = 0xd06, .m64 = &A64.cortex_a65 },
        E{ .part = 0xd43, .m64 = &A64.cortex_a65ae },
    };
    // implementer = 0x42
    const Broadcom = [_]E{
        E{ .part = 0x516, .m64 = &A64.thunderx2t99 },
    };
    // implementer = 0x43
    const Cavium = [_]E{
        E{ .part = 0x0a0, .m64 = &A64.thunderx },
        E{ .part = 0x0a2, .m64 = &A64.thunderxt81 },
        E{ .part = 0x0a3, .m64 = &A64.thunderxt83 },
        E{ .part = 0x0a1, .m64 = &A64.thunderxt88 },
        E{ .part = 0x0af, .m64 = &A64.thunderx2t99 },
    };
    // implementer = 0x46
    const Fujitsu = [_]E{
        E{ .part = 0x001, .m64 = &A64.a64fx },
    };
    // implementer = 0x48
    const HiSilicon = [_]E{
        E{ .part = 0xd01, .m64 = &A64.tsv110 },
    };
    // implementer = 0x4e
    const Nvidia = [_]E{
        E{ .part = 0x004, .m64 = &A64.carmel },
    };
    // implementer = 0x50
    const Ampere = [_]E{
        E{ .part = 0x000, .variant = 3, .m64 = &A64.emag },
        E{ .part = 0x000, .m64 = &A64.xgene1 },
    };
    // implementer = 0x51
    const Qualcomm = [_]E{
        E{ .part = 0x06f, .m32 = &A32.krait },
        E{ .part = 0x201, .m64 = &A64.kryo, .m32 = &A64.kryo },
        E{ .part = 0x205, .m64 = &A64.kryo, .m32 = &A64.kryo },
        E{ .part = 0x211, .m64 = &A64.kryo, .m32 = &A64.kryo },
        E{ .part = 0x800, .m64 = &A64.cortex_a73, .m32 = &A64.cortex_a73 },
        E{ .part = 0x801, .m64 = &A64.cortex_a73, .m32 = &A64.cortex_a73 },
        E{ .part = 0x802, .m64 = &A64.cortex_a75, .m32 = &A64.cortex_a75 },
        E{ .part = 0x803, .m64 = &A64.cortex_a75, .m32 = &A64.cortex_a75 },
        E{ .part = 0x804, .m64 = &A64.cortex_a76, .m32 = &A64.cortex_a76 },
        E{ .part = 0x805, .m64 = &A64.cortex_a76, .m32 = &A64.cortex_a76 },
        E{ .part = 0xc00, .m64 = &A64.falkor },
        E{ .part = 0xc01, .m64 = &A64.saphira },
    };

    pub fn isKnown(core: CoreInfo, is_64bit: bool) ?*const Target.Cpu.Model {
        const models = switch (core.implementer) {
            0x41 => &ARM,
            0x42 => &Broadcom,
            0x43 => &Cavium,
            0x46 => &Fujitsu,
            0x48 => &HiSilicon,
            0x50 => &Ampere,
            0x51 => &Qualcomm,
            else => return null,
        };

        for (models) |model| {
            if (model.part == core.part and
                (model.variant == null or model.variant.? == core.variant))
                return if (is_64bit) model.m64 else model.m32;
        }

        return null;
    }
};

pub const aarch64 = struct {
    fn setFeature(cpu: *Target.Cpu, feature: Target.aarch64.Feature, enabled: bool) void {
        const idx = @as(Target.Cpu.Feature.Set.Index, @intFromEnum(feature));

        if (enabled) cpu.features.addFeature(idx) else cpu.features.removeFeature(idx);
    }

    inline fn bitField(input: u64, offset: u6) u4 {
        return @as(u4, @truncate(input >> offset));
    }

    /// Input array should consist of readouts from 12 system registers such that:
    /// 0  -> MIDR_EL1
    /// 1  -> ID_AA64PFR0_EL1
    /// 2  -> ID_AA64PFR1_EL1
    /// 3  -> ID_AA64DFR0_EL1
    /// 4  -> ID_AA64DFR1_EL1
    /// 5  -> ID_AA64AFR0_EL1
    /// 6  -> ID_AA64AFR1_EL1
    /// 7  -> ID_AA64ISAR0_EL1
    /// 8  -> ID_AA64ISAR1_EL1
    /// 9  -> ID_AA64MMFR0_EL1
    /// 10 -> ID_AA64MMFR1_EL1
    /// 11 -> ID_AA64MMFR2_EL1
    pub fn detectNativeCpuAndFeatures(arch: Target.Cpu.Arch, registers: [12]u64) ?Target.Cpu {
        const info = detectNativeCoreInfo(registers[0]);
        const model = cpu_models.isKnown(info, true) orelse return null;

        var cpu = Target.Cpu{
            .arch = arch,
            .model = model,
            .features = Target.Cpu.Feature.Set.empty,
        };

        detectNativeCpuFeatures(&cpu, registers[1..12]);
        addInstructionFusions(&cpu, info);

        return cpu;
    }

    /// Takes readout of MIDR_EL1 register as input.
    fn detectNativeCoreInfo(midr: u64) CoreInfo {
        var info = CoreInfo{
            .implementer = @as(u8, @truncate(midr >> 24)),
            .part = @as(u12, @truncate(midr >> 4)),
        };

        blk: {
            if (info.implementer == 0x41) {
                // ARM Ltd.
                const special_bits: u4 = @truncate(info.part >> 8);
                if (special_bits == 0x0 or special_bits == 0x7) {
                    // TODO Variant and arch encoded differently.
                    break :blk;
                }
            }

            info.variant |= @as(u8, @intCast(@as(u4, @truncate(midr >> 20)))) << 4;
            info.variant |= @as(u4, @truncate(midr));
            info.architecture = @as(u4, @truncate(midr >> 16));
        }

        return info;
    }

    /// Input array should consist of readouts from 11 system registers such that:
    /// 0  -> ID_AA64PFR0_EL1
    /// 1  -> ID_AA64PFR1_EL1
    /// 2  -> ID_AA64DFR0_EL1
    /// 3  -> ID_AA64DFR1_EL1
    /// 4  -> ID_AA64AFR0_EL1
    /// 5  -> ID_AA64AFR1_EL1
    /// 6  -> ID_AA64ISAR0_EL1
    /// 7  -> ID_AA64ISAR1_EL1
    /// 8  -> ID_AA64MMFR0_EL1
    /// 9  -> ID_AA64MMFR1_EL1
    /// 10 -> ID_AA64MMFR2_EL1
    fn detectNativeCpuFeatures(cpu: *Target.Cpu, registers: *const [11]u64) void {
        // ID_AA64PFR0_EL1
        setFeature(cpu, .dit, bitField(registers[0], 48) >= 1);
        setFeature(cpu, .am, bitField(registers[0], 44) >= 1);
        setFeature(cpu, .amvs, bitField(registers[0], 44) >= 2);
        setFeature(cpu, .mpam, bitField(registers[0], 40) >= 1); // MPAM v1.0
        setFeature(cpu, .sel2, bitField(registers[0], 36) >= 1);
        setFeature(cpu, .sve, bitField(registers[0], 32) >= 1);
        setFeature(cpu, .el3, bitField(registers[0], 12) >= 1);
        setFeature(cpu, .ras, bitField(registers[0], 28) >= 1);

        if (bitField(registers[0], 20) < 0xF) blk: {
            if (bitField(registers[0], 16) != bitField(registers[0], 20)) break :blk; // This should never occur

            setFeature(cpu, .neon, true);
            setFeature(cpu, .fp_armv8, true);
            setFeature(cpu, .fullfp16, bitField(registers[0], 20) > 0);
        }

        // ID_AA64PFR1_EL1
        setFeature(cpu, .mpam, bitField(registers[1], 16) > 0 and bitField(registers[0], 40) == 0); // MPAM v0.1
        setFeature(cpu, .mte, bitField(registers[1], 8) >= 1);
        setFeature(cpu, .ssbs, bitField(registers[1], 4) >= 1);
        setFeature(cpu, .bti, bitField(registers[1], 0) >= 1);

        // ID_AA64DFR0_EL1
        setFeature(cpu, .tracev8_4, bitField(registers[2], 40) >= 1);
        setFeature(cpu, .spe, bitField(registers[2], 32) >= 1);
        setFeature(cpu, .perfmon, bitField(registers[2], 8) >= 1 and bitField(registers[2], 8) < 0xF);

        // ID_AA64DFR1_EL1 reserved
        // ID_AA64AFR0_EL1 reserved / implementation defined
        // ID_AA64AFR1_EL1 reserved

        // ID_AA64ISAR0_EL1
        setFeature(cpu, .rand, bitField(registers[6], 60) >= 1);
        setFeature(cpu, .tlb_rmi, bitField(registers[6], 56) >= 1);
        setFeature(cpu, .flagm, bitField(registers[6], 52) >= 1);
        setFeature(cpu, .fp16fml, bitField(registers[6], 48) >= 1);
        setFeature(cpu, .dotprod, bitField(registers[6], 44) >= 1);
        setFeature(cpu, .sm4, bitField(registers[6], 40) >= 1 and bitField(registers[6], 36) >= 1);
        setFeature(cpu, .sha3, bitField(registers[6], 32) >= 1 and bitField(registers[6], 12) >= 2);
        setFeature(cpu, .rdm, bitField(registers[6], 28) >= 1);
        setFeature(cpu, .lse, bitField(registers[6], 20) >= 1);
        setFeature(cpu, .crc, bitField(registers[6], 16) >= 1);
        setFeature(cpu, .sha2, bitField(registers[6], 12) >= 1 and bitField(registers[6], 8) >= 1);
        setFeature(cpu, .aes, bitField(registers[6], 4) >= 1);

        // ID_AA64ISAR1_EL1
        setFeature(cpu, .i8mm, bitField(registers[7], 52) >= 1);
        setFeature(cpu, .bf16, bitField(registers[7], 44) >= 1);
        setFeature(cpu, .predres, bitField(registers[7], 40) >= 1);
        setFeature(cpu, .sb, bitField(registers[7], 36) >= 1);
        setFeature(cpu, .fptoint, bitField(registers[7], 32) >= 1);
        setFeature(cpu, .rcpc, bitField(registers[7], 20) >= 1);
        setFeature(cpu, .rcpc_immo, bitField(registers[7], 20) >= 2);
        setFeature(cpu, .complxnum, bitField(registers[7], 16) >= 1);
        setFeature(cpu, .jsconv, bitField(registers[7], 12) >= 1);
        setFeature(cpu, .pauth, bitField(registers[7], 8) >= 1 or bitField(registers[7], 4) >= 1);
        setFeature(cpu, .ccpp, bitField(registers[7], 0) >= 1);
        setFeature(cpu, .ccdp, bitField(registers[7], 0) >= 2);

        // ID_AA64MMFR0_EL1
        setFeature(cpu, .ecv, bitField(registers[8], 60) >= 1);
        setFeature(cpu, .fgt, bitField(registers[8], 56) >= 1);

        // ID_AA64MMFR1_EL1
        setFeature(cpu, .pan, bitField(registers[9], 20) >= 1);
        setFeature(cpu, .pan_rwv, bitField(registers[9], 20) >= 2);
        setFeature(cpu, .lor, bitField(registers[9], 16) >= 1);
        setFeature(cpu, .vh, bitField(registers[9], 8) >= 1);
        setFeature(cpu, .contextidr_el2, bitField(registers[9], 8) >= 1);

        // ID_AA64MMFR2_EL1
        setFeature(cpu, .nv, bitField(registers[10], 24) >= 1);
        setFeature(cpu, .ccidx, bitField(registers[10], 20) >= 1);
        setFeature(cpu, .uaops, bitField(registers[10], 4) >= 1);
    }

    fn addInstructionFusions(cpu: *Target.Cpu, info: CoreInfo) void {
        switch (info.implementer) {
            0x41 => switch (info.part) {
                0xd4b, 0xd4c => {
                    // According to A78C/X1C Core Software Optimization Guide, CPU fuses certain instructions.
                    setFeature(cpu, .cmp_bcc_fusion, true);
                    setFeature(cpu, .fuse_aes, true);
                },
                else => {},
            },
            else => {},
        }
    }
};
