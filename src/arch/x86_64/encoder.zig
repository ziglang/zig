const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.x86_64_encoder);
const math = std.math;
const testing = std.testing;

const bits = @import("bits.zig");
const Encoding = @import("Encoding.zig");
const FrameIndex = bits.FrameIndex;
const Register = bits.Register;
const Symbol = bits.Symbol;

pub const Instruction = struct {
    prefix: Prefix = .none,
    encoding: Encoding,
    ops: [4]Operand = .{.none} ** 4,

    pub const Mnemonic = Encoding.Mnemonic;

    pub const Prefix = enum(u3) {
        none,
        lock,
        rep,
        repe,
        repz,
        repne,
        repnz,
        directive,
    };

    pub const Immediate = union(enum) {
        signed: i32,
        unsigned: u64,

        pub fn u(x: u64) Immediate {
            return .{ .unsigned = x };
        }

        pub fn s(x: i32) Immediate {
            return .{ .signed = x };
        }

        pub fn asSigned(imm: Immediate, bit_size: u64) i64 {
            return switch (imm) {
                .signed => |x| switch (bit_size) {
                    1, 8 => @as(i8, @intCast(x)),
                    16 => @as(i16, @intCast(x)),
                    32, 64 => x,
                    else => unreachable,
                },
                .unsigned => |x| switch (bit_size) {
                    1, 8 => @as(i8, @bitCast(@as(u8, @intCast(x)))),
                    16 => @as(i16, @bitCast(@as(u16, @intCast(x)))),
                    32 => @as(i32, @bitCast(@as(u32, @intCast(x)))),
                    64 => @bitCast(x),
                    else => unreachable,
                },
            };
        }

        pub fn asUnsigned(imm: Immediate, bit_size: u64) u64 {
            return switch (imm) {
                .signed => |x| switch (bit_size) {
                    1, 8 => @as(u8, @bitCast(@as(i8, @intCast(x)))),
                    16 => @as(u16, @bitCast(@as(i16, @intCast(x)))),
                    32, 64 => @as(u32, @bitCast(x)),
                    else => unreachable,
                },
                .unsigned => |x| switch (bit_size) {
                    1, 8 => @as(u8, @intCast(x)),
                    16 => @as(u16, @intCast(x)),
                    32 => @as(u32, @intCast(x)),
                    64 => x,
                    else => unreachable,
                },
            };
        }
    };

    pub const Memory = union(enum) {
        sib: Sib,
        rip: Rip,
        moffs: Moffs,

        pub const Base = bits.Memory.Base;

        pub const ScaleIndex = struct {
            scale: u4,
            index: Register,

            const none = ScaleIndex{ .scale = 0, .index = undefined };
        };

        pub const PtrSize = bits.Memory.Size;

        pub const Sib = struct {
            ptr_size: PtrSize,
            base: Base,
            scale_index: ScaleIndex,
            disp: i32,
        };

        pub const Rip = struct {
            ptr_size: PtrSize,
            disp: i32,
        };

        pub const Moffs = struct {
            seg: Register,
            offset: u64,
        };

        pub fn initMoffs(reg: Register, offset: u64) Memory {
            assert(reg.class() == .segment);
            return .{ .moffs = .{ .seg = reg, .offset = offset } };
        }

        pub fn initSib(ptr_size: PtrSize, args: struct {
            disp: i32 = 0,
            base: Base = .none,
            scale_index: ?ScaleIndex = null,
        }) Memory {
            if (args.scale_index) |si| assert(std.math.isPowerOfTwo(si.scale));
            return .{ .sib = .{
                .base = args.base,
                .disp = args.disp,
                .ptr_size = ptr_size,
                .scale_index = if (args.scale_index) |si| si else ScaleIndex.none,
            } };
        }

        pub fn initRip(ptr_size: PtrSize, displacement: i32) Memory {
            return .{ .rip = .{ .ptr_size = ptr_size, .disp = displacement } };
        }

        pub fn isSegmentRegister(mem: Memory) bool {
            return switch (mem) {
                .moffs => true,
                .rip => false,
                .sib => |s| switch (s.base) {
                    .none, .frame, .reloc => false,
                    .reg => |reg| reg.class() == .segment,
                },
            };
        }

        pub fn base(mem: Memory) Base {
            return switch (mem) {
                .moffs => |m| .{ .reg = m.seg },
                .sib => |s| s.base,
                .rip => .none,
            };
        }

        pub fn scaleIndex(mem: Memory) ?ScaleIndex {
            return switch (mem) {
                .moffs, .rip => null,
                .sib => |s| if (s.scale_index.scale > 0) s.scale_index else null,
            };
        }

        pub fn disp(mem: Memory) Immediate {
            return switch (mem) {
                .sib => |s| Immediate.s(s.disp),
                .rip => |r| Immediate.s(r.disp),
                .moffs => |m| Immediate.u(m.offset),
            };
        }

        pub fn bitSize(mem: Memory) u64 {
            return switch (mem) {
                .rip => |r| r.ptr_size.bitSize(),
                .sib => |s| s.ptr_size.bitSize(),
                .moffs => 64,
            };
        }
    };

    pub const Operand = union(enum) {
        none,
        reg: Register,
        mem: Memory,
        imm: Immediate,
        bytes: []const u8,

        /// Returns the bitsize of the operand.
        pub fn bitSize(op: Operand) u64 {
            return switch (op) {
                .none => unreachable,
                .reg => |reg| reg.bitSize(),
                .mem => |mem| mem.bitSize(),
                .imm => unreachable,
                .bytes => unreachable,
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
                .bytes => unreachable,
            };
        }

        pub fn isBaseExtended(op: Operand) bool {
            return switch (op) {
                .none, .imm => false,
                .reg => |reg| reg.isExtended(),
                .mem => |mem| mem.base().isExtended(),
                .bytes => unreachable,
            };
        }

        pub fn isIndexExtended(op: Operand) bool {
            return switch (op) {
                .none, .reg, .imm => false,
                .mem => |mem| if (mem.scaleIndex()) |si| si.index.isExtended() else false,
                .bytes => unreachable,
            };
        }

        fn format(
            op: Operand,
            comptime unused_format_string: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = op;
            _ = unused_format_string;
            _ = options;
            _ = writer;
            @compileError("do not format Operand directly; use fmt() instead");
        }

        const FormatContext = struct {
            op: Operand,
            enc_op: Encoding.Op,
        };

        fn fmtContext(
            ctx: FormatContext,
            comptime unused_format_string: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            _ = unused_format_string;
            _ = options;
            const op = ctx.op;
            const enc_op = ctx.enc_op;
            switch (op) {
                .none => {},
                .reg => |reg| try writer.writeAll(@tagName(reg)),
                .mem => |mem| switch (mem) {
                    .rip => |rip| {
                        try writer.print("{} [rip", .{rip.ptr_size});
                        if (rip.disp != 0) try writer.print(" {c} 0x{x}", .{
                            @as(u8, if (rip.disp < 0) '-' else '+'),
                            @abs(rip.disp),
                        });
                        try writer.writeByte(']');
                    },
                    .sib => |sib| {
                        try writer.print("{} ", .{sib.ptr_size});

                        if (mem.isSegmentRegister()) {
                            return writer.print("{s}:0x{x}", .{ @tagName(sib.base.reg), sib.disp });
                        }

                        try writer.writeByte('[');

                        var any = true;
                        switch (sib.base) {
                            .none => any = false,
                            .reg => |reg| try writer.print("{s}", .{@tagName(reg)}),
                            .frame => |frame_index| try writer.print("{}", .{frame_index}),
                            .reloc => |sym_index| try writer.print("Symbol({d})", .{sym_index}),
                        }
                        if (mem.scaleIndex()) |si| {
                            if (any) try writer.writeAll(" + ");
                            try writer.print("{s} * {d}", .{ @tagName(si.index), si.scale });
                            any = true;
                        }
                        if (sib.disp != 0 or !any) {
                            if (any)
                                try writer.print(" {c} ", .{@as(u8, if (sib.disp < 0) '-' else '+')})
                            else if (sib.disp < 0)
                                try writer.writeByte('-');
                            try writer.print("0x{x}", .{@abs(sib.disp)});
                            any = true;
                        }

                        try writer.writeByte(']');
                    },
                    .moffs => |moffs| try writer.print("{s}:0x{x}", .{
                        @tagName(moffs.seg),
                        moffs.offset,
                    }),
                },
                .imm => |imm| if (enc_op.isSigned()) {
                    const imms = imm.asSigned(enc_op.immBitSize());
                    if (imms < 0) try writer.writeByte('-');
                    try writer.print("0x{x}", .{@abs(imms)});
                } else try writer.print("0x{x}", .{imm.asUnsigned(enc_op.immBitSize())}),
                .bytes => unreachable,
            }
        }

        pub fn fmt(op: Operand, enc_op: Encoding.Op) std.fmt.Formatter(fmtContext) {
            return .{ .data = .{ .op = op, .enc_op = enc_op } };
        }
    };

    pub fn new(prefix: Prefix, mnemonic: Mnemonic, ops: []const Operand) !Instruction {
        const encoding: Encoding = switch (prefix) {
            else => (try Encoding.findByMnemonic(prefix, mnemonic, ops)) orelse {
                log.err("no encoding found for: {s} {s} {s} {s} {s} {s}", .{
                    @tagName(prefix),
                    @tagName(mnemonic),
                    @tagName(if (ops.len > 0) Encoding.Op.fromOperand(ops[0]) else .none),
                    @tagName(if (ops.len > 1) Encoding.Op.fromOperand(ops[1]) else .none),
                    @tagName(if (ops.len > 2) Encoding.Op.fromOperand(ops[2]) else .none),
                    @tagName(if (ops.len > 3) Encoding.Op.fromOperand(ops[3]) else .none),
                });
                return error.InvalidInstruction;
            },
            .directive => .{
                .mnemonic = mnemonic,
                .data = .{
                    .op_en = .zo,
                    .ops = .{
                        if (ops.len > 0) Encoding.Op.fromOperand(ops[0]) else .none,
                        if (ops.len > 1) Encoding.Op.fromOperand(ops[1]) else .none,
                        if (ops.len > 2) Encoding.Op.fromOperand(ops[2]) else .none,
                        if (ops.len > 3) Encoding.Op.fromOperand(ops[3]) else .none,
                    },
                    .opc_len = 0,
                    .opc = undefined,
                    .modrm_ext = 0,
                    .mode = .none,
                    .feature = .none,
                },
            },
        };
        log.debug("selected encoding: {}", .{encoding});

        var inst: Instruction = .{
            .prefix = prefix,
            .encoding = encoding,
            .ops = [1]Operand{.none} ** 4,
        };
        @memcpy(inst.ops[0..ops.len], ops);
        return inst;
    }

    pub fn format(
        inst: Instruction,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = unused_format_string;
        _ = options;
        switch (inst.prefix) {
            .none, .directive => {},
            else => try writer.print("{s} ", .{@tagName(inst.prefix)}),
        }
        try writer.print("{s}", .{@tagName(inst.encoding.mnemonic)});
        for (inst.ops, inst.encoding.data.ops, 0..) |op, enc, i| {
            if (op == .none) break;
            if (i > 0) try writer.writeByte(',');
            try writer.writeByte(' ');
            try writer.print("{}", .{op.fmt(enc)});
        }
    }

    pub fn encode(inst: Instruction, writer: anytype, comptime opts: Options) !void {
        assert(inst.prefix != .directive);
        const encoder = Encoder(@TypeOf(writer), opts){ .writer = writer };
        const enc = inst.encoding;
        const data = enc.data;

        if (data.mode.isVex()) {
            try inst.encodeVexPrefix(encoder);
            const opc = inst.encoding.opcode();
            try encoder.opcode_1byte(opc[opc.len - 1]);
        } else {
            try inst.encodeLegacyPrefixes(encoder);
            try inst.encodeMandatoryPrefix(encoder);
            try inst.encodeRexPrefix(encoder);
            try inst.encodeOpcode(encoder);
        }

        switch (data.op_en) {
            .zo, .o => {},
            .i, .d => try encodeImm(inst.ops[0].imm, data.ops[0], encoder),
            .zi, .oi => try encodeImm(inst.ops[1].imm, data.ops[1], encoder),
            .fd => try encoder.imm64(inst.ops[1].mem.moffs.offset),
            .td => try encoder.imm64(inst.ops[0].mem.moffs.offset),
            else => {
                const mem_op = switch (data.op_en) {
                    .m, .mi, .m1, .mc, .mr, .mri, .mrc, .mvr => inst.ops[0],
                    .rm, .rmi, .rm0, .vmi => inst.ops[1],
                    .rvm, .rvmr, .rvmi => inst.ops[2],
                    else => unreachable,
                };
                switch (mem_op) {
                    .reg => |reg| {
                        const rm = switch (data.op_en) {
                            .m, .mi, .m1, .mc, .vmi => enc.modRmExt(),
                            .mr, .mri, .mrc => inst.ops[1].reg.lowEnc(),
                            .rm, .rmi, .rm0, .rvm, .rvmr, .rvmi => inst.ops[0].reg.lowEnc(),
                            .mvr => inst.ops[2].reg.lowEnc(),
                            else => unreachable,
                        };
                        try encoder.modRm_direct(rm, reg.lowEnc());
                    },
                    .mem => |mem| {
                        const op = switch (data.op_en) {
                            .m, .mi, .m1, .mc, .vmi => .none,
                            .mr, .mri, .mrc => inst.ops[1],
                            .rm, .rmi, .rm0, .rvm, .rvmr, .rvmi => inst.ops[0],
                            .mvr => inst.ops[2],
                            else => unreachable,
                        };
                        try encodeMemory(enc, mem, op, encoder);
                    },
                    else => unreachable,
                }

                switch (data.op_en) {
                    .mi => try encodeImm(inst.ops[1].imm, data.ops[1], encoder),
                    .rmi, .mri, .vmi => try encodeImm(inst.ops[2].imm, data.ops[2], encoder),
                    .rvmr => try encoder.imm8(@as(u8, inst.ops[3].reg.enc()) << 4),
                    .rvmi => try encodeImm(inst.ops[3].imm, data.ops[3], encoder),
                    else => {},
                }
            },
        }
    }

    fn encodeOpcode(inst: Instruction, encoder: anytype) !void {
        const opcode = inst.encoding.opcode();
        const first = @intFromBool(inst.encoding.mandatoryPrefix() != null);
        const final = opcode.len - 1;
        for (opcode[first..final]) |byte| try encoder.opcode_1byte(byte);
        switch (inst.encoding.data.op_en) {
            .o, .oi => try encoder.opcode_withReg(opcode[final], inst.ops[0].reg.lowEnc()),
            else => try encoder.opcode_1byte(opcode[final]),
        }
    }

    fn encodeLegacyPrefixes(inst: Instruction, encoder: anytype) !void {
        const enc = inst.encoding;
        const data = enc.data;
        const op_en = data.op_en;

        var legacy = LegacyPrefixes{};

        switch (inst.prefix) {
            .none => {},
            .lock => legacy.prefix_f0 = true,
            .repne, .repnz => legacy.prefix_f2 = true,
            .rep, .repe, .repz => legacy.prefix_f3 = true,
            .directive => unreachable,
        }

        switch (data.mode) {
            .short, .rex_short => legacy.set16BitOverride(),
            else => {},
        }

        const segment_override: ?Register = switch (op_en) {
            .zo, .i, .zi, .o, .oi, .d => null,
            .fd => inst.ops[1].mem.base().reg,
            .td => inst.ops[0].mem.base().reg,
            .rm, .rmi, .rm0 => if (inst.ops[1].isSegmentRegister())
                switch (inst.ops[1]) {
                    .reg => |reg| reg,
                    .mem => |mem| mem.base().reg,
                    else => unreachable,
                }
            else
                null,
            .m, .mi, .m1, .mc, .mr, .mri, .mrc => if (inst.ops[0].isSegmentRegister())
                switch (inst.ops[0]) {
                    .reg => |reg| reg,
                    .mem => |mem| mem.base().reg,
                    else => unreachable,
                }
            else
                null,
            .vmi, .rvm, .rvmr, .rvmi, .mvr => unreachable,
        };
        if (segment_override) |seg| {
            legacy.setSegmentOverride(seg);
        }

        try encoder.legacyPrefixes(legacy);
    }

    fn encodeRexPrefix(inst: Instruction, encoder: anytype) !void {
        const op_en = inst.encoding.data.op_en;

        var rex = Rex{};
        rex.present = inst.encoding.data.mode == .rex;
        rex.w = inst.encoding.data.mode == .long;

        switch (op_en) {
            .zo, .i, .zi, .fd, .td, .d => {},
            .o, .oi => rex.b = inst.ops[0].reg.isExtended(),
            .m, .mi, .m1, .mc, .mr, .rm, .rmi, .mri, .mrc, .rm0 => {
                const r_op = switch (op_en) {
                    .rm, .rmi, .rm0 => inst.ops[0],
                    .mr, .mri, .mrc => inst.ops[1],
                    else => .none,
                };
                rex.r = r_op.isBaseExtended();

                const b_x_op = switch (op_en) {
                    .rm, .rmi, .rm0 => inst.ops[1],
                    .m, .mi, .m1, .mc, .mr, .mri, .mrc => inst.ops[0],
                    else => unreachable,
                };
                rex.b = b_x_op.isBaseExtended();
                rex.x = b_x_op.isIndexExtended();
            },
            .vmi, .rvm, .rvmr, .rvmi, .mvr => unreachable,
        }

        try encoder.rex(rex);
    }

    fn encodeVexPrefix(inst: Instruction, encoder: anytype) !void {
        const op_en = inst.encoding.data.op_en;
        const opc = inst.encoding.opcode();
        const mand_pre = inst.encoding.mandatoryPrefix();

        var vex = Vex{};

        vex.w = inst.encoding.data.mode.isLong();

        switch (op_en) {
            .zo, .i, .zi, .fd, .td, .d => {},
            .o, .oi => vex.b = inst.ops[0].reg.isExtended(),
            .m, .mi, .m1, .mc, .mr, .rm, .rmi, .mri, .mrc, .rm0, .vmi, .rvm, .rvmr, .rvmi, .mvr => {
                const r_op = switch (op_en) {
                    .rm, .rmi, .rm0, .rvm, .rvmr, .rvmi => inst.ops[0],
                    .mr, .mri, .mrc => inst.ops[1],
                    .mvr => inst.ops[2],
                    .m, .mi, .m1, .mc, .vmi => .none,
                    else => unreachable,
                };
                vex.r = r_op.isBaseExtended();

                const b_x_op = switch (op_en) {
                    .rm, .rmi, .rm0, .vmi => inst.ops[1],
                    .m, .mi, .m1, .mc, .mr, .mri, .mrc, .mvr => inst.ops[0],
                    .rvm, .rvmr, .rvmi => inst.ops[2],
                    else => unreachable,
                };
                vex.b = b_x_op.isBaseExtended();
                vex.x = b_x_op.isIndexExtended();
            },
        }

        vex.l = inst.encoding.data.mode.isVecLong();

        vex.p = if (mand_pre) |mand| switch (mand) {
            0x66 => .@"66",
            0xf2 => .f2,
            0xf3 => .f3,
            else => unreachable,
        } else .none;

        const leading: usize = if (mand_pre) |_| 1 else 0;
        assert(opc[leading] == 0x0f);
        vex.m = switch (opc[leading + 1]) {
            else => .@"0f",
            0x38 => .@"0f38",
            0x3a => .@"0f3a",
        };

        switch (op_en) {
            else => {},
            .vmi => vex.v = inst.ops[0].reg,
            .rvm, .rvmr, .rvmi => vex.v = inst.ops[1].reg,
        }

        try encoder.vex(vex);
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
            .sib => |sib| switch (sib.base) {
                .none => {
                    try encoder.modRm_SIBDisp0(operand_enc);
                    if (mem.scaleIndex()) |si| {
                        const scale = math.log2_int(u4, si.scale);
                        try encoder.sib_scaleIndexDisp32(scale, si.index.lowEnc());
                    } else {
                        try encoder.sib_disp32();
                    }
                    try encoder.disp32(sib.disp);
                },
                .reg => |base| switch (base.class()) {
                    .segment => {
                        // TODO audit this wrt SIB
                        try encoder.modRm_SIBDisp0(operand_enc);
                        if (mem.scaleIndex()) |si| {
                            const scale = math.log2_int(u4, si.scale);
                            try encoder.sib_scaleIndexDisp32(scale, si.index.lowEnc());
                        } else {
                            try encoder.sib_disp32();
                        }
                        try encoder.disp32(sib.disp);
                    },
                    .general_purpose => {
                        const dst = base.lowEnc();
                        const src = operand_enc;
                        if (dst == 4 or mem.scaleIndex() != null) {
                            if (sib.disp == 0 and dst != 5) {
                                try encoder.modRm_SIBDisp0(src);
                                if (mem.scaleIndex()) |si| {
                                    const scale = math.log2_int(u4, si.scale);
                                    try encoder.sib_scaleIndexBase(scale, si.index.lowEnc(), dst);
                                } else {
                                    try encoder.sib_base(dst);
                                }
                            } else if (math.cast(i8, sib.disp)) |_| {
                                try encoder.modRm_SIBDisp8(src);
                                if (mem.scaleIndex()) |si| {
                                    const scale = math.log2_int(u4, si.scale);
                                    try encoder.sib_scaleIndexBaseDisp8(scale, si.index.lowEnc(), dst);
                                } else {
                                    try encoder.sib_baseDisp8(dst);
                                }
                                try encoder.disp8(@as(i8, @truncate(sib.disp)));
                            } else {
                                try encoder.modRm_SIBDisp32(src);
                                if (mem.scaleIndex()) |si| {
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
                                try encoder.disp8(@as(i8, @truncate(sib.disp)));
                            } else {
                                try encoder.modRm_indirectDisp32(src, dst);
                                try encoder.disp32(sib.disp);
                            }
                        }
                    },
                    else => unreachable,
                },
                .frame => if (@TypeOf(encoder).options.allow_frame_locs) {
                    try encoder.modRm_indirectDisp32(operand_enc, undefined);
                    try encoder.disp32(undefined);
                } else return error.CannotEncode,
                .reloc => if (@TypeOf(encoder).options.allow_symbols) {
                    try encoder.modRm_indirectDisp32(operand_enc, undefined);
                    try encoder.disp32(undefined);
                } else return error.CannotEncode,
            },
            .rip => |rip| {
                try encoder.modRm_RIPDisp32(operand_enc);
                try encoder.disp32(rip.disp);
            },
        }
    }

    fn encodeImm(imm: Immediate, kind: Encoding.Op, encoder: anytype) !void {
        const raw = imm.asUnsigned(kind.immBitSize());
        switch (kind.immBitSize()) {
            8 => try encoder.imm8(@as(u8, @intCast(raw))),
            16 => try encoder.imm16(@as(u16, @intCast(raw))),
            32 => try encoder.imm32(@as(u32, @intCast(raw))),
            64 => try encoder.imm64(raw),
            else => unreachable,
        }
    }
};

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

