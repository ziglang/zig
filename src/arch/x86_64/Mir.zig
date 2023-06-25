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

        /// Integer __
        i_,

        /// ___ Left
        _l,
        /// ___ Left Double
        _ld,
        /// ___ Right
        _r,
        /// ___ Right Double
        _rd,

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
        //_l,
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

        /// ___ Byte
        //_b,
        /// ___ Word
        _w,
        /// ___ Doubleword
        _d,
        /// ___ QuadWord
        _q,

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
        /// ___ And Complement
        //_c,
        /// Locked ___ And Complement
        @"lock _c",
        /// ___ And Reset
        //_r,
        /// Locked ___ And Reset
        @"lock _r",
        /// ___ And Set
        //_s,
        /// Locked ___ And Set
        @"lock _s",
        /// ___ 8 Bytes
        _8b,
        /// Locked ___ 8 Bytes
        @"lock _8b",
        /// ___ 16 Bytes
        _16b,
        /// Locked ___ 16 Bytes
        @"lock _16b",

        /// Float ___
        f_,
        /// Float ___ Pop
        f_p,

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
        /// VEX-Encoded ___ Byte
        v_b,
        /// VEX-Encoded ___ Word
        v_w,
        /// VEX-Encoded ___ Doubleword
        v_d,
        /// VEX-Encoded ___ QuadWord
        v_q,
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
        /// VEX-Encoded ___ 128-Bits Of Floating-Point Data
        v_f128,

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
        /// Add packed integers
        /// Add packed single-precision floating-point values
        /// Add scalar single-precision floating-point values
        /// Add packed double-precision floating-point values
        /// Add scalar double-precision floating-point values
        add,
        /// Logical and
        /// Bitwise logical and of packed single-precision floating-point values
        /// Bitwise logical and of packed double-precision floating-point values
        @"and",
        /// Bit scan forward
        bsf,
        /// Bit scan reverse
        bsr,
        /// Byte swap
        bswap,
        /// Bit test
        /// Bit test and complement
        /// Bit test and reset
        /// Bit test and set
        bt,
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
        /// Compare scalar single-precision floating-point values
        /// Compare scalar double-precision floating-point values
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
        /// Signed division
        /// Divide packed single-precision floating-point values
        /// Divide scalar single-precision floating-point values
        /// Divide packed double-precision floating-point values
        /// Divide scalar double-precision floating-point values
        div,
        ///
        int3,
        /// Store integer with truncation
        istt,
        /// Conditional jump
        j,
        /// Jump
        jmp,
        /// Load floating-point value
        ld,
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
        /// Move scalar single-precision floating-point value
        /// Move scalar double-precision floating-point value
        /// Move doubleword
        /// Move quadword
        mov,
        /// Move data after swapping bytes
        movbe,
        /// Move with sign extension
        movsx,
        /// Move with zero extension
        movzx,
        /// Multiply
        /// Signed multiplication
        /// Multiply packed single-precision floating-point values
        /// Multiply scalar single-precision floating-point values
        /// Multiply packed double-precision floating-point values
        /// Multiply scalar double-precision floating-point values
        mul,
        /// Two's complement negation
        neg,
        /// No-op
        nop,
        /// One's complement negation
        not,
        /// Logical or
        /// Bitwise logical or of packed single-precision floating-point values
        /// Bitwise logical or of packed double-precision floating-point values
        @"or",
        /// Pop
        pop,
        /// Return the count of number of bits set to 1
        popcnt,
        /// Push
        push,
        /// Rotate left through carry
        /// Rotate right through carry
        rc,
        /// Return
        ret,
        /// Rotate left
        /// Rotate right
        ro,
        /// Arithmetic shift left
        /// Arithmetic shift right
        sa,
        /// Integer subtraction with borrow
        sbb,
        /// Scan string
        sca,
        /// Set byte on condition
        set,
        /// Store fence
        sfence,
        /// Logical shift left
        /// Double precision shift left
        /// Logical shift right
        /// Double precision shift right
        sh,
        /// Subtract
        /// Subtract packed integers
        /// Subtract packed single-precision floating-point values
        /// Subtract scalar single-precision floating-point values
        /// Subtract packed double-precision floating-point values
        /// Subtract scalar double-precision floating-point values
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
        /// Bitwise logical xor of packed single-precision floating-point values
        /// Bitwise logical xor of packed double-precision floating-point values
        xor,

        /// Pack with signed saturation
        ackssw,
        /// Pack with signed saturation
        ackssd,
        /// Pack with unsigned saturation
        ackusw,
        /// Add packed signed integers with signed saturation
        adds,
        /// Add packed unsigned integers with unsigned saturation
        addus,
        /// Bitwise logical and not of packed single-precision floating-point values
        /// Bitwise logical and not of packed double-precision floating-point values
        andn,
        /// Maximum of packed signed integers
        maxs,
        /// Maximum of packed unsigned integers
        maxu,
        /// Minimum of packed signed integers
        mins,
        /// Minimum of packed unsigned integers
        minu,
        /// Multiply packed signed integers and store low result
        mull,
        /// Multiply packed signed integers and store high result
        mulh,
        /// Subtract packed signed integers with signed saturation
        subs,
        /// Subtract packed unsigned integers with unsigned saturation
        subus,

        /// Convert packed doubleword integers to packed single-precision floating-point values
        /// Convert packed doubleword integers to packed double-precision floating-point values
        cvtpi2,
        /// Convert packed single-precision floating-point values to packed doubleword integers
        cvtps2pi,
        /// Convert doubleword integer to scalar single-precision floating-point value
        /// Convert doubleword integer to scalar double-precision floating-point value
        cvtsi2,
        /// Convert scalar single-precision floating-point value to doubleword integer
        cvtss2si,
        /// Convert with truncation packed single-precision floating-point values to packed doubleword integers
        cvttps2pi,
        /// Convert with truncation scalar single-precision floating-point value to doubleword integer
        cvttss2si,

        /// Maximum of packed single-precision floating-point values
        /// Maximum of scalar single-precision floating-point values
        /// Maximum of packed double-precision floating-point values
        /// Maximum of scalar double-precision floating-point values
        max,
        /// Minimum of packed single-precision floating-point values
        /// Minimum of scalar single-precision floating-point values
        /// Minimum of packed double-precision floating-point values
        /// Minimum of scalar double-precision floating-point values
        min,
        /// Move aligned packed single-precision floating-point values
        /// Move aligned packed double-precision floating-point values
        mova,
        /// Move packed single-precision floating-point values high to low
        movhl,
        /// Move packed single-precision floating-point values low to high
        movlh,
        /// Move unaligned packed single-precision floating-point values
        /// Move unaligned packed double-precision floating-point values
        movu,
        /// Extract byte
        /// Extract word
        /// Extract doubleword
        /// Extract quadword
        extr,
        /// Insert byte
        /// Insert word
        /// Insert doubleword
        /// Insert quadword
        insr,
        /// Square root of packed single-precision floating-point values
        /// Square root of scalar single-precision floating-point value
        /// Square root of packed double-precision floating-point values
        /// Square root of scalar double-precision floating-point value
        sqrt,
        /// Unordered compare scalar single-precision floating-point values
        /// Unordered compare scalar double-precision floating-point values
        ucomi,
        /// Unpack and interleave high packed single-precision floating-point values
        /// Unpack and interleave high packed double-precision floating-point values
        unpckh,
        /// Unpack and interleave low packed single-precision floating-point values
        /// Unpack and interleave low packed double-precision floating-point values
        unpckl,

        /// Convert packed doubleword integers to packed single-precision floating-point values
        /// Convert packed doubleword integers to packed double-precision floating-point values
        cvtdq2,
        /// Convert packed double-precision floating-point values to packed doubleword integers
        cvtpd2dq,
        /// Convert packed double-precision floating-point values to packed doubleword integers
        cvtpd2pi,
        /// Convert packed double-precision floating-point values to packed single-precision floating-point values
        cvtpd2,
        /// Convert packed single-precision floating-point values to packed doubleword integers
        cvtps2dq,
        /// Convert packed single-precision floating-point values to packed double-precision floating-point values
        cvtps2,
        /// Convert scalar double-precision floating-point value to doubleword integer
        cvtsd2si,
        /// Convert scalar double-precision floating-point value to scalar single-precision floating-point value
        cvtsd2,
        /// Convert scalar single-precision floating-point value to scalar double-precision floating-point value
        cvtss2,
        /// Convert with truncation packed double-precision floating-point values to packed doubleword integers
        cvttpd2dq,
        /// Convert with truncation packed double-precision floating-point values to packed doubleword integers
        cvttpd2pi,
        /// Convert with truncation packed single-precision floating-point values to packed doubleword integers
        cvttps2dq,
        /// Convert with truncation scalar double-precision floating-point value to doubleword integer
        cvttsd2si,
        /// Move aligned packed integer values
        movdqa,
        /// Move unaligned packed integer values
        movdqu,
        /// Packed interleave shuffle of quadruplets of single-precision floating-point values
        /// Packed interleave shuffle of pairs of double-precision floating-point values
        shuf,
        /// Shuffle packed high words
        shufh,
        /// Shuffle packed low words
        shufl,
        /// Shift packed data right logical
        /// Shift packed data right logical
        /// Shift packed data right logical
        srl,
        /// Unpack high data
        unpckhbw,
        /// Unpack high data
        unpckhdq,
        /// Unpack high data
        unpckhqdq,
        /// Unpack high data
        unpckhwd,
        /// Unpack low data
        unpcklbw,
        /// Unpack low data
        unpckldq,
        /// Unpack low data
        unpcklqdq,
        /// Unpack low data
        unpcklwd,

        /// Replicate double floating-point values
        movddup,
        /// Replicate single floating-point values
        movshdup,
        /// Replicate single floating-point values
        movsldup,

        /// Pack with unsigned saturation
        ackusd,
        /// Blend packed single-precision floating-point values
        /// Blend scalar single-precision floating-point values
        /// Blend packed double-precision floating-point values
        /// Blend scalar double-precision floating-point values
        blend,
        /// Variable blend packed single-precision floating-point values
        /// Variable blend scalar single-precision floating-point values
        /// Variable blend packed double-precision floating-point values
        /// Variable blend scalar double-precision floating-point values
        blendv,
        /// Extract packed floating-point values
        extract,
        /// Insert scalar single-precision floating-point value
        /// Insert packed floating-point values
        insert,
        /// Round packed single-precision floating-point values
        /// Round scalar single-precision floating-point value
        /// Round packed double-precision floating-point values
        /// Round scalar double-precision floating-point value
        round,

        /// Load with broadcast floating-point data
        broadcast,

        /// Convert 16-bit floating-point values to single-precision floating-point values
        cvtph2,
        /// Convert single-precision floating-point values to 16-bit floating-point values
        cvtps2ph,

        /// Fused multiply-add of packed single-precision floating-point values
        /// Fused multiply-add of scalar single-precision floating-point values
        /// Fused multiply-add of packed double-precision floating-point values
        /// Fused multiply-add of scalar double-precision floating-point values
        fmadd132,
        /// Fused multiply-add of packed single-precision floating-point values
        /// Fused multiply-add of scalar single-precision floating-point values
        /// Fused multiply-add of packed double-precision floating-point values
        /// Fused multiply-add of scalar double-precision floating-point values
        fmadd213,
        /// Fused multiply-add of packed single-precision floating-point values
        /// Fused multiply-add of scalar single-precision floating-point values
        /// Fused multiply-add of packed double-precision floating-point values
        /// Fused multiply-add of scalar double-precision floating-point values
        fmadd231,

        /// A pseudo instruction that requires special lowering.
        /// This should be the only tag in this enum that doesn't
        /// directly correspond to one or more instruction mnemonics.
        pseudo,
    };

    pub const FixedTag = struct { Fixes, Tag };

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
        /// Register, register, register, register operands.
        /// Uses `rrrr` payload.
        rrrr,
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
        /// Uses `x` payload with extra data of type `Imm32` followed by `MemorySib`.
        mi_sib_u,
        /// Memory (RIP), immediate (unsigned) operands.
        /// Uses `x` payload with extra data of type `Imm32` followed by `MemoryRip`.
        mi_rip_u,
        /// Memory (SIB), immediate (sign-extend) operands.
        /// Uses `x` payload with extra data of type `Imm32` followed by `MemorySib`.
        mi_sib_s,
        /// Memory (RIP), immediate (sign-extend) operands.
        /// Uses `x` payload with extra data of type `Imm32` followed by `MemoryRip`.
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
        /// Uses `rr` payload.
        pseudo_set_z_and_np_r,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_z_and_np_m_sib,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_z_and_np_m_rip,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `rr` payload.
        pseudo_set_nz_or_p_r,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_nz_or_p_m_sib,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_nz_or_p_m_rip,
        /// Jump if zero flag set and parity flag not set
        /// Uses `inst` payload.
        pseudo_j_z_and_np_inst,
        /// Jump if zero flag not set or parity flag set
        /// Uses `inst` payload.
        pseudo_j_nz_or_p_inst,

        /// Probe alignment
        /// Uses `ri` payload
        pseudo_probe_align_ri_s,
        /// Probe adjust unrolled
        /// Uses `ri` payload
        pseudo_probe_adjust_unrolled_ri_s,
        /// Probe adjust setup
        /// Uses `rri` payload
        pseudo_probe_adjust_setup_rri_s,
        /// Probe adjust loop
        /// Uses `rr` payload
        pseudo_probe_adjust_loop_rr,
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
        rrrr: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            r3: Register,
            r4: Register,
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
            if (reg.id() == cpreg.id()) return @as(u32, @intCast(i));
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
        return @as(u32, @intCast(self.bitset.count()));
    }
};

