pt: Zcu.PerThread,
air_instructions: std.MultiArrayList(Air.Inst),
air_extra: std.ArrayListUnmanaged(u32),
features: *const Features,

pub const Feature = enum {
    scalarize_add,
    scalarize_add_safe,
    scalarize_add_optimized,
    scalarize_add_wrap,
    scalarize_add_sat,
    scalarize_sub,
    scalarize_sub_safe,
    scalarize_sub_optimized,
    scalarize_sub_wrap,
    scalarize_sub_sat,
    scalarize_mul,
    scalarize_mul_safe,
    scalarize_mul_optimized,
    scalarize_mul_wrap,
    scalarize_mul_sat,
    scalarize_div_float,
    scalarize_div_float_optimized,
    scalarize_div_trunc,
    scalarize_div_trunc_optimized,
    scalarize_div_floor,
    scalarize_div_floor_optimized,
    scalarize_div_exact,
    scalarize_div_exact_optimized,
    scalarize_rem,
    scalarize_rem_optimized,
    scalarize_mod,
    scalarize_mod_optimized,
    scalarize_max,
    scalarize_min,
    scalarize_bit_and,
    scalarize_bit_or,
    scalarize_shr,
    scalarize_shr_exact,
    scalarize_shl,
    scalarize_shl_exact,
    scalarize_shl_sat,
    scalarize_xor,
    scalarize_not,
    scalarize_bitcast,
    scalarize_clz,
    scalarize_ctz,
    scalarize_popcount,
    scalarize_byte_swap,
    scalarize_bit_reverse,
    scalarize_sqrt,
    scalarize_sin,
    scalarize_cos,
    scalarize_tan,
    scalarize_exp,
    scalarize_exp2,
    scalarize_log,
    scalarize_log2,
    scalarize_log10,
    scalarize_abs,
    scalarize_floor,
    scalarize_ceil,
    scalarize_round,
    scalarize_trunc_float,
    scalarize_neg,
    scalarize_neg_optimized,
    scalarize_cmp_vector,
    scalarize_cmp_vector_optimized,
    scalarize_fptrunc,
    scalarize_fpext,
    scalarize_intcast,
    scalarize_intcast_safe,
    scalarize_trunc,
    scalarize_int_from_float,
    scalarize_int_from_float_optimized,
    scalarize_float_from_int,
    scalarize_mul_add,

    /// Legalize (shift lhs, (splat rhs)) -> (shift lhs, rhs)
    unsplat_shift_rhs,
    /// Legalize reduce of a one element vector to a bitcast
    reduce_one_elem_to_bitcast,

    fn scalarize(tag: Air.Inst.Tag) Feature {
        return switch (tag) {
            else => unreachable,
            .add => .scalarize_add,
            .add_safe => .scalarize_add_safe,
            .add_optimized => .scalarize_add_optimized,
            .add_wrap => .scalarize_add_wrap,
            .add_sat => .scalarize_add_sat,
            .sub => .scalarize_sub,
            .sub_safe => .scalarize_sub_safe,
            .sub_optimized => .scalarize_sub_optimized,
            .sub_wrap => .scalarize_sub_wrap,
            .sub_sat => .scalarize_sub_sat,
            .mul => .scalarize_mul,
            .mul_safe => .scalarize_mul_safe,
            .mul_optimized => .scalarize_mul_optimized,
            .mul_wrap => .scalarize_mul_wrap,
            .mul_sat => .scalarize_mul_sat,
            .div_float => .scalarize_div_float,
            .div_float_optimized => .scalarize_div_float_optimized,
            .div_trunc => .scalarize_div_trunc,
            .div_trunc_optimized => .scalarize_div_trunc_optimized,
            .div_floor => .scalarize_div_floor,
            .div_floor_optimized => .scalarize_div_floor_optimized,
            .div_exact => .scalarize_div_exact,
            .div_exact_optimized => .scalarize_div_exact_optimized,
            .rem => .scalarize_rem,
            .rem_optimized => .scalarize_rem_optimized,
            .mod => .scalarize_mod,
            .mod_optimized => .scalarize_mod_optimized,
            .max => .scalarize_max,
            .min => .scalarize_min,
            .bit_and => .scalarize_bit_and,
            .bit_or => .scalarize_bit_or,
            .shr => .scalarize_shr,
            .shr_exact => .scalarize_shr_exact,
            .shl => .scalarize_shl,
            .shl_exact => .scalarize_shl_exact,
            .shl_sat => .scalarize_shl_sat,
            .xor => .scalarize_xor,
            .not => .scalarize_not,
            .bitcast => .scalarize_bitcast,
            .clz => .scalarize_clz,
            .ctz => .scalarize_ctz,
            .popcount => .scalarize_popcount,
            .byte_swap => .scalarize_byte_swap,
            .bit_reverse => .scalarize_bit_reverse,
            .sqrt => .scalarize_sqrt,
            .sin => .scalarize_sin,
            .cos => .scalarize_cos,
            .tan => .scalarize_tan,
            .exp => .scalarize_exp,
            .exp2 => .scalarize_exp2,
            .log => .scalarize_log,
            .log2 => .scalarize_log2,
            .log10 => .scalarize_log10,
            .abs => .scalarize_abs,
            .floor => .scalarize_floor,
            .ceil => .scalarize_ceil,
            .round => .scalarize_round,
            .trunc_float => .scalarize_trunc_float,
            .neg => .scalarize_neg,
            .neg_optimized => .scalarize_neg_optimized,
            .cmp_vector => .scalarize_cmp_vector,
            .cmp_vector_optimized => .scalarize_cmp_vector_optimized,
            .fptrunc => .scalarize_fptrunc,
            .fpext => .scalarize_fpext,
            .intcast => .scalarize_intcast,
            .intcast_safe => .scalarize_intcast_safe,
            .trunc => .scalarize_trunc,
            .int_from_float => .scalarize_int_from_float,
            .int_from_float_optimized => .scalarize_int_from_float_optimized,
            .float_from_int => .scalarize_float_from_int,
            .mul_add => .scalarize_mul_add,
        };
    }
};

