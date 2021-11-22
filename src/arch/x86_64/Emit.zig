//! This file contains the functionality for lowering x86_64 MIR into
//! machine code

const Emit = @This();

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

mir: Mir,
bin_file: *link.File,
debug_output: DebugInfoOutput,
target: *const std.Target,
err_msg: ?*ErrorMsg = null,
src_loc: Module.SrcLoc,
code: *std.ArrayList(u8),

prev_di_line: u32,
prev_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

code_offset_mapping: std.AutoHashMapUnmanaged(Mir.Inst.Index, usize) = .{},
relocs: std.ArrayListUnmanaged(Reloc) = .{},

const InnerError = error{
    OutOfMemory,
    Overflow,
    EmitFail,
};

const Reloc = struct {
    /// Offset of the instruction.
    source: u64,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset of the relocation within the instruction.
    offset: u64,
    /// Length of the instruction.
    length: u5,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        try emit.code_offset_mapping.putNoClobber(emit.bin_file.allocator, inst, emit.code.items.len);
        switch (tag) {
            .adc => try emit.mirArith(.adc, inst),
            .add => try emit.mirArith(.add, inst),
            .sub => try emit.mirArith(.sub, inst),
            .xor => try emit.mirArith(.xor, inst),
            .@"and" => try emit.mirArith(.@"and", inst),
            .@"or" => try emit.mirArith(.@"or", inst),
            .sbb => try emit.mirArith(.sbb, inst),
            .cmp => try emit.mirArith(.cmp, inst),

            .adc_scale_src => try emit.mirArithScaleSrc(.adc, inst),
            .add_scale_src => try emit.mirArithScaleSrc(.add, inst),
            .sub_scale_src => try emit.mirArithScaleSrc(.sub, inst),
            .xor_scale_src => try emit.mirArithScaleSrc(.xor, inst),
            .and_scale_src => try emit.mirArithScaleSrc(.@"and", inst),
            .or_scale_src => try emit.mirArithScaleSrc(.@"or", inst),
            .sbb_scale_src => try emit.mirArithScaleSrc(.sbb, inst),
            .cmp_scale_src => try emit.mirArithScaleSrc(.cmp, inst),

            .adc_scale_dst => try emit.mirArithScaleDst(.adc, inst),
            .add_scale_dst => try emit.mirArithScaleDst(.add, inst),
            .sub_scale_dst => try emit.mirArithScaleDst(.sub, inst),
            .xor_scale_dst => try emit.mirArithScaleDst(.xor, inst),
            .and_scale_dst => try emit.mirArithScaleDst(.@"and", inst),
            .or_scale_dst => try emit.mirArithScaleDst(.@"or", inst),
            .sbb_scale_dst => try emit.mirArithScaleDst(.sbb, inst),
            .cmp_scale_dst => try emit.mirArithScaleDst(.cmp, inst),

            .adc_scale_imm => try emit.mirArithScaleImm(.adc, inst),
            .add_scale_imm => try emit.mirArithScaleImm(.add, inst),
            .sub_scale_imm => try emit.mirArithScaleImm(.sub, inst),
            .xor_scale_imm => try emit.mirArithScaleImm(.xor, inst),
            .and_scale_imm => try emit.mirArithScaleImm(.@"and", inst),
            .or_scale_imm => try emit.mirArithScaleImm(.@"or", inst),
            .sbb_scale_imm => try emit.mirArithScaleImm(.sbb, inst),
            .cmp_scale_imm => try emit.mirArithScaleImm(.cmp, inst),

            // Even though MOV is technically not an arithmetic op,
            // its structure can be represented using the same set of
            // opcode primitives.
            .mov => try emit.mirArith(.mov, inst),
            .mov_scale_src => try emit.mirArithScaleSrc(.mov, inst),
            .mov_scale_dst => try emit.mirArithScaleDst(.mov, inst),
            .mov_scale_imm => try emit.mirArithScaleImm(.mov, inst),
            .movabs => try emit.mirMovabs(inst),

            .lea => try emit.mirLea(inst),
            .lea_rip => try emit.mirLeaRip(inst),

            .imul_complex => try emit.mirIMulComplex(inst),

            .push => try emit.mirPushPop(.push, inst),
            .pop => try emit.mirPushPop(.pop, inst),

            .jmp => try emit.mirJmpCall(.jmp, inst),
            .call => try emit.mirJmpCall(.call, inst),

            .cond_jmp_greater_less => try emit.mirCondJmp(.cond_jmp_greater_less, inst),
            .cond_jmp_above_below => try emit.mirCondJmp(.cond_jmp_above_below, inst),
            .cond_jmp_eq_ne => try emit.mirCondJmp(.cond_jmp_eq_ne, inst),

            .cond_set_byte_greater_less => try emit.mirCondSetByte(.cond_set_byte_greater_less, inst),
            .cond_set_byte_above_below => try emit.mirCondSetByte(.cond_set_byte_above_below, inst),
            .cond_set_byte_eq_ne => try emit.mirCondSetByte(.cond_set_byte_eq_ne, inst),

            .ret => try emit.mirRet(inst),

            .syscall => try emit.mirSyscall(),

            .@"test" => try emit.mirTest(inst),

            .brk => try emit.mirBrk(),
            .nop => try emit.mirNop(),

            .call_extern => try emit.mirCallExtern(inst),

            .dbg_line => try emit.mirDbgLine(inst),
            .dbg_prologue_end => try emit.mirDbgPrologueEnd(inst),
            .dbg_epilogue_begin => try emit.mirDbgEpilogueBegin(inst),
            .arg_dbg_info => try emit.mirArgDbgInfo(inst),

            .push_regs_from_callee_preserved_regs => try emit.mirPushPopRegsFromCalleePreservedRegs(.push, inst),
            .pop_regs_from_callee_preserved_regs => try emit.mirPushPopRegsFromCalleePreservedRegs(.pop, inst),

            else => {
                return emit.fail("Implement MIR->Isel lowering for x86_64 for pseudo-inst: {s}", .{tag});
            },
        }
    }

    try emit.fixupRelocs();
}

