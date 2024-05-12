mnemonic: Mnemonic,
data: Data,

const OpCode = enum(u7) {
    OP = 0b0110011,
    OP_IMM = 0b0010011,
    OP_32 = 0b0111011,

    BRANCH = 0b1100011,
    LOAD = 0b0000011,
    STORE = 0b0100011,
    SYSTEM = 0b1110011,

    OP_FP = 0b1010011,
    LOAD_FP = 0b0000111,
    STORE_FP = 0b0100111,

    JALR = 0b1100111,
    AUIPC = 0b0010111,
    LUI = 0b0110111,
    JAL = 0b1101111,
    NONE = 0b0000000,
};

const Fmt = enum(u2) {
    /// 32-bit single-precision
    S = 0b00,
    /// 64-bit double-precision
    D = 0b01,
    _reserved = 0b10,
    /// 128-bit quad-precision
    Q = 0b11,
};

const Enc = struct {
    opcode: OpCode,

    data: union(enum) {
        /// funct3 + funct7
        ff: struct {
            funct3: u3,
            funct7: u7,
        },
        /// funct3 + offset
        fo: struct {
            funct3: u3,
            offset: u12 = 0,
        },
        /// funct5 + rm + fmt
        fmt: struct {
            funct5: u5,
            rm: u3,
            fmt: Fmt,
        },
        /// U-type
        none,
    },
};

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
    sllw,

    addi,
    jalr,

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
    @"and",
    @"or",
    sub,
    slt,
    mul,
    sltu,
    xor,

    // System
    ecall,
    ebreak,
    unimp,

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


            // OP_IMM

            .addi    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b000 } } },
            .andi    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b111 } } },
            .xori    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b100 } } },
            
            .sltiu   => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b011 } } },

            .slli    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b001 } } },
            .srli    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b101 } } },
            .srai    => .{ .opcode = .OP_IMM, .data = .{ .fo = .{ .funct3 = 0b101, .offset = 1 << 10 } } },


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


            // LOAD

            .lb      => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b000 } } },
            .lh      => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b001 } } },
            .lw      => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b010 } } },
            .ld      => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b011 } } },
            .lbu     => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b100 } } },
            .lhu     => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b101 } } },
            .lwu     => .{ .opcode = .LOAD, .data = .{ .fo = .{ .funct3 = 0b110 } } },


            // STORE
            
            .sb      => .{ .opcode = .STORE, .data = .{ .fo = .{ .funct3 = 0b000 } } },
            .sh      => .{ .opcode = .STORE, .data = .{ .fo = .{ .funct3 = 0b001 } } },
            .sw      => .{ .opcode = .STORE, .data = .{ .fo = .{ .funct3 = 0b010 } } },
            .sd      => .{ .opcode = .STORE, .data = .{ .fo = .{ .funct3 = 0b011 } } },


            // LOAD_FP

            .flw     => .{ .opcode = .LOAD_FP, .data = .{ .fo = .{ .funct3 = 0b010 } } },
            .fld     => .{ .opcode = .LOAD_FP, .data = .{ .fo = .{ .funct3 = 0b011 } } },
            

            // STORE_FP

            .fsw     => .{ .opcode = .STORE_FP, .data = .{ .fo = .{ .funct3 = 0b010 } } },
            .fsd     => .{ .opcode = .STORE_FP, .data = .{ .fo = .{ .funct3 = 0b011 } } },


            // JALR

            .jalr    => .{ .opcode = .JALR, .data = .{ .fo = .{ .funct3 = 0b000 } } },


            // OP_32

            .sllw    => .{ .opcode = .OP_32, .data = .{ .ff = .{ .funct3 = 0b001, .funct7 = 0b0000000 } } },


            // LUI

            .lui     => .{ .opcode = .LUI, .data = .{ .none = {} } },


            // AUIPC

            .auipc   => .{ .opcode = .AUIPC, .data = .{ .none = {} } },


            // JAL

            .jal     => .{ .opcode = .JAL, .data = .{ .none = {} } },


            // BRANCH

            .beq     => .{ .opcode = .BRANCH, .data = .{ .fo = .{ .funct3 = 0b000 } } },


            // SYSTEM

            .ecall   => .{ .opcode = .SYSTEM, .data = .{ .fo = .{ .funct3 = 0b000 } } },
            .ebreak  => .{ .opcode = .SYSTEM, .data = .{ .fo = .{ .funct3 = 0b000 } } },
           

            // NONE
            
            .unimp   => .{ .opcode = .NONE, .data = .{ .fo = .{ .funct3 = 0b000 } } },


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

    /// extras that have unusual op counts
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

            .ld,
            .lw,
            .lwu,
            .lh,
            .lhu,
            .lb,
            .lbu,

            .flw,
            .fld,
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
            .sllw,
            .mul,
            .xor,
            .add,
            .sub,
            .@"and",
            .@"or",

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
            => .R,

            .ecall,
            .ebreak,
            .unimp,
            => .system,
        };
    }

    pub fn opsList(enc: InstEnc) [4]std.meta.FieldEnum(Operand) {
        return switch (enc) {
            // zig fmt: off
            .R      => .{ .reg,  .reg,  .reg,  .none },
            .R4     => .{ .reg,  .reg,  .reg,  .reg  },  
            .I      => .{ .reg,  .reg,  .imm,  .none },
            .S      => .{ .reg,  .reg,  .imm,  .none },
            .B      => .{ .reg,  .reg,  .imm,  .none },
            .U      => .{ .reg,  .imm,  .none, .none },
            .J      => .{ .reg,  .imm,  .none, .none },
            .system => .{ .none, .none, .none, .none },
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
    system: void,

    pub fn toU32(self: Data) u32 {
        return switch (self) {
            // zig fmt: off
            .R  => |v| @bitCast(v),
            .R4 => |v| @bitCast(v),
            .I  => |v| @bitCast(v),
            .S  => |v| @bitCast(v),
            .B  => |v| @as(u32, @intCast(v.opcode)) + (@as(u32, @intCast(v.imm11)) << 7) + (@as(u32, @intCast(v.imm1_4)) << 8) + (@as(u32, @intCast(v.funct3)) << 12) + (@as(u32, @intCast(v.rs1)) << 15) + (@as(u32, @intCast(v.rs2)) << 20) + (@as(u32, @intCast(v.imm5_10)) << 25) + (@as(u32, @intCast(v.imm12)) << 31),
            .U  => |v| @bitCast(v),
            .J  => |v| @bitCast(v),
            .system => unreachable,
            // zig fmt: on
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
                            .unimp => 0,
                            else => unreachable,
                        },

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.fo.funct3,
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
                        .funct3 = enc.data.fo.funct3,
                    },
                };
            },
            .I => {
                assert(ops.len == 3);
                return .{
                    .I = .{
                        .rd = ops[0].reg.encodeId(),
                        .rs1 = ops[1].reg.encodeId(),
                        .imm0_11 = ops[2].imm.asBits(u12) + enc.data.fo.offset,

                        .opcode = @intFromEnum(enc.opcode),
                        .funct3 = enc.data.fo.funct3,
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
                        .funct3 = enc.data.fo.funct3,
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