pub const Features = std.enums.EnumSet(Feature);

pub const Error = std.mem.Allocator.Error;

pub fn legalize(air: *Air, pt: Zcu.PerThread, features: *const Features) Error!void {
    dev.check(.legalize);
    assert(!features.bits.eql(.initEmpty())); // backend asked to run legalize, but no features were enabled
    var l: Legalize = .{
        .pt = pt,
        .air_instructions = air.instructions.toMultiArrayList(),
        .air_extra = air.extra,
        .features = features,
    };
    defer air.* = l.getTmpAir();
    const main_extra = l.extraData(Air.Block, l.air_extra.items[@intFromEnum(Air.ExtraIndex.main_block)]);
    try l.legalizeBody(main_extra.end, main_extra.data.body_len);
}

fn getTmpAir(l: *const Legalize) Air {
    return .{
        .instructions = l.air_instructions.slice(),
        .extra = l.air_extra,
    };
}

fn typeOf(l: *const Legalize, ref: Air.Inst.Ref) Type {
    return l.getTmpAir().typeOf(ref, &l.pt.zcu.intern_pool);
}

fn typeOfIndex(l: *const Legalize, inst: Air.Inst.Index) Type {
    return l.getTmpAir().typeOfIndex(inst, &l.pt.zcu.intern_pool);
}

fn extraData(l: *const Legalize, comptime T: type, index: usize) @TypeOf(Air.extraData(undefined, T, undefined)) {
    return l.getTmpAir().extraData(T, index);
}