pub fn deinit(emit: *Emit) void {
    emit.relocs.deinit(emit.bin_file.allocator);
    emit.code_offset_mapping.deinit(emit.bin_file.allocator);
    emit.* = undefined;
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(emit.err_msg == null);
    emit.err_msg = try ErrorMsg.create(emit.bin_file.allocator, emit.src_loc, format, args);
    return error.EmitFail;
}

fn fixupRelocs(emit: *Emit) InnerError!void {
    // TODO this function currently assumes all relocs via JMP/CALL instructions are 32bit in size.
    // This should be reversed like it is done in aarch64 MIR emit code: start with the smallest
    // possible resolution, i.e., 8bit, and iteratively converge on the minimum required resolution
    // until the entire decl is correctly emitted with all JMP/CALL instructions within range.
    for (emit.relocs.items) |reloc| {
        const offset = try math.cast(usize, reloc.offset);
        const target = emit.code_offset_mapping.get(reloc.target) orelse
            return emit.fail("JMP/CALL relocation target not found!", .{});
        const disp = @intCast(i32, @intCast(i64, target) - @intCast(i64, reloc.source + reloc.length));
        mem.writeIntLittle(i32, emit.code.items[offset..][0..4], disp);
    }
}

fn mirBrk(emit: *Emit) InnerError!void {
    const encoder = try Encoder.init(emit.code, 1);
    encoder.opcode_1byte(0xcc);
}

fn mirNop(emit: *Emit) InnerError!void {
    const encoder = try Encoder.init(emit.code, 1);
    encoder.opcode_1byte(0x90);
}

fn mirSyscall(emit: *Emit) InnerError!void {
    const encoder = try Encoder.init(emit.code, 2);
    encoder.opcode_2byte(0x0f, 0x05);
}

