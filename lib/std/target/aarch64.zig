// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const CpuFeature = std.Target.Cpu.Feature;
const CpuModel = std.Target.Cpu.Model;

pub const Feature = enum {
    a34,
    a65,
    a76,
    aes,
    aggressive_fma,
    alternate_sextload_cvt_f32_pattern,
    altnzcv,
    am,
    amvs,
    apple_a10,
    apple_a11,
    apple_a12,
    apple_a13,
    apple_a7,
    arith_bcc_fusion,
    arith_cbz_fusion,
    balance_fp_ops,
    bf16,
    bti,
    call_saved_x10,
    call_saved_x11,
    call_saved_x12,
    call_saved_x13,
    call_saved_x14,
    call_saved_x15,
    call_saved_x18,
    call_saved_x8,
    call_saved_x9,
    ccdp,
    ccidx,
    ccpp,
    complxnum,
    crc,
    crypto,
    custom_cheap_as_move,
    disable_latency_sched_heuristic,
    dit,
    dotprod,
    ecv,
    ete,
    exynos_cheap_as_move,
    exynosm4,
    f32mm,
    f64mm,
    fgt,
    fmi,
    force_32bit_jump_tables,
    fp_armv8,
    fp16fml,
    fptoint,
    fullfp16,
    fuse_address,
    fuse_aes,
    fuse_arith_logic,
    fuse_crypto_eor,
    fuse_csel,
    fuse_literals,
    harden_sls_blr,
    harden_sls_retbr,
    i8mm,
    jsconv,
    lor,
    lse,
    lsl_fast,
    mpam,
    mte,
    neon,
    neoversee1,
    neoversen1,
    no_neg_immediates,
    nv,
    pa,
    pan,
    pan_rwv,
    perfmon,
    pmu,
    predictable_select_expensive,
    predres,
    rand,
    ras,
    rasv8_4,
    rcpc,
    rcpc_immo,
    rdm,
    reserve_x1,
    reserve_x10,
    reserve_x11,
    reserve_x12,
    reserve_x13,
    reserve_x14,
    reserve_x15,
    reserve_x18,
    reserve_x2,
    reserve_x20,
    reserve_x21,
    reserve_x22,
    reserve_x23,
    reserve_x24,
    reserve_x25,
    reserve_x26,
    reserve_x27,
    reserve_x28,
    reserve_x3,
    reserve_x30,
    reserve_x4,
    reserve_x5,
    reserve_x6,
    reserve_x7,
    reserve_x9,
    sb,
    sel2,
    sha2,
    sha3,
    slow_misaligned_128store,
    slow_paired_128,
    slow_strqro_store,
    sm4,
    spe,
    specrestrict,
    ssbs,
    strict_align,
    sve,
    sve2,
    sve2_aes,
    sve2_bitperm,
    sve2_sha3,
    sve2_sm4,
    tagged_globals,
    tlb_rmi,
    tme,
    tpidr_el1,
    tpidr_el2,
    tpidr_el3,
    tracev8_4,
    trbe,
    uaops,
    use_aa,
    use_experimental_zeroing_pseudos,
    use_postra_scheduler,
    use_reciprocal_square_root,
    v8a,
    v8_1a,
    v8_2a,
    v8_3a,
    v8_4a,
    v8_5a,
    v8_6a,
    vh,
    zcm,
    zcz,
    zcz_fp,
    zcz_fp_workaround,
    zcz_gp,
};

pub usingnamespace CpuFeature.feature_set_fns(Feature);

