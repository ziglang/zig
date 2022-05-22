//! This file contains the functionality for lowering AArch64 MIR into
//! machine code

const Emit = @This();
const std = @import("std");
const math = std.math;
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const assert = std.debug.assert;
const DW = std.dwarf;
const leb128 = std.leb;
const Instruction = bits.Instruction;
const Register = bits.Register;
const log = std.log.scoped(.aarch64_emit);
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

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

/// The branch type of every branch
branch_types: std.AutoHashMapUnmanaged(Mir.Inst.Index, BranchType) = .{},
/// For every forward branch, maps the target instruction to a list of
/// branches which branch to this target instruction
branch_forward_origins: std.AutoHashMapUnmanaged(Mir.Inst.Index, std.ArrayListUnmanaged(Mir.Inst.Index)) = .{},
/// For backward branches: stores the code offset of the target
/// instruction
///
/// For forward branches: stores the code offset of the branch
/// instruction
code_offset_mapping: std.AutoHashMapUnmanaged(Mir.Inst.Index, usize) = .{},

stack_size: u32,

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

const BranchType = enum {
    cbz,
    b_cond,
    unconditional_branch_immediate,

    fn default(tag: Mir.Inst.Tag) BranchType {
        return switch (tag) {
            .cbz => .cbz,
            .b, .bl => .unconditional_branch_immediate,
            .b_cond => .b_cond,
            else => unreachable,
        };
    }
};

pub fn emitMir(
    emit: *Emit,
) !void {
    const mir_tags = emit.mir.instructions.items(.tag);

    // Find smallest lowerings for branch instructions
    try emit.lowerBranches();

    // Emit machine code
    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            .add_immediate => try emit.mirAddSubtractImmediate(inst),
            .adds_immediate => try emit.mirAddSubtractImmediate(inst),
            .cmp_immediate => try emit.mirAddSubtractImmediate(inst),
            .sub_immediate => try emit.mirAddSubtractImmediate(inst),
            .subs_immediate => try emit.mirAddSubtractImmediate(inst),

            .asr_register => try emit.mirShiftRegister(inst),
            .lsl_register => try emit.mirShiftRegister(inst),
            .lsr_register => try emit.mirShiftRegister(inst),

            .asr_immediate => try emit.mirShiftImmediate(inst),
            .lsl_immediate => try emit.mirShiftImmediate(inst),
            .lsr_immediate => try emit.mirShiftImmediate(inst),

            .b_cond => try emit.mirConditionalBranchImmediate(inst),

            .b => try emit.mirBranch(inst),
            .bl => try emit.mirBranch(inst),

            .cbz => try emit.mirCompareAndBranch(inst),

            .blr => try emit.mirUnconditionalBranchRegister(inst),
            .ret => try emit.mirUnconditionalBranchRegister(inst),

            .brk => try emit.mirExceptionGeneration(inst),
            .svc => try emit.mirExceptionGeneration(inst),

            .call_extern => try emit.mirCallExtern(inst),

            .eor_immediate => try emit.mirLogicalImmediate(inst),
            .tst_immediate => try emit.mirLogicalImmediate(inst),

            .add_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),
            .adds_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),
            .cmp_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),
            .sub_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),
            .subs_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),

            .add_extended_register => try emit.mirAddSubtractExtendedRegister(inst),
            .adds_extended_register => try emit.mirAddSubtractExtendedRegister(inst),
            .sub_extended_register => try emit.mirAddSubtractExtendedRegister(inst),
            .subs_extended_register => try emit.mirAddSubtractExtendedRegister(inst),
            .cmp_extended_register => try emit.mirAddSubtractExtendedRegister(inst),

            .cset => try emit.mirConditionalSelect(inst),

            .dbg_line => try emit.mirDbgLine(inst),

            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .and_shifted_register => try emit.mirLogicalShiftedRegister(inst),
            .eor_shifted_register => try emit.mirLogicalShiftedRegister(inst),
            .orr_shifted_register => try emit.mirLogicalShiftedRegister(inst),

            .load_memory_got => try emit.mirLoadMemoryPie(inst),
            .load_memory_direct => try emit.mirLoadMemoryPie(inst),
            .load_memory_ptr_got => try emit.mirLoadMemoryPie(inst),
            .load_memory_ptr_direct => try emit.mirLoadMemoryPie(inst),

            .ldp => try emit.mirLoadStoreRegisterPair(inst),
            .stp => try emit.mirLoadStoreRegisterPair(inst),

            .ldr_stack => try emit.mirLoadStoreStack(inst),
            .ldrb_stack => try emit.mirLoadStoreStack(inst),
            .ldrh_stack => try emit.mirLoadStoreStack(inst),
            .ldrsb_stack => try emit.mirLoadStoreStack(inst),
            .ldrsh_stack => try emit.mirLoadStoreStack(inst),
            .str_stack => try emit.mirLoadStoreStack(inst),
            .strb_stack => try emit.mirLoadStoreStack(inst),
            .strh_stack => try emit.mirLoadStoreStack(inst),

            .ldr_register => try emit.mirLoadStoreRegisterRegister(inst),
            .ldrb_register => try emit.mirLoadStoreRegisterRegister(inst),
            .ldrh_register => try emit.mirLoadStoreRegisterRegister(inst),
            .str_register => try emit.mirLoadStoreRegisterRegister(inst),
            .strb_register => try emit.mirLoadStoreRegisterRegister(inst),
            .strh_register => try emit.mirLoadStoreRegisterRegister(inst),

            .ldr_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .ldrb_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .ldrh_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .ldrsb_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .ldrsh_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .ldrsw_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .str_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .strb_immediate => try emit.mirLoadStoreRegisterImmediate(inst),
            .strh_immediate => try emit.mirLoadStoreRegisterImmediate(inst),

            .mov_register => try emit.mirMoveRegister(inst),
            .mov_to_from_sp => try emit.mirMoveRegister(inst),
            .mvn => try emit.mirMoveRegister(inst),

            .movk => try emit.mirMoveWideImmediate(inst),
            .movz => try emit.mirMoveWideImmediate(inst),

            .mul => try emit.mirDataProcessing3Source(inst),
            .smulh => try emit.mirDataProcessing3Source(inst),
            .smull => try emit.mirDataProcessing3Source(inst),
            .umulh => try emit.mirDataProcessing3Source(inst),
            .umull => try emit.mirDataProcessing3Source(inst),

            .nop => try emit.mirNop(),

            .push_regs => try emit.mirPushPopRegs(inst),
            .pop_regs => try emit.mirPushPopRegs(inst),

            .sbfx,
            .ubfx,
            => try emit.mirBitfieldExtract(inst),

            .sxtb,
            .sxth,
            .sxtw,
            .uxtb,
            .uxth,
            => try emit.mirExtend(inst),
        }
    }
}

