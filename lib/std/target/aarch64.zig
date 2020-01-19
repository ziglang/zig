const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    aes,
    am,
    aggressive_fma,
    altnzcv,
    alternate_sextload_cvt_f32_pattern,
    arith_bcc_fusion,
    arith_cbz_fusion,
    balance_fp_ops,
    bti,
    ccidx,
    ccpp,
    crc,
    ccdp,
    call_saved_x8,
    call_saved_x9,
    call_saved_x10,
    call_saved_x11,
    call_saved_x12,
    call_saved_x13,
    call_saved_x14,
    call_saved_x15,
    call_saved_x18,
    complxnum,
    crypto,
    custom_cheap_as_move,
    dit,
    disable_latency_sched_heuristic,
    dotprod,
    exynos_cheap_as_move,
    fmi,
    fp16fml,
    fp_armv8,
    fptoint,
    force_32bit_jump_tables,
    fullfp16,
    fuse_aes,
    fuse_address,
    fuse_arith_logic,
    fuse_csel,
    fuse_crypto_eor,
    fuse_literals,
    jsconv,
    lor,
    lse,
    lsl_fast,
    mpam,
    mte,
    neon,
    nv,
    no_neg_immediates,
    pa,
    pan,
    pan_rwv,
    perfmon,
    use_postra_scheduler,
    predres,
    predictable_select_expensive,
    uaops,
    ras,
    rasv8_4,
    rcpc,
    rcpc_immo,
    rdm,
    rand,
    reserve_x1,
    reserve_x2,
    reserve_x3,
    reserve_x4,
    reserve_x5,
    reserve_x6,
    reserve_x7,
    reserve_x9,
    reserve_x10,
    reserve_x11,
    reserve_x12,
    reserve_x13,
    reserve_x14,
    reserve_x15,
    reserve_x18,
    reserve_x20,
    reserve_x21,
    reserve_x22,
    reserve_x23,
    reserve_x24,
    reserve_x25,
    reserve_x26,
    reserve_x27,
    reserve_x28,
    sb,
    sel2,
    sha2,
    sha3,
    sm4,
    spe,
    ssbs,
    sve,
    sve2,
    sve2_aes,
    sve2_bitperm,
    sve2_sha3,
    sve2_sm4,
    slow_misaligned_128store,
    slow_paired_128,
    slow_strqro_store,
    specrestrict,
    strict_align,
    tlb_rmi,
    tracev84,
    use_aa,
    tpidr_el1,
    tpidr_el2,
    tpidr_el3,
    use_reciprocal_square_root,
    vh,
    zcm,
    zcz,
    zcz_fp,
    zcz_fp_workaround,
    zcz_gp,
};

pub fn featureSet(features: []const Feature) Cpu.Feature.Set {
    var x: Cpu.Feature.Set = 0;
    for (features) |feature| {
        x |= 1 << @enumToInt(feature);
    }
    return x;
}

