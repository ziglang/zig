//! This file contains the functionality for lowering AArch32 MIR into
//! machine code

const Emit = @This();
const builtin = @import("builtin");
const std = @import("std");
const math = std.math;
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const Type = @import("../../type.zig").Type;
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const assert = std.debug.assert;
const Instruction = bits.Instruction;
const Register = bits.Register;
const log = std.log.scoped(.aarch32_emit);
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const CodeGen = @import("CodeGen.zig");

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

/// The amount of stack space consumed by the saved callee-saved
/// registers in bytes
saved_regs_stack_space: u32,

/// The final stack frame size of the function (already aligned to the
/// respective stack alignment). Does not include prologue stack space.
stack_size: u32,

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

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

const BranchType = enum {
    b,

    fn default(tag: Mir.Inst.Tag) BranchType {
        return switch (tag) {
            .b => .b,
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
    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        switch (tag) {
            .add => try emit.mirDataProcessing(inst),
            .adds => try emit.mirDataProcessing(inst),
            .@"and" => try emit.mirDataProcessing(inst),
            .cmp => try emit.mirDataProcessing(inst),
            .eor => try emit.mirDataProcessing(inst),
            .mov => try emit.mirDataProcessing(inst),
            .mvn => try emit.mirDataProcessing(inst),
            .orr => try emit.mirDataProcessing(inst),
            .rsb => try emit.mirDataProcessing(inst),
            .sub => try emit.mirDataProcessing(inst),
            .subs => try emit.mirDataProcessing(inst),

            .sub_sp_scratch_r4 => try emit.mirSubStackPointer(inst),

            .asr => try emit.mirShift(inst),
            .lsl => try emit.mirShift(inst),
            .lsr => try emit.mirShift(inst),

            .b => try emit.mirBranch(inst),

            .undefined_instruction => try emit.mirUndefinedInstruction(),
            .bkpt => try emit.mirExceptionGeneration(inst),

            .blx => try emit.mirBranchExchange(inst),
            .bx => try emit.mirBranchExchange(inst),

            .dbg_line => try emit.mirDbgLine(inst),

            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),

            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .ldr => try emit.mirLoadStore(inst),
            .ldrb => try emit.mirLoadStore(inst),
            .str => try emit.mirLoadStore(inst),
            .strb => try emit.mirLoadStore(inst),

            .ldr_ptr_stack_argument => try emit.mirLoadStackArgument(inst),
            .ldr_stack_argument => try emit.mirLoadStackArgument(inst),
            .ldrb_stack_argument => try emit.mirLoadStackArgument(inst),
            .ldrh_stack_argument => try emit.mirLoadStackArgument(inst),
            .ldrsb_stack_argument => try emit.mirLoadStackArgument(inst),
            .ldrsh_stack_argument => try emit.mirLoadStackArgument(inst),

            .ldrh => try emit.mirLoadStoreExtra(inst),
            .ldrsb => try emit.mirLoadStoreExtra(inst),
            .ldrsh => try emit.mirLoadStoreExtra(inst),
            .strh => try emit.mirLoadStoreExtra(inst),

            .movw => try emit.mirSpecialMove(inst),
            .movt => try emit.mirSpecialMove(inst),

            .mul => try emit.mirMultiply(inst),
            .smulbb => try emit.mirMultiply(inst),

            .smull => try emit.mirMultiplyLong(inst),
            .umull => try emit.mirMultiplyLong(inst),

            .nop => try emit.mirNop(),

            .pop => try emit.mirBlockDataTransfer(inst),
            .push => try emit.mirBlockDataTransfer(inst),

            .svc => try emit.mirSupervisorCall(inst),

            .sbfx => try emit.mirBitFieldExtract(inst),
            .ubfx => try emit.mirBitFieldExtract(inst),
        }
    }
}

pub fn deinit(emit: *Emit) void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;

    var iter = emit.branch_forward_origins.valueIterator();
    while (iter.next()) |origin_list| {
        origin_list.deinit(gpa);
    }

    emit.branch_types.deinit(gpa);
    emit.branch_forward_origins.deinit(gpa);
    emit.code_offset_mapping.deinit(gpa);
    emit.* = undefined;
}