pub fn deinit(emit: *Emit) void {
    var iter = emit.branch_forward_origins.valueIterator();
    while (iter.next()) |origin_list| {
        origin_list.deinit(emit.bin_file.allocator);
    }

    emit.branch_types.deinit(emit.bin_file.allocator);
    emit.branch_forward_origins.deinit(emit.bin_file.allocator);
    emit.code_offset_mapping.deinit(emit.bin_file.allocator);
    emit.* = undefined;
}

fn optimalBranchType(emit: *Emit, tag: Mir.Inst.Tag, offset: i64) !BranchType {
    assert(offset & 0b11 == 0);

    switch (tag) {
        .cbz => {
            if (std.math.cast(i19, @shrExact(offset, 2))) |_| {
                return BranchType.cbz;
            } else {
                return emit.fail("TODO support cbz branches larger than +-1 MiB", .{});
            }
        },
        .b, .bl => {
            if (std.math.cast(i26, @shrExact(offset, 2))) |_| {
                return BranchType.unconditional_branch_immediate;
            } else {
                return emit.fail("TODO support unconditional branches larger than +-128 MiB", .{});
            }
        },
        .b_cond => {
            if (std.math.cast(i19, @shrExact(offset, 2))) |_| {
                return BranchType.b_cond;
            } else {
                return emit.fail("TODO support conditional branches larger than +-1 MiB", .{});
            }
        },
        else => unreachable,
    }
}

fn instructionSize(emit: *Emit, inst: Mir.Inst.Index) usize {
    const tag = emit.mir.instructions.items(.tag)[inst];

    if (isBranch(tag)) {
        switch (emit.branch_types.get(inst).?) {
            .cbz,
            .unconditional_branch_immediate,
            .b_cond,
            => return 4,
        }
    }

    switch (tag) {
        .load_memory_direct => return 3 * 4,
        .load_memory_got,
        .load_memory_ptr_got,
        .load_memory_ptr_direct,
        => return 2 * 4,
        .pop_regs, .push_regs => {
            const reg_list = emit.mir.instructions.items(.data)[inst].reg_list;
            const number_of_regs = @popCount(u32, reg_list);
            const number_of_insts = std.math.divCeil(u6, number_of_regs, 2) catch unreachable;
            return number_of_insts * 4;
        },
        .call_extern => return 4,
        .dbg_line,
        .dbg_epilogue_begin,
        .dbg_prologue_end,
        => return 0,
        else => return 4,
    }
}

fn isBranch(tag: Mir.Inst.Tag) bool {
    return switch (tag) {
        .cbz,
        .b,
        .bl,
        .b_cond,
        => true,
        else => false,
    };
}

fn branchTarget(emit: *Emit, inst: Mir.Inst.Index) Mir.Inst.Index {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .cbz => return emit.mir.instructions.items(.data)[inst].r_inst.inst,
        .b, .bl => return emit.mir.instructions.items(.data)[inst].inst,
        .b_cond => return emit.mir.instructions.items(.data)[inst].inst_cond.inst,
        else => unreachable,
    }
}

