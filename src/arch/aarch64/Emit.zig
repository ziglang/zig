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
    b_cond,
    unconditional_branch_immediate,

    fn default(tag: Mir.Inst.Tag) BranchType {
        return switch (tag) {
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
            .cmp_immediate => try emit.mirAddSubtractImmediate(inst),
            .sub_immediate => try emit.mirAddSubtractImmediate(inst),

            .b_cond => try emit.mirConditionalBranchImmediate(inst),

            .b => try emit.mirBranch(inst),
            .bl => try emit.mirBranch(inst),

            .blr => try emit.mirUnconditionalBranchRegister(inst),
            .ret => try emit.mirUnconditionalBranchRegister(inst),

            .brk => try emit.mirExceptionGeneration(inst),
            .svc => try emit.mirExceptionGeneration(inst),

            .call_extern => try emit.mirCallExtern(inst),

            .cmp_shifted_register => try emit.mirAddSubtractShiftedRegister(inst),

            .cset => try emit.mirConditionalSelect(inst),

            .dbg_line => try emit.mirDbgLine(inst),

            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .load_memory => try emit.mirLoadMemory(inst),

            .ldp => try emit.mirLoadStoreRegisterPair(inst),
            .stp => try emit.mirLoadStoreRegisterPair(inst),

            .ldr_stack => try emit.mirLoadStoreStack(inst),
            .ldrb_stack => try emit.mirLoadStoreStack(inst),
            .ldrh_stack => try emit.mirLoadStoreStack(inst),
            .str_stack => try emit.mirLoadStoreStack(inst),
            .strb_stack => try emit.mirLoadStoreStack(inst),
            .strh_stack => try emit.mirLoadStoreStack(inst),

            .ldr => try emit.mirLoadStoreRegister(inst),
            .ldrb => try emit.mirLoadStoreRegister(inst),
            .ldrh => try emit.mirLoadStoreRegister(inst),
            .str => try emit.mirLoadStoreRegister(inst),
            .strb => try emit.mirLoadStoreRegister(inst),
            .strh => try emit.mirLoadStoreRegister(inst),

            .mov_register => try emit.mirMoveRegister(inst),
            .mov_to_from_sp => try emit.mirMoveRegister(inst),

            .movk => try emit.mirMoveWideImmediate(inst),
            .movz => try emit.mirMoveWideImmediate(inst),

            .nop => try emit.mirNop(),

            .push_regs => try emit.mirPushPopRegs(inst),
            .pop_regs => try emit.mirPushPopRegs(inst),
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
        .b, .bl => {
            if (std.math.cast(i26, offset >> 2)) |_| {
                return BranchType.unconditional_branch_immediate;
            } else |_| {
                return emit.fail("TODO support branches larger than +-128 MiB", .{});
            }
        },
        .b_cond => {
            if (std.math.cast(i19, offset >> 2)) |_| {
                return BranchType.b_cond;
            } else |_| {
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
            .unconditional_branch_immediate => return 4,
            .b_cond => return 4,
        }
    }

    switch (tag) {
        .load_memory => {
            if (emit.bin_file.options.pie) {
                // adrp, ldr
                return 2 * 4;
            } else {
                const payload = emit.mir.instructions.items(.data)[inst].payload;
                const load_memory = emit.mir.extraData(Mir.LoadMemory, payload).data;
                const addr = load_memory.addr;

                // movz, [movk, ...], ldr
                if (addr <= math.maxInt(u16)) return 2 * 4;
                if (addr <= math.maxInt(u32)) return 3 * 4;
                if (addr <= math.maxInt(u48)) return 4 * 4;
                return 5 * 4;
            }
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
        .b, .bl, .b_cond => true,
        else => false,
    };
}

fn branchTarget(emit: *Emit, inst: Mir.Inst.Index) Mir.Inst.Index {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
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

fn moveImmediate(emit: *Emit, reg: Register, imm64: u64) !void {
    try emit.writeInstruction(Instruction.movz(reg, @truncate(u16, imm64), 0));

    if (imm64 > math.maxInt(u16)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 16), 16));
    }
    if (imm64 > math.maxInt(u32)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 32), 32));
    }
    if (imm64 > math.maxInt(u48)) {
        try emit.writeInstruction(Instruction.movk(reg, @truncate(u16, imm64 >> 48), 48));
    }
}

