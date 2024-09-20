//! Contains all logic to lower wasm MIR into its binary
//! or textual representation.

const Emit = @This();
const std = @import("std");
const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const codegen = @import("../../codegen.zig");
const leb128 = std.leb;

/// Contains our list of instructions
mir: Mir,
/// Reference to the Wasm module linker
bin_file: *link.File.Wasm,
/// Possible error message. When set, the value is allocated and
/// must be freed manually.
error_msg: ?*Zcu.ErrorMsg = null,
/// The binary representation that will be emit by this module.
code: *std.ArrayList(u8),
/// List of allocated locals.
locals: []const u8,
/// The declaration that code is being generated for.
owner_nav: InternPool.Nav.Index,

// Debug information
/// Holds the debug information for this emission
dbg_output: link.File.DebugInfoOutput,
/// Previous debug info line
prev_di_line: u32,
/// Previous debug info column
prev_di_column: u32,
/// Previous offset relative to code section
prev_di_offset: u32,

const InnerError = error{
    OutOfMemory,
    EmitFail,
};

pub fn emitMir(emit: *Emit) InnerError!void {
    const mir_tags = emit.mir.instructions.items(.tag);
    // write the locals in the prologue of the function body
    // before we emit the function body when lowering MIR
    try emit.emitLocals();

    for (mir_tags, 0..) |tag, index| {
        const inst = @as(u32, @intCast(index));
        switch (tag) {
            // block instructions
            .block => try emit.emitBlock(tag, inst),
            .loop => try emit.emitBlock(tag, inst),

            .dbg_line => try emit.emitDbgLine(inst),
            .dbg_epilogue_begin => try emit.emitDbgEpilogueBegin(),
            .dbg_prologue_end => try emit.emitDbgPrologueEnd(),

            // branch instructions
            .br_if => try emit.emitLabel(tag, inst),
            .br_table => try emit.emitBrTable(inst),
            .br => try emit.emitLabel(tag, inst),

            // relocatables
            .call => try emit.emitCall(inst),
            .call_indirect => try emit.emitCallIndirect(inst),
            .global_get => try emit.emitGlobal(tag, inst),
            .global_set => try emit.emitGlobal(tag, inst),
            .function_index => try emit.emitFunctionIndex(inst),
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
            .memory_size => try emit.emitLabel(tag, inst),

            // no-ops
            .end => try emit.emitTag(tag),
            .@"return" => try emit.emitTag(tag),
            .@"unreachable" => try emit.emitTag(tag),

            .select => try emit.emitTag(tag),

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
            .i64_or => try emit.emitTag(tag),
            .i64_xor => try emit.emitTag(tag),
            .i64_shl => try emit.emitTag(tag),
            .i64_shr_s => try emit.emitTag(tag),
            .i64_shr_u => try emit.emitTag(tag),
            .f32_abs => try emit.emitTag(tag),
            .f32_neg => try emit.emitTag(tag),
            .f32_ceil => try emit.emitTag(tag),
            .f32_floor => try emit.emitTag(tag),
            .f32_trunc => try emit.emitTag(tag),
            .f32_nearest => try emit.emitTag(tag),
            .f32_sqrt => try emit.emitTag(tag),
            .f32_add => try emit.emitTag(tag),
            .f32_sub => try emit.emitTag(tag),
            .f32_mul => try emit.emitTag(tag),
            .f32_div => try emit.emitTag(tag),
            .f32_min => try emit.emitTag(tag),
            .f32_max => try emit.emitTag(tag),
            .f32_copysign => try emit.emitTag(tag),
            .f64_abs => try emit.emitTag(tag),
            .f64_neg => try emit.emitTag(tag),
            .f64_ceil => try emit.emitTag(tag),
            .f64_floor => try emit.emitTag(tag),
            .f64_trunc => try emit.emitTag(tag),
            .f64_nearest => try emit.emitTag(tag),
            .f64_sqrt => try emit.emitTag(tag),
            .f64_add => try emit.emitTag(tag),
            .f64_sub => try emit.emitTag(tag),
            .f64_mul => try emit.emitTag(tag),
            .f64_div => try emit.emitTag(tag),
            .f64_min => try emit.emitTag(tag),
            .f64_max => try emit.emitTag(tag),
            .f64_copysign => try emit.emitTag(tag),
            .i32_wrap_i64 => try emit.emitTag(tag),
            .i64_extend_i32_s => try emit.emitTag(tag),
            .i64_extend_i32_u => try emit.emitTag(tag),
            .i32_extend8_s => try emit.emitTag(tag),
            .i32_extend16_s => try emit.emitTag(tag),
            .i64_extend8_s => try emit.emitTag(tag),
            .i64_extend16_s => try emit.emitTag(tag),
            .i64_extend32_s => try emit.emitTag(tag),
            .f32_demote_f64 => try emit.emitTag(tag),
            .f64_promote_f32 => try emit.emitTag(tag),
            .i32_reinterpret_f32 => try emit.emitTag(tag),
            .i64_reinterpret_f64 => try emit.emitTag(tag),
            .f32_reinterpret_i32 => try emit.emitTag(tag),
            .f64_reinterpret_i64 => try emit.emitTag(tag),
            .i32_trunc_f32_s => try emit.emitTag(tag),
            .i32_trunc_f32_u => try emit.emitTag(tag),
            .i32_trunc_f64_s => try emit.emitTag(tag),
            .i32_trunc_f64_u => try emit.emitTag(tag),
            .i64_trunc_f32_s => try emit.emitTag(tag),
            .i64_trunc_f32_u => try emit.emitTag(tag),
            .i64_trunc_f64_s => try emit.emitTag(tag),
            .i64_trunc_f64_u => try emit.emitTag(tag),
            .f32_convert_i32_s => try emit.emitTag(tag),
            .f32_convert_i32_u => try emit.emitTag(tag),
            .f32_convert_i64_s => try emit.emitTag(tag),
            .f32_convert_i64_u => try emit.emitTag(tag),
            .f64_convert_i32_s => try emit.emitTag(tag),
            .f64_convert_i32_u => try emit.emitTag(tag),
            .f64_convert_i64_s => try emit.emitTag(tag),
            .f64_convert_i64_u => try emit.emitTag(tag),
            .i32_rem_s => try emit.emitTag(tag),
            .i32_rem_u => try emit.emitTag(tag),
            .i64_rem_s => try emit.emitTag(tag),
            .i64_rem_u => try emit.emitTag(tag),
            .i32_popcnt => try emit.emitTag(tag),
            .i64_popcnt => try emit.emitTag(tag),
            .i32_clz => try emit.emitTag(tag),
            .i32_ctz => try emit.emitTag(tag),
            .i64_clz => try emit.emitTag(tag),
            .i64_ctz => try emit.emitTag(tag),

            .misc_prefix => try emit.emitExtended(inst),
            .simd_prefix => try emit.emitSimd(inst),
            .atomics_prefix => try emit.emitAtomic(inst),
        }
    }
}