fn lowerBranches(emit: *Emit) !void {
    const mir_tags = emit.mir.instructions.items(.tag);
    const allocator = emit.bin_file.allocator;

    // First pass: Note down all branches and their target
    // instructions, i.e. populate branch_types,
    // branch_forward_origins, and code_offset_mapping
    //
    // TODO optimization opportunity: do this in codegen while
    // generating MIR
    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        if (isBranch(tag)) {
            const target_inst = emit.branchTarget(inst);

            // Remember this branch instruction
            try emit.branch_types.put(allocator, inst, BranchType.default(tag));

            // Forward branches require some extra stuff: We only
            // know their offset once we arrive at the target
            // instruction. Therefore, we need to be able to
            // access the branch instruction when we visit the
            // target instruction in order to manipulate its type
            // etc.
            if (target_inst > inst) {
                // Remember the branch instruction index
                try emit.code_offset_mapping.put(allocator, inst, 0);

                if (emit.branch_forward_origins.getPtr(target_inst)) |origin_list| {
                    try origin_list.append(allocator, inst);
                } else {
                    var origin_list: std.ArrayListUnmanaged(Mir.Inst.Index) = .{};
                    try origin_list.append(allocator, inst);
                    try emit.branch_forward_origins.put(allocator, target_inst, origin_list);
                }
            }

            // Remember the target instruction index so that we
            // update the real code offset in all future passes
            //
            // putNoClobber may not be used as the put operation
            // may clobber the entry when multiple branches branch
            // to the same target instruction
            try emit.code_offset_mapping.put(allocator, target_inst, 0);
        }
    }

    // Further passes: Until all branches are lowered, interate
    // through all instructions and calculate new offsets and
    // potentially new branch types
    var all_branches_lowered = false;
    while (!all_branches_lowered) {
        all_branches_lowered = true;
        var current_code_offset: usize = 0;

        for (mir_tags) |tag, index| {
            const inst = @intCast(u32, index);

            // If this instruction contained in the code offset
            // mapping (when it is a target of a branch or if it is a
            // forward branch), update the code offset
            if (emit.code_offset_mapping.getPtr(inst)) |offset| {
                offset.* = current_code_offset;
            }

            // If this instruction is a backward branch, calculate the
            // offset, which may potentially update the branch type
            if (isBranch(tag)) {
                const target_inst = emit.branchTarget(inst);
                if (target_inst < inst) {
                    const target_offset = emit.code_offset_mapping.get(target_inst).?;
                    const offset = @intCast(i64, target_offset) - @intCast(i64, current_code_offset);
                    const branch_type = emit.branch_types.getPtr(inst).?;
                    const optimal_branch_type = try emit.optimalBranchType(tag, offset);
                    if (branch_type.* != optimal_branch_type) {
                        branch_type.* = optimal_branch_type;
                        all_branches_lowered = false;
                    }

                    log.debug("lowerBranches: branch {} has offset {}", .{ inst, offset });
                }
            }

            // If this instruction is the target of one or more
            // forward branches, calculate the offset, which may
            // potentially update the branch type
            if (emit.branch_forward_origins.get(inst)) |origin_list| {
                for (origin_list.items) |forward_branch_inst| {
                    const branch_tag = emit.mir.instructions.items(.tag)[forward_branch_inst];
                    const forward_branch_inst_offset = emit.code_offset_mapping.get(forward_branch_inst).?;
                    const offset = @intCast(i64, current_code_offset) - @intCast(i64, forward_branch_inst_offset);
                    const branch_type = emit.branch_types.getPtr(forward_branch_inst).?;
                    const optimal_branch_type = try emit.optimalBranchType(branch_tag, offset);
                    if (branch_type.* != optimal_branch_type) {
                        branch_type.* = optimal_branch_type;
                        all_branches_lowered = false;
                    }

                    log.debug("lowerBranches: branch {} has offset {}", .{ forward_branch_inst, offset });
                }
            }

            // Increment code offset
            current_code_offset += emit.instructionSize(inst);
        }
    }
}

fn writeInstruction(emit: *Emit, instruction: Instruction) !void {
    const endian = emit.target.cpu.arch.endian();
    std.mem.writeInt(u32, try emit.code.addManyAsArray(4), instruction.toU32(), endian);
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(emit.err_msg == null);
    emit.err_msg = try ErrorMsg.create(emit.bin_file.allocator, emit.src_loc, format, args);
    return error.EmitFail;
}

fn dbgAdvancePCAndLine(self: *Emit, line: u32, column: u32) !void {
    const delta_line = @intCast(i32, line) - @intCast(i32, self.prev_di_line);
    const delta_pc: usize = self.code.items.len - self.prev_di_pc;
    switch (self.debug_output) {
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
            self.prev_di_pc = self.code.items.len;
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes
            // we have already checked the target in the linker to make sure it is compatable
            const quant = @import("../../link/Plan9/aout.zig").getPCQuant(self.target.cpu.arch) catch unreachable;

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
                dbg_out.start_line.* = self.prev_di_line;
            dbg_out.end_line.* = line;
            // only do this if the pc changed
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .none => {},
    }
}

