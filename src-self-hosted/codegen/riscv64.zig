const std = @import("std");
const DW = std.dwarf;

pub const instructions = struct {
    pub const CallBreak = packed struct {
        pub const Mode = packed enum(u12) { ecall, ebreak };
        opcode: u7 = 0b1110011,
        unused1: u5 = 0,
        unused2: u3 = 0,
        unused3: u5 = 0,
        mode: u12, //: Mode
    };
    // I-type
    pub const Addi = packed struct {
        pub const Mode = packed enum(u3) { addi = 0b000, slti = 0b010, sltiu = 0b011, xori = 0b100, ori = 0b110, andi = 0b111 };
        opcode: u7 = 0b0010011,
        rd: u5,
        mode: u3, //: Mode
        rs1: u5,
        imm: i12,
    };
    pub const Lui = packed struct {
        opcode: u7 = 0b0110111,
        rd: u5,
        imm: i20,
    };
    // I_type
    pub const Load = packed struct {
        pub const Mode = packed enum(u3) { ld = 0b011, lwu = 0b110 };
        opcode: u7 = 0b0000011,
        rd: u5,
        mode: u3, //: Mode
        rs1: u5,
        offset: i12,
    };
    // I-type
    pub const Jalr = packed struct {
        opcode: u7 = 0b1100111,
        rd: u5,
        mode: u3 = 0,
        rs1: u5,
        offset: i12,
    };
};

// zig fmt: off
pub const RawRegister = enum(u8) {
    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
    x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,

    pub fn dwarfLocOp(reg: RawRegister) u8 {
        return @enumToInt(reg) + DW.OP_reg0;
    }
};

pub const Register = enum(u8) {
    // 64 bit registers
    zero, // zero
    ra, // return address. caller saved
    sp, // stack pointer. callee saved.
    gp, // global pointer
    tp, // thread pointer
    t0, t1, t2, // temporaries. caller saved.
    s0, // s0/fp, callee saved.
    s1, // callee saved.
    a0, a1, // fn args/return values. caller saved.
    a2, a3, a4, a5, a6, a7, // fn args. caller saved.
    s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, // saved registers. callee saved.
    t3, t4, t5, t6, // caller saved
    
    pub fn parseRegName(name: []const u8) ?Register {
        if(std.meta.stringToEnum(Register, name)) |reg| return reg;
        if(std.meta.stringToEnum(RawRegister, name)) |rawreg| return @intToEnum(Register, @enumToInt(rawreg));
        return null;
    }

    /// Returns the register's id.
    pub fn id(self: @This()) u5 {
        return @truncate(u5, @enumToInt(self));
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for(callee_preserved_regs) |cpreg, i| {
            if(self == cpreg) return i;
        }
        return null;
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return @enumToInt(reg) + DW.OP_reg0;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};
