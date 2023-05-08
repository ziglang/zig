//! Machine Intermediate Representation.
//! This data is produced by x86_64 Codegen and consumed by x86_64 Isel.
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

const Mir = @This();
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const bits = @import("bits.zig");
const encoder = @import("encoder.zig");

const Air = @import("../../Air.zig");
const CodeGen = @import("CodeGen.zig");
const IntegerBitSet = std.bit_set.IntegerBitSet;
const Memory = bits.Memory;
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Tag,
    ops: Ops,
    data: Data,

    pub const Index = u32;

    pub const Fixes = enum(u8) {
        /// ___
        @"_",

        /// ___ Above
        _a,
        /// ___ Above Or Equal
        _ae,
        /// ___ Below
        _b,
        /// ___ Below Or Equal
        _be,
        /// ___ Carry
        _c,
        /// ___ Equal
        _e,
        /// ___ Greater
        _g,
        /// ___ Greater Or Equal
        _ge,
        /// ___ Less
        _l,
        /// ___ Less Or Equal
        _le,
        /// ___ Not Above
        _na,
        /// ___ Not Above Or Equal
        _nae,
        /// ___ Not Below
        _nb,
        /// ___ Not Below Or Equal
        _nbe,
        /// ___ Not Carry
        _nc,
        /// ___ Not Equal
        _ne,
        /// ___ Not Greater
        _ng,
        /// ___ Not Greater Or Equal
        _nge,
        /// ___ Not Less
        _nl,
        /// ___ Not Less Or Equal
        _nle,
        /// ___ Not Overflow
        _no,
        /// ___ Not Parity
        _np,
        /// ___ Not Sign
        _ns,
        /// ___ Not Zero
        _nz,
        /// ___ Overflow
        _o,
        /// ___ Parity
        _p,
        /// ___ Parity Even
        _pe,
        /// ___ Parity Odd
        _po,
        /// ___ Sign
        _s,
        /// ___ Zero
        _z,

        /// ___ String
        //_s,
        /// ___ String Byte
        _sb,
        /// ___ String Word
        _sw,
        /// ___ String Doubleword
        _sd,
        /// ___ String Quadword
        _sq,

        /// Repeat ___ String
        @"rep _s",
        /// Repeat ___ String Byte
        @"rep _sb",
        /// Repeat ___ String Word
        @"rep _sw",
        /// Repeat ___ String Doubleword
        @"rep _sd",
        /// Repeat ___ String Quadword
        @"rep _sq",

        /// Repeat Equal ___ String
        @"repe _s",
        /// Repeat Equal ___ String Byte
        @"repe _sb",
        /// Repeat Equal ___ String Word
        @"repe _sw",
        /// Repeat Equal ___ String Doubleword
        @"repe _sd",
        /// Repeat Equal ___ String Quadword
        @"repe _sq",

        /// Repeat Not Equal ___ String
        @"repne _s",
        /// Repeat Not Equal ___ String Byte
        @"repne _sb",
        /// Repeat Not Equal ___ String Word
        @"repne _sw",
        /// Repeat Not Equal ___ String Doubleword
        @"repne _sd",
        /// Repeat Not Equal ___ String Quadword
        @"repne _sq",

        /// Repeat Not Zero ___ String
        @"repnz _s",
        /// Repeat Not Zero ___ String Byte
        @"repnz _sb",
        /// Repeat Not Zero ___ String Word
        @"repnz _sw",
        /// Repeat Not Zero ___ String Doubleword
        @"repnz _sd",
        /// Repeat Not Zero ___ String Quadword
        @"repnz _sq",

        /// Repeat Zero ___ String
        @"repz _s",
        /// Repeat Zero ___ String Byte
        @"repz _sb",
        /// Repeat Zero ___ String Word
        @"repz _sw",
        /// Repeat Zero ___ String Doubleword
        @"repz _sd",
        /// Repeat Zero ___ String Quadword
        @"repz _sq",

        /// Locked ___
        @"lock _",
        /// ___ 8 Bytes
        _8b,
        /// Locked ___ 8 Bytes
        @"lock _8b",
        /// ___ 16 Bytes
        _16b,
        /// Locked ___ 16 Bytes
        @"lock _16b",

        /// Packed ___
        p_,
        /// Packed ___ Byte
        p_b,
        /// Packed ___ Word
        p_w,
        /// Packed ___ Doubleword
        p_d,
        /// Packed ___ Quadword
        p_q,
        /// Packed ___ Double Quadword
        p_dq,

        /// ___ Scalar Single-Precision Values
        _ss,
        /// ___ Packed Single-Precision Values
        _ps,
        /// ___ Scalar Double-Precision Values
        //_sd,
        /// ___ Packed Double-Precision Values
        _pd,

        /// VEX-Encoded ___
        v_,
        /// VEX-Encoded Packed ___
        vp_,
        /// VEX-Encoded Packed ___ Byte
        vp_b,
        /// VEX-Encoded Packed ___ Word
        vp_w,
        /// VEX-Encoded Packed ___ Doubleword
        vp_d,
        /// VEX-Encoded Packed ___ Quadword
        vp_q,
        /// VEX-Encoded Packed ___ Double Quadword
        vp_dq,
        /// VEX-Encoded ___ Scalar Single-Precision Values
        v_ss,
        /// VEX-Encoded ___ Packed Single-Precision Values
        v_ps,
        /// VEX-Encoded ___ Scalar Double-Precision Values
        v_sd,
        /// VEX-Encoded ___ Packed Double-Precision Values
        v_pd,

        /// Mask ___ Byte
        k_b,
        /// Mask ___ Word
        k_w,
        /// Mask ___ Doubleword
        k_d,
        /// Mask ___ Quadword
        k_q,

        pub fn fromCondition(cc: bits.Condition) Fixes {
            return switch (cc) {
                inline else => |cc_tag| @field(Fixes, "_" ++ @tagName(cc_tag)),
                .z_and_np, .nz_or_p => unreachable,
            };
        }
    };

    pub const Tag = enum(u8) {
        /// Add with carry
        adc,
        /// Add
        add,
        /// Logical and
        @"and",
        /// Bit scan forward
        bsf,
        /// Bit scan reverse
        bsr,
        /// Byte swap
        bswap,
        /// Bit test
        bt,
        /// Bit test and complement
        btc,
        /// Bit test and reset
        btr,
        /// Bit test and set
        bts,
        /// Call
        call,
        /// Convert byte to word
        cbw,
        /// Convert doubleword to quadword
        cdq,
        /// Convert doubleword to quadword
        cdqe,
        /// Conditional move
        cmov,
        /// Logical compare
        /// Compare string
        cmp,
        /// Compare and exchange
        /// Compare and exchange bytes
        cmpxchg,
        /// Convert doubleword to quadword
        cqo,
        /// Convert word to doubleword
        cwd,
        /// Convert word to doubleword
        cwde,
        /// Unsigned division
        div,
        /// Store integer with truncation
        fisttp,
        /// Load floating-point value
        fld,
        /// Signed division
        idiv,
        /// Signed multiplication
        imul,
        ///
        int3,
        /// Conditional jump
        j,
        /// Jump
        jmp,
        /// Load effective address
        lea,
        /// Load string
        lod,
        /// Load fence
        lfence,
        /// Count the number of leading zero bits
        lzcnt,
        /// Memory fence
        mfence,
        /// Move
        /// Move data from string to string
        mov,
        /// Move data after swapping bytes
        movbe,
        /// Move doubleword
        movd,
        /// Move quadword
        movq,
        /// Move with sign extension
        movsx,
        /// Move with sign extension
        movsxd,
        /// Move with zero extension
        movzx,
        /// Multiply
        mul,
        /// Two's complement negation
        neg,
        /// No-op
        nop,
        /// One's complement negation
        not,
        /// Logical or
        @"or",
        /// Pop
        pop,
        /// Return the count of number of bits set to 1
        popcnt,
        /// Push
        push,
        /// Rotate left through carry
        rcl,
        /// Rotate right through carry
        rcr,
        /// Return
        ret,
        /// Rotate left
        rol,
        /// Rotate right
        ror,
        /// Arithmetic shift left
        sal,
        /// Arithmetic shift right
        sar,
        /// Integer subtraction with borrow
        sbb,
        /// Scan string
        sca,
        /// Set byte on condition
        set,
        /// Store fence
        sfence,
        /// Logical shift left
        shl,
        /// Double precision shift left
        shld,
        /// Logical shift right
        shr,
        /// Double precision shift right
        shrd,
        /// Subtract
        sub,
        /// Store string
        sto,
        /// Syscall
        syscall,
        /// Test condition
        @"test",
        /// Count the number of trailing zero bits
        tzcnt,
        /// Undefined instruction
        ud2,
        /// Exchange and add
        xadd,
        /// Exchange register/memory with register
        xchg,
        /// Logical exclusive-or
        xor,

        /// Add packed single-precision floating-point values
        addps,
        /// Add scalar single-precision floating-point values
        addss,
        /// Bitwise logical and of packed single precision floating-point values
        andps,
        /// Bitwise logical and not of packed single precision floating-point values
        andnps,
        /// Compare scalar single-precision floating-point values
        cmpss,
        /// Convert doubleword integer to scalar single-precision floating-point value
        cvtsi2ss,
        /// Divide packed single-precision floating-point values
        divps,
        /// Divide scalar single-precision floating-point values
        divss,
        /// Maximum of packed single-precision floating-point values
        maxps,
        /// Maximum of scalar single-precision floating-point values
        maxss,
        /// Minimum of packed single-precision floating-point values
        minps,
        /// Minimum of scalar single-precision floating-point values
        minss,
        /// Move aligned packed single-precision floating-point values
        movaps,
        /// Move packed single-precision floating-point values high to low
        movhlps,
        /// Move scalar single-precision floating-point value
        movss,
        /// Move unaligned packed single-precision floating-point values
        movups,
        /// Multiply packed single-precision floating-point values
        mulps,
        /// Multiply scalar single-precision floating-point values
        mulss,
        /// Bitwise logical or of packed single precision floating-point values
        orps,
        /// Extract word
        pextrw,
        /// Insert word
        pinsrw,
        /// Square root of packed single-precision floating-point values
        sqrtps,
        /// Square root of scalar single-precision floating-point value
        sqrtss,
        /// Subtract packed single-precision floating-point values
        subps,
        /// Subtract scalar single-precision floating-point values
        subss,
        /// Unordered compare scalar single-precision floating-point values
        ucomiss,
        /// Unpack and interleave high packed single-precision floating-point values
        unpckhps,
        /// Unpack and interleave low packed single-precision floating-point values
        unpcklps,
        /// Bitwise logical xor of packed single precision floating-point values
        xorps,

        /// Add packed double-precision floating-point values
        addpd,
        /// Add scalar double-precision floating-point values
        addsd,
        /// Bitwise logical and not of packed double precision floating-point values
        andnpd,
        /// Bitwise logical and of packed double precision floating-point values
        andpd,
        /// Compare scalar double-precision floating-point values
        cmpsd,
        /// Convert scalar double-precision floating-point value to scalar single-precision floating-point value
        cvtsd2ss,
        /// Convert doubleword integer to scalar double-precision floating-point value
        cvtsi2sd,
        /// Convert scalar single-precision floating-point value to scalar double-precision floating-point value
        cvtss2sd,
        /// Divide packed double-precision floating-point values
        divpd,
        /// Divide scalar double-precision floating-point values
        divsd,
        /// Maximum of packed double-precision floating-point values
        maxpd,
        /// Maximum of scalar double-precision floating-point values
        maxsd,
        /// Minimum of packed double-precision floating-point values
        minpd,
        /// Minimum of scalar double-precision floating-point values
        minsd,
        /// Move scalar double-precision floating-point value
        movsd,
        /// Multiply packed double-precision floating-point values
        mulpd,
        /// Multiply scalar double-precision floating-point values
        mulsd,
        /// Bitwise logical or of packed double precision floating-point values
        orpd,
        /// Shuffle packed high words
        pshufhw,
        /// Shuffle packed low words
        pshuflw,
        /// Shift packed data right logical
        psrld,
        /// Shift packed data right logical
        psrlq,
        /// Shift packed data right logical
        psrlw,
        /// Unpack high data
        punpckhbw,
        /// Unpack high data
        punpckhdq,
        /// Unpack high data
        punpckhqdq,
        /// Unpack high data
        punpckhwd,
        /// Unpack low data
        punpcklbw,
        /// Unpack low data
        punpckldq,
        /// Unpack low data
        punpcklqdq,
        /// Unpack low data
        punpcklwd,
        /// Square root of double precision floating-point values
        sqrtpd,
        /// Square root of scalar double precision floating-point value
        sqrtsd,
        /// Subtract packed double-precision floating-point values
        subpd,
        /// Subtract scalar double-precision floating-point values
        subsd,
        /// Unordered compare scalar double-precision floating-point values
        ucomisd,
        /// Unpack and interleave high packed double-precision floating-point values
        unpckhpd,
        /// Unpack and interleave low packed double-precision floating-point values
        unpcklpd,
        /// Bitwise logical xor of packed double precision floating-point values
        xorpd,

        /// Replicate double floating-point values
        movddup,
        /// Replicate single floating-point values
        movshdup,
        /// Replicate single floating-point values
        movsldup,

        /// Extract Byte
        pextrb,
        /// Extract Doubleword
        pextrd,
        /// Extract Quadword
        pextrq,
        /// Insert Byte
        pinsrb,
        /// Insert Doubleword
        pinsrd,
        /// Insert Quadword
        pinsrq,
        /// Round packed double-precision floating-point values
        roundpd,
        /// Round packed single-precision floating-point values
        roundps,
        /// Round scalar double-precision floating-point value
        roundsd,
        /// Round scalar single-precision floating-point value
        roundss,

        /// Add packed double-precision floating-point values
        vaddpd,
        /// Add packed single-precision floating-point values
        vaddps,
        /// Add scalar double-precision floating-point values
        vaddsd,
        /// Add scalar single-precision floating-point values
        vaddss,
        /// Convert scalar double-precision floating-point value to scalar single-precision floating-point value
        vcvtsd2ss,
        /// Convert doubleword integer to scalar double-precision floating-point value
        vcvtsi2sd,
        /// Convert doubleword integer to scalar single-precision floating-point value
        vcvtsi2ss,
        /// Convert scalar single-precision floating-point value to scalar double-precision floating-point value
        vcvtss2sd,
        /// Divide packed double-precision floating-point values
        vdivpd,
        /// Divide packed single-precision floating-point values
        vdivps,
        /// Divide scalar double-precision floating-point values
        vdivsd,
        /// Divide scalar single-precision floating-point values
        vdivss,
        /// Maximum of packed double-precision floating-point values
        vmaxpd,
        /// Maximum of packed single-precision floating-point values
        vmaxps,
        /// Maximum of scalar double-precision floating-point values
        vmaxsd,
        /// Maximum of scalar single-precision floating-point values
        vmaxss,
        /// Minimum of packed double-precision floating-point values
        vminpd,
        /// Minimum of packed single-precision floating-point values
        vminps,
        /// Minimum of scalar double-precision floating-point values
        vminsd,
        /// Minimum of scalar single-precision floating-point values
        vminss,
        /// Move aligned packed double-precision floating-point values
        vmovapd,
        /// Move aligned packed single-precision floating-point values
        vmovaps,
        /// Move packed single-precision floating-point values high to low
        vmovhlps,
        /// Replicate double floating-point values
        vmovddup,
        /// Move or merge scalar double-precision floating-point value
        vmovsd,
        /// Replicate single floating-point values
        vmovshdup,
        /// Replicate single floating-point values
        vmovsldup,
        /// Move or merge scalar single-precision floating-point value
        vmovss,
        /// Move unaligned packed double-precision floating-point values
        vmovupd,
        /// Move unaligned packed single-precision floating-point values
        vmovups,
        /// Multiply packed double-precision floating-point values
        vmulpd,
        /// Multiply packed single-precision floating-point values
        vmulps,
        /// Multiply scalar double-precision floating-point values
        vmulsd,
        /// Multiply scalar single-precision floating-point values
        vmulss,
        /// Extract Byte
        vpextrb,
        /// Extract Doubleword
        vpextrd,
        /// Extract Quadword
        vpextrq,
        /// Extract word
        vpextrw,
        /// Insert Byte
        vpinsrb,
        /// Insert Doubleword
        vpinsrd,
        /// Insert Quadword
        vpinsrq,
        /// Insert word
        vpinsrw,
        /// Shuffle packed high words
        vpshufhw,
        /// Shuffle packed low words
        vpshuflw,
        /// Shift packed data right logical
        vpsrld,
        /// Shift packed data right logical
        vpsrlq,
        /// Shift packed data right logical
        vpsrlw,
        /// Unpack high data
        vpunpckhbw,
        /// Unpack high data
        vpunpckhdq,
        /// Unpack high data
        vpunpckhqdq,
        /// Unpack high data
        vpunpckhwd,
        /// Unpack low data
        vpunpcklbw,
        /// Unpack low data
        vpunpckldq,
        /// Unpack low data
        vpunpcklqdq,
        /// Unpack low data
        vpunpcklwd,
        /// Round packed double-precision floating-point values
        vroundpd,
        /// Round packed single-precision floating-point values
        vroundps,
        /// Round scalar double-precision floating-point value
        vroundsd,
        /// Round scalar single-precision floating-point value
        vroundss,
        /// Square root of packed double-precision floating-point value
        vsqrtpd,
        /// Square root of packed single-precision floating-point value
        vsqrtps,
        /// Square root of scalar double-precision floating-point value
        vsqrtsd,
        /// Square root of scalar single-precision floating-point value
        vsqrtss,
        /// Subtract packed double-precision floating-point values
        vsubpd,
        /// Subtract packed single-precision floating-point values
        vsubps,
        /// Subtract scalar double-precision floating-point values
        vsubsd,
        /// Subtract scalar single-precision floating-point values
        vsubss,
        /// Unpack and interleave high packed double-precision floating-point values
        vunpckhpd,
        /// Unpack and interleave high packed single-precision floating-point values
        vunpckhps,
        /// Unpack and interleave low packed double-precision floating-point values
        vunpcklpd,
        /// Unpack and interleave low packed single-precision floating-point values
        vunpcklps,

        /// Convert 16-bit floating-point values to single-precision floating-point values
        vcvtph2ps,
        /// Convert single-precision floating-point values to 16-bit floating-point values
        vcvtps2ph,

        /// Fused multiply-add of packed double-precision floating-point values
        vfmadd132pd,
        /// Fused multiply-add of packed double-precision floating-point values
        vfmadd213pd,
        /// Fused multiply-add of packed double-precision floating-point values
        vfmadd231pd,
        /// Fused multiply-add of packed single-precision floating-point values
        vfmadd132ps,
        /// Fused multiply-add of packed single-precision floating-point values
        vfmadd213ps,
        /// Fused multiply-add of packed single-precision floating-point values
        vfmadd231ps,
        /// Fused multiply-add of scalar double-precision floating-point values
        vfmadd132sd,
        /// Fused multiply-add of scalar double-precision floating-point values
        vfmadd213sd,
        /// Fused multiply-add of scalar double-precision floating-point values
        vfmadd231sd,
        /// Fused multiply-add of scalar single-precision floating-point values
        vfmadd132ss,
        /// Fused multiply-add of scalar single-precision floating-point values
        vfmadd213ss,
        /// Fused multiply-add of scalar single-precision floating-point values
        vfmadd231ss,

        /// A pseudo instruction that requires special lowering.
        /// This should be the only tag in this enum that doesn't
        /// directly correspond to one or more instruction mnemonics.
        pseudo,
    };

    pub const Ops = enum(u8) {
        /// No data associated with this instruction (only mnemonic is used).
        none,
        /// Single register operand.
        /// Uses `r` payload.
        r,
        /// Register, register operands.
        /// Uses `rr` payload.
        rr,
        /// Register, register, register operands.
        /// Uses `rrr` payload.
        rrr,
        /// Register, register, register, immediate (byte) operands.
        /// Uses `rrri` payload.
        rrri,
        /// Register, register, immediate (sign-extended) operands.
        /// Uses `rri`  payload.
        rri_s,
        /// Register, register, immediate (unsigned) operands.
        /// Uses `rri`  payload.
        rri_u,
        /// Register, immediate (sign-extended) operands.
        /// Uses `ri` payload.
        ri_s,
        /// Register, immediate (unsigned) operands.
        /// Uses `ri` payload.
        ri_u,
        /// Register, 64-bit unsigned immediate operands.
        /// Uses `rx` payload with payload type `Imm64`.
        ri64,
        /// Immediate (sign-extended) operand.
        /// Uses `imm` payload.
        i_s,
        /// Immediate (unsigned) operand.
        /// Uses `imm` payload.
        i_u,
        /// Relative displacement operand.
        /// Uses `imm` payload.
        rel,
        /// Register, memory (SIB) operands.
        /// Uses `rx` payload.
        rm_sib,
        /// Register, memory (RIP) operands.
        /// Uses `rx` payload.
        rm_rip,
        /// Register, memory (SIB), immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemorySib`.
        rmi_sib,
        /// Register, register, memory (RIP).
        /// Uses `rrix` payload with extra data of type `MemoryRip`.
        rrm_rip,
        /// Register, register, memory (SIB).
        /// Uses `rrix` payload with extra data of type `MemorySib`.
        rrm_sib,
        /// Register, register, memory (RIP), immediate (byte) operands.
        /// Uses `rrix` payload with extra data of type `MemoryRip`.
        rrmi_rip,
        /// Register, register, memory (SIB), immediate (byte) operands.
        /// Uses `rrix` payload with extra data of type `MemorySib`.
        rrmi_sib,
        /// Register, memory (RIP), immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemoryRip`.
        rmi_rip,
        /// Single memory (SIB) operand.
        /// Uses `x` with extra data of type `MemorySib`.
        m_sib,
        /// Single memory (RIP) operand.
        /// Uses `x` with extra data of type `MemoryRip`.
        m_rip,
        /// Memory (SIB), immediate (unsigned) operands.
        /// Uses `ix` payload with extra data of type `MemorySib`.
        mi_sib_u,
        /// Memory (RIP), immediate (unsigned) operands.
        /// Uses `ix` payload with extra data of type `MemoryRip`.
        mi_rip_u,
        /// Memory (SIB), immediate (sign-extend) operands.
        /// Uses `ix` payload with extra data of type `MemorySib`.
        mi_sib_s,
        /// Memory (RIP), immediate (sign-extend) operands.
        /// Uses `ix` payload with extra data of type `MemoryRip`.
        mi_rip_s,
        /// Memory (SIB), register operands.
        /// Uses `rx` payload with extra data of type `MemorySib`.
        mr_sib,
        /// Memory (RIP), register operands.
        /// Uses `rx` payload with extra data of type `MemoryRip`.
        mr_rip,
        /// Memory (SIB), register, register operands.
        /// Uses `rrx` payload with extra data of type `MemorySib`.
        mrr_sib,
        /// Memory (RIP), register, register operands.
        /// Uses `rrx` payload with extra data of type `MemoryRip`.
        mrr_rip,
        /// Memory (SIB), register, immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemorySib`.
        mri_sib,
        /// Memory (RIP), register, immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemoryRip`.
        mri_rip,
        /// Rax, Memory moffs.
        /// Uses `x` with extra data of type `MemoryMoffs`.
        rax_moffs,
        /// Memory moffs, rax.
        /// Uses `x` with extra data of type `MemoryMoffs`.
        moffs_rax,
        /// References another Mir instruction directly.
        /// Uses `inst` payload.
        inst,
        /// Linker relocation - external function.
        /// Uses `reloc` payload.
        extern_fn_reloc,
        /// Linker relocation - GOT indirection.
        /// Uses `rx` payload with extra data of type `Reloc`.
        got_reloc,
        /// Linker relocation - direct reference.
        /// Uses `rx` payload with extra data of type `Reloc`.
        direct_reloc,
        /// Linker relocation - imports table indirection (binding).
        /// Uses `rx` payload with extra data of type `Reloc`.
        import_reloc,
        /// Linker relocation - threadlocal variable via GOT indirection.
        /// Uses `rx` payload with extra data of type `Reloc`.
        tlv_reloc,

        // Pseudo instructions:

        /// Conditional move if zero flag set and parity flag not set
        /// Clobbers the source operand!
        /// Uses `rr` payload.
        pseudo_cmov_z_and_np_rr,
        /// Conditional move if zero flag not set or parity flag set
        /// Uses `rr` payload.
        pseudo_cmov_nz_or_p_rr,
        /// Conditional move if zero flag not set or parity flag set
        /// Uses `rx` payload.
        pseudo_cmov_nz_or_p_rm_sib,
        /// Conditional move if zero flag not set or parity flag set
        /// Uses `rx` payload.
        pseudo_cmov_nz_or_p_rm_rip,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `r_scratch` payload.
        pseudo_set_z_and_np_r,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `x_scratch` payload.
        pseudo_set_z_and_np_m_sib,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `x_scratch` payload.
        pseudo_set_z_and_np_m_rip,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `r_scratch` payload.
        pseudo_set_nz_or_p_r,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `x_scratch` payload.
        pseudo_set_nz_or_p_m_sib,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `x_scratch` payload.
        pseudo_set_nz_or_p_m_rip,
        /// Jump if zero flag set and parity flag not set
        /// Uses `inst` payload.
        pseudo_j_z_and_np_inst,
        /// Jump if zero flag not set or parity flag set
        /// Uses `inst` payload.
        pseudo_j_nz_or_p_inst,

        /// Push registers
        /// Uses `reg_list` payload.
        pseudo_push_reg_list,
        /// Pop registers
        /// Uses `reg_list` payload.
        pseudo_pop_reg_list,

        /// End of prologue
        pseudo_dbg_prologue_end_none,
        /// Update debug line
        /// Uses `line_column` payload.
        pseudo_dbg_line_line_column,
        /// Start of epilogue
        pseudo_dbg_epilogue_begin_none,

        /// Tombstone
        /// Emitter should skip this instruction.
        pseudo_dead_none,
    };

    pub const Data = union {
        none: struct {
            fixes: Fixes = ._,
        },
        /// References another Mir instruction.
        inst: struct {
            fixes: Fixes = ._,
            inst: Index,
        },
        /// A 32-bit immediate value.
        i: struct {
            fixes: Fixes = ._,
            i: u32,
        },
        r: struct {
            fixes: Fixes = ._,
            r1: Register,
        },
        rr: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
        },
        rrr: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            r3: Register,
        },
        rrri: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            r3: Register,
            i: u8,
        },
        rri: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            i: u32,
        },
        /// Register, immediate.
        ri: struct {
            fixes: Fixes = ._,
            r1: Register,
            i: u32,
        },
        /// Register, followed by custom payload found in extra.
        rx: struct {
            fixes: Fixes = ._,
            r1: Register,
            payload: u32,
        },
        /// Immediate, followed by Custom payload found in extra.
        ix: struct {
            i: u32,
            payload: u32,
        },
        /// Register, register, followed by Custom payload found in extra.
        rrx: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            payload: u32,
        },
        /// Register, byte immediate, followed by Custom payload found in extra.
        rix: struct {
            fixes: Fixes = ._,
            r1: Register,
            i: u8,
            payload: u32,
        },
        /// Register, register, byte immediate, followed by Custom payload found in extra.
        rrix: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            i: u8,
            payload: u32,
        },
        /// Register, scratch register
        r_scratch: struct {
            fixes: Fixes = ._,
            r1: Register,
            scratch_reg: Register,
        },
        /// Scratch register, followed by Custom payload found in extra.
        x_scratch: struct {
            fixes: Fixes = ._,
            scratch_reg: Register,
            payload: u32,
        },
        /// Custom payload found in extra.
        x: struct {
            fixes: Fixes = ._,
            payload: u32,
        },
        /// Relocation for the linker where:
        /// * `atom_index` is the index of the source
        /// * `sym_index` is the index of the target
        reloc: Reloc,
        /// Debug line and column position
        line_column: struct {
            line: u32,
            column: u32,
        },
        /// Register list
        reg_list: RegisterList,
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in Debug builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
            assert(@sizeOf(Data) == 8);
        }
    }
};

