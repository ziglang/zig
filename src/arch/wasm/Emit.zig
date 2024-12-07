const Emit = @This();

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const leb = std.leb;

const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const codegen = @import("../../codegen.zig");

mir: Mir,
wasm: *link.File.Wasm,
/// The binary representation that will be emitted by this module.
code: *std.ArrayListUnmanaged(u8),

pub const Error = error{
    OutOfMemory,
};

pub fn lowerToCode(emit: *Emit) Error!void {
    const mir = &emit.mir;
    const code = emit.code;
    const wasm = emit.wasm;
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const is_obj = comp.config.output_mode == .Obj;
    const target = &comp.root_mod.resolved_target.result;
    const is_wasm32 = target.cpu.arch == .wasm32;

    const tags = mir.instructions.items(.tag);
    const datas = mir.instructions.items(.data);
    var inst: u32 = 0;

    loop: switch (tags[inst]) {
        .dbg_epilogue_begin => {
            return;
        },
        .block, .loop => {
            const block_type = datas[inst].block_type;
            try code.ensureUnusedCapacity(gpa, 2);
            code.appendAssumeCapacity(@intFromEnum(tags[inst]));
            code.appendAssumeCapacity(block_type);

            inst += 1;
            continue :loop tags[inst];
        },
        .uav_ref => {
            try uavRefOff(wasm, code, .{ .ip_index = datas[inst].ip_index, .offset = 0 });
            inst += 1;
            continue :loop tags[inst];
        },
        .uav_ref_off => {
            try uavRefOff(wasm, code, mir.extraData(Mir.UavRefOff, datas[inst].payload).data);
            inst += 1;
            continue :loop tags[inst];
        },
        .nav_ref => {
            try navRefOff(wasm, code, .{ .ip_index = datas[inst].ip_index, .offset = 0 }, is_wasm32);
            inst += 1;
            continue :loop tags[inst];
        },
        .nav_ref_off => {
            try navRefOff(wasm, code, mir.extraData(Mir.NavRefOff, datas[inst].payload).data, is_wasm32);
            inst += 1;
            continue :loop tags[inst];
        },

        .dbg_line => {
            inst += 1;
            continue :loop tags[inst];
        },
        .errors_len => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
            // MIR is lowered during flush, so there is indeed only one thread at this time.
            const errors_len = 1 + comp.zcu.?.intern_pool.global_error_set.getNamesFromMainThread().len;
            leb.writeIleb128(code.fixedWriter(), errors_len) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },
        .error_name_table_ref => {
            try code.ensureUnusedCapacity(gpa, 11);
            const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;
            code.appendAssumeCapacity(@intFromEnum(opcode));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .index = try wasm.errorNameTableSymbolIndex(),
                    .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);

                inst += 1;
                continue :loop tags[inst];
            } else {
                const addr = try wasm.errorNameTableAddr();
                leb.writeIleb128(code.fixedWriter(), addr) catch unreachable;

                inst += 1;
                continue :loop tags[inst];
            }
        },
        .br_if, .br, .memory_grow, .memory_size => {
            try code.ensureUnusedCapacity(gpa, 11);
            code.appendAssumeCapacity(@intFromEnum(tags[inst]));
            leb.writeUleb128(code.fixedWriter(), datas[inst].label) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },

        .local_get, .local_set, .local_tee => {
            try code.ensureUnusedCapacity(gpa, 11);
            code.appendAssumeCapacity(@intFromEnum(tags[inst]));
            leb.writeUleb128(code.fixedWriter(), datas[inst].local) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },

        .br_table => {
            const extra_index = mir.instructions.items(.data)[inst].payload;
            const extra = mir.extraData(Mir.JumpTable, extra_index);
            const labels = mir.extra[extra.end..][0..extra.data.length];
            try code.ensureUnusedCapacity(gpa, 11 + 10 * labels.len);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.br_table));
            // -1 because default label is not part of length/depth.
            leb.writeUleb128(code.fixedWriter(), extra.data.length - 1) catch unreachable;
            for (labels) |label| leb.writeUleb128(code.fixedWriter(), label) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },

        .call_nav => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .index = try wasm.navSymbolIndex(datas[inst].nav_index),
                    .tag = .FUNCTION_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const func_index = try wasm.navFunctionIndex(datas[inst].nav_index);
                leb.writeUleb128(code.fixedWriter(), @intFromEnum(func_index)) catch unreachable;
            }

            inst += 1;
            continue :loop tags[inst];
        },

        .call_indirect => {
            try code.ensureUnusedCapacity(gpa, 11);
            const func_ty_index = datas[inst].func_ty;
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call_indirect));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .index = func_ty_index,
                    .tag = .TYPE_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                leb.writeUleb128(code.fixedWriter(), @intFromEnum(func_ty_index)) catch unreachable;
            }
            leb.writeUleb128(code.fixedWriter(), @as(u32, 0)) catch unreachable; // table index

            inst += 1;
            continue :loop tags[inst];
        },

        .global_set => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.global_set));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .index = try wasm.stackPointerSymbolIndex(),
                    .tag = .GLOBAL_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const sp_global = try wasm.stackPointerGlobalIndex();
                std.leb.writeULEB128(code.fixedWriter(), @intFromEnum(sp_global)) catch unreachable;
            }

            inst += 1;
            continue :loop tags[inst];
        },

        .function_index => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .index = try wasm.functionSymbolIndex(datas[inst].ip_index),
                    .tag = .TABLE_INDEX_SLEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const func_index = try wasm.functionIndex(datas[inst].ip_index);
                std.leb.writeULEB128(code.fixedWriter(), @intFromEnum(func_index)) catch unreachable;
            }

            inst += 1;
            continue :loop tags[inst];
        },

        .f32_const => {
            try code.ensureUnusedCapacity(gpa, 5);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.f32_const));
            std.mem.writeInt(u32, code.addManyAsArrayAssumeCapacity(4), @bitCast(datas[inst].float32), .little);

            inst += 1;
            continue :loop tags[inst];
        },

        .f64_const => {
            try code.ensureUnusedCapacity(gpa, 9);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.f64_const));
            const float64 = mir.extraData(Mir.Float64, datas[inst].payload).data;
            std.mem.writeInt(u64, code.addManyAsArrayAssumeCapacity(8), float64.toInt(), .little);

            inst += 1;
            continue :loop tags[inst];
        },
        .i32_const => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
            leb.writeIleb128(code.fixedWriter(), datas[inst].imm32) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },
        .i64_const => {
            try code.ensureUnusedCapacity(gpa, 11);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i64_const));
            const int64: i64 = @bitCast(mir.extraData(Mir.Imm64, datas[inst].payload).data.toInt());
            leb.writeIleb128(code.writer(), int64) catch unreachable;

            inst += 1;
            continue :loop tags[inst];
        },

        .i32_load,
        .i64_load,
        .f32_load,
        .f64_load,
        .i32_load8_s,
        .i32_load8_u,
        .i32_load16_s,
        .i32_load16_u,
        .i64_load8_s,
        .i64_load8_u,
        .i64_load16_s,
        .i64_load16_u,
        .i64_load32_s,
        .i64_load32_u,
        .i32_store,
        .i64_store,
        .f32_store,
        .f64_store,
        .i32_store8,
        .i32_store16,
        .i64_store8,
        .i64_store16,
        .i64_store32,
        => {
            try code.ensureUnusedCapacity(gpa, 1 + 20);
            code.appendAssumeCapacity(@intFromEnum(tags[inst]));
            encodeMemArg(code, mir.extraData(Mir.MemArg, datas[inst]).data);
            inst += 1;
            continue :loop tags[inst];
        },

        .end,
        .@"return",
        .@"unreachable",
        .select,
        .i32_eqz,
        .i32_eq,
        .i32_ne,
        .i32_lt_s,
        .i32_lt_u,
        .i32_gt_s,
        .i32_gt_u,
        .i32_le_s,
        .i32_le_u,
        .i32_ge_s,
        .i32_ge_u,
        .i64_eqz,
        .i64_eq,
        .i64_ne,
        .i64_lt_s,
        .i64_lt_u,
        .i64_gt_s,
        .i64_gt_u,
        .i64_le_s,
        .i64_le_u,
        .i64_ge_s,
        .i64_ge_u,
        .f32_eq,
        .f32_ne,
        .f32_lt,
        .f32_gt,
        .f32_le,
        .f32_ge,
        .f64_eq,
        .f64_ne,
        .f64_lt,
        .f64_gt,
        .f64_le,
        .f64_ge,
        .i32_add,
        .i32_sub,
        .i32_mul,
        .i32_div_s,
        .i32_div_u,
        .i32_and,
        .i32_or,
        .i32_xor,
        .i32_shl,
        .i32_shr_s,
        .i32_shr_u,
        .i64_add,
        .i64_sub,
        .i64_mul,
        .i64_div_s,
        .i64_div_u,
        .i64_and,
        .i64_or,
        .i64_xor,
        .i64_shl,
        .i64_shr_s,
        .i64_shr_u,
        .f32_abs,
        .f32_neg,
        .f32_ceil,
        .f32_floor,
        .f32_trunc,
        .f32_nearest,
        .f32_sqrt,
        .f32_add,
        .f32_sub,
        .f32_mul,
        .f32_div,
        .f32_min,
        .f32_max,
        .f32_copysign,
        .f64_abs,
        .f64_neg,
        .f64_ceil,
        .f64_floor,
        .f64_trunc,
        .f64_nearest,
        .f64_sqrt,
        .f64_add,
        .f64_sub,
        .f64_mul,
        .f64_div,
        .f64_min,
        .f64_max,
        .f64_copysign,
        .i32_wrap_i64,
        .i64_extend_i32_s,
        .i64_extend_i32_u,
        .i32_extend8_s,
        .i32_extend16_s,
        .i64_extend8_s,
        .i64_extend16_s,
        .i64_extend32_s,
        .f32_demote_f64,
        .f64_promote_f32,
        .i32_reinterpret_f32,
        .i64_reinterpret_f64,
        .f32_reinterpret_i32,
        .f64_reinterpret_i64,
        .i32_trunc_f32_s,
        .i32_trunc_f32_u,
        .i32_trunc_f64_s,
        .i32_trunc_f64_u,
        .i64_trunc_f32_s,
        .i64_trunc_f32_u,
        .i64_trunc_f64_s,
        .i64_trunc_f64_u,
        .f32_convert_i32_s,
        .f32_convert_i32_u,
        .f32_convert_i64_s,
        .f32_convert_i64_u,
        .f64_convert_i32_s,
        .f64_convert_i32_u,
        .f64_convert_i64_s,
        .f64_convert_i64_u,
        .i32_rem_s,
        .i32_rem_u,
        .i64_rem_s,
        .i64_rem_u,
        .i32_popcnt,
        .i64_popcnt,
        .i32_clz,
        .i32_ctz,
        .i64_clz,
        .i64_ctz,
        => {
            try code.append(gpa, @intFromEnum(tags[inst]));
            inst += 1;
            continue :loop tags[inst];
        },

        .misc_prefix => {
            try code.ensureUnusedCapacity(gpa, 6 + 6);
            const extra_index = datas[inst].payload;
            const opcode = mir.extra[extra_index];
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.misc_prefix));
            leb.writeUleb128(code.fixedWriter(), opcode) catch unreachable;
            switch (@as(std.wasm.MiscOpcode, @enumFromInt(opcode))) {
                // bulk-memory opcodes
                .data_drop => {
                    const segment = mir.extra[extra_index + 1];
                    leb.writeUleb128(code.fixedWriter(), segment) catch unreachable;

                    inst += 1;
                    continue :loop tags[inst];
                },
                .memory_init => {
                    const segment = mir.extra[extra_index + 1];
                    leb.writeUleb128(code.fixedWriter(), segment) catch unreachable;
                    leb.writeUleb128(code.fixedWriter(), @as(u32, 0)) catch unreachable; // memory index

                    inst += 1;
                    continue :loop tags[inst];
                },
                .memory_fill => {
                    leb.writeUleb128(code.fixedWriter(), @as(u32, 0)) catch unreachable; // memory index

                    inst += 1;
                    continue :loop tags[inst];
                },
                .memory_copy => {
                    leb.writeUleb128(code.fixedWriter(), @as(u32, 0)) catch unreachable; // dst memory index
                    leb.writeUleb128(code.fixedWriter(), @as(u32, 0)) catch unreachable; // src memory index

                    inst += 1;
                    continue :loop tags[inst];
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
                => {
                    inst += 1;
                    continue :loop tags[inst];
                },

                _ => unreachable,
            }
            comptime unreachable;
        },
        .simd_prefix => {
            try code.ensureUnusedCapacity(gpa, 6 + 20);
            const extra_index = mir.instructions.items(.data)[inst].payload;
            const opcode = mir.extra[extra_index];
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.simd_prefix));
            leb.writeUleb128(code.fixedWriter(), opcode) catch unreachable;
            switch (@as(std.wasm.SimdOpcode, @enumFromInt(opcode))) {
                .v128_store,
                .v128_load,
                .v128_load8_splat,
                .v128_load16_splat,
                .v128_load32_splat,
                .v128_load64_splat,
                => {
                    encodeMemArg(code, mir.extraData(Mir.MemArg, extra_index + 1).data);
                    inst += 1;
                    continue :loop tags[inst];
                },
                .v128_const, .i8x16_shuffle => {
                    code.appendSliceAssumeCapacity(std.mem.asBytes(mir.extra[extra_index + 1 ..][0..4]));
                    inst += 1;
                    continue :loop tags[inst];
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
                    code.appendAssumeCapacity(@intCast(mir.extra[extra_index + 1]));
                    inst += 1;
                    continue :loop tags[inst];
                },
                .i8x16_splat,
                .i16x8_splat,
                .i32x4_splat,
                .i64x2_splat,
                .f32x4_splat,
                .f64x2_splat,
                => {
                    inst += 1;
                    continue :loop tags[inst];
                },
                _ => unreachable,
            }
            comptime unreachable;
        },
        .atomics_prefix => {
            try code.ensureUnusedCapacity(gpa, 6 + 20);

            const extra_index = mir.instructions.items(.data)[inst].payload;
            const opcode = mir.extra[extra_index];
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.atomics_prefix));
            leb.writeUleb128(code.fixedWriter(), opcode) catch unreachable;
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
                    const mem_arg = mir.extraData(Mir.MemArg, extra_index + 1).data;
                    encodeMemArg(code, mem_arg);
                    inst += 1;
                    continue :loop tags[inst];
                },
                .atomic_fence => {
                    // Hard-codes memory index 0 since multi-memory proposal is
                    // not yet accepted nor implemented.
                    const memory_index: u32 = 0;
                    leb.writeUleb128(code.fixedWriter(), memory_index) catch unreachable;
                    inst += 1;
                    continue :loop tags[inst];
                },
            }
            comptime unreachable;
        },
    }
    comptime unreachable;
}