fn legalizeBody(l: *Legalize, body_start: usize, body_len: usize) Error!void {
    const zcu = l.pt.zcu;
    const ip = &zcu.intern_pool;
    for (0..body_len) |body_index| {
        const inst: Air.Inst.Index = @enumFromInt(l.air_extra.items[body_start + body_index]);
        inst: switch (l.air_instructions.items(.tag)[@intFromEnum(inst)]) {
            .arg,
            => {},
            inline .add,
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
            .xor,
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .ptr_add,
            .ptr_sub,
            .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            .alloc,
            => {},
            .inferred_alloc,
            .inferred_alloc_comptime,
            => unreachable,
            .ret_ptr,
            .assembly,
            => {},
            inline .shr,
            .shr_exact,
            .shl,
            .shl_exact,
            .shl_sat,
            => |air_tag| done: {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (!l.typeOf(bin_op.rhs).isVector(zcu)) break :done;
                if (l.features.contains(.unsplat_shift_rhs)) {
                    if (bin_op.rhs.toInterned()) |rhs_ip_index| switch (ip.indexToKey(rhs_ip_index)) {
                        else => {},
                        .aggregate => |aggregate| switch (aggregate.storage) {
                            else => {},
                            .repeated_elem => |splat| continue :inst l.replaceInst(inst, air_tag, .{ .bin_op = .{
                                .lhs = bin_op.lhs,
                                .rhs = Air.internedToRef(splat),
                            } }),
                        },
                    } else {
                        const rhs_inst = bin_op.rhs.toIndex().?;
                        switch (l.air_instructions.items(.tag)[@intFromEnum(rhs_inst)]) {
                            else => {},
                            .splat => continue :inst l.replaceInst(inst, air_tag, .{ .bin_op = .{
                                .lhs = bin_op.lhs,
                                .rhs = l.air_instructions.items(.data)[@intFromEnum(rhs_inst)].ty_op.operand,
                            } }),
                        }
                    }
                }
                if (l.features.contains(comptime .scalarize(air_tag))) continue :inst try l.scalarize(inst, .bin_op);
            },
            inline .not,
            .clz,
            .ctz,
            .popcount,
            .byte_swap,
            .bit_reverse,
            .abs,
            .fptrunc,
            .fpext,
            .intcast,
            .intcast_safe,
            .trunc,
            .int_from_float,
            .int_from_float_optimized,
            .float_from_int,
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
            },
            inline .bitcast,
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                const to_ty = ty_op.ty.toType();
                const from_ty = l.typeOf(ty_op.operand);
                if (to_ty.isVector(zcu) and from_ty.isVector(zcu) and to_ty.vectorLen(zcu) == from_ty.vectorLen(zcu))
                    continue :inst try l.scalarize(inst, .ty_op);
            },
            .block,
            .loop,
            => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.Block, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .repeat,
            .br,
            .trap,
            .breakpoint,
            .ret_addr,
            .frame_addr,
            .call,
            .call_always_tail,
            .call_never_tail,
            .call_never_inline,
            => {},
            inline .sqrt,
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
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const un_op = l.air_instructions.items(.data)[@intFromEnum(inst)].un_op;
                if (l.typeOf(un_op).isVector(zcu)) continue :inst try l.scalarize(inst, .un_op);
            },
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
            => {},
            inline .cmp_vector,
            .cmp_vector_optimized,
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                if (ty_pl.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_pl_vector_cmp);
            },
            .cond_br,
            => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.CondBr, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.then_body_len);
                try l.legalizeBody(extra.end + extra.data.then_body_len, extra.data.else_body_len);
            },
            .switch_br,
            .loop_switch_br,
            => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.SwitchBr, pl_op.payload);
                const hint_bag_count = std.math.divCeil(usize, extra.data.cases_len + 1, 10) catch unreachable;
                var extra_index = extra.end + hint_bag_count;
                for (0..extra.data.cases_len) |_| {
                    const case_extra = l.extraData(Air.SwitchBr.Case, extra_index);
                    const case_body_start = case_extra.end + case_extra.data.items_len + case_extra.data.ranges_len * 2;
                    try l.legalizeBody(case_body_start, case_extra.data.body_len);
                    extra_index = case_body_start + case_extra.data.body_len;
                }
                try l.legalizeBody(extra_index, extra.data.else_body_len);
            },
            .switch_dispatch,
            => {},
            .@"try",
            .try_cold,
            => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.Try, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .try_ptr,
            .try_ptr_cold,
            => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.TryPtr, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .dbg_stmt,
            .dbg_empty_stmt,
            => {},
            .dbg_inline_block,
            => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.DbgInlineBlock, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            .is_null,
            .is_non_null,
            .is_null_ptr,
            .is_non_null_ptr,
            .is_err,
            .is_non_err,
            .is_err_ptr,
            .is_non_err_ptr,
            .bool_and,
            .bool_or,
            .load,
            .ret,
            .ret_safe,
            .ret_load,
            .store,
            .store_safe,
            .unreach,
            => {},
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
            .struct_field_ptr,
            .struct_field_ptr_index_0,
            .struct_field_ptr_index_1,
            .struct_field_ptr_index_2,
            .struct_field_ptr_index_3,
            .struct_field_val,
            .set_union_tag,
            .get_union_tag,
            .slice,
            .slice_len,
            .slice_ptr,
            .ptr_slice_len_ptr,
            .ptr_slice_ptr_ptr,
            .array_elem_val,
            .slice_elem_val,
            .slice_elem_ptr,
            .ptr_elem_val,
            .ptr_elem_ptr,
            .array_to_slice,
            => {},
            .reduce,
            .reduce_optimized,
            => if (l.features.contains(.reduce_one_elem_to_bitcast)) done: {
                const reduce = l.air_instructions.items(.data)[@intFromEnum(inst)].reduce;
                const vector_ty = l.typeOf(reduce.operand);
                switch (vector_ty.vectorLen(zcu)) {
                    0 => unreachable,
                    1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                        .ty = Air.internedToRef(vector_ty.scalarType(zcu).toIntern()),
                        .operand = reduce.operand,
                    } }),
                    else => break :done,
                }
            },
            .splat,
            .shuffle,
            .select,
            .memset,
            .memset_safe,
            .memcpy,
            .memmove,
            .cmpxchg_weak,
            .cmpxchg_strong,
            .atomic_load,
            .atomic_store_unordered,
            .atomic_store_monotonic,
            .atomic_store_release,
            .atomic_store_seq_cst,
            .atomic_rmw,
            .is_named_enum_value,
            .tag_name,
            .error_name,
            .error_set_has_value,
            .aggregate_init,
            .union_init,
            .prefetch,
            => {},
            inline .mul_add,
            => |air_tag| if (l.features.contains(comptime .scalarize(air_tag))) {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                if (l.typeOf(pl_op.operand).isVector(zcu)) continue :inst try l.scalarize(inst, .pl_op_bin);
            },
            .field_parent_ptr,
            .wasm_memory_size,
            .wasm_memory_grow,
            .cmp_lt_errors_len,
            .err_return_trace,
            .set_err_return_trace,
            .addrspace_cast,
            .save_err_return_trace_index,
            .vector_store_elem,
            .tlv_dllimport_ptr,
            .c_va_arg,
            .c_va_copy,
            .c_va_end,
            .c_va_start,
            .work_item_id,
            .work_group_size,
            .work_group_id,
            => {},
        }
    }
}

