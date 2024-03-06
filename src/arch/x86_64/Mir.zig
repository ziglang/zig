//! Machine Intermediate Representation.
//! This data is produced by x86_64 Codegen and consumed by x86_64 Isel.
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

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
        /// VEX-Encoded ___ Integer Data
        v_i128,
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
        /// Flush cache line
        clflush,
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
        /// CPU identification
        cpuid,
        /// Convert doubleword to quadword
        cqo,
        /// Convert word to doubleword
        cwd,
        /// Convert word to doubleword
        cwde,
        /// Decrement by 1
        dec,
        /// Unsigned division
        /// Signed division
        /// Divide packed single-precision floating-point values
        /// Divide scalar single-precision floating-point values
        /// Divide packed double-precision floating-point values
        /// Divide scalar double-precision floating-point values
        div,
        /// Increment by 1
        inc,
        /// Call to interrupt procedure
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
        /// Spin loop hint
        pause,
        /// Pop
        pop,
        /// Return the count of number of bits set to 1
        popcnt,
        /// Pop stack into EFLAGS register
        popfq,
        /// Push
        push,
        /// Push EFLAGS register onto the stack
        pushfq,
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
        /// Get value of extended control register
        xgetbv,
        /// Logical exclusive-or
        /// Bitwise logical xor of packed single-precision floating-point values
        /// Bitwise logical xor of packed double-precision floating-point values
        xor,

        /// Absolute value
        abs,
        /// Change sign
        chs,
        /// Free floating-point register
        free,
        /// Store integer with truncation
        istt,
        /// Load floating-point value
        ld,
        /// Load x87 FPU environment
        ldenv,
        /// Store x87 FPU environment
        nstenv,
        /// Store floating-point value
        st,
        /// Store x87 FPU environment
        stenv,

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
        /// Compare packed data for equal
        cmpeq,
        /// Compare packed data for greater than
        cmpgt,
        /// Maximum of packed signed integers
        maxs,
        /// Maximum of packed unsigned integers
        maxu,
        /// Minimum of packed signed integers
        mins,
        /// Minimum of packed unsigned integers
        minu,
        /// Move byte mask
        /// Extract packed single precision floating-point sign mask
        /// Extract packed double precision floating-point sign mask
        movmsk,
        /// Multiply packed signed integers and store low result
        mull,
        /// Multiply packed signed integers and store high result
        mulh,
        /// Shift packed data left logical
        sll,
        /// Shift packed data right arithmetic
        sra,
        /// Shift packed data right logical
        srl,
        /// Subtract packed signed integers with signed saturation
        subs,
        /// Subtract packed unsigned integers with unsigned saturation
        subus,

        /// Load MXCSR register
        ldmxcsr,
        /// Store MXCSR register state
        stmxcsr,

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
        /// Shuffle packed doublewords
        /// Shuffle packed words
        shuf,
        /// Shuffle packed high words
        shufh,
        /// Shuffle packed low words
        shufl,
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

        /// Packed align right
        alignr,

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
        /// Extract packed integer values
        extract,
        /// Insert scalar single-precision floating-point value
        /// Insert packed floating-point values
        insert,
        /// Packed move with sign extend
        movsxb,
        movsxd,
        movsxw,
        /// Packed move with zero extend
        movzxb,
        movzxd,
        movzxw,
        /// Round packed single-precision floating-point values
        /// Round scalar single-precision floating-point value
        /// Round packed double-precision floating-point values
        /// Round scalar double-precision floating-point value
        round,

        /// Carry-less multiplication quadword
        clmulq,

        /// Perform one round of an AES decryption flow
        aesdec,
        /// Perform last round of an AES decryption flow
        aesdeclast,
        /// Perform one round of an AES encryption flow
        aesenc,
        /// Perform last round of an AES encryption flow
        aesenclast,
        /// Perform the AES InvMixColumn transformation
        aesimc,
        /// AES round key generation assist
        aeskeygenassist,

        /// Perform an intermediate calculation for the next four SHA256 message dwords
        sha256msg1,
        /// Perform a final calculation for the next four SHA256 message dwords
        sha256msg2,
        /// Perform two rounds of SHA256 operation
        sha256rnds2,

        /// Load with broadcast floating-point data
        /// Load integer and broadcast
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
        /// Register, memory operands.
        /// Uses `rx` payload with extra data of type `Memory`.
        rm,
        /// Register, memory, register operands.
        /// Uses `rrx` payload with extra data of type `Memory`.
        rmr,
        /// Register, memory, immediate (word) operands.
        /// Uses `rix` payload with extra data of type `Memory`.
        rmi,
        /// Register, memory, immediate (signed) operands.
        /// Uses `rx` payload with extra data of type `Imm32` followed by `Memory`.
        rmi_s,
        /// Register, memory, immediate (unsigned) operands.
        /// Uses `rx` payload with extra data of type `Imm32` followed by `Memory`.
        rmi_u,
        /// Register, register, memory.
        /// Uses `rrix` payload with extra data of type `Memory`.
        rrm,
        /// Register, register, memory, register.
        /// Uses `rrrx` payload with extra data of type `Memory`.
        rrmr,
        /// Register, register, memory, immediate (byte) operands.
        /// Uses `rrix` payload with extra data of type `Memory`.
        rrmi,
        /// Single memory operand.
        /// Uses `x` with extra data of type `Memory`.
        m,
        /// Memory, immediate (sign-extend) operands.
        /// Uses `x` payload with extra data of type `Imm32` followed by `Memory`.
        mi_s,
        /// Memory, immediate (unsigned) operands.
        /// Uses `x` payload with extra data of type `Imm32` followed by `Memory`.
        mi_u,
        /// Memory, register operands.
        /// Uses `rx` payload with extra data of type `Memory`.
        mr,
        /// Memory, register, register operands.
        /// Uses `rrx` payload with extra data of type `Memory`.
        mrr,
        /// Memory, register, immediate (word) operands.
        /// Uses `rix` payload with extra data of type `Memory`.
        mri,
        /// References another Mir instruction directly.
        /// Uses `inst` payload.
        inst,
        /// Linker relocation - external function.
        /// Uses `reloc` payload.
        extern_fn_reloc,
        /// Linker relocation - GOT indirection.
        /// Uses `rx` payload with extra data of type `bits.Symbol`.
        got_reloc,
        /// Linker relocation - direct reference.
        /// Uses `rx` payload with extra data of type `bits.Symbol`.
        direct_reloc,
        /// Linker relocation - imports table indirection (binding).
        /// Uses `rx` payload with extra data of type `bits.Symbol`.
        import_reloc,
        /// Linker relocation - threadlocal variable via GOT indirection.
        /// Uses `rx` payload with extra data of type `bits.Symbol`.
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
        pseudo_cmov_nz_or_p_rm,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `rr` payload.
        pseudo_set_z_and_np_r,
        /// Set byte if zero flag set and parity flag not set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_z_and_np_m,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `rr` payload.
        pseudo_set_nz_or_p_r,
        /// Set byte if zero flag not set or parity flag set
        /// Requires a scratch register!
        /// Uses `rx` payload.
        pseudo_set_nz_or_p_m,
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
        /// Start or end of inline function
        pseudo_dbg_inline_func,

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
        /// Register, register, register, followed by Custom payload found in extra.
        rrrx: struct {
            fixes: Fixes = ._,
            r1: Register,
            r2: Register,
            r3: Register,
            payload: u32,
        },
        /// Register, byte immediate, followed by Custom payload found in extra.
        rix: struct {
            fixes: Fixes = ._,
            r1: Register,
            i: u16,
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
        reloc: bits.Symbol,
        /// Debug line and column position
        line_column: struct {
            line: u32,
            column: u32,
        },
        func: InternPool.Index,
        /// Register list
        reg_list: RegisterList,
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in safety builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (!std.debug.runtime_safety) {
            assert(@sizeOf(Data) == 8);
        }
    }
};

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet = BitSet.initEmpty(),

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(i);
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

    pub fn count(self: Self) i32 {
        return @intCast(self.bitset.count());
    }

    pub fn size(self: Self) i32 {
        return @intCast(self.bitset.count() * 8);
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
            .msb = @truncate(v >> 32),
            .lsb = @truncate(v),
        };
    }

    pub fn decode(imm: Imm64) u64 {
        var res: u64 = 0;
        res |= @as(u64, @intCast(imm.msb)) << 32;
        res |= @as(u64, @intCast(imm.lsb));
        return res;
    }
};

