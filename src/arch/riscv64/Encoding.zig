mnemonic: Mnemonic,
data: Data,

const OpCode = enum(u7) {
    LOAD = 0b0000011,
    LOAD_FP = 0b0000111,
    MISC_MEM = 0b0001111,
    OP_IMM = 0b0010011,
    AUIPC = 0b0010111,
    OP_IMM_32 = 0b0011011,
    STORE = 0b0100011,
    STORE_FP = 0b0100111,
    AMO = 0b0101111,
    OP_V = 0b1010111,
    OP = 0b0110011,
    OP_32 = 0b0111011,
    LUI = 0b0110111,
    MADD = 0b1000011,
    MSUB = 0b1000111,
    NMSUB = 0b1001011,
    NMADD = 0b1001111,
    OP_FP = 0b1010011,
    OP_IMM_64 = 0b1011011,
    BRANCH = 0b1100011,
    JALR = 0b1100111,
    JAL = 0b1101111,
    SYSTEM = 0b1110011,
    OP_64 = 0b1111011,
    NONE = 0b00000000,
};

const FpFmt = enum(u2) {
    /// 32-bit single-precision
    S = 0b00,
    /// 64-bit double-precision
    D = 0b01,

    // H = 0b10, unused in the G extension

    /// 128-bit quad-precision
    Q = 0b11,
};

const AmoWidth = enum(u3) {
    W = 0b010,
    D = 0b011,
};

const FenceMode = enum(u4) {
    none = 0b0000,
    tso = 0b1000,
};

const Enc = struct {
    opcode: OpCode,

    data: union(enum) {
        /// funct3 + funct7
        ff: struct {
            funct3: u3,
            funct7: u7,
        },
        amo: struct {
            funct5: u5,
            width: AmoWidth,
        },
        fence: struct {
            funct3: u3,
            fm: FenceMode,
        },
        /// funct5 + rm + fmt
        fmt: struct {
            funct5: u5,
            rm: u3,
            fmt: FpFmt,
        },
        /// funct3
        f: struct {
            funct3: u3,
        },
        /// typ + funct3 + has_5
        sh: struct {
            typ: u6,
            funct3: u3,
            has_5: bool,
        },
        vecls: struct {
            width: VecWidth,
            umop: Umop,
            vm: bool,
            mop: Mop,
            mew: bool,
            nf: u3,
        },
        vecmath: struct {
            vm: bool,
            funct6: u6,
            funct3: VecType,
        },
        /// U-type
        none,
    },

    const Mop = enum(u2) {
        unit = 0b00,
        unord = 0b01,
        stride = 0b10,
        ord = 0b11,
    };

    const Umop = enum(u5) {
        unit = 0b00000,
        whole = 0b01000,
        mask = 0b01011,
        fault = 0b10000,
    };

    const VecWidth = enum(u3) {
        // zig fmt: off
        @"8"  = 0b000,
        @"16" = 0b101,
        @"32" = 0b110,
        @"64" = 0b111,
        // zig fmt: on
    };

    const VecType = enum(u3) {
        OPIVV = 0b000,
        OPFVV = 0b001,
        OPMVV = 0b010,
        OPIVI = 0b011,
        OPIVX = 0b100,
        OPFVF = 0b101,
        OPMVX = 0b110,
    };
};