fn optimalBranchType(emit: *Emit, tag: Mir.Inst.Tag, offset: i64) !BranchType {
    assert(std.mem.isAlignedGeneric(i64, offset, 4)); // misaligned offset

    switch (tag) {
        .b => {
            if (std.math.cast(i24, @divExact(offset, 4))) |_| {
                return BranchType.b;
            } else {
                return emit.fail("TODO support larger branches", .{});
            }
        },
        else => unreachable,
    }
}

fn instructionSize(emit: *Emit, inst: Mir.Inst.Index) usize {
    const tag = emit.mir.instructions.items(.tag)[inst];

    if (isBranch(tag)) {
        switch (emit.branch_types.get(inst).?) {
            .b => return 4,
        }
    }

    switch (tag) {
        .dbg_line,
        .dbg_epilogue_begin,
        .dbg_prologue_end,
        => return 0,

        .sub_sp_scratch_r4 => {
            const imm32 = emit.mir.instructions.items(.data)[inst].imm32;

            if (imm32 == 0) {
                return 0 * 4;
            } else if (Instruction.Operand.fromU32(imm32) != null) {
                // sub
                return 1 * 4;
            } else if (Target.arm.featureSetHas(emit.target.cpu.features, .has_v7)) {
                // movw; movt; sub
                return 3 * 4;
            } else {
                // mov; orr; orr; orr; sub
                return 5 * 4;
            }
        },

        else => return 4,
    }
}

fn isBranch(tag: Mir.Inst.Tag) bool {
    return switch (tag) {
        .b => true,
        else => false,
    };
}

fn branchTarget(emit: *Emit, inst: Mir.Inst.Index) Mir.Inst.Index {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .b => return emit.mir.instructions.items(.data)[inst].inst,
        else => unreachable,
    }
}