fn mirAddSubtractImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    switch (tag) {
        .add_immediate,
        .adds_immediate,
        .sub_immediate,
        .subs_immediate,
        => {
            const rr_imm12_sh = emit.mir.instructions.items(.data)[inst].rr_imm12_sh;
            const rd = rr_imm12_sh.rd;
            const rn = rr_imm12_sh.rn;
            const imm12 = rr_imm12_sh.imm12;
            const sh = rr_imm12_sh.sh == 1;

            switch (tag) {
                .add_immediate => try emit.writeInstruction(Instruction.add(rd, rn, imm12, sh)),
                .adds_immediate => try emit.writeInstruction(Instruction.adds(rd, rn, imm12, sh)),
                .sub_immediate => try emit.writeInstruction(Instruction.sub(rd, rn, imm12, sh)),
                .subs_immediate => try emit.writeInstruction(Instruction.subs(rd, rn, imm12, sh)),
                else => unreachable,
            }
        },
        .cmp_immediate => {
            const r_imm12_sh = emit.mir.instructions.items(.data)[inst].r_imm12_sh;
            const rn = r_imm12_sh.rn;
            const imm12 = r_imm12_sh.imm12;
            const sh = r_imm12_sh.sh == 1;
            const zr: Register = switch (rn.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };

            try emit.writeInstruction(Instruction.subs(zr, rn, imm12, sh));
        },
        else => unreachable,
    }
}

fn mirShiftRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rrr = emit.mir.instructions.items(.data)[inst].rrr;
    const rd = rrr.rd;
    const rn = rrr.rn;
    const rm = rrr.rm;

    switch (tag) {
        .asr_register => try emit.writeInstruction(Instruction.asrRegister(rd, rn, rm)),
        .lsl_register => try emit.writeInstruction(Instruction.lslRegister(rd, rn, rm)),
        .lsr_register => try emit.writeInstruction(Instruction.lsrRegister(rd, rn, rm)),
        else => unreachable,
    }
}

fn mirShiftImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr_shift = emit.mir.instructions.items(.data)[inst].rr_shift;
    const rd = rr_shift.rd;
    const rn = rr_shift.rn;
    const shift = rr_shift.shift;

    switch (tag) {
        .asr_immediate => try emit.writeInstruction(Instruction.asrImmediate(rd, rn, shift)),
        .lsl_immediate => try emit.writeInstruction(Instruction.lslImmediate(rd, rn, shift)),
        .lsr_immediate => try emit.writeInstruction(Instruction.lsrImmediate(rd, rn, shift)),
        else => unreachable,
    }
}