// TODO: this is basically a copy of the MIR table, we should be able to de-dupe them somehow.
pub const Mnemonic = enum {
    // base mnemonics

    // I Type
    ld,
    lw,
    lwu,
    lh,
    lhu,
    lb,
    lbu,

    sltiu,
    xori,
    andi,

    slli,
    srli,
    srai,

    slliw,
    srliw,
    sraiw,

    addi,
    jalr,

    vsetivli,
    vsetvli,

    // U Type
    lui,
    auipc,

    // S Type
    sd,
    sw,
    sh,
    sb,

    // J Type
    jal,

    // B Type
    beq,

    // R Type
    add,
    addw,
    sub,
    subw,
    @"and",
    @"or",
    slt,
    sltu,
    xor,

    sll,
    srl,
    sra,

    sllw,
    srlw,
    sraw,

    // System
    ecall,
    ebreak,
    unimp,

    csrrs,

    // M extension
    mul,
    mulw,

    mulh,
    mulhu,
    mulhsu,

    div,
    divu,

    divw,
    divuw,

    rem,
    remu,

    remw,
    remuw,

    // F extension (32-bit float)
    fadds,
    fsubs,
    fmuls,
    fdivs,

    fmins,
    fmaxs,

    fsqrts,

    flw,
    fsw,

    feqs,
    flts,
    fles,

    fsgnjns,
    fsgnjxs,

    // D extension (64-bit float)
    faddd,
    fsubd,
    fmuld,
    fdivd,

    fmind,
    fmaxd,

    fsqrtd,

    fld,
    fsd,

    feqd,
    fltd,
    fled,

    fsgnjnd,
    fsgnjxd,

    // V Extension
    vle8v,
    vle16v,
    vle32v,
    vle64v,

    vse8v,
    vse16v,
    vse32v,
    vse64v,

    vsoxei8v,

    vaddvv,
    vsubvv,

    vfaddvv,
    vfsubvv,

    vmulvv,
    vfmulvv,

    vadcvv,

    vmvvx,

    vslidedownvx,

    // MISC
    fence,
    fencetso,

    // AMO
    amoswapw,
    amoaddw,
    amoandw,
    amoorw,
    amoxorw,
    amomaxw,
    amominw,
    amomaxuw,
    amominuw,

    amoswapd,
    amoaddd,
    amoandd,
    amoord,
    amoxord,
    amomaxd,
    amomind,
    amomaxud,
    amominud,

    // TODO: Q extension

    // Zbb Extension
    clz,
    clzw,

    pub fn encoding(mnem: Mnemonic) Enc {
        return switch (mnem) {
            // zig fmt: off

            // OP

            .add     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000000 } } },
            .sub     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0100000 } } }, 

            .@"and"  => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000000 } } },
            .@"or"   => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000000 } } },
            .xor     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000000 } } },

            .sltu    => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b011, .funct7 = 0b0000000 } } },
            .slt     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b010, .funct7 = 0b0000000 } } },

            .mul     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000001 } } },
            .mulh    => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000001 } } },
            .mulhsu  => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b010, .funct7 = 0b0000001 } } },
            .mulhu   => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b011, .funct7 = 0b0000001 } } },
 
            .div     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000001 } } },
            .divu    => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000001 } } },

            .rem     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000001 } } },
            .remu    => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000001 } } },

            .sll     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000000 } } },
            .srl     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000000 } } },
            .sra     => .{ .opcode = .OP, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0100000 } } },


            // OP_IMM

            .addi    => .{ .opcode = .OP_IMM, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .andi    => .{ .opcode = .OP_IMM, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .xori    => .{ .opcode = .OP_IMM, .data = .{ .f = .{ .funct3 = 0b100 } } },
            
            .sltiu   => .{ .opcode = .OP_IMM, .data = .{ .f = .{ .funct3 = 0b011 } } },

            .slli    => .{ .opcode = .OP_IMM, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b001, .has_5 = true } } },
            .srli    => .{ .opcode = .OP_IMM, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b101, .has_5 = true } } },
            .srai    => .{ .opcode = .OP_IMM, .data = .{ .sh = .{ .typ = 0b010000, .funct3 = 0b101, .has_5 = true } } },

            .clz     => .{ .opcode = .OP_IMM, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },

            // OP_IMM_32

            .slliw   => .{ .opcode = .OP_IMM_32, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b001, .has_5 = false } } },
            .srliw   => .{ .opcode = .OP_IMM_32, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b101, .has_5 = false } } },
            .sraiw   => .{ .opcode = .OP_IMM_32, .data = .{ .sh = .{ .typ = 0b010000, .funct3 = 0b101, .has_5 = false } } },

            .clzw     => .{ .opcode = .OP_IMM_32, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },

            // OP_32

            .addw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000000 } } },
            .subw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0100000 } } },
            .mulw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000001 } } }, 

            .divw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000001 } } },
            .divuw   => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000001 } } },

            .remw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000001 } } },
            .remuw   => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000001 } } },

            .sllw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000000 } } },
            .srlw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000000 } } },
            .sraw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0100000 } } },


            // OP_FP

            .fadds   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00000, .fmt = .S, .rm = 0b111 } } },
            .faddd   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00000, .fmt = .D, .rm = 0b111 } } },

            .fsubs   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00001, .fmt = .S, .rm = 0b111 } } },
            .fsubd   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00001, .fmt = .D, .rm = 0b111 } } },

            .fmuls   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00010, .fmt = .S, .rm = 0b111 } } },
            .fmuld   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00010, .fmt = .D, .rm = 0b111 } } },

            .fdivs   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00011, .fmt = .S, .rm = 0b111 } } },
            .fdivd   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00011, .fmt = .D, .rm = 0b111 } } },

            .fmins   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .S, .rm = 0b000 } } },
            .fmind   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .D, .rm = 0b000 } } },

            .fmaxs   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .S, .rm = 0b001 } } },
            .fmaxd   => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .D, .rm = 0b001 } } },

            .fsqrts  => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b01011, .fmt = .S, .rm = 0b111 } } },
            .fsqrtd  => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b01011, .fmt = .D, .rm = 0b111 } } },

            .fles    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b000 } } },
            .fled    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b000 } } },

            .flts    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b001 } } },
            .fltd    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b001 } } },

            .feqs    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b010 } } },
            .feqd    => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b010 } } },

            .fsgnjns => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .S, .rm = 0b000 } } },
            .fsgnjnd => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .D, .rm = 0b000 } } },

            .fsgnjxs => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .S, .rm = 0b0010} } },
            .fsgnjxd => .{ .opcode = .OP_FP, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .D, .rm = 0b0010} } },


            // LOAD

            .lb      => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .lh      => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b001 } } },
            .lw      => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .ld      => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b011 } } },
            .lbu     => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b100 } } },
            .lhu     => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b101 } } },
            .lwu     => .{ .opcode = .LOAD, .data = .{ .f = .{ .funct3 = 0b110 } } },


            // STORE
            
            .sb      => .{ .opcode = .STORE, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .sh      => .{ .opcode = .STORE, .data = .{ .f = .{ .funct3 = 0b001 } } },
            .sw      => .{ .opcode = .STORE, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .sd      => .{ .opcode = .STORE, .data = .{ .f = .{ .funct3 = 0b011 } } },


            // LOAD_FP

            .flw     => .{ .opcode = .LOAD_FP, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .fld     => .{ .opcode = .LOAD_FP, .data = .{ .f = .{ .funct3 = 0b011 } } },   
    
            .vle8v   => .{ .opcode = .LOAD_FP, .data = .{ .vecls = .{ .width = .@"8",  .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle16v  => .{ .opcode = .LOAD_FP, .data = .{ .vecls = .{ .width = .@"16", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle32v  => .{ .opcode = .LOAD_FP, .data = .{ .vecls = .{ .width = .@"32", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle64v  => .{ .opcode = .LOAD_FP, .data = .{ .vecls = .{ .width = .@"64", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            

            // STORE_FP

            .fsw        => .{ .opcode = .STORE_FP, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .fsd        => .{ .opcode = .STORE_FP, .data = .{ .f = .{ .funct3 = 0b011 } } },

            .vse8v      => .{ .opcode = .STORE_FP, .data = .{ .vecls = .{ .width = .@"8",  .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse16v     => .{ .opcode = .STORE_FP, .data = .{ .vecls = .{ .width = .@"16", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse32v     => .{ .opcode = .STORE_FP, .data = .{ .vecls = .{ .width = .@"32", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse64v     => .{ .opcode = .STORE_FP, .data = .{ .vecls = .{ .width = .@"64", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },

            .vsoxei8v   => .{ .opcode = .STORE_FP, .data = .{ .vecls = .{ .width = .@"8", .umop = .unit, .vm = true, .mop = .ord,  .mew = false, .nf = 0b000 } } },

            // JALR

            .jalr    => .{ .opcode = .JALR, .data = .{ .f = .{ .funct3 = 0b000 } } },


            // LUI

            .lui     => .{ .opcode = .LUI, .data = .{ .none = {} } },


            // AUIPC

            .auipc   => .{ .opcode = .AUIPC, .data = .{ .none = {} } },


            // JAL

            .jal     => .{ .opcode = .JAL, .data = .{ .none = {} } },


            // BRANCH

            .beq     => .{ .opcode = .BRANCH, .data = .{ .f = .{ .funct3 = 0b000 } } },


            // SYSTEM

            .ecall   => .{ .opcode = .SYSTEM, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .ebreak  => .{ .opcode = .SYSTEM, .data = .{ .f = .{ .funct3 = 0b000 } } },

            .csrrs   => .{ .opcode = .SYSTEM, .data = .{ .f = .{ .funct3 = 0b010 } } },
           

            // NONE
            
            .unimp   => .{ .opcode = .NONE, .data = .{ .f = .{ .funct3 = 0b000 } } },


            // MISC_MEM

            .fence    => .{ .opcode = .MISC_MEM, .data = .{ .fence = .{ .funct3 = 0b000, .fm = .none } } },
            .fencetso => .{ .opcode = .MISC_MEM, .data = .{ .fence = .{ .funct3 = 0b000, .fm = .tso  } } },


            // AMO

            .amoaddw   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00000 } } },
            .amoswapw  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00001 } } },
            // LR.W
            // SC.W
            .amoxorw   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00100 } } },
            .amoandw   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b01100 } } },
            .amoorw    => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b01000 } } },
            .amominw   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b10000 } } },
            .amomaxw   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b10100 } } },
            .amominuw  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b11000 } } },
            .amomaxuw  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .W, .funct5 = 0b11100 } } },

            .amoaddd   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00000 } } },
            .amoswapd  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00001 } } },
            // LR.D
            // SC.D
            .amoxord   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00100 } } },
            .amoandd   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b01100 } } },
            .amoord    => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b01000 } } },
            .amomind   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b10000 } } },
            .amomaxd   => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b10100 } } },
            .amominud  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b11000 } } },
            .amomaxud  => .{ .opcode = .AMO, .data = .{ .amo = .{ .width = .D, .funct5 = 0b11100 } } },

            // OP_V
            .vsetivli       => .{ .opcode = .OP_V, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .vsetvli        => .{ .opcode = .OP_V, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .vaddvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000000, .funct3 = .OPIVV } } },
            .vsubvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000010, .funct3 = .OPIVV } } },
            .vmulvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b100101, .funct3 = .OPIVV } } },
            
            .vfaddvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000000, .funct3 = .OPFVV } } },
            .vfsubvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000010, .funct3 = .OPFVV } } },
            .vfmulvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b100100, .funct3 = .OPFVV } } },
            
            .vadcvv         => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b010000, .funct3 = .OPMVV } } },
            .vmvvx          => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b010111, .funct3 = .OPIVX } } },

            .vslidedownvx   => .{ .opcode = .OP_V, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b001111, .funct3 = .OPIVX } } },
            
            // zig fmt: on
        };
    }
};

