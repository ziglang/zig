const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    @"32bit",
    @"8msecext",
    a12,
    a15,
    a17,
    a32,
    a35,
    a5,
    a53,
    a55,
    a57,
    a7,
    a72,
    a73,
    a75,
    a76,
    a8,
    a9,
    aclass,
    acquire_release,
    aes,
    armv2,
    armv2a,
    armv3,
    armv3m,
    armv4,
    armv4t,
    armv5t,
    armv5te,
    armv5tej,
    armv6,
    armv6_m,
    armv6j,
    armv6k,
    armv6kz,
    armv6s_m,
    armv6t2,
    armv7_a,
    armv7_m,
    armv7_r,
    armv7e_m,
    armv7k,
    armv7s,
    armv7ve,
    armv8_a,
    armv8_m_base,
    armv8_m_main,
    armv8_r,
    armv8_1_a,
    armv8_1_m_main,
    armv8_2_a,
    armv8_3_a,
    armv8_4_a,
    armv8_5_a,
    avoid_movs_shop,
    avoid_partial_cpsr,
    cheap_predicable_cpsr,
    crc,
    crypto,
    d32,
    db,
    dfb,
    disable_postra_scheduler,
    dont_widen_vmovs,
    dotprod,
    dsp,
    execute_only,
    expand_fp_mlx,
    exynos,
    fp_armv8,
    fp_armv8d16,
    fp_armv8d16sp,
    fp_armv8sp,
    fp16,
    fp16fml,
    fp64,
    fpao,
    fpregs,
    fpregs16,
    fpregs64,
    fullfp16,
    fuse_aes,
    fuse_literals,
    hwdiv,
    hwdiv_arm,
    iwmmxt,
    iwmmxt2,
    krait,
    kryo,
    lob,
    long_calls,
    loop_align,
    m3,
    mclass,
    mp,
    muxed_units,
    mve,
    mve_fp,
    nacl_trap,
    neon,
    neon_fpmovs,
    neonfp,
    no_branch_predictor,
    no_movt,
    no_neg_immediates,
    noarm,
    nonpipelined_vfp,
    perfmon,
    prefer_ishst,
    prefer_vmovsr,
    prof_unpr,
    r4,
    r5,
    r52,
    r7,
    ras,
    rclass,
    read_tp_hard,
    reserve_r9,
    ret_addr_stack,
    sb,
    sha2,
    slow_fp_brcc,
    slow_load_D_subreg,
    slow_odd_reg,
    slow_vdup32,
    slow_vgetlni32,
    slowfpvmlx,
    soft_float,
    splat_vfp_neon,
    strict_align,
    swift,
    thumb_mode,
    thumb2,
    trustzone,
    use_aa,
    use_misched,
    v4t,
    v5t,
    v5te,
    v6,
    v6k,
    v6m,
    v6t2,
    v7,
    v7clrex,
    v8,
    v8_1a,
    v8_1m_main,
    v8_2a,
    v8_3a,
    v8_4a,
    v8_5a,
    v8m,
    v8m_main,
    vfp2,
    vfp2d16,
    vfp2d16sp,
    vfp2sp,
    vfp3,
    vfp3d16,
    vfp3d16sp,
    vfp3sp,
    vfp4,
    vfp4d16,
    vfp4d16sp,
    vfp4sp,
    virtualization,
    vldn_align,
    vmlx_forwarding,
    vmlx_hazards,
    wide_stride_vfp,
    xscale,
    zcz,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Cpu.Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.@"32bit")] = .{
        .index = @enumToInt(Feature.@"32bit"),
        .name = @tagName(Feature.@"32bit"),
        .llvm_name = "32bit",
        .description = "Prefer 32-bit Thumb instrs",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.@"8msecext")] = .{
        .index = @enumToInt(Feature.@"8msecext"),
        .name = @tagName(Feature.@"8msecext"),
        .llvm_name = "8msecext",
        .description = "Enable support for ARMv8-M Security Extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a12)] = .{
        .index = @enumToInt(Feature.a12),
        .name = @tagName(Feature.a12),
        .llvm_name = "a12",
        .description = "Cortex-A12 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a15)] = .{
        .index = @enumToInt(Feature.a15),
        .name = @tagName(Feature.a15),
        .llvm_name = "a15",
        .description = "Cortex-A15 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a17)] = .{
        .index = @enumToInt(Feature.a17),
        .name = @tagName(Feature.a17),
        .llvm_name = "a17",
        .description = "Cortex-A17 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a32)] = .{
        .index = @enumToInt(Feature.a32),
        .name = @tagName(Feature.a32),
        .llvm_name = "a32",
        .description = "Cortex-A32 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a35)] = .{
        .index = @enumToInt(Feature.a35),
        .name = @tagName(Feature.a35),
        .llvm_name = "a35",
        .description = "Cortex-A35 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a5)] = .{
        .index = @enumToInt(Feature.a5),
        .name = @tagName(Feature.a5),
        .llvm_name = "a5",
        .description = "Cortex-A5 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a53)] = .{
        .index = @enumToInt(Feature.a53),
        .name = @tagName(Feature.a53),
        .llvm_name = "a53",
        .description = "Cortex-A53 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a55)] = .{
        .index = @enumToInt(Feature.a55),
        .name = @tagName(Feature.a55),
        .llvm_name = "a55",
        .description = "Cortex-A55 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a57)] = .{
        .index = @enumToInt(Feature.a57),
        .name = @tagName(Feature.a57),
        .llvm_name = "a57",
        .description = "Cortex-A57 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a7)] = .{
        .index = @enumToInt(Feature.a7),
        .name = @tagName(Feature.a7),
        .llvm_name = "a7",
        .description = "Cortex-A7 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a72)] = .{
        .index = @enumToInt(Feature.a72),
        .name = @tagName(Feature.a72),
        .llvm_name = "a72",
        .description = "Cortex-A72 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a73)] = .{
        .index = @enumToInt(Feature.a73),
        .name = @tagName(Feature.a73),
        .llvm_name = "a73",
        .description = "Cortex-A73 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a75)] = .{
        .index = @enumToInt(Feature.a75),
        .name = @tagName(Feature.a75),
        .llvm_name = "a75",
        .description = "Cortex-A75 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a76)] = .{
        .index = @enumToInt(Feature.a76),
        .name = @tagName(Feature.a76),
        .llvm_name = "a76",
        .description = "Cortex-A76 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a8)] = .{
        .index = @enumToInt(Feature.a8),
        .name = @tagName(Feature.a8),
        .llvm_name = "a8",
        .description = "Cortex-A8 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.a9)] = .{
        .index = @enumToInt(Feature.a9),
        .name = @tagName(Feature.a9),
        .llvm_name = "a9",
        .description = "Cortex-A9 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.aclass)] = .{
        .index = @enumToInt(Feature.aclass),
        .name = @tagName(Feature.aclass),
        .llvm_name = "aclass",
        .description = "Is application profile ('A' series)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.acquire_release)] = .{
        .index = @enumToInt(Feature.acquire_release),
        .name = @tagName(Feature.acquire_release),
        .llvm_name = "acquire-release",
        .description = "Has v8 acquire/release (lda/ldaex  etc) instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.aes)] = .{
        .index = @enumToInt(Feature.aes),
        .name = @tagName(Feature.aes),
        .llvm_name = "aes",
        .description = "Enable AES support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.armv2)] = .{
        .index = @enumToInt(Feature.armv2),
        .name = @tagName(Feature.armv2),
        .llvm_name = "armv2",
        .description = "ARMv2 architecture",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.armv2a)] = .{
        .index = @enumToInt(Feature.armv2a),
        .name = @tagName(Feature.armv2a),
        .llvm_name = "armv2a",
        .description = "ARMv2a architecture",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.armv3)] = .{
        .index = @enumToInt(Feature.armv3),
        .name = @tagName(Feature.armv3),
        .llvm_name = "armv3",
        .description = "ARMv3 architecture",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.armv3m)] = .{
        .index = @enumToInt(Feature.armv3m),
        .name = @tagName(Feature.armv3m),
        .llvm_name = "armv3m",
        .description = "ARMv3m architecture",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.armv4)] = .{
        .index = @enumToInt(Feature.armv4),
        .name = @tagName(Feature.armv4),
        .llvm_name = "armv4",
        .description = "ARMv4 architecture",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.armv4t)] = .{
        .index = @enumToInt(Feature.armv4t),
        .name = @tagName(Feature.armv4t),
        .llvm_name = "armv4t",
        .description = "ARMv4t architecture",
        .dependencies = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    result[@enumToInt(Feature.armv5t)] = .{
        .index = @enumToInt(Feature.armv5t),
        .name = @tagName(Feature.armv5t),
        .llvm_name = "armv5t",
        .description = "ARMv5t architecture",
        .dependencies = featureSet(&[_]Feature{
            .v5t,
        }),
    };
    result[@enumToInt(Feature.armv5te)] = .{
        .index = @enumToInt(Feature.armv5te),
        .name = @tagName(Feature.armv5te),
        .llvm_name = "armv5te",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    result[@enumToInt(Feature.armv5tej)] = .{
        .index = @enumToInt(Feature.armv5tej),
        .name = @tagName(Feature.armv5tej),
        .llvm_name = "armv5tej",
        .description = "ARMv5tej architecture",
        .dependencies = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    result[@enumToInt(Feature.armv6)] = .{
        .index = @enumToInt(Feature.armv6),
        .name = @tagName(Feature.armv6),
        .llvm_name = "armv6",
        .description = "ARMv6 architecture",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .v6,
        }),
    };
    result[@enumToInt(Feature.armv6_m)] = .{
        .index = @enumToInt(Feature.armv6_m),
        .name = @tagName(Feature.armv6_m),
        .llvm_name = "armv6-m",
        .description = "ARMv6m architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .mclass,
            .noarm,
            .strict_align,
            .thumb_mode,
            .v6m,
        }),
    };
    result[@enumToInt(Feature.armv6j)] = .{
        .index = @enumToInt(Feature.armv6j),
        .name = @tagName(Feature.armv6j),
        .llvm_name = "armv6j",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv6,
        }),
    };
    result[@enumToInt(Feature.armv6k)] = .{
        .index = @enumToInt(Feature.armv6k),
        .name = @tagName(Feature.armv6k),
        .llvm_name = "armv6k",
        .description = "ARMv6k architecture",
        .dependencies = featureSet(&[_]Feature{
            .v6k,
        }),
    };
    result[@enumToInt(Feature.armv6kz)] = .{
        .index = @enumToInt(Feature.armv6kz),
        .name = @tagName(Feature.armv6kz),
        .llvm_name = "armv6kz",
        .description = "ARMv6kz architecture",
        .dependencies = featureSet(&[_]Feature{
            .trustzone,
            .v6k,
        }),
    };
    result[@enumToInt(Feature.armv6s_m)] = .{
        .index = @enumToInt(Feature.armv6s_m),
        .name = @tagName(Feature.armv6s_m),
        .llvm_name = "armv6s-m",
        .description = "ARMv6sm architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .mclass,
            .noarm,
            .strict_align,
            .thumb_mode,
            .v6m,
        }),
    };
    result[@enumToInt(Feature.armv6t2)] = .{
        .index = @enumToInt(Feature.armv6t2),
        .name = @tagName(Feature.armv6t2),
        .llvm_name = "armv6t2",
        .description = "ARMv6t2 architecture",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .v6t2,
        }),
    };
    result[@enumToInt(Feature.armv7_a)] = .{
        .index = @enumToInt(Feature.armv7_a),
        .name = @tagName(Feature.armv7_a),
        .llvm_name = "armv7-a",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .db,
            .dsp,
            .neon,
            .v7,
        }),
    };
    result[@enumToInt(Feature.armv7_m)] = .{
        .index = @enumToInt(Feature.armv7_m),
        .name = @tagName(Feature.armv7_m),
        .llvm_name = "armv7-m",
        .description = "ARMv7m architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .hwdiv,
            .mclass,
            .noarm,
            .thumb_mode,
            .thumb2,
            .v7,
        }),
    };
    result[@enumToInt(Feature.armv7_r)] = .{
        .index = @enumToInt(Feature.armv7_r),
        .name = @tagName(Feature.armv7_r),
        .llvm_name = "armv7-r",
        .description = "ARMv7r architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .dsp,
            .hwdiv,
            .rclass,
            .v7,
        }),
    };
    result[@enumToInt(Feature.armv7e_m)] = .{
        .index = @enumToInt(Feature.armv7e_m),
        .name = @tagName(Feature.armv7e_m),
        .llvm_name = "armv7e-m",
        .description = "ARMv7em architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .dsp,
            .hwdiv,
            .mclass,
            .noarm,
            .thumb_mode,
            .thumb2,
            .v7,
        }),
    };
    result[@enumToInt(Feature.armv7k)] = .{
        .index = @enumToInt(Feature.armv7k),
        .name = @tagName(Feature.armv7k),
        .llvm_name = "armv7k",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv7_a,
        }),
    };
    result[@enumToInt(Feature.armv7s)] = .{
        .index = @enumToInt(Feature.armv7s),
        .name = @tagName(Feature.armv7s),
        .llvm_name = "armv7s",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv7_a,
        }),
    };
    result[@enumToInt(Feature.armv7ve)] = .{
        .index = @enumToInt(Feature.armv7ve),
        .name = @tagName(Feature.armv7ve),
        .llvm_name = "armv7ve",
        .description = "ARMv7ve architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .db,
            .dsp,
            .mp,
            .neon,
            .trustzone,
            .v7,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_a)] = .{
        .index = @enumToInt(Feature.armv8_a),
        .name = @tagName(Feature.armv8_a),
        .llvm_name = "armv8-a",
        .description = "ARMv8a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .trustzone,
            .v8,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_m_base)] = .{
        .index = @enumToInt(Feature.armv8_m_base),
        .name = @tagName(Feature.armv8_m_base),
        .llvm_name = "armv8-m.base",
        .description = "ARMv8mBaseline architecture",
        .dependencies = featureSet(&[_]Feature{
            .@"8msecext",
            .acquire_release,
            .db,
            .hwdiv,
            .mclass,
            .noarm,
            .strict_align,
            .thumb_mode,
            .v7clrex,
            .v8m,
        }),
    };
    result[@enumToInt(Feature.armv8_m_main)] = .{
        .index = @enumToInt(Feature.armv8_m_main),
        .name = @tagName(Feature.armv8_m_main),
        .llvm_name = "armv8-m.main",
        .description = "ARMv8mMainline architecture",
        .dependencies = featureSet(&[_]Feature{
            .@"8msecext",
            .acquire_release,
            .db,
            .hwdiv,
            .mclass,
            .noarm,
            .thumb_mode,
            .v8m_main,
        }),
    };
    result[@enumToInt(Feature.armv8_r)] = .{
        .index = @enumToInt(Feature.armv8_r),
        .name = @tagName(Feature.armv8_r),
        .llvm_name = "armv8-r",
        .description = "ARMv8r architecture",
        .dependencies = featureSet(&[_]Feature{
            .crc,
            .db,
            .dfb,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .rclass,
            .v8,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_1_a)] = .{
        .index = @enumToInt(Feature.armv8_1_a),
        .name = @tagName(Feature.armv8_1_a),
        .llvm_name = "armv8.1-a",
        .description = "ARMv81a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .trustzone,
            .v8_1a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_1_m_main)] = .{
        .index = @enumToInt(Feature.armv8_1_m_main),
        .name = @tagName(Feature.armv8_1_m_main),
        .llvm_name = "armv8.1-m.main",
        .description = "ARMv81mMainline architecture",
        .dependencies = featureSet(&[_]Feature{
            .@"8msecext",
            .acquire_release,
            .db,
            .hwdiv,
            .lob,
            .mclass,
            .noarm,
            .ras,
            .thumb_mode,
            .v8_1m_main,
        }),
    };
    result[@enumToInt(Feature.armv8_2_a)] = .{
        .index = @enumToInt(Feature.armv8_2_a),
        .name = @tagName(Feature.armv8_2_a),
        .llvm_name = "armv8.2-a",
        .description = "ARMv82a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .ras,
            .trustzone,
            .v8_2a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_3_a)] = .{
        .index = @enumToInt(Feature.armv8_3_a),
        .name = @tagName(Feature.armv8_3_a),
        .llvm_name = "armv8.3-a",
        .description = "ARMv83a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .ras,
            .trustzone,
            .v8_3a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_4_a)] = .{
        .index = @enumToInt(Feature.armv8_4_a),
        .name = @tagName(Feature.armv8_4_a),
        .llvm_name = "armv8.4-a",
        .description = "ARMv84a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dotprod,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .ras,
            .trustzone,
            .v8_4a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.armv8_5_a)] = .{
        .index = @enumToInt(Feature.armv8_5_a),
        .name = @tagName(Feature.armv8_5_a),
        .llvm_name = "armv8.5-a",
        .description = "ARMv85a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .crc,
            .crypto,
            .db,
            .dotprod,
            .dsp,
            .fp_armv8,
            .mp,
            .neon,
            .ras,
            .trustzone,
            .v8_5a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.avoid_movs_shop)] = .{
        .index = @enumToInt(Feature.avoid_movs_shop),
        .name = @tagName(Feature.avoid_movs_shop),
        .llvm_name = "avoid-movs-shop",
        .description = "Avoid movs instructions with shifter operand",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.avoid_partial_cpsr)] = .{
        .index = @enumToInt(Feature.avoid_partial_cpsr),
        .name = @tagName(Feature.avoid_partial_cpsr),
        .llvm_name = "avoid-partial-cpsr",
        .description = "Avoid CPSR partial update for OOO execution",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.cheap_predicable_cpsr)] = .{
        .index = @enumToInt(Feature.cheap_predicable_cpsr),
        .name = @tagName(Feature.cheap_predicable_cpsr),
        .llvm_name = "cheap-predicable-cpsr",
        .description = "Disable +1 predication cost for instructions updating CPSR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.crc)] = .{
        .index = @enumToInt(Feature.crc),
        .name = @tagName(Feature.crc),
        .llvm_name = "crc",
        .description = "Enable support for CRC instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.crypto)] = .{
        .index = @enumToInt(Feature.crypto),
        .name = @tagName(Feature.crypto),
        .llvm_name = "crypto",
        .description = "Enable support for Cryptography extensions",
        .dependencies = featureSet(&[_]Feature{
            .aes,
            .neon,
            .sha2,
        }),
    };
    result[@enumToInt(Feature.d32)] = .{
        .index = @enumToInt(Feature.d32),
        .name = @tagName(Feature.d32),
        .llvm_name = "d32",
        .description = "Extend FP to 32 double registers",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.db)] = .{
        .index = @enumToInt(Feature.db),
        .name = @tagName(Feature.db),
        .llvm_name = "db",
        .description = "Has data barrier (dmb/dsb) instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.dfb)] = .{
        .index = @enumToInt(Feature.dfb),
        .name = @tagName(Feature.dfb),
        .llvm_name = "dfb",
        .description = "Has full data barrier (dfb) instruction",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.disable_postra_scheduler)] = .{
        .index = @enumToInt(Feature.disable_postra_scheduler),
        .name = @tagName(Feature.disable_postra_scheduler),
        .llvm_name = "disable-postra-scheduler",
        .description = "Don't schedule again after register allocation",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.dont_widen_vmovs)] = .{
        .index = @enumToInt(Feature.dont_widen_vmovs),
        .name = @tagName(Feature.dont_widen_vmovs),
        .llvm_name = "dont-widen-vmovs",
        .description = "Don't widen VMOVS to VMOVD",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.dotprod)] = .{
        .index = @enumToInt(Feature.dotprod),
        .name = @tagName(Feature.dotprod),
        .llvm_name = "dotprod",
        .description = "Enable support for dot product instructions",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.dsp)] = .{
        .index = @enumToInt(Feature.dsp),
        .name = @tagName(Feature.dsp),
        .llvm_name = "dsp",
        .description = "Supports DSP instructions in ARM and/or Thumb2",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.execute_only)] = .{
        .index = @enumToInt(Feature.execute_only),
        .name = @tagName(Feature.execute_only),
        .llvm_name = "execute-only",
        .description = "Enable the generation of execute only code.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.expand_fp_mlx)] = .{
        .index = @enumToInt(Feature.expand_fp_mlx),
        .name = @tagName(Feature.expand_fp_mlx),
        .llvm_name = "expand-fp-mlx",
        .description = "Expand VFP/NEON MLA/MLS instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.exynos)] = .{
        .index = @enumToInt(Feature.exynos),
        .name = @tagName(Feature.exynos),
        .llvm_name = "exynos",
        .description = "Samsung Exynos processors",
        .dependencies = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .expand_fp_mlx,
            .fuse_aes,
            .fuse_literals,
            .hwdiv,
            .hwdiv_arm,
            .prof_unpr,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slow_vdup32,
            .slow_vgetlni32,
            .slowfpvmlx,
            .splat_vfp_neon,
            .use_aa,
            .wide_stride_vfp,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.fp_armv8)] = .{
        .index = @enumToInt(Feature.fp_armv8),
        .name = @tagName(Feature.fp_armv8),
        .llvm_name = "fp-armv8",
        .description = "Enable ARMv8 FP",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16,
            .fp_armv8sp,
            .vfp4,
        }),
    };
    result[@enumToInt(Feature.fp_armv8d16)] = .{
        .index = @enumToInt(Feature.fp_armv8d16),
        .name = @tagName(Feature.fp_armv8d16),
        .llvm_name = "fp-armv8d16",
        .description = "Enable ARMv8 FP with only 16 d-registers",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fp64,
            .vfp4d16,
        }),
    };
    result[@enumToInt(Feature.fp_armv8d16sp)] = .{
        .index = @enumToInt(Feature.fp_armv8d16sp),
        .name = @tagName(Feature.fp_armv8d16sp),
        .llvm_name = "fp-armv8d16sp",
        .description = "Enable ARMv8 FP with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .vfp4d16sp,
        }),
    };
    result[@enumToInt(Feature.fp_armv8sp)] = .{
        .index = @enumToInt(Feature.fp_armv8sp),
        .name = @tagName(Feature.fp_armv8sp),
        .llvm_name = "fp-armv8sp",
        .description = "Enable ARMv8 FP with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .d32,
            .fp_armv8d16sp,
            .vfp4sp,
        }),
    };
    result[@enumToInt(Feature.fp16)] = .{
        .index = @enumToInt(Feature.fp16),
        .name = @tagName(Feature.fp16),
        .llvm_name = "fp16",
        .description = "Enable half-precision floating point",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fp16fml)] = .{
        .index = @enumToInt(Feature.fp16fml),
        .name = @tagName(Feature.fp16fml),
        .llvm_name = "fp16fml",
        .description = "Enable full half-precision floating point fml instructions",
        .dependencies = featureSet(&[_]Feature{
            .fullfp16,
        }),
    };
    result[@enumToInt(Feature.fp64)] = .{
        .index = @enumToInt(Feature.fp64),
        .name = @tagName(Feature.fp64),
        .llvm_name = "fp64",
        .description = "Floating point unit supports double precision",
        .dependencies = featureSet(&[_]Feature{
            .fpregs64,
        }),
    };
    result[@enumToInt(Feature.fpao)] = .{
        .index = @enumToInt(Feature.fpao),
        .name = @tagName(Feature.fpao),
        .llvm_name = "fpao",
        .description = "Enable fast computation of positive address offsets",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fpregs)] = .{
        .index = @enumToInt(Feature.fpregs),
        .name = @tagName(Feature.fpregs),
        .llvm_name = "fpregs",
        .description = "Enable FP registers",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fpregs16)] = .{
        .index = @enumToInt(Feature.fpregs16),
        .name = @tagName(Feature.fpregs16),
        .llvm_name = "fpregs16",
        .description = "Enable 16-bit FP registers",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.fpregs64)] = .{
        .index = @enumToInt(Feature.fpregs64),
        .name = @tagName(Feature.fpregs64),
        .llvm_name = "fpregs64",
        .description = "Enable 64-bit FP registers",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.fullfp16)] = .{
        .index = @enumToInt(Feature.fullfp16),
        .name = @tagName(Feature.fullfp16),
        .llvm_name = "fullfp16",
        .description = "Enable full half-precision floating point",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fpregs16,
        }),
    };
    result[@enumToInt(Feature.fuse_aes)] = .{
        .index = @enumToInt(Feature.fuse_aes),
        .name = @tagName(Feature.fuse_aes),
        .llvm_name = "fuse-aes",
        .description = "CPU fuses AES crypto operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_literals)] = .{
        .index = @enumToInt(Feature.fuse_literals),
        .name = @tagName(Feature.fuse_literals),
        .llvm_name = "fuse-literals",
        .description = "CPU fuses literal generation operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.hwdiv)] = .{
        .index = @enumToInt(Feature.hwdiv),
        .name = @tagName(Feature.hwdiv),
        .llvm_name = "hwdiv",
        .description = "Enable divide instructions in Thumb",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.hwdiv_arm)] = .{
        .index = @enumToInt(Feature.hwdiv_arm),
        .name = @tagName(Feature.hwdiv_arm),
        .llvm_name = "hwdiv-arm",
        .description = "Enable divide instructions in ARM mode",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.iwmmxt)] = .{
        .index = @enumToInt(Feature.iwmmxt),
        .name = @tagName(Feature.iwmmxt),
        .llvm_name = "iwmmxt",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    result[@enumToInt(Feature.iwmmxt2)] = .{
        .index = @enumToInt(Feature.iwmmxt2),
        .name = @tagName(Feature.iwmmxt2),
        .llvm_name = "iwmmxt2",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    result[@enumToInt(Feature.krait)] = .{
        .index = @enumToInt(Feature.krait),
        .name = @tagName(Feature.krait),
        .llvm_name = "krait",
        .description = "Qualcomm Krait processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.kryo)] = .{
        .index = @enumToInt(Feature.kryo),
        .name = @tagName(Feature.kryo),
        .llvm_name = "kryo",
        .description = "Qualcomm Kryo processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.lob)] = .{
        .index = @enumToInt(Feature.lob),
        .name = @tagName(Feature.lob),
        .llvm_name = "lob",
        .description = "Enable Low Overhead Branch extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.long_calls)] = .{
        .index = @enumToInt(Feature.long_calls),
        .name = @tagName(Feature.long_calls),
        .llvm_name = "long-calls",
        .description = "Generate calls via indirect call instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.loop_align)] = .{
        .index = @enumToInt(Feature.loop_align),
        .name = @tagName(Feature.loop_align),
        .llvm_name = "loop-align",
        .description = "Prefer 32-bit alignment for loops",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.m3)] = .{
        .index = @enumToInt(Feature.m3),
        .name = @tagName(Feature.m3),
        .llvm_name = "m3",
        .description = "Cortex-M3 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mclass)] = .{
        .index = @enumToInt(Feature.mclass),
        .name = @tagName(Feature.mclass),
        .llvm_name = "mclass",
        .description = "Is microcontroller profile ('M' series)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mp)] = .{
        .index = @enumToInt(Feature.mp),
        .name = @tagName(Feature.mp),
        .llvm_name = "mp",
        .description = "Supports Multiprocessing extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.muxed_units)] = .{
        .index = @enumToInt(Feature.muxed_units),
        .name = @tagName(Feature.muxed_units),
        .llvm_name = "muxed-units",
        .description = "Has muxed AGU and NEON/FPU",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mve)] = .{
        .index = @enumToInt(Feature.mve),
        .name = @tagName(Feature.mve),
        .llvm_name = "mve",
        .description = "Support M-Class Vector Extension with integer ops",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .fpregs16,
            .fpregs64,
            .v8_1m_main,
        }),
    };
    result[@enumToInt(Feature.mve_fp)] = .{
        .index = @enumToInt(Feature.mve_fp),
        .name = @tagName(Feature.mve_fp),
        .llvm_name = "mve.fp",
        .description = "Support M-Class Vector Extension with integer and floating ops",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fullfp16,
            .mve,
        }),
    };
    result[@enumToInt(Feature.nacl_trap)] = .{
        .index = @enumToInt(Feature.nacl_trap),
        .name = @tagName(Feature.nacl_trap),
        .llvm_name = "nacl-trap",
        .description = "NaCl trap",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.neon)] = .{
        .index = @enumToInt(Feature.neon),
        .name = @tagName(Feature.neon),
        .llvm_name = "neon",
        .description = "Enable NEON instructions",
        .dependencies = featureSet(&[_]Feature{
            .vfp3,
        }),
    };
    result[@enumToInt(Feature.neon_fpmovs)] = .{
        .index = @enumToInt(Feature.neon_fpmovs),
        .name = @tagName(Feature.neon_fpmovs),
        .llvm_name = "neon-fpmovs",
        .description = "Convert VMOVSR, VMOVRS, VMOVS to NEON",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.neonfp)] = .{
        .index = @enumToInt(Feature.neonfp),
        .name = @tagName(Feature.neonfp),
        .llvm_name = "neonfp",
        .description = "Use NEON for single precision FP",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.no_branch_predictor)] = .{
        .index = @enumToInt(Feature.no_branch_predictor),
        .name = @tagName(Feature.no_branch_predictor),
        .llvm_name = "no-branch-predictor",
        .description = "Has no branch predictor",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.no_movt)] = .{
        .index = @enumToInt(Feature.no_movt),
        .name = @tagName(Feature.no_movt),
        .llvm_name = "no-movt",
        .description = "Don't use movt/movw pairs for 32-bit imms",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.no_neg_immediates)] = .{
        .index = @enumToInt(Feature.no_neg_immediates),
        .name = @tagName(Feature.no_neg_immediates),
        .llvm_name = "no-neg-immediates",
        .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.noarm)] = .{
        .index = @enumToInt(Feature.noarm),
        .name = @tagName(Feature.noarm),
        .llvm_name = "noarm",
        .description = "Does not support ARM mode execution",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.nonpipelined_vfp)] = .{
        .index = @enumToInt(Feature.nonpipelined_vfp),
        .name = @tagName(Feature.nonpipelined_vfp),
        .llvm_name = "nonpipelined-vfp",
        .description = "VFP instructions are not pipelined",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.perfmon)] = .{
        .index = @enumToInt(Feature.perfmon),
        .name = @tagName(Feature.perfmon),
        .llvm_name = "perfmon",
        .description = "Enable support for Performance Monitor extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.prefer_ishst)] = .{
        .index = @enumToInt(Feature.prefer_ishst),
        .name = @tagName(Feature.prefer_ishst),
        .llvm_name = "prefer-ishst",
        .description = "Prefer ISHST barriers",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.prefer_vmovsr)] = .{
        .index = @enumToInt(Feature.prefer_vmovsr),
        .name = @tagName(Feature.prefer_vmovsr),
        .llvm_name = "prefer-vmovsr",
        .description = "Prefer VMOVSR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.prof_unpr)] = .{
        .index = @enumToInt(Feature.prof_unpr),
        .name = @tagName(Feature.prof_unpr),
        .llvm_name = "prof-unpr",
        .description = "Is profitable to unpredicate",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.r4)] = .{
        .index = @enumToInt(Feature.r4),
        .name = @tagName(Feature.r4),
        .llvm_name = "r4",
        .description = "Cortex-R4 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.r5)] = .{
        .index = @enumToInt(Feature.r5),
        .name = @tagName(Feature.r5),
        .llvm_name = "r5",
        .description = "Cortex-R5 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.r52)] = .{
        .index = @enumToInt(Feature.r52),
        .name = @tagName(Feature.r52),
        .llvm_name = "r52",
        .description = "Cortex-R52 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.r7)] = .{
        .index = @enumToInt(Feature.r7),
        .name = @tagName(Feature.r7),
        .llvm_name = "r7",
        .description = "Cortex-R7 ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ras)] = .{
        .index = @enumToInt(Feature.ras),
        .name = @tagName(Feature.ras),
        .llvm_name = "ras",
        .description = "Enable Reliability, Availability and Serviceability extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.rclass)] = .{
        .index = @enumToInt(Feature.rclass),
        .name = @tagName(Feature.rclass),
        .llvm_name = "rclass",
        .description = "Is realtime profile ('R' series)",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.read_tp_hard)] = .{
        .index = @enumToInt(Feature.read_tp_hard),
        .name = @tagName(Feature.read_tp_hard),
        .llvm_name = "read-tp-hard",
        .description = "Reading thread pointer from register",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_r9)] = .{
        .index = @enumToInt(Feature.reserve_r9),
        .name = @tagName(Feature.reserve_r9),
        .llvm_name = "reserve-r9",
        .description = "Reserve R9, making it unavailable as GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ret_addr_stack)] = .{
        .index = @enumToInt(Feature.ret_addr_stack),
        .name = @tagName(Feature.ret_addr_stack),
        .llvm_name = "ret-addr-stack",
        .description = "Has return address stack",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sb)] = .{
        .index = @enumToInt(Feature.sb),
        .name = @tagName(Feature.sb),
        .llvm_name = "sb",
        .description = "Enable v8.5a Speculation Barrier",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sha2)] = .{
        .index = @enumToInt(Feature.sha2),
        .name = @tagName(Feature.sha2),
        .llvm_name = "sha2",
        .description = "Enable SHA1 and SHA256 support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.slow_fp_brcc)] = .{
        .index = @enumToInt(Feature.slow_fp_brcc),
        .name = @tagName(Feature.slow_fp_brcc),
        .llvm_name = "slow-fp-brcc",
        .description = "FP compare + branch is slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_load_D_subreg)] = .{
        .index = @enumToInt(Feature.slow_load_D_subreg),
        .name = @tagName(Feature.slow_load_D_subreg),
        .llvm_name = "slow-load-D-subreg",
        .description = "Loading into D subregs is slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_odd_reg)] = .{
        .index = @enumToInt(Feature.slow_odd_reg),
        .name = @tagName(Feature.slow_odd_reg),
        .llvm_name = "slow-odd-reg",
        .description = "VLDM/VSTM starting with an odd register is slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_vdup32)] = .{
        .index = @enumToInt(Feature.slow_vdup32),
        .name = @tagName(Feature.slow_vdup32),
        .llvm_name = "slow-vdup32",
        .description = "Has slow VDUP32 - prefer VMOV",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_vgetlni32)] = .{
        .index = @enumToInt(Feature.slow_vgetlni32),
        .name = @tagName(Feature.slow_vgetlni32),
        .llvm_name = "slow-vgetlni32",
        .description = "Has slow VGETLNi32 - prefer VMOV",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slowfpvmlx)] = .{
        .index = @enumToInt(Feature.slowfpvmlx),
        .name = @tagName(Feature.slowfpvmlx),
        .llvm_name = "slowfpvmlx",
        .description = "Disable VFP / NEON MAC instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.soft_float)] = .{
        .index = @enumToInt(Feature.soft_float),
        .name = @tagName(Feature.soft_float),
        .llvm_name = "soft-float",
        .description = "Use software floating point features.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.splat_vfp_neon)] = .{
        .index = @enumToInt(Feature.splat_vfp_neon),
        .name = @tagName(Feature.splat_vfp_neon),
        .llvm_name = "splat-vfp-neon",
        .description = "Splat register from VFP to NEON",
        .dependencies = featureSet(&[_]Feature{
            .dont_widen_vmovs,
        }),
    };
    result[@enumToInt(Feature.strict_align)] = .{
        .index = @enumToInt(Feature.strict_align),
        .name = @tagName(Feature.strict_align),
        .llvm_name = "strict-align",
        .description = "Disallow all unaligned memory access",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.swift)] = .{
        .index = @enumToInt(Feature.swift),
        .name = @tagName(Feature.swift),
        .llvm_name = "swift",
        .description = "Swift ARM processors",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.thumb_mode)] = .{
        .index = @enumToInt(Feature.thumb_mode),
        .name = @tagName(Feature.thumb_mode),
        .llvm_name = "thumb-mode",
        .description = "Thumb mode",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.thumb2)] = .{
        .index = @enumToInt(Feature.thumb2),
        .name = @tagName(Feature.thumb2),
        .llvm_name = "thumb2",
        .description = "Enable Thumb2 instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.trustzone)] = .{
        .index = @enumToInt(Feature.trustzone),
        .name = @tagName(Feature.trustzone),
        .llvm_name = "trustzone",
        .description = "Enable support for TrustZone security extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.use_aa)] = .{
        .index = @enumToInt(Feature.use_aa),
        .name = @tagName(Feature.use_aa),
        .llvm_name = "use-aa",
        .description = "Use alias analysis during codegen",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.use_misched)] = .{
        .index = @enumToInt(Feature.use_misched),
        .name = @tagName(Feature.use_misched),
        .llvm_name = "use-misched",
        .description = "Use the MachineScheduler",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.v4t)] = .{
        .index = @enumToInt(Feature.v4t),
        .name = @tagName(Feature.v4t),
        .llvm_name = "v4t",
        .description = "Support ARM v4T instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.v5t)] = .{
        .index = @enumToInt(Feature.v5t),
        .name = @tagName(Feature.v5t),
        .llvm_name = "v5t",
        .description = "Support ARM v5T instructions",
        .dependencies = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    result[@enumToInt(Feature.v5te)] = .{
        .index = @enumToInt(Feature.v5te),
        .name = @tagName(Feature.v5te),
        .llvm_name = "v5te",
        .description = "Support ARM v5TE, v5TEj, and v5TExp instructions",
        .dependencies = featureSet(&[_]Feature{
            .v5t,
        }),
    };
    result[@enumToInt(Feature.v6)] = .{
        .index = @enumToInt(Feature.v6),
        .name = @tagName(Feature.v6),
        .llvm_name = "v6",
        .description = "Support ARM v6 instructions",
        .dependencies = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    result[@enumToInt(Feature.v6k)] = .{
        .index = @enumToInt(Feature.v6k),
        .name = @tagName(Feature.v6k),
        .llvm_name = "v6k",
        .description = "Support ARM v6k instructions",
        .dependencies = featureSet(&[_]Feature{
            .v6,
        }),
    };
    result[@enumToInt(Feature.v6m)] = .{
        .index = @enumToInt(Feature.v6m),
        .name = @tagName(Feature.v6m),
        .llvm_name = "v6m",
        .description = "Support ARM v6M instructions",
        .dependencies = featureSet(&[_]Feature{
            .v6,
        }),
    };
    result[@enumToInt(Feature.v6t2)] = .{
        .index = @enumToInt(Feature.v6t2),
        .name = @tagName(Feature.v6t2),
        .llvm_name = "v6t2",
        .description = "Support ARM v6t2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .thumb2,
            .v6k,
            .v8m,
        }),
    };
    result[@enumToInt(Feature.v7)] = .{
        .index = @enumToInt(Feature.v7),
        .name = @tagName(Feature.v7),
        .llvm_name = "v7",
        .description = "Support ARM v7 instructions",
        .dependencies = featureSet(&[_]Feature{
            .perfmon,
            .v6t2,
            .v7clrex,
        }),
    };
    result[@enumToInt(Feature.v7clrex)] = .{
        .index = @enumToInt(Feature.v7clrex),
        .name = @tagName(Feature.v7clrex),
        .llvm_name = "v7clrex",
        .description = "Has v7 clrex instruction",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.v8)] = .{
        .index = @enumToInt(Feature.v8),
        .name = @tagName(Feature.v8),
        .llvm_name = "v8",
        .description = "Support ARM v8 instructions",
        .dependencies = featureSet(&[_]Feature{
            .acquire_release,
            .v7,
        }),
    };
    result[@enumToInt(Feature.v8_1a)] = .{
        .index = @enumToInt(Feature.v8_1a),
        .name = @tagName(Feature.v8_1a),
        .llvm_name = "v8.1a",
        .description = "Support ARM v8.1a instructions",
        .dependencies = featureSet(&[_]Feature{
            .v8,
        }),
    };
    result[@enumToInt(Feature.v8_1m_main)] = .{
        .index = @enumToInt(Feature.v8_1m_main),
        .name = @tagName(Feature.v8_1m_main),
        .llvm_name = "v8.1m.main",
        .description = "Support ARM v8-1M Mainline instructions",
        .dependencies = featureSet(&[_]Feature{
            .v8m_main,
        }),
    };
    result[@enumToInt(Feature.v8_2a)] = .{
        .index = @enumToInt(Feature.v8_2a),
        .name = @tagName(Feature.v8_2a),
        .llvm_name = "v8.2a",
        .description = "Support ARM v8.2a instructions",
        .dependencies = featureSet(&[_]Feature{
            .v8_1a,
        }),
    };
    result[@enumToInt(Feature.v8_3a)] = .{
        .index = @enumToInt(Feature.v8_3a),
        .name = @tagName(Feature.v8_3a),
        .llvm_name = "v8.3a",
        .description = "Support ARM v8.3a instructions",
        .dependencies = featureSet(&[_]Feature{
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.v8_4a)] = .{
        .index = @enumToInt(Feature.v8_4a),
        .name = @tagName(Feature.v8_4a),
        .llvm_name = "v8.4a",
        .description = "Support ARM v8.4a instructions",
        .dependencies = featureSet(&[_]Feature{
            .dotprod,
            .v8_3a,
        }),
    };
    result[@enumToInt(Feature.v8_5a)] = .{
        .index = @enumToInt(Feature.v8_5a),
        .name = @tagName(Feature.v8_5a),
        .llvm_name = "v8.5a",
        .description = "Support ARM v8.5a instructions",
        .dependencies = featureSet(&[_]Feature{
            .sb,
            .v8_4a,
        }),
    };
    result[@enumToInt(Feature.v8m)] = .{
        .index = @enumToInt(Feature.v8m),
        .name = @tagName(Feature.v8m),
        .llvm_name = "v8m",
        .description = "Support ARM v8M Baseline instructions",
        .dependencies = featureSet(&[_]Feature{
            .v6m,
        }),
    };
    result[@enumToInt(Feature.v8m_main)] = .{
        .index = @enumToInt(Feature.v8m_main),
        .name = @tagName(Feature.v8m_main),
        .llvm_name = "v8m.main",
        .description = "Support ARM v8M Mainline instructions",
        .dependencies = featureSet(&[_]Feature{
            .v7,
        }),
    };
    result[@enumToInt(Feature.vfp2)] = .{
        .index = @enumToInt(Feature.vfp2),
        .name = @tagName(Feature.vfp2),
        .llvm_name = "vfp2",
        .description = "Enable VFP2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .vfp2d16,
            .vfp2sp,
        }),
    };
    result[@enumToInt(Feature.vfp2d16)] = .{
        .index = @enumToInt(Feature.vfp2d16),
        .name = @tagName(Feature.vfp2d16),
        .llvm_name = "vfp2d16",
        .description = "Enable VFP2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .vfp2d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp2d16sp)] = .{
        .index = @enumToInt(Feature.vfp2d16sp),
        .name = @tagName(Feature.vfp2d16sp),
        .llvm_name = "vfp2d16sp",
        .description = "Enable VFP2 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.vfp2sp)] = .{
        .index = @enumToInt(Feature.vfp2sp),
        .name = @tagName(Feature.vfp2sp),
        .llvm_name = "vfp2sp",
        .description = "Enable VFP2 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .vfp2d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp3)] = .{
        .index = @enumToInt(Feature.vfp3),
        .name = @tagName(Feature.vfp3),
        .llvm_name = "vfp3",
        .description = "Enable VFP3 instructions",
        .dependencies = featureSet(&[_]Feature{
            .vfp3d16,
            .vfp3sp,
        }),
    };
    result[@enumToInt(Feature.vfp3d16)] = .{
        .index = @enumToInt(Feature.vfp3d16),
        .name = @tagName(Feature.vfp3d16),
        .llvm_name = "vfp3d16",
        .description = "Enable VFP3 instructions with only 16 d-registers",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .vfp2,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp3d16sp)] = .{
        .index = @enumToInt(Feature.vfp3d16sp),
        .name = @tagName(Feature.vfp3d16sp),
        .llvm_name = "vfp3d16sp",
        .description = "Enable VFP3 instructions with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .vfp2sp,
        }),
    };
    result[@enumToInt(Feature.vfp3sp)] = .{
        .index = @enumToInt(Feature.vfp3sp),
        .name = @tagName(Feature.vfp3sp),
        .llvm_name = "vfp3sp",
        .description = "Enable VFP3 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .d32,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp4)] = .{
        .index = @enumToInt(Feature.vfp4),
        .name = @tagName(Feature.vfp4),
        .llvm_name = "vfp4",
        .description = "Enable VFP4 instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp16,
            .vfp3,
            .vfp4d16,
            .vfp4sp,
        }),
    };
    result[@enumToInt(Feature.vfp4d16)] = .{
        .index = @enumToInt(Feature.vfp4d16),
        .name = @tagName(Feature.vfp4d16),
        .llvm_name = "vfp4d16",
        .description = "Enable VFP4 instructions with only 16 d-registers",
        .dependencies = featureSet(&[_]Feature{
            .fp16,
            .fp64,
            .vfp3d16,
            .vfp4d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp4d16sp)] = .{
        .index = @enumToInt(Feature.vfp4d16sp),
        .name = @tagName(Feature.vfp4d16sp),
        .llvm_name = "vfp4d16sp",
        .description = "Enable VFP4 instructions with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .fp16,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp4sp)] = .{
        .index = @enumToInt(Feature.vfp4sp),
        .name = @tagName(Feature.vfp4sp),
        .llvm_name = "vfp4sp",
        .description = "Enable VFP4 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .d32,
            .fp16,
            .vfp3sp,
            .vfp4d16sp,
        }),
    };
    result[@enumToInt(Feature.virtualization)] = .{
        .index = @enumToInt(Feature.virtualization),
        .name = @tagName(Feature.virtualization),
        .llvm_name = "virtualization",
        .description = "Supports Virtualization extension",
        .dependencies = featureSet(&[_]Feature{
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    result[@enumToInt(Feature.vldn_align)] = .{
        .index = @enumToInt(Feature.vldn_align),
        .name = @tagName(Feature.vldn_align),
        .llvm_name = "vldn-align",
        .description = "Check for VLDn unaligned access",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.vmlx_forwarding)] = .{
        .index = @enumToInt(Feature.vmlx_forwarding),
        .name = @tagName(Feature.vmlx_forwarding),
        .llvm_name = "vmlx-forwarding",
        .description = "Has multiplier accumulator forwarding",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.vmlx_hazards)] = .{
        .index = @enumToInt(Feature.vmlx_hazards),
        .name = @tagName(Feature.vmlx_hazards),
        .llvm_name = "vmlx-hazards",
        .description = "Has VMLx hazards",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.wide_stride_vfp)] = .{
        .index = @enumToInt(Feature.wide_stride_vfp),
        .name = @tagName(Feature.wide_stride_vfp),
        .llvm_name = "wide-stride-vfp",
        .description = "Use a wide stride when allocating VFP registers",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.xscale)] = .{
        .index = @enumToInt(Feature.xscale),
        .name = @tagName(Feature.xscale),
        .llvm_name = "xscale",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    result[@enumToInt(Feature.zcz)] = .{
        .index = @enumToInt(Feature.zcz),
        .name = @tagName(Feature.zcz),
        .llvm_name = "zcz",
        .description = "Has zero-cycle zeroing instructions",
        .dependencies = 0,
    };
    break :blk result;
};

