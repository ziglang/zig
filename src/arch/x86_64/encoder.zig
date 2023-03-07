const std = @import("std");
const assert = std.debug.assert;
const math = std.math;

const bits = @import("bits.zig");
const Encoding = @import("Encoding.zig");
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const Moffs = bits.Moffs;
const PtrSize = bits.PtrSize;
const Register = bits.Register;

pub const Instruction = struct {
    op1: Operand = .none,
    op2: Operand = .none,
    op3: Operand = .none,
    op4: Operand = .none,
    encoding: Encoding,

    pub const Mnemonic = Encoding.Mnemonic;

    pub const Operand = union(enum) {
        none,
        reg: Register,
        mem: Memory,
        imm: Immediate,

        /// Returns the bitsize of the operand.
        pub fn bitSize(op: Operand) u64 {
            return switch (op) {
                .none => unreachable,
                .reg => |reg| reg.bitSize(),
                .mem => |mem| mem.bitSize(),
                .imm => unreachable,
            };
        }

        /// Returns true if the operand is a segment register.
        /// Asserts the operand is either register or memory.
        pub fn isSegmentRegister(op: Operand) bool {
            return switch (op) {
                .none => unreachable,
                .reg => |reg| reg.class() == .segment,
                .mem => |mem| mem.isSegmentRegister(),
                .imm => unreachable,
            };
        }

        pub fn fmtPrint(op: Operand, enc_op: Encoding.Op, writer: anytype) !void {
            switch (op) {
                .none => {},
                .reg => |reg| try writer.writeAll(@tagName(reg)),
                .mem => |mem| switch (mem) {
                    .rip => |rip| {
                        try writer.print("{s} ptr [rip", .{@tagName(rip.ptr_size)});
                        if (rip.disp != 0) {
                            const sign_bit = if (sign(rip.disp) < 0) "-" else "+";
                            const disp_abs = try std.math.absInt(rip.disp);
                            try writer.print(" {s} 0x{x}", .{ sign_bit, disp_abs });
                        }
                        try writer.writeByte(']');
                    },
                    .sib => |sib| {
                        try writer.print("{s} ptr ", .{@tagName(sib.ptr_size)});

                        if (mem.isSegmentRegister()) {
                            return writer.print("{s}:0x{x}", .{ @tagName(sib.base.?), sib.disp });
                        }

                        try writer.writeByte('[');

                        if (sib.base) |base| {
                            try writer.print("{s}", .{@tagName(base)});
                        }
                        if (sib.scale_index) |si| {
                            if (sib.base != null) {
                                try writer.writeAll(" + ");
                            }
                            try writer.print("{s} * {d}", .{ @tagName(si.index), si.scale });
                        }
                        if (sib.disp != 0) {
                            if (sib.base != null or sib.scale_index != null) {
                                try writer.writeByte(' ');
                            }
                            try writer.writeByte(if (sign(sib.disp) < 0) '-' else '+');
                            const disp_abs = try std.math.absInt(sib.disp);
                            try writer.print(" 0x{x}", .{disp_abs});
                        }

                        try writer.writeByte(']');
                    },
                    .moffs => |moffs| try writer.print("{s}:0x{x}", .{ @tagName(moffs.seg), moffs.offset }),
                },
                .imm => |imm| try writer.print("0x{x}", .{imm.asUnsigned(enc_op.bitSize())}),
            }
        }
    };

    pub fn new(mnemonic: Mnemonic, args: struct {
        op1: Operand = .none,
        op2: Operand = .none,
        op3: Operand = .none,
        op4: Operand = .none,
    }) !Instruction {
        const encoding = (try Encoding.findByMnemonic(mnemonic, .{
            .op1 = args.op1,
            .op2 = args.op2,
            .op3 = args.op3,
            .op4 = args.op4,
        })) orelse {
            std.log.debug("{s} {s} {s} {s} {s}", .{
                @tagName(mnemonic),
                @tagName(Encoding.Op.fromOperand(args.op1)),
                @tagName(Encoding.Op.fromOperand(args.op2)),
                @tagName(Encoding.Op.fromOperand(args.op3)),
                @tagName(Encoding.Op.fromOperand(args.op4)),
            });
            return error.InvalidInstruction;
        };
        std.log.debug("{}", .{encoding});
        return .{
            .op1 = args.op1,
            .op2 = args.op2,
            .op3 = args.op3,
            .op4 = args.op4,
            .encoding = encoding,
        };
    }

    pub fn fmtPrint(inst: Instruction, writer: anytype) !void {
        try writer.print("{s}", .{@tagName(inst.encoding.mnemonic)});
        const ops = [_]struct { Operand, Encoding.Op }{
            .{ inst.op1, inst.encoding.op1 },
            .{ inst.op2, inst.encoding.op2 },
            .{ inst.op3, inst.encoding.op3 },
            .{ inst.op4, inst.encoding.op4 },
        };
        for (&ops, 0..) |op, i| {
            if (op[0] == .none) break;
            if (i > 0) {
                try writer.writeByte(',');
            }
            try writer.writeByte(' ');
            try op[0].fmtPrint(op[1], writer);
        }
    }

    pub fn encode(inst: Instruction, writer: anytype) !void {
        const encoder = Encoder(@TypeOf(writer)){ .writer = writer };
        const encoding = inst.encoding;

        try inst.encodeLegacyPrefixes(encoder);
        try inst.encodeMandatoryPrefix(encoder);
        try inst.encodeRexPrefix(encoder);
        try inst.encodeOpcode(encoder);

        switch (encoding.op_en) {
            .np, .o => {},
            .i, .d => try encodeImm(inst.op1.imm, encoding.op1, encoder),
            .zi, .oi => try encodeImm(inst.op2.imm, encoding.op2, encoder),
            .fd => try encoder.imm64(inst.op2.mem.moffs.offset),
            .td => try encoder.imm64(inst.op1.mem.moffs.offset),
            else => {
                const mem_op = switch (encoding.op_en) {
                    .m, .mi, .m1, .mc, .mr => inst.op1,
                    .rm, .rmi => inst.op2,
                    else => unreachable,
                };
                switch (mem_op) {
                    .reg => |reg| {
                        const rm = switch (encoding.op_en) {
                            .m, .mi, .m1, .mc => encoding.modRmExt(),
                            .mr => inst.op2.reg.lowEnc(),
                            .rm, .rmi => inst.op1.reg.lowEnc(),
                            else => unreachable,
                        };
                        try encoder.modRm_direct(rm, reg.lowEnc());
                    },
                    .mem => |mem| {
                        const op = switch (encoding.op_en) {
                            .m, .mi, .m1, .mc => .none,
                            .mr => inst.op2,
                            .rm, .rmi => inst.op1,
                            else => unreachable,
                        };
                        try encodeMemory(encoding, mem, op, encoder);
                    },
                    else => unreachable,
                }

                switch (encoding.op_en) {
                    .mi => try encodeImm(inst.op2.imm, encoding.op2, encoder),
                    .rmi => try encodeImm(inst.op3.imm, encoding.op3, encoder),
                    else => {},
                }
            },
        }
    }

    fn encodeOpcode(inst: Instruction, encoder: anytype) !void {
        const opcode = inst.encoding.opcode();
        switch (inst.encoding.op_en) {
            .o, .oi => try encoder.opcode_withReg(opcode[0], inst.op1.reg.lowEnc()),
            else => {
                const index: usize = if (inst.encoding.mandatoryPrefix()) |_| 1 else 0;
                for (opcode[index..]) |byte| {
                    try encoder.opcode_1byte(byte);
                }
            },
        }
    }

    fn encodeLegacyPrefixes(inst: Instruction, encoder: anytype) !void {
        const enc = inst.encoding;
        const op_en = enc.op_en;

        var legacy = LegacyPrefixes{};
        if (enc.mode == .none) {
            const bit_size = enc.operandBitSize();
            if (bit_size == 16) {
                legacy.set16BitOverride();
            }
        }

        const segment_override: ?Register = switch (op_en) {
            .i, .zi, .o, .oi, .d, .np => null,
            .fd => inst.op2.mem.base().?,
            .td => inst.op1.mem.base().?,
            .rm, .rmi => if (inst.op2.isSegmentRegister()) blk: {
                break :blk switch (inst.op2) {
                    .reg => |r| r,
                    .mem => |m| m.base().?,
                    else => unreachable,
                };
            } else null,
            .m, .mi, .m1, .mc, .mr => if (inst.op1.isSegmentRegister()) blk: {
                break :blk switch (inst.op1) {
                    .reg => |r| r,
                    .mem => |m| m.base().?,
                    else => unreachable,
                };
            } else null,
        };
        if (segment_override) |seg| {
            legacy.setSegmentOverride(seg);
        }

        try encoder.legacyPrefixes(legacy);
    }

    fn encodeRexPrefix(inst: Instruction, encoder: anytype) !void {
        const op_en = inst.encoding.op_en;

        var rex = Rex{};
        rex.present = inst.encoding.mode == .rex;
        rex.w = inst.encoding.mode == .long;

        switch (op_en) {
            .np, .i, .zi, .fd, .td, .d => {},
            .o, .oi => {
                rex.b = inst.op1.reg.isExtended();
            },
            .m, .mi, .m1, .mc, .mr, .rm, .rmi => {
                const r_op = switch (op_en) {
                    .rm, .rmi => inst.op1,
                    .mr => inst.op2,
                    else => null,
                };
                if (r_op) |op| {
                    rex.r = op.reg.isExtended();
                }

                const b_x_op = switch (op_en) {
                    .rm, .rmi => inst.op2,
                    .m, .mi, .m1, .mc, .mr => inst.op1,
                    else => unreachable,
                };
                switch (b_x_op) {
                    .reg => |r| {
                        rex.b = r.isExtended();
                    },
                    .mem => |mem| {
                        rex.b = if (mem.base()) |base| base.isExtended() else false;
                        rex.x = if (mem.scaleIndex()) |si| si.index.isExtended() else false;
                    },
                    else => unreachable,
                }
            },
        }

        try encoder.rex(rex);
    }

    fn encodeMandatoryPrefix(inst: Instruction, encoder: anytype) !void {
        const prefix = inst.encoding.mandatoryPrefix() orelse return;
        try encoder.opcode_1byte(prefix);
    }

    fn encodeMemory(encoding: Encoding, mem: Memory, operand: Operand, encoder: anytype) !void {
        const operand_enc = switch (operand) {
            .reg => |reg| reg.lowEnc(),
            .none => encoding.modRmExt(),
            else => unreachable,
        };

        switch (mem) {
            .moffs => unreachable,
            .sib => |sib| {
                if (sib.base) |base| {
                    if (base.class() == .segment) {
                        // TODO audit this wrt SIB
                        try encoder.modRm_SIBDisp0(operand_enc);
                        if (sib.scale_index) |si| {
                            const scale = math.log2_int(u4, si.scale);
                            try encoder.sib_scaleIndexDisp32(scale, si.index.lowEnc());
                        } else {
                            try encoder.sib_disp32();
                        }
                        try encoder.disp32(sib.disp);
                    } else {
                        assert(base.class() == .general_purpose);
                        const dst = base.lowEnc();
                        const src = operand_enc;
                        if (dst == 4 or sib.scale_index != null) {
                            if (sib.disp == 0 and dst != 5) {
                                try encoder.modRm_SIBDisp0(src);
                                if (sib.scale_index) |si| {
                                    const scale = math.log2_int(u4, si.scale);
                                    try encoder.sib_scaleIndexBase(scale, si.index.lowEnc(), dst);
                                } else {
                                    try encoder.sib_base(dst);
                                }
                            } else if (math.cast(i8, sib.disp)) |_| {
                                try encoder.modRm_SIBDisp8(src);
                                if (sib.scale_index) |si| {
                                    const scale = math.log2_int(u4, si.scale);
                                    try encoder.sib_scaleIndexBaseDisp8(scale, si.index.lowEnc(), dst);
                                } else {
                                    try encoder.sib_baseDisp8(dst);
                                }
                                try encoder.disp8(@truncate(i8, sib.disp));
                            } else {
                                try encoder.modRm_SIBDisp32(src);
                                if (sib.scale_index) |si| {
                                    const scale = math.log2_int(u4, si.scale);
                                    try encoder.sib_scaleIndexBaseDisp32(scale, si.index.lowEnc(), dst);
                                } else {
                                    try encoder.sib_baseDisp32(dst);
                                }
                                try encoder.disp32(sib.disp);
                            }
                        } else {
                            if (sib.disp == 0 and dst != 5) {
                                try encoder.modRm_indirectDisp0(src, dst);
                            } else if (math.cast(i8, sib.disp)) |_| {
                                try encoder.modRm_indirectDisp8(src, dst);
                                try encoder.disp8(@truncate(i8, sib.disp));
                            } else {
                                try encoder.modRm_indirectDisp32(src, dst);
                                try encoder.disp32(sib.disp);
                            }
                        }
                    }
                } else {
                    try encoder.modRm_SIBDisp0(operand_enc);
                    if (sib.scale_index) |si| {
                        const scale = math.log2_int(u4, si.scale);
                        try encoder.sib_scaleIndexDisp32(scale, si.index.lowEnc());
                    } else {
                        try encoder.sib_disp32();
                    }
                    try encoder.disp32(sib.disp);
                }
            },
            .rip => |rip| {
                try encoder.modRm_RIPDisp32(operand_enc);
                try encoder.disp32(rip.disp);
            },
        }
    }

    fn encodeImm(imm: Immediate, kind: Encoding.Op, encoder: anytype) !void {
        const raw = imm.asUnsigned(kind.bitSize());
        switch (kind.bitSize()) {
            8 => try encoder.imm8(@intCast(u8, raw)),
            16 => try encoder.imm16(@intCast(u16, raw)),
            32 => try encoder.imm32(@intCast(u32, raw)),
            64 => try encoder.imm64(raw),
            else => unreachable,
        }
    }
};