const ScalarizeDataTag = enum { un_op, ty_op, bin_op, ty_pl_vector_cmp, pl_op_bin };
inline fn scalarize(l: *Legalize, orig_inst: Air.Inst.Index, comptime data_tag: ScalarizeDataTag) Error!Air.Inst.Tag {
    return l.replaceInst(orig_inst, .block, try l.scalarizeBlockPayload(orig_inst, data_tag));
}
fn scalarizeBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, comptime data_tag: ScalarizeDataTag) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const res_ty = l.typeOfIndex(orig_inst);
    const arity = switch (data_tag) {
        .un_op, .ty_op => 1,
        .bin_op, .ty_pl_vector_cmp => 2,
        .pl_op_bin => 3,
    };
    const expected_instructions_len = l.air_instructions.len + (6 + arity + 8);
    try l.air_instructions.ensureTotalCapacity(gpa, expected_instructions_len);

    var res_block: Block(4) = .empty;
    {
        const res_alloc_inst = res_block.add(l.addInstAssumeCapacity(.{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
        }));
        const index_alloc_inst = res_block.add(l.addInstAssumeCapacity(.{
            .tag = .alloc,
            .data = .{ .ty = .ptr_usize },
        }));
        _ = res_block.add(l.addInstAssumeCapacity(.{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = index_alloc_inst.toRef(),
                .rhs = .zero_usize,
            } },
        }));

        const loop_inst: Air.Inst.Index = @enumFromInt(l.air_instructions.len + (3 + arity + 7));
        var loop_block: Block(3 + arity + 2) = .empty;
        {
            const cur_index_inst = loop_block.add(l.addInstAssumeCapacity(.{
                .tag = .load,
                .data = .{ .ty_op = .{
                    .ty = .usize_type,
                    .operand = index_alloc_inst.toRef(),
                } },
            }));
            _ = loop_block.add(l.addInstAssumeCapacity(.{
                .tag = .vector_store_elem,
                .data = .{ .vector_store_elem = .{
                    .vector_ptr = res_alloc_inst.toRef(),
                    .payload = try l.addExtra(Air.Bin, .{
                        .lhs = cur_index_inst.toRef(),
                        .rhs = loop_block.add(l.addInstAssumeCapacity(res_elem: switch (data_tag) {
                            .un_op => .{
                                .tag = orig.tag,
                                .data = .{ .un_op = loop_block.add(l.addInstAssumeCapacity(.{
                                    .tag = .array_elem_val,
                                    .data = .{ .bin_op = .{
                                        .lhs = orig.data.un_op,
                                        .rhs = cur_index_inst.toRef(),
                                    } },
                                })).toRef() },
                            },
                            .ty_op => .{
                                .tag = orig.tag,
                                .data = .{ .ty_op = .{
                                    .ty = Air.internedToRef(orig.data.ty_op.ty.toType().scalarType(zcu).toIntern()),
                                    .operand = loop_block.add(l.addInstAssumeCapacity(.{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.ty_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    })).toRef(),
                                } },
                            },
                            .bin_op => .{
                                .tag = orig.tag,
                                .data = .{ .bin_op = .{
                                    .lhs = loop_block.add(l.addInstAssumeCapacity(.{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.bin_op.lhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    })).toRef(),
                                    .rhs = loop_block.add(l.addInstAssumeCapacity(.{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.bin_op.rhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    })).toRef(),
                                } },
                            },
                            .ty_pl_vector_cmp => {
                                const extra = l.extraData(Air.VectorCmp, orig.data.ty_pl.payload).data;
                                break :res_elem .{
                                    .tag = switch (orig.tag) {
                                        else => unreachable,
                                        .cmp_vector => switch (extra.compareOperator()) {
                                            .lt => .cmp_lt,
                                            .lte => .cmp_lte,
                                            .eq => .cmp_eq,
                                            .gte => .cmp_gte,
                                            .gt => .cmp_gt,
                                            .neq => .cmp_neq,
                                        },
                                        .cmp_vector_optimized => switch (extra.compareOperator()) {
                                            .lt => .cmp_lt_optimized,
                                            .lte => .cmp_lte_optimized,
                                            .eq => .cmp_eq_optimized,
                                            .gte => .cmp_gte_optimized,
                                            .gt => .cmp_gt_optimized,
                                            .neq => .cmp_neq_optimized,
                                        },
                                    },
                                    .data = .{ .bin_op = .{
                                        .lhs = loop_block.add(l.addInstAssumeCapacity(.{
                                            .tag = .array_elem_val,
                                            .data = .{ .bin_op = .{
                                                .lhs = extra.lhs,
                                                .rhs = cur_index_inst.toRef(),
                                            } },
                                        })).toRef(),
                                        .rhs = loop_block.add(l.addInstAssumeCapacity(.{
                                            .tag = .array_elem_val,
                                            .data = .{ .bin_op = .{
                                                .lhs = extra.rhs,
                                                .rhs = cur_index_inst.toRef(),
                                            } },
                                        })).toRef(),
                                    } },
                                };
                            },
                            .pl_op_bin => {
                                const extra = l.extraData(Air.Bin, orig.data.pl_op.payload).data;
                                break :res_elem .{
                                    .tag = orig.tag,
                                    .data = .{ .pl_op = .{
                                        .payload = try l.addExtra(Air.Bin, .{
                                            .lhs = loop_block.add(l.addInstAssumeCapacity(.{
                                                .tag = .array_elem_val,
                                                .data = .{ .bin_op = .{
                                                    .lhs = extra.lhs,
                                                    .rhs = cur_index_inst.toRef(),
                                                } },
                                            })).toRef(),
                                            .rhs = loop_block.add(l.addInstAssumeCapacity(.{
                                                .tag = .array_elem_val,
                                                .data = .{ .bin_op = .{
                                                    .lhs = extra.rhs,
                                                    .rhs = cur_index_inst.toRef(),
                                                } },
                                            })).toRef(),
                                        }),
                                        .operand = loop_block.add(l.addInstAssumeCapacity(.{
                                            .tag = .array_elem_val,
                                            .data = .{ .bin_op = .{
                                                .lhs = orig.data.pl_op.operand,
                                                .rhs = cur_index_inst.toRef(),
                                            } },
                                        })).toRef(),
                                    } },
                                };
                            },
                        })).toRef(),
                    }),
                } },
            }));
            const not_done_inst = loop_block.add(l.addInstAssumeCapacity(.{
                .tag = .cmp_lt,
                .data = .{ .bin_op = .{
                    .lhs = cur_index_inst.toRef(),
                    .rhs = try pt.intRef(.usize, res_ty.vectorLen(zcu) - 1),
                } },
            }));

            var not_done_block: Block(3) = .empty;
            {
                _ = not_done_block.add(l.addInstAssumeCapacity(.{
                    .tag = .store,
                    .data = .{ .bin_op = .{
                        .lhs = index_alloc_inst.toRef(),
                        .rhs = not_done_block.add(l.addInstAssumeCapacity(.{
                            .tag = .add,
                            .data = .{ .bin_op = .{
                                .lhs = cur_index_inst.toRef(),
                                .rhs = .one_usize,
                            } },
                        })).toRef(),
                    } },
                }));
                _ = not_done_block.add(l.addInstAssumeCapacity(.{
                    .tag = .repeat,
                    .data = .{ .repeat = .{ .loop_inst = loop_inst } },
                }));
            }
            var done_block: Block(2) = .empty;
            {
                _ = done_block.add(l.addInstAssumeCapacity(.{
                    .tag = .br,
                    .data = .{ .br = .{
                        .block_inst = orig_inst,
                        .operand = done_block.add(l.addInstAssumeCapacity(.{
                            .tag = .load,
                            .data = .{ .ty_op = .{
                                .ty = Air.internedToRef(res_ty.toIntern()),
                                .operand = res_alloc_inst.toRef(),
                            } },
                        })).toRef(),
                    } },
                }));
            }
            _ = loop_block.add(l.addInstAssumeCapacity(.{
                .tag = .cond_br,
                .data = .{ .pl_op = .{
                    .operand = not_done_inst.toRef(),
                    .payload = try l.addCondBrBodies(not_done_block.body(), done_block.body()),
                } },
            }));
        }
        assert(loop_inst == res_block.add(l.addInstAssumeCapacity(.{
            .tag = .loop,
            .data = .{ .ty_pl = .{
                .ty = .noreturn_type,
                .payload = try l.addBlockBody(loop_block.body()),
            } },
        })));
    }
    assert(l.air_instructions.len == expected_instructions_len);
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}

