const std = @import("../std.zig");
const Cpu = std.Target.Cpu;

pub const Feature = enum {
    @"16bit_mode",
    @"32bit_mode",
    @"3dnow",
    @"3dnowa",
    @"64bit",
    @"64bit_mode",
    adx,
    aes,
    avx,
    avx2,
    avx512bf16,
    avx512bitalg,
    avx512bw,
    avx512cd,
    avx512dq,
    avx512er,
    avx512f,
    avx512ifma,
    avx512pf,
    avx512vbmi,
    avx512vbmi2,
    avx512vl,
    avx512vnni,
    avx512vp2intersect,
    avx512vpopcntdq,
    bmi,
    bmi2,
    branchfusion,
    cldemote,
    clflushopt,
    clwb,
    clzero,
    cmov,
    cx16,
    cx8,
    enqcmd,
    ermsb,
    f16c,
    false_deps_lzcnt_tzcnt,
    false_deps_popcnt,
    fast_11bytenop,
    fast_15bytenop,
    fast_bextr,
    fast_gather,
    fast_hops,
    fast_lzcnt,
    fast_partial_ymm_or_zmm_write,
    fast_scalar_fsqrt,
    fast_scalar_shift_masks,
    fast_shld_rotate,
    fast_variable_shuffle,
    fast_vector_fsqrt,
    fast_vector_shift_masks,
    fma,
    fma4,
    fsgsbase,
    fxsr,
    gfni,
    idivl_to_divb,
    idivq_to_divl,
    invpcid,
    lea_sp,
    lea_uses_ag,
    lwp,
    lzcnt,
    macrofusion,
    merge_to_threeway_branch,
    mmx,
    movbe,
    movdir64b,
    movdiri,
    mpx,
    mwaitx,
    nopl,
    pad_short_functions,
    pclmul,
    pconfig,
    pku,
    popcnt,
    prefer_256_bit,
    prefetchwt1,
    prfchw,
    ptwrite,
    rdpid,
    rdrnd,
    rdseed,
    retpoline,
    retpoline_external_thunk,
    retpoline_indirect_branches,
    retpoline_indirect_calls,
    rtm,
    sahf,
    sgx,
    sha,
    shstk,
    slow_3ops_lea,
    slow_incdec,
    slow_lea,
    slow_pmaddwd,
    slow_pmulld,
    slow_shld,
    slow_two_mem_ops,
    slow_unaligned_mem_16,
    slow_unaligned_mem_32,
    soft_float,
    sse,
    sse2,
    sse3,
    sse4_1,
    sse4_2,
    sse4a,
    sse_unaligned_mem,
    ssse3,
    tbm,
    vaes,
    vpclmulqdq,
    waitpkg,
    wbnoinvd,
    x87,
    xop,
    xsave,
    xsavec,
    xsaveopt,
    xsaves,
};

pub usingnamespace Cpu.Feature.feature_set_fns(Feature);