pub const Imm32 = struct {
    imm: u32,
};

pub const Imm64 = struct {
    msb: u32,
    lsb: u32,

    pub fn encode(v: u64) Imm64 {
        return .{
            .msb = @as(u32, @truncate(v >> 32)),
            .lsb = @as(u32, @truncate(v)),
        };
    }

    pub fn decode(imm: Imm64) u64 {
        var res: u64 = 0;
        res |= (@as(u64, @intCast(imm.msb)) << 32);
        res |= @as(u64, @intCast(imm.lsb));
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
            .ptr_size = @intFromEnum(sib.ptr_size),
            .base_tag = @intFromEnum(@as(Memory.Base.Tag, sib.base)),
            .base = switch (sib.base) {
                .none => undefined,
                .reg => |r| @intFromEnum(r),
                .frame => |fi| @intFromEnum(fi),
            },
            .scale_index = @as(u32, sib.scale_index.scale) << 0 |
                @as(u32, if (sib.scale_index.scale > 0)
                @intFromEnum(sib.scale_index.index)
            else
                undefined) << 4,
            .disp = sib.disp,
        };
    }

    pub fn decode(msib: MemorySib) Memory {
        const scale = @as(u4, @truncate(msib.scale_index));
        assert(scale == 0 or std.math.isPowerOfTwo(scale));
        return .{ .sib = .{
            .ptr_size = @as(Memory.PtrSize, @enumFromInt(msib.ptr_size)),
            .base = switch (@as(Memory.Base.Tag, @enumFromInt(msib.base_tag))) {
                .none => .none,
                .reg => .{ .reg = @as(Register, @enumFromInt(msib.base)) },
                .frame => .{ .frame = @as(bits.FrameIndex, @enumFromInt(msib.base)) },
            },
            .scale_index = .{
                .scale = scale,
                .index = if (scale > 0) @as(Register, @enumFromInt(msib.scale_index >> 4)) else undefined,
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
            .ptr_size = @intFromEnum(mem.rip.ptr_size),
            .disp = mem.rip.disp,
        };
    }

    pub fn decode(mrip: MemoryRip) Memory {
        return .{ .rip = .{
            .ptr_size = @as(Memory.PtrSize, @enumFromInt(mrip.ptr_size)),
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
            .seg = @intFromEnum(seg),
            .msb = @as(u32, @truncate(offset >> 32)),
            .lsb = @as(u32, @truncate(offset >> 0)),
        };
    }

    pub fn decode(moffs: MemoryMoffs) Memory {
        return .{ .moffs = .{
            .seg = @as(Register, @enumFromInt(moffs.seg)),
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
            i32 => @as(i32, @bitCast(mir.extra[i])),
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
                .base = .{ .reg = mir.frame_locs.items(.base)[@intFromEnum(index)] },
                .disp = mir.frame_locs.items(.disp)[@intFromEnum(index)] + sib.disp,
                .scale_index = mem.scaleIndex(),
            }) else mem,
        },
        .rip, .moffs => mem,
    };
}