pub const Memory = struct {
    info: Info,
    base: u32,
    off: u32,
    extra: u32,

    pub const Info = packed struct(u32) {
        base: @typeInfo(bits.Memory.Base).Union.tag_type.?,
        mod: @typeInfo(bits.Memory.Mod).Union.tag_type.?,
        size: bits.Memory.Size,
        index: Register,
        scale: bits.Memory.Scale,
        _: u16 = undefined,
    };

    pub fn encode(mem: bits.Memory) Memory {
        assert(mem.base != .reloc or mem.mod != .off);
        return .{
            .info = .{
                .base = mem.base,
                .mod = mem.mod,
                .size = switch (mem.mod) {
                    .rm => |rm| rm.size,
                    .off => undefined,
                },
                .index = switch (mem.mod) {
                    .rm => |rm| rm.index,
                    .off => undefined,
                },
                .scale = switch (mem.mod) {
                    .rm => |rm| rm.scale,
                    .off => undefined,
                },
            },
            .base = switch (mem.base) {
                .none => undefined,
                .reg => |reg| @intFromEnum(reg),
                .frame => |frame_index| @intFromEnum(frame_index),
                .reloc => |symbol| symbol.sym_index,
            },
            .off = switch (mem.mod) {
                .rm => |rm| @bitCast(rm.disp),
                .off => |off| @truncate(off),
            },
            .extra = if (mem.base == .reloc)
                mem.base.reloc.atom_index
            else if (mem.mod == .off)
                @intCast(mem.mod.off >> 32)
            else
                undefined,
        };
    }

    pub fn decode(mem: Memory) encoder.Instruction.Memory {
        switch (mem.info.mod) {
            .rm => {
                if (mem.info.base == .reg and @as(Register, @enumFromInt(mem.base)) == .rip) {
                    assert(mem.info.index == .none and mem.info.scale == .@"1");
                    return encoder.Instruction.Memory.rip(mem.info.size, @bitCast(mem.off));
                }
                return encoder.Instruction.Memory.sib(mem.info.size, .{
                    .disp = @bitCast(mem.off),
                    .base = switch (mem.info.base) {
                        .none => .none,
                        .reg => .{ .reg = @enumFromInt(mem.base) },
                        .frame => .{ .frame = @enumFromInt(mem.base) },
                        .reloc => .{ .reloc = .{ .atom_index = mem.extra, .sym_index = mem.base } },
                    },
                    .scale_index = switch (mem.info.index) {
                        .none => null,
                        else => |index| .{ .scale = switch (mem.info.scale) {
                            inline else => |scale| comptime std.fmt.parseInt(
                                u4,
                                @tagName(scale),
                                10,
                            ) catch unreachable,
                        }, .index = index },
                    },
                });
            },
            .off => {
                assert(mem.info.base == .reg);
                return encoder.Instruction.Memory.moffs(
                    @enumFromInt(mem.base),
                    @as(u64, mem.extra) << 32 | mem.off,
                );
            },
        }
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
            i32, Memory.Info => @bitCast(mir.extra[i]),
            else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
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
    return switch (mem.info.base) {
        .none, .reg, .reloc => mem,
        .frame => if (mir.frame_locs.len > 0) Memory{
            .info = .{
                .base = .reg,
                .mod = mem.info.mod,
                .size = mem.info.size,
                .index = mem.info.index,
                .scale = mem.info.scale,
            },
            .base = @intFromEnum(mir.frame_locs.items(.base)[mem.base]),
            .off = @bitCast(mir.frame_locs.items(.disp)[mem.base] + @as(i32, @bitCast(mem.off))),
            .extra = mem.extra,
        } else mem,
    };
}

const assert = std.debug.assert;
const bits = @import("bits.zig");
const builtin = @import("builtin");
const encoder = @import("encoder.zig");
const std = @import("std");

const IntegerBitSet = std.bit_set.IntegerBitSet;
const InternPool = @import("../../InternPool.zig");
const Mir = @This();
const Register = bits.Register;