fn offset(self: Emit) u32 {
    return @as(u32, @intCast(self.code.items.len));
}

fn fail(emit: *Emit, comptime format: []const u8, args: anytype) InnerError {
    @branchHint(.cold);
    std.debug.assert(emit.error_msg == null);
    const comp = emit.bin_file.base.comp;
    const zcu = comp.zcu.?;
    const gpa = comp.gpa;
    emit.error_msg = try Zcu.ErrorMsg.create(gpa, zcu.navSrcLoc(emit.owner_nav), format, args);
    return error.EmitFail;
}

fn emitLocals(emit: *Emit) !void {
    const writer = emit.code.writer();
    try leb128.writeUleb128(writer, @as(u32, @intCast(emit.locals.len)));
    // emit the actual locals amount
    for (emit.locals) |local| {
        try leb128.writeUleb128(writer, @as(u32, 1));
        try writer.writeByte(local);
    }
}

fn emitTag(emit: *Emit, tag: Mir.Inst.Tag) !void {
    try emit.code.append(@intFromEnum(tag));
}

fn emitBlock(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const block_type = emit.mir.instructions.items(.data)[inst].block_type;
    try emit.code.append(@intFromEnum(tag));
    try emit.code.append(block_type);
}

fn emitBrTable(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const extra = emit.mir.extraData(Mir.JumpTable, extra_index);
    const labels = emit.mir.extra[extra.end..][0..extra.data.length];
    const writer = emit.code.writer();

    try emit.code.append(std.wasm.opcode(.br_table));
    try leb128.writeUleb128(writer, extra.data.length - 1); // Default label is not part of length/depth
    for (labels) |label| {
        try leb128.writeUleb128(writer, label);
    }
}