pub fn featureSetHas(set: Feature.Set, feature: Feature) bool {
    return (set & (1 << @enumToInt(feature))) != 0;
}

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;
    result[@enumToInt(Feature.aes)] = .{
        .index = @enumToInt(Feature.aes),
        .name = @tagName(Feature.aes),
        .llvm_name = "aes",
        .description = "Enable AES support",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.am)] = .{
        .index = @enumToInt(Feature.am),
        .name = @tagName(Feature.am),
        .llvm_name = "am",
        .description = "Enable v8.4-A Activity Monitors extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.aggressive_fma)] = .{
        .index = @enumToInt(Feature.aggressive_fma),
        .name = @tagName(Feature.aggressive_fma),
        .llvm_name = "aggressive-fma",
        .description = "Enable Aggressive FMA for floating-point.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.altnzcv)] = .{
        .index = @enumToInt(Feature.altnzcv),
        .name = @tagName(Feature.altnzcv),
        .llvm_name = "altnzcv",
        .description = "Enable alternative NZCV format for floating point comparisons",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.alternate_sextload_cvt_f32_pattern)] = .{
        .index = @enumToInt(Feature.alternate_sextload_cvt_f32_pattern),
        .name = @tagName(Feature.alternate_sextload_cvt_f32_pattern),
        .llvm_name = "alternate-sextload-cvt-f32-pattern",
        .description = "Use alternative pattern for sextload convert to f32",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.arith_bcc_fusion)] = .{
        .index = @enumToInt(Feature.arith_bcc_fusion),
        .name = @tagName(Feature.arith_bcc_fusion),
        .llvm_name = "arith-bcc-fusion",
        .description = "CPU fuses arithmetic+bcc operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.arith_cbz_fusion)] = .{
        .index = @enumToInt(Feature.arith_cbz_fusion),
        .name = @tagName(Feature.arith_cbz_fusion),
        .llvm_name = "arith-cbz-fusion",
        .description = "CPU fuses arithmetic + cbz/cbnz operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.balance_fp_ops)] = .{
        .index = @enumToInt(Feature.balance_fp_ops),
        .name = @tagName(Feature.balance_fp_ops),
        .llvm_name = "balance-fp-ops",
        .description = "balance mix of odd and even D-registers for fp multiply(-accumulate) ops",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.bti)] = .{
        .index = @enumToInt(Feature.bti),
        .name = @tagName(Feature.bti),
        .llvm_name = "bti",
        .description = "Enable Branch Target Identification",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ccidx)] = .{
        .index = @enumToInt(Feature.ccidx),
        .name = @tagName(Feature.ccidx),
        .llvm_name = "ccidx",
        .description = "Enable v8.3-A Extend of the CCSIDR number of sets",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ccpp)] = .{
        .index = @enumToInt(Feature.ccpp),
        .name = @tagName(Feature.ccpp),
        .llvm_name = "ccpp",
        .description = "Enable v8.2 data Cache Clean to Point of Persistence",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.crc)] = .{
        .index = @enumToInt(Feature.crc),
        .name = @tagName(Feature.crc),
        .llvm_name = "crc",
        .description = "Enable ARMv8 CRC-32 checksum instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ccdp)] = .{
        .index = @enumToInt(Feature.ccdp),
        .name = @tagName(Feature.ccdp),
        .llvm_name = "ccdp",
        .description = "Enable v8.5 Cache Clean to Point of Deep Persistence",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x8)] = .{
        .index = @enumToInt(Feature.call_saved_x8),
        .name = @tagName(Feature.call_saved_x8),
        .llvm_name = "call-saved-x8",
        .description = "Make X8 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x9)] = .{
        .index = @enumToInt(Feature.call_saved_x9),
        .name = @tagName(Feature.call_saved_x9),
        .llvm_name = "call-saved-x9",
        .description = "Make X9 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x10)] = .{
        .index = @enumToInt(Feature.call_saved_x10),
        .name = @tagName(Feature.call_saved_x10),
        .llvm_name = "call-saved-x10",
        .description = "Make X10 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x11)] = .{
        .index = @enumToInt(Feature.call_saved_x11),
        .name = @tagName(Feature.call_saved_x11),
        .llvm_name = "call-saved-x11",
        .description = "Make X11 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x12)] = .{
        .index = @enumToInt(Feature.call_saved_x12),
        .name = @tagName(Feature.call_saved_x12),
        .llvm_name = "call-saved-x12",
        .description = "Make X12 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x13)] = .{
        .index = @enumToInt(Feature.call_saved_x13),
        .name = @tagName(Feature.call_saved_x13),
        .llvm_name = "call-saved-x13",
        .description = "Make X13 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x14)] = .{
        .index = @enumToInt(Feature.call_saved_x14),
        .name = @tagName(Feature.call_saved_x14),
        .llvm_name = "call-saved-x14",
        .description = "Make X14 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x15)] = .{
        .index = @enumToInt(Feature.call_saved_x15),
        .name = @tagName(Feature.call_saved_x15),
        .llvm_name = "call-saved-x15",
        .description = "Make X15 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.call_saved_x18)] = .{
        .index = @enumToInt(Feature.call_saved_x18),
        .name = @tagName(Feature.call_saved_x18),
        .llvm_name = "call-saved-x18",
        .description = "Make X18 callee saved.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.complxnum)] = .{
        .index = @enumToInt(Feature.complxnum),
        .name = @tagName(Feature.complxnum),
        .llvm_name = "complxnum",
        .description = "Enable v8.3-A Floating-point complex number support",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.crypto)] = .{
        .index = @enumToInt(Feature.crypto),
        .name = @tagName(Feature.crypto),
        .llvm_name = "crypto",
        .description = "Enable cryptographic instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.custom_cheap_as_move)] = .{
        .index = @enumToInt(Feature.custom_cheap_as_move),
        .name = @tagName(Feature.custom_cheap_as_move),
        .llvm_name = "custom-cheap-as-move",
        .description = "Use custom handling of cheap instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.dit)] = .{
        .index = @enumToInt(Feature.dit),
        .name = @tagName(Feature.dit),
        .llvm_name = "dit",
        .description = "Enable v8.4-A Data Independent Timing instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.disable_latency_sched_heuristic)] = .{
        .index = @enumToInt(Feature.disable_latency_sched_heuristic),
        .name = @tagName(Feature.disable_latency_sched_heuristic),
        .llvm_name = "disable-latency-sched-heuristic",
        .description = "Disable latency scheduling heuristic",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.dotprod)] = .{
        .index = @enumToInt(Feature.dotprod),
        .name = @tagName(Feature.dotprod),
        .llvm_name = "dotprod",
        .description = "Enable dot product support",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.exynos_cheap_as_move)] = .{
        .index = @enumToInt(Feature.exynos_cheap_as_move),
        .name = @tagName(Feature.exynos_cheap_as_move),
        .llvm_name = "exynos-cheap-as-move",
        .description = "Use Exynos specific handling of cheap instructions",
        .dependencies = featureSet(&[_]Feature{
            .custom_cheap_as_move,
        }),
    };
    result[@enumToInt(Feature.fmi)] = .{
        .index = @enumToInt(Feature.fmi),
        .name = @tagName(Feature.fmi),
        .llvm_name = "fmi",
        .description = "Enable v8.4-A Flag Manipulation Instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fp16fml)] = .{
        .index = @enumToInt(Feature.fp16fml),
        .name = @tagName(Feature.fp16fml),
        .llvm_name = "fp16fml",
        .description = "Enable FP16 FML instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.fp_armv8)] = .{
        .index = @enumToInt(Feature.fp_armv8),
        .name = @tagName(Feature.fp_armv8),
        .llvm_name = "fp-armv8",
        .description = "Enable ARMv8 FP",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fptoint)] = .{
        .index = @enumToInt(Feature.fptoint),
        .name = @tagName(Feature.fptoint),
        .llvm_name = "fptoint",
        .description = "Enable FRInt[32|64][Z|X] instructions that round a floating-point number to an integer (in FP format) forcing it to fit into a 32- or 64-bit int",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.force_32bit_jump_tables)] = .{
        .index = @enumToInt(Feature.force_32bit_jump_tables),
        .name = @tagName(Feature.force_32bit_jump_tables),
        .llvm_name = "force-32bit-jump-tables",
        .description = "Force jump table entries to be 32-bits wide except at MinSize",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fullfp16)] = .{
        .index = @enumToInt(Feature.fullfp16),
        .name = @tagName(Feature.fullfp16),
        .llvm_name = "fullfp16",
        .description = "Full FP16",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.fuse_aes)] = .{
        .index = @enumToInt(Feature.fuse_aes),
        .name = @tagName(Feature.fuse_aes),
        .llvm_name = "fuse-aes",
        .description = "CPU fuses AES crypto operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_address)] = .{
        .index = @enumToInt(Feature.fuse_address),
        .name = @tagName(Feature.fuse_address),
        .llvm_name = "fuse-address",
        .description = "CPU fuses address generation and memory operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_arith_logic)] = .{
        .index = @enumToInt(Feature.fuse_arith_logic),
        .name = @tagName(Feature.fuse_arith_logic),
        .llvm_name = "fuse-arith-logic",
        .description = "CPU fuses arithmetic and logic operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_csel)] = .{
        .index = @enumToInt(Feature.fuse_csel),
        .name = @tagName(Feature.fuse_csel),
        .llvm_name = "fuse-csel",
        .description = "CPU fuses conditional select operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_crypto_eor)] = .{
        .index = @enumToInt(Feature.fuse_crypto_eor),
        .name = @tagName(Feature.fuse_crypto_eor),
        .llvm_name = "fuse-crypto-eor",
        .description = "CPU fuses AES/PMULL and EOR operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.fuse_literals)] = .{
        .index = @enumToInt(Feature.fuse_literals),
        .name = @tagName(Feature.fuse_literals),
        .llvm_name = "fuse-literals",
        .description = "CPU fuses literal generation operations",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.jsconv)] = .{
        .index = @enumToInt(Feature.jsconv),
        .name = @tagName(Feature.jsconv),
        .llvm_name = "jsconv",
        .description = "Enable v8.3-A JavaScript FP conversion enchancement",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.lor)] = .{
        .index = @enumToInt(Feature.lor),
        .name = @tagName(Feature.lor),
        .llvm_name = "lor",
        .description = "Enables ARM v8.1 Limited Ordering Regions extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.lse)] = .{
        .index = @enumToInt(Feature.lse),
        .name = @tagName(Feature.lse),
        .llvm_name = "lse",
        .description = "Enable ARMv8.1 Large System Extension (LSE) atomic instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.lsl_fast)] = .{
        .index = @enumToInt(Feature.lsl_fast),
        .name = @tagName(Feature.lsl_fast),
        .llvm_name = "lsl-fast",
        .description = "CPU has a fastpath logical shift of up to 3 places",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mpam)] = .{
        .index = @enumToInt(Feature.mpam),
        .name = @tagName(Feature.mpam),
        .llvm_name = "mpam",
        .description = "Enable v8.4-A Memory system Partitioning and Monitoring extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.mte)] = .{
        .index = @enumToInt(Feature.mte),
        .name = @tagName(Feature.mte),
        .llvm_name = "mte",
        .description = "Enable Memory Tagging Extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.neon)] = .{
        .index = @enumToInt(Feature.neon),
        .name = @tagName(Feature.neon),
        .llvm_name = "neon",
        .description = "Enable Advanced SIMD instructions",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.nv)] = .{
        .index = @enumToInt(Feature.nv),
        .name = @tagName(Feature.nv),
        .llvm_name = "nv",
        .description = "Enable v8.4-A Nested Virtualization Enchancement",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.no_neg_immediates)] = .{
        .index = @enumToInt(Feature.no_neg_immediates),
        .name = @tagName(Feature.no_neg_immediates),
        .llvm_name = "no-neg-immediates",
        .description = "Convert immediates and instructions to their negated or complemented equivalent when the immediate does not fit in the encoding.",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.pa)] = .{
        .index = @enumToInt(Feature.pa),
        .name = @tagName(Feature.pa),
        .llvm_name = "pa",
        .description = "Enable v8.3-A Pointer Authentication enchancement",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.pan)] = .{
        .index = @enumToInt(Feature.pan),
        .name = @tagName(Feature.pan),
        .llvm_name = "pan",
        .description = "Enables ARM v8.1 Privileged Access-Never extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.pan_rwv)] = .{
        .index = @enumToInt(Feature.pan_rwv),
        .name = @tagName(Feature.pan_rwv),
        .llvm_name = "pan-rwv",
        .description = "Enable v8.2 PAN s1e1R and s1e1W Variants",
        .dependencies = featureSet(&[_]Feature{
            .pan,
        }),
    };
    result[@enumToInt(Feature.perfmon)] = .{
        .index = @enumToInt(Feature.perfmon),
        .name = @tagName(Feature.perfmon),
        .llvm_name = "perfmon",
        .description = "Enable ARMv8 PMUv3 Performance Monitors extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.use_postra_scheduler)] = .{
        .index = @enumToInt(Feature.use_postra_scheduler),
        .name = @tagName(Feature.use_postra_scheduler),
        .llvm_name = "use-postra-scheduler",
        .description = "Schedule again after register allocation",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.predres)] = .{
        .index = @enumToInt(Feature.predres),
        .name = @tagName(Feature.predres),
        .llvm_name = "predres",
        .description = "Enable v8.5a execution and data prediction invalidation instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.predictable_select_expensive)] = .{
        .index = @enumToInt(Feature.predictable_select_expensive),
        .name = @tagName(Feature.predictable_select_expensive),
        .llvm_name = "predictable-select-expensive",
        .description = "Prefer likely predicted branches over selects",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.uaops)] = .{
        .index = @enumToInt(Feature.uaops),
        .name = @tagName(Feature.uaops),
        .llvm_name = "uaops",
        .description = "Enable v8.2 UAO PState",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ras)] = .{
        .index = @enumToInt(Feature.ras),
        .name = @tagName(Feature.ras),
        .llvm_name = "ras",
        .description = "Enable ARMv8 Reliability, Availability and Serviceability Extensions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.rasv8_4)] = .{
        .index = @enumToInt(Feature.rasv8_4),
        .name = @tagName(Feature.rasv8_4),
        .llvm_name = "rasv8_4",
        .description = "Enable v8.4-A Reliability, Availability and Serviceability extension",
        .dependencies = featureSet(&[_]Feature{
            .ras,
        }),
    };
    result[@enumToInt(Feature.rcpc)] = .{
        .index = @enumToInt(Feature.rcpc),
        .name = @tagName(Feature.rcpc),
        .llvm_name = "rcpc",
        .description = "Enable support for RCPC extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.rcpc_immo)] = .{
        .index = @enumToInt(Feature.rcpc_immo),
        .name = @tagName(Feature.rcpc_immo),
        .llvm_name = "rcpc-immo",
        .description = "Enable v8.4-A RCPC instructions with Immediate Offsets",
        .dependencies = featureSet(&[_]Feature{
            .rcpc,
        }),
    };
    result[@enumToInt(Feature.rdm)] = .{
        .index = @enumToInt(Feature.rdm),
        .name = @tagName(Feature.rdm),
        .llvm_name = "rdm",
        .description = "Enable ARMv8.1 Rounding Double Multiply Add/Subtract instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.rand)] = .{
        .index = @enumToInt(Feature.rand),
        .name = @tagName(Feature.rand),
        .llvm_name = "rand",
        .description = "Enable Random Number generation instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x1)] = .{
        .index = @enumToInt(Feature.reserve_x1),
        .name = @tagName(Feature.reserve_x1),
        .llvm_name = "reserve-x1",
        .description = "Reserve X1, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x2)] = .{
        .index = @enumToInt(Feature.reserve_x2),
        .name = @tagName(Feature.reserve_x2),
        .llvm_name = "reserve-x2",
        .description = "Reserve X2, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x3)] = .{
        .index = @enumToInt(Feature.reserve_x3),
        .name = @tagName(Feature.reserve_x3),
        .llvm_name = "reserve-x3",
        .description = "Reserve X3, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x4)] = .{
        .index = @enumToInt(Feature.reserve_x4),
        .name = @tagName(Feature.reserve_x4),
        .llvm_name = "reserve-x4",
        .description = "Reserve X4, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x5)] = .{
        .index = @enumToInt(Feature.reserve_x5),
        .name = @tagName(Feature.reserve_x5),
        .llvm_name = "reserve-x5",
        .description = "Reserve X5, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x6)] = .{
        .index = @enumToInt(Feature.reserve_x6),
        .name = @tagName(Feature.reserve_x6),
        .llvm_name = "reserve-x6",
        .description = "Reserve X6, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x7)] = .{
        .index = @enumToInt(Feature.reserve_x7),
        .name = @tagName(Feature.reserve_x7),
        .llvm_name = "reserve-x7",
        .description = "Reserve X7, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x9)] = .{
        .index = @enumToInt(Feature.reserve_x9),
        .name = @tagName(Feature.reserve_x9),
        .llvm_name = "reserve-x9",
        .description = "Reserve X9, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x10)] = .{
        .index = @enumToInt(Feature.reserve_x10),
        .name = @tagName(Feature.reserve_x10),
        .llvm_name = "reserve-x10",
        .description = "Reserve X10, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x11)] = .{
        .index = @enumToInt(Feature.reserve_x11),
        .name = @tagName(Feature.reserve_x11),
        .llvm_name = "reserve-x11",
        .description = "Reserve X11, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x12)] = .{
        .index = @enumToInt(Feature.reserve_x12),
        .name = @tagName(Feature.reserve_x12),
        .llvm_name = "reserve-x12",
        .description = "Reserve X12, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x13)] = .{
        .index = @enumToInt(Feature.reserve_x13),
        .name = @tagName(Feature.reserve_x13),
        .llvm_name = "reserve-x13",
        .description = "Reserve X13, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x14)] = .{
        .index = @enumToInt(Feature.reserve_x14),
        .name = @tagName(Feature.reserve_x14),
        .llvm_name = "reserve-x14",
        .description = "Reserve X14, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x15)] = .{
        .index = @enumToInt(Feature.reserve_x15),
        .name = @tagName(Feature.reserve_x15),
        .llvm_name = "reserve-x15",
        .description = "Reserve X15, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x18)] = .{
        .index = @enumToInt(Feature.reserve_x18),
        .name = @tagName(Feature.reserve_x18),
        .llvm_name = "reserve-x18",
        .description = "Reserve X18, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x20)] = .{
        .index = @enumToInt(Feature.reserve_x20),
        .name = @tagName(Feature.reserve_x20),
        .llvm_name = "reserve-x20",
        .description = "Reserve X20, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x21)] = .{
        .index = @enumToInt(Feature.reserve_x21),
        .name = @tagName(Feature.reserve_x21),
        .llvm_name = "reserve-x21",
        .description = "Reserve X21, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x22)] = .{
        .index = @enumToInt(Feature.reserve_x22),
        .name = @tagName(Feature.reserve_x22),
        .llvm_name = "reserve-x22",
        .description = "Reserve X22, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x23)] = .{
        .index = @enumToInt(Feature.reserve_x23),
        .name = @tagName(Feature.reserve_x23),
        .llvm_name = "reserve-x23",
        .description = "Reserve X23, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x24)] = .{
        .index = @enumToInt(Feature.reserve_x24),
        .name = @tagName(Feature.reserve_x24),
        .llvm_name = "reserve-x24",
        .description = "Reserve X24, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x25)] = .{
        .index = @enumToInt(Feature.reserve_x25),
        .name = @tagName(Feature.reserve_x25),
        .llvm_name = "reserve-x25",
        .description = "Reserve X25, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x26)] = .{
        .index = @enumToInt(Feature.reserve_x26),
        .name = @tagName(Feature.reserve_x26),
        .llvm_name = "reserve-x26",
        .description = "Reserve X26, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x27)] = .{
        .index = @enumToInt(Feature.reserve_x27),
        .name = @tagName(Feature.reserve_x27),
        .llvm_name = "reserve-x27",
        .description = "Reserve X27, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.reserve_x28)] = .{
        .index = @enumToInt(Feature.reserve_x28),
        .name = @tagName(Feature.reserve_x28),
        .llvm_name = "reserve-x28",
        .description = "Reserve X28, making it unavailable as a GPR",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sb)] = .{
        .index = @enumToInt(Feature.sb),
        .name = @tagName(Feature.sb),
        .llvm_name = "sb",
        .description = "Enable v8.5 Speculation Barrier",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sel2)] = .{
        .index = @enumToInt(Feature.sel2),
        .name = @tagName(Feature.sel2),
        .llvm_name = "sel2",
        .description = "Enable v8.4-A Secure Exception Level 2 extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sha2)] = .{
        .index = @enumToInt(Feature.sha2),
        .name = @tagName(Feature.sha2),
        .llvm_name = "sha2",
        .description = "Enable SHA1 and SHA256 support",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.sha3)] = .{
        .index = @enumToInt(Feature.sha3),
        .name = @tagName(Feature.sha3),
        .llvm_name = "sha3",
        .description = "Enable SHA512 and SHA3 support",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.sm4)] = .{
        .index = @enumToInt(Feature.sm4),
        .name = @tagName(Feature.sm4),
        .llvm_name = "sm4",
        .description = "Enable SM3 and SM4 support",
        .dependencies = featureSet(&[_]Feature{
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.spe)] = .{
        .index = @enumToInt(Feature.spe),
        .name = @tagName(Feature.spe),
        .llvm_name = "spe",
        .description = "Enable Statistical Profiling extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.ssbs)] = .{
        .index = @enumToInt(Feature.ssbs),
        .name = @tagName(Feature.ssbs),
        .llvm_name = "ssbs",
        .description = "Enable Speculative Store Bypass Safe bit",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sve)] = .{
        .index = @enumToInt(Feature.sve),
        .name = @tagName(Feature.sve),
        .llvm_name = "sve",
        .description = "Enable Scalable Vector Extension (SVE) instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.sve2)] = .{
        .index = @enumToInt(Feature.sve2),
        .name = @tagName(Feature.sve2),
        .llvm_name = "sve2",
        .description = "Enable Scalable Vector Extension 2 (SVE2) instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
        }),
    };
    result[@enumToInt(Feature.sve2_aes)] = .{
        .index = @enumToInt(Feature.sve2_aes),
        .name = @tagName(Feature.sve2_aes),
        .llvm_name = "sve2-aes",
        .description = "Enable AES SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.sve2_bitperm)] = .{
        .index = @enumToInt(Feature.sve2_bitperm),
        .name = @tagName(Feature.sve2_bitperm),
        .llvm_name = "sve2-bitperm",
        .description = "Enable bit permutation SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
        }),
    };
    result[@enumToInt(Feature.sve2_sha3)] = .{
        .index = @enumToInt(Feature.sve2_sha3),
        .name = @tagName(Feature.sve2_sha3),
        .llvm_name = "sve2-sha3",
        .description = "Enable SHA3 SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.sve2_sm4)] = .{
        .index = @enumToInt(Feature.sve2_sm4),
        .name = @tagName(Feature.sve2_sm4),
        .llvm_name = "sve2-sm4",
        .description = "Enable SM4 SVE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sve,
            .fp_armv8,
        }),
    };
    result[@enumToInt(Feature.slow_misaligned_128store)] = .{
        .index = @enumToInt(Feature.slow_misaligned_128store),
        .name = @tagName(Feature.slow_misaligned_128store),
        .llvm_name = "slow-misaligned-128store",
        .description = "Misaligned 128 bit stores are slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_paired_128)] = .{
        .index = @enumToInt(Feature.slow_paired_128),
        .name = @tagName(Feature.slow_paired_128),
        .llvm_name = "slow-paired-128",
        .description = "Paired 128 bit loads and stores are slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.slow_strqro_store)] = .{
        .index = @enumToInt(Feature.slow_strqro_store),
        .name = @tagName(Feature.slow_strqro_store),
        .llvm_name = "slow-strqro-store",
        .description = "STR of Q register with register offset is slow",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.specrestrict)] = .{
        .index = @enumToInt(Feature.specrestrict),
        .name = @tagName(Feature.specrestrict),
        .llvm_name = "specrestrict",
        .description = "Enable architectural speculation restriction",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.strict_align)] = .{
        .index = @enumToInt(Feature.strict_align),
        .name = @tagName(Feature.strict_align),
        .llvm_name = "strict-align",
        .description = "Disallow all unaligned memory access",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tlb_rmi)] = .{
        .index = @enumToInt(Feature.tlb_rmi),
        .name = @tagName(Feature.tlb_rmi),
        .llvm_name = "tlb-rmi",
        .description = "Enable v8.4-A TLB Range and Maintenance Instructions",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tracev84)] = .{
        .index = @enumToInt(Feature.tracev84),
        .name = @tagName(Feature.tracev84),
        .llvm_name = "tracev8.4",
        .description = "Enable v8.4-A Trace extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.use_aa)] = .{
        .index = @enumToInt(Feature.use_aa),
        .name = @tagName(Feature.use_aa),
        .llvm_name = "use-aa",
        .description = "Use alias analysis during codegen",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tpidr_el1)] = .{
        .index = @enumToInt(Feature.tpidr_el1),
        .name = @tagName(Feature.tpidr_el1),
        .llvm_name = "tpidr-el1",
        .description = "Permit use of TPIDR_EL1 for the TLS base",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tpidr_el2)] = .{
        .index = @enumToInt(Feature.tpidr_el2),
        .name = @tagName(Feature.tpidr_el2),
        .llvm_name = "tpidr-el2",
        .description = "Permit use of TPIDR_EL2 for the TLS base",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.tpidr_el3)] = .{
        .index = @enumToInt(Feature.tpidr_el3),
        .name = @tagName(Feature.tpidr_el3),
        .llvm_name = "tpidr-el3",
        .description = "Permit use of TPIDR_EL3 for the TLS base",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.use_reciprocal_square_root)] = .{
        .index = @enumToInt(Feature.use_reciprocal_square_root),
        .name = @tagName(Feature.use_reciprocal_square_root),
        .llvm_name = "use-reciprocal-square-root",
        .description = "Use the reciprocal square root approximation",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.vh)] = .{
        .index = @enumToInt(Feature.vh),
        .name = @tagName(Feature.vh),
        .llvm_name = "vh",
        .description = "Enables ARM v8.1 Virtual Host extension",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.zcm)] = .{
        .index = @enumToInt(Feature.zcm),
        .name = @tagName(Feature.zcm),
        .llvm_name = "zcm",
        .description = "Has zero-cycle register moves",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.zcz)] = .{
        .index = @enumToInt(Feature.zcz),
        .name = @tagName(Feature.zcz),
        .llvm_name = "zcz",
        .description = "Has zero-cycle zeroing instructions",
        .dependencies = featureSet(&[_]Feature{
            .zcz_fp,
            .zcz_gp,
        }),
    };
    result[@enumToInt(Feature.zcz_fp)] = .{
        .index = @enumToInt(Feature.zcz_fp),
        .name = @tagName(Feature.zcz_fp),
        .llvm_name = "zcz-fp",
        .description = "Has zero-cycle zeroing instructions for FP registers",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.zcz_fp_workaround)] = .{
        .index = @enumToInt(Feature.zcz_fp_workaround),
        .name = @tagName(Feature.zcz_fp_workaround),
        .llvm_name = "zcz-fp-workaround",
        .description = "The zero-cycle floating-point zeroing instruction has a bug",
        .dependencies = 0,
    };
    result[@enumToInt(Feature.zcz_gp)] = .{
        .index = @enumToInt(Feature.zcz_gp),
        .name = @tagName(Feature.zcz_gp),
        .llvm_name = "zcz-gp",
        .description = "Has zero-cycle zeroing instructions for generic registers",
        .dependencies = 0,
    };
    break :blk result;
};