fn mirConditionalBranchImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const inst_cond = emit.mir.instructions.items(.data)[inst].inst_cond;

    const offset = @intCast(i64, emit.code_offset_mapping.get(inst_cond.inst).?) - @intCast(i64, emit.code.items.len);
    const branch_type = emit.branch_types.get(inst).?;
    log.debug("mirConditionalBranchImmediate: {} offset={}", .{ inst, offset });

    switch (branch_type) {
        .b_cond => switch (tag) {
            .b_cond => try emit.writeInstruction(Instruction.bCond(inst_cond.cond, @intCast(i21, offset))),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn mirBranch(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const target_inst = emit.mir.instructions.items(.data)[inst].inst;

    log.debug("branch {}(tag: {}) -> {}(tag: {})", .{
        inst,
        tag,
        target_inst,
        emit.mir.instructions.items(.tag)[target_inst],
    });

    const offset = @intCast(i64, emit.code_offset_mapping.get(target_inst).?) - @intCast(i64, emit.code.items.len);
    const branch_type = emit.branch_types.get(inst).?;
    log.debug("mirBranch: {} offset={}", .{ inst, offset });

    switch (branch_type) {
        .unconditional_branch_immediate => switch (tag) {
            .b => try emit.writeInstruction(Instruction.b(@intCast(i28, offset))),
            .bl => try emit.writeInstruction(Instruction.bl(@intCast(i28, offset))),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn mirCompareAndBranch(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_inst = emit.mir.instructions.items(.data)[inst].r_inst;

    const offset = @intCast(i64, emit.code_offset_mapping.get(r_inst.inst).?) - @intCast(i64, emit.code.items.len);
    const branch_type = emit.branch_types.get(inst).?;
    log.debug("mirCompareAndBranch: {} offset={}", .{ inst, offset });

    switch (branch_type) {
        .cbz => switch (tag) {
            .cbz => try emit.writeInstruction(Instruction.cbz(r_inst.rt, @intCast(i21, offset))),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn mirUnconditionalBranchRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const reg = emit.mir.instructions.items(.data)[inst].reg;

    switch (tag) {
        .blr => try emit.writeInstruction(Instruction.blr(reg)),
        .ret => try emit.writeInstruction(Instruction.ret(reg)),
        else => unreachable,
    }
}

fn mirExceptionGeneration(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const imm16 = emit.mir.instructions.items(.data)[inst].imm16;

    switch (tag) {
        .brk => try emit.writeInstruction(Instruction.brk(imm16)),
        .svc => try emit.writeInstruction(Instruction.svc(imm16)),
        else => unreachable,
    }
}

fn mirDbgLine(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const dbg_line_column = emit.mir.instructions.items(.data)[inst].dbg_line_column;

    switch (tag) {
        .dbg_line => try emit.dbgAdvancePCAndLine(dbg_line_column.line, dbg_line_column.column),
        else => unreachable,
    }
}

fn mirDebugPrologueEnd(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            try dw.dbg_line.append(DW.LNS.set_prologue_end);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            try dw.dbg_line.append(DW.LNS.set_epilogue_begin);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirCallExtern(emit: *Emit, inst: Mir.Inst.Index) !void {
    assert(emit.mir.instructions.items(.tag)[inst] == .call_extern);
    const extern_fn = emit.mir.instructions.items(.data)[inst].extern_fn;

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        const offset = blk: {
            const offset = @intCast(u32, emit.code.items.len);
            // bl
            try emit.writeInstruction(Instruction.bl(0));
            break :blk offset;
        };
        // Add relocation to the decl.
        const atom = macho_file.atom_by_index_table.get(extern_fn.atom_index).?;
        try atom.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .global = extern_fn.sym_name },
            .addend = 0,
            .subtractor = null,
            .pcrel = true,
            .length = 2,
            .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_BRANCH26),
        });
    } else {
        return emit.fail("Implement call_extern for linking backends != MachO", .{});
    }
}

fn mirLogicalImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr_bitmask = emit.mir.instructions.items(.data)[inst].rr_bitmask;
    const rd = rr_bitmask.rd;
    const rn = rr_bitmask.rn;
    const imms = rr_bitmask.imms;
    const immr = rr_bitmask.immr;
    const n = rr_bitmask.n;

    switch (tag) {
        .eor_immediate => try emit.writeInstruction(Instruction.eorImmediate(rd, rn, imms, immr, n)),
        .tst_immediate => {
            const zr: Register = switch (rd.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };
            try emit.writeInstruction(Instruction.andsImmediate(zr, rn, imms, immr, n));
        },
        else => unreachable,
    }
}

fn mirAddSubtractShiftedRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    switch (tag) {
        .add_shifted_register,
        .adds_shifted_register,
        .sub_shifted_register,
        .subs_shifted_register,
        => {
            const rrr_imm6_shift = emit.mir.instructions.items(.data)[inst].rrr_imm6_shift;
            const rd = rrr_imm6_shift.rd;
            const rn = rrr_imm6_shift.rn;
            const rm = rrr_imm6_shift.rm;
            const shift = rrr_imm6_shift.shift;
            const imm6 = rrr_imm6_shift.imm6;

            switch (tag) {
                .add_shifted_register => try emit.writeInstruction(Instruction.addShiftedRegister(rd, rn, rm, shift, imm6)),
                .adds_shifted_register => try emit.writeInstruction(Instruction.addsShiftedRegister(rd, rn, rm, shift, imm6)),
                .sub_shifted_register => try emit.writeInstruction(Instruction.subShiftedRegister(rd, rn, rm, shift, imm6)),
                .subs_shifted_register => try emit.writeInstruction(Instruction.subsShiftedRegister(rd, rn, rm, shift, imm6)),
                else => unreachable,
            }
        },
        .cmp_shifted_register => {
            const rr_imm6_shift = emit.mir.instructions.items(.data)[inst].rr_imm6_shift;
            const rn = rr_imm6_shift.rn;
            const rm = rr_imm6_shift.rm;
            const shift = rr_imm6_shift.shift;
            const imm6 = rr_imm6_shift.imm6;
            const zr: Register = switch (rn.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };

            try emit.writeInstruction(Instruction.subsShiftedRegister(zr, rn, rm, shift, imm6));
        },
        else => unreachable,
    }
}

fn mirAddSubtractExtendedRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    switch (tag) {
        .add_extended_register,
        .adds_extended_register,
        .sub_extended_register,
        .subs_extended_register,
        => {
            const rrr_extend_shift = emit.mir.instructions.items(.data)[inst].rrr_extend_shift;
            const rd = rrr_extend_shift.rd;
            const rn = rrr_extend_shift.rn;
            const rm = rrr_extend_shift.rm;
            const ext_type = rrr_extend_shift.ext_type;
            const imm3 = rrr_extend_shift.imm3;

            switch (tag) {
                .add_extended_register => try emit.writeInstruction(Instruction.addExtendedRegister(rd, rn, rm, ext_type, imm3)),
                .adds_extended_register => try emit.writeInstruction(Instruction.addsExtendedRegister(rd, rn, rm, ext_type, imm3)),
                .sub_extended_register => try emit.writeInstruction(Instruction.subExtendedRegister(rd, rn, rm, ext_type, imm3)),
                .subs_extended_register => try emit.writeInstruction(Instruction.subsExtendedRegister(rd, rn, rm, ext_type, imm3)),
                else => unreachable,
            }
        },
        .cmp_extended_register => {
            const rr_extend_shift = emit.mir.instructions.items(.data)[inst].rr_extend_shift;
            const rn = rr_extend_shift.rn;
            const rm = rr_extend_shift.rm;
            const ext_type = rr_extend_shift.ext_type;
            const imm3 = rr_extend_shift.imm3;
            const zr: Register = switch (rn.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };

            try emit.writeInstruction(Instruction.subsExtendedRegister(zr, rn, rm, ext_type, imm3));
        },
        else => unreachable,
    }
}