pub const Options = struct { allow_frame_locs: bool = false, allow_symbols: bool = false };

fn Encoder(comptime T: type, comptime opts: Options) type {
    return struct {
        writer: T,

        const Self = @This();
        pub const options = opts;

        // --------
        // Prefixes
        // --------

        /// Encodes legacy prefixes
        pub fn legacyPrefixes(self: Self, prefixes: LegacyPrefixes) !void {
            if (@as(u16, @bitCast(prefixes)) != 0) {
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
        pub fn rex(self: Self, fields: Rex) !void {
            if (!fields.present and !fields.isSet()) return;

            var byte: u8 = 0b0100_0000;

            if (fields.w) byte |= 0b1000;
            if (fields.r) byte |= 0b0100;
            if (fields.x) byte |= 0b0010;
            if (fields.b) byte |= 0b0001;

            try self.writer.writeByte(byte);
        }

        /// Encodes a VEX prefix given all the fields
        ///
        /// See struct `Vex` for a description of each field.
        pub fn vex(self: Self, fields: Vex) !void {
            if (fields.is3Byte()) {
                try self.writer.writeByte(0b1100_0100);

                try self.writer.writeByte(
                    @as(u8, ~@intFromBool(fields.r)) << 7 |
                        @as(u8, ~@intFromBool(fields.x)) << 6 |
                        @as(u8, ~@intFromBool(fields.b)) << 5 |
                        @as(u8, @intFromEnum(fields.m)) << 0,
                );

                try self.writer.writeByte(
                    @as(u8, @intFromBool(fields.w)) << 7 |
                        @as(u8, ~fields.v.enc()) << 3 |
                        @as(u8, @intFromBool(fields.l)) << 2 |
                        @as(u8, @intFromEnum(fields.p)) << 0,
                );
            } else {
                try self.writer.writeByte(0b1100_0101);
                try self.writer.writeByte(
                    @as(u8, ~@intFromBool(fields.r)) << 7 |
                        @as(u8, ~fields.v.enc()) << 3 |
                        @as(u8, @intFromBool(fields.l)) << 2 |
                        @as(u8, @intFromEnum(fields.p)) << 0,
                );
            }
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
            try self.writer.writeByte(@as(u8, @bitCast(disp)));
        }

        /// Encode an 32 bit displacement
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn disp32(self: Self, disp: i32) !void {
            try self.writer.writeInt(i32, disp, .little);
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
            try self.writer.writeInt(u16, imm, .little);
        }

        /// Encode an 32 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm32(self: Self, imm: u32) !void {
            try self.writer.writeInt(u32, imm, .little);
        }

        /// Encode an 64 bit immediate
        ///
        /// It is sign-extended to 64 bits by the cpu.
        pub fn imm64(self: Self, imm: u64) !void {
            try self.writer.writeInt(u64, imm, .little);
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

pub const Vex = struct {
    w: bool = false,
    r: bool = false,
    x: bool = false,
    b: bool = false,
    l: bool = false,
    p: enum(u2) {
        none = 0b00,
        @"66" = 0b01,
        f3 = 0b10,
        f2 = 0b11,
    } = .none,
    m: enum(u5) {
        @"0f" = 0b0_0001,
        @"0f38" = 0b0_0010,
        @"0f3a" = 0b0_0011,
        _,
    } = .@"0f",
    v: Register = .ymm0,

    pub fn is3Byte(vex: Vex) bool {
        return vex.w or vex.x or vex.b or vex.m != .@"0f";
    }
};

// Tests
fn expectEqualHexStrings(expected: []const u8, given: []const u8, assembly: []const u8) !void {
    assert(expected.len > 0);
    if (std.mem.eql(u8, expected, given)) return;
    const expected_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(expected)});
    defer testing.allocator.free(expected_fmt);
    const given_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(given)});
    defer testing.allocator.free(given_fmt);
    const idx = std.mem.indexOfDiff(u8, expected_fmt, given_fmt).?;
    const padding = try testing.allocator.alloc(u8, idx + 5);
    defer testing.allocator.free(padding);
    @memset(padding, ' ');
    std.debug.print("\nASM: {s}\nEXP: {s}\nGIV: {s}\n{s}^ -- first differing byte\n", .{
        assembly,
        expected_fmt,
        given_fmt,
        padding,
    });
    return error.TestFailed;
}

