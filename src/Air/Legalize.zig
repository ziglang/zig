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
    scalarize_select,
    scalarize_mul_add,

    /// Legalize (shift lhs, (splat rhs)) -> (shift lhs, rhs)
    unsplat_shift_rhs,
    /// Legalize reduce of a one element vector to a bitcast
    reduce_one_elem_to_bitcast,

    /// Replace `intcast_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_intcast_safe`.
    expand_intcast_safe,
    /// Replace `add_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_add_safe`.
    expand_add_safe,
    /// Replace `sub_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_sub_safe`.
    expand_sub_safe,
    /// Replace `mul_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_mul_safe`.
    expand_mul_safe,

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
            .select => .scalarize_select,
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
            .add_optimized,
            .add_wrap,
            .add_sat,
            .sub,
            .sub_optimized,
            .sub_wrap,
            .sub_sat,
            .mul,
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
            .add_safe => if (l.features.contains(.expand_add_safe)) {
                assert(!l.features.contains(.scalarize_add_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .add_with_overflow));
            } else if (l.features.contains(.scalarize_add_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .sub_safe => if (l.features.contains(.expand_sub_safe)) {
                assert(!l.features.contains(.scalarize_sub_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .sub_with_overflow));
            } else if (l.features.contains(.scalarize_sub_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .mul_safe => if (l.features.contains(.expand_mul_safe)) {
                assert(!l.features.contains(.scalarize_mul_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .mul_with_overflow));
            } else if (l.features.contains(.scalarize_mul_safe)) {
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
            .intcast_safe => if (l.features.contains(.expand_intcast_safe)) {
                assert(!l.features.contains(.scalarize_intcast_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeIntcastBlockPayload(inst));
            } else if (l.features.contains(.scalarize_intcast_safe)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
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
            .shuffle_one,
            .shuffle_two,
            => {},
            .select,
            => if (l.features.contains(.scalarize_select)) continue :inst try l.scalarize(inst, .select_pl_op_bin),
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

const ScalarizeDataTag = enum { un_op, ty_op, bin_op, ty_pl_vector_cmp, pl_op_bin, select_pl_op_bin };
inline fn scalarize(l: *Legalize, orig_inst: Air.Inst.Index, comptime data_tag: ScalarizeDataTag) Error!Air.Inst.Tag {
    return l.replaceInst(orig_inst, .block, try l.scalarizeBlockPayload(orig_inst, data_tag));
}
fn scalarizeBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, comptime data_tag: ScalarizeDataTag) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const res_ty = l.typeOfIndex(orig_inst);

    var inst_buf: [
        5 + switch (data_tag) {
            .un_op, .ty_op => 1,
            .bin_op, .ty_pl_vector_cmp => 2,
            .pl_op_bin => 3,
            .select_pl_op_bin => 6,
        } + 9
    ]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const res_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
        });
        const index_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = .ptr_usize },
        });
        _ = res_block.add(l, .{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = index_alloc_inst.toRef(),
                .rhs = .zero_usize,
            } },
        });

        var loop: Loop = .init(l, &res_block);
        loop.block = .init(res_block.stealRemainingCapacity());
        {
            const cur_index_inst = loop.block.add(l, .{
                .tag = .load,
                .data = .{ .ty_op = .{
                    .ty = .usize_type,
                    .operand = index_alloc_inst.toRef(),
                } },
            });
            _ = loop.block.add(l, .{
                .tag = .vector_store_elem,
                .data = .{ .vector_store_elem = .{
                    .vector_ptr = res_alloc_inst.toRef(),
                    .payload = try l.addExtra(Air.Bin, .{
                        .lhs = cur_index_inst.toRef(),
                        .rhs = res_elem: switch (data_tag) {
                            .un_op => loop.block.add(l, .{
                                .tag = orig.tag,
                                .data = .{ .un_op = loop.block.add(l, .{
                                    .tag = .array_elem_val,
                                    .data = .{ .bin_op = .{
                                        .lhs = orig.data.un_op,
                                        .rhs = cur_index_inst.toRef(),
                                    } },
                                }).toRef() },
                            }),
                            .ty_op => loop.block.add(l, .{
                                .tag = orig.tag,
                                .data = .{ .ty_op = .{
                                    .ty = Air.internedToRef(orig.data.ty_op.ty.toType().scalarType(zcu).toIntern()),
                                    .operand = loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.ty_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                } },
                            }),
                            .bin_op => loop.block.add(l, .{
                                .tag = orig.tag,
                                .data = .{ .bin_op = .{
                                    .lhs = loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.bin_op.lhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                    .rhs = loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.bin_op.rhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                } },
                            }),
                            .ty_pl_vector_cmp => {
                                const extra = l.extraData(Air.VectorCmp, orig.data.ty_pl.payload).data;
                                break :res_elem try loop.block.addCmp(
                                    l,
                                    extra.compareOperator(),
                                    loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = extra.lhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                    loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = extra.rhs,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                    .{ .optimized = switch (orig.tag) {
                                        else => unreachable,
                                        .cmp_vector => false,
                                        .cmp_vector_optimized => true,
                                    } },
                                );
                            },
                            .pl_op_bin => {
                                const extra = l.extraData(Air.Bin, orig.data.pl_op.payload).data;
                                break :res_elem loop.block.add(l, .{
                                    .tag = orig.tag,
                                    .data = .{ .pl_op = .{
                                        .payload = try l.addExtra(Air.Bin, .{
                                            .lhs = loop.block.add(l, .{
                                                .tag = .array_elem_val,
                                                .data = .{ .bin_op = .{
                                                    .lhs = extra.lhs,
                                                    .rhs = cur_index_inst.toRef(),
                                                } },
                                            }).toRef(),
                                            .rhs = loop.block.add(l, .{
                                                .tag = .array_elem_val,
                                                .data = .{ .bin_op = .{
                                                    .lhs = extra.rhs,
                                                    .rhs = cur_index_inst.toRef(),
                                                } },
                                            }).toRef(),
                                        }),
                                        .operand = loop.block.add(l, .{
                                            .tag = .array_elem_val,
                                            .data = .{ .bin_op = .{
                                                .lhs = orig.data.pl_op.operand,
                                                .rhs = cur_index_inst.toRef(),
                                            } },
                                        }).toRef(),
                                    } },
                                });
                            },
                            .select_pl_op_bin => {
                                const extra = l.extraData(Air.Bin, orig.data.pl_op.payload).data;
                                var res_elem: Result = .init(l, l.typeOf(extra.lhs).scalarType(zcu), &loop.block);
                                res_elem.block = .init(loop.block.stealCapacity(6));
                                {
                                    var select_cond_br: CondBr = .init(l, res_elem.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.pl_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(), &res_elem.block, .{});
                                    select_cond_br.then_block = .init(res_elem.block.stealRemainingCapacity());
                                    {
                                        _ = select_cond_br.then_block.add(l, .{
                                            .tag = .br,
                                            .data = .{ .br = .{
                                                .block_inst = res_elem.inst,
                                                .operand = select_cond_br.then_block.add(l, .{
                                                    .tag = .array_elem_val,
                                                    .data = .{ .bin_op = .{
                                                        .lhs = extra.lhs,
                                                        .rhs = cur_index_inst.toRef(),
                                                    } },
                                                }).toRef(),
                                            } },
                                        });
                                    }
                                    select_cond_br.else_block = .init(select_cond_br.then_block.stealRemainingCapacity());
                                    {
                                        _ = select_cond_br.else_block.add(l, .{
                                            .tag = .br,
                                            .data = .{ .br = .{
                                                .block_inst = res_elem.inst,
                                                .operand = select_cond_br.else_block.add(l, .{
                                                    .tag = .array_elem_val,
                                                    .data = .{ .bin_op = .{
                                                        .lhs = extra.rhs,
                                                        .rhs = cur_index_inst.toRef(),
                                                    } },
                                                }).toRef(),
                                            } },
                                        });
                                    }
                                    try select_cond_br.finish(l);
                                }
                                try res_elem.finish(l);
                                break :res_elem res_elem.inst;
                            },
                        }.toRef(),
                    }),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, res_ty.vectorLen(zcu) - 1),
                .{},
            )).toRef(), &loop.block, .{});
            loop_cond_br.then_block = .init(loop.block.stealRemainingCapacity());
            {
                _ = loop_cond_br.then_block.add(l, .{
                    .tag = .store,
                    .data = .{ .bin_op = .{
                        .lhs = index_alloc_inst.toRef(),
                        .rhs = loop_cond_br.then_block.add(l, .{
                            .tag = .add,
                            .data = .{ .bin_op = .{
                                .lhs = cur_index_inst.toRef(),
                                .rhs = .one_usize,
                            } },
                        }).toRef(),
                    } },
                });
                _ = loop_cond_br.then_block.add(l, .{
                    .tag = .repeat,
                    .data = .{ .repeat = .{ .loop_inst = loop.inst } },
                });
            }
            loop_cond_br.else_block = .init(loop_cond_br.then_block.stealRemainingCapacity());
            {
                _ = loop_cond_br.else_block.add(l, .{
                    .tag = .br,
                    .data = .{ .br = .{
                        .block_inst = orig_inst,
                        .operand = loop_cond_br.else_block.add(l, .{
                            .tag = .load,
                            .data = .{ .ty_op = .{
                                .ty = Air.internedToRef(res_ty.toIntern()),
                                .operand = res_alloc_inst.toRef(),
                            } },
                        }).toRef(),
                    } },
                });
            }
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}

