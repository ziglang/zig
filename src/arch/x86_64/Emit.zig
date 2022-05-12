//! This file contains the functionality for lowering x86_64 MIR into
//! machine code

const Emit = @This();

const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const abi = @import("abi.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const Air = @import("../../Air.zig");
const Allocator = mem.Allocator;
const CodeGen = @import("CodeGen.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;
const Encoder = bits.Encoder;
const ErrorMsg = Module.ErrorMsg;
const MCValue = @import("CodeGen.zig").MCValue;
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Instruction = bits.Instruction;
const GpRegister = bits.Register;
const AvxRegister = bits.Register;
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
    EmitFail,
};

const Reloc = struct {
    /// Offset of the instruction.
    source: usize,
    /// Target of the relocation.
    target: Mir.Inst.Index,
    /// Offset of the relocation within the instruction.
    offset: usize,
    /// Length of the instruction.
    length: u5,
};

pub fn lowerMir(emit: *Emit) InnerError!void {
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
            .mov => try emit.mirArith(.mov, inst),

            .adc_mem_imm => try emit.mirArithMemImm(.adc, inst),
            .add_mem_imm => try emit.mirArithMemImm(.add, inst),
            .sub_mem_imm => try emit.mirArithMemImm(.sub, inst),
            .xor_mem_imm => try emit.mirArithMemImm(.xor, inst),
            .and_mem_imm => try emit.mirArithMemImm(.@"and", inst),
            .or_mem_imm => try emit.mirArithMemImm(.@"or", inst),
            .sbb_mem_imm => try emit.mirArithMemImm(.sbb, inst),
            .cmp_mem_imm => try emit.mirArithMemImm(.cmp, inst),
            .mov_mem_imm => try emit.mirArithMemImm(.mov, inst),

            .adc_scale_src => try emit.mirArithScaleSrc(.adc, inst),
            .add_scale_src => try emit.mirArithScaleSrc(.add, inst),
            .sub_scale_src => try emit.mirArithScaleSrc(.sub, inst),
            .xor_scale_src => try emit.mirArithScaleSrc(.xor, inst),
            .and_scale_src => try emit.mirArithScaleSrc(.@"and", inst),
            .or_scale_src => try emit.mirArithScaleSrc(.@"or", inst),
            .sbb_scale_src => try emit.mirArithScaleSrc(.sbb, inst),
            .cmp_scale_src => try emit.mirArithScaleSrc(.cmp, inst),
            .mov_scale_src => try emit.mirArithScaleSrc(.mov, inst),

            .adc_scale_dst => try emit.mirArithScaleDst(.adc, inst),
            .add_scale_dst => try emit.mirArithScaleDst(.add, inst),
            .sub_scale_dst => try emit.mirArithScaleDst(.sub, inst),
            .xor_scale_dst => try emit.mirArithScaleDst(.xor, inst),
            .and_scale_dst => try emit.mirArithScaleDst(.@"and", inst),
            .or_scale_dst => try emit.mirArithScaleDst(.@"or", inst),
            .sbb_scale_dst => try emit.mirArithScaleDst(.sbb, inst),
            .cmp_scale_dst => try emit.mirArithScaleDst(.cmp, inst),
            .mov_scale_dst => try emit.mirArithScaleDst(.mov, inst),

            .adc_scale_imm => try emit.mirArithScaleImm(.adc, inst),
            .add_scale_imm => try emit.mirArithScaleImm(.add, inst),
            .sub_scale_imm => try emit.mirArithScaleImm(.sub, inst),
            .xor_scale_imm => try emit.mirArithScaleImm(.xor, inst),
            .and_scale_imm => try emit.mirArithScaleImm(.@"and", inst),
            .or_scale_imm => try emit.mirArithScaleImm(.@"or", inst),
            .sbb_scale_imm => try emit.mirArithScaleImm(.sbb, inst),
            .cmp_scale_imm => try emit.mirArithScaleImm(.cmp, inst),
            .mov_scale_imm => try emit.mirArithScaleImm(.mov, inst),

            .adc_mem_index_imm => try emit.mirArithMemIndexImm(.adc, inst),
            .add_mem_index_imm => try emit.mirArithMemIndexImm(.add, inst),
            .sub_mem_index_imm => try emit.mirArithMemIndexImm(.sub, inst),
            .xor_mem_index_imm => try emit.mirArithMemIndexImm(.xor, inst),
            .and_mem_index_imm => try emit.mirArithMemIndexImm(.@"and", inst),
            .or_mem_index_imm => try emit.mirArithMemIndexImm(.@"or", inst),
            .sbb_mem_index_imm => try emit.mirArithMemIndexImm(.sbb, inst),
            .cmp_mem_index_imm => try emit.mirArithMemIndexImm(.cmp, inst),
            .mov_mem_index_imm => try emit.mirArithMemIndexImm(.mov, inst),

            .mov_sign_extend => try emit.mirMovSignExtend(inst),
            .mov_zero_extend => try emit.mirMovZeroExtend(inst),

            .movabs => try emit.mirMovabs(inst),

            .fisttp => try emit.mirFisttp(inst),
            .fld => try emit.mirFld(inst),

            .lea => try emit.mirLea(inst),
            .lea_pie => try emit.mirLeaPie(inst),

            .shl => try emit.mirShift(.shl, inst),
            .sal => try emit.mirShift(.sal, inst),
            .shr => try emit.mirShift(.shr, inst),
            .sar => try emit.mirShift(.sar, inst),

            .imul => try emit.mirMulDiv(.imul, inst),
            .mul => try emit.mirMulDiv(.mul, inst),
            .idiv => try emit.mirMulDiv(.idiv, inst),
            .div => try emit.mirMulDiv(.div, inst),
            .imul_complex => try emit.mirIMulComplex(inst),

            .cwd => try emit.mirCwd(inst),

            .push => try emit.mirPushPop(.push, inst),
            .pop => try emit.mirPushPop(.pop, inst),

            .jmp => try emit.mirJmpCall(.jmp_near, inst),
            .call => try emit.mirJmpCall(.call_near, inst),

            .cond_jmp_greater_less,
            .cond_jmp_above_below,
            .cond_jmp_eq_ne,
            => try emit.mirCondJmp(tag, inst),

            .cond_set_byte_greater_less,
            .cond_set_byte_above_below,
            .cond_set_byte_eq_ne,
            .cond_set_byte_overflow,
            => try emit.mirCondSetByte(tag, inst),

            .cond_mov_eq => try emit.mirCondMov(.cmove, inst),
            .cond_mov_lt => try emit.mirCondMov(.cmovl, inst),
            .cond_mov_below => try emit.mirCondMov(.cmovb, inst),

            .ret => try emit.mirRet(inst),

            .syscall => try emit.mirSyscall(),

            .@"test" => try emit.mirTest(inst),

            .interrupt => try emit.mirInterrupt(inst),
            .nop => try emit.mirNop(),

            .call_extern => try emit.mirCallExtern(inst),

            .dbg_line => try emit.mirDbgLine(inst),
            .dbg_prologue_end => try emit.mirDbgPrologueEnd(inst),
            .dbg_epilogue_begin => try emit.mirDbgEpilogueBegin(inst),

            .push_regs_from_callee_preserved_regs => try emit.mirPushPopRegsFromCalleePreservedRegs(.push, inst),
            .pop_regs_from_callee_preserved_regs => try emit.mirPushPopRegsFromCalleePreservedRegs(.pop, inst),

            else => {
                return emit.fail("Implement MIR->Emit lowering for x86_64 for pseudo-inst: {s}", .{tag});
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
        const target = emit.code_offset_mapping.get(reloc.target) orelse
            return emit.fail("JMP/CALL relocation target not found!", .{});
        const disp = @intCast(i32, @intCast(i64, target) - @intCast(i64, reloc.source + reloc.length));
        mem.writeIntLittle(i32, emit.code.items[reloc.offset..][0..4], disp);
    }
}

fn mirInterrupt(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .interrupt);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => return lowerToZoEnc(.int3, emit.code),
        else => return emit.fail("TODO handle variant 0b{b} of interrupt instruction", .{ops.flags}),
    }
}

fn mirNop(emit: *Emit) InnerError!void {
    return lowerToZoEnc(.nop, emit.code);
}

fn mirSyscall(emit: *Emit) InnerError!void {
    return lowerToZoEnc(.syscall, emit.code);
}

fn mirPushPop(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // PUSH/POP reg
            return lowerToOEnc(tag, Register.reg(ops.reg1), emit.code);
        },
        0b01 => {
            // PUSH/POP r/m64
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const ptr_size: Memory.PtrSize = switch (immOpSize(imm)) {
                16 => .word_ptr,
                else => .qword_ptr,
            };
            return lowerToMEnc(tag, RegisterOrMemory.mem(ptr_size, .{
                .disp = imm,
                .base = ops.reg1,
            }), emit.code);
        },
        0b10 => {
            // PUSH imm32
            assert(tag == .push);
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToIEnc(.push, imm, emit.code);
        },
        0b11 => unreachable,
    }
}

fn mirPushPopRegsFromCalleePreservedRegs(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const data = emit.mir.extraData(Mir.RegsToPushOrPop, payload).data;
    const regs = data.regs;
    var disp: u32 = data.disp + 8;
    for (abi.callee_preserved_regs) |reg, i| {
        if ((regs >> @intCast(u5, i)) & 1 == 0) continue;
        if (tag == .push) {
            try lowerToMrEnc(.mov, RegisterOrMemory.mem(.qword_ptr, .{
                .disp = @bitCast(u32, -@intCast(i32, disp)),
                .base = ops.reg1,
            }), Register.reg(reg.to64()), emit.code);
        } else {
            try lowerToRmEnc(.mov, Register.reg(reg.to64()), RegisterOrMemory.mem(.qword_ptr, .{
                .disp = @bitCast(u32, -@intCast(i32, disp)),
                .base = ops.reg1,
            }), emit.code);
        }
        disp += 8;
    }
}

fn mirJmpCall(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            const target = emit.mir.instructions.items(.data)[inst].inst;
            const source = emit.code.items.len;
            try lowerToDEnc(tag, 0, emit.code);
            try emit.relocs.append(emit.bin_file.allocator, .{
                .source = source,
                .target = target,
                .offset = emit.code.items.len - 4,
                .length = 5,
            });
        },
        0b01 => {
            if (ops.reg1 == .none) {
                // JMP/CALL [imm]
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                const ptr_size: Memory.PtrSize = switch (immOpSize(imm)) {
                    16 => .word_ptr,
                    else => .qword_ptr,
                };
                return lowerToMEnc(tag, RegisterOrMemory.mem(ptr_size, .{ .disp = imm }), emit.code);
            }
            // JMP/CALL reg
            return lowerToMEnc(tag, RegisterOrMemory.reg(ops.reg1), emit.code);
        },
        0b10 => {
            // JMP/CALL r/m64
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToMEnc(tag, RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg1.size()), .{
                .disp = imm,
                .base = ops.reg1,
            }), emit.code);
        },
        0b11 => return emit.fail("TODO unused JMP/CALL variant 0b11", .{}),
    }
}