const TestEncode = struct {
    buffer: [32]u8 = undefined,
    index: usize = 0,

    fn encode(
        enc: *TestEncode,
        mnemonic: Instruction.Mnemonic,
        ops: []const Instruction.Operand,
    ) !void {
        var stream = std.io.fixedBufferStream(&enc.buffer);
        var count_writer = std.io.countingWriter(stream.writer());
        const inst = try Instruction.new(.none, mnemonic, ops);
        try inst.encode(count_writer.writer(), .{});
        enc.index = count_writer.bytes_written;
    }

    fn code(enc: TestEncode) []const u8 {
        return enc.buffer[0..enc.index];
    }
};

test "encode" {
    var buf = std.ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    const inst = try Instruction.new(.none, .mov, &.{
        .{ .reg = .rbx },
        .{ .imm = Instruction.Immediate.u(4) },
    });
    try inst.encode(buf.writer(), .{});
    try testing.expectEqualSlices(u8, &.{ 0x48, 0xc7, 0xc3, 0x4, 0x0, 0x0, 0x0 }, buf.items);
}

test "lower I encoding" {
    var enc = TestEncode{};

    try enc.encode(.push, &.{
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x6A\x10", enc.code(), "push 0x10");

    try enc.encode(.push, &.{
        .{ .imm = Instruction.Immediate.u(0x1000) },
    });
    try expectEqualHexStrings("\x66\x68\x00\x10", enc.code(), "push 0x1000");

    try enc.encode(.push, &.{
        .{ .imm = Instruction.Immediate.u(0x10000000) },
    });
    try expectEqualHexStrings("\x68\x00\x00\x00\x10", enc.code(), "push 0x10000000");

    try enc.encode(.adc, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x10000000) },
    });
    try expectEqualHexStrings("\x48\x15\x00\x00\x00\x10", enc.code(), "adc rax, 0x10000000");

    try enc.encode(.add, &.{
        .{ .reg = .al },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x04\x10", enc.code(), "add al, 0x10");

    try enc.encode(.add, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\x83\xC0\x10", enc.code(), "add rax, 0x10");

    try enc.encode(.sbb, &.{
        .{ .reg = .ax },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x66\x1D\x10\x00", enc.code(), "sbb ax, 0x10");

    try enc.encode(.xor, &.{
        .{ .reg = .al },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x34\x10", enc.code(), "xor al, 0x10");
}

test "lower MI encoding" {
    var enc = TestEncode{};

    try enc.encode(.mov, &.{
        .{ .reg = .r12 },
        .{ .imm = Instruction.Immediate.u(0x1000) },
    });
    try expectEqualHexStrings("\x49\xC7\xC4\x00\x10\x00\x00", enc.code(), "mov r12, 0x1000");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .r12 } }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x41\xC6\x04\x24\x10", enc.code(), "mov BYTE PTR [r12], 0x10");

    try enc.encode(.mov, &.{
        .{ .reg = .r12 },
        .{ .imm = Instruction.Immediate.u(0x1000) },
    });
    try expectEqualHexStrings("\x49\xC7\xC4\x00\x10\x00\x00", enc.code(), "mov r12, 0x1000");

    try enc.encode(.mov, &.{
        .{ .reg = .r12 },
        .{ .imm = Instruction.Immediate.u(0x1000) },
    });
    try expectEqualHexStrings("\x49\xC7\xC4\x00\x10\x00\x00", enc.code(), "mov r12, 0x1000");

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\xc7\xc0\x10\x00\x00\x00", enc.code(), "mov rax, 0x10");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .r11 } }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x41\xc7\x03\x10\x00\x00\x00", enc.code(), "mov DWORD PTR [r11], 0x10");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initRip(.qword, 0x10) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x48\xC7\x05\x10\x00\x00\x00\x10\x00\x00\x00",
        enc.code(),
        "mov QWORD PTR [rip + 0x10], 0x10",
    );

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .rbp }, .disp = -8 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\xc7\x45\xf8\x10\x00\x00\x00", enc.code(), "mov QWORD PTR [rbp - 8], 0x10");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp }, .disp = -2 }) },
        .{ .imm = Instruction.Immediate.s(-16) },
    });
    try expectEqualHexStrings("\x66\xC7\x45\xFE\xF0\xFF", enc.code(), "mov WORD PTR [rbp - 2], -16");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .rbp }, .disp = -1 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\xC6\x45\xFF\x10", enc.code(), "mov BYTE PTR [rbp - 1], 0x10");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .{ .reg = .ds },
            .disp = 0x10000000,
            .scale_index = .{ .scale = 2, .index = .rcx },
        }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x48\xC7\x04\x4D\x00\x00\x00\x10\x10\x00\x00\x00",
        enc.code(),
        "mov QWORD PTR [rcx*2 + 0x10000000], 0x10",
    );

    try enc.encode(.adc, &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .rbp }, .disp = -0x10 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x80\x55\xF0\x10", enc.code(), "adc BYTE PTR [rbp - 0x10], 0x10");

    try enc.encode(.adc, &.{
        .{ .mem = Instruction.Memory.initRip(.qword, 0) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\x83\x15\x00\x00\x00\x00\x10", enc.code(), "adc QWORD PTR [rip], 0x10");

    try enc.encode(.adc, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\x83\xD0\x10", enc.code(), "adc rax, 0x10");

    try enc.encode(.add, &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .rdx }, .disp = -8 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x83\x42\xF8\x10", enc.code(), "add DWORD PTR [rdx - 8], 0x10");

    try enc.encode(.add, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x48\x83\xC0\x10", enc.code(), "add rax, 0x10");

    try enc.encode(.add, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .rbp }, .disp = -0x10 }) },
        .{ .imm = Instruction.Immediate.s(-0x10) },
    });
    try expectEqualHexStrings("\x48\x83\x45\xF0\xF0", enc.code(), "add QWORD PTR [rbp - 0x10], -0x10");

    try enc.encode(.@"and", &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .ds }, .disp = 0x10000000 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x83\x24\x25\x00\x00\x00\x10\x10",
        enc.code(),
        "and DWORD PTR ds:0x10000000, 0x10",
    );

    try enc.encode(.@"and", &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .es }, .disp = 0x10000000 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x26\x83\x24\x25\x00\x00\x00\x10\x10",
        enc.code(),
        "and DWORD PTR es:0x10000000, 0x10",
    );

    try enc.encode(.@"and", &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .r12 }, .disp = 0x10000000 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x41\x83\xA4\x24\x00\x00\x00\x10\x10",
        enc.code(),
        "and DWORD PTR [r12 + 0x10000000], 0x10",
    );

    try enc.encode(.sub, &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .r11 }, .disp = 0x10000000 }) },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings(
        "\x41\x83\xAB\x00\x00\x00\x10\x10",
        enc.code(),
        "sub DWORD PTR [r11 + 0x10000000], 0x10",
    );
}