/// A linker symbol not yet allocated in VM.
pub const Reloc = struct {
    /// Index of the containing atom.
    atom_index: u32,
    /// Index into the linker's symbol table.
    sym_index: u32,
};

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet = BitSet.initEmpty(),

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(u32, i);
        }
        unreachable; // register not in input register list!
    }

    pub fn push(self: *Self, registers: []const Register, reg: Register) void {
        const index = getIndexForReg(registers, reg);
        self.bitset.set(index);
    }

    pub fn isSet(self: Self, registers: []const Register, reg: Register) bool {
        const index = getIndexForReg(registers, reg);
        return self.bitset.isSet(index);
    }

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
    }

    pub fn count(self: Self) u32 {
        return @intCast(u32, self.bitset.count());
    }
};

pub const Imm64 = struct {
    msb: u32,
    lsb: u32,

    pub fn encode(v: u64) Imm64 {
        return .{
            .msb = @truncate(u32, v >> 32),
            .lsb = @truncate(u32, v),
        };
    }

    pub fn decode(imm: Imm64) u64 {
        var res: u64 = 0;
        res |= (@intCast(u64, imm.msb) << 32);
        res |= @intCast(u64, imm.lsb);
        return res;
    }
};

// TODO this can be further compacted using packed struct
pub const MemorySib = struct {
    /// Size of the pointer.
    ptr_size: u32,
    /// Base register tag of type Memory.Base.Tag
    base_tag: u32,
    /// Base register of type Register or FrameIndex
    base: u32,
    /// Scale starting at bit 0 and index register starting at bit 4.
    scale_index: u32,
    /// Displacement value.
    disp: i32,

    pub fn encode(mem: Memory) MemorySib {
        const sib = mem.sib;
        assert(sib.scale_index.scale == 0 or std.math.isPowerOfTwo(sib.scale_index.scale));
        return .{
            .ptr_size = @enumToInt(sib.ptr_size),
            .base_tag = @enumToInt(@as(Memory.Base.Tag, sib.base)),
            .base = switch (sib.base) {
                .none => undefined,
                .reg => |r| @enumToInt(r),
                .frame => |fi| @enumToInt(fi),
            },
            .scale_index = @as(u32, sib.scale_index.scale) << 0 |
                @as(u32, if (sib.scale_index.scale > 0)
                @enumToInt(sib.scale_index.index)
            else
                undefined) << 4,
            .disp = sib.disp,
        };
    }

    pub fn decode(msib: MemorySib) Memory {
        const scale = @truncate(u4, msib.scale_index);
        assert(scale == 0 or std.math.isPowerOfTwo(scale));
        return .{ .sib = .{
            .ptr_size = @intToEnum(Memory.PtrSize, msib.ptr_size),
            .base = switch (@intToEnum(Memory.Base.Tag, msib.base_tag)) {
                .none => .none,
                .reg => .{ .reg = @intToEnum(Register, msib.base) },
                .frame => .{ .frame = @intToEnum(bits.FrameIndex, msib.base) },
            },
            .scale_index = .{
                .scale = scale,
                .index = if (scale > 0) @intToEnum(Register, msib.scale_index >> 4) else undefined,
            },
            .disp = msib.disp,
        } };
    }
};

