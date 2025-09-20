pt: Zcu.PerThread,
air_instructions: std.MultiArrayList(Air.Inst),
air_extra: std.ArrayListUnmanaged(u32),
features: if (switch (dev.env) {
    .bootstrap => @import("../codegen/c.zig").legalizeFeatures(undefined),
    else => null,
}) |bootstrap_features| struct {
    fn init(features: *const Features) @This() {
        assert(features.eql(bootstrap_features.*));
        return .{};
    }
    /// `inline` to propagate comptime-known result.
    inline fn has(_: @This(), comptime feature: Feature) bool {
        return comptime bootstrap_features.contains(feature);
    }
    /// `inline` to propagate comptime-known result.
    fn hasAny(_: @This(), comptime features: []const Feature) bool {
        return comptime !bootstrap_features.intersectWith(.initMany(features)).eql(.initEmpty());
    }
} else struct {
    features: *const Features,
    /// `inline` to propagate whether `dev.check` returns.
    inline fn init(features: *const Features) @This() {
        dev.check(.legalize);
        return .{ .features = features };
    }
    fn has(rt: @This(), comptime feature: Feature) bool {
        return rt.features.contains(feature);
    }
    fn hasAny(rt: @This(), comptime features: []const Feature) bool {
        return !rt.features.intersectWith(comptime .initMany(features)).eql(comptime .initEmpty());
    }
},

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
    scalarize_add_with_overflow,
    scalarize_sub_with_overflow,
    scalarize_mul_with_overflow,
    scalarize_shl_with_overflow,
    scalarize_bit_and,
    scalarize_bit_or,
    scalarize_shr,
    scalarize_shr_exact,
    scalarize_shl,
    scalarize_shl_exact,
    scalarize_shl_sat,
    scalarize_xor,
    scalarize_not,
    /// Scalarize `bitcast` from or to an array or vector type to `bitcast`s of the elements.
    /// This does not apply if `@bitSizeOf(Elem) == 8 * @sizeOf(Elem)`.
    /// When this feature is enabled, all remaining `bitcast`s can be lowered using the old bitcast
    /// semantics (reinterpret memory) instead of the new bitcast semantics (copy logical bits) and
    /// the behavior will be equivalent. However, the behavior of `@bitSize` on arrays must be
    /// changed in `Type.zig` before enabling this feature to conform to the new bitcast semantics.
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
    scalarize_int_from_float_safe,
    scalarize_int_from_float_optimized_safe,
    scalarize_float_from_int,
    scalarize_shuffle_one,
    scalarize_shuffle_two,
    scalarize_select,
    scalarize_mul_add,

    /// Legalize (shift lhs, (splat rhs)) -> (shift lhs, rhs)
    unsplat_shift_rhs,
    /// Legalize reduce of a one element vector to a bitcast.
    reduce_one_elem_to_bitcast,
    /// Legalize splat to a one element vector to a bitcast.
    splat_one_elem_to_bitcast,

    /// Replace `intcast_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_intcast_safe`.
    expand_intcast_safe,
    /// Replace `int_from_float_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_int_from_float_safe`.
    expand_int_from_float_safe,
    /// Replace `int_from_float_optimized_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_int_from_float_optimized_safe`.
    expand_int_from_float_optimized_safe,
    /// Replace `add_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_add_safe`.
    expand_add_safe,
    /// Replace `sub_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_sub_safe`.
    expand_sub_safe,
    /// Replace `mul_safe` with an explicit safety check which `call`s the panic function on failure.
    /// Not compatible with `scalarize_mul_safe`.
    expand_mul_safe,

    /// Replace `load` from a packed pointer with a non-packed `load`, `shr`, `truncate`.
    /// Currently assumes little endian and a specific integer layout where the lsb of every integer is the lsb of the
    /// first byte of memory until bit pointers know their backing type.
    expand_packed_load,
    /// Replace `store` and `store_safe` to a packed pointer with a non-packed `load`/`store`, `bit_and`, `bit_or`, and `shl`.
    /// Currently assumes little endian and a specific integer layout where the lsb of every integer is the lsb of the
    /// first byte of memory until bit pointers know their backing type.
    expand_packed_store,
    /// Replace `struct_field_val` of a packed field with a `store` and packed `load`.
    expand_packed_struct_field_val,
    /// Replace `aggregate_init` of a packed aggregate with a series a packed `store`s followed by a `load`.
    expand_packed_aggregate_init,

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
            .add_with_overflow => .scalarize_add_with_overflow,
            .sub_with_overflow => .scalarize_sub_with_overflow,
            .mul_with_overflow => .scalarize_mul_with_overflow,
            .shl_with_overflow => .scalarize_shl_with_overflow,
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
            .int_from_float_safe => .scalarize_int_from_float_safe,
            .int_from_float_optimized_safe => .scalarize_int_from_float_optimized_safe,
            .float_from_int => .scalarize_float_from_int,
            .shuffle_one => .scalarize_shuffle_one,
            .shuffle_two => .scalarize_shuffle_two,
            .select => .scalarize_select,
            .mul_add => .scalarize_mul_add,
        };
    }
};

pub const Features = std.enums.EnumSet(Feature);

pub const Error = std.mem.Allocator.Error;