fn Block(comptime capacity: usize) type {
    return struct {
        instructions: [capacity]Air.Inst.Index,
        len: usize,

        const empty: @This() = .{
            .instructions = undefined,
            .len = 0,
        };

        fn add(b: *@This(), inst: Air.Inst.Index) Air.Inst.Index {
            b.instructions[b.len] = inst;
            b.len += 1;
            return inst;
        }

        fn body(b: *const @This()) []const Air.Inst.Index {
            assert(b.len == b.instructions.len);
            return &b.instructions;
        }
    };
}

fn addInstAssumeCapacity(l: *Legalize, inst: Air.Inst) Air.Inst.Index {
    defer l.air_instructions.appendAssumeCapacity(inst);
    return @enumFromInt(l.air_instructions.len);
}

fn addExtra(l: *Legalize, comptime Extra: type, extra: Extra) Error!u32 {
    const extra_fields = @typeInfo(Extra).@"struct".fields;
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, extra_fields.len);
    defer inline for (extra_fields) |field| l.air_extra.appendAssumeCapacity(switch (field.type) {
        u32 => @field(extra, field.name),
        Air.Inst.Ref => @intFromEnum(@field(extra, field.name)),
        else => @compileError(@typeName(field.type)),
    });
    return @intCast(l.air_extra.items.len);
}