fn mirCondJmp(emit: *Emit, mir_tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const target = emit.mir.instructions.items(.data)[inst].inst;
    const tag = switch (mir_tag) {
        .cond_jmp_greater_less => switch (ops.flags) {
            0b00 => Tag.jge,
            0b01 => Tag.jg,
            0b10 => Tag.jl,
            0b11 => Tag.jle,
        },
        .cond_jmp_above_below => switch (ops.flags) {
            0b00 => Tag.jae,
            0b01 => Tag.ja,
            0b10 => Tag.jb,
            0b11 => Tag.jbe,
        },
        .cond_jmp_eq_ne => switch (@truncate(u1, ops.flags)) {
            0b0 => Tag.jne,
            0b1 => Tag.je,
        },
        else => unreachable,
    };
    const source = emit.code.items.len;
    try lowerToDEnc(tag, 0, emit.code);
    try emit.relocs.append(emit.bin_file.allocator, .{
        .source = source,
        .target = target,
        .offset = emit.code.items.len - 4,
        .length = 6,
    });
}

fn mirCondSetByte(emit: *Emit, mir_tag: Mir.Inst.Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const tag = switch (mir_tag) {
        .cond_set_byte_greater_less => switch (ops.flags) {
            0b00 => Tag.setge,
            0b01 => Tag.setg,
            0b10 => Tag.setl,
            0b11 => Tag.setle,
        },
        .cond_set_byte_above_below => switch (ops.flags) {
            0b00 => Tag.setae,
            0b01 => Tag.seta,
            0b10 => Tag.setb,
            0b11 => Tag.setbe,
        },
        .cond_set_byte_eq_ne => switch (@truncate(u1, ops.flags)) {
            0b0 => Tag.setne,
            0b1 => Tag.sete,
        },
        .cond_set_byte_overflow => switch (ops.flags) {
            0b00 => Tag.seto,
            0b01 => Tag.setno,
            0b10 => Tag.setc,
            0b11 => Tag.setnc,
        },
        else => unreachable,
    };
    return lowerToMEnc(tag, RegisterOrMemory.reg(ops.reg1.to8()), emit.code);
}

fn mirCondMov(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    if (ops.flags == 0b00) {
        return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), emit.code);
    }
    const imm = emit.mir.instructions.items(.data)[inst].imm;
    const ptr_size: Memory.PtrSize = switch (ops.flags) {
        0b00 => unreachable,
        0b01 => .word_ptr,
        0b10 => .dword_ptr,
        0b11 => .qword_ptr,
    };
    return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.mem(ptr_size, .{
        .disp = imm,
        .base = ops.reg2,
    }), emit.code);
}

fn mirTest(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .@"test");
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            if (ops.reg2 == .none) {
                // TEST r/m64, imm32
                // MI
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                if (ops.reg1.to64() == .rax) {
                    // TEST rax, imm32
                    // I
                    return lowerToIEnc(.@"test", imm, emit.code);
                }
                return lowerToMiEnc(.@"test", RegisterOrMemory.reg(ops.reg1), imm, emit.code);
            }
            // TEST r/m64, r64
            return lowerToMrEnc(
                .@"test",
                RegisterOrMemory.reg(ops.reg1),
                Register.reg(ops.reg2),
                emit.code,
            );
        },
        else => return emit.fail("TODO more TEST alternatives", .{}),
    }
}

fn mirRet(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .ret);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // RETF imm16
            // I
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToIEnc(.ret_far, imm, emit.code);
        },
        0b01 => {
            return lowerToZoEnc(.ret_far, emit.code);
        },
        0b10 => {
            // RET imm16
            // I
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToIEnc(.ret_near, imm, emit.code);
        },
        0b11 => {
            return lowerToZoEnc(.ret_near, emit.code);
        },
    }
}

fn mirArith(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            if (ops.reg2 == .none) {
                // mov reg1, imm32
                // MI
                const imm = emit.mir.instructions.items(.data)[inst].imm;
                return lowerToMiEnc(tag, RegisterOrMemory.reg(ops.reg1), imm, emit.code);
            }
            // mov reg1, reg2
            // RM
            return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), emit.code);
        },
        0b01 => {
            // mov reg1, [reg2 + imm32]
            // RM
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const src_reg: ?GpRegister = if (ops.reg2 == .none) null else ops.reg2;
            return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg1.size()), .{
                .disp = imm,
                .base = src_reg,
            }), emit.code);
        },
        0b10 => {
            if (ops.reg2 == .none) {
                return emit.fail("TODO unused variant: mov reg1, none, 0b10", .{});
            }
            // mov [reg1 + imm32], reg2
            // MR
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToMrEnc(tag, RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg2.size()), .{
                .disp = imm,
                .base = ops.reg1,
            }), Register.reg(ops.reg2), emit.code);
        },
        0b11 => {
            return emit.fail("TODO unused variant: mov reg1, reg2, 0b11", .{});
        },
    }
}

fn mirArithMemImm(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    assert(ops.reg2 == .none);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
    const ptr_size: Memory.PtrSize = switch (ops.flags) {
        0b00 => .byte_ptr,
        0b01 => .word_ptr,
        0b10 => .dword_ptr,
        0b11 => .qword_ptr,
    };
    return lowerToMiEnc(tag, RegisterOrMemory.mem(ptr_size, .{
        .disp = imm_pair.dest_off,
        .base = ops.reg1,
    }), imm_pair.operand, emit.code);
}

inline fn setRexWRegister(reg: Register) bool {
    switch (reg) {
        .avx_register => return false,
        .register => |r| {
            if (r.size() == 64) return true;
            return switch (r) {
                .ah, .bh, .ch, .dh => true,
                else => false,
            };
        },
    }
}

inline fn immOpSize(u_imm: u32) u8 {
    const imm = @bitCast(i32, u_imm);
    if (math.minInt(i8) <= imm and imm <= math.maxInt(i8)) {
        return 8;
    }
    if (math.minInt(i16) <= imm and imm <= math.maxInt(i16)) {
        return 16;
    }
    return 32;
}

fn mirArithScaleSrc(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const imm = emit.mir.instructions.items(.data)[inst].imm;
    // OP reg1, [reg2 + scale*rcx + imm32]
    const scale_index = ScaleIndex{
        .scale = scale,
        .index = .rcx,
    };
    return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg1.size()), .{
        .disp = imm,
        .base = ops.reg2,
        .scale_index = scale_index,
    }), emit.code);
}

fn mirArithScaleDst(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const imm = emit.mir.instructions.items(.data)[inst].imm;
    const scale_index = ScaleIndex{
        .scale = scale,
        .index = .rax,
    };
    if (ops.reg2 == .none) {
        // OP qword ptr [reg1 + scale*rax + 0], imm32
        return lowerToMiEnc(tag, RegisterOrMemory.mem(.qword_ptr, .{
            .disp = 0,
            .base = ops.reg1,
            .scale_index = scale_index,
        }), imm, emit.code);
    }
    // OP [reg1 + scale*rax + imm32], reg2
    return lowerToMrEnc(tag, RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg2.size()), .{
        .disp = imm,
        .base = ops.reg1,
        .scale_index = scale_index,
    }), Register.reg(ops.reg2), emit.code);
}

fn mirArithScaleImm(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const scale = ops.flags;
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
    const scale_index = ScaleIndex{
        .scale = scale,
        .index = .rax,
    };
    // OP qword ptr [reg1 + scale*rax + imm32], imm32
    return lowerToMiEnc(tag, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = imm_pair.dest_off,
        .base = ops.reg1,
        .scale_index = scale_index,
    }), imm_pair.operand, emit.code);
}

fn mirArithMemIndexImm(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    assert(ops.reg2 == .none);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
    const ptr_size: Memory.PtrSize = switch (ops.flags) {
        0b00 => .byte_ptr,
        0b01 => .word_ptr,
        0b10 => .dword_ptr,
        0b11 => .qword_ptr,
    };
    const scale_index = ScaleIndex{
        .scale = 0,
        .index = .rax,
    };
    // OP ptr [reg1 + rax*1 + imm32], imm32
    return lowerToMiEnc(tag, RegisterOrMemory.mem(ptr_size, .{
        .disp = imm_pair.dest_off,
        .base = ops.reg1,
        .scale_index = scale_index,
    }), imm_pair.operand, emit.code);
}

fn mirMovSignExtend(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const mir_tag = emit.mir.instructions.items(.tag)[inst];
    assert(mir_tag == .mov_sign_extend);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const imm = if (ops.flags != 0b00) emit.mir.instructions.items(.data)[inst].imm else undefined;
    switch (ops.flags) {
        0b00 => {
            const tag: Tag = if (ops.reg2.size() == 32) .movsxd else .movsx;
            return lowerToRmEnc(tag, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), emit.code);
        },
        0b01 => {
            return lowerToRmEnc(.movsx, Register.reg(ops.reg1), RegisterOrMemory.mem(.byte_ptr, .{
                .disp = imm,
                .base = ops.reg2,
            }), emit.code);
        },
        0b10 => {
            return lowerToRmEnc(.movsx, Register.reg(ops.reg1), RegisterOrMemory.mem(.word_ptr, .{
                .disp = imm,
                .base = ops.reg2,
            }), emit.code);
        },
        0b11 => {
            return lowerToRmEnc(.movsxd, Register.reg(ops.reg1), RegisterOrMemory.mem(.dword_ptr, .{
                .disp = imm,
                .base = ops.reg2,
            }), emit.code);
        },
    }
}

fn mirMovZeroExtend(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const mir_tag = emit.mir.instructions.items(.tag)[inst];
    assert(mir_tag == .mov_zero_extend);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const imm = if (ops.flags != 0b00) emit.mir.instructions.items(.data)[inst].imm else undefined;
    switch (ops.flags) {
        0b00 => {
            return lowerToRmEnc(.movzx, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), emit.code);
        },
        0b01 => {
            return lowerToRmEnc(.movzx, Register.reg(ops.reg1), RegisterOrMemory.mem(.byte_ptr, .{
                .disp = imm,
                .base = ops.reg2,
            }), emit.code);
        },
        0b10 => {
            return lowerToRmEnc(.movzx, Register.reg(ops.reg1), RegisterOrMemory.mem(.word_ptr, .{
                .disp = imm,
                .base = ops.reg2,
            }), emit.code);
        },
        0b11 => {
            return emit.fail("TODO unused variant: movzx 0b11", .{});
        },
    }
}

