//! This file is responsible for going from MIR, which is emitted by CodeGen
//! and converting it into Instructions, which can be used as needed.
//!
//! Here we encode how mnemonics relate to opcodes and where their operands go.

/// Lower Instruction Representation
///
/// This format encodes a specific instruction, however it's still abstracted
/// away from the true encoding it'll be in. It's meant to make the process of
/// indicating unique encoding data easier.
pub const Lir = struct {
    opcode: OpCode,
    format: Format,
    data: Data,

    pub const Format = enum {
        R,
        I,
        S,
        B,
        U,
        J,
        extra,
    };

    const Data = union(enum) {
        none,
        f: struct { funct3: u3 },
        ff: struct {
            funct3: u3,
            funct7: u7,
        },
        sh: struct {
            typ: u6,
            funct3: u3,
            has_5: bool,
        },

        fmt: struct {
            funct5: u5,
            rm: u3,
            fmt: FpFmt,
        },
        fcvt: struct {
            funct5: u5,
            rm: u3,
            fmt: FpFmt,
            width: Mir.FcvtOp,
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

        amo: struct {
            funct5: u5,
            width: AmoWidth,
        },
        fence: struct {
            funct3: u3,
            fm: FenceMode,
        },

        /// the mnemonic has some special properities that can't be handled in a generic fashion
        extra: Mnemonic,
    };

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

    const Mop = enum(u2) {
        // zig fmt: off
        unit   = 0b00,
        unord  = 0b01,
        stride = 0b10,
        ord    = 0b11,
        // zig fmt: on
    };

    const Umop = enum(u5) {
        // zig fmt: off
        unit  = 0b00000,
        whole = 0b01000,
        mask  = 0b01011,
        fault = 0b10000,
        // zig fmt: on
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

    pub fn fromMnem(mnem: Mnemonic) Lir {
        return switch (mnem) {
            // zig fmt: off

            // OP
            .add     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000000 } } },
            .sub     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0100000 } } }, 

            .@"and"  => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000000 } } },
            .@"or"   => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000000 } } },
            .xor     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000000 } } },

            .sltu    => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b011, .funct7 = 0b0000000 } } },
            .slt     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b010, .funct7 = 0b0000000 } } },

            .mul     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000001 } } },
            .mulh    => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000001 } } },
            .mulhsu  => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b010, .funct7 = 0b0000001 } } },
            .mulhu   => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b011, .funct7 = 0b0000001 } } },
 
            .div     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000001 } } },
            .divu    => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000001 } } },

            .rem     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000001 } } },
            .remu    => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000001 } } },

            .sll     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000000 } } },
            .srl     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000000 } } },
            .sra     => .{ .opcode = .OP, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0100000 } } },


            // OP_IMM

            .addi    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .andi    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .xori    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .f = .{ .funct3 = 0b100 } } },
            
            .sltiu   => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .f = .{ .funct3 = 0b011 } } },

            .slli    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b001, .has_5 = true } } },
            .srli    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b101, .has_5 = true } } },
            .srai    => .{ .opcode = .OP_IMM, .format = .I, .data = .{ .sh = .{ .typ = 0b010000, .funct3 = 0b101, .has_5 = true } } },

            .clz     => .{ .opcode = .OP_IMM, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },
            .cpop    => .{ .opcode = .OP_IMM, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },

            // OP_IMM_32

            .slliw   => .{ .opcode = .OP_IMM_32, .format = .I, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b001, .has_5 = false } } },
            .srliw   => .{ .opcode = .OP_IMM_32, .format = .I, .data = .{ .sh = .{ .typ = 0b000000, .funct3 = 0b101, .has_5 = false } } },
            .sraiw   => .{ .opcode = .OP_IMM_32, .format = .I, .data = .{ .sh = .{ .typ = 0b010000, .funct3 = 0b101, .has_5 = false } } },

            .clzw    => .{ .opcode = .OP_IMM_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },
            .cpopw   => .{ .opcode = .OP_IMM_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0110000 } } },

            // OP_32

            .addw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000000 } } },
            .subw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0100000 } } },
            .mulw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b000, .funct7 = 0b0000001 } } }, 

            .divw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b100, .funct7 = 0b0000001 } } },
            .divuw   => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000001 } } },

            .remw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b110, .funct7 = 0b0000001 } } },
            .remuw   => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b111, .funct7 = 0b0000001 } } },

            .sllw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000000 } } },
            .srlw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0000000 } } },
            .sraw    => .{ .opcode = .OP_32, .format = .R, .data = .{ .ff = .{ .funct3 = 0b101, .funct7 = 0b0100000 } } },


            // OP_FP

            .fadds   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00000, .fmt = .S, .rm = 0b111 } } },
            .faddd   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00000, .fmt = .D, .rm = 0b111 } } },

            .fsubs   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00001, .fmt = .S, .rm = 0b111 } } },
            .fsubd   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00001, .fmt = .D, .rm = 0b111 } } },

            .fmuls   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00010, .fmt = .S, .rm = 0b111 } } },
            .fmuld   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00010, .fmt = .D, .rm = 0b111 } } },

            .fdivs   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00011, .fmt = .S, .rm = 0b111 } } },
            .fdivd   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00011, .fmt = .D, .rm = 0b111 } } },

            .fmins   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .S, .rm = 0b000 } } },
            .fmind   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .D, .rm = 0b000 } } },

            .fmaxs   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .S, .rm = 0b001 } } },
            .fmaxd   => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00101, .fmt = .D, .rm = 0b001 } } },

            .fsqrts  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b01011, .fmt = .S, .rm = 0b111 } } },
            .fsqrtd  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b01011, .fmt = .D, .rm = 0b111 } } },

            .fles    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b000 } } },
            .fled    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b000 } } },

            .flts    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b001 } } },
            .fltd    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b001 } } },

            .feqs    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .S, .rm = 0b010 } } },
            .feqd    => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b10100, .fmt = .D, .rm = 0b010 } } },

            .fsgnjns => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .S, .rm = 0b000 } } },
            .fsgnjnd => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .D, .rm = 0b000 } } },

            .fsgnjxs => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .S, .rm = 0b010 } } },
            .fsgnjxd => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fmt = .{ .funct5 = 0b00100, .fmt = .D, .rm = 0b010 } } },

            .fcvtws  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .S, .rm = 0b111, .width = .w  } } },
            .fcvtwus => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .S, .rm = 0b111, .width = .wu } } },
            .fcvtls  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .S, .rm = 0b111, .width = .l  } } },
            .fcvtlus => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .S, .rm = 0b111, .width = .lu } } },

            .fcvtwd  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .D, .rm = 0b111, .width = .w  } } },
            .fcvtwud => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .D, .rm = 0b111, .width = .wu } } },
            .fcvtld  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .D, .rm = 0b111, .width = .l  } } },
            .fcvtlud => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11000, .fmt = .D, .rm = 0b111, .width = .lu } } },

            .fcvtsw  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .S, .rm = 0b111, .width = .w  } } },
            .fcvtswu => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .S, .rm = 0b111, .width = .wu } } },
            .fcvtsl  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .S, .rm = 0b111, .width = .l  } } },
            .fcvtslu => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .S, .rm = 0b111, .width = .lu } } },

            .fcvtdw  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .D, .rm = 0b111, .width = .w  } } },
            .fcvtdwu => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .D, .rm = 0b111, .width = .wu } } },
            .fcvtdl  => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .D, .rm = 0b111, .width = .l  } } },
            .fcvtdlu => .{ .opcode = .OP_FP, .format = .R, .data = .{ .fcvt = .{ .funct5 = 0b11010, .fmt = .D, .rm = 0b111, .width = .lu } } },

            // LOAD

            .lb      => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .lh      => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b001 } } },
            .lw      => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .ld      => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b011 } } },
            .lbu     => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b100 } } },
            .lhu     => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b101 } } },
            .lwu     => .{ .opcode = .LOAD, .format = .I, .data = .{ .f = .{ .funct3 = 0b110 } } },


            // STORE
            
            .sb      => .{ .opcode = .STORE, .format = .S, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .sh      => .{ .opcode = .STORE, .format = .S, .data = .{ .f = .{ .funct3 = 0b001 } } },
            .sw      => .{ .opcode = .STORE, .format = .S, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .sd      => .{ .opcode = .STORE, .format = .S, .data = .{ .f = .{ .funct3 = 0b011 } } },


            // LOAD_FP

            .flw     => .{ .opcode = .LOAD_FP, .format = .I, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .fld     => .{ .opcode = .LOAD_FP, .format = .I, .data = .{ .f = .{ .funct3 = 0b011 } } },   
    
            .vle8v   => .{ .opcode = .LOAD_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"8",  .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle16v  => .{ .opcode = .LOAD_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"16", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle32v  => .{ .opcode = .LOAD_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"32", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vle64v  => .{ .opcode = .LOAD_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"64", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            

            // STORE_FP

            .fsw        => .{ .opcode = .STORE_FP, .format = .S, .data = .{ .f = .{ .funct3 = 0b010 } } },
            .fsd        => .{ .opcode = .STORE_FP, .format = .S, .data = .{ .f = .{ .funct3 = 0b011 } } },

            .vse8v      => .{ .opcode = .STORE_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"8",  .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse16v     => .{ .opcode = .STORE_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"16", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse32v     => .{ .opcode = .STORE_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"32", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },
            .vse64v     => .{ .opcode = .STORE_FP, .format = .R, .data = .{ .vecls = .{ .width = .@"64", .umop = .unit, .vm = true, .mop = .unit, .mew = false, .nf = 0b000 } } },

            // JALR

            .jalr    => .{ .opcode = .JALR, .format = .I, .data = .{ .f = .{ .funct3 = 0b000 } } },


            // LUI

            .lui     => .{ .opcode = .LUI, .format = .U, .data = .{ .none = {} } },


            // AUIPC

            .auipc   => .{ .opcode = .AUIPC, .format = .U, .data = .{ .none = {} } },


            // JAL

            .jal     => .{ .opcode = .JAL, .format = .J, .data = .{ .none = {} } },


            // BRANCH

            .beq     => .{ .opcode = .BRANCH, .format = .B, .data = .{ .f = .{ .funct3 = 0b000 } } },
            .bne     => .{ .opcode = .BRANCH, .format = .B, .data = .{ .f = .{ .funct3 = 0b001 } } },


            // SYSTEM

            .ecall   => .{ .opcode = .SYSTEM, .format = .extra, .data = .{ .extra = .ecall  } },
            .ebreak  => .{ .opcode = .SYSTEM, .format = .extra, .data = .{ .extra = .ebreak } },

            .csrrs   => .{ .opcode = .SYSTEM, .format = .I, .data = .{ .f = .{ .funct3 = 0b010 } } },
           

            // NONE

            .unimp  => .{ .opcode = .NONE, .format = .extra, .data = .{ .extra = .unimp } },


            // MISC_MEM

            .fence    => .{ .opcode = .MISC_MEM, .format = .I, .data = .{ .fence = .{ .funct3 = 0b000, .fm = .none } } },
            .fencetso => .{ .opcode = .MISC_MEM, .format = .I, .data = .{ .fence = .{ .funct3 = 0b000, .fm = .tso  } } },


            // AMO

            .amoaddw   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00000 } } },
            .amoswapw  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00001 } } },
            .lrw       => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00010 } } }, 
            .scw       => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00011 } } }, 
            .amoxorw   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b00100 } } },
            .amoandw   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b01100 } } },
            .amoorw    => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b01000 } } },
            .amominw   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b10000 } } },
            .amomaxw   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b10100 } } },
            .amominuw  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b11000 } } },
            .amomaxuw  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .W, .funct5 = 0b11100 } } },

        
            .amoaddd   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00000 } } },
            .amoswapd  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00001 } } },
            .lrd       => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00010 } } }, 
            .scd       => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00011 } } }, 
            .amoxord   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b00100 } } },
            .amoandd   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b01100 } } },
            .amoord    => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b01000 } } },
            .amomind   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b10000 } } },
            .amomaxd   => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b10100 } } },
            .amominud  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b11000 } } },
            .amomaxud  => .{ .opcode = .AMO, .format = .R, .data = .{ .amo = .{ .width = .D, .funct5 = 0b11100 } } },

            // OP_V
            .vsetivli       => .{ .opcode = .OP_V, .format = .I, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .vsetvli        => .{ .opcode = .OP_V, .format = .I, .data = .{ .f = .{ .funct3 = 0b111 } } },
            .vaddvv         => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000000, .funct3 = .OPIVV } } },
            .vsubvv         => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000010, .funct3 = .OPIVV } } },
            .vmulvv         => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b100101, .funct3 = .OPIVV } } },
            
            .vfaddvv        => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000000, .funct3 = .OPFVV } } },
            .vfsubvv        => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b000010, .funct3 = .OPFVV } } },
            .vfmulvv        => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b100100, .funct3 = .OPFVV } } },
            
            .vadcvv         => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b010000, .funct3 = .OPMVV } } },
            .vmvvx          => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b010111, .funct3 = .OPIVX } } },

            .vslidedownvx   => .{ .opcode = .OP_V, .format = .R, .data = .{ .vecmath = .{ .vm = true, .funct6 = 0b001111, .funct3 = .OPIVX } } },
            

            .pseudo_prologue,
            .pseudo_epilogue,
            .pseudo_dbg_prologue_end,
            .pseudo_dbg_epilogue_begin,
            .pseudo_dbg_line_column,
            .pseudo_load_rm,
            .pseudo_store_rm,
            .pseudo_lea_rm,
            .pseudo_j,
            .pseudo_dead,
            .pseudo_load_symbol,
            .pseudo_load_tlv,
            .pseudo_mv,
            .pseudo_restore_regs,
            .pseudo_spill_regs,
            .pseudo_compare,
            .pseudo_not,
            .pseudo_extern_fn_reloc,
            .nop,
            => std.debug.panic("lir: didn't catch pseudo {s}", .{@tagName(mnem)}),
            // zig fmt: on
        };
    }
};