fn mirPushPop(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // PUSH/POP reg
            const opc: u8 = switch (tag) {
                .push => 0x50,
                .pop => 0x58,
                else => unreachable,
            };
            const encoder = try Encoder.init(emit.code, 2);
            encoder.rex(.{
                .b = ops.reg1.isExtended(),
            });
            encoder.opcode_withReg(opc, ops.reg1.lowId());
        },
        0b01 => {
            // PUSH/POP r/m64
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const opc: u8 = switch (tag) {
                .push => 0xff,
                .pop => 0x8f,
                else => unreachable,
            };
            const modrm_ext: u3 = switch (tag) {
                .push => 0x6,
                .pop => 0x0,
                else => unreachable,
            };
            const encoder = try Encoder.init(emit.code, 6);
            encoder.opcode_1byte(opc);
            if (math.cast(i8, imm)) |imm_i8| {
                encoder.modRm_indirectDisp8(modrm_ext, ops.reg1.lowId());
                encoder.imm8(@intCast(i8, imm_i8));
            } else |_| {
                encoder.modRm_indirectDisp32(modrm_ext, ops.reg1.lowId());
                encoder.imm32(imm);
            }
        },
        0b10 => {
            // PUSH imm32
            assert(tag == .push);
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const opc: u8 = if (imm <= math.maxInt(i8)) 0x6a else 0x6b;
            const encoder = try Encoder.init(emit.code, 2);
            encoder.opcode_1byte(opc);
            if (imm <= math.maxInt(i8)) {
                encoder.imm8(@intCast(i8, imm));
            } else if (imm <= math.maxInt(i16)) {
                encoder.imm16(@intCast(i16, imm));
            } else {
                encoder.imm32(imm);
            }
        },
        0b11 => unreachable,
    }
}
fn mirPushPopRegsFromCalleePreservedRegs(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const callee_preserved_regs = bits.callee_preserved_regs;
    // PUSH/POP reg
    const opc: u8 = switch (tag) {
        .push => 0x50,
        .pop => 0x58,
        else => unreachable,
    };

    const regs = emit.mir.instructions.items(.data)[inst].regs_to_push_or_pop;
    if (tag == .push) {
        for (callee_preserved_regs) |reg, i| {
            if ((regs >> @intCast(u5, i)) & 1 == 0) continue;
            const encoder = try Encoder.init(emit.code, 2);
            encoder.rex(.{
                .b = reg.isExtended(),
            });
            encoder.opcode_withReg(opc, reg.lowId());
        }
    } else {
        // pop in the reverse direction
        var i = callee_preserved_regs.len;
        while (i > 0) : (i -= 1) {
            const reg = callee_preserved_regs[i - 1];
            if ((regs >> @intCast(u5, i - 1)) & 1 == 0) continue;
            const encoder = try Encoder.init(emit.code, 2);
            encoder.rex(.{
                .b = reg.isExtended(),
            });
            encoder.opcode_withReg(opc, reg.lowId());
        }
    }
}

fn mirJmpCall(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const flag = @truncate(u1, ops.flags);
    if (flag == 0) {
        const target = emit.mir.instructions.items(.data)[inst].inst;
        const opc: u8 = switch (tag) {
            .jmp => 0xe9,
            .call => 0xe8,
            else => unreachable,
        };
        const source = emit.code.items.len;
        const encoder = try Encoder.init(emit.code, 5);
        encoder.opcode_1byte(opc);
        try emit.relocs.append(emit.bin_file.allocator, .{
            .source = source,
            .target = target,
            .offset = emit.code.items.len,
            .length = 5,
        });
        encoder.imm32(0x0);
        return;
    }
    const modrm_ext: u3 = switch (tag) {
        .jmp => 0x4,
        .call => 0x2,
        else => unreachable,
    };
    if (ops.reg1 == .none) {
        // JMP/CALL [imm]
        const imm = emit.mir.instructions.items(.data)[inst].imm;
        const encoder = try Encoder.init(emit.code, 7);
        encoder.opcode_1byte(0xff);
        encoder.modRm_SIBDisp0(modrm_ext);
        encoder.sib_disp32();
        encoder.imm32(imm);
        return;
    }
    // JMP/CALL reg
    const encoder = try Encoder.init(emit.code, 2);
    encoder.opcode_1byte(0xff);
    encoder.modRm_direct(modrm_ext, ops.reg1.lowId());
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

fn mirCondJmp(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const target = emit.mir.instructions.items(.data)[inst].inst;
    const cond = CondType.fromTagAndFlags(tag, ops.flags);
    const opc = getCondOpCode(tag, cond);
    const source = emit.code.items.len;
    const encoder = try Encoder.init(emit.code, 6);
    encoder.opcode_2byte(0x0f, opc);
    try emit.relocs.append(emit.bin_file.allocator, .{
        .source = source,
        .target = target,
        .offset = emit.code.items.len,
        .length = 6,
    });
    encoder.imm32(0);
}

fn mirCondSetByte(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const cond = CondType.fromTagAndFlags(tag, ops.flags);
    const opc = getCondOpCode(tag, cond);
    const encoder = try Encoder.init(emit.code, 4);
    encoder.rex(.{
        .w = true,
        .b = ops.reg1.isExtended(),
    });
    encoder.opcode_2byte(0x0f, opc);
    encoder.modRm_direct(0x0, ops.reg1.lowId());
}

fn mirTest(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .@"test");
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => blk: {
            if (ops.reg2 == .none) {
                // TEST r/m64, imm32
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                if (ops.reg1.to64() == .rax) {
                    // TODO reduce the size of the instruction if the immediate
                    // is smaller than 32 bits
                    const encoder = try Encoder.init(emit.code, 6);
                    encoder.rex(.{
                        .w = true,
                    });
                    encoder.opcode_1byte(0xa9);
                    encoder.imm32(imm);
                    break :blk;
                }
                const opc: u8 = if (ops.reg1.size() == 8) 0xf6 else 0xf7;
                const encoder = try Encoder.init(emit.code, 7);
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
            return emit.fail("TODO TEST r/m64, r64", .{});
        },
        else => return emit.fail("TODO more TEST alternatives", .{}),
    }
}