fn mirMovabs(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .movabs);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const imm: u64 = if (ops.reg1.size() == 64) blk: {
        const payload = emit.mir.instructions.items(.data)[inst].payload;
        const imm = emit.mir.extraData(Mir.Imm64, payload).data;
        break :blk imm.decode();
    } else emit.mir.instructions.items(.data)[inst].imm;
    if (ops.flags == 0b00) {
        // movabs reg, imm64
        // OI
        return lowerToOiEnc(.mov, Register.reg(ops.reg1), imm, emit.code);
    }
    if (ops.reg1 == .none) {
        // movabs moffs64, rax
        // TD
        return lowerToTdEnc(.mov, imm, Register.reg(ops.reg2), emit.code);
    }
    // movabs rax, moffs64
    // FD
    return lowerToFdEnc(.mov, Register.reg(ops.reg1), imm, emit.code);
}

fn mirFisttp(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .fisttp);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);

    // the selecting between operand sizes for this particular `fisttp` instruction
    // is done via opcode instead of the usual prefixes.

    const opcode: Tag = switch (ops.flags) {
        0b00 => .fisttp16,
        0b01 => .fisttp32,
        0b10 => .fisttp64,
        else => unreachable,
    };
    const mem_or_reg = Memory{
        .base = ops.reg1,
        .disp = emit.mir.instructions.items(.data)[inst].imm,
        .ptr_size = Memory.PtrSize.dword_ptr, // to prevent any prefix from being used
    };
    return lowerToMEnc(opcode, .{ .memory = mem_or_reg }, emit.code);
}

fn mirFld(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .fld);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);

    // the selecting between operand sizes for this particular `fisttp` instruction
    // is done via opcode instead of the usual prefixes.

    const opcode: Tag = switch (ops.flags) {
        0b01 => .fld32,
        0b10 => .fld64,
        else => unreachable,
    };
    const mem_or_reg = Memory{
        .base = ops.reg1,
        .disp = emit.mir.instructions.items(.data)[inst].imm,
        .ptr_size = Memory.PtrSize.dword_ptr, // to prevent any prefix from being used
    };
    return lowerToMEnc(opcode, .{ .memory = mem_or_reg }, emit.code);
}
fn mirShift(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // sal reg1, 1
            // M1
            return lowerToM1Enc(tag, RegisterOrMemory.reg(ops.reg1), emit.code);
        },
        0b01 => {
            // sal reg1, .cl
            // MC
            return lowerToMcEnc(tag, RegisterOrMemory.reg(ops.reg1), emit.code);
        },
        0b10 => {
            // sal reg1, imm8
            // MI
            const imm = @truncate(u8, emit.mir.instructions.items(.data)[inst].imm);
            return lowerToMiImm8Enc(tag, RegisterOrMemory.reg(ops.reg1), imm, emit.code);
        },
        0b11 => {
            return emit.fail("TODO unused variant: SHIFT reg1, 0b11", .{});
        },
    }
}

fn mirMulDiv(emit: *Emit, tag: Tag, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    if (ops.reg1 != .none) {
        assert(ops.reg2 == .none);
        return lowerToMEnc(tag, RegisterOrMemory.reg(ops.reg1), emit.code);
    }
    assert(ops.reg1 == .none);
    assert(ops.reg2 != .none);
    const imm = emit.mir.instructions.items(.data)[inst].imm;
    const ptr_size: Memory.PtrSize = switch (ops.flags) {
        0b00 => .byte_ptr,
        0b01 => .word_ptr,
        0b10 => .dword_ptr,
        0b11 => .qword_ptr,
    };
    return lowerToMEnc(tag, RegisterOrMemory.mem(ptr_size, .{
        .disp = imm,
        .base = ops.reg2,
    }), emit.code);
}

fn mirIMulComplex(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .imul_complex);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            return lowerToRmEnc(.imul, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), emit.code);
        },
        0b01 => {
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const src_reg: ?GpRegister = if (ops.reg2 == .none) null else ops.reg2;
            return lowerToRmEnc(.imul, Register.reg(ops.reg1), RegisterOrMemory.mem(.qword_ptr, .{
                .disp = imm,
                .base = src_reg,
            }), emit.code);
        },
        0b10 => {
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            return lowerToRmiEnc(.imul, Register.reg(ops.reg1), RegisterOrMemory.reg(ops.reg2), imm, emit.code);
        },
        0b11 => {
            const payload = emit.mir.instructions.items(.data)[inst].payload;
            const imm_pair = emit.mir.extraData(Mir.ImmPair, payload).data;
            return lowerToRmiEnc(.imul, Register.reg(ops.reg1), RegisterOrMemory.mem(.qword_ptr, .{
                .disp = imm_pair.dest_off,
                .base = ops.reg2,
            }), imm_pair.operand, emit.code);
        },
    }
}

fn mirCwd(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const tag: Tag = switch (ops.flags) {
        0b00 => .cbw,
        0b01 => .cwd,
        0b10 => .cdq,
        0b11 => .cqo,
    };
    return lowerToZoEnc(tag, emit.code);
}

fn mirLea(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .lea);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    switch (ops.flags) {
        0b00 => {
            // lea reg1, [reg2 + imm32]
            // RM
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const src_reg: ?GpRegister = if (ops.reg2 == .none) null else ops.reg2;
            return lowerToRmEnc(
                .lea,
                Register.reg(ops.reg1),
                RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg1.size()), .{
                    .disp = imm,
                    .base = src_reg,
                }),
                emit.code,
            );
        },
        0b01 => {
            // lea reg1, [rip + imm32]
            // RM
            const start_offset = emit.code.items.len;
            try lowerToRmEnc(
                .lea,
                Register.reg(ops.reg1),
                RegisterOrMemory.rip(Memory.PtrSize.fromBits(ops.reg1.size()), 0),
                emit.code,
            );
            const end_offset = emit.code.items.len;
            // Backpatch the displacement
            const payload = emit.mir.instructions.items(.data)[inst].payload;
            const imm = emit.mir.extraData(Mir.Imm64, payload).data.decode();
            const disp = @intCast(i32, @intCast(i64, imm) - @intCast(i64, end_offset - start_offset));
            mem.writeIntLittle(i32, emit.code.items[end_offset - 4 ..][0..4], disp);
        },
        0b10 => {
            // lea reg, [rbp + rcx + imm32]
            const imm = emit.mir.instructions.items(.data)[inst].imm;
            const src_reg: ?GpRegister = if (ops.reg2 == .none) null else ops.reg2;
            const scale_index = ScaleIndex{
                .scale = 0,
                .index = .rcx,
            };
            return lowerToRmEnc(
                .lea,
                Register.reg(ops.reg1),
                RegisterOrMemory.mem(Memory.PtrSize.fromBits(ops.reg1.size()), .{
                    .disp = imm,
                    .base = src_reg,
                    .scale_index = scale_index,
                }),
                emit.code,
            );
        },
        0b11 => return emit.fail("TODO unused LEA variant 0b11", .{}),
    }
}

fn mirLeaPie(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .lea_pie);
    const ops = Mir.Ops.decode(emit.mir.instructions.items(.ops)[inst]);
    const load_reloc = emit.mir.instructions.items(.data)[inst].load_reloc;

    // lea reg1, [rip + reloc]
    // RM
    try lowerToRmEnc(
        .lea,
        Register.reg(ops.reg1),
        RegisterOrMemory.rip(Memory.PtrSize.fromBits(ops.reg1.size()), 0),
        emit.code,
    );

    const end_offset = emit.code.items.len;

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        const reloc_type = switch (ops.flags) {
            0b00 => @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_GOT),
            0b01 => @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_SIGNED),
            else => return emit.fail("TODO unused LEA PIE variants 0b10 and 0b11", .{}),
        };
        const atom = macho_file.atom_by_index_table.get(load_reloc.atom_index).?;
        log.debug("adding reloc of type {} to local @{d}", .{ reloc_type, load_reloc.sym_index });
        try atom.relocs.append(emit.bin_file.allocator, .{
            .offset = @intCast(u32, end_offset - 4),
            .target = .{ .local = load_reloc.sym_index },
            .addend = 0,
            .subtractor = null,
            .pcrel = true,
            .length = 2,
            .@"type" = reloc_type,
        });
    } else {
        return emit.fail(
            "TODO implement lea reg, [rip + reloc] for linking backends different than MachO",
            .{},
        );
    }
}