fn emitLabel(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(@intFromEnum(tag));
    try leb128.writeUleb128(emit.code.writer(), label);
}

fn emitGlobal(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const comp = emit.bin_file.base.comp;
    const gpa = comp.gpa;
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(@intFromEnum(tag));
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, label);
    const global_offset = emit.offset();
    try emit.code.appendSlice(&buf);

    const atom_index = emit.bin_file.zigObjectPtr().?.navs.get(emit.owner_nav).?.atom;
    const atom = emit.bin_file.getAtomPtr(atom_index);
    try atom.relocs.append(gpa, .{
        .index = label,
        .offset = global_offset,
        .relocation_type = .R_WASM_GLOBAL_INDEX_LEB,
    });
}

fn emitImm32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: i32 = emit.mir.instructions.items(.data)[inst].imm32;
    try emit.code.append(std.wasm.opcode(.i32_const));
    try leb128.writeIleb128(emit.code.writer(), value);
}

fn emitImm64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const value = emit.mir.extraData(Mir.Imm64, extra_index);
    try emit.code.append(std.wasm.opcode(.i64_const));
    try leb128.writeIleb128(emit.code.writer(), @as(i64, @bitCast(value.data.toU64())));
}

fn emitFloat32(emit: *Emit, inst: Mir.Inst.Index) !void {
    const value: f32 = emit.mir.instructions.items(.data)[inst].float32;
    try emit.code.append(std.wasm.opcode(.f32_const));
    try emit.code.writer().writeInt(u32, @bitCast(value), .little);
}

fn emitFloat64(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const value = emit.mir.extraData(Mir.Float64, extra_index);
    try emit.code.append(std.wasm.opcode(.f64_const));
    try emit.code.writer().writeInt(u64, value.data.toU64(), .little);
}

fn emitMemArg(emit: *Emit, tag: Mir.Inst.Tag, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const mem_arg = emit.mir.extraData(Mir.MemArg, extra_index).data;
    try emit.code.append(@intFromEnum(tag));
    try encodeMemArg(mem_arg, emit.code.writer());
}

fn encodeMemArg(mem_arg: Mir.MemArg, writer: anytype) !void {
    // wasm encodes alignment as power of 2, rather than natural alignment
    const encoded_alignment = @ctz(mem_arg.alignment);
    try leb128.writeUleb128(writer, encoded_alignment);
    try leb128.writeUleb128(writer, mem_arg.offset);
}

fn emitCall(emit: *Emit, inst: Mir.Inst.Index) !void {
    const comp = emit.bin_file.base.comp;
    const gpa = comp.gpa;
    const label = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.call));
    const call_offset = emit.offset();
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, label);
    try emit.code.appendSlice(&buf);

    if (label != 0) {
        const atom_index = emit.bin_file.zigObjectPtr().?.navs.get(emit.owner_nav).?.atom;
        const atom = emit.bin_file.getAtomPtr(atom_index);
        try atom.relocs.append(gpa, .{
            .offset = call_offset,
            .index = label,
            .relocation_type = .R_WASM_FUNCTION_INDEX_LEB,
        });
    }
}

