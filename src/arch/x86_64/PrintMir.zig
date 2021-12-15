//! This file contains the functionality for print x86_64 MIR in a debug way, interleaved with AIR

const Print = @This();

const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;

const Air = @import("../../Air.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;
const Encoder = bits.Encoder;
const ErrorMsg = Module.ErrorMsg;
const MCValue = @import("CodeGen.zig").MCValue;
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Instruction = bits.Instruction;
const Register = bits.Register;
const Type = @import("../../type.zig").Type;
const fmtIntSizeBin = std.fmt.fmtIntSizeBin;

mir: Mir,

pub fn printMir(print: *const Print, w: anytype, mir_to_air_map: std.AutoHashMap(Mir.Inst.Index, Air.Inst.Index), air: Air) !void {
    const instruction_bytes = print.mir.instructions.len *
        // Here we don't use @sizeOf(Mir.Inst.Data) because it would include
        // the debug safety tag but we want to measure release size.
        (@sizeOf(Mir.Inst.Tag) + 2 + 8);
    const extra_bytes = print.mir.extra.len * @sizeOf(u32);
    const total_bytes = @sizeOf(Mir) + instruction_bytes + extra_bytes;

    // zig fmt: off
    std.debug.print(
        \\# Total MIR bytes: {}
        \\# MIR Instructions:         {d} ({})
        \\# MIR Extra Data:           {d} ({})
        \\
    , .{
        fmtIntSizeBin(total_bytes),
        print.mir.instructions.len, fmtIntSizeBin(instruction_bytes),
        print.mir.extra.len, fmtIntSizeBin(extra_bytes),
    });
    // zig fmt: on
    const mir_tags = print.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        if (mir_to_air_map.get(inst)) |air_index| {
            try w.print("air index %{} ({}) for following mir inst(s)\n", .{ air_index, air.instructions.items(.tag)[air_index] });
        }
        try w.writeAll("  ");
        switch (tag) {
            .adc => try print.mirArith(.adc, inst, w),
            .add => try print.mirArith(.add, inst, w),
            .sub => try print.mirArith(.sub, inst, w),
            .xor => try print.mirArith(.xor, inst, w),
            .@"and" => try print.mirArith(.@"and", inst, w),
            .@"or" => try print.mirArith(.@"or", inst, w),
            .sbb => try print.mirArith(.sbb, inst, w),
            .cmp => try print.mirArith(.cmp, inst, w),

            .adc_scale_src => try print.mirArithScaleSrc(.adc, inst, w),
            .add_scale_src => try print.mirArithScaleSrc(.add, inst, w),
            .sub_scale_src => try print.mirArithScaleSrc(.sub, inst, w),
            .xor_scale_src => try print.mirArithScaleSrc(.xor, inst, w),
            .and_scale_src => try print.mirArithScaleSrc(.@"and", inst, w),
            .or_scale_src => try print.mirArithScaleSrc(.@"or", inst, w),
            .sbb_scale_src => try print.mirArithScaleSrc(.sbb, inst, w),
            .cmp_scale_src => try print.mirArithScaleSrc(.cmp, inst, w),

            .adc_scale_dst => try print.mirArithScaleDst(.adc, inst, w),
            .add_scale_dst => try print.mirArithScaleDst(.add, inst, w),
            .sub_scale_dst => try print.mirArithScaleDst(.sub, inst, w),
            .xor_scale_dst => try print.mirArithScaleDst(.xor, inst, w),
            .and_scale_dst => try print.mirArithScaleDst(.@"and", inst, w),
            .or_scale_dst => try print.mirArithScaleDst(.@"or", inst, w),
            .sbb_scale_dst => try print.mirArithScaleDst(.sbb, inst, w),
            .cmp_scale_dst => try print.mirArithScaleDst(.cmp, inst, w),

            .adc_scale_imm => try print.mirArithScaleImm(.adc, inst, w),
            .add_scale_imm => try print.mirArithScaleImm(.add, inst, w),
            .sub_scale_imm => try print.mirArithScaleImm(.sub, inst, w),
            .xor_scale_imm => try print.mirArithScaleImm(.xor, inst, w),
            .and_scale_imm => try print.mirArithScaleImm(.@"and", inst, w),
            .or_scale_imm => try print.mirArithScaleImm(.@"or", inst, w),
            .sbb_scale_imm => try print.mirArithScaleImm(.sbb, inst, w),
            .cmp_scale_imm => try print.mirArithScaleImm(.cmp, inst, w),

            .mov => try print.mirArith(.mov, inst, w),
            .mov_scale_src => try print.mirArithScaleSrc(.mov, inst, w),
            .mov_scale_dst => try print.mirArithScaleDst(.mov, inst, w),
            .mov_scale_imm => try print.mirArithScaleImm(.mov, inst, w),
            .movabs => try print.mirMovabs(inst, w),

            .lea => try print.mirLea(inst, w),
            .lea_rip => try print.mirLeaRip(inst, w),

            .imul_complex => try print.mirIMulComplex(inst, w),

            .push => try print.mirPushPop(.push, inst, w),
            .pop => try print.mirPushPop(.pop, inst, w),

            .jmp => try print.mirJmpCall(.jmp, inst, w),
            .call => try print.mirJmpCall(.call, inst, w),

            // .cond_jmp_greater_less => try print.mirCondJmp(.cond_jmp_greater_less, inst, w),
            // .cond_jmp_above_below => try print.mirCondJmp(.cond_jmp_above_below, inst, w),
            // .cond_jmp_eq_ne => try print.mirCondJmp(.cond_jmp_eq_ne, inst, w),

            // .cond_set_byte_greater_less => try print.mirCondSetByte(.cond_set_byte_greater_less, inst, w),
            // .cond_set_byte_above_below => try print.mirCondSetByte(.cond_set_byte_above_below, inst, w),
            // .cond_set_byte_eq_ne => try print.mirCondSetByte(.cond_set_byte_eq_ne, inst, w),

            // .@"test" => try print.mirTest(inst, w),

            .brk => try w.writeAll("brk\n"),
            .ret => try w.writeAll("ret\n"),
            .nop => try w.writeAll("nop\n"),
            .syscall => try w.writeAll("syscall\n"),

            .call_extern => try print.mirCallExtern(inst, w),

            .dbg_line, .dbg_prologue_end, .dbg_epilogue_begin, .arg_dbg_info => try w.print("{s}\n", .{@tagName(tag)}),

            .push_regs_from_callee_preserved_regs => try print.mirPushPopRegsFromCalleePreservedRegs(.push, inst, w),
            .pop_regs_from_callee_preserved_regs => try print.mirPushPopRegsFromCalleePreservedRegs(.pop, inst, w),

            else => {
                try w.print("TODO emit asm for {s}\n", .{@tagName(tag)});
            },
        }
    }
}