test "lower RM encoding" {
    var enc = TestEncode{};

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .r11 } }) },
    });
    try expectEqualHexStrings("\x49\x8b\x03", enc.code(), "mov rax, QWORD PTR [r11]");

    try enc.encode(.mov, &.{
        .{ .reg = .rbx },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .ds }, .disp = 0x10 }) },
    });
    try expectEqualHexStrings("\x48\x8B\x1C\x25\x10\x00\x00\x00", enc.code(), "mov rbx, QWORD PTR ds:0x10");

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .rbp }, .disp = -4 }) },
    });
    try expectEqualHexStrings("\x48\x8B\x45\xFC", enc.code(), "mov rax, QWORD PTR [rbp - 4]");

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .{ .reg = .rbp },
            .scale_index = .{ .scale = 1, .index = .rcx },
            .disp = -8,
        }) },
    });
    try expectEqualHexStrings("\x48\x8B\x44\x0D\xF8", enc.code(), "mov rax, QWORD PTR [rbp + rcx*1 - 8]");

    try enc.encode(.mov, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initSib(.dword, .{
            .base = .{ .reg = .rbp },
            .scale_index = .{ .scale = 4, .index = .rdx },
            .disp = -4,
        }) },
    });
    try expectEqualHexStrings("\x8B\x44\x95\xFC", enc.code(), "mov eax, dword ptr [rbp + rdx*4 - 4]");

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .{ .reg = .rbp },
            .scale_index = .{ .scale = 8, .index = .rcx },
            .disp = -8,
        }) },
    });
    try expectEqualHexStrings("\x48\x8B\x44\xCD\xF8", enc.code(), "mov rax, QWORD PTR [rbp + rcx*8 - 8]");

    try enc.encode(.mov, &.{
        .{ .reg = .r8b },
        .{ .mem = Instruction.Memory.initSib(.byte, .{
            .base = .{ .reg = .rsi },
            .scale_index = .{ .scale = 1, .index = .rcx },
            .disp = -24,
        }) },
    });
    try expectEqualHexStrings("\x44\x8A\x44\x0E\xE8", enc.code(), "mov r8b, BYTE PTR [rsi + rcx*1 - 24]");

    // TODO this mnemonic needs cleanup as some prefixes are obsolete.
    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .reg = .cs },
    });
    try expectEqualHexStrings("\x48\x8C\xC8", enc.code(), "mov rax, cs");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp }, .disp = -16 }) },
        .{ .reg = .fs },
    });
    try expectEqualHexStrings("\x8C\x65\xF0", enc.code(), "mov WORD PTR [rbp - 16], fs");

    try enc.encode(.mov, &.{
        .{ .reg = .r12w },
        .{ .reg = .cs },
    });
    try expectEqualHexStrings("\x66\x41\x8C\xCC", enc.code(), "mov r12w, cs");

    try enc.encode(.movsx, &.{
        .{ .reg = .eax },
        .{ .reg = .bx },
    });
    try expectEqualHexStrings("\x0F\xBF\xC3", enc.code(), "movsx eax, bx");

    try enc.encode(.movsx, &.{
        .{ .reg = .eax },
        .{ .reg = .bl },
    });
    try expectEqualHexStrings("\x0F\xBE\xC3", enc.code(), "movsx eax, bl");

    try enc.encode(.movsx, &.{
        .{ .reg = .ax },
        .{ .reg = .bl },
    });
    try expectEqualHexStrings("\x66\x0F\xBE\xC3", enc.code(), "movsx ax, bl");

    try enc.encode(.movsx, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp } }) },
    });
    try expectEqualHexStrings("\x0F\xBF\x45\x00", enc.code(), "movsx eax, BYTE PTR [rbp]");

    try enc.encode(.movsx, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .scale_index = .{ .index = .rax, .scale = 2 } }) },
    });
    try expectEqualHexStrings("\x0F\xBE\x04\x45\x00\x00\x00\x00", enc.code(), "movsx eax, BYTE PTR [rax * 2]");

    try enc.encode(.movsx, &.{
        .{ .reg = .ax },
        .{ .mem = Instruction.Memory.initRip(.byte, 0x10) },
    });
    try expectEqualHexStrings("\x66\x0F\xBE\x05\x10\x00\x00\x00", enc.code(), "movsx ax, BYTE PTR [rip + 0x10]");

    try enc.encode(.movsx, &.{
        .{ .reg = .rax },
        .{ .reg = .bx },
    });
    try expectEqualHexStrings("\x48\x0F\xBF\xC3", enc.code(), "movsx rax, bx");

    try enc.encode(.movsxd, &.{
        .{ .reg = .rax },
        .{ .reg = .ebx },
    });
    try expectEqualHexStrings("\x48\x63\xC3", enc.code(), "movsxd rax, ebx");

    try enc.encode(.lea, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initRip(.qword, 0x10) },
    });
    try expectEqualHexStrings("\x48\x8D\x05\x10\x00\x00\x00", enc.code(), "lea rax, QWORD PTR [rip + 0x10]");

    try enc.encode(.lea, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initRip(.dword, 0x10) },
    });
    try expectEqualHexStrings("\x48\x8D\x05\x10\x00\x00\x00", enc.code(), "lea rax, DWORD PTR [rip + 0x10]");

    try enc.encode(.lea, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initRip(.dword, 0x10) },
    });
    try expectEqualHexStrings("\x8D\x05\x10\x00\x00\x00", enc.code(), "lea eax, DWORD PTR [rip + 0x10]");

    try enc.encode(.lea, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initRip(.word, 0x10) },
    });
    try expectEqualHexStrings("\x8D\x05\x10\x00\x00\x00", enc.code(), "lea eax, WORD PTR [rip + 0x10]");

    try enc.encode(.lea, &.{
        .{ .reg = .ax },
        .{ .mem = Instruction.Memory.initRip(.byte, 0x10) },
    });
    try expectEqualHexStrings("\x66\x8D\x05\x10\x00\x00\x00", enc.code(), "lea ax, BYTE PTR [rip + 0x10]");

    try enc.encode(.lea, &.{
        .{ .reg = .rsi },
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .{ .reg = .rbp },
            .scale_index = .{ .scale = 1, .index = .rcx },
        }) },
    });
    try expectEqualHexStrings("\x48\x8D\x74\x0D\x00", enc.code(), "lea rsi, QWORD PTR [rbp + rcx*1 + 0]");

    try enc.encode(.add, &.{
        .{ .reg = .r11 },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .ds }, .disp = 0x10000000 }) },
    });
    try expectEqualHexStrings("\x4C\x03\x1C\x25\x00\x00\x00\x10", enc.code(), "add r11, QWORD PTR ds:0x10000000");

    try enc.encode(.add, &.{
        .{ .reg = .r12b },
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .ds }, .disp = 0x10000000 }) },
    });
    try expectEqualHexStrings("\x44\x02\x24\x25\x00\x00\x00\x10", enc.code(), "add r11b, BYTE PTR ds:0x10000000");

    try enc.encode(.add, &.{
        .{ .reg = .r12b },
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .fs }, .disp = 0x10000000 }) },
    });
    try expectEqualHexStrings("\x64\x44\x02\x24\x25\x00\x00\x00\x10", enc.code(), "add r11b, BYTE PTR fs:0x10000000");

    try enc.encode(.sub, &.{
        .{ .reg = .r11 },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .r13 }, .disp = 0x10000000 }) },
    });
    try expectEqualHexStrings("\x4D\x2B\x9D\x00\x00\x00\x10", enc.code(), "sub r11, QWORD PTR [r13 + 0x10000000]");

    try enc.encode(.sub, &.{
        .{ .reg = .r11 },
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .r12 }, .disp = 0x10000000 }) },
    });
    try expectEqualHexStrings("\x4D\x2B\x9C\x24\x00\x00\x00\x10", enc.code(), "sub r11, QWORD PTR [r12 + 0x10000000]");

    try enc.encode(.imul, &.{
        .{ .reg = .r11 },
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x4D\x0F\xAF\xDC", enc.code(), "mov r11, r12");
}

test "lower RMI encoding" {
    var enc = TestEncode{};

    try enc.encode(.imul, &.{
        .{ .reg = .r11 },
        .{ .reg = .r12 },
        .{ .imm = Instruction.Immediate.s(-2) },
    });
    try expectEqualHexStrings("\x4D\x6B\xDC\xFE", enc.code(), "imul r11, r12, -2");

    try enc.encode(.imul, &.{
        .{ .reg = .r11 },
        .{ .mem = Instruction.Memory.initRip(.qword, -16) },
        .{ .imm = Instruction.Immediate.s(-1024) },
    });
    try expectEqualHexStrings(
        "\x4C\x69\x1D\xF0\xFF\xFF\xFF\x00\xFC\xFF\xFF",
        enc.code(),
        "imul r11, QWORD PTR [rip - 16], -1024",
    );

    try enc.encode(.imul, &.{
        .{ .reg = .bx },
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp }, .disp = -16 }) },
        .{ .imm = Instruction.Immediate.s(-1024) },
    });
    try expectEqualHexStrings(
        "\x66\x69\x5D\xF0\x00\xFC",
        enc.code(),
        "imul bx, WORD PTR [rbp - 16], -1024",
    );

    try enc.encode(.imul, &.{
        .{ .reg = .bx },
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp }, .disp = -16 }) },
        .{ .imm = Instruction.Immediate.u(1024) },
    });
    try expectEqualHexStrings(
        "\x66\x69\x5D\xF0\x00\x04",
        enc.code(),
        "imul bx, WORD PTR [rbp - 16], 1024",
    );
}