fn emitCallIndirect(emit: *Emit, inst: Mir.Inst.Index) !void {
    const type_index = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.call_indirect));
    // NOTE: If we remove unused function types in the future for incremental
    // linking, we must also emit a relocation for this `type_index`
    const call_offset = emit.offset();
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, type_index);
    try emit.code.appendSlice(&buf);
    if (type_index != 0) {
        const atom_index = emit.bin_file.zigObjectPtr().?.navs.get(emit.owner_nav).?.atom;
        const atom = emit.bin_file.getAtomPtr(atom_index);
        try atom.relocs.append(emit.bin_file.base.comp.gpa, .{
            .offset = call_offset,
            .index = type_index,
            .relocation_type = .R_WASM_TYPE_INDEX_LEB,
        });
    }
    try leb128.writeUleb128(emit.code.writer(), @as(u32, 0)); // TODO: Emit relocation for table index
}

fn emitFunctionIndex(emit: *Emit, inst: Mir.Inst.Index) !void {
    const comp = emit.bin_file.base.comp;
    const gpa = comp.gpa;
    const symbol_index = emit.mir.instructions.items(.data)[inst].label;
    try emit.code.append(std.wasm.opcode(.i32_const));
    const index_offset = emit.offset();
    var buf: [5]u8 = undefined;
    leb128.writeUnsignedFixed(5, &buf, symbol_index);
    try emit.code.appendSlice(&buf);

    if (symbol_index != 0) {
        const atom_index = emit.bin_file.zigObjectPtr().?.navs.get(emit.owner_nav).?.atom;
        const atom = emit.bin_file.getAtomPtr(atom_index);
        try atom.relocs.append(gpa, .{
            .offset = index_offset,
            .index = symbol_index,
            .relocation_type = .R_WASM_TABLE_INDEX_SLEB,
        });
    }
}

fn emitMemAddress(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const mem = emit.mir.extraData(Mir.Memory, extra_index).data;
    const mem_offset = emit.offset() + 1;
    const comp = emit.bin_file.base.comp;
    const gpa = comp.gpa;
    const target = comp.root_mod.resolved_target.result;
    const is_wasm32 = target.cpu.arch == .wasm32;
    if (is_wasm32) {
        try emit.code.append(std.wasm.opcode(.i32_const));
        var buf: [5]u8 = undefined;
        leb128.writeUnsignedFixed(5, &buf, mem.pointer);
        try emit.code.appendSlice(&buf);
    } else {
        try emit.code.append(std.wasm.opcode(.i64_const));
        var buf: [10]u8 = undefined;
        leb128.writeUnsignedFixed(10, &buf, mem.pointer);
        try emit.code.appendSlice(&buf);
    }

    if (mem.pointer != 0) {
        const atom_index = emit.bin_file.zigObjectPtr().?.navs.get(emit.owner_nav).?.atom;
        const atom = emit.bin_file.getAtomPtr(atom_index);
        try atom.relocs.append(gpa, .{
            .offset = mem_offset,
            .index = mem.pointer,
            .relocation_type = if (is_wasm32) .R_WASM_MEMORY_ADDR_LEB else .R_WASM_MEMORY_ADDR_LEB64,
            .addend = @as(i32, @intCast(mem.offset)),
        });
    }
}

fn emitExtended(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const opcode = emit.mir.extra[extra_index];
    const writer = emit.code.writer();
    try emit.code.append(std.wasm.opcode(.misc_prefix));
    try leb128.writeUleb128(writer, opcode);
    switch (@as(std.wasm.MiscOpcode, @enumFromInt(opcode))) {
        // bulk-memory opcodes
        .data_drop => {
            const segment = emit.mir.extra[extra_index + 1];
            try leb128.writeUleb128(writer, segment);
        },
        .memory_init => {
            const segment = emit.mir.extra[extra_index + 1];
            try leb128.writeUleb128(writer, segment);
            try leb128.writeUleb128(writer, @as(u32, 0)); // memory index
        },
        .memory_fill => {
            try leb128.writeUleb128(writer, @as(u32, 0)); // memory index
        },
        .memory_copy => {
            try leb128.writeUleb128(writer, @as(u32, 0)); // dst memory index
            try leb128.writeUleb128(writer, @as(u32, 0)); // src memory index
        },

        // nontrapping-float-to-int-conversion opcodes
        .i32_trunc_sat_f32_s,
        .i32_trunc_sat_f32_u,
        .i32_trunc_sat_f64_s,
        .i32_trunc_sat_f64_u,
        .i64_trunc_sat_f32_s,
        .i64_trunc_sat_f32_u,
        .i64_trunc_sat_f64_s,
        .i64_trunc_sat_f64_u,
        => {}, // opcode already written
        else => |tag| return emit.fail("TODO: Implement extension instruction: {s}\n", .{@tagName(tag)}),
    }
}