/// Asserts 20 unused capacity.
fn encodeMemArg(code: *std.ArrayListUnmanaged(u8), mem_arg: Mir.MemArg) void {
    assert(code.unusedCapacitySlice().len >= 20);
    // Wasm encodes alignment as power of 2, rather than natural alignment.
    const encoded_alignment = @ctz(mem_arg.alignment);
    leb.writeUleb128(code.fixedWriter(), encoded_alignment) catch unreachable;
    leb.writeUleb128(code.fixedWriter(), mem_arg.offset) catch unreachable;
}

fn uavRefOff(wasm: *link.File.Wasm, code: *std.ArrayListUnmanaged(u8), data: Mir.UavRefOff, is_wasm32: bool) !void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const is_obj = comp.config.output_mode == .Obj;
    const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;

    try code.ensureUnusedCapacity(gpa, 11);
    code.appendAssumeCapacity(@intFromEnum(opcode));

    // If outputting an object file, this needs to be a relocation, since global
    // constant data may be mixed with other object files in the final link.
    if (is_obj) {
        try wasm.out_relocs.append(gpa, .{
            .offset = @intCast(code.items.len),
            .index = try wasm.uavSymbolIndex(data.ip_index),
            .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
            .addend = data.offset,
        });
        code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);
        return;
    }

    // When linking into the final binary, no relocation mechanism is necessary.
    const addr: i64 = try wasm.uavAddr(data.ip_index);
    leb.writeUleb128(code.fixedWriter(), addr + data.offset) catch unreachable;
}

