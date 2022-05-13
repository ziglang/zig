//! This file contains the functionality for lowering SPARCv9 MIR into
//! machine code

const std = @import("std");
const Endian = std.builtin.Endian;
const assert = std.debug.assert;
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const Liveness = @import("../../Liveness.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;
const leb128 = std.leb;

const Emit = @This();
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");
const Instruction = bits.Instruction;
const Register = bits.Register;

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
    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            .dbg_line => try emit.mirDbgLine(inst),
            .dbg_prologue_end => try emit.mirDebugPrologueEnd(),
            .dbg_epilogue_begin => try emit.mirDebugEpilogueBegin(),

            .add => try emit.mirArithmetic3Op(inst),

            .bpcc => @panic("TODO implement sparc64 bpcc"),

            .call => @panic("TODO implement sparc64 call"),

            .jmpl => try emit.mirArithmetic3Op(inst),

            .ldub => try emit.mirArithmetic3Op(inst),
            .lduh => try emit.mirArithmetic3Op(inst),
            .lduw => try emit.mirArithmetic3Op(inst),
            .ldx => try emit.mirArithmetic3Op(inst),

            .@"or" => try emit.mirArithmetic3Op(inst),

            .nop => try emit.mirNop(),

            .@"return" => try emit.mirArithmetic2Op(inst),

            .save => try emit.mirArithmetic3Op(inst),
            .restore => try emit.mirArithmetic3Op(inst),

            .sethi => try emit.mirSethi(inst),

            .sllx => @panic("TODO implement sparc64 sllx"),

            .stb => try emit.mirArithmetic3Op(inst),
            .sth => try emit.mirArithmetic3Op(inst),
            .stw => try emit.mirArithmetic3Op(inst),
            .stx => try emit.mirArithmetic3Op(inst),

            .sub => try emit.mirArithmetic3Op(inst),

            .tcc => try emit.mirTrap(inst),
        }
    }
}

pub fn deinit(emit: *Emit) void {
    emit.* = undefined;
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
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_prologue_end);
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirDebugEpilogueBegin(emit: *Emit) !void {
    switch (emit.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_epilogue_begin);
            try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn mirArithmetic2Op(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst].arithmetic_2op;

    const rs1 = data.rs1;

    if (data.is_imm) {
        const imm = data.rs2_or_imm.imm;
        switch (tag) {
            .@"return" => try emit.writeInstruction(Instruction.@"return"(i13, rs1, imm)),
            else => unreachable,
        }
    } else {
        const rs2 = data.rs2_or_imm.rs2;
        switch (tag) {
            .@"return" => try emit.writeInstruction(Instruction.@"return"(Register, rs1, rs2)),
            else => unreachable,
        }
    }
}

