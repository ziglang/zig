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
/// List of allocated locals.
locals: []const u8,

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);
    // Reserve space to write the size after generating the code.
    try emit.code.resize(5);
    // write the locals in the prologue of the function body
    // before we emit the function body when lowering MIR
    try emit.emitLocals();

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            .@"unreachable" => try emit.emitNoop(tag),
            .block => try emit.emitBlock(tag, inst),
            .loop => try emit.emitBlock(tag, inst),
            .end => try emit.emitNoop(tag),
            .br => try emit.emitLabel(tag, inst),
            .br_if => try emit.emitLabel(tag, inst),
            .br_table => try emit.emitBrTable(inst),
            .@"return" => try emit.emitNoop(tag),
            .local_get => try emit.emitLabel(tag, inst),
            .local_set => try emit.emitLabel(tag, inst),
            .local_tee => try emit.emitLabel(tag, inst),
            .global_get => try emit.emitGlobal(tag, inst),
            .global_set => try emit.emitGlobal(tag, inst),
            .i32_load => try emit.emitMemArg(tag, inst),
            .i32_store => try emit.emitMemArg(tag, inst),
            .memory_size => try emit.emitNoop(tag),
            .memory_grow => try emit.emitLabel(tag, inst),
            .i32_const => try emit.emitImm32(inst),
            .i64_const => try emit.emitImm64(inst),
            .f32_const => try emit.emitFloat32(inst),
            .f64_const => try emit.emitFloat64(inst),
        }
    }

    // Fill in the size of the generated code to the reserved space at the
    // beginning of the buffer.
    const size = emit.code.items.len - 5;
    leb128.writeUnsignedFixed(5, emit.code.items[0..5], @intCast(u32, size));
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    std.debug.assert(emit.error_msg == null);
    // TODO: Determine the source location.
    emit.error_msg = try ErrorMsg.create(emit.bin_file.allocator, 0, format, args);
    return error.EmitFail;
}

fn emitLocals(emit: *Emit) !void {
    const writer = emit.code.writer();
    try leb128.writeULEB128(writer, @intCast(u32, emit.locals.len));
    // emit the actual locals amount
    for (emit.locals) |local| {
        try leb128.writeULEB128(writer, @as(u32, 1));
        try writer.writeByte(local);
    }
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

fn emitLabel(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(@enumToInt(tag));
    try leb128.writeULEB128(emit.code.writer(), label);
}

fn emitGlobal(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].label;
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
    const value: f32 = emit.mir.instructions.items(.data)[inst].float32;
    try emit.code.append(std.wasm.opcode(.f32_const));
    try emit.code.writer().writeIntLittle(u32, @bitCast(u32, value));
}

fn emitFloat64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: f64 = emit.mir.instructions.items(.data)[inst].float64;
    try emit.code.append(std.wasm.opcode(.f64_const));
    try emit.code.writer().writeIntLittle(u64, @bitCast(u64, value));
}

fn emitMemArg(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const mem_arg = emit.mir.instructions.items(.data)[inst].mem_arg;
    try emit.code.append(@enumToInt(tag));
    try leb128.writeULEB128(emit.code.writer(), mem_arg.alignment);
    try leb128.writeULEB128(emit.code.writer(), mem_arg.offset);
}