fn safeIntcastBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;

    const operand_ref = ty_op.operand;
    const operand_ty = l.typeOf(operand_ref);
    const dest_ty = ty_op.ty.toType();

    const is_vector = operand_ty.zigTypeTag(zcu) == .vector;
    const operand_scalar_ty = operand_ty.scalarType(zcu);
    const dest_scalar_ty = dest_ty.scalarType(zcu);

    assert(operand_scalar_ty.zigTypeTag(zcu) == .int);
    const dest_is_enum = switch (dest_scalar_ty.zigTypeTag(zcu)) {
        .int => false,
        .@"enum" => true,
        else => unreachable,
    };

    const operand_info = operand_scalar_ty.intInfo(zcu);
    const dest_info = dest_scalar_ty.intInfo(zcu);

    const have_min_check, const have_max_check = c: {
        const dest_pos_bits = dest_info.bits - @intFromBool(dest_info.signedness == .signed);
        const operand_pos_bits = operand_info.bits - @intFromBool(operand_info.signedness == .signed);
        const dest_allows_neg = dest_info.signedness == .signed and dest_info.bits > 0;
        const operand_allows_neg = operand_info.signedness == .signed and operand_info.bits > 0;
        break :c .{
            operand_allows_neg and (!dest_allows_neg or dest_info.bits < operand_info.bits),
            dest_pos_bits < operand_pos_bits,
        };
    };

    // The worst-case scenario in terms of total instructions and total condbrs is the case where
    // the result type is an exhaustive enum whose tag type is smaller than the operand type:
    //
    // %x = block({
    //   %1 = cmp_lt(%y, @min_allowed_int)
    //   %2 = cmp_gt(%y, @max_allowed_int)
    //   %3 = bool_or(%1, %2)
    //   %4 = cond_br(%3, {
    //     %5 = call(@panic.invalidEnumValue, [])
    //     %6 = unreach()
    //   }, {
    //     %7 = intcast(@res_ty, %y)
    //     %8 = is_named_enum_value(%7)
    //     %9 = cond_br(%8, {
    //       %10 = br(%x, %7)
    //     }, {
    //       %11 = call(@panic.invalidEnumValue, [])
    //       %12 = unreach()
    //     })
    //   })
    // })
    //
    // Note that vectors of enums don't exist -- the worst case for vectors is this:
    //
    // %x = block({
    //   %1 = cmp_lt(%y, @min_allowed_int)
    //   %2 = cmp_gt(%y, @max_allowed_int)
    //   %3 = bool_or(%1, %2)
    //   %4 = reduce(%3, .@"or")
    //   %5 = cond_br(%4, {
    //     %6 = call(@panic.invalidEnumValue, [])
    //     %7 = unreach()
    //   }, {
    //     %8 = intcast(@res_ty, %y)
    //     %9 = br(%x, %8)
    //   })
    // })

    var inst_buf: [12]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);
    var condbr_buf: [2]CondBr = undefined;
    var condbr_idx: usize = 0;

    var main_block: Block = .init(&inst_buf);
    var cur_block: *Block = &main_block;

    const panic_id: Zcu.SimplePanicId = if (dest_is_enum) .invalid_enum_value else .cast_truncated_data;

    if (have_min_check or have_max_check) {
        const dest_int_ty = if (dest_is_enum) dest_ty.intTagType(zcu) else dest_ty;
        const condbr = &condbr_buf[condbr_idx];
        condbr_idx += 1;
        const below_min_inst: Air.Inst.Index = if (have_min_check) inst: {
            const min_val_ref = Air.internedToRef((try dest_int_ty.minInt(pt, operand_ty)).toIntern());
            break :inst try cur_block.addCmp(l, .lt, operand_ref, min_val_ref, .{ .vector = is_vector });
        } else undefined;
        const above_max_inst: Air.Inst.Index = if (have_max_check) inst: {
            const max_val_ref = Air.internedToRef((try dest_int_ty.maxInt(pt, operand_ty)).toIntern());
            break :inst try cur_block.addCmp(l, .gt, operand_ref, max_val_ref, .{ .vector = is_vector });
        } else undefined;
        const out_of_range_inst: Air.Inst.Index = inst: {
            if (have_min_check and have_max_check) break :inst cur_block.add(l, .{
                .tag = .bool_or,
                .data = .{ .bin_op = .{
                    .lhs = below_min_inst.toRef(),
                    .rhs = above_max_inst.toRef(),
                } },
            });
            if (have_min_check) break :inst below_min_inst;
            if (have_max_check) break :inst above_max_inst;
            unreachable;
        };
        const scalar_out_of_range_inst: Air.Inst.Index = if (is_vector) cur_block.add(l, .{
            .tag = .reduce,
            .data = .{ .reduce = .{
                .operand = out_of_range_inst.toRef(),
                .operation = .Or,
            } },
        }) else out_of_range_inst;
        condbr.* = .init(l, scalar_out_of_range_inst.toRef(), cur_block, .{ .true = .cold });
        condbr.then_block = .init(cur_block.stealRemainingCapacity());
        try condbr.then_block.addPanic(l, panic_id);
        condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
        cur_block = &condbr.else_block;
    }

    // Now we know we're in-range, we can intcast:
    const cast_inst = cur_block.add(l, .{
        .tag = .intcast,
        .data = .{ .ty_op = .{
            .ty = Air.internedToRef(dest_ty.toIntern()),
            .operand = operand_ref,
        } },
    });
    // For ints we're already done, but for exhaustive enums we must check this is a valid tag.
    if (dest_is_enum and !dest_ty.isNonexhaustiveEnum(zcu) and zcu.backendSupportsFeature(.is_named_enum_value)) {
        assert(!is_vector); // vectors of enums don't exist
        // We are building this:
        //   %1 = is_named_enum_value(%cast_inst)
        //   %2 = cond_br(%1, {
        //     <new cursor>
        //   }, {
        //     <panic>
        //   })
        const is_named_inst = cur_block.add(l, .{
            .tag = .is_named_enum_value,
            .data = .{ .un_op = cast_inst.toRef() },
        });
        const condbr = &condbr_buf[condbr_idx];
        condbr_idx += 1;
        condbr.* = .init(l, is_named_inst.toRef(), cur_block, .{ .false = .cold });
        condbr.else_block = .init(cur_block.stealRemainingCapacity());
        try condbr.else_block.addPanic(l, panic_id);
        condbr.then_block = .init(condbr.else_block.stealRemainingCapacity());
        cur_block = &condbr.then_block;
    }
    // Finally, just `br` to our outer `block`.
    _ = cur_block.add(l, .{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = orig_inst,
            .operand = cast_inst.toRef(),
        } },
    });
    // We might not have used all of the instructions; that's intentional.
    _ = cur_block.stealRemainingCapacity();

    for (condbr_buf[0..condbr_idx]) |*condbr| try condbr.finish(l);
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(dest_ty.toIntern()),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}
fn safeArithmeticBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, overflow_op_tag: Air.Inst.Tag) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const bin_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].bin_op;

    const operand_ty = l.typeOf(bin_op.lhs);
    assert(l.typeOf(bin_op.rhs).toIntern() == operand_ty.toIntern());
    const is_vector = operand_ty.zigTypeTag(zcu) == .vector;

    const overflow_tuple_ty = try pt.overflowArithmeticTupleType(operand_ty);
    const overflow_bits_ty = overflow_tuple_ty.fieldType(1, zcu);

    // The worst-case scenario is a vector operand:
    //
    // %1 = add_with_overflow(%x, %y)
    // %2 = struct_field_val(%1, .@"1")
    // %3 = reduce(%2, .@"or")
    // %4 = bitcast(%3, @bool_type)
    // %5 = cond_br(%4, {
    //   %6 = call(@panic.integerOverflow, [])
    //   %7 = unreach()
    // }, {
    //   %8 = struct_field_val(%1, .@"0")
    //   %9 = br(%z, %8)
    // })
    var inst_buf: [9]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var main_block: Block = .init(&inst_buf);

    const overflow_op_inst = main_block.add(l, .{
        .tag = overflow_op_tag,
        .data = .{ .ty_pl = .{
            .ty = Air.internedToRef(overflow_tuple_ty.toIntern()),
            .payload = try l.addExtra(Air.Bin, .{
                .lhs = bin_op.lhs,
                .rhs = bin_op.rhs,
            }),
        } },
    });
    const overflow_bits_inst = main_block.add(l, .{
        .tag = .struct_field_val,
        .data = .{ .ty_pl = .{
            .ty = Air.internedToRef(overflow_bits_ty.toIntern()),
            .payload = try l.addExtra(Air.StructField, .{
                .struct_operand = overflow_op_inst.toRef(),
                .field_index = 1,
            }),
        } },
    });
    const any_overflow_bit_inst = if (is_vector) main_block.add(l, .{
        .tag = .reduce,
        .data = .{ .reduce = .{
            .operand = overflow_bits_inst.toRef(),
            .operation = .Or,
        } },
    }) else overflow_bits_inst;
    const any_overflow_inst = try main_block.addCmp(l, .eq, any_overflow_bit_inst.toRef(), .one_u1, .{});

    var condbr: CondBr = .init(l, any_overflow_inst.toRef(), &main_block, .{ .true = .cold });
    condbr.then_block = .init(main_block.stealRemainingCapacity());
    try condbr.then_block.addPanic(l, .integer_overflow);
    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());

    const result_inst = condbr.else_block.add(l, .{
        .tag = .struct_field_val,
        .data = .{ .ty_pl = .{
            .ty = Air.internedToRef(operand_ty.toIntern()),
            .payload = try l.addExtra(Air.StructField, .{
                .struct_operand = overflow_op_inst.toRef(),
                .field_index = 0,
            }),
        } },
    });
    _ = condbr.else_block.add(l, .{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = orig_inst,
            .operand = result_inst.toRef(),
        } },
    });
    // We might not have used all of the instructions; that's intentional.
    _ = condbr.else_block.stealRemainingCapacity();

    try condbr.finish(l);
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(operand_ty.toIntern()),
        .payload = try l.addBlockBody(main_block.body()),
    } };
}