fn mirCallExtern(emit: *Emit, inst: Mir.Inst.Index) InnerError!void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    assert(tag == .call_extern);
    const extern_fn = emit.mir.instructions.items(.data)[inst].extern_fn;

    const offset = blk: {
        // callq
        try lowerToDEnc(.call_near, 0, emit.code);
        break :blk @intCast(u32, emit.code.items.len) - 4;
    };

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        // Add relocation to the decl.
        const atom = macho_file.atom_by_index_table.get(extern_fn.atom_index).?;
        try atom.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .global = extern_fn.sym_name },
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
    log.debug("mirDbgLine", .{});
    try emit.dbgAdvancePCAndLine(dbg_line_column.line, dbg_line_column.column);
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) InnerError!void {
    const delta_line = @intCast(i32, line) - @intCast(i32, emit.prev_di_line);
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("  (advance pc={d} and line={d})", .{ delta_line, delta_pc });
    switch (emit.debug_output) {
        .dwarf => |dw| {
            // TODO Look into using the DWARF special opcodes to compress this data.
            // It lets you emit single-byte opcodes that add different numbers to
            // both the PC and the line number at the same time.
            const dbg_line = &dw.dbg_line;
            try dbg_line.ensureUnusedCapacity(11);
            dbg_line.appendAssumeCapacity(DW.LNS.advance_pc);
            leb128.writeULEB128(dbg_line.writer(), delta_pc) catch unreachable;
            if (delta_line != 0) {
                dbg_line.appendAssumeCapacity(DW.LNS.advance_line);
                leb128.writeILEB128(dbg_line.writer(), delta_line) catch unreachable;
            }
            dbg_line.appendAssumeCapacity(DW.LNS.copy);
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
                var diff = @divExact(d_pc_p9, quant) - quant;
                while (diff > 0) {
                    if (diff < 64) {
                        try dbg_out.dbg_line.append(@intCast(u8, diff + 128));
                        diff = 0;
                    } else {
                        try dbg_out.dbg_line.append(@intCast(u8, 64 + 128));
                        diff -= 64;
                    }
                }
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
        .dwarf => |dw| {
            try dw.dbg_line.append(DW.LNS.set_prologue_end);
            log.debug("mirDbgPrologueEnd (line={d}, col={d})", .{ emit.prev_di_line, emit.prev_di_column });
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
        .dwarf => |dw| {
            try dw.dbg_line.append(DW.LNS.set_epilogue_begin);
            log.debug("mirDbgEpilogueBegin (line={d}, col={d})", .{ emit.prev_di_line, emit.prev_di_column });
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

const Tag = enum {
    adc,
    add,
    sub,
    xor,
    @"and",
    @"or",
    sbb,
    cmp,
    mov,
    movsx,
    movsxd,
    movzx,
    lea,
    jmp_near,
    call_near,
    push,
    pop,
    @"test",
    int3,
    nop,
    imul,
    mul,
    idiv,
    div,
    syscall,
    ret_near,
    ret_far,
    fisttp16,
    fisttp32,
    fisttp64,
    fld32,
    fld64,
    jo,
    jno,
    jb,
    jbe,
    jc,
    jnae,
    jnc,
    jae,
    je,
    jz,
    jne,
    jnz,
    jna,
    jnb,
    jnbe,
    ja,
    js,
    jns,
    jpe,
    jp,
    jpo,
    jnp,
    jnge,
    jl,
    jge,
    jnl,
    jle,
    jng,
    jg,
    jnle,
    seto,
    setno,
    setb,
    setc,
    setnae,
    setnb,
    setnc,
    setae,
    sete,
    setz,
    setne,
    setnz,
    setbe,
    setna,
    seta,
    setnbe,
    sets,
    setns,
    setp,
    setpe,
    setnp,
    setop,
    setl,
    setnge,
    setnl,
    setge,
    setle,
    setng,
    setnle,
    setg,
    shl,
    sal,
    shr,
    sar,
    cbw,
    cwd,
    cdq,
    cqo,
    cmove,
    cmovz,
    cmovl,
    cmovng,
    cmovb,
    cmovnae,

    fn isSetCC(tag: Tag) bool {
        return switch (tag) {
            .seto,
            .setno,
            .setb,
            .setc,
            .setnae,
            .setnb,
            .setnc,
            .setae,
            .sete,
            .setz,
            .setne,
            .setnz,
            .setbe,
            .setna,
            .seta,
            .setnbe,
            .sets,
            .setns,
            .setp,
            .setpe,
            .setnp,
            .setop,
            .setl,
            .setnge,
            .setnl,
            .setge,
            .setle,
            .setng,
            .setnle,
            .setg,
            => true,
            else => false,
        };
    }
};

const Encoding = enum {
    /// OP
    zo,

    /// OP rel32
    d,

    /// OP r/m64
    m,

    /// OP r64
    o,

    /// OP imm32
    i,

    /// OP r/m64, 1
    m1,

    /// OP r/m64, .cl
    mc,

    /// OP r/m64, imm32
    mi,

    /// OP r/m64, imm8
    mi8,

    /// OP r/m64, r64
    mr,

    /// OP r64, r/m64
    rm,

    /// OP r64, imm64
    oi,

    /// OP al/ax/eax/rax, moffs
    fd,

    /// OP moffs, al/ax/eax/rax
    td,

    /// OP r64, r/m64, imm32
    rmi,
};

const OpCode = union(enum) {
    one_byte: u8,
    two_byte: struct { _1: u8, _2: u8 },

    fn oneByte(opc: u8) OpCode {
        return .{ .one_byte = opc };
    }

    fn twoByte(opc1: u8, opc2: u8) OpCode {
        return .{ .two_byte = .{ ._1 = opc1, ._2 = opc2 } };
    }

    fn encode(opc: OpCode, encoder: Encoder) void {
        switch (opc) {
            .one_byte => |v| encoder.opcode_1byte(v),
            .two_byte => |v| encoder.opcode_2byte(v._1, v._2),
        }
    }

    fn encodeWithReg(opc: OpCode, encoder: Encoder, reg: Register) void {
        assert(opc == .one_byte);
        encoder.opcode_withReg(opc.one_byte, reg.lowId());
    }
};

inline fn getOpCode(tag: Tag, enc: Encoding, is_one_byte: bool) ?OpCode {
    switch (enc) {
        .zo => return switch (tag) {
            .ret_near => OpCode.oneByte(0xc3),
            .ret_far => OpCode.oneByte(0xcb),
            .int3 => OpCode.oneByte(0xcc),
            .nop => OpCode.oneByte(0x90),
            .syscall => OpCode.twoByte(0x0f, 0x05),
            .cbw => OpCode.oneByte(0x98),
            .cwd, .cdq, .cqo => OpCode.oneByte(0x99),
            else => null,
        },
        .d => return switch (tag) {
            .jmp_near => OpCode.oneByte(0xe9),
            .call_near => OpCode.oneByte(0xe8),
            .jo => if (is_one_byte) OpCode.oneByte(0x70) else OpCode.twoByte(0x0f, 0x80),
            .jno => if (is_one_byte) OpCode.oneByte(0x71) else OpCode.twoByte(0x0f, 0x81),
            .jb, .jc, .jnae => if (is_one_byte) OpCode.oneByte(0x72) else OpCode.twoByte(0x0f, 0x82),
            .jnb, .jnc, .jae => if (is_one_byte) OpCode.oneByte(0x73) else OpCode.twoByte(0x0f, 0x83),
            .je, .jz => if (is_one_byte) OpCode.oneByte(0x74) else OpCode.twoByte(0x0f, 0x84),
            .jne, .jnz => if (is_one_byte) OpCode.oneByte(0x75) else OpCode.twoByte(0x0f, 0x85),
            .jna, .jbe => if (is_one_byte) OpCode.oneByte(0x76) else OpCode.twoByte(0x0f, 0x86),
            .jnbe, .ja => if (is_one_byte) OpCode.oneByte(0x77) else OpCode.twoByte(0x0f, 0x87),
            .js => if (is_one_byte) OpCode.oneByte(0x78) else OpCode.twoByte(0x0f, 0x88),
            .jns => if (is_one_byte) OpCode.oneByte(0x79) else OpCode.twoByte(0x0f, 0x89),
            .jpe, .jp => if (is_one_byte) OpCode.oneByte(0x7a) else OpCode.twoByte(0x0f, 0x8a),
            .jpo, .jnp => if (is_one_byte) OpCode.oneByte(0x7b) else OpCode.twoByte(0x0f, 0x8b),
            .jnge, .jl => if (is_one_byte) OpCode.oneByte(0x7c) else OpCode.twoByte(0x0f, 0x8c),
            .jge, .jnl => if (is_one_byte) OpCode.oneByte(0x7d) else OpCode.twoByte(0x0f, 0x8d),
            .jle, .jng => if (is_one_byte) OpCode.oneByte(0x7e) else OpCode.twoByte(0x0f, 0x8e),
            .jg, .jnle => if (is_one_byte) OpCode.oneByte(0x7f) else OpCode.twoByte(0x0f, 0x8f),
            else => null,
        },
        .m => return switch (tag) {
            .jmp_near, .call_near, .push => OpCode.oneByte(0xff),
            .pop => OpCode.oneByte(0x8f),
            .seto => OpCode.twoByte(0x0f, 0x90),
            .setno => OpCode.twoByte(0x0f, 0x91),
            .setb, .setc, .setnae => OpCode.twoByte(0x0f, 0x92),
            .setnb, .setnc, .setae => OpCode.twoByte(0x0f, 0x93),
            .sete, .setz => OpCode.twoByte(0x0f, 0x94),
            .setne, .setnz => OpCode.twoByte(0x0f, 0x95),
            .setbe, .setna => OpCode.twoByte(0x0f, 0x96),
            .seta, .setnbe => OpCode.twoByte(0x0f, 0x97),
            .sets => OpCode.twoByte(0x0f, 0x98),
            .setns => OpCode.twoByte(0x0f, 0x99),
            .setp, .setpe => OpCode.twoByte(0x0f, 0x9a),
            .setnp, .setop => OpCode.twoByte(0x0f, 0x9b),
            .setl, .setnge => OpCode.twoByte(0x0f, 0x9c),
            .setnl, .setge => OpCode.twoByte(0x0f, 0x9d),
            .setle, .setng => OpCode.twoByte(0x0f, 0x9e),
            .setnle, .setg => OpCode.twoByte(0x0f, 0x9f),
            .idiv, .div, .imul, .mul => OpCode.oneByte(if (is_one_byte) 0xf6 else 0xf7),
            .fisttp16 => OpCode.oneByte(0xdf),
            .fisttp32 => OpCode.oneByte(0xdb),
            .fisttp64 => OpCode.oneByte(0xdd),
            .fld32 => OpCode.oneByte(0xd9),
            .fld64 => OpCode.oneByte(0xdd),
            else => null,
        },
        .o => return switch (tag) {
            .push => OpCode.oneByte(0x50),
            .pop => OpCode.oneByte(0x58),
            else => null,
        },
        .i => return switch (tag) {
            .push => OpCode.oneByte(if (is_one_byte) 0x6a else 0x68),
            .@"test" => OpCode.oneByte(if (is_one_byte) 0xa8 else 0xa9),
            .ret_near => OpCode.oneByte(0xc2),
            .ret_far => OpCode.oneByte(0xca),
            else => null,
        },
        .m1 => return switch (tag) {
            .shl, .sal, .shr, .sar => OpCode.oneByte(if (is_one_byte) 0xd0 else 0xd1),
            else => null,
        },
        .mc => return switch (tag) {
            .shl, .sal, .shr, .sar => OpCode.oneByte(if (is_one_byte) 0xd2 else 0xd3),
            else => null,
        },
        .mi => return switch (tag) {
            .adc, .add, .sub, .xor, .@"and", .@"or", .sbb, .cmp => OpCode.oneByte(if (is_one_byte) 0x80 else 0x81),
            .mov => OpCode.oneByte(if (is_one_byte) 0xc6 else 0xc7),
            .@"test" => OpCode.oneByte(if (is_one_byte) 0xf6 else 0xf7),
            else => null,
        },
        .mi8 => return switch (tag) {
            .adc, .add, .sub, .xor, .@"and", .@"or", .sbb, .cmp => OpCode.oneByte(0x83),
            .shl, .sal, .shr, .sar => OpCode.oneByte(if (is_one_byte) 0xc0 else 0xc1),
            else => null,
        },
        .mr => return switch (tag) {
            .adc => OpCode.oneByte(if (is_one_byte) 0x10 else 0x11),
            .add => OpCode.oneByte(if (is_one_byte) 0x00 else 0x01),
            .sub => OpCode.oneByte(if (is_one_byte) 0x28 else 0x29),
            .xor => OpCode.oneByte(if (is_one_byte) 0x30 else 0x31),
            .@"and" => OpCode.oneByte(if (is_one_byte) 0x20 else 0x21),
            .@"or" => OpCode.oneByte(if (is_one_byte) 0x08 else 0x09),
            .sbb => OpCode.oneByte(if (is_one_byte) 0x18 else 0x19),
            .cmp => OpCode.oneByte(if (is_one_byte) 0x38 else 0x39),
            .mov => OpCode.oneByte(if (is_one_byte) 0x88 else 0x89),
            .@"test" => OpCode.oneByte(if (is_one_byte) 0x84 else 0x85),
            else => null,
        },
        .rm => return switch (tag) {
            .adc => OpCode.oneByte(if (is_one_byte) 0x12 else 0x13),
            .add => OpCode.oneByte(if (is_one_byte) 0x02 else 0x03),
            .sub => OpCode.oneByte(if (is_one_byte) 0x2a else 0x2b),
            .xor => OpCode.oneByte(if (is_one_byte) 0x32 else 0x33),
            .@"and" => OpCode.oneByte(if (is_one_byte) 0x22 else 0x23),
            .@"or" => OpCode.oneByte(if (is_one_byte) 0x0a else 0x0b),
            .sbb => OpCode.oneByte(if (is_one_byte) 0x1a else 0x1b),
            .cmp => OpCode.oneByte(if (is_one_byte) 0x3a else 0x3b),
            .mov => OpCode.oneByte(if (is_one_byte) 0x8a else 0x8b),
            .movsx => OpCode.twoByte(0x0f, if (is_one_byte) 0xbe else 0xbf),
            .movsxd => OpCode.oneByte(0x63),
            .movzx => OpCode.twoByte(0x0f, if (is_one_byte) 0xb6 else 0xb7),
            .lea => OpCode.oneByte(if (is_one_byte) 0x8c else 0x8d),
            .imul => OpCode.twoByte(0x0f, 0xaf),
            .cmove, .cmovz => OpCode.twoByte(0x0f, 0x44),
            .cmovb, .cmovnae => OpCode.twoByte(0x0f, 0x42),
            .cmovl, .cmovng => OpCode.twoByte(0x0f, 0x4c),
            else => null,
        },
        .oi => return switch (tag) {
            .mov => OpCode.oneByte(if (is_one_byte) 0xb0 else 0xb8),
            else => null,
        },
        .fd => return switch (tag) {
            .mov => OpCode.oneByte(if (is_one_byte) 0xa0 else 0xa1),
            else => null,
        },
        .td => return switch (tag) {
            .mov => OpCode.oneByte(if (is_one_byte) 0xa2 else 0xa3),
            else => null,
        },
        .rmi => return switch (tag) {
            .imul => OpCode.oneByte(if (is_one_byte) 0x6b else 0x69),
            else => null,
        },
    }
}

inline fn getModRmExt(tag: Tag) ?u3 {
    return switch (tag) {
        .adc => 0x2,
        .add => 0x0,
        .sub => 0x5,
        .xor => 0x6,
        .@"and" => 0x4,
        .@"or" => 0x1,
        .sbb => 0x3,
        .cmp => 0x7,
        .mov => 0x0,
        .jmp_near => 0x4,
        .call_near => 0x2,
        .push => 0x6,
        .pop => 0x0,
        .@"test" => 0x0,
        .seto,
        .setno,
        .setb,
        .setc,
        .setnae,
        .setnb,
        .setnc,
        .setae,
        .sete,
        .setz,
        .setne,
        .setnz,
        .setbe,
        .setna,
        .seta,
        .setnbe,
        .sets,
        .setns,
        .setp,
        .setpe,
        .setnp,
        .setop,
        .setl,
        .setnge,
        .setnl,
        .setge,
        .setle,
        .setng,
        .setnle,
        .setg,
        => 0x0,
        .shl,
        .sal,
        => 0x4,
        .shr => 0x5,
        .sar => 0x7,
        .mul => 0x4,
        .imul => 0x5,
        .div => 0x6,
        .idiv => 0x7,
        .fisttp16 => 0x1,
        .fisttp32 => 0x1,
        .fisttp64 => 0x1,
        .fld32 => 0x0,
        .fld64 => 0x0,
        else => null,
    };
}

const ScaleIndex = struct {
    scale: u2,
    index: GpRegister,
};

const Memory = struct {
    base: ?GpRegister,
    rip: bool = false,
    disp: u32,
    ptr_size: PtrSize,
    scale_index: ?ScaleIndex = null,

    const PtrSize = enum {
        byte_ptr,
        word_ptr,
        dword_ptr,
        qword_ptr,

        fn fromBits(in_bits: u64) PtrSize {
            return switch (in_bits) {
                8 => .byte_ptr,
                16 => .word_ptr,
                32 => .dword_ptr,
                64 => .qword_ptr,
                else => unreachable,
            };
        }

        /// Returns size in bits.
        fn size(ptr_size: PtrSize) u64 {
            return switch (ptr_size) {
                .byte_ptr => 8,
                .word_ptr => 16,
                .dword_ptr => 32,
                .qword_ptr => 64,
            };
        }
    };

    fn encode(mem_op: Memory, encoder: Encoder, operand: u3) void {
        if (mem_op.base) |base| {
            const dst = base.lowId();
            const src = operand;
            if (dst == 4 or mem_op.scale_index != null) {
                if (mem_op.disp == 0 and dst != 5) {
                    encoder.modRm_SIBDisp0(src);
                    if (mem_op.scale_index) |si| {
                        encoder.sib_scaleIndexBase(si.scale, si.index.lowId(), dst);
                    } else {
                        encoder.sib_base(dst);
                    }
                } else if (immOpSize(mem_op.disp) == 8) {
                    encoder.modRm_SIBDisp8(src);
                    if (mem_op.scale_index) |si| {
                        encoder.sib_scaleIndexBaseDisp8(si.scale, si.index.lowId(), dst);
                    } else {
                        encoder.sib_baseDisp8(dst);
                    }
                    encoder.disp8(@bitCast(i8, @truncate(u8, mem_op.disp)));
                } else {
                    encoder.modRm_SIBDisp32(src);
                    if (mem_op.scale_index) |si| {
                        encoder.sib_scaleIndexBaseDisp32(si.scale, si.index.lowId(), dst);
                    } else {
                        encoder.sib_baseDisp32(dst);
                    }
                    encoder.disp32(@bitCast(i32, mem_op.disp));
                }
            } else {
                if (mem_op.disp == 0 and dst != 5) {
                    encoder.modRm_indirectDisp0(src, dst);
                } else if (immOpSize(mem_op.disp) == 8) {
                    encoder.modRm_indirectDisp8(src, dst);
                    encoder.disp8(@bitCast(i8, @truncate(u8, mem_op.disp)));
                } else {
                    encoder.modRm_indirectDisp32(src, dst);
                    encoder.disp32(@bitCast(i32, mem_op.disp));
                }
            }
        } else {
            if (mem_op.rip) {
                encoder.modRm_RIPDisp32(operand);
            } else {
                encoder.modRm_SIBDisp0(operand);
                if (mem_op.scale_index) |si| {
                    encoder.sib_scaleIndexDisp32(si.scale, si.index.lowId());
                } else {
                    encoder.sib_disp32();
                }
            }
            encoder.disp32(@bitCast(i32, mem_op.disp));
        }
    }

    fn size(memory: Memory) u64 {
        return memory.ptr_size.size();
    }
};

fn encodeImm(encoder: Encoder, imm: u32, size: u64) void {
    switch (size) {
        8 => encoder.imm8(@bitCast(i8, @truncate(u8, imm))),
        16 => encoder.imm16(@bitCast(i16, @truncate(u16, imm))),
        32, 64 => encoder.imm32(@bitCast(i32, imm)),
        else => unreachable,
    }
}

const Register = union(enum) {
    register: GpRegister,
    avx_register: AvxRegister,

    fn reg(register: GpRegister) Register {
        return .{ .register = register };
    }

    fn avxReg(register: AvxRegister) Register {
        return .{ .avx_register = register };
    }

    fn lowId(register: Register) u3 {
        return switch (register) {
            .register => |r| r.lowId(),
            .avx_register => |r| r.lowId(),
        };
    }

    fn size(register: Register) u64 {
        return switch (register) {
            .register => |r| r.size(),
            .avx_register => |r| r.size(),
        };
    }

    fn isExtended(register: Register) bool {
        return switch (register) {
            .register => |r| r.isExtended(),
            .avx_register => |r| r.isExtended(),
        };
    }
};

const RegisterOrMemory = union(enum) {
    register: Register,
    memory: Memory,

    fn reg(register: GpRegister) RegisterOrMemory {
        return .{ .register = Register.reg(register) };
    }

    fn avxReg(register: AvxRegister) RegisterOrMemory {
        return .{ .register = Register.avxReg(register) };
    }

    fn mem(ptr_size: Memory.PtrSize, args: struct {
        disp: u32,
        base: ?GpRegister = null,
        scale_index: ?ScaleIndex = null,
    }) RegisterOrMemory {
        return .{
            .memory = .{
                .base = args.base,
                .disp = args.disp,
                .ptr_size = ptr_size,
                .scale_index = args.scale_index,
            },
        };
    }

    fn rip(ptr_size: Memory.PtrSize, disp: u32) RegisterOrMemory {
        return .{
            .memory = .{
                .base = null,
                .rip = true,
                .disp = disp,
                .ptr_size = ptr_size,
            },
        };
    }

    fn size(reg_or_mem: RegisterOrMemory) u64 {
        return switch (reg_or_mem) {
            .register => |reg| reg.size(),
            .memory => |memory| memory.size(),
        };
    }
};

fn lowerToZoEnc(tag: Tag, code: *std.ArrayList(u8)) InnerError!void {
    const opc = getOpCode(tag, .zo, false).?;
    const encoder = try Encoder.init(code, 2);
    switch (tag) {
        .cqo => {
            encoder.rex(.{
                .w = true,
            });
        },
        else => {},
    }
    opc.encode(encoder);
}

fn lowerToIEnc(tag: Tag, imm: u32, code: *std.ArrayList(u8)) InnerError!void {
    if (tag == .ret_far or tag == .ret_near) {
        const encoder = try Encoder.init(code, 3);
        const opc = getOpCode(tag, .i, false).?;
        opc.encode(encoder);
        encoder.imm16(@bitCast(i16, @truncate(u16, imm)));
        return;
    }
    const opc = getOpCode(tag, .i, immOpSize(imm) == 8).?;
    const encoder = try Encoder.init(code, 5);
    if (immOpSize(imm) == 16) {
        encoder.prefix16BitMode();
    }
    opc.encode(encoder);
    encodeImm(encoder, imm, immOpSize(imm));
}

fn lowerToOEnc(tag: Tag, reg: Register, code: *std.ArrayList(u8)) InnerError!void {
    const opc = getOpCode(tag, .o, false).?;
    const encoder = try Encoder.init(code, 3);
    if (reg.size() == 16) {
        encoder.prefix16BitMode();
    }
    encoder.rex(.{
        .w = false,
        .b = reg.isExtended(),
    });
    opc.encodeWithReg(encoder, reg);
}

fn lowerToDEnc(tag: Tag, imm: u32, code: *std.ArrayList(u8)) InnerError!void {
    const opc = getOpCode(tag, .d, false).?;
    const encoder = try Encoder.init(code, 6);
    opc.encode(encoder);
    encoder.imm32(@bitCast(i32, imm));
}

fn lowerToMxEnc(tag: Tag, reg_or_mem: RegisterOrMemory, enc: Encoding, code: *std.ArrayList(u8)) InnerError!void {
    const opc = getOpCode(tag, enc, reg_or_mem.size() == 8).?;
    const modrm_ext = getModRmExt(tag).?;
    switch (reg_or_mem) {
        .register => |reg| {
            const encoder = try Encoder.init(code, 4);
            if (reg.size() == 16) {
                encoder.prefix16BitMode();
            }
            const wide = if (tag == .jmp_near) false else setRexWRegister(reg);
            encoder.rex(.{
                .w = wide,
                .b = reg.isExtended(),
            });
            opc.encode(encoder);
            encoder.modRm_direct(modrm_ext, reg.lowId());
        },
        .memory => |mem_op| {
            const encoder = try Encoder.init(code, 8);
            if (mem_op.ptr_size == .word_ptr) {
                encoder.prefix16BitMode();
            }
            if (mem_op.base) |base| {
                const wide = if (tag == .jmp_near) false else mem_op.ptr_size == .qword_ptr;
                encoder.rex(.{
                    .w = wide,
                    .b = base.isExtended(),
                });
            }
            opc.encode(encoder);
            mem_op.encode(encoder, modrm_ext);
        },
    }
}

fn lowerToMEnc(tag: Tag, reg_or_mem: RegisterOrMemory, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToMxEnc(tag, reg_or_mem, .m, code);
}

fn lowerToM1Enc(tag: Tag, reg_or_mem: RegisterOrMemory, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToMxEnc(tag, reg_or_mem, .m1, code);
}

fn lowerToMcEnc(tag: Tag, reg_or_mem: RegisterOrMemory, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToMxEnc(tag, reg_or_mem, .mc, code);
}

fn lowerToTdEnc(tag: Tag, moffs: u64, reg: Register, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToTdFdEnc(tag, reg, moffs, code, true);
}

fn lowerToFdEnc(tag: Tag, reg: Register, moffs: u64, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToTdFdEnc(tag, reg, moffs, code, false);
}

fn lowerToTdFdEnc(tag: Tag, reg: Register, moffs: u64, code: *std.ArrayList(u8), td: bool) InnerError!void {
    const opc = if (td)
        getOpCode(tag, .td, reg.size() == 8).?
    else
        getOpCode(tag, .fd, reg.size() == 8).?;
    const encoder = try Encoder.init(code, 10);
    if (reg.size() == 16) {
        encoder.prefix16BitMode();
    }
    encoder.rex(.{
        .w = setRexWRegister(reg),
    });
    opc.encode(encoder);
    switch (reg.size()) {
        8 => encoder.imm8(@bitCast(i8, @truncate(u8, moffs))),
        16 => encoder.imm16(@bitCast(i16, @truncate(u16, moffs))),
        32 => encoder.imm32(@bitCast(i32, @truncate(u32, moffs))),
        64 => encoder.imm64(moffs),
        else => unreachable,
    }
}

fn lowerToOiEnc(tag: Tag, reg: Register, imm: u64, code: *std.ArrayList(u8)) InnerError!void {
    const opc = getOpCode(tag, .oi, reg.size() == 8).?;
    const encoder = try Encoder.init(code, 10);
    if (reg.size() == 16) {
        encoder.prefix16BitMode();
    }
    encoder.rex(.{
        .w = setRexWRegister(reg),
        .b = reg.isExtended(),
    });
    opc.encodeWithReg(encoder, reg);
    switch (reg.size()) {
        8 => encoder.imm8(@bitCast(i8, @truncate(u8, imm))),
        16 => encoder.imm16(@bitCast(i16, @truncate(u16, imm))),
        32 => encoder.imm32(@bitCast(i32, @truncate(u32, imm))),
        64 => encoder.imm64(imm),
        else => unreachable,
    }
}

fn lowerToMiXEnc(
    tag: Tag,
    reg_or_mem: RegisterOrMemory,
    imm: u32,
    enc: Encoding,
    code: *std.ArrayList(u8),
) InnerError!void {
    const modrm_ext = getModRmExt(tag).?;
    const opc = getOpCode(tag, enc, reg_or_mem.size() == 8).?;
    switch (reg_or_mem) {
        .register => |dst_reg| {
            const encoder = try Encoder.init(code, 7);
            if (dst_reg.size() == 16) {
                // 0x66 prefix switches to the non-default size; here we assume a switch from
                // the default 32bits to 16bits operand-size.
                // More info: https://www.cs.uni-potsdam.de/desn/lehre/ss15/64-ia-32-architectures-software-developer-instruction-set-reference-manual-325383.pdf#page=32&zoom=auto,-159,773
                encoder.prefix16BitMode();
            }
            encoder.rex(.{
                .w = setRexWRegister(dst_reg),
                .b = dst_reg.isExtended(),
            });
            opc.encode(encoder);
            encoder.modRm_direct(modrm_ext, dst_reg.lowId());
            encodeImm(encoder, imm, if (enc == .mi8) 8 else dst_reg.size());
        },
        .memory => |dst_mem| {
            const encoder = try Encoder.init(code, 12);
            if (dst_mem.ptr_size == .word_ptr) {
                encoder.prefix16BitMode();
            }
            if (dst_mem.base) |base| {
                encoder.rex(.{
                    .w = dst_mem.ptr_size == .qword_ptr,
                    .b = base.isExtended(),
                });
            } else {
                encoder.rex(.{
                    .w = dst_mem.ptr_size == .qword_ptr,
                });
            }
            opc.encode(encoder);
            dst_mem.encode(encoder, modrm_ext);
            encodeImm(encoder, imm, if (enc == .mi8) 8 else dst_mem.ptr_size.size());
        },
    }
}

fn lowerToMiImm8Enc(tag: Tag, reg_or_mem: RegisterOrMemory, imm: u8, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToMiXEnc(tag, reg_or_mem, imm, .mi8, code);
}

fn lowerToMiEnc(tag: Tag, reg_or_mem: RegisterOrMemory, imm: u32, code: *std.ArrayList(u8)) InnerError!void {
    return lowerToMiXEnc(tag, reg_or_mem, imm, .mi, code);
}

fn lowerToRmEnc(
    tag: Tag,
    reg: Register,
    reg_or_mem: RegisterOrMemory,
    code: *std.ArrayList(u8),
) InnerError!void {
    const opc = getOpCode(tag, .rm, reg.size() == 8 or reg_or_mem.size() == 8).?;
    switch (reg_or_mem) {
        .register => |src_reg| {
            const encoder = try Encoder.init(code, 4);
            if (reg.size() == 16) {
                encoder.prefix16BitMode();
            }
            encoder.rex(.{
                .w = setRexWRegister(reg) or setRexWRegister(src_reg),
                .r = reg.isExtended(),
                .b = src_reg.isExtended(),
            });
            opc.encode(encoder);
            encoder.modRm_direct(reg.lowId(), src_reg.lowId());
        },
        .memory => |src_mem| {
            const encoder = try Encoder.init(code, 9);
            if (reg.size() == 16) {
                encoder.prefix16BitMode();
            }
            if (src_mem.base) |base| {
                // TODO handle 32-bit base register - requires prefix 0x67
                // Intel Manual, Vol 1, chapter 3.6 and 3.6.1
                encoder.rex(.{
                    .w = setRexWRegister(reg),
                    .r = reg.isExtended(),
                    .b = base.isExtended(),
                });
            } else {
                encoder.rex(.{
                    .w = setRexWRegister(reg),
                    .r = reg.isExtended(),
                });
            }
            opc.encode(encoder);
            src_mem.encode(encoder, reg.lowId());
        },
    }
}

fn lowerToMrEnc(
    tag: Tag,
    reg_or_mem: RegisterOrMemory,
    reg: Register,
    code: *std.ArrayList(u8),
) InnerError!void {
    const opc = getOpCode(tag, .mr, reg.size() == 8 or reg_or_mem.size() == 8).?;
    switch (reg_or_mem) {
        .register => |dst_reg| {
            const encoder = try Encoder.init(code, 4);
            if (dst_reg.size() == 16) {
                encoder.prefix16BitMode();
            }
            encoder.rex(.{
                .w = setRexWRegister(dst_reg) or setRexWRegister(reg),
                .r = reg.isExtended(),
                .b = dst_reg.isExtended(),
            });
            opc.encode(encoder);
            encoder.modRm_direct(reg.lowId(), dst_reg.lowId());
        },
        .memory => |dst_mem| {
            const encoder = blk: {
                switch (reg) {
                    .register => {
                        const encoder = try Encoder.init(code, 9);
                        if (reg.size() == 16) {
                            encoder.prefix16BitMode();
                        }
                        if (dst_mem.base) |base| {
                            encoder.rex(.{
                                .w = dst_mem.ptr_size == .qword_ptr or setRexWRegister(reg),
                                .r = reg.isExtended(),
                                .b = base.isExtended(),
                            });
                        } else {
                            encoder.rex(.{
                                .w = dst_mem.ptr_size == .qword_ptr or setRexWRegister(reg),
                                .r = reg.isExtended(),
                            });
                        }
                        break :blk encoder;
                    },
                    .avx_register => {
                        unreachable;
                    },
                }
            };
            opc.encode(encoder);
            dst_mem.encode(encoder, reg.lowId());
        },
    }
}

fn lowerToRmiEnc(
    tag: Tag,
    reg: Register,
    reg_or_mem: RegisterOrMemory,
    imm: u32,
    code: *std.ArrayList(u8),
) InnerError!void {
    const opc = getOpCode(tag, .rmi, false).?;
    const encoder = try Encoder.init(code, 13);
    if (reg.size() == 16) {
        encoder.prefix16BitMode();
    }
    switch (reg_or_mem) {
        .register => |src_reg| {
            encoder.rex(.{
                .w = setRexWRegister(reg) or setRexWRegister(src_reg),
                .r = reg.isExtended(),
                .b = src_reg.isExtended(),
            });
            opc.encode(encoder);
            encoder.modRm_direct(reg.lowId(), src_reg.lowId());
        },
        .memory => |src_mem| {
            if (src_mem.base) |base| {
                // TODO handle 32-bit base register - requires prefix 0x67
                // Intel Manual, Vol 1, chapter 3.6 and 3.6.1
                encoder.rex(.{
                    .w = setRexWRegister(reg),
                    .r = reg.isExtended(),
                    .b = base.isExtended(),
                });
            } else {
                encoder.rex(.{
                    .w = setRexWRegister(reg),
                    .r = reg.isExtended(),
                });
            }
            opc.encode(encoder);
            src_mem.encode(encoder, reg.lowId());
        },
    }
    encodeImm(encoder, imm, reg.size());
}

fn expectEqualHexStrings(expected: []const u8, given: []const u8, assembly: []const u8) !void {
    assert(expected.len > 0);
    if (mem.eql(u8, expected, given)) return;
    const expected_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(expected)});
    defer testing.allocator.free(expected_fmt);
    const given_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(given)});
    defer testing.allocator.free(given_fmt);
    const idx = mem.indexOfDiff(u8, expected_fmt, given_fmt).?;
    var padding = try testing.allocator.alloc(u8, idx + 5);
    defer testing.allocator.free(padding);
    mem.set(u8, padding, ' ');
    std.debug.print("\nASM: {s}\nEXP: {s}\nGIV: {s}\n{s}^ -- first differing byte\n", .{
        assembly,
        expected_fmt,
        given_fmt,
        padding,
    });
    return error.TestFailed;
}

const TestEmit = struct {
    code_buffer: std.ArrayList(u8),
    next: usize = 0,

    fn init() TestEmit {
        return .{
            .code_buffer = std.ArrayList(u8).init(testing.allocator),
        };
    }

    fn deinit(emit: *TestEmit) void {
        emit.code_buffer.deinit();
        emit.next = undefined;
    }

    fn code(emit: *TestEmit) *std.ArrayList(u8) {
        emit.next = emit.code_buffer.items.len;
        return &emit.code_buffer;
    }

    fn lowered(emit: TestEmit) []const u8 {
        return emit.code_buffer.items[emit.next..];
    }
};

test "lower MI encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToMiEnc(.mov, RegisterOrMemory.reg(.rax), 0x10, emit.code());
    try expectEqualHexStrings("\x48\xc7\xc0\x10\x00\x00\x00", emit.lowered(), "mov rax, 0x10");
    try lowerToMiEnc(.mov, RegisterOrMemory.mem(.dword_ptr, .{ .disp = 0, .base = .r11 }), 0x10, emit.code());
    try expectEqualHexStrings("\x41\xc7\x03\x10\x00\x00\x00", emit.lowered(), "mov dword ptr [r11 + 0], 0x10");
    try lowerToMiEnc(.add, RegisterOrMemory.mem(.dword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -8)),
        .base = .rdx,
    }), 0x10, emit.code());
    try expectEqualHexStrings("\x81\x42\xF8\x10\x00\x00\x00", emit.lowered(), "add dword ptr [rdx - 8], 0x10");
    try lowerToMiEnc(.sub, RegisterOrMemory.mem(.dword_ptr, .{
        .disp = 0x10000000,
        .base = .r11,
    }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x41\x81\xab\x00\x00\x00\x10\x10\x00\x00\x00",
        emit.lowered(),
        "sub dword ptr [r11 + 0x10000000], 0x10",
    );
    try lowerToMiEnc(.@"and", RegisterOrMemory.mem(.dword_ptr, .{ .disp = 0x10000000 }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x81\x24\x25\x00\x00\x00\x10\x10\x00\x00\x00",
        emit.lowered(),
        "and dword ptr [ds:0x10000000], 0x10",
    );
    try lowerToMiEnc(.@"and", RegisterOrMemory.mem(.dword_ptr, .{
        .disp = 0x10000000,
        .base = .r12,
    }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x41\x81\xA4\x24\x00\x00\x00\x10\x10\x00\x00\x00",
        emit.lowered(),
        "and dword ptr [r12 + 0x10000000], 0x10",
    );
    try lowerToMiEnc(.mov, RegisterOrMemory.rip(.qword_ptr, 0x10), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x48\xC7\x05\x10\x00\x00\x00\x10\x00\x00\x00",
        emit.lowered(),
        "mov qword ptr [rip + 0x10], 0x10",
    );
    try lowerToMiEnc(.mov, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -8)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x48\xc7\x45\xf8\x10\x00\x00\x00",
        emit.lowered(),
        "mov qword ptr [rbp - 8], 0x10",
    );
    try lowerToMiEnc(.mov, RegisterOrMemory.mem(.word_ptr, .{
        .disp = @bitCast(u32, @as(i32, -2)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings("\x66\xC7\x45\xFE\x10\x00", emit.lowered(), "mov word ptr [rbp - 2], 0x10");
    try lowerToMiEnc(.mov, RegisterOrMemory.mem(.byte_ptr, .{
        .disp = @bitCast(u32, @as(i32, -1)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings("\xC6\x45\xFF\x10", emit.lowered(), "mov byte ptr [rbp - 1], 0x10");
    try lowerToMiEnc(.mov, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0x10000000,
        .scale_index = .{
            .scale = 1,
            .index = .rcx,
        },
    }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x48\xC7\x04\x4D\x00\x00\x00\x10\x10\x00\x00\x00",
        emit.lowered(),
        "mov qword ptr [rcx*2 + 0x10000000], 0x10",
    );

    try lowerToMiImm8Enc(.add, RegisterOrMemory.reg(.rax), 0x10, emit.code());
    try expectEqualHexStrings("\x48\x83\xC0\x10", emit.lowered(), "add rax, 0x10");
}

test "lower RM encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToRmEnc(.mov, Register.reg(.rax), RegisterOrMemory.reg(.rbx), emit.code());
    try expectEqualHexStrings("\x48\x8b\xc3", emit.lowered(), "mov rax, rbx");
    try lowerToRmEnc(.mov, Register.reg(.rax), RegisterOrMemory.mem(.qword_ptr, .{ .disp = 0, .base = .r11 }), emit.code());
    try expectEqualHexStrings("\x49\x8b\x03", emit.lowered(), "mov rax, qword ptr [r11 + 0]");
    try lowerToRmEnc(.add, Register.reg(.r11), RegisterOrMemory.mem(.qword_ptr, .{ .disp = 0x10000000 }), emit.code());
    try expectEqualHexStrings(
        "\x4C\x03\x1C\x25\x00\x00\x00\x10",
        emit.lowered(),
        "add r11, qword ptr [ds:0x10000000]",
    );
    try lowerToRmEnc(.add, Register.reg(.r12b), RegisterOrMemory.mem(.byte_ptr, .{ .disp = 0x10000000 }), emit.code());
    try expectEqualHexStrings(
        "\x44\x02\x24\x25\x00\x00\x00\x10",
        emit.lowered(),
        "add r11b, byte ptr [ds:0x10000000]",
    );
    try lowerToRmEnc(.sub, Register.reg(.r11), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0x10000000,
        .base = .r13,
    }), emit.code());
    try expectEqualHexStrings(
        "\x4D\x2B\x9D\x00\x00\x00\x10",
        emit.lowered(),
        "sub r11, qword ptr [r13 + 0x10000000]",
    );
    try lowerToRmEnc(.sub, Register.reg(.r11), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0x10000000,
        .base = .r12,
    }), emit.code());
    try expectEqualHexStrings(
        "\x4D\x2B\x9C\x24\x00\x00\x00\x10",
        emit.lowered(),
        "sub r11, qword ptr [r12 + 0x10000000]",
    );
    try lowerToRmEnc(.mov, Register.reg(.rax), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -4)),
        .base = .rbp,
    }), emit.code());
    try expectEqualHexStrings("\x48\x8B\x45\xFC", emit.lowered(), "mov rax, qword ptr [rbp - 4]");
    try lowerToRmEnc(.lea, Register.reg(.rax), RegisterOrMemory.rip(.qword_ptr, 0x10), emit.code());
    try expectEqualHexStrings("\x48\x8D\x05\x10\x00\x00\x00", emit.lowered(), "lea rax, [rip + 0x10]");
    try lowerToRmEnc(.mov, Register.reg(.rax), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -8)),
        .base = .rbp,
        .scale_index = .{
            .scale = 0,
            .index = .rcx,
        },
    }), emit.code());
    try expectEqualHexStrings("\x48\x8B\x44\x0D\xF8", emit.lowered(), "mov rax, qword ptr [rbp + rcx*1 - 8]");
    try lowerToRmEnc(.mov, Register.reg(.eax), RegisterOrMemory.mem(.dword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -4)),
        .base = .rbp,
        .scale_index = .{
            .scale = 2,
            .index = .rdx,
        },
    }), emit.code());
    try expectEqualHexStrings("\x8B\x44\x95\xFC", emit.lowered(), "mov eax, dword ptr [rbp + rdx*4 - 4]");
    try lowerToRmEnc(.mov, Register.reg(.rax), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -8)),
        .base = .rbp,
        .scale_index = .{
            .scale = 3,
            .index = .rcx,
        },
    }), emit.code());
    try expectEqualHexStrings("\x48\x8B\x44\xCD\xF8", emit.lowered(), "mov rax, qword ptr [rbp + rcx*8 - 8]");
    try lowerToRmEnc(.mov, Register.reg(.r8b), RegisterOrMemory.mem(.byte_ptr, .{
        .disp = @bitCast(u32, @as(i32, -24)),
        .base = .rsi,
        .scale_index = .{
            .scale = 0,
            .index = .rcx,
        },
    }), emit.code());
    try expectEqualHexStrings("\x44\x8A\x44\x0E\xE8", emit.lowered(), "mov r8b, byte ptr [rsi + rcx*1 - 24]");
    try lowerToRmEnc(.lea, Register.reg(.rsi), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0,
        .base = .rbp,
        .scale_index = .{
            .scale = 0,
            .index = .rcx,
        },
    }), emit.code());
    try expectEqualHexStrings("\x48\x8D\x74\x0D\x00", emit.lowered(), "lea rsi, qword ptr [rbp + rcx*1 + 0]");
}