test "lower MR encoding" {
    var enc = TestEncode{};

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .reg = .rbx },
    });
    try expectEqualHexStrings("\x48\x89\xD8", enc.code(), "mov rax, rbx");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .rbp }, .disp = -4 }) },
        .{ .reg = .r11 },
    });
    try expectEqualHexStrings("\x4c\x89\x5d\xfc", enc.code(), "mov QWORD PTR [rbp - 4], r11");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initRip(.qword, 0x10) },
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x4C\x89\x25\x10\x00\x00\x00", enc.code(), "mov QWORD PTR [rip + 0x10], r12");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .{ .reg = .r11 },
            .scale_index = .{ .scale = 2, .index = .r12 },
            .disp = 0x10,
        }) },
        .{ .reg = .r13 },
    });
    try expectEqualHexStrings("\x4F\x89\x6C\x63\x10", enc.code(), "mov QWORD PTR [r11 + 2 * r12 + 0x10], r13");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initRip(.word, -0x10) },
        .{ .reg = .r12w },
    });
    try expectEqualHexStrings("\x66\x44\x89\x25\xF0\xFF\xFF\xFF", enc.code(), "mov WORD PTR [rip - 0x10], r12w");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{
            .base = .{ .reg = .r11 },
            .scale_index = .{ .scale = 2, .index = .r12 },
            .disp = 0x10,
        }) },
        .{ .reg = .r13b },
    });
    try expectEqualHexStrings("\x47\x88\x6C\x63\x10", enc.code(), "mov BYTE PTR [r11 + 2 * r12 + 0x10], r13b");

    try enc.encode(.add, &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .ds }, .disp = 0x10000000 }) },
        .{ .reg = .r12b },
    });
    try expectEqualHexStrings("\x44\x00\x24\x25\x00\x00\x00\x10", enc.code(), "add BYTE PTR ds:0x10000000, r12b");

    try enc.encode(.add, &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .ds }, .disp = 0x10000000 }) },
        .{ .reg = .r12d },
    });
    try expectEqualHexStrings("\x44\x01\x24\x25\x00\x00\x00\x10", enc.code(), "add DWORD PTR [ds:0x10000000], r12d");

    try enc.encode(.add, &.{
        .{ .mem = Instruction.Memory.initSib(.dword, .{ .base = .{ .reg = .gs }, .disp = 0x10000000 }) },
        .{ .reg = .r12d },
    });
    try expectEqualHexStrings("\x65\x44\x01\x24\x25\x00\x00\x00\x10", enc.code(), "add DWORD PTR [gs:0x10000000], r12d");

    try enc.encode(.sub, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .r11 }, .disp = 0x10000000 }) },
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x4D\x29\xA3\x00\x00\x00\x10", enc.code(), "sub QWORD PTR [r11 + 0x10000000], r12");
}

test "lower M encoding" {
    var enc = TestEncode{};

    try enc.encode(.call, &.{
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x41\xFF\xD4", enc.code(), "call r12");

    try enc.encode(.call, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .r12 } }) },
    });
    try expectEqualHexStrings("\x41\xFF\x14\x24", enc.code(), "call QWORD PTR [r12]");

    try enc.encode(.call, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .none,
            .scale_index = .{ .index = .r11, .scale = 2 },
        }) },
    });
    try expectEqualHexStrings("\x42\xFF\x14\x5D\x00\x00\x00\x00", enc.code(), "call QWORD PTR [r11 * 2]");

    try enc.encode(.call, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{
            .base = .none,
            .scale_index = .{ .index = .r12, .scale = 2 },
        }) },
    });
    try expectEqualHexStrings("\x42\xFF\x14\x65\x00\x00\x00\x00", enc.code(), "call QWORD PTR [r12 * 2]");

    try enc.encode(.call, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .gs } }) },
    });
    try expectEqualHexStrings("\x65\xFF\x14\x25\x00\x00\x00\x00", enc.code(), "call gs:0x0");

    try enc.encode(.call, &.{
        .{ .imm = Instruction.Immediate.s(0) },
    });
    try expectEqualHexStrings("\xE8\x00\x00\x00\x00", enc.code(), "call 0x0");

    try enc.encode(.push, &.{
        .{ .mem = Instruction.Memory.initSib(.qword, .{ .base = .{ .reg = .rbp } }) },
    });
    try expectEqualHexStrings("\xFF\x75\x00", enc.code(), "push QWORD PTR [rbp]");

    try enc.encode(.push, &.{
        .{ .mem = Instruction.Memory.initSib(.word, .{ .base = .{ .reg = .rbp } }) },
    });
    try expectEqualHexStrings("\x66\xFF\x75\x00", enc.code(), "push QWORD PTR [rbp]");

    try enc.encode(.pop, &.{
        .{ .mem = Instruction.Memory.initRip(.qword, 0) },
    });
    try expectEqualHexStrings("\x8F\x05\x00\x00\x00\x00", enc.code(), "pop QWORD PTR [rip]");

    try enc.encode(.pop, &.{
        .{ .mem = Instruction.Memory.initRip(.word, 0) },
    });
    try expectEqualHexStrings("\x66\x8F\x05\x00\x00\x00\x00", enc.code(), "pop WORD PTR [rbp]");

    try enc.encode(.imul, &.{
        .{ .reg = .rax },
    });
    try expectEqualHexStrings("\x48\xF7\xE8", enc.code(), "imul rax");

    try enc.encode(.imul, &.{
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x49\xF7\xEC", enc.code(), "imul r12");
}

test "lower O encoding" {
    var enc = TestEncode{};

    try enc.encode(.push, &.{
        .{ .reg = .rax },
    });
    try expectEqualHexStrings("\x50", enc.code(), "push rax");

    try enc.encode(.push, &.{
        .{ .reg = .r12w },
    });
    try expectEqualHexStrings("\x66\x41\x54", enc.code(), "push r12w");

    try enc.encode(.pop, &.{
        .{ .reg = .r12 },
    });
    try expectEqualHexStrings("\x41\x5c", enc.code(), "pop r12");
}

test "lower OI encoding" {
    var enc = TestEncode{};

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .imm = Instruction.Immediate.u(0x1000000000000000) },
    });
    try expectEqualHexStrings(
        "\x48\xB8\x00\x00\x00\x00\x00\x00\x00\x10",
        enc.code(),
        "movabs rax, 0x1000000000000000",
    );

    try enc.encode(.mov, &.{
        .{ .reg = .r11 },
        .{ .imm = Instruction.Immediate.u(0x1000000000000000) },
    });
    try expectEqualHexStrings(
        "\x49\xBB\x00\x00\x00\x00\x00\x00\x00\x10",
        enc.code(),
        "movabs r11, 0x1000000000000000",
    );

    try enc.encode(.mov, &.{
        .{ .reg = .r11d },
        .{ .imm = Instruction.Immediate.u(0x10000000) },
    });
    try expectEqualHexStrings("\x41\xBB\x00\x00\x00\x10", enc.code(), "mov r11d, 0x10000000");

    try enc.encode(.mov, &.{
        .{ .reg = .r11w },
        .{ .imm = Instruction.Immediate.u(0x1000) },
    });
    try expectEqualHexStrings("\x66\x41\xBB\x00\x10", enc.code(), "mov r11w, 0x1000");

    try enc.encode(.mov, &.{
        .{ .reg = .r11b },
        .{ .imm = Instruction.Immediate.u(0x10) },
    });
    try expectEqualHexStrings("\x41\xB3\x10", enc.code(), "mov r11b, 0x10");
}

test "lower FD/TD encoding" {
    var enc = TestEncode{};

    try enc.encode(.mov, &.{
        .{ .reg = .rax },
        .{ .mem = Instruction.Memory.initMoffs(.cs, 0x10) },
    });
    try expectEqualHexStrings("\x2E\x48\xA1\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs rax, cs:0x10");

    try enc.encode(.mov, &.{
        .{ .reg = .eax },
        .{ .mem = Instruction.Memory.initMoffs(.fs, 0x10) },
    });
    try expectEqualHexStrings("\x64\xA1\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs eax, fs:0x10");

    try enc.encode(.mov, &.{
        .{ .reg = .ax },
        .{ .mem = Instruction.Memory.initMoffs(.gs, 0x10) },
    });
    try expectEqualHexStrings("\x65\x66\xA1\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs ax, gs:0x10");

    try enc.encode(.mov, &.{
        .{ .reg = .al },
        .{ .mem = Instruction.Memory.initMoffs(.ds, 0x10) },
    });
    try expectEqualHexStrings("\xA0\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs al, ds:0x10");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initMoffs(.cs, 0x10) },
        .{ .reg = .rax },
    });
    try expectEqualHexStrings("\x2E\x48\xA3\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs cs:0x10, rax");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initMoffs(.fs, 0x10) },
        .{ .reg = .eax },
    });
    try expectEqualHexStrings("\x64\xA3\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs fs:0x10, eax");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initMoffs(.gs, 0x10) },
        .{ .reg = .ax },
    });
    try expectEqualHexStrings("\x65\x66\xA3\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs gs:0x10, ax");

    try enc.encode(.mov, &.{
        .{ .mem = Instruction.Memory.initMoffs(.ds, 0x10) },
        .{ .reg = .al },
    });
    try expectEqualHexStrings("\xA2\x10\x00\x00\x00\x00\x00\x00\x00", enc.code(), "movabs ds:0x10, al");
}