pub const InstEnc = enum {
    R,
    R4,
    I,
    S,
    B,
    U,
    J,
    fence,
    amo,
    system,

    pub fn fromMnemonic(mnem: Mnemonic) InstEnc {
        return switch (mnem) {
            .addi,
            .jalr,
            .sltiu,
            .xori,
            .andi,

            .slli,
            .srli,
            .srai,

            .slliw,
            .srliw,
            .sraiw,

            .ld,
            .lw,
            .lwu,
            .lh,
            .lhu,
            .lb,
            .lbu,

            .flw,
            .fld,

            .csrrs,
            .vsetivli,
            .vsetvli,
            => .I,

            .lui,
            .auipc,
            => .U,

            .sd,
            .sw,
            .sh,
            .sb,

            .fsd,
            .fsw,
            => .S,

            .jal,
            => .J,

            .beq,
            => .B,

            .slt,
            .sltu,

            .sll,
            .srl,
            .sra,

            .sllw,
            .srlw,
            .sraw,

            .div,
            .divu,
            .divw,
            .divuw,

            .rem,
            .remu,
            .remw,
            .remuw,

            .xor,
            .@"and",
            .@"or",

            .add,
            .addw,

            .sub,
            .subw,

            .mul,
            .mulw,
            .mulh,
            .mulhu,
            .mulhsu,

            .fadds,
            .faddd,

            .fsubs,
            .fsubd,

            .fmuls,
            .fmuld,

            .fdivs,
            .fdivd,

            .fmins,
            .fmind,

            .fmaxs,
            .fmaxd,

            .fsqrts,
            .fsqrtd,

            .fles,
            .fled,

            .flts,
            .fltd,

            .feqs,
            .feqd,

            .fsgnjns,
            .fsgnjnd,

            .fsgnjxs,
            .fsgnjxd,

            .vle8v,
            .vle16v,
            .vle32v,
            .vle64v,

            .vse8v,
            .vse16v,
            .vse32v,
            .vse64v,

            .vsoxei8v,

            .vaddvv,
            .vsubvv,
            .vmulvv,
            .vfaddvv,
            .vfsubvv,
            .vfmulvv,
            .vadcvv,
            .vmvvx,
            .vslidedownvx,

            .clz,
            .clzw,
            => .R,

            .ecall,
            .ebreak,
            .unimp,
            => .system,

            .fence,
            .fencetso,
            => .fence,

            .amoswapw,
            .amoaddw,
            .amoandw,
            .amoorw,
            .amoxorw,
            .amomaxw,
            .amominw,
            .amomaxuw,
            .amominuw,

            .amoswapd,
            .amoaddd,
            .amoandd,
            .amoord,
            .amoxord,
            .amomaxd,
            .amomind,
            .amomaxud,
            .amominud,
            => .amo,
        };
    }

    pub fn opsList(enc: InstEnc) [5]std.meta.FieldEnum(Operand) {
        return switch (enc) {
            // zig fmt: off
            .R      => .{ .reg,     .reg,     .reg,  .none,    .none,   },
            .R4     => .{ .reg,     .reg,     .reg,  .reg,     .none,   },  
            .I      => .{ .reg,     .reg,     .imm,  .none,    .none,   },
            .S      => .{ .reg,     .reg,     .imm,  .none,    .none,   },
            .B      => .{ .reg,     .reg,     .imm,  .none,    .none,   },
            .U      => .{ .reg,     .imm,     .none, .none,    .none,   },
            .J      => .{ .reg,     .imm,     .none, .none,    .none,   },
            .system => .{ .none,    .none,    .none, .none,    .none,   },
            .fence  => .{ .barrier, .barrier, .none, .none,    .none,   },
            .amo    => .{ .reg,     .reg,     .reg,  .barrier, .barrier },
            // zig fmt: on
        };
    }
};

