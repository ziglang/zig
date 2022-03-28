//! This file contains the functionality for lowering SPARCv9 MIR into
//! machine code

const std = @import("std");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const Liveness = @import("../../Liveness.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

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
    _ = emit;

    @panic("TODO implement emitMir");
}

pub fn deinit(emit: *Emit) void {
    emit.* = undefined;
}