test "lower NP encoding" {
    var enc = TestEncode{};

    try enc.encode(.int3, &.{});
    try expectEqualHexStrings("\xCC", enc.code(), "int3");

    try enc.encode(.nop, &.{});
    try expectEqualHexStrings("\x90", enc.code(), "nop");

    try enc.encode(.ret, &.{});
    try expectEqualHexStrings("\xC3", enc.code(), "ret");

    try enc.encode(.syscall, &.{});
    try expectEqualHexStrings("\x0f\x05", enc.code(), "syscall");
}

fn invalidInstruction(mnemonic: Instruction.Mnemonic, ops: []const Instruction.Operand) !void {
    const err = Instruction.new(.none, mnemonic, ops);
    try testing.expectError(error.InvalidInstruction, err);
}

test "invalid instruction" {
    try invalidInstruction(.call, &.{
        .{ .reg = .eax },
    });
    try invalidInstruction(.call, &.{
        .{ .reg = .ax },
    });
    try invalidInstruction(.call, &.{
        .{ .reg = .al },
    });
    try invalidInstruction(.call, &.{
        .{ .mem = Instruction.Memory.initRip(.dword, 0) },
    });
    try invalidInstruction(.call, &.{
        .{ .mem = Instruction.Memory.initRip(.word, 0) },
    });
    try invalidInstruction(.call, &.{
        .{ .mem = Instruction.Memory.initRip(.byte, 0) },
    });
    try invalidInstruction(.mov, &.{
        .{ .mem = Instruction.Memory.initRip(.word, 0x10) },
        .{ .reg = .r12 },
    });
    try invalidInstruction(.lea, &.{
        .{ .reg = .rax },
        .{ .reg = .rbx },
    });
    try invalidInstruction(.lea, &.{
        .{ .reg = .al },
        .{ .mem = Instruction.Memory.initRip(.byte, 0) },
    });
    try invalidInstruction(.pop, &.{
        .{ .reg = .r12b },
    });
    try invalidInstruction(.pop, &.{
        .{ .reg = .r12d },
    });
    try invalidInstruction(.push, &.{
        .{ .reg = .r12b },
    });
    try invalidInstruction(.push, &.{
        .{ .reg = .r12d },
    });
    try invalidInstruction(.push, &.{
        .{ .imm = Instruction.Immediate.u(0x1000000000000000) },
    });
}

fn cannotEncode(mnemonic: Instruction.Mnemonic, ops: []const Instruction.Operand) !void {
    try testing.expectError(error.CannotEncode, Instruction.new(.none, mnemonic, ops));
}

test "cannot encode" {
    try cannotEncode(.@"test", &.{
        .{ .mem = Instruction.Memory.initSib(.byte, .{ .base = .{ .reg = .r12 } }) },
        .{ .reg = .ah },
    });
    try cannotEncode(.@"test", &.{
        .{ .reg = .r11b },
        .{ .reg = .bh },
    });
    try cannotEncode(.mov, &.{
        .{ .reg = .sil },
        .{ .reg = .ah },
    });
}