pub const all_features = blk: {
    @setEvalBranchQuota(2000);
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= CpuFeature.Set.needed_bit_count);
    var result: [len]CpuFeature = undefined;
    result[@enumToInt(Feature.a34)] = .{
        .llvm_name = "a35",
        .description = "Cortex-A34 ARM processors",
        .dependencies = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .perfmon,
            .v8a,
        }),
    };
    result[@enumToInt(Feature.a65)] = .{
        .llvm_name = "a65",
        .description = "Cortex-A65 ARM processors",
        .dependencies = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .neon,
            .ras,
            .rcpc,
            .ssbs,
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.a76)] = .{
        .llvm_name = "a76",
        .description = "Cortex-A76 ARM processors",
        .dependencies = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fullfp16,
            .rcpc,
            .ssbs,
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.aes)] = .{
        .llvm_name = "aes",
        .description = "Enable AES support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.aggressive_fma)] = .{
        .llvm_name = "aggressive-fma",
        .description = "Enable Aggressive FMA for floating-point.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.alternate_sextload_cvt_f32_pattern)] = .{
        .llvm_name = "alternate-sextload-cvt-f32-pattern",
        .description = "Use alternative pattern for sextload convert to f32",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.altnzcv)] = .{
        .llvm_name = "altnzcv",
        .description = "Enable alternative NZCV format for floating point comparisons",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.am)] = .{
        .llvm_name = "am",
        .description = "Enable v8.4-A Activity Monitors extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.amvs)] = .{
        .llvm_name = "amvs",
        .description = "Enable v8.6-A Activity Monitors Virtualization support",
        .dependencies = featureSet(&[_]Feature{
            .am,
        }),
    };
    result[@enumToInt(Feature.apple_a10)] = .{
        .llvm_name = "apple-a10",
        .description = "Apple A10",
        .dependencies = featureSet(&[_]Feature{
            .alternate_sextload_cvt_f32_pattern,
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crc,
            .crypto,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .fuse_aes,
            .fuse_crypto_eor,
            .lor,
            .neon,
            .pan,
            .perfmon,
            .rdm,
            .vh,
            .zcm,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.apple_a11)] = .{
        .llvm_name = "apple-a11",
        .description = "Apple A11",
        .dependencies = featureSet(&[_]Feature{
            .alternate_sextload_cvt_f32_pattern,
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crypto,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .fullfp16,
            .fuse_aes,
            .fuse_crypto_eor,
            .neon,
            .perfmon,
            .v8_2a,
            .zcm,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.apple_a12)] = .{
        .llvm_name = "apple-a12",
        .description = "Apple A12",
        .dependencies = featureSet(&[_]Feature{
            .alternate_sextload_cvt_f32_pattern,
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crypto,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .fullfp16,
            .fuse_aes,
            .fuse_crypto_eor,
            .neon,
            .perfmon,
            .v8_3a,
            .zcm,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.apple_a13)] = .{
        .llvm_name = "apple-a13",
        .description = "Apple A13",
        .dependencies = featureSet(&[_]Feature{
            .alternate_sextload_cvt_f32_pattern,
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crypto,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .fp16fml,
            .fullfp16,
            .fuse_aes,
            .fuse_crypto_eor,
            .neon,
            .perfmon,
            .sha3,
            .v8_4a,
            .zcm,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.apple_a7)] = .{
        .llvm_name = "apple-a7",
        .description = "Apple A7 (the CPU formerly known as Cyclone)",
        .dependencies = featureSet(&[_]Feature{
            .alternate_sextload_cvt_f32_pattern,
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crypto,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .fuse_aes,
            .fuse_crypto_eor,
            .neon,
            .perfmon,
            .zcm,
            .zcz,
            .zcz_fp_workaround,
        }),
    };
    result[@enumToInt(Feature.arith_bcc_fusion)] = .{
        .llvm_name = "arith-bcc-fusion",
        .description = "CPU fuses arithmetic+bcc operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.arith_cbz_fusion)] = .{
        .llvm_name = "arith-cbz-fusion",
        .description = "CPU fuses arithmetic + cbz/cbnz operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.balance_fp_ops)] = .{
        .llvm_name = "balance-fp-ops",
        .description = "balance mix of odd and even D-registers for fp multiply(-accumulate) ops",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.bf16)] = .{
        .llvm_name = "bf16",
        .description = "Enable BFloat16 Extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.bti)] = .{
        .llvm_name = "bti",
        .description = "Enable Branch Target Identification",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x10)] = .{
        .llvm_name = "call-saved-x10",
        .description = "Make X10 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x11)] = .{
        .llvm_name = "call-saved-x11",
        .description = "Make X11 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x12)] = .{
        .llvm_name = "call-saved-x12",
        .description = "Make X12 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x13)] = .{
        .llvm_name = "call-saved-x13",
        .description = "Make X13 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x14)] = .{
        .llvm_name = "call-saved-x14",
        .description = "Make X14 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x15)] = .{
        .llvm_name = "call-saved-x15",
        .description = "Make X15 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x18)] = .{
        .llvm_name = "call-saved-x18",
        .description = "Make X18 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x8)] = .{
        .llvm_name = "call-saved-x8",
        .description = "Make X8 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.call_saved_x9)] = .{
        .llvm_name = "call-saved-x9",
        .description = "Make X9 callee saved.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ccdp)] = .{
        .llvm_name = "ccdp",
        .description = "Enable v8.5 Cache Clean to Point of Deep Persistence",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ccidx)] = .{
        .llvm_name = "ccidx",
        .description = "Enable v8.3-A Extend of the CCSIDR number of sets",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ccpp)] = .{
        .llvm_name = "ccpp",
        .description = "Enable v8.2 data Cache Clean to Point of Persistence",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.complxnum)] = .{
        .llvm_name = "complxnum",
        .description = "Enable v8.3-A Floating-point complex number support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.crc)] = .{
        .llvm_name = "crc",
        .description = "Enable ARMv8 CRC-32 checksum instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.crypto)] = .{
        .llvm_name = "crypto",
        .description = "Enable cryptographic instructions",
        .dependencies = featureSet(&[_]Feature{
            .aes,
            .neon,
            .sha2,
        }),
    };
    result[@enumToInt(Feature.custom_cheap_as_move)] = .{
        .llvm_name = "custom-cheap-as-move",
        .description = "Use custom handling of cheap instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.disable_latency_sched_heuristic)] = .{
        .llvm_name = "disable-latency-sched-heuristic",
        .description = "Disable latency scheduling heuristic",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dit)] = .{
        .llvm_name = "dit",
        .description = "Enable v8.4-A Data Independent Timing instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.dotprod)] = .{
        .llvm_name = "dotprod",
        .description = "Enable dot product support",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ecv)] = .{
        .llvm_name = "ecv",
        .description = "Enable enhanced counter virtualization extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ete)] = .{
        .llvm_name = "ete",
        .description = "Enable Embedded Trace Extension",
        .dependencies = featureSet(&[_]Feature{
            .trbe,
        }),
    };
    result[@enumToInt(Feature.exynos_cheap_as_move)] = .{
        .llvm_name = "exynos-cheap-as-move",
        .description = "Use Exynos specific handling of cheap instructions",
        .dependencies = featureSet(&[_]Feature{
            .custom_cheap_as_move,
        }),
    };
    result[@enumToInt(Feature.exynosm4)] = .{
        .llvm_name = "exynosm4",
        .description = "Samsung Exynos-M4 processors",
        .dependencies = featureSet(&[_]Feature{
            .arith_bcc_fusion,
            .arith_cbz_fusion,
            .crypto,
            .dotprod,
            .exynos_cheap_as_move,
            .force_32bit_jump_tables,
            .fullfp16,
            .fuse_address,
            .fuse_aes,
            .fuse_arith_logic,
            .fuse_csel,
            .fuse_literals,
            .lsl_fast,
            .perfmon,
            .use_postra_scheduler,
            .v8_2a,
            .zcz,
        }),
    };
    result[@enumToInt(Feature.f32mm)] = .{
        .llvm_name = "f32mm",
        .description = "Enable Matrix Multiply FP32 Extension",
        .dependencies = featureSet(&[_]Feature{
            .sve,
        }),
    };
    result[@enumToInt(Feature.f64mm)] = .{
        .llvm_name = "f64mm",
        .description = "Enable Matrix Multiply FP64 Extension",
        .dependencies = featureSet(&[_]Feature{
            .sve,
        }),
    };
    result[@enumToInt(Feature.fgt)] = .{
        .llvm_name = "fgt",
        .description = "Enable fine grained virtualization traps extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fmi)] = .{
        .llvm_name = "fmi",
        .description = "Enable v8.4-A Flag Manipulation Instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.force_32bit_jump_tables)] = .{
        .llvm_name = "force-32bit-jump-tables",
        .description = "Force jump table entries to be 32-bits wide except at MinSize",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp_armv8)] = .{
        .llvm_name = "fp-armv8",
        .description = "Enable ARMv8 FP",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fp16fml)] = .{
        .llvm_name = "fp16fml",
        .description = "Enable FP16 FML instructions",
        .dependencies = featureSet(&[_]Feature{
            .fullfp16,
        }),
    };
    result[@enumToInt(Feature.fptoint)] = .{
        .llvm_name = "fptoint",
        .description = "Enable FRInt[32|64][Z|X] instructions that round a floating-point number to an integer (in FP format) forcing it to fit into a 32- or 64-bit int",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fullfp16)] = .{
        .llvm_name = "fullfp16",
        .description = "Full FP16",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.fuse_address)] = .{
        .llvm_name = "fuse-address",
        .description = "CPU fuses address generation and memory operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_aes)] = .{
        .llvm_name = "fuse-aes",
        .description = "CPU fuses AES crypto operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_arith_logic)] = .{
        .llvm_name = "fuse-arith-logic",
        .description = "CPU fuses arithmetic and logic operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_crypto_eor)] = .{
        .llvm_name = "fuse-crypto-eor",
        .description = "CPU fuses AES/PMULL and EOR operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_csel)] = .{
        .llvm_name = "fuse-csel",
        .description = "CPU fuses conditional select operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.fuse_literals)] = .{
        .llvm_name = "fuse-literals",
        .description = "CPU fuses literal generation operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.harden_sls_blr)] = .{
        .llvm_name = "harden-sls-blr",
        .description = "Harden against straight line speculation across BLR instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.harden_sls_retbr)] = .{
        .llvm_name = "harden-sls-retbr",
        .description = "Harden against straight line speculation across RET and BR instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.i8mm)] = .{
        .llvm_name = "i8mm",
        .description = "Enable Matrix Multiply Int8 Extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.jsconv)] = .{
        .llvm_name = "jsconv",
        .description = "Enable v8.3-A JavaScript FP conversion instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.lor)] = .{
        .llvm_name = "lor",
        .description = "Enables ARM v8.1 Limited Ordering Regions extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lse)] = .{
        .llvm_name = "lse",
        .description = "Enable ARMv8.1 Large System Extension (LSE) atomic instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.lsl_fast)] = .{
        .llvm_name = "lsl-fast",
        .description = "CPU has a fastpath logical shift of up to 3 places",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mpam)] = .{
        .llvm_name = "mpam",
        .description = "Enable v8.4-A Memory system Partitioning and Monitoring extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.mte)] = .{
        .llvm_name = "mte",
        .description = "Enable Memory Tagging Extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.neon)] = .{
        .llvm_name = "neon",
        .description = "Enable Advanced SIMD instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.neoversee1)] = .{
        .llvm_name = "neoversee1",
        .description = "Neoverse E1 ARM processors",
        .dependencies = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .neon,
            .rcpc,
            .ssbs,
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.neoversen1)] = .{
        .llvm_name = "neoversen1",
        .description = "Neoverse N1 ARM processors",
        .dependencies = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .neon,
            .rcpc,
            .spe,
            .ssbs,
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.no_neg_immediates)] = .{
        .llvm_name = "no-neg-immediates",
        .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.nv)] = .{
        .llvm_name = "nv",
        .description = "Enable v8.4-A Nested Virtualization extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.pa)] = .{
        .llvm_name = "pa",
        .description = "Enable v8.3-A Pointer Authentication extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.pan)] = .{
        .llvm_name = "pan",
        .description = "Enables ARM v8.1 Privileged Access-Never extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.pan_rwv)] = .{
        .llvm_name = "pan-rwv",
        .description = "Enable v8.2 PAN s1e1R and s1e1W Variants",
        .dependencies = featureSet(&[_]Feature{
            .pan,
        }),
    };
    result[@enumToInt(Feature.perfmon)] = .{
        .llvm_name = "perfmon",
        .description = "Enable ARMv8 PMUv3 Performance Monitors extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.pmu)] = .{
        .llvm_name = "pmu",
        .description = "Enable v8.4-A PMU extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.predictable_select_expensive)] = .{
        .llvm_name = "predictable-select-expensive",
        .description = "Prefer likely predicted branches over selects",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.predres)] = .{
        .llvm_name = "predres",
        .description = "Enable v8.5a execution and data prediction invalidation instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.rand)] = .{
        .llvm_name = "rand",
        .description = "Enable Random Number generation instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ras)] = .{
        .llvm_name = "ras",
        .description = "Enable ARMv8 Reliability, Availability and Serviceability Extensions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.rasv8_4)] = .{
        .llvm_name = "rasv8_4",
        .description = "Enable v8.4-A Reliability, Availability and Serviceability extension",
        .dependencies = featureSet(&[_]Feature{
            .ras,
        }),
    };
    result[@enumToInt(Feature.rcpc)] = .{
        .llvm_name = "rcpc",
        .description = "Enable support for RCPC extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.rcpc_immo)] = .{
        .llvm_name = "rcpc-immo",
        .description = "Enable v8.4-A RCPC instructions with Immediate Offsets",
        .dependencies = featureSet(&[_]Feature{
            .rcpc,
        }),
    };
    result[@enumToInt(Feature.rdm)] = .{
        .llvm_name = "rdm",
        .description = "Enable ARMv8.1 Rounding Double Multiply Add/Subtract instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x1)] = .{
        .llvm_name = "reserve-x1",
        .description = "Reserve X1, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x10)] = .{
        .llvm_name = "reserve-x10",
        .description = "Reserve X10, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x11)] = .{
        .llvm_name = "reserve-x11",
        .description = "Reserve X11, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x12)] = .{
        .llvm_name = "reserve-x12",
        .description = "Reserve X12, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x13)] = .{
        .llvm_name = "reserve-x13",
        .description = "Reserve X13, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x14)] = .{
        .llvm_name = "reserve-x14",
        .description = "Reserve X14, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x15)] = .{
        .llvm_name = "reserve-x15",
        .description = "Reserve X15, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x18)] = .{
        .llvm_name = "reserve-x18",
        .description = "Reserve X18, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x2)] = .{
        .llvm_name = "reserve-x2",
        .description = "Reserve X2, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x20)] = .{
        .llvm_name = "reserve-x20",
        .description = "Reserve X20, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x21)] = .{
        .llvm_name = "reserve-x21",
        .description = "Reserve X21, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x22)] = .{
        .llvm_name = "reserve-x22",
        .description = "Reserve X22, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x23)] = .{
        .llvm_name = "reserve-x23",
        .description = "Reserve X23, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x24)] = .{
        .llvm_name = "reserve-x24",
        .description = "Reserve X24, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x25)] = .{
        .llvm_name = "reserve-x25",
        .description = "Reserve X25, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x26)] = .{
        .llvm_name = "reserve-x26",
        .description = "Reserve X26, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x27)] = .{
        .llvm_name = "reserve-x27",
        .description = "Reserve X27, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x28)] = .{
        .llvm_name = "reserve-x28",
        .description = "Reserve X28, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x3)] = .{
        .llvm_name = "reserve-x3",
        .description = "Reserve X3, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x30)] = .{
        .llvm_name = "reserve-x30",
        .description = "Reserve X30, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x4)] = .{
        .llvm_name = "reserve-x4",
        .description = "Reserve X4, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x5)] = .{
        .llvm_name = "reserve-x5",
        .description = "Reserve X5, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x6)] = .{
        .llvm_name = "reserve-x6",
        .description = "Reserve X6, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x7)] = .{
        .llvm_name = "reserve-x7",
        .description = "Reserve X7, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.reserve_x9)] = .{
        .llvm_name = "reserve-x9",
        .description = "Reserve X9, making it unavailable as a GPR",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sb)] = .{
        .llvm_name = "sb",
        .description = "Enable v8.5 Speculation Barrier",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sel2)] = .{
        .llvm_name = "sel2",
        .description = "Enable v8.4-A Secure Exception Level 2 extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sha2)] = .{
        .llvm_name = "sha2",
        .description = "Enable SHA1 and SHA256 support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.sha3)] = .{
        .llvm_name = "sha3",
        .description = "Enable SHA512 and SHA3 support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
            .sha2,
        }),
    };
    result[@enumToInt(Feature.slow_misaligned_128store)] = .{
        .llvm_name = "slow-misaligned-128store",
        .description = "Misaligned 128 bit stores are slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_paired_128)] = .{
        .llvm_name = "slow-paired-128",
        .description = "Paired 128 bit loads and stores are slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.slow_strqro_store)] = .{
        .llvm_name = "slow-strqro-store",
        .description = "STR of Q register with register offset is slow",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sm4)] = .{
        .llvm_name = "sm4",
        .description = "Enable SM3 and SM4 support",
        .dependencies = featureSet(&[_]Feature{
            .neon,
        }),
    };
    result[@enumToInt(Feature.spe)] = .{
        .llvm_name = "spe",
        .description = "Enable Statistical Profiling extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.specrestrict)] = .{
        .llvm_name = "specrestrict",
        .description = "Enable architectural speculation restriction",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.ssbs)] = .{
        .llvm_name = "ssbs",
        .description = "Enable Speculative Store Bypass Safe bit",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.strict_align)] = .{
        .llvm_name = "strict-align",
        .description = "Disallow all unaligned memory access",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sve)] = .{
        .llvm_name = "sve",
        .description = "Enable Scalable Vector Extension (SVE) instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.sve2)] = .{
        .llvm_name = "sve2",
        .description = "Enable Scalable Vector Extension 2 (SVE2) instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
        }),
    };
    result[@enumToInt(Feature.sve2_aes)] = .{
        .llvm_name = "sve2-aes",
        .description = "Enable AES SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .aes,
            .sve2,
        }),
    };
    result[@enumToInt(Feature.sve2_bitperm)] = .{
        .llvm_name = "sve2-bitperm",
        .description = "Enable bit permutation SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve2,
        }),
    };
    result[@enumToInt(Feature.sve2_sha3)] = .{
        .llvm_name = "sve2-sha3",
        .description = "Enable SHA3 SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sha3,
            .sve2,
        }),
    };
    result[@enumToInt(Feature.sve2_sm4)] = .{
        .llvm_name = "sve2-sm4",
        .description = "Enable SM4 SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sm4,
            .sve2,
        }),
    };
    result[@enumToInt(Feature.tagged_globals)] = .{
        .llvm_name = "tagged-globals",
        .description = "Use an instruction sequence for taking the address of a global that allows a memory tag in the upper address bits",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tlb_rmi)] = .{
        .llvm_name = "tlb-rmi",
        .description = "Enable v8.4-A TLB Range and Maintenance Instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tme)] = .{
        .llvm_name = "tme",
        .description = "Enable Transactional Memory Extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tpidr_el1)] = .{
        .llvm_name = "tpidr-el1",
        .description = "Permit use of TPIDR_EL1 for the TLS base",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tpidr_el2)] = .{
        .llvm_name = "tpidr-el2",
        .description = "Permit use of TPIDR_EL2 for the TLS base",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tpidr_el3)] = .{
        .llvm_name = "tpidr-el3",
        .description = "Permit use of TPIDR_EL3 for the TLS base",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.tracev8_4)] = .{
        .llvm_name = "tracev8.4",
        .description = "Enable v8.4-A Trace extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.trbe)] = .{
        .llvm_name = "trbe",
        .description = "Enable Trace Buffer Extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.uaops)] = .{
        .llvm_name = "uaops",
        .description = "Enable v8.2 UAO PState",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_aa)] = .{
        .llvm_name = "use-aa",
        .description = "Use alias analysis during codegen",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_experimental_zeroing_pseudos)] = .{
        .llvm_name = "use-experimental-zeroing-pseudos",
        .description = "Hint to the compiler that the MOVPRFX instruction is merged with destructive operations",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_postra_scheduler)] = .{
        .llvm_name = "use-postra-scheduler",
        .description = "Schedule again after register allocation",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.use_reciprocal_square_root)] = .{
        .llvm_name = "use-reciprocal-square-root",
        .description = "Use the reciprocal square root approximation",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.v8a)] = .{
        .llvm_name = null,
        .description = "Support ARM v8a instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
            .neon,
        }),
    };
    result[@enumToInt(Feature.v8_1a)] = .{
        .llvm_name = "v8.1a",
        .description = "Support ARM v8.1a instructions",
        .dependencies = featureSet(&[_]Feature{
            .crc,
            .lor,
            .lse,
            .pan,
            .rdm,
            .vh,
            .v8a,
        }),
    };
    result[@enumToInt(Feature.v8_2a)] = .{
        .llvm_name = "v8.2a",
        .description = "Support ARM v8.2a instructions",
        .dependencies = featureSet(&[_]Feature{
            .ccpp,
            .pan_rwv,
            .ras,
            .uaops,
            .v8_1a,
        }),
    };
    result[@enumToInt(Feature.v8_3a)] = .{
        .llvm_name = "v8.3a",
        .description = "Support ARM v8.3a instructions",
        .dependencies = featureSet(&[_]Feature{
            .ccidx,
            .complxnum,
            .jsconv,
            .pa,
            .rcpc,
            .v8_2a,
        }),
    };
    result[@enumToInt(Feature.v8_4a)] = .{
        .llvm_name = "v8.4a",
        .description = "Support ARM v8.4a instructions",
        .dependencies = featureSet(&[_]Feature{
            .am,
            .dit,
            .dotprod,
            .fmi,
            .mpam,
            .nv,
            .pmu,
            .rasv8_4,
            .rcpc_immo,
            .sel2,
            .tlb_rmi,
            .tracev8_4,
            .v8_3a,
        }),
    };
    result[@enumToInt(Feature.v8_5a)] = .{
        .llvm_name = "v8.5a",
        .description = "Support ARM v8.5a instructions",
        .dependencies = featureSet(&[_]Feature{
            .altnzcv,
            .bti,
            .ccdp,
            .fptoint,
            .predres,
            .sb,
            .specrestrict,
            .ssbs,
            .v8_4a,
        }),
    };
    result[@enumToInt(Feature.v8_6a)] = .{
        .llvm_name = "v8.6a",
        .description = "Support ARM v8.6a instructions",
        .dependencies = featureSet(&[_]Feature{
            .amvs,
            .bf16,
            .ecv,
            .fgt,
            .i8mm,
            .v8_5a,
        }),
    };
    result[@enumToInt(Feature.vh)] = .{
        .llvm_name = "vh",
        .description = "Enables ARM v8.1 Virtual Host extension",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.zcm)] = .{
        .llvm_name = "zcm",
        .description = "Has zero-cycle register moves",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.zcz)] = .{
        .llvm_name = "zcz",
        .description = "Has zero-cycle zeroing instructions",
        .dependencies = featureSet(&[_]Feature{
            .zcz_fp,
            .zcz_gp,
        }),
    };
    result[@enumToInt(Feature.zcz_fp)] = .{
        .llvm_name = "zcz-fp",
        .description = "Has zero-cycle zeroing instructions for FP registers",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.zcz_fp_workaround)] = .{
        .llvm_name = "zcz-fp-workaround",
        .description = "The zero-cycle floating-point zeroing instruction has a bug",
        .dependencies = featureSet(&[_]Feature{}),
    };
    result[@enumToInt(Feature.zcz_gp)] = .{
        .llvm_name = "zcz-gp",
        .description = "Has zero-cycle zeroing instructions for generic registers",
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
    pub const a64fx = CpuModel{
        .name = "a64fx",
        .llvm_name = "a64fx",
        .features = featureSet(&[_]Feature{
            .complxnum,
            .fp_armv8,
            .fullfp16,
            .neon,
            .perfmon,
            .sha2,
            .sve,
            .use_postra_scheduler,
            .v8_2a,
        }),
    };
    pub const apple_a10 = CpuModel{
        .name = "apple_a10",
        .llvm_name = "apple-a10",
        .features = featureSet(&[_]Feature{
            .apple_a10,
        }),
    };
    pub const apple_a11 = CpuModel{
        .name = "apple_a11",
        .llvm_name = "apple-a11",
        .features = featureSet(&[_]Feature{
            .apple_a11,
        }),
    };
    pub const apple_a12 = CpuModel{
        .name = "apple_a12",
        .llvm_name = "apple-a12",
        .features = featureSet(&[_]Feature{
            .apple_a12,
        }),
    };
    pub const apple_a13 = CpuModel{
        .name = "apple_a13",
        .llvm_name = "apple-a13",
        .features = featureSet(&[_]Feature{
            .apple_a13,
        }),
    };
    pub const apple_a7 = CpuModel{
        .name = "apple_a7",
        .llvm_name = "apple-a7",
        .features = featureSet(&[_]Feature{
            .apple_a7,
        }),
    };
    pub const apple_a8 = CpuModel{
        .name = "apple_a8",
        .llvm_name = "apple-a8",
        .features = featureSet(&[_]Feature{
            .apple_a7,
        }),
    };
    pub const apple_a9 = CpuModel{
        .name = "apple_a9",
        .llvm_name = "apple-a9",
        .features = featureSet(&[_]Feature{
            .apple_a7,
        }),
    };
    pub const apple_latest = CpuModel{
        .name = "apple_latest",
        .llvm_name = "apple-latest",
        .features = featureSet(&[_]Feature{
            .apple_a13,
        }),
    };
    pub const apple_s4 = CpuModel{
        .name = "apple_s4",
        .llvm_name = "apple-s4",
        .features = featureSet(&[_]Feature{
            .apple_a12,
        }),
    };
    pub const apple_s5 = CpuModel{
        .name = "apple_s5",
        .llvm_name = "apple-s5",
        .features = featureSet(&[_]Feature{
            .apple_a12,
        }),
    };
    pub const carmel = CpuModel{
        .name = "carmel",
        .llvm_name = "carmel",
        .features = featureSet(&[_]Feature{
            .crypto,
            .fullfp16,
            .neon,
            .v8_2a,
        }),
    };
    pub const cortex_a34 = CpuModel{
        .name = "cortex_a34",
        .llvm_name = "cortex-a34",
        .features = featureSet(&[_]Feature{
            .a34,
        }),
    };
    pub const cortex_a35 = CpuModel{
        .name = "cortex_a35",
        .llvm_name = "cortex-a35",
        .features = featureSet(&[_]Feature{
            .a34,
        }),
    };
    pub const cortex_a53 = CpuModel{
        .name = "cortex_a53",
        .llvm_name = "cortex-a53",
        .features = featureSet(&[_]Feature{
            .balance_fp_ops,
            .crc,
            .crypto,
            .custom_cheap_as_move,
            .fuse_aes,
            .perfmon,
            .use_aa,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const cortex_a55 = CpuModel{
        .name = "cortex_a55",
        .llvm_name = "cortex-a55",
        .features = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fullfp16,
            .fuse_aes,
            .perfmon,
            .rcpc,
            .v8_2a,
        }),
    };
    pub const cortex_a57 = CpuModel{
        .name = "cortex_a57",
        .llvm_name = "cortex-a57",
        .features = featureSet(&[_]Feature{
            .balance_fp_ops,
            .crc,
            .crypto,
            .custom_cheap_as_move,
            .fuse_aes,
            .fuse_literals,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const cortex_a65 = CpuModel{
        .name = "cortex_a65",
        .llvm_name = "cortex-a65",
        .features = featureSet(&[_]Feature{
            .a65,
        }),
    };
    pub const cortex_a65ae = CpuModel{
        .name = "cortex_a65ae",
        .llvm_name = "cortex-a65ae",
        .features = featureSet(&[_]Feature{
            .a65,
        }),
    };
    pub const cortex_a72 = CpuModel{
        .name = "cortex_a72",
        .llvm_name = "cortex-a72",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .fuse_aes,
            .perfmon,
            .v8a,
        }),
    };
    pub const cortex_a73 = CpuModel{
        .name = "cortex_a73",
        .llvm_name = "cortex-a73",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .fuse_aes,
            .perfmon,
            .v8a,
        }),
    };
    pub const cortex_a75 = CpuModel{
        .name = "cortex_a75",
        .llvm_name = "cortex-a75",
        .features = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fullfp16,
            .fuse_aes,
            .perfmon,
            .rcpc,
            .v8_2a,
        }),
    };
    pub const cortex_a76 = CpuModel{
        .name = "cortex_a76",
        .llvm_name = "cortex-a76",
        .features = featureSet(&[_]Feature{
            .a76,
        }),
    };
    pub const cortex_a76ae = CpuModel{
        .name = "cortex_a76ae",
        .llvm_name = "cortex-a76ae",
        .features = featureSet(&[_]Feature{
            .a76,
        }),
    };
    pub const cortex_a77 = CpuModel{
        .name = "cortex_a77",
        .llvm_name = "cortex-a77",
        .features = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .neon,
            .rcpc,
            .v8_2a,
        }),
    };
    pub const cortex_a78 = CpuModel{
        .name = "cortex_a78",
        .llvm_name = "cortex-a78",
        .features = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .fuse_aes,
            .neon,
            .perfmon,
            .rcpc,
            .spe,
            .ssbs,
            .use_postra_scheduler,
            .v8_2a,
        }),
    };
    pub const cortex_x1 = CpuModel{
        .name = "cortex_x1",
        .llvm_name = "cortex-x1",
        .features = featureSet(&[_]Feature{
            .crypto,
            .dotprod,
            .fp_armv8,
            .fullfp16,
            .fuse_aes,
            .neon,
            .perfmon,
            .rcpc,
            .spe,
            .use_postra_scheduler,
            .v8_2a,
        }),
    };
    pub const cyclone = CpuModel{
        .name = "cyclone",
        .llvm_name = "cyclone",
        .features = featureSet(&[_]Feature{
            .apple_a7,
        }),
    };
    pub const exynos_m1 = CpuModel{
        .name = "exynos_m1",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .exynos_cheap_as_move,
            .force_32bit_jump_tables,
            .fuse_aes,
            .perfmon,
            .slow_misaligned_128store,
            .slow_paired_128,
            .use_postra_scheduler,
            .use_reciprocal_square_root,
            .v8a,
            .zcz_fp,
        }),
    };
    pub const exynos_m2 = CpuModel{
        .name = "exynos_m2",
        .llvm_name = null,
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .exynos_cheap_as_move,
            .force_32bit_jump_tables,
            .fuse_aes,
            .perfmon,
            .slow_misaligned_128store,
            .slow_paired_128,
            .use_postra_scheduler,
            .v8a,
            .zcz_fp,
        }),
    };
    pub const exynos_m3 = CpuModel{
        .name = "exynos_m3",
        .llvm_name = "exynos-m3",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .exynos_cheap_as_move,
            .force_32bit_jump_tables,
            .fuse_address,
            .fuse_aes,
            .fuse_csel,
            .fuse_literals,
            .lsl_fast,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
            .zcz_fp,
        }),
    };
    pub const exynos_m4 = CpuModel{
        .name = "exynos_m4",
        .llvm_name = "exynos-m4",
        .features = featureSet(&[_]Feature{
            .exynosm4,
        }),
    };
    pub const exynos_m5 = CpuModel{
        .name = "exynos_m5",
        .llvm_name = "exynos-m5",
        .features = featureSet(&[_]Feature{
            .exynosm4,
        }),
    };
    pub const falkor = CpuModel{
        .name = "falkor",
        .llvm_name = "falkor",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .custom_cheap_as_move,
            .lsl_fast,
            .perfmon,
            .predictable_select_expensive,
            .rdm,
            .slow_strqro_store,
            .use_postra_scheduler,
            .v8a,
            .zcz,
        }),
    };
    pub const generic = CpuModel{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .ete,
            .fuse_aes,
            .perfmon,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const kryo = CpuModel{
        .name = "kryo",
        .llvm_name = "kryo",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .custom_cheap_as_move,
            .lsl_fast,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .zcz,
            .v8a,
        }),
    };
    pub const neoverse_e1 = CpuModel{
        .name = "neoverse_e1",
        .llvm_name = "neoverse-e1",
        .features = featureSet(&[_]Feature{
            .neoversee1,
        }),
    };
    pub const neoverse_n1 = CpuModel{
        .name = "neoverse_n1",
        .llvm_name = "neoverse-n1",
        .features = featureSet(&[_]Feature{
            .neoversen1,
        }),
    };
    pub const saphira = CpuModel{
        .name = "saphira",
        .llvm_name = "saphira",
        .features = featureSet(&[_]Feature{
            .crypto,
            .custom_cheap_as_move,
            .lsl_fast,
            .perfmon,
            .predictable_select_expensive,
            .spe,
            .use_postra_scheduler,
            .v8_4a,
            .zcz,
        }),
    };
    pub const thunderx = CpuModel{
        .name = "thunderx",
        .llvm_name = "thunderx",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const thunderx2t99 = CpuModel{
        .name = "thunderx2t99",
        .llvm_name = "thunderx2t99",
        .features = featureSet(&[_]Feature{
            .aggressive_fma,
            .arith_bcc_fusion,
            .crc,
            .crypto,
            .lse,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8_1a,
        }),
    };
    pub const thunderx3t110 = CpuModel{
        .name = "thunderx3t110",
        .llvm_name = "thunderx3t110",
        .features = featureSet(&[_]Feature{
            .aggressive_fma,
            .arith_bcc_fusion,
            .balance_fp_ops,
            .crc,
            .crypto,
            .fp_armv8,
            .lse,
            .neon,
            .pa,
            .perfmon,
            .predictable_select_expensive,
            .strict_align,
            .use_aa,
            .use_postra_scheduler,
            .v8_3a,
        }),
    };
    pub const thunderxt81 = CpuModel{
        .name = "thunderxt81",
        .llvm_name = "thunderxt81",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const thunderxt83 = CpuModel{
        .name = "thunderxt83",
        .llvm_name = "thunderxt83",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const thunderxt88 = CpuModel{
        .name = "thunderxt88",
        .llvm_name = "thunderxt88",
        .features = featureSet(&[_]Feature{
            .crc,
            .crypto,
            .perfmon,
            .predictable_select_expensive,
            .use_postra_scheduler,
            .v8a,
        }),
    };
    pub const tsv110 = CpuModel{
        .name = "tsv110",
        .llvm_name = "tsv110",
        .features = featureSet(&[_]Feature{
            .crypto,
            .custom_cheap_as_move,
            .dotprod,
            .fp16fml,
            .fullfp16,
            .fuse_aes,
            .perfmon,
            .spe,
            .use_postra_scheduler,
            .v8_2a,
        }),
    };
};