pub const all_features = blk: {
    const len = @typeInfo(Feature).Enum.fields.len;
    std.debug.assert(len <= @typeInfo(Cpu.Feature.Set).Int.bits);
    var result: [len]Cpu.Feature = undefined;

    result[@enumToInt(Feature.@"16bit_mode")] = .{
        .index = @enumToInt(Feature.@"16bit_mode"),
        .name = @tagName(Feature.@"16bit_mode"),
        .llvm_name = "16bit-mode",
        .description = "16-bit mode (i8086)",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.@"32bit_mode")] = .{
        .index = @enumToInt(Feature.@"32bit_mode"),
        .name = @tagName(Feature.@"32bit_mode"),
        .llvm_name = "32bit-mode",
        .description = "32-bit mode (80386)",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.@"3dnow")] = .{
        .index = @enumToInt(Feature.@"3dnow"),
        .name = @tagName(Feature.@"3dnow"),
        .llvm_name = "3dnow",
        .description = "Enable 3DNow! instructions",
        .dependencies = featureSet(&[_]Feature{
            .mmx,
        }),
    };

    result[@enumToInt(Feature.@"3dnowa")] = .{
        .index = @enumToInt(Feature.@"3dnowa"),
        .name = @tagName(Feature.@"3dnowa"),
        .llvm_name = "3dnowa",
        .description = "Enable 3DNow! Athlon instructions",
        .dependencies = featureSet(&[_]Feature{
            .mmx,
        }),
    };

    result[@enumToInt(Feature.@"64bit")] = .{
        .index = @enumToInt(Feature.@"64bit"),
        .name = @tagName(Feature.@"64bit"),
        .llvm_name = "64bit",
        .description = "Support 64-bit instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.@"64bit_mode")] = .{
        .index = @enumToInt(Feature.@"64bit_mode"),
        .name = @tagName(Feature.@"64bit_mode"),
        .llvm_name = "64bit-mode",
        .description = "64-bit mode (x86_64)",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.adx)] = .{
        .index = @enumToInt(Feature.adx),
        .name = @tagName(Feature.adx),
        .llvm_name = "adx",
        .description = "Support ADX instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.aes)] = .{
        .index = @enumToInt(Feature.aes),
        .name = @tagName(Feature.aes),
        .llvm_name = "aes",
        .description = "Enable AES instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx)] = .{
        .index = @enumToInt(Feature.avx),
        .name = @tagName(Feature.avx),
        .llvm_name = "avx",
        .description = "Enable AVX instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx2)] = .{
        .index = @enumToInt(Feature.avx2),
        .name = @tagName(Feature.avx2),
        .llvm_name = "avx2",
        .description = "Enable AVX2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512f)] = .{
        .index = @enumToInt(Feature.avx512f),
        .name = @tagName(Feature.avx512f),
        .llvm_name = "avx512f",
        .description = "Enable AVX-512 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512bf16)] = .{
        .index = @enumToInt(Feature.avx512bf16),
        .name = @tagName(Feature.avx512bf16),
        .llvm_name = "avx512bf16",
        .description = "Support bfloat16 floating point",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512bitalg)] = .{
        .index = @enumToInt(Feature.avx512bitalg),
        .name = @tagName(Feature.avx512bitalg),
        .llvm_name = "avx512bitalg",
        .description = "Enable AVX-512 Bit Algorithms",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.bmi)] = .{
        .index = @enumToInt(Feature.bmi),
        .name = @tagName(Feature.bmi),
        .llvm_name = "bmi",
        .description = "Support BMI instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.bmi2)] = .{
        .index = @enumToInt(Feature.bmi2),
        .name = @tagName(Feature.bmi2),
        .llvm_name = "bmi2",
        .description = "Support BMI2 instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.avx512bw)] = .{
        .index = @enumToInt(Feature.avx512bw),
        .name = @tagName(Feature.avx512bw),
        .llvm_name = "avx512bw",
        .description = "Enable AVX-512 Byte and Word Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.branchfusion)] = .{
        .index = @enumToInt(Feature.branchfusion),
        .name = @tagName(Feature.branchfusion),
        .llvm_name = "branchfusion",
        .description = "CMP/TEST can be fused with conditional branches",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.avx512cd)] = .{
        .index = @enumToInt(Feature.avx512cd),
        .name = @tagName(Feature.avx512cd),
        .llvm_name = "avx512cd",
        .description = "Enable AVX-512 Conflict Detection Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.cldemote)] = .{
        .index = @enumToInt(Feature.cldemote),
        .name = @tagName(Feature.cldemote),
        .llvm_name = "cldemote",
        .description = "Enable Cache Demote",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.clflushopt)] = .{
        .index = @enumToInt(Feature.clflushopt),
        .name = @tagName(Feature.clflushopt),
        .llvm_name = "clflushopt",
        .description = "Flush A Cache Line Optimized",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.clwb)] = .{
        .index = @enumToInt(Feature.clwb),
        .name = @tagName(Feature.clwb),
        .llvm_name = "clwb",
        .description = "Cache Line Write Back",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.clzero)] = .{
        .index = @enumToInt(Feature.clzero),
        .name = @tagName(Feature.clzero),
        .llvm_name = "clzero",
        .description = "Enable Cache Line Zero",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.cmov)] = .{
        .index = @enumToInt(Feature.cmov),
        .name = @tagName(Feature.cmov),
        .llvm_name = "cmov",
        .description = "Enable conditional move instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.cx8)] = .{
        .index = @enumToInt(Feature.cx8),
        .name = @tagName(Feature.cx8),
        .llvm_name = "cx8",
        .description = "Support CMPXCHG8B instructions",
        .dependencies = featureSet(&[_]Feature{}),
    };

    result[@enumToInt(Feature.cx16)] = .{
        .index = @enumToInt(Feature.cx16),
        .name = @tagName(Feature.cx16),
        .llvm_name = "cx16",
        .description = "64-bit with cmpxchg16b",
        .dependencies = featureSet(&[_]Feature{
            .cx8,
        }),
    };

    result[@enumToInt(Feature.avx512dq)] = .{
        .index = @enumToInt(Feature.avx512dq),
        .name = @tagName(Feature.avx512dq),
        .llvm_name = "avx512dq",
        .description = "Enable AVX-512 Doubleword and Quadword Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.enqcmd)] = .{
        .index = @enumToInt(Feature.enqcmd),
        .name = @tagName(Feature.enqcmd),
        .llvm_name = "enqcmd",
        .description = "Has ENQCMD instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.avx512er)] = .{
        .index = @enumToInt(Feature.avx512er),
        .name = @tagName(Feature.avx512er),
        .llvm_name = "avx512er",
        .description = "Enable AVX-512 Exponential and Reciprocal Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.ermsb)] = .{
        .index = @enumToInt(Feature.ermsb),
        .name = @tagName(Feature.ermsb),
        .llvm_name = "ermsb",
        .description = "REP MOVS/STOS are fast",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.f16c)] = .{
        .index = @enumToInt(Feature.f16c),
        .name = @tagName(Feature.f16c),
        .llvm_name = "f16c",
        .description = "Support 16-bit floating point conversion instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.fma)] = .{
        .index = @enumToInt(Feature.fma),
        .name = @tagName(Feature.fma),
        .llvm_name = "fma",
        .description = "Enable three-operand fused multiple-add",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.fma4)] = .{
        .index = @enumToInt(Feature.fma4),
        .name = @tagName(Feature.fma4),
        .llvm_name = "fma4",
        .description = "Enable four-operand fused multiple-add",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.fsgsbase)] = .{
        .index = @enumToInt(Feature.fsgsbase),
        .name = @tagName(Feature.fsgsbase),
        .llvm_name = "fsgsbase",
        .description = "Support FS/GS Base instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fxsr)] = .{
        .index = @enumToInt(Feature.fxsr),
        .name = @tagName(Feature.fxsr),
        .llvm_name = "fxsr",
        .description = "Support fxsave/fxrestore instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_11bytenop)] = .{
        .index = @enumToInt(Feature.fast_11bytenop),
        .name = @tagName(Feature.fast_11bytenop),
        .llvm_name = "fast-11bytenop",
        .description = "Target can quickly decode up to 11 byte NOPs",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_15bytenop)] = .{
        .index = @enumToInt(Feature.fast_15bytenop),
        .name = @tagName(Feature.fast_15bytenop),
        .llvm_name = "fast-15bytenop",
        .description = "Target can quickly decode up to 15 byte NOPs",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_bextr)] = .{
        .index = @enumToInt(Feature.fast_bextr),
        .name = @tagName(Feature.fast_bextr),
        .llvm_name = "fast-bextr",
        .description = "Indicates that the BEXTR instruction is implemented as a single uop with good throughput",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_hops)] = .{
        .index = @enumToInt(Feature.fast_hops),
        .name = @tagName(Feature.fast_hops),
        .llvm_name = "fast-hops",
        .description = "Prefer horizontal vector math instructions (haddp, phsub, etc.) over normal vector instructions with shuffles",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.fast_lzcnt)] = .{
        .index = @enumToInt(Feature.fast_lzcnt),
        .name = @tagName(Feature.fast_lzcnt),
        .llvm_name = "fast-lzcnt",
        .description = "LZCNT instructions are as fast as most simple integer ops",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_partial_ymm_or_zmm_write)] = .{
        .index = @enumToInt(Feature.fast_partial_ymm_or_zmm_write),
        .name = @tagName(Feature.fast_partial_ymm_or_zmm_write),
        .llvm_name = "fast-partial-ymm-or-zmm-write",
        .description = "Partial writes to YMM/ZMM registers are fast",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_shld_rotate)] = .{
        .index = @enumToInt(Feature.fast_shld_rotate),
        .name = @tagName(Feature.fast_shld_rotate),
        .llvm_name = "fast-shld-rotate",
        .description = "SHLD can be used as a faster rotate",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_scalar_fsqrt)] = .{
        .index = @enumToInt(Feature.fast_scalar_fsqrt),
        .name = @tagName(Feature.fast_scalar_fsqrt),
        .llvm_name = "fast-scalar-fsqrt",
        .description = "Scalar SQRT is fast (disable Newton-Raphson)",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_scalar_shift_masks)] = .{
        .index = @enumToInt(Feature.fast_scalar_shift_masks),
        .name = @tagName(Feature.fast_scalar_shift_masks),
        .llvm_name = "fast-scalar-shift-masks",
        .description = "Prefer a left/right scalar logical shift pair over a shift+and pair",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_variable_shuffle)] = .{
        .index = @enumToInt(Feature.fast_variable_shuffle),
        .name = @tagName(Feature.fast_variable_shuffle),
        .llvm_name = "fast-variable-shuffle",
        .description = "Shuffles with variable masks are fast",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_vector_fsqrt)] = .{
        .index = @enumToInt(Feature.fast_vector_fsqrt),
        .name = @tagName(Feature.fast_vector_fsqrt),
        .llvm_name = "fast-vector-fsqrt",
        .description = "Vector SQRT is fast (disable Newton-Raphson)",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.fast_vector_shift_masks)] = .{
        .index = @enumToInt(Feature.fast_vector_shift_masks),
        .name = @tagName(Feature.fast_vector_shift_masks),
        .llvm_name = "fast-vector-shift-masks",
        .description = "Prefer a left/right vector logical shift pair over a shift+and pair",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.gfni)] = .{
        .index = @enumToInt(Feature.gfni),
        .name = @tagName(Feature.gfni),
        .llvm_name = "gfni",
        .description = "Enable Galois Field Arithmetic Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.fast_gather)] = .{
        .index = @enumToInt(Feature.fast_gather),
        .name = @tagName(Feature.fast_gather),
        .llvm_name = "fast-gather",
        .description = "Indicates if gather is reasonably fast",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.avx512ifma)] = .{
        .index = @enumToInt(Feature.avx512ifma),
        .name = @tagName(Feature.avx512ifma),
        .llvm_name = "avx512ifma",
        .description = "Enable AVX-512 Integer Fused Multiple-Add",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.invpcid)] = .{
        .index = @enumToInt(Feature.invpcid),
        .name = @tagName(Feature.invpcid),
        .llvm_name = "invpcid",
        .description = "Invalidate Process-Context Identifier",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.sahf)] = .{
        .index = @enumToInt(Feature.sahf),
        .name = @tagName(Feature.sahf),
        .llvm_name = "sahf",
        .description = "Support LAHF and SAHF instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.lea_sp)] = .{
        .index = @enumToInt(Feature.lea_sp),
        .name = @tagName(Feature.lea_sp),
        .llvm_name = "lea-sp",
        .description = "Use LEA for adjusting the stack pointer",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.lea_uses_ag)] = .{
        .index = @enumToInt(Feature.lea_uses_ag),
        .name = @tagName(Feature.lea_uses_ag),
        .llvm_name = "lea-uses-ag",
        .description = "LEA instruction needs inputs at AG stage",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.lwp)] = .{
        .index = @enumToInt(Feature.lwp),
        .name = @tagName(Feature.lwp),
        .llvm_name = "lwp",
        .description = "Enable LWP instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.lzcnt)] = .{
        .index = @enumToInt(Feature.lzcnt),
        .name = @tagName(Feature.lzcnt),
        .llvm_name = "lzcnt",
        .description = "Support LZCNT instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.false_deps_lzcnt_tzcnt)] = .{
        .index = @enumToInt(Feature.false_deps_lzcnt_tzcnt),
        .name = @tagName(Feature.false_deps_lzcnt_tzcnt),
        .llvm_name = "false-deps-lzcnt-tzcnt",
        .description = "LZCNT/TZCNT have a false dependency on dest register",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.mmx)] = .{
        .index = @enumToInt(Feature.mmx),
        .name = @tagName(Feature.mmx),
        .llvm_name = "mmx",
        .description = "Enable MMX instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.movbe)] = .{
        .index = @enumToInt(Feature.movbe),
        .name = @tagName(Feature.movbe),
        .llvm_name = "movbe",
        .description = "Support MOVBE instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.movdir64b)] = .{
        .index = @enumToInt(Feature.movdir64b),
        .name = @tagName(Feature.movdir64b),
        .llvm_name = "movdir64b",
        .description = "Support movdir64b instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.movdiri)] = .{
        .index = @enumToInt(Feature.movdiri),
        .name = @tagName(Feature.movdiri),
        .llvm_name = "movdiri",
        .description = "Support movdiri instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.mpx)] = .{
        .index = @enumToInt(Feature.mpx),
        .name = @tagName(Feature.mpx),
        .llvm_name = "mpx",
        .description = "Support MPX instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.mwaitx)] = .{
        .index = @enumToInt(Feature.mwaitx),
        .name = @tagName(Feature.mwaitx),
        .llvm_name = "mwaitx",
        .description = "Enable MONITORX/MWAITX timer functionality",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.macrofusion)] = .{
        .index = @enumToInt(Feature.macrofusion),
        .name = @tagName(Feature.macrofusion),
        .llvm_name = "macrofusion",
        .description = "Various instructions can be fused with conditional branches",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.merge_to_threeway_branch)] = .{
        .index = @enumToInt(Feature.merge_to_threeway_branch),
        .name = @tagName(Feature.merge_to_threeway_branch),
        .llvm_name = "merge-to-threeway-branch",
        .description = "Merge branches to a three-way conditional branch",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.nopl)] = .{
        .index = @enumToInt(Feature.nopl),
        .name = @tagName(Feature.nopl),
        .llvm_name = "nopl",
        .description = "Enable NOPL instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.pclmul)] = .{
        .index = @enumToInt(Feature.pclmul),
        .name = @tagName(Feature.pclmul),
        .llvm_name = "pclmul",
        .description = "Enable packed carry-less multiplication instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.pconfig)] = .{
        .index = @enumToInt(Feature.pconfig),
        .name = @tagName(Feature.pconfig),
        .llvm_name = "pconfig",
        .description = "platform configuration instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.avx512pf)] = .{
        .index = @enumToInt(Feature.avx512pf),
        .name = @tagName(Feature.avx512pf),
        .llvm_name = "avx512pf",
        .description = "Enable AVX-512 PreFetch Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.pku)] = .{
        .index = @enumToInt(Feature.pku),
        .name = @tagName(Feature.pku),
        .llvm_name = "pku",
        .description = "Enable protection keys",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.popcnt)] = .{
        .index = @enumToInt(Feature.popcnt),
        .name = @tagName(Feature.popcnt),
        .llvm_name = "popcnt",
        .description = "Support POPCNT instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.false_deps_popcnt)] = .{
        .index = @enumToInt(Feature.false_deps_popcnt),
        .name = @tagName(Feature.false_deps_popcnt),
        .llvm_name = "false-deps-popcnt",
        .description = "POPCNT has a false dependency on dest register",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.prefetchwt1)] = .{
        .index = @enumToInt(Feature.prefetchwt1),
        .name = @tagName(Feature.prefetchwt1),
        .llvm_name = "prefetchwt1",
        .description = "Prefetch with Intent to Write and T1 Hint",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.prfchw)] = .{
        .index = @enumToInt(Feature.prfchw),
        .name = @tagName(Feature.prfchw),
        .llvm_name = "prfchw",
        .description = "Support PRFCHW instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.ptwrite)] = .{
        .index = @enumToInt(Feature.ptwrite),
        .name = @tagName(Feature.ptwrite),
        .llvm_name = "ptwrite",
        .description = "Support ptwrite instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.pad_short_functions)] = .{
        .index = @enumToInt(Feature.pad_short_functions),
        .name = @tagName(Feature.pad_short_functions),
        .llvm_name = "pad-short-functions",
        .description = "Pad short functions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.prefer_256_bit)] = .{
        .index = @enumToInt(Feature.prefer_256_bit),
        .name = @tagName(Feature.prefer_256_bit),
        .llvm_name = "prefer-256-bit",
        .description = "Prefer 256-bit AVX instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.rdpid)] = .{
        .index = @enumToInt(Feature.rdpid),
        .name = @tagName(Feature.rdpid),
        .llvm_name = "rdpid",
        .description = "Support RDPID instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.rdrnd)] = .{
        .index = @enumToInt(Feature.rdrnd),
        .name = @tagName(Feature.rdrnd),
        .llvm_name = "rdrnd",
        .description = "Support RDRAND instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.rdseed)] = .{
        .index = @enumToInt(Feature.rdseed),
        .name = @tagName(Feature.rdseed),
        .llvm_name = "rdseed",
        .description = "Support RDSEED instruction",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.rtm)] = .{
        .index = @enumToInt(Feature.rtm),
        .name = @tagName(Feature.rtm),
        .llvm_name = "rtm",
        .description = "Support RTM instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.retpoline)] = .{
        .index = @enumToInt(Feature.retpoline),
        .name = @tagName(Feature.retpoline),
        .llvm_name = "retpoline",
        .description = "Remove speculation of indirect branches from the generated code, either by avoiding them entirely or lowering them with a speculation blocking construct",
        .dependencies = featureSet(&[_]Feature{
            .retpoline_indirect_calls,
            .retpoline_indirect_branches,
        }),
    };

    result[@enumToInt(Feature.retpoline_external_thunk)] = .{
        .index = @enumToInt(Feature.retpoline_external_thunk),
        .name = @tagName(Feature.retpoline_external_thunk),
        .llvm_name = "retpoline-external-thunk",
        .description = "When lowering an indirect call or branch using a `retpoline`, rely on the specified user provided thunk rather than emitting one ourselves. Only has effect when combined with some other retpoline feature",
        .dependencies = featureSet(&[_]Feature{
            .retpoline_indirect_calls,
        }),
    };

    result[@enumToInt(Feature.retpoline_indirect_branches)] = .{
        .index = @enumToInt(Feature.retpoline_indirect_branches),
        .name = @tagName(Feature.retpoline_indirect_branches),
        .llvm_name = "retpoline-indirect-branches",
        .description = "Remove speculation of indirect branches from the generated code",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.retpoline_indirect_calls)] = .{
        .index = @enumToInt(Feature.retpoline_indirect_calls),
        .name = @tagName(Feature.retpoline_indirect_calls),
        .llvm_name = "retpoline-indirect-calls",
        .description = "Remove speculation of indirect calls from the generated code",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.sgx)] = .{
        .index = @enumToInt(Feature.sgx),
        .name = @tagName(Feature.sgx),
        .llvm_name = "sgx",
        .description = "Enable Software Guard Extensions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.sha)] = .{
        .index = @enumToInt(Feature.sha),
        .name = @tagName(Feature.sha),
        .llvm_name = "sha",
        .description = "Enable SHA instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.shstk)] = .{
        .index = @enumToInt(Feature.shstk),
        .name = @tagName(Feature.shstk),
        .llvm_name = "shstk",
        .description = "Support CET Shadow-Stack instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.sse)] = .{
        .index = @enumToInt(Feature.sse),
        .name = @tagName(Feature.sse),
        .llvm_name = "sse",
        .description = "Enable SSE instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.sse2)] = .{
        .index = @enumToInt(Feature.sse2),
        .name = @tagName(Feature.sse2),
        .llvm_name = "sse2",
        .description = "Enable SSE2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.sse3)] = .{
        .index = @enumToInt(Feature.sse3),
        .name = @tagName(Feature.sse3),
        .llvm_name = "sse3",
        .description = "Enable SSE3 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.sse4a)] = .{
        .index = @enumToInt(Feature.sse4a),
        .name = @tagName(Feature.sse4a),
        .llvm_name = "sse4a",
        .description = "Support SSE 4a instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.sse4_1)] = .{
        .index = @enumToInt(Feature.sse4_1),
        .name = @tagName(Feature.sse4_1),
        .llvm_name = "sse4.1",
        .description = "Enable SSE 4.1 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.sse4_2)] = .{
        .index = @enumToInt(Feature.sse4_2),
        .name = @tagName(Feature.sse4_2),
        .llvm_name = "sse4.2",
        .description = "Enable SSE 4.2 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.sse_unaligned_mem)] = .{
        .index = @enumToInt(Feature.sse_unaligned_mem),
        .name = @tagName(Feature.sse_unaligned_mem),
        .llvm_name = "sse-unaligned-mem",
        .description = "Allow unaligned memory operands with SSE instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.ssse3)] = .{
        .index = @enumToInt(Feature.ssse3),
        .name = @tagName(Feature.ssse3),
        .llvm_name = "ssse3",
        .description = "Enable SSSE3 instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.slow_3ops_lea)] = .{
        .index = @enumToInt(Feature.slow_3ops_lea),
        .name = @tagName(Feature.slow_3ops_lea),
        .llvm_name = "slow-3ops-lea",
        .description = "LEA instruction with 3 ops or certain registers is slow",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.idivl_to_divb)] = .{
        .index = @enumToInt(Feature.idivl_to_divb),
        .name = @tagName(Feature.idivl_to_divb),
        .llvm_name = "idivl-to-divb",
        .description = "Use 8-bit divide for positive values less than 256",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.idivq_to_divl)] = .{
        .index = @enumToInt(Feature.idivq_to_divl),
        .name = @tagName(Feature.idivq_to_divl),
        .llvm_name = "idivq-to-divl",
        .description = "Use 32-bit divide for positive values less than 2^32",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_incdec)] = .{
        .index = @enumToInt(Feature.slow_incdec),
        .name = @tagName(Feature.slow_incdec),
        .llvm_name = "slow-incdec",
        .description = "INC and DEC instructions are slower than ADD and SUB",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_lea)] = .{
        .index = @enumToInt(Feature.slow_lea),
        .name = @tagName(Feature.slow_lea),
        .llvm_name = "slow-lea",
        .description = "LEA instruction with certain arguments is slow",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_pmaddwd)] = .{
        .index = @enumToInt(Feature.slow_pmaddwd),
        .name = @tagName(Feature.slow_pmaddwd),
        .llvm_name = "slow-pmaddwd",
        .description = "PMADDWD is slower than PMULLD",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_pmulld)] = .{
        .index = @enumToInt(Feature.slow_pmulld),
        .name = @tagName(Feature.slow_pmulld),
        .llvm_name = "slow-pmulld",
        .description = "PMULLD instruction is slow",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_shld)] = .{
        .index = @enumToInt(Feature.slow_shld),
        .name = @tagName(Feature.slow_shld),
        .llvm_name = "slow-shld",
        .description = "SHLD instruction is slow",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_two_mem_ops)] = .{
        .index = @enumToInt(Feature.slow_two_mem_ops),
        .name = @tagName(Feature.slow_two_mem_ops),
        .llvm_name = "slow-two-mem-ops",
        .description = "Two memory operand instructions are slow",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_unaligned_mem_16)] = .{
        .index = @enumToInt(Feature.slow_unaligned_mem_16),
        .name = @tagName(Feature.slow_unaligned_mem_16),
        .llvm_name = "slow-unaligned-mem-16",
        .description = "Slow unaligned 16-byte memory access",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.slow_unaligned_mem_32)] = .{
        .index = @enumToInt(Feature.slow_unaligned_mem_32),
        .name = @tagName(Feature.slow_unaligned_mem_32),
        .llvm_name = "slow-unaligned-mem-32",
        .description = "Slow unaligned 32-byte memory access",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.soft_float)] = .{
        .index = @enumToInt(Feature.soft_float),
        .name = @tagName(Feature.soft_float),
        .llvm_name = "soft-float",
        .description = "Use software floating point features",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.tbm)] = .{
        .index = @enumToInt(Feature.tbm),
        .name = @tagName(Feature.tbm),
        .llvm_name = "tbm",
        .description = "Enable TBM instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.vaes)] = .{
        .index = @enumToInt(Feature.vaes),
        .name = @tagName(Feature.vaes),
        .llvm_name = "vaes",
        .description = "Promote selected AES instructions to AVX512/AVX registers",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vbmi)] = .{
        .index = @enumToInt(Feature.avx512vbmi),
        .name = @tagName(Feature.avx512vbmi),
        .llvm_name = "avx512vbmi",
        .description = "Enable AVX-512 Vector Byte Manipulation Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vbmi2)] = .{
        .index = @enumToInt(Feature.avx512vbmi2),
        .name = @tagName(Feature.avx512vbmi2),
        .llvm_name = "avx512vbmi2",
        .description = "Enable AVX-512 further Vector Byte Manipulation Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vl)] = .{
        .index = @enumToInt(Feature.avx512vl),
        .name = @tagName(Feature.avx512vl),
        .llvm_name = "avx512vl",
        .description = "Enable AVX-512 Vector Length eXtensions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vnni)] = .{
        .index = @enumToInt(Feature.avx512vnni),
        .name = @tagName(Feature.avx512vnni),
        .llvm_name = "avx512vnni",
        .description = "Enable AVX-512 Vector Neural Network Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vp2intersect)] = .{
        .index = @enumToInt(Feature.avx512vp2intersect),
        .name = @tagName(Feature.avx512vp2intersect),
        .llvm_name = "avx512vp2intersect",
        .description = "Enable AVX-512 vp2intersect",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.vpclmulqdq)] = .{
        .index = @enumToInt(Feature.vpclmulqdq),
        .name = @tagName(Feature.vpclmulqdq),
        .llvm_name = "vpclmulqdq",
        .description = "Enable vpclmulqdq instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.avx512vpopcntdq)] = .{
        .index = @enumToInt(Feature.avx512vpopcntdq),
        .name = @tagName(Feature.avx512vpopcntdq),
        .llvm_name = "avx512vpopcntdq",
        .description = "Enable AVX-512 Population Count Instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.waitpkg)] = .{
        .index = @enumToInt(Feature.waitpkg),
        .name = @tagName(Feature.waitpkg),
        .llvm_name = "waitpkg",
        .description = "Wait and pause enhancements",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.wbnoinvd)] = .{
        .index = @enumToInt(Feature.wbnoinvd),
        .name = @tagName(Feature.wbnoinvd),
        .llvm_name = "wbnoinvd",
        .description = "Write Back No Invalidate",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.x87)] = .{
        .index = @enumToInt(Feature.x87),
        .name = @tagName(Feature.x87),
        .llvm_name = "x87",
        .description = "Enable X87 float instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.xop)] = .{
        .index = @enumToInt(Feature.xop),
        .name = @tagName(Feature.xop),
        .llvm_name = "xop",
        .description = "Enable XOP instructions",
        .dependencies = featureSet(&[_]Feature{
            .sse,
        }),
    };

    result[@enumToInt(Feature.xsave)] = .{
        .index = @enumToInt(Feature.xsave),
        .name = @tagName(Feature.xsave),
        .llvm_name = "xsave",
        .description = "Support xsave instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.xsavec)] = .{
        .index = @enumToInt(Feature.xsavec),
        .name = @tagName(Feature.xsavec),
        .llvm_name = "xsavec",
        .description = "Support xsavec instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.xsaveopt)] = .{
        .index = @enumToInt(Feature.xsaveopt),
        .name = @tagName(Feature.xsaveopt),
        .llvm_name = "xsaveopt",
        .description = "Support xsaveopt instructions",
        .dependencies = 0,
    };

    result[@enumToInt(Feature.xsaves)] = .{
        .index = @enumToInt(Feature.xsaves),
        .name = @tagName(Feature.xsaves),
        .llvm_name = "xsaves",
        .description = "Support xsaves instructions",
        .dependencies = 0,
    };

    break :blk result;
};

