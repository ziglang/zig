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
table: []const Inst.Index,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Tag,
    ops: Ops,
    data: Data,

    pub const Index = u32;

    pub const Fixes = enum(u8) {
        /// ___
        @"_",

        /// ___ 0
        _0,
        /// ___ 1
        _1,
        /// ___ 2
        _2,
        /// ___ 3
        _3,
        /// ___ 4
        _4,

        /// ___ Demote
        _demote,
        /// ___ Flush
        _flush,
        /// ___ Flush Optimized
        _flushopt,
        /// ___ Instructions With T0 Hint
        _it0,
        /// ___ Instructions With T0 Hint
        _it1,
        /// ___ With NTA Hint
        _nta,
        /// System Call ___
        sys_,
        /// ___ With T0 Hint
        _t0,
        /// ___ With T1 Hint
        _t1,
        /// ___ With T2 Hint
        _t2,
        /// ___ Write Back
        _wb,
        /// ___ With Intent to Write and T1 Hint
        _wt1,

        /// ___ crement Shadow Stack Pointer Doubleword
        _csspd,
        /// ___ crement Shadow Stack Pointer Quadword
        _csspq,
        /// ___ FS Segment Base
        _fsbase,
        /// ___ GS
        _gs,
        /// ___ GS Segment Base
        _gsbase,
        /// ___ Model Specific Register
        _msr,
        /// ___ MXCSR
        _mxcsr,
        /// ___ Processor ID
        _pid,
        /// ___ Protection Key Rights For User Pages
        _pkru,
        /// ___ Performance-Monitoring Counters
        _pmc,
        /// ___ Random Number
        _rand,
        /// ___ r Busy Flag in a Supervisor Shadow Stack token
        _rssbsy,
        /// ___ Random Seed
        _seed,
        /// ___ Shadow Stack Doubleword
        _ssd,
        /// ___ Shadow Stack Quadword
        _ssq,
        /// ___ Shadow Stack Pointer Doubleword
        _sspd,
        /// ___ Shadow Stack Pointer Quadword
        _sspq,
        /// ___ Time-Stamp Counter
        _tsc,
        /// ___ Time-Stamp Counter And Processor ID
        _tscp,
        /// ___ User Shadow Stack Doubleword
        _ussd,
        /// ___ User Shadow Stack Quadword
        _ussq,
        /// VEX-Encoded ___ MXCSR
        v_mxcsr,

        /// Byte ___
        b_,
        /// Interrupt ___
        /// Integer ___
        i_,
        /// Interrupt ___ Word
        i_w,
        /// Interrupt ___ Doubleword
        i_d,
        /// Interrupt ___ Quadword
        i_q,
        /// User-Interrupt ___
        ui_,

        /// ___ mp
        _mp,
        /// ___ if CX register is 0
        _cxz,
        /// ___ if ECX register is 0
        _ecxz,
        /// ___ if RCX register is 0
        _rcxz,

        /// ___ Addition
        _a,
        /// ___ Subtraction
        _s,
        /// ___ Multiply
        _m,
        /// ___ Division
        _d,

        /// ___ Without Affecting Flags
        _x,
        /// ___ Left
        _l,
        /// ___ Left Double
        _ld,
        /// ___ Left Without Affecting Flags
        _lx,
        /// ___ Mask
        _msk,
        /// ___ Right
        /// ___ For Reading
        /// ___ Register
        _r,
        /// ___ Right Double
        _rd,
        /// ___ Right Without Affecting Flags
        _rx,

        /// ___ Forward
        _f,
        /// ___ Reverse
        //_r,

        /// ___ Above
        //_a,
        /// ___ Above Or Equal
        _ae,
        /// ___ Below
        _b,
        /// ___ Below Or Equal
        /// ___ Big Endian
        _be,
        /// ___ Carry
        /// ___ Carry Flag
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
        //_s,
        /// ___ Zero
        _z,
        /// ___ Alignment Check Flag
        _ac,
        /// ___ Direction Flag
        //_d,
        /// ___ Interrupt Flag
        _i,
        /// ___ Task-Switched Flag In CR0
        _ts,
        /// ___ User Interrupt Flag
        _ui,

        /// ___ Byte
        //_b,
        /// ___ Word
        /// ___ For Writing
        /// ___ With Intent to Write
        _w,
        /// ___ Doubleword
        //_d,
        /// ___ Double Quadword to Quadword
        _dq2q,
        /// ___ QuadWord
        _q,
        /// ___ Quadword to Double Quadword
        _q2dq,

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
        /// Float ___ +1.0
        /// Float ___ 1
        f_1,
        /// Float ___ Below
        f_b,
        /// Float ___ Below Or Equal
        f_be,
        /// Float ___ Control Word
        f_cw,
        /// Float ___ Equal
        f_e,
        /// Float ___ Environment
        f_env,
        /// Float ___ log_2(e)
        f_l2e,
        /// Float ___ log_2(10)
        f_l2t,
        /// Float ___ log_10(2)
        f_lg2,
        /// Float ___ log_e(2)
        f_ln2,
        /// Float ___ Not Below
        f_nb,
        /// Float ___ Not Below Or Equal
        f_nbe,
        /// Float ___ Not Equal
        f_ne,
        /// Float ___ Not Unordered
        f_nu,
        /// Float ___ Pop
        f_p,
        /// Float ___ +1
        f_p1,
        /// Float ___ π
        f_pi,
        /// Float ___ Pop Pop
        f_pp,
        /// Float ___ crement Stack-Top Pointer
        f_cstp,
        /// Float ___ Status Word
        f_sw,
        /// Float ___ Unordered
        f_u,
        /// Float ___ +0.0
        f_z,
        /// Float BCD ___
        fb_,
        /// Float BCD ___ Pop
        fb_p,
        /// Float And Integer ___
        fi_,
        /// Float And Integer ___ Pop
        fi_p,
        /// Float No Wait ___
        fn_,
        /// Float No Wait ___ Control Word
        fn_cw,
        /// Float No Wait ___ Environment
        fn_env,
        /// Float No Wait ___ status word
        fn_sw,
        /// Float Extended ___
        fx_,
        /// Float Extended ___ 64
        fx_64,

        /// ___ in 32-bit and Compatibility Mode
        _32,
        /// ___ in 64-bit Mode
        _64,

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
        /// Packed ___ Doubleword to Quadword
        p_dq,
        /// Packed ___ Unsigned Doubleword to Quadword
        p_udq,
        /// Packed Carry-Less ___ Quadword to Double Quadword
        pcl_qdq,
        /// Packed Half ___ Doubleword
        ph_d,
        /// Packed Half ___ Saturate Word
        ph_sw,
        /// Packed Half ___ Word
        ph_w,
        /// ___ Aligned Packed Integer Values
        _dqa,
        /// ___ Unaligned Packed Integer Values
        _dqu,

        /// ___ Scalar Single-Precision Values
        _ss,
        /// ___ Packed Single-Precision Values
        _ps,
        /// ___ Scalar Double-Precision Values
        //_sd,
        /// ___ Packed Double-Precision Values
        _pd,
        /// Half ___ Packed Single-Precision Values
        h_ps,
        /// Half ___ Packed Double-Precision Values
        h_pd,

        /// ___ Internal Caches
        //_d,
        /// ___ TLB Entries
        _lpg,
        /// ___ Process-Context Identifier
        _pcid,

        /// Load ___
        l_,
        /// Memory ___
        m_,
        /// Store ___
        s_,
        /// Timed ___
        t_,
        /// User Level Monitor ___
        um_,

        /// VEX-Encoded ___
        v_,
        /// VEX-Encoded ___ Byte
        v_b,
        /// VEX-Encoded ___ Word
        v_w,
        /// VEX-Encoded ___ Doubleword
        v_d,
        /// VEX-Encoded ___ Quadword
        v_q,
        /// VEX-Encoded ___ Aligned Packed Integer Values
        v_dqa,
        /// VEX-Encoded ___ Unaligned Packed Integer Values
        v_dqu,
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
        /// VEX-Encoded Packed ___ Doubleword to Quadword
        vp_dq,
        /// VEX-Encoded Packed ___ Unsigned Doubleword to Quadword
        vp_udq,
        /// VEx-Encoded Packed Carry-Less ___ Quadword to Double Quadword
        vpcl_qdq,
        /// VEX-Encoded Packed Half ___ Doubleword
        vph_d,
        /// VEX-Encoded Packed Half ___ Saturate Word
        vph_sw,
        /// VEX-Encoded Packed Half ___ Word
        vph_w,
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
        /// VEX-Encoded Half ___ Packed Single-Precision Values
        vh_ps,
        /// VEX-Encoded Half ___ Packed Double-Precision Values
        vh_pd,

        /// ___ 128-bit key with key locker
        _128,
        /// ___ 256-bit key with key locker
        _256,
        /// ___ with key locker using 128-bit key
        _128kl,
        /// ___ with key locker using 256-bit key
        _256kl,
        /// ___ with key locker on 8 blocks using 128-bit key
        _wide128kl,
        /// ___ with key locker on 8 blocks using 256-bit key
        _wide256kl,

        /// Mask ___ Byte
        k_b,
        /// Mask ___ Word
        k_w,
        /// Mask ___ Doubleword
        k_d,
        /// Mask ___ Quadword
        k_q,

        pub fn fromCond(cc: bits.Condition) Fixes {
            return switch (cc) {
                inline else => |cc_tag| @field(Fixes, "_" ++ @tagName(cc_tag)),
                .z_and_np, .nz_or_p => unreachable,
            };
        }
    };

    pub const Tag = enum(u8) {
        // General-purpose
        /// ASCII adjust al after addition
        /// ASCII adjust ax before division
        /// ASCII adjust ax after multiply
        /// ASCII adjust al after subtraction
        aa,
        /// Add with carry
        /// Unsigned integer addition of two operands with carry flag
        adc,
        /// Add
        /// Add packed integers
        /// Add packed single-precision floating-point values
        /// Add scalar single-precision floating-point values
        /// Add packed double-precision floating-point values
        /// Add scalar double-precision floating-point values
        /// Packed single-precision floating-point horizontal add
        /// Packed double-precision floating-point horizontal add
        /// Packed horizontal add
        /// Packed horizontal add and saturate
        add,
        /// Logical and
        /// Bitwise logical and of packed single-precision floating-point values
        /// Bitwise logical and of packed double-precision floating-point values
        @"and",
        /// Adjust RPL field of segment selector
        arpl,
        /// Bit scan forward
        /// Bit scan reverse
        bs,
        /// Byte swap
        /// Swap GS base register
        swap,
        /// Bit test
        /// Bit test and complement
        /// Bit test and reset
        /// Bit test and set
        bt,
        /// Check array index against bounds
        bound,
        /// Call
        /// Fast system call
        call,
        /// Convert byte to word
        cbw,
        /// Convert doubleword to quadword
        cdq,
        /// Convert doubleword to quadword
        cdqe,
        /// Clear AC flag in EFLAGS register
        /// Clear carry flag
        /// Clear direction flag
        /// Clear interrupt flag
        /// Clear task-switched flag in CR0
        /// Clear user interrupt flag
        /// Cache line demote
        /// Flush cache line
        /// Flush cache line optimized
        /// Clear busy flag in a supervisor shadow stack token
        /// Cache line write back
        cl,
        /// Complement carry flag
        cmc,
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
        /// Decimal adjust AL after addition
        /// Decimal adjust AL after subtraction
        da,
        /// Decrement by 1
        /// Decrement stack-top pointer
        /// Decrement shadow stack pointer
        de,
        /// Unsigned division
        /// Signed division
        /// Divide
        /// Divide packed single-precision floating-point values
        /// Divide scalar single-precision floating-point values
        /// Divide packed double-precision floating-point values
        /// Divide scalar double-precision floating-point values
        div,
        /// Terminate and indirect branch in 32-bit and compatibility mode
        /// Terminate and indirect branch in 64-bit mode
        endbr,
        /// Enqueue command
        /// Enqueue command supervisor
        enqcmd,
        /// Make stack frame for procedure parameters
        /// Fast system call
        enter,
        /// Fast return from fast system call
        exit,
        /// Load fence
        /// Memory fence
        /// Store fence
        fence,
        /// Halt
        hlt,
        /// History reset
        hreset,
        /// Input from port
        /// Input from port to string
        /// Increment by 1
        /// Increment stack-top pointer
        /// Increment shadow stack pointer
        in,
        /// Call to interrupt procedure
        int,
        /// Invalidate internal caches
        /// Invalidate TLB entries
        /// Invalidate process-context identifier
        inv,
        /// Conditional jump
        /// Jump
        j,
        /// Load status flags into AH register
        lahf,
        /// Load access right byte
        lar,
        /// Load effective address
        lea,
        /// High level procedure exit
        leave,
        /// Load global descriptor table register
        lgdt,
        /// Load interrupt descriptor table register
        lidt,
        /// Load local descriptor table register
        lldt,
        /// Load machine status word
        lmsw,
        /// Load string
        lod,
        /// Loop according to ECX counter
        loop,
        /// Load segment limit
        lsl,
        /// Load task register
        ltr,
        /// Count the number of leading zero bits
        lzcnt,
        /// Move
        /// Move data from string to string
        /// Move data after swapping bytes
        /// Move scalar single-precision floating-point value
        /// Move scalar double-precision floating-point value
        /// Move doubleword
        /// Move quadword
        /// Move aligned packed integer values
        /// Move unaligned packed integer values
        /// Move quadword from XMM to MMX technology register
        /// Move quadword from MMX technology to XMM register
        mov,
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
        /// Multiply packed unsigned doubleword integers
        /// Multiply packed doubleword integers
        /// Carry-less multiplication quadword
        mul,
        /// Two's complement negation
        neg,
        /// No-op
        /// No operation
        nop,
        /// One's complement negation
        not,
        /// Logical or
        /// Bitwise logical or of packed single-precision floating-point values
        /// Bitwise logical or of packed double-precision floating-point values
        @"or",
        /// Output to port
        /// Output string to port
        out,
        /// Spin loop hint
        /// Timed pause
        pause,
        /// Pop
        pop,
        /// Return the count of number of bits set to 1
        popcnt,
        /// Pop stack into EFLAGS register
        popf,
        /// Push
        push,
        /// Push EFLAGS register onto the stack
        pushf,
        /// Rotate left through carry
        /// Rotate right through carry
        rc,
        /// Read FS segment base
        /// Read GS segment base
        /// Read from model specific register
        /// Read processor ID
        /// Read protection key rights for user pages
        /// Read performance-monitoring counters
        /// Read random number
        /// Read random seed
        /// Read shadow stack pointer
        /// Read time-stamp counter
        /// Read time-stamp counter and processor ID
        rd,
        /// Return
        /// Return from fast system call
        /// Interrupt return
        /// User-interrupt return
        ret,
        /// Rotate left
        /// Rotate right
        /// Rotate right logical without affecting flags
        ro,
        /// Resume from system management mode
        rsm,
        /// Arithmetic shift left
        /// Arithmetic shift right
        /// Shift left arithmetic without affecting flags
        sa,
        /// Store AH into flags
        sahf,
        /// Integer subtraction with borrow
        sbb,
        /// Scan string
        sca,
        /// Send user interprocessor interrupt
        senduipi,
        /// Serialize instruction execution
        serialize,
        /// Set byte on condition
        set,
        /// Logical shift left
        /// Double precision shift left
        /// Logical shift right
        /// Double precision shift right
        /// Shift left logical without affecting flags
        /// Shift right logical without affecting flags
        sh,
        /// Store interrupt descriptor table register
        sidt,
        /// Store local descriptor table register
        sldt,
        /// Store machine status word
        smsw,
        /// Subtract
        /// Subtract packed integers
        /// Subtract packed single-precision floating-point values
        /// Subtract scalar single-precision floating-point values
        /// Subtract packed double-precision floating-point values
        /// Subtract scalar double-precision floating-point values
        /// Packed single-precision floating-point horizontal subtract
        /// Packed double-precision floating-point horizontal subtract
        /// Packed horizontal subtract
        /// Packed horizontal subtract and saturate
        sub,
        /// Set carry flag
        /// Set direction flag
        /// Set interrupt flag
        /// Store binary coded decimal integer and pop
        /// Store floating-point value
        /// Store integer
        /// Store x87 FPU control word
        /// Store x87 FPU environment
        /// Store x87 FPU status word
        /// Store MXCSR register state
        st,
        /// Store string
        sto,
        /// Test condition
        /// Logical compare
        /// Packed bit test
        @"test",
        /// Undefined instruction
        ud,
        /// User level set up monitor address
        umonitor,
        /// Verify a segment for reading
        /// Verify a segment for writing
        ver,
        /// Write to model specific register
        /// Write to model specific register
        /// Write to model specific register
        /// Write to shadow stack
        /// Write to user shadow stack
        wr,
        /// Exchange and add
        xadd,
        /// Exchange register/memory with register
        /// Exchange register contents
        xch,
        /// Get value of extended control register
        xgetbv,
        /// Table look-up translation
        xlat,
        /// Logical exclusive-or
        /// Bitwise logical xor of packed single-precision floating-point values
        /// Bitwise logical xor of packed double-precision floating-point values
        xor,

        // X87
        /// Compute 2^x-1
        @"2xm1",
        /// Absolute value
        abs,
        /// Change sign
        chs,
        /// Clear exceptions
        clex,
        /// Compare floating-point values
        com,
        /// Compare floating-point values and set EFLAGS
        /// Compare scalar ordered single-precision floating-point values
        /// Compare scalar ordered double-precision floating-point values
        comi,
        /// Cosine
        cos,
        /// Reverse divide
        divr,
        /// Free floating-point register
        free,
        /// Initialize floating-point unit
        init,
        /// Load binary coded decimal integer
        /// Load floating-point value
        /// Load integer
        /// Load constant
        /// Load x87 FPU control word
        /// Load x87 FPU environment
        /// Load MXCSR register state
        ld,
        /// Partial arctangent
        patan,
        /// Partial remainder
        prem,
        /// Partial tangent
        ptan,
        /// Round to integer
        rndint,
        /// Restore x87 FPU state
        /// Restore x87 FPU, MMX, XMM, and MXCSR state
        rstor,
        /// Store x87 FPU state
        /// Save x87 FPU, MMX technology, and MXCSR state
        save,
        /// Scale
        scale,
        /// Sine
        sin,
        /// Sine and cosine
        sincos,
        /// Square root
        /// Square root of packed single-precision floating-point values
        /// Square root of scalar single-precision floating-point value
        /// Square root of packed double-precision floating-point values
        /// Square root of scalar double-precision floating-point value
        sqrt,
        /// Store integer with truncation
        stt,
        /// Reverse subtract
        subr,
        /// Test
        tst,
        /// Unordered compare floating-point values
        ucom,
        /// Unordered compare floating-point values and set EFLAGS
        /// Unordered compare scalar single-precision floating-point values
        /// Unordered compare scalar double-precision floating-point values
        ucomi,
        /// Wait
        /// User level monitor wait
        wait,
        /// Examine floating-point
        xam,
        /// Extract exponent and significand
        xtract,
        /// Compute y * log2x
        /// Compute y * log2(x + 1)
        yl2x,

        // MMX
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
        /// Logical and not
        /// Bitwise logical and not of packed single-precision floating-point values
        /// Bitwise logical and not of packed double-precision floating-point values
        andn,
        /// Compare packed data for equal
        cmpeq,
        /// Compare packed data for greater than
        cmpgt,
        /// Empty MMX technology state
        emms,
        /// Multiply and add packed signed and unsigned bytes
        maddubs,
        /// Multiply and add packed integers
        maddw,
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
        /// Unpack high data
        unpckhbw,
        /// Unpack high data
        unpckhdq,
        /// Unpack high data
        unpckhwd,
        /// Unpack low data
        unpcklbw,
        /// Unpack low data
        unpckldq,
        /// Unpack low data
        unpcklwd,

        // SSE
        /// Average packed integers
        avg,
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
        /// Maximum of packed single-precision floating-point values
        /// Maximum of scalar single-precision floating-point values
        /// Maximum of packed double-precision floating-point values
        /// Maximum of scalar double-precision floating-point values
        max,
        /// Maximum of packed signed integers
        maxs,
        /// Maximum of packed unsigned integers
        maxu,
        /// Minimum of packed single-precision floating-point values
        /// Minimum of scalar single-precision floating-point values
        /// Minimum of packed double-precision floating-point values
        /// Minimum of scalar double-precision floating-point values
        min,
        /// Minimum of packed signed integers
        mins,
        /// Minimum of packed unsigned integers
        minu,
        /// Move aligned packed single-precision floating-point values
        /// Move aligned packed double-precision floating-point values
        mova,
        /// Move high packed single-precision floating-point values
        /// Move high packed double-precision floating-point values
        movh,
        /// Move packed single-precision floating-point values high to low
        movhl,
        /// Move low packed single-precision floating-point values
        /// Move low packed double-precision floating-point values
        movl,
        /// Move packed single-precision floating-point values low to high
        movlh,
        /// Move byte mask
        /// Extract packed single precision floating-point sign mask
        /// Extract packed double precision floating-point sign mask
        movmsk,
        /// Move unaligned packed single-precision floating-point values
        /// Move unaligned packed double-precision floating-point values
        movu,
        /// Multiply packed unsigned integers and store high result
        mulhu,
        /// Prefetch data into caches
        /// Prefetch data into caches with intent to write
        prefetch,
        /// Compute sum of absolute differences
        sadb,
        /// Packed interleave shuffle of quadruplets of single-precision floating-point values
        /// Packed interleave shuffle of pairs of double-precision floating-point values
        /// Shuffle packed doublewords
        /// Shuffle packed words
        shuf,
        /// Unpack and interleave high packed single-precision floating-point values
        /// Unpack and interleave high packed double-precision floating-point values
        unpckh,
        /// Unpack and interleave low packed single-precision floating-point values
        /// Unpack and interleave low packed double-precision floating-point values
        unpckl,

        // SSE2
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
        /// Galois field affine transformation inverse
        gf2p8affineinvq,
        /// Galois field affine transformation
        gf2p8affineq,
        /// Galois field multiply bytes
        gf2p8mul,
        /// Shuffle packed high words
        shufh,
        /// Shuffle packed low words
        shufl,
        /// Unpack high data
        unpckhqdq,
        /// Unpack low data
        unpcklqdq,

        // SSE3
        /// Packed single-precision floating-point add/subtract
        /// Packed double-precision floating-point add/subtract
        addsub,
        /// Replicate double floating-point values
        movddup,
        /// Replicate single floating-point values
        movshdup,
        /// Replicate single floating-point values
        movsldup,

        // SSSE3
        /// Packed align right
        alignr,
        /// Packed multiply high with round and scale
        mulhrs,
        /// Packed sign
        sign,

        // SSE4.1
        /// Pack with unsigned saturation
        ackusd,
        /// Blend packed single-precision floating-point values
        /// Blend scalar single-precision floating-point values
        /// Blend packed double-precision floating-point values
        /// Blend scalar double-precision floating-point values
        /// Blend packed dwords
        blend,
        /// Variable blend packed single-precision floating-point values
        /// Variable blend scalar single-precision floating-point values
        /// Variable blend packed double-precision floating-point values
        /// Variable blend scalar double-precision floating-point values
        blendv,
        /// Dot product of packed single-precision floating-point values
        /// Dot product of packed double-precision floating-point values
        dp,
        /// Extract packed floating-point values
        /// Extract packed integer values
        extract,
        /// Packed horizontal word minimum
        hminposu,
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

        // SSE4.2
        /// Accumulate CRC32 value
        crc32,

        // AES
        /// Perform one round of an AES decryption flow
        /// Perform ten rounds of AES decryption flow with key locker using 128-bit key
        /// Perform ten rounds of AES decryption flow with key locker using 256-bit key
        /// Perform ten rounds of AES decryption flow with key locker on 8 blocks using 128-bit key
        /// Perform ten rounds of AES decryption flow with key locker on 8 blocks using 256-bit key
        aesdec,
        /// Perform last round of an AES decryption flow
        aesdeclast,
        /// Perform one round of an AES encryption flow
        /// Perform ten rounds of AES encryption flow with key locker using 128-bit key
        /// Perform ten rounds of AES encryption flow with key locker using 256-bit key
        /// Perform ten rounds of AES encryption flow with key locker on 8 blocks using 128-bit key
        /// Perform ten rounds of AES encryption flow with key locker on 8 blocks using 256-bit key
        aesenc,
        /// Perform last round of an AES encryption flow
        aesenclast,
        /// Perform the AES InvMixColumn transformation
        aesimc,
        /// AES round key generation assist
        aeskeygenassist,

        // SHA
        /// Perform four rounds of SHA1 operation
        sha1rnds,
        /// Calculate SHA1 state variable E after four rounds
        sha1nexte,
        /// Perform an intermediate calculation for the next four SHA1 message dwords
        /// Perform a final calculation for the next four SHA1 message dwords
        sha1msg,
        /// Perform an intermediate calculation for the next four SHA256 message dwords
        /// Perform a final calculation for the next four SHA256 message dwords
        sha256msg,
        /// Perform two rounds of SHA256 operation
        sha256rnds,

        // AVX
        /// Load with broadcast floating-point data
        /// Load integer and broadcast
        broadcast,
        /// Conditional SIMD packed loads and stores
        /// Condition SIMD integer packed loads and stores
        maskmov,
        /// Permute floating-point values
        /// Permute integer values
        perm2,
        /// Permute in-lane pairs of double-precision floating-point values
        /// Permute in-lane quadruples of single-precision floating-point values
        permil,

        // BMI
        /// Bit field extract
        bextr,
        /// Extract lowest set isolated bit
        /// Get mask up to lowest set bit
        /// Reset lowest set bit
        bls,
        /// Count the number of trailing zero bits
        tzcnt,

        // BMI2
        /// Zero high bits starting with specified bit position
        bzhi,
        /// Parallel bits deposit
        pdep,
        /// Parallel bits extract
        pext,

        // F16C
        /// Convert 16-bit floating-point values to single-precision floating-point values
        cvtph2,
        /// Convert single-precision floating-point values to 16-bit floating-point values
        cvtps2ph,

        // FMA
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

        // AVX2
        /// Permute packed doubleword elements
        /// Permute packed qword elements
        /// Permute double-precision floating-point elements
        /// Permute single-precision floating-point elements
        perm,
        /// Variable bit shift left logical
        sllv,
        /// Variable bit shift right arithmetic
        srav,
        /// Variable bit shift right logical
        srlv,

        // ADX
        /// Unsigned integer addition of two operands with overflow flag
        ado,

        // AESKLE
        /// Encode 128-bit key with key locker
        /// Encode 256-bit key with key locker
        encodekey,
        /// Load internal wrapping key with key locker
        loadiwkey,

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
        /// Uses `ri` payload with `i` index of extra data of type `Imm64`.
        ri_64,
        /// Immediate (sign-extended) operand.
        /// Uses `i` payload.
        i_s,
        /// Immediate (unsigned) operand.
        /// Uses `i` payload.
        i_u,
        /// Immediate (word), immediate (byte) operands.
        /// Uses `ii` payload.
        ii,
        /// Immediate (byte), register operands.
        /// Uses `ri` payload.
        ir,
        /// Relative displacement operand.
        /// Uses `reloc` payload.
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
        /// Uses `x` payload with extra data of type `Memory`.
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
        /// Uses `rx` payload with extra data of type `bits.SymbolOffset`.
        got_reloc,
        /// Linker relocation - direct reference.
        /// Uses `rx` payload with extra data of type `bits.SymbolOffset`.
        direct_reloc,
        /// Linker relocation - imports table indirection (binding).
        /// Uses `rx` payload with extra data of type `bits.SymbolOffset`.
        import_reloc,
        /// Linker relocation - threadlocal variable via GOT indirection.
        /// Uses `rx` payload with extra data of type `bits.SymbolOffset`.
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
        /// Uses `ri` payload.
        pseudo_probe_align_ri_s,
        /// Probe adjust unrolled
        /// Uses `ri` payload.
        pseudo_probe_adjust_unrolled_ri_s,
        /// Probe adjust setup
        /// Uses `rri` payload.
        pseudo_probe_adjust_setup_rri_s,
        /// Probe adjust loop
        /// Uses `rr` payload.
        pseudo_probe_adjust_loop_rr,

        /// Push registers
        /// Uses `reg_list` payload.
        pseudo_push_reg_list,
        /// Pop registers
        /// Uses `reg_list` payload.
        pseudo_pop_reg_list,

        /// Define cfa rule as offset from register.
        /// Uses `ri` payload.
        pseudo_cfi_def_cfa_ri_s,
        /// Modify cfa rule register.
        /// Uses `r` payload.
        pseudo_cfi_def_cfa_register_r,
        /// Modify cfa rule offset.
        /// Uses `i` payload.
        pseudo_cfi_def_cfa_offset_i_s,
        /// Offset cfa rule offset.
        /// Uses `i` payload.
        pseudo_cfi_adjust_cfa_offset_i_s,
        /// Define register rule as stored at offset from cfa.
        /// Uses `ri` payload.
        pseudo_cfi_offset_ri_s,
        /// Define register rule as offset from cfa.
        /// Uses `ri` payload.
        pseudo_cfi_val_offset_ri_s,
        /// Define register rule as stored at offset from cfa rule register.
        /// Uses `ri` payload.
        pseudo_cfi_rel_offset_ri_s,
        /// Define register rule as register.
        /// Uses `rr` payload.
        pseudo_cfi_register_rr,
        /// Define register rule from initial.
        /// Uses `r` payload.
        pseudo_cfi_restore_r,
        /// Define register rule as undefined.
        /// Uses `r` payload.
        pseudo_cfi_undefined_r,
        /// Define register rule as itself.
        /// Uses `r` payload.
        pseudo_cfi_same_value_r,
        /// Push cfi state.
        pseudo_cfi_remember_state_none,
        /// Pop cfi state.
        pseudo_cfi_restore_state_none,
        /// Raw cfi bytes.
        /// Uses `bytes` payload.
        pseudo_cfi_escape_bytes,

        /// End of prologue
        pseudo_dbg_prologue_end_none,
        /// Update debug line with is_stmt register set
        /// Uses `line_column` payload.
        pseudo_dbg_line_stmt_line_column,
        /// Update debug line with is_stmt register clear
        /// Uses `line_column` payload.
        pseudo_dbg_line_line_column,
        /// Start of epilogue
        pseudo_dbg_epilogue_begin_none,
        /// Start of lexical block
        pseudo_dbg_enter_block_none,
        /// End of lexical block
        pseudo_dbg_leave_block_none,
        /// Start of inline function
        pseudo_dbg_enter_inline_func,
        /// End of inline function
        pseudo_dbg_leave_inline_func,
        /// Local argument or variable.
        /// Uses `a` payload.
        pseudo_dbg_local_a,
        /// Local argument or variable.
        /// Uses `ai` payload.
        pseudo_dbg_local_ai_s,
        /// Local argument or variable.
        /// Uses `ai` payload.
        pseudo_dbg_local_ai_u,
        /// Local argument or variable.
        /// Uses `ai` payload with extra data of type `Imm64`.
        pseudo_dbg_local_ai_64,
        /// Local argument or variable.
        /// Uses `as` payload.
        pseudo_dbg_local_as,
        /// Local argument or variable.
        /// Uses `ax` payload with extra data of type `bits.SymbolOffset`.
        pseudo_dbg_local_aso,
        /// Local argument or variable.
        /// Uses `rx` payload with extra data of type `AirOffset`.
        pseudo_dbg_local_aro,
        /// Local argument or variable.
        /// Uses `ax` payload with extra data of type `bits.FrameAddr`.
        pseudo_dbg_local_af,
        /// Local argument or variable.
        /// Uses `ax` payload with extra data of type `Memory`.
        pseudo_dbg_local_am,
        /// Remaining arguments are varargs.
        pseudo_dbg_var_args_none,

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
        ii: struct {
            fixes: Fixes = ._,
            i1: u16,
            i2: u8,
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
        bytes: struct {
            payload: u32,
            len: u32,

            pub fn get(bytes: @This(), mir: Mir) []const u8 {
                return std.mem.sliceAsBytes(mir.extra[bytes.payload..])[0..bytes.len];
            }
        },
        a: struct {
            air_inst: Air.Inst.Index,
        },
        ai: struct {
            air_inst: Air.Inst.Index,
            i: u32,
        },
        as: struct {
            air_inst: Air.Inst.Index,
            sym_index: u32,
        },
        ax: struct {
            air_inst: Air.Inst.Index,
            payload: u32,
        },
        /// Relocation for the linker where:
        /// * `sym_index` is the index of the target
        /// * `off` is the offset from the target
        reloc: bits.SymbolOffset,
        /// Debug line and column position
        line_column: struct {
            line: u32,
            column: u32,
        },
        func: InternPool.Index,
        /// Register list
        reg_list: RegisterList,
    };

    comptime {
        if (!std.debug.runtime_safety) {
            // Make sure we don't accidentally make instructions bigger than expected.
            // Note that in safety builds, Zig is allowed to insert a secret field for safety checks.
            assert(@sizeOf(Data) == 8);
        }
        const Mnemonic = @import("Encoding.zig").Mnemonic;
        if (@typeInfo(Mnemonic).@"enum".fields.len != 977 or
            @typeInfo(Fixes).@"enum".fields.len != 231 or
            @typeInfo(Tag).@"enum".fields.len != 251)
        {
            const cond_src = (struct {
                fn src() std.builtin.SourceLocation {
                    return @src();
                }
            }).src();
            @setEvalBranchQuota(1_750_000);
            for (@typeInfo(Mnemonic).@"enum".fields) |mnemonic| {
                if (mnemonic.name[0] == '.') continue;
                for (@typeInfo(Fixes).@"enum".fields) |fixes| {
                    const pattern = fixes.name[if (std.mem.indexOfScalar(u8, fixes.name, ' ')) |index| index + " ".len else 0..];
                    const wildcard_index = std.mem.indexOfScalar(u8, pattern, '_').?;
                    const mnem_prefix = pattern[0..wildcard_index];
                    const mnem_suffix = pattern[wildcard_index + "_".len ..];
                    if (!std.mem.startsWith(u8, mnemonic.name, mnem_prefix)) continue;
                    if (!std.mem.endsWith(u8, mnemonic.name, mnem_suffix)) continue;
                    if (@hasField(
                        Tag,
                        mnemonic.name[mnem_prefix.len .. mnemonic.name.len - mnem_suffix.len],
                    )) break;
                } else @compileError("'" ++ mnemonic.name ++ "' is not encodable in Mir");
            }
            @compileError(std.fmt.comptimePrint(
                \\All mnemonics are encodable in Mir! You may now change the condition at {s}:{d} to:
                \\if (@typeInfo(Mnemonic).@"enum".fields.len != {d} or
                \\    @typeInfo(Fixes).@"enum".fields.len != {d} or
                \\    @typeInfo(Tag).@"enum".fields.len != {d})
            , .{
                cond_src.file,
                cond_src.line - 6,
                @typeInfo(Mnemonic).@"enum".fields.len,
                @typeInfo(Fixes).@"enum".fields.len,
                @typeInfo(Tag).@"enum".fields.len,
            }));
        }
    }
};

