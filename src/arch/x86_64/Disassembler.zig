const Disassembler = @This();

const std = @import("std");
const assert = std.debug.assert;
const math = std.math;

const bits = @import("bits.zig");
const encoder = @import("encoder.zig");

const Encoding = @import("Encoding.zig");
const Immediate = bits.Immediate;
const Instruction = encoder.Instruction;
const LegacyPrefixes = encoder.LegacyPrefixes;
const Memory = Instruction.Memory;
const Register = bits.Register;
const Rex = encoder.Rex;

pub const Error = error{
    EndOfStream,
    LegacyPrefixAfterRex,
    UnknownOpcode,
    Overflow,
    Todo,
};

code: []const u8,
pos: usize = 0,

pub fn init(code: []const u8) Disassembler {
    return .{ .code = code };
}

pub fn next(dis: *Disassembler) Error!?Instruction {
    const prefixes = dis.parsePrefixes() catch |err| switch (err) {
        error.EndOfStream => return null,
        else => |e| return e,
    };

    const enc = try dis.parseEncoding(prefixes) orelse return error.UnknownOpcode;
    switch (enc.data.op_en) {
        .zo => return inst(enc, .{}),
        .d, .i => {
            const imm = try dis.parseImm(enc.data.ops[0]);
            return inst(enc, .{
                .op1 = .{ .imm = imm },
            });
        },
        .zi => {
            const imm = try dis.parseImm(enc.data.ops[1]);
            return inst(enc, .{
                .op1 = .{ .reg = Register.rax.toBitSize(enc.data.ops[0].regBitSize()) },
                .op2 = .{ .imm = imm },
            });
        },
        .o, .oi => {
            const reg_low_enc = @as(u3, @truncate(dis.code[dis.pos - 1]));
            const op2: Instruction.Operand = if (enc.data.op_en == .oi) .{
                .imm = try dis.parseImm(enc.data.ops[1]),
            } else .none;
            return inst(enc, .{
                .op1 = .{ .reg = parseGpRegister(reg_low_enc, prefixes.rex.b, prefixes.rex, enc.data.ops[0].regBitSize()) },
                .op2 = op2,
            });
        },
        .m, .mi, .m1, .mc => {
            const modrm = try dis.parseModRmByte();
            const act_enc = Encoding.findByOpcode(enc.opcode(), .{
                .legacy = prefixes.legacy,
                .rex = prefixes.rex,
            }, modrm.op1) orelse return error.UnknownOpcode;
            const sib = if (modrm.sib()) try dis.parseSibByte() else null;

            if (modrm.direct()) {
                const op2: Instruction.Operand = switch (act_enc.data.op_en) {
                    .mi => .{ .imm = try dis.parseImm(act_enc.data.ops[1]) },
                    .m1 => .{ .imm = Immediate.u(1) },
                    .mc => .{ .reg = .cl },
                    .m => .none,
                    else => unreachable,
                };
                return inst(act_enc, .{
                    .op1 = .{ .reg = parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, act_enc.data.ops[0].regBitSize()) },
                    .op2 = op2,
                });
            }

            const disp = try dis.parseDisplacement(modrm, sib);
            const op2: Instruction.Operand = switch (act_enc.data.op_en) {
                .mi => .{ .imm = try dis.parseImm(act_enc.data.ops[1]) },
                .m1 => .{ .imm = Immediate.u(1) },
                .mc => .{ .reg = .cl },
                .m => .none,
                else => unreachable,
            };

            if (modrm.rip()) {
                return inst(act_enc, .{
                    .op1 = .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(act_enc.data.ops[0].memBitSize()), disp) },
                    .op2 = op2,
                });
            }

            const scale_index = if (sib) |info| info.scaleIndex(prefixes.rex) else null;
            const base = if (sib) |info|
                info.baseReg(modrm, prefixes)
            else
                parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, 64);
            return inst(act_enc, .{
                .op1 = .{ .mem = Memory.sib(Memory.PtrSize.fromBitSize(act_enc.data.ops[0].memBitSize()), .{
                    .base = if (base) |base_reg| .{ .reg = base_reg } else .none,
                    .scale_index = scale_index,
                    .disp = disp,
                }) },
                .op2 = op2,
            });
        },
        .fd => {
            const seg = segmentRegister(prefixes.legacy);
            const offset = try dis.parseOffset();
            return inst(enc, .{
                .op1 = .{ .reg = Register.rax.toBitSize(enc.data.ops[0].regBitSize()) },
                .op2 = .{ .mem = Memory.moffs(seg, offset) },
            });
        },
        .td => {
            const seg = segmentRegister(prefixes.legacy);
            const offset = try dis.parseOffset();
            return inst(enc, .{
                .op1 = .{ .mem = Memory.moffs(seg, offset) },
                .op2 = .{ .reg = Register.rax.toBitSize(enc.data.ops[1].regBitSize()) },
            });
        },
        .mr, .mri, .mrc => {
            const modrm = try dis.parseModRmByte();
            const sib = if (modrm.sib()) try dis.parseSibByte() else null;
            const src_bit_size = enc.data.ops[1].regBitSize();

            if (modrm.direct()) {
                return inst(enc, .{
                    .op1 = .{ .reg = parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, enc.data.ops[0].regBitSize()) },
                    .op2 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.x, prefixes.rex, src_bit_size) },
                });
            }

            const dst_bit_size = enc.data.ops[0].memBitSize();
            const disp = try dis.parseDisplacement(modrm, sib);
            const op3: Instruction.Operand = switch (enc.data.op_en) {
                .mri => .{ .imm = try dis.parseImm(enc.data.ops[2]) },
                .mrc => .{ .reg = .cl },
                .mr => .none,
                else => unreachable,
            };

            if (modrm.rip()) {
                return inst(enc, .{
                    .op1 = .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(dst_bit_size), disp) },
                    .op2 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.r, prefixes.rex, src_bit_size) },
                    .op3 = op3,
                });
            }

            const scale_index = if (sib) |info| info.scaleIndex(prefixes.rex) else null;
            const base = if (sib) |info|
                info.baseReg(modrm, prefixes)
            else
                parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, 64);
            return inst(enc, .{
                .op1 = .{ .mem = Memory.sib(Memory.PtrSize.fromBitSize(dst_bit_size), .{
                    .base = if (base) |base_reg| .{ .reg = base_reg } else .none,
                    .scale_index = scale_index,
                    .disp = disp,
                }) },
                .op2 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.r, prefixes.rex, src_bit_size) },
                .op3 = op3,
            });
        },
        .rm, .rmi => {
            const modrm = try dis.parseModRmByte();
            const sib = if (modrm.sib()) try dis.parseSibByte() else null;
            const dst_bit_size = enc.data.ops[0].regBitSize();

            if (modrm.direct()) {
                const op3: Instruction.Operand = switch (enc.data.op_en) {
                    .rm => .none,
                    .rmi => .{ .imm = try dis.parseImm(enc.data.ops[2]) },
                    else => unreachable,
                };
                return inst(enc, .{
                    .op1 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.x, prefixes.rex, dst_bit_size) },
                    .op2 = .{ .reg = parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, enc.data.ops[1].regBitSize()) },
                    .op3 = op3,
                });
            }

            const src_bit_size = if (enc.data.ops[1] == .m) dst_bit_size else enc.data.ops[1].memBitSize();
            const disp = try dis.parseDisplacement(modrm, sib);
            const op3: Instruction.Operand = switch (enc.data.op_en) {
                .rmi => .{ .imm = try dis.parseImm(enc.data.ops[2]) },
                .rm => .none,
                else => unreachable,
            };

            if (modrm.rip()) {
                return inst(enc, .{
                    .op1 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.r, prefixes.rex, dst_bit_size) },
                    .op2 = .{ .mem = Memory.rip(Memory.PtrSize.fromBitSize(src_bit_size), disp) },
                    .op3 = op3,
                });
            }

            const scale_index = if (sib) |info| info.scaleIndex(prefixes.rex) else null;
            const base = if (sib) |info|
                info.baseReg(modrm, prefixes)
            else
                parseGpRegister(modrm.op2, prefixes.rex.b, prefixes.rex, 64);
            return inst(enc, .{
                .op1 = .{ .reg = parseGpRegister(modrm.op1, prefixes.rex.r, prefixes.rex, dst_bit_size) },
                .op2 = .{ .mem = Memory.sib(Memory.PtrSize.fromBitSize(src_bit_size), .{
                    .base = if (base) |base_reg| .{ .reg = base_reg } else .none,
                    .scale_index = scale_index,
                    .disp = disp,
                }) },
                .op3 = op3,
            });
        },
        .rm0, .vmi, .rvm, .rvmr, .rvmi, .mvr => unreachable, // TODO
    }
}

