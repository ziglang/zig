//! This file contains the functionality for lowering RISCV64 MIR into
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
const Instruction = bits.Instruction;
const Register = bits.Register;
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

const log = std.log.scoped(.emit);

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(
    emit: *Emit,
) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    // TODO: compute branch offsets
    // try emit.lowerMir();

    // Emit machine code
    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        log.debug("emitMir: {s}", .{@tagName(tag)});
        switch (tag) {
            .add => try emit.mirRType(inst),
            .sub => try emit.mirRType(inst),

            .cmp_eq => try emit.mirRType(inst),
            .cmp_gt => try emit.mirRType(inst),

            .beq => try emit.mirBType(inst),
            .bne => try emit.mirBType(inst),

            .addi => try emit.mirIType(inst),
            .jalr => try emit.mirIType(inst),

            .jal => try emit.mirJType(inst),

            .ebreak => try emit.mirSystem(inst),
            .ecall => try emit.mirSystem(inst),
            .unimp => try emit.mirSystem(inst),

            .dbg_line => try emit.mirDbgLine(inst),
            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .psuedo_prologue => try emit.mirPsuedo(inst),
            .psuedo_jump => try emit.mirPsuedo(inst),

            .mv => try emit.mirRR(inst),

            .nop => try emit.mirNop(inst),
            .ret => try emit.mirNop(inst),

            .lui => try emit.mirUType(inst),

            .ld => try emit.mirIType(inst),
            .sd => try emit.mirIType(inst),
            .lw => try emit.mirIType(inst),
            .sw => try emit.mirIType(inst),
            .lh => try emit.mirIType(inst),
            .sh => try emit.mirIType(inst),
            .lb => try emit.mirIType(inst),
            .sb => try emit.mirIType(inst),
            .ldr_ptr_stack => try emit.mirIType(inst),

            .load_symbol => try emit.mirLoadSymbol(inst),
        }
    }
}

pub fn deinit(emit: *Emit) void {
    emit.* = undefined;
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

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) !void {
    log.debug("Line: {} {}\n", .{ line, emit.prev_di_line });
    const delta_line = @as(i32, @intCast(line)) - @as(i32, @intCast(emit.prev_di_line));
    const delta_pc: usize = emit.code.items.len - emit.prev_di_pc;
    log.debug("(advance pc={d} and line={d})", .{ delta_pc, delta_line });
    switch (emit.debug_output) {
        .dwarf => |dw| {
            if (column != emit.prev_di_column) try dw.setColumn(column);
            if (delta_line == 0) return; // TODO: remove this
            try dw.advancePCAndLine(delta_line, delta_pc);
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
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
                dbg_out.start_line = emit.prev_di_line;
            dbg_out.end_line = line;
            // only do this if the pc changed
            emit.prev_di_line = line;
            emit.prev_di_column = column;
            emit.prev_di_pc = emit.code.items.len;
        },
        .none => {},
    }
}

fn mirRType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_type = emit.mir.instructions.items(.data)[inst].r_type;

    switch (tag) {
        .add => try emit.writeInstruction(Instruction.add(r_type.rd, r_type.rs1, r_type.rs2)),
        .sub => try emit.writeInstruction(Instruction.sub(r_type.rd, r_type.rs1, r_type.rs2)),
        .cmp_eq => try emit.writeInstruction(Instruction.slt(r_type.rd, r_type.rs1, r_type.rs2)),
        else => unreachable,
    }
}

fn mirBType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const b_type = emit.mir.instructions.items(.data)[inst].b_type;

    // const inst = b_type.imm12;

    switch (tag) {
        .beq => try emit.writeInstruction(Instruction.beq(b_type.rs1, b_type.rs2, b_type.imm12)),
        else => unreachable,
    }
}

fn mirIType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const i_type = emit.mir.instructions.items(.data)[inst].i_type;

    switch (tag) {
        .addi => try emit.writeInstruction(Instruction.addi(i_type.rd, i_type.rs1, i_type.imm12)),
        .jalr => try emit.writeInstruction(Instruction.jalr(i_type.rd, i_type.imm12, i_type.rs1)),

        .ld => try emit.writeInstruction(Instruction.ld(i_type.rd, i_type.imm12, i_type.rs1)),
        .sd => try emit.writeInstruction(Instruction.sd(i_type.rd, i_type.imm12, i_type.rs1)),
        .lw => try emit.writeInstruction(Instruction.lw(i_type.rd, i_type.imm12, i_type.rs1)),
        .sw => try emit.writeInstruction(Instruction.sw(i_type.rd, i_type.imm12, i_type.rs1)),
        .lh => try emit.writeInstruction(Instruction.lh(i_type.rd, i_type.imm12, i_type.rs1)),
        .sh => try emit.writeInstruction(Instruction.sh(i_type.rd, i_type.imm12, i_type.rs1)),
        .lb => try emit.writeInstruction(Instruction.lb(i_type.rd, i_type.imm12, i_type.rs1)),
        .sb => try emit.writeInstruction(Instruction.sb(i_type.rd, i_type.imm12, i_type.rs1)),

        .ldr_ptr_stack => try emit.writeInstruction(Instruction.add(i_type.rd, i_type.rs1, .sp)),

        else => unreachable,
    }
}

