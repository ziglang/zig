const std = @import("std");

pub const CoreInfo = struct {
    architecture: u8 = 0,
    implementer: u8 = 0,
    variant: u8 = 0,
    part: u16 = 0,
};

pub const cpu_models = struct {
    // Shorthands to simplify the tables below.
    const A32 = std.Target.arm.cpu;
    const A64 = std.Target.aarch64.cpu;

    const E = struct {
        part: u16,
        variant: ?u8 = null, // null if matches any variant
        m32: ?*const std.Target.Cpu.Model = null,
        m64: ?*const std.Target.Cpu.Model = null,
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
        // This is a guess based on https://www.notebookcheck.net/Qualcomm-Snapdragon-8cx-Gen-3-Processor-Benchmarks-and-Specs.652916.0.html
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

    pub fn isKnown(core: CoreInfo, is_64bit: bool) ?*const std.Target.Cpu.Model {
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