pub const cpu = struct {
    pub const apple_latest = Cpu{
        .name = "apple_latest",
        .llvm_name = "apple-latest",
        .features = featureSet(&[_]Feature{
            .arith_cbz_fusion,
            .zcz_fp_workaround,
            .alternate_sextload_cvt_f32_pattern,
            .fuse_crypto_eor,
            .zcm,
            .zcz_gp,
            .perfmon,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .zcz_fp,
            .arith_bcc_fusion,
            .fuse_aes,
        }),
    };

    pub const cortex_a35 = Cpu{
        .name = "cortex_a35",
        .llvm_name = "cortex-a35",
        .features = featureSet(&[_]Feature{
            .perfmon,
            .fp_armv8,
            .crc,
        }),
    };

    pub const cortex_a53 = Cpu{
        .name = "cortex_a53",
        .llvm_name = "cortex-a53",
        .features = featureSet(&[_]Feature{
            .custom_cheap_as_move,
            .crc,
            .perfmon,
            .use_aa,
            .fp_armv8,
            .fuse_aes,
            .balance_fp_ops,
            .use_postra_scheduler,
        }),
    };

    pub const cortex_a55 = Cpu{
        .name = "cortex_a55",
        .llvm_name = "cortex-a55",
        .features = featureSet(&[_]Feature{
            .ccpp,
            .rcpc,
            .uaops,
            .rdm,
            .ras,
            .lse,
            .crc,
            .perfmon,
            .fp_armv8,
            .vh,
            .fuse_aes,
            .lor,
            .dotprod,
            .pan,
        }),
    };

    pub const cortex_a57 = Cpu{
        .name = "cortex_a57",
        .llvm_name = "cortex-a57",
        .features = featureSet(&[_]Feature{
            .fuse_literals,
            .predictable_select_expensive,
            .custom_cheap_as_move,
            .crc,
            .perfmon,
            .fp_armv8,
            .fuse_aes,
            .balance_fp_ops,
            .use_postra_scheduler,
        }),
    };

    pub const cortex_a72 = Cpu{
        .name = "cortex_a72",
        .llvm_name = "cortex-a72",
        .features = featureSet(&[_]Feature{
            .fuse_aes,
            .fp_armv8,
            .perfmon,
            .crc,
        }),
    };

    pub const cortex_a73 = Cpu{
        .name = "cortex_a73",
        .llvm_name = "cortex-a73",
        .features = featureSet(&[_]Feature{
            .fuse_aes,
            .fp_armv8,
            .perfmon,
            .crc,
        }),
    };

    pub const cortex_a75 = Cpu{
        .name = "cortex_a75",
        .llvm_name = "cortex-a75",
        .features = featureSet(&[_]Feature{
            .ccpp,
            .rcpc,
            .uaops,
            .rdm,
            .ras,
            .lse,
            .crc,
            .perfmon,
            .fp_armv8,
            .vh,
            .fuse_aes,
            .lor,
            .dotprod,
            .pan,
        }),
    };

    pub const cortex_a76 = Cpu{
        .name = "cortex_a76",
        .llvm_name = "cortex-a76",
        .features = featureSet(&[_]Feature{
            .ccpp,
            .rcpc,
            .uaops,
            .rdm,
            .ras,
            .lse,
            .crc,
            .fp_armv8,
            .vh,
            .lor,
            .ssbs,
            .dotprod,
            .pan,
        }),
    };

    pub const cortex_a76ae = Cpu{
        .name = "cortex_a76ae",
        .llvm_name = "cortex-a76ae",
        .features = featureSet(&[_]Feature{
            .ccpp,
            .rcpc,
            .uaops,
            .rdm,
            .ras,
            .lse,
            .crc,
            .fp_armv8,
            .vh,
            .lor,
            .ssbs,
            .dotprod,
            .pan,
        }),
    };

    pub const cyclone = Cpu{
        .name = "cyclone",
        .llvm_name = "cyclone",
        .features = featureSet(&[_]Feature{
            .arith_cbz_fusion,
            .zcz_fp_workaround,
            .alternate_sextload_cvt_f32_pattern,
            .fuse_crypto_eor,
            .zcm,
            .zcz_gp,
            .perfmon,
            .disable_latency_sched_heuristic,
            .fp_armv8,
            .zcz_fp,
            .arith_bcc_fusion,
            .fuse_aes,
        }),
    };

    pub const exynos_m1 = Cpu{
        .name = "exynos_m1",
        .llvm_name = "exynos-m1",
        .features = featureSet(&[_]Feature{
            .custom_cheap_as_move,
            .crc,
            .force_32bit_jump_tables,
            .perfmon,
            .slow_misaligned_128store,
            .use_reciprocal_square_root,
            .fp_armv8,
            .zcz_fp,
            .fuse_aes,
            .slow_paired_128,
            .use_postra_scheduler,
        }),
    };

    pub const exynos_m2 = Cpu{
        .name = "exynos_m2",
        .llvm_name = "exynos-m2",
        .features = featureSet(&[_]Feature{
            .custom_cheap_as_move,
            .crc,
            .force_32bit_jump_tables,
            .perfmon,
            .slow_misaligned_128store,
            .fp_armv8,
            .zcz_fp,
            .fuse_aes,
            .slow_paired_128,
            .use_postra_scheduler,
        }),
    };

    pub const exynos_m3 = Cpu{
        .name = "exynos_m3",
        .llvm_name = "exynos-m3",
        .features = featureSet(&[_]Feature{
            .fuse_literals,
            .predictable_select_expensive,
            .custom_cheap_as_move,
            .crc,
            .force_32bit_jump_tables,
            .fuse_address,
            .fuse_csel,
            .perfmon,
            .fp_armv8,
            .zcz_fp,
            .fuse_aes,
            .lsl_fast,
            .use_postra_scheduler,
        }),
    };

    pub const exynos_m4 = Cpu{
        .name = "exynos_m4",
        .llvm_name = "exynos-m4",
        .features = featureSet(&[_]Feature{
            .arith_cbz_fusion,
            .custom_cheap_as_move,
            .lse,
            .zcz_fp,
            .lsl_fast,
            .lor,
            .fuse_literals,
            .ccpp,
            .ras,
            .fp_armv8,
            .fuse_aes,
            .pan,
            .fuse_arith_logic,
            .crc,
            .force_32bit_jump_tables,
            .fuse_address,
            .fuse_csel,
            .arith_bcc_fusion,
            .uaops,
            .rdm,
            .zcz_gp,
            .perfmon,
            .vh,
            .use_postra_scheduler,
            .dotprod,
        }),
    };

    pub const exynos_m5 = Cpu{
        .name = "exynos_m5",
        .llvm_name = "exynos-m5",
        .features = featureSet(&[_]Feature{
            .arith_cbz_fusion,
            .custom_cheap_as_move,
            .lse,
            .zcz_fp,
            .lsl_fast,
            .lor,
            .fuse_literals,
            .ccpp,
            .ras,
            .fp_armv8,
            .fuse_aes,
            .pan,
            .fuse_arith_logic,
            .crc,
            .force_32bit_jump_tables,
            .fuse_address,
            .fuse_csel,
            .arith_bcc_fusion,
            .uaops,
            .rdm,
            .zcz_gp,
            .perfmon,
            .vh,
            .use_postra_scheduler,
            .dotprod,
        }),
    };

    pub const falkor = Cpu{
        .name = "falkor",
        .llvm_name = "falkor",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .custom_cheap_as_move,
            .rdm,
            .slow_strqro_store,
            .zcz_gp,
            .crc,
            .perfmon,
            .fp_armv8,
            .zcz_fp,
            .lsl_fast,
            .use_postra_scheduler,
        }),
    };

    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .fp_armv8,
            .fuse_aes,
            .neon,
            .perfmon,
            .use_postra_scheduler,
        }),
    };

    pub const kryo = Cpu{
        .name = "kryo",
        .llvm_name = "kryo",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .custom_cheap_as_move,
            .zcz_gp,
            .crc,
            .perfmon,
            .fp_armv8,
            .zcz_fp,
            .lsl_fast,
            .use_postra_scheduler,
        }),
    };

    pub const saphira = Cpu{
        .name = "saphira",
        .llvm_name = "saphira",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .custom_cheap_as_move,
            .fmi,
            .lse,
            .zcz_fp,
            .lsl_fast,
            .lor,
            .dit,
            .pa,
            .ccpp,
            .sel2,
            .ras,
            .fp_armv8,
            .ccidx,
            .pan,
            .rcpc,
            .crc,
            .tracev84,
            .mpam,
            .am,
            .nv,
            .tlb_rmi,
            .uaops,
            .rdm,
            .zcz_gp,
            .perfmon,
            .vh,
            .use_postra_scheduler,
            .dotprod,
            .spe,
        }),
    };

    pub const thunderx = Cpu{
        .name = "thunderx",
        .llvm_name = "thunderx",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .crc,
            .perfmon,
            .fp_armv8,
            .use_postra_scheduler,
        }),
    };

    pub const thunderx2t99 = Cpu{
        .name = "thunderx2t99",
        .llvm_name = "thunderx2t99",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .aggressive_fma,
            .rdm,
            .lse,
            .crc,
            .fp_armv8,
            .vh,
            .arith_bcc_fusion,
            .lor,
            .use_postra_scheduler,
            .pan,
        }),
    };

    pub const thunderxt81 = Cpu{
        .name = "thunderxt81",
        .llvm_name = "thunderxt81",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .crc,
            .perfmon,
            .fp_armv8,
            .use_postra_scheduler,
        }),
    };

    pub const thunderxt83 = Cpu{
        .name = "thunderxt83",
        .llvm_name = "thunderxt83",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .crc,
            .perfmon,
            .fp_armv8,
            .use_postra_scheduler,
        }),
    };

    pub const thunderxt88 = Cpu{
        .name = "thunderxt88",
        .llvm_name = "thunderxt88",
        .features = featureSet(&[_]Feature{
            .predictable_select_expensive,
            .crc,
            .perfmon,
            .fp_armv8,
            .use_postra_scheduler,
        }),
    };

    pub const tsv110 = Cpu{
        .name = "tsv110",
        .llvm_name = "tsv110",
        .features = featureSet(&[_]Feature{
            .ccpp,
            .custom_cheap_as_move,
            .uaops,
            .rdm,
            .ras,
            .lse,
            .crc,
            .perfmon,
            .fp_armv8,
            .vh,
            .fuse_aes,
            .lor,
            .use_postra_scheduler,
            .dotprod,
            .pan,
            .spe,
        }),
    };
};

/// All aarch64 CPUs, sorted alphabetically by name.
/// TODO: Replace this with usage of `std.meta.declList`. It does work, but stage1
/// compiler has inefficient memory and CPU usage, affecting build times.
pub const all_cpus = &[_]*const Cpu{
    &cpu.apple_latest,
    &cpu.cortex_a35,
    &cpu.cortex_a53,
    &cpu.cortex_a55,
    &cpu.cortex_a57,
    &cpu.cortex_a72,
    &cpu.cortex_a73,
    &cpu.cortex_a75,
    &cpu.cortex_a76,
    &cpu.cortex_a76ae,
    &cpu.cyclone,
    &cpu.exynos_m1,
    &cpu.exynos_m2,
    &cpu.exynos_m3,
    &cpu.exynos_m4,
    &cpu.exynos_m5,
    &cpu.falkor,
    &cpu.generic,
    &cpu.kryo,
    &cpu.saphira,
    &cpu.thunderx,
    &cpu.thunderx2t99,
    &cpu.thunderxt81,
    &cpu.thunderxt83,
    &cpu.thunderxt88,
    &cpu.tsv110,
};