fn mirPushPop(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // PUSH/POP reg
            try w.print("{s} {s}", .{ @tagName(tag), @tagName(ops.reg1) });
        },
        0b01 => {
            // PUSH/POP r/m64
            const imm = print.mir.instructions.items(.data)[inst].imm;
            try w.print("{s} [{s} + {d}]", .{ @tagName(tag), @tagName(ops.reg1), imm });
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            // PUSH imm32
            assert(tag == .push);
            try w.print("{s} {d}", .{ @tagName(tag), imm });
        },
        0b11 => unreachable,
    }
    try w.writeByte('\n');
}
fn mirPushPopRegsFromCalleePreservedRegs(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const callee_preserved_regs = bits.callee_preserved_regs;
    // PUSH/POP reg

    const regs = print.mir.instructions.items(.data)[inst].regs_to_push_or_pop;
    if (regs == 0) return w.writeAll("push/pop no regs from callee_preserved_regs\n");
    if (tag == .push) {
        try w.writeAll("push ");
        for (callee_preserved_regs) |reg, i| {
            if ((regs >> @intCast(u5, i)) & 1 == 0) continue;
            try w.print("{s}, ", .{@tagName(reg)});
        }
    } else {
        // pop in the reverse direction
        var i = callee_preserved_regs.len;
        try w.writeAll("pop ");
        while (i > 0) : (i -= 1) {
            if ((regs >> @intCast(u5, i - 1)) & 1 == 0) continue;
            const reg = callee_preserved_regs[i - 1];
            try w.print("{s}, ", .{@tagName(reg)});
        }
    }
    try w.writeByte('\n');
}