fn mirRet(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .ret);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const encoder = try Encoder.init(emit.code, 3);
    switch (ops.flags) {
        0b00 => {
            // RETF imm16
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            encoder.opcode_1byte(0xca);
            encoder.imm16(@intCast(i16, imm));
        },
        0b01 => encoder.opcode_1byte(0xcb), // RETF
        0b10 => {
            // RET imm16
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            encoder.opcode_1byte(0xc2);
            encoder.imm16(@intCast(i16, imm));
        },
        0b11 => encoder.opcode_1byte(0xc3), // RET
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

fn mirArith(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => blk: {
            if (ops.reg2 == .none) {
                // OP reg1, imm32
                // OP r/m64, imm32
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                const opcode = getArithOpCode(tag, .mi);
                const encoder = try Encoder.init(emit.code, 7);
                encoder.rex(.{
                    .w = ops.reg1.size() == 64,
                    .b = ops.reg1.isExtended(),
                });
                if (tag != .mov and imm <= math.maxInt(i8)) {
                    encoder.opcode_1byte(opcode.opc + 2);
                    encoder.modRm_direct(opcode.modrm_ext, ops.reg1.lowId());
                    encoder.imm8(@intCast(i8, imm));
                } else {
                    encoder.opcode_1byte(opcode.opc);
                    encoder.modRm_direct(opcode.modrm_ext, ops.reg1.lowId());
                    encoder.imm32(imm);
                }
                break :blk;
            }
            // OP reg1, reg2
            // OP r/m64, r64
            const opcode = getArithOpCode(tag, .mr);
            const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
            const encoder = try Encoder.init(emit.code, 3);
            encoder.rex(.{
                .w = ops.reg1.size() == 64 and ops.reg2.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg2.isExtended(),
            });
            encoder.opcode_1byte(opc);
            encoder.modRm_direct(ops.reg1.lowId(), ops.reg2.lowId());
        },
        0b01 => blk: {
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const opcode = getArithOpCode(tag, .rm);
            const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
            if (ops.reg2 == .none) {
                // OP reg1, [imm32]
                // OP r64, r/m64
                const encoder = try Encoder.init(emit.code, 8);
                encoder.rex(.{
                    .w = ops.reg1.size() == 64,
                    .b = ops.reg1.isExtended(),
                });
                encoder.opcode_1byte(opc);
                encoder.modRm_SIBDisp0(ops.reg1.lowId());
                encoder.sib_disp32();
                encoder.disp32(imm);
                break :blk;
            }
            // OP reg1, [reg2 + imm32]
            // OP r64, r/m64
            const encoder = try Encoder.init(emit.code, 7);
            encoder.rex(.{
                .w = ops.reg1.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg2.isExtended(),
            });
            encoder.opcode_1byte(opc);
            if (imm <= math.maxInt(i8)) {
                encoder.modRm_indirectDisp8(ops.reg1.lowId(), ops.reg2.lowId());
                encoder.disp8(@intCast(i8, imm));
            } else {
                encoder.modRm_indirectDisp32(ops.reg1.lowId(), ops.reg2.lowId());
                encoder.disp32(imm);
            }
        },
        0b10 => blk: {
            if (ops.reg2 == .none) {
                // OP [reg1 + 0], imm32
                // OP r/m64, imm32
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                const opcode = getArithOpCode(tag, .mi);
                const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
                const encoder = try Encoder.init(emit.code, 7);
                encoder.rex(.{
                    .w = ops.reg1.size() == 64,
                    .b = ops.reg1.isExtended(),
                });
                encoder.opcode_1byte(opc);
                encoder.modRm_indirectDisp0(opcode.modrm_ext, ops.reg1.lowId());
                if (imm <= math.maxInt(i8)) {
                    encoder.imm8(@intCast(i8, imm));
                } else if (imm <= math.maxInt(i16)) {
                    encoder.imm16(@intCast(i16, imm));
                } else {
                    encoder.imm32(imm);
                }
                break :blk;
            }
            // OP [reg1 + imm32], reg2
            // OP r/m64, r64
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const opcode = getArithOpCode(tag, .mr);
            const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
            const encoder = try Encoder.init(emit.code, 7);
            encoder.rex(.{
                .w = ops.reg2.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg2.isExtended(),
            });
            encoder.opcode_1byte(opc);
            if (imm <= math.maxInt(i8)) {
                encoder.modRm_indirectDisp8(ops.reg1.lowId(), ops.reg2.lowId());
                encoder.disp8(@intCast(i8, imm));
            } else {
                encoder.modRm_indirectDisp32(ops.reg1.lowId(), ops.reg2.lowId());
                encoder.disp32(imm);
            }
        },
        0b11 => blk: {
            if (ops.reg2 == .none) {
                // OP [reg1 + imm32], imm32
                // OP r/m64, imm32
                const payload = emit.mir.instructions.items(.data)[inst].payload;
                const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
                const opcode = getArithOpCode(tag, .mi);
                const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
                const encoder = try Encoder.init(emit.code, 11);
                encoder.rex(.{
                    .w = false,
                    .b = ops.reg1.isExtended(),
                });
                encoder.opcode_1byte(opc);
                if (imm_pair.dest_off <= math.maxInt(i8)) {
                    encoder.modRm_indirectDisp8(opcode.modrm_ext, ops.reg1.lowId());
                    encoder.disp8(@intCast(i8, imm_pair.dest_off));
                } else {
                    encoder.modRm_indirectDisp32(opcode.modrm_ext, ops.reg1.lowId());
                    encoder.disp32(imm_pair.dest_off);
                }
                encoder.imm32(imm_pair.operand);
                break :blk;
            }
            // TODO clearly mov doesn't belong here; for other, arithemtic ops,
            // this is the same as 0b00.
            const opcode = getArithOpCode(tag, if (tag == .mov) .rm else .mr);
            const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
            const encoder = try Encoder.init(emit.code, 3);
            encoder.rex(.{
                .w = ops.reg1.size() == 64 and ops.reg2.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg2.isExtended(),
            });
            encoder.opcode_1byte(opc);
            encoder.modRm_direct(ops.reg1.lowId(), ops.reg2.lowId());
        },
    }
}