pub const Data = union(InstEnc) {
    R: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        funct7: u7,
    },
    R4: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        funct2: u2,
        rs3: u5,
    },
    I: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        imm0_11: u12,
    },
    S: packed struct {
        opcode: u7,
        imm0_4: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_11: u7,
    },
    B: packed struct {
        opcode: u7,
        imm11: u1,
        imm1_4: u4,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_10: u6,
        imm12: u1,
    },
    U: packed struct {
        opcode: u7,
        rd: u5,
        imm12_31: u20,
    },
    J: packed struct {
        opcode: u7,
        rd: u5,
        imm12_19: u8,
        imm11: u1,
        imm1_10: u10,
        imm20: u1,
    },
    fence: packed struct {
        opcode: u7,
        rd: u5 = 0,
        funct3: u3,
        rs1: u5 = 0,
        succ: u4,
        pred: u4,
        fm: u4,
    },
    amo: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        rl: bool,
        aq: bool,
        funct5: u5,
    },
    system: u32,

    comptime {
        for (std.meta.fields(Data)) |field| {
            assert(@bitSizeOf(field.type) == 32);
        }
    }

    pub fn toU32(self: Data) u32 {
        return switch (self) {
            .fence => |v| @as(u32, @intCast(v.opcode)) + (@as(u32, @intCast(v.rd)) << 7) + (@as(u32, @intCast(v.funct3)) << 12) + (@as(u32, @intCast(v.rs1)) << 15) + (@as(u32, @intCast(v.succ)) << 20) + (@as(u32, @intCast(v.pred)) << 24) + (@as(u32, @intCast(v.fm)) << 28),
            inline else => |v| @bitCast(v),
            .system => unreachable,
        };
    }

    pub fn construct(mnem: Mnemonic, ops: []const Operand) !Data {
        const inst_enc = InstEnc.fromMnemonic(mnem);
        const enc = mnem.encoding();

        // special mnemonics
        switch (mnem) {
            .ecall,
            .ebreak,
            .unimp,
            => {
                assert(ops.len == 0);
                return .{
                    .I = .{
                        .rd = Register.zero.encodeId(),
                        .rs1 = Register.zero.encodeId(),
                        .imm0_11 = switch (mnem) {
                            .ecall => 0x000,
                            .ebreak => 0x001,
                            .unimp => 0x000,
                            else => unreachable,
                        },

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.f.funct3,
                    },
                };
            },
            .csrrs => {
                assert(ops.len == 3);

                const csr = ops[0].csr;
                const rs1 = ops[1].reg;
                const rd = ops[2].reg;

                return .{
                    .I = .{
                        .rd = rd.encodeId(),
                        .rs1 = rs1.encodeId(),

                        .imm0_11 = @intFromEnum(csr),

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.f.funct3,
                    },
                };
            },
            else => {},
        }

        switch (inst_enc) {
            .R => {
                assert(ops.len == 3);
                return .{
                    .R = switch (enc.data) {
                        .ff => |ff| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = ff.funct3,
                            .funct7 = ff.funct7,
                        },
                        .fmt => |fmt| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = fmt.rm,
                            .funct7 = (@as(u7, fmt.funct5) << 2) | @intFromEnum(fmt.fmt),
                        },
                        .vecls => |vec| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),

                            .rs2 = @intFromEnum(vec.umop),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = @intFromEnum(vec.width),
                            .funct7 = (@as(u7, vec.nf) << 4) | (@as(u7, @intFromBool(vec.mew)) << 3) | (@as(u7, @intFromEnum(vec.mop)) << 1) | @intFromBool(vec.vm),
                        },
                        .vecmath => |vec| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = @intFromEnum(vec.funct3),
                            .funct7 = (@as(u7, vec.funct6) << 1) | @intFromBool(vec.vm),
                        },
                        else => unreachable,
                    },
                };
            },
            .S => {
                assert(ops.len == 3);
                const umm = ops[2].imm.asBits(u12);

                return .{
                    .S = .{
                        .imm0_4 = @truncate(umm),
                        .rs1 = ops[0].reg.encodeId(),
                        .rs2 = ops[1].reg.encodeId(),
                        .imm5_11 = @truncate(umm >> 5),

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.f.funct3,
                    },
                };
            },
            .I => {
                assert(ops.len == 3);
                return .{
                    .I = switch (enc.data) {
                        .f => |f| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .imm0_11 = ops[2].imm.asBits(u12),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = f.funct3,
                        },
                        .sh => |sh| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .imm0_11 = (@as(u12, sh.typ) << 6) |
                                if (sh.has_5) ops[2].imm.asBits(u6) else (@as(u6, 0) | ops[2].imm.asBits(u5)),

                            .opcode = @intFromEnum(enc.opcode),
                            .funct3 = sh.funct3,
                        },
                        else => unreachable,
                    },
                };
            },
            .U => {
                assert(ops.len == 2);
                return .{
                    .U = .{
                        .rd = ops[0].reg.encodeId(),
                        .imm12_31 = ops[1].imm.asBits(u20),

                        .opcode = @intFromEnum(enc.opcode),
                    },
                };
            },
            .J => {
                assert(ops.len == 2);

                const umm = ops[1].imm.asBits(u21);
                assert(umm % 4 == 0); // misaligned jump target

                return .{
                    .J = .{
                        .rd = ops[0].reg.encodeId(),
                        .imm1_10 = @truncate(umm >> 1),
                        .imm11 = @truncate(umm >> 11),
                        .imm12_19 = @truncate(umm >> 12),
                        .imm20 = @truncate(umm >> 20),

                        .opcode = @intFromEnum(enc.opcode),
                    },
                };
            },
            .B => {
                assert(ops.len == 3);

                const umm = ops[2].imm.asBits(u13);
                assert(umm % 4 == 0); // misaligned branch target

                return .{
                    .B = .{
                        .rs1 = ops[0].reg.encodeId(),
                        .rs2 = ops[1].reg.encodeId(),
                        .imm1_4 = @truncate(umm >> 1),
                        .imm5_10 = @truncate(umm >> 5),
                        .imm11 = @truncate(umm >> 11),
                        .imm12 = @truncate(umm >> 12),

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.f.funct3,
                    },
                };
            },
            .fence => {
                assert(ops.len == 2);

                const succ = ops[0].barrier;
                const pred = ops[1].barrier;

                return .{
                    .fence = .{
                        .succ = @intFromEnum(succ),
                        .pred = @intFromEnum(pred),

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.fence.funct3,
                        .fm = @intFromEnum(enc.data.fence.fm),
                    },
                };
            },
            .amo => {
                assert(ops.len == 5);

                const rd = ops[0].reg;
                const rs1 = ops[1].reg;
                const rs2 = ops[2].reg;
                const rl = ops[3].barrier;
                const aq = ops[4].barrier;

                return .{
                    .amo = .{
                        .rd = rd.encodeId(),
                        .rs1 = rs1.encodeId(),
                        .rs2 = rs2.encodeId(),

                        // TODO: https://github.com/ziglang/zig/issues/20113
                        .rl = if (rl == .rl) true else false,
                        .aq = if (aq == .aq) true else false,

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = @intFromEnum(enc.data.amo.width),
                        .funct5 = enc.data.amo.funct5,
                    },
                };
            },
            else => std.debug.panic("TODO: construct {s}", .{@tagName(inst_enc)}),
        }
    }
};

pub fn findByMnemonic(mnem: Mnemonic, ops: []const Operand) !?Encoding {
    if (!verifyOps(mnem, ops)) return null;

    return .{
        .mnemonic = mnem,
        .data = try Data.construct(mnem, ops),
    };
}

fn verifyOps(mnem: Mnemonic, ops: []const Operand) bool {
    const inst_enc = InstEnc.fromMnemonic(mnem);
    const list = std.mem.sliceTo(&inst_enc.opsList(), .none);
    for (list, ops) |l, o| if (l != std.meta.activeTag(o)) return false;
    return true;
}

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.encoding);

const Encoding = @This();
const bits = @import("bits.zig");
const Register = bits.Register;
const encoder = @import("encoder.zig");
const Instruction = encoder.Instruction;
const Operand = Instruction.Operand;
const OperandEnum = std.meta.FieldEnum(Operand);