fn mirJmpCall(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    try w.print("{s} ", .{@tagName(tag)});
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const flag = @truncate(u1, ops.flags);
    if (flag == 0) {
        return w.writeAll("TODO target\n");
    }
    if (ops.reg1 == .none) {
        // JMP/CALL [imm]
        const imm = print.mir.instructions.items(.data)[inst].imm;
        try w.print("[{x}]\n", .{imm});
        return;
    }
    // JMP/CALL reg
    try w.print("{s}\n", .{@tagName(ops.reg1)});
}

const CondType = enum {
    /// greater than or equal
    gte,

    /// greater than
    gt,

    /// less than
    lt,

    /// less than or equal
    lte,

    /// above or equal
    ae,

    /// above
    a,

    /// below
    b,

    /// below or equal
    be,

    /// not equal
    ne,

    /// equal
    eq,

    fn fromTagAndFlags(tag: Mir.Inst.Tag, flags: u2) CondType {
        return switch (tag) {
            .cond_jmp_greater_less,
            .cond_set_byte_greater_less,
            => switch (flags) {
                0b00 => CondType.gte,
                0b01 => CondType.gt,
                0b10 => CondType.lt,
                0b11 => CondType.lte,
            },
            .cond_jmp_above_below,
            .cond_set_byte_above_below,
            => switch (flags) {
                0b00 => CondType.ae,
                0b01 => CondType.a,
                0b10 => CondType.b,
                0b11 => CondType.be,
            },
            .cond_jmp_eq_ne,
            .cond_set_byte_eq_ne,
            => switch (@truncate(u1, flags)) {
                0b0 => CondType.ne,
                0b1 => CondType.eq,
            },
            else => unreachable,
        };
    }
};

inline fn getCondOpCode(tag: Mir.Inst.Tag, cond: CondType) u8 {
    switch (cond) {
        .gte => return switch (tag) {
            .cond_jmp_greater_less => 0x8d,
            .cond_set_byte_greater_less => 0x9d,
            else => unreachable,
        },
        .gt => return switch (tag) {
            .cond_jmp_greater_less => 0x8f,
            .cond_set_byte_greater_less => 0x9f,
            else => unreachable,
        },
        .lt => return switch (tag) {
            .cond_jmp_greater_less => 0x8c,
            .cond_set_byte_greater_less => 0x9c,
            else => unreachable,
        },
        .lte => return switch (tag) {
            .cond_jmp_greater_less => 0x8e,
            .cond_set_byte_greater_less => 0x9e,
            else => unreachable,
        },
        .ae => return switch (tag) {
            .cond_jmp_above_below => 0x83,
            .cond_set_byte_above_below => 0x93,
            else => unreachable,
        },
        .a => return switch (tag) {
            .cond_jmp_above_below => 0x87,
            .cond_set_byte_greater_less => 0x97,
            else => unreachable,
        },
        .b => return switch (tag) {
            .cond_jmp_above_below => 0x82,
            .cond_set_byte_greater_less => 0x92,
            else => unreachable,
        },
        .be => return switch (tag) {
            .cond_jmp_above_below => 0x86,
            .cond_set_byte_greater_less => 0x96,
            else => unreachable,
        },
        .eq => return switch (tag) {
            .cond_jmp_eq_ne => 0x84,
            .cond_set_byte_eq_ne => 0x94,
            else => unreachable,
        },
        .ne => return switch (tag) {
            .cond_jmp_eq_ne => 0x85,
            .cond_set_byte_eq_ne => 0x95,
            else => unreachable,
        },
    }
}

fn mirCondJmp(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    _ = w; // TODO
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const target = print.mir.instructions.items(.data)[inst].inst;
    const cond = CondType.fromTagAndFlags(tag, ops.flags);
    const opc = getCondOpCode(tag, cond);
    const source = print.code.items.len;
    const encoder = try Encoder.init(print.code, 6);
    encoder.opcode_2byte(0x0f, opc);
    try print.relocs.append(print.bin_file.allocator, .{
        .source = source,
        .target = target,
        .offset = print.code.items.len,
        .length = 6,
    });
    encoder.imm32(0);
}

