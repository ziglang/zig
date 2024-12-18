const Emit = @This();

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const leb = std.leb;

const Wasm = link.File.Wasm;
const Mir = @import("Mir.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const codegen = @import("../../codegen.zig");

mir: Mir,
wasm: *Wasm,
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
    const function_imports_len: u32 = @intCast(wasm.function_imports.entries.len);

    const tags = mir.instruction_tags;
    const datas = mir.instruction_datas;
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
            if (is_obj) {
                try uavRefOffObj(wasm, code, .{ .uav_obj = datas[inst].uav_obj, .offset = 0 }, is_wasm32);
            } else {
                try uavRefOffExe(wasm, code, .{ .uav_exe = datas[inst].uav_exe, .offset = 0 }, is_wasm32);
            }
            inst += 1;
            continue :loop tags[inst];
        },
        .uav_ref_off => {
            if (is_obj) {
                try uavRefOffObj(wasm, code, mir.extraData(Mir.UavRefOffObj, datas[inst].payload).data, is_wasm32);
            } else {
                try uavRefOffExe(wasm, code, mir.extraData(Mir.UavRefOffExe, datas[inst].payload).data, is_wasm32);
            }
            inst += 1;
            continue :loop tags[inst];
        },
        .nav_ref => {
            try navRefOff(wasm, code, .{ .nav_index = datas[inst].nav_index, .offset = 0 }, is_wasm32);
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
                    .pointee = .{ .symbol_index = try wasm.errorNameTableSymbolIndex() },
                    .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);

                inst += 1;
                continue :loop tags[inst];
            } else {
                const addr: u32 = wasm.errorNameTableAddr();
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
            const extra_index = datas[inst].payload;
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
                    .pointee = .{ .symbol_index = try wasm.navSymbolIndex(datas[inst].nav_index) },
                    .tag = .FUNCTION_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const func_index = Wasm.FunctionIndex.fromIpNav(wasm, datas[inst].nav_index).?;
                leb.writeUleb128(code.fixedWriter(), function_imports_len + @intFromEnum(func_index)) catch unreachable;
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
                    .pointee = .{ .type_index = func_ty_index },
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

        .call_tag_name => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .pointee = .{ .symbol_index = try wasm.tagNameSymbolIndex(datas[inst].ip_index) },
                    .tag = .FUNCTION_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const func_index = Wasm.FunctionIndex.fromTagNameType(wasm, datas[inst].ip_index).?;
                leb.writeUleb128(code.fixedWriter(), function_imports_len + @intFromEnum(func_index)) catch unreachable;
            }

            inst += 1;
            continue :loop tags[inst];
        },

        .call_intrinsic => {
            // Although this currently uses `wasm.internString`, note that it
            // *could* be changed to directly index into a preloaded strings
            // table initialized based on the `Mir.Intrinsic` enum.
            const symbol_name = try wasm.internString(@tagName(datas[inst].intrinsic));

            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.call));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .pointee = .{ .symbol_index = try wasm.symbolNameIndex(symbol_name) },
                    .tag = .FUNCTION_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const func_index = Wasm.FunctionIndex.fromSymbolName(wasm, symbol_name).?;
                leb.writeUleb128(code.fixedWriter(), function_imports_len + @intFromEnum(func_index)) catch unreachable;
            }

            inst += 1;
            continue :loop tags[inst];
        },

        .global_set_sp => {
            try code.ensureUnusedCapacity(gpa, 6);
            code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.global_set));
            if (is_obj) {
                try wasm.out_relocs.append(gpa, .{
                    .offset = @intCast(code.items.len),
                    .pointee = .{ .symbol_index = try wasm.stackPointerSymbolIndex() },
                    .tag = .GLOBAL_INDEX_LEB,
                    .addend = 0,
                });
                code.appendNTimesAssumeCapacity(0, 5);
            } else {
                const sp_global: Wasm.GlobalIndex = .stack_pointer;
                std.leb.writeULEB128(code.fixedWriter(), @intFromEnum(sp_global)) catch unreachable;
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
            leb.writeIleb128(code.fixedWriter(), int64) catch unreachable;

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
            encodeMemArg(code, mir.extraData(Mir.MemArg, datas[inst].payload).data);
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

                .table_init => @panic("TODO"),
                .elem_drop => @panic("TODO"),
                .table_copy => @panic("TODO"),
                .table_grow => @panic("TODO"),
                .table_size => @panic("TODO"),
                .table_fill => @panic("TODO"),

                _ => unreachable,
            }
            comptime unreachable;
        },
        .simd_prefix => {
            try code.ensureUnusedCapacity(gpa, 6 + 20);
            const extra_index = datas[inst].payload;
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

                .v128_load8x8_s => @panic("TODO"),
                .v128_load8x8_u => @panic("TODO"),
                .v128_load16x4_s => @panic("TODO"),
                .v128_load16x4_u => @panic("TODO"),
                .v128_load32x2_s => @panic("TODO"),
                .v128_load32x2_u => @panic("TODO"),
                .i8x16_swizzle => @panic("TODO"),
                .i8x16_eq => @panic("TODO"),
                .i16x8_eq => @panic("TODO"),
                .i32x4_eq => @panic("TODO"),
                .i8x16_ne => @panic("TODO"),
                .i16x8_ne => @panic("TODO"),
                .i32x4_ne => @panic("TODO"),
                .i8x16_lt_s => @panic("TODO"),
                .i16x8_lt_s => @panic("TODO"),
                .i32x4_lt_s => @panic("TODO"),
                .i8x16_lt_u => @panic("TODO"),
                .i16x8_lt_u => @panic("TODO"),
                .i32x4_lt_u => @panic("TODO"),
                .i8x16_gt_s => @panic("TODO"),
                .i16x8_gt_s => @panic("TODO"),
                .i32x4_gt_s => @panic("TODO"),
                .i8x16_gt_u => @panic("TODO"),
                .i16x8_gt_u => @panic("TODO"),
                .i32x4_gt_u => @panic("TODO"),
                .i8x16_le_s => @panic("TODO"),
                .i16x8_le_s => @panic("TODO"),
                .i32x4_le_s => @panic("TODO"),
                .i8x16_le_u => @panic("TODO"),
                .i16x8_le_u => @panic("TODO"),
                .i32x4_le_u => @panic("TODO"),
                .i8x16_ge_s => @panic("TODO"),
                .i16x8_ge_s => @panic("TODO"),
                .i32x4_ge_s => @panic("TODO"),
                .i8x16_ge_u => @panic("TODO"),
                .i16x8_ge_u => @panic("TODO"),
                .i32x4_ge_u => @panic("TODO"),
                .f32x4_eq => @panic("TODO"),
                .f64x2_eq => @panic("TODO"),
                .f32x4_ne => @panic("TODO"),
                .f64x2_ne => @panic("TODO"),
                .f32x4_lt => @panic("TODO"),
                .f64x2_lt => @panic("TODO"),
                .f32x4_gt => @panic("TODO"),
                .f64x2_gt => @panic("TODO"),
                .f32x4_le => @panic("TODO"),
                .f64x2_le => @panic("TODO"),
                .f32x4_ge => @panic("TODO"),
                .f64x2_ge => @panic("TODO"),
                .v128_not => @panic("TODO"),
                .v128_and => @panic("TODO"),
                .v128_andnot => @panic("TODO"),
                .v128_or => @panic("TODO"),
                .v128_xor => @panic("TODO"),
                .v128_bitselect => @panic("TODO"),
                .v128_any_true => @panic("TODO"),
                .v128_load8_lane => @panic("TODO"),
                .v128_load16_lane => @panic("TODO"),
                .v128_load32_lane => @panic("TODO"),
                .v128_load64_lane => @panic("TODO"),
                .v128_store8_lane => @panic("TODO"),
                .v128_store16_lane => @panic("TODO"),
                .v128_store32_lane => @panic("TODO"),
                .v128_store64_lane => @panic("TODO"),
                .v128_load32_zero => @panic("TODO"),
                .v128_load64_zero => @panic("TODO"),
                .f32x4_demote_f64x2_zero => @panic("TODO"),
                .f64x2_promote_low_f32x4 => @panic("TODO"),
                .i8x16_abs => @panic("TODO"),
                .i16x8_abs => @panic("TODO"),
                .i32x4_abs => @panic("TODO"),
                .i64x2_abs => @panic("TODO"),
                .i8x16_neg => @panic("TODO"),
                .i16x8_neg => @panic("TODO"),
                .i32x4_neg => @panic("TODO"),
                .i64x2_neg => @panic("TODO"),
                .i8x16_popcnt => @panic("TODO"),
                .i16x8_q15mulr_sat_s => @panic("TODO"),
                .i8x16_all_true => @panic("TODO"),
                .i16x8_all_true => @panic("TODO"),
                .i32x4_all_true => @panic("TODO"),
                .i64x2_all_true => @panic("TODO"),
                .i8x16_bitmask => @panic("TODO"),
                .i16x8_bitmask => @panic("TODO"),
                .i32x4_bitmask => @panic("TODO"),
                .i64x2_bitmask => @panic("TODO"),
                .i8x16_narrow_i16x8_s => @panic("TODO"),
                .i16x8_narrow_i32x4_s => @panic("TODO"),
                .i8x16_narrow_i16x8_u => @panic("TODO"),
                .i16x8_narrow_i32x4_u => @panic("TODO"),
                .f32x4_ceil => @panic("TODO"),
                .i16x8_extend_low_i8x16_s => @panic("TODO"),
                .i32x4_extend_low_i16x8_s => @panic("TODO"),
                .i64x2_extend_low_i32x4_s => @panic("TODO"),
                .f32x4_floor => @panic("TODO"),
                .i16x8_extend_high_i8x16_s => @panic("TODO"),
                .i32x4_extend_high_i16x8_s => @panic("TODO"),
                .i64x2_extend_high_i32x4_s => @panic("TODO"),
                .f32x4_trunc => @panic("TODO"),
                .i16x8_extend_low_i8x16_u => @panic("TODO"),
                .i32x4_extend_low_i16x8_u => @panic("TODO"),
                .i64x2_extend_low_i32x4_u => @panic("TODO"),
                .f32x4_nearest => @panic("TODO"),
                .i16x8_extend_high_i8x16_u => @panic("TODO"),
                .i32x4_extend_high_i16x8_u => @panic("TODO"),
                .i64x2_extend_high_i32x4_u => @panic("TODO"),
                .i8x16_shl => @panic("TODO"),
                .i16x8_shl => @panic("TODO"),
                .i32x4_shl => @panic("TODO"),
                .i64x2_shl => @panic("TODO"),
                .i8x16_shr_s => @panic("TODO"),
                .i16x8_shr_s => @panic("TODO"),
                .i32x4_shr_s => @panic("TODO"),
                .i64x2_shr_s => @panic("TODO"),
                .i8x16_shr_u => @panic("TODO"),
                .i16x8_shr_u => @panic("TODO"),
                .i32x4_shr_u => @panic("TODO"),
                .i64x2_shr_u => @panic("TODO"),
                .i8x16_add => @panic("TODO"),
                .i16x8_add => @panic("TODO"),
                .i32x4_add => @panic("TODO"),
                .i64x2_add => @panic("TODO"),
                .i8x16_add_sat_s => @panic("TODO"),
                .i16x8_add_sat_s => @panic("TODO"),
                .i8x16_add_sat_u => @panic("TODO"),
                .i16x8_add_sat_u => @panic("TODO"),
                .i8x16_sub => @panic("TODO"),
                .i16x8_sub => @panic("TODO"),
                .i32x4_sub => @panic("TODO"),
                .i64x2_sub => @panic("TODO"),
                .i8x16_sub_sat_s => @panic("TODO"),
                .i16x8_sub_sat_s => @panic("TODO"),
                .i8x16_sub_sat_u => @panic("TODO"),
                .i16x8_sub_sat_u => @panic("TODO"),
                .f64x2_ceil => @panic("TODO"),
                .f64x2_nearest => @panic("TODO"),
                .f64x2_floor => @panic("TODO"),
                .i16x8_mul => @panic("TODO"),
                .i32x4_mul => @panic("TODO"),
                .i64x2_mul => @panic("TODO"),
                .i8x16_min_s => @panic("TODO"),
                .i16x8_min_s => @panic("TODO"),
                .i32x4_min_s => @panic("TODO"),
                .i64x2_eq => @panic("TODO"),
                .i8x16_min_u => @panic("TODO"),
                .i16x8_min_u => @panic("TODO"),
                .i32x4_min_u => @panic("TODO"),
                .i64x2_ne => @panic("TODO"),
                .i8x16_max_s => @panic("TODO"),
                .i16x8_max_s => @panic("TODO"),
                .i32x4_max_s => @panic("TODO"),
                .i64x2_lt_s => @panic("TODO"),
                .i8x16_max_u => @panic("TODO"),
                .i16x8_max_u => @panic("TODO"),
                .i32x4_max_u => @panic("TODO"),
                .i64x2_gt_s => @panic("TODO"),
                .f64x2_trunc => @panic("TODO"),
                .i32x4_dot_i16x8_s => @panic("TODO"),
                .i64x2_le_s => @panic("TODO"),
                .i8x16_avgr_u => @panic("TODO"),
                .i16x8_avgr_u => @panic("TODO"),
                .i64x2_ge_s => @panic("TODO"),
                .i16x8_extadd_pairwise_i8x16_s => @panic("TODO"),
                .i16x8_extmul_low_i8x16_s => @panic("TODO"),
                .i32x4_extmul_low_i16x8_s => @panic("TODO"),
                .i64x2_extmul_low_i32x4_s => @panic("TODO"),
                .i16x8_extadd_pairwise_i8x16_u => @panic("TODO"),
                .i16x8_extmul_high_i8x16_s => @panic("TODO"),
                .i32x4_extmul_high_i16x8_s => @panic("TODO"),
                .i64x2_extmul_high_i32x4_s => @panic("TODO"),
                .i32x4_extadd_pairwise_i16x8_s => @panic("TODO"),
                .i16x8_extmul_low_i8x16_u => @panic("TODO"),
                .i32x4_extmul_low_i16x8_u => @panic("TODO"),
                .i64x2_extmul_low_i32x4_u => @panic("TODO"),
                .i32x4_extadd_pairwise_i16x8_u => @panic("TODO"),
                .i16x8_extmul_high_i8x16_u => @panic("TODO"),
                .i32x4_extmul_high_i16x8_u => @panic("TODO"),
                .i64x2_extmul_high_i32x4_u => @panic("TODO"),
                .f32x4_abs => @panic("TODO"),
                .f64x2_abs => @panic("TODO"),
                .f32x4_neg => @panic("TODO"),
                .f64x2_neg => @panic("TODO"),
                .f32x4_sqrt => @panic("TODO"),
                .f64x2_sqrt => @panic("TODO"),
                .f32x4_add => @panic("TODO"),
                .f64x2_add => @panic("TODO"),
                .f32x4_sub => @panic("TODO"),
                .f64x2_sub => @panic("TODO"),
                .f32x4_mul => @panic("TODO"),
                .f64x2_mul => @panic("TODO"),
                .f32x4_div => @panic("TODO"),
                .f64x2_div => @panic("TODO"),
                .f32x4_min => @panic("TODO"),
                .f64x2_min => @panic("TODO"),
                .f32x4_max => @panic("TODO"),
                .f64x2_max => @panic("TODO"),
                .f32x4_pmin => @panic("TODO"),
                .f64x2_pmin => @panic("TODO"),
                .f32x4_pmax => @panic("TODO"),
                .f64x2_pmax => @panic("TODO"),
                .i32x4_trunc_sat_f32x4_s => @panic("TODO"),
                .i32x4_trunc_sat_f32x4_u => @panic("TODO"),
                .f32x4_convert_i32x4_s => @panic("TODO"),
                .f32x4_convert_i32x4_u => @panic("TODO"),
                .i32x4_trunc_sat_f64x2_s_zero => @panic("TODO"),
                .i32x4_trunc_sat_f64x2_u_zero => @panic("TODO"),
                .f64x2_convert_low_i32x4_s => @panic("TODO"),
                .f64x2_convert_low_i32x4_u => @panic("TODO"),
                .i8x16_relaxed_swizzle => @panic("TODO"),
                .i32x4_relaxed_trunc_f32x4_s => @panic("TODO"),
                .i32x4_relaxed_trunc_f32x4_u => @panic("TODO"),
                .i32x4_relaxed_trunc_f64x2_s_zero => @panic("TODO"),
                .i32x4_relaxed_trunc_f64x2_u_zero => @panic("TODO"),
                .f32x4_relaxed_madd => @panic("TODO"),
                .f32x4_relaxed_nmadd => @panic("TODO"),
                .f64x2_relaxed_madd => @panic("TODO"),
                .f64x2_relaxed_nmadd => @panic("TODO"),
                .i8x16_relaxed_laneselect => @panic("TODO"),
                .i16x8_relaxed_laneselect => @panic("TODO"),
                .i32x4_relaxed_laneselect => @panic("TODO"),
                .i64x2_relaxed_laneselect => @panic("TODO"),
                .f32x4_relaxed_min => @panic("TODO"),
                .f32x4_relaxed_max => @panic("TODO"),
                .f64x2_relaxed_min => @panic("TODO"),
                .f64x2_relaxed_max => @panic("TODO"),
                .i16x8_relaxed_q15mulr_s => @panic("TODO"),
                .i16x8_relaxed_dot_i8x16_i7x16_s => @panic("TODO"),
                .i32x4_relaxed_dot_i8x16_i7x16_add_s => @panic("TODO"),
                .f32x4_relaxed_dot_bf16x8_add_f32x4 => @panic("TODO"),
            }
            comptime unreachable;
        },
        .atomics_prefix => {
            try code.ensureUnusedCapacity(gpa, 6 + 20);

            const extra_index = datas[inst].payload;
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
                .memory_atomic_notify => @panic("TODO"),
                .memory_atomic_wait32 => @panic("TODO"),
                .memory_atomic_wait64 => @panic("TODO"),
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

fn uavRefOffObj(wasm: *Wasm, code: *std.ArrayListUnmanaged(u8), data: Mir.UavRefOffObj, is_wasm32: bool) !void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;

    try code.ensureUnusedCapacity(gpa, 11);
    code.appendAssumeCapacity(@intFromEnum(opcode));

    try wasm.out_relocs.append(gpa, .{
        .offset = @intCast(code.items.len),
        .pointee = .{ .symbol_index = try wasm.uavSymbolIndex(data.uav_obj.key(wasm).*) },
        .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
        .addend = data.offset,
    });
    code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);
}

