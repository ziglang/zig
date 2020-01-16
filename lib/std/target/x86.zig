const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_dnow3 = Feature{
    .name = "dnow3",
    .llvm_name = "3dnow",
    .description = "Enable 3DNow! instructions",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
    },
};

pub const feature_dnowa3 = Feature{
    .name = "dnowa3",
    .llvm_name = "3dnowa",
    .description = "Enable 3DNow! Athlon instructions",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
    },
};

pub const feature_bit64 = Feature{
    .name = "bit64",
    .llvm_name = "64bit",
    .description = "Support 64-bit instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_adx = Feature{
    .name = "adx",
    .llvm_name = "adx",
    .description = "Support ADX instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_aes = Feature{
    .name = "aes",
    .llvm_name = "aes",
    .description = "Enable AES instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx = Feature{
    .name = "avx",
    .llvm_name = "avx",
    .description = "Enable AVX instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx2 = Feature{
    .name = "avx2",
    .llvm_name = "avx2",
    .description = "Enable AVX2 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512f = Feature{
    .name = "avx512f",
    .llvm_name = "avx512f",
    .description = "Enable AVX-512 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512bf16 = Feature{
    .name = "avx512bf16",
    .llvm_name = "avx512bf16",
    .description = "Support bfloat16 floating point",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512bitalg = Feature{
    .name = "avx512bitalg",
    .llvm_name = "avx512bitalg",
    .description = "Enable AVX-512 Bit Algorithms",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_bmi = Feature{
    .name = "bmi",
    .llvm_name = "bmi",
    .description = "Support BMI instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bmi2 = Feature{
    .name = "bmi2",
    .llvm_name = "bmi2",
    .description = "Support BMI2 instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avx512bw = Feature{
    .name = "avx512bw",
    .llvm_name = "avx512bw",
    .description = "Enable AVX-512 Byte and Word Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_branchfusion = Feature{
    .name = "branchfusion",
    .llvm_name = "branchfusion",
    .description = "CMP/TEST can be fused with conditional branches",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avx512cd = Feature{
    .name = "avx512cd",
    .llvm_name = "avx512cd",
    .description = "Enable AVX-512 Conflict Detection Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_cldemote = Feature{
    .name = "cldemote",
    .llvm_name = "cldemote",
    .description = "Enable Cache Demote",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_clflushopt = Feature{
    .name = "clflushopt",
    .llvm_name = "clflushopt",
    .description = "Flush A Cache Line Optimized",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_clwb = Feature{
    .name = "clwb",
    .llvm_name = "clwb",
    .description = "Cache Line Write Back",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_clzero = Feature{
    .name = "clzero",
    .llvm_name = "clzero",
    .description = "Enable Cache Line Zero",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_cmov = Feature{
    .name = "cmov",
    .llvm_name = "cmov",
    .description = "Enable conditional move instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_cx8 = Feature{
    .name = "cx8",
    .llvm_name = "cx8",
    .description = "Support CMPXCHG8B instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_cx16 = Feature{
    .name = "cx16",
    .llvm_name = "cx16",
    .description = "64-bit with cmpxchg16b",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
    },
};

pub const feature_avx512dq = Feature{
    .name = "avx512dq",
    .llvm_name = "avx512dq",
    .description = "Enable AVX-512 Doubleword and Quadword Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_enqcmd = Feature{
    .name = "enqcmd",
    .llvm_name = "enqcmd",
    .description = "Has ENQCMD instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avx512er = Feature{
    .name = "avx512er",
    .llvm_name = "avx512er",
    .description = "Enable AVX-512 Exponential and Reciprocal Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_ermsb = Feature{
    .name = "ermsb",
    .llvm_name = "ermsb",
    .description = "REP MOVS/STOS are fast",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_f16c = Feature{
    .name = "f16c",
    .llvm_name = "f16c",
    .description = "Support 16-bit floating point conversion instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_fma = Feature{
    .name = "fma",
    .llvm_name = "fma",
    .description = "Enable three-operand fused multiple-add",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_fma4 = Feature{
    .name = "fma4",
    .llvm_name = "fma4",
    .description = "Enable four-operand fused multiple-add",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_fsgsbase = Feature{
    .name = "fsgsbase",
    .llvm_name = "fsgsbase",
    .description = "Support FS/GS Base instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fxsr = Feature{
    .name = "fxsr",
    .llvm_name = "fxsr",
    .description = "Support fxsave/fxrestore instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fast11bytenop = Feature{
    .name = "fast11bytenop",
    .llvm_name = "fast-11bytenop",
    .description = "Target can quickly decode up to 11 byte NOPs",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fast15bytenop = Feature{
    .name = "fast15bytenop",
    .llvm_name = "fast-15bytenop",
    .description = "Target can quickly decode up to 15 byte NOPs",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastBextr = Feature{
    .name = "fastBextr",
    .llvm_name = "fast-bextr",
    .description = "Indicates that the BEXTR instruction is implemented as a single uop with good throughput",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastHops = Feature{
    .name = "fastHops",
    .llvm_name = "fast-hops",
    .description = "Prefer horizontal vector math instructions (haddp, phsub, etc.) over normal vector instructions with shuffles",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_fastLzcnt = Feature{
    .name = "fastLzcnt",
    .llvm_name = "fast-lzcnt",
    .description = "LZCNT instructions are as fast as most simple integer ops",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastPartialYmmOrZmmWrite = Feature{
    .name = "fastPartialYmmOrZmmWrite",
    .llvm_name = "fast-partial-ymm-or-zmm-write",
    .description = "Partial writes to YMM/ZMM registers are fast",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastShldRotate = Feature{
    .name = "fastShldRotate",
    .llvm_name = "fast-shld-rotate",
    .description = "SHLD can be used as a faster rotate",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastScalarFsqrt = Feature{
    .name = "fastScalarFsqrt",
    .llvm_name = "fast-scalar-fsqrt",
    .description = "Scalar SQRT is fast (disable Newton-Raphson)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastScalarShiftMasks = Feature{
    .name = "fastScalarShiftMasks",
    .llvm_name = "fast-scalar-shift-masks",
    .description = "Prefer a left/right scalar logical shift pair over a shift+and pair",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastVariableShuffle = Feature{
    .name = "fastVariableShuffle",
    .llvm_name = "fast-variable-shuffle",
    .description = "Shuffles with variable masks are fast",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastVectorFsqrt = Feature{
    .name = "fastVectorFsqrt",
    .llvm_name = "fast-vector-fsqrt",
    .description = "Vector SQRT is fast (disable Newton-Raphson)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_fastVectorShiftMasks = Feature{
    .name = "fastVectorShiftMasks",
    .llvm_name = "fast-vector-shift-masks",
    .description = "Prefer a left/right vector logical shift pair over a shift+and pair",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_gfni = Feature{
    .name = "gfni",
    .llvm_name = "gfni",
    .description = "Enable Galois Field Arithmetic Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_fastGather = Feature{
    .name = "fastGather",
    .llvm_name = "fast-gather",
    .description = "Indicates if gather is reasonably fast",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avx512ifma = Feature{
    .name = "avx512ifma",
    .llvm_name = "avx512ifma",
    .description = "Enable AVX-512 Integer Fused Multiple-Add",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_invpcid = Feature{
    .name = "invpcid",
    .llvm_name = "invpcid",
    .description = "Invalidate Process-Context Identifier",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sahf = Feature{
    .name = "sahf",
    .llvm_name = "sahf",
    .description = "Support LAHF and SAHF instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_leaSp = Feature{
    .name = "leaSp",
    .llvm_name = "lea-sp",
    .description = "Use LEA for adjusting the stack pointer",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_leaUsesAg = Feature{
    .name = "leaUsesAg",
    .llvm_name = "lea-uses-ag",
    .description = "LEA instruction needs inputs at AG stage",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lwp = Feature{
    .name = "lwp",
    .llvm_name = "lwp",
    .description = "Enable LWP instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_lzcnt = Feature{
    .name = "lzcnt",
    .llvm_name = "lzcnt",
    .description = "Support LZCNT instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_falseDepsLzcntTzcnt = Feature{
    .name = "falseDepsLzcntTzcnt",
    .llvm_name = "false-deps-lzcnt-tzcnt",
    .description = "LZCNT/TZCNT have a false dependency on dest register",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mmx = Feature{
    .name = "mmx",
    .llvm_name = "mmx",
    .description = "Enable MMX instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_movbe = Feature{
    .name = "movbe",
    .llvm_name = "movbe",
    .description = "Support MOVBE instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_movdir64b = Feature{
    .name = "movdir64b",
    .llvm_name = "movdir64b",
    .description = "Support movdir64b instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_movdiri = Feature{
    .name = "movdiri",
    .llvm_name = "movdiri",
    .description = "Support movdiri instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mpx = Feature{
    .name = "mpx",
    .llvm_name = "mpx",
    .description = "Support MPX instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mwaitx = Feature{
    .name = "mwaitx",
    .llvm_name = "mwaitx",
    .description = "Enable MONITORX/MWAITX timer functionality",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_macrofusion = Feature{
    .name = "macrofusion",
    .llvm_name = "macrofusion",
    .description = "Various instructions can be fused with conditional branches",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mergeToThreewayBranch = Feature{
    .name = "mergeToThreewayBranch",
    .llvm_name = "merge-to-threeway-branch",
    .description = "Merge branches to a three-way conditional branch",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nopl = Feature{
    .name = "nopl",
    .llvm_name = "nopl",
    .description = "Enable NOPL instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_pclmul = Feature{
    .name = "pclmul",
    .llvm_name = "pclmul",
    .description = "Enable packed carry-less multiplication instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_pconfig = Feature{
    .name = "pconfig",
    .llvm_name = "pconfig",
    .description = "platform configuration instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_avx512pf = Feature{
    .name = "avx512pf",
    .llvm_name = "avx512pf",
    .description = "Enable AVX-512 PreFetch Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_pku = Feature{
    .name = "pku",
    .llvm_name = "pku",
    .description = "Enable protection keys",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_popcnt = Feature{
    .name = "popcnt",
    .llvm_name = "popcnt",
    .description = "Support POPCNT instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_falseDepsPopcnt = Feature{
    .name = "falseDepsPopcnt",
    .llvm_name = "false-deps-popcnt",
    .description = "POPCNT has a false dependency on dest register",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_prefetchwt1 = Feature{
    .name = "prefetchwt1",
    .llvm_name = "prefetchwt1",
    .description = "Prefetch with Intent to Write and T1 Hint",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_prfchw = Feature{
    .name = "prfchw",
    .llvm_name = "prfchw",
    .description = "Support PRFCHW instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ptwrite = Feature{
    .name = "ptwrite",
    .llvm_name = "ptwrite",
    .description = "Support ptwrite instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_padShortFunctions = Feature{
    .name = "padShortFunctions",
    .llvm_name = "pad-short-functions",
    .description = "Pad short functions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_prefer256Bit = Feature{
    .name = "prefer256Bit",
    .llvm_name = "prefer-256-bit",
    .description = "Prefer 256-bit AVX instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rdpid = Feature{
    .name = "rdpid",
    .llvm_name = "rdpid",
    .description = "Support RDPID instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rdrnd = Feature{
    .name = "rdrnd",
    .llvm_name = "rdrnd",
    .description = "Support RDRAND instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rdseed = Feature{
    .name = "rdseed",
    .llvm_name = "rdseed",
    .description = "Support RDSEED instruction",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_rtm = Feature{
    .name = "rtm",
    .llvm_name = "rtm",
    .description = "Support RTM instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_retpoline = Feature{
    .name = "retpoline",
    .llvm_name = "retpoline",
    .description = "Remove speculation of indirect branches from the generated code, either by avoiding them entirely or lowering them with a speculation blocking construct",
    .dependencies = &[_]*const Feature {
        &feature_retpolineIndirectCalls,
        &feature_retpolineIndirectBranches,
    },
};

pub const feature_retpolineExternalThunk = Feature{
    .name = "retpolineExternalThunk",
    .llvm_name = "retpoline-external-thunk",
    .description = "When lowering an indirect call or branch using a `retpoline`, rely on the specified user provided thunk rather than emitting one ourselves. Only has effect when combined with some other retpoline feature",
    .dependencies = &[_]*const Feature {
        &feature_retpolineIndirectCalls,
    },
};

pub const feature_retpolineIndirectBranches = Feature{
    .name = "retpolineIndirectBranches",
    .llvm_name = "retpoline-indirect-branches",
    .description = "Remove speculation of indirect branches from the generated code",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_retpolineIndirectCalls = Feature{
    .name = "retpolineIndirectCalls",
    .llvm_name = "retpoline-indirect-calls",
    .description = "Remove speculation of indirect calls from the generated code",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sgx = Feature{
    .name = "sgx",
    .llvm_name = "sgx",
    .description = "Enable Software Guard Extensions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sha = Feature{
    .name = "sha",
    .llvm_name = "sha",
    .description = "Enable SHA instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_shstk = Feature{
    .name = "shstk",
    .llvm_name = "shstk",
    .description = "Support CET Shadow-Stack instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sse = Feature{
    .name = "sse",
    .llvm_name = "sse",
    .description = "Enable SSE instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_sse2 = Feature{
    .name = "sse2",
    .llvm_name = "sse2",
    .description = "Enable SSE2 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_sse3 = Feature{
    .name = "sse3",
    .llvm_name = "sse3",
    .description = "Enable SSE3 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_sse4a = Feature{
    .name = "sse4a",
    .llvm_name = "sse4a",
    .description = "Support SSE 4a instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_sse41 = Feature{
    .name = "sse41",
    .llvm_name = "sse4.1",
    .description = "Enable SSE 4.1 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_sse42 = Feature{
    .name = "sse42",
    .llvm_name = "sse4.2",
    .description = "Enable SSE 4.2 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_sseUnalignedMem = Feature{
    .name = "sseUnalignedMem",
    .llvm_name = "sse-unaligned-mem",
    .description = "Allow unaligned memory operands with SSE instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_ssse3 = Feature{
    .name = "ssse3",
    .llvm_name = "ssse3",
    .description = "Enable SSSE3 instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_slow3opsLea = Feature{
    .name = "slow3opsLea",
    .llvm_name = "slow-3ops-lea",
    .description = "LEA instruction with 3 ops or certain registers is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_idivlToDivb = Feature{
    .name = "idivlToDivb",
    .llvm_name = "idivl-to-divb",
    .description = "Use 8-bit divide for positive values less than 256",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_idivqToDivl = Feature{
    .name = "idivqToDivl",
    .llvm_name = "idivq-to-divl",
    .description = "Use 32-bit divide for positive values less than 2^32",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowIncdec = Feature{
    .name = "slowIncdec",
    .llvm_name = "slow-incdec",
    .description = "INC and DEC instructions are slower than ADD and SUB",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowLea = Feature{
    .name = "slowLea",
    .llvm_name = "slow-lea",
    .description = "LEA instruction with certain arguments is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowPmaddwd = Feature{
    .name = "slowPmaddwd",
    .llvm_name = "slow-pmaddwd",
    .description = "PMADDWD is slower than PMULLD",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowPmulld = Feature{
    .name = "slowPmulld",
    .llvm_name = "slow-pmulld",
    .description = "PMULLD instruction is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowShld = Feature{
    .name = "slowShld",
    .llvm_name = "slow-shld",
    .description = "SHLD instruction is slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowTwoMemOps = Feature{
    .name = "slowTwoMemOps",
    .llvm_name = "slow-two-mem-ops",
    .description = "Two memory operand instructions are slow",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowUnalignedMem16 = Feature{
    .name = "slowUnalignedMem16",
    .llvm_name = "slow-unaligned-mem-16",
    .description = "Slow unaligned 16-byte memory access",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_slowUnalignedMem32 = Feature{
    .name = "slowUnalignedMem32",
    .llvm_name = "slow-unaligned-mem-32",
    .description = "Slow unaligned 32-byte memory access",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_softFloat = Feature{
    .name = "softFloat",
    .llvm_name = "soft-float",
    .description = "Use software floating point features",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_tbm = Feature{
    .name = "tbm",
    .llvm_name = "tbm",
    .description = "Enable TBM instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_vaes = Feature{
    .name = "vaes",
    .llvm_name = "vaes",
    .description = "Promote selected AES instructions to AVX512/AVX registers",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vbmi = Feature{
    .name = "avx512vbmi",
    .llvm_name = "avx512vbmi",
    .description = "Enable AVX-512 Vector Byte Manipulation Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vbmi2 = Feature{
    .name = "avx512vbmi2",
    .llvm_name = "avx512vbmi2",
    .description = "Enable AVX-512 further Vector Byte Manipulation Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vl = Feature{
    .name = "avx512vl",
    .llvm_name = "avx512vl",
    .description = "Enable AVX-512 Vector Length eXtensions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vnni = Feature{
    .name = "avx512vnni",
    .llvm_name = "avx512vnni",
    .description = "Enable AVX-512 Vector Neural Network Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vp2intersect = Feature{
    .name = "avx512vp2intersect",
    .llvm_name = "avx512vp2intersect",
    .description = "Enable AVX-512 vp2intersect",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_vpclmulqdq = Feature{
    .name = "vpclmulqdq",
    .llvm_name = "vpclmulqdq",
    .description = "Enable vpclmulqdq instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_avx512vpopcntdq = Feature{
    .name = "avx512vpopcntdq",
    .llvm_name = "avx512vpopcntdq",
    .description = "Enable AVX-512 Population Count Instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_waitpkg = Feature{
    .name = "waitpkg",
    .llvm_name = "waitpkg",
    .description = "Wait and pause enhancements",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_wbnoinvd = Feature{
    .name = "wbnoinvd",
    .llvm_name = "wbnoinvd",
    .description = "Write Back No Invalidate",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_x87 = Feature{
    .name = "x87",
    .llvm_name = "x87",
    .description = "Enable X87 float instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_xop = Feature{
    .name = "xop",
    .llvm_name = "xop",
    .description = "Enable XOP instructions",
    .dependencies = &[_]*const Feature {
        &feature_sse,
    },
};

pub const feature_xsave = Feature{
    .name = "xsave",
    .llvm_name = "xsave",
    .description = "Support xsave instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_xsavec = Feature{
    .name = "xsavec",
    .llvm_name = "xsavec",
    .description = "Support xsavec instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_xsaveopt = Feature{
    .name = "xsaveopt",
    .llvm_name = "xsaveopt",
    .description = "Support xsaveopt instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_xsaves = Feature{
    .name = "xsaves",
    .llvm_name = "xsaves",
    .description = "Support xsaves instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bitMode16 = Feature{
    .name = "bitMode16",
    .llvm_name = "16bit-mode",
    .description = "16-bit mode (i8086)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bitMode32 = Feature{
    .name = "bitMode32",
    .llvm_name = "32bit-mode",
    .description = "32-bit mode (80386)",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bitMode64 = Feature{
    .name = "bitMode64",
    .llvm_name = "64bit-mode",
    .description = "64-bit mode (x86_64)",
    .dependencies = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_dnow3,
    &feature_dnowa3,
    &feature_bit64,
    &feature_adx,
    &feature_aes,
    &feature_avx,
    &feature_avx2,
    &feature_avx512f,
    &feature_avx512bf16,
    &feature_avx512bitalg,
    &feature_bmi,
    &feature_bmi2,
    &feature_avx512bw,
    &feature_branchfusion,
    &feature_avx512cd,
    &feature_cldemote,
    &feature_clflushopt,
    &feature_clwb,
    &feature_clzero,
    &feature_cmov,
    &feature_cx8,
    &feature_cx16,
    &feature_avx512dq,
    &feature_enqcmd,
    &feature_avx512er,
    &feature_ermsb,
    &feature_f16c,
    &feature_fma,
    &feature_fma4,
    &feature_fsgsbase,
    &feature_fxsr,
    &feature_fast11bytenop,
    &feature_fast15bytenop,
    &feature_fastBextr,
    &feature_fastHops,
    &feature_fastLzcnt,
    &feature_fastPartialYmmOrZmmWrite,
    &feature_fastShldRotate,
    &feature_fastScalarFsqrt,
    &feature_fastScalarShiftMasks,
    &feature_fastVariableShuffle,
    &feature_fastVectorFsqrt,
    &feature_fastVectorShiftMasks,
    &feature_gfni,
    &feature_fastGather,
    &feature_avx512ifma,
    &feature_invpcid,
    &feature_sahf,
    &feature_leaSp,
    &feature_leaUsesAg,
    &feature_lwp,
    &feature_lzcnt,
    &feature_falseDepsLzcntTzcnt,
    &feature_mmx,
    &feature_movbe,
    &feature_movdir64b,
    &feature_movdiri,
    &feature_mpx,
    &feature_mwaitx,
    &feature_macrofusion,
    &feature_mergeToThreewayBranch,
    &feature_nopl,
    &feature_pclmul,
    &feature_pconfig,
    &feature_avx512pf,
    &feature_pku,
    &feature_popcnt,
    &feature_falseDepsPopcnt,
    &feature_prefetchwt1,
    &feature_prfchw,
    &feature_ptwrite,
    &feature_padShortFunctions,
    &feature_prefer256Bit,
    &feature_rdpid,
    &feature_rdrnd,
    &feature_rdseed,
    &feature_rtm,
    &feature_retpoline,
    &feature_retpolineExternalThunk,
    &feature_retpolineIndirectBranches,
    &feature_retpolineIndirectCalls,
    &feature_sgx,
    &feature_sha,
    &feature_shstk,
    &feature_sse,
    &feature_sse2,
    &feature_sse3,
    &feature_sse4a,
    &feature_sse41,
    &feature_sse42,
    &feature_sseUnalignedMem,
    &feature_ssse3,
    &feature_slow3opsLea,
    &feature_idivlToDivb,
    &feature_idivqToDivl,
    &feature_slowIncdec,
    &feature_slowLea,
    &feature_slowPmaddwd,
    &feature_slowPmulld,
    &feature_slowShld,
    &feature_slowTwoMemOps,
    &feature_slowUnalignedMem16,
    &feature_slowUnalignedMem32,
    &feature_softFloat,
    &feature_tbm,
    &feature_vaes,
    &feature_avx512vbmi,
    &feature_avx512vbmi2,
    &feature_avx512vl,
    &feature_avx512vnni,
    &feature_avx512vp2intersect,
    &feature_vpclmulqdq,
    &feature_avx512vpopcntdq,
    &feature_waitpkg,
    &feature_wbnoinvd,
    &feature_x87,
    &feature_xop,
    &feature_xsave,
    &feature_xsavec,
    &feature_xsaveopt,
    &feature_xsaves,
    &feature_bitMode16,
    &feature_bitMode32,
    &feature_bitMode64,
};

pub const cpu_amdfam10 = Cpu{
    .name = "amdfam10",
    .llvm_name = "amdfam10",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_nopl,
        &feature_popcnt,
        &feature_sse,
        &feature_sse4a,
        &feature_slowShld,
        &feature_x87,
    },
};

pub const cpu_athlon = Cpu{
    .name = "athlon",
    .llvm_name = "athlon",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cmov,
        &feature_cx8,
        &feature_nopl,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlon4 = Cpu{
    .name = "athlon4",
    .llvm_name = "athlon-4",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_nopl,
        &feature_sse,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlonFx = Cpu{
    .name = "athlonFx",
    .llvm_name = "athlon-fx",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlonMp = Cpu{
    .name = "athlonMp",
    .llvm_name = "athlon-mp",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_nopl,
        &feature_sse,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlonTbird = Cpu{
    .name = "athlonTbird",
    .llvm_name = "athlon-tbird",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cmov,
        &feature_cx8,
        &feature_nopl,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlonXp = Cpu{
    .name = "athlonXp",
    .llvm_name = "athlon-xp",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_nopl,
        &feature_sse,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlon64 = Cpu{
    .name = "athlon64",
    .llvm_name = "athlon64",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_athlon64Sse3 = Cpu{
    .name = "athlon64Sse3",
    .llvm_name = "athlon64-sse3",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_atom = Cpu{
    .name = "atom",
    .llvm_name = "atom",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_leaSp,
        &feature_leaUsesAg,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_padShortFunctions,
        &feature_sse,
        &feature_ssse3,
        &feature_idivlToDivb,
        &feature_idivqToDivl,
        &feature_slowTwoMemOps,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_barcelona = Cpu{
    .name = "barcelona",
    .llvm_name = "barcelona",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_nopl,
        &feature_popcnt,
        &feature_sse,
        &feature_sse4a,
        &feature_slowShld,
        &feature_x87,
    },
};

pub const cpu_bdver1 = Cpu{
    .name = "bdver1",
    .llvm_name = "bdver1",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_branchfusion,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fast11bytenop,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lwp,
        &feature_lzcnt,
        &feature_mmx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_slowShld,
        &feature_x87,
        &feature_xop,
        &feature_xsave,
    },
};

pub const cpu_bdver2 = Cpu{
    .name = "bdver2",
    .llvm_name = "bdver2",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_bmi,
        &feature_branchfusion,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fma,
        &feature_fxsr,
        &feature_fast11bytenop,
        &feature_fastBextr,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lwp,
        &feature_lzcnt,
        &feature_mmx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_slowShld,
        &feature_tbm,
        &feature_x87,
        &feature_xop,
        &feature_xsave,
    },
};

pub const cpu_bdver3 = Cpu{
    .name = "bdver3",
    .llvm_name = "bdver3",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_bmi,
        &feature_branchfusion,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fast11bytenop,
        &feature_fastBextr,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lwp,
        &feature_lzcnt,
        &feature_mmx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_slowShld,
        &feature_tbm,
        &feature_x87,
        &feature_xop,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_bdver4 = Cpu{
    .name = "bdver4",
    .llvm_name = "bdver4",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_branchfusion,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fast11bytenop,
        &feature_fastBextr,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lwp,
        &feature_lzcnt,
        &feature_mmx,
        &feature_mwaitx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_slowShld,
        &feature_tbm,
        &feature_x87,
        &feature_xop,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_bonnell = Cpu{
    .name = "bonnell",
    .llvm_name = "bonnell",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_leaSp,
        &feature_leaUsesAg,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_padShortFunctions,
        &feature_sse,
        &feature_ssse3,
        &feature_idivlToDivb,
        &feature_idivqToDivl,
        &feature_slowTwoMemOps,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_broadwell = Cpu{
    .name = "broadwell",
    .llvm_name = "broadwell",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_avx,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_falseDepsLzcntTzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_btver1 = Cpu{
    .name = "btver1",
    .llvm_name = "btver1",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fast15bytenop,
        &feature_fastScalarShiftMasks,
        &feature_fastVectorShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_nopl,
        &feature_popcnt,
        &feature_prfchw,
        &feature_sse,
        &feature_sse4a,
        &feature_ssse3,
        &feature_slowShld,
        &feature_x87,
    },
};

pub const cpu_btver2 = Cpu{
    .name = "btver2",
    .llvm_name = "btver2",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_bmi,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fxsr,
        &feature_fast15bytenop,
        &feature_fastBextr,
        &feature_fastHops,
        &feature_fastLzcnt,
        &feature_fastPartialYmmOrZmmWrite,
        &feature_fastScalarShiftMasks,
        &feature_fastVectorShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_sse4a,
        &feature_ssse3,
        &feature_slowShld,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_c3 = Cpu{
    .name = "c3",
    .llvm_name = "c3",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnow3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_c32 = Cpu{
    .name = "c32",
    .llvm_name = "c3-2",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_sse,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_cannonlake = Cpu{
    .name = "cannonlake",
    .llvm_name = "cannonlake",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_avx512ifma,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sha,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_avx512vbmi,
        &feature_avx512vl,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_cascadelake = Cpu{
    .name = "cascadelake",
    .llvm_name = "cascadelake",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_avx512vl,
        &feature_avx512vnni,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_cooperlake = Cpu{
    .name = "cooperlake",
    .llvm_name = "cooperlake",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_avx512bf16,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_avx512vl,
        &feature_avx512vnni,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_coreAvxI = Cpu{
    .name = "coreAvxI",
    .llvm_name = "core-avx-i",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_rdrnd,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowUnalignedMem32,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_coreAvx2 = Cpu{
    .name = "coreAvx2",
    .llvm_name = "core-avx2",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_falseDepsLzcntTzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_rdrnd,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_core2 = Cpu{
    .name = "core2",
    .llvm_name = "core2",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_sse,
        &feature_ssse3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_corei7 = Cpu{
    .name = "corei7",
    .llvm_name = "corei7",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_popcnt,
        &feature_sse,
        &feature_sse42,
        &feature_x87,
    },
};

pub const cpu_corei7Avx = Cpu{
    .name = "corei7Avx",
    .llvm_name = "corei7-avx",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowUnalignedMem32,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_geode = Cpu{
    .name = "geode",
    .llvm_name = "geode",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_goldmont = Cpu{
    .name = "goldmont",
    .llvm_name = "goldmont",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_clflushopt,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sha,
        &feature_sse42,
        &feature_ssse3,
        &feature_slowIncdec,
        &feature_slowLea,
        &feature_slowTwoMemOps,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_goldmontPlus = Cpu{
    .name = "goldmontPlus",
    .llvm_name = "goldmont-plus",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_clflushopt,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_ptwrite,
        &feature_rdpid,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sha,
        &feature_sse42,
        &feature_ssse3,
        &feature_slowIncdec,
        &feature_slowLea,
        &feature_slowTwoMemOps,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_haswell = Cpu{
    .name = "haswell",
    .llvm_name = "haswell",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_falseDepsLzcntTzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_rdrnd,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_i386 = Cpu{
    .name = "i386",
    .llvm_name = "i386",
    .dependencies = &[_]*const Feature {
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_i486 = Cpu{
    .name = "i486",
    .llvm_name = "i486",
    .dependencies = &[_]*const Feature {
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_i586 = Cpu{
    .name = "i586",
    .llvm_name = "i586",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_i686 = Cpu{
    .name = "i686",
    .llvm_name = "i686",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_icelakeClient = Cpu{
    .name = "icelakeClient",
    .llvm_name = "icelake-client",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_avx512bitalg,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_gfni,
        &feature_fastGather,
        &feature_avx512ifma,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_prfchw,
        &feature_rdpid,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sha,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_vaes,
        &feature_avx512vbmi,
        &feature_avx512vbmi2,
        &feature_avx512vl,
        &feature_avx512vnni,
        &feature_vpclmulqdq,
        &feature_avx512vpopcntdq,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_icelakeServer = Cpu{
    .name = "icelakeServer",
    .llvm_name = "icelake-server",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_avx512bitalg,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_gfni,
        &feature_fastGather,
        &feature_avx512ifma,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pconfig,
        &feature_pku,
        &feature_popcnt,
        &feature_prfchw,
        &feature_rdpid,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sha,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_vaes,
        &feature_avx512vbmi,
        &feature_avx512vbmi2,
        &feature_avx512vl,
        &feature_avx512vnni,
        &feature_vpclmulqdq,
        &feature_avx512vpopcntdq,
        &feature_wbnoinvd,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_ivybridge = Cpu{
    .name = "ivybridge",
    .llvm_name = "ivybridge",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_rdrnd,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowUnalignedMem32,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_k6 = Cpu{
    .name = "k6",
    .llvm_name = "k6",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
        &feature_mmx,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_k62 = Cpu{
    .name = "k62",
    .llvm_name = "k6-2",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnow3,
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_k63 = Cpu{
    .name = "k63",
    .llvm_name = "k6-3",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnow3,
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_k8 = Cpu{
    .name = "k8",
    .llvm_name = "k8",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_k8Sse3 = Cpu{
    .name = "k8Sse3",
    .llvm_name = "k8-sse3",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_knl = Cpu{
    .name = "knl",
    .llvm_name = "knl",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512cd,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512er,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastPartialYmmOrZmmWrite,
        &feature_fastGather,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_pclmul,
        &feature_avx512pf,
        &feature_popcnt,
        &feature_prefetchwt1,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowIncdec,
        &feature_slowPmaddwd,
        &feature_slowTwoMemOps,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_knm = Cpu{
    .name = "knm",
    .llvm_name = "knm",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512cd,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512er,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastPartialYmmOrZmmWrite,
        &feature_fastGather,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_pclmul,
        &feature_avx512pf,
        &feature_popcnt,
        &feature_prefetchwt1,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowIncdec,
        &feature_slowPmaddwd,
        &feature_slowTwoMemOps,
        &feature_avx512vpopcntdq,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_lakemont = Cpu{
    .name = "lakemont",
    .llvm_name = "lakemont",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_nehalem = Cpu{
    .name = "nehalem",
    .llvm_name = "nehalem",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_popcnt,
        &feature_sse,
        &feature_sse42,
        &feature_x87,
    },
};

pub const cpu_nocona = Cpu{
    .name = "nocona",
    .llvm_name = "nocona",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_opteron = Cpu{
    .name = "opteron",
    .llvm_name = "opteron",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_opteronSse3 = Cpu{
    .name = "opteronSse3",
    .llvm_name = "opteron-sse3",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnowa3,
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastScalarShiftMasks,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowShld,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_penryn = Cpu{
    .name = "penryn",
    .llvm_name = "penryn",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_sse,
        &feature_sse41,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium = Cpu{
    .name = "pentium",
    .llvm_name = "pentium",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentiumM = Cpu{
    .name = "pentiumM",
    .llvm_name = "pentium-m",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentiumMmx = Cpu{
    .name = "pentiumMmx",
    .llvm_name = "pentium-mmx",
    .dependencies = &[_]*const Feature {
        &feature_cx8,
        &feature_mmx,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium2 = Cpu{
    .name = "pentium2",
    .llvm_name = "pentium2",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium3 = Cpu{
    .name = "pentium3",
    .llvm_name = "pentium3",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium3m = Cpu{
    .name = "pentium3m",
    .llvm_name = "pentium3m",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium4 = Cpu{
    .name = "pentium4",
    .llvm_name = "pentium4",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentium4m = Cpu{
    .name = "pentium4m",
    .llvm_name = "pentium4m",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_pentiumpro = Cpu{
    .name = "pentiumpro",
    .llvm_name = "pentiumpro",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_nopl,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_prescott = Cpu{
    .name = "prescott",
    .llvm_name = "prescott",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_sandybridge = Cpu{
    .name = "sandybridge",
    .llvm_name = "sandybridge",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_avx,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_slowUnalignedMem32,
        &feature_x87,
        &feature_xsave,
        &feature_xsaveopt,
    },
};

pub const cpu_silvermont = Cpu{
    .name = "silvermont",
    .llvm_name = "silvermont",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_sse,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_sse42,
        &feature_ssse3,
        &feature_idivqToDivl,
        &feature_slowIncdec,
        &feature_slowLea,
        &feature_slowPmulld,
        &feature_slowTwoMemOps,
        &feature_x87,
    },
};

pub const cpu_skx = Cpu{
    .name = "skx",
    .llvm_name = "skx",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_avx512vl,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_skylake = Cpu{
    .name = "skylake",
    .llvm_name = "skylake",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_clflushopt,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_skylakeAvx512 = Cpu{
    .name = "skylakeAvx512",
    .llvm_name = "skylake-avx512",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx,
        &feature_avx2,
        &feature_avx512f,
        &feature_bmi,
        &feature_bmi2,
        &feature_avx512bw,
        &feature_avx512cd,
        &feature_clflushopt,
        &feature_clwb,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_avx512dq,
        &feature_ermsb,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fastShldRotate,
        &feature_fastScalarFsqrt,
        &feature_fastVariableShuffle,
        &feature_fastVectorFsqrt,
        &feature_fastGather,
        &feature_invpcid,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mpx,
        &feature_macrofusion,
        &feature_mergeToThreewayBranch,
        &feature_nopl,
        &feature_pclmul,
        &feature_pku,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sse42,
        &feature_slow3opsLea,
        &feature_idivqToDivl,
        &feature_avx512vl,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_slm = Cpu{
    .name = "slm",
    .llvm_name = "slm",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_movbe,
        &feature_nopl,
        &feature_sse,
        &feature_pclmul,
        &feature_popcnt,
        &feature_falseDepsPopcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_sse42,
        &feature_ssse3,
        &feature_idivqToDivl,
        &feature_slowIncdec,
        &feature_slowLea,
        &feature_slowPmulld,
        &feature_slowTwoMemOps,
        &feature_x87,
    },
};

pub const cpu_tremont = Cpu{
    .name = "tremont",
    .llvm_name = "tremont",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_sse,
        &feature_aes,
        &feature_cldemote,
        &feature_clflushopt,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_gfni,
        &feature_sahf,
        &feature_mmx,
        &feature_movbe,
        &feature_movdir64b,
        &feature_movdiri,
        &feature_mpx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_ptwrite,
        &feature_rdpid,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sgx,
        &feature_sha,
        &feature_sse42,
        &feature_ssse3,
        &feature_slowIncdec,
        &feature_slowLea,
        &feature_slowTwoMemOps,
        &feature_waitpkg,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_westmere = Cpu{
    .name = "westmere",
    .llvm_name = "westmere",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_fxsr,
        &feature_sahf,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_sse,
        &feature_pclmul,
        &feature_popcnt,
        &feature_sse42,
        &feature_x87,
    },
};

pub const cpu_winchipC6 = Cpu{
    .name = "winchipC6",
    .llvm_name = "winchip-c6",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_winchip2 = Cpu{
    .name = "winchip2",
    .llvm_name = "winchip2",
    .dependencies = &[_]*const Feature {
        &feature_mmx,
        &feature_dnow3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_x8664 = Cpu{
    .name = "x8664",
    .llvm_name = "x86-64",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_macrofusion,
        &feature_nopl,
        &feature_sse,
        &feature_sse2,
        &feature_slow3opsLea,
        &feature_slowIncdec,
        &feature_x87,
    },
};

pub const cpu_yonah = Cpu{
    .name = "yonah",
    .llvm_name = "yonah",
    .dependencies = &[_]*const Feature {
        &feature_cmov,
        &feature_cx8,
        &feature_fxsr,
        &feature_mmx,
        &feature_nopl,
        &feature_sse,
        &feature_sse3,
        &feature_slowUnalignedMem16,
        &feature_x87,
    },
};

pub const cpu_znver1 = Cpu{
    .name = "znver1",
    .llvm_name = "znver1",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_branchfusion,
        &feature_clflushopt,
        &feature_clzero,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fast15bytenop,
        &feature_fastBextr,
        &feature_fastLzcnt,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mwaitx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sha,
        &feature_sse4a,
        &feature_slowShld,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpu_znver2 = Cpu{
    .name = "znver2",
    .llvm_name = "znver2",
    .dependencies = &[_]*const Feature {
        &feature_bit64,
        &feature_adx,
        &feature_sse,
        &feature_aes,
        &feature_avx2,
        &feature_bmi,
        &feature_bmi2,
        &feature_branchfusion,
        &feature_clflushopt,
        &feature_clwb,
        &feature_clzero,
        &feature_cmov,
        &feature_cx8,
        &feature_cx16,
        &feature_f16c,
        &feature_fma,
        &feature_fsgsbase,
        &feature_fxsr,
        &feature_fast15bytenop,
        &feature_fastBextr,
        &feature_fastLzcnt,
        &feature_fastScalarShiftMasks,
        &feature_sahf,
        &feature_lzcnt,
        &feature_mmx,
        &feature_movbe,
        &feature_mwaitx,
        &feature_nopl,
        &feature_pclmul,
        &feature_popcnt,
        &feature_prfchw,
        &feature_rdpid,
        &feature_rdrnd,
        &feature_rdseed,
        &feature_sha,
        &feature_sse4a,
        &feature_slowShld,
        &feature_wbnoinvd,
        &feature_x87,
        &feature_xsave,
        &feature_xsavec,
        &feature_xsaveopt,
        &feature_xsaves,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_amdfam10,
    &cpu_athlon,
    &cpu_athlon4,
    &cpu_athlonFx,
    &cpu_athlonMp,
    &cpu_athlonTbird,
    &cpu_athlonXp,
    &cpu_athlon64,
    &cpu_athlon64Sse3,
    &cpu_atom,
    &cpu_barcelona,
    &cpu_bdver1,
    &cpu_bdver2,
    &cpu_bdver3,
    &cpu_bdver4,
    &cpu_bonnell,
    &cpu_broadwell,
    &cpu_btver1,
    &cpu_btver2,
    &cpu_c3,
    &cpu_c32,
    &cpu_cannonlake,
    &cpu_cascadelake,
    &cpu_cooperlake,
    &cpu_coreAvxI,
    &cpu_coreAvx2,
    &cpu_core2,
    &cpu_corei7,
    &cpu_corei7Avx,
    &cpu_generic,
    &cpu_geode,
    &cpu_goldmont,
    &cpu_goldmontPlus,
    &cpu_haswell,
    &cpu_i386,
    &cpu_i486,
    &cpu_i586,
    &cpu_i686,
    &cpu_icelakeClient,
    &cpu_icelakeServer,
    &cpu_ivybridge,
    &cpu_k6,
    &cpu_k62,
    &cpu_k63,
    &cpu_k8,
    &cpu_k8Sse3,
    &cpu_knl,
    &cpu_knm,
    &cpu_lakemont,
    &cpu_nehalem,
    &cpu_nocona,
    &cpu_opteron,
    &cpu_opteronSse3,
    &cpu_penryn,
    &cpu_pentium,
    &cpu_pentiumM,
    &cpu_pentiumMmx,
    &cpu_pentium2,
    &cpu_pentium3,
    &cpu_pentium3m,
    &cpu_pentium4,
    &cpu_pentium4m,
    &cpu_pentiumpro,
    &cpu_prescott,
    &cpu_sandybridge,
    &cpu_silvermont,
    &cpu_skx,
    &cpu_skylake,
    &cpu_skylakeAvx512,
    &cpu_slm,
    &cpu_tremont,
    &cpu_westmere,
    &cpu_winchipC6,
    &cpu_winchip2,
    &cpu_x8664,
    &cpu_yonah,
    &cpu_znver1,
    &cpu_znver2,
};