fn mirCondSetByte(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    _ = w; // TODO
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const cond = CondType.fromTagAndFlags(tag, ops.flags);
    const opc = getCondOpCode(tag, cond);
    const encoder = try Encoder.init(print.code, 4);
    encoder.rex(.{
        .w = true,
        .b = ops.reg1.isExtended(),
    });
    encoder.opcode_2byte(0x0f, opc);
    encoder.modRm_direct(0x0, ops.reg1.lowId());
}

fn mirTest(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    _ = w; // TODO
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .@"test");
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => blk: {
            if (ops.reg2 == .none) {
                // TEST r/m64, imm32
                const imm = print.mir.instructions.items(.data)[inst].imm;
                if (ops.reg1.to64() == .rax) {
                    // TODO reduce the size of the instruction if the immediate
                    // is smaller than 32 bits
                    const encoder = try Encoder.init(print.code, 6);
                    encoder.rex(.{
                        .w = true,
                    });
                    encoder.opcode_1byte(0xa9);
                    encoder.imm32(imm);
                    break :blk;
                }
                const opc: u8 = if (ops.reg1.size() == 8) 0xf6 else 0xf7;
                const encoder = try Encoder.init(print.code, 7);
                encoder.rex(.{
                    .w = true,
                    .b = ops.reg1.isExtended(),
                });
                encoder.opcode_1byte(opc);
                encoder.modRm_direct(0, ops.reg1.lowId());
                encoder.imm8(@intCast(i8, imm));
                break :blk;
            }
            // TEST r/m64, r64
            return print.fail("TODO TEST r/m64, r64", .{});
        },
        else => return print.fail("TODO more TEST alternatives", .{}),
    }
}

const EncType = enum {
    /// OP r/m64, imm32
    mi,

    /// OP r/m64, r64
    mr,

    /// OP r64, r/m64
    rm,
};

const OpCode = struct {
    opc: u8,
    /// Only used if `EncType == .mi`.
    modrm_ext: u3,
};

inline fn getArithOpCode(tag: Mir.Inst.Tag, enc: EncType) OpCode {
    switch (enc) {
        .mi => return switch (tag) {
            .adc => .{ .opc = 0x81, .modrm_ext = 0x2 },
            .add => .{ .opc = 0x81, .modrm_ext = 0x0 },
            .sub => .{ .opc = 0x81, .modrm_ext = 0x5 },
            .xor => .{ .opc = 0x81, .modrm_ext = 0x6 },
            .@"and" => .{ .opc = 0x81, .modrm_ext = 0x4 },
            .@"or" => .{ .opc = 0x81, .modrm_ext = 0x1 },
            .sbb => .{ .opc = 0x81, .modrm_ext = 0x3 },
            .cmp => .{ .opc = 0x81, .modrm_ext = 0x7 },
            .mov => .{ .opc = 0xc7, .modrm_ext = 0x0 },
            else => unreachable,
        },
        .mr => {
            const opc: u8 = switch (tag) {
                .adc => 0x11,
                .add => 0x01,
                .sub => 0x29,
                .xor => 0x31,
                .@"and" => 0x21,
                .@"or" => 0x09,
                .sbb => 0x19,
                .cmp => 0x39,
                .mov => 0x89,
                else => unreachable,
            };
            return .{ .opc = opc, .modrm_ext = undefined };
        },
        .rm => {
            const opc: u8 = switch (tag) {
                .adc => 0x13,
                .add => 0x03,
                .sub => 0x2b,
                .xor => 0x33,
                .@"and" => 0x23,
                .@"or" => 0x0b,
                .sbb => 0x1b,
                .cmp => 0x3b,
                .mov => 0x8b,
                else => unreachable,
            };
            return .{ .opc = opc, .modrm_ext = undefined };
        },
    }
}

