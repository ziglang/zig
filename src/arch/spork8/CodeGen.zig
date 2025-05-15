const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const CodeGen = @This();
const link = @import("../../link.zig");
const Spork8 = link.File.Spork8;
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const Air = @import("../../Air.zig");
const Liveness = @import("../../Liveness.zig");
const Mir = @import("Mir.zig");

air: Air,
liveness: Liveness,
gpa: Allocator,
spork8: *Spork8,
pt: Zcu.PerThread,
owner_nav: InternPool.Nav.Index,
func_index: InternPool.Index,
mir_instructions: *std.MultiArrayList(Mir.Inst),
/// Contains extra data for MIR
mir_extra: *std.ArrayListUnmanaged(u32),
start_mir_extra_off: u32,

pub const Error = error{
    OutOfMemory,
    /// Compiler was asked to operate on a number larger than supported.
    Overflow,
    /// Indicates the error is already stored in Zcu `failed_codegen`.
    CodegenFail,
};

pub const Function = extern struct {
    /// Index into `Spork8.mir_instructions`.
    mir_off: u32,
    /// This is unused except for as a safety slice bound and could be removed.
    mir_len: u32,
    /// Index into `Spork8.mir_extra`.
    mir_extra_off: u32,
    /// This is unused except for as a safety slice bound and could be removed.
    mir_extra_len: u32,
};

pub fn function(
    spork8: *Spork8,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) Error!Function {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func_info = zcu.funcInfo(func_index);

    var code_gen: CodeGen = .{
        .gpa = gpa,
        .pt = pt,
        .air = air,
        .liveness = liveness,
        .owner_nav = func_info.owner_nav,
        .spork8 = spork8,
        .func_index = func_index,
        .mir_instructions = &spork8.mir_instructions,
        .mir_extra = &spork8.mir_extra,
        .start_mir_extra_off = @intCast(spork8.mir_extra.items.len),
    };
    defer code_gen.deinit();

    return functionInner(&code_gen) catch |err| switch (err) {
        error.CodegenFail => return error.CodegenFail,
        else => |e| return code_gen.fail("failed to generate function: {s}", .{@errorName(e)}),
    };
}

fn deinit(cg: *CodeGen) void {
    cg.* = undefined;
}

const InnerError = error{
    CodegenFail,
    OutOfMemory,
};

fn functionInner(cg: *CodeGen) InnerError!Function {
    const spork8 = cg.spork8;

    const start_mir_off: u32 = @intCast(spork8.mir_instructions.len);

    // Generate MIR for function body
    try cg.genBody(cg.air.getMainBody());

    return .{
        .mir_off = start_mir_off,
        .mir_len = @intCast(spork8.mir_instructions.len - start_mir_off),
        .mir_extra_off = cg.start_mir_extra_off,
        .mir_extra_len = cg.extraLen(),
    };
}

fn genBody(cg: *CodeGen, body: []const Air.Inst.Index) InnerError!void {
    const zcu = cg.pt.zcu;
    const ip = &zcu.intern_pool;

    for (body) |inst| {
        if (cg.liveness.isUnused(inst) and !cg.air.mustLower(inst, ip)) continue;
        try cg.genInst(inst);
    }
}

