const Air = @import("../Air.zig");
const Zcu = @import("../Zcu.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const InternPool = @import("../InternPool.zig");

/// Given a body of AIR instructions, returns whether all type resolution necessary for codegen is complete.
/// If `false`, then type resolution must have failed, so codegen cannot proceed.
pub fn typesFullyResolved(air: Air, zcu: *Zcu) bool {
    return checkBody(air, air.getMainBody(), zcu);
}

fn checkBody(air: Air, body: []const Air.Inst.Index, zcu: *Zcu) bool {
    const tags = air.instructions.items(.tag);
    const datas = air.instructions.items(.data);

    for (body) |inst| {
        const data = datas[@intFromEnum(inst)];
        switch (tags[@intFromEnum(inst)]) {
            .inferred_alloc, .inferred_alloc_comptime => unreachable,

            .arg => {
                if (!checkType(data.arg.ty.toType(), zcu)) return false;
            },

            .add,
            .add_safe,
            .add_optimized,
            .add_wrap,
            .add_sat,
            .sub,
            .sub_safe,
            .sub_optimized,
            .sub_wrap,
            .sub_sat,
            .mul,
            .mul_safe,
            .mul_optimized,
            .mul_wrap,
            .mul_sat,
            .div_float,
            .div_float_optimized,
            .div_trunc,
            .div_trunc_optimized,
            .div_floor,
            .div_floor_optimized,
            .div_exact,
            .div_exact_optimized,
            .rem,
            .rem_optimized,
            .mod,
            .mod_optimized,
            .max,
            .min,
            .bit_and,
            .bit_or,
            .shr,
            .shr_exact,
            .shl,
            .shl_exact,
            .shl_sat,
            .xor,
            .cmp_lt,
            .cmp_lt_optimized,
            .cmp_lte,
            .cmp_lte_optimized,
            .cmp_eq,
            .cmp_eq_optimized,
            .cmp_gte,
            .cmp_gte_optimized,
            .cmp_gt,
            .cmp_gt_optimized,
            .cmp_neq,
            .cmp_neq_optimized,
            .bool_and,
            .bool_or,
            .store,
            .store_safe,
            .set_union_tag,
            .array_elem_val,
            .slice_elem_val,
            .ptr_elem_val,
            .memset,
            .memset_safe,
            .memcpy,
            .atomic_store_unordered,
            .atomic_store_monotonic,
            .atomic_store_release,
            .atomic_store_seq_cst,
            => {
                if (!checkRef(data.bin_op.lhs, zcu)) return false;
                if (!checkRef(data.bin_op.rhs, zcu)) return false;
            },

            .not,
            .bitcast,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .abs,
            .load,
            .fptrunc,
            .fpext,
            .intcast,
            .trunc,
            .optional_payload,
            .optional_payload_ptr,
            .optional_payload_ptr_set,
            .wrap_optional,
            .unwrap_errunion_payload,
            .unwrap_errunion_err,
            .unwrap_errunion_payload_ptr,
            .unwrap_errunion_err_ptr,
            .errunion_payload_ptr_set,
            .wrap_errunion_payload,
            .wrap_errunion_err,
            .struct_field_ptr_index_0,
            .struct_field_ptr_index_1,
            .struct_field_ptr_index_2,
            .struct_field_ptr_index_3,
            .get_union_tag,
            .slice_len,
            .slice_ptr,
            .ptr_slice_len_ptr,
            .ptr_slice_ptr_ptr,
            .array_to_slice,
            .int_from_float,
            .int_from_float_optimized,
            .float_from_int,
            .splat,
            .error_set_has_value,
            .addrspace_cast,
            .c_va_arg,
            .c_va_copy,
            => {
                if (!checkType(data.ty_op.ty.toType(), zcu)) return false;
                if (!checkRef(data.ty_op.operand, zcu)) return false;
            },

            .alloc,
            .ret_ptr,
            .c_va_start,
            => {
                if (!checkType(data.ty, zcu)) return false;
            },

            .ptr_add,
            .ptr_sub,
            .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            .slice,
            .slice_elem_ptr,
            .ptr_elem_ptr,
            => {
                const bin = air.extraData(Air.Bin, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(bin.lhs, zcu)) return false;
                if (!checkRef(bin.rhs, zcu)) return false;
            },

            .block,
            .loop,
            => {
                const extra = air.extraData(Air.Block, data.ty_pl.payload);
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end..][0..extra.data.body_len]),
                    zcu,
                )) return false;
            },

            .dbg_inline_block => {
                const extra = air.extraData(Air.DbgInlineBlock, data.ty_pl.payload);
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end..][0..extra.data.body_len]),
                    zcu,
                )) return false;
            },

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
            .neg_optimized,
            .is_null,
            .is_non_null,
            .is_null_ptr,
            .is_non_null_ptr,
            .is_err,
            .is_non_err,
            .is_err_ptr,
            .is_non_err_ptr,
            .int_from_ptr,
            .int_from_bool,
            .ret,
            .ret_safe,
            .ret_load,
            .is_named_enum_value,
            .tag_name,
            .error_name,
            .cmp_lt_errors_len,
            .c_va_end,
            .set_err_return_trace,
            => {
                if (!checkRef(data.un_op, zcu)) return false;
            },

            .br, .switch_dispatch => {
                if (!checkRef(data.br.operand, zcu)) return false;
            },

            .cmp_vector,
            .cmp_vector_optimized,
            => {
                const extra = air.extraData(Air.VectorCmp, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.lhs, zcu)) return false;
                if (!checkRef(extra.rhs, zcu)) return false;
            },

            .reduce,
            .reduce_optimized,
            => {
                if (!checkRef(data.reduce.operand, zcu)) return false;
            },

            .struct_field_ptr,
            .struct_field_val,
            => {
                const extra = air.extraData(Air.StructField, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.struct_operand, zcu)) return false;
            },

            .shuffle => {
                const extra = air.extraData(Air.Shuffle, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.a, zcu)) return false;
                if (!checkRef(extra.b, zcu)) return false;
                if (!checkVal(Value.fromInterned(extra.mask), zcu)) return false;
            },

            .cmpxchg_weak,
            .cmpxchg_strong,
            => {
                const extra = air.extraData(Air.Cmpxchg, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.ptr, zcu)) return false;
                if (!checkRef(extra.expected_value, zcu)) return false;
                if (!checkRef(extra.new_value, zcu)) return false;
            },

            .aggregate_init => {
                const ty = data.ty_pl.ty.toType();
                const elems_len: usize = @intCast(ty.arrayLen(zcu));
                const elems: []const Air.Inst.Ref = @ptrCast(air.extra[data.ty_pl.payload..][0..elems_len]);
                if (!checkType(ty, zcu)) return false;
                if (ty.zigTypeTag(zcu) == .@"struct") {
                    for (elems, 0..) |elem, elem_idx| {
                        if (ty.structFieldIsComptime(elem_idx, zcu)) continue;
                        if (!checkRef(elem, zcu)) return false;
                    }
                } else {
                    for (elems) |elem| {
                        if (!checkRef(elem, zcu)) return false;
                    }
                }
            },

            .union_init => {
                const extra = air.extraData(Air.UnionInit, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.init, zcu)) return false;
            },

            .field_parent_ptr => {
                const extra = air.extraData(Air.FieldParentPtr, data.ty_pl.payload).data;
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.field_ptr, zcu)) return false;
            },

            .atomic_load => {
                if (!checkRef(data.atomic_load.ptr, zcu)) return false;
            },

            .prefetch => {
                if (!checkRef(data.prefetch.ptr, zcu)) return false;
            },

            .vector_store_elem => {
                const bin = air.extraData(Air.Bin, data.vector_store_elem.payload).data;
                if (!checkRef(data.vector_store_elem.vector_ptr, zcu)) return false;
                if (!checkRef(bin.lhs, zcu)) return false;
                if (!checkRef(bin.rhs, zcu)) return false;
            },

            .select,
            .mul_add,
            => {
                const bin = air.extraData(Air.Bin, data.pl_op.payload).data;
                if (!checkRef(data.pl_op.operand, zcu)) return false;
                if (!checkRef(bin.lhs, zcu)) return false;
                if (!checkRef(bin.rhs, zcu)) return false;
            },

            .atomic_rmw => {
                const extra = air.extraData(Air.AtomicRmw, data.pl_op.payload).data;
                if (!checkRef(data.pl_op.operand, zcu)) return false;
                if (!checkRef(extra.operand, zcu)) return false;
            },

            .call,
            .call_always_tail,
            .call_never_tail,
            .call_never_inline,
            => {
                const extra = air.extraData(Air.Call, data.pl_op.payload);
                const args: []const Air.Inst.Ref = @ptrCast(air.extra[extra.end..][0..extra.data.args_len]);
                if (!checkRef(data.pl_op.operand, zcu)) return false;
                for (args) |arg| if (!checkRef(arg, zcu)) return false;
            },

            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            => {
                if (!checkRef(data.pl_op.operand, zcu)) return false;
            },

            .@"try", .try_cold => {
                const extra = air.extraData(Air.Try, data.pl_op.payload);
                if (!checkRef(data.pl_op.operand, zcu)) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end..][0..extra.data.body_len]),
                    zcu,
                )) return false;
            },

            .try_ptr, .try_ptr_cold => {
                const extra = air.extraData(Air.TryPtr, data.ty_pl.payload);
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                if (!checkRef(extra.data.ptr, zcu)) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end..][0..extra.data.body_len]),
                    zcu,
                )) return false;
            },

            .cond_br => {
                const extra = air.extraData(Air.CondBr, data.pl_op.payload);
                if (!checkRef(data.pl_op.operand, zcu)) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end..][0..extra.data.then_body_len]),
                    zcu,
                )) return false;
                if (!checkBody(
                    air,
                    @ptrCast(air.extra[extra.end + extra.data.then_body_len ..][0..extra.data.else_body_len]),
                    zcu,
                )) return false;
            },

            .switch_br, .loop_switch_br => {
                const switch_br = air.unwrapSwitch(inst);
                if (!checkRef(switch_br.operand, zcu)) return false;
                var it = switch_br.iterateCases();
                while (it.next()) |case| {
                    for (case.items) |item| if (!checkRef(item, zcu)) return false;
                    for (case.ranges) |range| {
                        if (!checkRef(range[0], zcu)) return false;
                        if (!checkRef(range[1], zcu)) return false;
                    }
                    if (!checkBody(air, case.body, zcu)) return false;
                }
                if (!checkBody(air, it.elseBody(), zcu)) return false;
            },

            .assembly => {
                const extra = air.extraData(Air.Asm, data.ty_pl.payload);
                if (!checkType(data.ty_pl.ty.toType(), zcu)) return false;
                // Luckily, we only care about the inputs and outputs, so we don't have to do
                // the whole null-terminated string dance.
                const outputs: []const Air.Inst.Ref = @ptrCast(air.extra[extra.end..][0..extra.data.outputs_len]);
                const inputs: []const Air.Inst.Ref = @ptrCast(air.extra[extra.end + extra.data.outputs_len ..][0..extra.data.inputs_len]);
                for (outputs) |output| if (output != .none and !checkRef(output, zcu)) return false;
                for (inputs) |input| if (input != .none and !checkRef(input, zcu)) return false;
            },

            .trap,
            .breakpoint,
            .ret_addr,
            .frame_addr,
            .unreach,
            .wasm_memory_size,
            .wasm_memory_grow,
            .work_item_id,
            .work_group_size,
            .work_group_id,
            .dbg_stmt,
            .err_return_trace,
            .save_err_return_trace_index,
            .repeat,
            => {},
        }
    }
    return true;
}