pub const cpu = struct {
    pub const amdfam10 = Cpu{
        .name = "amdfam10",
        .llvm_name = "amdfam10",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_scalar_shift_masks,
            .sahf,
            .lzcnt,
            .nopl,
            .popcnt,
            .sse,
            .sse4a,
            .slow_shld,
            .x87,
        }),
    };

    pub const athlon = Cpu{
        .name = "athlon",
        .llvm_name = "athlon",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cmov,
            .cx8,
            .nopl,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon4 = Cpu{
        .name = "athlon_4",
        .llvm_name = "athlon-4",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cmov,
            .cx8,
            .fxsr,
            .nopl,
            .sse,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon_fx = Cpu{
        .name = "athlon_fx",
        .llvm_name = "athlon-fx",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse2,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon_mp = Cpu{
        .name = "athlon_mp",
        .llvm_name = "athlon-mp",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cmov,
            .cx8,
            .fxsr,
            .nopl,
            .sse,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon_tbird = Cpu{
        .name = "athlon_tbird",
        .llvm_name = "athlon-tbird",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cmov,
            .cx8,
            .nopl,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon_xp = Cpu{
        .name = "athlon_xp",
        .llvm_name = "athlon-xp",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cmov,
            .cx8,
            .fxsr,
            .nopl,
            .sse,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon64 = Cpu{
        .name = "athlon64",
        .llvm_name = "athlon64",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse2,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const athlon64_sse3 = Cpu{
        .name = "athlon64_sse3",
        .llvm_name = "athlon64-sse3",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse3,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const atom = Cpu{
        .name = "atom",
        .llvm_name = "atom",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .lea_sp,
            .lea_uses_ag,
            .mmx,
            .movbe,
            .nopl,
            .pad_short_functions,
            .sse,
            .ssse3,
            .idivl_to_divb,
            .idivq_to_divl,
            .slow_two_mem_ops,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const barcelona = Cpu{
        .name = "barcelona",
        .llvm_name = "barcelona",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_scalar_shift_masks,
            .sahf,
            .lzcnt,
            .nopl,
            .popcnt,
            .sse,
            .sse4a,
            .slow_shld,
            .x87,
        }),
    };

    pub const bdver1 = Cpu{
        .name = "bdver1",
        .llvm_name = "bdver1",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .branchfusion,
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_11bytenop,
            .fast_scalar_shift_masks,
            .sahf,
            .lwp,
            .lzcnt,
            .mmx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .slow_shld,
            .x87,
            .xop,
            .xsave,
        }),
    };

    pub const bdver2 = Cpu{
        .name = "bdver2",
        .llvm_name = "bdver2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .bmi,
            .branchfusion,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fma,
            .fxsr,
            .fast_11bytenop,
            .fast_bextr,
            .fast_scalar_shift_masks,
            .sahf,
            .lwp,
            .lzcnt,
            .mmx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .slow_shld,
            .tbm,
            .x87,
            .xop,
            .xsave,
        }),
    };

    pub const bdver3 = Cpu{
        .name = "bdver3",
        .llvm_name = "bdver3",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .bmi,
            .branchfusion,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_11bytenop,
            .fast_bextr,
            .fast_scalar_shift_masks,
            .sahf,
            .lwp,
            .lzcnt,
            .mmx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .slow_shld,
            .tbm,
            .x87,
            .xop,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const bdver4 = Cpu{
        .name = "bdver4",
        .llvm_name = "bdver4",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .avx2,
            .bmi,
            .bmi2,
            .branchfusion,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_11bytenop,
            .fast_bextr,
            .fast_scalar_shift_masks,
            .sahf,
            .lwp,
            .lzcnt,
            .mmx,
            .mwaitx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .slow_shld,
            .tbm,
            .x87,
            .xop,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const bonnell = Cpu{
        .name = "bonnell",
        .llvm_name = "bonnell",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .lea_sp,
            .lea_uses_ag,
            .mmx,
            .movbe,
            .nopl,
            .pad_short_functions,
            .sse,
            .ssse3,
            .idivl_to_divb,
            .idivq_to_divl,
            .slow_two_mem_ops,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const broadwell = Cpu{
        .name = "broadwell",
        .llvm_name = "broadwell",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .avx,
            .avx2,
            .bmi,
            .bmi2,
            .cmov,
            .cx8,
            .cx16,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .invpcid,
            .sahf,
            .lzcnt,
            .false_deps_lzcnt_tzcnt,
            .mmx,
            .movbe,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const btver1 = Cpu{
        .name = "btver1",
        .llvm_name = "btver1",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_15bytenop,
            .fast_scalar_shift_masks,
            .fast_vector_shift_masks,
            .sahf,
            .lzcnt,
            .mmx,
            .nopl,
            .popcnt,
            .prfchw,
            .sse,
            .sse4a,
            .ssse3,
            .slow_shld,
            .x87,
        }),
    };

    pub const btver2 = Cpu{
        .name = "btver2",
        .llvm_name = "btver2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .avx,
            .bmi,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fxsr,
            .fast_15bytenop,
            .fast_bextr,
            .fast_hops,
            .fast_lzcnt,
            .fast_partial_ymm_or_zmm_write,
            .fast_scalar_shift_masks,
            .fast_vector_shift_masks,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .sse4a,
            .ssse3,
            .slow_shld,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const c3 = Cpu{
        .name = "c3",
        .llvm_name = "c3",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnow",
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const c32 = Cpu{
        .name = "c3_2",
        .llvm_name = "c3-2",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .sse,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const cannonlake = Cpu{
        .name = "cannonlake",
        .llvm_name = "cannonlake",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .avx512ifma,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sgx,
            .sha,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .avx512vbmi,
            .avx512vl,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const cascadelake = Cpu{
        .name = "cascadelake",
        .llvm_name = "cascadelake",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .avx512vl,
            .avx512vnni,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const cooperlake = Cpu{
        .name = "cooperlake",
        .llvm_name = "cooperlake",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .avx512bf16,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .avx512vl,
            .avx512vnni,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const core_avx_i = Cpu{
        .name = "core_avx_i",
        .llvm_name = "core-avx-i",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .sahf,
            .mmx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .rdrnd,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_unaligned_mem_32,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const core_avx2 = Cpu{
        .name = "core_avx2",
        .llvm_name = "core-avx2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .avx2,
            .bmi,
            .bmi2,
            .cmov,
            .cx8,
            .cx16,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .invpcid,
            .sahf,
            .lzcnt,
            .false_deps_lzcnt_tzcnt,
            .mmx,
            .movbe,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .rdrnd,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const core2 = Cpu{
        .name = "core2",
        .llvm_name = "core2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .macrofusion,
            .nopl,
            .sse,
            .ssse3,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const corei7 = Cpu{
        .name = "corei7",
        .llvm_name = "corei7",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .macrofusion,
            .nopl,
            .popcnt,
            .sse,
            .sse4_2,
            .x87,
        }),
    };

    pub const corei7_avx = Cpu{
        .name = "corei7_avx",
        .llvm_name = "corei7-avx",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .sahf,
            .mmx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_unaligned_mem_32,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const generic = Cpu{
        .name = "generic",
        .llvm_name = "generic",
        .features = featureSet(&[_]Feature{
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const geode = Cpu{
        .name = "geode",
        .llvm_name = "geode",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const goldmont = Cpu{
        .name = "goldmont",
        .llvm_name = "goldmont",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .clflushopt,
            .cmov,
            .cx8,
            .cx16,
            .fsgsbase,
            .fxsr,
            .sahf,
            .mmx,
            .movbe,
            .mpx,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sha,
            .sse4_2,
            .ssse3,
            .slow_incdec,
            .slow_lea,
            .slow_two_mem_ops,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const goldmont_plus = Cpu{
        .name = "goldmont_plus",
        .llvm_name = "goldmont-plus",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .clflushopt,
            .cmov,
            .cx8,
            .cx16,
            .fsgsbase,
            .fxsr,
            .sahf,
            .mmx,
            .movbe,
            .mpx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .ptwrite,
            .rdpid,
            .rdrnd,
            .rdseed,
            .sgx,
            .sha,
            .sse4_2,
            .ssse3,
            .slow_incdec,
            .slow_lea,
            .slow_two_mem_ops,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const haswell = Cpu{
        .name = "haswell",
        .llvm_name = "haswell",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .avx2,
            .bmi,
            .bmi2,
            .cmov,
            .cx8,
            .cx16,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .invpcid,
            .sahf,
            .lzcnt,
            .false_deps_lzcnt_tzcnt,
            .mmx,
            .movbe,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .rdrnd,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const _i386 = Cpu{
        .name = "_i386",
        .llvm_name = "i386",
        .features = featureSet(&[_]Feature{
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const _i486 = Cpu{
        .name = "_i486",
        .llvm_name = "i486",
        .features = featureSet(&[_]Feature{
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const _i586 = Cpu{
        .name = "_i586",
        .llvm_name = "i586",
        .features = featureSet(&[_]Feature{
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const _i686 = Cpu{
        .name = "_i686",
        .llvm_name = "i686",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const icelake_client = Cpu{
        .name = "icelake_client",
        .llvm_name = "icelake-client",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .avx512bitalg,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .gfni,
            .fast_gather,
            .avx512ifma,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .prfchw,
            .rdpid,
            .rdrnd,
            .rdseed,
            .sgx,
            .sha,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .vaes,
            .avx512vbmi,
            .avx512vbmi2,
            .avx512vl,
            .avx512vnni,
            .vpclmulqdq,
            .avx512vpopcntdq,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const icelake_server = Cpu{
        .name = "icelake_server",
        .llvm_name = "icelake-server",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .avx512bitalg,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .gfni,
            .fast_gather,
            .avx512ifma,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pconfig,
            .pku,
            .popcnt,
            .prfchw,
            .rdpid,
            .rdrnd,
            .rdseed,
            .sgx,
            .sha,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .vaes,
            .avx512vbmi,
            .avx512vbmi2,
            .avx512vl,
            .avx512vnni,
            .vpclmulqdq,
            .avx512vpopcntdq,
            .wbnoinvd,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const ivybridge = Cpu{
        .name = "ivybridge",
        .llvm_name = "ivybridge",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .sahf,
            .mmx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .rdrnd,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_unaligned_mem_32,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const k6 = Cpu{
        .name = "k6",
        .llvm_name = "k6",
        .features = featureSet(&[_]Feature{
            .cx8,
            .mmx,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const k62 = Cpu{
        .name = "k6_2",
        .llvm_name = "k6-2",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnow",
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const k63 = Cpu{
        .name = "k6_3",
        .llvm_name = "k6-3",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnow",
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const k8 = Cpu{
        .name = "k8",
        .llvm_name = "k8",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse2,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const k8_sse3 = Cpu{
        .name = "k8_sse3",
        .llvm_name = "k8-sse3",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse3,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const knl = Cpu{
        .name = "knl",
        .llvm_name = "knl",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512cd,
            .cmov,
            .cx8,
            .cx16,
            .avx512er,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_partial_ymm_or_zmm_write,
            .fast_gather,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .nopl,
            .pclmul,
            .avx512pf,
            .popcnt,
            .prefetchwt1,
            .prfchw,
            .rdrnd,
            .rdseed,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_incdec,
            .slow_pmaddwd,
            .slow_two_mem_ops,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const knm = Cpu{
        .name = "knm",
        .llvm_name = "knm",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512cd,
            .cmov,
            .cx8,
            .cx16,
            .avx512er,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_partial_ymm_or_zmm_write,
            .fast_gather,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .nopl,
            .pclmul,
            .avx512pf,
            .popcnt,
            .prefetchwt1,
            .prfchw,
            .rdrnd,
            .rdseed,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_incdec,
            .slow_pmaddwd,
            .slow_two_mem_ops,
            .avx512vpopcntdq,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const lakemont = Cpu{
        .name = "lakemont",
        .llvm_name = "lakemont",
        .features = 0,
    };

    pub const nehalem = Cpu{
        .name = "nehalem",
        .llvm_name = "nehalem",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .macrofusion,
            .nopl,
            .popcnt,
            .sse,
            .sse4_2,
            .x87,
        }),
    };

    pub const nocona = Cpu{
        .name = "nocona",
        .llvm_name = "nocona",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse3,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const opteron = Cpu{
        .name = "opteron",
        .llvm_name = "opteron",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse2,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const opteron_sse3 = Cpu{
        .name = "opteron_sse3",
        .llvm_name = "opteron-sse3",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnowa",
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_scalar_shift_masks,
            .nopl,
            .sse,
            .sse3,
            .slow_shld,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const penryn = Cpu{
        .name = "penryn",
        .llvm_name = "penryn",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .macrofusion,
            .nopl,
            .sse,
            .sse4_1,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium = Cpu{
        .name = "pentium",
        .llvm_name = "pentium",
        .features = featureSet(&[_]Feature{
            .cx8,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium_m = Cpu{
        .name = "pentium_m",
        .llvm_name = "pentium-m",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse2,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium_mmx = Cpu{
        .name = "pentium_mmx",
        .llvm_name = "pentium-mmx",
        .features = featureSet(&[_]Feature{
            .cx8,
            .mmx,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium2 = Cpu{
        .name = "pentium2",
        .llvm_name = "pentium2",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium3 = Cpu{
        .name = "pentium3",
        .llvm_name = "pentium3",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium3m = Cpu{
        .name = "pentium3m",
        .llvm_name = "pentium3m",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium4 = Cpu{
        .name = "pentium4",
        .llvm_name = "pentium4",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse2,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentium4m = Cpu{
        .name = "pentium4m",
        .llvm_name = "pentium4m",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse2,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const pentiumpro = Cpu{
        .name = "pentiumpro",
        .llvm_name = "pentiumpro",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .nopl,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const prescott = Cpu{
        .name = "prescott",
        .llvm_name = "prescott",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse3,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const sandybridge = Cpu{
        .name = "sandybridge",
        .llvm_name = "sandybridge",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .avx,
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .sahf,
            .mmx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .slow_unaligned_mem_32,
            .x87,
            .xsave,
            .xsaveopt,
        }),
    };

    pub const silvermont = Cpu{
        .name = "silvermont",
        .llvm_name = "silvermont",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .movbe,
            .nopl,
            .sse,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .sse4_2,
            .ssse3,
            .idivq_to_divl,
            .slow_incdec,
            .slow_lea,
            .slow_pmulld,
            .slow_two_mem_ops,
            .x87,
        }),
    };

    pub const skx = Cpu{
        .name = "skx",
        .llvm_name = "skx",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .avx512vl,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const skylake = Cpu{
        .name = "skylake",
        .llvm_name = "skylake",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .bmi,
            .bmi2,
            .clflushopt,
            .cmov,
            .cx8,
            .cx16,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sgx,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const skylake_avx512 = Cpu{
        .name = "skylake_avx512",
        .llvm_name = "skylake-avx512",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx,
            .avx2,
            .avx512f,
            .bmi,
            .bmi2,
            .avx512bw,
            .avx512cd,
            .clflushopt,
            .clwb,
            .cmov,
            .cx8,
            .cx16,
            .avx512dq,
            .ermsb,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_shld_rotate,
            .fast_scalar_fsqrt,
            .fast_variable_shuffle,
            .fast_vector_fsqrt,
            .fast_gather,
            .invpcid,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mpx,
            .macrofusion,
            .merge_to_threeway_branch,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sse4_2,
            .slow_3ops_lea,
            .idivq_to_divl,
            .avx512vl,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const slm = Cpu{
        .name = "slm",
        .llvm_name = "slm",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .movbe,
            .nopl,
            .sse,
            .pclmul,
            .popcnt,
            .false_deps_popcnt,
            .prfchw,
            .rdrnd,
            .sse4_2,
            .ssse3,
            .idivq_to_divl,
            .slow_incdec,
            .slow_lea,
            .slow_pmulld,
            .slow_two_mem_ops,
            .x87,
        }),
    };

    pub const tremont = Cpu{
        .name = "tremont",
        .llvm_name = "tremont",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .sse,
            .aes,
            .cldemote,
            .clflushopt,
            .cmov,
            .cx8,
            .cx16,
            .fsgsbase,
            .fxsr,
            .gfni,
            .sahf,
            .mmx,
            .movbe,
            .movdir64b,
            .movdiri,
            .mpx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .ptwrite,
            .rdpid,
            .rdrnd,
            .rdseed,
            .sgx,
            .sha,
            .sse4_2,
            .ssse3,
            .slow_incdec,
            .slow_lea,
            .slow_two_mem_ops,
            .waitpkg,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const westmere = Cpu{
        .name = "westmere",
        .llvm_name = "westmere",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .cx16,
            .fxsr,
            .sahf,
            .mmx,
            .macrofusion,
            .nopl,
            .sse,
            .pclmul,
            .popcnt,
            .sse4_2,
            .x87,
        }),
    };

    pub const winchip_c6 = Cpu{
        .name = "winchip_c6",
        .llvm_name = "winchip-c6",
        .features = featureSet(&[_]Feature{
            .mmx,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const winchip2 = Cpu{
        .name = "winchip2",
        .llvm_name = "winchip2",
        .features = featureSet(&[_]Feature{
            .mmx,
            .@"3dnow",
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const x86_64 = Cpu{
        .name = "x86_64",
        .llvm_name = "x86-64",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .macrofusion,
            .nopl,
            .sse,
            .sse2,
            .slow_3ops_lea,
            .slow_incdec,
            .x87,
        }),
    };

    pub const yonah = Cpu{
        .name = "yonah",
        .llvm_name = "yonah",
        .features = featureSet(&[_]Feature{
            .cmov,
            .cx8,
            .fxsr,
            .mmx,
            .nopl,
            .sse,
            .sse3,
            .slow_unaligned_mem_16,
            .x87,
        }),
    };

    pub const znver1 = Cpu{
        .name = "znver1",
        .llvm_name = "znver1",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx2,
            .bmi,
            .bmi2,
            .branchfusion,
            .clflushopt,
            .clzero,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_15bytenop,
            .fast_bextr,
            .fast_lzcnt,
            .fast_scalar_shift_masks,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mwaitx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .rdrnd,
            .rdseed,
            .sha,
            .sse4a,
            .slow_shld,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };

    pub const znver2 = Cpu{
        .name = "znver2",
        .llvm_name = "znver2",
        .features = featureSet(&[_]Feature{
            .@"64bit",
            .adx,
            .sse,
            .aes,
            .avx2,
            .bmi,
            .bmi2,
            .branchfusion,
            .clflushopt,
            .clwb,
            .clzero,
            .cmov,
            .cx8,
            .cx16,
            .f16c,
            .fma,
            .fsgsbase,
            .fxsr,
            .fast_15bytenop,
            .fast_bextr,
            .fast_lzcnt,
            .fast_scalar_shift_masks,
            .sahf,
            .lzcnt,
            .mmx,
            .movbe,
            .mwaitx,
            .nopl,
            .pclmul,
            .popcnt,
            .prfchw,
            .rdpid,
            .rdrnd,
            .rdseed,
            .sha,
            .sse4a,
            .slow_shld,
            .wbnoinvd,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };
};

pub const all_cpus = &[_]*const Cpu{
    &cpu.amdfam10,
    &cpu.athlon,
    &cpu.athlon4,
    &cpu.athlon_fx,
    &cpu.athlon_mp,
    &cpu.athlon_tbird,
    &cpu.athlon_xp,
    &cpu.athlon64,
    &cpu.athlon64_sse3,
    &cpu.atom,
    &cpu.barcelona,
    &cpu.bdver1,
    &cpu.bdver2,
    &cpu.bdver3,
    &cpu.bdver4,
    &cpu.bonnell,
    &cpu.broadwell,
    &cpu.btver1,
    &cpu.btver2,
    &cpu.c3,
    &cpu.c32,
    &cpu.cannonlake,
    &cpu.cascadelake,
    &cpu.cooperlake,
    &cpu.core_avx_i,
    &cpu.core_avx2,
    &cpu.core2,
    &cpu.corei7,
    &cpu.corei7_avx,
    &cpu.generic,
    &cpu.geode,
    &cpu.goldmont,
    &cpu.goldmont_plus,
    &cpu.haswell,
    &cpu._i386,
    &cpu._i486,
    &cpu._i586,
    &cpu._i686,
    &cpu.icelake_client,
    &cpu.icelake_server,
    &cpu.ivybridge,
    &cpu.k6,
    &cpu.k62,
    &cpu.k63,
    &cpu.k8,
    &cpu.k8_sse3,
    &cpu.knl,
    &cpu.knm,
    &cpu.lakemont,
    &cpu.nehalem,
    &cpu.nocona,
    &cpu.opteron,
    &cpu.opteron_sse3,
    &cpu.penryn,
    &cpu.pentium,
    &cpu.pentium_m,
    &cpu.pentium_mmx,
    &cpu.pentium2,
    &cpu.pentium3,
    &cpu.pentium3m,
    &cpu.pentium4,
    &cpu.pentium4m,
    &cpu.pentiumpro,
    &cpu.prescott,
    &cpu.sandybridge,
    &cpu.silvermont,
    &cpu.skx,
    &cpu.skylake,
    &cpu.skylake_avx512,
    &cpu.slm,
    &cpu.tremont,
    &cpu.westmere,
    &cpu.winchip_c6,
    &cpu.winchip2,
    &cpu.x86_64,
    &cpu.yonah,
    &cpu.znver1,
    &cpu.znver2,
};