/// This is the final form of the instruction. Lir is transformed into
/// this, which is then bitcast into a u32.
pub const Instruction = union(Lir.Format) {
    R: packed struct(u32) {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        funct7: u7,
    },
    I: packed struct(u32) {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        imm0_11: u12,
    },
    S: packed struct(u32) {
        opcode: u7,
        imm0_4: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_11: u7,
    },
    B: packed struct(u32) {
        opcode: u7,
        imm11: u1,
        imm1_4: u4,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        imm5_10: u6,
        imm12: u1,
    },
    U: packed struct(u32) {
        opcode: u7,
        rd: u5,
        imm12_31: u20,
    },
    J: packed struct(u32) {
        opcode: u7,
        rd: u5,
        imm12_19: u8,
        imm11: u1,
        imm1_10: u10,
        imm20: u1,
    },
    extra: u32,

    comptime {
        for (std.meta.fields(Instruction)) |field| {
            assert(@bitSizeOf(field.type) == 32);
        }
    }

    pub const Operand = union(enum) {
        none,
        reg: Register,
        csr: CSR,
        mem: Memory,
        imm: Immediate,
        barrier: Mir.Barrier,
    };

    pub fn toU32(inst: Instruction) u32 {
        return switch (inst) {
            inline else => |v| @bitCast(v),
        };
    }

    pub fn encode(inst: Instruction, writer: anytype) !void {
        try writer.writeInt(u32, inst.toU32(), .little);
    }

    pub fn fromLir(lir: Lir, ops: []const Operand) Instruction {
        const opcode: u7 = @intFromEnum(lir.opcode);

        switch (lir.format) {
            .R => {
                return .{
                    .R = switch (lir.data) {
                        .ff => |ff| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = opcode,
                            .funct3 = ff.funct3,
                            .funct7 = ff.funct7,
                        },
                        .fmt => |fmt| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = opcode,
                            .funct3 = fmt.rm,
                            .funct7 = (@as(u7, fmt.funct5) << 2) | @intFromEnum(fmt.fmt),
                        },
                        .fcvt => |fcvt| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = @intFromEnum(fcvt.width),

                            .opcode = opcode,
                            .funct3 = fcvt.rm,
                            .funct7 = (@as(u7, fcvt.funct5) << 2) | @intFromEnum(fcvt.fmt),
                        },
                        .vecls => |vec| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),

                            .rs2 = @intFromEnum(vec.umop),

                            .opcode = opcode,
                            .funct3 = @intFromEnum(vec.width),
                            .funct7 = (@as(u7, vec.nf) << 4) | (@as(u7, @intFromBool(vec.mew)) << 3) | (@as(u7, @intFromEnum(vec.mop)) << 1) | @intFromBool(vec.vm),
                        },
                        .vecmath => |vec| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = opcode,
                            .funct3 = @intFromEnum(vec.funct3),
                            .funct7 = (@as(u7, vec.funct6) << 1) | @intFromBool(vec.vm),
                        },
                        .amo => |amo| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .rs2 = ops[2].reg.encodeId(),

                            .opcode = opcode,
                            .funct3 = @intFromEnum(amo.width),
                            .funct7 = @as(u7, amo.funct5) << 2 |
                                @as(u7, @intFromBool(ops[3].barrier == .rl)) << 1 |
                                @as(u7, @intFromBool(ops[4].barrier == .aq)),
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

                        .opcode = opcode,
                        .funct3 = lir.data.f.funct3,
                    },
                };
            },
            .I => {
                return .{
                    .I = switch (lir.data) {
                        .f => |f| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .imm0_11 = ops[2].imm.asBits(u12),

                            .opcode = opcode,
                            .funct3 = f.funct3,
                        },
                        .sh => |sh| .{
                            .rd = ops[0].reg.encodeId(),
                            .rs1 = ops[1].reg.encodeId(),
                            .imm0_11 = (@as(u12, sh.typ) << 6) |
                                if (sh.has_5) ops[2].imm.asBits(u6) else (@as(u6, 0) | ops[2].imm.asBits(u5)),

                            .opcode = opcode,
                            .funct3 = sh.funct3,
                        },
                        .fence => |fence| .{
                            .rd = 0,
                            .rs1 = 0,
                            .funct3 = 0,
                            .imm0_11 = (@as(u12, @intFromEnum(fence.fm)) << 8) |
                                (@as(u12, @intFromEnum(ops[1].barrier)) << 4) |
                                @as(u12, @intFromEnum(ops[0].barrier)),
                            .opcode = opcode,
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

                        .opcode = opcode,
                    },
                };
            },
            .J => {
                assert(ops.len == 2);

                const umm = ops[1].imm.asBits(u21);
                // the RISC-V spec says the target index of a jump
                // must be a multiple of 2
                assert(umm % 2 == 0);

                return .{
                    .J = .{
                        .rd = ops[0].reg.encodeId(),
                        .imm1_10 = @truncate(umm >> 1),
                        .imm11 = @truncate(umm >> 11),
                        .imm12_19 = @truncate(umm >> 12),
                        .imm20 = @truncate(umm >> 20),

                        .opcode = opcode,
                    },
                };
            },
            .B => {
                assert(ops.len == 3);

                const umm = ops[2].imm.asBits(u13);
                // the RISC-V spec says the target index of a branch
                // must be a multiple of 2
                assert(umm % 2 == 0);

                return .{
                    .B = .{
                        .rs1 = ops[0].reg.encodeId(),
                        .rs2 = ops[1].reg.encodeId(),
                        .imm1_4 = @truncate(umm >> 1),
                        .imm5_10 = @truncate(umm >> 5),
                        .imm11 = @truncate(umm >> 11),
                        .imm12 = @truncate(umm >> 12),

                        .opcode = opcode,
                        .funct3 = lir.data.f.funct3,
                    },
                };
            },
            .extra => {
                assert(ops.len == 0);

                return .{
                    .I = .{
                        .rd = Register.zero.encodeId(),
                        .rs1 = Register.zero.encodeId(),
                        .imm0_11 = switch (lir.data.extra) {
                            .ecall => 0x000,
                            .ebreak => 0x001,
                            .unimp => 0x000,
                            else => unreachable,
                        },

                        .opcode = opcode,
                        .funct3 = 0b000,
                    },
                };
            },
        }
    }
};

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.format);

const bits = @import("bits.zig");
const Mir = @import("Mir.zig");
const Mnemonic = @import("mnem.zig").Mnemonic;
const Lower = @import("Lower.zig");

const Register = bits.Register;
const CSR = bits.CSR;
const Memory = bits.Memory;
const Immediate = bits.Immediate;