fn inst(encoding: Encoding, args: struct {
    prefix: Instruction.Prefix = .none,
    op1: Instruction.Operand = .none,
    op2: Instruction.Operand = .none,
    op3: Instruction.Operand = .none,
    op4: Instruction.Operand = .none,
}) Instruction {
    return .{ .encoding = encoding, .prefix = args.prefix, .ops = .{
        args.op1,
        args.op2,
        args.op3,
        args.op4,
    } };
}

const Prefixes = struct {
    legacy: LegacyPrefixes = .{},
    rex: Rex = .{},
    // TODO add support for VEX prefix
};

fn parsePrefixes(dis: *Disassembler) !Prefixes {
    const rex_prefix_mask: u4 = 0b0100;
    var stream = std.io.fixedBufferStream(dis.code[dis.pos..]);
    const reader = stream.reader();

    var res: Prefixes = .{};

    while (true) {
        const next_byte = try reader.readByte();
        dis.pos += 1;

        switch (next_byte) {
            0xf0, 0xf2, 0xf3, 0x2e, 0x36, 0x26, 0x64, 0x65, 0x3e, 0x66, 0x67 => {
                // Legacy prefix
                if (res.rex.present) return error.LegacyPrefixAfterRex;
                switch (next_byte) {
                    0xf0 => res.legacy.prefix_f0 = true,
                    0xf2 => res.legacy.prefix_f2 = true,
                    0xf3 => res.legacy.prefix_f3 = true,
                    0x2e => res.legacy.prefix_2e = true,
                    0x36 => res.legacy.prefix_36 = true,
                    0x26 => res.legacy.prefix_26 = true,
                    0x64 => res.legacy.prefix_64 = true,
                    0x65 => res.legacy.prefix_65 = true,
                    0x3e => res.legacy.prefix_3e = true,
                    0x66 => res.legacy.prefix_66 = true,
                    0x67 => res.legacy.prefix_67 = true,
                    else => unreachable,
                }
            },
            else => {
                if (rex_prefix_mask == @as(u4, @truncate(next_byte >> 4))) {
                    // REX prefix
                    res.rex.w = next_byte & 0b1000 != 0;
                    res.rex.r = next_byte & 0b100 != 0;
                    res.rex.x = next_byte & 0b10 != 0;
                    res.rex.b = next_byte & 0b1 != 0;
                    res.rex.present = true;
                    continue;
                }

                // TODO VEX prefix

                dis.pos -= 1;
                break;
            },
        }
    }

    return res;
}