fn addBlockBody(l: *Legalize, body: []const Air.Inst.Index) Error!u32 {
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, 1 + body.len);
    defer {
        l.air_extra.appendAssumeCapacity(@intCast(body.len));
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(body));
    }
    return @intCast(l.air_extra.items.len);
}

fn addCondBrBodies(l: *Legalize, then_body: []const Air.Inst.Index, else_body: []const Air.Inst.Index) Error!u32 {
    try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, 3 + then_body.len + else_body.len);
    defer {
        l.air_extra.appendSliceAssumeCapacity(&.{
            @intCast(then_body.len),
            @intCast(else_body.len),
            @bitCast(Air.CondBr.BranchHints{
                .true = .none,
                .false = .none,
                .then_cov = .none,
                .else_cov = .none,
            }),
        });
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(then_body));
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(else_body));
    }
    return @intCast(l.air_extra.items.len);
}

// inline to propagate comptime `tag`s
inline fn replaceInst(l: *Legalize, inst: Air.Inst.Index, tag: Air.Inst.Tag, data: Air.Inst.Data) Air.Inst.Tag {
    const orig_ty = if (std.debug.runtime_safety) l.typeOfIndex(inst) else {};
    l.air_instructions.set(@intFromEnum(inst), .{ .tag = tag, .data = data });
    if (std.debug.runtime_safety) assert(l.typeOfIndex(inst).toIntern() == orig_ty.toIntern());
    return tag;
}

const Air = @import("../Air.zig");
const assert = std.debug.assert;
const dev = @import("../dev.zig");
const Legalize = @This();
const std = @import("std");
const Type = @import("../Type.zig");
const Zcu = @import("../Zcu.zig");
