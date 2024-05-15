mnemonic: Mnemonic,
data: Data,

pub const Mnemonic = enum {
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

    addi,
    jalr,

    // U Type
    lui,

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
    sub,
    slt,
    mul,
    sltu,
    xor,

    // System
    ecall,
    ebreak,
    unimp,

    pub fn encoding(mnem: Mnemonic) Enc {
        return switch (mnem) {
            // zig fmt: off
            .add    => .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000000 },
            .sltu   => .{ .opcode = 0b0110011, .funct3 = 0b011, .funct7 = 0b0000000 },
            .@"and" => .{ .opcode = 0b0110011, .funct3 = 0b111, .funct7 = 0b0000000 },
            .sub    => .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0100000 }, 

            .ld     => .{ .opcode = 0b0000011, .funct3 = 0b011, .funct7 = null      },
            .lw     => .{ .opcode = 0b0000011, .funct3 = 0b010, .funct7 = null      },
            .lwu    => .{ .opcode = 0b0000011, .funct3 = 0b110, .funct7 = null      },
            .lh     => .{ .opcode = 0b0000011, .funct3 = 0b001, .funct7 = null      },
            .lhu    => .{ .opcode = 0b0000011, .funct3 = 0b101, .funct7 = null      },
            .lb     => .{ .opcode = 0b0000011, .funct3 = 0b000, .funct7 = null      },
            .lbu    => .{ .opcode = 0b0000011, .funct3 = 0b100, .funct7 = null      },

            .sltiu  => .{ .opcode = 0b0010011, .funct3 = 0b011, .funct7 = null      },

            .addi   => .{ .opcode = 0b0010011, .funct3 = 0b000, .funct7 = null      },
            .andi   => .{ .opcode = 0b0010011, .funct3 = 0b111, .funct7 = null      },
            .xori   => .{ .opcode = 0b0010011, .funct3 = 0b100, .funct7 = null      },
            .jalr   => .{ .opcode = 0b1100111, .funct3 = 0b000, .funct7 = null      },
            .slli   => .{ .opcode = 0b0010011, .funct3 = 0b001, .funct7 = null      },
            .srli   => .{ .opcode = 0b0010011, .funct3 = 0b101, .funct7 = null      },
            .srai   => .{ .opcode = 0b0010011, .funct3 = 0b101, .funct7 = null,   .offset = 1 << 10  },

            .lui    => .{ .opcode = 0b0110111, .funct3 = null,  .funct7 = null      },

            .sd     => .{ .opcode = 0b0100011, .funct3 = 0b011, .funct7 = null      },
            .sw     => .{ .opcode = 0b0100011, .funct3 = 0b010, .funct7 = null      },
            .sh     => .{ .opcode = 0b0100011, .funct3 = 0b001, .funct7 = null      },
            .sb     => .{ .opcode = 0b0100011, .funct3 = 0b000, .funct7 = null      },

            .jal    => .{ .opcode = 0b1101111, .funct3 = null,  .funct7 = null      },

            .beq    => .{ .opcode = 0b1100011, .funct3 = 0b000, .funct7 = null      },

            .slt    => .{ .opcode = 0b0110011, .funct3 = 0b010, .funct7 = 0b0000000 },

            .xor    => .{ .opcode = 0b0110011, .funct3 = 0b100, .funct7 = 0b0000000 },

            .mul    => .{ .opcode = 0b0110011, .funct3 = 0b000, .funct7 = 0b0000001 },

            .ecall  => .{ .opcode = 0b1110011, .funct3 = 0b000, .funct7 = null      },
            .ebreak => .{ .opcode = 0b1110011, .funct3 = 0b000, .funct7 = null      },
            .unimp  => .{ .opcode = 0b0000000, .funct3 = 0b000, .funct7 = null      },
            // zig fmt: on
        };
    }
};