pub fn legalize(air: *Air, pt: Zcu.PerThread, features: *const Features) Error!void {
    assert(!features.eql(comptime .initEmpty())); // backend asked to run legalize, but no features were enabled
    var l: Legalize = .{
        .pt = pt,
        .air_instructions = air.instructions.toMultiArrayList(),
        .air_extra = air.extra,
        .features = .init(features),
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
            .arg => {},
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
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .add_safe => if (l.features.has(.expand_add_safe)) {
                assert(!l.features.has(.scalarize_add_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .add_with_overflow));
            } else if (l.features.has(.scalarize_add_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .sub_safe => if (l.features.has(.expand_sub_safe)) {
                assert(!l.features.has(.scalarize_sub_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .sub_with_overflow));
            } else if (l.features.has(.scalarize_sub_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .mul_safe => if (l.features.has(.expand_mul_safe)) {
                assert(!l.features.has(.scalarize_mul_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeArithmeticBlockPayload(inst, .mul_with_overflow));
            } else if (l.features.has(.scalarize_mul_safe)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.lhs).isVector(zcu)) continue :inst try l.scalarize(inst, .bin_op);
            },
            .ptr_add, .ptr_sub => {},
            inline .add_with_overflow,
            .sub_with_overflow,
            .mul_with_overflow,
            .shl_with_overflow,
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                if (ty_pl.ty.toType().fieldType(0, zcu).isVector(zcu)) continue :inst l.replaceInst(inst, .block, try l.scalarizeOverflowBlockPayload(inst));
            },
            .alloc => {},
            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .ret_ptr, .assembly => {},
            inline .shr,
            .shr_exact,
            .shl,
            .shl_exact,
            .shl_sat,
            => |air_tag| if (l.features.hasAny(&.{
                .unsplat_shift_rhs,
                .scalarize(air_tag),
            })) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                if (l.typeOf(bin_op.rhs).isVector(zcu)) {
                    if (l.features.has(.unsplat_shift_rhs)) {
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
                    if (l.features.has(comptime .scalarize(air_tag))) continue :inst try l.scalarize(inst, .bin_op);
                }
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
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
            },
            .bitcast => if (l.features.has(.scalarize_bitcast)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;

                const to_ty = ty_op.ty.toType();
                const to_ty_tag = to_ty.zigTypeTag(zcu);
                const to_ty_legal = legal: switch (to_ty_tag) {
                    else => true,
                    .array, .vector => {
                        if (to_ty.arrayLen(zcu) == 1) break :legal true;
                        const to_elem_ty = to_ty.childType(zcu);
                        break :legal to_elem_ty.bitSize(zcu) == 8 * to_elem_ty.abiSize(zcu);
                    },
                };

                const from_ty = l.typeOf(ty_op.operand);
                const from_ty_legal = legal: switch (from_ty.zigTypeTag(zcu)) {
                    else => true,
                    .array, .vector => {
                        if (from_ty.arrayLen(zcu) == 1) break :legal true;
                        const from_elem_ty = from_ty.childType(zcu);
                        break :legal from_elem_ty.bitSize(zcu) == 8 * from_elem_ty.abiSize(zcu);
                    },
                };

                if (!to_ty_legal and !from_ty_legal and to_ty.arrayLen(zcu) == from_ty.arrayLen(zcu)) switch (to_ty_tag) {
                    else => unreachable,
                    .array => continue :inst l.replaceInst(inst, .block, try l.scalarizeBitcastToArrayBlockPayload(inst)),
                    .vector => continue :inst try l.scalarize(inst, .bitcast),
                };
                if (!to_ty_legal) switch (to_ty_tag) {
                    else => unreachable,
                    .array => continue :inst l.replaceInst(inst, .block, try l.scalarizeBitcastResultArrayBlockPayload(inst)),
                    .vector => continue :inst l.replaceInst(inst, .block, try l.scalarizeBitcastResultVectorBlockPayload(inst)),
                };
                if (!from_ty_legal) continue :inst l.replaceInst(inst, .block, try l.scalarizeBitcastOperandBlockPayload(inst));
            },
            .intcast_safe => if (l.features.has(.expand_intcast_safe)) {
                assert(!l.features.has(.scalarize_intcast_safe)); // it doesn't make sense to do both
                continue :inst l.replaceInst(inst, .block, try l.safeIntcastBlockPayload(inst));
            } else if (l.features.has(.scalarize_intcast_safe)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
            },
            .int_from_float_safe => if (l.features.has(.expand_int_from_float_safe)) {
                assert(!l.features.has(.scalarize_int_from_float_safe));
                continue :inst l.replaceInst(inst, .block, try l.safeIntFromFloatBlockPayload(inst, false));
            } else if (l.features.has(.scalarize_int_from_float_safe)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
            },
            .int_from_float_optimized_safe => if (l.features.has(.expand_int_from_float_optimized_safe)) {
                assert(!l.features.has(.scalarize_int_from_float_optimized_safe));
                continue :inst l.replaceInst(inst, .block, try l.safeIntFromFloatBlockPayload(inst, true));
            } else if (l.features.has(.scalarize_int_from_float_optimized_safe)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                if (ty_op.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .ty_op);
            },
            .block, .loop => {
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
            => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
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
            inline .cmp_vector, .cmp_vector_optimized => |air_tag| if (l.features.has(comptime .scalarize(air_tag))) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                if (ty_pl.ty.toType().isVector(zcu)) continue :inst try l.scalarize(inst, .cmp_vector);
            },
            .cond_br => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.CondBr, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.then_body_len);
                try l.legalizeBody(extra.end + extra.data.then_body_len, extra.data.else_body_len);
            },
            .switch_br, .loop_switch_br => {
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
            .switch_dispatch => {},
            .@"try", .try_cold => {
                const pl_op = l.air_instructions.items(.data)[@intFromEnum(inst)].pl_op;
                const extra = l.extraData(Air.Try, pl_op.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .try_ptr, .try_ptr_cold => {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.TryPtr, ty_pl.payload);
                try l.legalizeBody(extra.end, extra.data.body_len);
            },
            .dbg_stmt, .dbg_empty_stmt => {},
            .dbg_inline_block => {
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
            => {},
            .load => if (l.features.has(.expand_packed_load)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                const ptr_info = l.typeOf(ty_op.operand).ptrInfo(zcu);
                if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) continue :inst l.replaceInst(inst, .block, try l.packedLoadBlockPayload(inst));
            },
            .ret, .ret_safe, .ret_load => {},
            .store, .store_safe => if (l.features.has(.expand_packed_store)) {
                const bin_op = l.air_instructions.items(.data)[@intFromEnum(inst)].bin_op;
                const ptr_info = l.typeOf(bin_op.lhs).ptrInfo(zcu);
                if (ptr_info.packed_offset.host_size > 0 and ptr_info.flags.vector_index == .none) continue :inst l.replaceInst(inst, .block, try l.packedStoreBlockPayload(inst));
            },
            .unreach,
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
            => {},
            .struct_field_val => if (l.features.has(.expand_packed_struct_field_val)) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const extra = l.extraData(Air.StructField, ty_pl.payload).data;
                switch (l.typeOf(extra.struct_operand).containerLayout(zcu)) {
                    .auto, .@"extern" => {},
                    .@"packed" => continue :inst l.replaceInst(inst, .block, try l.packedStructFieldValBlockPayload(inst)),
                }
            },
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
            .reduce, .reduce_optimized => if (l.features.has(.reduce_one_elem_to_bitcast)) {
                const reduce = l.air_instructions.items(.data)[@intFromEnum(inst)].reduce;
                const vector_ty = l.typeOf(reduce.operand);
                switch (vector_ty.vectorLen(zcu)) {
                    0 => unreachable,
                    1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                        .ty = Air.internedToRef(vector_ty.childType(zcu).toIntern()),
                        .operand = reduce.operand,
                    } }),
                    else => {},
                }
            },
            .splat => if (l.features.has(.splat_one_elem_to_bitcast)) {
                const ty_op = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_op;
                switch (ty_op.ty.toType().vectorLen(zcu)) {
                    0 => unreachable,
                    1 => continue :inst l.replaceInst(inst, .bitcast, .{ .ty_op = .{
                        .ty = ty_op.ty,
                        .operand = ty_op.operand,
                    } }),
                    else => {},
                }
            },
            .shuffle_one => if (l.features.has(.scalarize_shuffle_one)) continue :inst try l.scalarize(inst, .shuffle_one),
            .shuffle_two => if (l.features.has(.scalarize_shuffle_two)) continue :inst try l.scalarize(inst, .shuffle_two),
            .select => if (l.features.has(.scalarize_select)) continue :inst try l.scalarize(inst, .select),
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
            => {},
            .aggregate_init => if (l.features.has(.expand_packed_aggregate_init)) {
                const ty_pl = l.air_instructions.items(.data)[@intFromEnum(inst)].ty_pl;
                const agg_ty = ty_pl.ty.toType();
                switch (agg_ty.zigTypeTag(zcu)) {
                    else => {},
                    .@"struct", .@"union" => switch (agg_ty.containerLayout(zcu)) {
                        .auto, .@"extern" => {},
                        .@"packed" => continue :inst l.replaceInst(inst, .block, try l.packedAggregateInitBlockPayload(inst)),
                    },
                }
            },
            .union_init, .prefetch => {},
            .mul_add => if (l.features.has(.scalarize_mul_add)) {
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
            .runtime_nav_ptr,
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

const ScalarizeForm = enum { un_op, ty_op, bin_op, pl_op_bin, bitcast, cmp_vector, shuffle_one, shuffle_two, select };
/// inline to propagate comptime-known `replaceInst` result.
inline fn scalarize(l: *Legalize, orig_inst: Air.Inst.Index, comptime form: ScalarizeForm) Error!Air.Inst.Tag {
    return l.replaceInst(orig_inst, .block, try l.scalarizeBlockPayload(orig_inst, form));
}
fn scalarizeBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, comptime form: ScalarizeForm) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const res_ty = l.typeOfIndex(orig_inst);
    const res_len = res_ty.vectorLen(zcu);

    const extra_insts = switch (form) {
        .un_op, .ty_op, .bitcast => 1,
        .bin_op, .cmp_vector => 2,
        .pl_op_bin => 3,
        .shuffle_one, .shuffle_two => 13,
        .select => 6,
    };
    var inst_buf: [5 + extra_insts + 9]Air.Inst.Index = undefined;
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
                        .rhs = res_elem: switch (form) {
                            .un_op => loop.block.add(l, .{
                                .tag = orig.tag,
                                .data = .{ .un_op = loop.block.add(l, .{
                                    .tag = .array_elem_val,
                                    .data = .{ .bin_op = .{
                                        .lhs = orig.data.un_op,
                                        .rhs = cur_index_inst.toRef(),
                                    } },
                                }).toRef() },
                            }).toRef(),
                            .ty_op => loop.block.add(l, .{
                                .tag = orig.tag,
                                .data = .{ .ty_op = .{
                                    .ty = Air.internedToRef(res_ty.childType(zcu).toIntern()),
                                    .operand = loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.ty_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                } },
                            }).toRef(),
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
                            }).toRef(),
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
                                }).toRef();
                            },
                            .bitcast => loop.block.addBitCast(l, res_ty.childType(zcu), loop.block.add(l, .{
                                .tag = .array_elem_val,
                                .data = .{ .bin_op = .{
                                    .lhs = orig.data.ty_op.operand,
                                    .rhs = cur_index_inst.toRef(),
                                } },
                            }).toRef()),
                            .cmp_vector => {
                                const extra = l.extraData(Air.VectorCmp, orig.data.ty_pl.payload).data;
                                break :res_elem (try loop.block.addCmp(
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
                                )).toRef();
                            },
                            .shuffle_one, .shuffle_two => {
                                const ip = &zcu.intern_pool;
                                const unwrapped = switch (form) {
                                    else => comptime unreachable,
                                    .shuffle_one => l.getTmpAir().unwrapShuffleOne(zcu, orig_inst),
                                    .shuffle_two => l.getTmpAir().unwrapShuffleTwo(zcu, orig_inst),
                                };
                                const operand_a = switch (form) {
                                    else => comptime unreachable,
                                    .shuffle_one => unwrapped.operand,
                                    .shuffle_two => unwrapped.operand_a,
                                };
                                const operand_a_len = l.typeOf(operand_a).vectorLen(zcu);
                                const elem_ty = res_ty.childType(zcu);
                                var res_elem: Result = .init(l, elem_ty, &loop.block);
                                res_elem.block = .init(loop.block.stealCapacity(extra_insts));
                                {
                                    const ExpectedContents = extern struct {
                                        mask_elems: [128]InternPool.Index,
                                        ct_elems: switch (form) {
                                            else => unreachable,
                                            .shuffle_one => extern struct {
                                                keys: [152]InternPool.Index,
                                                header: u8 align(@alignOf(u32)),
                                                index: [256][2]u8,
                                            },
                                            .shuffle_two => void,
                                        },
                                    };
                                    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
                                        std.heap.stackFallback(@sizeOf(ExpectedContents), zcu.gpa);
                                    const gpa = stack.get();

                                    const mask_elems = try gpa.alloc(InternPool.Index, res_len);
                                    defer gpa.free(mask_elems);

                                    var ct_elems: switch (form) {
                                        else => unreachable,
                                        .shuffle_one => std.AutoArrayHashMapUnmanaged(InternPool.Index, void),
                                        .shuffle_two => struct {
                                            const empty: @This() = .{};
                                            inline fn deinit(_: @This(), _: std.mem.Allocator) void {}
                                            inline fn ensureTotalCapacity(_: @This(), _: std.mem.Allocator, _: usize) error{}!void {}
                                        },
                                    } = .empty;
                                    defer ct_elems.deinit(gpa);
                                    try ct_elems.ensureTotalCapacity(gpa, res_len);

                                    const mask_elem_ty = try pt.intType(.signed, 1 + Type.smallestUnsignedBits(@max(operand_a_len, switch (form) {
                                        else => comptime unreachable,
                                        .shuffle_one => res_len,
                                        .shuffle_two => l.typeOf(unwrapped.operand_b).vectorLen(zcu),
                                    })));
                                    for (mask_elems, unwrapped.mask) |*mask_elem_val, mask_elem| mask_elem_val.* = (try pt.intValue(mask_elem_ty, switch (form) {
                                        else => comptime unreachable,
                                        .shuffle_one => switch (mask_elem.unwrap()) {
                                            .elem => |index| index,
                                            .value => |elem_val| if (ip.isUndef(elem_val))
                                                operand_a_len
                                            else
                                                ~@as(i33, @intCast((ct_elems.getOrPutAssumeCapacity(elem_val)).index)),
                                        },
                                        .shuffle_two => switch (mask_elem.unwrap()) {
                                            .a_elem => |a_index| a_index,
                                            .b_elem => |b_index| ~@as(i33, b_index),
                                            .undef => operand_a_len,
                                        },
                                    })).toIntern();
                                    const mask_ty = try pt.arrayType(.{
                                        .len = res_len,
                                        .child = mask_elem_ty.toIntern(),
                                    });
                                    const mask_elem_inst = res_elem.block.add(l, .{
                                        .tag = .ptr_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = Air.internedToRef(try pt.intern(.{ .ptr = .{
                                                .ty = (try pt.manyConstPtrType(mask_elem_ty)).toIntern(),
                                                .base_addr = .{ .uav = .{
                                                    .val = (try pt.aggregateValue(mask_ty, mask_elems)).toIntern(),
                                                    .orig_ty = (try pt.singleConstPtrType(mask_ty)).toIntern(),
                                                } },
                                                .byte_offset = 0,
                                            } })),
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    });
                                    var def_cond_br: CondBr = .init(l, (try res_elem.block.addCmp(
                                        l,
                                        .lt,
                                        mask_elem_inst.toRef(),
                                        try pt.intRef(mask_elem_ty, operand_a_len),
                                        .{},
                                    )).toRef(), &res_elem.block, .{});
                                    def_cond_br.then_block = .init(res_elem.block.stealRemainingCapacity());
                                    {
                                        const operand_b_used = switch (form) {
                                            else => comptime unreachable,
                                            .shuffle_one => ct_elems.count() > 0,
                                            .shuffle_two => true,
                                        };
                                        var operand_cond_br: CondBr = undefined;
                                        operand_cond_br.then_block = if (operand_b_used) then_block: {
                                            operand_cond_br = .init(l, (try def_cond_br.then_block.addCmp(
                                                l,
                                                .gte,
                                                mask_elem_inst.toRef(),
                                                try pt.intRef(mask_elem_ty, 0),
                                                .{},
                                            )).toRef(), &def_cond_br.then_block, .{});
                                            break :then_block .init(def_cond_br.then_block.stealRemainingCapacity());
                                        } else def_cond_br.then_block;
                                        _ = operand_cond_br.then_block.add(l, .{
                                            .tag = .br,
                                            .data = .{ .br = .{
                                                .block_inst = res_elem.inst,
                                                .operand = operand_cond_br.then_block.add(l, .{
                                                    .tag = .array_elem_val,
                                                    .data = .{ .bin_op = .{
                                                        .lhs = operand_a,
                                                        .rhs = operand_cond_br.then_block.add(l, .{
                                                            .tag = .intcast,
                                                            .data = .{ .ty_op = .{
                                                                .ty = .usize_type,
                                                                .operand = mask_elem_inst.toRef(),
                                                            } },
                                                        }).toRef(),
                                                    } },
                                                }).toRef(),
                                            } },
                                        });
                                        if (operand_b_used) {
                                            operand_cond_br.else_block = .init(operand_cond_br.then_block.stealRemainingCapacity());
                                            _ = operand_cond_br.else_block.add(l, .{
                                                .tag = .br,
                                                .data = .{ .br = .{
                                                    .block_inst = res_elem.inst,
                                                    .operand = if (switch (form) {
                                                        else => comptime unreachable,
                                                        .shuffle_one => ct_elems.count() > 1,
                                                        .shuffle_two => true,
                                                    }) operand_cond_br.else_block.add(l, .{
                                                        .tag = switch (form) {
                                                            else => comptime unreachable,
                                                            .shuffle_one => .ptr_elem_val,
                                                            .shuffle_two => .array_elem_val,
                                                        },
                                                        .data = .{ .bin_op = .{
                                                            .lhs = operand_b: switch (form) {
                                                                else => comptime unreachable,
                                                                .shuffle_one => {
                                                                    const ct_elems_ty = try pt.arrayType(.{
                                                                        .len = ct_elems.count(),
                                                                        .child = elem_ty.toIntern(),
                                                                    });
                                                                    break :operand_b Air.internedToRef(try pt.intern(.{ .ptr = .{
                                                                        .ty = (try pt.manyConstPtrType(elem_ty)).toIntern(),
                                                                        .base_addr = .{ .uav = .{
                                                                            .val = (try pt.aggregateValue(ct_elems_ty, ct_elems.keys())).toIntern(),
                                                                            .orig_ty = (try pt.singleConstPtrType(ct_elems_ty)).toIntern(),
                                                                        } },
                                                                        .byte_offset = 0,
                                                                    } }));
                                                                },
                                                                .shuffle_two => unwrapped.operand_b,
                                                            },
                                                            .rhs = operand_cond_br.else_block.add(l, .{
                                                                .tag = .intcast,
                                                                .data = .{ .ty_op = .{
                                                                    .ty = .usize_type,
                                                                    .operand = operand_cond_br.else_block.add(l, .{
                                                                        .tag = .not,
                                                                        .data = .{ .ty_op = .{
                                                                            .ty = Air.internedToRef(mask_elem_ty.toIntern()),
                                                                            .operand = mask_elem_inst.toRef(),
                                                                        } },
                                                                    }).toRef(),
                                                                } },
                                                            }).toRef(),
                                                        } },
                                                    }).toRef() else res_elem_br: {
                                                        _ = operand_cond_br.else_block.stealCapacity(3);
                                                        break :res_elem_br Air.internedToRef(ct_elems.keys()[0]);
                                                    },
                                                } },
                                            });
                                            def_cond_br.else_block = .init(operand_cond_br.else_block.stealRemainingCapacity());
                                            try operand_cond_br.finish(l);
                                        } else {
                                            def_cond_br.then_block = operand_cond_br.then_block;
                                            _ = def_cond_br.then_block.stealCapacity(6);
                                            def_cond_br.else_block = .init(def_cond_br.then_block.stealRemainingCapacity());
                                        }
                                    }
                                    _ = def_cond_br.else_block.add(l, .{
                                        .tag = .br,
                                        .data = .{ .br = .{
                                            .block_inst = res_elem.inst,
                                            .operand = try pt.undefRef(elem_ty),
                                        } },
                                    });
                                    try def_cond_br.finish(l);
                                }
                                try res_elem.finish(l);
                                break :res_elem res_elem.inst.toRef();
                            },
                            .select => {
                                const extra = l.extraData(Air.Bin, orig.data.pl_op.payload).data;
                                var res_elem: Result = .init(l, l.typeOf(extra.lhs).childType(zcu), &loop.block);
                                res_elem.block = .init(loop.block.stealCapacity(extra_insts));
                                {
                                    var select_cond_br: CondBr = .init(l, res_elem.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig.data.pl_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(), &res_elem.block, .{});
                                    select_cond_br.then_block = .init(res_elem.block.stealRemainingCapacity());
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
                                    select_cond_br.else_block = .init(select_cond_br.then_block.stealRemainingCapacity());
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
                                    try select_cond_br.finish(l);
                                }
                                try res_elem.finish(l);
                                break :res_elem res_elem.inst.toRef();
                            },
                        },
                    }),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, res_len - 1),
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
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn scalarizeBitcastToArrayBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const res_elem_ty = res_ty.childType(zcu);
    const res_len = res_ty.arrayLen(zcu);

    var inst_buf: [16]Air.Inst.Index = undefined;
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
                .tag = .store,
                .data = .{ .bin_op = .{
                    .lhs = loop.block.add(l, .{
                        .tag = .ptr_elem_ptr,
                        .data = .{ .ty_pl = .{
                            .ty = Air.internedToRef((try pt.singleMutPtrType(res_elem_ty)).toIntern()),
                            .payload = try l.addExtra(Air.Bin, .{
                                .lhs = res_alloc_inst.toRef(),
                                .rhs = cur_index_inst.toRef(),
                            }),
                        } },
                    }).toRef(),
                    .rhs = loop.block.addBitCast(l, res_elem_ty, loop.block.add(l, .{
                        .tag = .array_elem_val,
                        .data = .{ .bin_op = .{
                            .lhs = orig_ty_op.operand,
                            .rhs = cur_index_inst.toRef(),
                        } },
                    }).toRef()),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, res_len - 1),
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
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn scalarizeBitcastOperandBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const operand_ty = l.typeOf(orig_ty_op.operand);
    const int_bits: u16 = @intCast(operand_ty.bitSize(zcu));
    const int_ty = try pt.intType(.unsigned, int_bits);
    const shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, int_bits));
    const elem_bits: u16 = @intCast(operand_ty.childType(zcu).bitSize(zcu));
    const elem_int_ty = try pt.intType(.unsigned, elem_bits);

    var inst_buf: [22]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const int_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(int_ty) },
        });
        _ = res_block.add(l, .{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = int_alloc_inst.toRef(),
                .rhs = try pt.intRef(int_ty, 0),
            } },
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
            const cur_int_inst = loop.block.add(l, .{
                .tag = .bit_or,
                .data = .{ .bin_op = .{
                    .lhs = loop.block.add(l, .{
                        .tag = .shl_exact,
                        .data = .{ .bin_op = .{
                            .lhs = loop.block.add(l, .{
                                .tag = .intcast,
                                .data = .{ .ty_op = .{
                                    .ty = Air.internedToRef(int_ty.toIntern()),
                                    .operand = loop.block.addBitCast(l, elem_int_ty, loop.block.add(l, .{
                                        .tag = .array_elem_val,
                                        .data = .{ .bin_op = .{
                                            .lhs = orig_ty_op.operand,
                                            .rhs = cur_index_inst.toRef(),
                                        } },
                                    }).toRef()),
                                } },
                            }).toRef(),
                            .rhs = loop.block.add(l, .{
                                .tag = .mul,
                                .data = .{ .bin_op = .{
                                    .lhs = loop.block.add(l, .{
                                        .tag = .intcast,
                                        .data = .{ .ty_op = .{
                                            .ty = Air.internedToRef(shift_ty.toIntern()),
                                            .operand = cur_index_inst.toRef(),
                                        } },
                                    }).toRef(),
                                    .rhs = try pt.intRef(shift_ty, elem_bits),
                                } },
                            }).toRef(),
                        } },
                    }).toRef(),
                    .rhs = loop.block.add(l, .{
                        .tag = .load,
                        .data = .{ .ty_op = .{
                            .ty = Air.internedToRef(int_ty.toIntern()),
                            .operand = int_alloc_inst.toRef(),
                        } },
                    }).toRef(),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, operand_ty.arrayLen(zcu) - 1),
                .{},
            )).toRef(), &loop.block, .{});
            loop_cond_br.then_block = .init(loop.block.stealRemainingCapacity());
            {
                _ = loop_cond_br.then_block.add(l, .{
                    .tag = .store,
                    .data = .{ .bin_op = .{
                        .lhs = int_alloc_inst.toRef(),
                        .rhs = cur_int_inst.toRef(),
                    } },
                });
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
            _ = loop_cond_br.else_block.add(l, .{
                .tag = .br,
                .data = .{ .br = .{
                    .block_inst = orig_inst,
                    .operand = loop_cond_br.else_block.addBitCast(l, res_ty, cur_int_inst.toRef()),
                } },
            });
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn scalarizeBitcastResultArrayBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const int_bits: u16 = @intCast(res_ty.bitSize(zcu));
    const int_ty = try pt.intType(.unsigned, int_bits);
    const shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, int_bits));
    const res_elem_ty = res_ty.childType(zcu);
    const elem_bits: u16 = @intCast(res_elem_ty.bitSize(zcu));
    const elem_int_ty = try pt.intType(.unsigned, elem_bits);

    var inst_buf: [20]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const res_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
        });
        const int_ref = res_block.addBitCast(l, int_ty, orig_ty_op.operand);
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
                .tag = .store,
                .data = .{ .bin_op = .{
                    .lhs = loop.block.add(l, .{
                        .tag = .ptr_elem_ptr,
                        .data = .{ .ty_pl = .{
                            .ty = Air.internedToRef((try pt.singleMutPtrType(res_elem_ty)).toIntern()),
                            .payload = try l.addExtra(Air.Bin, .{
                                .lhs = res_alloc_inst.toRef(),
                                .rhs = cur_index_inst.toRef(),
                            }),
                        } },
                    }).toRef(),
                    .rhs = loop.block.addBitCast(l, res_elem_ty, loop.block.add(l, .{
                        .tag = .trunc,
                        .data = .{ .ty_op = .{
                            .ty = Air.internedToRef(elem_int_ty.toIntern()),
                            .operand = loop.block.add(l, .{
                                .tag = .shr,
                                .data = .{ .bin_op = .{
                                    .lhs = int_ref,
                                    .rhs = loop.block.add(l, .{
                                        .tag = .mul,
                                        .data = .{ .bin_op = .{
                                            .lhs = loop.block.add(l, .{
                                                .tag = .intcast,
                                                .data = .{ .ty_op = .{
                                                    .ty = Air.internedToRef(shift_ty.toIntern()),
                                                    .operand = cur_index_inst.toRef(),
                                                } },
                                            }).toRef(),
                                            .rhs = try pt.intRef(shift_ty, elem_bits),
                                        } },
                                    }).toRef(),
                                } },
                            }).toRef(),
                        } },
                    }).toRef()),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, res_ty.arrayLen(zcu) - 1),
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
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn scalarizeBitcastResultVectorBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const int_bits: u16 = @intCast(res_ty.bitSize(zcu));
    const int_ty = try pt.intType(.unsigned, int_bits);
    const shift_ty = try pt.intType(.unsigned, std.math.log2_int_ceil(u16, int_bits));
    const res_elem_ty = res_ty.childType(zcu);
    const elem_bits: u16 = @intCast(res_elem_ty.bitSize(zcu));
    const elem_int_ty = try pt.intType(.unsigned, elem_bits);

    var inst_buf: [19]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const res_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
        });
        const int_ref = res_block.addBitCast(l, int_ty, orig_ty_op.operand);
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
                        .rhs = loop.block.addBitCast(l, res_elem_ty, loop.block.add(l, .{
                            .tag = .trunc,
                            .data = .{ .ty_op = .{
                                .ty = Air.internedToRef(elem_int_ty.toIntern()),
                                .operand = loop.block.add(l, .{
                                    .tag = .shr,
                                    .data = .{ .bin_op = .{
                                        .lhs = int_ref,
                                        .rhs = loop.block.add(l, .{
                                            .tag = .mul,
                                            .data = .{ .bin_op = .{
                                                .lhs = loop.block.add(l, .{
                                                    .tag = .intcast,
                                                    .data = .{ .ty_op = .{
                                                        .ty = Air.internedToRef(shift_ty.toIntern()),
                                                        .operand = cur_index_inst.toRef(),
                                                    } },
                                                }).toRef(),
                                                .rhs = try pt.intRef(shift_ty, elem_bits),
                                            } },
                                        }).toRef(),
                                    } },
                                }).toRef(),
                            } },
                        }).toRef()),
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
            try loop_cond_br.finish(l);
        }
        try loop.finish(l);
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn scalarizeOverflowBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig = l.air_instructions.get(@intFromEnum(orig_inst));
    const res_ty = l.typeOfIndex(orig_inst);
    const wrapped_res_ty = res_ty.fieldType(0, zcu);
    const wrapped_res_scalar_ty = wrapped_res_ty.childType(zcu);
    const res_len = wrapped_res_ty.vectorLen(zcu);

    var inst_buf: [21]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const res_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(res_ty) },
        });
        const ptr_wrapped_res_inst = res_block.add(l, .{
            .tag = .struct_field_ptr_index_0,
            .data = .{ .ty_op = .{
                .ty = Air.internedToRef((try pt.singleMutPtrType(wrapped_res_ty)).toIntern()),
                .operand = res_alloc_inst.toRef(),
            } },
        });
        const ptr_overflow_res_inst = res_block.add(l, .{
            .tag = .struct_field_ptr_index_1,
            .data = .{ .ty_op = .{
                .ty = Air.internedToRef((try pt.singleMutPtrType(res_ty.fieldType(1, zcu))).toIntern()),
                .operand = res_alloc_inst.toRef(),
            } },
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
            const extra = l.extraData(Air.Bin, orig.data.ty_pl.payload).data;
            const res_elem = loop.block.add(l, .{
                .tag = orig.tag,
                .data = .{ .ty_pl = .{
                    .ty = Air.internedToRef(try zcu.intern_pool.getTupleType(zcu.gpa, pt.tid, .{
                        .types = &.{ wrapped_res_scalar_ty.toIntern(), .u1_type },
                        .values = &(.{.none} ** 2),
                    })),
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
                } },
            });
            _ = loop.block.add(l, .{
                .tag = .vector_store_elem,
                .data = .{ .vector_store_elem = .{
                    .vector_ptr = ptr_overflow_res_inst.toRef(),
                    .payload = try l.addExtra(Air.Bin, .{
                        .lhs = cur_index_inst.toRef(),
                        .rhs = loop.block.add(l, .{
                            .tag = .struct_field_val,
                            .data = .{ .ty_pl = .{
                                .ty = .u1_type,
                                .payload = try l.addExtra(Air.StructField, .{
                                    .struct_operand = res_elem.toRef(),
                                    .field_index = 1,
                                }),
                            } },
                        }).toRef(),
                    }),
                } },
            });
            _ = loop.block.add(l, .{
                .tag = .vector_store_elem,
                .data = .{ .vector_store_elem = .{
                    .vector_ptr = ptr_wrapped_res_inst.toRef(),
                    .payload = try l.addExtra(Air.Bin, .{
                        .lhs = cur_index_inst.toRef(),
                        .rhs = loop.block.add(l, .{
                            .tag = .struct_field_val,
                            .data = .{ .ty_pl = .{
                                .ty = Air.internedToRef(wrapped_res_scalar_ty.toIntern()),
                                .payload = try l.addExtra(Air.StructField, .{
                                    .struct_operand = res_elem.toRef(),
                                    .field_index = 0,
                                }),
                            } },
                        }).toRef(),
                    }),
                } },
            });

            var loop_cond_br: CondBr = .init(l, (try loop.block.addCmp(
                l,
                .lt,
                cur_index_inst.toRef(),
                try pt.intRef(.usize, res_len - 1),
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

    const panic_id: Zcu.SimplePanicId = if (dest_is_enum) .invalid_enum_value else .integer_out_of_bounds;

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
fn safeIntFromFloatBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index, optimized: bool) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;

    const operand_ref = ty_op.operand;
    const operand_ty = l.typeOf(operand_ref);
    const dest_ty = ty_op.ty.toType();

    const is_vector = operand_ty.zigTypeTag(zcu) == .vector;
    const dest_scalar_ty = dest_ty.scalarType(zcu);
    const int_info = dest_scalar_ty.intInfo(zcu);

    // We emit 9 instructions in the worst case.
    var inst_buf: [9]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);
    var main_block: Block = .init(&inst_buf);

    // This check is a bit annoying because of floating-point rounding and the fact that this
    // builtin truncates. We'll use a bigint for our calculations, because we need to construct
    // integers exceeding the bounds of the result integer type, and we need to convert it to a
    // float with a specific rounding mode to avoid errors.
    // Our bigint may exceed the twos complement limit by one, so add an extra limb.
    const limbs = try gpa.alloc(
        std.math.big.Limb,
        std.math.big.int.calcTwosCompLimbCount(int_info.bits) + 1,
    );
    defer gpa.free(limbs);
    var big: std.math.big.int.Mutable = .init(limbs, 0);

    // Check if the operand is lower than `min_int` when truncated to an integer.
    big.setTwosCompIntLimit(.min, int_info.signedness, int_info.bits);
    const below_min_inst: Air.Inst.Index = if (!big.positive or big.eqlZero()) bad: {
        // `min_int <= 0`, so check for `x <= min_int - 1`.
        big.addScalar(big.toConst(), -1);
        // For `<=`, we must round the RHS down, so that this value is the first `x` which returns `true`.
        const limit_val = try floatFromBigIntVal(pt, is_vector, operand_ty, big.toConst(), .floor);
        break :bad try main_block.addCmp(l, .lte, operand_ref, Air.internedToRef(limit_val.toIntern()), .{
            .vector = is_vector,
            .optimized = optimized,
        });
    } else {
        // `min_int > 0`, which is currently impossible. It would become possible under #3806, in
        // which case we must detect `x < min_int`.
        unreachable;
    };

    // Check if the operand is greater than `max_int` when truncated to an integer.
    big.setTwosCompIntLimit(.max, int_info.signedness, int_info.bits);
    const above_max_inst: Air.Inst.Index = if (big.positive or big.eqlZero()) bad: {
        // `max_int >= 0`, so check for `x >= max_int + 1`.
        big.addScalar(big.toConst(), 1);
        // For `>=`, we must round the RHS up, so that this value is the first `x` which returns `true`.
        const limit_val = try floatFromBigIntVal(pt, is_vector, operand_ty, big.toConst(), .ceil);
        break :bad try main_block.addCmp(l, .gte, operand_ref, Air.internedToRef(limit_val.toIntern()), .{
            .vector = is_vector,
            .optimized = optimized,
        });
    } else {
        // `max_int < 0`, which is currently impossible. It would become possible under #3806, in
        // which case we must detect `x > max_int`.
        unreachable;
    };

    // Combine the conditions.
    const out_of_bounds_inst: Air.Inst.Index = main_block.add(l, .{
        .tag = .bool_or,
        .data = .{ .bin_op = .{
            .lhs = below_min_inst.toRef(),
            .rhs = above_max_inst.toRef(),
        } },
    });
    const scalar_out_of_bounds_inst: Air.Inst.Index = if (is_vector) main_block.add(l, .{
        .tag = .reduce,
        .data = .{ .reduce = .{
            .operand = out_of_bounds_inst.toRef(),
            .operation = .Or,
        } },
    }) else out_of_bounds_inst;

    // Now emit the actual condbr. "true" will be safety panic. "false" will be "ok", meaning we do
    // the `int_from_float` and `br` the result to `orig_inst`.
    var condbr: CondBr = .init(l, scalar_out_of_bounds_inst.toRef(), &main_block, .{ .true = .cold });
    condbr.then_block = .init(main_block.stealRemainingCapacity());
    try condbr.then_block.addPanic(l, .integer_part_out_of_bounds);
    condbr.else_block = .init(condbr.then_block.stealRemainingCapacity());
    const cast_inst = condbr.else_block.add(l, .{
        .tag = if (optimized) .int_from_float_optimized else .int_from_float,
        .data = .{ .ty_op = .{
            .ty = Air.internedToRef(dest_ty.toIntern()),
            .operand = operand_ref,
        } },
    });
    _ = condbr.else_block.add(l, .{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = orig_inst,
            .operand = cast_inst.toRef(),
        } },
    });
    _ = condbr.else_block.stealRemainingCapacity(); // we might not have used it all
    try condbr.finish(l);

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

fn expandBitcastBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const res_ty_key = ip.indexToKey(res_ty.toIntern());
    const operand_ty = l.typeOf(orig_ty_op.operand);
    const operand_ty_key = ip.indexToKey(operand_ty.toIntern());
    _ = res_ty_key;
    _ = operand_ty_key;

    var inst_buf: [1]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        _ = res_block.add(l, .{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = orig_inst,
                .operand = try pt.undefRef(res_ty),
            } },
        });
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn packedLoadBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_op;
    const res_ty = orig_ty_op.ty.toType();
    const res_int_ty = try pt.intType(.unsigned, @intCast(res_ty.bitSize(zcu)));
    const ptr_ty = l.typeOf(orig_ty_op.operand);
    const ptr_info = ptr_ty.ptrInfo(zcu);
    // This relies on a heap of possibly invalid assumptions to work around not knowing the actual backing type.
    const load_bits = 8 * ptr_info.packed_offset.host_size;
    const load_ty = try pt.intType(.unsigned, load_bits);

    var inst_buf: [6]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    _ = res_block.add(l, .{
        .tag = .br,
        .data = .{ .br = .{
            .block_inst = orig_inst,
            .operand = res_block.addBitCast(l, res_ty, res_block.add(l, .{
                .tag = .trunc,
                .data = .{ .ty_op = .{
                    .ty = Air.internedToRef(res_int_ty.toIntern()),
                    .operand = res_block.add(l, .{
                        .tag = .shr,
                        .data = .{ .bin_op = .{
                            .lhs = res_block.add(l, .{
                                .tag = .load,
                                .data = .{ .ty_op = .{
                                    .ty = Air.internedToRef(load_ty.toIntern()),
                                    .operand = res_block.addBitCast(l, load_ptr_ty: {
                                        var load_ptr_info = ptr_info;
                                        load_ptr_info.child = load_ty.toIntern();
                                        load_ptr_info.flags.vector_index = .none;
                                        load_ptr_info.packed_offset = .{ .host_size = 0, .bit_offset = 0 };
                                        break :load_ptr_ty try pt.ptrType(load_ptr_info);
                                    }, orig_ty_op.operand),
                                } },
                            }).toRef(),
                            .rhs = try pt.intRef(
                                try pt.intType(.unsigned, std.math.log2_int_ceil(u16, load_bits)),
                                ptr_info.packed_offset.bit_offset,
                            ),
                        } },
                    }).toRef(),
                } },
            }).toRef()),
        } },
    });
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(res_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn packedStoreBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_bin_op = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].bin_op;
    const ptr_ty = l.typeOf(orig_bin_op.lhs);
    const ptr_info = ptr_ty.ptrInfo(zcu);
    const operand_ty = l.typeOf(orig_bin_op.rhs);
    const operand_bits: u16 = @intCast(operand_ty.bitSize(zcu));
    const operand_int_ty = try pt.intType(.unsigned, operand_bits);
    // This relies on a heap of possibly invalid assumptions to work around not knowing the actual backing type.
    const load_store_bits = 8 * ptr_info.packed_offset.host_size;
    const load_store_ty = try pt.intType(.unsigned, load_store_bits);

    var inst_buf: [9]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const backing_ptr_inst = res_block.add(l, .{
            .tag = .bitcast,
            .data = .{ .ty_op = .{
                .ty = Air.internedToRef((load_store_ptr_ty: {
                    var load_ptr_info = ptr_info;
                    load_ptr_info.child = load_store_ty.toIntern();
                    load_ptr_info.flags.vector_index = .none;
                    load_ptr_info.packed_offset = .{ .host_size = 0, .bit_offset = 0 };
                    break :load_store_ptr_ty try pt.ptrType(load_ptr_info);
                }).toIntern()),
                .operand = orig_bin_op.lhs,
            } },
        });
        _ = res_block.add(l, .{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = backing_ptr_inst.toRef(),
                .rhs = res_block.add(l, .{
                    .tag = .bit_or,
                    .data = .{ .bin_op = .{
                        .lhs = res_block.add(l, .{
                            .tag = .bit_and,
                            .data = .{ .bin_op = .{
                                .lhs = res_block.add(l, .{
                                    .tag = .load,
                                    .data = .{ .ty_op = .{
                                        .ty = Air.internedToRef(load_store_ty.toIntern()),
                                        .operand = backing_ptr_inst.toRef(),
                                    } },
                                }).toRef(),
                                .rhs = Air.internedToRef((keep_mask: {
                                    const ExpectedContents = [std.math.big.int.calcTwosCompLimbCount(256)]std.math.big.Limb;
                                    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
                                        std.heap.stackFallback(@sizeOf(ExpectedContents), zcu.gpa);
                                    const gpa = stack.get();

                                    var mask_big_int: std.math.big.int.Mutable = .{
                                        .limbs = try gpa.alloc(
                                            std.math.big.Limb,
                                            std.math.big.int.calcTwosCompLimbCount(load_store_bits),
                                        ),
                                        .len = undefined,
                                        .positive = undefined,
                                    };
                                    defer gpa.free(mask_big_int.limbs);
                                    mask_big_int.setTwosCompIntLimit(.max, .unsigned, operand_bits);
                                    mask_big_int.shiftLeft(mask_big_int.toConst(), ptr_info.packed_offset.bit_offset);
                                    mask_big_int.bitNotWrap(mask_big_int.toConst(), .unsigned, load_store_bits);
                                    break :keep_mask try pt.intValue_big(load_store_ty, mask_big_int.toConst());
                                }).toIntern()),
                            } },
                        }).toRef(),
                        .rhs = res_block.add(l, .{
                            .tag = .shl_exact,
                            .data = .{ .bin_op = .{
                                .lhs = res_block.add(l, .{
                                    .tag = .intcast,
                                    .data = .{ .ty_op = .{
                                        .ty = Air.internedToRef(load_store_ty.toIntern()),
                                        .operand = res_block.addBitCast(l, operand_int_ty, orig_bin_op.rhs),
                                    } },
                                }).toRef(),
                                .rhs = try pt.intRef(
                                    try pt.intType(.unsigned, std.math.log2_int_ceil(u16, load_store_bits)),
                                    ptr_info.packed_offset.bit_offset,
                                ),
                            } },
                        }).toRef(),
                    } },
                }).toRef(),
            } },
        });
        _ = res_block.add(l, .{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = orig_inst,
                .operand = .void_value,
            } },
        });
    }
    return .{ .ty_pl = .{
        .ty = .void_type,
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn packedStructFieldValBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_pl = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_pl;
    const orig_extra = l.extraData(Air.StructField, orig_ty_pl.payload).data;
    const field_ty = orig_ty_pl.ty.toType();
    const agg_ty = l.typeOf(orig_extra.struct_operand);

    var inst_buf: [5]Air.Inst.Index = undefined;
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(&inst_buf);
    {
        const agg_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(agg_ty) },
        });
        _ = res_block.add(l, .{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = agg_alloc_inst.toRef(),
                .rhs = orig_extra.struct_operand,
            } },
        });
        _ = res_block.add(l, .{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = orig_inst,
                .operand = res_block.add(l, .{
                    .tag = .load,
                    .data = .{ .ty_op = .{
                        .ty = Air.internedToRef(field_ty.toIntern()),
                        .operand = (try res_block.addStructFieldPtr(l, agg_alloc_inst.toRef(), orig_extra.field_index)).toRef(),
                    } },
                }).toRef(),
            } },
        });
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(field_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}
fn packedAggregateInitBlockPayload(l: *Legalize, orig_inst: Air.Inst.Index) Error!Air.Inst.Data {
    const pt = l.pt;
    const zcu = pt.zcu;

    const orig_ty_pl = l.air_instructions.items(.data)[@intFromEnum(orig_inst)].ty_pl;
    const field_ty = orig_ty_pl.ty.toType();
    const agg_ty = orig_ty_pl.ty.toType();
    const agg_field_count = agg_ty.structFieldCount(zcu);

    const ExpectedContents = [1 + 2 * 32 + 2]Air.Inst.Index;
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), zcu.gpa);
    const gpa = stack.get();

    const inst_buf = try gpa.alloc(Air.Inst.Index, 1 + 2 * agg_field_count + 2);
    defer gpa.free(inst_buf);
    try l.air_instructions.ensureUnusedCapacity(zcu.gpa, inst_buf.len);

    var res_block: Block = .init(inst_buf);
    {
        const agg_alloc_inst = res_block.add(l, .{
            .tag = .alloc,
            .data = .{ .ty = try pt.singleMutPtrType(agg_ty) },
        });
        for (0..agg_field_count, orig_ty_pl.payload..) |field_index, extra_index| _ = res_block.add(l, .{
            .tag = .store,
            .data = .{ .bin_op = .{
                .lhs = (try res_block.addStructFieldPtr(l, agg_alloc_inst.toRef(), field_index)).toRef(),
                .rhs = @enumFromInt(l.air_extra.items[extra_index]),
            } },
        });
        _ = res_block.add(l, .{
            .tag = .br,
            .data = .{ .br = .{
                .block_inst = orig_inst,
                .operand = res_block.add(l, .{
                    .tag = .load,
                    .data = .{ .ty_op = .{
                        .ty = Air.internedToRef(field_ty.toIntern()),
                        .operand = agg_alloc_inst.toRef(),
                    } },
                }).toRef(),
            } },
        });
    }
    return .{ .ty_pl = .{
        .ty = Air.internedToRef(field_ty.toIntern()),
        .payload = try l.addBlockBody(res_block.body()),
    } };
}