const Assembler = struct {
    it: Tokenizer,

    const Tokenizer = struct {
        input: []const u8,
        pos: usize = 0,

        const Error = error{InvalidToken};

        const Token = struct {
            id: Id,
            start: usize,
            end: usize,

            const Id = enum {
                eof,

                space,
                new_line,

                colon,
                comma,
                open_br,
                close_br,
                plus,
                minus,
                star,

                string,
                numeral,
            };
        };

        const Iterator = struct {};

        fn next(it: *Tokenizer) !Token {
            var result = Token{
                .id = .eof,
                .start = it.pos,
                .end = it.pos,
            };

            var state: enum {
                start,
                space,
                new_line,
                string,
                numeral,
                numeral_hex,
            } = .start;

            while (it.pos < it.input.len) : (it.pos += 1) {
                const ch = it.input[it.pos];
                switch (state) {
                    .start => switch (ch) {
                        ',' => {
                            result.id = .comma;
                            it.pos += 1;
                            break;
                        },
                        ':' => {
                            result.id = .colon;
                            it.pos += 1;
                            break;
                        },
                        '[' => {
                            result.id = .open_br;
                            it.pos += 1;
                            break;
                        },
                        ']' => {
                            result.id = .close_br;
                            it.pos += 1;
                            break;
                        },
                        '+' => {
                            result.id = .plus;
                            it.pos += 1;
                            break;
                        },
                        '-' => {
                            result.id = .minus;
                            it.pos += 1;
                            break;
                        },
                        '*' => {
                            result.id = .star;
                            it.pos += 1;
                            break;
                        },
                        ' ', '\t' => state = .space,
                        '\n', '\r' => state = .new_line,
                        'a'...'z', 'A'...'Z' => state = .string,
                        '0'...'9' => state = .numeral,
                        else => return error.InvalidToken,
                    },

                    .space => switch (ch) {
                        ' ', '\t' => {},
                        else => {
                            result.id = .space;
                            break;
                        },
                    },

                    .new_line => switch (ch) {
                        '\n', '\r', ' ', '\t' => {},
                        else => {
                            result.id = .new_line;
                            break;
                        },
                    },

                    .string => switch (ch) {
                        'a'...'z', 'A'...'Z', '0'...'9' => {},
                        else => {
                            result.id = .string;
                            break;
                        },
                    },

                    .numeral => switch (ch) {
                        'x' => state = .numeral_hex,
                        '0'...'9' => {},
                        else => {
                            result.id = .numeral;
                            break;
                        },
                    },

                    .numeral_hex => switch (ch) {
                        'a'...'f' => {},
                        '0'...'9' => {},
                        else => {
                            result.id = .numeral;
                            break;
                        },
                    },
                }
            }

            if (it.pos >= it.input.len) {
                switch (state) {
                    .string => result.id = .string,
                    .numeral, .numeral_hex => result.id = .numeral,
                    else => {},
                }
            }

            result.end = it.pos;
            return result;
        }

        fn seekTo(it: *Tokenizer, pos: usize) void {
            it.pos = pos;
        }
    };

    pub fn init(input: []const u8) Assembler {
        return .{
            .it = Tokenizer{ .input = input },
        };
    }

    pub fn assemble(as: *Assembler, writer: anytype) !void {
        while (try as.next()) |parsed_inst| {
            const inst = try Instruction.new(.none, parsed_inst.mnemonic, &parsed_inst.ops);
            try inst.encode(writer, .{});
        }
    }

    const ParseResult = struct {
        mnemonic: Instruction.Mnemonic,
        ops: [4]Instruction.Operand,
    };

    const ParseError = error{
        UnexpectedToken,
        InvalidMnemonic,
        InvalidOperand,
        InvalidRegister,
        InvalidPtrSize,
        InvalidMemoryOperand,
        InvalidScaleIndex,
    } || Tokenizer.Error || std.fmt.ParseIntError;

    fn next(as: *Assembler) ParseError!?ParseResult {
        try as.skip(2, .{ .space, .new_line });
        const mnemonic_tok = as.expect(.string) catch |err| switch (err) {
            error.UnexpectedToken => return if (try as.peek() == .eof) null else err,
            else => return err,
        };
        const mnemonic = mnemonicFromString(as.source(mnemonic_tok)) orelse
            return error.InvalidMnemonic;
        try as.skip(1, .{.space});

        const rules = .{
            .{},
            .{.register},
            .{.memory},
            .{.immediate},
            .{ .register, .register },
            .{ .register, .memory },
            .{ .memory, .register },
            .{ .register, .immediate },
            .{ .memory, .immediate },
            .{ .register, .register, .immediate },
            .{ .register, .memory, .immediate },
        };

        const pos = as.it.pos;
        inline for (rules) |rule| {
            var ops = [4]Instruction.Operand{ .none, .none, .none, .none };
            if (as.parseOperandRule(rule, &ops)) {
                return .{
                    .mnemonic = mnemonic,
                    .ops = ops,
                };
            } else |_| {
                as.it.seekTo(pos);
            }
        }

        return error.InvalidOperand;
    }

    fn source(as: *Assembler, token: Tokenizer.Token) []const u8 {
        return as.it.input[token.start..token.end];
    }

    fn peek(as: *Assembler) Tokenizer.Error!Tokenizer.Token.Id {
        const pos = as.it.pos;
        const next_tok = try as.it.next();
        const id = next_tok.id;
        as.it.seekTo(pos);
        return id;
    }

    fn expect(as: *Assembler, id: Tokenizer.Token.Id) ParseError!Tokenizer.Token {
        const next_tok_id = try as.peek();
        if (next_tok_id == id) return as.it.next();
        return error.UnexpectedToken;
    }

    fn skip(as: *Assembler, comptime num: comptime_int, tok_ids: [num]Tokenizer.Token.Id) Tokenizer.Error!void {
        outer: while (true) {
            const pos = as.it.pos;
            const next_tok = try as.it.next();
            inline for (tok_ids) |tok_id| {
                if (next_tok.id == tok_id) continue :outer;
            }
            as.it.seekTo(pos);
            break;
        }
    }

    fn mnemonicFromString(bytes: []const u8) ?Instruction.Mnemonic {
        const ti = @typeInfo(Instruction.Mnemonic).@"enum";
        inline for (ti.fields) |field| {
            if (std.mem.eql(u8, bytes, field.name)) {
                return @field(Instruction.Mnemonic, field.name);
            }
        }
        return null;
    }

    fn parseOperandRule(as: *Assembler, rule: anytype, ops: *[4]Instruction.Operand) ParseError!void {
        inline for (rule, 0..) |cond, i| {
            comptime assert(i < 4);
            if (i > 0) {
                _ = try as.expect(.comma);
                try as.skip(1, .{.space});
            }
            if (@typeInfo(@TypeOf(cond)) != .enum_literal) {
                @compileError("invalid condition in the rule: " ++ @typeName(@TypeOf(cond)));
            }
            switch (cond) {
                .register => {
                    const reg_tok = try as.expect(.string);
                    const reg = registerFromString(as.source(reg_tok)) orelse
                        return error.InvalidOperand;
                    ops[i] = .{ .reg = reg };
                },
                .memory => {
                    const mem = try as.parseMemory();
                    ops[i] = .{ .mem = mem };
                },
                .immediate => {
                    const is_neg = if (as.expect(.minus)) |_| true else |_| false;
                    const imm_tok = try as.expect(.numeral);
                    const imm: Instruction.Immediate = if (is_neg) blk: {
                        const imm = try std.fmt.parseInt(i32, as.source(imm_tok), 0);
                        break :blk .{ .signed = imm * -1 };
                    } else .{ .unsigned = try std.fmt.parseInt(u64, as.source(imm_tok), 0) };
                    ops[i] = .{ .imm = imm };
                },
                else => @compileError("unhandled enum literal " ++ @tagName(cond)),
            }
            try as.skip(1, .{.space});
        }

        try as.skip(1, .{.space});
        const tok = try as.it.next();
        switch (tok.id) {
            .new_line, .eof => {},
            else => return error.InvalidOperand,
        }
    }

    fn registerFromString(bytes: []const u8) ?Register {
        const ti = @typeInfo(Register).@"enum";
        inline for (ti.fields) |field| {
            if (std.mem.eql(u8, bytes, field.name)) {
                return @field(Register, field.name);
            }
        }
        return null;
    }

    fn parseMemory(as: *Assembler) ParseError!Instruction.Memory {
        const ptr_size: ?Instruction.Memory.PtrSize = blk: {
            const pos = as.it.pos;
            const ptr_size = as.parsePtrSize() catch |err| switch (err) {
                error.UnexpectedToken => {
                    as.it.seekTo(pos);
                    break :blk null;
                },
                else => return err,
            };
            break :blk ptr_size;
        };

        try as.skip(1, .{.space});

        // Supported rules and orderings.
        const rules = .{
            .{ .open_br, .general_purpose, .close_br }, // [ general_purpose ]
            .{ .open_br, .general_purpose, .plus, .disp, .close_br }, // [ general_purpose + disp ]
            .{ .open_br, .general_purpose, .minus, .disp, .close_br }, // [ general_purpose - disp ]
            .{ .open_br, .disp, .plus, .general_purpose, .close_br }, // [ disp + general_purpose ]
            .{ .open_br, .general_purpose, .plus, .index, .close_br }, // [ general_purpose + index ]
            .{ .open_br, .general_purpose, .plus, .index, .star, .scale, .close_br }, // [ general_purpose + index * scale ]
            .{ .open_br, .index, .star, .scale, .plus, .general_purpose, .close_br }, // [ index * scale + general_purpose ]
            .{ .open_br, .general_purpose, .plus, .index, .star, .scale, .plus, .disp, .close_br }, // [ general_purpose + index * scale + disp ]
            .{ .open_br, .general_purpose, .plus, .index, .star, .scale, .minus, .disp, .close_br }, // [ general_purpose + index * scale - disp ]
            .{ .open_br, .index, .star, .scale, .plus, .general_purpose, .plus, .disp, .close_br }, // [ index * scale + general_purpose + disp ]
            .{ .open_br, .index, .star, .scale, .plus, .general_purpose, .minus, .disp, .close_br }, // [ index * scale + general_purpose - disp ]
            .{ .open_br, .disp, .plus, .index, .star, .scale, .plus, .general_purpose, .close_br }, // [ disp + index * scale + general_purpose ]
            .{ .open_br, .disp, .plus, .general_purpose, .plus, .index, .star, .scale, .close_br }, // [ disp + general_purpose + index * scale ]
            .{ .open_br, .general_purpose, .plus, .disp, .plus, .index, .star, .scale, .close_br }, // [ general_purpose + disp + index * scale ]
            .{ .open_br, .general_purpose, .minus, .disp, .plus, .index, .star, .scale, .close_br }, // [ general_purpose - disp + index * scale ]
            .{ .open_br, .general_purpose, .plus, .disp, .plus, .scale, .star, .index, .close_br }, // [ general_purpose + disp + scale * index ]
            .{ .open_br, .general_purpose, .minus, .disp, .plus, .scale, .star, .index, .close_br }, // [ general_purpose - disp + scale * index ]
            .{ .open_br, .rip, .plus, .disp, .close_br }, // [ rip + disp ]
            .{ .open_br, .rip, .minus, .disp, .close_br }, // [ rig - disp ]
            .{ .segment, .colon, .disp }, // seg:disp
        };

        const pos = as.it.pos;
        inline for (rules) |rule| {
            if (as.parseMemoryRule(rule)) |res| {
                if (res.rip) {
                    if (res.base != null or res.scale_index != null or res.offset != null)
                        return error.InvalidMemoryOperand;
                    return Instruction.Memory.initRip(ptr_size orelse .qword, res.disp orelse 0);
                }
                if (res.base) |base| {
                    if (res.rip)
                        return error.InvalidMemoryOperand;
                    if (res.offset) |offset| {
                        if (res.scale_index != null or res.disp != null)
                            return error.InvalidMemoryOperand;
                        return Instruction.Memory.initMoffs(base, offset);
                    }
                    return Instruction.Memory.initSib(ptr_size orelse .qword, .{
                        .base = .{ .reg = base },
                        .scale_index = res.scale_index,
                        .disp = res.disp orelse 0,
                    });
                }
                return error.InvalidMemoryOperand;
            } else |_| {
                as.it.seekTo(pos);
            }
        }

        return error.InvalidOperand;
    }

    const MemoryParseResult = struct {
        rip: bool = false,
        base: ?Register = null,
        scale_index: ?Instruction.Memory.ScaleIndex = null,
        disp: ?i32 = null,
        offset: ?u64 = null,
    };

    fn parseMemoryRule(as: *Assembler, rule: anytype) ParseError!MemoryParseResult {
        var res: MemoryParseResult = .{};
        inline for (rule, 0..) |cond, i| {
            if (@typeInfo(@TypeOf(cond)) != .enum_literal) {
                @compileError("unsupported condition type in the rule: " ++ @typeName(@TypeOf(cond)));
            }
            switch (cond) {
                .open_br, .close_br, .plus, .minus, .star, .colon => {
                    _ = try as.expect(cond);
                },
                .general_purpose, .segment => {
                    const tok = try as.expect(.string);
                    const base = registerFromString(as.source(tok)) orelse return error.InvalidMemoryOperand;
                    if (base.class() != cond) return error.InvalidMemoryOperand;
                    res.base = base;
                },
                .rip => {
                    const tok = try as.expect(.string);
                    if (!std.mem.eql(u8, as.source(tok), "rip")) return error.InvalidMemoryOperand;
                    res.rip = true;
                },
                .index => {
                    const tok = try as.expect(.string);
                    const index = registerFromString(as.source(tok)) orelse
                        return error.InvalidMemoryOperand;
                    if (res.scale_index) |*si| {
                        si.index = index;
                    } else {
                        res.scale_index = .{ .scale = 1, .index = index };
                    }
                },
                .scale => {
                    const tok = try as.expect(.numeral);
                    const scale = try std.fmt.parseInt(u2, as.source(tok), 0);
                    if (res.scale_index) |*si| {
                        si.scale = scale;
                    } else {
                        res.scale_index = .{ .scale = scale, .index = undefined };
                    }
                },
                .disp => {
                    const tok = try as.expect(.numeral);
                    const is_neg = blk: {
                        if (i > 0) {
                            if (rule[i - 1] == .minus) break :blk true;
                        }
                        break :blk false;
                    };
                    if (std.fmt.parseInt(i32, as.source(tok), 0)) |disp| {
                        res.disp = if (is_neg) -1 * disp else disp;
                    } else |err| switch (err) {
                        error.Overflow => {
                            if (is_neg) return err;
                            if (res.base) |base| {
                                if (base.class() != .segment) return err;
                            }
                            const offset = try std.fmt.parseInt(u64, as.source(tok), 0);
                            res.offset = offset;
                        },
                        else => return err,
                    }
                },
                else => @compileError("unhandled operand output type: " ++ @tagName(cond)),
            }
            try as.skip(1, .{.space});
        }
        return res;
    }

    fn parsePtrSize(as: *Assembler) ParseError!Instruction.Memory.PtrSize {
        const size = try as.expect(.string);
        try as.skip(1, .{.space});
        const ptr = try as.expect(.string);

        const size_raw = as.source(size);
        const ptr_raw = as.source(ptr);
        const len = size_raw.len + ptr_raw.len + 1;
        var buf: ["qword ptr".len]u8 = undefined;
        if (len > buf.len) return error.InvalidPtrSize;

        for (size_raw, 0..) |c, i| {
            buf[i] = std.ascii.toLower(c);
        }
        buf[size_raw.len] = ' ';
        for (ptr_raw, 0..) |c, i| {
            buf[size_raw.len + i + 1] = std.ascii.toLower(c);
        }

        const slice = buf[0..len];
        if (std.mem.eql(u8, slice, "qword ptr")) return .qword;
        if (std.mem.eql(u8, slice, "dword ptr")) return .dword;
        if (std.mem.eql(u8, slice, "word ptr")) return .word;
        if (std.mem.eql(u8, slice, "byte ptr")) return .byte;
        if (std.mem.eql(u8, slice, "tbyte ptr")) return .tbyte;
        return error.InvalidPtrSize;
    }
};

