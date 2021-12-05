//! Contains all logic to lower wasm MIR into its binary
//! or textual representation.

const Emit = @This();
const std = @import("std");
const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const leb128 = std.leb;

/// Contains our list of instructions
mir: Mir,
/// Reference to the file handler
bin_file: *link.File,
/// Possible error message. When set, the value is allocated and
/// must be freed manually.
error_msg: ?*Module.ErrorMsg = null,
/// The binary representation that will be emit by this module.
code: *std.ArrayList(u8),
/// List of allocated locals.
locals: []const u8,
/// The declaration that code is being generated for.
decl: *Module.Decl,

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);
    // write the locals in the prologue of the function body
    // before we emit the function body when lowering MIR
    try emit.emitLocals();

    for (mir_tags) |tag, index| {
        const inst = @intCast(u32, index);
        switch (tag) {
            // block instructions
            .block => try emit.emitBlock(tag, inst),
            .loop => try emit.emitBlock(tag, inst),

            // branch instructions
            .br_if => try emit.emitLabel(tag, inst),
            .br_table => try emit.emitBrTable(inst),
            .br => try emit.emitLabel(tag, inst),

            // relocatables
            .call => try emit.emitCall(inst),
            .call_indirect => try emit.emitCallIndirect(inst),
            .global_get => try emit.emitGlobal(tag, inst),
            .global_set => try emit.emitGlobal(tag, inst),
            .memory_address => try emit.emitMemAddress(inst),

            // immediates
            .f32_const => try emit.emitFloat32(inst),
            .f64_const => try emit.emitFloat64(inst),
            .i32_const => try emit.emitImm32(inst),
            .i64_const => try emit.emitImm64(inst),

            // memory instructions
            .i32_load => try emit.emitMemArg(tag, inst),
            .i64_load => try emit.emitMemArg(tag, inst),
            .f32_load => try emit.emitMemArg(tag, inst),
            .f64_load => try emit.emitMemArg(tag, inst),
            .i32_load8_s => try emit.emitMemArg(tag, inst),
            .i32_load8_u => try emit.emitMemArg(tag, inst),
            .i32_load16_s => try emit.emitMemArg(tag, inst),
            .i32_load16_u => try emit.emitMemArg(tag, inst),
            .i64_load8_s => try emit.emitMemArg(tag, inst),
            .i64_load8_u => try emit.emitMemArg(tag, inst),
            .i64_load16_s => try emit.emitMemArg(tag, inst),
            .i64_load16_u => try emit.emitMemArg(tag, inst),
            .i64_load32_s => try emit.emitMemArg(tag, inst),
            .i64_load32_u => try emit.emitMemArg(tag, inst),
            .i32_store => try emit.emitMemArg(tag, inst),
            .i64_store => try emit.emitMemArg(tag, inst),
            .f32_store => try emit.emitMemArg(tag, inst),
            .f64_store => try emit.emitMemArg(tag, inst),
            .i32_store8 => try emit.emitMemArg(tag, inst),
            .i32_store16 => try emit.emitMemArg(tag, inst),
            .i64_store8 => try emit.emitMemArg(tag, inst),
            .i64_store16 => try emit.emitMemArg(tag, inst),
            .i64_store32 => try emit.emitMemArg(tag, inst),

            // Instructions with an index that do not require relocations
            .local_get => try emit.emitLabel(tag, inst),
            .local_set => try emit.emitLabel(tag, inst),
            .local_tee => try emit.emitLabel(tag, inst),
            .memory_grow => try emit.emitLabel(tag, inst),

            // no-ops
            .end => try emit.emitTag(tag),
            .memory_size => try emit.emitTag(tag),
            .@"return" => try emit.emitTag(tag),
            .@"unreachable" => try emit.emitTag(tag),

            // arithmetic
            .i32_eqz => try emit.emitTag(tag),
            .i32_eq => try emit.emitTag(tag),
            .i32_ne => try emit.emitTag(tag),
            .i32_lt_s => try emit.emitTag(tag),
            .i32_lt_u => try emit.emitTag(tag),
            .i32_gt_s => try emit.emitTag(tag),
            .i32_gt_u => try emit.emitTag(tag),
            .i32_le_s => try emit.emitTag(tag),
            .i32_le_u => try emit.emitTag(tag),
            .i32_ge_s => try emit.emitTag(tag),
            .i32_ge_u => try emit.emitTag(tag),
            .i64_eqz => try emit.emitTag(tag),
            .i64_eq => try emit.emitTag(tag),
            .i64_ne => try emit.emitTag(tag),
            .i64_lt_s => try emit.emitTag(tag),
            .i64_lt_u => try emit.emitTag(tag),
            .i64_gt_s => try emit.emitTag(tag),
            .i64_gt_u => try emit.emitTag(tag),
            .i64_le_s => try emit.emitTag(tag),
            .i64_le_u => try emit.emitTag(tag),
            .i64_ge_s => try emit.emitTag(tag),
            .i64_ge_u => try emit.emitTag(tag),
            .f32_eq => try emit.emitTag(tag),
            .f32_ne => try emit.emitTag(tag),
            .f32_lt => try emit.emitTag(tag),
            .f32_gt => try emit.emitTag(tag),
            .f32_le => try emit.emitTag(tag),
            .f32_ge => try emit.emitTag(tag),
            .f64_eq => try emit.emitTag(tag),
            .f64_ne => try emit.emitTag(tag),
            .f64_lt => try emit.emitTag(tag),
            .f64_gt => try emit.emitTag(tag),
            .f64_le => try emit.emitTag(tag),
            .f64_ge => try emit.emitTag(tag),
            .i32_add => try emit.emitTag(tag),
            .i32_sub => try emit.emitTag(tag),
            .i32_mul => try emit.emitTag(tag),
            .i32_div_s => try emit.emitTag(tag),
            .i32_div_u => try emit.emitTag(tag),
            .i32_and => try emit.emitTag(tag),
            .i32_or => try emit.emitTag(tag),
            .i32_xor => try emit.emitTag(tag),
            .i32_shl => try emit.emitTag(tag),
            .i32_shr_s => try emit.emitTag(tag),
            .i32_shr_u => try emit.emitTag(tag),
            .i64_add => try emit.emitTag(tag),
            .i64_sub => try emit.emitTag(tag),
            .i64_mul => try emit.emitTag(tag),
            .i64_div_s => try emit.emitTag(tag),
            .i64_div_u => try emit.emitTag(tag),
            .i64_and => try emit.emitTag(tag),
            .i32_wrap_i64 => try emit.emitTag(tag),
            .i64_extend_i32_s => try emit.emitTag(tag),
            .i64_extend_i32_u => try emit.emitTag(tag),
            .i32_extend8_s => try emit.emitTag(tag),
            .i32_extend16_s => try emit.emitTag(tag),
            .i64_extend8_s => try emit.emitTag(tag),
            .i64_extend16_s => try emit.emitTag(tag),
            .i64_extend32_s => try emit.emitTag(tag),
        }
    }
}

