const std = @import("std");
const DW = std.dwarf;

pub const Instruction = union(enum) {
    R: packed struct {
        opcode: u7,
        rd: u5,
        funct3: u3,
        rs1: u5,
        rs2: u5,
        funct7: u7,
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

    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .R => |v| @bitCast(u32, v),
            .I => |v| @bitCast(u32, v),
            .S => |v| @bitCast(u32, v),
            .B => |v|
            // TODO: once packed structs work we can remove this monstrosity.
            @intCast(u32, v.opcode) + (@intCast(u32, v.imm11) << 7) + (@intCast(u32, v.imm1_4) << 8) + (@intCast(u32, v.funct3) << 12) + (@intCast(u32, v.rs1) << 15) + (@intCast(u32, v.rs2) << 20) + (@intCast(u32, v.imm5_10) << 25) + (@intCast(u32, v.imm12) << 31),
            .U => |v| @bitCast(u32, v),
            .J => |v| @bitCast(u32, v),
        };
    }

    fn rType(op: u7, fn3: u3, fn7: u7, rd: Register, r1: Register, r2: Register) Instruction {
        return Instruction{
            .R = .{
                .opcode = op,
                .funct3 = fn3,
                .funct7 = fn7,
                .rd = @enumToInt(rd),
                .rs1 = @enumToInt(r1),
                .rs2 = @enumToInt(r2),
            },
        };
    }

    // RISC-V is all signed all the time -- convert immediates to unsigned for processing
    fn iType(op: u7, fn3: u3, rd: Register, r1: Register, imm: i12) Instruction {
        const umm = @bitCast(u12, imm);

        return Instruction{
            .I = .{
                .opcode = op,
                .funct3 = fn3,
                .rd = @enumToInt(rd),
                .rs1 = @enumToInt(r1),
                .imm0_11 = umm,
            },
        };
    }

    fn sType(op: u7, fn3: u3, r1: Register, r2: Register, imm: i12) Instruction {
        const umm = @bitCast(u12, imm);

        return Instruction{
            .S = .{
                .opcode = op,
                .funct3 = fn3,
                .rs1 = @enumToInt(r1),
                .rs2 = @enumToInt(r2),
                .imm0_4 = @truncate(u5, umm),
                .imm5_11 = @truncate(u6, umm >> 5),
            },
        };
    }

    // Use significance value rather than bit value, same for J-type
    // -- less burden on callsite, bonus semantic checking
    fn bType(op: u7, fn3: u3, r1: Register, r2: Register, imm: i13) Instruction {
        const umm = @bitCast(u13, imm);
        if (umm % 2 != 0) @panic("Internal error: misaligned branch target");

        return Instruction{
            .B = .{
                .opcode = op,
                .funct3 = fn3,
                .rs1 = @enumToInt(r1),
                .rs2 = @enumToInt(r2),
                .imm1_4 = @truncate(u4, umm >> 1),
                .imm5_10 = @truncate(u6, umm >> 5),
                .imm11 = @truncate(u1, umm >> 11),
                .imm12 = @truncate(u1, umm >> 12),
            },
        };
    }

    // We have to extract the 20 bits anyway -- let's not make it more painful
    fn uType(op: u7, rd: Register, imm: i20) Instruction {
        const umm = @bitCast(u20, imm);

        return Instruction{
            .U = .{
                .opcode = op,
                .rd = @enumToInt(rd),
                .imm12_31 = umm,
            },
        };
    }

    fn jType(op: u7, rd: Register, imm: i21) Instruction {
        const umm = @bitcast(u21, imm);
        if (umm % 2 != 0) @panic("Internal error: misaligned jump target");

        return Instruction{
            .J = .{
                .opcode = op,
                .rd = @enumToInt(rd),
                .imm1_10 = @truncate(u10, umm >> 1),
                .imm11 = @truncate(u1, umm >> 1),
                .imm12_19 = @truncate(u8, umm >> 12),
                .imm20 = @truncate(u1, umm >> 20),
            },
        };
    }

    // The meat and potatoes. Arguments are in the order in which they appear in assembly code.

    // Arithmetic/Logical, Register-Register

    // Arithmetic/Logical, Register-Immediate
    pub fn addi(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b000, rd, r1, imm);
    }

    // Upper Immediate
    pub fn lui(rd: Register, imm: i20) Instruction {
        return uType(0b0110111, rd, imm);
    }

    pub fn auipc(rd: Register, imm: i20) Instruction {
        return uType(0b0010111, rd, imm);
    }

    // Load
    pub fn ld(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b011, rd, base, offset);
    }

    // Store

    // Branch

    // Jump
    pub fn jal(link: Register, offset: i21) Instruction {
        return jType(0b1101111, link, offset);
    }

    pub fn jalr(link: Register, offset: i12, base: Register) Instruction {
        return iType(0b1100111, 0b000, link, base, offset);
    }

    // System
    pub fn ecall() Instruction {
        return iType(0b1110011, 0b000, .zero, .zero, 0x000);
    }

    pub fn ebreak() Instruction {
        return iType(0b1110011, 0b000, .zero, .zero, 0x001);
    }
};

// zig fmt: off
pub const RawRegister = enum(u5) {
    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
    x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,

    pub fn dwarfLocOp(reg: RawRegister) u8 {
        return @enumToInt(reg) + DW.OP_reg0;
    }
};

pub const Register = enum(u5) {
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
        return @enumToInt(self);
    }

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for(callee_preserved_regs) |cpreg, i| {
            if(self == cpreg) return i;
        }
        return null;
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return @intCast(u8, @enumToInt(reg)) + DW.OP_reg0;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};