test "lower MR encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToMrEnc(.mov, RegisterOrMemory.reg(.rax), Register.reg(.rbx), emit.code());
    try expectEqualHexStrings("\x48\x89\xd8", emit.lowered(), "mov rax, rbx");
    try lowerToMrEnc(.mov, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -4)),
        .base = .rbp,
    }), Register.reg(.r11), emit.code());
    try expectEqualHexStrings("\x4c\x89\x5d\xfc", emit.lowered(), "mov qword ptr [rbp - 4], r11");
    try lowerToMrEnc(.add, RegisterOrMemory.mem(.byte_ptr, .{ .disp = 0x10000000 }), Register.reg(.r12b), emit.code());
    try expectEqualHexStrings(
        "\x44\x00\x24\x25\x00\x00\x00\x10",
        emit.lowered(),
        "add byte ptr [ds:0x10000000], r12b",
    );
    try lowerToMrEnc(.add, RegisterOrMemory.mem(.dword_ptr, .{ .disp = 0x10000000 }), Register.reg(.r12d), emit.code());
    try expectEqualHexStrings(
        "\x44\x01\x24\x25\x00\x00\x00\x10",
        emit.lowered(),
        "add dword ptr [ds:0x10000000], r12d",
    );
    try lowerToMrEnc(.sub, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0x10000000,
        .base = .r11,
    }), Register.reg(.r12), emit.code());
    try expectEqualHexStrings(
        "\x4D\x29\xA3\x00\x00\x00\x10",
        emit.lowered(),
        "sub qword ptr [r11 + 0x10000000], r12",
    );
    try lowerToMrEnc(.mov, RegisterOrMemory.rip(.qword_ptr, 0x10), Register.reg(.r12), emit.code());
    try expectEqualHexStrings("\x4C\x89\x25\x10\x00\x00\x00", emit.lowered(), "mov qword ptr [rip + 0x10], r12");
}