fn uavRefOffExe(wasm: *Wasm, code: *std.ArrayListUnmanaged(u8), data: Mir.UavRefOffExe, is_wasm32: bool) !void {
    const comp = wasm.base.comp;
    const gpa = comp.gpa;
    const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;

    try code.ensureUnusedCapacity(gpa, 11);
    code.appendAssumeCapacity(@intFromEnum(opcode));

    const addr = wasm.uavAddr(data.uav_exe);
    leb.writeUleb128(code.fixedWriter(), @as(u32, @intCast(@as(i64, addr) + data.offset))) catch unreachable;
}

fn navRefOff(wasm: *Wasm, code: *std.ArrayListUnmanaged(u8), data: Mir.NavRefOff, is_wasm32: bool) !void {
    const comp = wasm.base.comp;
    const zcu = comp.zcu.?;
    const ip = &zcu.intern_pool;
    const gpa = comp.gpa;
    const is_obj = comp.config.output_mode == .Obj;
    const nav_ty = ip.getNav(data.nav_index).typeOf(ip);

    try code.ensureUnusedCapacity(gpa, 11);

    if (ip.isFunctionType(nav_ty)) {
        code.appendAssumeCapacity(@intFromEnum(std.wasm.Opcode.i32_const));
        assert(data.offset == 0);
        if (is_obj) {
            try wasm.out_relocs.append(gpa, .{
                .offset = @intCast(code.items.len),
                .pointee = .{ .symbol_index = try wasm.navSymbolIndex(data.nav_index) },
                .tag = .TABLE_INDEX_SLEB,
                .addend = data.offset,
            });
            code.appendNTimesAssumeCapacity(0, 5);
        } else {
            const function_imports_len: u32 = @intCast(wasm.function_imports.entries.len);
            const func_index = Wasm.FunctionIndex.fromIpNav(wasm, data.nav_index).?;
            leb.writeUleb128(code.fixedWriter(), function_imports_len + @intFromEnum(func_index)) catch unreachable;
        }
    } else {
        const opcode: std.wasm.Opcode = if (is_wasm32) .i32_const else .i64_const;
        code.appendAssumeCapacity(@intFromEnum(opcode));
        if (is_obj) {
            try wasm.out_relocs.append(gpa, .{
                .offset = @intCast(code.items.len),
                .pointee = .{ .symbol_index = try wasm.navSymbolIndex(data.nav_index) },
                .tag = if (is_wasm32) .MEMORY_ADDR_LEB else .MEMORY_ADDR_LEB64,
                .addend = data.offset,
            });
            code.appendNTimesAssumeCapacity(0, if (is_wasm32) 5 else 10);
        } else {
            const addr = wasm.navAddr(data.nav_index);
            leb.writeUleb128(code.fixedWriter(), @as(u32, @intCast(@as(i64, addr) + data.offset))) catch unreachable;
        }
    }
}