fn mirArith(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    try w.writeAll(@tagName(tag));
    try w.writeByte(' ');
    switch (ops.flags) {
        0b00 => {
            if (ops.reg2 == .none) {
                const imm = print.mir.instructions.items(.data)[inst].imm;
                try w.print("{s}, {d}", .{ @tagName(ops.reg1), imm });
            } else try w.print("{s}, {s}", .{ @tagName(ops.reg1), @tagName(ops.reg2) });
        },
        0b01 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            if (ops.reg2 == .none) {
                try w.print("{s}, [ds:{d}]", .{ @tagName(ops.reg1), imm });
            } else {
                try w.print("{s}, [{s} + {d}]", .{ @tagName(ops.reg1), @tagName(ops.reg2), imm });
            }
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            if (ops.reg2 == .none) {
                try w.print("[{s} + 0], {d}", .{ @tagName(ops.reg1), imm });
            } else {
                try w.print("[{s} + {d}], {s}", .{ @tagName(ops.reg1), imm, @tagName(ops.reg2) });
            }
        },
        0b11 => {
            if (ops.reg2 == .none) {
                const payload = print.mir.instructions.items(.data)[inst].payload;
                const imm_pair = Mir.extraData(print.mir.extra, Mir.ImmPair, payload).data;
                try w.print("[{s} + {d}], {d}", .{ @tagName(ops.reg1), imm_pair.dest_off, imm_pair.operand });
            }
            try w.writeAll("TODO");
        },
    }
    try w.writeByte('\n');
}

fn mirArithScaleSrc(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    // OP reg1, [reg2 + scale*rcx + imm32]
    const imm = print.mir.instructions.items(.data)[inst].imm;
    try w.print("{s} {s}, [{s} + {d}*rcx + {d}]\n", .{ @tagName(tag), @tagName(ops.reg1), @tagName(ops.reg2), scale, imm });
}

fn mirArithScaleDst(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const imm = print.mir.instructions.items(.data)[inst].imm;

    if (ops.reg2 == .none) {
        // OP [reg1 + scale*rax + 0], imm32
        try w.print("{s} [{s} + {d}*rcx + 0], {d}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm });
    }

    // OP [reg1 + scale*rax + imm32], reg2
    try w.print("{s} [{s} + {d}*rcx + {d}], {s}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm, @tagName(ops.reg2) });
}

fn mirArithScaleImm(print: *const Print, tag: Mir.Inst.Tag, inst: Mir.Inst.Index, w: anytype) !void {
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const payload = print.mir.instructions.items(.data)[inst].payload;
    const imm_pair = Mir.extraData(print.mir.extra, Mir.ImmPair, payload).data;
    try w.print("{s} [{s} + {d}*rcx + {d}], {d}\n", .{ @tagName(tag), @tagName(ops.reg1), scale, imm_pair.dest_off, imm_pair.operand });
}

fn mirMovabs(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .movabs);
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);

    const is_64 = ops.reg1.size() == 64;
    const imm: i128 = if (is_64) blk: {
        const payload = print.mir.instructions.items(.data)[inst].payload;
        const imm64 = Mir.extraData(print.mir.extra, Mir.Imm64, payload).data;
        break :blk imm64.decode();
    } else print.mir.instructions.items(.data)[inst].imm;
    if (ops.flags == 0b00) {
        // movabs reg, imm64
        try w.print("movabs {s}, {d}\n", .{ @tagName(ops.reg1), imm });
    }
    if (ops.reg1 == .none) {
        try w.writeAll("movabs moffs64, rax\n");
    } else {
        // movabs rax, moffs64
        try w.writeAll("movabs rax, moffs64\n");
    }
}

fn mirIMulComplex(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .imul_complex);
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            try w.print("imul {s}, {s}\n", .{ @tagName(ops.reg1), @tagName(ops.reg2) });
        },
        0b10 => {
            const imm = print.mir.instructions.items(.data)[inst].imm;
            try w.print("imul {s}, {s}, {d}\n", .{ @tagName(ops.reg1), @tagName(ops.reg2), imm });
        },
        else => return w.writeAll("TODO implement imul\n"),
    }
}

fn mirLea(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    const tag = print.mir.instructions.items(.tag)[inst];
    assert(tag == .lea);
    const ops = Mir.Ops.decode(print.mir.instructions.items(.ops)[inst]);
    assert(ops.flags == 0b01);
    const imm = print.mir.instructions.items(.data)[inst].imm;

    try w.print("lea {s} [{s} + {d}]\n", .{ @tagName(ops.reg1), @tagName(ops.reg2), imm });
}

fn mirLeaRip(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    _ = print;
    _ = inst;
    return w.writeAll("TODO lea_rip\n");
}

fn mirCallExtern(print: *const Print, inst: Mir.Inst.Index, w: anytype) !void {
    _ = print;
    _ = inst;
    return w.writeAll("TODO call_extern");
}