fn mirConditionalSelect(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    switch (tag) {
        .cset => {
            const r_cond = emit.mir.instructions.items(.data)[inst].r_cond;
            const zr: Register = switch (r_cond.rd.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };
            try emit.writeInstruction(Instruction.csinc(r_cond.rd, zr, zr, r_cond.cond.negate()));
        },
        else => unreachable,
    }
}

fn mirLogicalShiftedRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rrr_imm6_logical_shift = emit.mir.instructions.items(.data)[inst].rrr_imm6_logical_shift;
    const rd = rrr_imm6_logical_shift.rd;
    const rn = rrr_imm6_logical_shift.rn;
    const rm = rrr_imm6_logical_shift.rm;
    const shift = rrr_imm6_logical_shift.shift;
    const imm6 = rrr_imm6_logical_shift.imm6;

    switch (tag) {
        .and_shifted_register => try emit.writeInstruction(Instruction.andShiftedRegister(rd, rn, rm, shift, imm6)),
        .eor_shifted_register => try emit.writeInstruction(Instruction.eorShiftedRegister(rd, rn, rm, shift, imm6)),
        .orr_shifted_register => try emit.writeInstruction(Instruction.orrShiftedRegister(rd, rn, rm, shift, imm6)),
        else => unreachable,
    }
}

fn mirLoadMemoryPie(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const data = emit.mir.extraData(Mir.LoadMemoryPie, payload).data;
    const reg = @intToEnum(Register, data.register);

    // PC-relative displacement to the entry in memory.
    // adrp
    const offset = @intCast(u32, emit.code.items.len);
    try emit.writeInstruction(Instruction.adrp(reg.to64(), 0));

    switch (tag) {
        .load_memory_got => {
            // ldr reg, reg, offset
            try emit.writeInstruction(Instruction.ldr(
                reg,
                reg.to64(),
                Instruction.LoadStoreOffset.imm(0),
            ));
        },
        .load_memory_direct => {
            // We cannot load the offset directly as it may not be aligned properly.
            // For example, load for 64bit register will require the target address offset
            // to be 8-byte aligned, while the value might have non-8-byte natural alignment,
            // meaning the linker might have put it at a non-8-byte aligned address. To circumvent
            // this, we use `adrp, add` to form the address value which we then dereference with
            // `ldr`.
            // Note that this can potentially be optimised out by the codegen/linker if the
            // target address is appropriately aligned.
            // add reg, reg, offset
            try emit.writeInstruction(Instruction.add(reg.to64(), reg.to64(), 0, false));
            // ldr reg, reg, offset
            try emit.writeInstruction(Instruction.ldr(
                reg,
                reg.to64(),
                Instruction.LoadStoreOffset.imm(0),
            ));
        },
        .load_memory_ptr_got,
        .load_memory_ptr_direct,
        => {
            // add reg, reg, offset
            try emit.writeInstruction(Instruction.add(reg, reg, 0, false));
        },
        else => unreachable,
    }

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        const atom = macho_file.atom_by_index_table.get(data.atom_index).?;
        // Page reloc for adrp instruction.
        try atom.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .local = data.sym_index },
            .addend = 0,
            .subtractor = null,
            .pcrel = true,
            .length = 2,
            .@"type" = switch (tag) {
                .load_memory_got,
                .load_memory_ptr_got,
                => @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGE21),
                .load_memory_direct,
                .load_memory_ptr_direct,
                => @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_PAGE21),
                else => unreachable,
            },
        });
        // Pageoff reloc for adrp instruction.
        try atom.relocs.append(emit.bin_file.allocator, .{
            .offset = offset + 4,
            .target = .{ .local = data.sym_index },
            .addend = 0,
            .subtractor = null,
            .pcrel = false,
            .length = 2,
            .@"type" = switch (tag) {
                .load_memory_got,
                .load_memory_ptr_got,
                => @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGEOFF12),
                .load_memory_direct,
                .load_memory_ptr_direct,
                => @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_PAGEOFF12),
                else => unreachable,
            },
        });
    } else {
        return emit.fail("TODO implement load_memory for PIE GOT indirection on this platform", .{});
    }
}

fn mirLoadStoreRegisterPair(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register_pair = emit.mir.instructions.items(.data)[inst].load_store_register_pair;
    const rt = load_store_register_pair.rt;
    const rt2 = load_store_register_pair.rt2;
    const rn = load_store_register_pair.rn;
    const offset = load_store_register_pair.offset;

    switch (tag) {
        .stp => try emit.writeInstruction(Instruction.stp(rt, rt2, rn, offset)),
        .ldp => try emit.writeInstruction(Instruction.ldp(rt, rt2, rn, offset)),
        else => unreachable,
    }
}