fn navRefOff(wasm: *link.File.Wasm, code: *std.ArrayListUnmanaged(u8), data: Mir.NavRefOff, is_wasm32: bool) !void {
    const comp = wasm.base.comp;
    const zcu = comp.zcu.?;
    const ip = &zcu.intern_pool;
    const gpa = comp.gpa;
    const is_obj = comp.config.output_mode == .Obj;
    const nav_ty = ip.getNav(data.nav_index).typeOf(ip);

    try code.ensureUnusedCapacity(gpa, 11);

    if (ip.isFunctionType(nav_ty)) {
        code.appendAssumeCapacity(std.wasm.Opcode.i32_const);
        assert(data.offset == 0);
        if (is_obj) {
            try wasm.out_relocs.append(gpa, .{
                .offset = @intCast(code.items.len),
                .index = try wasm.navSymbolIndex(data.nav_index),
                .tag = .TABLE_INDEX_SLEB,
                .addend = data.offset,
            });
            code.appendNTimesAssumeCapacity(0, 5);
        } else {
            const addr: i64 = try wasm.navAddr(data.nav_index);
            leb.writeUleb128(code.fixedWriter(), addr + data.offset) catch unreachable;
        }
    } else {
        const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;
        code.appendAssumeCapacity(@intFromEnum(opcode));
        if (is_obj) {
            try wasm.out_relocs.append(gpa, .{
                .offset = @intCast(code.items.len),
                .index = try wasm.navSymbolIndex(data.nav_index),
                .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
                .addend = data.offset,
            });
            code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);
        } else {
            const addr: i64 = try wasm.navAddr(data.nav_index);
            leb.writeUleb128(code.fixedWriter(), addr + data.offset) catch unreachable;
        }
    }
}