pub const cpu = struct {
    pub const arm1020e = Cpu{
        .name = "arm1020e",
        .llvm_name = "arm1020e",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm1020t = Cpu{
        .name = "arm1020t",
        .llvm_name = "arm1020t",
        .features = featureSet(&[_]Feature{
            .armv5t,
        }),
    };
    pub const arm1022e = Cpu{
        .name = "arm1022e",
        .llvm_name = "arm1022e",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm10e = Cpu{
        .name = "arm10e",
        .llvm_name = "arm10e",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm10tdmi = Cpu{
        .name = "arm10tdmi",
        .llvm_name = "arm10tdmi",
        .features = featureSet(&[_]Feature{
            .armv5t,
        }),
    };
    pub const arm1136j_s = Cpu{
        .name = "arm1136j_s",
        .llvm_name = "arm1136j-s",
        .features = featureSet(&[_]Feature{
            .armv6,
        }),
    };
    pub const arm1136jf_s = Cpu{
        .name = "arm1136jf_s",
        .llvm_name = "arm1136jf-s",
        .features = featureSet(&[_]Feature{
            .armv6,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm1156t2_s = Cpu{
        .name = "arm1156t2_s",
        .llvm_name = "arm1156t2-s",
        .features = featureSet(&[_]Feature{
            .armv6t2,
        }),
    };
    pub const arm1156t2f_s = Cpu{
        .name = "arm1156t2f_s",
        .llvm_name = "arm1156t2f-s",
        .features = featureSet(&[_]Feature{
            .armv6t2,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm1176j_s = Cpu{
        .name = "arm1176j_s",
        .llvm_name = "arm1176j-s",
        .features = featureSet(&[_]Feature{
            .armv6kz,
        }),
    };
    pub const arm1176jz_s = Cpu{
        .name = "arm1176jz_s",
        .llvm_name = "arm1176jz-s",
        .features = featureSet(&[_]Feature{
            .armv6kz,
        }),
    };
    pub const arm1176jzf_s = Cpu{
        .name = "arm1176jzf_s",
        .llvm_name = "arm1176jzf-s",
        .features = featureSet(&[_]Feature{
            .armv6kz,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm710t = Cpu{
        .name = "arm710t",
        .llvm_name = "arm710t",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm720t = Cpu{
        .name = "arm720t",
        .llvm_name = "arm720t",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm7tdmi = Cpu{
        .name = "arm7tdmi",
        .llvm_name = "arm7tdmi",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm7tdmi_s = Cpu{
        .name = "arm7tdmi_s",
        .llvm_name = "arm7tdmi-s",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm8 = Cpu{
        .name = "arm8",
        .llvm_name = "arm8",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const arm810 = Cpu{
        .name = "arm810",
        .llvm_name = "arm810",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const arm9 = Cpu{
        .name = "arm9",
        .llvm_name = "arm9",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm920 = Cpu{
        .name = "arm920",
        .llvm_name = "arm920",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm920t = Cpu{
        .name = "arm920t",
        .llvm_name = "arm920t",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm922t = Cpu{
        .name = "arm922t",
        .llvm_name = "arm922t",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm926ej_s = Cpu{
        .name = "arm926ej_s",
        .llvm_name = "arm926ej-s",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm940t = Cpu{
        .name = "arm940t",
        .llvm_name = "arm940t",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const arm946e_s = Cpu{
        .name = "arm946e_s",
        .llvm_name = "arm946e-s",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm966e_s = Cpu{
        .name = "arm966e_s",
        .llvm_name = "arm966e-s",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm968e_s = Cpu{
        .name = "arm968e_s",
        .llvm_name = "arm968e-s",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm9e = Cpu{
        .name = "arm9e",
        .llvm_name = "arm9e",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const arm9tdmi = Cpu{
        .name = "arm9tdmi",
        .llvm_name = "arm9tdmi",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const cortex_a12 = Cpu{
        .name = "cortex_a12",
        .llvm_name = "cortex-a12",
        .features = featureSet(&[_]Feature{
            .a12,
            .armv7_a,
            .avoid_partial_cpsr,
            .mp,
            .ret_addr_stack,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a15 = Cpu{
        .name = "cortex_a15",
        .llvm_name = "cortex-a15",
        .features = featureSet(&[_]Feature{
            .a15,
            .armv7_a,
            .avoid_partial_cpsr,
            .dont_widen_vmovs,
            .mp,
            .muxed_units,
            .ret_addr_stack,
            .splat_vfp_neon,
            .trustzone,
            .vfp4,
            .virtualization,
            .vldn_align,
        }),
    };
    pub const cortex_a17 = Cpu{
        .name = "cortex_a17",
        .llvm_name = "cortex-a17",
        .features = featureSet(&[_]Feature{
            .a17,
            .armv7_a,
            .avoid_partial_cpsr,
            .mp,
            .ret_addr_stack,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a32 = Cpu{
        .name = "cortex_a32",
        .llvm_name = "cortex-a32",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a35 = Cpu{
        .name = "cortex_a35",
        .llvm_name = "cortex-a35",
        .features = featureSet(&[_]Feature{
            .a35,
            .armv8_a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a5 = Cpu{
        .name = "cortex_a5",
        .llvm_name = "cortex-a5",
        .features = featureSet(&[_]Feature{
            .a5,
            .armv7_a,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .trustzone,
            .vfp4,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a53 = Cpu{
        .name = "cortex_a53",
        .llvm_name = "cortex-a53",
        .features = featureSet(&[_]Feature{
            .a53,
            .armv8_a,
            .crc,
            .crypto,
            .fpao,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a55 = Cpu{
        .name = "cortex_a55",
        .llvm_name = "cortex-a55",
        .features = featureSet(&[_]Feature{
            .a55,
            .armv8_2_a,
            .dotprod,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a57 = Cpu{
        .name = "cortex_a57",
        .llvm_name = "cortex-a57",
        .features = featureSet(&[_]Feature{
            .a57,
            .armv8_a,
            .avoid_partial_cpsr,
            .cheap_predicable_cpsr,
            .crc,
            .crypto,
            .fpao,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a7 = Cpu{
        .name = "cortex_a7",
        .llvm_name = "cortex-a7",
        .features = featureSet(&[_]Feature{
            .a7,
            .armv7_a,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
            .vmlx_hazards,
        }),
    };
    pub const cortex_a72 = Cpu{
        .name = "cortex_a72",
        .llvm_name = "cortex-a72",
        .features = featureSet(&[_]Feature{
            .a72,
            .armv8_a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a73 = Cpu{
        .name = "cortex_a73",
        .llvm_name = "cortex-a73",
        .features = featureSet(&[_]Feature{
            .a73,
            .armv8_a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a75 = Cpu{
        .name = "cortex_a75",
        .llvm_name = "cortex-a75",
        .features = featureSet(&[_]Feature{
            .a75,
            .armv8_2_a,
            .dotprod,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a76 = Cpu{
        .name = "cortex_a76",
        .llvm_name = "cortex-a76",
        .features = featureSet(&[_]Feature{
            .a76,
            .armv8_2_a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a76ae = Cpu{
        .name = "cortex_a76ae",
        .llvm_name = "cortex-a76ae",
        .features = featureSet(&[_]Feature{
            .a76,
            .armv8_2_a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a8 = Cpu{
        .name = "cortex_a8",
        .llvm_name = "cortex-a8",
        .features = featureSet(&[_]Feature{
            .a8,
            .armv7_a,
            .nonpipelined_vfp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .trustzone,
            .vmlx_forwarding,
            .vmlx_hazards,
        }),
    };
    pub const cortex_a9 = Cpu{
        .name = "cortex_a9",
        .llvm_name = "cortex-a9",
        .features = featureSet(&[_]Feature{
            .a9,
            .armv7_a,
            .avoid_partial_cpsr,
            .expand_fp_mlx,
            .fp16,
            .mp,
            .muxed_units,
            .neon_fpmovs,
            .prefer_vmovsr,
            .ret_addr_stack,
            .trustzone,
            .vldn_align,
            .vmlx_forwarding,
            .vmlx_hazards,
        }),
    };
    pub const cortex_m0 = Cpu{
        .name = "cortex_m0",
        .llvm_name = "cortex-m0",
        .features = featureSet(&[_]Feature{
            .armv6_m,
        }),
    };
    pub const cortex_m0plus = Cpu{
        .name = "cortex_m0plus",
        .llvm_name = "cortex-m0plus",
        .features = featureSet(&[_]Feature{
            .armv6_m,
        }),
    };
    pub const cortex_m1 = Cpu{
        .name = "cortex_m1",
        .llvm_name = "cortex-m1",
        .features = featureSet(&[_]Feature{
            .armv6_m,
        }),
    };
    pub const cortex_m23 = Cpu{
        .name = "cortex_m23",
        .llvm_name = "cortex-m23",
        .features = featureSet(&[_]Feature{
            .armv8_m_base,
            .no_movt,
        }),
    };
    pub const cortex_m3 = Cpu{
        .name = "cortex_m3",
        .llvm_name = "cortex-m3",
        .features = featureSet(&[_]Feature{
            .armv7_m,
            .loop_align,
            .m3,
            .no_branch_predictor,
            .use_aa,
            .use_misched,
        }),
    };
    pub const cortex_m33 = Cpu{
        .name = "cortex_m33",
        .llvm_name = "cortex-m33",
        .features = featureSet(&[_]Feature{
            .armv8_m_main,
            .dsp,
            .fp_armv8d16sp,
            .loop_align,
            .no_branch_predictor,
            .slowfpvmlx,
            .use_aa,
            .use_misched,
        }),
    };
    pub const cortex_m35p = Cpu{
        .name = "cortex_m35p",
        .llvm_name = "cortex-m35p",
        .features = featureSet(&[_]Feature{
            .armv8_m_main,
            .dsp,
            .fp_armv8d16sp,
            .loop_align,
            .no_branch_predictor,
            .slowfpvmlx,
            .use_aa,
            .use_misched,
        }),
    };
    pub const cortex_m4 = Cpu{
        .name = "cortex_m4",
        .llvm_name = "cortex-m4",
        .features = featureSet(&[_]Feature{
            .armv7e_m,
            .loop_align,
            .no_branch_predictor,
            .slowfpvmlx,
            .use_aa,
            .use_misched,
            .vfp4d16sp,
        }),
    };
    pub const cortex_m7 = Cpu{
        .name = "cortex_m7",
        .llvm_name = "cortex-m7",
        .features = featureSet(&[_]Feature{
            .armv7e_m,
            .fp_armv8d16,
        }),
    };
    pub const cortex_r4 = Cpu{
        .name = "cortex_r4",
        .llvm_name = "cortex-r4",
        .features = featureSet(&[_]Feature{
            .armv7_r,
            .avoid_partial_cpsr,
            .r4,
            .ret_addr_stack,
        }),
    };
    pub const cortex_r4f = Cpu{
        .name = "cortex_r4f",
        .llvm_name = "cortex-r4f",
        .features = featureSet(&[_]Feature{
            .armv7_r,
            .avoid_partial_cpsr,
            .r4,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r5 = Cpu{
        .name = "cortex_r5",
        .llvm_name = "cortex-r5",
        .features = featureSet(&[_]Feature{
            .armv7_r,
            .avoid_partial_cpsr,
            .hwdiv_arm,
            .r5,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r52 = Cpu{
        .name = "cortex_r52",
        .llvm_name = "cortex-r52",
        .features = featureSet(&[_]Feature{
            .armv8_r,
            .fpao,
            .r52,
            .use_aa,
            .use_misched,
        }),
    };
    pub const cortex_r7 = Cpu{
        .name = "cortex_r7",
        .llvm_name = "cortex-r7",
        .features = featureSet(&[_]Feature{
            .armv7_r,
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv_arm,
            .mp,
            .r7,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r8 = Cpu{
        .name = "cortex_r8",
        .llvm_name = "cortex-r8",
        .features = featureSet(&[_]Feature{
            .armv7_r,
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv_arm,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cyclone = Cpu{
        .name = "cyclone",
        .llvm_name = "cyclone",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .avoid_movs_shop,
            .avoid_partial_cpsr,
            .crypto,
            .disable_postra_scheduler,
            .hwdiv,
            .hwdiv_arm,
            .mp,
            .neonfp,
            .ret_addr_stack,
            .slowfpvmlx,
            .swift,
            .use_misched,
            .vfp4,
            .zcz,
        }),
    };
    pub const ep9312 = Cpu{
        .name = "ep9312",
        .llvm_name = "ep9312",
        .features = featureSet(&[_]Feature{
            .armv4t,
        }),
    };
    pub const exynos_m1 = Cpu{
        .name = "exynos_m1",
        .llvm_name = "exynos-m1",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .exynos,
        }),
    };
    pub const exynos_m2 = Cpu{
        .name = "exynos_m2",
        .llvm_name = "exynos-m2",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .exynos,
        }),
    };
    pub const exynos_m3 = Cpu{
        .name = "exynos_m3",
        .llvm_name = "exynos-m3",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .exynos,
        }),
    };
    pub const exynos_m4 = Cpu{
        .name = "exynos_m4",
        .llvm_name = "exynos-m4",
        .features = featureSet(&[_]Feature{
            .armv8_2_a,
            .dotprod,
            .exynos,
            .fullfp16,
        }),
    };
    pub const exynos_m5 = Cpu{
        .name = "exynos_m5",
        .llvm_name = "exynos-m5",
        .features = featureSet(&[_]Feature{
            .armv8_2_a,
            .dotprod,
            .exynos,
            .fullfp16,
        }),
    };
    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = 0,
    };
    pub const iwmmxt = Cpu{
        .name = "iwmmxt",
        .llvm_name = "iwmmxt",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
    pub const krait = Cpu{
        .name = "krait",
        .llvm_name = "krait",
        .features = featureSet(&[_]Feature{
            .armv7_a,
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv,
            .hwdiv_arm,
            .krait,
            .muxed_units,
            .ret_addr_stack,
            .vfp4,
            .vldn_align,
            .vmlx_forwarding,
        }),
    };
    pub const kryo = Cpu{
        .name = "kryo",
        .llvm_name = "kryo",
        .features = featureSet(&[_]Feature{
            .armv8_a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
            .kryo,
        }),
    };
    pub const mpcore = Cpu{
        .name = "mpcore",
        .llvm_name = "mpcore",
        .features = featureSet(&[_]Feature{
            .armv6k,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const mpcorenovfp = Cpu{
        .name = "mpcorenovfp",
        .llvm_name = "mpcorenovfp",
        .features = featureSet(&[_]Feature{
            .armv6k,
        }),
    };
    pub const sc000 = Cpu{
        .name = "sc000",
        .llvm_name = "sc000",
        .features = featureSet(&[_]Feature{
            .armv6_m,
        }),
    };
    pub const sc300 = Cpu{
        .name = "sc300",
        .llvm_name = "sc300",
        .features = featureSet(&[_]Feature{
            .armv7_m,
            .m3,
            .no_branch_predictor,
            .use_aa,
            .use_misched,
        }),
    };
    pub const strongarm = Cpu{
        .name = "strongarm",
        .llvm_name = "strongarm",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const strongarm110 = Cpu{
        .name = "strongarm110",
        .llvm_name = "strongarm110",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const strongarm1100 = Cpu{
        .name = "strongarm1100",
        .llvm_name = "strongarm1100",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const strongarm1110 = Cpu{
        .name = "strongarm1110",
        .llvm_name = "strongarm1110",
        .features = featureSet(&[_]Feature{
            .armv4,
        }),
    };
    pub const swift = Cpu{
        .name = "swift",
        .llvm_name = "swift",
        .features = featureSet(&[_]Feature{
            .armv7_a,
            .avoid_movs_shop,
            .avoid_partial_cpsr,
            .disable_postra_scheduler,
            .hwdiv,
            .hwdiv_arm,
            .mp,
            .neonfp,
            .prefer_ishst,
            .prof_unpr,
            .ret_addr_stack,
            .slow_load_D_subreg,
            .slow_odd_reg,
            .slow_vdup32,
            .slow_vgetlni32,
            .slowfpvmlx,
            .swift,
            .use_misched,
            .vfp4,
            .vmlx_hazards,
            .wide_stride_vfp,
        }),
    };
    pub const xscale = Cpu{
        .name = "xscale",
        .llvm_name = "xscale",
        .features = featureSet(&[_]Feature{
            .armv5te,
        }),
    };
};

/// All arm CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.arm1020e,
    &cpu.arm1020t,
    &cpu.arm1022e,
    &cpu.arm10e,
    &cpu.arm10tdmi,
    &cpu.arm1136j_s,
    &cpu.arm1136jf_s,
    &cpu.arm1156t2_s,
    &cpu.arm1156t2f_s,
    &cpu.arm1176j_s,
    &cpu.arm1176jz_s,
    &cpu.arm1176jzf_s,
    &cpu.arm710t,
    &cpu.arm720t,
    &cpu.arm7tdmi,
    &cpu.arm7tdmi_s,
    &cpu.arm8,
    &cpu.arm810,
    &cpu.arm9,
    &cpu.arm920,
    &cpu.arm920t,
    &cpu.arm922t,
    &cpu.arm926ej_s,
    &cpu.arm940t,
    &cpu.arm946e_s,
    &cpu.arm966e_s,
    &cpu.arm968e_s,
    &cpu.arm9e,
    &cpu.arm9tdmi,
    &cpu.cortex_a12,
    &cpu.cortex_a15,
    &cpu.cortex_a17,
    &cpu.cortex_a32,
    &cpu.cortex_a35,
    &cpu.cortex_a5,
    &cpu.cortex_a53,
    &cpu.cortex_a55,
    &cpu.cortex_a57,
    &cpu.cortex_a7,
    &cpu.cortex_a72,
    &cpu.cortex_a73,
    &cpu.cortex_a75,
    &cpu.cortex_a76,
    &cpu.cortex_a76ae,
    &cpu.cortex_a8,
    &cpu.cortex_a9,
    &cpu.cortex_m0,
    &cpu.cortex_m0plus,
    &cpu.cortex_m1,
    &cpu.cortex_m23,
    &cpu.cortex_m3,
    &cpu.cortex_m33,
    &cpu.cortex_m35p,
    &cpu.cortex_m4,
    &cpu.cortex_m7,
    &cpu.cortex_r4,
    &cpu.cortex_r4f,
    &cpu.cortex_r5,
    &cpu.cortex_r52,
    &cpu.cortex_r7,
    &cpu.cortex_r8,
    &cpu.cyclone,
    &cpu.ep9312,
    &cpu.exynos_m1,
    &cpu.exynos_m2,
    &cpu.exynos_m3,
    &cpu.exynos_m4,
    &cpu.exynos_m5,
    &cpu.generic,
    &cpu.iwmmxt,
    &cpu.krait,
    &cpu.kryo,
    &cpu.mpcore,
    &cpu.mpcorenovfp,
    &cpu.sc000,
    &cpu.sc300,
    &cpu.strongarm,
    &cpu.strongarm110,
    &cpu.strongarm1100,
    &cpu.strongarm1110,
    &cpu.swift,
    &cpu.xscale,
};