fn emitSimd(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const opcode = emit.mir.extra[extra_index];
    const writer = emit.code.writer();
    try emit.code.append(std.wasm.opcode(.simd_prefix));
    try leb128.writeUleb128(writer, opcode);
    switch (@as(std.wasm.SimdOpcode, @enumFromInt(opcode))) {
        .v128_store,
        .v128_load,
        .v128_load8_splat,
        .v128_load16_splat,
        .v128_load32_splat,
        .v128_load64_splat,
        => {
            const mem_arg = emit.mir.extraData(Mir.MemArg, extra_index + 1).data;
            try encodeMemArg(mem_arg, writer);
        },
        .v128_const,
        .i8x16_shuffle,
        => {
            const simd_value = emit.mir.extra[extra_index + 1 ..][0..4];
            try writer.writeAll(std.mem.asBytes(simd_value));
        },
        .i8x16_extract_lane_s,
        .i8x16_extract_lane_u,
        .i8x16_replace_lane,
        .i16x8_extract_lane_s,
        .i16x8_extract_lane_u,
        .i16x8_replace_lane,
        .i32x4_extract_lane,
        .i32x4_replace_lane,
        .i64x2_extract_lane,
        .i64x2_replace_lane,
        .f32x4_extract_lane,
        .f32x4_replace_lane,
        .f64x2_extract_lane,
        .f64x2_replace_lane,
        => {
            try writer.writeByte(@as(u8, @intCast(emit.mir.extra[extra_index + 1])));
        },
        .i8x16_splat,
        .i16x8_splat,
        .i32x4_splat,
        .i64x2_splat,
        .f32x4_splat,
        .f64x2_splat,
        => {}, // opcode already written
        else => |tag| return emit.fail("TODO: Implement simd instruction: {s}", .{@tagName(tag)}),
    }
}