test "lower OI encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToOiEnc(.mov, Register.reg(.rax), 0x1000000000000000, emit.code());
    try expectEqualHexStrings(
        "\x48\xB8\x00\x00\x00\x00\x00\x00\x00\x10",
        emit.lowered(),
        "movabs rax, 0x1000000000000000",
    );
    try lowerToOiEnc(.mov, Register.reg(.r11), 0x1000000000000000, emit.code());
    try expectEqualHexStrings(
        "\x49\xBB\x00\x00\x00\x00\x00\x00\x00\x10",
        emit.lowered(),
        "movabs r11, 0x1000000000000000",
    );
    try lowerToOiEnc(.mov, Register.reg(.r11d), 0x10000000, emit.code());
    try expectEqualHexStrings("\x41\xBB\x00\x00\x00\x10", emit.lowered(), "mov r11d, 0x10000000");
    try lowerToOiEnc(.mov, Register.reg(.r11w), 0x1000, emit.code());
    try expectEqualHexStrings("\x66\x41\xBB\x00\x10", emit.lowered(), "mov r11w, 0x1000");
    try lowerToOiEnc(.mov, Register.reg(.r11b), 0x10, emit.code());
    try expectEqualHexStrings("\x41\xB3\x10", emit.lowered(), "mov r11b, 0x10");
}