const Block = struct {
    instructions: []Air.Inst.Index,
    len: usize,

    /// There are two common usages of the API:
    /// * `buf.len` is exactly the number of instructions which will be in this block
    /// * `buf.len` is no smaller than necessary, and `b.stealRemainingCapacity` will be used
    fn init(buf: []Air.Inst.Index) Block {
        return .{
            .instructions = buf,
            .len = 0,
        };
    }

    /// Like `Legalize.addInstAssumeCapacity`, but also appends the instruction to `b`.
    fn add(b: *Block, l: *Legalize, inst_data: Air.Inst) Air.Inst.Index {
        const inst = l.addInstAssumeCapacity(inst_data);
        b.instructions[b.len] = inst;
        b.len += 1;
        return inst;
    }

    /// Adds the code to call the panic handler `panic_id`. This is usually `.call` then `.unreach`,
    /// but if `Zcu.Feature.panic_fn` is unsupported, we lower to `.trap` instead.
    fn addPanic(b: *Block, l: *Legalize, panic_id: Zcu.SimplePanicId) Error!void {
        const zcu = l.pt.zcu;
        if (!zcu.backendSupportsFeature(.panic_fn)) {
            _ = b.add(l, .{
                .tag = .trap,
                .data = .{ .no_op = {} },
            });
            return;
        }
        const panic_fn_val = zcu.builtin_decl_values.get(panic_id.toBuiltin());
        _ = b.add(l, .{
            .tag = .call,
            .data = .{ .pl_op = .{
                .operand = Air.internedToRef(panic_fn_val),
                .payload = try l.addExtra(Air.Call, .{ .args_len = 0 }),
            } },
        });
        _ = b.add(l, .{
            .tag = .unreach,
            .data = .{ .no_op = {} },
        });
    }

    /// Adds a `cmp_*` instruction (including maybe `cmp_vector`) to `b`. This is a fairly thin wrapper
    /// around `add`, although it does compute the result type if `is_vector` (`@Vector(n, bool)`).
    fn addCmp(
        b: *Block,
        l: *Legalize,
        op: std.math.CompareOperator,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
        opts: struct { optimized: bool = false, vector: bool = false },
    ) Error!Air.Inst.Index {
        const pt = l.pt;
        if (opts.vector) {
            const bool_vec_ty = try pt.vectorType(.{
                .child = .bool_type,
                .len = l.typeOf(lhs).vectorLen(pt.zcu),
            });
            return b.add(l, .{
                .tag = if (opts.optimized) .cmp_vector_optimized else .cmp_vector,
                .data = .{ .ty_pl = .{
                    .ty = Air.internedToRef(bool_vec_ty.toIntern()),
                    .payload = try l.addExtra(Air.VectorCmp, .{
                        .lhs = lhs,
                        .rhs = rhs,
                        .op = Air.VectorCmp.encodeOp(op),
                    }),
                } },
            });
        }
        return b.add(l, .{
            .tag = switch (op) {
                .lt => if (opts.optimized) .cmp_lt_optimized else .cmp_lt,
                .lte => if (opts.optimized) .cmp_lte_optimized else .cmp_lte,
                .eq => if (opts.optimized) .cmp_eq_optimized else .cmp_eq,
                .gte => if (opts.optimized) .cmp_gte_optimized else .cmp_gte,
                .gt => if (opts.optimized) .cmp_gt_optimized else .cmp_gt,
                .neq => if (opts.optimized) .cmp_neq_optimized else .cmp_neq,
            },
            .data = .{ .bin_op = .{
                .lhs = lhs,
                .rhs = rhs,
            } },
        });
    }

    /// Returns the unused capacity of `b.instructions`, and shrinks `b.instructions` down to `b.len`.
    /// This is useful when you've provided a buffer big enough for all your instructions, but you are
    /// now starting a new block and some of them need to live there instead.
    fn stealRemainingCapacity(b: *Block) []Air.Inst.Index {
        return b.stealFrom(b.len);
    }

    /// Returns `len` elements taken from the unused capacity of `b.instructions`, and shrinks
    /// `b.instructions` down to not include them anymore.
    /// This is useful when you've provided a buffer big enough for all your instructions, but you are
    /// now starting a new block and some of them need to live there instead.
    fn stealCapacity(b: *Block, len: usize) []Air.Inst.Index {
        return b.stealFrom(b.instructions.len - len);
    }

    fn stealFrom(b: *Block, start: usize) []Air.Inst.Index {
        assert(start >= b.len);
        defer b.instructions.len = start;
        return b.instructions[start..];
    }

    fn body(b: *const Block) []const Air.Inst.Index {
        assert(b.len == b.instructions.len);
        return b.instructions;
    }
};