fn offset(self: Emit) u32 {
    return @intCast(u32, self.code.items.len);
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    std.debug.assert(emit.error_msg == null);
    // TODO: Determine the source location.
    emit.error_msg = try Module.ErrorMsg.create(emit.bin_file.allocator, emit.decl.srcLoc(), format, args);
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

fn emitTag(emit: *Emit, tag: Mir.Inst.Tag) !void {
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
    try leb128.writeULEB128(writer, extra.data.length - 1); // Default label is not part of length/depth
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
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, label);
    const global_offset = emit.offset();
    try emit.code.appendSlice(&buf);

    try emit.decl.link.wasm.relocs.append(emit.bin_file.allocator, .{
        .index = label,
        .offset = global_offset,
        .relocation_type = .R_WASM_GLOBAL_INDEX_LEB,
    });
}

fn emitImm32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: i32 = emit.mir.instructions.items(.data)[inst].imm32;
    try emit.code.append(std.wasm.opcode(.i32_const));
    try leb128.writeILEB128(emit.code.writer(), value);
}

fn emitImm64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const value = emit.mir.extraData(Mir.Imm64, extra_index);
    try emit.code.append(std.wasm.opcode(.i64_const));
    try leb128.writeULEB128(emit.code.writer(), value.data.toU64());
}

fn emitFloat32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: f32 = emit.mir.instructions.items(.data)[inst].float32;
    try emit.code.append(std.wasm.opcode(.f32_const));
    try emit.code.writer().writeIntLittle(u32, @bitCast(u32, value));
}

fn emitFloat64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const value = emit.mir.extraData(Mir.Float64, extra_index);
    try emit.code.append(std.wasm.opcode(.f64_const));
    try emit.code.writer().writeIntLittle(u64, value.data.toU64());
}

fn emitMemArg(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const mem_arg = emit.mir.extraData(Mir.MemArg, extra_index).data;
    try emit.code.append(@enumToInt(tag));

    // wasm encodes alignment as power of 2, rather than natural alignment
    const encoded_alignment = @ctz(u32, mem_arg.alignment);
    try leb128.writeULEB128(emit.code.writer(), encoded_alignment);
    try leb128.writeULEB128(emit.code.writer(), mem_arg.offset);
}

fn emitCall(emit: *Emit, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.call));
    const call_offset = emit.offset();
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, label);
    try emit.code.appendSlice(&buf);

    try emit.decl.link.wasm.relocs.append(emit.bin_file.allocator, .{
        .offset = call_offset,
        .index = label,
        .relocation_type = .R_WASM_FUNCTION_INDEX_LEB,
    });
}

fn emitCallIndirect(emit: *Emit, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.call_indirect));
    try leb128.writeULEB128(emit.code.writer(), @as(u32, 0)); // TODO: Emit relocation for table index
    try leb128.writeULEB128(emit.code.writer(), label);
}

fn emitMemAddress(emit: *Emit, inst: Mir.Inst.Index) !void {
    const symbol_index = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.i32_const));
    const mem_offset = emit.offset();
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, symbol_index);
    try emit.code.appendSlice(&buf);

    try emit.decl.link.wasm.relocs.append(emit.bin_file.allocator, .{
        .offset = mem_offset,
        .index = symbol_index,
        .relocation_type = .R_WASM_MEMORY_ADDR_LEB,
    });
}
