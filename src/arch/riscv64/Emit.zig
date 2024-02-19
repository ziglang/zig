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

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(
    emit: *Emit,
) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    // Emit machine code
    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        switch (tag) {
            .add => try emit.mirRType(inst),
            .sub => try emit.mirRType(inst),

            .addi => try emit.mirIType(inst),
            .jalr => try emit.mirIType(inst),
            .ld => try emit.mirIType(inst),
            .sd => try emit.mirIType(inst),

            .ebreak => try emit.mirSystem(inst),
            .ecall => try emit.mirSystem(inst),
            .unimp => try emit.mirSystem(inst),

            .dbg_line => try emit.mirDbgLine(inst),

            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .mv => try emit.mirRR(inst),

            .nop => try emit.mirNop(inst),
            .ret => try emit.mirNop(inst),

            .lui => try emit.mirUType(inst),
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

fn mirRType(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const r_type = emit.mir.instructions.items(.data)[inst].r_type;

    switch (tag) {
        .add => try emit.writeInstruction(Instruction.add(r_type.rd, r_type.rs1, r_type.rs2)),
        .sub => try emit.writeInstruction(Instruction.sub(r_type.rd, r_type.rs1, r_type.rs2)),
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

fn mirDebugPrologueEnd(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            try dw.setPrologueEnd();
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(self: *Emit) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            try dw.setEpilogueBegin();
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
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