test "lower FD/TD encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToFdEnc(.mov, Register.reg(.rax), 0x1000000000000000, emit.code());
    try expectEqualHexStrings(
        "\x48\xa1\x00\x00\x00\x00\x00\x00\x00\x10",
        emit.lowered(),
        "mov rax, ds:0x1000000000000000",
    );
    try lowerToFdEnc(.mov, Register.reg(.eax), 0x10000000, emit.code());
    try expectEqualHexStrings("\xa1\x00\x00\x00\x10", emit.lowered(), "mov eax, ds:0x10000000");
    try lowerToFdEnc(.mov, Register.reg(.ax), 0x1000, emit.code());
    try expectEqualHexStrings("\x66\xa1\x00\x10", emit.lowered(), "mov ax, ds:0x1000");
    try lowerToFdEnc(.mov, Register.reg(.al), 0x10, emit.code());
    try expectEqualHexStrings("\xa0\x10", emit.lowered(), "mov al, ds:0x10");
}

test "lower M encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToMEnc(.jmp_near, RegisterOrMemory.reg(.r12), emit.code());
    try expectEqualHexStrings("\x41\xFF\xE4", emit.lowered(), "jmp r12");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.reg(.r12w), emit.code());
    try expectEqualHexStrings("\x66\x41\xFF\xE4", emit.lowered(), "jmp r12w");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.mem(.qword_ptr, .{ .disp = 0, .base = .r12 }), emit.code());
    try expectEqualHexStrings("\x41\xFF\x24\x24", emit.lowered(), "jmp qword ptr [r12]");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.mem(.word_ptr, .{ .disp = 0, .base = .r12 }), emit.code());
    try expectEqualHexStrings("\x66\x41\xFF\x24\x24", emit.lowered(), "jmp word ptr [r12]");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.mem(.qword_ptr, .{ .disp = 0x10, .base = .r12 }), emit.code());
    try expectEqualHexStrings("\x41\xFF\x64\x24\x10", emit.lowered(), "jmp qword ptr [r12 + 0x10]");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = 0x1000,
        .base = .r12,
    }), emit.code());
    try expectEqualHexStrings(
        "\x41\xFF\xA4\x24\x00\x10\x00\x00",
        emit.lowered(),
        "jmp qword ptr [r12 + 0x1000]",
    );
    try lowerToMEnc(.jmp_near, RegisterOrMemory.rip(.qword_ptr, 0x10), emit.code());
    try expectEqualHexStrings("\xFF\x25\x10\x00\x00\x00", emit.lowered(), "jmp qword ptr [rip + 0x10]");
    try lowerToMEnc(.jmp_near, RegisterOrMemory.mem(.qword_ptr, .{ .disp = 0x10 }), emit.code());
    try expectEqualHexStrings("\xFF\x24\x25\x10\x00\x00\x00", emit.lowered(), "jmp qword ptr [ds:0x10]");
    try lowerToMEnc(.seta, RegisterOrMemory.reg(.r11b), emit.code());
    try expectEqualHexStrings("\x41\x0F\x97\xC3", emit.lowered(), "seta r11b");
    try lowerToMEnc(.idiv, RegisterOrMemory.reg(.rax), emit.code());
    try expectEqualHexStrings("\x48\xF7\xF8", emit.lowered(), "idiv rax");
    try lowerToMEnc(.imul, RegisterOrMemory.reg(.al), emit.code());
    try expectEqualHexStrings("\xF6\xE8", emit.lowered(), "imul al");
}