const Result = struct {
    inst: Air.Inst.Index,
    block: Block,

    /// The return value has `block` initialized to `undefined`; it is the caller's reponsibility
    /// to initialize it.
    fn init(l: *Legalize, ty: Type, parent_block: *Block) Result {
        return .{
            .inst = parent_block.add(l, .{
                .tag = .block,
                .data = .{ .ty_pl = .{
                    .ty = Air.internedToRef(ty.toIntern()),
                    .payload = undefined,
                } },
            }),
            .block = undefined,
        };
    }

    fn finish(res: Result, l: *Legalize) Error!void {
        const data = &l.air_instructions.items(.data)[@intFromEnum(res.inst)];
        data.ty_pl.payload = try l.addBlockBody(res.block.body());
    }
};

const Loop = struct {
    inst: Air.Inst.Index,
    block: Block,

    /// The return value has `block` initialized to `undefined`; it is the caller's reponsibility
    /// to initialize it.
    fn init(l: *Legalize, parent_block: *Block) Loop {
        return .{
            .inst = parent_block.add(l, .{
                .tag = .loop,
                .data = .{ .ty_pl = .{
                    .ty = .noreturn_type,
                    .payload = undefined,
                } },
            }),
            .block = undefined,
        };
    }

    fn finish(loop: Loop, l: *Legalize) Error!void {
        const data = &l.air_instructions.items(.data)[@intFromEnum(loop.inst)];
        data.ty_pl.payload = try l.addBlockBody(loop.block.body());
    }
};