pub const MemoryRip = struct {
    /// Size of the pointer.
    ptr_size: u32,
    /// Displacement value.
    disp: i32,

    pub fn encode(mem: Memory) MemoryRip {
        return .{
            .ptr_size = @enumToInt(mem.rip.ptr_size),
            .disp = mem.rip.disp,
        };
    }

    pub fn decode(mrip: MemoryRip) Memory {
        return .{ .rip = .{
            .ptr_size = @intToEnum(Memory.PtrSize, mrip.ptr_size),
            .disp = mrip.disp,
        } };
    }
};

pub const MemoryMoffs = struct {
    /// Segment register.
    seg: u32,
    /// Absolute offset wrt to the segment register split between MSB and LSB parts much like
    /// `Imm64` payload.
    msb: u32,
    lsb: u32,

    pub fn encode(seg: Register, offset: u64) MemoryMoffs {
        return .{
            .seg = @enumToInt(seg),
            .msb = @truncate(u32, offset >> 32),
            .lsb = @truncate(u32, offset >> 0),
        };
    }

    pub fn decode(moffs: MemoryMoffs) Memory {
        return .{ .moffs = .{
            .seg = @intToEnum(Register, moffs.seg),
            .offset = @as(u64, moffs.msb) << 32 | @as(u64, moffs.lsb) << 0,
        } };
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    gpa.free(mir.extra);
    mir.frame_locs.deinit(gpa);
    mir.* = undefined;
}

pub fn extraData(mir: Mir, comptime T: type, index: u32) struct { data: T, end: u32 } {
    const fields = std.meta.fields(T);
    var i: u32 = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => mir.extra[i],
            i32 => @bitCast(i32, mir.extra[i]),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

pub const FrameLoc = struct {
    base: Register,
    disp: i32,
};

pub fn resolveFrameLoc(mir: Mir, mem: Memory) Memory {
    return switch (mem) {
        .sib => |sib| switch (sib.base) {
            .none, .reg => mem,
            .frame => |index| if (mir.frame_locs.len > 0) Memory.sib(sib.ptr_size, .{
                .base = .{ .reg = mir.frame_locs.items(.base)[@enumToInt(index)] },
                .disp = mir.frame_locs.items(.disp)[@enumToInt(index)] + sib.disp,
                .scale_index = mem.scaleIndex(),
            }) else mem,
        },
        .rip, .moffs => mem,
    };
}