fn mirJType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const j_type = emit.mir.instructions.items(.data)[inst].j_type;

    switch (tag) {
        .jal => {
            try emit.writeInstruction(Instruction.jal(j_type.rd, j_type.imm21));
        },
        else => unreachable,
    }
}

fn mirSystem(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .ebreak => try emit.writeInstruction(Instruction.ebreak),
        .ecall => try emit.writeInstruction(Instruction.ecall),
        .unimp => try emit.writeInstruction(Instruction.unimp),
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

fn mirPsuedo(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst];

    switch (tag) {
        .psuedo_prologue => {
            const imm12 = data.imm12;
            const stack_size: i12 = @max(32, imm12);

            try emit.writeInstruction(Instruction.addi(.sp, .sp, -stack_size));
            try emit.writeInstruction(Instruction.sd(.ra, stack_size - 8, .sp));
            try emit.writeInstruction(Instruction.sd(.s0, stack_size - 16, .sp));
            try emit.writeInstruction(Instruction.addi(.s0, .sp, stack_size));
        },

        .psuedo_jump => {
            const target = data.inst;
            const offset: i12 = @intCast(emit.code.items.len);
            _ = target;

            try emit.writeInstruction(Instruction.jal(.s0, offset));
        },

        else => unreachable,
    }
}

fn mirRR(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const rr = emit.mir.instructions.items(.data)[inst].rr;

    switch (tag) {
        .mv => try emit.writeInstruction(Instruction.addi(rr.rd, rr.rs, 0)),
        else => unreachable,
    }
}

fn mirUType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const u_type = emit.mir.instructions.items(.data)[inst].u_type;

    switch (tag) {
        .lui => try emit.writeInstruction(Instruction.lui(u_type.rd, u_type.imm20)),
        else => unreachable,
    }
}

fn mirNop(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];

    switch (tag) {
        .nop => try emit.writeInstruction(Instruction.addi(.zero, .zero, 0)),
        .ret => try emit.writeInstruction(Instruction.jalr(.zero, 0, .ra)),
        else => unreachable,
    }
}

fn mirLoadSymbol(emit: *Emit, inst: Mir.Inst.Index) !void {
    // const tag = emit.mir.instructions.items(.tag)[inst];
    const payload = emit.mir.instructions.items(.data)[inst].payload;
    const data = emit.mir.extraData(Mir.LoadSymbolPayload, payload).data;
    const reg = @as(Register, @enumFromInt(data.register));

    const end_offset = @as(u32, @intCast(emit.code.items.len));
    try emit.writeInstruction(Instruction.lui(reg, 0));
    try emit.writeInstruction(Instruction.lw(reg, 0, reg));

    switch (emit.bin_file.tag) {
        .elf => {
            const elf_file = emit.bin_file.cast(link.File.Elf).?;
            const atom_ptr = elf_file.symbol(data.atom_index).atom(elf_file).?;

            const hi_r_type = @intFromEnum(std.elf.R_RISCV.HI20);

            try atom_ptr.addReloc(elf_file, .{
                .r_offset = end_offset,
                .r_info = (@as(u64, @intCast(data.sym_index)) << 32) | hi_r_type,
                .r_addend = 0,
            });

            const lo_r_type = @intFromEnum(std.elf.R_RISCV.LO12_I);

            try atom_ptr.addReloc(elf_file, .{
                .r_offset = end_offset + 4,
                .r_info = (@as(u64, @intCast(data.sym_index)) << 32) | lo_r_type,
                .r_addend = 0,
            });
        },
        else => unreachable,
    }
}

fn isBranch(tag: Mir.Inst.Tag) bool {
    switch (tag) {
        .psuedo_jump => true,
        else => false,
    }
}

fn lowerMir(emit: *Emit) !void {
    const comp = emit.bin_file.comp;
    const gpa = comp.gpa;
    const mir_tags = emit.mir.instructions.items(.tag);

    _ = gpa;

    for (mir_tags, 0..) |tag, index| {
        const inst: u32 = @intCast(index);

        if (isBranch(tag)) {
            const target_inst = emit.mir.instructions.items(.data)[inst].inst;

            _ = target_inst;
        }
    }
}