fn lowerBranches(emit: *Emit) !void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    const mir_tags = emit.mir.instructions.items(.tag);

    // First pass: Note down all branches and their target
    // instructions, i.e. populate branch_types,
    // branch_forward_origins, and code_offset_mapping
    //
    // TODO optimization opportunity: do this in codegen while
    // generating MIR
    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        if (isBranch(tag)) {
            const target_inst = emit.branchTarget(inst);

            // Remember this branch instruction
            try emit.branch_types.put(gpa, inst, BranchType.default(tag));

            // Forward branches require some extra stuff: We only
            // know their offset once we arrive at the target
            // instruction. Therefore, we need to be able to
            // access the branch instruction when we visit the
            // target instruction in order to manipulate its type
            // etc.
            if (target_inst > inst) {
                // Remember the branch instruction index
                try emit.code_offset_mapping.put(gpa, inst, 0);

                if (emit.branch_forward_origins.getPtr(target_inst)) |origin_list| {
                    try origin_list.append(gpa, inst);
                } else {
                    var origin_list: std.ArrayListUnmanaged(Mir.Inst.Index) = .{};
                    try origin_list.append(gpa, inst);
                    try emit.branch_forward_origins.put(gpa, target_inst, origin_list);
                }
            }

            // Remember the target instruction index so that we
            // update the real code offset in all future passes
            //
            // putNoClobber may not be used as the put operation
            // may clobber the entry when multiple branches branch
            // to the same target instruction
            try emit.code_offset_mapping.put(gpa, target_inst, 0);
        }
    }

    // Further passes: Until all branches are lowered, interate
    // through all instructions and calculate new offsets and
    // potentially new branch types
    var all_branches_lowered = false;
    while (!all_branches_lowered) {
        all_branches_lowered = true;
        var current_code_offset: usize = 0;

        for (mir_tags, 0..) |tag, index| {
            const inst = @as(u32, @intCast(index));

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
                    const offset = @as(i64, @intCast(target_offset)) - @as(i64, @intCast(current_code_offset + 8));
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
                    const offset = @as(i64, @intCast(current_code_offset)) - @as(i64, @intCast(forward_branch_inst_offset + 8));
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
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    emit.err_msg = try ErrorMsg.create(gpa, emit.src_loc, format, args);
    return error.EmitFail;
}

fn dbgAdvancePCAndLine(self: *Emit, line: u32, column: u32) !void {
    const delta_line = @as(i32, @intCast(line)) - @as(i32, @intCast(self.prev_di_line));
    const delta_pc: usize = self.code.items.len - self.prev_di_pc;
    switch (self.debug_output) {
        .dwarf => |dw| {
            try dw.advancePCAndLine(delta_line, delta_pc);
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes

            // increasing the line number
            try link.File.Plan9.changeLine(&dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @as(i64, @intCast(delta_pc)) - dbg_out.pc_quanta;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one pc quanta
                try dbg_out.dbg_line.append(@as(u8, @intCast(@divExact(d_pc_p9, dbg_out.pc_quanta) + 128)) - dbg_out.pc_quanta);
                if (dbg_out.pcop_change_index) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index = @as(u32, @intCast(dbg_out.dbg_line.items.len - 1));
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the pc quanta does it for us
            } else unreachable;
            if (dbg_out.start_line == null)
                dbg_out.start_line = self.prev_di_line;
            dbg_out.end_line = line;
            // only do this if the pc changed
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .none => {},
    }
}

fn mirDataProcessing(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];

    switch (tag) {
        .add,
        .adds,
        .@"and",
        .eor,
        .orr,
        .rsb,
        .sub,
        .subs,
        => {
            const rr_op = emit.mir.instructions.items(.data)[inst].rr_op;
            switch (tag) {
                .add => try emit.writeInstruction(Instruction.add(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .adds => try emit.writeInstruction(Instruction.adds(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .@"and" => try emit.writeInstruction(Instruction.@"and"(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .eor => try emit.writeInstruction(Instruction.eor(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .orr => try emit.writeInstruction(Instruction.orr(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .rsb => try emit.writeInstruction(Instruction.rsb(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .sub => try emit.writeInstruction(Instruction.sub(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                .subs => try emit.writeInstruction(Instruction.subs(cond, rr_op.rd, rr_op.rn, rr_op.op)),
                else => unreachable,
            }
        },
        .cmp => {
            const r_op_cmp = emit.mir.instructions.items(.data)[inst].r_op_cmp;
            try emit.writeInstruction(Instruction.cmp(cond, r_op_cmp.rn, r_op_cmp.op));
        },
        .mov,
        .mvn,
        => {
            const r_op_mov = emit.mir.instructions.items(.data)[inst].r_op_mov;
            switch (tag) {
                .mov => try emit.writeInstruction(Instruction.mov(cond, r_op_mov.rd, r_op_mov.op)),
                .mvn => try emit.writeInstruction(Instruction.mvn(cond, r_op_mov.rd, r_op_mov.op)),
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

fn mirSubStackPointer(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const imm32 = emit.mir.instructions.items(.data)[inst].imm32;

    switch (tag) {
        .sub_sp_scratch_r4 => {
            if (imm32 == 0) return;

            const operand = Instruction.Operand.fromU32(imm32) orelse blk: {
                const scratch: Register = .r4;

                if (Target.arm.featureSetHas(emit.target.cpu.features, .has_v7)) {
                    try emit.writeInstruction(Instruction.movw(cond, scratch, @as(u16, @truncate(imm32))));
                    try emit.writeInstruction(Instruction.movt(cond, scratch, @as(u16, @truncate(imm32 >> 16))));
                } else {
                    try emit.writeInstruction(Instruction.mov(cond, scratch, Instruction.Operand.imm(@as(u8, @truncate(imm32)), 0)));
                    try emit.writeInstruction(Instruction.orr(cond, scratch, scratch, Instruction.Operand.imm(@as(u8, @truncate(imm32 >> 8)), 12)));
                    try emit.writeInstruction(Instruction.orr(cond, scratch, scratch, Instruction.Operand.imm(@as(u8, @truncate(imm32 >> 16)), 8)));
                    try emit.writeInstruction(Instruction.orr(cond, scratch, scratch, Instruction.Operand.imm(@as(u8, @truncate(imm32 >> 24)), 4)));
                }

                break :blk Instruction.Operand.reg(scratch, Instruction.Operand.Shift.none);
            };

            try emit.writeInstruction(Instruction.sub(cond, .sp, .sp, operand));
        },
        else => unreachable,
    }
}

fn mirShift(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rr_shift = emit.mir.instructions.items(.data)[inst].rr_shift;

    switch (tag) {
        .asr => try emit.writeInstruction(Instruction.asr(cond, rr_shift.rd, rr_shift.rm, rr_shift.shift_amount)),
        .lsl => try emit.writeInstruction(Instruction.lsl(cond, rr_shift.rd, rr_shift.rm, rr_shift.shift_amount)),
        .lsr => try emit.writeInstruction(Instruction.lsr(cond, rr_shift.rd, rr_shift.rm, rr_shift.shift_amount)),
        else => unreachable,
    }
}

fn mirBranch(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const target_inst = emit.mir.instructions.items(.data)[inst].inst;

    const offset = @as(i64, @intCast(emit.code_offset_mapping.get(target_inst).?)) - @as(i64, @intCast(emit.code.items.len + 8));
    const branch_type = emit.branch_types.get(inst).?;

    switch (branch_type) {
        .b => switch (tag) {
            .b => try emit.writeInstruction(Instruction.b(cond, @as(i26, @intCast(offset)))),
            else => unreachable,
        },
    }
}

fn mirUndefinedInstruction(emit: *Emit) !void {
    try emit.writeInstruction(Instruction.undefinedInstruction());
}

fn mirExceptionGeneration(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const imm16 = emit.mir.instructions.items(.data)[inst].imm16;

    switch (tag) {
        .bkpt => try emit.writeInstruction(Instruction.bkpt(imm16)),
        else => unreachable,
    }
}

fn mirBranchExchange(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const reg = emit.mir.instructions.items(.data)[inst].reg;

    switch (tag) {
        .blx => try emit.writeInstruction(Instruction.blx(cond, reg)),
        .bx => try emit.writeInstruction(Instruction.bx(cond, reg)),
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

fn mirDebugPrologueEnd(emit: *Emit) !void {
    switch (emit.debug_output) {
        .dwarf => |dw| {
            try dw.setPrologueEnd();
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(emit: *Emit) !void {
    switch (emit.debug_output) {
        .dwarf => |dw| {
            try dw.setEpilogueBegin();
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirLoadStore(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rr_offset = emit.mir.instructions.items(.data)[inst].rr_offset;

    switch (tag) {
        .ldr => try emit.writeInstruction(Instruction.ldr(cond, rr_offset.rt, rr_offset.rn, rr_offset.offset)),
        .ldrb => try emit.writeInstruction(Instruction.ldrb(cond, rr_offset.rt, rr_offset.rn, rr_offset.offset)),
        .str => try emit.writeInstruction(Instruction.str(cond, rr_offset.rt, rr_offset.rn, rr_offset.offset)),
        .strb => try emit.writeInstruction(Instruction.strb(cond, rr_offset.rt, rr_offset.rn, rr_offset.offset)),
        else => unreachable,
    }
}

fn mirLoadStackArgument(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const r_stack_offset = emit.mir.instructions.items(.data)[inst].r_stack_offset;
    const rt = r_stack_offset.rt;

    const raw_offset = emit.stack_size + emit.saved_regs_stack_space + r_stack_offset.stack_offset;
    switch (tag) {
        .ldr_ptr_stack_argument => {
            const operand = Instruction.Operand.fromU32(raw_offset) orelse
                return emit.fail("TODO mirLoadStack larger offsets", .{});

            try emit.writeInstruction(Instruction.add(cond, rt, .sp, operand));
        },
        .ldr_stack_argument,
        .ldrb_stack_argument,
        => {
            const offset = if (raw_offset <= math.maxInt(u12)) blk: {
                break :blk Instruction.Offset.imm(@as(u12, @intCast(raw_offset)));
            } else return emit.fail("TODO mirLoadStack larger offsets", .{});

            switch (tag) {
                .ldr_stack_argument => try emit.writeInstruction(Instruction.ldr(cond, rt, .sp, .{ .offset = offset })),
                .ldrb_stack_argument => try emit.writeInstruction(Instruction.ldrb(cond, rt, .sp, .{ .offset = offset })),
                else => unreachable,
            }
        },
        .ldrh_stack_argument,
        .ldrsb_stack_argument,
        .ldrsh_stack_argument,
        => {
            const offset = if (raw_offset <= math.maxInt(u8)) blk: {
                break :blk Instruction.ExtraLoadStoreOffset.imm(@as(u8, @intCast(raw_offset)));
            } else return emit.fail("TODO mirLoadStack larger offsets", .{});

            switch (tag) {
                .ldrh_stack_argument => try emit.writeInstruction(Instruction.ldrh(cond, rt, .sp, .{ .offset = offset })),
                .ldrsb_stack_argument => try emit.writeInstruction(Instruction.ldrsb(cond, rt, .sp, .{ .offset = offset })),
                .ldrsh_stack_argument => try emit.writeInstruction(Instruction.ldrsh(cond, rt, .sp, .{ .offset = offset })),
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

fn mirLoadStoreExtra(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rr_extra_offset = emit.mir.instructions.items(.data)[inst].rr_extra_offset;

    switch (tag) {
        .ldrh => try emit.writeInstruction(Instruction.ldrh(cond, rr_extra_offset.rt, rr_extra_offset.rn, rr_extra_offset.offset)),
        .ldrsb => try emit.writeInstruction(Instruction.ldrsb(cond, rr_extra_offset.rt, rr_extra_offset.rn, rr_extra_offset.offset)),
        .ldrsh => try emit.writeInstruction(Instruction.ldrsh(cond, rr_extra_offset.rt, rr_extra_offset.rn, rr_extra_offset.offset)),
        .strh => try emit.writeInstruction(Instruction.strh(cond, rr_extra_offset.rt, rr_extra_offset.rn, rr_extra_offset.offset)),
        else => unreachable,
    }
}

fn mirSpecialMove(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const r_imm16 = emit.mir.instructions.items(.data)[inst].r_imm16;

    switch (tag) {
        .movw => try emit.writeInstruction(Instruction.movw(cond, r_imm16.rd, r_imm16.imm16)),
        .movt => try emit.writeInstruction(Instruction.movt(cond, r_imm16.rd, r_imm16.imm16)),
        else => unreachable,
    }
}

fn mirMultiply(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rrr = emit.mir.instructions.items(.data)[inst].rrr;

    switch (tag) {
        .mul => try emit.writeInstruction(Instruction.mul(cond, rrr.rd, rrr.rn, rrr.rm)),
        .smulbb => try emit.writeInstruction(Instruction.smulbb(cond, rrr.rd, rrr.rn, rrr.rm)),
        else => unreachable,
    }
}

fn mirMultiplyLong(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rrrr = emit.mir.instructions.items(.data)[inst].rrrr;

    switch (tag) {
        .smull => try emit.writeInstruction(Instruction.smull(cond, rrrr.rdlo, rrrr.rdhi, rrrr.rn, rrrr.rm)),
        .umull => try emit.writeInstruction(Instruction.umull(cond, rrrr.rdlo, rrrr.rdhi, rrrr.rn, rrrr.rm)),
        else => unreachable,
    }
}

fn mirNop(emit: *Emit) !void {
    try emit.writeInstruction(Instruction.nop());
}

fn mirBlockDataTransfer(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const register_list = emit.mir.instructions.items(.data)[inst].register_list;

    switch (tag) {
        .pop => try emit.writeInstruction(Instruction.ldm(cond, .sp, true, register_list)),
        .push => try emit.writeInstruction(Instruction.stmdb(cond, .sp, true, register_list)),
        else => unreachable,
    }
}

fn mirSupervisorCall(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const imm24 = emit.mir.instructions.items(.data)[inst].imm24;

    switch (tag) {
        .svc => try emit.writeInstruction(Instruction.svc(cond, imm24)),
        else => unreachable,
    }
}

fn mirBitFieldExtract(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const cond = emit.mir.instructions.items(.cond)[inst];
    const rr_lsb_width = emit.mir.instructions.items(.data)[inst].rr_lsb_width;
    const rd = rr_lsb_width.rd;
    const rn = rr_lsb_width.rn;
    const lsb = rr_lsb_width.lsb;
    const width = rr_lsb_width.width;

    switch (tag) {
        .sbfx => try emit.writeInstruction(Instruction.sbfx(cond, rd, rn, lsb, width)),
        .ubfx => try emit.writeInstruction(Instruction.ubfx(cond, rd, rn, lsb, width)),
        else => unreachable,
    }
}