test "assemble" {
    const input =
        \\int3
        \\mov rax, rbx
        \\mov qword ptr [rbp], rax
        \\mov qword ptr [rbp - 16], rax
        \\mov qword ptr [16 + rbp], rax
        \\mov rax, 0x10
        \\mov byte ptr [rbp - 0x10], 0x10
        \\mov word ptr [rbp + r12], r11w
        \\mov word ptr [rbp + r12 * 2], r11w
        \\mov word ptr [rbp + r12 * 2 - 16], r11w
        \\mov dword ptr [rip - 16], r12d
        \\mov rax, fs:0x0
        \\mov rax, gs:0x1000000000000000
        \\movzx r12, al
        \\imul r12, qword ptr [rbp - 16], 6
        \\jmp 0x0
        \\jc 0x0
        \\jb 0x0
        \\sal rax, 1
        \\sal rax, 63
        \\shl rax, 63
        \\sar rax, 63
        \\shr rax, 63
        \\test byte ptr [rbp - 16], r12b
        \\sal r12, cl
        \\mul qword ptr [rip - 16]
        \\div r12
        \\idiv byte ptr [rbp - 16]
        \\cwde
        \\cbw
        \\cdqe
        \\test byte ptr [rbp], ah
        \\test byte ptr [r12], spl
        \\cdq
        \\cwd
        \\cqo
        \\test bl, 0x1
        \\mov rbx,0x8000000000000000
        \\movss xmm0, dword ptr [rbp]
        \\movss xmm0, xmm1
        \\movss dword ptr [rbp - 16 + rax * 2], xmm7
        \\movss dword ptr [rbp - 16 + rax * 2], xmm8
        \\movss xmm15, xmm9
        \\movsd xmm8, qword ptr [rbp - 16]
        \\movsd qword ptr [rbp - 8], xmm0
        \\movq xmm8, qword ptr [rbp - 16]
        \\movq qword ptr [rbp - 16], xmm8
        \\ucomisd xmm0, qword ptr [rbp - 16]
        \\fisttp qword ptr [rbp - 16]
        \\fisttp word ptr [rip + 32]
        \\fisttp dword ptr [rax]
        \\fld tbyte ptr [rbp]
        \\fld dword ptr [rbp]
        \\xor bl, 0xff
        \\ud2
        \\add rsp, -1
        \\add rsp, 0xff
        \\mov sil, byte ptr [rax + rcx * 1]
        \\
    ;

    // zig fmt: off
    const expected = &[_]u8{
        0xCC,
        0x48, 0x89, 0xD8,
        0x48, 0x89, 0x45, 0x00,
        0x48, 0x89, 0x45, 0xF0,
        0x48, 0x89, 0x45, 0x10,
        0x48, 0xC7, 0xC0, 0x10, 0x00, 0x00, 0x00,
        0xC6, 0x45, 0xF0, 0x10,
        0x66, 0x46, 0x89, 0x5C, 0x25, 0x00,
        0x66, 0x46, 0x89, 0x5C, 0x65, 0x00,
        0x66, 0x46, 0x89, 0x5C, 0x65, 0xF0,
        0x44, 0x89, 0x25, 0xF0, 0xFF, 0xFF, 0xFF,
        0x64, 0x48, 0x8B, 0x04, 0x25, 0x00, 0x00, 0x00, 0x00,
        0x65, 0x48, 0xA1, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
        0x4C, 0x0F, 0xB6, 0xE0,
        0x4C, 0x6B, 0x65, 0xF0, 0x06,
        0xE9, 0x00, 0x00, 0x00, 0x00,
        0x0F, 0x82, 0x00, 0x00, 0x00, 0x00,
        0x0F, 0x82, 0x00, 0x00, 0x00, 0x00,
        0x48, 0xD1, 0xE0,
        0x48, 0xC1, 0xE0, 0x3F,
        0x48, 0xC1, 0xE0, 0x3F,
        0x48, 0xC1, 0xF8, 0x3F,
        0x48, 0xC1, 0xE8, 0x3F,
        0x44, 0x84, 0x65, 0xF0,
        0x49, 0xD3, 0xE4,
        0x48, 0xF7, 0x25, 0xF0, 0xFF, 0xFF, 0xFF,
        0x49, 0xF7, 0xF4,
        0xF6, 0x7D, 0xF0,
        0x98,
        0x66, 0x98,
        0x48, 0x98,
        0x84, 0x65, 0x00,
        0x41, 0x84, 0x24, 0x24,
        0x99,
        0x66, 0x99,
        0x48, 0x99,
        0xF6, 0xC3, 0x01,
        0x48, 0xBB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80,
        0xF3, 0x0F, 0x10, 0x45, 0x00,
        0xF3, 0x0F, 0x10, 0xC1,
        0xF3, 0x0F, 0x11, 0x7C, 0x45, 0xF0,
        0xF3, 0x44, 0x0F, 0x11, 0x44, 0x45, 0xF0,
        0xF3, 0x45, 0x0F, 0x10, 0xF9,
        0xF2, 0x44, 0x0F, 0x10, 0x45, 0xF0,
        0xF2, 0x0F, 0x11, 0x45, 0xF8,
        0x66, 0x4C, 0x0F, 0x6E, 0x45, 0xF0,
        0x66, 0x4C, 0x0F, 0x7E, 0x45, 0xF0,
        0x66, 0x0F, 0x2E, 0x45, 0xF0,
        0xDD, 0x4D, 0xF0,
        0xDF, 0x0D, 0x20, 0x00, 0x00, 0x00,
        0xDB, 0x08,
        0xDB, 0x6D, 0x00,
        0xD9, 0x45, 0x00,
        0x80, 0xF3, 0xFF,
        0x0F, 0x0B,
        0x48, 0x83, 0xC4, 0xFF,
        0x48, 0x81, 0xC4, 0xFF, 0x00, 0x00, 0x00,
        0x40, 0x8A, 0x34, 0x08,
    };
    // zig fmt: on

    var as = Assembler.init(input);
    var output = std.ArrayList(u8).init(testing.allocator);
    defer output.deinit();
    try as.assemble(output.writer());
    try expectEqualHexStrings(expected, output.items, input);
}

test "assemble - Jcc" {
    const mnemonics = [_]struct { Instruction.Mnemonic, u8 }{
        .{ .ja, 0x87 },
        .{ .jae, 0x83 },
        .{ .jb, 0x82 },
        .{ .jbe, 0x86 },
        .{ .jc, 0x82 },
        .{ .je, 0x84 },
        .{ .jg, 0x8f },
        .{ .jge, 0x8d },
        .{ .jl, 0x8c },
        .{ .jle, 0x8e },
        .{ .jna, 0x86 },
        .{ .jnae, 0x82 },
        .{ .jnb, 0x83 },
        .{ .jnbe, 0x87 },
        .{ .jnc, 0x83 },
        .{ .jne, 0x85 },
        .{ .jng, 0x8e },
        .{ .jnge, 0x8c },
        .{ .jnl, 0x8d },
        .{ .jnle, 0x8f },
        .{ .jno, 0x81 },
        .{ .jnp, 0x8b },
        .{ .jns, 0x89 },
        .{ .jnz, 0x85 },
        .{ .jo, 0x80 },
        .{ .jp, 0x8a },
        .{ .jpe, 0x8a },
        .{ .jpo, 0x8b },
        .{ .js, 0x88 },
        .{ .jz, 0x84 },
    };

    inline for (&mnemonics) |mnemonic| {
        const input = @tagName(mnemonic[0]) ++ " 0x0";
        const expected = [_]u8{ 0x0f, mnemonic[1], 0x0, 0x0, 0x0, 0x0 };
        var as = Assembler.init(input);
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();
        try as.assemble(output.writer());
        try expectEqualHexStrings(&expected, output.items, input);
    }
}

test "assemble - SETcc" {
    const mnemonics = [_]struct { Instruction.Mnemonic, u8 }{
        .{ .seta, 0x97 },
        .{ .setae, 0x93 },
        .{ .setb, 0x92 },
        .{ .setbe, 0x96 },
        .{ .setc, 0x92 },
        .{ .sete, 0x94 },
        .{ .setg, 0x9f },
        .{ .setge, 0x9d },
        .{ .setl, 0x9c },
        .{ .setle, 0x9e },
        .{ .setna, 0x96 },
        .{ .setnae, 0x92 },
        .{ .setnb, 0x93 },
        .{ .setnbe, 0x97 },
        .{ .setnc, 0x93 },
        .{ .setne, 0x95 },
        .{ .setng, 0x9e },
        .{ .setnge, 0x9c },
        .{ .setnl, 0x9d },
        .{ .setnle, 0x9f },
        .{ .setno, 0x91 },
        .{ .setnp, 0x9b },
        .{ .setns, 0x99 },
        .{ .setnz, 0x95 },
        .{ .seto, 0x90 },
        .{ .setp, 0x9a },
        .{ .setpe, 0x9a },
        .{ .setpo, 0x9b },
        .{ .sets, 0x98 },
        .{ .setz, 0x94 },
    };

    inline for (&mnemonics) |mnemonic| {
        const input = @tagName(mnemonic[0]) ++ " al";
        const expected = [_]u8{ 0x0f, mnemonic[1], 0xC0 };
        var as = Assembler.init(input);
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();
        try as.assemble(output.writer());
        try expectEqualHexStrings(&expected, output.items, input);
    }
}

test "assemble - CMOVcc" {
    const mnemonics = [_]struct { Instruction.Mnemonic, u8 }{
        .{ .cmova, 0x47 },
        .{ .cmovae, 0x43 },
        .{ .cmovb, 0x42 },
        .{ .cmovbe, 0x46 },
        .{ .cmovc, 0x42 },
        .{ .cmove, 0x44 },
        .{ .cmovg, 0x4f },
        .{ .cmovge, 0x4d },
        .{ .cmovl, 0x4c },
        .{ .cmovle, 0x4e },
        .{ .cmovna, 0x46 },
        .{ .cmovnae, 0x42 },
        .{ .cmovnb, 0x43 },
        .{ .cmovnbe, 0x47 },
        .{ .cmovnc, 0x43 },
        .{ .cmovne, 0x45 },
        .{ .cmovng, 0x4e },
        .{ .cmovnge, 0x4c },
        .{ .cmovnl, 0x4d },
        .{ .cmovnle, 0x4f },
        .{ .cmovno, 0x41 },
        .{ .cmovnp, 0x4b },
        .{ .cmovns, 0x49 },
        .{ .cmovnz, 0x45 },
        .{ .cmovo, 0x40 },
        .{ .cmovp, 0x4a },
        .{ .cmovpe, 0x4a },
        .{ .cmovpo, 0x4b },
        .{ .cmovs, 0x48 },
        .{ .cmovz, 0x44 },
    };

    inline for (&mnemonics) |mnemonic| {
        const input = @tagName(mnemonic[0]) ++ " rax, rbx";
        const expected = [_]u8{ 0x48, 0x0f, mnemonic[1], 0xC3 };
        var as = Assembler.init(input);
        var output = std.ArrayList(u8).init(testing.allocator);
        defer output.deinit();
        try as.assemble(output.writer());
        try expectEqualHexStrings(&expected, output.items, input);
    }
}