fn mirArithScaleSrc(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    // OP reg1, [reg2 + scale*rcx + imm32]
    const opcode = getArithOpCode(tag, .rm);
    const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
    const imm = emit.mir.instructions.items(.data)[inst].imm;
    const encoder = try Encoder.init(emit.code, 8);
    encoder.rex(.{
        .w = ops.reg1.size() == 64,
        .r = ops.reg1.isExtended(),
        .b = ops.reg2.isExtended(),
    });
    encoder.opcode_1byte(opc);
    if (imm <= math.maxInt(i8)) {
        encoder.modRm_SIBDisp8(ops.reg1.lowId());
        encoder.sib_scaleIndexBaseDisp8(scale, Register.rcx.lowId(), ops.reg2.lowId());
        encoder.disp8(@intCast(i8, imm));
    } else {
        encoder.modRm_SIBDisp32(ops.reg1.lowId());
        encoder.sib_scaleIndexBaseDisp32(scale, Register.rcx.lowId(), ops.reg2.lowId());
        encoder.disp32(imm);
    }
}

fn mirArithScaleDst(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const imm = emit.mir.instructions.items(.data)[inst].imm;

    if (ops.reg2 == .none) {
        // OP [reg1 + scale*rax + 0], imm32
        const opcode = getArithOpCode(tag, .mi);
        const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
        const encoder = try Encoder.init(emit.code, 8);
        encoder.rex(.{
            .w = ops.reg1.size() == 64,
            .b = ops.reg1.isExtended(),
        });
        encoder.opcode_1byte(opc);
        encoder.modRm_SIBDisp0(opcode.modrm_ext);
        encoder.sib_scaleIndexBase(scale, Register.rax.lowId(), ops.reg1.lowId());
        if (imm <= math.maxInt(i8)) {
            encoder.imm8(@intCast(i8, imm));
        } else if (imm <= math.maxInt(i16)) {
            encoder.imm16(@intCast(i16, imm));
        } else {
            encoder.imm32(imm);
        }
        return;
    }

    // OP [reg1 + scale*rax + imm32], reg2
    const opcode = getArithOpCode(tag, .mr);
    const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
    const encoder = try Encoder.init(emit.code, 8);
    encoder.rex(.{
        .w = ops.reg1.size() == 64,
        .r = ops.reg2.isExtended(),
        .b = ops.reg1.isExtended(),
    });
    encoder.opcode_1byte(opc);
    if (imm <= math.maxInt(i8)) {
        encoder.modRm_SIBDisp8(ops.reg2.lowId());
        encoder.sib_scaleIndexBaseDisp8(scale, Register.rax.lowId(), ops.reg1.lowId());
        encoder.disp8(@intCast(i8, imm));
    } else {
        encoder.modRm_SIBDisp32(ops.reg2.lowId());
        encoder.sib_scaleIndexBaseDisp32(scale, Register.rax.lowId(), ops.reg1.lowId());
        encoder.disp32(imm);
    }
}