inline fn sign(i: anytype) @TypeOf(i) {
    return @as(@TypeOf(i), @boolToInt(i > 0)) - @boolToInt(i < 0);
}

pub const LegacyPrefixes = packed struct {
    /// LOCK
    prefix_f0: bool = false,
    /// REPNZ, REPNE, REP, Scalar Double-precision
    prefix_f2: bool = false,
    /// REPZ, REPE, REP, Scalar Single-precision
    prefix_f3: bool = false,

    /// CS segment override or Branch not taken
    prefix_2e: bool = false,
    /// SS segment override
    prefix_36: bool = false,
    /// ES segment override
    prefix_26: bool = false,
    /// FS segment override
    prefix_64: bool = false,
    /// GS segment override
    prefix_65: bool = false,

    /// Branch taken
    prefix_3e: bool = false,

    /// Address size override (enables 16 bit address size)
    prefix_67: bool = false,

    /// Operand size override (enables 16 bit operation)
    prefix_66: bool = false,

    padding: u5 = 0,

    pub fn setSegmentOverride(self: *LegacyPrefixes, reg: Register) void {
        assert(reg.class() == .segment);
        switch (reg) {
            .cs => self.prefix_2e = true,
            .ss => self.prefix_36 = true,
            .es => self.prefix_26 = true,
            .fs => self.prefix_64 = true,
            .gs => self.prefix_65 = true,
            .ds => {},
            else => unreachable,
        }
    }

    pub fn set16BitOverride(self: *LegacyPrefixes) void {
        self.prefix_66 = true;
    }
};