fn checkRef(ref: Air.Inst.Ref, zcu: *Zcu) bool {
    const ip_index = ref.toInterned() orelse {
        // This operand refers back to a previous instruction.
        // We have already checked that instruction's type.
        // So, there's no need to check this operand's type.
        return true;
    };
    return checkVal(Value.fromInterned(ip_index), zcu);
}

pub fn checkVal(val: Value, zcu: *Zcu) bool {
    const ty = val.typeOf(zcu);
    if (!checkType(ty, zcu)) return false;
    if (ty.toIntern() == .type_type and !checkType(val.toType(), zcu)) return false;
    // Check for lazy values
    switch (zcu.intern_pool.indexToKey(val.toIntern())) {
        .int => |int| switch (int.storage) {
            .u64, .i64, .big_int => return true,
            .lazy_align, .lazy_size => |ty_index| {
                return checkType(Type.fromInterned(ty_index), zcu);
            },
        },
        else => return true,
    }
}

pub fn checkType(ty: Type, zcu: *Zcu) bool {
    const ip = &zcu.intern_pool;
    return switch (ty.zigTypeTagOrPoison(zcu) catch |err| switch (err) {
        error.GenericPoison => return true,
    }) {
        .type,
        .void,
        .bool,
        .noreturn,
        .int,
        .float,
        .error_set,
        .@"enum",
        .@"opaque",
        .vector,
        // These types can appear due to some dummy instructions Sema introduces and expects to be omitted by Liveness.
        // It's a little silly -- but fine, we'll return `true`.
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .enum_literal,
        => true,

        .frame,
        .@"anyframe",
        => @panic("TODO Air.types_resolved.checkType async frames"),

        .optional => checkType(ty.childType(zcu), zcu),
        .error_union => checkType(ty.errorUnionPayload(zcu), zcu),
        .pointer => checkType(ty.childType(zcu), zcu),
        .array => checkType(ty.childType(zcu), zcu),

        .@"fn" => {
            const info = zcu.typeToFunc(ty).?;
            for (0..info.param_types.len) |i| {
                const param_ty = info.param_types.get(ip)[i];
                if (!checkType(Type.fromInterned(param_ty), zcu)) return false;
            }
            return checkType(Type.fromInterned(info.return_type), zcu);
        },
        .@"struct" => switch (ip.indexToKey(ty.toIntern())) {
            .struct_type => {
                const struct_obj = zcu.typeToStruct(ty).?;
                return switch (struct_obj.layout) {
                    .@"packed" => struct_obj.backingIntTypeUnordered(ip) != .none,
                    .auto, .@"extern" => struct_obj.flagsUnordered(ip).fully_resolved,
                };
            },
            .anon_struct_type => |tuple| {
                for (0..tuple.types.len) |i| {
                    const field_is_comptime = tuple.values.get(ip)[i] != .none;
                    if (field_is_comptime) continue;
                    const field_ty = tuple.types.get(ip)[i];
                    if (!checkType(Type.fromInterned(field_ty), zcu)) return false;
                }
                return true;
            },
            else => unreachable,
        },
        .@"union" => return zcu.typeToUnion(ty).?.flagsUnordered(ip).status == .fully_resolved,
    };
}