const CondBr = struct {
    inst: Air.Inst.Index,
    hints: Air.CondBr.BranchHints,
    then_block: Block,
    else_block: Block,

    /// The return value has `then_block` and `else_block` initialized to `undefined`; it is the
    /// caller's reponsibility to initialize them.
    fn init(l: *Legalize, operand: Air.Inst.Ref, parent_block: *Block, hints: Air.CondBr.BranchHints) CondBr {
        return .{
            .inst = parent_block.add(l, .{
                .tag = .cond_br,
                .data = .{ .pl_op = .{
                    .operand = operand,
                    .payload = undefined,
                } },
            }),
            .hints = hints,
            .then_block = undefined,
            .else_block = undefined,
        };
    }

    fn finish(cond_br: CondBr, l: *Legalize) Error!void {
        const then_body = cond_br.then_block.body();
        const else_body = cond_br.else_block.body();
        try l.air_extra.ensureUnusedCapacity(l.pt.zcu.gpa, 3 + then_body.len + else_body.len);

        const data = &l.air_instructions.items(.data)[@intFromEnum(cond_br.inst)];
        data.pl_op.payload = @intCast(l.air_extra.items.len);
        l.air_extra.appendSliceAssumeCapacity(&.{
            @intCast(then_body.len),
            @intCast(else_body.len),
            @bitCast(cond_br.hints),
        });
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(then_body));
        l.air_extra.appendSliceAssumeCapacity(@ptrCast(else_body));
    }
};

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
