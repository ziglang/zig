const std = @import("std");
const DW = std.dwarf;
const assert = std.debug.assert;
const testing = std.testing;

// TODO: this is only tagged to facilitate the monstrosity.
// Once packed structs work make it packed.
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

    // TODO: once packed structs work we can remove this monstrosity.
    pub fn toU32(self: Instruction) u32 {
        return switch (self) {
            .R => |v| @bitCast(u32, v),
            .I => |v| @bitCast(u32, v),
            .S => |v| @bitCast(u32, v),
            .B => |v| @intCast(u32, v.opcode) + (@intCast(u32, v.imm11) << 7) + (@intCast(u32, v.imm1_4) << 8) + (@intCast(u32, v.funct3) << 12) + (@intCast(u32, v.rs1) << 15) + (@intCast(u32, v.rs2) << 20) + (@intCast(u32, v.imm5_10) << 25) + (@intCast(u32, v.imm12) << 31),
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
                .imm5_11 = @truncate(u7, umm >> 5),
            },
        };
    }

    // Use significance value rather than bit value, same for J-type
    // -- less burden on callsite, bonus semantic checking
    fn bType(op: u7, fn3: u3, r1: Register, r2: Register, imm: i13) Instruction {
        const umm = @bitCast(u13, imm);
        assert(umm % 2 == 0); // misaligned branch target

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
        const umm = @bitCast(u21, imm);
        assert(umm % 2 == 0); // misaligned jump target

        return Instruction{
            .J = .{
                .opcode = op,
                .rd = @enumToInt(rd),
                .imm1_10 = @truncate(u10, umm >> 1),
                .imm11 = @truncate(u1, umm >> 11),
                .imm12_19 = @truncate(u8, umm >> 12),
                .imm20 = @truncate(u1, umm >> 20),
            },
        };
    }

    // The meat and potatoes. Arguments are in the order in which they would appear in assembly code.

    // Arithmetic/Logical, Register-Register

    pub fn add(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b000, 0b0000000, rd, r1, r2);
    }

    pub fn sub(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b000, 0b0100000, rd, r1, r2);
    }

    pub fn @"and"(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b111, 0b0000000, rd, r1, r2);
    }

    pub fn @"or"(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b110, 0b0000000, rd, r1, r2);
    }

    pub fn xor(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b100, 0b0000000, rd, r1, r2);
    }

    pub fn sll(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b001, 0b0000000, rd, r1, r2);
    }

    pub fn srl(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b101, 0b0000000, rd, r1, r2);
    }

    pub fn sra(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b101, 0b0100000, rd, r1, r2);
    }

    pub fn slt(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b010, 0b0000000, rd, r1, r2);
    }

    pub fn sltu(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0110011, 0b011, 0b0000000, rd, r1, r2);
    }

    // Arithmetic/Logical, Register-Register (32-bit)

    pub fn addw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b000, rd, r1, r2);
    }

    pub fn subw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b000, 0b0100000, rd, r1, r2);
    }

    pub fn sllw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b001, 0b0000000, rd, r1, r2);
    }

    pub fn srlw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b101, 0b0000000, rd, r1, r2);
    }

    pub fn sraw(rd: Register, r1: Register, r2: Register) Instruction {
        return rType(0b0111011, 0b101, 0b0100000, rd, r1, r2);
    }

    // Arithmetic/Logical, Register-Immediate

    pub fn addi(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b000, rd, r1, imm);
    }

    pub fn andi(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b111, rd, r1, imm);
    }

    pub fn ori(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b110, rd, r1, imm);
    }

    pub fn xori(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b100, rd, r1, imm);
    }

    pub fn slli(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b001, rd, r1, shamt);
    }

    pub fn srli(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b101, rd, r1, shamt);
    }

    pub fn srai(rd: Register, r1: Register, shamt: u6) Instruction {
        return iType(0b0010011, 0b101, rd, r1, (1 << 10) + shamt);
    }

    pub fn slti(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0010011, 0b010, rd, r1, imm);
    }

    pub fn sltiu(rd: Register, r1: Register, imm: u12) Instruction {
        return iType(0b0010011, 0b011, rd, r1, @bitCast(i12, imm));
    }

    // Arithmetic/Logical, Register-Immediate (32-bit)

    pub fn addiw(rd: Register, r1: Register, imm: i12) Instruction {
        return iType(0b0011011, 0b000, rd, r1, imm);
    }

    pub fn slliw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b001, rd, r1, shamt);
    }

    pub fn srliw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b101, rd, r1, shamt);
    }

    pub fn sraiw(rd: Register, r1: Register, shamt: u5) Instruction {
        return iType(0b0011011, 0b101, rd, r1, (1 << 10) + shamt);
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

    pub fn lw(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b010, rd, base, offset);
    }

    pub fn lwu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b110, rd, base, offset);
    }

    pub fn lh(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b001, rd, base, offset);
    }

    pub fn lhu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b101, rd, base, offset);
    }

    pub fn lb(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b000, rd, base, offset);
    }

    pub fn lbu(rd: Register, offset: i12, base: Register) Instruction {
        return iType(0b0000011, 0b100, rd, base, offset);
    }

    // Store

    pub fn sd(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b011, base, rs, offset);
    }

    pub fn sw(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b010, base, rs, offset);
    }

    pub fn sh(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b001, base, rs, offset);
    }

    pub fn sb(rs: Register, offset: i12, base: Register) Instruction {
        return sType(0b0100011, 0b000, base, rs, offset);
    }

    // Fence
    // TODO: implement fence

    // Branch

    pub fn beq(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b000, r1, r2, offset);
    }

    pub fn bne(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b001, r1, r2, offset);
    }

    pub fn blt(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b100, r1, r2, offset);
    }

    pub fn bge(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b101, r1, r2, offset);
    }

    pub fn bltu(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b110, r1, r2, offset);
    }

    pub fn bgeu(r1: Register, r2: Register, offset: i13) Instruction {
        return bType(0b1100011, 0b111, r1, r2, offset);
    }

    // Jump

    pub fn jal(link: Register, offset: i21) Instruction {
        return jType(0b1101111, link, offset);
    }

    pub fn jalr(link: Register, offset: i12, base: Register) Instruction {
        return iType(0b1100111, 0b000, link, base, offset);
    }

    // System

    pub const ecall = iType(0b1110011, 0b000, .zero, .zero, 0x000);
    pub const ebreak = iType(0b1110011, 0b000, .zero, .zero, 0x001);
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

    /// Returns the index into `callee_preserved_regs`.
    pub fn allocIndex(self: Register) ?u4 {
        inline for(callee_preserved_regs) |cpreg, i| {
            if(self == cpreg) return i;
        }
        return null;
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return @as(u8, @enumToInt(reg)) + DW.OP_reg0;
    }
};

// zig fmt: on

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};

test "serialize instructions" {
    const Testcase = struct {
        inst: Instruction,
        expected: u32,
    };

    const testcases = [_]Testcase{
        .{ // add t6, zero, zero
            .inst = Instruction.add(.t6, .zero, .zero),
            .expected = 0b0000000_00000_00000_000_11111_0110011,
        },
        .{ // sd s0, 0x7f(s0)
            .inst = Instruction.sd(.s0, 0x7f, .s0),
            .expected = 0b0000011_01000_01000_011_11111_0100011,
        },
        .{ // bne s0, s1, 0x42
            .inst = Instruction.bne(.s0, .s1, 0x42),
            .expected = 0b0_000010_01001_01000_001_0001_0_1100011,
        },
        .{ // j 0x1a
            .inst = Instruction.jal(.zero, 0x1a),
            .expected = 0b0_0000001101_0_00000000_00000_1101111,
        },
        .{ // ebreak
            .inst = Instruction.ebreak,
            .expected = 0b000000000001_00000_000_00000_1110011,
        },
    };

    for (testcases) |case| {
        const actual = case.inst.toU32();
        testing.expectEqual(case.expected, actual);
    }
}
