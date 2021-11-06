//! Contains all logic to lower wasm MIR into its binary
//! or textual representation.

const Emit = @This();
const std = @import("std");
const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const ErrorMsg = Module.ErrorMsg;
const leb128 = std.leb;

/// Contains our list of instructions
mir: Mir,
/// Reference to the file handler
bin_file: *link.File,
/// Possible error message. When set, the value is allocated and
/// must be freed manually.
error_msg: ?*ErrorMsg = null,
/// The binary representation that will be emit by this module.
code: *std.ArrayList(u8),

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            .@"unreachable" => emit.emitNoop(tag),
            .block => emit.emitBlock(inst),
            .loop => emit.emitBlock(inst),
            .end => emit.emitNoop(tag),
            .br => emit.emitBr(inst),
            .br_if => emit.emitBr(inst),
            .br_table => emit.emitBrTable(inst),
            .@"return" => emit.emitNoop(tag),
            .local_get => emit.emitLabel(tag, inst),
            .local_set => emit.emitLabel(tag, inst),
            .local_tee => emit.emitLabel(tag, inst),
            .global_get => emit.emitGlobal(tag, inst),
            .global_set => emit.emitGlobal(tag, inst),
            .i32_load => emit.emitMemArg(tag, inst),
            .i32_store => emit.emitMemArg(tag, inst),
            .memory_size => emit.emitNoop(tag),
            .memory_grow => emit.emitLabel(tag, inst),
            .i32_const => emit.emitImm32(inst),
            .i64_const => emit.emitImm64(inst),
            .f32_const => emit.emitFloat32(inst),
            .f64_const => emit.emitFloat64(inst),
        }
    }
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    std.debug.assert(emit.error_msg == null);
    // TODO: Determine the source location.
    emit.error_msg = try ErrorMsg.create(emit.bin_file.allocator, 0, format, args);
    return error.EmitFail;
}

fn emitNoop(emit: *Emit, tag: Mir.Inst.Tag) !void {
    try emit.code.append(@enumToInt(tag));
}

fn emitBlock(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const block_type = emit.mir.instructions.items(.data)[inst].block_type;
    try emit.code.append(@enumToInt(tag));
    try emit.code.append(block_type);
}

fn emitBrTable(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const extra = emit.mir.extraData(Mir.JumpTable, extra_index);
    const labels = emit.mir.extra[extra.end..][0..extra.data.length];
    const writer = emit.code.writer();

    try emit.code.append(std.wasm.opcode(.br_table));
    try leb128.writeULEB128(writer, extra.data.length);
    for (labels) |label| {
        try leb128.writeULEB128(writer, label);
    }
}

fn emitLabel(emit: *Emit, tag: Mir.Inst.Index, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].index;
    try emit.code.append(@enumToInt(tag));
    try leb128.writeULEB128(emit.code.writer(), label);
}

fn emitGlobal(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].index;
    try emit.code.append(@enumToInt(tag));
    try leb128.writeULEB128(emit.code.writer(), label);

    // TODO: Append label to the relocation list of this function
}

fn emitImm32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: i32 = emit.mir.instructions.items(.data)[inst].imm32;
    try emit.code.append(std.wasm.opcode(.i32_const));
    try leb128.writeILEB128(emit.code.writer(), value);
}

fn emitImm64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: i64 = emit.mir.instructions.items(.data)[inst].imm64;
    try emit.code.append(std.wasm.opcode(.i64_const));
    try leb128.writeILEB128(emit.code.writer(), value);
}

fn emitFloat32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: f32 = emit.mir.instructions.items(.data)[inst].imm32;
    try emit.code.append(std.wasm.opcode(.f32_const));
    try emit.code.writer.writeIntLittle(u32, @bitCast(u32, value));
}

fn emitFloat64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: f64 = emit.mir.instructions.items(.data)[inst].imm32;
    try emit.code.append(std.wasm.opcode(.f64_const));
    try emit.code.writer.writeIntLittle(u64, @bitCast(u64, value));
}

fn emitMemArg(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const mem_arg = emit.mir.instructions.items(.data)[inst].mem_arg;
    try emit.code.append(@enumToInt(tag));
    try leb128.writeULEB128(emit.code.writer(), mem_arg.alignment);
    try leb128.writeULEB128(emit.code.writer(), mem_arg.offset);
}