fn genInst(cg: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const air_tags = cg.air.instructions.items(.tag);
    return switch (air_tags[@intFromEnum(inst)]) {
        .inferred_alloc, .inferred_alloc_comptime => unreachable,

        .unreach => cg.airUnreachable(inst),

        .add,
        .add_sat,
        .add_wrap,
        .sub,
        .sub_sat,
        .sub_wrap,
        .mul,
        .mul_sat,
        .mul_wrap,
        .div_float,
        .div_exact,
        .div_trunc,
        .div_floor,
        .bit_and,
        .bit_or,
        .bool_and,
        .bool_or,
        .rem,
        .mod,
        .shl,
        .shl_exact,
        .shl_sat,
        .shr,
        .shr_exact,
        .xor,
        .max,
        .min,
        .mul_add,

        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .floor,
        .ceil,
        .round,
        .trunc_float,
        .neg,

        .abs,

        .add_with_overflow,
        .sub_with_overflow,
        .shl_with_overflow,
        .mul_with_overflow,

        .clz,
        .ctz,

        .cmp_eq,
        .cmp_gte,
        .cmp_gt,
        .cmp_lte,
        .cmp_lt,
        .cmp_neq,

        .cmp_vector,
        .cmp_lt_errors_len,

        .array_elem_val,
        .array_to_slice,
        .alloc,
        .arg,
        .bitcast,
        .block,
        .trap,
        .breakpoint,
        .br,
        .repeat,
        .switch_dispatch,
        .cond_br,
        .intcast,
        .fptrunc,
        .fpext,
        .int_from_float,
        .float_from_int,
        .get_union_tag,

        .@"try",
        .try_cold,
        .try_ptr,
        .try_ptr_cold,

        .dbg_stmt,
        .dbg_empty_stmt,
        .dbg_inline_block,
        .dbg_var_ptr,
        .dbg_var_val,
        .dbg_arg_inline,

        .call,
        .call_always_tail,
        .call_never_tail,
        .call_never_inline,

        .is_err,
        .is_non_err,

        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,

        .load,
        .loop,
        .memset,
        .memset_safe,
        .not,
        .optional_payload,
        .optional_payload_ptr,
        .optional_payload_ptr_set,
        .ptr_add,
        .ptr_sub,
        .ptr_elem_ptr,
        .ptr_elem_val,
        .ret,
        .ret_safe,
        .ret_ptr,
        .ret_load,
        .splat,
        .select,
        .shuffle,
        .reduce,
        .aggregate_init,
        .union_init,
        .prefetch,
        .popcount,
        .byte_swap,
        .bit_reverse,

        .slice,
        .slice_len,
        .slice_elem_val,
        .slice_elem_ptr,
        .slice_ptr,
        .ptr_slice_len_ptr,
        .ptr_slice_ptr_ptr,
        .store,
        .store_safe,

        .set_union_tag,
        .struct_field_ptr,
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        .struct_field_val,
        .field_parent_ptr,

        .switch_br,
        .loop_switch_br,
        .trunc,

        .wrap_optional,
        .unwrap_errunion_payload,
        .unwrap_errunion_payload_ptr,
        .unwrap_errunion_err,
        .unwrap_errunion_err_ptr,
        .wrap_errunion_payload,
        .wrap_errunion_err,
        .errunion_payload_ptr_set,
        .error_name,

        .wasm_memory_size,
        .wasm_memory_grow,

        .memcpy,

        .ret_addr,
        .tag_name,

        .error_set_has_value,
        .frame_addr,

        .assembly,
        .is_err_ptr,
        .is_non_err_ptr,

        .err_return_trace,
        .set_err_return_trace,
        .save_err_return_trace_index,
        .is_named_enum_value,
        .addrspace_cast,
        .vector_store_elem,
        .c_va_arg,
        .c_va_copy,
        .c_va_end,
        .c_va_start,
        .memmove,

        .atomic_load,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .atomic_rmw,
        .cmpxchg_weak,
        .cmpxchg_strong,

        .add_optimized,
        .sub_optimized,
        .mul_optimized,
        .div_float_optimized,
        .div_trunc_optimized,
        .div_floor_optimized,
        .div_exact_optimized,
        .rem_optimized,
        .mod_optimized,
        .neg_optimized,
        .cmp_lt_optimized,
        .cmp_lte_optimized,
        .cmp_eq_optimized,
        .cmp_gte_optimized,
        .cmp_gt_optimized,
        .cmp_neq_optimized,
        .cmp_vector_optimized,
        .reduce_optimized,
        .int_from_float_optimized,
        .add_safe,
        .sub_safe,
        .mul_safe,
        .intcast_safe,
        => |tag| return cg.fail("TODO: implement spork8 inst: {s}", .{@tagName(tag)}),

        .work_item_id,
        .work_group_size,
        .work_group_id,
        => unreachable,
    };
}

fn airUnreachable(cg: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    _ = cg;
    _ = inst;
}

fn fail(cg: *CodeGen, comptime fmt: []const u8, args: anytype) error{ OutOfMemory, CodegenFail } {
    const zcu = cg.pt.zcu;
    const func = zcu.funcInfo(cg.func_index);
    return zcu.codegenFail(func.owner_nav, fmt, args);
}

fn extraLen(cg: *const CodeGen) u32 {
    return @intCast(cg.mir_extra.items.len - cg.start_mir_extra_off);
}