fn mirLoadStoreStack(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_stack = emit.mir.instructions.items(.data)[inst].load_store_stack;
    const rt = load_store_stack.rt;

    const raw_offset = emit.stack_size - load_store_stack.offset;
    const offset = switch (tag) {
        .ldrb_stack, .ldrsb_stack, .strb_stack => blk: {
            if (math.cast(u12, raw_offset)) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else {
                return emit.fail("TODO load/store stack byte with larger offset", .{});
            }
        },
        .ldrh_stack, .ldrsh_stack, .strh_stack => blk: {
            assert(std.mem.isAlignedGeneric(u32, raw_offset, 2)); // misaligned stack entry
            if (math.cast(u12, @divExact(raw_offset, 2))) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else {
                return emit.fail("TODO load/store stack halfword with larger offset", .{});
            }
        },
        .ldr_stack, .str_stack => blk: {
            const alignment: u32 = switch (rt.size()) {
                32 => 4,
                64 => 8,
                else => unreachable,
            };

            assert(std.mem.isAlignedGeneric(u32, raw_offset, alignment)); // misaligned stack entry
            if (math.cast(u12, @divExact(raw_offset, alignment))) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else {
                return emit.fail("TODO load/store stack with larger offset", .{});
            }
        },
        else => unreachable,
    };

    switch (tag) {
        .ldr_stack => try emit.writeInstruction(Instruction.ldr(rt, .sp, offset)),
        .ldrb_stack => try emit.writeInstruction(Instruction.ldrb(rt, .sp, offset)),
        .ldrh_stack => try emit.writeInstruction(Instruction.ldrh(rt, .sp, offset)),
        .ldrsb_stack => try emit.writeInstruction(Instruction.ldrsb(rt, .sp, offset)),
        .ldrsh_stack => try emit.writeInstruction(Instruction.ldrsh(rt, .sp, offset)),
        .str_stack => try emit.writeInstruction(Instruction.str(rt, .sp, offset)),
        .strb_stack => try emit.writeInstruction(Instruction.strb(rt, .sp, offset)),
        .strh_stack => try emit.writeInstruction(Instruction.strh(rt, .sp, offset)),
        else => unreachable,
    }
}

fn mirLoadStoreRegisterImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register_immediate = emit.mir.instructions.items(.data)[inst].load_store_register_immediate;
    const rt = load_store_register_immediate.rt;
    const rn = load_store_register_immediate.rn;
    const offset = Instruction.LoadStoreOffset{ .immediate = load_store_register_immediate.offset };

    switch (tag) {
        .ldr_immediate => try emit.writeInstruction(Instruction.ldr(rt, rn, offset)),
        .ldrb_immediate => try emit.writeInstruction(Instruction.ldrb(rt, rn, offset)),
        .ldrh_immediate => try emit.writeInstruction(Instruction.ldrh(rt, rn, offset)),
        .ldrsb_immediate => try emit.writeInstruction(Instruction.ldrsb(rt, rn, offset)),
        .ldrsh_immediate => try emit.writeInstruction(Instruction.ldrsh(rt, rn, offset)),
        .ldrsw_immediate => try emit.writeInstruction(Instruction.ldrsw(rt, rn, offset)),
        .str_immediate => try emit.writeInstruction(Instruction.str(rt, rn, offset)),
        .strb_immediate => try emit.writeInstruction(Instruction.strb(rt, rn, offset)),
        .strh_immediate => try emit.writeInstruction(Instruction.strh(rt, rn, offset)),
        else => unreachable,
    }
}

fn mirLoadStoreRegisterRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register_register = emit.mir.instructions.items(.data)[inst].load_store_register_register;
    const rt = load_store_register_register.rt;
    const rn = load_store_register_register.rn;
    const offset = Instruction.LoadStoreOffset{ .register = load_store_register_register.offset };

    switch (tag) {
        .ldr_register => try emit.writeInstruction(Instruction.ldr(rt, rn, offset)),
        .ldrb_register => try emit.writeInstruction(Instruction.ldrb(rt, rn, offset)),
        .ldrh_register => try emit.writeInstruction(Instruction.ldrh(rt, rn, offset)),
        .str_register => try emit.writeInstruction(Instruction.str(rt, rn, offset)),
        .strb_register => try emit.writeInstruction(Instruction.strb(rt, rn, offset)),
        .strh_register => try emit.writeInstruction(Instruction.strh(rt, rn, offset)),
        else => unreachable,
    }
}

fn mirMoveRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    switch (tag) {
        .mov_register => {
            const rr = emit.mir.instructions.items(.data)[inst].rr;
            const zr: Register = switch (rr.rd.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };

            try emit.writeInstruction(Instruction.orrShiftedRegister(rr.rd, zr, rr.rn, .lsl, 0));
        },
        .mov_to_from_sp => {
            const rr = emit.mir.instructions.items(.data)[inst].rr;
            try emit.writeInstruction(Instruction.add(rr.rd, rr.rn, 0, false));
        },
        .mvn => {
            const rr_imm6_logical_shift = emit.mir.instructions.items(.data)[inst].rr_imm6_logical_shift;
            const rd = rr_imm6_logical_shift.rd;
            const rm = rr_imm6_logical_shift.rm;
            const shift = rr_imm6_logical_shift.shift;
            const imm6 = rr_imm6_logical_shift.imm6;
            const zr: Register = switch (rd.size()) {
                32 => .wzr,
                64 => .xzr,
                else => unreachable,
            };

            try emit.writeInstruction(Instruction.ornShiftedRegister(rd, zr, rm, shift, imm6));
        },
        else => unreachable,
    }
}