fn Encoder(comptime T: type) type {
    return struct {
        writer: T,

        const Self = @This();

        // --------
        // Prefixes
        // --------

        /// Encodes legacy prefixes
        pub fn legacyPrefixes(self: Self, prefixes: LegacyPrefixes) !void {
            if (@bitCast(u16, prefixes) != 0) {
                // Hopefully this path isn't taken very often, so we'll do it the slow way for now

                // LOCK
                if (prefixes.prefix_f0) try self.writer.writeByte(0xf0);
                // REPNZ, REPNE, REP, Scalar Double-precision
                if (prefixes.prefix_f2) try self.writer.writeByte(0xf2);
                // REPZ, REPE, REP, Scalar Single-precision
                if (prefixes.prefix_f3) try self.writer.writeByte(0xf3);

                // CS segment override or Branch not taken
                if (prefixes.prefix_2e) try self.writer.writeByte(0x2e);
                // DS segment override
                if (prefixes.prefix_36) try self.writer.writeByte(0x36);
                // ES segment override
                if (prefixes.prefix_26) try self.writer.writeByte(0x26);
                // FS segment override
                if (prefixes.prefix_64) try self.writer.writeByte(0x64);
                // GS segment override
                if (prefixes.prefix_65) try self.writer.writeByte(0x65);

                // Branch taken
                if (prefixes.prefix_3e) try self.writer.writeByte(0x3e);

                // Operand size override
                if (prefixes.prefix_66) try self.writer.writeByte(0x66);

                // Address size override
                if (prefixes.prefix_67) try self.writer.writeByte(0x67);
            }
        }

        /// Use 16 bit operand size
        ///
        /// Note that this flag is overridden by REX.W, if both are present.
        pub fn prefix16BitMode(self: Self) !void {
            try self.writer.writeByte(0x66);
        }

        /// Encodes a REX prefix byte given all the fields
        ///
        /// Use this byte whenever you need 64 bit operation,
        /// or one of reg, index, r/m, base, or opcode-reg might be extended.
        ///
        /// See struct `Rex` for a description of each field.
        pub fn rex(self: Self, byte: Rex) !void {
            if (!byte.present and !byte.isSet()) return;

            var value: u8 = 0b0100_0000;

            if (byte.w) value |= 0b1000;
            if (byte.r) value |= 0b0100;
            if (byte.x) value |= 0b0010;
            if (byte.b) value |= 0b0001;

            try self.writer.writeByte(value);
        }

        // ------
        // Opcode
        // ------

        /// Encodes a 1 byte opcode
        pub fn opcode_1byte(self: Self, opcode: u8) !void {
            try self.writer.writeByte(opcode);
        }

        /// Encodes a 2 byte opcode
        ///
        /// e.g. IMUL has the opcode 0x0f 0xaf, so you use
        ///
        /// encoder.opcode_2byte(0x0f, 0xaf);
        pub fn opcode_2byte(self: Self, prefix: u8, opcode: u8) !void {
            try self.writer.writeAll(&.{ prefix, opcode });
        }

        /// Encodes a 3 byte opcode
        ///
        /// e.g. MOVSD has the opcode 0xf2 0x0f 0x10
        ///
        /// encoder.opcode_3byte(0xf2, 0x0f, 0x10);
        pub fn opcode_3byte(self: Self, prefix_1: u8, prefix_2: u8, opcode: u8) !void {
            try self.writer.writeAll(&.{ prefix_1, prefix_2, opcode });
        }

        /// Encodes a 1 byte opcode with a reg field
        ///
        /// Remember to add a REX prefix byte if reg is extended!
        pub fn opcode_withReg(self: Self, opcode: u8, reg: u3) !void {
            assert(opcode & 0b111 == 0);
            try self.writer.writeByte(opcode | reg);
        }

        // ------
        // ModR/M
        // ------

        /// Construct a ModR/M byte given all the fields
        ///
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm(self: Self, mod: u2, reg_or_opx: u3, rm: u3) !void {
            try self.writer.writeByte(@as(u8, mod) << 6 | @as(u8, reg_or_opx) << 3 | rm);
        }

        /// Construct a ModR/M byte using direct r/m addressing
        /// r/m effective address: r/m
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_direct(self: Self, reg_or_opx: u3, rm: u3) !void {
            try self.modRm(0b11, reg_or_opx, rm);
        }

        /// Construct a ModR/M byte using indirect r/m addressing
        /// r/m effective address: [r/m]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_indirectDisp0(self: Self, reg_or_opx: u3, rm: u3) !void {
            assert(rm != 4 and rm != 5);
            try self.modRm(0b00, reg_or_opx, rm);
        }

        /// Construct a ModR/M byte using indirect SIB addressing
        /// r/m effective address: [SIB]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_SIBDisp0(self: Self, reg_or_opx: u3) !void {
            try self.modRm(0b00, reg_or_opx, 0b100);
        }

        /// Construct a ModR/M byte using RIP-relative addressing
        /// r/m effective address: [RIP + disp32]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_RIPDisp32(self: Self, reg_or_opx: u3) !void {
            try self.modRm(0b00, reg_or_opx, 0b101);
        }

        /// Construct a ModR/M byte using indirect r/m with a 8bit displacement
        /// r/m effective address: [r/m + disp8]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_indirectDisp8(self: Self, reg_or_opx: u3, rm: u3) !void {
            assert(rm != 4);
            try self.modRm(0b01, reg_or_opx, rm);
        }

        /// Construct a ModR/M byte using indirect SIB with a 8bit displacement
        /// r/m effective address: [SIB + disp8]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_SIBDisp8(self: Self, reg_or_opx: u3) !void {
            try self.modRm(0b01, reg_or_opx, 0b100);
        }

        /// Construct a ModR/M byte using indirect r/m with a 32bit displacement
        /// r/m effective address: [r/m + disp32]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_indirectDisp32(self: Self, reg_or_opx: u3, rm: u3) !void {
            assert(rm != 4);
            try self.modRm(0b10, reg_or_opx, rm);
        }

        /// Construct a ModR/M byte using indirect SIB with a 32bit displacement
        /// r/m effective address: [SIB + disp32]
        ///
        /// Note reg's effective address is always just reg for the ModR/M byte.
        /// Remember to add a REX prefix byte if reg or rm are extended!
        pub fn modRm_SIBDisp32(self: Self, reg_or_opx: u3) !void {
            try self.modRm(0b10, reg_or_opx, 0b100);
        }

        // ---
        // SIB
        // ---

        /// Construct a SIB byte given all the fields
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib(self: Self, scale: u2, index: u3, base: u3) !void {
            try self.writer.writeByte(@as(u8, scale) << 6 | @as(u8, index) << 3 | base);
        }

        /// Construct a SIB byte with scale * index + base, no frills.
        /// r/m effective address: [base + scale * index]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_scaleIndexBase(self: Self, scale: u2, index: u3, base: u3) !void {
            assert(base != 5);

            try self.sib(scale, index, base);
        }

        /// Construct a SIB byte with scale * index + disp32
        /// r/m effective address: [scale * index + disp32]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_scaleIndexDisp32(self: Self, scale: u2, index: u3) !void {
            // scale is actually ignored
            // index = 4 means no index if and only if we haven't extended the register
            // TODO enforce this
            // base = 5 means no base, if mod == 0.
            try self.sib(scale, index, 5);
        }

        /// Construct a SIB byte with just base
        /// r/m effective address: [base]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_base(self: Self, base: u3) !void {
            assert(base != 5);

            // scale is actually ignored
            // index = 4 means no index
            try self.sib(0, 4, base);
        }

        /// Construct a SIB byte with just disp32
        /// r/m effective address: [disp32]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_disp32(self: Self) !void {
            // scale is actually ignored
            // index = 4 means no index
            // base = 5 means no base, if mod == 0.
            try self.sib(0, 4, 5);
        }

        /// Construct a SIB byte with scale * index + base + disp8
        /// r/m effective address: [base + scale * index + disp8]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_scaleIndexBaseDisp8(self: Self, scale: u2, index: u3, base: u3) !void {
            try self.sib(scale, index, base);
        }

        /// Construct a SIB byte with base + disp8, no index
        /// r/m effective address: [base + disp8]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_baseDisp8(self: Self, base: u3) !void {
            // scale is ignored
            // index = 4 means no index
            try self.sib(0, 4, base);
        }

        /// Construct a SIB byte with scale * index + base + disp32
        /// r/m effective address: [base + scale * index + disp32]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_scaleIndexBaseDisp32(self: Self, scale: u2, index: u3, base: u3) !void {
            try self.sib(scale, index, base);
        }

        /// Construct a SIB byte with base + disp32, no index
        /// r/m effective address: [base + disp32]
        ///
        /// Remember to add a REX prefix byte if index or base are extended!
        pub fn sib_baseDisp32(self: Self, base: u3) !void {
            // scale is ignored
            // index = 4 means no index
            try self.sib(0, 4, base);
        }

        // -------------------------
        // Trivial (no bit fiddling)
        // -------------------------

        /// Encode an 8 bit displacement
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn disp8(self: Self, disp: i8) !void {
            try self.writer.writeByte(@bitCast(u8, disp));
        }

        /// Encode an 32 bit displacement
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn disp32(self: Self, disp: i32) !void {
            try self.writer.writeIntLittle(i32, disp);
        }

        /// Encode an 8 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm8(self: Self, imm: u8) !void {
            try self.writer.writeByte(imm);
        }

        /// Encode an 16 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm16(self: Self, imm: u16) !void {
            try self.writer.writeIntLittle(u16, imm);
        }

        /// Encode an 32 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm32(self: Self, imm: u32) !void {
            try self.writer.writeIntLittle(u32, imm);
        }

        /// Encode an 64 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm64(self: Self, imm: u64) !void {
            try self.writer.writeIntLittle(u64, imm);
        }
    };
}

pub const Rex = struct {
    w: bool = false,
    r: bool = false,
    x: bool = false,
    b: bool = false,
    present: bool = false,

    pub fn isSet(rex: Rex) bool {
        return rex.w or rex.r or rex.x or rex.b;
    }
};
