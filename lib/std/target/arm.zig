// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    @"32bit",
    @"8msecext",
    a76,
    aclass,
    acquire_release,
    aes,
    avoid_movs_shop,
    avoid_partial_cpsr,
    bf16,
    cde,
    cdecp0,
    cdecp1,
    cdecp2,
    cdecp3,
    cdecp4,
    cdecp5,
    cdecp6,
    cdecp7,
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
    fp16,
    fp16fml,
    fp64,
    fp_armv8,
    fp_armv8d16,
    fp_armv8d16sp,
    fp_armv8sp,
    fpao,
    fpregs,
    fpregs16,
    fpregs64,
    fullfp16,
    fuse_aes,
    fuse_literals,
    has_v4t,
    has_v5t,
    has_v5te,
    has_v6,
    has_v6k,
    has_v6m,
    has_v6t2,
    has_v7,
    has_v7clrex,
    has_v8_1a,
    has_v8_1m_main,
    has_v8_2a,
    has_v8_3a,
    has_v8_4a,
    has_v8_5a,
    has_v8_6a,
    has_v8,
    has_v8m,
    has_v8m_main,
    hwdiv,
    hwdiv_arm,
    i8mm,
    iwmmxt,
    iwmmxt2,
    lob,
    long_calls,
    loop_align,
    m3,
    mclass,
    mp,
    muxed_units,
    mve,
    mve_fp,
    mve1beat,
    mve2beat,
    mve4beat,
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
    slowfpvfmx,
    slowfpvmlx,
    soft_float,
    splat_vfp_neon,
    strict_align,
    swift,
    thumb2,
    thumb_mode,
    trustzone,
    use_misched,
    v2,
    v2a,
    v3,
    v3m,
    v4,
    v4t,
    v5t,
    v5te,
    v5tej,
    v6,
    v6j,
    v6k,
    v6kz,
    v6m,
    v6sm,
    v6t2,
    v7a,
    v7em,
    v7k,
    v7m,
    v7r,
    v7s,
    v7ve,
    v8a,
    v8m,
    v8m_main,
    v8r,
    v8_1a,
    v8_1m_main,
    v8_2a,
    v8_3a,
    v8_4a,
    v8_5a,
    v8_6a,
    vfp2,
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

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    @setEvalBranchQuota(10000);
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.@"32bit")] = .{
        .llvm_name = "32bit",
        .description = "Prefer 32-bit Thumb instrs",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.@"8msecext")] = .{
        .llvm_name = "8msecext",
        .description = "Enable support for ARMv8-M Security Extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.a76)] = .{
        .llvm_name = "a76",
        .description = "Cortex-A76 ARM processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.aclass)] = .{
        .llvm_name = "aclass",
        .description = "Is application profile ('A' series)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.acquire_release)] = .{
        .llvm_name = "acquire-release",
        .description = "Has v8 acquire/release (lda/ldaex  etc) instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.aes)] = .{
        .llvm_name = "aes",
        .description = "Enable AES support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.avoid_movs_shop)] = .{
        .llvm_name = "avoid-movs-shop",
        .description = "Avoid movs instructions with shifter operand",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.avoid_partial_cpsr)] = .{
        .llvm_name = "avoid-partial-cpsr",
        .description = "Avoid CPSR partial update for OOO execution",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.bf16)] = .{
        .llvm_name = "bf16",
        .description = "Enable support for BFloat16 instructions",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.cde)] = .{
        .llvm_name = "cde",
        .description = "Support CDE instructions",
        .dependencies = featureSet(&[_]Feature{
            .v8m_main,
        }),
    };
    result[@enumToInt(Feature.cdecp0)] = .{
        .llvm_name = "cdecp0",
        .description = "Coprocessor 0 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp1)] = .{
        .llvm_name = "cdecp1",
        .description = "Coprocessor 1 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp2)] = .{
        .llvm_name = "cdecp2",
        .description = "Coprocessor 2 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp3)] = .{
        .llvm_name = "cdecp3",
        .description = "Coprocessor 3 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp4)] = .{
        .llvm_name = "cdecp4",
        .description = "Coprocessor 4 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp5)] = .{
        .llvm_name = "cdecp5",
        .description = "Coprocessor 5 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp6)] = .{
        .llvm_name = "cdecp6",
        .description = "Coprocessor 6 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cdecp7)] = .{
        .llvm_name = "cdecp7",
        .description = "Coprocessor 7 ISA is CDEv1",
        .dependencies = featureSet(&[_]Feature{
            .cde,
        }),
    };
    result[@enumToInt(Feature.cheap_predicable_cpsr)] = .{
        .llvm_name = "cheap-predicable-cpsr",
        .description = "Disable +1 predication cost for instructions updating CPSR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.crc)] = .{
        .llvm_name = "crc",
        .description = "Enable support for CRC instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.crypto)] = .{
        .llvm_name = "crypto",
        .description = "Enable support for Cryptography extensions",
        .dependencies = featureSet(&[_]Feature{
            .aes,
            .neon,
            .sha2,
        }),
    };
    result[@enumToInt(Feature.d32)] = .{
        .llvm_name = "d32",
        .description = "Extend FP to 32 double registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.db)] = .{
        .llvm_name = "db",
        .description = "Has data barrier (dmb/dsb) instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dfb)] = .{
        .llvm_name = "dfb",
        .description = "Has full data barrier (dfb) instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.disable_postra_scheduler)] = .{
        .llvm_name = "disable-postra-scheduler",
        .description = "Don't schedule again after register allocation",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dont_widen_vmovs)] = .{
        .llvm_name = "dont-widen-vmovs",
        .description = "Don't widen VMOVS to VMOVD",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dotprod)] = .{
        .llvm_name = "dotprod",
        .description = "Enable support for dot product instructions",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.dsp)] = .{
        .llvm_name = "dsp",
        .description = "Supports DSP instructions in ARM and/or Thumb2",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.execute_only)] = .{
        .llvm_name = "execute-only",
        .description = "Enable the generation of execute only code.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.expand_fp_mlx)] = .{
        .llvm_name = "expand-fp-mlx",
        .description = "Expand VFP/NEON MLA/MLS instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.exynos)] = .{
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
            .slowfpvfmx,
            .slowfpvmlx,
            .splat_vfp_neon,
            .wide_stride_vfp,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.fp16)] = .{
        .llvm_name = "fp16",
        .description = "Enable half-precision floating point",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp16fml)] = .{
        .llvm_name = "fp16fml",
        .description = "Enable full half-precision floating point fml instructions",
        .dependencies = featureSet(&[_]Feature{
            .fullfp16,
        }),
    };
    result[@enumToInt(Feature.fp64)] = .{
        .llvm_name = "fp64",
        .description = "Floating point unit supports double precision",
        .dependencies = featureSet(&[_]Feature{
            .fpregs64,
        }),
    };
    result[@enumToInt(Feature.fp_armv8)] = .{
        .llvm_name = "fp-armv8",
        .description = "Enable ARMv8 FP",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16,
            .fp_armv8sp,
            .vfp4,
        }),
    };
    result[@enumToInt(Feature.fp_armv8d16)] = .{
        .llvm_name = "fp-armv8d16",
        .description = "Enable ARMv8 FP with only 16 d-registers",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fp64,
            .vfp4d16,
        }),
    };
    result[@enumToInt(Feature.fp_armv8d16sp)] = .{
        .llvm_name = "fp-armv8d16sp",
        .description = "Enable ARMv8 FP with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .vfp4d16sp,
        }),
    };
    result[@enumToInt(Feature.fp_armv8sp)] = .{
        .llvm_name = "fp-armv8sp",
        .description = "Enable ARMv8 FP with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .d32,
            .fp_armv8d16sp,
            .vfp4sp,
        }),
    };
    result[@enumToInt(Feature.fpao)] = .{
        .llvm_name = "fpao",
        .description = "Enable fast computation of positive address offsets",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fpregs)] = .{
        .llvm_name = "fpregs",
        .description = "Enable FP registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fpregs16)] = .{
        .llvm_name = "fpregs16",
        .description = "Enable 16-bit FP registers",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.fpregs64)] = .{
        .llvm_name = "fpregs64",
        .description = "Enable 64-bit FP registers",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.fullfp16)] = .{
        .llvm_name = "fullfp16",
        .description = "Enable full half-precision floating point",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fpregs16,
        }),
    };
    result[@enumToInt(Feature.fuse_aes)] = .{
        .llvm_name = "fuse-aes",
        .description = "CPU fuses AES crypto operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_literals)] = .{
        .llvm_name = "fuse-literals",
        .description = "CPU fuses literal generation operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.has_v4t)] = .{
        .llvm_name = "v4t",
        .description = "Support ARM v4T instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.has_v5t)] = .{
        .llvm_name = "v5t",
        .description = "Support ARM v5T instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v4t,
        }),
    };
    result[@enumToInt(Feature.has_v5te)] = .{
        .llvm_name = "v5te",
        .description = "Support ARM v5TE, v5TEj, and v5TExp instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v5t,
        }),
    };
    result[@enumToInt(Feature.has_v6)] = .{
        .llvm_name = "v6",
        .description = "Support ARM v6 instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.has_v6k)] = .{
        .llvm_name = "v6k",
        .description = "Support ARM v6k instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v6,
        }),
    };
    result[@enumToInt(Feature.has_v6m)] = .{
        .llvm_name = "v6m",
        .description = "Support ARM v6M instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v6,
        }),
    };
    result[@enumToInt(Feature.has_v6t2)] = .{
        .llvm_name = "v6t2",
        .description = "Support ARM v6t2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .thumb2,
            .has_v6k,
            .has_v8m,
        }),
    };
    result[@enumToInt(Feature.has_v7)] = .{
        .llvm_name = "v7",
        .description = "Support ARM v7 instructions",
        .dependencies = featureSet(&[_]Feature{
            .perfmon,
            .has_v6t2,
            .has_v7clrex,
        }),
    };
    result[@enumToInt(Feature.has_v7clrex)] = .{
        .llvm_name = "v7clrex",
        .description = "Has v7 clrex instruction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.has_v8)] = .{
        .llvm_name = "v8",
        .description = "Support ARM v8 instructions",
        .dependencies = featureSet(&[_]Feature{
            .acquire_release,
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.has_v8_1a)] = .{
        .llvm_name = "v8.1a",
        .description = "Support ARM v8.1a instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v8,
        }),
    };
    result[@enumToInt(Feature.has_v8_1m_main)] = .{
        .llvm_name = "v8.1m.main",
        .description = "Support ARM v8-1M Mainline instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v8m_main,
        }),
    };
    result[@enumToInt(Feature.has_v8_2a)] = .{
        .llvm_name = "v8.2a",
        .description = "Support ARM v8.2a instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v8_1a,
        }),
    };
    result[@enumToInt(Feature.has_v8_3a)] = .{
        .llvm_name = "v8.3a",
        .description = "Support ARM v8.3a instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v8_2a,
        }),
    };
    result[@enumToInt(Feature.has_v8_4a)] = .{
        .llvm_name = "v8.4a",
        .description = "Support ARM v8.4a instructions",
        .dependencies = featureSet(&[_]Feature{
            .dotprod,
            .has_v8_3a,
        }),
    };
    result[@enumToInt(Feature.has_v8_5a)] = .{
        .llvm_name = "v8.5a",
        .description = "Support ARM v8.5a instructions",
        .dependencies = featureSet(&[_]Feature{
            .sb,
            .has_v8_4a,
        }),
    };
    result[@enumToInt(Feature.has_v8_6a)] = .{
        .llvm_name = "v8.6a",
        .description = "Support ARM v8.6a instructions",
        .dependencies = featureSet(&[_]Feature{
            .bf16,
            .i8mm,
            .has_v8_5a,
        }),
    };
    result[@enumToInt(Feature.has_v8m)] = .{
        .llvm_name = "v8m",
        .description = "Support ARM v8M Baseline instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v6m,
        }),
    };
    result[@enumToInt(Feature.has_v8m_main)] = .{
        .llvm_name = "v8m.main",
        .description = "Support ARM v8M Mainline instructions",
        .dependencies = featureSet(&[_]Feature{
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.hwdiv)] = .{
        .llvm_name = "hwdiv",
        .description = "Enable divide instructions in Thumb",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.hwdiv_arm)] = .{
        .llvm_name = "hwdiv-arm",
        .description = "Enable divide instructions in ARM mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.i8mm)] = .{
        .llvm_name = "i8mm",
        .description = "Enable Matrix Multiply Int8 Extension",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.iwmmxt)] = .{
        .llvm_name = "iwmmxt",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.iwmmxt2)] = .{
        .llvm_name = "iwmmxt2",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.lob)] = .{
        .llvm_name = "lob",
        .description = "Enable Low Overhead Branch extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.long_calls)] = .{
        .llvm_name = "long-calls",
        .description = "Generate calls via indirect call instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.loop_align)] = .{
        .llvm_name = "loop-align",
        .description = "Prefer 32-bit alignment for loops",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.m3)] = .{
        .llvm_name = "m3",
        .description = "Cortex-M3 ARM processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mclass)] = .{
        .llvm_name = "mclass",
        .description = "Is microcontroller profile ('M' series)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mp)] = .{
        .llvm_name = "mp",
        .description = "Supports Multiprocessing extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.muxed_units)] = .{
        .llvm_name = "muxed-units",
        .description = "Has muxed AGU and NEON/FPU",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mve)] = .{
        .llvm_name = "mve",
        .description = "Support M-Class Vector Extension with integer ops",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .fpregs16,
            .fpregs64,
            .has_v8_1m_main,
        }),
    };
    result[@enumToInt(Feature.mve_fp)] = .{
        .llvm_name = "mve.fp",
        .description = "Support M-Class Vector Extension with integer and floating ops",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8d16sp,
            .fullfp16,
            .mve,
        }),
    };
    result[@enumToInt(Feature.mve1beat)] = .{
        .llvm_name = "mve1beat",
        .description = "Model MVE instructions as a 1 beat per tick architecture",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mve2beat)] = .{
        .llvm_name = "mve2beat",
        .description = "Model MVE instructions as a 2 beats per tick architecture",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mve4beat)] = .{
        .llvm_name = "mve4beat",
        .description = "Model MVE instructions as a 4 beats per tick architecture",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nacl_trap)] = .{
        .llvm_name = "nacl-trap",
        .description = "NaCl trap",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.neon)] = .{
        .llvm_name = "neon",
        .description = "Enable NEON instructions",
        .dependencies = featureSet(&[_]Feature{
            .vfp3,
        }),
    };
    result[@enumToInt(Feature.neon_fpmovs)] = .{
        .llvm_name = "neon-fpmovs",
        .description = "Convert VMOVSR, VMOVRS, VMOVS to NEON",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.neonfp)] = .{
        .llvm_name = "neonfp",
        .description = "Use NEON for single precision FP",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_branch_predictor)] = .{
        .llvm_name = "no-branch-predictor",
        .description = "Has no branch predictor",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_movt)] = .{
        .llvm_name = "no-movt",
        .description = "Don't use movt/movw pairs for 32-bit imms",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.no_neg_immediates)] = .{
        .llvm_name = "no-neg-immediates",
        .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.noarm)] = .{
        .llvm_name = "noarm",
        .description = "Does not support ARM mode execution",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nonpipelined_vfp)] = .{
        .llvm_name = "nonpipelined-vfp",
        .description = "VFP instructions are not pipelined",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.perfmon)] = .{
        .llvm_name = "perfmon",
        .description = "Enable support for Performance Monitor extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.prefer_ishst)] = .{
        .llvm_name = "prefer-ishst",
        .description = "Prefer ISHST barriers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.prefer_vmovsr)] = .{
        .llvm_name = "prefer-vmovsr",
        .description = "Prefer VMOVSR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.prof_unpr)] = .{
        .llvm_name = "prof-unpr",
        .description = "Is profitable to unpredicate",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.r4)] = .{
        .llvm_name = "r4",
        .description = "Cortex-R4 ARM processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ras)] = .{
        .llvm_name = "ras",
        .description = "Enable Reliability, Availability and Serviceability extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.rclass)] = .{
        .llvm_name = "rclass",
        .description = "Is realtime profile ('R' series)",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.read_tp_hard)] = .{
        .llvm_name = "read-tp-hard",
        .description = "Reading thread pointer from register",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_r9)] = .{
        .llvm_name = "reserve-r9",
        .description = "Reserve R9, making it unavailable as GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ret_addr_stack)] = .{
        .llvm_name = "ret-addr-stack",
        .description = "Has return address stack",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sb)] = .{
        .llvm_name = "sb",
        .description = "Enable v8.5a Speculation Barrier",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sha2)] = .{
        .llvm_name = "sha2",
        .description = "Enable SHA1 and SHA256 support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.slow_fp_brcc)] = .{
        .llvm_name = "slow-fp-brcc",
        .description = "FP compare + branch is slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_load_D_subreg)] = .{
        .llvm_name = "slow-load-D-subreg",
        .description = "Loading into D subregs is slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_odd_reg)] = .{
        .llvm_name = "slow-odd-reg",
        .description = "VLDM/VSTM starting with an odd register is slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_vdup32)] = .{
        .llvm_name = "slow-vdup32",
        .description = "Has slow VDUP32 - prefer VMOV",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_vgetlni32)] = .{
        .llvm_name = "slow-vgetlni32",
        .description = "Has slow VGETLNi32 - prefer VMOV",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slowfpvfmx)] = .{
        .llvm_name = "slowfpvfmx",
        .description = "Disable VFP / NEON FMA instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slowfpvmlx)] = .{
        .llvm_name = "slowfpvmlx",
        .description = "Disable VFP / NEON MAC instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.soft_float)] = .{
        .llvm_name = "soft-float",
        .description = "Use software floating point features.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.splat_vfp_neon)] = .{
        .llvm_name = "splat-vfp-neon",
        .description = "Splat register from VFP to NEON",
        .dependencies = featureSet(&[_]Feature{
            .dont_widen_vmovs,
        }),
    };
    result[@enumToInt(Feature.strict_align)] = .{
        .llvm_name = "strict-align",
        .description = "Disallow all unaligned memory access",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.swift)] = .{
        .llvm_name = "swift",
        .description = "Swift ARM processors",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.thumb2)] = .{
        .llvm_name = "thumb2",
        .description = "Enable Thumb2 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.thumb_mode)] = .{
        .llvm_name = "thumb-mode",
        .description = "Thumb mode",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.trustzone)] = .{
        .llvm_name = "trustzone",
        .description = "Enable support for TrustZone security extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_misched)] = .{
        .llvm_name = "use-misched",
        .description = "Use the MachineScheduler",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.v2)] = .{
        .llvm_name = "armv2",
        .description = "ARMv2 architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
        }),
    };
    result[@enumToInt(Feature.v2a)] = .{
        .llvm_name = "armv2a",
        .description = "ARMv2a architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
        }),
    };
    result[@enumToInt(Feature.v3)] = .{
        .llvm_name = "armv3",
        .description = "ARMv3 architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
        }),
    };
    result[@enumToInt(Feature.v3m)] = .{
        .llvm_name = "armv3m",
        .description = "ARMv3m architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
        }),
    };
    result[@enumToInt(Feature.v4)] = .{
        .llvm_name = "armv4",
        .description = "ARMv4 architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
        }),
    };
    result[@enumToInt(Feature.v4t)] = .{
        .llvm_name = "armv4t",
        .description = "ARMv4t architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
            .has_v4t,
        }),
    };
    result[@enumToInt(Feature.v5t)] = .{
        .llvm_name = "armv5t",
        .description = "ARMv5t architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
            .has_v5t,
        }),
    };
    result[@enumToInt(Feature.v5te)] = .{
        .llvm_name = "armv5te",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.v5tej)] = .{
        .llvm_name = "armv5tej",
        .description = "ARMv5tej architecture",
        .dependencies = featureSet(&[_]Feature{
            .strict_align,
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.v6)] = .{
        .llvm_name = "armv6",
        .description = "ARMv6 architecture",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .has_v6,
        }),
    };
    result[@enumToInt(Feature.v6m)] = .{
        .llvm_name = "armv6-m",
        .description = "ARMv6m architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .mclass,
            .noarm,
            .strict_align,
            .thumb_mode,
            .has_v6m,
        }),
    };
    result[@enumToInt(Feature.v6j)] = .{
        .llvm_name = "armv6j",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .v6,
        }),
    };
    result[@enumToInt(Feature.v6k)] = .{
        .llvm_name = "armv6k",
        .description = "ARMv6k architecture",
        .dependencies = featureSet(&[_]Feature{
            .has_v6k,
        }),
    };
    result[@enumToInt(Feature.v6kz)] = .{
        .llvm_name = "armv6kz",
        .description = "ARMv6kz architecture",
        .dependencies = featureSet(&[_]Feature{
            .trustzone,
            .has_v6k,
        }),
    };
    result[@enumToInt(Feature.v6sm)] = .{
        .llvm_name = "armv6s-m",
        .description = "ARMv6sm architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .mclass,
            .noarm,
            .strict_align,
            .thumb_mode,
            .has_v6m,
        }),
    };
    result[@enumToInt(Feature.v6t2)] = .{
        .llvm_name = "armv6t2",
        .description = "ARMv6t2 architecture",
        .dependencies = featureSet(&[_]Feature{
            .dsp,
            .has_v6t2,
        }),
    };
    result[@enumToInt(Feature.v7a)] = .{
        .llvm_name = "armv7-a",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .db,
            .dsp,
            .neon,
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.v7m)] = .{
        .llvm_name = "armv7-m",
        .description = "ARMv7m architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .hwdiv,
            .mclass,
            .noarm,
            .thumb_mode,
            .thumb2,
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.v7r)] = .{
        .llvm_name = "armv7-r",
        .description = "ARMv7r architecture",
        .dependencies = featureSet(&[_]Feature{
            .db,
            .dsp,
            .hwdiv,
            .rclass,
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.v7em)] = .{
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
            .has_v7,
        }),
    };
    result[@enumToInt(Feature.v7k)] = .{
        .llvm_name = "armv7k",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .v7a,
        }),
    };
    result[@enumToInt(Feature.v7s)] = .{
        .llvm_name = "armv7s",
        .description = "ARMv7a architecture",
        .dependencies = featureSet(&[_]Feature{
            .v7a,
        }),
    };
    result[@enumToInt(Feature.v7ve)] = .{
        .llvm_name = "armv7ve",
        .description = "ARMv7ve architecture",
        .dependencies = featureSet(&[_]Feature{
            .aclass,
            .db,
            .dsp,
            .mp,
            .neon,
            .trustzone,
            .has_v7,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8a)] = .{
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
            .has_v8,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8m)] = .{
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
            .has_v7clrex,
            .has_v8m,
        }),
    };
    result[@enumToInt(Feature.v8m_main)] = .{
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
            .has_v8m_main,
        }),
    };
    result[@enumToInt(Feature.v8r)] = .{
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
            .has_v8,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_1a)] = .{
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
            .has_v8_1a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_1m_main)] = .{
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
            .has_v8_1m_main,
        }),
    };
    result[@enumToInt(Feature.v8_2a)] = .{
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
            .has_v8_2a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_3a)] = .{
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
            .has_v8_3a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_4a)] = .{
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
            .has_v8_4a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_5a)] = .{
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
            .has_v8_5a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.v8_6a)] = .{
        .llvm_name = "armv8.6-a",
        .description = "ARMv86a architecture",
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
            .has_v8_6a,
            .virtualization,
        }),
    };
    result[@enumToInt(Feature.vfp2)] = .{
        .llvm_name = "vfp2",
        .description = "Enable VFP2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .vfp2sp,
        }),
    };
    result[@enumToInt(Feature.vfp2sp)] = .{
        .llvm_name = "vfp2sp",
        .description = "Enable VFP2 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .fpregs,
        }),
    };
    result[@enumToInt(Feature.vfp3)] = .{
        .llvm_name = "vfp3",
        .description = "Enable VFP3 instructions",
        .dependencies = featureSet(&[_]Feature{
            .vfp3d16,
            .vfp3sp,
        }),
    };
    result[@enumToInt(Feature.vfp3d16)] = .{
        .llvm_name = "vfp3d16",
        .description = "Enable VFP3 instructions with only 16 d-registers",
        .dependencies = featureSet(&[_]Feature{
            .fp64,
            .vfp2,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp3d16sp)] = .{
        .llvm_name = "vfp3d16sp",
        .description = "Enable VFP3 instructions with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .vfp2sp,
        }),
    };
    result[@enumToInt(Feature.vfp3sp)] = .{
        .llvm_name = "vfp3sp",
        .description = "Enable VFP3 instructions with no double precision",
        .dependencies = featureSet(&[_]Feature{
            .d32,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp4)] = .{
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
        .llvm_name = "vfp4d16sp",
        .description = "Enable VFP4 instructions with only 16 d-registers and no double precision",
        .dependencies = featureSet(&[_]Feature{
            .fp16,
            .vfp3d16sp,
        }),
    };
    result[@enumToInt(Feature.vfp4sp)] = .{
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
        .llvm_name = "virtualization",
        .description = "Supports Virtualization extension",
        .dependencies = featureSet(&[_]Feature{
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    result[@enumToInt(Feature.vldn_align)] = .{
        .llvm_name = "vldn-align",
        .description = "Check for VLDn unaligned access",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vmlx_forwarding)] = .{
        .llvm_name = "vmlx-forwarding",
        .description = "Has multiplier accumulator forwarding",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.vmlx_hazards)] = .{
        .llvm_name = "vmlx-hazards",
        .description = "Has VMLx hazards",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.wide_stride_vfp)] = .{
        .llvm_name = "wide-stride-vfp",
        .description = "Use a wide stride when allocating VFP registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.xscale)] = .{
        .llvm_name = "xscale",
        .description = "ARMv5te architecture",
        .dependencies = featureSet(&[_]Feature{
            .has_v5te,
        }),
    };
    result[@enumToInt(Feature.zcz)] = .{
        .llvm_name = "zcz",
        .description = "Has zero-cycle zeroing instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    const ti = @typeInfo(Feature);
    for (result) |*elem, i| {
        elem.index = i;
        elem.name = ti.Enum.fields[i].name;
    }
    break :blk result;
};

pub const cpu = struct {
    pub const arm1020e = CpuModel{
        .name = "arm1020e",
        .llvm_name = "arm1020e",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm1020t = CpuModel{
        .name = "arm1020t",
        .llvm_name = "arm1020t",
        .features = featureSet(&[_]Feature{
            .v5t,
        }),
    };
    pub const arm1022e = CpuModel{
        .name = "arm1022e",
        .llvm_name = "arm1022e",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm10e = CpuModel{
        .name = "arm10e",
        .llvm_name = "arm10e",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm10tdmi = CpuModel{
        .name = "arm10tdmi",
        .llvm_name = "arm10tdmi",
        .features = featureSet(&[_]Feature{
            .v5t,
        }),
    };
    pub const arm1136j_s = CpuModel{
        .name = "arm1136j_s",
        .llvm_name = "arm1136j-s",
        .features = featureSet(&[_]Feature{
            .v6,
        }),
    };
    pub const arm1136jf_s = CpuModel{
        .name = "arm1136jf_s",
        .llvm_name = "arm1136jf-s",
        .features = featureSet(&[_]Feature{
            .v6,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm1156t2_s = CpuModel{
        .name = "arm1156t2_s",
        .llvm_name = "arm1156t2-s",
        .features = featureSet(&[_]Feature{
            .v6t2,
        }),
    };
    pub const arm1156t2f_s = CpuModel{
        .name = "arm1156t2f_s",
        .llvm_name = "arm1156t2f-s",
        .features = featureSet(&[_]Feature{
            .v6t2,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm1176j_s = CpuModel{
        .name = "arm1176j_s",
        .llvm_name = "arm1176j-s",
        .features = featureSet(&[_]Feature{
            .v6kz,
        }),
    };
    pub const arm1176jz_s = CpuModel{
        .name = "arm1176jz_s",
        .llvm_name = "arm1176jz-s",
        .features = featureSet(&[_]Feature{
            .v6kz,
        }),
    };
    pub const arm1176jzf_s = CpuModel{
        .name = "arm1176jzf_s",
        .llvm_name = "arm1176jzf-s",
        .features = featureSet(&[_]Feature{
            .v6kz,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const arm710t = CpuModel{
        .name = "arm710t",
        .llvm_name = "arm710t",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm720t = CpuModel{
        .name = "arm720t",
        .llvm_name = "arm720t",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm7tdmi = CpuModel{
        .name = "arm7tdmi",
        .llvm_name = "arm7tdmi",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm7tdmi_s = CpuModel{
        .name = "arm7tdmi_s",
        .llvm_name = "arm7tdmi-s",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm8 = CpuModel{
        .name = "arm8",
        .llvm_name = "arm8",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const arm810 = CpuModel{
        .name = "arm810",
        .llvm_name = "arm810",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const arm9 = CpuModel{
        .name = "arm9",
        .llvm_name = "arm9",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm920 = CpuModel{
        .name = "arm920",
        .llvm_name = "arm920",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm920t = CpuModel{
        .name = "arm920t",
        .llvm_name = "arm920t",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm922t = CpuModel{
        .name = "arm922t",
        .llvm_name = "arm922t",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm926ej_s = CpuModel{
        .name = "arm926ej_s",
        .llvm_name = "arm926ej-s",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm940t = CpuModel{
        .name = "arm940t",
        .llvm_name = "arm940t",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const arm946e_s = CpuModel{
        .name = "arm946e_s",
        .llvm_name = "arm946e-s",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm966e_s = CpuModel{
        .name = "arm966e_s",
        .llvm_name = "arm966e-s",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm968e_s = CpuModel{
        .name = "arm968e_s",
        .llvm_name = "arm968e-s",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm9e = CpuModel{
        .name = "arm9e",
        .llvm_name = "arm9e",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const arm9tdmi = CpuModel{
        .name = "arm9tdmi",
        .llvm_name = "arm9tdmi",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const baseline = CpuModel{
        .name = "baseline",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .v7a,
        }),
    };
    pub const cortex_a12 = CpuModel{
        .name = "cortex_a12",
        .llvm_name = "cortex-a12",
        .features = featureSet(&[_]Feature{
            .v7a,
            .avoid_partial_cpsr,
            .mp,
            .ret_addr_stack,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a15 = CpuModel{
        .name = "cortex_a15",
        .llvm_name = "cortex-a15",
        .features = featureSet(&[_]Feature{
            .v7a,
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
    pub const cortex_a17 = CpuModel{
        .name = "cortex_a17",
        .llvm_name = "cortex-a17",
        .features = featureSet(&[_]Feature{
            .v7a,
            .avoid_partial_cpsr,
            .mp,
            .ret_addr_stack,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a32 = CpuModel{
        .name = "cortex_a32",
        .llvm_name = "cortex-a32",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
            .v8a,
        }),
    };
    pub const cortex_a35 = CpuModel{
        .name = "cortex_a35",
        .llvm_name = "cortex-a35",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
            .v8a,
        }),
    };
    pub const cortex_a5 = CpuModel{
        .name = "cortex_a5",
        .llvm_name = "cortex-a5",
        .features = featureSet(&[_]Feature{
            .v7a,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .trustzone,
            .vfp4,
            .vmlx_forwarding,
        }),
    };
    pub const cortex_a53 = CpuModel{
        .name = "cortex_a53",
        .llvm_name = "cortex-a53",
        .features = featureSet(&[_]Feature{
            .v8a,
            .crc,
            .crypto,
            .fpao,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a55 = CpuModel{
        .name = "cortex_a55",
        .llvm_name = "cortex-a55",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .dotprod,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a57 = CpuModel{
        .name = "cortex_a57",
        .llvm_name = "cortex-a57",
        .features = featureSet(&[_]Feature{
            .v8a,
            .avoid_partial_cpsr,
            .cheap_predicable_cpsr,
            .crc,
            .crypto,
            .fpao,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a7 = CpuModel{
        .name = "cortex_a7",
        .llvm_name = "cortex-a7",
        .features = featureSet(&[_]Feature{
            .v7a,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .trustzone,
            .vfp4,
            .virtualization,
            .vmlx_forwarding,
            .vmlx_hazards,
        }),
    };
    pub const cortex_a72 = CpuModel{
        .name = "cortex_a72",
        .llvm_name = "cortex-a72",
        .features = featureSet(&[_]Feature{
            .v8a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a73 = CpuModel{
        .name = "cortex_a73",
        .llvm_name = "cortex-a73",
        .features = featureSet(&[_]Feature{
            .v8a,
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a75 = CpuModel{
        .name = "cortex_a75",
        .llvm_name = "cortex-a75",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .dotprod,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a76 = CpuModel{
        .name = "cortex_a76",
        .llvm_name = "cortex-a76",
        .features = featureSet(&[_]Feature{
            .a76,
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a76ae = CpuModel{
        .name = "cortex_a76ae",
        .llvm_name = "cortex-a76ae",
        .features = featureSet(&[_]Feature{
            .a76,
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a77 = CpuModel{
        .name = "cortex_a77",
        .llvm_name = "cortex-a77",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a78 = CpuModel{
        .name = "cortex_a78",
        .llvm_name = "cortex-a78",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cortex_a8 = CpuModel{
        .name = "cortex_a8",
        .llvm_name = "cortex-a8",
        .features = featureSet(&[_]Feature{
            .v7a,
            .nonpipelined_vfp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .trustzone,
            .vmlx_forwarding,
            .vmlx_hazards,
        }),
    };
    pub const cortex_a9 = CpuModel{
        .name = "cortex_a9",
        .llvm_name = "cortex-a9",
        .features = featureSet(&[_]Feature{
            .v7a,
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
    pub const cortex_m0 = CpuModel{
        .name = "cortex_m0",
        .llvm_name = "cortex-m0",
        .features = featureSet(&[_]Feature{
            .v6m,
        }),
    };
    pub const cortex_m0plus = CpuModel{
        .name = "cortex_m0plus",
        .llvm_name = "cortex-m0plus",
        .features = featureSet(&[_]Feature{
            .v6m,
        }),
    };
    pub const cortex_m1 = CpuModel{
        .name = "cortex_m1",
        .llvm_name = "cortex-m1",
        .features = featureSet(&[_]Feature{
            .v6m,
        }),
    };
    pub const cortex_m23 = CpuModel{
        .name = "cortex_m23",
        .llvm_name = "cortex-m23",
        .features = featureSet(&[_]Feature{
            .v8m,
            .no_movt,
        }),
    };
    pub const cortex_m3 = CpuModel{
        .name = "cortex_m3",
        .llvm_name = "cortex-m3",
        .features = featureSet(&[_]Feature{
            .v7m,
            .loop_align,
            .m3,
            .no_branch_predictor,
            .use_misched,
        }),
    };
    pub const cortex_m33 = CpuModel{
        .name = "cortex_m33",
        .llvm_name = "cortex-m33",
        .features = featureSet(&[_]Feature{
            .v8m_main,
            .dsp,
            .fp_armv8d16sp,
            .loop_align,
            .no_branch_predictor,
            .slowfpvfmx,
            .slowfpvmlx,
            .use_misched,
        }),
    };
    pub const cortex_m35p = CpuModel{
        .name = "cortex_m35p",
        .llvm_name = "cortex-m35p",
        .features = featureSet(&[_]Feature{
            .v8m_main,
            .dsp,
            .fp_armv8d16sp,
            .loop_align,
            .no_branch_predictor,
            .slowfpvfmx,
            .slowfpvmlx,
            .use_misched,
        }),
    };
    pub const cortex_m4 = CpuModel{
        .name = "cortex_m4",
        .llvm_name = "cortex-m4",
        .features = featureSet(&[_]Feature{
            .v7em,
            .loop_align,
            .no_branch_predictor,
            .slowfpvfmx,
            .slowfpvmlx,
            .use_misched,
            .vfp4d16sp,
        }),
    };
    pub const cortex_m55 = CpuModel{
        .name = "cortex_m55",
        .llvm_name = "cortex-m55",
        .features = featureSet(&[_]Feature{
            .v8_1m_main,
            .dsp,
            .fp_armv8d16,
            .loop_align,
            .mve_fp,
            .no_branch_predictor,
            .slowfpvmlx,
            .use_misched,
        }),
    };
    pub const cortex_m7 = CpuModel{
        .name = "cortex_m7",
        .llvm_name = "cortex-m7",
        .features = featureSet(&[_]Feature{
            .v7em,
            .fp_armv8d16,
        }),
    };
    pub const cortex_r4 = CpuModel{
        .name = "cortex_r4",
        .llvm_name = "cortex-r4",
        .features = featureSet(&[_]Feature{
            .v7r,
            .avoid_partial_cpsr,
            .r4,
            .ret_addr_stack,
        }),
    };
    pub const cortex_r4f = CpuModel{
        .name = "cortex_r4f",
        .llvm_name = "cortex-r4f",
        .features = featureSet(&[_]Feature{
            .v7r,
            .avoid_partial_cpsr,
            .r4,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r5 = CpuModel{
        .name = "cortex_r5",
        .llvm_name = "cortex-r5",
        .features = featureSet(&[_]Feature{
            .v7r,
            .avoid_partial_cpsr,
            .hwdiv_arm,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r52 = CpuModel{
        .name = "cortex_r52",
        .llvm_name = "cortex-r52",
        .features = featureSet(&[_]Feature{
            .v8r,
            .fpao,
            .use_misched,
        }),
    };
    pub const cortex_r7 = CpuModel{
        .name = "cortex_r7",
        .llvm_name = "cortex-r7",
        .features = featureSet(&[_]Feature{
            .v7r,
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv_arm,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_r8 = CpuModel{
        .name = "cortex_r8",
        .llvm_name = "cortex-r8",
        .features = featureSet(&[_]Feature{
            .v7r,
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv_arm,
            .mp,
            .ret_addr_stack,
            .slow_fp_brcc,
            .slowfpvfmx,
            .slowfpvmlx,
            .vfp3d16,
        }),
    };
    pub const cortex_x1 = CpuModel{
        .name = "cortex_x1",
        .llvm_name = "cortex-x1",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .fullfp16,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const cyclone = CpuModel{
        .name = "cyclone",
        .llvm_name = "cyclone",
        .features = featureSet(&[_]Feature{
            .v8a,
            .avoid_movs_shop,
            .avoid_partial_cpsr,
            .crypto,
            .disable_postra_scheduler,
            .hwdiv,
            .hwdiv_arm,
            .mp,
            .neonfp,
            .ret_addr_stack,
            .slowfpvfmx,
            .slowfpvmlx,
            .swift,
            .use_misched,
            .vfp4,
            .zcz,
        }),
    };
    pub const ep9312 = CpuModel{
        .name = "ep9312",
        .llvm_name = "ep9312",
        .features = featureSet(&[_]Feature{
            .v4t,
        }),
    };
    pub const exynos_m1 = CpuModel{
        .name = "exynos_m1",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{
            .v8a,
            .exynos,
        }),
    };
    pub const exynos_m2 = CpuModel{
        .name = "exynos_m2",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{
            .v8a,
            .exynos,
        }),
    };
    pub const exynos_m3 = CpuModel{
        .name = "exynos_m3",
        .llvm_name = "exynos-m3",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .exynos,
        }),
    };
    pub const exynos_m4 = CpuModel{
        .name = "exynos_m4",
        .llvm_name = "exynos-m4",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .dotprod,
            .exynos,
            .fullfp16,
        }),
    };
    pub const exynos_m5 = CpuModel{
        .name = "exynos_m5",
        .llvm_name = "exynos-m5",
        .features = featureSet(&[_]Feature{
            .dotprod,
            .exynos,
            .fullfp16,
            .v8_2a,
        }),
    };
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{}),
    };
    pub const iwmmxt = CpuModel{
        .name = "iwmmxt",
        .llvm_name = "iwmmxt",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
    pub const krait = CpuModel{
        .name = "krait",
        .llvm_name = "krait",
        .features = featureSet(&[_]Feature{
            .avoid_partial_cpsr,
            .fp16,
            .hwdiv,
            .hwdiv_arm,
            .muxed_units,
            .ret_addr_stack,
            .v7a,
            .vfp4,
            .vldn_align,
            .vmlx_forwarding,
        }),
    };
    pub const kryo = CpuModel{
        .name = "kryo",
        .llvm_name = "kryo",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .hwdiv,
            .hwdiv_arm,
            .v8a,
        }),
    };
    pub const mpcore = CpuModel{
        .name = "mpcore",
        .llvm_name = "mpcore",
        .features = featureSet(&[_]Feature{
            .v6k,
            .slowfpvmlx,
            .vfp2,
        }),
    };
    pub const mpcorenovfp = CpuModel{
        .name = "mpcorenovfp",
        .llvm_name = "mpcorenovfp",
        .features = featureSet(&[_]Feature{
            .v6k,
        }),
    };
    pub const neoverse_n1 = CpuModel{
        .name = "neoverse_n1",
        .llvm_name = "neoverse-n1",
        .features = featureSet(&[_]Feature{
            .v8_2a,
            .crc,
            .crypto,
            .dotprod,
            .hwdiv,
            .hwdiv_arm,
        }),
    };
    pub const sc000 = CpuModel{
        .name = "sc000",
        .llvm_name = "sc000",
        .features = featureSet(&[_]Feature{
            .v6m,
        }),
    };
    pub const sc300 = CpuModel{
        .name = "sc300",
        .llvm_name = "sc300",
        .features = featureSet(&[_]Feature{
            .v7m,
            .m3,
            .no_branch_predictor,
            .use_misched,
        }),
    };
    pub const strongarm = CpuModel{
        .name = "strongarm",
        .llvm_name = "strongarm",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const strongarm110 = CpuModel{
        .name = "strongarm110",
        .llvm_name = "strongarm110",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const strongarm1100 = CpuModel{
        .name = "strongarm1100",
        .llvm_name = "strongarm1100",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const strongarm1110 = CpuModel{
        .name = "strongarm1110",
        .llvm_name = "strongarm1110",
        .features = featureSet(&[_]Feature{
            .v4,
        }),
    };
    pub const swift = CpuModel{
        .name = "swift",
        .llvm_name = "swift",
        .features = featureSet(&[_]Feature{
            .v7a,
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
            .slowfpvfmx,
            .slowfpvmlx,
            .swift,
            .use_misched,
            .vfp4,
            .vmlx_hazards,
            .wide_stride_vfp,
        }),
    };
    pub const xscale = CpuModel{
        .name = "xscale",
        .llvm_name = "xscale",
        .features = featureSet(&[_]Feature{
            .v5te,
        }),
    };
};