pub const AirOffset = struct { air_inst: Air.Inst.Index, off: i32 };

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet,

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    pub const empty: RegisterList = .{ .bitset = .initEmpty() };

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

    pub fn size(self: Self, target: *const std.Target) i32 {
        return @intCast(self.bitset.count() * @as(u4, switch (target.cpu.arch) {
            else => unreachable,
            .x86 => 4,
            .x86_64 => 8,
        }));
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
        base: @typeInfo(bits.Memory.Base).@"union".tag_type.?,
        mod: @typeInfo(bits.Memory.Mod).@"union".tag_type.?,
        size: bits.Memory.Size,
        index: Register,
        scale: bits.Memory.Scale,
        _: u14 = undefined,
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
                .none, .table => undefined,
                .reg => |reg| @intFromEnum(reg),
                .frame => |frame_index| @intFromEnum(frame_index),
                .reloc => |sym_index| sym_index,
                .rip_inst => |inst_index| inst_index,
            },
            .off = switch (mem.mod) {
                .rm => |rm| @bitCast(rm.disp),
                .off => |off| @truncate(off),
            },
            .extra = if (mem.mod == .off)
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
                    return encoder.Instruction.Memory.initRip(mem.info.size, @bitCast(mem.off));
                }
                return encoder.Instruction.Memory.initSib(mem.info.size, .{
                    .disp = @bitCast(mem.off),
                    .base = switch (mem.info.base) {
                        .none => .none,
                        .reg => .{ .reg = @enumFromInt(mem.base) },
                        .frame => .{ .frame = @enumFromInt(mem.base) },
                        .table => .table,
                        .reloc => .{ .reloc = mem.base },
                        .rip_inst => .{ .rip_inst = mem.base },
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
                return encoder.Instruction.Memory.initMoffs(
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
    gpa.free(mir.table);
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
            bits.FrameIndex, Air.Inst.Index => @enumFromInt(mir.extra[i]),
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

pub fn resolveFrameAddr(mir: Mir, frame_addr: bits.FrameAddr) bits.RegisterOffset {
    const frame_loc = mir.frame_locs.get(@intFromEnum(frame_addr.index));
    return .{ .reg = frame_loc.base, .off = frame_loc.disp + frame_addr.off };
}

pub fn resolveFrameLoc(mir: Mir, mem: Memory) Memory {
    return switch (mem.info.base) {
        .none, .reg, .table, .reloc, .rip_inst => mem,
        .frame => if (mir.frame_locs.len > 0) .{
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

const Air = @import("../../Air.zig");
const IntegerBitSet = std.bit_set.IntegerBitSet;
const InternPool = @import("../../InternPool.zig");
const Mir = @This();
const Register = bits.Register;