test "lower M1 and MC encodings" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.r12), emit.code());
    try expectEqualHexStrings("\x49\xD1\xE4", emit.lowered(), "sal r12, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.r12d), emit.code());
    try expectEqualHexStrings("\x41\xD1\xE4", emit.lowered(), "sal r12d, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.r12w), emit.code());
    try expectEqualHexStrings("\x66\x41\xD1\xE4", emit.lowered(), "sal r12w, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.r12b), emit.code());
    try expectEqualHexStrings("\x41\xD0\xE4", emit.lowered(), "sal r12b, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.rax), emit.code());
    try expectEqualHexStrings("\x48\xD1\xE0", emit.lowered(), "sal rax, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.reg(.eax), emit.code());
    try expectEqualHexStrings("\xD1\xE0", emit.lowered(), "sal eax, 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -0x10)),
        .base = .rbp,
    }), emit.code());
    try expectEqualHexStrings("\x48\xD1\x65\xF0", emit.lowered(), "sal qword ptr [rbp - 0x10], 1");
    try lowerToM1Enc(.sal, RegisterOrMemory.mem(.dword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -0x10)),
        .base = .rbp,
    }), emit.code());
    try expectEqualHexStrings("\xD1\x65\xF0", emit.lowered(), "sal dword ptr [rbp - 0x10], 1");

    try lowerToMcEnc(.shr, RegisterOrMemory.reg(.r12), emit.code());
    try expectEqualHexStrings("\x49\xD3\xEC", emit.lowered(), "shr r12, cl");
    try lowerToMcEnc(.shr, RegisterOrMemory.reg(.rax), emit.code());
    try expectEqualHexStrings("\x48\xD3\xE8", emit.lowered(), "shr rax, cl");

    try lowerToMcEnc(.sar, RegisterOrMemory.reg(.rsi), emit.code());
    try expectEqualHexStrings("\x48\xD3\xFE", emit.lowered(), "sar rsi, cl");
}

test "lower O encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToOEnc(.pop, Register.reg(.r12), emit.code());
    try expectEqualHexStrings("\x41\x5c", emit.lowered(), "pop r12");
    try lowerToOEnc(.push, Register.reg(.r12w), emit.code());
    try expectEqualHexStrings("\x66\x41\x54", emit.lowered(), "push r12w");
}

test "lower RMI encoding" {
    var emit = TestEmit.init();
    defer emit.deinit();
    try lowerToRmiEnc(.imul, Register.reg(.rax), RegisterOrMemory.mem(.qword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -8)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings(
        "\x48\x69\x45\xF8\x10\x00\x00\x00",
        emit.lowered(),
        "imul rax, qword ptr [rbp - 8], 0x10",
    );
    try lowerToRmiEnc(.imul, Register.reg(.eax), RegisterOrMemory.mem(.dword_ptr, .{
        .disp = @bitCast(u32, @as(i32, -4)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings("\x69\x45\xFC\x10\x00\x00\x00", emit.lowered(), "imul eax, dword ptr [rbp - 4], 0x10");
    try lowerToRmiEnc(.imul, Register.reg(.ax), RegisterOrMemory.mem(.word_ptr, .{
        .disp = @bitCast(u32, @as(i32, -2)),
        .base = .rbp,
    }), 0x10, emit.code());
    try expectEqualHexStrings("\x66\x69\x45\xFE\x10\x00", emit.lowered(), "imul ax, word ptr [rbp - 2], 0x10");
    try lowerToRmiEnc(.imul, Register.reg(.r12), RegisterOrMemory.reg(.r12), 0x10, emit.code());
    try expectEqualHexStrings("\x4D\x69\xE4\x10\x00\x00\x00", emit.lowered(), "imul r12, r12, 0x10");
    try lowerToRmiEnc(.imul, Register.reg(.r12w), RegisterOrMemory.reg(.r12w), 0x10, emit.code());
    try expectEqualHexStrings("\x66\x45\x69\xE4\x10\x00", emit.lowered(), "imul r12w, r12w, 0x10");
}