fn mirMoveWideImmediate(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_imm16_sh = emit.mir.instructions.items(.data)[inst].r_imm16_sh;

    switch (tag) {
        .movz => try emit.writeInstruction(Instruction.movz(r_imm16_sh.rd, r_imm16_sh.imm16, @as(u6, r_imm16_sh.hw) << 4)),
        .movk => try emit.writeInstruction(Instruction.movk(r_imm16_sh.rd, r_imm16_sh.imm16, @as(u6, r_imm16_sh.hw) << 4)),
        else => unreachable,
    }
}

fn mirDataProcessing3Source(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rrr = emit.mir.instructions.items(.data)[inst].rrr;

    switch (tag) {
        .mul => try emit.writeInstruction(Instruction.mul(rrr.rd, rrr.rn, rrr.rm)),
        .smulh => try emit.writeInstruction(Instruction.smulh(rrr.rd, rrr.rn, rrr.rm)),
        .smull => try emit.writeInstruction(Instruction.smull(rrr.rd, rrr.rn, rrr.rm)),
        .umulh => try emit.writeInstruction(Instruction.umulh(rrr.rd, rrr.rn, rrr.rm)),
        .umull => try emit.writeInstruction(Instruction.umull(rrr.rd, rrr.rn, rrr.rm)),
        else => unreachable,
    }
}

fn mirNop(emit: *Emit) !void {
    try emit.writeInstruction(Instruction.nop());
}

fn mirPushPopRegs(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const reg_list = emit.mir.instructions.items(.data)[inst].reg_list;

    if (reg_list & @as(u32, 1) << 31 != 0) return emit.fail("xzr is not a valid register for {}", .{tag});

    // sp must be aligned at all times, so we only use stp and ldp
    // instructions for minimal instruction count. However, if we do
    // not have an even number of registers, we use str and ldr
    const number_of_regs = @popCount(u32, reg_list);

    switch (tag) {
        .pop_regs => {
            var i: u6 = 32;
            var count: u6 = 0;
            var other_reg: Register = undefined;
            while (i > 0) : (i -= 1) {
                const reg = @intToEnum(Register, i - 1);
                if (reg_list & @as(u32, 1) << @intCast(u5, reg.id()) != 0) {
                    if (count % 2 == 0) {
                        if (count == number_of_regs - 1) {
                            try emit.writeInstruction(Instruction.ldr(
                                reg,
                                .sp,
                                Instruction.LoadStoreOffset.imm_post_index(16),
                            ));
                        } else {
                            other_reg = reg;
                        }
                    } else {
                        try emit.writeInstruction(Instruction.ldp(
                            reg,
                            other_reg,
                            .sp,
                            Instruction.LoadStorePairOffset.post_index(16),
                        ));
                    }
                    count += 1;
                }
            }
            assert(count == number_of_regs);
        },
        .push_regs => {
            var i: u6 = 0;
            var count: u6 = 0;
            var other_reg: Register = undefined;
            while (i < 32) : (i += 1) {
                const reg = @intToEnum(Register, i);
                if (reg_list & @as(u32, 1) << @intCast(u5, reg.id()) != 0) {
                    if (count % 2 == 0) {
                        if (count == number_of_regs - 1) {
                            try emit.writeInstruction(Instruction.str(
                                reg,
                                .sp,
                                Instruction.LoadStoreOffset.imm_pre_index(-16),
                            ));
                        } else {
                            other_reg = reg;
                        }
                    } else {
                        try emit.writeInstruction(Instruction.stp(
                            other_reg,
                            reg,
                            .sp,
                            Instruction.LoadStorePairOffset.pre_index(-16),
                        ));
                    }
                    count += 1;
                }
            }
            assert(count == number_of_regs);
        },
        else => unreachable,
    }
}

fn mirBitfieldExtract(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr_lsb_width = emit.mir.instructions.items(.data)[inst].rr_lsb_width;
    const rd = rr_lsb_width.rd;
    const rn = rr_lsb_width.rn;
    const lsb = rr_lsb_width.lsb;
    const width = rr_lsb_width.width;

    switch (tag) {
        .sbfx => try emit.writeInstruction(Instruction.sbfx(rd, rn, lsb, width)),
        .ubfx => try emit.writeInstruction(Instruction.ubfx(rd, rn, lsb, width)),
        else => unreachable,
    }
}

fn mirExtend(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr = emit.mir.instructions.items(.data)[inst].rr;

    switch (tag) {
        .sxtb => try emit.writeInstruction(Instruction.sxtb(rr.rd, rr.rn)),
        .sxth => try emit.writeInstruction(Instruction.sxth(rr.rd, rr.rn)),
        .sxtw => try emit.writeInstruction(Instruction.sxtw(rr.rd, rr.rn)),
        .uxtb => try emit.writeInstruction(Instruction.uxtb(rr.rd, rr.rn)),
        .uxth => try emit.writeInstruction(Instruction.uxth(rr.rd, rr.rn)),
        else => unreachable,
    }
}
