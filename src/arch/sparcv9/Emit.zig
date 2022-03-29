//! This file contains the functionality for lowering SPARCv9 MIR into
//! machine code

const std = @import("std");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const Liveness = @import("../../Liveness.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;

const Emit = @This();
const Mir = @import("Mir.zig");
const bits = @import("bits.zig");

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
        }
    }
}

pub fn deinit(emit: *Emit) void {
    emit.* = undefined;
}

fn dbgAdvancePCAndLine(self: *Emit, line: u32, column: u32) !void {
    _ = self;
    _ = line;
    _ = column;

    @panic("TODO implement dbgAdvancePCAndLine");
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