fn emitAtomic(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const opcode = emit.mir.extra[extra_index];
    const writer = emit.code.writer();
    try emit.code.append(std.wasm.opcode(.atomics_prefix));
    try leb128.writeUleb128(writer, opcode);
    switch (@as(std.wasm.AtomicsOpcode, @enumFromInt(opcode))) {
        .i32_atomic_load,
        .i64_atomic_load,
        .i32_atomic_load8_u,
        .i32_atomic_load16_u,
        .i64_atomic_load8_u,
        .i64_atomic_load16_u,
        .i64_atomic_load32_u,
        .i32_atomic_store,
        .i64_atomic_store,
        .i32_atomic_store8,
        .i32_atomic_store16,
        .i64_atomic_store8,
        .i64_atomic_store16,
        .i64_atomic_store32,
        .i32_atomic_rmw_add,
        .i64_atomic_rmw_add,
        .i32_atomic_rmw8_add_u,
        .i32_atomic_rmw16_add_u,
        .i64_atomic_rmw8_add_u,
        .i64_atomic_rmw16_add_u,
        .i64_atomic_rmw32_add_u,
        .i32_atomic_rmw_sub,
        .i64_atomic_rmw_sub,
        .i32_atomic_rmw8_sub_u,
        .i32_atomic_rmw16_sub_u,
        .i64_atomic_rmw8_sub_u,
        .i64_atomic_rmw16_sub_u,
        .i64_atomic_rmw32_sub_u,
        .i32_atomic_rmw_and,
        .i64_atomic_rmw_and,
        .i32_atomic_rmw8_and_u,
        .i32_atomic_rmw16_and_u,
        .i64_atomic_rmw8_and_u,
        .i64_atomic_rmw16_and_u,
        .i64_atomic_rmw32_and_u,
        .i32_atomic_rmw_or,
        .i64_atomic_rmw_or,
        .i32_atomic_rmw8_or_u,
        .i32_atomic_rmw16_or_u,
        .i64_atomic_rmw8_or_u,
        .i64_atomic_rmw16_or_u,
        .i64_atomic_rmw32_or_u,
        .i32_atomic_rmw_xor,
        .i64_atomic_rmw_xor,
        .i32_atomic_rmw8_xor_u,
        .i32_atomic_rmw16_xor_u,
        .i64_atomic_rmw8_xor_u,
        .i64_atomic_rmw16_xor_u,
        .i64_atomic_rmw32_xor_u,
        .i32_atomic_rmw_xchg,
        .i64_atomic_rmw_xchg,
        .i32_atomic_rmw8_xchg_u,
        .i32_atomic_rmw16_xchg_u,
        .i64_atomic_rmw8_xchg_u,
        .i64_atomic_rmw16_xchg_u,
        .i64_atomic_rmw32_xchg_u,

        .i32_atomic_rmw_cmpxchg,
        .i64_atomic_rmw_cmpxchg,
        .i32_atomic_rmw8_cmpxchg_u,
        .i32_atomic_rmw16_cmpxchg_u,
        .i64_atomic_rmw8_cmpxchg_u,
        .i64_atomic_rmw16_cmpxchg_u,
        .i64_atomic_rmw32_cmpxchg_u,
        => {
            const mem_arg = emit.mir.extraData(Mir.MemArg, extra_index + 1).data;
            try encodeMemArg(mem_arg, writer);
        },
        .atomic_fence => {
            // TODO: When multi-memory proposal is accepted and implemented in the compiler,
            // change this to (user-)specified index, rather than hardcode it to memory index 0.
            const memory_index: u32 = 0;
            try leb128.writeUleb128(writer, memory_index);
        },
        else => |tag| return emit.fail("TODO: Implement atomic instruction: {s}", .{@tagName(tag)}),
    }
}

fn emitMemFill(emit: *Emit) !void {
    try emit.code.append(0xFC);
    try emit.code.append(0x0B);
    // When multi-memory proposal reaches phase 4, we
    // can emit a different memory index here.
    // For now we will always emit index 0.
    try leb128.writeUleb128(emit.code.writer(), @as(u32, 0));
}

fn emitDbgLine(emit: *Emit, inst: Mir.Inst.Index) !void {
    const extra_index = emit.mir.instructions.items(.data)[inst].payload;
    const dbg_line = emit.mir.extraData(Mir.DbgLineColumn, extra_index).data;
    try emit.dbgAdvancePCAndLine(dbg_line.line, dbg_line.column);
}

fn dbgAdvancePCAndLine(emit: *Emit, line: u32, column: u32) !void {
    if (emit.dbg_output != .dwarf) return;

    const delta_line = @as(i32, @intCast(line)) - @as(i32, @intCast(emit.prev_di_line));
    const delta_pc = emit.offset() - emit.prev_di_offset;
    // TODO: This must emit a relocation to calculate the offset relative
    // to the code section start.
    try emit.dbg_output.dwarf.advancePCAndLine(delta_line, delta_pc);

    emit.prev_di_line = line;
    emit.prev_di_column = column;
    emit.prev_di_offset = emit.offset();
}

fn emitDbgPrologueEnd(emit: *Emit) !void {
    if (emit.dbg_output != .dwarf) return;

    try emit.dbg_output.dwarf.setPrologueEnd();
    try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
}

fn emitDbgEpilogueBegin(emit: *Emit) !void {
    if (emit.dbg_output != .dwarf) return;

    try emit.dbg_output.dwarf.setEpilogueBegin();
    try emit.dbgAdvancePCAndLine(emit.prev_di_line, emit.prev_di_column);
}