fn mirArithScaleImm(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
    const opcode = getArithOpCode(tag, .mi);
    const opc = if (ops.reg1.size() == 8) opcode.opc - 1 else opcode.opc;
    const encoder = try Encoder.init(emit.code, 2);
    encoder.rex(.{
        .w = ops.reg1.size() == 64,
        .b = ops.reg1.isExtended(),
    });
    encoder.opcode_1byte(opc);
    if (imm_pair.dest_off <= math.maxInt(i8)) {
        encoder.modRm_SIBDisp8(opcode.modrm_ext);
        encoder.sib_scaleIndexBaseDisp8(scale, Register.rax.lowId(), ops.reg1.lowId());
        encoder.disp8(@intCast(i8, imm_pair.dest_off));
    } else {
        encoder.modRm_SIBDisp32(opcode.modrm_ext);
        encoder.sib_scaleIndexBaseDisp32(scale, Register.rax.lowId(), ops.reg1.lowId());
        encoder.disp32(imm_pair.dest_off);
    }
    encoder.imm32(imm_pair.operand);
}

fn mirMovabs(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .movabs);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);

    const encoder = try Encoder.init(emit.code, 10);
    const is_64 = blk: {
        if (ops.flags == 0b00) {
            // movabs reg, imm64
            const opc: u8 = if (ops.reg1.size() == 8) 0xb0 else 0xb8;
            if (ops.reg1.size() == 64) {
                encoder.rex(.{
                    .w = true,
                    .b = ops.reg1.isExtended(),
                });
                encoder.opcode_withReg(opc, ops.reg1.lowId());
                break :blk true;
            }
            break :blk false;
        }
        if (ops.reg1 == .none) {
            // movabs moffs64, rax
            const opc: u8 = if (ops.reg2.size() == 8) 0xa2 else 0xa3;
            encoder.rex(.{
                .w = ops.reg2.size() == 64,
            });
            encoder.opcode_1byte(opc);
            break :blk ops.reg2.size() == 64;
        } else {
            // movabs rax, moffs64
            const opc: u8 = if (ops.reg2.size() == 8) 0xa0 else 0xa1;
            encoder.rex(.{
                .w = ops.reg1.size() == 64,
            });
            encoder.opcode_1byte(opc);
            break :blk ops.reg1.size() == 64;
        }
    };

    if (is_64) {
        const payload = emit.mir.instructions.items(.data)[inst].payload;
        const imm64 = emit.mir.extraData(Mir.Imm64, payload).data;
        encoder.imm64(imm64.decode());
    } else {
        const imm = emit.mir.instructions.items(.data)[inst].imm;
        if (imm <= math.maxInt(i8)) {
            encoder.imm8(@intCast(i8, imm));
        } else if (imm <= math.maxInt(i16)) {
            encoder.imm16(@intCast(i16, imm));
        } else {
            encoder.imm32(imm);
        }
    }
}