pub const InstEnc = enum {
    R,
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
            .ld,
            .lw,
            .lwu,
            .lh,
            .lhu,
            .lb,
            .lbu,
            .jalr,
            .sltiu,
            .xori,
            .andi,
            .slli,
            .srli,
            .srai,
            => .I,

            .lui,
            => .U,

            .sd,
            .sw,
            .sh,
            .sb,
            => .S,

            .jal,
            => .J,

            .beq,
            => .B,

            .slt,
            .sltu,
            .mul,
            .xor,
            .add,
            .sub,
            .@"and",
            => .R,

            .ecall,
            .ebreak,
            .unimp,
            => .system,
        };
    }

    pub fn opsList(enc: InstEnc) [3]std.meta.FieldEnum(Operand) {
        return switch (enc) {
            // zig fmt: off
            .R =>      .{ .reg,  .reg,  .reg,  },
            .I =>      .{ .reg,  .reg,  .imm,  },
            .S =>      .{ .reg,  .reg,  .imm,  },
            .B =>      .{ .reg,  .reg,  .imm,  },
            .U =>      .{ .reg,  .imm,  .none, },
            .J =>      .{ .reg,  .imm,  .none, },
            .system => .{ .none, .none, .none, },
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
            .R => |v| @as(u32, @bitCast(v)),
            .I => |v| @as(u32, @bitCast(v)),
            .S => |v| @as(u32, @bitCast(v)),
            .B => |v| @as(u32, @intCast(v.opcode)) + (@as(u32, @intCast(v.imm11)) << 7) + (@as(u32, @intCast(v.imm1_4)) << 8) + (@as(u32, @intCast(v.funct3)) << 12) + (@as(u32, @intCast(v.rs1)) << 15) + (@as(u32, @intCast(v.rs2)) << 20) + (@as(u32, @intCast(v.imm5_10)) << 25) + (@as(u32, @intCast(v.imm12)) << 31),
            .U => |v| @as(u32, @bitCast(v)),
            .J => |v| @as(u32, @bitCast(v)),
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
                        .rd = Register.zero.id(),
                        .rs1 = Register.zero.id(),
                        .imm0_11 = switch (mnem) {
                            .ecall => 0x000,
                            .ebreak => 0x001,
                            .unimp => 0,
                            else => unreachable,
                        },

                        .opcode = enc.opcode,
                        .funct3 = enc.funct3.?,
                    },
                };
            },
            else => {},
        }

        switch (inst_enc) {
            .R => {
                assert(ops.len == 3);
                return .{
                    .R = .{
                        .rd = ops[0].reg.id(),
                        .rs1 = ops[1].reg.id(),
                        .rs2 = ops[2].reg.id(),

                        .opcode = enc.opcode,
                        .funct3 = enc.funct3.?,
                        .funct7 = enc.funct7.?,
                    },
                };
            },
            .S => {
                assert(ops.len == 3);
                const umm = ops[2].imm.asBits(u12);

                return .{
                    .S = .{
                        .imm0_4 = @truncate(umm),
                        .rs1 = ops[0].reg.id(),
                        .rs2 = ops[1].reg.id(),
                        .imm5_11 = @truncate(umm >> 5),

                        .opcode = enc.opcode,
                        .funct3 = enc.funct3.?,
                    },
                };
            },
            .I => {
                assert(ops.len == 3);
                return .{
                    .I = .{
                        .rd = ops[0].reg.id(),
                        .rs1 = ops[1].reg.id(),
                        .imm0_11 = ops[2].imm.asBits(u12) + enc.offset,

                        .opcode = enc.opcode,
                        .funct3 = enc.funct3.?,
                    },
                };
            },
            .U => {
                assert(ops.len == 2);
                return .{
                    .U = .{
                        .rd = ops[0].reg.id(),
                        .imm12_31 = ops[1].imm.asBits(u20),

                        .opcode = enc.opcode,
                    },
                };
            },
            .J => {
                assert(ops.len == 2);

                const umm = ops[1].imm.asBits(u21);
                assert(umm % 4 == 0); // misaligned jump target

                return .{
                    .J = .{
                        .rd = ops[0].reg.id(),
                        .imm1_10 = @truncate(umm >> 1),
                        .imm11 = @truncate(umm >> 11),
                        .imm12_19 = @truncate(umm >> 12),
                        .imm20 = @truncate(umm >> 20),

                        .opcode = enc.opcode,
                    },
                };
            },
            .B => {
                assert(ops.len == 3);

                const umm = ops[2].imm.asBits(u13);
                assert(umm % 4 == 0); // misaligned branch target

                return .{
                    .B = .{
                        .rs1 = ops[0].reg.id(),
                        .rs2 = ops[1].reg.id(),
                        .imm1_4 = @truncate(umm >> 1),
                        .imm5_10 = @truncate(umm >> 5),
                        .imm11 = @truncate(umm >> 11),
                        .imm12 = @truncate(umm >> 12),

                        .opcode = enc.opcode,
                        .funct3 = enc.funct3.?,
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

const Enc = struct {
    opcode: u7,
    funct3: ?u3,
    funct7: ?u7,
    offset: u12 = 0,
};

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