fn parseEncoding(dis: *Disassembler, prefixes: Prefixes) !?Encoding {
    const o_mask: u8 = 0b1111_1000;

    var opcode: [3]u8 = .{ 0, 0, 0 };
    var stream = std.io.fixedBufferStream(dis.code[dis.pos..]);
    const reader = stream.reader();

    comptime var opc_count = 0;
    inline while (opc_count < 3) : (opc_count += 1) {
        const byte = try reader.readByte();
        opcode[opc_count] = byte;
        dis.pos += 1;

        if (byte == 0x0f) {
            // Multi-byte opcode
        } else if (opc_count > 0) {
            // Multi-byte opcode
            if (Encoding.findByOpcode(opcode[0 .. opc_count + 1], .{
                .legacy = prefixes.legacy,
                .rex = prefixes.rex,
            }, null)) |mnemonic| {
                return mnemonic;
            }
        } else {
            // Single-byte opcode
            if (Encoding.findByOpcode(opcode[0..1], .{
                .legacy = prefixes.legacy,
                .rex = prefixes.rex,
            }, null)) |mnemonic| {
                return mnemonic;
            } else {
                // Try O* encoding
                return Encoding.findByOpcode(&.{opcode[0] & o_mask}, .{
                    .legacy = prefixes.legacy,
                    .rex = prefixes.rex,
                }, null);
            }
        }
    }
    return null;
}

fn parseGpRegister(low_enc: u3, is_extended: bool, rex: Rex, bit_size: u64) Register {
    const reg_id: u4 = @as(u4, @intCast(@intFromBool(is_extended))) << 3 | low_enc;
    const reg = @as(Register, @enumFromInt(reg_id)).toBitSize(bit_size);
    return switch (reg) {
        .spl => if (rex.present or rex.isSet()) .spl else .ah,
        .dil => if (rex.present or rex.isSet()) .dil else .bh,
        .bpl => if (rex.present or rex.isSet()) .bpl else .ch,
        .sil => if (rex.present or rex.isSet()) .sil else .dh,
        else => reg,
    };
}