fn mirIMulComplex(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .imul_complex);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            const encoder = try Encoder.init(emit.code, 4);
            encoder.rex(.{
                .w = ops.reg1.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg2.isExtended(),
            });
            encoder.opcode_2byte(0x0f, 0xaf);
            encoder.modRm_direct(ops.reg1.lowId(), ops.reg2.lowId());
        },
        0b10 => {
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const opc: u8 = if (imm <= math.maxInt(i8)) 0x6b else 0x69;
            const encoder = try Encoder.init(emit.code, 7);
            encoder.rex(.{
                .w = ops.reg1.size() == 64,
                .r = ops.reg1.isExtended(),
                .b = ops.reg1.isExtended(),
            });
            encoder.opcode_1byte(opc);
            encoder.modRm_direct(ops.reg1.lowId(), ops.reg2.lowId());
            if (imm <= math.maxInt(i8)) {
                encoder.imm8(@intCast(i8, imm));
            } else if (imm <= math.maxInt(i16)) {
                encoder.imm16(@intCast(i16, imm));
            } else {
                encoder.imm32(imm);
            }
        },
        else => return emit.fail("TODO implement imul", .{}),
    }
}

fn mirLea(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .lea);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    assert(ops.flags == 0b01);
    const imm = emit.mir.instructions.items(.data)[inst].imm;

    if (imm == 0) {
        const encoder = try Encoder.init(emit.code, 3);
        encoder.rex(.{
            .w = ops.reg1.size() == 64,
            .r = ops.reg1.isExtended(),
            .b = ops.reg2.isExtended(),
        });
        encoder.opcode_1byte(0x8d);
        encoder.modRm_indirectDisp0(ops.reg1.lowId(), ops.reg2.lowId());
    } else if (imm <= math.maxInt(i8)) {
        const encoder = try Encoder.init(emit.code, 4);
        encoder.rex(.{
            .w = ops.reg1.size() == 64,
            .r = ops.reg1.isExtended(),
            .b = ops.reg2.isExtended(),
        });
        encoder.opcode_1byte(0x8d);
        encoder.modRm_indirectDisp8(ops.reg1.lowId(), ops.reg2.lowId());
        encoder.disp8(@intCast(i8, imm));
    } else {
        const encoder = try Encoder.init(emit.code, 7);
        encoder.rex(.{
            .w = ops.reg1.size() == 64,
            .r = ops.reg1.isExtended(),
            .b = ops.reg2.isExtended(),
        });
        encoder.opcode_1byte(0x8d);
        encoder.modRm_indirectDisp32(ops.reg1.lowId(), ops.reg2.lowId());
        encoder.disp32(imm);
    }
}

fn mirLeaRip(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .lea_rip);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const start_offset = emit.code.items.len;
    const encoder = try Encoder.init(emit.code, 7);
    encoder.rex(.{
        .w = ops.reg1.size() == 64,
        .r = ops.reg1.isExtended(),
    });
    encoder.opcode_1byte(0x8d);
    encoder.modRm_RIPDisp32(ops.reg1.lowId());
    const end_offset = emit.code.items.len;
    if (@truncate(u1, ops.flags) == 0b0) {
        const payload = emit.mir.instructions.items(.data)[inst].payload;
        const imm = emit.mir.extraData(Mir.Imm64, payload).data.decode();
        encoder.disp32(@intCast(i32, @intCast(i64, imm) - @intCast(i64, end_offset - start_offset + 4)));
    } else {
        const got_entry = emit.mir.instructions.items(.data)[inst].got_entry;
        encoder.disp32(0);
        if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
            // TODO I think the reloc might be in the wrong place.
            const decl = macho_file.active_decl.?;
            try decl.link.macho.relocs.append(emit.bin_file.allocator, .{
                .offset = @intCast(u32, end_offset),
                .target = .{ .local = got_entry },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_GOT),
            });
        } else {
            return emit.fail("TODO implement lea_rip for linking backends different than MachO", .{});
        }
    }
}

fn mirCallExtern(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .call_extern);
    const n_strx = emit.mir.instructions.items(.data)[inst].extern_fn;
    const offset = blk: {
        const offset = @intCast(u32, emit.code.items.len + 1);
        // callq
        const encoder = try Encoder.init(emit.code, 5);
        encoder.opcode_1byte(0xe8);
        encoder.imm32(0x0);
        break :blk offset;
    };
    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        // Add relocation to the decl.
        try macho_file.active_decl.?.link.macho.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .global = n_strx },
            .addend = 0,
            .subtractor = null,
            .pcrel = true,
            .length = 2,
            .@"type" = @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_BRANCH),
        });
    } else {
        return emit.fail("TODO implement call_extern for linking backends different than MachO", .{});
    }
}