/// Given a `std.math.big.int.Const`, converts it to a `Value` which is a float of type `float_ty`
/// representing the same numeric value. If the integer cannot be exactly represented, `round`
/// decides whether the value should be rounded up or down. If `is_vector`, then `float_ty` is
/// instead a vector of floats, and the result value is a vector containing the converted scalar
/// repeated N times.
fn floatFromBigIntVal(
    pt: Zcu.PerThread,
    is_vector: bool,
    float_ty: Type,
    x: std.math.big.int.Const,
    round: std.math.big.int.Round,
) Error!Value {
    const zcu = pt.zcu;
    const scalar_ty = switch (is_vector) {
        true => float_ty.childType(zcu),
        false => float_ty,
    };
    assert(scalar_ty.zigTypeTag(zcu) == .float);
    const scalar_val: Value = switch (scalar_ty.floatBits(zcu.getTarget())) {
        16 => try pt.floatValue(scalar_ty, x.toFloat(f16, round)[0]),
        32 => try pt.floatValue(scalar_ty, x.toFloat(f32, round)[0]),
        64 => try pt.floatValue(scalar_ty, x.toFloat(f64, round)[0]),
        80 => try pt.floatValue(scalar_ty, x.toFloat(f80, round)[0]),
        128 => try pt.floatValue(scalar_ty, x.toFloat(f128, round)[0]),
        else => unreachable,
    };
    if (is_vector) {
        return pt.aggregateSplatValue(float_ty, scalar_val);
    } else {
        return scalar_val;
    }
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

    /// Adds a `struct_field_ptr*` instruction to `b`. This is a fairly thin wrapper around `add`
    /// that selects the optimized instruction encoding to use, although it does compute the
    /// proper field pointer type.
    fn addStructFieldPtr(
        b: *Block,
        l: *Legalize,
        struct_operand: Air.Inst.Ref,
        field_index: usize,
    ) Error!Air.Inst.Index {
        const pt = l.pt;
        const zcu = pt.zcu;

        const agg_ptr_ty = l.typeOf(struct_operand);
        const agg_ptr_info = agg_ptr_ty.ptrInfo(zcu);
        const agg_ty: Type = .fromInterned(agg_ptr_info.child);
        const agg_ptr_align = switch (agg_ptr_info.flags.alignment) {
            .none => agg_ty.abiAlignment(zcu),
            else => |agg_ptr_align| agg_ptr_align,
        };
        const agg_layout = agg_ty.containerLayout(zcu);
        const field_ty = agg_ty.fieldType(field_index, zcu);
        var field_ptr_info: InternPool.Key.PtrType = .{
            .child = field_ty.toIntern(),
            .flags = .{
                .is_const = agg_ptr_info.flags.is_const,
                .is_volatile = agg_ptr_info.flags.is_volatile,
                .address_space = agg_ptr_info.flags.address_space,
            },
        };
        field_ptr_info.flags.alignment = field_ptr_align: switch (agg_layout) {
            .auto => agg_ty.fieldAlignment(field_index, zcu).min(agg_ptr_align),
            .@"extern" => switch (agg_ty.zigTypeTag(zcu)) {
                else => unreachable,
                .@"struct" => .fromLog2Units(@min(
                    agg_ptr_align.toLog2Units(),
                    @ctz(agg_ty.structFieldOffset(field_index, zcu)),
                )),
                .@"union" => agg_ptr_align,
            },
            .@"packed" => switch (agg_ty.zigTypeTag(zcu)) {
                else => unreachable,
                .@"struct" => {
                    const packed_offset = agg_ty.packedStructFieldPtrInfo(agg_ptr_ty, @intCast(field_index), pt);
                    field_ptr_info.packed_offset = packed_offset;
                    break :field_ptr_align agg_ptr_align;
                },
                .@"union" => {
                    field_ptr_info.packed_offset = .{
                        .host_size = switch (agg_ptr_info.packed_offset.host_size) {
                            0 => @intCast(agg_ty.abiSize(zcu)),
                            else => |host_size| host_size,
                        },
                        .bit_offset = agg_ptr_info.packed_offset.bit_offset,
                    };
                    break :field_ptr_align agg_ptr_align;
                },
            },
        };
        const field_ptr_ty = try pt.ptrType(field_ptr_info);
        const field_ptr_ty_ref = Air.internedToRef(field_ptr_ty.toIntern());
        return switch (field_index) {
            inline 0...3 => |ct_field_index| b.add(l, .{
                .tag = switch (ct_field_index) {
                    0 => .struct_field_ptr_index_0,
                    1 => .struct_field_ptr_index_1,
                    2 => .struct_field_ptr_index_2,
                    3 => .struct_field_ptr_index_3,
                    else => comptime unreachable,
                },
                .data = .{ .ty_op = .{
                    .ty = field_ptr_ty_ref,
                    .operand = struct_operand,
                } },
            }),
            else => b.add(l, .{
                .tag = .struct_field_ptr,
                .data = .{ .ty_pl = .{
                    .ty = field_ptr_ty_ref,
                    .payload = try l.addExtra(Air.StructField, .{
                        .struct_operand = struct_operand,
                        .field_index = @intCast(field_index),
                    }),
                } },
            }),
        };
    }

    /// Adds a `bitcast` instruction to `b`. This is a thin wrapper that omits the instruction for
    /// no-op casts.
    fn addBitCast(
        b: *Block,
        l: *Legalize,
        ty: Type,
        operand: Air.Inst.Ref,
    ) Air.Inst.Ref {
        if (ty.toIntern() != l.typeOf(operand).toIntern()) return b.add(l, .{
            .tag = .bitcast,
            .data = .{ .ty_op = .{
                .ty = Air.internedToRef(ty.toIntern()),
                .operand = operand,
            } },
        }).toRef();
        _ = b.stealCapacity(1);
        return operand;
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

/// Returns `tag` to remind the caller to `continue :inst` the result.
/// `inline` to propagate the comptime-known `tag` result.
inline fn replaceInst(l: *Legalize, inst: Air.Inst.Index, comptime tag: Air.Inst.Tag, data: Air.Inst.Data) Air.Inst.Tag {
    const orig_ty = if (std.debug.runtime_safety) l.typeOfIndex(inst) else {};
    l.air_instructions.set(@intFromEnum(inst), .{ .tag = tag, .data = data });
    if (std.debug.runtime_safety) assert(l.typeOfIndex(inst).toIntern() == orig_ty.toIntern());
    return tag;
}

const Air = @import("../Air.zig");
const assert = std.debug.assert;
const dev = @import("../dev.zig");
const InternPool = @import("../InternPool.zig");
const Legalize = @This();
const std = @import("std");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");