fn parseImm(dis: *Disassembler, kind: Encoding.Op) !Immediate {
    var stream = std.io.fixedBufferStream(dis.code[dis.pos..]);
    var creader = std.io.countingReader(stream.reader());
    const reader = creader.reader();
    const imm = switch (kind) {
        .imm8s, .rel8 => Immediate.s(try reader.readInt(i8, .little)),
        .imm16s, .rel16 => Immediate.s(try reader.readInt(i16, .little)),
        .imm32s, .rel32 => Immediate.s(try reader.readInt(i32, .little)),
        .imm8 => Immediate.u(try reader.readInt(u8, .little)),
        .imm16 => Immediate.u(try reader.readInt(u16, .little)),
        .imm32 => Immediate.u(try reader.readInt(u32, .little)),
        .imm64 => Immediate.u(try reader.readInt(u64, .little)),
        else => unreachable,
    };
    dis.pos += std.math.cast(usize, creader.bytes_read) orelse return error.Overflow;
    return imm;
}

fn parseOffset(dis: *Disassembler) !u64 {
    var stream = std.io.fixedBufferStream(dis.code[dis.pos..]);
    const reader = stream.reader();
    const offset = try reader.readInt(u64, .little);
    dis.pos += 8;
    return offset;
}

const ModRm = packed struct {
    mod: u2,
    op1: u3,
    op2: u3,

    inline fn direct(self: ModRm) bool {
        return self.mod == 0b11;
    }

    inline fn rip(self: ModRm) bool {
        return self.mod == 0 and self.op2 == 0b101;
    }

    inline fn sib(self: ModRm) bool {
        return !self.direct() and self.op2 == 0b100;
    }
};

fn parseModRmByte(dis: *Disassembler) !ModRm {
    if (dis.code[dis.pos..].len == 0) return error.EndOfStream;
    const modrm_byte = dis.code[dis.pos];
    dis.pos += 1;
    const mod: u2 = @as(u2, @truncate(modrm_byte >> 6));
    const op1: u3 = @as(u3, @truncate(modrm_byte >> 3));
    const op2: u3 = @as(u3, @truncate(modrm_byte));
    return ModRm{ .mod = mod, .op1 = op1, .op2 = op2 };
}

fn segmentRegister(prefixes: LegacyPrefixes) Register {
    if (prefixes.prefix_2e) return .cs;
    if (prefixes.prefix_36) return .ss;
    if (prefixes.prefix_26) return .es;
    if (prefixes.prefix_64) return .fs;
    if (prefixes.prefix_65) return .gs;
    return .ds;
}

const Sib = packed struct {
    scale: u2,
    index: u3,
    base: u3,

    fn scaleIndex(self: Sib, rex: Rex) ?Memory.ScaleIndex {
        if (self.index == 0b100 and !rex.x) return null;
        return .{
            .scale = @as(u4, 1) << self.scale,
            .index = parseGpRegister(self.index, rex.x, rex, 64),
        };
    }

    fn baseReg(self: Sib, modrm: ModRm, prefixes: Prefixes) ?Register {
        if (self.base == 0b101 and modrm.mod == 0) {
            if (self.scaleIndex(prefixes.rex)) |_| return null;
            return segmentRegister(prefixes.legacy);
        }
        return parseGpRegister(self.base, prefixes.rex.b, prefixes.rex, 64);
    }
};

fn parseSibByte(dis: *Disassembler) !Sib {
    if (dis.code[dis.pos..].len == 0) return error.EndOfStream;
    const sib_byte = dis.code[dis.pos];
    dis.pos += 1;
    const scale: u2 = @as(u2, @truncate(sib_byte >> 6));
    const index: u3 = @as(u3, @truncate(sib_byte >> 3));
    const base: u3 = @as(u3, @truncate(sib_byte));
    return Sib{ .scale = scale, .index = index, .base = base };
}

fn parseDisplacement(dis: *Disassembler, modrm: ModRm, sib: ?Sib) !i32 {
    var stream = std.io.fixedBufferStream(dis.code[dis.pos..]);
    var creader = std.io.countingReader(stream.reader());
    const reader = creader.reader();
    const disp = disp: {
        if (sib) |info| {
            if (info.base == 0b101 and modrm.mod == 0) {
                break :disp try reader.readInt(i32, .little);
            }
        }
        if (modrm.rip()) {
            break :disp try reader.readInt(i32, .little);
        }
        break :disp switch (modrm.mod) {
            0b00 => 0,
            0b01 => try reader.readInt(i8, .little),
            0b10 => try reader.readInt(i32, .little),
            0b11 => unreachable,
        };
    };
    dis.pos += std.math.cast(usize, creader.bytes_read) orelse return error.Overflow;
    return disp;
}