fn mirArithmetic3Op(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst].arithmetic_3op;

    const rd = data.rd;
    const rs1 = data.rs1;

    if (data.is_imm) {
        const imm = data.rs2_or_imm.imm;
        switch (tag) {
            .add => try emit.writeInstruction(Instruction.add(i13, rs1, imm, rd)),
            .jmpl => try emit.writeInstruction(Instruction.jmpl(i13, rs1, imm, rd)),
            .ldub => try emit.writeInstruction(Instruction.ldub(i13, rs1, imm, rd)),
            .lduh => try emit.writeInstruction(Instruction.lduh(i13, rs1, imm, rd)),
            .lduw => try emit.writeInstruction(Instruction.lduw(i13, rs1, imm, rd)),
            .ldx => try emit.writeInstruction(Instruction.ldx(i13, rs1, imm, rd)),
            .@"or" => try emit.writeInstruction(Instruction.@"or"(i13, rs1, imm, rd)),
            .save => try emit.writeInstruction(Instruction.save(i13, rs1, imm, rd)),
            .restore => try emit.writeInstruction(Instruction.restore(i13, rs1, imm, rd)),
            .stb => try emit.writeInstruction(Instruction.stb(i13, rs1, imm, rd)),
            .sth => try emit.writeInstruction(Instruction.sth(i13, rs1, imm, rd)),
            .stw => try emit.writeInstruction(Instruction.stw(i13, rs1, imm, rd)),
            .stx => try emit.writeInstruction(Instruction.stx(i13, rs1, imm, rd)),
            .sub => try emit.writeInstruction(Instruction.sub(i13, rs1, imm, rd)),
            else => unreachable,
        }
    } else {
        const rs2 = data.rs2_or_imm.rs2;
        switch (tag) {
            .add => try emit.writeInstruction(Instruction.add(Register, rs1, rs2, rd)),
            .jmpl => try emit.writeInstruction(Instruction.jmpl(Register, rs1, rs2, rd)),
            .ldub => try emit.writeInstruction(Instruction.ldub(Register, rs1, rs2, rd)),
            .lduh => try emit.writeInstruction(Instruction.lduh(Register, rs1, rs2, rd)),
            .lduw => try emit.writeInstruction(Instruction.lduw(Register, rs1, rs2, rd)),
            .ldx => try emit.writeInstruction(Instruction.ldx(Register, rs1, rs2, rd)),
            .@"or" => try emit.writeInstruction(Instruction.@"or"(Register, rs1, rs2, rd)),
            .save => try emit.writeInstruction(Instruction.save(Register, rs1, rs2, rd)),
            .restore => try emit.writeInstruction(Instruction.restore(Register, rs1, rs2, rd)),
            .stb => try emit.writeInstruction(Instruction.stb(Register, rs1, rs2, rd)),
            .sth => try emit.writeInstruction(Instruction.sth(Register, rs1, rs2, rd)),
            .stw => try emit.writeInstruction(Instruction.stw(Register, rs1, rs2, rd)),
            .stx => try emit.writeInstruction(Instruction.stx(Register, rs1, rs2, rd)),
            .sub => try emit.writeInstruction(Instruction.sub(Register, rs1, rs2, rd)),
            else => unreachable,
        }
    }
}

fn mirNop(emit: *Emit) !void {
    try emit.writeInstruction(Instruction.nop());
}

fn mirSethi(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst].sethi;

    const imm = data.imm;
    const rd = data.rd;

    assert(tag == .sethi);
    try emit.writeInstruction(Instruction.sethi(imm, rd));
}

fn mirTrap(emit: *Emit, inst: Mir.Inst.Index) !void {
    const tag = emit.mir.instructions.items(.tag)[inst];
    const data = emit.mir.instructions.items(.data)[inst].trap;

    const cond = data.cond;
    const ccr = data.ccr;
    const rs1 = data.rs1;

    if (data.is_imm) {
        const imm = data.rs2_or_imm.imm;
        switch (tag) {
            .tcc => try emit.writeInstruction(Instruction.trap(u7, cond, ccr, rs1, imm)),
            else => unreachable,
        }
    } else {
        const rs2 = data.rs2_or_imm.rs2;
        switch (tag) {
            .tcc => try emit.writeInstruction(Instruction.trap(Register, cond, ccr, rs1, rs2)),
            else => unreachable,
        }
    }
}

// Common helper functions

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) !void {
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
        else => {},
    }
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(emit.err_msg == null);
    emit.err_msg = try ErrorMsg.create(emit.bin_file.allocator, emit.src_loc, format, args);
    return error.EmitFail;
}

fn writeInstruction(emit: *Emit, instruction: Instruction) !void {
    // SPARCv9 instructions are always arranged in BE regardless of the
    // endianness mode the CPU is running in (Section 3.1 of the ISA specification).
    // This is to ease porting in case someone wants to do a LE SPARCv9 backend.
    const endian = Endian.Big;

    std.mem.writeInt(u32, try emit.code.addManyAsArray(4), instruction.toU32(), endian);
}