fn dbgAdvancePCAndLine(self: *Emit, line: u32, column: u32) !void {
    const delta_line = @intCast(i32, line) - @intCast(i32, self.prev_di_line);
    const delta_pc: usize = self.code.items.len - self.prev_di_pc;
    switch (self.debug_output) {
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
    const rr_imm12_sh = emit.mir.instructions.items(.data)[inst].rr_imm12_sh;

    switch (tag) {
        .add_immediate => try emit.writeInstruction(Instruction.add(
            rr_imm12_sh.rd,
            rr_imm12_sh.rn,
            rr_imm12_sh.imm12,
            rr_imm12_sh.sh == 1,
        )),
        .cmp_immediate => try emit.writeInstruction(Instruction.subs(
            rr_imm12_sh.rd,
            rr_imm12_sh.rn,
            rr_imm12_sh.imm12,
            rr_imm12_sh.sh == 1,
        )),
        .sub_immediate => try emit.writeInstruction(Instruction.sub(
            rr_imm12_sh.rd,
            rr_imm12_sh.rn,
            rr_imm12_sh.imm12,
            rr_imm12_sh.sh == 1,
        )),
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
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_prologue_end);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_epilogue_begin);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirCallExtern(emit: *Emit, inst: Mir.Inst.Index) !void {
    assert(emit.mir.instructions.items(.tag)[inst] == .call_extern);
    const n_strx = emit.mir.instructions.items(.data)[inst].extern_fn;

    if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
        const offset = blk: {
            const offset = @intCast(u32, emit.code.items.len);
            // bl
            try emit.writeInstruction(Instruction.bl(0));
            break :blk offset;
        };
        // Add relocation to the decl.
        try macho_file.active_decl.?.link.macho.relocs.append(emit.bin_file.allocator, .{
            .offset = offset,
            .target = .{ .global = n_strx },
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

fn mirAddSubtractShiftedRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rrr_imm6_shift = emit.mir.instructions.items(.data)[inst].rrr_imm6_shift;

    switch (tag) {
        .cmp_shifted_register => try emit.writeInstruction(Instruction.subsShiftedRegister(
            rrr_imm6_shift.rd,
            rrr_imm6_shift.rn,
            rrr_imm6_shift.rm,
            rrr_imm6_shift.shift,
            rrr_imm6_shift.imm6,
        )),
        else => unreachable,
    }
}

fn mirConditionalSelect(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rrr_cond = emit.mir.instructions.items(.data)[inst].rrr_cond;

    switch (tag) {
        .cset => try emit.writeInstruction(Instruction.csinc(
            rrr_cond.rd,
            rrr_cond.rn,
            rrr_cond.rm,
            rrr_cond.cond,
        )),
        else => unreachable,
    }
}

fn mirLoadMemory(emit: *Emit, inst: Mir.Inst.Index) !void {
    assert(emit.mir.instructions.items(.tag)[inst] == .load_memory);
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const load_memory = emit.mir.extraData(Mir.LoadMemory, payload).data;
    const reg = @intToEnum(Register, load_memory.register);
    const addr = load_memory.addr;

    if (emit.bin_file.options.pie) {
        // PC-relative displacement to the entry in the GOT table.
        // adrp
        const offset = @intCast(u32, emit.code.items.len);
        try emit.writeInstruction(Instruction.adrp(reg, 0));

        // ldr reg, reg, offset
        try emit.writeInstruction(Instruction.ldr(
            reg,
            reg,
            Instruction.LoadStoreOffset.imm(0),
        ));

        if (emit.bin_file.cast(link.File.MachO)) |macho_file| {
            // TODO I think the reloc might be in the wrong place.
            const decl = macho_file.active_decl.?;
            // Page reloc for adrp instruction.
            try decl.link.macho.relocs.append(emit.bin_file.allocator, .{
                .offset = offset,
                .target = .{ .local = addr },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGE21),
            });
            // Pageoff reloc for adrp instruction.
            try decl.link.macho.relocs.append(emit.bin_file.allocator, .{
                .offset = offset + 4,
                .target = .{ .local = addr },
                .addend = 0,
                .subtractor = null,
                .pcrel = false,
                .length = 2,
                .@"type" = @enumToInt(std.macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGEOFF12),
            });
        } else {
            return emit.fail("TODO implement load_memory for PIE GOT indirection on this platform", .{});
        }
    } else {
        // The value is in memory at a hard-coded address.
        // If the type is a pointer, it means the pointer address is at this memory location.
        try emit.moveImmediate(reg, addr);
        try emit.writeInstruction(Instruction.ldr(
            reg,
            reg,
            Instruction.LoadStoreOffset.none,
        ));
    }
}

fn mirLoadStoreRegisterPair(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register_pair = emit.mir.instructions.items(.data)[inst].load_store_register_pair;

    switch (tag) {
        .stp => try emit.writeInstruction(Instruction.stp(
            load_store_register_pair.rt,
            load_store_register_pair.rt2,
            load_store_register_pair.rn,
            load_store_register_pair.offset,
        )),
        .ldp => try emit.writeInstruction(Instruction.ldp(
            load_store_register_pair.rt,
            load_store_register_pair.rt2,
            load_store_register_pair.rn,
            load_store_register_pair.offset,
        )),
        else => unreachable,
    }
}

fn mirLoadStoreStack(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_stack = emit.mir.instructions.items(.data)[inst].load_store_stack;

    const raw_offset = emit.stack_size - load_store_stack.offset;
    const offset = switch (tag) {
        .ldrb_stack, .strb_stack => blk: {
            if (math.cast(u12, raw_offset)) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else |_| {
                return emit.fail("TODO load/store stack byte with larger offset", .{});
            }
        },
        .ldrh_stack, .strh_stack => blk: {
            assert(std.mem.isAlignedGeneric(u32, raw_offset, 2)); // misaligned stack entry
            if (math.cast(u12, @divExact(raw_offset, 2))) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else |_| {
                return emit.fail("TODO load/store stack halfword with larger offset", .{});
            }
        },
        .ldr_stack, .str_stack => blk: {
            const alignment: u32 = switch (load_store_stack.rt.size()) {
                32 => 4,
                64 => 8,
                else => unreachable,
            };

            assert(std.mem.isAlignedGeneric(u32, raw_offset, alignment)); // misaligned stack entry
            if (math.cast(u12, @divExact(raw_offset, alignment))) |imm| {
                break :blk Instruction.LoadStoreOffset.imm(imm);
            } else |_| {
                return emit.fail("TODO load/store stack with larger offset", .{});
            }
        },
        else => unreachable,
    };

    switch (tag) {
        .ldr_stack => try emit.writeInstruction(Instruction.ldr(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        .ldrb_stack => try emit.writeInstruction(Instruction.ldrb(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        .ldrh_stack => try emit.writeInstruction(Instruction.ldrh(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        .str_stack => try emit.writeInstruction(Instruction.str(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        .strb_stack => try emit.writeInstruction(Instruction.strb(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        .strh_stack => try emit.writeInstruction(Instruction.strh(
            load_store_stack.rt,
            Register.sp,
            offset,
        )),
        else => unreachable,
    }
}

fn mirLoadStoreRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const load_store_register = emit.mir.instructions.items(.data)[inst].load_store_register;

    switch (tag) {
        .ldr => try emit.writeInstruction(Instruction.ldr(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        .ldrb => try emit.writeInstruction(Instruction.ldrb(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        .ldrh => try emit.writeInstruction(Instruction.ldrh(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        .str => try emit.writeInstruction(Instruction.str(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        .strb => try emit.writeInstruction(Instruction.strb(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        .strh => try emit.writeInstruction(Instruction.strh(
            load_store_register.rt,
            load_store_register.rn,
            load_store_register.offset,
        )),
        else => unreachable,
    }
}

fn mirMoveRegister(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr = emit.mir.instructions.items(.data)[inst].rr;

    switch (tag) {
        .mov_register => try emit.writeInstruction(Instruction.orr(rr.rd, .xzr, rr.rn, Instruction.Shift.none)),
        .mov_to_from_sp => try emit.writeInstruction(Instruction.add(rr.rd, rr.rn, 0, false)),
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
                if (reg_list & @as(u32, 1) << reg.id() != 0) {
                    if (count % 2 == 0) {
                        if (count == number_of_regs - 1) {
                            try emit.writeInstruction(Instruction.ldr(
                                reg,
                                Register.sp,
                                Instruction.LoadStoreOffset.imm_post_index(16),
                            ));
                        } else {
                            other_reg = reg;
                        }
                    } else {
                        try emit.writeInstruction(Instruction.ldp(
                            reg,
                            other_reg,
                            Register.sp,
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
                if (reg_list & @as(u32, 1) << reg.id() != 0) {
                    if (count % 2 == 0) {
                        if (count == number_of_regs - 1) {
                            try emit.writeInstruction(Instruction.str(
                                reg,
                                Register.sp,
                                Instruction.LoadStoreOffset.imm_pre_index(-16),
                            ));
                        } else {
                            other_reg = reg;
                        }
                    } else {
                        try emit.writeInstruction(Instruction.stp(
                            other_reg,
                            reg,
                            Register.sp,
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