fn mirDbgLine(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .dbg_line);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const dbg_line_column = emit.mir.extraData(Mir.DbgLineColumn, payload).data;
    try emit.dbgAdvancePCAndLine(dbg_line_column.line, dbg_line_column.column);
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) InnerError!void {
    const delta_line = @intCast(i32, line) - @intCast(i32, emit.prev_di_line);
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    switch (emit.debug_output) {
        .dwarf => |dbg_out| {
            // TODO Look into using the DWARF special opcodes to compress this data.
            // It lets you emit single-byte opcodes that add different numbers to
            // both the PC and the line number at the same time.
            try dbg_out.dbg_line.ensureUnusedCapacity(11);
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_pc);
            leb128.writeULEB128(dbg_out.dbg_line.writer(), delta_pc) catch unreachable;
            if (delta_line != 0) {
                dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_line);
                leb128.writeILEB128(dbg_out.dbg_line.writer(), delta_line) catch unreachable;
            }
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.copy);
            emit.prev_di_pc = emit.code.items.len;
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes
            // we have already checked the target in the linker to make sure it is compatable
            const quant = @import("../../link/Plan9/aout.zig").getPCQuant(emit.target.cpu.arch) catch unreachable;

            // increasing the line number
            try @import("../../link/Plan9.zig").changeLine(dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @intCast(i64, delta_pc) - quant;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one quanta
                try dbg_out.dbg_line.append(@intCast(u8, @divExact(d_pc_p9, quant) + 128) - quant);
                if (dbg_out.pcop_change_index.*) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index.* = @intCast(u32, dbg_out.dbg_line.items.len - 1);
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the quant does it for us
            } else unreachable;
            if (dbg_out.start_line.* == null)
                dbg_out.start_line.* = emit.prev_di_line;
            dbg_out.end_line.* = line;
            // only do this if the pc changed
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

fn mirDbgPrologueEnd(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .dbg_prologue_end);
    switch (emit.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_prologue_end);
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDbgEpilogueBegin(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .dbg_epilogue_begin);
    switch (emit.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_epilogue_begin);
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirArgDbgInfo(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .arg_dbg_info);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const arg_dbg_info = emit.mir.extraData(Mir.ArgDbgInfo, payload).data;
    const mcv = emit.mir.function.args[arg_dbg_info.arg_index];
    try emit.genArgDbgInfo(arg_dbg_info.air_inst, mcv);
}

fn genArgDbgInfo(emit: *Emit, inst: Air.Inst.Index, mcv: MCValue) !void {
    const ty_str = emit.mir.function.air.instructions.items(.data)[inst].ty_str;
    const zir = &emit.mir.function.mod_fn.owner_decl.getFileScope().zir;
    const name = zir.nullTerminatedString(ty_str.str);
    const name_with_null = name.ptr[0 .. name.len + 1];
    const ty = emit.mir.function.air.getRefType(ty_str.ty);

    switch (mcv) {
        .register => |reg| {
            switch (emit.debug_output) {
                .dwarf => |dbg_out| {
                    try dbg_out.dbg_info.ensureUnusedCapacity(3);
                    dbg_out.dbg_info.appendAssumeCapacity(link.File.Elf.abbrev_parameter);
                    dbg_out.dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1, // ULEB128 dwarf expression length
                        reg.dwarfLocOp(),
                    });
                    try dbg_out.dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                    try emit.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                    dbg_out.dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
                },
                .plan9 => {},
                .none => {},
            }
        },
        .stack_offset => {
            switch (emit.debug_output) {
                .dwarf => {},
                .plan9 => {},
                .none => {},
            }
        },
        else => {},
    }
}

/// Adds a Type to the .debug_info at the current position. The bytes will be populated later,
/// after codegen for this symbol is done.
fn addDbgInfoTypeReloc(emit: *Emit, ty: Type) !void {
    switch (emit.debug_output) {
        .dwarf => |dbg_out| {
            assert(ty.hasCodeGenBits());
            const index = dbg_out.dbg_info.items.len;
            try dbg_out.dbg_info.resize(index + 4); // DW.AT.type,  DW.FORM.ref4

            const gop = try dbg_out.dbg_info_type_relocs.getOrPut(emit.bin_file.allocator, ty);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{
                    .off = undefined,
                    .relocs = .{},
                };
            }
            try gop.value_ptr.relocs.append(emit.bin_file.allocator, @intCast(u32, index));
        },
        .plan9 => {},
        .none => {},
    }
}
